-- Unlocks & Protection Module for NiceTrainer
-- Handles Selective DLC Unlocker, Anti-Cheat Outfit Spoofing, Skin Unlocker,
-- and the Anti-Cheat Security Audit (AntiCheatChecker)

local DLC_DISPLAY_NAMES = {
    akm4_pack = "The Butcher's AK/CAR Mod Pack",
    alienware_alpha = "Alienware Alpha Mask Pack",
    alienware_alpha_promo = "Alienware Alpha Mauler",
    arena = "The Alesso Heist",
    armored_transport = "Armored Transport",
    bbq = "The Butcher's BBQ Pack",
    berry = "The Point Break Heists",
    big_bank = "The Big Bank Heist",
    bobblehead = "Bobblehead DLC",
    born = "The Biker Heist",
    bsides_soundtrack = "The OVERKILL B-Sides Soundtrack",
    career_criminal_edition = "Career Criminal Content",
    character_pack_clover = "Clover Character Pack",
    character_pack_dragan = "Dragan Character Pack",
    character_pack_sokol = "Sokol Character Pack",
    complete_overkill_pack = "The COMPLETELY OVERKILL Pack",
    dbd_clan = "Dead by Daylight (Steam Group)",
    dbd_deluxe = "Dead by Daylight: Deluxe Edition",
    dragon = "Yakuza Character Pack",
    e3_s15a = "The Jack Mask Pack",
    e3_s15b = "The Queen Mask Pack",
    e3_s15c = "The King Mask Pack",
    e3_s15d = "The Joker Mask Pack",
    full_game = "PAYDAY 2",
    gage_pack = "Gage Weapon Pack #01",
    gage_pack_assault = "Gage Assault Pack",
    gage_pack_historical = "Gage Historical Pack",
    gage_pack_jobs = "Gage Mod Courier",
    gage_pack_lmg = "Gage Weapon Pack #02",
    gage_pack_shotgun = "Gage Shotgun Pack",
    gage_pack_snp = "Gage Sniper Pack",
    hl_miami = "Hotline Miami",
    hlm2 = "Hotline Miami 2",
    hlm2_aus = "Jacket Character Pack",
    hlm2_deluxe = "Hotline Miami 2: Special Edition",
    hlm_game = "Hotline Miami",
    hope_diamond = "The Diamond Heist",
    humble_pack2 = "Humble Mask Pack 2",
    humble_pack3 = "Humble Mask Pack 3",
    humble_pack4 = "Humble Mask Pack 4",
    jigg = "Humble Mask Pack 5",
    kenaz = "The Golden Grin Casino Heist",
    opera = "Sydney Character Pack",
    overkill_pack = "The OVERKILL Pack",
    pal = "The Wolf Pack",
    pd2_clan = "PAYDAY 2 (Steam Group)",
    pdcon_2015 = "The PAYDAYCON 2015 Mask Pack",
    pdth_soundtrack = "PAYDAY: The Heist Soundtrack",
    peta = "The Goat Simulator Heist",
    preorder = "Pre-order Bonus",
    solus_clan = "The Solus Project",
    soundtrack = "The Official Soundtrack",
    speedrunners = "SpeedRunners",
    steel = "Gage Chivalry Pack",
    the_bomb = "The Bomb Heists",
    turtles = "Gage Ninja Pack",
    twitch_pack = "Humble Mask Pack",
    wild = "The Biker Character Pack",
    pim = "John Wick Weapon Pack",
    sparkle = "Gage Russian Weapon Pack",
    friend = "Scarface Character Pack",
    chico = "Scarface Heist",
    swm = "John Wick Heists",
    spa = "Gage Spec Ops Pack",
    grunt = "Tailor Pack 1",
    joy = "Joy Character Pack",
    hvh = "Border Crossing Heist",
    wwh = "White House Heist",
    mex = "San Martín Bank Heist",
    bex = "Breakfast in Tijuana Heist",
    fex = "Buluc's Mansion Heist",
    pex = "Dragon Heist",
    tag = "Jacket Character Pack (Digital Special)",
    sand = "The Ukrainian Prisoner Heist",
    chas = "Black Cat Heist",
    sand2 = "Mountain Master Heist",
    trai = "Lost in Transit Heist",
    corp = "Hostile Takeover Heist",
    deep = "Crude Awakening Heist"
}

local function get_dlc_display_name(name)
    if DLC_DISPLAY_NAMES[name] then return DLC_DISPLAY_NAMES[name] end
    if managers.localization and managers.localization:exists("bm_global_value_" .. name) then
        local loc = managers.localization:text("bm_global_value_" .. name)
        if loc and loc ~= "" then return loc end
    end
    -- Pretty title case
    local formatted = name:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return formatted
end

local function get_all_dlc_entries()
    local list = {}
    local seen = {}
    if Global.dlc_manager and Global.dlc_manager.all_dlc_data then
        for name, _ in pairs(Global.dlc_manager.all_dlc_data) do
            seen[name] = true
            table.insert(list, { name = name, title = get_dlc_display_name(name) })
        end
    end
    for name, _ in pairs(DLC_DISPLAY_NAMES) do
        if not seen[name] then
            seen[name] = true
            table.insert(list, { name = name, title = get_dlc_display_name(name) })
        end
    end
    table.sort(list, function(a, b) return a.title < b.title end)
    return list
end

local function applyDlcUnlockState(state)
    if not (Global.dlc_manager and Global.dlc_manager.all_dlc_data) then return end
    local unlocked = NiceTrainer.Settings.unlocked_dlcs
    for name, data in pairs(Global.dlc_manager.all_dlc_data) do
        data._dlc_name = name
        if state then
            local is_unlocked = true
            if unlocked then
                is_unlocked = unlocked[name] == true
            end
            if is_unlocked then
                data.verified = true
            end
        end
    end
end

-- ─── Selective DLC Settings Modal ─────────────────────────────────────────────

local DLC_MODAL_W = 580
local DLC_MODAL_H = 620
local DLC_ROW_H   = 38

local function ShowSelectiveDLCSettings()
    local dlc_list = get_all_dlc_entries()

    NiceTrainer:ShowCustomModal("Selective DLC Unlocker", DLC_MODAL_W, DLC_MODAL_H, function(m)
        local top_modal = NiceTrainer._modals_stack[#NiceTrainer._modals_stack]
        if not top_modal then return end

        -- Subtitle / instructions
        m:text({
            text = "Select which DLCs to unlock. Unchecked DLCs will remain locked.",
            font = "fonts/font_medium_shadow_mf", font_size = 14,
            color = Color(0.7, 0.7, 0.7), x = 16, y = 52, w = DLC_MODAL_W - 32, layer = 2
        })

        -- Game Restart Warning Banner
        local warn_panel = m:panel({ x = 16, y = 72, w = DLC_MODAL_W - 32, h = 26, layer = 2 })
        warn_panel:rect({ color = Color(1, 0.7, 0.1), alpha = 0.12, layer = 0 })
        warn_panel:rect({ color = Color(1, 0.7, 0.1), alpha = 0.6, w = 3, layer = 1 })
        warn_panel:text({
            text = "⚠ RESTART REQUIRED: Restart the game for newly unlocked DLCs to take full effect!",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            color = Color(1, 0.8, 0.25), x = 10, vertical = "center", layer = 2
        })

        -- 1. Anti-Cheat Outfit Spoof Checkbox
        local spoof_y = 104
        local spoof_panel = m:panel({ x = 16, y = spoof_y, w = DLC_MODAL_W - 32, h = 34, layer = 2 })
        local spoof_bg = spoof_panel:rect({ color = Color.white, alpha = 0.04, layer = 0 })
        local spoof_state = NiceTrainer.Settings.spoof_equipment == true

        spoof_panel:rect({ color = Color.white, alpha = 0.1, x = 6, y = 7, w = 20, h = 20, layer = 1 })
        local spoof_cb = spoof_panel:rect({ color = Color(0.2, 0.8, 0.4), x = 10, y = 11, w = 12, h = 12, visible = spoof_state, layer = 2 })

        local spoof_txt = spoof_panel:text({
            text = "Anti-Cheat Outfit Spoof (Recommended: masks DLC weapons, masks, skins & suits in network sync)",
            font = "fonts/font_medium_shadow_mf", font_size = 13,
            color = spoof_state and Color(0.3, 1, 0.5) or Color(0.85, 0.85, 0.85),
            x = 34, vertical = "center", layer = 1
        })

        table.insert(top_modal.elements, {
            panel = spoof_panel,
            inside = function(self, mx, my) return spoof_panel:inside(mx, my) end,
            on_hover = function(self, hovered) spoof_bg:set_alpha(hovered and 0.12 or 0.04) end,
            on_click = function(self)
                local ns = not (NiceTrainer.Settings.spoof_equipment == true)
                NiceTrainer.Settings.spoof_equipment = ns
                NiceTrainer:Save()
                if alive(spoof_cb) then spoof_cb:set_visible(ns) end
                if alive(spoof_txt) then spoof_txt:set_color(ns and Color(0.3, 1, 0.5) or Color(0.85, 0.85, 0.85)) end
                NiceTrainer:Toast("Outfit Spoof: " .. (ns and "ON" or "OFF"))
                if NiceTrainer.UpdateAntiCheatWarning then NiceTrainer.UpdateAntiCheatWarning() end
            end
        })

        -- Buttons row: [Select All] [Deselect All]
        local btn_w, btn_h = 130, 26
        local btn_y = 146
        local sel_btn = m:panel({ x = 16, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local sel_bg = sel_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        sel_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        sel_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w - 1, w = 1, layer = 1 })
        sel_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        sel_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        sel_btn:text({ text = "Select All", font = "fonts/font_medium_shadow_mf", font_size = 16, align = "center", vertical = "center", color = Color.white, layer = 2 })

        local desel_btn = m:panel({ x = 16 + btn_w + 10, y = btn_y, w = btn_w, h = btn_h, layer = 2 })
        local desel_bg = desel_btn:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.2, layer = 0 })
        desel_btn:rect({ color = Color(0.2, 0.6, 1.0), w = 1, layer = 1 })
        desel_btn:rect({ color = Color(0.2, 0.6, 1.0), x = btn_w - 1, w = 1, layer = 1 })
        desel_btn:rect({ color = Color(0.2, 0.6, 1.0), h = 1, layer = 1 })
        desel_btn:rect({ color = Color(0.2, 0.6, 1.0), y = btn_h - 1, h = 1, layer = 1 })
        desel_btn:text({ text = "Deselect All", font = "fonts/font_medium_shadow_mf", font_size = 16, align = "center", vertical = "center", color = Color.white, layer = 2 })

        local sep_y = 178
        m:rect({ color = Color(0.2, 0.6, 1.0), alpha = 0.35, x = 16, y = sep_y, w = DLC_MODAL_W - 32, h = 1, layer = 2 })

        -- Scrollable DLC list
        local scroll_top  = sep_y + 8
        local scroll_wrap = m:panel({ x = 0, y = scroll_top, w = DLC_MODAL_W, h = DLC_MODAL_H - scroll_top - 8, layer = 2 })

        local canvas_h = 8 + (#dlc_list * (DLC_ROW_H + 4))
        local canvas   = scroll_wrap:panel({ x = 0, y = 0, w = DLC_MODAL_W, h = math.max(canvas_h, DLC_ROW_H), layer = 1 })
        top_modal.scroll = { wrapper = scroll_wrap, canvas = canvas }

        local ROW_W = DLC_MODAL_W - 16
        local y = 8
        local row_checkboxes = {}

        if #dlc_list == 0 then
            canvas:text({
                text = "No DLC data loaded yet. Enter Crime.net or inventory first.",
                font = "fonts/font_medium_shadow_mf", font_size = 16,
                color = Color(0.6, 0.6, 0.6), x = 18, y = y, layer = 2
            })
        end

        for _, dlc in ipairs(dlc_list) do
            local dlc_name = dlc.name
            local dlc_title = dlc.title

            local unlocked = NiceTrainer.Settings.unlocked_dlcs or {}
            local state = true
            if NiceTrainer.Settings.unlocked_dlcs ~= nil then
                state = unlocked[dlc_name] == true
            end

            local row    = canvas:panel({ x = 8, y = y, w = ROW_W, h = DLC_ROW_H, layer = 2 })
            local row_bg = row:rect({ color = Color.white, alpha = 0.04, layer = 0 })

            -- Checkbox
            row:rect({ color = Color.white, alpha = 0.1, x = 8, y = 9, w = 20, h = 20, layer = 1 })
            local cb = row:rect({ color = Color(0.2, 0.6, 1.0), x = 12, y = 13, w = 12, h = 12, visible = state, layer = 2 })
            row_checkboxes[dlc_name] = cb

            -- DLC Name
            row:text({
                text = dlc_title,
                font = "fonts/font_medium_shadow_mf", font_size = 17,
                x = 36, vertical = "center", color = Color(0.9, 0.9, 0.9), layer = 1
            })

            -- Internal DLC Key
            row:text({
                text = dlc_name,
                font = "fonts/font_medium_shadow_mf", font_size = 13,
                x = 0, y = 0, w = ROW_W - 14, h = DLC_ROW_H,
                align = "right", vertical = "center", color = Color(0.45, 0.45, 0.45), layer = 1
            })

            local dn = dlc_name
            table.insert(top_modal.elements, {
                panel = row,
                inside = function(self, mx, my)
                    return scroll_wrap:inside(mx, my) and row:inside(mx, my)
                end,
                on_hover = function(self, hovered)
                    row_bg:set_alpha(hovered and 0.12 or 0.04)
                end,
                on_click = function(self, mx, my)
                    if not NiceTrainer.Settings.unlocked_dlcs then
                        NiceTrainer.Settings.unlocked_dlcs = {}
                        for _, item in ipairs(dlc_list) do
                            NiceTrainer.Settings.unlocked_dlcs[item.name] = true
                        end
                    end
                    local nstate = not (NiceTrainer.Settings.unlocked_dlcs[dn] == true)
                    NiceTrainer.Settings.unlocked_dlcs[dn] = nstate
                    NiceTrainer:Save()
                    if alive(cb) then cb:set_visible(nstate) end
                    if Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[dn] then
                        Global.dlc_manager.all_dlc_data[dn]._dlc_name = dn
                        if NiceTrainer.Settings.dlc_unlocker then
                            Global.dlc_manager.all_dlc_data[dn].verified = nstate
                        end
                    end
                end
            })

            y = y + DLC_ROW_H + 4
        end

        -- Select All Click
        table.insert(top_modal.elements, {
            panel = sel_btn,
            inside = function(self, mx, my) return sel_btn:inside(mx, my) end,
            on_hover = function(self, hovered) sel_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self)
                NiceTrainer.Settings.unlocked_dlcs = {}
                for _, dlc in ipairs(dlc_list) do
                    NiceTrainer.Settings.unlocked_dlcs[dlc.name] = true
                    local box = row_checkboxes[dlc.name]
                    if alive(box) then box:set_visible(true) end
                    if Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[dlc.name] then
                        Global.dlc_manager.all_dlc_data[dlc.name]._dlc_name = dlc.name
                        if NiceTrainer.Settings.dlc_unlocker then
                            Global.dlc_manager.all_dlc_data[dlc.name].verified = true
                        end
                    end
                end
                NiceTrainer:Save()
                NiceTrainer:Toast("All DLCs Selected")
            end
        })

        -- Deselect All Click
        table.insert(top_modal.elements, {
            panel = desel_btn,
            inside = function(self, mx, my) return desel_btn:inside(mx, my) end,
            on_hover = function(self, hovered) desel_bg:set_alpha(hovered and 0.4 or 0.2) end,
            on_click = function(self)
                NiceTrainer.Settings.unlocked_dlcs = {}
                for _, dlc in ipairs(dlc_list) do
                    NiceTrainer.Settings.unlocked_dlcs[dlc.name] = false
                    local box = row_checkboxes[dlc.name]
                    if alive(box) then box:set_visible(false) end
                    if Global.dlc_manager and Global.dlc_manager.all_dlc_data and Global.dlc_manager.all_dlc_data[dlc.name] then
                        Global.dlc_manager.all_dlc_data[dlc.name]._dlc_name = dlc.name
                        if NiceTrainer.Settings.dlc_unlocker then
                            Global.dlc_manager.all_dlc_data[dlc.name].verified = false
                        end
                    end
                end
                NiceTrainer:Save()
                NiceTrainer:Toast("All DLCs Deselected")
            end
        })
    end)
end

-- Register DLC Unlocker with Confirmation Dialog and Settings Modal
NiceTrainer:RegisterAction("Account", {
    type              = "toggle_settings",
    category          = "Unlockers & Protection",
    no_bind           = true,
    id                = "dlc_unlocker",
    badge             = "risk",
    text              = "DLC Unlocker",
    tooltip           = "Unlocks DLCs. Click [...] to choose specific DLCs and configure Outfit Spoof.",
    default           = false,
    callback          = function(state)
        if state then
            if NiceTrainer.Settings.spoof_equipment == true then
                applyDlcUnlockState(true)
            else
                -- Open security confirmation dialog if outfit spoof is disabled
                NiceTrainer:ShowConfirmDialog(
                    "Security Notice - DLC Unlocker",
                    "NOTICE: Newly unlocked DLC packages and heists require a GAME RESTART to take full effect in your inventory and Crime.net!\n\nWARNING: Anti-Cheat Outfit Spoof is currently DISABLED. If you join a multiplayer heist with unowned DLC weapons, masks or cosmetics, remote host anti-cheat may flag you as CHEATER.\n\nEnable Anti-Cheat Outfit Spoof to mask your loadout safely in multiplayer sync:",
                    {
                        {
                            text = "Enable Outfit Spoof (Recommended)",
                            color = Color(0.2, 0.8, 0.4),
                            callback = function()
                                NiceTrainer.Settings.spoof_equipment = true
                                NiceTrainer:Save()
                                applyDlcUnlockState(true)
                                NiceTrainer:Toast("DLC Unlocker & Outfit Spoof Enabled! (Restart game to finalize)")
                                if NiceTrainer.UpdateAntiCheatWarning then NiceTrainer.UpdateAntiCheatWarning() end
                            end
                        },
                        {
                            text = "No Spoof (Risky)",
                            color = Color(0.9, 0.35, 0.35),
                            callback = function()
                                applyDlcUnlockState(true)
                                NiceTrainer:Toast("DLC Unlocker Enabled! (Restart game to finalize)")
                                if NiceTrainer.UpdateAntiCheatWarning then NiceTrainer.UpdateAntiCheatWarning() end
                            end
                        },
                        {
                            text = "Cancel",
                            color = Color(0.6, 0.6, 0.6),
                            callback = function()
                                NiceTrainer:SetToggleState("dlc_unlocker", false)
                                applyDlcUnlockState(false)
                                NiceTrainer:Toast("DLC Unlocker activation canceled.")
                                if NiceTrainer.UpdateAntiCheatWarning then NiceTrainer.UpdateAntiCheatWarning() end
                            end
                        }
                    }
                )
            end
        else
            applyDlcUnlockState(false)
        end
        if NiceTrainer.UpdateAntiCheatWarning then NiceTrainer.UpdateAntiCheatWarning() end
    end,
    settings_callback = ShowSelectiveDLCSettings
})


Hooks:Add('BaseNetworkSessionOnLoadComplete', 'NiceTrainer_DLCUnlocker_OnLoad', function()
    if NiceTrainer.Settings.dlc_unlocker then
        applyDlcUnlockState(true)
    end
end)
