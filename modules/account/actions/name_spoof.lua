-- ─── Name & Profile Privacy Spoof ───────────────────────────────────────────────
-- Fully protects player identity:
-- 1. Broadcasts spoofed name with customizable Unicode PD2 icons (prefix & suffix).
-- 2. Spoofs Steam Profile / Account ID to prevent opening real Steam Profile on click.
-- 3. Intercepts overlay activations, FBI Files suspect links, and lobby clicks.
-- 4. Offers Quick Presets, Custom ID/URL redirection, and Complete Profile Blocking.

-- ============================================================================
-- Icon catalogue (PAYDAY 2 PD2_MEDIUM_FONT Unicode Glyphs: U+E000 to U+E021)
-- ============================================================================
local ICONS = {
    { label = "None",                 char = "",             code = "Off"    },
    { label = "A Button",             char = "\xEE\x80\x80", code = "U+E000" },
    { label = "B Button",             char = "\xEE\x80\x81", code = "U+E001" },
    { label = "X Button",             char = "\xEE\x80\x82", code = "U+E002" },
    { label = "Y Button",             char = "\xEE\x80\x83", code = "U+E003" },
    { label = "Select",               char = "\xEE\x80\x84", code = "U+E004" },
    { label = "Start",                char = "\xEE\x80\x85", code = "U+E005" },
    { label = "L Stick",              char = "\xEE\x80\x86", code = "U+E006" },
    { label = "R Stick",              char = "\xEE\x80\x87", code = "U+E007" },
    { label = "L Bumper",             char = "\xEE\x80\x88", code = "U+E008" },
    { label = "R Bumper",             char = "\xEE\x80\x89", code = "U+E009" },
    { label = "L Trigger",            char = "\xEE\x80\x8A", code = "U+E00A" },
    { label = "R Trigger",            char = "\xEE\x80\x8B", code = "U+E00B" },
    { label = "L Stick (L3)",         char = "\xEE\x80\x8C", code = "U+E00C" },
    { label = "R Stick (R3)",         char = "\xEE\x80\x8D", code = "U+E00D" },
    { label = "D-pad Down",           char = "\xEE\x80\x8E", code = "U+E00E" },
    { label = "D-pad Left",           char = "\xEE\x80\x8F", code = "U+E00F" },
    { label = "D-pad Right",          char = "\xEE\x80\x90", code = "U+E010" },
    { label = "D-pad Up",             char = "\xEE\x80\x91", code = "U+E011" },
    { label = "New Item",             char = "\xEE\x80\x92", code = "U+E012" },
    { label = "Ghost",                char = "\xEE\x80\x93", code = "U+E013" },
    { label = "Skull",                char = "\xEE\x80\x94", code = "U+E014" },
    { label = "Padlock",              char = "\xEE\x80\x95", code = "U+E015" },
    { label = "Plus Hexagon",         char = "\xEE\x80\x96", code = "U+E016" },
    { label = "Heart Hexagon",        char = "\xEE\x80\x97", code = "U+E017" },
    { label = "Crime Spree",          char = "\xEE\x80\x98", code = "U+E018" },
    { label = "Timer 1",              char = "\xEE\x80\x99", code = "U+E019" },
    { label = "Timer 2",              char = "\xEE\x80\x9A", code = "U+E01A" },
    { label = "Timer 3",              char = "\xEE\x80\x9B", code = "U+E01B" },
    { label = "Long Ghost",           char = "\xEE\x80\x9C", code = "U+E01C" },
    { label = "Continental Coin",     char = "\xEE\x80\x9D", code = "U+E01D" },
    { label = "Christmas Tree",       char = "\xEE\x80\x9E", code = "U+E01E" },
    { label = "Range Square (Empty)", char = "\xEE\x80\x9F", code = "U+E01F" },
    { label = "Range Square (Full)",  char = "\xEE\x81\x80", code = "U+E020" },
    { label = "Range Square (Plus)",  char = "\xEE\x81\x81", code = "U+E021" },
}

local NAME_PRESETS = {
    { label = "Ghost (Stealth)",  name = "Ghost",              prefix = 21, suffix = 21 },
    { label = "Anonymous",        name = "Anonymous",          prefix = 23, suffix = 23 },
    { label = "[CLASSIFIED]",     name = "[CLASSIFIED]",       prefix = 23, suffix = 1  },
    { label = "Almir (OVERKILL)", name = "Almir Ready",        prefix = 22, suffix = 22 },
    { label = "Dallas (Medic)",   name = "Dallas",             prefix = 25, suffix = 25 },
    { label = "John Wick",        name = "John Wick",          prefix = 22, suffix = 22 },
    { label = "Cloaker (Sneak)",  name = "Cloaker",            prefix = 21, suffix = 21 },
    { label = "Crime Spree Pro",  name = "Crime Spree Pro",    prefix = 26, suffix = 26 },
    { label = "Coin Hoarder",     name = "Continental Lord",   prefix = 31, suffix = 31 },
}

local DEFAULT_FAKE_STEAM_ID = "76561197960287930" -- Gabe Newell (Valve)

-- Initialize Settings Defaults
NiceTrainer.Settings.name_spoof_enabled      = NiceTrainer.Settings.name_spoof_enabled or false
NiceTrainer.Settings.name_spoof_text         = NiceTrainer.Settings.name_spoof_text or "Anonymous"
NiceTrainer.Settings.name_spoof_prefix_idx   = NiceTrainer.Settings.name_spoof_prefix_idx or 21 -- Ghost icon
NiceTrainer.Settings.name_spoof_suffix_idx   = NiceTrainer.Settings.name_spoof_suffix_idx or 21
NiceTrainer.Settings.profile_spoof_mode      = NiceTrainer.Settings.profile_spoof_mode or 1     -- 1 = Gabe Newell, 2 = Custom ID/URL, 3 = Block Overlay, 4 = Disabled
NiceTrainer.Settings.profile_spoof_custom_id = NiceTrainer.Settings.profile_spoof_custom_id or "76561198000000000"

-- ============================================================================
-- Font Helpers
-- ============================================================================
local function get_icon_font()
    if tweak_data and tweak_data.menu and tweak_data.menu.pd2_medium_font then
        return tweak_data.menu.pd2_medium_font
    end
    if tweak_data and tweak_data.hud and tweak_data.hud.medium_font_n then
        return tweak_data.hud.medium_font_n
    end
    return "fonts/font_medium_mf"
end

local function get_large_font()
    if tweak_data and tweak_data.menu and tweak_data.menu.pd2_large_font then
        return tweak_data.menu.pd2_large_font
    end
    return "fonts/font_large_mf"
end

-- ============================================================================
-- Helpers
-- ============================================================================
local function get_spoofed_name()
    local base  = NiceTrainer.Settings.name_spoof_text or ""
    local pre_i = NiceTrainer.Settings.name_spoof_prefix_idx or 1
    local suf_i = NiceTrainer.Settings.name_spoof_suffix_idx or 1
    local prefix = (ICONS[pre_i] and ICONS[pre_i].char) or ""
    local suffix = (ICONS[suf_i] and ICONS[suf_i].char) or ""
    if base == "" and prefix == "" and suffix == "" then return nil end
    local name = prefix
    if base ~= "" then
        name = name .. (prefix ~= "" and " " or "") .. base .. (suffix ~= "" and " " or "")
    end
    name = name .. suffix
    return name
end

local function get_spoofed_steam_id()
    local mode = NiceTrainer.Settings.profile_spoof_mode or 1
    if mode == 1 then
        return DEFAULT_FAKE_STEAM_ID
    elseif mode == 2 then
        local custom = NiceTrainer.Settings.profile_spoof_custom_id
        if custom and custom ~= "" then
            return custom
        end
        return DEFAULT_FAKE_STEAM_ID
    end
    return nil -- mode 3 = block
end

local function is_my_steam_id(id)
    if not id then return false end
    id = tostring(id)
    local my_id = Steam and Steam.userid and tostring(Steam:userid())
    if my_id and my_id ~= "" and (id == my_id or id:find(my_id, 1, true)) then
        return true
    end
    local my_acc = managers.network and managers.network.account and managers.network.account:player_id()
    if my_acc and my_acc ~= "" and (id == tostring(my_acc) or id:find(tostring(my_acc), 1, true)) then
        return true
    end
    return false
end

-- ============================================================================
-- Core Hooks & Interceptors
-- ============================================================================
NiceTrainer._namespoof_hooked = NiceTrainer._namespoof_hooked or false

local function install_hooks()
    if NiceTrainer._namespoof_hooked then return end

    -- 1. Hook Steam & NetworkAccount Usernames (Menu, Lobby, HUD, Chat)
    if _G.Steam and not Steam._nt_orig_username then
        Steam._nt_orig_username = Steam.username
        function Steam:username(id, ...)
            if NiceTrainer.Settings.name_spoof_enabled then
                if not id or is_my_steam_id(id) then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
            end
            return Steam._nt_orig_username(self, id, ...)
        end
    end

    if _G.NetworkAccountSTEAM then
        if not NetworkAccountSTEAM._nt_orig_username then
            NetworkAccountSTEAM._nt_orig_username = NetworkAccountSTEAM.username
            function NetworkAccountSTEAM:username(...)
                if NiceTrainer.Settings.name_spoof_enabled then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
                return NetworkAccountSTEAM._nt_orig_username(self, ...)
            end
        end
        if not NetworkAccountSTEAM._nt_orig_username_id then
            NetworkAccountSTEAM._nt_orig_username_id = NetworkAccountSTEAM.username_id
            function NetworkAccountSTEAM:username_id(...)
                if NiceTrainer.Settings.name_spoof_enabled then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
                return NetworkAccountSTEAM._nt_orig_username_id(self, ...)
            end
        end
        if not NetworkAccountSTEAM._nt_orig_username_by_id then
            NetworkAccountSTEAM._nt_orig_username_by_id = NetworkAccountSTEAM.username_by_id
            function NetworkAccountSTEAM:username_by_id(id, ...)
                if NiceTrainer.Settings.name_spoof_enabled and (not id or is_my_steam_id(id)) then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
                return NetworkAccountSTEAM._nt_orig_username_by_id(self, id, ...)
            end
        end
    end

    if _G.NetworkMatchMakingSTEAM then
        if not NetworkMatchMakingSTEAM._nt_orig_username then
            NetworkMatchMakingSTEAM._nt_orig_username = NetworkMatchMakingSTEAM.username
            function NetworkMatchMakingSTEAM:username(...)
                if NiceTrainer.Settings.name_spoof_enabled then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
                return NetworkMatchMakingSTEAM._nt_orig_username(self, ...)
            end
        end
        if not NetworkMatchMakingSTEAM._nt_orig_username_by_id then
            NetworkMatchMakingSTEAM._nt_orig_username_by_id = NetworkMatchMakingSTEAM.username_by_id
            function NetworkMatchMakingSTEAM:username_by_id(id, ...)
                if NiceTrainer.Settings.name_spoof_enabled and (not id or is_my_steam_id(id)) then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
                return NetworkMatchMakingSTEAM._nt_orig_username_by_id(self, id, ...)
            end
        end
        if not NetworkMatchMakingSTEAM._nt_orig_set_attributes then
            NetworkMatchMakingSTEAM._nt_orig_set_attributes = NetworkMatchMakingSTEAM.set_attributes
            function NetworkMatchMakingSTEAM:set_attributes(settings, ...)
                local res = NetworkMatchMakingSTEAM._nt_orig_set_attributes(self, settings, ...)
                if NiceTrainer.Settings.name_spoof_enabled and self.lobby_handler then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then
                        self.lobby_handler:set_lobby_data({ owner_name = spoof })
                        if self._lobby_attributes then
                            self._lobby_attributes.owner_name = spoof
                        end
                    end
                end
                return res
            end
        end
        if not NetworkMatchMakingSTEAM._nt_orig_set_server_attributes then
            NetworkMatchMakingSTEAM._nt_orig_set_server_attributes = NetworkMatchMakingSTEAM.set_server_attributes
            function NetworkMatchMakingSTEAM:set_server_attributes(settings, ...)
                local res = NetworkMatchMakingSTEAM._nt_orig_set_server_attributes(self, settings, ...)
                if NiceTrainer.Settings.name_spoof_enabled and self.lobby_handler then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then
                        self.lobby_handler:set_lobby_data({ owner_name = spoof })
                        if self._lobby_attributes then
                            self._lobby_attributes.owner_name = spoof
                        end
                    end
                end
                return res
            end
        end
    end

    -- 2. Hook NetworkPeer name & account_id
    if _G.NetworkPeer then
        if not NetworkPeer._nt_orig_name       then NetworkPeer._nt_orig_name       = NetworkPeer.name end
        if not NetworkPeer._nt_orig_set_name   then NetworkPeer._nt_orig_set_name   = NetworkPeer.set_name end
        if not NetworkPeer._nt_orig_account_id then NetworkPeer._nt_orig_account_id = NetworkPeer.account_id end

        function NetworkPeer:name()
            if NiceTrainer.Settings.name_spoof_enabled then
                local session = managers.network and managers.network:session()
                if session and self == session:local_peer() then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then return spoof end
                end
            end
            return NetworkPeer._nt_orig_name(self)
        end

        function NetworkPeer:set_name(name)
            if NiceTrainer.Settings.name_spoof_enabled then
                local session = managers.network and managers.network:session()
                if session and self == session:local_peer() then
                    local spoof = get_spoofed_name()
                    if spoof and spoof ~= "" then name = spoof end
                end
            end
            return NetworkPeer._nt_orig_set_name(self, name)
        end

        function NetworkPeer:account_id(...)
            if NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local session = managers.network and managers.network:session()
                if session and self == session:local_peer() then
                    local fake_id = get_spoofed_steam_id()
                    if fake_id and not fake_id:find("^https?://") then
                        return fake_id
                    end
                end
            end
            return NetworkPeer._nt_orig_account_id(self, ...)
        end
    end

    -- 2. Hook Steam:overlay_activate & NetworkAccountSTEAM:overlay_activate
    if _G.Steam and not Steam._nt_orig_overlay_activate then
        Steam._nt_orig_overlay_activate = Steam.overlay_activate
        function Steam:overlay_activate(type_name, destination, extra_flags, ...)
            if NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local mode = NiceTrainer.Settings.profile_spoof_mode or 1
                if mode == 3 and (is_my_steam_id(destination) or type_name == "steamid" or type_name == "game" or type_name == "community") then
                    NiceTrainer:Toast("Profile overlay blocked by Privacy Spoof.")
                    return
                end
                if is_my_steam_id(destination) then
                    local fake_id = get_spoofed_steam_id()
                    if fake_id then
                        if type_name == "url" and type(destination) == "string" then
                            local my_id = Steam and Steam.userid and tostring(Steam:userid()) or ""
                            if my_id ~= "" and destination:find(my_id, 1, true) then
                                destination = destination:gsub(my_id, fake_id)
                            elseif fake_id:find("^https?://") then
                                destination = fake_id
                            else
                                destination = "https://steamcommunity.com/profiles/" .. fake_id
                            end
                        elseif type_name == "community" or type_name == "steamid" then
                            destination = fake_id
                        end
                    else
                        NiceTrainer:Toast("Profile overlay blocked by Privacy Spoof.")
                        return
                    end
                end
            end
            return Steam._nt_orig_overlay_activate(self, type_name, destination, extra_flags, ...)
        end
    end

    if _G.NetworkAccountSTEAM and not NetworkAccountSTEAM._nt_orig_overlay_activate then
        NetworkAccountSTEAM._nt_orig_overlay_activate = NetworkAccountSTEAM.overlay_activate
        function NetworkAccountSTEAM:overlay_activate(type_name, destination, ...)
            if NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local mode = NiceTrainer.Settings.profile_spoof_mode or 1
                if mode == 3 and (is_my_steam_id(destination) or type_name == "steamid") then
                    NiceTrainer:Toast("Profile overlay blocked by Privacy Spoof.")
                    return
                end
                if is_my_steam_id(destination) then
                    local fake_id = get_spoofed_steam_id()
                    if fake_id then
                        if type_name == "url" and type(destination) == "string" then
                            local my_id = Steam and Steam.userid and tostring(Steam:userid()) or ""
                            if my_id ~= "" and destination:find(my_id, 1, true) then
                                destination = destination:gsub(my_id, fake_id)
                            elseif fake_id:find("^https?://") then
                                destination = fake_id
                            else
                                destination = "https://steamcommunity.com/profiles/" .. fake_id
                            end
                        elseif type_name == "community" or type_name == "steamid" then
                            destination = fake_id
                        end
                    else
                        NiceTrainer:Toast("Profile overlay blocked by Privacy Spoof.")
                        return
                    end
                end
            end
            return NetworkAccountSTEAM._nt_orig_overlay_activate(self, type_name, destination, ...)
        end
    end

    -- 3. Hook GUI Profile Boxes (Profile clicks in menus & lobbies)
    if _G.ProfileBoxGui and not ProfileBoxGui._nt_orig_trigger_profile then
        ProfileBoxGui._nt_orig_trigger_profile = ProfileBoxGui._trigger_profile
        function ProfileBoxGui:_trigger_profile(...)
            if NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local mode = NiceTrainer.Settings.profile_spoof_mode or 1
                if mode == 3 then
                    NiceTrainer:Toast("Profile click blocked by Privacy Spoof.")
                    return
                end
                local fake_id = get_spoofed_steam_id()
                if fake_id then
                    if fake_id:find("^https?://") then
                        Steam:overlay_activate("url", fake_id)
                    else
                        Steam:overlay_activate("url", "https://steamcommunity.com/profiles/" .. fake_id)
                    end
                    return
                end
            end
            return ProfileBoxGui._nt_orig_trigger_profile(self, ...)
        end
    end

    if _G.LobbyProfileBoxGui and not LobbyProfileBoxGui._nt_orig_trigger_profile then
        LobbyProfileBoxGui._nt_orig_trigger_profile = LobbyProfileBoxGui._trigger_profile
        function LobbyProfileBoxGui:_trigger_profile(...)
            local session = managers.network and managers.network:session()
            local peer = session and session:peer(self._peer_id)
            if peer and peer == session:local_peer() and NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local mode = NiceTrainer.Settings.profile_spoof_mode or 1
                if mode == 3 then
                    NiceTrainer:Toast("Profile click blocked by Privacy Spoof.")
                    return
                end
                local fake_id = get_spoofed_steam_id()
                if fake_id then
                    if fake_id:find("^https?://") then
                        Steam:overlay_activate("url", fake_id)
                    else
                        Steam:overlay_activate("url", "https://steamcommunity.com/profiles/" .. fake_id)
                    end
                    return
                end
            end
            return LobbyProfileBoxGui._nt_orig_trigger_profile(self, ...)
        end
    end

    -- 4. Hook FBI Files suspect link
    if _G.MenuCallbackHandler and not MenuCallbackHandler._nt_orig_on_visit_fbi_files_suspect then
        MenuCallbackHandler._nt_orig_on_visit_fbi_files_suspect = MenuCallbackHandler.on_visit_fbi_files_suspect
        function MenuCallbackHandler:on_visit_fbi_files_suspect(item, ...)
            if NiceTrainer.Settings.name_spoof_enabled and (NiceTrainer.Settings.profile_spoof_mode or 1) ~= 4 then
                local fake_id = get_spoofed_steam_id()
                local my_acc = managers.network and managers.network.account and managers.network.account:player_id()
                if fake_id and item and (item:name() == my_acc or item:name() == fake_id) then
                    managers.network.account:overlay_activate("url", tweak_data.gui.fbi_files_webpage .. "/suspect/" .. fake_id .. "/")
                    return
                elseif (NiceTrainer.Settings.profile_spoof_mode or 1) == 3 then
                    NiceTrainer:Toast("FBI Files suspect link blocked by Privacy Spoof.")
                    return
                end
            end
            return MenuCallbackHandler._nt_orig_on_visit_fbi_files_suspect(self, item, ...)
        end
    end

    NiceTrainer._namespoof_hooked = true
end

local function push_name_to_live_peer()
    pcall(function()
        local spoof = get_spoofed_name()
        local session = managers.network and managers.network:session()
        local peer    = session and session:local_peer()
        if peer then
            local name = (NiceTrainer.Settings.name_spoof_enabled and spoof and spoof ~= "") and spoof
                or (Steam and Steam._nt_orig_username and Steam._nt_orig_username(Steam))
                or (managers.network and managers.network.account and managers.network.account:username())
                or peer:name()
            peer:set_name(name)
            if managers.hud and managers.hud.set_teammate_name then
                pcall(function()
                    managers.hud:set_teammate_name(HUDManager.PLAYER_PANEL or 4, name)
                end)
            end
        end
        if managers.network and managers.network.matchmake and managers.network.matchmake.lobby_handler then
            if NiceTrainer.Settings.name_spoof_enabled and spoof and spoof ~= "" then
                managers.network.matchmake.lobby_handler:set_lobby_data({ owner_name = spoof })
                if managers.network.matchmake._lobby_attributes then
                    managers.network.matchmake._lobby_attributes.owner_name = spoof
                end
            elseif Steam and Steam._nt_orig_username then
                local real_name = Steam._nt_orig_username(Steam)
                if real_name then
                    managers.network.matchmake.lobby_handler:set_lobby_data({ owner_name = real_name })
                    if managers.network.matchmake._lobby_attributes then
                        managers.network.matchmake._lobby_attributes.owner_name = real_name
                    end
                end
            end
        end
    end)
end

local function apply_name_spoof(state)
    if state then
        install_hooks()
        push_name_to_live_peer()
    else
        push_name_to_live_peer()
    end
end

local function randomize_name_spoof()
    local idx = math.random(1, #NAME_PRESETS)
    local preset = NAME_PRESETS[idx]
    NiceTrainer.Settings.name_spoof_text       = preset.name
    NiceTrainer.Settings.name_spoof_prefix_idx = preset.prefix
    NiceTrainer.Settings.name_spoof_suffix_idx = preset.suffix
    NiceTrainer:Save()
    push_name_to_live_peer()
    NiceTrainer:Toast("Randomized Name: " .. preset.label)
end

-- Re-apply on heist load so the hook survives level transitions
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NameSpoof_Reapply", function()
    if NiceTrainer.Settings.name_spoof_enabled then
        install_hooks()
        push_name_to_live_peer()
    end
end)

-- Auto-install on start
install_hooks()

-- ============================================================================
-- Settings Modal Layout & Builder
-- ============================================================================
local MOD_W = 600

local CELL_W, CELL_H = 48, 44
local INNER_W = MOD_W - 40

local function icon_cols() return math.floor(INNER_W / CELL_W) end
local function icon_rows() return math.ceil(#ICONS / icon_cols()) end
local function grid_height() return icon_rows() * CELL_H end

local SECTION_CHROME = 32
local INPUT_H        = 38
local PREVIEW_H      = 52
local BTN_H          = 38
local PADDING        = 12

local CANVAS_H = (
    SECTION_CHROME + INPUT_H + PADDING +
    SECTION_CHROME + 40 + PADDING +
    SECTION_CHROME + grid_height() + PADDING +
    SECTION_CHROME + grid_height() + PADDING +
    SECTION_CHROME + (INPUT_H * 2) + PADDING +
    PREVIEW_H + PADDING +
    BTN_H + PADDING + 30
)

local MOD_H = math.min(CANVAS_H + 70, 720)

local function build_name_spoof_modal()
    NiceTrainer:ShowCustomModal("Name & Profile Spoof Settings", MOD_W, MOD_H, function(p)
        local ms = NiceTrainer._modals_stack
        local modal_state = ms and ms[#ms]
        if not modal_state then return end

        local BG   = Color(0.2, 0.6, 1.0)
        local FNT  = get_icon_font()
        local LFNT = get_large_font()

        local scroll_wrapper = p:panel({ x = 0, y = 55, w = MOD_W, h = MOD_H - 55, layer = 2 })
        local canvas = scroll_wrapper:panel({ x = 0, y = 0, w = MOD_W, h = CANVAS_H, layer = 1 })
        modal_state.scroll = { wrapper = scroll_wrapper, canvas = canvas }

        local cy = 8

        local preview_txt_ref    = nil
        local profile_prev_ref   = nil
        local name_val_text_ref  = nil
        local custom_id_text_ref = nil
        local is_placeholder_ref = { v = true }
        local is_custom_id_ph    = { v = true }

        local prefix_info_txt    = nil
        local suffix_info_txt    = nil

        local function refresh_preview()
            if not alive(preview_txt_ref) then return end
            local base = (not is_placeholder_ref.v)
                and (alive(name_val_text_ref) and name_val_text_ref:text() or "")
                or  (NiceTrainer.Settings.name_spoof_text or "")
            local pre_i  = NiceTrainer.Settings.name_spoof_prefix_idx or 1
            local suf_i  = NiceTrainer.Settings.name_spoof_suffix_idx or 1
            local pre    = (ICONS[pre_i] and ICONS[pre_i].char) or ""
            local suf    = (ICONS[suf_i] and ICONS[suf_i].char) or ""
            local out    = pre
            if base ~= "" then
                out = out .. (pre ~= "" and " " or "") .. base .. (suf ~= "" and " " or "")
            end
            out = out .. suf
            preview_txt_ref:set_text(out ~= "" and out or "(none)")

            if alive(profile_prev_ref) then
                local mode = NiceTrainer.Settings.profile_spoof_mode or 1
                local mode_str = "Gabe Newell (76561197960287930)"
                if mode == 2 then
                    local custom = (not is_custom_id_ph.v) and (alive(custom_id_text_ref) and custom_id_text_ref:text() or "") or (NiceTrainer.Settings.profile_spoof_custom_id or "")
                    mode_str = "Custom: " .. (custom ~= "" and custom or DEFAULT_FAKE_STEAM_ID)
                elseif mode == 3 then
                    mode_str = "BLOCKED (Overlay suppressed)"
                elseif mode == 4 then
                    mode_str = "Real Profile (Unprotected)"
                end
                profile_prev_ref:set_text("Target: " .. mode_str)
            end

            if alive(prefix_info_txt) then
                local item = ICONS[pre_i] or ICONS[1]
                prefix_info_txt:set_text("Prefix: " .. item.label .. " [" .. item.code .. "]")
            end
            if alive(suffix_info_txt) then
                local item = ICONS[suf_i] or ICONS[1]
                suffix_info_txt:set_text("Suffix: " .. item.label .. " [" .. item.code .. "]")
            end
        end

        local function make_section_header(title)
            local title_p = canvas:panel({ x = 20, y = cy, w = INNER_W, h = 26, layer = 2 })
            local lbl = title_p:text({
                text = title, font = FNT, font_size = 14,
                color = BG, vertical = "center", layer = 1
            })
            local info_lbl = title_p:text({
                text = "", font = FNT, font_size = 12,
                color = Color(0.7, 0.7, 0.7), align = "right", vertical = "center", layer = 1
            })
            canvas:rect({ color = BG, alpha = 0.35, x = 20, y = cy + 26, w = INNER_W, h = 1, layer = 2 })
            cy = cy + SECTION_CHROME
            return info_lbl
        end

        -- 1. Custom Name input
        make_section_header("CUSTOM SPOOFED NAME")

        local input_p  = canvas:panel({ x = 20, y = cy, w = INNER_W, h = INPUT_H, layer = 2 })
        local input_bg = input_p:rect({ color = BG, alpha = 0.12, layer = 0 })
        input_p:rect({ color = BG, alpha = 0.5, w = 1,          layer = 1 })
        input_p:rect({ color = BG, alpha = 0.5, x = INNER_W - 1, w = 1, layer = 1 })
        input_p:rect({ color = BG, alpha = 0.5, h = 1,          layer = 1 })
        input_p:rect({ color = BG, alpha = 0.5, y = INPUT_H - 1, h = 1, layer = 1 })

        local saved_name = NiceTrainer.Settings.name_spoof_text or ""
        local placeholder = "Type your name here..."
        is_placeholder_ref.v = (saved_name == "")
        local val_text = input_p:text({
            text     = is_placeholder_ref.v and placeholder or saved_name,
            font     = FNT, font_size = 18,
            color    = is_placeholder_ref.v and Color(0.4, 0.4, 0.4) or Color.white,
            x = 10, vertical = "center", layer = 2
        })
        name_val_text_ref = val_text

        local clr_w = 30
        local clr_p = input_p:panel({ x = INNER_W - clr_w - 2, y = 4, w = clr_w, h = INPUT_H - 8, layer = 3 })
        local clr_bg = clr_p:rect({ color = Color(0.8, 0.2, 0.2), alpha = 0.0, layer = 0 })
        local clr_t  = clr_p:text({ text = "×", font = LFNT, font_size = 20,
            align = "center", vertical = "center", color = Color(0.6, 0.3, 0.3), layer = 1 })

        table.insert(modal_state.elements, {
            panel  = clr_p,
            inside = function(self, mx, my) return clr_p:inside(mx, my) end,
            on_hover = function(self, hovered)
                clr_bg:set_alpha(hovered and 0.35 or 0.0)
                clr_t:set_color(hovered and Color.white or Color(0.6, 0.3, 0.3))
            end,
            on_click = function(self)
                val_text:set_text(placeholder)
                val_text:set_color(Color(0.4, 0.4, 0.4))
                is_placeholder_ref.v = true
                refresh_preview()
            end
        })

        local keyboard_active = false
        table.insert(modal_state.elements, {
            panel  = input_p,
            inside = function(self, mx, my)
                return scroll_wrapper:inside(mx, my) and input_p:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                input_bg:set_alpha(hovered and 0.25 or (keyboard_active and 0.35 or 0.12))
            end,
            on_click = function(self, mx, my)
                if clr_p:inside(mx, my) then return end
                if is_placeholder_ref.v then
                    val_text:set_text("")
                    val_text:set_color(Color.white)
                    is_placeholder_ref.v = false
                end
                if keyboard_active then return end
                keyboard_active = true
                input_bg:set_alpha(0.35)
                if alive(NiceTrainer._panel) then
                    NiceTrainer._ws:connect_keyboard(Input:keyboard())
                    NiceTrainer._panel:key_press(function(o, k)
                        if k == Idstring("backspace") then
                            local t = val_text:text()
                            val_text:set_text(string.sub(t, 1, -2))
                            refresh_preview()
                        elseif k == Idstring("enter") or k == Idstring("escape") then
                            keyboard_active = false
                            input_bg:set_alpha(0.12)
                            NiceTrainer._panel:key_press(nil)
                            NiceTrainer._panel:enter_text(nil)
                            NiceTrainer._ws:disconnect_keyboard()
                        end
                    end)
                    NiceTrainer._panel:enter_text(function(o, s)
                        local t = val_text:text()
                        if #t < 32 then
                            val_text:set_text(t .. s)
                            refresh_preview()
                        end
                    end)
                end
            end
        })

        cy = cy + INPUT_H + PADDING

        -- 2. Quick Presets Bar
        make_section_header("QUICK NAME PRESETS")
        local pset_p = canvas:panel({ x = 20, y = cy, w = INNER_W, h = 34, layer = 2 })
        local pw = (INNER_W - (#NAME_PRESETS - 1) * 4) / #NAME_PRESETS
        for pi, preset in ipairs(NAME_PRESETS) do
            local px = (pi - 1) * (pw + 4)
            local pbtn = pset_p:panel({ x = px, y = 0, w = pw, h = 32, layer = 1 })
            local pbg = pbtn:rect({ color = BG, alpha = 0.12, layer = 0 })
            pbtn:rect({ color = BG, alpha = 0.5, w = 1, layer = 1 })
            pbtn:rect({ color = BG, alpha = 0.5, x = pw - 1, w = 1, layer = 1 })
            pbtn:rect({ color = BG, alpha = 0.5, h = 1, layer = 1 })
            pbtn:rect({ color = BG, alpha = 0.5, y = 31, h = 1, layer = 1 })
            local pt = pbtn:text({
                text = preset.name, font = FNT, font_size = 11,
                align = "center", vertical = "center", color = Color(0.85, 0.85, 0.85), layer = 2
            })
            table.insert(modal_state.elements, {
                panel = pbtn,
                inside = function(self, mx, my)
                    return scroll_wrapper:inside(mx, my) and pbtn:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    pbg:set_alpha(hovered and 0.35 or 0.12)
                    pt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                end,
                on_click = function(self)
                    val_text:set_text(preset.name)
                    val_text:set_color(Color.white)
                    is_placeholder_ref.v = false
                    NiceTrainer.Settings.name_spoof_prefix_idx = preset.prefix
                    NiceTrainer.Settings.name_spoof_suffix_idx = preset.suffix
                    refresh_preview()
                end
            })
        end
        cy = cy + 34 + PADDING

        -- 3. Prefix icon grid
        local function make_icon_grid(setting_key, info_lbl_target)
            local cols      = icon_cols()
            local cur_idx   = NiceTrainer.Settings[setting_key] or 1
            local cell_refs = {}

            local function apply_sel(i, selected)
                local r = cell_refs[i]
                if not r or not alive(r.bg) then return end
                r.bg:set_alpha(selected and 0.4 or 0.08)
                if alive(r.txt) then
                    r.txt:set_color(selected and Color.white or Color(0.75, 0.75, 0.75))
                end
                if alive(r.st) then r.st:set_visible(selected) end
                if alive(r.sb) then r.sb:set_visible(selected) end
                if alive(r.sl) then r.sl:set_visible(selected) end
                if alive(r.sr) then r.sr:set_visible(selected) end
            end

            for i, icon in ipairs(ICONS) do
                local col_i  = (i - 1) % cols
                local row_i  = math.floor((i - 1) / cols)
                local cx     = 20 + col_i * CELL_W
                local cell_y = cy + row_i * CELL_H

                local cell    = canvas:panel({ x = cx, y = cell_y, w = CELL_W - 2, h = CELL_H - 2, layer = 2 })
                local is_sel  = (i == cur_idx)
                local cell_bg = cell:rect({ color = BG, alpha = is_sel and 0.4 or 0.08, layer = 0 })

                local st = cell:rect({ color = BG, alpha = 0.9, h = 1,            layer = 1, visible = is_sel })
                local sb = cell:rect({ color = BG, alpha = 0.9, y = CELL_H - 3, h = 1, layer = 1, visible = is_sel })
                local sl = cell:rect({ color = BG, alpha = 0.9, w = 1,            layer = 1, visible = is_sel })
                local sr = cell:rect({ color = BG, alpha = 0.9, x = CELL_W - 3, w = 1, layer = 1, visible = is_sel })

                local display = icon.char ~= "" and icon.char or "—"
                local ctxt = cell:text({
                    text = display,
                    font = FNT,
                    font_size = (icon.char ~= "" and 22 or 14),
                    align = "center",
                    vertical = "center",
                    color = is_sel and Color.white or Color(0.75, 0.75, 0.75),
                    layer = 2
                })

                cell_refs[i] = { bg = cell_bg, txt = ctxt, st = st, sb = sb, sl = sl, sr = sr }

                table.insert(modal_state.elements, {
                    panel  = cell,
                    inside = function(self, mx, my)
                        return scroll_wrapper:inside(mx, my) and cell:inside(mx, my)
                    end,
                    on_hover = function(self, hovered)
                        local selected = (NiceTrainer.Settings[setting_key] or 1) == i
                        cell_bg:set_alpha(hovered and 0.25 or (selected and 0.4 or 0.08))
                        if hovered and alive(info_lbl_target) then
                            info_lbl_target:set_text(icon.label .. " (" .. icon.code .. ")")
                            info_lbl_target:set_color(Color.white)
                        elseif not hovered and alive(info_lbl_target) then
                            local sel_item = ICONS[NiceTrainer.Settings[setting_key] or 1] or ICONS[1]
                            info_lbl_target:set_text(sel_item.label .. " [" .. sel_item.code .. "]")
                            info_lbl_target:set_color(Color(0.7, 0.7, 0.7))
                        end
                    end,
                    on_click = function(self)
                        local old = NiceTrainer.Settings[setting_key] or 1
                        apply_sel(old, false)
                        NiceTrainer.Settings[setting_key] = i
                        apply_sel(i, true)
                        refresh_preview()
                    end
                })
            end

            cy = cy + grid_height() + PADDING
        end

        prefix_info_txt = make_section_header("PREFIX ICON")
        make_icon_grid("name_spoof_prefix_idx", prefix_info_txt)

        -- 4. Suffix icon grid
        suffix_info_txt = make_section_header("SUFFIX ICON")
        make_icon_grid("name_spoof_suffix_idx", suffix_info_txt)

        -- 5. Profile & Anti-Stalking Privacy Redirection
        make_section_header("PROFILE SPOOF & PRIVACY REDIRECTION")
        local prof_modes = {
            { id = 1, label = "Gabe Newell (SteamID)" },
            { id = 2, label = "Custom SteamID / URL" },
            { id = 3, label = "Block Overlay Completely" },
            { id = 4, label = "Real Profile (Off)" }
        }
        local mode_w = (INNER_W - 3 * 6) / 4
        local prof_btns = {}

        local function apply_prof_mode_sel(m_id)
            for id, b in pairs(prof_btns) do
                local sel = (id == m_id)
                if alive(b.bg) then b.bg:set_alpha(sel and 0.45 or 0.12) end
                if alive(b.txt) then b.txt:set_color(sel and Color.white or Color(0.7, 0.7, 0.7)) end
            end
        end

        local cur_prof_mode = NiceTrainer.Settings.profile_spoof_mode or 1
        local mode_p = canvas:panel({ x = 20, y = cy, w = INNER_W, h = 32, layer = 2 })
        for mi, m in ipairs(prof_modes) do
            local mx = (mi - 1) * (mode_w + 6)
            local mb = mode_p:panel({ x = mx, y = 0, w = mode_w, h = 32, layer = 1 })
            local mbg = mb:rect({ color = BG, alpha = (m.id == cur_prof_mode) and 0.45 or 0.12, layer = 0 })
            mb:rect({ color = BG, alpha = 0.5, w = 1, layer = 1 })
            mb:rect({ color = BG, alpha = 0.5, x = mode_w - 1, w = 1, layer = 1 })
            mb:rect({ color = BG, alpha = 0.5, h = 1, layer = 1 })
            mb:rect({ color = BG, alpha = 0.5, y = 31, h = 1, layer = 1 })
            local mt = mb:text({
                text = m.label, font = FNT, font_size = 11,
                align = "center", vertical = "center",
                color = (m.id == cur_prof_mode) and Color.white or Color(0.7, 0.7, 0.7),
                layer = 2
            })
            prof_btns[m.id] = { bg = mbg, txt = mt }

            table.insert(modal_state.elements, {
                panel = mb,
                inside = function(self, x, y)
                    return scroll_wrapper:inside(x, y) and mb:inside(x, y)
                end,
                on_hover = function(self, hovered)
                    local sel = (NiceTrainer.Settings.profile_spoof_mode or 1) == m.id
                    mbg:set_alpha(hovered and 0.35 or (sel and 0.45 or 0.12))
                    mt:set_color(hovered and Color.white or (sel and Color.white or Color(0.7, 0.7, 0.7)))
                end,
                on_click = function(self)
                    NiceTrainer.Settings.profile_spoof_mode = m.id
                    apply_prof_mode_sel(m.id)
                    refresh_preview()
                end
            })
        end
        cy = cy + 32 + 8

        -- Custom Steam ID input
        local custom_id_p  = canvas:panel({ x = 20, y = cy, w = INNER_W, h = INPUT_H, layer = 2 })
        local custom_id_bg = custom_id_p:rect({ color = BG, alpha = 0.12, layer = 0 })
        custom_id_p:rect({ color = BG, alpha = 0.5, w = 1, layer = 1 })
        custom_id_p:rect({ color = BG, alpha = 0.5, x = INNER_W - 1, w = 1, layer = 1 })
        custom_id_p:rect({ color = BG, alpha = 0.5, h = 1, layer = 1 })
        custom_id_p:rect({ color = BG, alpha = 0.5, y = INPUT_H - 1, h = 1, layer = 1 })

        local saved_custom_id = NiceTrainer.Settings.profile_spoof_custom_id or ""
        local id_ph = "Custom SteamID64 / URL (Used when Custom mode selected)..."
        is_custom_id_ph.v = (saved_custom_id == "")
        local custom_id_val = custom_id_p:text({
            text     = is_custom_id_ph.v and id_ph or saved_custom_id,
            font     = FNT, font_size = 14,
            color    = is_custom_id_ph.v and Color(0.4, 0.4, 0.4) or Color.white,
            x = 10, vertical = "center", layer = 2
        })
        custom_id_text_ref = custom_id_val

        local id_kb_active = false
        table.insert(modal_state.elements, {
            panel  = custom_id_p,
            inside = function(self, mx, my)
                return scroll_wrapper:inside(mx, my) and custom_id_p:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                custom_id_bg:set_alpha(hovered and 0.25 or (id_kb_active and 0.35 or 0.12))
            end,
            on_click = function(self)
                if is_custom_id_ph.v then
                    custom_id_val:set_text("")
                    custom_id_val:set_color(Color.white)
                    is_custom_id_ph.v = false
                end
                if id_kb_active then return end
                id_kb_active = true
                custom_id_bg:set_alpha(0.35)
                if alive(NiceTrainer._panel) then
                    NiceTrainer._ws:connect_keyboard(Input:keyboard())
                    NiceTrainer._panel:key_press(function(o, k)
                        if k == Idstring("backspace") then
                            local t = custom_id_val:text()
                            custom_id_val:set_text(string.sub(t, 1, -2))
                            refresh_preview()
                        elseif k == Idstring("enter") or k == Idstring("escape") then
                            id_kb_active = false
                            custom_id_bg:set_alpha(0.12)
                            NiceTrainer._panel:key_press(nil)
                            NiceTrainer._panel:enter_text(nil)
                            NiceTrainer._ws:disconnect_keyboard()
                        end
                    end)
                    NiceTrainer._panel:enter_text(function(o, s)
                        local t = custom_id_val:text()
                        if #t < 64 then
                            custom_id_val:set_text(t .. s)
                            refresh_preview()
                        end
                    end)
                end
            end
        })

        cy = cy + INPUT_H + PADDING

        -- 6. Live preview bar
        local prev_p = canvas:panel({ x = 20, y = cy, w = INNER_W, h = PREVIEW_H, layer = 2 })
        prev_p:rect({ color = Color(0.06, 0.06, 0.08), alpha = 0.95, layer = 0 })
        prev_p:rect({ color = BG, alpha = 0.25, h = 1, layer = 1 })
        prev_p:rect({ color = BG, alpha = 0.25, y = PREVIEW_H - 1, h = 1, layer = 1 })

        local prev_title = prev_p:text({
            text = "NAME:", font = FNT, font_size = 12,
            color = Color(0.4, 0.7, 1.0), x = 12, y = 8, layer = 2
        })
        local prev_txt = prev_p:text({
            text = "", font = FNT, font_size = 18,
            color = Color.white, x = 60, y = 6, layer = 2
        })
        preview_txt_ref = prev_txt

        local prof_prev = prev_p:text({
            text = "Target: Gabe Newell", font = FNT, font_size = 12,
            color = Color(0.3, 0.9, 0.4), x = 12, y = 28, layer = 2
        })
        profile_prev_ref = prof_prev

        refresh_preview()

        cy = cy + PREVIEW_H + PADDING

        -- 7. Action buttons (APPLY / RANDOMIZE / CANCEL)
        local btn_w3 = (INNER_W - 16) / 3

        local function make_btn(label, bx, col, onclick)
            local btn = canvas:panel({ x = bx, y = cy, w = btn_w3, h = BTN_H, layer = 2 })
            local bb  = btn:rect({ color = col, alpha = 0.18, layer = 0 })
            btn:rect({ color = col, alpha = 0.7, w = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, x = btn_w3 - 1, w = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, h = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, y = BTN_H - 1, h = 1, layer = 1 })
            local bt = btn:text({ text = label, font = FNT, font_size = 13,
                align = "center", vertical = "center", color = Color.white, layer = 2 })
            table.insert(modal_state.elements, {
                panel  = btn,
                inside = function(self, mx, my)
                    return scroll_wrapper:inside(mx, my) and btn:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    bb:set_alpha(hovered and 0.45 or 0.18)
                    bt:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
                end,
                on_click = onclick
            })
        end

        local function cleanup_keyboard()
            keyboard_active = false
            id_kb_active = false
            if alive(NiceTrainer._panel) then
                NiceTrainer._panel:key_press(nil)
                NiceTrainer._panel:enter_text(nil)
            end
            if NiceTrainer._ws then NiceTrainer._ws:disconnect_keyboard() end
        end

        make_btn("APPLY & SAVE", 20, BG, function()
            cleanup_keyboard()
            local new_name = (not is_placeholder_ref.v) and (alive(val_text) and val_text:text() or "") or ""
            local new_custom_id = (not is_custom_id_ph.v) and (alive(custom_id_val) and custom_id_val:text() or "") or ""
            NiceTrainer.Settings.name_spoof_text = new_name
            NiceTrainer.Settings.profile_spoof_custom_id = new_custom_id
            NiceTrainer:Save()
            if NiceTrainer.Settings.name_spoof_enabled then
                install_hooks()
                push_name_to_live_peer()
            end
            NiceTrainer:CloseModal()
            NiceTrainer:Toast("Name & Profile Spoof updated!")
        end)

        make_btn("RANDOMIZE", 20 + btn_w3 + 8, Color(0.8, 0.6, 0.2), function()
            local idx = math.random(1, #NAME_PRESETS)
            local preset = NAME_PRESETS[idx]
            val_text:set_text(preset.name)
            val_text:set_color(Color.white)
            is_placeholder_ref.v = false
            NiceTrainer.Settings.name_spoof_prefix_idx = preset.prefix
            NiceTrainer.Settings.name_spoof_suffix_idx = preset.suffix
            refresh_preview()
        end)

        make_btn("CANCEL", 20 + (btn_w3 + 8) * 2, Color(0.7, 0.2, 0.2), function()
            cleanup_keyboard()
            NiceTrainer:CloseModal()
        end)

        cy = cy + BTN_H + PADDING

        if alive(canvas) then canvas:set_h(cy) end
    end)
end

-- ============================================================================
-- Registration
-- ============================================================================

NiceTrainer:RegisterAction("Account", {
    type              = "toggle_settings",
    category          = "Identity & Anti-Cheat",
    badge             = "client",
    id                = "name_spoof_enabled",
    text              = "Name & Profile Privacy Spoof",
    tooltip           = "Broadcasts a spoofed name and intercepts profile clicks so others cannot view your real Steam account. Click (...) to customize.",
    default           = false,
    callback          = function(state)
        apply_name_spoof(state)
    end,
    settings_callback = function()
        build_name_spoof_modal()
    end,
})

