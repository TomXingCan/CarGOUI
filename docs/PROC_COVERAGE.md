# Native Proc coverage — 0.1.0-alpha.15

Audit target: **Retail 12.1.0.69933 Live**. This is the real native Proc coverage
ledger, independent of Body-theme and Mobility coverage.

All **12 non-Mage classes / 37 specializations were reviewed**. The increment
connects **63 specialization-scoped runtime definitions / 81 independently
configurable regions** across **33** of those specializations. The other four
have explicit empty-scope decisions below. These numbers count implementation
records, not distinct spell names, simultaneous buffs, or client-tested effects.
Different spec records and independent hidden left/right owners are counted
separately. Talent exclusions mean the complete catalogue is not active at once.
“All classes reviewed” does not mean every specialization has an eligible timer.

Every newly admitted record below is **implemented and source-audited**, and is
**covered by the offline suite; see the exact delivery report for execution
results**. All new classes remain **pending real-client combat, aura-exposure,
placement, taint and performance acceptance**. No WoW client is attached here.
An offline test showing an inserted aura cannot prove its actual gameplay mapping.

The existing Mage paths are retained. The user's latest alpha.14 feedback
confirms normal Mage Proc behavior, per-region color behavior and combat Options
behavior in the tested usage. Their actual client build and an exhaustive
per-talent/per-region matrix were not supplied. That feedback is not silently
extended to these new classes or every future build.

## Evidence and status conventions

- [SpellActivationOverlay, exact build](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933)
  proves a nonzero native texture, owner, layout and scale. Its row ID is not a spell ID.
- [ScreenLocation, exact build](https://wago.tools/db2/ScreenLocation/csv?build=12.1.0.69933)
  identifies the native region layout. Recorded scales below preserve the DB2
  floating-point value, not an invented common scale.
- [Pinned build information](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/build_info.txt)
  and the spell-dump headers identify **12.1.0.69933**. All spell dump/source links
  below use revision `18429d2f8fd75ebe7be92fec37394055a0254b77`. They establish spell
  effects and relationships; no simulator duration or state is used at runtime.
- [Batch 1 evidence](PROC_BATCH1.md), [Batch 2 evidence](PROC_BATCH2.md) and
  [Batch 3 evidence](PROC_BATCH3.md) provide the finite-aura records, current
  drivers, supplementary DB2 joins and exclusions. A finite dummy duration or
  matching English name alone is insufficient evidence for a timer association.
- Target overlay CSV SHA256:
  `b123f93f96efeea03150a4b9e4c8f0761cc51f661a3494abc1c831fc3ba16bbe`.
  Target ScreenLocation CSV SHA256:
  `95865ff516b2dd5ad110541e20eae2d6ed184390efbce813cd63e02105d251b9`.
  Per-class source fingerprints and direct supplemental queries are retained in
  the batch documents. Source snapshots are development evidence, not runtime dependencies.

In the detailed tables, **A** means the exact native helpful-aura slot may
bootstrap before public graphic history is known; subsequent SHOW/HIDE gates
use observed owner lifecycle. It does not prove replay of an already-visible
graphic. **E** means a public native SHOW is additionally required; aura presence
alone cannot bootstrap that entry. Both use the actual AuraContainer timer and
native DurationTextBinding, never a fixed lifetime, Lua stack count, or aura readback.
`Known` means all listed verified learned drivers; `Any` means at least one;
`Not` excludes a learned replacement. These checks select available definitions,
not whether a buff is currently present. An unknown/restricted learned-state
result does not authorize a speculative entry.

Each detailed row has status **implemented / source-audited / offline-covered /
client-pending**, abbreviated **I / S / O / P**. Source audit is evidence for
admission, not a claim that a hidden aura is exposed correctly in a live combat
session. Exact timer IDs remain separate from cast IDs and graphical owners.
The stable region IDs listed below are the saved XY/RGB keys; font, font size,
outline, shadow and scale stay shared by current class + specialization.

## All 37 non-Mage specializations

| Class | Specialization (ID) | Definitions / regions | Implemented native Proc families or empty-scope reason | Client status |
|---|---|---:|---|---|
| Death Knight | Blood (250) | 2 / 3 | Crimson Scourge; Dance of Midnight | Pending |
| Death Knight | Frost (251) | 3 / 3 | Rime; Killing Machine | Pending |
| Death Knight | Unholy (252) | 2 / 2 | Sudden Doom | Pending |
| Demon Hunter | Havoc (577) | 1 / 2 | Chaos Theory | Pending |
| Demon Hunter | Vengeance (581) | 1 / 1 | Untethered Rage | Pending |
| Demon Hunter | Devourer (1480) | 1 / 1 | Moment of Craving | Pending |
| Druid | Balance (102) | 1 / 1 | Owlkin Frenzy | Pending |
| Druid | Feral (103) | 1 / 2 | Clearcasting | Pending |
| Druid | Guardian (104) | 3 / 3 | Gore; Galactic Guardian; Celestial Might | Pending |
| Druid | Restoration (105) | 1 / 2 | Clearcasting | Pending |
| Evoker | Devastation (1467) | 1 / 1 | Essence Burst | Pending |
| Evoker | Preservation (1468) | 2 / 2 | Essence Burst; Lifespark | Pending |
| Evoker | Augmentation (1473) | 1 / 1 | Essence Burst | Pending |
| Hunter | Beast Mastery (253) | 4 / 7 | Deathblow; Howl of the Pack Leader: Wyvern; Howl of the Pack Leader: Boar; Howl of the Pack Leader: Bear | Pending |
| Hunter | Marksmanship (254) | 3 / 4 | Lock and Load; Precise Shots; Deathblow | Pending |
| Hunter | Survival (255) | 3 / 6 | Howl of the Pack Leader: Wyvern; Howl of the Pack Leader: Boar; Howl of the Pack Leader: Bear | Pending |
| Monk | Brewmaster (268) | 1 / 1 | Potential Energy | Pending |
| Monk | Windwalker (269) | 2 / 2 | Blackout Kick!; Strength of the Black Ox | Pending |
| Monk | Mistweaver (270) | 3 / 3 | Strength of the Black Ox; Zen Pulse; Potential Energy | Pending |
| Paladin | Holy (65) | 3 / 3 | Infusion of Light; Divine Purpose | Pending |
| Paladin | Protection (66) | 1 / 1 | Divine Purpose | Pending |
| Paladin | Retribution (70) | 3 / 3 | Divine Purpose; Art of War; Righteous Cause | Pending |
| Priest | Discipline (256) | 4 / 5 | Surge of Light; Power of the Dark Side; Harsh Discipline | Pending |
| Priest | Holy (257) | 3 / 3 | Surge of Light; Benediction | Pending |
| Priest | Shadow (258) | 4 / 4 | Surge of Light; Shadowy Insight; Mind Flay: Insanity | Pending |
| Rogue | Assassination (259) | 1 / 2 | Blindside | Pending |
| Rogue | Outlaw (260) | 1 / 1 | Opportunity | Pending |
| Rogue | Subtlety (261) | 1 / 2 | Ancient Arts | Pending |
| Shaman | Elemental (262) | 1 / 2 | Lava Surge | Pending |
| Shaman | Enhancement (263) | 0 / 0 | **None admitted:** Maelstrom Weapon graphics represent stack/resource thresholds; excluded from finite Proc scope. | No timer claimed |
| Shaman | Restoration (264) | 2 / 3 | Lava Surge; High Tide | Pending |
| Warlock | Affliction (265) | 1 / 2 | Nightfall | Pending |
| Warlock | Demonology (266) | 1 / 2 | Demonic Core | Pending |
| Warlock | Destruction (267) | 0 / 0 | **None admitted:** No current source-verified finite screen graphic admitted; action-bar highlights are not substitutes. | No timer claimed |
| Warrior | Arms (71) | 0 / 0 | **None admitted:** Tactician is an Overpower charge/reset flash, not a finite empowerment timer. | No timer claimed |
| Warrior | Fury (72) | 0 / 0 | **None admitted:** No matching finite native screen-graphic Proc established in the target audit. | No timer claimed |
| Warrior | Protection (73) | 1 / 1 | Revenge! | Pending |

No Proc business monitoring starts for an empty current-spec catalogue. A spec
with admitted records can also be empty for a particular character when its
required talents/passives are not learned. Available regions are selected from
the audited current-scope definitions independently of whether the effect is
active, so admitted regions can be configured before triggering them. Unknown
candidates in the exclusion table have no selectable Preview/color placeholders.

## Detailed implementation catalogue

In the graphic column, each segment is **owner → texture; native layout × scale;
DB2 row**. `LeftRight` expands into two distinct regions; native `Bottom` is not
replaced with a made-up top or central position. Different sources sharing a
stable region use the explicitly audited timer provider, not whichever ID is
most convenient. All rows target **12.1.0.69933**.

### Death Knight

[Production definitions](../Modules/CarGOUI_Data/Classes/DeathKnight/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/deathknight.txt) · [Relationship evidence](PROC_BATCH1.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Blood 250 — Crimson Scourge | 81141 | 81141 → 511104; LeftRight × 1; row 3166 | `deathknight_blood_crimson_scourge_left`<br>`deathknight_blood_crimson_scourge_right` | Known 81136; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Blood 250 — Dance of Midnight | 1264568 | 1264568 → 449487; Top × 1; row 4960 | `deathknight_blood_dance_midnight_top` | Known 1264506; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Frost 251 — Rime | 59052 | 59052 → 450930; Top × 1; row 121 | `deathknight_frost_rime_top` | Known 59057; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Frost 251 — Killing Machine | 51124 | 51124 → 458740; Left × 1; row 3150 | `deathknight_frost_killing_machine_left` | Known 51128; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Frost 251 — Killing Machine | 438833 | 438833 → 458740; Right × 1; row 4495 | `deathknight_frost_killing_machine_second_right` | Known 51128; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Unholy 252 — Sudden Doom | 81340 | 81340 → 450932; Left × 1; row 120 | `deathknight_unholy_sudden_doom_left` | Known 49530; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Unholy 252 — Sudden Doom | 461135 | 461135 → 450932; Right × 1; row 4649 | `deathknight_unholy_sudden_doom_second_right` | Known 49530; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |

### Demon Hunter

[Production definitions](../Modules/CarGOUI_Data/Classes/DemonHunter/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/demonhunter.txt) · [Relationship evidence](PROC_BATCH3.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Havoc 577 — Chaos Theory | 390195 | 390195 → 801267; LeftRight × 1; row 4225 | `demonhunter_577_chaos_theory_left`<br>`demonhunter_577_chaos_theory_right` | Known 389687; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Vengeance 581 — Untethered Rage | 1270476 | 1270476 → 450930; Top × 1; row 4983 | `demonhunter_581_untethered_rage_top` | Known 1270444; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Devourer 1480 — Moment of Craving | 1238495 | 1238495 → 7549806; Top × 1; row 4853 | `demonhunter_1480_moment_of_craving_top` | Devourer talent 1238488 or set 1296616; exact native aura covers both, no hidden-bonus known query; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |

### Druid

[Production definitions](../Modules/CarGOUI_Data/Classes/Druid/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/druid.txt) · [Relationship evidence](PROC_BATCH2.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Balance 102 — Owlkin Frenzy | 157228 | 157228 → 463452; Top × 1; row 3369 | `druid_balance_owlkin_frenzy_top` | Known 24858; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Feral 103 — Clearcasting | 135700 | 135700 → 510823; LeftRight × 1; row 1899 | `druid_feral_clearcasting_left`<br>`druid_feral_clearcasting_right` | Known 16864; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Guardian 104 — Gore | 93622 | 93622 → 510822; Top × 1; row 205 | `druid_guardian_gore_top` | Known 210706; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Guardian 104 — Galactic Guardian | 213708 | 213708 → 450914; Left × 1; row 3193 | `druid_guardian_galactic_guardian_left` | Known 203964; Not 1252871; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Guardian 104 — Celestial Might | 1272376 | 1272376 → 592058; Right × 1; row 4999 | `druid_guardian_celestial_might_right` | Guardian 12.0 4pc 1264816; no hidden set-bonus known query; E | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Restoration 105 — Clearcasting | 16870 | 16870 → 450929; LeftRight × 0.75; row 148 | `druid_restoration_clearcasting_left`<br>`druid_restoration_clearcasting_right` | Known 113043; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |

### Evoker

[Production definitions](../Modules/CarGOUI_Data/Classes/Evoker/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt) · [Relationship evidence](PROC_BATCH2.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Devastation 1467 — Essence Burst | 359618 | 359618 → 4699056; Left × 1; row 4057 | `evoker_devastation_essence_burst_left` | Any (375721 or 376872); A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Preservation 1468 — Essence Burst | 369299 | 369299 → 4699056; Left × 1; row 4110 | `evoker_preservation_essence_burst_left` | Known 369297; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Preservation 1468 — Lifespark | 394552 | 394552 → 4699057; Top × 1; row 4259 | `evoker_preservation_lifespark_top` | Known 443177; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Augmentation 1473 — Essence Burst | 392268 | 392268 → 4699056; Left × 1; row 4243 | `evoker_augmentation_essence_burst_left` | Known 396187; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |

### Hunter

[Production definitions](../Modules/CarGOUI_Data/Classes/Hunter/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/hunter.txt) · [Relationship evidence](PROC_BATCH3.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Beast Mastery 253 — Deathblow | 378770 | 378770 → 449487; Bottom × 1; row 5084 | `hunter_253_deathblow_bottom` | Any (466930); A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Beast Mastery 253 — Howl of the Pack Leader: Wyvern | 471878 | 471878 → 774420; LeftRight × 1; row 4747 | `hunter_253_pack_leader_wyvern_left`<br>`hunter_253_pack_leader_wyvern_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Beast Mastery 253 — Howl of the Pack Leader: Boar | 472324 | 472324 → 774420; LeftRight × 1; row 4745 | `hunter_253_pack_leader_boar_left`<br>`hunter_253_pack_leader_boar_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Beast Mastery 253 — Howl of the Pack Leader: Bear | 472325 | 472325 → 774420; LeftRight × 1; row 4746 | `hunter_253_pack_leader_bear_left`<br>`hunter_253_pack_leader_bear_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Marksmanship 254 — Lock and Load | 194594 | 194594 → 450926; Top × 1; row 3043 | `hunter_254_lock_and_load_top` | Any (194595 or 1301406); A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Marksmanship 254 — Precise Shots | 260242 | 270436 → 1029138; LeftRight × 1; row 3730<br>270437 → 1029139; LeftRight × 1; row 3731 | `hunter_254_precise_shots_left`<br>`hunter_254_precise_shots_right` | Known 260240; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Marksmanship 254 — Deathblow | 378770 | 378770 → 449487; Bottom × 1; row 5084 | `hunter_254_deathblow_bottom` | Any (343248 or 466932); A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Survival 255 — Howl of the Pack Leader: Wyvern | 471878 | 471878 → 774420; LeftRight × 1; row 4747 | `hunter_255_pack_leader_wyvern_left`<br>`hunter_255_pack_leader_wyvern_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Survival 255 — Howl of the Pack Leader: Boar | 472324 | 472324 → 774420; LeftRight × 1; row 4745 | `hunter_255_pack_leader_boar_left`<br>`hunter_255_pack_leader_boar_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Survival 255 — Howl of the Pack Leader: Bear | 472325 | 472325 → 774420; LeftRight × 1; row 4746 | `hunter_255_pack_leader_bear_left`<br>`hunter_255_pack_leader_bear_right` | Known 471876; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |

### Monk

[Production definitions](../Modules/CarGOUI_Data/Classes/Monk/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/monk.txt) · [Relationship evidence](PROC_BATCH3.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Brewmaster 268 — Potential Energy | 1270990 | 1270990 → 469752; Top × 1; row 4985 | `monk_268_potential_energy_top` | Known 1270958; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Windwalker 269 — Blackout Kick! | 116768 | 116768 → 1001511; Right × 1; row 1132 | `monk_269_blackout_kick_right` | Any (137384 or 1250042); A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Windwalker 269 — Strength of the Black Ox | 443112 | 443112 → 623950; Left × 1.20000004768; row 4561 | `monk_269_strength_black_ox_left` | Known 443110; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Mistweaver 270 — Strength of the Black Ox | 443112 | 443112 → 623950; Left × 1.20000004768; row 4561 | `monk_270_strength_black_ox_left` | Known 443110; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Mistweaver 270 — Zen Pulse | 446334 | 446334 → 623951; Right × 1.10000002384; row 4572 | `monk_270_zen_pulse_right` | Known 446326; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |
| Mistweaver 270 — Potential Energy | 1270990 | 1270990 → 469752; Top × 1; row 4985 | `monk_270_potential_energy_top` | Known 1270958; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |

### Paladin

[Production definitions](../Modules/CarGOUI_Data/Classes/Paladin/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/paladin.txt) · [Relationship evidence](PROC_BATCH1.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Holy 65 — Infusion of Light | 54149 | 54149 → 459313; Left × 1; row 4349 | `paladin_holy_infusion_light_left` | Known 53576; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Holy 65 — Infusion of Light | 458213 | 458213 → 459313; Right × 1; row 4628 | `paladin_holy_infusion_light_second_right` | Known 53576; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Holy 65 — Divine Purpose | 223819 | 223819 → 459314; Top × 1; row 3232 | `paladin_holy_divine_purpose_top` | Known 223817; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Protection 66 — Divine Purpose | 223819 | 223819 → 459314; Top × 1; row 3232 | `paladin_protection_divine_purpose_top` | Known 223817; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Retribution 70 — Divine Purpose | 408458 | 408458 → 459314; Top × 1; row 4322 | `paladin_retribution_divine_purpose_top` | Known 408459; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Retribution 70 — Art of War | 406086 | 406086 → 450913; Left × 1; row 4312 | `paladin_retribution_art_war_left` | Known 406064 + 1261113; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Retribution 70 — Righteous Cause | 402916 | 402916 → 450913; Left × 1; row 4303 | `paladin_retribution_righteous_cause_left` | Known 402912 + 1261113; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |

### Priest

[Production definitions](../Modules/CarGOUI_Data/Classes/Priest/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/priest.txt) · [Relationship evidence](PROC_BATCH1.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Discipline 256 — Surge of Light | 114255 | 114255 → 450933; Left × 1; row 1080 | `priest_discipline_surge_light_left` | Any (109186); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Discipline 256 — Surge of Light | 128654 | 128654 → 450933; Right × 1; row 1430 | `priest_discipline_surge_light_second_right` | Any (109186); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Discipline 256 — Power of the Dark Side | 198069 | 198069 → 592058; LeftRight × 1; row 3146 | `priest_discipline_power_dark_side_left`<br>`priest_discipline_power_dark_side_right` | Known 198068; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Discipline 256 — Harsh Discipline | 373183 | 373183 → 469752; Top × 1; row 4129 | `priest_discipline_harsh_discipline_top` | Known 373180; E | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Holy 257 — Surge of Light | 114255 | 114255 → 450933; Left × 1; row 1080 | `priest_holy_surge_light_left` | Any (109186 or 453783); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Holy 257 — Surge of Light | 128654 | 128654 → 450933; Right × 1; row 1430 | `priest_holy_surge_light_second_right` | Any (109186 or 453783); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Holy 257 — Benediction | 1262766 | 1262766 → 469752; Top × 1; row 4955 | `priest_holy_benediction_top` | Known 1262755; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Shadow 258 — Surge of Light | 114255 | 114255 → 450933; Left × 1; row 1080 | `priest_shadow_surge_light_left` | Any (109186); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Shadow 258 — Surge of Light | 128654 | 128654 → 450933; Right × 1; row 1430 | `priest_shadow_surge_light_second_right` | Any (109186); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Shadow 258 — Shadowy Insight | 375981 | 375981 → 627609; Top × 1; row 4152 | `priest_shadow_shadowy_insight_top` | Any (375888 or 450138); A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Shadow 258 — Mind Flay: Insanity | 391401 | 391401 → 592058; Left × 1; row 4290 | `priest_shadow_mind_flay_insanity_left` | Known 453783; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |

### Rogue

[Production definitions](../Modules/CarGOUI_Data/Classes/Rogue/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/rogue.txt) · [Relationship evidence](PROC_BATCH2.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Assassination 259 — Blindside | 121153 | 121153 → 449493; LeftRight × 1; row 1246 | `rogue_assassination_blindside_left`<br>`rogue_assassination_blindside_right` | Known 328085; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Outlaw 260 — Opportunity | 195627 | 195627 → 450926; Top × 1; row 3071 | `rogue_outlaw_opportunity_top` | Known 279876; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Subtlety 261 — Ancient Arts | 1269163 | 1269163 → 656728; LeftRight × 1.29999995232; row 4974 | `rogue_subtlety_ancient_arts_left`<br>`rogue_subtlety_ancient_arts_right` | Known 1268939; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |

### Shaman

[Production definitions](../Modules/CarGOUI_Data/Classes/Shaman/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/shaman.txt) · [Relationship evidence](PROC_BATCH2.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Elemental 262 — Lava Surge | 77762 | 77762 → 449491; LeftRight × 1; row 1204 | `shaman_elemental_lava_surge_left`<br>`shaman_elemental_lava_surge_right` | Known 77756; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Restoration 264 — Lava Surge | 77762 | 77762 → 449491; LeftRight × 1; row 1204 | `shaman_restoration_lava_surge_left`<br>`shaman_restoration_lava_surge_right` | Known 77756; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |
| Restoration 264 — High Tide | 288675 | 288675 → 2851788; Top × 0.80000001192; row 3881 | `shaman_restoration_high_tide_top` | Known 157154; A | I / [S](PROC_BATCH2.md#admitted-mappings) / O / P |

### Warlock

[Production definitions](../Modules/CarGOUI_Data/Classes/Warlock/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/warlock.txt) · [Relationship evidence](PROC_BATCH1.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Affliction 265 — Nightfall | 264571 | 264571 → 449492; LeftRight × 1; row 3693 | `warlock_affliction_nightfall_left`<br>`warlock_affliction_nightfall_right` | Known 108558; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |
| Demonology 266 — Demonic Core | 264173 | 264173 → 2888300; LeftRight × 1; row 3697 | `warlock_demonology_demonic_core_left`<br>`warlock_demonology_demonic_core_right` | Known 267102; A | I / [S](PROC_BATCH1.md#admitted-definitions) / O / P |

### Warrior

[Production definitions](../Modules/CarGOUI_Data/Classes/Warrior/ProcDefinitions.lua) · [Target spell data](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/warrior.txt) · [Relationship evidence](PROC_BATCH3.md)

| Spec / Proc | Timer aura | Graphic sources | Stable regions | Availability; bootstrap | Status |
|---|---:|---|---|---|---|
| Protection 73 — Revenge! | 5302 | 5302 → 603339; Right × 0.85000002384; row 1488 | `warrior_73_revenge_right` | Known 6572; A | I / [S](PROC_BATCH3.md#implemented-mappings) / O / P |

## Mapping-specific limits and distinctions

- **Independent hidden owners:** Killing Machine 438833, Sudden Doom 461135,
  Infusion of Light 458213 and Surge of Light 128654 use their own verified
  finite aura IDs for the right region. No left-aura/stack-count substitution
  chooses the right clock. Whether each permitted native filter is populated
  in actual combat remains client acceptance. Batch 1 records direct DB2
  duration/effect evidence for owners absent from the extracted spell dumps.
- **Harsh Discipline:** its graphic has a native threshold of two. An actual
  public SHOW establishes graphical availability; Lua never compares stacks.
  Reloading after a SHOW that the addon did not receive may leave this entry
  gated until a new SHOW. This is a declared resynchronization limitation.
- **Celestial Might:** the current finite aura is linked to the Guardian
  12.0 four-piece effect. An actual SHOW is required, without pretending that a
  hidden equipment-bonus spell is normally learned. The same missed-event
  reload limitation applies. Its admitted Preview remains explicitly synthetic.
- **Moment of Craving:** current Devourer talent and 12.1 set paths both grant
  the same finite 1238495 effect. The spec admits the exact native aura slot
  without a talent-only gate that would incorrectly reject the equipment path.
- **Precise Shots:** timer 260242 is separate from graphic owners 270436/270437.
  The target owners refer to driver 260240, which explicitly refers to 260242;
  the current class implementation constructs that actual buff. Both owners
  share each stable left/right timer. The retained second graphic does not
  prove two live charges; late HIDE for one owner cannot clear another observed
  active owner. Actual event emission and native aura exposure remain pending.
- **Pack Leader:** Wyvern, Boar and Bear are distinct finite next-Kill-Command
  empowerments. Their separate native aura slots preserve overlapping stock
  geometry; the periodic cycle aura 471877 is not displayed or reconstructed.
- **High Tide:** target SpellMisc 362564 uses finite Duration 63, and the
  288675 effects modify Chain Heal. Its explicit driver 157154 is linked through
  TraitDefinition / TraitNode / TraitTreeLoadout to Restoration 264 in the same
  build. It is not a duration guessed from another expansion or mana counting.
- **Replacement and alternate drivers:** Galactic Guardian excludes Red Moon;
  Ret Art of War/Righteous Cause additionally require Light Within; Holy Surge
  accepts Manifested Power, while Shadow Mind Flay: Insanity requires that
  actual current driver rather than the changed historical talent 391399.
  Other alternate gates are recorded exactly in the catalogue above.

## Existing Mage baseline — retained

| Spec | Retained runtime definitions / regions | Native mapping summary | Evidence / acceptance |
|---|---:|---|---|
| Arcane 62 | 3 / 5 | Clearcasting: timer 263725, owners 1277420/1277421/1277422, textures 1027131/1027132/1027133, LeftRight × 1; Arcane Soul: 451038, texture 449486, LeftRightOutside × 1; Overpowered Missiles: 1277009, texture 6160020, Top × 1 | Source audit retained; covered by regression suite. User confirms current Mage behavior in tested alpha.14 usage; no exhaustive client matrix/build claim. |
| Fire 63 | 5 / 8, including one guarded legacy record | Hot Streak 48108, texture 449490, LeftRight × 1; Heating Up 48107, same texture, LeftRight × 0.5; Pyroclasm 269651, texture 457658, Top × 0.7; Hyperthermia 383874, texture 6160021, LeftRightOutside × 1.5; guarded Fury of the Sun King 383883, texture 457658, Top × 0.7 | Current Mage implementation retained. Fury is native-event-only and is not offered as an available current talent in Preview; its historical driver is not newly certified. |
| Frost 64 | 3 / 3 | Fingers of Frost: left timer/owner 44544 and right timer/owner 126084, texture 449489, scale 1; Brain Freeze 190446, texture 450930, Top × 1 | Existing independent right-owner path retained; no Lua layer inference. User's general Mage acceptance is not item-by-item proof of every Frost scenario. |

Unless stated separately, each Mage timer equals its graphical owner. The
Clearcasting finite timer is deliberately different from its three infinite
dummy graphic owners. See [Mage audit and stable region inventory](MAGE_PROC_COVERAGE.md)
and [Clearcasting correction](CLEARCASTING_ALPHA13.md). Historical per-row
“pending” wording there describes the earlier delivery; the dated user-feedback
update and the bounded acceptance statement above describe the latest report.
No Mage ID, saved region key, style or runtime path is replaced for this expansion.

## Excluded or unconfirmed — not a future-work checklist

These candidates do not gain usable Preview/color entries in this increment.
They are audit conclusions, not blocked user tasks or commitments to expand
scope. Missing proof is reported separately from an explicitly excluded mechanic.

| Class / scope | Candidate | Decision and exact gap |
|---|---|---|
| Paladin Protection | Grand Crusader 85416 | **Excluded:** Avenger's Shield cooldown reset/readiness graphic. A different Strength effect is not an established timer alias. |
| Paladin Retribution | Art of War / Righteous Cause without Light Within 1261113 | **Excluded configuration:** only reset/readiness without the verified empowerment; admitted rows require that talent. |
| Priest | The Penitent One 336009 | **Unconfirmed current driver:** retained legendary-era 336011 does not establish a current talent path. |
| Priest Shadow | Surge of Insanity right owner 409129 | **Unconfirmed association:** changed driver 391399 does not prove current activation from Manifested Power. Left 391401 is implemented separately. |
| Priest Shadow | Shadowy Insight owner 1287613 | **Unconfirmed selection/replacement:** finite owner exists, but its current phase/driver relation versus 375981 is not established. No duplicate Top timer is invented. |
| Warlock | Nightfall 1260279 | **Unconfirmed variant:** current activation/replacement rule is not established; verified current provider 264571 is used. |
| Warlock | Inevitable Demise 334320 / 334463 | **Unconfirmed current availability; threshold concern:** retained talent/legendary rows without verified current talent entry. |
| Warlock Destruction | No admitted target candidate | **Empty reviewed scope:** action-bar highlights or old records are not evidence for the requested finite screen-artwork timer. |
| Druid Balance | Eclipse visuals 93430 / 93431 | **Unconfirmed timer association:** 3-second dummy graphical records are not the real 48517/48518 Eclipse duration. Neither a dummy deadline nor an unproven real-aura substitution is used. |
| Druid Restoration | Memory of the Mother Tree 189877 | **Unconfirmed current driver:** retained legendary relation 339064 alone is insufficient. |
| Shaman Enhancement | Maelstrom Weapon 170585–170588 / 187890 / 467442 | **Excluded:** resource/stack-threshold graphics. Finite dummy artwork is not a finite gameplay Proc timer. |
| Evoker | Essence Burst hidden right graphic 361519 | **Unconfirmed provider/spec relation:** a same name or nominal duration does not prove which actual spec aura clock it follows. Left regions are independently implemented. |
| Evoker Preservation | Alternate Lifespark 443176 | **Unconfirmed driver variant:** current 443177 explicitly triggers admitted 394552; no evidence authorizes merging 443176 into its filter. |
| Rogue Outlaw | Deep Insight 340584 | **Unconfirmed current driver:** linked Guile Charm 340086 is retained legendary-era data. |
| Hunter Survival | Grenade Juggler owner 470492 | **Unconfirmed current association:** old GCD modifier graphic does not establish a link to current recharge aura 470488 granted by 459843. |
| Hunter Marksmanship | Lock and Load: Explosive Shot 1300701 | **Unconfirmed screen layout:** target ScreenLocationID 0 has no target location row. No fabricated center/Top placement. |
| Monk | Combo Breaker: Chi Explosion 159407 | **Unconfirmed current driver:** retained historical graphic, without a verified current Chi Explosion talent. |
| Monk Brewmaster | Light/Moderate Stagger 124275 / 124274 | **Excluded:** ongoing damage-state presentation, not this Proc scope. |
| Warrior Arms | Tactician 199854 | **Excluded:** two-second dummy Overpower reset/charge flash is not a deadline on a finite empowerment. |
| Warrior Fury | No admitted target candidate | **Empty reviewed scope:** target Warrior graphic join identifies Revenge and Tactician, neither a Fury finite Proc. No placeholder timer. |
| Demon Hunter Vengeance / Devourer | Voidfall 1256302 | **Excluded:** infinite stack/spending aura; finite Final Hour 1256322 is a different aftermath and cannot time the original graphic. |
| All classes | Texture-zero overlay rows; ordinary buffs; passive/resource readiness | **Outside scope:** no eligible native screen artwork / finite Proc effect. Action-bar glow alone does not qualify. |

The retained, event-guarded Mage legacy record is documented separately above;
it is not a newly admitted current talent and does not receive a new selectable
sample. Detailed records and source links for these decisions are in the three
batch documents.

## Runtime, settings and loading boundary

One shared native engine handles admitted classes. Only the current class
adapter and specialization catalogue are activated; verified learned drivers
filter its entries. Empty scopes create no Proc monitoring. Specialization or
talent changes invalidate the current catalogue and stop obsolete slots/listeners.
Different effects and graphical owners do not clear one another's still-valid
regions. Repeated triggers and spec returns reuse bounded, stable identities;
a slot is never retargeted to a different aura.

Digits are native duration text at the matching graphic region plus the saved
region offset. Proc fonts remain per class/spec; each region retains optional
RGB and independent XY. Default color falls back to current class color without
persisting a prior character's RGB. Options/TEST/color changes do not infer real
aura state. TEST uses explicit synthetic samples and is not counted as live
support. Closing Options or stopping TEST leaves enabled live Proc, Mobility
and confirmed Time Spiral Free move monitoring working. Alpha.14 combat Options
restrictions remain in effect.

Installation remains **CarGOUI + CarGOUI_Data**. One Data TOC loads its listed
static code, and shared SavedVariables can restore records for other classes.
“Not activated/read” is not called “not loaded.” No all-class aura scan, manual
stack counter, forced GC, new page, new selector or additional top-level class
package is introduced. Native containers may retain bounded static subscriptions
and pooled objects after their active aura monitoring is disabled; this is not a
promise of complete code/widget/cache unloading. No CPU or memory number is
claimed from offline tests or ZIP size.

The [native API audit](PROC_API_AUDIT.md) documents filtering, DurationTextBinding,
public graphical lifecycle, geometry and restrictions. Its original Mage-only
scope description is historical; this catalogue records the alpha.15 classes
using that shared path. Missing required native APIs produce an explicit
unsupported status, not a fabricated clock or an out-of-combat-only success claim.

## Offline verification and in-game acceptance

The offline suite covers class/spec discovery, exact mapped aura providers,
current-driver and replacement selection, native location/scale, individual
region identity, pre-trigger configuration, simultaneous effects, refresh,
partial/final consumption, expiry, late-owner HIDE, reused slots, disabled/empty
scopes, secret-data tripwires, bounded lifecycle, style/color isolation, combat
Options, Mage, Mobility and Free move regressions. **Use the final extracted-ZIP
test output for actual command results and counts.** Source-map fixtures and
synthetic lifecycle checks remain separate kinds of evidence.

For each newly admitted family available to the test character:

1. Record the actual client build, class/spec, learned drivers and enabled native
   spell-overlay graphics. Configure its admitted regions before triggering it.
2. Trigger the actual effect and compare each number with its own Blizzard
   graphic. Check left/right, small/large, Bottom and overlapping native regions
   at the current UI scale; no label, icon or added background should appear.
3. Refresh the real duration; consume only part where applicable, then consume
   fully and allow natural expiry. Verify remaining regions are not cleared by
   unrelated graphics or late HIDE events. Repeat with simultaneous Procs.
4. Repeat during real combat. Close Options and stop TEST; real timers continue.
   Confirm opening Options in combat follows the retained alpha.14 deferred-open
   behavior, without starting TEST or a picker during lockdown.
5. Switch talents/specs and reload with an already-active effect; verify settings
   stay scoped and stale bindings stop. Check the stated native-event-only
   resynchronization limit rather than accepting a guessed bootstrap.
6. Test native graphic opacity/enable settings and record public diagnostics if
   a timer is absent or misplaced. Diagnostics report **Native tracking** and
   requested slots, not Lua-observed secret aura presence.
7. After repeated triggers/spec changes, inspect actual client counts and measure
   client CPU/memory if profiling. Record the actual observations; offline
   bounded-object checks do not establish live performance figures.

Unconfirmed/excluded candidates above do not need the user to validate a guessed
implementation. Their absence does not invalidate the admitted finite timers;
the absence and its reason remain explicit in this coverage ledger.
