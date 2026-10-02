-- Joker / Conversion Actions for NPC AI Tab

local _originals = {}

local function each_enemy(fn)
    pcall(function()
        if managers.enemy then
            for _, data in pairs(managers.enemy:all_enemies()) do
                if alive(data.unit) then pcall(fn, data.unit) end
            end
        end
    end)
end

NiceTrainer._instant_convert_installed = NiceTrainer._instant_convert_installed or false

local function applyInstantConvert(enabled)
    NiceTrainer.Settings.instant_convert = enabled
    if enabled and not NiceTrainer._instant_convert_installed then
        if not _G.PlayerManager then return end
        local orig = PlayerManager.upgrade_value
        if not _originals["PlayerManager.upgrade_value"] then
            _originals["PlayerManager.upgrade_value"] = orig
        end
        PlayerManager.upgrade_value = function(self, category, upgrade, default)
            if NiceTrainer.Settings.instant_convert and category == "player" then
                if upgrade == "convert_enemies"            then return true end
                if upgrade == "convert_enemies_max_minions" then return 9999 end
            end
            return _originals["PlayerManager.upgrade_value"](self, category, upgrade, default)
        end
        NiceTrainer._instant_convert_installed = true
    end
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "Conversion",
    badge    = "client",
    id       = "instant_convert",
    text     = "Instant Convert (Joker)",
    tooltip  = "Convert any enemy to Joker without the skill, with no minion cap.",
    default  = false,
    callback = applyInstantConvert,
})

NiceTrainer:RegisterAction("NPC AI", {
    type     = "button",
    category = "Conversion",
    badge    = "client",
    text     = "Convert All Enemies",
    tooltip  = "Converts every living enemy into a Joker ally at once (works as host and client).",
    callback = function()
        if not NiceTrainer:IsInHeist() then NiceTrainer:Toast("Only in heist!"); return end
        applyInstantConvert(true)
        local count = 0
        local player = managers.player and managers.player:player_unit()
        local ai = managers.groupai and managers.groupai:state()

        if Network:is_server() and ai then
            -- Host authoritative convert
            each_enemy(function(u)
                pcall(function()
                    ai:convert_hostage_to_criminal(u)
                    ai:sync_converted_enemy(u)
                    count = count + 1
                end)
            end)
        else
            -- Client: Intimidate into surrender and trigger convert interaction
            each_enemy(function(u)
                pcall(function()
                    local brain = u:brain()
                    if brain and brain.on_intimidated then
                        brain:on_intimidated(1, player, true)
                    end
                    local inter = u:interaction()
                    if inter then
                        inter:set_tweak_data("hostage_convert")
                        inter:set_active(true)
                        if player then inter:interact(player) end
                        count = count + 1
                    end
                end)
            end)
        end
        NiceTrainer:Toast("Converted " .. count .. " enemies")
    end,
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NPCAI_Conversion_Load", function()
    if NiceTrainer.Settings.instant_convert then
        applyInstantConvert(true)
    end
end)
