-- ─── Black Market & Inventory Actions for NiceTrainer ───────────────────────

local function get_item_global_value(data)
    if not data then return "normal" end
    if data.global_value then return data.global_value end
    if data.infamous then return "infamous" end
    if data.dlcs and #data.dlcs > 0 then
        return data.dlcs[math.random(#data.dlcs)]
    end
    if data.dlc then return data.dlc end
    return "normal"
end

local function unlock_blackmarket_category(item_type)
    local count = 0
    local bm_tweaks = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket[item_type]
    if not bm_tweaks or not managers.blackmarket then return 0 end

    for id, data in pairs(bm_tweaks) do
        if data.infamy_lock then data.infamy_lock = false end
        local gv = get_item_global_value(data)
        pcall(function()
            managers.blackmarket:add_to_inventory(gv, item_type, id)
            count = count + 1
        end)
    end
    return count
end

local function unlock_all_weapons()
    local count = 0
    local weapons = Global.blackmarket_manager and Global.blackmarket_manager.weapons
    if weapons and managers.upgrades then
        for weapon_id, wdata in pairs(weapons) do
            pcall(function()
                managers.upgrades:aquire(weapon_id)
                wdata.unlocked = true
                count = count + 1
            end)
        end
    end
    return count
end

local function unlock_upgrade_category(cat)
    local count = 0
    if tweak_data and tweak_data.upgrades and tweak_data.upgrades.definitions and managers.upgrades then
        for id, data in pairs(tweak_data.upgrades.definitions) do
            if data.category == cat then
                if cat == "weapon" and (string.find(id, "_primary") or string.find(id, "_secondary")) then
                    -- skip base slot duplicates
                else
                    if not managers.upgrades:aquired(id) then
                        pcall(function()
                            managers.upgrades:aquire(id)
                            count = count + 1
                        end)
                    end
                end
            end
        end
    end
    return count
end

local function unlock_blackmarket_items(target)
    if target == "all" then
        local types = { "weapon_mods", "masks", "materials", "textures", "colors" }
        local total = 0
        for _, t in ipairs(types) do
            total = total + unlock_blackmarket_category(t)
        end
        total = total + unlock_all_weapons()
        total = total + unlock_upgrade_category("melee_weapon")
        total = total + unlock_upgrade_category("grenade")
        total = total + unlock_upgrade_category("armor")
        NiceTrainer:Toast(string.format("Unlocked %d items across all Black Market categories!", total))
    elseif target == "weapons" then
        local c = unlock_all_weapons() + unlock_upgrade_category("weapon")
        NiceTrainer:Toast(string.format("Unlocked %d Weapons!", c))
    elseif target == "melee_weapon" then
        local c = unlock_upgrade_category("melee_weapon")
        NiceTrainer:Toast(string.format("Unlocked %d Melee Weapons!", c))
    elseif target == "grenade" then
        local c = unlock_upgrade_category("grenade")
        NiceTrainer:Toast(string.format("Unlocked %d Throwables / Grenades!", c))
    elseif target == "armor" then
        local c = unlock_upgrade_category("armor")
        NiceTrainer:Toast(string.format("Unlocked %d Armors!", c))
    else
        local c = unlock_blackmarket_category(target)
        NiceTrainer:Toast(string.format("Unlocked %d items in %s!", c, target))
    end
    if managers.savefile and managers.savefile.save_progress then
        pcall(function() managers.savefile:save_progress() end)
    end
end

-- ============================================================================
-- 1. Granular Black Market Unlocker Modal
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "modal",
    category        = "Black Market & Inventory",
    badge           = "client",
    no_bind         = true,
    id              = "blackmarket_unlock_modal",
    text            = "Black Market Item Unlocker",
    tooltip         = "Select which category of Black Market items to add directly to your inventory.",
    modal_title     = "Black Market Category Unlocker",
    action_btn_text = "Open Unlocker...",
    options         = {
        { text = "★ Unlock All Items (Weapons, Mods, Masks, Colors, Materials, Melee, Grenades, Armors)", value = "all" },
        { text = "Weapon Modifications (Barrels, Sights, Gadgets, Grips)",                  value = "weapon_mods" },
        { text = "Masks (All Non-DLC & Drop Masks)",                                         value = "masks" },
        { text = "Materials (All Mask Crafting Materials)",                                  value = "materials" },
        { text = "Textures & Patterns (All Mask Patterns)",                                 value = "textures" },
        { text = "Color Palettes (All Mask Colors)",                                         value = "colors" },
        { text = "Base Weapons (Unlock All Base Weapon Licenses)",                           value = "weapons" },
        { text = "Melee Weapons (Unlock All Melee Weapons)",                                 value = "melee_weapon" },
        { text = "Throwables / Grenades (Unlock All Throwables)",                            value = "grenade" },
        { text = "Body Armors (Unlock All Armors)",                                          value = "armor" },
    },
    callback        = function(val, text)
        unlock_blackmarket_items(val)
    end
})

-- ============================================================================
-- 2. Clear New Drops Exclamation Marks (!)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Black Market & Inventory",
    badge           = "client",
    no_bind         = true,
    id              = "clear_inventory_exclamations",
    text            = "Clear Drop Notification Marks (!)",
    tooltip         = "Clears all new drop exclamation marks from the Black Market inventory and menu.",
    action_btn_text = "Clear (!)",
    callback        = function()
        if Global.blackmarket_manager then
            Global.blackmarket_manager.new_drops = {}
            NiceTrainer:Toast("Inventory notification marks cleared!")
        end
    end
})

-- ============================================================================
-- 3. Inventory Cleanup Modal
-- ============================================================================
local function clear_crafted_slots(category)
    local crafted_items = Global.blackmarket_manager and Global.blackmarket_manager.crafted_items
    if not crafted_items then return end

    local cats = (category == "all") and { "primaries", "secondaries", "masks" } or { category }
    local cleared = 0

    for _, cat in ipairs(cats) do
        if crafted_items[cat] then
            for slot, _ in pairs(crafted_items[cat]) do
                if slot ~= 1 then
                    pcall(function()
                        if cat == "masks" then
                            managers.blackmarket:on_sell_mask(slot)
                        else
                            managers.blackmarket:on_sell_weapon(cat, slot)
                        end
                        cleared = cleared + 1
                    end)
                end
            end
        end
    end
    NiceTrainer:Toast(string.format("Cleared %d crafted items from %s slots (Slot 1 preserved).", cleared, category))
end

local function wipe_uncrafted_inventory()
    local bmt = tweak_data and tweak_data.blackmarket
    local g_inv = Global.blackmarket_manager and Global.blackmarket_manager.inventory
    if not (bmt and g_inv) then return end

    for global_value, gv_table in pairs(g_inv) do
        for type_id, type_table in pairs(gv_table) do
            if bmt[type_id] then
                for item_id, _ in pairs(type_table) do
                    type_table[item_id] = nil
                end
            end
        end
    end
    pcall(function() managers.blackmarket:_load_done() end)
    NiceTrainer:Toast("Uncrafted Black Market inventory wiped.")
end

NiceTrainer:RegisterAction("Account", {
    type            = "modal",
    category        = "Black Market & Inventory",
    badge           = "risk",
    no_bind         = true,
    id              = "inventory_cleanup_modal",
    text            = "Inventory Cleanup & Wipe",
    tooltip         = "Manage inventory slots and cleanup duplicate crafted weapons or masks.",
    modal_title     = "Select Inventory Cleanup Action",
    action_btn_text = "Open Cleanup...",
    options         = {
        { text = "Clear All Crafted Primaries (Slot 2+)",       value = "primaries" },
        { text = "Clear All Crafted Secondaries (Slot 2+)",     value = "secondaries" },
        { text = "Clear All Crafted Masks (Slot 2+)",           value = "masks" },
        { text = "Clear ALL Crafted Slots (Primaries, Secondaries, Masks)", value = "all_slots" },
        { text = "⚠ Wipe Uncrafted Black Market Items (Stash)", value = "wipe_stash" },
    },
    callback        = function(val, text)
        if val == "primaries" or val == "secondaries" or val == "masks" then
            clear_crafted_slots(val)
        elseif val == "all_slots" then
            clear_crafted_slots("all")
        elseif val == "wipe_stash" then
            NiceTrainer:ShowConfirmDialog(
                "Confirm Stash Wipe",
                "Are you sure you want to clear your uncrafted Black Market inventory?\n\nThis will remove unequipped masks, mods, and materials in your stock.",
                {
                    {
                        text = "Yes, Wipe Stash",
                        color = Color(0.9, 0.35, 0.35),
                        callback = wipe_uncrafted_inventory
                    },
                    {
                        text = "Cancel",
                        color = Color(0.6, 0.6, 0.6),
                        callback = function() end
                    }
                }
            )
        end
    end
})
