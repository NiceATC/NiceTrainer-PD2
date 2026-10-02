-- Chat Translator Action for NiceTrainer (Miscellaneous Tab)

local languages_file = (NiceTrainer and NiceTrainer.ModPath or ModPath) .. "data/languages.json"
local codes = {}
local names = {}

local function load_languages()
    local file = io.open(languages_file, "r")
    if file then
        local data = file:read("*a")
        file:close()
        if data then
            local ok, decoded = pcall(json.decode, data)
            if ok and type(decoded) == "table" then
                local list = {}
                for key, value in pairs(decoded) do
                    table.insert(list, { code = key, name = value.name or key })
                end
                table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)

                for _, value in ipairs(list) do
                    table.insert(codes, value.code)
                    table.insert(names, value.name)
                end
            end
        end
    end

    -- Fallback default languages in case languages.json is unavailable
    if #codes == 0 then
        local fallbacks = {
            { code = "en", name = "English" },
            { code = "pt", name = "Portuguese" },
            { code = "es", name = "Spanish" },
            { code = "ru", name = "Russian" },
            { code = "fr", name = "French" },
            { code = "de", name = "German" },
            { code = "zh", name = "Chinese" },
            { code = "ja", name = "Japanese" },
        }
        for _, fb in ipairs(fallbacks) do
            table.insert(codes, fb.code)
            table.insert(names, fb.name)
        end
    end
end

load_languages()

local default_settings = {
    enabled = false,
    language = "en",
    keyword = "tl",
    hud = 5,
    extend_chat = true,
    mouse_pointer = true
}

for k, v in pairs(default_settings) do
    if NiceTrainer.Settings["chat_translator_" .. k] == nil then
        NiceTrainer.Settings["chat_translator_" .. k] = v
    end
end

local selected_lang_idx = 1
for i, code in ipairs(codes) do
    if code == NiceTrainer.Settings["chat_translator_language"] then
        selected_lang_idx = i
        break
    end
end

NiceTrainer:RegisterAction("Miscellaneous", {
    type            = "toggle_multichoice",
    no_bind         = true,
    category        = "Chat Translator",
    id              = "chat_translator_enabled",
    text            = "Chat Translator",
    tooltip         = "Enable Chat Translator. Translates clicked messages and outgoing 'tl <lang> <msg>'. Select target language beside toggle.",
    default         = false,
    options         = names,
    choice_default  = selected_lang_idx,
    choice_id       = "chat_translator_language_idx",
    callback        = function(state)
        NiceTrainer.Settings.chat_translator_enabled = state
        NiceTrainer:Save()
        if _G.ChatTranslator and _G.ChatTranslator.settings then
            _G.ChatTranslator.settings.enabled = state
        end
    end,
    choice_callback = function(idx, val)
        local code = codes[idx] or "en"
        NiceTrainer.Settings.chat_translator_language = code
        NiceTrainer.Settings.chat_translator_language_idx = idx
        NiceTrainer:Save()
        if _G.ChatTranslator and _G.ChatTranslator.settings then
            _G.ChatTranslator.settings.language = code
        end
    end
})

local hud_names = { "Default", "WolfHUD", "VoidUI", "VanillaHUD Plus", "Auto" }
NiceTrainer:RegisterAction("Miscellaneous", {
    type     = "multichoice",
    category = "Chat Translator",
    no_bind  = true,
    id       = "chat_translator_hud",
    text     = "Chat HUD Style",
    options  = hud_names,
    default  = tonumber(NiceTrainer.Settings.chat_translator_hud) or 5,
    tooltip  = "Force a specific HUD for chat, or Auto.",
    callback = function(idx, val)
        NiceTrainer.Settings.chat_translator_hud = idx
        NiceTrainer:Save()
        if _G.ChatTranslator and _G.ChatTranslator.settings then
            _G.ChatTranslator.settings.hud = idx
        end
    end
})

NiceTrainer:RegisterAction("Miscellaneous", {
    type     = "toggle",
    category = "Chat Translator",
    no_bind  = true,
    id       = "chat_translator_mouse_pointer",
    text     = "Click to Translate",
    default  = NiceTrainer.Settings.chat_translator_mouse_pointer ~= false,
    tooltip  = "Enables clicking chat messages with mouse to translate them.",
    callback = function(state)
        NiceTrainer.Settings.chat_translator_mouse_pointer = state
        NiceTrainer:Save()
        if _G.ChatTranslator and _G.ChatTranslator.settings then
            _G.ChatTranslator.settings.mouse_pointer = state
        end
    end
})

NiceTrainer:RegisterAction("Miscellaneous", {
    type     = "toggle",
    category = "Chat Translator",
    no_bind  = true,
    id       = "chat_translator_extend_chat",
    text     = "Extend Chat (Scroll)",
    default  = NiceTrainer.Settings.chat_translator_extend_chat ~= false,
    tooltip  = "Allows scrolling the chat box with mouse wheel.",
    callback = function(state)
        NiceTrainer.Settings.chat_translator_extend_chat = state
        NiceTrainer:Save()
        if _G.ChatTranslator and _G.ChatTranslator.settings then
            _G.ChatTranslator.settings.extend_chat = state
        end
    end
})

-- Sync state to ChatTranslator global when loaded
if _G.ChatTranslator and _G.ChatTranslator.settings then
    _G.ChatTranslator.settings.enabled = (NiceTrainer.Settings.chat_translator_enabled == true)
    _G.ChatTranslator.settings.language = NiceTrainer.Settings.chat_translator_language or "en"
    _G.ChatTranslator.settings.hud = NiceTrainer.Settings.chat_translator_hud or 5
    _G.ChatTranslator.settings.mouse_pointer = (NiceTrainer.Settings.chat_translator_mouse_pointer ~= false)
    _G.ChatTranslator.settings.extend_chat = (NiceTrainer.Settings.chat_translator_extend_chat ~= false)
end
