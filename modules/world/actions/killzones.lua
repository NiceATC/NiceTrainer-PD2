-- Killzones & Out-of-Bounds Protection for NiceTrainer (World Tab)
-- Prevents instant death, fall abysses, and environmental killzones (e.g. Yacht Heist, Birth of Sky, Goat Simulator).

NiceTrainer.KillzonesDisabled = false

-- Safe dynamic hook installer
local function _install_killzone_hooks()
    if _G.KillzoneManager and not KillzoneManager._nicetrainer_killzone_hooked then
        KillzoneManager._nicetrainer_killzone_hooked = true

        local orig_kill_unit = KillzoneManager._kill_unit
        function KillzoneManager:_kill_unit(unit, ...)
            if NiceTrainer.KillzonesDisabled then
                local player = managers.player and managers.player:player_unit()
                if unit == player then
                    return
                end
            end
            return orig_kill_unit(self, unit, ...)
        end

        local orig_deal_damage = KillzoneManager._deal_damage
        function KillzoneManager:_deal_damage(unit, ...)
            if NiceTrainer.KillzonesDisabled then
                local player = managers.player and managers.player:player_unit()
                if unit == player then
                    return
                end
            end
            return orig_deal_damage(self, unit, ...)
        end

        local orig_deal_gas = KillzoneManager._deal_gas_damage
        function KillzoneManager:_deal_gas_damage(unit, ...)
            if NiceTrainer.KillzonesDisabled then
                local player = managers.player and managers.player:player_unit()
                if unit == player then
                    return
                end
            end
            return orig_deal_gas(self, unit, ...)
        end

        local orig_deal_fire = KillzoneManager._deal_fire_damage
        function KillzoneManager:_deal_fire_damage(unit, ...)
            if NiceTrainer.KillzonesDisabled then
                local player = managers.player and managers.player:player_unit()
                if unit == player then
                    return
                end
            end
            return orig_deal_fire(self, unit, ...)
        end

        local orig_electrocute = KillzoneManager._electrocute_unit
        function KillzoneManager:_electrocute_unit(unit, ...)
            if NiceTrainer.KillzonesDisabled then
                local player = managers.player and managers.player:player_unit()
                if unit == player then
                    return
                end
            end
            return orig_electrocute(self, unit, ...)
        end
    end

    if _G.PlayerDamage and not PlayerDamage._nicetrainer_killzone_hooked then
        PlayerDamage._nicetrainer_killzone_hooked = true
        local orig_damage_killzone = PlayerDamage.damage_killzone
        function PlayerDamage:damage_killzone(attack_data, ...)
            if NiceTrainer.KillzonesDisabled and attack_data then
                attack_data.damage = 0
                attack_data.instant_death = false
                return false
            end
            return orig_damage_killzone(self, attack_data, ...)
        end
    end
end

_install_killzone_hooks()
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Killzone_SessionHooks", _install_killzone_hooks)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Killzone_GameHooks", function()
    if not KillzoneManager or not KillzoneManager._nicetrainer_killzone_hooked then
        _install_killzone_hooks()
    end
end)

-- Register Action in World Tab
NiceTrainer:RegisterAction("World", {
    type = "toggle",
    badge = "Client",
    category = "Movable Objects & Motion Paths",
    id = "disable_killzones",
    text = "Disable Killzones (Out-of-Bounds)",
    tooltip = "Removes invisible boundary abysses and instant-death fall triggers across all heists",
    default = false,
    save = true,
    callback = function(state)
        NiceTrainer.KillzonesDisabled = state
    end
})
