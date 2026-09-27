# Batch 1 native Proc audit — alpha.15

Target: **Retail 12.1.0.69933 Live**. This batch implements Death Knight, Paladin, Priest and Warlock definitions through the shared Proc capability. It does not change Mage, Mobility, Free move, themes, Options layout or saved settings.

All new client behavior is **pending real-client acceptance**. The mapping audit and Lua checks below are offline evidence, not proof that a specific player's combat scene or hidden aura visibility has passed. Previously reported Mage success does not imply these classes have been tested.

## Versioned evidence

- [Target SpellActivationOverlay export](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933): owner, texture, location, scale and trigger mode, keyed by DB2 row below.
- [Target ScreenLocation export](https://wago.tools/db2/ScreenLocation/csv?build=12.1.0.69933): 3=Left, 4=Top, 8=Right, 9=LeftRight.
- The four [SimulationCraft SpellDataDump files](https://github.com/SimulationCraft/simc/tree/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump) have the exact header `SimulationCraft 1210-01 for World of Warcraft 12.1.0.69933 Live`. Pinned revision: `18429d2f8fd75ebe7be92fec37394055a0254b77`. Citations below identify spell blocks using both ID and raw-file LF line, rather than borrowing duration or talent information from another patch.
- Supplemental target DB2 rows verify hidden owners absent from that extracted spell dump: [Killing Machine 438833 SpellMisc](https://wago.tools/db2/SpellMisc/csv?build=12.1.0.69933&filter%5BSpellID%5D=438833), [Surge of Light 128654 SpellMisc](https://wago.tools/db2/SpellMisc/csv?build=12.1.0.69933&filter%5BSpellID%5D=128654), [SpellDuration](https://wago.tools/db2/SpellDuration/csv?build=12.1.0.69933). Queries may return substring matches; only the exact ID row is evidence.

The inventory filters **nonzero OverlayFileDataID**, then checks the class spell family plus hidden-name rows. Rows with texture 0 are action-bar highlighting, not admitted screen artwork. Data files existing in the target client do not alone prove current talent availability: retained historical records are separated below.

## Admitted definitions

`owner = aura` means the exact owner aura supplies the native timer; it does not mean IDs were assumed interchangeable because names matched. All definitions below have a same-build finite aura record. No fixed duration appears in runtime code. `Known` IDs are verified talent/passive drivers, never hidden timer IDs. Regions retain separate saved color and XY even where the spec shares one font style.

| Class / spec | Proc; owner = timer aura | Native source row / texture / regions | Finite record and driver evidence | Activation |
|---|---|---|---|---|
| DK Blood 250 | Crimson Scourge 81141 | 3166 / 511104 / Left + Right | deathknight.txt L2140, 15s; baseline Blood driver81136 L2123 | Known81136; exact aura bootstrap |
| DK Blood 250 | Dance of Midnight 1264568 | 4960 / 449487 / Top | DK L20326, 15s; Blood talent1264506 L20309 directly describes the empowered Heart Strike | Known1264506; exact aura bootstrap |
| DK Frost 251 | Rime 59052 | 121 / 450930 / Top | DK L1627, 15s, Triggered By59057; Frost baseline59057 L1664 | Known59057; exact aura bootstrap |
| DK Frost 251 | Killing Machine 51124 | 3150 / 458740 / Left | DK L1094, 10s, Triggered By51128; Frost talent51128 L1133 | Known51128; exact aura bootstrap |
| DK Frost 251 | Killing Machine 438833 | 4495 / 458740 / Right | SpellMisc731130 → DurationIndex1 → 10000ms; SpellEffect1131670 is its self aura; SAO uses this exact owner with matching KM class masks | Known51128; exact owner aura; no left-aura alias or Lua stack selection |
| DK Unholy 252 | Sudden Doom 81340 | 120 / 450932 / Left | DK L2234, 10s, Triggered By49530; Unholy talent49530 L865 | Known49530; exact aura bootstrap |
| DK Unholy 252 | Sudden Doom 461135 | 4649 / 450932 / Right | DK L16921, separate 10s aura; description explicitly references driver49530 | Known49530; exact right-owner aura |
| Paladin Holy 65 | Infusion of Light 54149 | 4349 / 459313 / Left | paladin.txt L1288, 15s, Triggered By53576; Holy talent53576 L1164 | Known53576; exact aura bootstrap |
| Paladin Holy 65 | Infusion of Light 458213 | 4628 / 459313 / Right | Paladin L18022, separate finite15s hidden aura with description53576 and empowerment tooltip | Known53576; exact right-owner aura |
| Paladin Holy65 + Protection66 | Divine Purpose 223819 | 3232 / 459314 / Top | Paladin L5543, 12s; driver223817 L5524 lists **both** Holy and Protection Talent Entries | Known223817; separate spec configuration IDs |
| Paladin Retribution70 | Divine Purpose 408458 | 4322 / 459314 / Top | Paladin L14092, 12s; Ret driver408459 L14128 | Known408459; exact aura bootstrap |
| Paladin Retribution70 | Art of War 406086 | 4312 / 450913 / Left | Paladin L13576, 20s; talent406064 L13554; Light Within1261113 L20793 adds80% to its actual damage effect | Known406064 **and**1261113; otherwise excluded readiness indicator |
| Paladin Retribution70 | Righteous Cause 402916 | 4303 / 450913 / Left | Paladin L12741, 20s; talent402912 L12723; same explicit Light Within1261113 effect label5745 | Known402912 **and**1261113; otherwise excluded readiness indicator |
| Priest all three specs | Surge of Light 114255 | 1080 / 450933 / Left | priest.txt L2264, 20s; generic class talent109186 L2103 | Known109186; Holy also accepts Manifested Power453783 |
| Priest all three specs | Surge of Light 128654 | 1430 / 450933 / Right | SpellMisc102675 → DurationIndex18 → 20000ms; SpellEffect164238 is its self aura; native row has same Surge class mask as114255 | Same driver gate; exact finite right-owner aura, never a guessed left timer |
| Priest Discipline256 | Power of the Dark Side 198069 | 3146 / 592058 / Left + Right | Priest L3979, 30s, Triggered By198068; Disc talent198068 L3961 | Known198068; exact aura bootstrap |
| Priest Discipline256 | Harsh Discipline 373183 | 4129 / 469752 / Top | Priest L9399, 30s, two charges; Disc talent373180 L9382; SAO TriggerType2 and threshold2 | Known373180; **native SHOW required**, no Lua stack comparison |
| Priest Holy257 | Benediction 1262766 | 4955 / 469752 / Top | Priest L16526, 30s; Holy talent1262755 L16424 explicitly upgrades Flash Heal | Known1262755; exact aura bootstrap |
| Priest Shadow258 | Shadowy Insight 375981 | 4152 / 627609 / Top | Priest L9997, 10s; Shadow talent375888 L9868; Voidweaver450138 L13140 explicitly grants Shadowy Insight in Shadow | Known375888 **or**450138; exact aura bootstrap |
| Priest Shadow258 | Mind Flay: Insanity 391401 | 4290 / 592058 / Left | Priest L11071, 30s action-spell upgrade; current Archon Manifested Power453783 L13870 explicitly grants it | Known453783; exact aura bootstrap |
| Warlock Affliction265 | Nightfall 264571 | 3693 / 449492 / Left + Right | warlock.txt L6367, 12s cast empowerment; Affliction talent108558 L2392 references264571 effects | Known108558; exact aura bootstrap |
| Warlock Demonology266 | Demonic Core 264173 | 3697 / 2888300 / Left + Right | Warlock L6282, 20s; driver267102 L6636 describes stacks reducing Demonbolt cast time; triggered by270171 | Known267102; exact aura bootstrap |
| Warlock Destruction267 | None admitted | No current verified finite screen graphic | Action-bar-only rows and retained/unconfirmed candidates are not substituted for a screen timer | No Proc business engine when empty |

All admitted scales are1 in target SAO. Separate sources for left and right use separate exact-aura runtime providers, with permanent separate region IDs. A left HIDE cannot clear a right record; partial consumption is left to each real native aura/filter, not manual counting.

The required known gates are availability filters only. Duration, presence, refresh and expiry belong to native AuraContainer filtering and DurationTextBinding. The presence of a hidden owner's finite DB2 duration is not evidence that its permitted native filter has already passed in a real combat session; that remains explicit client acceptance.

## Cross-checks and limits that affect selection

- [Pinned Paladin implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/paladin/sc_paladin_retribution.cpp#L1164) separately constructs Art of War406086 and Righteous Cause402916. Target Light Within1261113 explicitly modifies these exact aura effects. No return/cooldown duration is fabricated, and no passive readiness-only variant is advertised without the empowering talent.
- [Pinned Priest implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/priest/sc_priest.cpp#L695) triggers Surge of Light for Holy and Mind Flay: Insanity for Shadow from Manifested Power; L3404–3406 select391401 as the real aura. Current391399 is a damage/Insanity-generation modifier, so it is **not** used as the learned gate for391401.
- [Shadowy Insight provider](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/priest/sc_priest_shadow.cpp#L2054) is375981; its trigger checks Shadowy Insight or Void Empowerment at L2927. The second native owner1287613 is not blindly aliased to375981.
- [Pinned Warlock implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/warlock/sc_warlock_init.cpp#L139) explicitly selects Nightfall264571. L252–253 select Demonology's267102 driver and264173 buff. No runtime dependency on SimulationCraft is introduced.
- Harsh Discipline is a finite empowering buff, but its graphic is threshold-gated. After reload with an already-active graphic, the addon must wait for an allowed native SHOW if no lifecycle event was received. Aura existence alone cannot prove threshold2. This is an explicit resynchronization limit, not an implemented Lua stack workaround.

## Excluded or unconfirmed native graphical rows

These are audit results, not product commitments or a queue of required future features. They have no usable Preview/color entry.

| Candidate | Target record | Decision |
|---|---|---|
| Grand Crusader85416 | SAO112; Paladin L1847 finite6s | Pure Avenger's Shield cooldown-reset/readiness indicator. The separate Strength effect is not this native owner; no invented alias. |
| Art of War / Righteous Cause without1261113 | SAO4312/4303 | Pure reset indicator without the verified empowering talent; gated out. |
| The Penitent One336009 | SAO3966; Priest L7616, old336011 legendary driver | No current talent/driver condition established in this target; retained data alone is not current support. |
| Surge of Insanity409129 | SAO4329; Priest L11889 finite30s hidden right owner | Current391399 no longer describes the old trigger, and no verified current right-owner activation link from Manifested Power was found. Left391401 is implemented; no right alias or sample. |
| Shadowy Insight1287613 | SAO5037; Priest L17288 finite10s hidden charge-bypass aura | The native row and finite source exist, but current phase/driver selection versus375981 is unconfirmed. Does not silently replace375981 or produce two simultaneous top timers. |
| Nightfall1260279 | SAO4927; Warlock L16906 finite12s; adds instant/free Seed | Current activation/replacement rule is not established; the current pinned implementation chooses264571. No second guessed variant filter or Preview. |
| Inevitable Demise334320 /334463 | SAO4061/3962; Warlock L8538/L8567 | Retained talent/legendary data; no current talent entry verified. Threshold50 is not treated as evidence of a supported timer. |
| Other class-family SAO rows with texture0 | Same target table | Action-bar highlights only, including many newly named talents. Outside the native screen-artwork scope regardless of finite buff duration. |

## Offline verification and client acceptance

Focused Lua5.1 checks passed: all four factories load, every admitted owner's texture/scale matches the target SAO export, current-spec region IDs are unique, hidden aura IDs are not used as known-spell gates, Holy Manifested Power remains an alternate Surge driver, and Harsh Discipline retains configurable Preview despite native-event activation.

All-known fixture record/region counts (not a promise of every talent simultaneously available):

| Class | Spec: records / regions |
|---|---|
| Death Knight | 250: 2 / 3; 251: 3 / 3; 252: 2 / 2 |
| Paladin | 65: 3 / 3; 66: 1 / 1; 70: 3 / 3 |
| Priest | 256: 4 / 5; 257: 3 / 3; 258: 4 / 4 |
| Warlock | 265: 1 / 2; 266: 1 / 2; 267: 0 / 0 |

Delivery tests additionally exercise integrated Runtime, Preview, colors, combat gating, owner lifecycle and the final extracted ZIP; see the delivered test output for actual results.

Client acceptance for each selected spec: trigger each learned admitted effect; compare native left/right/top artwork and timer independently; refresh and partially consume; let expire; trigger multiple effects together; reload with active effects; repeat in combat; close Options and stop TEST; toggle native Proc graphics/CVar opacity; switch spec and verify saved regional offsets/colors. Confirm no hidden-region stale timer and no timer when the associated graphic is absent. Harsh Discipline must remain absent below its graphic threshold. Do not treat mock aura insertion as mapping evidence or real combat acceptance.

## Source snapshot SHA256

The raw target files used during audit are cached under `work/`; they are development evidence, not runtime dependencies or additions to the two-folder AddOn installation.

| File | SHA256 |
|---|---|
| spell-data-deathknight.txt | `153059029642f56925099e960815d9b6bcd4d39317aa1eea77ba759a0bd6e562` |
| spell-data-paladin.txt | `352a28e72d96d599f1ae89243ad321c3d9fecf0f0a6673577edf62c92f9d1643` |
| spell-data-priest.txt | `f28bff81c4879ba1f541950b3208e717356681ecbb38cbaf8f7af52e0c74d0da` |
| spell-data-warlock.txt | `e73c47d963cf4a2b9814be32550fa6c4a106c872631326914156bc08153e88d1` |
| wago-SpellActivationOverlay-69933.csv | `b123f93f96efeea03150a4b9e4c8f0761cc51f661a3494abc1c831fc3ba16bbe` |
| wago-ScreenLocation-69933.csv | `95865ff516b2dd5ad110541e20eae2d6ed184390efbce813cd63e02105d251b9` |
| batch1-SpellMisc-438833.csv | `a12a4c3a976076730504d79bd021880dfae22e3fb9935cf2ae3277c664f64783` |
| batch1-SpellMisc-128654.csv | `8bf30304d710b6664f87d9fbd6229ecdcebefbc676646a4d2c2b434bfbde8439` |
| batch1-SpellEffect-438833.csv | `571e92a078af1fc483fc1d84d28936415919efeedf3d26034d75a46f088d61d0` |
| batch1-SpellEffect-128654.csv | `115222e866de008c6132880c445d91cc66ab4ab81c77df8d61e06500765f9601` |
| batch1-SpellDuration-1.csv | `eb4dfa17c3d47b06561fe11a7c06d09fd7d8bdb65572b36d2ef6300294133b05` |
| batch1-SpellDuration-18.csv | `d69e43a4a820bea623d6262401c31e9984617ad01bbaa95a0ab4307525cae257` |
