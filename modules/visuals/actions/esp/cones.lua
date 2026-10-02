local ESP = NiceTrainer.ESP

function ESP.is_camera_operational(camera_unit)
    if not (camera_unit and alive(camera_unit)) then
        return false
    end
    local base = camera_unit:base()
    if base and ((base.destroyed and base:destroyed()) or base._destroyed) then
        return false
    end
    return true
end
-- -- ─── 3D Camera Vision Cones Engine (1:1 Camera Helper) ──────────────────────

_G.CamZones = _G.CamZones or {}
CamZones.runtime = CamZones.runtime or {}
CamZones.settings = CamZones.settings or {}
CamZones.spy_cameras = CamZones.spy_cameras or {}
CamZones.spy_runtime = CamZones.spy_runtime or {}

local CONE_SEGMENTS = 36
local SPHERE_SEGMENTS = 4

local UPDATE_INTERVAL = 0.001
local DRAW_LIFETIME  = 0.003

local SEEN_RAY_INTERVAL = 0.03

local ID_LENS  = Idstring("CameraLens")
local ID_LAMP  = Idstring("g_lamp")
local ID_YAW   = Idstring("CameraYaw")
local ID_PITCH = Idstring("CameraPitch")

local DEFAULT_FOV_DEG = 60
local MIN_FOV_DEG = 1
local MAX_FOV_DEG = 360

local WIDE_FOV_DEG = 160

local UNITS_PER_METER = 100
local SPY_CAMERA_DEFAULT_RANGE = 3000
local SPY_CAMERA_DEFAULT_RADIUS = 2300

local tmp_pos = Vector3()
local tmp_cone_base = Vector3()
local tmp_dir = Vector3()
local tmp_fwd = Vector3()
local tmp_spy_pos = Vector3()
local tmp_spy_base = Vector3()
local tmp_spy_fwd = Vector3()

local function _safe_call_bool(obj, method_name)
	local fn = obj and obj[method_name]
	if not fn then
		return nil
	end
	local ok, res = pcall(fn, obj)
	if ok then
		return res and true or false
	end
	return nil
end

local function _clamp_num(value, default_value, min_value, max_value)
	value = tonumber(value) or default_value
	if value < min_value then
		return min_value
	end
	if value > max_value then
		return max_value
	end
	return value
end

local function _normalize_fov_deg(fov)
	if type(fov) ~= "number" or fov <= 0 then
		return DEFAULT_FOV_DEG
	end
	if fov <= 6.5 then
		fov = fov * (180 / math.pi)
	end
	if fov < MIN_FOV_DEG then
		return MIN_FOV_DEG
	end
	if fov > MAX_FOV_DEG then
		return MAX_FOV_DEG
	end
	return fov
end

local function _camera_sees_player(cam_unit, cam_pos, fwd, fov_deg, range, player_unit, player_head_pos, vis_mask, rt, t)
	if not player_head_pos then
		return false
	end

	local range_sq = range * range
	if mvector3.distance_sq(player_head_pos, cam_pos) > range_sq then
		rt.seen = false
		return false
	end

	mvector3.set(tmp_dir, player_head_pos)
	mvector3.subtract(tmp_dir, cam_pos)
	mvector3.normalize(tmp_dir)

	if fov_deg < WIDE_FOV_DEG then
		local ang = fwd:angle(tmp_dir)
		if ang > (fov_deg * 0.5) then
			rt.seen = false
			return false
		end
	end

	if rt.next_seen_check_t and t < rt.next_seen_check_t then
		return rt.seen == true
	end
	rt.next_seen_check_t = t + SEEN_RAY_INTERVAL

	local ray = World:raycast(
		"ray", cam_pos, player_head_pos,
		"slot_mask", vis_mask,
		"ray_type", "ai_vision",
		"ignore_unit", cam_unit,
		"report"
	)

	local seen = not ray
	rt.seen = seen
	return seen
end

local function _draw_security_cameras(t, player, player_pos, player_head_pos, vis_mask, range_mul, is_cesp)
	if not SecurityCamera or not SecurityCamera.cameras then
		return
	end

	local group_ai = managers.groupai and managers.groupai:state()
	local active_cams = group_ai and group_ai._security_cameras

	local draw_m = _clamp_num(is_cesp and NiceTrainer.Settings.cesp_camera_cones_range or NiceTrainer.Settings.esp_camera_cones_range, 5, 1, 50)
	local draw_u = draw_m * UNITS_PER_METER
	local draw_u_sq = draw_u * draw_u

	local r = 0 / 255
	local g = 255 / 255
	local b = 0 / 255
	local a = _clamp_num(is_cesp and NiceTrainer.Settings.cesp_camera_cones_alpha or NiceTrainer.Settings.esp_camera_cones_alpha, 25, 0, 255) / 255

	local brush = Draw:brush(Color(a, r, g, b), DRAW_LIFETIME)

	for _, cam_unit in ipairs(SecurityCamera.cameras) do
		if alive(cam_unit) and cam_unit:base() and cam_unit:base().is_security_camera then
			local unit_enabled = _safe_call_bool(cam_unit, "enabled")
			if unit_enabled == false then
				goto continue_camera
			end

			local base = cam_unit:base()
			if base.destroyed and base:destroyed() then
				goto continue_camera
			end

			if base._destroyed then
				goto continue_camera
			end

			-- Only process cameras that actually spawned in this heist
			if active_cams and not active_cams[cam_unit:key()] then
				goto continue_camera
			end

			if not base._look_obj and not base._pos then
				goto continue_camera
			end

			local st = CamZones.settings and CamZones.settings[cam_unit:key()]
			if st and st.ai_enabled == false then
				goto continue_camera
			end

			local obj = cam_unit:get_object(ID_LENS) or cam_unit:get_object(ID_PITCH) or cam_unit:get_object(ID_YAW) or cam_unit:get_object(ID_LAMP)
			if obj then
				obj:m_position(tmp_pos)

				local fov = _normalize_fov_deg((st and st.fov) or base._cone_angle or DEFAULT_FOV_DEG)
				local range_full = (st and st.range) or base._range or 1500
				local range_susp = (st and st.suspicion_range) or base._suspicion_range or range_full

				local base_susp_range = math.min(range_full, range_susp)
				local zone_range = base_susp_range * range_mul

				local dist_sq = mvector3.distance_sq(player_pos, tmp_pos)
				local near = (dist_sq <= draw_u_sq)

				local should_draw = false
				if near then
					-- Check if player has line of sight to the camera (not through a wall)
					local wall_ray = World:raycast(
						"ray", player_head_pos, tmp_pos,
						"slot_mask", vis_mask,
						"ray_type", "ai_vision",
						"ignore_unit", cam_unit,
						"report"
					)
					if not wall_ray then
						should_draw = true
					end
				else
					local key = cam_unit:key()
					local rt = CamZones.runtime[key]
					if not rt then
						rt = {}
						CamZones.runtime[key] = rt
					end

					mvector3.set(tmp_fwd, obj:rotation():y())
					should_draw = _camera_sees_player(cam_unit, tmp_pos, tmp_fwd, fov, zone_range, player, player_head_pos, vis_mask, rt, t)
				end

				if should_draw then
					mvector3.set(tmp_cone_base, obj:rotation():y())
					mvector3.multiply(tmp_cone_base, zone_range)
					mvector3.add(tmp_cone_base, tmp_pos)

					-- Clip cone length at wall/obstacle so it doesn't penetrate through walls
					local fwd_ray = World:raycast(
						"ray", tmp_pos, tmp_cone_base,
						"slot_mask", vis_mask,
						"ray_type", "ai_vision",
						"ignore_unit", cam_unit
					)

					local actual_range = zone_range
					if fwd_ray and fwd_ray.distance then
						actual_range = math.min(zone_range, math.max(30, fwd_ray.distance))
						mvector3.set(tmp_cone_base, obj:rotation():y())
						mvector3.multiply(tmp_cone_base, actual_range)
						mvector3.add(tmp_cone_base, tmp_pos)
					end

					if fov >= WIDE_FOV_DEG then
						brush:sphere(tmp_pos, actual_range, SPHERE_SEGMENTS)
					else
						local cone_base_rad = math.tan(fov * 0.5) * actual_range
						brush:cone(tmp_pos, tmp_cone_base, cone_base_rad, CONE_SEGMENTS)
					end
				end
			end
		end

		::continue_camera::
	end
end

local function _spy_camera_sees_player(cam_unit, cam_pos, fwd, player_head_pos, slot_mask, rt, t)
	if not player_head_pos then
		return false
	end

	mvector3.set(tmp_dir, player_head_pos)
	mvector3.subtract(tmp_dir, cam_pos)

	local dist = mvector3.length(tmp_dir)
	if dist <= 0 then
		rt.seen = true
		return true
	end

	mvector3.multiply(tmp_dir, 1 / dist)

	local along = mvector3.dot(tmp_dir, fwd) * dist
	if along < 0 or along > SPY_CAMERA_DEFAULT_RANGE then
		rt.seen = false
		return false
	end

	local radius_at_along = (along / SPY_CAMERA_DEFAULT_RANGE) * SPY_CAMERA_DEFAULT_RADIUS
	local radial_sq = math.max(0, dist * dist - along * along)
	if radial_sq > radius_at_along * radius_at_along then
		rt.seen = false
		return false
	end

	if rt.next_seen_check_t and t < rt.next_seen_check_t then
		return rt.seen == true
	end
	rt.next_seen_check_t = t + SEEN_RAY_INTERVAL

	local ray = World:raycast(
		"ray", player_head_pos, tmp_spy_base,
		"ray_type", "ai_vision",
		"slot_mask", slot_mask,
		"ignore_unit", cam_unit,
		"report"
	)

	local seen = not ray
	rt.seen = seen
	return seen
end

local function _draw_spy_cameras(t, player_pos, player_head_pos, slot_mask, is_cesp)
	if not CamZones.spy_cameras then
		return
	end

	local draw_m = _clamp_num(is_cesp and NiceTrainer.Settings.cesp_camera_cones_range or NiceTrainer.Settings.esp_camera_cones_range, 5, 1, 50)
	local draw_u = draw_m * UNITS_PER_METER
	local draw_u_sq = draw_u * draw_u
	local range_u = SPY_CAMERA_DEFAULT_RANGE
	local radius = SPY_CAMERA_DEFAULT_RADIUS

	local r = 0 / 255
	local g = 160 / 255
	local b = 255 / 255
	local a = _clamp_num(is_cesp and NiceTrainer.Settings.cesp_camera_cones_alpha or NiceTrainer.Settings.esp_camera_cones_alpha, 25, 0, 255) / 255

	local brush = Draw:brush(Color(a, r, g, b), DRAW_LIFETIME)

	for key, cam_unit in pairs(CamZones.spy_cameras) do
		if not alive(cam_unit) or not cam_unit:base() or (cam_unit:base().is_removed and cam_unit:base():is_removed()) then
			CamZones.spy_cameras[key] = nil
			CamZones.spy_runtime[key] = nil
			goto continue_spy_camera
		end

		cam_unit:m_position(tmp_spy_pos)
		mvector3.set(tmp_spy_fwd, cam_unit:rotation():y())

		local dist_sq = mvector3.distance_sq(player_pos, tmp_spy_pos)
		local near = (dist_sq <= draw_u_sq)

		local should_draw = false
		if near then
			local wall_ray = World:raycast(
				"ray", player_head_pos, tmp_spy_pos,
				"slot_mask", slot_mask,
				"ray_type", "ai_vision",
				"ignore_unit", cam_unit,
				"report"
			)
			if not wall_ray then
				should_draw = true
			end
		else
			local rt = CamZones.spy_runtime[key]
			if not rt then
				rt = {}
				CamZones.spy_runtime[key] = rt
			end

			should_draw = _spy_camera_sees_player(cam_unit, tmp_spy_pos, tmp_spy_fwd, player_head_pos, slot_mask, rt, t)
		end

		if should_draw then
			mvector3.set(tmp_spy_base, tmp_spy_fwd)
			mvector3.multiply(tmp_spy_base, range_u)
			mvector3.add(tmp_spy_base, tmp_spy_pos)

			local fwd_ray = World:raycast(
				"ray", tmp_spy_pos, tmp_spy_base,
				"slot_mask", slot_mask,
				"ray_type", "ai_vision",
				"ignore_unit", cam_unit
			)

			local actual_range = range_u
			local actual_radius = radius
			if fwd_ray and fwd_ray.distance then
				actual_range = math.min(range_u, math.max(30, fwd_ray.distance))
				actual_radius = (actual_range / range_u) * radius
				mvector3.set(tmp_spy_base, tmp_spy_fwd)
				mvector3.multiply(tmp_spy_base, actual_range)
				mvector3.add(tmp_spy_base, tmp_spy_pos)
			end

			brush:cone(tmp_spy_pos, tmp_spy_base, actual_radius, CONE_SEGMENTS)
		end

		::continue_spy_camera::
	end
end

local _cam_next_t = 0

function ESP.DrawSecurityCameraCones(t, mode)
	local is_cesp = (mode == "cesp")
	local cones_enabled = is_cesp and NiceTrainer.Settings.cesp_camera_cones or NiceTrainer.Settings.esp_camera_cones
	if not cones_enabled then
		return
	end

	local state = managers.groupai and managers.groupai:state()
	if not state or not state:whisper_mode() then
		return
	end

	t = t or (TimerManager and TimerManager:game() and TimerManager:game():time()) or 0
	if t < _cam_next_t then
		return
	end
	_cam_next_t = t + UPDATE_INTERVAL

	local player = managers.player and managers.player:local_player()
	if not alive(player) or not player:movement() then
		return
	end

	local player_pos = player:movement():m_pos()
	local player_head_pos = player:movement():m_head_pos()
	local vis_mask = managers.slot:get_mask("AI_visibility")
	local spy_vis_mask = managers.slot:get_mask("world_geometry")

	local range_mul = 1
	if player:base() and player:base().suspicion_settings then
		local ss = player:base():suspicion_settings()
		if ss and ss.range_mul then
			range_mul = ss.range_mul
		end
	end

	_draw_security_cameras(t, player, player_pos, player_head_pos, vis_mask, range_mul, is_cesp)

	local spy_enabled = is_cesp and NiceTrainer.Settings.cesp_camera_spy_cones or NiceTrainer.Settings.esp_camera_spy_cones
	if spy_enabled then
		_draw_spy_cameras(t, player_pos, player_head_pos, spy_vis_mask, is_cesp)
	end
end

NiceTrainer.DrawSecurityCameraCones = ESP.DrawSecurityCameraCones

