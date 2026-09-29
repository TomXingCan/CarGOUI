# CarGOUI

**CarGOUI 1.0.1** is a World of Warcraft Retail addon for real Mobility depletion reminders, native-bound Proc countdowns, and Time Spiral's **Free move** effect. It targets Retail 12.1 / Interface 120100; existing skill/API audits pin build **69933**. This release adds SharedMedia font support, Modern CUI controls and opt-in independent Proc artwork while preserving saved settings, Options drag safeguards, standard launchers and automatic themes.

The author approved formal 1.0.1 delivery after confirming the final RC checks for source `9bef4c3b654c4a45a705b74cb1b0a46431367ace`. See the [1.0.1 release notes](docs/RELEASE_1.0.1.md), [localization](docs/LOCALIZATION.md) and separate [Mobility](docs/MOBILITY_COVERAGE.md), [Proc](docs/PROC_COVERAGE.md) and [Body-theme](docs/BODY_THEME_COVERAGE.md) coverage records. The published [v1.0.0 release](https://github.com/TomXingCan/CarGOUI/releases/tag/v1.0.0) and its [historical notes](docs/RELEASE_1.0.0.md) remain unchanged.

## 1.0.1 release scope

The release includes [#6 font selector and LibSharedMedia support](https://github.com/TomXingCan/CarGOUI/issues/6), the artwork catalog and style controls from [#7 Proc Appearance v2](https://github.com/TomXingCan/CarGOUI/issues/7), and [#13 Modern CUI controls](https://github.com/TomXingCan/CarGOUI/issues/13). Its two supported Proc paths are **Blizzard Native artwork + Timer** and opt-in **Independent CUI artwork + Timer**. Legacy per-region replacement/suppression is not available in this release; retained compatibility code and saved modes do not have native takeover authority. Its first-SHOW/consumption exposure defect is not declared fixed.

The author previously reported four P1 checks passing on **MAGE / 62, build 69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`**, then confirmed final RC `9bef4c3` and authorized release. These are author confirmations, separate from offline tests; they do not supply a new per-class matrix or invented measurements. [Independent Proc acceptance](docs/PROC_INDEPENDENT_ACCEPTANCE.md) retains the exact P1 observations. The [#15 release-admission decision](docs/PROC_MEMORY_RELEASE_REVIEW.md) is not a claim that a memory leak was established or fixed. Only the Proc diagnostics/quarantine subset of [#16](https://github.com/TomXingCan/CarGOUI/issues/16) is included; the broader Reload-required framework is not complete. The release combines the work from [PR #12](https://github.com/TomXingCan/CarGOUI/pull/12) and [PR #14](https://github.com/TomXingCan/CarGOUI/pull/14).

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
| Proc presentation strategy and independent live artwork master | Current classToken + specID; independent strategy is explicit opt-in; its artwork master does not disable Timer |
| Independent artwork enabled | Explicit per-region opt-in within that class/spec; absent means disabled |
| Proc artwork mode, asset, RGB, transform and animation | Separate optional `region.appearance`; the stored legacy mode is retained without controlling independent rendering, which reuses the visual preferences |
| Options placement, branding animation, minimap visibility/angle | Independent shell records, separate from class settings and from one another |

No class/spec/Profile/manual-theme selector. Appearance shows the automatically selected configuration context. The Proc Region Editor selects one Proc and one stable region in the current specialization. Timer typography remains shared by that specialization; the existing Appearance editor controls it. Timer RGB and artwork RGB are independent. Mobility and Free move always use Blizzard's player class color. Proc timers default to class color; only custom artwork has its own opacity control. Options themes do not alter reminder style or native state.

Options uses the [900x640 Modern CUI shell](docs/MODERN_UI_1.0.1.md): a compact Header, registered Sidebar navigation, shared content grid and status Footer. Graphite surfaces, teal-to-blue-violet accents, owned toggles/inputs/sliders and short animated dropdowns provide one visual system across pages. Proc uses section cards and Display segments; Class Tools remains unregistered and invisible. Header, Body, sidebar blank areas, borders and static explanations drag the whole window; interactive controls keep their input. Release, close and Esc end movement; existing placement persists and stays screen-constrained. [RC2's drag record](docs/DRAG_RC2.md) explains source ownership and native current-pointer pickup.

Dropdowns, checkboxes and sliders update immediately. Numeric rows allow exact inline input; valid Enter or focus loss saves, Escape cancels, and context/page changes or closing discard drafts. No Apply step is required. Appearance's Font, Font Size, Outline, Shadow and Scale share the appropriate class/spec scope; reset affects only that style, not positions or other scopes. Font choices combine Client default, distinct language-compatible Blizzard faces, and locally registered LSM fonts in a paged popup. Factory typography retains the 1.0.0 defaults: Friz Quadrata or the appropriate wide-language client face, size 24, OUTLINE, shadow on, Scale 1. Size range is 8–72, Scale 0.5–3 and new XY edits -10000..10000. Scaling does not multiply saved offsets.

Proc's **Timer color** uses the selected ability/region, previews native-picker changes, and saves only on Okay. Cancel/close/region/spec changes discard drafts without closing another addon's subsequently owned picker. **Use class color** removes only that region's override. Color changes update existing text objects without Aura queries, timer rebuilds or native gate-alpha changes. See [regional colors](docs/PROC_COLORS.md).

General/Mobility switches and XY edit the same current-class Mobility record. Disabling Mobility also stops Free move and Mobility samples, leaving Proc independent. Proc enable controls its current-spec module; independent artwork has separate gates. Reset Mobility offsets affects only that class group; Reset region offsets affects only the selected region. Reset class + Options requires confirmation and preserves other classes/migration backups; the existing `reset` slash command immediately applies the same reset scope, subject to successful policy cleanup.

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

**Blizzard Native + Timer** preserves Blizzard artwork and places native-bound countdown digits at its audited visual midpoint plus the existing timer XY. Old settings do not automatically opt into independent artwork. Legacy Custom replacement and Timer Only suppression are unavailable in 1.0.1. Their saved modes are retained as inactive preferences; they neither take over native artwork nor establish that legacy first-SHOW exposure was fixed.

**Independent CUI + Timer** draws CUI-owned artwork from valid public Spell Alert SHOW/HIDE events, without acquiring, reading or suppressing Blizzard artwork objects. Select **Artwork strategy → Independent CUI**, enable the live artwork master, and explicitly enable each desired region. Manually set Blizzard **Spell Alert Opacity** to zero; live independent artwork requires both `spellActivationOverlayOpacity=0` and `displaySpellActivationOverlays=0`. CUI never writes these settings. If either value is unavailable or nonzero, independent artwork pauses with a notice while saved preferences and native-bound Timer behavior remain intact.

Global zero hides **all** Blizzard Proc artwork, including uncovered Procs, and cannot keep one side genuinely Native. Turning independent artwork off, disabling Proc, switching strategy/spec, or quarantine does not restore that game setting. **Restore Blizzard Spell Alert Opacity manually when native alerts are needed.** The artwork master and per-region artwork switch leave Timer enabled; the separate Proc enable switch stops the Proc module. A strategy change clears previous graphical state, so an existing buff needs a new valid public SHOW before independent artwork appears. Native timer bootstrap is not a substitute artwork event.

The Region Editor reuses the existing audited asset catalog, artwork tint/alpha/scale and animation controls. Advanced expands desaturation, width/height, rotation, mirrors, separate artwork XY and animation speed/intensity/direction. Its expansion is session-only. Legacy mode and style values are preserved when changing strategy; independent rendering uses the visual preferences without activating the legacy mode. Timer color/XY/typography stay separate. A cross-class image grants no trigger or timer support. Reset artwork changes only `region.appearance`, not strategy, region opt-in or timer settings. See [architecture](docs/PROC_APPEARANCE_V2.md) and [independent behavior and acceptance](docs/PROC_INDEPENDENT_ACCEPTANCE.md).

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

External TEST uses clearly marked fixed `8.0` samples; Free move is text-only. Proc choices include only audited regions for current class/spec/talents, even without an active effect, independently of Mobility. Samples never enter native Aura/live state. In independent strategy, TEST follows the selected region's explicit artwork enablement and remains available with live artwork paused or its master off. Its artwork objects are separate from live objects and never own native suppression. TEST cannot prove live event delivery or duration correctness. Closing, Stop test, combat or spec change clears temporary samples; live resynchronizes. Reminders/guides cannot be dragged.

Header retains automatic faction identity and original full-color branding. Body retains complete 13-class/40-spec identity mappings and static motif geometry. The Modern CUI design system integrates these as restrained identity layers over common graphite surfaces and teal-to-blue-violet component accents; historical palette data is not a promise that the old full-window skin remains unchanged. No Themes page or manual theme control is added.

No spec uses the class base; unavailable identity uses neutral and recovers on identity events. Opening resolves identity; hidden windows stop theme listeners. Gameplay-disabled/unlearned states do not affect themes. Lightweight maps are core UI data, not an excuse to initialize business adapters. The shared bounded Line pool draws only the current lower-right watermark behind readable content; no promotional backgrounds, particles, rotations or per-frame color changes. [Theme sources](docs/THEMES.md) and [coverage](docs/BODY_THEME_COVERAGE.md) distinguish implemented mappings from client visual acceptance.

## Loading, diagnostics and migration

The native load-on-demand CarGOUI_Data TOC executes all listed class adapter definitions together. Only the current class factory and active skill/spec paths run. Class subdirectories are not separate load-on-demand boundaries. The account CarGOUIDB may restore all saved classes; accessing/initializing only one is not the same as other records being unloaded. The two-folder design intentionally does not promise strict per-class code/config zero-loading. No deletion, compression or forced GC conceals this tradeoff.

The adapter registry rejects duplicates rather than letting class files overwrite core methods. Other classes receive no business listeners, cooldown queries, reminders or bindings. Old CarGOUI_Mage bridge writes are quarantined; users should still remove its obsolete program folder. Cached frames/code are not claimed unloaded.

Existing Copy diagnostics / Refresh snapshot distinguishes loaded modules, instantiated entries, loaded/accessed config and listener/active/allocated binding counts. Runtime memory KB and cumulative CPU ms are read on demand; CPU is unavailable without scriptProfile. Native requested-active slots are not visible buff counts, and copied binding state is not read back. No background sampling or whole-library scan. [Loading boundaries](docs/LOAD_BOUNDARIES.md) explains client measurement.

Schema 5 uses `classes[classToken].mobility` and `classes[classToken].proc[specID]`. Legacy Mage values migrate only to Mage using effective skill/current-position rules; conflicts and choice rules remain in migrations.scope5. New classes receive independent factory copies. Only missing/invalid fields migrate, without overwriting later valid settings on login. [Configuration scopes](docs/CONFIG_SCOPES.md) records details.

## Import / Export

Current class is the default, including its already-saved Proc specs without initializing others. All saved settings includes saved classes and shell placement/animation/minimap preferences. Exports contain only whitelisted user data, never identity/theme/skills/runtime/migration/import backups. Select text and Ctrl+C; no unsupported direct-clipboard claim.

Import validates before review, then Confirm commits atomically. Source class/spec remains unchanged; omitted classes/specs/regions survive. An included region without timer RGB clears its old timer-color override; omitted artwork settings clear its old appearance override and use the selected strategy's defaults. An included Proc scope without the optional policy returns to legacy replacement, while omitted fields in a local edit preserve current settings. Independent regions require explicit enablement. Strategy changes through editing, import, restore or reset clean old artwork before commit; cleanup failure rejects the transaction and retains unresolved ownership. Schema 5 and transfer format 1 remain unchanged. Older strict importers can reject new optional fields safely. A single pre-import snapshot can be restored with review/confirmation. Close/combat cancels drafts/transactions; unlock never auto-submits. Artwork-only switches do not rebind Timer. Minimap settings retain their library-bound table; older strings without minimap fields preserve current preferences. See [transfer specification](docs/SETTINGS_TRANSFER_FORMAT.md).

## Development and verification

`Core/`: initialization/events/config/migration/loading/diagnostics; `Config/`: defaults/locales/commands; `Database/`: shared appearance context/themes; `UI/`: rendering/Preview/Options/branding/launchers; `Modules/Mobility/`: active-skill engine/Free move; `Modules/Proc/`: native Aura/overlay lifecycle; `UI/ProcDisplay.lua`: native positioning/style boundary; `Modules/CarGOUI_Data/`: LoD manifest, registry, shared state engine and class-private definitions; `tests/`: Lua 5.1 and static checks.

`python tests/run_tests.py` requires existing lupa.lua51 and uses clearly identified Python JSON/Base64 mocks; it does not install dependencies. The final delivery output records actual source and extracted-package results rather than reusing a historical count. Author onsite reports, offline simulations and source/API audits are separate evidence. The author's final RC confirmation authorizes this release; it does not imply universal class/source coverage, native-speaker certification or unreported client CPU/memory measurements. The [release notes](docs/RELEASE_1.0.1.md) distinguish release admission from unresolved investigations.

`python tools/package.py --output <directory>` builds the committed production version from a clean tree and checks both TOCs against `addon.version`. Repository tools test `--addon-root <extracted/CarGOUI>`, recording source commit/tree and archive SHA256. The formal installer is `CarGOUI-1.0.1.zip`, accompanied by its exact checksum and verification report; earlier staging RCs and the published 1.0.0 installer remain unchanged. The installer contains two addon directories, required runtime/media files and license/user documents. Research, Class Tools logging, external observers, tests, review records, art sources and scripts stay outside it. Preserve SavedVariables; addon version, schema 5 and transfer format 1 are distinct.

## License

Current project-owned source from the commit introducing the ARR [LICENSE](LICENSE), including this 1.0.1 release and future project-owned source unless expressly licensed otherwise, is **All Rights Reserved**. The source cutover identifies the terms; no historical release is relicensed. Official distributions may be installed and run for personal gameplay under LICENSE.

The already published **v1.0.0 remains GPL-3.0-only as originally distributed**: [historical license](https://github.com/TomXingCan/CarGOUI/blob/v1.0.0/LICENSE) and [unchanged Release](https://github.com/TomXingCan/CarGOUI/releases/tag/v1.0.0). No previously granted GPL rights are revoked or restricted by this cutover.

Branding assets under Media/Branding remain **All Rights Reserved**, separately described in [their notice](Media/Branding/LICENSE.txt). Embedded libraries retain their original licenses and notices. See [NOTICE.md](NOTICE.md) for the exact scopes and [the ownership audit](docs/LICENSING_AUDIT_1.0.1.md) for cutover evidence.
