-- Time Manipulation & Bullet-Time Engine for NiceTrainer (Player Tab)
-- Provides Bullet-Time Matrix, Selective Enemy-Only Slomo, and World Fast-Forward.

NiceTrainer.BulletTimeActive = false
NiceTrainer.BulletTimeSpeed = 0.25
NiceTrainer.EnemySlomoActive = false
NiceTrainer.EnemySlomoSpeed = 0.2
NiceTrainer.WorldFastForwardActive = false
NiceTrainer.WorldFastForwardSpeed = 2.0

-- Helper to safely re-apply game timer multipliers
local function _update_game_time_speed()
    local mul = 1.0
    local rtpc = 1

    if NiceTrainer.BulletTimeActive then
        mul = NiceTrainer.BulletTimeSpeed or 0.25
        rtpc = 0
    elseif NiceTrainer.WorldFastForwardActive then
        mul = NiceTrainer.WorldFastForwardSpeed or 2.0
        rtpc = 2
    end

    pcall(function()
        if TimerManager then
            if TimerManager:game() then
                TimerManager:game():set_multiplier(mul)
            end
            if TimerManager:game_animation() then
                TimerManager:game_animation():set_multiplier(mul)
            end
        end
        if SoundDevice and SoundDevice.set_rtpc then
            SoundDevice:set_rtpc("game_speed", rtpc)
        end
    end)
end

-- ============================================================
-- Safe Enemy Slomo Hook (CopMovement dt scaling)
-- ============================================================

local function _install_timespeed_hooks()
    if _G.CopMovement and not CopMovement._nicetrainer_slomo_hooked then
        CopMovement._nicetrainer_slomo_hooked = true
        local orig_update = CopMovement.update
        function CopMovement:update(unit, t, dt, ...)
            if NiceTrainer.EnemySlomoActive then
                local slomo_mul = NiceTrainer.EnemySlomoSpeed or 0.2
                dt = dt * slomo_mul
            end
            return orig_update(self, unit, t, dt, ...)
        end
    end
end

_install_timespeed_hooks()
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Timespeed_SessionHooks", _install_timespeed_hooks)
Hooks:Add("GameSetupUpdate", "NiceTrainer_Timespeed_GameHooks", function()
    if not CopMovement or not CopMovement._nicetrainer_slomo_hooked then
        _install_timespeed_hooks()
    end
end)

-- ============================================================
-- Action Registrations
-- ============================================================

-- Bullet-Time Matrix On-Demand (Toggle-Slider)
NiceTrainer:RegisterAction("Player", {
    type = "toggle_slider",
    badge = "Client",
    category = "Time Manipulation",
    id = "bullet_time_matrix",
    text = "Bullet-Time Matrix (Slow Motion)",
    tooltip = "Slows down game time (0.05x to 0.8x) with audio muffle (assign a hotkey for cinematic firefights)",
    default = false,
    save = false,
    min = 0.05,
    max = 0.8,
    slider_default = 0.25,
    slider_id = "bullet_time_speed",
    callback = function(state, val)
        NiceTrainer.BulletTimeActive = state
        NiceTrainer.BulletTimeSpeed = tonumber(val) or 0.25
        _update_game_time_speed()
        if state then
        end
    end,
    slider_callback = function(val, state)
        NiceTrainer.BulletTimeSpeed = tonumber(val) or 0.25
        if state or NiceTrainer.BulletTimeActive then
            _update_game_time_speed()
        end
    end
})

-- Selective Enemy-Only Slomo (Toggle-Slider)
NiceTrainer:RegisterAction("Player", {
    type = "toggle_slider",
    badge = "Host",
    category = "Time Manipulation",
    id = "enemy_slomo_toggle",
    text = "Selective Enemy Slow Motion",
    tooltip = "Enemies move and react in extreme slow motion (10%-50%), while the player moves and shoots at 100% full speed",
    default = false,
    save = false,
    min = 0.05,
    max = 0.8,
    slider_default = 0.2,
    slider_id = "enemy_slomo_speed",
    callback = function(state, val)
        NiceTrainer.EnemySlomoActive = state
        NiceTrainer.EnemySlomoSpeed = tonumber(val) or 0.2
        if state then
        end
    end,
    slider_callback = function(val, state)
        NiceTrainer.EnemySlomoSpeed = tonumber(val) or 0.2
        if state or NiceTrainer.EnemySlomoActive then
        end
    end
})

-- World Fast-Forward (Toggle-Slider)
NiceTrainer:RegisterAction("Player", {
    type = "toggle_slider",
    badge = "Host",
    category = "Time Manipulation",
    id = "world_fast_forward",
    text = "World Fast-Forward",
    tooltip = "Accelerates game speed (1.5x to 5x) to breeze through long drills, escapes, and waiting timers",
    default = false,
    save = false,
    min = 1.5,
    max = 5.0,
    slider_default = 2.0,
    slider_id = "world_fast_forward_speed",
    callback = function(state, val)
        NiceTrainer.WorldFastForwardActive = state
        NiceTrainer.WorldFastForwardSpeed = tonumber(val) or 2.0
        _update_game_time_speed()
    end,
    slider_callback = function(val, state)
        NiceTrainer.WorldFastForwardSpeed = tonumber(val) or 2.0
        if state or NiceTrainer.WorldFastForwardActive then
            _update_game_time_speed()
        end
    end
})
