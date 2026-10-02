function NiceTrainer:FormatKeyDisplay(key)
    if not key or key == "" then return "None" end
    local k = string.lower(tostring(key))
    if k == "mouse 1" or k == "m2" or k == "right" then return "M2 (RIGHT)" end
    if k == "mouse 2" or k == "m3" or k == "middle" or k == "mouse 3" then return "M3 (MID)" end
    if k == "mouse 4" or k == "m4" then return "MOUSE 4" end
    if k == "mouse 5" or k == "m5" then return "MOUSE 5" end
    if k == "mouse 6" or k == "m6" then return "MOUSE 6" end
    if k == "mouse wheel up" or k == "wheel up" then return "WHEEL UP" end
    if k == "mouse wheel down" or k == "wheel down" then return "WHEEL DN" end
    return string.upper(k)
end

function NiceTrainer:AddButton(tab_name, id, btn_text, tooltip, callback_func, no_bind, action_btn_text)
    if type(btn_text) == "function" or btn_text == nil then
        callback_func = tooltip or btn_text
        tooltip = type(btn_text) == "string" and btn_text or nil
        btn_text = id
        id = string.gsub(id, "%s+", "_"):lower()
    end
    if type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if no_bind == nil then
        no_bind = NiceTrainer.CurrentNoBind
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    local has_bind = not no_bind
    local key_id = id .. "_keybind"
    local current_key = ""
    if has_bind then
        if self.Settings[key_id] == nil then self.Settings[key_id] = "" end
        current_key = self.Settings[key_id]
    end
    
    local w = tab.wrapper:w() - 70 -- 100% de largura disponível
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    
    -- Background with subtle fill
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    
    -- Bottom glow highlight on hover
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    -- Action Icon Box on the Left (with border around >)
    local icon_box = p:panel({ x = 14, y = 12, w = 21, h = 21, layer = 2 })
    local icon_bg  = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.15, layer = 0 })
    local ib1 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, w = 1, layer = 1 })
    local ib2 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, x = 20, w = 1, layer = 1 })
    local ib3 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, h = 1, layer = 1 })
    local ib4 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, y = 20, h = 1, layer = 1 })
    local icon_arrow = icon_box:text({
        text = ">",
        font = "fonts/font_medium_shadow_mf",
        font_size = 14,
        align = "center",
        vertical = "center",
        color = Color(0.3, 0.7, 1.0),
        layer = 2
    })
    
    -- Button Label
    local text = p:text({
        text = btn_text,
        font = "fonts/font_medium_shadow_mf",
        font_size = 20,
        color = Color(0.85, 0.85, 0.85),
        x = 46,
        vertical = "center",
        layer = 1
    })
    self:RenderBadge(p, text)
    
    -- Bind Button (if enabled)
    local bind_btn, bind_bg, val_text
    local bind_w = 80
    if has_bind then
        bind_btn = p:panel({ x = w - 15 - bind_w, y = 8, w = bind_w, h = 29, layer = 2 })
        bind_bg = bind_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        bind_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        bind_btn:rect({ color = self:GetAccentColor(), x = bind_w - 2, w = 2, layer = 1 })
        
        local display_key = current_key == "" and "BIND" or NiceTrainer:FormatKeyDisplay(current_key)
        val_text = bind_btn:text({ 
            text = display_key, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = bind_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    local perform_click = function()
        NiceTrainer:Toast("Action: " .. btn_text)
        NiceTrainer:SafeCall(callback_func)
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = val_text, bg = bind_bg, id = key_id, callback_func = perform_click,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            hl:set_alpha(hovered and 1 or 0)
            text:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
            icon_bg:set_alpha(hovered and 0.35 or 0.15)
            icon_arrow:set_color(hovered and Color.white or Color(0.3, 0.7, 1.0))
            local iba = hovered and 0.9 or 0.5
            ib1:set_alpha(iba)
            ib2:set_alpha(iba)
            ib3:set_alpha(iba)
            ib4:set_alpha(iba)
            
            if has_bind and bind_btn then
                if NiceTrainer._listening_for_key == self then return end
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = bind_btn:inside(mx, my)
                bind_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if has_bind and bind_btn and bind_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
                return
            end
            perform_click()
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if has_bind and current_key ~= "" then
        self:BindGlobalHotkey(key_id, current_key, perform_click, tab_name)
    end
end

function NiceTrainer:AddToggle(tab_name, id, btn_text, default_val, tooltip, callback_func, no_bind, save)
    if type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if no_bind == nil then
        no_bind = NiceTrainer.CurrentNoBind
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, callback_func)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local state = self.Settings[id]
    
    local has_bind = not no_bind
    local key_id = id .. "_keybind"
    local current_key = ""
    if has_bind then
        if self.Settings[key_id] == nil then self.Settings[key_id] = "" end
        current_key = self.Settings[key_id]
    end
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    p:rect({ color = Color.white, alpha = 0.1, x = 15, y = 12, w = 20, h = 20, layer = 1 })
    local check = p:rect({ color = self:GetAccentColor(), x = 19, y = 16, w = 12, h = 12, visible = state, layer = 2 })
    
    local text = p:text({
        text = btn_text, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 50, vertical = "center", layer = 1
    })
    self:RenderBadge(p, text)
    
    local bind_btn, bind_bg, val_text
    if has_bind then
        local bind_w = 80
        bind_btn = p:panel({ x = w - 15 - bind_w, y = 8, w = bind_w, h = 29, layer = 2 })
        bind_bg = bind_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        bind_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        bind_btn:rect({ color = self:GetAccentColor(), x = bind_w - 2, w = 2, layer = 1 })
        
        local display_key = current_key == "" and "BIND" or NiceTrainer:FormatKeyDisplay(current_key)
        val_text = bind_btn:text({ 
            text = display_key, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = bind_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    local perform_toggle = function()
        state = not state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
        if save then
            NiceTrainer:Save()
        end
        NiceTrainer:Toast(btn_text .. " (" .. (state and "ON" or "OFF") .. ")")
        if callback_func then NiceTrainer:SafeCall(callback_func, state) end
    end

    self._toggle_elements = self._toggle_elements or {}
    self._toggle_elements[id] = function(new_state)
        state = new_state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = val_text, bg = bind_bg, id = key_id, callback_func = perform_toggle,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
            
            if has_bind and bind_btn then
                if NiceTrainer._listening_for_key == self then return end
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = bind_btn:inside(mx, my)
                bind_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if has_bind and bind_btn and bind_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
                return
            end
            perform_toggle()
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if has_bind and current_key ~= "" then
        self:BindGlobalHotkey(key_id, current_key, perform_toggle, tab_name)
    end
    
    if callback_func then NiceTrainer:SafeCall(callback_func, state) end
end


function NiceTrainer:AddMultiChoice(tab_name, id, title, options, default_idx, action_btn_text, tooltip, callback_func, save)
    if type(action_btn_text) == "function" then
        callback_func = action_btn_text
        action_btn_text = nil
        tooltip = nil
    elseif type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_idx, callback_func)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_idx end
    local idx = self.Settings[id]
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    local text = p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1
    })
    self:RenderBadge(p, text)
    
    local val_w = action_btn_text and 180 or 205
    local right_offset = action_btn_text and (15 + 100 + 10) or 15
    
    local val_panel = p:panel({ x = w - right_offset - val_w, y = 0, w = val_w, h = h, layer = 2 })
    local left_arrow = val_panel:text({ text = "<", font = "fonts/font_large_mf", font_size = 24, x = 0, vertical = "center", color = Color(0.8, 0.8, 0.8) })
    
    local function get_opt_text(i)
        if type(options) == "function" then
            return tostring(options(i) or "")
        end
        return tostring(options[i] or "")
    end
    
    local val_text = val_panel:text({ text = get_opt_text(idx), font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = self:GetAccentColor() })
    local right_arrow = val_panel:text({ text = ">", font = "fonts/font_large_mf", font_size = 24, align = "right", vertical = "center", color = Color(0.8, 0.8, 0.8) })
    
    local action_btn, action_text, action_bg
    if action_btn_text then
        action_btn = p:panel({ x = w - 15 - 100, y = 8, w = 100, h = 29, layer = 2 })
        action_bg = action_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        action_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        action_btn:rect({ color = self:GetAccentColor(), x = 98, w = 2, layer = 1 })
        action_text = action_btn:text({ 
            text = action_btn_text, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = 100, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
            if action_btn then
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = action_btn:inside(mx, my)
                action_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            local opt_len = type(options) == "function" and options("count") or #options
            if action_btn and action_btn:inside(mx, my) then
                NiceTrainer:Toast(action_btn_text .. " (" .. get_opt_text(idx) .. ") executado!")
                if callback_func then NiceTrainer:SafeCall(callback_func, idx, get_opt_text(idx)) end
                return
            end
            
            if val_panel:inside(mx, my) then
                local local_x = mx - val_panel:world_x()
                if local_x < 40 then
                    idx = idx - 1
                    if idx < 1 then idx = opt_len end
                elseif local_x > val_w - 40 then
                    idx = idx + 1
                    if idx > opt_len then idx = 1 end
                else
                    -- Clicar no meio também avança
                    idx = idx + 1
                    if idx > opt_len then idx = 1 end
                end
            else
                return -- Ignora clique no nome do item!
            end
            
            val_text:set_text(get_opt_text(idx))
            NiceTrainer.Settings[id] = idx
            if save then
                NiceTrainer:Save()
            end
            
            -- Se não tiver botão de ação associado, dispara o callback imediatamente ao girar a seta
            if not action_btn_text and callback_func then NiceTrainer:SafeCall(callback_func, idx, get_opt_text(idx)) end
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    -- Dispara imediatamente no carregamento se não for um botão manual
    if not action_btn_text and callback_func then NiceTrainer:SafeCall(callback_func, idx, get_opt_text(idx)) end
end

function NiceTrainer:AddSlider(tab_name, id, title, min, max, default_val, tooltip, callback_func, save)
    if type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, callback_func)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local val = self.Settings[id]
    
    local w = tab.wrapper:w() - 70
    local h = 55
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    local text = p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 15, y = 8, h = 24, layer = 1
    })
    self:RenderBadge(p, text)
    
    local val_text = p:text({
        text = tostring(math.floor(val)), font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = self:GetAccentColor(), x = w - 115, y = 8, w = 100, align = "right", layer = 1
    })
    
    local min_text = p:text({ text = tostring(min), font = "fonts/font_medium_shadow_mf", font_size = 14, color = Color(0.5, 0.5, 0.5), x = 15, y = 30, layer = 1 })
    local max_text = p:text({ text = tostring(max), font = "fonts/font_medium_shadow_mf", font_size = 14, color = Color(0.5, 0.5, 0.5), x = w - 115, y = 30, w = 100, align = "right", layer = 1 })
    
    local track_w = w - 60
    local track_x = 30
    local track = p:rect({ color = Color.black, alpha = 0.5, x = track_x, y = 35, w = track_w, h = 6, layer = 1 })
    local pct = math.clamp((val - min) / (max - min), 0, 1)
    local fill_w = pct * track_w
    local fill = p:rect({ color = self:GetAccentColor(), x = track_x, y = 35, w = fill_w, h = 6, layer = 2 })
    local knob = p:rect({ color = Color.white, x = track_x + fill_w - 4, y = 31, w = 8, h = 14, layer = 3 })
    
    local update_slider = function(mx)
        local rx = mx - track:world_x()
        pct = math.clamp(rx / track_w, 0, 1)
        val = min + (pct * (max - min))
        val = math.floor(val)
        
        fill:set_w(pct * track_w)
        knob:set_x(track_x + (pct * track_w) - 4)
        val_text:set_text(tostring(val))
        
        NiceTrainer.Settings[id] = val
        if save then
            NiceTrainer:Save()
        end
        if callback_func then NiceTrainer:SafeCall(callback_func, val) end
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
        end,
        on_click = function(self, mx, my)
            NiceTrainer._dragging_slider = update_slider
            update_slider(mx)
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if callback_func then NiceTrainer:SafeCall(callback_func, val) end
end
function NiceTrainer:RenderBadge(p, text_el)
    if not self.CurrentBadge then return end
    
    local _, _, tw, th = text_el:text_rect()
    local bx = text_el:x() + tw + 10
    
    local badges = {
        HOST = {
            text = "HOST",
            color = Color(1, 0.8, 0.2)
        },
        CLIENT = {
            text = "CLIENT",
            color = Color(0.2, 0.8, 1.0)
        },
        RISK = {
            text = "RISK",
            color = Color(1, 0.2, 0.2)
        },
        SAFE = {
            text = "CLIENT",
            color = Color(0.2, 0.8, 1.0)
        },
    }

    local badge_str = string.upper(self.CurrentBadge)
    local badge = badges[badge_str]

    local badge_color = badge and badge.color or Color(0.2, 0.8, 1.0)
    local badge_text = badge and badge.text or badge_str
    
    local dummy = p:text({ text = badge_text, font = "fonts/font_medium_shadow_mf", font_size = 14, alpha = 0 })
    local _, _, tw2, th2 = dummy:text_rect()
    p:remove(dummy)
    
    local b_w = tw2 + 12
    local b_h = 20
    
    -- Use text_el:h() which handles vertical="center" panels correctly
    local b_y = text_el:y() + (text_el:h() / 2) - (b_h / 2) - 2

    p:rect({ color = badge_color, alpha = 0.85, x = bx, y = b_y, w = b_w, h = b_h, layer = 2 })
    
    p:text({
        text = badge_text, font = "fonts/font_medium_shadow_mf", font_size = 14,
        color = Color.white, x = bx, y = b_y + 1, w = b_w, h = b_h, align = "center", vertical = "center", layer = 3
    })
    
    self.CurrentBadge = nil
end

function NiceTrainer:AddHeader(tab_name, title)
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    local w = tab.wrapper:w() - 70
    local h = 30
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    
    p:text({
        text = string.upper(title), font = "fonts/font_large_mf", font_size = 24,
        color = self:GetAccentColor(), x = 0, y = 5, layer = 1
    })
    p:rect({ color = self:GetAccentColor(), alpha = 0.5, x = 0, y = 28, w = w, h = 2, layer = 1 })
    
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
end
function NiceTrainer:SetFocusedInput(input_el)
    if self._focused_input then
        if alive(self._focused_input.bg) then
            self._focused_input.bg:set_alpha(0.2)
        end
        if alive(self._panel) then
            self._panel:key_press(nil)
            self._panel:enter_text(nil)
        end
        if self._ws then
            self._ws:disconnect_keyboard()
        end
    end
    
    self._focused_input = input_el
    if input_el and alive(self._panel) then
        input_el.bg:set_alpha(0.5)
        self._ws:connect_keyboard(Input:keyboard())
        
        self._panel:key_press(function(o, k)
            if k == Idstring("backspace") then
                local t = input_el.val_text:text()
                input_el.val_text:set_text(string.sub(t, 1, -2))
            elseif k == Idstring("enter") then
                NiceTrainer:SetFocusedInput(nil)
            end
        end)
        
        self._panel:enter_text(function(o, s)
            if s:match("^%d$") then
                local t = input_el.val_text:text()
                if string.len(t) < 10 then
                    input_el.val_text:set_text(t .. s)
                end
            end
        end)
    end
end

function NiceTrainer:AddNumberInput(tab_name, id, title, min, max, default_val, action_btn_text, tooltip, callback_func, save)
    if type(action_btn_text) == "function" then
        callback_func = action_btn_text
        action_btn_text = nil
        tooltip = nil
    elseif type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, callback_func)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local val = tostring(self.Settings[id])
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1
    })
    
    local input_w = 120
    local right_offset = action_btn_text and (15 + 100 + 10) or 15
    
    local input_panel = p:panel({ x = w - right_offset - input_w, y = 8, w = input_w, h = 29, layer = 2 })
    local input_bg = input_panel:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
    input_panel:rect({ color = self:GetAccentColor(), alpha = 0.5, w = 2, layer = 1 })
    
    local val_text = input_panel:text({ 
        text = val, font = "fonts/font_medium_shadow_mf", font_size = 18, 
        x = 5, y = 0, align = "left", vertical = "center", color = Color.white, layer = 2 
    })
    
    local action_btn, action_text, action_bg
    if action_btn_text then
        action_btn = p:panel({ x = w - 15 - 100, y = 8, w = 100, h = 29, layer = 2 })
        action_bg = action_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        action_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        action_btn:rect({ color = self:GetAccentColor(), x = 98, w = 2, layer = 1 })
        action_text = action_btn:text({ 
            text = action_btn_text, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = 100, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        bg = input_bg, val_text = val_text,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            hl:set_alpha(hovered and 1 or 0)
            if action_btn then
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = action_btn:inside(mx, my)
                action_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if action_btn and action_btn:inside(mx, my) then
                local current_val = tonumber(val_text:text()) or default_val
                current_val = math.clamp(current_val, min, max)
                val_text:set_text(tostring(current_val))
                
                NiceTrainer.Settings[id] = current_val
                if save then
                    NiceTrainer:Save()
                end
                NiceTrainer:SetFocusedInput(nil)
                
                NiceTrainer:Toast(action_btn_text .. " (" .. current_val .. ") executado!")
                if callback_func then NiceTrainer:SafeCall(callback_func, current_val) end
                return
            end
            
            if input_panel:inside(mx, my) then
                NiceTrainer:SetFocusedInput(self)
                val_text:set_text("") -- Clear on click to type new number
            end
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
end
function NiceTrainer:AddModalButton(tab_name, id, title, modal_title, options_list, action_btn_text, tooltip, callback_func)
    if type(action_btn_text) == "function" then
        callback_func = action_btn_text
        action_btn_text = nil
        tooltip = nil
    elseif type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    -- Action Icon Box on the Left (with border around >)
    local icon_box = p:panel({ x = 14, y = 12, w = 21, h = 21, layer = 2 })
    local icon_bg  = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.15, layer = 0 })
    local ib1 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, w = 1, layer = 1 })
    local ib2 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, x = 20, w = 1, layer = 1 })
    local ib3 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, h = 1, layer = 1 })
    local ib4 = icon_box:rect({ color = self:GetAccentColor(), alpha = 0.5, y = 20, h = 1, layer = 1 })
    local icon_arrow = icon_box:text({
        text = ">",
        font = "fonts/font_medium_shadow_mf",
        font_size = 14,
        align = "center",
        vertical = "center",
        color = Color(0.3, 0.7, 1.0),
        layer = 2
    })
    
    local text = p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.85, 0.85, 0.85), x = 46, vertical = "center", layer = 1
    })
    self:RenderBadge(p, text)
    
    local btn_w = 180
    local action_btn = p:panel({ x = w - 15 - btn_w, y = 8, w = btn_w, h = 29, layer = 2 })
    local action_bg = action_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
    action_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
    action_btn:rect({ color = self:GetAccentColor(), x = btn_w - 2, w = 2, layer = 1 })
    action_btn:text({ 
        text = action_btn_text or "Select", font = "fonts/font_medium_shadow_mf", font_size = 18, 
        w = btn_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
    })
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            hl:set_alpha(hovered and 1 or 0)
            text:set_color(hovered and Color.white or Color(0.85, 0.85, 0.85))
            icon_bg:set_alpha(hovered and 0.35 or 0.15)
            icon_arrow:set_color(hovered and Color.white or Color(0.3, 0.7, 1.0))
            local iba = hovered and 0.9 or 0.5
            ib1:set_alpha(iba)
            ib2:set_alpha(iba)
            ib3:set_alpha(iba)
            ib4:set_alpha(iba)
            if action_btn then
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = action_btn:inside(mx, my)
                action_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            local resolved_options = options_list
            if type(options_list) == "function" then
                resolved_options = options_list()
            end
            if resolved_options and type(resolved_options) == "table" then
                NiceTrainer:ShowModal(modal_title, resolved_options, callback_func)
            elseif type(callback_func) == "function" then
                callback_func()
            end
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
end

function NiceTrainer:AddColorPicker(tab_name, id, title, default_color, tooltip, callback_func, save)
    if type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_color or "#FFFFFF", callback_func)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    local function hex_to_color(hex)
        hex = hex:gsub("#","")
        return Color(tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255)
    end
    local function color_to_hex(c)
        return string.format("#%02X%02X%02X", math.floor(c.r*255), math.floor(c.g*255), math.floor(c.b*255))
    end
    
    if type(default_color) == "userdata" and default_color.type_name == "Color" then
        default_color = color_to_hex(default_color)
    end
    
    if self.Settings[id] == nil then self.Settings[id] = default_color or "#FFFFFF" end
    local current_hex = self.Settings[id]
    local current_col = hex_to_color(current_hex)
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1
    })
    
    local btn_w = 120
    local action_btn = p:panel({ x = w - 15 - btn_w, y = 8, w = btn_w, h = 29, layer = 2 })
    local action_bg = action_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
    action_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
    action_btn:rect({ color = self:GetAccentColor(), x = btn_w - 2, w = 2, layer = 1 })
    
    local color_preview = action_btn:rect({ color = current_col, x = 5, y = 4, w = 21, h = 21, layer = 2 })
    action_btn:rect({ color = Color.white, x = 4, y = 3, w = 23, h = 23, layer = 1, alpha = 0.5 }) 
    
    local hex_text = action_btn:text({ 
        text = current_hex, font = "fonts/font_medium_shadow_mf", font_size = 18, 
        x = 35, y = 0, w = btn_w - 35, h = 29, align = "left", vertical = "center", color = Color.white, layer = 2 
    })
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            hl:set_alpha(hovered and 1 or 0)
            if action_btn then
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = action_btn:inside(mx, my)
                action_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if action_btn and action_btn:inside(mx, my) then
                local current_start_color = hex_to_color(NiceTrainer.Settings[id] or current_hex)
                NiceTrainer:ShowColorPickerModal(title, current_start_color, function(new_color)
                    local new_hex = color_to_hex(new_color)
                    NiceTrainer.Settings[id] = new_hex
                    if save then
                        NiceTrainer:Save()
                    end
                    color_preview:set_color(new_color)
                    hex_text:set_text(new_hex)
                    if callback_func then NiceTrainer:SafeCall(callback_func, new_color, new_hex) end
                end)
            end
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
end

function NiceTrainer:AddToggleWithSettings(tab_name, id, btn_text, default_val, tooltip, toggle_callback, settings_callback, no_bind, save)
    if type(tooltip) == "function" then
        settings_callback = toggle_callback
        toggle_callback = tooltip
        tooltip = nil
    end
    if no_bind == nil then
        no_bind = NiceTrainer.CurrentNoBind
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, toggle_callback)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local state = self.Settings[id]
    
    local has_bind = not no_bind
    local key_id = id .. "_keybind"
    local current_key = ""
    if has_bind then
        if self.Settings[key_id] == nil then self.Settings[key_id] = "" end
        current_key = self.Settings[key_id]
    end
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    p:rect({ color = Color.white, alpha = 0.1, x = 15, y = 12, w = 20, h = 20, layer = 1 })
    local check = p:rect({ color = self:GetAccentColor(), x = 19, y = 16, w = 12, h = 12, visible = state, layer = 2 })
    
    local text = p:text({
        text = btn_text, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 50, vertical = "center", layer = 1
    })
    self:RenderBadge(p, text)
    
    local btn_w = 40
    local settings_btn = p:panel({ x = w - 15 - btn_w, y = 8, w = btn_w, h = 29, layer = 2 })
    local settings_bg = settings_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
    settings_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
    settings_btn:rect({ color = self:GetAccentColor(), x = btn_w - 2, w = 2, layer = 1 })
    
    settings_btn:text({ 
        text = "...", font = "fonts/font_medium_shadow_mf", font_size = 20, 
        align = "center", vertical = "center", color = Color.white, layer = 2 
    })
    
    local bind_btn, bind_bg, val_text
    if has_bind then
        local bind_w = 80
        bind_btn = p:panel({ x = w - 15 - btn_w - 5 - bind_w, y = 8, w = bind_w, h = 29, layer = 2 })
        bind_bg = bind_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        bind_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        bind_btn:rect({ color = self:GetAccentColor(), x = bind_w - 2, w = 2, layer = 1 })
        
        local display_key = current_key == "" and "BIND" or NiceTrainer:FormatKeyDisplay(current_key)
        val_text = bind_btn:text({ 
            text = display_key, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = bind_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    local perform_toggle = function()
        state = not state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
        if save then
            NiceTrainer:Save()
        end
        NiceTrainer:Toast(btn_text .. " (" .. (state and "ON" or "OFF") .. ")")
        if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state) end
    end

    self._toggle_elements = self._toggle_elements or {}
    self._toggle_elements[id] = function(new_state)
        state = new_state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = val_text, bg = bind_bg, id = key_id, callback_func = perform_toggle,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
            
            local mx, my = managers.mouse_pointer:mouse()
            local sbtn_hover = settings_btn:inside(mx, my)
            settings_bg:set_alpha(sbtn_hover and 0.4 or 0.2)
            
            if has_bind and bind_btn then
                if NiceTrainer._listening_for_key == self then return end
                local bbtn_hover = bind_btn:inside(mx, my)
                bind_bg:set_alpha(bbtn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if settings_btn:inside(mx, my) then
                if settings_callback then NiceTrainer:SafeCall(settings_callback) end
                return
            end
            if has_bind and bind_btn and bind_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
                return
            end
            perform_toggle()
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if has_bind and current_key ~= "" then
        self:BindGlobalHotkey(key_id, current_key, perform_toggle, tab_name)
    end
    
    if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state) end
end

function NiceTrainer:AddToggleMultiChoice(tab_name, id, title, default_val, options, default_idx, choice_id, tooltip, toggle_callback, choice_callback, no_bind, save)
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if no_bind == nil then
        no_bind = NiceTrainer.CurrentNoBind
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, toggle_callback)
    end
    local has_bind = not no_bind
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local state = self.Settings[id]
    
    choice_id = choice_id or (id .. "_mode")
    if self.Settings[choice_id] == nil then self.Settings[choice_id] = default_idx or 1 end
    local idx = self.Settings[choice_id]
    
    local key_id = id .. "_keybind"
    local current_key = ""
    if has_bind then
        if self.Settings[key_id] == nil then self.Settings[key_id] = "" end
        current_key = self.Settings[key_id]
    end
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    -- Checkbox
    p:rect({ color = Color.white, alpha = 0.1, x = 15, y = 12, w = 20, h = 20, layer = 1 })
    local check = p:rect({ color = self:GetAccentColor(), x = 19, y = 16, w = 12, h = 12, visible = state, layer = 2 })
    
    local text = p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 50, vertical = "center", layer = 1
    })
    self:RenderBadge(p, text)
    
    local bind_btn, bind_bg, bind_text
    local val_w = 210
    local val_x = w - 15 - val_w
    if has_bind then
        local bind_w = 80
        bind_btn = p:panel({ x = w - 15 - bind_w, y = 8, w = bind_w, h = 29, layer = 2 })
        bind_bg = bind_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        bind_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        bind_btn:rect({ color = self:GetAccentColor(), x = bind_w - 2, w = 2, layer = 1 })
        
        local display_key = current_key == "" and "BIND" or NiceTrainer:FormatKeyDisplay(current_key)
        bind_text = bind_btn:text({ 
            text = display_key, font = "fonts/font_medium_shadow_mf", font_size = 18, 
            w = bind_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
        val_x = w - 15 - bind_w - 10 - val_w
    end
    
    -- Dropdown / MultiChoice panel (between label and BIND button)
    local val_panel = p:panel({ x = val_x, y = 0, w = val_w, h = h, layer = 2 })
    local left_arrow = val_panel:text({ text = "<", font = "fonts/font_large_mf", font_size = 24, x = 0, vertical = "center", color = Color(0.8, 0.8, 0.8) })
    
    local function get_opt_text(i)
        if type(options) == "function" then
            return tostring(options(i) or "")
        end
        return tostring(options[i] or "")
    end
    
    local val_text = val_panel:text({ text = get_opt_text(idx), font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = self:GetAccentColor() })
    local right_arrow = val_panel:text({ text = ">", font = "fonts/font_large_mf", font_size = 24, align = "right", vertical = "center", color = Color(0.8, 0.8, 0.8) })
    
    local perform_toggle = function()
        state = not state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
        if save then
            NiceTrainer:Save()
        end
        NiceTrainer:Toast(title .. " (" .. (state and "ON" or "OFF") .. ")")
        if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state) end
    end

    self._toggle_elements = self._toggle_elements or {}
    self._toggle_elements[id] = function(new_state)
        state = new_state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = bind_text, bg = bind_bg, id = key_id, callback_func = perform_toggle,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
            
            local mx, my = managers.mouse_pointer:mouse()
            local over_choice = val_panel:inside(mx, my)
            left_arrow:set_color(over_choice and Color.white or Color(0.8, 0.8, 0.8))
            right_arrow:set_color(over_choice and Color.white or Color(0.8, 0.8, 0.8))
            
            if has_bind and bind_btn then
                if NiceTrainer._listening_for_key == self then return end
                local btn_hover = bind_btn:inside(mx, my)
                bind_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if has_bind and bind_btn and bind_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
                return
            end
            
            if val_panel:inside(mx, my) then
                local opt_len = type(options) == "function" and options("count") or #options
                local local_x = mx - val_panel:world_x()
                if local_x < 40 then
                    idx = idx - 1
                    if idx < 1 then idx = opt_len end
                else
                    idx = idx + 1
                    if idx > opt_len then idx = 1 end
                end
                
                NiceTrainer.Settings[choice_id] = idx
                NiceTrainer:Save()
                val_text:set_text(get_opt_text(idx))
                
                if choice_callback then NiceTrainer:SafeCall(choice_callback, idx, get_opt_text(idx)) end
                return
            end
            
            perform_toggle()
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if has_bind and current_key ~= "" then
        self:BindGlobalHotkey(key_id, current_key, perform_toggle, tab_name)
    end
    
    if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state) end
    if choice_callback then NiceTrainer:SafeCall(choice_callback, idx, get_opt_text(idx)) end
end

function NiceTrainer:AddToggleSlider(tab_name, id, title, default_val, min, max, default_slider_val, slider_id, tooltip, toggle_callback, slider_callback, no_bind, save)
    if type(tooltip) == "function" then
        slider_callback = toggle_callback
        toggle_callback = tooltip
        tooltip = nil
    end
    if no_bind == nil then
        no_bind = NiceTrainer.CurrentNoBind
    end
    if save == nil then
        save = NiceTrainer.CurrentSave
    end
    if save == nil then
        save = true
    end
    if not save then
        self:RegisterNonPersistent(id, default_val, toggle_callback)
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_val end
    local state = self.Settings[id]
    
    slider_id = slider_id or (id .. "_value")
    if self.Settings[slider_id] == nil then self.Settings[slider_id] = default_slider_val or min end
    local val = self.Settings[slider_id]
    
    local has_bind = not no_bind
    local key_id = id .. "_keybind"
    local current_key = ""
    if has_bind then
        if self.Settings[key_id] == nil then self.Settings[key_id] = "" end
        current_key = self.Settings[key_id]
    end
    
    local w = tab.wrapper:w() - 70
    local h = 62
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    -- Checkbox
    p:rect({ color = Color.white, alpha = 0.1, x = 15, y = 10, w = 20, h = 20, layer = 1 })
    local check = p:rect({ color = self:GetAccentColor(), x = 19, y = 14, w = 12, h = 12, visible = state, layer = 2 })
    
    -- Title
    local text = p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 48, y = 8, h = 24, layer = 1
    })
    self:RenderBadge(p, text)
    
    -- Keybind
    local bind_btn, bind_bg, bind_val_text
    local bind_w = 75
    if has_bind then
        bind_btn = p:panel({ x = w - 15 - bind_w, y = 7, w = bind_w, h = 26, layer = 2 })
        bind_bg = bind_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
        bind_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
        bind_btn:rect({ color = self:GetAccentColor(), x = bind_w - 2, w = 2, layer = 1 })
        
        local display_key = current_key == "" and "BIND" or NiceTrainer:FormatKeyDisplay(current_key)
        bind_val_text = bind_btn:text({ 
            text = display_key, font = "fonts/font_medium_shadow_mf", font_size = 16, 
            w = bind_w, h = 26, align = "center", vertical = "center", color = Color.white, layer = 2 
        })
    end
    
    -- Value Display
    local val_text_x = has_bind and (w - 25 - bind_w - 60) or (w - 75)
    local val_text = p:text({
        text = tostring(math.floor(val)), font = "fonts/font_medium_shadow_mf", font_size = 19,
        color = self:GetAccentColor(), x = val_text_x, y = 8, w = 60, align = "right", layer = 1
    })
    
    -- Slider track & knob
    local track_x = 48
    local track_w = w - 65
    local track = p:rect({ color = Color.black, alpha = 0.5, x = track_x, y = 38, w = track_w, h = 6, layer = 1 })
    local pct = math.clamp((val - min) / (max - min), 0, 1)
    local fill_w = pct * track_w
    local fill = p:rect({ color = self:GetAccentColor(), x = track_x, y = 38, w = fill_w, h = 6, layer = 2 })
    local knob = p:rect({ color = Color.white, x = track_x + fill_w - 4, y = 34, w = 8, h = 14, layer = 3 })
    
    local min_text = p:text({ text = tostring(min), font = "fonts/font_medium_shadow_mf", font_size = 13, color = Color(0.5, 0.5, 0.5), x = track_x, y = 46, layer = 1 })
    local max_text = p:text({ text = tostring(max), font = "fonts/font_medium_shadow_mf", font_size = 13, color = Color(0.5, 0.5, 0.5), x = track_x + track_w - 50, y = 46, w = 50, align = "right", layer = 1 })
    
    local update_slider = function(mx)
        local rx = mx - track:world_x()
        pct = math.clamp(rx / track_w, 0, 1)
        val = min + (pct * (max - min))
        val = math.floor(val)
        
        fill:set_w(pct * track_w)
        knob:set_x(track_x + (pct * track_w) - 4)
        val_text:set_text(tostring(val))
        
        NiceTrainer.Settings[slider_id] = val
        if save then
            NiceTrainer:Save()
        end
        if slider_callback then NiceTrainer:SafeCall(slider_callback, val, state) end
    end
    
    local perform_toggle = function()
        state = not state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
        if save then
            NiceTrainer:Save()
        end
        NiceTrainer:Toast(title .. " (" .. (state and "ON" or "OFF") .. ")")
        if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state, val) end
    end

    self._toggle_elements = self._toggle_elements or {}
    self._toggle_elements[id] = function(new_state)
        state = new_state
        if alive(check) then check:set_visible(state) end
        NiceTrainer.Settings[id] = state
    end
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = bind_val_text, bg = bind_bg, id = key_id, callback_func = perform_toggle,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            text:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            hl:set_alpha(hovered and 1 or 0)
            
            if has_bind and bind_btn then
                if NiceTrainer._listening_for_key == self then return end
                local mx, my = managers.mouse_pointer:mouse()
                local btn_hover = bind_btn:inside(mx, my)
                bind_bg:set_alpha(btn_hover and 0.4 or 0.2)
            end
        end,
        on_click = function(self, mx, my)
            if has_bind and bind_btn and bind_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
                return
            end
            
            if my >= (track:world_y() - 10) and my <= (track:world_y() + 20) and mx >= (track:world_x() - 10) and mx <= (track:world_x() + track_w + 10) then
                NiceTrainer._dragging_slider = update_slider
                update_slider(mx)
                return
            end
            
            perform_toggle()
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    if has_bind and current_key ~= "" then
        self:BindGlobalHotkey(key_id, current_key, perform_toggle, tab_name)
    end
    
    if toggle_callback then NiceTrainer:SafeCall(toggle_callback, state, val) end
end

function NiceTrainer:ListenForKeybind(el)
    if self._listening_for_key then
        self:CancelKeybind()
    end
    
    self._listening_for_key = el
    el.val_text:set_text("Press Key...")
    el.val_text:set_color(Color.yellow)
    el.bg:set_alpha(0.6)
    
    if self._ws then
        self._ws:connect_keyboard(Input:keyboard())
    end
    
    self._panel:key_press(function(o, k)
        local key_name = ""
        if type(k) == "string" then
            key_name = k
        elseif type(k) == "number" then
            local success, res = pcall(function() return Input:keyboard():button_name_str(k) end)
            if success and res then key_name = res end
        else
            -- Probably Idstring
            local success, res = pcall(function() return Input:keyboard():button_name_str(k) end)
            if success and res then 
                key_name = res 
            else
                local s2, r2 = pcall(function() return Input:keyboard():button_name_str(Input:keyboard():button_name(k)) end)
                if s2 and r2 then key_name = r2 end
            end
        end
        
        if not key_name or key_name == "" then
            local keys = Input:keyboard():down_list()
            for _, pressed_key in pairs(keys) do
                local s, r = pcall(function() return Input:keyboard():button_name_str(pressed_key) end)
                if s and r and r ~= "" then
                    local s2, r2 = pcall(function() return Input:keyboard():button_name_str(Input:keyboard():button_name(pressed_key)) end)
                    if s2 and r2 and r2 ~= "" then key_name = r2 else key_name = r end
                    break
                end
            end
        end
        
        key_name = tostring(key_name):lower()
        if key_name == "esc" then
            NiceTrainer:CancelKeybind()
            return
        end
        if key_name == "backspace" then
            NiceTrainer:ApplyKeybind(el, "")
            return
        end
        
        NiceTrainer:ApplyKeybind(el, key_name)
    end)
end

function NiceTrainer:CancelKeybind()
    local el = self._listening_for_key
    if not el then return end
    
    local current_key = self.Settings[el.id] or ""
    local default_empty = el.is_standalone_keybind and "None" or "BIND"
    local txt = current_key == "" and default_empty or NiceTrainer:FormatKeyDisplay(current_key)
    el.val_text:set_text(txt)
    el.val_text:set_color(Color.white)
    el.bg:set_alpha(0.2)
    
    self._panel:key_press(nil)
    if self._ws then
        self._ws:disconnect_keyboard()
    end
    
    self._listening_for_key = nil
end

function NiceTrainer:ApplyKeybind(el, key_name)
    self.Settings[el.id] = key_name
    self:Save()
    
    local default_empty = el.is_standalone_keybind and "None" or "BIND"
    local txt = key_name == "" and default_empty or NiceTrainer:FormatKeyDisplay(key_name)
    el.val_text:set_text(txt)
    el.val_text:set_color(Color.white)
    el.bg:set_alpha(0.2)
    
    self._panel:key_press(nil)
    if self._ws then
        self._ws:disconnect_keyboard()
    end
    
    self._listening_for_key = nil
    
    self:BindGlobalHotkey(el.id, key_name, el.callback_func, el.tab_name)
end

function NiceTrainer:BindGlobalHotkey(id, key_name, callback_func, tab_name)
    if not self._custom_hotkeys then self._custom_hotkeys = {} end
    
    if key_name and key_name ~= "" and callback_func then
        self._custom_hotkeys[id] = {
            key = string.lower(tostring(key_name)),
            callback = callback_func,
            tab_name = tab_name
        }
    else
        self._custom_hotkeys[id] = nil
    end
end

function NiceTrainer:CheckHotkeys()
    if not self._custom_hotkeys then return end
    if self._focused_input or self._listening_for_key then return end
    
    if managers then
        if managers.hud and managers.hud.chat_focus and managers.hud:chat_focus() then return end
        if managers.menu_component and managers.menu_component.input_focus_game_chat_gui and managers.menu_component:input_focus_game_chat_gui() then return end
    end

    local mouse = Input:mouse()
    local keyboard = Input:keyboard()
    if not mouse or not keyboard then return end

    for id, data in pairs(self._custom_hotkeys) do
        local key = data.key
        if key and key ~= "" then
            local pressed = false
            local k_lower = string.lower(tostring(key))

            if string.find(k_lower, "mouse") or string.find(k_lower, "wheel") or string.find(k_lower, "m") == 1 or k_lower == "middle" or k_lower == "right" then
                if k_lower == "mouse 1" or k_lower == "m2" or k_lower == "right" then
                    pressed = mouse:pressed(Idstring("1")) or mouse:pressed(Idstring("mouse 1"))
                elseif k_lower == "mouse 2" or k_lower == "m3" or k_lower == "middle" or k_lower == "mouse 3" then
                    pressed = mouse:pressed(Idstring("2")) or mouse:pressed(Idstring("mouse 2")) or mouse:pressed(Idstring("3")) or mouse:pressed(Idstring("mouse 3"))
                elseif k_lower == "mouse 4" or k_lower == "m4" then
                    pressed = mouse:pressed(Idstring("3")) or mouse:pressed(Idstring("mouse 3")) or mouse:pressed(Idstring("4")) or mouse:pressed(Idstring("mouse 4"))
                elseif k_lower == "mouse 5" or k_lower == "m5" then
                    pressed = mouse:pressed(Idstring("4")) or mouse:pressed(Idstring("mouse 4")) or mouse:pressed(Idstring("5")) or mouse:pressed(Idstring("mouse 5"))
                elseif k_lower == "mouse wheel up" or k_lower == "wheel up" then
                    pressed = mouse:pressed(Idstring("mouse wheel up")) or mouse:pressed(Idstring("wheel_up"))
                elseif k_lower == "mouse wheel down" or k_lower == "wheel down" then
                    pressed = mouse:pressed(Idstring("mouse wheel down")) or mouse:pressed(Idstring("wheel_down"))
                else
                    local btn_num = k_lower:match("%d+")
                    if btn_num then
                        pressed = mouse:pressed(Idstring(btn_num)) or mouse:pressed(Idstring("mouse " .. btn_num)) or mouse:pressed(Idstring("mouse" .. btn_num))
                    end
                    if not pressed then
                        pressed = mouse:pressed(Idstring(k_lower))
                    end
                end
            else
                pressed = keyboard:pressed(Idstring(k_lower))
            end

            if pressed then
                if not data.tab_name or self:CanRunTabAction(data.tab_name) then
                    self:SafeCall(data.callback)
                end
            end
        end
    end
end

Hooks:Add("MenuUpdate", "NiceTrainer_Hotkeys_MenuUpdate", function(t, dt)
    NiceTrainer:CheckHotkeys()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Hotkeys_GameUpdate", function(t, dt)
    NiceTrainer:CheckHotkeys()
end)

function NiceTrainer:AddKeybind(tab_name, id, title, default_key, tooltip, callback_func)
    if type(tooltip) == "function" then
        callback_func = tooltip
        tooltip = nil
    end
    
    local tab = self.Tabs[tab_name]
    if not tab then return end
    
    if self.Settings[id] == nil then self.Settings[id] = default_key or "" end
    local current_key = self.Settings[id]
    
    local w = tab.wrapper:w() - 70
    local h = 45
    local p = tab.canvas:panel({ x = 30, y = tab.y_offset, w = w, h = h, layer = 5 })
    local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
    local hl = p:rect({ color = self:GetAccentColor(), x = 0, y = h - 2, w = w, h = 2, alpha = 0, layer = 1 })
    
    p:text({
        text = title, font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1
    })
    
    local btn_w = 120
    local action_btn = p:panel({ x = w - 15 - btn_w, y = 8, w = btn_w, h = 29, layer = 2 })
    local action_bg = action_btn:rect({ color = self:GetAccentColor(), alpha = 0.2, layer = 0 })
    action_btn:rect({ color = self:GetAccentColor(), w = 2, layer = 1 })
    action_btn:rect({ color = self:GetAccentColor(), x = btn_w - 2, w = 2, layer = 1 })
    
    local display_text = current_key == "" and "None" or NiceTrainer:FormatKeyDisplay(current_key)
    local val_text = action_btn:text({ 
        text = display_text, font = "fonts/font_medium_shadow_mf", font_size = 18, 
        w = btn_w, h = 29, align = "center", vertical = "center", color = Color.white, layer = 2 
    })
    
    local el = {
        panel = p, tab_name = tab_name, tooltip = tooltip,
        val_text = val_text, bg = action_bg, id = id, callback_func = callback_func,
        is_standalone_keybind = true,
        inside = function(self, mx, my) 
            if not tab.wrapper:inside(mx, my) then return false end
            return p:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            hl:set_alpha(hovered and 1 or 0)
            
            if NiceTrainer._listening_for_key == self then return end
            
            local mx, my = managers.mouse_pointer:mouse()
            local btn_hover = action_btn:inside(mx, my)
            action_bg:set_alpha(btn_hover and 0.4 or 0.2)
        end,
        on_click = function(self, mx, my)
            if action_btn:inside(mx, my) then
                if NiceTrainer._listening_for_key == self then
                    NiceTrainer:CancelKeybind()
                else
                    NiceTrainer:ListenForKeybind(self)
                end
            end
        end
    }
    table.insert(self.Elements, el)
    tab.y_offset = tab.y_offset + h + 10
    tab.canvas:set_h(tab.y_offset)
    self:UpdateScrollbar(tab_name)
    
    -- Bind it automatically on creation if a key exists
    if current_key ~= "" then
        self:BindGlobalHotkey(id, current_key, callback_func, tab_name)
    end
end

function NiceTrainer:SetToggleState(id, new_state)
    self.Settings[id] = new_state
    self:Save()
    if self._toggle_elements and self._toggle_elements[id] then
        self._toggle_elements[id](new_state)
    end
end


