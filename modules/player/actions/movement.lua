-- Better Movement for NiceTrainer (Player Tab)
-- Full modern parkour, sliding, crouch sprinting, agility and movement enhancements

NiceTrainer._orig_player_manager = NiceTrainer._orig_player_manager or {}
NiceTrainer._orig_player_standard = NiceTrainer._orig_player_standard or {}
NiceTrainer._tweak_data_carry_types_backup = NiceTrainer._tweak_data_carry_types_backup or nil

-- ─── Low-level Hook Implementations ──────────────────────────────────────────

local function apply_run_speed(state, mult)
    if not _G.PlayerManager then return end
    if state then
        if not NiceTrainer._orig_player_manager.movement_speed_multiplier then
            NiceTrainer._orig_player_manager.movement_speed_multiplier = PlayerManager.movement_speed_multiplier
        end
        local speed_mult = tonumber(mult) or 2.0
        PlayerManager.movement_speed_multiplier = function(self, ...)
            local orig = NiceTrainer._orig_player_manager.movement_speed_multiplier
            return (orig and orig(self, ...) or 1) * speed_mult
        end
    else
        if NiceTrainer._orig_player_manager.movement_speed_multiplier then
            PlayerManager.movement_speed_multiplier = NiceTrainer._orig_player_manager.movement_speed_multiplier
            NiceTrainer._orig_player_manager.movement_speed_multiplier = nil
        end
    end
end

local function apply_high_jump(state)
    if not _G.PlayerStandard then return end
    if state then
        if not NiceTrainer._orig_player_standard.start_action_jump then
            NiceTrainer._orig_player_standard.start_action_jump = PlayerStandard._start_action_jump
            PlayerStandard._start_action_jump = function(self, t, action_start_data, ...)
                if self._running and type(action_start_data) == "table" and action_start_data.jump_vel_z then
                    action_start_data.jump_vel_z = action_start_data.jump_vel_z * 2.5
                end
                return NiceTrainer._orig_player_standard.start_action_jump(self, t, action_start_data, ...)
            end
        end
    else
        if NiceTrainer._orig_player_standard.start_action_jump then
            PlayerStandard._start_action_jump = NiceTrainer._orig_player_standard.start_action_jump
            NiceTrainer._orig_player_standard.start_action_jump = nil
        end
    end
end

local function apply_run_in_all_directions(state)
    if not _G.PlayerStandard then return end
    if state then
        if not NiceTrainer._orig_player_standard.can_run_directional then
            NiceTrainer._orig_player_standard.can_run_directional = PlayerStandard._can_run_directional
            PlayerStandard._can_run_directional = function() return true end
        end
    else
        if NiceTrainer._orig_player_standard.can_run_directional then
            PlayerStandard._can_run_directional = NiceTrainer._orig_player_standard.can_run_directional
            NiceTrainer._orig_player_standard.can_run_directional = nil
        end
    end
end

local function apply_no_bag_penalty(state)
    if not tweak_data or not tweak_data.carry or not tweak_data.carry.types then return end
    
    if state then
        if not NiceTrainer._tweak_data_carry_types_backup then
            NiceTrainer._tweak_data_carry_types_backup = deep_clone(tweak_data.carry.types)
        end
        for carry_type, data in pairs(tweak_data.carry.types) do
            if type(data) == "table" then
                tweak_data.carry.types[carry_type].can_run = true
            end
        end
    else
        if NiceTrainer._tweak_data_carry_types_backup then
            for carry_type, data in pairs(NiceTrainer._tweak_data_carry_types_backup) do
                if tweak_data.carry.types[carry_type] and type(data) == "table" then
                    tweak_data.carry.types[carry_type].can_run = data.can_run
                end
            end
        end
    end
end

-- ─── Load Modern Movement Engine ─────────────────────────────────────────────

local path = (NiceTrainer and NiceTrainer.ModPath) or ModPath or "mods/NiceTrainer/"
pcall(dofile, path .. "modules/player/actions/modernmovement/modernmovementcore.lua")

local DEFAULT_MOVEMENT_SETTINGS = {
    better_movement       = true,
    -- Mantling
    vaulting              = true,
    airvaulting           = false,
    mantlesound           = true,
    vaultdebug            = false,
    -- Sliding
    slidestealth          = 2,
    slideloud             = 3,
    slidewpnangle         = 15,
    slidescreeneffectalpha = 0,
    -- Agility
    crouchsprinting       = false,
    crouchjump            = true,
    nullmovement          = false,
    -- Enhancements
    enable_run_speed      = false,
    run_speed_multiplier  = 2.0,
    high_jump             = false,
    run_in_all_directions = false,
    no_bag_penalty        = false,
}

local function EnsureMovementDefaults()
    NiceTrainer.Settings = NiceTrainer.Settings or {}
    for k, def in pairs(DEFAULT_MOVEMENT_SETTINGS) do
        if NiceTrainer.Settings[k] == nil then
            NiceTrainer.Settings[k] = def
        end
    end
end

EnsureMovementDefaults()

if _G.ModernMovement then
    ModernMovement:Load()
    ModernMovement:_apply_defaults()
    for k, def in pairs(DEFAULT_MOVEMENT_SETTINGS) do
        if ModernMovement.settings[k] ~= nil then
            if NiceTrainer.Settings[k] == nil then
                NiceTrainer.Settings[k] = ModernMovement.settings[k]
            else
                ModernMovement.settings[k] = NiceTrainer.Settings[k]
            end
        end
    end
end

-- ─── Master Sync & Hook Applicator ───────────────────────────────────────────

local function reapply_movement_hooks()
    EnsureMovementDefaults()
    local master_enabled = (NiceTrainer.Settings.better_movement ~= false)

    if not master_enabled then
        apply_run_speed(false, 1)
        apply_high_jump(false)
        apply_run_in_all_directions(false)
        apply_no_bag_penalty(false)

        if ModernMovement then
            ModernMovement.settings.vaulting = false
            ModernMovement.settings.airvaulting = false
            ModernMovement.settings.slidestealth = 1
            ModernMovement.settings.slideloud = 1
            ModernMovement.settings.crouchsprinting = false
            ModernMovement.settings.crouchjump = false
            ModernMovement.settings.nullmovement = false
        end
        if AdvMov then
            AdvMov.settings.vaulting = false
            AdvMov.settings.airvaulting = false
            AdvMov.settings.slidestealth = 1
            AdvMov.settings.slideloud = 1
            AdvMov.settings.crouchsprinting = false
            AdvMov.settings.crouchjump = false
            AdvMov.settings.nullmovement = false
        end
        return
    end

    -- Run Speed Multiplier
    if NiceTrainer.Settings.enable_run_speed then
        local mult = tonumber(NiceTrainer.Settings.run_speed_multiplier) or 2.0
        apply_run_speed(true, mult)
    else
        apply_run_speed(false, 1)
    end

    -- Trainer movement enhancements
    apply_high_jump(NiceTrainer.Settings.high_jump == true)
    apply_run_in_all_directions(NiceTrainer.Settings.run_in_all_directions == true)
    apply_no_bag_penalty(NiceTrainer.Settings.no_bag_penalty == true)

    -- Modern Movement settings sync
    if ModernMovement then
        ModernMovement.settings.vaulting = (NiceTrainer.Settings.vaulting ~= false)
        ModernMovement.settings.airvaulting = (NiceTrainer.Settings.airvaulting == true)
        ModernMovement.settings.mantlesound = (NiceTrainer.Settings.mantlesound ~= false)
        ModernMovement.settings.crouchsprinting = (NiceTrainer.Settings.crouchsprinting == true)
        ModernMovement.settings.crouchjump = (NiceTrainer.Settings.crouchjump ~= false)
        ModernMovement.settings.nullmovement = (NiceTrainer.Settings.nullmovement == true)
        ModernMovement.settings.slidestealth = tonumber(NiceTrainer.Settings.slidestealth) or 2
        ModernMovement.settings.slideloud = tonumber(NiceTrainer.Settings.slideloud) or 3
        ModernMovement.settings.slidewpnangle = tonumber(NiceTrainer.Settings.slidewpnangle) or 15
        ModernMovement.settings.slidescreeneffectalpha = (tonumber(NiceTrainer.Settings.slidescreeneffectalpha) or 0) / 100
        ModernMovement.settings.vaultdebug = (NiceTrainer.Settings.vaultdebug == true)
        ModernMovement:Save()
    end

    if AdvMov then
        AdvMov.settings.vaulting = (NiceTrainer.Settings.vaulting ~= false)
        AdvMov.settings.airvaulting = (NiceTrainer.Settings.airvaulting == true)
        AdvMov.settings.mantlesound = (NiceTrainer.Settings.mantlesound ~= false)
        AdvMov.settings.crouchsprinting = (NiceTrainer.Settings.crouchsprinting == true)
        AdvMov.settings.crouchjump = (NiceTrainer.Settings.crouchjump ~= false)
        AdvMov.settings.nullmovement = (NiceTrainer.Settings.nullmovement == true)
        AdvMov.settings.slidestealth = tonumber(NiceTrainer.Settings.slidestealth) or 2
        AdvMov.settings.slideloud = tonumber(NiceTrainer.Settings.slideloud) or 3
        AdvMov.settings.slidewpnangle = tonumber(NiceTrainer.Settings.slidewpnangle) or 15
        AdvMov.settings.vaultdebug = (NiceTrainer.Settings.vaultdebug == true)
        AdvMov:Save()
    end
end

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Player_ApplyMovement", function()
    reapply_movement_hooks()
end)

Hooks:Add("GameSetupUpdate", "NiceTrainer_Player_MovementGameUpdate", function()
    reapply_movement_hooks()
end)

-- ─── Better Movement Settings Modal ──────────────────────────────────────────

local MODAL_W   = 620
local MODAL_H   = 580
local ROW_H     = 42
local SLIDER_H  = 54
local SUBHDR_H  = 26

local function ShowBetterMovementSettings()
    EnsureMovementDefaults()

    NiceTrainer:ShowCustomModal("Better Movement Settings", MODAL_W, MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        local TRACK_X, TRACK_W = 20, MODAL_W - 40
        local ROW_W = MODAL_W - 16

        local scroll_top  = 50
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = MODAL_W, h = MODAL_H - scroll_top - 12, layer = 2 })

        -- Calculate canvas height
        -- 4 subheaders, 10 checkboxes, 2 multichoices, 3 sliders
        local total_canvas_h = (4 * (SUBHDR_H + 8)) + (10 * (ROW_H + 3)) + (2 * (ROW_H + 3)) + (3 * (SLIDER_H + 4)) + 40
        local canvas = scroll_wrap:panel({ x = 0, y = 0, w = MODAL_W, h = total_canvas_h, layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local y = 8

        local function AddSubHeader(title)
            canvas:text({
                text = string.upper(title),
                font = "fonts/font_large_mf",
                font_size = 18,
                color = Color(0.2, 0.6, 1.0),
                x = 18,
                y = y,
                layer = 2
            })
            canvas:rect({
                color = Color(0.2, 0.6, 1.0),
                alpha = 0.35,
                x = 18,
                y = y + SUBHDR_H - 2,
                w = ROW_W - 18,
                h = 1,
                layer = 2
            })
            y = y + SUBHDR_H + 6
        end

        local function AddCheckboxRow(key, title, tooltip)
            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = ROW_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            local cur_state = (NiceTrainer.Settings[key] == true)
            if DEFAULT_MOVEMENT_SETTINGS[key] == true and NiceTrainer.Settings[key] == nil then
                cur_state = true
            end

            -- Checkbox box
            row:rect({ color = Color.white, alpha = 0.1, x = 8, y = 11, w = 20, h = 20, layer = 1 })
            local cb_fill = row:rect({ color = Color(0.2, 0.6, 1.0), x = 12, y = 15, w = 12, h = 12, visible = cur_state, layer = 2 })

            -- Text
            row:text({
                text = title,
                font = "fonts/font_medium_shadow_mf",
                font_size = 17,
                x = 36,
                y = tooltip and 4 or 11,
                color = Color(0.92, 0.92, 0.92),
                layer = 1
            })

            if tooltip then
                row:text({
                    text = tooltip,
                    font = "fonts/font_medium_shadow_mf",
                    font_size = 13,
                    x = 36,
                    y = 22,
                    color = Color(0.6, 0.6, 0.6),
                    layer = 1
                })
            end

            table.insert(top_modal.elements, {
                panel = row,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and row:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    row_bg:set_alpha(hovered and 0.12 or 0.04)
                end,
                on_click = function(self, mx, my)
                    cur_state = not cur_state
                    NiceTrainer.Settings[key] = cur_state
                    NiceTrainer:Save()
                    if alive(cb_fill) then cb_fill:set_visible(cur_state) end
                    reapply_movement_hooks()
                end
            })

            y = y + ROW_H + 3
        end

        local function AddMultiChoiceRow(key, title, options, default_val)
            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = ROW_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            local cur_idx = tonumber(NiceTrainer.Settings[key]) or default_val or 1
            if cur_idx < 1 or cur_idx > #options then cur_idx = 1 end

            row:text({
                text = title,
                font = "fonts/font_medium_shadow_mf",
                font_size = 17,
                x = 18,
                vertical = "center",
                color = Color(0.92, 0.92, 0.92),
                layer = 1
            })

            local BTN_W = 180
            local BTN_X = ROW_W - 8 - BTN_W
            local btn_panel = row:panel({ x = BTN_X, y = 7, w = BTN_W, h = 28, layer = 2 })
            local btn_bg    = btn_panel:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
            btn_panel:rect({ color = Color(0.2, 0.6, 1.0), w = 2, layer = 1 })
            btn_panel:rect({ color = Color(0.2, 0.6, 1.0), x = BTN_W - 2, w = 2, layer = 1 })
            local btn_txt   = btn_panel:text({
                text = options[cur_idx] or tostring(cur_idx),
                font = "fonts/font_medium_shadow_mf",
                font_size = 15,
                w = BTN_W,
                h = 28,
                align = "center",
                vertical = "center",
                color = Color.white,
                layer = 2
            })

            table.insert(top_modal.elements, {
                panel = btn_panel,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and btn_panel:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    btn_bg:set_alpha(hovered and 0.45 or 0.2)
                end,
                on_click = function(self, mx, my)
                    cur_idx = (cur_idx % #options) + 1
                    NiceTrainer.Settings[key] = cur_idx
                    NiceTrainer:Save()
                    if alive(btn_txt) then
                        btn_txt:set_text(options[cur_idx] or tostring(cur_idx))
                    end
                    reapply_movement_hooks()
                end
            })

            y = y + ROW_H + 3
        end

        local function AddSliderRow(key, title, min_val, max_val, default_val, is_float, suffix)
            local row = canvas:panel({ x = 8, y = y, w = ROW_W, h = SLIDER_H, layer = 2 })
            local val = tonumber(NiceTrainer.Settings[key]) or default_val or min_val

            row:text({
                text = title .. ":",
                font = "fonts/font_medium_shadow_mf",
                font_size = 17,
                x = 18,
                y = 4,
                color = Color.white,
                layer = 1
            })

            local val_fmt = is_float and string.format("%.1f%s", val, suffix or "") or string.format("%d%s", math.floor(val + 0.5), suffix or "")
            local val_txt = row:text({
                text = val_fmt,
                font = "fonts/font_medium_shadow_mf",
                font_size = 17,
                color = Color(0.2, 0.6, 1.0),
                x = ROW_W - 80,
                y = 4,
                w = 70,
                align = "right",
                layer = 1
            })

            local S_TRACK_X = 18
            local S_TRACK_W = ROW_W - 36
            local s_ty = 28

            local track_bg   = row:rect({ color = Color.black, alpha = 0.5, x = S_TRACK_X, y = s_ty + 5, w = S_TRACK_W, h = 6, layer = 1 })
            local pct        = math.clamp((val - min_val) / (max_val - min_val), 0, 1)
            local track_fill = row:rect({ color = Color(0.2, 0.6, 1.0), x = S_TRACK_X, y = s_ty + 5, w = pct * S_TRACK_W, h = 6, layer = 2 })
            local track_knob = row:rect({ color = Color.white, x = S_TRACK_X + pct * S_TRACK_W - 4, y = s_ty + 1, w = 8, h = 14, layer = 3 })

            table.insert(top_modal.elements, {
                panel = track_bg,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and (track_bg:inside(mx, my) or track_knob:inside(mx, my))
                end,
                on_click = function(self, mx, my)
                    NiceTrainer._dragging_slider = function(drag_x)
                        local rx = drag_x - track_bg:world_x()
                        local new_pct = math.clamp(rx / S_TRACK_W, 0, 1)
                        local new_val
                        if is_float then
                            new_val = math.floor((min_val + new_pct * (max_val - min_val)) * 10 + 0.5) / 10
                        else
                            new_val = math.floor(min_val + new_pct * (max_val - min_val) + 0.5)
                        end
                        NiceTrainer.Settings[key] = new_val
                        NiceTrainer:Save()
                        if alive(track_fill) then track_fill:set_w(new_pct * S_TRACK_W) end
                        if alive(track_knob) then track_knob:set_x(S_TRACK_X + new_pct * S_TRACK_W - 4) end
                        if alive(val_txt) then
                            local fmt = is_float and string.format("%.1f%s", new_val, suffix or "") or string.format("%d%s", math.floor(new_val + 0.5), suffix or "")
                            val_txt:set_text(fmt)
                        end
                        reapply_movement_hooks()
                    end
                    NiceTrainer._dragging_slider(mx)
                end
            })

            y = y + SLIDER_H + 4
        end

        -- 1. PARKOUR & MANTLING
        AddSubHeader("Parkour & Mantling (Vaulting)")
        AddCheckboxRow("vaulting", "Modern Mantling", "Jump at a low ledge to climb or vault over it.")
        AddCheckboxRow("airvaulting", "Air Mantle Catch", "Allows mantles to start while falling or mid-air.")
        AddCheckboxRow("mantlesound", "Mantle Sound Effects", "Plays a grab sound when a mantle starts.")
        AddCheckboxRow("vaultdebug", "Mantle Debug Logging", "Writes mantle raycast traces to console log.")

        -- 2. SLIDING MECHANICS
        AddSubHeader("Sliding Mechanics")
        AddMultiChoiceRow("slidestealth", "Stealth Slide Mode", { "Disabled", "Hold Crouch + Move", "Hold Crouch Only" }, 2)
        AddMultiChoiceRow("slideloud", "Loud Slide Mode", { "Disabled", "Hold Crouch + Move", "Hold Crouch Only" }, 3)
        AddSliderRow("slidewpnangle", "Slide Weapon Tilt", 0, 30, 15, false, "°")
        AddSliderRow("slidescreeneffectalpha", "Slide Speed Blur Effect", 0, 100, 0, false, "%")

        -- 3. AGILITY & CONTROLS
        AddSubHeader("Agility & Controls")
        AddCheckboxRow("crouchsprinting", "Crouch Sprinting", "Sprint while crouched. (Standard slide is bypassed while active)")
        AddCheckboxRow("crouchjump", "Crouch Jumping", "Jump directly while crouched without standing up (Vanilla stands up).")
        AddCheckboxRow("nullmovement", "Null Movement / SOCD", "When opposing movement keys (A+D/W+S) are held, newest key wins.")

        -- 4. MOVEMENT ENHANCEMENTS & TRAINER TWEAKS
        AddSubHeader("Movement Enhancements & Speed")
        AddCheckboxRow("enable_run_speed", "Enable Speed Multiplier", "Multiplies overall player movement speed.")
        AddSliderRow("run_speed_multiplier", "Run Speed Multiplier", 1.0, 10.0, 2.0, true, "x")
        AddCheckboxRow("high_jump", "High Jump", "Jump 2.5x higher while sprinting.")
        AddCheckboxRow("run_in_all_directions", "Run In All Directions", "Allows sprinting sideways and backwards.")
        AddCheckboxRow("no_bag_penalty", "No Bag Penalty", "Sprint and jump freely while carrying any type of bag.")
    end)
end

-- ─── Action Registrations ───────────────────────────────────────────────────

NiceTrainer:RegisterAction("Player", {
    type              = "toggle_settings",
    category          = "Movement",
    badge             = "client",
    id                = "better_movement",
    text              = "Better Movement",
    tooltip           = "Comprehensive movement overhaul: mantling, sliding, crouch sprint, high jump, speed and custom controls.",
    default           = true,
    save              = true,
    callback          = function(state)
        NiceTrainer.Settings.better_movement = state
        NiceTrainer:Save()
        reapply_movement_hooks()
    end,
    settings_callback = ShowBetterMovementSettings,
})

NiceTrainer:RegisterAction("Player", {
    type     = "button",
    category = "Movement",
    badge    = "client",
    text     = "Teleport to Crosshair",
    tooltip  = "Teleports you instantly to where you are aiming.",
    callback = function()
        if not managers.player then return end
        local player = managers.player:player_unit()
        if not alive(player) or not player:camera() then return end
        
        local from = player:camera():position()
        local to = from + player:camera():forward() * 100000
        local ray = World:raycast("ray", from, to, "slot_mask", managers.slot:get_mask("all"))
        
        if ray then
            managers.player:warp_to(ray.hit_position, player:rotation())
            NiceTrainer:Toast("Teleported!")
        else
            NiceTrainer:Toast("No valid surface found.")
        end
    end
})
