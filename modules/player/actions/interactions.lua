-- Interactions and Equipment hacks for Player Tab

NiceTrainer._orig_interaction_ext = NiceTrainer._orig_interaction_ext or {}
NiceTrainer._orig_player_manager_interactions = NiceTrainer._orig_player_manager_interactions or {}

local function apply_instant_interaction(state)
    if not _G.BaseInteractionExt then return end
    if state then
        if not NiceTrainer._orig_interaction_ext.get_timer then
            NiceTrainer._orig_interaction_ext.get_timer = BaseInteractionExt._get_timer
            BaseInteractionExt._get_timer = function() return 0.001 end
        end
    else
        if NiceTrainer._orig_interaction_ext.get_timer then
            BaseInteractionExt._get_timer = NiceTrainer._orig_interaction_ext.get_timer
            NiceTrainer._orig_interaction_ext.get_timer = nil
        end
    end
end

local function apply_instant_deployment(state)
    if not _G.PlayerManager then return end
    if state then
        if not NiceTrainer._orig_player_manager_interactions.selected_equipment_deploy_timer then
            NiceTrainer._orig_player_manager_interactions.selected_equipment_deploy_timer = PlayerManager.selected_equipment_deploy_timer
            PlayerManager.selected_equipment_deploy_timer = function() return 0.001 end
        end
    else
        if NiceTrainer._orig_player_manager_interactions.selected_equipment_deploy_timer then
            PlayerManager.selected_equipment_deploy_timer = NiceTrainer._orig_player_manager_interactions.selected_equipment_deploy_timer
            NiceTrainer._orig_player_manager_interactions.selected_equipment_deploy_timer = nil
        end
    end
end

NiceTrainer._tweak_data_player_put_on_mask_time = NiceTrainer._tweak_data_player_put_on_mask_time or nil

local function apply_fast_mask(state)
    if not tweak_data or not tweak_data.player then return end
    if state then
        NiceTrainer._tweak_data_player_put_on_mask_time = NiceTrainer._tweak_data_player_put_on_mask_time or tweak_data.player.put_on_mask_time
        tweak_data.player.put_on_mask_time = 0.25
    else
        if NiceTrainer._tweak_data_player_put_on_mask_time then
            tweak_data.player.put_on_mask_time = NiceTrainer._tweak_data_player_put_on_mask_time
        end
    end
end

local function apply_no_carry_cooldown(state)
    if not _G.PlayerManager then return end
    if state then
        if not NiceTrainer._orig_player_manager_interactions.carry_blocked_by_cooldown then
            NiceTrainer._orig_player_manager_interactions.carry_blocked_by_cooldown = PlayerManager.carry_blocked_by_cooldown
            PlayerManager.carry_blocked_by_cooldown = function() return false end
        end
    else
        if NiceTrainer._orig_player_manager_interactions.carry_blocked_by_cooldown then
            PlayerManager.carry_blocked_by_cooldown = NiceTrainer._orig_player_manager_interactions.carry_blocked_by_cooldown
            NiceTrainer._orig_player_manager_interactions.carry_blocked_by_cooldown = nil
        end
    end
end

local function refill_equipment()
    pcall(function()
        local pm = managers.player
        if not pm or not pm._equipment or not pm._equipment.selections then return end
        for index, selection in ipairs(pm._equipment.selections) do
            if selection.amount then
                for slot = 1, #selection.amount do
                    selection.amount[slot] = Application:digest_value(99, true)
                end
                pcall(function() managers.hud:set_item_amount(index, 99) end)
                pcall(function() pm:update_deployable_equipment_amount_to_peers(selection.equipment, 99) end)
            end
        end
    end)
end

local function apply_unlimited_equipment(state)
    if not _G.PlayerManager then return end
    if state then
        if not NiceTrainer._orig_player_manager_interactions.on_used_body_bag then
            NiceTrainer._orig_player_manager_interactions.on_used_body_bag = PlayerManager.on_used_body_bag
            NiceTrainer._orig_player_manager_interactions.remove_equipment = PlayerManager.remove_equipment
            NiceTrainer._orig_player_manager_interactions.remove_special = PlayerManager.remove_special
            
            PlayerManager.on_used_body_bag = function() end
            PlayerManager.remove_equipment = function(self, equipment_id, slot) end
            PlayerManager.remove_special = function(self, name) end
            
            refill_equipment()
        end
    else
        if NiceTrainer._orig_player_manager_interactions.on_used_body_bag then
            PlayerManager.on_used_body_bag = NiceTrainer._orig_player_manager_interactions.on_used_body_bag
            PlayerManager.remove_equipment = NiceTrainer._orig_player_manager_interactions.remove_equipment
            PlayerManager.remove_special = NiceTrainer._orig_player_manager_interactions.remove_special
            
            NiceTrainer._orig_player_manager_interactions.on_used_body_bag = nil
            NiceTrainer._orig_player_manager_interactions.remove_equipment = nil
            NiceTrainer._orig_player_manager_interactions.remove_special = nil
        end
    end
end

local function apply_throw_distance(state, mult)
    if not tweak_data or not tweak_data.carry or not tweak_data.carry.types then return end
    
    if state then
        if not NiceTrainer._tweak_data_carry_types_backup then
            NiceTrainer._tweak_data_carry_types_backup = deep_clone(tweak_data.carry.types)
        end
        for carry_type, data in pairs(tweak_data.carry.types) do
            if type(data) == "table" then
                tweak_data.carry.types[carry_type].throw_distance_multiplier = mult
            end
        end
    else
        if NiceTrainer._tweak_data_carry_types_backup then
            for carry_type, data in pairs(NiceTrainer._tweak_data_carry_types_backup) do
                if tweak_data.carry.types[carry_type] and type(data) == "table" then
                    tweak_data.carry.types[carry_type].throw_distance_multiplier = data.throw_distance_multiplier
                end
            end
        end
    end
end

NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Interactions", badge = "client", id = "instant_interaction", text = "Instant Interaction", tooltip = "Interact with anything instantly.", default = false, callback = apply_instant_interaction })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Interactions", badge = "client", id = "instant_deployment", text = "Instant Deployment", tooltip = "Deploy equipment instantly.", default = false, callback = apply_instant_deployment })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Interactions", badge = "client", id = "fast_mask", text = "Fast Mask", tooltip = "Put on your mask instantly.", default = false, callback = apply_fast_mask })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Interactions", badge = "client", id = "no_carry_cooldown", text = "No Carry Cooldown", tooltip = "No delay between throwing bags.", default = false, callback = apply_no_carry_cooldown })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Interactions", badge = "client", id = "unlimited_equipment", text = "Unlimited Equipment", tooltip = "You never run out of deployables, body bags, or cable ties.", default = false, callback = apply_unlimited_equipment })

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Interactions", badge = "client", id = "enable_throw_distance", text = "Throw Distance Multiplier", tooltip = "Multiplies how far you can throw bags.", default = false,
    callback = function(state)
        local mult = tonumber(NiceTrainer.Settings.throw_distance_multiplier) or 2
        apply_throw_distance(state, mult)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Throw Distance Multiplier", 1, 10, tonumber(NiceTrainer.Settings.throw_distance_multiplier) or 2, function(val)
            NiceTrainer.Settings.throw_distance_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_throw_distance then
                apply_throw_distance(true, val)
            end
        end)
    end
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

local function applyInteractionSpeed(state, val)
    if state and val > 1 then
        hijack("BaseInteractionExt", "_get_timer", function(self)
            local orig = _originals["BaseInteractionExt._get_timer"]
            return (orig and orig(self) or 1) / val
        end)
    else
        restore("BaseInteractionExt", "_get_timer")
    end
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Interactions", badge = "client", id = "enable_interaction_speed", text = "Interaction Speed Multiplier", tooltip = "How fast you interact with objects. 10 = 10x faster.", default = false,
    callback = function(state) applyInteractionSpeed(state, tonumber(NiceTrainer.Settings.interaction_speed_multiplier) or 2) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Interaction Speed Multiplier", 1, 10, tonumber(NiceTrainer.Settings.interaction_speed_multiplier) or 2, function(val)
            NiceTrainer.Settings.interaction_speed_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_interaction_speed then applyInteractionSpeed(true, val) end
        end)
    end
})

local function apply_instant_lootpile(state)
    if not _G.ElementLootPile then return end
    if state then
        hijack("ElementLootPile", "register_steal_SO", function(self)
            local orig = _originals["ElementLootPile.register_steal_SO"]
            if orig then orig(self) end
            if self._next_steal_time then
                self._next_steal_time = 0
            end
        end)
    else
        restore("ElementLootPile", "register_steal_SO")
    end
end

NiceTrainer:RegisterAction("Player", {
    type    = "toggle",
    category = "Interactions",
    badge   = "client",
    id      = "instant_lootpile",
    text    = "Instant Lootpile Reset",
    tooltip = "Loot piles (bag spawn spots) refill instantly instead of making you wait for the timer.",
    default = false,
    callback = apply_instant_lootpile
})

local function apply_ignore_item_requirements(state)
    if not _G.BaseInteractionExt then return end
    if state then
        hijack("BaseInteractionExt", "can_interact", function()
            return true
        end)
    else
        restore("BaseInteractionExt", "can_interact")
    end
end

NiceTrainer:RegisterAction("Player", {
    type    = "toggle",
    category = "Interactions",
    badge   = "client",
    id      = "ignore_item_requirements",
    text    = "Ignore Item Requirements",
    tooltip = "Lets you interact with anything without needing the correct tool, keycard, or skill. (crowbar, keycards, C4, etc.)",
    default = false,
    callback = apply_ignore_item_requirements
})

local function apply_interact_through_walls(state)
    if not _G.ObjectInteractionManager then return end
    if state then
        hijack("ObjectInteractionManager", "_raycheck_ok", function()
            return true
        end)
        hijack("ObjectInteractionManager", "raycheck_ok", function()
            return true
        end)
    else
        restore("ObjectInteractionManager", "_raycheck_ok")
        restore("ObjectInteractionManager", "raycheck_ok")
    end
end

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Interactions",
    badge    = "client",
    id       = "interact_through_walls",
    text     = "Interact Through Walls",
    tooltip  = "Bypasses line-of-sight geometry checks, allowing you to interact with doors, keycard readers, pagers, computers, drills, and loot through solid walls and closed vaults.",
    default  = false,
    callback = apply_interact_through_walls
})

local function reapply_all_interactions()
    if NiceTrainer.Settings.instant_interaction then apply_instant_interaction(true) end
    if NiceTrainer.Settings.instant_deployment then apply_instant_deployment(true) end
    if NiceTrainer.Settings.fast_mask then apply_fast_mask(true) end
    if NiceTrainer.Settings.no_carry_cooldown then apply_no_carry_cooldown(true) end
    if NiceTrainer.Settings.unlimited_equipment then apply_unlimited_equipment(true) end
    if NiceTrainer.Settings.enable_throw_distance then
        local mult = tonumber(NiceTrainer.Settings.throw_distance_multiplier) or 2
        apply_throw_distance(true, mult)
    end
    if NiceTrainer.Settings.enable_interaction_speed then applyInteractionSpeed(true, tonumber(NiceTrainer.Settings.interaction_speed_multiplier) or 2) end
    if NiceTrainer.Settings.instant_lootpile then apply_instant_lootpile(true) end
    if NiceTrainer.Settings.ignore_item_requirements then apply_ignore_item_requirements(true) end
    if NiceTrainer.Settings.interact_through_walls then apply_interact_through_walls(true) end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyInteractions", function()
    reapply_all_interactions()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_InteractionsGameUpdate", function()
    reapply_all_interactions()
end)

local function trigger_nearby_interactions(range_cm)
    local player_unit = managers.player and managers.player:player_unit()
    if not alive(player_unit) then
        NiceTrainer:Toast("You must be in a heist to interact.")
        return
    end

    local interactive_units = managers.interaction and managers.interaction._interactive_units
    if not interactive_units or #interactive_units == 0 then
        NiceTrainer:Toast("No interactive objects found.")
        return
    end

    local player_pos = player_unit:position()
    local max_dist = range_cm or 2000 -- default 20m
    local count = 0

    for _, u in ipairs(interactive_units) do
        if alive(u) and u:interaction() and u:interaction():active() then
            local dist = mvector3.distance(player_pos, u:position())
            if dist <= max_dist then
                local ok = pcall(function()
                    u:interaction():interact(player_unit)
                end)
                if ok then
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        NiceTrainer:Toast(string.format("Interacted with %d objects nearby!", count))
    else
        NiceTrainer:Toast("No active interactive objects within range.")
    end
end

NiceTrainer:RegisterAction("Player", {
    type            = "button",
    category        = "Interactions",
    badge           = "client",
    id              = "interact_nearby",
    text            = "Interact Nearby Objects",
    action_btn_text = "Trigger",
    tooltip         = "Instantly triggers all interactive objects within 20 meters (doors, keycard readers, bags, computers, planks, etc.). Can be bound to a hotkey.",
    callback        = function()
        trigger_nearby_interactions(2000)
    end
})
