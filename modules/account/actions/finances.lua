-- ─── Finances & Currencies Actions for NiceTrainer ────────────────────────────

-- ============================================================================
-- 1. Add Spending Cash (Presets)
-- ============================================================================
local SPENDING_PRESETS = {
    { label = "+$1,000,000",                val = 1000000 },
    { label = "+$5,000,000",                val = 5000000 },
    { label = "+$10,000,000",               val = 10000000 },
    { label = "+$50,000,000",               val = 50000000 },
    { label = "+$100,000,000",              val = 100000000 },
    { label = "+$1,000,000,000 (1 Billion)",val = 1000000000 },
    { label = "+$10,000,000,000 (10 Billion)",val = 10000000000 },
}

local spending_preset_labels = {}
for _, item in ipairs(SPENDING_PRESETS) do table.insert(spending_preset_labels, item.label) end

NiceTrainer:RegisterAction("Account", {
    type            = "multichoice",
    category        = "Finances & Currencies",
    badge           = "client",
    no_bind         = true,
    id              = "add_spending_preset",
    text            = "Add Spending Cash (Presets)",
    tooltip         = "Select a spending cash amount to add to your account.",
    options         = spending_preset_labels,
    default         = 3,
    action_btn_text = "Add Cash",
    callback        = function(idx, label)
        local item = SPENDING_PRESETS[idx]
        if item and managers.money then
            managers.money:add_to_spending(item.val)
            NiceTrainer:Toast("Added " .. item.label .. " spending cash!")
        end
    end
})

-- ============================================================================
-- 2. Custom Spending Cash Input
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Finances & Currencies",
    badge           = "client",
    no_bind         = true,
    id              = "custom_spending_cash",
    text            = "Custom Spending Cash",
    tooltip         = "Enter an exact amount of spending cash to add.",
    min             = 1000,
    max             = 999999999999,
    default         = 50000000,
    action_btn_text = "Add",
    callback        = function(value)
        if managers.money then
            managers.money:add_to_spending(value)
            NiceTrainer:Toast("Added +$" .. tostring(value) .. " spending cash!")
        end
    end
})

-- ============================================================================
-- 3. Add Offshore Cash (Presets)
-- ============================================================================
local OFFSHORE_PRESETS = {
    { label = "+$10,000,000",                 val = 10000000 },
    { label = "+$50,000,000",                 val = 50000000 },
    { label = "+$100,000,000",                val = 100000000 },
    { label = "+$500,000,000",                val = 500000000 },
    { label = "+$1,000,000,000 (1 Billion)",  val = 1000000000 },
    { label = "+$10,000,000,000 (10 Billion)",val = 10000000000 },
    { label = "+$100,000,000,000 (100 Billion)",val = 100000000000 }
}

local offshore_preset_labels = {}
for _, item in ipairs(OFFSHORE_PRESETS) do table.insert(offshore_preset_labels, item.label) end

NiceTrainer:RegisterAction("Account", {
    type            = "multichoice",
    category        = "Finances & Currencies",
    badge           = "client",
    no_bind         = true,
    id              = "add_offshore_preset",
    text            = "Add Offshore Cash (Presets)",
    tooltip         = "Select an offshore cash amount to add to your offshore vault.",
    options         = offshore_preset_labels,
    default         = 3,
    action_btn_text = "Add Offshore",
    callback        = function(idx, label)
        local item = OFFSHORE_PRESETS[idx]
        if item and managers.money then
            managers.money:add_to_offshore(item.val)
            NiceTrainer:Toast("Added " .. item.label .. " offshore cash!")
        end
    end
})

-- ============================================================================
-- 4. Custom Offshore Cash Input
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Finances & Currencies",
    badge           = "client",
    no_bind         = true,
    id              = "custom_offshore_cash",
    text            = "Custom Offshore Cash",
    tooltip         = "Enter an exact amount of offshore cash to add.",
    min             = 1000,
    max             = 999999999999,
    default         = 500000000,
    action_btn_text = "Add",
    callback        = function(value)
        if managers.money then
            managers.money:add_to_offshore(value)
            NiceTrainer:Toast("Added +$" .. tostring(value) .. " offshore cash!")
        end
    end
})

-- ============================================================================
-- 5. Reset All Money (with Confirm Dialog)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Finances & Currencies",
    badge           = "risk",
    no_bind         = true,
    id              = "reset_money",
    text            = "Reset All Money",
    tooltip         = "Resets both spending and offshore cash balances to $0.",
    action_btn_text = "Reset",
    callback        = function()
        NiceTrainer:ShowConfirmDialog(
            "Confirm Reset Finances",
            "Are you sure you want to reset all spending and offshore money to $0?\n\nThis will zero out your wallet and offshore account.",
            {
                {
                    text = "Yes, Reset All Money",
                    color = Color(0.9, 0.35, 0.35),
                    callback = function()
                        if managers.money then managers.money:reset() end
                        NiceTrainer:Toast("Finances reset to $0.")
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
