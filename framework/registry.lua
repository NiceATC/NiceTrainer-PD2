NiceTrainer.Actions = {}

function NiceTrainer:RegisterAction(tab_name, action_def)
    if not self.Actions[tab_name] then self.Actions[tab_name] = {} end
    table.insert(self.Actions[tab_name], action_def)

    if action_def and action_def.save == false and action_def.id then
        self:RegisterNonPersistent(action_def.id, action_def.default, action_def.callback)
    end
end

function NiceTrainer:BuildRegisteredActions(tab_name)
    local last_category = nil
    local current_level = self:GetCurrentLevelId()
    
    local all_actions = self.Actions[tab_name] or {}
    local prioritized_actions = {}
    local general_actions = {}

    for _, action in ipairs(all_actions) do
        local should_build = true
        local is_level_specific = false
        if action.level_id then
            if not current_level then
                should_build = false
            else
                local match = false
                local cur = string.lower(tostring(current_level))
                if type(action.level_id) == "table" then
                    for _, lid in ipairs(action.level_id) do
                        local s_lid = string.lower(tostring(lid))
                        if cur == s_lid or cur:find(s_lid, 1, true) or s_lid:find(cur, 1, true) then
                            match = true
                            break
                        end
                    end
                else
                    local s_lid = string.lower(tostring(action.level_id))
                    if cur == s_lid or cur:find(s_lid, 1, true) or s_lid:find(cur, 1, true) then
                        match = true
                    end
                end
                if match then
                    is_level_specific = true
                else
                    should_build = false
                end
            end
        end

        if should_build and action.check_available and type(action.check_available) == "function" then
            pcall(function()
                if not action.check_available() then
                    should_build = false
                end
            end)
        end

        if should_build then
            if is_level_specific then
                table.insert(prioritized_actions, action)
            else
                table.insert(general_actions, action)
            end
        end
    end

    -- Build map-specific actions first, then general actions
    local actions_to_render = {}
    for _, act in ipairs(prioritized_actions) do table.insert(actions_to_render, act) end
    for _, act in ipairs(general_actions) do table.insert(actions_to_render, act) end

    for _, action in ipairs(actions_to_render) do
        if action.category and action.category ~= last_category then
            self:AddHeader(tab_name, action.category)
            last_category = action.category
        end
        
        local display_text = action.text
        NiceTrainer.CurrentBadge = action.badge
        NiceTrainer.CurrentNoBind = action.no_bind
        NiceTrainer.CurrentSave = action.save
        
        if action.type == "button" then
            self:AddButton(tab_name, action.id or display_text, display_text, action.tooltip, action.callback, action.no_bind, action.action_btn_text)
        elseif action.type == "toggle" then
            self:AddToggle(tab_name, action.id, display_text, action.default, action.tooltip, action.callback, action.no_bind, action.save)
        elseif action.type == "slider" then
            self:AddSlider(tab_name, action.id, display_text, action.min, action.max, action.default, action.tooltip, action.callback, action.save)
        elseif action.type == "multichoice" then
            self:AddMultiChoice(tab_name, action.id, display_text, action.options, action.default, action.action_btn_text, action.tooltip, action.callback, action.save)
        elseif action.type == "inputbox" then
            self:AddNumberInput(tab_name, action.id, display_text, action.min, action.max, action.default, action.action_btn_text, action.tooltip, action.callback, action.save)
        elseif action.type == "modal" then
            self:AddModalButton(tab_name, action.id, display_text, action.modal_title, action.options, action.action_btn_text, action.tooltip, action.callback)
        elseif action.type == "colorpicker" then
            self:AddColorPicker(tab_name, action.id, display_text, action.default, action.tooltip, action.callback, action.save)
        elseif action.type == "toggle_settings" then
            self:AddToggleWithSettings(tab_name, action.id, display_text, action.default, action.tooltip, action.callback, action.settings_callback, action.no_bind, action.save)
        elseif action.type == "toggle_multichoice" or action.type == "toggle_choice" then
            self:AddToggleMultiChoice(tab_name, action.id, display_text, action.default, action.options, action.choice_default or action.default_idx or action.default_choice, action.choice_id, action.tooltip, action.callback, action.choice_callback, action.no_bind, action.save)
        elseif action.type == "toggle_slider" then
            self:AddToggleSlider(tab_name, action.id, display_text, action.default, action.min, action.max, action.slider_default or action.default_val or action.min, action.slider_id, action.tooltip, action.callback, action.slider_callback, action.no_bind, action.save)
        elseif action.type == "keybind" then
            self:AddKeybind(tab_name, action.id, display_text, action.default, action.tooltip, action.callback)
        end
    end
end
