# OmniBar (3.3.5a backport)
OmniBar is an _extremely lightweight_ addon that tracks enemy cooldowns.

![OmniBar](http://i.imgur.com/p9DjSOh.png)

Originally created by [Jordon](https://github.com/jordonwow/omnibar).
3.3.5a backport by [JedborgWoW](https://github.com/JedborgWoW).

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
