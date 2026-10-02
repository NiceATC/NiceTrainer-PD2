-- ECM Timer & Cheats integration for NiceTrainer (Stealth Tab)

local function parse_hex_color(hex_val, default_color)
    if type(hex_val) == "userdata" then return hex_val end
    if type(hex_val) == "string" then
        local hex = string.gsub(hex_val, "^#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)
            if r and g and b then
                return Color(r / 255, g / 255, b / 255)
            end
        end
    end
    return default_color or Color.white
end

if not _G.ECM_Timer_v2 then
    _G.ECM_Timer_v2 = {
        _data = {
            infoboxes = true,
            hide_hudbox = false,
            animate_low = true,
            pager_jam = true,
            pocket_ecm = true,
            chat_ecm = false,
            low_time = 5,
            ECMText = { r = 255, g = 255, b = 255 },
            ecm_low = { r = 255, g = 102, b = 102 },
            ecm_mid = { r = 255, g = 204, b = 102 },
            ECMIcon = { r = 255, g = 255, b = 255 },
            ecm_color = { r = 9, g = 177, b = 219 }
        }
    }
    
    function ECM_Timer_v2:GetOption(id)
        if NiceTrainer and NiceTrainer.Settings then
            if id == "infoboxes" and NiceTrainer.Settings.ecm_timer_enabled ~= nil then
                return NiceTrainer.Settings.ecm_timer_enabled
            elseif id == "hide_hudbox" and NiceTrainer.Settings.ecm_timer_hide_hudbox ~= nil then
                return NiceTrainer.Settings.ecm_timer_hide_hudbox
            elseif id == "animate_low" and NiceTrainer.Settings.ecm_timer_animate_low ~= nil then
                return NiceTrainer.Settings.ecm_timer_animate_low
            elseif id == "pager_jam" and NiceTrainer.Settings.ecm_timer_pager_jam ~= nil then
                return NiceTrainer.Settings.ecm_timer_pager_jam
            elseif id == "pocket_ecm" and NiceTrainer.Settings.ecm_timer_pocket_ecm ~= nil then
                return NiceTrainer.Settings.ecm_timer_pocket_ecm
            elseif id == "chat_ecm" and NiceTrainer.Settings.ecm_timer_chat_mode ~= nil then
                return NiceTrainer.Settings.ecm_timer_chat_mode > 1
            elseif id == "low_time" and NiceTrainer.Settings.ecm_timer_low_time ~= nil then
                return tonumber(NiceTrainer.Settings.ecm_timer_low_time) or 5
            end
        end
        return self._data[id]
    end

    function ECM_Timer_v2:GetColor(id)
        if NiceTrainer and NiceTrainer.Settings then
            local hex_map = {
                ECMText = "ecm_timer_color_text",
                ecm_low = "ecm_timer_color_low",
                ecm_mid = "ecm_timer_color_mid",
                ECMIcon = "ecm_timer_color_icon",
                ecm_color = "ecm_timer_color_chat"
            }
            local default_fallback = {
                ECMText = Color.white,
                ecm_low = Color(1, 0.4, 0.4),
                ecm_mid = Color(1, 0.8, 0.4),
                ECMIcon = Color.white,
                ecm_color = Color(0.04, 0.7, 0.86)
            }
            local setting_key = hex_map[id]
            if setting_key and NiceTrainer.Settings[setting_key] then
                return parse_hex_color(NiceTrainer.Settings[setting_key], default_fallback[id])
            end
        end
        local color = self._data[id]
        if color and color.r and color.b and color.g then
            return Color(255, color.r, color.g, color.b) / 255
        end
        return Color.white
    end
end

-- Helper: Send Chat Alert (Private or Public)
local function send_ecm_chat_alert(sec)
    local mode = NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.ecm_timer_chat_mode or 2
    if mode == 1 then return end -- Disabled

    local msg = string.format("[ECM] %ds...", sec)

    if mode == 2 then
        -- Private Chat (Only visible to local player)
        if managers.chat then
            local col = ECM_Timer_v2:GetColor("ecm_color")
            managers.chat:_receive_message(1, "ECM Timer", msg, col)
        end
    elseif mode == 3 then
        -- Public / Team Chat (Visible to all heisters)
        if managers.chat then
            if managers.network and managers.network:session() then
                local sender = managers.network.account and managers.network.account:username() or "Local"
                managers.chat:send_message(1, sender, msg)
            else
                local col = ECM_Timer_v2:GetColor("ecm_color")
                managers.chat:_receive_message(1, "ECM Timer", msg, col)
            end
        end
    end
end

-- HUDECMCounter Class (Adapted 1:1 from LazyOzzy / fragECM)
if not _G.HUDECMCounter then
    _G.HUDECMCounter = class()

    function HUDECMCounter:init(hud)
        self._end_time = 0
        self._last_chat_sec = nil
        self._hud_panel = hud and hud.panel
        if not self._hud_panel then return end

        if self._hud_panel:child("ecm_counter_panel") then
            self._hud_panel:remove(self._hud_panel:child("ecm_counter_panel"))
        end

        self._panel = self._hud_panel:panel({
            name = "ecm_counter_panel",
            visible = false,
            w = 200,
            h = 200,
            x = self._hud_panel:w() - 200,
            y = 50,
            layer = 10
        })

        -- ECM Overdrive icon (guis/textures/pd2/skilltree/icons_atlas)
        local ecm_icon = self._panel:bitmap({
            name = "ecm_icon",
            texture = "guis/textures/pd2/skilltree/icons_atlas",
            texture_rect = { 6 * 64, 3 * 64, 64, 64 },
            valign = "center",
            align = "center",
            layer = 2,
            h = 38,
            w = 38,
            color = Color.white
        })
        self._icon = ecm_icon
        ecm_icon:set_right(self._panel:w() + 5)

        local box = HUDBGBox_create(self._panel, { w = 38, h = 38 }, {})
        box:set_right(ecm_icon:left() - 5)
        box:set_center_y(ecm_icon:h() / 2)
        self._box = box

        self._text = box:text({
            name = "text",
            text = "0",
            valign = "center",
            align = "center",
            vertical = "center",
            w = box:w(),
            h = box:h(),
            layer = 2,
            color = Color.white,
            font = tweak_data.hud_corner.assault_font or "fonts/font_medium_shadow_mf",
            font_size = tweak_data.hud_corner.numhostages_size and (tweak_data.hud_corner.numhostages_size * 0.9) or 20
        })

        self:update_hudbox_visibility()
    end

    function HUDECMCounter:set_end_time(new_end_time)
        if new_end_time > self._end_time then
            self._end_time = new_end_time
            self._last_chat_sec = nil
        end
    end

    function HUDECMCounter:update_position()
        if not alive(self._panel) or not self._hud_panel then return end
        
        local custom_pos = NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.ecm_timer_custom_pos
        if custom_pos then
            local x = tonumber(NiceTrainer.Settings.ecm_timer_pos_x) or (self._hud_panel:w() - 200)
            local y = tonumber(NiceTrainer.Settings.ecm_timer_pos_y) or 50
            self._panel:set_x(x)
            self._panel:set_y(y)
        else
            local hostages_panel = self._hud_panel:child("hostages_panel")
            if hostages_panel and alive(hostages_panel) then
                self._panel:set_top(hostages_panel:bottom() + 5)
                self._panel:set_right(hostages_panel:right())
            else
                self._panel:set_top(65)
                self._panel:set_right(self._hud_panel:w() - 10)
            end
        end
    end

    function HUDECMCounter:update_hudbox_visibility()
        if not alive(self._box) then return end
        local hide = ECM_Timer_v2:GetOption("hide_hudbox")
        for _, child in ipairs({"bg", "left_top", "left_bottom", "right_top", "right_bottom"}) do
            local c = self._box:child(child)
            if c then
                if hide then c:hide() else c:show() end
            end
        end
    end

    function HUDECMCounter:update()
        if not alive(self._panel) or not alive(self._text) then return end

        local current_time = TimerManager:game():time()
        local t = self._end_time - current_time
        local is_stealth = managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode()
        local is_enabled = ECM_Timer_v2:GetOption("infoboxes") ~= false

        if t > 0 and (is_stealth or NiceTrainer.Settings.ecm_show_in_loud) and is_enabled then
            if not self._panel:visible() then
                self._panel:set_visible(true)
            end

            self._text:set_text(string.format(t < 10 and "%.1f" or "%.0f", t))

            -- Chat alert countdown tick every second (5.. 4.. 3.. 2.. 1..)
            local low_threshold = ECM_Timer_v2:GetOption("low_time") or 5
            local sec = math.floor(t + 0.1)
            if sec <= low_threshold and sec >= 1 and sec ~= self._last_chat_sec then
                self._last_chat_sec = sec
                send_ecm_chat_alert(sec)
            end

            -- Update Icon Color
            if alive(self._icon) then
                self._icon:set_color(ECM_Timer_v2:GetColor("ECMIcon"))
            end

            -- Colors & Pulse Animation
            if t < 3 then
                self._text:set_color(ECM_Timer_v2:GetColor("ecm_low"))
                if ECM_Timer_v2:GetOption("animate_low") then
                    local pulse = 1 - math.sin(t * 700)
                    local base_size = (tweak_data.hud_corner.numhostages_size or 22) * 0.9
                    self._text:set_font_size(math.lerp(base_size, base_size * 1.15, pulse))
                end
            elseif t < 10 then
                self._text:set_color(ECM_Timer_v2:GetColor("ecm_mid"))
                self._text:set_font_size((tweak_data.hud_corner.numhostages_size or 22) * 0.9)
            else
                self._text:set_color(ECM_Timer_v2:GetColor("ECMText"))
                self._text:set_font_size((tweak_data.hud_corner.numhostages_size or 22) * 0.9)
            end
        else
            if self._panel:visible() then
                self._panel:set_visible(false)
            end
            self._last_chat_sec = nil
        end

        self:update_position()
    end
end

_G.EcmTimer = _G.HUDECMCounter

-- HUD Hooks
if _G.HUDManager and not NiceTrainer._ecm_timer_hud_hooked then
    NiceTrainer._ecm_timer_hud_hooked = true
    Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "NiceTrainer_ECM_SetupPlayerInfoHud", function(self)
        self._hud_ecm_counter = HUDECMCounter:new(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
    end)
    Hooks:PostHook(HUDManager, "update", "NiceTrainer_ECM_HUDUpdate", function(self)
        if self._hud_ecm_counter then
            self._hud_ecm_counter:update()
        end
    end)
end

-- ECM Jammer Base Hooks (Host & Client Setup + Cheats)
if _G.ECMJammerBase and not NiceTrainer._ecm_jammer_hooked then
    NiceTrainer._ecm_jammer_hooked = true

    local function apply_ecm_cheats(self)
        if NiceTrainer.Settings.ecm_infinite_battery then
            self._max_battery_life = 999999
            self._battery_life = 999999
        elseif NiceTrainer.Settings.ecm_duration_slider and NiceTrainer.Settings.ecm_duration_slider > 0 then
            local dur = tonumber(NiceTrainer.Settings.ecm_duration_slider) or 30
            self._max_battery_life = dur
            self._battery_life = dur
        end

        if NiceTrainer.Settings.ecm_all_upgrades then
            self._battery_life_upgrade_lvl = 3
        end
    end

    local function on_ecm_activated(self)
        apply_ecm_cheats(self)

        if ECM_Timer_v2:GetOption("infoboxes") then
            local battery_life = self:battery_life() or 0
            if battery_life <= 0 then return end

            local jam_pagers = false
            if NiceTrainer.Settings.ecm_all_upgrades or self._ets_local_peer or (self._owner_id and managers.network and managers.network:session() and self._owner_id == managers.network:session():local_peer():id()) then
                jam_pagers = true
            elseif self._ets_peer_id and self._ets_peer_id ~= 0 and managers.network and managers.network:session() then
                local peer = managers.network:session():peer(self._ets_peer_id)
                if peer and peer._unit and peer._unit:base() and peer._unit:base().upgrade_value then
                    jam_pagers = peer._unit:base():upgrade_value("ecm_jammer", "affects_pagers")
                end
            end

            if jam_pagers or not ECM_Timer_v2:GetOption("pager_jam") then
                local dur = NiceTrainer.Settings.ecm_infinite_battery and 999999 or (NiceTrainer.Settings.ecm_duration_slider or battery_life)
                local end_time = TimerManager:game():time() + dur
                if managers.hud and managers.hud._hud_ecm_counter then
                    managers.hud._hud_ecm_counter:set_end_time(end_time)
                end
            end
        end
    end

    Hooks:PreHook(ECMJammerBase, "update", "NiceTrainer_ECM_Cheats_Update", function(self, unit, t, dt)
        if NiceTrainer.Settings.ecm_infinite_battery then
            self._battery_life = 999999
        end
    end)

    Hooks:PostHook(ECMJammerBase, "setup", "NiceTrainer_ECM_HostSetup", function(self, ...)
        on_ecm_activated(self)
    end)

    Hooks:PostHook(ECMJammerBase, "sync_setup", "NiceTrainer_ECM_ClientSyncSetup", function(self, upgrade_lvl, peer_id, ...)
        self._ets_peer_id = peer_id or 0
        local session = managers.network and managers.network:session()
        self._ets_local_peer = session and session:local_peer() and (peer_id == session:local_peer():id()) or false
        on_ecm_activated(self)
    end)

    Hooks:PostHook(ECMJammerBase, "set_active", "NiceTrainer_ECM_SetActive", function(self, active, ...)
        if active then
            on_ecm_activated(self)
        end
    end)

    -- 100% Feedback Stun & Radius Hack
    local orig_chk_feedback_chance = ECMJammerBase.chk_feedback_chance
    ECMJammerBase.chk_feedback_chance = function(self, ...)
        if NiceTrainer.Settings.ecm_feedback_100 then
            return true
        end
        return orig_chk_feedback_chance(self, ...)
    end
end

-- PlayerManager & Inventory Cheats (Infinite ECM Count, Pocket ECM Duration & Instant Cooldown)
if _G.PlayerManager and not NiceTrainer._ecm_player_cheats_hooked then
    NiceTrainer._ecm_player_cheats_hooked = true

    -- Infinite ECM Deployable count
    local orig_use_deployable = PlayerManager.use_deployable
    PlayerManager.use_deployable = function(self, ...)
        if NiceTrainer.Settings.ecm_infinite_amount then
            local equip = self:selected_equipment()
            if equip and equip.equipment == "ecm_jammer" then
                equip.amount = math.max(equip.amount or 1, 2)
                if managers.hud then
                    managers.hud:set_deployable_equipment_amount(1, { icon = "equipment_ecm_jammer", amount = equip.amount })
                end
            end
        end
        return orig_use_deployable(self, ...)
    end

    -- Force Pager Jamming and Security Door bypass upgrades
    local orig_has_cat_upgrade = PlayerManager.has_category_upgrade
    PlayerManager.has_category_upgrade = function(self, category, upgrade, ...)
        if NiceTrainer.Settings.ecm_all_upgrades and category == "ecm_jammer" then
            if upgrade == "affects_pagers" or upgrade == "can_open_sec_doors" or upgrade == "feedback_duration_boost" then
                return true
            end
        end
        return orig_has_cat_upgrade(self, category, upgrade, ...)
    end

    -- Pocket ECM Instant Cooldown
    Hooks:PostHook(PlayerManager, "_attempt_pocket_ecm_jammer", "NiceTrainer_ECM_PocketInstantCooldown", function(self)
        if NiceTrainer.Settings.ecm_instant_pocket_cooldown or NiceTrainer.Settings.ecm_infinite_battery then
            self._pocket_ecm_jammer_cooldown_t = 0
        end
    end)
end

-- Pocket ECM Jammer Effect Hook
if _G.PlayerInventory and not NiceTrainer._ecm_pocket_hooked then
    NiceTrainer._ecm_pocket_hooked = true
    Hooks:PostHook(PlayerInventory, "_start_jammer_effect", "NiceTrainer_ECM_PocketJammerEffect", function(self, end_time, ...)
        if ECM_Timer_v2:GetOption("infoboxes") and ECM_Timer_v2:GetOption("pocket_ecm") then
            local base_dur = self.get_jammer_time and self:get_jammer_time() or 6
            if NiceTrainer.Settings.ecm_infinite_battery then
                base_dur = 999999
            elseif NiceTrainer.Settings.ecm_duration_slider and NiceTrainer.Settings.ecm_duration_slider > 0 then
                base_dur = tonumber(NiceTrainer.Settings.ecm_duration_slider) or base_dur
            end
            local ecm_end_time = TimerManager:game():time() + base_dur
            if managers.hud and managers.hud._hud_ecm_counter then
                managers.hud._hud_ecm_counter:set_end_time(ecm_end_time)
            end
        end
    end)
end

-- Function: Spawn Active ECM at Player's position
local function spawn_active_ecm()
    if not managers.player then return end
    local player = managers.player:local_player()
    if not alive(player) then
        NiceTrainer:Toast("You must be in-game to spawn an ECM.")
        return
    end

    local pos = player:position() + Vector3(0, 0, 5)
    local rot = player:rotation()
    local unit = ECMJammerBase.spawn(pos, rot, 3, player, managers.network:session():local_peer():id())
    if alive(unit) and unit:base() then
        unit:base():set_active(true)
        NiceTrainer:Toast("⚡ Active ECM Jammer Spawned!")
    end
end

-- Action Registrations for Stealth Tab (Guarded to prevent duplicate entries)
if not NiceTrainer._ecm_timer_actions_registered then
    NiceTrainer._ecm_timer_actions_registered = true

    -- Category: ECM Cheats & Hacks
    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Cheats", badge = "cheat", id = "ecm_infinite_battery", text = "Infinite ECM Duration",
        tooltip = "ECM Jammers and Pocket ECMs will never run out of battery.",
        default = false, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "slider", category = "ECM Cheats", id = "ecm_duration_slider", text = "Custom ECM Duration (Seconds)",
        tooltip = "Set custom duration for all deployed ECM Jammers and Pocket ECMs.",
        min = 20, max = 300, default = 30, save = true,
        callback = function(val) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Cheats", badge = "cheat", id = "ecm_infinite_amount", text = "Infinite ECM Equipment",
        tooltip = "Placing an ECM Jammer will not consume your deployable stock.",
        default = false, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Cheats", badge = "cheat", id = "ecm_all_upgrades", text = "Unlock All ECM Upgrades",
        tooltip = "Forces Pager Jamming, Security Door Opening, and Maximum Duration on all ECMs.",
        default = false, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Cheats", badge = "cheat", id = "ecm_instant_pocket_cooldown", text = "Instant Pocket ECM Cooldown",
        tooltip = "Removes cooldown delay between Pocket ECM uses.",
        default = false, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Cheats", badge = "cheat", id = "ecm_feedback_100", text = "100% Feedback Stun Rate",
        tooltip = "ECM Feedback always succeeds with 100% stun chance on all enemies in radius.",
        default = false, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "button", category = "ECM Cheats", badge = "cheat", text = "Spawn Active ECM Jammer",
        tooltip = "Spawns a fully upgraded active ECM Jammer right at your position.",
        action_btn_text = "Spawn",
        callback = spawn_active_ecm
    })

    -- Category: ECM Timer HUD
    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", badge = "client", id = "ecm_timer_enabled", text = "ECM Timer HUD Widget",
        tooltip = "Displays a real-time countdown timer on the HUD when an ECM is active.",
        default = true, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "multichoice", category = "ECM Timer HUD", id = "ecm_timer_chat_mode", text = "Chat Alert Mode",
        tooltip = "Sends a chat countdown tick (5.. 4.. 3.. 2.. 1..) when ECM battery is running out.",
        options = { "Disabled", "Private (Only You)", "Public (Team/All)" },
        default = 2, save = true,
        callback = function(idx, val) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "slider", category = "ECM Timer HUD", id = "ecm_timer_low_time", text = "Chat Countdown Start (Seconds)",
        tooltip = "Seconds remaining to begin the second-by-second countdown chat alerts.",
        min = 1, max = 15, default = 5, save = true,
        callback = function(val) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", id = "ecm_timer_pager_jam", text = "Only Pager-Delay ECMs",
        tooltip = "Only show the timer for ECMs that delay pagers.",
        default = true, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", id = "ecm_timer_pocket_ecm", text = "Pocket ECM Support",
        tooltip = "Displays timer when Pocket ECMs (Hacker perk deck) are triggered.",
        default = true, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", id = "ecm_timer_animate_low", text = "Animate When Low (<3s)",
        tooltip = "Pulsates timer text size when remaining time is under 3 seconds.",
        default = true, save = true,
        callback = function(state) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", id = "ecm_timer_hide_hudbox", text = "Hide HUD Box Frame",
        tooltip = "Hides the white corners and background behind the timer.",
        default = false, save = true,
        callback = function(state)
            if managers.hud and managers.hud._hud_ecm_counter then
                managers.hud._hud_ecm_counter:update_hudbox_visibility()
            end
        end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "toggle", category = "ECM Timer HUD", id = "ecm_timer_custom_pos", text = "Custom Position Mode",
        tooltip = "Enable manual positioning using the sliders below (instead of auto-attaching under the hostage panel).",
        default = false, save = true,
        callback = function(state)
            if managers.hud and managers.hud._hud_ecm_counter then
                managers.hud._hud_ecm_counter:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "slider", category = "ECM Timer HUD", id = "ecm_timer_pos_x", text = "Manual Position (X)",
        tooltip = "Horizontal position coordinate when Custom Position Mode is active.",
        min = 50, max = 1250, default = 1175, save = true,
        callback = function(val)
            if managers.hud and managers.hud._hud_ecm_counter then
                managers.hud._hud_ecm_counter:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "slider", category = "ECM Timer HUD", id = "ecm_timer_pos_y", text = "Manual Position (Y)",
        tooltip = "Vertical position coordinate when Custom Position Mode is active.",
        min = 10, max = 700, default = 65, save = true,
        callback = function(val)
            if managers.hud and managers.hud._hud_ecm_counter then
                managers.hud._hud_ecm_counter:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "colorpicker", category = "ECM Timer HUD", id = "ecm_timer_color_text", text = "Timer Text Color",
        tooltip = "Color of the ECM countdown text.",
        default = "#FFFFFF", save = true,
        callback = function(color, hex) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "colorpicker", category = "ECM Timer HUD", id = "ecm_timer_color_mid", text = "Medium Time Color (<10s)",
        tooltip = "Color of countdown text when under 10 seconds.",
        default = "#FFCC66", save = true,
        callback = function(color, hex) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "colorpicker", category = "ECM Timer HUD", id = "ecm_timer_color_low", text = "Low Time Color (<3s)",
        tooltip = "Color of countdown text when under 3 seconds.",
        default = "#FF6666", save = true,
        callback = function(color, hex) end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "colorpicker", category = "ECM Timer HUD", id = "ecm_timer_color_icon", text = "Icon Color",
        tooltip = "Color of the ECM icon bitmap.",
        default = "#FFFFFF", save = true,
        callback = function(color, hex)
            if managers.hud and managers.hud._hud_ecm_counter and alive(managers.hud._hud_ecm_counter._icon) then
                managers.hud._hud_ecm_counter._icon:set_color(parse_hex_color(hex, Color.white))
            end
        end
    })

    NiceTrainer:RegisterAction("Stealth", {
        type = "colorpicker", category = "ECM Timer HUD", id = "ecm_timer_color_chat", text = "Chat Alert Color",
        tooltip = "Color of the private chat alert message.",
        default = "#09B1DB", save = true,
        callback = function(color, hex) end
    })
end
