-- Invisible Player & Detection Range for NiceTrainer (Stealth Tab)
-- Supports client Host and Client

local _originals = {}
local invisibleAttentionBackup = nil

local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then _originals[key] = cls[method_name] end
    cls[method_name] = replacement
    return true
end

local function restore(class_name, method_name)
    local cls = _G[class_name]
    if not cls then return end
    local key = class_name .. "." .. method_name
    if _originals[key] then
        cls[method_name] = _originals[key]
        _originals[key] = nil
    end
end

local function apply_invisibility(state)
    if state then
        -- Suppress player suspicion buildup & uncover callbacks (Client & Host)
        hijack("PlayerMovement", "on_suspicion", function(self, observer_unit, status)
            if NiceTrainer.Settings.invisible_player then
                return
            end
            if NiceTrainer.Settings.enable_detection_range then
                local mul = tonumber(NiceTrainer.Settings.detection_range_multiplier) or 0.5
                if type(status) == "number" then
                    status = status * mul
                end
            end
            return _originals["PlayerMovement.on_suspicion"](self, observer_unit, status)
        end)

        hijack("PlayerMovement", "on_uncovered", function(self, enemy_unit)
            if NiceTrainer.Settings.invisible_player then
                return
            end
            return _originals["PlayerMovement.on_uncovered"](self, enemy_unit)
        end)

        -- Suppress group AI suspicion and spotting events for local player
        hijack("GroupAIStateBase", "on_criminal_suspicion_progress", function(self, u_suspect, u_observer, status)
            if NiceTrainer.Settings.invisible_player and managers.player and u_suspect == managers.player:player_unit() then
                return
            end
            return _originals["GroupAIStateBase.on_criminal_suspicion_progress"](self, u_suspect, u_observer, status)
        end)

        hijack("GroupAIStateBase", "criminal_spotted", function(self, unit)
            if NiceTrainer.Settings.invisible_player and managers.player and unit == managers.player:player_unit() then
                return
            end
            return _originals["GroupAIStateBase.criminal_spotted"](self, unit)
        end)

        -- Suppress camera suspicion
        hijack("SecurityCamera", "_set_suspicion_level", function(self, suspicion_level)
            if NiceTrainer.Settings.invisible_player then
                return _originals["SecurityCamera._set_suspicion_level"](self, 0)
            end
            if NiceTrainer.Settings.enable_detection_range then
                local mul = tonumber(NiceTrainer.Settings.detection_range_multiplier) or 0.5
                if type(suspicion_level) == "number" then
                    suspicion_level = suspicion_level * mul
                end
            end
            return _originals["SecurityCamera._set_suspicion_level"](self, suspicion_level)
        end)

        hijack("SecurityCamera", "_upd_suspicion", function(self, t)
            if NiceTrainer.Settings.invisible_player then
                return
            end
            return _originals["SecurityCamera._upd_suspicion"](self, t)
        end)

        -- Clear attention settings on local player movement
        if managers.player then
            local player = managers.player:player_unit()
            if alive(player) then
                local mov = player:movement()
                if mov and mov.set_attention_settings then
                    mov:set_attention_settings(nil)
                end
            end
        end
    else
        restore("PlayerMovement", "on_suspicion")
        restore("PlayerMovement", "on_uncovered")
        restore("GroupAIStateBase", "on_criminal_suspicion_progress")
        restore("GroupAIStateBase", "criminal_spotted")
        restore("SecurityCamera", "_set_suspicion_level")
        restore("SecurityCamera", "_upd_suspicion")

        if managers.player and managers.groupai then
            local player = managers.player:player_unit()
            if alive(player) then
                local playerKey = player:key()
                local AiState = managers.groupai:state()
                if invisibleAttentionBackup and AiState and AiState._attention_objects and AiState._attention_objects.all then
                    AiState._attention_objects.all[playerKey] = invisibleAttentionBackup
                    if AiState.on_AI_attention_changed then
                        AiState:on_AI_attention_changed(playerKey)
                    end
                    invisibleAttentionBackup = nil
                end

                local mov = player:movement()
                if mov and mov.current_state and mov:current_state() and mov:current_state()._upd_attention then
                    mov:current_state():_upd_attention()
                end
            end
        end
    end
end

-- Update Loop for Invisibility (Host AI state unregistration & state upkeep)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Stealth_Invisible", function(t, dt)
    if not NiceTrainer:IsInHeist() then return end
    if NiceTrainer.Settings.invisible_player and managers.player then
        local player = managers.player:player_unit()
        if alive(player) then
            -- Host GroupAI attention object unregistration
            if managers.groupai then
                local playerKey = player:key()
                local AiState = managers.groupai:state()
                if AiState and AiState._attention_objects and AiState._attention_objects.all and AiState._attention_objects.all[playerKey] then
                    invisibleAttentionBackup = AiState._attention_objects.all[playerKey]
                    AiState:unregister_AI_attention_object(playerKey)
                end
            end

            -- Ensure local player attention stays cleared
            local mov = player:movement()
            if mov and mov.set_attention_settings then
                mov:set_attention_settings(nil)
            end
        end
    end
end)

NiceTrainer:RegisterAction("Stealth", {
    type = "toggle",
    category = "Player",
    badge = "client",
    id = "invisible_player",
    text = "Invisible Player",
    tooltip = "Enemies and cameras will not be able to see you.",
    default = false,
    callback = function(state)
        apply_invisibility(state)
    end
})

local function applyDetection(state, val)
    val = tonumber(val) or 0.5
    if state then
        hijack("PlayerBase", "set_detection_multiplier", function(self, reason, mul)
            _originals["PlayerBase.set_detection_multiplier"](self, reason, mul)
            if self._detection_settings then
                self._detection_settings.multipliers["nice_trainer_range"] = val
                local range_mul = 1
                local delay_mul = 1
                for _, m in pairs(self._detection_settings.multipliers) do
                    range_mul = range_mul * m
                    delay_mul = delay_mul / m
                end
                self._detection_settings.range_mul = range_mul
                self._detection_settings.delay_mul = delay_mul
            end
        end)

        hijack("PlayerBase", "set_suspicion_multiplier", function(self, reason, mul)
            _originals["PlayerBase.set_suspicion_multiplier"](self, reason, mul)
            if self._suspicion_settings then
                self._suspicion_settings.multipliers["nice_trainer_range"] = val
                local range_mul = 1
                local delay_mul = 1
                for _, m in pairs(self._suspicion_settings.multipliers) do
                    range_mul = range_mul * m
                    delay_mul = delay_mul / m
                end
                self._suspicion_settings.range_mul = range_mul
                self._suspicion_settings.delay_mul = delay_mul
            end
        end)
    else
        restore("PlayerBase", "set_detection_multiplier")
        restore("PlayerBase", "set_suspicion_multiplier")
    end

    if managers.player then
        local player_unit = managers.player:player_unit()
        if alive(player_unit) then
            local base = player_unit:base()
            if base then
                if base.set_detection_multiplier then
                    base:set_detection_multiplier("nice_trainer_range", state and val or nil)
                end
                if base.set_suspicion_multiplier then
                    base:set_suspicion_multiplier("nice_trainer_range", state and val or nil)
                end
            end
        end
    end
end

NiceTrainer:RegisterAction("Stealth", {
    type = "toggle_settings",
    category = "Player",
    badge = "client",
    id = "enable_detection_range",
    text = "Detection Range Multiplier",
    tooltip = "1 = Normal, 0.01 = Enemies practically need to touch you to detect you.",
    default = false,
    callback = function(state)
        applyDetection(state, tonumber(NiceTrainer.Settings.detection_range_multiplier) or 0.5)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Detection Range Multiplier", 0.01, 1, tonumber(NiceTrainer.Settings.detection_range_multiplier) or 0.5, function(val)
            NiceTrainer.Settings.detection_range_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_detection_range then
                applyDetection(true, val)
            end
        end)
    end
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Stealth_ApplyDetectionAndInvis", function()
    if NiceTrainer.Settings.invisible_player then
        apply_invisibility(true)
    end
    if NiceTrainer.Settings.enable_detection_range then 
        applyDetection(true, tonumber(NiceTrainer.Settings.detection_range_multiplier) or 0.5) 
    end
end)
