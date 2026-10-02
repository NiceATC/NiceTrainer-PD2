_G.AdvMov = _G.AdvMov or {}
AdvMov._path = ModPath or AdvMov._path
AdvMov._data_path = SavePath .. "advmovsave.txt"
AdvMov.settings = AdvMov.settings or {}

function AdvMov:_default_settings()
	return {
		runkick = false,
		kickyeet = 1,
		goldeneye = 1,
		slidestealth = 2,
		slideloud = 3,
		slidewpnangle = 15,
		wallrunwpnangle = 15,
		dashcontrols = 4,
		armorslidetuning = true,
		nullmovement = false,
		crouchsprinting = false,
		crouchjump = true,
		airvaulting = false,

		vaulting = true,
		mantlesound = true,
		vaultdebug = false
	}
end

function AdvMov:_apply_defaults()
	local defaults = self:_default_settings()
	for k, v in pairs(defaults) do
		if AdvMov.settings[k] == nil then
			AdvMov.settings[k] = v
		end
	end
end

function AdvMov:Save()
	self:_apply_defaults()
	local file = io.open(AdvMov._data_path, "w+")
	if file then
		file:write(json.encode(AdvMov.settings))
		file:close()
	end
end

function AdvMov:Load()
	self:_apply_defaults()
	local file = io.open(AdvMov._data_path, "r")
	if file then
		local ok, decoded = pcall(json.decode, file:read("*all") or "")
		if ok and type(decoded) == "table" then
			for k, v in pairs(decoded) do
				AdvMov.settings[k] = v
			end
		end
		file:close()
	end
	self:_apply_defaults()
end

function AdvMov:equipped_armor_level()
	local armor_id = nil
	if managers and managers.blackmarket and managers.blackmarket.equipped_armor then
		armor_id = managers.blackmarket:equipped_armor(true, true)
	end

	local armor_data = armor_id and tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.armors and tweak_data.blackmarket.armors[armor_id]
	local level = armor_data and armor_data.upgrade_level

	if not level and type(armor_id) == "string" then
		level = tonumber(string.match(armor_id, "level_(%d+)"))
	end

	return tonumber(level) or 1
end

AdvMov:Load()

