# OmniBar 3.3.5a — Projektminne för Claude

## Vad är detta?
Backport av [OmniBar](https://github.com/jordonwow/omnibar) (av Jordon) till **WoW 3.3.5a** (interface 30300).
Backport utförd av **JedborgWoW**. Repo: `JedborgWoW/OmniBar-3.3.5a`.

Målet: 100 % kompatibelt med en **stock 3.3.5a core** — inga retail/modern classic API:er.

---

## Filstruktur
```
OmniBar.toc          — Interface 30300, matchar mapp "OmniBar"
OmniBar_Wrath.toc    — Identisk, matchar mapp "OmniBar_Wrath"
Compat.lua           — Laddas FÖRST; shimmar alla API:er som saknas på 3.3.5a
OmniBar.lua          — Patched addon-logik
OmniBar_Wrath.lua    — WotLK spell-databas (oförändrad)
Options.lua          — Patched options panel
OmniBar.xml          — Patched XML (retail-animations borttagna)
Locales/             — Lokaliseringar
Libs/                — Ace3 + LibDeflate (från Skada-WoTLK, INTE ElvUI-forken)
```

---

## Vad som är gjort

### Compat.lua (ny fil)
Shimmar allt som saknas på 3.3.5a:
- `WOW_PROJECT_*` konstanter — pinnas till `WOW_PROJECT_WRATH_CLASSIC` (nil==nil-fällan)
- `C_Timer` — OnUpdate-scheduler (After / NewTimer / NewTicker)
- `C_AddOns` — mappar till gamla globaler (GetAddOnMetadata etc.)
- `C_PvP.IsRatedBattleground` — returnerar alltid `false`
- `GetServerTime` — `time()`
- `nop` — global no-op funktion
- `GetNumGroupMembers / IsInRaid / IsInGroup` — mappar till GetNumRaidMembers/GetNumPartyMembers
- Cooldown metatable: `GetCooldownTimes`, `SetSwipeColor`, `SetHideCountdownNumbers`, `SetDrawBling`, `SetDrawEdge`, `SetDrawSwipe`, `SetSwipeTexture`, `SetEdgeTexture`
- `Frame:SetClipsChildren` — no-op
- `GameTooltip:SetSpellByID` — via SetHyperlink
- `addon.AlphaPulse / AlphaPulseStop` — Lua-driven alpha-tween (ersätter retail animations)
- `addon.EventExists` — säker event-probe med pcall

### OmniBar.lua
- **COMBAT_LOG_EVENT_UNFILTERED**: dual-path — `CombatLogGetCurrentEventInfo` på retail, direkt `...`-args på 3.3.5a (layout: timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellID, spellName — ingen hideCaster/raidFlags)
- **UNIT_SPELLCAST_SUCCEEDED**: dual-path — retail får spellID direkt, 3.3.5a resolvar från `SPELL_ID_BY_NAME[spellName]`
- **SPELL_ID_BY_NAME**: byggs för CLASSIC + WRATH_CLASSIC med nil-name-guard
- **GROUP_ROSTER_UPDATE**: probar med `addon.EventExists`, faller tillbaka på `PARTY_MEMBERS_CHANGED` + `RAID_ROSTER_UPDATE`
- **OmniBar_OnEvent**: normaliserar legacy roster-events till `GROUP_ROSTER_UPDATE`
- **Delete**: unregistrerar även `PARTY_MEMBERS_CHANGED` + `RAID_ROSTER_UPDATE`
- **OmniBar_StartAnimation / StopAnimation**: reskriven med `addon.AlphaPulse`
- **Icon-texturer**: föredrar client string-path över numeriskt fileID
- **UnitReaction**: nil-guard före jämförelse
- **Version parsing**: `tonumber(major) or 0` — förhindrar `nil > 0`-krasch
- **SPEC_ID_BY_NAME**: byggs bara på MAINLINE
- **GetSpecs()**: early-return om `GetSpecializationInfo == nil`
- **ARENA_PREP_OPPONENT_SPECIALIZATIONS / PVP_MATCH_ACTIVE**: registreras bara på MAINLINE
- **ARENA_OPPONENT_UPDATE**: probar med `addon.EventExists`

### Options.lua
- `SPELL_DATA_LOAD_RESULT` event-registrering insvept i `pcall`
- `C_Spell.RequestLoadSpellData` — guardad med `C_Spell and C_Spell.RequestLoadSpellData`
- `export:EnableResize(false)` och `import:EnableResize(false)` — guardade med `if X.EnableResize then` (metoden saknas i den medföljande AceGUI:n)

### OmniBar.xml
- Retail `<Animations>`-block borttaget (fromAlpha/toAlpha/childKey existerar inte)
- 4 atlas-texturer (bags-glow-flash/blue/purple/white) ersatta med `Interface\Buttons\UI-ActionButton-Border` med Color-tints
- Cooldown: `drawBling`/`drawEdge` attribut borttagna, `<SwipeTexture>` borttagen

### Libs
- Källa: **Skada-WoTLK** (INTE ElvUI-forken — den har `-ElvUI`-suffix och custom widgets)
- Alla 39 lib-filer passerar Lua 5.1.1-syntaxkontroll

---

## Kända 3.3.5a-begränsningar (by design, inget att fixa)
- `EnableResize` finns inte i bundlad AceGUI Frame-widget → guarded (resize alltid på)
- `C_Spell` tillhandahålls inte av Compat.lua (OmniBar.lua/Options.lua har egna guards)
- `LE_PARTY_CATEGORY_INSTANCE` existerar inte (skickas som arg men ignoreras)
- `GetSpecialization*` / `GetClassInfo` / `GetNumSpecializations` — alla gated bakom MAINLINE eller nil-check

---

## Verifieringsverktyg
```bash
# Lua 5.1.1 syntaxkontroll (matchar WoW 3.3.5a)
/tmp/luabin -e "assert(loadfile('OmniBar.lua'))"

# Kontrollera alla addon-filer
for f in Compat.lua OmniBar.lua OmniBar_Wrath.lua Options.lua; do
  /tmp/luabin -e "assert(loadfile('$f'))" && echo "OK $f"
done

# Kontrollera alla lib-filer
find Libs -name '*.lua' | while read f; do /tmp/luabin -e "assert(loadfile([[$f]]))" || echo "FAIL $f"; done

# XML välformad
python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('OmniBar.xml')" && echo "OK"
```
> OBS: `/tmp/luabin` är Lua 5.1.1 byggt from source i sessionen — måste byggas om om den inte finns.

---

## API-referens (3.3.5a stock)
Källa: https://github.com/goldpaw/WoW_UI_Source_WotLK (build 12340)

**Finns på 3.3.5a:**
- `GetNumRaidMembers()`, `GetNumPartyMembers()`
- `tContains`, `SecondsToTime`, `format`, `tinsert`, `wipe`, `strsplit`
- `UI-ActionButton-Border`, `CooldownFrameTemplate`, `UIPanelButtonTemplate2`
- `GameTooltip`, `ARENA_OPPONENT_UPDATE` (på vissa cores — proba med EventExists)

**Saknas på 3.3.5a:**
- `CombatLogGetCurrentEventInfo()` — använd `...`-args direkt
- `C_Timer`, `C_PvP`, `C_AddOns`, `C_Spell` — alla shimmas
- `GROUP_ROSTER_UPDATE` — använd PARTY_MEMBERS_CHANGED + RAID_ROSTER_UPDATE
- `GetSpecialization*`, `GetClassInfo`, `GetNumSpecializations`
- `WOW_PROJECT_ID`, `nop`
- `GetNumGroupMembers`, `IsInRaid`, `IsInGroup` (från 5.0 / Mists)
- `UNIT_SPELLCAST_SUCCEEDED` med spellID (tillagt i 4.0)
- Numeriska fileID:n i `SetTexture`

---

## Git
- Branch: `main` (default)
- Commits i ordning: initial backport → audit/nop-fix → README-uppdatering → EnableResize-fix
