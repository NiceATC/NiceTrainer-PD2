local ESP = NiceTrainer.ESP

if not NiceTrainer._esp_marker_hook_added then
    Hooks:Add("GameSetupUpdate", "NiceTrainer_ESP_Markers_Update", function(t, dt)
        if NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled and ESP._highlighted_units then
            for _, u in pairs(ESP._highlighted_units) do
                if alive(u) then
                    local ud = u:unit_data()
                    if ud then ud.ignore_portal = true end
                    if not u:visible() then
                        pcall(u.set_visible, u, true)
                    end
                end
            end
        end
        ESP.UpdateMarkers()
    end)
    NiceTrainer._esp_marker_hook_added = true
end
-- ─── Update loop ─────────────────────────────────────────────────────────────

if not NiceTrainer._esp_hook_added then
    Hooks:Add("GameSetupUpdate", "NiceTrainer_ESP_Loop", function(t, dt)
        if not NiceTrainer.Settings.esp_enabled then
            if NiceTrainer._esp_was_enabled then
                ESP.CleanAllContoursOnLevelLoad()
                NiceTrainer._esp_was_enabled = false
            elseif NiceTrainer._esp_needs_cleanup then
                -- Wait until the player is actually in the game (not in the loadout/ready screen)
                local player_in_game = managers.player and managers.player:player_unit() and alive(managers.player:player_unit())
                if player_in_game then
                    NiceTrainer._esp_cleanup_timer = (NiceTrainer._esp_cleanup_timer or 0) + dt
                    -- Wait 1 second AFTER the player actually spawns in to ensure all mission scripts fired
                    if NiceTrainer._esp_cleanup_timer > 1.0 then
                        ESP.CleanAllContoursOnLevelLoad()
                        NiceTrainer._esp_needs_cleanup = false
                        NiceTrainer._esp_cleanup_timer = 0
                    end
                end
            end
            return
        end

        NiceTrainer._esp_was_enabled = true

        -- Draw 3D Camera Detection Vision Cones every frame
        if NiceTrainer.Settings.esp_camera_cones and NiceTrainer:IsInHeist() then
            ESP.DrawSecurityCameraCones(t, "esp")
        end

        NiceTrainer._esp_acc = (NiceTrainer._esp_acc or 0) + dt
        if NiceTrainer._esp_acc >= (NiceTrainer.Settings.esp_refresh_rate or 1.0) then
            NiceTrainer._esp_acc = 0
            local ok_apply, err_apply = pcall(ESP.ApplyESP)
            if not ok_apply then
                ESP._logged_errors = ESP._logged_errors or {}
                local msg = tostring(err_apply)
                if not ESP._logged_errors[msg] then
                    ESP._logged_errors[msg] = true
                    log("[NiceTrainer ESP] ApplyESP error: " .. msg)
                end
            end
        end
    end)
    
    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ESP_ResetMarkerWS", function()
        NiceTrainer._marker_ws         = nil
        NiceTrainer._marker_panel      = nil
        NiceTrainer._esp_markers       = {}
        NiceTrainer._active_ammo_clips = {}
        NiceTrainer._cam_settings      = {}
        NiceTrainer._cam_runtime       = {}
        NiceTrainer._spy_cameras       = {}
        NiceTrainer._spy_cam_runtime   = {}
        ESP._cached_static_props           = nil
        ESP.CleanAllContoursOnLevelLoad()
    end)

    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ESP_AutoDisable", function()
        NiceTrainer.Settings.esp_enabled = false
        ESP.CleanAllContoursOnLevelLoad()
        NiceTrainer._esp_needs_cleanup = true
        NiceTrainer._esp_cleanup_timer = 0
    end)
    
    local function HookInteractionManager()
        if not ObjectInteractionManager or NiceTrainer._esp_interaction_hooked then
            return
        end
        NiceTrainer._esp_interaction_hooked = true
        Hooks:PostHook(ObjectInteractionManager, "add_unit", "NiceTrainer_ESP_ClearNewUnits", function(self, unit)
            if alive(unit) then
                if NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled then
                    local is_wl, cat = ESP.is_whitelisted_always_visible(unit)
                    if is_wl and NiceTrainer.Settings["esp_show_" .. cat] then
                        ESP.SetWhitelistedContour(unit, cat)
                    end
                else
                    pcall(ESP.SetMaterialHighlight, unit, false)
                    if unit:contour() then
                        for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(unit:contour().remove, unit:contour(), ct) end
                        for _, ct in ipairs(ESP.NPC_KEYS) do pcall(unit:contour().remove, unit:contour(), ct) end
                    end
                end
            end
        end)
    end
    local function HookInteractionContour()
        if not _G.BaseInteractionExt or NiceTrainer._esp_base_int_hooked then return end
        NiceTrainer._esp_base_int_hooked = true

        Hooks:PostHook(BaseInteractionExt, "set_contour", "NiceTrainer_ESP_ContourOverride", function(self, color, opacity)
            if not (alive(self._unit) and self._materials) then return end
            local u_key = self._unit:key()

            if NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled then
                local is_wl, cat = ESP.is_whitelisted_always_visible(self._unit)
                if is_wl and NiceTrainer.Settings["esp_show_" .. cat] then
                    local c = (NiceTrainer.Settings and NiceTrainer.Settings["esp_color_" .. cat]) or Color.white
                    ESP.SetMaterialHighlight(self._unit, true, c)
                    return
                end

                if ESP._highlighted_units[u_key] then
                    local item_cat, _ = ESP.ClassifyInteractive(self._unit)
                    if not item_cat and self._unit:base() and (self._unit:base().is_security_camera or self._unit:base().is_spy_camera) then
                        item_cat = "cameras"
                    end
                    if item_cat and NiceTrainer.Settings["esp_show_" .. item_cat] then
                        local c = NiceTrainer.Settings["esp_color_" .. item_cat]
                        if c then
                            ESP.SetMaterialHighlight(self._unit, true, c)
                            return
                        end
                    end
                end

                local int_disabled = (self.disabled and self:disabled()) or self._disabled
                local is_goat = ESP.is_actual_goat(self._unit)

                if not int_disabled or is_goat then
                    -- 1. Fast check for NPC
                    local is_dead = ESP.is_unit_dead(self._unit)
                    if not is_dead and not ESP.IsFriendlyUnit(self._unit) then
                        local has_keycard, _ = ESP.UnitHasKeycard(self._unit)
                        local npc_cat = has_keycard and "vips" or ESP.ClassifyNPC(self._unit)
                        if npc_cat and NiceTrainer.Settings["esp_show_" .. npc_cat] then
                            local c = NiceTrainer.Settings["esp_color_" .. npc_cat]
                            if c then
                                ESP.SetMaterialHighlight(self._unit, true, c)
                                return
                            end
                        end
                    end

                    -- 2. Fast check for Interactive Item or Camera
                    local item_cat, _ = ESP.ClassifyInteractive(self._unit)
                    if not item_cat and self._unit:base() and (self._unit:base().is_security_camera or self._unit:base().is_spy_camera) then
                        item_cat = "cameras"
                    end
                    if item_cat and NiceTrainer.Settings["esp_show_" .. item_cat] then
                        local c = NiceTrainer.Settings["esp_color_" .. item_cat]
                        if c then
                            ESP.SetMaterialHighlight(self._unit, true, c)
                            return
                        end
                    end
                end
            end
        end)

        Hooks:PostHook(BaseInteractionExt, "interact", "NiceTrainer_ESP_Interact", function(self, player)
            if alive(self._unit) then
                local is_disabled = (self.disabled and self:disabled()) or self._disabled or (self._active == false)
                if is_disabled then
                    local u_key = self._unit:key()
                    ESP._highlighted_units[u_key] = nil
                    local marker = NiceTrainer._esp_markers_map and NiceTrainer._esp_markers_map[u_key]
                    if marker and alive(marker.panel) then
                        marker.panel:parent():remove(marker.panel)
                        NiceTrainer._esp_markers_map[u_key] = nil
                    end
                    if self._unit:contour() and self._nt_esp_contour then
                        for _, ct in ipairs(ESP.ALL_ITEM_KEYS) do pcall(self._unit:contour().remove, self._unit:contour(), ct) end
                        self._nt_esp_contour = nil
                    end
                    ESP.SetMaterialHighlight(self._unit, false)
                end
            end
        end)
    end
    local function HookAmmoClips()
        if NiceTrainer._esp_ammoclip_hooked then return end
        NiceTrainer._esp_ammoclip_hooked = true
        NiceTrainer._active_ammo_clips = NiceTrainer._active_ammo_clips or {}

        if _G.AmmoClip then
            Hooks:PostHook(AmmoClip, "init", "NiceTrainer_ESP_AmmoClipInit", function(self, unit)
                if alive(unit) then
                    NiceTrainer._active_ammo_clips[unit:key()] = unit
                    if NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled and NiceTrainer.Settings.esp_show_mission_deployables then
                        local ammo_col = NiceTrainer.Settings.esp_color_mission_deployables
                        if ammo_col then
                            ESP.SetMaterialHighlight(unit, true, ammo_col)
                        end
                    end
                end
            end)

            Hooks:PostHook(AmmoClip, "_pickup", "NiceTrainer_ESP_AmmoClipPickup", function(self, unit)
                if alive(self._unit) then
                    local u_key = self._unit:key()
                    ESP._highlighted_units[u_key] = nil
                    NiceTrainer._active_ammo_clips[u_key] = nil
                    if self._unit:contour() and self._unit:base() and self._unit:base()._nt_esp_contour then
                        pcall(self._unit:contour().remove, self._unit:contour(), "nt_esp_mission_deployables")
                        self._unit:base()._nt_esp_contour = nil
                    end
                    ESP.SetMaterialHighlight(self._unit, false)
                end
            end)

            Hooks:PostHook(AmmoClip, "consume", "NiceTrainer_ESP_AmmoClipConsume", function(self)
                if alive(self._unit) then
                    local u_key = self._unit:key()
                    ESP._highlighted_units[u_key] = nil
                    NiceTrainer._active_ammo_clips[u_key] = nil
                    if self._unit:contour() and self._unit:base() and self._unit:base()._nt_esp_contour then
                        pcall(self._unit:contour().remove, self._unit:contour(), "nt_esp_mission_deployables")
                        self._unit:base()._nt_esp_contour = nil
                    end
                    ESP.SetMaterialHighlight(self._unit, false)
                end
            end)

            Hooks:PostHook(AmmoClip, "destroy", "NiceTrainer_ESP_AmmoClipDestroy", function(self)
                if alive(self._unit) then
                    NiceTrainer._active_ammo_clips[self._unit:key()] = nil
                end
            end)
        end
    end
    local function HookDeathCleaners()
        if NiceTrainer._esp_death_hooked then return end
        NiceTrainer._esp_death_hooked = true

        if _G.CopDamage then
            Hooks:PostHook(CopDamage, "die", "NiceTrainer_ESP_CopDie", function(self, variant)
                ESP.clean_unit_esp(self._unit)
            end)
            Hooks:PostHook(CopDamage, "_on_death", "NiceTrainer_ESP_CopOnDeath", function(self)
                ESP.clean_unit_esp(self._unit)
            end)
        end
        if _G.CivilianDamage then
            Hooks:PostHook(CivilianDamage, "die", "NiceTrainer_ESP_CivDie", function(self, variant)
                ESP.clean_unit_esp(self._unit)
            end)
            Hooks:PostHook(CivilianDamage, "_on_death", "NiceTrainer_ESP_CivOnDeath", function(self)
                ESP.clean_unit_esp(self._unit)
            end)
        end
        if _G.HuskCopDamage then
            Hooks:PostHook(HuskCopDamage, "die", "NiceTrainer_ESP_HuskCopDie", function(self, variant)
                ESP.clean_unit_esp(self._unit)
            end)
            Hooks:PostHook(HuskCopDamage, "_on_death", "NiceTrainer_ESP_HuskCopOnDeath", function(self)
                ESP.clean_unit_esp(self._unit)
            end)
        end
        if _G.HuskCivilianDamage then
            Hooks:PostHook(HuskCivilianDamage, "die", "NiceTrainer_ESP_HuskCivDie", function(self, variant)
                ESP.clean_unit_esp(self._unit)
            end)
            Hooks:PostHook(HuskCivilianDamage, "_on_death", "NiceTrainer_ESP_HuskCivOnDeath", function(self)
                ESP.clean_unit_esp(self._unit)
            end)
        end
        if _G.EnemyManager then
            Hooks:PostHook(EnemyManager, "on_enemy_died", "NiceTrainer_ESP_EnemyDied", function(self, unit, damage_info)
                ESP.clean_unit_esp(unit)
            end)
            Hooks:PostHook(EnemyManager, "on_civilian_died", "NiceTrainer_ESP_CivilianDied", function(self, unit, damage_info)
                ESP.clean_unit_esp(unit)
            end)
        end
    end
    local function HookPortalSystem()
        if NiceTrainer._esp_portal_hooked then return end
        NiceTrainer._esp_portal_hooked = true

        local function on_portal_update(self, t, dt)
            if NiceTrainer.Settings and NiceTrainer.Settings.esp_enabled and ESP._highlighted_units then
                for u_key, u in pairs(ESP._highlighted_units) do
                    if alive(u) then
                        local ud = u:unit_data()
                        if ud then ud.ignore_portal = true end
                        if not u:visible() then
                            pcall(u.set_visible, u, true)
                        end
                    end
                end
            end
        end

        if _G.PortalUnitGroup then
            Hooks:PostHook(PortalUnitGroup, "update", "NiceTrainer_ESP_PortalBypass", on_portal_update)
        end
        if _G.CorePortalUnitGroup and _G.CorePortalUnitGroup ~= _G.PortalUnitGroup then
            Hooks:PostHook(CorePortalUnitGroup, "update", "NiceTrainer_ESP_CorePortalBypass", on_portal_update)
        end
    end
    HookInteractionManager()
    HookInteractionContour()
    HookAmmoClips()
    HookDeathCleaners()
    HookPortalSystem()

    Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_ESP_HookInteraction", function()
        HookInteractionManager()
        HookInteractionContour()
        HookAmmoClips()
        HookDeathCleaners()
        HookPortalSystem()
    end)
    
    NiceTrainer._esp_hook_added = true
end
