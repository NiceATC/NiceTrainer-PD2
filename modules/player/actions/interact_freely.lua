-- ─── Full Interaction Freedom (Interact, Move & Look) for NiceTrainer ───────
-- Allows moving, looking around 360°, shooting, reloading, weapon switching,
-- meleeing, throwing grenades, and interacting in Civilian/Mask-Off states.

local P2H = {
    adv_mov = {
        secondary_attack = true, -- aim while interacting
        primary_attack   = true, -- shoot while interacting
        reload           = true, -- reload while interacting
        switch_weapon    = true, -- switch weapon while interacting
        use_item         = true, -- use equipment while interacting
        throw_grenade    = true, -- throw grenades while interacting
        melee            = true, -- melee while interacting
        move             = true, -- move around while interacting
        look             = true  -- look around 360° while interacting
    },
    adv_act = {
        civilian         = true, -- mark units in civilian mode
    },
    adv_dialog = {
        civilian_state   = true, -- silence action blocked messages
        mask_off_state   = true
    }
}

local function is_enabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.interact_freely == true
end

local function sync_settings()
    if not NiceTrainer or not NiceTrainer.Settings then return end
    for k, _ in pairs(P2H.adv_mov) do
        if NiceTrainer.Settings["interact_freely_" .. k] ~= nil then
            P2H.adv_mov[k] = NiceTrainer.Settings["interact_freely_" .. k]
        end
    end
    if NiceTrainer.Settings.interact_freely_civilian ~= nil then
        P2H.adv_act.civilian = NiceTrainer.Settings.interact_freely_civilian
    end
end

-- ============================================================================
-- Dynamic Hook Application
-- ============================================================================
local function apply_interact_freely_hooks()
    sync_settings()

    -- 1. Camera Look Limits Hook (Full 360° Freedom)
    if _G.FPCameraPlayerBase and not FPCameraPlayerBase._nt_freely_hooked then
        FPCameraPlayerBase._nt_freely_hooked = true
        local orig_set_limits = FPCameraPlayerBase.set_limits
        function FPCameraPlayerBase:set_limits(spin, pitch, ...)
            if is_enabled() and P2H.adv_mov.look then
                return self:remove_limits()
            end
            return orig_set_limits(self, spin, pitch, ...)
        end
    end

    -- 2. Hint Manager Hook: Silence action blocked hints in mask off / civilian
    if _G.HintManager and not _G.HintManager._nt_freely_hooked then
        _G.HintManager._nt_freely_hooked = true
        local orig_show_hint = HintManager.show_hint
        function HintManager:show_hint(id, time, only_sync, params, ...)
            if is_enabled() then
                if (id == "mask_off_block_interact" and P2H.adv_dialog.civilian_state) or
                   (id == "clean_block_interact" and P2H.adv_dialog.mask_off_state) then
                    return
                end
            end
            return orig_show_hint(self, id, time, only_sync, params, ...)
        end
    end

    -- 3. BaseInteractionExt State, Raycast & Interrupt Hooks
    if _G.BaseInteractionExt and not _G.BaseInteractionExt._nt_freely_hooked then
        _G.BaseInteractionExt._nt_freely_hooked = true

        local orig_is_in_required_state = BaseInteractionExt._is_in_required_state
        function BaseInteractionExt:_is_in_required_state(movement_state, ...)
            if is_enabled() then
                return true
            end
            if orig_is_in_required_state then
                return orig_is_in_required_state(self, movement_state, ...)
            end
            return movement_state == "standard"
        end

        local orig_check_interupt = BaseInteractionExt.check_interupt
        function BaseInteractionExt:check_interupt(...)
            if is_enabled() and P2H.adv_mov.move then
                return false
            end
            if orig_check_interupt then
                return orig_check_interupt(self, ...)
            end
            return false
        end

        local orig_can_interact = BaseInteractionExt.can_interact
        function BaseInteractionExt:can_interact(player, ...)
            if is_enabled() and self._interact_object and self._interact_object == player then
                return true
            end
            if orig_can_interact then
                return orig_can_interact(self, player, ...)
            end
            return true
        end
    end

    -- 4. PlayerStandard Hooks
    if _G.PlayerStandard and not PlayerStandard._nt_freely_hooked then
        PlayerStandard._nt_freely_hooked = true

        -- Start interaction: keep weapons equipped, remove camera limits & register interact_start
        local orig_start_action_interact = PlayerStandard._start_action_interact
        function PlayerStandard:_start_action_interact(t, input, timer, interact_object, ...)
            if not is_enabled() then
                return orig_start_action_interact(self, t, input, timer, interact_object, ...)
            end

            local final_timer = timer
            final_timer = managers.modifiers:modify_value("PlayerStandard:OnStartInteraction", final_timer, interact_object)
            self._interact_expire_t = final_timer

            self._interact_params = {
                object = interact_object,
                timer = final_timer,
                tweak_data = interact_object:interaction().tweak_data
            }

            if P2H.adv_mov.look and self._ext_camera then
                pcall(function() self._ext_camera:camera_unit():base():remove_limits() end)
            end

            if not P2H.adv_mov.primary_attack and not P2H.adv_mov.move then
                self:_play_unequip_animation()
            end

            if alive(interact_object) and interact_object:interaction() then
                interact_object:interaction():interact_start(self._unit)
            end

            managers.hud:show_interaction_bar(0, final_timer)
            if managers.network and managers.network:session() then
                managers.network:session():send_to_peers_synched("sync_teammate_progress", 1, true, self._interact_params.tweak_data, final_timer, false)
            end
            if self._unit and self._unit:network() then
                self._unit:network():send("sync_interaction_anim", true, self._interact_params.tweak_data)
            end
        end

        -- Update interaction timers: do NOT interrupt when walking/looking away from object
        local orig_update_interaction_timers = PlayerStandard._update_interaction_timers
        function PlayerStandard:_update_interaction_timers(t, ...)
            if not is_enabled() then
                return orig_update_interaction_timers(self, t, ...)
            end

            if self._interact_expire_t then
                local dt = self:_get_interaction_speed()
                self._interact_expire_t = self._interact_expire_t - dt

                local params = self._interact_params
                local obj = params and params.object

                -- Check if object was destroyed or became invalid
                local is_invalid = not alive(obj) or not obj:interaction()
                if not is_invalid and not P2H.adv_mov.move then
                    if (params.tweak_data ~= obj:interaction().tweak_data) or obj:interaction():check_interupt() then
                        is_invalid = true
                    end
                elseif not is_invalid then
                    if params.tweak_data ~= obj:interaction().tweak_data then
                        is_invalid = true
                    end
                end

                if is_invalid then
                    self:_interupt_action_interact(t)
                else
                    local current = params.timer - self._interact_expire_t
                    local total = params.timer
                    managers.hud:set_interaction_bar_width(current, total)

                    if self._interact_expire_t <= 0 then
                        self:_end_action_interact(t)
                        self._interact_expire_t = nil
                        return true
                    end
                end
            end
        end

        -- End interaction: bypass vanilla can_interact raycast/distance checks so it always executes
        local orig_end_action_interact = PlayerStandard._end_action_interact
        function PlayerStandard:_end_action_interact(t, ...)
            if not is_enabled() then
                return orig_end_action_interact(self, t, ...)
            end

            if not self._interact_params then
                return
            end

            local obj = self._interact_params.object
            self:_interupt_action_interact(t, nil, true)

            if alive(obj) and obj:interaction() then
                obj:interaction():interact(self._unit)
            end
        end

        -- Movement calculation: do NOT zero out movement vector during interaction
        local orig_determine_move_direction = PlayerStandard._determine_move_direction
        function PlayerStandard:_determine_move_direction(...)
            if not is_enabled() or not P2H.adv_mov.move then
                return orig_determine_move_direction(self, ...)
            end

            self._stick_move = self._controller:get_input_axis("move")
            if self._state_data.on_zipline then
                return
            end

            if mvector3.length(self._stick_move) < PlayerStandard.MOVEMENT_DEADZONE or self:_does_deploying_limit_movement() then
                self._move_dir = nil
                self._normal_move_dir = nil
            else
                local ladder_unit = self._unit:movement():ladder_unit()
                if alive(ladder_unit) then
                    local ladder_ext = ladder_unit:ladder()
                    self._move_dir = mvector3.copy(self._stick_move)
                    self._normal_move_dir = mvector3.copy(self._move_dir)
                    local cam_flat_rot = Rotation(self._cam_fwd_flat, math.UP)
                    mvector3.rotate_with(self._normal_move_dir, cam_flat_rot)
                    local cam_rot = Rotation(self._cam_fwd, self._ext_camera:rotation():z())
                    mvector3.rotate_with(self._move_dir, cam_rot)
                    local up_dot = math.dot(self._move_dir, ladder_ext:up())
                    local w_dir_dot = math.dot(self._move_dir, ladder_ext:w_dir())
                    local normal_dot = math.dot(self._move_dir, ladder_ext:normal()) * -1
                    local normal_offset = ladder_ext:get_normal_move_offset(self._unit:movement():m_pos())
                    mvector3.set(self._move_dir, ladder_ext:up() * (up_dot + normal_dot))
                    mvector3.add(self._move_dir, ladder_ext:w_dir() * w_dir_dot)
                    mvector3.add(self._move_dir, ladder_ext:normal() * normal_offset)
                else
                    self._move_dir = mvector3.copy(self._stick_move)
                    local cam_flat_rot = Rotation(self._cam_fwd_flat, math.UP)
                    mvector3.rotate_with(self._move_dir, cam_flat_rot)
                    self._normal_move_dir = mvector3.copy(self._move_dir)
                end
            end
        end

        -- Check action interact: allow tap-to-interact and manual abort
        local orig_check_action_interact = PlayerStandard._check_action_interact
        function PlayerStandard:_check_action_interact(t, input, ...)
            if not is_enabled() then
                return orig_check_action_interact(self, t, input, ...)
            end

            -- If already interacting and user presses interact again, cancel it manually
            if input.btn_interact_press and self._interact_expire_t then
                self:_interupt_action_interact(t)
                return false
            end

            -- Releasing interact key does NOT interrupt interaction
            if input.btn_interact_release and self._interact_expire_t then
                return false
            end

            local res = orig_check_action_interact(self, t, input, ...)
            if P2H.adv_mov.look and self._ext_camera then
                pcall(function() self._ext_camera:camera_unit():base():remove_limits() end)
            end
            return res
        end

        -- Interacting query: return false for action blockers to allow shooting/aiming/reloading/melee/throw/swap
        local orig_interacting = PlayerStandard._interacting
        function PlayerStandard:_interacting(...)
            if not is_enabled() then
                return orig_interacting and orig_interacting(self, ...) or (self._interact_expire_t ~= nil)
            end
            return false
        end

        -- Interupt interact override
        local orig_interupt_interact = PlayerStandard.interupt_interact
        function PlayerStandard:interupt_interact(...)
            if self._interact_expire_t then
                self:_interupt_action_interact()
                if self._interaction then
                    self._interaction:interupt_action_interact()
                end
                self._interact_expire_t = nil
            end
            if orig_interupt_interact then
                return orig_interupt_interact(self, ...)
            end
        end
    end

    -- 5. PlayerMaskOff Hooks
    if _G.PlayerMaskOff and not PlayerMaskOff._nt_freely_hooked then
        PlayerMaskOff._nt_freely_hooked = true

        local orig_maskoff_update_actions = PlayerMaskOff._update_check_actions
        function PlayerMaskOff:_update_check_actions(t, dt, ...)
            if not is_enabled() or not P2H.adv_mov.move then
                return orig_maskoff_update_actions(self, t, dt, ...)
            end

            local input = self:_get_input(t, dt)
            self._stick_move = self._controller:get_input_axis("move")
            if mvector3.length(self._stick_move) < 0.1 then
                self._move_dir = nil
            else
                self._move_dir = mvector3.copy(self._stick_move)
                local cam_flat_rot = Rotation(self._cam_fwd_flat, math.UP)
                mvector3.rotate_with(self._move_dir, cam_flat_rot)
            end

            local cur_state = self._ext_movement:current_state_name()
            local new_action = self:_update_interaction_timers(t)
            if cur_state ~= self._ext_movement:current_state_name() then return end

            new_action = self:_update_start_standard_timers(t) or new_action
            if cur_state ~= self._ext_movement:current_state_name() then return end

            if input.btn_stats_screen_press then
                self._unit:base():set_stats_screen_visible(true)
            elseif input.btn_stats_screen_release then
                self._unit:base():set_stats_screen_visible(false)
            end

            self:_update_foley(t, input)

            if not new_action then
                new_action = self:_check_use_item(t, input)
                if cur_state ~= self._ext_movement:current_state_name() then return end
            end

            if not new_action then
                new_action = self:_check_action_interact(t, input)
                if cur_state ~= self._ext_movement:current_state_name() then return end
            end

            if not new_action and self._state_data.ducking then
                self:_end_action_ducking(t)
            end

            self:_check_action_jump(t, input)
            self:_check_action_duck(t, input)
            self:_check_action_run(t, input)
            self:_check_action_change_equipment(t, input)
        end

        local orig_maskoff_check_interact = PlayerMaskOff._check_action_interact
        function PlayerMaskOff:_check_action_interact(t, input, ...)
            if not is_enabled() then
                return orig_maskoff_check_interact(self, t, input, ...)
            end

            if input.btn_interact_press and self._interact_expire_t then
                self:_interupt_action_interact(t)
                return false
            end
            if input.btn_interact_release and self._interact_expire_t then
                return false
            end

            local res = orig_maskoff_check_interact(self, t, input, ...)
            if P2H.adv_mov.look and self._ext_camera then
                pcall(function() self._ext_camera:camera_unit():base():remove_limits() end)
            end
            return res
        end
    end

    -- 6. PlayerCivilian Marking Hook
    if _G.PlayerCivilian and not PlayerCivilian._nt_freely_hooked then
        PlayerCivilian._nt_freely_hooked = true
        local orig_civ_mark = PlayerCivilian.mark_units
        function PlayerCivilian:mark_units(line, t, no_gesture, skip_alert, ...)
            if is_enabled() and P2H.adv_act.civilian and PlayerMaskOff and PlayerMaskOff.mark_units then
                return PlayerMaskOff.mark_units(self, line, t, no_gesture, skip_alert, ...)
            end
            if orig_civ_mark then
                return orig_civ_mark(self, line, t, no_gesture, skip_alert, ...)
            end
        end
    end
end

apply_interact_freely_hooks()

-- ============================================================================
-- Settings Modal Layout for Full Interaction Freedom
-- ============================================================================
local function ShowInteractFreelySettings()
    local MODAL_W, MODAL_H = 540, 480
    NiceTrainer:ShowCustomModal("Interaction Freedom Settings", MODAL_W, MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        m:text({
            text = "Configure movement and action permissions during active interactions.",
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(0.7, 0.7, 0.7), x = 16, y = 54, w = MODAL_W - 32, layer = 2
        })

        local options = {
            { label = "Free Camera Look (360° rotation)",          key = "look",             sub = "adv_mov" },
            { label = "Move Freely While Interacting",              key = "move",             sub = "adv_mov" },
            { label = "Shoot & Attack (Primary Attack)",            key = "primary_attack",   sub = "adv_mov" },
            { label = "Aim Down Sights (Secondary Attack)",         key = "secondary_attack", sub = "adv_mov" },
            { label = "Reload Weapons While Interacting",           key = "reload",           sub = "adv_mov" },
            { label = "Switch Weapons While Interacting",           key = "switch_weapon",    sub = "adv_mov" },
            { label = "Melee Attack While Interacting",             key = "melee",            sub = "adv_mov" },
            { label = "Throw Projectiles / Grenades",               key = "throw_grenade",    sub = "adv_mov" },
            { label = "Deploy Equipment While Interacting",          key = "use_item",         sub = "adv_mov" },
            { label = "Mark Guards & Cameras in Civilian Mode",     key = "civilian",         sub = "adv_act" },
        }

        local scroll_top = 80
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = MODAL_W, h = MODAL_H - scroll_top - 12, layer = 2 })
        local row_h = 36
        local canvas_h = #options * (row_h + 4) + 10
        local canvas = scroll_wrap:panel({ x = 0, y = 0, w = MODAL_W, h = math.max(canvas_h, row_h), layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local y = 6
        for _, opt in ipairs(options) do
            local cur_val = P2H[opt.sub][opt.key] == true
            local row = canvas:panel({ x = 14, y = y, w = MODAL_W - 28, h = row_h, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            row:rect({ color = Color.white, alpha = 0.1, x = 8, y = 8, w = 20, h = 20, layer = 1 })
            local cb = row:rect({ color = Color(0.2, 0.6, 1.0), x = 12, y = 12, w = 12, h = 12, visible = cur_val, layer = 2 })

            row:text({
                text = opt.label, font = "fonts/font_medium_shadow_mf", font_size = 16,
                x = 36, vertical = "center", color = Color(0.9, 0.9, 0.9), layer = 1
            })

            local sub_key = opt.sub
            local item_key = opt.key
            table.insert(top_modal.elements, {
                panel = row,
                inside = function(self, mx, my) return scroll_wrap:inside(mx, my) and row:inside(mx, my) end,
                on_hover = function(self, hovered) row_bg:set_alpha(hovered and 0.12 or 0.04) end,
                on_click = function(self)
                    local nv = not (P2H[sub_key][item_key] == true)
                    P2H[sub_key][item_key] = nv
                    if alive(cb) then cb:set_visible(nv) end
                    NiceTrainer.Settings["interact_freely_" .. item_key] = nv
                    NiceTrainer:Save()
                end
            })

            y = y + row_h + 4
        end
    end)
end

-- ============================================================================
-- Registration in Player Tab
-- ============================================================================
NiceTrainer:RegisterAction("Player", {
    type              = "toggle_settings",
    category          = "Interactions",
    badge             = "client",
    id                = "interact_freely",
    text              = "Full Interaction Freedom",
    tooltip           = "Move around, look 360°, shoot, aim, reload, melee, and throw grenades while interacting. Also allows interacting and marking in Civilian mode. Click [...] to customize.",
    default           = false,
    callback          = function(state)
        NiceTrainer.Settings.interact_freely = state
        NiceTrainer:Save()
        apply_interact_freely_hooks()
    end,
    settings_callback = ShowInteractFreelySettings
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyInteractFreely", function()
    apply_interact_freely_hooks()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_InteractFreelyUpdate", function()
    apply_interact_freely_hooks()
end)
