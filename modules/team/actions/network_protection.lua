-- ─── Network Protection, Anti-Kick & Voting ─────────────────────────────────────
-- Covers:
-- 1. Anti-Vote Kick Immunity (Rejects kick votes started against you)
-- 2. Force Restart Vote Approval (Instant restart quorum/trigger)
-- 3. Vanilla Anticheat Auto-Kick / Auto-Ban Filter (Host protection with friend whitelist)

-- ============================================================================
-- 1. Anti-Vote Kick & Auto-Kick Interceptor
-- ============================================================================
if _G.VoteManager and not VoteManager._nt_prot_hooked then
    VoteManager._nt_prot_hooked = true

    -- Intercept incoming vote network packets
    local orig_net_pkg = VoteManager.network_package
    function VoteManager:network_package(type, value, result, peer_id)
        if NiceTrainer.Settings.anti_vote_kick then
            local session = managers.network and managers.network:session()
            local local_peer = session and session:local_peer()
            local local_id = local_peer and local_peer:id()

            -- Vote event process_kick targets local player
            if type == self.VOTE_EVENT.process_kick and value == local_id then
                NiceTrainer:Toast("🛡️ Anti-Kick: Blocked kick vote started against you!", Color(1, 0.4, 0.2))
                -- Send automatic NO response to host if we are a client
                if not Network:is_server() and session then
                    session:send_to_host("voting_data", self.VOTE_EVENT.respond, self.VOTES.no, 0)
                end
                return
            end
        end

        return orig_net_pkg(self, type, value, result, peer_id)
    end

    -- Prevent automatic cheat kick when playing as client
    local orig_kick_auto = VoteManager.kick_auto
    function VoteManager:kick_auto(reason, peer, loading)
        if NiceTrainer.Settings.anti_vote_kick and not Network:is_server() then
            local session = managers.network and managers.network:session()
            local local_peer = session and session:local_peer()
            if peer and local_peer and peer == local_peer then
                NiceTrainer:Toast("🛡️ Anti-Kick: Blocked automatic cheat kick signal!", Color(1, 0.4, 0.2))
                return
            end
        end

        return orig_kick_auto(self, reason, peer, loading)
    end
end

-- ============================================================================
-- 2. Vanilla Anticheat Auto-Kick / Auto-Ban Filter (Host)
-- ============================================================================
if _G.NetworkPeer and not NetworkPeer._nt_autocheat_filter_hooked then
    NetworkPeer._nt_autocheat_filter_hooked = true

    Hooks:PostHook(NetworkPeer, "mark_cheater", "NiceTrainer_Network_AutoCheaterFilter", function(self, reason, auto_kick)
        if not Network:is_server() then return end
        if not NiceTrainer.Settings.host_autocheat_filter_enabled then return end

        local session = managers.network and managers.network:session()
        if not session then return end
        if self == session:local_peer() then return end

        local mode = NiceTrainer.Settings.host_autocheat_filter_mode or 3 -- 1: Kick Only, 2: Ban & Kick, 3: Ban & Kick (Ignore Friends)
        local is_friend = false

        pcall(function()
            if Steam and Steam.is_user_friend and self:account_id() then
                is_friend = Steam:is_user_friend(self:account_id())
            end
        end)

        if mode == 3 and is_friend then
            NiceTrainer:Toast("🛡️ Anticheat Alert: " .. self:name() .. " cheated (Friend - Skipped Ban)")
            return
        end

        if (mode == 2 or mode == 3) and managers.ban_list then
            pcall(function()
                managers.ban_list:ban(self:account_id(), self:name())
                managers.ban_list:save()
            end)
        end

        pcall(function()
            session:send_to_peers("kick_peer", self:id(), 0)
            session:on_peer_kicked(self, self:id(), 0)
        end)

        local action_str = (mode == 1) and "🚫 Auto-Kicked Cheater: " or "🔨 Auto-Banned Cheater: "
        NiceTrainer:Toast(action_str .. self:name(), Color(1, 0.3, 0.3))
    end)
end

-- ============================================================================
-- Registrations (Team Tab -> NETWORK PROTECTION & VOTING)
-- ============================================================================

NiceTrainer:RegisterAction("Team", {
    type     = "toggle",
    category = "NETWORK PROTECTION & VOTING",
    badge    = "client",
    id       = "anti_vote_kick",
    text     = "Anti-Vote Kick Immunity",
    default  = false,
    tooltip  = "Rejects and intercepts kick votes initiated against you in public lobbies, auto-voting NO to host.",
    callback = function(state)
        NiceTrainer.Settings.anti_vote_kick = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Team", {
    type            = "button",
    category        = "NETWORK PROTECTION & VOTING",
    badge           = "client",
    text            = "Force Restart Heist Vote",
    action_btn_text = "Restart",
    tooltip         = "Instantly triggers or forces approval of the heist restart vote without waiting for other players.",
    callback        = function()
        local session = managers.network and managers.network:session()
        if not session then
            NiceTrainer:Toast("No active network session.")
            return
        end

        if Network:is_server() then
            if managers.vote then
                managers.vote:restart_auto()
            elseif managers.game_play_central then
                managers.game_play_central:restart_the_game()
            end
            NiceTrainer:Toast("🔄 Heist Restarted (Host)!")
        else
            if managers.vote then
                managers.vote:restart()
                session:send_to_host("voting_data", VoteManager.VOTE_EVENT.respond, VoteManager.VOTES.yes, 0)
            end
            NiceTrainer:Toast("🔄 Restart vote submitted with instant YES approval!")
        end
    end
})

NiceTrainer:RegisterAction("Team", {
    type            = "toggle_multichoice",
    category        = "NETWORK PROTECTION & VOTING",
    badge           = "host",
    id              = "host_autocheat_filter_enabled",
    text            = "Anticheat Auto-Kick",
    default         = false,
    options         = { "Kick Only", "Ban & Kick", "Ban & Kick (Ignore Friends)" },
    choice_default  = 3,
    choice_id       = "host_autocheat_filter_mode",
    tooltip         = "Automatically removes cheaters who trip vanilla detection (invalid equipment, masks, weapons, excessive bags).",
    callback        = function(state)
        NiceTrainer.Settings.host_autocheat_filter_enabled = state
        NiceTrainer:Save()
    end,
    choice_callback = function(idx, val)
        NiceTrainer.Settings.host_autocheat_filter_mode = idx
        NiceTrainer:Save()
    end
})
