# Proc audit, batch 2: Druid, Shaman, Evoker and Rogue

Target data: **Retail 12.1.0.69933**, not an unspecified latest client. All
new entries below use the shared native AuraContainer exact helpful-aura
filter and DurationTextBinding. Addon Lua does not read aura presence, stacks,
duration or protected child state. The displayed time is never a duration
copied from these audit records.

**Status:** the four real specialization factories are implemented. An isolated
Lua 5.1 factory test passed for all 13 specifications, including empty
Enhancement, native geometry and current-scope regions. The final package's
integration-test report is separate. **Every new entry remains pending real
client combat, aura-exposure and visual acceptance.** Existing Mage user
acceptance does not apply to these classes.

## Fixed evidence and provenance

The target [SpellActivationOverlay](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933)
and [ScreenLocation](https://wago.tools/db2/ScreenLocation/csv?build=12.1.0.69933)
records provide the owner IDs, textures, scales and placements below.
ScreenLocation 3 = Left, 8 = Right (flipped), 9 = Left + Right (flipped),
4 = Top. The shared renderer uses each recorded placement rather than
applying Mage brackets to every class.

The same-build spell dumps are pinned to SimulationCraft revision
`18429d2f8fd75ebe7be92fec37394055a0254b77`; every dump header identifies
`12.1.0.69933 Live`. Local cached bytes were independently checked against
the GitHub API's blob identities for that revision:

| Dump | Verified Git blob SHA |
|---|---|
| [Druid](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/druid.txt) | `bcba1f1c96319dd5b967fde349dfad89bddeec2f` |
| [Shaman](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/shaman.txt) | `f5295bed2aaaeabc9135a6ad1792f1fb3821f0f3` |
| [Evoker](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt) | `589fcf7c313e51dcf2062b0c3284145066b9885c` |
| [Rogue](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/rogue.txt) | `38a0daf34bd0ad9988e10f0a04aee492954abdbc` |
| [All exported spells](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/allspells.txt) | `f5a0d636dd6cd063d2caccec85321a073a755fe2` |

The pinned class implementations corroborate the talent-to-aura relationships:
[Druid](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_druid.cpp),
[Shaman](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_shaman.cpp),
[Evoker](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_evoker.cpp),
[Rogue](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_rogue.cpp).
They are evidence for identities and conditions, not runtime code, simulator
timers or synthetic aura state used by CarGOUI.

## Admitted mappings

All rows below are actual runtime definitions, not placeholders. "Finite" is
verified from target spell data. Native presence governs refresh, partial
consumption, final consumption and expiry. Unless explicitly stated, native
matching may bootstrap an existing aura before a replayed graphical SHOW;
the existing runtime's public SHOW/HIDE gating and reload boundary apply.

| Class/spec | Proc and actual driver | Timer aura / overlay owner | Overlay row; texture; location; scale | Stable region suffixes | Admission evidence |
|---|---|---|---|---|---|
| Druid Balance 102 | Owlkin Frenzy; Moonkin Form **24858** | **157228 / 157228** | 3369; 463452; Top; 1 | `druid_balance_owlkin_frenzy_top` | Finite instant-Starfire aura; current class source constructs it only for Balance + Moonkin Form. |
| Druid Feral 103 | Clearcasting; Omen of Clarity **16864** | **135700 / 135700** | 1899; 510823; LeftRight; 1 | `druid_feral_clearcasting_left/right` | Driver directly triggers 135700, the finite Shred/Swipe/Brutal Slash cost-reduction aura. |
| Druid Guardian 104 | Gore; talent **210706** | **93622 / 93622** | 205; 510822; Top; 1 | `druid_guardian_gore_top` | Finite Mangle bonus aura selected by current class source. Tracks the bonus, not cooldown readiness. |
| Druid Guardian 104 | Galactic Guardian **203964**, excluding Red Moon **1252871** | **213708 / 213708** | 3193; 450914; Left; 1 | `druid_guardian_galactic_guardian_left` | Finite empowered-Moonfire aura; target source explicitly excludes the Red Moon replacement from this buff. |
| Druid Guardian 104 | Celestial Might; 12.0 four-piece effect **1264816** | **1272376 / 1272376** | 4999; 592058; Right; 1 | `druid_guardian_celestial_might_right` | Set effect directly triggers the finite next-finisher repeat aura. **Actual SHOW required**; hidden set effect is never used as a spellbook test. |
| Druid Restoration 105 | Clearcasting; Omen of Clarity **113043** | **16870 / 16870** | 148; 450929; LeftRight; 0.75 | `druid_restoration_clearcasting_left/right` | Driver directly triggers the finite free-Regrowth aura. Not the Feral aura. |
| Shaman Elemental 262 | Lava Surge passive **77756** | **77762 / 77762** | 1204; 449491; LeftRight; 1 | `shaman_elemental_lava_surge_left/right` | Target passive explicitly belongs to Elemental/Restoration; finite instant-Lava-Burst proc. |
| Shaman Restoration 264 | Lava Surge passive **77756** | **77762 / 77762** | 1204; 449491; LeftRight; 1 | `shaman_restoration_lava_surge_left/right` | Same actual aura, separate spec typography and stable regional configuration. |
| Shaman Restoration 264 | High Tide talent **157154** | **288675 / 288675** | 3881; 2851788; Top; 0.80000001192 | `shaman_restoration_high_tide_top` | Exact target DB2 finite duration, Chain Heal aura effects and Restoration trait-tree linkage; see below. |
| Evoker Devastation 1467 | Essence Burst; Azure **375721** OR Ruby **376872** | **359618 / 359618** | 4057; 4699056; Left; 1 | `evoker_devastation_essence_burst_left` | Current class source explicitly selects 359618 for Devastation; either genuine generator talent is sufficient. |
| Evoker Preservation 1468 | Essence Burst talent **369297** | **369299 / 369299** | 4110; 4699056; Left; 1 | `evoker_preservation_essence_burst_left` | Current source selects 369299; finite free-Essence-ability aura. |
| Evoker Preservation 1468 | Lifespark talent **443177** | **394552 / 394552** | 4259; 4699057; Top; 1 | `evoker_preservation_lifespark_top` | Current talent effect **1138908** directly triggers finite 394552. Alternate 443176 is not guessed as a fallback. |
| Evoker Augmentation 1473 | Essence Burst talent **396187** | **392268 / 392268** | 4243; 4699056; Left; 1 | `evoker_augmentation_essence_burst_left` | Current source selects 392268; finite free-Eruption aura. |
| Rogue Assassination 259 | Blindside talent **328085** | **121153 / 121153** | 1246; 449493; LeftRight; 1 | `rogue_assassination_blindside_left/right` | Current source chooses 121153 for the current talent. Old cast spell 111240 is not the talent or timer. |
| Rogue Outlaw 260 | Opportunity talent **279876** | **195627 / 195627** | 3071; 450926; Top; 1 | `rogue_outlaw_opportunity_top` | Driver and source identify the finite Pistol Shot bonus; partial charges are native-managed. |
| Rogue Subtlety 261 | Ancient Arts final talent **1268939** | **1269163 / 1269163** | 4974; 656728; LeftRight; 1.29999995232 | `rogue_subtlety_ancient_arts_left/right` | Source selects, triggers and consumes this finite finishing-move aura. Its timer is not a Shadow Techniques resource/stack display. |

`left/right` in this table abbreviates **two independently saved complete
region IDs**, never a single shared configuration record. All conditions are
evaluated through the common factory capability on context/talent changes.
The native aura IDs above are not passed to a spellbook-known predicate.

Celestial Might has a source-verified equipment trigger. Its native-event
gate avoids showing a speculative set-bonus timer before an actual graphic
event. An already-active bonus after reload may remain blank until SHOW;
this explicitly limited bootstrap is not described as fully synchronized.

### High Tide evidence missing from the simulator dump

Absence from an exported simulator subset was not treated as absence from
the client. Direct fixed-build DB2 retrieval established:

- [SpellMisc 288675](https://wago.tools/db2/SpellMisc/csv?build=12.1.0.69933&filter%5BSpellID%5D=288675)
  row **362564** uses DurationIndex **63**.
- [SpellDuration 63](https://wago.tools/db2/SpellDuration/csv?build=12.1.0.69933&filter%5BID%5D=63)
  is finite (**25000 ms**). This value is evidence only and is not in runtime
  timer code.
- [SpellEffect 288675](https://wago.tools/db2/SpellEffect/csv?build=12.1.0.69933&filter%5BSpellID%5D=288675)
  rows **752547/752548** apply the actual Chain Heal throughput/jump modifiers;
  this is not a purely decorative dummy.
- [TraitDefinition 157154](https://wago.tools/db2/TraitDefinition/csv?build=12.1.0.69933&filter%5BSpellID%5D=157154)
  gives **131799/132049**. Their TraitNodeEntry IDs are **126972/127228**;
  TraitNodeXTraitNodeEntry rows **124435/124691** link nodes **102860/103069**.
  Those nodes belong to trees **1033/1034**. Target
  [TraitTreeLoadout](https://wago.tools/db2/TraitTreeLoadout/csv?build=12.1.0.69933&filter%5BChrSpecializationID%5D=264)
  rows **495/498** tie both trees to Restoration **264**.
- The target Spell description for **157154** explicitly references **288675**
  as the finite empowered Chain Heal effect. Overlay **3881** uses 288675 itself.

Wago's CSV filters may match substrings; every relationship above was selected
again by **exact** SpellID / ID after downloading.

## Reviewed but not exposed as supported entries

These are audit outcomes, not a promise or mandatory backlog to implement
everything that once appeared in an old overlay table.

| Class/spec | Candidate | Outcome and exact boundary |
|---|---|---|
| Druid Balance 102 | Eclipse Visual (Solar) **93430**, Lunar **93431** | **Unconfirmed association.** Target overlays 197/198 use these graphics. SpellMisc rows 70949/70950 use DurationIndex **27**, a **3000 ms** dummy visual. Actual current Eclipse auras 48517/48518 have a different finite gameplay lifetime. No target-source proof ties a visual's observed lifecycle to the correct gameplay aura; neither visual clock is presented as Eclipse's timer, and the two IDs are not silently substituted. |
| Druid Restoration 105 | Memory of the Mother Tree **189877** | **Unconfirmed current driver.** Finite aura and old overlay 2981 exist; linked 339064 is retained legendary-era data without an established current talent condition in the inspected target implementation. No menu entry. |
| Shaman Enhancement 263 | Maelstrom / Maelstrom Weapon graphics **170585–170588**, **187890**, **467442** | **Outside scope:** stack/resource-threshold graphics, not the requested finite consumable Proc effect. A finite dummy graphic duration does not turn the threshold into a gameplay timer. Enhancement therefore has no admitted Proc in this batch and starts no empty Proc engine. |
| Evoker all three specs | Hidden right Essence Burst graphic **361519** | **Unconfirmed timer relationship.** Overlay 4066 is real and its hidden dummy aura has a finite record. Neither the same name nor identical nominal duration proves which specialization's real aura lifetime it follows, or that the hidden visual is a reliable timer provider. No right-side timer is fabricated from the left aura and no stack count is inferred. Admitted left timers remain independent and functional. |
| Evoker Preservation 1468 | Alternate Lifespark **443176** / overlay 4554 | **Unconfirmed driver/provider variant.** Current talent 443177 explicitly names 394552 as its trigger. The separate 443176 record lacks a proven target driver relation. It is not mixed into the filter or made a second overlapping Top timer. |
| Rogue Outlaw 260 | Deep Insight **340584** | **Unconfirmed current driver.** The finite graphic is retained, but its linked Guile Charm 340086 belongs to an older legendary mechanism, not a verified current Outlaw talent path. No supported Preview or color entry. |

Eclipse's exact visual records were checked with target
[SpellMisc](https://wago.tools/db2/SpellMisc/csv?build=12.1.0.69933&filter%5BSpellID%5D=93430),
[SpellEffect](https://wago.tools/db2/SpellEffect/csv?build=12.1.0.69933&filter%5BSpellID%5D=93430)
and [SpellDuration 27](https://wago.tools/db2/SpellDuration/csv?build=12.1.0.69933&filter%5BID%5D=27).
The lunar record has the same duration index and dummy effect. This records
the remaining association gap precisely; it does not claim Balance lacks
native graphics or that Eclipse can never be supported.

## User acceptance for these additions

Select the appropriate genuine talents, then configure their admitted regions
on the existing Proc page before triggering anything. Confirm real digits sit
on their own native graphic centers and use the same settings as Preview.
For each admitted family, check trigger, refresh, partial consumption where
applicable, final consumption, expiry, combat, reopening Options, specialization
switch and reload with an already-active effect. Test two distinct concurrent
effects on Guardian / Restoration Shaman / Preservation when available.

Confirm Clearcasting uses the Feral or Restoration aura for the actual
specialization; Galactic Guardian is absent with Red Moon; Devastation accepts
either Essence Burst generator talent; Lifespark uses its verified variant;
and Ancient Arts tracks its real finite proc rather than displaying a resource
threshold. The unconfirmed candidates in the preceding table are intentionally
absent from Preview/configuration. Their absence is not a request for the user
to validate speculative timers.

Body themes, header identity, current Mage mappings, Mobility and Time Spiral
Free move are untouched by these four data files. They introduce no listeners,
frames, bindings, loops over other classes, or per-frame work by themselves.
