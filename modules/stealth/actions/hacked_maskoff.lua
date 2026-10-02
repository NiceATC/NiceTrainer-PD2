-- Hacked Mask Off for NiceTrainer (Stealth Tab)
-- Enables full interaction, jumping, ducking, and sprint while in Mask Off without stamina bugs or weapon viewmodel glitches.

local orig = {}
local feature_enabled = false

local blocked_maskoff_redirect_keys = {
    [Idstring("start_running"):key()] = true,
    [Idstring("stop_running"):key()]  = true,
    [Idstring("idle"):key()]          = true,
    [Idstring("equip"):key()]         = true,
    [Idstring("recoil"):key()]        = true,
    ["start_running"]                 = true,
    ["stop_running"]                  = true,
    ["idle"]                          = true,
    ["equip"]                         = true,
    ["recoil"]                        = true,
}

local function is_unmasked_state()
    if not managers.player then return false end
    local state = managers.player:current_state()
    return state == "mask_off" or state == "civilian" or state == "clean"
end

-- ─── 1. Interaction Bypass ───────────────────────────────────────────────────

local function skip_mask_state_gate(self, movement_state)
    if movement_state == "mask_off" or movement_state == "civilian" or movement_state == "clean" then
        return true
    end
    if orig.BaseInteractionExt_is_in_required_state then
        return orig.BaseInteractionExt_is_in_required_state(self, movement_state)
    end
    return true
end

local function skip_mask_upgrade_gate(self, movement_state)
    if (movement_state == "mask_off" or movement_state == "civilian" or movement_state == "clean") and self._tweak_data.requires_mask_off_upgrade then
        return true
    end
    if orig.BaseInteractionExt_has_required_upgrade then
        return orig.BaseInteractionExt_has_required_upgrade(self, movement_state)
    end
    return true
end

-- ─── 2. Mask Off Movement Actions (No Empty Hands Visual Glitch) ────────────

local function real_duck_while_unmasked(self, t, input)
    if PlayerStandard and PlayerStandard._check_action_duck then
        return PlayerStandard._check_action_duck(self, t, input)
    end
end

local function real_run_while_unmasked(self, t, input)
    if PlayerStandard and PlayerStandard._check_action_run then
        return PlayerStandard._check_action_run(self, t, input)
    end
end

local function real_jump_while_unmasked(self, t, input)
    if PlayerStandard and PlayerStandard._check_action_jump then
        return PlayerStandard._check_action_jump(self, t, input)
    end
end

local function maskoff_start_action_running(self, t)
    if self._slowdown_run_prevent then
        self._running_wanted = false
        return
    end

    if not self._move_dir then
        self._running_wanted = true
        return
    end

    if self:on_ladder() or self:_on_zipline() then
        return
    end

    if self._shooting or self:_changing_weapon() or self:_is_meleeing() or self._use_item_expire_t or self._state_data.in_air or self:_is_throwing_projectile() or self:_is_charging_weapon() then
        self._running_wanted = true
        return
    end

    if self._state_data.ducking and not self:_can_stand() then
        self._running_wanted = true
        return
    end

    if not self:_can_run_directional() then
        return
    end

    self._running_wanted = false

    if managers.player:get_player_rule("no_run") then
        return
    end

    if not self._unit:movement():is_above_stamina_threshold() then
        return
    end

    if (not self._state_data.shake_player_start_running or not self._ext_camera:shaker():is_playing(self._state_data.shake_player_start_running)) and self._setting_use_headbob then
        self._state_data.shake_player_start_running = self._ext_camera:play_shaker("player_start_running", 0.75)
    end

    self:set_running(true)

    self._end_running_expire_t = nil
    self._start_running_t = t
    self._play_stop_running_anim = nil

    -- Do NOT play start_running redirect to prevent showing empty floating hands

    self:_interupt_action_steelsight(t)
    self:_interupt_action_ducking(t)
end

local function maskoff_end_action_running(self, t)
    if not self._end_running_expire_t then
        self._end_running_expire_t = t + 0.4
        -- Do NOT play stop_running redirect to prevent showing empty floating hands
    end
end

local function maskoff_start_action_jump(self, t, action_start_data)
    if self._running and not self._end_running_expire_t then
        self:_end_action_running(t)
    end

    self._jump_t = t

    local jump_vec = action_start_data.jump_vel_z * math.UP
    self._unit:mover():jump()

    if self._move_dir then
        local move_dir_clamp = self._move_dir:normalized() * math.min(1, self._move_dir:length())
        self._last_velocity_xy = move_dir_clamp * action_start_data.jump_vel_xy
        self._jump_vel_xy = mvector3.copy(self._last_velocity_xy)
    else
        self._last_velocity_xy = Vector3()
        self._jump_vel_xy = Vector3()
    end

    self:_perform_jump(jump_vec)
end

-- ─── 3. Action Lifecycle & Stamina Fix ───────────────────────────────────────

local function patched_maskoff_update_check_actions(self, t, dt)
    local input = self:_get_input(t, dt)

    self:_determine_move_direction()

    -- Process running timer updates so sprint stops when key/movement stops
    if self._update_running_timers then
        self:_update_running_timers(t)
    end

    local cur_state = self._ext_movement:current_state_name()
    local new_action = self:_update_interaction_timers(t)

    if cur_state ~= self._ext_movement:current_state_name() then
        return
    end

    new_action = self:_update_start_standard_timers(t) or new_action

    if cur_state ~= self._ext_movement:current_state_name() then
        return
    end

    if input.btn_stats_screen_press then
        self._unit:base():set_stats_screen_visible(true)
    elseif input.btn_stats_screen_release then
        self._unit:base():set_stats_screen_visible(false)
    end

    self:_update_foley(t, input)

    if not new_action then
        new_action = self:_check_use_item(t, input)
        if cur_state ~= self._ext_movement:current_state_name() then
            return
        end
    end

    if not new_action then
        new_action = self:_check_action_interact(t, input)
        if cur_state ~= self._ext_movement:current_state_name() then
            return
        end
    end

    self:_check_action_jump(t, input)
    self:_check_action_run(t, input)
    self:_check_action_duck(t, input)
    self:_check_action_change_equipment(t, input)
end

-- Allow dropping carry bag with Use Item button (G) without forcing mask on
local function drop_carry_in_mask_off(self, t, input)
    if input.btn_use_item_press and managers.player and managers.player:is_carrying() then
        local action_forbidden = self._use_item_expire_t or self:_changing_weapon() or self:_interacting()
        if not action_forbidden then
            managers.player:drop_carry()
            return true
        end
    end
    if orig.PlayerMaskOff_check_use_item then
        return orig.PlayerMaskOff_check_use_item(self, t, input)
    end
end

-- Cleanly interrupt sprint on state exit to ensure no persistent running flags
local function clean_maskoff_exit(self, state_data, new_state_name)
    if self._running then
        self:_interupt_action_running(Application:time())
    end
    if orig.PlayerMaskOff_exit then
        return orig.PlayerMaskOff_exit(self, state_data, new_state_name)
    end
end

-- Stamina hook: Prevents infinite panting sound in mask off
local function clean_update_stamina(self, t, dt, ignore_running)
    if feature_enabled and self._current_state_name == "mask_off" and not self._is_running then
        self._stamina = self:_max_stamina()
        pcall(function() SoundDevice:set_rtpc("stamina", 100) end)
    end
    if orig.PlayerMovement_update_stamina then
        return orig.PlayerMovement_update_stamina(self, t, dt, ignore_running)
    end
end

-- ─── 4. Toggle Hook Applier ──────────────────────────────────────────────────

local function apply(enabled)
    feature_enabled = enabled and true or false
    
    if enabled then
        if BaseInteractionExt and not orig.BaseInteractionExt_is_in_required_state then
            orig.BaseInteractionExt_is_in_required_state = BaseInteractionExt._is_in_required_state
            BaseInteractionExt._is_in_required_state = skip_mask_state_gate
        end
        if BaseInteractionExt and not orig.BaseInteractionExt_has_required_upgrade then
            orig.BaseInteractionExt_has_required_upgrade = BaseInteractionExt._has_required_upgrade
            BaseInteractionExt._has_required_upgrade = skip_mask_upgrade_gate
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_check_use_item then
            orig.PlayerMaskOff_check_use_item = PlayerMaskOff._check_use_item
            PlayerMaskOff._check_use_item = drop_carry_in_mask_off
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_exit then
            orig.PlayerMaskOff_exit = PlayerMaskOff.exit
            PlayerMaskOff.exit = clean_maskoff_exit
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_check_action_duck then
            orig.PlayerMaskOff_check_action_duck = PlayerMaskOff._check_action_duck
            PlayerMaskOff._check_action_duck = real_duck_while_unmasked
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_check_action_run then
            orig.PlayerMaskOff_check_action_run = PlayerMaskOff._check_action_run
            PlayerMaskOff._check_action_run = real_run_while_unmasked
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_start_action_running then
            orig.PlayerMaskOff_start_action_running = PlayerMaskOff._start_action_running
            PlayerMaskOff._start_action_running = maskoff_start_action_running
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_end_action_running then
            orig.PlayerMaskOff_end_action_running = PlayerMaskOff._end_action_running
            PlayerMaskOff._end_action_running = maskoff_end_action_running
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_start_action_jump then
            orig.PlayerMaskOff_start_action_jump = PlayerMaskOff._start_action_jump
            PlayerMaskOff._start_action_jump = maskoff_start_action_jump
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_check_action_jump then
            orig.PlayerMaskOff_check_action_jump = PlayerMaskOff._check_action_jump
            PlayerMaskOff._check_action_jump = real_jump_while_unmasked
        end
        if PlayerMaskOff and not orig.PlayerMaskOff_update_check_actions then
            orig.PlayerMaskOff_update_check_actions = PlayerMaskOff._update_check_actions
            PlayerMaskOff._update_check_actions = patched_maskoff_update_check_actions
        end
        if PlayerMovement and not orig.PlayerMovement_update_stamina then
            orig.PlayerMovement_update_stamina = PlayerMovement.update_stamina
            PlayerMovement.update_stamina = clean_update_stamina
        end
        if FPCameraPlayerBase and not orig.FPCameraPlayerBase_play_redirect then
            orig.FPCameraPlayerBase_play_redirect = FPCameraPlayerBase.play_redirect
            function FPCameraPlayerBase:play_redirect(redirect_name, ...)
                if feature_enabled and is_unmasked_state() then
                    local k = (type(redirect_name) == "userdata" and redirect_name.key) and redirect_name:key() or redirect_name
                    if blocked_maskoff_redirect_keys[k] then
                        return false
                    end
                end
                return orig.FPCameraPlayerBase_play_redirect(self, redirect_name, ...)
            end
        end
    else
        if BaseInteractionExt and orig.BaseInteractionExt_is_in_required_state then
            BaseInteractionExt._is_in_required_state = orig.BaseInteractionExt_is_in_required_state
            orig.BaseInteractionExt_is_in_required_state = nil
        end
        if BaseInteractionExt and orig.BaseInteractionExt_has_required_upgrade then
            BaseInteractionExt._has_required_upgrade = orig.BaseInteractionExt_has_required_upgrade
            orig.BaseInteractionExt_has_required_upgrade = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_check_use_item then
            PlayerMaskOff._check_use_item = orig.PlayerMaskOff_check_use_item
            orig.PlayerMaskOff_check_use_item = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_exit then
            PlayerMaskOff.exit = orig.PlayerMaskOff_exit
            orig.PlayerMaskOff_exit = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_check_action_duck then
            PlayerMaskOff._check_action_duck = orig.PlayerMaskOff_check_action_duck
            orig.PlayerMaskOff_check_action_duck = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_check_action_run then
            PlayerMaskOff._check_action_run = orig.PlayerMaskOff_check_action_run
            orig.PlayerMaskOff_check_action_run = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_start_action_running then
            PlayerMaskOff._start_action_running = orig.PlayerMaskOff_start_action_running
            orig.PlayerMaskOff_start_action_running = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_end_action_running then
            PlayerMaskOff._end_action_running = orig.PlayerMaskOff_end_action_running
            orig.PlayerMaskOff_end_action_running = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_start_action_jump then
            PlayerMaskOff._start_action_jump = orig.PlayerMaskOff_start_action_jump
            orig.PlayerMaskOff_start_action_jump = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_check_action_jump then
            PlayerMaskOff._check_action_jump = orig.PlayerMaskOff_check_action_jump
            orig.PlayerMaskOff_check_action_jump = nil
        end
        if PlayerMaskOff and orig.PlayerMaskOff_update_check_actions then
            PlayerMaskOff._update_check_actions = orig.PlayerMaskOff_update_check_actions
            orig.PlayerMaskOff_update_check_actions = nil
        end
        if PlayerMovement and orig.PlayerMovement_update_stamina then
            PlayerMovement.update_stamina = orig.PlayerMovement_update_stamina
            orig.PlayerMovement_update_stamina = nil
        end
        if FPCameraPlayerBase and orig.FPCameraPlayerBase_play_redirect then
            FPCameraPlayerBase.play_redirect = orig.FPCameraPlayerBase_play_redirect
            orig.FPCameraPlayerBase_play_redirect = nil
        end
    end
end

-- ─── 5. Auto-Apply On Mission Load ───────────────────────────────────────────

if not NiceTrainer._hacked_maskoff_hook then
    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_MaskOff_Apply", function()
        if NiceTrainer.Settings.mask_off_normal_interactions then
            apply(true)
        end
    end)
    NiceTrainer._hacked_maskoff_hook = true
end

-- ─── 6. Action Registrations ─────────────────────────────────────────────────

NiceTrainer:RegisterAction("Stealth", {
    type     = "toggle",
    category = "Player",
    badge    = "client",
    id       = "mask_off_normal_interactions",
    text     = "Normal Interactions (Mask Off)",
    tooltip  = "Allows full interaction (doors, pagers, revives, loot) plus running, jumping, and ducking while your mask is off.",
    default  = false,
    callback = function(state)
        apply(state)
    end
})

NiceTrainer:RegisterAction("Stealth", {
    type     = "button",
    category = "Player",
    badge    = "client",
    text     = "Take Mask Off",
    tooltip  = "Takes your mask off immediately, returning to peaceful civilian casing mode.",
    callback = function()
        if not managers.player then return end
        local unit = managers.player:player_unit()
        if not alive(unit) then return end
        managers.player:set_player_state("mask_off")
        if unit:camera() then
            pcall(function() unit:camera():play_redirect(Idstring("unequip")) end)
        end
        NiceTrainer:Toast("Mask taken off (Casing mode)!")
    end
})
