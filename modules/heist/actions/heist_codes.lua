-- NiceTrainer - Native Heist Codes & Objectives Integration
-- Combines Code On HUD (chat parser) and EHI (level script triggers & codes auto-detection)
-- Built with full HUD repositioning (matching ECM Timer positioning system)

local function parse_hex_color(hex_str, default_color)
    if not hex_str or type(hex_str) ~= "string" then return default_color or Color.white end
    hex_str = hex_str:gsub("#", "")
    if #hex_str == 6 then
        local r = tonumber(hex_str:sub(1, 2), 16) or 255
        local g = tonumber(hex_str:sub(3, 4), 16) or 255
        local b = tonumber(hex_str:sub(5, 6), 16) or 255
        return Color(r / 255, g / 255, b / 255)
    end
    return default_color or Color.white
end

local function get_instance_element_id(id, start_index, continent_index)
    if continent_index then
        return continent_index + math.mod(id, 100000) + 30000 + start_index
    end
    return id + 30000 + start_index
end

local function get_instance_unit_id(id, start_index, continent_index)
    return get_instance_element_id(id, start_index, continent_index)
end

-- =========================================================================
-- HUD CODE DISPLAY CLASS
-- =========================================================================
_G.HUDCodeDisplay = _G.HUDCodeDisplay or class()

function HUDCodeDisplay:init(hud)
    self._hud_panel = hud and hud.panel
    if not self._hud_panel then return end

    -- Destroy old panel if reloading
    local old_panel = self._hud_panel:child("heist_code_display_panel")
    if old_panel and alive(old_panel) then
        self._hud_panel:remove(old_panel)
    end

    self._panel = self._hud_panel:panel({
        name = "heist_code_display_panel",
        visible = false,
        w = 400,
        h = 38,
        layer = 10
    })

    local code_icon = self._panel:bitmap({
        name = "code_icon",
        texture = "guis/textures/pd2/skilltree/icons_atlas",
        texture_rect = { 0 * 64, 8 * 64, 64, 64 },
        valign = "center",
        align = "left",
        layer = 1,
        h = 38,
        w = 38,
        color = Color.white
    })
    self._icon = code_icon

    local box = HUDBGBox_create(self._panel, { w = 68, h = 38 }, {})
    box:set_left(code_icon:right() + 4)
    box:set_center_y(code_icon:h() / 2)
    self._box = box

    self._code = box:text({
        name = "code",
        text = "",
        valign = "center",
        align = "center",
        vertical = "center",
        w = box:w(),
        h = box:h(),
        layer = 2,
        color = Color.white,
        font = tweak_data.hud_stats and tweak_data.hud_stats.objectives_font or "fonts/font_medium_shadow_mf",
        font_size = tweak_data.hud_stats and tweak_data.hud_stats.objectives_title_size or 22
    })

    local digit_w = box:w() / 3
    self._digit_red = box:text({
        name = "digit_red",
        text = "",
        valign = "center",
        align = "center",
        vertical = "center",
        w = digit_w,
        h = box:h(),
        x = 0,
        layer = 2,
        color = Color(1, 0.25, 0.25),
        font = tweak_data.hud_stats and tweak_data.hud_stats.objectives_font or "fonts/font_medium_shadow_mf",
        font_size = tweak_data.hud_stats and tweak_data.hud_stats.objectives_title_size or 22
    })

    self._digit_green = box:text({
        name = "digit_green",
        text = "",
        valign = "center",
        align = "center",
        vertical = "center",
        w = digit_w,
        h = box:h(),
        x = digit_w,
        layer = 2,
        color = Color(0.25, 1, 0.25),
        font = tweak_data.hud_stats and tweak_data.hud_stats.objectives_font or "fonts/font_medium_shadow_mf",
        font_size = tweak_data.hud_stats and tweak_data.hud_stats.objectives_title_size or 22
    })

    self._digit_blue = box:text({
        name = "digit_blue",
        text = "",
        valign = "center",
        align = "center",
        vertical = "center",
        w = digit_w,
        h = box:h(),
        x = digit_w * 2,
        layer = 2,
        color = Color(0.25, 0.8, 1),
        font = tweak_data.hud_stats and tweak_data.hud_stats.objectives_font or "fonts/font_medium_shadow_mf",
        font_size = tweak_data.hud_stats and tweak_data.hud_stats.objectives_title_size or 22
    })

    self:update_position()
end

function HUDCodeDisplay:_resize_box(target_w)
    if not alive(self._box) then return end
    target_w = math.max(68, math.ceil(target_w or 68))
    self._box:set_w(target_w)

    local right_top = self._box:child("right_top")
    if right_top and alive(right_top) then
        right_top:set_right(target_w)
    end
    local right_bottom = self._box:child("right_bottom")
    if right_bottom and alive(right_bottom) then
        right_bottom:set_right(target_w)
    end

    if alive(self._code) then
        self._code:set_w(target_w)
    end

    if alive(self._panel) then
        self._panel:set_w(self._box:right() + 8)
    end
end

function HUDCodeDisplay:update_position()
    if not alive(self._panel) or not self._hud_panel then return end

    local is_enabled = (NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled ~= false)
    if not is_enabled then
        self._panel:set_visible(false)
        return
    end

    local custom_pos = NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_custom_pos
    if custom_pos then
        local x = tonumber(NiceTrainer.Settings.heist_codes_pos_x) or 600
        local y = tonumber(NiceTrainer.Settings.heist_codes_pos_y) or 80
        self._panel:set_x(x)
        self._panel:set_y(y)
    else
        local timer = self._hud_panel:child("heist_timer_panel")
        if timer and alive(timer) then
            self._panel:set_center_x(self._hud_panel:center_x())
            self._panel:set_y(timer:y() + 40)
        else
            self._panel:set_center_x(self._hud_panel:w() / 2)
            self._panel:set_y(80)
        end
    end
end

function HUDCodeDisplay:set_numeric_code(code_str)
    if not alive(self._panel) then return end
    if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled == false then return end

    self._digit_red:set_visible(false)
    self._digit_green:set_visible(false)
    self._digit_blue:set_visible(false)

    self._code:set_text(tostring(code_str))
    self._code:set_color(Color.white)
    self._code:set_visible(true)

    local _, _, tw, _ = self._code:text_rect()
    self:_resize_box(math.max(68, math.ceil(tw) + 20))

    self._panel:set_visible(true)
    self:update_position()
end

function HUDCodeDisplay:set_rgb(r, g, b)
    if not alive(self._panel) then return end
    if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled == false then return end

    self._code:set_visible(false)
    self:_resize_box(68)

    local digit_w = 68 / 3
    self._digit_red:set_w(digit_w)
    self._digit_red:set_x(0)
    self._digit_green:set_w(digit_w)
    self._digit_green:set_x(digit_w)
    self._digit_blue:set_w(digit_w)
    self._digit_blue:set_x(digit_w * 2)

    if r and r ~= '-' then
        self._digit_red:set_text(tostring(r))
        self._digit_red:set_visible(true)
    end
    if g and g ~= '-' then
        self._digit_green:set_text(tostring(g))
        self._digit_green:set_visible(true)
    end
    if b and b ~= '-' then
        self._digit_blue:set_text(tostring(b))
        self._digit_blue:set_visible(true)
    end

    self._panel:set_visible(true)
    self:update_position()
end

function HUDCodeDisplay:set_rgb_part(r, g, b)
    if not alive(self._panel) then return end
    if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled == false then return end

    self._code:set_visible(false)
    self:_resize_box(68)

    local digit_w = 68 / 3
    self._digit_red:set_w(digit_w)
    self._digit_red:set_x(0)
    self._digit_green:set_w(digit_w)
    self._digit_green:set_x(digit_w)
    self._digit_blue:set_w(digit_w)
    self._digit_blue:set_x(digit_w * 2)

    if r then
        self._digit_red:set_text(tostring(r))
        self._digit_red:set_visible(true)
    end
    if g then
        self._digit_green:set_text(tostring(g))
        self._digit_green:set_visible(true)
    end
    if b then
        self._digit_blue:set_text(tostring(b))
        self._digit_blue:set_visible(true)
    end

    self._panel:set_visible(true)
    self:update_position()
end

function HUDCodeDisplay:set_info_text(text, color)
    if not alive(self._panel) then return end
    if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled == false then return end

    self._digit_red:set_visible(false)
    self._digit_green:set_visible(false)
    self._digit_blue:set_visible(false)

    self._code:set_text(tostring(text))
    self._code:set_color(color or Color(1, 0.9, 0.4))
    self._code:set_visible(true)

    local _, _, tw, _ = self._code:text_rect()
    self:_resize_box(math.max(68, math.ceil(tw) + 24))

    self._panel:set_visible(true)
    self:update_position()
end

function HUDCodeDisplay:clear()
    if not alive(self._panel) then return end
    self._digit_red:set_text("")
    self._digit_green:set_text("")
    self._digit_blue:set_text("")
    self._code:set_text("")
    self:_resize_box(68)
    self._panel:set_visible(false)
end

-- =========================================================================
-- CODE PARSING LOGIC (CHAT & LEVEL)
-- =========================================================================
local function get_or_create_hud_display()
    if not managers.hud then return nil end
    if not managers.hud._hud_code_display then
        local script_panel = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
        if script_panel then
            managers.hud._hud_code_display = HUDCodeDisplay:new(script_panel)
        end
    end
    return managers.hud._hud_code_display
end

local function look_for_code_parts(message)
    local m = message:lower()
    return m:find('r') ~= nil, m:find('g') ~= nil, m:find('b') ~= nil
end

local function process_incoming_code(message)
    if NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.heist_codes_enabled == false then return end
    if not message or type(message) ~= "string" then return end

    local display = get_or_create_hud_display()
    if not display then return end

    local clean = message:gsub("%s+", "")
    local clean_lower = clean:lower()

    if clean_lower == "close_code" or clean_lower == "clear_code" then
        display:clear()
        return
    end

    local len = string.len(clean)

    -- Case 1: 2-char code part (r3, g7, b1, 3r, etc.)
    if len == 2 then
        local r, g, b = look_for_code_parts(clean)
        local d = clean:match("(%d)")
        if (r or g or b) and d then
            display:set_rgb_part(r and d, g and d, b and d)
            return
        end
    end

    -- Case 2: 3-digit RGB code (123, 582, etc.)
    if len == 3 and tonumber(clean) and tonumber(clean) >= 0 then
        local r = clean:sub(1, 1)
        local g = clean:sub(2, 2)
        local b = clean:sub(3, 3)
        display:set_rgb(r, g, b)
        return
    end

    -- Case 3: 4-digit code (1234, 5920, etc.)
    if len == 4 and tonumber(clean) and tonumber(clean) >= 0 then
        display:set_numeric_code(clean)
        return
    end

    -- Case 4: Regex check if message contains a 4-digit number (e.g. "code is 1234")
    local match4 = clean:match("(%d%d%d%d)")
    if match4 then
        display:set_numeric_code(match4)
        return
    end
end

-- =========================================================================
-- LEVEL SPECIFIC DETECTIONS & REAL-TIME SCANNER (EHI Integration)
-- =========================================================================
local _level_hooks_installed = false

local function scan_active_level_codes(display)
    if not display or not (Global.game_settings and Global.game_settings.level_id) then return end
    local level_id = Global.game_settings.level_id
    local wd = managers.worlddefinition

    -- 1. Golden Grin Casino (kenaz)
    if level_id == "kenaz" or level_id == "cas" or level_id == "golden_grin" then
        if wd then
            local keycode_units = {
                red = { unit_id = 100000, indexes = { 28250, 15020, 15120 } },
                green = { unit_ids = { 100125, 100113, 100224, 100225, 100007, 100290 }, indexes = { 21500, 25000, 31225 } },
                blue = { unit_ids = { 100061, 100064 }, index = 15370 }
            }
            local found_r, found_g, found_b = nil, nil, nil
            for color, data in pairs(keycode_units) do
                local function check_u(u_id)
                    local unit = wd:get_unit(u_id)
                    if unit and alive(unit) then
                        for i = 0, 9 do
                            local obj = unit:get_object(Idstring(string.format("g_number_%s_0%d", color, i)))
                            if obj and obj:visibility() then
                                if color == "red" then found_r = i
                                elseif color == "green" then found_g = i
                                elseif color == "blue" then found_b = i end
                                return true
                            end
                        end
                    end
                    return false
                end

                if data.unit_ids then
                    for _, u in ipairs(data.unit_ids) do
                        if data.indexes then
                            for _, idx in ipairs(data.indexes) do
                                if check_u(get_instance_unit_id(u, idx)) then break end
                            end
                        elseif data.index then
                            if check_u(get_instance_unit_id(u, data.index)) then break end
                        else
                            if check_u(u) then break end
                        end
                    end
                else
                    if data.indexes then
                        for _, idx in ipairs(data.indexes) do
                            if check_u(get_instance_unit_id(data.unit_id, idx)) then break end
                        end
                    elseif data.index then
                        check_u(get_instance_unit_id(data.unit_id, data.index))
                    else
                        check_u(data.unit_id)
                    end
                end
            end
            if found_r or found_g or found_b then
                display:set_rgb_part(found_r, found_g, found_b)
            end
        end
    end

    -- 2. Car Shop (cage)
    if level_id == "cage" and wd then
        local names = {
            [Idstring("g_name_01")] = "Bob Rogers", [Idstring("g_name_02")] = "David Meizler",
            [Idstring("g_name_03")] = "Steven Jordan", [Idstring("g_name_04")] = "Karen T. Hanley",
            [Idstring("g_name_05")] = "Edward Black", [Idstring("g_name_06")] = "Cynthia Lopez",
            [Idstring("g_name_07")] = "Franci Collins", [Idstring("g_name_08")] = "Donald Alexander",
            [Idstring("g_name_09")] = "Michael Disarro", [Idstring("g_name_10")] = "Amy Herman",
            [Idstring("g_name_11")] = "Matthew Putnick", [Idstring("g_name_12")] = "Brandon Martinez",
            [Idstring("g_name_13")] = "David Buono", [Idstring("g_name_14")] = "Mary Brown",
            [Idstring("g_name_15")] = "Carson Daniels", [Idstring("g_name_16")] = "Marc Bailey",
            [Idstring("g_name_17")] = "Carolyn Worster"
        }
        local whiteboard = wd:get_unit(101889)
        if whiteboard and alive(whiteboard) then
            for object, name in pairs(names) do
                if whiteboard:get_object(object) and whiteboard:get_object(object):visibility() then
                    display:set_info_text(name, Color(1, 0.9, 0.4))
                    break
                end
            end
        end
    end

    -- 3. Diamond Heist (dah)
    if level_id == "dah" and wd then
        local dah_laptops = { red = 1900, green = 2100, blue = 2300 }
        local dr, dg, db = nil, nil, nil
        for color, offset in pairs(dah_laptops) do
            local unit = wd:get_unit(get_instance_unit_id(100052, offset))
            if unit and alive(unit) then
                for i = 0, 9 do
                    local obj = unit:get_object(Idstring(string.format("g_number_%s_0%d", color, i)))
                    if obj and obj:visibility() then
                        if color == "red" then dr = i
                        elseif color == "green" then dg = i
                        elseif color == "blue" then db = i end
                        break
                    end
                end
            end
        end
        if dr or dg or db then
            display:set_rgb_part(dr, dg, db)
        end
    end

    -- 4. Black Cat / Mountain Master (chca)
    if level_id == "chca" and wd then
        local paper = wd:get_unit(get_instance_element_id(100000, 14470))
        if paper and alive(paper) then
            local code_digits = {}
            for i = 1, 4 do
                for j = 0, 9 do
                    local obj = paper:get_object(Idstring(string.format("g_%d_%d", i, j)))
                    if obj and obj:visibility() then
                        code_digits[i] = tostring(j)
                        break
                    end
                end
            end
            if #code_digits == 4 then
                display:set_numeric_code(table.concat(code_digits))
            end
        end
    end

    -- 5. Breakfast in Tijuana / San Martín (fex)
    if level_id == "fex" and wd then
        for _, offset in ipairs({ 3550, 3750 }) do
            local paper = wd:get_unit(get_instance_element_id(100140, offset))
            if paper and alive(paper) then
                local code_digits = {}
                for i = 1, 4 do
                    for j = 0, 9 do
                        local obj = paper:get_object(Idstring(string.format("g_%d_%d", i, j)))
                        if obj and obj:visibility() then
                            code_digits[i] = tostring(j)
                            break
                        end
                    end
                end
                if #code_digits == 4 then
                    display:set_numeric_code(table.concat(code_digits))
                    break
                end
            end
        end
    end

    -- 6. Shacklethorne Auction (sah / auc)
    if (level_id == "sah" or level_id == "auc") and wd then
        local code_on_variable = { { 1, 2 }, { 3, 4 }, { 1, 9 }, { 6, 3 }, { 7, 1 }, { 9, 5 } }
        for i = 2892, 3837, 189 do
            local u1 = wd:get_unit(get_instance_element_id(100065, i))
            local u2 = wd:get_unit(get_instance_element_id(100064, i))
            if u1 and alive(u1) and u1:damage() and u1:damage()._variables and u2 and alive(u2) and u2:damage() and u2:damage()._variables then
                local p1 = code_on_variable[u1:damage()._variables.var_code or 0]
                local p2 = code_on_variable[u2:damage()._variables.var_code or 0]
                if p1 and p2 then
                    display:set_numeric_code(string.format("%d%d%d%d", p1[1], p1[2], p2[1], p2[2]))
                    break
                end
            end
        end
    end

    -- 7. White House (vit)
    if level_id == "vit" and wd then
        local gate_box = wd:get_unit(get_instance_unit_id(100018, 4550))
        if gate_box and alive(gate_box) then
            local wires = {}
            if gate_box:get_object(Idstring("g_light_01")) and gate_box:get_object(Idstring("g_light_01")):visibility() then table.insert(wires, "R") end
            if gate_box:get_object(Idstring("g_light_02")) and gate_box:get_object(Idstring("g_light_02")):visibility() then table.insert(wires, "G") end
            if gate_box:get_object(Idstring("g_light_03")) and gate_box:get_object(Idstring("g_light_03")):visibility() then table.insert(wires, "B") end
            if gate_box:get_object(Idstring("g_light_04")) and gate_box:get_object(Idstring("g_light_04")):visibility() then table.insert(wires, "Y") end
            if #wires > 0 and not (display._code and display._code:visible()) then
                display:set_info_text(table.concat(wires, " "), Color(0.3, 0.9, 1))
            end
        end
    end
end

local function install_level_sequence_hooks()
    if not (managers.mission and Global.game_settings and Global.game_settings.level_id) then return end
    local level_id = Global.game_settings.level_id
    if _level_hooks_installed == level_id then return end
    _level_hooks_installed = level_id

    -- Golden Grin Casino (kenaz)
    if level_id == "kenaz" or level_id == "cas" or level_id == "golden_grin" then
        local keycode_units = {
            red = { unit_id = 100000, indexes = { 28250, 15020, 15120 } },
            green = { unit_ids = { 100125, 100113, 100224, 100225, 100007, 100290 }, indexes = { 21500, 25000, 31225 } },
            blue = { unit_ids = { 100061, 100064 }, index = 15370 }
        }
        for color, data in pairs(keycode_units) do
            local function hook_u(u_id)
                for i = 0, 9 do
                    managers.mission:add_runned_unit_sequence_trigger(u_id, string.format("set_%s_0%d", color, i), function(...)
                        local d = get_or_create_hud_display()
                        if d then
                            if color == "red" then d:set_rgb_part(i, nil, nil)
                            elseif color == "green" then d:set_rgb_part(nil, i, nil)
                            elseif color == "blue" then d:set_rgb_part(nil, nil, i) end
                        end
                    end)
                end
            end
            if data.unit_ids then
                for _, u in ipairs(data.unit_ids) do
                    if data.indexes then
                        for _, idx in ipairs(data.indexes) do hook_u(get_instance_unit_id(u, idx)) end
                    elseif data.index then
                        hook_u(get_instance_unit_id(u, data.index))
                    else
                        hook_u(u)
                    end
                end
            else
                if data.indexes then
                    for _, idx in ipairs(data.indexes) do hook_u(get_instance_unit_id(data.unit_id, idx)) end
                elseif data.index then
                    hook_u(get_instance_unit_id(data.unit_id, data.index))
                else
                    hook_u(data.unit_id)
                end
            end
        end
    end
end

local function handle_mission_element_code(elem_id)
    if not (Global.game_settings and Global.game_settings.level_id) then return end
    local level_id = Global.game_settings.level_id
    local display = get_or_create_hud_display()
    if not display then return end

    -- Hotline Miami Day 1 (mia_1)
    if level_id == "mia_1" then
        local districts = {
            [100396] = "Downtown", [100551] = "Georgetown", [100558] = "West End",
            [100559] = "Foggy Bottom", [100642] = "Shaw"
        }
        if districts[elem_id] then
            display:set_info_text(districts[elem_id], Color(1, 0.9, 0.4))
        elseif elem_id == 105065 then
            display:clear()
        end
    end

    -- Shacklethorne Auction (sah / auc)
    if level_id == "sah" or level_id == "auc" then
        for i = 100169, 100208 do
            if elem_id == get_instance_element_id(i, 18200) then
                local digit = (i - 100169) % 10
                local pos = math.floor((i - 100169) / 10) + 1
                local current = (display._code and display._code:text()) or "----"
                if #current ~= 4 then current = "----" end
                local chars = { current:sub(1,1), current:sub(2,2), current:sub(3,3), current:sub(4,4) }
                chars[pos] = tostring(digit)
                display:set_numeric_code(table.concat(chars))
                break
            end
        end
    end

    -- White House (vit)
    if level_id == "vit" then
        for i = 102622, 102661 do
            if elem_id == i then
                local digit = (i - 102622) % 10
                local pos = math.floor((i - 102622) / 10) + 1
                local current = (display._code and display._code:text()) or "----"
                if #current ~= 4 then current = "----" end
                local chars = { current:sub(1,1), current:sub(2,2), current:sub(3,3), current:sub(4,4) }
                chars[pos] = tostring(digit)
                display:set_numeric_code(table.concat(chars))
                break
            end
        end
        if elem_id == get_instance_element_id(100230, 12900) then
            display:clear()
        end
    end
end

-- =========================================================================
-- HUD UPDATE WITH AUTO SCANNER
-- =========================================================================
function HUDCodeDisplay:update()
    if not alive(self._panel) then return end
    self:update_position()

    -- Run level scanner periodically (every 1 second)
    local t = TimerManager:game() and TimerManager:game():time() or 0
    if not self._last_scan_t or (t - self._last_scan_t > 1.0) then
        self._last_scan_t = t
        scan_active_level_codes(self)
        install_level_sequence_hooks()
    end
end

-- =========================================================================
-- ENGINE HOOKS REGISTRATION
-- =========================================================================

-- 1. HUD Manager Setup & Update
if _G.HUDManager and not NiceTrainer._hc_hud_hooked then
    NiceTrainer._hc_hud_hooked = true

    Hooks:PostHook(HUDManager, "_setup_player_info_hud_pd2", "NiceTrainer_HC_SetupPlayerInfoHud", function(self)
        self._hud_code_display = HUDCodeDisplay:new(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
    end)

    Hooks:PostHook(HUDManager, "update", "NiceTrainer_HC_HUDUpdate", function(self)
        if self._hud_code_display then
            self._hud_code_display:update()
        end
    end)
end

-- If already in heist, instantiate display immediately
if managers.hud and not managers.hud._hud_code_display and managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2) then
    managers.hud._hud_code_display = HUDCodeDisplay:new(managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2))
end

-- 2. HUD Chat Receive Message
if _G.HUDChat and not NiceTrainer._hc_hudchat_hooked then
    NiceTrainer._hc_hudchat_hooked = true
    Hooks:PostHook(HUDChat, "receive_message", "NiceTrainer_HC_ReceiveMessage", function(self, name, message, color, icon)
        process_incoming_code(message)
    end)
end

-- 3. Chat Manager Send Message
if _G.ChatManager and not NiceTrainer._hc_chatmanager_hooked then
    NiceTrainer._hc_chatmanager_hooked = true
    Hooks:PostHook(ChatManager, "send_message", "NiceTrainer_HC_SendMessage", function(self, channel_id, sender, message)
        process_incoming_code(message)
    end)
end

-- 4. Mission Script Elements (Host & Client)
if _G.MissionScriptElement and not NiceTrainer._hc_mission_element_hooked then
    NiceTrainer._hc_mission_element_hooked = true

    Hooks:PostHook(MissionScriptElement, "on_executed", "NiceTrainer_HC_MissionElementExecuted", function(self, instigator)
        handle_mission_element_code(self._id)
    end)

    if MissionScriptElement.client_on_executed then
        Hooks:PostHook(MissionScriptElement, "client_on_executed", "NiceTrainer_HC_ClientMissionElementExecuted", function(self, instigator)
            handle_mission_element_code(self._id)
        end)
    end
end

-- =========================================================================
-- NICETRAINER ACTIONS REGISTRATION
-- =========================================================================
if not NiceTrainer._heist_codes_registered and NiceTrainer and NiceTrainer.RegisterAction then
    NiceTrainer._heist_codes_registered = true

    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Heist Codes & Objectives",
        badge = "client",
        id = "heist_codes_enabled",
        text = "Heist Codes & Objectives HUD",
        tooltip = "Displays active vault codes, keypad passwords, and chat codes directly on the HUD.",
        default = true,
        save = true,
        callback = function(state)
            if managers.hud and managers.hud._hud_code_display then
                managers.hud._hud_code_display:update_position()
                if not state then
                    managers.hud._hud_code_display:clear()
                end
            end
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Heist Codes & Objectives",
        id = "heist_codes_custom_pos",
        text = "Custom Position Mode",
        tooltip = "Enable manual positioning using the sliders below (instead of auto-centering below the heist timer).",
        default = false,
        save = true,
        callback = function(state)
            if managers.hud and managers.hud._hud_code_display then
                managers.hud._hud_code_display:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "slider",
        category = "Heist Codes & Objectives",
        id = "heist_codes_pos_x",
        text = "Manual Position (X)",
        tooltip = "Horizontal screen coordinate when Custom Position Mode is active.",
        min = 10,
        max = 1900,
        default = 600,
        save = true,
        callback = function(val)
            if managers.hud and managers.hud._hud_code_display then
                managers.hud._hud_code_display:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "slider",
        category = "Heist Codes & Objectives",
        id = "heist_codes_pos_y",
        text = "Manual Position (Y)",
        tooltip = "Vertical screen coordinate when Custom Position Mode is active.",
        min = 10,
        max = 1000,
        default = 80,
        save = true,
        callback = function(val)
            if managers.hud and managers.hud._hud_code_display then
                managers.hud._hud_code_display:update_position()
            end
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Heist Codes & Objectives",
        badge = "client",
        text = "Clear Active HUD Code",
        tooltip = "Clears and hides the currently displayed code on the HUD.",
        action_btn_text = "Clear",
        callback = function()
            if managers.hud and managers.hud._hud_code_display then
                managers.hud._hud_code_display:clear()
            end
            NiceTrainer:Toast("HUD code cleared.")
        end
    })
end
