# RC3: branding, launchers and collector acceptance

Baseline: RC2 `b2eeb3a4bd418c5d61f2a3b3ac71e8de9345585a`. This historical increment did not change gameplay monitoring, reminder rendering, RC2 drag functions, automatic themes or branding animation. It delivered an installation candidate, without a formal Release, tag or main merge.

## Implementation and storage

- Main and internal Data TOCs both use `IconTexture` pointing to the main addon's `Media/Branding/emblem.tga`. Only the main TOC declares `AddonCompartmentFunc`; Data has no menu entry and LibDBIcon compartment registration is not enabled.
- One LDB object named `CarGOUI`, type `launcher`, and one `LibDBIcon10_CarGOUI` button. The static tooltip contains only name, version and plain-left-click guidance. Entries query no skills, Auras, CPU or memory.
- All three entries call the existing `ToggleOptions()`. A third-party frame never becomes the Options target. Only explicit unmodified left-clicks are accepted; absent/unrecognized buttons, secret inputs and modified gestures are ignored.
- Options remains lazy. Combat uses the existing one-request queue, feedback and post-combat recheck, without automatically starting TEST or a color picker. Minimap and Options movement code/positions remain separate.
- General adds only **Show minimap icon**. `options.minimap = {hide=false, minimapPos=220}` is separate from Options XY, Mobility and Proc. Finite angles from -360 to 360 are accepted; standard dragging writes angles within 0..360. Radius, lock, collector and frame state are not exported.
- Current class excludes shell settings. All saved settings includes those two minimap fields; RC1/RC2 strings without them preserve current preferences. Existing prefix, whitelist, budgets, validation, review, confirmation and atomic commit remain.
- Import/restore/reset copies the two validated values into the original LibDBIcon-bound table and reconnects `db.options.minimap` to it. Backups are independent snapshots. No repeat registration or `LibDBIcon:Refresh`, which would replace drag scripts and anchors.
- Visibility updates only when the preference changes. Collected buttons respond to explicit display changes without being anchored back to Minimap. Angle changes require both parent and public anchor target to belong to Minimap, except a new unplaced button. This excludes MBB bar anchors even when MBB retains the parent. Manager-hidden buttons are not repeatedly shown.
- Standard library dragging installs OnUpdate only during interaction and removes it at termination. CarGOUI adds no polling. Hiding a still library-owned active drag delegates to its existing Stop handler without replacing collector handlers.

## Icon inspection

The existing 128x128, 32-bit transparent TGA is reused: alpha 0..255, nontransparent bounds `[4,4,124,124]`. No new artwork was made. Offline 16/20/32-pixel inspection found recognizable outlines, transparent edges and the central blue/gold emblem. These are not game screenshots.

LibDBIcon normally insets UV coordinates by 5%. Standard LDB `iconCoords` of `-1/18..19/18` cancel that inset to sample 0..1 and preserve all four tips. Pressed-state and full-coordinate broker rendering use the transparent outer padding. Client filtering and collectors' round/square masks still require visual checks. No library/manager icon method is replaced.

## Compatibility evidence

Pinned library sources/licenses and manager versions are in the [API review](LAUNCHER_RC3_API.md) and [bundled notices](../Libs/THIRD_PARTY_NOTICES.md). Libraries are embedded unchanged. Users install only CarGOUI and CarGOUI_Data; that does not mean the addon has no internal third-party dependencies.

| Scenario | Evidence | Client status at RC3 delivery |
| --- | --- | --- |
| No manager: standard button, LDB, TOC compartment | Actual library execution in offline registration/click/lifecycle tests; native TOC signature review | Pending user acceptance |
| HidingBar defaults | Source review: only minimap input is enabled by default, so a second LDB representation is not added | Pending user acceptance |
| HidingBar with both minimap and LDB sources enabled by the user | No universal same-name deduplication in source; two representations are possible. Exclude one source in the manager; CarGOUI does not edit its settings | Explicit limitation; no automatic-deduplication claim |
| WindTools Minimap Buttons Bar | Standard LibDBIcon name, Show/Hide takeover and drag-disable interfaces reviewed; offline collector-ownership simulation | Pending acceptance with a recorded manager version |
| MBB Reborn / original MBB | Standard button scan and Ctrl-right-click forwarding reviewed; original MBB is archived | Pending maintained-fork acceptance; no claim to fix old MBB itself |

Test managers separately. Multiple managers competing for one button are not guaranteed compatible. An already-loaded newer shared library may supersede the embedded version; record the actual combination. Without WoW, no measured CPU/memory numbers or universal compatibility claim is made.

## Installation and in-game checks

Exit WoW, replace `CarGOUI` and `CarGOUI_Data`, and keep WTF/SavedVariables. Record client build, manager versions, UI scale and minimap shape.

1. Disable collectors initially. Both AddOns rows show the emblem; login creates one minimap button and one native CarGOUI menu item. The full Options UI is not created before it is opened.
2. Left-click minimap, broker display and compartment separately. All toggle the same window; tooltip contains only name/version/instructions. Right-click and Ctrl-right-click do not open Options.
3. In combat, alternate those entries with `/cui` and `/cargoui` ten times: no settings flash, TEST or picker; one message and one pending request. After unlocking, open once. Later ordinary combat exits do not reopen. Entering combat with Options open still discards drafts while live reminders continue.
4. Disable **Show minimap icon**. Only the standard button hides; `/cui` and the compartment can reopen settings to restore it. Dragging an uncollected icon changes only its angle. Options dragging changes neither angle nor reminder positions. Check ROUND/SQUARE/common shapes and UI scales, including transparent tips.
5. Enable each collector separately. Test clicks, tooltip, hide/restore, placement, exclusion and `/reload`. Fresh HidingBar defaults show one entry; dual-source behavior follows the table. Imports of identical or changed icon preferences, restore and reset must not take back WindTools/MBB anchors or drag handlers.
6. Current-class export/import preserves current icon preferences. All-settings round trips restore visibility/angle. RC1/RC2 strings preserve them. Canceled or corrupt imports change nothing. Drag and `/reload` verify writes reach the active saved table.
7. Reopen Options, switch specs, load Data and toggle visibility repeatedly: no extra buttons, menu items, callbacks, timers or hidden permanent drag updates. Retest RC2 pickup/release and real Mobility/Proc/Free move timing, visibility, fonts and independent XY/RGB.

Final extracted-installer offline output and SHA256 accompany the ZIP. Offline simulation does not replace native visual, pointer-event, secret-data or manager acceptance. Subsequent user-reported RC3 success is recorded in [1.0.0 release notes](RELEASE_1.0.0.md), without retroactively claiming every matrix row was individually tested.
