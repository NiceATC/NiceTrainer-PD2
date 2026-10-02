-- ─── Account Module Init ───────────────────────────────────────────────────────
-- Loads all actions and registers the Account tab.

-- 1. Identity & Anti-Cheat
dofile(NiceTrainer.ModPath .. "modules/account/actions/name_spoof.lua")
dofile(NiceTrainer.ModPath .. "modules/account/actions/anticheat_audit.lua")

-- 2. Unlockers & Protection
dofile(NiceTrainer.ModPath .. "modules/account/actions/dlc_unlocker.lua")
dofile(NiceTrainer.ModPath .. "modules/account/actions/skin_unlocker.lua")
dofile(NiceTrainer.ModPath .. "modules/account/actions/skills_unlocker.lua")
dofile(NiceTrainer.ModPath .. "modules/account/actions/inventory_unlockers.lua")

-- 3. Progression & Experience
dofile(NiceTrainer.ModPath .. "modules/account/actions/progression.lua")

-- 4. Finances & Currencies
dofile(NiceTrainer.ModPath .. "modules/account/actions/finances.lua")

-- 5. Continental Coins & Safehouse
dofile(NiceTrainer.ModPath .. "modules/account/actions/safehouse.lua")

-- 6. Skills & Perk Decks
dofile(NiceTrainer.ModPath .. "modules/account/actions/skills_perks.lua")

-- 7. Black Market & Inventory
dofile(NiceTrainer.ModPath .. "modules/account/actions/blackmarket.lua")

-- 8. Achievements
dofile(NiceTrainer.ModPath .. "modules/account/actions/achievements.lua")

-- 9. Crime Spree
dofile(NiceTrainer.ModPath .. "modules/account/actions/crimespree.lua")

-- Tab Definition
dofile(NiceTrainer.ModPath .. "modules/account/tab.lua")
