local path = (NiceTrainer and NiceTrainer.ModPath) or ModPath or "mods/NiceTrainer/"
dofile(path .. "modules/player/actions/modernmovement/restoration_detector.lua")

if ModernMovementCompat:is_restoration_installed() then
	dofile(path .. "modules/player/actions/modernmovement/advmov_core.lua")
	dofile(path .. "modules/player/actions/modernmovement/advmov_playerstandard.lua")
	dofile(path .. "modules/player/actions/modernmovement/advmov_restoration_pd3_layer.lua")
else
	dofile(path .. "modules/player/actions/modernmovement/playerstandard.lua")
end

