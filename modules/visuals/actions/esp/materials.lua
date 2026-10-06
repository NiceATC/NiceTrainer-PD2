local ESP = NiceTrainer.ESP

function ESP.GetUnitMaterials(unit)
    if not (unit and alive(unit)) then return {} end

    local u_key = unit:key()
    local cached = ESP._cached_unit_materials[u_key]
    if cached and #cached > 0 then return cached end

    local materials = {}
    local seen_mats = {}

    local function add_mat(m)
        if m and alive(m) then
            local ok_n, n = pcall(function() return tostring(m:name()) end)
            local k = ok_n and n or tostring(m)
            if not seen_mats[k] then
                seen_mats[k] = true
                table.insert(materials, m)
            end
        end
    end

    -- 1. unit:materials()
    local ok_m, um = pcall(function() return unit:materials() end)
    if ok_m and um and type(um) == "table" then
        for _, m in ipairs(um) do
            add_mat(m)
        end
    end

    -- 2. Traverse all bodies
    local ok_bodies, num_bodies = pcall(function() return unit:num_bodies() end)
    if ok_bodies and num_bodies and num_bodies > 0 then
        for i = 0, num_bodies - 1 do
            local ok_b, body = pcall(function() return unit:body(i) end)
            if ok_b and body then
                if body.num_materials then
                    local num_materials = body:num_materials()
                    for j = 0, num_materials - 1 do
                        local ok_mat, mat = pcall(function() return body:material(j) end)
                        if ok_mat and mat and alive(mat) then
                            add_mat(mat)
                        end
                    end
                end
                if body.materials then
                    local ok_bm, bmats = pcall(function() return body:materials() end)
                    if ok_bm and bmats and type(bmats) == "table" then
                        for _, mat in ipairs(bmats) do
                            add_mat(mat)
                        end
                    end
                end
            end
        end
    end

    -- 3. interaction._materials
    local inter = unit.interaction and unit:interaction()
    if inter then
        if type(inter._init_materials) == "function" and (not inter._materials or #inter._materials == 0) then
            pcall(function() inter:_init_materials() end)
        end
        if inter._materials then
            for _, m in ipairs(inter._materials) do
                add_mat(m)
            end
        end
    end

    -- 4. Direct model objects (Iterate all models and extract materials via materials() method)
    local ok_models, models = pcall(function() return unit:get_objects_by_type(Idstring("model")) end)
    if ok_models and models and type(models) == "table" then
        for _, obj in ipairs(models) do
            if obj and alive(obj) then
                if obj.materials then
                    local ok_mats, obj_mats = pcall(function() return obj:materials() end)
                    if ok_mats and obj_mats and type(obj_mats) == "table" then
                        for _, mat in ipairs(obj_mats) do
                            add_mat(mat)
                        end
                    end
                end
                if obj.num_materials then
                    local ok_num, num_m = pcall(function() return obj:num_materials() end)
                    if ok_num and num_m and num_m > 0 then
                        for mi = 0, num_m - 1 do
                            local ok_mi, m_obj = pcall(function() return obj:material(mi) end)
                            if ok_mi and m_obj then
                                add_mat(m_obj)
                            end
                        end
                    end
                end
                if obj.material then
                    local ok_obj_m, obj_mat = pcall(function() return obj:material() end)
                    if ok_obj_m and obj_mat and alive(obj_mat) then
                        add_mat(obj_mat)
                    end
                end
            end
        end
    end

    -- 4b. Direct material objects from unit hierarchy
    local ok_mats_type, mats_type = pcall(function() return unit:get_objects_by_type(Idstring("material")) end)
    if ok_mats_type and mats_type and type(mats_type) == "table" then
        for _, mat_obj in ipairs(mats_type) do
            add_mat(mat_obj)
        end
    end

    -- 5. Direct material lookup by name
    local known_names = {
        "mtr_atm", "mtr_contour", "material", "contour", "security_camera",
        "mtr_hard_camera", "mat_camera", "mat_invisible_contour", "mtr_painting",
        "mat_mus_prop_exhibit_painting_thing", "mat_mus_prop_exhibit_painting_thing_lod1",
        "mat_goat", "mtr_goat", "goat",
        "display", "laptop", "monitor", "screen", "mtr_electrical_box", "fuse_box",
        "circuit_breaker", "mat_circuit_breaker", "mat_fuse_box", "mat_screen",
        "mat_laptop", "mat_display", "mtr_screen", "mtr_laptop", "mtr_monitor",
        "mat_dah_laptop", "mtr_dah_laptop", "dah_laptop", "dah_prop_laptop",
        "hackpad", "mat_hackpad", "mtr_hackpad", "dah_hackpad", "mat_dah_hackpad",
        "mtr_dah_hackpad", "dah_prop_hackpad", "dah_fuse_box", "dah_prop_fuse_box",
        "mat_dah_fuse_box", "mtr_dah_fuse_box", "mat_keypad", "mtr_keypad", "keypad",
        "mat_fuse", "mtr_fuse", "mat_power_box", "mtr_power_box", "power_box",
        "mat_security_box", "mtr_security_box", "security_box", "sec_box",
        "mat_switch_box", "mtr_switch_box", "switch_box", "mat_transformer", "mtr_transformer"
    }
    for _, name in ipairs(known_names) do
        local ok_named, named_m = pcall(function() return unit:material(Idstring(name)) end)
        if ok_named and named_m and alive(named_m) then
            add_mat(named_m)
        end
    end

    if #materials > 0 then
        ESP._cached_unit_materials[u_key] = materials
        if inter and (not inter._materials or #inter._materials == 0) then
            inter._materials = materials
        end
    end
    return materials
end
function ESP.ApplyHighlightToUnit(target_u, enabled, color)
    if not (target_u and alive(target_u)) then return end

    if enabled then
        pcall(function()
            if target_u:unit_data() then target_u:unit_data().ignore_portal = true end
            if managers.portal then managers.portal:remove_unit(target_u) end
            if managers.occlusion then managers.occlusion:remove_occlusion(target_u) end
            if target_u.get_objects_by_type then
                local models = target_u:get_objects_by_type(Idstring("model"))
                if models then
                    for _, obj in pairs(models) do
                        if obj and alive(obj) then
                            if obj.set_skip_occlusion then obj:set_skip_occlusion(true) end
                        end
                    end
                end
            end
            if target_u.set_moving then target_u:set_moving() end
        end)
    end

    local inter = target_u.interaction and target_u:interaction()
    if inter and inter.set_contour_override then
        inter:set_contour_override(enabled and true or nil)
    end

    local mats = ESP.GetUnitMaterials(target_u)
    for _, mat in ipairs(mats) do
        if mat and alive(mat) then
            pcall(function()
                if enabled then
                    mat:set_variable(Idstring("contour_opacity"), 1)
                    if color then
                        mat:set_variable(Idstring("contour_color"), Vector3(color.r, color.g, color.b))
                    end
                else
                    mat:set_variable(Idstring("contour_opacity"), 0)
                end
            end)
        end
    end
end
function ESP.SetMaterialHighlight(unit, enabled, color)
    if not (unit and alive(unit)) then return end

    local u_key = unit:key()
    if enabled then
        ESP._highlighted_units[u_key] = unit
    else
        ESP._highlighted_units[u_key] = nil
    end

    -- 1. Check interaction extension materials
    local inter = unit.interaction and unit:interaction()
    if inter then
        if inter.set_contour_override then inter:set_contour_override(enabled and true or nil) end
        if type(inter._init_materials) == "function" and (not inter._materials or #inter._materials == 0) then
            pcall(function() inter:_init_materials() end)
        end
        if inter._materials then
            for _, m in ipairs(inter._materials) do
                if m and alive(m) then
                    pcall(function()
                        if enabled then
                            m:set_variable(Idstring("contour_opacity"), 1)
                            if color then
                                m:set_variable(Idstring("contour_color"), Vector3(color.r, color.g, color.b))
                            end
                        else
                            m:set_variable(Idstring("contour_opacity"), 0)
                        end
                    end)
                end
            end
        end
    end

    ESP.ApplyHighlightToUnit(unit, enabled, color)

    -- 2. Check spawned children (e.g. ATM door, money inside, parts)
    if unit.spawn_manager and unit:spawn_manager() then
        pcall(function()
            local sm = unit:spawn_manager()
            local spawned = sm.spawned_units and sm:spawned_units()
            if spawned then
                for _, entry in pairs(spawned) do
                    local child_u = type(entry) == "table" and entry.unit or entry
                    if child_u and type(child_u) == "userdata" and alive(child_u) then
                        local c_inter = child_u.interaction and child_u:interaction()
                        if c_inter and c_inter._materials then
                            for _, m in ipairs(c_inter._materials) do
                                if m and alive(m) then
                                    pcall(function()
                                        if enabled then
                                            m:set_variable(Idstring("contour_opacity"), 1)
                                            if color then
                                                m:set_variable(Idstring("contour_color"), Vector3(color.r, color.g, color.b))
                                            end
                                        else
                                            m:set_variable(Idstring("contour_opacity"), 0)
                                        end
                                    end)
                                end
                            end
                        end
                        ESP.ApplyHighlightToUnit(child_u, enabled, color)
                    end
                end
            end
        end)
    end

    -- 3. Check linked children (unit:children())
    if unit.children then
        pcall(function()
            for _, child_u in ipairs(unit:children()) do
                if alive(child_u) then
                    ESP.ApplyHighlightToUnit(child_u, enabled, color)
                end
            end
        end)
    end

    if unit.parent then
        pcall(function()
            local parent_u = unit:parent()
            if parent_u and alive(parent_u) then
                ESP.ApplyHighlightToUnit(parent_u, enabled, color)
                if parent_u.children then
                    for _, sibling_u in ipairs(parent_u:children()) do
                        if alive(sibling_u) and sibling_u ~= unit then
                            ESP.ApplyHighlightToUnit(sibling_u, enabled, color)
                        end
                    end
                end
            end
        end)
    end
end
function ESP.SetWhitelistedContour(unit, cat)
    if not (unit and alive(unit)) then return end
    if not (NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled) then return end
    if cat and NiceTrainer.Settings["esp_show_" .. cat] == false then return end

    local c = (NiceTrainer.Settings and NiceTrainer.Settings["esp_color_" .. cat]) or (cat == "loot_bags" and Color(0.2, 0.6, 1) or Color(1, 0.4, 0.1))
    local expected = "nt_esp_" .. cat

    if unit:contour() then
        pcall(unit:contour().add, unit:contour(), expected, false, 1)
    end
    ESP.SetMaterialHighlight(unit, true, c)
    local base_ext = unit:base() or (unit.interaction and unit:interaction())
    if base_ext then base_ext._nt_esp_contour = expected end
end
function ESP.ClearAllMaterialHighlights()
    for _, unit in pairs(ESP._highlighted_units) do
        if alive(unit) then
            pcall(ESP.SetMaterialHighlight, unit, false)
        end
    end
    ESP._highlighted_units = {}

    if managers.interaction and managers.interaction._interactive_units then
        for _, unit in ipairs(managers.interaction._interactive_units) do
            if alive(unit) then
                local base_ext = unit:base() or (unit.interaction and unit:interaction())
                if base_ext and base_ext._nt_esp_contour then
                    if unit:contour() then
                        for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(unit:contour().remove, unit:contour(), ct) end
                    end
                    base_ext._nt_esp_contour = nil
                    pcall(ESP.SetMaterialHighlight, unit, false)
                end
            end
        end
    end
    if NiceTrainer._active_ammo_clips then
        for _, clip in pairs(NiceTrainer._active_ammo_clips) do
            if alive(clip) then
                pcall(ESP.SetMaterialHighlight, clip, false)
                if clip:contour() and clip:base() and clip:base()._nt_esp_contour then
                    pcall(clip:contour().remove, clip:contour(), "nt_esp_mission_deployables")
                    clip:base()._nt_esp_contour = nil
                end
            end
        end
    end
    if SecurityCamera and SecurityCamera.cameras then
        for _, cam in pairs(SecurityCamera.cameras) do
            if alive(cam) then
                pcall(ESP.SetMaterialHighlight, cam, false)
                if cam:contour() and cam:base() and cam:base()._nt_esp_contour then
                    pcall(cam:contour().remove, cam:contour(), "nt_esp_cameras")
                    cam:base()._nt_esp_contour = nil
                end
            end
        end
    end
end
function ESP.clean_unit_esp(unit)
    if not (unit and alive(unit)) then return end
    local u_key = unit:key()
    ESP._highlighted_units[u_key] = nil
    ESP._cached_unit_materials[u_key] = nil
    ESP._cached_classification[u_key] = nil

    if unit:contour() then
        pcall(function()
            if unit:contour().clear then unit:contour():clear() end
            for _, ct in ipairs(ESP.NPC_KEYS) do unit:contour():remove(ct) end
            for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do unit:contour():remove(ct) end
        end)
    end
    if unit:base() then
        unit:base()._nt_esp_contour = nil
    end
    pcall(ESP.SetMaterialHighlight, unit, false)

    -- Force contour_opacity to 0 on all materials directly to guarantee no residual outlines on corpses
    local mats = ESP.GetUnitMaterials(unit)
    for _, mat in ipairs(mats) do
        if mat and alive(mat) then
            pcall(function()
                mat:set_variable(Idstring("contour_opacity"), 0)
            end)
        end
    end

    -- Clean up pooled HUD marker attached to this unit
    local marker = NiceTrainer._esp_markers_map and NiceTrainer._esp_markers_map[u_key]
    if marker then
        if alive(marker.panel) then marker.panel:parent():remove(marker.panel) end
        NiceTrainer._esp_markers_map[u_key] = nil
        if NiceTrainer._esp_markers then
            for idx, m in ipairs(NiceTrainer._esp_markers) do
                if m == marker then
                    table.remove(NiceTrainer._esp_markers, idx)
                    break
                end
            end
        end
    end
end
