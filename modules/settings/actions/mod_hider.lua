-- ============================================================
-- Selective Mod Hider (Inverted: Visible by default, check to Hide)
-- ============================================================

if type(NiceTrainer.Settings.hidden_mods) ~= "table" then
    NiceTrainer.Settings.hidden_mods = {}
    -- Migration: if old show_mods existed where a mod was explicitly false, keep it hidden
    if type(NiceTrainer.Settings.show_mods) == "table" then
        for mod_name, is_shown in pairs(NiceTrainer.Settings.show_mods) do
            if is_shown == false then
                NiceTrainer.Settings.hidden_mods[mod_name] = true
            end
        end
    end
end

-- Returns all installed BLT mods + engine registered mods reliably
local function GetAllInstalledMods()
    local list = {}
    local seen = {}

    -- 1. Try BLT.Mods:Mods() (always loaded and contains exact names)
    if BLT and BLT.Mods and BLT.Mods.Mods then
        local ok, blt_mods = pcall(function() return BLT.Mods:Mods() end)
        if ok and type(blt_mods) == "table" then
            for _, mod in pairs(blt_mods) do
                if mod and mod.GetName then
                    local name = mod:GetName()
                    if type(name) == "string" and name ~= "" and not seen[name] then
                        seen[name] = true
                        table.insert(list, { name, (mod.GetId and mod:GetId()) or "1" })
                    end
                end
            end
        end
    end

    -- 2. Try original MenuCallbackHandler:build_mods_list
    local fn = _G.MenuCallbackHandler and (
        _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods or _G.MenuCallbackHandler.build_mods_list
    )
    if fn then
        local ok, result = pcall(fn, _G.MenuCallbackHandler)
        if ok and type(result) == "table" then
            for _, mod_data in ipairs(result) do
                local name = mod_data[1]
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(list, mod_data)
                end
            end
        end
    end

    table.sort(list, function(a, b)
        return tostring(a[1]):lower() < tostring(b[1]):lower()
    end)

    return list
end

local in_build_mods = false
local in_is_modded = false

local function is_mod_hidden(name)
    if type(name) ~= "string" then return false end
    -- NiceTrainer Framework and SelectiveModsHider are ALWAYS permanently hidden
    if name:find("NiceTrainer", 1, true) or name:find("SelectiveModsHider", 1, true) then
        return true
    end
    local hidden_list = NiceTrainer.Settings.hidden_mods
    if type(hidden_list) == "table" and hidden_list[name] == true then
        return true
    end
    return false
end

local function get_filtered_mods_list()
    local orig_fn = _G.MenuCallbackHandler and _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods
    local mods = orig_fn and orig_fn(_G.MenuCallbackHandler) or {}
    local return_mods = {}

    for _, mod_data in ipairs(mods) do
        local name = mod_data[1]
        if not is_mod_hidden(name) then
            table.insert(return_mods, mod_data)
        end
    end

    return return_mods
end

local function applyHidePresence(enabled)
    if not _G.MenuCallbackHandler then return end

    if not _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods then
        _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods    = _G.MenuCallbackHandler.build_mods_list
        _G.MenuCallbackHandler.NiceTrainer_OrigIsModded     = _G.MenuCallbackHandler.is_modded_client
        _G.MenuCallbackHandler.NiceTrainer_OrigIsNotModded  = _G.MenuCallbackHandler.is_not_modded_client
    end

    if enabled then
        _G.MenuCallbackHandler.build_mods_list = function(self, ...)
            if in_build_mods then return {} end
            in_build_mods = true

            local return_mods = get_filtered_mods_list()

            in_build_mods = false
            return return_mods
        end

        -- Dynamically reflect whether any mods are visible:
        -- If 0 mods shown -> appears as a 100% vanilla client
        -- If >0 mods shown -> appears as a legitimate player with only the unhidden mods
        _G.MenuCallbackHandler.is_modded_client = function(self, ...)
            if in_is_modded then return false end
            in_is_modded = true
            
            local filtered = get_filtered_mods_list()
            local result = #filtered > 0
            
            in_is_modded = false
            return result
        end

        _G.MenuCallbackHandler.is_not_modded_client = function(self, ...)
            return not self:is_modded_client(...)
        end
    else
        if _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods then
            _G.MenuCallbackHandler.build_mods_list      = _G.MenuCallbackHandler.NiceTrainer_OrigBuildMods
            _G.MenuCallbackHandler.is_modded_client     = _G.MenuCallbackHandler.NiceTrainer_OrigIsModded
            _G.MenuCallbackHandler.is_not_modded_client = _G.MenuCallbackHandler.NiceTrainer_OrigIsNotModded
        end
    end

    -- Sync with SelectiveModsHider global if present
    if _G.SelectiveModsHider then
        _G.SelectiveModsHider.hidden_mods = NiceTrainer.Settings.hidden_mods or {}
    end
end

-- ─── Mod Hider Settings Modal ─────────────────────────────────────────────────

local MHIDER_W = 570
local MHIDER_H = 520
local MH_ROW_H = 36

local function ShowModHiderSettings()
    local all_mods = GetAllInstalledMods()

    NiceTrainer:ShowCustomModal("Selective Mod Hider", MHIDER_W, MHIDER_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]

        -- Subtitle description
        m:text({
            text = "NiceTrainer Framework is locked as HIDDEN and cannot be altered.",
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(1.0, 0.6, 0.2), x = 16, y = 56, w = MHIDER_W - 32, layer = 2
        })
        m:text({
            text = "All mods are VISIBLE by default. Check a mod to HIDE it from other players.",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            color = Color(0.75, 0.75, 0.75), x = 16, y = 74, w = MHIDER_W - 32, layer = 2
        })

        -- Buttons row: [Hide All] [Show All] and dynamic counter
        local btn_w, btn_h = 110, 26
        local btn_y = 98

        local hide_all_btn = m:panel({ x = 16, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local hide_all_bg  = hide_all_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        hide_all_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        hide_all_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w - 1, w = 1, layer = 1 })
        hide_all_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        hide_all_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        hide_all_btn:text({ text = "Hide All", font = "fonts/font_medium_shadow_mf", font_size = 15, align = "center", vertical = "center", color = Color.white, layer = 2 })

        local show_all_btn = m:panel({ x = 16 + btn_w + 10, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local show_all_bg  = show_all_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        show_all_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        show_all_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w - 1, w = 1, layer = 1 })
        show_all_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        show_all_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        show_all_btn:text({ text = "Show All", font = "fonts/font_medium_shadow_mf", font_size = 15, align = "center", vertical = "center", color = Color.white, layer = 2 })

        local counter_text = m:text({
            text = "",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            align = "right", vertical = "center",
            color = Color(0.85, 0.85, 0.85),
            x = 16, y = btn_y, w = MHIDER_W - 32, h = btn_h, layer = 2
        })

        local sep_y = 132
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 16, y = sep_y, w = MHIDER_W - 32, h = 1, layer = 2 })

        -- Separate trainer mod from other mods
        local other_mods = {}
        local trainer_mod_name = "NiceTrainer Framework"

        for _, mod_data in ipairs(all_mods) do
            local name = mod_data[1]
            if type(name) == "string" then
                if name:find("NiceTrainer", 1, true) then
                    trainer_mod_name = name
                elseif not name:find("SelectiveModsHider", 1, true) then
                    table.insert(other_mods, mod_data)
                end
            end
        end

        -- Scrollable list of mods (total rows = 1 for trainer + other_mods)
        local total_rows  = 1 + #other_mods
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = MHIDER_W, h = MHIDER_H - scroll_top - 8, layer = 2 })

        local canvas_h = 8 + (total_rows * (MH_ROW_H + 4))
        local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = MHIDER_W, h = math.max(canvas_h, MH_ROW_H), layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local ROW_W = MHIDER_W - 16
        local y = 8
        local row_items = {}

        local function update_counter()
            local hidden_count = 0
            local hidden_list = NiceTrainer.Settings.hidden_mods or {}
            for _, mod_data in ipairs(other_mods) do
                if hidden_list[mod_data[1]] == true then
                    hidden_count = hidden_count + 1
                end
            end
            local visible_count = #other_mods - hidden_count
            local status_desc = visible_count == 0 and "(Vanilla Client)" or string.format("(%d Visible)", visible_count)
            counter_text:set_text(string.format("Hidden: %d/%d  %s", hidden_count + 1, total_rows, status_desc))
            counter_text:set_color(visible_count == 0 and Color(0.2, 0.9, 0.4) or Color(0.3, 0.8, 1.0))
        end

        -- ── 1. Locked NiceTrainer Row (Always at the very top) ──
        local nt_row = canvas:panel({ x = 8, y = y, w = ROW_W, h = MH_ROW_H, layer = 2 })
        local nt_bg  = nt_row:rect({ color = Color(1.0, 0.5, 0.1), alpha = 0.08, layer = 0 })
        nt_row:rect({ color = Color(1.0, 0.5, 0.1), alpha = 0.3, w = 1, layer = 1 })
        nt_row:rect({ color = Color(1.0, 0.5, 0.1), alpha = 0.3, x = ROW_W - 1, w = 1, layer = 1 })

        -- Locked Checkbox (checked, orange/gold)
        nt_row:rect({ color = Color(1.0, 0.5, 0.1), alpha = 0.3, x = 8, y = 8, w = 20, h = 20, layer = 1 })
        nt_row:rect({ color = Color(1.0, 0.6, 0.2), x = 12, y = 12, w = 12, h = 12, layer = 2 })

        -- Name label
        nt_row:text({
            text = trainer_mod_name .. "  [LOCKED]",
            font = "fonts/font_medium_shadow_mf", font_size = 15,
            x = 36, vertical = "center", color = Color(1.0, 0.8, 0.4), layer = 1
        })

        -- Locked Status badge
        nt_row:text({
            text = "HIDDEN (PERMANENT)",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            align = "right", vertical = "center",
            color = Color(1.0, 0.6, 0.2),
            x = 0, y = 0, w = ROW_W - 16, h = MH_ROW_H, layer = 1
        })

        table.insert(top_modal.elements, {
            panel = nt_row,
            inside = function(self, mx, my)
                return scroll_wrap:inside(mx, my) and nt_row:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                nt_bg:set_alpha(hovered and 0.16 or 0.08)
            end,
            on_click = function(self)
                NiceTrainer:Toast("NiceTrainer is locked as permanently hidden for safety.")
            end
        })

        y = y + MH_ROW_H + 4

        -- ── 2. Other Mods Rows (Default = Visible, Checked = Hidden) ──
        for _, mod_data in ipairs(other_mods) do
            local mod_name = mod_data[1]
            local hidden_list = NiceTrainer.Settings.hidden_mods or {}
            local is_hidden = hidden_list[mod_name] == true

            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = MH_ROW_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            -- Checkbox (marked = hidden)
            row:rect({ color = Color.white, alpha = 0.15, x = 8, y = 8, w = 20, h = 20, layer = 1 })
            local cb = row:rect({ color = Color(1.0, 0.35, 0.35), x = 12, y = 12, w = 12, h = 12, visible = is_hidden, layer = 2 })

            -- Mod name label
            row:text({
                text = mod_name,
                font = "fonts/font_medium_shadow_mf", font_size = 15,
                x = 36, vertical = "center", color = Color(0.9, 0.9, 0.9), layer = 1
            })

            -- Status badge text (right aligned)
            local status_txt = row:text({
                text = is_hidden and "HIDDEN" or "VISIBLE",
                font = "fonts/font_medium_shadow_mf", font_size = 13,
                align = "right", vertical = "center",
                color = is_hidden and Color(1.0, 0.35, 0.35) or Color(0.2, 0.9, 0.4),
                x = 0, y = 0, w = ROW_W - 16, h = MH_ROW_H, layer = 1
            })

            local item_ref = { cb = cb, status = status_txt, name = mod_name }
            table.insert(row_items, item_ref)

            local mn = mod_name
            table.insert(top_modal.elements, {
                panel = row,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and row:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    row_bg:set_alpha(hovered and 0.12 or 0.04)
                end,
                on_click = function(self, mx, my)
                    NiceTrainer.Settings.hidden_mods = NiceTrainer.Settings.hidden_mods or {}
                    local currently_hidden = NiceTrainer.Settings.hidden_mods[mn] == true
                    local new_hidden = not currently_hidden
                    NiceTrainer.Settings.hidden_mods[mn] = new_hidden and true or nil
                    NiceTrainer:Save()

                    if _G.SelectiveModsHider then
                        _G.SelectiveModsHider.hidden_mods = NiceTrainer.Settings.hidden_mods
                    end

                    if alive(cb) then cb:set_visible(new_hidden) end
                    if alive(status_txt) then
                        status_txt:set_text(new_hidden and "HIDDEN" or "VISIBLE")
                        status_txt:set_color(new_hidden and Color(1.0, 0.35, 0.35) or Color(0.2, 0.9, 0.4))
                    end
                    update_counter()
                end
            })

            y = y + MH_ROW_H + 4
        end

        -- ── Quick Action: Hide All Button Handler ──
        table.insert(top_modal.elements, {
            panel = hide_all_btn,
            inside = function(self, mx, my) return hide_all_btn:inside(mx, my) end,
            on_hover = function(self, hovered) hide_all_bg:set_alpha(hovered and 0.45 or 0.2) end,
            on_click = function(self)
                NiceTrainer.Settings.hidden_mods = NiceTrainer.Settings.hidden_mods or {}
                for _, mod_data in ipairs(other_mods) do
                    NiceTrainer.Settings.hidden_mods[mod_data[1]] = true
                end
                NiceTrainer:Save()
                if _G.SelectiveModsHider then
                    _G.SelectiveModsHider.hidden_mods = NiceTrainer.Settings.hidden_mods
                end
                for _, item in ipairs(row_items) do
                    if alive(item.cb) then item.cb:set_visible(true) end
                    if alive(item.status) then
                        item.status:set_text("HIDDEN")
                        item.status:set_color(Color(1.0, 0.35, 0.35))
                    end
                end
                update_counter()
                NiceTrainer:Toast("All mods marked as Hidden (Vanilla Disguise)")
            end
        })

        -- ── Quick Action: Show All Button Handler ──
        table.insert(top_modal.elements, {
            panel = show_all_btn,
            inside = function(self, mx, my) return show_all_btn:inside(mx, my) end,
            on_hover = function(self, hovered) show_all_bg:set_alpha(hovered and 0.45 or 0.2) end,
            on_click = function(self)
                NiceTrainer.Settings.hidden_mods = {}
                NiceTrainer:Save()
                if _G.SelectiveModsHider then
                    _G.SelectiveModsHider.hidden_mods = NiceTrainer.Settings.hidden_mods
                end
                for _, item in ipairs(row_items) do
                    if alive(item.cb) then item.cb:set_visible(false) end
                    if alive(item.status) then
                        item.status:set_text("VISIBLE")
                        item.status:set_color(Color(0.2, 0.9, 0.4))
                    end
                end
                update_counter()
                NiceTrainer:Toast("All mods marked as Visible (NiceTrainer remains hidden)")
            end
        })

        update_counter()
    end)
end

NiceTrainer:RegisterAction("Settings", {
    type              = "toggle_settings",
    category          = "Configuration",
    no_bind           = true,
    badge             = "safe",
    id                = "hide_mod_presence",
    text              = "Hide Mod Presence",
    tooltip           = "Selective Mod Hider: NiceTrainer is permanently hidden. Check any other mod to hide it from peers.",
    default           = true,
    callback          = function(state)
        applyHidePresence(state)
    end,
    settings_callback = ShowModHiderSettings,
})

if NiceTrainer.Settings.hide_mod_presence == nil or NiceTrainer.Settings.hide_mod_presence == true then
    applyHidePresence(true)
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_EnforceHideModPresence", function()
    if NiceTrainer.Settings.hide_mod_presence then
        applyHidePresence(true)
    end
end)
