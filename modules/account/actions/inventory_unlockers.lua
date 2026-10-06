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

local _forbids_backup = {}
local function apply_mod_limits(state)
    local factory = tweak_data and tweak_data.weapon and tweak_data.weapon.factory
    if not factory or not factory.parts then return end
    
    if state then
        for part_id, part in pairs(factory.parts) do
            if part.forbids then
                _forbids_backup[part_id] = part.forbids
                part.forbids = nil
            end
        end
    else
        for part_id, forbids in pairs(_forbids_backup) do
            if factory.parts[part_id] then
                factory.parts[part_id].forbids = forbids
            end
        end
        _forbids_backup = {}
    end
end

if _G.WeaponFactoryTweakData then
    Hooks:PostHook(WeaponFactoryTweakData, "init", "NiceTrainer_ModLimitTweak", function(self)
        if is_no_mod_limit_enabled() then
            -- Atrasar a remoção para garantir que o tweak data termine de inicializar outras dependências
            DelayedCalls:Add("NiceTrainer_ModLimit_Delay", 0.1, function()
                apply_mod_limits(true)
            end)
        end
    end)
end

-- Tentar aplicar imediatamente caso o jogo já tenha carregado o tweak_data
if tweak_data and tweak_data.weapon and tweak_data.weapon.factory then
    if is_no_mod_limit_enabled() then
        apply_mod_limits(true)
    end
end

-- Fix de Softlock: Evitar engine freeze do Payday 2 ao tentar renderizar peças forçadas em nodes 3D inexistentes (ex: silenciador na Judge)
if _G.WeaponFactoryManager and not _G.WeaponFactoryManager._nt_softlock_hooked then
    _G.WeaponFactoryManager._nt_softlock_hooked = true
    local orig_spawn_and_link_unit = WeaponFactoryManager._spawn_and_link_unit
    function WeaponFactoryManager:_spawn_and_link_unit(u_name, a_obj, third_person, link_to_unit, ...)
        if link_to_unit and a_obj then
            local id_a_obj = type(a_obj) == "string" and Idstring(a_obj) or a_obj
            -- Se a peça base (cano/arma) não possuir o ponto de encaixe (node 3D) que esse mod exige, o motor do jogo congela.
            -- Para evitar isso, redirecionamos o encaixe para a raiz da arma caso o node falte.
            if not link_to_unit:get_object(id_a_obj) then
                a_obj = link_to_unit:orientation_object():name()
            end
        end
        return orig_spawn_and_link_unit(self, u_name, a_obj, third_person, link_to_unit, ...)
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
        apply_mod_limits(state)
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
