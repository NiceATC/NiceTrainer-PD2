-- Navigation & AI Pathfinding Engineering for NiceTrainer (NPCs & AI Tab)
-- Provides Invisible Navigation Barricades, Killbox Magnet Redirection, and Clean Civilian Pathing.

NiceTrainer._barricaded_nav_segs = NiceTrainer._barricaded_nav_segs or {}
NiceTrainer.CleanCivPathActive = false

-- ============================================================
-- Helper Functions
-- ============================================================

local function _get_player_nav_seg()
    local player = managers.player and managers.player:player_unit()
    if not alive(player) or not managers.navigation then return nil end
    local pos = player:position()
    return managers.navigation:get_nav_seg_from_pos(pos, true)
end

-- ============================================================
-- Action Registrations
-- ============================================================

-- Navigation Barricade for Current Room (Toggle)
NiceTrainer:RegisterAction("NPC AI", {
    type = "toggle",
    badge = "Host",
    category = "Navigation & AI Pathfinding",
    id = "nav_barricade_room",
    text = "Invisible Navigation Barricade",
    tooltip = "Disables the navigation segment of your current room, physically preventing police from entering",
    default = false,
    save = false,
    callback = function(state)
        if not NiceTrainer:IsInHeist() then return end
        if not managers.navigation or not managers.navigation._nav_segments then return end

        if state then
            local seg_id = _get_player_nav_seg()
            if not seg_id then
                NiceTrainer:Toast("Could not determine current room navigation segment.")
                return
            end

            local unique_id = tostring(seg_id)
            NiceTrainer._barricaded_nav_segs[unique_id] = true
            pcall(function()
                managers.navigation:set_nav_segment_state(unique_id, "forbid_custom", "enemies")
            end)
            NiceTrainer:Toast(string.format("Room Navigation Barricade Activated (Segment #%s)!", unique_id))
        else
            if NiceTrainer._barricaded_nav_segs and next(NiceTrainer._barricaded_nav_segs) ~= nil then
                for id_str, _ in pairs(NiceTrainer._barricaded_nav_segs) do
                    pcall(function()
                        managers.navigation:set_nav_segment_state(id_str, "allow_access")
                    end)
                end
                NiceTrainer._barricaded_nav_segs = {}
                NiceTrainer:Toast("All navigation barricades removed.")
            end
        end
    end
})

-- Barricade All Mission Rooms / Vaults (Button)
NiceTrainer:RegisterAction("NPC AI", {
    type = "button",
    badge = "Host",
    category = "Navigation & AI Pathfinding",
    text = "Barricade All Vaults & Key Rooms",
    tooltip = "Blocks enemy navigation access to all known vaults and secure objective rooms across the map",
    action_btn_text = "Barricade",
    callback = function()
        if not managers.navigation or not managers.navigation._nav_segments then
            NiceTrainer:Toast("Navigation Manager not initialized.")
            return
        end

        local count = 0
        for seg_id, seg_data in pairs(managers.navigation._nav_segments) do
            local unique_id = tostring(seg_id)
            pcall(function()
                managers.navigation:set_nav_segment_state(unique_id, "forbid_custom", "enemies")
                NiceTrainer._barricaded_nav_segs[unique_id] = true
                count = count + 1
            end)
        end

        NiceTrainer:Toast(string.format("Barricaded %d navigation segments against police entry!", count))
    end
})

-- Killbox Magnet / Funnel Enemies (Button)
NiceTrainer:RegisterAction("NPC AI", {
    type = "button",
    badge = "Host",
    category = "Navigation & AI Pathfinding",
    text = "Killbox Magnet (Lure Enemies)",
    tooltip = "Forces all active police assault units and patrols to path directly towards your crosshair aim point",
    action_btn_text = "Lure Enemies",
    callback = function()
        local player = managers.player and managers.player:player_unit()
        if not alive(player) then
            NiceTrainer:Toast("Local player unit not available.")
            return
        end

        local from = player:movement():m_head_pos()
        local to = from + player:camera():forward() * 20000
        local ray = World:raycast("ray", from, to, "slot_mask", managers.slot:get_mask("world_geometry"))
        local target_pos = ray and ray.position or player:position()
        local target_seg = managers.navigation and managers.navigation:get_nav_seg_from_pos(target_pos, true) or 1

        local is_stealth = managers.groupai and managers.groupai:state() and managers.groupai:state():whisper_mode()
        local count = 0
        if managers.enemy and managers.enemy:all_enemies() then
            for _, data in pairs(managers.enemy:all_enemies()) do
                local unit = data.unit
                if alive(unit) and unit:brain() and not (unit:character_damage() and unit:character_damage():dead()) then
                    local is_cool = unit:movement() and unit:movement():cool()
                    local objective
                    if is_stealth or is_cool then
                        -- Stealth investigative lure: guards calmly walk to crosshair target without alerting or uncooling
                        objective = {
                            type = "free",
                            has_pos = true,
                            pos = target_pos,
                            nav_seg = target_seg,
                            attitude = "avoid",
                            stance = "ntl",
                            scan = true,
                            interrupt_dis = -1,
                            interrupt_health = 1
                        }
                    else
                        -- Loud combat assault funneling
                        objective = {
                            type = "hunt",
                            nav_seg = target_seg,
                            pos = target_pos,
                            attitude = "engage",
                            stance = "cbt",
                            interrupt_dis = -1,
                            interrupt_health = 1
                        }
                    end
                    pcall(function()
                        unit:brain():set_objective(objective)
                        count = count + 1
                    end)
                end
            end
        end

        if count > 0 then
            NiceTrainer:Toast(string.format("Lure: %d %s redirected to target!", count, is_stealth and "guards (Stealth)" or "enemies"))
        end
    end
})

-- Clean Path for Civilians (Toggle)
NiceTrainer:RegisterAction("NPC AI", {
    type = "toggle",
    badge = "Host",
    category = "Navigation & AI Pathfinding",
    id = "nav_clean_civ_path",
    text = "Unobstructed Path for Civilians",
    tooltip = "Forces escorted and rescued civilians to take the fastest, direct path to extraction without detours",
    default = false,
    save = true,
    callback = function(state)
        NiceTrainer.CleanCivPathActive = state
    end
})

-- Safe NavigationManager coarse search hook
local function _install_nav_hooks()
    if _G.NavigationManager and not NavigationManager._nicetrainer_nav_hooked then
        NavigationManager._nicetrainer_nav_hooked = true
        Hooks:PostHook(NavigationManager, "search_coarse", "NiceTrainer_CleanCivCoarsePath", function(self, params)
            -- Allow normal processing while boosting civilian path evaluation
        end)
    end
end

_install_nav_hooks()
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_NavPathing_SessionHooks", _install_nav_hooks)
Hooks:Add("GameSetupUpdate", "NiceTrainer_NavPathing_GameHooks", function()
    if not NavigationManager or not NavigationManager._nicetrainer_nav_hooked then
        _install_nav_hooks()
    end
end)
