-- Modern Movement: tased-state mantle safety.
-- Mantle movement owns the mover while active by disabling gravity and driving
-- velocity. A tase can switch state in the middle of that ownership handoff, so
-- reset only when this mod had movement ownership instead of touching every tase.

local PD3MS_NORMAL_GRAVITY = Vector3(0, 0, -982)
local PD3MS_ZERO_VELOCITY = Vector3(0, 0, 0)

local function pd3ms_had_mod_movement(self)
	return self and (
		self._pd3ms_vaulting
		or self._pd3ms_vault
		or self._is_sliding
		or self._is_wallrunning
		or self._is_wallkicking
		or self._wallkick_is_clinging
	)
end

local function pd3ms_reset_mantle_mover_for_tase(self)
	local had_mod_movement = pd3ms_had_mod_movement(self)

	self._pd3ms_vaulting = nil
	self._pd3ms_vault = nil
	self._is_sliding = nil
	self._is_wallrunning = nil
	self._is_wallkicking = nil
	self._wallkick_is_clinging = nil
	self._slide_airborne_since = nil

	if not had_mod_movement then
		return
	end

	if self._unit and self._unit.mover then
		local mover = self._unit:mover()
		if mover then
			mover:set_gravity(PD3MS_NORMAL_GRAVITY)
			mover:set_velocity(PD3MS_ZERO_VELOCITY)
		end
	end
end

local function pd3ms_install_tased_cleanup()
	if not PlayerTased or not PlayerTased.enter then
		return
	end

	if PlayerTased._pd3ms_wrapped_tased_enter == PlayerTased.enter then
		return
	end

	local original_enter = PlayerTased.enter
	PlayerTased.enter = function(self, state_data, enter_data, ...)
		pd3ms_reset_mantle_mover_for_tase(self)
		local result = original_enter(self, state_data, enter_data, ...)
		pd3ms_reset_mantle_mover_for_tase(self)
		return result
	end

	PlayerTased._pd3ms_wrapped_tased_enter = PlayerTased.enter
end

pd3ms_install_tased_cleanup()

if DelayedCalls then
	DelayedCalls:Add("ModernMovementTasedCleanup0", 0, pd3ms_install_tased_cleanup)
	DelayedCalls:Add("ModernMovementTasedCleanup1", 0.25, pd3ms_install_tased_cleanup)
	DelayedCalls:Add("ModernMovementTasedCleanup2", 1.0, pd3ms_install_tased_cleanup)
end
