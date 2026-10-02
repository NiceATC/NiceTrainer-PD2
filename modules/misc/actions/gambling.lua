-- Gambling logic
local rand = math.random
local randseed = math.randomseed
local tab_insert = table.insert

local r_index = {"common", "uncommon", "rare", "epic", "legendary"}
local q_index = {"poor", "fair", "good", "fine", "mint"}
local sim_chances = {
    r = {65, 20, 5, 1.5, 0.5},
    r_o = {70, 25, 5},
    r_a = {65, 30, 5},
    q = {20, 20, 20, 20, 20},
    stat = 10
}

local function get_total(index, t)
    local total = 0
    for i, n in pairs(index) do
        total = total + sim_chances[t][i]
    end
    return total
end

local function random_choice(index, t)
    local total = get_total(index, t)
    local rand_n = rand(total)
    local track = 0
    for i, n in pairs(index) do
        local prob = sim_chances[t][i]
        if prob > 0 and rand_n > track and rand_n <= track + prob then
            return n
        end
        track = track + prob
    end
    return index[1]
end

local function choose_item(safe_content)
    local T_E = tweak_data and tweak_data.economy
    local T_B_weapon_skins = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins
    if not T_E or not T_B_weapon_skins then return nil end

    local r_index_over = safe_content == "overkill_01" and {"rare", "epic", "legendary"} or safe_content == "lones_01" and {"rare", "epic", "legendary"} or nil
    local is_armor = T_E.contents[safe_content] and T_E.contents[safe_content].contains and T_E.contents[safe_content].contains.armor_skins and {"uncommon", "rare", "epic"} or nil
    local r_index_armor = is_armor or nil
    local data = is_armor and {amount = 1, category = "armor_skins"} or {amount = 1, category = "weapon_skins"}
    local now = os.date("!*t")
    randseed(now.yday * (now.hour + 1) * (now.min + 1) * (now.sec + 1))
    
    if is_armor == nil then 
        data.bonus = rand(100) <= sim_chances.stat
    end
    
    local rarity_chances = r_index_over and "r_o" or r_index_armor and "r_a" or "r"
    local rarity = random_choice(r_index_over or r_index_armor or r_index, rarity_chances)
    local skin_index = {}
    
    if is_armor ~= nil then
        for _, skin in pairs(T_E.contents[safe_content].contains.armor_skins) do
            if T_E.armor_skins[skin] and T_E.armor_skins[skin].rarity == rarity then
                tab_insert(skin_index, skin)
            end
        end
    else
        if rarity == "legendary" then
            local c_arr = T_E.contents[safe_content] and T_E.contents[safe_content].contains and T_E.contents[safe_content].contains.contents
            if c_arr and c_arr[1] and T_E.contents[c_arr[1]] and T_E.contents[c_arr[1]].contains and T_E.contents[c_arr[1]].contains.weapon_skins then
                for _, skin in pairs(T_E.contents[c_arr[1]].contains.weapon_skins) do
                    tab_insert(skin_index, skin)
                end
            end
        else
            if T_E.contents[safe_content] and T_E.contents[safe_content].contains and T_E.contents[safe_content].contains.weapon_skins then
                for _, skin in pairs(T_E.contents[safe_content].contains.weapon_skins) do
                    if T_B_weapon_skins[skin] and T_B_weapon_skins[skin].rarity == rarity then
                        tab_insert(skin_index, skin)
                    end
                end
            end
        end
    end
    
    if #skin_index == 0 then return nil end
    data.entry = skin_index[rand(#skin_index)]
    if not is_armor then
        data.quality = random_choice(q_index, "q")
    end
    
    data.def_id = 101
    local i = 1
    if managers.blackmarket and managers.blackmarket._global and managers.blackmarket._global.inventory_tradable then
        while managers.blackmarket._global.inventory_tradable[tostring(i)] ~= nil do
            i = i + 1
        end
    end
    data.instance_id = tostring(i)
    
    return data
end

local function get_safe_options()
    local safe_options = {}
    local T_E = tweak_data and tweak_data.economy
    if T_E and T_E.safes and managers.localization then
        for safe, safe_d in pairs(T_E.safes) do
            if safe_d.name_id and safe_d.content then
                table.insert(safe_options, {
                    text = managers.localization:text(safe_d.name_id),
                    value = safe_d
                })
            end
        end
        table.sort(safe_options, function(a, b) return a.text < b.text end)
    end
    return safe_options
end

NiceTrainer:RegisterAction("Miscellaneous", {
    type = "modal",
    category = "FUN - OFFSHORE GAMBLING",
    id = "open_safe_modal",
    text = "Open Safe (Cost: $1,000,000)",
    modal_title = "SELECT A SAFE",
    action_btn_text = "Select & Open...",
    options = get_safe_options,
    tooltip = "Choose and open a safe directly from the list",
    callback = function(safe_d, safe_text)
        if not safe_d then return end
        local T_E = tweak_data and tweak_data.economy
        if not T_E then return end

        local safe_cost = 1000000
        if not managers.money or managers.money:offshore() < safe_cost then
            NiceTrainer:Toast("Not enough offshore money!", Color.red)
            return
        end

        local item = choose_item(safe_d.content)
        if not item then
            NiceTrainer:Toast("Failed to generate item from safe!", Color.red)
            return
        end

        managers.money:deduct_from_offshore(safe_cost)
        
        local item_name = "Unknown"
        local rarity = "Unknown"
        if item.category == "weapon_skins" then
            local skin_data = tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins[item.entry]
            if skin_data then 
                item_name = managers.localization:text(skin_data.name_id)
                rarity = managers.localization:text("bm_menu_rarity_" .. skin_data.rarity)
            end
        elseif item.category == "armor_skins" then
            local skin_data = tweak_data.economy and tweak_data.economy.armor_skins[item.entry]
            if skin_data then 
                item_name = managers.localization:text(skin_data.name_id)
                rarity = managers.localization:text("bm_menu_rarity_" .. skin_data.rarity)
            end
        end

        NiceTrainer.Settings.fake_skins = NiceTrainer.Settings.fake_skins or {}
        NiceTrainer.Settings.fake_skins[item.instance_id] = {
            category = item.category,
            entry = item.entry,
            quality = item.quality,
            bonus = item.bonus,
            favourite = false
        }
        NiceTrainer:Save()

        if managers.blackmarket then
            managers.blackmarket:tradable_add_item(item.instance_id, item.category, item.entry, item.quality or "mint", item.bonus or false, 1)
        end

        -- Animação original 1 para 1
        if NiceTrainer.IsOpen then NiceTrainer:Toggle() end
        
        local function ready_clbk()
            if managers.menu then managers.menu:back() end
            if managers.system_menu then managers.system_menu:force_close_all() end
            if managers.menu_component then managers.menu_component:set_blackmarket_enabled(false) end
            if managers.menu then managers.menu:open_node("open_steam_safe", {safe_d.content}) end
        end

        if managers.menu_component then
            managers.menu_component:set_blackmarket_disable_fetching(true)
            managers.menu_component:set_blackmarket_enabled(false)
        end
        
        -- Pega o ID da safe para o 3D (normalmente é a chave do tweak_data)
        local safe_name_id = "default"
        for k, v in pairs(T_E.safes) do
            if v == safe_d then safe_name_id = k break end
        end
        
        if managers.menu_scene then
            managers.menu_scene:create_economy_safe_scene(safe_name_id, ready_clbk)
            managers.menu_scene:set_scene_template("standard")
        end
        
        if MenuCallbackHandler and MenuCallbackHandler._safe_result_recieved then
            MenuCallbackHandler:_safe_result_recieved(nil, {item}, {})
        end
    end
})

local safe_cost = 1000000
local OFFSHORE_POC_SELL_BONUS_MULT = 1.25
local OFFSHORE_POC_SELL_RARITY_MULT = { common = 0.1, uncommon = 0.4, rare = 1, epic = 2.5, legendary = 10 }
local OFFSHORE_POC_SELL_CONDITION_MULT = { poor = 0.25, fair = 0.6, good = 1, fine = 1.4, mint = 1.75 }

local function get_sell_value(skin_data)
    local weapon_skin_tweak = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins[skin_data.entry]
    local skin_rarity = weapon_skin_tweak and weapon_skin_tweak.rarity or "common"
    local rarity_mult = OFFSHORE_POC_SELL_RARITY_MULT[skin_rarity] or OFFSHORE_POC_SELL_RARITY_MULT.common
    local condition_mult = OFFSHORE_POC_SELL_CONDITION_MULT[skin_data.quality] or 1
    local value = safe_cost * rarity_mult * condition_mult
    if skin_data.bonus then value = value * OFFSHORE_POC_SELL_BONUS_MULT end
    return math.floor(value)
end

local function sell_fake_skins_by_rarity(rarity)
    NiceTrainer.Settings.fake_skins = NiceTrainer.Settings.fake_skins or {}
    local total_value = 0
    local sold_count = 0
    for instance_id, skin_data in pairs(NiceTrainer.Settings.fake_skins) do
        local weapon_skin_tweak = tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.weapon_skins[skin_data.entry]
        local skin_rarity = weapon_skin_tweak and weapon_skin_tweak.rarity
        if skin_rarity == rarity and not skin_data.favourite then
            local value = get_sell_value(skin_data)
            NiceTrainer.Settings.fake_skins[instance_id] = nil
            if managers.blackmarket then
                managers.blackmarket:tradable_remove_item(instance_id)
            end
            if managers.money then
                managers.money:add_to_offshore(value)
            end
            total_value = total_value + value
            sold_count = sold_count + 1
        end
    end
    NiceTrainer:Save()
    local cash_str = managers.experience and managers.experience:cash_string(total_value) or tostring(total_value)
    NiceTrainer:ShowModal("Skins Sold", { "Sold " .. sold_count .. " " .. rarity .. " skins", "Earned: $" .. cash_str .. " Offshore" })
end

NiceTrainer:RegisterAction("Miscellaneous", {
    type = "button",
    category = "FUN - OFFSHORE GAMBLING",
    no_bind = true,
    id = "btn_sell_common",
    text = "Sell all Common Skins",
    tooltip = "Sells every common-rarity fake skin you own",
    callback = function() sell_fake_skins_by_rarity("common") end
})

NiceTrainer:RegisterAction("Miscellaneous", {
    type = "button",
    category = "FUN - OFFSHORE GAMBLING",
    no_bind = true,
    id = "btn_sell_uncommon",
    text = "Sell all Uncommon Skins",
    tooltip = "Sells every uncommon-rarity fake skin you own",
    callback = function() sell_fake_skins_by_rarity("uncommon") end
})

NiceTrainer:RegisterAction("Miscellaneous", {
    type = "button",
    category = "FUN - OFFSHORE GAMBLING",
    no_bind = true,
    id = "btn_sell_nonfav",
    text = "Sell all Non-Favourite Skins",
    tooltip = "Sells every fake skin you own that's not marked as favourite",
    callback = function()
        NiceTrainer.Settings.fake_skins = NiceTrainer.Settings.fake_skins or {}
        local total_value = 0
        local sold_count = 0
        for instance_id, skin_data in pairs(NiceTrainer.Settings.fake_skins) do
            if not skin_data.favourite then
                local value = get_sell_value(skin_data)
                NiceTrainer.Settings.fake_skins[instance_id] = nil
                if managers.blackmarket then
                    managers.blackmarket:tradable_remove_item(instance_id)
                end
                if managers.money then
                    managers.money:add_to_offshore(value)
                end
                total_value = total_value + value
                sold_count = sold_count + 1
            end
        end
        NiceTrainer:Save()
        local cash_str = managers.experience and managers.experience:cash_string(total_value) or tostring(total_value)
        NiceTrainer:ShowModal("Skins Sold", { "Sold " .. sold_count .. " non-favourite skins", "Earned: $" .. cash_str .. " Offshore" })
    end
})

DelayedCalls:Add("NiceTrainer_RestoreFakeSkins", 1, function()
    if managers.blackmarket and NiceTrainer.Settings.fake_skins then
        managers.blackmarket._global.inventory_tradable = managers.blackmarket._global.inventory_tradable or {}
        for instance_id, skin_data in pairs(NiceTrainer.Settings.fake_skins) do
            if not managers.blackmarket._global.inventory_tradable[instance_id] then
                managers.blackmarket:tradable_add_item(instance_id, skin_data.category, skin_data.entry, skin_data.quality or "mint", skin_data.bonus or false, 1)
            end
        end
    end
end)
