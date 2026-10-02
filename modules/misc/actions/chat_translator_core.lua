ChatTranslator = ChatTranslator or {}
ChatTranslator.CHAT_TYPE = {
    CHATGUI = 1,
    HUDCHAT = 2
}
ChatTranslator.HUD = {
    DEFAULT = 1,
    WOLFHUD = 2,
    VOIDUI = 3,
    VANILLAHUD = 4,
    AUTO = 5
}
ChatTranslator.default_settings = {
    enabled = false,
    language = "en",
    keyword = "tl",
    hud = ChatTranslator.HUD.AUTO,
    extend_chat = true,
    mouse_pointer = true
}

ChatTranslator._mod_path = (NiceTrainer and NiceTrainer.ModPath) or ModPath or "mods/NiceTrainer/"
ChatTranslator._languages_file = ChatTranslator._mod_path .. "data/languages.json"
ChatTranslator._save_path = SavePath
ChatTranslator._save_file = ChatTranslator._save_path .. "chat_translator.json"

local function deep_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        setmetatable(copy, deep_copy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function ChatTranslator:Setup()
    if not self.settings then
        self:Load()
        self.LoadLanguages()
    end

    HSAS = HSAS or {}

    self.SetupHooks()
end

function ChatTranslator:Load()
    self.settings = deep_copy(self.default_settings)
    local settings = _G.NiceTrainer and _G.NiceTrainer.Settings or (_G.GetNiceTrainerSettings and _G.GetNiceTrainerSettings() or {})
    for key, _ in pairs(self.settings) do
        local saved_val = settings["chat_translator_" .. key]
        if saved_val ~= nil then
            self.settings[key] = saved_val
        end
    end
end

function ChatTranslator:Save()
    if _G.NiceTrainer and _G.NiceTrainer.Settings then
        for key, value in pairs(self.settings) do
            _G.NiceTrainer.Settings["chat_translator_" .. key] = value
        end
        _G.NiceTrainer:Save()
    end
end

-- The chat HUD is identified from the HUDChat class itself so that the mod always follows whichever
-- HUD mod actually owns the chat, no matter what the saved setting says or in which order mods load.
function ChatTranslator.DetectHUD()
    if HUDChat then
        if HUDChat._layout_custom_output_panel then
            return ChatTranslator.HUD.VOIDUI
        elseif HUDChat.MAX_OUTPUT_LINES then
            return WolfHUD and ChatTranslator.HUD.WOLFHUD or ChatTranslator.HUD.VANILLAHUD
        end

        return ChatTranslator.HUD.DEFAULT
    end

    -- HUDChat only exists ingame, fall back to the HUD mods themselves in the menu state
    if VoidUI and VoidUI.options and VoidUI.options.enable_chat then
        return ChatTranslator.HUD.VOIDUI
    elseif WolfHUD then
        return ChatTranslator.HUD.WOLFHUD
    elseif VHUDPlus and VHUDPlus:getSetting({"HUDChat", "ENABLED"}, true) then
        return ChatTranslator.HUD.VANILLAHUD
    end

    return ChatTranslator.HUD.DEFAULT
end

function ChatTranslator.ResolveHUD()
    local detected = ChatTranslator.DetectHUD()

    ChatTranslator.hud = detected
    ChatTranslator.can_extend_chat = detected == ChatTranslator.HUD.DEFAULT
    ChatTranslator.can_use_mouse_pointer = detected == ChatTranslator.HUD.DEFAULT or detected ==
                                               ChatTranslator.HUD.WOLFHUD

    return detected
end

function ChatTranslator.GetHUD()
    return ChatTranslator.hud or ChatTranslator.ResolveHUD()
end

function ChatTranslator.LoadLanguages()
    ChatTranslator.languages = {
        codes = {},
        name_ids = {},
        names = {}
    }

    local file = io.open(ChatTranslator._languages_file, "r")
    if file then
        local data = file:read("*a")
        if data then
            local decoded_data = json.decode(data)

            if decoded_data then
                local list = {}
                for key, value in pairs(decoded_data) do
                    table.insert(list, {
                        code = key,
                        name = value.name
                    })
                end

                table.sort(list, function(entry1, entry2)
                    return entry1.name < entry2.name
                end)

                for i, value in ipairs(list) do
                    table.insert(ChatTranslator.languages.codes, value.code)
                    table.insert(ChatTranslator.languages.name_ids, "chat_translator_" .. value.name)
                    table.insert(ChatTranslator.languages.names, value.name)
                end
            end
        end
        file:close()
    end
end

function ChatTranslator.EncodeUrl(message)
    if message == nil then
        return nil
    end

    local char_to_hex = function(c)
        return string.format("%%%02X", string.byte(c))
    end

    message = message:gsub("\n", "\r\n")
    message = message:gsub("([^%w _%%%-%.~])", char_to_hex)
    message = message:gsub(" ", "+")
    return message
end

function ChatTranslator.RequestTranslation(language, message, callback)
    local url_encoded_message = ChatTranslator.EncodeUrl(message)
    if not url_encoded_message then
        return
    end

    local url =
        "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" .. language .. "&dt=t&q=" ..
            url_encoded_message

    dohttpreq(url, function(data)
        if not data then
            return
        end

        local decoded_data = json.decode(data)
        if not decoded_data or not decoded_data[1] or not decoded_data[1][1] or not decoded_data[1][1][1] or
            not decoded_data[2] then
            return
        end

        local source_language = tostring(decoded_data[2])
        if not source_language then
            return
        end

        local translated_message = ""
        for i = 1, #decoded_data[1] do
            local part = tostring(decoded_data[1][i][1])
            if not part then
                return
            end
            translated_message = translated_message .. part
        end
        if translated_message == "" then
            return
        end

        if source_language ~= language then
            callback(source_language, translated_message)
        end
    end)
end

function ChatTranslator.ProcessInput(object, channel_id, sender, message)
    if not ChatTranslator.settings or not ChatTranslator.settings.enabled then
        return false
    end
    if not message or type(message) ~= "string" then
        return false
    end
    if message:find(ChatTranslator.settings.keyword) ~= 1 then
        return false
    end

    message = message:gsub(ChatTranslator.settings.keyword, "", 1)
    if message:len() == 0 then
        return true
    end

    if message:find(" ") ~= 1 then
        return false
    end

    message = message:gsub(" ", "", 1)
    if message:len() == 0 then
        return true
    end

    if message:len() >= 4 then
        local target_language = message:sub(1, 2)
        if message:find(" ") ~= 3 then
            return true
        end

        message = message:sub(4)

        ChatTranslator.RequestTranslation(target_language, message, function(language, message)
            return ChatTranslator._ChatManager_send_message(object, channel_id, sender, message)
        end)
    end
    return true
end

function ChatTranslator.UpdateButtons()
    -- Disabled since we use NiceTrainer UI.
end

function ChatTranslator:Warn()
    local dialog_data = {
        title = managers.localization:text("dialog_warning_title"),
        text = managers.localization:text("chat_translator_warning_hud_missing")
    }

    local ok_button = {
        text = managers.localization:text("dialog_ok")
    }

    dialog_data.button_list = {ok_button}

    managers.system_menu:show(dialog_data)
end

function ChatTranslator:CheckHUDCompatibility()
    if self.settings.hud ~= ChatTranslator.HUD.AUTO and self.settings.hud ~= ChatTranslator.ResolveHUD() then
        ChatTranslator:Warn()
    end
end

function ChatTranslator:mouse_moved(x, y)
    if not ChatTranslator.settings or not ChatTranslator.settings.enabled then
        return false
    end
    local output_panel = alive(self._panel) and self._panel:child("output_panel")
    if not output_panel or not output_panel:inside(x, y) then
        managers.mouse_pointer:set_pointer_image("arrow")
        return false
    end

    if self._chat_type ~= ChatTranslator.CHAT_TYPE.CHATGUI and ChatTranslator.GetHUD() ==
        ChatTranslator.HUD.VOIDUI then
        local inside = false
        for i = #self._lines, 1, -1 do
            local panel = self._lines[i].panel
            if inside == false then
                inside = panel:inside(x, y)
            end
            panel:set_alpha(panel:inside(x, y) and 1 or 0.5)
        end
    end

    local translatable_messages = self._translatable_messages or {}
    for i = #translatable_messages, 1, -1 do
        local message = translatable_messages[i]

        if message:inside(x, y) then
            managers.mouse_pointer:set_pointer_image("link")
            return true
        end
    end

    managers.mouse_pointer:set_pointer_image("arrow")
    return false
end

function ChatTranslator:mouse_pressed(button, x, y)
    if not ChatTranslator.settings or not ChatTranslator.settings.enabled then
        return false
    end
    local output_panel = alive(self._panel) and self._panel:child("output_panel")
    if not output_panel or not output_panel:inside(x, y) then
        return false
    end

    -- The vanilla ingame chat has no mouse handling of its own, so scrolling is added here
    if ChatTranslator.settings.extend_chat and ChatTranslator.can_extend_chat and self._chat_type ==
        ChatTranslator.CHAT_TYPE.HUDCHAT then
        if button == Idstring("mouse wheel down") then
            local ret = self:scroll_down()
            self:set_scroll_indicators()
            return ret
        elseif button == Idstring("mouse wheel up") then
            local ret = self:scroll_up()
            self:set_scroll_indicators()
            return ret
        end
    end

    if button ~= Idstring("0") then
        return false
    end

    local translatable_messages = self._translatable_messages or {}
    for i = #translatable_messages, 1, -1 do
        local message = translatable_messages[i]

        if message:inside(x, y) then
            message:ToggleTranslation()
            self:_on_focus()
            return true
        end
    end

    return false
end

ChatTranslatorMessage = ChatTranslatorMessage or class()

function ChatTranslatorMessage:init(chat, line, name, message, color, icon)
    self._chat = chat
    self._line = line
    self._name = name
    self._message = message
    self._color = color
    self._icon = icon
    self._show_translation = false

    if self._chat._chat_type == ChatTranslator.CHAT_TYPE.HUDCHAT and ChatTranslator.GetHUD() ==
        ChatTranslator.HUD.VOIDUI then
        self._time_stamp = VoidUI.options.chattime == 2 and "[" ..
                               os.date("!%X", managers.game_play_central:get_heist_timer()) .. "] " or "[" ..
                               os.date("%X") .. "] "
    end
end

function ChatTranslatorMessage:inside(x, y)
    if not self._line then
        return false
    end

    if self._chat._chat_type == ChatTranslator.CHAT_TYPE.CHATGUI then
        return alive(self._line[2]) and self._line[2]:inside(x, y)
    elseif ChatTranslator.GetHUD() == ChatTranslator.HUD.DEFAULT then
        return alive(self._line[1]) and self._line[1]:inside(x, y)
    end

    return alive(self._line.panel) and self._line.panel:inside(x, y)
end

function ChatTranslatorMessage:RequestTranslation()
    if self._translation_requested then
        return
    end

    self._translation_requested = true

    ChatTranslator.RequestTranslation(ChatTranslator.settings.language, self._message, function(language, message)
        return self:ApplyTranslation(language, message)
    end)
end

function ChatTranslatorMessage:ApplyTranslation(language, message)
    self._translated = true

    self._language = language
    self._translated_message = message

    self:ToggleTranslation()
end

function ChatTranslatorMessage:ToggleTranslation()
    if not self._translated then
        self:RequestTranslation()
        return
    end

    self._show_translation = not self._show_translation

    local hud = ChatTranslator.GetHUD()

    local display_name = nil
    local display_message = nil
    if self._show_translation then
        display_name = self._name .. " (" .. self._language .. ")"
        display_message = self._translated_message
    else
        display_name = self._name
        display_message = self._message
    end

    if self._chat._chat_type == ChatTranslator.CHAT_TYPE.CHATGUI then
        local line = self._line[1]
        local line_bg = self._line[2]

        local len = utf8.len(display_name) + 1
        line:set_text(display_name .. ": " .. display_message)

        local total_len = utf8.len(line:text())

        line:set_range_color(0, len, self._color)
        line:set_range_color(len, total_len, Color.white)

        line:set_w(self._chat._panel:child("output_panel"):w() - line:left())

        local _, _, w, h = line:text_rect()

        line:set_h(h)
        line_bg:set_w(w + line:left() + 2)
        line_bg:set_h(self._chat.line_height * line:number_of_lines())
    elseif hud == ChatTranslator.HUD.DEFAULT then
        local line = self._line[1]

        local len = utf8.len(display_name) + 1
        line:set_text(display_name .. ": " .. display_message)

        local total_len = utf8.len(line:text())

        line:set_range_color(0, len, self._color)
        line:set_range_color(len, total_len, Color.white)
        line:set_kern(line:kern())
    elseif hud == ChatTranslator.HUD.WOLFHUD or hud == ChatTranslator.HUD.VANILLAHUD then
        local msg_panel = self._line.panel
        local message_text = msg_panel:child("msg")
        local msg_panel_bg = msg_panel:child("bg")

        message_text:set_text(display_name .. ": " .. display_message)
        local no_lines = message_text:number_of_lines()

        message_text:set_range_color(0, utf8.len(display_name) + 1, self._color)
        message_text:set_h(self._chat.LINE_HEIGHT * no_lines)
        message_text:set_kern(message_text:kern())
        msg_panel:set_h(self._chat.LINE_HEIGHT * no_lines)
        msg_panel_bg:set_h(self._chat.LINE_HEIGHT * no_lines)

        -- A translation can wrap over a different amount of lines than the original message
        if self._chat._total_message_lines and self._line.lines then
            self._chat._total_message_lines = self._chat._total_message_lines + no_lines - self._line.lines
            self._line.lines = no_lines
        end

        if not self._chat.COLORED_BG then
            local x_offset = HUDChat.COLORED_BG and 2 or 0
            local time_text = msg_panel:child("time")
            local _, _, w, _ = time_text:text_rect()
            x_offset = x_offset + w + 2
            local icon_bitmap = msg_panel:child("icon")
            if icon_bitmap then
                x_offset = x_offset + icon_bitmap:w() + 1
            end

            local _, _, msg_w, _ = message_text:text_rect()

            msg_panel_bg:set_width(x_offset + msg_w + 2)
        end
    elseif hud == ChatTranslator.HUD.VOIDUI then
        local name = self._line.name
        local peer =
            (managers.network and managers.network:session() and managers.network:session():local_peer():name() ==
                self._name and managers.network:session():local_peer()) or
                (managers.network and managers.network:session() and managers.network:session():peer_by_name(self._name))
        local character = self._line.character
        local full_message = display_name ..
                                 (VoidUI.options.show_charactername and peer and peer:character() and character or "") ..
                                 ": " .. display_message
        if self._name == managers.localization:to_upper_text("menu_system_message") then
            name = display_message
            full_message = display_message
        else
            name = display_name
        end

        if VoidUI.options.chattime > 1 and self._time_stamp then
            full_message = self._time_stamp .. full_message
            name = self._time_stamp .. name
        end
        local len = utf8.len(name) + (VoidUI.options.show_charactername and utf8.len(character) or 0) + 1

        local output_panel = self._chat._panel:child("output_panel")
        local panel = self._line.panel
        local line = panel:child("line")
        local line_shadow = panel:child("line_shadow")

        line:set_text(full_message)
        line_shadow:set_text(full_message)

        line_shadow:set_w(output_panel:w() - line:left())

        local total_len = utf8.len(line:text())
        local lines_count = line:number_of_lines()
        self._chat._lines_count = self._chat._lines_count + lines_count
        line:set_range_color(0, len, self._color)
        line:set_range_color(len, total_len, Color.white)
        panel:set_h(self._chat.line_height * self._chat._scale * lines_count)
        line:set_h(panel:h())
        line_shadow:set_h(panel:h())
    end

    if self._chat._chat_type == ChatTranslator.CHAT_TYPE.HUDCHAT and hud == ChatTranslator.HUD.VOIDUI then
        self._chat:_layout_custom_output_panel()
    else
        self._chat:_layout_output_panel()
    end
end

function ChatTranslator.SetupHooks()
    if RequiredScript == "lib/managers/chatmanager" then
        Hooks:PostHook(ChatGui, "init", "ChatTranslator_ChatGui_init", function(self)
            self._chat_type = ChatTranslator.CHAT_TYPE.CHATGUI
            self._translatable_messages = {}
        end)

        Hooks:PostHook(ChatGui, "receive_message", "ChatTranslator_ChatGui_receive_message",
            function(self, name, message, color, icon)
                local line = self._lines[#self._lines]

                local translatable_message = ChatTranslatorMessage:new(self, line, name, message, color, icon)
                table.insert(self._translatable_messages, translatable_message)
            end)

        ChatTranslator._ChatGui_mouse_moved = ChatGui.mouse_moved
        function ChatGui:mouse_moved(x, y)
            local inside, arrow = ChatTranslator._ChatGui_mouse_moved(self, x, y)
            if not inside and ChatTranslator.mouse_moved(self, x, y) then
                return true, "link"
            end

            return inside, arrow
        end

        Hooks:PreHook(ChatGui, "mouse_pressed", "ChatTranslator_ChatGui_mouse_pressed", ChatTranslator.mouse_pressed)

        ChatTranslator._ChatManager_send_message = ChatManager.send_message
        function ChatManager:send_message(channel_id, sender, message)
            if not ChatTranslator.ProcessInput(self, channel_id, sender, message) then
                ChatTranslator._ChatManager_send_message(self, channel_id, sender, message)
            end
        end
    elseif RequiredScript == "lib/managers/hud/hudchat" then
        local hud = ChatTranslator.ResolveHUD()

        if hud == ChatTranslator.HUD.VANILLAHUD and HUDChat._mouse_move then
            Hooks:PostHook(HUDChat, "_mouse_move", "ChatTranslator_HUDChat__mouse_move", function(self, _, x, y)
                x = x - self._x_offset
                y = y - self._y_offset
                ChatTranslator.mouse_moved(self, x, y)
            end)
            Hooks:PreHook(HUDChat, "_mouse_press", "ChatTranslator_HUDChat__mouse_press",
                function(self, _, button, x, y)
                    x = x - self._x_offset
                    y = y - self._y_offset
                    ChatTranslator.mouse_pressed(self, button, x, y)
                end)
        end

        Hooks:PostHook(HUDChat, "init", "ChatTranslator_HUDChat_init", function(self)
            -- Every mod has had its say by the time the chat is built, so this is the final word on the HUD
            ChatTranslator.ResolveHUD()

            self._chat_type = ChatTranslator.CHAT_TYPE.HUDCHAT
            self._translatable_messages = {}
        end)

        Hooks:PostHook(HUDChat, "receive_message", "ChatTranslator_HUDChat_receive_message",
            function(self, name, message, color, icon)
                local line = nil
                if ChatTranslator.GetHUD() == ChatTranslator.HUD.DEFAULT or ChatTranslator.GetHUD() ==
                    ChatTranslator.HUD.VOIDUI then
                    line = self._lines[#self._lines]
                else
                    line = self._messages[#self._messages]
                end

                local translatable_message = ChatTranslatorMessage:new(self, line, name, message, color, icon)
                table.insert(self._translatable_messages, translatable_message)
            end)

        if HUDChat.mouse_moved then
            Hooks:PostHook(HUDChat, "mouse_moved", "ChatTranslator_HUDChat_mouse_moved",
                (hud ~= ChatTranslator.HUD.VOIDUI) and ChatTranslator.mouse_moved or function(self, _, x, y)
                    x =
                        x -
                            (managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2).panel:w() -
                                self._hud_panel:w()) / 2
                    y =
                        y -
                            (managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2).panel:h() -
                                self._hud_panel:h()) / 2
                    ChatTranslator.mouse_moved(self, x, y)
                end)
        else
            HUDChat.mouse_moved = ChatTranslator.mouse_moved
        end

        if HUDChat.mouse_pressed then
            Hooks:PreHook(HUDChat, "mouse_pressed", "ChatTranslator_HUDChat_mouse_pressed",
                (hud ~= ChatTranslator.HUD.VOIDUI) and ChatTranslator.mouse_pressed or
                    function(self, _, button, x, y)
                        x =
                            x -
                                (managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2).panel:w() -
                                    self._hud_panel:w()) / 2
                        y =
                            y -
                                (managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2).panel:h() -
                                    self._hud_panel:h()) / 2
                        ChatTranslator.mouse_pressed(self, button, x, y)
                    end)
        else
            HUDChat.mouse_pressed = ChatTranslator.mouse_pressed
        end

        Hooks:PostHook(HUDChat, "_on_focus", "ChatTranslator_HUDChat__on_focus", function(self)
            if ChatTranslator.settings.mouse_pointer and ChatTranslator.can_use_mouse_pointer and
                not self._mouse_pointer_active then
                local data = {
                    mouse_move = function(_, x, y)
                        return self:mouse_moved(managers.mouse_pointer:convert_mouse_pos(x, y))
                    end,
                    mouse_press = function(_, button, x, y)
                        return self:mouse_pressed(button, managers.mouse_pointer:convert_mouse_pos(x, y))
                    end,
                    mouse_release = function()
                    end,
                    mouse_click = function()
                    end,
                    mouse_double_click = function()
                    end,
                    id = "chat_translator_hudchat"
                }
                managers.mouse_pointer:use_mouse(data)
                self._mouse_pointer_active = true
            end
        end)

        Hooks:PostHook(HUDChat, "_loose_focus", "ChatTranslator_HUDChat__loose_focus", function(self)
            if self._mouse_pointer_active then
                managers.mouse_pointer:remove_mouse("chat_translator_hudchat")
                self._mouse_pointer_active = false
            end
        end)

        Hooks:PostHook(HUDChat, "remove", "ChatTranslator_HUDChat_remove", function(self)
            if self._mouse_pointer_active then
                managers.mouse_pointer:remove_mouse("chat_translator_hudchat")
                self._mouse_pointer_active = false
            end
        end)
    elseif RequiredScript == "lib/managers/hudmanagerpd2" then
        Hooks:PreHook(HUDManager, "setup_endscreen_hud", "ChatTranslator_HUDManager_setup_endscreen_hud", function(self)
            if self._hud_chat_ingame and self._hud_chat_ingame._mouse_pointer_active then
                managers.mouse_pointer:remove_mouse("chat_translator_hudchat")
                self._hud_chat_ingame._mouse_pointer_active = false
            end
        end)
    end
end

ChatTranslator:Setup()
