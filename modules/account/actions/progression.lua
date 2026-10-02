-- ─── Progression & Level Actions for NiceTrainer ─────────────────────────────

-- ============================================================================
-- 1. Set Level (0-100)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "set_level",
    text            = "Set Player Level",
    tooltip         = "Sets your current reputation level (0-100) without altering your Infamy rank.",
    min             = 0,
    max             = 100,
    default         = 100,
    action_btn_text = "Set",
    callback        = function(value)
        if not managers.experience then return end
        local rank = 0
        pcall(function() rank = managers.experience:current_rank() end)
        managers.experience:reset()
        local ok = pcall(function() managers.experience:_set_current_level(value) end)
        if not ok then
            pcall(function() managers.experience:set_current_level(value) end)
        end
        pcall(function() managers.experience:set_current_rank(rank) end)
        NiceTrainer:Toast("Reputation Level set to: " .. tostring(value))
    end
})

-- ============================================================================
-- 2. Set Infamy Rank (0-500)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "set_infamy",
    text            = "Set Infamy Rank",
    tooltip         = "Sets your Infamy rank (0-500).",
    min             = 0,
    max             = 500,
    default         = 100,
    action_btn_text = "Set",
    callback        = function(value)
        if not managers.experience then return end
        pcall(function() managers.experience:set_current_rank(value) end)
        NiceTrainer:Toast("Infamy Rank set to: " .. tostring(value))
    end
})

-- ============================================================================
-- 3. Set Infamy Points
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "set_infamy_points",
    text            = "Set Infamy Skill Points",
    tooltip         = "Sets your unspent Infamy points for unlocking infamy tree rewards.",
    min             = 0,
    max             = 100,
    default         = 25,
    action_btn_text = "Set",
    callback        = function(value)
        if managers.infamy and managers.infamy._set_points then
            managers.infamy:_set_points(value)
            NiceTrainer:Toast("Infamy Points set to: " .. tostring(value))
        elseif managers.infamy and managers.infamy.set_points then
            managers.infamy:set_points(value)
            NiceTrainer:Toast("Infamy Points set to: " .. tostring(value))
        end
    end
})

-- ============================================================================
-- 4. Experience Booster (Presets)
-- ============================================================================
local EXP_PRESETS = {
    { label = "+100,000 XP",                   val = 100000 },
    { label = "+500,000 XP",                   val = 500000 },
    { label = "+1,000,000 XP",                 val = 1000000 },
    { label = "+5,000,000 XP",                 val = 5000000 },
    { label = "+23,000,000 XP (Level 100)",    val = 23000000 },
    { label = "+50,000,000 XP",                val = 50000000 }
}

local exp_preset_labels = {}
for _, item in ipairs(EXP_PRESETS) do table.insert(exp_preset_labels, item.label) end

NiceTrainer:RegisterAction("Account", {
    type            = "multichoice",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "add_exp_preset",
    text            = "Experience Booster",
    tooltip         = "Select an experience amount preset to add to your character.",
    options         = exp_preset_labels,
    default         = 3,
    action_btn_text = "Add XP",
    callback        = function(idx, label)
        local item = EXP_PRESETS[idx]
        if item and managers.experience and managers.experience.debug_add_points then
            managers.experience:debug_add_points(item.val, false)
            NiceTrainer:Toast("Added " .. item.label .. " to character!")
        end
    end
})

-- ============================================================================
-- 5. Custom Experience Input
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "custom_exp_input",
    text            = "Custom Experience Points",
    tooltip         = "Enter an exact amount of experience points to grant.",
    min             = 1000,
    max             = 999999999,
    default         = 1000000,
    action_btn_text = "Add",
    callback        = function(value)
        if managers.experience and managers.experience.debug_add_points then
            managers.experience:debug_add_points(value, false)
            NiceTrainer:Toast("Added +" .. tostring(value) .. " XP!")
        end
    end
})

-- ============================================================================
-- 6. Max Out Level & Infamy 500 Quick-Set
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Progression & Experience",
    badge           = "client",
    no_bind         = true,
    id              = "max_level_infamy",
    text            = "Max Level 100 & Infamy 500",
    tooltip         = "Instantly sets your character to Level 100 and Infamy Rank 500.",
    action_btn_text = "Max Out",
    callback        = function()
        if not managers.experience then return end
        managers.experience:reset()
        pcall(function() managers.experience:_set_current_level(100) end)
        pcall(function() managers.experience:set_current_rank(500) end)
        if managers.infamy and managers.infamy._set_points then
            managers.infamy:_set_points(100)
        end
        NiceTrainer:Toast("Account maxed to Level 100, Infamy 500!")
    end
})
