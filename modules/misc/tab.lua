Hooks:Add("NiceTrainer_InitTabs", "NiceTrainer_MiscTab", function(trainer)
    trainer:CreateTab("Miscellaneous", {
        icon = "guis/textures/pd2/skilltree/icons_atlas",
        icon_rect = { 64 * 3, 0, 64, 64 },
        show_in = "menu"
    }, function(tr, name)
        tr:BuildRegisteredActions(name)
    end)
end)
