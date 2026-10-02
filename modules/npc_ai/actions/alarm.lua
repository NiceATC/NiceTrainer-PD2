-- Alarm Control for NPC AI Tab

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

local function applyBlockAlarm(enabled)
    if not _G.GroupAIStateBase then return end
    if enabled then
        hijack("GroupAIStateBase", "on_police_called", function() end)
    else
        restore("GroupAIStateBase", "on_police_called")
    end
end

NiceTrainer:RegisterAction("NPC AI", {
    type     = "toggle",
    category = "Alarm",
    badge    = "host",
    id       = "prevent_alarm",
    text     = "Block Alarm",
    tooltip  = "Prevents the police from being called / alarm from triggering.",
    default  = false,
    callback = applyBlockAlarm,
})

NiceTrainer:RegisterAction("NPC AI", {
    type     = "button",
    category = "Alarm",
    badge    = "client",
    text     = "Trigger Alarm",
    tooltip  = "Immediately calls the police and starts the assault (works as host and client).",
    callback = function()
        if not NiceTrainer:IsInHeist() then NiceTrainer:Toast("Only in heist!"); return end
        if Network:is_server() then
            pcall(function() managers.groupai:state():on_police_called("empty") end)
        else
            -- Client: Trigger camera alarm event or group AI alert
            pcall(function()
                for _, u in pairs(World:find_units_quick("all", 1)) do
                    if alive(u) and u:base() and u:base()._send_net_event and u:base()._NET_EVENTS then
                        u:base():_send_net_event(u:base()._NET_EVENTS.alarm_start)
                        break
                    end
                end
                managers.groupai:state():on_police_called("empty")
            end)
        end
        NiceTrainer:Toast("Alarm triggered!")
    end,
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NPCAI_Alarm_Load", function()
    if NiceTrainer.Settings.prevent_alarm then
        applyBlockAlarm(true)
    end
end)
