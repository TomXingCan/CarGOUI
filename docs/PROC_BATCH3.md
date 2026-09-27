# Proc batch 3: Hunter, Monk, Warrior, Demon Hunter

Target data is **Retail 12.1.0.69933**, not a mixture of expansion-era lists.
The [pinned SimulationCraft build file](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/build_info.txt)
identifies this exact live build and hotfix. All four class dumps below have the
same build header. Graphic membership, texture, location and scale come from
[SpellActivationOverlay](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933)
and [ScreenLocation](https://wago.tools/db2/ScreenLocation/csv?build=12.1.0.69933).
The admitted scope is a finite, consumable/refreshable empowerment with a native
screen graphic. It is not a general Buff list or a count of charges/stacks.

All listed implementations use the shared native helpful-player AuraContainer
with **one exact timer Aura per native slot**. Native DurationTextBinding supplies
the digits. Public SHOW/HIDE selects the native graphic regions; Lua never reads
Aura presence, application counts, remaining time, private text or visibility.
Durations below are **audit evidence only** and are absent from runtime timers.
New mappings have source/data evidence and require real-client acceptance.

## Implemented mappings

`LeftRight` means two stable configurable regions, `Left` and `Right`. Rows with
two specializations are separately scoped definitions/configuration records.
All admitted entries have `nativeEventOnly=false`: before graphic history is
known, exact native Aura matching uses the verified static layout. This is the
existing safe login/world-entry bootstrap, not a promise that a public graphic
event can be replayed. After an observed HIDE, unobserved alternative owners do
not resurrect a region. Client exposure and layout still need acceptance.

| Class / spec | Proc and learned condition | Exact timer Aura; audited lifetime | Graphic owner(s); DB2 row | Native texture / location / scale | Evidence |
|---|---|---|---|---|---|
| Hunter / Marksmanship 254 | Lock and Load; talent 194595 **or** Tactical Reload 1301406 | 194594; 15 s | 194594; 3043 | 450926 / Top / 1 | Talent 194595 describes this empowerment; 1301406 explicitly triggers 194594. Pinned Hunter implementation uses `lock_and_load_buff = find_spell(194594)`. |
| Hunter / Marksmanship 254 | Precise Shots; talent 260240 | 260242; 15 s | 270436, 270437; 3730, 3731 | 1029138, 1029139 / LeftRight / 1 | Both graphic owners explicitly reference driver 260240 in their descriptions. Driver 260240 names actual effect 260242, whose damage/cost modifiers match the current talent. Current Hunter implementation uses `precise_shots_buff = find_spell(260242)`. See split mapping below. |
| Hunter / Marksmanship 254 | Deathblow; talent 343248 **or** Dark Ranger 466932 | 378770; 12 s | 378770; 5084 | 449487 / Bottom / 1 | 343248 explicitly embeds Aura 378770 in its tooltip. Current Hunter implementation permits the Deathblow talent or Black Arrow and constructs the same Aura. |
| Hunter / Beast Mastery 253 | Deathblow; Dark Ranger Black Arrow 466930 | 378770; 12 s | 378770; 5084 | 449487 / Bottom / 1 | Pinned Hunter source limits this Black Arrow/Deathblow branch to Beast Mastery and Marksmanship; no Survival mapping is inferred. |
| Hunter / Beast Mastery 253 and Survival 255 | Howl of the Pack Leader: Wyvern; hero talent 471876 | 471878; 30 s | 471878; 4747 | 774420 / LeftRight / 1 | Exact timed Aura tooltip says the next Kill Command summons a Wyvern. Current Hunter source constructs the Wyvern ready Buff directly from 471878. |
| Hunter / Beast Mastery 253 and Survival 255 | Howl of the Pack Leader: Boar; hero talent 471876 | 472324; 30 s | 472324; 4745 | 774420 / LeftRight / 1 | Exact timed Aura tooltip says the next Kill Command summons a Boar. Current Hunter source constructs its separate Buff directly from 472324. |
| Hunter / Beast Mastery 253 and Survival 255 | Howl of the Pack Leader: Bear; hero talent 471876 | 472325; 30 s | 472325; 4746 | 774420 / LeftRight / 1 | Exact timed Aura tooltip says the next Kill Command summons a Bear. Current Hunter source constructs its separate Buff directly from 472325. |
| Monk / Windwalker 269 | Blackout Kick!; Combo Breaker 137384 **or** Echo Technique 1250042 | 116768; 15 s | 116768; 1132 | 1001511 / Right / 1 | Combo Breaker explicitly names the limited free-Blackout-Kick duration. Echo Technique explicitly triggers 116768. Not enabled for all Monk specs merely because the base kick exists. |
| Monk / Windwalker 269 and Mistweaver 270 | Strength of the Black Ox; Conduit talent 443110 | 443112; 30 s | 443112; 4561 | 623950 / Left / 1.20000004768 | Current hero talent lists these two specs and explicitly references 443112. Pinned Monk implementation constructs `strength_of_the_black_ox` from that Aura. |
| Monk / Mistweaver 270 | Zen Pulse; talent 446326 | 446334; 20 s | 446334; 4572 | 623951 / Right / 1.10000002384 | Native owner is the finite empowerment Aura, distinct from heal spell 198487 and earlier active ability 388609. Its description references the current Mistweaver talent. |
| Monk / Brewmaster 268 and Mistweaver 270 | Potential Energy; Master of Harmony Harmonic Surge 1270958 | 1270990; 30 s | 1270990; 4985 | 469752 / Top / 1 | Current talent says it grants Potential Energy for the next Tiger Palm/Vivify. The finite Aura and pinned Monk `harmonic_surge_buff = find_spell(1270990)` agree. Only remaining time is displayed, never its charge count. |
| Warrior / Protection 73 | Revenge!; learned Revenge 6572 | 5302; 6 s | 5302; 1488 | 603339 / Right / 0.85000002384 | Protection passive 5301 explicitly triggers 5302. This Aura makes the next Revenge free; current Warrior implementation constructs this exact Buff. |
| Demon Hunter / Havoc 577 | Chaos Theory; talent 389687 | 390195; 8 s | 390195; 4225 | 801267 / LeftRight / 1 | Talent and Aura identify the finite next-Chaos-Strike empowerment. Pinned DH implementation uses `chaos_theory_buff`. |
| Demon Hunter / Vengeance 581 | Untethered Rage; apex talent 1270444 | 1270476; 12 s | 1270476; 4983 | 450930 / Top / 1 | Exact Aura grants a temporary Metamorphosis use and expires. Current DH implementation uses this Buff; the 10 s duration of the resulting Metamorphosis is **not** the Proc timer. |
| Demon Hunter / Devourer 1480 | Moment of Craving; talent 1238488 or current set driver; see below | 1238495; 8 s | 1238495; 4853 | 7549806 / Top / 1 | Talent explicitly references additional fragments from 1238495; the current implementation constructs `moment_of_craving` from this Aura. Its accompanying Reap cooldown reset is not used as the countdown. |

The source files register actual Proc factories for these classes. Only the
requested spec factory runs; learned-driver conditions filter ordinary talent
entries. Hidden **timer Aura IDs are never used with IsSpellKnown**. Each region
uses `class_spec_proc_location`, independent of Aura identity, localized labels,
and list order. Typography remains shared by class/spec; RGB and XY remain per
stable region. No new rendering engine, picker, page or manual selector is added.

## Split-source and stage decisions

**Precise Shots:** the admitted timer source is 260242. Graphic owners 270436 and
270437 are presentation dummies, not alternative timer candidates. This relation
uses their explicit common driver reference, that driver's direct numeric
references to 260242, and the target-version implementation's actual Buff ID; it
is not inferred from the English name alone. The two graphical owners share the
same left/right slots and timer provider. The current real Aura has one maximum
stack in the target dump. The retained second graphical row is only an alternate
public event source, not a claim that the current talent provides two charges.
Late HIDE for one owner cannot clear another observed active owner. Their actual
SHOW behavior and AuraContainer exposure remain client checks.

**Pack Leader:** these are finite next-Kill-Command empowerments, each actually
consumed or expired, rather than a bare resource threshold or ordinary skill
ready indication. This is why they satisfy admission even though the current
implementation calls them “ready buffs.” The periodic scheduling Aura 471877 is
not displayed. Three different timer providers get distinct native slot keys;
none is retargeted to whichever beast happens to be next. Only its matching Aura
and graphic owner enable each pair. No addon tracks the beast cycle or counts
Kill Commands. Their shared native geometry is preserved rather than replaced
with invented separate screen positions.

**Potential Energy:** its charges influence the empowerment, but this feature
only displays the actual finite Aura duration. It neither counts charges nor
tries to reconstruct Harmonic Surge damage/healing. Partial versus complete
consumption is handled by native Aura presence and duration updates.

**Devourer:** target set bonus 1296616 (Demon Hunter Devourer 12.1 Class Set 4pc)
also explicitly grants Moment of Craving via Soulburst. The pinned DH source
checks that set bonus before triggering the same `moment_of_craving` Buff. A
talent-only filter would omit this legitimate source; the implementation must
retain the exact native Aura route for the current Devourer spec without treating
the set bonus or the timer Aura as an ordinary learned spell. It never infers
equipment from buff duration or private Aura state.

## Reviewed but not exposed in the product

These are exclusions or unconfirmed source relationships, not a backlog the user
is expected to complete. They receive no fake Preview or color-menu entry.

| Class / spec | Candidate | Current-build reason |
|---|---|---|
| Hunter / Survival | Grenade Juggler owner 470492, row 4708 | Owner 470492 modifies Explosive Shot/Sticky Bomb GCD. Current talent 459843 explicitly triggers different Aura 470488 for Wildfire Bomb recharge, and current Hunter source uses 470488. A same-name/shared-lifetime alias does not prove this old graphic represents that new effect. Not admitted without that relationship. |
| Hunter / Marksmanship | Lock and Load: Explosive Shot 1300701, row 5077 | Although a finite Aura and texture exist, ScreenLocationID is 0, which has no row in the target ScreenLocation table. Do not invent a center/top location or claim a verified screen graphic. |
| Monk / historical | Combo Breaker: Chi Explosion 159407, row 2676 | Historical finite graphic row remains, but no current talent/driver for Chi Explosion is established. The current WW Combo Breaker describes Blackout Kick instead. |
| Monk / Brewmaster | Light/Moderate Stagger 124275/124274, rows 2794/2795 | Ongoing stagger damage state; explicitly outside the requested Proc feature despite finite periodic records. |
| Warrior / Arms | Tactician 199854, row 3082 | Two-second dummy graphic flash accompanies an Overpower charge/reset. Talent 184783 grants a charge; there is no corresponding finite empowerment that ends when this flash expires. This is a ready/reset indication, not a two-second deadline for Overpower. |
| Warrior / Fury | No admitted graphic in this target audit | The target class-family graphic join has Revenge and Tactician, neither belongs to Fury. No placeholder timer is created, and this does not claim that future builds can never add Fury graphics. |
| Demon Hunter / Annihilator Vengeance/Devourer | Voidfall owner 1256302, row 4957 | Owner is an infinite stack/spending Aura. Building Aura 1256301 is also infinite. Finite 1256322 is the separate Final Hour aftermath, triggered as spending stacks are consumed; the pinned implementation establishes it is **not** the lifetime of the 1256302 graphic. No cross-Aura substitute or fixed timer is attached. |

## Primary source links and reproducibility

- [Hunter target spell dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/hunter.txt)
  and [target Hunter implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_hunter.cpp): talent definitions around lines 7752–7759, 7896–7916 and 7943–7946; actual Buff construction around 8157–8177 and 8358–8383.
- [Monk target spell dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/monk.txt)
  and [target Monk implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/monk/sc_monk.cpp): 443112 and 1270990 bindings around 5885, 5928, 6493–6495 and 6518–6519. Mistweaver Zen Pulse and its talent scope are taken from the extracted target data, not inferred from the damage simulator's healer coverage.
- [Warrior target spell dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/warrior.txt)
  and [target Warrior implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_warrior.cpp): Revenge Buff 5302 around 8352–8355.
- [Demon Hunter target spell dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/demonhunter.txt)
  and [target Demon Hunter implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_demon_hunter.cpp): current Buff construction 9920–9921, 10043 and 10101; Devourer set trigger 5698–5705; Voidfall/Final Hour provider distinction 11338–11340 and aftermath consumption callbacks 9376–9389.

The local audit copies have these SHA256 values:

| File | SHA256 |
|---|---|
| SpellActivationOverlay CSV | `b123f93f96efeea03150a4b9e4c8f0761cc51f661a3494abc1c831fc3ba16bbe` |
| ScreenLocation CSV | `95865ff516b2dd5ad110541e20eae2d6ed184390efbce813cd63e02105d251b9` |
| Hunter dump | `240c75f67307bb038e0e6b014116553d83ceeb8aa4658dcbf40c3130a190f1c8` |
| Monk dump | `f42aa1d3480bf50b6c93a6b488a540b8cd398561a83955a3ffa47b7bf3fa627c` |
| Warrior dump | `dabc2f407cccb2f50631a248ac522e6f3306514f0f4bfd2d3b2b59094af8679e` |
| Demon Hunter dump | `97ab5c759eb9a7f7d4c0e1e8f75ad30bb2e24fd3d3212d110b78c68c6b62f6e8` |

The release's final extracted-package tests provide implementation/lifecycle
verification separately. **No Hunter, Monk, Warrior or Demon Hunter client
combat, taint, visual or performance acceptance is claimed.**
