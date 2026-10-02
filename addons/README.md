# NiceTrainer Addons System

The **Addons System** allows you to add custom scripts, hacks, or brand-new tabs to NiceTrainer **without modifying any core files**.

---

## How to Install an Addon

You can install addons in two ways:

### 1. Single-File Addon (`.lua`)
Simply drop your script file directly into the `addons/` folder:
```
addons/
  └── my_speed_hack.lua
```
NiceTrainer will automatically detect and execute it on startup.

### 2. Folder Addon (Multi-file / Mod Pack)
If your addon has multiple files, put it in its own subfolder with an `init.lua`, `main.lua`, or `addon.lua`:
```
addons/
  └── my_awesome_addon/
        ├── init.lua
        ├── config.lua
        └── logic.lua
```
NiceTrainer will automatically run the entrypoint (`init.lua`).

---

## How to Write an Addon

### Example 1: Add a Feature to an Existing Tab
You can inject buttons, toggles, sliders, or modals into existing tabs (`Player`, `Visuals`, `Stealth`, `World`, `Settings`, etc.):

```lua
-- addons/my_feature.lua

NiceTrainer:RegisterAction("Player", {
    type     = "toggle",
    category = "My Custom Category",
    id       = "addon_god_jump",
    text     = "Super Jump",
    tooltip  = "Increases jump height drastically",
    default  = false,
    callback = function(state)
        if state then
            NiceTrainer:Toast("Super Jump Enabled!")
        else
            NiceTrainer:Toast("Super Jump Disabled.")
        end
    end
})
```

---

### Example 2: Create a Brand-New Tab in NiceTrainer
You can register an entirely custom tab on the sidebar:

```lua
-- addons/custom_tab.lua

-- 1. Register the new Tab
Hooks:Add("NiceTrainer_InitTabs", "NiceTrainer_Addon_CustomTab", function(trainer)
    trainer:CreateTab("MyAddons", { show_in = "all" }, function(tr, name)
        tr:BuildRegisteredActions(name)
    end)
end)

-- 2. Register Actions inside the new Tab
NiceTrainer:RegisterAction("MyAddons", {
    type     = "button",
    category = "General",
    text     = "Say Hello",
    tooltip  = "Prints a greeting message",
    callback = function()
        NiceTrainer:Toast("Hello from my custom addon!", Color.cyan)
    end
})
```

---

## Supported Action Types
- `button`
- `toggle`
- `slider`
- `multichoice`
- `inputbox`
- `modal`
- `colorpicker`
- `toggle_settings`
- `toggle_multichoice`
- `keybind`

*Check `GEMINI.md` in the root folder for complete component parameters and syntax.*
