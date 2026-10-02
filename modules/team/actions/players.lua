-- ─── Individual Player Management ─────────────────────────────────────────────
-- Actions targeted at a specific connected peer.

NiceTrainer.TeamTargetPeerId = NiceTrainer.TeamTargetPeerId or 2

local function get_peer_unit(peer)
    if not peer then return nil end
    return peer:unit() or (managers.criminals and managers.criminals:character_unit_by_name(peer:character()))
end

local function get_target_peer()
    local session = managers.network and managers.network:session()
    if not session then
        NiceTrainer:Toast("No active network session.")
        return nil
    end
    local target_id = NiceTrainer.TeamTargetPeerId or 2
    local peer = session:peer(target_id)
    if not peer then
        NiceTrainer:Toast("No player connected in slot " .. target_id)
        return nil
    end
    return peer
end

local function teleport_to_peer(peer)
    local unit = get_peer_unit(peer)
    if alive(unit) then
        managers.player:warp_to(unit:position(), unit:rotation())
        NiceTrainer:Toast("Teleported to " .. peer:name())
    else
        NiceTrainer:Toast("Could not locate unit for " .. peer:name())
    end
end

local function teleport_peer_to_me(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local unit = get_peer_unit(peer)
    local my_unit = managers.player and managers.player:player_unit()
    if alive(unit) and alive(my_unit) then
        local pos = my_unit:position() + Vector3(0, 0, 40)
        pcall(function()
            unit:movement():set_position(pos)
            unit:set_position(pos)
        end)
        NiceTrainer:Toast("Teleported " .. peer:name() .. " to you!")
    else
        NiceTrainer:Toast("Could not teleport " .. peer:name())
    end
end

local function refill_peer(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local unit = get_peer_unit(peer)
    if alive(unit) then
        pcall(function()
            if unit:base() and unit:base().replenish then unit:base():replenish() end
            if unit:character_damage() and unit:character_damage().replenish then unit:character_damage():replenish() end
            unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 })
        end)
        NiceTrainer:Toast("Refilled health and ammo for " .. peer:name())
    else
        NiceTrainer:Toast("Unit not available for " .. peer:name())
    end
end

local function revive_peer(peer)
    local unit = get_peer_unit(peer)
    local local_player = managers.player and managers.player:player_unit()
    local session = managers.network and managers.network:session()
    local local_peer = session and session:local_peer()

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
                if local_player and session then
                    session:send_to_peers_synched("sync_teammate_helped_hint", 1, unit, local_player)
                end
                if unit:character_damage() and unit:character_damage().revive then
                    unit:character_damage():revive(true)
                end
            end
        end)
        NiceTrainer:Toast("Revived " .. (peer and peer:name() or "player"))
    else
        NiceTrainer:Toast("Player is not in a revivable state.")
    end
end

local function release_peer_from_custody(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    pcall(function()
        if _G.IngameWaitingForRespawnState and IngameWaitingForRespawnState.request_player_spawn then
            IngameWaitingForRespawnState.request_player_spawn(peer:id())
            NiceTrainer:Toast("Respawn requested for " .. peer:name())
        end
    end)
end

local function down_peer(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local unit = get_peer_unit(peer)
    if alive(unit) then
        pcall(function()
            unit:character_damage():damage_killzone({
                variant = "killzone",
                damage = 1000,
                col_ray = { position = unit:position() }
            })
        end)
        NiceTrainer:Toast("Downed " .. peer:name())
    end
end

local function toggle_godmode_peer(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local unit = get_peer_unit(peer)
    if alive(unit) then
        peer._nt_godmode = not peer._nt_godmode
        pcall(function() unit:character_damage():set_mission_damage_blockers("invulnerable", peer._nt_godmode) end)
        if peer._nt_godmode then
            pcall(function() unit:network():send_to_unit({ "spawn_dropin_penalty", false, false, 1, 0, 0, 0 }) end)
            pcall(function() unit:character_damage():replenish() end)
            NiceTrainer:Toast("Godmode ENABLED for " .. peer:name())
        else
            NiceTrainer:Toast("Godmode DISABLED for " .. peer:name())
        end
    else
        NiceTrainer:Toast("Could not locate unit for " .. peer:name())
    end
end

local function steal_peer_loadout(peer)
    local outfit = peer:blackmarket_outfit()
    if not outfit then
        NiceTrainer:Toast("No outfit data available for " .. peer:name())
        return
    end

    local function add_item(category, id)
        if not id or id == "" then return end
        if not (tweak_data.blackmarket and tweak_data.blackmarket[category] and tweak_data.blackmarket[category][id]) then return end
        local gv = managers.blackmarket:get_global_value(category, id) or "normal"
        pcall(function() managers.blackmarket:add_to_inventory(gv, category, id, false) end)
    end

    local count = 0
    if outfit.mask then
        add_item("masks", outfit.mask.mask_id)
        count = count + 1
        local bp = outfit.mask.blueprint
        if bp then
            if bp.material then add_item("materials", bp.material.id); count = count + 1 end
            if bp.pattern  then add_item("textures",  bp.pattern.id);  count = count + 1 end
            if bp.color    then add_item("colors",    bp.color.id);    count = count + 1 end
        end
    end

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
                    add_item("weapon_mods", mod)
                    count = count + 1
                end
            end
        end
    end

    pcall(function()
        if managers.menu_component and managers.menu_component.refresh_player_profile_gui then
            managers.menu_component:refresh_player_profile_gui()
        end
    end)
    NiceTrainer:Toast("Copied " .. count .. " items from " .. peer:name() .. " to your inventory!")
end

local function give_peer_supply(peer, supply_kind)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    local unit = get_peer_unit(peer)
    if alive(unit) then
        pcall(function()
            unit:network():send_to_unit({ "give_equipment", supply_kind, 6 })
        end)
        NiceTrainer:Toast("Gave " .. supply_kind .. " supply to " .. peer:name())
    else
        NiceTrainer:Toast("Unit not available for " .. peer:name())
    end
end

local function kick_peer(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    managers.network:session():send_to_peers("kick_peer", peer:id(), 0)
    managers.network:session():on_peer_kicked(peer, peer:id(), 0)
    NiceTrainer:Toast("Kicked " .. peer:name())
end

local function ban_peer(peer)
    if not Network:is_server() then
        NiceTrainer:Toast("Host only feature.")
        return
    end
    managers.ban_list:ban(peer:account_id(), peer:name())
    kick_peer(peer)
    NiceTrainer:Toast("Banned " .. peer:name())
end

-- ============================================================================
-- Registration: Manage Players
-- ============================================================================

NiceTrainer:RegisterAction("Team", {
    type     = "multichoice",
    category = "Manage Players",
    id       = "target_peer",
    text     = "Target Player",
    options  = function(idx)
        if idx == "count" then return 4 end
        local session = managers.network and managers.network:session()
        if not session then return "Player Slot " .. idx end
        local peer = session:peer(idx)
        if peer then
            local is_local = (session:local_peer() == peer)
            return peer:name() .. (is_local and " (You)" or (Network:is_server() and idx == 1 and " (Host)" or ""))
        else
            return "Slot " .. idx .. " (Empty)"
        end
    end,
    default  = 2,
    callback = function(idx, val)
        NiceTrainer.TeamTargetPeerId = idx
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "client",
    text     = "Teleport To Them",
    tooltip  = "Teleports your player directly to the selected teammate's location.",
    callback = function()
        local peer = get_target_peer()
        if peer then teleport_to_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Teleport Them To Me",
    tooltip  = "Teleports the selected player to your current coordinates. Host only.",
    callback = function()
        local peer = get_target_peer()
        if peer then teleport_peer_to_me(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Refill Health & Ammo",
    tooltip  = "Restores maximum health and replenishes ammo for the selected player.",
    callback = function()
        local peer = get_target_peer()
        if peer then refill_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "client",
    text     = "Revive Player",
    tooltip  = "Revives the selected player if they are bleeding out or incapacitated (works as host and client).",
    callback = function()
        local peer = get_target_peer()
        if peer then revive_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Release from Custody",
    tooltip  = "Frees the selected player from police custody immediately.",
    callback = function()
        local peer = get_target_peer()
        if peer then release_peer_from_custody(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Toggle Player Godmode",
    tooltip  = "Toggles invulnerability on the selected player.",
    callback = function()
        local peer = get_target_peer()
        if peer then toggle_godmode_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "client",
    text     = "Steal Player's Loadout",
    tooltip  = "Copies the selected player's mask, colors, materials, patterns, and weapon attachments to your Blackmarket inventory.",
    callback = function()
        local peer = get_target_peer()
        if peer then steal_peer_loadout(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type            = "multichoice",
    category        = "Manage Players",
    badge           = "host",
    id              = "player_supply_pack_type",
    text            = "Give Supply Pack",
    tooltip         = "Sends extra ammo, first aid, cable ties, or body bags directly to the selected player's equipment inventory.",
    options         = { "Ammo", "First Aid", "Cable Ties", "Body Bags", "Grenades" },
    default         = 1,
    action_btn_text = "Give",
    callback        = function(idx, val)
        local peer = get_target_peer()
        if not peer then return end
        local supply_map = { "ammo", "first_aid_kit", "cable_tie", "bodybags_bag", "grenades" }
        give_peer_supply(peer, supply_map[idx] or "ammo")
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Down / Send to Custody",
    tooltip  = "Incapacitates or downs the selected player.",
    callback = function()
        local peer = get_target_peer()
        if peer then down_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Kick Player",
    tooltip  = "Kicks the selected player from the heist.",
    callback = function()
        local peer = get_target_peer()
        if peer then kick_peer(peer) end
    end
})

NiceTrainer:RegisterAction("Team", {
    type     = "button",
    category = "Manage Players",
    badge    = "host",
    text     = "Ban Player",
    tooltip  = "Permanently bans and kicks the selected player.",
    callback = function()
        local peer = get_target_peer()
        if peer then ban_peer(peer) end
    end
})
