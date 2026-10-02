-- ─── Team Fast Actions & Collective Spawns ────────────────────────────────────
-- Quick team rescues, group refuels, bag drops and deployable drops.

local BAG_TYPES = {
    { text = "Money",      carry_id = "money"      },
    { text = "Gold",       carry_id = "gold"       },
    { text = "Diamonds",   carry_id = "diamonds"   },
    { text = "Coke",       carry_id = "coke"       },
    { text = "Weapons",    carry_id = "weapon"     },
    { text = "Painting",   carry_id = "painting"   },
    { text = "Meth",       carry_id = "meth"       },
    { text = "Artifact",   carry_id = "artifact"   },
    { text = "Server",     carry_id = "server"     },
}

local DEPLOYABLE_TYPES = {
    { text = "Ammo Bag",    id = "ammo"     },
    { text = "Doctor Bag",  id = "medic"    },
    { text = "Body Bags",   id = "bodybag"  },
    { text = "ECM Jammer",  id = "ecm"      },
    { text = "Trip Mine",   id = "trip_mine"},
    { text = "Sentry Gun",  id = "sentry"   },
}

local function for_each_teammate(fn)
    local session = managers.network and managers.network:session()
    if not session then return 0 end
    local count = 0
    for _, peer in pairs(session:peers()) do
        local unit = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        if alive(unit) then
            pcall(fn, peer, unit)
            count = count + 1
        end
    end
    return count
end

local function revive_all_teammates()
    local count = 0
    local session = managers.network and managers.network:session()
    local local_player = managers.player and managers.player:player_unit()
    local local_peer = session and session:local_peer()
    if not session then return end

    for _, peer in pairs(session:peers()) do
        local unit = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        if alive(unit) then
            pcall(function()
                if Network:is_server() then
                    if unit:character_damage() and unit:character_damage().revive then
                        unit:character_damage():revive(true)
                    end
                    unit:network():send_to_unit({ "revive_player" })
                else
                    if unit:interaction() and unit:interaction():active() then
                        unit:interaction():interact(local_player)
                    end
                    if unit:movement() and unit:movement().on_revive_boost then
                        unit:movement():on_revive_boost()
                    end
                    if local_peer then
                        session:send_to_peers_synched("sync_teammate_helped_hint", 1, unit, local_peer:id())
                    end
                    if unit:character_damage() and unit:character_damage().revive then
                        unit:character_damage():revive(true)
                    end
                end
                count = count + 1
            end)
        end
    end

    if managers.criminals then
        for _, char in pairs(managers.criminals:characters()) do
            if char.data and char.data.ai and alive(char.unit) then
                pcall(function()
                    local u = char.unit
                    if u:character_damage() and u:character_damage():need_revive() then
                        if Network:is_server() then
                            u:character_damage():revive(local_player)
                        else
                            if u:interaction() and u:interaction():active() then
                                u:interaction():interact(local_player)
                            end
                            u:character_damage():revive(local_player)
                        end
                        count = count + 1
                    end
                end)
            end
        end
    end

    NiceTrainer:Toast("Revived " .. count .. " teammate(s)!")
end

local function release_all_from_custody()
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local count = 0
    local session = managers.network and managers.network:session()
    if not session then return end

    for _, peer in pairs(session:peers()) do
        pcall(function()
            if _G.IngameWaitingForRespawnState and IngameWaitingForRespawnState.request_player_spawn then
                IngameWaitingForRespawnState.request_player_spawn(peer:id())
                count = count + 1
            end
        end)
    end
    NiceTrainer:Toast("Requested respawn for all teammates in custody!")
end

local function teleport_all_to_me()
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local player = managers.player and managers.player:player_unit()
    if not alive(player) then
        NiceTrainer:Toast("Player unit not found.")
        return
    end
    local my_pos = player:position() + Vector3(0, 0, 25)
    local count = for_each_teammate(function(peer, unit)
        pcall(function()
            unit:movement():set_position(my_pos)
            unit:set_position(my_pos)
        end)
    end)
    NiceTrainer:Toast("Teleported " .. count .. " teammate(s) to you!")
end

local function refill_all_health_and_ammo()
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local count = for_each_teammate(function(peer, unit)
        pcall(function()
            if unit:base() and unit:base().replenish then unit:base():replenish() end
            if unit:character_damage() and unit:character_damage().replenish then unit:character_damage():replenish() end
            unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 })
        end)
    end)
    NiceTrainer:Toast("Refilled health and ammo for " .. count .. " teammate(s)!")
end

local function drop_bags_on_all(bag_idx)
    local bag_data = BAG_TYPES[bag_idx] or BAG_TYPES[1]
    local carry_id = bag_data.carry_id
    if not (tweak_data.carry and tweak_data.carry[carry_id]) then
        carry_id = "money"
    end

    local count = 0
    local session = managers.network and managers.network:session()
    if not session then return end

    -- Drop on all peers + local player
    local function drop_on_unit(unit)
        if not alive(unit) then return end
        local val = 1
        pcall(function() val = managers.money:get_bag_value(carry_id) end)
        local pos = unit:position() + Vector3(0, 0, 80)
        local rot = unit:rotation()
        local dir = Vector3(0, 0, 40)

        if Network:is_server() then
            managers.player:server_drop_carry(
                carry_id, val, true, true, 1,
                pos, rot, dir, 0, nil, nil
            )
        else
            -- Client: Request host to drop carry bag at target location
            pcall(function()
                session:send_to_host(
                    "server_drop_carry",
                    carry_id, val, true, false, 1,
                    pos, rot, dir, 0, nil
                )
            end)
        end
        count = count + 1
    end

    for _, peer in pairs(session:peers()) do
        local u = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        drop_on_unit(u)
    end
    drop_on_unit(managers.player and managers.player:player_unit())

    NiceTrainer:Toast("Dropped '" .. bag_data.text .. "' bags on " .. count .. " player(s)!")
end

local function drop_deployables_on_all(dep_idx)
    local dep = DEPLOYABLE_TYPES[dep_idx] or DEPLOYABLE_TYPES[1]
    local kind = dep.id

    local session = managers.network and managers.network:session()
    if not session then return end
    local local_peer = session:local_peer()
    local local_player = managers.player and managers.player:player_unit()

    local count = 0
    local function spawn_for_unit(unit)
        if not alive(unit) then return end
        local pos, rot = unit:position(), unit:rotation()
        pcall(function()
            if Network:is_server() then
                -- Host direct spawning
                if kind == "ammo" and AmmoBagBase then
                    AmmoBagBase.spawn(pos, rot, 1)
                elseif kind == "medic" and DoctorBagBase then
                    DoctorBagBase.spawn(pos, rot, 1)
                elseif kind == "bodybag" and BodyBagsBagBase then
                    BodyBagsBagBase.spawn(pos, rot, 1)
                elseif kind == "ecm" and ECMJammerBase and alive(local_player) then
                    local ecm = ECMJammerBase.spawn(pos, rot, 1, local_player, local_peer:id())
                    if alive(ecm) and ecm:base() then ecm:base():set_active(true) end
                elseif kind == "trip_mine" and TripMineBase and alive(local_player) then
                    local mine = TripMineBase.spawn(pos, rot, false, local_peer:id())
                    if alive(mine) and mine:base() then mine:base():set_active(true, local_player) end
                elseif kind == "sentry" and SentryGunBase and alive(local_player) then
                    local sentry, spread, rotation = SentryGunBase.spawn(local_player, pos, rot, local_peer:id())
                    if alive(sentry) then
                        pcall(function() sentry:base():post_setup(1) end)
                        pcall(function()
                            session:send_to_peers("from_server_sentry_gun_place_result",
                                local_peer:id(), nil, sentry, rotation or 1, spread or 1, false, nil, 1)
                        end)
                    end
                end
            else
                -- Client network RPC deployment
                if kind == "ammo" then
                    session:send_to_host("place_deployable_bag", "AmmoBagBase", pos, rot, 1)
                elseif kind == "medic" then
                    session:send_to_host("place_deployable_bag", "DoctorBagBase", pos, rot, 1)
                elseif kind == "bodybag" then
                    session:send_to_host("place_deployable_bag", "BodyBagsBagBase", pos, rot, 1)
                elseif kind == "ecm" then
                    session:send_to_host("request_place_ecm_jammer", pos, rot, 1)
                elseif kind == "trip_mine" then
                    session:send_to_host("attach_device", pos, rot, 1)
                elseif kind == "sentry" then
                    session:send_to_host("place_sentry_gun", pos, rot, 1, 1, 1)
                end
            end
        end)
        count = count + 1
    end

    for _, peer in pairs(session:peers()) do
        local u = peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
        spawn_for_unit(u)
    end
    spawn_for_unit(local_player)

    NiceTrainer:Toast("Deployed '" .. dep.text .. "' for " .. count .. " player(s)!")
end

-- Broadcast chat message to the team
local function broadcast_host_announcement()
    NiceTrainer:ShowCustomModal("Broadcast Message", 500, 220, function(p)
        local ms = NiceTrainer._modals_stack
        local modal_state = ms and ms[#ms]
        if not modal_state then return end

        local BG  = Color(0.2, 0.6, 1.0)
        local FNT = "fonts/font_medium_shadow_mf"

        p:text({
            text = "ENTER MESSAGE TO SEND TO TEAM CHAT:",
            font = FNT, font_size = 13,
            color = BG, x = 20, y = 60, layer = 2
        })

        local inp_p  = p:panel({ x = 20, y = 84, w = 460, h = 36, layer = 2 })
        local inp_bg = inp_p:rect({ color = BG, alpha = 0.15, layer = 0 })
        inp_p:rect({ color = BG, alpha = 0.5, w = 1, layer = 1 })
        inp_p:rect({ color = BG, alpha = 0.5, x = 459, w = 1, layer = 1 })
        inp_p:rect({ color = BG, alpha = 0.5, h = 1, layer = 1 })
        inp_p:rect({ color = BG, alpha = 0.5, y = 35, h = 1, layer = 1 })

        local msg_txt = inp_p:text({
            text = "Type announcement...",
            font = FNT, font_size = 16,
            color = Color(0.4, 0.4, 0.4), x = 10, vertical = "center", layer = 2
        })
        local is_ph = true

        table.insert(modal_state.elements, {
            panel = inp_p,
            inside = function(self, mx, my) return inp_p:inside(mx, my) end,
            on_hover = function(self, hovered) inp_bg:set_alpha(hovered and 0.3 or 0.15) end,
            on_click = function(self)
                if is_ph then
                    msg_txt:set_text("")
                    msg_txt:set_color(Color.white)
                    is_ph = false
                end
                if alive(NiceTrainer._panel) then
                    NiceTrainer._ws:connect_keyboard(Input:keyboard())
                    NiceTrainer._panel:key_press(function(o, k)
                        if k == Idstring("backspace") then
                            local t = msg_txt:text()
                            msg_txt:set_text(string.sub(t, 1, -2))
                        elseif k == Idstring("enter") then
                            NiceTrainer._panel:key_press(nil)
                            NiceTrainer._panel:enter_text(nil)
                            NiceTrainer._ws:disconnect_keyboard()
                        end
                    end)
                    NiceTrainer._panel:enter_text(function(o, s)
                        local t = msg_txt:text()
                        if #t < 64 then msg_txt:set_text(t .. s) end
                    end)
                end
            end
        })

        local function make_btn(label, bx, col, onclick)
            local btn = p:panel({ x = bx, y = 140, w = 220, h = 36, layer = 2 })
            local bb  = btn:rect({ color = col, alpha = 0.2, layer = 0 })
            btn:rect({ color = col, alpha = 0.7, w = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, x = 219, w = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, h = 1, layer = 1 })
            btn:rect({ color = col, alpha = 0.7, y = 35, h = 1, layer = 1 })
            btn:text({ text = label, font = FNT, font_size = 14, align = "center", vertical = "center", color = Color.white, layer = 2 })
            table.insert(modal_state.elements, {
                panel = btn,
                inside = function(self, mx, my) return btn:inside(mx, my) end,
                on_hover = function(self, hovered) bb:set_alpha(hovered and 0.5 or 0.2) end,
                on_click = onclick
            })
        end

        make_btn("SEND CHAT", 20, BG, function()
            local msg = (not is_ph) and msg_txt:text() or ""
            if msg ~= "" then
                pcall(function()
                    if managers.chat and managers.chat._receive_message then
                        managers.chat:_receive_message(1, "HOST", msg, tweak_data.system_chat_color)
                    end
                    local session = managers.network and managers.network:session()
                    if session then
                        session:send_to_peers("send_chat_message", ChatManager.GAME, "[HOST] " .. msg)
                    end
                end)
                NiceTrainer:Toast("Announcement sent!")
            end
            if alive(NiceTrainer._panel) then
                NiceTrainer._panel:key_press(nil)
                NiceTrainer._panel:enter_text(nil)
            end
            if NiceTrainer._ws then NiceTrainer._ws:disconnect_keyboard() end
            NiceTrainer:CloseModal()
        end)

        make_btn("CANCEL", 260, Color(0.7, 0.2, 0.2), function()
            if alive(NiceTrainer._panel) then
                NiceTrainer._panel:key_press(nil)
                NiceTrainer._panel:enter_text(nil)
            end
            if NiceTrainer._ws then NiceTrainer._ws:disconnect_keyboard() end
            NiceTrainer:CloseModal()
        end)
    end)
end

-- ============================================================================
-- Registration: Team Fast Actions
-- ============================================================================

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Actions",
    badge    = "client",
    text     = "Revive All Teammates",
    tooltip  = "Instantly revives all downed and incapacitated teammates (works as host and client).",
    callback = function()
        revive_all_teammates()
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Actions",
    badge    = "host",
    text     = "Release All from Custody",
    tooltip  = "Instantly frees all dead or detained teammates from custody and respawns them.",
    callback = function()
        release_all_from_custody()
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Actions",
    badge    = "host",
    text     = "Teleport All to Me",
    tooltip  = "Teleports all live teammates straight to your current coordinates.",
    callback = function()
        teleport_all_to_me()
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Actions",
    badge    = "host",
    text     = "Refill All Health & Ammo",
    tooltip  = "Restores 100% health and full ammo to every player on the team.",
    callback = function()
        refill_all_health_and_ammo()
    end
})

NiceTrainer:RegisterAction("Team", {
    type            = "multichoice",
    category        = "Team Actions",
    badge           = "client",
    id              = "team_drop_bag_type",
    text            = "Drop Bags on Team",
    tooltip         = "Spawns the selected loot bag type at each player's position (works as host and client).",
    options         = { "Money", "Gold", "Diamonds", "Coke", "Weapons", "Painting", "Meth", "Artifact", "Server" },
    default         = 1,
    action_btn_text = "Drop Bags",
    callback        = function(idx, val)
        drop_bags_on_all(idx)
    end
})

NiceTrainer:RegisterAction("Team", {
    type            = "multichoice",
    category        = "Team Actions",
    badge           = "client",
    id              = "team_drop_deployable_type",
    text            = "Drop Deployables on Team",
    tooltip         = "Spawns the selected deployable equipment (Ammo, Doctor Bag, Sentry, ECM, etc.) at each player's position (works as host and client).",
    options         = { "Ammo Bag", "Doctor Bag", "Body Bags", "ECM Jammer", "Trip Mine", "Sentry Gun" },
    default         = 1,
    action_btn_text = "Deploy",
    callback        = function(idx, val)
        drop_deployables_on_all(idx)
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Team Actions",
    badge    = "client",
    text     = "Broadcast [HOST] Message",
    tooltip  = "Sends an official server message to the team in-game chat.",
    callback = function()
        broadcast_host_announcement()
    end
})
