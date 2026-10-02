-- Golden Grin Casino (kenaz) - Vault Codes, Briefcases, Key Items & Keypad Solver
-- Integrated with 3D World Waypoints, real-time code decoder, and automatic waypoint cleanup

NiceTrainer = NiceTrainer or {}
NiceTrainer.GoldenGrin = NiceTrainer.GoldenGrin or {
    waypoints = {},
    codes = { red = nil, green = nil, blue = nil },
    briefcase_positions = { red = nil, green = nil, blue = nil }
}

local GGC = NiceTrainer.GoldenGrin

local function is_kenaz()
    if Global.game_settings and Global.game_settings.level_id == "kenaz" then
        return true
    end
    if managers.job and managers.job:current_level_id() == "kenaz" then
        return true
    end
    return false
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
-- 3D WAYPOINT CREATOR & MANAGER
-- =========================================================================
function GGC:AddWaypoint(id, pos, text, color, icon)
    if not (managers.hud and pos) then return end
    self.waypoints[id] = { position = pos, text = text }

    local icon_name = icon or "wp_standard"
    if not (tweak_data and tweak_data.hud_icons and tweak_data.hud_icons[icon_name]) then
        icon_name = "wp_standard"
    end

    local wp_data = {
        icon = icon_name,
        distance = true,
        position = pos,
        no_sync = true,
        present_timer = 0,
        state = "present",
        radius = 50,
        color = color or Color.white,
        blend_mode = "normal"
    }

    managers.hud:add_waypoint(id, wp_data)

    -- Explicitly configure bitmap, text, arrow and distance elements on HUD
    if managers.hud._hud and managers.hud._hud.waypoints and managers.hud._hud.waypoints[id] then
        local wp = managers.hud._hud.waypoints[id]
        if wp.bitmap and alive(wp.bitmap) then
            wp.bitmap:set_color(color or Color.white)
            wp.bitmap:set_visible(true)
        end
        if wp.arrow and alive(wp.arrow) then
            wp.arrow:set_color((color or Color.white):with_alpha(0.8))
        end
        if wp.distance and alive(wp.distance) then
            wp.distance:set_color(color or Color.white)
            wp.distance:set_visible(true)
        end
        if text and wp.text and alive(wp.text) then
            wp.text:set_text(utf8.to_upper(" " .. tostring(text)))
            local _, _, w, _ = wp.text:text_rect()
            wp.text:set_w(w)
            wp.text:set_color(color or Color.white)
            wp.text:set_visible(true)
        end
    end
end

function GGC:RemoveWaypoint(id)
    if managers.hud then
        managers.hud:remove_waypoint(id)
    end
    self.waypoints[id] = nil
end

function GGC:RemoveNearestWaypoint(pos, max_dist)
    if not pos or not managers.hud then return end
    max_dist = max_dist or 400
    local closest_id = nil
    local closest_dist = max_dist

    for id, data in pairs(self.waypoints) do
        if data and data.position then
            local dist = mvector3.distance(pos, data.position)
            if dist < closest_dist then
                closest_dist = dist
                closest_id = id
            end
        end
    end

    if closest_id then
        self:RemoveWaypoint(closest_id)
    end
end

function GGC:ClearAllWaypoints()
    if managers.hud then
        for id, _ in pairs(self.waypoints) do
            managers.hud:remove_waypoint(id)
        end
    end
    self.waypoints = {}
end

-- =========================================================================
-- CODE DECODER & BRIEFCASES 3D WAYPOINTS
-- =========================================================================
function GGC:ScanAndDecodeVaultCodes()
    local wd = managers.worlddefinition
    local found_digits = { red = nil, green = nil, blue = nil }
    local found_positions = { red = nil, green = nil, blue = nil }

    local keycode_units = {
        red = { unit_ids = { 100000 }, indexes = { 28250, 15020, 15120 } },
        green = { unit_ids = { 100125, 100113, 100224, 100225, 100007, 100290 }, indexes = { 21500, 25000, 31225 } },
        blue = { unit_ids = { 100061, 100064 }, indexes = { 15370 } }
    }

    -- 1. Check known level instances in worlddefinition
    if wd then
        for color, data in pairs(keycode_units) do
            for _, u_id in ipairs(data.unit_ids) do
                for _, idx in ipairs(data.indexes) do
                    local real_id = get_instance_unit_id(u_id, idx)
                    local unit = wd:get_unit(real_id)
                    if unit and alive(unit) then
                        local is_active = unit:enabled()
                        if unit:interaction() and unit:interaction():active() then
                            is_active = true
                        end
                        if unit:get_object(Idstring("g_top_opened")) and unit:get_object(Idstring("g_top_opened")):visibility() then
                            is_active = true
                        end

                        for i = 0, 9 do
                            local obj = unit:get_object(Idstring(string.format("g_number_%s_0%d", color, i)))
                            if obj then
                                if obj:visibility() then
                                    found_digits[color] = i
                                    found_positions[color] = unit:position() + Vector3(0, 0, 30)
                                    break
                                elseif is_active and not found_positions[color] then
                                    found_positions[color] = unit:position() + Vector3(0, 0, 30)
                                end
                            end
                        end

                        if is_active and not found_positions[color] then
                            found_positions[color] = unit:position() + Vector3(0, 0, 30)
                        end
                    end
                end
            end
        end
    end

    -- 2. Scan all World units & interactive units as fallback / confirmation
    for _, u in pairs(World:find_units_quick("all")) do
        if alive(u) then
            for _, color in ipairs({ "red", "green", "blue" }) do
                for i = 0, 9 do
                    local obj = u:get_object(Idstring(string.format("g_number_%s_0%d", color, i)))
                    if obj then
                        if obj:visibility() then
                            found_digits[color] = i
                            found_positions[color] = u:position() + Vector3(0, 0, 30)
                        elseif (u:enabled() or (u:interaction() and u:interaction():active())) and not found_positions[color] then
                            found_positions[color] = u:position() + Vector3(0, 0, 30)
                        end
                    end
                end
            end
        end
    end

    self.codes = found_digits
    self.briefcase_positions = found_positions

    -- 3. Place 3D Waypoints on all found Briefcases with clear icons and text
    if found_positions.red then
        local r_label = "RED CODE [" .. (found_digits.red ~= nil and tostring(found_digits.red) or "?") .. "]"
        self:AddWaypoint("kenaz_wp_code_red", found_positions.red, r_label, Color(1, 0.25, 0.25), "wp_standard")
    end
    if found_positions.green then
        local g_label = "GREEN CODE [" .. (found_digits.green ~= nil and tostring(found_digits.green) or "?") .. "]"
        self:AddWaypoint("kenaz_wp_code_green", found_positions.green, g_label, Color(0.25, 1, 0.25), "wp_standard")
    end
    if found_positions.blue then
        local b_label = "BLUE CODE [" .. (found_digits.blue ~= nil and tostring(found_digits.blue) or "?") .. "]"
        self:AddWaypoint("kenaz_wp_code_blue", found_positions.blue, b_label, Color(0.25, 0.75, 1), "wp_standard")
    end

    -- Update HUD Display
    if managers.hud and managers.hud._hud_code_display then
        managers.hud._hud_code_display:set_rgb_part(found_digits.red, found_digits.green, found_digits.blue)
    end

    local r_str = found_digits.red ~= nil and tostring(found_digits.red) or "?"
    local g_str = found_digits.green ~= nil and tostring(found_digits.green) or "?"
    local b_str = found_digits.blue ~= nil and tostring(found_digits.blue) or "?"

    local code_msg = string.format("RED: [%s] | GREEN: [%s] | BLUE: [%s]", r_str, g_str, b_str)
    NiceTrainer:Toast("🎰 Vault Codes: " .. code_msg)
    if managers.chat then
        managers.chat:feed_system_message(ChatManager.GAME, "[NiceTrainer] Golden Grin Vault Codes: " .. code_msg)
    end

    return found_digits
end

-- =========================================================================
-- AUTO-ENTER VAULT CODE INTO KEYPAD (INSTANT UNLOCK VAULT)
-- =========================================================================
function GGC:UnlockVaultKeypad()
    local executed = false
    if managers.mission and managers.mission._scripts then
        for _, script in pairs(managers.mission._scripts) do
            for _, elem in pairs(script:elements()) do
                local name = string.lower(elem:editor_name() or "")
                local id = elem._id or 0
                if id == 102761 or id == 101357 
                   or name:find("keypad_correct", 1, true) 
                   or name:find("vault_code_correct", 1, true) 
                   or name:find("vault_gate_open", 1, true) 
                   or name:find("inner_door_open", 1, true) then
                    pcall(function()
                        elem:on_executed()
                        executed = true
                    end)
                end
            end
        end
    end

    if executed then
        NiceTrainer:Toast("🔓 Vault Keypad Code Submitted! Doors Unlocked.")
    else
        NiceTrainer:Toast("Vault keypad elements not active yet. Reach the vault area first.")
    end
end

-- =========================================================================
-- AUTO-REMOVE WAYPOINTS ON INTERACTION COMPLETED
-- =========================================================================
if _G.BaseInteractionExt and not GGC._interaction_hooked then
    GGC._interaction_hooked = true

    Hooks:PostHook(BaseInteractionExt, "interact", "NiceTrainer_GGC_AutoRemoveWP", function(self, player)
        if is_kenaz() then
            local tw = tostring(self._tweak_data or ""):lower()
            local u_pos = self._unit and alive(self._unit) and self._unit:position()

            -- Briefcases
            if tw:find("briefcase", 1, true) or tw == "cas_open_briefcase" then
                if u_pos then
                    GGC:RemoveNearestWaypoint(u_pos, 250)
                end
            -- USB Key
            elseif tw:find("usb", 1, true) then
                if u_pos then GGC:RemoveNearestWaypoint(u_pos, 250) end
            -- Gear Bag
            elseif tw:find("cas_gear", 1, true) or tw:find("gear", 1, true) then
                if u_pos then GGC:RemoveNearestWaypoint(u_pos, 250) end
            -- Casino Chips
            elseif tw == "cas_chips_pile" then
                if u_pos then GGC:RemoveNearestWaypoint(u_pos, 200) end
            end
        end
    end)
end

-- =========================================================================
-- REGISTRATION IN HEIST TAB
-- =========================================================================
if not _G.NT_GoldenGrin_Actions_Registered and NiceTrainer and NiceTrainer.RegisterAction then
    _G.NT_GoldenGrin_Actions_Registered = true

    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Golden Grin Casino (kenaz)",
        level_id = { "kenaz", "cas", "golden_grin" },
        badge = "client",
        text = "Find & Mark 3 Vault Code Briefcases",
        tooltip = "Scans game units, decodes Red/Green/Blue vault numbers, updates the HUD display, and places 3D Waypoints on all 3 briefcases.",
        action_btn_text = "Decode",
        callback = function()
            GGC:ScanAndDecodeVaultCodes()
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Golden Grin Casino (kenaz)",
        level_id = { "kenaz", "cas", "golden_grin" },
        badge = "host",
        text = "Auto-Enter Vault Code into Keypad",
        tooltip = "Triggers the keypad unlock elements directly to instantly open the vault inner door and cages.",
        action_btn_text = "Unlock",
        callback = function()
            GGC:UnlockVaultKeypad()
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Golden Grin Casino (kenaz)",
        level_id = { "kenaz", "cas", "golden_grin" },
        badge = "client",
        text = "Clear All Golden Grin 3D Waypoints",
        tooltip = "Removes all currently active 3D world waypoints placed by the Golden Grin helper.",
        action_btn_text = "Clear",
        callback = function()
            GGC:ClearAllWaypoints()
            NiceTrainer:Toast("Golden Grin waypoints cleared.")
        end
    })
end
