-- ─── Stealth GPS & Patrol Path Visualizer (Stealth Tab) ───────────────────────
-- Renders real-time 3D navigation paths, future destination points, patrol routes, and unit IDs.

NiceTrainer._stealth_gps = NiceTrainer._stealth_gps or {
    unit_colors = {},
    brush = nil,
    active_paths = {}
}
local SG = NiceTrainer._stealth_gps

local function get_gps_settings()
    return {
        enabled = NiceTrainer.Settings.stealth_gps_enabled or false,
        draw_enemies = (NiceTrainer.Settings.stealth_gps_enemies ~= false),
        draw_civilians = (NiceTrainer.Settings.stealth_gps_civilians ~= false),
        draw_guided_path = (NiceTrainer.Settings.stealth_gps_guided_path ~= false),
        draw_nav_aura = (NiceTrainer.Settings.stealth_gps_nav_aura ~= false),
        draw_unit_id = (NiceTrainer.Settings.stealth_gps_unit_id ~= false),
        draw_last_pos = (NiceTrainer.Settings.stealth_gps_last_pos ~= false),
        max_dist = (NiceTrainer.Settings.stealth_gps_distance or 100) * 100, -- in cm
        loud_mode = NiceTrainer.Settings.stealth_gps_loud_mode or false
    }
end

local function hsv2rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return r + m, g + m, b + m
end

local function get_unit_color(unit_id)
    local key = tostring(unit_id or 1)
    if not SG.unit_colors[key] then
        local id_num = tonumber(unit_id) or 1
        local hue = ((id_num * 137.5) % 360)
        local r, g, b = hsv2rgb(hue, 0.85, 1.0)
        SG.unit_colors[key] = { r = r, g = g, b = b }
    end
    return SG.unit_colors[key]
end

local function extract_nav_pos(nav_point, walk_action)
    if not nav_point then return nil end
    if type(nav_point) == "userdata" then
        return nav_point
    end
    if type(nav_point) == "table" then
        if nav_point.pos and type(nav_point.pos) == "userdata" then return nav_point.pos end
        if nav_point.position and type(nav_point.position) == "userdata" then return nav_point.position end
        if nav_point.x and nav_point.y and nav_point.z then return Vector3(nav_point.x, nav_point.y, nav_point.z) end
        if walk_action and walk_action._nav_point_pos then
            local ok, pos = pcall(walk_action._nav_point_pos, nav_point)
            if ok and pos and type(pos) == "userdata" then return pos end
            local ok2, pos2 = pcall(function() return walk_action:_nav_point_pos(nav_point) end)
            if ok2 and pos2 and type(pos2) == "userdata" then return pos2 end
        end
        if nav_point.element and nav_point.element.values and nav_point.element.values.position then
            return nav_point.element.values.position
        end
    end
    return nil
end

local function render_unit_gps(unit, player, cam_rot, cfg)
    if not alive(unit) or not unit:movement() then return end

    local mov = unit:movement()
    local unit_pos = unit:position()
    local head_pos = (mov.m_head_pos and mov:m_head_pos()) or (unit_pos + Vector3(0, 0, 160))
    local u_id = unit:id()
    local color = get_unit_color(u_id)
    local r, g, b = color.r, color.g, color.b

    if not SG.brush then
        SG.brush = Draw:brush(Color(r, g, b))
        pcall(function()
            SG.brush:set_font(Idstring("fonts/font_medium"), 14)
            SG.brush:set_render_template(Idstring("OverlayVertexColorTextured"))
        end)
    end
    SG.brush:set_color(Color(r, g, b))

    local cam_up = cam_rot:z()
    local cam_right = cam_rot:x()
    
    local raw_name = (unit:base() and unit:base()._tweak_table) or "Guard"
    local text = string.upper(tostring(raw_name):gsub("^[a-z]+_", ""))
    
    if cfg.draw_unit_id then
        text = string.format("%s [%d]", text, u_id)
    end

    pcall(function()
        SG.brush:center_text(head_pos + Vector3(0, 0, 25), text, cam_right, -cam_up)
    end)

    -- Check if unit is walking and has navigation path
    local walk_action = (mov._active_actions and mov._active_actions[2]) or (mov._queued_actions and mov._queued_actions[1])
    local positions = walk_action and (walk_action._nav_path or walk_action._simplified_path)
    local app = Application

    if positions and #positions > 0 then
        local prev_pos = unit_pos
        local last_pos = nil

        for i = 1, #positions do
            local nav_pt = positions[i]
            local cur_pos = extract_nav_pos(nav_pt, walk_action)

            if cur_pos then
                if cfg.draw_guided_path and prev_pos then
                    pcall(function() app:draw_cylinder(cur_pos, prev_pos, 2, r, g, b) end)
                end
                prev_pos = cur_pos
                last_pos = cur_pos
            end
        end

        if last_pos then
            pcall(function() app:draw_sphere(last_pos, 10, r, g, b) end)
            if cfg.draw_nav_aura then
                local radius = (unit.bounding_sphere_radius and unit:bounding_sphere_radius()) or 35
                pcall(function() app:draw_circle(last_pos + Vector3(0, 0, 5), radius, r, g, b) end)
            end
            if cfg.draw_unit_id then
                pcall(function()
                    SG.brush:center_text(last_pos + Vector3(0, 0, 15), text .. " (DEST)", cam_right, -cam_up)
                end)
            end
        end
    else
        -- Standing / Idle guard
        if cfg.draw_nav_aura then
            pcall(function() app:draw_circle(unit_pos + Vector3(0, 0, 5), 35, r, g, b) end)
        end
    end
end

-- ─── 1. CopActionWalk Hook for Real-Time Path Interception ─────────────────────

if _G.CopActionWalk and not CopActionWalk._nt_gps_hooked then
    CopActionWalk._nt_gps_hooked = true
    Hooks:PostHook(CopActionWalk, "update", "NT_StealthGPS_CopWalkUpdate", function(self, t)
        local cfg = get_gps_settings()
        if not cfg.enabled or not NiceTrainer:IsInHeist() then return end

        local is_whisper = managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode()
        if not is_whisper and not cfg.loud_mode then return end

        local player = managers.player and managers.player:player_unit()
        if not alive(player) or not player:camera() then return end

        local unit = self._unit
        if not alive(unit) or not self._nav_path or #self._nav_path == 0 then return end

        local u_id = unit:id()
        local color = get_unit_color(u_id)
        local r, g, b = color.r, color.g, color.b
        local app = Application

        local prev_pos = unit:position()
        for i = 1, #self._nav_path do
            local cur_pos = extract_nav_pos(self._nav_path[i], self)
            if cur_pos then
                if cfg.draw_guided_path and prev_pos then
                    pcall(function() app:draw_cylinder(cur_pos, prev_pos, 2, r, g, b) end)
                end
                prev_pos = cur_pos
            end
        end
        if prev_pos then
            pcall(function() app:draw_sphere(prev_pos, 10, r, g, b) end)
        end
    end)
end

-- ─── 2. Render Loop in GameSetupUpdate ──────────────────────────────────────────

Hooks:Add("GameSetupUpdate", "NiceTrainer_StealthGPS_RenderLoop", function(t, dt)
    local cfg = get_gps_settings()
    if not cfg.enabled then return end
    if not NiceTrainer:IsInHeist() then return end

    local player = managers.player and managers.player:player_unit()
    if not alive(player) or not player:camera() then return end

    local is_whisper = managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode()
    if not is_whisper and not cfg.loud_mode then
        return
    end

    local cam_rot = player:camera():rotation()
    local player_pos = player:position()

    local slot_list = {}
    if cfg.draw_enemies then table.insert(slot_list, "enemies") end
    if cfg.draw_civilians then table.insert(slot_list, "civilians") end
    if #slot_list == 0 then return end

    local mask = managers.slot:get_mask(unpack(slot_list))
    local units_nearby = World:find_units_quick("sphere", player_pos, cfg.max_dist, mask) or {}

    for _, unit in ipairs(units_nearby) do
        if alive(unit) and not (unit:character_damage() and unit:character_damage():dead()) then
            render_unit_gps(unit, player, cam_rot, cfg)
        end
    end
end)

-- ─── 3. NiceTrainer Actions Registration (Stealth Tab) ─────────────────────────

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_enabled",
    text     = "Stealth GPS (Patrol Routes & Paths)",
    tooltip  = "Draws real-time 3D laser pathways, target destination markers, and patrol routes for all guards and civilians.",
    default  = false,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_enabled = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_enemies",
    text     = "Show Guard / Enemy Paths",
    tooltip  = "Displays patrol destination lines and next waypoints for security guards, cops, and specials.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_enemies = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_civilians",
    text     = "Show Civilian Walking Paths",
    tooltip  = "Displays pathing lines and destinations for moving civilians.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_civilians = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_guided_path",
    text     = "Draw 3D Route Cylinders",
    tooltip  = "Renders glowing color-coded 3D cylinder lines along the navigation nodes to destination.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_guided_path = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_unit_id",
    text     = "Display Unit Type & ID Labels",
    tooltip  = "Displays text labels above heads and destination points with guard type and internal unit ID.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_unit_id = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_nav_aura",
    text     = "Draw Destination Range Rings",
    tooltip  = "Draws circular rings on the floor around future destination nodes.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_nav_aura = state
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "slider",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_distance",
    text     = "GPS Detection Range (Meters)",
    tooltip  = "Maximum distance in meters to render GPS pathways around player.",
    min      = 10,
    max      = 200,
    step     = 5,
    default  = 100,
    save     = true,
    callback = function(val)
        NiceTrainer.Settings.stealth_gps_distance = val
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Stealth GPS & Patrol Visualizer",
    badge    = "client",
    id       = "stealth_gps_loud_mode",
    text     = "Allow GPS in Loud Assault",
    tooltip  = "Keep path visualizers active even after alarm goes off during loud assault waves.",
    default  = false,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.stealth_gps_loud_mode = state
    end
})
