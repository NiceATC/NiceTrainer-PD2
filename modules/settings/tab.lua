Hooks:Add("NiceTrainer_InitTabs", "NiceTrainer_SettingsTab", function(trainer)
    trainer:CreateTab("Settings", { show_in = "menu" }, function(tr, name)
        tr:BuildRegisteredActions(name)
    end)
    trainer:CreateTab("Debug", { 
        show_in = "all",
        condition = function() return NiceTrainer.Settings.debug_tab_enabled == true end
    }, function(tr, name)
        tr:BuildRegisteredActions(name)
    end)
end)

if NiceTrainer and NiceTrainer.Tabs and NiceTrainer.Tabs["Debug"] then
    NiceTrainer.Tabs["Debug"].options = NiceTrainer.Tabs["Debug"].options or {}
    NiceTrainer.Tabs["Debug"].options.condition = function() return NiceTrainer.Settings.debug_tab_enabled == true end
    if NiceTrainer.RefreshTabsVisibility then NiceTrainer:RefreshTabsVisibility() end
end
