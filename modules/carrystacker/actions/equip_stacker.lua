-- ─── Equipment Stacker & Auto-Collector ─────────────────────────────────────────
-- 1. Stack Mission Equipment (Hold multiple keycards, crowbars, planks, C4, etc.)
-- 2. Auto-Collect Equipment (Picks up keycards, crowbars, loot within radius)

-- ============================================================================
-- Hooks: Enable Multiple Special Equipment Items
-- ============================================================================
if _G.UseInteractionExt and not UseInteractionExt._nt_equip_stacker_hooked then
    UseInteractionExt._nt_equip_stacker_hooked = true

    local orig_can_select   = UseInteractionExt.can_select
    local orig_can_interact = UseInteractionExt.can_interact

    function UseInteractionExt:can_select(player, ...)
        if NiceTrainer.Settings.equip_stacker_enabled then
            if self._tweak_data and self._tweak_data.special_equipment_block then
                return true
            end
        end
        return orig_can_select(self, player, ...)
    end

    function UseInteractionExt:can_interact(player, ...)
        if NiceTrainer.Settings.equip_stacker_enabled then
            if self._tweak_data and self._tweak_data.special_equipment_block then
                return true
            end
        end
        return orig_can_interact(self, player, ...)
    end
end

if _G.PlayerManager and not PlayerManager._nt_equip_stacker_hooked then
    PlayerManager._nt_equip_stacker_hooked = true

    local orig_add_special = PlayerManager.add_special
    function PlayerManager:add_special(params, ...)
        if NiceTrainer.Settings.equip_stacker_enabled then
            local name = params.equipment or params.name
            if name and tweak_data and tweak_data.equipments and tweak_data.equipments.specials and tweak_data.equipments.specials[name] then
                local eq = tweak_data.equipments.specials[name]
                if not eq._nt_orig_max then
                    eq._nt_orig_max = eq.max_quantity or 1
                end
                eq.max_quantity = NiceTrainer.Settings.equip_stacker_amount or 99
            end
        end
        return orig_add_special(self, params, ...)
    end
end

-- ============================================================================
-- Auto-Collector Loop
-- ============================================================================
local _equip_acc = 0
Hooks:Add("GameSetupUpdate", "NiceTrainer_EquipCollector", function(t, dt)
    if not NiceTrainer.Settings.equip_auto_collect or not NiceTrainer:IsInHeist() then return end

    _equip_acc = _equip_acc + dt
    if _equip_acc < 0.25 then return end
    _equip_acc = 0

    local player = managers.player and managers.player:player_unit()
    if not alive(player) then return end

    local range = (NiceTrainer.Settings.equip_auto_collect_range or 10) * 100
    local p_pos = player:position()

    if managers.interaction and managers.interaction._interactive_units then
        for _, unit in ipairs(managers.interaction._interactive_units) do
            if alive(unit) then
                local interaction = unit:interaction()
                if interaction and interaction:active() and not interaction:disabled() then
                    local dist = mvector3.distance(p_pos, interaction:interact_position())
                    if dist <= range then
                        local tweak = interaction.tweak_data
                        if type(tweak) == "string" then
                            local tweak_table = tweak_data.interaction and tweak_data.interaction[tweak]
                            local is_equip = tweak_table and (tweak_table.special_equipment_block or tweak:find("money_wrap") or tweak:find("diamond_pickup") or tweak:find("gold") or tweak:find("coke") or tweak:find("pku_"))
                            if is_equip then
                                pcall(function()
                                    interaction:interact(player)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================================
-- Registrations (CarryStacker Tab -> Equipment & Auto-Collect)
-- ============================================================================

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Equipment",
    badge    = "client",
    id       = "equip_stacker_enabled",
    text     = "Stack Mission Equipment",
    tooltip  = "Allows you to pick up and hold unlimited keycards, crowbars, C4 and thermal drills.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.equip_stacker_enabled = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "slider",
    category = "Equipment",
    badge    = "client",
    id       = "equip_stacker_amount",
    text     = "Max Equipment Stack",
    tooltip  = "Maximum quantity allowed for each special mission equipment item.",
    min      = 2,
    max      = 99,
    default  = 99,
    callback = function(val)
        NiceTrainer.Settings.equip_stacker_amount = val
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "toggle",
    category = "Auto-Collect",
    badge    = "client",
    id       = "equip_auto_collect",
    text     = "Auto-Collect Items & Loot",
    tooltip  = "Automatically vacuums up nearby keycards, crowbars, cash bundles, and loose loot in range.",
    default  = false,
    callback = function(state)
        NiceTrainer.Settings.equip_auto_collect = state
        NiceTrainer:Save()
    end
})

NiceTrainer:RegisterAction("CarryStacker", {
    type     = "slider",
    category = "Auto-Collect",
    badge    = "client",
    id       = "equip_auto_collect_range",
    text     = "Collection Range (m)",
    tooltip  = "Radius in meters around your character to automatically collect loose items.",
    min      = 1,
    max      = 50,
    default  = 10,
    callback = function(val)
        NiceTrainer.Settings.equip_auto_collect_range = val
        NiceTrainer:Save()
    end
})
