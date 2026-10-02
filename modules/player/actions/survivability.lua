-- Survivability hacks for Player Tab

local function apply_god_mode(state)
    if managers.player and alive(managers.player:player_unit()) then
        local damage = managers.player:player_unit():character_damage()
        if damage and damage.set_god_mode then
            damage:set_god_mode(state)
        end
    end
end

-- Ensure god mode is reapplied on heist start if enabled
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyGodMode", function()
    if NiceTrainer.Settings.god_mode then
        -- Wait for player unit to spawn
        local function retry()
            if managers.player and alive(managers.player:player_unit()) then
                apply_god_mode(true)
            else
                DelayedCalls:Add("NiceTrainer_GodMode_Retry", 1, retry)
            end
        end
        retry()
    end
end)

NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    category = "Survivability",
    badge = "client",
    id = "god_mode",
    text = "God Mode",
    tooltip = "You take absolutely no damage from any source.",
    default = false,
    callback = apply_god_mode
})

NiceTrainer._orig_player_damage = NiceTrainer._orig_player_damage or {}

local function apply_no_fall_damage(state)
    if not _G.PlayerDamage then return end
    if state then
        if not NiceTrainer._orig_player_damage.damage_fall then
            NiceTrainer._orig_player_damage.damage_fall = PlayerDamage.damage_fall
            PlayerDamage.damage_fall = function(self, data)
                return false
            end
        end
    else
        if NiceTrainer._orig_player_damage.damage_fall then
            PlayerDamage.damage_fall = NiceTrainer._orig_player_damage.damage_fall
            NiceTrainer._orig_player_damage.damage_fall = nil
        end
    end
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    category = "Survivability",
    badge = "client",
    id = "no_fall_damage",
    text = "No Fall Damage",
    tooltip = "Prevents you from taking damage when falling from high places.",
    default = false,
    callback = apply_no_fall_damage
})

local function apply_infinite_stamina(state)
    if not _G.PlayerMovement then return end
    if state then
        if not NiceTrainer._orig_player_damage.change_stamina then
            NiceTrainer._orig_player_damage.change_stamina = PlayerMovement._change_stamina
            PlayerMovement._change_stamina = function() end
            
            NiceTrainer._orig_player_damage.is_stamina_drained = PlayerMovement.is_stamina_drained
            PlayerMovement.is_stamina_drained = function() return false end
        end
    else
        if NiceTrainer._orig_player_damage.change_stamina then
            PlayerMovement._change_stamina = NiceTrainer._orig_player_damage.change_stamina
            NiceTrainer._orig_player_damage.change_stamina = nil
            
            PlayerMovement.is_stamina_drained = NiceTrainer._orig_player_damage.is_stamina_drained
            NiceTrainer._orig_player_damage.is_stamina_drained = nil
        end
    end
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    category = "Survivability",
    badge = "client",
    id = "infinite_stamina",
    text = "Infinite Stamina",
    tooltip = "Your stamina never runs out, so you can sprint forever.",
    default = false,
    callback = apply_infinite_stamina
})

local _originals = {}
local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then _originals[key] = cls[method_name] end
    cls[method_name] = replacement
    return true
end
local function restore(class_name, method_name)
    local cls = _G[class_name]
    if not cls then return end
    local key = class_name .. "." .. method_name
    if _originals[key] then
        cls[method_name] = _originals[key]
        _originals[key] = nil
    end
end

local function applyMaxHealth(state, val)
    if state and val > 1 then
        hijack("PlayerDamage", "_max_health", function(self)
            local orig = _originals["PlayerDamage._max_health"]
            return (orig and orig(self) or 1) * val
        end)
    else
        restore("PlayerDamage", "_max_health")
    end
end

local function applyMaxArmor(state, val)
    if state and val > 1 then
        hijack("PlayerDamage", "_max_armor", function(self)
            local orig = _originals["PlayerDamage._max_armor"]
            return (orig and orig(self) or 1) * val
        end)
    else
        restore("PlayerDamage", "_max_armor")
    end
end

local function applyDodge(state, val)
    if state and val > 0 then
        hijack("PlayerManager", "skill_dodge_chance", function(self, ...)
            local orig = _originals["PlayerManager.skill_dodge_chance"]
            return (orig and orig(self, ...) or 0) + (val / 100)
        end)
    else
        restore("PlayerManager", "skill_dodge_chance")
    end
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Survivability", badge = "client", id = "enable_max_health", text = "Max Health Multiplier", tooltip = "Multiplies your maximum health.", default = false,
    callback = function(state) applyMaxHealth(state, tonumber(NiceTrainer.Settings.max_health_multiplier) or 2) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Max Health Multiplier", 1, 10, tonumber(NiceTrainer.Settings.max_health_multiplier) or 2, function(val)
            NiceTrainer.Settings.max_health_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_max_health then applyMaxHealth(true, val) end
        end)
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Survivability", badge = "client", id = "enable_max_armor", text = "Max Armor Multiplier", tooltip = "Multiplies your maximum armor.", default = false,
    callback = function(state) applyMaxArmor(state, tonumber(NiceTrainer.Settings.max_armor_multiplier) or 2) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Max Armor Multiplier", 1, 10, tonumber(NiceTrainer.Settings.max_armor_multiplier) or 2, function(val)
            NiceTrainer.Settings.max_armor_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_max_armor then applyMaxArmor(true, val) end
        end)
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Survivability", badge = "client", id = "enable_dodge_bonus", text = "Dodge Chance Bonus (%)", tooltip = "Adds flat dodge chance. 100 = completely dodge all bullets.", default = false,
    callback = function(state) applyDodge(state, tonumber(NiceTrainer.Settings.dodge_chance_bonus) or 50) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Dodge Chance Bonus", 0, 100, tonumber(NiceTrainer.Settings.dodge_chance_bonus) or 50, function(val)
            NiceTrainer.Settings.dodge_chance_bonus = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_dodge_bonus then applyDodge(true, val) end
        end)
    end
})

local function reapply_survivability_hooks()
    if NiceTrainer.Settings.no_fall_damage then apply_no_fall_damage(true) end
    if NiceTrainer.Settings.infinite_stamina then apply_infinite_stamina(true) end
    if NiceTrainer.Settings.enable_max_health then applyMaxHealth(true, tonumber(NiceTrainer.Settings.max_health_multiplier) or 2) end
    if NiceTrainer.Settings.enable_max_armor then applyMaxArmor(true, tonumber(NiceTrainer.Settings.max_armor_multiplier) or 2) end
    if NiceTrainer.Settings.enable_dodge_bonus then applyDodge(true, tonumber(NiceTrainer.Settings.dodge_chance_bonus) or 50) end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplySurvivability", function()
    reapply_survivability_hooks()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_SurvivabilityGameUpdate", function()
    reapply_survivability_hooks()
end)

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Survivability", badge = "client", id = "self_revive", text = "Self Revive",
    tooltip = "Instantly revives you if you are down.",
    callback = function()
        if managers.player then
            local state = managers.player:current_state()
            if state == "bleed_out" or state == "fatal" or state == "incapacitated" then
                managers.player:set_player_state("standard")
                NiceTrainer:Toast("Self Revived!")
            else
                NiceTrainer:Toast("You are not down.")
            end
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Survivability", badge = "client", id = "out_of_custody", text = "Out of Custody",
    tooltip = "Releases you from custody immediately (works as host and client).",
    callback = function()
        if IngameWaitingForRespawnState and IngameWaitingForRespawnState.request_player_spawn then
            IngameWaitingForRespawnState.request_player_spawn()
            NiceTrainer:Toast("Requested respawn!")
        else
            NiceTrainer:Toast("Cannot request respawn right now.")
        end
    end
})

-- Replenish Features
NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Health",
    tooltip = "Restores your health completely.",
    callback = function()
        if managers.player and managers.player:player_unit() then
            managers.player:player_unit():character_damage():replenish()
            NiceTrainer:Toast("Health Replenished!")
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Ammo",
    tooltip = "Restores ammo for all your weapons.",
    callback = function()
        if managers.player and managers.player:player_unit() then
            for id, weapon in pairs(managers.player:player_unit():inventory():available_selections()) do
                weapon.unit:base():replenish()
                managers.hud:set_ammo_amount(id, weapon.unit:base():ammo_info())
            end
            NiceTrainer:Toast("Ammo Replenished!")
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Equipment",
    tooltip = "Restores your deployable equipment (ammo bags, doctor bags, sentries, ECMs, trip mines, etc.).",
    callback = function()
        if managers.player and managers.player._equipment and managers.player._equipment.selections then
            for slot_idx, equip_data in ipairs(managers.player._equipment.selections) do
                local equip_name = equip_data.equipment
                local tw = tweak_data.equipments[equip_name]
                if tw and tw.quantity then
                    for q_idx = 1, #tw.quantity do
                        local sub_name = (tw.upgrade_name and tw.upgrade_name[q_idx]) or equip_name
                        local max_amt = (tw.quantity[q_idx] or 0) + managers.player:equiptment_upgrade_value(sub_name, "quantity")
                        if slot_idx > 1 then
                            max_amt = math.ceil(max_amt / 2)
                        end
                        max_amt = math.max(max_amt, 2)
                        managers.player:set_equipment_amount(equip_name, max_amt, q_idx)
                    end
                else
                    managers.player:set_equipment_amount(equip_name, 14, 1)
                end
            end
            NiceTrainer:Toast("Equipment Replenished!")
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Cable Ties",
    tooltip = "Restores your cable ties.",
    callback = function()
        if managers.player then
            managers.player:add_cable_ties(99)
            NiceTrainer:Toast("Cable Ties Replenished!")
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Throwables",
    tooltip = "Restores your grenades/throwables.",
    callback = function()
        if managers.player then
            managers.player:add_grenade_amount(99)
            NiceTrainer:Toast("Throwables Replenished!")
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "button", category = "Replenish", badge = "client", text = "Replenish Body Bags",
    tooltip = "Restores your body bags.",
    callback = function()
        if managers.player then
            local max_bags = (managers.player.max_body_bags and managers.player:max_body_bags()) or 3
            if managers.player._set_body_bags_amount then
                managers.player:_set_body_bags_amount(max_bags)
            elseif managers.player.add_body_bags_amount then
                managers.player:add_body_bags_amount(max_bags)
            end
            NiceTrainer:Toast("Body Bags Replenished!")
        end
    end
})
