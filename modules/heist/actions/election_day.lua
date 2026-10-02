-- Election Day (election_day_1) - Truck Solver (HUD Waypoints)

_G.NT_ElectionDay = _G.NT_ElectionDay or {
    correct_truck_pos = nil,
    truck_element_id = nil,
    day1_waypoint_active = false,
    auto_mark_day1 = true
}

local NT_ElectionDay = _G.NT_ElectionDay

local TRUCK_COORDS = {
    [100633] = Vector3(878, -3360, 50),
    [100634] = Vector3(828, -2222, 50),
    [100635] = Vector3(848, -1084, 50),
    [100636] = Vector3(150, -3900, 50),
    [100637] = Vector3(150, -2775, 50),
    [100639] = Vector3(150, -1628, 50)
}

-- =========================================================================
-- Day 1: Mission Element Hook (CoreElementRandom)
-- =========================================================================
if RequiredScript == "core/lib/managers/mission/coreelementrandom" or (core and core.module) then
    pcall(function()
        core:module("CoreElementRandom")
        core:import("CoreMissionScriptElement")
        core:import("CoreTable")

        ElementRandom = ElementRandom or class(CoreMissionScriptElement.MissionScriptElement)

        Hooks:PostHook(ElementRandom, "on_executed", "NT_ElectionDay_GetTruckAns", function(self)
            local level_id = (Global.game_settings and Global.game_settings.level_id) or (Global.level_data and Global.level_data.level_id)
            if level_id == "election_day_1" and self._id == 100631 then
                local ans = self._values and self._values.on_executed and self._values.on_executed[1]
                if ans and ans.id then
                    local ans_id = tonumber(tostring(ans.id))
                    local pos = TRUCK_COORDS[ans_id]
                    if pos then
                        NT_ElectionDay.correct_truck_pos = pos
                        NT_ElectionDay.truck_element_id = ans_id
                        if NT_ElectionDay.auto_mark_day1 then
                            NT_ElectionDay:ApplyDay1Waypoint()
                        end
                    end
                end
            end
        end)
    end)
end

-- =========================================================================
-- Day 1: DialogManager Hook (Auto-announcements & Waypoint Cleanup)
-- =========================================================================
if DialogManager then
    Hooks:PostHook(DialogManager, "queue_dialog", "NT_ElectionDay_DialogHook", function(self, id, params)
        local level_id = (Global.game_settings and Global.game_settings.level_id) or (Global.level_data and Global.level_data.level_id)
        if level_id == "election_day_1" and NT_ElectionDay then
            if NT_ElectionDay.correct_truck_pos and not NT_ElectionDay.day1_waypoint_active and NT_ElectionDay.auto_mark_day1 then
                NT_ElectionDay:ApplyDay1Waypoint()
            elseif id == "Play_pln_ed1_03" then
                NT_ElectionDay:RemoveDay1Waypoint()
                NT_ElectionDay.correct_truck_pos = nil
            end
        end
    end)
end

-- =========================================================================
-- Day 1 Helper Functions (HUD Waypoints)
-- =========================================================================
function NT_ElectionDay:ScanDay1Truck()
    if self.correct_truck_pos then return self.correct_truck_pos end
    if not (managers and managers.mission and managers.mission._scripts) then return nil end

    for _, script in pairs(managers.mission._scripts) do
        local elem = script:element(100631)
        if elem and elem._values and elem._values.on_executed then
            local ans = elem._values.on_executed[1]
            if ans and ans.id then
                local ans_id = tonumber(tostring(ans.id))
                local pos = TRUCK_COORDS[ans_id]
                if pos then
                    self.correct_truck_pos = pos
                    self.truck_element_id = ans_id
                    return pos
                end
            end
        end
    end
    return nil
end

function NT_ElectionDay:ApplyDay1Waypoint()
    local pos = self.correct_truck_pos or self:ScanDay1Truck()
    if not pos then return false end

    if managers and managers.hud then
        pcall(function()
            managers.hud:remove_waypoint("election_day_1_right_truck")
            managers.hud:add_waypoint("election_day_1_right_truck", {
                icon = "equipment_vial",
                distance = true,
                position = pos,
                no_sync = true,
                present_timer = 0,
                state = "present",
                radius = 50,
                color = Color.green,
                blend_mode = "add"
            })
            self.day1_waypoint_active = true
        end)
        return true
    end
    return false
end

function NT_ElectionDay:RemoveDay1Waypoint()
    if managers and managers.hud then
        pcall(function()
            managers.hud:remove_waypoint("election_day_1_right_truck")
        end)
        self.day1_waypoint_active = false
    end
end

-- Reset on heist stop or restart
Hooks:Add("MissionManagerStop", "NT_ElectionDay_Cleanup", function()
    NT_ElectionDay:RemoveDay1Waypoint()
    NT_ElectionDay.correct_truck_pos = nil
end)

-- =========================================================================
-- NiceTrainer Action Registration
-- =========================================================================
if not _G.NT_ElectionDay_Actions_Registered and NiceTrainer and NiceTrainer.RegisterAction then
    _G.NT_ElectionDay_Actions_Registered = true

    -- Day 1: Auto-Mark Toggle
    NiceTrainer:RegisterAction("Heist", {
        type = "toggle",
        category = "Election Day (Day 1)",
        level_id = "election_day_1",
        id = "election_day_auto_truck",
        badge = "both",
        save = true,
        default = true,
        text = "Auto-Mark Correct Shipping Truck",
        tooltip = "Automatically computes the correct shipping truck at mission start and places a green 3D HUD waypoint.",
        callback = function(state)
            NT_ElectionDay.auto_mark_day1 = state
            if state then
                NT_ElectionDay:ApplyDay1Waypoint()
            else
                NT_ElectionDay:RemoveDay1Waypoint()
            end
        end
    })

    -- Day 1: Find & Tag Correct Truck (Manual Button)
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Election Day (Day 1)",
        level_id = "election_day_1",
        badge = "both",
        text = "Find & Mark Correct Shipping Truck",
        tooltip = "Decodes mission randomizer element 100631 and displays a green 3D HUD waypoint over the winning truck.",
        action_btn_text = "Mark Truck",
        callback = function()
            local success = NT_ElectionDay:ApplyDay1Waypoint()
            if success then
                NiceTrainer:Toast("Correct shipping truck located! 3D HUD Waypoint applied.")
            else
                NiceTrainer:Toast("Could not determine truck yet. Check if heist is fully loaded.")
            end
        end
    })

    -- Day 1: Clear Truck Waypoint
    NiceTrainer:RegisterAction("Heist", {
        type = "button",
        category = "Election Day (Day 1)",
        level_id = "election_day_1",
        badge = "client",
        text = "Clear Truck Waypoint",
        tooltip = "Removes the green HUD waypoint from the truck.",
        action_btn_text = "Clear",
        callback = function()
            NT_ElectionDay:RemoveDay1Waypoint()
            NiceTrainer:Toast("Truck waypoint removed.")
        end
    })
end
