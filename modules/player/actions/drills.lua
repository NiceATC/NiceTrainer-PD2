-- ─── Drills, Saws & Hacking Machinery (Player Tab) ──────────────────────────
-- Provides instant drilling/hacking, custom timers, auto-service, silent drills, and no jamming.

NiceTrainer._orig_drill = NiceTrainer._orig_drill or {}
local _hooks_installed = false

-- ─── 1. Hook Installation ───────────────────────────────────────────────────

local function ensure_hooks_installed()
    if _hooks_installed then return end
    if not _G.TimerGui then return end
    _hooks_installed = true

    -- Hook TimerGui:update (Drills, Thermal Saws, Hacking Timers, Keypads)
    local orig_tg_update = TimerGui.update
    TimerGui.update = function(self, unit, t, dt, ...)
        if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
            if self._started and not self._done then
                if (self._current_timer or 0) > 0 then
                    self._current_timer = 0
                    if not self._powered then self:set_powered(true) end
                    if self._jammed then self:set_jammed(false) end
                end
            end
        end
        return orig_tg_update(self, unit, t, dt, ...)
    end

    -- Hook TimerGui:start
    local orig_tg_start = TimerGui.start
    TimerGui.start = function(self, timer, ...)
        if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
            timer = 0
        end
        local res = orig_tg_start(self, timer, ...)
        if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
            self._current_timer = 0
            self._timer = 0
        end
        return res
    end

    -- Hook TimerGui:_start
    local orig_tg_pstart = TimerGui._start
    TimerGui._start = function(self, timer, current_timer, ...)
        if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
            timer = 0
            current_timer = 0
        end
        local res = orig_tg_pstart(self, timer, current_timer, ...)
        if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
            self._current_timer = 0
            self._timer = 0
        end
        return res
    end

    -- Hook TimerGui:set_jammed (Never Jam)
    local orig_tg_jammed = TimerGui.set_jammed
    TimerGui.set_jammed = function(self, jammed, ...)
        if jammed and NiceTrainer.Settings and NiceTrainer.Settings.drill_prevent_jamming then
            return
        end
        return orig_tg_jammed(self, jammed, ...)
    end

    -- Hook DigitalGui (Computers, server hacking, countdown panels)
    if _G.DigitalGui then
        local orig_dg_update = DigitalGui.update
        DigitalGui.update = function(self, unit, t, dt, ...)
            if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
                if self._timer and self._timer > 0 then
                    self._timer = 0
                end
            end
            return orig_dg_update(self, unit, t, dt, ...)
        end

        local orig_dg_start = DigitalGui.start_timer
        if orig_dg_start then
            DigitalGui.start_timer = function(self, timer, ...)
                if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
                    timer = 0
                end
                local res = orig_dg_start(self, timer, ...)
                if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
                    self._timer = 0
                end
                return res
            end
        end
    end

    -- Hook SecurityLockGui (Security lock panels)
    if _G.SecurityLockGui then
        local orig_slg_update = SecurityLockGui.update
        SecurityLockGui.update = function(self, unit, t, dt, ...)
            if NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling then
                if self._started and not self._done and (self._current_timer or 0) > 0 then
                    self._current_timer = 0
                end
            end
            return orig_slg_update(self, unit, t, dt, ...)
        end
    end

    -- Hook Drill:set_jammed (Auto-Restart Jammed Drills & Never Jam)
    if _G.Drill then
        local orig_drill_jammed = Drill.set_jammed
        Drill.set_jammed = function(self, jammed, ...)
            if jammed and NiceTrainer.Settings and NiceTrainer.Settings.drill_prevent_jamming then
                return
            end
            local res = orig_drill_jammed(self, jammed, ...)
            if jammed and NiceTrainer.Settings and NiceTrainer.Settings.drill_auto_service and alive(self._unit) then
                local player = managers.player and managers.player:player_unit()
                local interaction = self._unit.interaction and self._unit:interaction()
                if interaction and player then
                    pcall(function()
                        interaction:interact(player)
                    end)
                end
            end
            return res
        end
    end
end

-- Try immediate installation
ensure_hooks_installed()

-- ─── 2. Silent Drills Hooks ───────────────────────────────────────────

local function apply_silent_drills(state)
    if not _G.Drill then return end
    
    if state then
        if not NiceTrainer._orig_drill.init_silent then
            NiceTrainer._orig_drill.init_silent = Drill.init
            Drill.init = function(self, unit, ...)
                local res = NiceTrainer._orig_drill.init_silent(self, unit, ...)
                self._alert_radius = 0
                self._is_silent = true
                return res
            end
        end
        if PlayerManager and not NiceTrainer._orig_drill.upgrade_value then
            NiceTrainer._orig_drill.upgrade_value = PlayerManager.upgrade_value
            PlayerManager.upgrade_value = function(self, category, upgrade, default, ...)
                if category == "player" and (upgrade == "drill_alert" or upgrade == "silent_drill") then
                    return true
                end
                return NiceTrainer._orig_drill.upgrade_value(self, category, upgrade, default, ...)
            end
        end
    else
        if NiceTrainer._orig_drill.init_silent then
            Drill.init = NiceTrainer._orig_drill.init_silent
            NiceTrainer._orig_drill.init_silent = nil
        end
        if NiceTrainer._orig_drill.upgrade_value and PlayerManager then
            PlayerManager.upgrade_value = NiceTrainer._orig_drill.upgrade_value
            NiceTrainer._orig_drill.upgrade_value = nil
        end
    end
end

-- ─── 3. Instant Finish All Active Drills & Hacks ──────────────────────

local function finish_all_active_drills_and_hacks()
    if not NiceTrainer:IsInHeist() then
        return
    end

    local count = 0
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) then
                -- 1. TimerGui (Drills, Saws, Lances, Keypads, Computers)
                if unit.timer_gui and unit:timer_gui() then
                    local tg = unit:timer_gui()
                    if tg and tg._started and not tg._done then
                        pcall(function()
                            if tg._jammed then tg:set_jammed(false) end
                            if not tg._powered then tg:set_powered(true) end
                            tg._current_timer = 0
                            if tg.done then tg:done() end

                            -- Trigger drill/timer completion sequences
                            if alive(unit) and unit:damage() then
                                local dmg = unit:damage()
                                if dmg:has_sequence("timer_done") then pcall(dmg.run_sequence_simple, dmg, "timer_done") end
                                if dmg:has_sequence("drill_done") then pcall(dmg.run_sequence_simple, dmg, "drill_done") end
                                if dmg:has_sequence("done") then pcall(dmg.run_sequence_simple, dmg, "done") end
                            end

                            -- Notify parent door/safe
                            if alive(unit) and unit.mission_door_device and unit:mission_door_device() then
                                local mdd = unit:mission_door_device()
                                if alive(mdd._parent_door) and mdd._parent_door:base() then
                                    pcall(function() mdd._parent_door:base():device_completed(unit) end)
                                end
                            end

                            count = count + 1
                        end)
                    end
                end

                -- 2. SecurityLockGui
                if unit.security_lock_gui and unit:security_lock_gui() then
                    local slg = unit:security_lock_gui()
                    if slg and not slg._done then
                        pcall(function()
                            slg._current_timer = 0
                            if slg.done then slg:done() end
                            count = count + 1
                        end)
                    end
                end

                -- 3. DigitalGui (Computers, server hacks)
                if unit.digital_gui and unit:digital_gui() then
                    local dg = unit:digital_gui()
                    if dg and (dg._timer or 0) > 0 then
                        pcall(function()
                            dg._timer = 0
                            if alive(dg._unit) and dg._unit:damage() then
                                if dg._unit:damage():has_sequence("timer_done") then
                                    pcall(dg._unit:damage().run_sequence_simple, dg._unit:damage(), "timer_done")
                                end
                                if dg._unit:damage():has_sequence("done") then
                                    pcall(dg._unit:damage().run_sequence_simple, dg._unit:damage(), "done")
                                end
                            end
                            count = count + 1
                        end)
                    end
                end

                -- 4. Direct Safe/Vault open sequences
                if unit:damage() and not unit:timer_gui() and not unit:digital_gui() then
                    local dmg = unit:damage()
                    local seqs = { "open_safe", "safe_open", "open_titan", "open_vault", "open_the_vault", "drill_done", "lance_done", "door_opened" }
                    if unit:base() and unit:base()._devices and unit:base()._devices.drill then
                        local dinfo = unit:base()._devices.drill
                        if dinfo.completed or (dinfo.completed_counter and dinfo.completed_counter >= (dinfo.amount or 1)) then
                            for _, seq in ipairs(seqs) do
                                if dmg:has_sequence(seq) then
                                    pcall(dmg.run_sequence_simple, dmg, seq)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
end

-- ─── 4. Custom Timer for All Active Drills & Hacks ────────────────────

local function apply_custom_drill_timer(seconds)
    if not NiceTrainer:IsInHeist() then
        return
    end
    
    local sec = tonumber(seconds) or 1
    local count = 0
    
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) then
                if unit.timer_gui and unit:timer_gui() then
                    local tg = unit:timer_gui()
                    if tg and tg._started and not tg._done then
                        pcall(function()
                            if tg._jammed then tg:set_jammed(false) end
                            tg._timer = sec
                            tg._current_timer = sec
                            if managers.network and managers.network:session() and alive(tg._unit) then
                                managers.network:session():send_to_peers_synched("start_timer_gui", tg._unit, sec)
                            end
                            if sec <= 0.05 then
                                if tg.done then tg:done() end
                            end
                            count = count + 1
                        end)
                    end
                end

                if unit.digital_gui and unit:digital_gui() then
                    local dg = unit:digital_gui()
                    if dg and (dg._timer or 0) > 0 then
                        pcall(function()
                            dg._timer = sec
                            if sec <= 0.05 and alive(dg._unit) and dg._unit:damage() then
                                if dg._unit:damage():has_sequence("timer_done") then
                                    pcall(dg._unit:damage().run_sequence_simple, dg._unit:damage(), "timer_done")
                                end
                            end
                            count = count + 1
                        end)
                    end
                end
            end
        end
    end)
end

-- ─── 5. Action Registrations (Player Tab) ─────────────────────────────

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Drills, Saws & Hacking",
    badge    = "client",
    id       = "instant_drilling",
    text     = "Instant Drilling & Hacking (0s)",
    tooltip  = "All placed drills, thermal saws, and hacking devices complete and open targets immediately.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.instant_drilling = state
        ensure_hooks_installed()
        if state then
            finish_all_active_drills_and_hacks()
        end
    end
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Drills, Saws & Hacking",
    badge    = "client",
    id       = "drill_prevent_jamming",
    text     = "Drills & Hacks Never Jam",
    tooltip  = "Prevents all drills, saws, and hacking devices from breaking down or jamming during operation.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.drill_prevent_jamming = state
        ensure_hooks_installed()
    end
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Drills, Saws & Hacking",
    badge    = "client",
    id       = "drill_auto_service",
    text     = "Auto-Restart Jammed Drills & Hacks",
    tooltip  = "Automatically and instantly restarts any jammed drill or interrupted hack anywhere across the map without walking to it.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.drill_auto_service = state
        ensure_hooks_installed()
    end
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Drills, Saws & Hacking",
    badge    = "client",
    id       = "drill_silent",
    text     = "Silent Drills (Stealth)",
    tooltip  = "Drills make zero noise and have 0 alert radius, keeping guards and civilians oblivious.",
    default  = false,
    callback = apply_silent_drills
})

NiceTrainer:RegisterAction("Player", {
    type           = "inputbox",
    category       = "Drills, Saws & Hacking",
    badge          = "client",
    id             = "custom_drill_timer_input",
    text           = "Set Active Drills/Hacks Timer (Seconds)",
    tooltip        = "Enter desired time in seconds and click Apply to update all running drills, saws, and hacking timers.",
    min            = 0,
    max            = 3600,
    default        = 5,
    action_btn_text = "Apply Timer",
    callback       = function(val)
        apply_custom_drill_timer(val)
    end
})

NiceTrainer:RegisterAction("Player", {
    type           = "multichoice",
    category       = "Drills, Saws & Hacking",
    badge          = "client",
    id             = "drill_timer_presets",
    text           = "Drill & Hack Time Presets",
    tooltip        = "Select a preset timer and click Apply.",
    options        = {"Instant (0s)", "5 Seconds", "10 Seconds", "20 Seconds", "30 Seconds", "60 Seconds"},
    default        = 2,
    action_btn_text = "Apply Preset",
    callback       = function(idx, val)
        local map = { [1] = 0.01, [2] = 5, [3] = 10, [4] = 20, [5] = 30, [6] = 60 }
        local chosen = map[idx] or 5
        apply_custom_drill_timer(chosen)
    end
})

NiceTrainer:RegisterAction("Player", {
    type           = "button",
    category       = "Drills, Saws & Hacking",
    badge          = "client",
    text           = "Instant Finish All Active Drills & Hacks",
    tooltip        = "Immediately finishes all active drills, saws, and hacking timers right now.",
    action_btn_text = "Finish All",
    callback       = finish_all_active_drills_and_hacks
})

-- Apply settings and ensure hooks on load and state transitions
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyDrills", function()
    ensure_hooks_installed()
    if NiceTrainer.Settings and NiceTrainer.Settings.drill_silent then
        apply_silent_drills(true)
    end
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_EnsureDrillHooks", function(t, dt)
    if not _hooks_installed and _G.TimerGui then
        ensure_hooks_installed()
    end
end)
