# Mage native Proc coverage — alpha.13

**2026-09-27 user acceptance update (alpha.14 lifecycle increment):** the user
reports that current Mage Proc behavior works normally. This supersedes the
earlier general request to retest the alpha.13 Clearcasting repair, but does
not supply a build or a per-talent/per-layout scenario matrix. Mapping and
runtime code are unchanged in alpha.14; the following records retain their
original source-audit and offline-test distinctions.

Target source audit: **Retail 12.1.0 build 69933**. The user's actual client
build has not been supplied. Source verification, offline tests and a real
client combat/visual test are separate results. The user reports that
Arcane Soul and Overpowered Missiles work in their alpha.12 scenario.
That does not establish every talent, combat, refresh or layout scenario.
At the alpha.13 delivery, Clearcasting's correction was pending user retest;
the subsequent user report is recorded above.

This scope adds countdown **numbers** to an existing Blizzard graphical
activation overlay. It does not create a general buff list, a cast
recommendation, replacement graphics, spell names, icons or backgrounds.

## Primary data and reproducibility

- [Target-build SpellActivationOverlay DB2](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933), downloaded 2026-09-26; SHA256 `b123f93f96efeea03150a4b9e4c8f0761cc51f661a3494abc1c831fc3ba16bbe`.
- [Target-build ScreenLocation DB2](https://wago.tools/db2/ScreenLocation/csv?build=12.1.0.69933), downloaded 2026-09-26; SHA256 `95865ff516b2dd5ad110541e20eae2d6ed184390efbce813cd63e02105d251b9`.
- [Target-build Mage spell/effect/talent dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt). Its header identifies `12.1.0.69933`. This is extracted client spell data; the simulator's combat predictions are not used as live state.
- [Blizzard overlay layout and lifecycle](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua).

The implementation is a current-specialization factory in
`CarGOUI_Data/Classes/Mage/ProcDefinitions.lua`. A single current-spec cache
is replaced when the spec changes. Preview entries are built from these
definitions, independently of real aura state. They are not a source of
live spell IDs or durations.

## Graphical overlay inventory

`Row` is the DB2 record ID, **not** the event's `spellID`. `Overlay ID` is
the spell ID delivered for that native graphic. `Aura ID` is the explicitly
audited aura spell supplied to native filtering. Cast/driver IDs are kept
separate and are never used as a substitute timer source.

| Spec | Proc / cast or driver | Aura ID | Overlay ID / row | Native texture and regions | Mapping / implementation status | Client acceptance |
|---|---|---:|---|---|---|---|
| Arcane 62 | Clearcasting; Arcane Missiles cast 5143, passive 79684 | **263725** | **1277420 / 5010; 1277421 / 5011; 1277422 / 5012** | 1027131 / 1027132 / 1027133; left + right, scale 1 | One native aura timer per stable region; three graphical owners; source-backed association, see audit below | Alpha.12 failure reported; alpha.13 fix pending user retest |
| Arcane 62 | Arcane Soul; Memory of Al'ar 449619 | 451038 | 451038 / 4598 | 449486; outside left + outside right, scale 1 | Current Sunfury hero effect mapped | **User reports working in their alpha.12 scenario**; full matrix not claimed |
| Arcane 62 | Overpowered Missiles; talent 1244329, consumed by Arcane Missiles | 1277009 | 1277009 / 5007 | 6160020; top, scale 1 | Current Arcane talent effect mapped | **User reports working in their alpha.12 scenario**; full matrix not claimed |
| Fire 63 | Hot Streak; passive 195283, benefits Pyroblast 11366 / Flamestrike 2120 and their actual overrides | 48108 | 48108 / 117 | 449490; left + right, scale 1 | Current effect mapped | Pending |
| Fire 63 | Heating Up; preceding Hot Streak state | 48107 | 48107 / 1162 | 449490; small left + small right, scale 0.5 | Current effect mapped separately from Hot Streak | Pending |
| Fire 63 | **Pyroclasm**; current talent 269650, benefits a **non-instant** Pyroblast or Flamestrike | 269651 | 269651 / 3739 | 457658; top, scale 0.7 | Current hard-cast bonus mapped, not collapsed into Hot Streak | Pending, including partial stack consumption |
| Fire 63 | Hyperthermia; Memory of Al'ar 449619 | 383874 | 383874 / 4184 | 6160021; outside left + outside right, scale 1.5 | Current Sunfury effect mapped; the older standalone passive is not required | Pending |
| Fire 63 | Fury of the Sun King; historical driver Sun King's Blessing 383886 | 383883 | 383883 / 4555 | 457658; top, scale 0.7 | Retained client row; **native-event-only**, no sample offered as an available current talent | Pending only if the client actually emits this graphic |
| Frost 64 | Fingers of Frost; passive 112965, benefits Ice Lance 30455 | 44544 | 44544 / 119 | 449489; left, scale 1 | Main aura and left region mapped | Pending, including partial consumption |
| Frost 64 | Fingers of Frost hidden graphical companion | 126084 | 126084 / 1385 | 449489; right, scale 1 | Exact hidden aura mapped; no Lua stack inference or guessed timer alias | Pending: hidden aura exposure and right-side lifecycle |
| Frost 64 | Brain Freeze; passive 190447, benefits Flurry 44614 | 190446 | 190446 / 2990 | 450930; top, scale 1 | Current effect mapped | Pending |

All rows have an actual nonzero native texture and valid screen-location
record in the audited build. The legacy Fury of the Sun King record is not
evidence that its old talent can currently be learned. Its exact aura and
actual native graph event must both participate; it is not added to the
user's Preview menu.

### Clearcasting: timer and graphical identities are different

The principal finite aura **263725** is the only timer source. Its own
activation row 3685 has no artwork; that does **not** disqualify it from
providing time to the separate graphical Clearcasting owners. The
12.1.0.69933 overlay records **1277420/1277421/1277422**, Blizzard's published
charge-display change, their hidden/infinite dummy effects, and the current
Arcane Clearcasting implementation together support the explicit association.
The public data does not expose all server-side linkage; this is a
**source-backed association requiring user-client confirmation**.

Alpha.12 mistakenly limited the path to the separate PvP variant **276743**,
omitting the three modern owners. Alpha.13 admits their native SHOW/HIDE
events and keeps one persistent 263725 timer per existing saved region.
A HIDE for one old variant cannot close another variant that is still
shown. Hidden **277726** contains additional movement-casting effects and
is not used as an alternative timer. Neither 276743 nor 277726 enters the
timer candidate filter, even when it coexists with 263725.

See [Clearcasting correction and primary evidence](CLEARCASTING_ALPHA13.md)
for the exact records, diagnostics, bootstrap boundary and retest steps.
The implementation never uses a fixed duration or guesses stack counts.

### Fingers of Frost: independent native regions

The left graphic is keyed by 44544; the right graphic is keyed by the
hidden aura spell 126084. The client dump records both as real aura spells,
but does not establish a Lua-readable “right means stack count two”
contract. The implementation keeps their exact identities separate and
does not count Ice Lance casts, compare restricted stack counts, or copy
44544's duration to 126084 on assumption. If the target client does not
expose the hidden 126084 aura to the approved native display component,
the right timer remains a specifically identified pending/limited path.
The main 44544 timer must continue when one charge is consumed and that
aura remains active.

### Non-graphical candidates intentionally excluded

The target Mage data includes activation rows with texture zero for such
effects as normal Clearcasting 263725, Glacial Spike, Intuition, Arcane
Salvo, Comet Storm, Frostfire Empowerment, Burden of Power, Glorious
Incandescence, Freezing Rain, Reflection and Prismatic Bolt. These are not
silently turned into center timers or new brackets. Clearcasting 263725
is used only as the timer for the separately mapped modern Clearcasting
graphics described above; it does not create an extra graphic. Arcane Soul 1223522
and Hyperthermia 1242220 are separate damage-stack buffs and do not replace
the timed graphical auras 451038 and 383874. This is a native-graph scope,
not an inventory of every Mage buff.

## Geometry, saved regions and typography

The original saved IDs remain unchanged:

- `mage_arcane_clearcasting_left` / `mage_arcane_clearcasting_right`.
- `mage_fire_hot_streak_left` / `mage_fire_hot_streak_right`.
- `mage_frost_fingers_left` / `mage_frost_fingers_right`.
- `mage_frost_brain_freeze_top`.

Each added region has its own stable position ID. Heating Up's small
brackets have different centers from Hot Streak's full-sized brackets.
Outside graphics remain outside rather than being collapsed onto the
ordinary left/right coordinates. The static guide uses Blizzard's
`longSide = 256 * 0.8`, `shortSide = 128 * 0.8` geometry and the row's scale.
These values describe **layout only**, never aura duration.

Real timers follow the corresponding native layout and current client
scale, plus the saved per-region offsets. The existing user offsets are
not reset. Proc typography remains shared by class + specialization;
region positions remain independent. Alpha.13 adds optional RGB per stable
Proc region; an unset RGB dynamically uses the current player's Blizzard
class color. Each region's live and Preview displays resolve the same RGB.
Font, size, outline, shadow and scale remain shared by class + spec.
Mobility and Free move keep their fixed class color and separate
class-level configuration.

## Runtime and validation boundary

The approved route is an identity-filtered native player AuraContainer
and native duration rendering, with the actual overlay lifecycle handling
graph visibility. Aura payloads, secret durations and stack counts do not
pass through string formatting, comparisons or font-string measurement.
An empty native display is not reported as proof of “buff absent.”
Diagnostics must distinguish native tracking, missing API/layout support
and an unverified identity mapping.

The release test report records the final extracted-package results.
Required real-client checks remain: trigger, consume, partially consume,
refresh, naturally expire, simultaneously active effects; reload/spec
change; disabled native graphics; frame reuse; UI scale; and closing
Options / Test Mode while actual Proc monitoring continues. The specific
Clearcasting and hidden Fingers of Frost caveats above are not covered by
mock objects passing their tests.

### Native graphic resynchronization boundary

The audited Blizzard overlay Lua registers SHOW, HIDE and SETTINGS_LOADED.
It ignores a SHOW when `displaySpellActivationOverlays` is false. Its
settings callbacks change root opacity and the display CVar; they do not
rebuild or replay the current graphics. A SHOW received while graphics are
disabled must therefore remain suppressed after re-enabling until a new
actual SHOW establishes that region. HIDE is processed independently of
the display setting.

There is no public active-graphic replay API in that audited Lua source.
At login/reload, CarGOUI can resynchronize the exact timer aura through the native
AuraContainer and position it using the audited graphical record. Whether
the engine simultaneously recreates every corresponding stock graphic is
a client acceptance question, especially for the Clearcasting variants and
Fingers of Frost records. This bootstrap is not represented as a verified
query of native graphic visibility, and no overlay child visibility or
alpha is read back to manufacture such a query.

`Blizzard_AuraContainer.toc` declares `AllowLoad: game` without
`LoadOnDemand`; it exports its XML templates into the global environment
specifically for external consumers. It normally exists by player login.
CarGOUI checks the actual template/API availability and reports a missing
component instead of guessing an unavailable fallback or forcing a
different addon's loader.

## Confirmed Free move scope

The user confirmed **Time Spiral's one free movement use**. The cast ID is
**374968**. The effect is not Hover's movement-casting duration. Its
receiver aura is class-specific, as shown by the spell-family, effects and
tooltips in the [target Evoker spell dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt).

| Class | Receiver aura | Movement affected in the audited data |
|---|---:|---|
| Death Knight | 375226 | Death's Advance / Death Charge |
| Demon Hunter | 375229 | Fel Rush / Infernal Strike / Shift |
| Druid | 375230 | Dash / Tiger Dash |
| Evoker | 375234 | Hover / Spatial Paradox charge category |
| Hunter | 375238 | Aspect of the Cheetah |
| Mage | 375240 | Blink / Shimmer |
| Monk | 375252 | Roll / Chi Torpedo |
| Paladin | 375253 | Divine Steed |
| Priest | 375254 | Leap of Faith |
| Rogue | 375255 | Sprint |
| Shaman | 375256 | Spirit Walk / Spiritwalker's Grace / Gust of Wind |
| Warlock | 375257 | Demonic Circle: Teleport |
| Warrior | 375258 | Heroic Leap |

Only actual receiver-aura presence drives the text **Free move**. There is
no countdown. The DB2 duration is not used to start a fixed timer. The
[referenced EUI implementation](https://github.com/EllesmereGaming/EllesmereUI/blob/394319df23b67d4b09850a78a8d6a542beb80140/EllesmereUIQoL/EllesmereUIQoL_MovementAlert.lua)
was inspected to identify the feature, but its fixed ten-second timer and
cast/glow inference are not adopted. No EUI dependency or copied code is
introduced. This addition does not reopen excluded return, gateway or
other free-recast mechanisms.
