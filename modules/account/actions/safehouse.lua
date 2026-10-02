-- ─── Continental Coins, Safehouse & Side Jobs Actions for NiceTrainer ─────────

-- ============================================================================
-- 1. Continental Coins Presets
-- ============================================================================
local COIN_PRESETS = {
    { label = "+50 Coins",                         val = 50 },
    { label = "+100 Coins",                        val = 100 },
    { label = "+500 Coins",                        val = 500 },
    { label = "+1,000 Coins",                      val = 1000 },
    { label = "+6,000 Coins (Full Safehouse Max)", val = 6000 },
    { label = "+10,000 Coins",                     val = 10000 },
}

local coin_preset_labels = {}
for _, item in ipairs(COIN_PRESETS) do table.insert(coin_preset_labels, item.label) end

NiceTrainer:RegisterAction("Account", {
    type            = "multichoice",
    category        = "Continental Coins & Safehouse",
    badge           = "client",
    no_bind         = true,
    id              = "add_coins_preset",
    text            = "Continental Coins (Presets)",
    tooltip         = "Select a preset quantity of Continental Coins to add.",
    options         = coin_preset_labels,
    default         = 2,
    action_btn_text = "Add Coins",
    callback        = function(idx, label)
        local item = COIN_PRESETS[idx]
        if item and managers.custom_safehouse and managers.custom_safehouse.add_coins then
            managers.custom_safehouse:add_coins(item.val)
            NiceTrainer:Toast("Added " .. item.label .. "!")
        end
    end
})

-- ============================================================================
-- 2. Custom Continental Coins Input
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Continental Coins & Safehouse",
    badge           = "client",
    no_bind         = true,
    id              = "custom_coins_input",
    text            = "Custom Continental Coins",
    tooltip         = "Enter an exact number of Continental Coins to grant.",
    min             = 1,
    max             = 1000000,
    default         = 500,
    action_btn_text = "Add",
    callback        = function(value)
        if managers.custom_safehouse and managers.custom_safehouse.add_coins then
            managers.custom_safehouse:add_coins(value)
            NiceTrainer:Toast("Added +" .. tostring(value) .. " Continental Coins!")
        end
    end
})

-- ============================================================================
-- 3. Max Out All Safehouse Rooms (Tier 3)
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Continental Coins & Safehouse",
    badge           = "client",
    no_bind         = true,
    id              = "max_safehouse_rooms",
    text            = "Max Out All Safehouse Rooms (Tier 3)",
    tooltip         = "Upgrades every character and facility room in the Custom Safehouse to the maximum Tier 3.",
    action_btn_text = "Upgrade All",
    callback        = function()
        local g_safehouse = Global.custom_safehouse_manager
        local m_safehouse = managers.custom_safehouse
        if not (g_safehouse and m_safehouse and g_safehouse.rooms) then
            NiceTrainer:Toast("Safehouse data not available.")
            return
        end

        local count = 0
        for room_id, data in pairs(g_safehouse.rooms) do
            local max_tier = data.tier_max or 3
            local current_tier = m_safehouse:get_room_current_tier(room_id) or 0
            while max_tier > current_tier do
                current_tier = current_tier + 1
                if m_safehouse._global and m_safehouse._global.rooms and m_safehouse._global.rooms[room_id] then
                    table.insert(m_safehouse._global.rooms[room_id].unlocked_tiers, current_tier)
                end
            end
            pcall(function() m_safehouse:set_room_tier(room_id, max_tier) end)
            count = count + 1
        end
        NiceTrainer:Toast(string.format("Upgraded %d Safehouse rooms to Tier 3 Max!", count))
    end
})

-- ============================================================================
-- 4. Unlock All Safehouse Trophies
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Continental Coins & Safehouse",
    badge           = "client",
    no_bind         = true,
    id              = "unlock_safehouse_trophies",
    text            = "Unlock All Safehouse Trophies",
    tooltip         = "Instantly fulfills all Safehouse trophy milestones and displays.",
    action_btn_text = "Unlock All",
    callback        = function()
        local m_safehouse = managers.custom_safehouse
        if not (m_safehouse and m_safehouse.trophies) then
            NiceTrainer:Toast("Safehouse trophies not loaded.")
            return
        end

        local trophies = m_safehouse:trophies() or {}
        local count = 0
        for _, trophy in pairs(trophies) do
            if trophy.objectives then
                for _, objective in pairs(trophy.objectives) do
                    objective.verify = false
                    pcall(function()
                        m_safehouse:on_achievement_progressed(objective.progress_id, objective.max_progress)
                    end)
                end
                count = count + 1
            end
        end
        NiceTrainer:Toast(string.format("Completed objectives for %d Safehouse Trophies!", count))
    end
})

-- ============================================================================
-- 5. Complete All Side Jobs, Daily & Event Challenges
-- ============================================================================
local function complete_all_side_jobs_now()
    local total = 0

    -- 1. Custom Safehouse Daily
    if managers.custom_safehouse and managers.custom_safehouse.get_daily_challenge then
        local daily = managers.custom_safehouse:get_daily_challenge()
        if daily and daily.id then
            pcall(function()
                managers.custom_safehouse:complete_daily(daily.id)
                if managers.custom_safehouse.reward_daily then
                    managers.custom_safehouse:reward_daily()
                end
                total = total + 1
            end)
        end
    end

    -- 2. Challenge Manager (Side Jobs)
    if managers.challenge and managers.challenge._global and managers.challenge._global.active_challenges then
        for _, challenge in pairs(managers.challenge._global.active_challenges) do
            challenge.completed = true
            challenge.rewarded = true
            total = total + 1
        end
    end

    -- 3. Gage Spec Ops / Tango Missions
    if managers.tango and managers.tango._global and managers.tango._global.challenges then
        for _, challenge in ipairs(managers.tango._global.challenges) do
            challenge.completed = true
            total = total + 1
        end
    end

    -- 4. Aldstone's Heritage Side Jobs
    local generic_mgr = managers.generic_side_jobs or managers.side_job_generic_dlc
    if generic_mgr and generic_mgr._global and generic_mgr._global.challenges then
        for _, challenge in ipairs(generic_mgr._global.challenges) do
            challenge.completed = true
            total = total + 1
        end
    end

    -- 5. Event Manager Jobs
    if managers.event_jobs and managers.event_jobs._global and managers.event_jobs._global.challenges then
        for _, challenge in ipairs(managers.event_jobs._global.challenges) do
            challenge.completed = true
            total = total + 1
        end
    end

    -- 6. Side Job Event Manager
    if managers.side_job_event and managers.side_job_event._global and managers.side_job_event._global.challenges then
        for _, challenge in ipairs(managers.side_job_event._global.challenges) do
            challenge.completed = true
            total = total + 1
        end
    end

    NiceTrainer:Toast(string.format("Completed & rewarded %d Side Jobs, Daily, and Event contracts!", total))
end

NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Continental Coins & Safehouse",
    badge           = "client",
    no_bind         = true,
    id              = "complete_all_sidejobs_btn",
    text            = "Complete All Side Jobs & Events",
    tooltip         = "Instantly completes and rewards all active Side Jobs, Safehouse Daily contracts, Gage Spec Ops assignments, Aldstone's Heritage jobs, and Event challenges.",
    action_btn_text = "Complete All",
    callback        = complete_all_side_jobs_now
})

-- ============================================================================
-- 6. Auto-Complete Side Jobs on Load Hook
-- ============================================================================
local function is_auto_sidejobs_enabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.auto_complete_side_jobs == true
end

local function safe_hook_load(class_name, state_key, save_ver_key)
    local cls = _G[class_name]
    if type(cls) == "table" and type(cls.load) == "function" and not cls._nt_sidejobs_hooked then
        cls._nt_sidejobs_hooked = true
        local orig = cls.load
        cls.load = function(self, cache, version, ...)
            local key = state_key or self.save_table_name or class_name
            local state = cache and cache[key]
            local target_ver = save_ver_key and cls[save_ver_key] or self.save_version
            if state and (not target_ver or state.version == target_ver) and is_auto_sidejobs_enabled() then
                for _, saved_challenge in ipairs(state.challenges or {}) do
                    saved_challenge.completed = true
                end
            end
            return orig(self, cache, version, ...)
        end
    end
end

if type(_G.ChallengeManager) == "table" and type(ChallengeManager.activate_challenge) == "function" and not ChallengeManager._nt_sidejobs_hooked then
    ChallengeManager._nt_sidejobs_hooked = true
    local orig_activate_challenge = ChallengeManager.activate_challenge
    function ChallengeManager:activate_challenge(id, key, category, ...)
        if is_auto_sidejobs_enabled() then
            if self:has_active_challenges(id, key) then
                local challenge = self:get_challenge(id, key)
                if challenge then
                    challenge.completed = true
                    challenge.rewarded = true
                    challenge.category = category
                    self._global.active_challenges[key or Idstring(id):key()] = challenge
                    return true
                end
            end
        end
        return orig_activate_challenge(self, id, key, category, ...)
    end
end

safe_hook_load("TangoManager", "Tango", "SAVE_DATA_VERSION")
safe_hook_load("SideJobGenericDLCManager")
safe_hook_load("SideJobEventManager")

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Continental Coins & Safehouse",
    badge    = "safe",
    no_bind  = true,
    id       = "auto_complete_side_jobs",
    text     = "Auto-Complete Side Jobs on Load",
    tooltip  = "Automatically marks newly loaded and activated Side Jobs, Gage Spec Ops, and Event challenges as completed upon opening the game or menu.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.auto_complete_side_jobs = state
        NiceTrainer:Save()
        if state then
            complete_all_side_jobs_now()
        end
    end
})

-- ============================================================================
-- 7. Disable Safehouse Raids
-- ============================================================================
local function is_raids_disabled()
    return NiceTrainer and NiceTrainer.Settings and NiceTrainer.Settings.disable_safehouse_raids == true
end

if _G.CustomSafehouseManager and not _G.CustomSafehouseManager._nt_raids_hooked then
    _G.CustomSafehouseManager._nt_raids_hooked = true
    local orig_is_being_raided = CustomSafehouseManager.is_being_raided
    function CustomSafehouseManager:is_being_raided(...)
        if is_raids_disabled() then
            return false
        end
        return orig_is_being_raided(self, ...)
    end
end

NiceTrainer:RegisterAction("Account", {
    type     = "toggle",
    category = "Continental Coins & Safehouse",
    badge    = "safe",
    no_bind  = true,
    id       = "disable_safehouse_raids",
    text     = "Disable Safehouse Raids",
    tooltip  = "Prevents the Custom Safehouse from ever triggering a police raid defense mission.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.disable_safehouse_raids = state
        NiceTrainer:Save()
    end
})

-- ============================================================================
-- 8. Reset Continental Coins
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Continental Coins & Safehouse",
    badge           = "risk",
    no_bind         = true,
    id              = "reset_continental_coins",
    text            = "Reset Continental Coins",
    tooltip         = "Resets your Continental Coins balance back to 0.",
    action_btn_text = "Reset",
    callback        = function()
        NiceTrainer:ShowConfirmDialog(
            "Confirm Reset Coins",
            "Are you sure you want to reset all Continental Coins to 0?",
            {
                {
                    text = "Yes, Reset Coins",
                    color = Color(0.9, 0.35, 0.35),
                    callback = function()
                        if Global.custom_safehouse_manager then
                            Global.custom_safehouse_manager.total = Application:digest_value(0, true)
                            Global.custom_safehouse_manager.total_collected = Application:digest_value(0, true)
                            NiceTrainer:Toast("Continental Coins reset to 0.")
                        end
                    end
                },
                {
                    text = "Cancel",
                    color = Color(0.6, 0.6, 0.6),
                    callback = function() end
                }
            }
        )
    end
})

-- ============================================================================
-- 9. Relock All Safehouse Trophies
-- ============================================================================
NiceTrainer:RegisterAction("Account", {
    type            = "button",
    category        = "Continental Coins & Safehouse",
    badge           = "risk",
    no_bind         = true,
    id              = "lock_all_safehouse_trophies",
    text            = "Relock All Safehouse Trophies",
    tooltip         = "Resets all Safehouse trophies back to uncompleted state.",
    action_btn_text = "Relock",
    callback        = function()
        NiceTrainer:ShowConfirmDialog(
            "Confirm Relock Trophies",
            "Are you sure you want to relock all Safehouse trophies?",
            {
                {
                    text = "Yes, Relock Trophies",
                    color = Color(0.9, 0.35, 0.35),
                    callback = function()
                        if managers.custom_safehouse and managers.custom_safehouse.flush_completed_trophies then
                            managers.custom_safehouse:flush_completed_trophies()
                        end
                        if Global.custom_safehouse_manager and Global.custom_safehouse_manager.trophies then
                            for _, trophy in pairs(Global.custom_safehouse_manager.trophies) do
                                trophy.completed = false
                            end
                        end
                        NiceTrainer:Toast("All Safehouse trophies relocked.")
                    end
                },
                {
                    text = "Cancel",
                    color = Color(0.6, 0.6, 0.6),
                    callback = function() end
                }
            }
        )
    end
})
