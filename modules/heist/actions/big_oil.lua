-- Big Oil Day 2 (welcome_to_the_jungle_2 / big_oil_2) - Fusion Engine Calculator & HUD Overlay Helper
-- Fully synced with mission script element execution and manual intel clue solver.

NiceTrainer.BigOilHelper = NiceTrainer.BigOilHelper or {
    enabled = false,
    auto_highlight = true,
    chat_announce = false,
    ws = nil,
    panel = nil,
    txt_status = nil,
    txt_subinfo = nil,
    border_rects = {},
    correct_element_id = nil,
    correct_engine_num = nil,
    correct_pos = nil,
    correct_unit = nil,
    engine_data = nil,
    current_status = "AWAITING ENGINE SELECTION...",
    current_subinfo = "Waiting for lab mission trigger / Intel scan",
    current_color = Color(0.6, 0.6, 0.6),
    highlighted_units = {},
    clue_units = {},
    active_waypoint_id = nil,
    manual_gas = 1,
    manual_hoses = 1,
    manual_pressure = 1
}

local B = NiceTrainer.BigOilHelper

local function is_in_big_oil_heist()
    if not (NiceTrainer and NiceTrainer.IsInHeist and NiceTrainer:IsInHeist()) then
        return false
    end
    if not Global.game_settings then
        return false
    end
    local lvl = Global.game_settings.level_id or (managers.job and managers.job:current_level_id())
    return (lvl == "welcome_to_the_jungle_2" or lvl == "big_oil_2")
end

-- ─── Exact 12 Big Oil Engines Database (100% accurate matrix) ───────────────────
local ENGINES = {
    [103703] = {
        number = 1,
        pos = Vector3(-1830, -2182, -313.492),
        gas = "Nitrogen",
        gas_color = Color(0.2, 0.7, 1.0), -- Blue
        hoses = "1 Hose (1xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #1 [Nitrogen | 1xH | <= 400 bar]"
    },
    [103704] = {
        number = 2,
        pos = Vector3(-1200, -2050, -313.492),
        gas = "Deuterium",
        gas_color = Color(0.2, 1.0, 0.4), -- Green
        hoses = "1 Hose (1xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #2 [Deuterium | 1xH | > 400 bar]"
    },
    [103705] = {
        number = 3,
        pos = Vector3(-1849, -1869, -313.492),
        gas = "Helium",
        gas_color = Color(1.0, 0.85, 0.2), -- Yellow
        hoses = "2 Hoses (2xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #3 [Helium | 2xH | <= 400 bar]"
    },
    [103706] = {
        number = 4,
        pos = Vector3(-1200, -1735, -313.492),
        gas = "Nitrogen",
        gas_color = Color(0.2, 0.7, 1.0), -- Blue
        hoses = "2 Hoses (2xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #4 [Nitrogen | 2xH | > 400 bar]"
    },
    [103707] = {
        number = 5,
        pos = Vector3(-1849, -1429, -313.492),
        gas = "Deuterium",
        gas_color = Color(0.2, 1.0, 0.4), -- Green
        hoses = "2 Hoses (2xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #5 [Deuterium | 2xH | <= 400 bar]"
    },
    [103708] = {
        number = 6,
        pos = Vector3(-1200, -1415, -313.492),
        gas = "Helium",
        gas_color = Color(1.0, 0.85, 0.2), -- Yellow
        hoses = "2 Hoses (2xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #6 [Helium | 2xH | > 400 bar]"
    },
    [103709] = {
        number = 7,
        pos = Vector3(-175, -2025, -313.492),
        gas = "Helium",
        gas_color = Color(1.0, 0.85, 0.2), -- Yellow
        hoses = "3 Hoses (3xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #7 [Helium | 3xH | <= 400 bar]"
    },
    [103711] = {
        number = 8,
        pos = Vector3(24.9999, -1350, -313.492),
        gas = "Nitrogen",
        gas_color = Color(0.2, 0.7, 1.0), -- Blue
        hoses = "3 Hoses (3xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #8 [Nitrogen | 3xH | <= 400 bar]"
    },
    [103714] = {
        number = 9,
        pos = Vector3(-175, -1675, -313.492),
        gas = "Deuterium",
        gas_color = Color(0.2, 1.0, 0.4), -- Green
        hoses = "3 Hoses (3xH)",
        pressure = "<= 5812 PSI (<= 400 bar)",
        desc = "Engine #9 [Deuterium | 3xH | <= 400 bar]"
    },
    [103715] = {
        number = 10,
        pos = Vector3(35, -1733, -314),
        gas = "Helium",
        gas_color = Color(1.0, 0.85, 0.2), -- Yellow
        hoses = "3 Hoses (3xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #10 [Helium | 3xH | > 400 bar]"
    },
    [103716] = {
        number = 11,
        pos = Vector3(-175, -1350, -313.492),
        gas = "Nitrogen",
        gas_color = Color(0.2, 0.7, 1.0), -- Blue
        hoses = "3 Hoses (3xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #11 [Nitrogen | 3xH | > 400 bar]"
    },
    [103717] = {
        number = 12,
        pos = Vector3(25, -2050, -313.492),
        gas = "Deuterium",
        gas_color = Color(0.2, 1.0, 0.4), -- Green
        hoses = "3 Hoses (3xH)",
        pressure = "> 5812 PSI (> 400 bar)",
        desc = "Engine #12 [Deuterium | 3xH | > 400 bar]"
    }
}

-- Map engine number 1..12 to element ID
local ENGINE_BY_NUMBER = {}
for elem_id, data in pairs(ENGINES) do
    ENGINE_BY_NUMBER[data.number] = elem_id
end

-- ─── Highlight & Waypoint Helpers ──────────────────────────────────────────────

local function clear_engine_highlights()
    for _, u in ipairs(B.highlighted_units) do
        if alive(u) and u:contour() then
            pcall(function() u:contour():remove("generic_interactable") end)
            pcall(function() u:contour():remove("highlight_character") end)
        end
    end
    B.highlighted_units = {}

    if managers.hud and B.active_waypoint_id then
        pcall(function() managers.hud:remove_waypoint(B.active_waypoint_id) end)
        B.active_waypoint_id = nil
    end
end

local function clear_clue_highlights()
    for _, u in ipairs(B.clue_units) do
        if alive(u) and u:contour() then
            pcall(function() u:contour():remove("generic_interactable") end)
            pcall(function() u:contour():remove("highlight_character") end)
        end
    end
    B.clue_units = {}
end

local function find_engine_unit_near_position(target_pos)
    if not target_pos then return nil end
    local best_unit = nil
    local best_dist = 250

    for _, u in pairs(World:find_units_quick("all")) do
        if alive(u) then
            local dist = mvector3.distance(u:position(), target_pos)
            if dist < best_dist then
                best_dist = dist
                best_unit = u
            end
        end
    end
    return best_unit
end

local function apply_correct_engine_highlight(engine_data)
    clear_engine_highlights()
    if not engine_data or not engine_data.pos then return end

    local target_pos = engine_data.pos
    local unit = find_engine_unit_near_position(target_pos)
    B.correct_unit = unit

    local color = engine_data.gas_color or Color(0.2, 1.0, 0.4)
    local vec_color = Vector3(color.red, color.green, color.blue)

    if alive(unit) and unit:contour() then
        pcall(function()
            unit:contour():add("generic_interactable", true, vec_color)
            table.insert(B.highlighted_units, unit)
        end)
    end

    if managers.hud and managers.hud.add_waypoint then
        B.active_waypoint_id = "EngineHelperWaypoint_ThisOne_CorrectOne"
        pcall(function()
            managers.hud:add_waypoint(B.active_waypoint_id, {
                position = target_pos + Vector3(0, 0, 35),
                distance = true,
                icon = "equipment_vial",
                no_sync = true,
                present_timer = 0,
                state = "present",
                radius = 50,
                color = color,
                blend_mode = "add"
            })
        end)
    end
end

-- ─── Dynamic HUD Overlay ───────────────────────────────────────────────────────

local function destroy_engine_overlay()
    if B.ws and alive(B.ws) then
        local root = B.ws:panel()
        local existing = root and root:child("big_oil_hud_panel")
        if existing and alive(existing) then
            root:remove(existing)
        end
    end
    B.panel = nil
    B.txt_status = nil
    B.txt_subinfo = nil
    B.border_rects = {}
end

local function build_engine_overlay()
    if not is_in_big_oil_heist() then return end

    if not B.ws or not alive(B.ws) then
        pcall(function()
            B.ws = Overlay:newgui():create_screen_workspace()
        end)
    end
    if not B.ws or not alive(B.ws) then return end

    local root = B.ws:panel()
    local existing = root:child("big_oil_hud_panel")
    if existing and alive(existing) then
        root:remove(existing)
    end

    local res = RenderSettings.resolution
    local w, h = 360, 74
    local x = (res.x - w) / 2
    local y = 25

    B.panel = root:panel({
        name = "big_oil_hud_panel",
        x = x, y = y, w = w, h = h,
        layer = 150,
        visible = true
    })

    B.panel:rect({ color = Color(0.04, 0.05, 0.07), alpha = 0.92, layer = 0 })

    B.border_rects = {
        top    = B.panel:rect({ color = B.current_color, alpha = 0.95, x = 0, y = 0, w = w, h = 2, layer = 1 }),
        bottom = B.panel:rect({ color = B.current_color, alpha = 0.95, x = 0, y = h - 2, w = w, h = 2, layer = 1 }),
        left   = B.panel:rect({ color = B.current_color, alpha = 0.95, x = 0, y = 0, w = 2, h = h, layer = 1 }),
        right  = B.panel:rect({ color = B.current_color, alpha = 0.95, x = w - 2, y = 0, w = 2, h = h, layer = 1 })
    }

    B.panel:text({
        text      = "BIG OIL 2 - FUSION ENGINE CALCULATOR",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 12,
        color     = Color(0.4, 0.8, 1.0),
        x = 12, y = 6, layer = 2
    })

    B.txt_status = B.panel:text({
        text      = B.current_status,
        font      = "fonts/font_large_mf",
        font_size = 18,
        color     = B.current_color,
        x = 12, y = 22, layer = 2
    })

    B.txt_subinfo = B.panel:text({
        text      = B.current_subinfo,
        font      = "fonts/font_medium_shadow_mf",
        font_size = 11,
        color     = Color(0.7, 0.7, 0.7),
        x = 12, y = 49, layer = 2
    })
end

local function update_overlay_ui()
    if not is_in_big_oil_heist() or not B.enabled then
        destroy_engine_overlay()
        return
    end

    if not B.panel or not alive(B.panel) or not B.txt_status or not alive(B.txt_status) then
        build_engine_overlay()
    end

    if alive(B.txt_status) then
        B.txt_status:set_text(B.current_status)
        B.txt_status:set_color(B.current_color)
    end

    if alive(B.txt_subinfo) then
        B.txt_subinfo:set_text(B.current_subinfo)
    end

    if B.border_rects then
        for _, border in pairs(B.border_rects) do
            if alive(border) then
                border:set_color(B.current_color)
            end
        end
    end
end

-- ─── Engine Calculation & Setting Logic ────────────────────────────────────────

function B:SetCorrectEngine(elem_id)
    local data = ENGINES[elem_id]
    if not data then return end

    B.correct_element_id = elem_id
    B.correct_engine_num = data.number
    B.correct_pos = data.pos
    B.engine_data = data
    B.current_status = string.format("✔ CORRECT ENGINE: #%d (%s)", data.number, string.upper(data.gas))
    B.current_subinfo = string.format("Gas: %s  |  Hoses: %s  |  PSI: %s", data.gas, data.hoses, data.pressure)
    B.current_color = data.gas_color or Color(0.2, 1.0, 0.4)

    -- Also populate EngineHelper for external compatibility
    _G.EngineHelper = _G.EngineHelper or {}
    _G.EngineHelper.CorrectOne = data.pos

    if is_in_big_oil_heist() then
        update_overlay_ui()

        if B.auto_highlight then
            apply_correct_engine_highlight(data)
        end

        if B.chat_announce and managers.chat then
            local msg = string.format("[Big Oil Helper] Correct Fusion Engine is #%d (%s | %s | %s)", data.number, data.gas, data.hoses, data.pressure)
            pcall(function()
                managers.chat:_receive_message(1, "[Big Oil]", msg, Color("5FE1FF"))
                if managers.network and managers.network:session() then
                    local user = (managers.network.account and managers.network.account:username()) or "Local"
                    managers.chat:send_message(ChatManager.GAME, user, msg)
                end
            end)
        end

        if managers.hud and managers.hud.show_hint then
            pcall(function()
                managers.hud:show_hint({ text = string.format("[Big Oil] Correct Engine: #%d (%s)", data.number, data.gas) })
            end)
        end
    end
end

-- Calculate engine from 3 clues (Gas, Hoses, Pressure)
local function calculate_engine_from_clues(gas_name, hose_count, pressure_type)
    for elem_id, eng in pairs(ENGINES) do
        local match = true
        if gas_name and eng.gas ~= gas_name then match = false end
        if hose_count and not eng.hoses:find(tostring(hose_count), 1, true) then match = false end
        if pressure_type then
            if pressure_type == "<" and not eng.pressure:find("<=", 1, true) then match = false end
            if pressure_type == ">" and not eng.pressure:find(">", 1, true) then match = false end
        end
        if match then
            return elem_id, eng
        end
    end
    return nil, nil
end

-- ─── Hooks Installation for Element Execution ──────────────────────────────────

local _hook_installed = false
local function install_mission_element_hooks()
    if _hook_installed then return end

    local target_classes = {}
    if _G.CoreMissionScriptElement and _G.CoreMissionScriptElement.MissionScriptElement then
        table.insert(target_classes, _G.CoreMissionScriptElement.MissionScriptElement)
    end
    if _G.MissionScriptElement then
        table.insert(target_classes, _G.MissionScriptElement)
    end

    pcall(function()
        core:import("CoreMissionScriptElement")
        if CoreMissionScriptElement and CoreMissionScriptElement.MissionScriptElement then
            table.insert(target_classes, CoreMissionScriptElement.MissionScriptElement)
        end
    end)

    for _, cls in ipairs(target_classes) do
        if cls and not cls._nt_big_oil_hooked then
            cls._nt_big_oil_hooked = true
            _hook_installed = true

            local orig_on_exec = cls.on_executed
            cls.on_executed = function(self, ...)
                if is_in_big_oil_heist() then
                    local id_num = tonumber(self._id)
                    if id_num and ENGINES[id_num] then
                        B:SetCorrectEngine(id_num)
                    end
                end
                return orig_on_exec(self, ...)
            end

            local orig_client_exec = cls.client_on_executed
            if orig_client_exec then
                cls.client_on_executed = function(self, ...)
                    if is_in_big_oil_heist() then
                        local id_num = tonumber(self._id)
                        if id_num and ENGINES[id_num] then
                            B:SetCorrectEngine(id_num)
                        end
                    end
                    return orig_client_exec(self, ...)
                end
            end
        end
    end
end

install_mission_element_hooks()

-- ─── Dialog & Event Hooks ──────────────────────────────────────────────────────

if DialogManager then
    Hooks:PostHook(DialogManager, "queue_dialog", "NiceTrainer_BigOil_Dialog", function(self, id, params)
        if not is_in_big_oil_heist() then return end
        local sound_id = tostring(id or "")
        -- Helicopter arrived / Lab open
        if sound_id == "pln_bo2_33" then
            if B.engine_data then
                apply_correct_engine_highlight(B.engine_data)
            end
        -- Engine secured
        elseif sound_id == "pln_bo2_35" then
            clear_engine_highlights()
            B.current_status = "✔ ENGINE SECURED!"
            B.current_color = Color(0.2, 1.0, 0.4)
            update_overlay_ui()
        end
    end)
end

-- Carry Hook (clears waypoint when player bags the engine)
if PlayerManager then
    Hooks:PostHook(PlayerManager, "set_carry", "NiceTrainer_BigOil_OnCarry", function(self, carry_id, ...)
        if not is_in_big_oil_heist() then return end
        local cid = tostring(carry_id or "")
        if cid:find("engine", 1, true) then
            clear_engine_highlights()
            B.current_status = "✔ ENGINE IN BACKPACK!"
            B.current_color = Color(0.2, 1.0, 0.4)
            update_overlay_ui()
        end
    end)
end

-- Frame update loop
Hooks:Add("GameSetupUpdate", "NiceTrainer_BigOil_Update", function(t, dt)
    if not is_in_big_oil_heist() then
        if B.panel and alive(B.panel) then
            destroy_engine_overlay()
            clear_engine_highlights()
            clear_clue_highlights()
        end
        return
    end

    if not _hook_installed then
        install_mission_element_hooks()
    end

    if B.enabled then
        if not B.panel or not alive(B.panel) then
            build_engine_overlay()
            update_overlay_ui()
        end
    end

    -- Check if EngineHelper was set externally
    if not B.engine_data and _G.EngineHelper and _G.EngineHelper.CorrectOne then
        for elem_id, data in pairs(ENGINES) do
            if mvector3.distance(data.pos, _G.EngineHelper.CorrectOne) < 50 then
                B:SetCorrectEngine(elem_id)
                break
            end
        end
    end

    -- If player is carrying the engine, ensure waypoint is cleared
    if B.active_waypoint_id and managers.player and managers.player:is_carrying() then
        local my_carry = managers.player:get_my_carry_data()
        if my_carry and tostring(my_carry.carry_id or ""):find("engine", 1, true) then
            clear_engine_highlights()
            B.current_status = "✔ ENGINE IN BACKPACK!"
            B.current_color = Color(0.2, 1.0, 0.4)
            update_overlay_ui()
        end
    end
end)

-- Clean up on menu / escape / restart
Hooks:Add("MenuUpdate", "NiceTrainer_BigOil_MenuCleanup", function(t, dt)
    if B.panel and alive(B.panel) then
        destroy_engine_overlay()
        clear_engine_highlights()
        clear_clue_highlights()
    end
end)

if _G.MissionEndState then
    Hooks:PostHook(MissionEndState, "at_enter", "NiceTrainer_BigOil_MissionEnd", function(...)
        destroy_engine_overlay()
        clear_engine_highlights()
        clear_clue_highlights()
    end)
end

if _G.VictoryState then
    Hooks:PostHook(VictoryState, "at_enter", "NiceTrainer_BigOil_Victory", function(...)
        destroy_engine_overlay()
        clear_engine_highlights()
        clear_clue_highlights()
    end)
end

if _G.GameOverState then
    Hooks:PostHook(GameOverState, "at_enter", "NiceTrainer_BigOil_GameOver", function(...)
        destroy_engine_overlay()
        clear_engine_highlights()
        clear_clue_highlights()
    end)
end

-- Session reset
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_BigOil_ResetSession", function()
    B.correct_element_id = nil
    B.correct_engine_num = nil
    B.correct_pos = nil
    B.correct_unit = nil
    B.engine_data = nil
    B.current_status = "AWAITING ENGINE SELECTION..."
    B.current_subinfo = "Waiting for lab mission trigger / Intel scan"
    B.current_color = Color(0.6, 0.6, 0.6)
    clear_engine_highlights()
    clear_clue_highlights()
    destroy_engine_overlay()

    if is_in_big_oil_heist() then
        install_mission_element_hooks()
        if B.enabled then
            build_engine_overlay()
            update_overlay_ui()
        end
    end
end)

-- ─── Helper Actions Implementation ─────────────────────────────────────────────

local function auto_bag_correct_engine()
    if not is_in_big_oil_heist() then
        NiceTrainer:Toast("Only available inside Big Oil Day 2 heist!")
        return
    end

    local unit = B.correct_unit
    if not alive(unit) and B.correct_pos then
        unit = find_engine_unit_near_position(B.correct_pos)
        B.correct_unit = unit
    end

    local player = managers.player and managers.player:player_unit()
    if not alive(player) then
        NiceTrainer:Toast("Player unit not found.")
        return
    end

    if alive(unit) and unit:interaction() then
        local success = false
        pcall(function()
            unit:interaction():interact(player)
            success = true
        end)
        if success then
            NiceTrainer:Toast(string.format("Correct Engine #%d bagged!", B.correct_engine_num or 1), Color(0.2, 1.0, 0.4))
            return
        end
    end

    if managers.player and managers.player.set_carry then
        pcall(function()
            managers.player:set_carry("engine_01", 1, true, false, 1)
        end)
        NiceTrainer:Toast(string.format("Correct Engine #%d added to your backpack!", B.correct_engine_num or 1), Color(0.2, 1.0, 0.4))
    else
        NiceTrainer:Toast("Make sure the lab door is open and carry slot is empty.")
    end
end

local function highlight_intel_clues()
    if not is_in_big_oil_heist() then
        NiceTrainer:Toast("Only available inside Big Oil Day 2 heist!")
        return
    end

    clear_clue_highlights()
    local count = 0

    for _, u in pairs(World:find_units_quick("all")) do
        if alive(u) then
            local name = ""
            pcall(function() name = u:name().s and u:name():s() or tostring(u:name()) end)
            name = string.lower(name)

            if name:find("notebook", 1, true) or name:find("clipboard", 1, true) or name:find("intel", 1, true) or name:find("lab_pc", 1, true) or name:find("computer", 1, true) or name:find("science_notepad", 1, true) then
                if u:contour() then
                    pcall(function()
                        u:contour():add("generic_interactable", true, Vector3(1.0, 0.85, 0.2)) -- Yellow outline
                        table.insert(B.clue_units, u)
                        count = count + 1
                    end)
                end
            end
        end
    end

    NiceTrainer:Toast(string.format("Highlighted %d clues (PC, Notebook, Clipboard) in YELLOW.", count), Color(1.0, 0.85, 0.2))
end

local function print_clues_cheat_sheet()
    if not (managers and managers.chat) then return end
    managers.chat:feed_system_message(ChatManager.GAME, "#-=-=-=-=-=-=-=-= BIG OIL ENGINE CLUES =-=-=-=-=-=-=-=-#")
    managers.chat:feed_system_message(ChatManager.GAME, "  [ DEUTERIUM (Green Notebook) ]")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 1 Hose + > 400 bar  --> Engine #2")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 2 Hoses + <= 400 bar --> Engine #5")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + <= 400 bar --> Engine #9")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + > 400 bar  --> Engine #12")
    managers.chat:feed_system_message(ChatManager.GAME, "  [ HELIUM (Yellow Notebook) ]")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 2 Hoses + <= 400 bar --> Engine #3")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 2 Hoses + > 400 bar  --> Engine #6")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + <= 400 bar --> Engine #7")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + > 400 bar  --> Engine #10")
    managers.chat:feed_system_message(ChatManager.GAME, "  [ NITROGEN (Blue Notebook) ]")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 1 Hose + <= 400 bar --> Engine #1")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 2 Hoses + > 400 bar  --> Engine #4")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + <= 400 bar --> Engine #8")
    managers.chat:feed_system_message(ChatManager.GAME, "    • 3 Hoses + > 400 bar  --> Engine #11")
    managers.chat:feed_system_message(ChatManager.GAME, "#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-#")
    NiceTrainer:Toast("Printed Big Oil Cheat Sheet to Chat!", Color("5FE1FF"))
end

-- ─── NiceTrainer Actions Registration ──────────────────────────────────────────

if not _G.NT_BigOil_Actions_Registered and NiceTrainer and NiceTrainer.RegisterAction then
    _G.NT_BigOil_Actions_Registered = true

    -- Toggle 1: Big Oil Engine HUD Overlay
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_hud_overlay",
        badge = "client",
        save = true,
        default = false,
        text = "Engine Calculator HUD Overlay",
        tooltip = "Displays a sleek dynamic HUD widget with the exact correct engine number, gas element, hose count, and PSI threshold.",
        callback = function(state)
            B.enabled = state
            if state then
                build_engine_overlay()
                update_overlay_ui()
            else
                destroy_engine_overlay()
            end
        end
    })

    -- Toggle 2: Auto-Highlight & Waypoint Correct Engine
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_auto_engine_highlight",
        badge = "client",
        save = true,
        default = true,
        text = "Auto-Highlight & Waypoint Correct Engine",
        tooltip = "Automatically applies a 3D contour outline and waypoint on the single correct fusion engine in the basement lab.",
        callback = function(state)
            B.auto_highlight = state
            if state then
                if B.engine_data then
                    apply_correct_engine_highlight(B.engine_data)
                end
            else
                clear_engine_highlights()
            end
        end
    })

    -- Toggle 3: Announce Correct Engine in Team Chat
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_chat_announce",
        badge = "client",
        save = true,
        default = false,
        text = "Announce Correct Engine to Team Chat",
        tooltip = "Automatically broadcasts the correct engine number and intel clues to the team chat.",
        callback = function(state)
            B.chat_announce = state
        end
    })

    -- Action 4: Select / Highlight Engine Manually (#1 to #12)
    NiceTrainer:RegisterAction("Heist", {
        type = "multichoice",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_manual_engine_choice",
        badge = "client",
        text = "Highlight Engine Directly (#1 - #12)",
        tooltip = "Select any of the 12 fusion engines to set as target, highlight it in 3D, and place a waypoint.",
        options = {
            "#1: Nitrogen | 1xH | <= 400 bar",
            "#2: Deuterium | 1xH | > 400 bar",
            "#3: Helium | 2xH | <= 400 bar",
            "#4: Nitrogen | 2xH | > 400 bar",
            "#5: Deuterium | 2xH | <= 400 bar",
            "#6: Helium | 2xH | > 400 bar",
            "#7: Helium | 3xH | <= 400 bar",
            "#8: Nitrogen | 3xH | <= 400 bar",
            "#9: Deuterium | 3xH | <= 400 bar",
            "#10: Helium | 3xH | > 400 bar",
            "#11: Nitrogen | 3xH | > 400 bar",
            "#12: Deuterium | 3xH | > 400 bar"
        },
        default = 1,
        action_btn_text = "Target Engine",
        callback = function(idx, val)
            local elem_id = ENGINE_BY_NUMBER[idx]
            if elem_id then
                B:SetCorrectEngine(elem_id)
                NiceTrainer:Toast(string.format("Targeted %s!", val), ENGINES[elem_id].gas_color)
            end
        end
    })

    -- Action 5: Calculate from Clues (Gas, Hoses, Pressure)
    NiceTrainer:RegisterAction("Heist", {
        type = "multichoice",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_clue_gas",
        badge = "client",
        text = "Intel Clue 1: Gas (Notebook)",
        tooltip = "Gas found in notebook (Blue = Nitrogen, Green = Deuterium, Yellow = Helium).",
        options = { "Deuterium (Green)", "Helium (Yellow)", "Nitrogen (Blue)" },
        default = 1,
        callback = function(idx, val)
            B.manual_gas = idx
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "multichoice",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_clue_hoses",
        badge = "client",
        text = "Intel Clue 2: Hoses (Clipboard)",
        tooltip = "Hoses found in clipboard (1xH, 2xH, or 3xH).",
        options = { "1 Hose (1xH)", "2 Hoses (2xH)", "3 Hoses (3xH)" },
        default = 1,
        callback = function(idx, val)
            B.manual_hoses = idx
        end
    })

    NiceTrainer:RegisterAction("Heist", {
        type = "multichoice",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        id = "big_oil_clue_pressure",
        badge = "client",
        text = "Intel Clue 3: PSI (Lab PC)",
        tooltip = "Pressure on computer (<= 5812 psi or > 5812 psi).",
        options = { "<= 5812 PSI (<= 400 bar)", "> 5812 PSI (> 400 bar)" },
        default = 1,
        action_btn_text = "Solve Clues",
        callback = function(idx, val)
            B.manual_pressure = idx
            local gas_names = { [1] = "Deuterium", [2] = "Helium", [3] = "Nitrogen" }
            local hose_counts = { [1] = 1, [2] = 2, [3] = 3 }
            local pressure_types = { [1] = "<", [2] = ">" }

            local g = gas_names[B.manual_gas or 1]
            local h = hose_counts[B.manual_hoses or 1]
            local p = pressure_types[B.manual_pressure or 1]

            local elem_id, data = calculate_engine_from_clues(g, h, p)
            if elem_id and data then
                B:SetCorrectEngine(elem_id)
                NiceTrainer:Toast(string.format("Clues solved! Engine #%d is the correct one.", data.number), data.gas_color)
            else
                NiceTrainer:Toast("No engine matches this clue combination! Check clues again.")
            end
        end
    })

    -- Action 6: Auto-Bag Correct Engine
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        badge = "client",
        text = "Auto-Bag Correct Engine",
        tooltip = "Instantly interacts with and bags the correct fusion engine into your backpack.",
        action_btn_text = "Bag Engine",
        callback = function()
            auto_bag_correct_engine()
        end
    })

    -- Action 7: Locate & Highlight Intel Clues (PC / Notebook / Clipboard)
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        badge = "client",
        text = "Locate All Intel Clues in Mansion",
        tooltip = "Highlights the 3 intel clues (Notebook, Clipboard, Computer) scattered across the mansion in bright yellow.",
        action_btn_text = "Locate Clues",
        callback = function()
            highlight_intel_clues()
        end
    })

    -- Action 8: Print Clues Cheat Sheet in Chat
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Big Oil Day 2 (welcome_to_the_jungle_2)",
        level_id = { "welcome_to_the_jungle_2", "big_oil_2", "welcome_to_the_jungle_wrapper" },
        badge = "client",
        text = "Print Big Oil Cheat Sheet to Chat",
        tooltip = "Prints the complete Big Oil engine table reference in chat.",
        action_btn_text = "Print Table",
        callback = function()
            print_clues_cheat_sheet()
        end
    })

end
