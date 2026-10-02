-- ─── Crime Spree Actions for NiceTrainer ────────────────────────────────────

-- ============================================================================
-- 1. Set Crime Spree Level
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Crime Spree",
    badge           = "client",
    no_bind         = true,
    id              = "set_crimespree_level",
    text            = "Set Crime Spree Level",
    tooltip         = "Sets your current active Crime Spree level.",
    min             = 0,
    max             = 100000000,
    default         = 1000,
    action_btn_text = "Set Level",
    callback        = function(value)
        if managers.crime_spree and managers.crime_spree._global then
            managers.crime_spree._global.spree_level = value
            NiceTrainer:Toast("Crime Spree Level set to: " .. tostring(value))
        elseif CrimeSpreeManager then
            function CrimeSpreeManager:spree_level()
                return self:in_progress() and value or -1
            end
            NiceTrainer:Toast("Crime Spree Level set to: " .. tostring(value))
        else
            NiceTrainer:Toast("Crime Spree manager not active.")
        end
    end
})

-- ============================================================================
-- 2. Set Crime Spree Reward Level
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Crime Spree",
    badge           = "client",
    no_bind         = true,
    id              = "set_crimespree_reward_level",
    text            = "Set Crime Spree Reward Level",
    tooltip         = "Sets your accumulated Crime Spree reward level for claiming cards, continental coins, and loot.",
    min             = 0,
    max             = 100000000,
    default         = 1000,
    action_btn_text = "Set Rewards",
    callback        = function(value)
        if managers.crime_spree and managers.crime_spree._global then
            managers.crime_spree._global.reward_level = value
            NiceTrainer:Toast("Crime Spree Reward Level set to: " .. tostring(value))
        elseif CrimeSpreeManager then
            function CrimeSpreeManager:reward_level()
                return self:in_progress() and value or -1
            end
            NiceTrainer:Toast("Crime Spree Reward Level set to: " .. tostring(value))
        else
            NiceTrainer:Toast("Crime Spree manager not active.")
        end
    end
})

-- ============================================================================
-- 3. Crime Spree Bonus Multiplier
-- ============================================================================
local SPREE_BONUSES = {
    { label = "Default (+0%)",          val = 0 },
    { label = "+100% Bonus",            val = 100 },
    { label = "+500% Bonus",            val = 500 },
    { label = "+1,000% Bonus",          val = 1000 },
    { label = "+10,000% Bonus",         val = 10000 },
    { label = "+100,000% Mega Boost",   val = 100000 },
}

local spree_labels = {}
for _, item in ipairs(SPREE_BONUSES) do table.insert(spree_labels, item.label) end

NiceTrainer:RegisterAction("Account", {
    type            = "multichoice",
    category        = "Crime Spree",
    badge           = "client",
    no_bind         = true,
    id              = "crimespree_bonus_multiplier",
    text            = "Crime Spree Bonus Multipliers",
    tooltip         = "Boosts the catchup and winning streak reward multipliers for high payout upon finishing sprees.",
    options         = spree_labels,
    default         = 1,
    action_btn_text = "Apply Bonus",
    callback        = function(idx, label)
        local item = SPREE_BONUSES[idx]
        if item and CrimeSpreeManager then
            local bval = item.val
            function CrimeSpreeManager:catchup_bonus()
                return math.floor(bval)
            end
            function CrimeSpreeManager:winning_streak_bonus()
                return math.floor(bval)
            end
            NiceTrainer:Toast("Crime Spree bonus multiplier applied: " .. item.label)
        end
    end
})
