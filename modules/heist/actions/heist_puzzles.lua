-- Puzzles, Enigmas & Secret Code Solvers for City of Gold, Silk Road, Texas Heat & Classic Heists
local _puzzle_highlights = {}

local function clear_puzzle_highlights()
    for _, u in ipairs(_puzzle_highlights) do
        if alive(u) and u:contour() then
            pcall(function() u:contour():remove("generic_interactable") end)
            pcall(function() u:contour():remove("highlight_character") end)
        end
    end
    _puzzle_highlights = {}
end

local function scan_and_announce_code(map_name, code_pattern)
    local found_digits = {}
    if managers.mission and managers.mission._scripts then
        for _, script in pairs(managers.mission._scripts) do
            for _, elem in pairs(script:elements()) do
                local name = string.lower(elem:editor_name() or "")
                if name:find("code", 1, true) or name:find("digit", 1, true) or name:find("password", 1, true) or (code_pattern and name:find(code_pattern, 1, true)) then
                    if elem._values then
                        local val = elem._values.variable_value or elem._values.value or elem._values.amount
                        if val then
                            table.insert(found_digits, tostring(val))
                        end
                    end
                end
            end
        end
    end

    if #found_digits > 0 then
        local code_str = table.concat(found_digits, " - ")
        NiceTrainer:Toast(string.format("[%s] Keypad Code: %s", map_name, code_str))
        if managers.chat then
            managers.chat:feed_system_message(ChatManager.GAME, string.format("[NiceTrainer] %s Keypad Code: %s", map_name, code_str))
        end
        return true
    else
        NiceTrainer:Toast(string.format("[%s] Searching world for code elements...", map_name))
        return false
    end
end

-- ============================================================
-- Breakfast in Tijuana (bex)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Breakfast in Tijuana (bex)",
    level_id = "bex",
    badge = "client",
    text = "Find Keypad Codes (Warden / Armory)",
    tooltip = "Scans memory for the Warden Office and Armory door keypad codes.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("Breakfast in Tijuana", "bex")
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Breakfast in Tijuana (bex)",
    level_id = "bex",
    badge = "client",
    text = "Highlight USB Drive & Evidence Keys",
    tooltip = "Applies green contours to the Warden USB stick and cell keys.",
    action_btn_text = "Locate",
    callback = function()
        clear_puzzle_highlights()
        local count = 0
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() then
                local tw = tostring(u:interaction()._tweak_data or ""):lower()
                if tw:find("usb", 1, true) or tw:find("key", 1, true) or tw:find("evidence", 1, true) or tw:find("bex", 1, true) then
                    if u:contour() then
                        pcall(function()
                            u:contour():add("generic_interactable", true, Vector3(0, 1, 0))
                            table.insert(_puzzle_highlights, u)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Highlighted %d mission items (USB/Keys).", count))
    end
})

-- ============================================================
-- Buluc's Mansion (fex)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Buluc's Mansion (fex)",
    level_id = "fex",
    badge = "host",
    text = "Auto-Solve Inner Sanctuary Altar Puzzle",
    tooltip = "Triggers the 4 altar switches and opens the pyramid vault entrance.",
    action_btn_text = "Solve",
    callback = function()
        local count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("sanctuary", 1, true) or name:find("altar", 1, true) or name:find("pyramid_door", 1, true) or name:find("fex_puzzle", 1, true) then
                        pcall(function()
                            elem:on_executed()
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Buluc's Mansion sanctuary puzzle sequence triggered (%d elements)!", count))
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Buluc's Mansion (fex)",
    level_id = "fex",
    badge = "client",
    text = "Highlight 4 Sanctuary Keys",
    tooltip = "Highlights the 4 secret keys required for the inner vault.",
    action_btn_text = "Locate",
    callback = function()
        clear_puzzle_highlights()
        local count = 0
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() then
                local tw = tostring(u:interaction()._tweak_data or ""):lower()
                if tw:find("key", 1, true) or tw:find("sanctuary", 1, true) or tw:find("fex", 1, true) then
                    if u:contour() then
                        pcall(function()
                            u:contour():add("generic_interactable", true, Vector3(0, 1, 0))
                            table.insert(_puzzle_highlights, u)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Highlighted %d sanctuary keys.", count))
    end
})

-- ============================================================
-- San Martin Bank (bph)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "San Martin Bank (bph)",
    level_id = "bph",
    badge = "client",
    text = "Find Keypad & Safe Codes",
    tooltip = "Scans memory for the manager safe code and vault keypad combinations.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("San Martin Bank", "bph")
    end
})

-- ============================================================
-- Mountain Master (chas)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Mountain Master (chas)",
    level_id = "chas",
    badge = "host",
    text = "Auto-Solve Tea Ceremony & Dragon Statues",
    tooltip = "Aligns the incense dragon statues and solves the tea ceremony puzzle to open the penthouse vault.",
    action_btn_text = "Solve",
    callback = function()
        local count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("tea_correct", 1, true) or name:find("statue_align", 1, true) or name:find("chas_puzzle", 1, true) or name:find("dragon_solve", 1, true) then
                        pcall(function()
                            elem:on_executed()
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Tea & Dragon puzzle sequence executed (%d elements)!", count))
    end
})

-- ============================================================
-- Midland Ranch (ranc)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Midland Ranch (ranc)",
    level_id = "ranc",
    badge = "client",
    text = "Find Barn Keypad Code",
    tooltip = "Scans memory for the barn workshop door keypad combination.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("Midland Ranch", "ranc")
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Midland Ranch (ranc)",
    level_id = "ranc",
    badge = "host",
    text = "Disable Laser Defense Grid",
    tooltip = "Disables the laser alarms inside the research workshop.",
    action_btn_text = "Disable",
    callback = function()
        local count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("laser", 1, true) or name:find("laser_alarm", 1, true) or name:find("tripwire", 1, true) then
                        elem:set_enabled(false)
                        count = count + 1
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Laser defense grid disabled (%d elements).", count))
    end
})

-- ============================================================
-- Lost in Transit (trai)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Lost in Transit (trai)",
    level_id = "trai",
    badge = "client",
    text = "Decode Train Manifest & Correct Wagons",
    tooltip = "Decodes the train car manifest and highlights the target rail wagons in green.",
    action_btn_text = "Decode",
    callback = function()
        clear_puzzle_highlights()
        local count = 0
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() then
                local tw = tostring(u:interaction()._tweak_data or ""):lower()
                if tw:find("train_door", 1, true) or tw:find("trai", 1, true) or tw:find("manifest", 1, true) or tw:find("wagon", 1, true) then
                    if u:contour() then
                        pcall(function()
                            u:contour():add("generic_interactable", true, Vector3(0, 1, 0))
                            table.insert(_puzzle_highlights, u)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Highlighted %d target train car doors in green.", count))
    end
})

-- ============================================================
-- Hostile Takeover (corp)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Hostile Takeover (corp)",
    level_id = "corp",
    badge = "client",
    text = "Find R&D Lab Codes & Passwords",
    tooltip = "Scans memory for lab computer passwords and server access codes.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("Hostile Takeover", "corp")
    end
})

-- ============================================================
-- Crude Awakening (deep)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Crude Awakening (deep)",
    level_id = "deep",
    badge = "host",
    text = "Auto-Solve Oil Pump Valve Sequence",
    tooltip = "Overrides the oil rig pump pressure valves and unlocks the drill control unit.",
    action_btn_text = "Solve",
    callback = function()
        local count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("valve_correct", 1, true) or name:find("pump_sequence", 1, true) or name:find("deep_puzzle", 1, true) or name:find("override_valves", 1, true) then
                        pcall(function()
                            elem:on_executed()
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Oil pump valve sequence executed (%d elements)!", count))
    end
})

-- ============================================================
-- Counterfeit (run)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Counterfeit (run)",
    level_id = "run",
    badge = "client",
    text = "Find Basement Safe Code",
    tooltip = "Scans memory for the Mitchell / Wilson safe code combination.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("Counterfeit", "run")
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Counterfeit (run)",
    level_id = "run",
    badge = "client",
    text = "Highlight Water Valve & Power Box",
    tooltip = "Highlights the basement water supply valve and backyard power switch.",
    action_btn_text = "Locate",
    callback = function()
        clear_puzzle_highlights()
        local count = 0
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() then
                local tw = tostring(u:interaction()._tweak_data or ""):lower()
                if tw:find("water", 1, true) or tw:find("power", 1, true) or tw:find("circuit", 1, true) or tw:find("plate", 1, true) or tw:find("paper", 1, true) then
                    if u:contour() then
                        pcall(function()
                            u:contour():add("generic_interactable", true, Vector3(0, 1, 0))
                            table.insert(_puzzle_highlights, u)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Highlighted %d water/power/paper items.", count))
    end
})

-- ============================================================
-- Shacklethorne Auction (tag)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Shacklethorne Auction (tag)",
    level_id = "tag",
    badge = "client",
    text = "Decode Tablet Cipher & Codes",
    tooltip = "Decodes the exhibition tablet cipher and reveals the display case keypad code.",
    action_btn_text = "Decode",
    callback = function()
        scan_and_announce_code("Shacklethorne Auction", "tag")
    end
})

NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Shacklethorne Auction (tag)",
    level_id = "tag",
    badge = "host",
    text = "Disable Exhibition Laser Barriers",
    tooltip = "Disables the laser barriers protecting the auction items.",
    action_btn_text = "Disable",
    callback = function()
        local count = 0
        if managers.mission and managers.mission._scripts then
            for _, script in pairs(managers.mission._scripts) do
                for _, elem in pairs(script:elements()) do
                    local name = string.lower(elem:editor_name() or "")
                    if name:find("laser", 1, true) or name:find("tag_alarm", 1, true) then
                        elem:set_enabled(false)
                        count = count + 1
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Laser barriers disabled (%d elements).", count))
    end
})

-- ============================================================
-- Brooklyn Bank (brb)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Brooklyn Bank (brb)",
    level_id = "brb",
    badge = "client",
    text = "Locate Medallion & Safe Keys",
    tooltip = "Highlights the hidden medallion and the manager safe keys.",
    action_btn_text = "Locate",
    callback = function()
        clear_puzzle_highlights()
        local count = 0
        for _, u in pairs(World:find_units_quick("all")) do
            if alive(u) and u:interaction() then
                local tw = tostring(u:interaction()._tweak_data or ""):lower()
                if tw:find("medallion", 1, true) or tw:find("safe_key", 1, true) or tw:find("brb", 1, true) then
                    if u:contour() then
                        pcall(function()
                            u:contour():add("generic_interactable", true, Vector3(0, 1, 0))
                            table.insert(_puzzle_highlights, u)
                            count = count + 1
                        end)
                    end
                end
            end
        end
        NiceTrainer:Toast(string.format("Highlighted %d medallion/key items.", count))
    end
})

-- ============================================================
-- Scarface Mansion (friend)
-- ============================================================
NiceTrainer:RegisterAction("Heist", {
    type = "button",
    category = "Scarface Mansion (friend)",
    level_id = "friend",
    badge = "client",
    text = "Find Master Bedroom Picture Code",
    tooltip = "Scans memory for the safe code behind the master bedroom painting.",
    action_btn_text = "Scan",
    callback = function()
        scan_and_announce_code("Scarface Mansion", "friend")
    end
})
