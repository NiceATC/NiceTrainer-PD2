-- Anti-Crash & Malformed Network Packet Protection
-- Ported from HexTrainer AntiCrash.lua
local nice_hooks = {
    _originals = {},
    hijack = function(self, path, wrapper)
        if self._originals[path] then return false end
        local parts = string.split(path, "%.")
        local cls_name, fn_name = parts[1], parts[2]
        local cls = _G[cls_name]
        if not cls or type(cls[fn_name]) ~= "function" then return false end
        
        self._originals[path] = cls[fn_name]
        cls[fn_name] = function(instance, ...)
            return wrapper(self._originals[path], instance, ...)
        end
        return true
    end,
    restore = function(self, path)
        if not self._originals[path] then return end
        local parts = string.split(path, "%.")
        local cls = _G[parts[1]]
        if cls then cls[parts[2]] = self._originals[path] end
        self._originals[path] = nil
    end
}

local function nice_hlog_error(tag, msg, err)
    NiceTrainer:Log("[AntiCrash] " .. tostring(msg) .. " " .. tostring(err))
end

local hijacked_paths = {}
local notified = {}

local warn_color = Color("FF0000")

local function chat_warn(title, text)
	if not (managers and managers.chat) then
		return
	end
	managers.chat:_receive_message(1, title, text, warn_color)
end

local function resolve_peer(self, sender)
	if not sender or type(sender) ~= "userdata" then
		return nil
	end
	local verify = (self and self._verify_sender) or (BaseNetworkHandler and BaseNetworkHandler._verify_sender)
	if type(verify) ~= "function" then
		return nil
	end
	local ok, peer = pcall(verify, sender)
	if ok and peer then
		return peer
	end
	return nil
end

local function chat_notify(peer, path)
	if not peer then
		return
	end
	if managers.network and managers.network:session() and peer == managers.network:session():local_peer() then
		return
	end
	local id = peer:id() or "unknown"
	local key = id .. "|" .. path
	if notified[key] then
		return
	end
	notified[key] = true
	local name = peer:name() or "someone"
	chat_warn("Anti-Crash", name .. " tried to crash you (" .. path .. ") -- blocked.")
end

local band = bit.band
local string_byte = string.byte
local function utf8_is_ok(str)
	local i = 1
	while true do
		local c = string_byte(str, i, i)
		if not c then
			return true
		elseif c <= 127 then
			i = i + 1
		elseif c <= 193 then
			return false
		elseif c <= 223 then
			local c2 = string_byte(str, i + 1, i + 1)
			i = i + 2
			if not (c2 and band(c2, 192) == 128) then
				return false
			end
		elseif c <= 224 then
			local c2, c3 = string_byte(str, i + 1, i + 2)
			i = i + 3
			if not (c3 and c2 and band(c2, 160) == 160 and band(c3, 192) == 128) then
				return false
			end
		elseif c <= 236 then
			local c2, c3 = string_byte(str, i + 1, i + 2)
			i = i + 3
			if not (c3 and c2 and band(c2, 192) == 128 and band(c3, 192) == 128) then
				return false
			end
		elseif c <= 237 then
			local c2, c3 = string_byte(str, i + 1, i + 2)
			i = i + 3
			if not (c3 and c2 and band(c2, 224) == 128 and band(c3, 192) == 128) then
				return false
			end
		elseif c <= 239 then
			local c2, c3 = string_byte(str, i + 1, i + 2)
			i = i + 3
			if not (c3 and c2 and band(c2, 192) == 128 and band(c3, 192) == 128) then
				return false
			end
		elseif c <= 240 then
			local c2, c3, c4 = string_byte(str, i + 1, i + 3)
			i = i + 4
			if not (c4 and c3 and c2 and c2 >= 144 and c2 <= 191 and band(c3, 192) == 128 and band(c4, 192) == 128) then
				return false
			end
		elseif c <= 243 then
			local c2, c3, c4 = string_byte(str, i + 1, i + 3)
			i = i + 4
			if not (c4 and c3 and c2 and band(c2, 192) == 128 and band(c3, 192) == 128 and band(c4, 192) == 128) then
				return false
			end
		elseif c <= 244 then
			local c2, c3, c4 = string_byte(str, i + 1, i + 3)
			i = i + 4
			if not (c4 and c3 and c2 and band(c2, 240) == 128 and band(c3, 192) == 128 and band(c4, 192) == 128) then
				return false
			end
		else
			return false
		end
	end
end

local function utf8_clean(str)
	if type(str) ~= "string" then
		return str
	elseif utf8_is_ok(str) then
		return str
	else
		-- Sanitize invalid byte sequences instead of replacing the entire string with placeholder
		local cleaned = str:gsub("[\128-\255]", "")
		return cleaned ~= "" and cleaned or str
	end
end

local function utf8_clean_args(args, indices)
	for _, i in ipairs(indices) do
		local pos = i - 1
		if type(args[pos]) == "string" then
			args[pos] = utf8_clean(args[pos])
		end
	end
end

local TEXT_FIELDS = {
	["UnitNetworkHandler.activate_temporary_team_upgrade"] = { 2, 3 },
	["UnitNetworkHandler.add_synced_team_upgrade"] = { 2, 3 },
	["UnitNetworkHandler.alarm_pager_interaction"] = { 3 },
	["UnitNetworkHandler.bain_comment"] = { 2 },
	["UnitNetworkHandler.corpse_sound_play"] = { 4 },
	["UnitNetworkHandler.damage_dot"] = { 6, 8 },
	["UnitNetworkHandler.damage_fire"] = { 9 },
	["UnitNetworkHandler.from_server_ecm_jammer_place_result"] = { 4 },
	["UnitNetworkHandler.give_equipment"] = { 2 },
	["UnitNetworkHandler.interaction_set_active"] = { 5 },
	["UnitNetworkHandler.killzone_set_unit"] = { 2 },
	["UnitNetworkHandler.link_attention_no_rot"] = { 4 },
	["UnitNetworkHandler.place_deployable_bag"] = { 2 },
	["UnitNetworkHandler.play_distance_interact_redirect"] = { 3 },
	["UnitNetworkHandler.play_distance_interact_redirect_delay"] = { 3 },
	["UnitNetworkHandler.request_place_ecm_jammer"] = { 3 },
	["UnitNetworkHandler.run_local_push_child_unit"] = { 3, 4, 7, 8 },
	["UnitNetworkHandler.run_mission_door_device_sequence"] = { 3 },
	["UnitNetworkHandler.run_mission_door_sequence"] = { 3 },
	["UnitNetworkHandler.run_spawn_unit_sequence"] = { 3, 4, 5 },
	["UnitNetworkHandler.run_unit_module_function"] = { 3, 4, 5, 6, 7 },
	["UnitNetworkHandler.server_drop_carry"] = { 2 },
	["UnitNetworkHandler.server_recheck_assets"] = { 2 },
	["UnitNetworkHandler.server_secure_loot"] = { 2 },
	["UnitNetworkHandler.server_unlock_asset"] = { 2 },
	["UnitNetworkHandler.set_equipped_weapon"] = { 4, 5 },
	["UnitNetworkHandler.set_interaction_voice"] = { 3 },
	["UnitNetworkHandler.set_trade_death"] = { 2 },
	["UnitNetworkHandler.set_trade_replace"] = { 3, 4 },
	["UnitNetworkHandler.set_trade_spawn"] = { 2 },
	["UnitNetworkHandler.set_unit"] = { 3, 4, 7 },
	["UnitNetworkHandler.start_timespeed_effect"] = { 2, 3, 4 },
	["UnitNetworkHandler.statistics_tied"] = { 2 },
	["UnitNetworkHandler.stop_timespeed_effect"] = { 2 },
	["UnitNetworkHandler.sync_ai_vehicle_action"] = { 2, 4 },
	["UnitNetworkHandler.sync_carry"] = { 2 },
	["UnitNetworkHandler.sync_carry_data"] = { 3 },
	["UnitNetworkHandler.sync_cg22_dialog"] = { 2 },
	["UnitNetworkHandler.sync_change_char_tweak"] = { 3 },
	["UnitNetworkHandler.sync_deployable_attachment"] = { 4 },
	["UnitNetworkHandler.sync_deployable_equipment"] = { 2 },
	["UnitNetworkHandler.sync_detonate_incendiary_grenade"] = { 3 },
	["UnitNetworkHandler.sync_detonate_molotov_grenade"] = { 3 },
	["UnitNetworkHandler.sync_enemy_buff"] = { 3 },
	["UnitNetworkHandler.sync_enter_vehicle_host"] = { 3 },
	["UnitNetworkHandler.sync_equipment_possession"] = { 3 },
	["UnitNetworkHandler.sync_friendly_fire_damage"] = { 5 },
	["UnitNetworkHandler.sync_gain_buff"] = { 2 },
	["UnitNetworkHandler.sync_give_vehicle_loot_to_player"] = { 3 },
	["UnitNetworkHandler.sync_grenades"] = { 2 },
	["UnitNetworkHandler.sync_interacted"] = { 4 },
	["UnitNetworkHandler.sync_interacted_by_id"] = { 3 },
	["UnitNetworkHandler.sync_interaction_anim"] = { 4 },
	["UnitNetworkHandler.sync_link_spawned_unit"] = { 3, 4, 5 },
	["UnitNetworkHandler.sync_npc_vehicle_data"] = { 3 },
	["UnitNetworkHandler.sync_player_kill_statistic"] = { 2, 5, 6 },
	["UnitNetworkHandler.sync_player_movement_state"] = { 3, 5 },
	["UnitNetworkHandler.sync_proximity_activation"] = { 3, 4 },
	["UnitNetworkHandler.sync_relock_assets"] = { 2 },
	["UnitNetworkHandler.sync_remove_equipment_possession"] = { 3 },
	["UnitNetworkHandler.sync_remove_one_teamAI"] = { 2 },
	["UnitNetworkHandler.sync_run_sequence_char"] = { 3 },
	["UnitNetworkHandler.sync_santa_anim"] = { 3 },
	["UnitNetworkHandler.sync_secure_loot"] = { 2 },
	["UnitNetworkHandler.sync_show_action_message"] = { 3 },
	["UnitNetworkHandler.sync_show_hint"] = { 2 },
	["UnitNetworkHandler.sync_spawn_present"] = { 3 },
	["UnitNetworkHandler.sync_special_character_material"] = { 3 },
	["UnitNetworkHandler.sync_store_loot_in_vehicle"] = { 4 },
	["UnitNetworkHandler.sync_teammate_progress"] = { 4 },
	["UnitNetworkHandler.sync_temporary_upgrade_owned"] = { 2, 3 },
	["UnitNetworkHandler.sync_underbarrel_switch"] = { 3 },
	["UnitNetworkHandler.sync_unit_event_id_16"] = { 3 },
	["UnitNetworkHandler.sync_unit_module"] = { 4, 5, 6 },
	["UnitNetworkHandler.sync_unit_spawn"] = { 4, 5, 6 },
	["UnitNetworkHandler.sync_unlock_asset"] = { 2 },
	["UnitNetworkHandler.sync_upgrade"] = { 2, 3 },
	["UnitNetworkHandler.sync_vehicle_data"] = { 3 },
	["UnitNetworkHandler.sync_vehicle_driving"] = { 2 },
	["UnitNetworkHandler.sync_vehicle_loot"] = { 3, 5, 7 },
	["UnitNetworkHandler.sync_vehicle_player"] = { 2, 6 },
	["UnitNetworkHandler.sync_waiting_for_player_start"] = { 3, 4 },
	["UnitNetworkHandler.to_server_access_camera_trigger"] = { 3 },
	["UnitNetworkHandler.unit_sound_play"] = { 4 },
	["ConnectionNetworkHandler.client_used_projectile"] = { 2 },
	["ConnectionNetworkHandler.client_used_weapon"] = { 2 },
	["ConnectionNetworkHandler.discover_host_reply"] = { 2, 4, 5, 7 },
	["ConnectionNetworkHandler.feed_lootdrop"] = { 3, 4 },
	["ConnectionNetworkHandler.feed_lootdrop_skirmish"] = { 2 },
	["ConnectionNetworkHandler.join_request_reply"] = { 4, 9, 10, 11 },
	["ConnectionNetworkHandler.lobby_info"] = { 5, 6 },
	["ConnectionNetworkHandler.lobby_sync_update_difficulty"] = { 2 },
	["ConnectionNetworkHandler.peer_handshake"] = { 2, 4, 8, 9 },
	["ConnectionNetworkHandler.preplanning_reserved"] = { 2 },
	["ConnectionNetworkHandler.propagate_alert"] = { 2 },
	["ConnectionNetworkHandler.request_drop_in_pause"] = { 3 },
	["ConnectionNetworkHandler.request_join"] = { 2, 3, 4 },
	["ConnectionNetworkHandler.request_player_name_reply"] = { 2 },
	["ConnectionNetworkHandler.reserve_preplanning"] = { 2 },
	["ConnectionNetworkHandler.set_auto_assault_ai_trade"] = { 2 },
	["ConnectionNetworkHandler.set_member_ready"] = { 5 },
	["ConnectionNetworkHandler.sync_award_achievement"] = { 2 },
	["ConnectionNetworkHandler.sync_crime_spree_gage_asset_event"] = { 3 },
	["ConnectionNetworkHandler.sync_crime_spree_mission"] = { 3 },
	["ConnectionNetworkHandler.sync_crime_spree_modifier"] = { 2 },
	["ConnectionNetworkHandler.sync_outfit"] = { 2 },
	["ConnectionNetworkHandler.sync_phalanx_vip_achievement_unlocked"] = { 2 },
	["ConnectionNetworkHandler.sync_player_installed_mod"] = { 3, 4 },
	["ConnectionNetworkHandler.sync_safehouse_room_tier"] = { 2 },
	["ConnectionNetworkHandler.sync_synced_unit_outfit"] = { 3, 4 },
	["ConnectionNetworkHandler.sync_used_projectile"] = { 2 },
	["ConnectionNetworkHandler.sync_used_weapon"] = { 2 },
}

local function check_outfit_string(outfit_string, peer)
	if not managers.blackmarket then
		return true
	end
	local outfit = managers.blackmarket:unpack_outfit_from_string(outfit_string)
	if not outfit then
		return false
	end
	if not tweak_data.blackmarket.melee_weapons[outfit.melee_weapon] then
		return false
	end
	if not managers.upgrades or not managers.upgrades:weapon_upgrade_by_factory_id(outfit.primary.factory_id) or not managers.upgrades:weapon_upgrade_by_factory_id(outfit.secondary.factory_id) then
		return false
	end
	if peer and alive(peer:unit()) then
		local old_outfit = managers.blackmarket:unpack_outfit_from_string(peer:profile("outfit_string"))
		if old_outfit and outfit.armor_skin ~= old_outfit.armor_skin then
			return false
		end
	end
	return true
end

local VALIDATORS = {
	["ConnectionNetworkHandler.sync_outfit"] = function(self, args)
		local outfit_string = args[1]
		local sender = args[#args]
		local peer = resolve_peer(self, sender)
		return check_outfit_string(outfit_string, peer)
	end,
	["UnitNetworkHandler.set_stance"] = function(self, args)
		local unit, stance_code = args[1], args[2]
		if not alive(unit) then
			return true
		end
		local mov = unit.movement and unit:movement()
		if not mov then
			return true
		end
		return mov._stance ~= nil and mov._stance.values ~= nil and mov._stance.values[stance_code] ~= nil
	end,
	["UnitNetworkHandler.player_action_walk_nav_point"] = function(self, args)
		local unit = args[1]
		if not alive(unit) then
			return true
		end
		local slot = unit:slot()
		return slot == 3 or slot == 5
	end,
}

local real_world
local ids_unit = Idstring("unit")
local fake_world = setmetatable({
	spawn_unit = function(fw, ids_unit_name, ...)
		if not PackageManager:has(ids_unit, ids_unit_name:id()) then
			return
		end
		return real_world:spawn_unit(ids_unit_name, ...)
	end,
}, {
	__index = function(t, k)
		local v = real_world[k]
		if type(v) == "function" then
			return function(fw, ...)
				return v(real_world, ...)
			end
		end
		return v
	end,
})

local function enable_spawn_guard()
	real_world = real_world or World
	World = fake_world
end

local function disable_spawn_guard()
	World = real_world
end

local SPAWN_GUARD = {
	["HuskPlayerMovement.anim_cbk_spawn_melee_item"] = true,
	["HuskPlayerMovement.anim_clbk_spawn_dropped_magazine"] = true,
	["UnitNetworkHandler.request_throw_projectile"] = true,
	["UnitNetworkHandler.sync_throw_projectile"] = true,
}

local function retaliate_slowmo(peer)
	if not peer then
		return
	end
	if managers.network and managers.network:session() and peer == managers.network:session():local_peer() then
		return
	end
	peer:send("start_timespeed_effect", "pause", "pausable", "player;game;game_animation", 0.1, 1, 5, 1)
end

local function build_wrapper(path, silent)
	return function(original, self, ...)
		local n = select("#", ...)
		local args = { ... }

		local text_fields = TEXT_FIELDS[path]
		if text_fields then
			utf8_clean_args(args, text_fields)
		end

		local validator = VALIDATORS[path]
		if validator and not validator(self, args) then
			return
		end

		local guard_spawn = SPAWN_GUARD[path]
		if guard_spawn then
			enable_spawn_guard()
		end
		local results = { pcall(original, self, unpack(args, 1, n)) }
		if guard_spawn then
			disable_spawn_guard()
		end

		if results[1] then
			return unpack(results, 2)
		end

		if silent then
			nice_hlog_error("anti_crash", "caught error in " .. path .. ":", results[2])
			return
		end

		local sender = args[n]
		local peer = resolve_peer(self, sender)
		chat_notify(peer, path)
		retaliate_slowmo(peer)
	end
end

local function install(path, silent)
	if nice_hooks._originals[path] then
		return
	end
	local installed = nice_hooks:hijack(path, build_wrapper(path, silent))
	if installed then
		table.insert(hijacked_paths, path)
	end
end

local FULL_CLASSES = { "ConnectionNetworkHandler", "UnitNetworkHandler" }
local NAMED_FUNCTIONS = {
	HostNetworkSession = {
		"on_join_request_received", "on_peer_connection_established",
		"chk_spawn_member_unit", "on_drop_in_pause_confirmation_received",
		"on_peer_finished_loading_outfit", "on_set_member_ready",
	},
	PlayerManager = { "select_next_item", "select_previous_item", "add_sentry_gun", "remove_equipment" },
	PlayerTurret = { "_postion_player_on_turret" },
	EnemyManager = { "set_gfx_lod_enabled" },
	HuskPlayerMovement = { "anim_cbk_spawn_melee_item", "anim_clbk_spawn_dropped_magazine" },
}

local function install_full_class(class_name)
	local class = _G[class_name]
	if type(class) ~= "table" then return end
	for fname, f in pairs(class) do
		if type(f) == "function" and fname ~= "new" and fname:sub(1, 1) ~= "_" then
			install(class_name .. "." .. fname)
		end
	end
end

local function install_named(class_name, fnames)
	local class = _G[class_name]
	if type(class) ~= "table" then return end
	for _, fname in ipairs(fnames) do
		if type(class[fname]) == "function" then
			install(class_name .. "." .. fname, true)
		end
	end
end

local function sanitize_blueprint(factory_id, blueprint)
	if type(blueprint) ~= "table" or not managers.weapon_factory then return blueprint end
	local default_blueprint = managers.weapon_factory:get_default_blueprint_by_factory_id(factory_id)
	if not default_blueprint then return blueprint end
	local new_blueprint = table.deep_map_copy(default_blueprint)
	local pass, changed = 0, false
	repeat
		pass = pass + 1
		changed = false
		for _, part_id in ipairs(blueprint) do
			if not table.contains(new_blueprint, part_id) then
				managers.weapon_factory:change_part_blueprint_only(factory_id, part_id, new_blueprint)
				changed = true
			end
		end
	until not changed or pass > 5
	return new_blueprint
end

local function install_blueprint_sanitizer()
	if type(WeaponFactoryManager) ~= "table" then return end
	local path = "WeaponFactoryManager.unpack_blueprint_from_string"
	if nice_hooks._originals[path] then return end
	local installed = nice_hooks:hijack(path, function(original, self, factory_id, blueprint_string)
		local blueprint = original(self, factory_id, blueprint_string)
		return sanitize_blueprint(factory_id, blueprint)
	end)
	if installed then table.insert(hijacked_paths, path) end
end

local function install_lobby_mods_sanitizer()
	if type(NetworkMatchMakingSTEAM) ~= "table" then return end
	local path = "NetworkMatchMakingSTEAM.is_server_ok"
	if nice_hooks._originals[path] then return end
	local installed = nice_hooks:hijack(path, function(original, self, friends_only, room, attributes_list, ...)
		if type(attributes_list) == "table" and type(attributes_list.mods) == "string" then
			local chunks = string.split(attributes_list.mods, "|")
			for i = 1, #chunks do chunks[i] = utf8_clean(chunks[i]) end
			attributes_list.mods = table.concat(chunks, "|")
		end
		return original(self, friends_only, room, attributes_list, ...)
	end)
	if installed then table.insert(hijacked_paths, path) end
end

local function install_preload_part_guard()
	install_named("WeaponFactoryManager", { "_preload_part" })
end

local function enable_anti_crash()
	for _, class_name in ipairs(FULL_CLASSES) do install_full_class(class_name) end
	for class_name, fnames in pairs(NAMED_FUNCTIONS) do install_named(class_name, fnames) end
	install_blueprint_sanitizer()
	install_lobby_mods_sanitizer()
	install_preload_part_guard()
end

-- Guard SecurityCamera against uninitialized / nil _last_detect_t crashes
local function secure_security_camera()
	if not _G.SecurityCamera or SecurityCamera._nt_anticrash_secured then return end
	SecurityCamera._nt_anticrash_secured = true

	local orig_cam_upd_det = SecurityCamera._upd_detection
	function SecurityCamera:_upd_detection(t, ...)
		if self._destroyed or not self._look_obj then
			return
		end
		if not self._last_detect_t then
			self._last_detect_t = t or (TimerManager and TimerManager:game() and TimerManager:game():time()) or 0
		end
		if not self._detection_interval then
			self._detection_interval = 0.1
		end
		return orig_cam_upd_det(self, t, ...)
	end

	local orig_cam_upd = SecurityCamera.update
	function SecurityCamera:update(unit, t, dt, ...)
		if self._destroyed or not self._look_obj then
			if self._update_tape_loop_restarting then
				pcall(self._update_tape_loop_restarting, self, unit, t, dt)
			end
			return
		end
		if not self._last_detect_t then
			self._last_detect_t = t or (TimerManager and TimerManager:game() and TimerManager:game():time()) or 0
		end
		return orig_cam_upd(self, unit, t, dt, ...)
	end
end

local function secure_civilian_logic_flee()
	if not _G.CivilianLogicFlee or CivilianLogicFlee._nt_anticrash_secured then return end
	CivilianLogicFlee._nt_anticrash_secured = true

	local orig_on_alert = CivilianLogicFlee.on_alert
	function CivilianLogicFlee.on_alert(data, alert_data, ...)
		if not data or not alert_data or type(alert_data) ~= "table" then
			return
		end
		local ok, res = pcall(orig_on_alert, data, alert_data, ...)
		if not ok then
			return
		end
		return res
	end
end

local function secure_mission_doors_and_timers()
	if _G.MissionDoor and not MissionDoor._nt_anticrash_secured then
		MissionDoor._nt_anticrash_secured = true
		local orig_report_completed = MissionDoor.report_completed
		function MissionDoor:report_completed(...)
			local ok, res = pcall(orig_report_completed, self, ...)
			if not ok then return end
			return res
		end
		local orig_run_sequence = MissionDoor.run_sequence
		function MissionDoor:run_sequence(...)
			local ok, res = pcall(orig_run_sequence, self, ...)
			if not ok then return end
			return res
		end
	end

	if _G.TimerGui and not TimerGui._nt_anticrash_secured then
		TimerGui._nt_anticrash_secured = true
		local orig_done = TimerGui.done
		function TimerGui:done(...)
			local ok, res = pcall(orig_done, self, ...)
			if not ok then return end
			return res
		end
	end
end

secure_security_camera()
secure_civilian_logic_flee()
secure_mission_doors_and_timers()
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_AntiCrash_SecureCamera_Load", function()
	secure_security_camera()
	secure_civilian_logic_flee()
	secure_mission_doors_and_timers()
end)
Hooks:Add("GameSetupUpdate", "NiceTrainer_AntiCrash_SecureCamera_Loop", function()
	if not SecurityCamera or not SecurityCamera._nt_anticrash_secured then
		secure_security_camera()
	end
	if not CivilianLogicFlee or not CivilianLogicFlee._nt_anticrash_secured then
		secure_civilian_logic_flee()
	end
	if not MissionDoor or not MissionDoor._nt_anticrash_secured then
		secure_mission_doors_and_timers()
	end
end)

local function disable_anti_crash()
	for _, path in ipairs(hijacked_paths) do nice_hooks:restore(path) end
	hijacked_paths = {}
	notified = {}
end

NiceTrainer:RegisterAction("Settings", {
    type = "toggle",
    category = "Configuration",
    id = "anti_crash",
	no_bind = true,
	badge = "safe",
    text = "Advanced Anti-Crash",
    tooltip = "Prevents malformed network packets and unhandled unit states from crashing you.",
    default = true,
    callback = function(state)
        if state then enable_anti_crash() else disable_anti_crash() end
    end
})

if NiceTrainer.Settings.anti_crash then
    enable_anti_crash()
end

