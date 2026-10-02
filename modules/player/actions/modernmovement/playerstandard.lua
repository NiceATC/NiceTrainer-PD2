local path = (NiceTrainer and NiceTrainer.ModPath) or ModPath or "mods/NiceTrainer/"
dofile(path .. "modules/player/actions/modernmovement/modernmovementcore.lua")

-- Modern Movement standalone uses a Restoration-style slide-speed model instead
-- of its older custom per-armor multiplier table. This tuned standalone version
-- keeps the useful heavy-armor floor, but lowers the overall launch range because
-- the full Restoration numbers felt too fast/long outside Restoration's movement stack.
function ModernMovement:equipped_armor_level()
	local armor_id = nil
	if managers and managers.blackmarket and managers.blackmarket.equipped_armor then
		armor_id = managers.blackmarket:equipped_armor(true, true)
	end

	local armor_data = armor_id and tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.armors and tweak_data.blackmarket.armors[armor_id]
	local level = armor_data and armor_data.upgrade_level

	if not level and type(armor_id) == "string" then
		level = tonumber(string.match(armor_id, "level_(%d+)"))
	end

	return tonumber(level) or 1
end

function ModernMovement:resmod_slide_speed_multiplier()
	-- Keep the Restoration-style run-speed driven launch, but use enough
	-- multiplier for armor/build speed differences to remain visible.
	return 1.35
end

function ModernMovement:resmod_slide_min_speed_floor()
	-- Low enough to keep armor spread visible, but a touch higher than the
	-- previous pass so every armor gets a little more carry without becoming long again.
	return 775
end

function ModernMovement:resmod_slide_max_speed_cap()
	-- Armor-specific caps preserve the ResMod-style formula while keeping
	-- armor classes separated. This pass raises each cap slightly so slides are
	-- a touch less stubby while preserving clear armor separation.
	local level = self:equipped_armor_level()

	if level == 1 then
		return 1000 -- Suit
	elseif level == 2 then
		return 950 -- Lightweight Ballistic Vest
	elseif level == 3 then
		return 925 -- Ballistic Vest
	elseif level == 4 then
		return 900 -- Heavy Ballistic Vest
	elseif level == 5 then
		return 875 -- Flak Jacket
	elseif level == 6 then
		return 850 -- Combined Tactical Vest
	elseif level == 7 then
		return 825 -- Improved Combined Tactical Vest
	end

	return 925
end

ModernMovement:Load()
ModernMovement:_apply_defaults()
-- Generate save data if nobody ever touches the mod options menu, but do not
-- rewrite the settings file every time PlayerStandard loads.
local modernmovement_existing_save = io.open(ModernMovement._data_path, "r")
if modernmovement_existing_save then
	modernmovement_existing_save:close()
else
	ModernMovement:Save()
end


function PlayerStandard:_stance_entered(unequipped, timemult)
	local stance_standard = tweak_data.player.stances.default[managers.player:current_state()] or tweak_data.player.stances.default.standard
	local head_stance = self._state_data.ducking and tweak_data.player.stances.default.crouched.head or stance_standard.head
	local stance_id = nil
	local stance_mod = {
		translation = Vector3(0, 0, 0),
		rotation = Rotation(0, 0, 0)
	}

	local head_duration = tweak_data.player.TRANSITION_DURATION or 0.23
	local head_duration_multiplier = 1
	local duration = head_duration + (self._equipped_unit:base():transition_duration() or 0)
	--local duration = tweak_data.player.TRANSITION_DURATION + (self._equipped_unit:base():transition_duration() or 0)
	local duration_multiplier = self._state_data.in_steelsight and 1 / self._equipped_unit:base():enter_steelsight_speed_multiplier() or 1

	if not unequipped then
		stance_id = self._equipped_unit:base():get_stance_id()

		if self._state_data.in_steelsight and self._equipped_unit:base().stance_mod then
			stance_mod = self._equipped_unit:base():stance_mod() or stance_mod
		end
	end

	-- geddan
--[[
	stance_mod.rotation = stance_mod.rotation * Rotation(math.random(-90, 90), math.random(-90, 90), math.random(-90, 90))
	duration = 0.01
--]]


	-- shift melee weapons
	local tdmelee = tweak_data.blackmarket.melee_weapons[managers.blackmarket:equipped_melee_weapon()]
	if self._state_data.meleeing and tdmelee.stance_mod then
		if tdmelee.stance_mod.translation then
			stance_mod.translation = stance_mod.translation + tdmelee.stance_mod.translation
		end
		if tdmelee.stance_mod.rotation then
			stance_mod.rotation = stance_mod.rotation * tdmelee.stance_mod.rotation
		end
	end


	-- mid-reload viewmodel adjustments aka flipturn
	local reload_timed_stances = self._equipped_unit:base()._reload_timed_stance_mod
	if self:_is_reloading() and reload_timed_stances and self._flipturn_reload_state then
		local empty = 0
		local values = reload_timed_stances.not_empty
		if self._flipturn_reload_state > 99 then
			empty = 100
			values = reload_timed_stances.empty
		end
		if values then
			if self:in_steelsight() then
				values = values.ads
			else
				values = values.hip
			end
		end
		local flipturn_index = self._flipturn_reload_state - empty
		if values and values[flipturn_index] then
			if values[flipturn_index].translation then
				stance_mod.translation = stance_mod.translation + values[flipturn_index].translation
			end
			if values[flipturn_index].rotation then
				stance_mod.rotation = stance_mod.rotation * values[flipturn_index].rotation
			end
			if values[flipturn_index].sound and (flipturn_index > self._last_flipturn_sound) then
				self._unit:sound():_play(values[flipturn_index].sound)
				self._last_flipturn_sound = flipturn_index
			end
			duration_multiplier = duration_multiplier / (values[flipturn_index].speed or 1)
			duration_multiplier = duration_multiplier / (self._equipped_unit:base():reload_speed_multiplier()/self._equipped_unit:base():standard_reload_speed_multiplier())
		end
	end

	-- shell-by-shell viewmodel adjustments
	local shotgun_ammo_stances = self._equipped_unit:base()._shotgun_ammo_stance_mod
	if self:_is_reloading() and shotgun_ammo_stances then
		local values = shotgun_ammo_stances
		if values then
			if self:in_steelsight() then
				values = values.ads
			else
				values = values.hip
			end
		end
		local ammovalue = self._equipped_unit:base():get_ammo_remaining_in_clip() + 1
		if values and values[ammovalue] then
			if values[ammovalue].translation then
				stance_mod.translation = stance_mod.translation + values[ammovalue].translation
			end
			if values[ammovalue].rotation then
				stance_mod.rotation = stance_mod.rotation * values[ammovalue].rotation
			end
			if values[ammovalue].sound and (ammovalue > self._last_flipturn_sound) then
				self._unit:sound():_play(values[ammovalue].sound)
				self._last_flipturn_sound = ammovalue
			end
			duration_multiplier = duration_multiplier / (values[ammovalue].speed or 1)
			duration_multiplier = duration_multiplier / (self._equipped_unit:base():reload_speed_multiplier()/self._equipped_unit:base():standard_reload_speed_multiplier())
		end
	end

	-- post-shooting viewmodel adjustments aka shootturn
	-- works differently than the reload ones because i don't feel like going back and unfucking how the reload shit works
	local fire_timed_stances = self._equipped_unit:base()._fire_timed_stance_mod
	if fire_timed_stances and not self:_is_reloading() then
		if self:in_steelsight() then
			fire_timed_stances = fire_timed_stances.ads
		else
			fire_timed_stances = fire_timed_stances.hip
		end

		if fire_timed_stances[self._shootturn_state] then
			if fire_timed_stances[self._shootturn_state].translation then
				stance_mod.translation = stance_mod.translation + fire_timed_stances[self._shootturn_state].translation
			end
			if fire_timed_stances[self._shootturn_state].rotation then
				stance_mod.rotation = stance_mod.rotation * fire_timed_stances[self._shootturn_state].rotation
			end
			if fire_timed_stances[self._shootturn_state].sound and (self._shootturn_state > self._last_shootturn_sound) then
				if fire_timed_stances[self._shootturn_state].round_sound then
					if fire_timed_stances[self._shootturn_state].round_sound[self._equipped_unit:base():get_ammo_remaining_in_clip()] and fire_timed_stances[self._shootturn_state].round_sound[self._equipped_unit:base():get_ammo_remaining_in_clip()] == self._equipped_unit:base():get_ammo_remaining_in_clip() then
						self._unit:sound():_play(fire_timed_stances[self._shootturn_state].sound)
						self._last_shootturn_sound = self._shootturn_state
					end
				else
					self._unit:sound():_play(fire_timed_stances[self._shootturn_state].sound)
					self._last_shootturn_sound = self._shootturn_state
				end
			end
			duration_multiplier = duration_multiplier / (fire_timed_stances[self._shootturn_state].speed or 1)
			if self._shootturn_state == #fire_timed_stances then
				self._shootturn_state = nil
				self._last_shootturn_sound = 0
			end
		end
		duration_multiplier = duration_multiplier / (self._equipped_unit:base():fire_rate_multiplier())
	end

	-- static adjustment of stance when reloading
	if self._equipped_unit:base()._reload_stance_mod and self:_is_reloading() then
		if self._state_data.in_steelsight and self._equipped_unit:base()._reload_stance_mod.ads then
			if self._equipped_unit:base()._reload_stance_mod.ads.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._reload_stance_mod.ads.translation
			end
			if self._equipped_unit:base()._reload_stance_mod.ads.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._reload_stance_mod.ads.rotation
			end
		elseif self._equipped_unit:base()._reload_stance_mod.hip then
			if self._equipped_unit:base()._reload_stance_mod.hip.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._reload_stance_mod.hip.translation
			end
			if self._equipped_unit:base()._reload_stance_mod.hip.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._reload_stance_mod.hip.rotation
			end
		end
	end
	-- or while equipping
	if self._equipped_unit:base()._equip_stance_mod and self:is_equipping() then
		if self._equipped_unit:base()._equip_stance_mod.ads and self._state_data.in_steelsight then
			if self._equipped_unit:base()._equip_stance_mod.ads.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._equip_stance_mod.ads.translation
			end
			if self._equipped_unit:base()._equip_stance_mod.ads.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._equip_stance_mod.ads.rotation
			end
		elseif self._equipped_unit:base()._equip_stance_mod.hip then
			if self._equipped_unit:base()._equip_stance_mod.hip.translation then
				stance_mod.translation = stance_mod.translation + self._equipped_unit:base()._equip_stance_mod.hip.translation
			end
			if self._equipped_unit:base()._equip_stance_mod.hip.rotation then
				stance_mod.rotation = stance_mod.rotation * self._equipped_unit:base()._equip_stance_mod.hip.rotation
			end
		end
	end
	-- Slide viewmodel roll/tuck is applied before stance refresh by
	-- _modernmovement_apply_slide_viewmodel_stance(). Do not touch
	-- FPCameraPlayerBase here; that can tilt the camera.
	-- Small visual weapon tuck while the experimental vault movement is active.
	-- The cash/pickup-style camera redirect handles the main fake mantle animation.
	if self._pd3ms_vaulting and not self._state_data.in_steelsight then
		stance_mod.translation = stance_mod.translation + Vector3(0, -6, -2)
		stance_mod.rotation = stance_mod.rotation * Rotation(0, 0, -5)
	end
	if timemult then
		duration_multiplier = duration_multiplier * timemult
	end

	-- goldeneye
	if ((ModernMovement.settings.goldeneye == 2 and self._equipped_unit:base().akimbo) or ModernMovement.settings.goldeneye == 3 or self._equipped_unit:base()._use_goldeneye_reload) and self:_is_reloading() then
		stance_mod.translation = Vector3(0, 0, -100)
		stance_mod.rotation = Rotation(0, 0, 0)
	end

	local stances = nil
	stances = (self:_is_meleeing() or self:_is_throwing_projectile()) and tweak_data.player.stances.default or tweak_data.player.stances[stance_id] or tweak_data.player.stances.default
	local misc_attribs = stances.standard
	--misc_attribs = (not self:_is_using_bipod() or self:_is_throwing_projectile() or stances.bipod) and (self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and stances.crouched or stances.standard)

	-- Crouch-sprint is still physically crouched, so keep the crouched head/camera stance above.
	-- For the weapon shoulders, however, holding the standing sprint stance during the
	-- exact stand-sprint -> crouch-sprint handoff prevents the one-frame snap into
	-- crouched hipfire/default pose before the run redirect takes over.
	local hold_standing_weapon_stance = self._pd3ms_should_hold_standing_weapon_stance_for_crouch_sprint and self:_pd3ms_should_hold_standing_weapon_stance_for_crouch_sprint()
	misc_attribs = self:_is_using_bipod() and not self:_is_throwing_projectile() and stances.bipod or self._state_data.in_steelsight and stances.steelsight or self._state_data.ducking and not hold_standing_weapon_stance and stances.crouched or stances.standard
	self._pd3ms_holding_standing_crouch_sprint_stance = hold_standing_weapon_stance and true or nil

	local new_fov = self:get_zoom_fov(misc_attribs) + 0
	
	self._camera_unit:base():clbk_stance_entered(misc_attribs.shoulders, head_stance, misc_attribs.vel_overshot, new_fov, misc_attribs.shakers, stance_mod, duration_multiplier, duration, head_duration_multiplier, head_duration)
	--self._camera_unit:base():clbk_stance_entered(misc_attribs.shoulders, head_stance, misc_attribs.vel_overshot, new_fov, misc_attribs.shakers, stance_mod, duration_multiplier, duration)
	managers.menu:set_mouse_sensitivity(self:in_steelsight())
end


local function modernmovement_copy_rotation(rotation)
	if mrotation and mrotation.copy then
		return mrotation.copy(rotation)
	end

	if rotation and rotation.yaw and rotation.pitch and rotation.roll then
		return Rotation(rotation:yaw(), rotation:pitch(), rotation:roll())
	end

	return Rotation(0, 0, 0)
end

function PlayerStandard:_modernmovement_restore_slide_viewmodel_stance()
	local restore_data = self._modernmovement_slide_viewmodel_restore
	if not restore_data then
		return
	end

	for _, data in ipairs(restore_data) do
		if data.shoulders then
			data.shoulders.translation = data.translation
			data.shoulders.rotation = data.rotation
		end
	end

	self._modernmovement_slide_viewmodel_restore = nil
end

function PlayerStandard:_modernmovement_slide_viewmodel_stance_id()
	if not alive(self._equipped_unit) or not self._equipped_unit.base then
		return nil
	end

	local weapon_base = self._equipped_unit:base()
	if not weapon_base then
		return nil
	end

	if not self._state_data.in_steelsight and weapon_base.get_hipfire_stance_id then
		return weapon_base:get_hipfire_stance_id()
	end

	if weapon_base.get_stance_id then
		return weapon_base:get_stance_id()
	end

	return nil
end

function PlayerStandard:_modernmovement_apply_slide_viewmodel_stance()
	self:_modernmovement_restore_slide_viewmodel_stance()

	if not self._is_sliding or not ModernMovement or not ModernMovement.settings then
		return
	end

	if self._state_data.in_steelsight or self:_is_meleeing() then
		return
	end

	local stance_id = self:_modernmovement_slide_viewmodel_stance_id()
	local stances = stance_id and tweak_data.player.stances[stance_id]
	if not stances then
		return
	end

	local angle = ModernMovement:slide_weapon_angle()
	local restore_data = {}
	local seen = {}

	local function patch_shoulders(misc_attribs)
		local shoulders = misc_attribs and misc_attribs.shoulders
		if type(shoulders) ~= "table" or seen[shoulders] then
			return
		end

		seen[shoulders] = true
		table.insert(restore_data, {
			shoulders = shoulders,
			translation = shoulders.translation and mvector3.copy(shoulders.translation) or Vector3(0, 0, 0),
			rotation = shoulders.rotation and modernmovement_copy_rotation(shoulders.rotation) or Rotation(0, 0, 0)
		})

		shoulders.translation = (shoulders.translation or Vector3(0, 0, 0)) + Vector3(0, -3, 0)
		if angle ~= 0 then
			shoulders.rotation = (shoulders.rotation or Rotation(0, 0, 0)) * Rotation(0, 0, -angle)
		end
	end

	-- Slide is a ducking state, but patch standard too as a narrow compatibility
	-- fallback for viewmodel mods that resolve hipfire stance before ducking settles.
	patch_shoulders(stances.crouched)
	patch_shoulders(stances.standard)

	if #restore_data > 0 then
		self._modernmovement_slide_viewmodel_restore = restore_data
	end
end




Hooks:PostHook(PlayerStandard, "update", "pd3msupdate", function(self, t, dt)
	self._last_t = t
	self._last_dt = dt

	-- Track real grounded frames for crouch/stand foley. This lets
	-- sprint-jump-crouch stay silent in midair, while still allowing the
	-- stand-up foley after the player lands and releases crouch on the ground.
	if self._pd3ms_is_grounded_for_crouch_foley and self:_pd3ms_is_grounded_for_crouch_foley(t) then
		self._pd3ms_last_grounded_crouch_foley_t = t
	end

	-- Keep short crouch/stand one-shots attached to the local player while
	-- they ring out. Leaving the source at its spawn position made strafing
	-- sound like the foley was coming from the opposite ear.
	if self._pd3ms_crouch_sound_follow_until and t <= self._pd3ms_crouch_sound_follow_until then
		self:_pd3ms_update_crouch_sound_source()
	else
		self._pd3ms_crouch_sound_follow_until = nil
	end

	-- geddan
--[[
	self._geddan = self._geddan or 0
	if (t - 0.05) > self._geddan then
		self:_stance_entered()
		self._geddan = t
	end
--]]
end)

--[[
function PlayerStandard:_start_action_jump(t, action_start_data)
	-- don't fuck with the animation if melee weapon is still out
	if self._running and not self.RUN_AND_RELOAD and not self._equipped_unit:base():run_and_shoot_allowed() and not self:_is_meleeing() then
		self:_interupt_action_reload(t)
		self._ext_camera:play_redirect(self:get_animation("stop_running"), self._equipped_unit:base():exit_run_speed_multiplier())
	end

	self:_interupt_action_running(t)

	self._jump_t = t
	local jump_vec = action_start_data.jump_vel_z * math.UP

	self._unit:mover():jump()

	if self._move_dir then
		local move_dir_clamp = self._move_dir:normalized() * math.min(1, self._move_dir:length())
		self._last_velocity_xy = move_dir_clamp * action_start_data.jump_vel_xy
		self._jump_vel_xy = mvector3.copy(self._last_velocity_xy)
	else
		self._last_velocity_xy = Vector3()
	end

	self:_perform_jump(jump_vec)
end
--]]



function PlayerStandard:_get_max_walk_speed(t, force_run)
	local speed_tweak = self._tweak_data.movement.speed
	local movement_speed = speed_tweak.STANDARD_MAX
	local speed_state = "walk"
	local ads_mult = 1

	if self._is_sliding then
		movement_speed = self._slide_speed
		speed_state = "run"
	elseif self._state_data.in_steelsight and not managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and not self:_is_reloading() and not _G.IS_VR then
		-- allow full walkspeed while reloading
		movement_speed = speed_tweak.STEELSIGHT_MAX
		speed_state = "steelsight"
	elseif self:on_ladder() then
		movement_speed = speed_tweak.CLIMBING_MAX
		speed_state = "climb"
	elseif self._state_data.ducking then
		movement_speed = speed_tweak.CROUCHING_MAX
		speed_state = "crouch"
		if self._pd3ms_should_crouch_sprint and self:_pd3ms_should_crouch_sprint(t) then
			movement_speed = self:_pd3ms_crouch_sprint_speed(speed_tweak)
		end
	elseif self._state_data.in_air then
		movement_speed = speed_tweak.INAIR_MAX
		speed_state = nil
	elseif self._running or force_run then
		movement_speed = speed_tweak.RUNNING_MAX
		speed_state = "run"
	end

	movement_speed = managers.modifiers:modify_value("PlayerStandard:GetMaxWalkSpeed", movement_speed, self._state_data, speed_tweak)
	local morale_boost_bonus = self._ext_movement:morale_boost()
	local multiplier = managers.player:movement_speed_multiplier(speed_state, speed_state and morale_boost_bonus and morale_boost_bonus.move_speed_bonus, nil, self._ext_damage:health_ratio())
	multiplier = multiplier * (self._tweak_data.movement.multiplier[speed_state] or 1) -- fuck with this if 100% movespeed while aiming is required
	local apply_weapon_penalty = true

	if self:_is_meleeing() then
		local melee_entry = managers.blackmarket:equipped_melee_weapon()
		apply_weapon_penalty = not tweak_data.blackmarket.melee_weapons[melee_entry].stats.remove_weapon_movement_penalty
	end

	if alive(self._equipped_unit) and apply_weapon_penalty then
		multiplier = multiplier * self._equipped_unit:base():movement_penalty()
	end

	if managers.player:has_activate_temporary_upgrade("temporary", "increased_movement_speed") then
		multiplier = multiplier * managers.player:temporary_upgrade_value("temporary", "increased_movement_speed", 1)
	end

	local final_speed = movement_speed * multiplier

	self._cached_final_speed = self._cached_final_speed or 0

	if final_speed ~= self._cached_final_speed then
		self._cached_final_speed = final_speed

		self._ext_network:send("action_change_speed", final_speed)
	end

	--log(final_speed)
	return final_speed
end

-- returns normal walkspeed (used to determine speed threshold for beginning a slide)
local PD3MS_CROUCH_SLIDE_DOUBLE_TAP_WINDOW = 0.34

function PlayerStandard:_pd3ms_crouch_sprint_enabled()
	return ModernMovement and ModernMovement.settings and ModernMovement.settings.crouchsprinting == true
end

function PlayerStandard:_pd3ms_crouch_slide_ready(t)
	return true
end

function PlayerStandard:_pd3ms_crouch_slide_armed(t)
	return true
end

function PlayerStandard:_pd3ms_run_input_held()
	return self._controller and self._controller:get_input_bool("run") == true
end

function PlayerStandard:_pd3ms_hold_to_run()
	return self._setting_hold_to_run == true
end

function PlayerStandard:_pd3ms_crouch_sprint_waiting_for_run_repress()
	if not self:_pd3ms_hold_to_run() then
		self._pd3ms_crouch_sprint_require_run_repress = nil
		return false
	end

	if not self._pd3ms_crouch_sprint_require_run_repress then
		return false
	end

	if not self._pd3ms_run_input_held or not self:_pd3ms_run_input_held() then
		self._pd3ms_crouch_sprint_require_run_repress = nil
		return false
	end

	return true
end


function PlayerStandard:_pd3ms_can_sprint_current_direction()
	if not self._stick_move or mvector3.length(self._stick_move) < PlayerStandard.MOVEMENT_DEADZONE then
		return false
	end

	if self._can_run_directional then
		local ok, can_run = pcall(function()
			return self:_can_run_directional()
		end)
		if ok then
			return can_run == true
		end
	end

	local player_manager = managers and managers.player
	if player_manager and player_manager.has_category_upgrade and player_manager:has_category_upgrade("player", "can_free_run") then
		return true
	end

	local running_angle = player_manager and player_manager.has_category_upgrade and player_manager:has_category_upgrade("player", "can_strafe_run") and 92 or 50
	return mvector3.angle(self._stick_move, math.Y) <= running_angle
end

function PlayerStandard:_pd3ms_crouch_sprint_input_active()
	if self:_pd3ms_hold_to_run() then
		if self:_pd3ms_crouch_sprint_waiting_for_run_repress() then
			return false
		end

		return self:_pd3ms_run_input_held()
	end

	if self._pd3ms_crouch_sprint_toggled == true or self._running_wanted == true then
		return true
	end

	if self._state_data and self._state_data.ducking then
		return self._pd3ms_crouch_sprinting == true or self._pd3ms_crouch_sprint_anim_playing == true
	end

	return self._running == true
end

function PlayerStandard:_pd3ms_update_crouch_sprint_toggle(t, input)
	if self:_pd3ms_hold_to_run() then
		self._pd3ms_crouch_sprint_toggled = nil
		return
	end

	if not input or not input.btn_run_press then
		return
	end

	if self._pd3ms_crouch_sprint_toggled or self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing then
		self._pd3ms_crouch_sprint_toggled = nil
		self._running = nil
		self._running_wanted = false
		self._pd3ms_crouch_sprinting = nil
		if self._pd3ms_stop_crouch_sprint_anim then
			self:_pd3ms_stop_crouch_sprint_anim(t, false)
		end
	else
		self._pd3ms_crouch_sprint_toggled = true
		self._running_wanted = false
	end
end

function PlayerStandard:_pd3ms_primary_attack_input_active(input)
	return input and (input.btn_primary_attack_press or input.btn_primary_attack_state)
end

function PlayerStandard:_pd3ms_equipped_weapon_base()
	if not alive(self._equipped_unit) or not self._equipped_unit.base then
		return nil
	end

	return self._equipped_unit:base()
end

function PlayerStandard:_pd3ms_reload_press_can_start_reload()
	local weapon_base = self:_pd3ms_equipped_weapon_base()
	if not weapon_base then
		return false
	end

	if weapon_base.clip_full then
		local ok, clip_full = pcall(function()
			return weapon_base:clip_full()
		end)
		if ok and clip_full then
			return false
		end
	end

	if weapon_base.can_reload then
		local ok, can_reload = pcall(function()
			return weapon_base:can_reload()
		end)
		if ok and can_reload == false then
			return false
		end
	end

	if self._is_reloading and self:_is_reloading() then
		return false
	end

	if self._changing_weapon and self:_changing_weapon() then
		return false
	end

	if self._is_meleeing and self:_is_meleeing() then
		return false
	end

	if self._use_item_expire_t then
		return false
	end

	if self._interacting and self:_interacting() then
		local player_manager = managers and managers.player
		if not (player_manager and player_manager.has_category_upgrade and player_manager:has_category_upgrade("player", "no_interrupt_interaction")) then
			return false
		end
	end

	if self._is_throwing_projectile and self:_is_throwing_projectile() then
		return false
	end

	if self.is_shooting_count and self:is_shooting_count() then
		return false
	end

	if self._in_burst and self:_in_burst() then
		return false
	end

	return true
end

function PlayerStandard:_pd3ms_run_and_shoot_allowed()
	if not alive(self._equipped_unit) or not self._equipped_unit.base then
		return false
	end

	local weapon_base = self._equipped_unit:base()
	return weapon_base and weapon_base.run_and_shoot_allowed and weapon_base:run_and_shoot_allowed() == true
end

function PlayerStandard:_pd3ms_crouch_sprint_stamina_drain_rate()
	return tweak_data.player.movement_state.stamina.STAMINA_DRAIN_RATE or 0
end

function PlayerStandard:_pd3ms_has_sprint_stamina()
	local movement_ext = self._unit and self._unit:movement()
	return movement_ext and movement_ext.is_above_stamina_threshold and movement_ext:is_above_stamina_threshold() == true
end

function PlayerStandard:_pd3ms_set_crouch_sprint_movement_running(running)
	local movement_ext = self._unit and self._unit:movement()
	if not movement_ext then
		return
	end

	local target = running == true
	local current = nil
	if movement_ext.running then
		local ok, result = pcall(function()
			return movement_ext:running()
		end)
		if ok then
			current = result == true
		end
	end

	if movement_ext.set_running then
		if current == nil or current ~= target then
			movement_ext:set_running(target)
		end
	else
		movement_ext._is_running = target
		if movement_ext._restart_stamina_regen_timer then
			movement_ext:_restart_stamina_regen_timer()
		end
	end

	if self._ext_network and self._ext_network.send and current ~= target then
		pcall(function()
			self._ext_network:send("action_change_run", target)
		end)
	end
end

function PlayerStandard:_pd3ms_crouch_sprint_waiting_for_run_release()
	if not self._pd3ms_crouch_sprint_wait_for_run_release then
		return false
	end

	if self:_pd3ms_run_input_held() then
		return true
	end

	self._pd3ms_crouch_sprint_wait_for_run_release = nil
	return false
end

function PlayerStandard:_pd3ms_stop_crouch_sprint_for_stamina(t)
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self:_pd3ms_stop_crouch_sprint_anim(t, false)
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._running = nil
	self._running_wanted = false
	self._start_running_t = nil
	self._last_run_t = nil
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(false)
	end
	self._pd3ms_crouch_sprint_wait_for_run_release = self:_pd3ms_run_input_held() and true or nil
end

function PlayerStandard:_pd3ms_is_crouch_sprinting(t)
	if not self._state_data or not self._state_data.ducking or not self:_pd3ms_crouch_sprint_enabled() then
		return false
	end

	if not self:_pd3ms_has_sprint_stamina() then
		return false
	end

	return self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self:_pd3ms_should_crouch_sprint(t)
end

function PlayerStandard:_pd3ms_end_steelsight_for_crouch_sprint(t)
	if not self._state_data or not self._state_data.in_steelsight then
		return
	end

	self._steelsight_wanted = false
	if self._end_action_steelsight then
		self:_end_action_steelsight(t or self._last_t or 0)
	end
end

function PlayerStandard:_pd3ms_cancel_crouch_sprint_for_steelsight(t)
	if not self._state_data or not self._state_data.ducking or not self._pd3ms_crouch_sprint_enabled or not self:_pd3ms_crouch_sprint_enabled() then
		return false
	end

	local was_crouch_sprinting = self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self:_pd3ms_should_crouch_sprint(t)
	if not was_crouch_sprinting then
		return false
	end

	self._pd3ms_crouch_sprint_toggled = nil
	self._running_wanted = false
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
	if self._pd3ms_hold_to_run and self:_pd3ms_hold_to_run() and self._pd3ms_run_input_held and self:_pd3ms_run_input_held() then
		-- Match normal standing sprint: holding run through ADS should not auto-resume
		-- sprint after ADS is released. Require a fresh run press/release cycle.
		self._pd3ms_crouch_sprint_require_run_repress = true
	end
	self._pd3ms_crouch_sprint_steelsight_block_until_t = (t or self._last_t or 0) + 0.45
	self._running = true
	return true
end

function PlayerStandard:_pd3ms_interrupt_steelsight_for_crouch_sprint_run(t)
	-- Match vanilla stand-sprint behavior: ADS blocks a held run key that was
	-- already down before aiming, but a fresh run press while ADS is active
	-- should break ADS and start sprinting. If the run press happens a frame
	-- before movement is available, remember it like vanilla _running_wanted and
	-- complete the ADS interrupt once movement input exists.
	if not self._state_data or not self._state_data.ducking or not self._pd3ms_crouch_sprint_enabled or not self:_pd3ms_crouch_sprint_enabled() then
		self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
		return false
	end

	if self._pd3ms_has_sprint_stamina and not self:_pd3ms_has_sprint_stamina() then
		self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
		return false
	end

	if not (self._steelsight_wanted or self._state_data.in_steelsight or self._state_data.in_full_steelsight) then
		self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
		return false
	end

	t = t or self._last_t or 0

	if not self._move_dir then
		self._running_wanted = true
		self._pd3ms_crouch_sprint_run_from_ads_wanted = true
		return false
	end

	self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
	self._pd3ms_crouch_sprint_steelsight_block_until_t = nil
	self._pd3ms_crouch_sprint_ignore_held_steelsight = true
	self._steelsight_wanted = false

	if self._state_data.in_steelsight and self._end_action_steelsight then
		self:_end_action_steelsight(t)
	end

	return true
end

function PlayerStandard:_pd3ms_ignore_held_steelsight_after_run_from_ads(t, input)
	if not self._pd3ms_crouch_sprint_ignore_held_steelsight then
		return false
	end

	-- A fresh ADS press after the run press should still be honored. The guard
	-- only swallows the ADS button state that was already being held when sprint
	-- was pressed, exactly like vanilla because vanilla steelsight check does not
	-- restart ADS from btn_steelsight_state alone.
	if input and input.btn_steelsight_press then
		self._pd3ms_crouch_sprint_ignore_held_steelsight = nil
		return false
	end

	if input and input.btn_steelsight_state then
		self._steelsight_wanted = false
		return true
	end

	self._pd3ms_crouch_sprint_ignore_held_steelsight = nil
	return false
end

function PlayerStandard:_pd3ms_block_held_steelsight_after_run_press(t, input)
	-- _check_action_run runs before _check_action_steelsight in vanilla. When a
	-- fresh run press interrupts crouched ADS, the weapon can still spend a frame
	-- exiting steelsight before crouch-sprint has formally claimed its state. If
	-- this guard only runs while _pd3ms_is_crouch_sprinting() is already true, the
	-- later steelsight check can immediately re-arm ADS from the held aim button.
	if not self._pd3ms_crouch_sprint_ignore_held_steelsight then
		return false
	end

	if not self._state_data or not self._state_data.ducking then
		self._pd3ms_crouch_sprint_ignore_held_steelsight = nil
		return false
	end

	if not self._pd3ms_crouch_sprint_enabled or not self:_pd3ms_crouch_sprint_enabled() then
		self._pd3ms_crouch_sprint_ignore_held_steelsight = nil
		return false
	end

	return self:_pd3ms_ignore_held_steelsight_after_run_from_ads(t, input)
end

function PlayerStandard:_pd3ms_crouch_sprint_steelsight_blocked(t)
	-- Match vanilla standing sprint: once ADS is wanted/active, held shift must
	-- not immediately restart crouch-sprint and kick the player back out of aim.
	if self._steelsight_wanted or (self._state_data and (self._state_data.in_steelsight or self._state_data.in_full_steelsight)) then
		return true
	end

	local block_until = self._pd3ms_crouch_sprint_steelsight_block_until_t
	if not block_until then
		return false
	end

	t = t or self._last_t or 0
	if t <= block_until then
		return true
	end

	self._pd3ms_crouch_sprint_steelsight_block_until_t = nil
	return false
end

function PlayerStandard:_pd3ms_stop_preserved_stand_sprint_for_stamina(t)
	self._pd3ms_preserved_run_stamina = nil
	self._running_wanted = false
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil

	if self._end_action_running then
		self:_end_action_running(t or self._last_t or 0)
		return
	end

	self._running = nil
	self._start_running_t = nil
	self._last_run_t = nil
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
end

function PlayerStandard:_pd3ms_should_drain_preserved_stand_sprint(t)
	if not self._pd3ms_preserved_run_stamina then
		return false
	end

	if not self._running or not self._state_data or self._state_data.ducking or not self._move_dir or not self:_pd3ms_crouch_sprint_input_active() then
		self._pd3ms_preserved_run_stamina = nil
		if self._pd3ms_set_crouch_sprint_movement_running and (not self._move_dir or not self:_pd3ms_crouch_sprint_input_active()) then
			self:_pd3ms_set_crouch_sprint_movement_running(false)
		end
		return false
	end

	if not self:_pd3ms_has_sprint_stamina() then
		self:_pd3ms_stop_preserved_stand_sprint_for_stamina(t)
		return false
	end

	return true
end

function PlayerStandard:_pd3ms_update_crouch_sprint_stamina(t, dt)
	if not dt or dt <= 0 then
		return
	end

	if self._pd3ms_stop_run_if_hold_to_run_released and self:_pd3ms_stop_run_if_hold_to_run_released(t) then
		return
	end

	local drain_stamina = self:_pd3ms_is_crouch_sprinting(t) or self:_pd3ms_should_drain_preserved_stand_sprint(t)
	if not drain_stamina then
		return
	end

	local movement_ext = self._unit and self._unit:movement()
	if not movement_ext or not movement_ext.subtract_stamina then
		return
	end
	if movement_ext.running and movement_ext:running() then
		return
	end

	movement_ext:subtract_stamina(self:_pd3ms_crouch_sprint_stamina_drain_rate() * dt)

	if movement_ext._restart_stamina_regen_timer then
		movement_ext:_restart_stamina_regen_timer()
	end

	if not self:_pd3ms_has_sprint_stamina() then
		if self._state_data and self._state_data.ducking then
			self:_pd3ms_stop_crouch_sprint_for_stamina(t)
		else
			self:_pd3ms_stop_preserved_stand_sprint_for_stamina(t)
		end
	end
end

function PlayerStandard:_pd3ms_release_slide_running_stamina_lock(t)
	local movement_ext = self._unit and self._unit:movement()
	if not movement_ext then
		return false
	end

	-- Release only the movement-extension running flag so stamina can regenerate
	-- after a stamina-draining slide. Do not clear PlayerStandard._running here:
	-- if sprint is pressed during a slide, vanilla may already have played the
	-- first-person start_running redirect. Clearing _running under it splits the
	-- logical sprint state from the viewmodel and leaves the gun stuck in the
	-- run loop at walk speed when movement is released.
	if movement_ext.set_running then
		movement_ext:set_running(false)
	else
		movement_ext._is_running = false
		if movement_ext._restart_stamina_regen_timer then
			movement_ext:_restart_stamina_regen_timer()
		end
	end

	self._pd3ms_slide_released_running_stamina_lock_t = t or self._last_t or 0
	return true
end



function PlayerStandard:_pd3ms_interrupt_slide_into_sprint(t)
	if not self._is_sliding then
		return false
	end

	t = t or self._last_t or 0

	-- Sprint during an active normal slide should be a clean slide-cancel into
	-- stand-sprint. The bad path is letting vanilla start_running run while the
	-- slide still owns ducking, then clearing the movement-extension running flag
	-- for stamina regen; that can leave the first-person run redirect alive while
	-- logical sprint/speed are already gone. End the slide/duck first, then let
	-- the normal run checker start sprint from a standing state.
	self._pd3ms_slide_sprint_interrupt_t = t
	self._running_wanted = true
	self._delay_running_anim = nil

	if self._pd3ms_release_slide_running_stamina_lock then
		self:_pd3ms_release_slide_running_stamina_lock(t)
	end

	if self._state_data and self._state_data.ducking and self._end_action_ducking then
		self:_end_action_ducking(t)
	elseif self._cancel_slide then
		self:_cancel_slide(0.12)
	else
		self._is_sliding = nil
	end

	self._pd3ms_slide_sprint_interrupt_until_t = t + 0.20
	return true
end

function PlayerStandard:_pd3ms_clear_stale_running_after_move_stop(t, play_fallback_redirect)
	t = t or self._last_t or 0

	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._running_wanted = false
	self._delay_running_anim = nil

	local was_running = self._running
	local had_end_running_expire = self._end_running_expire_t ~= nil
	self._running = nil
	self._start_running_t = nil
	self._last_run_t = t
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil

	local movement_ext = self._unit and self._unit:movement()
	if movement_ext then
		if movement_ext.set_running then
			movement_ext:set_running(false)
		else
			movement_ext._is_running = false
			if movement_ext._restart_stamina_regen_timer then
				movement_ext:_restart_stamina_regen_timer()
			end
		end
	end

	if was_running and self._ext_network and self._ext_network.send then
		pcall(function()
			self._ext_network:send("action_change_run", false)
		end)
	end

	if self._state_data and self._state_data.ducking and self._stance_entered then
		self:_stance_entered(nil, 0.12)
	end

	if play_fallback_redirect and not had_end_running_expire and self._ext_camera and self.get_animation then
		if self._pd3ms_run_and_shoot_allowed and self:_pd3ms_run_and_shoot_allowed() then
			self._ext_camera:play_redirect(self:get_animation("idle"))
		elseif self._pd3ms_should_play_crouch_sprint_anim and self:_pd3ms_should_play_crouch_sprint_anim() then
			local speed_multiplier = alive(self._equipped_unit) and self._equipped_unit:base():exit_run_speed_multiplier() or 1
			self._ext_camera:play_redirect(self:get_animation("stop_running"), speed_multiplier)
		end
	end

	return true
end

function PlayerStandard:_pd3ms_clear_stale_running_if_idle(t)
	if self._move_dir or self._is_sliding or self._pd3ms_vaulting or self._is_wallrunning or self._is_wallkicking then
		return false
	end

	if self._state_data then
		if self._state_data.in_air or self._state_data.on_ladder or self:on_ladder() then
			return false
		end
	end

	local crouched = self._state_data and self._state_data.ducking
	local owned_by_crouch_sprint = self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self._pd3ms_crouch_sprint_toggled or self._pd3ms_holding_standing_crouch_sprint_stance
	local owned_by_stand_handoff = self._pd3ms_preserved_run_stamina or self._pd3ms_crouch_sprint_stand_handoff_until_t

	if crouched then
		if not (self._running or owned_by_crouch_sprint) then
			return false
		end
	else
		if not owned_by_stand_handoff then
			return false
		end
	end

	local need_fallback_redirect = self._running and not self._pd3ms_crouch_sprint_anim_playing
	return self:_pd3ms_clear_stale_running_after_move_stop(t, need_fallback_redirect)
end


function PlayerStandard:_pd3ms_crouch_sprint_run_headbob_active()
	if not self._state_data or not self._state_data.ducking then
		return false
	end

	if not self._pd3ms_crouch_sprint_enabled or not self:_pd3ms_crouch_sprint_enabled() then
		return false
	end

	if self._state_data.in_steelsight or self._state_data.in_air or self._state_data.on_ladder or self:on_ladder() then
		return false
	end

	if self._is_sliding or self._pd3ms_vaulting or self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod() then
		return false
	end

	if not self._pd3ms_run_and_shoot_allowed or not self:_pd3ms_run_and_shoot_allowed() then
		return false
	end

	if not self._pd3ms_crouch_sprint_input_active or not self:_pd3ms_crouch_sprint_input_active() then
		return false
	end

	return self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self._running
end

if PlayerStandard._get_walk_headbob and not PlayerStandard._pd3ms_wrapped_crouch_sprint_run_headbob then
	local pd3ms_original_get_walk_headbob = PlayerStandard._get_walk_headbob
	PlayerStandard._get_walk_headbob = function(self, ...)
		if self._pd3ms_crouch_sprint_run_headbob_active and self:_pd3ms_crouch_sprint_run_headbob_active() then
			-- Vanilla stand-sprint with run-and-shoot perks returns 0.1 * 0.5 = 0.05.
			-- Crouch-sprint keeps the same kind of ongoing weapon/headbob sway, tuned down
			-- slightly so it still reads as crouched instead of full-height sprinting.
			return 0.04
		end

		return pd3ms_original_get_walk_headbob(self, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_run_headbob = true
end

function PlayerStandard:_pd3ms_crouch_run_input_wanted(input)
	if self._pd3ms_hold_to_run_released and self:_pd3ms_hold_to_run_released() then
		self._running_wanted = false
		self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
		return false
	end

	if self._pd3ms_crouch_sprint_waiting_for_run_repress and self:_pd3ms_crouch_sprint_waiting_for_run_repress() then
		self._running_wanted = false
		self._pd3ms_crouch_sprint_run_from_ads_wanted = nil
		return false
	end

	if self._pd3ms_crouch_sprint_input_active and self:_pd3ms_crouch_sprint_input_active() then
		return true
	end

	if self._running_wanted then
		return true
	end

	if input and (input.btn_run_press or input.btn_run_state) then
		return true
	end

	return self._pd3ms_run_input_held and self:_pd3ms_run_input_held() or false
end

function PlayerStandard:_pd3ms_weapon_blocks_run_attack()
	return not self:_pd3ms_run_and_shoot_allowed()
end

function PlayerStandard:_pd3ms_crouch_sprint_attack_blocked(t)
	if not self:_pd3ms_weapon_blocks_run_attack() then
		self._pd3ms_crouch_sprint_attack_block_until_t = nil
		return false
	end

	t = t or self._last_t or 0
	local block_until = self._pd3ms_crouch_sprint_attack_block_until_t
	if block_until then
		if t <= block_until then
			return true
		end

		self._pd3ms_crouch_sprint_attack_block_until_t = nil
	end

	return self._shooting == true
end

function PlayerStandard:_pd3ms_crouch_sprint_reload_cancel_request_valid(t)
	local cancel_request_t = self._pd3ms_crouch_sprint_reload_cancel_request_t
	local time = t or self._last_t or 0
	return self._pd3ms_crouch_sprint_reload_cancel_requested and (not cancel_request_t or (time - cancel_request_t) <= 0.15)
end

function PlayerStandard:_pd3ms_crouch_sprint_reload_blocked(t)
	if not self._is_reloading or not self:_is_reloading() then
		self._pd3ms_crouch_sprint_reload_cancel_requested = nil
		self._pd3ms_crouch_sprint_reload_cancel_request_t = nil
		return false
	end

	local time = t or self._last_t or 0

	-- Match vanilla standing sprint: without RUN_AND_RELOAD, sprint input may
	-- cancel an active reload, but reload input may not keep sprint alive.
	if not self.RUN_AND_RELOAD then
		if self:_pd3ms_crouch_sprint_reload_cancel_request_valid(time) then
			self._pd3ms_crouch_sprint_reload_cancel_requested = nil
			self._pd3ms_crouch_sprint_reload_cancel_request_t = nil
			self._pd3ms_suppress_reload_press_until_t = time + 0.10
			if self._interupt_action_reload then
				self:_interupt_action_reload(time)
			end
			return false
		end

		self._pd3ms_crouch_sprint_reload_cancel_requested = nil
		self._pd3ms_crouch_sprint_reload_cancel_request_t = nil
		self._pd3ms_crouch_sprint_toggled = nil
		self._pd3ms_crouch_sprinting = nil
		self._pd3ms_crouch_sprint_anim_playing = nil
		self._pd3ms_holding_standing_crouch_sprint_stance = nil
		self._running = nil
		self._running_wanted = false
		self._start_running_t = nil
		self._pd3ms_crouch_sprint_wait_for_run_release = self:_pd3ms_run_input_held() and true or nil
		if self._pd3ms_set_crouch_sprint_movement_running then
			self:_pd3ms_set_crouch_sprint_movement_running(false)
		end
		return true
	end

	self._pd3ms_crouch_sprint_reload_cancel_requested = nil
	self._pd3ms_crouch_sprint_reload_cancel_request_t = nil
	return false
end

function PlayerStandard:_pd3ms_reload_should_keep_crouch_sprint_anim_off()
	if not self._is_reloading or not self:_is_reloading() or self.RUN_AND_RELOAD ~= true then
		return false
	end

	-- Vanilla stand-sprint lets the reload redirect own the viewmodel, then
	-- restores start_running from _update_reload_timers when the reload ends.
	return true
end

function PlayerStandard:_pd3ms_cancel_crouch_sprint_for_attack(t)
	if not self._state_data or not self._state_data.ducking or not self:_pd3ms_crouch_sprint_enabled() then
		return false
	end

	if not self:_pd3ms_weapon_blocks_run_attack() then
		return false
	end

	t = t or self._last_t or 0
	self._pd3ms_crouch_sprint_attack_block_until_t = t + 0.20

	-- Shooting must cancel crouch-sprint through the same running interrupt as
	-- normal standing sprint. Clear the duck-handoff guard first; otherwise the
	-- no-snap handoff wrapper would intentionally swallow this interrupt.
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil

	local was_running = self._running
	local was_crouch_sprinting = self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing
	if was_running and self._interupt_action_running then
		self:_interupt_action_running(t)
	end

	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._running_wanted = nil
	self._last_run_t = nil
	self._pd3ms_crouch_sprint_wait_for_run_release = self:_pd3ms_run_input_held() and true or nil
	if self._pd3ms_set_crouch_sprint_movement_running and (was_running or was_crouch_sprinting) then
		self:_pd3ms_set_crouch_sprint_movement_running(false)
	end

	return was_running or was_crouch_sprinting
end

function PlayerStandard:_pd3ms_should_crouch_sprint(t)
	if not self:_pd3ms_crouch_sprint_enabled() or not self._state_data or not self._state_data.ducking then
		return false
	end

	if self:_pd3ms_crouch_sprint_waiting_for_run_release() then
		return false
	end

	if self:_pd3ms_crouch_sprint_steelsight_blocked(t) then
		return false
	end

	-- Vanilla Payday 2 blocks normal sprint while carrying a bag. Keep that
	-- vanilla rule for crouch-sprint too; Restoration handles bag sprinting
	-- differently, so this standalone file is the only place we apply it.
	if managers.player and managers.player.get_my_carry_data and managers.player:get_my_carry_data() then
		self._pd3ms_crouch_sprint_toggled = nil
		return false
	end

	if not self._move_dir then
		self._pd3ms_crouch_sprint_toggled = nil
		return false
	end

	-- Keep crouch-sprint bound to the same directional rules as Payday's normal sprint.
	-- SOCD/null movement may replace the move axis, but it must not allow sprinting
	-- backward/sideways unless the player's normal sprint perks allow it.
	if self._pd3ms_can_sprint_current_direction and not self:_pd3ms_can_sprint_current_direction() then
		return false
	end

	local reload_block_until = self._pd3ms_reload_block_crouch_sprint_until_t
	if reload_block_until then
		local time = t or self._last_t or 0
		if time <= reload_block_until and self._is_reloading and self:_is_reloading() then
			self._pd3ms_crouch_sprint_toggled = nil
			return false
		end
		self._pd3ms_reload_block_crouch_sprint_until_t = nil
	end

	if self._is_sliding or self._pd3ms_vaulting or self._state_data.in_air or self._state_data.on_ladder or self:on_ladder() then
		return false
	end

	if self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod() then
		return false
	end

	if self:_pd3ms_crouch_sprint_attack_blocked(t) then
		return false
	end

	if self._pd3ms_crouch_sprint_reload_blocked and self:_pd3ms_crouch_sprint_reload_blocked(t) then
		return false
	end

	if not self:_pd3ms_has_sprint_stamina() then
		return false
	end

	return self:_pd3ms_crouch_sprint_input_active()
end

function PlayerStandard:_pd3ms_crouch_sprint_speed(speed_tweak)
	local crouch_speed = speed_tweak and speed_tweak.CROUCHING_MAX or 0
	local run_speed = speed_tweak and speed_tweak.RUNNING_MAX or crouch_speed
	return math.min(crouch_speed * 1.55, run_speed * 0.78)
end

function PlayerStandard:_pd3ms_should_hold_standing_weapon_stance_for_crouch_sprint()
	if not self._state_data or not self._state_data.ducking then
		return false
	end

	if not self._pd3ms_crouch_sprint_enabled or not self:_pd3ms_crouch_sprint_enabled() then
		return false
	end

	if self._state_data.in_steelsight or self._is_sliding or self._pd3ms_vaulting or self._state_data.in_air or self._state_data.on_ladder or self:on_ladder() then
		return false
	end

	if not self._pd3ms_crouch_sprint_input_active or not self:_pd3ms_crouch_sprint_input_active() then
		return false
	end

	if self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod() then
		return false
	end

	if self:_pd3ms_crouch_sprint_attack_blocked(self._last_t) then
		return false
	end

	if self._pd3ms_should_play_crouch_sprint_anim and not self:_pd3ms_should_play_crouch_sprint_anim() then
		return false
	end

	if self._pd3ms_crouch_sprinting or self._running then
		return true
	end

	return self._pd3ms_in_crouch_sprint_handoff and self:_pd3ms_in_crouch_sprint_handoff(self._last_t) or false
end

function PlayerStandard:_pd3ms_should_play_crouch_sprint_anim()
	if not self._ext_camera or not self.get_animation or not alive(self._equipped_unit) then
		return false
	end

	if self._state_data and self._state_data.in_steelsight then
		return false
	end

	if self:_changing_weapon() or self:_is_charging_weapon() or self:_is_meleeing() or self:_is_throwing_projectile() then
		return false
	end

	if self:_is_reloading() then
		return false
	end

	if self._shooting and not self:_pd3ms_run_and_shoot_allowed() then
		return false
	end

	return true
end


function PlayerStandard:_pd3ms_play_crouch_sprint_start_sway(t)
	-- Reuse Payday 2's normal sprint-start headbob/shaker without calling
	-- _start_action_running, because vanilla running would forcibly end ducking.
	-- Standing sprint uses 0.75; crouch-sprint uses a calmer 0.45 so it
	-- keeps the start impulse without making the weapon/camera bob look exaggerated.
	if not self._ext_camera or not self._ext_camera.play_shaker or not self._state_data or not self._setting_use_headbob then
		return
	end

	local shaker = self._ext_camera.shaker and self._ext_camera:shaker()
	local active_start_shake = self._state_data.shake_player_start_running
	if active_start_shake and shaker and shaker.is_playing and shaker:is_playing(active_start_shake) then
		return
	end

	self._state_data.shake_player_start_running = self._ext_camera:play_shaker("player_start_running", 0.45)
	self._pd3ms_crouch_sprint_sway_played = true
end

function PlayerStandard:_pd3ms_start_crouch_sprint_anim(t, defer_until_crouch_settles)
	if self._pd3ms_crouch_sprint_anim_playing or not self:_pd3ms_should_play_crouch_sprint_anim() then
		return
	end

	-- Smooth stand-sprint -> crouch-sprint handoff: do not leave a delayed
	-- gap after ducking where the weapon can fall back to the default pose for
	-- one rendered frame. The duck handler already finished by the time this
	-- runs, so immediately re-assert the run redirect instead of waiting.
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_playing = true
	self:_pd3ms_play_crouch_sprint_start_sway(t)

	-- Mirror vanilla sprint animation selection. Weapons/perks that allow
	-- run-and-shoot intentionally use idle instead of start_running so the
	-- shoot-ready sprint stance does not snap into the default sprint redirect
	-- when crouch-sprint starts from crouch.
	if self:_pd3ms_run_and_shoot_allowed() then
		self._ext_camera:play_redirect(self:get_animation("idle"))
	else
		self._ext_camera:play_redirect(self:get_animation("start_running"))
	end
end

function PlayerStandard:_pd3ms_update_crouch_sprint_anim(t, defer_until_crouch_settles)
	local pending_t = self._pd3ms_crouch_sprint_anim_pending_t
	if pending_t then
		if (t or self._last_t or 0) < pending_t then
			return
		end

		self._pd3ms_crouch_sprint_anim_pending_t = nil
		self._pd3ms_crouch_sprint_handoff_until_t = nil
		defer_until_crouch_settles = false
	end

	self:_pd3ms_start_crouch_sprint_anim(t, defer_until_crouch_settles)
end

function PlayerStandard:_pd3ms_stop_crouch_sprint_anim(t, keep_running_anim)
	local was_holding_standing_weapon_stance = self._pd3ms_holding_standing_crouch_sprint_stance

	local function restore_crouched_weapon_stance()
		if was_holding_standing_weapon_stance and self._state_data and self._state_data.ducking and not keep_running_anim and not self._is_sliding and self._stance_entered then
			self:_stance_entered(nil, 0.18)
		end
		if was_holding_standing_weapon_stance then
			self._pd3ms_holding_standing_crouch_sprint_stance = nil
		end
	end

	if not self._pd3ms_crouch_sprint_anim_playing then
		self._pd3ms_crouch_sprint_anim_pending_t = nil
		self._pd3ms_crouch_sprint_sway_played = nil
		restore_crouched_weapon_stance()
		return
	end

	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	restore_crouched_weapon_stance()
	if keep_running_anim or self._end_running_expire_t or not self:_pd3ms_should_play_crouch_sprint_anim() or self:_pd3ms_run_and_shoot_allowed() then
		return
	end

	local speed_multiplier = alive(self._equipped_unit) and self._equipped_unit:base():exit_run_speed_multiplier() or 1
	self._ext_camera:play_redirect(self:get_animation("stop_running"), speed_multiplier)
end

function PlayerStandard:_pd3ms_begin_crouch_sprint_handoff(t, was_running)
	-- Vanilla leaves _running true while the stop-running redirect expires. Do
	-- not mistake that already-ending sprint for a live stand -> crouch-sprint
	-- handoff, or crouching right after stopping can replay stop_running twice.
	if self._end_running_expire_t then
		return false
	end

	if not was_running or not self:_pd3ms_crouch_sprint_enabled() or not self:_pd3ms_crouch_sprint_input_active() or self._is_sliding then
		return false
	end

	t = t or self._last_t or 0
	self._pd3ms_crouch_sprint_handoff_until_t = t + 0.16
	return true
end

function PlayerStandard:_pd3ms_in_crouch_sprint_handoff(t)
	local until_t = self._pd3ms_crouch_sprint_handoff_until_t
	if not until_t then
		return false
	end

	t = t or self._last_t or 0
	if t <= until_t then
		return true
	end

	self._pd3ms_crouch_sprint_handoff_until_t = nil
	return false
end

function PlayerStandard:_pd3ms_in_crouch_sprint_stand_handoff(t)
	local until_t = self._pd3ms_crouch_sprint_stand_handoff_until_t
	if not until_t then
		return false
	end

	t = t or self._last_t or 0
	if t <= until_t then
		return true
	end

	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	return false
end

function PlayerStandard:_pd3ms_clear_running_without_sprintout(t)
	-- During a stand-sprint -> crouch-sprint transition, vanilla/Restoration try
	-- to end running as part of the duck action. Fully clearing _running here
	-- makes the arms briefly resolve to the neutral/default pose before the
	-- crouch-sprint redirect is restored. Keep the logical running state alive,
	-- but still clear sprintout/end timers so no stop-running animation fires.
	self._last_run_t = nil
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
	self._running_wanted = true
	self._delay_running_anim = nil
	self._running = true
	self._pd3ms_crouch_sprinting = true
end

function PlayerStandard:_pd3ms_keep_stand_sprint_without_redirect(t, start_running_t)
	self._running_wanted = false
	self._delay_running_anim = nil
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
	self._running = true
	self._start_running_t = start_running_t or self._start_running_t or t or self._last_t or 0
	self._last_run_t = nil

	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(true)
	else
		local movement_ext = self._unit and self._unit:movement()
		if movement_ext and movement_ext.set_running then
			movement_ext:set_running(true)
		end

		if self._ext_network then
			self._ext_network:send("action_change_run", true)
		end
	end
end

function PlayerStandard:_pd3ms_clear_crouch_sprint_stand_handoff()
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
end

function PlayerStandard:_pd3ms_release_stand_handoff_for_vanilla_action()
	-- The crouch-sprint -> stand-sprint handoff exists only to preserve the active
	-- sprint viewmodel through a stance change. Real vanilla actions such as ADS
	-- and reload must be allowed to interrupt running immediately; otherwise the
	-- handoff wrappers swallow _interupt_action_running() for a few frames and can
	-- cause delayed ADS or illegal sprint-reload without RUN_AND_RELOAD.
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
end

function PlayerStandard:_pd3ms_crouch_sprint_stand_handoff_active()
	return self._pd3ms_crouch_sprint_stand_handoff_until_t ~= nil or self._pd3ms_preserved_run_stamina == true
end

function PlayerStandard:_pd3ms_stop_run_if_hold_to_run_released(t)
	if not self._pd3ms_hold_to_run or not self:_pd3ms_hold_to_run() then
		return false
	end

	if not self._running or not self._state_data or self._state_data.ducking then
		return false
	end

	if self._pd3ms_run_input_held and self:_pd3ms_run_input_held() then
		return false
	end

	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._running_wanted = false

	if self._end_action_running then
		self:_end_action_running(t or self._last_t or 0)
		return true
	end

	self._running = nil
	self._start_running_t = nil
	self._last_run_t = t or self._last_t or 0
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(false)
	end
	return true
end

function PlayerStandard:_pd3ms_hold_to_run_released()
	local released = self._pd3ms_hold_to_run and self:_pd3ms_hold_to_run() and (not self._pd3ms_run_input_held or not self:_pd3ms_run_input_held())
	if released then
		self._pd3ms_crouch_sprint_require_run_repress = nil
	end
	return released
end


function PlayerStandard:_pd3ms_clear_crouch_sprint_ads_run_block_for_fresh_run()
	-- Holding run through ADS should not auto-resume crouch-sprint, but once ADS
	-- is actually gone a fresh run press should behave like normal standing sprint
	-- and start immediately instead of waiting for the short post-ADS safety timer.
	if not self._pd3ms_crouch_sprint_steelsight_block_until_t then
		return false
	end

	if self._steelsight_wanted or (self._state_data and (self._state_data.in_steelsight or self._state_data.in_full_steelsight)) then
		return false
	end

	self._pd3ms_crouch_sprint_steelsight_block_until_t = nil
	self._pd3ms_resmod_run_anim_replay_suppress_until_t = nil
	return true
end


function PlayerStandard:_pd3ms_clear_crouch_sprint_hold_release(t)
	if not self._state_data or not self._state_data.ducking or not self:_pd3ms_hold_to_run_released() then
		return false
	end

	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	self._running = nil
	self._running_wanted = false
	self._start_running_t = nil
	self._last_run_t = nil
	self._end_running_expire_t = nil
	self._running_sprintout_expire_t = nil
	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(false)
	end
	return true
end

function PlayerStandard:_pd3ms_restore_crouch_sprint(t, was_running, start_running_t)
	local in_handoff = self._pd3ms_in_crouch_sprint_handoff and self:_pd3ms_in_crouch_sprint_handoff(t)
	if not was_running or not in_handoff or not self:_pd3ms_crouch_sprint_enabled() or self._is_sliding or not self._state_data or not self._state_data.ducking or self:_pd3ms_crouch_sprint_attack_blocked(t) then
		return
	end

	self._running = true
	self._start_running_t = start_running_t or t or self._last_t or 0
	self._last_run_t = nil
	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(true)
	end
	self._pd3ms_crouch_sprinting = true

	-- Stand-sprint already has the running viewmodel redirect active. Replaying
	-- start_running immediately after vanilla's duck handler restarts that anim
	-- from frame 0, which is the visible snap/pop seen only on stand -> crouch
	-- sprint. Claim the crouch-sprint anim state without restarting the redirect;
	-- crouch -> stand stays clean for the same reason, because it preserves the
	-- active run redirect through the stance change instead of replaying it.
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_crouch_sprint_anim_playing = true
end

function PlayerStandard:_pd3ms_update_crouch_sprint(t)
	local no_move_input = not self._move_dir
	local had_crouch_sprint_state = self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self._pd3ms_crouch_sprint_toggled or self._running_wanted or (self._state_data and self._state_data.ducking and self._running)
	local had_anim = self._pd3ms_crouch_sprint_anim_playing
	local had_running = self._running

	if not self:_pd3ms_should_crouch_sprint(t) then
		if self._state_data and self._state_data.ducking and self._pd3ms_has_sprint_stamina and not self:_pd3ms_has_sprint_stamina() and self._pd3ms_stop_crouch_sprint_for_stamina then
			self:_pd3ms_stop_crouch_sprint_for_stamina(t)
			return false
		end

		local hold_to_run_released = self._pd3ms_hold_to_run_released and self:_pd3ms_hold_to_run_released()
		local keep_running_anim = not hold_to_run_released and self._running and self._pd3ms_crouch_sprint_input_active and self:_pd3ms_crouch_sprint_input_active() and self._state_data and not self._state_data.ducking
		self:_pd3ms_stop_crouch_sprint_anim(t, keep_running_anim)
		self._pd3ms_crouch_sprinting = nil

		if hold_to_run_released and self._pd3ms_clear_crouch_sprint_hold_release then
			self:_pd3ms_clear_crouch_sprint_hold_release(t)
		elseif no_move_input and self._state_data and self._state_data.ducking and had_crouch_sprint_state and self._pd3ms_clear_stale_running_after_move_stop then
			self:_pd3ms_clear_stale_running_after_move_stop(t, had_running and not had_anim)
		end
		return false
	end

	if self._pd3ms_reload_should_keep_crouch_sprint_anim_off and self:_pd3ms_reload_should_keep_crouch_sprint_anim_off() then
		self:_pd3ms_stop_crouch_sprint_anim(t, true)
	end

	self:_pd3ms_end_steelsight_for_crouch_sprint(t)

	local defer_until_crouch_settles = not self._pd3ms_crouch_sprinting and self._running
	if self:_pd3ms_crouch_sprint_input_active() then
		self._running = true
		self._start_running_t = self._start_running_t or t or self._last_t or 0
		self._last_run_t = nil
		if self._pd3ms_set_crouch_sprint_movement_running then
			self:_pd3ms_set_crouch_sprint_movement_running(true)
		end
	end
	self._pd3ms_crouch_sprinting = true
	self:_pd3ms_update_crouch_sprint_anim(t, defer_until_crouch_settles)
	return true
end

function PlayerStandard:_get_modified_move_speed(state)
	local speed_tweak = self._tweak_data.movement.speed
	local movement_speed = 0
	local final_speed = 0

	if speed_tweak then
		movement_speed = speed_tweak.STANDARD_MAX
		local speed_state = "walk"

		if state == "crouch" then
			movement_speed = speed_tweak.CROUCHING_MAX
			speed_state = "crouch"
		elseif state == "run" then
			movement_speed = speed_tweak.RUNNING_MAX
			speed_state = "run"
		end

		movement_speed = managers.modifiers:modify_value("PlayerStandard:GetMaxWalkSpeed", movement_speed, self._state_data, speed_tweak)
		local morale_boost_bonus = self._ext_movement:morale_boost()
		local multiplier = managers.player:movement_speed_multiplier(speed_state, speed_state and morale_boost_bonus and morale_boost_bonus.move_speed_bonus, nil, nil)
		multiplier = multiplier * (self._tweak_data.movement.multiplier[speed_state] or 1)

		if alive(self._equipped_unit) then
			multiplier = multiplier * self._equipped_unit:base():movement_penalty()
		end

		final_speed = movement_speed * multiplier
	end

	return final_speed
end

if PlayerStandard._update_reload_timers and not PlayerStandard._pd3ms_wrapped_crouch_sprint_reload_timers then
	local pd3ms_original_update_reload_timers = PlayerStandard._update_reload_timers
	PlayerStandard._update_reload_timers = function(self, t, dt, input, ...)
		local was_reloading = self._is_reloading and self:_is_reloading()
		local result = pd3ms_original_update_reload_timers(self, t, dt, input, ...)
		local still_reloading = self._is_reloading and self:_is_reloading()

		-- Vanilla restores start_running at the exact reload end while RUN_AND_RELOAD
		-- is active. Mark the crouch-sprint animation as already restored so the
		-- post-movement crouch-sprint update does not replay/cut the final reload frames.
		if was_reloading and not still_reloading and self.RUN_AND_RELOAD and self._running and not self._end_running_expire_t and self._move_dir and self._pd3ms_crouch_sprint_input_active and self:_pd3ms_crouch_sprint_input_active() and self._state_data and self._state_data.ducking and self._pd3ms_crouch_sprint_enabled and self:_pd3ms_crouch_sprint_enabled() then
			self._pd3ms_crouch_sprint_anim_pending_t = nil
			self._pd3ms_crouch_sprint_handoff_until_t = nil
			self._pd3ms_crouch_sprint_anim_playing = true
			self._pd3ms_crouch_sprinting = true
		end

		return result
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_reload_timers = true
end

if PlayerStandard._start_action_running and not PlayerStandard._pd3ms_wrapped_crouch_sprint_start_run then
	local pd3ms_original_start_action_running = PlayerStandard._start_action_running
	PlayerStandard._start_action_running = function(self, t, ...)
		if self._pd3ms_in_crouch_sprint_stand_handoff and self:_pd3ms_in_crouch_sprint_stand_handoff(t) then
			self:_pd3ms_keep_stand_sprint_without_redirect(t)
			return
		end

		return pd3ms_original_start_action_running(self, t, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_start_run = true
end

if PlayerStandard._interupt_action_running and not PlayerStandard._pd3ms_wrapped_crouch_sprint_interrupt_run then
	local pd3ms_original_interupt_action_running = PlayerStandard._interupt_action_running
	PlayerStandard._interupt_action_running = function(self, t, ...)
		if self._pd3ms_in_crouch_sprint_handoff and self:_pd3ms_in_crouch_sprint_handoff(t) then
			self:_pd3ms_clear_running_without_sprintout(t)
			return
		end
		if self._pd3ms_in_crouch_sprint_stand_handoff and self:_pd3ms_in_crouch_sprint_stand_handoff(t) then
			if not self._move_dir then
				if self._pd3ms_clear_crouch_sprint_stand_handoff then
					self:_pd3ms_clear_crouch_sprint_stand_handoff()
				else
					self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
					self._pd3ms_preserved_run_stamina = nil
				end
				return pd3ms_original_interupt_action_running(self, t, ...)
			end
			self:_pd3ms_keep_stand_sprint_without_redirect(t)
			return
		end

		return pd3ms_original_interupt_action_running(self, t, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_interrupt_run = true
end

if PlayerStandard._end_action_running and not PlayerStandard._pd3ms_wrapped_crouch_sprint_end_run then
	local pd3ms_original_end_action_running = PlayerStandard._end_action_running
	PlayerStandard._end_action_running = function(self, t, ...)
		if self._pd3ms_in_crouch_sprint_handoff and self:_pd3ms_in_crouch_sprint_handoff(t) then
			self:_pd3ms_clear_running_without_sprintout(t)
			return
		end
		if self._pd3ms_in_crouch_sprint_stand_handoff and self:_pd3ms_in_crouch_sprint_stand_handoff(t) then
			-- This handoff only protects the crouch->stand stance change. If movement
			-- has already stopped, this is a real sprint stop and must go through the
			-- normal running end path so stop_running plays instead of snapping.
			if not self._move_dir then
				if self._pd3ms_clear_crouch_sprint_stand_handoff then
					self:_pd3ms_clear_crouch_sprint_stand_handoff()
				else
					self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
					self._pd3ms_preserved_run_stamina = nil
				end
				return pd3ms_original_end_action_running(self, t, ...)
			end
			self:_pd3ms_keep_stand_sprint_without_redirect(t)
			return
		end

		return pd3ms_original_end_action_running(self, t, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_end_run = true
end

if PlayerStandard._start_sprintout and not PlayerStandard._pd3ms_wrapped_crouch_sprint_sprintout then
	local pd3ms_original_start_sprintout = PlayerStandard._start_sprintout
	PlayerStandard._start_sprintout = function(self, t, ...)
		if self._pd3ms_in_crouch_sprint_handoff and self:_pd3ms_in_crouch_sprint_handoff(t) then
			self._running_sprintout_expire_t = nil
			return
		end
		if self._pd3ms_in_crouch_sprint_stand_handoff and self:_pd3ms_in_crouch_sprint_stand_handoff(t) then
			if not self._move_dir then
				if self._pd3ms_clear_crouch_sprint_stand_handoff then
					self:_pd3ms_clear_crouch_sprint_stand_handoff()
				else
					self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
					self._pd3ms_preserved_run_stamina = nil
				end
				return pd3ms_original_start_sprintout(self, t, ...)
			end
			self._running_sprintout_expire_t = nil
			return
		end

		return pd3ms_original_start_sprintout(self, t, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_sprintout = true
end
if PlayerStandard._start_action_ducking and not PlayerStandard._pd3ms_wrapped_crouch_sprint_start_duck then
	local pd3ms_original_start_action_ducking = PlayerStandard._start_action_ducking
	PlayerStandard._start_action_ducking = function(self, t, ...)
		local was_running = self._running
		local start_running_t = self._start_running_t
		if self._pd3ms_begin_crouch_sprint_handoff then
			self:_pd3ms_begin_crouch_sprint_handoff(t, was_running)
		end
		local result = pd3ms_original_start_action_ducking(self, t, ...)
		self:_pd3ms_restore_crouch_sprint(t, was_running, start_running_t)
		return result
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_start_duck = true
end

if PlayerStandard._end_action_ducking and not PlayerStandard._pd3ms_wrapped_crouch_sprint_end_duck then
	local pd3ms_original_end_action_ducking = PlayerStandard._end_action_ducking
	PlayerStandard._end_action_ducking = function(self, t, ...)
		local was_crouch_sprinting = self._pd3ms_crouch_sprinting or self._running
		local start_running_t = self._start_running_t
		local preserve_run_viewmodel = was_crouch_sprinting and self._move_dir and self:_pd3ms_crouch_sprint_enabled() and self:_pd3ms_crouch_sprint_input_active() and self:_pd3ms_has_sprint_stamina() and not self:_pd3ms_crouch_sprint_attack_blocked(t) and not self._is_sliding and (not self._pd3ms_crouch_sprint_reload_blocked or not self:_pd3ms_crouch_sprint_reload_blocked(t))
		if preserve_run_viewmodel then
			self._pd3ms_crouch_sprint_stand_handoff_until_t = (t or self._last_t or 0) + 0.35
		end

		local result = pd3ms_original_end_action_ducking(self, t, ...)
		if preserve_run_viewmodel and self._state_data and not self._state_data.ducking then
			self:_pd3ms_keep_stand_sprint_without_redirect(t, start_running_t)
			self._pd3ms_preserved_run_stamina = true
			self._pd3ms_crouch_sprint_toggled = nil
			self._pd3ms_crouch_sprint_anim_pending_t = nil
			self._pd3ms_crouch_sprint_anim_playing = nil
			self._pd3ms_crouch_sprint_sway_played = nil
			self._pd3ms_holding_standing_crouch_sprint_stance = nil
		end
		self._pd3ms_crouch_sprinting = nil
		return result
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_end_duck = true
end

if PlayerStandard._check_action_reload and not PlayerStandard._pd3ms_wrapped_crouch_sprint_check_reload then
	local pd3ms_original_check_action_reload = PlayerStandard._check_action_reload
	PlayerStandard._check_action_reload = function(self, t, input, ...)
		local time = t or self._last_t or 0
		local suppress_until = self._pd3ms_suppress_reload_press_until_t
		if suppress_until and time <= suppress_until and input and input.btn_reload_press then
			return true
		elseif suppress_until and time > suppress_until then
			self._pd3ms_suppress_reload_press_until_t = nil
		end

		-- If a crouch-sprint -> stand-sprint handoff is active, do not let the
		-- handoff wrappers delay the normal reload sprint interrupt. Vanilla
		-- stand-sprint without RUN_AND_RELOAD must stop running before reload starts.
		if input and input.btn_reload_press and not self.RUN_AND_RELOAD and self._running and (not self._state_data or not self._state_data.ducking) and self._pd3ms_crouch_sprint_stand_handoff_active and self:_pd3ms_crouch_sprint_stand_handoff_active() and self._pd3ms_reload_press_can_start_reload and self:_pd3ms_reload_press_can_start_reload() then
			if self._pd3ms_stop_stand_handoff_for_reload then
				self:_pd3ms_stop_stand_handoff_for_reload(time)
			elseif self._pd3ms_release_stand_handoff_for_vanilla_action then
				self:_pd3ms_release_stand_handoff_for_vanilla_action()
			end
		end

		-- Match vanilla stand-sprint: reload input cancels sprint only when the
		-- reload can actually begin. A full clip/no-reload press should be ignored
		-- and must not momentarily stop crouch-sprint.
		if input and input.btn_reload_press and self._state_data and self._state_data.ducking and self._pd3ms_reload_press_can_start_reload and self:_pd3ms_reload_press_can_start_reload() then
			local active_crouch_sprint = self._pd3ms_crouch_sprinting or self._pd3ms_crouch_sprint_anim_playing or self._running
			if active_crouch_sprint then
				if self.RUN_AND_RELOAD then
					if self._pd3ms_stop_crouch_sprint_anim then
						self:_pd3ms_stop_crouch_sprint_anim(time, true)
					end
				else
					self._pd3ms_crouch_sprint_reload_cancel_requested = nil
					self._pd3ms_crouch_sprint_reload_cancel_request_t = nil
					self._pd3ms_reload_block_crouch_sprint_until_t = time + 0.35
					if self._pd3ms_stop_crouch_sprint_anim then
						self:_pd3ms_stop_crouch_sprint_anim(time, false)
					end
					self._pd3ms_crouch_sprinting = nil
					self._pd3ms_crouch_sprint_anim_playing = nil
					self._pd3ms_crouch_sprint_toggled = nil
					self._pd3ms_holding_standing_crouch_sprint_stance = nil
					self._running_wanted = false
					self._pd3ms_crouch_sprint_wait_for_run_release = self:_pd3ms_run_input_held() and true or nil
					self._running = nil
					self._start_running_t = nil
					if self._pd3ms_set_crouch_sprint_movement_running then
						self:_pd3ms_set_crouch_sprint_movement_running(false)
					end
				end
			end
		end

		return pd3ms_original_check_action_reload(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_check_reload = true
end

if PlayerStandard._check_action_primary_attack and not PlayerStandard._pd3ms_wrapped_crouch_sprint_primary_attack then
	local pd3ms_original_check_action_primary_attack = PlayerStandard._check_action_primary_attack
	PlayerStandard._check_action_primary_attack = function(self, t, input, ...)
		if self._pd3ms_primary_attack_input_active and self:_pd3ms_primary_attack_input_active(input) and self._pd3ms_cancel_crouch_sprint_for_attack then
			self:_pd3ms_cancel_crouch_sprint_for_attack(t)
		end

		return pd3ms_original_check_action_primary_attack(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_primary_attack = true
end

if PlayerStandard._check_action_melee and not PlayerStandard._pd3ms_wrapped_vault_blocks_melee then
	local pd3ms_original_check_action_melee = PlayerStandard._check_action_melee
	PlayerStandard._check_action_melee = function(self, t, input, ...)
		if self._pd3ms_vaulting then
			if input and (input.btn_melee_press or input.btn_melee_state or input.btn_melee_release) then
				return true
			end
			return false
		end

		return pd3ms_original_check_action_melee(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_vault_blocks_melee = true
end

if PlayerStandard._check_action_steelsight and not PlayerStandard._pd3ms_wrapped_crouch_sprint_check_steelsight then
	local pd3ms_original_check_action_steelsight = PlayerStandard._check_action_steelsight
	PlayerStandard._check_action_steelsight = function(self, t, input, ...)
		if self._pd3ms_block_held_steelsight_after_run_press and self:_pd3ms_block_held_steelsight_after_run_press(t, input) then
			return true
		end

		-- During the crouch-sprint -> stand-sprint handoff, ADS should behave like
		-- normal standing sprint: the press immediately interrupts sprint and arms
		-- steelsight. Do not preserve the no-snap handoff in this case, or the
		-- handoff can delay ADS until its short timer expires.
		if input and (input.btn_steelsight_press or input.btn_steelsight_state or self._steelsight_wanted) and self._running and (not self._state_data or not self._state_data.ducking) and self._pd3ms_crouch_sprint_stand_handoff_active and self:_pd3ms_crouch_sprint_stand_handoff_active() then
			if self._pd3ms_release_stand_handoff_for_vanilla_action then
				self:_pd3ms_release_stand_handoff_for_vanilla_action()
			end
		end

		if self._pd3ms_is_crouch_sprinting and self:_pd3ms_is_crouch_sprinting(t) then
			if self._pd3ms_ignore_held_steelsight_after_run_from_ads and self:_pd3ms_ignore_held_steelsight_after_run_from_ads(t, input) then
				return true
			end

			if input and (input.btn_steelsight_press or input.btn_steelsight_state) and self._pd3ms_cancel_crouch_sprint_for_steelsight and self:_pd3ms_cancel_crouch_sprint_for_steelsight(t) then
				return pd3ms_original_check_action_steelsight(self, t, input, ...)
			end

			self._steelsight_wanted = false
			return input and (input.btn_steelsight_press or input.btn_steelsight_state) or true
		end

		return pd3ms_original_check_action_steelsight(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_check_steelsight = true
end

if PlayerStandard._start_action_steelsight and not PlayerStandard._pd3ms_wrapped_crouch_sprint_start_steelsight then
	local pd3ms_original_start_action_steelsight = PlayerStandard._start_action_steelsight
	PlayerStandard._start_action_steelsight = function(self, t, ...)
		if self._pd3ms_crouch_sprint_ignore_held_steelsight and self._state_data and self._state_data.ducking then
			self._steelsight_wanted = false
			return false
		end

		if self._pd3ms_is_crouch_sprinting and self:_pd3ms_is_crouch_sprinting(t) then
			if self._pd3ms_cancel_crouch_sprint_for_steelsight and self:_pd3ms_cancel_crouch_sprint_for_steelsight(t) then
				return pd3ms_original_start_action_steelsight(self, t, ...)
			end

			self._steelsight_wanted = false
			return false
		end

		return pd3ms_original_start_action_steelsight(self, t, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_start_steelsight = true
end

if PlayerStandard._check_action_run and not PlayerStandard._pd3ms_wrapped_crouch_sprint_check_run then
	local pd3ms_original_check_action_run = PlayerStandard._check_action_run
	PlayerStandard._check_action_run = function(self, t, input, ...)
		if self._is_sliding and input and (input.btn_run_press or input.btn_run_state) then
			if input.btn_run_press and self._pd3ms_interrupt_slide_into_sprint and self:_pd3ms_interrupt_slide_into_sprint(t) then
				if not self._is_sliding and (not self._state_data or not self._state_data.ducking) then
					return pd3ms_original_check_action_run(self, t, input, ...)
				end
			end

			-- A held sprint key from the pre-slide sprint should not instantly cancel
			-- every slide. Only a fresh run press interrupts; otherwise block the
			-- unsafe vanilla run start while the slide still owns ducking.
			self._running_wanted = false
			self._delay_running_anim = nil
			return true
		end

		if self._pd3ms_stop_run_if_hold_to_run_released and self:_pd3ms_stop_run_if_hold_to_run_released(t) then
			return true
		end

		-- After crouch-sprint hands off into normal standing sprint, toggle sprint
		-- must behave like vanilla again. The no-snap handoff should not swallow the
		-- first toggle-off press.
		if input and input.btn_run_press and self._running and not (self._state_data and self._state_data.ducking) and not (self._pd3ms_hold_to_run and self:_pd3ms_hold_to_run()) and self._pd3ms_crouch_sprint_stand_handoff_active and self:_pd3ms_crouch_sprint_stand_handoff_active() then
			self:_pd3ms_clear_crouch_sprint_stand_handoff()
			return pd3ms_original_check_action_run(self, t, input, ...)
		end

		if self._state_data and self._state_data.ducking and self._pd3ms_crouch_sprint_enabled and self:_pd3ms_crouch_sprint_enabled() then
			if input and (input.btn_run_press or input.btn_run_release) then
				self._pd3ms_crouch_sprint_require_run_repress = nil
			end

			if input and input.btn_run_press and self._pd3ms_clear_crouch_sprint_ads_run_block_for_fresh_run then
				self:_pd3ms_clear_crouch_sprint_ads_run_block_for_fresh_run()
			end

			if input and input.btn_run_press and self._is_reloading and self:_is_reloading() then
				self._pd3ms_crouch_sprint_reload_cancel_requested = true
				self._pd3ms_crouch_sprint_reload_cancel_request_t = t or self._last_t or 0
				self._pd3ms_reload_block_crouch_sprint_until_t = nil
			end

			local run_pressed_or_pending_ads_cancel = input and input.btn_run_press
			if not run_pressed_or_pending_ads_cancel and self._pd3ms_crouch_sprint_run_from_ads_wanted then
				run_pressed_or_pending_ads_cancel = self._running_wanted or (self._pd3ms_run_input_held and self:_pd3ms_run_input_held())
			end

			if run_pressed_or_pending_ads_cancel and self._pd3ms_interrupt_steelsight_for_crouch_sprint_run then
				self:_pd3ms_interrupt_steelsight_for_crouch_sprint_run(t)
			end

			if self._pd3ms_update_crouch_sprint_toggle then
				self:_pd3ms_update_crouch_sprint_toggle(t, input)
			end
			local crouch_run_wanted = self._pd3ms_crouch_run_input_wanted and self:_pd3ms_crouch_run_input_wanted(input)

			if self._pd3ms_primary_attack_input_active and self:_pd3ms_primary_attack_input_active(input) and self._pd3ms_cancel_crouch_sprint_for_attack then
				self:_pd3ms_cancel_crouch_sprint_for_attack(t)
			elseif self:_pd3ms_update_crouch_sprint(t) then
				return true
			end

			-- With crouch-sprint enabled, crouched run input should never fall
			-- through into vanilla _start_action_running, because vanilla running
			-- forcibly interrupts ducking and snaps the player to stand-sprint. This
			-- is especially visible during the short post-shot block window.
			if crouch_run_wanted then
				self._running_wanted = false
				return true
			end
		end

		return pd3ms_original_check_action_run(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_sprint_check_run = true
end

Hooks:PostHook(PlayerStandard, "_start_action_ducking", "slide_startducking", function(self, params)
	self:_check_slide()
	self:_pd3ms_update_crouch_sprint(nil)

	-- Payday 3 crouch foley: play only for grounded normal crouch starts.
	-- Slide starts also pass through _start_action_ducking, so suppress the
	-- crouch one-shot when the slide path claimed this duck action.
	if self:_pd3ms_should_play_crouch_foley(nil, "down") then
		self:_pd3ms_play_crouch_sound(nil, "down")
	end
end)

function PlayerStandard:_check_slide()
	-- Ground-slide-only behavior: do not allow a slide to begin from a jump or fall.
	-- Existing ground slides get a tiny airborne grace in _update_movement so stairs/curbs do not instantly cancel them.
	if self._state_data.in_air then
		return
	end

	local whisper_mode = managers.groupai:state():whisper_mode()
	if not ((whisper_mode and ModernMovement.settings.slidestealth == 1) or (not whisper_mode and ModernMovement.settings.slideloud == 1)) then
		local is_running = self._running or self._pd3ms_crouch_sprinting or (self._pd3ms_is_crouch_sprinting and self:_pd3ms_is_crouch_sprinting(self._last_t))
		local can_slide = self._last_velocity_xy and is_running and (self._last_t - (self._start_running_t or 0)) > 0.2
		if can_slide then
			-- must be moving at least a certain speed to slide
			local movedir = self._move_dir or self._last_velocity_xy -- don't use self:get_sampled_xy() in any of the other lines in here
			local velocity = self._last_velocity_xy
			local horizontal_speed = math.sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
			local walkspeed = self:_get_modified_move_speed()
			local slide_cooldown = 1

			local armed_crouch_slide = self._pd3ms_crouch_slide_armed and self:_pd3ms_crouch_slide_armed(self._last_t)
			if (armed_crouch_slide or horizontal_speed > (walkspeed * 1.1)) and ((self._last_t - (self._last_slide_time or 0)) > slide_cooldown) then
				if not self:_pd3ms_crouch_slide_ready(self._last_t) then
					return
				end

				self._is_sliding = true
				self._last_speed = horizontal_speed
				self._slide_dir = mvector3.copy(movedir)
				self._slide_slow_add = 0
				self._slide_desired_dir = mvector3.copy(movedir)
				self._sprinting_speed = self:_get_modified_move_speed("run")
				-- Tuned Restoration-style slide launch is always enabled in this build.
				-- Armor/build movement still comes from real run speed, but the global range
				-- is lower than Restoration because standalone Modern Movement felt too fast/long.
				local max_slide_speed = ModernMovement:resmod_slide_max_speed_cap()
				local min_slide_speed = ModernMovement:resmod_slide_min_speed_floor()
				local slide_speed_mult = ModernMovement:resmod_slide_speed_multiplier()
				self._slide_speed = math.clamp(self._sprinting_speed * slide_speed_mult, min_slide_speed, max_slide_speed)
				self._slide_speed_factor = self._slide_speed/(self._tweak_data.movement.speed.RUNNING_MAX * 1.20)
				self._slide_refresh_t = 0
				self._slide_airborne_since = nil
				self._slide_last_z = self._unit:position().z
				self._slide_last_speed = self._slide_speed
				self._slide_has_played_shaker = nil
				self._pd3ms_slide_sound_start_t = nil
				self._pd3ms_slide_extra_sound_played = true
				self._slide_end_speed = self:_get_modified_move_speed("crouch")/4 -- don't need to calculate every frame
				self:_modernmovement_apply_slide_viewmodel_stance()
				self:_stance_entered()
				ModernMovement:play_screen_effect(0.25, Vector3(0.625, 0.625, 1.0), ModernMovement.settings.slidescreeneffectalpha, "ModernMovement_slide")
--[[
				if not self._state_data.in_air and managers.user:get_setting("use_headbob") then
					self._ext_camera:play_shaker("player_start_running", 1)
					self._slide_has_played_shaker = true
				end
--]]
				self._last_slide_time = self._last_t
				self._last_run_t = nil
			end
		end
	end
end


function PlayerStandard:_pd3ms_null_movement_enabled()
	return ModernMovement and ModernMovement.settings and ModernMovement.settings.nullmovement == true
end

local PD3MS_NULL_BINDING_NAMES = {"left", "right", "up", "down"}

function PlayerStandard:_pd3ms_null_movement_bindings()
	local cached = self._pd3ms_null_movement_binding_ids
	if cached ~= nil then
		return cached or nil
	end

	if not managers or not managers.controller or not managers.controller.get_default_wrapper_type or not managers.controller.get_settings then
		self._pd3ms_null_movement_binding_ids = false
		return nil
	end

	local wrapper_type = managers.controller:get_default_wrapper_type()
	local settings = wrapper_type and managers.controller:get_settings(wrapper_type)
	local connection_map = settings and settings.get_connection_map and settings:get_connection_map()
	local move_connection = connection_map and connection_map.move
	local btn_connections = move_connection and move_connection._btn_connections
	local keyboard = Input and Input:keyboard()

	if not btn_connections or not keyboard then
		self._pd3ms_null_movement_binding_ids = false
		return nil
	end

	local ids = {}
	for _, name in ipairs(PD3MS_NULL_BINDING_NAMES) do
		local connection = btn_connections[name]
		if not connection or connection.type ~= "button" or not connection.name then
			self._pd3ms_null_movement_binding_ids = false
			return nil
		end

		local id = Idstring(connection.name)
		if not keyboard:has_button(id) then
			self._pd3ms_null_movement_binding_ids = false
			return nil
		end

		ids[name] = id
	end

	self._pd3ms_null_movement_keyboard = keyboard
	self._pd3ms_null_movement_binding_ids = ids
	return ids
end

function PlayerStandard:_pd3ms_null_movement_key_down(id)
	local keyboard = self._pd3ms_null_movement_keyboard or (Input and Input:keyboard())
	if not keyboard or not id then
		return nil
	end

	return keyboard:down(id) == true
end

function PlayerStandard:_pd3ms_null_movement_read_dirs()
	local bindings = self:_pd3ms_null_movement_bindings()
	if not bindings then
		return nil
	end

	local left = self:_pd3ms_null_movement_key_down(bindings.left)
	local right = self:_pd3ms_null_movement_key_down(bindings.right)
	local up = self:_pd3ms_null_movement_key_down(bindings.up)
	local down = self:_pd3ms_null_movement_key_down(bindings.down)

	if left == nil or right == nil or up == nil or down == nil then
		return nil
	end

	return {
		left = left,
		right = right,
		up = up,
		down = down
	}
end

function PlayerStandard:_pd3ms_apply_null_movement()
	if not self:_pd3ms_null_movement_enabled() then
		return
	end

	if self._pd3ms_vaulting or self._state_data and self._state_data.on_zipline then
		return
	end

	if self._is_sliding then
		return
	end

	if self._unit and alive(self._unit:movement():ladder_unit()) then
		return
	end

	if self._interacting and self:_interacting() then
		return
	end

	if self._does_deploying_limit_movement and self:_does_deploying_limit_movement() then
		return
	end

	local dirs = self:_pd3ms_null_movement_read_dirs()
	if not dirs then
		return
	end

	self._pd3ms_null_move_prev = self._pd3ms_null_move_prev or {
		left = false,
		right = false,
		up = false,
		down = false
	}

	local prev = self._pd3ms_null_move_prev

	if dirs.left and not prev.left then
		self._pd3ms_null_move_last_x = -1
	end
	if dirs.right and not prev.right then
		self._pd3ms_null_move_last_x = 1
	end
	if dirs.up and not prev.up then
		self._pd3ms_null_move_last_y = 1
	end
	if dirs.down and not prev.down then
		self._pd3ms_null_move_last_y = -1
	end

	prev.left = dirs.left
	prev.right = dirs.right
	prev.up = dirs.up
	prev.down = dirs.down

	local conflict_x = dirs.left and dirs.right
	local conflict_y = dirs.up and dirs.down

	if not conflict_x and not conflict_y then
		return
	end

	local move_x = self._stick_move and mvector3.x(self._stick_move) or 0
	local move_y = self._stick_move and mvector3.y(self._stick_move) or 0

	if conflict_x then
		if not self._pd3ms_null_move_last_x then
			return
		end
		move_x = self._pd3ms_null_move_last_x
	end

	if conflict_y then
		if not self._pd3ms_null_move_last_y then
			return
		end
		move_y = self._pd3ms_null_move_last_y
	end

	local cleaned_stick = Vector3(move_x, move_y, 0)

	if mvector3.length(cleaned_stick) < PlayerStandard.MOVEMENT_DEADZONE then
		self._move_dir = nil
		self._normal_move_dir = nil
		return
	end

	self._stick_move = cleaned_stick
	self._move_dir = mvector3.copy(cleaned_stick)

	local cam_flat_rot = Rotation(self._cam_fwd_flat, math.UP)
	mvector3.rotate_with(self._move_dir, cam_flat_rot)

	self._normal_move_dir = mvector3.copy(self._move_dir)
end


Hooks:PostHook(PlayerStandard, "_determine_move_direction", "slide_movedir", function(self)
	if self._pd3ms_vaulting then
		self._move_dir = nil
		return
	end

	if self._pd3ms_apply_null_movement then
		self:_pd3ms_apply_null_movement()
	end

    if self._is_sliding then
		if self._move_dir then
			local slide_angle = math.atan2(self._slide_dir.y, self._slide_dir.x)
			local move_angle = math.atan2(self._move_dir.y, self._move_dir.x)
			-- use difference between slide and move angles to figure out if the player's trying to slow down
			local angle_diff = math.abs(math.abs(move_angle - slide_angle) - 180)
			if angle_diff < 30 then -- less than x degrees from 180 (rear angle)
				self._slide_slow_add = 1600
			elseif angle_diff < 60 then
				self._slide_slow_add = 800
			elseif angle_diff < 90 then
				self._slide_slow_add = 400
			elseif angle_diff < 120 then
				self._slide_slow_add = 200
			else
				self._slide_slow_add = 0
			end

			self._slide_desired_dir = mvector3.copy(self._move_dir)
			mvector3.multiply(self._slide_desired_dir, 0.2) -- level of control over slide direction
		else
			local whisper_mode = managers.groupai:state():whisper_mode()
			if (whisper_mode and ModernMovement.settings.slidestealth == 2) or (not whisper_mode and ModernMovement.settings.slideloud == 2) then
				-- put on the superbrakes
				self._slide_slow_add = 1600
			end
		end
		-- continue moving in slide direction
		self._move_dir = self._slide_dir
	end
end)

Hooks:PostHook(PlayerStandard, "_end_action_ducking", "slide_stopducking", function(self, params)
	local was_sliding = self._is_sliding or self._slide_speed

	self:_cancel_slide()

	-- Payday 3 crouch foley: normal grounded stand-up only. If this duck end
	-- was part of slide cleanup, skip the crouch pool so slide audio stays clean.
	if not was_sliding and self:_pd3ms_should_play_crouch_foley(nil, "up") then
		self:_pd3ms_play_crouch_sound(nil, "up")
	end
end)

if PlayerStandard._check_action_ducking and not PlayerStandard._pd3ms_wrapped_crouch_mantle_ducking then
	local pd3ms_original_check_action_ducking = PlayerStandard._check_action_ducking
	PlayerStandard._check_action_ducking = function(self, t, input, ...)
		if self._pd3ms_vaulting and self._pd3ms_vault and self._pd3ms_vault.crouch_mantle then
			self:_pd3ms_force_crouch_for_vault(t, 0.05)
			return true
		end

		if input and input.btn_duck_press and self._state_data and self._state_data.ducking and self._pd3ms_crouch_slide_armed and self:_pd3ms_crouch_slide_armed(t) then
			self:_check_slide()
			if self._is_sliding then
				return true
			end
		end

		return pd3ms_original_check_action_ducking(self, t, input, ...)
	end
	PlayerStandard._pd3ms_wrapped_crouch_mantle_ducking = true
end

Hooks:PostHook(PlayerStandard, "_update_movement", "slide_update", function(self, t, dt)
	if self._pd3ms_update_crouch_sprint then
		self:_pd3ms_update_crouch_sprint(t)
	end
	if self._pd3ms_update_crouch_sprint_stamina then
		self:_pd3ms_update_crouch_sprint_stamina(t, dt)
	end
	if self._pd3ms_clear_stale_running_if_idle then
		self:_pd3ms_clear_stale_running_if_idle(t)
	end

	if self._pd3ms_reset_air_vault_if_grounded then
		self:_pd3ms_reset_air_vault_if_grounded(t)
	end

	if self._pd3ms_vaulting then
		self:_pd3ms_update_vault(t, dt)
		return
	end

	if self:_pd3ms_try_air_vault(t) then
		return
	end

	if self._is_sliding then
		-- A ground slide may briefly leave the floor over tiny seams/stairs, but it
		-- should cancel if the player stays airborne too long.
		if self._state_data.in_air then
			self._slide_airborne_since = self._slide_airborne_since or t
			if (t - self._slide_airborne_since) > 0.08 then
				self:_cancel_slide(1)
				return
			end
		else
			self._slide_airborne_since = nil
		end

		local speed_factor_sq = self._slide_speed_factor * self._slide_speed_factor
		if not self._state_data.in_air then
			local movement_ext = self._unit:movement()
			local drain_mult = self._slide_speed / self._sprinting_speed
			movement_ext:subtract_stamina((movement_ext:_max_stamina() * 0.20) * dt * drain_mult)
			movement_ext:_restart_stamina_regen_timer()
			if self._pd3ms_release_slide_running_stamina_lock then
				self:_pd3ms_release_slide_running_stamina_lock(t)
			end
		end

		-- Standalone distance tuning: use the ResMod-style launch model, but bleed
		-- speed off moderately firmly while keeping armor caps separated so armor choice still matters.
		self._slide_speed = math.clamp(self._slide_speed - ((575 + self._slide_slow_add) * dt * speed_factor_sq), 0, 1500)

		local last_refresh_dt = t - self._slide_refresh_t
		if self._slide_refresh_t and last_refresh_dt > 0.1 then
			if not self._state_data.in_air and (t - self._last_jump_t) > 0.20 and not self._slide_has_played_shaker then
				if managers.user:get_setting("use_headbob") then
					self._ext_camera:play_shaker("player_start_running", 1)
				end

				self._slide_has_played_shaker = true
				self:_pd3ms_play_slide_sound(t)
			end

			local current_z = self._unit:position().z
			local downspeed = self._slide_last_z - current_z
			self._slide_speed = self._slide_speed + (downspeed * 10 * last_refresh_dt * speed_factor_sq)
			self._slide_refresh_t = t
			self._slide_last_z = current_z

			if self._move_dir then
				mvector3.add(self._slide_dir, self._slide_desired_dir)
				mvector3.normalize(self._slide_dir)
			end
		end

		if self._last_speed < self._slide_end_speed then
			self:_cancel_slide(1)
		end
	end
end)


-- Experimental Payday 3-ish vaulting / mantling. This is intentionally self-contained:
-- jump while moving forward into low/medium geometry, resolve the actual ledge/top first,
-- then blend the player along a Payday 3-style pull-up path. It avoids a custom
-- GameStateMachine state so it should not stall other online actions.
local PD3MS_MAX_TOP_MANTLE_DZ = 132
local PD3MS_MAX_SKINNY_MANTLE_DZ = 96
local PD3MS_MIN_LOW_FURNITURE_DZ = 16
local PD3MS_MAX_LOW_FURNITURE_DZ = 78
-- Benches/chairs may have a low seat, but normal ledges below this are better left
-- to PAYDAY 2's step/jump movement instead of starting a custom mantle.
-- Keep the tiny-lip / step-over rejection disabled for now: that restored dumpsters
-- and confirmed the remaining front-bumper issue is elsewhere. Keep the old permissive
-- low thresholds instead of the later 42-unit tiny-lip cutoff.
local PD3MS_DISABLE_TINY_LIP_REJECT = true
local PD3MS_MIN_LOW_FURNITURE_SEAT_DZ = PD3MS_MIN_LOW_FURNITURE_DZ
local PD3MS_MIN_GENERAL_MANTLE_DZ = 24
local PD3MS_MAX_STEP_OVER_TRIM_DZ = 52
local PD3MS_MAX_STEP_OVER_FACE_DZ = 38
local PD3MS_MAX_TINY_WALL_LIP_DZ = 52
local PD3MS_STANDING_MANTLE_CLEARANCE = 152
local PD3MS_CROUCH_MANTLE_CLEARANCE = 98
local PD3MS_AIR_CATCH_JUMP_GRACE = 0.14
-- Air-catch probes run while jump is held in midair. Keep normal jump mantles on
-- the full scan, but budget held-air probes separately so failed probes do not
-- spam hundreds of raycasts every few frames.
local PD3MS_AIR_CATCH_PROBE_INTERVAL = 0.16
local PD3MS_AIR_CATCH_GROUND_RESET_TIME = 0.40
local PD3MS_OBSTACLE_SCAN_HEIGHTS = {22, 30, 38, 48, 60, 72, 84, 96, 108, 120, 132, 144}
local PD3MS_OBSTACLE_SCAN_RANGES = {24, 32, 42, 56, 70, 86, 104, 120}
local PD3MS_OBSTACLE_SCAN_SIDES = {0, 4, -4, 8, -8, 14, -14, 20, -20}
local PD3MS_AIR_OBSTACLE_SCAN_HEIGHTS = {38, 56, 76, 100, 124}
local PD3MS_AIR_OBSTACLE_SCAN_RANGES = {32, 56, 84, 116}
local PD3MS_AIR_OBSTACLE_SCAN_SIDES = {0, 8, -8, 18, -18}
local PD3MS_AIR_CATCH_PREFLIGHT_INTERVAL = 0.10
local PD3MS_AIR_CATCH_BROAD_PREFLIGHT_INTERVAL = 0.32
local PD3MS_AIR_CATCH_FAIL_COOLDOWN = 0.28
local PD3MS_AIR_CATCH_FAIL_COOLDOWN_MAX = 0.58
local PD3MS_AIR_PREFLIGHT_CENTER_HEIGHTS = {52, 84, 116}
local PD3MS_AIR_PREFLIGHT_CENTER_RANGE = 116
local PD3MS_AIR_PREFLIGHT_SIDE_HEIGHTS = {64, 100}
local PD3MS_AIR_PREFLIGHT_SIDE_RANGES = {78, 112}
local PD3MS_AIR_PREFLIGHT_SIDE_OFFSETS = {18, -18}
local PD3MS_TOP_SCAN_DISTANCE_OFFSETS = {16, 26, 38, 52, 68, 88, 112, 136}
local PD3MS_TOP_SCAN_SIDE_OFFSETS = {0, 12, -12, 24, -24, 30, -30}
local PD3MS_LANDING_DEPTH_FORWARD_OFFSETS = {14, 28, 42}
local PD3MS_LANDING_DEPTH_SIDE_OFFSETS = {0, 12, -12}
local PD3MS_LANDING_DEPTH_LOOSE_FORWARD_OFFSETS = {14, 28, 44, 62, 82}
local PD3MS_LANDING_DEPTH_LOOSE_SIDE_OFFSETS = {0, 12, -12, 24, -24}
local PD3MS_TINY_LIP_BLOCK_SIDE_OFFSETS = {0, 12, -12}
local PD3MS_ZERO_VEC = Vector3(0, 0, 0)
local PD3MS_NORMAL_GRAVITY = Vector3(0, 0, -982)
local PD3MS_RAY_FROM_VEC = Vector3(0, 0, 0)
local PD3MS_RAY_TO_VEC = Vector3(0, 0, 0)
local PD3MS_FACE_SCAN_SIDE_OFFSETS = {0, 10, -10, 20, -20, 30, -30}
local PD3MS_SIDE_WALL_FORWARD_OFFSETS = {-8, 6, 20}
local PD3MS_CLEARANCE_LOOSE_SIDE_OFFSETS = {0, 16, -16}
local PD3MS_CLEARANCE_STRICT_SIDE_OFFSETS = {0, 18, -18, 32, -32}
local PD3MS_CROUCH_CLEARANCE_SIDE_OFFSETS = {8, -8, 16, -16}
local PD3MS_LOW_OVERHEAD_SIDE_OFFSETS = {0, 10, -10, 18, -18}
local PD3MS_CORRIDOR_CLEARANCE_SIDE_OFFSETS = {0, 8, -8, 16, -16}
local PD3MS_CORRIDOR_NEAR_CENTER_SIDE_OFFSETS = {8, -8, 16, -16}
local PD3MS_SKINNY_CLEARANCE_SIDE_OFFSETS = {0, 10, -10, 20, -20}
local PD3MS_BACKSTOP_SIDE_OFFSETS = {0, 8, -8, 16, -16}
local PD3MS_SHELF_BLOCK_SIDE_OFFSETS = {0, 12, -12}
local PD3MS_ROUNDED_PROP_PROFILE_DEPTHS = {0, 18, 38, 62, 88, 116}
local PD3MS_ROUNDED_PROP_PROFILE_LANES = {0, 14, -14, 28, -28}
local PD3MS_DIRECT_SKINNY_DEPTH_EXTRAS = {14, 26, 40}
local PD3MS_SIDE_SIGN_OFFSETS = {-1, 1}
local PD3MS_SKINNY_HEAD_CLEAR_SIDE_OFFSETS = {0, 8, -8, 16, -16}
local PD3MS_SKINNY_HEAD_CLEAR_WIDE_SIDE_OFFSETS = {0, 8, -8, 16, -16, 24, -24}
local PD3MS_HORIZONTAL_SKINNY_DEPTH_EXTRAS = {12, 24, 38}
local PD3MS_SPHERE_SKINNY_DEPTH_EXTRAS = {14, 28, 42}
local PD3MS_LOW_FURNITURE_BASE_DISTANCES = {10, 14, 18, 24, 32, 42, 54, 68}
local PD3MS_LOW_FURNITURE_HIT_DIST_OFFSETS = {4, 8, 14, 24, 38, 54}
local PD3MS_LOW_FURNITURE_SIDE_OFFSETS = {0, 8, -8, 16, -16, 24, -24}
local PD3MS_ROUNDED_FRONT_DISTANCE_OFFSETS = {8, 14, 22, 32, 44, 58, 76, 98, 124, 154}
local PD3MS_ROUNDED_FRONT_SIDE_OFFSETS = {0, 10, -10, 20, -20, 34, -34}
local PD3MS_WALL_CAP_DISTANCE_OFFSETS = {-8, -3, 2, 6, 10, 15, 22, 30, 40}
local PD3MS_WALL_CAP_SIDE_OFFSETS = {0, 4, -4, 8, -8, 14, -14, 22, -22, 30, -30}
local PD3MS_TOP_SUPPORT_CHECKS = {
	{0, 0},
	{18, 0},
	{-14, 0},
	{0, 18},
	{0, -18}
}
local PD3MS_RAISED_TOP_CHECKS = {
	{18, 0},
	{26, 0},
	{34, 0},
	{42, 0},
	{30, 10},
	{30, -10}
}
local PD3MS_WALL_CAP_SUPPORT_CHECKS = {
	{0, 0},
	{5, 0},
	{-5, 0},
	{0, 7},
	{0, -7},
	{9, 7},
	{9, -7},
	{-7, 7},
	{-7, -7}
}
local PD3MS_STAIR_RISER_HEIGHT_ROWS = {
	{8, 30, 154},
	{20, 38, 166},
	{34, 48, 178},
	{48, 60, 190}
}
local PD3MS_STAIR_RISER_START_OFFSETS = {8, 26, 48, 74, 104, 136}
local PD3MS_STAIR_RISER_SIDE_OFFSETS = {0, 10, -10, 20, -20}
local PD3MS_STAIR_APPROACH_STARTS = {-136, -112, -88, -64, -42, -24}
local PD3MS_STAIR_APPROACH_HEIGHTS = {-10, -24, -38, -54, -72, -92}
local PD3MS_STAIR_APPROACH_SIDES = {0, 10, -10, 20, -20}
local PD3MS_ESTIMATE_SKINNY_HEIGHTS = {28, 34, 42, 50, 58, 68, 80, 92, 104, 116, 128, 140}
local PD3MS_ESTIMATE_SKINNY_SIDES = {0, 4, -4, 8, -8, 14, -14}
local PD3MS_HORIZONTAL_SKINNY_SIDES = {0, 4, -4, 8, -8, 14, -14, 22, -22}
local PD3MS_HORIZONTAL_SKINNY_HEIGHTS = {104, 96, 88, 80, 72, 64, 56, 48, 40, 32, 26}
local PD3MS_CORRIDOR_SAMPLE_FACTORS = {-1, 0, 0.35, 0.70, 1}
local PD3MS_STAIR_VALIDATE_DISTANCES = {0, 16, 30, 46, 64, 84, 106, 130, 156, 184}
local PD3MS_STAIR_VALIDATE_SIDES = {0, 12, -12, 24, -24}
local PD3MS_FINAL_STAIR_SAMPLE_DISTANCES = {-132, -104, -78, -54, -32, -14, 4, 18}
local PD3MS_FINAL_STAIR_SAMPLE_SIDES = {0, 12, -12}
local PD3MS_ESTIMATE_SKINNY_SCAN_OFFSETS = {-3, 2, 6, 10, 15}
local PD3MS_ESTIMATE_SKINNY_SCAN_SIDES = {0, 6, -6, 12, -12}
local PD3MS_SPHERE_SKINNY_SIDE_OFFSETS = {0, 5, -5, 10, -10, 16, -16, 24, -24, 32, -32}
local PD3MS_SPHERE_SKINNY_HEIGHTS = {100, 94, 88, 82, 76, 70, 64, 58, 52, 46, 40, 34, 28}
local PD3MS_SPHERE_SKINNY_RADII = {5, 8}
local PD3MS_DIRECT_SKINNY_HIT_DISTANCE_OFFSETS = {-12, -6, 0, 5, 11, 19, 30}
local PD3MS_DIRECT_SKINNY_DEFAULT_DISTANCES = {6, 10, 14, 20, 28, 38, 50, 64, 82, 100, 116}
local PD3MS_DIRECT_SKINNY_SIDE_OFFSETS = {0, 4, -4, 8, -8, 14, -14, 22, -22}
local PD3MS_OVER_LANDING_OFFSETS = {64, 82, 104, 132, 164}
local PD3MS_VAULT_ANIM_CANDIDATES = {"interact", "interaction", "pickup", "use_item", "melee_item"}

local PD3MS_FORCE_VAULT_DEBUG = false

function PlayerStandard:_pd3ms_vault_debug_enabled()
	return PD3MS_FORCE_VAULT_DEBUG or (ModernMovement and ModernMovement.settings and ModernMovement.settings.vaultdebug)
end

function PlayerStandard:_pd3ms_vault_log(message)
	if self:_pd3ms_vault_debug_enabled() and log then
		pcall(function()
			log("[ModernMovement Vault] " .. tostring(message))
		end)
	end
end

function PlayerStandard:_pd3ms_debug_ray_info(label, ray, pos, forward, dist_override)
	if not self:_pd3ms_vault_debug_enabled() then
		return
	end

	if not ray or not ray.position then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log(tostring(label) .. ": nil")
		end
		return
	end

	local dist = dist_override or (pos and self:_pd3ms_flat_distance_from(pos, ray.position)) or 0
	local dz = pos and (ray.position.z - pos.z) or 0
	local nz = ray.normal and ray.normal.z or 0
	local fp = (pos and forward) and self:_pd3ms_forward_progress_from(pos, ray.position, forward) or dist
	local unit_name = "?"
	pcall(function()
		if ray.unit and ray.unit.name then
			unit_name = tostring(ray.unit:name())
		end
	end)

	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log(tostring(label) .. " dist=" .. tostring(math.floor(dist or 0)) .. " fp=" .. tostring(math.floor(fp or 0)) .. " dz=" .. tostring(math.floor(dz or 0)) .. " nz=" .. tostring(math.floor((nz or 0) * 100) / 100) .. " unit=" .. unit_name)
	end
end

function PlayerStandard:_pd3ms_debug_target_info(label, target, pos, forward, dz, support, obstacle_dist)
	if not self:_pd3ms_vault_debug_enabled() then
		return
	end

	if not target then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log(tostring(label) .. ": nil")
		end
		return
	end

	local flat = pos and self:_pd3ms_flat_distance_from(pos, target) or 0
	local fp = (pos and forward) and self:_pd3ms_forward_progress_from(pos, target, forward) or flat
	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log(tostring(label) .. " flat=" .. tostring(math.floor(flat or 0)) .. " fp=" .. tostring(math.floor(fp or 0)) .. " dz=" .. tostring(math.floor(dz or 0)) .. " support=" .. tostring(support or 0) .. " obstacle_dist=" .. tostring(math.floor(obstacle_dist or 0)))
	end
end

function PlayerStandard:_pd3ms_flat_forward()
	local rotation_flat = self._ext_camera:rotation()
	mvector3.set_x(rotation_flat, 0)
	mvector3.set_y(rotation_flat, 0)

	local forward = Vector3(0, 1, 0)
	mvector3.rotate_with(forward, rotation_flat)
	mvector3.set_z(forward, 0)
	if mvector3.normalize(forward) == 0 then
		return nil
	end

	return forward
end

function PlayerStandard:_pd3ms_slot_mask(slot_name)
	if not slot_name or not managers or not managers.slot or not managers.slot.get_mask then
		return nil
	end

	local cache = self._pd3ms_slot_mask_cache
	if not cache then
		cache = {}
		self._pd3ms_slot_mask_cache = cache
	end

	local cached = cache[slot_name]
	if cached ~= nil then
		return cached or nil
	end

	local ok, mask = pcall(function()
		return managers.slot:get_mask(slot_name)
	end)

	cache[slot_name] = ok and mask or false

	return ok and mask or nil
end

function PlayerStandard:_pd3ms_unit_in_slot_name(unit, slot_name)
	if not unit or not unit.in_slot then
		return false
	end

	local mask = self:_pd3ms_slot_mask(slot_name)
	return mask and unit:in_slot(mask) or false
end

function PlayerStandard:_pd3ms_bad_vault_unit_slot_mask()
	local cached = self._pd3ms_bad_vault_unit_slot_mask_cache
	if cached ~= nil then
		return cached or nil
	end

	if not managers or not managers.slot or not managers.slot.get_mask then
		self._pd3ms_bad_vault_unit_slot_mask_cache = false
		return nil
	end

	local ok, mask = pcall(function()
		return managers.slot:get_mask("corpses", "persons", "criminals", "enemies", "civilians")
	end)

	self._pd3ms_bad_vault_unit_slot_mask_cache = ok and mask or false

	return ok and mask or nil
end

function PlayerStandard:_pd3ms_is_corpse_vault_unit(unit)
	if not unit then
		return false
	end

	-- PAYDAY 2 moves dead enemies/civilians into the dedicated corpses slot.
	-- The mantle scan allows non-world props, so corpse ragdolls need their own
	-- rejection before they can be treated like climbable low furniture.
	if self:_pd3ms_unit_in_slot_name(unit, "corpses") then
		return true
	end

	local parent_unit = nil
	if unit.parent then
		local ok, result = pcall(function()
			return unit:parent()
		end)
		if ok and result and alive(result) then
			parent_unit = result
			if self:_pd3ms_unit_in_slot_name(parent_unit, "corpses") then
				return true
			end
		end
	end

	local enemy_manager = managers and managers.enemy
	if enemy_manager and enemy_manager.get_corpse_unit_data_from_key and unit.key then
		local ok, corpse_data = pcall(function()
			return enemy_manager:get_corpse_unit_data_from_key(unit:key())
		end)
		if ok and corpse_data then
			return true
		end

		if parent_unit and parent_unit.key then
			ok, corpse_data = pcall(function()
				return enemy_manager:get_corpse_unit_data_from_key(parent_unit:key())
			end)
			if ok and corpse_data then
				return true
			end
		end
	end

	if unit.character_damage then
		local ok, char_damage = pcall(function()
			return unit:character_damage()
		end)
		if ok and char_damage and char_damage.dead then
			local dead_ok, is_dead = pcall(function()
				return char_damage:dead()
			end)
			if dead_ok and is_dead then
				return true
			end
		end
	end

	return false
end

function PlayerStandard:_pd3ms_is_lootbag_vault_unit(unit)
	if not unit then
		return false
	end

	-- Loose loot bags have the carry_data extension. Treat them like characters/corpses:
	-- they are dynamic gameplay objects, not stable mantle geometry. This keeps players
	-- from grabbing a moving/janky bag collision as a ledge.
	if unit.carry_data then
		local ok, carry_data = pcall(function()
			return unit:carry_data()
		end)
		if ok and carry_data then
			return true
		end
	end

	local unit_name = nil
	if unit.name then
		local ok, name = pcall(function()
			return tostring(unit:name())
		end)
		if ok and name then
			unit_name = string.lower(name)
		end
	end

	if unit_name then
		return unit_name:find("lootbag", 1, true)
			or unit_name:find("loot_bag", 1, true)
			or unit_name:find("gen_pku_loot", 1, true)
			or unit_name:find("units/payday2/pickups/gen_pku", 1, true)
			or false
	end

	return false
end

function PlayerStandard:_pd3ms_is_bad_vault_unit(unit)
	if not unit then
		return false
	end

	if self:_pd3ms_is_lootbag_vault_unit(unit) then
		return true
	end

	-- Fast path: one cached combined mask catches normal live characters and normal corpse slot ragdolls.
	-- The deeper corpse helper below is kept for unusual parented ragdoll/body units that may not report their own slot.
	if unit.in_slot then
		local bad_mask = self:_pd3ms_bad_vault_unit_slot_mask()
		if bad_mask and unit:in_slot(bad_mask) then
			return true
		end
	end

	return self:_pd3ms_is_corpse_vault_unit(unit)
end

function PlayerStandard:_pd3ms_world_ray(from_pos, to_pos, allow_non_world)
	if not Utils or not Utils.GetCrosshairRay then
		return nil
	end

	local ray = Utils:GetCrosshairRay(from_pos, to_pos)
	if not ray or not ray.unit or not alive(ray.unit) then
		return nil
	end

	if self:_pd3ms_is_bad_vault_unit(ray.unit) then
		return nil
	end

	-- For ledge/top scans, allow non-world solid units too. A lot of mantle-looking props
	-- are not in pure world_geometry.
	if not allow_non_world then
		local world_mask = self:_pd3ms_slot_mask("world_geometry")
		if world_mask and ray.unit.in_slot and not ray.unit:in_slot(world_mask) then
			return nil
		end
	end

	return ray
end

function PlayerStandard:_pd3ms_world_ray_xyz(from_x, from_y, from_z, to_x, to_y, to_z, allow_non_world)
	mvector3.set_static(PD3MS_RAY_FROM_VEC, from_x, from_y, from_z)
	mvector3.set_static(PD3MS_RAY_TO_VEC, to_x, to_y, to_z)
	return self:_pd3ms_world_ray(PD3MS_RAY_FROM_VEC, PD3MS_RAY_TO_VEC, allow_non_world)
end

function PlayerStandard:_pd3ms_world_sphere_ray_xyz(from_x, from_y, from_z, to_x, to_y, to_z, radius, allow_non_world)
	mvector3.set_static(PD3MS_RAY_FROM_VEC, from_x, from_y, from_z)
	mvector3.set_static(PD3MS_RAY_TO_VEC, to_x, to_y, to_z)
	return self:_pd3ms_world_sphere_ray(PD3MS_RAY_FROM_VEC, PD3MS_RAY_TO_VEC, radius, allow_non_world)
end

function PlayerStandard:_pd3ms_world_sphere_ray(from_pos, to_pos, radius, allow_non_world)
	if not World or not World.raycast then
		return nil
	end

	local slot_mask = nil
	if allow_non_world then
		if self._pd3ms_world_static_slot_mask_cache ~= nil then
			slot_mask = self._pd3ms_world_static_slot_mask_cache or nil
		elseif managers and managers.slot and managers.slot.get_mask then
			local ok, mask = pcall(function()
				return managers.slot:get_mask("world_geometry", "statics")
			end)
			self._pd3ms_world_static_slot_mask_cache = ok and mask or false
			slot_mask = ok and mask or nil
		end
	else
		slot_mask = self:_pd3ms_slot_mask("world_geometry")
	end

	local ray = nil
	if slot_mask then
		ray = World:raycast("ray", from_pos, to_pos, "slot_mask", slot_mask, "sphere_cast_radius", radius or 6, "ray_type", "body walk")
	else
		ray = World:raycast("ray", from_pos, to_pos, "sphere_cast_radius", radius or 6, "ray_type", "body walk")
	end

	if not ray or not ray.unit or not alive(ray.unit) then
		return nil
	end

	if self:_pd3ms_is_bad_vault_unit(ray.unit) then
		return nil
	end

	if not allow_non_world then
		local world_mask = self:_pd3ms_slot_mask("world_geometry")
		if world_mask and ray.unit.in_slot and not ray.unit:in_slot(world_mask) then
			return nil
		end
	end

	return ray
end

function PlayerStandard:_pd3ms_is_moving_forward(forward)
	local move_dir = self._move_dir
	if not move_dir or not forward then
		return false
	end

	local move_x = move_dir.x or 0
	local move_y = move_dir.y or 0
	local len = math.sqrt((move_x * move_x) + (move_y * move_y))
	if len <= 0 then
		return false
	end

	local dot = ((move_x / len) * forward.x) + ((move_y / len) * forward.y)
	-- Thin rails can stop the player almost immediately, especially when the player is
	-- already touching them. Keep the mantle intent requirement, but do not require a
	-- perfect run-forward vector or the normal Payday 2 jump path will win first.
	return dot > 0.18
end

function PlayerStandard:_pd3ms_smoothstep(value)
	value = math.clamp(value, 0, 1)
	return value * value * (3 - (2 * value))
end

function PlayerStandard:_pd3ms_smootherstep(value)
	value = math.clamp(value, 0, 1)
	return value * value * value * (value * ((value * 6) - 15) + 10)
end

function PlayerStandard:_pd3ms_ease_out(value)
	value = math.clamp(value, 0, 1)
	return 1 - ((1 - value) * (1 - value))
end

function PlayerStandard:_pd3ms_ease_in(value)
	value = math.clamp(value, 0, 1)
	return value * value
end

function PlayerStandard:_pd3ms_lerp_vec(a, b, p)
	local out = mvector3.copy(b)
	mvector3.subtract(out, a)
	mvector3.multiply(out, p)
	mvector3.add(out, a)
	return out
end

function PlayerStandard:_pd3ms_offset_from(pos, forward, forward_amt, side_amt, up_amt)
	local out_x = pos.x
	local out_y = pos.y
	local out_z = pos.z + (up_amt or 0)

	if forward then
		local fwd = forward_amt or 0
		local side = side_amt or 0
		out_x = out_x + (forward.x * fwd) + (forward.y * side)
		out_y = out_y + (forward.y * fwd) - (forward.x * side)
	end

	return Vector3(out_x, out_y, out_z)
end

function PlayerStandard:_pd3ms_apply_vault_position(pos, vel, hard_snap)
	local mover = self._unit:mover()

	-- Tiny final settling helper only. Normal mantle travel is driven by velocity plus
	-- very small anti-stall nudges, not the old large per-frame set_position pull.
	if hard_snap then
		if self._unit and self._unit.set_position then
			pcall(function()
				self._unit:set_position(pos)
			end)
		end

		if mover and mover.set_position then
			pcall(function()
				mover:set_position(pos)
			end)
		end
	end

	if mover then
		mover:set_gravity(PD3MS_ZERO_VEC)
		mover:set_velocity(vel or PD3MS_ZERO_VEC)
	end
end

function PlayerStandard:_pd3ms_set_vault_velocity(vel)
	local mover = self._unit:mover()
	if mover then
		mover:set_gravity(PD3MS_ZERO_VEC)
		mover:set_velocity(vel or PD3MS_ZERO_VEC)
	end
end

function PlayerStandard:_pd3ms_micro_correct_vault(target_pos, max_step, vertical_only)
	-- This is the only intentional position correction during the visible mantle. It is capped
	-- extremely low so it reads as a smooth pull, not the old HybridPull teleport.
	if not target_pos or not max_step or max_step <= 0 then
		return
	end

	local current = self._unit:position()
	local delta = mvector3.copy(target_pos)
	mvector3.subtract(delta, current)

	if vertical_only then
		delta.x = 0
		delta.y = 0
	end

	local dist = mvector3.normalize(delta)
	if dist <= 0 then
		return
	end

	local step = math.min(dist, max_step)
	mvector3.multiply(delta, step)
	local next_pos = mvector3.copy(current)
	mvector3.add(next_pos, delta)

	if self._unit and self._unit.set_position then
		pcall(function()
			self._unit:set_position(next_pos)
		end)
	end

	local mover = self._unit:mover()
	if mover then
		mover:set_gravity(PD3MS_ZERO_VEC)
		if mover.set_position then
			pcall(function()
				mover:set_position(next_pos)
			end)
		end
	end
end

function PlayerStandard:_pd3ms_down_ray_at(pos, top_offset, bottom_offset, allow_non_world)
	return self:_pd3ms_world_ray_xyz(pos.x, pos.y, pos.z + (top_offset or 210), pos.x, pos.y, pos.z + (bottom_offset or -90), allow_non_world)
end

function PlayerStandard:_pd3ms_down_ray_offset_from(pos, forward, forward_amt, side_amt, up_amt, top_offset, bottom_offset, allow_non_world)
	local fwd = forward_amt or 0
	local side = side_amt or 0
	local base_z = pos.z + (up_amt or 0)
	local sample_x = pos.x + (forward.x * fwd) + (forward.y * side)
	local sample_y = pos.y + (forward.y * fwd) - (forward.x * side)
	return self:_pd3ms_world_ray_xyz(sample_x, sample_y, base_z + (top_offset or 210), sample_x, sample_y, base_z + (bottom_offset or -90), allow_non_world)
end

function PlayerStandard:_pd3ms_flat_distance_from(pos, point)
	local dx = point.x - pos.x
	local dy = point.y - pos.y
	return math.sqrt((dx * dx) + (dy * dy))
end

function PlayerStandard:_pd3ms_flat_distance_between(a, b)
	local dx = b.x - a.x
	local dy = b.y - a.y
	return math.sqrt((dx * dx) + (dy * dy))
end

function PlayerStandard:_pd3ms_forward_progress_from(start_pos, point, forward)
	return ((point.x - start_pos.x) * forward.x) + ((point.y - start_pos.y) * forward.y)
end

function PlayerStandard:_pd3ms_find_obstacle_ray(pos, forward, air_catch_probe)
	-- Nearby obstacle scan. Normal jump mantles keep the full broad scan. Air catch
	-- can run repeatedly while jump is held, so it uses a smaller centered scan that
	-- still finds the common ledge/rail cases without turning every miss into a large
	-- burst of raycasts.
	local heights = air_catch_probe and PD3MS_AIR_OBSTACLE_SCAN_HEIGHTS or PD3MS_OBSTACLE_SCAN_HEIGHTS
	local ranges = air_catch_probe and PD3MS_AIR_OBSTACLE_SCAN_RANGES or PD3MS_OBSTACLE_SCAN_RANGES
	local side_offsets = air_catch_probe and PD3MS_AIR_OBSTACLE_SCAN_SIDES or PD3MS_OBSTACLE_SCAN_SIDES
	local best_ray = nil
	local best_score = nil
	local best_dist = nil

	local pos_x = pos.x
	local pos_y = pos.y
	local pos_z = pos.z
	local fwd_x = forward.x
	local fwd_y = forward.y
	local right_x = fwd_y
	local right_y = -fwd_x

	for _, height in ipairs(heights) do
		local scan_z = pos_z + height
		for _, range in ipairs(ranges) do
			local range_x = fwd_x * range
			local range_y = fwd_y * range
			for _, side in ipairs(side_offsets) do
				local side_x = right_x * side
				local side_y = right_y * side

				local ray = self:_pd3ms_world_ray_xyz(pos_x + side_x, pos_y + side_y, scan_z, pos_x + range_x + side_x, pos_y + range_y + side_y, scan_z, true)
				if ray and ray.position then
					local dx = ray.position.x - pos_x
					local dy = ray.position.y - pos_y
					local dist = math.sqrt((dx * dx) + (dy * dy))
					local face_ok = true
					local face_score = 0

					if ray.normal then
						local normal_z = ray.normal.z or 0
						if math.abs(normal_z) > 0.72 then
							-- Rounded rail tops / narrow trim can report as mostly upward. Do not reject
							-- them here; later top/clearance checks decide whether this is climbable.
							face_score = 11 + math.abs(normal_z) * 5
						else
							local normal_x = ray.normal.x or 0
							local normal_y = ray.normal.y or 0
							local normal_len_sq = (normal_x * normal_x) + (normal_y * normal_y)
							if normal_len_sq > 0 then
								local inv_len = 1 / math.sqrt(normal_len_sq)
								local face_dot = (normal_x * inv_len * fwd_x) + (normal_y * inv_len * fwd_y)
								face_ok = face_dot < 0.22
								face_score = math.max(face_dot, -0.8) * 18
							end
						end
					end

					if face_ok and dist >= 3 and dist <= 112 then
						local height_score = math.abs(height - 82) * 0.14
						local dist_score = math.abs(dist - 44) * 0.36
						local side_score = math.abs(side) * 0.50
						local score = dist_score + height_score + side_score + face_score
						if not best_score or score < best_score then
							best_ray = ray
							best_score = score
							best_dist = dist

							if air_catch_probe and side == 0 and score <= 14 and dist <= 104 then
								return best_ray, best_dist
							end
						end
					end
				end
			end
		end
	end

	return best_ray, best_dist
end


function PlayerStandard:_pd3ms_target_lateral_from(pos, forward, target_pos)
	if not pos or not forward or not target_pos then
		return 0
	end

	return ((target_pos.x - pos.x) * forward.y) - ((target_pos.y - pos.y) * forward.x)
end

function PlayerStandard:_pd3ms_front_face_coherence(pos, forward, obstacle_ray, obstacle_dist, top_dz)
	-- Corner mantles usually happen when the scan catches the sharp edge between two faces.
	-- A real mantleable face has a coherent vertical/front surface across both near-side lanes.
	-- A corner/edge either has only one side lane, or the side lanes report different normals.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position then
		return 0, 0, 0, 0, 0, 0
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 4, 124)
	local obstacle_dz = obstacle_ray.position.z - pos.z
	local primary_height = math.clamp(obstacle_dz, 28, 118)
	local face_height = math.clamp((top_dz or obstacle_dz or 64) * 0.52, 28, 108)
	local scan_height_count = 1
	local second_height = nil
	if math.abs(face_height - primary_height) > 9 then
		scan_height_count = 2
		second_height = face_height
	end

	local hit_sides = self._pd3ms_face_hit_sides
	if not hit_sides then
		hit_sides = {}
		self._pd3ms_face_hit_sides = hit_sides
	end

	local hit_normal_x = self._pd3ms_face_hit_normal_x
	if not hit_normal_x then
		hit_normal_x = {}
		self._pd3ms_face_hit_normal_x = hit_normal_x
	end

	local hit_normal_y = self._pd3ms_face_hit_normal_y
	if not hit_normal_y then
		hit_normal_y = {}
		self._pd3ms_face_hit_normal_y = hit_normal_y
	end

	local total = 0
	for height_index = 1, scan_height_count do
		local height = height_index == 1 and primary_height or second_height
		for _, side in ipairs(PD3MS_FACE_SCAN_SIDE_OFFSETS) do
			local ray = self:_pd3ms_horizontal_ray(pos, forward, 0, hit_dist + 22, side, height, true)
			if ray and ray.position and ray.normal then
				local fp = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
				if fp >= hit_dist - 22 and fp <= hit_dist + 30 then
					local normal_z = math.abs(ray.normal.z or 0)
					if normal_z <= 0.66 then
						local normal_x = ray.normal.x or 0
						local normal_y = ray.normal.y or 0
						local normal_len_sq = (normal_x * normal_x) + (normal_y * normal_y)
						if normal_len_sq > 0 then
							local inv_len = 1 / math.sqrt(normal_len_sq)
							total = total + 1
							hit_sides[total] = side
							hit_normal_x[total] = normal_x * inv_len
							hit_normal_y[total] = normal_y * inv_len
						end
					end
				end
			end
		end
	end

	if total == 0 then
		return 0, 0, 0, 0, 0, 0
	end

	local best_same = 0
	local best_left = 0
	local best_right = 0
	local best_center = 0

	for ref_i = 1, total do
		local same = 0
		local left = 0
		local right = 0
		local center = 0
		local ref_x = hit_normal_x[ref_i]
		local ref_y = hit_normal_y[ref_i]

		for hit_i = 1, total do
			local dot = (ref_x * hit_normal_x[hit_i]) + (ref_y * hit_normal_y[hit_i])
			if dot >= 0.72 then
				same = same + 1
				local side = hit_sides[hit_i]
				if side < 0 then
					left = left + 1
				elseif side > 0 then
					right = right + 1
				else
					center = center + 1
				end
			end
		end

		if same > best_same or (same == best_same and (left + right + center) > (best_left + best_right + best_center)) then
			best_same = same
			best_left = left
			best_right = right
			best_center = center
		end
	end

	return best_same, best_left, best_right, best_center, math.max(0, total - best_same), total
end

function PlayerStandard:_pd3ms_is_corner_mantle_target(pos, forward, obstacle_ray, obstacle_dist, target_pos, top_dz, top_support, wall_cap_top, low_furniture_top)
	if not pos or not forward or not obstacle_ray or not target_pos then
		return false
	end

	local same, left, right, center, split_normals, total = self:_pd3ms_front_face_coherence(pos, forward, obstacle_ray, obstacle_dist, top_dz)
	if total <= 0 then
		return false
	end

	-- Good front-facing ledges/walls produce at least one matching vertical face hit on
	-- both sides of the player. Corners usually only support one side, or split into two
	-- unrelated perpendicular normals.
	if same >= 3 and left > 0 and right > 0 then
		return false
	end

	local one_sided = left == 0 or right == 0
	local lateral = math.abs(self:_pd3ms_target_lateral_from(pos, forward, target_pos) or 0)
	local dz = top_dz or 0
	local support = top_support or 0
	local risky_corner_shape = wall_cap_top or split_normals >= 2 or lateral >= 18 or dz >= 56 or support <= 2

	-- Bench/chair rescue targets are intentionally allowed to be narrower than wall caps.
	-- Only reject them when the front-face normals clearly split like a corner.
	if low_furniture_top then
		risky_corner_shape = split_normals >= 2 and one_sided and same <= 2
	end

	if risky_corner_shape and (one_sided or same <= 2) then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("reject: corner mantle face same=" .. tostring(same) .. " left=" .. tostring(left) .. " right=" .. tostring(right) .. " split=" .. tostring(split_normals) .. " total=" .. tostring(total) .. " dz=" .. tostring(math.floor(dz or 0)) .. " lateral=" .. tostring(math.floor(lateral or 0)) .. " wall_cap=" .. tostring(wall_cap_top) .. " low_furniture=" .. tostring(low_furniture_top))
		end
		return true
	end

	return false
end


function PlayerStandard:_pd3ms_obstacle_face_dot(forward, obstacle_ray)
	if not forward or not obstacle_ray or not obstacle_ray.normal then
		return nil
	end

	local normal_z = math.abs(obstacle_ray.normal.z or 0)
	if normal_z > 0.68 then
		return nil
	end

	local normal_x = obstacle_ray.normal.x or 0
	local normal_y = obstacle_ray.normal.y or 0
	local normal_len_sq = (normal_x * normal_x) + (normal_y * normal_y)
	if normal_len_sq <= 0 then
		return nil
	end

	local inv_len = 1 / math.sqrt(normal_len_sq)
	return (normal_x * inv_len * forward.x) + (normal_y * inv_len * forward.y)
end
function PlayerStandard:_pd3ms_is_glancing_corner_mantle_target(pos, forward, obstacle_ray, obstacle_dist, target_pos, top_dz, top_support, wall_cap_top, low_furniture_top)
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position or not target_pos then
		return false
	end

	-- Low furniture uses verified backstop/support logic and can be approached from odd angles.
	-- Do not let the corner guard steal those bench/chair rescue cases.
	if low_furniture_top then
		return false
	end

	local face_dot = self:_pd3ms_obstacle_face_dot(forward, obstacle_ray)
	if not face_dot then
		return false
	end

	-- A normal mantle approaches a face that pushes back against the player's movement.
	-- The corner bug from the clip is a shallow along-wall/corner scrape: the ray hits a
	-- vertical side face whose normal is nearly perpendicular to movement, then the top
	-- scan finds a valid surface and starts a mantle anyway.
	if face_dot <= -0.18 then
		return false
	end

	local hit_forward = obstacle_dist or self:_pd3ms_forward_progress_from(pos, obstacle_ray.position, forward)
	local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
	local hit_lateral = math.abs(self:_pd3ms_target_lateral_from(pos, forward, obstacle_ray.position) or 0)
	local target_lateral = math.abs(self:_pd3ms_target_lateral_from(pos, forward, target_pos) or 0)
	local forward_gap = math.abs((target_forward or 0) - (hit_forward or 0))
	local dz = top_dz or (target_pos.z - pos.z)
	local support = top_support or 0

	-- Be strict only for side/glancing contacts. The extra shape checks avoid rejecting
	-- ordinary broad, front-facing mantles while still catching wall-corner seams where
	-- the obstacle face is basically beside the player.
	local seam_like = wall_cap_top or hit_lateral >= 5 or target_lateral >= 10 or forward_gap <= 48 or support <= 3 or dz >= 54
	if seam_like then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("reject: glancing corner mantle face_dot=" .. tostring(string.format("%.2f", face_dot)) .. " hit_lat=" .. tostring(math.floor(hit_lateral or 0)) .. " target_lat=" .. tostring(math.floor(target_lateral or 0)) .. " gap=" .. tostring(math.floor(forward_gap or 0)) .. " dz=" .. tostring(math.floor(dz or 0)) .. " support=" .. tostring(support or 0) .. " wall_cap=" .. tostring(wall_cap_top))
		end
		return true
	end

	return false
end


function PlayerStandard:_pd3ms_is_side_wall_seam_mantle_target(pos, forward, target_pos, top_dz, top_support, skinny_top, wall_cap_top, low_furniture_top, obstacle_ray)
	if not pos or not forward or not target_pos then
		return false
	end

	-- Bench/chair rescue is intentionally allowed near side blockers/backrests.
	if low_furniture_top then
		return false
	end

	-- v1.4.25 was too broad here: high ledges, lateral ledges, and ordinary low-support
	-- tops near a wall were getting rejected even when they were not the corner-seam bug.
	-- Keep this guard only on the family that actually fixed the clip: skinny rail / wall-cap
	-- style candidates that have a tall wall immediately on one side of the accepted top.
	if not skinny_top and not wall_cap_top then
		return false
	end

	local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
	if not target_forward then
		return false
	end

	local dz = top_dz or (target_pos.z - pos.z)
	local support = top_support or 0
	local target_side = self:_pd3ms_target_lateral_from(pos, forward, target_pos) or 0
	local target_lateral = math.abs(target_side)
	local face_dot = obstacle_ray and self:_pd3ms_obstacle_face_dot(forward, obstacle_ray) or nil
	local glancing_face = face_dot and face_dot > -0.22

	-- Frontal skinny-rail mantles can legitimately be next to a side wall. Only run the
	-- expensive side-wall seam scan when the candidate still looks seam-prone: a wall-cap,
	-- a glancing/side-face contact, a notably off-center top, very thin support, or a tall cap.
	if not wall_cap_top and not glancing_face and target_lateral < 14 and support >= 2 and (dz or 0) < 72 then
		return false
	end

	local left_wall = 0
	local right_wall = 0
	local left_close = 0
	local right_close = 0
	local left_dist = 999
	local right_dist = 999
	local low_height = math.clamp((dz or 64) + 24, 62, 164)
	local high_height = math.clamp((dz or 64) + 54, 90, 198)
	local pos_x = pos.x
	local pos_y = pos.y
	local pos_z = pos.z
	local fwd_x = forward.x
	local fwd_y = forward.y

	for side_index, side_sign in ipairs(PD3MS_SIDE_SIGN_OFFSETS) do
		for _, forward_offset in ipairs(PD3MS_SIDE_WALL_FORWARD_OFFSETS) do
			for height_index = 1, 2 do
				local height = height_index == 1 and low_height or high_height
				local scan_forward = target_forward + forward_offset
				local from_side = side_sign * 6
				local to_side = side_sign * 40
				local ray_z = pos_z + height
				local ray = self:_pd3ms_world_ray_xyz(
					pos_x + (fwd_x * scan_forward) + (fwd_y * from_side),
					pos_y + (fwd_y * scan_forward) - (fwd_x * from_side),
					ray_z,
					pos_x + (fwd_x * scan_forward) + (fwd_y * to_side),
					pos_y + (fwd_y * scan_forward) - (fwd_x * to_side),
					ray_z,
					true
				)
				if ray and ray.position then
					local normal_z = math.abs(ray.normal and ray.normal.z or 0)
					if normal_z <= 0.58 then
						local hit_side = math.abs((self:_pd3ms_target_lateral_from(pos, forward, ray.position) or 0) - target_side)
						if side_index == 1 then
							left_wall = left_wall + 1
							if hit_side < left_dist then
								left_dist = hit_side
							end
							if hit_side <= 22 then
								left_close = left_close + 1
							end
						else
							right_wall = right_wall + 1
							if hit_side < right_dist then
								right_dist = hit_side
							end
							if hit_side <= 22 then
								right_close = right_close + 1
							end
						end
					end
				end
			end
		end
	end

	-- Require strong one-sided evidence. This preserves the successful corner fix while
	-- avoiding v1.4.25's overreach on normal rails/ledges that merely have some wall geometry
	-- nearby or are pinched between objects.
	local left_strong_wall = left_close >= 4 and left_dist <= 22
	local right_strong_wall = right_close >= 4 and right_dist <= 22
	local one_sided_wall = (left_strong_wall and right_close <= 1) or (right_strong_wall and left_close <= 1)
	if one_sided_wall then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("reject: side wall seam mantle skinny=" .. tostring(skinny_top) .. " wall_cap=" .. tostring(wall_cap_top) .. " support=" .. tostring(support or 0) .. " dz=" .. tostring(math.floor(dz or 0)) .. " lateral=" .. tostring(math.floor(target_lateral or 0)) .. " face_dot=" .. tostring(face_dot and string.format("%.2f", face_dot) or "nil") .. " left=" .. tostring(left_close) .. "/" .. tostring(left_wall) .. " right=" .. tostring(right_close) .. "/" .. tostring(right_wall) .. " dist_l=" .. tostring(math.floor(left_dist or -1)) .. " dist_r=" .. tostring(math.floor(right_dist or -1)))
		end
		return true
	end

	return false
end


function PlayerStandard:_pd3ms_is_skinny_wall_edge_mantle_target(pos, forward, obstacle_ray, obstacle_dist, target_pos, top_dz, top_support, low_furniture_top)
	-- Narrow guard for the remaining wall/corner edge case after the broad corner guards
	-- were rolled back. Only apply this to high skinny-top fallback mantles; normal tops,
	-- wall caps, low furniture, and rear chair/backrest rescues stay out of this path.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position or not target_pos then
		return false
	end
	if low_furniture_top then
		return false
	end

	local dz = top_dz or (target_pos.z - pos.z)
	local support = top_support or 0
	if dz < 70 or support < 3 then
		return false
	end

	local obstacle_dz = obstacle_ray.position.z - pos.z
	if obstacle_dz < (dz - 22) or obstacle_dz > (dz + 14) then
		return false
	end

	local same, left, right, center, split_normals, total = self:_pd3ms_front_face_coherence(pos, forward, obstacle_ray, obstacle_dist, dz)
	local compact_edge_hit = (obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position) or 999) <= 54
	local face_dot = self:_pd3ms_obstacle_face_dot(forward, obstacle_ray)

	-- v1.4.42: Direct reject for the object-corner shape that v1.4.41 still missed.
	-- This helper is only called for skinny fallback candidates after normal-top,
	-- near-wall-cap, rounded, and furniture rescue have failed. If the sampled top is
	-- high/close/supported and the first obstacle hit is at nearly the same height,
	-- it is the wall/object corner seam from the logs, not a valid broad mantle.
	local obstacle_to_top_gap = math.abs((obstacle_dz or dz) - (dz or obstacle_dz or 0))
	if compact_edge_hit and dz >= 78 and support >= 3 and obstacle_to_top_gap <= 18 then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("reject: skinny object-corner mantle direct dz=" .. tostring(math.floor(dz or 0)) .. " support=" .. tostring(support or 0) .. " dist=" .. tostring(math.floor(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position) or 0)) .. " gap=" .. tostring(math.floor(obstacle_to_top_gap or 0)) .. " face_dot=" .. tostring(face_dot and string.format("%.2f", face_dot) or "nil"))
		end
		return true
	end

	-- The remaining object-corner bug logs as a high, very close skinny fallback with
	-- *no* usable broad top/cap and no coherent vertical face samples at all. True rails
	-- usually either have a lower profile, less support, or some face evidence from both
	-- lanes. Reject this no-face shape here instead of re-enabling the old broad corner
	-- guards that broke normal mantles.
	if total <= 0 then
		if compact_edge_hit and dz >= 78 and support >= 3 then
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("reject: skinny wall edge mantle no-face dz=" .. tostring(math.floor(dz or 0)) .. " support=" .. tostring(support or 0) .. " dist=" .. tostring(math.floor(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position) or 0)) .. " face_dot=" .. tostring(face_dot and string.format("%.2f", face_dot) or "nil"))
			end
			return true
		end
		return false
	end

	local one_sided = left == 0 or right == 0
	if not one_sided then
		return false
	end

	-- Good rails/fences usually have either usable face evidence on both side lanes or a
	-- lower/thinner profile. The bad wall-edge case logs as a high skinny fallback with
	-- only center/one-sided face hits, so require that specific shape before rejecting.
	local glancing_or_edge_face = not face_dot or face_dot > -0.22
	local weak_side_evidence = same <= 2 or center >= same or (left + right) <= 1

	if compact_edge_hit and weak_side_evidence and (glancing_or_edge_face or split_normals >= 1 or support >= 5) then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("reject: skinny wall edge mantle same=" .. tostring(same) .. " left=" .. tostring(left) .. " right=" .. tostring(right) .. " split=" .. tostring(split_normals) .. " total=" .. tostring(total) .. " dz=" .. tostring(math.floor(dz or 0)) .. " support=" .. tostring(support or 0) .. " face_dot=" .. tostring(face_dot and string.format("%.2f", face_dot) or "nil"))
		end
		return true
	end

	return false
end

function PlayerStandard:_pd3ms_clearance_lane_blocked(pos, forward, side, clearance_height)
	local side_offset = side or 0
	local sample_x = pos.x + (forward.y * side_offset)
	local sample_y = pos.y - (forward.x * side_offset)
	local sample_z = pos.z
	local ray = self:_pd3ms_world_ray_xyz(sample_x, sample_y, sample_z + 34, sample_x, sample_y, sample_z + (clearance_height or PD3MS_CROUCH_MANTLE_CLEARANCE), true)
	if not ray then
		return false
	end

	-- A nearby vertical wall face can intersect a straight-up clearance ray when
	-- the target is tight to counters/benches. Only horizontal-ish undersides
	-- should force a crouch mantle.
	if ray.normal and ray.normal.z then
		return ray.normal.z < -0.18
	end

	return false
end

function PlayerStandard:_pd3ms_has_clearance_at(pos, forward, clearance_height, loose)
	local samples = loose and PD3MS_CLEARANCE_LOOSE_SIDE_OFFSETS or PD3MS_CLEARANCE_STRICT_SIDE_OFFSETS
	local clear_lanes = 0
	local center_clear = false

	for _, side in ipairs(samples) do
		if not self:_pd3ms_clearance_lane_blocked(pos, forward, side, clearance_height or 126) then
			clear_lanes = clear_lanes + 1
			if side == 0 then
				center_clear = true
			end
		end
	end

	if loose then
		return center_clear and clear_lanes >= 2
	end

	return clear_lanes == #samples
end

function PlayerStandard:_pd3ms_has_clearance_lane_at(pos, forward, side, clearance_height)
	return not self:_pd3ms_clearance_lane_blocked(pos, forward, side, clearance_height or PD3MS_CROUCH_MANTLE_CLEARANCE)
end

function PlayerStandard:_pd3ms_has_crouch_clearance_at(pos, forward)
	if self:_pd3ms_has_clearance_lane_at(pos, forward, 0, PD3MS_CROUCH_MANTLE_CLEARANCE) then
		return true
	end

	local clear_lanes = 0
	for _, side in ipairs(PD3MS_CROUCH_CLEARANCE_SIDE_OFFSETS) do
		if self:_pd3ms_has_clearance_lane_at(pos, forward, side, PD3MS_CROUCH_MANTLE_CLEARANCE) then
			clear_lanes = clear_lanes + 1
		end
	end

	return clear_lanes >= 2
end

function PlayerStandard:_pd3ms_has_low_overhead_at(pos, forward, standing_height)
	if not pos or not forward then
		return false
	end

	local hits = 0
	local center_hit = false
	local from_height = PD3MS_CROUCH_MANTLE_CLEARANCE + 4
	local to_height = math.max(standing_height or PD3MS_STANDING_MANTLE_CLEARANCE, PD3MS_STANDING_MANTLE_CLEARANCE)
	local pos_x = pos.x
	local pos_y = pos.y
	local pos_z = pos.z
	local right_x = forward.y
	local right_y = -forward.x

	for _, side in ipairs(PD3MS_LOW_OVERHEAD_SIDE_OFFSETS) do
		local sample_x = pos_x + (right_x * side)
		local sample_y = pos_y + (right_y * side)
		local ray = self:_pd3ms_world_ray_xyz(sample_x, sample_y, pos_z + from_height, sample_x, sample_y, pos_z + to_height, true)

		if ray and ray.normal and ray.normal.z and ray.normal.z < -0.18 then
			hits = hits + 1
			if side == 0 then
				center_hit = true
			end
		end
	end

	return center_hit or hits >= 2
end

function PlayerStandard:_pd3ms_landing_clearance(pos, forward, standing_height, loose)
	local full_standing_height = math.max(standing_height or 0, PD3MS_STANDING_MANTLE_CLEARANCE)
	if self:_pd3ms_has_clearance_at(pos, forward, full_standing_height, loose) then
		return true, false
	end

	if self:_pd3ms_has_crouch_clearance_at(pos, forward) then
		return true, self:_pd3ms_has_low_overhead_at(pos, forward, full_standing_height)
	end

	return false, false
end

function PlayerStandard:_pd3ms_corridor_crouch_mantle_needed(pos, forward, target_pos, obstacle_dist, target_forward)
	if not pos or not forward or not target_pos then
		return false
	end

	local target_z_offset = (target_pos.z or pos.z) - (pos.z or 0)
	local start_forward = math.max(4, (obstacle_dist or 42) - 14)
	local lip_forward = math.max(start_forward + 6, (obstacle_dist or 42) + 4)
	local end_forward = math.max(lip_forward + 18, (target_forward or lip_forward) + 34)
	end_forward = math.min(end_forward, 176)
	local sample_span = end_forward - lip_forward

	for _, factor in ipairs(PD3MS_CORRIDOR_SAMPLE_FACTORS) do
		local dist = factor < 0 and start_forward or (factor == 0 and lip_forward or (factor >= 1 and end_forward or lip_forward + (sample_span * factor)))
		local standing_blocked_lanes = 0
		local center_standing_blocked = false
		for _, side in ipairs(PD3MS_BACKSTOP_SIDE_OFFSETS) do
			local sample = self:_pd3ms_offset_from(pos, forward, dist, side, target_z_offset)
			if not self:_pd3ms_has_clearance_lane_at(sample, forward, 0, PD3MS_STANDING_MANTLE_CLEARANCE) then
				standing_blocked_lanes = standing_blocked_lanes + 1
				if side == 0 then
					center_standing_blocked = true
				end
			end
		end

		if center_standing_blocked or standing_blocked_lanes >= 3 then
			local center_sample = self:_pd3ms_offset_from(pos, forward, dist, 0, target_z_offset)
			if self:_pd3ms_has_clearance_lane_at(center_sample, forward, 0, PD3MS_CROUCH_MANTLE_CLEARANCE) then
				if self:_pd3ms_has_low_overhead_at(center_sample, forward, PD3MS_STANDING_MANTLE_CLEARANCE) then
					return true
				end
			end

			local clear_near_center = 0
			for _, side in ipairs(PD3MS_CORRIDOR_NEAR_CENTER_SIDE_OFFSETS) do
				local sample = self:_pd3ms_offset_from(pos, forward, dist, side, target_z_offset)
				if self:_pd3ms_has_clearance_lane_at(sample, forward, 0, PD3MS_CROUCH_MANTLE_CLEARANCE) then
					clear_near_center = clear_near_center + 1
				end
			end

			if clear_near_center >= 2 then
				if self:_pd3ms_has_low_overhead_at(center_sample, forward, PD3MS_STANDING_MANTLE_CLEARANCE) then
					return true
				end
			end
		end
	end

	return false
end

function PlayerStandard:_pd3ms_has_skinny_clearance_at(pos, forward, clearance_height)
	-- Thin rails often have posts/extra bars near one side lane. Normal mantle
	-- clearance requires every loose sample to be clear; for skinny fallback targets
	-- require a safe center/near-center lane instead, while the separate head-lane
	-- checks still keep walls from being accepted.
	local clear_lanes = 0
	local pos_x = pos.x
	local pos_y = pos.y
	local pos_z = pos.z
	local right_x = forward.y
	local right_y = -forward.x
	local to_height = clearance_height or 92

	for _, side in ipairs(PD3MS_SKINNY_CLEARANCE_SIDE_OFFSETS) do
		local sample_x = pos_x + (right_x * side)
		local sample_y = pos_y + (right_y * side)
		if not self:_pd3ms_world_ray_xyz(sample_x, sample_y, pos_z + 34, sample_x, sample_y, pos_z + to_height, true) then
			clear_lanes = clear_lanes + 1
		end
	end

	return clear_lanes >= 1, clear_lanes
end

function PlayerStandard:_pd3ms_top_surface_support(pos, forward)
	-- Reject tiny trim/curbs by requiring some real surface area near the candidate top.
	-- We only need two hits because sandbags and props often have uneven collision.
	local hits = 0
	local base_z = pos.z

	for _, data in ipairs(PD3MS_TOP_SUPPORT_CHECKS) do
		local ray = self:_pd3ms_down_ray_offset_from(pos, forward, data[1], data[2], 0, 70, -42, true)
		if ray and ray.position then
			local dz = math.abs(ray.position.z - base_z)
			local normal_ok = true
			if ray.normal and ray.normal.z then
				normal_ok = ray.normal.z > 0.50
			end
			if normal_ok and dz <= 18 then
				hits = hits + 1
			end
		end
	end

	return hits >= 2, hits
end

function PlayerStandard:_pd3ms_find_raised_top_landing(pos, forward, player_z, max_top_dz)
	-- Car sides/window frames can report a valid lower edge before the roof/hood surface.
	-- Only adjust when the same object rises slightly deeper ahead; flat props stay untouched.
	local base_surface_z = pos.z - 6
	local best = nil
	local best_dz = nil
	local best_score = nil

	for _, data in ipairs(PD3MS_RAISED_TOP_CHECKS) do
		local ray = self:_pd3ms_down_ray_offset_from(pos, forward, data[1], data[2], 0, 88, -42, true)
		if ray and ray.position then
			local rise = ray.position.z - base_surface_z
			local dz = ray.position.z - player_z
			local normal_ok = true
			if ray.normal and ray.normal.z then
				normal_ok = ray.normal.z > 0.46
			end
			if normal_ok and rise >= 7 and rise <= 26 and dz >= 24 and dz <= max_top_dz then
				local target_pos = mvector3.copy(ray.position)
				mvector3.add(target_pos, Vector3(0, 0, 6))
				local score = data[1] + math.abs(data[2]) * 0.75 + rise * 0.35
				if not best_score or score < best_score then
					best = target_pos
					best_dz = dz
					best_score = score
				end
			end
		end
	end

	return best, best_dz
end

function PlayerStandard:_pd3ms_low_furniture_backstop_score(pos, forward, dist, dz)
	-- This is the key distinction between the bench/chair fix and normal low walls.
	-- A bench/chair seat usually has a backrest or chair back just beyond the low seat.
	-- A broad ledge/wall cap that should use the original vault behavior is usually open
	-- behind the cap. Requiring this backstop keeps the rescue from stealing wall/ledge vaults.
	if not pos or not forward or not dist or not dz then
		return 0
	end

	local hits = 0
	local start_forward = math.max(4, dist + 6)
	local end_forward = math.min(132, dist + 58)
	local low_height = math.clamp(dz + 22, 34, 88)
	local high_height = math.clamp(dz + 48, 58, 118)

	for _, side in ipairs(PD3MS_BACKSTOP_SIDE_OFFSETS) do
		if self:_pd3ms_horizontal_ray(pos, forward, start_forward, end_forward, side, low_height, true) then
			hits = hits + 1
		end
		if self:_pd3ms_horizontal_ray(pos, forward, start_forward, end_forward, side, high_height, true) then
			hits = hits + 1
		end
	end

	return hits
end

function PlayerStandard:_pd3ms_low_furniture_nearside_backrest_score(pos, forward, dist, dz, obstacle_dist, hit_dz)
	-- Rear bench/chair approaches hit the backrest first, then the usable low seat is
	-- just beyond it. The original backstop proof only looked beyond the seat, so it
	-- worked from the front but often failed from behind the backrest.
	if not pos or not forward or not dist or not dz then
		return 0
	end

	-- The candidate needs to be meaningfully past the front/backrest hit. Otherwise this
	-- is just the normal front-facing furniture path, which is handled by backstop_score.
	if obstacle_dist and dist <= (obstacle_dist + 3) then
		return 0
	end

	-- A rear backrest should be taller than the seat, but not the height of a normal wall.
	-- Keep this loose enough for different bench/chair collision while excluding scenery walls.
	if hit_dz and hit_dz > 0 then
		if hit_dz < (dz + 8) or hit_dz > (dz + 92) then
			return 0
		end
	end

	local scan_end = math.max(8, dist - 4)
	local low_height = math.clamp(dz + 24, 34, 94)
	local high_height = math.clamp(dz + 48, 58, 126)
	local hits = 0

	for _, side in ipairs(PD3MS_BACKSTOP_SIDE_OFFSETS) do
		local low_ray = self:_pd3ms_horizontal_ray(pos, forward, 0, scan_end, side, low_height, true)
		if low_ray and low_ray.position then
			local fp = self:_pd3ms_forward_progress_from(pos, low_ray.position, forward)
			if fp >= 2 and fp <= (dist - 3) then
				hits = hits + 1
			end
		end

		local high_ray = self:_pd3ms_horizontal_ray(pos, forward, 0, scan_end, side, high_height, true)
		if high_ray and high_ray.position then
			local fp = self:_pd3ms_forward_progress_from(pos, high_ray.position, forward)
			if fp >= 2 and fp <= (dist - 3) then
				hits = hits + 1
			end
		end
	end

	return hits
end


function PlayerStandard:_pd3ms_find_low_furniture_top_from_skinny_candidate(pos, forward, skinny_target, skinny_dz, skinny_dist, skinny_support)
	-- Rear bench/chair attempts can miss the normal horizontal obstacle ray and then
	-- fall into the skinny-top fallback by sampling the top of the backrest. In that
	-- case the real landing is usually the lower supported seat/top just beyond the
	-- skinny backrest. Re-run the low-furniture proof using the skinny candidate as
	-- a synthetic front hit, but keep it narrow so true rails/fences stay on the
	-- skinny path.
	if not pos or not forward or not skinny_target or not skinny_dz or not skinny_dist then
		return nil, nil, nil, nil, nil, nil
	end

	if skinny_dz < 38 or skinny_dz > (PD3MS_MAX_LOW_FURNITURE_DZ + 8) then
		return nil, nil, nil, nil, nil, nil
	end

	if (skinny_support or 0) > 2 then
		return nil, nil, nil, nil, nil, nil
	end

	if skinny_dist < 14 or skinny_dist > 78 then
		return nil, nil, nil, nil, nil, nil
	end

	local synthetic_hit_pos = mvector3.copy(skinny_target)
	mvector3.set_z(synthetic_hit_pos, pos.z + skinny_dz)

	local synthetic_ray = {
		position = synthetic_hit_pos
	}

	local furniture_target, furniture_dz, furniture_support, furniture_dist, furniture_backstop, furniture_crouch_mantle = self:_pd3ms_find_low_furniture_top_target(pos, forward, synthetic_ray, skinny_dist)
	self:_pd3ms_debug_target_info("skinny-furniture", furniture_target, pos, forward, furniture_dz, furniture_support, furniture_dist or skinny_dist)

	if not furniture_target then
		return nil, nil, nil, nil, nil, nil
	end

	-- From behind a bench/chair backrest the lower seat is detected here, but
	-- trying to redirect onto that low seat still leaves the controller fighting
	-- the taller rear backrest collision. Use the seat proof only to confirm that
	-- this skinny hit is really furniture, then mantle onto the back/headrest top
	-- itself. That is simpler and much more reliable from the rear.
	local seat_is_beyond_backrest = (furniture_dist or 0) >= (skinny_dist - 2)
	local clear_low_seat = (skinny_dz - (furniture_dz or skinny_dz)) >= 6
	local strong_furniture_proof = (furniture_backstop or 0) >= 3

	if seat_is_beyond_backrest and clear_low_seat and strong_furniture_proof then
		local backrest_support = math.max(1, skinny_support or 1, math.min(furniture_support or 1, 2))
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("skinny-furniture backrest-top used: backrest_dz=" .. tostring(math.floor(skinny_dz or 0)) .. " backrest_dist=" .. tostring(math.floor(skinny_dist or 0)) .. " seat_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " seat_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
		end
		return skinny_target, skinny_dz, backrest_support, skinny_dist, furniture_backstop, false, true, skinny_dz, skinny_dist, true
	end

	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log("skinny-furniture rescue ignored: skinny_dz=" .. tostring(math.floor(skinny_dz or 0)) .. " skinny_dist=" .. tostring(math.floor(skinny_dist or 0)) .. " seat_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " seat_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
	end
	return nil, nil, nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_find_low_furniture_top_target(pos, forward, obstacle_ray, obstacle_dist)
	-- Narrow rescue for benches/chairs: find a close, supported low horizontal seat/top
	-- only when it also has a backrest/chair-back style obstruction behind it. This avoids
	-- reclassifying normal wall caps, planters, and ledges that the original build vaulted over.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position then
		return nil, nil, nil, nil, nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 4, 94)
	local hit_dz = obstacle_ray.position.z - pos.z
	-- Rear bench/chair approaches can hit the taller backrest first, then find the
	-- usable low seat just beyond it. Allow a taller first hit here, but the helper
	-- below still has to prove the target is bench/chair-like before it wins.
	if hit_dz > (PD3MS_MAX_LOW_FURNITURE_DZ + 46) then
		return nil, nil, nil, nil, nil
	end

	local best = nil
	local best_dz = nil
	local best_support = 0
	local best_dist = nil
	local best_backstop = 0
	local best_score = nil
	local best_crouch_mantle = false
	local scan_hits = 0
	local height_hits = 0
	local support_rejects = 0
	local clearance_rejects = 0
	local proof_rejects = 0
	local front_blocked_hits = 0
	local best_proof_seen = 0
	local best_near_seen = 0
	local best_back_seen = 0
	local best_seen_dist = nil
	local best_seen_dz = nil
	local best_seen_support = 0

	for scan_pass = 1, 2 do
		local scan_distances = scan_pass == 1 and PD3MS_LOW_FURNITURE_BASE_DISTANCES or PD3MS_LOW_FURNITURE_HIT_DIST_OFFSETS
		for _, raw_dist in ipairs(scan_distances) do
			local dist = math.clamp(scan_pass == 1 and raw_dist or hit_dist + raw_dist, 6, 118)
			for _, side in ipairs(PD3MS_LOW_FURNITURE_SIDE_OFFSETS) do
				local top_ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 142, -22, true)
			if top_ray and top_ray.position then
				scan_hits = scan_hits + 1
				local dz = top_ray.position.z - pos.z
				local normal_ok = true
				if top_ray.normal and top_ray.normal.z then
					normal_ok = top_ray.normal.z > 0.44
				end

				if normal_ok and dz >= math.max(PD3MS_MIN_LOW_FURNITURE_DZ, PD3MS_MIN_LOW_FURNITURE_SEAT_DZ) and dz <= PD3MS_MAX_LOW_FURNITURE_DZ then
					height_hits = height_hits + 1
					local target_pos = mvector3.copy(top_ray.position)
					mvector3.add(target_pos, Vector3(0, 0, 6))

					local support_ok, support_hits = self:_pd3ms_top_surface_support(target_pos, forward)
					local clearance_ok, crouch_mantle = self:_pd3ms_landing_clearance(target_pos, forward, 96, true)
					if support_ok and clearance_ok then
						local front_check_height = math.clamp(dz * 0.55, 12, 38)
						local front_blocked = self:_pd3ms_horizontal_ray(pos, forward, 0, math.max(8, dist - 2), side * 0.35, front_check_height, true) ~= nil
						front_blocked = front_blocked or (hit_dz >= 10 and hit_dz <= (dz + 18) and dist >= math.max(8, hit_dist - 34) and dist <= (hit_dist + 64))

						local nearside_backrest_hits = self:_pd3ms_low_furniture_nearside_backrest_score(pos, forward, dist, dz, hit_dist, hit_dz)
						if front_blocked then
							front_blocked_hits = front_blocked_hits + 1
						end
						local backstop_hits = self:_pd3ms_low_furniture_backstop_score(pos, forward, dist, dz)
						local furniture_proof_hits = math.max(backstop_hits, nearside_backrest_hits)
						if furniture_proof_hits > best_proof_seen then
							best_proof_seen = furniture_proof_hits
							best_near_seen = nearside_backrest_hits
							best_back_seen = backstop_hits
							best_seen_dist = dist
							best_seen_dz = dz
							best_seen_support = support_hits or 0
						end
						if front_blocked or nearside_backrest_hits >= 3 then
							-- Front approach needs the old beyond-seat backrest proof. Rear approach can instead
							-- prove the backrest between the player and the candidate seat.
							if backstop_hits >= 2 or nearside_backrest_hits >= 3 then
								local score = dist * 0.45 + math.abs(side) * 1.20 - (support_hits or 0) * 4.0 - furniture_proof_hits * 2.6 + math.abs(dz - 38) * 0.16
								if not best_score or score < best_score then
									best = target_pos
									best_dz = dz
									best_support = support_hits or 0
									best_dist = dist
									best_backstop = furniture_proof_hits
									best_crouch_mantle = crouch_mantle
									best_score = score
								end
							else
								proof_rejects = proof_rejects + 1
							end
						else
							proof_rejects = proof_rejects + 1
						end
					else
						if not support_ok then
							support_rejects = support_rejects + 1
						end
						if support_ok and not clearance_ok then
							clearance_rejects = clearance_rejects + 1
						end
					end
				end
			end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("low-furniture top candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0) .. " proof=" .. tostring(best_backstop or 0))
		end
		return best, best_dz, best_support, best_dist, best_backstop, best_crouch_mantle
	end

	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log("low-furniture nil summary: obstacle_dist=" .. tostring(math.floor(hit_dist or 0)) .. " hit_dz=" .. tostring(math.floor(hit_dz or 0)) .. " scan=" .. tostring(scan_hits or 0) .. " height=" .. tostring(height_hits or 0) .. " support_rej=" .. tostring(support_rejects or 0) .. " clear_rej=" .. tostring(clearance_rejects or 0) .. " proof_rej=" .. tostring(proof_rejects or 0) .. " front=" .. tostring(front_blocked_hits or 0) .. " best_proof=" .. tostring(best_proof_seen or 0) .. " near=" .. tostring(best_near_seen or 0) .. " back=" .. tostring(best_back_seen or 0) .. " best_dist=" .. tostring(best_seen_dist and math.floor(best_seen_dist) or "nil") .. " best_dz=" .. tostring(best_seen_dz and math.floor(best_seen_dz) or "nil") .. " best_sup=" .. tostring(best_seen_support or 0))
	end
	return nil, nil, nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_is_shelf_like_landing(pos, forward, support_hits)
	if not pos or not forward then
		return false
	end

	if not support_hits then
		local _, hits = self:_pd3ms_top_surface_support(pos, forward)
		support_hits = hits or 0
	end

	if support_hits > 3 then
		return false
	end

	local blocked_lanes = 0
	for _, side in ipairs(PD3MS_SHELF_BLOCK_SIDE_OFFSETS) do
		local low_blocked = self:_pd3ms_horizontal_ray(pos, forward, -2, 44, side, 24, true) ~= nil
		local high_blocked = self:_pd3ms_horizontal_ray(pos, forward, -2, 44, side, 62, true) ~= nil
		if low_blocked and high_blocked then
			blocked_lanes = blocked_lanes + 1
		end
	end

	return blocked_lanes >= 2
end

function PlayerStandard:_pd3ms_landing_depth_hits(pos, forward, loose)
	if not pos or not forward then
		return 0
	end

	local base_z = pos.z
	local hits = 0
	local forward_offsets = loose and PD3MS_LANDING_DEPTH_LOOSE_FORWARD_OFFSETS or PD3MS_LANDING_DEPTH_FORWARD_OFFSETS
	local side_offsets = loose and PD3MS_LANDING_DEPTH_LOOSE_SIDE_OFFSETS or PD3MS_LANDING_DEPTH_SIDE_OFFSETS
	local normal_min = loose and 0.26 or 0.48
	local z_tolerance = loose and 32 or 16

	for _, forward_offset in ipairs(forward_offsets) do
		for _, side in ipairs(side_offsets) do
			local ray = self:_pd3ms_down_ray_offset_from(pos, forward, forward_offset, side, 0, loose and 118 or 82, loose and -58 or -42, true)
			if ray and ray.position then
				local normal_ok = true
				if ray.normal and ray.normal.z then
					normal_ok = ray.normal.z > normal_min
				end

				if normal_ok and math.abs(ray.position.z - base_z) <= z_tolerance then
					hits = hits + 1
				end
			end
		end
	end

	return hits
end

function PlayerStandard:_pd3ms_is_wall_backed_tiny_lip(pos, forward, top_dz, support_hits)
	-- Test build: completely bypass tiny lip rejection.
	if PD3MS_DISABLE_TINY_LIP_REJECT then
		return false, 0, 0
	end

	-- Decorative window trim and tiny shelf lips can produce a valid down-ray even
	-- though there is not enough real landing depth to justify starting a mantle.
	-- Keep this narrow: broad ledges/wall caps have depth, benches are handled by the
	-- furniture path, and skinny rail targets only use this wall-backed portion.
	if not pos or not forward or not top_dz or top_dz > PD3MS_MAX_TINY_WALL_LIP_DZ then
		return false, 0, 0
	end

	local depth_hits = self:_pd3ms_landing_depth_hits(pos, forward)
	if depth_hits >= 3 then
		return false, depth_hits, 0
	end

	local blocked_lanes = 0
	for _, side in ipairs(PD3MS_TINY_LIP_BLOCK_SIDE_OFFSETS) do
		local low_blocked = self:_pd3ms_horizontal_ray(pos, forward, -4, 42, side, 24, true) ~= nil
		local high_blocked = self:_pd3ms_horizontal_ray(pos, forward, -4, 42, side, 58, true) ~= nil
		if low_blocked and high_blocked then
			blocked_lanes = blocked_lanes + 1
		end
	end

	return blocked_lanes >= 2, depth_hits, blocked_lanes
end

function PlayerStandard:_pd3ms_is_too_small_step_lip(pos, forward, top_dz, support_hits, player_pos, obstacle_ray)
	-- Test build: completely bypass tiny lip / step-over rejection.
	if PD3MS_DISABLE_TINY_LIP_REJECT then
		return false, "tiny-lip-disabled", 0, 0
	end

	-- v1.4.15: make tiny-lip rejection a narrow late filter instead of a broad
	-- early height cutoff. Cars/dumpsters often present a low bumper/front face
	-- before the real hood/lid surface, so height alone must not reject a mantle.
	-- Only reject targets that are both low and shallow/narrow, with no real depth
	-- behind the selected landing.
	if not top_dz then
		return false, nil, 0, 0
	end

	local support = support_hits or 0
	local tight_depth_hits = self:_pd3ms_landing_depth_hits(pos, forward, false)
	local loose_depth_hits = self:_pd3ms_landing_depth_hits(pos, forward, true)

	-- Broad/rounded prop tops: accept before applying trim logic. A hood/lid may be
	-- sloped or slightly uneven, so the loose depth scan is intentionally tolerant.
	if support >= 2 and (tight_depth_hits >= 2 or loose_depth_hits >= 4) then
		return false, "real-landing-depth", loose_depth_hits, 0
	end

	-- Extremely low, shallow targets are step-over trim/curbs. This replaces the old
	-- unconditional 42-unit cutoff, which was blocking useful low broad props.
	if top_dz < 30 and support <= 2 and loose_depth_hits <= 2 then
		return true, "very-low-shallow-lip", loose_depth_hits, 0
	end

	if player_pos and obstacle_ray and obstacle_ray.position and top_dz <= PD3MS_MAX_STEP_OVER_TRIM_DZ then
		local obstacle_dz = obstacle_ray.position.z - player_pos.z
		local obstacle_dist = self:_pd3ms_flat_distance_from(player_pos, obstacle_ray.position)
		-- Low front-face trim should only be rejected when the selected landing remains
		-- shallow. If there is actual top depth behind it, let the normal mantle path win.
		if obstacle_dz <= PD3MS_MAX_STEP_OVER_FACE_DZ and obstacle_dist <= 62 then
			if support <= 2 and loose_depth_hits <= 3 then
				return true, "low-face-shallow-trim", loose_depth_hits, 0
			end
			return false, "low-face-with-depth", loose_depth_hits, 0
		end
	end

	local wall_backed, wall_depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(pos, forward, top_dz, support)
	if wall_backed and support <= 3 and loose_depth_hits <= 3 then
		return true, "wall-backed-shallow-lip", math.max(wall_depth_hits or 0, loose_depth_hits or 0), blocked_lanes
	end

	return false, nil, loose_depth_hits or tight_depth_hits or 0, blocked_lanes or 0
end


function PlayerStandard:_pd3ms_stair_riser_face_score(pos, forward, target_forward, top_dz)
	-- A broad rounded prop (car hood, dumpster lid) can look like several rising
	-- down-ray levels from the front, which made the stair reject too aggressive.
	-- Real stairs also have repeated near-vertical riser faces behind the first tread.
	-- Require those riser faces before rejecting a mantle as stair-only movement.
	if not pos or not forward or not target_forward or not top_dz then
		return 0, 0
	end

	local hits = 0
	local center_hits = 0
	for _, height_data in ipairs(PD3MS_STAIR_RISER_HEIGHT_ROWS) do
		local height = math.clamp(top_dz + height_data[1], height_data[2], height_data[3])
		for _, start_offset in ipairs(PD3MS_STAIR_RISER_START_OFFSETS) do
			local start_dist = target_forward + start_offset
			for _, side in ipairs(PD3MS_STAIR_RISER_SIDE_OFFSETS) do
				local ray = self:_pd3ms_horizontal_ray(pos, forward, start_dist, start_dist + 24, side, height, true)
				if ray and ray.position then
					local hit_forward = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
					local normal_z = ray.normal and math.abs(ray.normal.z or 0) or 0
					-- Stairs/riser faces are mostly vertical. Rounded hoods/lids usually report
					-- a much stronger upward component, so do not count those as stair risers.
					if hit_forward >= target_forward + 6 and hit_forward <= target_forward + 170 and normal_z <= 0.42 then
						hits = hits + 1
						if side == 0 then
							center_hits = center_hits + 1
						end
					end
				end
			end
		end
	end

	return hits, center_hits
end

function PlayerStandard:_pd3ms_find_rounded_front_prop_top_target(pos, forward, obstacle_ray, obstacle_dist)
	-- Low front bumpers/grilles can seed the scan too close/low, while the actual
	-- usable surface is the rounded hood/lid just behind them. This is a fallback
	-- only for broad, deep, low-front prop tops; it is not used for stairs because
	-- the stair riser checks below still get the final say.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position then
		return nil, nil, nil, nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 4, 112)
	local hit_dz = obstacle_ray.position.z - pos.z
	if hit_dz > 118 then
		return nil, nil, nil, nil
	end

	local best = nil
	local best_dz = nil
	local best_support = 0
	local best_dist = nil
	local best_score = nil
	local best_crouch_mantle = false

	for _, offset in ipairs(PD3MS_ROUNDED_FRONT_DISTANCE_OFFSETS) do
		local dist = hit_dist + offset
		for _, side in ipairs(PD3MS_ROUNDED_FRONT_SIDE_OFFSETS) do
			local top_ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 270, -70, true)
			if top_ray and top_ray.position then
				local dz = top_ray.position.z - pos.z
				local normal_ok = true
				if top_ray.normal and top_ray.normal.z then
					-- Rounded/sloped hoods can be softer than flat wall caps.
					normal_ok = top_ray.normal.z > 0.20
				end

				if normal_ok and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_TOP_MANTLE_DZ then
					local target_pos = mvector3.copy(top_ray.position)
					mvector3.add(target_pos, Vector3(0, 0, 6))

					local broad_hits = 0
					local broad_rows = 0
					for _, depth in ipairs(PD3MS_ROUNDED_PROP_PROFILE_DEPTHS) do
						local row_hits = 0
						for _, lane in ipairs(PD3MS_ROUNDED_PROP_PROFILE_LANES) do
							local profile_ray = self:_pd3ms_down_ray_offset_from(target_pos, forward, depth, lane, 0, 128, -62, true)
							if profile_ray and profile_ray.position then
								local profile_normal_ok = true
								if profile_ray.normal and profile_ray.normal.z then
									profile_normal_ok = profile_ray.normal.z > 0.16
								end
								local rel_z = profile_ray.position.z - target_pos.z
								if profile_normal_ok and rel_z >= -34 and rel_z <= 48 then
									broad_hits = broad_hits + 1
									row_hits = row_hits + 1
								end
							end
						end
						if row_hits >= 2 then
							broad_rows = broad_rows + 1
						end
					end

					local clearance_ok, crouch_mantle = self:_pd3ms_landing_clearance(target_pos, forward, 104, true)
					if broad_hits >= 7 and broad_rows >= 3 and clearance_ok then
						local score = math.abs(side) * 1.15 + math.abs(offset - 44) * 0.22 - broad_hits * 1.2 - broad_rows * 3.5 + math.max(dz - 104, 0) * 0.35
						if not best_score or score < best_score then
							best = target_pos
							best_dz = dz
							best_support = math.max(3, math.min(5, broad_hits))
							best_dist = dist
							best_crouch_mantle = crouch_mantle
							best_score = score
						end
					end
				end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("rounded-front prop candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0))
		end
		return best, best_dz, best_support, best_dist, best_crouch_mantle
	end

	return nil, nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_is_cluttered_high_landing_target(pos, forward, obstacle_ray, obstacle_dist, target_pos, top_dz, top_support)
	-- Paper stacks/files and other thin clutter on a real desk/counter can create
	-- several small rising collision levels behind the front face. That shape fooled
	-- the stair reject into blocking otherwise valid high tabletop mantles. Keep this
	-- rescue narrow: a close waist-high front panel, a higher top set well behind it,
	-- enough same-height landing depth, and no low-furniture/wall-cap classification.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position or not target_pos or not top_dz then
		return false, 0, 0, 0
	end

	if top_dz < 88 or top_dz > 108 then
		return false, 0, 0, 0
	end

	if (top_support or 0) < 2 then
		return false, 0, 0, 0
	end

	local hit_dz = obstacle_ray.position.z - pos.z
	if hit_dz < 64 or hit_dz > 88 then
		return false, 0, hit_dz, 0
	end

	local hit_dist = obstacle_dist or self:_pd3ms_forward_progress_from(pos, obstacle_ray.position, forward) or 999
	if hit_dist > 54 then
		return false, 0, hit_dz, 0
	end

	local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
	if not target_forward then
		return false, 0, hit_dz, 0
	end

	local forward_gap = target_forward - hit_dist
	if forward_gap < 52 or forward_gap > 86 then
		return false, 0, hit_dz, target_forward
	end

	local height_gap = top_dz - hit_dz
	if height_gap < 10 or height_gap > 34 then
		return false, 0, hit_dz, target_forward
	end

	local loose_depth_hits = self:_pd3ms_landing_depth_hits(target_pos, forward, true)
	if loose_depth_hits < 5 then
		return false, loose_depth_hits, hit_dz, target_forward
	end

	return true, loose_depth_hits, hit_dz, target_forward
end

function PlayerStandard:_pd3ms_is_cluttered_tabletop_false_low_furniture(pos, forward, obstacle_ray, obstacle_dist, top_target, top_dz, top_support, furniture_target, furniture_dz, furniture_support, furniture_dist, furniture_proof)
	-- Some desks/tables with paper stacks, folders, or monitor clutter report two
	-- plausible tops: the real tabletop from the broad top scan, and a lower
	-- "low-furniture" hit from clutter/near-edge collision. If we accept the
	-- lower hit, the stair guard sees several small stacked levels and rejects the
	-- mantle. Keep this rescue narrow and only preserve a supported medium tabletop
	-- when the lower furniture proof is weak/moderate.
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position or not top_target or not furniture_target or not top_dz or not furniture_dz then
		return false, 0, 0, 0, 0
	end

	if top_dz < 70 or top_dz > 96 then
		return false, 0, 0, 0, 0
	end

	if (top_support or 0) < 3 then
		return false, 0, 0, 0, 0
	end

	if furniture_dz < 38 or furniture_dz > 66 then
		return false, 0, 0, 0, 0
	end

	if furniture_dz > (top_dz - 10) then
		return false, 0, 0, 0, 0
	end

	if (furniture_support or 0) > 4 or (furniture_proof or 0) > 5 then
		return false, 0, 0, 0, 0
	end

	local hit_dz = obstacle_ray.position.z - pos.z
	if hit_dz < 48 or hit_dz > 92 then
		return false, 0, hit_dz, 0, 0
	end

	local hit_dist = obstacle_dist or self:_pd3ms_forward_progress_from(pos, obstacle_ray.position, forward) or 999
	if hit_dist > 58 then
		return false, 0, hit_dz, 0, 0
	end

	local top_forward = self:_pd3ms_forward_progress_from(pos, top_target, forward)
	local furniture_forward = furniture_dist or self:_pd3ms_forward_progress_from(pos, furniture_target, forward)
	if not top_forward or not furniture_forward then
		return false, 0, hit_dz, top_forward or 0, furniture_forward or 0
	end

	if top_forward < 66 or top_forward > 116 then
		return false, 0, hit_dz, top_forward, furniture_forward
	end

	local top_gap = top_forward - hit_dist
	if top_gap < 28 or top_gap > 84 then
		return false, 0, hit_dz, top_forward, furniture_forward
	end

	if furniture_forward > (top_forward - 10) or furniture_forward > 70 then
		return false, 0, hit_dz, top_forward, furniture_forward
	end

	local loose_depth_hits = self:_pd3ms_landing_depth_hits(top_target, forward, true)
	if loose_depth_hits < 5 then
		return false, loose_depth_hits, hit_dz, top_forward, furniture_forward
	end

	return true, loose_depth_hits, hit_dz, top_forward, furniture_forward
end

function PlayerStandard:_pd3ms_is_repeating_stair_tread_target(pos, forward, target_pos, top_dz, obstacle_dist, top_support)
	-- Stairs are the one place where a valid-looking ledge is usually not a mantle.
	-- Each riser/tread can look like a small wall cap, and the bench/chair rescue can
	-- also mistake the next riser for a backrest. Detect the stair pattern itself: a
	-- chain of several horizontal landings that keep rising in the same forward lane.
	if not pos or not forward or not target_pos or not top_dz then
		return false, "missing-data", 0, 0
	end

	if top_dz < 24 or top_dz > 132 then
		return false, "target-height-outside-stair-range", 0, 0
	end

	-- Logs from the dumpster/car-front failures showed broad prop tops being
	-- misread as a staircase: high supported target, close front face, then
	-- repeated tiny lid/hood seams counted as risers. Real unwanted stair
	-- mantles in this mod have been low/medium step targets; do not let the
	-- stair reject suppress a high, well-supported prop top.
	if top_dz >= 108 and (top_support or 0) >= 4 then
		return false, "high-broad-supported-top", 0, 0
	end

	local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
	if target_forward < 4 or target_forward > 240 then
		return false, "target-distance-outside-stair-range", 0, 0
	end

	local first_forward = math.max(8, math.min(target_forward, obstacle_dist or target_forward) - 4)
	local levels = {}
	local hits = 0
	local center_hits = 0
	local higher_hits = 0
	local center_higher_hits = 0

	local function add_level(dz)
		for _, level in ipairs(levels) do
			if math.abs(level - dz) <= 10 then
				return
			end
		end
		table.insert(levels, dz)
	end

	for _, extra in ipairs(PD3MS_STAIR_VALIDATE_DISTANCES) do
		for _, side in ipairs(PD3MS_STAIR_VALIDATE_SIDES) do
			local ray = self:_pd3ms_down_ray_offset_from(pos, forward, first_forward + extra, side, 0, 280, -18, true)
			if ray and ray.position then
				local normal_ok = true
				if ray.normal and ray.normal.z then
					normal_ok = ray.normal.z > 0.52
				end

				local dz = ray.position.z - pos.z
				if normal_ok and dz >= math.max(16, top_dz - 14) and dz <= 188 then
					hits = hits + 1
					add_level(dz)
					if side == 0 then
						center_hits = center_hits + 1
					end
					if dz >= top_dz + 11 then
						higher_hits = higher_hits + 1
						if side == 0 then
							center_higher_hits = center_higher_hits + 1
						end
					end
				end
			end
		end
	end

	table.sort(levels)

	local rising_steps = 0
	local last_level = nil
	for _, level in ipairs(levels) do
		if not last_level then
			last_level = level
		elseif level - last_level >= 11 and level - last_level <= 44 then
			rising_steps = rising_steps + 1
			last_level = level
		elseif level - last_level > 44 then
			last_level = level
		end
	end

	-- Benches/chairs generally have a seat plus one backrest/top behind it. A real
	-- staircase has at least two continued rises and several down-ray hits in the
	-- center/near-center lanes. This runs for low-furniture too, which is the case
	-- the previous stair reject missed.
	if rising_steps >= 2 and #levels >= 3 and hits >= 5 and center_hits >= 2 and higher_hits >= 3 and center_higher_hits >= 1 then
		local riser_hits, center_riser_hits = self:_pd3ms_stair_riser_face_score(pos, forward, target_forward, top_dz)
		if riser_hits >= 3 and center_riser_hits >= 1 then
			return true, "repeating-rising-treads", hits, #levels
		end

		-- Treat this as a rounded/ramped prop top rather than a staircase if the
		-- down-rays rise but there are no repeated vertical riser faces. This is
		-- the important difference for front car hoods.
		return false, "rising-surface-without-risers", riser_hits, #levels
	end

	return false, "no-repeating-treads", hits, #levels
end


function PlayerStandard:_pd3ms_stair_approach_riser_score(pos, forward)
	-- Final-stair rejection needs proof that the player is actually standing on
	--/approaching a staircase. Down-rays alone were too broad and also matched
	-- window ledges/curbs with lower ground behind the player. Look for repeated
	-- vertical riser faces behind the player at descending heights.
	if not pos or not forward then
		return 0, 0
	end

	local hits = 0
	local center_hits = 0
	for _, start_dist in ipairs(PD3MS_STAIR_APPROACH_STARTS) do
		for _, height in ipairs(PD3MS_STAIR_APPROACH_HEIGHTS) do
			for _, side in ipairs(PD3MS_STAIR_APPROACH_SIDES) do
				local ray = self:_pd3ms_horizontal_ray(pos, forward, start_dist, start_dist + 26, side, height, true)
				if ray and ray.position then
					local normal_z = ray.normal and math.abs(ray.normal.z or 0) or 0
					local fp = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
					if fp >= -146 and fp <= 10 and normal_z <= 0.44 then
						hits = hits + 1
						if side == 0 then
							center_hits = center_hits + 1
						end
					end
				end
			end
		end
	end

	return hits, center_hits
end

function PlayerStandard:_pd3ms_is_top_stair_landing_target(pos, forward, target_pos, top_dz, obstacle_dist)
	-- v1.4.8.4: The repeating-tread reject catches the middle of a staircase, but the
	-- final riser can look like a normal low ledge because a flat landing continues
	-- behind it. Reject only when the player is already on a stair-like approach:
	-- several lower tread levels are immediately behind the player, and the target
	-- ahead is only a low step/landing height. This leaves standalone ledges, wall
	-- caps, benches/chairs, and normal vault props alone.
	if not pos or not forward or not target_pos or not top_dz then
		return false, "missing-data", 0, 0
	end

	if top_dz < 24 or top_dz > 82 then
		return false, "target-height-outside-final-stair-range", 0, 0
	end

	local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
	local approx_dist = obstacle_dist or target_forward
	if target_forward < 8 or target_forward > 174 or approx_dist > 128 then
		return false, "target-distance-outside-final-stair-range", 0, 0
	end

	local lower_levels = {}
	local lower_hits = 0
	local center_lower_hits = 0
	local same_level_hits = 0

	local function add_lower_level(dz)
		for _, level in ipairs(lower_levels) do
			if math.abs(level - dz) <= 9 then
				return
			end
		end
		table.insert(lower_levels, dz)
	end

	for _, dist in ipairs(PD3MS_FINAL_STAIR_SAMPLE_DISTANCES) do
		for _, side in ipairs(PD3MS_FINAL_STAIR_SAMPLE_SIDES) do
			local ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 142, -126, true)
			if ray and ray.position then
				local normal_ok = true
				if ray.normal and ray.normal.z then
					normal_ok = ray.normal.z > 0.52
				end

				if normal_ok then
					local dz = ray.position.z - pos.z
					if dz <= -10 and dz >= -160 then
						lower_hits = lower_hits + 1
						add_lower_level(dz)
						if side == 0 then
							center_lower_hits = center_lower_hits + 1
						end
					elseif math.abs(dz) <= 10 then
						same_level_hits = same_level_hits + 1
					end
				end
			end
		end
	end

	table.sort(lower_levels)

	local stair_gaps = 0
	local last_level = nil
	for _, level in ipairs(lower_levels) do
		if last_level and (level - last_level) >= 11 and (level - last_level) <= 44 then
			stair_gaps = stair_gaps + 1
		end
		last_level = level
	end

	-- Require multiple lower tread levels behind the player. A normal low wall/ledge
	-- approach has flat ground behind it, while the last stair before a landing has a
	-- visible descending tread sequence behind/under the player. The same-level hit
	-- requirement keeps open drops behind the player from being mistaken for stairs.
	if #lower_levels >= 2 and stair_gaps >= 1 and lower_hits >= 4 and center_lower_hits >= 1 and same_level_hits >= 2 then
		local approach_riser_hits, approach_center_hits = self:_pd3ms_stair_approach_riser_score(pos, forward)
		if approach_riser_hits >= 3 and approach_center_hits >= 1 then
			return true, "final-stair-landing-approach", lower_hits, #lower_levels
		end
		return false, "lower-ground-without-stair-risers", approach_riser_hits, #lower_levels
	end

	return false, "no-final-stair-approach", lower_hits, #lower_levels
end

function PlayerStandard:_pd3ms_horizontal_ray(pos, forward, forward_from, forward_to, side, height, allow_non_world)
	local from_forward = forward_from or 0
	local to_forward = forward_to or 0
	local side_amt = side or 0
	local ray_z = pos.z + (height or 0)
	local from_x = pos.x + (forward.x * from_forward) + (forward.y * side_amt)
	local from_y = pos.y + (forward.y * from_forward) - (forward.x * side_amt)
	local to_x = pos.x + (forward.x * to_forward) + (forward.y * side_amt)
	local to_y = pos.y + (forward.y * to_forward) - (forward.x * side_amt)
	return self:_pd3ms_world_ray_xyz(from_x, from_y, ray_z, to_x, to_y, ray_z, allow_non_world)
end

function PlayerStandard:_pd3ms_is_clear_lane(pos, forward, forward_from, forward_to, side, height)
	return self:_pd3ms_horizontal_ray(pos, forward, forward_from, forward_to, side, height, true) == nil
end

function PlayerStandard:_pd3ms_skinny_head_clearance(pos, forward, forward_from, forward_to, top_dz, sides, low_extra, high_extra)
	local clear_lanes = 0
	local center_clear = false

	for _, side in ipairs(sides) do
		local clear = self:_pd3ms_is_clear_lane(pos, forward, forward_from, forward_to, side, top_dz + low_extra)
			and self:_pd3ms_is_clear_lane(pos, forward, forward_from, forward_to, side, top_dz + high_extra)

		if clear then
			clear_lanes = clear_lanes + 1
			if side == 0 then
				center_clear = true
			end
		end
	end

	return clear_lanes, center_clear
end

function PlayerStandard:_pd3ms_estimate_skinny_top_height(pos, forward, obstacle_ray, obstacle_dist)
	if not obstacle_ray or not obstacle_ray.position then
		return nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 14, 104)
	local best_dz = nil

	-- First try to hit the actual skinny top from above. The normal check is deliberately
	-- looser than the normal top-mantle path because rail collision can be rounded/slanted.
	for _, offset in ipairs(PD3MS_ESTIMATE_SKINNY_SCAN_OFFSETS) do
		local dist = offset < 0 and math.max(hit_dist + offset, 8) or hit_dist + offset
		for _, side in ipairs(PD3MS_ESTIMATE_SKINNY_SCAN_SIDES) do
			local ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 164, 10, true)
			if ray and ray.position then
				local dz = ray.position.z - pos.z
				local normal_ok = true
				if ray.normal and ray.normal.z then
					normal_ok = ray.normal.z > 0.16
				end
				if normal_ok and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_SKINNY_MANTLE_DZ and (not best_dz or dz > best_dz) then
					best_dz = dz
				end
			end
		end
	end

	-- If the down ray misses the top of a very thin round rail, estimate the rail height
	-- from forward probe hits on/near the same obstacle. This keeps the fallback usable on
	-- guardrails without requiring a fake landing point behind them.
	local highest_hit_dz = nil
	for _, height in ipairs(PD3MS_ESTIMATE_SKINNY_HEIGHTS) do
		for _, side in ipairs(PD3MS_ESTIMATE_SKINNY_SIDES) do
			local ray = self:_pd3ms_horizontal_ray(pos, forward, 2, hit_dist + 18, side, height, true)
			if ray and ray.position then
				local dist = self:_pd3ms_flat_distance_from(pos, ray.position)
				if dist >= math.max(3, hit_dist - 14) and dist <= hit_dist + 18 then
					local dz = ray.position.z - pos.z
					if dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_SKINNY_MANTLE_DZ and (not highest_hit_dz or dz > highest_hit_dz) then
						highest_hit_dz = dz
					end
				end
			end
		end
	end

	if highest_hit_dz and (not best_dz or highest_hit_dz > best_dz) then
		best_dz = highest_hit_dz
	end

	if not best_dz then
		local hit_dz = obstacle_ray.position.z - pos.z
		if hit_dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and hit_dz <= PD3MS_MAX_SKINNY_MANTLE_DZ then
			best_dz = hit_dz
		end
	end

	return best_dz
end

function PlayerStandard:_pd3ms_find_skinny_top_target(pos, forward, obstacle_ray, obstacle_dist)
	if not obstacle_ray or not obstacle_ray.position then
		return nil, nil, nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 8, 112)
	local top_dz = self:_pd3ms_estimate_skinny_top_height(pos, forward, obstacle_ray, hit_dist)
	if not top_dz or top_dz < PD3MS_MIN_GENERAL_MANTLE_DZ or top_dz > PD3MS_MAX_SKINNY_MANTLE_DZ then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("skinny reject: bad top height dz=" .. tostring(top_dz))
		end
		return nil, nil, nil
	end

	-- Guardrails/fences are not wide enough to satisfy the normal supported-top area test.
	-- The important safety check is that the space above the rail is open. A real wall keeps
	-- blocking these lanes above the detected rail height, while a rail/fence does not.
	local head_clear_lanes, center_head_clear = self:_pd3ms_skinny_head_clearance(pos, forward, 4, hit_dist + 20, top_dz, PD3MS_SKINNY_HEAD_CLEAR_SIDE_OFFSETS, 30, 52)
	if head_clear_lanes < 3 or not center_head_clear then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("skinny reject: no head clearance dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(hit_dist or 0)))
		end
		return nil, nil, nil
	end

	-- Prefer rails/thin props by checking that at least one lane clears soon after the hit.
	-- Do not hard-reject if it fails: some Payday 2 rail sets have a second bar/vertical post
	-- immediately behind the top rail, and those were falling through to the default jump.
	local thin_lanes = 0
	local mid_height = math.clamp(top_dz * 0.58, 32, 82)
	for _, side in ipairs(PD3MS_BACKSTOP_SIDE_OFFSETS) do
		if self:_pd3ms_is_clear_lane(pos, forward, hit_dist + 5, hit_dist + 28, side, mid_height) then
			thin_lanes = thin_lanes + 1
		end
	end

	-- Put the target on the rail/top itself, not deep behind it. The previous build used a
	-- behind-the-rail target, which could start but then feel like a normal jump because the
	-- capsule never settled onto the skinny top surface.
	local target_forward = hit_dist + (thin_lanes > 0 and 3 or 5)
	local target_pos = self:_pd3ms_offset_from(pos, forward, target_forward, 0, top_dz + 7)
	local skinny_clearance_ok = self:_pd3ms_has_skinny_clearance_at(target_pos, forward, 90)
	if not skinny_clearance_ok then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("skinny reject: target blocked dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(hit_dist or 0)))
		end
		return nil, nil, nil
	end

	if thin_lanes < 2 and self:_pd3ms_is_shelf_like_landing(target_pos, forward, math.max(1, thin_lanes)) then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("skinny reject: shelf-like landing dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(hit_dist or 0)))
		end
		return nil, nil, nil
	end

	return target_pos, top_dz, math.max(1, thin_lanes)
end

function PlayerStandard:_pd3ms_find_horizontal_skinny_top_target(pos, forward, obstacle_dist)
	-- Last-resort rail-bar sweep for the unreliable small Shadow Raid rail style.
	-- This catches the highest horizontal bar using side/height rays, which is more reliable
	-- than down-rays on very thin/rounded collision. It only runs after normal mantle paths
	-- fail and still requires overhead clearance plus low broad-surface support.
	if not pos or not forward then
		return nil, nil, nil, nil
	end

	local max_range = obstacle_dist and math.clamp(obstacle_dist + 32, 28, 122) or 86
	local min_dist = obstacle_dist and math.max(-4, obstacle_dist - 18) or -4
	local side_offsets = PD3MS_HORIZONTAL_SKINNY_SIDES
	local heights = PD3MS_HORIZONTAL_SKINNY_HEIGHTS
	local best = nil
	local best_dz = nil
	local best_dist = nil
	local best_support = 0
	local best_score = nil

	for _, height in ipairs(heights) do
		for _, side in ipairs(side_offsets) do
			local ray = self:_pd3ms_horizontal_ray(pos, forward, -6, max_range, side, height, true)
			if ray and ray.position then
				local hit_forward = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
				local dist = self:_pd3ms_flat_distance_from(pos, ray.position)
				local dz = ray.position.z - pos.z

				if hit_forward >= min_dist and dist <= max_range and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_SKINNY_MANTLE_DZ then
					-- Do not turn broad floors/hoods/crates into skinny rails. Those normally have
					-- a lot of depth and support hits at the same height.
					local depth_hits = 0
					for _, extra in ipairs(PD3MS_HORIZONTAL_SKINNY_DEPTH_EXTRAS) do
						local depth_ray = self:_pd3ms_down_ray_offset_from(pos, forward, hit_forward + extra, side, 0, 176, 18, true)
						if depth_ray and depth_ray.position then
							local depth_dz = depth_ray.position.z - pos.z
							if math.abs(depth_dz - dz) <= 16 then
								depth_hits = depth_hits + 1
							end
						end
					end

					local target_forward = math.clamp(hit_forward + 3, 4, 118)
					local target_pos = self:_pd3ms_offset_from(pos, forward, target_forward, 0, dz + 7)
					local _, support_hits = self:_pd3ms_top_surface_support(target_pos, forward)

					local skinny_clearance_ok = self:_pd3ms_has_skinny_clearance_at(target_pos, forward, 88)
					if depth_hits <= 1 and (support_hits or 0) <= 3 and skinny_clearance_ok and not self:_pd3ms_is_shelf_like_landing(target_pos, forward, support_hits) then
						local head_clear_lanes, center_head_clear = self:_pd3ms_skinny_head_clearance(pos, forward, 0, target_forward + 18, dz, PD3MS_SKINNY_HEAD_CLEAR_WIDE_SIDE_OFFSETS, 24, 48)
						if head_clear_lanes >= 3 and center_head_clear then
							local ideal_dist = obstacle_dist and math.clamp(obstacle_dist + 3, 4, 118) or 38
							-- Prefer the highest usable rail bar so lower/middle bars do not get rejected
							-- by the actual top rail sitting above them.
							local score = math.abs(target_forward - ideal_dist) * 0.42 + math.abs(side) * 0.55 + depth_hits * 15 + (support_hits or 0) * 2.5 - dz * 0.10
							if not best_score or score < best_score then
								best = target_pos
								best_dz = dz
								best_dist = target_forward
								best_support = math.max(1, support_hits or 0)
								best_score = score
							end
						end
					end
				end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("horizontal skinny-top candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0))
		end
		return best, best_dz, best_support, best_dist
	end

	return nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_find_sphere_skinny_rail_target(pos, forward, obstacle_dist)
	-- Last-resort sweep for real skinny handrail collision that normal line rays miss.
	-- This only runs after the normal no-obstacle skinny scans fail, so broad ledges,
	-- posts, furniture, and the existing slide/minigame behavior keep their v4 paths.
	if not pos or not forward then
		return nil, nil, nil, nil
	end

	local max_range = obstacle_dist and math.clamp(obstacle_dist + 30, 34, 118) or 96
	local min_forward = obstacle_dist and math.max(-8, obstacle_dist - 24) or -10
	local best = nil
	local best_dz = nil
	local best_dist = nil
	local best_support = 0
	local best_score = nil
	local best_radius = nil
	local seen_hits = 0

	for _, radius in ipairs(PD3MS_SPHERE_SKINNY_RADII) do
		for _, height in ipairs(PD3MS_SPHERE_SKINNY_HEIGHTS) do
			for _, side in ipairs(PD3MS_SPHERE_SKINNY_SIDE_OFFSETS) do
				local from_x = pos.x + (forward.x * -12) + (forward.y * side)
				local from_y = pos.y + (forward.y * -12) - (forward.x * side)
				local to_x = pos.x + (forward.x * max_range) + (forward.y * side)
				local to_y = pos.y + (forward.y * max_range) - (forward.x * side)
				local ray = self:_pd3ms_world_sphere_ray_xyz(from_x, from_y, pos.z + height, to_x, to_y, pos.z + height, radius, true)
				if ray and ray.position then
					seen_hits = seen_hits + 1
					local hit_forward = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
					local dist = self:_pd3ms_flat_distance_from(pos, ray.position)
					local dz = ray.position.z - pos.z

					if hit_forward >= min_forward and hit_forward <= max_range and dist <= (max_range + 10) and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= 112 then
						local upper_height = pos.z + height + 22
						local upper_ray = self:_pd3ms_world_sphere_ray_xyz(from_x, from_y, upper_height, to_x, to_y, upper_height, radius, true)
						local upper_blocks_same_face = false
						if upper_ray and upper_ray.position then
							local upper_forward = self:_pd3ms_forward_progress_from(pos, upper_ray.position, forward)
							if math.abs(upper_forward - hit_forward) <= 18 then
								upper_blocks_same_face = true
							end
						end

						if not upper_blocks_same_face then
							local depth_hits = 0
							for _, extra in ipairs(PD3MS_SPHERE_SKINNY_DEPTH_EXTRAS) do
								local depth_ray = self:_pd3ms_down_ray_offset_from(pos, forward, hit_forward + extra, side, 0, 174, 18, true)
								if depth_ray and depth_ray.position then
									local depth_dz = depth_ray.position.z - pos.z
									if math.abs(depth_dz - dz) <= 16 then
										depth_hits = depth_hits + 1
									end
								end
							end

							local target_forward = math.clamp(hit_forward + 4, 6, 118)
							local target_pos = self:_pd3ms_offset_from(pos, forward, target_forward, 0, dz + 7)
							local _, support_hits = self:_pd3ms_top_surface_support(target_pos, forward)

							if depth_hits <= 1 and (support_hits or 0) <= 3 and self:_pd3ms_has_skinny_clearance_at(target_pos, forward, 90) and not self:_pd3ms_is_shelf_like_landing(target_pos, forward, support_hits) then
								local head_clear_lanes, center_head_clear = self:_pd3ms_skinny_head_clearance(pos, forward, 0, target_forward + 18, dz, PD3MS_SKINNY_HEAD_CLEAR_WIDE_SIDE_OFFSETS, 24, 50)
								if head_clear_lanes >= 3 and center_head_clear then
									local ideal_dist = obstacle_dist and math.clamp(obstacle_dist + 3, 6, 118) or 38
									local score = math.abs(target_forward - ideal_dist) * 0.44 + math.abs(side) * 0.58 + depth_hits * 16 + (support_hits or 0) * 2.5 + radius * 0.35 + math.max(dz - 104, 0) * 0.6
									if not best_score or score < best_score then
										best = target_pos
										best_dz = dz
										best_dist = target_forward
										best_support = math.max(1, support_hits or 0)
										best_score = score
										best_radius = radius
									end
								end
							end
						end
					end
				end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("sphere skinny-rail candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0) .. " radius=" .. tostring(best_radius or 0))
		end
		return best, best_dz, best_support, best_dist
	end

	if seen_hits > 0 then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("sphere skinny-rail nil hits=" .. tostring(seen_hits))
		end
	end

	return nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_find_direct_skinny_top_target(pos, forward, obstacle_dist)
	-- Last-resort fallback for very small/rounded rails where the normal horizontal
	-- obstacle rays pass through gaps or catch the wrong bar. This only runs after
	-- the normal top path and the existing skinny-rail path fail, so car hoods,
	-- crates, dumpsters, and other broad tops keep using the original mantle logic.
	if not pos or not forward then
		return nil, nil, nil, nil
	end

	local hit_dist = obstacle_dist and math.clamp(obstacle_dist, 6, 112) or nil
	local distances = hit_dist and PD3MS_DIRECT_SKINNY_HIT_DISTANCE_OFFSETS or PD3MS_DIRECT_SKINNY_DEFAULT_DISTANCES

	local best = nil
	local best_dz = nil
	local best_dist = nil
	local best_support = 0
	local best_score = nil

	for _, dist_value in ipairs(distances) do
		local dist = hit_dist and (dist_value < 0 and math.max(hit_dist + dist_value, 6) or hit_dist + dist_value) or dist_value
		for _, side in ipairs(PD3MS_DIRECT_SKINNY_SIDE_OFFSETS) do
			local ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 180, 18, true)
			if ray and ray.position then
				local dz = ray.position.z - pos.z
				local normal_ok = true
				if ray.normal and ray.normal.z then
					normal_ok = ray.normal.z > 0.08
				end

				if normal_ok and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_SKINNY_MANTLE_DZ then
					-- A skinny rail may be long sideways, but it should not have broad depth
					-- at the same height. Broad props/floors produce several depth hits here.
					local depth_hits = 0
					for _, extra in ipairs(PD3MS_DIRECT_SKINNY_DEPTH_EXTRAS) do
						local depth_ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist + extra, side, 0, 180, 18, true)
						if depth_ray and depth_ray.position then
							local depth_dz = depth_ray.position.z - pos.z
							if math.abs(depth_dz - dz) <= 16 then
								depth_hits = depth_hits + 1
							end
						end
					end

					if depth_hits <= 1 then
						local hit_forward = self:_pd3ms_forward_progress_from(pos, ray.position, forward)
						local target_forward = math.clamp(hit_forward + 3, 6, 118)
						local target_pos = self:_pd3ms_offset_from(pos, forward, target_forward, 0, dz + 7)
						local _, support_hits = self:_pd3ms_top_surface_support(target_pos, forward)

						-- Full broad tops generally have 4-5 support hits and should never be
						-- converted to the skinny fallback. Rails/fences usually have 0-3.
						local skinny_clearance_ok = self:_pd3ms_has_skinny_clearance_at(target_pos, forward, 90)
						if (support_hits or 0) <= 3 and skinny_clearance_ok and not self:_pd3ms_is_shelf_like_landing(target_pos, forward, support_hits) then
							local head_clear_lanes, center_head_clear = self:_pd3ms_skinny_head_clearance(pos, forward, 3, target_forward + 18, dz, PD3MS_SKINNY_HEAD_CLEAR_SIDE_OFFSETS, 30, 52)
							if head_clear_lanes >= 3 and center_head_clear then
								local ideal_dist = obstacle_dist and math.clamp(obstacle_dist + 3, 8, 118) or 42
								local score = math.abs(target_forward - ideal_dist) * 0.44 + math.abs(side) * 0.58 + depth_hits * 18 + (support_hits or 0) * 2.75 + math.max(dz - 112, 0) * 0.40
								if not best_score or score < best_score then
									best = target_pos
									best_dz = dz
									best_dist = target_forward
									best_support = math.max(1, support_hits or 0)
									best_score = score
								end
							end
						end
					end
				end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("direct skinny-top candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0))
		end
		return best, best_dz, best_support, best_dist
	end

	return nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_wall_cap_surface_support(pos, forward)
	if not pos or not forward then
		return false, 0
	end

	-- Partition/wall caps are long but very shallow, so the normal broad-top support
	-- check can flicker depending on view angle. Use tight samples around the cap.
	local hits = 0
	local base_z = pos.z

	for _, data in ipairs(PD3MS_WALL_CAP_SUPPORT_CHECKS) do
		local ray = self:_pd3ms_down_ray_offset_from(pos, forward, data[1], data[2], 0, 58, -28, true)
		if ray and ray.position then
			local normal_ok = true
			if ray.normal and ray.normal.z then
				normal_ok = ray.normal.z > 0.30
			end

			if normal_ok and math.abs(ray.position.z - base_z) <= 15 then
				hits = hits + 1
			end
		end
	end

	return hits >= 2, hits
end

function PlayerStandard:_pd3ms_find_near_wall_cap_target(pos, forward, obstacle_ray, obstacle_dist)
	if not pos or not forward or not obstacle_ray or not obstacle_ray.position then
		return nil, nil, nil, nil, nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 4, 108)
	local hit_dz = obstacle_ray.position.z - pos.z
	if hit_dz > (PD3MS_MAX_TOP_MANTLE_DZ + 26) then
		return nil, nil, nil, nil, nil
	end

	local best = nil
	local best_dz = nil
	local best_support = 0
	local best_dist = nil
	local best_crouch_mantle = false
	local best_score = nil

	for _, raw_offset in ipairs(PD3MS_WALL_CAP_DISTANCE_OFFSETS) do
		local dist = math.clamp(hit_dist + raw_offset, 4, 136)
		for _, side in ipairs(PD3MS_WALL_CAP_SIDE_OFFSETS) do
			local top_ray = self:_pd3ms_down_ray_offset_from(pos, forward, dist, side, 0, 210, -34, true)
			if top_ray and top_ray.position then
				local dz = top_ray.position.z - pos.z
				local normal_ok = true
				if top_ray.normal and top_ray.normal.z then
					normal_ok = top_ray.normal.z > 0.32
				end

				if normal_ok and dz >= PD3MS_MIN_GENERAL_MANTLE_DZ and dz <= PD3MS_MAX_TOP_MANTLE_DZ then
					local target_pos = mvector3.copy(top_ray.position)
					mvector3.add(target_pos, Vector3(0, 0, 6))

					local support_ok, support_hits = self:_pd3ms_wall_cap_surface_support(target_pos, forward)
					local depth_hits = self:_pd3ms_landing_depth_hits(target_pos, forward, true)
					local clearance_ok, crouch_mantle = self:_pd3ms_landing_clearance(target_pos, forward, 104, true)
					if support_ok and depth_hits <= 5 and clearance_ok then
						local target_forward = self:_pd3ms_forward_progress_from(pos, target_pos, forward)
						local ideal_dist = hit_dist + 7
						local score = math.abs(target_forward - ideal_dist) * 1.05
							+ math.abs(side) * 1.15
							+ math.max(depth_hits - 1, 0) * 7.5
							+ math.max(dz - 112, 0) * 0.38
							- (support_hits or 0) * 2.0

						if not best_score or score < best_score then
							best = target_pos
							best_dz = dz
							best_support = support_hits or 1
							best_dist = target_forward
							best_crouch_mantle = crouch_mantle
							best_score = score
						end
					end
				end
			end
		end
	end

	if best then
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("near-wall-cap candidate dz=" .. tostring(math.floor(best_dz or 0)) .. " dist=" .. tostring(math.floor(best_dist or 0)) .. " support=" .. tostring(best_support or 0))
		end
		return best, best_dz, best_support, best_dist, best_crouch_mantle
	end

	return nil, nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_find_top_target(pos, forward, obstacle_ray, obstacle_dist)
	if not obstacle_ray or not obstacle_ray.position then
		return nil, nil, nil
	end

	local hit_dist = math.clamp(obstacle_dist or self:_pd3ms_flat_distance_from(pos, obstacle_ray.position), 14, 104)
	local right = Vector3(forward.y, -forward.x, 0)
	-- Keep the scan generous enough for prop collision, but do not reach so far/high that
	-- brick walls and tall scenery become climbable.
	local distance_offsets = PD3MS_TOP_SCAN_DISTANCE_OFFSETS
	local side_offsets = PD3MS_TOP_SCAN_SIDE_OFFSETS
	local hard_max_top_dz = PD3MS_MAX_TOP_MANTLE_DZ
	local best = nil
	local best_score = nil
	local best_dz = nil
	local best_support = 0
	local best_crouch_mantle = false

	for _, offset in ipairs(distance_offsets) do
		local dist = hit_dist + offset
		for _, side in ipairs(side_offsets) do
			local scan_xy = mvector3.copy(pos)
			local f = mvector3.copy(forward)
			mvector3.multiply(f, dist)
			mvector3.add(scan_xy, f)

			if side ~= 0 then
				local s = mvector3.copy(right)
				mvector3.multiply(s, side)
				mvector3.add(scan_xy, s)
			end

			local top_ray = self:_pd3ms_down_ray_at(scan_xy, 260, -52, true)
			if top_ray and top_ray.position then
				local dz = top_ray.position.z - pos.z
				local top_normal_ok = true
				if top_ray.normal and top_ray.normal.z then
					top_normal_ok = top_ray.normal.z > 0.54
				end

				if top_normal_ok and dz >= 24 and dz <= hard_max_top_dz then
					local target_pos = mvector3.copy(top_ray.position)
					mvector3.add(target_pos, Vector3(0, 0, 6))

					local support_ok, support_hits = self:_pd3ms_top_surface_support(target_pos, forward)
					local clearance_ok, crouch_mantle = self:_pd3ms_landing_clearance(target_pos, forward, 104, true)
					if support_ok and clearance_ok then
						local landing_pos = target_pos
						local landing_dz = dz
						local landing_crouch_mantle = crouch_mantle
						local raised_pos, raised_dz = self:_pd3ms_find_raised_top_landing(target_pos, forward, pos.z, hard_max_top_dz)
						if raised_pos then
							local raised_support_ok, raised_support_hits = self:_pd3ms_top_surface_support(raised_pos, forward)
							local raised_clearance_ok, raised_crouch_mantle = self:_pd3ms_landing_clearance(raised_pos, forward, 104, true)
							if raised_support_ok and raised_clearance_ok then
								landing_pos = raised_pos
								landing_dz = raised_dz
								support_hits = raised_support_hits
								landing_crouch_mantle = raised_crouch_mantle
							end
						end

						local ideal_dist = hit_dist + math.clamp(38 + dz * 0.08, 34, 78)
						local height_penalty = math.max(dz - 104, 0) * 0.85
						local shallow_penalty = offset < 24 and 14 or 0
						local deep_penalty = math.max(offset - 142, 0) * 0.30
						local support_bonus = (support_hits or 0) * -4
						local score = math.abs(side) * 1.40 + math.abs(dist - ideal_dist) + height_penalty + shallow_penalty + deep_penalty + support_bonus
						if not best_score or score < best_score then
							best = landing_pos
							best_score = score
							best_dz = landing_dz
							best_support = support_hits or 0
							best_crouch_mantle = landing_crouch_mantle
					end
					end
				end
			end
		end
	end

	if best then
		self:_pd3ms_debug_target_info("find-top-best", best, pos, forward, best_dz, best_support, hit_dist)
		local tiny_lip, tiny_reason, depth_hits, blocked_lanes = self:_pd3ms_is_too_small_step_lip(best, forward, best_dz, best_support, pos, obstacle_ray)
		if tiny_lip then
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("top reject: tiny step lip reason=" .. tostring(tiny_reason) .. " dz=" .. tostring(math.floor(best_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
			end
			return nil, nil, nil
		end

		return best, best_dz, best_support, best_crouch_mantle
	end

	self:_pd3ms_vault_log("find-top-best: nil")
	return nil, nil, nil, nil
end

function PlayerStandard:_pd3ms_find_over_target(pos, forward, obstacle_dist)
	local hit_dist = math.clamp(obstacle_dist or 48, 14, 102)
	for _, offset in ipairs(PD3MS_OVER_LANDING_OFFSETS) do
		local ground_ray = self:_pd3ms_down_ray_offset_from(pos, forward, hit_dist + offset, 0, 0, 230, -112, true)
		if ground_ray and ground_ray.position then
			local dz = ground_ray.position.z - pos.z
			local ground_ok = true
			if ground_ray.normal and ground_ray.normal.z then
				ground_ok = ground_ray.normal.z > 0.54
			end
			if ground_ok and dz <= 56 and dz >= -92 then
				local target_pos = self:_pd3ms_offset_from(ground_ray.position, forward, 0, 0, 5)
				local clearance_ok, crouch_mantle = self:_pd3ms_landing_clearance(target_pos, forward, 118, false)
				if clearance_ok then
					return target_pos, dz, crouch_mantle
				end
			end
		end
	end

	return nil, nil, nil
end

function PlayerStandard:_pd3ms_find_vault(forward, air_catch_probe)
	if not forward then
		self:_pd3ms_vault_log("reject: no forward")
		return nil
	end

	local pos = self._unit:position()
	local obstacle_ray, obstacle_dist = self:_pd3ms_find_obstacle_ray(pos, forward, air_catch_probe)
	self:_pd3ms_debug_ray_info("obstacle", obstacle_ray, pos, forward, obstacle_dist)
	local top_target, top_dz, top_support = nil, nil, nil
	local skinny_top = false
	local sphere_skinny_rail = false
	local low_furniture_top = false
	local cluttered_table_top = false
	local cluttered_table_depth_hits = 0
	local rear_furniture_top = false
	local rear_furniture_backrest_top = false
	local low_furniture_clear_dz = nil
	local low_furniture_backrest_dist = nil
	local low_furniture_proof = nil
	local wall_cap_top = false
	local near_wall_cap_target = nil
	local near_wall_cap_dz = nil
	local near_wall_cap_support = nil
	local near_wall_cap_dist = nil
	local near_wall_cap_crouch_mantle = false
	local crouch_mantle = false

	if obstacle_ray then
		-- Keep the original broad top scan as the primary result. The furniture
		-- rescue is evaluated later and must prove a backrest/backstop before it
		-- is allowed to suppress the original low-ledge vault-over path.
		top_target, top_dz, top_support, crouch_mantle = self:_pd3ms_find_top_target(pos, forward, obstacle_ray, obstacle_dist)
		self:_pd3ms_debug_target_info("normal-top", top_target, pos, forward, top_dz, top_support, obstacle_dist)

		local cap_target, cap_dz, cap_support, cap_dist, cap_crouch_mantle = self:_pd3ms_find_near_wall_cap_target(pos, forward, obstacle_ray, obstacle_dist)
		near_wall_cap_target = cap_target
		near_wall_cap_dz = cap_dz
		near_wall_cap_support = cap_support
		near_wall_cap_dist = cap_dist
		near_wall_cap_crouch_mantle = cap_crouch_mantle
		self:_pd3ms_debug_target_info("near-wall-cap", cap_target, pos, forward, cap_dz, cap_support, cap_dist or obstacle_dist)
		if cap_target then
			local use_cap_target = false
			if not top_target then
				use_cap_target = true
			else
				local normal_forward = self:_pd3ms_forward_progress_from(pos, top_target, forward)
				local cap_forward = cap_dist or self:_pd3ms_forward_progress_from(pos, cap_target, forward)
				local normal_depth_hits = self:_pd3ms_landing_depth_hits(top_target, forward, true)
				local close_to_front = cap_forward <= ((obstacle_dist or cap_forward) + 24)
				local noticeably_closer = cap_forward <= (normal_forward - 10)
				local similar_height = math.abs((top_dz or 0) - (cap_dz or 0)) <= 22

				if close_to_front and similar_height and (noticeably_closer or normal_depth_hits <= 5) then
					use_cap_target = true
				end
			end

			if use_cap_target then
				top_target = cap_target
				top_dz = cap_dz
				top_support = cap_support or 2
				obstacle_dist = cap_dist and math.max(8, cap_dist - 7) or obstacle_dist
				wall_cap_top = true
				crouch_mantle = cap_crouch_mantle
			end
		end

		-- If the strict flat/support scan misses a rounded front prop top, try a
		-- broad rounded-surface fallback. This is aimed at car hoods/low dumpster
		-- lids approached from the front bumper/face, while the stair checks below
		-- still reject actual staircase treads.
		if not top_target then
			local rounded_target, rounded_dz, rounded_support, rounded_dist, rounded_crouch_mantle = self:_pd3ms_find_rounded_front_prop_top_target(pos, forward, obstacle_ray, obstacle_dist)
			self:_pd3ms_debug_target_info("rounded-fallback", rounded_target, pos, forward, rounded_dz, rounded_support, rounded_dist or obstacle_dist)
			if rounded_target then
				top_target = rounded_target
				top_dz = rounded_dz
				top_support = rounded_support or 3
				obstacle_dist = rounded_dist or obstacle_dist
				crouch_mantle = rounded_crouch_mantle
			end
		end
	else
		-- Some very thin rails are almost impossible to catch with a horizontal face
		-- ray, especially when the player is already touching them. Try fallback rail
		-- top searches before giving up to PAYDAY 2's default jump.
		local direct_target, direct_dz, direct_support, direct_dist = self:_pd3ms_find_direct_skinny_top_target(pos, forward, nil)
		if direct_target then
			local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(direct_target, forward, direct_dz, direct_support)
			if tiny_lip then
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("direct skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(direct_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
				end
			else
				top_target = direct_target
				top_dz = direct_dz
				top_support = direct_support or 1
				obstacle_dist = direct_dist or 42
				skinny_top = true
				crouch_mantle = false
			end
		end
		if not top_target then
			local horizontal_target, horizontal_dz, horizontal_support, horizontal_dist = self:_pd3ms_find_horizontal_skinny_top_target(pos, forward, nil)
			if horizontal_target then
				local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(horizontal_target, forward, horizontal_dz, horizontal_support)
				if tiny_lip then
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("horizontal skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(horizontal_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
					end
				else
					top_target = horizontal_target
					top_dz = horizontal_dz
					top_support = horizontal_support or 1
					obstacle_dist = horizontal_dist or 42
					skinny_top = true
					crouch_mantle = false
				end
			end
			if not top_target then
				local sphere_target, sphere_dz, sphere_support, sphere_dist = self:_pd3ms_find_sphere_skinny_rail_target(pos, forward, nil)
				if sphere_target then
					local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(sphere_target, forward, sphere_dz, sphere_support)
					if tiny_lip then
						if self:_pd3ms_vault_debug_enabled() then
							self:_pd3ms_vault_log("sphere skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(sphere_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
						end
					else
						top_target = sphere_target
						top_dz = sphere_dz
						top_support = sphere_support or 1
						obstacle_dist = sphere_dist or 42
						skinny_top = true
						sphere_skinny_rail = true
						crouch_mantle = false
					end
				end
			end
			if not top_target then
				self:_pd3ms_vault_log("reject: no close front ledge")
				return nil
			end
		end
	end

	-- Skinny rails/fences usually fail the normal supported-top area test. Treat them as a
	-- special top-mantle candidate instead of creating a separate vault-over/drop behavior.
	if not top_target and obstacle_ray then
		local skinny_target, skinny_dz, skinny_support = self:_pd3ms_find_skinny_top_target(pos, forward, obstacle_ray, obstacle_dist)
		if skinny_target then
			local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(skinny_target, forward, skinny_dz, skinny_support)
			if tiny_lip then
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(skinny_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
				end
			else
				top_target = skinny_target
				top_dz = skinny_dz
				top_support = skinny_support or 1
				skinny_top = true
				crouch_mantle = false
			end
		end
		if not top_target then
			local direct_target, direct_dz, direct_support, direct_dist = self:_pd3ms_find_direct_skinny_top_target(pos, forward, obstacle_dist)
			if direct_target then
				local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(direct_target, forward, direct_dz, direct_support)
				if tiny_lip then
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("direct skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(direct_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
					end
				else
					top_target = direct_target
					top_dz = direct_dz
					top_support = direct_support or 1
					obstacle_dist = direct_dist or obstacle_dist
					skinny_top = true
					crouch_mantle = false
				end
			end
			if not top_target then
				local horizontal_target, horizontal_dz, horizontal_support, horizontal_dist = self:_pd3ms_find_horizontal_skinny_top_target(pos, forward, obstacle_dist)
				if horizontal_target then
					local tiny_lip, depth_hits, blocked_lanes = self:_pd3ms_is_wall_backed_tiny_lip(horizontal_target, forward, horizontal_dz, horizontal_support)
					if tiny_lip then
						if self:_pd3ms_vault_debug_enabled() then
							self:_pd3ms_vault_log("horizontal skinny reject: wall-backed tiny lip dz=" .. tostring(math.floor(horizontal_dz or 0)) .. " depth=" .. tostring(depth_hits or 0) .. " blocked=" .. tostring(blocked_lanes or 0))
						end
					else
						top_target = horizontal_target
						top_dz = horizontal_dz
						top_support = horizontal_support or 1
						obstacle_dist = horizontal_dist or obstacle_dist
						skinny_top = true
						crouch_mantle = false
					end
				end
			end
		end
	end

	-- If the target came from a skinny fallback, it may actually be the top of a
	-- bench/chair backrest with no horizontal obstacle ray. Try a narrow furniture
	-- proof here so rear approaches can climb onto the back/headrest top
	-- instead of redirecting to the lower seat and fighting the backrest collision.
	-- This is guarded by real furniture proof and only rewrites low skinny candidates.
	if skinny_top and top_target and not wall_cap_top then
		local furniture_target, furniture_dz, furniture_support, furniture_dist, furniture_backstop, furniture_crouch_mantle, furniture_from_skinny, furniture_clear_dz, furniture_backrest_dist, furniture_backrest_top = self:_pd3ms_find_low_furniture_top_from_skinny_candidate(pos, forward, top_target, top_dz, obstacle_dist, top_support)
		if furniture_target then
			top_target = furniture_target
			top_dz = furniture_dz
			top_support = furniture_support or 2
			obstacle_dist = furniture_dist and (furniture_backrest_top and furniture_dist or math.max(8, furniture_dist - 8)) or obstacle_dist
			skinny_top = false
			low_furniture_top = true
			rear_furniture_top = furniture_from_skinny == true
			rear_furniture_backrest_top = furniture_backrest_top == true
			low_furniture_clear_dz = furniture_clear_dz
			low_furniture_backrest_dist = furniture_backrest_dist
			low_furniture_proof = furniture_backstop
			crouch_mantle = furniture_crouch_mantle
		end
	end

	-- Bench/chair rescue runs before the vault-over return, but it is now guarded by
	-- a real furniture proof. Front approaches use the old beyond-seat backrest check;
	-- rear approaches can use a near-side backrest check so benches/chairs still land
	-- on the low seat when approached from behind the backrest.
	if obstacle_ray and not skinny_top and not wall_cap_top then
		local furniture_target, furniture_dz, furniture_support, furniture_dist, furniture_backstop, furniture_crouch_mantle = self:_pd3ms_find_low_furniture_top_target(pos, forward, obstacle_ray, obstacle_dist)
		self:_pd3ms_debug_target_info("furniture", furniture_target, pos, forward, furniture_dz, furniture_support, furniture_dist or obstacle_dist)
		if furniture_target then
			local use_furniture_target = false
			local use_high_backrest_target = false
			local use_wall_cap_over_low_landing = false
			local use_sill_wall_cap_over_false_furniture = false
			local use_window_wall_cap_over_mid_landing = false
			local use_medium_wall_cap_over_false_furniture = false
			local obstacle_hit_dz = obstacle_ray and obstacle_ray.position and (obstacle_ray.position.z - pos.z) or nil
			local preserve_cluttered_tabletop = false
			local preserve_cluttered_depth = 0
			local preserve_cluttered_hit_dz = 0
			local preserve_cluttered_top_forward = 0
			local preserve_cluttered_furniture_forward = 0
			if top_target then
				preserve_cluttered_tabletop, preserve_cluttered_depth, preserve_cluttered_hit_dz, preserve_cluttered_top_forward, preserve_cluttered_furniture_forward = self:_pd3ms_is_cluttered_tabletop_false_low_furniture(pos, forward, obstacle_ray, obstacle_dist, top_target, top_dz, top_support, furniture_target, furniture_dz, furniture_support, furniture_dist, furniture_backstop)
			end

			-- Some one-sided wall/ledge approaches log as a false low-furniture landing:
			-- the real standable wall cap is close to the front hit, while the selected
			-- "furniture" target is a much lower floor/step beyond it. In that case the
			-- correct behavior is still a normal top mantle onto the wall/ledge cap, never
			-- a vault-over/low landing behind it. Keep this narrower than the chair
			-- backrest path by requiring a genuinely low landing behind a tall front hit.
			if near_wall_cap_target and obstacle_hit_dz and furniture_dz and furniture_dist and near_wall_cap_dz and near_wall_cap_dist then
				local low_landing_behind_wall = (furniture_dz or 999) <= 40
				local front_hit_is_wall = (obstacle_hit_dz or 0) >= 58
				local cap_above_hit = near_wall_cap_dz >= ((obstacle_hit_dz or 0) + 10)
				local cap_above_low_landing = near_wall_cap_dz >= ((furniture_dz or 0) + 44)
				local cap_reasonable_height = near_wall_cap_dz <= 132
				local cap_before_low_landing = near_wall_cap_dist <= ((furniture_dist or near_wall_cap_dist) - 10)
				local cap_close_to_front = near_wall_cap_dist <= ((obstacle_dist or near_wall_cap_dist) + 24)
				local cap_support_ok = (near_wall_cap_support or 0) >= 4 and (furniture_backstop or 0) >= 6
				if low_landing_behind_wall and front_hit_is_wall and cap_above_hit and cap_above_low_landing and cap_reasonable_height and cap_before_low_landing and cap_close_to_front and cap_support_ok then
					use_wall_cap_over_low_landing = true
				end
			end

			-- Breakfast in Tijuana-style window frames can look like medium-height
			-- low-furniture: the lower sill/inside landing is supported around dz 50-65,
			-- but the real ledge/window-cap the capsule has to clear is the closer
			-- high cap around dz 100. If the furniture proof is only weak/moderate,
			-- prefer the high supported cap so the mantle lands on top of the window
			-- frame instead of barely lifting onto the lower sill. Keep this separate
			-- from the chair path, which uses stronger furniture proof.
			-- GoBank-style teller windows can hit a low inner sill/desk first and
			-- accidentally look like low furniture or repeating stair treads. When the
			-- close wall-cap scan already found a strong cap at the same height as the
			-- front obstacle, prefer that cap over the low/deeper false furniture target.
			if near_wall_cap_target and obstacle_hit_dz and furniture_dz and furniture_dist and near_wall_cap_dz and near_wall_cap_dist then
				local low_landing_behind_wall = (furniture_dz or 999) <= 40
				local front_hit_is_sill = (obstacle_hit_dz or 0) >= 58 and (obstacle_hit_dz or 0) <= 96
				local cap_matches_front_hit = near_wall_cap_dz >= ((obstacle_hit_dz or 0) - 8) and near_wall_cap_dz <= ((obstacle_hit_dz or 0) + 12)
				local cap_above_low_landing = near_wall_cap_dz >= ((furniture_dz or 0) + 32)
				local cap_reasonable_height = near_wall_cap_dz >= 56 and near_wall_cap_dz <= 104
				local cap_before_low_landing = near_wall_cap_dist <= ((furniture_dist or near_wall_cap_dist) - 6)
				local cap_close_to_front = near_wall_cap_dist <= ((obstacle_dist or near_wall_cap_dist) + 30)
				local cap_support_strong = (near_wall_cap_support or 0) >= 7
				local weak_or_medium_furniture_proof = (furniture_backstop or 0) >= 3 and (furniture_backstop or 0) <= 6
				local normal_low_top_agrees = top_target and top_dz and math.abs((top_dz or 0) - (furniture_dz or 0)) <= 8 and (top_dz or 999) <= 40 and (top_support or 0) <= 4
				local not_strong_chair_seat = (furniture_support or 0) <= 4 or ((furniture_support or 0) == 5 and normal_low_top_agrees)
				if low_landing_behind_wall and front_hit_is_sill and cap_matches_front_hit and cap_above_low_landing and cap_reasonable_height and cap_before_low_landing and cap_close_to_front and cap_support_strong and weak_or_medium_furniture_proof and not_strong_chair_seat then
					use_sill_wall_cap_over_false_furniture = true
				end
			end

			if near_wall_cap_target and obstacle_hit_dz and furniture_dz and furniture_dist and near_wall_cap_dz and near_wall_cap_dist then
				local mid_landing_below_cap = furniture_dz >= 42 and furniture_dz <= 72
				local front_hit_is_tall_window = obstacle_hit_dz >= 70 and obstacle_hit_dz <= 108
				local cap_above_hit = near_wall_cap_dz >= ((obstacle_hit_dz or 0) + 12)
				local cap_above_mid_landing = near_wall_cap_dz >= ((furniture_dz or 0) + 30)
				local cap_window_height = near_wall_cap_dz >= 86 and near_wall_cap_dz <= 128
				local cap_before_mid_landing = near_wall_cap_dist <= ((furniture_dist or near_wall_cap_dist) - 6)
				local cap_close_to_front = near_wall_cap_dist <= ((obstacle_dist or near_wall_cap_dist) + 22)
				local cap_support_strong = (near_wall_cap_support or 0) >= 7
				local weak_or_medium_furniture_proof = (furniture_backstop or 0) >= 3 and (furniture_backstop or 0) <= 6
				local not_strong_chair_seat = (furniture_support or 0) <= 4
				if mid_landing_below_cap and front_hit_is_tall_window and cap_above_hit and cap_above_mid_landing and cap_window_height and cap_before_mid_landing and cap_close_to_front and cap_support_strong and weak_or_medium_furniture_proof and not_strong_chair_seat then
					use_window_wall_cap_over_mid_landing = true
				end
			end


			-- Medium-height wall caps can also look like low furniture when the first
			-- horizontal hit is the wall face and the helper finds a lower/deeper point
			-- behind it. The old window guard above is intentionally tall; this narrower
			-- guard covers the shorter wall-cap shape from the debug clips without
			-- stealing normal low-prop mantles. Require a strong close cap, a weaker
			-- medium/deeper furniture proof, and the normal top scan agreeing with the cap.
			if near_wall_cap_target and obstacle_hit_dz and furniture_dz and furniture_dist and near_wall_cap_dz and near_wall_cap_dist then
				local mid_landing_below_cap = furniture_dz >= 38 and furniture_dz <= 66
				local front_hit_is_medium_wall = obstacle_hit_dz >= 68 and obstacle_hit_dz <= 98
				local cap_at_or_above_hit = near_wall_cap_dz >= ((obstacle_hit_dz or 0) - 4)
				local cap_above_mid_landing = near_wall_cap_dz >= ((furniture_dz or 0) + 22)
				local cap_reasonable_height = near_wall_cap_dz >= 70 and near_wall_cap_dz <= 112
				local cap_before_mid_landing = near_wall_cap_dist <= ((furniture_dist or near_wall_cap_dist) - 8)
				local cap_close_to_front = near_wall_cap_dist <= ((obstacle_dist or near_wall_cap_dist) + 48)
				local cap_support_strong = (near_wall_cap_support or 0) >= 7
				local weak_or_medium_furniture_proof = (furniture_backstop or 0) >= 3 and (furniture_backstop or 0) <= 5
				local not_strong_chair_seat = (furniture_support or 0) <= 4
				local normal_top_matches_cap = top_target and top_dz and math.abs((top_dz or 0) - (near_wall_cap_dz or 0)) <= 12 and (top_support or 0) >= 4
				if mid_landing_below_cap and front_hit_is_medium_wall and cap_at_or_above_hit and cap_above_mid_landing and cap_reasonable_height and cap_before_mid_landing and cap_close_to_front and cap_support_strong and weak_or_medium_furniture_proof and not_strong_chair_seat and normal_top_matches_cap then
					use_medium_wall_cap_over_false_furniture = true
				end
			end

			-- Tall-backed chair rear approaches are a different case from normal low furniture.
			-- The low-furniture proof identifies the chair/seat, while the near-wall-cap scan
			-- often finds the real standable back/headrest top. Prefer that high target only
			-- when all three pieces line up: tall first hit, lower furniture proof, and a
			-- nearby supported cap between the hit and the low seat. This avoids reintroducing
			-- the broad corner/wall-cap rejects that were rolled back in v1.4.37.
			if near_wall_cap_target and obstacle_hit_dz and furniture_dz and furniture_dist and near_wall_cap_dz and near_wall_cap_dist then
				local cap_above_seat = near_wall_cap_dz >= math.max(72, (furniture_dz or 0) + 28)
				local cap_near_hit_height = near_wall_cap_dz >= ((obstacle_hit_dz or 0) + 8) and near_wall_cap_dz <= 128
				local hit_is_backrest = (obstacle_hit_dz or 0) >= ((furniture_dz or 0) + 20) and (obstacle_hit_dz or 0) <= 118
				local cap_before_or_at_seat = near_wall_cap_dist <= ((furniture_dist or 0) + 2)
				local cap_close_to_front_hit = near_wall_cap_dist <= ((obstacle_dist or near_wall_cap_dist) + 14)
				local proof_ok = (furniture_backstop or 0) >= 8 and (furniture_support or 0) >= 3 and (near_wall_cap_support or 0) >= 4
				if cap_above_seat and cap_near_hit_height and hit_is_backrest and cap_before_or_at_seat and cap_close_to_front_hit and proof_ok then
					use_high_backrest_target = true
				end
			end

			if use_wall_cap_over_low_landing or use_sill_wall_cap_over_false_furniture or use_window_wall_cap_over_mid_landing or use_medium_wall_cap_over_false_furniture then
				top_target = near_wall_cap_target
				top_dz = near_wall_cap_dz
				top_support = near_wall_cap_support or 4
				obstacle_dist = near_wall_cap_dist and math.max(8, near_wall_cap_dist - 7) or obstacle_dist
				skinny_top = false
				wall_cap_top = true
				low_furniture_top = false
				rear_furniture_top = false
				rear_furniture_backrest_top = false
				low_furniture_clear_dz = nil
				low_furniture_backrest_dist = nil
				low_furniture_proof = nil
				crouch_mantle = near_wall_cap_crouch_mantle
				if use_sill_wall_cap_over_false_furniture then
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("sill wall-cap used: cap_dz=" .. tostring(math.floor(near_wall_cap_dz or 0)) .. " cap_dist=" .. tostring(math.floor(near_wall_cap_dist or 0)) .. " low_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " low_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " hit_dz=" .. tostring(math.floor(obstacle_hit_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
					end
				elseif use_window_wall_cap_over_mid_landing then
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("window wall-cap used: cap_dz=" .. tostring(math.floor(near_wall_cap_dz or 0)) .. " cap_dist=" .. tostring(math.floor(near_wall_cap_dist or 0)) .. " mid_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " mid_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " hit_dz=" .. tostring(math.floor(obstacle_hit_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
					end
				elseif use_medium_wall_cap_over_false_furniture then
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("medium wall-cap used: cap_dz=" .. tostring(math.floor(near_wall_cap_dz or 0)) .. " cap_dist=" .. tostring(math.floor(near_wall_cap_dist or 0)) .. " mid_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " mid_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " hit_dz=" .. tostring(math.floor(obstacle_hit_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
					end
				else
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("low-landing wall-cap used: cap_dz=" .. tostring(math.floor(near_wall_cap_dz or 0)) .. " cap_dist=" .. tostring(math.floor(near_wall_cap_dist or 0)) .. " low_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " low_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " hit_dz=" .. tostring(math.floor(obstacle_hit_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
					end
				end
			elseif use_high_backrest_target then
				top_target = near_wall_cap_target
				top_dz = near_wall_cap_dz
				top_support = near_wall_cap_support or 4
				obstacle_dist = near_wall_cap_dist or obstacle_dist
				skinny_top = false
				wall_cap_top = false
				low_furniture_top = true
				rear_furniture_top = false
				rear_furniture_backrest_top = true
				low_furniture_clear_dz = near_wall_cap_dz
				low_furniture_backrest_dist = near_wall_cap_dist
				low_furniture_proof = furniture_backstop
				-- Do not force crouch here. The high back/headrest target is a large upward
				-- mantle, and forcing crouch made some chair cases feel stuck.
				crouch_mantle = false
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("low-furniture high-backrest used: backrest_dz=" .. tostring(math.floor(near_wall_cap_dz or 0)) .. " backrest_dist=" .. tostring(math.floor(near_wall_cap_dist or 0)) .. " seat_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " seat_dist=" .. tostring(math.floor(furniture_dist or 0)) .. " hit_dz=" .. tostring(math.floor(obstacle_hit_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0))
				end
			else
				if not top_target then
					use_furniture_target = true
				else
					local dz_gap = (top_dz or 0) - (furniture_dz or 0)
					local same_low_top_family = (top_dz or 999) <= 68 and math.abs((top_dz or 0) - (furniture_dz or 0)) <= 18

					-- Two safe furniture cases:
					-- 1) Original scan found a taller/deeper backrest and the helper found the low seat.
					-- 2) Original scan already found the low seat, but the verified backrest means this
					--    is bench/chair furniture, not a normal ledge that should vault over.
					if (top_dz or 0) >= 70 and (furniture_dz or 999) <= 64 and dz_gap >= 14 and (furniture_backstop or 0) >= 2 then
						use_furniture_target = true
					elseif same_low_top_family and (furniture_backstop or 0) >= 2 then
						use_furniture_target = true
					end
				end

				if preserve_cluttered_tabletop then
					cluttered_table_top = true
					cluttered_table_depth_hits = preserve_cluttered_depth or 0
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("low-furniture ignored: cluttered tabletop preserved top_dz=" .. tostring(math.floor(top_dz or 0)) .. " low_dz=" .. tostring(math.floor(furniture_dz or 0)) .. " proof=" .. tostring(furniture_backstop or 0) .. " depth=" .. tostring(cluttered_table_depth_hits or 0) .. " hit_dz=" .. tostring(math.floor(preserve_cluttered_hit_dz or 0)) .. " top_fp=" .. tostring(math.floor(preserve_cluttered_top_forward or 0)) .. " low_fp=" .. tostring(math.floor(preserve_cluttered_furniture_forward or 0)))
					end
				elseif use_furniture_target then
					top_target = furniture_target
					top_dz = furniture_dz
					top_support = furniture_support or 2
					obstacle_dist = furniture_dist and math.max(8, furniture_dist - 8) or obstacle_dist
					low_furniture_top = true
					low_furniture_proof = furniture_backstop
					crouch_mantle = furniture_crouch_mantle
				else
					self:_pd3ms_vault_log("low-furniture ignored: preserving original ledge/top classification")
				end
			end
		end
	end


	if top_target and skinny_top and not low_furniture_top and not obstacle_ray then
		local skinny_dist = obstacle_dist or self:_pd3ms_forward_progress_from(pos, top_target, forward) or 999
		-- No-obstacle skinny fallbacks are useful for low rails and rear chair backs, but the
		-- remaining corner exploit also appears as a very high, very close horizontal/direct
		-- skinny hit with no front obstacle at all. By this point furniture rescue has already
		-- run, so block only that high/close non-furniture shape.
		if not sphere_skinny_rail and (top_dz or 0) >= 78 and skinny_dist <= 34 and (top_support or 0) <= 2 then
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("reject: skinny no-obstacle edge mantle dz=" .. tostring(math.floor(top_dz or 0)) .. " support=" .. tostring(top_support or 0) .. " dist=" .. tostring(math.floor(skinny_dist or 0)))
			end
			return nil
		end
	end

	if top_target and obstacle_ray and skinny_top and not low_furniture_top then
		if self:_pd3ms_is_skinny_wall_edge_mantle_target(pos, forward, obstacle_ray, obstacle_dist, top_target, top_dz, top_support, low_furniture_top) then
			return nil
		end
	end

	if top_target and not skinny_top then
		local skip_stair_reject = false
		if low_furniture_top and not rear_furniture_top and not rear_furniture_backrest_top and (low_furniture_proof or 0) >= 8 and top_dz and top_dz >= 34 and top_dz <= 66 and (top_support or 0) >= 3 and obstacle_ray and obstacle_ray.position then
			local hit_dz = obstacle_ray.position.z - pos.z
			local hit_dist = obstacle_dist or self:_pd3ms_forward_progress_from(pos, obstacle_ray.position, forward)
			if hit_dz >= (top_dz + 20) and hit_dz <= 116 and (hit_dist or 999) <= 58 then
				skip_stair_reject = true
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("stair reject skipped: strong low-furniture proof=" .. tostring(low_furniture_proof or 0) .. " hit_dz=" .. tostring(math.floor(hit_dz or 0)) .. " top_dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(hit_dist or 0)))
				end
			end
		end

		if not skip_stair_reject and wall_cap_top and not low_furniture_top and top_dz and top_dz >= 84 and top_dz <= 112 and (top_support or 0) >= 7 and obstacle_ray and obstacle_ray.position then
			local hit_dz = obstacle_ray.position.z - pos.z
			local hit_dist = obstacle_dist or self:_pd3ms_forward_progress_from(pos, obstacle_ray.position, forward)
			if hit_dz >= 56 and hit_dz <= 104 and (hit_dist or 999) <= 72 then
				skip_stair_reject = true
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("stair reject skipped: strong wall-cap top=" .. tostring(math.floor(top_dz or 0)) .. " support=" .. tostring(top_support or 0) .. " hit_dz=" .. tostring(math.floor(hit_dz or 0)) .. " dist=" .. tostring(math.floor(hit_dist or 0)))
				end
			end
		end

		if not skip_stair_reject and cluttered_table_top and obstacle_ray and obstacle_ray.position then
			skip_stair_reject = true
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("stair reject skipped: cluttered tabletop top=" .. tostring(math.floor(top_dz or 0)) .. " support=" .. tostring(top_support or 0) .. " depth=" .. tostring(cluttered_table_depth_hits or 0) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)))
			end
		end

		if not skip_stair_reject and not low_furniture_top and not wall_cap_top and not near_wall_cap_target and obstacle_ray and obstacle_ray.position then
			local cluttered_high_landing, clutter_depth_hits, clutter_hit_dz, clutter_target_forward = self:_pd3ms_is_cluttered_high_landing_target(pos, forward, obstacle_ray, obstacle_dist, top_target, top_dz, top_support)
			if cluttered_high_landing then
				skip_stair_reject = true
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("stair reject skipped: cluttered high landing top=" .. tostring(math.floor(top_dz or 0)) .. " support=" .. tostring(top_support or 0) .. " hit_dz=" .. tostring(math.floor(clutter_hit_dz or 0)) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)) .. " target_fp=" .. tostring(math.floor(clutter_target_forward or 0)) .. " depth=" .. tostring(clutter_depth_hits or 0))
				end
			end
		end

		if not skip_stair_reject then
			local stair_tread, stair_reason, stair_hits, stair_levels = self:_pd3ms_is_repeating_stair_tread_target(pos, forward, top_target, top_dz, obstacle_dist, top_support)
			if stair_tread then
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("reject: repeating stair tread reason=" .. tostring(stair_reason) .. " hits=" .. tostring(stair_hits or 0) .. " levels=" .. tostring(stair_levels or 0) .. " dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)) .. " low_furniture=" .. tostring(low_furniture_top))
				end
				return nil
			end
		end

		if not cluttered_table_top then
			local stair_landing, landing_reason, landing_hits, landing_levels = self:_pd3ms_is_top_stair_landing_target(pos, forward, top_target, top_dz, obstacle_dist)
			if stair_landing then
				if self:_pd3ms_vault_debug_enabled() then
					self:_pd3ms_vault_log("reject: final stair landing reason=" .. tostring(landing_reason) .. " hits=" .. tostring(landing_hits or 0) .. " levels=" .. tostring(landing_levels or 0) .. " dz=" .. tostring(math.floor(top_dz or 0)) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)) .. " low_furniture=" .. tostring(low_furniture_top))
				end
				return nil
			end
		end
	end

	local over_target, over_dz = nil, nil

	-- Preserve the original small ledge/wall-cap vault-over behavior unless the object
	-- has already been positively classified as low furniture with a backrest.
	if top_dz and top_dz <= 68 and not skinny_top and not low_furniture_top then
		local over_crouch_mantle = false
		over_target, over_dz, over_crouch_mantle = self:_pd3ms_find_over_target(pos, forward, obstacle_dist)
		crouch_mantle = crouch_mantle or over_crouch_mantle
		self:_pd3ms_debug_target_info("over-target", over_target, pos, forward, over_dz, 0, obstacle_dist)
	end

	local low_upward_top = false
	if top_target and over_target and not skinny_top and not low_furniture_top and top_dz and over_dz then
		-- If the player is already standing close to the target height, a wall/ledge cap can
		-- look like a tiny over-vault even though the correct behavior is to climb/settle onto
		-- its supported top. The failing dumpster-to-window ledge case logged as top dz=26,
		-- support=4, over dz=26: choosing mode=over played the grab but did not carry the
		-- capsule onto the ledge. Prefer top-mode only for shallow *upward* ledges with
		-- real support and a same/higher landing behind them; true step-over/drop vaults keep
		-- the old over path.
		local target_forward = self:_pd3ms_forward_progress_from(pos, top_target, forward)
		local over_same_or_higher = over_dz >= (top_dz - 10) and over_dz >= -2
		local close_low_lip = (obstacle_dist or 999) <= 48 and top_dz >= 18 and top_dz <= 58
		local supported_landing = (top_support or 0) >= 3 and target_forward >= 42
		if close_low_lip and supported_landing and over_same_or_higher then
			low_upward_top = true
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("prefer top: low upward supported ledge top_dz=" .. tostring(math.floor(top_dz or 0)) .. " over_dz=" .. tostring(math.floor(over_dz or 0)) .. " support=" .. tostring(top_support or 0))
			end
		end
	end

	if top_target and not skinny_top then
		local target_forward = self:_pd3ms_forward_progress_from(pos, top_target, forward)
		if self:_pd3ms_corridor_crouch_mantle_needed(pos, forward, top_target, obstacle_dist, target_forward) then
			crouch_mantle = true
			if self:_pd3ms_vault_debug_enabled() then
				self:_pd3ms_vault_log("crouch mantle: low overhead corridor dist=" .. tostring(math.floor(obstacle_dist or 0)) .. " target_fp=" .. tostring(math.floor(target_forward or 0)))
			end
		end
	end

	local forced_over_top = false
	if over_target and not skinny_top and not low_furniture_top then
		-- Old builds returned mode="over" here, but that path only gives a quick
		-- hop-through and often leaves low windows/ledge caps barely moving the player.
		-- The user wants every would-be over-vault to behave like the rest of the mod:
		-- climb onto the detected top surface instead of trying to vault through/over it.
		--
		-- Keep the normal v12 stair/ledge checks intact, but stop the forced-over
		-- fallback from reviving the top-step stair case. That stair case logs as a
		-- low same-height over target hit from a sloped step face; normal ledges and
		-- wall-cap mantles should not go through this block.
		local force_over_blocked_by_stair = false
		if obstacle_ray and obstacle_ray.position and obstacle_ray.normal and top_dz and over_dz then
			local hit_nz = obstacle_ray.normal.z or 0
			local hit_dz = obstacle_ray.position.z - pos.z
			local same_height_over = over_dz >= (top_dz - 8) and over_dz <= (top_dz + 8)
			local step_sized_top = top_dz >= 24 and top_dz <= 68
			local step_face_hit = hit_nz >= 0.55 and hit_dz >= 10 and hit_dz <= 52
			local midrange_fallback = (obstacle_dist or 999) >= 54 and (obstacle_dist or 999) <= 92
			if same_height_over and step_sized_top and step_face_hit and midrange_fallback and (top_support or 0) >= 4 then
				local riser_hits, center_riser_hits = self:_pd3ms_stair_approach_riser_score(pos, forward)
				if riser_hits >= 3 and center_riser_hits >= 1 then
					force_over_blocked_by_stair = true
					if self:_pd3ms_vault_debug_enabled() then
						self:_pd3ms_vault_log("reject: forced-over stair fallback reason=sloped-step-over-target risers=" .. tostring(riser_hits or 0) .. " center=" .. tostring(center_riser_hits or 0) .. " hit_dz=" .. tostring(math.floor(hit_dz or 0)) .. " top_dz=" .. tostring(math.floor(top_dz or 0)) .. " over_dz=" .. tostring(math.floor(over_dz or 0)) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)))
					end
				end
			end
		end
		if force_over_blocked_by_stair then
			return nil
		end
		forced_over_top = true
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("force top: converted old over-target to top mantle top_dz=" .. tostring(math.floor(top_dz or 0)) .. " over_dz=" .. tostring(math.floor(over_dz or 0)) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)))
		end
	end

	if top_target then
		local duration = math.clamp(0.42 + math.max(top_dz or 0, 0) / 1100, 0.44, 0.58)
		if crouch_mantle then
			duration = math.min(duration + 0.035, 0.64)
		end
		if rear_furniture_backrest_top then
			-- Low bench backs still use the older short timing, but tall chair backs need
			-- enough time to make a real upward climb. Keep this far milder than the
			-- abandoned v1.4.35 experiment so it does not lock the player against the chair.
			duration = math.max(duration, (top_dz or 0) >= 72 and math.clamp(0.58 + ((top_dz or 72) - 72) / 520, 0.60, 0.70) or 0.56)
		elseif rear_furniture_top then
			duration = math.max(duration, 0.54)
		end
		if forced_over_top then
			-- Give converted low ledges/windows a little more travel time than the old
			-- over-vault hop so the normal top-mantle servo can actually carry the
			-- capsule onto the surface.
			duration = math.max(duration, 0.52)
		end
		local top_kind = skinny_top and "skinny-top" or (rear_furniture_backrest_top and "rear-furniture-backrest-top" or (rear_furniture_top and "rear-low-furniture-top" or (low_furniture_top and "low-furniture-top" or (forced_over_top and "forced-over-top" or "top"))))
		if crouch_mantle then
			top_kind = "crouch-" .. top_kind
		end
		if wall_cap_top and not skinny_top then
			top_kind = "wall-cap-" .. top_kind
		end
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("start: " .. top_kind .. " dz=" .. tostring(math.floor(top_dz or 0)) .. " support=" .. tostring(top_support or 0) .. " dist=" .. tostring(math.floor(obstacle_dist or 0)) .. " dur=" .. tostring(duration))
		end
		return {
			target_pos = top_target,
			obstacle_ray = obstacle_ray,
			obstacle_dist = obstacle_dist,
			arc_height = math.clamp(34 + math.max(top_dz or 0, low_furniture_clear_dz or 0) * 0.12, 38, 66),
			duration = duration,
			mode = "top",
			top_dz = top_dz or 0,
			skinny_top = skinny_top,
			low_furniture_top = low_furniture_top,
			rear_furniture_top = rear_furniture_top,
			rear_furniture_backrest_top = rear_furniture_backrest_top,
			low_furniture_clear_dz = low_furniture_clear_dz,
			low_furniture_backrest_dist = low_furniture_backrest_dist,
			wall_cap_top = wall_cap_top,
			low_upward_top = low_upward_top,
			forced_over_top = forced_over_top,
			crouch_mantle = crouch_mantle,
			target_forward = self:_pd3ms_forward_progress_from(pos, top_target, forward)
		}
	end

	self:_pd3ms_vault_log("reject: front hit but no supported top/landing")
	return nil
end

function PlayerStandard:_pd3ms_stop_running_for_vault(t)
	-- Vaulting/mantling should break sprint first. If we leave the run action active,
	-- Payday 2 can accept the mantle movement but keep/override the first-person run
	-- animation, which makes the grab redirect fail visually while sprinting.
	if not self._running then
		return
	end

	if self._interupt_action_running then
		pcall(function()
			self:_interupt_action_running(t or (managers.player and managers.player:player_timer():time()) or 0)
		end)
	end

	-- Be defensive for modded PlayerStandard states: make sure the run flags are clear
	-- before the interact/grab redirect is requested. Do not play stop_running here; that
	-- redirect can eat the mantle grab animation on the exact bug case we are fixing.
	self._running = nil
	self._start_running_t = nil
	self._last_run_t = t
end


function PlayerStandard:_pd3ms_stop_reload_for_vault(t)
	-- Mantle uses the normal interact/use redirect for the grab animation.
	-- PAYDAY 2 refuses that redirect while reload timers are active, so cancel
	-- the reload only after a valid mantle target has been accepted.
	if not self._is_reloading or not self:_is_reloading() then
		return false
	end

	if self._interupt_action_reload then
		local ok = pcall(function()
			self:_interupt_action_reload(t or (managers.player and managers.player:player_timer():time()) or 0)
		end)
		if ok then
			return true
		end
	end

	if self._state_data then
		self._state_data.reload_enter_expire_t = nil
		self._state_data.reload_expire_t = nil
		self._state_data.reload_exit_expire_t = nil
		self._state_data.reload_steelsight_expire_t = nil
	end

	return true
end

function PlayerStandard:_pd3ms_cancel_melee_for_vault(t)
	-- Mantling should own the first-person action. If a melee charge/swing is
	-- active, cancel it only after a valid mantle target has been accepted so a
	-- normal failed mantle probe does not eat melee input.
	local state_data = self._state_data
	if not state_data then
		return false
	end

	local is_meleeing = false
	if self._is_meleeing then
		local ok, result = pcall(function()
			return self:_is_meleeing()
		end)
		is_meleeing = ok and result == true
	end

	local had_melee = state_data.meleeing or state_data.melee_charge_wanted or state_data.melee_attack_wanted or state_data.melee_attack_allowed_t or state_data.melee_damage_delay_t or state_data.melee_expire_t or state_data.melee_repeat_expire_t or is_meleeing
	if not had_melee then
		return false
	end

	t = t or (managers.player and managers.player:player_timer():time()) or self._last_t or 0

	if self._interupt_action_melee then
		pcall(function()
			self:_interupt_action_melee(t)
		end)
	end

	state_data.meleeing = nil
	state_data.melee_charge_wanted = nil
	state_data.melee_attack_wanted = nil
	state_data.melee_attack_allowed_t = nil
	state_data.melee_damage_delay_t = nil
	state_data.melee_expire_t = nil
	state_data.melee_repeat_expire_t = nil
	state_data.melee_start_t = nil
	state_data.chainsaw_t = nil

	local camera_base = self._camera_unit and self._camera_unit.base and self._camera_unit:base()
	if camera_base and camera_base.unspawn_melee_item then
		pcall(function()
			camera_base:unspawn_melee_item()
		end)
	end

	return true
end

function PlayerStandard:_pd3ms_stop_stand_handoff_for_reload(t)
	-- The crouch->stand sprint handoff preserves the running viewmodel for a few
	-- frames. When reload is pressed without RUN_AND_RELOAD, release that guard
	-- and stop sprint immediately before vanilla starts reload, matching normal
	-- standing sprint timing.
	t = t or self._last_t or 0
	if self._pd3ms_release_stand_handoff_for_vanilla_action then
		self:_pd3ms_release_stand_handoff_for_vanilla_action()
	else
		self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
		self._pd3ms_preserved_run_stamina = nil
		self._pd3ms_crouch_sprint_toggled = nil
	end

	if self._interupt_action_running and self._running then
		pcall(function()
			self:_interupt_action_running(t)
		end)
	end

	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_preserved_run_stamina = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._running = nil
	self._running_wanted = false
	self._start_running_t = nil
	self._last_run_t = t
	self._running_sprintout_expire_t = nil
	if self._pd3ms_set_crouch_sprint_movement_running then
		self:_pd3ms_set_crouch_sprint_movement_running(false)
	end
	self._pd3ms_crouch_sprint_wait_for_run_release = nil
	return true
end

function PlayerStandard:_pd3ms_play_vault_anim(t, input)
	-- The normal interaction redirect is the closest built-in thing to the cash/jewelry/small-object
	-- grab motion. Prefer that over cash_inspect, which is weapon inspect in this setup.
	if self._play_interact_redirect then
		local ok = pcall(function()
			self:_play_interact_redirect(t or managers.player:player_timer():time(), input or {})
		end)
		if ok then
			return
		end
	end

	if not self._ext_camera or not self._ext_camera.play_redirect or not self.get_animation then
		return
	end

	for _, anim_name in ipairs(PD3MS_VAULT_ANIM_CANDIDATES) do
		local ok_anim, redirect = pcall(function()
			return self:get_animation(anim_name)
		end)
		if ok_anim and redirect then
			local ok_play = pcall(function()
				self._ext_camera:play_redirect(redirect, 1.45)
			end)
			if ok_play then
				return
			end
		end
	end
end

function PlayerStandard:_pd3ms_play_slide_sound(t)
	if not self._using_superblt then
		return
	end

	local sound_source = self._pd3ms_slide_sound_source or self._inf_sound
	if not sound_source then
		return
	end

	t = t or (managers.player and managers.player:player_timer():time()) or 0
	if self._last_pd3ms_slide_sound_t and (t - self._last_pd3ms_slide_sound_t) < 0.65 then
		return
	end

	self._last_pd3ms_slide_sound_t = t
	self._pd3ms_slide_sound_start_t = self._pd3ms_slide_sound_start_t or t

	local event_name = "pd3_slide_generic" .. tostring(math.random(1, 4))

	pcall(function()
		-- Dedicated player-positioned source for the Payday 3 slide one-shots.
		-- This replaces the older slide_enter + slide_loop spam system.
		if sound_source.set_position and self._unit and self._unit.position then
			sound_source:set_position(self._unit:position())
		end
		sound_source:post_event(event_name)
	end)
end

function PlayerStandard:_pd3ms_play_vault_sound(t)
	if ModernMovement.settings.mantlesound == false then
		return
	end

	if not self._using_superblt then
		return
	end

	local sound_source = self._pd3ms_mantle_sound_source or self._inf_sound
	if not sound_source then
		return
	end

	t = t or (managers.player and managers.player:player_timer():time()) or 0
	if self._last_pd3ms_mantle_sound_t and (t - self._last_pd3ms_mantle_sound_t) < 0.18 then
		return
	end

	self._last_pd3ms_mantle_sound_t = t
	local event_name = "mantle_grab" .. tostring(math.random(1, 4))

	pcall(function()
		-- Use a dedicated player-positioned source for mantle audio. Reusing the slide
		-- loop source made the custom event easy to lose or mix down too quietly.
		if sound_source.set_position and self._unit and self._unit.position then
			sound_source:set_position(self._unit:position())
		end
		sound_source:post_event(event_name)
	end)
end

function PlayerStandard:_pd3ms_player_foley_position()
	-- Use a body-centered position and keep it updated while the one-shot rings
	-- out. The previous camera-forward offset sounded OK while standing still,
	-- but because the sound source was fixed in world space after playback,
	-- strafing made it pan to the wrong ear.
	local pos = nil

	if alive(self._unit) then
		pos = mvector3.copy(self._unit:position())
		pos.z = pos.z + 110
	end

	if not pos and self._ext_camera and self._ext_camera.position then
		local ok, camera_pos = pcall(function()
			return self._ext_camera:position()
		end)
		if ok and camera_pos then
			pos = mvector3.copy(camera_pos)
		end
	end

	return pos
end

function PlayerStandard:_pd3ms_update_crouch_sound_source()
	local sound_source = self._pd3ms_crouch_sound_source or self._inf_sound
	if not sound_source or not sound_source.set_position then
		return
	end

	local pos = self:_pd3ms_player_foley_position()
	if pos then
		pcall(function()
			sound_source:set_position(pos)
		end)
	end
end

function PlayerStandard:_pd3ms_is_grounded_for_crouch_foley(t)
	if self._state_data then
		if self._state_data.in_air or self._state_data.on_ladder then
			return false
		end
	end

	-- Do not use mover:standing() here. In PAYDAY 2 it can be false while
	-- the player is legitimately crouched on the floor, which blocked the
	-- stand-up sound after landing from an airborne crouch. The player state's
	-- in_air/on_ladder flags are the safer grounded gate for this foley.
	return true
end

function PlayerStandard:_pd3ms_should_play_crouch_foley(t, direction)
	if not self._using_superblt then
		return false
	end

	if self._pd3ms_vaulting or self._is_sliding or self._slide_speed then
		return false
	end

	t = t or (managers.player and managers.player:player_timer():time()) or self._last_t or 0
	direction = direction or "down"

	if not self:_pd3ms_is_grounded_for_crouch_foley(t) then
		return false
	end

	-- Crouch-down needs the stricter jump/velocity filter so sprint-jump-crouch
	-- remains silent. Stand-up is allowed once the player is grounded again,
	-- even if the crouch-down happened in midair.
	if direction ~= "up" then
		if self._last_jump_t and (t - self._last_jump_t) < 0.22 then
			return false
		end

		if alive(self._unit) then
			local ok_vel, velocity = pcall(function()
				return self._unit:sampled_velocity()
			end)
			if ok_vel and velocity and math.abs(velocity.z or 0) > 80 then
				return false
			end
		end
	end

	return true
end

function PlayerStandard:_pd3ms_play_crouch_sound(t, direction)
	if not self._using_superblt then
		return
	end

	local sound_source = self._pd3ms_crouch_sound_source or self._inf_sound
	if not sound_source then
		return
	end

	t = t or (managers.player and managers.player:player_timer():time()) or 0
	if self._last_pd3ms_crouch_sound_t and (t - self._last_pd3ms_crouch_sound_t) < 0.20 then
		return
	end

	-- The same Payday 3 crouch foley pool is intentionally shared by crouch-down
	-- and stand-up, but only the two cleaner variants are registered.
	self._last_pd3ms_crouch_sound_t = t
	local event_name = "pd3_crouch_general" .. tostring(math.random(1, 2))

	pcall(function()
		self:_pd3ms_update_crouch_sound_source()
		sound_source:post_event(event_name)
	end)

	-- Follow the local player while the short one-shot decays so strafing does
	-- not leave the source behind in world space.
	self._pd3ms_crouch_sound_follow_until = t + 0.55
end

function PlayerStandard:_pd3ms_force_crouch_for_vault(t, transition)
	if not self._state_data then
		return
	end

	self._pd3ms_vault_forced_crouch = true
	if self._state_data.ducking then
		return
	end

	if self._start_action_ducking then
		local ok = pcall(function()
			self:_start_action_ducking(t or (managers.player and managers.player:player_timer():time()) or 0)
		end)
		if ok and self._state_data.ducking then
			return
		end
	end

	self._state_data.ducking = true
	if self._stance_entered then
		self:_stance_entered(nil, transition or 0.12)
	end
end

function PlayerStandard:_pd3ms_prepare_vault_points(vault, start_pos, forward)
	local target_pos = vault.target_pos
	local start_z = start_pos.z or 0
	local target_z = target_pos.z or start_z
	local obstacle_dist = math.clamp(vault.obstacle_dist or 48, 14, 104)

	-- Test2: the first build felt too poppy because the lift point overshot the lip,
	-- then the controller corrected downward/forward. Keep the same PD3-style strong early
	-- lift, but make the points form one continuous climb: up -> over lip -> settle.
	local lift_forward = vault.mode == "top" and math.min(2, obstacle_dist * 0.04) or math.min(5, obstacle_dist * 0.10)
	local lift_pos = self:_pd3ms_offset_from(start_pos, forward, lift_forward, 0, 0)

	if vault.mode == "top" then
		local dz = math.max(target_z - start_z, 0)
		if vault.rear_furniture_backrest_top then
			local high_backrest = dz >= 72
			lift_pos.z = math.max(start_z + (high_backrest and 58 or 48), target_z + (high_backrest and 16 or 12))
		elseif vault.rear_furniture_top then
			local clear_dz = math.max(vault.low_furniture_clear_dz or 0, dz)
			lift_pos.z = math.max(start_z + 42, target_z + 16, start_z + clear_dz + 9)
		elseif vault.crouch_mantle then
			lift_pos.z = math.max(start_z + 31, math.min(target_z + 7, start_z + 35 + dz * 0.48))
		elseif vault.skinny_top then
			lift_pos.z = math.max(start_z + 36, math.min(target_z + 10, start_z + 40 + dz * 0.48))
		else
			lift_pos.z = math.max(start_z + 35, math.min(target_z + 9, start_z + 38 + dz * 0.54))
		end
	else
		lift_pos.z = math.max(start_z + 36, math.min(target_z + 22, start_z + 52))
	end

	local lip_forward = math.max(8, obstacle_dist + (vault.mode == "top" and (vault.skinny_top and 3 or 10) or 20))
	if vault.rear_furniture_backrest_top and vault.target_forward then
		lip_forward = math.max(lip_forward, (vault.target_forward or 0) + ((vault.top_dz or 0) >= 72 and 3 or 5))
	elseif vault.rear_furniture_top and vault.target_forward then
		lip_forward = math.max(lip_forward, (vault.low_furniture_backrest_dist or 0) + 17, (vault.target_forward or 0) + 3)
	elseif vault.low_furniture_top and vault.target_forward then
		-- Front/normal bench-chair mantles only need to clear the near edge.
		-- Do not chase the deeper proof point during the lip phase, or the
		-- capsule can feel like it gets flung forward over the furniture.
		lip_forward = math.min(lip_forward, math.max((vault.obstacle_dist or 48) + 6, (vault.target_forward or 0) - 2))
	end
	local lip_pos = self:_pd3ms_offset_from(start_pos, forward, lip_forward, 0, 0)
	if vault.mode == "top" then
		if vault.rear_furniture_backrest_top then
			local high_backrest = (vault.top_dz or 0) >= 72
			lip_pos.z = math.max(target_z + (high_backrest and 18 or 14), lift_pos.z + 2)
		elseif vault.rear_furniture_top then
			lip_pos.z = math.max(target_z + 18, lift_pos.z + 2)
		elseif vault.crouch_mantle then
		lip_pos.z = math.max(target_z + 7, lift_pos.z + 2)
	else
			lip_pos.z = math.max(target_z + (vault.skinny_top and 10 or 12), lift_pos.z + 2)
		end
	else
		lip_pos.z = math.max(target_z + 23, lift_pos.z + 3)
	end

	local pull_pos = nil
	if vault.mode == "top" then
		local top_backoff = vault.skinny_top and -1 or ((vault.rear_furniture_backrest_top or vault.rear_furniture_top) and 2 or (vault.low_furniture_top and -12 or ((vault.low_upward_top or vault.forced_over_top) and 0 or -7)))
		pull_pos = self:_pd3ms_offset_from(target_pos, forward, top_backoff, 0, 0)
		if vault.rear_furniture_backrest_top then
			local high_backrest = (vault.top_dz or 0) >= 72
			pull_pos.z = math.max(target_z + (high_backrest and 9 or 5), lip_pos.z - (high_backrest and 24 or 28))
		elseif vault.rear_furniture_top then
			pull_pos.z = math.max(target_z + 7, lip_pos.z - 30)
		elseif vault.crouch_mantle then
			pull_pos.z = math.max(target_z + 3, lip_pos.z - 30)
		else
			pull_pos.z = math.max(target_z + (vault.skinny_top and 4 or 5), lip_pos.z - 28)
		end
	else
		pull_pos = self:_pd3ms_offset_from(target_pos, forward, -16, 0, 0)
		pull_pos.z = math.max(target_z + 6, lip_pos.z - 28)
	end

	return lift_pos, lip_pos, pull_pos
end

function PlayerStandard:_pd3ms_air_vault_enabled()
	return ModernMovement and ModernMovement.settings and ModernMovement.settings.airvaulting == true
end

function PlayerStandard:_pd3ms_clear_air_vault_probe_backoff()
	self._pd3ms_next_air_vault_prefilter_t = nil
	self._pd3ms_air_catch_next_full_probe_t = nil
	self._pd3ms_air_catch_fail_count = nil
	self._pd3ms_last_air_vault_probe_t = nil
	self._pd3ms_next_air_vault_broad_prefilter_t = nil
end

function PlayerStandard:_pd3ms_reset_air_vault_if_grounded(t)
	if not self._state_data then
		return
	end

	if self._state_data.in_air or self._pd3ms_vaulting or self:on_ladder() then
		self._pd3ms_air_vault_grounded_since = nil
		return
	end

	self:_pd3ms_clear_air_vault_probe_backoff()

	if not self._pd3ms_air_vault_used then
		self._pd3ms_air_vault_grounded_since = nil
		return
	end

	local jump_held = self._controller and self._controller:get_input_bool("jump") == true
	if jump_held then
		self._pd3ms_air_vault_grounded_since = nil
		return
	end

	t = t or self._last_t or 0
	self._pd3ms_air_vault_grounded_since = self._pd3ms_air_vault_grounded_since or t
	if (t - self._pd3ms_air_vault_grounded_since) >= PD3MS_AIR_CATCH_GROUND_RESET_TIME then
		self._pd3ms_air_vault_used = nil
		self._pd3ms_air_vault_grounded_since = nil
	end
end

function PlayerStandard:_pd3ms_air_vault_prefilter(pos, forward, t)
	if not pos or not forward then
		return false
	end

	local pos_x = pos.x
	local pos_y = pos.y
	local pos_z = pos.z
	local fwd_x = forward.x
	local fwd_y = forward.y
	local center_to_x = fwd_x * PD3MS_AIR_PREFLIGHT_CENTER_RANGE
	local center_to_y = fwd_y * PD3MS_AIR_PREFLIGHT_CENTER_RANGE
	local center_range_sq = PD3MS_AIR_PREFLIGHT_CENTER_RANGE * PD3MS_AIR_PREFLIGHT_CENTER_RANGE

	-- Common case: holding jump in open air. Check the center lane first with only
	-- three rays; do not enter the broader side preflight unless this timed cheap
	-- pass says it is due. Reuse ray vectors and compare squared distance to avoid
	-- extra garbage/sqrt work in the held-jump miss path.
	for _, height in ipairs(PD3MS_AIR_PREFLIGHT_CENTER_HEIGHTS) do
		local scan_z = pos_z + height
		local ray = self:_pd3ms_world_ray_xyz(
			pos_x,
			pos_y,
			scan_z,
			pos_x + center_to_x,
			pos_y + center_to_y,
			scan_z,
			true
		)

		if ray and ray.position then
			local dx = ray.position.x - pos_x
			local dy = ray.position.y - pos_y
			local dist_sq = (dx * dx) + (dy * dy)
			if dist_sq >= 16 and dist_sq <= center_range_sq then
				return true
			end
		end
	end

	t = t or self._last_t or 0
	if self._pd3ms_next_air_vault_broad_prefilter_t and t < self._pd3ms_next_air_vault_broad_prefilter_t then
		return false
	end
	self._pd3ms_next_air_vault_broad_prefilter_t = t + PD3MS_AIR_CATCH_BROAD_PREFLIGHT_INTERVAL

	local right_x = fwd_y
	local right_y = -fwd_x
	for _, height in ipairs(PD3MS_AIR_PREFLIGHT_SIDE_HEIGHTS) do
		local scan_z = pos_z + height
		for _, range in ipairs(PD3MS_AIR_PREFLIGHT_SIDE_RANGES) do
			local range_x = fwd_x * range
			local range_y = fwd_y * range
			for _, side in ipairs(PD3MS_AIR_PREFLIGHT_SIDE_OFFSETS) do
				local side_x = right_x * side
				local side_y = right_y * side
				local ray = self:_pd3ms_world_ray_xyz(
					pos_x + side_x,
					pos_y + side_y,
					scan_z,
					pos_x + range_x + side_x,
					pos_y + range_y + side_y,
					scan_z,
					true
				)

				if ray and ray.position then
					local dx = ray.position.x - pos_x
					local dy = ray.position.y - pos_y
					local dist_sq = (dx * dx) + (dy * dy)
					if dist_sq >= 16 and dist_sq <= 14400 then
						return true
					end
				end
			end
		end
	end

	return false
end

function PlayerStandard:_pd3ms_note_air_vault_scan_failed(t)
	local fail_count = math.min((self._pd3ms_air_catch_fail_count or 0) + 1, 4)
	self._pd3ms_air_catch_fail_count = fail_count

	local cooldown = math.min(PD3MS_AIR_CATCH_FAIL_COOLDOWN + ((fail_count - 1) * 0.10), PD3MS_AIR_CATCH_FAIL_COOLDOWN_MAX)
	self._pd3ms_air_catch_next_full_probe_t = (t or self._last_t or 0) + cooldown
	self._pd3ms_next_air_vault_prefilter_t = (t or self._last_t or 0) + PD3MS_AIR_CATCH_PREFLIGHT_INTERVAL
end

function PlayerStandard:_pd3ms_should_probe_air_vault(t)
	if not self._state_data or not self._state_data.in_air or not self:_pd3ms_air_vault_enabled() then
		self:_pd3ms_clear_air_vault_probe_backoff()
		return false
	end

	if self._pd3ms_vaulting or self._state_data.ducking or self._is_sliding or self:on_ladder() then
		return false
	end

	if self._pd3ms_air_vault_used then
		return false
	end

	if self._last_jump_t and (t - self._last_jump_t) < PD3MS_AIR_CATCH_JUMP_GRACE then
		return false
	end

	if not self._controller or not self._controller:get_input_bool("jump") then
		self:_pd3ms_clear_air_vault_probe_backoff()
		return false
	end

	if self._pd3ms_next_air_vault_prefilter_t and t < self._pd3ms_next_air_vault_prefilter_t then
		return false
	end

	return true
end

function PlayerStandard:_pd3ms_try_air_vault(t)
	if not self:_pd3ms_should_probe_air_vault(t) then
		return false
	end

	-- If a failed full scan already installed a cooldown, skip all preflight rays.
	-- v3 still paid the preflight cost during this window and then discarded it.
	if self._pd3ms_air_catch_next_full_probe_t and t < self._pd3ms_air_catch_next_full_probe_t then
		return false
	end

	if self._pd3ms_last_air_vault_probe_t and (t - self._pd3ms_last_air_vault_probe_t) < PD3MS_AIR_CATCH_PROBE_INTERVAL then
		return false
	end

	local forward = self:_pd3ms_flat_forward()
	if not self:_pd3ms_is_moving_forward(forward) then
		self._pd3ms_next_air_vault_prefilter_t = t + PD3MS_AIR_CATCH_PREFLIGHT_INTERVAL
		return false
	end

	local pos = self._unit:position()
	if not self:_pd3ms_air_vault_prefilter(pos, forward, t) then
		self._pd3ms_next_air_vault_prefilter_t = t + PD3MS_AIR_CATCH_PREFLIGHT_INTERVAL
		return false
	end

	self._pd3ms_last_air_vault_probe_t = t
	local started = self:_pd3ms_try_start_vault(t, {btn_jump_press = true, air_catch = true, precomputed_forward = forward})
	if started then
		self:_pd3ms_clear_air_vault_probe_backoff()
		return true
	end

	self:_pd3ms_note_air_vault_scan_failed(t)
	return false
end

function PlayerStandard:_pd3ms_try_start_vault(t, input)
	if ModernMovement.settings.vaulting == false then
		return false
	end

	local airborne = self._state_data and self._state_data.in_air
	if self._pd3ms_vaulting or self._state_data.ducking or self._is_sliding then
		return false
	end

	if self._pd3ms_air_vault_used then
		self:_pd3ms_vault_log("reject: air catch recovery active")
		return false
	end

	if airborne then
		if not self:_pd3ms_air_vault_enabled() then
			return false
		end

		if self._last_jump_t and (t - self._last_jump_t) < PD3MS_AIR_CATCH_JUMP_GRACE then
			return false
		end
	end

	if self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod() then
		return false
	end

	-- Allow mantling while carrying a bag. Carry weight already affects normal movement
	-- elsewhere; blocking vaults here made bag movement feel inconsistent.

	if self._last_vault_time and (t - self._last_vault_time) < 0.34 then
		return false
	end

	local forward = input and input.precomputed_forward or self:_pd3ms_flat_forward()
	if not self:_pd3ms_is_moving_forward(forward) then
		self:_pd3ms_vault_log("reject: not moving forward")
		return false
	end

	local air_catch_probe = airborne and input and input.air_catch == true
	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log(air_catch_probe and "=== air catch vault attempt ===" or "=== jump vault attempt ===")
	end
	local vault = self:_pd3ms_find_vault(forward, air_catch_probe)
	if not vault then
		self:_pd3ms_vault_log("=== jump vault result: vanilla jump / no mantle ===")
		return false
	end
	if self:_pd3ms_vault_debug_enabled() then
		self:_pd3ms_vault_log("=== jump vault result: accepted mode=" .. tostring(vault.mode) .. " top_dz=" .. tostring(math.floor(vault.top_dz or 0)) .. " dist=" .. tostring(math.floor(vault.obstacle_dist or 0)) .. " ===")
	end

	-- Stop sprint/reload/melee before starting the mantle so the grab/pickup-style
	-- redirect can play instead of being suppressed by another first-person action.
	self:_pd3ms_stop_running_for_vault(t)
	self:_pd3ms_stop_reload_for_vault(t)
	if self._pd3ms_cancel_melee_for_vault then
		self:_pd3ms_cancel_melee_for_vault(t)
	end

	self:_cancel_slide(1)
	local start_pos = mvector3.copy(self._unit:position())
	local lift_pos, lip_pos, pull_pos = self:_pd3ms_prepare_vault_points(vault, start_pos, forward)
	if airborne then
		self._pd3ms_air_vault_used = true
		self._pd3ms_air_vault_grounded_since = nil
	end
	self._pd3ms_vaulting = true
	self._pd3ms_vault = {
		start_t = t,
		phase_t = t,
		end_t = t + (vault.duration or 0.48),
		max_end_t = t + (vault.duration or 0.48) + ((vault.rear_furniture_backrest_top and (vault.top_dz or 0) >= 72) and 0.30 or 0.24),
		duration = vault.duration or 0.48,
		phase = "lift",
		start_pos = start_pos,
		target_pos = vault.target_pos,
		lift_pos = lift_pos,
		lip_pos = lip_pos,
		pull_pos = pull_pos,
		arc_height = vault.arc_height,
		mode = vault.mode or "top",
		forward = forward,
		obstacle_pos = vault.obstacle_ray and vault.obstacle_ray.position and mvector3.copy(vault.obstacle_ray.position) or nil,
		obstacle_dist = vault.obstacle_dist or 48,
		top_dz = vault.top_dz or 0,
		skinny_top = vault.skinny_top,
		low_furniture_top = vault.low_furniture_top,
		rear_furniture_top = vault.rear_furniture_top,
		rear_furniture_backrest_top = vault.rear_furniture_backrest_top,
		low_furniture_clear_dz = vault.low_furniture_clear_dz,
		low_furniture_backrest_dist = vault.low_furniture_backrest_dist,
		low_upward_top = vault.low_upward_top,
		forced_over_top = vault.forced_over_top,
		crouch_mantle = vault.crouch_mantle,
		target_forward = vault.target_forward,
		last_dist = nil,
		stall_t = 0
	}
	self._last_vault_time = t

	if vault.crouch_mantle then
		self:_pd3ms_force_crouch_for_vault(t, 0.08)
	end

	if self._unit:mover() then
		self._unit:mover():set_gravity(PD3MS_ZERO_VEC)
		self._unit:mover():set_velocity(PD3MS_ZERO_VEC)
	end

	self:_pd3ms_play_vault_anim(t, input)
	self:_pd3ms_play_vault_sound(t)
	self:_stance_entered(nil, 0.35)
	return true
end

function PlayerStandard:_pd3ms_end_vault(t, no_snap)
	local vault = self._pd3ms_vault
	self._pd3ms_vaulting = nil
	self._pd3ms_vault = nil

	if self._unit:mover() then
		self._unit:mover():set_gravity(PD3MS_NORMAL_GRAVITY)
		if vault and not no_snap then
			local current = self._unit:position()
			local delta = mvector3.copy(vault.target_pos)
			mvector3.subtract(delta, current)
			local dist = mvector3.normalize(delta)
			-- Keep normal mantles almost fully velocity-driven. Skinny rails get a slightly
			-- larger final settle because the collision is too narrow for the capsule to
			-- reliably land on from velocity alone.
			local settle_snap = vault.rear_furniture_backrest_top and ((vault.top_dz or 0) >= 72 and 18 or 14) or (vault.skinny_top and 20 or 6)
			if dist <= settle_snap then
				self:_pd3ms_apply_vault_position(vault.target_pos, PD3MS_ZERO_VEC, true)
				self._unit:mover():set_gravity(PD3MS_NORMAL_GRAVITY)
			end
		end
		if vault and vault.forward then
			-- Do not add an artificial forward push after the mantle/vault finishes.
			-- The visible travel already carries the player over the lip; forcing a
			-- fresh forward velocity here was the source of the "shoved forward" feel.
			self._unit:mover():set_velocity(PD3MS_ZERO_VEC)
		end
	end

	if vault and vault.crouch_mantle then
		self:_pd3ms_force_crouch_for_vault(t, 0.08)
	end

	self:_stance_entered(nil, 1)
end


function PlayerStandard:_pd3ms_abort_vault_for_state_change(t)
	local had_vault = self._pd3ms_vaulting or self._pd3ms_vault
	self._pd3ms_vaulting = nil
	self._pd3ms_vault = nil

	if not had_vault then
		return
	end

	if alive(self._unit) and self._unit.mover then
		local mover = self._unit:mover()
		if mover then
			mover:set_gravity(PD3MS_NORMAL_GRAVITY)
			mover:set_velocity(PD3MS_ZERO_VEC)
		end
	end

	if self._pd3ms_vault_log then
		self:_pd3ms_vault_log("abort: state changed during mantle")
	end
end

if Hooks and PlayerStandard.exit and not PlayerStandard._pd3ms_wrapped_vault_exit_cleanup then
	Hooks:PreHook(PlayerStandard, "exit", "pd3ms_cleanup_vault_on_exit", function(self, state_data, new_state_name)
		if self._pd3ms_abort_vault_for_state_change then
			local t = managers and managers.player and managers.player.player_timer and managers.player:player_timer():time() or 0
			self:_pd3ms_abort_vault_for_state_change(t)
		end
	end)

	PlayerStandard._pd3ms_wrapped_vault_exit_cleanup = true
end

function PlayerStandard:_pd3ms_drive_vault_toward(vault, target_pos, dt, speed, micro_step, vertical_only_micro, xy_scale)
	local current = self._unit:position()
	local delta = mvector3.copy(target_pos)
	mvector3.subtract(delta, current)

	if xy_scale and xy_scale ~= 1 then
		delta.x = delta.x * xy_scale
		delta.y = delta.y * xy_scale
	end

	local dist = mvector3.normalize(delta)
	if dist <= 0 then
		self:_pd3ms_set_vault_velocity(PD3MS_ZERO_VEC)
		return 0
	end

	-- Velocity servo instead of path snapping. The old Test1 servo drove at max speed almost
	-- until the exact target, which made phase changes feel snappy. This version eases velocity
	-- toward each phase target and only uses tiny position correction after a real stall.
	local gain = vault.mode == "top" and 10.2 or 10.8
	local command_speed = math.min(speed or 620, math.max(150, dist * gain))
	local vel = mvector3.copy(delta)
	mvector3.multiply(vel, command_speed)

	if vault.current_vel then
		local blend = math.clamp(dt * (vault.phase == "lift" and 23 or (vault.phase == "lip" and 20 or 17)), 0.30, 0.66)
		local smoothed = mvector3.copy(vault.current_vel)
		mvector3.multiply(smoothed, 1 - blend)
		local desired_part = mvector3.copy(vel)
		mvector3.multiply(desired_part, blend)
		mvector3.add(smoothed, desired_part)
		vel = smoothed
	end

	vault.current_vel = mvector3.copy(vel)
	self:_pd3ms_set_vault_velocity(vel)

	local real_delta = mvector3.copy(target_pos)
	mvector3.subtract(real_delta, current)
	local real_dist = mvector3.normalize(real_delta)
	if vault.last_dist and real_dist > (vault.last_dist - 0.65) then
		vault.stall_t = (vault.stall_t or 0) + dt
	else
		vault.stall_t = 0
	end
	vault.last_dist = real_dist

	-- No default per-frame correction anymore. That was the main source of the visible snap.
	if (vault.stall_t or 0) > 0.075 and (micro_step or 0) > 0 then
		local correction = micro_step
		if (vault.stall_t or 0) > 0.16 then
			correction = correction + 0.45
		end
		self:_pd3ms_micro_correct_vault(target_pos, correction, vertical_only_micro)
	end

	return real_dist
end

function PlayerStandard:_pd3ms_set_vault_phase(vault, phase, t)
	if vault.phase ~= phase then
		vault.phase = phase
		vault.phase_t = t
		vault.last_dist = nil
		vault.stall_t = 0
		vault.current_vel = nil
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("phase: " .. tostring(phase))
		end
	end
end

function PlayerStandard:_pd3ms_update_vault(t, dt)
	local vault = self._pd3ms_vault
	if not vault then
		self._pd3ms_vaulting = nil
		return
	end

	dt = math.max(dt or 0.016, 0.016)
	if vault.crouch_mantle then
		self:_pd3ms_force_crouch_for_vault(t, 0.05)
	end

	local current = self._unit:position()
	local phase_age = t - (vault.phase_t or vault.start_t or t)
	local target_z = vault.target_pos.z or current.z

	if vault.phase == "lift" then
		local lift_speed = vault.mode == "top" and 960 or 1040
		local lift_limit = vault.mode == "top" and math.max(0.105, (vault.duration or 0.48) * 0.24) or 0.095
		local lift_min = vault.mode == "top" and 0.040 or 0.035
		local lift_micro = vault.mode == "top" and 0.55 or 0.50
		local lift_xy = vault.mode == "top" and 0.05 or 0.04
		if vault.rear_furniture_backrest_top and (vault.top_dz or 0) >= 72 then
			lift_speed = 1180
			lift_limit = math.max(lift_limit, 0.18)
			lift_min = 0.055
			lift_micro = 0.72
			lift_xy = 0.02
		end
		local lift_dist = self:_pd3ms_drive_vault_toward(vault, vault.lift_pos, dt, lift_speed, lift_micro, true, lift_xy)
		if vault.rear_furniture_backrest_top and (vault.top_dz or 0) >= 72 then
			if phase_age >= lift_min and (current.z >= (vault.lift_pos.z - 6) or phase_age >= lift_limit) then
				self:_pd3ms_set_vault_phase(vault, "lip", t)
			end
		elseif phase_age >= lift_min and (current.z >= (vault.lift_pos.z - 7) or lift_dist <= 10 or phase_age >= lift_limit) then
			self:_pd3ms_set_vault_phase(vault, "lip", t)
		end
	elseif vault.phase == "lip" then
		local lip_speed = vault.mode == "top" and 1040 or 1140
		local lip_limit = vault.mode == "top" and math.max(0.125, (vault.duration or 0.48) * 0.27) or 0.105
		local lip_min = vault.mode == "top" and 0.050 or 0.040
		local lip_micro = vault.mode == "top" and 0.50 or 0.42
		local lip_xy = 0.96
		if vault.rear_furniture_backrest_top and (vault.top_dz or 0) >= 72 then
			lip_speed = 1180
			lip_limit = math.max(lip_limit, 0.20)
			lip_min = 0.060
			lip_micro = 0.58
			lip_xy = 0.88
		end
		local lip_dist = self:_pd3ms_drive_vault_toward(vault, vault.lip_pos, dt, lip_speed, lip_micro, false, lip_xy)
		local progress = self:_pd3ms_forward_progress_from(vault.start_pos, current, vault.forward)
		local needed = math.max(8, (vault.obstacle_dist or 48) + (vault.mode == "top" and 6 or 14))
		local required_z_extra = vault.crouch_mantle and 6 or (vault.mode == "top" and 12 or 8)
		if vault.rear_furniture_backrest_top and (vault.top_dz or 0) >= 72 then
			needed = math.max(8, (vault.obstacle_dist or 48) + 3)
			required_z_extra = 13
		end
		if phase_age >= lip_min and ((progress >= needed and current.z >= (target_z + required_z_extra)) or lip_dist <= 15 or phase_age >= lip_limit) then
			self:_pd3ms_set_vault_phase(vault, "pull", t)
		end
	elseif vault.phase == "pull" then
		local pull_speed = vault.mode == "top" and 940 or 1040
		local pull_limit = vault.mode == "top" and math.max(0.135, (vault.duration or 0.48) * 0.30) or 0.10
		local pull_min = vault.mode == "top" and 0.055 or 0.040
		-- Once the capsule is safely over the front lip, stop pulling hard toward the
		-- deeper scan target. The deeper target is useful for detection/clearance, but
		-- continuing to chase it is what reads as an artificial shove on low props.
		local pull_xy = vault.mode == "top" and (vault.skinny_top and 0.92 or 0.72) or 0.62
		if vault.rear_furniture_backrest_top then
			-- Rear bench/chair attempts are resolved onto the back/headrest top
			-- itself. Taller backs need a little more pull time, but avoid the old
			-- extreme profile that could pin the player against the collision.
			if (vault.top_dz or 0) >= 72 then
				pull_speed = 1120
				pull_min = 0.065
				pull_limit = math.max(pull_limit, 0.22)
			end
			pull_xy = math.max(pull_xy, 0.90)
			pull_limit = math.max(pull_limit, 0.18)
		elseif vault.rear_furniture_top then
			-- Rear bench/chair mantles first clear the taller backrest, then settle onto
			-- the lower seat. They need stronger XY commitment than a normal low-top
			-- mantle, otherwise the capsule can hit the backrest and look like it barely
			-- rises even though the low furniture target was selected correctly.
			pull_xy = math.max(pull_xy, 0.94)
			pull_limit = math.max(pull_limit, 0.19)
		elseif vault.low_upward_top or vault.forced_over_top then
			-- Low ledges/windows that used to choose the over-vault branch need more
			-- forward commitment than normal top mantles. Otherwise the animation starts,
			-- but the phase can finish after only clearing the front lip, before the
			-- player reaches the real supported landing. Keep it limited to verified
			-- low-upward/converted-over cases so regular top mantles stay unchanged.
			pull_xy = math.max(pull_xy, vault.forced_over_top and 0.94 or 0.88)
			pull_limit = math.max(pull_limit, vault.forced_over_top and 0.18 or 0.16)
		end
		local pull_dist = self:_pd3ms_drive_vault_toward(vault, vault.pull_pos, dt, pull_speed, vault.mode == "top" and 0.38 or 0.32, false, pull_xy)
		local progress = self:_pd3ms_forward_progress_from(vault.start_pos, current, vault.forward)
		local clear_extra = vault.mode == "top" and (vault.skinny_top and 3 or math.clamp(14 + math.max(vault.top_dz or 0, 0) * 0.035, 14, 22)) or 30
		if vault.rear_furniture_backrest_top and vault.target_forward then
			local target_based_extra = math.clamp((vault.target_forward or 0) - (vault.obstacle_dist or 48) + ((vault.top_dz or 0) >= 72 and 4 or 6), 6, 22)
			clear_extra = math.max(8, math.min(clear_extra, target_based_extra))
		elseif vault.rear_furniture_top and vault.target_forward then
			local target_based_extra = math.clamp((vault.target_forward or 0) - (vault.obstacle_dist or 48) + 6, 18, 46)
			clear_extra = math.max(clear_extra, target_based_extra)
		elseif vault.low_furniture_top and vault.target_forward then
			clear_extra = math.min(clear_extra, 10)
		elseif (vault.low_upward_top or vault.forced_over_top) and vault.target_forward then
			local target_based_extra = math.clamp((vault.target_forward or 0) - (vault.obstacle_dist or 48) - 10, 20, vault.forced_over_top and 52 or 42)
			clear_extra = math.max(clear_extra, target_based_extra)
		end
		local clear_progress = (vault.obstacle_dist or 48) + clear_extra

		local required_z_extra = vault.crouch_mantle and 2 or (vault.mode == "top" and 4 or 7)
		if progress >= clear_progress and current.z >= (target_z + required_z_extra) and phase_age >= pull_min then
			self:_pd3ms_set_vault_phase(vault, "settle", t)
		elseif phase_age >= pull_min and (pull_dist <= 12 or phase_age >= pull_limit) then
			self:_pd3ms_set_vault_phase(vault, "settle", t)
		end
	else
		-- Final settle should mostly drop the player onto the top surface, not
		-- keep steering them forward. Keep the original target for clearance, but
		-- heavily de-weight XY during this last phase so it does not read like a
		-- post-mantle shove.
		local settle_speed = vault.mode == "top" and 480 or 560
		local settle_limit = vault.mode == "top" and math.max(0.065, (vault.duration or 0.48) * 0.14) or 0.045
		local settle_min = vault.mode == "top" and 0.025 or 0.018
		local xy_settle = vault.mode == "top" and (vault.rear_furniture_backrest_top and 0.10 or ((vault.low_upward_top or vault.forced_over_top) and 0.12 or 0.025)) or 0.02
		local settle_dist = self:_pd3ms_drive_vault_toward(vault, vault.target_pos, dt, settle_speed, vault.mode == "top" and 0.12 or 0.09, false, xy_settle)
		if phase_age >= settle_min and (settle_dist <= 8 or phase_age >= settle_limit) then
			self:_pd3ms_end_vault(t, not (vault.skinny_top or vault.rear_furniture_backrest_top))
			return
		end
	end

	if t >= (vault.max_end_t or vault.end_t) then
		local remaining = self:_pd3ms_flat_distance_between(self._unit:position(), vault.target_pos)
		if self:_pd3ms_vault_debug_enabled() then
			self:_pd3ms_vault_log("end: timed out, flat_remaining=" .. tostring(math.floor(remaining or 0)))
		end
		self:_pd3ms_end_vault(t, true)
	end
end


function PlayerStandard:_check_action_jump(t, input)
	local new_action = nil
	local action_wanted = input.btn_jump_press

	if action_wanted then
		if self._pd3ms_vaulting then
			return true
		end

		local airborne = self._state_data and self._state_data.in_air
		local air_vault_allowed = airborne and self:_pd3ms_air_vault_enabled()
		local action_forbidden = self._jump_t and t < self._jump_t + 0.55
		action_forbidden = action_forbidden or self._unit:base():stats_screen_visible() or (airborne and not air_vault_allowed) or self:_interacting() or self:_on_zipline() or self:_does_deploying_limit_movement() or self:_is_using_bipod()

		local crouch_jump_disabled = (ModernMovement and ModernMovement.settings and ModernMovement.settings.crouchjump == false) or (AdvMov and AdvMov.settings and AdvMov.settings.crouchjump == false)

		if not action_forbidden and self:_pd3ms_try_start_vault(t, input) then
			new_action = true
		elseif not action_forbidden and not airborne then
			if self._state_data.ducking and crouch_jump_disabled then
				self:_end_action_ducking(t)
			else
				if self._state_data.on_ladder then
					self:_interupt_action_ladder(t)
				end

				local action_start_data = {}
				local jump_vel_z = tweak_data.player.movement_state.standard.movement.jump_velocity.z
				action_start_data.jump_vel_z = jump_vel_z

				if self._move_dir then
					local is_running = self._running and self._unit:movement():is_above_stamina_threshold() and t - self._start_running_t > 0.4
					local jump_vel_xy = tweak_data.player.movement_state.standard.movement.jump_velocity.xy[is_running and "run" or "walk"]
					action_start_data.jump_vel_xy = jump_vel_xy

					if is_running then
						self._unit:movement():subtract_stamina(tweak_data.player.movement_state.stamina.JUMP_STAMINA_DRAIN)
					end
				end

				--self._slide_has_played_shaker = nil -- play shaker again after landing
				new_action = self:_start_action_jump(t, action_start_data)
			end
		end
	end

	return new_action
end

function PlayerStandard:_cancel_slide(timemult)
	local was_sliding = self._is_sliding or self._slide_speed or self._slide_airborne_since or self._modernmovement_slide_viewmodel_restore
	if self._is_sliding and self._pd3ms_release_slide_running_stamina_lock then
		self:_pd3ms_release_slide_running_stamina_lock(self._last_t)
	end

	self._is_sliding = nil
	self._slide_speed = nil
	self._slide_airborne_since = nil
	self._slide_has_played_shaker = nil
	self._pd3ms_slide_sound_start_t = nil
	self._pd3ms_slide_extra_sound_played = nil

	if was_sliding then
		self:_modernmovement_restore_slide_viewmodel_stance()
		self:_stance_entered(nil, timemult or 1)
	end
end

Hooks:PostHook(PlayerStandard, "enter", "reset_pd3ms_enter", function(self, params)
	self:_cancel_slide()
	self._slide_end_speed = self:_get_modified_move_speed("crouch")/4 -- don't need to calculate every frame

	self._last_snd_slide_t = 0
	self._last_jump_t = 0

	self._last_slide_time = 0
	self._slide_airborne_since = nil
	self._pd3ms_vaulting = nil
	self._pd3ms_vault = nil
	self._last_vault_time = 0
	self._last_pd3ms_mantle_sound_t = 0
	self._last_pd3ms_slide_sound_t = 0
	self._last_pd3ms_crouch_sound_t = 0
	self._pd3ms_slide_sound_start_t = nil
	self._pd3ms_slide_extra_sound_played = nil
	self._pd3ms_crouch_sound_follow_until = nil
	self._pd3ms_last_grounded_crouch_foley_t = nil
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_sway_played = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprint_wait_for_run_release = nil
	self._pd3ms_crouch_sprint_steelsight_block_until_t = nil
	self._pd3ms_skip_stance_entered_for_crouch_sprint_stand = nil
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_last_crouch_slide_tap_t = nil
	self._pd3ms_air_vault_used = nil
	self._pd3ms_air_vault_grounded_since = nil
end)

Hooks:PostHook(PlayerStandard, "init", "reset_pd3ms_init", function(self, params)
	self._last_snd_slide_t = 0
	self._last_jump_t = 0

	self._last_slide_time = 0
	self._slide_airborne_since = nil
	self._pd3ms_vaulting = nil
	self._pd3ms_vault = nil
	self._last_vault_time = 0
	self._last_pd3ms_mantle_sound_t = 0
	self._last_pd3ms_slide_sound_t = 0
	self._last_pd3ms_crouch_sound_t = 0
	self._pd3ms_slide_sound_start_t = nil
	self._pd3ms_slide_extra_sound_played = nil
	self._pd3ms_crouch_sound_follow_until = nil
	self._pd3ms_last_grounded_crouch_foley_t = nil
	self._pd3ms_crouch_sprinting = nil
	self._pd3ms_crouch_sprint_anim_pending_t = nil
	self._pd3ms_crouch_sprint_anim_playing = nil
	self._pd3ms_crouch_sprint_handoff_until_t = nil
	self._pd3ms_holding_standing_crouch_sprint_stance = nil
	self._pd3ms_crouch_sprint_toggled = nil
	self._pd3ms_crouch_sprint_wait_for_run_release = nil
	self._pd3ms_crouch_sprint_steelsight_block_until_t = nil
	self._pd3ms_skip_stance_entered_for_crouch_sprint_stand = nil
	self._pd3ms_crouch_sprint_stand_handoff_until_t = nil
	self._pd3ms_last_crouch_slide_tap_t = nil

	if blt and blt.xaudio then
		self._using_superblt = true
	end
	if self._using_superblt then
		self._inf_sound = SoundDevice:create_source("inf_sounds")
		self._pd3ms_slide_sound_source = SoundDevice:create_source("pd3ms_player_slide_sounds")
		self._pd3ms_mantle_sound_source = SoundDevice:create_source("pd3ms_player_mantle_sounds")
		self._pd3ms_crouch_sound_source = SoundDevice:create_source("pd3ms_player_crouch_sounds")
		--self._inf_sound:set_position(managers.player:player_unit():position())
	end
end)


function PlayerStandard:_check_step(t)
	-- don't make footstep noises while airborne or sliding
	if self._state_data.in_air or self._is_sliding then
		return
	end

	self._last_step_pos = self._last_step_pos or Vector3()
	local step_length = self._state_data.on_ladder and 50 or self._state_data.in_steelsight and (managers.player:has_category_upgrade("player", "steelsight_normal_movement_speed") and 150 or 100) or self._state_data.ducking and 125 or self._running and 175 or 150

	if mvector3.distance_sq(self._last_step_pos, self._pos) > step_length * step_length then
		mvector3.set(self._last_step_pos, self._pos)
		self._unit:base():anim_data_clbk_footstep()
	end
end



Hooks:PostHook(PlayerStandard, "_calculate_standard_variables", "wtfismyrealspeed", function(self, t, dt)
	if self._is_sliding or self._pd3ms_vaulting then
		self._last_speed = mvector3.normalize(self._unit:sampled_velocity())
	end
	-- cannot trust last_velocity_xy
end)

Hooks:PostHook(PlayerStandard, "_start_action_jump", "set_jump_var_plox", function(self, t, action_start_data)
	self._last_jump_t = t
end)

--[[
function PlayerStandard:_get_ground_normal()
	local playerpos = mvector3.copy(managers.player:player_unit():position())
	local downpos = mvector3.copy(managers.player:player_unit():position() + Vector3(0, 0, -40))
	return ground_ray = Utils:GetCrosshairRay(playerpos, downpos)	
end
--]]
