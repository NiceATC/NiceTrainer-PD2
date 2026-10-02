-- ─── Achievements Actions for NiceTrainer ────────────────────────────────────

-- ============================================================================
-- 1. Unlock All Achievements
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Achievements",
    badge           = "client",
    no_bind         = true,
    id              = "unlock_all_achievements",
    text            = "Unlock All Achievements",
    tooltip         = "Awards every Steam and in-game achievement in PAYDAY 2.",
    action_btn_text = "Unlock All",
    callback        = function()
        if not (managers.achievment and managers.achievment.achievments) then
            NiceTrainer:Toast("Achievements manager not ready.")
            return
        end
        local count = 0
        for id, data in pairs(managers.achievment.achievments) do
            if not data.awarded then
                pcall(function() managers.achievment:award(id) end)
                count = count + 1
            end
        end
        NiceTrainer:Toast(string.format("Unlocked %d achievements!", count))
    end
})

-- ============================================================================
-- 2. Lock All Achievements
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Achievements",
    badge           = "risk",
    no_bind         = true,
    id              = "lock_all_achievements",
    text            = "Lock All Steam Achievements",
    tooltip         = "Clears and locks all Steam achievements for PAYDAY 2.",
    action_btn_text = "Lock All",
    callback        = function()
        NiceTrainer:ShowConfirmDialog(
            "Confirm Lock Achievements",
            "WARNING: This will reset and lock ALL of your PAYDAY 2 Steam achievements.\n\nAre you sure you want to proceed?",
            {
                {
                    text = "Yes, Relock Achievements",
                    color = Color(0.9, 0.35, 0.35),
                    callback = function()
                        if managers.achievment and managers.achievment.clear_all_steam then
                            managers.achievment:clear_all_steam()
                            NiceTrainer:Toast("All Steam achievements have been relocked.")
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
