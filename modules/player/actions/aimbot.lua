local aimbot_running = false
local aim_rotation = nil
local aimbot_ws
local aimbot_panel
local fov_circle

local function build_circle_points(radius, segments, cx, cy)
    local points = {}
    for i = 0, segments do
        local a = (i / segments) * 360
        local x = math.cos(a) * radius + cx
        local y = math.sin(a) * radius + cy
        table.insert(points, Vector3(x, y, 0))
    end
    return points
end

local function update_fov_circle()
    if aimbot_ws and not alive(aimbot_ws) then
        aimbot_ws = nil
        aimbot_panel = nil
        fov_circle = nil
    end

    if not aimbot_ws then
        if managers.gui_data then
            aimbot_ws = managers.gui_data:create_saferect_workspace()
            aimbot_panel = aimbot_ws:panel():panel()
            fov_circle = aimbot_panel:polyline({
                color = Color.white,
                line_width = 1.5,
                alpha = 0.3,
                layer = 9999,
                closed = true
            })
        end
    end
    
    if not fov_circle then return end
    
    local show = NiceTrainer.Settings.aimbot_draw_fov and aimbot_running
    
    if NiceTrainer.IsOpen then
        show = false
    end
    
    if show and NiceTrainer.Settings.aimbot_require_ads then
        local player = managers.player and managers.player:player_unit()
        if alive(player) then
            local state = player:movement():current_state()
            if not state or not state._state_data or not state._state_data.in_steelsight then
                show = false
            end
        else
            show = false
        end
    end

    fov_circle:set_visible(show)
    
    if show then
        local player = managers.player and managers.player:player_unit()
        if alive(player) then
            local camera = player:camera()
            local current_fov = camera._camera_object and camera._camera_object:fov() or 90
            local fov_deg = tonumber(NiceTrainer.Settings.aimbot_fov) or 10
            
            local pixel_per_deg = aimbot_panel:w() / current_fov
            local radius = fov_deg * pixel_per_deg
            
            fov_circle:set_points(build_circle_points(radius, 60, aimbot_panel:w() / 2, aimbot_panel:h() / 2))
        end
    end
end

-- ==========================================
-- SILENT AIM LOGIC (YALOKGAR APPROACH)
-- ==========================================

local function calculate_angle(player, enemy_head_pos)
    local direction = enemy_head_pos - player
    mvector3.normalize(direction)
    return direction
end

local function is_valid_enemy(enemy_unit)
    if not alive(enemy_unit) then return false end
    local brain = enemy_unit:brain()
    if not brain or brain:surrendered() then return false end
    if brain._logic_data and brain._logic_data.is_converted then return false end
    local damage = enemy_unit:character_damage()
    if damage and damage.dead and damage:dead() then return false end
    local movement = enemy_unit:movement()
    if not movement then return false end
    local team = movement:team()
    if team and (team.id == "criminal1" or team.id == "neutral1") then return false end
    return true
end

local function check_wall(u)
    if not alive(u) then return false end
    if (NiceTrainer.IsWallPenetrationActive and NiceTrainer:IsWallPenetrationActive())
        or NiceTrainer.Settings.aimbot_shoot_through_walls
        or NiceTrainer.Settings.shoot_through_walls then
        return true
    end
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return false end
    
    local cam_pos = player:camera():position()
    local from = cam_pos
    local target = u:movement():m_com()
    local ray = World:raycast("ray", from, target, "slot_mask", managers.slot:get_mask("world_geometry"))
    return not ray
end

local function find_best_target(weapon, player_pos, current_direction)
    local best_target_dir = nil
    local closest_angle = math.huge
    local fov_only = tonumber(NiceTrainer.Settings.aimbot_fov) or 10
    local target_head = NiceTrainer.Settings.aimbot_target_head
    local max_dist = tonumber(NiceTrainer.Settings.aimbot_max_dist) or 8000
    local can_penetrate = (NiceTrainer.IsWallPenetrationActive and NiceTrainer:IsWallPenetrationActive())
        or NiceTrainer.Settings.aimbot_shoot_through_walls
        or NiceTrainer.Settings.shoot_through_walls

    if not managers.enemy or not managers.enemy:all_enemies() then return nil end

    for _, enemy_data in pairs(managers.enemy:all_enemies()) do
        local enemy_unit = enemy_data.unit
        if is_valid_enemy(enemy_unit) then
            local dist = mvector3.distance(player_pos, enemy_unit:position())
            if dist <= max_dist then
                local target_pos
                if target_head then
                    if enemy_unit:movement().m_head_pos then
                        target_pos = enemy_unit:movement():m_head_pos()
                    else
                        target_pos = enemy_unit:movement():m_com()
                    end
                else
                    target_pos = enemy_unit:movement():m_com()
                end

                local target_direction = calculate_angle(player_pos, target_pos)
                local angle_diff = mvector3.angle(current_direction, target_direction)

                if angle_diff <= fov_only and angle_diff < closest_angle then
                    if can_penetrate or check_wall(enemy_unit) then
                        closest_angle = angle_diff
                        best_target_dir = target_direction
                    end
                end
            end
        end
    end

    return best_target_dir
end

local function auto_shoot(player)
    local state = player:movement():current_state()
    local wep_base = state and state._equipped_unit and state._equipped_unit:base()
    if wep_base and wep_base.fire and wep_base:clip_empty() == false then
        if NiceTrainer.Settings.aimbot_require_ads then
            if not state or not state._state_data or not state._state_data.in_steelsight then
                return
            end
        end
        wep_base:fire(player:camera():position(), player:camera():forward(), 1, false, 1, 1, 1, nil)
    end
end

local function auto_aim(player)
    if not managers.enemy or not managers.enemy:all_enemies() then return end
    local max_dist = tonumber(NiceTrainer.Settings.aimbot_max_dist) or 8000
    local target_head = NiceTrainer.Settings.aimbot_target_head
    local fov_deg = tonumber(NiceTrainer.Settings.aimbot_fov) or 10
    
    local closest_dist = max_dist
    local best_target = nil
    
    local cam_pos = player:camera():position()
    local cam_fwd = player:camera():forward()
    
    for _, data in pairs(managers.enemy:all_enemies()) do
        local u = data.unit
        if is_valid_enemy(u) then
            local u_pos = u:position()
            local dist = mvector3.distance(cam_pos, u_pos)
            if dist < closest_dist and check_wall(u) then
                local char_damage = u:character_damage()
                local head_pos
                if target_head and char_damage and char_damage._head_body_name then
                    local body = u:body(char_damage._head_body_name)
                    head_pos = body and body:position()
                end
                
                local target = head_pos or u:movement():m_com()
                local dir = target - cam_pos
                mvector3.normalize(dir)
                local angle = mvector3.angle(cam_fwd, dir)
                
                if angle <= fov_deg then
                    closest_dist = dist
                    best_target = u
                end
            end
        end
    end
    
    if alive(best_target) then
        local char_damage = best_target:character_damage()
        local head_pos
        if target_head and char_damage and char_damage._head_body_name then
            local body = best_target:body(char_damage._head_body_name)
            head_pos = body and body:position()
        end
        
        local target = head_pos or best_target:movement():m_com()
        local dir = target - cam_pos
        aim_rotation = Rotation(dir, math.UP)
    end
end

local function aimbot_update()
    if not aimbot_running then return end
    
    update_fov_circle()
    
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return end
    
    if NiceTrainer.Settings.aimbot_require_ads then
        local state = player:movement():current_state()
        if not state or not state._state_data or not state._state_data.in_steelsight then
            return
        end
    end

    local mode = NiceTrainer.Settings.aimbot_mode or 1
    
    if mode == 1 or mode == 3 then
        auto_shoot(player)
    end
    
    if mode == 1 or mode == 2 then
        auto_aim(player)
    end
end

NiceTrainer._orig_aimbot_hooks = NiceTrainer._orig_aimbot_hooks or {}

local function start_aimbot()
    aimbot_running = true
    
    if NiceTrainer.ApplyShootThroughWalls then
        NiceTrainer:ApplyShootThroughWalls()
    end

    if _G.FPCameraPlayerBase and not NiceTrainer._orig_aimbot_hooks.update_rot then
        NiceTrainer._orig_aimbot_hooks.update_rot = FPCameraPlayerBase._update_rot
        FPCameraPlayerBase._update_rot = function(self, ...)
            local ret = NiceTrainer._orig_aimbot_hooks.update_rot(self, ...)
            if aim_rotation then
                self._parent_unit:camera():set_rotation(aim_rotation)
                self:set_rotation(aim_rotation)
                aim_rotation = nil
            end
            return ret
        end
    end
    
    if _G.NewRaycastWeaponBase and not NiceTrainer._orig_aimbot_hooks.fire then
        NiceTrainer._orig_aimbot_hooks.fire = NewRaycastWeaponBase.fire
        NewRaycastWeaponBase.fire = function(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
            local player = managers.player and managers.player:player_unit()
            if not alive(player) or not self._setup or self._setup.user_unit ~= player then
                return NiceTrainer._orig_aimbot_hooks.fire(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
            end
            
            local mode = NiceTrainer.Settings.aimbot_mode or 1
            if aimbot_running and mode == 4 then
                local should_silent_aim = true
                if NiceTrainer.Settings.aimbot_require_ads then
                    local state = player:movement():current_state()
                    if not state or not state._state_data or not state._state_data.in_steelsight then
                        should_silent_aim = false
                    end
                end
                
                if should_silent_aim then
                    local player_pos = player:camera():position()
                    local current_direction = player:camera():forward()
                    local target_dir = find_best_target(self, player_pos, current_direction)
                    
                    if target_dir then
                        return NiceTrainer._orig_aimbot_hooks.fire(self, from_pos, target_dir, dmg_mul, shoot_player, 0, autohit_mul, suppr_mul, target_unit)
                    end
                end
            end
            
            return NiceTrainer._orig_aimbot_hooks.fire(self, from_pos, direction, dmg_mul, shoot_player, spread_mul, autohit_mul, suppr_mul, target_unit)
        end
    end
    
    Hooks:Add("GameSetupUpdate", "NiceTrainer_Aimbot_Update", aimbot_update)
end

local function stop_aimbot()
    aimbot_running = false
    Hooks:Remove("GameSetupUpdate", "NiceTrainer_Aimbot_Update")
    
    if _G.FPCameraPlayerBase and NiceTrainer._orig_aimbot_hooks.update_rot then
        FPCameraPlayerBase._update_rot = NiceTrainer._orig_aimbot_hooks.update_rot
        NiceTrainer._orig_aimbot_hooks.update_rot = nil
    end
    
    if _G.NewRaycastWeaponBase and NiceTrainer._orig_aimbot_hooks.fire then
        NewRaycastWeaponBase.fire = NiceTrainer._orig_aimbot_hooks.fire
        NiceTrainer._orig_aimbot_hooks.fire = nil
    end
    
    if fov_circle then fov_circle:set_visible(false) end

    if NiceTrainer.ApplyShootThroughWalls then
        NiceTrainer:ApplyShootThroughWalls()
    end
end

local function toggle_aimbot(state)
    if state then
        start_aimbot()
    else
        stop_aimbot()
    end
end

local function ShowAimbotSettings()
    local MODAL_W, MODAL_H = 500, 500
    NiceTrainer:ShowCustomModal("Aimbot Settings", MODAL_W, MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        local TRACK_X, TRACK_W = 20, MODAL_W - 40
        
        local function create_native_btn(y, h)
            local p = m:panel({ x = TRACK_X, y = y, w = TRACK_W, h = h, layer = 2 })
            local bg = p:rect({ color = Color.white, alpha = 0, layer = 0 })
            local hl = p:rect({ color = Color(0.2, 0.6, 1.0), x = 0, y = h - 2, w = TRACK_W, h = 2, alpha = 0, layer = 1 })
            return p, bg, hl
        end

        local function create_slider(y, label, min_val, max_val, setting_key, format_str)
            local p, bg, hl = create_native_btn(y, 55)
            local val = tonumber(NiceTrainer.Settings[setting_key]) or min_val
            
            local title_txt = p:text({ text = label, font = "fonts/font_medium_shadow_mf", font_size = 20, color = Color(0.8, 0.8, 0.8), x = 15, y = 8, h = 24, layer = 1 })
            local val_txt = p:text({ text = string.format(format_str, val), font = "fonts/font_medium_shadow_mf", font_size = 20, color = Color(0.8, 0.8, 0.8), x = p:w() - 75, y = 8, w = 60, align = "right", h = 24, layer = 1 })
            
            local track_bg = p:rect({ color = Color.white, alpha = 0.2, x = 15, y = 35, w = p:w() - 30, h = 4, layer = 1 })
            local pct = math.clamp((val - min_val) / (max_val - min_val), 0, 1)
            local track_fill = p:rect({ color = Color(0.2, 0.6, 1.0), x = 15, y = 35, w = pct * (p:w() - 30), h = 4, layer = 2 })
            local track_knob = p:rect({ color = Color.white, x = 15 + pct * (p:w() - 30) - 4, y = 31, w = 8, h = 12, layer = 3 })
            
            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.05 or 0)
                    hl:set_alpha(hovered and 1 or 0)
                    title_txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
                    val_txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
                end,
                on_click = function(self, mx, my)
                    NiceTrainer._dragging_slider = function(drag_x)
                        local rx = drag_x - track_bg:world_x()
                        local npct = math.clamp(rx / track_bg:w(), 0, 1)
                        local nval = min_val + npct * (max_val - min_val)
                        if format_str == "%d" then nval = math.floor(nval + 0.5) end
                        NiceTrainer.Settings[setting_key] = nval
                        NiceTrainer:Save()
                        track_fill:set_w(npct * track_bg:w())
                        track_knob:set_x(15 + npct * track_bg:w() - 4)
                        val_txt:set_text(string.format(format_str, nval))
                    end
                    NiceTrainer._dragging_slider(mx)
                end
            })
            return y + 60
        end

        local function create_toggle(y, label, setting_key, default_val)
            local p, bg, hl = create_native_btn(y, 45)
            if NiceTrainer.Settings[setting_key] == nil then NiceTrainer.Settings[setting_key] = default_val end
            local state = NiceTrainer.Settings[setting_key]
            
            local box = p:rect({ color = Color.white, alpha = 0.1, x = 15, y = 12, w = 20, h = 20, layer = 1 })
            local check = p:rect({ color = Color(0.2, 0.6, 1.0), x = 19, y = 16, w = 12, h = 12, visible = state, layer = 2 })
            local txt = p:text({ text = label, font = "fonts/font_medium_shadow_mf", font_size = 20, color = Color(0.8, 0.8, 0.8), x = 50, vertical = "center", layer = 1 })
            
            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.05 or 0)
                    hl:set_alpha(hovered and 1 or 0)
                    txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
                end,
                on_click = function(self)
                    NiceTrainer.Settings[setting_key] = not NiceTrainer.Settings[setting_key]
                    NiceTrainer:Save()
                    check:set_visible(NiceTrainer.Settings[setting_key])
                    if setting_key == "aimbot_shoot_through_walls" and NiceTrainer.ApplyShootThroughWalls then
                        NiceTrainer:ApplyShootThroughWalls()
                    end
                end
            })
            return y + 50
        end
        
        local function create_mode(y)
            local p, bg, hl = create_native_btn(y, 45)
            local txt = p:text({ text = "Aimbot Mode", font = "fonts/font_medium_shadow_mf", font_size = 20, color = Color(0.8, 0.8, 0.8), x = 15, vertical = "center", layer = 1 })
            
            local mode = NiceTrainer.Settings.aimbot_mode or 1
            local modes = { "Aim & Shoot", "Aim Only", "Shoot Only", "Silent Aim" }
            
            local btn_w = 140
            local action_btn = p:panel({ x = p:w() - 15 - btn_w, y = 8, w = btn_w, h = 29, layer = 2 })
            local action_bg = action_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
            action_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 2, layer = 1 })
            action_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w - 2, w = 2, layer = 1 })
            
            local mode_txt = action_btn:text({ text = modes[mode], font = "fonts/font_medium_shadow_mf", font_size = 18, align = "center", vertical = "center", color = Color.white, layer = 2 })
            
            table.insert(top_modal.elements, {
                panel = p,
                inside = function(self, mx, my) return p:inside(mx, my) end,
                on_hover = function(self, hovered)
                    bg:set_alpha(hovered and 0.05 or 0)
                    hl:set_alpha(hovered and 1 or 0)
                    txt:set_color(hovered and Color.white or Color(0.8, 0.8, 0.8))
                    action_bg:set_alpha(hovered and 0.4 or 0.2)
                end,
                on_click = function(self)
                    mode = mode + 1
                    if mode > #modes then mode = 1 end
                    NiceTrainer.Settings.aimbot_mode = mode
                    NiceTrainer:Save()
                    mode_txt:set_text(modes[mode])
                end
            })
            return y + 50
        end

        local cur_y = 60
        cur_y = create_mode(cur_y)
        cur_y = create_toggle(cur_y, "Require Aim Down Sights", "aimbot_require_ads", false)
        cur_y = create_toggle(cur_y, "Target Head", "aimbot_target_head", true)
        cur_y = create_toggle(cur_y, "Shoot Through Walls", "aimbot_shoot_through_walls", false)
        cur_y = create_toggle(cur_y, "Draw FOV Circle", "aimbot_draw_fov", true)
        cur_y = create_slider(cur_y, "Max Distance (m)", 1000, 20000, "aimbot_max_dist", "%d")
        cur_y = create_slider(cur_y, "Aimbot FOV (Degrees)", 1, 90, "aimbot_fov", "%d")
        
        local close_btn = m:panel({ x = (MODAL_W - 120) / 2, y = MODAL_H - 45, w = 120, h = 30, layer = 2 })
        local close_bg = close_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        close_btn:text({ text = "Close", font = "fonts/font_medium_shadow_mf", font_size = 20, align = "center", vertical = "center", color = Color.white, layer = 2 })
        
        table.insert(top_modal.elements, {
            panel = close_btn,
            inside = function(self, mx, my) return close_btn:inside(mx, my) end,
            on_hover = function(self, hovered) close_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self) NiceTrainer:CloseModal() end
        })
    end)
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Aimbot", badge = "client", id = "aimbot_enabled", text = "Enable Aimbot", tooltip = "Turns on the Aimbot system.", default = false,
    callback = toggle_aimbot,
    settings_callback = ShowAimbotSettings
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyAimbot", function()
    if NiceTrainer.Settings.aimbot_enabled then
        toggle_aimbot(true)
    end
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_EnsureAimbotRunning", function()
    if NiceTrainer.Settings.aimbot_enabled and not aimbot_running then
        toggle_aimbot(true)
    end
end)
