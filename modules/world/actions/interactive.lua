-- Interactive Objects & World Utilities for NiceTrainer (World Tab)
-- Provides Categorized Modals, Multi-Tab World Objects Explorer, Dynamic Map Detection, and Remote Interaction.

-- ============================================================
-- Interaction ID database (hashes from interactions.json)
-- ============================================================
local _interactions = nil

local function _load_interactions()
    if _interactions then return _interactions end

    local path = NiceTrainer.ModPath .. "data/interactions.json"
    local ok_read, content = false, nil

    if io.file_is_readable and io.file_is_readable(path) then
        local f = io.open(path, "r")
        if f then
            content = f:read("*all")
            f:close()
            ok_read = true
        end
    end

    if ok_read and content then
        local ok_json, decoded = pcall(json.decode, content)
        if ok_json and type(decoded) == "table" then
            _interactions = decoded
            return _interactions
        end
    end

    -- Fallback inline table (kept in sync with data/interactions.json)
    _interactions = {
        ["open-doors"] = {
            "e653b95736abc583","4407f5e571e2f51a","a25106db58e693fc","18a7caca12899b38",
            "645fad32c1eabd6b","b68beff56b10a9fd","851f3239dec9d210","95cdd60b3546a91c",
            "e95f3cda0f71f283","08a33537c9d0673a","086277cceecba34c","1d283db01fc4a72b",
            "9c5716b1233940a7","5349b5cf54341268","622b34ce3cd1d3bb","574bab205ffb92e4",
            "0e2cd454f5ee8bfa","245afc14239b8863","6f05dea8c859aab9","ab54c8b618486ddb",
            "cae8305c16806475","d9667fc91bbd9a54","004abf948ee53441","b43c26feb159eef7",
            "7601731dfdabdf2c","db4fe8f7d5684758","cfb8d38ad0edaedb","2f913647223aa622",
            "cf8980a644c5b7ec","cffcea35596d6b53","14093a6ddd6664d9","43132b0a273df773",
            "fbf379ad311ef40d","c64fa142f6d098b5","c3419d4bf5de2647","8479fb0d2c0ae300",
            "59f28d3cc55b04c6","9f86c1d142c90206","5eb73ede6ece6c9d","559c3e4ebf3b32f3",
            "cfffc73d99a0b3ce","30a21bbbcb69954e","6283ee0a3557468c","c0a49d70d9725387",
            "58076b8d4c8ba6d3","070795428cd925dc","985d76ced36deacf"
        },
        ["open-windows"] = {
            "31ccfa0f3229b974","606a9bb7134be4b8","ebbffe6226241ea2","8dd5dfcaf36f7c02",
            "d99d699641a8bd4e","344cc0fed4dcb301","92319bc34bbe75fa"
        },
        ["open-deposit-boxes"] = {
            "79991727a2679722","e93c9b2218810d63","a95e021324bc842a","d2d7c5a3aced6f0f",
            "e4bc87015ed9fd46","50aac55917cba830","5dcd1776e3f2f767","8d8c766828915eb9",
            "51da6d6c91d378c1"
        },
        ["open-containers"] = {
            "391916f9100c4b3f","d0a93f5776731f41"
        },
        ["open-crates"] = {
            "9819a50244591ecf","a9d501c31b8d7592","d90bf4a3a96e4d3b",
            "067dc091e3ddb975","5ccfb101f75d720b","b22c6099e7518d43"
        },
        ["open-atms"] = {
            "c403e02cf736e795"
        },
        ["cut-fences"] = {
            "d5d1c35e617d73ad","b025e83ed6d542b4"
        },
        ["hack-computers"] = {
            "08cc6579c6c50d23","58cb6c4c6221c415","c06b518a90138065","18246f3fc500983d",
            "2721ad04af703513","629e9f44e06ea56f","9db53c1337a10fb7","e70d5b98a739aedc",
            "3c10506b25886b2b"
        },
        ["barricade-windows"] = {
            "b524e472a247f6ff","b71bf75755b6181b","4738b25ad84c7f39","b55faf1195846400",
            "bb2c888ee317cf22","2840eded7a49eba6","e86b68a126c540da","945dcbc3586178cd"
        },
        ["place-drills"] = {
            "584bea03f3b5d712","2bf4a499717b215f","ae5854b5e1565e45","f594e56c194ff640"
        },
        ["place-shaped-charges"] = {
            "34d05ca941b5ebfe","169f2718e6c167e4"
        },
        ["use-keycards"] = {
            "2a72308f20bd9293","15d846fa379f77a6","db2e8d04bec83951","86703455b619528f",
            "a52494f0946a6ab0","a93a07d5b7bf4418","03b7330fcde71c50","29c7dea1a7d81dbd"
        },
        ["pick-up-packages"] = {
            "b3cc2abe1734636c","c90378ad89058c7d","96504ebd40f8cf98",
            "05956ff396f3c58e","e8088e3bdae0ab9e"
        },
    }
    return _interactions
end

local function _to_set(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end

-- Known Bank Vault Doors, Titan Safes, Wall Safes & Deposit Box units (mapped to Idstring keys for 100% reliable matching)
local VAULT_UNIT_PATHS = {
    -- Harvest & Trustee / Branchbank / Classic Banks
    "units/payday2/props/bnk_prop_vault_door/bnk_prop_vault_door",
    "units/payday2/props/bnk_prop_vault_door_titan/bnk_prop_vault_door_titan",
    "units/payday2/props/bnk_prop_vault_gate/bnk_prop_vault_gate",
    "units/payday2/props/bnk_prop_vault_deposit_box/bnk_prop_vault_deposit_box",
    "units/payday2/props/bnk_prop_vault_deposit_box_a/bnk_prop_vault_deposit_box_a",
    "units/payday2/props/bnk_prop_vault_deposit_box_b/bnk_prop_vault_deposit_box_b",
    
    -- Titan Safes & Standard Safes
    "units/payday2/props/gen_prop_titan_safe/gen_prop_titan_safe",
    "units/payday2/props/gen_prop_safe_small/gen_prop_safe_small",
    "units/payday2/props/gen_prop_safe_medium/gen_prop_safe_medium",
    "units/payday2/props/gen_prop_safe_large/gen_prop_safe_large",
    "units/payday2/props/gen_prop_wall_safe/gen_prop_wall_safe",
    "units/payday2/props/com_prop_store_safe/com_prop_store_safe",
    "units/payday2/props/off_prop_safe_medium/off_prop_safe_medium",
    
    -- DLC Maps Vault Doors & Safes (San Martín, Breakfast in Tijuana, Buluc's Mansion, Big Bank, First World Bank, Diamond Heist, etc.)
    "units/pd2_dlc_bex/props/bex_prop_vault_door/bex_prop_vault_door",
    "units/pd2_dlc_bex/props/bex_prop_safe_small/bex_prop_safe_small",
    "units/pd2_dlc_trai/props/trai_prop_vault_door/trai_prop_vault_door",
    "units/pd2_dlc_trai/props/trai_prop_safe/trai_prop_safe",
    "units/pd2_dlc_chca/props/chca_prop_vault_door/chca_prop_vault_door",
    "units/pd2_dlc_chca/props/chca_prop_safe/chca_prop_safe",
    "units/pd2_dlc_pal/props/pal_prop_vault_door/pal_prop_vault_door",
    "units/pd2_dlc_pal/props/pal_prop_vault_gate/pal_prop_vault_gate",
    "units/pd2_dlc_dah/props/dah_prop_vault_door/dah_prop_vault_door",
    "units/pd2_dlc_rvd/props/rvd_prop_vault_door/rvd_prop_vault_door",
    "units/pd2_dlc_friend/props/friend_prop_vault_door/friend_prop_vault_door",
    "units/pd2_dlc_big/props/big_prop_vault_door/big_prop_vault_door",
    "units/pd2_dlc_big/props/big_prop_vault_gate/big_prop_vault_gate",
    "units/pd2_dlc_mex/props/mex_prop_vault_door/mex_prop_vault_door",
    "units/pd2_dlc_mex/props/mex_prop_safe/mex_prop_safe",
    "units/pd2_dlc_pex/props/pex_prop_safe/pex_prop_safe",
    "units/pd2_dlc_fex/props/fex_prop_safe/fex_prop_safe",
    "units/pd2_dlc_sand/props/sand_prop_safe/sand_prop_safe",
    "units/pd2_dlc_glace/props/glc_prop_safe/glc_prop_safe",
}

local VAULT_UNIT_KEYS = {}
for _, p in ipairs(VAULT_UNIT_PATHS) do
    VAULT_UNIT_KEYS[Idstring(p):key()] = true
end

-- ============================================================
-- Category Definitions & Classifier
-- ============================================================

local CATEGORIES = {
    { id = "all",        label = "All",               color = Color(0.95, 0.95, 0.95) },
    { id = "safes",      label = "Safes & Vaults",    color = Color(1, 0.85, 0) },
    { id = "loot",       label = "Cash & Valuables",  color = Color(0.1, 0.9, 0.4) },
    { id = "doors",      label = "Doors & Gates",     color = Color(0, 0.8, 1) },
    { id = "containers", label = "Containers & ATMs", color = Color(0.4, 0.9, 0.3) },
    { id = "breach",     label = "Breach & C4/Drills",color = Color(1, 0.3, 0.2) },
    { id = "keys",       label = "Keycards & Locks",  color = Color(1, 1, 0) },
    { id = "tech",       label = "Computers & Tech",  color = Color(0.2, 0.6, 1) },
    { id = "power",      label = "Power & Valves",    color = Color(1, 0.6, 0) },
    { id = "windows",    label = "Windows & Planks",  color = Color(0.8, 0.6, 0.4) },
    { id = "packages",   label = "Gage & Items",      color = Color(0.2, 0.9, 0.2) },
    { id = "misc",       label = "Misc",              color = Color(0.7, 0.7, 0.7) },
}

local CATEGORY_MAP = {}
for _, c in ipairs(CATEGORIES) do CATEGORY_MAP[c.id] = c end

local function clean_display_name(tid, tid_str, u_name)
    local name = nil

    if tid ~= "" then
        local td = tweak_data.interaction and tweak_data.interaction[tid]
        if td and td.text_id and managers.localization and managers.localization:exists(td.text_id) then
            local raw = managers.localization:text(td.text_id, {
                BTN_INTERACT = "",
                VALUE = "",
                MONEY = "",
                TIME = "",
                BAG = "",
                KEY = "",
                POSITION = "",
                NAME = "",
                TYPE = ""
            })
            if raw and raw ~= "" then
                name = raw
            end
        end
    end

    if not name or name == "" then
        if tid_str ~= "" then
            name = tid_str
        elseif u_name ~= "" and not u_name:find("^@id") then
            name = u_name
        else
            name = "Interactive Object"
        end
    end

    -- 1. Strip macros ($VALUE, $BTN_INTERACT, $1, etc.)
    name = name:gsub("%$[%w_]+", ""):gsub("%$[%d]+", "")

    -- 2. Strip standard action verb prefixes
    name = name:gsub("^[Hh]old%s+to%s+", "")
    name = name:gsub("^[Pp]ress%s+to%s+", "")
    name = name:gsub("^[Hh]old%s+", "")
    name = name:gsub("^[Pp]ress%s+", "")
    name = name:gsub("^[Tt]ake%s+", "")
    name = name:gsub("^[Oo]pen%s+", "")
    name = name:gsub("^[Pp]ick%s+up%s+", "")
    name = name:gsub("^[Hh]ack%s+", "")
    name = name:gsub("^[Uu]se%s+", "")
    name = name:gsub("^[Pp]lace%s+", "")
    name = name:gsub("^[Cc]ut%s+", "")
    name = name:gsub("^[Ss]tart%s+", "")
    name = name:gsub("^[Aa]ctivate%s+", "")
    name = name:gsub("^[Cc]onnect%s+", "")
    name = name:gsub("^[Gg]rab%s+", "")
    name = name:gsub("^[Dd]isable%s+", "")

    -- 3. Strip engine path and symbol prefixes
    name = name:gsub("hud_int_", ""):gsub("debug_interact_", "")
    name = name:gsub("gen_interactable_prop_", ""):gsub("gen_interactable_", "")
    name = name:gsub("gen_prop_", ""):gsub("gen_pku_", "")
    name = name:gsub("bnk_prop_", ""):gsub("com_prop_", ""):gsub("chas_prop_", "")
    name = name:gsub("units/.*/", "")

    -- 4. Replace separators
    name = name:gsub("_", " ")
    name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- 5. Capitalize
    name = name:gsub("(%a)([%w_']*)", function(f, r) return f:upper() .. r:lower() end)

    if name == "" or name == " " or name:find("^@Id") or name:find("^@id") then
        name = "Interactive Object"
    end

    -- 6. Precise Friendly Overrides for PD2 Interaction Objects
    local s = string.lower(name)
    if s:find("the safe") or s == "safe" or s:find("open safe") then
        name = "Safe"
    elseif s:find("titan") then
        name = "Titan Safe"
    elseif s:find("vault") or s:find("the vault") then
        name = "Bank Vault Door"
    elseif s:find("atm") then
        name = "ATM Machine"
    elseif s:find("deposit") then
        name = "Deposit Box"
    elseif s:find("crate") or s:find("weapon case") or s:find("loot box") then
        name = "Wooden Crate / Case"
    elseif s:find("fence") then
        name = "Cuttable Wire Fence"
    elseif s:find("lance") or s:find("thermal drill") then
        name = "Thermal Drill Point"
    elseif s:find("drill") then
        name = "Drill Placement Point"
    elseif s:find("c4") or s:find("shaped charge") then
        name = "C4 Placement Point"
    elseif s:find("saw") then
        name = "Saw Placement Point"
    elseif s:find("keycard") or s:find("key card") then
        name = "Keycard Reader"
    elseif s:find("money") or s:find("cash") then
        name = "Cash Bundle"
    elseif s:find("gold") then
        name = "Gold Bar"
    elseif s:find("diamond") or s:find("jewelry") then
        name = "Jewelry / Diamonds"
    elseif s:find("necklace") then
        name = "Necklace"
    elseif s:find("tiara") then
        name = "Tiara"
    elseif s:find("painting") then
        name = "Painting"
    elseif s:find("artifact") then
        name = "Artifact"
    elseif s:find("gage") or s:find("assignment") then
        name = "Gage Package"
    elseif s:find("computer") or s:find("laptop") or s:find("server") then
        name = "Computer / Server"
    elseif s:find("breaker") or s:find("fuse") or s:find("power") then
        name = "Circuit Breaker"
    elseif s:find("valve") then
        name = "Valve"
    elseif s:find("window") then
        name = "Window"
    elseif s:find("plank") or s:find("barricade") then
        name = "Wooden Planks"
    end

    return name
end

local function ClassifyInteractiveUnit(unit)
    if not (unit and alive(unit)) then
        return "Interactive Object", "misc", "Misc", Color(0.7, 0.7, 0.7)
    end

    local inter = unit.interaction and unit:interaction()
    local tid = inter and inter.tweak_data or ""
    local tid_str = string.lower(tostring(tid))

    local u_name = ""
    pcall(function()
        u_name = string.lower(tostring(unit:name() or ""))
    end)

    local u_key = unit:name():key()
    local cat_id = "misc"

    -- 1. Cash, Valuables & Loot (checked FIRST to avoid hex collision with breach/c4)
    if tid_str:find("money") or tid_str:find("cash") or tid_str:find("gold") or tid_str:find("diamond") or tid_str:find("jewelry") or tid_str:find("necklace") or tid_str:find("tiara") or tid_str:find("ring_band") or tid_str:find("painting") or tid_str:find("artifact") or tid_str:find("plate") or tid_str:find("safe_loot") or tid_str:find("loot") or (u_name:find("money") or u_name:find("gold") or u_name:find("diamond") or u_name:find("jewelry") or u_name:find("painting")) then
        cat_id = "loot"

    -- 2. Safes & Vaults (Bank Vaults, Titan Safes, Wall Safes, Office Safes, and Safe/Vault Drills)
    elseif VAULT_UNIT_KEYS[u_key] or tid_str:find("safe") or tid_str:find("titan") or tid_str:find("vault") or u_name:find("safe") or u_name:find("vault") or u_name:find("titan") then
        cat_id = "safes"

    -- 3. Breach, Drills, C4 & Thermite
    elseif tid_str:find("drill") or tid_str:find("saw") or tid_str:find("c4") or tid_str:find("shaped_charge") or tid_str:find("shaped_sharge") or tid_str:find("thermite") or tid_str:find("termite") or tid_str:find("cutter") or tid_str:find("lance") or u_name:find("drill") or u_name:find("c4") or u_name:find("thermite") or u_name:find("lance") then
        cat_id = "breach"

    -- 4. Containers, ATMs, Crates, Deposit Boxes & Registers
    elseif tid_str:find("atm") or tid_str:find("deposit") or tid_str:find("crate") or tid_str:find("container") or tid_str:find("weapon_case") or tid_str:find("cabinet") or tid_str:find("locker") or tid_str:find("register") or u_name:find("atm") or u_name:find("deposit") or u_name:find("crate") or u_name:find("container") then
        cat_id = "containers"

    -- 5. Doors, Gates, Cages & Fences
    elseif tid_str:find("door") or tid_str:find("gate") or tid_str:find("cage") or tid_str:find("cell") or tid_str:find("fence") or tid_str:find("shutter") or tid_str:find("hatch") or tid_str:find("trapdoor") or tid_str:find("pick_lock") or u_name:find("door") or u_name:find("gate") or u_name:find("fence") then
        cat_id = "doors"

    -- 6. Keycards, Readers & Codes
    elseif tid_str:find("keycard") or tid_str:find("key_") or tid_str:find("_key") or tid_str:find("card") or tid_str:find("numpad") or tid_str:find("timelock") or tid_str:find("passcode") or tid_str:find("code") or u_name:find("keycard") or u_name:find("timelock") then
        cat_id = "keys"

    -- 7. Computers & Tech (Hacking, Servers, Terminals)
    elseif tid_str:find("computer") or tid_str:find("hack") or tid_str:find("server") or tid_str:find("terminal") or tid_str:find("phone") or tid_str:find("scanner") or tid_str:find("keyboard") or tid_str:find("tablet") or tid_str:find("laptop") or tid_str:find("hdd") or u_name:find("computer") or u_name:find("server") then
        cat_id = "tech"

    -- 8. Power, Valves, Breakers & Switches
    elseif tid_str:find("breaker") or tid_str:find("power") or tid_str:find("fuse") or tid_str:find("switch") or tid_str:find("valve") or tid_str:find("rewire") or tid_str:find("pump") or tid_str:find("generator") or tid_str:find("water_tap") or tid_str:find("transformer") or u_name:find("breaker") or u_name:find("fuse") or u_name:find("valve") then
        cat_id = "power"

    -- 9. Windows & Barricades
    elseif tid_str:find("window") or tid_str:find("plank") or tid_str:find("barricade") or tid_str:find("board") or u_name:find("window") or u_name:find("plank") or u_name:find("barricade") then
        cat_id = "windows"

    -- 10. Gage Packages & Special Pickups
    elseif tid_str:find("gage") or tid_str:find("assignment") or tid_str:find("crowbar") or tid_str:find("evidence") or tid_str:find("document") or tid_str:find("patientpaper") or tid_str:find("vial") or tid_str:find("bottle") or tid_str:find("gasoline") or tid_str:find("acid") or tid_str:find("soda") or tid_str:find("chloride") or u_name:find("gage") or u_name:find("crowbar") then
        cat_id = "packages"
    end

    local cat_info = CATEGORY_MAP[cat_id] or CATEGORY_MAP["misc"]
    local clean_name = clean_display_name(tid, tid_str, u_name)

    return clean_name, cat_info.id, cat_info.label, cat_info.color
end

-- ============================================================
-- Interaction Execution Engine
-- ============================================================

local function instant_finish_drills_on_map()
    if not (NiceTrainer.Settings and NiceTrainer.Settings.instant_drilling) then return end
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) then
                if unit.timer_gui and unit:timer_gui() then
                    local tg = unit:timer_gui()
                    if tg and tg._started and not tg._done then
                        pcall(function()
                            if tg._jammed then tg:set_jammed(false) end
                            tg._current_timer = 0.001
                            if tg.done then tg:done() end
                        end)
                    end
                end
                if unit.digital_gui and unit:digital_gui() then
                    local dg = unit:digital_gui()
                    if dg and (dg._timer or 0) > 0 then
                        pcall(function()
                            dg._timer = 0.001
                            if alive(dg._unit) and dg._unit:damage() then
                                if dg._unit:damage():has_sequence("timer_done") then
                                    dg._unit:damage():run_sequence_simple("timer_done")
                                end
                                if dg._unit:damage():has_sequence("done") then
                                    dg._unit:damage():run_sequence_simple("done")
                                end
                            end
                        end)
                    end
                end
            end
        end
    end)
end

local function _interact_with_set(hash_set, need_equipment)
    local player = managers.player and managers.player:player_unit()
    if not player then return 0 end

    local player_state = managers.player.current_state and managers.player:current_state()
    local was_mask_off = (player_state == "mask_off")
    if was_mask_off then
        managers.player:set_player_state("clean")
    end

    local orig_base_has_required_upgrade, orig_base_has_required_deployable, orig_base_can_interact
    local orig_player_remove_equipment, orig_player_remove_special

    if need_equipment then
        orig_base_has_required_upgrade = BaseInteractionExt._has_required_upgrade
        orig_base_has_required_deployable = BaseInteractionExt._has_required_deployable
        orig_base_can_interact = BaseInteractionExt.can_interact

        function BaseInteractionExt:_has_required_upgrade() return true end
        function BaseInteractionExt:_has_required_deployable() return true end
        function BaseInteractionExt:can_interact() return true end

        orig_player_remove_equipment = PlayerManager.remove_equipment
        orig_player_remove_special = PlayerManager.remove_special

        function PlayerManager:remove_equipment() end
        function PlayerManager:remove_special() end
    end

    local units_snapshot = {}
    for k, v in pairs(managers.interaction._interactive_units or {}) do
        units_snapshot[k] = v
    end

    local count = 0
    for _, unit in pairs(units_snapshot) do
        if alive(unit) then
            pcall(function()
                local key = tostring(unit:name():key())
                if hash_set[key] then
                    unit:interaction():interact(player)
                    count = count + 1
                end
            end)
        end
    end

    if need_equipment then
        BaseInteractionExt._has_required_upgrade = orig_base_has_required_upgrade
        BaseInteractionExt._has_required_deployable = orig_base_has_required_deployable
        BaseInteractionExt.can_interact = orig_base_can_interact
        PlayerManager.remove_equipment = orig_player_remove_equipment
        PlayerManager.remove_special = orig_player_remove_special
    end

    if was_mask_off then
        managers.player:set_player_state("mask_off")
    end

    return count
end

-- Legacy helper: interact by interaction key name in interactions.json
local function interact_by_key(key_name, label, need_equipment)
    local db = _load_interactions()
    local list = db and db[key_name]
    if not list or #list == 0 then
        return 0
    end
    return _interact_with_set(_to_set(list), need_equipment)
end

-- Legacy helper: pattern-matching fallback
local function interact_with_patterns(patterns, label, need_equipment)
    local player = managers.player and managers.player:player_unit()
    if not player then return 0 end

    local player_state = managers.player.current_state and managers.player:current_state()
    local was_mask_off = (player_state == "mask_off")
    if was_mask_off then
        managers.player:set_player_state("clean")
    end

    local objects = {}
    if managers.interaction and managers.interaction._interactive_units then
        for _, v in pairs(managers.interaction._interactive_units) do
            if alive(v) and v.interaction and v:interaction() then
                pcall(function()
                    local inter = v:interaction()
                    local td_id = inter.tweak_data
                    local td_str = td_id and string.lower(tostring(td_id)) or ""
                    local u_n = ""
                    pcall(function() u_n = string.lower(tostring(v:name() or "")) end)
                    for _, pattern in ipairs(patterns) do
                        local p = string.lower(pattern)
                        if (td_str ~= "" and td_str:find(p, 1, true)) or (u_n ~= "" and u_n:find(p, 1, true)) then
                            table.insert(objects, v)
                            break
                        end
                    end
                end)
            end
        end
    end

    local orig_base_has_required_upgrade, orig_base_has_required_deployable, orig_base_can_interact
    local orig_player_remove_equipment, orig_player_remove_special

    if need_equipment then
        orig_base_has_required_upgrade = BaseInteractionExt._has_required_upgrade
        orig_base_has_required_deployable = BaseInteractionExt._has_required_deployable
        orig_base_can_interact = BaseInteractionExt.can_interact

        function BaseInteractionExt:_has_required_upgrade() return true end
        function BaseInteractionExt:_has_required_deployable() return true end
        function BaseInteractionExt:can_interact() return true end

        orig_player_remove_equipment = PlayerManager.remove_equipment
        orig_player_remove_special = PlayerManager.remove_special

        function PlayerManager:remove_equipment() end
        function PlayerManager:remove_special() end
    end

    local count = 0
    for _, unit in ipairs(objects) do
        if alive(unit) then
            pcall(function()
                if unit.interaction and unit:interaction() then
                    local inter = unit:interaction()
                    if inter.interact_start then pcall(inter.interact_start, inter, player) end
                    inter:interact(player)
                    count = count + 1
                end
            end)
        end
    end

    if need_equipment then
        BaseInteractionExt._has_required_upgrade = orig_base_has_required_upgrade
        BaseInteractionExt._has_required_deployable = orig_base_has_required_deployable
        BaseInteractionExt.can_interact = orig_base_can_interact
        PlayerManager.remove_equipment = orig_player_remove_equipment
        PlayerManager.remove_special = orig_player_remove_special
    end

    if was_mask_off then
        managers.player:set_player_state("mask_off")
    end

    return count
end

-- Legacy mass unlock execution: acts exactly as the legacy system (UT6 hash matching + pattern matching + bypass)
local function execute_legacy_mass_interaction(cat_filter)
    local total_count = 0

    if not cat_filter or cat_filter == "all" then
        total_count = total_count + interact_by_key("open-doors", "doors", false)
        total_count = total_count + interact_by_key("open-windows", "windows", false)
        total_count = total_count + interact_by_key("open-deposit-boxes", "deposit boxes", false)
        total_count = total_count + interact_by_key("open-containers", "containers", false)
        total_count = total_count + interact_by_key("open-crates", "crates", true)
        total_count = total_count + interact_by_key("open-atms", "ATMs", true)
        total_count = total_count + interact_by_key("cut-fences", "fences", true)
        total_count = total_count + interact_by_key("hack-computers", "computers", false)
        total_count = total_count + interact_by_key("use-keycards", "keycard doors", true)
        total_count = total_count + interact_by_key("place-drills", "drills", true)
        total_count = total_count + interact_by_key("place-shaped-charges", "shaped charges", true)
        total_count = total_count + interact_by_key("pick-up-packages", "packages", false)
        total_count = total_count + interact_by_key("barricade-windows", "windows", true)

        -- Heist-specific pattern fallbacks (ECMs, C4, Thermite, Lockpicks)
        total_count = total_count + interact_with_patterns({"ecm", "requires_ecm_jammer", "ecm_jammer"}, "ECM doors", true)
        total_count = total_count + interact_with_patterns({"c4", "place_c4", "c4_charge", "thermite_c4", "c4_stackable", "c4_x"}, "C4", true)
        total_count = total_count + interact_with_patterns({"thermite", "termite", "thermite_paste", "place_thermite", "thermite_door", "thermite_apply"}, "Termite", true)
        total_count = total_count + interact_with_patterns({"pick_lock", "lockpick", "keyhole"}, "Lockpicks", false)

        -- Safes, Vaults & Mission Devices
        pcall(function()
            for _, u in pairs(World:find_units_quick("all")) do
                if alive(u) then
                    local u_n = ""
                    pcall(function() u_n = string.lower(tostring(u:name() or "")) end)
                    local is_v = VAULT_UNIT_KEYS[u:name():key()] or u_n:find("vault") or u_n:find("safe") or u_n:find("titan")
                    if not is_v and u:damage() then
                        local dmg = u:damage()
                        is_v = dmg:has_sequence("open_vault") or dmg:has_sequence("open_the_vault") or dmg:has_sequence("open_safe") or dmg:has_sequence("open_titan") or dmg:has_sequence("door_opened")
                    end
                    if is_v then
                        if interact_single_unit(u) then total_count = total_count + 1 end
                    end
                end
            end
        end)
        instant_finish_drills_on_map()

    elseif cat_filter == "doors" then
        total_count = total_count + interact_by_key("open-doors", "doors", false)
        total_count = total_count + interact_by_key("cut-fences", "fences", true)
        total_count = total_count + interact_with_patterns({"door", "gate", "fence", "cage", "cell", "shutter"}, "Doors", false)
        total_count = total_count + interact_with_patterns({"pick_lock", "lockpick"}, "Locks", false)

    elseif cat_filter == "safes" then
        total_count = total_count + interact_by_key("place-drills", "drills", true)
        total_count = total_count + interact_by_key("place-shaped-charges", "shaped charges", true)
        pcall(function()
            for _, u in pairs(World:find_units_quick("all")) do
                if alive(u) then
                    local u_n = ""
                    pcall(function() u_n = string.lower(tostring(u:name() or "")) end)
                    local is_v = VAULT_UNIT_KEYS[u:name():key()] or u_n:find("vault") or u_n:find("safe") or u_n:find("titan")
                    if not is_v and u:damage() then
                        local dmg = u:damage()
                        is_v = dmg:has_sequence("open_vault") or dmg:has_sequence("open_the_vault") or dmg:has_sequence("open_safe") or dmg:has_sequence("open_titan") or dmg:has_sequence("door_opened")
                    end
                    if is_v then
                        if interact_single_unit(u) then total_count = total_count + 1 end
                    end
                end
            end
        end)
        instant_finish_drills_on_map()

    elseif cat_filter == "containers" then
        total_count = total_count + interact_by_key("open-atms", "ATMs", true)
        total_count = total_count + interact_by_key("open-deposit-boxes", "deposit boxes", false)
        total_count = total_count + interact_by_key("open-crates", "crates", true)
        total_count = total_count + interact_by_key("open-containers", "containers", false)
        total_count = total_count + interact_with_patterns({"atm", "deposit", "crate", "container", "locker", "cabinet", "weapon_case", "register"}, "Containers", true)

    elseif cat_filter == "breach" then
        total_count = total_count + interact_by_key("place-drills", "drills", true)
        total_count = total_count + interact_by_key("place-shaped-charges", "shaped charges", true)
        total_count = total_count + interact_with_patterns({"c4", "place_c4", "c4_charge", "thermite_c4", "c4_stackable", "c4_x"}, "C4", true)
        total_count = total_count + interact_with_patterns({"thermite", "termite", "thermite_paste", "place_thermite", "thermite_door", "thermite_apply"}, "Termite", true)
        total_count = total_count + interact_with_patterns({"drill", "saw", "cutter", "lance"}, "Breaches", true)
        instant_finish_drills_on_map()

    elseif cat_filter == "keys" then
        total_count = total_count + interact_by_key("use-keycards", "keycards", true)
        total_count = total_count + interact_with_patterns({"keycard", "key_", "_key", "card", "numpad", "timelock", "passcode"}, "Keycards & Codes", true)

    elseif cat_filter == "tech" then
        total_count = total_count + interact_by_key("hack-computers", "computers", false)
        total_count = total_count + interact_with_patterns({"computer", "hack", "server", "terminal", "phone", "scanner", "keyboard", "tablet", "laptop", "hdd"}, "Computers", false)

    elseif cat_filter == "power" then
        total_count = total_count + interact_with_patterns({"breaker", "power", "fuse", "switch", "valve", "rewire", "pump", "generator", "water_tap", "transformer"}, "Power & Valves", false)

    elseif cat_filter == "windows" then
        total_count = total_count + interact_by_key("open-windows", "windows", false)
        total_count = total_count + interact_by_key("barricade-windows", "windows", true)
        total_count = total_count + interact_with_patterns({"window", "plank", "barricade", "board"}, "Windows", true)

    elseif cat_filter == "packages" then
        total_count = total_count + interact_by_key("pick-up-packages", "packages", false)
        total_count = total_count + interact_with_patterns({"gage", "assignment", "crowbar", "evidence", "document", "vial", "gasoline", "acid", "soda", "chloride"}, "Packages", false)

    elseif cat_filter == "loot" then
        total_count = total_count + interact_with_patterns({"money", "cash", "gold", "diamond", "jewelry", "necklace", "tiara", "ring_band", "painting", "artifact", "plate", "safe_loot", "loot"}, "Loot", false)
    end

    return total_count
end

local function interact_single_unit(unit)
    if not (unit and alive(unit)) then return false end
    local player = managers.player and managers.player:player_unit()
    if not player then return false end

    local player_state = managers.player.current_state and managers.player:current_state()
    local was_mask_off = (player_state == "mask_off")
    if was_mask_off then
        managers.player:set_player_state("clean")
    end

    local orig_base_has_required_upgrade = BaseInteractionExt._has_required_upgrade
    local orig_base_has_required_deployable = BaseInteractionExt._has_required_deployable
    local orig_base_interact_blocked = BaseInteractionExt._interact_blocked
    local orig_base_can_interact = BaseInteractionExt.can_interact
    local orig_base_can_select = BaseInteractionExt.can_select

    function BaseInteractionExt:_has_required_upgrade() return true end
    function BaseInteractionExt:_has_required_deployable() return true end
    function BaseInteractionExt:_interact_blocked() return false end
    function BaseInteractionExt:can_interact() return true end
    function BaseInteractionExt:can_select() return true end

    local orig_player_remove_equipment = PlayerManager.remove_equipment
    local orig_player_remove_special = PlayerManager.remove_special

    function PlayerManager:remove_equipment() end
    function PlayerManager:remove_special() end

    local ok = false
    pcall(function()
        if unit.interaction and unit:interaction() then
            local inter = unit:interaction()
            if inter.interact_start then pcall(inter.interact_start, inter, player) end
            inter:interact(player)
            ok = true
        end

        -- Finish attached timer/drill if applicable
        if unit.timer_gui and unit:timer_gui() then
            local tg = unit:timer_gui()
            if tg and tg._started and not tg._done then
                pcall(function()
                    if tg._jammed then tg:set_jammed(false) end
                    tg._current_timer = 0.001
                    if tg.done then tg:done() end
                end)
                ok = true
            end
        end

        -- Sequence triggers for physical doors, vaults, safes, and barriers
        if unit:damage() then
            local dmg = unit:damage()
            local sequences = {
                "open", "open_door", "open_vault", "open_the_vault", "door_open",
                "open_safe", "open_titan", "safe_open", "vault_open",
                "drill_done", "lance_done", "timer_done", "done", "unlocked", "complete",
                "explode", "saw_done", "cut", "unbarricade",
                "door_opened", "explode_door", "all_drill_placed", "all_c4_placed", "activate"
            }
            for _, seq in ipairs(sequences) do
                if dmg:has_sequence(seq) then
                    pcall(dmg.run_sequence_simple, dmg, seq)
                    ok = true
                end
            end
        end
    end)

    BaseInteractionExt._has_required_upgrade = orig_base_has_required_upgrade
    BaseInteractionExt._has_required_deployable = orig_base_has_required_deployable
    BaseInteractionExt._interact_blocked = orig_base_interact_blocked
    BaseInteractionExt.can_interact = orig_base_can_interact
    BaseInteractionExt.can_select = orig_base_can_select
    PlayerManager.remove_equipment = orig_player_remove_equipment
    PlayerManager.remove_special = orig_player_remove_special

    if was_mask_off then
        managers.player:set_player_state("mask_off")
    end

    return ok
end

local function get_map_interactive_units(category_filter_id)
    local list = {}
    local seen = {}
    local player = managers.player and managers.player:player_unit()
    local p_pos = (player and alive(player)) and player:position() or Vector3()

    -- 1. Standard Interactive Units
    if managers.interaction and managers.interaction._interactive_units then
        for _, unit in pairs(managers.interaction._interactive_units) do
            if alive(unit) and unit:enabled() and unit.interaction and unit:interaction() and not seen[unit:key()] then
                local inter = unit:interaction()
                local is_active = inter:active() and not (inter.disabled and inter:disabled())
                if is_active then
                    seen[unit:key()] = true
                    local name, cat_id, cat_label, cat_color = ClassifyInteractiveUnit(unit)
                    local match = (not category_filter_id or category_filter_id == "all" or cat_id == category_filter_id)
                    -- For 'safes' category, also include active drill interactions placed on safes/vaults
                    if not match and category_filter_id == "safes" and (cat_id == "breach" or cat_id == "safes") then
                        local tid_str = string.lower(tostring(inter.tweak_data or ""))
                        if tid_str:find("drill") or tid_str:find("safe") or tid_str:find("vault") or tid_str:find("titan") or VAULT_UNIT_KEYS[unit:name():key()] then
                            match = true
                        end
                    end
                    if match then
                        local dist = math.floor(mvector3.distance(p_pos, unit:position()) / 100)
                        table.insert(list, {
                            unit      = unit,
                            name      = name,
                            cat_id    = cat_id,
                            category  = cat_label,
                            color     = cat_color,
                            dist      = dist
                        })
                    end
                end
            end
        end
    end

    -- 2. Physical Vault Doors, Titan Safes, and Mission-Scripted Vaults
    if not category_filter_id or category_filter_id == "all" or category_filter_id == "safes" then
        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) and not seen[unit:key()] then
                local is_vault_target = false
                local vault_label = "Bank Vault Door"

                local u_name = ""
                pcall(function() u_name = string.lower(tostring(unit:name() or "")) end)
                local u_key = unit:name():key()

                if VAULT_UNIT_KEYS[u_key] or u_name:find("vault") or u_name:find("safe") or u_name:find("titan") then
                    is_vault_target = true
                    if u_name:find("titan") then vault_label = "Titan Safe"
                    elseif u_name:find("safe") then vault_label = "Safe"
                    elseif u_name:find("deposit") then vault_label = "Deposit Box"
                    else vault_label = "Bank Vault Door" end
                elseif unit:damage() then
                    local dmg = unit:damage()
                    if dmg:has_sequence("open_vault") or dmg:has_sequence("open_the_vault") or dmg:has_sequence("vault_open") then
                        is_vault_target = true
                        vault_label = "Bank Vault Door"
                    elseif dmg:has_sequence("open_safe") or dmg:has_sequence("open_titan") or dmg:has_sequence("safe_open") then
                        is_vault_target = true
                        vault_label = "Safe"
                    elseif dmg:has_sequence("door_opened") or dmg:has_sequence("timer_done") then
                        if unit:base() and unit:base()._devices and unit:base()._devices.drill then
                            is_vault_target = true
                            vault_label = "Bank Vault Door"
                        end
                    end
                end

                if is_vault_target then
                    seen[unit:key()] = true
                    local dist = math.floor(mvector3.distance(p_pos, unit:position()) / 100)
                    table.insert(list, {
                        unit      = unit,
                        name      = vault_label,
                        cat_id    = "safes",
                        category  = "Safes & Vaults",
                        color     = Color(1, 0.85, 0),
                        dist      = dist
                    })
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- Check if any matching active units exist on map (used for dynamic menu display)
local function has_category_units_on_map(category_id)
    if not NiceTrainer:IsInHeist() then return true end
    local items = get_map_interactive_units(category_id)
    return #items > 0
end

-- ============================================================
-- Category-Specific Modal Builder
-- ============================================================

local C_MODAL_W = 600
local C_MODAL_H = 550
local C_ROW_H   = 38

local function ShowCategoryModal(title, category_id, interact_all_label)
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Only available during heist.")
        return
    end

    local items = get_map_interactive_units(category_id)

    NiceTrainer:ShowCustomModal(title, C_MODAL_W, C_MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        local count_txt = m:text({
            text = string.format("Found %d active objects on this heist.", #items),
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(0.8, 0.8, 0.8), x = 18, y = 52, w = C_MODAL_W - 36, layer = 2
        })

        local btn_w1, btn_w2 = 180, 100
        local btn_h = 28
        local btn_y = 78

        -- Interact All Button (Uses robust legacy hash-matching + fallback)
        local all_btn = m:panel({ x = 18, y = btn_y, w = btn_w1, h = btn_h, layer = 2 })
        local all_bg  = all_btn:rect({ color = Color(0.2, 0.8, 0.4), alpha = 0.25, layer = 0 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), x = btn_w1 - 1, w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), h = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), y = btn_h - 1, h = 1, layer = 1 })
        all_btn:text({
            text = interact_all_label or "Interact All",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            align = "center", vertical = "center", color = Color.white, layer = 2
        })

        -- Refresh Button
        local ref_btn = m:panel({ x = 18 + btn_w1 + 10, y = btn_y, w = btn_w2, h = btn_h, layer = 2 })
        local ref_bg  = ref_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w2 - 1, w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        ref_btn:text({
            text = "Refresh", font = "fonts/font_medium_shadow_mf", font_size = 13,
            align = "center", vertical = "center", color = Color.white, layer = 2
        })

        local sep_y = 114
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 18, y = sep_y, w = C_MODAL_W - 36, h = 1, layer = 2 })

        -- Scrollable List
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = C_MODAL_W, h = C_MODAL_H - scroll_top - 8, layer = 2 })

        local function build_list()
            if not alive(scroll_wrap) then return end
            scroll_wrap:clear()

            items = get_map_interactive_units(category_id)
            if alive(count_txt) then
                count_txt:set_text(string.format("Found %d active objects on this heist.", #items))
            end

            local canvas_h = 8 + (#items * (C_ROW_H + 4))
            local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = C_MODAL_W, h = math.max(canvas_h, C_ROW_H), layer = 1 })
            top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

            local ROW_W = C_MODAL_W - 16
            local y = 8

            if #items == 0 then
                canvas:text({
                    text = "No active objects found for this category on the current heist.",
                    font = "fonts/font_medium_shadow_mf", font_size = 15,
                    color = Color(0.6, 0.6, 0.6), x = 18, y = y, layer = 2
                })
                return
            end

            for _, it in ipairs(items) do
                local cur_it = it
                local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = C_ROW_H, layer = 2 })
                row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

                -- Category color stripe
                row:rect({ color = cur_it.color, alpha = 0.9, x = 8, y = 9, w = 4, h = 20, layer = 1 })

                -- Name + Category tag
                row:text({
                    text = cur_it.name,
                    font = "fonts/font_medium_shadow_mf", font_size = 15,
                    x = 20, y = 3, color = Color(0.95, 0.95, 0.95), layer = 1
                })
                row:text({
                    text = string.upper(cur_it.category),
                    font = "fonts/font_medium_shadow_mf", font_size = 11,
                    x = 20, y = 20, color = cur_it.color, layer = 1
                })

                -- Distance
                row:text({
                    text = string.format("%dm", cur_it.dist),
                    font = "fonts/font_medium_shadow_mf", font_size = 14,
                    x = ROW_W - 165, w = 55, h = C_ROW_H,
                    align = "right", vertical = "center", color = Color(0.6, 0.6, 0.6), layer = 1
                })

                -- [ Interact ] Button
                local act_w, act_h = 90, 24
                local act_btn = row:panel({ x = ROW_W - act_w - 8, y = 7, w = act_w, h = act_h, layer = 2 })
                local act_bg  = act_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.25, layer = 0 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), x = act_w - 1, w = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), y = act_h - 1, h = 1, layer = 1 })
                act_btn:text({
                    text = "Interact", font = "fonts/font_medium_shadow_mf", font_size = 13,
                    w = act_w, h = act_h, align = "center", vertical = "center",
                    color = Color.white, layer = 2
                })

                table.insert(top_modal.elements, {
                    panel = act_btn,
                    inside = function(self, mx, my)
                        if not (alive(scroll_wrap) and alive(act_btn)) then return false end
                        return scroll_wrap:inside(mx, my) and act_btn:inside(mx, my)
                    end,
                    on_hover = function(self, hovered)
                        if alive(act_bg) then act_bg:set_alpha(hovered and 0.5 or 0.25) end
                    end,
                    on_click = function(self)
                        if alive(cur_it.unit) then
                            if interact_single_unit(cur_it.unit) then
                                NiceTrainer:Toast("Interacted with " .. cur_it.name .. "!")
                            end
                        end
                        build_list()
                    end
                })

                y = y + C_ROW_H + 4
            end
        end

        -- Interact All Click (Legacy hashes + listed unit fallback + instant drills)
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
                -- 1. Run legacy mass unlock
                local count = execute_legacy_mass_interaction(category_id)

                -- 2. Fallback on all listed units
                for _, it in ipairs(items) do
                    if alive(it.unit) then
                        if interact_single_unit(it.unit) then count = count + 1 end
                    end
                end

                if category_id == "safes" or category_id == "all" then
                    instant_finish_drills_on_map()
                end

                NiceTrainer:Toast(string.format("Interacted with %d objects in %s!", count, title))
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
                NiceTrainer:Toast("Refreshed!")
            end
        })

        build_list()
    end)
end

-- ============================================================
-- Multi-Tab World Objects Explorer Modal
-- ============================================================

local W_MODAL_W = 720
local W_MODAL_H = 580
local W_ROW_H   = 38

local function ShowWorldObjectsModal()
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Only available during heist.")
        return
    end

    local current_tab = "all"
    local items = get_map_interactive_units("all")

    NiceTrainer:ShowCustomModal("World Objects Explorer", W_MODAL_W, W_MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        local count_txt = m:text({
            text = string.format("Found %d interactive objects on the map.", #items),
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(0.8, 0.8, 0.8), x = 18, y = 48, w = W_MODAL_W - 36, layer = 2
        })

        -- Top action buttons
        local btn_h = 26
        local btn_y = 68

        -- Interact All Visible Button (Uses robust legacy mass unlock + fallback)
        local all_btn = m:panel({ x = 18, y = btn_y, w = 160, h = btn_h, layer = 2 })
        local all_bg  = all_btn:rect({ color = Color(0.2, 0.8, 0.4), alpha = 0.25, layer = 0 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), x = 159, w = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), h = 1, layer = 1 })
        all_btn:rect({ color = Color(0.2, 0.8, 0.4), y = btn_h - 1, h = 1, layer = 1 })
        all_btn:text({ text = "Interact All (Visible)", font = "fonts/font_medium_shadow_mf", font_size = 13, align = "center", vertical = "center", color = Color.white, layer = 2 })

        -- Open Safes & Doors Shortcut
        local safe_btn = m:panel({ x = 18 + 160 + 10, y = btn_y, w = 160, h = btn_h, layer = 2 })
        local safe_bg  = safe_btn:rect({ color = Color(1, 0.85, 0), alpha = 0.25, layer = 0 })
        safe_btn:rect({ color = Color(1, 0.85, 0), w = 1, layer = 1 })
        safe_btn:rect({ color = Color(1, 0.85, 0), x = 159, w = 1, layer = 1 })
        safe_btn:rect({ color = Color(1, 0.85, 0), h = 1, layer = 1 })
        safe_btn:rect({ color = Color(1, 0.85, 0), y = btn_h - 1, h = 1, layer = 1 })
        safe_btn:text({ text = "Open Safes & Doors", font = "fonts/font_medium_shadow_mf", font_size = 13, align = "center", vertical = "center", color = Color.white, layer = 2 })

        -- Refresh Button
        local ref_btn = m:panel({ x = 18 + 160 + 10 + 160 + 10, y = btn_y, w = 90, h = btn_h, layer = 2 })
        local ref_bg  = ref_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), x = 89, w = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        ref_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        ref_btn:text({ text = "Refresh", font = "fonts/font_medium_shadow_mf", font_size = 13, align = "center", vertical = "center", color = Color.white, layer = 2 })

        -- Category Filter Tabs Bar
        local tab_bar_y = 100
        local tab_bar = m:panel({ x = 18, y = tab_bar_y, w = W_MODAL_W - 36, h = 54, layer = 2 })

        local tab_buttons = {}
        local build_list_func = nil

        local function render_filter_tabs()
            tab_bar:clear()
            tab_buttons = {}

            local cur_x = 0
            local cur_y = 0
            local row_h = 24
            local max_w = W_MODAL_W - 36

            for _, cat in ipairs(CATEGORIES) do
                local label = cat.label
                local is_active = (current_tab == cat.id)
                local btn_len = math.max(string.len(label) * 8 + 14, 40)

                if cur_x + btn_len > max_w then
                    cur_x = 0
                    cur_y = cur_y + row_h + 3
                end

                local p = tab_bar:panel({ x = cur_x, y = cur_y, w = btn_len, h = row_h, layer = 2 })
                local bg = p:rect({ color = is_active and cat.color or Color.white, alpha = is_active and 0.3 or 0.08, layer = 0 })
                p:rect({ color = cat.color, alpha = is_active and 0.9 or 0.25, w = 1, layer = 1 })
                p:rect({ color = cat.color, alpha = is_active and 0.9 or 0.25, x = btn_len - 1, w = 1, layer = 1 })
                p:rect({ color = cat.color, alpha = is_active and 0.9 or 0.25, h = 1, layer = 1 })
                p:rect({ color = cat.color, alpha = is_active and 0.9 or 0.25, y = row_h - 1, h = 1, layer = 1 })
                p:text({
                    text = label, font = "fonts/font_medium_shadow_mf", font_size = 12,
                    w = btn_len, h = row_h, align = "center", vertical = "center",
                    color = is_active and Color.white or Color(0.75, 0.75, 0.75), layer = 2
                })

                table.insert(top_modal.elements, {
                    panel = p,
                    inside = function(self, mx, my)
                        if not (alive(tab_bar) and alive(p)) then return false end
                        return tab_bar:inside(mx, my) and p:inside(mx, my)
                    end,
                    on_hover = function(self, hovered)
                        if alive(bg) and not (current_tab == cat.id) then
                            bg:set_alpha(hovered and 0.2 or 0.08)
                        end
                    end,
                    on_click = function(self)
                        current_tab = cat.id
                        render_filter_tabs()
                        if build_list_func then build_list_func() end
                    end
                })

                cur_x = cur_x + btn_len + 6
            end
        end

        local sep_y = tab_bar_y + 58
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 18, y = sep_y, w = W_MODAL_W - 36, h = 1, layer = 2 })

        -- Scrollable List
        local scroll_top  = sep_y + 6
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = W_MODAL_W, h = W_MODAL_H - scroll_top - 8, layer = 2 })

        local function build_list()
            if not alive(scroll_wrap) then return end
            scroll_wrap:clear()

            items = get_map_interactive_units(current_tab)
            if alive(count_txt) then
                count_txt:set_text(string.format("Found %d interactive objects on the map (Filter: %s).", #items, (CATEGORY_MAP[current_tab] and CATEGORY_MAP[current_tab].label or "All")))
            end

            local canvas_h = 8 + (#items * (W_ROW_H + 4))
            local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = W_MODAL_W, h = math.max(canvas_h, W_ROW_H), layer = 1 })
            top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

            local ROW_W = W_MODAL_W - 16
            local y = 8

            if #items == 0 then
                canvas:text({
                    text = "No interactive objects currently active under this filter.",
                    font = "fonts/font_medium_shadow_mf", font_size = 15,
                    color = Color(0.6, 0.6, 0.6), x = 18, y = y, layer = 2
                })
                return
            end

            for _, it in ipairs(items) do
                local cur_it = it
                local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = W_ROW_H, layer = 2 })
                row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

                -- Category color stripe
                row:rect({ color = cur_it.color, alpha = 0.9, x = 8, y = 9, w = 4, h = 20, layer = 1 })

                -- Name + Category tag
                row:text({
                    text = cur_it.name,
                    font = "fonts/font_medium_shadow_mf", font_size = 15,
                    x = 20, y = 3, color = Color(0.95, 0.95, 0.95), layer = 1
                })
                row:text({
                    text = string.upper(cur_it.category),
                    font = "fonts/font_medium_shadow_mf", font_size = 11,
                    x = 20, y = 20, color = cur_it.color, layer = 1
                })

                -- Distance
                row:text({
                    text = string.format("%dm", cur_it.dist),
                    font = "fonts/font_medium_shadow_mf", font_size = 14,
                    x = ROW_W - 165, w = 55, h = W_ROW_H,
                    align = "right", vertical = "center", color = Color(0.6, 0.6, 0.6), layer = 1
                })

                -- [ Interact ] Button
                local act_w, act_h = 90, 24
                local act_btn = row:panel({ x = ROW_W - act_w - 8, y = 7, w = act_w, h = act_h, layer = 2 })
                local act_bg  = act_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.25, layer = 0 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), x = act_w - 1, w = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
                act_btn:rect({ color = Color(0.2, 0.6, 1.0), y = act_h - 1, h = 1, layer = 1 })
                act_btn:text({
                    text = "Interact", font = "fonts/font_medium_shadow_mf", font_size = 13,
                    w = act_w, h = act_h, align = "center", vertical = "center",
                    color = Color.white, layer = 2
                })

                table.insert(top_modal.elements, {
                    panel = act_btn,
                    inside = function(self, mx, my)
                        if not (alive(scroll_wrap) and alive(act_btn)) then return false end
                        return scroll_wrap:inside(mx, my) and act_btn:inside(mx, my)
                    end,
                    on_hover = function(self, hovered)
                        if alive(act_bg) then act_bg:set_alpha(hovered and 0.5 or 0.25) end
                    end,
                    on_click = function(self)
                        if alive(cur_it.unit) then
                            if interact_single_unit(cur_it.unit) then
                                NiceTrainer:Toast("Interacted with " .. cur_it.name .. "!")
                            end
                        end
                        build_list()
                    end
                })

                y = y + W_ROW_H + 4
            end
        end

        build_list_func = build_list

        -- Interact All Visible Click (Uses legacy hash unlock + fallback + instant drills)
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
                local count = execute_legacy_mass_interaction(current_tab)
                for _, it in ipairs(items) do
                    if alive(it.unit) then
                        if interact_single_unit(it.unit) then count = count + 1 end
                    end
                end
                if current_tab == "safes" or current_tab == "all" then
                    instant_finish_drills_on_map()
                end
                NiceTrainer:Toast(string.format("Interacted with %d objects!", count))
                build_list()
            end
        })

        -- Open Safes & Doors Shortcut Click
        table.insert(top_modal.elements, {
            panel = safe_btn,
            inside = function(self, mx, my)
                if not alive(safe_btn) then return false end
                return safe_btn:inside(mx, my)
            end,
            on_hover = function(self, hovered)
                if alive(safe_bg) then safe_bg:set_alpha(hovered and 0.5 or 0.25) end
            end,
            on_click = function(self)
                local count = execute_legacy_mass_interaction("safes") + execute_legacy_mass_interaction("doors")
                local s_items = get_map_interactive_units("safes")
                local d_items = get_map_interactive_units("doors")
                for _, it in ipairs(s_items) do
                    if alive(it.unit) and interact_single_unit(it.unit) then count = count + 1 end
                end
                for _, it in ipairs(d_items) do
                    if alive(it.unit) and interact_single_unit(it.unit) then count = count + 1 end
                end
                instant_finish_drills_on_map()
                NiceTrainer:Toast(string.format("Opened %d safes and doors!", count))
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
                NiceTrainer:Toast("Refreshed!")
            end
        })

        render_filter_tabs()
        build_list()
    end)
end

-- ============================================================
-- Registered Actions (Modals for Each Category)
-- ============================================================

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "World Objects Explorer",
    action_btn_text = "Open Explorer...",
    tooltip         = "Opens the complete interactive explorer showing all active objects on the map with category filters, distances, and remote interaction.",
    callback        = ShowWorldObjectsModal,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Safes & Vaults",
    action_btn_text = "Open...",
    tooltip         = "Lists and unlocks all bank vaults, titan safes, and wall safes on this map.",
    check_available = function() return has_category_units_on_map("safes") end,
    callback        = function() ShowCategoryModal("Safes & Vaults", "safes", "Open All Safes & Vaults") end,
})


NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Doors & Gates",
    action_btn_text = "Open...",
    tooltip         = "Lists and opens all doors, security gates, cages, cells, and fences on this map.",
    check_available = function() return has_category_units_on_map("doors") end,
    callback        = function() ShowCategoryModal("Doors & Gates", "doors", "Open All Doors & Gates") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Containers & ATMs",
    action_btn_text = "Open...",
    tooltip         = "Lists and opens all ATMs, deposit boxes, weapon crates, and lockers on this map.",
    check_available = function() return has_category_units_on_map("containers") end,
    callback        = function() ShowCategoryModal("Containers & ATMs", "containers", "Open All Containers & ATMs") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Breach, Drills & C4",
    action_btn_text = "Open...",
    tooltip         = "Lists and places drills, saws, C4 shaped charges, and thermite on all targets.",
    check_available = function() return has_category_units_on_map("breach") end,
    callback        = function() ShowCategoryModal("Breach, Drills & C4", "breach", "Place / Trigger All Breaches") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Keycards & Locks",
    action_btn_text = "Open...",
    tooltip         = "Lists and activates all keycard readers, timelock panels, and keyholes.",
    check_available = function() return has_category_units_on_map("keys") end,
    callback        = function() ShowCategoryModal("Keycards & Locks", "keys", "Use All Keycards & Codes") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Computers & Tech",
    action_btn_text = "Open...",
    tooltip         = "Lists and hacks all computers, laptops, server terminals, and keypads.",
    check_available = function() return has_category_units_on_map("tech") end,
    callback        = function() ShowCategoryModal("Computers & Tech", "tech", "Hack All Computers") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Power & Valves",
    action_btn_text = "Open...",
    tooltip         = "Lists and toggles all circuit breakers, power switches, and valves.",
    check_available = function() return has_category_units_on_map("power") end,
    callback        = function() ShowCategoryModal("Power & Valves", "power", "Activate All Power & Valves") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Windows & Barricades",
    action_btn_text = "Open...",
    tooltip         = "Lists and boards/opens all windows and barricades.",
    check_available = function() return has_category_units_on_map("windows") end,
    callback        = function() ShowCategoryModal("Windows & Barricades", "windows", "Interact All Windows & Planks") end,
})

NiceTrainer:RegisterAction("World", {
    type            = "modal",
    category        = "Interactive",
    badge           = "client",
    text            = "Gage Packages & Items",
    action_btn_text = "Open...",
    tooltip         = "Lists and picks up all Gage assignment packages and mission pickups.",
    check_available = function() return has_category_units_on_map("packages") end,
    callback        = function() ShowCategoryModal("Gage Packages & Items", "packages", "Pick Up All Items") end,
})

NiceTrainer:RegisterAction("World", {
    type     = "button",
    category = "Interactive",
    badge    = "client",
    text     = "Access Cameras",
    tooltip  = "Forces access to the security cameras from anywhere.",
    callback = function()
        if not managers.groupai:state():whisper_mode() then
            NiceTrainer:Toast("Warning: The alarm has already been triggered!")
        end
        pcall(function()
            game_state_machine:change_state_by_name("ingame_access_camera")
        end)
    end
})

-- ============================================================
-- Time & Weather
-- ============================================================

local env_paths = {
    ["Early Morning"] = "environments/pd2_env_hox_02/pd2_env_hox_02",
    ["Morning"]       = "environments/pd2_env_morning_02/pd2_env_morning_02",
    ["Mid Day"]       = "environments/pd2_env_mid_day/pd2_env_mid_day",
    ["Afternoon"]     = "environments/pd2_env_afternoon/pd2_env_afternoon",
    ["Bright Day"]    = "environments/pd2_env_jry_plane/pd2_env_jry_plane",
    ["Cloudy Day"]    = "environments/pd2_env_docks/pd2_env_docks",
    ["Night"]         = "environments/pd2_env_n2/pd2_env_n2",
    ["Misty Night"]   = "environments/pd2_env_arm_hcm_02/pd2_env_arm_hcm_02",
    ["Foggy Night"]   = "environments/pd2_env_foggy_bright/pd2_env_foggy_bright"
}

local env_options = {
    "Early Morning", "Morning", "Mid Day", "Afternoon",
    "Bright Day", "Cloudy Day", "Night", "Misty Night", "Foggy Night"
}

NiceTrainer:RegisterAction("World", {
    type = "multichoice", category = "Time & Weather", badge = "client",
    id = "time_of_day", text = "Time of Day", options = env_options, default = 3,
    action_btn_text = "Apply",
    tooltip = "Changes the lighting and time of day for the map.",
    callback = function(idx, val)
        local env = env_paths[val]
        if not env then return end
        
        local ids_environment = Idstring("environment")
        local env_id = Idstring(env)
        
        local function apply_env()
            if managers.viewport and managers.viewport:first_active_viewport() then
                managers.viewport:first_active_viewport():set_environment(env)
                NiceTrainer:Toast("Time of Day set to " .. val)
            end
        end

        if PackageManager:has(ids_environment, env_id) then
            pcall(apply_env)
        elseif DB and DB:has(ids_environment, env_id) and managers.dyn_resource then
            managers.dyn_resource:load(ids_environment, env_id, DynamicResourceManager.DYN_RESOURCES_PACKAGE, function(status)
                if status then
                    pcall(apply_env)
                else
                    NiceTrainer:Toast("Could not load lighting for " .. val)
                end
            end)
        else
            NiceTrainer:Toast("Environment not available on this map: " .. val)
        end
    end
})