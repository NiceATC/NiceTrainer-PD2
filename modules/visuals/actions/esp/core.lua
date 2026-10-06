local ESP = NiceTrainer.ESP

function ESP.get_static_props()
    if ESP._cached_static_props then return ESP._cached_static_props end
    ESP._cached_static_props = {}
    if World and World.find_units_quick then
        local statics = World:find_units_quick("all", 1) -- slot 1 only
        if statics then
            for _, u in ipairs(statics) do
                if alive(u) then
                    local un = tostring(u:name() or ""):lower()
                    if un:find("atm", 1, true) or un:find("bank_machine", 1, true) then
                        table.insert(ESP._cached_static_props, u)
                    end
                end
            end
        end
    end
    return ESP._cached_static_props
end
function ESP.CleanAllContoursOnLevelLoad()
    ESP.EnsureDefaults()
    ESP.InitContourConfig()

    ESP._cached_unit_materials = {}
    ESP._cached_classification = {}
    ESP._cached_static_props = nil
    ESP._client_inter_cache = nil
    ESP.ClearMarkers()

    -- 1. Sweep all NPCs, enemies, civilians, group AI & turrets
    local npc_units = {}
    local checked_npc = {}
    if managers.enemy then
        if managers.enemy.all_enemies then
            for _, e_data in pairs(managers.enemy:all_enemies() or {}) do
                local u = type(e_data) == "table" and e_data.unit or e_data
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
        if managers.enemy.all_civilians then
            for _, c_data in pairs(managers.enemy:all_civilians() or {}) do
                local u = type(c_data) == "table" and c_data.unit or c_data
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
    end
    if managers.groupai and managers.groupai:state() then
        local gai = managers.groupai:state()
        if gai.all_AI_units then
            for _, u_data in pairs(gai:all_AI_units()) do
                local u = type(u_data) == "table" and u_data.unit or u_data
                if alive(u) and type(u) == "userdata" and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
        if gai.turrets then
            for _, turret_u in pairs(gai:turrets()) do
                if alive(turret_u) and not checked_npc[turret_u:key()] then
                    checked_npc[turret_u:key()] = true
                    table.insert(npc_units, turret_u)
                end
            end
        end
    end
    if World and World.find_units_quick then
        local slot_units = World:find_units_quick("all", 12, 21, 22)
        if slot_units then
            for _, u in ipairs(slot_units) do
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
    end

    for _, unit in ipairs(npc_units) do
        if alive(unit) then
            ESP.clean_unit_esp(unit)
        end
    end

    -- Sweep corpses
    if World and World.find_units_quick then
        local corpse_units = World:find_units_quick("all", 17, 25)
        if corpse_units then
            for _, c_unit in ipairs(corpse_units) do
                if alive(c_unit) then
                    ESP.clean_unit_esp(c_unit)
                end
            end
        end
    end

    -- 2. Sweep cameras: remove contours and material highlights
    local checked_cams = {}
    local cam_list = {}
    if SecurityCamera and SecurityCamera.cameras then
        for _, cam in pairs(SecurityCamera.cameras) do
            if alive(cam) and not checked_cams[cam:key()] then
                checked_cams[cam:key()] = true
                table.insert(cam_list, cam)
            end
        end
    end
    if SecurityCamera and SecurityCamera.all_cameras then
        for _, cam in pairs(SecurityCamera.all_cameras) do
            if alive(cam) and not checked_cams[cam:key()] then
                checked_cams[cam:key()] = true
                table.insert(cam_list, cam)
            end
        end
    end
    if World and World.find_units_quick then
        local cam_slot_units = World:find_units_quick("all", 7)
        if cam_slot_units then
            for _, cam in ipairs(cam_slot_units) do
                if alive(cam) and not checked_cams[cam:key()] then
                    local base = cam:base()
                    local un = tostring(cam:name() or ""):lower()
                    if (base and (base.is_security_camera or base.is_spy_camera)) or un:find("camera", 1, true) or un:find("cctv", 1, true) then
                        checked_cams[cam:key()] = true
                        table.insert(cam_list, cam)
                    end
                end
            end
        end
    end

    for _, cam in ipairs(cam_list) do
        if alive(cam) then
            if cam:contour() then
                pcall(function()
                    cam:contour():remove("nt_esp_cameras")
                    cam:contour():remove("friendly")
                    cam:contour():remove("generic_interactable")
                    cam:contour():remove("mark_unit")
                    cam:contour():remove("mark_enemy")
                end)
            end
            local base_ext = cam:base() or (cam.interaction and cam:interaction())
            if base_ext then base_ext._nt_esp_contour = nil end
            ESP.SetMaterialHighlight(cam, false)
        end
    end

    -- 3. Sweep ESP._highlighted_units: clear all highlights and contours
    for u_key, unit in pairs(ESP._highlighted_units) do
        if alive(unit) then
            ESP.clean_unit_esp(unit)
        end
    end
    ESP._highlighted_units = {}

    -- 4. Sweep interactive units: clear contours
    if managers.interaction and managers.interaction._interactive_units then
        for _, u in ipairs(managers.interaction._interactive_units) do
            if alive(u) then
                pcall(ESP.SetMaterialHighlight, u, false)
                if u:contour() then
                    for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(u:contour().remove, u:contour(), ct) end
                    for _, ct in ipairs(ESP.NPC_KEYS) do pcall(u:contour().remove, u:contour(), ct) end
                end
                local b = u:base() or (u.interaction and u:interaction())
                if b then b._nt_esp_contour = nil end
            end
        end
    end

    -- 5. Sweep world loot/carry slots
    if World and World.find_units_quick then
        local items = World:find_units_quick("all")
        if items then
            for _, u in ipairs(items) do
                if alive(u) then
                    pcall(ESP.SetMaterialHighlight, u, false)
                    if u:contour() then
                        for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(u:contour().remove, u:contour(), ct) end
                        for _, ct in ipairs(ESP.NPC_KEYS) do pcall(u:contour().remove, u:contour(), ct) end
                    end
                    local b = u:base() or (u.interaction and u:interaction())
                    if b then b._nt_esp_contour = nil end
                end
            end
        end
    end
end
function ESP.ApplyESP(force_clean)
    if not force_clean and not NiceTrainer:IsInHeist() then return end
    ESP.EnsureDefaults()
    ESP.InitContourConfig()

    local enabled = NiceTrainer.Settings.esp_enabled

    if not enabled then 
        ESP.CleanAllContoursOnLevelLoad()
        return
    end

    ESP._apply_count = (ESP._apply_count or 0) + 1
    ESP._stage = "npc"
    -- Mark existing markers as unseen for this refresh cycle
    if NiceTrainer._esp_markers then
        for _, m in ipairs(NiceTrainer._esp_markers) do
            m._seen_in_tick = false
        end
    end

    local player = managers.player and managers.player:player_unit()
    local p_pos = alive(player) and player:position() or nil
    local proximity_mode = NiceTrainer.Settings.esp_proximity
    local proximity_range = (NiceTrainer.Settings.esp_proximity_range or 15) * 100
    local auto_hide = NiceTrainer.Settings.esp_auto_hide
    local show_labels = NiceTrainer.Settings.esp_show_labels
    local current_highlighted_keys = {}

    -- 1. NPCs, Cops, Civilians, VIPs & Special Enemies
    local npc_units = {}
    local checked_npc = {}
    if managers.enemy then
        if managers.enemy.all_enemies then
            for _, e_data in pairs(managers.enemy:all_enemies() or {}) do
                local u = type(e_data) == "table" and e_data.unit or e_data
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
        if managers.enemy.all_civilians then
            for _, c_data in pairs(managers.enemy:all_civilians() or {}) do
                local u = type(c_data) == "table" and c_data.unit or c_data
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
    end
    if managers.groupai and managers.groupai:state() then
        local gai = managers.groupai:state()
        if gai.all_AI_units then
            for _, u_data in pairs(gai:all_AI_units()) do
                local u = type(u_data) == "table" and u_data.unit or u_data
                if alive(u) and type(u) == "userdata" and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
        if gai.turrets then
            for _, turret_u in pairs(gai:turrets()) do
                if alive(turret_u) and not checked_npc[turret_u:key()] then
                    checked_npc[turret_u:key()] = true
                    table.insert(npc_units, turret_u)
                end
            end
        end
    end
    if World and World.find_units_quick then
        local slot_units = World:find_units_quick("all", 12, 21, 22)
        if slot_units then
            for _, u in ipairs(slot_units) do
                if alive(u) and not checked_npc[u:key()] then
                    checked_npc[u:key()] = true
                    table.insert(npc_units, u)
                end
            end
        end
    end

    local mission_units = ESP.GetMissionSpawnedUnits()
    for _, u in ipairs(mission_units) do
        if alive(u) and not checked_npc[u:key()] and u.character_damage and u:character_damage() then
            checked_npc[u:key()] = true
            table.insert(npc_units, u)
        end
    end

    for _, unit in ipairs(npc_units) do
        local ok_npc, err_npc = pcall(function()
        if alive(unit) then
            -- If this unit is a camera, DO NOT process or clean it in the NPC loop!
            local u_base = unit:base()
            if u_base and (u_base.is_security_camera or u_base.is_spy_camera) then
                return
            end
            local u_name_check = tostring(unit:name() or ""):lower()
            if u_name_check:find("camera", 1, true) or u_name_check:find("cctv", 1, true) then
                return
            end

            if ESP.IsFriendlyUnit(unit) then
                ESP.clean_unit_esp(unit)
            else
                local is_dead = ESP.is_unit_dead(unit)
                if enabled and not is_dead then
                    local has_keycard, key_label = ESP.UnitHasKeycard(unit)
                    local c_key = has_keycard and "vips" or ESP.ClassifyNPC(unit)

                    if c_key and NiceTrainer.Settings["esp_show_" .. c_key] then
                        local c = NiceTrainer.Settings["esp_color_" .. c_key]
                        pcall(function()
                            if unit:unit_data() then unit:unit_data().ignore_portal = true end
                        end)
                        local ext = unit:contour()
                        if c and ext and ext.add then
                            local expected_contour = "nt_esp_" .. c_key
                            if not u_base or u_base._nt_esp_contour ~= expected_contour then
                                for _, ct in ipairs(ESP.NPC_KEYS) do ext:remove(ct) end
                                pcall(ext.add, ext, expected_contour, false, 1)
                                if u_base then u_base._nt_esp_contour = expected_contour end
                            end
                        end
                        if c then
                            ESP.SetMaterialHighlight(unit, true, c)
                        end
                        current_highlighted_keys[unit:key()] = true

                        if show_labels and (has_keycard or c_key == "vips" or c_key:find("special_", 1, true)) then
                            local lbl = has_keycard and (key_label or "KEYCARD") or (c_key == "vips" and "VIP" or c_key:gsub("special_", ""))
                            ESP.UpdateOrCreateMarker(unit, c_key, Color(c.r, c.g, c.b), lbl)
                        end
                    else
                        ESP.clean_unit_esp(unit)
                    end
                else
                    ESP.clean_unit_esp(unit)
                end
            end
        end
        end)
        if not ok_npc then
            ESP._logged_errors = ESP._logged_errors or {}
            local msg = tostring(err_npc)
            if not ESP._logged_errors[msg] then
                ESP._logged_errors[msg] = true
                log("[NiceTrainer ESP] npc loop error: " .. msg)
            end
        end
    end

    -- Sweep corpses to ensure no lingering contours or material highlights remain on dead bodies
    if World and World.find_units_quick then
        local corpse_units = World:find_units_quick("all", 17, 25)
        if corpse_units then
            for _, c_unit in ipairs(corpse_units) do
                if alive(c_unit) then
                    ESP.clean_unit_esp(c_unit)
                end
            end
        end
    end

    ESP._stage = "cameras"
    -- 2. Security Cameras (Active & Operational Only)
    local checked_cams = {}
    local cam_list = {}
    if SecurityCamera and SecurityCamera.cameras then
        for _, cam in pairs(SecurityCamera.cameras) do
            if alive(cam) and not checked_cams[cam:key()] then
                checked_cams[cam:key()] = true
                table.insert(cam_list, cam)
            end
        end
    end
    if SecurityCamera and SecurityCamera.all_cameras then
        for _, cam in pairs(SecurityCamera.all_cameras) do
            if alive(cam) and not checked_cams[cam:key()] then
                checked_cams[cam:key()] = true
                table.insert(cam_list, cam)
            end
        end
    end
    if World and World.find_units_quick then
        local cam_slot_units = World:find_units_quick("all", 7)
        if cam_slot_units then
            for _, cam in ipairs(cam_slot_units) do
                if alive(cam) and not checked_cams[cam:key()] then
                    local base = cam:base()
                    local un = tostring(cam:name() or ""):lower()
                    if (base and (base.is_security_camera or base.is_spy_camera)) or un:find("camera", 1, true) or un:find("cctv", 1, true) then
                        checked_cams[cam:key()] = true
                        table.insert(cam_list, cam)
                    end
                end
            end
        end
    end

    for _, camera_unit in ipairs(cam_list) do
        if alive(camera_unit) then
            local is_active = ESP.is_camera_operational(camera_unit)
            local should_show = enabled and NiceTrainer.Settings.esp_show_cameras and is_active
            local expected = should_show and "nt_esp_cameras" or nil
            local base_ext = camera_unit:base() or (camera_unit.interaction and camera_unit:interaction())
            
            if expected then
                local c = NiceTrainer.Settings.esp_color_cameras or { r = 0, g = 1, b = 1 }
                current_highlighted_keys[camera_unit:key()] = true
                
                if camera_unit:contour() then
                    pcall(function()
                        camera_unit:contour():remove("friendly", false)
                        camera_unit:contour():remove("nt_esp_cameras", false)
                        camera_unit:contour():remove("generic_interactable", false)
                        camera_unit:contour():remove("mark_unit", false)
                        camera_unit:contour():remove("mark_enemy", false)

                        camera_unit:contour():add("nt_esp_cameras", false, 1)
                    end)
                    if base_ext then base_ext._nt_esp_contour = expected end
                end
                
                ESP.SetMaterialHighlight(camera_unit, true, c)
                
                if show_labels and camera_unit:enabled() then
                    ESP.UpdateOrCreateMarker(camera_unit, "cameras", Color(c.r, c.g, c.b), "camera")
                end
            else
                if camera_unit:contour() then
                    pcall(function()
                        camera_unit:contour():remove("nt_esp_cameras", false)
                        camera_unit:contour():remove("friendly", false)
                        camera_unit:contour():remove("generic_interactable", false)
                        camera_unit:contour():remove("mark_unit", false)
                        camera_unit:contour():remove("mark_enemy", false)
                    end)
                    if base_ext then base_ext._nt_esp_contour = nil end
                end
                ESP.SetMaterialHighlight(camera_unit, false)
            end
        end
    end

    ESP._stage = "items:collect"
    -- 3. Loot, Mission Items, Power Boxes, Computers, Doors, Deployables & Objectives
    local processed_items = {}
    for k, _ in pairs(checked_cams) do
        processed_items[k] = true
    end
    local item_units = {}
    if managers.interaction and managers.interaction._interactive_units then
        for _, u in ipairs(managers.interaction._interactive_units) do
            if alive(u) and u:enabled() and not processed_items[u:key()] then
                processed_items[u:key()] = true
                table.insert(item_units, u)
            end
        end
    end
    if World and World.find_units_quick then
        local slot_items = World:find_units_quick("all", 14, 20, 23)
        if slot_items then
            for _, u in ipairs(slot_items) do
                if alive(u) and not processed_items[u:key()] then
                    processed_items[u:key()] = true
                    table.insert(item_units, u)
                end
            end
        end
        local statics = World:find_units_quick("all", 1)
        if statics then
            for _, u in ipairs(statics) do
                if alive(u) and not processed_items[u:key()] then
                    local un = tostring(u:name() or ""):lower()
                    local inter = u.interaction and u:interaction()
                    if Network:is_server() then
                        -- Host: Use the original optimized string-matching filter (mission scripts already give us the rest)
                        local td = inter and inter.tweak_data and tostring(inter.tweak_data):lower() or ""
                        if un:find("laptop", 1, true) or un:find("notebook", 1, true) or un:find("computer", 1, true)
                           or un:find("hackpad", 1, true) or un:find("hack_pad", 1, true) or un:find("fuse_box", 1, true)
                           or un:find("circuit_breaker", 1, true) or un:find("power_box", 1, true) or un:find("security_box", 1, true)
                           or un:find("atm", 1, true) or un:find("bank_machine", 1, true)
                           or td:find("laptop", 1, true) or td:find("password", 1, true) or td:find("notebook", 1, true)
                           or td:find("hackpad", 1, true) or td:find("hack_pad", 1, true) or td:find("fuse", 1, true)
                        then
                            processed_items[u:key()] = true
                            table.insert(item_units, u)
                        end
                    else
                        -- Client: the mission tables are incomplete, so grab all interactables
                        if inter or un:find("atm", 1, true) or un:find("bank_machine", 1, true) then
                            processed_items[u:key()] = true
                            table.insert(item_units, u)
                        end
                    end
                end
            end
        end
        if not Network:is_server() then
            -- Client: interactions flagged host_only are never registered in managers.interaction
            -- (set_active forces them inactive), so scan every unit that owns an interaction extension.
            local now = TimerManager:game():time()
            if not ESP._client_inter_cache or now - (ESP._client_inter_cache_t or 0) > 3 then
                local cache = {}
                local all_units = World:find_units_quick("all")
                if all_units then
                    for _, u in ipairs(all_units) do
                        if alive(u) and u.interaction and u:interaction() then
                            table.insert(cache, u)
                        end
                    end
                end
                ESP._client_inter_cache = cache
                ESP._client_inter_cache_t = now
            end
            for _, u in ipairs(ESP._client_inter_cache) do
                if alive(u) and not processed_items[u:key()] then
                    processed_items[u:key()] = true
                    table.insert(item_units, u)
                end
            end
        end
    end
    for _, u in ipairs(mission_units) do
        if alive(u) and not processed_items[u:key()] then
            processed_items[u:key()] = true
            table.insert(item_units, u)
        end
    end

    ESP._stage = "items:loop"
    local dbg = { total = #item_units, enabled_ok = 0, valid = 0, cat = 0, expected = 0, no_enabled = 0, mission_dis = 0 }
    ESP._dbg = dbg
    for _, unit in ipairs(item_units) do
        local ok_unit, err_unit = pcall(function()
        if alive(unit) then
            local is_wl, wl_cat = ESP.is_whitelisted_always_visible(unit)
            local is_unit_ok = is_wl or unit:enabled()

            local u_data = unit:unit_data()
            local u_id = u_data and u_data.unit_id
            
            local is_mission_disabled = false
            if not is_wl and u_id and managers.game_play_central and managers.game_play_central._mission_disabled_units then
                is_mission_disabled = managers.game_play_central._mission_disabled_units[u_id] and true or false
                -- Clients often fail to clear _mission_disabled_units when the host enables dynamic loot/props.
                -- However, if we blindly bypass it, we mark ghost props (planks, crowbars) that never spawned.
                -- The only safe way to bypass it is to check if the host synced the interaction state as active.
                if is_mission_disabled and not Network:is_server() then
                    local inter = unit.interaction and unit:interaction()
                    if inter and (inter:active() or inter._active) then
                        is_mission_disabled = false
                    end
                end
            end
            
            if unit:slot() == 0 then
                is_unit_ok = false
            end
            
            if not is_unit_ok then dbg.no_enabled = dbg.no_enabled + 1 end
            if is_mission_disabled then dbg.mission_dis = dbg.mission_dis + 1 end

            if is_unit_ok and not is_mission_disabled then
                dbg.enabled_ok = dbg.enabled_ok + 1
                local inter = unit.interaction and unit:interaction()
                
                local is_wl, wl_cat = ESP.is_whitelisted_always_visible(unit)
                local cat, tw = ESP.ClassifyInteractive(unit)
                if not cat and is_wl then
                    cat = wl_cat
                    tw = wl_cat
                end

                local is_active = false
                if inter then
                    local is_disabled = (inter.disabled and inter:disabled()) or inter._disabled
                    local inactive = (inter._active == false)

                    if inactive and not Network:is_server() then
                        -- Clients often have inter._active == false for valid spawned loot, bags, planks, etc.
                        if cat or inter._host_only then
                            inactive = false
                        end
                    end

                    is_active = not (is_disabled or inactive)
                end
                
                local is_atm = false
                local u_name = tostring(unit:name() or ""):lower()
                if u_name:find("atm", 1, true) or u_name:find("bank_machine", 1, true) then
                    is_atm = true
                end
                local is_bag = ESP.is_actual_bag(unit)
                local is_c4 = ESP.is_c4_mission_item(unit)

                local is_power = (cat == "mission_power")

                local is_goat = false
                if cat == "loot_valuables" then
                    local tw_str = tw and tostring(tw):lower() or ""
                    local inter_td = inter and inter.tweak_data and tostring(inter.tweak_data):lower() or ""
                    if tw_str:find("goat", 1, true) or u_name:find("goat", 1, true) or inter_td:find("goat", 1, true) then
                        is_goat = true
                    end
                end

                local is_valid = false
                if is_wl then
                    is_valid = true
                elseif inter then
                    is_valid = is_active or is_goat or cat == "mission_computer" or cat == "mission_power"
                else
                    is_valid = is_bag or is_c4 or is_atm or is_goat or cat == "mission_computer" or cat == "mission_power"
                end

                if cat then dbg.cat = dbg.cat + 1 end
                if is_valid and cat then
                    dbg.valid = dbg.valid + 1
                    local expected = nil
                    local c = nil
                    
                    if enabled and cat and NiceTrainer.Settings["esp_show_" .. cat] then
                        c = NiceTrainer.Settings["esp_color_" .. cat]
                        if c then
                            local show_this = true
                            if proximity_mode and p_pos then
                                if mvector3.distance(p_pos, unit:position()) > proximity_range then show_this = false end
                            end
                            if show_this and auto_hide and managers.player then
                                if cat == "mission_crowbar" and (managers.player:has_special_equipment("crowbar") or managers.player:has_special_equipment("crowbar_stackable")) then
                                    show_this = false
                                end
                            end
                            if show_this then expected = "nt_esp_" .. cat end
                        end
                    end

                    local base_ext = unit:base() or inter
                    if base_ext then
                        if expected then
                            dbg.expected = dbg.expected + 1
                            current_highlighted_keys[unit:key()] = true
                            pcall(function()
                                if unit:unit_data() then unit:unit_data().ignore_portal = true end
                                if managers.portal then managers.portal:remove_unit(unit) end
                                if managers.occlusion then managers.occlusion:remove_occlusion(unit) end
                            end)
                            if unit:contour() then
                                if base_ext._nt_esp_contour ~= expected then
                                    for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do unit:contour():remove(ct) end
                                    pcall(unit:contour().add, unit:contour(), expected, false, 1)
                                    base_ext._nt_esp_contour = expected
                                end
                            end
                            ESP.SetMaterialHighlight(unit, true, c)
                            base_ext._nt_esp_contour = expected
                            if show_labels and cat ~= "mission_c4" then
                                local label_str = tw or cat
                                if cat == "loot_bags" then
                                    local bag_cid = nil
                                    if unit.carry_data and unit:carry_data() then
                                        local ok_cid, cid = pcall(function() return unit:carry_data():carry_id() end)
                                        if ok_cid and cid and type(cid) == "string" and cid ~= "" then
                                            bag_cid = cid .. " bag"
                                        end
                                    end
                                    label_str = bag_cid or tw or "bag"
                                elseif is_goat then
                                    label_str = "goat"
                                end
                                ESP.UpdateOrCreateMarker(unit, cat, Color(c.r, c.g, c.b), label_str)
                            end
                        else
                            local is_wl_sub, wl_cat_sub = ESP.is_whitelisted_always_visible(unit)
                            if is_wl_sub then
                                ESP.SetWhitelistedContour(unit, wl_cat_sub)
                            else
                                if unit:contour() and base_ext._nt_esp_contour then
                                    for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(unit:contour().remove, unit:contour(), ct) end
                                end
                                base_ext._nt_esp_contour = nil
                                ESP.SetMaterialHighlight(unit, false)
                            end
                        end
                    end
                end
            end
        end
        end)
        if not ok_unit then
            ESP._logged_errors = ESP._logged_errors or {}
            local msg = tostring(err_unit)
            if not ESP._logged_errors[msg] then
                ESP._logged_errors[msg] = true
                log("[NiceTrainer ESP] item loop error: " .. msg)
            end
        end
    end

    do
        local now = TimerManager:game():time()
        if now - (ESP._dbg_log_t or 0) > 10 then
            ESP._dbg_log_t = now
            log(string.format("[NiceTrainer ESP] items(server=%s) total=%d enabled_ok=%d no_enabled=%d mission_dis=%d cat=%d valid=%d expected=%d",
                tostring(Network:is_server()), dbg.total, dbg.enabled_ok, dbg.no_enabled, dbg.mission_dis, dbg.cat, dbg.valid, dbg.expected))
        end
    end

    -- 4. Standalone ATM & Props (Cached - slot 1 only)
    local static_props = ESP.get_static_props()
    for _, unit in ipairs(static_props) do
        if alive(unit) and not processed_items[unit:key()] then
            local u_name = tostring(unit:name() or ""):lower()
            if u_name:find("atm", 1, true) or u_name:find("bank_machine", 1, true) then
                if enabled and NiceTrainer.Settings.esp_show_loot_cash then
                    local c = NiceTrainer.Settings.esp_color_loot_cash
                    if c then
                        ESP.SetMaterialHighlight(unit, true, c)
                        current_highlighted_keys[unit:key()] = true
                        if show_labels and unit:enabled() then
                            ESP.UpdateOrCreateMarker(unit, "loot_cash", Color(c.r, c.g, c.b), "atm")
                        end
                    end
                else
                    if ESP._highlighted_units[unit:key()] then
                        ESP.SetMaterialHighlight(unit, false)
                    end
                end
            end
        end
    end

    -- 5. Dropped Ammo Pickups (AmmoClips from dead cops)
    if NiceTrainer._active_ammo_clips then
        local show_ammo = enabled and NiceTrainer.Settings.esp_show_mission_deployables
        local ammo_col = NiceTrainer.Settings.esp_color_mission_deployables
        for u_key, clip_unit in pairs(NiceTrainer._active_ammo_clips) do
            if alive(clip_unit) then
                local should_show = show_ammo
                if should_show and proximity_mode and p_pos then
                    if mvector3.distance(p_pos, clip_unit:position()) > proximity_range then
                        should_show = false
                    end
                end

                if should_show and ammo_col then
                    current_highlighted_keys[u_key] = true
                    ESP.SetMaterialHighlight(clip_unit, true, ammo_col)
                    if clip_unit:contour() then
                        local expected = "nt_esp_mission_deployables"
                        if clip_unit:base() and clip_unit:base()._nt_esp_contour ~= expected then
                            pcall(clip_unit:contour().add, clip_unit:contour(), expected, false, 1)
                            clip_unit:base()._nt_esp_contour = expected
                        end
                    end
                else
                    if clip_unit:contour() and clip_unit:base() and clip_unit:base()._nt_esp_contour then
                        clip_unit:contour():remove("nt_esp_mission_deployables")
                        clip_unit:base()._nt_esp_contour = nil
                    end
                    ESP.SetMaterialHighlight(clip_unit, false)
                end
            else
                NiceTrainer._active_ammo_clips[u_key] = nil
            end
        end
    end

    -- 6. Clean up any stale highlighted units that are no longer active/valid
    for u_key, old_unit in pairs(ESP._highlighted_units) do
        if not current_highlighted_keys[u_key] then
            if alive(old_unit) then
                ESP.clean_unit_esp(old_unit)
            else
                ESP._highlighted_units[u_key] = nil
            end
        end
    end

    ESP._stage = "done"
    -- 7. Flush unused markers from previous ticks (zero panel recreation cost)
    ESP.FlushUnusedMarkers()
end

-- Debug system integration (live values in the Debug panel)
if NiceTrainer.Debug then
    NiceTrainer.Debug:Watch("esp", function()
        local d = ESP._dbg
        local s = string.format("runs=%d stage=%s", ESP._apply_count or 0, tostring(ESP._stage))
        if d then s = s .. string.format(" items %d/ok%d/cat%d/val%d/exp%d", d.total, d.enabled_ok, d.cat, d.valid, d.expected) end
        return s
    end)
end
