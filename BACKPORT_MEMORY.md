# OmniBar 3.3.5a — Backport Memory

Practical notes for the next session. Not fluff. Read this before changing code.

## Target
- **WoW Wrath of the Lich King 3.3.5a**, client build **12340**, TrinityCore 3.3.5a.
- Interface `30300`, **Lua 5.1**, legacy Blizzard API.
- **Baseline = stock 3.3.5a.** No ClassicAPI dependency, no awesome_wotlk dependency.
- awesome_wotlk.dll is NOT used and NOT required by this addon (see below).
- Upstream: OmniBar by Jordon (`github.com/jordonwow/omnibar`). Backporter: JedborgWoW.

## Architecture / load order
`.toc` (`OmniBar.toc`, with an identical `OmniBar_Wrath.toc` for folder-name flexibility):
1. Libs (LibStub, CallbackHandler, Ace3 suite, AceSerializer, LibDeflate)
2. `Compat.lua` — the 3.3.5a compatibility layer (loaded before OmniBar's own files)
3. `Locales/Locales.xml`
4. `OmniBar.xml` — frame/button/cooldown templates
5. `OmniBar_Wrath.lua` — **the WotLK spell database** (`addon.Cooldowns`, `addon.Shared`, `addon.Resets`, `addon.MAX_ARENA_SIZE`). Authored fresh for 3.3.5a; NOT the retail DB.
6. `OmniBar.lua` — main logic (bars, combat log, icons, events)
7. `Options.lua` — AceConfig options UI

`Compat.lua` loads AFTER the libs, which is fine here: the bundled Ace3 is the
**modern closure-dispatcher** safecall (`local function call() method(ARGS) end;
xpcall(call, eh)`), so the **Lua 5.1 xpcall vararg-drop bug does NOT apply** — no
`xpcall`/`securecallfunction` shim is needed. Compat only adds globals consumed at
runtime by OmniBar.lua/Options.lua (`C_Timer`, `C_PvP`, `C_AddOns`), and those
files load after Compat, so file-scope captures like `local C_Timer_After =
C_Timer.After` resolve. Do not "fix" the load order — it is correct as-is.

## What Compat.lua provides (already done, do not duplicate)
- `WOW_PROJECT_*` constants + `WOW_PROJECT_ID = WOW_PROJECT_WRATH_CLASSIC` (avoids the nil==nil retail-branch trap).
- `C_Timer.After/NewTimer/NewTicker` on one OnUpdate driver frame.
- `C_AddOns.*` → classic globals; `C_PvP.IsRatedBattleground` → `false` (3.3.5a has no rated BGs).
- **C_Spell deliberately left nil** — OmniBar/Options guard every call with `if C_Spell and C_Spell.X` and fall back to global `GetSpellInfo`/`GetSpellTexture`.
- Cooldown shims: wraps `SetCooldown` to record start/duration so the shimmed `GetCooldownTimes` can report running state; no-ops for `SetSwipeColor`, `SetHideCountdownNumbers`, `SetDrawBling/Edge/Swipe`, `SetSwipeTexture`, `SetEdgeTexture`.
- `Frame:SetClipsChildren` no-op (AceGUI import/export windows).
- `GameTooltip:SetSpellByID` built on `SetHyperlink` **with a `GetSpellInfo` guard** — this is the **#132 ACCESS_VIOLATION** fix (a `spell:<id>` hyperlink for an id the core does not know hard-crashes the client). Never feed an unvalidated spell id to a tooltip.
- `Texture:SetColorTexture` → `SetTexture(r,g,b,a)`.
- `GetServerTime`, `nop`, `GetNumGroupMembers`, `IsInRaid`, `IsInGroup`.
- `addon.AlphaPulse` / `AlphaPulseStop` — Lua OnUpdate alpha tween replacing the retail glow/flash animation system (XML animations were stripped).
- `addon.EventExists(event)` — pcall-probe before registering events that may not exist on a given core.

## Combat log (correct — do not change without re-deriving field order)
`OmniBar:COMBAT_LOG_EVENT_UNFILTERED(_, ...)` branches:
- If `CombatLogGetCurrentEventInfo` exists (retail/modern classic) → accessor.
- Else (3.3.5a) → legacy vararg unpack: `local _, ev, sGUID, sName, sFlags, _, _, _, sid, sname = ...`
  i.e. **8-field prefix** (timestamp, subevent, sourceGUID, sourceName, sourceFlags,
  destGUID, destName, destFlags) then spellId, spellName. 3.3.5a has **no hideCaster
  and no raid flags** — do not add them.
`UNIT_SPELLCAST_SUCCEEDED` on 3.3.5a fires `(unit, spellName, spellRank, lineID)` with
no spellID; OmniBar resolves the id via `SPELL_ID_BY_NAME[spellName]`. Used for PvP
trinket + spells that do not appear in CLEU.

## Events
- Retail-only events (`ARENA_PREP_OPPONENT_SPECIALIZATIONS`, `PVP_MATCH_ACTIVE`) are
  registered ONLY under `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` → skipped on 3.3.5a.
- `ARENA_OPPONENT_UPDATE` and `GROUP_ROSTER_UPDATE` are `addon.EventExists`-gated;
  legacy fallbacks `PARTY_MEMBERS_CHANGED` + `RAID_ROSTER_UPDATE` used when absent.
- Spec detection (`OmniBar:GetSpecs`) returns early when `GetSpecializationInfo` is nil
  (always on 3.3.5a). Enemy detection therefore falls back to class-based
  (`UnitClass` on arenaN where the core supplies it) + combat-log-triggered icons.
  This is the correct WotLK behavior — do not try to force retail spec detection.

## Spell database (OmniBar_Wrath.lua) — strictly WotLK 3.3.5a
- Classes present: GENERAL, DEATHKNIGHT, DRUID, HUNTER, MAGE, PALADIN, PRIEST,
  ROGUE, SHAMAN, WARLOCK, WARRIOR. **No Monk / Demon Hunter / Evoker spells.**
- Default-tracked spells = the per-class interrupts (DK **Mind Freeze 47528**, Mage
  Counterspell, Rogue Kick, Shaman Wind Shear, Hunter Silencing Shot, Warlock Spell
  Lock, Warrior Pummel + Shield Bash, Druid Feral Charge-Bear). Priest/Paladin have
  no default — correct, they had no interrupt in WotLK.
- Options UI builds class sections from the **client** globals `CLASS_SORT_ORDER` +
  `MAX_CLASSES` (10 on 3.3.5a) and hides any class with zero spells → post-WotLK
  classes can never appear on a 3.3.5a client even if a stale retail profile exists.
- Stale retail spell ids / class keys in a migrated `OmniBarDB` are inert: icon
  rendering iterates `addon.Cooldowns` (WotLK only); `settings.spells[id]` toggles for
  unknown ids just sit unused; the custom-class dropdown only offers WotLK classes.

## Death Knight (supported, verified)
DK has 32 entries. Core PvP cooldowns cross-checked against Gladdy-3.3.5a's
known-good `Constants_Wrath.lua` and match exactly:
Strangulate 47476/120, Mind Freeze 47528/10, Anti-Magic Shell 48707/45,
Icebound Fortitude 48792/120, Death Grip 49576/35, Empower Rune Weapon 47568/300,
Death Pact 48743/120, Lichborne 49039/120, Gnaw 47481/60, Anti-Magic Zone 51052/120,
Raise Dead 46584/180, Summon Gargoyle 49206/180, Dancing Rune Weapon 49028/90,
Hungering Cold 49203/60. Plus Army of the Dead, Death & Decay, Bone Shield, Vampiric
Blood, Unbreakable Armor, Rune Tap, Mark of Blood, Hysteria(49016), Raise Ally, etc.
- **49796 "Deathchill"** resolves in 3.3.5a (present in Gladdy LibClassAuras as a
  DEATHKNIGHT spell). Low value to track but harmless; left in.
- **49158 "Corpse Explosion"** (5s CD) is present in the WotLK spell data (wowhead
  WotLK) but is a low-priority/utility id; harmless (toggleable, #132-guarded). Left in
  pending an in-game `GetSpellInfo(49158)` smoke-test.

## Changes made 2026-06-29 (this session)
- `OmniBar.lua` `CLASS_ORDER`: removed the post-WotLK class tokens DEMONHUNTER,
  MONK, EVOKER (they were dead entries used only by the icon-grouping sort; no
  loaded 3.3.5a data references them). No post-Wrath class token remains in code.
- `OmniBar.lua` icon sort comparator: hardened `CLASS_ORDER[aClass] < CLASS_ORDER[bClass]`
  to `(CLASS_ORDER[aClass] or 0) < (...)`. **Root-cause fix** for a latent nil-compare
  crash: icons fall back to `a.class or 0` (numeric 0) when classless, and
  `CLASS_ORDER[0]` is nil, so the old form could throw `compare nil with number` when
  `showUnused` is on and a classless icon is active.

## Group sync comm channel (no "INSTANCE_CHAT" on 3.3.5a)
`GetDefaultCommChannel` (OmniBar.lua) used retail's `IsInRaid(LE_PARTY_CATEGORY_INSTANCE)`
to pick "INSTANCE_CHAT". On 3.3.5a that constant is nil and the old arg-ignoring
`IsInRaid`/`IsInGroup` shims returned true in any group, so the channel became
"INSTANCE_CHAT" — a distribution added in MoP that `SendAddonMessage` rejects here,
silently breaking the "Track Multiple Players" sync in any party/raid. Fix lives in
`Compat.lua`: define `LE_PARTY_CATEGORY_HOME/INSTANCE` and make the *categorized*
`IsInRaid(cat)`/`IsInGroup(cat)` form return false (3.3.5a has no party categories),
so the channel falls through to PARTY/RAID. (Version broadcast via SendVersion stays
off because the "V34…" version string has no lowercase-v match → `version.major == 0`.)

## Cooldown completion (3.3.5a has no OnCooldownDone)
Retail fires the Cooldown frame's `OnCooldownDone` when a swipe completes, which
OmniBar wires (via the cooldown's `<OnHide>`) to `OmniBar_CooldownFinish` to drop
the finished icon. **3.3.5a has no such callback** — the swipe just ends and the
icon would linger forever (nothing else calls `cooldown:Hide()` except a full
`OmniBar_ResetIcons`). Fix: `OmniBar_OnUpdate` (a throttled `OnUpdate` set on every
bar frame in the bar-creation block) polls `self.active` and, once an icon's
`cooldown.finish` (set in `OmniBar_StartCooldown`) has passed, hides the cooldown —
that produces the `OnHide` transition that runs `OmniBar_CooldownFinish` (removes
the icon in default mode, dims it to unused in Show-Unused mode). `OmniBar_StartCooldown`
now also `cooldown:Show()`s the frame so the swipe renders AND so the later `Hide()`
is a real visible->hidden transition (otherwise OnHide never fires). Do NOT move this
auto-hide into the Compat `SetCooldown` shim — that metatable is shared by every
Cooldown in the UI and would make unrelated cooldowns hide themselves.

## awesome_wotlk.dll
Not used. OmniBar needs no nameplate / `C_NamePlate` / native-token features, so
there is nothing the DLL would improve here. No code path calls DLL-specific
functions. Runs identically with or without it.

## What still needs IN-GAME verification (cannot run WoW from here)
Everything runtime. See the in-game checklist in the session summary / README. Key items:
loads with no Lua error on stock 3.3.5a; `/omnibar` opens options; DK Mind Freeze icon
appears when an enemy DK interrupts; combat-log-driven icons populate in arena/BG;
`GetSpellInfo(49158)` / `GetSpellInfo(49796)` resolve (or prune if they do not).

## Do NOT do again
- Do not re-add Monk / Demon Hunter / Evoker anywhere.
- Do not assume retail/Wrath-Classic spell ids are valid 3.3.5a ids — verify against
  Gladdy/BigDebuffs WotLK data or `GetSpellInfo`.
- Do not add the xpcall/securecallfunction shim — the bundled Ace3 does not need it.
- Do not "reorder" Compat before the libs — the current order is correct.
- Do not feed unvalidated spell ids to `SetSpellByID`/`SetHyperlink` (#132 crash).
- Do not switch the combat-log parser to `CombatLogGetCurrentEventInfo` for 3.3.5a.
