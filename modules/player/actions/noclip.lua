-- Noclip (Fly Mode) for Player Tab

local zero_vel = Vector3(0, 0, 0)
local noclip_speed = 20
local noclip_enabled = false
local noclip_kb = Input:keyboard()

local function in_active_mission()
    local state = game_state_machine and game_state_machine:current_state_name()
    return state ~= nil and string.find(state, "game") ~= nil
end

local function apply_noclip(enabled)
    noclip_enabled = enabled
end

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_NoclipLoop", function(t, dt)
    if not noclip_enabled then return end
    if not in_active_mission() then return end
    if not managers.player then return end

    local player = managers.player:player_unit()
    if not alive(player) then return end
    
    local cam = player:camera()
    if not cam then return end
    
    local camera_rot = cam:rotation()

    local x = (noclip_kb:down(Idstring("d")) and noclip_speed or 0) - (noclip_kb:down(Idstring("a")) and noclip_speed or 0)
    local y = (noclip_kb:down(Idstring("w")) and noclip_speed or 0) - (noclip_kb:down(Idstring("s")) and noclip_speed or 0)
    local z = (noclip_kb:down(Idstring("space")) and noclip_speed or 0) - (noclip_kb:down(Idstring("left ctrl")) and noclip_speed or 0)

    local new_pos = player:position()
    if x ~= 0 or y ~= 0 or z ~= 0 then
        local move = camera_rot:x() * x + camera_rot:y() * y + math.UP * z
        new_pos = new_pos + move
    end
    managers.player:warp_to(new_pos, camera_rot, 1, zero_vel)
end)

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Movement",
    badge    = "client",
    id       = "noclip",
    text     = "Noclip",
    save     = false,
    tooltip  = "Fly freely through the level using WASD and Space/Ctrl.",
    default  = false,
    callback = apply_noclip
})
