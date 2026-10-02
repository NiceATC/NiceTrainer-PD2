-- Unlock All Skills Action for NiceTrainer (Account Tab)
-- Hooks SkillTreeTweakData:init to provide all skill tree upgrades for free without skill points.

local ALL_SKILLS = {
    -- DO NOT TOUCH/EDIT --
	"player_fall_damage_multiplier",
	"player_fall_health_damage_multiplier",
	"player_silent_kill",
	"player_primary_weapon_when_downed",
	"player_intimidate_enemies",
	"player_special_enemy_highlight",
	"player_hostage_trade",
	"player_sec_camera_highlight",
	"player_corpse_dispose",
	"player_corpse_dispose_amount_1",
	"player_civ_harmless_melee",
	"player_walk_speed_multiplier",
	"player_steelsight_when_downed",
	"player_crouch_speed_multiplier",
	"carry_interact_speed_multiplier_1",
	"carry_interact_speed_multiplier_2",
	"carry_movement_speed_multiplier",
	"trip_mine_sensor_toggle",
	"trip_mine_sensor_highlight",
	"trip_mine_can_switch_on_off",
	"ecm_jammer_can_activate_feedback",
	"ecm_jammer_interaction_speed_multiplier",
	"ecm_jammer_can_retrigger",
	"ecm_jammer_affects_cameras",
	"striker_reload_speed_default",
	"temporary_first_aid_damage_reduction",
	"temporary_passive_revive_damage_reduction_2",
	"akimbo_recoil_index_addend_1",
	"doctor_bag",
	"ammo_bag",
	"trip_mine",
	"ecm_jammer",
	"first_aid_kit",
	"sentry_gun",
	"bodybags_bag",
	"saw",
	"cable_tie",
	"jowi",
	"x_1911",
	"x_b92fs",
	"x_deagle",
	"x_g22c",
	"x_g17",
	"x_usp",
	"x_sr2",
	"x_mp5",
	"x_akmsu",
	"x_packrat",
	"x_p226",
	"x_m45",
	"x_mp7",
	"x_ppk",
	
	
	--[[ MASTERMIND ---------------------------------------------------------------------- ]]
 
		-- MEDIC
 
	-- COMBAT MEDIC (combat_medic)
	"temporary_revive_damage_reduction_1",
	"player_revive_damage_reduction_1",
	"player_revive_health_boost", --ACED
 
	-- QUICK FIX (tea_time)
	"first_aid_kit_deploy_time_multiplier",
	"first_aid_kit_damage_reduction_upgrade", --ACED
 
	-- PAINKILLERS (fast_learner)
	"player_revive_damage_reduction_level_1",
	"player_revive_damage_reduction_level_2", --ACED
 
	-- UPPERS (tea_cookies)
	"first_aid_kit_quantity_increase_1",
	"first_aid_kit_quantity_increase_2", --ACED
	"first_aid_kit_auto_recovery_1",
 
	-- COMBAT DOCTOR (medic_2x)
	"doctor_bag_quantity",
	"doctor_bag_amount_increase1", --ACED
 
	-- INSPIRE (inspire)
	"player_revive_interaction_speed_multiplier",
	"player_morale_boost",
	"cooldown_long_dis_revive", --ACED
 
 
		-- CONTROLLER
 
	--FORCED FRIENDSHIP (triathlete)
	"cable_tie_quantity",
	"cable_tie_interact_speed_multiplier", --ACED
	"team_damage_hostage_absorption",
 
	-- CONFIDENT (cable_guy)
	"player_intimidate_range_mul",
	"player_intimidate_aura",
	"player_civ_intimidation_mul",
	"player_convert_enemies_max_minions_2", --ACED
 
	-- JOKER (joker)
	"player_convert_enemies_damage_multiplier_1",
	"player_convert_enemies",
	"player_convert_enemies_max_minions_1",
	"player_convert_enemies_damage_multiplier_2", --ACED
	"player_convert_enemies_interaction_speed_multiplier",
 
	-- STOCKHOLM SYNDROME (stockholm_syndrome)
	"player_civ_calming_alerts",
	"player_super_syndrome_1", --ACED
 
	-- PARTNER IN CRIME (control_freak)
	"player_minion_master_speed_multiplier",
	"player_passive_convert_enemies_health_multiplier_1",
	"player_minion_master_health_multiplier", --ACED
	"player_passive_convert_enemies_health_multiplier_2",
 
	-- HOSTAGE TAKER (black_marketeer)
	"player_hostage_health_regen_addend_1",
	"player_hostage_health_regen_addend_2", --ACED
 
 
		-- SHARPSHOOTER
 
	-- STABLE SHOT (stable_shot)
	"player_stability_increase_bonus_1",
	"player_not_moving_accuracy_increase_bonus_1", --ACED
 
	-- RIFLEMAN (rifleman)
	"weapon_enter_steelsight_speed_multiplier",
	"player_steelsight_normal_movement_speed",
	"assault_rifle_zoom_increase", --ACED
	"snp_zoom_increase",
	"smg_zoom_increase",
	"lmg_zoom_increase",
	"pistol_zoom_increase",
	"assault_rifle_move_spread_index_addend",
	"snp_move_spread_index_addend",
	"smg_move_spread_index_addend",
 
	-- MARKSMAN (sharpshooter)
	"weapon_single_spread_index_addend",
	"single_shot_accuracy_inc_1", --ACED
 
	-- HIGH VALUE TARGET (spotter_teamwork)
	"head_shot_ammo_return_1",
	"head_shot_ammo_return_2", --ACED
 
	-- AGGRESSIVE RELOAD (speedy_reload)
	"assault_rifle_reload_speed_multiplier",
	"smg_reload_speed_multiplier",
	"snp_reload_speed_multiplier",
	"temporary_single_shot_fast_reload_1", --ACED
 
	-- AMMO EFFICIENCY (single_shot_ammo_return) This one is actually the worst. It clearly got moved into High Value Target, but it retains ALL THE CODE NAMES OF OLD.
	"snp_graze_damage_1",
	"snp_graze_damage_2", --ACED
 
 
 
--[[ ENFORCER ------------------------------------------------------------------------ ]]
 
		-- SHOTGUNNER
 
	-- UNDERDOG (underdog)
	"player_damage_multiplier_outnumbered",
	"player_damage_dampener_outnumbered", --ACED
 
	-- SHOTGUN CQB (shotgun_cqb)
	"shotgun_reload_speed_multiplier_1",
	"shotgun_enter_steelsight_speed_multiplier", --ACED
	"shotgun_reload_speed_multiplier_2",
 
	-- SHOTGUN IMPACT (shotgun_impact)
	"shotgun_recoil_index_addend",
	"shotgun_damage_multiplier_1",
	"shotgun_damage_multiplier_2", --ACED
 
	-- FAR AWAY (far_away)
	"shotgun_steelsight_accuracy_inc_1",
	"shotgun_steelsight_range_inc_1", --ACED
 
	-- CLOSE BY (close_by)
	"shotgun_hip_run_and_shoot_1",
	"shotgun_hip_rate_of_fire_1", --ACED
	"shotgun_magazine_capacity_inc_1",
 
	-- OVERKILL (overkill)
	"player_overkill_damage_multiplier",
	"player_overkill_all_weapons", --ACED
	"weapon_swap_speed_multiplier",
 
 
		-- TANK
 
	-- RESILIANCE (oppressor)
	"player_armor_regen_time_mul_1",
	"player_flashbang_multiplier_1", --ACED
	"player_flashbang_multiplier_2",
 
	-- DIE HARD (show_of_force)
	"player_interacting_damage_multiplier",
	"player_level_2_armor_addend", --ACED
	"player_level_3_armor_addend",
	"player_level_4_armor_addend",
 
	-- TRANSPORTER (pack_mule)
	"carry_throw_distance_multiplier",
	"player_armor_carry_bonus_1", --ACED
 
	-- SHOCK AND AWE (iron_man)
	"team_armor_regen_time_multiplier",
	"player_shield_knock", --ACED
 
	-- BULLSEYE (prison_wife)
	"player_headshot_regen_armor_bonus_1",
	"player_headshot_regen_armor_bonus_2", --ACED
 
	-- IRON MAN (juggernaut)
	"player_armor_multiplier",
	"body_armor6", --ACED
 
 
		-- AMMO SPECIALIST
 
	-- SCAVENGER (scavenging)
	"player_increased_pickup_area_1",
	"player_double_drop_1", --ACED
 
	-- BULLETSTORM (ammo_reservior)
	"temporary_no_ammo_cost_1",
	"temporary_no_ammo_cost_2", --ACED
 
	-- PORTABLE SAW (portable_saw)
	"saw_secondary",
	"saw_extra_ammo_multiplier", --ACED
	"player_saw_speed_multiplier_2",
	"saw_lock_damage_multiplier_2",
 
	-- EXTRA LEAD (ammo_2x)
	"ammo_bag_quantity",
	"ammo_bag_ammo_increase1", --ACED
 
	-- SAW MASSACRE (carbon_blade)
	"saw_enemy_slicer",
	"saw_ignore_shields_1", --ACED
	"saw_panic_when_kill_1",
 
	-- FULLY LOADED (bandoliers)
	"extra_ammo_multiplier1",
	"player_pick_up_ammo_multiplier", --ACED
	"player_pick_up_ammo_multiplier_2",
	"player_regain_throwable_from_ammo_1",
 
 
 
--[[ TECHNICIAN ---------------------------------------------------------------------- ]]
 
		-- ENGINEER
 
	-- THIRD LAW (defense_up)
	"sentry_gun_cost_reduction_1",
	"sentry_gun_shield", --ACED
 
	-- SENTRY TARGETING PACKAGE (sentry_targeting_package)
	"sentry_gun_spread_multiplier",
	"sentry_gun_rot_speed_multiplier", --ACED
	"sentry_gun_extra_ammo_multiplier_1",
 
	-- ECO SENTRY (eco_sentry)
	"sentry_gun_cost_reduction_2",
	"sentry_gun_armor_multiplier", --ACED
 
	-- ENGINEERING (engineering)
	"sentry_gun_silent",
	"sentry_gun_ap_bullets", --ACED
	"sentry_gun_fire_rate_reduction_1",
 
	-- JACK OF ALL TRADES (jack_of_all_trades)
	"deploy_interact_faster_1",
	"second_deployable_1", --ACED
 
	-- TOWER DEFENSE (tower_defense)
	"sentry_gun_quantity_1",
	"sentry_gun_quantity_2", --ACED
 
 
		-- BREACHER
 
	-- HARDWARE EXPERT (hardware_expert)
	"player_drill_fix_interaction_speed_multiplier",
	"player_trip_mine_deploy_time_multiplier_2",
	"player_drill_alert",
	"player_silent_drill",
	"player_drill_autorepair_1", --ACED
 
	-- COMBAT ENGINEERING (combat_engineering)
	"trip_mine_explosion_size_multiplier_1",
	"trip_mine_damage_multiplier_1", --ACED
 
	-- DRILL SAWGEANT (drill_expert)
	"player_drill_speed_multiplier1",
	"player_drill_speed_multiplier2", --ACED
 
	-- MORE FIREPOWER (more_fire_power)
	"shape_charge_quantity_increase_1",
	"trip_mine_quantity_increase_1",
	"shape_charge_quantity_increase_2", --ACED
	"trip_mine_quantity_increase_2",
 
	-- KICKSTARTER (kick_starter)
	"player_drill_autorepair_2",
	"player_drill_melee_hit_restart_chance_1", --ACED
 
	-- FIRE TRAP (fire_trap)
	"trip_mine_fire_trap_1",
	"trip_mine_fire_trap_2", --ACED
 
 
		-- OPPRESSOR
 
	-- STEADY GRIP (steady_grip)
	"player_weapon_accuracy_increase_1",
	"player_stability_increase_bonus_2", --ACED
 
	-- HEAVY IMPACT (heavy_impact)
	"weapon_knock_down_1",
	"weapon_knock_down_2", --ACED
 
	-- FIRE CONTROL (fire_control)
	"player_hip_fire_accuracy_inc_1",
	"player_weapon_movement_stability_1", --ACED
 
	-- LOCK N LOAD (shock_and_awe)
	"player_run_and_shoot_1",
	"player_automatic_faster_reload_1", --ACED
 
	-- SUREFIRE (fast_fire)
	"player_automatic_mag_increase_1",
	"player_ap_bullets_1", --ACED
 
	-- BODY EXPERTISE (body_expertise)
	"weapon_automatic_head_shot_add_1",
	"weapon_automatic_head_shot_add_2", --ACED
 
 
 
--[[ GHOST --------------------------------------------------------------------------- ]]
 
		-- SHINOBI
 
	-- CHAMELEON (jail_workout)
	"player_suspicion_bonus",
	"player_sec_camera_highlight_mask_off",
	"player_special_enemy_highlight_mask_off", --ACED
	"player_mask_off_pickup",
	"player_small_loot_multiplier_1",
 
	-- CLEANER (cleaner)
	"player_corpse_dispose_amount_2",
	"player_extra_corpse_dispose_amount",
	"bodybags_bag_quantity", --ACED
 
	-- SIXTH SENSE (chameleon)
	"player_standstill_omniscience",
	"player_buy_bodybags_asset", --ACED
	"player_additional_assets",
	"player_cleaner_cost_multiplier",
	"player_buy_spotter_asset",
 
	-- NIMBLE (second_chances)
	"player_tape_loop_duration_1",
	"player_tape_loop_duration_2",
	"player_pick_lock_hard", --ACED
	"player_pick_lock_easy_speed_multiplier",
 
	-- ECM OVERDRIVE (ecm_booster)
	"ecm_jammer_duration_multiplier",
	"ecm_jammer_feedback_duration_boost",
	"ecm_jammer_can_open_sec_doors", --ACED
 
	-- ECM SPECIALIST (ecm_2x)
	"ecm_jammer_quantity_increase_1",
	"ecm_jammer_duration_multiplier_2", --ACED
	"ecm_jammer_feedback_duration_boost_2",
	"ecm_jammer_affects_pagers",
 
 
		-- ARTFUL DODGER
 
	-- DUCK AND COVER (sprinter)
	"player_stamina_regen_timer_multiplier",
	"player_stamina_regen_multiplier",
	"player_run_speed_multiplier",
	"player_run_dodge_chance", --ACED
 
	-- PARKOUR (awareness)
	"player_movement_speed_multiplier",
	"player_climb_speed_multiplier_1",
	"player_can_free_run", --ACED
	"player_run_and_reload",
 
	-- INNER POCKETS (thick_skin)
	"player_melee_concealment_modifier",
	"player_ballistic_vest_concealment_1", --ACED
 
	-- DIRE NEED (dire_need)
	"player_armor_depleted_stagger_shot_1",
	"player_armor_depleted_stagger_shot_2", --ACED
 
	-- SHOCKPROOF (insulation)
	"player_taser_malfunction",
	"player_taser_self_shock", --ACED
	"player_escape_taser_1",
 
	-- SNEAKY [removed] (jail_diet)
	"player_detection_risk_add_dodge_chance_1",
	"player_detection_risk_add_dodge_chance_2", --ACED
 
 
		-- SILENT KILLER
 
	-- SECOND WIND (scavenger)
	"temporary_damage_speed_multiplier",
	"player_team_damage_speed_multiplier_send", --ACED
 
	-- OPTICAL ILLUSIONS (optic_illusions)
	"player_camouflage_bonus_1",
	"player_camouflage_bonus_2",
	"player_silencer_concealment_penalty_decrease_1",
	"player_silencer_concealment_increase_1", --ACED
 
	-- THE PROFESSIONAL (silence_expert)
	"weapon_silencer_recoil_index_addend",
	"weapon_silencer_enter_steelsight_speed_multiplier",
	"weapon_silencer_spread_index_addend", --ACED
 
	-- LOW BLOW (backstab)
	"player_detection_risk_add_crit_chance_1",
	"player_detection_risk_add_crit_chance_2", --ACED
 
	-- SPECIALIZED KILLING (hitman)
	"player_marked_enemy_extra_damage",
	"player_marked_inc_dmg_distance_1", --ACED
	"weapon_steelsight_highlight_specials",
	"player_mark_enemy_time_multiplier",
	"player_marked_distance_mul",
 
	-- UNSEEN STRIKE (unseen_strike)
	"player_unseen_increased_crit_chance_1",
	"player_unseen_temp_increased_crit_chance_1", --ACED
	"player_unseen_increased_crit_chance_2",
	"player_unseen_temp_increased_crit_chance_2",
 
 
 
--[[ FUGITIVE ------------------------------------------------------------------------ ]]
 
		-- GUNSLINGER
 
	-- EQUILIBRIUM (equilibrium)
	"pistol_swap_speed_multiplier",
	"pistol_spread_index_addend", --ACED
 
	-- GUN NUT (dance_instructor)
	"pistol_magazine_capacity_inc_1",
	"pistol_fire_rate_multiplier", --ACED
 
	-- AKIMBO (akimbo)
	"akimbo_recoil_index_addend_2",
	"akimbo_extra_ammo_multiplier_1", --ACED
	"akimbo_recoil_index_addend_3",
 
	-- ONE HANDED TALENT (gun_fighter)
	"pistol_damage_addend_1",
	"pistol_damage_addend_2", --ACED
 
	-- DESPERADO (expert_handling)
	"pistol_stacked_accuracy_bonus_1",
	"pistol_reload_speed_multiplier", --ACED
 
	-- TRIGGER HAPPY (trigger_happy)
	"pistol_stacking_hit_damage_multiplier_1",
	"pistol_stacking_hit_damage_multiplier_2", --ACED
 
 
		-- REVENANT
 
	-- NINE LIVES (nine_lives)
	"player_bleed_out_health_multiplier",
	"player_additional_lives_1", --ACED
 
	-- RUNNING FROM DEATH (running_from_death)
	"player_temp_swap_weapon_faster_1",
	"player_temp_reload_weapon_faster_1",
	"player_temp_increased_movement_speed_1", --ACED
 
	-- UP YOU GO (up_you_go)
	"player_revived_damage_resist_1",
	"player_revived_health_regain_1", --ACED
 
	-- SWAN SONG (perseverance)
	"temporary_berserker_damage_multiplier_1",
	"temporary_berserker_damage_multiplier_2", --ACED
	"player_berserker_no_ammo_cost",
 
	-- FEIGN DEATH (feign_death)
	"player_cheat_death_chance_1",
	"player_cheat_death_chance_2", --ACED
 
	-- MESSIAH (messiah)
	"player_messiah_revive_from_bleed_out_1",
	"player_recharge_messiah_1", --ACED
 
 
		-- BRAWLER
 
	-- MARTIAL ARTS (martial_arts)
	"player_melee_damage_dampener",
	"player_melee_knockdown_mul", --ACED
 
	-- BLOODTHIRST (bloodthirst)
	"player_melee_damage_stacking_1",
	"player_temp_melee_kill_increase_reload_speed_1", --ACED
 
	-- PUMPING IRON (steroids)
	"player_non_special_melee_multiplier",
	"player_melee_damage_multiplier", --ACED
 
	-- COUNTERSTIKE (drop_soap)
	"player_counter_strike_melee",
	"player_counter_strike_spooc", --ACED
 
	-- BERSERKER (wolverine)
	"player_melee_damage_health_ratio_multiplier",
	"player_damage_health_ratio_multiplier", --ACED
 
	-- FRENZY (frenzy)
--	"player_healing_reduction_1",
--	"player_health_damage_reduction_1",
--	"player_max_health_reduction_1",
--	"player_healing_reduction_2", --ACED
--	"player_health_damage_reduction_2"
}

local PERK_THROWABLE_SKILLS = {
    -- Kingpin Injector
    "temporary_chico_injector_1",
    "chico_injector",
    "player_chico_preferred_target",
    "player_chico_injector_low_health_multiplier",
    "player_chico_injector_health_to_speed",

    -- Hacker Pocket ECM
    "pocket_ecm_jammer",
    "player_pocket_ecm_jammer_base",
    "player_pocket_ecm_heal_on_kill_1",
    "player_pocket_ecm_kill_dodge_1",
    "team_pocket_ecm_heal_on_kill_1",

    -- Sicario Smoke Screen
    "smoke_screen_grenade",
    "player_smoke_screen_ally_dodge_bonus",
    "player_sicario_multiplier",

    -- Tag Team Gas Dispenser
    "tag_team",
    "player_tag_team_base",
    "player_tag_team_cooldown_drain_1",
    "player_tag_team_damage_absorption",
    "player_tag_team_cooldown_drain_2",

    -- Stoic Hip Flask
    "damage_control",
    "player_damage_control_passive",
    "player_damage_control_cooldown_drain_1",
    "player_damage_control_auto_shrug",
    "player_damage_control_cooldown_drain_2",
    "player_damage_control_healing"
}

local function is_skills_enabled()
    if _G.NiceTrainer and _G.NiceTrainer.Settings then
        return _G.NiceTrainer.Settings.unlock_all_skills == true
    end
    if _G.GetNiceTrainerSettings then
        local s = _G.GetNiceTrainerSettings()
        return s and s.unlock_all_skills == true
    end
    return false
end

local function is_perk_throwables_enabled()
    if _G.NiceTrainer and _G.NiceTrainer.Settings then
        return _G.NiceTrainer.Settings.unlock_all_perk_throwables == true
    end
    if _G.GetNiceTrainerSettings then
        local s = _G.GetNiceTrainerSettings()
        return s and s.unlock_all_perk_throwables == true
    end
    return false
end

-- TweakData Hook (runs early via mod.txt)
if _G.SkillTreeTweakData then
    SkillTreeTweakData._orig_init = SkillTreeTweakData._orig_init or SkillTreeTweakData.init
    function SkillTreeTweakData:init(...)
        SkillTreeTweakData._orig_init(self, ...)
        self._orig_default_upgrades = deep_clone and deep_clone(self.default_upgrades) or self.default_upgrades
        if is_skills_enabled() then
            self.default_upgrades = ALL_SKILLS
        end
        if is_perk_throwables_enabled() and self.specializations then
            for _, skill in ipairs(PERK_THROWABLE_SKILLS) do
                for k, spec in pairs(self.specializations) do
                    if spec and spec[1] and spec[1].upgrades then
                        table.insert(spec[1].upgrades, skill)
                    end
                end
            end
        end
    end
end

local function apply_skills_unlock(enabled)
    if NiceTrainer and NiceTrainer.Settings then
        NiceTrainer.Settings.unlock_all_skills = enabled
        NiceTrainer:Save()
    end

    local st = tweak_data and tweak_data.skilltree
    if st then
        st._orig_default_upgrades = st._orig_default_upgrades or st.default_upgrades
        if enabled then
            st.default_upgrades = ALL_SKILLS
        else
            st.default_upgrades = st._orig_default_upgrades or st.default_upgrades
        end
    end

    if managers.upgrades then
        if enabled then
            for _, upgrade in ipairs(ALL_SKILLS) do
                if not managers.upgrades:aquired(upgrade) then
                    pcall(function() managers.upgrades:aquire(upgrade) end)
                end
            end
        else
            local orig = (tweak_data and tweak_data.skilltree and tweak_data.skilltree._orig_default_upgrades) or {}
            local orig_lookup = {}
            for _, u in ipairs(orig) do orig_lookup[u] = true end
            for _, upgrade in ipairs(ALL_SKILLS) do
                if not orig_lookup[upgrade] and managers.upgrades:aquired(upgrade) then
                    pcall(function() managers.upgrades:unaquire(upgrade) end)
                end
            end
        end
    end
end

local function apply_perk_throwables_unlock(enabled)
    if NiceTrainer and NiceTrainer.Settings then
        NiceTrainer.Settings.unlock_all_perk_throwables = enabled
        NiceTrainer:Save()
    end

    local st = tweak_data and tweak_data.skilltree
    if st and st.specializations and enabled then
        for _, skill in ipairs(PERK_THROWABLE_SKILLS) do
            for k, spec in pairs(st.specializations) do
                if spec and spec[1] and spec[1].upgrades then
                    local found = false
                    for _, u in ipairs(spec[1].upgrades) do
                        if u == skill then found = true break end
                    end
                    if not found then
                        table.insert(spec[1].upgrades, skill)
                    end
                end
            end
        end
    end

    if managers.upgrades then
        for _, skill in ipairs(PERK_THROWABLE_SKILLS) do
            if enabled then
                if not managers.upgrades:aquired(skill) then
                    pcall(function() managers.upgrades:aquire(skill) end)
                end
            else
                if managers.upgrades:aquired(skill) then
                    pcall(function() managers.upgrades:unaquire(skill) end)
                end
            end
        end
    end

    if NiceTrainer and NiceTrainer.Toast then
    end
end

-- Register Actions in Account tab if NiceTrainer framework is loaded
if _G.NiceTrainer and _G.NiceTrainer.RegisterAction then
    NiceTrainer:RegisterAction("Account", {
        type     = "toggle",
        category = "Unlockers & Protection",
        badge    = "safe",
        no_bind  = true,
        id       = "unlock_all_skills",
        text     = "Unlock All Skills",
        tooltip  = "Unlocks all skill tree upgrades simultaneously without spending skill points.",
        default  = false,
        callback = apply_skills_unlock
    })

    NiceTrainer:RegisterAction("Account", {
        type     = "toggle",
        category = "Unlockers & Protection",
        badge    = "client",
        no_bind  = true,
        id       = "unlock_all_perk_throwables",
        text     = "Unlock All Perk Throwables (Universal)",
        tooltip  = "Unlocks all special Perk Deck throwables & abilities (Kingpin Injector, Hacker Pocket ECM, Sicario Smoke Screen, Tag Team Gas, Stoic Flask) so they can be equipped and used with ANY Perk Deck.",
        default  = false,
        callback = apply_perk_throwables_unlock
    })

    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Account_Skills_OnLoad", function()
        if NiceTrainer.Settings.unlock_all_skills then
            apply_skills_unlock(true)
        end
        if NiceTrainer.Settings.unlock_all_perk_throwables then
            apply_perk_throwables_unlock(true)
        end
    end)
end
