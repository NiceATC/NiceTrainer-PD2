NiceTrainer:RegisterAction("Heist", {
    type = "button", category = "Mission", badge = "client", text = "Force End Mission", tooltip = "Instantly ends the current mission as a win (works as host and client).",
    callback = function()
        if not GameSetup then
            NiceTrainer:Toast("No active mission")
            return
        end
        local session = managers.network and managers.network:session()
        if not session then
            NiceTrainer:Toast("No active network session")
            return
        end

        if Network:is_server() then
            -- Host authoritative mission end
            local unready_peers = {}
            for _, peer in pairs(session._peers) do
                if not (peer:ip_verified() and peer:synched()) then
                    table.insert(unready_peers, peer:name() or "unknown peer")
                end
            end
            if #unready_peers > 0 then
                NiceTrainer:Toast("Aborted - not all peers ready: " .. table.concat(unready_peers, ", "))
                return
            end

            local num_winners = session:amount_of_alive_players()
            local sends_left = 3
            local function send_once()
                session:send_to_peers("mission_ended", true, num_winners)
                sends_left = sends_left - 1
                if sends_left > 0 then
                    DelayedCalls:Add("nt_force_end_mission_retry", 0.5, send_once)
                else
                    game_state_machine:change_state_by_name("victoryscreen", { num_winners = num_winners, personal_win = true })
                end
            end
            send_once()
            NiceTrainer:Toast("Forcing mission end (Host)...")
        else
            -- Client bypass: trigger mission end / escape elements via network RPC
            local player = managers.player and managers.player:player_unit()
            local triggered = 0
            if managers.mission and managers.mission._scripts then
                for _, script in pairs(managers.mission._scripts) do
                    for _, elem in pairs(script:elements()) do
                        local name = string.lower(elem:editor_name() or "")
                        local is_end = (elem._values and (elem._values.state == "success" or elem._values.state == "leave"))
                                    or name:find("victory", 1, true) or name:find("escape", 1, true) or name:find("end_heist", 1, true) or name:find("mission_end", 1, true)
                        if is_end then
                            pcall(function()
                                session:send_to_host("to_server_mission_element_trigger", elem:id(), player)
                                session:send_to_host("to_server_area_event", 1, elem:id(), player)
                            end)
                            triggered = triggered + 1
                        end
                    end
                end
            end
            if triggered > 0 then
                NiceTrainer:Toast("Triggered escape/victory on host!")
            else
                NiceTrainer:Toast("Could not find escape trigger on this map.")
            end
        end
    end
})
