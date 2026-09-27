# Phase 2A combat repair — in-game acceptance

> Later user feedback confirmed alpha.6 Blink/Shimmer in tested scenarios, without a complete build/boundary matrix. This historical checklist preserves the original evidence limits; [alpha.7](ENTRY_STYLES.md) subsequently added styling/themes.

Target: `0.1.0-alpha.6`. **No real client was available in development; these are acceptance instructions, not a pass log.** API/data evidence is in [the audit](Mobility-Combat-API-Audit.md); offline output accompanies the ZIP.

## Install and record

For this historical single-folder release, exit WoW and replace the ZIP's CarGOUI under `_retail_/Interface/AddOns/`. Keep WTF/SavedVariables, positions, fonts, size and scale. `/cui → Mobility` and General reminders should be enabled. Current releases require both directories; see README.

Copy public diagnostics first: addon version, client version/build/Interface, class/spec, detected spell, Status/Path/Reason. The source target is **Retail 12.1.0 / build 69933**; record any actual build difference. Do not read restricted counts/time/alpha/FontString contents for diagnosis; visible behavior and public diagnostics suffice.

`Restricted / blocked: native charge visibility` may mean missing curve APIs/objects, missing/secret global GetSpellBaseCooldown or the public cooldown/GCD maximum for the two supported IDs differing from the audited 1500 ms bound, including a full recharge cycle returned there. Preserve the full Reason and mark the scenario blocked, not passed based on out-of-combat/single-charge success.

Close Options/TEST and compare actual recovery visually with Blizzard's action bar. Test Blink and Shimmer, actual capacities one/two and temporary three separately. Mark unavailable capacities untested; do not modify game state or simulate charges. Low-level/unspecialized characters can test learned/unlearned detection and positions.

## Function and lifecycle

| # | Action | Expected observation |
| --- | --- | --- |
| 1 | Deplete outside combat, then enter while digits run; wait for one recovery | Continuous true remaining time, no disappearance/restart/freeze/residue on entering combat |
| 2 | In combat use 2→1→0, then wait for 0→1 | Hidden at 2→1, `No Blink`/`No Shimmer` plus next recovery at 1→0, hidden after the first recovery rather than full refill |
| 3 | Keep one use, trigger another spell's GCD; test the short interval after first movement use | Neither GCD nor the 0.5-second use interval implies depletion; Shimmer's GCD independence does not excuse interval false positives |
| 4 | Wait several seconds between first and final use | Show the already-running first recovery, matching the action bar, not a fresh full cooldown |
| 5 | Trigger an available real reset, e.g. Alter Time return with learned Time Walk; leave/re-enter combat | Hide on reset, use current API time after new depletion, no stale alpha/digits |
| 6 | Start external Preview, stop/close, then deplete in combat; also stop Preview while empty | TEST ends and live continues from current state, not sample numbers |
| 7 | Observe both secret-charge and public-charge combat cases | Multicharge native path says Native tracking; no secret/taint errors; status does not mean Lua knows Ready/Depleted |
| 8 | Open/close Options and edit size/font/Scale while live; repeat transitions | Native digits continue; style/binding does not replace gate alpha with 1/0 or flash then disappear |
| 9 | Compare Mage Blizzard class color in name, digits and same-entry Preview | Same class color for all; TEST helper text may keep its helper color |
| 10 | Reload, reuse frames, reopen, edit fonts and switch Mage specs | Class color remains the same across specs, positions/size/scale persist, no account RGB inherited by a future other class |
| 11 | Inspect Options | At this historical stage no custom reminder RGB/color-mode controls; `/cui`, movement, Enter, sliders and branding remain |

Single-capacity cases also run available→empty→recovered in combat. Three-capacity cases hide for 3→2 and 2→1, show at 1→0 and hide at 0→1. This checklist tests actual Blink/Shimmer, without adding a Free Move product feature at that stage. Later Proc regional RGB is separately documented and does not change Mobility's fixed class color.

## Native visibility boundaries

A normal depletion alone does not establish the multicount secret path's semantics.

1. **Use the last charge near first recovery:** after the first use, wait until the action bar shows less than 1.5 seconds, then expend the last charge; repeat below 0.5 seconds. Show the correct brief remainder, then hide on first recovery. Record misses or delays masked by GCD/use interval.
2. **Real cooldown reduction/recovery changes:** test available Flow of Time, Improved Blink and Bronze conditions, including safely available combat changes. Digits follow engine time, not a static cycle. Mark missing talents/teammates/mechanisms untested.
3. **Reset and reuse just before recovery:** reset or recover at a small remaining value, then spend again. No old digits/alpha flashback, freezing or timer until full refill.
4. **Other unusability only:** with a charge, inspect safely available low mana, silence or control. No depletion alert. Blink removing some control does not substitute for availability detection.
5. **Combat boundaries/reload:** current state survives transitions and permitted reloads. Out-of-combat training or Preview success is not combat evidence; record actual secrecy separately from the combat flag.

If the engine chooses a short remaining interval as ordinary cooldown total instead of the real recovery period in checks 1/2, the curve may miss. A long recovery object while a charge remains may falsely show. API declarations alone do not exclude those cases. Report build, talents/capacity, steps and visible results; never bypass guards or count casts.

## Offline evidence and feedback

Run tests on the **final extracted ZIP**, recording name/path/version/results. Combat and secrecy must be independently controlled. Secret alpha may flow only into permitted native display APIs; `inCombat=true` with ordinary counts is insufficient.

Offline tests also cover class-color caching/fallback recovery/frame reuse, absent color controls at that stage and Preview retaining event subscriptions. They establish script contracts, not real object selection, secret/taint permission or visuals. Use actual delivered counts.

```text
CarGOUI version:
WoW version / build / Interface:
Spec / Blink or Shimmer / actual maximum charges:
Relevant talents / cooldown modifiers:
Public diagnostics Status / Path / Reason:
Acceptance item number:
Observed behavior and timing compared with Blizzard action bar:
Lua error text, if any:
```

Screenshots/video can clarify flicker, recovery and color. Exclude account-sensitive information. No extra addon or SavedVariables editing is required for acceptance.
