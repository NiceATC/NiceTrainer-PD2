-- ============================================================
-- Lock Smasher (Melee Lock Breaker)
-- Enables melee attacks to break/open locks, security doors,
-- deposit boxes, cages, and ATMs just like an OVE9000 saw.
-- ============================================================

local _originals = {}

local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then _originals[key] = cls[method_name] end
    cls[method_name] = replacement
    return true
end

local function restore(class_name, method_name)
    local cls = _G[class_name]
    if not cls then return end
    local key = class_name .. "." .. method_name
    if _originals[key] then
        cls[method_name] = _originals[key]
        _originals[key] = nil
    end
end

local POWER_TOOLS_ENTRIES = {
    ["cs"]       = true, -- Lumber-Lite L2 Chainsaw
    ["cutters"]  = true, -- Bolt Cutters
    ["nin"]      = true, -- The Pounder Nailgun
    ["dingdong"] = true  -- Ding Dong Breaching Tool
}

local function is_melee_allowed_for_locks(melee_entry)
    local mode = NiceTrainer.Settings.lock_smasher_mode or 1
    if mode == 1 then
        return POWER_TOOLS_ENTRIES[melee_entry] == true
    elseif mode == 2 then
        return melee_entry == "cs"
    end
    -- Mode 3: All Melee Weapons
    return true
end

local function check_and_break_lock(player_standard, t)
    pcall(function()
        if not managers.blackmarket then return end
        local melee_entry = managers.blackmarket:equipped_melee_weapon() or "weapon"
        if not is_melee_allowed_for_locks(melee_entry) then return end

        local range = 175
        if tweak_data and tweak_data.blackmarket and tweak_data.blackmarket.melee_weapons and tweak_data.blackmarket.melee_weapons[melee_entry] then
            local stats = tweak_data.blackmarket.melee_weapons[melee_entry].stats
            if stats and stats.range then
                range = stats.range
            end
        end

        local unit = player_standard._unit
        if not alive(unit) or not unit:movement() or not unit:camera() then return end

        local from = unit:movement():m_head_pos()
        local to = from + unit:camera():forward() * range

        local slot_mask = InstantBulletBase and InstantBulletBase:bullet_slotmask() or (managers.slot and managers.slot:get_mask("bullet_impact_targets"))
        local raytrace = unit:raycast(
            "ray", from, to,
            "slot_mask", slot_mask,
            "ignore_unit", { unit },
            "ray_type", "body bullet lock"
        )

        if raytrace and alive(raytrace.unit) and alive(raytrace.body) then
            local hit_unit = raytrace.unit
            local body = raytrace.body
            if hit_unit:damage() and body:extension() and body:extension().damage and body:extension().damage.damage_lock then
                local damage = 200
                local normal = raytrace.normal or math.UP
                local pos = raytrace.position or raytrace.hit_position or from
                local dir = raytrace.direction or (to - from):normalized()

                body:extension().damage:damage_lock(unit, normal, pos, dir, damage)

                if hit_unit:id() ~= -1 and managers.network and managers.network:session() then
                    managers.network:session():send_to_peers_synched("sync_body_damage_lock", body, damage)
                end

                local show_sparks = NiceTrainer.Settings.lock_smasher_sparks
                if show_sparks == nil then show_sparks = true end
                if show_sparks and World and World:effect_manager() then
                    pcall(function()
                        local effect = World:effect_manager():spawn({
                            effect = Idstring("effects/payday2/particles/weapons/saw/sawing"),
                            position = raytrace.hit_position or pos,
                            normal = math.UP
                        })
                        if effect and _G.DelayedCalls then
                            DelayedCalls:Add("NiceTrainer_LockSmasher_Sparks_" .. tostring(effect), 0.1, function()
                                pcall(function()
                                    if World and World:effect_manager() then
                                        World:effect_manager():fade_kill(effect)
                                    end
                                end)
                            end)
                        end
                    end)
                end
            end
        end
    end)
end

local function apply_lock_smasher(state)
    if not _G.PlayerStandard then return end
    if state then
        hijack("PlayerStandard", "_do_action_melee", function(self, t, ...)
            check_and_break_lock(self, t)
            return _originals["PlayerStandard._do_action_melee"](self, t, ...)
        end)
    else
        restore("PlayerStandard", "_do_action_melee")
    end
end

NiceTrainer:RegisterAction("Player", {
    type            = "toggle_multichoice",
    category        = "Interactions",
    badge           = "client",
    id              = "lock_smasher",
    text            = "Lock Smasher",
    default         = false,
    options         = { "Power Tools Only", "Chainsaw Only", "All Melee Weapons" },
    choice_default  = 1,
    choice_id       = "lock_smasher_mode",
    tooltip         = "Allows melee attacks to break open locks, doors, ATMs, and deposit boxes like a saw.",
    callback        = apply_lock_smasher,
    choice_callback = function(idx, val)
        NiceTrainer.Settings.lock_smasher_mode = idx
        NiceTrainer:Save()
    end
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyLockSmasher", function()
    if NiceTrainer.Settings.lock_smasher then apply_lock_smasher(true) end
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_LockSmasherUpdate", function()
    if NiceTrainer.Settings.lock_smasher then apply_lock_smasher(true) end
end)
