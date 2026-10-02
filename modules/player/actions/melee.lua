-- Melee hacks for Player Tab

local function toggle_instant_melee(state)
    if not tweak_data or not tweak_data.blackmarket or not tweak_data.blackmarket.melee_weapons then return end
    
    for id, data in pairs(tweak_data.blackmarket.melee_weapons) do
        local stats = data.stats
        local charge_time = stats and stats.charge_time
        if id ~= "weapon" and charge_time then
            if state then
                if not stats.nice_orig_charge_time then
                    stats.nice_orig_charge_time = charge_time
                    stats.charge_time = 0.001
                end
            else
                if stats.nice_orig_charge_time then
                    stats.charge_time = stats.nice_orig_charge_time
                    stats.nice_orig_charge_time = nil
                end
            end
        end
    end
end

local function apply_melee_range(state)
    if not tweak_data or not tweak_data.blackmarket or not tweak_data.blackmarket.melee_weapons then return end
    
    for _, tweak in pairs(tweak_data.blackmarket.melee_weapons) do
        local stats = tweak.stats
        if type(stats) == "table" and stats.range then
            if state then
                stats.old_range = stats.old_range or stats.range
                stats.range = 20000
            elseif stats.old_range then
                stats.range = stats.old_range
                stats.old_range = nil
            end
        end
    end
end

local function apply_melee_damage(state, mult)
    if not tweak_data or not tweak_data.blackmarket or not tweak_data.blackmarket.melee_weapons then return end
    
    for _, tweak in pairs(tweak_data.blackmarket.melee_weapons) do
        local stats = tweak.stats
        if type(stats) == "table" then
            for _, field in ipairs({ "min_damage", "max_damage", "damage" }) do
                if stats[field] then
                    local backup = "old_" .. field
                    if state then
                        stats[backup] = stats[backup] or stats[field]
                        stats[field] = stats[backup] * mult
                    else
                        if stats[backup] then
                            stats[field] = stats[backup]
                            stats[backup] = nil
                        end
                    end
                end
            end
        end
    end
end

NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Melee", badge = "client", id = "instant_melee", text = "Instant Melee Charge", tooltip = "Your melee attack is instantly ready to use again after each swing.", default = false, callback = toggle_instant_melee })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Melee", badge = "client", id = "melee_range", text = "Long Melee Range", tooltip = "Hit enemies with melee from far away.", default = false, callback = apply_melee_range })

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Melee", badge = "client", id = "enable_melee_damage", text = "Melee Damage Multiplier", tooltip = "Multiplies your melee weapon damage.", default = false,
    callback = function(state)
        local mult = tonumber(NiceTrainer.Settings.melee_damage_multiplier) or 2
        apply_melee_damage(state, mult)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Melee Damage Multiplier", 1, 100, tonumber(NiceTrainer.Settings.melee_damage_multiplier) or 2, function(val)
            NiceTrainer.Settings.melee_damage_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_melee_damage then
                apply_melee_damage(true, val)
            end
        end)
    end
})

local function reapply_all_melee()
    if NiceTrainer.Settings.instant_melee then toggle_instant_melee(true) end
    if NiceTrainer.Settings.melee_range then apply_melee_range(true) end
    if NiceTrainer.Settings.enable_melee_damage then
        local mult = tonumber(NiceTrainer.Settings.melee_damage_multiplier) or 2
        apply_melee_damage(true, mult)
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyMelee", reapply_all_melee)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_ReapplyMelee", reapply_all_melee)
