-- ─── Skin Unlocker (Pure TweakData Method) ──────────────────────────────────

local skinOriginals = {}

local function applySkinUnlockState(value)
    local weapon_skins = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins
    if weapon_skins then
        for id, data in pairs(weapon_skins) do
            if not string.find(id, "color") and not data.is_template then
                if not skinOriginals[id] then
                    skinOriginals[id] = {
                        locked = data.locked,
                        is_a_unlockable = data.is_a_unlockable,
                        skip_cheat_verification = data.skip_cheat_verification,
                        is_marketable = data.is_marketable
                    }
                end
                
                if value then
                    data.locked = false
                    data.is_a_unlockable = true
                    data.skip_cheat_verification = true
                    data.is_marketable = true
                else
                    data.locked = skinOriginals[id].locked
                    data.is_a_unlockable = skinOriginals[id].is_a_unlockable
                    data.skip_cheat_verification = skinOriginals[id].skip_cheat_verification
                    data.is_marketable = skinOriginals[id].is_marketable
                end
            end
        end
    end

    local armor_skins = tweak_data and tweak_data.economy and tweak_data.economy.armor_skins
    if armor_skins then
        for id, data in pairs(armor_skins) do
            if not skinOriginals["armor_" .. id] then
                skinOriginals["armor_" .. id] = {
                    free = data.free,
                    unlocked = data.unlocked,
                }
            end
            if value then
                data.free = true
                data.unlocked = true
            else
                data.free = skinOriginals["armor_" .. id].free
                data.unlocked = skinOriginals["armor_" .. id].unlocked
            end
        end
    end

    local safes = tweak_data and tweak_data.economy and tweak_data.economy.safes
    if safes then
        for id, safe in pairs(safes) do
            if not skinOriginals["safe_" .. id] then
                skinOriginals["safe_" .. id] = {
                    market_link = safe.market_link
                }
            end
            if value then
                safe.market_link = safe.market_link or "Fake Link"
            else
                safe.market_link = skinOriginals["safe_" .. id].market_link
            end
        end
    end

    if not value then return end
    local crafted = managers.blackmarket and managers.blackmarket._global and managers.blackmarket._global.crafted_items
    if crafted then
        for _, category in ipairs({"primaries", "secondaries"}) do
            for _, weapon in pairs(crafted[category] or {}) do
                if weapon.cosmetics then weapon.customize_locked = nil end
            end
        end
    end
end

if _G.BlackMarketManager then
    Hooks:PostHook(BlackMarketManager, "on_equip_weapon_cosmetics", "NiceTrainer_SkinUnlock_StatBoostFix", function(self, category, slot, instance_id)
        if NiceTrainer.Settings.skin_unlocker then
            local weapon = self._global.crafted_items and self._global.crafted_items[category] and self._global.crafted_items[category][slot]
            if weapon and weapon.cosmetics then
                local td = tweak_data.blackmarket.weapon_skins[weapon.cosmetics.id]
                if td and td.bonus then
                    weapon.cosmetics.bonus = true
                end
            end
        end
    end)

    local old_get_item_amount = BlackMarketManager.get_item_amount
    BlackMarketManager.get_item_amount = function(self, global_value, category, id, ...)
        if NiceTrainer.Settings.skin_unlocker and category == "weapon_skins" then
            return 1
        end
        return old_get_item_amount(self, global_value, category, id, ...)
    end

    local old_has_item = BlackMarketManager.has_item
    BlackMarketManager.has_item = function(self, global_value, category, id, ...)
        if NiceTrainer.Settings.skin_unlocker and category == "weapon_skins" then
            return true
        end
        return old_has_item(self, global_value, category, id, ...)
    end

    Hooks:PostHook(BlackMarketManager, "init_finalize", "NiceTrainer_SkinUnlockInit", function()
        if NiceTrainer.Settings.skin_unlocker then
            applySkinUnlockState(true)
        end
    end)
end

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Unlockers & Protection",
    badge    = "safe",
    no_bind  = true,
    id       = "skin_unlocker",
    text     = "Skin Unlocker",
    tooltip  = "Unlocks all weapon and armor skins. (Ultimate Engine Bypass Version)",
    default  = false,
    callback = function(state)
        applySkinUnlockState(state)
    end
})

if NiceTrainer.Settings.skin_unlocker then
    applySkinUnlockState(true)
end
