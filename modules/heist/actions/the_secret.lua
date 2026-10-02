-- The White House (vit) - The Secret & Uno Puzzle Door Solver
local function get_uno_puzzle_door()
    for _, unit in pairs(World:find_units_quick("all")) do
        if alive(unit) and unit:base() and unit:base()._outer and unit:base()._middle and unit:base()._inner then
            return unit
        end
    end
    return nil
end

local function solve_uno_puzzle_step(door_unit)
    if not alive(door_unit) then return false end
    local base = door_unit:base()
    if not base._solution then
        if base.init_puzzle then
            base:init_puzzle()
        end
    end

    local sol = base._solution
    if not sol then return false end

    -- Find matching ring stop combination (0-25)
    for o = 0, 25 do
        for m = 0, 25 do
            for i = 0, 25 do
                local key = (o .. ":" .. m .. ":" .. i):key()
                if key == sol then
                    base._outer._current_stop = o
                    base._outer:_target_stop(o)
                    base._middle._current_stop = m
                    base._middle:_target_stop(m)
                    base._inner._current_stop = i
                    base._inner:_target_stop(i)
                    base:submit_answer()
                    return true, o, m, i
                end
            end
        end
    end
    return false
end

-- Action: Solve Current Riddle
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "The Secret (vit)",
    level_id = { "vit", "whiterun", "white_house" },
    badge = "host",
    text = "Auto-Solve Current Riddle",
    tooltip = "Aligns the 3 Mayan rings to the exact solution of the active riddle and submits the answer.",
    action_btn_text = "Solve",
    callback = function()
        local door_unit = get_uno_puzzle_door()
        if not door_unit then
            NiceTrainer:Toast("Uno Puzzle Door not found in the underground chamber.")
            return
        end

        local base = door_unit:base()
        local riddle_num = base._current_riddle or 1
        local ok, o, m, i = solve_uno_puzzle_step(door_unit)
        if ok then
            NiceTrainer:Toast(string.format("Riddle %d Solved! Rings: [%d, %d, %d]", riddle_num, o, m, i))
        else
            NiceTrainer:Toast("Could not calculate ring solution for current riddle.")
        end
    end
})

-- Action: Solve All 4 Riddles / Open Final Ark
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "The Secret (vit)",
    level_id = { "vit", "whiterun", "white_house" },
    badge = "host",
    text = "Auto-Solve ALL 4 Riddles & Open Ark",
    tooltip = "Instantly solves all 4 Mayan door riddles in sequence and unlocks the final ark room.",
    action_btn_text = "Unlock",
    callback = function()
        local door_unit = get_uno_puzzle_door()
        if not door_unit then
            -- Fallback: execute mission sequence / elements
            local solved = false
            if managers.mission and managers.mission._scripts then
                for _, script in pairs(managers.mission._scripts) do
                    for _, elem in pairs(script:elements()) do
                        local name = string.lower(elem:editor_name() or "")
                        if name:find("all_riddles_solved", 1, true) or name:find("uno_door_solved", 1, true) or name:find("ark_open", 1, true) then
                            pcall(function() elem:on_executed() end)
                            solved = true
                        end
                    end
                end
            end
            if solved then
                NiceTrainer:Toast("Secret sequence executed via mission elements!")
            else
                NiceTrainer:Toast("Uno Puzzle Door not found. Make sure you are in the underground chamber.")
            end
            return
        end

        pcall(function()
            if door_unit:damage() and door_unit:damage():has_sequence("all_riddles_solved") then
                door_unit:damage():run_sequence_simple("all_riddles_solved")
            else
                for step = 1, 4 do
                    solve_uno_puzzle_step(door_unit)
                end
            end
        end)
        NiceTrainer:Toast("All 4 Mayan Riddles Solved! Secret Vault opening...")
    end
})

-- Action: Revive Players in Secret Chamber
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "The Secret (vit)",
    level_id = { "vit", "whiterun", "white_house" },
    badge = "host",
    text = "Revive Team in Secret Chamber",
    tooltip = "Revives all players and bots using the official Uno Puzzle revival mechanic.",
    action_btn_text = "Revive",
    callback = function()
        local door_unit = get_uno_puzzle_door()
        if door_unit and door_unit:base() and door_unit:base().revive_player then
            door_unit:base():revive_player()
            NiceTrainer:Toast("Team revived via Uno Chamber mechanic!")
        else
            for _, character in ipairs(managers.criminals:characters()) do
                if alive(character.unit) and character.unit:character_damage() and character.unit:character_damage():need_revive() then
                    character.unit:character_damage():revive(nil, true)
                end
            end
            local lp = managers.player and managers.player:player_unit()
            if alive(lp) and lp:character_damage() and lp:character_damage():need_revive() then
                lp:character_damage():revive(true)
            end
            NiceTrainer:Toast("Team revived!")
        end
    end
})
