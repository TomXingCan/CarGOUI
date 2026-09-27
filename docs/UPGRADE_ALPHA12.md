# alpha.12 installation, scope and in-game acceptance

Historical record: [alpha.13](UPGRADE_ALPHA13.md) supersedes the Clearcasting mapping and Proc color requirements. Use the newer instructions for those features.

Target: Retail 12.1.0 build 69933, Interface 120100. Built on alpha.11, this package added Mage native Proc digits and user-confirmed Time Spiral Free move, retaining ordinary Mobility and all-class Body themes. This is not a live-client pass record.

## Installation and saved data

1. Exit WoW, back up both program directories and replace them with the ZIP's `CarGOUI` and `CarGOUI_Data`. TOCs belong directly inside each folder.
2. Remove only obsolete alpha.8 `AddOns/CarGOUI_Mage`, if present. Keep WTF/CarGOUIDB. The new package omits that old folder and deletes no saved data.
3. Schema 5 remains. No reset: Mobility stays class-wide, Proc style/enabled belongs to class+spec, and region offsets stay independent. Seven original Proc IDs remain. New regions receive factory defaults; old offsets are neither recalculated nor multiplied by Scale again.
4. `/cui` opens Options. Proc controls live digits; Appearance and region-position controls retain Enter-to-save and immediate sliders. This historical version defaulted to English.
5. Enable Blizzard Spell Alert graphics with nonzero opacity. CarGOUI digits respect those preferences; ordinary buffs without native graphics are outside this module.

## Implemented paths and limitations at alpha.12

- Native AuraContainer matches `HELPFUL + includeSpellIDs`; copied native DurationTextBinding renders digits. No Lua buff scan, secret comparison, manual consumption count, fixed duration or combat-log reconstruction.
- The native container handles Aura presence/consumption/refresh. Public graphic SHOW/HIDE handles each graphic region's lifecycle. SHOW ignored while graphics are disabled is not replayed as orphan digits when preferences are re-enabled.
- Login/reload starts native matching from audited graphic-owned Auras. No public API enumerates graphic history. Initial synchronization, hidden-Aura exposure and initial graphic-event delivery require client verification. `IsSpellOverlayed` action-bar glow is not treated as central-graphic replay.
- **Historical Clearcasting: graphic 276743 matched only 276743.** Main buff 263725 and hidden 277726 were not assumed equivalent. An unmatched native duration meant no digits and a mapping blocker. This mapping was subsequently corrected in alpha.13.
- **Fingers of Frost right: graphic/hidden Aura 126084 matches only 126084.** Never infer the right side from secret 44544 stacks or duplicate its left-side Aura. If native duration is unavailable, right-side timing remains restricted rather than complete.
- Fury of the Sun King 383883 is actual-SHOW-only; current talent reachability was unproven, so no available Preview entry. Pyroclasm 269651 is the separate audited hard-cast buff.
- Time Spiral was user-confirmed. 374968 is the cast spell; native matching uses class-specific receiving Auras, such as Mage 375240. Show only `Free move`, no countdown; Hover 358267 is not this effect.
- Missing native interfaces produce precise diagnostics and disable that slot, never fabricated samples. New paths had source/API/offline evidence only: **no live combat, visual or performance pass**.

## Mage Proc in-game checks

For each step, check natural expiry, full consumption and refresh both in/out of combat. Record `/dump GetBuildInfo()` and spec/talents.

1. Trigger Arcane Clearcasting. Each side's digits belong at its graphic midpoint. If graphics exist without digits, record that separately rather than counting Preview as success. With relevant talents, check Arcane Soul outer regions and Overpowered Missiles top.
2. Trigger Heating Up small regions, then Hot Streak large regions. Positions remain separate and transitions leave no stale digits. Trigger Pyroclasm top and confirm its hard-cast Pyroblast/Flamestrike buff, not Hot Streak. Check Sunfury Hyperthermia outer regions with its talent.
3. Check one/two Fingers of Frost stacks, partial/full consumption and concurrent Brain Freeze. Left/right/top do not clear each other. Record right hidden-Aura matching independently as passed or blocked.
4. Concurrent Procs retain independent progress. Refresh one without restarting another; expiry/consumption removes digits; recycled graphics must not retain old bindings.
5. `/reload`, world entry and spec changes with an effect active test initial native synchronization. Returning restores style/offsets. No digits remain without their graphic.
6. Edit current-spec Proc font/size/outline/shadow/Scale and one region's XY. Typography is shared, offsets separate; centers follow native root/scale. At this stage digits use class color. Mobility appearance/timing remains unchanged.
7. Inspect multiple UI scales and native graphic scale/opacity. Small/large, side and top regions each need visual inspection; static geometry tests are not pixel acceptance.
8. Close Options, stop TEST and enter combat: live output continues. Preview suppresses only its tested region and does not change Aura state. Disabling Proc removes its digits while Mobility/Free move continue; re-enabling uses current state.
9. Disable native graphics, trigger during that interval, then re-enable. Previously ignored SHOW must not become orphan digits. Wait for the next actual SHOW to verify recovery; record initial/reload preference-event combinations.

## Free move in-game checks

1. Have an Evoker grant Time Spiral to a teammate with a movement ability. Show `Free move` for the receiving class, without a 10.0-style timer. Ordinary depletion reminders stay independent.
2. Consume the effect with its actual movement ability: text disappears with the buff. Without consumption, it disappears on expiry; a new grant works again. No cast-record inference.
3. Repeat in combat, during individual Free move Preview, after stopping Preview and closing Options. Disabling Mobility also disables Free move, leaving Proc unchanged.
4. Change characters: match only the new class's receiving Aura and use its style/color. At alpha.12 the default was 84 UI units above the first ordinary Mobility slot, following class XY/anchor, without an editor. **Alpha.16 later separated Free move XY; see [position isolation](POSITION_ISOLATION_XYFIX1.md).**

## Regression and resource records

- Earlier user confirmation covered Blink/Shimmer. Retest 2→1 hidden, 1→0 showing the existing next-recovery time, 0→1 hidden; Options/TEST must not interfere. Its main detection code was byte-identical to alpha.11.
- Keep parallel ordinary Mobility, class isolation, spec Proc fonts, themes, dragging and controls. Excluded returns, other free recasts and portals are not development blockers or required new acceptance; retain existing safe fallback.
- Use Mobility → Copy diagnostics / Refresh snapshot at login, Options, Preview, combat, stop and repeated three-spec changes. Record module/core events, ordinary bindings and native Aura slot allocation/requested activation.
- Requested slots are not visible buffs; copied native binding state is never read back. Deactivation unregisters UNIT_AURA and keeps a transparent shown container for one native cleanup. Cached containers retain Blizzard's static data-provider listener; do not claim every native listener is gone.
- Core account SavedVariables and the Data TOC's static files may load together, while only current class/spec monitoring runs. Unaccessed is not unloaded. After warming all three specs, repeated changes should not keep growing slot/font/binding counts.
- Measure client memory/CPU on demand. Offline object counts are not client KB/ms. No background polling or forced GC.

## Delivery verification

`tests/run_tests.py`, `check_mobility_static.py`, `check_styles_theme_static.py` and `check_proc_static.py` must all pass. Packaging from committed content produces two top-level directories, verifies TOCs/CRC/bytes/SHA256 and runs those tests against the final extracted ZIP. The external `.tests.txt` records actual results, commit/tree and archive checksum; repository-only tests are insufficient.
