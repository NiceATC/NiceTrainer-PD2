-- Bhop Physics Engine for Player Tab

NiceTrainer._orig_player_standard = NiceTrainer._orig_player_standard or {}

local function apply_bhop(enabled)
    if not _G.PlayerStandard then return end
    if enabled then
        if not NiceTrainer._orig_player_standard.get_input_bhop then
            NiceTrainer._orig_player_standard.get_input_bhop = PlayerStandard._get_input
            PlayerStandard._get_input = function(self, t, dt, ...)
                local input = NiceTrainer._orig_player_standard.get_input_bhop(self, t, dt, ...)
                if self._controller and self._controller:get_input_bool("jump") then
                    input.btn_jump_press = true
                end
                return input
            end
        end

        if not NiceTrainer._orig_player_standard.get_max_walk_speed_bhop then
            NiceTrainer._orig_player_standard.get_max_walk_speed_bhop = PlayerStandard._get_max_walk_speed
            PlayerStandard._get_max_walk_speed = function(self, ...)
                local is_standing = self._unit and self._unit:mover() and self._unit:mover():standing()
                if not self._on_ground and not is_standing and self._state_data and self._state_data.in_air then
                    local vel_z = self._unit:mover() and self._unit:mover():velocity().z or 0
                    if math.abs(vel_z) > 10 then
                        return 10000
                    end
                end
                return NiceTrainer._orig_player_standard.get_max_walk_speed_bhop(self, ...)
            end
        end

        if not NiceTrainer._orig_player_standard.update_movement_bhop then
            NiceTrainer._orig_player_standard.update_movement_bhop = PlayerStandard._update_movement
            PlayerStandard._update_movement = function(self, t, dt)
                self._last_frame_velocity = self._last_frame_velocity or Vector3()

                local mover = self._unit and self._unit:mover()
                if not mover then
                    return NiceTrainer._orig_player_standard.update_movement_bhop(self, t, dt)
                end

                local is_jumping = self._controller and self._controller:get_input_bool("jump")
                local is_really_on_ground = self._on_ground

                if not is_really_on_ground then
                    local pos = self._unit:position()
                    local ray = World:raycast("ray", pos, pos + Vector3(0, 0, -20), "slot_mask", managers.slot:get_mask("world_geometry"))
                    if ray then
                        is_really_on_ground = true
                    end
                end

                local groundSpeedThreshold = 450

                if not is_jumping and is_really_on_ground then
                    local res = NiceTrainer._orig_player_standard.update_movement_bhop(self, t, dt)
                    local current_vel = mover:velocity()
                    local h_vel = Vector3(current_vel.x, current_vel.y, 0)
                    local speed = mvector3.length(h_vel)

                    if speed > groundSpeedThreshold + 50 then
                        mvector3.normalize(h_vel)
                        mvector3.multiply(h_vel, groundSpeedThreshold)
                        local clamped_vel = Vector3(h_vel.x, h_vel.y, current_vel.z)
                        mover:set_velocity(clamped_vel)
                        self._last_frame_velocity = clamped_vel
                    else
                        self._last_frame_velocity = current_vel
                    end
                    return res
                end

                if self._on_ground then
                    local res = NiceTrainer._orig_player_standard.update_movement_bhop(self, t, dt)
                    local current_vel = mover:velocity()

                    if is_jumping then
                        local saved_h = Vector3(self._last_frame_velocity.x, self._last_frame_velocity.y, 0)
                        local saved_speed = mvector3.length(saved_h)
                        local current_h = Vector3(current_vel.x, current_vel.y, 0)
                        local current_speed = mvector3.length(current_h)

                        if saved_speed > groundSpeedThreshold + 50 and saved_speed > current_speed then
                            local restored = Vector3(self._last_frame_velocity.x, self._last_frame_velocity.y, current_vel.z)
                            mover:set_velocity(restored)
                            self._last_frame_velocity = restored
                        else
                            self._last_frame_velocity = current_vel
                        end
                    else
                        self._last_frame_velocity = current_vel
                    end
                    return res
                end

                local airAccel = tonumber(NiceTrainer.Settings.bhop_air_accel) or 1000
                local maxAirSpeed = tonumber(NiceTrainer.Settings.bhop_max_air_speed) or 100
                local speedCap = tonumber(NiceTrainer.Settings.bhop_speed_cap) or 3500

                local wishdir = Vector3()
                local input = self._controller and self._controller:get_input_axis("move")
                if input and self._unit:camera() then
                    local fwd = self._unit:camera():forward()
                    local right = self._unit:camera():right()
                    fwd = Vector3(fwd.x, fwd.y, 0):normalized()
                    right = Vector3(right.x, right.y, 0):normalized()
                    wishdir = (fwd * input.y + right * input.x)
                    wishdir = Vector3(wishdir.x, wishdir.y, 0)
                    if mvector3.length(wishdir) > 0.001 then
                        mvector3.normalize(wishdir)
                    else
                        wishdir = Vector3()
                    end
                end

                local res = NiceTrainer._orig_player_standard.update_movement_bhop(self, t, dt)
                local current_vel = mover:velocity()
                local h_vel = Vector3(current_vel.x, current_vel.y, 0)

                if mvector3.length(wishdir) > 0.001 then
                    local cur_proj = mvector3.dot(h_vel, wishdir)
                    local add_speed = maxAirSpeed - cur_proj

                    if add_speed > 0 then
                        local accel_speed = airAccel * dt * maxAirSpeed
                        if accel_speed > add_speed then
                            accel_speed = add_speed
                        end
                        h_vel = h_vel + wishdir * accel_speed
                    end
                end

                local new_speed = mvector3.length(h_vel)
                if new_speed > speedCap then
                    mvector3.normalize(h_vel)
                    mvector3.multiply(h_vel, speedCap)
                end

                local final_vel = Vector3(h_vel.x, h_vel.y, current_vel.z)
                mover:set_velocity(final_vel)
                self._last_frame_velocity = final_vel

                return res
            end
        end
    else
        if NiceTrainer._orig_player_standard.get_input_bhop then
            PlayerStandard._get_input = NiceTrainer._orig_player_standard.get_input_bhop
            NiceTrainer._orig_player_standard.get_input_bhop = nil
        end
        if NiceTrainer._orig_player_standard.get_max_walk_speed_bhop then
            PlayerStandard._get_max_walk_speed = NiceTrainer._orig_player_standard.get_max_walk_speed_bhop
            NiceTrainer._orig_player_standard.get_max_walk_speed_bhop = nil
        end
        if NiceTrainer._orig_player_standard.update_movement_bhop then
            PlayerStandard._update_movement = NiceTrainer._orig_player_standard.update_movement_bhop
            NiceTrainer._orig_player_standard.update_movement_bhop = nil
        end
    end
end

NiceTrainer:RegisterAction("Player", { 
    type = "toggle_settings", 
    category = "Movement", 
    badge = "client", 
    id = "bhop", 
    text = "Bhop Engine", 
    tooltip = "Enable UT6 Bunnyhop physics. Click settings icon to configure.", 
    default = false, 
    callback = apply_bhop,
    settings_callback = function()
        local options = {
            { text = "Air Accelerate: " .. tostring(NiceTrainer.Settings.bhop_air_accel or 1000), value = "accel" },
            { text = "Max Air Speed: " .. tostring(NiceTrainer.Settings.bhop_max_air_speed or 100), value = "max_speed" },
            { text = "Speed Cap: " .. tostring(NiceTrainer.Settings.bhop_speed_cap or 3500), value = "cap" }
        }
        NiceTrainer:ShowModal("Bhop Settings", options, function(val)
            if val == "accel" then
                NiceTrainer:ShowSliderModal("Air Accelerate", 100, 5000, NiceTrainer.Settings.bhop_air_accel or 1000, function(v)
                    NiceTrainer.Settings.bhop_air_accel = math.floor(v)
                    NiceTrainer:Save()
                end)
            elseif val == "max_speed" then
                NiceTrainer:ShowSliderModal("Max Air Speed", 10, 1000, NiceTrainer.Settings.bhop_max_air_speed or 100, function(v)
                    NiceTrainer.Settings.bhop_max_air_speed = math.floor(v)
                    NiceTrainer:Save()
                end)
            elseif val == "cap" then
                NiceTrainer:ShowSliderModal("Speed Cap", 1000, 10000, NiceTrainer.Settings.bhop_speed_cap or 3500, function(v)
                    NiceTrainer.Settings.bhop_speed_cap = math.floor(v)
                    NiceTrainer:Save()
                end)
            end
        end)
    end
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_Bhop_Load", function()
    if NiceTrainer.Settings.bhop then apply_bhop(true) end
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_Bhop_GameUpdate", function()
    if NiceTrainer.Settings.bhop then apply_bhop(true) end
end)
