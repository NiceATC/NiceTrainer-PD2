NiceTrainer.SavePath = SavePath .. "NiceTrainer.json"
NiceTrainer.LegacySavePath = SavePath .. "NiceTrainer.txt"
NiceTrainer.Settings = NiceTrainer.Settings or {}
NiceTrainer._non_persistent_keys = NiceTrainer._non_persistent_keys or {}
NiceTrainer.NonPersistentActions = NiceTrainer.NonPersistentActions or {}

local function format_json_val(val, indent, level)
    local v_type = type(val)
    if v_type == "string" then
        return string.format("%q", val):gsub("\\\n", "\\n")
    elseif v_type == "number" or v_type == "boolean" then
        return tostring(val)
    elseif v_type == "table" then
        local is_array = true
        local max_idx = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                is_array = false
            else
                if k > max_idx then max_idx = k end
            end
        end
        if count == 0 then return "{}" end
        if is_array and max_idx == count then
            local items = {}
            for i = 1, count do
                table.insert(items, format_json_val(val[i], indent, level + 1))
            end
            local pad = string.rep(indent, level + 1)
            local end_pad = string.rep(indent, level)
            return "[\n" .. pad .. table.concat(items, ",\n" .. pad) .. "\n" .. end_pad .. "]"
        else
            local keys = {}
            for k in pairs(val) do table.insert(keys, tostring(k)) end
            table.sort(keys)
            local items = {}
            local pad = string.rep(indent, level + 1)
            local end_pad = string.rep(indent, level)
            for _, k in ipairs(keys) do
                local v = val[k]
                local formatted_v = format_json_val(v, indent, level + 1)
                table.insert(items, string.format("%q: %s", k, formatted_v))
            end
            return "{\n" .. pad .. table.concat(items, ",\n" .. pad) .. "\n" .. end_pad .. "}"
        end
    end
    return "null"
end

function NiceTrainer:FormatJSON(tbl)
    return format_json_val(tbl or {}, "  ", 0) .. "\n"
end

function NiceTrainer:RegisterNonPersistent(id, default_val, callback_func)
    if not id then return end
    self._non_persistent_keys[id] = true
    self.NonPersistentActions[id] = {
        default = default_val ~= nil and default_val or false,
        callback = callback_func
    }
end

function NiceTrainer:ResetSessionActions()
    for id, act in pairs(self.NonPersistentActions or {}) do
        local old_val = self.Settings[id]
        local def = act.default
        self.Settings[id] = def
        if self._toggle_elements and self._toggle_elements[id] then
            self._toggle_elements[id](def)
        end
        if old_val ~= def and act.callback then
            pcall(act.callback, def)
        end
    end
end

function NiceTrainer:Save()
    local to_save = {}
    for k, v in pairs(self.Settings or {}) do
        if not self._non_persistent_keys[k] then
            to_save[k] = v
        end
    end
    
    local formatted = self:FormatJSON(to_save)
    local file = io.open(self.SavePath, "w+")
    if file then
        file:write(formatted)
        file:close()
    elseif io.save_as_json then
        io.save_as_json(to_save, self.SavePath)
    end
end

function NiceTrainer:Load()
    local path = self.SavePath
    if not (io.file_is_readable and io.file_is_readable(path)) and (io.file_is_readable and io.file_is_readable(self.LegacySavePath)) then
        path = self.LegacySavePath
    end

    if io.load_as_json and io.file_is_readable and io.file_is_readable(path) then
        self.Settings = io.load_as_json(path) or {}
    else
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local s, res = pcall(json.decode, data)
            self.Settings = (s and type(res) == "table") and res or {}
            file:close()
        else
            self.Settings = {}
        end
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ResetSessionActions_Hook", function()
    NiceTrainer:ResetSessionActions()
end)

function NiceTrainer:GetAccentColor()
    local hex = self.Settings and self.Settings.menu_accent_color
    if type(hex) == "string" and hex:sub(1, 1) == "#" and #hex == 7 then
        local r = tonumber(hex:sub(2, 3), 16) / 255
        local g = tonumber(hex:sub(4, 5), 16) / 255
        local b = tonumber(hex:sub(6, 7), 16) / 255
        return Color(r, g, b)
    elseif type(hex) == "userdata" then
        return hex
    end
    return Color(0.2, 0.6, 1.0)
end

function NiceTrainer:GetAccentColorHex()
    return self.Settings and self.Settings.menu_accent_color or "#3399FF"
end

function NiceTrainer:SafeCall(func, ...)
    if type(func) ~= "function" then return end
    local success, err = pcall(func, ...)
    if not success then
        log("[NiceTrainer ERROR] Callback failed: " .. tostring(err))
        if self.Toast then
            self:Toast("Error in script! Check BLT logs.", Color.red)
        end
    end
end

function NiceTrainer:LoadAddons()
    local addons_dir = self.ModPath .. "addons/"
    
    -- Ensure addons directory exists
    if file and file.DirectoryExists and not file.DirectoryExists(addons_dir) then
        if SystemFS and SystemFS.make_dir then
            pcall(SystemFS.make_dir, SystemFS, addons_dir)
        end
    end

    if not file or not file.GetFiles then return end

    -- 1. Load standalone lua scripts directly inside addons/ (e.g. addons/my_addon.lua)
    local files = file.GetFiles(addons_dir)
    if files then
        table.sort(files)
        for _, fname in ipairs(files) do
            if fname:sub(-4):lower() == ".lua" then
                local file_path = addons_dir .. fname
                log("[NiceTrainer] [Addon] Loading script: " .. fname)
                local success, err = pcall(dofile, file_path)
                if not success then
                    log("[NiceTrainer ERROR] [Addon] Failed to load " .. fname .. ": " .. tostring(err))
                end
            end
        end
    end

    -- 2. Load folder-based addons inside addons/ (e.g. addons/my_addon/init.lua)
    local dirs = file.GetDirectories and file.GetDirectories(addons_dir)
    if dirs then
        table.sort(dirs)
        local entrypoints = { "init.lua", "main.lua", "addon.lua" }
        for _, dname in ipairs(dirs) do
            local folder_path = addons_dir .. dname .. "/"
            for _, ep in ipairs(entrypoints) do
                local ep_path = folder_path .. ep
                if io.file_is_readable(ep_path) then
                    log("[NiceTrainer] [Addon] Loading folder addon: " .. dname .. " (" .. ep .. ")")
                    local success, err = pcall(dofile, ep_path)
                    if not success then
                        log("[NiceTrainer ERROR] [Addon] Failed to load " .. dname .. "/" .. ep .. ": " .. tostring(err))
                    end
                    break
                end
            end
        end
    end
end

function NiceTrainer:IsInHeist()
    if not game_state_machine then return false end
    local state = game_state_machine:current_state_name()
    if state == "ingame_waiting_for_players" then return false end
    
    if Utils and Utils.IsInGameState then return Utils:IsInGameState() end
    return state ~= "menu_main" and state ~= "empty"
end

function NiceTrainer:IsInMenu()
    if Utils and Utils.IsInGameState then return not Utils:IsInGameState() end
    if not game_state_machine then return true end
    return game_state_machine:current_state_name() == "menu_main"
end

function NiceTrainer:IsInPrePlanning()
    if not game_state_machine then return false end
    return game_state_machine:current_state_name() == "ingame_waiting_for_players"
end

function NiceTrainer:IsHost()
    if not Network then return false end
    return Network:is_server()
end

function NiceTrainer:IsClient()
    if not Network then return false end
    return Network:is_client()
end

function NiceTrainer:GetCurrentLevelId()
    if Global.game_settings and Global.game_settings.level_id and Global.game_settings.level_id ~= "" then
        return Global.game_settings.level_id
    end
    if Global.level_data and Global.level_data.level_id and Global.level_data.level_id ~= "" then
        return Global.level_data.level_id
    end
    if managers.job and managers.job.current_level_id then
        local ok, lid = pcall(function() return managers.job:current_level_id() end)
        if ok and lid and lid ~= "" then return lid end
    end
    if managers.job and managers.job.current_job_id then
        local ok, jid = pcall(function() return managers.job:current_job_id() end)
        if ok and jid and jid ~= "" then return jid end
    end
    if managers.job and managers.job.current_real_job_id then
        local ok, rjid = pcall(function() return managers.job:current_real_job_id() end)
        if ok and rjid and rjid ~= "" then return rjid end
    end
    if Global.job_manager and Global.job_manager.current_job and Global.job_manager.current_job.job_id then
        return Global.job_manager.current_job.job_id
    end
    return nil
end

DelayedCalls:Add("NiceTrainer_AutoInit", 2, function()
    if managers.gui_data then
        NiceTrainer:InitUI()
    end
end)


function NiceTrainer:GetUnitInfo(unit)
    if not alive(unit) then return nil end
    local info = { unit = unit, id = unit:id() }
    local u_base = unit:base() or {}
    
    if u_base.is_local_player or u_base.is_husk_player then
        info.type = u_base.is_local_player and "local_player" or "remote_player"
        local peer = unit.network and unit:network() and unit:network():peer()
        info.name = u_base.is_local_player and (managers.network and managers.network.account and managers.network.account:username() or "Local Player") or (peer and peer:name() or "Unknown")
        local dmg = unit.character_damage and unit:character_damage()
        if dmg then
            if type(dmg.get_real_health) == "function" then
                info.health = dmg:get_real_health()
            elseif type(dmg.health) == "function" then
                info.health = dmg:health()
            elseif dmg._health then
                info.health = dmg._health
            else
                info.health = 0
            end
        else
            info.health = 0
        end
    elseif u_base._tweak_table then
        info.type = "npc"
        local gai_state = managers.groupai and managers.groupai:state()
        if gai_state and gai_state.is_unit_team_AI and gai_state:is_unit_team_AI(unit) then
            info.type = "team_ai"
            info.name = (u_base.nick_name and u_base:nick_name()) or "Team AI"
        elseif gai_state and gai_state._police and gai_state._police[unit:key()] and gai_state._police[unit:key()].is_converted then
            info.type = "joker"
            info.name = u_base.joker_name or "Joker"
        else
            info.name = u_base._tweak_table
        end
    elseif u_base.security_camera then
        info.type = "camera"
        info.name = "Security Camera"
    end
    return info
end
-- Automatically load settings right away so we don't accidentally overwrite them with a blank table
if not NiceTrainer._loaded then
    NiceTrainer:Load()
    NiceTrainer._loaded = true
end

-- F1 Hotkey to open or close the menu
Hooks:Add("MenuUpdate", "NiceTrainer_Toggle_Menu", function(t, dt)
    if Input:keyboard():pressed(Idstring("f1")) then
        NiceTrainer:Toggle()
    end
end)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Toggle_Game", function(t, dt)
    if Input:keyboard():pressed(Idstring("f1")) then
        NiceTrainer:Toggle()
    end
end)

-- First-run disclaimer auto-prompt when entering the main menu
Hooks:Add("MenuUpdate", "NiceTrainer_FirstRun_Notice", function(t, dt)
    if not NiceTrainer._first_run_checked then
        NiceTrainer._first_run_checked = true
        if NiceTrainer.Settings.disclaimer_acknowledged ~= true then
            if DelayedCalls then
                DelayedCalls:Add("NiceTrainer_AutoOpenDisclaimer", 1.0, function()
                    if NiceTrainer.Settings.disclaimer_acknowledged ~= true and not NiceTrainer.IsModalOpen then
                        NiceTrainer:ShowDisclaimerModal()
                    end
                end)
            end
        end
    end
end)


