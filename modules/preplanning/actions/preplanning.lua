-- Pre-planning Module for NiceTrainer

NiceTrainer:RegisterAction("Pre-planning", {
    type = "toggle",
    category = "Cheats",
    id = "free_preplanning",
    text = "Free Preplanning",
    tooltip = "Preplanning costs nothing and needs no favours.",
    default = false,
    callback = function(state)
        if _G.MoneyManager then
            if not _G.MoneyManager.orig_get_preplanning_type_cost then
                _G.MoneyManager.orig_get_preplanning_type_cost = _G.MoneyManager.get_preplanning_type_cost
                _G.MoneyManager.orig_can_afford_preplanning_type = _G.MoneyManager.can_afford_preplanning_type
                _G.MoneyManager.orig_get_preplanning_votes_cost = _G.MoneyManager.get_preplanning_votes_cost
            end
            if state then
                _G.MoneyManager.get_preplanning_type_cost = function() return 0 end
                _G.MoneyManager.can_afford_preplanning_type = function() return true end
                _G.MoneyManager.get_preplanning_votes_cost = function() return 0 end
            else
                _G.MoneyManager.get_preplanning_type_cost = _G.MoneyManager.orig_get_preplanning_type_cost
                _G.MoneyManager.can_afford_preplanning_type = _G.MoneyManager.orig_can_afford_preplanning_type
                _G.MoneyManager.get_preplanning_votes_cost = _G.MoneyManager.orig_get_preplanning_votes_cost
            end
        end

        if _G.PrePlanningManager then
            if not _G.PrePlanningManager.orig_get_type_budget_cost then
                _G.PrePlanningManager.orig_get_type_budget_cost = _G.PrePlanningManager.get_type_budget_cost
                _G.PrePlanningManager.orig_can_reserve_mission_element = _G.PrePlanningManager.can_reserve_mission_element
                _G.PrePlanningManager.orig_can_vote_on_plan = _G.PrePlanningManager.can_vote_on_plan
                _G.PrePlanningManager.orig_get_current_budget = _G.PrePlanningManager.get_current_budget
            end
            if state then
                _G.PrePlanningManager.get_type_budget_cost = function() return 0 end
                _G.PrePlanningManager.can_reserve_mission_element = function() return true end
                _G.PrePlanningManager.can_vote_on_plan = function() return true end
                _G.PrePlanningManager.get_current_budget = function() return 0, 9999 end
            else
                _G.PrePlanningManager.get_type_budget_cost = _G.PrePlanningManager.orig_get_type_budget_cost
                _G.PrePlanningManager.can_reserve_mission_element = _G.PrePlanningManager.orig_can_reserve_mission_element
                _G.PrePlanningManager.can_vote_on_plan = _G.PrePlanningManager.orig_can_vote_on_plan
                _G.PrePlanningManager.get_current_budget = _G.PrePlanningManager.orig_get_current_budget
            end
        end
    end
})

NiceTrainer:RegisterAction("Pre-planning", {
    type = "toggle",
    category = "Cheats",
    badge = "host",
    id = "host_choose_plan",
    text = "Host Choose Plan",
    tooltip = "Host's chosen preplanning always wins the vote.",
    default = false,
    callback = function(state)
        if _G.PrePlanningManager then
            if not _G.PrePlanningManager.orig_update_majority_votes then
                _G.PrePlanningManager.orig_update_majority_votes = _G.PrePlanningManager._update_majority_votes
            end
            if state then
                _G.PrePlanningManager._update_majority_votes = function(self, ...)
                    if Network:is_client() then return _G.PrePlanningManager.orig_update_majority_votes(self, ...) end
                    local winners
                    pcall(function()
                        local local_peer_id = managers.network:session():local_peer():id()
                        local plan_data = self:get_vote_council()[local_peer_id]
                        if plan_data then
                            winners = {}
                            for plan, data in pairs(plan_data) do winners[plan] = { data[1], data[2] } end
                            self._saved_majority_votes = winners
                        end
                    end)
                    if winners then return winners end
                    return _G.PrePlanningManager.orig_update_majority_votes(self, ...)
                end
            else
                _G.PrePlanningManager._update_majority_votes = _G.PrePlanningManager.orig_update_majority_votes
            end
        end
    end
})


NiceTrainer:RegisterAction("Pre-planning", {
    type = "button",
    category = "Actions",
    badge = "client",
    text = "Buy All Preplanning",
    tooltip = "Reserves every preplanning element possible (works as host and client).",
    callback = function()
        if not managers.preplanning then return end
        
        -- Garante que o free preplanning esta ativo antes de comprar
        if _G.MoneyManager and not _G.MoneyManager.orig_get_preplanning_type_cost then
            NiceTrainer:Toast("Ative o Free Preplanning primeiro!", Color.yellow)
            return
        end

        pcall(function()
            local pp = managers.preplanning
            if not pp._mission_elements_by_type then return end
            local equipments = { "bodybags_bag", "grenade_crate", "ammo_bag", "health_bag" }
            for ptype, array in pairs(pp._mission_elements_by_type) do
                for _, element in pairs(array) do
                    local t = ptype
                    if table.contains(equipments, ptype) then 
                        t = equipments[math.random(1, #equipments)] 
                    end
                    pcall(function() pp:reserve_mission_element(t, element:id()) end)
                end
            end
        end)
        NiceTrainer:Toast("Reserved all preplanning elements!", Color.green)
    end
})

NiceTrainer:RegisterAction("Pre-planning", {
    type = "button",
    category = "Actions",
    badge = "client",
    text = "Unlock All Assets",
    tooltip = "Unlocks all available assets for the current heist (works as host and client).",
    callback = function()
        pcall(function()
            local assets = managers.assets
            if not assets then return end
            if Network:is_server() and assets.unlock_all_availible_assets then
                assets:unlock_all_availible_assets()
            elseif assets.get_all_asset_ids then
                local session = managers.network:session()
                for _, id in pairs(assets:get_all_asset_ids(true)) do
                    if Network:is_server() then
                        assets:unlock_asset(id)
                    elseif session then
                        session:send_to_host("server_unlock_asset", id)
                    end
                end
            end
        end)
        NiceTrainer:Toast("Unlocked all assets!", Color.green)
    end
})
