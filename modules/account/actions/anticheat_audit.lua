-- ─── Anti-Cheat Checker (Security Audit) ──────────────────────────────────────
-- Modernized Security Audit & Real-Time On-Screen Menu/HUD Warning Indicator.
-- Evaluates all active features against PAYDAY 2 anticheat mechanisms and
-- respects protection overrides from disable_anti_cheat and Outfit Spoof.

local function getDetectableFeatures()
    local list = {}
    local is_spoof_on = NiceTrainer.Settings.spoof_equipment == true
    local ac_disabled = NiceTrainer.Settings.disable_anti_cheat == true

    -- 1. DLC Unlocker
    local dlc_on = NiceTrainer.Settings.dlc_unlocker == true
    local dlc_risk = "SAFE"
    local dlc_desc = "Clean: DLC Unlocker is not active."
    local dlc_prot = false

    if is_spoof_on then
        dlc_risk = "PROTECTED"
        dlc_prot = true
        dlc_desc = dlc_on
            and "Protected: Outfit Spoof masks DLC weapons, masks, skins & loadouts in network sync."
            or "Protected: Inactive (Armed). Outfit Spoof is enabled for network safety."
    elseif dlc_on then
        if ac_disabled then
            dlc_risk = "MEDIUM"
            dlc_prot = false
            dlc_desc = "Partially Protected: Local anti-cheat disabled (host safe). Remote hosts will detect unowned DLC unless Outfit Spoof is enabled."
        else
            dlc_risk = "HIGH"
            dlc_prot = false
            dlc_desc = "High Risk: Unowned DLC weapons or masks trigger the CHEATER tag on remote hosts. Enable Outfit Spoof to fix."
        end
    elseif ac_disabled then
        dlc_risk = "PROTECTED"
        dlc_prot = true
        dlc_desc = "Protected: Inactive. Disable Anti-Cheat is active."
    end

    table.insert(list, {
        name = "DLC Unlocker",
        category = "Account",
        active = dlc_on,
        protected = dlc_prot,
        risk_level = dlc_risk,
        description = dlc_desc
    })

    -- 2. Skin Unlocker
    local skin_on = NiceTrainer.Settings.skin_unlocker == true
    local skin_risk = "SAFE"
    local skin_desc = "Clean: Skin Unlocker is not active."
    local skin_prot = false

    if is_spoof_on or ac_disabled then
        skin_risk = "PROTECTED"
        skin_prot = true
        skin_desc = skin_on
            and (is_spoof_on and "Protected: Weapon skins & cosmetics are stripped from network sync by Outfit Spoof." or "Protected: Disable Anti-Cheat bypasses tradable outfit verification.")
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat / Outfit Spoof."
    elseif skin_on then
        skin_risk = "MEDIUM"
        skin_prot = false
        skin_desc = "Medium Risk: Tradable skin verifiers may flag unowned skins if remote host checks. Enable Outfit Spoof to fix."
    end

    table.insert(list, {
        name = "Skin Unlocker",
        category = "Account",
        active = skin_on,
        protected = skin_prot,
        risk_level = skin_risk,
        description = skin_desc
    })

    -- 3. Unlimited Equipment
    local unl_eq = NiceTrainer.Settings.unlimited_equipment == true
    local unl_risk = "SAFE"
    local unl_desc = "Clean: Unlimited Equipment is not active."
    local unl_prot = false

    if ac_disabled then
        unl_risk = "PROTECTED"
        unl_prot = true
        unl_desc = unl_eq
            and "Protected: Disable Anti-Cheat bypasses verify_equipment and verify_deployable."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif unl_eq then
        unl_risk = "HIGH"
        unl_prot = false
        unl_desc = "High Risk: Deploying excessive equipment triggers host anti-cheat (verify_equipment)."
    end

    table.insert(list, {
        name = "Unlimited Equipment",
        category = "Player",
        active = unl_eq,
        protected = unl_prot,
        risk_level = unl_risk,
        description = unl_desc
    })

    -- 4. Bag Stacker / Carry Stacker
    local cs_on = NiceTrainer.Settings.bag_stacker_enabled == true or NiceTrainer.Settings.carrystacker_enabled == true
    local cs_risk = "SAFE"
    local cs_desc = "Clean: Carry Stacker is not active."
    local cs_prot = false

    if ac_disabled then
        cs_risk = "PROTECTED"
        cs_prot = true
        cs_desc = cs_on
            and "Protected: Disable Anti-Cheat bypasses verify_carry, verify_bag, and place_bag."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif cs_on then
        cs_risk = "HIGH"
        cs_prot = false
        cs_desc = "High Risk: Carrying multiple bags simultaneously triggers host anti-cheat (verify_carry)."
    end

    table.insert(list, {
        name = "Carry Stacker",
        category = "Carry Stacker",
        active = cs_on,
        protected = cs_prot,
        risk_level = cs_risk,
        description = cs_desc
    })

    -- 5. Equipment / Bag Spawner
    local spawner_on = NiceTrainer.Settings.spawner_active == true
    local spw_risk = "SAFE"
    local spw_desc = "Clean: Spawner is not active."
    local spw_prot = false

    if ac_disabled then
        spw_risk = "PROTECTED"
        spw_prot = true
        spw_desc = spawner_on
            and "Protected: Disable Anti-Cheat bypasses verify_deployable and bag checks."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif spawner_on then
        spw_risk = "HIGH"
        spw_prot = false
        spw_desc = "High Risk: Spawning unauthorized bags or deployables directly into the mission."
    end

    table.insert(list, {
        name = "Equipment / Bag Spawner",
        category = "Spawner",
        active = spawner_on,
        protected = spw_prot,
        risk_level = spw_risk,
        description = spw_desc
    })

    -- 6. Skill Tree / Unlock All Skills
    local skill_hack = NiceTrainer.Settings.unlock_all_skills == true or NiceTrainer.Settings.all_skills == true or NiceTrainer.Settings.skill_points_hack == true
    local sk_risk = "SAFE"
    local sk_desc = "Clean: No excessive skill points active."
    local sk_prot = false

    if ac_disabled then
        sk_risk = "PROTECTED"
        sk_prot = true
        sk_desc = skill_hack
            and "Protected: Disable Anti-Cheat neutralizes Infamy and skill verification."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif skill_hack then
        sk_risk = "HIGH"
        sk_prot = false
        sk_desc = "High Risk: Having more skills than allowed triggers the native CHEATER tag."
    end

    table.insert(list, {
        name = "Skill Tree / Unlock All Skills",
        category = "Account",
        active = skill_hack,
        protected = sk_prot,
        risk_level = sk_risk,
        description = sk_desc
    })

    -- 7. Instant Interaction
    local inst_int = NiceTrainer.Settings.instant_interaction == true
    local int_risk = "SAFE"
    local int_desc = "Clean: Instant interaction is not active."
    local int_prot = false

    if ac_disabled then
        int_risk = "PROTECTED"
        int_prot = true
        int_desc = inst_int
            and "Protected: Native anti-cheat disabled. Third-party mods (NGBTO) might still log fast timer."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif inst_int then
        int_risk = "LOW"
        int_prot = false
        int_desc = "Low Risk: Instant completion is only flagged by third-party anticheat mods (VanillaHUD+, NGBTO)."
    end

    table.insert(list, {
        name = "Instant Interaction",
        category = "Player",
        active = inst_int,
        protected = int_prot,
        risk_level = int_risk,
        description = int_desc
    })

    -- 8. God Mode
    local god_on = NiceTrainer.Settings.god_mode == true
    local god_risk = "SAFE"
    local god_desc = "Clean: God mode is not active."
    local god_prot = false

    if ac_disabled then
        god_risk = "PROTECTED"
        god_prot = true
        god_desc = god_on
            and "Protected: Native anti-cheat disabled. Host third-party inspect mods might notice damage patterns."
            or "Protected: Inactive (Armed). Protected by Disable Anti-Cheat if activated."
    elseif god_on then
        god_risk = "LOW"
        god_prot = false
        god_desc = "Low Risk: Damage immunity is not flagged by native anti-cheat, but noticeable by peers."
    end

    table.insert(list, {
        name = "God Mode",
        category = "Player",
        active = god_on,
        protected = god_prot,
        risk_level = god_risk,
        description = god_desc
    })

    return list
end

local function countRisks(features)
    local high, med, prot, safe = 0, 0, 0, 0
    for _, f in ipairs(features) do
        if f.risk_level == "HIGH" then high = high + 1
        elseif f.risk_level == "MEDIUM" then med = med + 1
        elseif f.risk_level == "PROTECTED" then prot = prot + 1
        else safe = safe + 1 end
    end
    return high, med, prot
end

-- ─── Real-Time In-Menu & In-Game Warning Banner (HUD / Menu Alert) ───────────

local _ac_ws = nil
local _ac_banner = nil
local _ac_bar = nil
local _ac_tag = nil
local _ac_sub = nil

-- In-Heist Cheater Tag HUD Alert
local _heist_ac_ws = nil
local _heist_ac_panel = nil
local _heist_ac_bar = nil
local _heist_ac_title = nil
local _heist_ac_reason = nil
local _heist_pulse_t = 0

-- Hook NetworkPeer, ConnectionNetworkHandler & HUDManager to catch if local player is flagged as a cheater
local function record_local_cheater_detected(reason, source)
    NiceTrainer._local_marked_cheater = true
    if reason then NiceTrainer._local_cheater_reason = reason end
    local reason_text = "Detection Triggered"
    if reason and managers.vote and managers.vote.kick_reason_to_string then
        local r_key = managers.vote:kick_reason_to_string(reason)
        reason_text = (r_key and managers.localization and managers.localization:text(r_key)) or tostring(reason)
    end
    NiceTrainer:Toast("🚨 WARNING: CHEATER STATUS FLAGGED! (" .. reason_text .. ")", Color(1, 0.2, 0.2))
end

NiceTrainer.OnCheaterMarked = record_local_cheater_detected

NiceTrainer.TestCheaterAlert = function()
    NiceTrainer._local_marked_cheater = true
    NiceTrainer._local_cheater_reason = "Simulated Host Flag (Self-Test)"
    NiceTrainer:Toast("🚨 Cheater Alert Simulation Triggered (6s)", Color(1, 0.25, 0.25))
    DelayedCalls:Add("NiceTrainer_ResetCheaterSim", 6, function()
        NiceTrainer._local_marked_cheater = false
        NiceTrainer._local_cheater_reason = nil
        NiceTrainer:Toast("Cheater Alert Simulation Finished", Color(0.2, 0.8, 1.0))
    end)
end

if _G.NetworkPeer and not NetworkPeer._nt_audit_cheater_hooked then
    NetworkPeer._nt_audit_cheater_hooked = true
    Hooks:PostHook(NetworkPeer, "mark_cheater", "NiceTrainer_Audit_CatchLocalCheater", function(self, reason, auto_kick)
        local session = managers.network and managers.network:session()
        local local_peer = session and session:local_peer()
        if session and (self == local_peer or (local_peer and self:id() == local_peer:id())) then
            record_local_cheater_detected(reason, "peer")
        end
    end)
end

if _G.ConnectionNetworkHandler and not ConnectionNetworkHandler._nt_audit_cheater_hooked then
    ConnectionNetworkHandler._nt_audit_cheater_hooked = true
    Hooks:PreHook(ConnectionNetworkHandler, "mark_cheater", "NiceTrainer_NetHandler_CatchHostCheater", function(self, peer_id, sender)
        local session = managers.network and managers.network:session()
        local local_peer = session and session:local_peer()
        if local_peer and (peer_id == local_peer:id()) then
            record_local_cheater_detected("Host sent mark_cheater packet", "network_handler")
        end
    end)
end

if _G.HUDManager and not HUDManager._nt_audit_cheater_hooked then
    HUDManager._nt_audit_cheater_hooked = true
    Hooks:PostHook(HUDManager, "mark_cheater", "NiceTrainer_HUD_CatchCheaterTag", function(self, peer_id)
        local session = managers.network and managers.network:session()
        local local_peer = session and session:local_peer()
        if local_peer and local_peer:id() == peer_id then
            record_local_cheater_detected(VoteManager and VoteManager.REASON and VoteManager.REASON.invalid_character or 1, "hud")
        end
    end)
    Hooks:PostHook(HUDManager, "set_teammate_cheater", "NiceTrainer_HUD_CatchTeammateCheater", function(self, i, state)
        local session = managers.network and managers.network:session()
        local local_peer = session and session:local_peer()
        if state and local_peer and (i == (HUDManager.PLAYER_PANEL or 4) or i == local_peer:id()) then
            record_local_cheater_detected(nil, "hud_teammate")
        end
    end)
end

if _G.HUDTeammate and not HUDTeammate._nt_audit_cheater_hooked then
    HUDTeammate._nt_audit_cheater_hooked = true
    Hooks:PostHook(HUDTeammate, "set_cheater", "NiceTrainer_HUDTeammate_CatchCheater", function(self, state)
        if state and self._main_player then
            record_local_cheater_detected(nil, "hud_teammate_main")
        end
    end)
end

local function is_local_player_cheater()
    if NiceTrainer._local_marked_cheater and NiceTrainer._local_cheater_reason == "Simulated Host Flag (Self-Test)" then
        return true, NiceTrainer._local_cheater_reason
    end
    if NiceTrainer.Settings.disable_anti_cheat ~= false then
        return false, nil
    end
    local session = managers.network and managers.network:session()
    local local_peer = session and session:local_peer()
    if local_peer then
        if (local_peer.is_cheater and local_peer:is_cheater()) or local_peer._cheater then
            return true, NiceTrainer._local_cheater_reason or "Session cheater flag active"
        end
    end
    if NiceTrainer._local_marked_cheater then
        return true, NiceTrainer._local_cheater_reason or "Flagged by anti-cheat check"
    end
    return false, nil
end

NiceTrainer.IsLocalPlayerCheater = is_local_player_cheater

local function cleanup_heist_ac_gui()
    if _heist_ac_ws and alive(_heist_ac_ws) then
        managers.gui_data:destroy_workspace(_heist_ac_ws)
    end
    _heist_ac_ws = nil
    _heist_ac_panel = nil
    _heist_ac_bar = nil
    _heist_ac_title = nil
    _heist_ac_reason = nil
end

local function get_or_create_heist_ac_workspace()
    if not _heist_ac_ws or not alive(_heist_ac_ws) or not _heist_ac_panel then
        cleanup_heist_ac_gui()
        if not managers.gui_data then return nil end

        local ok, ws = pcall(function() return managers.gui_data:create_saferect_workspace() end)
        if ok and ws and alive(ws) then
            _heist_ac_ws = ws
            local root = _heist_ac_ws:panel()
            local bw, bh = 480, 52
            local bx = (root:w() - bw) / 2
            local by = 35

            _heist_ac_panel = root:panel({
                name = "nt_heist_cheater_alert",
                x = bx,
                y = by,
                w = bw,
                h = bh,
                layer = 3000,
                visible = false
            })

            _heist_ac_panel:rect({ color = Color(0.12, 0.02, 0.02), alpha = 0.95, layer = 0 })
            _heist_ac_bar = _heist_ac_panel:rect({ color = Color(1, 0.15, 0.15), w = 6, layer = 1 })
            _heist_ac_panel:rect({ color = Color(1, 0.2, 0.2), alpha = 0.6, h = 1, layer = 1 })
            _heist_ac_panel:rect({ color = Color(1, 0.2, 0.2), alpha = 0.6, y = bh - 1, h = 1, layer = 1 })
            _heist_ac_panel:rect({ color = Color(1, 0.2, 0.2), alpha = 0.6, x = bw - 1, w = 1, layer = 1 })

            _heist_ac_title = _heist_ac_panel:text({
                text = "🚨 WARNING: YOU ARE MARKED AS A CHEATER!",
                font = "fonts/font_medium_shadow_mf",
                font_size = 16,
                color = Color(1, 0.25, 0.25),
                x = 16,
                y = 5,
                layer = 2
            })

            _heist_ac_reason = _heist_ac_panel:text({
                text = "Host or other peers see a red [CHEATER] tag above your head.",
                font = "fonts/font_medium_shadow_mf",
                font_size = 13,
                color = Color(0.95, 0.95, 0.95),
                x = 16,
                y = 26,
                layer = 2
            })
        end
    end

    return _heist_ac_panel
end

local function get_or_create_ac_workspace()
    if _ac_ws and not alive(_ac_ws) then
        _ac_ws = nil
        _ac_banner = nil
        _ac_bar = nil
        _ac_tag = nil
        _ac_sub = nil
    end

    if not _ac_ws and managers.gui_data then
        local ok, ws = pcall(function() return managers.gui_data:create_saferect_workspace() end)
        if ok and ws and alive(ws) then
            _ac_ws = ws
            local root = _ac_ws:panel()
            local bw, bh = 540, 34
            local bx = (root:w() - bw) / 2
            local by = 10

            _ac_banner = root:panel({
                name = "nt_ac_warning_banner",
                x = bx,
                y = by,
                w = bw,
                h = bh,
                layer = 1200,
                visible = false
            })

            _ac_banner:rect({ color = Color.black, alpha = 0.85, layer = 0 })
            _ac_bar = _ac_banner:rect({ color = Color(1, 0.25, 0.25), w = 4, layer = 1 })
            _ac_banner:rect({ color = Color.white, alpha = 0.08, h = 1, layer = 1 })
            _ac_banner:rect({ color = Color.white, alpha = 0.08, y = bh - 1, h = 1, layer = 1 })
            _ac_banner:rect({ color = Color.white, alpha = 0.08, x = bw - 1, w = 1, layer = 1 })

            _ac_tag = _ac_banner:text({
                text = "[ ⚠ ANTI-CHEAT WARNING ]",
                font = "fonts/font_medium_shadow_mf",
                font_size = 14,
                color = Color(1, 0.3, 0.3),
                x = 12,
                y = 2,
                layer = 2
            })

            _ac_sub = _ac_banner:text({
                text = "Audit warning",
                font = "fonts/font_medium_shadow_mf",
                font_size = 12,
                color = Color(0.85, 0.85, 0.85),
                x = 12,
                y = 17,
                layer = 2
            })
        end
    end

    return _ac_banner
end

local function updateAntiCheatWarningBanner()
    local banner = get_or_create_ac_workspace()
    if not banner or not alive(banner) then return end

    -- Show only in Menu / Crime.net, never during a heist
    if NiceTrainer:IsInHeist() or not NiceTrainer:IsInMenu() then
        banner:set_visible(false)
        return
    end

    if NiceTrainer.Settings.anti_cheat_checker_alert == false then
        banner:set_visible(false)
        return
    end

    local features = getDetectableFeatures()
    local high_count, med_count, _ = countRisks(features)

    if high_count > 0 then
        if alive(_ac_bar) then _ac_bar:set_color(Color(1, 0.25, 0.25)) end
        if alive(_ac_tag) then
            _ac_tag:set_color(Color(1, 0.3, 0.3))
            _ac_tag:set_text("[ ⚠ ANTI-CHEAT WARNING - DETECTABLE CHEATS ACTIVE ]")
        end
        if alive(_ac_sub) then
            _ac_sub:set_text(string.format("%d cheat(s) at HIGH risk without protection! Check Account > Security Audit.", high_count))
        end
        banner:set_visible(true)
    elseif med_count > 0 then
        if alive(_ac_bar) then _ac_bar:set_color(Color(1, 0.65, 0.15)) end
        if alive(_ac_tag) then
            _ac_tag:set_color(Color(1, 0.75, 0.2))
            _ac_tag:set_text("[ ⚠ ANTI-CHEAT NOTICE - PUBLIC LOBBY RISK ]")
        end
        if alive(_ac_sub) then
            _ac_sub:set_text(string.format("%d feature(s) detectable by remote hosts. Enable Outfit Spoof in DLC Unlocker.", med_count))
        end
        banner:set_visible(true)
    else
        banner:set_visible(false)
    end
end

NiceTrainer.UpdateAntiCheatWarning = updateAntiCheatWarningBanner

-- Real-time ticker in Menu ONLY
local _last_menu_ticker = 0
Hooks:Add("MenuUpdate", "NiceTrainer_AntiCheatWarning_MenuUpdate", function(t, dt)
    if not _last_menu_ticker or (t - _last_menu_ticker > 0.5) then
        _last_menu_ticker = t
        updateAntiCheatWarningBanner()
    end
end)

-- Real-time In-Heist Cheater Tag Monitor
Hooks:Add("GameSetupUpdate", "NiceTrainer_AntiCheatWarning_GameUpdate", function(t, dt)
    if _ac_banner and alive(_ac_banner) and _ac_banner:visible() then
        _ac_banner:set_visible(false)
    end

    if NiceTrainer:IsInHeist() and NiceTrainer.Settings.anticheat_heist_hud_indicator ~= false then
        local is_cheater, reason = is_local_player_cheater()
        local features = getDetectableFeatures()
        local high_count, _, _ = countRisks(features)

        local heist_panel = get_or_create_heist_ac_workspace()
        if heist_panel and alive(heist_panel) then
            if is_cheater then
                _heist_pulse_t = (_heist_pulse_t or 0) + (dt or 0.033) * 4
                local pulse_alpha = 0.75 + 0.25 * math.sin(_heist_pulse_t)
                heist_panel:set_alpha(pulse_alpha)

                if alive(_heist_ac_bar) then _heist_ac_bar:set_color(Color(1, 0.15, 0.15)) end
                if alive(_heist_ac_title) then
                    _heist_ac_title:set_color(Color(1, 0.25, 0.25))
                    _heist_ac_title:set_text("🚨 WARNING: YOU ARE MARKED AS A CHEATER!")
                end

                local reason_str = "Host or other peers see a red [CHEATER] tag on you."
                if reason and managers.vote and managers.vote.kick_reason_to_string then
                    local r_key = managers.vote:kick_reason_to_string(reason)
                    local txt = r_key and managers.localization and managers.localization:text(r_key)
                    if txt then
                        reason_str = "Flagged Reason: " .. txt
                    end
                elseif type(reason) == "string" and reason:len() > 0 then
                    reason_str = reason
                end

                if alive(_heist_ac_reason) then
                    _heist_ac_reason:set_text(reason_str)
                end

                heist_panel:set_visible(true)
            elseif high_count > 0 and NiceTrainer.Settings.anti_cheat_checker_alert ~= false then
                _heist_pulse_t = (_heist_pulse_t or 0) + (dt or 0.033) * 3
                local pulse_alpha = 0.7 + 0.3 * math.sin(_heist_pulse_t)
                heist_panel:set_alpha(pulse_alpha)

                if alive(_heist_ac_bar) then _heist_ac_bar:set_color(Color(1, 0.65, 0.15)) end
                if alive(_heist_ac_title) then
                    _heist_ac_title:set_color(Color(1, 0.75, 0.2))
                    _heist_ac_title:set_text("⚠ ANTI-CHEAT WARNING: RISKY CHEATS ACTIVE")
                end
                if alive(_heist_ac_reason) then
                    _heist_ac_reason:set_text(string.format("%d cheat(s) active without protection! Check Account > Security Audit.", high_count))
                end

                heist_panel:set_visible(true)
            else
                heist_panel:set_visible(false)
            end
        end
    else
        if _heist_ac_panel and alive(_heist_ac_panel) and _heist_ac_panel:visible() then
            _heist_ac_panel:set_visible(false)
        end
    end
end)

-- ─── Anti-Cheat Security Audit Modal ──────────────────────────────────────────

local AC_MODAL_W = 600
local AC_MODAL_H = 540

local function ShowAntiCheatCheckerModal()
    local features = getDetectableFeatures()
    local high_count, med_count, prot_count = countRisks(features)
    local total_risks = high_count + med_count

    NiceTrainer:ShowCustomModal("Anti-Cheat Security Status", AC_MODAL_W, AC_MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        -- Security Status Card
        local banner_h = 62
        local banner = m:panel({ x = 16, y = 56, w = AC_MODAL_W - 32, h = banner_h, layer = 2 })

        local is_flagged_cheater, cheater_flag_reason = is_local_player_cheater()

        local is_safe = (total_risks == 0) and not is_flagged_cheater
        local banner_color = is_flagged_cheater and Color(1, 0.1, 0.1) or (is_safe and Color(0.15, 0.6, 0.25) or (high_count > 0 and Color(0.8, 0.2, 0.2) or Color(0.85, 0.55, 0.1)))
        banner:rect({ color = banner_color, alpha = 0.15, layer = 0 })
        banner:rect({ color = banner_color, alpha = 0.8, w = 2, layer = 1 })
        banner:rect({ color = banner_color, alpha = 0.8, x = banner:w() - 2, w = 2, layer = 1 })
        banner:rect({ color = banner_color, alpha = 0.8, h = 2, layer = 1 })
        banner:rect({ color = banner_color, alpha = 0.8, y = banner_h - 2, h = 2, layer = 1 })

        local title_str = is_flagged_cheater and "[🚨] YOU ARE FLAGGED AS CHEATER IN THIS SESSION!" or (is_safe and "[√] ALL CHEATS SECURE / PROTECTED" or (high_count > 0 and string.format("[!] DETECTABLE CHEATS ACTIVE (%d HIGH RISK)", high_count) or string.format("[!] MEDIUM RISK NOTICE (%d AT RISK)", med_count)))
        banner:text({
            text = title_str, font = "fonts/font_large_mf", font_size = 18,
            color = is_flagged_cheater and Color(1, 0.2, 0.2) or (is_safe and Color(0.3, 1, 0.4) or (high_count > 0 and Color(1, 0.35, 0.35) or Color(1, 0.75, 0.2))),
            x = 14, y = 8, layer = 2
        })

        local subtitle_str = is_flagged_cheater
            and "Host or peers have marked you with the red [CHEATER] tag."
            or (is_safe
                and "No unprotected detectable features active. You are safe from anti-cheat tags."
                or (high_count > 0 and string.format("%d High Risk, %d Medium Risk. Enable protections below.", high_count, med_count) or "Protected locally by Disable Anti-Cheat. Enable Outfit Spoof for public lobbies."))
        banner:text({
            text = subtitle_str, font = "fonts/font_medium_shadow_mf", font_size = 13,
            color = Color(0.8, 0.8, 0.8), x = 14, y = 34, layer = 2
        })

        -- Quick Fix Action Buttons in Banner
        local btn_offset_x = banner:w() - 10
        if NiceTrainer.Settings.dlc_unlocker and not NiceTrainer.Settings.spoof_equipment then
            local fix_w = 140
            btn_offset_x = btn_offset_x - fix_w
            local fix_btn = banner:panel({ x = btn_offset_x, y = 14, w = fix_w, h = 34, layer = 3 })
            local fix_bg = fix_btn:rect({ color = Color(0.2, 0.8, 0.4), alpha = 0.3, layer = 0 })
            fix_btn:rect({ color = Color(0.2, 0.8, 0.4), w = 1, layer = 1 })
            fix_btn:rect({ color = Color(0.2, 0.8, 0.4), x = fix_w - 1, w = 1, layer = 1 })
            fix_btn:rect({ color = Color(0.2, 0.8, 0.4), h = 1, layer = 1 })
            fix_btn:rect({ color = Color(0.2, 0.8, 0.4), y = 33, h = 1, layer = 1 })
            fix_btn:text({ text = "Enable Outfit Spoof", font = "fonts/font_medium_shadow_mf", font_size = 14, align = "center", vertical = "center", color = Color.white, layer = 2 })

            table.insert(top_modal.elements, {
                panel = fix_btn,
                inside = function(self, mx, my) return fix_btn:inside(mx, my) end,
                on_hover = function(self, hovered) fix_bg:set_alpha(hovered and 0.6 or 0.3) end,
                on_click = function(self)
                    NiceTrainer.Settings.spoof_equipment = true
                    NiceTrainer:Save()
                    NiceTrainer:CloseModal()
                    NiceTrainer:Toast("Outfit Spoof Enabled! All DLCs now protected.")
                    updateAntiCheatWarningBanner()
                    ShowAntiCheatCheckerModal()
                end
            })
            btn_offset_x = btn_offset_x - 10
        end

        if NiceTrainer.Settings.disable_anti_cheat == false then
            local ac_fix_w = 150
            btn_offset_x = btn_offset_x - ac_fix_w
            local ac_btn = banner:panel({ x = btn_offset_x, y = 14, w = ac_fix_w, h = 34, layer = 3 })
            local ac_bg = ac_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.3, layer = 0 })
            ac_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
            ac_btn:rect({ color = Color(0.2, 0.6, 1.0), x = ac_fix_w - 1, w = 1, layer = 1 })
            ac_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
            ac_btn:rect({ color = Color(0.2, 0.6, 1.0), y = 33, h = 1, layer = 1 })
            ac_btn:text({ text = "Disable Anti-Cheat", font = "fonts/font_medium_shadow_mf", font_size = 14, align = "center", vertical = "center", color = Color.white, layer = 2 })

            table.insert(top_modal.elements, {
                panel = ac_btn,
                inside = function(self, mx, my) return ac_btn:inside(mx, my) end,
                on_hover = function(self, hovered) ac_bg:set_alpha(hovered and 0.6 or 0.3) end,
                on_click = function(self)
                    NiceTrainer:SetToggleState("disable_anti_cheat", true)
                    NiceTrainer:CloseModal()
                    NiceTrainer:Toast("Disable Anti-Cheat Enabled! Protections active.")
                    updateAntiCheatWarningBanner()
                    ShowAntiCheatCheckerModal()
                end
            })
        end

        local sep_y = 126
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 16, y = sep_y, w = AC_MODAL_W - 32, h = 1, layer = 2 })

        -- Scrollable feature list
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = AC_MODAL_W, h = AC_MODAL_H - scroll_top - 8, layer = 2 })

        local ITEM_H = 50
        local canvas_h = 8 + (#features * (ITEM_H + 6))
        local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = AC_MODAL_W, h = math.max(canvas_h, ITEM_H), layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local ROW_W = AC_MODAL_W - 16
        local y = 8

        for _, item in ipairs(features) do
            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = ITEM_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            -- Status indicator bar on left
            local bar_color = Color(0.4, 0.4, 0.4)
            if item.risk_level == "HIGH" then bar_color = Color(1, 0.25, 0.25)
            elseif item.risk_level == "MEDIUM" then bar_color = Color(1, 0.65, 0.2)
            elseif item.risk_level == "PROTECTED" then bar_color = Color(0.2, 0.8, 1.0)
            elseif item.risk_level == "SAFE" then bar_color = Color(0.25, 0.75, 0.35)
            elseif item.risk_level == "LOW" then bar_color = Color(0.5, 0.75, 0.5) end

            row:rect({ color = bar_color, w = 4, layer = 1 })

            -- Title & Category
            row:text({
                text = item.name, font = "fonts/font_medium_shadow_mf", font_size = 17,
                color = Color.white, x = 14, y = 6, layer = 1
            })
            row:text({
                text = "[" .. item.category .. "]", font = "fonts/font_medium_shadow_mf", font_size = 13,
                color = Color(0.2, 0.7, 1.0), x = 14 + (item.name:len() * 9) + 12, y = 8, layer = 1
            })

            -- Description
            row:text({
                text = item.description, font = "fonts/font_medium_shadow_mf", font_size = 13,
                color = Color(0.65, 0.65, 0.65), x = 14, y = 28, layer = 1
            })

            -- Badge on right
            local badge_w = 110
            row:rect({ color = bar_color, alpha = 0.2, x = ROW_W - badge_w - 12, y = 10, w = badge_w, h = 28, layer = 1 })
            row:rect({ color = bar_color, alpha = 0.7, x = ROW_W - badge_w - 12, y = 10, w = badge_w, h = 1, layer = 2 })
            row:rect({ color = bar_color, alpha = 0.7, x = ROW_W - badge_w - 12, y = 37, w = badge_w, h = 1, layer = 2 })

            local badge_label = "CLEAN / OFF"
            if item.risk_level == "HIGH" then badge_label = "HIGH RISK"
            elseif item.risk_level == "MEDIUM" then badge_label = "MEDIUM RISK"
            elseif item.risk_level == "PROTECTED" then badge_label = "PROTECTED"
            elseif item.risk_level == "LOW" then badge_label = "LOW RISK" end

            row:text({
                text = badge_label, font = "fonts/font_medium_shadow_mf", font_size = 14,
                color = bar_color, align = "center", vertical = "center",
                x = ROW_W - badge_w - 12, y = 10, w = badge_w, h = 28, layer = 2
            })

            table.insert(top_modal.elements, {
                panel = row,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and row:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    row_bg:set_alpha(hovered and 0.1 or 0.04)
                end,
                on_click = function(self) end
            })

            y = y + ITEM_H + 6
        end
    end)
end

-- Register Anti-Cheat Security Audit Button
NiceTrainer:RegisterAction("Account", {
    type     = "button",
    category = "Identity & Anti-Cheat",
    no_bind  = true,
    badge    = "client",
    id       = "anti_cheat_checker",
    text     = "Anti-Cheat Security Audit",
    tooltip  = "Audits all active features for anti-cheat detection risk and checks live session cheater flags.",
    callback = ShowAntiCheatCheckerModal
})

-- Register Test Cheater Alert Simulation Button
NiceTrainer:RegisterAction("Account", {
    type     = "button",
    category = "Identity & Anti-Cheat",
    no_bind  = true,
    badge    = "safe",
    id       = "test_cheater_alert",
    text     = "Test Cheater Alert (HUD)",
    tooltip  = "Simulates a Cheater Tag alert on your HUD for 6 seconds to verify screen positioning and visibility.",
    callback = function()
        NiceTrainer.TestCheaterAlert()
    end
})

-- Register Menu Warning Toggle
NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Identity & Anti-Cheat",
    no_bind  = true,
    badge    = "safe",
    id       = "anti_cheat_checker_alert",
    text     = "Menu Anti-Cheat Warning",
    tooltip  = "Displays an on-screen warning banner in menus (Crime.net/Lobby) if any detectable cheats are active without protection.",
    default  = true,
    callback = function(state)
        NiceTrainer.Settings.anti_cheat_checker_alert = state
        NiceTrainer:Save()
        updateAntiCheatWarningBanner()
    end
})

-- Register In-Heist Cheater Tag Indicator Toggle
NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Identity & Anti-Cheat",
    no_bind  = true,
    badge    = "safe",
    id       = "anticheat_heist_hud_indicator",
    text     = "In-Heist Cheater HUD Alert",
    tooltip  = "Displays a live pulsing red alert on your HUD during a heist if the host or game marks you as a CHEATER.",
    default  = true,
    callback = function(state)
        NiceTrainer.Settings.anticheat_heist_hud_indicator = state
        NiceTrainer:Save()
    end
})

-- Heist Load Hook: reset local cheater status on new lobby/heist load
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Account_Audit_OnLoad", function()
    NiceTrainer._local_marked_cheater = false
    NiceTrainer._local_cheater_reason = nil
    if _ac_banner and alive(_ac_banner) then
        _ac_banner:set_visible(false)
    end
    cleanup_heist_ac_gui()
end)

