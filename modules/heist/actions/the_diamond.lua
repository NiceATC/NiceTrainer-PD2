-- The Diamond (mus) - Floor Tile Puzzle Guide (TDPG) & Traps Disabler

if not TDPGMod then
    TDPGMod = {
        enabled = false,
        _brush = Draw:brush(),
        drawn_tiles = {},
        tile_data = {}
    }
end

if Global.level_data and Global.level_data.level_id == "mus" then
    local hook_name = Network:is_server() and "on_executed" or "client_on_executed"

    function TDPGMod:init(hook)
        if hook == "core/lib/managers/coreworldinstancemanager" then
            Hooks:PostHook(CoreWorldInstanceManager, "add_instance_data", "TDPG_AddInstanceData", function(manager, instance)
                if instance.name:match("^mus_tile_[a-i]00[1-6]$") then
                    local base_index = instance.start_index + manager:start_offset_index()
                    self.tile_data[base_index + 100005] = base_index + 100001
                end
            end)
        elseif hook == "lib/managers/missionmanager" then
            function TDPGMod:add_drawable(element)
                if type(self.drawn_tiles) == "table" and type(element) == "table" then
                    local shape = element._shapes and element._shapes[1]

                    if type(shape) == "table" then
                        local rot = shape:rotation()

                        table.insert(self.drawn_tiles, {
                            pos = shape:position() - rot:z() * (shape._properties.height - 20) / 2,
                            width = rot:x() * shape._properties.width / 2,
                            depth = rot:y() * shape._properties.depth / 2,
                            height = Vector3(0, 0, 0.3)
                        })
                    end
                end
            end

            Hooks:PostHook(MissionScriptElement, "init", "TDPG_InitTiles", function(element, script, data)
                if data.id == 101517 or data.id == 101784 then
                    Hooks:PostHook(element, hook_name, "TDPG_ClearTiles", function()
                        if data.id == 101784 then
                            Hooks:RemovePostHook("TDPG_UpdateDigitalGui")
                            Hooks:RemovePostHook("TDPG_HighlightTile")
                            Hooks:RemovePostHook("TDPG_UpdateTiles")
                            Hooks:RemovePostHook("TDPG_ClearTiles")
                        end

                        self.drawn_tiles = {}
                    end)
                elseif type(self.tile_data[data.id]) == "number" then
                    Hooks:PostHook(element, hook_name, "TDPG_HighlightTile", function()
                        self:add_drawable(script:element(self.tile_data[data.id]))
                    end)
                end
            end)

            Hooks:PostHook(MissionScript, "update", "TDPG_UpdateTiles", function()
                if TDPGMod.enabled and #self.drawn_tiles > 0 then
                    for _, tile in ipairs(self.drawn_tiles) do
                        self._brush:box(tile.pos, tile.width, tile.depth, tile.height)
                    end
                end
            end)
        elseif hook == "lib/units/props/digitalgui" then
            Hooks:PostHook(DigitalGui, "init", "TDPG_InitDigitalGui", function(gui, unit)
                if alive(unit) and unit:name():key() == "5a7e636bc31e53b2" then
                    Hooks:PostHook(gui, "_update_timer_text", "TDPG_UpdateDigitalGui", function()
                        if gui._timer > 0 then
                            if gui._timer <= 2.5 then
                                self._brush:set_color(Color((gui._timer / 2.5) ^ 0.7 * 0.03, 1, 0, 0))
                            elseif gui._timer <= 15 then
                                self._brush:set_color(Color(0.03, 1, (gui._timer - 5) / 10 ^ 0.3, 0))
                            elseif gui._timer <= 30 then
                                self._brush:set_color(Color(0.03, 1 - (gui._timer - 15) / 30 ^ 0.3, 1, 0))
                            else
                                self._brush:set_color(Color(0.03, 0, 1, 0))
                            end
                        end
                    end)

                    self._brush:set_color(Color(0.03, 0, 1, 0))
                end
            end)
        end
    end

    if RequiredScript then
        TDPGMod:init(RequiredScript)
    end
end

-- =========================================================================
-- NiceTrainer Actions Registration (Register only once)
-- =========================================================================
if not _G.NT_Diamond_Actions_Registered and NiceTrainer and NiceTrainer.RegisterAction then
    _G.NT_Diamond_Actions_Registered = true

    -- Action 1: Floor Tile Guide (TDPG)
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "The Diamond (mus)",
        level_id = { "mus", "diamond", "the_diamond" },
        id = "diamond_puzzle_guide",
        badge = "client",
        save = true,
        default = false,
        text = "Floor Tile Guide (TDPG)",
        tooltip = "Highlights the safe floor path in real-time synced with the circuit timer.",
        callback = function(state)
            TDPGMod.enabled = state
            if not state then
            else
            end
        end
    })

    -- Action 2: Make All Tiles Safe (Bypass Floor Puzzle)
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "The Diamond (mus)",
        level_id = { "mus", "diamond", "the_diamond" },
        badge = "host",
        text = "Make All Tiles Safe (Bypass Puzzle)",
        tooltip = "Neutralizes all gas triggers, alarms, and wrong-step traps completely so you can walk straight across the puzzle room safely.",
        action_btn_text = "Safe Floor",
        callback = function()
            local count = 0
            if managers.mission and managers.mission._scripts then
                for _, script in pairs(managers.mission._scripts) do
                    for _, elem in pairs(script:elements()) do
                        local name = string.lower(elem:editor_name() or "")
                        if name:find("gas", 1, true) 
                           or name:find("fail_tile", 1, true) 
                           or name:find("alarm_tile", 1, true) 
                           or name:find("wrong_step", 1, true)
                           or name:find("wrong_tile", 1, true)
                           or name:find("tile_alarm", 1, true)
                           or name:find("timer_reset", 1, true)
                           or name:find("puzzle_timer", 1, true) then
                            elem:set_enabled(false)
                            count = count + 1
                        end
                    end
                end
            end

            if managers.killzone and managers.killzone._zones then
                for _, zone in pairs(managers.killzone._zones) do
                    if zone.type == "gas" then
                        zone.type = "none"
                    end
                end
            end
        end
    })

    -- Action 3: Disable Toxic Gas & Floor Alarms
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "The Diamond (mus)",
        level_id = { "mus", "diamond", "the_diamond" },
        badge = "host",
        text = "Disable Toxic Gas & Floor Alarms",
        tooltip = "Disables the poison gas triggers and floor traps completely.",
        action_btn_text = "Disable",
        callback = function()
            local disabled_count = 0
            if managers.mission and managers.mission._scripts then
                for _, script in pairs(managers.mission._scripts) do
                    for _, elem in pairs(script:elements()) do
                        local name = string.lower(elem:editor_name() or "")
                        if name:find("gas", 1, true) 
                           or name:find("fail_tile", 1, true) 
                           or name:find("alarm_tile", 1, true) 
                           or name:find("wrong_step", 1, true)
                           or name:find("wrong_tile", 1, true)
                           or name:find("tile_alarm", 1, true) then
                            elem:set_enabled(false)
                            disabled_count = disabled_count + 1
                        end
                    end
                end
            end

            if managers.killzone and managers.killzone._zones then
                for _, zone in pairs(managers.killzone._zones) do
                    if zone.type == "gas" then
                        zone.type = "none"
                    end
                end
            end
        end
    })

    -- Action 4: Freeze / Infinite Puzzle Timer
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "The Diamond (mus)",
        level_id = { "mus", "diamond", "the_diamond" },
        badge = "host",
        text = "Freeze Puzzle Countdown Timer",
        tooltip = "Stops the circuit countdown timer from resetting the safe floor path.",
        action_btn_text = "Freeze",
        callback = function()
            local found = false
            for _, unit in pairs(World:find_units_quick("all")) do
                if alive(unit) and unit:digital_gui() and unit:name():key() == "5a7e636bc31e53b2" then
                    local gui = unit:digital_gui()
                    gui._timer = 999999
                    gui._timer_paused = true
                    found = true
                end
            end
            if managers.mission and managers.mission._scripts then
                for _, script in pairs(managers.mission._scripts) do
                    for id, elem in pairs(script:elements()) do
                        if id == 101517 or id == 101784 then
                            elem:set_enabled(false)
                            found = true
                        end
                    end
                end
            end
            if found then
            else
            end
        end
    })

end
