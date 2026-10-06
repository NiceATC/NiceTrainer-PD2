local ESP = NiceTrainer.ESP

-- ─── HUD Marker system ───────────────────────────────────────────────────────

NiceTrainer._esp_markers = NiceTrainer._esp_markers or {}
NiceTrainer._esp_markers_map = NiceTrainer._esp_markers_map or {}

local MARKER_W = 120
local math_floor = math.floor
local math_sqrt = math.sqrt

function ESP.UpdateOrCreateMarker(unit, cat_key, color, label_str)
    if not (unit and alive(unit)) then return nil end
    local u_key = unit:key()
    local existing = NiceTrainer._esp_markers_map[u_key]
    if existing and alive(existing.panel) then
        existing._seen_in_tick = true
        if existing.c_type ~= cat_key or existing._raw_label ~= label_str then
            existing.c_type = cat_key
            existing._raw_label = label_str
            local formatted = ESP.FormatLabel(label_str)
            if alive(existing.label_shadow) then existing.label_shadow:set_text(formatted) end
            if alive(existing.label_text) then
                existing.label_text:set_text(formatted)
                existing.label_text:set_color(color)
            end
        end
        return existing
    end

    local u_pos = unit:position()
    for _, other in ipairs(NiceTrainer._esp_markers) do
        if other._seen_in_tick and other.unit ~= unit and alive(other.unit) and (other.c_type == cat_key or (other.c_type == "mission_computer" and cat_key == "mission_computer") or (other.c_type == "mission_power" and cat_key == "mission_power")) then
            local o_pos = other._cached_pos or (other.unit and alive(other.unit) and other.unit:position())
            if o_pos and mvector3.distance(u_pos, o_pos) < 120 then
                NiceTrainer._esp_markers_map[u_key] = other
                return other
            end
        end
    end

    if not NiceTrainer._marker_ws or not alive(NiceTrainer._marker_panel) then
        NiceTrainer._marker_ws    = managers.gui_data:create_fullscreen_workspace()
        NiceTrainer._marker_panel = NiceTrainer._marker_ws:panel():panel({ layer = 100 })
    end

    local p = NiceTrainer._marker_panel:panel({ w = MARKER_W, h = 20, visible = false })
    local label = ESP.FormatLabel(label_str)
    local l_shadow = p:text({ text = label, font = tweak_data.menu.pd2_small_font, font_size = 7,
             color = Color.black, alpha = 0.7, align = "center", w = MARKER_W, h = 10, y = 1, layer = 2 })
    local l_text = p:text({ text = label, font = tweak_data.menu.pd2_small_font, font_size = 7,
             color = color, align = "center", w = MARKER_W, h = 10, y = 0, layer = 3 })
    local dist = p:text({ text = "",
             font = tweak_data.menu.pd2_small_font, font_size = 7,
             color = Color(0.85, 0.85, 0.85), align = "center", w = MARKER_W, h = 10, y = 8, layer = 3 })

    local marker_obj = {
        panel = p,
        dist = dist,
        label_shadow = l_shadow,
        label_text = l_text,
        unit = unit,
        c_type = cat_key,
        _raw_label = label_str,
        _seen_in_tick = true
    }
    NiceTrainer._esp_markers_map[u_key] = marker_obj
    table.insert(NiceTrainer._esp_markers, marker_obj)
    return marker_obj
end
-- Backward compatibility alias
function ESP.CreateMarker(unit, cat_key, color, label_str)
    return ESP.UpdateOrCreateMarker(unit, cat_key, color, label_str)
end
function ESP.ClearMarkers()
    if alive(NiceTrainer._marker_panel) then NiceTrainer._marker_panel:clear() end
    NiceTrainer._esp_markers = {}
    NiceTrainer._esp_markers_map = {}
end
function ESP.FlushUnusedMarkers()
    local i = 1
    local markers = NiceTrainer._esp_markers
    while i <= #markers do
        local m = markers[i]
        if not m._seen_in_tick or not (m.unit and alive(m.unit)) then
            if alive(m.panel) then m.panel:parent():remove(m.panel) end
            if alive(m.unit) then NiceTrainer._esp_markers_map[m.unit:key()] = nil end
            table.remove(markers, i)
        else
            i = i + 1
        end
    end
end
function ESP.UpdateMarkers()
    if not NiceTrainer.Settings.esp_enabled or not NiceTrainer._marker_ws or not alive(NiceTrainer._marker_ws) then return end
    local cam = managers.viewport and managers.viewport:get_current_camera()
    if not cam or not alive(cam) then return end
    local cam_pos = cam:position()
    local cam_rot = cam:rotation()
    local cam_fwd = cam_rot:y()

    local cx, cy, cz = cam_pos.x, cam_pos.y, cam_pos.z
    local fx, fy, fz = cam_fwd.x, cam_fwd.y, cam_fwd.z

    local i = 1
    local markers = NiceTrainer._esp_markers
    local count = #markers
    while i <= count do
        local m  = markers[i]
        local sk = "esp_show_" .. m.c_type
        local u  = m.unit
        if not (u and alive(u)) or not NiceTrainer.Settings[sk] or not alive(m.panel) or not alive(m.dist) then
            if alive(m.panel) and alive(m.panel:parent()) then m.panel:parent():remove(m.panel) end
            if alive(u) and NiceTrainer._esp_markers_map then NiceTrainer._esp_markers_map[u:key()] = nil end
            table.remove(markers, i)
            count = count - 1
        else
            local pos = m._cached_pos
            if not pos then
                if u.interaction and u:interaction() then
                    local ok_pos, ipos = pcall(function() return u:interaction():interact_position() end)
                    if ok_pos and ipos then pos = ipos end
                end
                if not pos then
                    pos = u:position()
                end
                -- Cache position for static objects to eliminate pcall overhead
                if not (u.character_damage and u:character_damage()) then
                    m._cached_pos = pos
                end
            else
                if u.character_damage and u:character_damage() then
                    pos = u:position()
                end
            end

            local dx = pos.x - cx
            local dy = pos.y - cy
            local dz = pos.z - cz
            local dot = dx * fx + dy * fy + dz * fz

            if dot > 0 then
                local dist_sq = dx * dx + dy * dy + dz * dz
                if dist_sq < 625000000 then -- 250m max
                    local sp = NiceTrainer._marker_ws:world_to_screen(cam, pos)
                    if sp.z > 0 then
                        m.panel:set_center_x(sp.x)
                        m.panel:set_y(sp.y - 20)
                        local dist_m = math_floor(math_sqrt(dist_sq) * 0.01)
                        if m._last_dist ~= dist_m then
                            m._last_dist = dist_m
                            m.dist:set_text(dist_m .. "m")
                        end
                        m.panel:set_visible(true)
                    else
                        m.panel:set_visible(false)
                    end
                else
                    m.panel:set_visible(false)
                end
            else
                m.panel:set_visible(false)
            end
            i = i + 1
        end
    end
end
