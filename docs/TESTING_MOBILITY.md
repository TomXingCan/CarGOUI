# Phase 2A — in-game acceptance

> Historical alpha.5 checklist. The user reported out-of-combat success but no combat display. For alpha.6's combat/class-color repair, use [the subsequent checklist](Mobility-Combat-Acceptance.md). Hiding under Restricted is no longer an acceptance criterion for completed multicharge combat support.

Target: `0.1.0-alpha.5`. **These instructions are not live-client pass results.** Earlier user approval concerned the broad UI appearance, not live skills/combat/secret values/taint/native timers. Offline results, final extracted-package tests and SHA256 are in the delivery report.

## Preparation

1. For this historical single-folder build, exit WoW and replace `_retail_/Interface/AddOns/CarGOUI/` with the delivered CarGOUI folder, with its TOC directly inside. Preserve WTF and adjusted positions. Current installation uses two folders; see README.
2. Prefer only CarGOUI enabled initially; `/console scriptErrors 1` enables Lua error dialogs. On Mage, `/cui → Mobility → Enable Mobility` and General → Show reminders (live and test) must be on.
3. Copy diagnostics → Select all → Ctrl+C records version/build/Interface, class/spec, identified skill, state, Path and Reason. Refresh snapshot after scenario/talent changes.
4. Stop test and close Options. Live output has no TEST label; fixed `8.0` is not live success.

## Live skill matrix

Repeat in **town, training-dummy combat and at least one actual instance fight**, recording success/precise restriction. Test Blink and Shimmer, detection/saved placement across all three Mage specs, and learned/unlearned states on a low-level unspecialized character.

| Action | Expected result |
| --- | --- |
| Full available charges | No live alert; correct detection without assuming two charges |
| Spend one of at least two | Hidden while one remains, even as another recharges |
| Reach zero | Correct No Blink/No Shimmer and real remaining time, without large frame/icon/TEST guide |
| Wait between first/final spend | Show the partly completed first recharge, never restart a full period |
| Recover the first use | Hide immediately, not at full refill |
| Actual maximum one | Follow the client's one-charge state normally |
| Non-charge Blink cooldown | Show own cooldown, clear on ready; another spell's GCD does not imply depletion |
| Mana/silence/range/unusable/failed cast | No depletion while a use remains or no own cooldown exists |
| Early recovery/reset where legitimately available | Current API state immediately supersedes old time; unavailable scenario is untested, not fabricated passed |
| Learn/remove Shimmer; switch specs | Monitor only the effective skill, no duplicate Blink/Shimmer; retain saved position |
| Low-level, no spec | Learned Blink works; neither learned yields Not learned with no alert; spell data existence is not learning |
| Non-Mage at this historical stage | Unsupported, no live output or other-class scanning |

## Reload, Preview and settings

1. Reload while empty: immediately show current recovery without requiring another cast. Recheck after instance transitions, death, release and resurrection.
2. With Options/TEST closed, deplete/recover again. Opening Options must not stop synchronization.
3. Test current spell shows TEST and fixed `8.0`, suppressing overlapping true/sample digits. State changes during Preview must resynchronize current live on stop/close, not its old snapshot.
4. Previewing a Proc region does not prevent live movement in another region. Test current spec avoids overlap; stopping immediately resynchronizes.
5. Entering combat stops samples and disables/explains preview controls while real monitoring continues. Branding becomes static and resumes according to its switch after combat; skill refreshes do not restart it.
6. Enter in either Mobility XY field submits both; one invalid axis leaves both unchanged. Scale/size sliders update immediately; exact inputs use Enter. Live and TEST share font/size/outline/shadow and global/region offsets.
7. Preserve all three `mage_*_shimmer` positions, Proc positions and Options placement. Blink/Shimmer share the old spec position at this stage. New `mage_unspecialized_mobility` defaults do not overwrite selected specs.
8. Disabling Mobility during depletion immediately removes output; re-enabling reads current state. Repeat depletion/recovery and window changes 20 times without errors, stale objects or increasing callbacks/refresh work.
9. `/cui` and `/cargoui` toggle, help remains available, and zhCN remained English in this historical build. Header drag saving, Esc/Close, menus/focus retain behavior. No reminder drag or Unlock Mode.

## Interpreting restrictions

- **Restricted / blocked: charge depletion:** secret currentCharges could not legally confirm zero, so alpha.5 hid the reminder. This is an exact unsupported client/scenario branch, not Ready or combat acceptance based on Preview.
- **Tracking / native cooldown duration (ignoreGCD):** non-charge internal time can feed native binding. Actual GCD exclusion/expiry clearing still needs visual validation; this does not inherently mean out-of-combat-only.
- **Unknown:** no valid synchronized record, e.g. absent cooldown, zero-count/zero-duration mismatch or learned/override disagreement. Verify learned Shimmer resolves Blink to 212653. Persistent `Learning and Blink replacement disagree` is an unsupported state, not zero/Ready; record talents/diagnostics.
- **Unsupported:** missing APIs, unsupported class or replacement. Keep diagnostics; do not rewrite/bypass secret fields.

Record environment, skill/spec, publicly visible behavior, diagnostics and Lua errors without account details. Complete success requires **Options and TEST closed, true remaining time after depletion in actual combat, and immediate hiding after one recovery**. Any key restricted branch must retain its working scope and exact blocker.
