-- Drivable Vehicles Spawner for NiceTrainer
-- Dynamically checks map package availability and only displays vehicle actions on supported heists

NiceTrainer._spawned_vehicles = NiceTrainer._spawned_vehicles or {}

local vehicles_data = {
    { text = "Falcogini (Supercar - Car Shop)",           unit = "units/pd2_dlc_cage/vehicles/fps_vehicle_falcogini_1/fps_vehicle_falcogini_1" },
    { text = "Longfellow (Muscle Car - Meltdown)",        unit = "units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_muscle_1/fps_vehicle_muscle_1" },
    { text = "Forklift (Empilhadeira - Meltdown)",        unit = "units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_forklift_1/fps_vehicle_forklift_1" },
    { text = "Rust's Bike (Chopper - Biker Heist)",       unit = "units/pd2_dlc_born/vehicles/fps_vehicle_bike_1/fps_vehicle_bike_1" },
    { text = "Biker Bike 2 (Cruiser - Biker Heist)",      unit = "units/pd2_dlc_born/vehicles/fps_vehicle_bike_2/fps_vehicle_bike_2" },
    { text = "Box Truck (Caminhão - Aftershock)",         unit = "units/pd2_dlc_born/vehicles/fps_vehicle_box_truck_1/fps_vehicle_box_truck_1" },
    { text = "Speedboat (Lancha - Scarface)",             unit = "units/pd2_dlc_friend/vehicles/fps_vehicle_boat_rib_1/fps_vehicle_boat_rib_1" },
    { text = "Golf Cart (Carrinho - Golden Grin)",        unit = "units/pd2_dlc_casino/vehicles/fps_vehicle_golfcart_1/fps_vehicle_golfcart_1" },
    { text = "Lawnmower (Cortador de Grama)",             unit = "units/pd2_dlc_born/vehicles/fps_vehicle_mower_1/fps_vehicle_mower_1" },
    { text = "Wanker (Hotrod - Santa's Workshop)",        unit = "units/pd2_dlc_cane/vehicles/fps_vehicle_wanker_1/fps_vehicle_wanker_1" }
}

local function is_vehicle_unit_loaded(unit_name)
    if not PackageManager or not PackageManager.has then return false end
    return PackageManager:has(Idstring("unit"), Idstring(unit_name))
end

local function is_any_vehicle_available()
    for _, v in ipairs(vehicles_data) do
        if is_vehicle_unit_loaded(v.unit) then
            return true
        end
    end
    return false
end

local function get_available_vehicle_options()
    local opts = {}
    for _, v in ipairs(vehicles_data) do
        if is_vehicle_unit_loaded(v.unit) then
            table.insert(opts, { text = v.text, value = v.unit })
        end
    end
    return opts
end

local function spawn_drivable_vehicle(unit_name, display_name)
    if not Network:is_server() then
        NiceTrainer:Toast("Warning: Only Host can reliably spawn physical vehicles.")
    end

    local unit_id = Idstring(unit_name)
    if not is_vehicle_unit_loaded(unit_name) then
        NiceTrainer:Toast("Vehicle unit is not loaded on this map.")
        return
    end

    local player = managers.player and managers.player:player_unit()
    if not alive(player) then
        NiceTrainer:Toast("Player unit not found.")
        return
    end

    local cam = player:camera()
    local rot = Rotation(cam and cam:rotation():yaw() or player:rotation():yaw(), 0, 0)
    local fwd = rot:y()

    local start_pos = player:position() + fwd * 450 + Vector3(0, 0, 100)
    local ground_ray = World:raycast("ray", start_pos, start_pos - Vector3(0, 0, 500), "slot_mask", managers.slot:get_mask("statics", "world_geometry"))
    local spawn_pos = ground_ray and (ground_ray.hit_position + Vector3(0, 0, 25)) or (player:position() + fwd * 450 + Vector3(0, 0, 25))

    local unit = nil
    if _G.safe_spawn_unit then
        pcall(function() unit = safe_spawn_unit(unit_name, spawn_pos, rot) end)
    end
    if not alive(unit) then
        pcall(function() unit = World:spawn_unit(unit_id, spawn_pos, rot) end)
    end

    if alive(unit) then
        table.insert(NiceTrainer._spawned_vehicles, unit)

        if unit:vehicle_driving() then
            unit:vehicle_driving():set_state("parked")
            unit:vehicle_driving():set_interaction_allowed(true)
        end

        NiceTrainer:Toast("Spawned Vehicle: " .. tostring(display_name or unit_name))
    else
        NiceTrainer:Toast("Failed to spawn " .. tostring(display_name or unit_name))
    end
end

-- ============================================================================
-- Registration in Spawner Tab with Dynamic Level Availability Filtering
-- ============================================================================

NiceTrainer:RegisterAction("Spawner", {
    type            = "modal",
    category        = "Vehicles",
    badge           = "host",
    id              = "spawner_vehicle_modal",
    text            = "Spawn Drivable Vehicle",
    tooltip         = "Spawns a drivable vehicle supported on the current heist. (Only available on heists with vehicle assets).",
    modal_title     = "Select Vehicle to Spawn",
    action_btn_text = "Select...",
    options         = vehicles_data,
    check_available = is_any_vehicle_available,
    callback        = function(val, text)
        local available = get_available_vehicle_options()
        local is_supported = false
        for _, opt in ipairs(available) do
            if opt.value == val then
                is_supported = true
                break
            end
        end

        if not is_supported then
            NiceTrainer:Toast("This vehicle is not loaded on this heist.")
            return
        end

        spawn_drivable_vehicle(val, text)
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type            = "button",
    category        = "Vehicles",
    badge           = "host",
    text            = "Quick Spawn Falcogini (Supercar)",
    tooltip         = "Instantly spawns the Falcogini in front of you.",
    check_available = function()
        return is_vehicle_unit_loaded("units/pd2_dlc_cage/vehicles/fps_vehicle_falcogini_1/fps_vehicle_falcogini_1")
    end,
    callback        = function()
        spawn_drivable_vehicle(
            "units/pd2_dlc_cage/vehicles/fps_vehicle_falcogini_1/fps_vehicle_falcogini_1",
            "Falcogini"
        )
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type            = "button",
    category        = "Vehicles",
    badge           = "host",
    text            = "Quick Spawn Longfellow (Muscle Car)",
    tooltip         = "Instantly spawns the Longfellow muscle car in front of you.",
    check_available = function()
        return is_vehicle_unit_loaded("units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_muscle_1/fps_vehicle_muscle_1")
    end,
    callback        = function()
        spawn_drivable_vehicle(
            "units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_muscle_1/fps_vehicle_muscle_1",
            "Longfellow"
        )
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type            = "button",
    category        = "Vehicles",
    badge           = "host",
    text            = "Quick Spawn Forklift",
    tooltip         = "Instantly spawns a drivable Forklift in front of you.",
    check_available = function()
        return is_vehicle_unit_loaded("units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_forklift_1/fps_vehicle_forklift_1")
    end,
    callback        = function()
        spawn_drivable_vehicle(
            "units/pd2_dlc_shoutout_raid/vehicles/fps_vehicle_forklift_1/fps_vehicle_forklift_1",
            "Forklift"
        )
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type            = "button",
    category        = "Vehicles",
    badge           = "host",
    text            = "Repair All Vehicles",
    tooltip         = "Instantly repairs and revives all broken/damaged vehicles on the map.",
    check_available = function()
        return is_any_vehicle_available() or (managers.vehicle and #(managers.vehicle:get_all_vehicles() or {}) > 0)
    end,
    callback        = function()
        local count = 0
        if managers.vehicle and managers.vehicle:get_all_vehicles() then
            for _, v in ipairs(managers.vehicle:get_all_vehicles()) do
                if alive(v) then
                    if v:character_damage() then
                        pcall(function() v:character_damage():repair() end)
                    end
                    if v:vehicle_driving() then
                        pcall(function()
                            v:vehicle_driving():set_state("parked")
                            v:vehicle_driving():set_interaction_allowed(true)
                        end)
                    end
                    count = count + 1
                end
            end
        end
        NiceTrainer:Toast("Repaired " .. tostring(count) .. " vehicle(s)!")
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type            = "button",
    category        = "Vehicles",
    badge           = "host",
    text            = "Remove Spawned Vehicles",
    tooltip         = "Deletes all vehicles created by the trainer in this session.",
    check_available = function()
        return #(NiceTrainer._spawned_vehicles or {}) > 0
    end,
    callback        = function()
        local count = 0
        for _, v in ipairs(NiceTrainer._spawned_vehicles or {}) do
            if alive(v) then
                if managers.vehicle then
                    pcall(function() managers.vehicle:remove_vehicle(v) end)
                end
                v:set_slot(0)
                count = count + 1
            end
        end
        NiceTrainer._spawned_vehicles = {}
        NiceTrainer:Toast("Removed " .. tostring(count) .. " vehicle(s)!")
    end
})
