-- Suit Flashlight integration for NiceTrainer (Visuals Tab)

if not _G.SuitFlashlight then
    _G.SuitFlashlight = {}
    
    local mod_path = (NiceTrainer and NiceTrainer.ModPath) or ModPath or "mods/NiceTrainer/"
    SuitFlashlight._mod_path = mod_path
    SuitFlashlight._assets_path = mod_path .. "assets/"
    SuitFlashlight._texture_normal = "units/lights/spot_light_projection_textures/spotprojection_11_flashlight_df"
    SuitFlashlight._range = 800
    SuitFlashlight._angle = 75
    SuitFlashlight._light_multiplier = 0.9
    SuitFlashlight._light_on = false
    SuitFlashlight._light_obj = nil
    SuitFlashlight._bouncelight_obj = nil

    SuitFlashlight.settings = {
        a_offset_x = -20,
        a_offset_y = 0,
        a_offset_z = -35,
        a_offset_yaw = -1,
        a_offset_pitch = 90,
        a_offset_roll = 0,
        sound_enabled = true,
        light_color = "fff7dc"
    }

    function SuitFlashlight:Save()
        if NiceTrainer and NiceTrainer.Save then
            NiceTrainer:Save()
        end
    end

    function SuitFlashlight:Load()
        if NiceTrainer and NiceTrainer.Settings then
            if NiceTrainer.Settings.suit_flashlight_color then
                self.settings.light_color = string.gsub(NiceTrainer.Settings.suit_flashlight_color, "^#", "")
            end
            if NiceTrainer.Settings.suit_flashlight_sound ~= nil then
                self.settings.sound_enabled = NiceTrainer.Settings.suit_flashlight_sound
            end
        end
    end

    function SuitFlashlight:GetOffsetPos()
        local s = self.settings
        return Vector3(s.a_offset_x, s.a_offset_y, s.a_offset_z)
    end

    function SuitFlashlight:GetOffsetRot()
        local s = self.settings
        return Rotation(s.a_offset_yaw, s.a_offset_pitch, s.a_offset_roll)
    end

    function SuitFlashlight:AddFlashlight(state, bounce_light_enabled)
        local player = managers.player and managers.player:local_player()
        if alive(player) and player:camera() then 
            local texture = self._texture_normal
            local bounce_light
            local light = World:create_light("spot|specular|plane_projection", texture)
            light:set_spot_angle_end(self._angle)
            light:set_far_range(self._range)
            
            local a_obj = player:camera():camera_object()
            if a_obj then
                light:link(a_obj)
                local rot = self:GetOffsetRot()
                light:set_local_rotation(rot)
                local pos = self:GetOffsetPos()
                light:set_local_position(pos)
                local col_str = self.settings.light_color or "fff7dc"
                local color = Color(col_str)
                local vec3_col = Vector3(color.r, color.g, color.b)
                light:set_color(vec3_col)
                light:set_multiplier(self._light_multiplier)
                
                if bounce_light_enabled then
                    bounce_light = World:create_light("spot|specular|plane_projection", self._texture_normal)
                    bounce_light:link(a_obj)
                    bounce_light:set_spot_angle_end(80)
                    bounce_light:set_far_range(200)
                    local bounce_rot = rot:inverse()
                    bounce_light:set_color(vec3_col)
                    bounce_light:set_multiplier(10 * self._light_multiplier)
                    local new_rot = Rotation(
                        bounce_rot:yaw() + 90,
                        bounce_rot:pitch() + 0,
                        bounce_rot:roll() + 0
                    )
                    bounce_light:set_local_rotation(new_rot)
                    bounce_light:set_local_position(Vector3(-170, 20, -7))
                end
            end
            
            if state ~= nil then
                light:set_enable(state)
                if bounce_light then
                    bounce_light:set_enable(state)
                end
            end
            
            return light, bounce_light
        end
    end

    function SuitFlashlight:RemoveFlashlight()
        self._light_on = false
        
        if alive(self._light_obj) then 
            World:delete_light(self._light_obj)
        end
        self._light_obj = nil
        
        if alive(self._bouncelight_obj) then
            World:delete_light(self._bouncelight_obj)
        end
        self._bouncelight_obj = nil
    end

    function SuitFlashlight:ToggleLight(force_state)
        local state = not self._light_on
        if force_state ~= nil then 
            state = force_state
        end
        self._light_on = state
        
        local player = managers.player and managers.player:local_player()
        if not alive(player) then 
            self:RemoveFlashlight()
            return
        end
        
        if not state then
            if alive(self._light_obj) or alive(self._bouncelight_obj) then
                if self.settings.sound_enabled and player.sound_source and player:sound_source() then
                    player:sound_source():post_event("gadget_flashlight_off")
                end
                self:RemoveFlashlight()
            end
            return
        end

        if self.settings.sound_enabled and player.sound_source and player:sound_source() then
            player:sound_source():post_event("gadget_flashlight_on")
        end
        
        if alive(self._light_obj) then 
            self._light_obj:set_enable(true)
            if alive(self._bouncelight_obj) then
                self._bouncelight_obj:set_enable(true)
            end
        else
            local light, bounce_light = self:AddFlashlight(true, true)
            self._light_obj = light
            self._bouncelight_obj = bounce_light
        end
    end

    function SuitFlashlight:SetLightColor(color)
        if alive(self._light_obj) then 
            local vec3_col = Vector3(color.r, color.g, color.b)
            self._light_obj:set_color(vec3_col)
            if alive(self._bouncelight_obj) then
                self._bouncelight_obj:set_color(vec3_col)
            end
        end
    end

    SuitFlashlight:Load()
end

-- Custody & cleanup hook
if _G.PlayerManager and not _G.NiceTrainer_SuitFlashlight_CustodyHooked then
    _G.NiceTrainer_SuitFlashlight_CustodyHooked = true
    Hooks:PostHook(PlayerManager, "check_skills", "NiceTrainer_SuitFlashlight_CustodyHook", function(self)
        if self._listener_holder and self._custody_state then
            self._listener_holder:remove("suitflashlight_onentercustody")
            self._listener_holder:add("suitflashlight_onentercustody", { self._custody_state }, function()
                SuitFlashlight:RemoveFlashlight()
            end)
        end
    end)
end

-- Action Registrations for Visuals Tab
if NiceTrainer and NiceTrainer.RegisterAction then
    NiceTrainer:RegisterAction("Visuals", {
        type = "toggle", category = "Suit Flashlight", badge = "client", id = "suit_flashlight_toggle", text = "Suit Flashlight",
        tooltip = "Turn your suit-mounted flashlight on or off.",
        default = false, save = false,
        callback = function(state)
            SuitFlashlight:ToggleLight(state)
        end
    })

    NiceTrainer:RegisterAction("Visuals", {
        type = "colorpicker", category = "Suit Flashlight", id = "suit_flashlight_color", text = "Flashlight Color",
        tooltip = "Choose the beam color of your suit flashlight.",
        default = "#FFF7DC", save = true,
        callback = function(color, hex)
            local raw_hex = string.gsub(hex or "FFF7DC", "^#", "")
            SuitFlashlight.settings.light_color = raw_hex
            SuitFlashlight:SetLightColor(Color(raw_hex))
            SuitFlashlight:Save()
        end
    })

    NiceTrainer:RegisterAction("Visuals", {
        type = "button", category = "Suit Flashlight", badge = "client", text = "Unstuck Flashlight",
        tooltip = "Removes and resets any orphaned or stuck flashlight objects.",
        action_btn_text = "Reset",
        callback = function()
            SuitFlashlight:RemoveFlashlight()
            NiceTrainer:Toast("Suit Flashlight Reset!")
        end
    })

    NiceTrainer:RegisterAction("Visuals", {
        type = "toggle", category = "Suit Flashlight", id = "suit_flashlight_sound", text = "Flashlight Sounds",
        tooltip = "Plays clicking sound when turning the flashlight on or off.",
        default = true, save = true,
        callback = function(state)
            SuitFlashlight.settings.sound_enabled = state
            SuitFlashlight:Save()
        end
    })
end

