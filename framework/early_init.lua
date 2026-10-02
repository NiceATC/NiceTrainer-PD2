if not _G.GetNiceTrainerSettings then
    _G.GetNiceTrainerSettings = function()
        local save_path = SavePath .. "NiceTrainer.json"
        local legacy_path = SavePath .. "NiceTrainer.txt"
        local active_path = save_path
        
        if not (io.file_is_readable and io.file_is_readable(save_path)) and (io.file_is_readable and io.file_is_readable(legacy_path)) then
            active_path = legacy_path
        end

        if io.load_as_json and io.file_is_readable and io.file_is_readable(active_path) then
            return io.load_as_json(active_path) or {}
        end

        local file = io.open(active_path, "r")
        if file then
            local success, content = pcall(function() return file:read("*a") end)
            file:close()
            if success and content then
                local s, decoded = pcall(json.decode, content)
                if s and type(decoded) == "table" then return decoded end
            end
        end
        return {}
    end
end
