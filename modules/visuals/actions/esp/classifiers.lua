local ESP = NiceTrainer.ESP

function ESP.is_actual_bag(unit)
    if not (unit and alive(unit) and unit:enabled()) then return false end

    -- Reject live/dead special enemies right away to prevent modded 'corpse_dispose' interactions from turning them into "bags"
    if unit:base() and unit:base()._tweak_table then
        local tw_str = tostring(unit:base()._tweak_table):lower()
        if tw_str:find("taser") or tw_str:find("medic") or tw_str:find("spooc") or tw_str:find("tank") or tw_str:find("sniper") or tw_str:find("shield") or tw_str:find("phalanx") or tw_str:find("turret") then
            return false
        end
    end

    local inter = unit.interaction and unit:interaction()
    local td = inter and inter.tweak_data and tostring(inter.tweak_data):lower() or ""

    local uname = nil
    pcall(function() uname = tostring(unit:name() or ""):lower() end)
    local name_str = uname or ""

    -- Explicitly reject non-bag items first
    if td:find("painting", 1, true) or td:find("art_loot", 1, true) or td:find("art_prop_painting", 1, true)
       or name_str:find("art_loot", 1, true) or name_str:find("painting", 1, true) or name_str:find("art_prop_painting", 1, true)
       or td:find("goat", 1, true) or name_str:find("goat", 1, true)
       or td:find("c4", 1, true) or td:find("charge", 1, true) or name_str:find("c4", 1, true)
       or td:find("samurai", 1, true) or name_str:find("samurai", 1, true)
       or td:find("atm", 1, true) or name_str:find("atm", 1, true)
       or td:find("safe", 1, true) or name_str:find("safe", 1, true)
       or td:find("coke", 1, true) or td:find("meth", 1, true) or td:find("pure", 1, true) or td:find("chemical", 1, true)
       or td:find("money", 1, true) or td:find("cash", 1, true) or td:find("bundle", 1, true) or td:find("banknote", 1, true)
       or td:find("gold", 1, true) or td:find("diamond", 1, true) or td:find("jewel", 1, true) or td:find("necklace", 1, true)
       or td:find("ring", 1, true) or td:find("artifact", 1, true) or td:find("relic", 1, true) or td:find("tiara", 1, true)
       or td:find("statue", 1, true) or td:find("urn", 1, true) or td:find("chalice", 1, true) or td:find("bottle", 1, true)
       or td:find("wine", 1, true) or td:find("weapon", 1, true) or td:find("server", 1, true) or td:find("toy", 1, true)
       or td:find("shoes", 1, true) or td:find("gnome", 1, true) or td:find("vr_headset", 1, true) or td:find("puck", 1, true)
       or name_str:find("cash_pile", 1, true) or name_str:find("single_bundle", 1, true) or name_str:find("money_wrap", 1, true)
       or name_str:find("coke", 1, true) or name_str:find("gold", 1, true) or name_str:find("diamond", 1, true)
       or name_str:find("jewelry", 1, true) or name_str:find("weapon", 1, true)
    then
        return false
    end

    -- 1. Check interaction tweak data: strictly dropped bags / body bags / carry drops
    if td == "carry_drop"
       or td == "corpse_bag"
       or td == "body_bag"
       or td == "bodybag"
       or td == "bodybags_bag"
       or td == "take_body_bag"
       or td == "bag_drop"
       or td == "hold_take_carry"
       or td == "take_carry" then
        return true
    end

    -- 2. Check model name: strictly actual loot bag or body bag models
    if name_str:find("gen_prop_loot_bag", 1, true)
       or name_str:find("body_bag_unit", 1, true)
       or name_str:find("corpse_bag_unit", 1, true)
       or name_str:find("gen_prop_equipment_bag", 1, true)
       or name_str:find("units/payday2/props/gen_prop_loot_bag", 1, true) then
        return true
    end

    return false
end
function ESP.is_c4_mission_item(unit)
    if not (unit and alive(unit) and unit:enabled()) then return false end

    local uname = nil
    pcall(function() uname = tostring(unit:name() or ""):lower() end)
    local name_str = uname or ""

    local inter = unit.interaction and unit:interaction()
    local td = inter and inter.tweak_data and tostring(inter.tweak_data):lower() or ""

    -- 1. Check interaction tweak data
    if td == "c4" or td == "c4_bag" or td == "c4_charge" or td == "c4_stackable" or td == "c4_x"
       or td == "c4_consume" or td == "c4_plant" or td == "place_c4" or td == "plant_c4"
       or td == "thermite_c4" or td == "breaching_charges" or td == "c4_mission" or td == "c4_diffuse"
       or td == "alesso_c4" or td == "trip_mine" or td == "tripmine" or td == "c4_set"
       or td == "plant_c4_x3" or td == "shaped_charge" or td == "shaped_sharge"
       or td == "breaching_detonator" or td == "breacher" then
        return true
    end

    -- 2. Check model name
    if name_str:find("shaped_charge", 1, true)
       or name_str:find("shaped_sharge", 1, true)
       or name_str:find("c4_charge", 1, true)
       or name_str:find("c4_plant", 1, true)
       or name_str:find("breaching_charge", 1, true)
       or name_str:find("trip_mine", 1, true)
       or name_str:find("tripmine", 1, true)
       or (name_str:find("c4", 1, true) and not name_str:find("slot", 1, true) and not name_str:find("screen", 1, true)) then
        return true
    end

    -- 3. Carry data with c4
    if unit.carry_data and unit:carry_data() then
        local ok, cid = pcall(function() return unit:carry_data():carry_id() end)
        if ok and cid and type(cid) == "string" then
            local cid_l = cid:lower()
            if cid_l:find("c4", 1, true) or cid_l:find("charge", 1, true) then
                return true
            end
        end
    end

    return false
end
function ESP.is_actual_goat(unit)
    if not (unit and alive(unit) and unit:enabled()) then return false end

    -- 1. Character Goat (live civ_goat running around)
    if unit.character_damage and unit:character_damage() then
        local u_base = unit:base()
        local tw = u_base and u_base._tweak_table and tostring(u_base._tweak_table):lower() or ""
        local uname = tostring(unit:name() or ""):lower()
        if tw:find("goat", 1, true) or uname:find("goat", 1, true) or uname:find("civ_goat", 1, true) then
            return true
        end
    end

    -- 2. Carried / Dropped Goat Bag
    if unit.carry_data and unit:carry_data() then
        local ok, cid = pcall(function() return unit:carry_data():carry_id() end)
        if ok and cid and type(cid) == "string" and cid:lower():find("goat", 1, true) then
            return true
        end
    end

    -- 3. Interactive Goat (prop or interactable goat pickup)
    local inter = unit.interaction and unit:interaction()
    if inter and inter.tweak_data then
        local td = tostring(inter.tweak_data):lower()
        if td:find("goat", 1, true) then
            return true
        end
    end

    return false
end
function ESP.is_stealable_painting(unit)
    if not (unit and alive(unit) and unit:enabled()) then return false end
    local inter = unit.interaction and unit:interaction()
    if not inter then return false end

    local td = inter.tweak_data and tostring(inter.tweak_data):lower() or ""
    local uname = tostring(unit:name() or ""):lower()

    local is_paint = td:find("painting", 1, true)
        or td:find("art_loot", 1, true)
        or td:find("art_prop_painting", 1, true)
        or td:find("gallery_painting", 1, true)
        or td:find("hold_cut_painting", 1, true)
        or td:find("hold_take_painting", 1, true)
        or td:find("cut_painting", 1, true)
        or td:find("take_painting", 1, true)
        or (uname:find("painting", 1, true) and td ~= "" and not td:find("camera", 1, true) and not td:find("cctv", 1, true))

    if not is_paint then return false end

    local is_disabled = (inter.disabled and inter:disabled()) or inter._disabled or (inter._active == false)
    if is_disabled then
        return false
    end

    return true
end
function ESP.is_whitelisted_always_visible(unit)
    if not (unit and alive(unit)) then return false, nil end

    -- 1. Stealable Paintings (Must be active on wall, not taken/disabled)
    if ESP.is_stealable_painting(unit) then
        return true, "loot_valuables"
    end

    if ESP.is_actual_goat(unit) then
        return true, "loot_valuables"
    end

    if ESP.is_c4_mission_item(unit) then
        return true, "mission_c4"
    end

    return false, nil
end
function ESP.GetMissionSpawnedUnits()
    local units = {}
    if managers.mission and managers.mission._scripts then
        for _, script in pairs(managers.mission._scripts) do
            if script.elements then
                for _, element in pairs(script:elements()) do
                    if element._units and type(element._units) == "table" then
                        for _, u in ipairs(element._units) do
                            if alive(u) then
                                table.insert(units, u)
                            end
                        end
                    end
                    if element._unit and alive(element._unit) then
                        table.insert(units, element._unit)
                    end
                    if element._spawned_units and type(element._spawned_units) == "table" then
                        for _, u in ipairs(element._spawned_units) do
                            if alive(u) then
                                table.insert(units, u)
                            end
                        end
                    end
                end
            end
        end
    end
    return units
end
function ESP._raw_classify_interactive(unit)
    -- Cameras are handled separately by Section 2 (Security Cameras)
    local base = unit:base()
    if base and (base.is_security_camera or base.security_camera or base._detection_interval) then
        return nil
    end

    -- Reject all dead characters to prevent modded interactions (like Carry Stacker) or base game body bag interactions from turning corpses into interactive items
    if unit:character_damage() and unit:character_damage():dead() then
        return nil
    end

    local interaction = unit.interaction and unit:interaction()
    local id = interaction and interaction.tweak_data
    local id_str = type(id) == "string" and string.lower(id) or ""

    local uname = nil
    pcall(function()
        uname = tostring(unit:name())
    end)
    local name_str = type(uname) == "string" and string.lower(uname) or ""

    -- Direct check: Security Cameras & CCTV
    if (base and (base.is_security_camera or base.is_spy_camera))
        or id_str:find("camera", 1, true)
        or id_str:find("cctv", 1, true)
        or id_str:find("tape_loop", 1, true)
        or name_str:find("camera", 1, true)
        or name_str:find("cctv", 1, true)
    then
        return "cameras", "camera"
    end

    -- Direct check: Paintings & Art Loot (Art Gallery, Framing Frame, etc.)
    if ESP.is_stealable_painting(unit) then
        return "loot_valuables", "painting"
    end

    -- Direct check: Goats (Goat Simulator live or props)
    if id_str:find("goat", 1, true) or name_str:find("goat", 1, true) then
        return "loot_valuables", "goat"
    end

    -- Direct check: C4 Charges & Shaped charges
    if ESP.is_c4_mission_item(unit) then
        return "mission_c4", (id_str ~= "" and id_str or "c4")
    end

    -- Direct check: Real Bags (ensacadas)
    if ESP.is_actual_bag(unit) then
        return "loot_bags", (id_str ~= "" and id_str or "bag")
    end

    -- Direct check: Samurai Armor (Shadow Raid)
    if name_str:find("samurai", 1, true) or id_str:find("samurai", 1, true) then
        return "loot_valuables", "samurai armor"
    end

    -- Direct check: ATMs (Bank ATMs, standing ATMs, ATM loot)
    if id_str:find("atm", 1, true) or name_str:find("atm", 1, true) or name_str:find("bank_machine", 1, true) then
        local label = (id_str:find("loot", 1, true) or name_str:find("loot", 1, true)) and "atm cash" or "atm"
        return "loot_cash", label
    end

    -- Direct check: Casino chips & Cash piles (Golden Grin Casino, etc.)
    if id_str:find("chip", 1, true) or name_str:find("chip", 1, true) or id_str:find("cas_prop_chip", 1, true) or name_str:find("cas_prop_chip", 1, true) then
        return "loot_cash", "casino chips"
    end

    -- Direct check: Crates (Shadow Raid, Election Day, Murky Station, Golden Grin, etc.)
    if id_str:find("crate", 1, true) or name_str:find("crate", 1, true) then
        return "loot_valuables", (id_str ~= "" and id_str or "crate")
    end

    -- Direct check: Crowbar tool pickups
    if id_str == "crowbar" or id_str == "crowbar_stackable" or id_str == "take_crowbar" or id_str == "pku_crowbar" or id_str == "pickup_crowbar" then
        return "mission_crowbar", id_str
    end

    -- Direct check: Power boxes, Circuit Breakers, Fuse Boxes, Security Boxes, Transformers, Wiring, Rewiring, Hackpads
    if id_str:find("circuit", 1, true)
        or id_str:find("breaker", 1, true)
        or id_str:find("power", 1, true)
        or id_str:find("fuse", 1, true)
        or id_str:find("sec_box", 1, true)
        or id_str:find("security_box", 1, true)
        or id_str:find("switch_box", 1, true)
        or id_str:find("transformer", 1, true)
        or id_str:find("rewire", 1, true)
        or id_str:find("cut_wire", 1, true)
        or id_str:find("cut_cable", 1, true)
        or id_str:find("cut_wires", 1, true)
        or id_str:find("pull_switch", 1, true)
        or id_str:find("electric", 1, true)
        or id_str:find("junction", 1, true)
        or id_str:find("substation", 1, true)
        or id_str:find("cable", 1, true)
        or id_str:find("hackpad", 1, true)
        or id_str:find("hack_pad", 1, true)
        or name_str:find("power_box", 1, true)
        or name_str:find("powerbox", 1, true)
        or name_str:find("circuit_breaker", 1, true)
        or name_str:find("fuse_box", 1, true)
        or name_str:find("security_box", 1, true)
        or name_str:find("sec_box", 1, true)
        or name_str:find("electrical_box", 1, true)
        or name_str:find("electrical", 1, true)
        or name_str:find("transformer", 1, true)
        or name_str:find("switch_box", 1, true)
        or name_str:find("breaker", 1, true)
        or name_str:find("circuit", 1, true)
        or name_str:find("junction", 1, true)
        or name_str:find("substation", 1, true)
        or name_str:find("rewire", 1, true)
        or name_str:find("hackpad", 1, true)
        or name_str:find("hack_pad", 1, true)
    then
        return "mission_power", (id_str ~= "" and id_str or (name_str ~= "" and name_str or "power box"))
    end

    -- Direct check: Laptops, Notebooks, Computers & Terminals
    if id_str:find("laptop", 1, true)
        or id_str:find("notebook", 1, true)
        or id_str:find("computer", 1, true)
        or id_str:find("server", 1, true)
        or id_str:find("terminal", 1, true)
        or id_str:find("keypad", 1, true)
        or id_str:find("hackable", 1, true)
        or name_str:find("laptop", 1, true)
        or name_str:find("notebook", 1, true)
        or name_str:find("computer", 1, true)
        or name_str:find("server", 1, true)
        or name_str:find("terminal", 1, true)
    then
        return "mission_computer", (id_str ~= "" and id_str or (name_str ~= "" and name_str or "laptop"))
    end

    -- 1. Primary: Match against the actual interaction tweak_data ID (Mission items take priority over loot)
    if id_str ~= "" then
        for _, entry in ipairs(ESP.MISSION_CLASSIFY) do
            for _, pattern in ipairs(entry.patterns) do
                if id_str:find(pattern, 1, true) then
                    return entry.key, id_str
                end
            end
        end

        for _, entry in ipairs(ESP.LOOT_CLASSIFY) do
            for _, pattern in ipairs(entry.patterns) do
                if id_str:find(pattern, 1, true) then
                    return entry.key, id_str
                end
            end
        end
    end

    -- 2. Fallback: For loose models without interaction IDs
    if name_str ~= "" then
        if name_str:find("gen_prop_loot_bag", 1, true) or name_str:find("body_bag_unit", 1, true) or name_str:find("corpse_bag_unit", 1, true) then
            return "loot_bags", "bag"
        end
        for _, entry in ipairs(ESP.MISSION_CLASSIFY) do
            for _, pattern in ipairs(entry.patterns) do
                if name_str:find(pattern, 1, true) then
                    return entry.key, (id_str ~= "" and id_str or name_str)
                end
            end
        end

        for _, entry in ipairs(ESP.LOOT_CLASSIFY) do
            for _, pattern in ipairs(entry.patterns) do
                if name_str:find(pattern, 1, true) then
                    return entry.key, (id_str ~= "" and id_str or name_str)
                end
            end
        end
    end

    return nil
end
function ESP.ClassifyInteractive(unit)
    if not (unit and alive(unit)) then return nil end
    
    local base_ext = unit:base() or (unit.interaction and unit:interaction())
    if base_ext and base_ext._nt_classification ~= nil then
        if base_ext._nt_classification == false then return nil end
        return base_ext._nt_classification[1], base_ext._nt_classification[2]
    end

    local cat, tw = ESP._raw_classify_interactive(unit)
    
    if base_ext then
        if cat then
            base_ext._nt_classification = { cat, tw }
        else
            base_ext._nt_classification = false
        end
    end
    
    return cat, tw
end
local MAX_LABEL = 22
function ESP.FormatLabel(str)
    if not str then return "" end
    str = string.lower(str)
    str = string.gsub(str, "units/", "")
    str = string.gsub(str, "payday2/", "")
    str = string.gsub(str, "pd2_dlc[^/]+/", "")
    str = string.gsub(str, "equipment/", "")
    str = string.gsub(str, "pickups/", "")
    str = string.gsub(str, "props/", "")
    str = string.gsub(str, "architecture/", "")
    str = string.gsub(str, "characters/", "")
    str = string.gsub(str, "shared_textures/", "")
    str = string.gsub(str, "gen_interactable_prop_", "")
    str = string.gsub(str, "gen_interactable_", "")
    str = string.gsub(str, "gen_prop_", "")
    str = string.gsub(str, "gen_pku_", "")
    str = string.gsub(str, "bnk_prop_", "")
    str = string.gsub(str, "com_prop_", "")
    str = string.gsub(str, "mus_prop_", "")
    str = string.gsub(str, "mcm_prop_", "")
    str = string.gsub(str, "tag_prop_", "")
    str = string.gsub(str, "trai_prop_", "")
    str = string.gsub(str, "sand_prop_", "")
    str = string.gsub(str, "uno_prop_", "")
    str = string.gsub(str, "vit_prop_", "")
    str = string.gsub(str, "xmn_prop_", "")
    str = string.gsub(str, "hud_int_hold_", "")
    str = string.gsub(str, "hud_int_press_", "")
    str = string.gsub(str, "hud_int_", "")
    str = string.gsub(str, "hud_hold_", "")
    str = string.gsub(str, "hud_press_", "")
    str = string.gsub(str, "hud_", "")
    str = string.gsub(str, "debug_interact_", "")
    str = string.gsub(str, "hold_take_", "")
    str = string.gsub(str, "hold_pku_", "")
    str = string.gsub(str, "hold_", "")
    str = string.gsub(str, "press_", "")
    str = string.gsub(str, "pku_", "")
    str = string.gsub(str, "gen_prop_bank_atm_standing[^/]*", "atm")
    str = string.gsub(str, "atm_standing", "atm")
    str = string.gsub(str, "atm_open", "atm")
    str = string.gsub(str, "atm_loot", "atm cash")
    str = string.gsub(str, "money_wrap", "money")
    str = string.gsub(str, "single_bundle", "cash")
    str = string.gsub(str, "gage_assignment", "gage")
    str = string.gsub(str, "vit_open_security_box", "power box")
    str = string.gsub(str, "vit_security_box", "power box")
    str = string.gsub(str, "vit_rewire", "rewire")
    str = string.gsub(str, "vit_cut_wires", "cut wire")
    str = string.gsub(str, "open_slash_close_sec_box", "power box")
    str = string.gsub(str, "cas_open_security_box", "power box")
    str = string.gsub(str, "open_sec_box", "power box")
    str = string.gsub(str, "security_box", "power box")
    str = string.gsub(str, "sec_box", "power box")
    str = string.gsub(str, "circuit_breaker_off", "breaker")
    str = string.gsub(str, "circuit_breaker", "breaker")
    str = string.gsub(str, "hold_circuit_breaker", "breaker")
    str = string.gsub(str, "transformer_box", "transformer")
    str = string.gsub(str, "switch_box", "switch box")
    str = string.gsub(str, "fuse_box", "fuse box")
    str = string.gsub(str, "electrical_box", "power box")
    str = string.gsub(str, "hold_pull_switch_distance", "switch")
    str = string.gsub(str, "hold_pull_switch", "switch")
    str = string.gsub(str, "pull_switch_distance", "switch")
    str = string.gsub(str, "pull_switch", "switch")
    str = string.gsub(str, "hold_cut_wires", "cut wire")
    str = string.gsub(str, "hold_cut_wire", "cut wire")
    str = string.gsub(str, "cut_wires", "cut wire")
    str = string.gsub(str, "cut_wire", "cut wire")
    str = string.gsub(str, "cut_cable", "cut cable")
    str = string.gsub(str, "open_slash_use_computer", "laptop")
    str = string.gsub(str, "use_computer", "laptop")
    str = string.gsub(str, "use computer", "laptop")
    str = string.gsub(str, "dah_type_password", "laptop")
    str = string.gsub(str, "type_in_password", "laptop")
    str = string.gsub(str, "type_password", "laptop")
    str = string.gsub(str, "enter_password", "laptop")
    str = string.gsub(str, "dah_hackpad", "hackpad")
    str = string.gsub(str, "dah_hack_fuse_box", "hackpad")
    str = string.gsub(str, "hack_fuse_box", "hackpad")
    str = string.gsub(str, "dah_laptop", "laptop")
    str = string.gsub(str, "disable_lasers", "lasers")
    str = string.gsub(str, "disable_laser", "lasers")
    str = string.gsub(str, "doctor_bag", "medic bag")
    str = string.gsub(str, "first_aid_kit", "first aid")
    str = string.gsub(str, "first_aid", "first aid")
    str = string.gsub(str, "ammo_bag", "ammo")
    str = string.gsub(str, "bodybags_bag", "body bags")
    str = string.gsub(str, "body_bag", "body bag")
    str = string.gsub(str, "carry_drop", "bag")
    str = string.gsub(str, "bag_drop", "bag")
    str = string.gsub(str, "hold_take_carry", "bag")
    str = string.gsub(str, "take_carry", "bag")
    str = string.gsub(str, "pure_coke", "coke")
    str = string.gsub(str, "coke_pure", "coke")
    str = string.gsub(str, "cokebag", "coke bag")
    str = string.gsub(str, "methbag", "meth bag")
    str = string.gsub(str, "goldbag", "gold bag")
    str = string.gsub(str, "gold_pile", "gold")
    str = string.gsub(str, "gold_bar", "gold")
    str = string.gsub(str, "diamond_single", "diamond")
    str = string.gsub(str, "diamond_necklace", "necklace")
    str = string.gsub(str, "suburbia_necklace", "necklace")
    str = string.gsub(str, "chas_teaset", "teaset")
    str = string.gsub(str, "deposit_box", "deposit")
    str = string.gsub(str, "safety_deposit", "deposit")
    str = string.gsub(str, "shaped_charge", "c4")
    str = string.gsub(str, "painting_carry_drop", "painting")
    str = string.gsub(str, "hold_take_painting", "painting")
    str = string.gsub(str, "hold_cut_painting", "painting")
    str = string.gsub(str, "cut_painting", "painting")
    str = string.gsub(str, "gallery_painting", "painting")
    str = string.gsub(str, "art_prop_painting", "painting")
    str = string.gsub(str, "art_loot", "painting")
    str = string.gsub(str, "hold_take_goat", "goat")
    str = string.gsub(str, "hold_pull_goat", "goat")
    str = string.gsub(str, "hold_search_goat", "goat")
    str = string.gsub(str, "hold_grab_goat", "goat")
    str = string.gsub(str, "peta_take_goat", "goat")
    str = string.gsub(str, "peta_grab_goat", "goat")
    str = string.gsub(str, "peta_pull_goat", "goat")
    str = string.gsub(str, "take_goat", "goat")
    str = string.gsub(str, "pku_goat", "goat")
    str = string.gsub(str, "civ_goat", "goat")
    str = string.gsub(str, "pta_prop_goat", "goat")
    str = string.gsub(str, "jewelry_bust", "bust")
    str = string.gsub(str, "secret_stash_", "")
    str = string.gsub(str, "_", " ")
    str = string.gsub(str, "^%s*(.-)%s*$", "%1")
    str = string.upper(str)
    if #str > MAX_LABEL then str = string.sub(str, 1, MAX_LABEL - 1) .. "." end
    return str
end
function ESP.UnitHasKeycard(unit)
    if not (unit and alive(unit)) then return false, nil end

    -- 1. Character Damage Drop/Pickup
    if unit.character_damage and unit:character_damage() then
        local cd = unit:character_damage()
        local pickup = cd._pickup or (cd.pickup and cd:pickup())
        if pickup then
            local p_str = string.lower(tostring(pickup))
            if p_str:find("key", 1, true) or p_str:find("card", 1, true) or p_str:find("pass", 1, true) then
                return true, "KEYCARD"
            end
        end
    end

    -- 2. Interaction tweak data
    if unit.interaction and unit:interaction() then
        local td = unit:interaction().tweak_data
        if td then
            local td_str = string.lower(tostring(td))
            if td_str:find("key", 1, true) or td_str:find("card", 1, true) or td_str:find("pass", 1, true) or td_str:find("search", 1, true) then
                return true, "KEYCARD"
            end
        end
    end

    -- 3. Spawn manager child units (attached keycard to belt/vest)
    if unit.spawn_manager and unit:spawn_manager() then
        local ok, sm = pcall(function() return unit:spawn_manager() end)
        if ok and sm then
            -- Usually it's sm:spawned_units() or sm._spawned_units
            local spawned = sm.spawned_units and sm:spawned_units() or sm._spawned_units
            if spawned then
                for _, entry in pairs(spawned) do
                    local child_u = type(entry) == "table" and entry.unit or entry
                    if child_u and type(child_u) == "userdata" and alive(child_u) then
                        local c_name = string.lower(tostring(child_u:name() or ""))
                        if c_name:find("keycard", 1, true) or c_name:find("key_chain", 1, true) or c_name:find("pass_card", 1, true) then
                            return true, "KEYCARD"
                        end
                        if child_u.interaction and child_u:interaction() then
                            local c_td = string.lower(tostring(child_u:interaction().tweak_data or ""))
                            if c_td:find("key", 1, true) or c_td:find("card", 1, true) then
                                return true, "KEYCARD"
                            end
                        end
                    end
                end
            end
        end
    end

    -- 4. Unit name / type (Bank Managers, etc.)
    local u_name = string.lower(tostring(unit:name() or ""))
    if u_name:find("bank_manager", 1, true) or u_name:find("bex_bank_manager", 1, true) or u_name:find("fex_manager", 1, true) then
        return true, "KEYCARD (MANAGER)"
    end

    -- 5. Tweak table for manager
    local tw = unit:base() and unit:base()._tweak_table
    if tw then
        local tw_str = string.lower(tostring(tw))
        if tw_str:find("bank_manager", 1, true) or tw_str:find("ranchmanager", 1, true) or tw_str:find("cfo", 1, true) then
            return true, "KEYCARD (MANAGER)"
        end
    end

    return false, nil
end
function ESP.ClassifyNPC(unit, info)
    local tw = unit:base() and unit:base()._tweak_table
    local tw_str = tw and string.lower(tostring(tw)) or ""

    local u_name = ""
    pcall(function()
        u_name = string.lower(tostring(unit:name() or ""))
    end)

    -- 1. Special Police / Heavies / Snipers / Cloakers / Turrets
    if tw_str:find("tank", 1, true) or tw_str:find("bulldozer", 1, true) or tw_str:find("piggydozer", 1, true) then
        return "special_dozer"
    elseif tw_str:find("taser", 1, true) then
        return "special_taser"
    elseif tw_str:find("medic", 1, true) then
        return "special_medic"
    elseif tw_str:find("shield", 1, true) or tw_str:find("phalanx_minion", 1, true) or tw_str:find("phalanx_vip", 1, true) then
        return "special_shield"
    elseif tw_str:find("sniper", 1, true) or tw_str:find("marshal_marksman", 1, true) then
        return "special_sniper"
    elseif tw_str:find("spooc", 1, true) or tw_str:find("cloaker", 1, true) or tw_str:find("shadow_spooc", 1, true) or u_name:find("cloaker", 1, true) then
        return "special_cloaker"
    elseif tw_str:find("turret", 1, true) or tw_str:find("sentry", 1, true) or u_name:find("swat_van_turret", 1, true) or u_name:find("ceiling_turret", 1, true) then
        return "special_turret"
    elseif tw_str:find("goat", 1, true) or u_name:find("goat", 1, true) or u_name:find("civ_goat", 1, true) then
        return "loot_valuables"
    end

    -- 2. VIP & Mission Critical NPCs (Bank Manager, Keycard Carriers, Escorts, CFO, Boris, Drunk Pilot, Old Hoxton, Inside Man, Taxman, Bosses, etc.)
    local is_vip = false
    
    local has_key, _ = ESP.UnitHasKeycard(unit)
    if has_key then
        is_vip = true
    end

    -- Fast key lookup for all known Bank Manager and VIP unit models
    if not is_vip and ESP.VIP_UNIT_KEYS[unit:name():key()] then
        is_vip = true
    end

    local pickup = nil
    if unit.character_damage and unit:character_damage() then
        local cd = unit:character_damage()
        pickup = cd._pickup or (cd.pickup and cd:pickup())
    end
    local pickup_str = type(pickup) == "string" and string.lower(pickup) or ""
    
    local inter_td = unit.interaction and unit:interaction() and unit:interaction().tweak_data
    local inter_td_str = type(inter_td) == "string" and string.lower(tostring(inter_td)) or ""

    if not is_vip and (tw_str:find("bank_manager", 1, true)
        or tw_str:find("escort", 1, true)
        or tw_str:find("drunk_pilot", 1, true)
        or tw_str:find("boris", 1, true)
        or tw_str:find("spa_vip", 1, true)
        or tw_str:find("inside_man", 1, true)
        or tw_str:find("inside_woman", 1, true)
        or tw_str:find("old_hoxton_mission", 1, true)
        or tw_str:find("taxman", 1, true)
        or tw_str:find("mitch", 1, true)
        or tw_str:find("ranchmanager", 1, true)
        or tw_str:find("cfo", 1, true)
        or tw_str:find("boss", 1, true)
        or tw_str:find("captain", 1, true)
        or tw_str:find("hector_boss", 1, true)
        or tw_str:find("chavez_boss", 1, true)
        or tw_str:find("biker_boss", 1, true)
        or tw_str:find("triad_boss", 1, true)
        or tw_str:find("mobster_boss", 1, true)
        or tw_str:find("bolivian_indoors_boss", 1, true)
        or tw_str:find("scientist", 1, true)
        or tw_str:find("president", 1, true)
        or tw_str:find("prisoner", 1, true)
        or tw_str:find("curator", 1, true))
    then
        is_vip = true
    end

    -- Check model / unit name string
    if not is_vip and u_name ~= "" then
        if u_name:find("bank_manager", 1, true)
            or u_name:find("manager", 1, true)
            or u_name:find("escort", 1, true)
            or u_name:find("pilot", 1, true)
            or u_name:find("vip", 1, true)
            or u_name:find("boss", 1, true)
            or u_name:find("cfo", 1, true)
            or u_name:find("boris", 1, true)
            or u_name:find("taxman", 1, true)
            or u_name:find("scientist", 1, true)
            or u_name:find("president", 1, true)
            or u_name:find("mechanic", 1, true)
            or u_name:find("inside_man", 1, true)
            or u_name:find("prisoner", 1, true)
            or u_name:find("commissioner", 1, true)
            or u_name:find("curator", 1, true)
        then
            is_vip = true
        end
    end

    -- Check if NPC carries a keycard / drop item
    if not is_vip and pickup_str ~= "" then
        if pickup_str:find("key", 1, true) or pickup_str:find("card", 1, true) or pickup_str:find("manager", 1, true) or pickup_str:find("access", 1, true) or pickup_str:find("pass", 1, true) then
            is_vip = true
        end
    end

    -- Check interaction attached to unit
    if not is_vip and inter_td_str ~= "" then
        if inter_td_str:find("key", 1, true) or inter_td_str:find("search", 1, true) or inter_td_str:find("escort", 1, true) or inter_td_str:find("rescue", 1, true) then
            is_vip = true
        end
    end

    local char_td = tweak_data and tweak_data.character and tweak_data.character[tw]
    if not is_vip and char_td then
        if char_td.is_escort or char_td.spotlight_important then
            is_vip = true
        end
    end

    -- Check AI Special Objective / Brain tags if available
    if not is_vip and unit.brain and unit:brain() then
        local brain = unit:brain()
        local so_access = brain._SO_access
        local so_str = type(so_access) == "string" and string.lower(so_access) or ""
        if so_str:find("bank_manager", 1, true) or so_str:find("vip", 1, true) or so_str:find("escort", 1, true) then
            is_vip = true
        end
    end

    if is_vip then
        return "vips"
    end

    -- 3. Regular Civilians (Female civilians, Mariachi, Safehouse civilians, Civilians with no penalty, etc.)
    if tw_str:find("civilian", 1, true)
        or tw_str == "robbers_safehouse"
        or tw_str == "melee_box"
        or u_name:find("civ_", 1, true)
    then
        return "civilians"
    end

    if CopDamage and CopDamage.is_civilian and CopDamage.is_civilian(tw) then
        return "civilians"
    end

    if managers.enemy and managers.enemy.is_civilian and managers.enemy:is_civilian(unit) then
        return "civilians"
    end

    if managers.slot and unit.in_slot and unit:in_slot(managers.slot:get_mask("civilians")) then
        return "civilians"
    end

    if char_td then
        if char_td.civilian or (char_td.challenges and char_td.challenges.type == "civilians") then
            return "civilians"
        end
        if char_td.access and string.sub(char_td.access, 1, 4) == "civ_" then
            return "civilians"
        end
    end

    -- 4. Regular Cops & Security Guards & Gangsters
    return "cops"
end
function ESP.is_unit_dead(unit)
    if not (unit and alive(unit)) then return true end

    -- Slot checks (corpses, ragdolls)
    if unit:in_slot(17) or unit:in_slot(25) then
        return true
    end

    -- Character damage checks
    local cd = unit.character_damage and unit:character_damage()
    if cd then
        if cd._dead then return true end
        if type(cd.dead) == "function" and cd:dead() then return true end
    end

    -- Base checks
    local base = unit.base and unit:base()
    if base and (base._dead or (base.is_dead and type(base.is_dead) == "function" and base:is_dead())) then
        return true
    end

    return false
end
function ESP.IsFriendlyUnit(unit)
    if not (unit and alive(unit)) then return false end

    -- Local Player
    if managers.player and managers.player:player_unit() == unit then
        return true
    end

    local base = unit.base and unit:base()
    if base then
        if base.is_local_player or base.is_husk_player then
            return true
        end
        if base.is_convert or base.is_converted then
            return true
        end
    end

    local gai = managers.groupai and managers.groupai:state()
    if gai then
        if gai.is_unit_team_AI and gai:is_unit_team_AI(unit) then
            return true
        end
        if gai.all_player_criminals and gai:all_player_criminals()[unit:key()] then
            return true
        end
        if gai.all_AI_criminals and gai:all_AI_criminals()[unit:key()] then
            return true
        end
        if gai.is_unit_police_converted and gai:is_unit_police_converted(unit) then
            return true
        end
        if gai._police and gai._police[unit:key()] and gai._police[unit:key()].is_converted then
            return true
        end
        if gai._converted_police and gai._converted_police[unit:key()] then
            return true
        end
    end

    -- Slot 2 = players, 3 = criminals, 16 = team_AI, 24 = converted_enemies
    if unit:in_slot(2) or unit:in_slot(3) or unit:in_slot(16) or unit:in_slot(24) then
        return true
    end

    return false
end
