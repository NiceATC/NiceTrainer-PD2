-- Civilian Control Actions for NPC AI Tab

local function each_civilian(fn)
    pcall(function()
        if managers.enemy then
            for _, data in pairs(managers.enemy:all_civilians()) do
                if alive(data.unit) then pcall(fn, data.unit) end
            end
        end
    end)
end

if not NiceTrainer._npc_ai_civ_freeze_hooked then
    Hooks:Add("GameSetupUpdate", "NiceTrainer_AI_CivFreezeLoop", function()
        if not NiceTrainer:IsInHeist() then return end
        if NiceTrainer.Settings.freeze_civilians then
            local player = managers.player and managers.player:player_unit()
            each_civilian(function(u)
                if Network:is_server() then
                    if u:brain():is_active() then u:brain():set_active(false) end
                else
                    -- Client: Intimidate / tie civilian so they drop down and don't call police
                    local brain = u:brain()
                    if brain and not brain:is_tied() then
                        pcall(function()
                            if brain.on_intimidated then brain:on_intimidated(1, player, true) end
                            if brain.on_tied then brain:on_tied(player) end
                            if u:interaction() and u:interaction():active() and player then
                                u:interaction():interact(player)
                            end
                        end)
                    end
                end
            end)
        end
    end)
    NiceTrainer._npc_ai_civ_freeze_hooked = true
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    badge    = "client",
    category = "Civilians",
    id       = "freeze_civilians",
    text     = "Freeze / Restrain Civilians",
    tooltip  = "Freezes or instantly restrains civilians so they cannot call police or move (works as host and client).",
    default  = false,
    save     = false,
    callback = function(state)
        if not state and Network:is_server() then
            each_civilian(function(u)
                local brain = u:brain()
                if brain and not brain:is_active() then
                    pcall(function()
                        brain:set_active(true)
                        brain:set_update_enabled_state(true)
                    end)
                end
            end)
        end
    end,
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NPCAI_Civilians_Load", function()
    NiceTrainer.Settings.freeze_civilians = false
    if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.freeze_civilians then
        NiceTrainer._toggle_elements.freeze_civilians(false)
    end
end)
