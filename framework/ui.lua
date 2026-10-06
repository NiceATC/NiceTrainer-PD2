function NiceTrainer:InitUI()
    if self._panel and alive(self._panel) then return end
    
    self:Load()
    
    self._ws = managers.gui_data:create_fullscreen_workspace()
    self._panel = self._ws:panel():panel({
        name = "nice_trainer_main",
        layer = 2000,
        visible = false
    })
    
    -- Cinematic Blur
    self._panel:bitmap({
        texture = "guis/textures/test_blur_df",
        w = self._panel:w(), h = self._panel:h(),
        render_template = "VertexColorTexturedBlur3D",
        layer = -1, halign = "scale", valign = "scale"
    })
    
    self._bg = self._panel:rect({ color = Color.black, alpha = 0.4, layer = 0 })
    
    local w, h = 850, 500
    local cx = (self._panel:w() - w) / 2
    local cy = (self._panel:h() - h) / 2
    
    self._main = self._panel:panel({ x = cx, y = cy, w = w, h = h, layer = 1 })
    self._main:rect({ color = Color(0.12, 0.12, 0.12), x = 0, y = 0, w = w, h = h, alpha = 0.95, layer = 0 })
    
    local logo_w, logo_h = 250, 90
    self._main:rect({ color = Color.black, alpha = 0.3, x = 0, y = 0, w = logo_w, h = logo_h, layer = 2 })
    
    self._main:text({
        text = "NICE TRAINER", font = "fonts/font_large_mf", font_size = 30,
        color = Color.white, x = 0, y = 25, w = logo_w, align = "center", layer = 3
    })
    self._main:text({
        text = "STANDALONE ENGINE", font = "fonts/font_medium_shadow_mf", font_size = 14,
        color = Color(0.8, 0.8, 0.8), x = 0, y = 55, w = logo_w, align = "center", layer = 3
    })
    
    self._sidebar = self._main:panel({ x = 0, y = logo_h, w = logo_w, h = h - logo_h - 50, layer = 3 })
    self._sidebar_canvas = self._sidebar:panel({ x = 0, y = 0, w = logo_w, h = self._sidebar:h(), layer = 1 })
    
    local version = "1.0"
    local f = io.open(self.ModPath .. "mod.txt", "r")
    if f then
        local f_content = f:read("*a")
        if f_content then
            local success, m_data = pcall(json.decode, f_content)
            if success and m_data and m_data.version then version = m_data.version end
        end
        f:close()
    end
    
    self._version = version
    local footer_h = 35
    self._main:rect({ color = Color(1, 0.05, 0.05, 0.05), x = 0, y = h - footer_h, w = w, h = footer_h, layer = 2 })
    self._footer_text = self._main:text({
        text = string.format("NiceTrainer v%s   -   Overlay Key: [UNBOUND]", version),
        font = "fonts/font_medium_shadow_mf", font_size = 14,
        color = Color(0.5, 0.5, 0.5), x = 0, y = h - footer_h + 10, w = w, align = "center", layer = 3
    })
    
    self._content = self._main:panel({ x = logo_w, y = 0, w = w - logo_w, h = h - footer_h, layer = 2 })
    self._main:rect({ color = Color.white, alpha = 0.1, x = logo_w, y = 0, w = 1, h = h - footer_h, layer = 5 })
    
    self.Tabs = {}
    self.TabsList = {}
    self.Elements = {}
    self._tab_count = 0
    self.ActiveTab = nil

    -- Footer About Button (right side of the bottom footer)
    local about_btn_w, about_btn_h = 80, 23
    local about_btn = self._main:panel({
        x = w - about_btn_w - 15,
        y = h - footer_h + 6,
        w = about_btn_w,
        h = about_btn_h,
        layer = 4
    })
    local ab_bg = about_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.1, layer = 0 })
    local ab_b1 = about_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.5, w = 1, layer = 1 })
    local ab_b2 = about_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.5, x = about_btn_w - 1, w = 1, layer = 1 })
    local ab_b3 = about_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.5, h = 1, layer = 1 })
    local ab_b4 = about_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.5, y = about_btn_h - 1, h = 1, layer = 1 })
    local ab_txt = about_btn:text({
        text = "ABOUT",
        font = "fonts/font_medium_shadow_mf",
        font_size = 13,
        color = Color(0.8, 0.8, 0.8),
        align = "center",
        vertical = "center",
        layer = 2
    })
    table.insert(self.Elements, {
        panel = about_btn,
        is_global_btn = true,
        tooltip = "About NiceTrainer, Credits, Links & Info",
        inside = function(self, mx, my) return about_btn:inside(mx, my) end,
        on_hover = function(self, hovered)
            ab_bg:set_alpha(hovered and 0.3 or 0.1)
            ab_txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            local ba = hovered and 1.0 or 0.5
            ab_b1:set_alpha(ba)
            ab_b2:set_alpha(ba)
            ab_b3:set_alpha(ba)
            ab_b4:set_alpha(ba)
        end,
        on_click = function()
            NiceTrainer:ShowAboutModal()
        end
    })
    
    -- Steam Profile Info
    local profile_h = 45
    local profile_p = self._main:panel({ x = 0, y = h - footer_h - profile_h, w = logo_w, h = profile_h, layer = 4 })
    
    local avatar_size = 32
    profile_p:rect({ color = Color.black, alpha = 0.5, x = 15, y = 6, w = avatar_size, h = avatar_size, layer = 0 })
    
    self._avatar_slot = profile_p
    if Distribution then
        pcall(function()
            Distribution:request_user_profile_picture(Distribution.ProfilePictureSize_Large, Distribution:local_user_id(), function(texture)
                if texture and alive(self._avatar_slot) then
                    self._avatar_slot:bitmap({ texture = texture, x = 15, y = 6, w = avatar_size, h = avatar_size, layer = 1 })
                end
            end)
        end)
    end
    
    local username = "Unknown Player"
    if Steam then
        pcall(function() 
            local name = Steam:username()
            if name and name ~= "" then username = name end
        end)
    end
    
    self._profile_name = profile_p:text({
        text = username,
        font = "fonts/font_medium_shadow_mf", font_size = 16,
        color = Color(0.9, 0.9, 0.9), x = 15 + avatar_size + 10, y = 5, layer = 1
    })
    
    self._profile_level = profile_p:text({
        text = "Lvl 0",
        font = "fonts/font_medium_shadow_mf", font_size = 14,
        color = Color(0.5, 0.5, 0.5), x = 15 + avatar_size + 10, y = 22, layer = 1
    })
    
    -- Tooltip Base
    self._tooltip_panel = self._panel:panel({ layer = 100, visible = false })
    self._tooltip_bg = self._tooltip_panel:rect({ color = Color(0.1, 0.1, 0.1), alpha = 0.95, layer = 0 })
    self._tooltip_border = self._tooltip_panel:rect({ color = NiceTrainer:GetAccentColor(), w = 2, layer = 1 })
    self._tooltip_text = self._tooltip_panel:text({ font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color.white, x = 10, y = 5, layer = 1 })
    
    if Hooks then Hooks:Call("NiceTrainer_InitTabs", self) end
    
    self:RefreshTabsVisibility()

    self:UpdateFooter()
    self:UpdatePlayerWidget()
end

function NiceTrainer:ShowTooltip(text, x, y)
    if not text then 
        self._tooltip_panel:set_visible(false)
        return 
    end
    
    self._tooltip_text:set_text(text)
    local _, _, w, h = self._tooltip_text:text_rect()
    self._tooltip_panel:set_size(w + 20, h + 10)
    self._tooltip_bg:set_size(w + 20, h + 10)
    self._tooltip_border:set_h(h + 10)
    
    local px, py = x + 15, y + 15
    if px + w + 20 > self._panel:w() then px = x - w - 20 end
    if py + h + 10 > self._panel:h() then py = y - h - 10 end
    
    self._tooltip_panel:set_position(px, py)
    self._tooltip_panel:set_visible(true)
end

function NiceTrainer:CreateTab(name, options, build_func)
    if type(options) == "function" then
        build_func = options
        options = { show_in = "all" }
    end
    options = options or { show_in = "all" }
    
    local tab_h = 32
    local y_pos = (self._tab_count * tab_h) + 10
    local logo_w = 250
    
    local btn_panel = self._sidebar_canvas:panel({ x = 0, y = y_pos, w = logo_w, h = tab_h, layer = 4 })
    local bg = btn_panel:rect({ color = Color.white, alpha = 0, layer = 0 })
    local indicator = btn_panel:rect({ color = NiceTrainer:GetAccentColor(), x = 0, y = 0, w = 4, h = tab_h, visible = false, layer = 1 })
    
    -- Icon / Bullet Point
    local icon = btn_panel:rect({ color = Color(0.5, 0.5, 0.5), x = 16, y = 12, w = 8, h = 8, layer = 2 })
    
    local text = btn_panel:text({
        text = string.upper(name),
        font = "fonts/font_medium_shadow_mf", font_size = 20,
        color = Color(0.7, 0.7, 0.7), x = 32, y = 6, layer = 2
    })
    
    local content_panel = self._content:panel({ visible = false, layer = 4 })
    local title_txt = content_panel:text({
        text = string.upper(name),
        font = "fonts/font_large_mf", font_size = 36,
        color = NiceTrainer:GetAccentColor(), x = 30, y = 30, layer = 2
    })
    local title_line = content_panel:rect({
        color = NiceTrainer:GetAccentColor(), x = 30, y = 70, w = 40, h = 3, layer = 2
    })
    
    local wrapper = content_panel:panel({ x = 0, y = 85, w = content_panel:w(), h = content_panel:h() - 85, layer = 3 })
    local canvas = wrapper:panel({ x = 0, y = 0, w = wrapper:w(), h = 0, layer = 1 })
    
    local scroll_bg = wrapper:rect({ color = Color.white, alpha = 0.05, x = wrapper:w() - 10, y = 0, w = 6, h = wrapper:h(), layer = 5, visible = false })
    local scrollbar = wrapper:rect({ color = NiceTrainer:GetAccentColor(), x = wrapper:w() - 10, y = 0, w = 6, h = 0, layer = 6, visible = false })
    
    table.insert(self.TabsList, name)
    self.Tabs[name] = { 
        panel = content_panel, wrapper = wrapper, canvas = canvas,
        indicator = indicator, text = text, icon = icon, y_offset = 10,
        title_txt = title_txt, title_line = title_line,
        scroll_bg = scroll_bg, scrollbar = scrollbar,
        btn_panel = btn_panel, options = options, el_index = #self.Elements + 1,
        build_func = build_func
    }
    
    local el = {
        panel = btn_panel, is_sidebar_btn = true,
        inside = function(self, mx, my) 
            if not NiceTrainer._sidebar:inside(mx, my) then return false end
            return btn_panel:inside(mx, my) 
        end,
        on_hover = function(self, hovered)
            bg:set_alpha(hovered and 0.05 or 0)
            if NiceTrainer.ActiveTab ~= name then
                text:set_color(hovered and Color.white or Color(0.7, 0.7, 0.7))
                icon:set_color(hovered and NiceTrainer:GetAccentColor() or Color(0.5, 0.5, 0.5))
            end
        end,
        on_click = function() NiceTrainer:SelectTab(name) end
    }
    table.insert(self.Elements, el)
    self._tab_count = self._tab_count + 1
    
    if build_func then build_func(self, name) end
end

function NiceTrainer:ApplyThemeColors()
    local acc = self:GetAccentColor()
    for name, tab in pairs(self.Tabs or {}) do
        if tab.indicator and alive(tab.indicator) then tab.indicator:set_color(acc) end
        if tab.title_txt and alive(tab.title_txt) then tab.title_txt:set_color(acc) end
        if tab.title_line and alive(tab.title_line) then tab.title_line:set_color(acc) end
        if tab.scrollbar and alive(tab.scrollbar) then tab.scrollbar:set_color(acc) end
        if tab.icon and alive(tab.icon) then
            if self.ActiveTab == name then
                tab.icon:set_color(acc)
            else
                tab.icon:set_color(Color(0.5, 0.5, 0.5))
            end
        end
    end
    if self._tooltip_border and alive(self._tooltip_border) then
        self._tooltip_border:set_color(acc)
    end
    if self.ActiveTab then
        self:RebuildTab(self.ActiveTab)
    end
end

function NiceTrainer:RebuildTab(tab_name)
    local tab = self.Tabs[tab_name]
    if not tab or not tab.build_func then return end

    -- Preserve the saved scroll position for this tab
    local saved_y = tab.saved_scroll_y or (alive(tab.canvas) and tab.canvas:y()) or 0

    -- Filter out existing elements for this tab
    local new_elements = {}
    for _, el in ipairs(self.Elements) do
        if not el.tab_name or el.tab_name ~= tab_name then
            table.insert(new_elements, el)
        end
    end
    self.Elements = new_elements

    -- Reset canvas
    if alive(tab.canvas) then
        tab.canvas:clear()
    end
    tab.y_offset = 10
    tab.canvas:set_h(0)

    -- Re-run builder
    tab.build_func(self, tab_name)

    -- Restore and clamp scroll position
    local wrapper_h = alive(tab.wrapper) and tab.wrapper:h() or 0
    local canvas_h = alive(tab.canvas) and tab.canvas:h() or 0

    if canvas_h > wrapper_h and wrapper_h > 0 then
        local min_y = wrapper_h - canvas_h - 10
        local target_y = saved_y
        if target_y > 0 then target_y = 0 end
        if target_y < min_y then target_y = min_y end
        tab.canvas:set_y(target_y)
        tab.saved_scroll_y = target_y
    else
        if alive(tab.canvas) then tab.canvas:set_y(0) end
        tab.saved_scroll_y = 0
    end

    self:UpdateScrollbar(tab_name)
end

function NiceTrainer:UpdateScrollbar(tab_name)
    local tab = self.Tabs[tab_name]
    if not tab or not tab.scrollbar or not alive(tab.scrollbar) or not alive(tab.wrapper) or not alive(tab.canvas) then return end
    
    local wrapper_h = tab.wrapper:h()
    local canvas_h = tab.canvas:h()
    
    if canvas_h > wrapper_h and wrapper_h > 0 then
        tab.scroll_bg:set_visible(true)
        tab.scrollbar:set_visible(true)
        
        local ratio = wrapper_h / canvas_h
        local bar_h = math.max(40, wrapper_h * ratio)
        tab.scrollbar:set_h(bar_h)
        
        local max_scroll = canvas_h - wrapper_h
        local current_y = -tab.canvas:y()
        local scroll_pct = current_y / (max_scroll > 0 and max_scroll or 1)
        
        tab.scrollbar:set_y(scroll_pct * (wrapper_h - bar_h))
    else
        tab.scroll_bg:set_visible(false)
        tab.scrollbar:set_visible(false)
    end
end

function NiceTrainer:CanRunTabAction(tab_name)
    local tab = self.Tabs[tab_name]
    if not tab then return false end
    local opt = tab.options or {}
    
    if type(opt.condition) == "function" and not opt.condition() then return false end

    local is_heist = self:IsInHeist()
    local is_menu = self:IsInMenu()
    local is_preplanning = self:IsInPrePlanning()
    
    if (opt.show_in == "heist" or opt.show_in == "game") and not is_heist then return false end
    if opt.show_in == "menu" and not is_menu and not is_preplanning then return false end
    if opt.show_in == "preplanning" and not is_preplanning then return false end
    return true
end

function NiceTrainer:RefreshTabsVisibility()
    local visible_count = 0
    local tab_h = 32
    local first_visible = nil
    
    for _, name in ipairs(self.TabsList) do
        local tab = self.Tabs[name]
        local show = self:CanRunTabAction(name)
        
        if show then
            tab.btn_panel:set_visible(true)
            tab.btn_panel:set_y((visible_count * tab_h) + 10)
            visible_count = visible_count + 1
            if not first_visible then first_visible = name end
            if tab.el_index and self.Elements[tab.el_index] then
                self.Elements[tab.el_index].disabled = false
            end
        else
            tab.btn_panel:set_visible(false)
            if tab.el_index and self.Elements[tab.el_index] then
                self.Elements[tab.el_index].disabled = true
            end
        end
    end
    
    self._visible_tab_count = visible_count
    self._sidebar_canvas:set_h((visible_count * tab_h) + 20)
    
    -- Restore previous sidebar scroll position if valid
    if self._sidebar_scroll_y and alive(self._sidebar_canvas) and alive(self._sidebar) then
        local wrapper_h = self._sidebar:h()
        local canvas_h = self._sidebar_canvas:h()
        if canvas_h > wrapper_h then
            local min_y = wrapper_h - canvas_h
            local target_y = math.max(min_y, math.min(0, self._sidebar_scroll_y))
            self._sidebar_canvas:set_y(target_y)
        else
            self._sidebar_canvas:set_y(0)
        end
    end
    
    -- Determine which tab should be active
    local target_tab = nil
    if self.ActiveTab and self:CanRunTabAction(self.ActiveTab) then
        target_tab = self.ActiveTab
    elseif self.Settings and self.Settings.last_active_tab and self:CanRunTabAction(self.Settings.last_active_tab) then
        target_tab = self.Settings.last_active_tab
    elseif self._last_active_tab and self:CanRunTabAction(self._last_active_tab) then
        target_tab = self._last_active_tab
    else
        target_tab = first_visible
    end

    if target_tab then
        self:SelectTab(target_tab)
    end
end

function NiceTrainer:SelectTab(name)
    if not name or not self.Tabs[name] then return end

    local is_tab_change = (self.ActiveTab ~= name)
    if is_tab_change then
        for tname, tab in pairs(self.Tabs) do 
            local is_active = (tname == name)
            tab.panel:set_visible(is_active)
            tab.indicator:set_visible(is_active)
            tab.text:set_color(is_active and Color.white or Color(0.7, 0.7, 0.7))
            tab.icon:set_color(is_active and NiceTrainer:GetAccentColor() or Color(0.5, 0.5, 0.5))
            
            if is_active then
                tab.panel:stop()
                tab.panel:animate(function(o)
                    local duration = 0.35
                    local t = 0
                    local start_x = 50
                    while t < duration do
                        local dt = coroutine.yield()
                        t = t + dt
                        local pct = math.min(t / duration, 1)
                        local ease = (pct == 1) and 1 or (1 - math.pow(2, -10 * pct))
                        o:set_x(start_x * (1 - ease))
                        o:set_alpha(ease)
                    end
                    o:set_x(0)
                    o:set_alpha(1)
                end)
            end
        end
        self.ActiveTab = name
        self._last_active_tab = name
        if self.Settings then
            self.Settings.last_active_tab = name
        end
    end

    self:RebuildTab(name)
    
    for _, el in pairs(self.Elements) do
        if el.tab_name and el.tab_name ~= name and el.hovered then
            el.hovered = false
            if el.on_hover then el:on_hover(false) end
        end
    end
    
    self:UpdateScrollbar(name)
end

function NiceTrainer:ScrollSidebar(amount)
    if not self._sidebar or not self._sidebar_canvas then return end
    
    local wrapper_h = self._sidebar:h()
    local canvas_h = self._sidebar_canvas:h()
    
    if canvas_h > wrapper_h then
        local current_y = self._sidebar_canvas:y()
        local min_y = wrapper_h - canvas_h
        local new_y = current_y + amount
        
        if new_y > 0 then new_y = 0 end
        if new_y < min_y then new_y = min_y end
        
        self._sidebar_canvas:set_y(new_y)
        self._sidebar_scroll_y = new_y
        
        if managers.mouse_pointer then
            local mx, my = managers.mouse_pointer:mouse()
            self:mouse_moved(nil, mx, my)
        end
    end
end

function NiceTrainer:ScrollActiveTab(amount)
    if not self.ActiveTab then return end
    local tab = self.Tabs[self.ActiveTab]
    if not tab or not tab.canvas or not tab.wrapper or not alive(tab.canvas) or not alive(tab.wrapper) then return end
    
    local wrapper_h = tab.wrapper:h()
    local canvas_h = tab.canvas:h()
    
    if canvas_h > wrapper_h then
        local current_y = tab.canvas:y()
        local min_y = wrapper_h - canvas_h - 10
        local new_y = current_y + amount
        
        if new_y > 0 then new_y = 0 end
        if new_y < min_y then new_y = min_y end
        
        tab.canvas:set_y(new_y)
        tab.saved_scroll_y = new_y
        self:UpdateScrollbar(self.ActiveTab)
        
        if managers.mouse_pointer then
            local mx, my = managers.mouse_pointer:mouse()
            self:mouse_moved(nil, mx, my)
        end
    end
end

function NiceTrainer:GetMenuKeybind()
    return "F1"
end

function NiceTrainer:UpdateFooter()
    if alive(self._footer_text) then
        local key = self:GetMenuKeybind()
        local version = self._version or "1.0"
        self._footer_text:set_text(string.format("NiceTrainer v%s   -   Overlay Key: [%s]", version, key))
    end
end

function NiceTrainer:UpdatePlayerWidget()
    if alive(self._profile_name) then
        local username = "Unknown Player"
        if Steam then
            pcall(function()
                local name = Steam:username()
                if name and name ~= "" then username = name end
            end)
        end
        self._profile_name:set_text(username)
    end
    
    if alive(self._profile_level) then
        local level_str = "Lvl 0"
        pcall(function()
            local lvl = 0
            local rank = 0
            if managers and managers.experience then
                lvl = tonumber(managers.experience:current_level()) or 0
                rank = tonumber(managers.experience:current_rank()) or 0
            end
            if lvl == 0 and Global and Global.experience_manager then
                lvl = tonumber(Global.experience_manager.level) or 0
                rank = tonumber(Global.experience_manager.rank) or 0
            end
            
            lvl = tonumber(lvl) or 0
            rank = tonumber(rank) or 0
            
            if lvl > 0 then
                if rank > 0 then
                    level_str = "Infamy " .. tostring(rank) .. " | Lvl " .. tostring(lvl)
                else
                    level_str = "Lvl " .. tostring(lvl)
                end
            elseif rank > 0 then
                level_str = "Infamy " .. tostring(rank) .. " | Lvl 0"
            else
                level_str = "Lvl 0"
            end
        end)
        self._profile_level:set_text(level_str)
    end
end

function NiceTrainer:Toggle()
    if self.IsModalOpen and not self.IsOpen then
        self:CloseModal()
        return
    end

    if self._panel and not alive(self._panel) then
        self._ws = nil
        self._panel = nil
        self.IsOpen = false
    end
    
    if not self._ws then self:InitUI() end
    self.IsOpen = not self.IsOpen
    self._panel:set_visible(self.IsOpen)
    
    if self.IsOpen then
        self:UpdateFooter()
        self:UpdatePlayerWidget()
        self:RefreshTabsVisibility()
        if self.ActiveTab then
            self:RebuildTab(self.ActiveTab)
        end
        
        if self.Settings.disclaimer_acknowledged ~= true and not self.IsModalOpen then
            self:ShowDisclaimerModal()
        end
        
        if game_state_machine and game_state_machine:current_state() then
            if game_state_machine:current_state().set_controller_enabled then
                game_state_machine:current_state():set_controller_enabled(false)
            end
        end
        
        if not self._mouse_id and managers.mouse_pointer then self._mouse_id = managers.mouse_pointer:get_id() end
        if managers.mouse_pointer then
            if managers.mouse_pointer._ws and alive(managers.mouse_pointer._ws) and managers.mouse_pointer._ws.panel then
                managers.mouse_pointer._ws:panel():set_layer(10000)
            end
            if managers.mouse_pointer._mouse and alive(managers.mouse_pointer._mouse) then
                managers.mouse_pointer._mouse:show()
            end
            managers.mouse_pointer:use_mouse({
                id = self._mouse_id,
                mouse_move = callback(self, self, "mouse_moved"),
                mouse_press = callback(self, self, "mouse_pressed"),
                mouse_release = callback(self, self, "mouse_release")
            })
        end
    else
        if game_state_machine and game_state_machine:current_state() then
            if game_state_machine:current_state().set_controller_enabled then
                game_state_machine:current_state():set_controller_enabled(true)
            end
        end
        if self._mouse_id and managers.mouse_pointer then managers.mouse_pointer:remove_mouse(self._mouse_id) end
    end
end

function NiceTrainer:mouse_moved(o, x, y)
    if not self.IsOpen and not self.IsModalOpen then return end
    
    -- Dragging must run even while a modal is open
    if self._dragging_slider then
        self._dragging_slider(x)
    end
    
    if self._colorpicker_dragging and self._colorpicker_update then
        self._colorpicker_update(x, y)
    end
    
    if self.IsModalOpen then
        for _, el in pairs(self._modal_elements) do
            if el:inside(x, y) then
                if not el.hovered then
                    el.hovered = true
                    if el.on_hover then el:on_hover(true) end
                end
            elseif el.hovered then
                el.hovered = false
                if el.on_hover then el:on_hover(false) end
            end
        end
        return -- Block normal menu interaction
    end
    
    local found_tooltip = false
    
    for _, el in pairs(self.Elements) do
        local is_visible = (el.is_sidebar_btn or el.is_global_btn or el.tab_name == self.ActiveTab)
        if is_visible and el.panel:visible() and el.panel:parent():visible() then
            if el:inside(x, y) then
                if el.tooltip then
                    self:ShowTooltip(el.tooltip, x, y)
                    found_tooltip = true
                end
                
                if not el.hovered then
                    el.hovered = true
                    if el.on_hover then el:on_hover(true) end
                end
            elseif el.hovered then
                el.hovered = false
                if el.on_hover then el:on_hover(false) end
            end
        elseif el.hovered then
            el.hovered = false
            if el.on_hover then el:on_hover(false) end
        end
    end
    
    if not found_tooltip then self:ShowTooltip(nil) end
end

function NiceTrainer:mouse_pressed(o, button, x, y)
    if not self.IsOpen and not self.IsModalOpen then return end
    
    if self._listening_for_key then
        local el = self._listening_for_key
        if button == Idstring("0") then
            self:CancelKeybind()
            return
        elseif button == Idstring("1") then
            self:ApplyKeybind(el, "mouse 1")
            return
        elseif button == Idstring("2") then
            self:ApplyKeybind(el, "mouse 2")
            return
        elseif button == Idstring("3") then
            self:ApplyKeybind(el, "mouse 3")
            return
        elseif button == Idstring("4") then
            self:ApplyKeybind(el, "mouse 4")
            return
        elseif button == Idstring("5") then
            self:ApplyKeybind(el, "mouse 5")
            return
        elseif button == Idstring("mouse wheel up") then
            self:ApplyKeybind(el, "mouse wheel up")
            return
        elseif button == Idstring("mouse wheel down") then
            self:ApplyKeybind(el, "mouse wheel down")
            return
        end
    end
    
    if self.IsModalOpen then
        if button == Idstring("mouse wheel up") then
            self:ScrollModal(40)
        elseif button == Idstring("mouse wheel down") then
            self:ScrollModal(-40)
        elseif button == Idstring("0") then
            for _, el in pairs(self._modal_elements) do
                if el.hovered and el.on_click then
                    el:on_click(x, y)
                    return
                end
            end
            -- If clicked outside modal box, we could close it, but let's just do nothing.
        end
        return -- Block normal menu interaction
    end
    
    if button == Idstring("mouse wheel up") then
        if self._sidebar:inside(x, y) then
            self:ScrollSidebar(40)
        else
            self:ScrollActiveTab(40)
        end
    elseif button == Idstring("mouse wheel down") then
        if self._sidebar:inside(x, y) then
            self:ScrollSidebar(-40)
        else
            self:ScrollActiveTab(-40)
        end
    elseif button == Idstring("0") then
        local clicked_something = false
        for _, el in pairs(self.Elements) do
            local is_visible = (el.is_sidebar_btn or el.is_global_btn or el.tab_name == self.ActiveTab)
            if is_visible and el.panel:visible() and el.panel:parent():visible() and el.hovered then
                if el.on_click then 
                    el:on_click(x, y) 
                    clicked_something = true
                    break 
                end
            end
        end
        if not clicked_something and self.SetFocusedInput then
            self:SetFocusedInput(nil)
        end
    end
end

function NiceTrainer:mouse_release(o, button, x, y)
    if self._dragging_slider then
        self._dragging_slider = nil
        self:Save()
    end
    
    if self._colorpicker_dragging then
        self._colorpicker_dragging = nil
    end
end
function NiceTrainer:PushModal(w, h, title)
    self._modals_stack = self._modals_stack or {}
    local depth = #self._modals_stack
    local layer = self._panel:panel({ layer = 3000 + (depth * 10) })
    layer:rect({ color = Color.black, alpha = (depth == 0) and 0.85 or 0.3, layer = 0 })
    
    local p = layer:panel({ 
        x = (layer:w() - w) / 2, 
        y = (layer:h() - h) / 2, 
        w = w, h = h, layer = 1 
    })
    
    p:rect({ color = Color(0.12, 0.12, 0.12), alpha = 0.98, layer = 0 })
    p:rect({ color = NiceTrainer:GetAccentColor(), w = 2, layer = 1 })
    p:rect({ color = NiceTrainer:GetAccentColor(), x = w - 2, w = 2, layer = 1 })
    p:rect({ color = NiceTrainer:GetAccentColor(), h = 2, layer = 1 })
    p:rect({ color = NiceTrainer:GetAccentColor(), y = h - 2, h = 2, layer = 1 })
    
    if title then
        p:text({ text = title, font = "fonts/font_large_mf", font_size = 28, color = Color.white, x = 20, y = 15, layer = 2 })
    end
    
    local close_p = p:panel({ x = w - 50, y = 15, w = 30, h = 30, layer = 2 })
    local close_txt = close_p:text({ text = "X", font = "fonts/font_large_mf", font_size = 28, align = "center", color = Color(0.8, 0.2, 0.2) })
    
    local modal_state = { layer = layer, panel = p, elements = {}, scroll = nil }
    table.insert(self._modals_stack, modal_state)
    self.IsModalOpen = true
    self._modal_elements = modal_state.elements
    
    table.insert(modal_state.elements, {
        panel = close_p, inside = function(self, mx, my) return close_p:inside(mx, my) end,
        on_hover = function(self, hovered) close_txt:set_color(hovered and Color.red or Color(0.8, 0.2, 0.2)) end,
        on_click = function(self) NiceTrainer:CloseModal() end
    })
    
    return p, modal_state
end

function NiceTrainer:CloseModal()
    self._modals_stack = self._modals_stack or {}
    local standalone = false
    if #self._modals_stack > 0 then
        local top = table.remove(self._modals_stack)
        standalone = top.standalone
        if alive(top.layer) then
            self._panel:remove(top.layer)
        end
    end
    if #self._modals_stack > 0 then
        local new_top = self._modals_stack[#self._modals_stack]
        self._modal_elements = new_top.elements
        self.IsModalOpen = true
    else
        self._modal_elements = {}
        self.IsModalOpen = false

        if standalone and not self.IsOpen then
            if alive(self._main) then self._main:set_visible(true) end
            if alive(self._bg) then self._bg:set_visible(true) end
            if alive(self._panel) then self._panel:set_visible(false) end
            if self._mouse_id then
                managers.mouse_pointer:remove_mouse(self._mouse_id)
            end
            if game_state_machine and game_state_machine:current_state() then
                if game_state_machine:current_state().set_controller_enabled then
                    game_state_machine:current_state():set_controller_enabled(true)
                end
            end
        end
    end
end

function NiceTrainer:ScrollModal(amount)
    self._modals_stack = self._modals_stack or {}
    if not self.IsModalOpen or #self._modals_stack == 0 then return end
    local top = self._modals_stack[#self._modals_stack]
    if not top.scroll then return end
    
    local wrapper_h = top.scroll.wrapper:h()
    local canvas_h = top.scroll.canvas:h()
    
    if canvas_h > wrapper_h then
        local current_y = top.scroll.canvas:y()
        local min_y = wrapper_h - canvas_h
        local new_y = math.clamp(current_y + amount, min_y, 0)
        top.scroll.canvas:set_y(new_y)
        
        if top.scroll.scrollbar and alive(top.scroll.scrollbar) then
            local max_scroll = canvas_h - wrapper_h
            local bar_h = top.scroll.scrollbar:h()
            local scroll_pct = -new_y / (max_scroll > 0 and max_scroll or 1)
            top.scroll.scrollbar:set_y(scroll_pct * (wrapper_h - bar_h))
        end
        
        if managers.mouse_pointer then
            local mx, my = managers.mouse_pointer:mouse()
            self:mouse_moved(nil, mx, my)
        end
    end
end

function NiceTrainer:ShowModal(title, items, callback_func)
    if not self._panel then return end
    items = items or {}
    local w, h = 450, 550
    local p, modal_state = self:PushModal(w, h, title)
    
    local scroll_p = p:panel({ x = 20, y = 70, w = w - 40, h = h - 90, layer = 2 })
    local canvas_h = math.max(scroll_p:h(), #items * 45)
    local canvas = scroll_p:panel({ x = 0, y = 0, w = scroll_p:w(), h = canvas_h, layer = 1 })
    modal_state.scroll = { wrapper = scroll_p, canvas = canvas }
    
    for i, item in ipairs(items) do
        local btn = canvas:panel({ x = 0, y = (i - 1) * 45, w = canvas:w() - 10, h = 40, layer = 2 })
        local bg = btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.05, layer = 0 })
        local txt = btn:text({ text = item.text, font = "fonts/font_medium_shadow_mf", font_size = 20, color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1 })
        
        table.insert(modal_state.elements, {
            panel = btn, wrapper = scroll_p, inside = function(self, mx, my) return scroll_p:inside(mx, my) and btn:inside(mx, my) end,
            on_hover = function(self, hovered)
                bg:set_alpha(hovered and 0.2 or 0.05)
                txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
            end,
            on_click = function(self)
                NiceTrainer:CloseModal()
                if callback_func then NiceTrainer:SafeCall(callback_func, item.value, item.text) end
            end
        })
    end
end

function NiceTrainer:ShowCustomModal(title, w, h, builder_callback)
    if not self._ws then return end
    local p, modal_state = self:PushModal(w, h, title)
    
    if builder_callback then
        NiceTrainer:SafeCall(builder_callback, p)
    end
end

-- =========================================================================================
-- ABOUT / CREDITS CONFIGURATION & MODAL
-- You can freely customize, add sections, or edit links and text below!
-- =========================================================================================

NiceTrainer.AboutData = {
    title = "NiceTrainer",
    subtitle = "STANDALONE ENGINE & CHEAT FRAMEWORK",
    description = "NiceTrainer is a modern, modular standalone cheat engine and developer framework for PAYDAY 2. Designed for high performance, game stability, thread-safe hooks, and clean Slate UI design.",
    sections = {
        {
            title = "DEVELOPMENT & ARCHITECTURE",
            items = {
                { text = "Framework Engine, UI System & Action Registry: NiceATC" }
            }
        },
        {
            title = "COMMUNITY ATTRIBUTIONS & RESEARCH CREDITS",
            items = {
                { text = "HexTrip (HexTrainer) - Dexterity mechanics, progression logic & anti-cheat research" },
                { text = "Baddog-11, baldwin & Pirate Perfection Team - Classic drills, sentries, AI & gameplay hooks" },
                { text = "Pierre Josselin (Ultimate Trainer / UT6) - Native Diesel UI concepts & utility foundations" },
                { text = "KILLBASE - Anti-griefing, stealth triggers & mission skip methods" },
                { text = "Complete All Side Jobs Community - Safehouse & side job completion routines" },
                { text = "Znixian (SuperBLT) & Luffy (BeardLib) - The foundation of PAYDAY 2 modding and hook architecture" },
                { text = "HopLib Community - Unit introspection & entity categorization logic" }
            }
        },
        {
            title = "DMCA & COPYRIGHT",
            items = {
                { text = "If you own content used here and want it removed, please contact us with the relevant details." },
                { text = "Valid removal requests will be reviewed and addressed accordingly." },
                { text = "This project is not affiliated with Overkill Software or Starbreeze Studios." },
                { text = "Created with care for the entire community, with the sole purpose of helping and sharing. No intention to steal, claim, or take credit for anyone's work." }
            }
        },
        {
            title = "USAGE & ATTRIBUTION",
            items = {
                { text = "Please play respectfully and avoid griefing public matches." }
            }
        },
        {
            title = "BETA STATUS & REFINEMENT",
            items = {
                { text = "NiceTrainer is currently in active Beta and is an evolving community framework." },
                { text = "You may encounter occasional edge cases or bugs across specific heists or mod loadouts." },
                { text = "Please report any bugs, crashes, or feedback with SuperBLT logs to help us refine and improve the trainer!" }
            }
        },
        {
            title = "USEFUL LINKS & RESOURCES",
            items = {
                { text = "UnknownCheats Forum", url = "https://www.unknowncheats.me/forum/payday-2-a/", desc = "PAYDAY 2 game reversing & research community" }
            }
        }
    }
}



function NiceTrainer:SetAboutData(data)
    if type(data) == "table" then
        self.AboutData = data
    end
end

function NiceTrainer:AddAboutSection(section)
    if not self.AboutData then self.AboutData = {} end
    if not self.AboutData.sections then self.AboutData.sections = {} end
    if type(section) == "table" then
        table.insert(self.AboutData.sections, section)
    end
end

function NiceTrainer:ShowAboutModal()
    if not self._ws then return end

    local version = "1.0"
    local f = io.open(self.ModPath .. "mod.txt", "r")
    if f then
        local f_content = f:read("*a")
        if f_content then
            local success, m_data = pcall(json.decode, f_content)
            if success and m_data and m_data.version then version = m_data.version end
        end
        f:close()
    end

    local data = self.AboutData or {}
    local w, h = 640, 520
    local p, modal_state = self:PushModal(w, h, (data.title or "NiceTrainer") .. " v" .. version)

    -- Subtitle
    p:text({
        text = data.subtitle or "STANDALONE ENGINE & FRAMEWORK",
        font = "fonts/font_medium_shadow_mf",
        font_size = 13,
        color = NiceTrainer:GetAccentColor(),
        x = 22, y = 46,
        layer = 2
    })

    -- Separator line
    p:rect({
        color = NiceTrainer:GetAccentColor(),
        alpha = 0.4,
        x = 20, y = 66,
        w = w - 40, h = 1,
        layer = 2
    })

    local bottom_bar_h = 52
    local scroll_y = 75
    local scroll_h = h - scroll_y - bottom_bar_h
    local scroll_p = p:panel({
        x = 20, y = scroll_y,
        w = w - 40, h = scroll_h,
        layer = 2
    })

    local canvas = scroll_p:panel({ x = 0, y = 0, w = scroll_p:w(), h = 1000, layer = 1 })
    modal_state.scroll = { wrapper = scroll_p, canvas = canvas }

    local cur_y = 6
    local content_w = canvas:w() - 14

    -- Description
    if data.description and data.description ~= "" then
        local desc_t = canvas:text({
            text = data.description,
            font = "fonts/font_medium_shadow_mf",
            font_size = 14,
            color = Color(0.85, 0.85, 0.85),
            x = 4, y = cur_y,
            w = content_w - 8,
            wrap = true,
            word_wrap = true,
            layer = 2
        })
        local _, _, _, dth = desc_t:text_rect()
        desc_t:set_h(dth)
        cur_y = cur_y + dth + 14
    end

    -- Sections
    if data.sections then
        for _, sec in ipairs(data.sections) do
            local sec_h = 24
            canvas:rect({
                color = NiceTrainer:GetAccentColor(),
                alpha = 0.12,
                x = 0, y = cur_y,
                w = content_w, h = sec_h,
                layer = 2
            })
            canvas:rect({
                color = NiceTrainer:GetAccentColor(),
                x = 0, y = cur_y,
                w = 3, h = sec_h,
                layer = 3
            })
            canvas:text({
                text = string.upper(sec.title or "INFO"),
                font = "fonts/font_medium_shadow_mf",
                font_size = 14,
                color = Color(0.3, 0.7, 1.0),
                x = 10, y = cur_y + 4,
                layer = 3
            })
            cur_y = cur_y + sec_h + 8

            local items = sec.items or sec.lines or {}
            for _, item in ipairs(items) do
                local item_text = type(item) == "string" and item or (item.text or "")
                local item_url = type(item) == "table" and item.url or nil
                local item_desc = type(item) == "table" and item.desc or nil

                if item_url then
                    local card_h = item_desc and 42 or 32
                    local card_p = canvas:panel({
                        x = 4, y = cur_y,
                        w = content_w - 8, h = card_h,
                        layer = 2
                    })
                    local c_bg = card_p:rect({ color = Color(0.18, 0.18, 0.18), alpha = 0.9, layer = 0 })
                    local b1 = card_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.35, w = 1, layer = 1 })
                    local b2 = card_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.35, x = card_p:w() - 1, w = 1, layer = 1 })
                    local b3 = card_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.35, h = 1, layer = 1 })
                    local b4 = card_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.35, y = card_p:h() - 1, h = 1, layer = 1 })

                    local tag_w = 46
                    card_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, x = 6, y = 6, w = tag_w, h = card_h - 12, layer = 2 })
                    card_p:text({
                        text = "LINK",
                        font = "fonts/font_medium_shadow_mf",
                        font_size = 12,
                        color = Color(0.3, 0.7, 1.0),
                        align = "center", vertical = "center",
                        x = 6, y = 6, w = tag_w, h = card_h - 12,
                        layer = 3
                    })

                    local txt_y = item_desc and 4 or 6
                    local title_t = card_p:text({
                        text = item_text,
                        font = "fonts/font_medium_shadow_mf",
                        font_size = 14,
                        color = Color.white,
                        x = 60, y = txt_y,
                        layer = 2
                    })

                    if item_desc then
                        card_p:text({
                            text = item_desc,
                            font = "fonts/font_medium_shadow_mf",
                            font_size = 12,
                            color = Color(0.6, 0.6, 0.6),
                            x = 60, y = txt_y + 17,
                            layer = 2
                        })
                    end

                    local action_lbl = card_p:text({
                        text = "Open / Copy >",
                        font = "fonts/font_medium_shadow_mf",
                        font_size = 13,
                        color = Color(0.5, 0.8, 1.0),
                        align = "right",
                        vertical = "center",
                        x = 0, y = 0,
                        w = card_p:w() - 12, h = card_h,
                        layer = 2
                    })

                    table.insert(modal_state.elements, {
                        panel = card_p,
                        wrapper = scroll_p,
                        inside = function(self, mx, my)
                            return scroll_p:inside(mx, my) and card_p:inside(mx, my)
                        end,
                        on_hover = function(self, hovered)
                            c_bg:set_color(hovered and Color(0.25, 0.25, 0.25) or Color(0.18, 0.18, 0.18))
                            local ba = hovered and 1.0 or 0.35
                            b1:set_alpha(ba)
                            b2:set_alpha(ba)
                            b3:set_alpha(ba)
                            b4:set_alpha(ba)
                            action_lbl:set_color(hovered and Color.white or Color(0.5, 0.8, 1.0))
                        end,
                        on_click = function()
                            pcall(function()
                                if Steam and Steam.overlay_activate then
                                    Steam:overlay_activate("url", item_url)
                                end
                                if Application and Application.set_clipboard then
                                    Application:set_clipboard(item_url)
                                end
                            end)
                            NiceTrainer:Toast("Opening: " .. item_url .. " (Copied to Clipboard)")
                        end
                    })

                    cur_y = cur_y + card_h + 6
                else
                    canvas:rect({
                        color = NiceTrainer:GetAccentColor(),
                        x = 6, y = cur_y + 6,
                        w = 4, h = 4,
                        layer = 2
                    })

                    local line_t = canvas:text({
                        text = item_text,
                        font = "fonts/font_medium_shadow_mf",
                        font_size = 14,
                        color = Color(0.85, 0.85, 0.85),
                        x = 18, y = cur_y,
                        w = content_w - 24,
                        wrap = true,
                        word_wrap = true,
                        layer = 2
                    })
                    local _, _, _, lth = line_t:text_rect()
                    line_t:set_h(lth)
                    cur_y = cur_y + math.max(18, lth + 4)
                end
            end

            cur_y = cur_y + 10
        end
    end

    local final_h = math.max(scroll_p:h(), cur_y + 10)
    canvas:set_h(final_h)

    -- Scrollbar indicator if needed
    if final_h > scroll_p:h() then
        local scroll_bg = scroll_p:rect({ color = Color.white, alpha = 0.05, x = scroll_p:w() - 6, y = 0, w = 4, h = scroll_p:h(), layer = 5 })
        local ratio = scroll_p:h() / final_h
        local bar_h = math.max(30, scroll_p:h() * ratio)
        local scrollbar = scroll_p:rect({ color = NiceTrainer:GetAccentColor(), x = scroll_p:w() - 6, y = 0, w = 4, h = bar_h, layer = 6 })
        modal_state.scroll.scrollbar = scrollbar
    end

    -- Bottom Bar
    p:rect({
        color = Color.white,
        alpha = 0.1,
        x = 20, y = h - bottom_bar_h,
        w = w - 40, h = 1,
        layer = 2
    })

    p:text({
        text = "NiceTrainer - PAYDAY 2 Modding Framework",
        font = "fonts/font_medium_shadow_mf",
        font_size = 13,
        color = Color(0.45, 0.45, 0.45),
        x = 25, y = h - bottom_bar_h + 16,
        layer = 2
    })

    local close_btn_w, close_btn_h = 100, 30
    local close_btn = p:panel({
        x = w - close_btn_w - 25,
        y = h - bottom_bar_h + 10,
        w = close_btn_w,
        h = close_btn_h,
        layer = 2
    })
    local cb_bg = close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
    close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.7, w = 1, layer = 1 })
    close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.7, x = close_btn_w - 1, w = 1, layer = 1 })
    close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.7, h = 1, layer = 1 })
    close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.7, y = close_btn_h - 1, h = 1, layer = 1 })

    local cb_txt = close_btn:text({
        text = "CLOSE",
        font = "fonts/font_medium_shadow_mf",
        font_size = 14,
        color = Color.white,
        align = "center",
        vertical = "center",
        layer = 2
    })

    table.insert(modal_state.elements, {
        panel = close_btn,
        inside = function(self, mx, my) return close_btn:inside(mx, my) end,
        on_hover = function(self, hovered)
            cb_bg:set_alpha(hovered and 0.5 or 0.2)
            cb_txt:set_color(hovered and Color.white or Color(0.9, 0.9, 0.9))
        end,
        on_click = function(self)
            NiceTrainer:CloseModal()
        end
    })
end

function NiceTrainer:ShowDisclaimerModal()
    if self._panel and not alive(self._panel) then
        self._ws = nil
        self._panel = nil
        self.IsOpen = false
    end

    if not self._ws then self:InitUI() end

    local was_open = self.IsOpen
    if not was_open then
        if alive(self._main) then self._main:set_visible(false) end
        if alive(self._bg) then self._bg:set_visible(false) end
        if alive(self._panel) then self._panel:set_visible(true) end

        if not self._mouse_id then self._mouse_id = managers.mouse_pointer:get_id() end
        if managers.mouse_pointer._ws and alive(managers.mouse_pointer._ws) and managers.mouse_pointer._ws.panel then
            managers.mouse_pointer._ws:panel():set_layer(10000)
        end
        if managers.mouse_pointer._mouse and alive(managers.mouse_pointer._mouse) then
            managers.mouse_pointer._mouse:show()
        end
        managers.mouse_pointer:use_mouse({
            id = self._mouse_id,
            mouse_move = callback(self, self, "mouse_moved"),
            mouse_press = callback(self, self, "mouse_pressed"),
            mouse_release = callback(self, self, "mouse_release")
        })
        if game_state_machine and game_state_machine:current_state() then
            if game_state_machine:current_state().set_controller_enabled then
                game_state_machine:current_state():set_controller_enabled(false)
            end
        end
    end

    local w, h = 660, 520
    local p, modal_state = self:PushModal(w, h, "COMMUNITY NOTICE & DISCLAIMER")
    modal_state.standalone = not was_open

    -- If closed via top-right 'X', mark as acknowledged and save
    if modal_state.elements and modal_state.elements[1] then
        modal_state.elements[1].on_click = function()
            NiceTrainer.Settings.disclaimer_acknowledged = true
            NiceTrainer:Save()
            NiceTrainer:CloseModal()
        end
    end

    -- Subtitle
    p:text({
        text = "FREE SOFTWARE & SECURITY WARNING",
        font = "fonts/font_medium_shadow_mf",
        font_size = 13,
        color = Color(1.0, 0.4, 0.4),
        x = 22, y = 46,
        layer = 2
    })

    -- Separator line
    p:rect({
        color = Color(1.0, 0.35, 0.35),
        alpha = 0.5,
        x = 20, y = 66,
        w = w - 40, h = 1,
        layer = 2
    })

    local bottom_bar_h = 56
    local scroll_y = 75
    local scroll_h = h - scroll_y - bottom_bar_h
    local scroll_p = p:panel({
        x = 20, y = scroll_y,
        w = w - 40, h = scroll_h,
        layer = 2
    })

    local canvas = scroll_p:panel({ x = 0, y = 0, w = scroll_p:w(), h = 800, layer = 1 })
    modal_state.scroll = { wrapper = scroll_p, canvas = canvas }

    local cur_y = 6
    local content_w = canvas:w() - 14

    local sections = {
        {
            title = "100% FREE COMMUNITY SOFTWARE",
            header_color = Color(0.2, 0.8, 0.4),
            text = "NiceTrainer is completely FREE and open-source. It was created for the PAYDAY 2 modding community. There are NO VIP memberships, NO paid keys, and NO premium tiers."
        },
        {
            title = "SCAM ALERT - IF YOU PAID, YOU WERE SCAMMED!",
            header_color = Color(1.0, 0.3, 0.3),
            text = "If you paid ANY money to download this trainer, purchased an 'activation key', or bought it from a reseller on YouTube, Discord, Telegram, or any marketplace: YOU HAVE BEEN SCAMMED!\n\nPlease demand an immediate refund or open a chargeback / payment dispute with your provider."
        },
        {
            title = "OFFICIAL & SAFE DOWNLOAD LOCATION",
            header_color = NiceTrainer:GetAccentColor(),
            text = "The ONLY official, safe, and verified place to download NiceTrainer and its official updates is UnknownCheats (and the official GitHub repository).\n\nDownloading from third-party websites or re-uploaded links puts you at high risk of malware, keyloggers, and account theft.",
            link = "https://www.unknowncheats.me/forum/payday-2/"
        },
        {
            title = "USAGE & FAIR PLAY",
            header_color = Color(0.9, 0.7, 0.2),
            text = "This mod is provided for educational purposes and private play. Please use features responsibly and avoid disrupting the gameplay of legitimate players in public lobbies."
        }
    }

    for _, sec in ipairs(sections) do
        local header_h = 24
        canvas:rect({
            color = sec.header_color,
            alpha = 0.12,
            x = 0, y = cur_y,
            w = content_w, h = header_h,
            layer = 2
        })
        canvas:rect({
            color = sec.header_color,
            x = 0, y = cur_y,
            w = 3, h = header_h,
            layer = 3
        })
        canvas:text({
            text = sec.title,
            font = "fonts/font_medium_shadow_mf",
            font_size = 14,
            color = sec.header_color,
            x = 10, y = cur_y + 4,
            layer = 3
        })
        cur_y = cur_y + header_h + 6

        local body_t = canvas:text({
            text = sec.text,
            font = "fonts/font_medium_shadow_mf",
            font_size = 14,
            color = Color(0.88, 0.88, 0.88),
            x = 8, y = cur_y,
            w = content_w - 16,
            wrap = true,
            word_wrap = true,
            layer = 2
        })
        local _, _, _, bth = body_t:text_rect()
        body_t:set_h(bth)
        cur_y = cur_y + bth + 8

        if sec.link then
            local link_w = content_w - 16
            local link_h = 30
            local link_p = canvas:panel({
                x = 8, y = cur_y,
                w = link_w, h = link_h,
                layer = 2
            })
            local l_bg = link_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.15, layer = 0 })
            local lb1 = link_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.4, w = 1, layer = 1 })
            local lb2 = link_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.4, x = link_w - 1, w = 1, layer = 1 })
            local lb3 = link_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.4, h = 1, layer = 1 })
            local lb4 = link_p:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.4, y = link_h - 1, h = 1, layer = 1 })

            local l_txt = link_p:text({
                text = "Visit UnknownCheats Official Release Thread >",
                font = "fonts/font_medium_shadow_mf",
                font_size = 13,
                color = Color(0.4, 0.8, 1.0),
                align = "center",
                vertical = "center",
                layer = 2
            })

            table.insert(modal_state.elements, {
                panel = link_p,
                wrapper = scroll_p,
                inside = function(self, mx, my)
                    return scroll_p:inside(mx, my) and link_p:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    l_bg:set_alpha(hovered and 0.35 or 0.15)
                    local ba = hovered and 0.9 or 0.4
                    lb1:set_alpha(ba); lb2:set_alpha(ba); lb3:set_alpha(ba); lb4:set_alpha(ba)
                    l_txt:set_color(hovered and Color.white or Color(0.4, 0.8, 1.0))
                end,
                on_click = function()
                    local item_url = sec.link
                    pcall(function()
                        if Steam and Steam.overlay_activate then
                            Steam:overlay_activate("url", item_url)
                        end
                        if Application and Application.set_clipboard then
                            Application:set_clipboard(item_url)
                        end
                    end)
                    NiceTrainer:Toast("Opening UnknownCheats... (URL copied to clipboard)")
                end
            })

            cur_y = cur_y + link_h + 10
        end

        cur_y = cur_y + 8
    end

    local final_h = math.max(scroll_p:h(), cur_y + 10)
    canvas:set_h(final_h)

    if final_h > scroll_p:h() then
        local ratio = scroll_p:h() / final_h
        local bar_h = math.max(30, scroll_p:h() * ratio)
        local scrollbar = scroll_p:rect({ color = NiceTrainer:GetAccentColor(), x = scroll_p:w() - 6, y = 0, w = 4, h = bar_h, layer = 6 })
        modal_state.scroll.scrollbar = scrollbar
    end

    -- Bottom Bar
    p:rect({
        color = Color.white,
        alpha = 0.1,
        x = 20, y = h - bottom_bar_h,
        w = w - 40, h = 1,
        layer = 2
    })

    local confirm_btn_w, confirm_btn_h = 240, 36
    local confirm_btn = p:panel({
        x = (w - confirm_btn_w) / 2,
        y = h - bottom_bar_h + 10,
        w = confirm_btn_w,
        h = confirm_btn_h,
        layer = 2
    })
    local cb_bg = confirm_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.25, layer = 0 })
    local cb1 = confirm_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.8, w = 1, layer = 1 })
    local cb2 = confirm_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.8, x = confirm_btn_w - 1, w = 1, layer = 1 })
    local cb3 = confirm_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.8, h = 1, layer = 1 })
    local cb4 = confirm_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.8, y = confirm_btn_h - 1, h = 1, layer = 1 })

    local cb_txt = confirm_btn:text({
        text = "I UNDERSTAND & AGREE",
        font = "fonts/font_medium_shadow_mf",
        font_size = 15,
        color = Color.white,
        align = "center",
        vertical = "center",
        layer = 2
    })

    local function acknowledge_and_close()
        NiceTrainer.Settings.disclaimer_acknowledged = true
        NiceTrainer:Save()
        NiceTrainer:CloseModal()
        NiceTrainer:Toast("Disclaimer acknowledged. Welcome to NiceTrainer!")
    end

    table.insert(modal_state.elements, {
        panel = confirm_btn,
        inside = function(self, mx, my) return confirm_btn:inside(mx, my) end,
        on_hover = function(self, hovered)
            cb_bg:set_alpha(hovered and 0.55 or 0.25)
            local ba = hovered and 1.0 or 0.8
            cb1:set_alpha(ba); cb2:set_alpha(ba); cb3:set_alpha(ba); cb4:set_alpha(ba)
            cb_txt:set_color(hovered and Color.white or Color(0.9, 0.9, 0.9))
        end,
        on_click = function(self)
            acknowledge_and_close()
        end
    })
end

function NiceTrainer:ShowConfirmDialog(title, message, options)
    if not self._ws then return end

    local w, h = 540, 260
    local p, modal_state = self:PushModal(w, h, title or "Confirmation")
    local top_modal = modal_state

    -- Message text (wrapped)
    local msg_text = p:text({
        text = message or "",
        font = "fonts/font_medium_shadow_mf",
        font_size = 16,
        color = Color(0.85, 0.85, 0.85),
        x = 22, y = 58,
        w = w - 44,
        wrap = true,
        word_wrap = true,
        layer = 2
    })
    local _, _, tw, th = msg_text:text_rect()
    msg_text:set_h(th)

    -- Dynamic height expansion if message is long
    local required_h = math.max(h, 60 + th + 80)
    if required_h > h then
        p:set_h(required_h)
        p:set_y((p:parent():h() - required_h) / 2)
    end

    -- Options / Buttons
    options = options or {
        { text = "OK", color = NiceTrainer:GetAccentColor(), callback = function() end }
    }

    local btn_h = 36
    local spacing = 10
    local btn_w = math.floor((w - 44 - (#options - 1) * spacing) / #options)
    local btn_y = p:h() - btn_h - 18

    for i, opt in ipairs(options) do
        local btn_x = 22 + (i - 1) * (btn_w + spacing)
        local btn_p = p:panel({ x = btn_x, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local btn_col = opt.color or NiceTrainer:GetAccentColor()
        local bg = btn_p:rect({ color = btn_col, alpha = 0.2, layer = 0 })
        btn_p:rect({ color = btn_col, w = 1, layer = 1 })
        btn_p:rect({ color = btn_col, x = btn_w - 1, w = 1, layer = 1 })
        btn_p:rect({ color = btn_col, h = 1, layer = 1 })
        btn_p:rect({ color = btn_col, y = btn_h - 1, h = 1, layer = 1 })

        local txt = btn_p:text({
            text = opt.text, font = "fonts/font_medium_shadow_mf", font_size = 15,
            color = Color.white, align = "center", vertical = "center", layer = 2
        })

        table.insert(top_modal.elements, {
            panel = btn_p,
            inside = function(self, mx, my) return btn_p:inside(mx, my) end,
            on_hover = function(self, hovered)
                bg:set_alpha(hovered and 0.5 or 0.2)
                txt:set_color(hovered and Color.white or Color(0.9, 0.9, 0.9))
            end,
            on_click = function(self)
                NiceTrainer:CloseModal()
                if opt.callback then
                    NiceTrainer:SafeCall(opt.callback)
                end
            end
        })
    end
end


local function hsv2rgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return r + m, g + m, b + m
end

local function rgb2hsv(r, g, b)
    local cmax = math.max(r, g, b)
    local cmin = math.min(r, g, b)
    local delta = cmax - cmin
    
    local h = 0
    if delta == 0 then h = 0
    elseif cmax == r then h = 60 * (((g - b) / delta) % 6)
    elseif cmax == g then h = 60 * (((b - r) / delta) + 2)
    elseif cmax == b then h = 60 * (((r - g) / delta) + 4)
    end
    if h < 0 then h = h + 360 end
    
    local s = (cmax == 0) and 0 or (delta / cmax)
    local v = cmax
    return h, s, v
end

function NiceTrainer:ShowColorPickerModal(title, start_color, callback_func)
    if not self._ws then return end

    if type(start_color) == "string" then
        local hex = start_color:gsub("#", "")
        if #hex == 6 then
            local r = tonumber(hex:sub(1, 2), 16) or 255
            local g = tonumber(hex:sub(3, 4), 16) or 255
            local b = tonumber(hex:sub(5, 6), 16) or 255
            start_color = Color(r / 255, g / 255, b / 255)
        else
            start_color = Color.white
        end
    elseif not start_color or type(start_color) ~= "userdata" or not start_color.r then
        start_color = Color.white
    end

    local p, modal_state = self:PushModal(450, 400, title)
    local content_p = p:panel({ x = 20, y = 70, w = 410, h = 310, layer = 2 })
    
    local r, g, b = start_color.r or 1, start_color.g or 1, start_color.b or 1
    local hue, sat, val = rgb2hsv(r, g, b)
    
    local gamut_w, gamut_h = 256, 256
    local gamut_x, gamut_y = 10, 10
    
    local gamut_bg = content_p:rect({ color = Color.white, x = gamut_x, y = gamut_y, w = gamut_w, h = gamut_h, layer = 1 })
    
    local gamut_s = content_p:gradient({
        x = gamut_x, y = gamut_y, w = gamut_w, h = gamut_h, layer = 2,
        gradient_points = {0, Color.white, 1, Color(hsv2rgb(hue, 1, 1))},
        orientation = "horizontal"
    })
    
    local gamut_v = content_p:gradient({
        x = gamut_x, y = gamut_y, w = gamut_w, h = gamut_h, layer = 3,
        gradient_points = {0, Color(0,0,0,0), 1, Color(1,0,0,0)},
        orientation = "vertical"
    })
    
    local gamut_cursor = content_p:rect({
        x = gamut_x + (sat * gamut_w) - 4,
        y = gamut_y + ((1 - val) * gamut_h) - 4,
        w = 8, h = 8, layer = 4, color = Color(0,0,0,0)
    })
    
    local cursor_border = {
        top = content_p:rect({ name="cursor_top", x=gamut_cursor:x(), y=gamut_cursor:y(), w=8, h=2, layer=5, color=Color.white }),
        bottom = content_p:rect({ name="cursor_bottom", x=gamut_cursor:x(), y=gamut_cursor:y()+6, w=8, h=2, layer=5, color=Color.white }),
        left = content_p:rect({ name="cursor_left", x=gamut_cursor:x(), y=gamut_cursor:y(), w=2, h=8, layer=5, color=Color.white }),
        right = content_p:rect({ name="cursor_right", x=gamut_cursor:x()+6, y=gamut_cursor:y(), w=2, h=8, layer=5, color=Color.white }),
    }
    
    local hue_x = gamut_x + gamut_w + 20
    local hue_w = 20
    local hue_h = gamut_h
    
    local hue_colors = {
        Color(1,0,0), Color(1,1,0), Color(0,1,0), Color(0,1,1),
        Color(0,0,1), Color(1,0,1), Color(1,0,0)
    }
    local hue_points = {}
    for i, c in ipairs(hue_colors) do
        table.insert(hue_points, (i-1)/(#hue_colors-1))
        table.insert(hue_points, c)
    end
    
    local hue_gradient = content_p:gradient({
        x = hue_x, y = gamut_y, w = hue_w, h = hue_h, layer = 2,
        gradient_points = hue_points,
        orientation = "vertical"
    })
    
    local hue_cursor = content_p:rect({
        x = hue_x - 2, y = gamut_y + (hue/360 * hue_h) - 2,
        w = hue_w + 4, h = 4, layer = 3, color = Color.white
    })
    
    local preview_w, preview_h = 70, 70
    local preview_x = hue_x + hue_w + 20
    
    local old_preview = content_p:rect({ color = start_color, x = preview_x, y = gamut_y, w = preview_w, h = preview_h/2, layer = 2 })
    local current_preview = content_p:rect({ color = start_color, x = preview_x, y = gamut_y + preview_h/2, w = preview_w, h = preview_h/2, layer = 2 })
    content_p:rect({ color = Color.white, x = preview_x-2, y = gamut_y-2, w = preview_w+4, h = preview_h+4, layer = 1 })
    
    local hex_text = content_p:text({
        text = string.format("#%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255)),
        font = "fonts/font_medium_shadow_mf", font_size = 20,
        x = preview_x - 10, y = gamut_y + preview_h + 10, w = preview_w + 20, align = "center", color = Color.white, layer = 2
    })
    
    local accept_btn = content_p:panel({ x = preview_x - 10, y = gamut_y + gamut_h - 40, w = preview_w + 20, h = 40, layer = 2 })
    local accept_bg = accept_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
    accept_btn:rect({ color = NiceTrainer:GetAccentColor(), w = 2, layer = 1 })
    accept_btn:rect({ color = NiceTrainer:GetAccentColor(), x = accept_btn:w() - 2, w = 2, layer = 1 })
    accept_btn:text({ text = "Accept", font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = Color.white, layer = 2 })
    
    local function update_color()
        local new_r, new_g, new_b = hsv2rgb(hue, sat, val)
        local c = Color(new_r, new_g, new_b)
        current_preview:set_color(c)
        gamut_s:set_gradient_points({0, Color.white, 1, Color(hsv2rgb(hue, 1, 1))})
        hex_text:set_text(string.format("#%02X%02X%02X", math.floor(new_r*255), math.floor(new_g*255), math.floor(new_b*255)))
    end
    
    local function set_cursor_pos()
        local cx = gamut_x + (sat * gamut_w) - 4
        local cy = gamut_y + ((1 - val) * gamut_h) - 4
        cursor_border.top:set_position(cx, cy)
        cursor_border.bottom:set_position(cx, cy + 6)
        cursor_border.left:set_position(cx, cy)
        cursor_border.right:set_position(cx + 6, cy)
    end
    
    table.insert(modal_state.elements, {
        panel = gamut_bg, inside = function(self, mx, my) return content_p:inside(mx, my) and gamut_bg:inside(mx, my) end,
        on_click = function(self, mx, my)
            NiceTrainer._colorpicker_dragging = "gamut"
            local local_x = mx - gamut_bg:world_x()
            local local_y = my - gamut_bg:world_y()
            sat = math.clamp(local_x / gamut_w, 0, 1)
            val = 1 - math.clamp(local_y / gamut_h, 0, 1)
            set_cursor_pos()
            update_color()
        end
    })
    
    table.insert(modal_state.elements, {
        panel = hue_gradient, inside = function(self, mx, my) return content_p:inside(mx, my) and hue_gradient:inside(mx, my) end,
        on_click = function(self, mx, my)
            NiceTrainer._colorpicker_dragging = "hue"
            local local_y = my - hue_gradient:world_y()
            local pct = math.clamp(local_y / hue_h, 0, 1)
            hue = pct * 360
            hue_cursor:set_y(gamut_y + (pct * hue_h) - 2)
            update_color()
        end
    })
    
    table.insert(modal_state.elements, {
        panel = accept_btn, inside = function(self, mx, my) return accept_btn:inside(mx, my) end,
        on_hover = function(self, hovered) accept_bg:set_alpha(hovered and 0.4 or 0.2) end,
        on_click = function(self)
            local final_r, final_g, final_b = hsv2rgb(hue, sat, val)
            local c = Color(final_r, final_g, final_b)
            local hex = string.format("#%02X%02X%02X", math.floor(final_r * 255 + 0.5), math.floor(final_g * 255 + 0.5), math.floor(final_b * 255 + 0.5))
            NiceTrainer:CloseModal()
            if callback_func then NiceTrainer:SafeCall(callback_func, c, hex) end
        end
    })
    
    self._colorpicker_gamut_bg = gamut_bg
    self._colorpicker_hue_bg = hue_gradient
    self._colorpicker_update = function(mx, my)
        if NiceTrainer._colorpicker_dragging == "gamut" then
            local local_x = mx - self._colorpicker_gamut_bg:world_x()
            local local_y = my - self._colorpicker_gamut_bg:world_y()
            sat = math.clamp(local_x / gamut_w, 0, 1)
            val = 1 - math.clamp(local_y / gamut_h, 0, 1)
            set_cursor_pos()
            update_color()
        elseif NiceTrainer._colorpicker_dragging == "hue" then
            local local_y = my - self._colorpicker_hue_bg:world_y()
            local pct = math.clamp(local_y / hue_h, 0, 1)
            hue = pct * 360
            hue_cursor:set_y(gamut_y + (pct * hue_h) - 2)
            update_color()
        end
    end
end

function NiceTrainer:ShowSliderModal(title, min_val, max_val, current_val, callback_func)
    if not self._ws then return end
    local p, modal_state = self:PushModal(450, 250, title)
    
    local w = 410
    local pnl = p:panel({ x = 20, y = 70, w = w, h = 150, layer = 2 })
    
    local val_text = pnl:text({
        text = string.format("%.2f", current_val), font = "fonts/font_large_mf", font_size = 32,
        color = NiceTrainer:GetAccentColor(), x = 0, y = 20, w = w, align = "center", layer = 1
    })
    
    local track = pnl:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.3, x = 20, y = 80, w = w - 40, h = 4, layer = 1 })
    
    local function get_x_for_val(v)
        local pct = (v - min_val) / (max_val - min_val)
        return 20 + pct * (w - 40)
    end
    
    local knob = pnl:rect({ color = NiceTrainer:GetAccentColor(), w = 12, h = 24, layer = 2 })
    knob:set_center(get_x_for_val(current_val), track:center_y())
    
    local update_slider = function(mx)
        local track_x1 = pnl:world_x() + 20
        local pct = math.clamp((mx - track_x1) / (w - 40), 0, 1)
        current_val = min_val + pct * (max_val - min_val)
        knob:set_center_x(20 + pct * (w - 40))
        val_text:set_text(string.format("%.2f", current_val))
        if callback_func then NiceTrainer:SafeCall(callback_func, current_val) end
    end
    
    table.insert(modal_state.elements, {
        panel = pnl,
        inside = function(self, mx, my)
            return pnl:inside(mx, my) and my >= pnl:world_y() + 60 and my <= pnl:world_y() + 100
        end,
        on_hover = function(self, hovered)
            knob:set_color(hovered and Color.white or NiceTrainer:GetAccentColor())
        end,
        on_click = function(self, mx, my)
            NiceTrainer._dragging_slider = update_slider
            update_slider(mx)
        end
    })
    
    local btn_w = 120
    local close_btn = pnl:panel({ x = (w - btn_w) / 2, y = 110, w = btn_w, h = 30, layer = 2 })
    local close_bg = close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
    close_btn:text({ text = "Close", font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = Color.white, layer = 2 })
    
    table.insert(modal_state.elements, {
        panel = close_btn,
        inside = function(self, mx, my) return close_btn:inside(mx, my) end,
        on_hover = function(self, hovered) close_bg:set_alpha(hovered and 0.4 or 0.2) end,
        on_click = function(self) NiceTrainer:CloseModal() end
    })
end

if Hooks then
    Hooks:Add("SavefileManagerOnLoadedSavefile", "NiceTrainer_OnSavefileLoaded", function()
        if NiceTrainer then
            NiceTrainer:UpdateFooter()
            NiceTrainer:UpdatePlayerWidget()
        end
    end)
    pcall(function()
        if type(SavefileManager) == "table" and type(SavefileManager._on_load_sequence_complete) == "function" then
            Hooks:PostHook(SavefileManager, "_on_load_sequence_complete", "NiceTrainer_SavefileLoadedPost", function()
                if NiceTrainer then
                    NiceTrainer:UpdateFooter()
                    NiceTrainer:UpdatePlayerWidget()
                end
            end)
        end
    end)
end


