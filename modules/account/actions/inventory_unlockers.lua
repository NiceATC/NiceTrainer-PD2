-- ─── Inventory & Crew Unlockers for NiceTrainer ───────────────────────────────
-- Features: Crew Boosts/Abilities Unlocker, Unlock 500 Inventory Slots,
-- No Weapon Mod Restrictions, and Free Black Market purchases.

-- ============================================================================
-- 1. Crew Abilities & Boosts Unlocker
-- ============================================================================
local function is_crew_unlocker_enabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.crew_unlocker == true
end

if _G.BlackMarketManager and not _G.BlackMarketManager._nt_crew_hooked then
    _G.BlackMarketManager._nt_crew_hooked = true
    local orig_is_crew_item_unlocked = BlackMarketManager.is_crew_item_unlocked
    function BlackMarketManager:is_crew_item_unlocked(...)
        if is_crew_unlocker_enabled() then
            return true
        end
        return orig_is_crew_item_unlocked(self, ...)
    end
end

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Unlockers & Protection",
    badge    = "client",
    no_bind  = true,
    id       = "crew_unlocker",
    text     = "Unlock Crew Abilities & Boosts",
    tooltip  = "Forces all AI crew abilities and crew boosts to be permanently unlocked and selectable.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.crew_unlocker = state
        NiceTrainer:Save()
    end
})

-- ============================================================================
-- 2. Unlock 500 Inventory Slots (Masks, Primaries, Secondaries)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Unlockers & Protection",
    badge           = "client",
    no_bind         = true,
    id              = "unlock_all_slots",
    text            = "Unlock All Inventory Slots (500)",
    tooltip         = "Unlocks 500 weapon (primary/secondary) and mask slots in your Black Market inventory for free.",
    action_btn_text = "Unlock",
    callback        = function()
        if not (Global.blackmarket_manager and Global.blackmarket_manager.unlocked_weapon_slots) then
            NiceTrainer:Toast("Inventory not loaded. Open inventory or Crime.net first.")
            return
        end
        local bm = Global.blackmarket_manager
        bm.unlocked_mask_slots = bm.unlocked_mask_slots or {}
        bm.unlocked_weapon_slots = bm.unlocked_weapon_slots or {}
        bm.unlocked_weapon_slots.primaries = bm.unlocked_weapon_slots.primaries or {}
        bm.unlocked_weapon_slots.secondaries = bm.unlocked_weapon_slots.secondaries or {}

        for i = 1, 500 do
            bm.unlocked_mask_slots[i] = true
            bm.unlocked_weapon_slots.primaries[i] = true
            bm.unlocked_weapon_slots.secondaries[i] = true
        end
        NiceTrainer:Toast("500 Inventory Slots unlocked successfully!")
    end
})

-- ============================================================================
-- 3. No Weapon Mod Restrictions (No Incompatibilities)
-- ============================================================================
local function is_no_mod_limit_enabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.no_weap_mod_limit == true
end

if _G.BlackMarketManager and not _G.BlackMarketManager._nt_mod_limit_hooked then
    _G.BlackMarketManager._nt_mod_limit_hooked = true
    local orig_get_modify_weapon_consequence = BlackMarketManager.get_modify_weapon_consequence
    function BlackMarketManager:get_modify_weapon_consequence(...)
        if is_no_mod_limit_enabled() then
            return {}, {}
        end
        return orig_get_modify_weapon_consequence(self, ...)
    end
end

if _G.WeaponFactoryManager and not _G.WeaponFactoryManager._nt_mod_limit_hooked then
    _G.WeaponFactoryManager._nt_mod_limit_hooked = true
    local orig_change_part_blueprint_only = WeaponFactoryManager.change_part_blueprint_only
    function WeaponFactoryManager:change_part_blueprint_only(factory_id, part_id, blueprint, remove_part, ...)
        if is_no_mod_limit_enabled() then
            local factory = tweak_data.weapon.factory
            local part = factory and factory.parts and factory.parts[part_id]
            if not part then return false end
            table.insert(blueprint, part_id)
            return true
        end
        return orig_change_part_blueprint_only(self, factory_id, part_id, blueprint, remove_part, ...)
    end
end

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Unlockers & Protection",
    badge    = "safe",
    no_bind  = true,
    id       = "no_weap_mod_limit",
    text     = "No Weapon Mod Restrictions",
    tooltip  = "Allows equipping any weapon modification simultaneously without part conflict limits.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.no_weap_mod_limit = state
        NiceTrainer:Save()
    end
})

-- ============================================================================
-- 4. Free Black Market Purchases
-- ============================================================================
local function is_free_market_enabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.free_blackmarket == true
end

if _G.MoneyManager and not _G.MoneyManager._nt_freemarket_hooked then
    _G.MoneyManager._nt_freemarket_hooked = true

    local o_skillpoint_cost = MoneyManager.get_skillpoint_cost
    function MoneyManager:get_skillpoint_cost(...)
        if is_free_market_enabled() then return 0 end
        return o_skillpoint_cost(self, ...)
    end

    local o_respec_cost = MoneyManager.get_skilltree_respec_cost
    if o_respec_cost then
        function MoneyManager:get_skilltree_respec_cost(...)
            if is_free_market_enabled() then return 0 end
            return o_respec_cost(self, ...)
        end
    end

    local o_contract_cost = MoneyManager.get_cost_of_premium_contract
    function MoneyManager:get_cost_of_premium_contract(...)
        if is_free_market_enabled() then return 0 end
        return o_contract_cost(self, ...)
    end

    local o_weapon_price = MoneyManager.get_weapon_price
    function MoneyManager:get_weapon_price(...)
        if is_free_market_enabled() then return 0 end
        return o_weapon_price(self, ...)
    end

    local o_weapon_mod_price = MoneyManager.get_weapon_modify_price
    function MoneyManager:get_weapon_modify_price(...)
        if is_free_market_enabled() then return 0 end
        return o_weapon_mod_price(self, ...)
    end

    local o_mask_slot_price = MoneyManager.get_buy_mask_slot_price
    function MoneyManager:get_buy_mask_slot_price(...)
        if is_free_market_enabled() then return 0 end
        return o_mask_slot_price(self, ...)
    end

    local o_weap_slot_price = MoneyManager.get_buy_weapon_slot_price
    function MoneyManager:get_buy_weapon_slot_price(...)
        if is_free_market_enabled() then return 0 end
        return o_weap_slot_price(self, ...)
    end

    local o_mask_part_price = MoneyManager.get_mask_part_price_modified
    function MoneyManager:get_mask_part_price_modified(...)
        if is_free_market_enabled() then return 0 end
        return o_mask_part_price(self, ...)
    end

    local o_mask_craft_price = MoneyManager.get_mask_crafting_price_modified
    function MoneyManager:get_mask_crafting_price_modified(...)
        if is_free_market_enabled() then return 0 end
        return o_mask_craft_price(self, ...)
    end
end

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Unlockers & Protection",
    badge    = "client",
    no_bind  = true,
    id       = "free_blackmarket",
    text     = "Free Black Market Purchases",
    tooltip  = "Sets the purchase cost of all weapons, weapon modifications, masks, slots, and contract fees to $0.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.free_blackmarket = state
        NiceTrainer:Save()
    end
})
