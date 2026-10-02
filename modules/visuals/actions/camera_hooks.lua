_G.CamZones = _G.CamZones or {}
CamZones.settings = CamZones.settings or {}
CamZones.spy_cameras = CamZones.spy_cameras or {}
CamZones.spy_runtime = CamZones.spy_runtime or {}
_G.NiceTrainer = _G.NiceTrainer or {}
NiceTrainer._cam_settings = CamZones.settings
NiceTrainer._spy_cameras = CamZones.spy_cameras
NiceTrainer._spy_cam_runtime = CamZones.spy_runtime

local function _store_settings(self)
	local values = self and self._values
	if not values or not values.camera_u_id then
		return
	end

	local cam_unit = self:_fetch_unit_by_unit_id(values.camera_u_id)
	if not (cam_unit and alive(cam_unit)) then
		return
	end

	local fov = values.fov or 60
	local range = (values.detection_range or 15) * 100
	local susp_range = (values.suspicion_range or 7) * 100
	local ai_enabled = values.ai_enabled and true or false
	local apply_settings = values.apply_settings and true or false

	local t = TimerManager and TimerManager:game() and TimerManager:game():time() or 0

	local st = CamZones.settings[cam_unit:key()] or {}
	st.ai_enabled = ai_enabled
	st.apply_settings = apply_settings
	st.last_update_t = t

	st.fov = fov
	st.range = range
	st.suspicion_range = susp_range

	CamZones.settings[cam_unit:key()] = st
end

if _G.ElementSecurityCamera and not NiceTrainer._cam_elem_hooked then
	NiceTrainer._cam_elem_hooked = true
	Hooks:PostHook(ElementSecurityCamera, "client_on_executed", "CamZones_ClientStore", function(self, ...)
		_store_settings(self)
	end)
	Hooks:PostHook(ElementSecurityCamera, "on_executed", "CamZones_ServerStore", function(self, ...)
		_store_settings(self)
	end)
end

local function _track_spy_camera(unit)
	if alive(unit) then
		CamZones.spy_cameras[unit:key()] = unit
	end
end

local function _untrack_spy_camera(unit)
	if unit then
		local key = unit:key()
		CamZones.spy_cameras[key] = nil
		CamZones.spy_runtime[key] = nil
	end
end

if _G.SpyCameraBase and not NiceTrainer._spy_cam_hooked then
	NiceTrainer._spy_cam_hooked = true
	Hooks:PostHook(SpyCameraBase, "init", "CamZones_SpyCameraInit", function(self, unit, ...)
		_track_spy_camera(unit)
	end)
	Hooks:PostHook(SpyCameraBase, "setup", "CamZones_SpyCameraSetup", function(self, ...)
		_track_spy_camera(self._unit)
	end)
	Hooks:PreHook(SpyCameraBase, "remove", "CamZones_SpyCameraRemove", function(self, ...)
		_untrack_spy_camera(self._unit)
	end)
	Hooks:PreHook(SpyCameraBase, "destroy", "CamZones_SpyCameraDestroy", function(self, unit, ...)
		_untrack_spy_camera(unit or self._unit)
	end)
end
