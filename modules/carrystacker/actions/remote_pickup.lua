-- Remote Loot Collector for NiceTrainer (CarryStacker tab)
-- Allows viewing and picking up loose bags and raw loot directly onto your back remotely.

local function safe_alive(unit)
    return unit and alive(unit)
end

-- Carry tweak names to readable labels
local function get_loot_display_name(unit)
    if not safe_alive(unit) then return "Loot Item" end
    
    local name = nil

    if unit.carry_data and unit:carry_data() then
        local cid = unit:carry_data():carry_id()
        if cid then
            local td = tweak_data.carry and tweak_data.carry[cid]
            if td and td.name_id and managers.localization and managers.localization:exists(td.name_id) then
                name = managers.localization:text(td.name_id, { VALUE = "", BTN_INTERACT = "", MONEY = "" })
            else
                name = cid
            end
        end
    end

    if (not name or name == "") and unit.interaction and unit:interaction() then
        local tid = unit:interaction().tweak_data
        if tid then
            local td = tweak_data.interaction and tweak_data.interaction[tid]
            if td and td.text_id and managers.localization and managers.localization:exists(td.text_id) then
                name = managers.localization:text(td.text_id, { VALUE = "", BTN_INTERACT = "", MONEY = "" })
            else
                name = tid
            end
        end
    end

    name = tostring(name or "Loot Bag")
    name = name:gsub("%$[%w_]+", ""):gsub("%$[%d]+", "")
    name = name:gsub("^[Hh]old%s+to%s+", ""):gsub("^[Pp]ress%s+to%s+", ""):gsub("^[Tt]ake%s+", ""):gsub("^[Pp]ick%s+up%s+", "")
    name = name:gsub("hud_int_", ""):gsub("debug_interact_", ""):gsub("gen_pku_", ""):gsub("gen_prop_", "")
    name = name:gsub("_", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)

    if name == "" or name == " " then name = "Loot Bag" end

    local s = string.lower(name)
    if s:find("money") or s:find("cash") then name = "Cash Bundle"
    elseif s:find("gold") then name = "Gold Bars"
    elseif s:find("diamond") or s:find("jewel") then name = "Diamonds / Jewelry"
    elseif s:find("coke") then name = "Cocaine Bag"
    elseif s:find("meth") then name = "Meth Bag"
    elseif s:find("weapon") then name = "Weapon Bag"
    elseif s:find("painting") then name = "Painting"
    elseif s:find("artifact") then name = "Artifact"
    elseif s:find("safe loot") then name = "Safe Contents"
    end

    return name
end

local function is_loot_interaction(id)
    if not id then return false end
    local s = string.lower(tostring(id))
    local loot_patterns = { "money", "cash", "coke", "meth", "gold", "diamond", "jewel", "painting", "weapon", "artifact", "warhead", "pku", "loot", "bag", "safe_loot", "take_wine", "vr_headset", "shoes" }
    for _, pat in ipairs(loot_patterns) do
        if s:find(pat, 1, true) then return true end
    end
    return false
end

-- Scan map for all loose bags and interactable loot
local function get_map_loot()
    local list = {}
    local seen = {}
    local player = managers.player and managers.player:player_unit()
    local p_pos = safe_alive(player) and player:position() or Vector3()

    -- 1. Loose Carry Bags
    for _, unit in pairs(World:find_units_quick("all", 14)) do
        if safe_alive(unit) and unit:enabled() and unit.interaction and not seen[unit:key()] then
            local cd = unit.carry_data and unit:carry_data()
            if cd and cd:carry_id() and cd:carry_id() ~= "person" then
                seen[unit:key()] = true
                local dist = math.floor(mvector3.distance(p_pos, unit:position()) / 100)
                table.insert(list, {
                    unit = unit,
                    name = get_loot_display_name(unit),
                    dist = dist,
                    is_bag = true
                })
            end
        end
    end

    -- 2. Raw Unbagged Loot Interactables
    for _, unit in pairs(World:find_units_quick("all")) do
        if safe_alive(unit) and unit:enabled() and unit.interaction and not seen[unit:key()] then
            local inter = unit:interaction()
            if inter and inter:active() and inter.tweak_data and is_loot_interaction(inter.tweak_data) then
                seen[unit:key()] = true
                local dist = math.floor(mvector3.distance(p_pos, unit:position()) / 100)
                table.insert(list, {
                    unit = unit,
                    name = get_loot_display_name(unit),
                    dist = dist,
                    is_bag = false
                })
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- Pick up a loot unit onto the player's back
local function pickup_loot_to_back(unit)
    if not (safe_alive(unit) and unit:enabled() and unit.interaction) then return false end
    local inter = unit:interaction()
    if not inter then return false end

    local player = managers.player and managers.player:player_unit()
    if not player then return false end

    -- Ensure infinite carry stacker is enabled so it doesn't drop/block
    if not NiceTrainer.Settings.bag_stacker_enabled then
        NiceTrainer.Settings.bag_stacker_enabled = true
        NiceTrainer:Save()
    end

    local ok = pcall(function()
        inter:interact(player)
    end)

    if ok then
        -- Restore mobility if client
        pcall(function()
            if Network:is_client() and player:movement() and player:movement().set_carry_restriction then
                player:movement():set_carry_restriction(false)
            end
        end)
    end

    return ok
end

-- Pick up all loot on map
local function grab_all_loot_to_back()
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Only available during heist.")
        return
    end

    local loot_list = get_map_loot()
    if #loot_list == 0 then
        NiceTrainer:Toast("No loose loot or bags found on map.")
        return
    end

    local collected = 0
    for _, item in ipairs(loot_list) do
        if safe_alive(item.unit) then
            if pickup_loot_to_back(item.unit) then
                collected = collected + 1
            end
        end
    end

    NiceTrainer:Toast(string.format("Grabbed %d loot items to your back!", collected))
end

-- ─── Auto Collector Loop ──────────────────────────────────────────────────────
local _remote_loot_acc = 0
Hooks:Add("GameSetupUpdate", "NiceTrainer_RemoteLoot_AutoLoop", function(t, dt)
    if not NiceTrainer.Settings.remote_loot_collector or not NiceTrainer:IsInHeist() then return end
    _remote_loot_acc = _remote_loot_acc + dt
    if _remote_loot_acc >= 2.0 then
        _remote_loot_acc = 0
        local loot_list = get_map_loot()
        for _, item in ipairs(loot_list) do
            if safe_alive(item.unit) then
                pickup_loot_to_back(item.unit)
            end
        end
    end
end)

-- ─── Remote Loot Modal ────────────────────────────────────────────────────────
local LOOT_MODAL_W = 580
local LOOT_MODAL_H = 560
local LOOT_ROW_H   = 38

local function ShowRemoteLootModal()
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Only available during heist.")
        return
    end

    local loot_list = get_map_loot()

    NiceTrainer:ShowCustomModal("Remote Loot Collector", LOOT_MODAL_W, LOOT_MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        -- Subtitle / Count
        local count_txt = m:text({
            text = string.format("Found %d loose bags & loot items on the map.", #loot_list),
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(0.8, 0.8, 0.8), x = 18, y = 52, w = LOOT_MODAL_W - 36, layer = 2
        })

        -- Buttons row: [Take All to Back] [Refresh List]
        local btn_w, btn_h = 160, 28
        local btn_y = 78
        
        -- Take All Button
        local all_btn = m:panel({ x = 18, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local all_bg  = all_btn:rect({ color = Color(0.2, 0.8, 0.4), alpha = 0.25, layer = 0 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), x = btn_w - 1, w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), h = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), y = btn_h - 1, h = 1, layer = 1 })
        all_btn:text({ text = "Take All to Back", font = "fonts/font_medium_shadow_mf", font_size = 15, align = "center", vertical = "center", color = Color.white, layer = 2 })

        -- Refresh Button
        local ref_btn = m:panel({ x = 18 + btn_w + 12, y = btn_y, w = 120, h = btn_h, layer = 2 })
        local ref_bg  = ref_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), x = 119, w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        ref_btn:text({ text = "Refresh", font = "fonts/font_medium_shadow_mf", font_size = 15, align = "center", vertical = "center", color = Color.white, layer = 2 })

        local sep_y = 114
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 18, y = sep_y, w = LOOT_MODAL_W - 36, h = 1, layer = 2 })

        -- Scrollable List
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = LOOT_MODAL_W, h = LOOT_MODAL_H - scroll_top - 8, layer = 2 })

        local function build_list()
            if not alive(scroll_wrap) then return end
            scroll_wrap:clear()

            loot_list = get_map_loot()
            if alive(count_txt) then
                count_txt:set_text(string.format("Found %d loose bags & loot items on the map.", #loot_list))
            end

            local canvas_h = 8 + (#loot_list * (LOOT_ROW_H + 4))
            local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = LOOT_MODAL_W, h = math.max(canvas_h, LOOT_ROW_H), layer = 1 })
            top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

            local ROW_W = LOOT_MODAL_W - 16
            local y = 8

            if #loot_list == 0 then
                canvas:text({
                    text = "No loose loot or bags on the map right now.",
                    font = "fonts/font_medium_shadow_mf", font_size = 16,
                    color = Color(0.6, 0.6, 0.6), x = 18, y = y, layer = 2
                })
                return
            end

            for _, item in ipairs(loot_list) do
                local cur_item = item
                local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = LOOT_ROW_H, layer = 2 })
                local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

                -- Icon / Tag
                row:rect({ color = cur_item.is_bag and Color(0.2, 0.6, 1.0) or Color(1, 0.85, 0), alpha = 0.8, x = 8, y = 9, w = 4, h = 20, layer = 1 })

                -- Name
                row:text({
                    text = cur_item.name,
                    font = "fonts/font_medium_shadow_mf", font_size = 16,
                    x = 20, vertical = "center", color = Color(0.95, 0.95, 0.95), layer = 1
                })

                -- Distance
                row:text({
                    text = string.format("%dm", cur_item.dist),
                    font = "fonts/font_medium_shadow_mf", font_size = 14,
                    x = ROW_W - 170, w = 60, h = LOOT_ROW_H,
                    align = "right", vertical = "center", color = Color(0.6, 0.6, 0.6), layer = 1
                })

                -- [ Take to Back ] Button
                local take_w, take_h = 95, 24
                local take_btn = row:panel({ x = ROW_W - take_w - 8, y = 7, w = take_w, h = take_h, layer = 2 })
                local take_bg  = take_btn:rect({ color = Color(0.2, 0.8, 0.4), alpha = 0.25, layer = 0 })
                take_btn:rect({ color = Color(0.2, 0.8, 0.4), w = 1, layer = 1 })
                take_btn:rect({ color = Color(0.2, 0.8, 0.4), x = take_w - 1, w = 1, layer = 1 })
                take_btn:rect({ color = Color(0.2, 0.8, 0.4), h = 1, layer = 1 })
                take_btn:rect({ color = Color(0.2, 0.8, 0.4), y = take_h - 1, h = 1, layer = 1 })
                take_btn:text({
                    text = "Take to Back", font = "fonts/font_medium_shadow_mf", font_size = 13,
                    w = take_w, h = take_h, align = "center", vertical = "center",
                    color = Color.white, layer = 2
                })

                table.insert(top_modal.elements, {
                    panel = take_btn,
                    inside = function(self, mx, my)
                        if not (alive(scroll_wrap) and alive(take_btn)) then return false end
                        return scroll_wrap:inside(mx, my) and take_btn:inside(mx, my)
                    end,
                    on_hover = function(self, hovered)
                        if alive(take_bg) then
                            take_bg:set_alpha(hovered and 0.5 or 0.25)
                        end
                    end,
                    on_click = function(self)
                        if safe_alive(cur_item.unit) then
                            if pickup_loot_to_back(cur_item.unit) then
                                NiceTrainer:Toast("Picked up " .. cur_item.name .. " to back!")
                            end
                        end
                        build_list()
                    end
                })

                y = y + LOOT_ROW_H + 4
            end
        end

        -- Take All Click
        table.insert(top_modal.elements, {
            panel = all_btn,
            inside = function(self, mx, my)
                if not alive(all_btn) then return false end
                return all_btn:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                if alive(all_bg) then all_bg:set_alpha(hovered and 0.5 or 0.25) end
            end,
            on_click = function(self)
                grab_all_loot_to_back()
                build_list()
            end
        })

        -- Refresh Click
        table.insert(top_modal.elements, {
            panel = ref_btn,
            inside = function(self, mx, my)
                if not alive(ref_btn) then return false end
                return ref_btn:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                if alive(ref_bg) then ref_bg:set_alpha(hovered and 0.4 or 0.2) end
            end,
            on_click = function(self)
                build_list()
                NiceTrainer:Toast("Loot list refreshed!")
            end
        })

        build_list()
    end)
end

-- Register Actions
NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Bags",
    badge    = "client",
    id       = "remote_loot_collector",
    text     = "Auto-Pickup Bags",
    tooltip  = "Continuously sweeps the map and grabs all loose bags and interactable loot to your back every 2 seconds.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.remote_loot_collector = state
        NiceTrainer:Save()
        if state then
            grab_all_loot_to_back()
        end
    end,
})

NiceTrainer:RegisterAction("CarryStacker", {
    type            = "button",
    category        = "Bags",
    badge           = "client",
    text            = "Grab All Loot to Back",
    action_btn_text = "Grab All",
    tooltip         = "Instantly teleports all loose loot bags and raw unbagged loot on the map directly onto your back.",
    callback        = grab_all_loot_to_back,
})

NiceTrainer:RegisterAction("CarryStacker", {
    type            = "modal",
    category        = "Bags",
    badge           = "client",
    text            = "Remote Loot Collector",
    action_btn_text = "Open List...",
    tooltip         = "Opens an interactive modal listing all loot items on the map with distances and instant remote pickup buttons.",
    callback        = ShowRemoteLootModal,
})
