NiceTrainer.ESP = NiceTrainer.ESP or {}
NiceTrainer.ESP._highlighted_units = {}
NiceTrainer.ESP._cached_unit_materials = {}
NiceTrainer.ESP._cached_classification = {}
NiceTrainer.ESP._cached_static_props = nil

local ESP = NiceTrainer.ESP

ESP.LOOT_CLASSIFY = {
    { key = "loot_cash", patterns = {
        "money", "cash", "banknote", "bank_note", "single_bundle", "atm_loot", "register", "currency", 
        "wage", "briefcase_steel", "safe_loot_money", "money_wrap", "money_bag", "payout", "deposit_box_money",
        "casino_chip", "chip_piles", "counterfeit_money", "money_scanner", "spawn_bucket_of_money", "bundle",
        "atm_standing", "atm", "safe_money", "money_scanner_counter", "money_wrap_single_bundle", "single_money",
        "piggybank", "pda9_piggybank", "explode_the_pig"
    }},
    { key = "loot_drugs", patterns = {
        "coke", "meth", "drug", "weed", "cokebag", "methbag", "chemical_box", "pure_coke", "coke_pure",
        "yayo", "euphadrine", "concoction_paste", "hydro_chloride", "meth_half", "coca", "pure", "chemical",
        "cloaker_cocaine"
    }},
    { key = "loot_valuables", patterns = {
        "gold", "diamond", "jewel", "ring_box", "jewelry", "painting", "paintings", "artifact", "masterpiece", "toothbrush",
        "warhead", "samurai", "necklace", "pottery", "tiara", "statue", "ancient_urn", "chalice", "relic", "ancient",
        "coin_bag", "silver", "trophy", "sculpture", "egyptian", "roman", "papyrus", "bracelet", "watch", "sapphire",
        "ruby", "rubies", "emerald", "amulet", "bust", "safe_loot_gold", "safe_loot_diamond", "valuable", "treasure",
        "faberge_egg", "egg", "teaset", "chas_artifact", "hope_diamond", "red_diamond", "diamonds_dah", "sandwich",
        "presidential_pardon", "lost_artifact", "uno_gold", "expensive_vine", "ordinary_wine", "old_wine", "wine",
        "robot_toy", "women_shoes", "vr_headset", "gnome", "puck", "chl_puck", "black_tablet", "pda9_feed",
        "goldbag", "exhibit", "mummy", "alien_head", "brosch", "ankh", "relief", "caeser_bust", "cro_loot",
        "federali_medal", "medal", "present", "gift", "gold_pile", "take_cup", "ring_band", "vault_loot",
        "annabelle", "ben_qwek", "charlie", "claude", "curator", "degas", "edouard", "ernst", "francois",
        "gustave", "henri", "jacques", "jean", "lucas", "maurice", "michel", "pierre", "rene", "vincent",
        "william", "yves", "art_loot", "art_crate", "art_prop_painting", "com_prop_gallery", "cut_painting",
        "hold_cut_painting", "hold_take_painting", "take_painting", "painting_carry_drop", "gallery_painting",
        "mus_prop_exhibit_painting", "lxy_prop_maritime_painting", "corp_pku_paintings", "cas_prop_painting",
        "goat", "civ_goat", "peta_goat", "pta_prop_goat", "take_goat", "pku_goat", "grab_goat", "pull_goat",
        "search_goat", "peta_take_goat", "peta_grab_goat", "peta_pull_goat", "hold_take_goat", "hold_pull_goat",
        "hold_search_goat", "hold_grab_goat",
        "hardcase_loot", "diamondheist", "jewelry_bust", "nick_street",
        "luxury_bags", "loot_drop", "pku_loot", "bex_pku_treasure", "bex_prop_faberge_egg", "chas_pku_dragon_statue",
        "suburbia_necklace", "take_diamond_necklace", "gen_ladyjustice_statue", "gen_pku_artifact_statue",
        "mus_prop_", "xmn_prop_christmas_gift", "com_prop_christmas_gift", "secret_stash_equipment_server_rack",
        "vit_prop_presidential_pardon", "sah_pku_artifact", "sah_prop_mummy", "sand_prop_int_vase", "uno_prop_dentist",
        "cloaker_gold", "cloaker_money", "chas_teaset", "pku_pig", "pku_pills", "take_toy", "take_shoes", "take_pardons",
        "winning_slip", "fex_take_globe", "fex_take_alarm_clock", "tag_take_unknown", "des_take_unknown",
        "crate_loot", "loot_crate", "open_crate", "hold_open_crate", "crate_loot_crowbar", "hold_open_crate_crowbar",
        "open_crate_crowbar", "crate_weapon", "crate", "box_unknown", "box_unknown_tag", "weapon_crate", "weapons", "weapon",
        "grenades", "safe_wpn", "safe_ovk", "safe_secure_dummy", "ranc_weapon"
    }},
    { key = "loot_bags", patterns = {
        "carry_drop", "hold_take_carry", "take_carry", "loot_bag", "body_bag", "bodybag", "corpse_bag", "corpse_dispose",
        "bodybags_bag", "take_body_bag", "pig_bag", "ladder_bag", "cage_bag", "equipment_bag",
        "bag_drop", "carried_bag", "person", "special_person", "uno_prop_murky_clothes_bag"
    }},
    { key = "loot_small", patterns = {
        "deposit_box", "safety_deposit", "small_loot", "loot_drop", "safe_loot", "open_safe",
        "open_deposit", "deposit", "pku_safe", "safe_carry_drop", "bex_open_safe", "fex_open_safe", "vit_safe",
        "special_deposit_box", "slot_machine_payout", "vault_loot_chest", "vault_loot_diamond_chest",
        "vault_loot_banknotes", "vault_loot_silver", "vault_loot_diamond_collection", "vault_loot_trophy",
        "vault_loot_gold", "vault_loot_cash", "vault_loot_coins", "vault_loot_ring", "vault_loot_jewels",
        "vault_loot_macka", "trai_achievement_safe", "trai_hold_toolsafe_pickuptool"
    }},
}
ESP.MISSION_CLASSIFY = {
    { key = "mission_c4", patterns = {
        "c4", "shaped_charge", "shaped_sharge", "c4_charge", "c4_stackable", "c4_x", "c4_consume", "c4_plant",
        "place_c4", "thermite_c4", "c4_bag", "breaching_charges", "c4_mission", "plant_c4", "c4_diffuse", "alesso_c4",
        "trip_mine", "tripmine", "c4_set", "plant_c4_x3", "disarm_bomb", "assemble_bomb", "bomb_case",
        "breaching_detonator", "ignite_trap", "missile", "breacher"
    }},
    { key = "mission_ecm", patterns = {
        "ecm", "requires_ecm_jammer", "ecm_jammer", "ecm_door", "ecm_box", "ecm_panel", "ecm_feedback", "ecm_override"
    }},
    { key = "mission_key", patterns = {
        "keycard", "key_", "_key", "key", "passcode", "code", "card", "cessna_key", "rfid_tag", "keychain",
        "access_card", "security_card", "numpad_keycard", "timelock_panel", "key_double", "bank_manager_key",
        "key_case", "keycase", "key_ring", "take_keys", "hotel_room_key", "key_holder", "keyhole", "red_take_keycard",
        "chas_keycard", "chas_key", "keycard_insert", "swipe_card", "use_keycard", "mex_take_keys", "search_keycard",
        "take_keycard", "pick_up_keycard", "key_box", "keycard_box", "handcuff_key", "tag_take_keys", "fex_take_keys",
        "tag_keycard", "hotel_service_key", "pent_keycard"
    }},
    { key = "mission_drills", patterns = {
        "drill", "saw", "thermite", "dynamite", "torch", "cutter", "lance", "lance_part", "burn", "flare",
        "beacon", "charge", "blowtorch", "plasma_cutter", "laser_cutter", "cutter_tool", "drill_jammed",
        "drill_upgrade", "heavy_drill", "lance_jammed", "saw_jammed", "saw_blade", "glass_cutter",
        "thermite_paste", "place_flare", "ignite_flare", "goldheist_drill", "bfd_", "cas_bfd", "teddy_saw",
        "hospital_saw", "alesso_cutter", "circle_cutter", "saw_teddy", "requires_saw_blade", "glass_cutter_jammed"
    }},
    { key = "mission_power", patterns = {
        "circuit", "breaker", "fuse", "power", "electric", "switch", "generator", "rewire", "cut_wire",
        "cut_cable", "cut_wires", "security_box", "sec_box", "open_slash_close_sec_box", "open_sec_box",
        "cas_open_security_box", "electrical_box", "powerbox", "power_box", "switch_box", "fuse_box",
        "transformer", "transformer_box", "junction", "shut_off", "breaker_off", "breaker_on",
        "hold_circuit_breaker", "circuit_breaker_off", "circuit_breaker", "pull_switch", "hold_pull_switch",
        "hold_pull_switch_distance", "cable", "power_cable", "power_cord", "substation", "disable_alarm",
        "alarm_box", "electric_panel", "electric_box", "laser_grid", "lasers", "override", "turn_on", "turn_off",
        "valve", "pump", "lever", "panel", "water_tap", "security_button", "splice", "generator_start",
        "elevator_button", "light_switch", "button_0", "cas_button", "crane_joystick", "hose", "connect_hose",
        "disconnect_hose", "trai_prop_electrical_box", "mex_repair_breaker", "cas_elevator", "cas_slot_machine",
        "crane", "forklift", "water_pipe", "pipe", "gas_pipe", "pipe_corner", "trai_crane_control", "fire_alarm",
        "temperature", "lift_choose", "elevator", "sprinklers", "push_button", "spin_wheel", "bet_red", "bet_black",
        "alarm", "wall_lamp", "restart_timer", "activate", "release_brake", "slot_machine"
    }},
    { key = "mission_computer", patterns = {
        "computer", "laptop", "server", "hack", "keypad", "terminal", "ipad", "iphone", "phone", "keyboard",
        "harddrive", "usb", "drive", "download", "scanner", "camera_feed", "security_station", "console",
        "code_device", "screen", "monitor", "big_computer", "hackable", "hard_drive", "server_rack", "server_cord",
        "master_server", "copy_usb", "use_usb", "usb_key", "numpad", "answer_call", "call", "ip_scanner",
        "barcode", "firewall", "infopad", "tablet", "data_tape", "record_tape", "recording", "radio", "intercom",
        "mcm_laptop", "tag_pku_usb", "yacht_server", "yacht_harddrive", "secret_stash_equipment_server", "voting_machine",
        "access_camera", "access_sidejobs", "access_pd2stash", "activate_camera", "tv", "bypass_the_firewall",
        "sand_pku_copy_machine_usb", "copy_machine", "sample_validation", "hospital_sample", "spy_camera_access",
        "trai_connect_locke", "walkietalkie", "signal_operator", "voice_recorder", "customer_database", "database",
        "uload_database", "gps_coords", "password", "relay_locke", "postpone_update", "anwser_machine", "touch_book"
    }},
    { key = "mission_lockpick", patterns = {
        "lockpick", "pick_lock", "picklock", "lock_pick", "pick_safe", "pick_deposit", "fex_pick_lock", "pick_door"
    }},
    { key = "mission_doors", patterns = {
        "door", "gate", "window", "vent", "cage", "shutter", "vault", "trapdoor", "hatch", "cell", "curtain",
        "grate", "cut_fence", "fence_wire_cut", "suburbia_iron_gate_crowbar", "barricade", "open_door", "close_door",
        "iron_gate", "security_gate", "vault_gate", "slide_door", "open_window", "open_vent", "escape_hatch",
        "cas_screw_door", "open_slash_close_act", "open_slash_close_door", "fence", "manhole", "sewer", "cage_door", "safehouse_door",
        "bookshelf", "shelf_sliding", "open_trunk", "trunk", "open_from_inside", "break_open", "slide_ramp",
        "raise_ramp", "desk_drawer", "handcuffs", "display", "display_ares", "compartment", "guitar_case",
        "screw_down", "remove_bars", "remove_debris", "cut_tarp", "remove_tarp", "open_lid", "open_case",
        "pickup_case", "hold_close", "hold_open", "pent_hold_close", "pent_hold_open", "invisible_interaction_open",
        "invisible_interaction_close"
    }},
    { key = "mission_crowbar", patterns = {
        "take_crowbar", "pku_crowbar", "pickup_crowbar", "crowbar_stackable", "crowbar_pickup", "gen_pku_crowbar",
        "sah_prop_survivors_pickaxe", "survivors_pickaxe", "pickaxe_pickup", "hold_take_crowbar", "press_take_crowbar",
        "gen_pku_tool_crowbar"
    }},
    { key = "mission_gage", patterns = {
        "gage_assignment", "gage_package", "gage_pku", "gage", "gage_pack", "gage_courier"
    }},
    { key = "mission_planks", patterns = {
        "plank", "board", "wood", "planks_pickup", "stash_planks", "break_planks", "secret_stash_planks"
    }},
    { key = "mission_meth", patterns = {
        "caustic", "hydrogen", "muriatic", "acid", "soda", "methlab", "cloride", "chloride",
        "methlab_bubbling", "methlab_caustic_cooler", "methlab_gas_to_salt", "nail_muriatic_acid",
        "nail_caustic_soda", "nail_hydrogen_chloride", "apply_concoction_paste", "brew",
        "mix_concoction", "take_concoction", "compound_a", "compound_b", "compound_c", "compound_d",
        "sample_valid"
    }},
    { key = "mission_docs", patterns = {
        "evidence", "folder", "paper", "document", "file", "clipboard", "notebook", "blueprint", "manifest",
        "stapler", "puzzle", "stamp", "ledger", "certificate", "intel", "contract", "tape", "flight_recorder",
        "fingerprint", "cupprint", "tag_take_stapler", "corp_papers", "printing_plates", "vit_take_documents",
        "sand_pku_documents", "sand_pku_notepad", "notepad", "passport", "rvd_take_tape", "mcm_prop_evidence",
        "trai_pku_printing_plates", "bex_take_cupprint", "bex_take_record_tape", "tag_prop_office_stapler",
        "note", "take_note", "mark_clues", "clues", "envelope", "search_for_clue", "missing_animal_poster",
        "search_fridge", "search_drawer", "search_toilet", "search_cigar", "search_flightcase", "evidance_rfid",
        "fbi_case", "search_steel_cabinet", "search_cabinet", "search_capsule", "search_cart", "search_washer",
        "search_dumpster", "vit_search", "search_shower"
    }},
    { key = "mission_equipment", patterns = {
        "winch", "winch_part", "winch_hook", "engine", "gasoline", "gas_can", "gas_canister", "parachute",
        "turret_part", "tf2_turret", "tf2_turret_ammo", "turret_ammo", "fireworks", "watertank", "water_tank",
        "ladder", "ladder_bag", "battery", "hydraulic_opener", "disassemble_turret", "unpack_turret", "assemble_turret",
        "falcogini", "drone", "drone_control_helmet", "navigation_device", "survivors_pickaxe", "sandwich",
        "alaska_plane", "helicopter", "prototype", "corp_prototype", "printing_plates", "murky_clothes",
        "gas_can_2", "sand_pku_gasoline", "sand_prop_fireworks", "mcm_prop_drone", "sah_prop_navigation_device",
        "uno_prop_murky_clothes", "bike_part", "chl_puck", "drk_bomb_part", "hospital_veil", "hospital_sentry",
        "blood_sample", "veil", "train_car", "boat", "escape", "zipline", "hook", "wheelbarrow", "cage_bag",
        "equipment_bag", "circuit", "dye", "gps_tracker", "balloon", "camera_tripod", "fusion_reactor", "reaktor",
        "spy_camera", "adrenaline", "laxative", "spike_cake", "paddles", "defibrillator", "diesel", "lifeboat",
        "bugging_device", "bug", "car_jack", "refuel", "horseshoe", "hammer", "mould", "sheriff_star",
        "barrel", "receiver", "stock", "oilsample", "oil_sample", "texas_suit", "handprint", "hand",
        "churros", "mask", "flip_table", "truck", "locomotive", "turret", "decouple", "supplies", "liquid_nitrogen",
        "bottle", "drink", "sleeping_gas", "printer_ink", "plates", "body", "search_tools", "helmet", "repair_wheel",
        "magnet", "turtle", "chimichanga", "device", "wrench", "bridge", "uniform", "pour_liquid", "start_fire",
        "flammable", "scythe", "fertilizer", "symbol", "vlad", "number_sign", "gong", "bell", "cargo", "item",
        "cover", "platform", "resume_test", "stinger", "spikes", "ticket", "approve_req", "chute", "motor",
        "equip", "carpet", "briefcase", "fire_extinguisher", "extinguish", "strap", "ride_the_bike", "pickup_asset",
        "camera", "laser", "move_car", "take_gear", "start_printer", "remove_parts", "place_globe", "signal_mr_blonde",
        "take_unknown", "pick_up", "untie", "remove_rope"
    }},
    { key = "mission_deployables", patterns = {
        "doctor_bag", "first_aid", "ammo_bag", "bodybags_bag", "body_bag", "armor_kit", "sentry_gun",
        "deployable", "ammo_crate", "grenade_crate", "bodybag", "first_aid_kit", "sand_open_first_aid_kit",
        "sentry", "ammo", "bag_deployable"
    }},
}
ESP.ESP_CONFIGS = {
    -- Cops & Civilians
    { key = "cops",                title = "Cops & Guards",                  def = Color(1,    0,    0),    group = "cops",     def_show = true  },
    { key = "civilians",           title = "Civilians",                      def = Color(1,    1,    1),    group = "cops",     def_show = true  },
    { key = "vips",                title = "VIPs & Mission NPCs",            def = Color(1,    0.85, 0),    group = "cops",     def_show = true  },
    { key = "cameras",             title = "Security Cameras",               def = Color(0,    1,    1),    group = "cops",     def_show = true  },
    -- Special Enemies
    { key = "special_dozer",       title = "Bulldozer",                      def = Color(1,    0.4,  0),    group = "specials", def_show = true  },
    { key = "special_taser",       title = "Taser",                          def = Color(0,    0.8,  1),    group = "specials", def_show = true  },
    { key = "special_medic",       title = "Medic",                          def = Color(1,    1,    0),    group = "specials", def_show = true  },
    { key = "special_shield",      title = "Shield & Phalanx",               def = Color(0,    1,    0.5),  group = "specials", def_show = true  },
    { key = "special_sniper",      title = "Sniper & Marksman",              def = Color(1,    0,    0.5),  group = "specials", def_show = true  },
    { key = "special_cloaker",     title = "Cloaker",                        def = Color(0.5,  0,    1),    group = "specials", def_show = true  },
    { key = "special_turret",      title = "SWAT Van & Boss Turrets",        def = Color(1,    0.1,  0.3),  group = "specials", def_show = true  },
    -- Loot Items
    { key = "loot_cash",           title = "Cash, ATMs & Money",             def = Color(0,    0.9,  0.3),  group = "loot",     def_show = true  },
    { key = "loot_drugs",          title = "Drugs (Coke, Meth, Pure)",       def = Color(0.7,  0.2,  1),    group = "loot",     def_show = true  },
    { key = "loot_valuables",      title = "Valuables (Gold, Diamonds, Art)",def = Color(1,    0.85, 0),    group = "loot",     def_show = true  },
    { key = "loot_small",          title = "Deposit Boxes, Safes & Small",   def = Color(0.85, 0.75, 0.3),  group = "loot",     def_show = true  },
    { key = "loot_bags",           title = "Loose Bags & Carried Loot",      def = Color(0.2,  0.6,  1),    group = "loot",     def_show = true  },
    -- Mission Items & Objectives
    { key = "mission_c4",          title = "C4, Charges & Explosives",       def = Color(1,    0.4,  0.1),  group = "mission",  def_show = true  },
    { key = "mission_ecm",         title = "ECM Jammer Doors & Panels",      def = Color(0,    0.9,  0.9),  group = "mission",  def_show = true  },
    { key = "mission_key",         title = "Keycards, Keys & Readers",       def = Color(1,    1,    0),    group = "mission",  def_show = true  },
    { key = "mission_drills",      title = "Drills, Saws & Cutters",         def = Color(1,    0.2,  0.2),  group = "mission",  def_show = true  },
    { key = "mission_power",       title = "Power Boxes, Breakers & Valves", def = Color(1,    0.6,  0),    group = "mission",  def_show = true  },
    { key = "mission_computer",    title = "Computers, Keypads & Hacks",     def = Color(0,    0.7,  1),    group = "mission",  def_show = true  },
    { key = "mission_doors",       title = "Doors, Gates, Shutters & Cages", def = Color(0.85, 0.85, 0.85), group = "mission",  def_show = true  },
    { key = "mission_lockpick",    title = "Lockpicks & Pickable Locks",     def = Color(0.7,  0.7,  0.7),  group = "mission",  def_show = false },
    { key = "mission_docs",        title = "Evidence, Documents & Intel",    def = Color(0.8,  0.4,  1),    group = "mission",  def_show = true  },
    { key = "mission_meth",        title = "Meth Lab Ingredients",           def = Color(0,    1,    0.8),  group = "mission",  def_show = true  },
    { key = "mission_crowbar",     title = "Crowbars & Pickaxes",            def = Color(1,    0.5,  0),    group = "mission",  def_show = true  },
    { key = "mission_gage",        title = "Gage Packages",                  def = Color(0.2,  0.9,  0.2),  group = "mission",  def_show = true  },
    { key = "mission_planks",      title = "Wooden Planks & Barricades",     def = Color(0.7,  0.5,  0.3),  group = "mission",  def_show = true  },
    { key = "mission_equipment",   title = "Mission Gear, Tools & Parts",    def = Color(0.3,  0.8,  1),    group = "mission",  def_show = true  },
    { key = "mission_deployables", title = "Deployables (Doctor/Ammo/FAK)",  def = Color(0.2,  1,    0.5),  group = "mission",  def_show = true  },
}

ESP.GROUP_LABELS = {
    cops     = "Cops & Civilians",
    specials = "Special Enemies",
    loot     = "Loot Items",
    mission  = "Mission Items & Objectives",
}
ESP.ALL_ESP_KEYS = {}
for _, cfg in ipairs(ESP.ESP_CONFIGS) do
    ESP.ALL_ESP_KEYS[#ESP.ALL_ESP_KEYS + 1] = "nt_esp_" .. cfg.key
end
ESP.NPC_KEYS = ESP.ALL_ESP_KEYS
ESP.ALL_ITEM_KEYS = ESP.ALL_ESP_KEYS
-- Known VIP & Mission NPC unit paths (mapped to Idstring keys for 100% reliable matching)
ESP.VIP_UNIT_PATHS = {
    -- Bank Managers
    "units/payday2/characters/civ_female_bank_manager_1/civ_female_bank_manager_1",
    "units/payday2/characters/civ_male_bank_manager_1/civ_male_bank_manager_1",
    "units/payday2/characters/civ_male_bank_manager_2/civ_male_bank_manager_2",
    "units/payday2/characters/civ_male_bank_manager_3/civ_male_bank_manager_3",
    "units/payday2/characters/civ_male_bank_manager_4/civ_male_bank_manager_4",
    "units/payday2/characters/civ_male_bank_manager_5/civ_male_bank_manager_5",
    "units/payday2/characters/civ_male_bank_manager_hostage/civ_male_bank_manager_hostage",
    "units/pd2_dlc1/characters/civ_male_bank_manager_2/civ_male_bank_manager_2",
    "units/pd2_dlc_bex/characters/civ_male_bex_bank_manager/civ_male_bex_bank_manager",
    "units/pd2_dlc_fex/characters/civ_male_fex_manager/civ_male_fex_manager",

    -- Escorts, Pilots, Inside Men, Scientists, Bosses & Mission VIPs
    "units/payday2/characters/civ_male_drunk_pilot/civ_male_drunk_pilot",
    "units/payday2/characters/civ_male_pilot/civ_male_pilot",
    "units/payday2/characters/civ_male_pilot_1/civ_male_pilot_1",
    "units/payday2/characters/civ_male_mitch/civ_male_mitch",
    "units/payday2/characters/civ_male_escort_1/civ_male_escort_1",
    "units/payday2/characters/civ_male_escort_2/civ_male_escort_2",
    "units/payday2/characters/civ_male_escort_3/civ_male_escort_3",
    "units/payday2/characters/civ_male_escort_4/civ_male_escort_4",
    "units/payday2/characters/civ_male_escort_5/civ_male_escort_5",
    "units/pd2_dlc_spa/characters/civ_male_spa_vip/civ_male_spa_vip",
    "units/pd2_dlc_spa/characters/civ_male_spa_vip_hurt/civ_male_spa_vip_hurt",
    "units/pd2_dlc_peta/characters/civ_male_boris/civ_male_boris",
    "units/pd2_dlc_friend/characters/civ_male_inside_man/civ_male_inside_man",
    "units/pd2_dlc_bex/characters/civ_male_inside_man/civ_male_inside_man",
    "units/pd2_dlc_dah/characters/civ_male_cfo/civ_male_cfo",
    "units/pd2_dlc_rvd/characters/civ_male_taxman/civ_male_taxman",
    "units/pd2_dlc_rvd/characters/civ_male_taxman_tied/civ_male_taxman_tied",
    "units/pd2_dlc_born/characters/civ_male_biker_mechanic/civ_male_biker_mechanic",
    "units/pd2_dlc_chca/characters/civ_male_chca_boss/civ_male_chca_boss",
    "units/pd2_dlc_mex/characters/civ_male_mex_boss/civ_male_mex_boss",
    "units/pd2_dlc_trai/characters/civ_male_trai_prisoner/civ_male_trai_prisoner",
    "units/pd2_dlc_sand/characters/civ_male_sand_president/civ_male_sand_president",
    "units/pd2_dlc_des/characters/civ_male_scientist_01/civ_male_scientist_01",
    "units/pd2_dlc_des/characters/civ_male_scientist_02/civ_male_scientist_02",
    "units/pd2_dlc_des/characters/civ_female_scientist_01/civ_female_scientist_01",
    "units/pd2_dlc_des/characters/civ_female_scientist_02/civ_female_scientist_02",
    "units/pd2_mcmansion/characters/ene_male_hector_1/ene_male_hector_1",
    "units/pd2_dlc_tag/characters/ene_male_commissioner/ene_male_commissioner",
    "units/payday2/characters/ene_gang_mobster_boss/ene_gang_mobster_boss",
}

ESP.VIP_UNIT_KEYS = {}
for _, path in ipairs(ESP.VIP_UNIT_PATHS) do
    ESP.VIP_UNIT_KEYS[Idstring(path):key()] = true
end
