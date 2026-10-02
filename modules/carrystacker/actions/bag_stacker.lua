-- ─── Infinite Bag Carry & Bag Stacker ──────────────────────────────────────────
-- Allows picking up and carrying unlimited loot bags simultaneously.

local BagIcon = "pd2_loot"

NiceTrainer._cs = NiceTrainer._cs or {
    bags = {},
    bagType = "light",
}
local cs = NiceTrainer._cs

local function cs_refresh_hud()
    if not (managers and managers.hud) then return end
    local count = #cs.bags + ((managers.player and managers.player:is_carrying()) and 1 or 0)
    pcall(function()
        managers.hud:remove_special_equipment("carrystacker")
        if count > 0 then
            managers.hud:add_special_equipment({ id = "carrystacker", icon = BagIcon, amount = count })
        end
    end)
end

-- ============================================================================
-- Core Hooks
-- ============================================================================
local function apply_bag_stacker_hooks()
    if _G.PlayerManager and not PlayerManager._nt_bag_stacker_hooked then
        PlayerManager._nt_bag_stacker_hooked = true

        local orig_set_carry        = PlayerManager.set_carry
        local orig_drop_carry       = PlayerManager.drop_carry
        local orig_force_drop_carry = PlayerManager.force_drop_carry

        function PlayerManager:set_carry(carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier, _nt_skip_stack)
            if NiceTrainer.Settings.bag_stacker_enabled and not _nt_skip_stack then
                if self:is_carrying() then
                    local current = self:get_my_carry_data()
                    if current and current.carry_id then
                        table.insert(cs.bags, {
                            carry_id             = current.carry_id,
                            multiplier           = current.multiplier or carry_multiplier or 1,
                            value                = current.value or 100,
                            dye_initiated        = current.dye_initiated or dye_initiated,
                            has_dye_pack         = current.has_dye_pack or has_dye_pack,
                            dye_value_multiplier = current.dye_value_multiplier or dye_value_multiplier or 1,
                        })
                    end
                end
            end

            orig_set_carry(self, carry_id, carry_multiplier, dye_initiated, has_dye_pack, dye_value_multiplier)

            -- Ensure client movement restriction is cleared immediately
            if Network:is_client() then
                local player = self:player_unit()
                if alive(player) and player:movement() and player:movement().set_carry_restriction then
                    pcall(function() player:movement():set_carry_restriction(false) end)
                end
            end

            cs_refresh_hud()
        end

        function PlayerManager:drop_carry(zipline_unit)
            orig_drop_carry(self, zipline_unit)

            if NiceTrainer.Settings.bag_stacker_enabled and #cs.bags > 0 then
                local next_bag = table.remove(cs.bags)
                if next_bag then
                    self:set_carry(next_bag.carry_id, next_bag.multiplier or 1, next_bag.dye_initiated, next_bag.has_dye_pack, next_bag.dye_value_multiplier, true)
                end
            end

            cs_refresh_hud()
        end

        function PlayerManager:force_drop_carry(...)
            if NiceTrainer.Settings.bag_stacker_enabled and #cs.bags > 0 then
                while self:is_carrying() do
                    orig_force_drop_carry(self, ...)
                    if #cs.bags > 0 then
                        local next_bag = table.remove(cs.bags)
                        if next_bag then
                            self:set_carry(next_bag.carry_id, next_bag.multiplier or 1, next_bag.dye_initiated, next_bag.has_dye_pack, next_bag.dye_value_multiplier, true)
                        end
                    end
                end
                cs.bags = {}
                cs_refresh_hud()
                return
            end

            orig_force_drop_carry(self, ...)
            cs_refresh_hud()
        end
    end

    if _G.PlayerMovement and not PlayerMovement._nt_bag_stacker_hooked then
        PlayerMovement._nt_bag_stacker_hooked = true
        local orig_has_carry = PlayerMovement.has_carry_restriction
        function PlayerMovement:has_carry_restriction()
            if NiceTrainer.Settings.bag_stacker_enabled then
                return false
            end
            return orig_has_carry and orig_has_carry(self) or self._carry_restricted
        end
    end

    if _G.CarryInteractionExt and not CarryInteractionExt._nt_bag_stacker_hooked then
        CarryInteractionExt._nt_bag_stacker_hooked = true

        local orig_can_select = CarryInteractionExt.can_select
        function CarryInteractionExt:can_select(player)
            if NiceTrainer.Settings.bag_stacker_enabled then
                if (managers.player and managers.player:carry_blocked_by_cooldown()) or (self._unit:carry_data() and self._unit:carry_data():is_attached_to_zipline_unit()) then
                    return false
                end
                return CarryInteractionExt.super.can_select(self, player)
            end
            return orig_can_select(self, player)
        end

        local orig_interact_blocked = CarryInteractionExt._interact_blocked
        function CarryInteractionExt:_interact_blocked(player)
            if NiceTrainer.Settings.bag_stacker_enabled then
                local cd = self._unit:carry_data()
                local silent_block = (managers.player and managers.player:carry_blocked_by_cooldown()) or (cd and cd:is_attached_to_zipline_unit())
                if silent_block then
                    return true, silent_block
                end
                return false
            end
            return orig_interact_blocked(self, player)
        end
    end

    if _G.IntimitateInteractionExt and not IntimitateInteractionExt._nt_bag_stacker_hooked then
        IntimitateInteractionExt._nt_bag_stacker_hooked = true

        local orig_intim_can_select = IntimitateInteractionExt.can_select
        function IntimitateInteractionExt:can_select(player)
            if self.tweak_data == "corpse_dispose" then
                if NiceTrainer.Settings.infinite_body_bags then
                    if NiceTrainer.Settings.bag_stacker_enabled then
                        return true
                    else
                        return not (managers.player and managers.player:is_carrying())
                    end
                end
                if NiceTrainer.Settings.bag_stacker_enabled then
                    local has_bags = managers.player and (managers.player:has_total_body_bags() or not managers.player:chk_body_bags_depleted())
                    return has_bags and true or false
                end
            end
            return orig_intim_can_select and orig_intim_can_select(self, player)
        end

        local orig_intim_blocked = IntimitateInteractionExt._interact_blocked
        function IntimitateInteractionExt:_interact_blocked(player)
            if self.tweak_data == "corpse_dispose" then
                if NiceTrainer.Settings.infinite_body_bags then
                    if not NiceTrainer.Settings.bag_stacker_enabled and managers.player and managers.player:is_carrying() then
                        return true, nil, "body_bag_carrying_blocked"
                    end
                    return false
                end
                if NiceTrainer.Settings.bag_stacker_enabled then
                    local has_bags = managers.player and (managers.player:has_total_body_bags() or not managers.player:chk_body_bags_depleted())
                    if not has_bags then
                        return true, nil, "body_bag_limit_reached"
                    end
                    return false
                end
            end
            return orig_intim_blocked and orig_intim_blocked(self, player)
        end
    end
end

-- Apply on boot and on game/heist load
apply_bag_stacker_hooks()

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_BagStacker_LevelLoad", function()
    apply_bag_stacker_hooks()
    cs.bags = {}
    cs_refresh_hud()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_BagStacker_GameUpdate", function()
    apply_bag_stacker_hooks()
end)

-- ============================================================================
-- Registrations (CarryStacker Tab -> Bags)
-- ============================================================================

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Bags",
    badge    = "client",
    id       = "bag_stacker_enabled",
    text     = "Infinite Bag Carry",
    tooltip  = "Stack unlimited loot bags on your back. Pick up any new bag without dropping existing ones.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.bag_stacker_enabled = state
        NiceTrainer:Save()
        if not state then
            cs.bags = {}
            cs_refresh_hud()
        end
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "button",
    category = "Bags",
    badge    = "client",
    text     = "Drop All Bags",
    tooltip  = "Instantly throws and drops all bags currently in your stack onto the ground.",
    callback = function()
        if not managers.player then return end
        local count = #cs.bags + (managers.player:is_carrying() and 1 or 0)
        if count > 0 then
            managers.player:force_drop_carry()
            NiceTrainer:Toast("Dropped " .. count .. " bags!")
        else
            NiceTrainer:Toast("No bags in stack.")
        end
    end
})
