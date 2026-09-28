# CarGOUI

**CarGOUI 1.0.0** is a World of Warcraft Retail addon for real Mobility depletion reminders, timed digits over supported Blizzard Proc graphics, and Time Spiral's **Free move** effect. It targets Retail 12.1 / Interface 120100; existing skill/API audits pin build **69933**. It keeps the working RC3 gameplay, Options drag safeguards, standard launchers, themes and saved settings.

Version 1.0.0 adds automatic client-language UI and public spell-name localization, rendering-safe font fallback, and English project documentation. The user reported RC3 working in their test environment; that feedback does not certify every class/talent/collector/locale combination. New translations still require native-client and native-speaker review. See [release notes](docs/RELEASE_1.0.0.md), [localization](docs/LOCALIZATION.md) and the separate [Mobility](docs/MOBILITY_COVERAGE.md), [Proc](docs/PROC_COVERAGE.md) and [Body-theme](docs/BODY_THEME_COVERAGE.md) coverage records.

## 1.0.1 development baseline

The current development target is **1.0.1**: [#6 font selector fixes and LibSharedMedia font support](https://github.com/TomXingCan/CarGOUI/issues/6), plus [#7 Proc Appearance v2](https://github.com/TomXingCan/CarGOUI/issues/7). Font-resource support and Proc Appearance v2 are implemented on the development branch; Proc Appearance still requires real-client acceptance. The production version stays **1.0.0** until release hardening. See the [1.0.1 roadmap](docs/ROADMAP_1.0.1.md).

Production Class Tools development is paused and must not block 1.0.1. Its logger, Phase 1 / 1.1 findings and research tests remain in the repository, but normal login does not load `addon.ClassToolsRawCapture`, and `/cui ctlog` is not a player command or help entry. Research tests explicitly load the retained module. Arcane Missiles Chain Check, Combustion Counter and Alter Time Recovery Feedback are outside 1.0.1.

## Install or upgrade

1. Exit WoW and place **both `CarGOUI` and `CarGOUI_Data`** directly in `_retail_/Interface/AddOns/`. Replace their program directories together; each TOC must sit directly inside its matching folder. Data loads automatically—no class package selection.
2. Keep WTF and all SavedVariables. If an old alpha.8 `AddOns/CarGOUI_Mage` directory remains, remove only that obsolete program directory. CarGOUI does not delete files or saved data automatically.
3. Open/close settings with `/cui` or `/cargoui`, or plain left-click the minimap emblem, LDB launcher or native AddOn Compartment entry.
4. For a source checkout, use the repository as `CarGOUI` and copy `Modules/CarGOUI_Data` to a sibling AddOns/CarGOUI_Data directory. Prefer the installation ZIP to avoid omitting the internal module.

LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1 and LibDBIcon-1.0 are embedded inside CarGOUI. No separately installed library addon is required; no full Ace3/AceGUI is bundled. See [third-party notices](Libs/THIRD_PARTY_NOTICES.md).

## Language and fonts

The interface automatically follows the client locale: **English, Simplified Chinese, Traditional Chinese, German, French, Spanish, Italian and Russian** (`enUS`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `itIT`, `ruRU`). `enGB` uses English, `esMX` uses Spanish, and unknown locales fall back to English. English is the complete fallback catalog. There is no language selector, slash language command or saved language profile. This intentionally supersedes the historical English-only policy.

Only English plus the active locale's overlay is retained. Other locale files may execute from the TOC but return before constructing their translation tables; that is not a claim that their files never load. Public spell IDs remain stable, while available display names come from the client's public spell-name API. Missing names use the defined safe fallback and bounded event-driven retry. Localization neither scans Auras nor changes skill recognition, timing, visibility or stored IDs.

The font picker distinguishes **Blizzard / Client** from **SharedMedia** and follows the actual client's font language, including enUS/enGB, deDE, frFR, esES/esMX, itIT, ptBR, ruRU, zhCN, zhTW and koKR. It shows the client default and distinct eligible resources, without listing several Roman choices that all silently render as the same wide-language default. SharedMedia, MyMedia, ElvUI and other providers can contribute fonts through LibSharedMedia; none is a required dependency. CarGOUI ships no user font files and does not scan operating-system fonts or arbitrary directories.

Existing 1.0.0 Blizzard paths remain valid. New shared selections save a logical `LSM:<media-name>` preference, such as `LSM:Expressway`. If that font is missing on another client, the preference survives login and import/export while rendering uses the client default. The picker separately names the selected font, availability and effective rendering font. A later LSM registration updates existing live/Preview and pooled font objects without restarting timers. See [font architecture](docs/FONT_SYSTEM.md) and [the API audit](docs/LOCALIZATION_API.md). Native glyph coverage, clipping and language quality remain client/native-speaker acceptance.

## Settings and interaction

| Setting | Ownership |
| --- | --- |
| Mobility enabled, font/size/outline/shadow/Scale, anchor, XY and preferences | Current classToken; all Mage specs and Blink/Shimmer share one Mage scope |
| Free move anchor and XY | Separate `mobility.freeMovePosition` within that class; independent of ordinary Mobility XY |
| Proc font/size/outline/shadow/text Scale and enabled | Current classToken + specID; shared by all regions in that spec |
| Proc timer anchor, XY and optional RGB | Independent stable region ID within class/spec; absent timer RGB uses dynamic class color |
| Proc artwork mode, asset, RGB, transform and animation | Separate optional `region.appearance`; absent settings preserve Blizzard Native |
| Options placement, branding animation, minimap visibility/angle | Independent shell records, separate from class settings and from one another |

No class/spec/Profile/manual-theme selector. Appearance shows the automatically selected configuration context. The Proc Region Editor selects one Proc and one stable region in the current specialization. Timer typography remains shared by that specialization; the existing Appearance editor controls it. Timer RGB and artwork RGB are independent. Mobility and Free move always use Blizzard's player class color. Proc timers default to class color; only custom artwork has its own opacity control. Options themes do not alter reminder style or native state.

Options retains a left category list and right controls. Header, Body, sidebar blank areas, borders and static explanations drag the whole window; interactive controls keep their input. No modifier, capture overlay or Unlock Mode. Release, close and Esc end movement; placement persists and stays screen-constrained. [RC2's drag record](docs/DRAG_RC2.md) explains source ownership and native current-pointer pickup.

Dropdowns, checkboxes and sliders update immediately. Numeric fields save on Enter, without Apply. Context/page changes and closing discard unsubmitted drafts. Appearance's Font, Font Size, Outline, Shadow and Scale share the appropriate class/spec scope; reset affects only that style, not positions or other scopes. Font choices combine Client default, distinct language-compatible Blizzard faces, and locally registered LSM fonts in a paged popup. Factory typography retains the 1.0.0 defaults: Friz Quadrata or the appropriate wide-language client face, size 24, OUTLINE, shadow on, Scale 1. Size range is 8–72, Scale 0.5–3 and new XY edits -10000..10000. Scaling does not multiply saved offsets.

Proc's **Timer color** uses the selected ability/region, previews native-picker changes, and saves only on Okay. Cancel/close/region/spec changes discard drafts without closing another addon's subsequently owned picker. **Use class color** removes only that region's override. Color changes update existing text objects without Aura queries, timer rebuilds or native gate-alpha changes. See [regional colors](docs/PROC_COLORS.md).

General/Mobility switches and XY edit the same current-class Mobility record. Disabling Mobility also stops Free move and Mobility samples, leaving Proc independent. Proc can disable its own current-spec digits. Reset Mobility offsets affects only that class group; Reset region offsets affects only the selected region. Reset class + Options requires confirmation and preserves other classes/migration backups; the existing `reset` slash command immediately applies the same reset scope.

## Launchers and combat

General → **Show minimap icon** defaults on. Hiding it affects only the standard button; `/cui`, LDB and the native compartment remain available. Standard library dragging positions an uncollected button. Collector-owned layouts are respected; modified/right clicks remain available to collectors. All entries use the same combat-safe Options logic and never start TEST or a picker automatically.

In combat, opening requests queue once and report once; no Options controls are created or flashed. On combat exit, the lock is rechecked and one explicit open consumes the request. Ordinary later combat exits do not reopen. Entering combat with Options open closes it, ends drag/focus, cancels unconfirmed edits and stops TEST without stopping real reminders. Auto-close alone creates no reopening request. The request is session-only, not saved across reload/logout. Read-only help/status commands remain available. See [combat lifecycle](docs/OPTIONS_COMBAT_LOCK.md).

HidingBar defaults collect the standard button only. Enabling both its minimap and LDB sources may show two representations; its exclusion settings can select one. WindTools/MBB standard interfaces were reviewed, not universally client-certified. Test exact manager versions separately; competing managers are not guaranteed compatible. See [launcher acceptance](docs/LAUNCHER_RC3.md) and [source review](docs/LAUNCHER_RC3_API.md).

## Live Mobility

The current-class adapter filters current spec, actual learning and effective overrides. Replacements share a family and do not double-monitor. Each simultaneous skill has independent state/frame/native binding; one ready skill does not clear another. Ordinary cooldown uses native duration excluding GCD. Charge digits use the **existing next-recovery object**, not a new timer from the final cast. Secret multicount visibility uses individually audited native rules, never a universal Mage threshold.

Hide with at least one use; show a localized depletion label and true recovery time when empty; hide immediately when one use returns. Mana, range, target, silence/control and generic unusability do not imply depletion. The user-tested Blink 1953/Shimmer 212653 path remains. [Mobility API audit](docs/MOBILITY_API_AUDIT.md) and [historical Mage audit](docs/Mobility-Combat-API-Audit.md) distinguish evidence and limits.

`Native tracking` means native visibility owns the result, not Lua knowledge of Ready/Depleted. `Tracking` delegates zero/expiry text to native timing. Excluded conditional-return mechanics retain Unsupported safeguards; failed metadata/native guards retain Restricted. No samples, fixed cooldowns, cast counts or secret-value readback fill gaps.

Each family has a stable preset slot: the first at the saved class anchor, others 84 UI units downward per slot. Unavailable slots do not make others jump. Class XY moves the group; original Mage IDs/positions remain. All skills share class style. Preview can select an active entry or several; a single test suppresses only that entry's live output. [Coverage](docs/MOBILITY_COVERAGE.md) records admitted paths and excluded mechanisms; exclusions are not future development blockers.

## Native Proc and Free move

Native mode preserves Blizzard artwork and places timer digits at its audited visual midpoint plus the existing timer XY. The optional Proc Appearance v2 presentation layer adds Custom Blizzard Asset and Timer Only modes per stable region. Custom uses addon-owned frames/textures and a metadata-only catalog of audited client FileDataIDs. It can suppress a precisely matched native graphic only by owning a reversible texture-alpha change. If matching, public color, geometry or rendering is unavailable, it leaves/restores Blizzard artwork and reports why. Timer triggers and native Aura duration bindings are unchanged.

The Region Editor shows only relevant controls for the selected mode. Custom Basic contains artwork selection, independent artwork RGB, alpha, overall scale and animation presets. Advanced expands desaturation, width/height, rotation, mirrors, independent artwork XY and animation speed/intensity/direction. Its expansion is session-only. The gallery uses paged client-texture thumbnails and source-class filtering; a cross-class image grants no trigger or timer support. Reset artwork changes only `region.appearance`. See [architecture and client acceptance](docs/PROC_APPEARANCE_V2.md).

Mage coverage includes Clearcasting, Arcane Soul, Overpowered Missiles; Hot Streak, Heating Up, **Pyroclasm's hard-cast Pyroblast/Flamestrike buff**, Hyperthermia; and Fingers of Frost sides plus Brain Freeze. Historical Fury of the Sun King is actual-SHOW-only, not a currently verified selectable talent Preview. [Mage coverage](docs/MAGE_PROC_COVERAGE.md) separates graphic IDs, timer Auras, textures and regions. [Clearcasting's repair](docs/CLEARCASTING_ALPHA13.md) preserves the later source-supported finite-Aura association.

The non-Mage increment adds **63 spec-owned definitions / 81 regions**, based on 52 graphic source keys and 51 finite Auras. Of 37 reviewed non-Mage specs, 33 have eligible timers. Enhancement, Destruction, Arms and Fury have explicit empty states; this is not a timer for every spec. Examples include Rime, Infusion/Surge of Light, Nightfall, Clearcasting, Lava Surge, Essence Burst, Opportunity, Lock and Load, Blackout Kick!, Revenge! and Chaos Theory. [Proc coverage](docs/PROC_COVERAGE.md) is authoritative for conditions, separate same-name Aura IDs, stages and exclusions; [alpha.15 acceptance](docs/UPGRADE_ALPHA15.md) preserves delivery evidence.

Native CustomAuraContainerTemplate matches player `HELPFUL + includeSpellIDs` and owns presence, consumption, refresh and expiry. Copied native DurationTextBinding supplies digits; Lua does not compare secret buffs/time/stacks. Missing native interfaces/Auras produce no invented timer. There is no universal graphic-history replay API: reload uses explicitly mapped native timer-Aura matching, which may differ from the graphic owner; actual initial-graphic correspondence remains a client check.

Time Spiral **374968** grants class-specific receiving Auras. Confirmed Free move is that free use, not Hover moving-cast. Native matching displays only **Free move** while the receiving effect exists, clearing on consumption/expiry without a timer or cast count. It shares class Mobility style/Scale/enabled/color, with independent `mobility.freeMovePosition`. Default base is 84 UI units above screen center; its XY no longer adds ordinary Mobility XY. Other reminders remain independent. See [alpha.16 position isolation](docs/POSITION_ISOLATION_XYFIX1.md).

Options closing, TEST stopping and combat do not stop live monitoring. Proc disable stops only its slots/callbacks; Mobility disable stops Mobility/Free move only. Native-container shutdown retains a transparent shown public parent for one native cleanup pass, avoiding hidden-parent cleanup freezes.

## Supported Proc Timers

Implemented native Proc timers are listed below by specialization. Availability depends on the character's learned talents and passives. The detailed coverage record describes conditions and client-validation limits.

| Class | Specialization | Implemented Proc timers |
| --- | --- | --- |
| Death Knight | Blood | Crimson Scourge; Dance of Midnight |
| Death Knight | Frost | Rime; Killing Machine |
| Death Knight | Unholy | Sudden Doom |
| Demon Hunter | Havoc | Chaos Theory |
| Demon Hunter | Vengeance | Untethered Rage |
| Demon Hunter | Devourer | Moment of Craving |
| Druid | Balance | Owlkin Frenzy |
| Druid | Feral | Clearcasting |
| Druid | Guardian | Gore; Galactic Guardian; Celestial Might |
| Druid | Restoration | Clearcasting |
| Evoker | Devastation | Essence Burst |
| Evoker | Preservation | Essence Burst; Lifespark |
| Evoker | Augmentation | Essence Burst |
| Hunter | Beast Mastery | Deathblow; Howl of the Pack Leader: Wyvern; Howl of the Pack Leader: Boar; Howl of the Pack Leader: Bear |
| Hunter | Marksmanship | Lock and Load; Precise Shots; Deathblow |
| Hunter | Survival | Howl of the Pack Leader: Wyvern; Howl of the Pack Leader: Boar; Howl of the Pack Leader: Bear |
| Mage | Arcane | Clearcasting; Arcane Soul; Overpowered Missiles |
| Mage | Fire | Hot Streak; Heating Up; Pyroclasm; Hyperthermia |
| Mage | Frost | Fingers of Frost; Brain Freeze |
| Monk | Brewmaster | Potential Energy |
| Monk | Windwalker | Blackout Kick!; Strength of the Black Ox |
| Monk | Mistweaver | Strength of the Black Ox; Zen Pulse; Potential Energy |
| Paladin | Holy | Infusion of Light; Divine Purpose |
| Paladin | Protection | Divine Purpose |
| Paladin | Retribution | Divine Purpose; Art of War; Righteous Cause |
| Priest | Discipline | Surge of Light; Power of the Dark Side; Harsh Discipline |
| Priest | Holy | Surge of Light; Benediction |
| Priest | Shadow | Surge of Light; Shadowy Insight; Mind Flay: Insanity |
| Rogue | Assassination | Blindside |
| Rogue | Outlaw | Opportunity |
| Rogue | Subtlety | Ancient Arts |
| Shaman | Elemental | Lava Surge |
| Shaman | Enhancement | No eligible finite native Proc timer currently included. |
| Shaman | Restoration | Lava Surge; High Tide |
| Warlock | Affliction | Nightfall |
| Warlock | Demonology | Demonic Core |
| Warlock | Destruction | No eligible finite native Proc timer currently included. |
| Warrior | Arms | No eligible finite native Proc timer currently included. |
| Warrior | Fury | No eligible finite native Proc timer currently included. |
| Warrior | Protection | Revenge! |

CarGOUI only adds timers where a verified Blizzard native screen indicator can be mapped to a verified finite-duration effect. Action-bar glows, resource thresholds, cooldown-ready flashes and ordinary buffs are outside this Proc table.

See [the detailed Proc coverage record](docs/PROC_COVERAGE.md).

## Test Mode and themes

External TEST uses clearly marked fixed `8.0` samples; Free move is text-only. Proc choices include only audited regions for current class/spec/talents, even without an active effect, independently of Mobility. Samples never enter native Aura/live state. Proc Native previews render a simulated mapped image, Custom previews render the selected catalog asset, and Timer Only previews retain just the timer sample. Their artwork objects are independent of live artwork and never own native suppression. Closing, Stop test, combat or spec change clears temporary samples; live resynchronizes. Reminders/guides cannot be dragged.

Header expresses faction only: Alliance blue, Horde red, neutral fallback; same-faction spec changes retain it and original full-color branding. Body expresses class/spec over main/sidebar/footer surfaces, with complete 13-class/40-spec mappings and distinct palettes/static geometry. Mage Arcane purple runes, Fire red-brown/amber flames and Frost blue/cyan crystals retain alpha.9 definitions. No Themes page or manual theme control.

No spec uses the class base; unavailable identity uses neutral and recovers on identity events. Opening resolves identity; hidden windows stop theme listeners. Gameplay-disabled/unlearned states do not affect themes. Lightweight maps are core UI data, not an excuse to initialize business adapters. The shared bounded Line pool draws only the current lower-right watermark behind readable content; no promotional backgrounds, particles, rotations or per-frame color changes. [Theme sources](docs/THEMES.md) and [coverage](docs/BODY_THEME_COVERAGE.md) distinguish implemented mappings from client visual acceptance.

## Loading, diagnostics and migration

The native load-on-demand CarGOUI_Data TOC executes all listed class adapter definitions together. Only the current class factory and active skill/spec paths run. Class subdirectories are not separate load-on-demand boundaries. The account CarGOUIDB may restore all saved classes; accessing/initializing only one is not the same as other records being unloaded. The two-folder design intentionally does not promise strict per-class code/config zero-loading. No deletion, compression or forced GC conceals this tradeoff.

The adapter registry rejects duplicates rather than letting class files overwrite core methods. Other classes receive no business listeners, cooldown queries, reminders or bindings. Old CarGOUI_Mage bridge writes are quarantined; users should still remove its obsolete program folder. Cached frames/code are not claimed unloaded.

Existing Copy diagnostics / Refresh snapshot distinguishes loaded modules, instantiated entries, loaded/accessed config and listener/active/allocated binding counts. Runtime memory KB and cumulative CPU ms are read on demand; CPU is unavailable without scriptProfile. Native requested-active slots are not visible buff counts, and copied binding state is not read back. No background sampling or whole-library scan. [Loading boundaries](docs/LOAD_BOUNDARIES.md) explains client measurement.

Schema 5 uses `classes[classToken].mobility` and `classes[classToken].proc[specID]`. Legacy Mage values migrate only to Mage using effective skill/current-position rules; conflicts and choice rules remain in migrations.scope5. New classes receive independent factory copies. Only missing/invalid fields migrate, without overwriting later valid settings on login. [Configuration scopes](docs/CONFIG_SCOPES.md) records details.

## Import / Export

Current class is the default, including its already-saved Proc specs without initializing others. All saved settings includes saved classes and shell placement/animation/minimap preferences. Exports contain only whitelisted user data, never identity/theme/skills/runtime/migration/import backups. Select text and Ctrl+C; no unsupported direct-clipboard claim.

Import validates before review, then Confirm commits atomically. Source class/spec remains unchanged; omitted classes/specs/regions survive. An included region without timer RGB clears its old timer-color override. `region.appearance` is an additive strict whitelist; an included old region without it imports as Native. Schema 5 and transfer format 1 remain unchanged. New appearance-bearing strings require a version that understands those fields; older strict importers can reject them safely. A single pre-import snapshot can be restored with review/confirmation. Close/combat cancels drafts/transactions; unlock never auto-submits. Existing pure-coordinate/color changes stay targeted. Minimap settings use the stable library-bound table after import/restore/reset; older RC1/RC2 strings without minimap fields preserve current preferences. Locale/font rendering fallback does not add translated data or locale settings to format 1. See [transfer specification](docs/SETTINGS_TRANSFER_FORMAT.md).

## Development and verification

`Core/`: initialization/events/config/migration/loading/diagnostics; `Config/`: defaults/locales/commands; `Database/`: shared appearance context/themes; `UI/`: rendering/Preview/Options/branding/launchers; `Modules/Mobility/`: active-skill engine/Free move; `Modules/Proc/`: native Aura/overlay lifecycle; `UI/ProcDisplay.lua`: native positioning/style boundary; `Modules/CarGOUI_Data/`: LoD manifest, registry, shared state engine and class-private definitions; `tests/`: Lua 5.1 and static checks.

`python tests/run_tests.py` requires existing lupa.lua51 and uses clearly identified Python JSON/Base64 mocks; it does not install dependencies. RC3 retained all 219 RC2 groups and added 15 actual-library launcher groups. Current delivery output records the expanded suite and final extracted-package results, rather than treating an old count as current evidence. No real WoW client or native-speaker review is available in development. Prior user reports remain scenario-specific; new localization, native glyph/layout behavior, exact collector versions, secret API behavior and real CPU/memory require appropriate acceptance.

`python tools/package.py --output <directory>` builds from a clean commit. Repository tools then test `--addon-root <extracted/CarGOUI>`, recording tree/commit/SHA256. The runtime installer has only the two addon directories, TOC files, required TGA assets, embedded libraries/licenses and concise notices. Tests, review records, art sources and scripts remain in the repository. Preserve SavedVariables; addon version 1.0.0, schema 5 and transfer format 1 are distinct.

## License

Current project-owned source from the commit introducing the ARR [LICENSE](LICENSE), and future project-owned source unless expressly licensed otherwise, is **All Rights Reserved**. This cutover belongs to the 1.0.1 development baseline even though production TOCs still say 1.0.0. Official distributions may be installed and run for personal gameplay under LICENSE.

The already published **v1.0.0 remains GPL-3.0-only as originally distributed**: [historical license](https://github.com/TomXingCan/CarGOUI/blob/v1.0.0/LICENSE) and [unchanged Release](https://github.com/TomXingCan/CarGOUI/releases/tag/v1.0.0). No previously granted GPL rights are revoked or restricted by this cutover.

Branding assets under Media/Branding remain **All Rights Reserved**, separately described in [their notice](Media/Branding/LICENSE.txt). Embedded libraries retain their original licenses and notices. See [NOTICE.md](NOTICE.md) for the exact scopes and [the ownership audit](docs/LICENSING_AUDIT_1.0.1.md) for cutover evidence.
