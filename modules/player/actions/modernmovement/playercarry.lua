-- Modern Movement: bag-drop / mantle safety guard.
-- PAYDAY 2's carry state checks jump/mantle before it checks bag-drop input.
-- If the player releases the bag key on the same frame a mantle starts, the carry
-- state can switch out while the mantle controller has gravity disabled and an
-- upward velocity command active. Consume bag-drop input during the active mantle;
-- the player can drop normally again as soon as the mantle finishes.

if PlayerCarry and PlayerCarry._check_use_item and not PlayerCarry._pd3ms_wrapped_mantle_bag_drop_guard then
	local pd3ms_original_playercarry_check_use_item = PlayerCarry._check_use_item

	PlayerCarry._check_use_item = function(self, t, input, ...)
		if self._pd3ms_vaulting or self._pd3ms_vault then
			self._throw_down = nil
			self._second_press = nil
			self._throw_time = nil

			if input then
				input.btn_use_item_press = false
				input.btn_use_item_release = false
				input.btn_use_item_state = false
			end

			if self._pd3ms_vault_log then
				self:_pd3ms_vault_log("bag drop ignored: mantle active")
			end

			return true
		end

		return pd3ms_original_playercarry_check_use_item(self, t, input, ...)
	end

	PlayerCarry._pd3ms_wrapped_mantle_bag_drop_guard = true
end
