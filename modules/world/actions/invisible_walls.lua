-- ─── Invisible Walls & Boundaries for NiceTrainer (World Tab) ────────────────
-- Features: View Invisible Collision Walls (renders them visible),
-- and Remove / Ignore Invisible Walls (disables collision or removes blockers).
-- Ported and modernized from HexTrainer / Pirate Perfection.

local INVISIBLE_WALL_HASHES = {
    ["276de19dc5541f30"] = true, -- units/dev_tools/level_tools/dev_collision_1m_2
    ["e379cc9592197cd8"] = true, -- units/dev_tools/level_tools/dev_collision_1m_2_bag
    ["8f3cb89b79b42ec4"] = true, -- units/dev_tools/level_tools/dev_collision_4m
    ["6cdb4f6f58ec4fa8"] = true, -- units/dev_tools/level_tools/dev_collision_4m_bag
    ["7ae8fcbfe6a00f7b"] = true, -- units/dev_tools/level_tools/dev_collision_5m
    ["85462a64da94ee78"] = true, -- units/dev_tools/level_tools/dev_collision_5m_bag
    ["7a4c85917d8d8323"] = true, -- units/dev_tools/level_tools/dev_collision_10m
    ["b37a4188fde4c161"] = true, -- units/dev_tools/level_tools/dev_collision_10m_bag
    ["7b91ae618eadbe49"] = true, -- units/dev_tools/level_tools/dev_nav_blocker_vehicle_sedan
    ["01c78e4ef0340674"] = true, -- units/dev_tools/level_tools/navigation_blocker
    ["adea0368e2fee02b"] = true, -- units/dev_tools/level_tools/navigation_blocker_1
    ["42370b3a7b92f537"] = true, -- units/dev_tools/level_tools/navigation_blocker_10
    ["39d0838c190f1540"] = true, -- units/dev_tools/level_tools/navigation_blocker_20
    ["cacb76e8e1d7e2f3"] = true, -- units/dev_tools/level_tools/navigation_blocker_50
    ["c746af9ae100c837"] = true, -- units/dev_tools/level_tools/navigation_blocker_hlf
    ["75baea8dccabc8d5"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_1x1m
    ["4027cbad1f8d5b37"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_1x3m
    ["9b2fcf39f23e2344"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_4x3m
    ["d678a2a41e3f1bfb"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_4x32m
    ["0fe54fe3af59d86c"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_8x3m
    ["2854ee0748613f72"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_8x32m
    ["16dde5dd77259b35"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_16x32m
    ["8969155cb42a67cc"] = true, -- units/dev_tools/level_tools/dev_bag_collision/dev_bag_collision_64x32m
    ["c5c4442c5e147cb0"] = true, -- units/dev_tools/level_tools/collision/dev_collision_1m/dev_collision_1m
    ["9eda9e73ac0ef710"] = true, -- units/dev_tools/level_tools/collision/dev_collision_1m/dev_collision_1m_bag
    ["673ea142d68175df"] = true, -- units/dev_tools/level_tools/collision/dev_collision_20m/dev_collision_20m
    ["260a42b4809c08dc"] = true, -- units/dev_tools/level_tools/collision/dev_collision_20m/dev_collision_20m_bag
    ["9d8b22836aa015ed"] = true, -- units/dev_tools/level_tools/collision/dev_collision_50m/dev_collision_50m
    ["78f4407343b48f6d"] = true, -- units/dev_tools/level_tools/collision/dev_collision_50m/dev_collision_50m_bag
    ["96eba158d67240f6"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_1x1m
    ["a3649015ec10f0fa"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_1x3m
    ["6cb6040856588734"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_4x3m
    ["97e8d510fc7f6b4b"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_4x32m
    ["99792495ba726698"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_8x3m
    ["e765f9d63549a5c5"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_8x32m
    ["093021865a2c35af"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_16x32m
    ["a5bab566e1733d44"] = true, -- units/dev_tools/level_tools/dev_collision/dev_collision_64x32m
    ["3345b74c3081f3f9"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x1m
    ["f9639a083eb4eb0c"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x1x3m
    ["8f0bd5d3ce8adf20"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_1x3m
    ["120d0ca08375e85e"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_2x3m
    ["d6ab68fdfb25156e"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_4x3m
    ["77175ed91c87d38a"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_8x3m
    ["89a7dbeb98bb47fb"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_16x3m
    ["67e5497920d65b45"] = true, -- units/dev_tools/level_tools/dev_nav_blocker/dev_nav_blocker_64x3m
    ["4385cb1d46044948"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_1x1m
    ["75d60c30cfc752d5"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_1x3m
    ["6e94e532295a1c4c"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_4x3m
    ["b7dd69c3082ad494"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_4x32m
    ["03996689587afc9c"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_8x3m
    ["fe7682409496395c"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_8x32m
    ["20a34b41ca06015c"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_16x32m
    ["70fbfdaf5e1c50a1"] = true, -- units/dev_tools/level_tools/dev_vehicle_collision/dev_vehicle_collision_64x32m
    ["cbeb471aa32636ea"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_1x1m
    ["7c6a421c90a8709a"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_1x3m
    ["fe13549df62eab40"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_4x3m
    ["df37c0dd7a9e1392"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_4x32m
    ["887ceed0e322a202"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_8x3m
    ["b1f9779228aff5cf"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_8x32m
    ["ea53e01e72a77431"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_16x32m
    ["31245608e2096b2a"] = true, -- units/dev_tools/level_tools/dev_vehicle_only_collision/dev_vehicle_only_collision_64x32m
    ["29d0139549a54de7"] = true,
    ["53a9a98f72835230"] = true,
    ["63be2c801283f573"] = true,
    ["673cff4d49da2368"] = true,
    ["86efb80bf784046f"] = true,
    ["e8fe662bb4d262d3"] = true,
}

local function apply_display_invisible_walls(state)
    if not World then return end
    local count = 0
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all", 1)) do
            if alive(unit) and INVISIBLE_WALL_HASHES[unit:name():key()] then
                unit:set_visible(state)
                count = count + 1
            end
        end
    end)
end

local function apply_remove_invisible_walls()
    if not World then return end
    local count = 0
    local session = managers.network and managers.network:session()

    pcall(function()
        for _, unit in pairs(World:find_units_quick("all", 1)) do
            if alive(unit) and INVISIBLE_WALL_HASHES[unit:name():key()] then
                if session and session.send_to_peers then
                    pcall(function() session:send_to_peers("remove_unit", unit) end)
                end
                unit:set_slot(0)
                count = count + 1
            end
        end
    end)
    NiceTrainer:Toast(string.format("Removed %d invisible wall collision blockers!", count))
end

-- ============================================================================
-- Registration in World Tab
-- ============================================================================

NiceTrainer:RegisterAction("World", {
    type     = "toggle",
    category = "Map & Environment",
    badge    = "client",
    id       = "display_invisible_walls",
    text     = "View Invisible Walls",
    tooltip  = "Highlights and renders all invisible boundary and collision walls in the level so you can see map limits.",
    default  = false,
    callback = apply_display_invisible_walls
})

NiceTrainer:RegisterAction("World", {
    type            = "button",
    category        = "Map & Environment",
    badge           = "client",
    id              = "remove_invisible_walls",
    text            = "Remove / Ignore Invisible Walls",
    tooltip         = "Permanently destroys and removes all invisible map collision barriers for the current heist, allowing free traversal and throwing bags outside normal borders.",
    action_btn_text = "Remove Walls",
    callback        = apply_remove_invisible_walls
})
