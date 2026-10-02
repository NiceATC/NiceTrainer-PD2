if not _G.NiceTrainerEarlySettings then
    _G.NiceTrainerEarlySettings = _G.GetNiceTrainerSettings and _G.GetNiceTrainerSettings() or {}
end

local function isDlcEnabled(dlc_name)
    local enabled = false
    if _G.NiceTrainer and _G.NiceTrainer.Settings then
        enabled = _G.NiceTrainer.Settings.dlc_unlocker == true
    elseif _G.NiceTrainerEarlySettings then
        enabled = _G.NiceTrainerEarlySettings.dlc_unlocker == true
    end
    if not enabled then return false end

    local settings = (_G.NiceTrainer and _G.NiceTrainer.Settings) or _G.NiceTrainerEarlySettings
    if settings and settings.unlocked_dlcs and dlc_name then
        return settings.unlocked_dlcs[dlc_name] == true
    end
    return true
end

local function isSkinEnabled()
    if _G.NiceTrainer and _G.NiceTrainer.Settings then return _G.NiceTrainer.Settings.skin_unlocker end
    return _G.NiceTrainerEarlySettings.skin_unlocker
end

local function isSpoofEnabled()
    if _G.NiceTrainer and _G.NiceTrainer.Settings then
        return _G.NiceTrainer.Settings.spoof_equipment == true
    end
    return _G.NiceTrainerEarlySettings and _G.NiceTrainerEarlySettings.spoof_equipment == true
end

-- DLC Hooks
if _G.WinSteamDLCManager and not _G.WinSteamDLCManager.NT_Hooked then
    _G.WinSteamDLCManager.NT_Hooked = true
    _G.WinSteamDLCManager.orig_check_dlc_data = _G.WinSteamDLCManager.orig_check_dlc_data or _G.WinSteamDLCManager._check_dlc_data
    _G.WinSteamDLCManager._check_dlc_data = function(self, dlc_data, ...)
        local dlc_name = dlc_data and dlc_data._dlc_name
        if not dlc_name and Global.dlc_manager and Global.dlc_manager.all_dlc_data and dlc_data then
            for name, data in pairs(Global.dlc_manager.all_dlc_data) do
                if data == dlc_data then
                    dlc_name = name
                    dlc_data._dlc_name = name
                    break
                end
            end
        end
        if isDlcEnabled(dlc_name) then return true end
        return self:orig_check_dlc_data(dlc_data, ...)
    end
end
if _G.WinEpicDLCManager and not _G.WinEpicDLCManager.NT_Hooked then
    _G.WinEpicDLCManager.NT_Hooked = true
    _G.WinEpicDLCManager.orig_check_dlc_data = _G.WinEpicDLCManager.orig_check_dlc_data or _G.WinEpicDLCManager._check_dlc_data
    _G.WinEpicDLCManager._check_dlc_data = function(self, dlc_data, ...)
        local dlc_name = dlc_data and dlc_data._dlc_name
        if not dlc_name and Global.dlc_manager and Global.dlc_manager.all_dlc_data and dlc_data then
            for name, data in pairs(Global.dlc_manager.all_dlc_data) do
                if data == dlc_data then
                    dlc_name = name
                    dlc_data._dlc_name = name
                    break
                end
            end
        end
        if isDlcEnabled(dlc_name) then return true end
        return self:orig_check_dlc_data(dlc_data, ...)
    end
end
if _G.GenericDLCManager and not _G.GenericDLCManager.NT_Hooked then
    _G.GenericDLCManager.NT_Hooked = true
    _G.GenericDLCManager.orig_has_raidww2_clan = _G.GenericDLCManager.orig_has_raidww2_clan or _G.GenericDLCManager.has_raidww2_clan
    _G.GenericDLCManager.orig_has_freed_old_hoxton = _G.GenericDLCManager.orig_has_freed_old_hoxton or _G.GenericDLCManager.has_freed_old_hoxton
    _G.GenericDLCManager.orig_is_dlc_unlocked = _G.GenericDLCManager.orig_is_dlc_unlocked or _G.GenericDLCManager.is_dlc_unlocked
    _G.GenericDLCManager.orig_has_dlc = _G.GenericDLCManager.orig_has_dlc or _G.GenericDLCManager.has_dlc
    _G.GenericDLCManager.orig_give_missing_package = _G.GenericDLCManager.orig_give_missing_package or _G.GenericDLCManager.give_missing_package
    _G.GenericDLCManager.orig_give_dlc_and_verify_blackmarket = _G.GenericDLCManager.orig_give_dlc_and_verify_blackmarket or _G.GenericDLCManager.give_dlc_and_verify_blackmarket

    _G.GenericDLCManager.has_raidww2_clan = function(self, ...)
        if isDlcEnabled("pd2_clan") then return true end
        return self:orig_has_raidww2_clan(...)
    end
    _G.GenericDLCManager.has_freed_old_hoxton = function(self, ...)
        if isDlcEnabled("character_pack_clover") or isDlcEnabled() then return true end
        return self:orig_has_freed_old_hoxton(...)
    end
    _G.GenericDLCManager.is_dlc_unlocked = function(self, dlc, ...)
        if isDlcEnabled(dlc) then return true end
        return self:orig_is_dlc_unlocked(dlc, ...)
    end
    _G.GenericDLCManager.has_dlc = function(self, dlc, ...)
        if isDlcEnabled(dlc) then return true end
        return self:orig_has_dlc(dlc, ...)
    end

    _G.GenericDLCManager.give_missing_package = function(self, ...)
        local name_converter = {
            colors = "color",
            materials = "material",
            textures = "pattern"
        }
        local entry, global_value, passed, has_item, name, check_loot_drop

        if not tweak_data or not tweak_data.dlc or not Global.dlc_save or not Global.dlc_save.packages then
            return
        end

        for package_id, data in pairs(tweak_data.dlc) do
            if Global.dlc_save.packages[package_id] and self:is_dlc_unlocked(package_id) then
                for _, loot_drop in ipairs(data.content and data.content.loot_drops or {}) do
                    check_loot_drop = #loot_drop == 0

                    if check_loot_drop and loot_drop.type_items == "armor_skins" then
                        entry = tweak_data.economy and tweak_data.economy.armor_skins and tweak_data.economy.armor_skins[loot_drop.item_entry]
                        if entry and managers.blackmarket and managers.blackmarket.armor_skin_unlocked then
                            has_item = managers.blackmarket:armor_skin_unlocked(loot_drop.item_entry)
                            if not entry.steam_economy and not has_item and managers.blackmarket.on_aquired_armor_skin then
                                pcall(function() managers.blackmarket:on_aquired_armor_skin(loot_drop.item_entry) end)
                            end
                        end
                        check_loot_drop = false
                    end

                    if check_loot_drop and loot_drop.type_items == "player_styles" then
                        if managers.blackmarket and managers.blackmarket.player_style_unlocked and not managers.blackmarket:player_style_unlocked(loot_drop.item_entry) then
                            if managers.blackmarket.on_aquired_player_style then
                                pcall(function() managers.blackmarket:on_aquired_player_style(loot_drop.item_entry) end)
                            end
                        end
                        check_loot_drop = false
                    end

                    if check_loot_drop and loot_drop.type_items == "suit_variations" and type(loot_drop.item_entry) == "table" then
                        if managers.blackmarket and managers.blackmarket.suit_variation_unlocked and not managers.blackmarket:suit_variation_unlocked(loot_drop.item_entry[1], loot_drop.item_entry[2]) then
                            if managers.blackmarket.on_aquired_suit_variation then
                                pcall(function() managers.blackmarket:on_aquired_suit_variation(loot_drop.item_entry[1], loot_drop.item_entry[2]) end)
                            end
                        end
                        check_loot_drop = false
                    end

                    if check_loot_drop and loot_drop.type_items == "gloves" then
                        if managers.blackmarket and managers.blackmarket.glove_id_unlocked and not managers.blackmarket:glove_id_unlocked(loot_drop.item_entry) then
                            if managers.blackmarket.on_aquired_glove_id then
                                pcall(function() managers.blackmarket:on_aquired_glove_id(loot_drop.item_entry) end)
                            end
                        end
                        check_loot_drop = false
                    end

                    if check_loot_drop and tweak_data.blackmarket and tweak_data.blackmarket[loot_drop.type_items] then
                        entry = tweak_data.blackmarket[loot_drop.type_items][loot_drop.item_entry]
                        if entry then
                            global_value = loot_drop.global_value or (data.content and data.content.loot_global_value) or package_id
                            passed = false

                            if (loot_drop.type_items == "weapon_mods" or loot_drop.type_items == "weapon_skins") and entry.is_a_unlockable then
                                has_item = managers.blackmarket and managers.blackmarket:get_item_amount(global_value, loot_drop.type_items, loot_drop.item_entry, true) > 0
                                passed = not has_item
                            elseif loot_drop.type_items ~= "weapon_mods" and entry.value and entry.value == 0 then
                                has_item = managers.blackmarket and managers.blackmarket:get_item_amount(global_value, loot_drop.type_items, loot_drop.item_entry, true) > 0

                                if not has_item and Global.blackmarket_manager and Global.blackmarket_manager.crafted_items and Global.blackmarket_manager.crafted_items.masks then
                                    if loot_drop.type_items == "masks" then
                                        for slot, crafted in pairs(Global.blackmarket_manager.crafted_items.masks) do
                                            if slot ~= 1 and crafted.mask_id == loot_drop.item_entry and crafted.global_value == global_value then
                                                has_item = true
                                                break
                                            end
                                        end
                                    elseif loot_drop.type_items == "materials" or loot_drop.type_items == "textures" or loot_drop.type_items == "colors" then
                                        for slot, crafted in pairs(Global.blackmarket_manager.crafted_items.masks) do
                                            if slot ~= 1 and crafted.blueprint then
                                                name = name_converter[loot_drop.type_items]
                                                if name and crafted.blueprint[name] and crafted.blueprint[name].id == loot_drop.item_entry and crafted.blueprint[name].global_value == global_value then
                                                    has_item = true
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end

                                passed = not has_item
                            end

                            if passed and managers.blackmarket and managers.blackmarket.add_to_inventory then
                                for i = 1, loot_drop.amount or 1 do
                                    pcall(function()
                                        managers.blackmarket:add_to_inventory(global_value, loot_drop.type_items, loot_drop.item_entry)
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    _G.GenericDLCManager.give_dlc_and_verify_blackmarket = function(self, ...)
        if self.orig_give_dlc_and_verify_blackmarket then
            local ok, res = pcall(self.orig_give_dlc_and_verify_blackmarket, self, ...)
            if ok then return res end
        end
    end
end

-- BlackMarket Hooks (For both DLC and Skins)
if _G.BlackMarketManager and not _G.BlackMarketManager.NT_Hooked then
    _G.BlackMarketManager.NT_Hooked = true
    
    _G.BlackMarketManager.orig_has_unlocked_breech = _G.BlackMarketManager.orig_has_unlocked_breech or _G.BlackMarketManager.has_unlocked_breech
    _G.BlackMarketManager.orig_has_unlocked_ching = _G.BlackMarketManager.orig_has_unlocked_ching or _G.BlackMarketManager.has_unlocked_ching
    _G.BlackMarketManager.orig_has_unlocked_erma = _G.BlackMarketManager.orig_has_unlocked_erma or _G.BlackMarketManager.has_unlocked_erma
    _G.BlackMarketManager.orig_is_crew_item_unlocked = _G.BlackMarketManager.orig_is_crew_item_unlocked or _G.BlackMarketManager.is_crew_item_unlocked
    _G.BlackMarketManager.orig_verify_dlc_items = _G.BlackMarketManager.orig_verify_dlc_items or _G.BlackMarketManager.verify_dlc_items
    
    _G.BlackMarketManager.has_unlocked_breech = function(self, ...)
        if isDlcEnabled() then return true, "bm_menu_locked_breech" end
        return self:orig_has_unlocked_breech(...)
    end
    _G.BlackMarketManager.has_unlocked_ching = function(self, ...)
        if isDlcEnabled() then return true, "bm_menu_locked_ching" end
        return self:orig_has_unlocked_ching(...)
    end
    _G.BlackMarketManager.has_unlocked_erma = function(self, ...)
        if isDlcEnabled() then return true, "bm_menu_locked_erma" end
        return self:orig_has_unlocked_erma(...)
    end
    _G.BlackMarketManager.is_crew_item_unlocked = function(self, ...)
        if isDlcEnabled() then return true end
        return self:orig_is_crew_item_unlocked(...)
    end
    _G.BlackMarketManager.verify_dlc_items = function(self, ...)
        if self.orig_verify_dlc_items then
            local ok, res = pcall(self.orig_verify_dlc_items, self, ...)
            if ok then return res end
        end
    end

    -- Skin Methods
    local function isVirtualSkin(category, skinId)
        if category ~= "weapon_skins" then return false end
        local skins = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins
        local data = skins and skins[skinId]
        return data ~= nil and not data.is_template
    end

    _G.BlackMarketManager.orig_armor_skin_unlocked = _G.BlackMarketManager.armor_skin_unlocked
    _G.BlackMarketManager.orig_get_item_amount = _G.BlackMarketManager.get_item_amount
    _G.BlackMarketManager.orig_on_equip_weapon_cosmetics = _G.BlackMarketManager.on_equip_weapon_cosmetics
    
    function BlackMarketManager:armor_skin_unlocked(skinId)
        if isSkinEnabled() and self:_is_armor_skin_valid(skinId) then return true end
        return self:orig_armor_skin_unlocked(skinId)
    end

    function BlackMarketManager:get_item_amount(globalValue, category, itemId, noPrints)
        if isSkinEnabled() and isVirtualSkin(category, itemId) then return 1 end
        return self:orig_get_item_amount(globalValue, category, itemId, noPrints)
    end

    function BlackMarketManager:on_equip_weapon_cosmetics(category, slot, instanceId)
        if isSkinEnabled() then
            local inventory = self._global and self._global.inventory_tradable
            local realInstance = inventory and inventory[instanceId]
            if not realInstance and isVirtualSkin("weapon_skins", instanceId) then
                self:_set_weapon_cosmetics(category, slot, {
                    instance_id = instanceId,
                    id = instanceId,
                    quality = "mint",
                    bonus = false,
                }, true)
                return
            end
        end
        return self:orig_on_equip_weapon_cosmetics(category, slot, instanceId)
    end

    -- ============================================================
    -- Anti-Cheat Equipment & Outfit Spoofing (mark a cheater)
    -- ============================================================
    local function get_default_weapon_blueprint(factory_id, fallback)
        if managers.weapon_factory and managers.weapon_factory.get_default_blueprint_by_factory_id then
            local bp = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
            if bp and #bp > 0 then return bp end
        end
        if tweak_data and tweak_data.weapon and tweak_data.weapon.factory and tweak_data.weapon.factory[factory_id] then
            local bp = tweak_data.weapon.factory[factory_id].default_blueprint
            if bp and #bp > 0 then return bp end
        end
        return fallback
    end

    local fallback_amcar_blueprint = {
        "wpn_fps_ass_amcar_b_standard",
        "wpn_fps_ass_amcar_body_upperreciever",
        "wpn_fps_ass_amcar_body_lowerreciever",
        "wpn_fps_ass_amcar_fg_amcar",
        "wpn_fps_ass_amcar_m_standard",
        "wpn_fps_ass_amcar_s_standard",
        "wpn_fps_ass_amcar_g_standard"
    }

    local fallback_g17_blueprint = {
        "wpn_fps_pis_g17_body_standard",
        "wpn_fps_pis_g17_b_standard",
        "wpn_fps_pis_g17_m_standard"
    }

    local o_equipped_primary = BlackMarketManager.equipped_primary
    function BlackMarketManager:equipped_primary(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then
            return {
                ["weapon_id"] = "amcar",
                ["equipped"] = true,
                ["global_values"] = {},
                ["factory_id"] = "wpn_fps_ass_amcar",
                ["blueprint"] = get_default_weapon_blueprint("wpn_fps_ass_amcar", fallback_amcar_blueprint)
            }
        end
        return o_equipped_primary(self, ...)
    end

    local o_equipped_secondary = BlackMarketManager.equipped_secondary
    function BlackMarketManager:equipped_secondary(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then
            return {
                ["weapon_id"] = "glock_17",
                ["equipped"] = true,
                ["global_values"] = {},
                ["factory_id"] = "wpn_fps_pis_g17",
                ["blueprint"] = get_default_weapon_blueprint("wpn_fps_pis_g17", fallback_g17_blueprint)
            }
        end
        return o_equipped_secondary(self, ...)
    end

    local o_equipped_melee_weapon = BlackMarketManager.equipped_melee_weapon
    function BlackMarketManager:equipped_melee_weapon(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "weapon" end
        return o_equipped_melee_weapon(self, ...)
    end

    local o_equipped_grenade = BlackMarketManager.equipped_grenade
    function BlackMarketManager:equipped_grenade(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "concussion", 6 end
        return o_equipped_grenade(self, ...)
    end

    local o_outfit_string_mask = BlackMarketManager._outfit_string_mask
    function BlackMarketManager:_outfit_string_mask(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then
            return "character_locked plastic no_color_no_material nothing-nothing"
        end
        return o_outfit_string_mask(self, ...)
    end

    local o_equipped_armor = BlackMarketManager.equipped_armor
    function BlackMarketManager:equipped_armor(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "level_1" end
        return o_equipped_armor(self, ...)
    end

    local o_equipped_armor_skin = BlackMarketManager.equipped_armor_skin
    function BlackMarketManager:equipped_armor_skin(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "none" end
        return o_equipped_armor_skin(self, ...)
    end

    local o_equipped_player_style = BlackMarketManager.equipped_player_style
    function BlackMarketManager:equipped_player_style(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "none" end
        return o_equipped_player_style(self, ...)
    end

    local o_get_suit_variation = BlackMarketManager.get_suit_variation
    function BlackMarketManager:get_suit_variation(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "default" end
        return o_get_suit_variation(self, ...)
    end

    local o_equipped_glove_id = BlackMarketManager.equipped_glove_id
    function BlackMarketManager:equipped_glove_id(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "default" end
        return o_equipped_glove_id(self, ...)
    end

    local o_outfit_string_from_cosmetics = BlackMarketManager.outfit_string_from_cosmetics
    function BlackMarketManager:outfit_string_from_cosmetics(...)
        if Global.IS_SENDING_OUTFIT and isSpoofEnabled() then return "nil-1-0" end
        return o_outfit_string_from_cosmetics(self, ...)
    end
end

-- BaseNetworkSession hook for outfit broadcasting
if _G.BaseNetworkSession and not _G.BaseNetworkSession.NT_OutfitSpoofHooked then
    _G.BaseNetworkSession.NT_OutfitSpoofHooked = true
    local orig_check_send_outfit = BaseNetworkSession.check_send_outfit
    function BaseNetworkSession:check_send_outfit(peer, ...)
        local spoof = isSpoofEnabled()
        if spoof then
            Global.IS_SENDING_OUTFIT = true
        end
        local ok, res = pcall(orig_check_send_outfit, self, peer, ...)
        Global.IS_SENDING_OUTFIT = false
        if not ok then
            error(res)
        end
        return res
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ResetOutfitSpoofState", function()
    Global.IS_SENDING_OUTFIT = false
end)

