-- ─── Radial Mouse Menu System (Visuals Tab) ──────────────────────────────────
-- Integrated radial selection wheel with exact geometry, centered icons, and clean pointer management.

local this_version = 1.19
RadialMouseMenu = RadialMouseMenu or class()
RadialMouseMenu.VERSION = this_version
RadialMouseMenu.MOUSE_ID = "radial_menu_mouse"
RadialMouseMenu.queued_items = RadialMouseMenu.queued_items or {}

function RadialMouseMenu.GetWorkspace()
    if not RadialMouseMenu._WS or not alive(RadialMouseMenu._WS) then
        if managers.gui_data then
            RadialMouseMenu._WS = managers.gui_data:create_fullscreen_workspace()
        elseif Overlay and Overlay.newgui then
            RadialMouseMenu._WS = Overlay:newgui():create_screen_workspace()
        elseif Overlay and Overlay.gui then
            RadialMouseMenu._WS = Overlay:gui():create_screen_workspace()
        end
    end
    return RadialMouseMenu._WS
end

function RadialMouseMenu:init(params, callback)
    local ws = RadialMouseMenu.GetWorkspace()
    if not ws or not alive(ws) then
        table.insert(RadialMouseMenu.queued_items, 1, { callback = callback, params = params })
        return self
    end

    local base = ws:panel()
    self._base = base
    params = params or {}
    local name = params.name or "RadialMenu_" .. tostring(math.random(1000, 9999))

    Hooks:Register("radialmenu_selected_" .. name)
    Hooks:Register("radialmenu_released_" .. name)

    self.keep_mouse_position = params.keep_mouse_position or false
    self.allow_keyboard_input = params.allow_keyboard_input or false
    self.allow_camera_look = params.allow_camera_look or false
    self.block_all_input = (params.block_all_input == nil) and true or params.block_all_input

    if self.block_all_input then
        self.allow_keyboard_input = false
        self.allow_camera_look = false
    end

    local radius = params.radius or 300
    self._size = radius
    self._deadzone = params.deadzone or 35
    self._name = name
    self._items = params.items or {}

    local existing = base:child(name)
    if existing and alive(existing) then
        base:remove(existing)
    end

    self._hud = base:panel({
        name = self._name,
        layer = 1500,
        visible = false,
        x = params.x or 0,
        y = params.y or 0,
        w = base:w(),
        h = base:h()
    })

    local center_x = self._hud:w() / 2
    local center_y = self._hud:h() / 2

    self._bg = self._hud:bitmap({
        name = name .. "_BG",
        texture = "guis/textures/pd2/hud_radialbg",
        layer = 1,
        alpha = 0.75,
        w = radius,
        h = radius
    })
    self._bg:set_center(center_x, center_y)

    self._blur = self._hud:bitmap({
        texture = tweak_data.hud_icons.icon_circlefill16.texture,
        texture_rect = tweak_data.hud_icons.icon_circlefill16.texture_rect,
        name = name .. "_BLUR",
        render_template = "VertexColorTexturedBlur3D",
        layer = -2,
        alpha = 0.5,
        w = radius,
        h = radius
    })
    self._blur:set_center(center_x, center_y)

    self._center_text = self._hud:text({
        name = name .. "_CENTER_TEXT",
        text = "",
        layer = 4,
        font_size = 17,
        align = "center",
        vertical = "center",
        font = tweak_data.hud.medium_font,
        color = Color.white,
        visible = false
    })

    self._selector = self._hud:bitmap({
        name = name .. "_SELECTOR",
        texture = "guis/textures/pd2/hud_shield",
        render_template = "VertexColorTexturedRadial",
        layer = 2,
        color = Color(1 / math.max(#self._items, 1), 1, 1),
        w = radius,
        h = radius,
        visible = false
    })
    self._selector:set_center(center_x, center_y)

    self._arrow = self._hud:bitmap({
        name = name .. "_ARROW",
        w = 16,
        h = 16,
        texture = tweak_data.hud_icons.wp_arrow.texture,
        texture_rect = tweak_data.hud_icons.wp_arrow.texture_rect,
        layer = 5,
        visible = false
    })

    self._selected = false
    self._init_items_done = false
    self._active = false

    self:populate_items()

    if type(callback) == "function" then
        callback(self)
    end
    return self
end

function RadialMouseMenu:mouse_moved(o, mouse_x, mouse_y)
    if not self._hud or not alive(self._hud) then return end

    local offset_x = self._hud:w() / 2
    local offset_y = self._hud:h() / 2
    local rel_x = mouse_x - (self._hud:x() + offset_x)
    local rel_y = mouse_y - (self._hud:y() + offset_y)

    local num_items = math.max(#self._items, 1)
    local length = 0.5 * (self._size + 10)

    local mouse_angle
    if rel_x ~= 0 then
        mouse_angle = math.atan(rel_y / rel_x) % 180
        if rel_y == 0 then
            if rel_x > 0 then
                mouse_angle = 180
            else
                mouse_angle = 360
            end
        elseif rel_y > 0 then
            mouse_angle = mouse_angle - 180
        end
    else
        if rel_y > 0 then
            mouse_angle = 270
        else
            mouse_angle = 90
        end
    end

    local angle_interval = 360 / num_items
    local clean_angle = ((mouse_angle - 90) + (180 / num_items)) % 360

    local mouseover_selected = 1 + math.floor(clean_angle / angle_interval)
    if mouseover_selected > num_items then mouseover_selected = 1 end
    local mouseover_angle = (mouseover_selected - 0.5) * angle_interval
    self._selector:set_rotation(mouseover_angle - angle_interval)

    local function outside_deadzone(x1, y1, d)
        if not d then return true end
        return ((x1 * x1) + (y1 * y1)) >= (d * d)
    end

    local item = self._items[mouseover_selected]
    if outside_deadzone(rel_x, rel_y, self._deadzone) then
        self:on_mouseover_item(mouseover_selected)
    else
        self._selector:set_visible(false)
        self._selected = false
        self._center_text:set_visible(false)
        self._arrow:set_visible(false)
    end

    local opposite = math.cos(mouse_angle - 180)
    local adjacent = math.sin(mouse_angle - 180)

    self._arrow:set_center((opposite * length) + offset_x, (adjacent * length) + offset_y)
    self._arrow:set_rotation(mouse_angle)
end

function RadialMouseMenu:mouse_clicked(o, button, x, y)
    if button == Idstring("0") or button == Idstring("1") or button == Idstring("2") then
        local item = self._selected and self._items[self._selected]
        if item then
            self:on_item_clicked(item)
        else
            self:Hide(nil, false)
        end
    end
end

function RadialMouseMenu:on_item_clicked(item, skip_hide)
    local success, result
    if not (item.stay_open or skip_hide) then
        self:Hide(nil, false)
    end
    if item.callback then
        success, result = pcall(item.callback)
    end
    Hooks:Call("radialmenu_selected_" .. self._name, self._selected, result)
end

function RadialMouseMenu:on_mouseover_item(index)
    local item = self:get_item(index)
    if not item then
        self._selected = false
        return
    end
    self._selected = index
    self._selector:set_visible(true)
    self._center_text:set_visible(true)
    self._center_text:set_text(item.text or "")
    self._arrow:set_visible(true)
    self._arrow:set_color(item._icon and item._icon:color() or Color.white)
end

function RadialMouseMenu:Toggle(state, ...)
    if state == nil then
        state = not self:active()
    end
    if state then
        self:Show(...)
    else
        self:Hide(...)
    end
end

function RadialMouseMenu:Show()
    if self._active then return end

    if not self._hud or not alive(self._hud) then
        self:init({
            name = self._name,
            radius = self._size,
            deadzone = self._deadzone,
            allow_keyboard_input = self.allow_keyboard_input,
            allow_camera_look = self.allow_camera_look,
            block_all_input = self.block_all_input,
            items = self._items
        })
    end

    if not self._init_items_done then
        self:populate_items()
    end

    if RadialMouseMenu.current_menu and RadialMouseMenu.current_menu:get_name() ~= self:get_name() then
        RadialMouseMenu.current_menu:Hide(true)
    end
    RadialMouseMenu.current_menu = self

    self._hud:show()
    local this = self
    local data = {
        mouse_move = function(o, x, y) this:mouse_moved(o, x, y) end,
        mouse_press = function(o, btn, x, y) this:mouse_clicked(o, btn, x, y) end,
        mouse_click = function(o, btn, x, y) this:mouse_clicked(o, btn, x, y) end,
        id = RadialMouseMenu.MOUSE_ID
    }

    if managers.mouse_pointer then
        if managers.mouse_pointer._mouse_callbacks then
            for i = #managers.mouse_pointer._mouse_callbacks, 1, -1 do
                local cb = managers.mouse_pointer._mouse_callbacks[i]
                if cb and cb.id == RadialMouseMenu.MOUSE_ID then
                    table.remove(managers.mouse_pointer._mouse_callbacks, i)
                end
            end
        end
        managers.mouse_pointer:use_mouse(data)
        if managers.mouse_pointer._mouse and alive(managers.mouse_pointer._mouse) then
            managers.mouse_pointer._mouse:hide()
        end
        if self.block_all_input and game_state_machine and game_state_machine:current_state() and game_state_machine:current_state().set_controller_enabled then
            game_state_machine:current_state():set_controller_enabled(false)
        end
        if not self.keep_mouse_position then
            managers.mouse_pointer:set_mouse_world_position(self._hud:w() / 2, self._hud:h() / 2)
        end
    end

    self._active = true
end

function RadialMouseMenu:get_name()
    return self._name
end

function RadialMouseMenu:active()
    return self._active and self._hud and alive(self._hud) and self._hud:visible()
end

function RadialMouseMenu:Hide(skip_reset, do_success_cb)
    if not skip_reset then
        RadialMouseMenu.current_menu = nil
    end

    if self._hud and alive(self._hud) then
        self._hud:hide()
    end

    if self.block_all_input and game_state_machine and game_state_machine:current_state() and game_state_machine:current_state().set_controller_enabled then
        game_state_machine:current_state():set_controller_enabled(true)
    end

    local item = self._selected and self._items[self._selected]
    self._selected = false

    if self._active then
        self._active = false
        if self._selector and alive(self._selector) then
            self._selector:set_visible(false)
        end
        if self._arrow and alive(self._arrow) then
            self._arrow:set_visible(false)
        end
        if self._center_text and alive(self._center_text) then
            self._center_text:set_visible(false)
        end

        if managers.mouse_pointer then
            if managers.mouse_pointer._mouse_callbacks then
                for i = #managers.mouse_pointer._mouse_callbacks, 1, -1 do
                    local cb = managers.mouse_pointer._mouse_callbacks[i]
                    if cb and cb.id == RadialMouseMenu.MOUSE_ID then
                        table.remove(managers.mouse_pointer._mouse_callbacks, i)
                    end
                end
            end
            managers.mouse_pointer:remove_mouse(RadialMouseMenu.MOUSE_ID)

            local trainer_open = (NiceTrainer and NiceTrainer.IsOpen)
            local game_menu_active = (managers.menu and managers.menu.is_active and managers.menu:is_active())

            if not trainer_open and not game_menu_active then
                if managers.mouse_pointer._deactivate then
                    managers.mouse_pointer:_deactivate()
                end
                if managers.mouse_pointer._ws and alive(managers.mouse_pointer._ws) then
                    managers.mouse_pointer._ws:hide()
                end
                if managers.controller and managers.controller:get_mouse_controller() and managers.controller:get_mouse_controller().set_lock_mouse then
                    managers.controller:get_mouse_controller():set_lock_mouse(true)
                end
            else
                if managers.mouse_pointer._mouse and alive(managers.mouse_pointer._mouse) then
                    managers.mouse_pointer._mouse:show()
                end
            end
        end

        self:on_closed()
        if do_success_cb and item then
            self:on_item_clicked(item, true)
        end
    end
end

function RadialMouseMenu:reset_items(skip_refresh)
    for _, data in ipairs(self._items) do
        if data._panel and alive(data._panel) then
            self._hud:remove(data._panel)
            data._icon = nil
            data._body = nil
            data._panel = nil
        end
    end
end

function RadialMouseMenu:pre_destroy()
    if self._hud and alive(self._hud) then
        local ws = RadialMouseMenu.GetWorkspace()
        if ws and alive(ws) and alive(ws:panel()) then
            ws:panel():remove(self._hud)
        end
    end
    self._hud = nil
    self._active = false
end

function RadialMouseMenu:get_item(index)
    return self._items[index]
end

function RadialMouseMenu:on_closed()
    Hooks:Call("radialmenu_released_" .. self:get_name(), self._selected)
end

function RadialMouseMenu:populate_items()
    if not self._hud or not alive(self._hud) then return end
    self:reset_items(true)

    local num_items = math.max(#self._items, 1)
    local ho = self._hud:h() / 2
    local wo = self._hud:w() / 2

    for k, data in ipairs(self._items) do
        local name = "item_" .. k
        local new_segment = self._hud:panel({
            name = name .. "_PANEL",
            layer = 2,
            w = self._size,
            h = self._size
        })
        new_segment:set_center(wo, ho)
        data._panel = new_segment

        local angle = (360 * ((k - 1) / num_items) - 90) % 360

        local body = {
            layer = 1,
            alpha = 0.3,
            texture = "guis/dlcs/coco/textures/pd2/hud_absorb_stack_fg",
            w = self._size,
            h = self._size,
            name = name .. "_TEXTURE",
            render_template = "VertexColorTexturedRadial",
            color = Color(1 / num_items, 1, 1),
            rotation = angle + 90 - (180 / num_items)
        }

        local segment_texture = new_segment:bitmap(body)
        segment_texture:set_center(self._size / 2, self._size / 2)
        data._body = segment_texture

        local icon_data = data.icon or { layer = 3, visible = true, color = Color.white, w = 24, h = 24 }
        icon_data.name = name .. "_ICON"
        icon_data.w = icon_data.w or 24
        icon_data.h = icon_data.h or 24

        local icon_center_x = (self._size / 2) + (math.cos(angle) * (self._size * 0.33))
        local icon_center_y = (self._size / 2) + (math.sin(angle) * (self._size * 0.33))

        if icon_data.texture then
            local segment_icon = new_segment:bitmap(icon_data)
            segment_icon:set_center(icon_center_x, icon_center_y)
            data._icon = segment_icon
        end
    end

    if self._selector and alive(self._selector) then
        self._selector:set_color(Color(1 / num_items, 1, 1))
    end
    self._init_items_done = true
end

-- ─── Hooks for Camera & Movement ───────────────────────────────────────────────

if _G.PlayerStandard and not PlayerStandard._nt_radial_hooked then
    PlayerStandard._nt_radial_hooked = true
    local orig_determine_move = PlayerStandard._determine_move_direction
    function PlayerStandard:_determine_move_direction(...)
        if RadialMouseMenu and RadialMouseMenu.current_menu and RadialMouseMenu.current_menu:active() then
            if not RadialMouseMenu.current_menu.allow_keyboard_input then
                self._move_dir = nil
                self._normal_move_dir = nil
                return
            end
        end
        return orig_determine_move(self, ...)
    end

    local orig_check_fire = PlayerStandard._check_action_primary_attack
    function PlayerStandard:_check_action_primary_attack(...)
        if RadialMouseMenu and RadialMouseMenu.current_menu and RadialMouseMenu.current_menu:active() then
            return false
        end
        return orig_check_fire(self, ...)
    end
end

if _G.FPCameraPlayerBase and not FPCameraPlayerBase._nt_radial_hooked then
    FPCameraPlayerBase._nt_radial_hooked = true
    local pc_look = FPCameraPlayerBase._pc_look_function
    function FPCameraPlayerBase:_pc_look_function(...)
        if RadialMouseMenu and RadialMouseMenu.current_menu and RadialMouseMenu.current_menu:active() then
            if not RadialMouseMenu.current_menu.allow_camera_look then
                return 0, 0
            end
        end
        return pc_look(self, ...)
    end
end

-- ─── NiceTrainer Actions & Wheel Logic (Visuals Tab) ───────────────────────────

NiceTrainer._radial_menus = NiceTrainer._radial_menus or {}
local R = NiceTrainer._radial_menus

local function act_toggle_god_mode()
    if not NiceTrainer:IsInHeist() then return end
    local cur = NiceTrainer.Settings.god_mode or false
    NiceTrainer:SetToggleState("god_mode", not cur)
end

local function act_toggle_infinite_ammo()
    if not NiceTrainer:IsInHeist() then return end
    local cur = NiceTrainer.Settings.infinite_ammo or false
    NiceTrainer:SetToggleState("infinite_ammo", not cur)
end

local function act_replenish_health()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if alive(player) and player:character_damage() then
            player:character_damage():replenish()
        end
    end)
end

local function act_replenish_ammo_equipment()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if alive(player) then
            if player:inventory() then
                for _, weapon in pairs(player:inventory():available_selections()) do
                    if alive(weapon.unit) and weapon.unit:base() then
                        weapon.unit:base():replenish()
                    end
                end
            end
            if managers.player then
                managers.player:add_cable_ties(9)
                managers.player:add_grenade_amount(9)
                if managers.player:get_equipment_amount("doctor_bag") then
                    managers.player:add_special({ name = "doctor_bag", amount = 2 })
                end
                if managers.player:get_equipment_amount("ammo_bag") then
                    managers.player:add_special({ name = "ammo_bag", amount = 2 })
                end
            end
        end
    end)
end

local function act_finish_all_drills()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        for _, unit in pairs(World:find_units_quick("all")) do
            if alive(unit) then
                if unit.timer_gui and unit:timer_gui() then
                    local tg = unit:timer_gui()
                    if tg and tg._started and not tg._done then
                        tg._current_timer = 0
                        if tg.done then tg:done() end
                    end
                end
                if unit.digital_gui and unit:digital_gui() then
                    local dg = unit:digital_gui()
                    if dg and (dg._timer or 0) > 0 then
                        dg._timer = 0
                        if alive(dg._unit) and dg._unit:damage() then
                            if dg._unit:damage():has_sequence("timer_done") then
                                dg._unit:damage():run_sequence_simple("timer_done")
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function act_interact_all()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if not alive(player) then return end

        for _, u in pairs(managers.interaction and managers.interaction._interactive_units or {}) do
            if alive(u) and u.interaction and u:interaction() and u:interaction():active() then
                pcall(function()
                    u:interaction():interact(player)
                end)
            end
        end
    end)
end

local function act_secure_all_loot()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:carry_data() then
                local cd = u:carry_data()
                if managers.loot then
                    managers.loot:secure(cd:carry_id(), cd:multiplier(), true)
                    u:set_slot(0)
                end
            end
        end
    end)
end

local function act_revive_all_team()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if alive(player) and player:character_damage() then
            if player:character_damage():need_revive() or player:character_damage():arrested() then
                player:character_damage():revive(true)
            end
        end
        for _, criminal in pairs(managers.criminals and managers.criminals:characters() or {}) do
            if criminal.unit and alive(criminal.unit) and criminal.unit:character_damage() then
                if criminal.unit:character_damage():need_revive() or criminal.unit:character_damage():arrested() then
                    criminal.unit:character_damage():revive(true)
                end
            end
        end
    end)
end

local function act_teleport_forward()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if alive(player) and player:camera() then
            local rot = player:camera():rotation()
            local dir = rot:y()
            local new_pos = player:position() + dir * 600
            player:warp_to(rot, new_pos)
        end
    end)
end

local function act_teleport_to_crosshair()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        local player = managers.player and managers.player:player_unit()
        if alive(player) and player:camera() then
            local from = player:camera():position()
            local to = from + player:camera():forward() * 20000
            local ray = World:raycast("ray", from, to, "slot_mask", managers.slot:get_mask("statics_bullet_blank"))
            if ray and ray.hit_position then
                local rot = player:camera():rotation()
                player:warp_to(rot, ray.hit_position + Vector3(0, 0, 10))
            end
        end
    end)
end

local function act_pacify_all_enemies()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:character_damage() and not u:character_damage():dead() then
                if managers.enemy and managers.enemy:is_enemy(u) then
                    local dmg_info = {
                        damage = 999999,
                        col_ray = { position = u:position(), ray = Vector3(0, 0, 1) },
                        variant = "bullet"
                    }
                    u:character_damage():damage_bullet(dmg_info)
                end
            end
        end
    end)
end

local function act_stealth_pagers_cams()
    if not NiceTrainer:IsInHeist() then return end
    pcall(function()
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:base() and u:base()._tape_loop_activated ~= nil then
                u:base()._tape_loop_activated = true
            end
        end
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() and u:interaction().tweak_data == "corpse_alarm_pager" then
                u:interaction():interact(managers.player:player_unit())
            end
        end
    end)
end

local function act_open_main_menu()
    pcall(function()
        NiceTrainer:Toggle()
    end)
end

local function create_icon(icon_name, color)
    local ic = tweak_data.hud_icons and tweak_data.hud_icons[icon_name]
    if ic then
        return {
            texture = ic.texture,
            texture_rect = ic.texture_rect,
            w = 24,
            h = 24,
            color = color or Color.white,
            alpha = 0.95
        }
    end
    return {
        w = 24,
        h = 24,
        color = color or Color.white
    }
end

local function build_wheel_by_preset(preset_idx)
    local rad = NiceTrainer.Settings.radial_radius or 300
    local deadzone = NiceTrainer.Settings.radial_deadzone or 35
    local allow_mov = NiceTrainer.Settings.radial_allow_movement or false
    local allow_cam = NiceTrainer.Settings.radial_allow_camera or false

    local items = {}

    if preset_idx == 2 then
        items = {
            { text = "Finish All Drills & Hacks", icon = create_icon("equipment_drill", Color(1.0, 0.6, 0.2)), callback = act_finish_all_drills },
            { text = "Unlock All Doors & Gates", icon = create_icon("wp_door", Color(0.2, 0.8, 1.0)), callback = act_interact_all },
            { text = "Secure All Loot Bags", icon = create_icon("pd2_loot", Color(1.0, 0.85, 0.2)), callback = act_secure_all_loot },
            { text = "Teleport Forward 6m", icon = create_icon("wp_standard", Color(0.2, 1.0, 0.8)), callback = act_teleport_forward },
            { text = "Teleport to Crosshair", icon = create_icon("wp_standard", Color(0.4, 0.8, 1.0)), callback = act_teleport_to_crosshair },
            { text = "Refill Equipment / Bags", icon = create_icon("equipment_ammo", Color(1.0, 0.85, 0.2)), callback = act_replenish_ammo_equipment },
            { text = "Open NiceTrainer Menu", icon = create_icon("pd2_mask_icon", Color(1.0, 0.4, 0.8)), callback = act_open_main_menu }
        }
    elseif preset_idx == 3 then
        items = {
            { text = "God Mode (Toggle)", icon = create_icon("icon_shield", Color(0.2, 1.0, 0.4)), callback = act_toggle_god_mode },
            { text = "Infinite Ammo (Toggle)", icon = create_icon("equipment_ammo", Color(0.2, 0.8, 1.0)), callback = act_toggle_infinite_ammo },
            { text = "Full Heal & Armor", icon = create_icon("equipment_doctor_bag", Color(0.2, 1.0, 0.4)), callback = act_replenish_health },
            { text = "Refill Ammo & Grenades", icon = create_icon("equipment_ammo", Color(1.0, 0.85, 0.2)), callback = act_replenish_ammo_equipment },
            { text = "Neutralize All Enemies", icon = create_icon("icon_damage", Color(1.0, 0.2, 0.2)), callback = act_pacify_all_enemies },
            { text = "Revive Entire Team", icon = create_icon("wp_revive", Color(0.2, 1.0, 0.4)), callback = act_revive_all_team },
            { text = "Open NiceTrainer Menu", icon = create_icon("pd2_mask_icon", Color(1.0, 0.4, 0.8)), callback = act_open_main_menu }
        }
    elseif preset_idx == 4 then
        items = {
            { text = "Disable Cams & Pagers", icon = create_icon("equipment_ecm_jammer", Color(0.2, 1.0, 0.8)), callback = act_stealth_pagers_cams },
            { text = "Silent Unlock Doors", icon = create_icon("wp_door", Color(0.2, 0.8, 1.0)), callback = act_interact_all },
            { text = "Instant Finish Drills", icon = create_icon("equipment_drill", Color(1.0, 0.85, 0.2)), callback = act_finish_all_drills },
            { text = "Secure All Bags", icon = create_icon("pd2_loot", Color(1.0, 0.85, 0.2)), callback = act_secure_all_loot },
            { text = "Teleport Forward 6m", icon = create_icon("wp_standard", Color(0.2, 1.0, 0.4)), callback = act_teleport_forward },
            { text = "Open NiceTrainer Menu", icon = create_icon("pd2_mask_icon", Color(1.0, 0.4, 0.8)), callback = act_open_main_menu }
        }
    else
        items = {
            { text = "God Mode (Toggle)", icon = create_icon("icon_shield", Color(0.2, 1.0, 0.4)), callback = act_toggle_god_mode },
            { text = "Infinite Ammo (Toggle)", icon = create_icon("equipment_ammo", Color(0.2, 0.8, 1.0)), callback = act_toggle_infinite_ammo },
            { text = "Heal & Armor", icon = create_icon("equipment_doctor_bag", Color(0.2, 1.0, 0.4)), callback = act_replenish_health },
            { text = "Refill Ammo & Bags", icon = create_icon("equipment_ammo", Color(1.0, 0.85, 0.2)), callback = act_replenish_ammo_equipment },
            { text = "Finish All Drills & Hacks", icon = create_icon("equipment_drill", Color(1.0, 0.6, 0.2)), callback = act_finish_all_drills },
            { text = "Interact All / Unlock Map", icon = create_icon("wp_door", Color(0.2, 1.0, 0.8)), callback = act_interact_all },
            { text = "Secure All Loot", icon = create_icon("pd2_loot", Color(1.0, 0.85, 0.2)), callback = act_secure_all_loot },
            { text = "Revive Team & Self", icon = create_icon("wp_revive", Color(0.2, 1.0, 0.4)), callback = act_revive_all_team },
            { text = "Teleport to Crosshair", icon = create_icon("wp_standard", Color(0.4, 0.8, 1.0)), callback = act_teleport_to_crosshair },
            { text = "Open NiceTrainer Menu", icon = create_icon("pd2_mask_icon", Color(1.0, 0.4, 0.8)), callback = act_open_main_menu }
        }
    end

    if R.current_wheel then
        R.current_wheel:pre_destroy()
    end

    R.current_wheel = RadialMouseMenu:new({
        name = "NiceTrainer_Radial_Wheel",
        radius = rad,
        deadzone = deadzone,
        allow_keyboard_input = allow_mov,
        allow_camera_look = allow_cam,
        block_all_input = not allow_mov and not allow_cam,
        items = items
    })
    return R.current_wheel
end

local function open_or_toggle_radial_menu()
    if not (NiceTrainer.Settings and (NiceTrainer.Settings.enable_radial_menu ~= false)) then
        return
    end

    local preset = NiceTrainer.Settings.radial_preset_wheel or 1
    local wheel = build_wheel_by_preset(preset)
    if wheel then
        wheel:Toggle()
    end
end

-- ─── Action Registrations in Visuals Tab ───────────────────────────────────────

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Radial Mouse Menu",
    badge    = "client",
    id       = "enable_radial_menu",
    text     = "Enable Radial Mouse Menu",
    tooltip  = "Enables the in-game radial wheel selector controlled with your mouse.",
    default  = true,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.enable_radial_menu = state
        if not state and RadialMouseMenu and RadialMouseMenu.current_menu then
            RadialMouseMenu.current_menu:Hide(true)
        end
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "keybind",
    category    = "Radial Mouse Menu",
    badge       = "client",
    id          = "radial_menu_hotkey",
    text        = "Radial Menu Hotkey",
    tooltip     = "Press this key in-game to open and select radial actions with your mouse (Default: M3 / Middle Click, or any key like V).",
    default     = "mouse 2",
    callback    = function()
        open_or_toggle_radial_menu()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type           = "multichoice",
    category       = "Radial Mouse Menu",
    id             = "radial_preset_wheel",
    text           = "Radial Wheel Preset",
    tooltip        = "Choose which action preset to load onto your radial wheel.",
    options        = {
        "1. Quick Cheats (God, Ammo, Heal, Revive, Drills, Teleport)",
        "2. Heist & World Utilities (Drills, Unlock, Loot, Teleport)",
        "3. Combat Destroyer (God, Ammo, Kill Enemies, Revive)",
        "4. Stealth Master (Pagers, Cams, Doors, Silent Drills)"
    },
    default        = 1,
    save           = true,
    action_btn_text = "Apply",
    callback       = function(idx, val)
        NiceTrainer.Settings.radial_preset_wheel = idx
        NiceTrainer:Save()
        build_wheel_by_preset(idx)
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "slider",
    category    = "Radial Mouse Menu",
    id          = "radial_radius",
    text        = "Wheel Radius (Size)",
    tooltip     = "Adjust the size of the radial wheel on your screen.",
    min         = 200,
    max         = 500,
    step        = 10,
    default     = 300,
    save        = true,
    callback    = function(val)
        NiceTrainer.Settings.radial_radius = val
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type        = "slider",
    category    = "Radial Mouse Menu",
    id          = "radial_deadzone",
    text        = "Center Deadzone (Pixels)",
    tooltip     = "Minimum distance from center required before a slice is highlighted.",
    min         = 10,
    max         = 100,
    step        = 5,
    default     = 35,
    save        = true,
    callback    = function(val)
        NiceTrainer.Settings.radial_deadzone = val
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Radial Mouse Menu",
    id       = "radial_allow_movement",
    text     = "Allow Player Movement while Wheel is Open",
    tooltip  = "Allows you to continue walking while the radial wheel is displayed.",
    default  = false,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.radial_allow_movement = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type     = "toggle",
    category = "Radial Mouse Menu",
    id       = "radial_allow_camera",
    text     = "Allow Camera Look while Wheel is Open",
    tooltip  = "Allows turning camera while moving the mouse inside the radial wheel.",
    default  = false,
    save     = true,
    callback = function(state)
        NiceTrainer.Settings.radial_allow_camera = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("Visuals", {
    type           = "button",
    category       = "Radial Mouse Menu",
    badge          = "client",
    text           = "Preview / Test Radial Wheel Now",
    tooltip        = "Opens the radial mouse menu right now for testing.",
    action_btn_text = "Open Wheel",
    callback       = function()
        if NiceTrainer.IsOpen then
            NiceTrainer:Toggle()
        end
        DelayedCalls:Add("NT_OpenRadialPreview", 0.1, function()
            open_or_toggle_radial_menu()
        end)
    end
})

Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_Radial_InitHotkeys", function()
    local key = (NiceTrainer.Settings and NiceTrainer.Settings.radial_menu_hotkey) or "mouse 2"
    if key and key ~= "" then
        NiceTrainer:BindGlobalHotkey("radial_menu_hotkey", key, open_or_toggle_radial_menu, "Visuals")
    end
end)
