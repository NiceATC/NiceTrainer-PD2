-- Cook Off & Rats (alex_1, rat, flat, mex, crojob2, san_martin) - Dynamic Meth Cooking Assistant & HUD Overlay

NiceTrainer.MethHelper = NiceTrainer.MethHelper or {
    enabled = false,
    auto_cook_enabled = false,
    highlight_enabled = false,
    chat_announce = false,
    explosion_disabled = false,
    ws = nil,
    panel = nil,
    txt_ingredient = nil,
    txt_subinfo = nil,
    border_rects = {},
    current_ingredient = nil,
    pending_auto_cook = nil,
    current_status = "WAITING FOR INGREDIENT...",
    current_color = Color(0.6, 0.6, 0.6),
    cook_step = 0,
    bags_cooked = 0,
    highlighted_station = nil,
    active_waypoint_id = nil,
    last_ingredient_code = nil
}

local M = NiceTrainer.MethHelper

local INGREDIENTS = {
    mu = {
        name = "Muriatic Acid (Mu)",
        short = "Mu",
        color = Color(0.2, 0.8, 1.0),
        tweaks = { "methlab_bubbling", "hold_add_muriatic_acid", "methlab_add_acid" }
    },
    cs = {
        name = "Caustic Soda (Cs)",
        short = "Cs",
        color = Color(1.0, 0.85, 0.2),
        tweaks = { "methlab_caustic_cooler", "hold_add_caustic_soda", "methlab_add_soda" }
    },
    hcl = {
        name = "Hydrogen Chloride (HCl)",
        short = "HCl",
        color = Color(0.2, 1.0, 0.4),
        tweaks = { "methlab_gas_to_salt", "hold_add_hydrogen_chloride", "methlab_add_hydrogen" }
    }
}

-- Exact Meth Helper Updated dialogue IDs catalogue
local DIALOG_IDS = {
    -- Bain's lines (Cook Off, Rats Day 1)
    ["pln_rt1_12"] = "added",
    ["pln_rt1_20"] = "mu",
    ["pln_rt1_22"] = "cs",
    ["pln_rt1_23"] = "fail",
    ["pln_rt1_24"] = "hcl",
    ["pln_rt1_28"] = "added",
    ["Play_pln_nai_16"] = "fail",
    ["pln_rat_stage1_20"] = "mu",
    ["pln_rat_stage1_22"] = "cs",
    ["pln_rat_stage1_24"] = "hcl",
    ["pln_rat_stage1_28"] = "done",

    -- Locke's lines (Border Crossing, San Martin, etc)
    ["Play_loc_mex_cook_03"] = "mu",
    ["Play_loc_mex_cook_04"] = "cs",
    ["Play_loc_mex_cook_05"] = "hcl",
    ["Play_loc_mex_cook_14"] = "done",
    ["Play_loc_mex_cook_17"] = "done",
    ["Play_loc_mex_cook_22"] = "added",
    ["Play_loc_mex_cook_12"] = "fail"
}

local function clear_station_highlight()
    if M.highlighted_station and alive(M.highlighted_station) then
        if M.highlighted_station:contour() then
            pcall(function() M.highlighted_station:contour():remove("generic_interactable") end)
            pcall(function() M.highlighted_station:contour():remove("highlight_character") end)
        end
    end
    M.highlighted_station = nil

    if managers.hud and M.active_waypoint_id then
        pcall(function() managers.hud:remove_waypoint(M.active_waypoint_id) end)
        M.active_waypoint_id = nil
    end
end

local function highlight_chemical_station(ing_key)
    clear_station_highlight()
    if not M.highlight_enabled or not ing_key or not INGREDIENTS[ing_key] then return end

    local ing_data = INGREDIENTS[ing_key]
    for _, unit in pairs(World:find_units_quick("all")) do
        if alive(unit) and unit:interaction() then
            local tw = tostring(unit:interaction().tweak_data or unit:interaction()._tweak_data or ""):lower()
            local match = false
            for _, tweak in ipairs(ing_data.tweaks) do
                if tw == tweak or tw:find(tweak, 1, true) then
                    match = true
                    break
                end
            end

            if match then
                M.highlighted_station = unit
                if unit:contour() then
                    pcall(function()
                        unit:contour():add("generic_interactable", true, Vector3(ing_data.color.red, ing_data.color.green, ing_data.color.blue))
                    end)
                end

                if managers.hud and managers.hud.add_waypoint then
                    M.active_waypoint_id = "meth_station_wp"
                    pcall(function()
                        managers.hud:add_waypoint(M.active_waypoint_id, {
                            unit = unit,
                            position = unit:position() + Vector3(0, 0, 30),
                            distance = true,
                            icon = "wp_standard",
                            present_timer = 0,
                            state = "sneak_present",
                            color = ing_data.color
                        })
                    end)
                end
                break
            end
        end
    end
end

local function perform_chemical_deposit(ing_key)
    if not ing_key or not INGREDIENTS[ing_key] then return false end
    local ing_data = INGREDIENTS[ing_key]
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return false end

    for _, unit in pairs(World:find_units_quick("all")) do
        if alive(unit) and unit:interaction() then
            local tw = tostring(unit:interaction().tweak_data or unit:interaction()._tweak_data or ""):lower()
            local match = false
            for _, tweak in ipairs(ing_data.tweaks) do
                if tw == tweak or tw:find(tweak, 1, true) then
                    match = true
                    break
                end
            end

            if match then
                local success = false
                pcall(function()
                    unit:interaction():interact(player)
                    success = true
                end)
                return success
            end
        end
    end
    return false
end

-- =========================================================================
-- Dynamic HUD Overlay
-- =========================================================================

local function destroy_cook_overlay()
    if M.ws and alive(M.ws) then
        local root = M.ws:panel()
        local existing = root and root:child("cook_off_hud_panel")
        if existing and alive(existing) then
            root:remove(existing)
        end
    end
    M.panel = nil
    M.txt_ingredient = nil
    M.txt_subinfo = nil
    M.border_rects = {}
    clear_station_highlight()
end

local function build_cook_overlay()
    if not M.ws or not alive(M.ws) then
        pcall(function()
            M.ws = Overlay:newgui():create_screen_workspace()
        end)
    end
    if not M.ws or not alive(M.ws) then return end

    local root = M.ws:panel()
    local existing = root:child("cook_off_hud_panel")
    if existing and alive(existing) then
        root:remove(existing)
    end

    local res = RenderSettings.resolution
    local w, h = 340, 72
    local x = (res.x - w) / 2
    local y = 25

    M.panel = root:panel({
        name = "cook_off_hud_panel",
        x = x, y = y, w = w, h = h,
        layer = 150,
        visible = true
    })

    M.panel:rect({ color = Color(0.04, 0.05, 0.07), alpha = 0.90, layer = 0 })

    M.border_rects = {
        top    = M.panel:rect({ color = M.current_color, alpha = 0.95, x = 0, y = 0, w = w, h = 2, layer = 1 }),
        bottom = M.panel:rect({ color = M.current_color, alpha = 0.95, x = 0, y = h - 2, w = w, h = 2, layer = 1 }),
        left   = M.panel:rect({ color = M.current_color, alpha = 0.95, x = 0, y = 0, w = 2, h = h, layer = 1 }),
        right  = M.panel:rect({ color = M.current_color, alpha = 0.95, x = w - 2, y = 0, w = 2, h = h, layer = 1 })
    }

    M.panel:text({
        text      = "METH LAB HELPER",
        font      = "fonts/font_medium_shadow_mf",
        font_size = 12,
        color     = Color(0.4, 0.8, 1.0),
        x = 12, y = 6, layer = 2
    })

    M.txt_ingredient = M.panel:text({
        text      = M.current_status,
        font      = "fonts/font_large_mf",
        font_size = 18,
        color     = M.current_color,
        x = 12, y = 22, layer = 2
    })

    local auto_tag = M.auto_cook_enabled and " | Auto-Cook: ON" or ""
    M.txt_subinfo = M.panel:text({
        text      = string.format("Step: %d/3   |   Bags Cooked: %d%s", (M.cook_step % 3) + 1, M.bags_cooked, auto_tag),
        font      = "fonts/font_medium_shadow_mf",
        font_size = 11,
        color     = Color(0.7, 0.7, 0.7),
        x = 12, y = 48, layer = 2
    })
end

local function update_overlay_ui()
    if not M.enabled then return end
    if not M.panel or not alive(M.panel) or not M.txt_ingredient or not alive(M.txt_ingredient) then
        build_cook_overlay()
    end

    if alive(M.txt_ingredient) then
        M.txt_ingredient:set_text(M.current_status)
        M.txt_ingredient:set_color(M.current_color)
    end

    if alive(M.txt_subinfo) then
        local auto_tag = M.auto_cook_enabled and " | Auto-Cook: ON" or ""
        M.txt_subinfo:set_text(string.format("Step: %d/3   |   Bags Cooked: %d%s", (M.cook_step % 3) + 1, M.bags_cooked, auto_tag))
    end

    if M.border_rects then
        for _, border in pairs(M.border_rects) do
            if alive(border) then
                border:set_color(M.current_color)
            end
        end
    end
end

local function process_ingredient_event(code)
    if code == "mu" or code == "cs" or code == "hcl" then
        local ing = INGREDIENTS[code]
        if not ing then return end
        M.current_ingredient = code
        M.current_status = "ADD: " .. ing.name
        M.current_color = ing.color
        M.last_ingredient_code = code

        update_overlay_ui()
        highlight_chemical_station(code)

        -- Announce in Chat
        if M.chat_announce and managers.chat then
            local prefix = "[Meth Helper]"
            pcall(function()
                managers.chat:_receive_message(1, prefix, "Add: " .. ing.name, Color("5FE1FF"))
                if managers.network and managers.network:session() then
                    local user = (managers.network.account and managers.network.account:username()) or "Local"
                    managers.chat:send_message(ChatManager.GAME, user, prefix .. " Add: " .. ing.name)
                end
            end)
        end

        if managers.hud and managers.hud.show_hint then
            managers.hud:show_hint({ text = "[Meth Helper] Add: " .. ing.name })
        end

        -- Trigger Auto-Cook if enabled
        if M.auto_cook_enabled then
            M.pending_auto_cook = code
            local deposited = perform_chemical_deposit(code)
            if deposited then
                M.pending_auto_cook = nil
                NiceTrainer:Toast("Auto-Cook: Deposited " .. ing.short .. "!", ing.color)
            end
        end

    elseif code == "added" then
        M.current_ingredient = nil
        M.pending_auto_cook = nil
        M.current_status = "COOKING IN PROGRESS..."
        M.current_color = Color(1.0, 0.5, 0.2)
        M.cook_step = M.cook_step + 1
        clear_station_highlight()
        update_overlay_ui()

    elseif code == "done" then
        M.bags_cooked = M.bags_cooked + 1
        M.cook_step = 0
        M.current_ingredient = nil
        M.pending_auto_cook = nil
        M.current_status = string.format("✔ BAG #%d READY! PICK UP METH", M.bags_cooked)
        M.current_color = Color(0.2, 1.0, 0.4)
        clear_station_highlight()
        update_overlay_ui()

    elseif code == "fail" then
        M.current_ingredient = nil
        M.pending_auto_cook = nil
        M.current_status = "WRONG INGREDIENT ADDED!"
        M.current_color = Color(1.0, 0.2, 0.2)
        clear_station_highlight()
        update_overlay_ui()
        NiceTrainer:Toast("WARNING: Wrong ingredient added!", Color(1.0, 0.2, 0.2))
    end
end

-- =========================================================================
-- DialogManager Hook (Exact Meth Helper Updated Mechanism)
-- =========================================================================

if DialogManager then
    Hooks:PostHook(DialogManager, "queue_dialog", "NiceTrainer_MethHelper_QueueDialog", function(self, id, params)
        local sound_key = tostring(id or "")
        local code = DIALOG_IDS[sound_key]
        if code then
            process_ingredient_event(code)
        end
    end)
end

-- Frame update loop (maintains HUD visibility and processes pending Auto-Cook)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Meth_Update", function(t, dt)
    if M.enabled then
        if not M.panel or not alive(M.panel) then
            build_cook_overlay()
        end
    end

    -- Process pending auto-cook deposit until table is available
    if M.auto_cook_enabled and M.pending_auto_cook then
        local deposited = perform_chemical_deposit(M.pending_auto_cook)
        if deposited then
            local ing = INGREDIENTS[M.pending_auto_cook]
            if ing then
                NiceTrainer:Toast("Auto-Cook: Deposited " .. ing.short .. "!", ing.color)
            end
            M.pending_auto_cook = nil
        end
    end
end)

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Meth_ResetSession", function()
    M.cook_step = 0
    M.bags_cooked = 0
    M.current_ingredient = nil
    M.pending_auto_cook = nil
    M.current_status = "WAITING FOR INGREDIENT..."
    M.current_color = Color(0.6, 0.6, 0.6)
    M.last_ingredient_code = nil
    clear_station_highlight()
    if M.enabled then
        build_cook_overlay()
        update_overlay_ui()
    end
end)

-- =========================================================================
-- Helper Actions
-- =========================================================================

local function auto_interact_current_station()
    if not M.current_ingredient or not INGREDIENTS[M.current_ingredient] then
        NiceTrainer:Toast("No active ingredient requested yet.")
        return
    end

    local ing_data = INGREDIENTS[M.current_ingredient]
    local success = perform_chemical_deposit(M.current_ingredient)
    if success then
    else
        NiceTrainer:Toast("Could not find table for " .. ing_data.short)
    end
end

local function disable_lab_explosions()
    local count = 0
    if managers.mission and managers.mission._scripts then
        for _, script in pairs(managers.mission._scripts) do
            for _, elem in pairs(script:elements()) do
                local name = string.lower(elem:editor_name() or "")
                if name:find("lab_explode", 1, true) 
                   or name:find("fail_explosion", 1, true) 
                   or name:find("meth_fire", 1, true) 
                   or name:find("explode_lab", 1, true) then
                    elem:set_enabled(false)
                    count = count + 1
                end
            end
        end
    end
    M.explosion_disabled = true
    update_overlay_ui()
    NiceTrainer:Toast(string.format("Lab explosion protection enabled (%d elements disabled)!", count))
end

-- =========================================================================
-- NiceTrainer Actions Registration (Register only once)
-- =========================================================================
if not _G.NT_CookOff_Actions_Registered and NiceTrainer and NiceTrainer.RegisterAction then
    _G.NT_CookOff_Actions_Registered = true

    -- Toggle 1: Meth Cooking HUD Overlay
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        id = "cook_off_hud_overlay",
        badge = "client",
        save = true,
        default = false,
        text = "Meth Cooking HUD Overlay",
        tooltip = "Displays a sleek dynamic HUD widget on top of your screen with the next chemical, bag counter, and cooking status.",
        callback = function(state)
            M.enabled = state
            if state then
                build_cook_overlay()
                update_overlay_ui()
            else
                destroy_cook_overlay()
            end
        end
    })

    -- Toggle 2: Auto-Cook (Hands-Free Meth Lab)
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        id = "cook_off_auto_cook",
        badge = "client",
        save = true,
        default = false,
        text = "Auto-Cook (Hands-Free Meth Lab)",
        tooltip = "Automatically interacts with and deposits the correct chemical into the chemistry set the instant it is confirmed by Bain/Locke.",
        callback = function(state)
            M.auto_cook_enabled = state
            update_overlay_ui()
            if state then
                if M.current_ingredient then
                    perform_chemical_deposit(M.current_ingredient)
                end
            else
                M.pending_auto_cook = nil
            end
        end
    })

    -- Toggle 3: Auto-Highlight Chemical Station
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        id = "cook_off_auto_station_highlight",
        badge = "client",
        save = true,
        default = false,
        text = "Auto-Highlight Active Chemical Station",
        tooltip = "Automatically places a 3D contour and waypoint on the exact chemical table (Acid / Soda / HCl) needed for the active step.",
        callback = function(state)
            M.highlight_enabled = state
            if state and M.current_ingredient then
                highlight_chemical_station(M.current_ingredient)
            else
                clear_station_highlight()
            end
        end
    })

    -- Toggle 4: Announce Chemical in Team Chat
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        id = "cook_off_chat_announce",
        badge = "client",
        save = true,
        default = false,
        text = "Announce Next Ingredient to Chat",
        tooltip = "Automatically posts the correct chemical in team chat as soon as Bain/Locke cues the cycle.",
        callback = function(state)
            M.chat_announce = state
        end
    })

    -- Action 5: Instant Add / Interact with Active Station
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        badge = "client",
        text = "Auto-Add Current Ingredient",
        tooltip = "Instantly interacts with the active chemical table and deposits the requested ingredient.",
        action_btn_text = "Add Chemical",
        callback = function()
            auto_interact_current_station()
        end
    })

    -- Action 6: Disable Lab Explosion Traps
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Meth Lab Helper (Cook Off / Rats)",
        level_id = { "alex_1", "rat", "flat", "mex", "crojob2", "san_martin" },
        badge = "host",
        text = "Disable Lab Explosion Elements",
        tooltip = "Neutralizes all mission explosion elements so adding the wrong chemical will never blow up the lab.",
        action_btn_text = "Protect Lab",
        callback = function()
            disable_lab_explosions()
        end
    })

end
