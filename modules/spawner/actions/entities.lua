-- Entities Spawner for NiceTrainer
-- Ported from UT6 Sandbox

local entities = {
    { text = "Cop 1", value = "units/payday2/characters/ene_cop_1/ene_cop_1" },
    { text = "Cop 2", value = "units/payday2/characters/ene_cop_2/ene_cop_2" },
    { text = "Cop 3", value = "units/payday2/characters/ene_cop_3/ene_cop_3" },
    { text = "Cop 4", value = "units/payday2/characters/ene_cop_4/ene_cop_4" },
    { text = "FBI 1", value = "units/payday2/characters/ene_fbi_1/ene_fbi_1" },
    { text = "FBI 2", value = "units/payday2/characters/ene_fbi_2/ene_fbi_2" },
    { text = "FBI 3", value = "units/payday2/characters/ene_fbi_3/ene_fbi_3" },
    { text = "FBI Heavy", value = "units/payday2/characters/ene_fbi_heavy_1/ene_fbi_heavy_1" },
    { text = "SWAT 1", value = "units/payday2/characters/ene_fbi_swat_1/ene_fbi_swat_1" },
    { text = "SWAT 2", value = "units/payday2/characters/ene_fbi_swat_2/ene_fbi_swat_2" },
    { text = "SWAT Heavy", value = "units/payday2/characters/ene_swat_heavy_1/ene_swat_heavy_1" },
    { text = "Shield 1", value = "units/payday2/characters/ene_shield_1/ene_shield_1" },
    { text = "Shield 2", value = "units/payday2/characters/ene_shield_2/ene_shield_2" },
    { text = "Tazer", value = "units/payday2/characters/ene_tazer_1/ene_tazer_1" },
    { text = "Cloaker", value = "units/payday2/characters/ene_spook_1/ene_spook_1" },
    { text = "Bulldozer", value = "units/payday2/characters/ene_bulldozer_1/ene_bulldozer_1" },
    { text = "Sniper", value = "units/payday2/characters/ene_sniper_1/ene_sniper_1" },
    { text = "Medic", value = "units/payday2/characters/ene_medic_r870/ene_medic_r870" }
}

-- Default settings
NiceTrainer.Settings.spawner_pos_type = NiceTrainer.Settings.spawner_pos_type or 1 -- 1 = Crosshair, 2 = Player
NiceTrainer.Settings.spawner_converted = NiceTrainer.Settings.spawner_converted or false

local function get_spawn_pos_rot()
    local pos = nil
    local rot = Rotation(0, 0, 0)
    
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return pos, rot end

    local cam = player:camera()
    if not cam then return pos, rot end

    if NiceTrainer.Settings.spawner_pos_type == 1 then
        -- Crosshair
        local from = cam:position()
        local mvec_to = Vector3()
        mvector3.set(mvec_to, cam:forward())
        mvector3.multiply(mvec_to, 20000)
        mvector3.add(mvec_to, from)
        local ray = World:raycast("ray", from, mvec_to, "slot_mask", managers.slot:get_mask("all"))
        if ray then
            pos = ray.hit_position
        end
        rot = Rotation(cam:rotation():yaw(), 0, 0)
    else
        -- On Player
        pos = player:position()
        rot = Rotation(cam:rotation():yaw(), 0, 0)
    end

    return pos, rot
end

NiceTrainer:RegisterAction("Spawner", {
    type = "multichoice",
    category = "Settings",
    id = "spawner_pos",
    text = "Spawn Location",
    options = { "On Crosshair", "On Player" },
    default = NiceTrainer.Settings.spawner_pos_type,
    callback = function(idx, val)
        NiceTrainer.Settings.spawner_pos_type = idx
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type = "toggle",
    category = "Settings",
    id = "spawner_converted",
    text = "Spawn as Joker (Converted)",
    default = NiceTrainer.Settings.spawner_converted,
    callback = function(state)
        NiceTrainer.Settings.spawner_converted = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type = "slider",
    category = "Settings",
    id = "spawner_quantity",
    text = "Spawn Quantity",
    min = 1,
    max = 10,
    default = NiceTrainer.Settings.spawner_quantity or 1,
    callback = function(val)
        NiceTrainer.Settings.spawner_quantity = val
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Spawner", {
    type = "modal",
    category = "Entities",
    id = "spawner_entity",
    text = "Spawn Enemy",
    modal_title = "Select Entity to Spawn",
    action_btn_text = "Select...",
    options = entities,
    callback = function(val, text)
        local pos, rot = get_spawn_pos_rot()
        if not pos then
            NiceTrainer:Toast("Could not determine spawn position.")
            return
        end

        local unit_id = Idstring(val)
        if not PackageManager:has(Idstring("unit"), unit_id) then
            NiceTrainer:Toast("Unit not loaded by map.")
            return
        end

        local amount = NiceTrainer.Settings.spawner_quantity or 1
        local spawned_count = 0

        for i = 1, amount do
            local unit = World:spawn_unit(unit_id, pos, rot)
            if alive(unit) then
                -- Force combatant team
                local team_id = tweak_data.levels:get_default_team_ID("combatant")
                unit:movement():set_team(managers.groupai:state():team_data(team_id))

                -- Convert if setting is enabled
                if NiceTrainer.Settings.spawner_converted and managers.groupai:state().convert_hostage_to_criminal then
                    -- Spoof upgrade to allow unlimited jokers briefly
                    local orig_upgrade = managers.player.has_category_upgrade
                    managers.player.has_category_upgrade = function() return true end
                    pcall(function()
                        managers.groupai:state():convert_hostage_to_criminal(unit)
                    end)
                    managers.player.has_category_upgrade = orig_upgrade
                end
                spawned_count = spawned_count + 1
            end
        end
        NiceTrainer:Toast("Spawned " .. tostring(spawned_count) .. "x: " .. text)
    end
})
