-- Motion Path & Movable Objects Controller for NiceTrainer (World Tab)
-- Supports Speed Multiplier, Pause/Resume, and Instant Fast-Forward / Teleport for Trains, Cranes, Elevators, and Gondolas.

NiceTrainer.MotionPathSpeedActive = false
NiceTrainer.MotionPathSpeedMul = 3.0
NiceTrainer.MotionPathPaused = false

-- Helper to find and advance motion path units
local function _advance_all_motion_paths()
    if not managers.motion_path then
        NiceTrainer:Toast("Motion Path Manager not available.")
        return 0
    end

    local paths = managers.motion_path:get_all_paths()
    if not paths or #paths == 0 then
        NiceTrainer:Toast("No active moving objects (Motion Paths) found on this heist.")
        return 0
    end

    local count = 0
    for _, path in ipairs(paths) do
        if path.units and #path.units > 0 then
            local total_points = path.points and #path.points or 1
            for _, unit_and_pos in ipairs(path.units) do
                local u_id = unit_and_pos.unit
                local target_cp = total_points

                unit_and_pos.target_checkpoint = target_cp
                unit_and_pos.initial_checkpoint = target_cp

                local unit = managers.motion_path:_get_unit(u_id)
                if alive(unit) and path.points and path.points[target_cp] then
                    unit:set_position(path.points[target_cp].point)
                    if unit:mission_element_data() then
                        unit:mission_element_data().target_checkpoint = target_cp
                    end
                    count = count + 1
                end
            end
        end

        -- Execute any arrival triggers attached to this path
        if managers.motion_path._triggers and managers.motion_path._triggers[path.id] then
            for _, trigger in ipairs(managers.motion_path._triggers[path.id]) do
                if trigger.callback and type(trigger.callback) == "function" then
                    pcall(trigger.callback)
                end
            end
        end
    end

    -- Also check mission element operators for motion paths and activate their target states
    pcall(function()
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                if script._elements then
                    for _, element in pairs(script._elements) do
                        if element._values and (element._values.operation == "goto_marker" or element._values.operation == "teleport") then
                            if element.on_executed then
                                element:on_executed(managers.player:player_unit())
                            end
                        end
                    end
                end
            end
        end
    end)

    return count
end

-- ============================================================
-- Action Registrations
-- ============================================================

-- Motion Path Speed Multiplier (Toggle-Slider)
NiceTrainer:RegisterAction("World", {
    type = "toggle_slider",
    badge = "Host",
    category = "Movable Objects & Motion Paths",
    id = "motion_path_speed_toggle",
    text = "Motion Path Speed Multiplier",
    tooltip = "Accelerates cranes, trains, elevators, and boats to the selected speed multiplier",
    default = false,
    save = false,
    min = 1.0,
    max = 10.0,
    slider_default = 3.0,
    slider_id = "motion_path_speed_val",
    callback = function(state, val)
        NiceTrainer.MotionPathSpeedActive = state
        NiceTrainer.MotionPathSpeedMul = tonumber(val) or 3.0
    end,
    slider_callback = function(val, state)
        NiceTrainer.MotionPathSpeedMul = tonumber(val) or 3.0
    end
})

-- Pause Moving Objects (Toggle)
NiceTrainer:RegisterAction("World", {
    type = "toggle",
    badge = "Host",
    category = "Movable Objects & Motion Paths",
    id = "motion_path_pause_toggle",
    text = "Pause Moving Objects",
    tooltip = "Freezes and pauses all moving trains, elevators, and cranes in transit",
    default = false,
    save = false,
    callback = function(state)
        NiceTrainer.MotionPathPaused = state
        local target_state = state and "wait" or "move"

        pcall(function()
            if managers.worlddefinition and managers.worlddefinition._mission_element_units then
                for _, me in pairs(managers.worlddefinition._mission_element_units) do
                    if alive(me) and me:name() == Idstring("units/dev_tools/mission_elements/motion_path_marker/motion_path_marker") then
                        if me:mission_element() and me:mission_element().motion_operation_set_motion_state then
                            me:mission_element():motion_operation_set_motion_state(target_state)
                        end
                    end
                end
            end
        end)
    end
})

-- Teleport / Fast-Forward Motion Paths (Button)
NiceTrainer:RegisterAction("World", {
    type = "button",
    badge = "Host",
    category = "Movable Objects & Motion Paths",
    text = "Teleport Moving Objects to End",
    tooltip = "Instantly advances all active elevators, cranes, and trains to their destination endpoint",
    action_btn_text = "Teleport",
    callback = function()
        local count = _advance_all_motion_paths()
        if count > 0 then
            NiceTrainer:Toast(string.format("Fast-forwarded %d moving object(s) to destination!", count))
        else
            NiceTrainer:Toast("Fast-forward executed on all active motion path nodes.")
        end
    end
})
