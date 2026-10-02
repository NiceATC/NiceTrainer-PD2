NiceTrainer:RegisterAction("Pre-planning", {
    type = "button", category = "Mission", badge = "client", text = "Force Everyone Ready", tooltip = "Marks every player as ready so the mission can start.",
    callback = function()
        local session = managers.network and managers.network:session()
        if not session then
            NiceTrainer:Toast("No active network session")
            return
        end
        for _, peer in pairs(session._peers) do
            local peer_id = peer:id()
            session:on_set_member_ready(peer_id, true, true, false)
            session:send_to_peers("set_member_ready", peer_id, 1, 1, "")
        end
        NiceTrainer:Toast("Forced everyone ready!")
    end
})

NiceTrainer:RegisterAction("Pre-planning", {
    type = "button", category = "Mission", badge = "host", text = "Force Mission Start", tooltip = "Instantly starts the mission for everyone, skipping the ready-up screen. Host only.",
    callback = function()
        local session = managers.network and managers.network:session()
        if not session then
            NiceTrainer:Toast("No active network session")
            return
        end
        session:spawn_players(true)
        NiceTrainer:Toast("Forced mission start!")
    end
})


