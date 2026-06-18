# OmniBar (3.3.5a backport)
OmniBar is an _extremely lightweight_ addon that tracks enemy cooldowns.

![OmniBar](http://i.imgur.com/p9DjSOh.png)

This is a backport of [OmniBar](https://github.com/jordonwow/omnibar) to the
original **Wrath of the Lich King 3.3.5a** client (interface `30300`). It runs
on a stock 3.3.5a core with **no extra APIs** — every modern API the upstream
addon relies on is shimmed or rewritten for 3.3.5a.

## Installation
1. Copy this folder into `Interface\AddOns\`.
2. Make sure the folder is named **`OmniBar`** (so `OmniBar.toc` loads) — an
   identical **`OmniBar_Wrath.toc`** is also included if you prefer the folder to
   be named `OmniBar_Wrath`. The 3.3.5a client loads the `.toc` whose name
   matches the folder, so you only need one of them.
3. All required libraries (Ace3, LibDeflate, …) are embedded under `Libs\`.

Type `/ob` or `/omnibar` to open the options.

## What changed for 3.3.5a
The Wrath spell database (`OmniBar_Wrath.lua`) is WotLK content and is used
as-is. The compatibility work lives in `Compat.lua` plus targeted edits:

* **Combat log** — 3.3.5a has no `CombatLogGetCurrentEventInfo()` and its
  `COMBAT_LOG_EVENT_UNFILTERED` payload has no `hideCaster`/raid flags, so the
  handler reads the event arguments directly with the correct 3.3.5a layout.
* **`UNIT_SPELLCAST_SUCCEEDED`** — on 3.3.5a this event carries no `spellID`
  (added in 4.0), only the spell *name*, so the spellID is resolved from a
  name→id lookup (this is what makes PvP-trinket tracking work).
* **`C_Timer`, `C_PvP`, `C_AddOns`** — provided by `Compat.lua` (C_Timer is a
  small OnUpdate scheduler; rated battlegrounds report `false`).
* **`C_Spell.*`** — falls back to the classic `GetSpellInfo`/`GetSpellTexture`.
* **Group API** — `IsInGroup`/`IsInRaid`/`GetNumGroupMembers` and the
  `GROUP_ROSTER_UPDATE` event are mapped to the 3.3.5a equivalents.
* **Cooldown / Frame / GameTooltip** — `GetCooldownTimes`, `SetSwipeColor`,
  `SetHideCountdownNumbers`, `SetClipsChildren` and `SetSpellByID` are polyfilled.
* **Icons** — numeric fileID icons are replaced with the client's string texture
  paths (3.3.5a cannot render fileIDs).
* **XML** — retail atlas glows, the `fromAlpha`/`toAlpha` animation system and the
  `Cooldown` swipe/bling/edge attributes don't exist on 3.3.5a; the glow is
  redriven in Lua and the textures use stock 3.3.5a art.

[Open a ticket to report any issues](https://github.com/jordonwow/omnibar/issues)

[Submit a pull request](https://github.com/jordonwow/omnibar/pulls)

## Features
OmniBar is easily customizable, and has a rich feature set.

### Customizable Cooldowns
Open the options panel to easily select which cooldowns you wish to track:

### Multiple Bars
Create as many bars are you want!

### Automatically Hide Icons
When a cooldown is used, its icon will be added to the bar. After it's complete, it will be hidden automatically. This allows more cooldowns to be tracked, while avoiding awkward gaps between bars.

### Show Unused Icons
Check this option if you prefer the icons to always remain visible. The **Unused Icon Transparency** slider will adjust the transparency of the unused icons. Check **As Enemies Appear** to only show unused icons for arena opponents or enemies you target while in combat.

### Track Multiple Players
If another player is detected using the same ability, a duplicate icon will be created and tracked separately.

### Profiles
Create custom profiles with dual specialization support.

### Cooldown Count
Allow Blizzard and other addons to display countdown text on the icons.

### Glow Icons
A glow animation will be displayed around an icon when it is activated.

### Visual Tweaks
You can configure various visual tweaks such as size, border, glow, transparency, columns, and padding. OmniBar also includes Masque support.

### Visibility
Choose to display OmniBar in arenas, battlegrounds, and world combat.

## Configuration
To open the options panel, type `/ob`

![OmniBar Options Panel](http://i.imgur.com/HTIe0h3.png)
