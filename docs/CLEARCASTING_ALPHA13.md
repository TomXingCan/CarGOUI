# Clearcasting correction — alpha.13

## Finding and implemented correction

The user reports that **Arcane Soul and Overpowered Missiles timers work in
their tested scenario**, while Clearcasting is blank in alpha.12. This is
evidence for those two paths, not acceptance of every Mage Proc. The user's
actual build and graphical-event arguments have not yet been captured.

Alpha.12 admitted only overlay **276743** and filtered the same aura ID.
The audited **12.1.0.69933** client data also contains three newer
Clearcasting graphical owners, **1277420, 1277421 and 1277422**. Alpha.12
omitted all three, so their SHOW events could never reopen its Clearcasting
gate. In addition, 276743 is the separate PvP variant, not the normal
Clearcasting timer used by the current Arcane implementation.

Alpha.13 makes these responsibilities explicit:

| Responsibility | Implemented identity | Evidence |
|---|---|---|
| Real finite timer | **263725**, one exact native `HELPFUL` filter | Target Mage aura effects and current Arcane Clearcasting buff construction/consumption |
| Native graphic variant | **1277420**, texture **1027131** | SpellActivationOverlay row **5010** |
| Native graphic variant | **1277421**, texture **1027132** | SpellActivationOverlay row **5011** |
| Native graphic variant | **1277422**, texture **1027133** | SpellActivationOverlay row **5012** |
| Native geometry | Each variant uses ScreenLocation **9**, Left + Right, scale **1** | Target overlay and ScreenLocation records |
| Saved configuration | `mage_arcane_clearcasting_left` and `mage_arcane_clearcasting_right` | Unchanged alpha.12 stable region IDs |

All three graphic owners share **one persistent native timer per saved
region**, not three copies of a timer. There is no Lua charge/stack count.
SHOW/HIDE events only control their own public graphical owner. If a new
owner appears before the previous owner's HIDE arrives, that late HIDE
does not hide the new owner's timer. Once all observed owners are hidden,
the public gate is closed. An unseen sibling cannot reopen it.

The timer filter contains **only 263725**. If 276743 and/or hidden 277726
coexist, they cannot win native candidate selection or replace its clock.
Neither is a fallback. The original 276743 graph is retained in the audit
as a separate PvP record; it is not silently aliased to 263725. An observed
unmapped owner is recorded for diagnosis rather than guessed at runtime.

## Why this association is more than matching spell names

1. Blizzard's [Midnight pre-expansion notes](https://worldofwarcraft.blizzard.com/en-us/news/24244455/midnight-pre-expansion-content-update-notes)
   explicitly describe Clearcasting's changed overlay as communicating
   its available charges.
2. The target-build [SpellActivationOverlay DB2](https://wago.tools/db2/SpellActivationOverlay/csv?build=12.1.0.69933)
   contains the three different textures/owners above, alongside the old
   276743 record. The [SpellName DB2](https://wago.tools/db2/SpellName/csv?build=12.1.0.69933)
   identifies the three new records as Clearcasting.
3. Target [SpellEffect](https://wago.tools/db2/SpellEffect/csv?build=12.1.0.69933&filter%5BSpellID%5D=1277420)
   rows **1289782/1289783/1289784**, for 1277420/1/2 respectively, are
   `Apply Aura / Dummy`. Their [SpellMisc](https://wago.tools/db2/SpellMisc/csv?build=12.1.0.69933&filter%5BSpellID%5D=1277420)
   rows **826211/826212/826213** use DurationIndex **21**, whose
   [SpellDuration](https://wago.tools/db2/SpellDuration/csv?build=12.1.0.69933&filter%5BID%5D=21)
   value is **-1**, infinite. They cannot provide Clearcasting's finite
   remaining-time clock. The SpellClassOptions record identifies Mage
   family **3**.
4. The [pinned target Mage dump](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt)
   identifies **263725** as the Arcane Missiles-enabling finite aura, with
   the Improved Clearcasting and Captured Thoughts labels. The same
   revision's [Mage implementation](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/class_modules/sc_mage.cpp)
   constructs `buffs.clearcasting` from **263725** and consumes that buff
   for Arcane Missiles. This corroborates the real timer identity; no
   simulator timing or simulated state is used by the addon.

The selected timer/graphic association is a **source-backed inference**, not
a direct observation of the user's events. The public
DB2 records do **not** contain the full server-side relationship logic,
and this investigation did not observe the user's client. Accordingly,
the correction is **implemented and offline tested; user-client mapping,
native aura exposure, combat behavior and visual placement require
retesting**. It is not represented as an already observed live fix.

No fixed duration from the dump is used. Captured Thoughts or a real aura
refresh can change the native duration; the native AuraContainer's copied
binding follows the real 263725 aura. The infinite graphical auras are
never timer candidates.

## Public gates, reload and diagnostics

The existing native AuraContainer handles aura presence, refresh,
consumption and expiry without returning those values to addon Lua.
Regular audited graphics bootstrap native aura matching after login,
reload or a world transition. This can show an already-active timer without
waiting for a missing replayed SHOW; it is **not proof that the engine has
replayed the matching stock artwork**. An explicit observed HIDE remains
authoritative until a valid SHOW or world/context resynchronization.

An old 276743 HIDE no longer locks out the new Clearcasting graphic owners.
A SHOW with a mismatched texture, unknown location, invalid/non-public
argument or unrelated owner cannot open their gate. Settings, Options,
Preview and colors do not manufacture SHOW events. Refreshing a color does
not run these gates or recreate a native binding.

Use the existing **Diagnostics / Copy diagnostics** entry after triggering
and consuming Clearcasting. It now includes:

- Actual `GetBuildInfo()` version, build, interface and build date.
- Configured timer aura, graphical owners and textures for the current spec.
- Each stable region's public gate, layout/API failure reason, requested
  native-slot activation and Preview suppression.
- The most recent **16** native graphic events, with public owner, texture,
  location and scale plus acceptance/rejection reason. Restricted arguments
  are replaced with the literal word `restricted` before formatting.

The bounded trace runs only on existing Proc events, in memory, without
polling or persistent logs. It never reads a restricted child, Aura ID,
stack, timer, alpha, native slot assignment or rendered text. A requested
enabled slot is **not** a report that the buff exists. Missing template/API
support is reported explicitly; native interface errors are not used to
probe for secrets.

## Client retest

1. Install alpha.13 without deleting SavedVariables. Disable Test Mode.
   Confirm the two Clearcasting offsets and chosen colors were retained.
2. Trigger Clearcasting normally. Check both numbers are at the visual
   midpoints of the native left/right graphic, not the screen center.
3. Gain further charges and consume only part of them. Graphical variants
   may change; the remaining timer must not be replaced by a fresh fixed
   duration or be cleared solely by the old graphic's HIDE.
4. Refresh its duration; fully consume it; separately allow it to expire.
   Check real refresh and disappearance in and out of combat.
5. Test simultaneous Arcane Soul / Overpowered Missiles, then close Options
   and stop Preview. Their independent native timers must keep working.
6. Reload with the aura already active, then switch spec away and back.
   Confirm the live graphic/timer synchronization and retained region data.
7. If still blank, copy Diagnostics immediately after trigger and after
   consumption. The build and public owner/texture/gate distinguish an
   event mismatch from missing layout or native API support. No restricted
   aura payload or screen-reading workaround is requested.
