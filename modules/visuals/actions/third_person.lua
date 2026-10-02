-- ─── Pure Third Person Camera (Visuals Tab) ──────────────────────────────────
-- Third-person camera system with shoulder offset, wall-collision raycast, and adaptive crosshair.
-- No husk/dummy unit spawned in the world.

NiceTrainer._tp_cam = NiceTrainer._tp_cam or {}

local function get_tp_settings()
    return {
        enabled = NiceTrainer.Settings.third_person_enabled or false,
        cam_x = NiceTrainer.Settings.third_person_cam_x or 60,
        cam_y = NiceTrainer.Settings.third_person_cam_y or 140,
        cam_z = NiceTrainer.Settings.third_person_cam_z or 10,
        first_person_on_steelsight = (NiceTrainer.Settings.third_person_steelsight_fp ~= false),
        first_person_on_downed = NiceTrainer.Settings.third_person_downed_fp or false,
        third_person_crosshair = (NiceTrainer.Settings.third_person_crosshair ~= false),
        third_person_crosshair_size = 32,
        third_person_crosshair_style = 1
    }
end

-- ─── 1. PlayerCamera Positioning & Crosshair Hooks ─────────────────────────────

local mvec_set = mvector3.set
local mvec_add = mvector3.add
local mvec_mul = mvector3.multiply
local mvec_rot_with = mvector3.rotate_with
local mvec_len = mvector3.length
local mvec = Vector3()

local function install_camera_hooks()
    if PlayerCamera and not PlayerCamera._nt_tp_hooked then
        PlayerCamera._nt_tp_hooked = true

        Hooks:PostHook(PlayerCamera, "init", "NT_PlayerCamera_InitTP", function(self)
            self._third_person = false
            self._tp_forward = Vector3()
            self._slot_mask = managers.slot:get_mask("world_geometry")
            self._slot_mask_all = managers.slot:get_mask("bullet_impact_targets_no_criminals")
            
            local hud = managers.hud and managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
            if hud and hud.panel then
                self._crosshair = hud.panel:bitmap({
                    name = "nt_third_person_crosshair",
                    texture = "units/pd2_dlc1/weapons/wpn_effects_textures/wpn_sight_reticle_l_1_green_il",
                    blend_mode = "add",
                    w = 32,
                    h = 32,
                    visible = false
                })
            end
            self:refresh_tp_cam_settings()
        end)

        function PlayerCamera:refresh_tp_cam_settings()
            local cfg = get_tp_settings()
            self._tp_cam_dir = Vector3(cfg.cam_x, -cfg.cam_y, cfg.cam_z)
            self._tp_cam_dis = mvec_len(self._tp_cam_dir)
            if self._tp_cam_dis > 0 then
                mvec_mul(self._tp_cam_dir, 1 / self._tp_cam_dis)
            end

            if self._crosshair and alive(self._crosshair) then
                local data = tweak_data.gui and tweak_data.gui.weapon_texture_switches and tweak_data.gui.weapon_texture_switches.types.sight[cfg.third_person_crosshair_style] or tweak_data.gui.weapon_texture_switches.types.sight[1]
                local suffix = tweak_data.gui and tweak_data.gui.weapon_texture_switches and tweak_data.gui.weapon_texture_switches.types.sight.suffix or ""
                self._crosshair_path_1 = data.texture_path:gsub(suffix .. "$", "_green" .. suffix)
                self._crosshair_path_2 = data.texture_path:gsub(suffix .. "$", "_yellow" .. suffix)
                self._crosshair:set_image(self._crosshair_path_1)
                self._crosshair:set_size(cfg.third_person_crosshair_size, cfg.third_person_crosshair_size)
                self._crosshair:set_visible(self:third_person() and cfg.third_person_crosshair)
            end
        end

        function PlayerCamera:check_set_third_person_position(pos, rot)
            if self:first_person() or _G.IS_VR then return end
            local cfg = get_tp_settings()

            mvec_set(mvec, self._tp_cam_dir)
            mvec_rot_with(mvec, rot)
            local ray = World:raycast("ray", pos, pos + mvec * (self._tp_cam_dis + 20), "slot_mask", self._slot_mask)
            mvec_mul(mvec, ray and (ray.distance - 20) or self._tp_cam_dis)
            mvec_add(mvec, pos)
            self._camera_controller:set_camera(mvec)

            -- Adaptive crosshair aiming ray
            if self._crosshair and alive(self._crosshair) and self._crosshair:visible() then
                mvec_set(mvec, self:forward())
                local cross_ray = World:raycast("ray", self:position(), self:position() + mvec * 10000, "slot_mask", self._slot_mask_all)
                mvec_mul(mvec, cross_ray and cross_ray.distance or 10000)
                mvec_add(mvec, self:position())
                mvec_set(mvec, managers.hud._workspace:world_to_screen(self._camera_object, mvec))
                self._crosshair:set_center(mvec.x, mvec.y)
                if cross_ray and cross_ray.unit and managers.enemy and managers.enemy:is_enemy(cross_ray.unit) then
                    self._crosshair:set_image(self._crosshair_path_2)
                else
                    self._crosshair:set_image(self._crosshair_path_1)
                end
            end
        end

        Hooks:PostHook(PlayerCamera, "set_position", "NT_TP_SetPosition", function(self, pos)
            self:check_set_third_person_position(pos, self:rotation())
        end)

        Hooks:PostHook(PlayerCamera, "set_rotation", "NT_TP_SetRotation", function(self, rot)
            self:check_set_third_person_position(self:position(), rot)
        end)

        Hooks:PreHook(PlayerCamera, "destroy", "NT_TP_Destroy", function(self)
            if self._crosshair and alive(self._crosshair) then
                local hud = managers.hud and managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
                if hud and hud.panel then hud.panel:remove(self._crosshair) end
            end
        end)

        function PlayerCamera:toggle_third_person(force)
            if self._mode_locked and not force then return end
            self._mode_locked = not self._mode_locked and force
            if self:first_person() then
                self._toggled_fp = false
                self:set_third_person()
            else
                self._toggled_fp = true
                self:set_first_person()
            end
        end

        function PlayerCamera:set_first_person()
            self._third_person = false
            if self._crosshair and alive(self._crosshair) then
                self._crosshair:set_visible(false)
            end
            if alive(self._camera_unit) and self._camera_unit:base() then
                self._camera_unit:base()._wants_fp = nil
            end
        end

        function PlayerCamera:set_third_person()
            if not self._toggled_fp then
                self._third_person = true
                local cfg = get_tp_settings()
                if self._crosshair and alive(self._crosshair) then
                    self._crosshair:set_visible(cfg.third_person_crosshair)
                end
            end
            if alive(self._camera_unit) and self._camera_unit:base() then
                self._camera_unit:base()._wants_fp = nil
            end
            self._skip_frames = 4
        end

        function PlayerCamera:first_person()
            return not self._third_person
        end

        function PlayerCamera:third_person()
            return self._third_person
        end
    end
end

install_camera_hooks()

-- ─── 2. Gameplay State Hooks (ADS, Bleedout) ───────────────────────────────────

if _G.FPCameraPlayerBase and not FPCameraPlayerBase._nt_tp_hooked then
    FPCameraPlayerBase._nt_tp_hooked = true
    Hooks:PostHook(FPCameraPlayerBase, "_update_stance", "NT_TP_UpdateStance", function(self)
        if self._wants_fp ~= nil then
            local cam = alive(self._parent_unit) and self._parent_unit:camera()
            if not cam then return end
            if self._wants_fp and not self._shoulder_stance.transition then
                cam:set_first_person()
            elseif not self._wants_fp then
                cam:set_third_person()
            end
        end
    end)
end

if _G.PlayerStandard and not PlayerStandard._nt_tp_hooked then
    PlayerStandard._nt_tp_hooked = true
    Hooks:PreHook(PlayerStandard, "enter", "NT_TP_EnterStandard", function(self, state_data)
        if state_data._was_in_tp and self._unit:camera() then
            self._unit:camera():set_third_person()
            state_data._was_in_tp = nil
        end
    end)

    Hooks:PostHook(PlayerStandard, "_start_action_steelsight", "NT_TP_StartSight", function(self)
        local cfg = get_tp_settings()
        if self._state_data.in_steelsight and cfg.first_person_on_steelsight then
            if alive(self._camera_unit) and self._camera_unit:base() then
                self._camera_unit:base()._wants_fp = true
            end
        end
    end)

    Hooks:PostHook(PlayerStandard, "_end_action_steelsight", "NT_TP_EndSight", function(self)
        local cfg = get_tp_settings()
        if cfg.first_person_on_steelsight then
            if alive(self._camera_unit) and self._camera_unit:base() then
                self._camera_unit:base()._wants_fp = false
            end
        end
    end)
end

if _G.PlayerBleedOut and not PlayerBleedOut._nt_tp_hooked then
    PlayerBleedOut._nt_tp_hooked = true
    Hooks:PreHook(PlayerBleedOut, "enter", "NT_TP_EnterBleedOut", function(self)
        local cfg = get_tp_settings()
        if cfg.first_person_on_downed and self._unit:camera() and self._unit:camera():third_person() then
            self._was_in_tp = true
            self._unit:camera():toggle_third_person()
        end
    end)

    Hooks:PreHook(PlayerBleedOut, "exit", "NT_TP_ExitBleedOut", function(self)
        if self._was_in_tp and self._unit:camera() and self._unit:camera():first_person() then
            self._was_in_tp = nil
            self._unit:camera():toggle_third_person()
        end
    end)
end

-- Refresh state on heist start/load
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NT_ThirdPerson_OnLoad", function()
    install_camera_hooks()
    local cfg = get_tp_settings()
    local player = managers.player and managers.player:local_player()
    if alive(player) and player:camera() then
        if cfg.enabled then
            player:camera()._toggled_fp = false
            player:camera():set_third_person()
            player:camera():refresh_tp_cam_settings()
        else
            player:camera()._toggled_fp = true
            player:camera():set_first_person()
        end
    end
end)

-- ─── 3. Action Registrations (Visuals Tab) ─────────────────────────────────────

local function apply_third_person_state(state)
    NiceTrainer.Settings.third_person_enabled = state
    local player = managers.player and managers.player:local_player()
    if alive(player) and player:camera() then
        if state then
            player:camera()._toggled_fp = false
            player:camera():set_third_person()
            player:camera():refresh_tp_cam_settings()
        else
            player:camera()._toggled_fp = true
            player:camera():set_first_person()
        end
    end
end

local function toggle_third_person_action()
    if not NiceTrainer:IsInHeist() then return end
    local cur = NiceTrainer.Settings.third_person_enabled or false
    NiceTrainer:SetToggleState("third_person_enabled", not cur)
    apply_third_person_state(not cur)
end

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Third Person Camera",
    badge    = "client",
    id       = "third_person_enabled",
    text     = "Third Person Mode",
    tooltip  = "Switches player camera to third-person view with customizable shoulder offset and crosshair.",
    default  = false,
    save     = true,
    callback = function(state)
        apply_third_person_state(state)
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "keybind",
    category    = "Third Person Camera",
    badge       = "client",
    id          = "third_person_hotkey",
    text        = "Third Person Hotkey",
    tooltip     = "Press this key in-game to toggle between first-person and third-person camera instantly.",
    default     = "",
    callback    = function()
        toggle_third_person_action()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "slider",
    category    = "Third Person Camera",
    id          = "third_person_cam_x",
    text        = "Camera Shoulder Offset (X)",
    tooltip     = "Horizontal distance from player center (positive = right shoulder, negative = left shoulder).",
    min         = -150,
    max         = 150,
    step        = 5,
    default     = 60,
    save        = true,
    callback    = function(val)
        NiceTrainer.Settings.third_person_cam_x = val
        local player = managers.player and managers.player:local_player()
        if alive(player) and player:camera() then
            player:camera():refresh_tp_cam_settings()
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "slider",
    category    = "Third Person Camera",
    id          = "third_person_cam_y",
    text        = "Camera Distance (Y)",
    tooltip     = "Distance behind the player.",
    min         = 40,
    max         = 350,
    step        = 10,
    default     = 140,
    save        = true,
    callback    = function(val)
        NiceTrainer.Settings.third_person_cam_y = val
        local player = managers.player and managers.player:local_player()
        if alive(player) and player:camera() then
            player:camera():refresh_tp_cam_settings()
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "slider",
    category    = "Third Person Camera",
    id          = "third_person_cam_z",
    text        = "Camera Height (Z)",
    tooltip     = "Vertical elevation above player shoulder.",
    min         = -50,
    max         = 100,
    step        = 5,
    default     = 10,
    save        = true,
    callback    = function(val)
        NiceTrainer.Settings.third_person_cam_z = val
        local player = managers.player and managers.player:local_player()
        if alive(player) and player:camera() then
            player:camera():refresh_tp_cam_settings()
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Third Person Camera",
    id       = "third_person_crosshair",
    text     = "Third Person Crosshair",
    tooltip  = "Displays an adaptive 3D crosshair with enemy target highlighting in third person.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.third_person_crosshair = state
        local player = managers.player and managers.player:local_player()
        if alive(player) and player:camera() then
            player:camera():refresh_tp_cam_settings()
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Third Person Camera",
    id       = "third_person_steelsight_fp",
    text     = "Switch to First Person on Aim (ADS)",
    tooltip  = "Automatically switches to first-person view while aiming down weapon sights.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.third_person_steelsight_fp = state
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Third Person Camera",
    id       = "third_person_downed_fp",
    text     = "Switch to First Person on Downed",
    tooltip  = "Switches to first person when downed, tased, or incapacitated.",
    default  = false,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.third_person_downed_fp = state
    end
})
