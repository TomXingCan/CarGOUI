# RC2: Options drag start and stop lifecycle repair

Baseline: RC1 commit `9c29f62684c54adc40618f4a215bab28a9d84edc`; original installer SHA256 `88e74d54a122d703dc57d5ed5fc3048c5d7b68245612a606742675aafb6f87a1`. This historical repair candidate was **1.0.0-rc.2**. That task did not merge main, create a formal Release or upload to CurseForge.

## Handoff and verification

The user supplied `CarGOUI-RC1-Drag-Codex-Handoff.zip`, SHA256 `f923a734d6686b9cff5d536893803c5f3f8779762ff078397e0409a42fc669b7`. Its CRC passed. It contained the patch, instructions, independent regressions and an external test record. `git apply --check` passed against RC1. All 204 existing test groups were retained and the handoff's 11 drag groups were added.

The attachment's Linux/Lua 5.4 runner was neither used for our results nor shipped in the installer. Its report remains handoff evidence; our verification used the project's actual Lua 5.1 environment. The separate dragfix ZIP hash in that attachment is not the RC2 installer hash. Use the checksum beside the delivered ZIP.

## Problem and repair

The handoff describes an occasional jump at pickup followed by a long pull while holding the mouse. Following the pointer while held is normal. Neither that behavior nor ordinary screen-edge clamping proves that movement continued after release.

The original code delegated movement from several background children to the Options root without explicitly supplying the current mouse origin. It stored a `dragging` flag without source ownership, so any registered background's Hide/Stop could end the session. Its save path also called native Stop before clearing ownership and capturing the center. These are inspectable code issues.

RC2 implements:

- `StartMoving(true)` explicitly uses the current mouse origin. Pickup does not restore old coordinates, call SetPoint or change Scale.
- The initiating background owns the session. Its Stop, or hiding it or an ancestor, ends movement. An unrelated hidden page or delayed Stop from a different old source does not end a new session.
- Global left-button release/press, UI scale, display-size and leaving-world callbacks exist only during a drag. Cleanup unregisters only these callbacks, preserving other shared-manager subscribers.
- Capture the visible center and effective scales before clearing ownership and stopping native movement. Repeated termination and synchronous Stop reentry are harmless. Invalid/secret geometry is not used in arithmetic or saved; the previous window position is restored.
- Preserve the existing conversion to UIParent units. SavedVariables alone owns Options placement; native position persistence is disabled for this frame.

Only `UI/Options.lua` changed runtime behavior. Other changes were version and delivery documentation. Mobility, Free move, Proc, native timers, regional RGB/XY, import/export, themes and combat queuing were not rewritten. No all-controls capture overlay, OnUpdate, ticker, permanent mouse polling or reminder dragging was added.

## API evidence and limits

The review uses the existing pinned source commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [SimpleFrame API declarations](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua) define `StartMoving(alwaysStartFromMouse)` with a default-false boolean, StopMovingOrSizing, SetUserPlaced, SetDontSavePosition and GetEffectiveScale. Start/Stop can be protected frame methods. CarGOUI still begins movement only out of combat on its own unprotected Options root; the combat lock is unchanged.
- [Blizzard TalentSelection UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedTalentUI/Blizzard_SharedTalentSelectionTemplates.lua) registers GLOBAL_MOUSE_DOWN/UP during its show/hide lifecycle. This supports event availability; it does not prove this addon's native drag-event ordering or repair outcome.

**No real WoW client was available during development.** The explicit origin parameter addresses the reported symptom, but the native C++ pickup jump was not reproduced and was not proven eliminated. Offline center changes, Stop reentry and secret geometry are fault-injection models. They verify Lua safeguards and cleanup, not native mouse acceptance.

## Tests and packaging

The 204 RC1 groups, 11 handoff groups and four integration groups total **219 actual Lua 5.1 tests**. They cover ownership, outside release, a new press after a lost release, unrelated hiding, delayed Stop, synchronous reentry, invalid geometry, scale round trips, combat/world/display boundaries and repeated-session resource counts. Integration checks also verify shared event ownership, secret input handling, unchanged live bindings/visibility, native position-cache flags and reload placement. All four earlier static suites remain.

The delivery's `.tests.txt` and `.sha256` record exact results, Windows/Python/lupa/Lua versions, source commit and archive checksum. Repository tools run with `--addon-root` pointing at the final extracted ZIP. Only `CarGOUI` and `CarGOUI_Data` are installed; handoff runners, patches, development tests and raw reports remain outside AddOns.

## Focused in-game retest

1. Exit WoW and replace both program directories together. Keep WTF, SavedVariables and saved positions. Record build, UI scale and other window-moving addons.
2. Open `/cui`. Start dragging from different corners of the root blank area, Header, Body/sidebar and Appearance scroll-content background. Pickup must not jump; the held grab point should remain reasonable.
3. Release outside the window, then grab a different background; repeat. Movement must stop on release without requiring `/reload`.
4. During a drag, close, press Esc, switch away from the source page, enter combat, change UI scale/display dimensions or cross a world-load boundary. Reopen and drag again. No session may remain stuck. Combat auto-close alone must not request reopening.
5. Check Center window, reopen, `/reload`, buttons, sliders, numerical Enter, dropdowns and import-text selection/scrolling. Reminder coordinates, fonts, RGB and live timing remain unchanged.
6. If a jump remains, record the source background, preceding page/import/scale actions and build. A short video should distinguish pickup teleportation from the pointer's relative position changing at a clamped screen edge. Preserve SavedVariables for reproduction.

After native drag acceptance, use the [complete RC checklist](RC_ACCEPTANCE.md) to decide whether to publish. This historical task did not make that release decision for the user.
