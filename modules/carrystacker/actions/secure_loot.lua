-- ─── Secure Loot Features ───────────────────────────────────────────────────────
-- 1. Instant Secure All (Host/Client real bags & unbagged loot with full HUD & objective credit)
-- 2. Secure All Bags (Semi-legit automated pickup & depot drop)
-- 3. Fabricate Loot (Direct cash/loot injection)
-- 4. Auto-Secure via Area Trigger (Any world bag auto-counts at depot)

local function safe_alive(unit)
    return unit and alive(unit)
end

-- Find all carry_data-bearing bags currently on the map that can be secured
local function find_securable_bags()
    local found = {}
    for _, unit in pairs(World:find_units_quick("all", 14)) do
        if safe_alive(unit) then
            local cd = unit.carry_data and unit:carry_data()
            if cd and cd:can_secure() and cd:value() > 0 then
                local cid = cd:carry_id()
                local is_small = tweak_data.carry and tweak_data.carry.small_loot and tweak_data.carry.small_loot[cid]
                if not is_small and cid ~= "person" and unit.interaction then
                    table.insert(found, unit)
                end
            end
        end
    end
    return found
end

-- Mapping of interaction tweak_data ids -> carry labels (raw/unbagged loot)
local INTERACTION_TO_CARRY = {
    weapon_case = "weapon", weapon_case_axis_z = "weapon",
    samurai_armor = "samurai_suit", gen_pku_warhead_box = "warhead",
    hold_open_case = "drone_control_helmet", cut_glass = "showcase",
    diamonds_pickup = "diamonds_dah", red_diamond_pickup = "red_diamond",
    red_diamond_pickup_no_axis = "red_diamond", hold_open_shopping_bag = "shopping_bag",
    hold_take_toy = "robot_toy", hold_take_wine = "ordinary_wine",
    hold_take_expensive_wine = "expensive_vine", hold_take_diamond_necklace = "diamond_necklace",
    hold_take_vr_headset = "vr_headset", hold_take_shoes = "women_shoes",
    hold_take_old_wine = "old_wine",
    money_wrap = "money", gold_pile = "gold", hold_take_painting = "painting",
    gen_pku_cocaine = "coke", gen_pku_artifact_statue = "artifact_statue",
    crate_loot = "crate", crate_loot_crowbar = "crate",
    diamond_pickup = "diamond", money_wrap_single_bundle = "money",
}

local function is_loot_interaction(id)
    if not id then return nil end
    if INTERACTION_TO_CARRY[id] then return INTERACTION_TO_CARRY[id] end
    if id:find("pku_", 1, true) then return "pku_item" end
    return nil
end

-- Find all raw (unbagged) interactable loot units
local function find_raw_loot_units()
    local found = {}
    for _, unit in pairs(World:find_units_quick("all")) do
        if safe_alive(unit) and unit.interaction then
            local inter = unit:interaction()
            if inter and inter.tweak_data and is_loot_interaction(inter.tweak_data) and inter:active() then
                table.insert(found, unit)
            end
        end
    end
    return found
end

-- Find the depot area trigger position
local function find_depot_position()
    if not (managers and managers.mission) then return nil end
    for _, script in pairs(managers.mission:scripts()) do
        for _, el in pairs(script:elements()) do
            local v = el:values()
            if v and (v.instigator == "loot" or v.instigator == "unique_loot") and el:enabled() then
                if not v.use_shape_element_ids and v.position then
                    return v.position
                end
            end
        end
    end
    return nil
end

-- ============================================================================
-- 1. Instant Secure All (Host / Client)
-- ============================================================================
local function instant_secure_all()
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Must be in a heist!")
        return
    end

    local bags = find_securable_bags()
    local raw  = find_raw_loot_units()
    if #bags == 0 and #raw == 0 then
        NiceTrainer:Toast("No securable loot found on map.")
        return
    end

    local count = 0
    local depot = find_depot_position()

    -- Process bags
    for _, unit in ipairs(bags) do
        if safe_alive(unit) then
            local cd = unit:carry_data()
            local cid = cd and cd:carry_id()
            if cid then
                local mult = cd:multiplier() or 1
                local peer_id = managers.network and managers.network:session() and managers.network:session():local_peer() and managers.network:session():local_peer():id()
                
                -- Secure with silent = false so HUD notifications, cash, and XP update visibly
                pcall(function()
                    managers.loot:secure(cid, mult, false, peer_id)
                end)

                if managers.mission then
                    pcall(function() managers.mission:call_global_event("secured_loot", cid) end)
                end

                if Network:is_server() then
                    pcall(function()
                        cd:disarm()
                        cd:set_value(0)
                        if unit:damage() and unit:damage():has_sequence("secured") then
                            unit:damage():run_sequence_simple("secured")
                        end
                        World:delete_unit(unit)
                    end)
                else
                    if depot then
                        pcall(function() unit:set_position(depot + Vector3(0, 0, 10)) end)
                    end
                end
                count = count + 1
            end
        end
    end

    -- Process unbagged / raw pickups
    local player = managers.player and managers.player:player_unit()
    for _, unit in ipairs(raw) do
        if safe_alive(unit) then
            local inter = unit:interaction()
            local cid = inter and is_loot_interaction(inter.tweak_data) or "money"
            if Network:is_server() then
                pcall(function()
                    managers.loot:secure(cid, 1, false)
                    World:delete_unit(unit)
                end)
            else
                if player and inter and inter.interact then
                    pcall(function() inter:interact(player) end)
                else
                    pcall(function() managers.loot:secure(cid, 1, false) end)
                end
            end
            count = count + 1
        end
    end

    NiceTrainer:Toast(count .. " loot items secured!")
end

-- ============================================================================
-- 2. Semi-Legit Secure All Bags
-- ============================================================================
local _secure_running = false
local _secure_cancel  = false
local _secure_delay   = 2.0

local function interact_and_drop(unit)
    if not (safe_alive(unit) and unit.interaction) then return false end
    local inter = unit:interaction()
    if not inter then return false end

    local player = managers.player and managers.player:player_unit()
    if not player then return false end

    pcall(function()
        local start_ok, _, timer = pcall(function() return inter:interact_start(player) end)
        if start_ok and timer then inter:interact(player) end
    end)

    if managers.player:is_carrying() then
        local depot = find_depot_position()
        if depot then
            local cam_rot = player:camera() and player:camera():rotation() or Rotation()
            managers.player:warp_to(depot + Vector3(0, 0, 10), cam_rot)
        end
        managers.player:force_drop_carry()
        return true
    end
    return false
end

local function _process_next(units, idx, on_done)
    if _secure_cancel or idx > #units then
        on_done()
        return
    end

    local unit = units[idx]
    if safe_alive(unit) then
        local cd = unit.carry_data and unit:carry_data()
        if Network:is_server() and cd and cd:can_secure() and cd:value() > 0 then
            local cid = cd:carry_id()
            pcall(function() managers.loot:secure(cid, 1, false) end)
            pcall(function() World:delete_unit(unit) end)
        else
            interact_and_drop(unit)
        end
    end

    DelayedCalls:Add("NiceTrainer_SecureLoot_" .. idx, _secure_delay, function()
        _process_next(units, idx + 1, on_done)
    end)
end

local function run_secure_all()
    if _secure_running then return end
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Must be in a heist!")
        return
    end

    _secure_running = true
    _secure_cancel  = false

    local bags = find_securable_bags()
    local raw  = find_raw_loot_units()
    local all  = {}
    for _, u in ipairs(bags) do table.insert(all, u) end
    for _, u in ipairs(raw)  do table.insert(all, u) end

    if #all == 0 then
        NiceTrainer:Toast("No loot found on the map.")
        _secure_running = false
        return
    end

    NiceTrainer:Toast("Securing " .. #all .. " loot items...")

    _process_next(all, 1, function()
        _secure_running = false
        _secure_cancel  = false
        NiceTrainer:Toast("Secure All done!")
    end)
end

-- ============================================================================
-- 3. Area Trigger Auto-Secure (Hook)
-- ============================================================================
local function apply_secure_loot_hooks()
    if _G.ElementAreaTrigger and not ElementAreaTrigger._nt_secure_hooked then
        ElementAreaTrigger._nt_secure_hooked = true

        local orig_project = ElementAreaTrigger.project_instigators
        function ElementAreaTrigger:project_instigators()
            local instigators = orig_project(self)
            if NiceTrainer.Settings.area_trigger_secure
                and (self._values.instigator == "loot" or self._values.instigator == "unique_loot") then
                for _, unit in pairs(World:find_units_quick("all", 14)) do
                    if safe_alive(unit) and unit:carry_data() then
                        table.insert(instigators, unit)
                    end
                end
            end
            return instigators
        end
    end
end

apply_secure_loot_hooks()

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_SecureLoot_LevelLoad", function()
    apply_secure_loot_hooks()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_SecureLoot_GameUpdate", function()
    apply_secure_loot_hooks()
end)

-- ============================================================================
-- 4. Most Expensive Bag Calculation
-- ============================================================================
local function most_expensive_bag()
    local best_val, best_name = 0, nil
    if tweak_data and tweak_data.money_manager and tweak_data.money_manager.bag_values then
        for name, val in pairs(tweak_data.money_manager.bag_values) do
            local v = Application.digest_value and Application:digest_value(val, false) or 0
            if v > best_val then
                best_val, best_name = v, name
            end
        end
    end
    return best_name or "hope_diamond"
end

-- ============================================================================
-- Registrations (CarryStacker Tab -> Secure Loot)
-- ============================================================================

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "button",
    category = "Secure Loot",
    badge    = "client",
    text     = "Instant Secure All",
    tooltip  = "Instantly secures all loose bags and unbagged loot on the map for maximum payout.",
    callback = function()
        instant_secure_all()
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Secure Loot",
    badge    = "client",
    id       = "secure_all_running",
    text     = "Secure All Bags (Semi-legit)",
    tooltip  = "Sequentially picks up and drops all bags at the depot. Toggle on to run, toggle off to cancel.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.secure_all_running = state
        NiceTrainer:Save()
        if state then
            run_secure_all()
        else
            if _secure_running then
                _secure_cancel = true
            end
        end
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "slider",
    category = "Secure Loot",
    badge    = "client",
    id       = "secure_loot_delay",
    text     = "Bag Delay (sec)",
    tooltip  = "Delay between each bag during Semi-legit Secure All.",
    min      = 1,
    max      = 5,
    default  = 2,
    callback = function(val)
        _secure_delay = val
        NiceTrainer.Settings.secure_loot_delay = val
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type            = "inputbox",
    category        = "Secure Loot",
    badge           = "client",
    id              = "fabricate_loot_amount",
    text            = "Bags to Fabricate",
    tooltip         = "Credits this many bags of the highest-value loot directly into the heist payout.",
    min             = 1,
    max             = 200,
    default         = 10,
    action_btn_text = "Fabricate",
    callback        = function(val)
        if not NiceTrainer:IsInHeist() then
            NiceTrainer:Toast("Must be in a heist!")
            return
        end
        local bag = most_expensive_bag()
        for i = 1, val do
            pcall(function() managers.loot:secure(bag, 1, false) end)
        end
        NiceTrainer:Toast(val .. "x " .. bag .. " secured!")
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Secure Loot",
    badge    = "host",
    id       = "area_trigger_secure",
    text     = "Auto-Secure via Area Trigger",
    tooltip  = "Injects all world bags into the loot depot trigger. Any bag on the map auto-secures as if dropped in the van.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.area_trigger_secure = state
        NiceTrainer:Save()
    end
})
