# Mobility coverage and boundaries (scope revised in alpha.12)

This table describes implemented **current-class, current-spec, actually learned skills**, not a claim that every path passed in-game. Mage Blink/Shimmer retains the user-confirmed path. New-path combat checks remain separate from offline results in delivery reports.

## Scope

Retain ordinary Mobility implemented in alpha.11. Alpha.12 moved development to Mage Proc; the only Mobility addition was **Free move, confirmed by the user as Time Spiral**. Its implementation is recorded in the Proc/Free move delivery documents. Special returns/talents, portals and other free recasts are outside development scope and are not mandatory acceptance tasks. Unimplemented candidates are not available Preview entries. Necessary safety rejection/recovery checks on supported ordinary paths remain.

The evidence and safe boundaries below are not a backlog expansion. Time Spiral Free move is not Hover's moving-cast duration. Subsequent Proc/localization work does not silently expand this Mobility list.

## Sources and versions

Target data: **Retail 12.1.0.69933**. Names, spell IDs, ordinary cooldown/GCD, charge categories and recharge data come from these traceable extracts. Recharge durations are audit data, never runtime countdown constants.

- [SimulationCraft data at 18429d2f8fd75ebe7be92fec37394055a0254b77](https://github.com/SimulationCraft/simc/tree/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump). Each class header says `12.1.0.69933 Live`. Definition references `class.txt#L...` identify that commit's LF-counted lines.
- [SpellName, build 69933](https://wago.tools/db2/SpellName/csv?build=12.1.0.69933) and [Spell](https://wago.tools/db2/Spell/csv?build=12.1.0.69933) fill SimC-filtered omissions: Shadowstep, Demonic Circle: Teleport, Transcendence: Transfer and aquatic Wild Charge. They also confirm former Displacement 389713 is named **Reflection** in this build.
- [SpellCooldowns](https://wago.tools/db2/SpellCooldowns/csv?build=12.1.0.69933), [SpellCategories](https://wago.tools/db2/SpellCategories/csv?build=12.1.0.69933) and [SpellCategory](https://wago.tools/db2/SpellCategory/csv?build=12.1.0.69933) cross-check ordinary/category cooldown, GCD and charge category. `Wago:table:number` identifies a row; `spellID=...` explicitly denotes SpellID filtering.

No complete other-addon class database was copied. Candidates are generated only when the class factory runs, and become active only after native learning/override filtering. The Mage adapter remains intact; historical extra-return definitions used a separate factory, subject to the exclusions below.

## Candidate scopes: 13 classes, 40 specs

Common means supplied by the class factory, **not monitored if unlearned**. Spec skills are not assumed learned in other specs. Unspecialized characters receive only common candidates.

| Class | Spec IDs | Common candidates | Spec additions |
| --- | --- | --- | --- |
| Warrior | Arms 71 / Fury 72 / Protection 73 | Charge, Heroic Leap, Intervene | Protection: Shield Charge |
| Paladin | Holy 65 / Protection 66 / Retribution 70 | Divine Steed | — |
| Hunter | Beast Mastery 253 / Marksmanship 254 / Survival 255 | Disengage, Aspect of the Cheetah | Survival: Harpoon |
| Rogue | Assassination 259 / Outlaw 260 / Subtlety 261 | Sprint, Shadowstep | Outlaw: Grappling Hook |
| Priest | Discipline 256 / Holy 257 / Shadow 258 | Angelic Feather | — |
| Death Knight | Blood 250 / Frost 251 / Unholy 252 | Death's Advance, Wraith Walk | Frost/Unholy: Death Charge replacement |
| Shaman | Elemental 262 / Enhancement 263 / Restoration 264 | Spirit Walk, Gust of Wind, Wind Rush Totem | Enhancement: Feral Lunge |
| Mage | Arcane 62 / Fire 63 / Frost 64 | Existing Blink/Shimmer; extra returns excluded | — |
| Warlock | Affliction 265 / Demonology 266 / Destruction 267 | Demonic Circle: Teleport | — |
| Monk | Brewmaster 268 / Windwalker 269 / Mistweaver 270 | Roll/Chi Torpedo, Transcendence: Transfer, Tiger's Lust | Windwalker: Flying Serpent Kick |
| Druid | Balance 102 / Feral 103 / Guardian 104 / Restoration 105 | Dash/Tiger Dash, Wild Charge form family, Stampeding Roar form family | — |
| Demon Hunter | Havoc 577 / Vengeance 581 / Devourer 1480 | Starter Fel Rush, Vengeful Retreat | Havoc: Fel Rush, Felblade, The Hunt, Metamorphosis; Vengeance: Infernal Strike, Felblade; Devourer: Shift, Voidblade, The Hunt |
| Evoker | Devastation 1467 / Preservation 1468 / Augmentation 1473 | Hover, Deep Breath, Verdant Embrace, Rescue | Devastation: steerable Deep Breath; Preservation: Dream Flight; Augmentation: Breath of Eons family |

This is the audited candidate scope, not all racial/item/portal/flight actions, incidental movement in every damage skill, passive speed or teammate movement effects. Unknown replacements introduced by future versions do not inherit old timing rules automatically.

## Skills, mechanisms and implementation

Implemented means a real API path exists: ordinary native cooldown duration, or current actual charges plus native next-recovery duration. Secret multicount visibility uses individually reviewed native classification, whose actual C++ duration selection still needs client acceptance. Unknown/restricted/mismatched cases degrade explicitly.

In the table, **API fixture passed** refers to repository offline fixtures; **safe rejection passed** refers to rejection fixtures. Every delivered package's extracted test report remains the exact result record. **Pending combat** is not a live-client pass.

| Class | Family / actual IDs | Mechanism, implementation and limits | Offline evidence | Client acceptance |
| --- | --- | --- | --- | --- |
| Warrior | Charge 100; Heroic Leap 6544; Intervene 3411 | Charge path implemented; ordinary/category intervals audited separately. API determines extra charges/recovery changes. | API fixture passed | Pending combat |
| Warrior | Shield Charge 385952 | Ordinary cooldown when actually learned in Protection; range, target or rage never imply depletion. | API fixture passed | Pending combat |
| Paladin | Divine Steed 190784 | Charge path; racial mount appearances are not extra skills. | API fixture passed | Pending combat |
| Hunter | Disengage 781; Harpoon 190925 | Charge paths; Harpoon candidate only in Survival. | API fixture passed | Pending combat |
| Hunter | Aspect of the Cheetah 186257 | Ordinary cooldown. | API fixture passed | Pending combat |
| Rogue | Sprint 2983 | Ordinary cooldown. | API fixture passed | Pending combat |
| Rogue | Shadowstep 36554; Grappling Hook 195457 | Charge paths; **Unsupported with learned Death's Arrival 454433**, whose temporary free reuse is excluded. Shadowstep's base category maximum is 0; learning/talents determine actual capacity, never a hardcoded maximum. | API fixture passed | Pending combat |
| Priest | Angelic Feather 121536 | Charge depletion monitors whether another feather can be placed, not existing ground feathers/player speed. | API fixture passed | Pending combat |
| Death Knight | Death's Advance 48265 / Death Charge 444347 | One effective replacement per family; charge path. | API fixture passed | Pending combat |
| Death Knight | Wraith Walk 212552 | Ordinary cooldown; channeling/silence/control are not extra depletion conditions. | API fixture passed | Pending combat |
| Shaman | Spirit Walk 58875; Gust of Wind 192063; Wind Rush Totem 192077; Feral Lunge 196884 | Separate ordinary cooldowns; first two filtered by learned talents; Feral Lunge Enhancement-only. Wind Rush tracks placement cooldown, not whether the player is inside its speed area. | API fixture passed | Pending combat |
| Mage | Blink 1953 / Shimmer 212653 | Retain separately implemented, user-tested detection, combat visibility and next-charge timing. | Regression fixture passed | Historical user-confirmed; alpha.11 package regression was pending |
| Mage | Alter Time 342245 / return 342247 | **Unsupported:** return may remain available while initial cast cools down; initial cooldown is not return depletion. | Safe rejection passed | Excluded; no required user test |
| Mage | Reflection 389713 | **Unsupported:** conditional return window after Blink/Shimmer; no verified native next-return timing. No fixed-window simulation. | Safe rejection passed | Excluded; no required user test |
| Warlock | Demonic Circle: Teleport 48020 | Teleport's own cooldown, not placement 48018. Missing circle/excessive range does not imply depletion. | API fixture passed | Pending combat |
| Monk | Roll 109132 / Chi Torpedo 115008 | One effective replacement, charge path; short intervals audited independently. | API fixture passed | Pending combat |
| Monk | Transcendence: Transfer 119996 | Swap cooldown, not spirit placement 101643. Missing spirit/wrong range is not depletion. Linked Spirits 434774 changes placement only; 119996 still uses its native API. Candidate 1294390 is absent from this build's SpellName/Spell/cooldown/category tables and was not mapped. | API fixture passed | Pending combat |
| Monk | Tiger's Lust 116841 | Ordinary cooldown when learned in any spec; cast availability, not speed-buff duration. | API fixture passed | Pending combat |
| Monk | Flying Serpent Kick 101545 / landing 115057 | Initial ordinary cooldown implemented; **landing re-press Unsupported** because landing time is not next-takeoff recovery. | API fixture passed | Pending combat for ordinary path |
| Druid | Dash 1850 / Tiger Dash 252216 | Replacement family, ordinary cooldown. | API fixture passed | Pending combat |
| Druid | Wild Charge 102401 / Bear 16979 / Cat 49376 / Moonkin 102383 / Travel 102417 / Aquatic 102416 | One form family; native override selects the shared ordinary timer. Aquatic is swimming speed, not an invented leap/charge. | API fixture passed | Pending combat |
| Druid | Stampeding Roar 106898 / Bear 77761 / Cat 77764 | One form family, ordinary cooldown, no duplicates. | API fixture passed | Pending combat |
| Demon Hunter | Starter Fel Rush 344865 / Havoc 195072 / Vengeance Infernal Strike 189110 / Devourer Shift 1234796 | One spec replacement family; instantiate only current-spec candidate. Four intervals audited separately; no universal two-charge assumption. | API fixture passed | Pending combat |
| Demon Hunter | Vengeful Retreat 344866 / 198793 | Starter/current native replacement family; separate ordinary/charge handling, no duplicate monitoring. | API fixture passed | Pending combat |
| Demon Hunter | Felblade 232893; Voidblade 1245412 | Havoc/Vengeance Felblade ordinary cooldown; Devourer Voidblade charges; candidates only in their specs. | API fixture passed | Pending combat |
| Demon Hunter | The Hunt 370965 (Havoc) / 1246167 (Devourer); Metamorphosis 191427 (Havoc) | Ordinary cooldowns for an actual charge/leap. Other specs do not inherit Havoc's transformation movement mechanism. | API fixture passed | Pending combat |
| Demon Hunter | Fel Rush return 427785 | **Unsupported:** return-button interval is not the next normal Fel Rush recharge. | Safe rejection passed | Excluded; no required user test |
| Evoker | Hover 358267 | Movement charge path. Hover's moving-cast buff is excluded; Free move is a separate Time Spiral receiving Aura. | API fixture passed | Pending combat |
| Evoker | Deep Breath 357210 / steerable 433874 / native override 1236943; Breath of Eons 403631 / steerable 442204 | Family selected by spec/actual override, using charge or ordinary cooldown as appropriate. **Entire flight family Unsupported with learned Strafing Run 1266151**; excluded free recast retains rejection. 1236943 cooldown/movement is audited and activates only as an actual base-skill override; unknown replacements remain diagnostic. | API fixture passed | Pending combat |
| Evoker | Verdant Embrace 360995 | Charges. DB2 RecoveryTime=0, CategoryRecoveryTime=500; SimC effective ordinary cooldown=500. Runtime GetSpellBaseCooldown must match audited metadata or secret path degrades; mismatches are not forced through. | API fixture passed | Pending combat |
| Evoker | Rescue 370665; Dream Flight 359816 | Ordinary cooldown; Dream Flight Preservation-only. Missing target is not depletion. | API fixture passed | Pending combat |
| Evoker | Recall 371838 | Included in the relevant family only when the native base actually overrides to Recall; learning Recall alone does not identify its source. Flight-family return is **Unsupported**, not a next-flight timer. | Safe rejection passed | Excluded; no required user test |

## Exclusions and retained safeguards

- Alter Time/Reflection, Fel Rush return, Flying Serpent Kick landing, Recall, Death's Arrival, Strafing Run, Demonic Gateway, other free recasts and passive/form speed are excluded. Existing rejection protects ordinary monitoring; it is neither a future blocker nor a fake usable Preview.
- Time Spiral is the sole confirmed Free move addition; it does not expand other free-recast mechanisms.
- Unknown overrides, secret learning/override state, missing native timing and failed secret-multicharge metadata guards remain Unknown/Restricted/Unsupported, never guessed Ready/Depleted or sample digits.

## Native paths and invariants

Timing and visibility use separate objects. Charge digits bind the **already-running next recharge**, never restart at final use. Native alpha controls visibility only. Hide while at least one use remains and on first recovery, without waiting for full refill. Ordinary cooldown excludes GCD. Secret classification output flows only to permitted display APIs.

Each new charge rule has independent ordinary/GCD/category evidence and runtime public-base metadata validation. Thresholds do not generate time. GCD/target/range/resources/control and IsSpellUsable=false do not imply depletion. The 23 new native rules are in the API audit and `chargeVisibility`; offline classification does not prove per-skill C++ behavior in-client.

Configuration stays class-owned; changing Mage specs does not create another Mobility profile. Candidate definitions are not SavedVariables. Parallel skills share class style, with separate active bindings and no whole-class-library scan. Closing Options/Preview retains live monitoring. See loading audit for actual code/config boundaries.

## Optional ordinary-Mobility client regression

1. Record full build/class/spec/talents and active skills. Live continues through login, Options open/close and Preview start/stop.
2. Ordinary cooldown: cast→real countdown→hidden. GCD alone, invalid target/range or insufficient resources does not falsely show.
3. Charges: use actual client maximum; hide while one remains, show at zero, hide on first recovery. Spaced uses retain the existing recharge.
4. Test combat entry/exit/reentry, real reset/extra charges/reduction/haste changes and secret data, not only readable values. Native tracking does not imply Lua knows final visibility.
5. Change talent replacements/spec/form: active IDs update, old output disappears, bindings do not duplicate, saved scope survives return.
6. Mage Proc/Free move acceptance is separate. Excluded special mechanisms require no additional implementation or user acceptance.
