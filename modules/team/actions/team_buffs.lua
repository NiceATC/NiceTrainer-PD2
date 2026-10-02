-- ─── Team Buffs & Lobby Controls ─────────────────────────────────────────────
-- Lobby-wide modifiers: Godmode, No Fall Damage, Instant Interaction,
-- Item Stealing (I Want That), Mark Enemies, and Disable Security.

local team_godmode_active = false
local team_fall_protect_active = false
local orig_interaction_timers = nil
local hooks_installed = false

local function install_team_hooks()
    if hooks_installed then return end
    hooks_installed = true

    -- Hook unit health network handler to protect teammates from damage/fall
    if _G.UnitNetworkHandler and not UnitNetworkHandler._nt_team_health_orig then
        UnitNetworkHandler._nt_team_health_orig = UnitNetworkHandler.set_health
        function UnitNetworkHandler:set_health(unit, percent, max_mul, sender)
            local result = UnitNetworkHandler._nt_team_health_orig(self, unit, percent, max_mul, sender)
            local protect = team_godmode_active or team_fall_protect_active
            if protect and alive(unit) and percent and percent < 100 then
                pcall(function()
                    unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 })
                end)
            end
            return result
        end
    end

    -- Sentry gun orphan safeguard
    if _G.SentryGunBase and not SentryGunBase._nt_team_sentry_orig then
        SentryGunBase._nt_team_sentry_orig = SentryGunBase.pre_destroy
        function SentryGunBase:pre_destroy(...)
            if self._sentry_uid == nil then self._sentry_uid = "nt_orphan_sentry" end
            return SentryGunBase._nt_team_sentry_orig(self, ...)
        end
    end

    -- Crash guard for bag instant pickups
    if _G.PlayerManager and not PlayerManager._nt_carry_safety_orig then
        PlayerManager._nt_carry_safety_orig = PlayerManager.set_carry
        function PlayerManager:set_carry(carry_id, ...)
            if not (carry_id and tweak_data.carry and tweak_data.carry[carry_id]) then
                return
            end
            return PlayerManager._nt_carry_safety_orig(self, carry_id, ...)
        end
    end
end

local function apply_team_godmode(state)
    if not Network:is_server() then
        return
    end
    install_team_hooks()
    team_godmode_active = state
    local session = managers.network and managers.network:session()
    if not session then return end

    for _, peer in pairs(session:peers()) do
        local unit = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        if alive(unit) then
            pcall(function() unit:character_damage():set_mission_damage_blockers("invulnerable", state) end)
            if state then
                pcall(function() unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 }) end)
                pcall(function() unit:character_damage():replenish() end)
            end
        end
    end
end

local function apply_team_fall_protect(state)
    if not Network:is_server() then
        return
    end
    install_team_hooks()
    team_fall_protect_active = state
    local session = managers.network and managers.network:session()
    if not session then return end

    for _, peer in pairs(session:peers()) do
        local unit = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        if alive(unit) then
            pcall(function() unit:character_damage():set_mission_damage_blockers("damage_fall_disabled", state) end)
            if state then
                pcall(function() unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 }) end)
            end
        end
    end
end

local function set_team_instant_interact(state)
    install_team_hooks()
    pcall(function()
        local interactions = tweak_data and tweak_data.interaction
        if not interactions then return end
        if state then
            orig_interaction_timers = orig_interaction_timers or {}
            for id, data in pairs(interactions) do
                if type(data) == "table" and data.timer then
                    if orig_interaction_timers[id] == nil then
                        orig_interaction_timers[id] = data.timer
                    end
                    data.timer = 0
                end
            end
        elseif orig_interaction_timers then
            for id, timer in pairs(orig_interaction_timers) do
                if interactions[id] then
                    interactions[id].timer = timer
                end
            end
        end
    end)

end

-- Item Stealing: copy teammate loadouts into your inventory
local function add_blackmarket_item(category, id)
    if not id or id == "" then return end
    if not (tweak_data.blackmarket and tweak_data.blackmarket[category] and tweak_data.blackmarket[category][id]) then return end
    local gv = managers.blackmarket:get_global_value(category, id) or "normal"
    pcall(function() managers.blackmarket:add_to_inventory(gv, category, id, false) end)
end

local function steal_outfit(outfit, added)
    if not outfit then return end
    -- Mask and mask custom components
    if outfit.mask then
        add_blackmarket_item("masks", outfit.mask.mask_id)
        added.n = added.n + 1
        local bp = outfit.mask.blueprint
        if bp then
            if bp.material then add_blackmarket_item("materials", bp.material.id) end
            if bp.pattern  then add_blackmarket_item("textures",  bp.pattern.id)  end
            if bp.color    then add_blackmarket_item("colors",    bp.color.id)    end
        end
    end
    -- Weapon attachments on primary & secondary
    for _, slot in ipairs({ outfit.primary, outfit.secondary }) do
        if slot and slot.blueprint then
            local default_mods = {}
            pcall(function()
                for _, p in pairs(managers.weapon_factory:get_default_blueprint_by_factory_id(slot.factory_id) or {}) do
                    default_mods[p] = true
                end
            end)
            for _, mod in pairs(slot.blueprint) do
                if not default_mods[mod] then
                    add_blackmarket_item("weapon_mods", mod)
                    added.n = added.n + 1
                end
            end
        end
    end
end

local function steal_all_teammate_loadouts()
    local session = managers.network and managers.network:session()
    if not session then
        NiceTrainer:Toast("Not in an active session.")
        return
    end
    local added = { n = 0 }
    for _, peer in pairs(session:peers()) do
        pcall(function() steal_outfit(peer:blackmarket_outfit(), added) end)
    end
    pcall(function()
        if managers.menu_component and managers.menu_component.refresh_player_profile_gui then
            managers.menu_component:refresh_player_profile_gui()
        end
    end)
    NiceTrainer:Toast("Copied ~" .. added.n .. " item(s) from teammates to your inventory!")
end

local function disable_lobby_security()
    local count = 0
    pcall(function()
        if SecurityCamera and SecurityCamera.cameras then
            for _, unit in pairs(SecurityCamera.cameras) do
                if alive(unit) and unit:base() and unit:base()._last_detect_t ~= nil and unit:base().set_update_enabled then
                    pcall(function() unit:base():set_update_enabled(false) end)
                    count = count + 1
                end
            end
        end

        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) and unit:base() and (unit:base()._tweak_table == "swat_van_turret_module" or unit:base().is_sentry_gun) then
                if unit:brain() and unit:brain().set_active then
                    pcall(function() unit:brain():set_active(false) end)
                    count = count + 1
                end
            end
        end
    end)
    NiceTrainer:Toast("Disabled " .. count .. " camera(s) and turret(s) for the lobby!")
end

local function mark_all_enemies_for_lobby()
    local count = 0
    local enemies = managers.enemy and managers.enemy:all_enemies() or {}
    for _, data in pairs(enemies) do
        if alive(data.unit) and data.unit:contour() then
            pcall(function() data.unit:contour():add("mark_enemy", true, 1000) end)
            count = count + 1
        end
    end
    NiceTrainer:Toast("Marked " .. count .. " enemies for the entire team!")
end

-- Re-apply team hooks on heist transition
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_TeamBuffs_Reapply", function()
    if NiceTrainer.Settings.team_god_mode then
        apply_team_godmode(true)
    end
    if NiceTrainer.Settings.team_fall_protection then
        apply_team_fall_protect(true)
    end
    if NiceTrainer.Settings.team_instant_interact then
        set_team_instant_interact(true)
    end
end)

-- ============================================================================
-- Registration: Lobby & Team Buffs
-- ============================================================================

NiceTrainer:RegisterAction("Team", {
    type     = "toggle",
    category = "Team Buffs & Lobby",
    badge    = "host",
    id       = "team_god_mode",
    text     = "Team God Mode",
    tooltip  = "Makes all teammates completely invulnerable to all damage. Host only.",
    default  = false,
    callback = function(state)
        apply_team_godmode(state)
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "toggle",
    category = "Team Buffs & Lobby",
    badge    = "host",
    id       = "team_fall_protection",
    text     = "Team Fall Damage Protection",
    tooltip  = "Protects all teammates from taking fall damage. Host only.",
    default  = false,
    callback = function(state)
        apply_team_fall_protect(state)
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "toggle",
    category = "Team Buffs & Lobby",
    badge    = "client",
    id       = "team_instant_interact",
    text     = "Team Instant Interaction",
    tooltip  = "Makes every interaction in the lobby (drills, ziplines, revives, bags) instant for the whole team.",
    default  = false,
    callback = function(state)
        set_team_instant_interact(state)
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Buffs & Lobby",
    badge    = "client",
    text     = "Mark All Enemies for Team",
    tooltip  = "Outlines and marks every active enemy on the map for all players in the lobby.",
    callback = function()
        mark_all_enemies_for_lobby()
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Buffs & Lobby",
    badge    = "host",
    text     = "Disable Cameras & Turrets",
    tooltip  = "Instantly deactivates all security cameras and SWAT van turrets across the entire heist.",
    callback = function()
        disable_lobby_security()
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Buffs & Lobby",
    badge    = "client",
    text     = "Steal Teammates Loadouts (I Want That)",
    tooltip  = "Copies masks, colors, materials, patterns, and equipped weapon mods from all teammates directly into your Blackmarket inventory.",
    callback = function()
        steal_all_teammate_loadouts()
    end
})
