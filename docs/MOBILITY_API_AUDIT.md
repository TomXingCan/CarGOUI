# Mobility expansion: API and mechanism audit

Target evidence is Retail **12.1.0, build 69933**. This is a source/data audit and an implementation contract, not a claim of testing inside that client. The player's actual build is recorded by diagnostics. Existing Mage Blink / Shimmer code remains unchanged; the user's successful Mage test does not certify another spell or class.

## Evidence

- Blizzard's exported [spell API declarations](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua) and [spell return-field declarations](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua) are pinned to the audited UI-source revision. This repository mirrors client-supplied Blizzard source.
- SimulationCraft's extracted [build information](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/build_info.txt) identifies 12.1.0.69933. Its class spell dumps are extracted client data, not an addon dependency or live runtime state. Definition `audit` fields record the relevant dump and spell ID.
- [DurationObject methods](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectAPIDocumentation.lua), [duration time modifiers](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectSharedDocumentation.lua), [curve methods](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaCurveObjectAPIDocumentation.lua), and [region display methods](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua) establish the permitted native display route.

## Engine boundary

`CarGOUI_Data/Shared/SpellState.lua` exposes `data:ReadAbilityState(entry, definition)`. The selected definition must contain a public, positive integer `spellID` and public `spellName`. The class adapter resolves actual learning and replacements before calling it. A database record is never evidence that the player learned a spell. The engine processes that ID only; it does not scan a class library, poll every frame, infer casts, or read another class's configuration.

The result retains the existing renderer contract: `entry`, `status`, `reason`, `spellID`, `spellName`, `path`, `duration`, and optional `visibility`. Timers and visibility objects are temporary runtime values, never SavedVariables. Native curve caches are created only when needed and can be cleared through `ClearAbilityStateCache()` on adapter deactivation.

| API state | Implemented decision | Time source |
| --- | --- | --- |
| Public charge count is at least one | Ready; no reminder | None needed |
| Public charge count is zero and recharge active | Depleted | Current `GetSpellChargeDuration(ID)` |
| Secret count; public capacity one and recharge active | The only slot is recovering; Depleted | Current charge duration |
| Secret count; public capacity greater than one | Only an explicitly audited ability may use native visibility; otherwise Restricted | Current charge duration, separate from visibility |
| Secret count; no active recharge | Unknown; never assert Ready from this alone | None |
| No charge record; valid enabled cooldown record | Native spell cooldown, excluding GCD | `GetSpellCooldownDuration(ID, true)` |
| Missing, inconsistent, unsupported or unexpectedly secret metadata | Explicit Unknown / Restricted / Unsupported reason | No fabricated fallback |

The real next-charge object continues an already-running recharge. Consuming the final charge several seconds after the first does not restart a full timer. Charge capacity is read from the API, never assumed to be two. Native text binding clears zero/expired output, and restricted time never enters Lua text concatenation, numerical formatting or width measurement.

An ordinary cooldown with a secret `IsZero()` result is reported as **Tracking**, not as a Lua-known depleted state. A native visibility curve is reported as **Native tracking**. The renderer sends its result directly to `SetAlpha`, without comparing, serializing, doing arithmetic on, or reading back that result.

## Direct exhaustion API check

The audited spell surface supplies no public exact predicate for “zero current charges.” `maxCharges` and recharge `isActive` are public, but activity means some charge is recovering, not that all are spent. Cooldown `isOnGCD` is public but explicitly valid only while responding directly to `SPELL_UPDATE_COOLDOWN`; it is not used after event coalescing, login, or talent refresh. It also cannot exclude a spell's separate inter-use cooldown.

`IsSpellUsable`, range, resource availability, loss of control, cast count and aura state are not substituted for charge exhaustion. `curve:Evaluate(secretCurrentCharges)` is not used: its secret-argument permission does not grant an ordinary addon a general numeric-classification route. Native Boolean-to-alpha helpers also cannot manufacture the missing zero-charge Boolean.

## Per-ability native visibility

For newly audited charge abilities, visibility uses `GetSpellCooldownDuration(ID, true)` to exclude GCD, then evaluates its **total BaseTime** through a native step curve. Numeric text still uses the independently obtained charge-recovery duration in **RealTime**. The two objects have different responsibilities. The unchanged Mage adapter retains its separately audited include-GCD classifier.

An explicit `chargeVisibility` declaration contains `baseCooldownMS`, `baseGCDMS`, `boundaryMS`, `ignoreGCD = true`, and a nonempty `audit` reference. The public `GetSpellBaseCooldown(ID)` result must exactly match both expected metadata values. `boundaryMS` is the reviewed envelope of that particular spell's ordinary and category inter-use cooldown, not its recharge period. There is no class default, global Mage threshold or universal 1.6-second cutoff. The curve changes from invisible to visible at the next millisecond after that envelope; this number never creates or estimates the countdown.

| Separately reviewed abilities | Ordinary / category inter-use envelope | Native GCD treatment | Recharge evidence |
| --- | --- | --- | --- |
| Charge 100, Heroic Leap 6544, Intervene 3411 | 1500 ms (category at most 1000 ms) | Excluded by API | [Warrior dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/warrior.txt); Double Time adds a charge and reduces recharge, Bounding Stride reduces Leap recharge |
| Death's Advance 48265, Death Charge 444347 | 1000 ms | Excluded by API | [Death Knight dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/deathknight.txt); Death's Echo adds charge capacity |
| Chi Torpedo 115008 | 0 ms | Excluded by API | [Monk dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/monk.txt); base two charges, no ordinary/category inter-use cooldown |
| Angelic Feather 121536 | 0 ms | Its 1500 ms GCD is excluded by API | [Priest dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/priest.txt); base three charges, no ordinary/category inter-use cooldown |
| Roll 109132 | 800 ms | Excluded by API | Monk dump; Celerity and Lighter Than Air change charge recovery/capacity, not a longer ordinary interval |
| Divine Steed 190784 | 750 ms | Excluded by API | [Paladin dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/paladin.txt); Cavalier adds a charge, Divine Spurs reduces recharge |
| Disengage 781, Harpoon 190925 | 1000 ms (category 500 / 1000 ms) | Excluded by API | [Hunter dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/hunter.txt) |
| Fel Rush 344865 / 195072, Infernal Strike 189110 | 1000 ms | GCD 250 / 500 / 0 ms excluded by API | [Demon Hunter dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/demonhunter.txt); Blazing Path adds capacity, Erratic Felheart reduces recharge |
| Shift 1234796; Vengeful Retreat 198793; Voidblade 1245412 | 800 / 750 / 0 ms, respectively | Excluded by API | Demon Hunter dump; separate values, not inherited from Fel Rush |
| Hover 358267; Verdant Embrace 360995 | 1000 / 500 ms, respectively | Excluded by API | [Evoker dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt); Aerial Mastery / Wings of Liberty add capacity; Warp and recharge-rate modifiers retain their separate responsibilities |
| Shadowstep 36554; Grappling Hook 195457 | 1000 / 800 ms, respectively | Excluded by API | [Rogue dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/rogue.txt) and DB2 category 1206; normal-state rule only, see Death's Arrival below |
| Deep Breath 357210 / 433874 | 1000 ms | Its 1500 ms GCD is excluded by API | Evoker dump; normal-state rule only, see Strafing Run and Recall below |

Public runtime counts always take precedence over this classifier. A changed/missing public metadata result, absent native method, or missing explicit ability rule produces **Restricted / blocked: native charge visibility** for the affected secret multi-charge branch. Public counts, ordinary cooldowns and valid single-slot recovery do not depend on that gate.

The target-build [SpellCooldowns table](https://wago.tools/db2/SpellCooldowns/csv?build=12.1.0.69933) separates ordinary `RecoveryTime`, `CategoryRecoveryTime` and GCD `StartRecoveryTime`; [SpellCategories](https://wago.tools/db2/SpellCategories/csv?build=12.1.0.69933) and [SpellCategory](https://wago.tools/db2/SpellCategory/csv?build=12.1.0.69933) identify charge pools. For example, Verdant Embrace has a 500 ms category interval and zero ordinary recovery field; the extracted spell summary displays their effective 500 ms interval. `GetSpellBaseCooldown` is still checked at runtime. A different interpretation of that public base value blocks the restricted classifier and must be reported with the actual build; it is not silently accepted. Shadowstep's base category capacity is zero in the DB2 table, while learned passives add capacity. Base data is therefore never used as a runtime availability or learning test.

### What the source cannot prove

Blizzard's [cooldown-viewer implementation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua#L840) treats partial recharge differently from exhausted spell cooldowns. This is useful context, not a guarantee of the C++ DurationObject selection for every skill, talent or hotfix. Its privileged comparisons are not copied into addon code.

For each new charge spell, actual-client validation must confirm that its ordinary object reports zero/inter-use time while a charge remains and the real recharge total when depleted, including when the remaining recharge is shorter than the inter-use interval. BaseTime avoids time-rate scaling, but does not prove all direct duration adjustments preserve the separation. An undocumented longer inter-use category could cause an incorrect visible state; a real recovery reduced into the envelope could be missed. Runtime base-metadata checks do not detect every such state. These are explicit client acceptance conditions, not offline passes or a claim that every secret combat branch is proven.

There is no Lua secret numeric read, error-based probe, frame readback, snapshot frozen before combat, manual charge counter, cast-history reconstruction or fixed recharge simulation. Unsupported mechanics must keep a specific reason instead of borrowing another spell's rules.

### Temporary free casts and destination mechanics

An extra free use is not necessarily ordinary recharge reduction. Rogue Death's Arrival (`454433`, temporary effects `457333` / `457343`) and Evoker Strafing Run (`1266151`, temporary effect `1266165`) involve charge capacity and an **Ignore Spell Charge Cooldown** effect. Time Spiral also has such effects for several classes. The API must reflect a usable temporary charge and/or its native cooldown selection correctly; static category data cannot establish that behavior. Acceptance must explicitly cover receiving and consuming the free use while the underlying pool is exhausted. No aura scanning or fabricated extra-use counter is added. A definition that blocks a specific unaudited mechanism must state that reason; a generic duration classifier is not proof that the mechanism works.

The delivered definitions explicitly block Shadowstep / Grappling Hook while Death's Arrival is learned and Deep Breath while Strafing Run is learned. This prevents those unverified branches from being advertised as working. Normal versions keep their audited rules. External Time Spiral is a remaining acceptance condition: learning a player's own talent cannot detect an ally's temporary effect, and no unsupported aura workaround is introduced.

Evoker Recall (`371806`) temporarily replaces the flight action with return spell `371838`. Return actions, translocation anchors and teleport destinations are not inferred from cooldown activity. The factory must honor the actual override, reject unknown replacements, and stop the stale outbound alert when the active spell changes. For Transcendence: Transfer and Demonic Circle: Teleport, the engine can report the selected spell's real cooldown, but a Ready cooldown state does not assert that a spirit/circle exists or that it is in range. No position, range or buff state is presented as a recharge countdown.

Alter Time and Reflection are explicitly unsupported additions: their return windows are not ordinary “no uses until this cooldown expires” states. Fel Rush's return action and Flying Serpent Kick's landing action also retain explicit unsupported stages. Those reasons are diagnostic output, not synthetic countdowns, and they do not replace or modify the already validated Blink / Shimmer path.

## Verification and client acceptance

Offline tests exercise ordinary and secret data independently of the combat flag, separate simultaneous abilities and duration identities, public and native charge visibility, metadata mismatch, missing interfaces, zero/GCD, and native output ownership. They verify the code contract under supplied API responses; they cannot emulate Blizzard's security enforcement or prove the native engine's spell-specific selection.

For every newly active ability, record actual build, specialization and talents, then check: one charge remains during GCD/inter-use; final charge spent after a staggered first use; recovery of one charge; reset or recharge-rate change; combat entry/exit; and Options/Preview closure. Also test new ordinary cooldowns with GCD-only, silence, control, missing target and insufficient-resource conditions: none of those alone is depletion. Test restricted values in real combat, not only a public-data fixture with `inCombat=true`.

No new-class client validation, runtime CPU/memory measurement, or taint/security certification was performed in this development environment. The final test output and gameplay acceptance document are separate delivery artifacts; existing user confirmation applies to the unchanged Mage branch only.
