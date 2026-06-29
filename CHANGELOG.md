# Changelog

## [3.3.5a-1] — 2026-06-29
- Static 3.3.5a compliance audit (no code regressions found in Compat layer,
  combat-log parser, event registration, spec-detection guards, or spell database).
- `CLASS_ORDER`: removed the post-WotLK class tokens (Demon Hunter, Monk, Evoker)
  so no post-Wrath class token is carried in loaded data. They were dead entries
  used only by the icon-grouping sort.
- Hardened the icon-grouping sort comparator against a nil class index
  (`CLASS_ORDER[aClass] or 0`). Fixes a latent `compare nil with number` crash that
  could occur with "show unused" enabled when an active icon had no class.
- Added `BACKPORT_MEMORY.md` documenting the 3.3.5a backport architecture, the
  combat-log field order, the Death Knight verification, and the awesome_wotlk
  (unused) status.

## [3.3.5a-1] — earlier
- Backport of OmniBar (by Jordon) to the stock Wrath of the Lich King 3.3.5a
  client (interface 30300, Lua 5.1), self-contained with no ClassicAPI/awesome_wotlk
  dependency.
- `Compat.lua` shim layer: `WOW_PROJECT_*`, `C_Timer`, `C_AddOns`, `C_PvP`, Cooldown
  method polyfills, `GameTooltip:SetSpellByID` with a `GetSpellInfo` guard (#132
  native-crash fix), `SetColorTexture`, group-roster helpers, Lua alpha-tween glow,
  and an `EventExists` probe.
- WotLK-only spell database (`OmniBar_Wrath.lua`) including full Death Knight support.
- Combat log backported to the legacy 3.3.5a `COMBAT_LOG_EVENT_UNFILTERED` argument
  model; retail-only events and spec-detection gated behind capability checks.
- XML retail animation system replaced with a Lua-driven equivalent.
