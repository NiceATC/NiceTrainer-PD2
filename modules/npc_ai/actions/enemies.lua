-- Enemy & AI Control for NPC AI Tab

local _originals = {}

local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then
        _originals[key] = cls[method_name]
    end
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

local function each_enemy(fn)
    pcall(function()
        if managers.enemy then
            for _, data in pairs(managers.enemy:all_enemies()) do
                if alive(data.unit) then pcall(fn, data.unit) end
            end
        end
    end)
end

local function each_civilian(fn)
    pcall(function()
        if managers.enemy then
            for _, data in pairs(managers.enemy:all_civilians()) do
                if alive(data.unit) then pcall(fn, data.unit) end
            end
        end
    end)
end

local function each_camera(fn)
    pcall(function()
        if SecurityCamera and SecurityCamera.cameras then
            for _, unit in pairs(SecurityCamera.cameras) do
                if alive(unit) then pcall(fn, unit) end
            end
        end
    end)
end

local function each_turret(fn)
    pcall(function()
        local state = managers.groupai and managers.groupai:state()
        if state and state:turrets() then
            for _, unit in pairs(state:turrets()) do
                if alive(unit) then pcall(fn, unit) end
            end
        end
    end)
end

local function freeze_all()
    each_enemy(function(u) if u:brain():is_active() then u:brain():set_active(false) end end)
    each_civilian(function(u) if u:brain():is_active() then u:brain():set_active(false) end end)
    each_camera(function(u)
        if u:base()._detection_interval ~= 999999999 then u:base()._detection_interval = 999999999 end
    end)
    each_turret(function(u) if u:brain():is_active() then u:brain():set_active(false) end end)
end

local function unfreeze_all()
    each_enemy(function(u)
        local brain = u:brain()
        if brain and not brain:is_active() then
            pcall(function()
                brain:set_active(true)
                brain:set_update_enabled_state(true)
            end)
        end
    end)
    each_civilian(function(u)
        local brain = u:brain()
        if brain and not brain:is_active() then
            pcall(function()
                brain:set_active(true)
                brain:set_update_enabled_state(true)
            end)
        end
    end)
    each_camera(function(u)
        local base = u:base()
        if base and not base._destroyed then
            base._detection_interval = base._detection_interval or 0.1
            base._last_detect_t = base._last_detect_t or (TimerManager and TimerManager:game() and TimerManager:game():time()) or 0
            if base.set_update_enabled then
                base:set_update_enabled(true)
            end
        end
    end)
    each_turret(function(u)
        if u:brain() and not u:brain():is_active() then
            u:brain():set_active(true)
        end
    end)
end

if not NiceTrainer._npc_ai_freeze_hooked then
    Hooks:Add("GameSetupUpdate", "NiceTrainer_AI_FreezeLoop", function()
        if not NiceTrainer:IsInHeist() then return end
        if NiceTrainer.Settings.disable_all_ai then freeze_all() end
    end)
    NiceTrainer._npc_ai_freeze_hooked = true
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "AI Control",
    badge    = "host",
    id       = "disable_all_ai",
    text     = "Disable All AI (Freeze)",
    tooltip  = "Freezes every cop, civilian, camera and turret. Nothing can move or detect you.",
    default  = false,
    save     = false,
    callback = function(state)
        if not state then unfreeze_all() end
    end,
})

local function applyCopsDontShoot(enabled)
    if enabled then
        hijack("CopMovement", "set_allow_fire", function(self, state, ...)
            if state then return end
            return _originals["CopMovement.set_allow_fire"](self, state, ...)
        end)
        hijack("CopMovement", "set_allow_fire_on_client", function(self, state, ...)
            if state then return end
            return _originals["CopMovement.set_allow_fire_on_client"](self, state, ...)
        end)
    else
        restore("CopMovement", "set_allow_fire")
        restore("CopMovement", "set_allow_fire_on_client")
    end
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "AI Control",
    badge    = "host",
    id       = "cops_dont_shoot",
    text     = "Cops Don't Shoot",
    tooltip  = "Police are never allowed to open fire on you.",
    default  = false,
    callback = applyCopsDontShoot,
})

local function applyPreventPanicButtons(enabled)
    if enabled then
        if _G.CopLogicArrest then
            hijack("CopLogicArrest", "_call_the_police", function(data, my_data, ...)
                return
            end)
        end
        if _G.CivilianLogicSurprised then
            hijack("CivilianLogicSurprised", "on_alarm", function(data, ...)
                return
            end)
        end
        if _G.CivilianLogicFlee then
            hijack("CivilianLogicFlee", "on_alarm", function(data, ...)
                return
            end)
        end
    else
        restore("CopLogicArrest", "_call_the_police")
        restore("CivilianLogicSurprised", "on_alarm")
        restore("CivilianLogicFlee", "on_alarm")
    end
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "AI Control",
    badge    = "host",
    id       = "prevent_panic_buttons",
    text     = "Prevent Panic Buttons",
    tooltip  = "Guards and civilians are blocked from pressing alarm/panic buttons or calling police.",
    default  = false,
    callback = applyPreventPanicButtons,
})

local function applyDisableCameras(enabled)
    each_camera(function(unit)
        if alive(unit) and unit:base() and unit:base().set_update_enabled then
            if enabled then
                unit:base():set_update_enabled(false)
            else
                if unit:base()._last_detect_t ~= nil and not unit:base()._destroyed then
                    unit:base():set_update_enabled(true)
                end
            end
        end
    end)
    if _G.SecurityCamera then
        if enabled then
            hijack("SecurityCamera", "_upd_detection", function(self, ...)
                if NiceTrainer.Settings.disable_cameras then return end
                if not self._last_detect_t or not self._look_obj or self._destroyed then return end
                return _originals["SecurityCamera._upd_detection"](self, ...)
            end)
        else
            restore("SecurityCamera", "_upd_detection")
        end
    end
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "AI Control",
    badge    = "client",
    id       = "disable_cameras",
    text     = "Disable Security Cameras",
    tooltip  = "Stops all security cameras from detecting you (works as host and client).",
    default  = false,
    callback = applyDisableCameras,
})

local function kill_enemy_unit(u, attacker)
    if not alive(u) then return false end
    local dmg = u:character_damage()
    if not dmg or dmg:dead() then return false end

    attacker = attacker or (managers.player and managers.player:player_unit())
    local head_body = u:body("head") or u:body("hit_Head") or u:body("body") or (u:num_bodies() > 0 and u:body(0))
    local col_ray = {
        unit = u,
        body = head_body,
        position = u:position(),
        ray = math.UP,
        normal = math.UP
    }
    local weapon = attacker and alive(attacker:inventory():equipped_unit()) and attacker:inventory():equipped_unit() or attacker
    local attack_data = {
        variant = "bullet",
        damage = 1000000,
        attacker_unit = attacker,
        weapon_unit = weapon,
        col_ray = col_ray,
        origin = attacker and attacker:position() or u:position(),
        pos = u:position()
    }

    if Network:is_server() then
        if dmg.damage_bullet then
            dmg:damage_bullet(attack_data)
        elseif dmg.death then
            dmg:death(attack_data)
        end
    else
        if dmg.damage_bullet then
            dmg:damage_bullet(attack_data)
        elseif dmg.damage_mission then
            dmg:damage_mission({ damage = 1000000, attacker_unit = attacker, col_ray = col_ray })
        end
    end
    return true
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "button",
    category = "Lethal",
    badge    = "client",
    text     = "Kill All Enemies",
    tooltip  = "Instantly kills every living cop/guard on the map (works as host and client).",
    callback = function()
        if not NiceTrainer:IsInHeist() then NiceTrainer:Toast("Only in heist!"); return end
        local count = 0
        local player = managers.player and managers.player:player_unit()
        each_enemy(function(u)
            pcall(function()
                if kill_enemy_unit(u, player) then
                    count = count + 1
                end
            end)
        end)
        NiceTrainer:Toast("Killed " .. count .. " enemies")
    end,
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NPCAI_Enemies_Load", function()
    NiceTrainer.Settings.disable_all_ai = false
    if NiceTrainer._toggle_elements and NiceTrainer._toggle_elements.disable_all_ai then
        NiceTrainer._toggle_elements.disable_all_ai(false)
    end
    if NiceTrainer.Settings.cops_dont_shoot       then applyCopsDontShoot(true)        end
    if NiceTrainer.Settings.prevent_panic_buttons then applyPreventPanicButtons(true)  end
    if NiceTrainer.Settings.disable_cameras       then applyDisableCameras(true)       end
end)
