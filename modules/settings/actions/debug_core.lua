-- NiceTrainer Debug System (core)
-- Loaded VERY early (framework/init.lua) so it can capture log(), wrap NiceTrainer hooks and
-- trace every registered action. Writes its own log file: <SavePath>/NiceTrainer_debug.log
-- (previous session is kept as NiceTrainer_debug_prev.log).
--
-- Public API (safe to call from any module, no need to check if it exists first if you guard with
-- `if NiceTrainer.Debug then ... end`):
--   NiceTrainer.Debug:Trace(cat, msg, ...)   -- only stored when "Verbose trace" is on
--   NiceTrainer.Debug:Info / Warn / Error(cat, msg, ...)
--   NiceTrainer.Debug:Pcall(cat, fn, ...)    -- pcall + traceback logged on failure
--   NiceTrainer.Debug:Count(name [, n])      -- named counters (shown in snapshots)
--   NiceTrainer.Debug:Watch(name, fn)        -- live value shown in the panel (fn returns string/number)
--   NiceTrainer.Debug:Snapshot([title])      -- dump full state to the log

if NiceTrainer.Debug then return end

local D = {}
NiceTrainer.Debug = D

local os_clock = os.clock
local string_format = string.format

D.LEVEL_TRACE, D.LEVEL_INFO, D.LEVEL_WARN, D.LEVEL_ERROR = 1, 2, 3, 4
D.LEVEL_NAMES = { "TRACE", "INFO", "WARN", "ERROR" }

D.max_entries   = 800
D.seq           = 0          -- total entries ever added (ring index = seq % max_entries)
D.entries       = {}
D.level_counts  = { 0, 0, 0, 0 }
D.counters      = {}
D.watchers      = {}
D.hook_stats    = {}
D.err_seen      = {}
D.buf           = {}
D.bytes         = 0
D.max_bytes     = 4 * 1024 * 1024
D.start_clock   = os_clock()
D.fps           = 0
D.fps_min       = 0
D.dt            = 0
D.file_path     = NiceTrainer.ModPath .. "NiceTrainer_debug.log"
D.prev_path     = NiceTrainer.ModPath .. "NiceTrainer_debug_prev.log"

-- ─── Settings helper (Settings may not be loaded yet when we start) ─────────────────────────────

function D:Opt(key, default)
    local s = NiceTrainer.Settings
    local v = s and s[key]
    if v == nil then return default end
    return v
end

function D:Enabled()
    return self:Opt("debug_enabled", true)
end

-- ─── Log file ───────────────────────────────────────────────────────────────────────────────────

function D:_rotate_session()
    pcall(function()
        if os.remove then os.remove(self.prev_path) end
        if os.rename then os.rename(self.file_path, self.prev_path) end
    end)
    local f = io.open(self.file_path, "w")
    if f then
        f:write(string_format("=== NiceTrainer debug log | %s ===\n", os.date("%Y-%m-%d %H:%M:%S")))
        f:close()
    end
end

function D:Flush()
    local n = #self.buf
    if n == 0 then return end
    local text = table.concat(self.buf, "\n") .. "\n"
    self.buf = {}
    if not self:Opt("debug_file", true) then return end

    if self.bytes > self.max_bytes then
        -- keep the file bounded: roll over to the "prev" file
        pcall(function()
            if os.remove then os.remove(self.prev_path) end
            if os.rename then os.rename(self.file_path, self.prev_path) end
        end)
        self.bytes = 0
    end
    pcall(function()
        local f = io.open(self.file_path, "a")
        if f then
            f:write(text)
            f:close()
            self.bytes = self.bytes + #text
        end
    end)
end

-- ─── Entries ────────────────────────────────────────────────────────────────────────────────────

local MAX_MSG = 1500

function D:Add(level, cat, msg, is_nt)
    if not self:Enabled() then return end
    msg = tostring(msg)
    if #msg > MAX_MSG then msg = msg:sub(1, MAX_MSG) .. "...[truncated]" end

    local now = os_clock() - self.start_clock
    local entry = { t = now, level = level, cat = cat or "?", msg = msg, nt = is_nt ~= false }
    self.entries[(self.seq % self.max_entries) + 1] = entry
    self.seq = self.seq + 1
    self.level_counts[level] = (self.level_counts[level] or 0) + 1

    self.buf[#self.buf + 1] = string_format("%s [%8.2f] %-5s %-14s %s",
        os.date("%H:%M:%S"), now, self.LEVEL_NAMES[level], entry.cat, msg)
    if level >= self.LEVEL_ERROR or #self.buf >= 60 then
        self:Flush()
    end
end

local function fmt(msg, ...)
    if select("#", ...) == 0 then return tostring(msg) end
    local ok, res = pcall(string_format, tostring(msg), ...)
    return ok and res or (tostring(msg) .. " [fmt error]")
end

function D:Trace(cat, msg, ...)
    if not self:Opt("debug_trace", false) then return end
    self:Add(self.LEVEL_TRACE, cat, fmt(msg, ...))
end
function D:Info(cat, msg, ...)  self:Add(self.LEVEL_INFO,  cat, fmt(msg, ...)) end
function D:Warn(cat, msg, ...)  self:Add(self.LEVEL_WARN,  cat, fmt(msg, ...)) end
function D:Error(cat, msg, ...) self:Add(self.LEVEL_ERROR, cat, fmt(msg, ...)) end

-- Error logger that avoids spamming per-frame failures: first 3 occurrences, then every 200th.
function D:ErrorOnce(cat, key, msg)
    local c = (self.err_seen[key] or 0) + 1
    self.err_seen[key] = c
    if c <= 3 or c % 200 == 0 then
        self:Add(self.LEVEL_ERROR, cat, string_format("%s%s", tostring(msg), c > 1 and (" (x" .. c .. ")") or ""))
    end
end

local function traceback_handler(err)
    local tb = (debug and debug.traceback) and debug.traceback() or ""
    return tostring(err) .. "\n" .. tb
end

function D:Pcall(cat, fn, ...)
    local n = select("#", ...)
    local args = { ... }
    local ok, res = xpcall(function() return fn(unpack(args, 1, n)) end, traceback_handler)
    if not ok then self:Error(cat, res) end
    return ok, res
end

function D:Count(name, n)
    self.counters[name] = (self.counters[name] or 0) + (n or 1)
end

function D:Watch(name, fn, heavy)
    for _, w in ipairs(self.watchers) do
        if w.name == name then w.fn = fn w.heavy = heavy return end
    end
    table.insert(self.watchers, { name = name, fn = fn, heavy = heavy })
end

function D:EvalWatchers(include_heavy)
    local out = {}
    for _, w in ipairs(self.watchers) do
        if include_heavy or not w.heavy then
            local ok, v = pcall(w.fn)
            out[#out + 1] = { name = w.name, value = ok and tostring(v) or ("<err: " .. tostring(v) .. ">") }
        end
    end
    return out
end

-- Returns up to n entries (oldest -> newest) passing the level / NiceTrainer-only filter.
function D:Recent(n, min_level, nt_only)
    local out = {}
    local first = math.max(0, self.seq - self.max_entries)
    for i = self.seq - 1, first, -1 do
        local e = self.entries[(i % self.max_entries) + 1]
        if e and e.level >= (min_level or 1) and (not nt_only or e.nt) then
            out[#out + 1] = e
            if #out >= n then break end
        end
    end
    -- reverse to oldest -> newest
    local rev = {}
    for i = #out, 1, -1 do rev[#rev + 1] = out[i] end
    return rev
end

function D:Clear()
    self.entries = {}
    self.seq = 0
    self.level_counts = { 0, 0, 0, 0 }
    self.err_seen = {}
end

function D:FormatEntry(e)
    return string_format("[%8.2f] %-5s %-12s %s", e.t, self.LEVEL_NAMES[e.level], e.cat, e.msg)
end

-- ─── log() capture ──────────────────────────────────────────────────────────────────────────────
-- Mirrors EVERYTHING sent to log() (NiceTrainer, BLT and other mods) into our own log/panel.

if not _G._nt_debug_orig_log then
    _G._nt_debug_orig_log = _G.log
end
local orig_log = _G._nt_debug_orig_log

if orig_log then
    _G.log = function(msg, ...)
        orig_log(msg, ...)
        if D._in_capture or not D:Opt("debug_capture_log", true) then return end
        D._in_capture = true
        local s = tostring(msg)
        local tag = s:match("^%[([^%]]+)%]")
        local is_nt = tag ~= nil and tag:find("NiceTrainer", 1, true) ~= nil
        if not is_nt and not D:Opt("debug_capture_foreign", true) then
            D._in_capture = false
            return
        end
        local low = s:lower()
        local level = D.LEVEL_INFO
        if low:find("error", 1, true) or low:find("fail", 1, true) or low:find("exception", 1, true) or low:find("traceback", 1, true) then
            level = D.LEVEL_ERROR
        elseif low:find("warn", 1, true) then
            level = D.LEVEL_WARN
        end
        D:Add(level, is_nt and (tag:gsub("^NiceTrainer%s*", "NT ")) or "log", s, is_nt)
        D._in_capture = false
    end
end

-- ─── Hook wrapper: NiceTrainer hooks get an error catcher + profiler ────────────────────────────

local function wrap_hook(key, fn)
    if type(fn) ~= "function" then return fn end
    local st = D.hook_stats[key]
    if not st then
        st = { calls = 0, total = 0, max = 0, last = 0, errors = 0, win = 0, rate = 0 }
        D.hook_stats[key] = st
    end
    return function(...)
        if not D._wrap_on then return fn(...) end
        local t0 = os_clock()
        local ok, a, b, c = pcall(fn, ...)
        local dt = os_clock() - t0
        st.calls = st.calls + 1
        st.total = st.total + dt
        st.win   = st.win + dt
        st.last  = dt
        if dt > st.max then st.max = dt end
        if not ok then
            st.errors = st.errors + 1
            D:ErrorOnce("hook", "hook:" .. key, string_format("Hook '%s' failed: %s", key, tostring(a)))
            error(a, 0)
        end
        return a, b, c
    end
end

local function is_nt_key(key)
    return type(key) == "string" and key:sub(1, 10) == "NiceTrainer"
end

D._wrap_on = true

if Hooks and not Hooks._nt_debug_wrapped then
    Hooks._nt_debug_wrapped = true
    local o_add, o_post, o_pre = Hooks.Add, Hooks.PostHook, Hooks.PreHook

    if o_add then
        function Hooks:Add(id, key, func)
            if is_nt_key(key) and D:Opt("debug_wrap_hooks", true) then func = wrap_hook(key, func) end
            return o_add(self, id, key, func)
        end
    end
    if o_post then
        function Hooks:PostHook(obj, name, key, func)
            if is_nt_key(key) and D:Opt("debug_wrap_hooks", true) then func = wrap_hook(key, func) end
            return o_post(self, obj, name, key, func)
        end
    end
    if o_pre then
        function Hooks:PreHook(obj, name, key, func)
            if is_nt_key(key) and D:Opt("debug_wrap_hooks", true) then func = wrap_hook(key, func) end
            return o_pre(self, obj, name, key, func)
        end
    end
end

-- ─── Action tracing: wrap every callback registered through NiceTrainer:RegisterAction ───────────

local CALLBACK_FIELDS = { "callback", "settings_callback", "choice_callback", "slider_callback" }

local function args_to_string(...)
    local n = select("#", ...)
    if n == 0 then return "" end
    local parts = {}
    for i = 1, math.min(n, 4) do
        local v = select(i, ...)
        parts[#parts + 1] = type(v) == "userdata" and "<userdata>" or tostring(v)
    end
    return table.concat(parts, ", ")
end

function D:WrapRegistry()
    if not NiceTrainer.RegisterAction or NiceTrainer.RegisterAction == self._registry_wrapper then return end
    local o_register = NiceTrainer.RegisterAction

    function NiceTrainer:RegisterAction(tab_name, def)
        if type(def) == "table" then
            local label = tostring(tab_name) .. "/" .. tostring(def.id or def.text or "?")
            for _, field in ipairs(CALLBACK_FIELDS) do
                local fn = def[field]
                if type(fn) == "function" then
                    def[field] = function(...)
                        if not D._wrap_on or not D:Enabled() then return fn(...) end
                        if D:Opt("debug_trace", false) then
                            D:Trace("action", "%s.%s(%s)", label, field, args_to_string(...))
                        end
                        D:Count("action:" .. label)
                        local ok, a, b, c = pcall(fn, ...)
                        if not ok then
                            D:ErrorOnce("action", "action:" .. label .. field,
                                string_format("Action '%s' (%s) failed: %s", label, field, tostring(a)))
                            error(a, 0)
                        end
                        return a, b, c
                    end
                end
            end
        end
        return o_register(self, tab_name, def)
    end
    self._registry_wrapper = NiceTrainer.RegisterAction
end

-- ─── Built-in watchers ──────────────────────────────────────────────────────────────────────────

local function count_table(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

D:Watch("role", function()
    if not Network then return "?" end
    local role = Network:is_server() and "HOST" or (Network:is_client() and "CLIENT" or "?")
    local session = managers.network and managers.network:session()
    local peers = session and session:peers() and count_table(session:peers()) or 0
    return string_format("%s (remote peers: %d)", role, peers)
end)
D:Watch("state", function()
    return game_state_machine and game_state_machine:current_state_name() or "?"
end)
D:Watch("level", function()
    return tostring(NiceTrainer:GetCurrentLevelId())
end)
D:Watch("player", function()
    local u = managers.player and managers.player:player_unit()
    if not alive(u) then return "no unit" end
    local p = u:position()
    return string_format("alive @ %.0f, %.0f, %.0f", p.x, p.y, p.z)
end)
D:Watch("enemies", function()
    if not (managers.enemy and managers.enemy.all_enemies) then return "-" end
    return count_table(managers.enemy:all_enemies())
end)
D:Watch("interactables", function()
    local iu = managers.interaction and managers.interaction._interactive_units
    return iu and #iu or "-"
end)
D:Watch("all units", function()
    if not (World and World.find_units_quick) then return "-" end
    local u = World:find_units_quick("all")
    return u and #u or 0
end, true)
D:Watch("lua mem", function()
    return string_format("%.1f MB", collectgarbage("count") / 1024)
end)

-- ─── Snapshot ───────────────────────────────────────────────────────────────────────────────────

function D:BuildSnapshotText(title)
    local lines = { string_format("SNAPSHOT: %s", title or "manual") }
    lines[#lines + 1] = string_format("  fps=%.1f (min %.1f)  entries=%d  info=%d warn=%d error=%d",
        self.fps, self.fps_min, self.seq, self.level_counts[2], self.level_counts[3], self.level_counts[4])
    for _, w in ipairs(self:EvalWatchers(true)) do
        lines[#lines + 1] = string_format("  watch %-14s = %s", w.name, w.value)
    end

    local hooks = {}
    for key, st in pairs(self.hook_stats) do hooks[#hooks + 1] = { key = key, st = st } end
    table.sort(hooks, function(a, b) return a.st.total > b.st.total end)
    lines[#lines + 1] = "  hooks (by total time):"
    for i = 1, math.min(15, #hooks) do
        local h = hooks[i]
        lines[#lines + 1] = string_format("    %-48s calls=%-8d total=%.1fms max=%.2fms err=%d",
            h.key, h.st.calls, h.st.total * 1000, h.st.max * 1000, h.st.errors)
    end

    local cnt = {}
    for k, v in pairs(self.counters) do cnt[#cnt + 1] = { k = k, v = v } end
    table.sort(cnt, function(a, b) return a.v > b.v end)
    if #cnt > 0 then
        lines[#lines + 1] = "  counters:"
        for i = 1, math.min(20, #cnt) do
            lines[#lines + 1] = string_format("    %-48s %d", cnt[i].k, cnt[i].v)
        end
    end

    local errs = {}
    for k, v in pairs(self.err_seen) do errs[#errs + 1] = { k = k, v = v } end
    table.sort(errs, function(a, b) return a.v > b.v end)
    if #errs > 0 then
        lines[#lines + 1] = "  error sources:"
        for i = 1, math.min(15, #errs) do
            lines[#lines + 1] = string_format("    %-48s x%d", errs[i].k, errs[i].v)
        end
    end
    return table.concat(lines, "\n")
end

function D:Snapshot(title)
    self:Add(self.LEVEL_INFO, "snapshot", self:BuildSnapshotText(title))
    self:Flush()
end

-- ─── Sampler (FPS, state changes, hook rates, file flush) ───────────────────────────────────────

D._acc, D._frames, D._max_dt = 0, 0, 0
D._last = {}

local function sample_state()
    local cur = {
        state = game_state_machine and game_state_machine:current_state_name() or "?",
        role  = Network and (Network:is_server() and "HOST" or (Network:is_client() and "CLIENT" or "?")) or "?",
        level = tostring(NiceTrainer:GetCurrentLevelId()),
    }
    for k, v in pairs(cur) do
        if D._last[k] ~= nil and D._last[k] ~= v then
            D:Info("state", "%s changed: %s -> %s", k, tostring(D._last[k]), tostring(v))
        end
        D._last[k] = v
    end
end

function D:OnUpdate(t, dt)
    self._wrap_on = self:Opt("debug_wrap_hooks", true)
    if not self:Enabled() then return end
    self.dt = dt
    self._frames = self._frames + 1
    self._acc = self._acc + dt
    if dt > self._max_dt then self._max_dt = dt end

    if dt > 0.25 and (os_clock() - (self._last_spike or -10)) > 2 then
        self._last_spike = os_clock()
        self:Warn("perf", "Frame spike: %.0f ms", dt * 1000)
    end

    if self._acc >= 1 then
        self.fps = self._frames / self._acc
        self.fps_min = self._max_dt > 0 and (1 / self._max_dt) or self.fps
        for _, st in pairs(self.hook_stats) do
            st.rate = st.win * 1000 / self._acc -- ms of CPU per second of wall time
            st.win = 0
        end
        self._acc, self._frames, self._max_dt = 0, 0, 0
        pcall(sample_state)
        self:Flush()
    end
end

if Hooks and Hooks.Add then
    Hooks:Add("GameSetupUpdate", "NiceTrainer_Debug_Update", function(t, dt) D:OnUpdate(t, dt) end)
    Hooks:Add("MenuUpdate", "NiceTrainer_Debug_UpdateMenu", function(t, dt) D:OnUpdate(t, dt) end)
    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Debug_SessionLoad", function()
        D:Snapshot("session loaded")
    end)
end

-- ─── Boot ───────────────────────────────────────────────────────────────────────────────────────

D:_rotate_session()
D:Info("debug", "Debug system started (log: %s)", D.file_path)
