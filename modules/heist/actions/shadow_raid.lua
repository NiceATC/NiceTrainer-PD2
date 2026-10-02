-- Shadow Raid specific scripts
local function fire_mission_element(elem_id)
    if not managers.mission then return end
    for _, data in pairs(managers.mission._scripts) do
        for id, element in pairs(data:elements()) do
            if id == elem_id then
                if Network:is_server() then
                    element:on_executed()
                else
                    managers.network:session():send_to_host("to_server_mission_element_trigger", element:id(), managers.player:player_unit())
                end
            end
        end
    end
end

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Shadow Raid (kosugi)",
    level_id = { "kosugi", "shadow_raid" },
    badge = "client",
    text = "Spawn Artifact Helicopter",
    tooltip = "Spawns the Shadow Raid mission's escape helicopter early to drop an artifact (works as host and client).",
    callback = function()
        fire_mission_element(101219)
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Shadow Raid (kosugi)",
    level_id = { "kosugi", "shadow_raid" },
    badge = "client",
    text = "[TROLL] Spawn 10 Roof Guards",
    tooltip = "Spawns 10 extra guards on the roof in Shadow Raid -- makes things harder, meant as a prank (works as host and client).",
    callback = function()
        for i = 1, 4 do
            fire_mission_element(101130)
        end
    end
})
