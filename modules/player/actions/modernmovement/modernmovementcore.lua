_G.ModernMovement = _G.ModernMovement or {}

ModernMovement._path = ModPath or ModernMovement._path
ModernMovement._data_path = SavePath .. 'modernmovementsave.txt'
ModernMovement._legacy_data_path = SavePath .. 'pd3mantleslidesave.txt'
ModernMovement.settings = ModernMovement.settings or {}

function ModernMovement:_default_settings()
	return {
		goldeneye = 1,
		slidestealth = 2,
		slideloud = 3,
		slidewpnangle = 15,
		slidescreeneffectalpha = 0,
		groundslideonly = true,
		nullmovement = false,
		crouchsprinting = false,
		crouchjump = true,
		airvaulting = false,

		vaulting = true,
		mantlesound = true,
		vaultdebug = false
	}
end

function ModernMovement:_apply_defaults()
	local defaults = self:_default_settings()
	for k, v in pairs(defaults) do
		if ModernMovement.settings[k] == nil then
			ModernMovement.settings[k] = v
		end
	end
end

function ModernMovement:_sanitize_settings()
	local defaults = self:_default_settings()
	local clean = {}
	for k, v in pairs(defaults) do
		clean[k] = ModernMovement.settings[k]
		if clean[k] == nil then
			clean[k] = v
		end
	end
	ModernMovement.settings = clean
end

function ModernMovement:Save()
	self:_sanitize_settings()
	local file = io.open(ModernMovement._data_path, 'w+')
	if file then
		file:write(json.encode(ModernMovement.settings))
		file:close()
	end
end

function ModernMovement:_read_settings_file(path)
	local file = path and io.open(path, 'r')
	if not file then
		return nil
	end

	local raw = file:read('*all')
	file:close()

	local ok, decoded = pcall(json.decode, raw or '')
	if ok and type(decoded) == 'table' then
		return decoded
	end

	return nil
end

function ModernMovement:Load()
	local decoded = self:_read_settings_file(ModernMovement._data_path)
	local migrated_from_legacy = false

	-- Migrate one time from the old save name, then keep future edits
	-- in Modern Movement's own save file.
	if not decoded then
		decoded = self:_read_settings_file(ModernMovement._legacy_data_path)
		migrated_from_legacy = decoded ~= nil
	end

	if decoded then
		for k, v in pairs(decoded) do
			ModernMovement.settings[k] = v
		end
	end

	self:_sanitize_settings()

	if migrated_from_legacy then
		self:Save()
	end
end

function ModernMovement:slide_weapon_angle()
	local defaults = self:_default_settings()
	local angle = tonumber(ModernMovement.settings.slidewpnangle) or defaults.slidewpnangle or 0
	return math.clamp(angle, -30, 30)
end

function ModernMovement:play_screen_effect(duration, color, alpha, effect_id)
	if not alpha or alpha <= 0 or not managers or not managers.hud or not managers.hud.activate_effect_screen then
		return
	end
	managers.hud:activate_effect_screen(duration, color * alpha, effect_id or "ModernMovement_dodge", "topbottomrim")
end
