-- Explosions, Fire & Chain DOT Systems for NiceTrainer (Player Tab)
-- Provides Cluster Bombs, Infinite Burn Ground, Super Explosion Radius, and Tesla Chain Stun.

NiceTrainer.SuperExplosionRadius = false
NiceTrainer.ExplosionRadiusMul = 3.0
NiceTrainer.ClusterBombs = false
NiceTrainer.InfiniteBurnGround = false
NiceTrainer.TeslaChainStun = false

-- ============================================================
-- Tesla Chain Shock Helper
-- ============================================================

local function _trigger_tesla_chain(source_unit)
    if not alive(source_unit) then return end
    local pos = source_unit:position()
    local enemies = World:find_units_quick("sphere", pos, 1000, managers.slot:get_mask("enemies"))
    if not enemies then return end

    for _, enemy in ipairs(enemies) do
        if alive(enemy) and enemy ~= source_unit and enemy:character_damage() and not enemy:character_damage():dead() then
            if enemy:movement() and not enemy:movement():tased() then
                local action_data = {
                    variant = "heavy",
                    damage = 0,
                    col_ray = {
                        position = enemy:position(),
                        ray = (enemy:position() - pos):normalized()
                    },
                    forced = true,
                    _is_tesla_chain = true
                }
                pcall(function()
                    enemy:character_damage():damage_tase(action_data)
                    World:effect_manager():spawn({
                        effect = Idstring("effects/payday2/particles/weapons/taser_spark"),
                        position = enemy:position() + Vector3(0, 0, 80)
                    })
                end)
            end
        end
    end
end

-- ============================================================
-- Safe Dynamic Hooks Installer
-- ============================================================

local function _install_explosions_fire_hooks()
    if _G.ExplosionManager and not ExplosionManager._nicetrainer_explosion_hooked then
        ExplosionManager._nicetrainer_explosion_hooked = true
        local orig_detect_and_give_dmg = ExplosionManager.detect_and_give_dmg
        function ExplosionManager:detect_and_give_dmg(params, ...)
            if NiceTrainer.SuperExplosionRadius and params and params.range then
                local mul = NiceTrainer.ExplosionRadiusMul or 3.0
                params.range = params.range * mul
                if params.alert_radius then
                    params.alert_radius = params.alert_radius * mul
                end
            end

            local res1, res2, res3 = orig_detect_and_give_dmg(self, params, ...)

            if NiceTrainer.ClusterBombs and params and not params._is_cluster_submunition then
                local hit_pos = params.hit_pos
                if hit_pos then
                    local offsets = {
                        Vector3(180, 180, 25),
                        Vector3(-180, 180, 25),
                        Vector3(180, -180, 25),
                        Vector3(-180, -180, 25)
                    }

                    for _, off in ipairs(offsets) do
                        local sub_pos = hit_pos + off
                        local sub_params = clone(params)
                        sub_params.hit_pos = sub_pos
                        sub_params._is_cluster_submunition = true
                        sub_params.range = (params.range or 500) * 0.75
                        sub_params.damage = (params.damage or 100) * 0.75
                        pcall(function()
                            managers.explosion:detect_and_give_dmg(sub_params)
                            managers.explosion:spawn_sound_and_effects(sub_pos, math.UP, sub_params.range)
                        end)
                    end
                end
            end

            return res1, res2, res3
        end
    end

    if _G.EnvironmentFire and not EnvironmentFire._nicetrainer_fire_hooked then
        EnvironmentFire._nicetrainer_fire_hooked = true
        local orig_fire_update = EnvironmentFire.update
        function EnvironmentFire:update(unit, t, dt, ...)
            if NiceTrainer.InfiniteBurnGround then
                self._burn_duration = math.max(self._burn_duration or 15, 15)
                self._burn_duration_destroy = math.max(self._burn_duration_destroy or 5, 5)
            end
            return orig_fire_update(self, unit, t, dt, ...)
        end
    end

    if _G.CopDamage and not CopDamage._nicetrainer_tesla_hooked then
        CopDamage._nicetrainer_tesla_hooked = true
        local orig_damage_tase = CopDamage.damage_tase
        function CopDamage:damage_tase(attack_data, ...)
            local res = orig_damage_tase(self, attack_data, ...)
            if NiceTrainer.TeslaChainStun and self._unit and attack_data and not attack_data._is_tesla_chain then
                _trigger_tesla_chain(self._unit)
            end
            return res
        end
    end

    if _G.DOTManager and not DOTManager._nicetrainer_tesla_hooked then
        DOTManager._nicetrainer_tesla_hooked = true
        local orig_damage_dot = DOTManager._damage_dot
        function DOTManager:_damage_dot(dot_info, var_info, ...)
            local res = orig_damage_dot(self, dot_info, var_info, ...)
            if NiceTrainer.TeslaChainStun and dot_info and alive(dot_info.unit) and var_info and (var_info.variant == "electricity" or var_info.variant == "tase") then
                _trigger_tesla_chain(dot_info.unit)
            end
            return res
        end
    end
end

_install_explosions_fire_hooks()
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ExplosionsFire_SessionHooks", _install_explosions_fire_hooks)
Hooks:Add("GameSetupUpdate", "NiceTrainer_ExplosionsFire_GameHooks", function()
    if not ExplosionManager or not ExplosionManager._nicetrainer_explosion_hooked then
        _install_explosions_fire_hooks()
    end
end)

-- ============================================================
-- Action Registrations
-- ============================================================

-- Super Explosion Radius (Toggle-Slider)
NiceTrainer:RegisterAction("Player", {
    type = "toggle_slider",
    badge = "Client",
    category = "Explosions & Fire Mechanics",
    id = "super_explosion_radius",
    text = "Super Explosion Radius",
    tooltip = "Multiplies detonation and alert radius of grenades, C4, trip mines, and rocket launchers",
    default = false,
    save = true,
    min = 1.5,
    max = 10.0,
    slider_default = 3.0,
    slider_id = "explosion_radius_mul",
    callback = function(state, val)
        NiceTrainer.SuperExplosionRadius = state
        NiceTrainer.ExplosionRadiusMul = tonumber(val) or 3.0
        if state then
        end
    end,
    slider_callback = function(val, state)
        NiceTrainer.ExplosionRadiusMul = tonumber(val) or 3.0
        if state or NiceTrainer.SuperExplosionRadius then
        end
    end
})

-- Cluster Bombs / Submunitions (Toggle)
NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    badge = "Client",
    category = "Explosions & Fire Mechanics",
    id = "cluster_bombs",
    text = "Cluster Bombs (Fragmentation)",
    tooltip = "Every explosion spawns 4 secondary sub-explosions around the impact point to wipe out entire squads",
    default = false,
    save = true,
    callback = function(state)
        NiceTrainer.ClusterBombs = state
    end
})

-- Infinite Burn Ground (Toggle)
NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    badge = "Host",
    category = "Explosions & Fire Mechanics",
    id = "infinite_burn_ground",
    text = "Infinite Burn Ground (Permanent Fire)",
    tooltip = "Fire patches from Molotovs, flamethrowers, and incendiary rounds burn permanently without extinguishing",
    default = false,
    save = true,
    callback = function(state)
        NiceTrainer.InfiniteBurnGround = state
    end
})

-- Tesla Chain Stun (Toggle)
NiceTrainer:RegisterAction("Player", {
    type = "toggle",
    badge = "Client",
    category = "Explosions & Fire Mechanics",
    id = "tesla_chain_stun",
    text = "Tesla Chain Shock (Arc Stun)",
    tooltip = "Electrocuted enemies transfer electrical shock arcs to all nearby police within 10 meters",
    default = false,
    save = true,
    callback = function(state)
        NiceTrainer.TeslaChainStun = state
    end
})
