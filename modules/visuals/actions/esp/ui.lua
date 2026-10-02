local ESP = NiceTrainer.ESP

function ESP.EnsureDefaults()
    for _, cfg in ipairs(ESP.ESP_CONFIGS) do
        local sk = "esp_show_"  .. cfg.key
        local ck = "esp_color_" .. cfg.key
        local bk = "esp_bind_"  .. cfg.key
        if NiceTrainer.Settings[sk] == nil then
            NiceTrainer.Settings[sk] = (cfg.def_show ~= nil) and cfg.def_show or true
        end
        if NiceTrainer.Settings[ck] == nil then
            NiceTrainer.Settings[ck] = { r = cfg.def.r, g = cfg.def.g, b = cfg.def.b }
        end
        if NiceTrainer.Settings[bk] == nil then NiceTrainer.Settings[bk] = "" end
    end
    if NiceTrainer.Settings.esp_enabled            == nil then NiceTrainer.Settings.esp_enabled            = false end
    if NiceTrainer.Settings.esp_refresh_rate       == nil then NiceTrainer.Settings.esp_refresh_rate       = 1.0   end
    if NiceTrainer.Settings.esp_proximity          == nil then NiceTrainer.Settings.esp_proximity          = false end
    if NiceTrainer.Settings.esp_proximity_range    == nil then NiceTrainer.Settings.esp_proximity_range    = 15    end
    if NiceTrainer.Settings.esp_auto_hide          == nil then NiceTrainer.Settings.esp_auto_hide          = true  end
    if NiceTrainer.Settings.esp_show_labels        == nil then NiceTrainer.Settings.esp_show_labels        = true  end
    if NiceTrainer.Settings.esp_camera_cones       == nil then NiceTrainer.Settings.esp_camera_cones       = true  end
    if NiceTrainer.Settings.esp_camera_spy_cones   == nil then NiceTrainer.Settings.esp_camera_spy_cones   = true  end
    if NiceTrainer.Settings.esp_camera_cones_alpha == nil then NiceTrainer.Settings.esp_camera_cones_alpha = 25    end
    if NiceTrainer.Settings.esp_camera_cones_range == nil then NiceTrainer.Settings.esp_camera_cones_range = 5     end
end

ESP.EnsureDefaults()
-- UI updater table: populated by the modal, used by keybind callbacks to sync checkbox state
NiceTrainer._esp_cb_updaters = NiceTrainer._esp_cb_updaters or {}

-- Central toggle function — used by client the modal checkbox and keybind
function ESP.ToggleCategory(cfg_key, cfg_title, new_state)
    local sk = "esp_show_" .. cfg_key
    if new_state == nil then new_state = not NiceTrainer.Settings[sk] end
    NiceTrainer.Settings[sk] = new_state
    NiceTrainer:Save()
    NiceTrainer:Toast(cfg_title .. ": " .. (new_state and "ON" or "OFF"))
    local upd = NiceTrainer._esp_cb_updaters[cfg_key]
    if upd then pcall(upd, new_state) end
end
function ESP.InitContourConfig()
    ESP.EnsureDefaults()
    if not ContourExt or not ContourExt._types then return end
    for _, cfg in ipairs(ESP.ESP_CONFIGS) do
        local ck     = "esp_color_" .. cfg.key
        local c_type = "nt_esp_"    .. cfg.key
        local c      = NiceTrainer.Settings[ck]
        if not c then goto continue end

        if not ContourExt._types[c_type] then
            local t = {}
            local src = ContourExt._types.friendly or ContourExt._types.generic_interactable or ContourExt._types.mark_unit or ContourExt._types.mark_enemy
            if src then
                for k, v in pairs(src) do t[k] = v end
            end
            t.fadeout        = nil
            t.fadeout_silent = nil
            t.priority       = 1
            t.color          = Vector3(c.r, c.g, c.b)
            t.material_swap_required = true
            
            ContourExt._types[c_type] = t
            if ContourExt.indexed_types then
                table.insert(ContourExt.indexed_types, c_type)
            end
        end

        ContourExt._types[c_type].priority = 1
        ContourExt._types[c_type].color = Vector3(c.r, c.g, c.b)
        ContourExt._types[c_type].material_swap_required = true
        if tweak_data and tweak_data.contour then
            tweak_data.contour[c_type] = ContourExt._types[c_type]
        end

        if cfg.key == "cameras" then
            if ContourExt._types.generic_interactable then
                ContourExt._types.generic_interactable.color = Vector3(c.r, c.g, c.b)
            end
        end

        ::continue::
    end
end
-- Restore saved keybinds on load
function ESP.RestoreKeybinds()
    ESP.EnsureDefaults()
    for _, cfg in ipairs(ESP.ESP_CONFIGS) do
        local bk  = "esp_bind_" .. cfg.key
        local key = NiceTrainer.Settings[bk]
        if key and key ~= "" then
            local c_key   = cfg.key
            local c_title = cfg.title
            NiceTrainer:BindGlobalHotkey(bk, key, function()
                ESP.ToggleCategory(c_key, c_title)
                ESP.ApplyESP()
            end)
        end
    end
end

Hooks:Add("NiceTrainer_InitTabs", "NiceTrainer_ESP_RestoreBinds", function()
    ESP.RestoreKeybinds()
end)
-- ─── Settings modal ──────────────────────────────────────────────────────────

local MODAL_W  = 620
local MODAL_H  = 580
local ROW_H    = 42
local SUBHDR_H = 26

function ESP.ShowESPSettings()
    NiceTrainer._esp_cb_updaters = {}

    NiceTrainer:ShowCustomModal("X-Ray Settings", MODAL_W, MODAL_H, function(m)

        -- ── Refresh rate slider ───────────────────────────────────────────
        local FIXED_Y  = 70
        local TRACK_X, TRACK_W  = 20, MODAL_W - 90

        -- Refresh Rate
        m:text({ text = "Refresh Rate (s):", font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color.white, x = TRACK_X, y = FIXED_Y, layer = 2 })
        local rate_val = NiceTrainer.Settings.esp_refresh_rate or 1.0
        local rate_txt = m:text({ text = string.format("%.1f", rate_val), font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color(0.2, 0.6, 1.0), x = MODAL_W - 65, y = FIXED_Y, w = 55, align = "right", layer = 2 })
        
        local ty = FIXED_Y + 24
        local MIN_RATE, MAX_RATE = 0.1, 5.0
        local track_bg   = m:rect({ color = Color.black, alpha = 0.5, x = TRACK_X, y = ty + 5, w = TRACK_W, h = 6, layer = 1 })
        local rate_pct   = math.clamp((rate_val - MIN_RATE) / (MAX_RATE - MIN_RATE), 0, 1)
        local track_fill = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X, y = ty + 5, w = rate_pct * TRACK_W, h = 6, layer = 2 })
        local track_knob = m:rect({ color = Color.white, x = TRACK_X + rate_pct * TRACK_W - 4, y = ty + 1, w = 8, h = 14, layer = 3 })

        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        table.insert(top_modal.elements, {
            panel = track_bg,
            inside = function(self, mx, my) return track_bg:inside(mx, my) or track_knob:inside(mx, my) end,
            on_click = function(self, mx, my)
                NiceTrainer._dragging_slider = function(drag_x)
                    local rx  = drag_x - track_bg:world_x()
                    local pct = math.clamp(rx / TRACK_W, 0, 1)
                    local val = math.floor((MIN_RATE + pct * (MAX_RATE - MIN_RATE)) * 10 + 0.5) / 10
                    NiceTrainer.Settings.esp_refresh_rate = val
                    NiceTrainer._esp_acc = 0
                    NiceTrainer:Save()
                    track_fill:set_w(pct * TRACK_W)
                    track_knob:set_x(TRACK_X + pct * TRACK_W - 4)
                    rate_txt:set_text(string.format("%.1f", val))
                end
                NiceTrainer._dragging_slider(mx)
            end
        })
        
        -- Smart Settings Subheader
        local smart_hdr_y = ty + 30
        m:text({ text = "SMART ITEM & CAMERA SETTINGS", font = "fonts/font_large_mf", font_size = 18, color = Color(0.2, 0.6, 1.0), x = TRACK_X, y = smart_hdr_y, layer = 2 })
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = TRACK_X, y = smart_hdr_y + 24, w = TRACK_W, h = 1, layer = 2 })

        -- Proximity Slider
        local py = smart_hdr_y + 34
        m:text({ text = "Proximity Range (m):", font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color.white, x = TRACK_X, y = py, layer = 2 })
        local prox_val = NiceTrainer.Settings.esp_proximity_range or 15
        local prox_txt = m:text({ text = string.format("%d", prox_val), font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color(0.2, 0.6, 1.0), x = MODAL_W - 65, y = py, w = 55, align = "right", layer = 2 })
        
        local p_ty = py + 24
        local MIN_PROX, MAX_PROX = 1, 100
        local p_track_bg   = m:rect({ color = Color.black, alpha = 0.5, x = TRACK_X, y = p_ty + 5, w = TRACK_W, h = 6, layer = 1 })
        local prox_pct     = math.clamp((prox_val - MIN_PROX) / (MAX_PROX - MIN_PROX), 0, 1)
        local p_track_fill = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X, y = p_ty + 5, w = prox_pct * TRACK_W, h = 6, layer = 2 })
        local p_track_knob = m:rect({ color = Color.white, x = TRACK_X + prox_pct * TRACK_W - 4, y = p_ty + 1, w = 8, h = 14, layer = 3 })

        table.insert(top_modal.elements, {
            panel = p_track_bg,
            inside = function(self, mx, my) return p_track_bg:inside(mx, my) or p_track_knob:inside(mx, my) end,
            on_click = function(self, mx, my)
                NiceTrainer._dragging_slider = function(drag_x)
                    local rx  = drag_x - p_track_bg:world_x()
                    local pct = math.clamp(rx / TRACK_W, 0, 1)
                    local val = math.floor(MIN_PROX + pct * (MAX_PROX - MIN_PROX) + 0.5)
                    NiceTrainer.Settings.esp_proximity_range = val
                    NiceTrainer:Save()
                    p_track_fill:set_w(pct * TRACK_W)
                    p_track_knob:set_x(TRACK_X + pct * TRACK_W - 4)
                    prox_txt:set_text(string.format("%d", val))
                end
                NiceTrainer._dragging_slider(mx)
            end
        })

        -- Camera Cone Draw Range Slider
        local cone_sy = p_ty + 28
        m:text({ text = "Camera Cones Range (m):", font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color.white, x = TRACK_X, y = cone_sy, layer = 2 })
        local cone_range_val = NiceTrainer.Settings.esp_camera_cones_range or 25
        local cone_range_txt = m:text({ text = string.format("%d", cone_range_val), font = "fonts/font_medium_shadow_mf", font_size = 18, color = Color(0.2, 0.6, 1.0), x = MODAL_W - 65, y = cone_sy, w = 55, align = "right", layer = 2 })

        local cone_ty = cone_sy + 24
        local MIN_CONE_R, MAX_CONE_R = 5, 100
        local c_track_bg   = m:rect({ color = Color.black, alpha = 0.5, x = TRACK_X, y = cone_ty + 5, w = TRACK_W, h = 6, layer = 1 })
        local cone_pct     = math.clamp((cone_range_val - MIN_CONE_R) / (MAX_CONE_R - MIN_CONE_R), 0, 1)
        local c_track_fill = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X, y = cone_ty + 5, w = cone_pct * TRACK_W, h = 6, layer = 2 })
        local c_track_knob = m:rect({ color = Color.white, x = TRACK_X + cone_pct * TRACK_W - 4, y = cone_ty + 1, w = 8, h = 14, layer = 3 })

        table.insert(top_modal.elements, {
            panel = c_track_bg,
            inside = function(self, mx, my) return c_track_bg:inside(mx, my) or c_track_knob:inside(mx, my) end,
            on_click = function(self, mx, my)
                NiceTrainer._dragging_slider = function(drag_x)
                    local rx  = drag_x - c_track_bg:world_x()
                    local pct = math.clamp(rx / TRACK_W, 0, 1)
                    local val = math.floor(MIN_CONE_R + pct * (MAX_CONE_R - MIN_CONE_R) + 0.5)
                    NiceTrainer.Settings.esp_camera_cones_range = val
                    NiceTrainer:Save()
                    c_track_fill:set_w(pct * TRACK_W)
                    c_track_knob:set_x(TRACK_X + pct * TRACK_W - 4)
                    cone_range_txt:set_text(string.format("%d", val))
                end
                NiceTrainer._dragging_slider(mx)
            end
        })
        
        -- Checkboxes Row 1: Proximity & Auto-Hide
        local cy = cone_ty + 28
        
        -- Proximity toggle
        local prox_state = NiceTrainer.Settings.esp_proximity
        local cb1_bg = m:rect({ color = Color.white, alpha = 0.1, x = TRACK_X, y = cy + 2, w = 18, h = 18, layer = 1 })
        local cb1    = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X + 3, y = cy + 5, w = 12, h = 12, visible = prox_state, layer = 2 })
        m:text({ text = "Enable Proximity Mode", font = "fonts/font_medium_shadow_mf", font_size = 17, x = TRACK_X + 26, y = cy, color = Color(0.9, 0.9, 0.9), layer = 1 })
        
        table.insert(top_modal.elements, {
            panel = cb1_bg,
            inside = function(self, mx, my) return cb1_bg:inside(mx, my) end,
            on_click = function(self, mx, my)
                prox_state = not prox_state
                NiceTrainer.Settings.esp_proximity = prox_state
                NiceTrainer:Save()
                cb1:set_visible(prox_state)
                ESP.ApplyESP()
            end
        })
        
        -- Auto-Hide toggle
        local hide_state = NiceTrainer.Settings.esp_auto_hide
        local cb2_bg = m:rect({ color = Color.white, alpha = 0.1, x = MODAL_W / 2 - 20, y = cy + 2, w = 18, h = 18, layer = 1 })
        local cb2    = m:rect({ color = Color(0.2, 0.6, 1.0), x = MODAL_W / 2 - 17, y = cy + 5, w = 12, h = 12, visible = hide_state, layer = 2 })
        m:text({ text = "Auto-hide Collected", font = "fonts/font_medium_shadow_mf", font_size = 17, x = MODAL_W / 2 + 6, y = cy, color = Color(0.9, 0.9, 0.9), layer = 1 })
        
        table.insert(top_modal.elements, {
            panel = cb2_bg,
            inside = function(self, mx, my) return cb2_bg:inside(mx, my) end,
            on_click = function(self, mx, my)
                hide_state = not hide_state
                NiceTrainer.Settings.esp_auto_hide = hide_state
                NiceTrainer:Save()
                cb2:set_visible(hide_state)
                ESP.ApplyESP()
            end
        })

        -- Checkboxes Row 2: Show Labels & Camera Vision Cones
        local cy2 = cy + 26

        -- Show Labels toggle
        local labels_state = NiceTrainer.Settings.esp_show_labels
        local cb3_bg = m:rect({ color = Color.white, alpha = 0.1, x = TRACK_X, y = cy2 + 2, w = 18, h = 18, layer = 1 })
        local cb3    = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X + 3, y = cy2 + 5, w = 12, h = 12, visible = labels_state, layer = 2 })
        m:text({ text = "Show Item Labels & Distance", font = "fonts/font_medium_shadow_mf", font_size = 17, x = TRACK_X + 26, y = cy2, color = Color(0.9, 0.9, 0.9), layer = 1 })
        
        table.insert(top_modal.elements, {
            panel = cb3_bg,
            inside = function(self, mx, my) return cb3_bg:inside(mx, my) end,
            on_click = function(self, mx, my)
                labels_state = not labels_state
                NiceTrainer.Settings.esp_show_labels = labels_state
                NiceTrainer:Save()
                cb3:set_visible(labels_state)
                ESP.ApplyESP()
            end
        })

        -- Camera Vision Cones toggle
        local cam_cone_state = NiceTrainer.Settings.esp_camera_cones
        local cb4_bg = m:rect({ color = Color.white, alpha = 0.1, x = MODAL_W / 2 - 20, y = cy2 + 2, w = 18, h = 18, layer = 1 })
        local cb4    = m:rect({ color = Color(0.2, 0.6, 1.0), x = MODAL_W / 2 - 17, y = cy2 + 5, w = 12, h = 12, visible = cam_cone_state, layer = 2 })
        m:text({ text = "Camera Vision Cones", font = "fonts/font_medium_shadow_mf", font_size = 17, x = MODAL_W / 2 + 6, y = cy2, color = Color(0.9, 0.9, 0.9), layer = 1 })

        table.insert(top_modal.elements, {
            panel = cb4_bg,
            inside = function(self, mx, my) return cb4_bg:inside(mx, my) end,
            on_click = function(self, mx, my)
                cam_cone_state = not cam_cone_state
                NiceTrainer.Settings.esp_camera_cones = cam_cone_state
                NiceTrainer:Save()
                cb4:set_visible(cam_cone_state)
            end
        })

        -- Checkboxes Row 3: Spy Camera Cones
        local cy3 = cy2 + 26

        local spy_cone_state = NiceTrainer.Settings.esp_camera_spy_cones
        local cb5_bg = m:rect({ color = Color.white, alpha = 0.1, x = TRACK_X, y = cy3 + 2, w = 18, h = 18, layer = 1 })
        local cb5    = m:rect({ color = Color(0.2, 0.6, 1.0), x = TRACK_X + 3, y = cy3 + 5, w = 12, h = 12, visible = spy_cone_state, layer = 2 })
        m:text({ text = "Spy Camera Vision Cones", font = "fonts/font_medium_shadow_mf", font_size = 17, x = TRACK_X + 26, y = cy3, color = Color(0.9, 0.9, 0.9), layer = 1 })

        table.insert(top_modal.elements, {
            panel = cb5_bg,
            inside = function(self, mx, my) return cb5_bg:inside(mx, my) end,
            on_click = function(self, mx, my)
                spy_cone_state = not spy_cone_state
                NiceTrainer.Settings.esp_camera_spy_cones = spy_cone_state
                NiceTrainer:Save()
                cb5:set_visible(spy_cone_state)
            end
        })

        local sep_y = cy3 + 28
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 20, y = sep_y, w = MODAL_W - 40, h = 1, layer = 2 })

        -- ── Scrollable list ───────────────────────────────────────────────
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = MODAL_W, h = MODAL_H - scroll_top - 8, layer = 2 })

        local canvas_h = 8
        local last_g   = nil
        for _, cfg in ipairs(ESP.ESP_CONFIGS) do
            if cfg.group ~= last_g then canvas_h = canvas_h + SUBHDR_H + 6; last_g = cfg.group end
            canvas_h = canvas_h + ROW_H + 3
        end

        local canvas  = scroll_wrap:panel({ x = 0, y = 0, w = MODAL_W, h = canvas_h + 8, layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        -- Layout constants
        local ROW_W    = MODAL_W - 16
        local SWATCH_W = 36
        local SWATCH_X = ROW_W - 8 - SWATCH_W
        local BIND_W   = 62
        local BIND_X   = SWATCH_X - 4 - BIND_W

        local y    = 8
        local lgrp = nil

        local function AddSubHeader(label)
            canvas:text({
                text = string.upper(label), font = "fonts/font_large_mf", font_size = 18,
                color = Color(0.2, 0.6, 1.0), x = 18, y = y, layer = 2
            })
            canvas:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 18, y = y + SUBHDR_H - 2, w = ROW_W - 18, h = 1, layer = 2 })
            y = y + SUBHDR_H + 6
        end

        local function AddCategoryRow(cfg)
            local sk = "esp_show_"  .. cfg.key
            local ck = "esp_color_" .. cfg.key
            local bk = "esp_bind_"  .. cfg.key

            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = ROW_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            -- Checkbox
            local state = NiceTrainer.Settings[sk]
            row:rect({ color = Color.white, alpha = 0.1, x = 8, y = 11, w = 20, h = 20, layer = 1 })
            local cb = row:rect({ color = Color(0.2, 0.6, 1.0), x = 12, y = 15, w = 12, h = 12, visible = state, layer = 2 })

            NiceTrainer._esp_cb_updaters[cfg.key] = function(new_state)
                if alive(cb) then cb:set_visible(new_state) end
            end

            -- Label
            row:text({
                text = cfg.title, font = "fonts/font_medium_shadow_mf", font_size = 17,
                x = 36, vertical = "center", color = Color(0.9, 0.9, 0.9), layer = 1
            })

            -- Keybind button
            local cur_key  = NiceTrainer.Settings[bk] or ""
            local bind_btn = row:panel({ x = BIND_X, y = 7, w = BIND_W, h = 28, layer = 2 })
            local bind_bg  = bind_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
            bind_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 2, layer = 1 })
            bind_btn:rect({ color = Color(0.2, 0.6, 1.0), x = BIND_W - 2, w = 2, layer = 1 })
            local bind_txt = bind_btn:text({
                text = cur_key == "" and "BIND" or string.upper(cur_key),
                font = "fonts/font_medium_shadow_mf", font_size = 15,
                w = BIND_W, h = 28, align = "center", vertical = "center",
                color = Color.white, layer = 2
            })

            -- Color swatch
            local c      = NiceTrainer.Settings[ck] or { r = cfg.def.r, g = cfg.def.g, b = cfg.def.b }
            local swatch = row:rect({ color = Color(c.r, c.g, c.b), x = SWATCH_X, y = 8, w = SWATCH_W, h = 26, layer = 2 })
            row:rect({ color = Color.white, alpha = 0.3, x = SWATCH_X - 1, y = 7, w = SWATCH_W + 2, h = 28, layer = 1 })

            local c_key   = cfg.key
            local c_title = cfg.title
            local bind_el = {
                panel         = bind_btn,
                val_text      = bind_txt,
                bg            = bind_bg,
                id            = bk,
                callback_func = function()
                    ESP.ToggleCategory(c_key, c_title)
                    ESP.ApplyESP()
                end,
            }

            local mref = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]

            -- Bind button
            table.insert(mref.elements, {
                panel = bind_btn,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and bind_btn:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    if NiceTrainer._listening_for_key == bind_el then return end
                    bind_bg:set_alpha(hovered and 0.4 or 0.2)
                end,
                on_click = function(self, mx, my)
                    if NiceTrainer._listening_for_key == bind_el then
                        NiceTrainer:CancelKeybind()
                    else
                        NiceTrainer:ListenForKeybind(bind_el)
                    end
                end
            })

            -- Checkbox row
            table.insert(mref.elements, {
                panel = row,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my)
                        and row:inside(mx, my)
                        and not bind_btn:inside(mx, my)
                        and not swatch:inside(mx, my)
                end,
                on_hover = function(self, hovered) row_bg:set_alpha(hovered and 0.12 or 0.04) end,
                on_click = function(self, mx, my)
                    state = not state
                    ESP.ToggleCategory(c_key, c_title, state)
                    ESP.ApplyESP()
                end
            })

            -- Color swatch
            table.insert(mref.elements, {
                panel = swatch,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and swatch:inside(mx, my)
                end,
                on_hover = function(self, hovered) swatch:set_alpha(hovered and 0.6 or 1) end,
                on_click = function(self, mx, my)
                    local cur2 = NiceTrainer.Settings[ck] or { r = cfg.def.r, g = cfg.def.g, b = cfg.def.b }
                    NiceTrainer:ShowColorPickerModal(cfg.title, Color(cur2.r, cur2.g, cur2.b), function(nc)
                        NiceTrainer.Settings[ck] = { r = nc.r, g = nc.g, b = nc.b }
                        NiceTrainer:Save()
                        if alive(swatch) then swatch:set_color(nc) end
                        ESP.ApplyESP()
                    end)
                end
            })

            y = y + ROW_H + 3
        end

        for _, cfg in ipairs(ESP.ESP_CONFIGS) do
            if cfg.group ~= lgrp then
                AddSubHeader(ESP.GROUP_LABELS[cfg.group] or cfg.group)
                lgrp = cfg.group
            end
            AddCategoryRow(cfg)
        end
    end)
end
-- ─── Register action ─────────────────────────────────────────────────────────

NiceTrainer._apply_esp = ESP.ApplyESP

NiceTrainer:RegisterAction("Visuals", {
    category          = "X-RAY",
    badge             = "client",
    type              = "toggle_settings",
    id                = "esp_enabled",
    text              = "X-Ray",
    save              = false,
    tooltip           = "See enemies, cameras, mission items, computers, power boxes, doors, deployables and loot through walls.",
    callback          = function(state)
        NiceTrainer.Settings.esp_enabled = state
        NiceTrainer:Save()
        ESP.ApplyESP()
    end,
    settings_callback = ESP.ShowESPSettings,
})