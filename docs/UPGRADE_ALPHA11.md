# Alpha.11 upgrade and gameplay acceptance

Baseline: alpha.10 `ea05b31859c6816e4f106f6c4aec88486445406e`. No schema change; no SavedVariables reset. The existing Mage Blink/Shimmer classifier, all theme/pattern/branding files, reminder style scopes and persisted coordinate calculations are preserved. See [Mobility coverage](MOBILITY_COVERAGE.md) for exact implemented and restricted branches, separately from [Body themes](BODY_THEME_COVERAGE.md).

## Install

1. Exit WoW fully. Keep WTF and all SavedVariables. Optional backup of those files is for recovery, not a required reset.
2. Replace the previous `Interface/AddOns/CarGOUI` and `CarGOUI_Data` **program directories** with the two folders from this ZIP. If `CarGOUI_Mage` remains from alpha.8, remove that obsolete program directory only. Do not install it alongside the new package.
3. Confirm both TOC files sit immediately inside their addon directories, with no extra enclosing folder. Start WoW and verify alpha.11 in Options/diagnostics.
4. Existing `/cui`, `/cargoui`, whole-panel background dragging, Enter commits, immediate sliders and automatic themes are unchanged. No class/profile/module picker is needed.

## What changed

- Twelve non-Mage lazy class factories and shared cooldown/charge handling now feed a plural active-skill runtime.
- Learned/replaced spells are selected automatically; each independent skill owns a stable preset slot and native timer. The class XY translates all its slots; non-primary slots use fixed 84-UI-unit vertical spacing. Larger fonts/scales may need normal user size adjustment to keep this fixed layout readable; no layout editor is introduced.
- Current skill entries appear in the existing Test Mode menu. Fixed TEST samples are not live proof. Same skill uses the same class style in live and Preview.
- Data files still load together. Only current-class/current-spec learned entries activate; config restoration remains shared account-wide and is reported honestly.
- Diagnostics and test manifests no longer assume one skill or Mage-only data files.

## Acceptance record

No new-class real-client results were obtained by development. The user's prior successful Mage Blink/Shimmer combat tests are retained as historical evidence only. New mechanisms, altered multi-skill runtime, install regression and all resource/taint behavior below need actual-client acceptance.

For each supported skill and relevant talent/replacement, record class, spec, exact build, talents, spell ID, observed result and diagnostic status. Include low-level/unselected-spec cases where the skill is available. Test all distinct charge capacities that talents permit.

1. With at least one use available, no reminder appears. Try GCD-only, no target, out of range, insufficient resources, silence/control where practical; none alone should produce a depletion reminder.
2. Spend a first charge, wait several seconds, then the last. The displayed countdown must be the already-running next charge's remaining time, not a fresh full cooldown. Restore one and require immediate invisibility even while another charge still recovers.
3. Repeat with actual secret combat data. Enter combat while depleted, leave/re-enter while recovering, reset cooldowns and trigger available recharge modifiers. No flash-and-hide, frozen timer, stale text or false restart.
4. Deplete two or more different skills together. Restore/reset only one. The others keep their independent countdowns and stable slot positions. While a first skill recovers, use another without clearing the first.
5. Open Options, preview one item, stop it, preview all, close/press Esc. Single preview suppresses only that item. Combat stops samples; live resumes independently with fresh API objects. Turn Mobility off/on and verify event/binding cleanup and restoration.
6. Change the class Mobility font/size/scale and confirm all its reminders/Previews update without restarting any timer or overwriting alpha. Proc styles and other-class settings stay unchanged. Relog to confirm coordinates and settings persist.
7. Switch specs/talents/forms repeatedly. Replacement and base must not duplicate. Lost skills stop immediately; newly learned ones appear. Druid form variants resolve to one Wild Charge family slot. Same-class config survives; Header stays faction-based and Body changes as before.
8. For free-recast/return/placement cases, follow the explicit coverage limitations. Do not accept a cooldown-only result as proof of a valid destination or a conditional return's availability. Do not mark a Restricted/Unsupported branch as combat-supported. Time Spiral and similar external temporary free-charge effects need a dedicated test, beyond ordinary reduced cooldowns.
9. Capture the existing diagnostic snapshot at login, Options, Preview, combat, stopped Preview and after 20 spec/form cycles. Follow [loading measurements](LOAD_BOUNDARIES.md). Counts must stabilize after bounded reuse; no client CPU/memory numbers are claimed by this release's offline report.

For a failure, provide the exact build/spec/talent/spell ID, reproduction sequence and the existing public diagnostic snapshot. Never use secret-value dumps, raw native text/alpha readback, or error probes to gather restricted state.

## Offline deliverable checks

The final archive is built from committed source, SHA256 recorded, extracted to a fresh directory, then Lua 5.1 smoke and both static suites run from that extracted two-directory installation. These include old Mage secret-combat regressions, new real definition/adapter fixtures, simultaneous skills, replacement deduplication, native charge gates, configuration isolation and lifecycle bounds. Passing mocks is not real-client acceptance.
