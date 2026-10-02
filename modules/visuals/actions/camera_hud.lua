-- Camera & HUD effects for NiceTrainer (Visuals Tab)
-- Covers: flashbang, headbob, camera shake, weapon sway, tinnitus, crosshair, HUD visibility

-- ─── Shared originals table ───────────────────────────────────────────────────
-- We use a single originals table so restoring one feature doesn't touch another.
local _originals = {}

local function hijack(class_name, method_name, replacement)
    local cls = _G[class_name]
    if not cls or type(cls[method_name]) ~= "function" then return false end
    local key = class_name .. "." .. method_name
    if not _originals[key] then
        _originals[key] = cls[method_name]
    end
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

-- ─── 1. No Flashbang Blind ────────────────────────────────────────────────────

local function applyNoFlashbang(enabled)
    if enabled then
        hijack("CoreEnvironmentControllerManager", "set_flashbang", function() end)
        hijack("CoreEnvironmentControllerManager", "set_concussion_grenade", function() end)
        hijack("CoreEnvironmentControllerManager", "set_flashbang_value", function(self)
            self._current_flashbang = 0
            self._current_flashbang_flash = 0
        end)
        hijack("CoreEnvironmentControllerManager", "set_concussion_value", function(self)
            self._current_concussion = 0
        end)
    else
        restore("CoreEnvironmentControllerManager", "set_flashbang")
        restore("CoreEnvironmentControllerManager", "set_concussion_grenade")
        restore("CoreEnvironmentControllerManager", "set_flashbang_value")
        restore("CoreEnvironmentControllerManager", "set_concussion_value")
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "CAMERA",
    badge    = "client",
    type     = "toggle",
    id       = "no_flashbang",
    text     = "No Flashbang & Concussion Blind",
    tooltip  = "Prevents flashbangs, concussion grenades and flash effects from blinding your screen.",
    default  = false,
    callback = applyNoFlashbang,
})

-- ─── 2. No Headbob ───────────────────────────────────────────────────────────

local function applyNoHeadbob(enabled)
    if enabled then
        hijack("PlayerStandard", "_get_walk_headbob", function() return 0 end)
    else
        restore("PlayerStandard", "_get_walk_headbob")
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "CAMERA",
    badge    = "client",
    type     = "toggle",
    id       = "no_headbob",
    text     = "No Headbob",
    tooltip  = "Removes the up-and-down camera bobbing while walking.",
    default  = false,
    callback = applyNoHeadbob,
})

-- ─── 3. No Camera Shake ──────────────────────────────────────────────────────
-- PlayerMovementController:add_camera_shake is the primary shake entry point.
-- We also intercept set_shaking on EnvironmentController for explosion/hit shakes.

local function applyNoCameraShake(enabled)
    if enabled then
        hijack("PlayerMovementController", "add_camera_shake", function() end)
        hijack("CoreEnvironmentControllerManager", "set_shaking",  function() end)
    else
        restore("PlayerMovementController", "add_camera_shake")
        restore("CoreEnvironmentControllerManager", "set_shaking")
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "CAMERA",
    badge    = "client",
    type     = "toggle",
    id       = "no_camera_shake",
    text     = "No Camera Shake",
    tooltip  = "Stops explosions and hits from shaking the camera.",
    default  = false,
    callback = applyNoCameraShake,
})

-- ─── 4. No Weapon Sway ───────────────────────────────────────────────────────
-- _get_sway_rotation returns the sway Rotation applied to the weapon each frame.
-- Returning a zero-rotation eliminates all idle/ADS sway.

local function applyNoWeaponSway(enabled)
    if enabled then
        hijack("PlayerStandard", "_get_sway_rotation", function() return Rotation() end)
    else
        restore("PlayerStandard", "_get_sway_rotation")
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "CAMERA",
    badge    = "client",
    type     = "toggle",
    id       = "no_weapon_sway",
    text     = "No Weapon Sway",
    tooltip  = "Removes idle and ADS weapon sway from the first-person camera.",
    default  = false,
    callback = applyNoWeaponSway,
})

-- ─── 5. No Tinnitus ──────────────────────────────────────────────────────────
-- SoundManager:set_rtpc("tinnitus", ...) is called after explosions.
-- We intercept it and block only the tinnitus RTPC, passing everything else through.

local function applyNoTinnitus(enabled)
    if enabled then
        hijack("SoundManager", "set_rtpc", function(self, param, value, ...)
            if param == "tinnitus" then return end
            if _originals["SoundManager.set_rtpc"] then
                return _originals["SoundManager.set_rtpc"](self, param, value, ...)
            end
        end)
    else
        restore("SoundManager", "set_rtpc")
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "CAMERA",
    badge    = "client",
    type     = "toggle",
    id       = "no_tinnitus",
    text     = "No Tinnitus",
    tooltip  = "Suppresses the ear-ringing sound effect after explosions.",
    default  = false,
    callback = applyNoTinnitus,
})

-- ─── 6. Custom Crosshair Dot ─────────────────────────────────────────────────
-- Draws a small centered dot using the overlay GUI.
-- Color comes from the colorpicker setting.

local _crosshair_ws  = nil
local _crosshair_dot = nil

local function hex_to_color(hex)
    hex = hex:gsub("#", "")
    return Color(
        tonumber("0x" .. hex:sub(1,2)) / 255,
        tonumber("0x" .. hex:sub(3,4)) / 255,
        tonumber("0x" .. hex:sub(5,6)) / 255
    )
end

local function applyUpdateCrosshairColor()
    if not _crosshair_dot or not alive(_crosshair_dot) then return end
    local hex = NiceTrainer.Settings.crosshair_color or "#FFFFFF"
    pcall(function() _crosshair_dot:set_color(hex_to_color(hex)) end)
end

local function applyShowCrosshair(enabled)
    if enabled then
        if not _crosshair_ws then
            pcall(function()
                _crosshair_ws  = Overlay:newgui():create_screen_workspace()
                local panel    = _crosshair_ws:panel()
                local size     = NiceTrainer.Settings.crosshair_size or 4
                local hex      = NiceTrainer.Settings.crosshair_color or "#FFFFFF"
                _crosshair_dot = panel:rect({
                    name  = "nt_crosshair",
                    w     = size, h = size,
                    color = hex_to_color(hex),
                    layer = 100,
                })
                _crosshair_dot:set_center(panel:w() / 2, panel:h() / 2)
            end)
        end
    else
        if _crosshair_ws then
            pcall(function() Overlay:newgui():destroy_workspace(_crosshair_ws) end)
            _crosshair_ws  = nil
            _crosshair_dot = nil
        end
    end
end

NiceTrainer:RegisterAction("Visuals", {
    category = "HUD",
    badge    = "client",
    type     = "toggle",
    id       = "crosshair_enabled",
    text     = "Custom Crosshair",
    tooltip  = "Shows a small dot in the center of your screen as a crosshair.",
    default  = false,
    callback = applyShowCrosshair,
})

NiceTrainer:RegisterAction("Visuals", {
    category          = "HUD",
    type              = "colorpicker",
    id                = "crosshair_color",
    text              = "Crosshair Color",
    tooltip           = "Pick the color for your custom crosshair dot.",
    default           = "#FFFFFF",
    callback          = function(c, hex)
        NiceTrainer.Settings.crosshair_color = hex
        NiceTrainer:Save()
        applyUpdateCrosshairColor()
    end,
})

NiceTrainer:RegisterAction("Visuals", {
    category = "HUD",
    type     = "slider",
    id       = "crosshair_size",
    text     = "Crosshair Size",
    tooltip  = "Adjust the size (px) of the crosshair dot.",
    min      = 2,
    max      = 20,
    default  = 4,
    callback = function(val)
        NiceTrainer.Settings.crosshair_size = val
        NiceTrainer:Save()

        -- Rebuild dot with new size if active
        if NiceTrainer.Settings.crosshair_enabled then
            applyShowCrosshair(false)
            applyShowCrosshair(true)
        end
    end,
})

-- ─── 7. Hide HUD ─────────────────────────────────────────────────────────────
-- Toggles the visibility of the entire HUD workspace.
-- Uses managers.hud's internal panel reference if available, otherwise
-- iterates Overlay workspaces to find and hide any "hud_" workspace.

local function applyHideHud(enabled)
    pcall(function()
        local hud = managers.hud
        if not hud then return end
        -- HUDManager keeps its main workspace in _hud_ws (vanilla) or _workspace
        local ws = hud._hud_ws or hud._workspace
        if ws then
            ws:panel():set_visible(not enabled)
        end
    end)
end

NiceTrainer:RegisterAction("Visuals", {
    category = "HUD",
    badge    = "client",
    type     = "toggle",
    id       = "hide_hud",
    text     = "Hide HUD",
    tooltip  = "Hides all HUD elements for screenshots or a clean view.",
    default  = false,
    callback = applyHideHud,
})

-- ─── Re-apply on game start ──────────────────────────────────────────────────

if not NiceTrainer._camera_hud_hook_added then
    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_CameraHUD_Load", function()
        if NiceTrainer.Settings.no_flashbang    then applyNoFlashbang(true)    end
        if NiceTrainer.Settings.no_headbob      then applyNoHeadbob(true)      end
        if NiceTrainer.Settings.no_camera_shake then applyNoCameraShake(true)  end
        if NiceTrainer.Settings.no_weapon_sway  then applyNoWeaponSway(true)   end
        if NiceTrainer.Settings.no_tinnitus     then applyNoTinnitus(true)     end
        if NiceTrainer.Settings.crosshair_enabled then applyShowCrosshair(true) end
    end)
    NiceTrainer._camera_hud_hook_added = true
end
