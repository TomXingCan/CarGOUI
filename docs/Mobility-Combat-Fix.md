# CarGOUI 0.1.0-alpha.6 — combat visibility and fixed class color

> Later feedback: the user confirmed alpha.6 Blink/Shimmer worked in their tests. This historical development/acceptance record preserves its API limits. Alpha.7 added styles/themes; see [that historical increment](ENTRY_STYLES.md). No complete build/scenario matrix accompanied the feedback, so it does not prove every boundary passed.

An increment over alpha.5 `1076f4158af0663cee58bce76fec99b58a75f816`, retaining PR #1 / `feat/options-window`, without reverting alpha.4 or completed Options work.

## Changes

- `Modules/Mobility/SpellState.lua`: keep secret guards, but remove the assumption that secret charge counts always end monitoring. Public counts remain exact; publicly known single-capacity recharge uses its public state; multicount visibility uses the ordinary cooldown's native total BaseTime curve, with a separate next-charge recovery object for digits.
- `Modules/Mobility/Runtime.lua`, `UI/Display.lua`: preserve bindings across updates instead of first hiding/clearing. Native visibility output flows directly to parent SetAlpha, never read/compared. Native DurationTextBinding formats digits outside ordinary string/layout-measurement paths.
- `UI/ReminderStyle.lua`: shared noncustomizable Blizzard class color for name and digits. Cache copied RGB by player class token; use white while unavailable and recover later. Apply on initialization/world entry, font refresh and frame reuse. Do not save character RGB, mutate global colors or change parent alpha.
- `UI/Preview.lua` keeps separate state/cleanup. Review/tests confirm closing Options or Preview continues live queries. Entering combat stops samples/decorative animation only.

No color setting, persistent scan, per-frame query or third-party dependency was added. Positions, typography, scale, `/cui`, movable Options, Enter saving, live sliders and title remain. SavedVariables stayed at schema 3, with no color field or migration at this stage.

## Delivery status at the time

Code/offline regressions were delivered and rerun on the final extracted ZIP. Exact results, hashes and versions are in `CarGOUI-alpha.6-Test-Results.txt` / `CarGOUI-alpha.6-SHA256.txt`. Earlier packages/reports remain separate evidence.

Source/API audit target: **12.1.0 build 69933**. There was **no real client in development**. At initial delivery, the user had confirmed alpha.5 worked out of combat but disappeared in combat; that evidence or a mock did not prove alpha.6 combat acceptance. Later alpha.6 feedback is recorded above.

Secret multicount visibility needs public GetSpellBaseCooldown metadata within the audited ordinary-interval/GCD bound and an ordinary cooldown object that distinguishes remaining charges from depletion. Missing APIs, secret metadata or mismatched bounds report Restricted and hide. If the engine chooses a different total duration near recovery or under special reduction, misses/false positives remain possible. Normal native tracking is diagnosed as **Native tracking**, never Lua knowledge of final visibility.

See [API evidence](Mobility-Combat-API-Audit.md) and [acceptance steps](Mobility-Combat-Acceptance.md), especially combat 2→1→0→1, final use near first recovery and cooldown reset/reduction. These were existing Mobility repair checks, not an expansion into Proc, all classes or decoration.
