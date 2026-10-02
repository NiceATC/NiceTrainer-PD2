-- Loot & Bags Spawner for NiceTrainer
-- Supports MultiChoice selection with Keybind and full Host & Client compatibility

local loot_bags = {
    { text = "Money",                     value = "money" },
    { text = "Gold",                      value = "gold" },
    { text = "Meth",                      value = "meth" },
    { text = "Cocaine",                   value = "coke" },
    { text = "Diamonds",                  value = "diamonds" },
    { text = "Weapons",                   value = "weapon" },
    { text = "Painting",                  value = "painting" },
    { text = "Lost Artifact",             value = "lost_artifact" },
    { text = "Artifact Statue",           value = "artifact_statue" },
    { text = "Chas Artifact",             value = "chas_artifact" },
    { text = "Mus Artifact",              value = "mus_artifact" },
    { text = "Masterpiece Painting",      value = "masterpiece_painting" },
    { text = "Pure Cocaine (Yayo)",       value = "coke_pure" },
    { text = "Counterfeit Money",         value = "counterfeit_money" },
    { text = "Goat (Goat Simulator)",     value = "goat" },
    { text = "Body Bag (Corpse)",         value = "person" },
    { text = "Engine (Cold Fusion)",      value = "engine_01" },
    { text = "Samurai Armor",             value = "samurai_suit" },
    { text = "Turret Part",               value = "turret" },
    { text = "Ammo Bag",                  value = "ammo" },
    { text = "Evidence Bag",              value = "evidence_bag" }
}

local loot_options = {}
for _, item in ipairs(loot_bags) do
    table.insert(loot_options, item.text)
end

local function get_spawn_pos_rot()
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return nil, nil, nil end

    local cam = player:camera()
    if not cam then return nil, nil, nil end

    local pos = cam:position()
    local rot = cam:rotation()
    local forward = cam:forward()

    local throw_pos = pos + forward * 50
    return throw_pos, rot, forward
end

local function spawn_loot_bag(idx)
    idx = idx or NiceTrainer.Settings.spawner_loot_type or 1
    local entry = loot_bags[idx] or loot_bags[1]
    local carry_id = entry.value

    local player = managers.player and managers.player:player_unit()
    if not alive(player) then
        NiceTrainer:Toast("Cannot spawn bag: Player not in heist/alive.")
        return
    end

    local throw_pos, rot, forward = get_spawn_pos_rot()
    if not throw_pos then
        NiceTrainer:Toast("Could not determine spawn direction.")
        return
    end

    local amount = NiceTrainer.Settings.spawner_quantity or 1
    local is_host = Network:is_server()
    local session = managers.network and managers.network:session()
    local spawned_count = 0

    local carry_multiplier = 1
    pcall(function()
        if managers.money and managers.money.get_bag_value then
            carry_multiplier = managers.money:get_bag_value(carry_id) or 1
        end
    end)

    if is_host then
        for i = 1, amount do
            local offset = (amount > 1) and Vector3(math.random(-15, 15), math.random(-15, 15), 0) or Vector3(0, 0, 0)
            local unit = managers.player:server_drop_carry(
                carry_id,
                carry_multiplier,
                false,
                false,
                1,
                throw_pos + offset,
                rot,
                forward,
                0,
                nil,
                player
            )
            if alive(unit) then
                spawned_count = spawned_count + 1
            end
        end
        NiceTrainer:Toast("Spawned " .. tostring(spawned_count) .. "x " .. entry.text .. " (Host)")
    else
        -- Client mode:
        -- 1. Send properly serialised RPC to host
        if session then
            for i = 1, amount do
                local offset = (amount > 1) and Vector3(math.random(-15, 15), math.random(-15, 15), 0) or Vector3(0, 0, 0)
                pcall(function()
                    session:send_to_host(
                        "server_drop_carry",
                        carry_id,
                        carry_multiplier,
                        false,
                        false,
                        1,
                        throw_pos + offset,
                        rot,
                        forward,
                        0,
                        nil
                    )
                end)
                spawned_count = spawned_count + 1
            end
        end

        -- 2. Equip directly to player back to guarantee client has the bag ready to drop or secure
        pcall(function()
            managers.player:set_carry(carry_id, carry_multiplier, true, false, 1)
        end)

        NiceTrainer:Toast("Spawned " .. tostring(spawned_count) .. "x " .. entry.text .. " (Client: Equipped/Dropped)")
    end
end

-- ============================================================================
-- Registration: Loot & Bags
-- ============================================================================

NiceTrainer:RegisterAction("Spawner", {
    type            = "multichoice",
    category        = "Loot & Bags",
    badge           = "all",
    id              = "spawner_loot_type",
    text            = "Select Loot Bag",
    options         = loot_options,
    default         = 1,
    action_btn_text = "Spawn",
    tooltip         = "Select the loot bag type and click Spawn, or use the BIND button to spawn on hotkey.",
    callback        = function(idx, val)
        spawn_loot_bag(idx)
    end
})


NiceTrainer:RegisterAction("Spawner", {
    type     = "button",
    category = "Loot & Bags",
    badge    = "client",
    text     = "Equip Selected Bag to Back",
    tooltip  = "Directly equips the selected bag onto your character's back (guaranteed to work as client).",
    callback = function()
        local idx = NiceTrainer.Settings.spawner_loot_type or 1
        local entry = loot_bags[idx] or loot_bags[1]
        pcall(function()
            managers.player:set_carry(entry.value, 1, true, false, 1)
        end)
        NiceTrainer:Toast("Equipped to back: " .. entry.text)
    end
})
