dofile(NiceTrainer.ModPath .. "modules/settings/actions/configuration.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/actions/anticheat.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/actions/mod_hider.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/actions/anticrash.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/actions/theme.lua")
-- Debug system
dofile(NiceTrainer.ModPath .. "modules/settings/actions/debug_core.lua")
if NiceTrainer.Debug and NiceTrainer.Debug.WrapRegistry then NiceTrainer.Debug:WrapRegistry() end
dofile(NiceTrainer.ModPath .. "modules/settings/actions/debug_panel.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/actions/debug_actions.lua")
dofile(NiceTrainer.ModPath .. "modules/settings/tab.lua")
