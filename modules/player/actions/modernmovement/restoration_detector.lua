_G.ModernMovementCompat = _G.ModernMovementCompat or {}

function ModernMovementCompat:_mod_value(mod, names)
	if not mod then
		return nil
	end

	for _, name in ipairs(names) do
		local value = nil
		if type(mod[name]) == "function" then
			local ok, result = pcall(function()
				return mod[name](mod)
			end)
			if ok then
				value = result
			end
		elseif mod[name] ~= nil then
			value = mod[name]
		end

		if value ~= nil then
			return tostring(value)
		end
	end

	return nil
end

function ModernMovementCompat:_mod_enabled(mod)
	if not mod then
		return false
	end

	for _, name in ipairs({"IsEnabled", "is_enabled", "Enabled", "enabled"}) do
		if type(mod[name]) == "function" then
			local ok, result = pcall(function()
				return mod[name](mod)
			end)
			if ok and result == false then
				return false
			end
		elseif mod[name] == false then
			return false
		end
	end

	return true
end

function ModernMovementCompat:_normalize(value)
	value = value and string.lower(tostring(value)) or ""
	return value
end

function ModernMovementCompat:_looks_like_restoration_name(value)
	value = self:_normalize(value)
	local compact = value:gsub("[%s%p_%-]+", "")

	-- Be deliberately strict here. Addons such as "Day & Night Restoration Mod Addon"
	-- and localization packs include the words "Restoration Mod" but do not install
	-- Restoration's player/weapon API. Loading the ResMod layer for those addons on
	-- vanilla crashes when the layer calls ResMod-only helpers such as
	-- get_hipfire_stance_id().
	return compact == "restorationmod" or compact == "restoration"
end

function ModernMovementCompat:_looks_like_restoration_path(value)
	value = self:_normalize(value):gsub("\\", "/")
	value = value:gsub("/+$", "")
	local last = value:match("([^/]+)$") or value
	return self:_looks_like_restoration_name(last)
end

function ModernMovementCompat:_global_value(tbl, names)
	if type(tbl) ~= "table" then
		return nil
	end

	for _, name in ipairs(names) do
		local value = tbl[name]
		if type(value) == "function" then
			local ok, result = pcall(function()
				return value(tbl)
			end)
			if ok and result ~= nil then
				return tostring(result)
			end
		elseif value ~= nil then
			return tostring(value)
		end
	end

	return nil
end

function ModernMovementCompat:_has_restoration_global()
	-- Do not treat a loose `restoration` table as proof. Several Restoration
	-- addons/localization packages expose/use that global on vanilla. Only accept
	-- globals that identify the actual core mod by exact name or exact folder.
	for _, global_name in ipairs({"restoration", "Restoration", "RestorationMod"}) do
		local value = rawget(_G, global_name)
		if type(value) == "table" then
			local name = self:_global_value(value, {"GetName", "Name", "name", "_name", "ModName"})
			local id = self:_global_value(value, {"GetId", "Id", "id", "_id"})
			local path = self:_global_value(value, {"GetPath", "Path", "path", "_path", "ModPath", "_mod_path"})

			if self:_looks_like_restoration_name(name) or self:_looks_like_restoration_name(id) or self:_looks_like_restoration_path(path) then
				return true
			end
		end
	end

	return false
end

function ModernMovementCompat:is_restoration_installed()
	if self._restoration_checked and self._restoration_installed == true then
		return self._restoration_installed == true
	end

	self._restoration_checked = true
	self._restoration_installed = false

	if self:_has_restoration_global() then
		self._restoration_installed = true
		return true
	end

	if BLT and BLT.Mods and type(BLT.Mods.Mods) == "function" then
		local ok, mods = pcall(function()
			return BLT.Mods:Mods()
		end)
		if ok and mods then
			for _, mod in pairs(mods) do
				if self:_mod_enabled(mod) then
					local name = self:_mod_value(mod, {"GetName", "Name", "name", "_name"})
					local id = self:_mod_value(mod, {"GetId", "Id", "id", "_id"})
					local path = self:_mod_value(mod, {"GetPath", "Path", "path", "_path"})
					if self:_looks_like_restoration_name(name) or self:_looks_like_restoration_name(id) or self:_looks_like_restoration_path(path) then
						self._restoration_installed = true
						return true
					end
				end
			end
		end
	end

	return false
end
