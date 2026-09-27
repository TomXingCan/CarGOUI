# alpha.15 upgrade and acceptance

Baseline: alpha.14 `bd96dbc46dd2c79f294bb35fcbce0dc8863677ab`. This historical increment delivered native Proc monitoring for the other 12 classes in three batches. Of 37 non-Mage specs reviewed, 33 have admitted entries: 63 spec-owned definitions and 81 regions. Enhancement, Destruction, Arms and Fury have no currently admitted timer and show an explicit empty state. See [PROC_COVERAGE.md](PROC_COVERAGE.md) for IDs, graphics, conditions and exclusions. This does not mean every spec has a timer.

## Installation

1. Exit WoW; back up both program directories and SavedVariables.
2. Replace AddOns/CarGOUI and AddOns/CarGOUI_Data together using the ZIP. Do not add a nesting layer.
3. Remove only an old alpha.8 AddOns/CarGOUI_Mage program directory. Keep WTF and character/account SavedVariables.
4. `/cui` should report `0.1.0-alpha.15`. `/cargoui`, Enter submission, immediate sliders and whole-window blank-area dragging remain. Audited target: Retail **12.1.0.69933 / Interface 120100**; diagnostics record the actual build for comparison.

Schema 5 remains without resets/cross-class copying. Mobility settings are class-wide; Proc fonts are class+spec; RGB/XY belong to stable region IDs. No new selector/page. Mage mappings/IDs, color confirmation/cancellation, alpha.14 combat lock, Mobility, Free move, themes and branding remain. The shared Proc engine adds capability interfaces, indexes and targeted dispatch only.

## Implementation and loading

Each new entry uses an audited finite timer Aura, passed to native AuraContainer `HELPFUL + includeSpellIDs` filtering and DurationTextBinding. Graphic and timer sources are separate. Public SHOW/HIDE gates the region; Lua does not read Auras, stacks, seconds or secret child frames. Only digits are added over native graphics.

Evidence pins the 69933 graphic table and matching SimulationCraft source/data. Three batch documents contain evidence, supplemental DB2 queries and exclusions. Source durations serve admission review, never runtime fixed timing. Out-of-scope or inadequately sourced candidates are neither menu entries nor mandatory future tasks.

The unified Data TOC still executes all class factory code, and account SavedVariables may restore other saved class records. Neither is zero-loading. Only current-spec factories/conditions execute; other classes get no instances/reminders/business listeners. Three generic learning/talent-change callbacks work independently of Mobility; an empty Proc scope starts no Proc monitoring. Stable-key slots are reused with bounded counts; old spec slots deactivate rather than claiming code/native objects fully unload. No new per-frame scan, periodic timer or forced GC.

## Offline results and evidence limits

- Retain 163 alpha.14 tests and expand to **175 Lua 5.1 tests**, plus Mobility, style/theme and Proc static suites. The final `.tests.txt` records extracted-installer execution; SHA256 accompanies the ZIP.
- The matrix covers all 63 definitions/81 regions, independently combining combat flag and data secrecy for trigger, native binding refresh, partial/full consumption, expiry, concurrency and stop Preview.
- Each region goes through actual Options dropdown, picker Okay, Preview, RGB/XY and shared-spec font controls. Check Mobility-disabled/unlearned independence, talent rediscovery, empty specs, no unverified menu candidates and bounded repeated spec changes.
- Retain Clearcasting stages, other Mage Procs, Mobility/Free move and color/window lifecycle tests. Add separate left/right Auras/owners, Precise Shots transitions and old HIDE, explicit shared-owner support/conflict rejection, no reuse across providers and zero full refresh for unrelated events.
- Source verification is separate from simulation. A nonruntime fixture records 52 graphic source keys, 51 finite Auras, versions/sources/fingerprints. Injecting an Aura in a mock is not proof of a game mapping.

**No real WoW client was available.** New-class secret Aura matching, combat safety, graphic midpoints and resource use required client acceptance. Existing user feedback on Mage, regional color and alpha.14 Options applies only to tested scenarios.

## In-game acceptance

1. Record build/class/spec/talents. Proc menu contains only coverage-table regions admitted under current conditions. Inactive effects remain configurable/previewable. The four empty specs show explanations without fake samples or active pickers. Disabling Mobility leaves Proc menu/runtime functional.
2. Close Options/TEST and trigger the Proc. Digits sit at each actual graphic's midpoint plus saved offsets. Check side/top/bottom/outside regions, graphic/UI scale and concurrency without one Proc clearing another.
3. In/out of combat, verify expiry, full/partial consumption and refresh. Remaining regions must survive partial consumption. Verify hidden right-side Auras are actually supplied by the target native filter.
4. For Precise Shots and other stages, old-stage HIDE must not clear the new stage. E-type Harsh Discipline/Celestial Might entries require actual native SHOW. Reload with an existing buff may await the next SHOW because no universal graphic replay exists; offline results do not promise history reconstruction.
5. Disable native alerts or set opacity zero, then restore. Digits respect those preferences; re-enabling does not invent historical SHOW. Record reload/spec-change initial matching against actual graphics separately.
6. Switch spec/talents, `/reload`, change characters and return. Style/RGB/XY restores within scope; old digits/TEST do not linger. Same-spec regions share typography but retain independent colors/offsets.
7. With Proc, Mobility and Time Spiral Free move active, open Options then enter combat. Options closes, live reminders continue. Repeated `/cui` and `/cargoui` produce one message/open-after-combat, without TEST/picker or later unsolicited reopening.
8. Trigger/change spec 20 times. Take on-demand diagnostics for active/allocated slots, callbacks, memory and scriptProfile-enabled CPU. `Native tracking` means requested native monitoring, not a readback of visible buff count. No guessed CPU/memory numbers before measurement.

For failures, report build/spec/talents, coverage entry/region, exact steps and error/diagnostics. Excluded special Mobility and unsourced candidates are not required acceptance tasks.
