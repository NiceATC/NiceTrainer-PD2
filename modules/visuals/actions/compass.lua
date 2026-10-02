-- ─── Tactical Compass HUD Element (Visuals Tab) ──────────────────────────────
-- Authentic 1:1 integration of Offyerrocker's HUD Compass (KineticHUD Standalone).
-- Renders the exact original compass strip, fonts, cardinal texts, ticks, and gradient shine.

_G.CompassStandalone = _G.CompassStandalone or {}
local CompassStandalone = _G.CompassStandalone

CompassStandalone.settings = CompassStandalone.settings or {
    enabled = false,
    panel_compass_alpha = 1,
    panel_compass_y = 0,
    compass_color = "FFFFFF",
    compass_color_bg = "FFFFFF",
    compass_bg_blend_mode = "add"
}

function CompassStandalone:IsEnabled()
    return self.settings.enabled
end

function CompassStandalone:Update(t, dt)
    local player = managers.player and managers.player:local_player()
    if player and alive(player) and player:movement() then 
        local rotlook = player:movement():m_head_rot()
        self:_set_compass(rotlook)
    elseif managers.viewport then
        local cam_rot = managers.viewport:get_current_camera_rotation()
        if cam_rot then
            self:_set_compass(cam_rot)
        end
    end
end

local function clean_hex(color_val)
    if type(color_val) == "string" then
        return color_val:gsub("#", "")
    end
    return "2EA1FF"
end

function CompassStandalone:_create_khud_compass(hud_panel)
    if self._panel and alive(self._panel) then
        pcall(function() hud_panel:remove(self._panel) end)
        self._panel = nil
    end

    local hex_fg = clean_hex(self.settings.compass_color)
    local hex_bg = clean_hex(self.settings.compass_color_bg or self.settings.compass_color)

    local compass_color = Color(hex_fg)
    local compass_color_bg = Color(hex_bg)

    local function get_cardinal(angle)
        angle = tostring(angle)
        local cardinal = {
            ["0"] = "N",
            ["45"] = "NW",
            ["90"] = "W",
            ["135"] = "SW",
            ["180"] = "S",
            ["225"] = "SE",
            ["270"] = "E",
            ["315"] = "NE",
            ["360"] = "N"
        }
        return cardinal[angle] or angle
    end
    
    local mul = 2
    local degrees = 360
    local compass_w = hud_panel:w() * mul
    local compass_h = 16
    local compass_y = compass_h * 2
    
    local tick_margin = compass_w / (degrees * mul)

    local compass_panel = hud_panel:panel({
        name = "compass_panel",
        visible = self:IsEnabled(),
        layer = 0,
        x = 0,
        y = self.settings.panel_compass_y or compass_y,
        w = compass_w
    })
    
    local compass_strip = compass_panel:panel({
        name = "compass_strip",
        layer = 0,
        x = (hud_panel:w() - compass_w) / 2,
        h = compass_h * 2
    })
    
    local ticks = math.floor(compass_w / tick_margin)
    local ammo_font = tweak_data.hud_players and tweak_data.hud_players.ammo_font or "fonts/font_large_mf"
    
    local alpha = 0.5
    for i = 0, ticks, 1 do 
        if (i % (degrees / 4)) == 0 then -- 90
            alpha = 1
            local newtick = compass_strip:text({
                name = "direction_" .. tostring(i),
                color = compass_color,
                layer = 2,
                font = ammo_font,
                font_size = compass_h,
                x = (i * tick_margin),
                vertical = "bottom",
                alpha = alpha,
                text = get_cardinal(i % degrees)
            })
            local _, _, text_w, _ = newtick:text_rect()
            newtick:move(-text_w * 0.25)
        elseif (i % (degrees / 8)) == 0 then -- 45
            alpha = 0.75
            local newtick = compass_strip:text({
                name = "direction_" .. tostring(i),
                color = compass_color,
                layer = 2,
                font = ammo_font,
                font_size = compass_h * 0.75,
                x = (i * tick_margin),
                vertical = "bottom",
                alpha = alpha,
                text = get_cardinal(i % degrees)
            })
            local _, _, text_w, _ = newtick:text_rect()
            newtick:move(-text_w * 0.25)
        elseif (i % (degrees / 24)) == 0 then -- 15
            alpha = 0.5
            compass_strip:text({
                name = "direction_" .. tostring(i),
                color = compass_color,
                layer = 2,
                font = ammo_font,
                font_size = compass_h * 0.5,
                x = (i * tick_margin) + 4,
                alpha = alpha,
                text = get_cardinal(i % degrees)
            })
        else
            alpha = 0.25
        end
        compass_strip:text({
            name = "tick_" .. tostring(i),
            color = compass_color,
            layer = 1,
            font = ammo_font,
            font_size = compass_h,
            x = i * tick_margin,
            alpha = alpha,
            text = "|"
        })
    end

    local backdrop = compass_panel:rect({
        name = "backdrop",
        layer = 0,
        blend_mode = "sub",
        color = Color.black:with_alpha(0.5),
    })
    
    local shine = compass_panel:gradient({
        name = "khud_compass_shine",
        layer = 1,
        blend_mode = self.settings.compass_bg_blend_mode or "add",
        w = hud_panel:w(),
        h = compass_h,
        valign = "grow",
        gradient_points = {
            0,
            Color(0, 1, 1, 1),
            0.3,
            compass_color_bg:with_alpha(0),
            0.5,
            compass_color_bg:with_alpha(0.2),
            0.8,
            compass_color_bg:with_alpha(0),
            1,
            Color(0, 1, 1, 1)
        }
    })

    self._panel = compass_panel
    self:_layout_compass_panel()
    return compass_panel
end

function CompassStandalone:_set_compass(veclook)
    local panel = self._panel
    if panel and alive(panel) and self:IsEnabled() then 
        local yaw = veclook:yaw()
        local compass = panel:child("compass_strip")
        if compass and alive(compass) then
            local compass_yaw = (0.5 + (math.rad(yaw * 0.25) / math.pi)) - 0.75
            compass:set_x(compass_yaw * panel:w())
        end
    end
end

function CompassStandalone:_layout_compass_panel(params)
    local compass = self._panel
    if compass and alive(compass) then 
        params = params or {}
        local settings = self.settings
        local alpha = params.alpha or settings.panel_compass_alpha or 1
        local y = params.y or settings.panel_compass_y or 64
        
        compass:set_alpha(alpha)
        compass:set_visible(self:IsEnabled())
        compass:set_y(y)
    end
end

function CompassStandalone:EnsureHUD()
    if managers.hud then
        local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
        if hud and hud.panel then
            if not self._panel or not alive(self._panel) then
                self:_create_khud_compass(hud.panel)
            else
                self:_layout_compass_panel()
            end

            if self:IsEnabled() then
                managers.hud:add_updator("_update_hud_compass_standalone", callback(self, self, "Update"))
            else
                managers.hud:remove_updator("_update_hud_compass_standalone")
            end
        end
    end
end

-- ============================================================================
-- Game HUD Hooks
-- ============================================================================
if _G.HUDManager and not HUDManager._nt_compass_hooked then
    HUDManager._nt_compass_hooked = true
    Hooks:PostHook(HUDManager, "_create_assault_corner", "compass_standalone_init_hud", function(self)
        local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
        if hud and hud.panel then 
            CompassStandalone:_create_khud_compass(hud.panel)
            CompassStandalone:_layout_compass_panel()
            if CompassStandalone:IsEnabled() then 
                self:add_updator("_update_hud_compass_standalone", callback(CompassStandalone, CompassStandalone, "Update"))
            end
        end
    end)
end

-- ============================================================================
-- NiceTrainer Action Registration
-- ============================================================================
NiceTrainer:RegisterAction("Visuals", {
    type = "toggle",
    category = "HUD & Navigation",
    id = "compass_hud_enabled",
    badge = "client",
    save = true,
    default = false,
    text = "HUD Compass (KineticHUD Element)",
    tooltip = "Adds the authentic KineticHUD Compass bar to the top of the HUD with cardinal directions, degrees, and real-time yaw tracking.",
    callback = function(state)
        CompassStandalone.settings.enabled = state
        CompassStandalone:EnsureHUD()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type = "colorpicker",
    category = "HUD & Navigation",
    id = "compass_hud_color",
    save = true,
    default = "#FFFFFF",
    text = "Compass Color",
    tooltip = "Customizes the color of the compass ticks, text, and gradient shine.",
    callback = function(c, hex)
        CompassStandalone.settings.compass_color = hex
        CompassStandalone.settings.compass_color_bg = hex
        if managers.hud then
            local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_FULLSCREEN_PD2)
            if hud and hud.panel then
                CompassStandalone:_create_khud_compass(hud.panel)
            end
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type = "slider",
    category = "HUD & Navigation",
    id = "compass_hud_alpha",
    save = true,
    min = 0,
    max = 100,
    default = 100,
    text = "Compass Opacity",
    tooltip = "Controls the transparency and opacity level of the compass element.",
    callback = function(val)
        CompassStandalone.settings.panel_compass_alpha = val / 100
        CompassStandalone:_layout_compass_panel()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type = "slider",
    category = "HUD & Navigation",
    id = "compass_hud_y",
    save = true,
    min = 0,
    max = 300,
    default = 0,
    text = "Compass Vertical Position (Y)",
    tooltip = "Adjusts the vertical placement (Y position) of the compass bar on the HUD.",
    callback = function(val)
        CompassStandalone.settings.panel_compass_y = val
        CompassStandalone:_layout_compass_panel()
    end
})
