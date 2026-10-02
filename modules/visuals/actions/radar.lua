-- ─── Military Tactical Sonar / Radar HUD (Visuals Tab) ───────────────────────
-- Renders a high-tech tactical sonar radar with real-time enemy, civilian,
-- special unit, camera and teammate tracking, customizable position, range,
-- size, opacity, rotation modes, round circular blips, cardinal indicators,
-- wall-accurate camera detection, and full color picker customization.

local _radar_ws = nil
local _radar_ws_pool = {} -- tracks EVERY workspace ever created so none can be orphaned
local _radar_container = nil
local _radar_panel = nil
local _radar_bg = nil
local _radar_aim_line = nil
local _radar_aim_cone_l = nil
local _radar_aim_cone_r = nil
local _radar_aim_arrow = nil
local _radar_rings = {}
local _radar_blips = {}
local _radar_labels = {}
local _radar_header_txt = nil
local _radar_center_player = nil
local _last_update_t = 0

-- Pool management for zero GC overhead
local BLIP_POOL_SIZE = 96
local _blip_pool = {}

local function parse_color(hex_or_color, default_color)
    if type(hex_or_color) == "userdata" then return hex_or_color end
    if type(hex_or_color) == "string" and hex_or_color:sub(1, 1) == "#" and hex_or_color:len() == 7 then
        local r = tonumber(hex_or_color:sub(2, 3), 16) or 255
        local g = tonumber(hex_or_color:sub(4, 5), 16) or 255
        local b = tonumber(hex_or_color:sub(6, 7), 16) or 255
        return Color(r / 255, g / 255, b / 255)
    end
    return default_color
end

local function create_circle_points(radius, segments, cx, cy)
    local points = {}
    for i = 0, segments do
        local a = (i / segments) * 360
        local x = math.cos(a) * radius + cx
        local y = math.sin(a) * radius + cy
        table.insert(points, Vector3(x, y, 0))
    end
    return points
end

local function cleanup_radar_gui()
    -- Destroy the currently tracked workspace (safely; destroy_workspace can
    -- throw if the workspace was already invalidated, e.g. by a heist reload
    -- or a rapid slider-drag re-init).
    if _radar_ws and alive(_radar_ws) then
        pcall(function() managers.gui_data:destroy_workspace(_radar_ws) end)
    end

    -- Also sweep any workspace from a PREVIOUS init that failed to clean up
    -- and got orphaned. Without this, a failed destroy_workspace() call above
    -- (silently swallowed in the old code, with no pcall) leaves the old
    -- radar's crosshair/aim-line/rings alive forever, rendering as stray
    -- disconnected lines on top of the new radar.
    for i = #_radar_ws_pool, 1, -1 do
        local ws = _radar_ws_pool[i]
        if alive(ws) then
            pcall(function() managers.gui_data:destroy_workspace(ws) end)
        end
        table.remove(_radar_ws_pool, i)
    end

    _radar_ws = nil
    _radar_container = nil
    _radar_panel = nil
    _radar_bg = nil
    _radar_aim_line = nil
    _radar_aim_cone_l = nil
    _radar_aim_cone_r = nil
    _radar_aim_arrow = nil
    _radar_rings = {}
    _radar_blips = {}
    _blip_pool = {}
    _radar_labels = {}
    _radar_header_txt = nil
    _radar_center_player = nil
end

local function init_radar_gui()
    cleanup_radar_gui()
    if not managers.gui_data then return end

    local size = tonumber(NiceTrainer.Settings.radar_size) or 200
    local radius = size / 2

    _radar_ws = managers.gui_data:create_saferect_workspace()
    table.insert(_radar_ws_pool, _radar_ws)

    _radar_panel = _radar_ws:panel():panel({
        name = "nice_tactical_radar",
        layer = 1200,
        visible = false
    })

    local pos_x = tonumber(NiceTrainer.Settings.radar_pos_x) or 25
    local pos_y = tonumber(NiceTrainer.Settings.radar_pos_y) or 240

    local container = _radar_panel:panel({
        name = "radar_container",
        x = pos_x,
        y = pos_y,
        w = size,
        h = size + 24,
        layer = 1
    })
    _radar_container = container

    -- Header info (Hostile / Civ count)
    _radar_header_txt = container:text({
        name = "radar_header",
        text = "RADAR [0 HOSTILES]",
        font = "fonts/font_medium_shadow_mf",
        font_size = 12,
        color = Color(0.2, 0.8, 1.0),
        x = 0,
        y = 0,
        w = size,
        align = "center",
        layer = 5,
        visible = NiceTrainer.Settings.radar_show_header ~= false
    })

    -- IMPORTANT: clipping = true prevents anything drawn inside this panel
    -- (crosshair lines, blips, aim line) from rendering outside the circular
    -- radar bounds if the background bitmap fails to load or coordinates
    -- momentarily fall outside the expected range.
    local radar_circle_p = container:panel({
        name = "radar_circle_p",
        x = 0,
        y = 20,
        w = size,
        h = size,
        layer = 2,
        clipping = true
    })

    -- Smooth circular background (with safe fallback if the texture is missing)
    local bg_alpha = (tonumber(NiceTrainer.Settings.radar_opacity) or 60) / 100
    local bg_ok, bg_result = pcall(function()
        return radar_circle_p:bitmap({
            texture = "guis/textures/pd2/hud_radialbg",
            w = size,
            h = size,
            color = Color.black,
            alpha = bg_alpha * 0.85,
            layer = 1
        })
    end)

    if bg_ok and bg_result then
        _radar_bg = bg_result
    else
        -- Fallback: plain rounded-looking dark backing so the crosshair/blips
        -- never render "floating" with nothing behind them.
        _radar_bg = radar_circle_p:rect({
            color = Color.black,
            alpha = bg_alpha * 0.85,
            x = 0,
            y = 0,
            w = size,
            h = size,
            layer = 1
        })
    end

    local border_color = parse_color(NiceTrainer.Settings.radar_color_border, Color(0.2, 0.6, 1.0))

    -- Crosshair lines (clamped neatly inside circle)
    radar_circle_p:polyline({
        points = { Vector3(radius, 6, 0), Vector3(radius, size - 6, 0) },
        color = border_color,
        line_width = 1,
        alpha = 0.2,
        layer = 2
    })
    radar_circle_p:polyline({
        points = { Vector3(6, radius, 0), Vector3(size - 6, radius, 0) },
        color = border_color,
        line_width = 1,
        alpha = 0.2,
        layer = 2
    })

    -- Cardinal labels (North, South, East, West)
    _radar_labels.n = radar_circle_p:text({ text = "N", font = "fonts/font_medium_shadow_mf", font_size = 11, color = border_color, x = radius - 4, y = 2, layer = 4 })
    _radar_labels.s = radar_circle_p:text({ text = "S", font = "fonts/font_medium_shadow_mf", font_size = 10, color = Color(0.7, 0.7, 0.7), x = radius - 4, y = size - 14, layer = 4 })
    _radar_labels.e = radar_circle_p:text({ text = "E", font = "fonts/font_medium_shadow_mf", font_size = 10, color = Color(0.7, 0.7, 0.7), x = size - 12, y = radius - 6, layer = 4 })
    _radar_labels.w = radar_circle_p:text({ text = "W", font = "fonts/font_medium_shadow_mf", font_size = 10, color = Color(0.7, 0.7, 0.7), x = 4, y = radius - 6, layer = 4 })

    -- Dedicated Player Forward Aim Sightline (Always points UP in camera rotation mode)
    _radar_aim_line = radar_circle_p:polyline({
        points = { Vector3(radius, radius - 4, 0), Vector3(radius, radius * 0.35, 0) },
        color = border_color,
        line_width = 2,
        alpha = 0.9,
        layer = 4,
        visible = NiceTrainer.Settings.radar_show_aim_line ~= false
    })

    -- Player center dot
    _radar_center_player = radar_circle_p:panel({
        name = "player_center",
        x = radius - 4,
        y = radius - 4,
        w = 8,
        h = 8,
        layer = 6
    })
    _radar_center_player:rect({ color = Color.white, x = 0, y = 0, w = 8, h = 8, layer = 1 })
    _radar_center_player:rect({ color = border_color, x = 1, y = 1, w = 6, h = 6, layer = 2 })

    -- Pre-create blip pool with vibrant, high-contrast solid dots
    _blip_pool = {}
    for i = 1, BLIP_POOL_SIZE do
        local blip_panel = radar_circle_p:panel({
            name = "blip_" .. i,
            x = -30,
            y = -30,
            w = 24,
            h = 24,
            layer = 5,
            visible = false
        })
        local glow = blip_panel:rect({
            color = Color.white,
            alpha = 0.3,
            x = 1,
            y = 1,
            w = 14,
            h = 14,
            layer = 1
        })
        local dot = blip_panel:rect({
            color = Color.red,
            x = 3,
            y = 3,
            w = 10,
            h = 10,
            layer = 2
        })
        local arrow = blip_panel:text({
            text = "",
            font = "fonts/font_medium_shadow_mf",
            font_size = 11,
            color = Color.white,
            x = 0,
            y = -5,
            w = 24,
            align = "center",
            layer = 3
        })

        table.insert(_blip_pool, {
            panel = blip_panel,
            dot = dot,
            glow = glow,
            arrow = arrow
        })
    end
end

-- Fast paths used by drag-sliders that don't need a full geometry rebuild.
-- Calling init_radar_gui() on every single drag tick is what caused the
-- stray/orphaned line artifacts in the first place, so Position X/Y and
-- Opacity now just mutate the existing panel instead of destroying and
-- recreating the whole radar workspace each frame.
local function reposition_radar_only()
    if _radar_container and alive(_radar_container) then
        local pos_x = tonumber(NiceTrainer.Settings.radar_pos_x) or 25
        local pos_y = tonumber(NiceTrainer.Settings.radar_pos_y) or 240
        _radar_container:set_position(pos_x, pos_y)
        return true
    end
    return false
end

local function set_opacity_only(nval)
    if _radar_bg and alive(_radar_bg) then
        _radar_bg:set_alpha(((tonumber(nval) or 60) / 100) * 0.85)
        return true
    end
    return false
end

-- ============================================================================
-- Radar Entity Classification & Update Loop
-- ============================================================================

local function update_radar(t, dt)
    if not NiceTrainer.Settings.radar_enabled then
        if _radar_panel and _radar_panel:visible() then
            _radar_panel:set_visible(false)
        end
        return
    end

    local player = managers.player and managers.player:player_unit()
    if not alive(player) or not NiceTrainer:IsInHeist() then
        if _radar_panel and _radar_panel:visible() then
            _radar_panel:set_visible(false)
        end
        return
    end

    if NiceTrainer.IsOpen and NiceTrainer.Settings.radar_hide_in_menu ~= false then
        if _radar_panel and _radar_panel:visible() then
            _radar_panel:set_visible(false)
        end
        return
    end

    if not _radar_ws or not alive(_radar_ws) or not _radar_panel then
        init_radar_gui()
    end

    if not _radar_panel then return end
    _radar_panel:set_visible(true)

    local size = tonumber(NiceTrainer.Settings.radar_size) or 200
    local radius = size / 2

    -- Camera Vectors for Projection & Aim Line Orientation
    local p_pos = player:position()
    local cam = player:camera()
    local cam_rot = cam and cam:rotation() or Rotation()
    local cam_fwd = cam_rot:y()
    local cam_right = cam_rot:x()
    local rotate_with_cam = (NiceTrainer.Settings.radar_rotation_mode or 1) == 1
    local max_dist_m = tonumber(NiceTrainer.Settings.radar_max_distance) or 35
    local max_dist_cm = max_dist_m * 100

    local border_color = parse_color(NiceTrainer.Settings.radar_color_border, Color(0.2, 0.6, 1.0))

    -- Player Aim Sightline & FOV Cone
    local show_aim = NiceTrainer.Settings.radar_show_aim_line ~= false
    local show_fov = NiceTrainer.Settings.radar_show_fov_cone ~= false

    if rotate_with_cam then
        -- In Rotate With Camera mode: Player aim is ALWAYS straight UP (12 o'clock / -Y)
        if _radar_aim_line and alive(_radar_aim_line) then
            _radar_aim_line:set_visible(show_aim)
            _radar_aim_line:set_color(border_color)
            _radar_aim_line:set_points({ Vector3(radius, radius - 4, 0), Vector3(radius, radius * 0.35, 0) })
        end

        -- Rotate 4 Cardinal Points (N, S, E, W) along rim
        local nx = (0 * cam_right.x + 1 * cam_right.y)
        local ny = -(0 * cam_fwd.x + 1 * cam_fwd.y)
        local ex = (1 * cam_right.x + 0 * cam_right.y)
        local ey = -(1 * cam_fwd.x + 0 * cam_fwd.y)

        local rim_r = radius - 12
        if _radar_labels.n and alive(_radar_labels.n) then _radar_labels.n:set_position(radius + nx * rim_r - 4, radius + ny * rim_r - 6) end
        if _radar_labels.s and alive(_radar_labels.s) then _radar_labels.s:set_position(radius - nx * rim_r - 4, radius - ny * rim_r - 6) end
        if _radar_labels.e and alive(_radar_labels.e) then _radar_labels.e:set_position(radius + ex * rim_r - 4, radius + ey * rim_r - 6) end
        if _radar_labels.w and alive(_radar_labels.w) then _radar_labels.w:set_position(radius - ex * rim_r - 4, radius - ey * rim_r - 6) end
    else
        -- In Fixed North-Up mode: Aim sightline rotates with player view orientation
        local aim_len = radius * 0.65
        local fx, fy = cam_fwd.x, -cam_fwd.y
        local ax, ay = radius + fx * aim_len, radius + fy * aim_len
        if _radar_aim_line and alive(_radar_aim_line) then
            _radar_aim_line:set_visible(show_aim)
            _radar_aim_line:set_color(border_color)
            _radar_aim_line:set_points({ Vector3(radius + fx * 4, radius + fy * 4, 0), Vector3(ax, ay, 0) })
        end

        if _radar_labels.n and alive(_radar_labels.n) then _radar_labels.n:set_position(radius - 4, 2) end
        if _radar_labels.s and alive(_radar_labels.s) then _radar_labels.s:set_position(radius - 4, size - 14) end
        if _radar_labels.e and alive(_radar_labels.e) then _radar_labels.e:set_position(size - 12, radius - 6) end
        if _radar_labels.w and alive(_radar_labels.w) then _radar_labels.w:set_position(4, radius - 6) end
    end

    local blip_idx = 1
    local hostile_count = 0
    local civ_count = 0
    local show_elevation = NiceTrainer.Settings.radar_show_elevation ~= false
    local blip_size = tonumber(NiceTrainer.Settings.radar_blip_size) or 7

    local show_enemies = NiceTrainer.Settings.radar_show_enemies ~= false
    local show_specials = NiceTrainer.Settings.radar_show_specials ~= false
    local show_civilians = NiceTrainer.Settings.radar_show_civilians ~= false
    local show_team = NiceTrainer.Settings.radar_show_team ~= false
    local show_cameras = NiceTrainer.Settings.radar_show_cameras ~= false

    local col_enemies   = parse_color(NiceTrainer.Settings.radar_color_enemies, Color(1.0, 0.2, 0.2))
    local col_specials  = parse_color(NiceTrainer.Settings.radar_color_specials, Color(1.0, 0.85, 0.1))
    local col_civilians = parse_color(NiceTrainer.Settings.radar_color_civilians, Color(1.0, 0.65, 0.1))
    local col_team      = parse_color(NiceTrainer.Settings.radar_color_team, Color(0.2, 1.0, 0.4))
    local col_cameras   = parse_color(NiceTrainer.Settings.radar_color_cameras, Color(0.0, 0.9, 1.0))

    local norm_factor = (radius - 8) / max_dist_cm

    local function add_blip(u_pos, color, shape_type, elev_diff, is_special)
        if blip_idx > #_blip_pool then return end

        local dx = u_pos.x - p_pos.x
        local dy = u_pos.y - p_pos.y
        local dist_sq = dx * dx + dy * dy
        if dist_sq > (max_dist_cm * max_dist_cm) then return end

        local rx, ry
        if rotate_with_cam then
            rx = (dx * cam_right.x + dy * cam_right.y) * norm_factor
            ry = -(dx * cam_fwd.x + dy * cam_fwd.y) * norm_factor
        else
            rx = dx * norm_factor
            ry = -dy * norm_factor
        end

        local bx = radius + rx - (blip_size / 2)
        local by = radius + ry - (blip_size / 2)

        local item = _blip_pool[blip_idx]
        item.panel:set_visible(true)
        item.panel:set_position(bx - 3, by - 3)

        local b_w = is_special and (blip_size + 3) or blip_size
        item.dot:set_size(b_w, b_w)
        item.dot:set_position(3, 3)
        item.dot:set_color(color)

        item.glow:set_size(b_w + 4, b_w + 4)
        item.glow:set_position(1, 1)
        item.glow:set_color(is_special and Color.white or color)
        item.glow:set_alpha(is_special and 0.55 or 0.25)

        if show_elevation and math.abs(elev_diff) > 180 then
            item.arrow:set_text(elev_diff > 0 and "^" or "v")
            item.arrow:set_color(color)
            item.arrow:set_visible(true)
        else
            item.arrow:set_visible(false)
        end

        blip_idx = blip_idx + 1
    end

    -- 1. Scan Enemies & Police
    if (show_enemies or show_specials) and managers.enemy then
        for _, data in pairs(managers.enemy:all_enemies() or {}) do
            local u = data.unit
            if alive(u) and u:movement() then
                local dmg = u:character_damage()
                if not (dmg and dmg.dead and dmg:dead()) then
                    local brain = u:brain()
                    local is_converted = brain and brain._logic_data and brain._logic_data.is_converted

                    if is_converted and show_team then
                        add_blip(u:position(), col_team, "minion", u:position().z - p_pos.z, false)
                    elseif not is_converted then
                        hostile_count = hostile_count + 1
                        local tw = u:base() and u:base()._tweak_table
                        local tw_str = tw and string.lower(tostring(tw)) or ""

                        local is_spec = false
                        local col = col_enemies

                        if tw_str:find("tank", 1, true) or tw_str:find("bulldozer", 1, true) or
                           tw_str:find("cloaker", 1, true) or tw_str:find("spooc", 1, true) or
                           tw_str:find("taser", 1, true) or tw_str:find("medic", 1, true) or
                           tw_str:find("shield", 1, true) or tw_str:find("sniper", 1, true) then
                            is_spec = true
                            col = col_specials
                        end

                        if (is_spec and show_specials) or (not is_spec and show_enemies) then
                            add_blip(u:position(), col, is_spec and "special" or "normal", u:position().z - p_pos.z, is_spec)
                        end
                    end
                end
            end
        end
    end

    -- 2. Scan Civilians
    if show_civilians and managers.enemy then
        for _, data in pairs(managers.enemy:all_civilians() or {}) do
            local u = data.unit
            if alive(u) and u:movement() then
                local dmg = u:character_damage()
                if not (dmg and dmg.dead and dmg:dead()) then
                    civ_count = civ_count + 1
                    add_blip(u:position(), col_civilians, "civ", u:position().z - p_pos.z, false)
                end
            end
        end
    end

    -- 3. Scan Teammates
    if show_team and managers.criminals then
        for _, char in pairs(managers.criminals:characters() or {}) do
            if char.taken and alive(char.unit) and char.unit ~= player then
                add_blip(char.unit:position(), col_team, "crew", char.unit:position().z - p_pos.z, false)
            end
        end
    end

    -- 4. Scan Security Cameras (Comprehensive multi-source search)
    if show_cameras then
        local checked_cams = {}
        local function check_and_add_camera(u)
            if type(u) ~= "userdata" or not alive(u) or checked_cams[u:key()] then return end
            checked_cams[u:key()] = true
            local base = u:base()
            local destroyed = false
            if base and (base._destroyed or base._disabled) then
                destroyed = true
            end
            if not destroyed and u:interaction() and u:interaction():disabled() then
                destroyed = true
            end
            if not destroyed and u:character_damage() and u:character_damage().dead and u:character_damage():dead() then
                destroyed = true
            end
            if not destroyed then
                local cpos = (base and base._look_obj and base._look_obj:position()) or u:position()
                add_blip(cpos, col_cameras, "cam", cpos.z - p_pos.z, false)
            end
        end

        pcall(function()
            if SecurityCamera and SecurityCamera.cameras then
                for _, u in pairs(SecurityCamera.cameras) do
                    check_and_add_camera(u)
                end
            end
            if managers.groupai and managers.groupai:state() and managers.groupai:state()._security_cameras then
                for _, u in pairs(managers.groupai:state()._security_cameras) do
                    check_and_add_camera(u)
                end
            end
            if managers.slot then
                local cmask = managers.slot:get_mask("cameras")
                if cmask then
                    local found = World:find_units_quick("all", cmask)
                    for _, u in pairs(found or {}) do
                        check_and_add_camera(u)
                    end
                end
            end
        end)
    end

    -- Hide remaining blips from pool
    for i = blip_idx, #_blip_pool do
        _blip_pool[i].panel:set_visible(false)
    end

    -- Update Header text
    if _radar_header_txt and _radar_header_txt:visible() then
        _radar_header_txt:set_text(string.format("RADAR [%d HOSTILES | %d CIVS]", hostile_count, civ_count))
        _radar_header_txt:set_color(hostile_count > 0 and Color(1.0, 0.35, 0.35) or border_color)
    end
end

-- ============================================================================
-- Radar Settings Modal (With Smooth Scroll & Color Pickers)
-- ============================================================================

local function ShowRadarSettings()
    local MODAL_W, MODAL_H = 540, 580
    NiceTrainer:ShowCustomModal("Tactical Radar Settings", MODAL_W, MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        local TRACK_X, TRACK_W = 16, MODAL_W - 32

        local scroll_wrap = m:panel({ x = 0, y = 48, w = MODAL_W, h = MODAL_H - 95, layer = 2 })
        local canvas_h = 820
        local canvas = scroll_wrap:panel({ x = 0, y = 0, w = MODAL_W, h = canvas_h, layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local function create_btn_panel(y, h)
            local p = canvas:panel({ x = TRACK_X, y = y, w = TRACK_W, h = h, layer = 2 })
            local bg = p:rect({ color = Color.white, alpha = 0.02, layer = 0 })
            local hl = p:rect({ color = NiceTrainer:GetAccentColor(), x = 0, y = h - 2, w = TRACK_W, h = 2, alpha = 0, layer = 1 })
            return p, bg, hl
        end

        local function create_slider(y, label, min_val, max_val, setting_key, default_val, format_str, callback_fn)
            local p, bg, hl = create_btn_panel(y, 44)
            if NiceTrainer.Settings[setting_key] == nil then
                NiceTrainer.Settings[setting_key] = default_val
            end
            local val = tonumber(NiceTrainer.Settings[setting_key])
            if val == nil then val = default_val or min_val end

            local title_txt = p:text({ text = label, font = "fonts/font_medium_shadow_mf", font_size = 15, color = Color(0.85, 0.85, 0.85), x = 12, y = 4, h = 20, layer = 1 })
            local val_txt = p:text({ text = string.format(format_str, val), font = "fonts/font_medium_shadow_mf", font_size = 15, color = NiceTrainer:GetAccentColor(), x = p:w() - 75, y = 4, w = 60, align = "right", h = 20, layer = 1 })

            local track_bg = p:rect({ color = Color.white, alpha = 0.2, x = 12, y = 26, w = p:w() - 24, h = 4, layer = 1 })
            local pct = math.clamp((val - min_val) / (max_val - min_val), 0, 1)
            local track_fill = p:rect({ color = NiceTrainer:GetAccentColor(), x = 12, y = 26, w = pct * (p:w() - 24), h = 4, layer = 2 })
            local track_knob = p:rect({ color = Color.white, x = 12 + pct * (p:w() - 24) - 4, y = 22, w = 8, h = 12, layer = 3 })

            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.08 or 0.02)
                    hl:set_alpha(hovered and 1 or 0)
                    title_txt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                end,
                on_click = function(self, mx, my)
                    NiceTrainer._dragging_slider = function(drag_x)
                        local rx = drag_x - track_bg:world_x()
                        local npct = math.clamp(rx / track_bg:w(), 0, 1)
                        local nval = min_val + npct * (max_val - min_val)
                        if format_str == "%d" or format_str == "%dm" or format_str == "%dpx" or format_str == "%d%%" then
                            nval = math.floor(nval + 0.5)
                        end
                        NiceTrainer.Settings[setting_key] = nval
                        NiceTrainer:Save()
                        track_fill:set_w(npct * track_bg:w())
                        track_knob:set_x(12 + npct * track_bg:w() - 4)
                        val_txt:set_text(string.format(format_str, nval))
                        if callback_fn then callback_fn(nval) end
                    end
                    NiceTrainer._dragging_slider(mx)
                end
            })
            return y + 46
        end

        local function create_toggle(y, label, setting_key, default_val, callback_fn)
            local p, bg, hl = create_btn_panel(y, 32)
            if NiceTrainer.Settings[setting_key] == nil then NiceTrainer.Settings[setting_key] = default_val end
            local state = NiceTrainer.Settings[setting_key]

            local box = p:rect({ color = Color.white, alpha = 0.1, x = 12, y = 7, w = 18, h = 18, layer = 1 })
            local check = p:rect({ color = NiceTrainer:GetAccentColor(), x = 15, y = 10, w = 12, h = 12, visible = state, layer = 2 })
            local txt = p:text({ text = label, font = "fonts/font_medium_shadow_mf", font_size = 15, color = Color(0.85, 0.85, 0.85), x = 40, vertical = "center", layer = 1 })

            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.08 or 0.02)
                    hl:set_alpha(hovered and 1 or 0)
                    txt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                end,
                on_click = function(self)
                    NiceTrainer.Settings[setting_key] = not NiceTrainer.Settings[setting_key]
                    NiceTrainer:Save()
                    check:set_visible(NiceTrainer.Settings[setting_key])
                    if callback_fn then callback_fn(NiceTrainer.Settings[setting_key]) end
                end
            })
            return y + 34
        end

        local function create_color_picker_row(y, label, setting_key, default_hex)
            local p, bg, hl = create_btn_panel(y, 34)
            if not NiceTrainer.Settings[setting_key] or NiceTrainer.Settings[setting_key] == "" then
                NiceTrainer.Settings[setting_key] = default_hex
            end
            local current_hex = NiceTrainer.Settings[setting_key]
            local current_col = parse_color(current_hex, Color.white)

            local txt = p:text({ text = label, font = "fonts/font_medium_shadow_mf", font_size = 15, color = Color(0.85, 0.85, 0.85), x = 12, vertical = "center", layer = 1 })

            local btn_w = 90
            local swatch_btn = p:panel({ x = p:w() - 12 - btn_w, y = 4, w = btn_w, h = 26, layer = 2 })
            local swatch_bg = swatch_btn:rect({ color = current_col, alpha = 0.85, layer = 1 })
            swatch_btn:rect({ color = Color.white, alpha = 0.4, w = 1, layer = 2 })
            swatch_btn:rect({ color = Color.white, alpha = 0.4, x = btn_w - 1, w = 1, layer = 2 })
            swatch_btn:rect({ color = Color.white, alpha = 0.4, h = 1, layer = 2 })
            swatch_btn:rect({ color = Color.white, alpha = 0.4, y = 25, h = 1, layer = 2 })

            local hex_txt = swatch_btn:text({ text = current_hex, font = "fonts/font_medium_shadow_mf", font_size = 13, align = "center", vertical = "center", color = Color.black, layer = 3 })

            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.08 or 0.02)
                    hl:set_alpha(hovered and 1 or 0)
                    txt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                end,
                on_click = function(self)
                    NiceTrainer:ShowColorPickerModal(label, NiceTrainer.Settings[setting_key], function(c, hex)
                        local save_hex = (type(hex) == "string" and hex) or (c and string.format("#%02X%02X%02X", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))) or default_hex
                        NiceTrainer.Settings[setting_key] = save_hex
                        NiceTrainer:Save()
                        swatch_bg:set_color(c or parse_color(save_hex, Color.white))
                        hex_txt:set_text(save_hex)
                        init_radar_gui()
                    end)
                end
            })
            return y + 36
        end

        local function create_rotation_mode(y)
            local p, bg, hl = create_btn_panel(y, 36)
            local txt = p:text({ text = "Radar Orientation", font = "fonts/font_medium_shadow_mf", font_size = 15, color = Color(0.85, 0.85, 0.85), x = 12, vertical = "center", layer = 1 })

            local modes = { "Rotate with Camera", "Fixed (North Up)" }
            local mode = NiceTrainer.Settings.radar_rotation_mode or 1

            local btn_w = 170
            local action_btn = p:panel({ x = p:w() - 12 - btn_w, y = 4, w = btn_w, h = 26, layer = 2 })
            local action_bg = action_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
            action_btn:rect({ color = NiceTrainer:GetAccentColor(), w = 2, layer = 1 })
            action_btn:rect({ color = NiceTrainer:GetAccentColor(), x = btn_w - 2, w = 2, layer = 1 })

            local mode_txt = action_btn:text({ text = modes[mode], font = "fonts/font_medium_shadow_mf", font_size = 14, align = "center", vertical = "center", color = Color.white, layer = 2 })

            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.08 or 0.02)
                    hl:set_alpha(hovered and 1 or 0)
                    txt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                    action_bg:set_alpha(hovered and 0.4 or 0.2)
                end,
                on_click = function(self)
                    mode = mode + 1
                    if mode > #modes then mode = 1 end
                    NiceTrainer.Settings.radar_rotation_mode = mode
                    NiceTrainer:Save()
                    mode_txt:set_text(modes[mode])
                end
            })
            return y + 38
        end

        local function create_position_presets(y)
            local p = canvas:panel({ x = TRACK_X, y = y, w = TRACK_W, h = 36, layer = 2 })
            p:text({ text = "Quick Positions:", font = "fonts/font_medium_shadow_mf", font_size = 15, color = Color(0.85, 0.85, 0.85), x = 12, vertical = "center", layer = 1 })

            local presets = {
                { name = "Center-L", x = 25, y = 240 },
                { name = "Top-L",    x = 25, y = 60 },
                { name = "Bot-L",    x = 25, y = 440 },
                { name = "Top-R",    x = 960, y = 60 },
                { name = "Bot-R",    x = 960, y = 440 }
            }

            local btn_w = 64
            for i, pr in ipairs(presets) do
                local px = p:w() - (6 - i) * (btn_w + 4)
                local btn = p:panel({ x = px, y = 4, w = btn_w, h = 26, layer = 2 })
                local btn_bg = btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
                btn:rect({ color = NiceTrainer:GetAccentColor(), w = 1, layer = 1 })
                btn:rect({ color = NiceTrainer:GetAccentColor(), x = btn_w - 1, w = 1, layer = 1 })
                btn:text({ text = pr.name, font = "fonts/font_medium_shadow_mf", font_size = 13, align = "center", vertical = "center", color = Color.white, layer = 2 })

                table.insert(top_modal.elements, {
                    panel = btn,
                    inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and btn:inside(mx, my) end,
                    on_hover = function(self, hovered) btn_bg:set_alpha(hovered and 0.5 or 0.2) end,
                    on_click = function(self)
                        NiceTrainer.Settings.radar_pos_x = pr.x
                        NiceTrainer.Settings.radar_pos_y = pr.y
                        NiceTrainer:Save()
                        init_radar_gui()
                        NiceTrainer:Toast("Radar positioned to " .. pr.name)
                    end
                })
            end
            return y + 38
        end

        local cur_y = 6
        cur_y = create_rotation_mode(cur_y)
        cur_y = create_position_presets(cur_y)
        cur_y = create_slider(cur_y, "Detection Range (Radius)", 10, 120, "radar_max_distance", 40, "%dm", function() end)
        cur_y = create_slider(cur_y, "Radar Diameter (Size)", 120, 360, "radar_size", 200, "%dpx", function() init_radar_gui() end)
        cur_y = create_slider(cur_y, "Blip Dot Size (Pixels)", 4, 16, "radar_blip_size", 8, "%dpx", function() init_radar_gui() end)
        cur_y = create_slider(cur_y, "Radar Background Opacity", 10, 100, "radar_opacity", 60, "%d%%", function(nval)
            if not set_opacity_only(nval) then init_radar_gui() end
        end)
        cur_y = create_slider(cur_y, "Screen Position X", 0, 1200, "radar_pos_x", 25, "%d", function()
            if not reposition_radar_only() then init_radar_gui() end
        end)
        cur_y = create_slider(cur_y, "Screen Position Y", 0, 800, "radar_pos_y", 240, "%d", function()
            if not reposition_radar_only() then init_radar_gui() end
        end)

        cur_y = create_toggle(cur_y, "Show Aim Sightline (Player Forward)", "radar_show_aim_line", true)
        cur_y = create_toggle(cur_y, "Show Field of View Cone (FOV)", "radar_show_fov_cone", true)
        cur_y = create_toggle(cur_y, "Show Special Enemy Blips (Dozer, Cloaker, Taser)", "radar_show_specials", true)
        cur_y = create_toggle(cur_y, "Show Regular Enemies & Police", "radar_show_enemies", true)
        cur_y = create_toggle(cur_y, "Show Civilians & Hostages", "radar_show_civilians", true)
        cur_y = create_toggle(cur_y, "Show Teammates & Converted Minions", "radar_show_team", true)
        cur_y = create_toggle(cur_y, "Show Security Cameras", "radar_show_cameras", true)
        cur_y = create_toggle(cur_y, "Show Elevation Indicators (^ / v)", "radar_show_elevation", true)

        -- Color Customizations Header
        local col_header = canvas:panel({ x = TRACK_X, y = cur_y + 6, w = TRACK_W, h = 24, layer = 2 })
        col_header:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.3, h = 1, y = 12, layer = 1 })
        col_header:text({ text = "BLIP COLOR CUSTOMIZATION (RGB / PALETTE)", font = "fonts/font_medium_shadow_mf", font_size = 13, color = NiceTrainer:GetAccentColor(), x = 8, vertical = "center", layer = 2 })
        cur_y = cur_y + 32

        cur_y = create_color_picker_row(cur_y, "Enemies & Police Color", "radar_color_enemies", "#FF3333")
        cur_y = create_color_picker_row(cur_y, "Special Units Color (Dozers, Cloakers, etc.)", "radar_color_specials", "#FFD700")
        cur_y = create_color_picker_row(cur_y, "Civilians & Hostages Color", "radar_color_civilians", "#FFA500")
        cur_y = create_color_picker_row(cur_y, "Teammates & Minions Color", "radar_color_team", "#00E676")
        cur_y = create_color_picker_row(cur_y, "Security Cameras Color", "radar_color_cameras", "#00E5FF")
        cur_y = create_color_picker_row(cur_y, "Radar Border & Accent Color", "radar_color_border", "#3399FF")

        canvas:set_h(cur_y + 20)

        local close_btn = m:panel({ x = (MODAL_W - 120) / 2, y = MODAL_H - 40, w = 120, h = 28, layer = 3 })
        local close_bg = close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
        close_btn:text({ text = "Close", font = "fonts/font_medium_shadow_mf", font_size = 18, align = "center", vertical = "center", color = Color.white, layer = 2 })

        table.insert(top_modal.elements, {
            panel = close_btn,
            inside = function(self, mx, my) return close_btn:inside(mx, my) end,
            on_hover = function(self, hovered) close_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self) NiceTrainer:CloseModal() end
        })
    end)
end

-- ============================================================================
-- Registration (Visuals Tab)
-- ============================================================================

NiceTrainer:RegisterAction("Visuals", {
    type              = "toggle_settings",
    category          = "RADAR & HUD",
    badge             = "client",
    id                = "radar_enabled",
    text              = "Tactical Sonar Radar",
    tooltip           = "Renders a circular sonar radar displaying all surrounding enemies, specials, civilians, cameras and elevation in real time with custom round blips and colors.",
    default           = false,
    callback          = function(state)
        if state then
            init_radar_gui()
        else
            cleanup_radar_gui()
        end
    end,
    settings_callback = ShowRadarSettings
})

Hooks:Add("GameSetupUpdate", "NiceTrainer_Radar_Update", function(t, dt)
    update_radar(t, dt)
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Radar_OnLoad", function()
    if NiceTrainer.Settings.radar_enabled then
        init_radar_gui()
    end
end)