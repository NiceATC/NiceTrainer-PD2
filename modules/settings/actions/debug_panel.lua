-- NiceTrainer Debug System: real-time in-game panel
-- Non-interactive overlay (own fullscreen workspace) that shows live stats, watchers, the hook
-- profiler and the tail of the debug log. Toggle it from Settings tab "Debug".

local D = NiceTrainer.Debug
if not D then return end

local P = {}
D.Panel = P

local PANEL_W      = 640
local LINE_H       = 13
local FONT_SIZE    = 11
local REFRESH_RATE = 0.2

local LEVEL_COLORS = {
    [1] = Color(0.6, 0.6, 0.6),
    [2] = Color(0.92, 0.92, 0.92),
    [3] = Color(1, 0.85, 0.25),
    [4] = Color(1, 0.35, 0.3),
}

P._acc = 0

local function font()
    return (tweak_data and tweak_data.menu and tweak_data.menu.pd2_small_font) or "fonts/font_small_mf"
end

function P:Destroy()
    if self.ws then
        pcall(function()
            if alive(self.ws) then Overlay:gui():destroy_workspace(self.ws) end
        end)
    end
    self.ws, self.root, self.header, self.stats, self.hooks, self.lines, self.bg = nil, nil, nil, nil, nil, nil, nil
    self.built_lines = nil
end

function P:IsAlive()
    return self.ws and alive(self.ws) and self.root and alive(self.root)
end

function P:Build()
    if not (managers.gui_data and Overlay) then return false end
    self:Destroy()

    local nlines = math.floor(D:Opt("debug_panel_lines", 14))
    local show_hooks = D:Opt("debug_panel_hooks", true)
    local show_watch = D:Opt("debug_panel_watch", true)
    local nwatch = show_watch and #D.watchers or 0
    local nhooks = show_hooks and 5 or 0

    local header_h = 18
    local stats_h = nwatch * LINE_H + 4
    local hooks_h = nhooks > 0 and ((nhooks + 1) * LINE_H + 4) or 0
    local log_h = nlines * LINE_H
    local total_h = header_h + stats_h + hooks_h + log_h + 10

    self.ws = managers.gui_data:create_fullscreen_workspace()
    local parent = self.ws:panel()
    
    local px = NiceTrainer.Settings.debug_panel_x or (parent:w() - PANEL_W - 10)
    local py = NiceTrainer.Settings.debug_panel_y or 60

    self.root = parent:panel({
        w = PANEL_W, h = total_h,
        x = px, y = py,
        layer = 4000,
    })

    local accent = NiceTrainer:GetAccentColor()
    self.bg = self.root:rect({ color = Color.black, alpha = D:Opt("debug_panel_alpha", 75) / 100, layer = 0 })
    self.root:rect({ color = accent, h = 2, layer = 1 })

    local y = 4
    self.header = self.root:text({
        text = "NiceTrainer Debug", font = font(), font_size = 14, color = accent,
        x = 6, y = y, layer = 2,
    })
    y = y + header_h

    self.stats_lines = {}
    if show_watch then
        self.stats = {}
        for i = 1, nwatch do
            self.stats[i] = self.root:text({
                text = "", font = font(), font_size = FONT_SIZE, color = Color(0.75, 0.85, 1),
                x = 6, y = y + (i - 1) * LINE_H, layer = 2,
            })
        end
        y = y + stats_h
    else
        self.stats = nil
    end

    if show_hooks then
        self.hooks = {}
        for i = 1, nhooks + 1 do
            self.hooks[i] = self.root:text({
                text = "", font = font(), font_size = FONT_SIZE,
                color = i == 1 and Color(0.7, 0.7, 0.7) or Color(0.6, 1, 0.7),
                x = 6, y = y + (i - 1) * LINE_H, layer = 2,
            })
        end
        y = y + hooks_h
    else
        self.hooks = nil
    end

    self.lines = {}
    for i = 1, nlines do
        self.lines[i] = self.root:text({
            text = "", font = font(), font_size = FONT_SIZE, color = Color.white,
            x = 6, y = y + (i - 1) * LINE_H, layer = 2,
        })
    end

    self.built_lines, self.built_hooks, self.built_watch, self.built_nwatch = nlines, show_hooks, show_watch, nwatch
    return true
end

local function truncate(s, n)
    s = tostring(s):gsub("[\r\n].*", "")
    if #s > n then s = s:sub(1, n - 2) .. ".." end
    return s
end

function P:Refresh()
    if not self:IsAlive() then return end

    local fps_color = D.fps >= 50 and Color(0.5, 1, 0.5) or (D.fps >= 30 and Color(1, 0.85, 0.25) or Color(1, 0.35, 0.3))
    self.header:set_text(string.format(
        "NiceTrainer Debug  |  FPS %.0f (min %.0f)  |  I:%d W:%d E:%d  |  %d entries",
        D.fps, D.fps_min, D.level_counts[2], D.level_counts[3], D.level_counts[4], D.seq))
    self.header:set_color(D.level_counts[4] > 0 and Color(1, 0.5, 0.45) or fps_color)

    -- watchers (non heavy)
    if self.stats then
        local vals = D:EvalWatchers(false)
        local line = 0
        for i, txt in ipairs(self.stats) do
            local w = vals[i]
            if alive(txt) then
                txt:set_text(w and string.format("%-14s %s", w.name, truncate(w.value, 80)) or "")
            end
        end
    end

    -- hook profiler: top 5 by ms/sec
    if self.hooks then
        local list = {}
        for key, st in pairs(D.hook_stats) do list[#list + 1] = { key = key, st = st } end
        table.sort(list, function(a, b) return a.st.rate > b.st.rate end)
        self.hooks[1]:set_text("HOOK PROFILER (ms of CPU per second)")
        for i = 2, #self.hooks do
            local h = list[i - 1]
            local txt = self.hooks[i]
            if h then
                local name = h.key:gsub("^NiceTrainer_", "")
                txt:set_text(string.format("%-42s %6.2f ms/s  max %6.2f ms  err %d",
                    truncate(name, 42), h.st.rate, h.st.max * 1000, h.st.errors))
                txt:set_color(h.st.errors > 0 and Color(1, 0.4, 0.35) or Color(0.6, 1, 0.7))
            else
                txt:set_text("")
            end
        end
    end

    -- log tail
    local min_level = math.floor(D:Opt("debug_panel_level", 1))
    local nt_only = D:Opt("debug_panel_nt_only", false)
    local entries = D:Recent(#self.lines, min_level, nt_only)
    local offset = #self.lines - #entries
    for i, txt in ipairs(self.lines) do
        if alive(txt) then
            local e = entries[i - offset]
            if e then
                txt:set_text(truncate(string.format("%7.1f %-4s %-9s %s",
                    e.t, D.LEVEL_NAMES[e.level]:sub(1, 4), truncate(e.cat, 9), e.msg), 105))
                txt:set_color(LEVEL_COLORS[e.level] or Color.white)
            else
                txt:set_text("")
            end
        end
    end
end

-- Called by the Debug tab whenever a panel option changes.
function P:Apply()
    if D:Opt("debug_panel", false) and D:Enabled() then
        self:Build()
        self:Refresh()
    else
        self:Destroy()
    end
end

function P:OnUpdate(t, dt)
    if not (D:Opt("debug_panel", false) and D:Enabled()) then
        if self.ws then self:Destroy() end
        return
    end
    -- (Re)build lazily: workspaces die on level change / menu transitions
    if not self:IsAlive() then
        if not self:Build() then return end
    end
    -- the layout depends on options: rebuild when they changed
    if self.built_lines ~= math.floor(D:Opt("debug_panel_lines", 14))
        or self.built_hooks ~= D:Opt("debug_panel_hooks", true)
        or self.built_watch ~= D:Opt("debug_panel_watch", true)
        or (self.built_watch and self.built_nwatch ~= #D.watchers) then
        self:Build()
    end
    if self.bg and alive(self.bg) then self.bg:set_alpha(D:Opt("debug_panel_alpha", 75) / 100) end

    self._acc = self._acc + dt
    if self._acc >= REFRESH_RATE then
        self._acc = 0
        local ok, err = pcall(self.Refresh, self)
        if not ok then
            -- never let the panel itself spam / crash: disable and report once
            log("[NiceTrainer Debug] Panel refresh failed: " .. tostring(err))
            self:Destroy()
            NiceTrainer.Settings.debug_panel = false
        end
    end
end

Hooks:Add("GameSetupUpdate", "NiceTrainer_DebugPanel_Update", function(t, dt) P:OnUpdate(t, dt) end)
Hooks:Add("MenuUpdate", "NiceTrainer_DebugPanel_UpdateMenu", function(t, dt) P:OnUpdate(t, dt) end)

local orig_mouse_pressed = NiceTrainer.mouse_pressed
function NiceTrainer:mouse_pressed(o, button, x, y)
    if button == Idstring("0") and P and P:IsAlive() and NiceTrainer.IsOpen then
        if P.bg and P.bg:inside(x, y) then
            P._dragging = true
            P._drag_x = x - P.root:x()
            P._drag_y = y - P.root:y()
            return
        end
    end
    if orig_mouse_pressed then return orig_mouse_pressed(self, o, button, x, y) end
end

local orig_mouse_moved = NiceTrainer.mouse_moved
function NiceTrainer:mouse_moved(o, x, y)
    if P and P._dragging and P:IsAlive() then
        P.root:set_x(x - P._drag_x)
        P.root:set_y(y - P._drag_y)
        return
    end
    if orig_mouse_moved then return orig_mouse_moved(self, o, x, y) end
end

local orig_mouse_release = NiceTrainer.mouse_release
function NiceTrainer:mouse_release(o, button, x, y)
    if P and P._dragging then
        P._dragging = false
        NiceTrainer.Settings.debug_panel_x = P.root:x()
        NiceTrainer.Settings.debug_panel_y = P.root:y()
        NiceTrainer:Save()
    end
    if orig_mouse_release then return orig_mouse_release(self, o, button, x, y) end
end
