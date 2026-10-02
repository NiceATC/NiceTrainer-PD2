-- ─── Vision Shaders & Cinematic Freecam ─────────────────────────────────────────
-- 1. Native Night & Thermal Vision Shaders (Green NVG, Blue NVG, Thermal Heat, Sin City, Matrix, etc.)
-- 2. Cinematic Free Flight Camera (Freecam with speed & rotation control)

local _vision_ambient_key = CoreEnvironmentFeeder and CoreEnvironmentFeeder.PostAmbientColorFeeder and CoreEnvironmentFeeder.PostAmbientColorFeeder.DATA_PATH_KEY
local _orig_color_grading = nil
local _is_vision_active   = false

local SHADER_MODES = {
    { text = "Off (Default)",                 effect = nil,                        light = 0.0 },
    { text = "Night Vision (Classic Green)",   effect = "color_night_vision",       light = 0.7 },
    { text = "Night Vision (Blue High-Vis)",  effect = "color_night_vision_blue",  light = 0.7 },
    { text = "Thermal Heat Vision",           effect = "color_heat",               light = 0.5 },
    { text = "Sin City (Noir B&W)",           effect = "color_sin",                light = 0.3 },
    { text = "Matrix Cyberpunk (Green Code)", effect = "color_matrix",             light = 0.4 },
    { text = "Sepia Vintage",                 effect = "color_sepia",              light = 0.2 },
    { text = "Cinematic Vibrant",             effect = "color_nice",               light = 0.3 },
    { text = "Sunset Strip",                  effect = "color_sunsetstrip",        light = 0.3 },
    { text = "Black Hawk Down",               effect = "color_bhd",                light = 0.4 }
}

local SHADER_OPTIONS = {}
for _, s in ipairs(SHADER_MODES) do
    table.insert(SHADER_OPTIONS, s.text)
end

local function ensure_thermal_contour_types()
    if not _G.ContourExt then return end
    if not ContourExt._types.nt_thermal_vision then
        ContourExt._types.nt_thermal_vision = {
            material_swap_required = true,
            priority = 7,
            color = Vector3(1, 0.25, 0.05)
        }
        if ContourExt.indexed_types then
            table.insert(ContourExt.indexed_types, "nt_thermal_vision")
        end
    end
end

local _thermal_active = false
local _last_thermal_check = 0

local function clear_thermal_contours()
    pcall(function()
        if managers.enemy then
            for _, data in pairs(managers.enemy:all_enemies() or {}) do
                local u = data.unit
                if alive(u) and u:contour() and u:base() and u:base()._nt_thermal_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:base()._nt_thermal_color = nil
                end
            end
            for _, data in pairs(managers.enemy:all_civilians() or {}) do
                local u = data.unit
                if alive(u) and u:contour() and u:base() and u:base()._nt_thermal_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:base()._nt_thermal_color = nil
                end
            end
        end
    end)
end

local function update_thermal_heat_contours(t, dt)
    if not _thermal_active then return end
    if not managers.enemy then return end

    _last_thermal_check = _last_thermal_check + (dt or 0.033)
    if _last_thermal_check < 0.2 then return end
    _last_thermal_check = 0

    ensure_thermal_contour_types()

    local player = managers.player and managers.player:player_unit()

    -- 1. Scan and highlight all living enemies & police
    for _, data in pairs(managers.enemy:all_enemies() or {}) do
        local u = data.unit
        if alive(u) and u:contour() and u:base() then
            local dmg = u:character_damage()
            local is_dead = dmg and dmg.dead and dmg:dead()
            if not is_dead then
                local brain = u:brain()
                local is_converted = brain and brain._logic_data and brain._logic_data.is_converted
                local heat_color
                
                if is_converted then
                    -- Friendly convert: Cool green body heat
                    heat_color = Vector3(0.2, 0.95, 0.4)
                else
                    local tw = u:base()._tweak_table
                    local tw_str = tw and string.lower(tostring(tw)) or ""
                    
                    if tw_str:find("tank", 1, true) or tw_str:find("bulldozer", 1, true) or tw_str:find("taser", 1, true) 
                        or tw_str:find("medic", 1, true) or tw_str:find("shield", 1, true) or tw_str:find("spooc", 1, true) 
                        or tw_str:find("cloaker", 1, true) or tw_str:find("sniper", 1, true) then
                        -- Special Enemy: Super-hot yellow/white signature (High armor / high metabolism)
                        heat_color = Vector3(1.0, 0.95, 0.25)
                    else
                        -- Regular Enemy / Guard: Hot glowing orange/red body heat
                        heat_color = Vector3(1.0, 0.25, 0.05)
                    end
                end

                if u:base()._nt_thermal_color ~= heat_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:contour():add("nt_thermal_vision", false, nil, heat_color)
                    u:base()._nt_thermal_color = heat_color
                end
            else
                -- Dead corpse: Body cools down, remove thermal contour
                if u:base()._nt_thermal_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:base()._nt_thermal_color = nil
                end
            end
        end
    end

    -- 2. Scan and highlight all living civilians
    for _, data in pairs(managers.enemy:all_civilians() or {}) do
        local u = data.unit
        if alive(u) and u:contour() and u:base() then
            local dmg = u:character_damage()
            local is_dead = dmg and dmg.dead and dmg:dead()
            if not is_dead then
                -- Civilian: Warm living amber/orange heat
                local heat_color = Vector3(1.0, 0.60, 0.12)
                if u:base()._nt_thermal_color ~= heat_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:contour():add("nt_thermal_vision", false, nil, heat_color)
                    u:base()._nt_thermal_color = heat_color
                end
            else
                if u:base()._nt_thermal_color then
                    u:contour():remove("nt_thermal_vision", false)
                    u:base()._nt_thermal_color = nil
                end
            end
        end
    end
end

local function apply_vision_shader(idx)
    idx = idx or NiceTrainer.Settings.vision_shader_idx or 1
    local mode = SHADER_MODES[idx] or SHADER_MODES[1]
    local player = managers.player and managers.player:player_unit()

    if not mode.effect then
        -- Turn OFF
        if _is_vision_active then
            pcall(function()
                if _vision_ambient_key and managers.viewport then
                    managers.viewport:destroy_global_environment_modifier(_vision_ambient_key)
                end
                local restore_cg = _orig_color_grading or "color_payday"
                if managers.environment_controller then
                    managers.environment_controller:set_default_color_grading(restore_cg, true)
                    managers.environment_controller:refresh_render_settings()
                end
                if alive(player) and player:sound() then
                    player:sound():play("night_vision_off", nil, false)
                end
            end)
            _is_vision_active = false
        end
        if _thermal_active then
            _thermal_active = false
            clear_thermal_contours()
        end
        return
    end

    -- Turn ON / Switch Shader
    pcall(function()
        if not _is_vision_active and managers.environment_controller then
            _orig_color_grading = managers.environment_controller:default_color_grading()
        end

        if _vision_ambient_key and managers.viewport then
            if _is_vision_active then
                managers.viewport:destroy_global_environment_modifier(_vision_ambient_key)
            end
            if mode.light > 0 then
                local function light_modifier(handler, feeder)
                    local base_light = feeder._target and mvector3.copy(feeder._target) or Vector3()
                    local l = mode.light
                    return base_light + Vector3(l, l, l)
                end
                managers.viewport:create_global_environment_modifier(_vision_ambient_key, true, light_modifier)
            end
        end

        if managers.environment_controller then
            managers.environment_controller:set_default_color_grading(mode.effect, true)
            managers.environment_controller:refresh_render_settings()
        end

        if alive(player) and player:sound() then
            player:sound():play("night_vision_on", nil, false)
        end
        _is_vision_active = true

        if mode.effect == "color_heat" then
            _thermal_active = true
            ensure_thermal_contour_types()
            update_thermal_heat_contours(0, 1)
        else
            if _thermal_active then
                _thermal_active = false
                clear_thermal_contours()
            end
        end
    end)
end

-- Hook game update for thermal contour tracking
Hooks:Add("GameSetupUpdate", "NiceTrainer_ThermalVision_Update", function(t, dt)
    if _thermal_active then
        update_thermal_heat_contours(t, dt)
    end
end)

-- ============================================================================
-- Cinematic Freecam (Free Flight Camera)
-- ============================================================================
local _freeflight_instance = nil
local _freecam_unlocked = false

local function ensure_freeflight_unlocked()
    local gsm = _G.game_state_machine or (_G.setup and _G.setup.game_state_machine and _G.setup:game_state_machine())
    if gsm and gsm:current_state() then
        local curr = gsm:current_state()
        if not curr.allow_freeflight or not curr:allow_freeflight() then
            curr.allow_freeflight = function() return true end
        end
    end
    pcall(function()
        local cigs = core:import("CoreInternalGameState")
        if cigs and cigs.GameState then
            cigs.GameState.allow_freeflight = function() return true end
        end
    end)
end

local function get_or_create_freeflight()
    if _freeflight_instance then
        return _freeflight_instance
    end

    if _G.setup and _G.setup.freeflight and _G.setup:freeflight() then
        _freeflight_instance = _G.setup:freeflight()
        return _freeflight_instance
    end

    local gsm = _G.game_state_machine or (_G.setup and _G.setup.game_state_machine and _G.setup:game_state_machine())
    local vpm = managers and managers.viewport
    local cm = managers and managers.controller

    if not gsm or not vpm or not cm then
        return nil
    end

    local FFClass = nil
    pcall(function()
        local ff_mod = core:import("FreeFlight")
        FFClass = ff_mod and ff_mod.FreeFlight
    end)
    if not FFClass then
        pcall(function()
            local core_ff = core:import("CoreFreeFlight")
            FFClass = core_ff and core_ff.FreeFlight
        end)
    end

    if FFClass then
        local success, instance = pcall(function()
            return FFClass:new(gsm, vpm, cm)
        end)
        if success and instance then
            _freeflight_instance = instance
            if _G.setup then
                _G.setup.__freeflight = instance
            end
            return _freeflight_instance
        end
    end

    return nil
end

-- Hook FreeFlight disable to sync toggle UI
pcall(function()
    local ff_mod = core:import("FreeFlight")
    local FFClass = ff_mod and ff_mod.FreeFlight
    if not FFClass then
        local core_ff = core:import("CoreFreeFlight")
        FFClass = core_ff and core_ff.FreeFlight
    end
    if FFClass and not FFClass._nt_hooked then
        FFClass._nt_hooked = true
        local orig_disable = FFClass.disable
        function FFClass:disable(...)
            orig_disable(self, ...)
            NiceTrainer.Settings.freecam_active = false
            if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freecam_active then
                NiceTrainer._toggle_elements.freecam_active(false)
            end
        end
    end
end)

local function set_freecam_state(enabled)
    if not NiceTrainer:IsInHeist() then
        if enabled then
            NiceTrainer:Toast("Cinematic Freecam is only available during a heist.")
            if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freecam_active then
                NiceTrainer._toggle_elements.freecam_active(false)
            end
            NiceTrainer.Settings.freecam_active = false
        end
        return
    end

    ensure_freeflight_unlocked()
    local ff = get_or_create_freeflight()
    if not ff then
        NiceTrainer:Toast("Freeflight camera unavailable in current game state.")
        if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freecam_active then
            NiceTrainer._toggle_elements.freecam_active(false)
        end
        NiceTrainer.Settings.freecam_active = false
        return
    end

    if enabled == nil then
        enabled = not ff:enabled()
    end

    pcall(function()
        if enabled then
            if not ff:enabled() then
                ff:enable()
            end
        else
            if ff:enabled() then
                ff:disable()
            end
        end
    end)

    local is_on = ff:enabled()
    NiceTrainer.Settings.freecam_active = is_on
    if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freecam_active then
        NiceTrainer._toggle_elements.freecam_active(is_on)
    end
end

-- Update FreeFlight in game loops when active
Hooks:Add("GameSetupUpdate", "NiceTrainer_FreeFlight_Update", function(t, dt)
    if _freeflight_instance and _freeflight_instance:enabled() then
        pcall(function()
            _freeflight_instance:update(t, dt)
        end)
    end
end)

Hooks:Add("GameSetupPausedUpdate", "NiceTrainer_FreeFlight_PausedUpdate", function(t, dt)
    if _freeflight_instance and _freeflight_instance:enabled() then
        pcall(function()
            if _freeflight_instance.paused_update then
                _freeflight_instance:paused_update(t, dt)
            elseif _freeflight_instance.update then
                _freeflight_instance:update(t, dt)
            end
        end)
    end
end)

-- Reset state on session transition
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_VisionFreecam_Load", function()
    _freeflight_instance = nil
    NiceTrainer.Settings.freecam_active = false
    if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freecam_active then
        NiceTrainer._toggle_elements.freecam_active(false)
    end

    if NiceTrainer.Settings.vision_shader_enabled and (NiceTrainer.Settings.vision_shader_idx or 1) > 1 then
        apply_vision_shader(NiceTrainer.Settings.vision_shader_idx)
    end
end)

-- ============================================================================
-- Registrations (Visuals Tab)
-- ============================================================================

NiceTrainer:RegisterAction("Visuals", {
    type            = "toggle_multichoice",
    category        = "SHADERS & CAMERA",
    badge           = "client",
    id              = "vision_shader_enabled",
    text            = "Vision Shaders & Night Vision",
    options         = SHADER_OPTIONS,
    choice_id       = "vision_shader_idx",
    choice_default  = 1,
    default         = false,
    tooltip         = "Applies night vision, thermal heat contrast, or custom cinematic shaders with ambient brightness boost.",
    callback        = function(state)
        if state then
            apply_vision_shader(NiceTrainer.Settings.vision_shader_idx or 2)
        else
            apply_vision_shader(1)
        end
    end,
    choice_callback = function(idx, val)
        NiceTrainer.Settings.vision_shader_idx = idx
        NiceTrainer:Save()
        if NiceTrainer.Settings.vision_shader_enabled then
            apply_vision_shader(idx)
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "SHADERS & CAMERA",
    badge    = "client",
    id       = "freecam_active",
    text     = "Cinematic Freecam",
    save     = false,
    default  = false,
    tooltip  = "Decouples camera to fly freely. Use WASD / Space / Ctrl / Mouse / F / C. Available only in heist.",
    callback = function(state)
        set_freecam_state(state)
    end
})

