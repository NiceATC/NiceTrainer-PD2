-- Equipment Spawner for NiceTrainer
-- Ported from UT6 Sandbox

local equipment = {
    { text = "Ammo Bag", value = "ammo-bag" },
    { text = "Doctor Bag", value = "doctor-bag" },
    { text = "First Aid Kit", value = "first-aid-kit" },
    { text = "Body Bag Case", value = "body-bag-case" },
    { text = "ECM Jammer", value = "ecm-jammer" },
    { text = "Trip Mine", value = "trip-mine" },
    { text = "Sentry Gun", value = "sentry-gun" },
    { text = "Suppressed Sentry", value = "suppressed-sentry-gun" }
}

local items = {
    { text = "Keycard", value = "bank_manager_key" },
    { text = "Crowbar", value = "crowbar" },
    { text = "Planks", value = "boards" },
    { text = "Acid", value = "acid" },
    { text = "Thermite", value = "thermite" }
}

local function get_spawn_pos_rot()
    local pos = nil
    local rot = Rotation(0, 0, 0)
    
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return pos, rot end
    local cam = player:camera()
    if not cam then return pos, rot end

    if NiceTrainer.Settings.spawner_pos_type == 1 then
        local from = cam:position()
        local mvec_to = Vector3()
        mvector3.set(mvec_to, cam:forward())
        mvector3.multiply(mvec_to, 2000)
        mvector3.add(mvec_to, from)
        local ray = World:raycast("ray", from, mvec_to, "slot_mask", managers.slot:get_mask("all"))
        if ray then
            pos = ray.hit_position
            rot = Rotation(ray.normal, math.UP)
        end
    else
        pos = player:position()
        rot = Rotation(cam:rotation():yaw(), 0, 0)
    end
    return pos, rot
end

NiceTrainer:RegisterAction("Spawner", {
    type = "modal",
    category = "Equipment & Items",
    id = "spawner_equipment",
    text = "Spawn Deployable",
    modal_title = "Select Deployable to Spawn",
    action_btn_text = "Select...",
    options = equipment,
    callback = function(val, text)
        local pos, rot = get_spawn_pos_rot()
        if not pos then
            NiceTrainer:Toast("Could not determine spawn position.")
            return
        end

        local player = managers.player:player_unit()
        local peer_id = managers.network:session():local_peer():id()

        local amount = NiceTrainer.Settings.spawner_quantity or 1
        local spawned_count = 0

        for i = 1, amount do
            pcall(function()
                if val == "ammo-bag" then
                    AmmoBagBase.spawn(pos, rot, 1, peer_id, 2)
                    spawned_count = spawned_count + 1
                elseif val == "doctor-bag" then
                    DoctorBagBase.spawn(pos, rot, 20, peer_id)
                    spawned_count = spawned_count + 1
                elseif val == "first-aid-kit" then
                    FirstAidKitBase.spawn(pos, rot, 20, peer_id)
                    spawned_count = spawned_count + 1
                elseif val == "body-bag-case" then
                    BodyBagsBagBase.spawn(pos, rot, 0, peer_id)
                    spawned_count = spawned_count + 1
                elseif val == "ecm-jammer" then
                    managers.mission:call_global_event("player_deploy_ecmjammer")
                    local unit = ECMJammerBase.spawn(pos, rot, 3, player, peer_id)
                    if unit then
                        unit:base():set_active(true)
                        unit:base()._check_body = function() end
                        spawned_count = spawned_count + 1
                    end
                elseif val == "trip-mine" then
                    local unit = TripMineBase.spawn(pos, rot, true, peer_id)
                    if unit then
                        unit:base():set_active(true, player)
                        spawned_count = spawned_count + 1
                    end
                elseif val == "sentry-gun" or val == "suppressed-sentry-gun" then
                    local shield = managers.player:has_category_upgrade("sentry_gun", "shield")
                    local ammo = managers.player:upgrade_value("sentry_gun", "extra_ammo_multiplier", 1)
                    local is_suppressed = val == "suppressed-sentry-gun"
                    local unit, spread, rot_speed = SentryGunBase.spawn(player, pos, rot, peer_id, false, is_suppressed and 2 or 1)
                    if unit then
                        managers.network:session():send_to_peers_synched("from_server_sentry_gun_place_result", peer_id, 0, unit, rot_speed, spread, shield, ammo, 1)
                        unit:event_listener():call("on_setup", true)
                        unit:base():post_setup(1)
                        spawned_count = spawned_count + 1
                    end
                end
            end)
        end
        NiceTrainer:Toast("Spawned " .. tostring(spawned_count) .. "x: " .. text)
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type = "modal",
    category = "Equipment & Items",
    id = "spawner_items",
    text = "Give Special Item",
    modal_title = "Select Item to Add",
    action_btn_text = "Select...",
    options = items,
    callback = function(val, text)
        local amount = NiceTrainer.Settings.spawner_quantity or 1
        managers.player:add_special({name = val, amount = amount, silent = false})
        NiceTrainer:Toast("Added " .. tostring(amount) .. "x " .. text)
    end
})
