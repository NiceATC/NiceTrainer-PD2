-- PerfectFOV for NiceTrainer (Visuals Tab)
local MINIMUM_FOV = 55
local MAXIMUM_FOV = 160
local GAME_DEFAULT_FOV = 65

if NiceTrainer.Settings.fov_enabled == nil then
    NiceTrainer.Settings.fov_enabled = false
end

if NiceTrainer.Settings.fov_value == nil then
    NiceTrainer.Settings.fov_value = 90
end

local function ApplyFOV(fov)
    if not managers.user then return end
    
    local multiplier = fov / GAME_DEFAULT_FOV
    managers.user:set_setting("fov_multiplier", multiplier)
    
    if managers.player and alive(managers.player:player_unit()) then
        local movement = managers.player:player_unit():movement()
        if movement and movement:current_state() and movement:current_state().update_fov_external then
            movement:current_state():update_fov_external()
        end
    end
end

local function update_fov_state()
    if NiceTrainer.Settings.fov_enabled then
        ApplyFOV(NiceTrainer.Settings.fov_value or 90)
    else
        ApplyFOV(GAME_DEFAULT_FOV)
    end
end

-- Ensure FOV is applied when the game is ready
if not NiceTrainer._fov_update_hooked then
    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ApplyFOV_Load", function()
        update_fov_state()
    end)
    NiceTrainer._fov_update_hooked = true
end

-- Fallback check for when re-loading via dev keybinds mid-game
if Utils and Utils:IsInGameState() then
    update_fov_state()
end

NiceTrainer:RegisterAction("Visuals", {
    category        = "CAMERA",
    badge           = "client",
    type            = "toggle_slider",
    id              = "fov_enabled",
    text            = "Field of View (FOV)",
    default         = false,
    min             = MINIMUM_FOV,
    max             = MAXIMUM_FOV,
    slider_default  = 90,
    slider_id       = "fov_value",
    save            = true,
    tooltip         = "Toggle custom camera Field of View on/off and adjust the angle with the slider.",
    callback        = function(state, val)
        update_fov_state()
    end,
    slider_callback = function(val, state)
        if NiceTrainer.Settings.fov_enabled then
            ApplyFOV(val)
        end
    end
})
