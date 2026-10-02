# NiceTrainer Framework & API Documentation 

**NiceTrainer** is a modular, event-driven cheat engine and modding framework designed specifically for **PAYDAY 2 (SuperBLT)**. Engineered for high scalability, clean isolation, and zero-conflict multi-module architectures, NiceTrainer provides a native GUI system, declarative action registry, persistent settings management, integrated keybinding engine, and an extensive suite of low-level hooks.

---

## 1. System Architecture ️

The framework strictly separates core engine operations from game modifications:

```
NiceTrainer/
├── mod.txt                  # SuperBLT metadata, updates & hook declarations
├── init.lua                 # Main entrypoint & module loader
├── framework/               # Core Framework Engine (NEVER edit for adding hacks)
│   ├── core.lua             # Core namespace, initialization & lifecycle events
│   ├── registry.lua         # Declarative Action & Tab Registry
│   ├── components.lua       # Native Diesel UI component builders
│   ├── ui.lua               # Window manager, sidebar, canvas & layout rendering
│   ├── toast.lua            # Non-blocking async notification queue
│   ├── utils.lua            # Unit inspection, math & Diesel helpers
│   ├── storage.lua          # Auto-serializing JSON settings manager
│   ├── keybinds.lua         # Global hotkey listener and binding dispatcher
│   └── modals.lua           # Overlay modal dialogs (lists, sliders, inputs, color)
└── modules/                 # Modular Feature Packages (Tabs & Action Scripts)
    ├── account/             # Profile, DLCs, Skins, Level, Infamy, Safehouse & Currency
    ├── player/              # Movement, God Mode, Gunplay, Drills, Sentries, Interactions
    ├── stealth/             # Pagers, Cameras, Civilians & Stealth QoL
    ├── npc_ai/              # Enemy AI, Crowd Control, Conversions & Panic Buttons
    ├── carrystacker/        # Bag & Equipment Stacking, Secure Loot
    ├── visuals/             # High-performance X-Ray ESP, FOV & HUD Tweaks
    ├── world/               # Map interactions, Door unlockers, Invisible walls & Time of day
    ├── preplanning/         # Free assets, Instant draw, Favors unlocker
    ├── misc/                # Gambling, Chat Translator, Utility tools
    └── settings/            # Anti-Cheat Audit, Anti-Crash, Hotkeys & Customization
```

### Core Architecture Principles:
1. **Core / Module Decoupling**: Core framework files in `framework/` are immutable and engine-only. All cheats and features live in `modules/<module_name>/`.
2. **Action Registry Pattern**: No hardcoded UI widgets. Features register declaratively via `NiceTrainer:RegisterAction()`, and the framework automatically calculates layout flow, pagination, scrollbars, state persistence, and keybind listeners.
3. **Safe Rehooking & Graceful Fallbacks**: Features use safe method wrappers, backup tables (`_orig_*`), and safe execution (`pcall`) to prevent game crashes during mid-game state transitions.

---

## 2. Creating a New Module (Tab) 

To add a new tab to NiceTrainer:

1. Create directory: `modules/<module_name>/`
2. Create `modules/<module_name>/tab.lua` and register the tab using the lifecycle hook:

```lua
Hooks:Add("NiceTrainer_InitTabs", "NiceTrainer_<ModuleName>Tab", function(trainer)
    trainer:CreateTab("ModuleName", { show_in = "all" }, function(tr, name)
        tr:BuildRegisteredActions(name)
    end)
end)
```

### `show_in` Display Contexts:
* `"all"`: Visible in all game states (Main Menu, Lobby, In-Game, Pre-planning).
* `"menu"`: Visible only in the main menu (Crime.net / Main Title).
* `"heist"` or `"game"`: Visible only during an active heist (Briefing and live gameplay).
* `"preplanning"`: Visible exclusively during the heist pre-planning / loadout phase (`ingame_waiting_for_players`).

3. Create your module loader: `modules/<module_name>/init.lua` and load `tab.lua` alongside your action scripts.
4. Load your module in the root `init.lua`:
```lua
dofile(ModPath .. "modules/<module_name>/init.lua")
```

---

## 3. Registering Features (Action Registry) 

Cheats and tools are registered using `NiceTrainer:RegisterAction(tab_name, definition)`. The framework parses component schemas and handles rendering, clicks, states, and saves automatically.

### Universal Action Parameters

Every action supports the following metadata fields:

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `type` | `string` | **Required** | Component type (`button`, `toggle`, `slider`, `inputbox`, `multichoice`, `modal`, `colorpicker`, `toggle_settings`, `toggle_multichoice`, `toggle_slider`, `keybind`). |
| `category` | `string` | `"General"` | Categorization header. Automatically creates a categorized subsection divider. |
| `text` | `string` | **Required** | Display label of the action. |
| `id` | `string` | `nil` | Unique identifier for state persistence in `NiceTrainer.Settings[id]`. |
| `tooltip` | `string` | `nil` | Tooltip rendered on the floating helper pane on mouse hover. |
| `badge` | `string` | `nil` | Status tag rendered beside the title: `"client"`, `"host"`, `"safe"`, `"risk"`, `"stealth"`, `"loud"`. |
| `no_bind` | `boolean` | `false` | When `true`, hides the quick hotkey bind button on toggles (recommended for permanent account unlocks). |
| `default` | `any` | `false`/`nil` | Default value on initial startup before configuration load. |
| `callback` | `function` | `nil` | Primary action handler invoked on interaction. |

---

## 4. UI Component Reference 

### 1. Button (`button`)
A one-shot interactive trigger button.

```lua
NiceTrainer:RegisterAction("Player", {
    type            = "button",
    category        = "Survivability",
    badge           = "client",
    text            = "Instant Full Heal",
    tooltip         = "Instantly restores your health, armor, and revives count to maximum.",
    action_btn_text = "Heal",
    callback        = function()
        local player = managers.player and managers.player:player_unit()
        if player and alive(player) then
            player:character_damage():replenish()
            NiceTrainer:Toast("Health and armor fully replenished!")
        end
    end
})
```

---

### 2. Toggle Switch (`toggle`)
A persistent boolean switch with built-in state saving and optional per-action keybinding support.

```lua
NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "Combat",
    badge    = "client",
    id       = "god_mode",
    text     = "God Mode (Invulnerable)",
    tooltip  = "Makes your character completely immune to all forms of damage.",
    default  = false,
    callback = function(state)
        local player = managers.player and managers.player:player_unit()
        if player and alive(player) and player:character_damage() then
            player:character_damage():set_invulnerable(state)
        end
    end
})
```

---

### 3. Slider (`slider`)
A continuous numerical slider with fine-tuned drag controls.

```lua
NiceTrainer:RegisterAction("Visuals", {
    type      = "slider",
    category  = "Camera & HUD",
    badge     = "safe",
    id        = "fov_multiplier",
    text      = "Field of View (FOV)",
    tooltip   = "Adjusts your camera FOV beyond default game limits.",
    min       = 60,
    max       = 140,
    step      = 1,
    default   = 90,
    callback  = function(val)
        -- 'val' is a number
        managers.user:set_setting("fov_multiplier", val / 75)
    end
})
```

---

### 4. Multi-Choice Selector (`multichoice`)
A horizontal step selector (`< Option >`) paired with an optional trigger button.

```lua
NiceTrainer:RegisterAction("Player", {
    type            = "multichoice",
    category        = "Equipment",
    badge           = "client",
    id              = "deployable_selector",
    text            = "Select Deployable Item",
    tooltip         = "Choose an equipment type to spawn at your position.",
    options         = {"Ammo Bag", "Doctor Bag", "First Aid Kit", "Body Bag Case", "Sentry Gun"},
    default         = 1,
    action_btn_text = "Spawn Item",
    callback        = function(idx, val)
        -- idx: integer (1-5), val: string ("Ammo Bag")
        NiceTrainer:Toast("Spawned: " .. val)
    end
})
```

---

### 5. Numerical Input Box (`inputbox`)
A native text field intercepting keyboard input to specify exact numeric values.

```lua
NiceTrainer:RegisterAction("Account", {
    type            = "inputbox",
    category        = "Finances",
    badge           = "safe",
    id              = "custom_spending_cash",
    text            = "Add Custom Spending Cash",
    tooltip         = "Enter the exact amount of spending cash you want to credit.",
    min             = 0,
    max             = 999999999999,
    default         = 10000000,
    action_btn_text = "Add Cash",
    callback        = function(amount)
        if managers.money then
            managers.money:_add_to_total(amount)
            NiceTrainer:Toast(string.format("Added $%s Spending Cash!", managers.money:add_decimal_marks_to_string(tostring(amount))))
        end
    end
})
```

---

### 6. Modal List Dialog (`modal`)
Opens a full-screen dimmed popup overlay featuring a searchable/scrollable list of items.

```lua
NiceTrainer:RegisterAction("CarryStacker", {
    type            = "modal",
    category        = "Spawners",
    badge           = "client",
    id              = "spawn_bag_selector",
    text            = "Spawn Loot Bag",
    modal_title     = "Select Bag Type to Spawn",
    action_btn_text = "Browse Bags...",
    options         = {
        { text = "Money", value = "money" },
        { text = "Gold", value = "gold" },
        { text = "Diamonds", value = "diamonds" },
        { text = "Pure Methamphetamine", value = "meth" },
        { text = "Cocaine", value = "coke" },
        { text = "Ancient Roman Armor", value = "armor" }
    },
    callback        = function(val, text)
        -- val: "gold", text: "Gold"
        NiceTrainer:Toast("Spawning bag: " .. text)
    end
})
```

---

### 7. Native Color Picker (`colorpicker`)
Opens an RGB / Hex interactive color palette.

```lua
NiceTrainer:RegisterAction("Visuals", {
    type     = "colorpicker",
    category = "Laser Customization",
    badge    = "client",
    id       = "laser_color",
    text     = "Weapon Laser Color",
    tooltip  = "Sets custom color for player and teammate lasers.",
    default  = "#00FFCC",
    callback = function(color_obj, hex_string)
        -- color_obj: Color(r, g, b)
        -- hex_string: "#00FFCC"
    end
})
```

---

### 8. Hybrid Toggle + Settings (`toggle_settings`)
Combines an On/Off toggle switch with a secondary settings gear icon `[...]` to open detailed sub-options.

```lua
NiceTrainer:RegisterAction("Player", {
    type              = "toggle_settings",
    category          = "Movement",
    badge             = "client",
    id                = "speed_multiplier_toggle",
    text              = "Speed Multiplier",
    tooltip           = "Increases movement speed. Click [...] to adjust the multiplier.",
    default           = false,
    callback          = function(state)
        -- Enable or disable speed boost
    end,
    settings_callback = function()
        NiceTrainer:ShowSliderModal("Movement Speed Multiplier", 1, 10, tonumber(NiceTrainer.Settings.speed_mult) or 2, function(val)
            NiceTrainer.Settings.speed_mult = val
            NiceTrainer:Save()
            NiceTrainer:Toast("Speed multiplier set to " .. val .. "x")
        end)
    end
})
```

---

### 9. Toggle Multi-Choice (`toggle_multichoice`)
A compact dual control on a single row: a boolean checkbox alongside an option selector (`< Option >`).

```lua
NiceTrainer:RegisterAction("Player", {
    type            = "toggle_multichoice",
    category        = "Interactions",
    badge           = "client",
    id              = "lock_smasher",
    text            = "Lock Smasher",
    tooltip         = "Break locks instantly using melee strikes or power tools.",
    default         = false,
    options         = {"Power Tools & Saws Only", "All Melee Weapons", "Gunfire Piercing"},
    choice_default  = 2,
    choice_id       = "lock_smasher_mode",
    callback        = function(state) end,
    choice_callback = function(idx, val) end
})
```

---

### 10. Toggle Slider (`toggle_slider`)
A compact dual control on a single row: a boolean checkbox alongside a numerical slider.

```lua
NiceTrainer:RegisterAction("Visuals", {
    type            = "toggle_slider",
    category        = "HUD Adjustments",
    badge           = "safe",
    id              = "hud_scaling_enabled",
    text            = "HUD Scale",
    tooltip         = "Enable custom HUD scaling and drag the slider to adjust.",
    default         = false,
    min             = 50,
    max             = 150,
    slider_default  = 100,
    slider_id       = "hud_scaling_value",
    callback        = function(state, slider_val) end,
    slider_callback = function(slider_val, state) end
})
```

---

### 11. Global Hotkey (`keybind`)
Dedicated keyboard interceptor allowing players to bind arbitrary functions to keyboard hotkeys.

```lua
NiceTrainer:RegisterAction("Settings", {
    type     = "keybind",
    category = "Global Hotkeys",
    id       = "hotkey_noclip",
    text     = "Toggle Noclip Keybind",
    default  = "",
    callback = function()
        NiceTrainer.Settings.noclip = not NiceTrainer.Settings.noclip
        NiceTrainer:Toast("Noclip: " .. (NiceTrainer.Settings.noclip and "ON" or "OFF"))
    end
})
```

---

## 5. Global Utilities & Runtime API 

NiceTrainer exposes helper methods globally on the `NiceTrainer` table:

### Notification System
```lua
NiceTrainer:Toast(message, [duration_seconds])
```
*Dispatches a non-intrusive floating toast notification with automatic queueing.*

### Game State Detection
```lua
NiceTrainer:IsInHeist()   -- Returns true if actively in a heist or briefing
NiceTrainer:IsInMenu()    -- Returns true if in the Main Menu
NiceTrainer:IsHost()      -- Returns true if local player is the lobby Host
```

### Persistence Engine
```lua
NiceTrainer:Save()        -- Serializes NiceTrainer.Settings to disk (mods/saves/NiceTrainer.txt)
NiceTrainer:Load()        -- Deserializes stored configurations into NiceTrainer.Settings
```

### Unit & AI Introspection (HopLib Engine)
```lua
local info = NiceTrainer:GetUnitInfo(unit)
-- Returns:
-- {
--     name   = "Heavy SWAT",
--     type   = "enemy",     -- "player", "team_ai", "enemy", "civilian", "joker"
--     health = 100,
--     unit   = <Unit>
-- }
```

### Modal Helpers
```lua
NiceTrainer:ShowModal(title, options_table, callback)
NiceTrainer:ShowSliderModal(title, min, max, default, callback)
NiceTrainer:ShowInputModal(title, default, callback)
NiceTrainer:ShowConfirmModal(title, message, on_confirm_callback)
```

---

## 6. Development Best Practices 

1. **State Persistence**: Always provide a unique `id` when creating toggles or settings so values persist across game restarts.
2. **Hook Cleanup**: Always store references to original engine functions in module-scoped or trainer tables (`NiceTrainer._orig_*`) to enable clean restoration when toggled off.
3. **Session Auto-Restoration**: Connect persistent in-game toggles to `BaseNetworkSessionOnLoadComplete`:
```lua
Hooks:Add("BaseNetworkSessionOnLoadComplete", "NiceTrainer_MyModule_OnLoad", function()
    if NiceTrainer.Settings.my_toggle_id then
        apply_my_toggle(true)
    end
end)
```
4. **No Direct Framework Modifications**: Keep all custom logic inside `modules/`. Never alter `framework/` files.
