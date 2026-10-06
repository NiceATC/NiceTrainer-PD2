-- Gunplay hacks for Player Tab

NiceTrainer._orig_weapon_base = NiceTrainer._orig_weapon_base or {}
NiceTrainer._orig_player_standard = NiceTrainer._orig_player_standard or {}
NiceTrainer._orig_cop_damage = NiceTrainer._orig_cop_damage or {}

local function apply_infinite_ammo(state)
    if state then
        if _G.RaycastWeaponBase and not NiceTrainer._orig_weapon_base.ammo_usage then
            NiceTrainer._orig_weapon_base.ammo_usage = RaycastWeaponBase.ammo_usage
            RaycastWeaponBase.ammo_usage = function() return 0 end
        end
        if _G.NewRaycastWeaponBase and not NiceTrainer._orig_weapon_base.new_ammo_usage then
            NiceTrainer._orig_weapon_base.new_ammo_usage = NewRaycastWeaponBase.ammo_usage
            NewRaycastWeaponBase.ammo_usage = function() return 0 end
        end
        if _G.SawWeaponBase and not NiceTrainer._orig_weapon_base.saw_fire then
            NiceTrainer._orig_weapon_base.saw_fire = SawWeaponBase.fire
            SawWeaponBase.fire = function(self, ...)
                local clip = self:get_ammo_remaining_in_clip()
                local total = self:get_ammo_total()
                local result = NiceTrainer._orig_weapon_base.saw_fire(self, ...)
                self:set_ammo_remaining_in_clip(clip)
                self:set_ammo_total(total)
                return result
            end
        end
    else
        if _G.RaycastWeaponBase and NiceTrainer._orig_weapon_base.ammo_usage then
            RaycastWeaponBase.ammo_usage = NiceTrainer._orig_weapon_base.ammo_usage
            NiceTrainer._orig_weapon_base.ammo_usage = nil
        end
        if _G.NewRaycastWeaponBase and NiceTrainer._orig_weapon_base.new_ammo_usage then
            NewRaycastWeaponBase.ammo_usage = NiceTrainer._orig_weapon_base.new_ammo_usage
            NiceTrainer._orig_weapon_base.new_ammo_usage = nil
        end
        if _G.SawWeaponBase and NiceTrainer._orig_weapon_base.saw_fire then
            SawWeaponBase.fire = NiceTrainer._orig_weapon_base.saw_fire
            NiceTrainer._orig_weapon_base.saw_fire = nil
        end
    end
end

local function apply_no_recoil(state)
    if not _G.NewRaycastWeaponBase then return end
    if state then
        if not NiceTrainer._orig_weapon_base.recoil_multiplier then
            NiceTrainer._orig_weapon_base.recoil_multiplier = NewRaycastWeaponBase.recoil_multiplier
            NewRaycastWeaponBase.recoil_multiplier = function() return 0 end
        end
    else
        if NiceTrainer._orig_weapon_base.recoil_multiplier then
            NewRaycastWeaponBase.recoil_multiplier = NiceTrainer._orig_weapon_base.recoil_multiplier
            NiceTrainer._orig_weapon_base.recoil_multiplier = nil
        end
    end
end

local function apply_no_spread(state)
    if not _G.NewRaycastWeaponBase then return end
    if state then
        if not NiceTrainer._orig_weapon_base.spread_multiplier then
            NiceTrainer._orig_weapon_base.spread_multiplier = NewRaycastWeaponBase.spread_multiplier
            NewRaycastWeaponBase.spread_multiplier = function() return 0 end
        end
    else
        if NiceTrainer._orig_weapon_base.spread_multiplier then
            NewRaycastWeaponBase.spread_multiplier = NiceTrainer._orig_weapon_base.spread_multiplier
            NiceTrainer._orig_weapon_base.spread_multiplier = nil
        end
    end
end

local function apply_instant_reload(state)
    if state then
        if _G.RaycastWeaponBase and not NiceTrainer._orig_weapon_base.reload_speed_multiplier then
            NiceTrainer._orig_weapon_base.reload_speed_multiplier = RaycastWeaponBase.reload_speed_multiplier
            RaycastWeaponBase.reload_speed_multiplier = function() return 1000 end
        end
        if _G.NewRaycastWeaponBase and not NiceTrainer._orig_weapon_base.new_reload_speed_multiplier then
            NiceTrainer._orig_weapon_base.new_reload_speed_multiplier = NewRaycastWeaponBase.reload_speed_multiplier
            NewRaycastWeaponBase.reload_speed_multiplier = function() return 1000 end
        end
    else
        if _G.RaycastWeaponBase and NiceTrainer._orig_weapon_base.reload_speed_multiplier then
            RaycastWeaponBase.reload_speed_multiplier = NiceTrainer._orig_weapon_base.reload_speed_multiplier
            NiceTrainer._orig_weapon_base.reload_speed_multiplier = nil
        end
        if _G.NewRaycastWeaponBase and NiceTrainer._orig_weapon_base.new_reload_speed_multiplier then
            NewRaycastWeaponBase.reload_speed_multiplier = NiceTrainer._orig_weapon_base.new_reload_speed_multiplier
            NiceTrainer._orig_weapon_base.new_reload_speed_multiplier = nil
        end
    end
end

local function apply_instant_swap(state)
    if not _G.PlayerStandard then return end
    if state then
        if not NiceTrainer._orig_player_standard.get_swap_speed_multiplier then
            NiceTrainer._orig_player_standard.get_swap_speed_multiplier = PlayerStandard._get_swap_speed_multiplier
            PlayerStandard._get_swap_speed_multiplier = function() return 1000 end
        end
    else
        if NiceTrainer._orig_player_standard.get_swap_speed_multiplier then
            PlayerStandard._get_swap_speed_multiplier = NiceTrainer._orig_player_standard.get_swap_speed_multiplier
            NiceTrainer._orig_player_standard.get_swap_speed_multiplier = nil
        end
    end
end

function NiceTrainer:IsWallPenetrationActive()
    return (self.Settings and self.Settings.shoot_through_walls == true)
        or (self.Settings and self.Settings.aimbot_enabled == true and self.Settings.aimbot_shoot_through_walls == true)
end

function NiceTrainer:IsAPPenetrationActive()
    return (self.Settings and self.Settings.ap_ammo == true)
        or self:IsWallPenetrationActive()
end

function NiceTrainer:ApplyShootThroughWalls(state)
    local wall = self:IsWallPenetrationActive()
    local ap = self:IsAPPenetrationActive()

    if wall or ap then
        if _G.RaycastWeaponBase and not NiceTrainer._orig_weapon_base.can_shoot_through_wall then
            NiceTrainer._orig_weapon_base.can_shoot_through_wall = RaycastWeaponBase.can_shoot_through_wall
            NiceTrainer._orig_weapon_base.can_shoot_through_shield = RaycastWeaponBase.can_shoot_through_shield
            NiceTrainer._orig_weapon_base.can_shoot_through_enemy = RaycastWeaponBase.can_shoot_through_enemy
            NiceTrainer._orig_weapon_base.armor_piercing_chance = RaycastWeaponBase.armor_piercing_chance
            NiceTrainer._orig_weapon_base.has_armor_piercing = RaycastWeaponBase.has_armor_piercing
        end
        if _G.NewRaycastWeaponBase and not NiceTrainer._orig_weapon_base.new_can_shoot_through_wall then
            NiceTrainer._orig_weapon_base.new_can_shoot_through_wall = NewRaycastWeaponBase.can_shoot_through_wall
            NiceTrainer._orig_weapon_base.new_can_shoot_through_shield = NewRaycastWeaponBase.can_shoot_through_shield
            NiceTrainer._orig_weapon_base.new_can_shoot_through_enemy = NewRaycastWeaponBase.can_shoot_through_enemy
            NiceTrainer._orig_weapon_base.new_armor_piercing_chance = NewRaycastWeaponBase.armor_piercing_chance
            NiceTrainer._orig_weapon_base.new_has_armor_piercing = NewRaycastWeaponBase.has_armor_piercing
        end
    end
    
    if _G.RaycastWeaponBase and NiceTrainer._orig_weapon_base.can_shoot_through_wall then
        RaycastWeaponBase.can_shoot_through_wall = wall and function() return true end or NiceTrainer._orig_weapon_base.can_shoot_through_wall
        RaycastWeaponBase.can_shoot_through_shield = ap and function() return true end or NiceTrainer._orig_weapon_base.can_shoot_through_shield
        RaycastWeaponBase.can_shoot_through_enemy = ap and function() return true end or NiceTrainer._orig_weapon_base.can_shoot_through_enemy
        RaycastWeaponBase.armor_piercing_chance = ap and function() return 1 end or NiceTrainer._orig_weapon_base.armor_piercing_chance
        RaycastWeaponBase.has_armor_piercing = ap and function() return true end or NiceTrainer._orig_weapon_base.has_armor_piercing
        
        if not wall and not ap then
            NiceTrainer._orig_weapon_base.can_shoot_through_wall = nil
            NiceTrainer._orig_weapon_base.can_shoot_through_shield = nil
            NiceTrainer._orig_weapon_base.can_shoot_through_enemy = nil
            NiceTrainer._orig_weapon_base.armor_piercing_chance = nil
            NiceTrainer._orig_weapon_base.has_armor_piercing = nil
        end
    end
    
    if _G.NewRaycastWeaponBase and NiceTrainer._orig_weapon_base.new_can_shoot_through_wall then
        NewRaycastWeaponBase.can_shoot_through_wall = wall and function() return true end or NiceTrainer._orig_weapon_base.new_can_shoot_through_wall
        NewRaycastWeaponBase.can_shoot_through_shield = ap and function() return true end or NiceTrainer._orig_weapon_base.new_can_shoot_through_shield
        NewRaycastWeaponBase.can_shoot_through_enemy = ap and function() return true end or NiceTrainer._orig_weapon_base.new_can_shoot_through_enemy
        NewRaycastWeaponBase.armor_piercing_chance = ap and function() return 1 end or NiceTrainer._orig_weapon_base.new_armor_piercing_chance
        NewRaycastWeaponBase.has_armor_piercing = ap and function() return true end or NiceTrainer._orig_weapon_base.new_has_armor_piercing
        
        if not wall and not ap then
            NiceTrainer._orig_weapon_base.new_can_shoot_through_wall = nil
            NiceTrainer._orig_weapon_base.new_can_shoot_through_shield = nil
            NiceTrainer._orig_weapon_base.new_can_shoot_through_enemy = nil
            NiceTrainer._orig_weapon_base.new_armor_piercing_chance = nil
            NiceTrainer._orig_weapon_base.new_has_armor_piercing = nil
        end
    end
    
    -- Apply to currently equipped weapons
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        local inv = player and alive(player) and player.inventory and player:inventory()
        local selections = inv and inv._available_selections
        if selections then
            for _, selection in pairs(selections) do
                local base = selection and selection.unit and alive(selection.unit) and selection.unit:base()
                if base and base.override_shoot_through then
                    if wall or ap then
                        -- Arguments mapped to wall, shield, enemy
                        base:override_shoot_through(wall and true or false, ap and true or false, ap and true or false)
                    else
                        base:override_shoot_through(nil, nil, nil)
                    end
                end
                if base then
                    if wall then
                        if base._ht_original_bullet_slotmask == nil then
                            base._ht_original_bullet_slotmask = base._bullet_slotmask
                        end
                        base._bullet_slotmask = World:make_slot_mask(7, 11, 12, 14, 16, 17, 18, 21, 22, 25, 26, 33, 34, 35)
                    elseif base._ht_original_bullet_slotmask ~= nil then
                        base._bullet_slotmask = base._ht_original_bullet_slotmask
                        base._ht_original_bullet_slotmask = nil
                    end
                end
            end
        end
    end)
end

local function apply_shoot_through_walls(state)
    NiceTrainer:ApplyShootThroughWalls(state)
end

local function apply_ap_ammo(state)
    NiceTrainer:ApplyShootThroughWalls(state)
end

local function apply_fire_rate(state, mult)
    if not _G.NewRaycastWeaponBase then return end
    if state then
        if not NiceTrainer._orig_weapon_base.fire_rate_multiplier then
            NiceTrainer._orig_weapon_base.fire_rate_multiplier = NewRaycastWeaponBase.fire_rate_multiplier
        end
        NewRaycastWeaponBase.fire_rate_multiplier = function(self, ...)
            local orig = NiceTrainer._orig_weapon_base.fire_rate_multiplier
            return (orig and orig(self, ...) or 1) * mult
        end
    else
        if NiceTrainer._orig_weapon_base.fire_rate_multiplier then
            NewRaycastWeaponBase.fire_rate_multiplier = NiceTrainer._orig_weapon_base.fire_rate_multiplier
            NiceTrainer._orig_weapon_base.fire_rate_multiplier = nil
        end
    end
end

local function apply_damage_multiplier(state)
    if not _G.CopDamage then return end
    local mult = tonumber(NiceTrainer.Settings.damage_multiplier) or 2
    local one_shot = NiceTrainer.Settings.one_shot_kill
    
    local any_enabled = state or one_shot
    
    if any_enabled then
        if not NiceTrainer._orig_cop_damage.damage_bullet then
            NiceTrainer._orig_cop_damage.damage_bullet = CopDamage.damage_bullet
            NiceTrainer._orig_cop_damage.damage_melee = CopDamage.damage_melee
            
            CopDamage.damage_bullet = function(self, attack_data)
                if attack_data and managers.player and attack_data.attacker_unit == managers.player:player_unit() then
                    if NiceTrainer.Settings.one_shot_kill then
                        attack_data.damage = 1000000
                    elseif NiceTrainer.Settings.enable_damage_multiplier then
                        attack_data.damage = attack_data.damage * mult
                    end
                end
                return NiceTrainer._orig_cop_damage.damage_bullet(self, attack_data)
            end
            
            CopDamage.damage_melee = function(self, attack_data)
                if attack_data and managers.player and attack_data.attacker_unit == managers.player:player_unit() then
                    if NiceTrainer.Settings.one_shot_kill then
                        attack_data.damage = 1000000
                    elseif NiceTrainer.Settings.enable_damage_multiplier then
                        attack_data.damage = attack_data.damage * mult
                    end
                end
                return NiceTrainer._orig_cop_damage.damage_melee(self, attack_data)
            end
        end
    else
        if NiceTrainer._orig_cop_damage.damage_bullet then
            CopDamage.damage_bullet = NiceTrainer._orig_cop_damage.damage_bullet
            CopDamage.damage_melee = NiceTrainer._orig_cop_damage.damage_melee
            NiceTrainer._orig_cop_damage.damage_bullet = nil
            NiceTrainer._orig_cop_damage.damage_melee = nil
        end
    end
end

NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "infinite_ammo", text = "Infinite Ammo", tooltip = "You have infinite ammo and never need to reload.", default = false, callback = apply_infinite_ammo })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "no_recoil", text = "No Recoil", tooltip = "Your weapons have absolutely no recoil.", default = false, callback = apply_no_recoil })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "max_accuracy", text = "Max Accuracy (No Spread)", tooltip = "Your weapons have no spread.", default = false, callback = apply_no_spread })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "instant_reload", text = "Instant Reload", tooltip = "Reload your weapons instantly.", default = false, callback = apply_instant_reload })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "instant_swap", text = "Instant Swap", tooltip = "Swap weapons instantly.", default = false, callback = apply_instant_swap })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "ap_ammo", text = "AP Ammo (Pierce Shields)", tooltip = "Your bullets penetrate shields and enemies.", default = false, callback = apply_ap_ammo })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "shoot_through_walls", text = "Shoot Through Walls", tooltip = "Your bullets penetrate all walls, shields, and enemies.", default = false, callback = apply_shoot_through_walls })
NiceTrainer:RegisterAction("Player", { type = "toggle", category = "Gunplay", badge = "client", id = "one_shot_kill", text = "One Hit Kill", tooltip = "Kill any enemy with a single shot or melee hit.", default = false, callback = apply_damage_multiplier })

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Gunplay", badge = "client", id = "enable_fire_rate", text = "Fire Rate Multiplier", tooltip = "Multiplies your weapon fire rate.", default = false,
    callback = function(state)
        local mult = tonumber(NiceTrainer.Settings.fire_rate_multiplier) or 2
        apply_fire_rate(state, mult)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Fire Rate Multiplier", 1, 10, tonumber(NiceTrainer.Settings.fire_rate_multiplier) or 2, function(val)
            NiceTrainer.Settings.fire_rate_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_fire_rate then
                apply_fire_rate(true, val)
            end
        end)
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Gunplay", badge = "client", id = "enable_damage_multiplier", text = "Damage Multiplier", tooltip = "Multiplies your weapon and melee damage.", default = false,
    callback = function(state)
        apply_damage_multiplier(state)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Damage Multiplier", 1, 100, tonumber(NiceTrainer.Settings.damage_multiplier) or 2, function(val)
            NiceTrainer.Settings.damage_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_damage_multiplier then
                apply_damage_multiplier(true)
            end
        end)
    end
})

local function reapply_all_gunplay()
    if NiceTrainer.Settings.infinite_ammo then apply_infinite_ammo(true) end
    if NiceTrainer.Settings.no_recoil then apply_no_recoil(true) end
    if NiceTrainer.Settings.max_accuracy then apply_no_spread(true) end
    if NiceTrainer.Settings.instant_reload then apply_instant_reload(true) end
    if NiceTrainer.Settings.instant_swap then apply_instant_swap(true) end
    if NiceTrainer.Settings.ap_ammo then apply_ap_ammo(true) end
    if NiceTrainer.Settings.shoot_through_walls then apply_shoot_through_walls(true) end
    if NiceTrainer.Settings.one_shot_kill or NiceTrainer.Settings.enable_damage_multiplier then apply_damage_multiplier(true) end
    if NiceTrainer.Settings.enable_fire_rate then
        local mult = tonumber(NiceTrainer.Settings.fire_rate_multiplier) or 2
        apply_fire_rate(true, mult)
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyGunplay", function()
    reapply_all_gunplay()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_GunplayGameUpdate", function()
    reapply_all_gunplay()
end)

local _originals = {}
local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then _originals[key] = cls[method_name] end
    cls[method_name] = replacement
    return true
end
local function restore(class_name, method_name)
    local cls = _G[class_name]
    if not cls then return end
    local key = class_name .. "." .. method_name
    if _originals[key] then
        cls[method_name] = _originals[key]
        _originals[key] = nil
    end
end

local function applyReloadSpeed(state, val)
    if state and val > 1 then
        hijack("RaycastWeaponBase", "reload_speed_multiplier", function(self)
            local orig = _originals["RaycastWeaponBase.reload_speed_multiplier"]
            return (orig and orig(self) or 1) * val
        end)
        hijack("PlayerStandard", "_start_action_reload", function(self, t, ...)
            local orig = _originals["PlayerStandard._start_action_reload"]
            local res = orig and orig(self, t, ...)
            if self._state_data.reload_expire_t then
                local remain = self._state_data.reload_expire_t - t
                self._state_data.reload_expire_t = t + (remain / val)
            end
            return res
        end)
    else
        restore("RaycastWeaponBase", "reload_speed_multiplier")
        restore("PlayerStandard", "_start_action_reload")
    end
end

local function applyAmmoPickup(state, val)
    if state and val > 1 then
        hijack("RaycastWeaponBase", "add_ammo", function(self, ratio, add_amount_override, ...)
            if ratio and not add_amount_override then ratio = ratio * val end
            local orig = _originals["RaycastWeaponBase.add_ammo"]
            return orig and orig(self, ratio, add_amount_override, ...)
        end)
    else
        restore("RaycastWeaponBase", "add_ammo")
    end
end

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Gunplay", badge = "client", id = "enable_reload_speed", text = "Reload Speed Multiplier", tooltip = "How fast you reload. 10 = 10x faster.", default = false,
    callback = function(state) applyReloadSpeed(state, tonumber(NiceTrainer.Settings.reload_speed_multiplier) or 2) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Reload Speed Multiplier", 1, 10, tonumber(NiceTrainer.Settings.reload_speed_multiplier) or 2, function(val)
            NiceTrainer.Settings.reload_speed_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_reload_speed then applyReloadSpeed(true, val) end
        end)
    end
})

NiceTrainer:RegisterAction("Player", {
    type = "toggle_settings", category = "Gunplay", badge = "client", id = "enable_ammo_pickup", text = "Ammo Pickup Multiplier", tooltip = "How much ammo you get from drops.", default = false,
    callback = function(state) applyAmmoPickup(state, tonumber(NiceTrainer.Settings.ammo_pickup_multiplier) or 2) end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Ammo Pickup Multiplier", 1, 20, tonumber(NiceTrainer.Settings.ammo_pickup_multiplier) or 2, function(val)
            NiceTrainer.Settings.ammo_pickup_multiplier = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.enable_ammo_pickup then applyAmmoPickup(true, val) end
        end)
    end
})

local function reapply_gunplay_stats()
    if NiceTrainer.Settings.enable_reload_speed then applyReloadSpeed(true, tonumber(NiceTrainer.Settings.reload_speed_multiplier) or 2) end
    if NiceTrainer.Settings.enable_ammo_pickup then applyAmmoPickup(true, tonumber(NiceTrainer.Settings.ammo_pickup_multiplier) or 2) end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyGunplay_Stats", function()
    reapply_gunplay_stats()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_GunplayStatsUpdate", function()
    reapply_gunplay_stats()
end)
