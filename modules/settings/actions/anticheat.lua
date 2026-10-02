-- Anti-Cheat Protection Action
-- Complete host and client immunity from cheater flags and invalid loadout checks

local function isLocalOrHost(peer, peer_id)
    if not peer and not peer_id then return true end
    local session = managers.network and managers.network:session()
    local local_peer = session and session:local_peer()
    if local_peer then
        if peer and (peer == local_peer or (peer.id and peer:id() == local_peer:id())) then
            return true
        end
        if peer_id and peer_id == local_peer:id() then
            return true
        end
    end
    if Network and Network.is_server and Network:is_server() then
        if peer and (peer.is_host and peer:is_host() or peer._id == 1) then
            return true
        end
        if peer_id == 1 then
            return true
        end
    end
    if peer and (peer._id == 1 or peer._id == nil) and (not session or (Network and Network.is_server and Network:is_server())) then
        return true
    end
    return false
end

-- Steam and TDVS ownership spoofing
if _G.Steam then
    Steam.NiceTrainerOrigs = Steam.NiceTrainerOrigs or {}
    if not Steam.NiceTrainerOrigs.is_user_product_owned then
        Steam.NiceTrainerOrigs.is_user_product_owned = Steam.is_user_product_owned
    end
    function Steam:is_user_product_owned(user_id, app_id, ...)
        if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.disable_anti_cheat ~= false then
            local session = managers.network and managers.network:session()
            local local_peer = session and session:local_peer()
            if not user_id or (local_peer and (user_id == local_peer:user_id() or user_id == local_peer:account_id())) or (Network and Network.is_server and Network:is_server()) then
                return true
            end
        end
        local orig = Steam.NiceTrainerOrigs.is_user_product_owned
        return orig and orig(self, user_id, app_id, ...) or false
    end
end

if _G.TDVS then
    TDVS.NiceTrainerOrigs = TDVS.NiceTrainerOrigs or {}
    if not TDVS.NiceTrainerOrigs.is_user_product_owned then
        TDVS.NiceTrainerOrigs.is_user_product_owned = TDVS.is_user_product_owned
    end
    function TDVS:is_user_product_owned(account_id, dlc_data, ...)
        if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.disable_anti_cheat ~= false then
            local session = managers.network and managers.network:session()
            local local_peer = session and session:local_peer()
            if not account_id or (local_peer and (account_id == local_peer:user_id() or account_id == local_peer:account_id())) or (Network and Network.is_server and Network:is_server()) then
                return true
            end
        end
        local orig = TDVS.NiceTrainerOrigs.is_user_product_owned
        return orig and orig(self, account_id, dlc_data, ...) or false
    end
end

local function applyAntiCheat(value)
    local TRUE = function() return true end
    local NOOP = function() end
    local NIL  = function() return nil end

    local overrides = {
        {
            class = "PlayerManager",
            methods = {
                verify_carry     = TRUE,
                verify_equipment = TRUE,
                verify_grenade   = TRUE,
                verify_bag       = TRUE,
            },
        },
        {
            class = "NetworkPeer",
            methods = {
                mark_cheater = function(self, reason, auto_kick)
                    if isLocalOrHost(self, self._id) then
                        self._cheater = false
                        return
                    end
                    local orig = NetworkPeer.NiceTrainerOrigs and NetworkPeer.NiceTrainerOrigs.mark_cheater
                    if orig then
                        return orig(self, reason, auto_kick)
                    end
                end,
                is_cheater = function(self)
                    if isLocalOrHost(self, self._id) then
                        return false
                    end
                    return self._cheater or false
                end,
                begin_ticket_session      = TRUE,
                on_verify_ticket          = NOOP,
                end_ticket_session        = NOOP,
                change_ticket_callback    = NOOP,
                verify_job                = NOOP,
                verify_character          = NOOP,
                verify_bag                = TRUE,
                verify_deployable         = TRUE,
                verify_grenade            = TRUE,
                verify_outfit             = NOOP,
                _verify_outfit_data       = NIL,
                _verify_cheated_outfit    = NIL,
                _verify_content           = TRUE,
                tradable_verify_outfit    = NOOP,
                on_verify_tradable_outfit = NOOP,
            },
        },
        {
            class = "HUDManager",
            methods = {
                mark_cheater = function(self, peer_id)
                    if isLocalOrHost(nil, peer_id) then
                        local name_label = self._name_label_by_peer_id and self:_name_label_by_peer_id(peer_id)
                        if name_label and name_label.panel and name_label.panel:child("cheater") then
                            name_label.panel:child("cheater"):set_visible(false)
                        end
                        return
                    end
                    local orig = HUDManager.NiceTrainerOrigs and HUDManager.NiceTrainerOrigs.mark_cheater
                    if orig then
                        return orig(self, peer_id)
                    end
                end,
            },
        },
        {
            class = "HUDTeammate",
            methods = {
                set_cheater = function(self, state)
                    if self._main_player or self._id == HUDManager.PLAYER_PANEL or isLocalOrHost(nil, self._peer_id) then
                        if self._panel and self._panel:child("name") then
                            self._panel:child("name"):set_color(Color.white)
                        end
                        return
                    end
                    local orig = HUDTeammate.NiceTrainerOrigs and HUDTeammate.NiceTrainerOrigs.set_cheater
                    if orig then
                        return orig(self, state)
                    end
                end,
            },
        },
        {
            class = "BlackMarketManager",
            methods = {
                verfify_recived_crew_loadout = TRUE,
                verify_recieved_crew_loadout = TRUE,
                verfify_crew_loadout         = NOOP,
                verify_crew_loadout          = NOOP,
            },
        },
        {
            class = "ConnectionNetworkHandler",
            methods = {
                mark_cheater = function(self, peer_id, sender)
                    if isLocalOrHost(nil, peer_id) then
                        return
                    end
                    local orig = ConnectionNetworkHandler.NiceTrainerOrigs and ConnectionNetworkHandler.NiceTrainerOrigs.mark_cheater
                    if orig then
                        return orig(self, peer_id, sender)
                    end
                end,
            },
        },
        {
            class = "UnitNetworkHandler",
            methods = {
                mark_cheater = function(self, peer_id, sender)
                    if isLocalOrHost(nil, peer_id) then
                        return
                    end
                    local orig = UnitNetworkHandler.NiceTrainerOrigs and UnitNetworkHandler.NiceTrainerOrigs.mark_cheater
                    if orig then
                        return orig(self, peer_id, sender)
                    end
                end,
            },
        },
        {
            class = "NetworkMember",
            methods = { place_bag = TRUE },
        },
        {
            class = "GrenadeBase",
            methods = { check_time_cheat = TRUE },
        },
        {
            class = "ProjectileBase",
            methods = { check_time_cheat = TRUE },
        },
        {
            class = "InfamyManager",
            methods = { _verify_loaded_data = NOOP },
        },
    }
    
    for _, group in ipairs(overrides) do
        local cls = _G[group.class]
        if cls then
            pcall(function()
                if not cls.NiceTrainerOrigs then cls.NiceTrainerOrigs = {} end
                for name, fn in pairs(group.methods) do
                    if not cls.NiceTrainerOrigs[name] and cls[name] then
                        cls.NiceTrainerOrigs[name] = cls[name]
                    end
                    if value then
                        cls[name] = fn
                    elseif cls.NiceTrainerOrigs[name] ~= nil then
                        cls[name] = cls.NiceTrainerOrigs[name]
                    end
                end
            end)
        end
    end
    
    if value then
        NiceTrainer._local_marked_cheater = false
        NiceTrainer._local_cheater_reason = nil
        local session = managers.network and managers.network:session()
        if session then
            local lp = session:local_peer()
            if lp then lp._cheater = false end
            if session:server_peer() and Network and Network.is_server and Network:is_server() then
                session:server_peer()._cheater = false
            end
        end
    end
end

NiceTrainer:RegisterAction("Settings", {
    type = "toggle",
    category = "Configuration",
    id = "disable_anti_cheat",
    no_bind = true,
    badge = "safe",
    text = "Disable Anti-Cheat",
    tooltip = "Stops the game from flagging you as a cheater (removes red CHEATER tag).",
    default = true,
    callback = function(state)
        applyAntiCheat(state)
        if NiceTrainer.UpdateAntiCheatWarning then
            NiceTrainer.UpdateAntiCheatWarning()
        end
    end
})

if NiceTrainer.Settings.disable_anti_cheat == nil or NiceTrainer.Settings.disable_anti_cheat == true then
    applyAntiCheat(true)
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_EnforceAntiCheat", function()
    if NiceTrainer.Settings.disable_anti_cheat ~= false then
        applyAntiCheat(true)
    end
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_EnforceAntiCheat_Tick", function()
    if NiceTrainer.Settings.disable_anti_cheat ~= false then
        local session = managers.network and managers.network:session()
        if session then
            local lp = session:local_peer()
            if lp and lp._cheater then
                lp._cheater = false
            end
            if Network and Network.is_server and Network:is_server() then
                local sp = session:server_peer()
                if sp and sp._cheater then
                    sp._cheater = false
                end
            end
        end
    end
end)
