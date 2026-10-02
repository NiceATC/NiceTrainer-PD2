-- ─── Menu Theme & Visual Customization (Settings Tab) ────────────────────────
-- Provides custom menu accent colors, theme presets, background dimming,
-- and live UI restyling.

local THEME_PRESETS = {
    { name = "Electric Blue (Default)", hex = "#3399FF", color = Color(0.2, 0.6, 1.0) },
    { name = "Crimson Red",             hex = "#FF3333", color = Color(1.0, 0.2, 0.2) },
    { name = "Emerald Green",           hex = "#00E676", color = Color(0.0, 0.9, 0.46) },
    { name = "Cyberpunk Purple",        hex = "#D500F9", color = Color(0.83, 0.0, 0.98) },
    { name = "Golden Amber",            hex = "#FFAB00", color = Color(1.0, 0.67, 0.0) },
    { name = "Sunset Orange",           hex = "#FF5722", color = Color(1.0, 0.34, 0.13) },
    { name = "Vaporwave Cyan",          hex = "#00E5FF", color = Color(0.0, 0.9, 1.0) },
    { name = "Neon Rose",               hex = "#FF4081", color = Color(1.0, 0.25, 0.51) },
    { name = "Matrix Green",            hex = "#00FF41", color = Color(0.0, 1.0, 0.25) },
    { name = "Stealth White",           hex = "#E0E0E0", color = Color(0.88, 0.88, 0.88) }
}

local function apply_accent_color(hex_or_color)
    local hex_str = type(hex_or_color) == "string" and hex_or_color or nil
    if type(hex_or_color) == "userdata" then
        hex_str = string.format("#%02X%02X%02X", math.floor(hex_or_color.r * 255), math.floor(hex_or_color.g * 255), math.floor(hex_or_color.b * 255))
    end

    if hex_str then
        NiceTrainer.Settings.menu_accent_color = hex_str
        NiceTrainer:Save()
    end

    -- Live refresh entire UI in real time
    pcall(function()
        if NiceTrainer.ApplyThemeColors then
            NiceTrainer:ApplyThemeColors()
        end
    end)
end

local function ShowThemeModal()
    local MODAL_W, MODAL_H = 500, 480
    NiceTrainer:ShowCustomModal("Menu Theme & Accent Color", MODAL_W, MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        local TRACK_X, TRACK_W = 20, MODAL_W - 40
        
        local desc_txt = m:text({
            text = "Select a color theme preset or pick a custom accent color for all menu borders, buttons, sliders, and highlights:",
            font = "fonts/font_medium_shadow_mf",
            font_size = 15,
            color = Color(0.8, 0.8, 0.8),
            x = TRACK_X,
            y = 50,
            w = TRACK_W,
            wrap = true,
            layer = 1
        })

        local cur_y = 100
        local cols = 2
        local card_w = (TRACK_W - 10) / cols
        local card_h = 36

        for i, preset in ipairs(THEME_PRESETS) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local px = TRACK_X + col * (card_w + 10)
            local py = cur_y + row * (card_h + 8)

            local p = m:panel({ x = px, y = py, w = card_w, h = card_h, layer = 2 })
            local bg = p:rect({ color = Color.white, alpha = 0.05, layer = 0 })
            local color_swatch = p:rect({ color = preset.color, x = 6, y = 6, w = 24, h = card_h - 12, layer = 2 })
            local border = p:rect({ color = preset.color, alpha = 0.4, w = 1, layer = 1 })
            p:rect({ color = preset.color, alpha = 0.4, x = card_w - 1, w = 1, layer = 1 })
            p:rect({ color = preset.color, alpha = 0.4, h = 1, layer = 1 })
            p:rect({ color = preset.color, alpha = 0.4, y = card_h - 1, h = 1, layer = 1 })

            local txt = p:text({
                text = preset.name,
                font = "fonts/font_medium_shadow_mf",
                font_size = 15,
                color = Color.white,
                x = 36,
                vertical = "center",
                layer = 2
            })

            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.15 or 0.05)
                    txt:set_color(hovered and preset.color or Color.white)
                end,
                on_click = function(self)
                    apply_accent_color(preset.hex)
                    NiceTrainer:Toast("Applied Theme: " .. preset.name, preset.color)
                    NiceTrainer:CloseModal()
                end
            })
        end

        local total_rows = math.ceil(#THEME_PRESETS / cols)
        local btn_y = cur_y + total_rows * (card_h + 8) + 15

        -- Custom Color Picker Button
        local picker_btn = m:panel({ x = TRACK_X, y = btn_y, w = TRACK_W, h = 38, layer = 2 })
        local picker_bg = picker_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
        picker_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.6, w = 1, layer = 1 })
        picker_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.6, x = TRACK_W - 1, w = 1, layer = 1 })
        picker_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.6, h = 1, layer = 1 })
        picker_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.6, y = 37, h = 1, layer = 1 })
        picker_btn:text({ text = "Open Advanced Color Picker (Hex / RGB)...", font = "fonts/font_medium_shadow_mf", font_size = 18, align = "center", vertical = "center", color = Color.white, layer = 2 })

        table.insert(top_modal.elements, {
            panel = picker_btn,
            inside = function(self, mx, my) return picker_btn:inside(mx, my) end,
            on_hover = function(self, hovered) picker_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self)
                NiceTrainer:CloseModal()
                NiceTrainer:ShowColorPickerModal("Custom Menu Accent Color", NiceTrainer:GetAccentColorHex(), function(c, hex)
                    apply_accent_color(hex)
                    NiceTrainer:Toast("Custom Accent Color Set: " .. hex, c)
                end)
            end
        })

        -- Close Button
        local close_btn = m:panel({ x = (MODAL_W - 120) / 2, y = MODAL_H - 45, w = 120, h = 30, layer = 2 })
        local close_bg = close_btn:rect({ color = NiceTrainer:GetAccentColor(), alpha = 0.2, layer = 0 })
        close_btn:text({ text = "Close", font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = Color.white, layer = 2 })
        
        table.insert(top_modal.elements, {
            panel = close_btn,
            inside = function(self, mx, my) return close_btn:inside(mx, my) end,
            on_hover = function(self, hovered) close_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self) NiceTrainer:CloseModal() end
        })
    end)
end

-- ============================================================================
-- Registrations (Settings Tab)
-- ============================================================================

local theme_names = {}
for _, p in ipairs(THEME_PRESETS) do
    table.insert(theme_names, p.name)
end

NiceTrainer:RegisterAction("Settings", {
    type            = "multichoice",
    category        = "Appearance & Themes",
    badge           = "safe",
    id              = "menu_theme_preset",
    text            = "Menu Accent Color Preset",
    tooltip         = "Instantly changes the primary accent highlight color of the NiceTrainer interface.",
    options         = theme_names,
    default         = 1,
    action_btn_text = "Apply Theme",
    callback        = function(idx, val)
        local preset = THEME_PRESETS[idx] or THEME_PRESETS[1]
        apply_accent_color(preset.hex)
        NiceTrainer:Toast("Menu Accent changed to: " .. preset.name, preset.color)
    end
})

NiceTrainer:RegisterAction("Settings", {
    type     = "colorpicker",
    category = "Appearance & Themes",
    badge    = "safe",
    id       = "menu_accent_color",
    text     = "Custom Accent Color (Palette)",
    tooltip  = "Pick any custom RGB/HEX color for all buttons, sliders, and highlights across the entire trainer.",
    default  = "#3399FF",
    callback = function(col, hex)
        apply_accent_color(hex)
    end
})

NiceTrainer:RegisterAction("Settings", {
    type           = "button",
    category       = "Appearance & Themes",
    badge          = "safe",
    text           = "Theme & Palette Preview Modal",
    tooltip        = "Opens a full visual palette modal with theme previews and custom color adjustments.",
    action_btn_text = "Open Themes",
    callback       = ShowThemeModal
})

NiceTrainer:RegisterAction("Settings", {
    type     = "slider",
    category = "Appearance & Themes",
    badge    = "safe",
    id       = "menu_bg_opacity",
    text     = "Menu Background Dimming Alpha (%)",
    tooltip  = "Adjust the darkness and opacity of the background behind the trainer window.",
    min      = 10,
    max      = 100,
    default  = 40,
    callback = function(val)
        NiceTrainer.Settings.menu_bg_opacity = val
        NiceTrainer:Save()
        if NiceTrainer._bg and alive(NiceTrainer._bg) then
            NiceTrainer._bg:set_alpha((val or 40) / 100)
        end
    end
})

NiceTrainer:RegisterAction("Settings", {
    type           = "button",
    category       = "Appearance & Themes",
    badge          = "safe",
    text           = "Reset Menu Theme to Default (Blue)",
    tooltip        = "Restores the original Electric Blue theme and default background opacity.",
    action_btn_text = "Reset Default",
    callback       = function()
        NiceTrainer.Settings.menu_accent_color = "#3399FF"
        NiceTrainer.Settings.menu_theme_preset = 1
        NiceTrainer.Settings.menu_bg_opacity = 40
        NiceTrainer:Save()
        apply_accent_color("#3399FF")
        if NiceTrainer._bg and alive(NiceTrainer._bg) then
            NiceTrainer._bg:set_alpha(0.4)
        end
        NiceTrainer:Toast("Reset menu theme to default Electric Blue!", Color(0.2, 0.6, 1.0))
    end
})
