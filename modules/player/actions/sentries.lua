-- ─── Sentry Gun Overhaul (Player Tab) ──────────────────────────────────
-- Provides invulnerable sentry guns, infinite sentry ammo, shield piercing,
-- stat overclocks, and instant sentry repair/refill.

NiceTrainer._orig_sentry = NiceTrainer._orig_sentry or {}
NiceTrainer._orig_sentry_tweak = NiceTrainer._orig_sentry_tweak or nil

-- ─── 1. Invulnerable Sentries ─────────────────────────────────────────
local function apply_invulnerable_sentries(state)
    if not _G.SentryGunDamage then return end

    if state then
        if not NiceTrainer._orig_sentry.damage_bullet then
            NiceTrainer._orig_sentry.damage_bullet = SentryGunDamage.damage_bullet
            NiceTrainer._orig_sentry.damage_fire = SentryGunDamage.damage_fire
            NiceTrainer._orig_sentry.damage_explosion = SentryGunDamage.damage_explosion
            NiceTrainer._orig_sentry.damage_melee = SentryGunDamage.damage_melee

            local function is_enemy_swat_turret(unit)
                if not managers.groupai or not managers.groupai:state() then return false end
                local turrets = managers.groupai:state():turrets()
                return turrets and table.contains(turrets, unit)
            end

            SentryGunDamage.damage_bullet = function(self, attack_data, ...)
                if is_enemy_swat_turret(self._unit) then
                    return NiceTrainer._orig_sentry.damage_bullet(self, attack_data, ...)
                end
                return nil
            end

            SentryGunDamage.damage_fire = function(self, attack_data, ...)
                if is_enemy_swat_turret(self._unit) then
                    return NiceTrainer._orig_sentry.damage_fire and NiceTrainer._orig_sentry.damage_fire(self, attack_data, ...)
                end
                return nil
            end

            SentryGunDamage.damage_explosion = function(self, attack_data, ...)
                if is_enemy_swat_turret(self._unit) then
                    return NiceTrainer._orig_sentry.damage_explosion and NiceTrainer._orig_sentry.damage_explosion(self, attack_data, ...)
                end
                return nil
            end

            SentryGunDamage.damage_melee = function(self, attack_data, ...)
                if is_enemy_swat_turret(self._unit) then
                    return NiceTrainer._orig_sentry.damage_melee and NiceTrainer._orig_sentry.damage_melee(self, attack_data, ...)
                end
                return nil
            end
        end
    else
        if NiceTrainer._orig_sentry.damage_bullet then
            SentryGunDamage.damage_bullet = NiceTrainer._orig_sentry.damage_bullet
            if NiceTrainer._orig_sentry.damage_fire then SentryGunDamage.damage_fire = NiceTrainer._orig_sentry.damage_fire end
            if NiceTrainer._orig_sentry.damage_explosion then SentryGunDamage.damage_explosion = NiceTrainer._orig_sentry.damage_explosion end
            if NiceTrainer._orig_sentry.damage_melee then SentryGunDamage.damage_melee = NiceTrainer._orig_sentry.damage_melee end
            NiceTrainer._orig_sentry.damage_bullet = nil
            NiceTrainer._orig_sentry.damage_fire = nil
            NiceTrainer._orig_sentry.damage_explosion = nil
            NiceTrainer._orig_sentry.damage_melee = nil
        end
    end
end

-- ─── 2. Infinite Sentry Ammo ──────────────────────────────────────────
local function apply_infinite_sentry_ammo(state)
    if not _G.SentryGunWeapon then return end

    if state then
        if not NiceTrainer._orig_sentry.weapon_fire then
            NiceTrainer._orig_sentry.weapon_fire = SentryGunWeapon.fire
            SentryGunWeapon.fire = function(self, blanks, expend_ammo, ...)
                return NiceTrainer._orig_sentry.weapon_fire(self, blanks, false, ...)
            end
        end
    else
        if NiceTrainer._orig_sentry.weapon_fire then
            SentryGunWeapon.fire = NiceTrainer._orig_sentry.weapon_fire
            NiceTrainer._orig_sentry.weapon_fire = nil
        end
    end
end

-- ─── 3. Sentries Target & Pierce Shields ──────────────────────────────
local function apply_sentry_shield_pierce(state)
    if not _G.SentryGunBrain then return end

    if state then
        if not NiceTrainer._orig_sentry.choose_focus_enemy then
            NiceTrainer._orig_sentry.choose_focus_enemy = SentryGunBrain._choose_focus_enemy
            
            local mvec3_dir = mvector3.direction
            local mvec3_dot = mvector3.dot
            local math_max = math.max
            local tmp_vec1 = Vector3()

            SentryGunBrain._choose_focus_enemy = function(self, t)
                local delay = 1
                local enemies = managers.enemy and managers.enemy:all_enemies()
                if not enemies then return delay end

                local my_tracker = self._unit:movement():nav_tracker()
                local chk_vis_func = my_tracker.check_visibility
                local my_pos = self._m_head_object_pos
                local my_team = self._unit:movement():team()

                for e_key, enemy_data in pairs(enemies) do
                    local enemy_unit = enemy_data.unit
                    if not my_team.foes[enemy_data.unit:movement():team().id] or enemy_unit:brain()._current_logic_name == "trade" then
                        self._AI_data.detected_enemies[e_key] = nil
                    elseif self._AI_data.detected_enemies[e_key] then
                        local detected_data = self._AI_data.detected_enemies[e_key]
                        local visible = false
                        local enemy_pos = detected_data.m_com
                        local vis_ray = World:raycast("ray", my_pos, enemy_pos, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision", "report")
                        if not vis_ray then
                            visible = true
                        end
                        detected_data.verified = visible
                        if visible then
                            delay = math.min(0.6, delay)
                            detected_data.verified_t = t
                            detected_data.verified_dis = mvector3.distance(enemy_pos, my_pos)
                        elseif not detected_data.verified_t or t - detected_data.verified_t > 3 then
                            enemy_unit:base():remove_destroy_listener(detected_data.destroy_clbk_key)
                            enemy_unit:character_damage():remove_listener(detected_data.death_clbk_key)
                            self._AI_data.detected_enemies[e_key] = nil
                        end
                    elseif chk_vis_func(my_tracker, enemy_data.tracker) then
                        local enemy_head = enemy_unit:movement():m_head_pos()
                        local dis_multiplier = mvector3.distance(enemy_head, my_pos) / self._AI_data.detection.dis_max
                        if dis_multiplier < 1 then
                            delay = math.min(delay, dis_multiplier)
                            if not World:raycast("ray", my_pos, enemy_head, "slot_mask", self._visibility_slotmask, "ray_type", "ai_vision", "report") then
                                local new_data = self:_create_enemy_detection_data(enemy_unit)
                                new_data.verified_t = t
                                new_data.verified = true
                                self._AI_data.detected_enemies[e_key] = new_data
                            end
                        end
                    end
                end

                local focus_enemy = self._AI_data.focus_enemy
                local cam_fwd = focus_enemy and tmp_vec1 or self._ext_movement:m_head_fwd()
                if focus_enemy then
                    mvec3_dir(cam_fwd, my_pos, focus_enemy.m_com)
                end

                local max_dis = 15000
                local function _get_weight(enemy_data)
                    local dis = mvec3_dir(tmp_vec1, my_pos, enemy_data.m_com)
                    local dis_weight = math_max(0, (max_dis - dis) / max_dis)
                    local dot_weight = 1 + mvec3_dot(tmp_vec1, cam_fwd)
                    return dot_weight * dot_weight * dot_weight * dis_weight
                end

                local focus_enemy_weight = focus_enemy and (_get_weight(focus_enemy) * 4) or nil
                for _, enemy_data in pairs(self._AI_data.detected_enemies) do
                    if not enemy_data.death_verify_t then
                        local weight = _get_weight(enemy_data)
                        if not focus_enemy_weight or focus_enemy_weight < weight then
                            focus_enemy_weight = weight
                            focus_enemy = enemy_data
                        end
                    end
                end

                if self._AI_data.focus_enemy ~= focus_enemy then
                    if focus_enemy then
                        self._ext_movement:set_attention({ unit = focus_enemy.unit })
                    else
                        self._ext_movement:set_attention()
                    end
                    self._AI_data.focus_enemy = focus_enemy
                end

                return delay
            end
        end
    else
        if NiceTrainer._orig_sentry.choose_focus_enemy then
            SentryGunBrain._choose_focus_enemy = NiceTrainer._orig_sentry.choose_focus_enemy
            NiceTrainer._orig_sentry.choose_focus_enemy = nil
        end
    end
end

-- ─── 4. Sentry Overclock & God Stats ─────────────────────────────────
local function apply_sentry_overclock(state, dmg_mult)
    if not tweak_data or not tweak_data.weapon or not tweak_data.weapon.sentry_gun then return end
    local sentry_tweak = tweak_data.weapon.sentry_gun

    if not NiceTrainer._orig_sentry_tweak then
        NiceTrainer._orig_sentry_tweak = deep_clone(sentry_tweak)
    end

    local mult = tonumber(dmg_mult) or 10

    if state then
        sentry_tweak.DAMAGE = 50 * mult
        sentry_tweak.SPREAD = 0.1
        sentry_tweak.FIRE_RANGE = 15000
        sentry_tweak.DETECTION_RANGE = 15000
        sentry_tweak.MAX_VEL_SPIN = 1000
        sentry_tweak.MIN_VEL_SPIN = 1000
        sentry_tweak.MAX_VEL_PITCH = 1000
        sentry_tweak.MIN_VEL_PITCH = 1000
        sentry_tweak.LOST_SIGHT_VERIFICATION = 0.01
        sentry_tweak.DEATH_VERIFICATION = { 0.01, 0.02 }
        if sentry_tweak.auto then sentry_tweak.auto.fire_rate = 0.05 end
    else
        if NiceTrainer._orig_sentry_tweak then
            for k, v in pairs(NiceTrainer._orig_sentry_tweak) do
                sentry_tweak[k] = type(v) == "table" and deep_clone(v) or v
            end
        end
    end
end

-- ─── 5. Refill & Repair All Active Sentries ───────────────────────────
local function refill_all_sentries()
    if not NiceTrainer:IsInHeist() then
        NiceTrainer:Toast("Only available inside a heist!")
        return
    end

    local count = 0
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all", 1)) do
            if alive(unit) and unit.weapon and unit:weapon() and unit.character_damage and unit:character_damage() then
                local wpn = unit:weapon()
                local dmg = unit:character_damage()
                if wpn.set_ammo and dmg.repair then
                    pcall(function()
                        wpn:set_ammo(wpn._max_ammo or 1000)
                        dmg:repair()
                        count = count + 1
                    end)
                elseif wpn._ammo_total and wpn._max_ammo then
                    pcall(function()
                        wpn._ammo_total = wpn._max_ammo
                        count = count + 1
                    end)
                end
            end
        end
    end)

    NiceTrainer:Toast("Repaired and refilled " .. count .. " sentry gun(s)!")
end

-- ─── Action Registrations ─────────────────────────────────────────────

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Sentry Guns",
    badge    = "client",
    id       = "sentry_invulnerable",
    text     = "Invulnerable Sentries (God Mode)",
    tooltip  = "Player and crew sentry guns cannot take any bullet, explosive, fire, or melee damage.",
    default  = false,
    callback = apply_invulnerable_sentries
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Sentry Guns",
    badge    = "client",
    id       = "sentry_infinite_ammo",
    text     = "Infinite Sentry Ammo",
    tooltip  = "Sentries fire non-stop without ever consuming ammunition or needing bags to refill.",
    default  = false,
    callback = apply_infinite_sentry_ammo
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Sentry Guns",
    badge    = "client",
    id       = "sentry_ignore_shields",
    text     = "Sentries Target & Pierce Shields",
    tooltip  = "Allows sentry guns to acquire SWAT shield enemies as valid targets and eliminate them immediately.",
    default  = false,
    callback = apply_sentry_shield_pierce
})

NiceTrainer:RegisterAction("Player", {
    type     = "toggle_settings",
    category = "Sentry Guns",
    badge    = "client",
    id       = "sentry_overclock",
    text     = "Sentry Overclock (God-Tier Stats)",
    tooltip  = "Extremely fast target acquisition, zero spread, maximum range, and multiplied damage.",
    default  = false,
    callback = function(state)
        local mult = tonumber(NiceTrainer.Settings.sentry_damage_mult) or 10
        apply_sentry_overclock(state, mult)
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Sentry Damage Multiplier", 1, 100, tonumber(NiceTrainer.Settings.sentry_damage_mult) or 10, function(val)
            NiceTrainer.Settings.sentry_damage_mult = val
            NiceTrainer:Save()
            if NiceTrainer.Settings.sentry_overclock then
                apply_sentry_overclock(true, val)
            end
        end)
    end
})

NiceTrainer:RegisterAction("Player", {
    type           = "button",
    category       = "Sentry Guns",
    badge          = "client",
    text           = "Repair & Refill All Sentries",
    tooltip        = "Instantly heals and refills ammo on all active deployed sentry guns on the map.",
    action_btn_text = "Refill Sentries",
    callback       = refill_all_sentries
})

local function reapply_all_sentries()
    if NiceTrainer.Settings.sentry_invulnerable then apply_invulnerable_sentries(true) end
    if NiceTrainer.Settings.sentry_infinite_ammo then apply_infinite_sentry_ammo(true) end
    if NiceTrainer.Settings.sentry_ignore_shields then apply_sentry_shield_pierce(true) end
    if NiceTrainer.Settings.sentry_overclock then
        local mult = tonumber(NiceTrainer.Settings.sentry_damage_mult) or 10
        apply_sentry_overclock(true, mult)
    end
end

-- ─── Auto-Apply On Mission Load & In-Game ────────────────────────────
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplySentries", reapply_all_sentries)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_ReapplySentries", reapply_all_sentries)
