-- Configuration actions for NiceTrainer (Settings Tab)
-- Ported from HexTrainer Extra.lua

NiceTrainer:RegisterAction("Settings", {
    type = "toggle",
    category = "Configuration",
    id = "disable_skills_check",
    text = "Disable Skills Check",
    tooltip = "Prevents the game from removing invalid/illegal skills.",
    default = false,
    callback = function(state)
        if _G.SkillTreeManager then
            if not _G.SkillTreeManager.orig_verify_loaded_data then
                _G.SkillTreeManager.orig_verify_loaded_data = _G.SkillTreeManager._verify_loaded_data
            end
            if state then
                _G.SkillTreeManager._verify_loaded_data = function() end
            else
                _G.SkillTreeManager._verify_loaded_data = _G.SkillTreeManager.orig_verify_loaded_data
            end
        end

    end
})

-- No Drop-in Pause logic
if _G.MenuManager then
    if not _G.MenuManager.orig_show_person_joining then
        _G.MenuManager.orig_show_person_joining = _G.MenuManager.show_person_joining
        _G.MenuManager.orig_close_person_joining = _G.MenuManager.close_person_joining
    end
    
    function MenuManager:show_person_joining(id, nick)
        if NiceTrainer.Settings.no_dropin_pause then
            pcall(function()
                managers.hud:show_hint({text = managers.localization:text("dialog_dropin_title", {USER = nick or "Player"})})
            end)
            return
        end
        return self:orig_show_person_joining(id, nick)
    end
    
    function MenuManager:close_person_joining(id)
        if NiceTrainer.Settings.no_dropin_pause then return end
        return self:orig_close_person_joining(id)
    end
end

if _G.BaseNetworkSession then
    Hooks:PostHook(BaseNetworkSession, "on_drop_in_pause_request_received", "NiceTrainer_NoDropInPause", function()
        if not NiceTrainer.Settings.no_dropin_pause then return end
        pcall(function() Application:set_pause(false) end)
        pcall(function() SoundDevice:set_rtpc("ingame_sound", 1) end)
    end)
end

NiceTrainer:RegisterAction("Settings", {
    type = "toggle",
    category = "Configuration",
    id = "no_dropin_pause",
    no_bind = true,
    badge = "safe",
    text = "No Drop-in Pause",
    tooltip = "Don't pause the game when someone is joining.",
    default = false,
    callback = function(state)

    end
})

NiceTrainer:RegisterAction("Settings", {
    type = "toggle",
    category = "Configuration",
    id = "debug_tab_enabled",
    no_bind = true,
    text = "Show Debug Tab",
    tooltip = "Enables the Debug tab in the trainer menu.",
    default = false,
    save = true,
    callback = function(state)
        if NiceTrainer._debug_tab_state_last == state then return end
        NiceTrainer._debug_tab_state_last = state
        
        NiceTrainer.Settings.debug_tab_enabled = state
        if NiceTrainer.RefreshTabsVisibility then
            NiceTrainer:RefreshTabsVisibility()
        end
    end
})



