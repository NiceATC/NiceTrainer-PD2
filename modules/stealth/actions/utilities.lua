-- Stealth utilities for NiceTrainer (Stealth Tab)

local _originals = {}
local _pagerChanceBackup = nil

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

-- Hook Appliers
local function apply_infinite_body_bags(state)
    if state then
        hijack("PlayerManager", "on_used_body_bag", function(self)
            local max_b = 3
            if managers.hud and self._set_body_bags_amount then
                pcall(self._set_body_bags_amount, self, max_b)
            else
                self._local_player_body_bags = max_b
            end
        end)
        hijack("PlayerManager", "chk_body_bags_depleted", function() return false end)
        hijack("PlayerManager", "has_total_body_bags", function() return true end)
        hijack("PlayerManager", "total_body_bags", function(self)
            local amount = self._local_player_body_bags
            if type(amount) == "number" and amount > 0 then
                return amount
            end
            return 3
        end)
        if managers.player then
            local max_b = 3
            if managers.hud and managers.player._set_body_bags_amount then
                pcall(managers.player._set_body_bags_amount, managers.player, max_b)
            else
                managers.player._local_player_body_bags = max_b
            end
        end
    else
        restore("PlayerManager", "on_used_body_bag")
        restore("PlayerManager", "chk_body_bags_depleted")
        restore("PlayerManager", "has_total_body_bags")
        restore("PlayerManager", "total_body_bags")
    end
end

local function apply_infinite_cable_ties(state)
    if state then
        hijack("PlayerManager", "remove_cable_tie", function() end)
    else
        restore("PlayerManager", "remove_cable_tie")
    end
end

local function apply_no_cash_penalty(state)
    if state then
        hijack("MoneyManager", "civilian_killed", function() end)
    else
        restore("MoneyManager", "civilian_killed")
    end
end

local function apply_steal_pagers(state)
    if state then
        hijack("CopDamage", "damage_melee", function(self, attack_data)
            local unit_data = self._unit:unit_data()
            local had_pager = unit_data and unit_data.has_alarm_pager
            
            if had_pager then
                unit_data.has_alarm_pager = false
            end
            
            local res = _originals["CopDamage.damage_melee"](self, attack_data)
            
            if had_pager and self:dead() and alive(self._unit) and self._unit:interaction() then
                self._unit:interaction():set_tweak_data("corpse_dispose")
                self._unit:interaction():set_active(true, false)
            elseif had_pager and not self:dead() then
                unit_data.has_alarm_pager = true
            end
            
            return res
        end)
    else
        restore("CopDamage", "damage_melee")
    end
end

local function apply_unlimited_pagers(state)
    if state then
        if tweak_data and tweak_data.player and tweak_data.player.alarm_pager then
            if not _pagerChanceBackup then
                _pagerChanceBackup = {
                    normal = deep_clone(tweak_data.player.alarm_pager.bluff_success_chance),
                    skilled = deep_clone(tweak_data.player.alarm_pager.bluff_success_chance_w_skill)
                }
            end
            local inf_table = setmetatable({}, { __index = function() return 1 end })
            for i = 1, 100 do inf_table[i] = 1 end
            tweak_data.player.alarm_pager.bluff_success_chance = inf_table
            tweak_data.player.alarm_pager.bluff_success_chance_w_skill = inf_table
            if tweak_data.player.alarm_pager.max_nr_pagers then
                tweak_data.player.alarm_pager.max_nr_pagers = 999
            end
        end

        hijack("CopBrain", "on_alarm_pager_interaction", function(self, status, player)
            if status == "complete" then
                self:end_alarm_pager()
                if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
                    managers.groupai:state():on_successful_alarm_pager_bluff()
                    local u = self._unit
                    if alive(u) and u:sound() then
                        local is_dead = u:character_damage() and u:character_damage():dead()
                        local radio_id = (self._get_radio_id and self:_get_radio_id("dsp_radio_fooled_4")) or "dsp_radio_fooled_4"
                        if is_dead and u:sound().corpse_play then
                            pcall(u:sound().corpse_play, u:sound(), radio_id, nil, true)
                        else
                            pcall(u:sound().play, u:sound(), radio_id, nil, true)
                        end
                    end
                    if alive(u) and u:interaction() then
                        if u:character_damage() and u:character_damage():dead() then
                            u:interaction():set_tweak_data("corpse_dispose")
                            u:interaction():set_active(true, false)
                        else
                            u:interaction():set_active(false, true)
                        end
                    end
                    return
                end
            end
            return _originals["CopBrain.on_alarm_pager_interaction"](self, status, player)
        end)

        hijack("GroupAIStateBase", "on_successful_alarm_pager_bluff", function(self)
            self._nr_successful_alarm_pager_bluffs = (self._nr_successful_alarm_pager_bluffs or 0) + 1
        end)

        hijack("GroupAIStateBase", "sync_alarm_pager_bluff", function(self)
            self._nr_successful_alarm_pager_bluffs = (self._nr_successful_alarm_pager_bluffs or 0) + 1
        end)

        hijack("GroupAIStateBase", "on_police_called", function(self, called_reason)
            if NiceTrainer.Settings.unlimited_pagers then
                if called_reason == "alarm_pager_bluff_failed" 
                    or called_reason == "alarm_pager_hang_up" 
                    or called_reason == "alarm_pager_not_answered" 
                    or called_reason == "alarm_pager_interrupted"
                then
                    return
                end
            end
            return _originals["GroupAIStateBase.on_police_called"](self, called_reason)
        end)
    else
        restore("CopBrain", "on_alarm_pager_interaction")
        restore("GroupAIStateBase", "on_successful_alarm_pager_bluff")
        restore("GroupAIStateBase", "sync_alarm_pager_bluff")
        restore("GroupAIStateBase", "on_police_called")
        if tweak_data and tweak_data.player and tweak_data.player.alarm_pager and _pagerChanceBackup then
            tweak_data.player.alarm_pager.bluff_success_chance = deep_clone(_pagerChanceBackup.normal)
            tweak_data.player.alarm_pager.bluff_success_chance_w_skill = deep_clone(_pagerChanceBackup.skilled)
        end
    end
end

local function apply_auto_answer_pagers(state)
    if state then
        hijack("CopBrain", "begin_alarm_pager", function(self, reset)
            _originals["CopBrain.begin_alarm_pager"](self, reset)
            if self._alarm_pager_data and alive(self._unit) then
                self:end_alarm_pager()
                if alive(self._unit) and self._unit:interaction() then
                    if self._unit:character_damage() and self._unit:character_damage():dead() then
                        self._unit:interaction():set_tweak_data("corpse_dispose")
                        self._unit:interaction():set_active(true, false)
                    else
                        self._unit:interaction():set_active(false, true)
                    end
                end
                if managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode() then
                    local nr = managers.groupai:state():get_nr_successful_alarm_pager_bluffs() or 0
                    if NiceTrainer.Settings.unlimited_pagers or nr < 4 then
                        managers.groupai:state():on_successful_alarm_pager_bluff()
                        local is_dead = self._unit:character_damage() and self._unit:character_damage():dead()
                        local radio_id = (self._get_radio_id and self:_get_radio_id("dsp_radio_fooled_1")) or "dsp_radio_fooled_1"
                        if is_dead and self._unit:sound() and self._unit:sound().corpse_play then
                            pcall(self._unit:sound().corpse_play, self._unit:sound(), radio_id, nil, true)
                        elseif self._unit:sound() then
                            pcall(self._unit:sound().play, self._unit:sound(), radio_id, nil, true)
                        end
                    else
                        managers.groupai:state():on_police_called("alarm_pager_bluff_failed")
                    end
                end
            end
        end)
    else
        restore("CopBrain", "begin_alarm_pager")
    end
end

local function apply_camera_kill_on_detection(state)
    if state then
        hijack("SecurityCamera", "_set_suspicion_level", function(self, suspicion_level)
            if suspicion_level > 0.05 then
                if alive(self._unit) and not self._destroyed then
                    pcall(function()
                        self:set_detection_enabled(false)
                        self:set_update_enabled(false)
                        self:destroy()
                    end)
                end
                return
            end
            return _originals["SecurityCamera._set_suspicion_level"](self, suspicion_level)
        end)
    else
        restore("SecurityCamera", "_set_suspicion_level")
    end
end

-- Update Loop for Utilities
Hooks:Add("GameSetupUpdate", "NiceTrainer_Stealth_Utilities", function(t, dt)
    if not NiceTrainer:IsInHeist() then return end
    
    -- Execute Alerted Guards
    if NiceTrainer.Settings.execute_alerted_guards and managers.enemy then
        local player = managers.player and managers.player:player_unit()
        local weapon = player and alive(player:inventory():equipped_unit()) and player:inventory():equipped_unit() or player
        for u_key, u_data in pairs(managers.enemy:all_enemies()) do
            local u = u_data.unit
            if alive(u) and not u:character_damage():dead() then
                local brain = u:brain()
                if brain and (brain._current_logic_name == "attack" or brain._current_logic_name == "arrest") then
                    pcall(function()
                        local head_body = u:body("head") or u:body("hit_Head") or u:body("body") or (u:num_bodies() > 0 and u:body(0))
                        local col_ray = { unit = u, body = head_body, position = u:position(), ray = math.UP, normal = math.UP }
                        local attack_data = { variant = "bullet", damage = 1000000, attacker_unit = player, weapon_unit = weapon, col_ray = col_ray, origin = u:position(), pos = u:position() }
                        local dmg = u:character_damage()
                        if dmg.damage_bullet then
                            dmg:damage_bullet(attack_data)
                        elseif dmg.damage_mission then
                            dmg:damage_mission({ damage = 1000000, attacker_unit = player, col_ray = col_ray })
                        end
                    end)
                end
            end
        end
    end
    
    -- Tie Alerted Civilians
    if NiceTrainer.Settings.tie_alerted_civilians and managers.enemy then
        local player = managers.player and managers.player:player_unit()
        for u_key, u_data in pairs(managers.enemy:all_civilians()) do
            local u = u_data.unit
            if alive(u) and not u:character_damage():dead() then
                local brain = u:brain()
                if brain and not brain:is_tied() then
                    if brain._current_logic_name == "flee" or brain._current_logic_name == "surrender" or brain._current_logic_name == "idle" then
                        pcall(function()
                            if brain.on_intimidated then brain:on_intimidated(1, player, true) end
                            if brain.on_tied then brain:on_tied(player) end
                            if u:interaction() and u:interaction():active() then
                                u:interaction():interact(player)
                            end
                        end)
                    end
                end
            end
        end
    end
end)

-- Registrations
NiceTrainer:RegisterAction("Stealth", {
    type = "toggle", category = "Mission", badge = "client", id = "unlimited_pagers", text = "Unlimited Pagers", tooltip = "Allows you to answer an unlimited amount of pagers successfully.", default = false,
    callback = apply_unlimited_pagers
})

NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "Mission", badge = "client", id = "auto_answer_pagers", text = "Auto Answer Pagers", tooltip = "Pagers will be automatically answered instantly.", default = false, callback = apply_auto_answer_pagers })
NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "Mission", badge = "client", id = "steal_pagers", text = "Steal Pagers On Melee", tooltip = "Melee killing a guard destroys their pager.", default = false, callback = apply_steal_pagers })
NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "Mission", badge = "client", id = "no_cash_penalty", text = "No Civilian Kill Penalty", tooltip = "You don't lose cash for killing civilians.", default = false, callback = apply_no_cash_penalty })

NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "Items", badge = "client", id = "infinite_body_bags", text = "Infinite Body Bags", tooltip = "You never run out of body bags.", default = false, callback = apply_infinite_body_bags })
NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "Items", badge = "client", id = "infinite_cable_ties", text = "Infinite Cable Ties", tooltip = "You never run out of cable ties.", default = false, callback = apply_infinite_cable_ties })

NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "AI & Cameras", badge = "client", id = "execute_alerted_guards", text = "Execute Alerted Guards", tooltip = "Automatically kills any guard that becomes fully alerted (works as host and client).", default = false })
NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "AI & Cameras", badge = "client", id = "tie_alerted_civilians", text = "Tie Alerted Civilians", tooltip = "Automatically intimidates and ties down any civilian that gets alerted.", default = false })
NiceTrainer:RegisterAction("Stealth", { type = "toggle", category = "AI & Cameras", badge = "client", id = "camera_kill_on_detection", text = "Cameras Die On Detection", tooltip = "Cameras automatically explode if they start detecting you.", default = false, callback = apply_camera_kill_on_detection })

NiceTrainer:RegisterAction("Stealth", {
    type = "button", category = "AI & Cameras", badge = "client", text = "Kill All Cameras", tooltip = "Destroys every security camera on the map (works as host and client).",
    callback = function()
        if SecurityCamera and SecurityCamera.cameras then
            local count = 0
            for _, cam in pairs(SecurityCamera.cameras) do
                if alive(cam) then
                    pcall(function()
                        if cam:base() then
                            if cam:base().set_detection_enabled then cam:base():set_detection_enabled(false) end
                            if cam:base().set_update_enabled then cam:base():set_update_enabled(false) end
                            if cam:base().destroy then cam:base():destroy() end
                        end
                    end)
                    pcall(function()
                        local dmg = cam:damage()
                        if dmg then
                            if dmg:has_sequence("broken") then dmg:run_sequence_simple("broken")
                            elseif dmg:has_sequence("destroy") then dmg:run_sequence_simple("destroy")
                            elseif dmg:has_sequence("explode") then dmg:run_sequence_simple("explode") end
                        end
                    end)
                    count = count + 1
                end
            end
            NiceTrainer:Toast("Destroyed " .. tostring(count) .. " cameras!")
        end
    end
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Stealth_Utilities_Reapply", function()
    if NiceTrainer.Settings.unlimited_pagers then apply_unlimited_pagers(true) end
    if NiceTrainer.Settings.infinite_body_bags then apply_infinite_body_bags(true) end
    if NiceTrainer.Settings.infinite_cable_ties then apply_infinite_cable_ties(true) end
    if NiceTrainer.Settings.no_cash_penalty then apply_no_cash_penalty(true) end
    if NiceTrainer.Settings.steal_pagers then apply_steal_pagers(true) end
    if NiceTrainer.Settings.auto_answer_pagers then apply_auto_answer_pagers(true) end
    if NiceTrainer.Settings.camera_kill_on_detection then apply_camera_kill_on_detection(true) end
    NiceTrainer._last_meth_announced = nil
end)

