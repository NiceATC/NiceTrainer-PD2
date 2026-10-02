-- NiceTrainer 1.0.0
-- Initializing Framework

if not _G.NiceTrainer then
    _G.NiceTrainer = {}
    NiceTrainer.IsOpen = false
    NiceTrainer.Tabs = {}
    NiceTrainer.TabsList = {}
    NiceTrainer.Elements = {}
end

if not NiceTrainer.ModPath or NiceTrainer.ModPath == "" or NiceTrainer.ModPath == "mods/base/" then
    NiceTrainer.ModPath = ModPath or "mods/NiceTrainer/"
end

function NiceTrainer:Log(msg)
    log("[NiceTrainer] " .. tostring(msg))
end

dofile(NiceTrainer.ModPath .. "framework/core.lua")
dofile(NiceTrainer.ModPath .. "framework/toast.lua")
dofile(NiceTrainer.ModPath .. "framework/registry.lua")
dofile(NiceTrainer.ModPath .. "framework/components.lua")
dofile(NiceTrainer.ModPath .. "framework/ui.lua")

dofile(NiceTrainer.ModPath .. "modules/preplanning/init.lua")
dofile(NiceTrainer.ModPath .. "modules/player/init.lua")
dofile(NiceTrainer.ModPath .. "modules/visuals/init.lua")
dofile(NiceTrainer.ModPath .. "modules/stealth/init.lua")
dofile(NiceTrainer.ModPath .. "modules/carrystacker/init.lua")
dofile(NiceTrainer.ModPath .. "modules/npc_ai/init.lua")
dofile(NiceTrainer.ModPath .. "modules/spawner/init.lua")
dofile(NiceTrainer.ModPath .. "modules/team/init.lua")
dofile(NiceTrainer.ModPath .. "modules/world/init.lua")
dofile(NiceTrainer.ModPath .. "modules/heist/init.lua")
dofile(NiceTrainer.ModPath .. "modules/account/init.lua")
dofile(NiceTrainer.ModPath .. "modules/misc/init.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/init.lua")

-- Load standalone and folder addons from addons/
if NiceTrainer.LoadAddons then
    NiceTrainer:LoadAddons()
end

