# NiceTrainer
> The ultimate modular cheat engine, trainer & modding framework for **PAYDAY 2** (SuperBLT).

![PAYDAY 2](https://img.shields.io/badge/PAYDAY%202-Compatible-blue.svg)
![SuperBLT](https://img.shields.io/badge/SuperBLT-Required-orange.svg)
![UI Engine](https://img.shields.io/badge/UI-Native%20Diesel%20Canvas-green.svg)
![Architecture](https://img.shields.io/badge/Framework-Modular%20Event--Driven-purple.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

---

## Overview

**NiceTrainer** is a next-generation trainer and extensible framework built specifically for **PAYDAY 2**. Built on a clean **event-driven, declarative architecture**, NiceTrainer completely separates the low-level engine primitives from the individual cheat modules. 

It features a custom **Native Diesel GUI Engine** rendering sleek dark-themed UI components directly into Payday 2's renderer without external dependencies. This framework comes fully equipped with animated toasts, real-time keybinding listeners, modal dialogs, and persistent state saving.

---

## Key Features

### Account & Progression (`Account`)
- **Profile & Spoofing**: In-game Name Spoofer with Payday glyph icon selector (`Skull`, `Ghost`, `Crown`, `Dollar`, `Music`), synchronized live with Steam peers.
- **Anti-Cheat Audit & Spoofing**: Live modal auditing your active equipment, skills, and cosmetics to verify safe client status. Includes a network-safe legendary skin bypass to prevent 'Invisible Weapon' glitches in vanilla lobbies.
- **DLC & Skin Unlockers**: Selective DLC unlocker (with Outfit Spoof protection) and Weapon/Armor Skin unlocker in pristine Mint quality.
- **Skills & Perk Decks**: Instant Unlock All Skills, Max Perk Decks, Silent Passive Perks, and **Universal Perk Throwables** (Kingpin Injector, Hacker Pocket ECM, Sicario Smoke Screen, Tag Team Gas Dispenser, Stoic Hip Flask on any build).
- **Finances & Safehouse**: Custom Offshore and Spending Cash inputs/presets, Continental Coins, instant Tier 3 Safehouse Upgrades, Safehouse Trophies, auto-complete Side Jobs and Daily Challenges.
- **Black Market & Inventory**: Granular unlocker for Weapons, Mods, Masks, Materials, Textures, Colors, Melee, Grenades, and Armors; $0 Free Market purchases, 500 Inventory Slots, and No Mod Limits.
- **Achievements & Crime Spree**: 1-Click Steam & In-Game Achievement unlocker, Crime Spree level and reward boost.

### Player & Movement (`Player`)
- **Modern Movement Engine (PD3 Style)**: Experience advanced parkour mechanics including **Slide**, **Vaulting**, and **Ledge Grabbing**, seamlessly integrated with the vanilla physics engine.
- **Survivability**: God Mode, Infinite Stamina, No Fall Damage, Auto-Heal, Unlimited Revives.
- **Movement Hacks**: Customizable Speed Multiplier, High Jump Multiplier, Bunny Hop (Bhop) engine, Noclip with directional camera control, Run in all directions, Sprint with any loot bag.
- **Interactions**: Instant Interaction, Instant Deployment, Fast Mask-On, No Carry Cooldown, Unlimited Equipment (never depletes ECMs, ammo bags, doctor bags, or body bags).
- **Wall Bypasses**: **Interact Through Walls** (bypasses raycast line-of-sight for keycard readers, doors, computers, loot) and **Full Interaction Freedom** (shoot, aim, reload, melee, and move 360° without breaking interaction progress).
- **Lock Smasher**: Break open doors and deposit boxes using melee weapons, saws, or bullet piercing.

### Gunplay & Combat (`Player`)
- **Aimbot Engine**: High-performance Aimbot with adjustable FOV cone, distance limits, visible-only filtering, bone targeting (Head/Body), and Triggerbot.
- **Weapon Mechanics**: Unlimited Ammo, Zero Recoil, Zero Spread, Instant Reload, Instant Weapon Swap, Rapid Fire Multiplier, Shoot Through Walls (pierces concrete, shields, and enemies).
- **Damage Multipliers**: Custom Bullet & Melee Damage Multipliers (1x–1000x), One-Shot Kill, Extended Melee Range (20m strike distance), Zero Melee Delay.
- **Explosions & Fire**: Adjust explosive radius, disable self-damage, and modify fire damage over time.

### Drills & Sentries (`Player`)
- **Drills & Machinery**:
  - **Instant Drilling**: All drills, saws, and hacking devices finish in 0.01s.
  - **Auto-Restart (Auto-Service)**: Jammed drills repair themselves automatically anywhere on the map in real-time.
  - **Drills Never Jam**: Completely blocks jam mechanics.
  - **Silent Drills**: Drills make 0 sound and have 0 alert radius for stealth.
  - **Custom Timer Input**: Set all active drills to custom timers (0s, 5s, 10s, 30s) and sync to peers.
- **Sentry Gun Overhaul**:
  - Invulnerable Sentries, Infinite Ammo, Sentry Shield Piercing AI, and Sentry Overclock (1000°/s spin velocity, instant lock-on, custom damage multiplier).

### Stealth & NPC AI (`Stealth` & `NPC AI`)
- **Stealth Tools**: Infinite Pagers, Auto-Answer Pagers, Steal Pager on Melee, No Civilian Kill Penalty, Infinite Body Bags & Cable Ties, Cameras Die on Detection, Break All Cameras, Auto-Tie Alerted Civilians, Silent Kill Alerted Guards, Invisible to AI, Casing Mode Mask-Off Hacking.
- **Stealth GPS & ECM Timers**: Dedicated HUD elements for stealth, tracking ECM durations precisely and pinpointing guard/objective locations.
- **AI Manipulation**: Freeze All AI, Cops Don't Shoot, Prevent Panic Buttons, Convert All Enemies, Infinite/Instant Jokers, Long Distance Conversion, Freeze/Tie/Kill Civilians, Nav Pathing visualization.

### Visuals & ESP (`Visuals`)
- **X-Ray V2 Engine**: Standalone visual engine featuring **3D Anatomical Bone Skeleton ESP**, 2D Corner & Full Bounding Boxes, smooth gradient **Health & Armor Bars**, Head Dots, horizontal Aim Rays, and Snaplines / Tracers.
- **Classic X-Ray ESP**: High-performance outlines for Enemies, Civilians, VIPs, Pagers, Security Cameras, Loot / Bag Stashes, and Gage Packages with intelligent dead-body cleanup.
- **HUD & Perspectives**: Stealth Telemetry Radar, Third-Person (3P) mode with shoulder camera offset, customizable Field of View (FOV) Multiplier, and **Dynamic HUD Compass**.
- **Action Radials**: Quick Radial Action Menu for rapid in-game actions without opening the main menu.
- **Vision Shaders & Weather**: Night Vision, Thermal Vision, Anti-Flashbang, Smoke removal, custom interactive RGB Laser Color, Suit Flashlight toggles, and Post-Processing Weather controls.

### Heist Solvers & Planners (`Heist` & `Preplanning`)
- **Puzzle Solvers (Heist Codes)**: Auto-scans notebooks, computer screens, pressure gauges, and environment data to instantly solve *Big Oil*, *Cook Off*, *Election Day*, *First World Bank*, *Golden Grin*, *Hotline Miami*, and *The Secret*.
- **Pre-planning**: 100% Free pre-planning assets, Infinite Favors, Instant drawing tools, Host Plan Override.
- **Carry Stacker**: Stack infinite loot bags and equipment (Ammo/Doctor bags, Sentries, Trip Mines), toggle weight penalties, extreme throw distance, remote bag securing.

### Entity & World Management (`Spawner`, `Team`, `World`)
- **NPC Spawner**: Spawn friendly or hostile SWAT, Heavies, Snipers, Bulldozers, Cloakers, Medics, Civilians, and Jokers directly at your crosshair.
- **Deployables & Vehicles**: Spawn Doctor Bags, Ammo Bags, Sentries, Body Bags, First Aid Kits, and drivable vehicles (Muscle Cars, Forklifts, Longfellows, Golf Carts).
- **Crew Buffs**: Grant God Mode, Unlimited Ammo, and Damage Multipliers to human teammates and AI bots. Remote Revive, Teleportation, and Team Speed Multipliers.
- **Interactive World**: Open All Doors, Unlock ATMs & Deposit Boxes, Open All Containers, Hack All Computers, Cut Fences, Insert Keycards, Place Shaped Charges/C4.
- **Motion Paths & Boundaries**: Speed up moving cranes/boats, disable instant-death killzones, and view/remove Invisible Walls.

### Utilities & Settings (`Misc` & `Settings`)
- **Chat Translator**: Real-time in-game auto-translation of peer chat messages into your preferred language.
- **Anti-Griefing**: Anti-Crash packet filters, Mod Hider (bypasses NGBTO/VanillaHUD+ mod lists), and slow-motion reversal.
- **Configuration & Theme**: Integrated Keybind Manager, dynamic UI theme customizer, and full settings persistence.

---

## Installation

1. Install **[SuperBLT](https://superblt.znix.xyz/)** (the modern C++ hook for PAYDAY 2).
2. Download or clone **NiceTrainer**:
   ```bash
   git clone https://github.com/NiceATC/NiceTrainer.git
   ```
3. Extract the `NiceTrainer` folder into your PAYDAY 2 `mods/` directory:
   ```
   PAYDAY 2/
   └── mods/
       └── NiceTrainer/
           ├── mod.txt
           ├── init.lua
           ├── framework/
           └── modules/
   ```
4. Launch PAYDAY 2.

---

## Controls & Default Hotkeys

| Hotkey | Action |
| :--- | :--- |
| **`F1`** (Default) | Open / Close NiceTrainer In-Game Menu |
| **Mouse Left Click** | Interact / Toggle / Adjust Sliders / Open Modals |
| **Mouse Hover** | Display Context-Sensitive Feature Tooltips |
| **Custom Keybinds** | Click **"BIND"** next to any feature in the menu and press your desired key! |

---

## Architecture & Developer Extensibility

NiceTrainer was designed from day one to be easily extended with custom modules.

```lua
-- Example: Creating a new cheat in 3 lines of code!
NiceTrainer:RegisterAction("Player", {
    type     = "toggle_slider",
    category = "Custom Hacks",
    badge    = "client",
    id       = "my_super_hack",
    text     = "Super Speed",
    default  = false,
    min      = 1,
    max      = 10,
    slider_default = 2,
    slider_id = "my_super_hack_speed",
    callback = function(state, speed_val)
        -- Your logic here!
    end
})
```

For full documentation on creating custom tabs, UI components (`button`, `toggle`, `toggle_slider`, `toggle_settings`, `multichoice`, etc.), modals, and hooks, check out **[Documentation.md](Documentation.md)**.

---

## Beta Status & Community Collaboration

- **Active Beta**: NiceTrainer is currently in active Beta. While all core systems and features have been tested, you may encounter occasional edge cases or bugs across specific heists, mutators, or complex mod loadouts.
- **Continuous Refinement**: This project is designed as an evolving, community-driven framework. We will be actively polishing, refactoring, and expanding functionality based on your feedback, bug reports, and pull requests.
- **Feedback & Issues**: If you run into an error, crash, or unexpected behavior, please provide your SuperBLT log (`mods/logs/`), game state, and reproduction steps. Every piece of feedback helps improve the trainer!

---

## Credits & Community Attributions

- **NiceATC** — Framework Engine, UI Architecture & Action Registry
- **HexTrip (HexTrainer)** — Dexterity mechanics, progression logic & anti-cheat research
- **Baddog-11, baldwin & Pirate Perfection Team** — Classic drills, sentries, AI & gameplay hooks
- **Pierre Josselin (Ultimate Trainer / UT6)** — Native Diesel UI concepts & utility foundations
- **KILLBASE** — Anti-griefing, stealth triggers & mission skip methods
- **Offyerrocker** — HUD Compass Standalone & KineticHUD element design
- **Complete All Side Jobs Community** — Safehouse & side job completion routines
- **Znixian (SuperBLT) & Luffy (BeardLib)** — PAYDAY 2 modding foundations & hook systems
- **HopLib Community** — Unit introspection & entity categorization logic

---

## DMCA, Copyright & Fair Use Statement

- If you own content used or referenced in this project and want it removed or modified, please contact us with the relevant details. Valid removal requests will be reviewed and promptly addressed.
- This project is not affiliated with, endorsed by, or associated with Overkill Software or Starbreeze Studios.
- Created with care for the entire community with the sole purpose of learning, sharing, and advancing modding tools. There is zero intention to steal, misattribute, or take undue credit for the community's research and work.
- *NiceTrainer is developed for educational, private lobby, and singleplayer research purposes. Please play respectfully in public matches.*

---

## License

This project is licensed under the [MIT License](LICENSE).
