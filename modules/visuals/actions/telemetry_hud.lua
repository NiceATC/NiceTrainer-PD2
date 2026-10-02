-- ─── Telemetry, Detection Rays & Technical HUD ──────────────────────────────────
-- Covers:
-- 1. Detection Rays & Cones (Accurate visible vision cones on guards & security cameras)
-- 2. Early Warning for Snipers (Laser Tracing) & Cloaker Charge Alert Banner
-- 3. Live Stealth Telemetry HUD (Real-time Pagers, Civilians, Guards, Cameras)

local _telemetry_ws = nil
local _telemetry_panel = nil
local _cloaker_warning_t = 0

local function init_telemetry_workspace()
    if _telemetry_ws and alive(_telemetry_ws) then return end
    pcall(function()
        _telemetry_ws = Overlay:newgui():create_screen_workspace()
        _telemetry_panel = _telemetry_ws:panel()
    end)
end

-- ============================================================================
-- 1. Cloaker Charge & Sniper Laser Detection
-- ============================================================================
if _G.CopBrain and not CopBrain._nt_cloaker_alert_hooked then
    CopBrain._nt_cloaker_alert_hooked = true
    Hooks:PostHook(CopBrain, "action_request", "NiceTrainer_Telemetry_CloakerCharge", function(self, action_desc)
        if not NiceTrainer.Settings.sniper_cloaker_alert_enabled then return end
        if action_desc and (action_desc.type == "spooc" or action_desc.body_part == 1 and action_desc.type == "spooc_attack") then
            _cloaker_warning_t = Application:time() + 3.0
            pcall(function()
                if managers.player and managers.player:player_unit() then
                    managers.player:player_unit():sound():play("prompt_enter", nil, false)
                end
            end)
            NiceTrainer:Toast("⚠️ WARNING: CLOAKER IS CHARGING!", Color(1, 0.2, 0.2))
        end
    end)
end

-- ============================================================================
-- 2. Live Stealth Telemetry HUD Panel
-- ============================================================================
local _stealth_hud_panel = nil
local _hud_txt_pagers   = nil
local _hud_txt_civs     = nil
local _hud_txt_guards   = nil
local _hud_txt_cams     = nil

local function build_stealth_hud()
    init_telemetry_workspace()
    if not _telemetry_panel or not alive(_telemetry_panel) then return end
    if _stealth_hud_panel and alive(_stealth_hud_panel) then return end

    local res = RenderSettings.resolution
    local w, h = 300, 68
    local x = res.x - w - 20
    local y = 20

    _stealth_hud_panel = _telemetry_panel:panel({ x = x, y = y, w = w, h = h, layer = 40 })
    _stealth_hud_panel:rect({ color = Color(0.04, 0.05, 0.08), alpha = 0.85, layer = 0 })
    _stealth_hud_panel:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.5, h = 1, layer = 1 })
    _stealth_hud_panel:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.5, y = h - 1, h = 1, layer = 1 })
    _stealth_hud_panel:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.5, w = 1, layer = 1 })
    _stealth_hud_panel:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.5, x = w - 1, w = 1, layer = 1 })

    -- Title Bar
    _stealth_hud_panel:text({
        text      = "LIVE HEIST TELEMETRY",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 12,
        color     = Color(0.3, 0.7, 1.0),
        x = 10, y = 4, layer = 2
    })

    _hud_txt_pagers = _stealth_hud_panel:text({
        text      = "PAGERS: 4/4",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 14,
        color     = Color(0.2, 1.0, 0.3),
        x = 10, y = 22, layer = 2
    })

    _hud_txt_civs = _stealth_hud_panel:text({
        text      = "CIVILIANS: 0/0",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 14,
        color     = Color(0.9, 0.9, 0.9),
        x = 155, y = 22, layer = 2
    })

    _hud_txt_guards = _stealth_hud_panel:text({
        text      = "GUARDS: 0",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 14,
        color     = Color(1.0, 0.5, 0.3),
        x = 10, y = 42, layer = 2
    })

    _hud_txt_cams = _stealth_hud_panel:text({
        text      = "CAMERAS: 0",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 14,
        color     = Color(0.3, 0.8, 1.0),
        x = 155, y = 42, layer = 2
    })
end

local function destroy_stealth_hud()
    if _stealth_hud_panel and alive(_stealth_hud_panel) then
        pcall(function() _stealth_hud_panel:parent():remove(_stealth_hud_panel) end)
    end
    _stealth_hud_panel = nil
    _hud_txt_pagers    = nil
    _hud_txt_civs      = nil
    _hud_txt_guards    = nil
    _hud_txt_cams      = nil
end

local function update_stealth_hud()
    if not _stealth_hud_panel or not alive(_stealth_hud_panel) then return end

    local pagers_used = (managers.groupai and managers.groupai:state() and managers.groupai:state()._nr_successful_alarm_pager_bluffs) or 0
    local pagers_left = math.max(0, 4 - pagers_used)

    if alive(_hud_txt_pagers) then
        _hud_txt_pagers:set_text(string.format("PAGERS: %d/4", pagers_left))
        if pagers_left >= 2 then
            _hud_txt_pagers:set_color(Color(0.2, 1.0, 0.3))
        elseif pagers_left == 1 then
            _hud_txt_pagers:set_color(Color(1.0, 0.8, 0.1))
        else
            _hud_txt_pagers:set_color(Color(1.0, 0.2, 0.2))
        end
    end

    local civs = (managers.enemy and managers.enemy:all_civilians()) or {}
    local total_civs = 0
    local tied_civs  = 0
    for _, data in pairs(civs) do
        if alive(data.unit) and not data.unit:character_damage():dead() then
            total_civs = total_civs + 1
            if data.unit:anim_data() and (data.unit:anim_data().tied or data.unit:anim_data().hands_tied or data.unit:anim_data().hands_back) then
                tied_civs = tied_civs + 1
            end
        end
    end

    if alive(_hud_txt_civs) then
        _hud_txt_civs:set_text(string.format("CIVS: %d/%d Tied", tied_civs, total_civs))
    end

    local enemies = (managers.enemy and managers.enemy:all_enemies()) or {}
    local guards_alive = 0
    for _, data in pairs(enemies) do
        if alive(data.unit) and not data.unit:character_damage():dead() then
            guards_alive = guards_alive + 1
        end
    end

    if alive(_hud_txt_guards) then
        _hud_txt_guards:set_text(string.format("GUARDS: %d Alive", guards_alive))
    end

    local cams = (SecurityCamera and SecurityCamera.cameras) or {}
    local cams_active = 0
    for _, u in pairs(cams) do
        if alive(u) and u:base() and u:base()._last_detect_t ~= nil and not u:base()._destroyed then
            cams_active = cams_active + 1
        end
    end

    if alive(_hud_txt_cams) then
        _hud_txt_cams:set_text(string.format("CAMS: %d Active", cams_active))
    end
end

-- ============================================================================
-- 3. Detection Rays & Visual Cones Drawing Loop (With Obstacle & Wall Clipping)
-- ============================================================================
local function draw_detection_rays(t, dt)
    if not NiceTrainer.Settings.detection_rays_enabled then return end
    local geom_mask = managers.slot and managers.slot:get_mask("world_geometry", "statics", "destructibles")
    local cam = managers.viewport and managers.viewport:get_current_camera()
    local cam_pos = cam and cam:position() or Vector3()

    -- 1. Security Cameras (Clips against walls)
    if SecurityCamera and SecurityCamera.cameras then
        for _, cam_unit in pairs(SecurityCamera.cameras) do
            if alive(cam_unit) and cam_unit:base() and cam_unit:base()._last_detect_t ~= nil and not cam_unit:base()._destroyed then
                local base = cam_unit:base()
                local look_obj = base._look_obj or cam_unit:get_object(Idstring("CameraLens")) or cam_unit:get_object(Idstring("Camera"))
                if look_obj then
                    local from = look_obj:position()
                    if mvector3.distance_sq(cam_pos, from) <= 16000000 then -- 40m cull
                        local fwd = base._look_fwd or look_obj:rotation():y()
                        local max_range = 1200 -- 12m standard camera vision range
                        local angle = 55 -- 55 degrees realistic FOV

                        -- Raycast forward to clip cone at walls/geometry
                        local ray = geom_mask and World:raycast("ray", from, from + fwd * max_range, "slot_mask", geom_mask)
                        local range = ray and ray.distance or max_range

                        if range > 20 then
                            local cone_base = from + fwd * range
                            local cone_rad  = math.min(math.tan(math.rad(angle * 0.5)) * range, 550)

                            local brush = Draw:brush(Color(0.12, 0.0, 0.75, 1.0))
                            brush:cone(from, cone_base, cone_rad, 16)
                            local center_brush = Draw:brush(Color(0.5, 0.0, 0.85, 1.0))
                            center_brush:cylinder(from, cone_base, 1.5)
                        end
                    end
                end
            end
        end
    end

    -- 2. Guard Vision Rays (60° stealth FOV, Clips against walls/obstacles)
    local enemies = (managers.enemy and managers.enemy:all_enemies()) or {}
    for _, data in pairs(enemies) do
        local u = data.unit
        if alive(u) and not u:character_damage():dead() and u:movement() then
            local anim = u:anim_data()
            local is_tied = anim and (anim.surrender or anim.tied or anim.hands_up)
            if not is_tied then
                local head = u:movement():m_head_pos()
                if mvector3.distance_sq(cam_pos, head) <= 12250000 then -- 35m cull
                    local fwd = (u:movement().detect_look_dir and u:movement():detect_look_dir()) or u:movement():m_fwd() or u:movement():m_rot():y()
                    if fwd and mvector3.length(fwd) > 0.01 then
                        local fwd_norm = Vector3(fwd.x, fwd.y, fwd.z)
                        mvector3.normalize(fwd_norm)
                        local max_range = 850 -- 8.5m realistic stealth vision range
                        local angle = 60 -- 60 degrees FOV

                        -- Raycast forward to stop vision cone at walls & obstacles
                        local ray = geom_mask and World:raycast("ray", head, head + fwd_norm * max_range, "slot_mask", geom_mask)
                        local range = ray and ray.distance or max_range

                        if range > 30 then
                            local cone_base = head + fwd_norm * range
                            local cone_rad  = math.min(math.tan(math.rad(angle * 0.5)) * range, 450)

                            local brush = Draw:brush(Color(0.10, 1.0, 0.65, 0.05))
                            brush:cone(head, cone_base, cone_rad, 16)
                            local center_brush = Draw:brush(Color(0.5, 1.0, 0.5, 0.0))
                            center_brush:cylinder(head, cone_base, 1.5)
                        end
                    end
                end
            end
        end
    end
end


local function draw_sniper_lasers(t, dt)
    if not NiceTrainer.Settings.sniper_cloaker_alert_enabled then return end
    local geom_mask = managers.slot and managers.slot:get_mask("world_geometry", "statics", "destructibles")
    local enemies = (managers.enemy and managers.enemy:all_enemies()) or {}
    for _, data in pairs(enemies) do
        local u = data.unit
        if alive(u) and not u:character_damage():dead() and u:base() and (u:base()._tweak_table == "sniper") then
            local from = u:movement() and u:movement():m_head_pos() or u:position()
            local weapon = u:inventory() and u:inventory():equipped_unit()
            if alive(weapon) and weapon:base() and weapon:base()._laser_unit and alive(weapon:base()._laser_unit) then
                from = weapon:base()._laser_unit:position()
            end
            local fwd = (u:movement() and u:movement().detect_look_dir and u:movement():detect_look_dir()) or (u:movement() and u:movement():m_fwd()) or Vector3(0, 0, 1)
            local to = from + fwd * 8000
            local ray = geom_mask and World:raycast("ray", from, to, "slot_mask", geom_mask)
            local target_pos = ray and ray.position or to
            local brush = Draw:brush(Color(0.8, 1.0, 0.0, 0.0))
            brush:cylinder(from, target_pos, 3)
        end
    end
end

-- ============================================================================
-- Main Telemetry Frame Update Hook
-- ============================================================================
Hooks:Add("GameSetupUpdate", "NiceTrainer_Telemetry_MainUpdate", function(t, dt)
    -- 1. Draw Detection Cones & Sniper Tracers
    draw_detection_rays(t, dt)
    draw_sniper_lasers(t, dt)

    -- 2. Live Stealth HUD Panel Update
    if NiceTrainer.Settings.stealth_telemetry_hud_enabled then
        if not _stealth_hud_panel then build_stealth_hud() end
        update_stealth_hud()
    else
        if _stealth_hud_panel then destroy_stealth_hud() end
    end
end)

-- Re-apply & recreate on level load
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Telemetry_Load", function()
    if NiceTrainer.Settings.stealth_telemetry_hud_enabled then
        build_stealth_hud()
    end
end)

-- ============================================================================
-- Registrations (Visuals Tab -> TELEMETRY & TECHNICAL HUD)
-- ============================================================================

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "TELEMETRY & TECHNICAL HUD",
    badge    = "client",
    id       = "detection_rays_enabled",
    text     = "Detection Rays & Vision Cones",
    default  = false,
    tooltip  = "Projects visible volumetric 3D vision cones and sightlines showing the exact angle and field of view for guards and security cameras.",
    callback = function(state)
        NiceTrainer.Settings.detection_rays_enabled = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "TELEMETRY & TECHNICAL HUD",
    badge    = "client",
    id       = "sniper_cloaker_alert_enabled",
    text     = "Sniper Laser Tracing & Cloaker Alert",
    default  = false,
    tooltip  = "Traces thick bright laser beams from snipers and triggers an instant alert banner when a Cloaker charges you.",
    callback = function(state)
        NiceTrainer.Settings.sniper_cloaker_alert_enabled = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "TELEMETRY & TECHNICAL HUD",
    badge    = "client",
    id       = "stealth_telemetry_hud_enabled",
    text     = "Live Stealth Telemetry HUD",
    default  = false,
    tooltip  = "Shows a sleek real-time HUD panel with remaining pagers, tied civilians, active guards and cameras.",
    callback = function(state)
        NiceTrainer.Settings.stealth_telemetry_hud_enabled = state
        NiceTrainer:Save()
        if not state then
            destroy_stealth_hud()
        else
            build_stealth_hud()
        end
    end
})
