-- NiceTrainer Debug System: Debug tab actions (works in menu AND in game)

local D = NiceTrainer.Debug
if not D then return end

local function panel_apply()
    if D.Panel then D.Panel:Apply() end
end

-- ─── Logging ────────────────────────────────────────────────────────────────────────────────────

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_enabled", no_bind = true,
    text = "Enable Debug System", default = true, save = true,
    tooltip = "Master switch. Captures logs, errors and performance data into NiceTrainer_debug.log.",
    callback = function(state)
        NiceTrainer.Settings.debug_enabled = state
        panel_apply()
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_file", no_bind = true,
    text = "Write Own Log File", default = true, save = true,
    tooltip = "Writes everything to SavePath/NiceTrainer_debug.log (previous session: NiceTrainer_debug_prev.log).",
    callback = function(state) NiceTrainer.Settings.debug_file = state end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_capture_log", no_bind = true,
    text = "Capture log() Output", default = true, save = true,
    tooltip = "Mirrors every log() call (NiceTrainer, BLT and other mods) into the debug log.",
    callback = function(state) NiceTrainer.Settings.debug_capture_log = state end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_capture_foreign", no_bind = true,
    text = "Include Other Mods' Logs", default = true, save = true,
    tooltip = "Also keep log() lines that are not tagged [NiceTrainer ...].",
    callback = function(state) NiceTrainer.Settings.debug_capture_foreign = state end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_trace", no_bind = true,
    text = "Verbose Trace", default = false, save = true,
    tooltip = "Logs every action/button/toggle invocation with its arguments. Can be noisy.",
    callback = function(state)
        NiceTrainer.Settings.debug_trace = state
        D:Info("debug", "Verbose trace %s", state and "ON" or "OFF")
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Debug System", id = "debug_wrap_hooks", no_bind = true,
    text = "Hook Profiler & Error Catcher", default = true, save = true,
    tooltip = "Measures CPU time of every NiceTrainer hook and logs errors thrown inside them (applies fully after restart).",
    callback = function(state) NiceTrainer.Settings.debug_wrap_hooks = state end,
})

-- ─── Live panel ─────────────────────────────────────────────────────────────────────────────────

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Live Panel", id = "debug_panel",
    text = "Live Debug Panel", default = false, save = true,
    tooltip = "Real-time overlay: FPS, game state, host/client role, watchers, hook profiler and the log tail.",
    callback = function(state)
        NiceTrainer.Settings.debug_panel = state
        panel_apply()
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "slider", category = "Live Panel", id = "debug_panel_lines",
    text = "Log Lines", min = 4, max = 30, default = 14, save = true,
    callback = function(val) NiceTrainer.Settings.debug_panel_lines = math.floor(val) end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "slider", category = "Live Panel", id = "debug_panel_alpha",
    text = "Background Opacity", min = 10, max = 100, default = 75, save = true,
    callback = function(val) NiceTrainer.Settings.debug_panel_alpha = val end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "multichoice", category = "Live Panel", id = "debug_panel_level",
    text = "Show Level", options = { "All", "Info+", "Warnings+", "Errors only" }, default = 1, save = true,
    callback = function(idx) NiceTrainer.Settings.debug_panel_level = idx end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Live Panel", id = "debug_panel_nt_only", no_bind = true,
    text = "Only NiceTrainer Messages", default = false, save = true,
    callback = function(state) NiceTrainer.Settings.debug_panel_nt_only = state end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Live Panel", id = "debug_panel_watch", no_bind = true,
    text = "Show Live Values", default = true, save = true,
    tooltip = "Host/client role, game state, level, units, memory...",
    callback = function(state) NiceTrainer.Settings.debug_panel_watch = state end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "toggle", category = "Live Panel", id = "debug_panel_hooks", no_bind = true,
    text = "Show Hook Profiler", default = true, save = true,
    callback = function(state) NiceTrainer.Settings.debug_panel_hooks = state end,
})

-- ─── Tools ──────────────────────────────────────────────────────────────────────────────────────

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Dump Full Snapshot", no_bind = true,
    action_btn_text = "Dump",
    tooltip = "Writes role, level, unit counts, hook timings, counters and error sources to the log.",
    callback = function()
        D:Snapshot("manual dump")
        NiceTrainer:Toast("Snapshot written to NiceTrainer_debug.log")
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Copy Recent Log To Clipboard", no_bind = true,
    action_btn_text = "Copy",
    callback = function()
        local lines = {}
        for _, e in ipairs(D:Recent(80, 1, false)) do lines[#lines + 1] = D:FormatEntry(e) end
        local ok = pcall(function() Application:set_clipboard(table.concat(lines, "\n")) end)
        NiceTrainer:Toast(ok and ("Copied " .. #lines .. " log lines") or "Clipboard not available")
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Copy Log File Path", no_bind = true,
    action_btn_text = "Copy",
    callback = function()
        pcall(function() Application:set_clipboard(D.file_path) end)
        NiceTrainer:Toast("Log: " .. D.file_path)
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Write Test Messages", no_bind = true,
    action_btn_text = "Test",
    callback = function()
        pcall(function()
            D:Trace("test", "trace message (only visible with Verbose Trace)")
            D:Info("test", "info message")
            D:Warn("test", "warning message")
            D:Error("test", "error message")
        end)
        NiceTrainer:Toast("Test messages written")
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Clear Panel / Memory Log", no_bind = true,
    action_btn_text = "Clear",
    tooltip = "Clears the in-memory buffer shown in the panel. The log file is kept.",
    callback = function()
        D:Clear()
        NiceTrainer:Toast("Debug buffer cleared")
    end,
})

NiceTrainer:RegisterAction("Debug", {
    type = "button", category = "Tools", text = "Reset Hook Statistics", no_bind = true,
    action_btn_text = "Reset",
    callback = function()
        for _, st in pairs(D.hook_stats) do
            st.calls, st.total, st.max, st.last, st.errors, st.win, st.rate = 0, 0, 0, 0, 0, 0, 0
        end
        D.counters = {}
        NiceTrainer:Toast("Hook statistics reset")
    end,
})
