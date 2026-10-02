-- ─── Skills & Perk Decks Actions for NiceTrainer ─────────────────────────────

-- ============================================================================
-- 1. Set Custom Skill Points
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Skills & Perk Decks",
    badge           = "client",
    no_bind         = true,
    id              = "set_skill_points",
    text            = "Set Custom Skill Points",
    tooltip         = "Sets your unspent skill points count.",
    min             = 0,
    max             = 1000,
    default         = 120,
    action_btn_text = "Set",
    callback        = function(value)
        if managers.skilltree and managers.skilltree._set_points then
            managers.skilltree:_set_points(value)
            NiceTrainer:Toast("Skill Points set to: " .. tostring(value))
        end
    end
})

-- ============================================================================
-- 2. Unlock All Skill Tree Tiers
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Skills & Perk Decks",
    badge           = "client",
    no_bind         = true,
    id              = "unlock_skill_tiers",
    text            = "Unlock All Skill Tree Tiers",
    tooltip         = "Bypasses tier point requirements, making all tier rows in Mastermind, Enforcer, Tech, Ghost, and Fugitive immediately accessible.",
    action_btn_text = "Unlock Tiers",
    callback        = function()
        if not (Global.skilltree_manager and Global.skilltree_manager.trees) then
            NiceTrainer:Toast("Skill trees not loaded.")
            return
        end
        for _, data in pairs(Global.skilltree_manager.trees) do
            data.unlocked = true
        end
        if SkillTreeManager then
            function SkillTreeManager:tier_unlocked() return true end
        end
        NiceTrainer:Toast("All Skill Tree tiers unlocked!")
    end
})

-- ============================================================================
-- 3. Set Perk Deck Points
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Skills & Perk Decks",
    badge           = "client",
    no_bind         = true,
    id              = "set_perk_points",
    text            = "Set Perk Deck Points",
    tooltip         = "Sets your available perk deck conversion points (260,300 is enough to max all decks).",
    min             = 0,
    max             = 500000,
    default         = 260300,
    action_btn_text = "Set",
    callback        = function(value)
        local skilltree = managers.skilltree
        local specs = skilltree and skilltree._global and skilltree._global.specializations
        if specs and skilltree.digest_value then
            specs.total_points = skilltree:digest_value(value, true)
            specs.points = skilltree:digest_value(value, true)
            specs.points_present = skilltree:digest_value(value, true)
            NiceTrainer:Toast("Perk Deck Points set to: " .. tostring(value))
        elseif Global.skilltree_manager and Global.skilltree_manager.specializations then
            local g_specs = Global.skilltree_manager.specializations
            g_specs.total_points = value
            g_specs.points = value
            NiceTrainer:Toast("Perk Deck Points set to: " .. tostring(value))
        end
    end
})

-- ============================================================================
-- 4. Unlock & Max All Perk Decks
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Skills & Perk Decks",
    badge           = "client",
    no_bind         = true,
    id              = "max_all_perk_decks",
    text            = "Unlock & Max All Perk Decks",
    tooltip         = "Spends required points across every Perk Deck specialization, unlocking all 9 cards for each deck.",
    action_btn_text = "Max Decks",
    callback        = function()
        local skilltree = managers.skilltree
        local specs = skilltree and skilltree._global and skilltree._global.specializations
        local g_specs = Global.skilltree_manager and Global.skilltree_manager.specializations

        local total_needed = 260300
        if specs and skilltree.digest_value then
            specs.total_points = skilltree:digest_value(total_needed, true)
            specs.points = skilltree:digest_value(total_needed, true)
            specs.points_present = skilltree:digest_value(total_needed, true)
        end
        if g_specs then
            g_specs.total_points = total_needed
            g_specs.points = total_needed
            for spec, _ in pairs(g_specs) do
                if type(spec) == "number" then
                    pcall(function() skilltree:spend_specialization_points(13700, spec) end)
                end
            end
        end
        NiceTrainer:Toast("All Perk Decks maxed out (9/9 cards)!")
    end
})

-- ============================================================================
-- 5. Activate All Perk Passives Simultaneously (Silent All Perks)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Skills & Perk Decks",
    badge           = "client",
    no_bind         = true,
    id              = "apply_all_perk_passives",
    text            = "Activate All Perk Passives Simultaneously",
    tooltip         = "Acquires the passive bonuses of every Perk Deck simultaneously in memory for the current session without altering your saved build.",
    action_btn_text = "Activate",
    callback        = function()
        local specializations = tweak_data and tweak_data.skilltree and tweak_data.skilltree.specializations
        if not (specializations and managers.upgrades) then
            NiceTrainer:Toast("Perk data unavailable.")
            return
        end

        local count = 0
        for _, specialization in pairs(specializations) do
            for _, tier in pairs(specialization) do
                if type(tier) == "table" and tier.upgrades then
                    for _, upgrade in ipairs(tier.upgrades) do
                        pcall(function()
                            managers.upgrades:aquire(upgrade, false)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Activated %d Perk Deck upgrades simultaneously!", count))
    end
})

-- ============================================================================
-- 6. Reset Specializations / Perk Decks
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Skills & Perk Decks",
    badge           = "risk",
    no_bind         = true,
    id              = "reset_perk_decks",
    text            = "Reset All Perk Decks",
    tooltip         = "Resets all spent cards in your Perk Deck specializations back to zero.",
    action_btn_text = "Reset",
    callback        = function()
        NiceTrainer:ShowConfirmDialog(
            "Confirm Reset Perk Decks",
            "Are you sure you want to reset all Perk Decks?\n\nAll specialization points will be refunded or reset.",
            {
                {
                    text = "Yes, Reset Perk Decks",
                    color = Color(0.9, 0.35, 0.35),
                    callback = function()
                        if managers.skilltree and managers.skilltree.reset_specializations then
                            managers.skilltree:reset_specializations()
                            NiceTrainer:Toast("All Perk Decks have been reset.")
                        end
                    end
                },
                {
                    text = "Cancel",
                    color = Color(0.6, 0.6, 0.6),
                    callback = function() end
                }
            }
        )
    end
})
