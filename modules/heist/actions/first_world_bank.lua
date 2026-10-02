-- First World Bank (pal) - Overdrill 6-Tile Secret Puzzle Solver
local function trigger_element_by_name_or_id(pattern, elem_id)
    if not managers.mission then return false end
    for _, script in pairs(managers.mission._scripts) do
        for id, elem in pairs(script:elements()) do
            local name = string.lower(elem:editor_name() or "")
            if (elem_id and id == elem_id) or (pattern and name:find(pattern, 1, true)) then
                if Network:is_server() then
                    elem:on_executed()
                else
                    managers.network:session():send_to_host("to_server_mission_element_trigger", elem:id(), managers.player:player_unit())
                end
                return true
            end
        end
    end
    return false
end

-- Action: Auto-Solve Overdrill Secret Tiles
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Overdrill (pal)",
    level_id = { "pal", "red2", "first_world_bank" },
    badge = "host",
    text = "Auto-Solve Overdrill Secret Tiles",
    tooltip = "Executes the 6 secret floor/wall tile interactions in the correct sequence to open the secret gold vault.",
    action_btn_text = "Solve",
    callback = function()
        local triggered_count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("overdrill_correct", 1, true) or name:find("overdrill_tile", 1, true) or name:find("secret_plate", 1, true) or name:find("secret_tile", 1, true) then
                        pcall(function()
                            if Network:is_server() then
                                elem:on_executed()
                            else
                                managers.network:session():send_to_host("to_server_mission_element_trigger", elem:id(), managers.player:player_unit())
                            end
                            triggered_count = triggered_count + 1
                        end)
                    end
                end
            end
        end

        if triggered_count > 0 then
            NiceTrainer:Toast(string.format("Overdrill tiles sequence executed (%d triggers)!", triggered_count))
        else
            trigger_element_by_name_or_id("overdrill_win")
            trigger_element_by_name_or_id("open_secret_vault")
            NiceTrainer:Toast("Executed Overdrill secret completion sequence!")
        end
    end
})

-- Action: Instantly Open Secret Vault Door
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Overdrill (pal)",
    level_id = { "pal", "red2", "first_world_bank" },
    badge = "host",
    text = "Instantly Open Overdrill Secret Vault",
    tooltip = "Opens the secret vault door without waiting on the 2000s drill timer or triggering fail traps.",
    action_btn_text = "Open",
    callback = function()
        local opened = false
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("door_secret", 1, true) or name:find("vault_secret_open", 1, true) or name:find("open_secret", 1, true) or name:find("drill_done", 1, true) then
                        pcall(function()
                            elem:on_executed()
                            opened = true
                        end)
                    end
                end
            end
        end

        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) and unit:damage() then
                local name = ""
                pcall(function() name = unit:name().s and unit:name():s() or tostring(unit:name()) end)
                name = string.lower(name)
                if name:find("secret_vault", 1, true) or name:find("overdrill_door", 1, true) or name:find("vault_door", 1, true) then
                    pcall(function()
                        if unit:damage():has_sequence("open") then
                            unit:damage():run_sequence_simple("open")
                            opened = true
                        end
                    end)
                end
            end
        end

        if opened then
            NiceTrainer:Toast("Secret Overdrill Vault Door Opened!")
        else
            NiceTrainer:Toast("Could not find secret vault door. Make sure you are in First World Bank.")
        end
    end
})
