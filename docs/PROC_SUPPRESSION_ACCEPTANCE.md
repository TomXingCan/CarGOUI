# Custom artwork suppression: regression and client acceptance

This is a functional release blocker on [Draft PR #14](https://github.com/TomXingCan/CarGOUI/pull/14), separate from the still-open P0 memory investigation [#15](https://github.com/TomXingCan/CarGOUI/issues/15). Offline regression success does not close either acceptance gate. The diagnostics and Proc isolation subset of [#16](https://github.com/TomXingCan/CarGOUI/issues/16) remains delivered; its general reload-required framework remains unfinished.

## Report and evidence boundaries

- Reported package: `ee7b87bf73b5a16edb4b6bb873bd373013945898`.
- Client: Retail 12.1.0 / 69933, WARLOCK / 266, Demonic Core Aura 264173. One definition owns two regions, left and right.
- The author confirmed Native-only behavior. With left Custom and right Native, consuming one Proc reportedly produces a flash and a native graphic on the replaced side, resembling two layers.
- The author reports Blizzard Spell Opacity 100% and CUI Artwork Opacity 1. The selected asset, animation choices and artwork color source have not yet been provided.
- No raw diagnostics cover the original consumption-flash interval. Earlier Native snapshots are not evidence for that failure. The reported flash has not been reproduced in a Retail client by this change's authoring environment.
- A later report of selecting an Animated setting includes a new raw snapshot: Proc is quarantined after three `artwork` failures, with one owned animation group/animation. Two native slot constructions succeeded; both recorded native alpha restorations returned successfully. Both regions are Custom in this later snapshot, unlike the earlier left Custom/right Native comparison. The exact animation choice and installed package hash are not present in the snapshot; its `CarGOUI 1.0.0` heading comes from the unchanged `Core/Addon.lua` version string and cannot identify a dev installer.

## Pinned native contract

The audit uses wow-ui-source revision `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`, matching the target build:

- [SpellActivationOverlay.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua): `ShowAllOverlays` dispatches compound positions as consecutive per-side `ShowOverlay` calls. The indexed object is reused for an unchanged owner/position; its native texture is updated before the secure posthook. `ShowOverlay` stops native fade-out before showing the frame.
- [SpellActivationOverlay.xml](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.xml): the 0.2-second entrance, 0.1-second exit and pulse target the overlay **Frame**. The child texture's suppression alpha is an independent multiplier.
- [Pools.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXMLBase/Pools.lua): ordinary release resets and hides the native frame before reclaiming it. A release posthook can restore the owned texture without exposing a still-shown pooled frame.
- [SimpleRegion API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua): `SetVertexColor` affects color and alpha and accepts an optional alpha. Its omitted-alpha engine behavior is not specified here. The audit does not claim that the native three-argument RGB write necessarily resets texture alpha.

No test inserts a draw between synchronous alpha setters or the consecutive sides of one native callback. Checkpoints occur after complete callbacks and during modeled native animation progression.

## Demonstrated defects and minimal correction

### Repeated SHOW for the same public identity

Previously, every native SHOW observation restored suppression, hid the previous custom frame and discarded its record. An identical SHOW therefore restarted the custom entrance, including while the frame was already in its active phase. The baseline fixture reproduces this in both native-first and addon-event-first orders. The final native alpha is still zero in the ordinary single-owner model: this animation restart alone does not prove a visible native flash.

The corrected observation compares root, region, owner, source, texture FileDataID, location and texture object. An unchanged verified identity retains suppression and custom animation state. At the native SHOW posthook it reapplies the allowed texture alpha zero, without reading back native alpha or color. Public scale/color updates still reach the renderer. Normal rendering and preview do not repeatedly write an already-owned native texture.

A real HIDE followed by SHOW still cancels the exit and starts the required new entrance. Changed identity, native release, mode/CVar changes, disable, specialization cleanup and fault recovery retain their restoration paths. Failed restoration retains cleanup ownership.

### A retiring source exposed beside a new source

Arcane Clearcasting is a separate audited multi-owner control, not an exact reproduction of the reported single-owner Warlock:

1. Custom owns source A at texture alpha zero.
2. HIDE A begins the native 0.1-second frame fade; A remains shown and indexed.
3. SHOW B for the same region completes before A is released.
4. The old renderer restores A while taking ownership of B. If the addon event arrives first, its missing-match fail-open can also restore A before B's hook record exists.
5. At the next paint checkpoint, A's nonzero native frame fade can contribute artwork beside custom B. This exposure survives the entire callback stack.

Four baseline combinations reproduce the ownership defect: native-first/event-first and HIDE A before/after SHOW B. The corrected renderer keeps verified retiring-source suppression until that object's native release or explicit cleanup. Missing current-source evidence restores only the current source; a new unmatched native source remains untouched. Explicit mode/visibility cleanup and actual internal failures still restore the full affected region.

These defects justify the local lifecycle correction. They do not establish the exact cause of the author's WARLOCK consumption flash. A separate fixture injection that resets native texture alpha tests defensive posthook reassertion; it is explicitly not evidence that Retail performs that reset.

### Tint and animation edits during a retiring source's fade

The tint integration reproduces a second entry into that multi-owner exposure: opening the artwork picker, canceling or confirming its draft called the full appearance refresh, which restored every native object owned by the region. Changing an entrance, active or exit preset also used this path. With A halfway through its native fade and B already current, each independent operation left A's texture gate at 1 and modeled paint contribution at 0.5 after the callback, while B remained suppressed. This probe uses the same legal Arcane control and is not a Warlock stack simulation.

Pure validated tint edits now reuse the continuous presentation update already used by numeric controls. Draft and saved colors retain both current and retiring native suppression; they do not replay an unchanged entrance or recreate a preview/timer session. A strict presentation whitelist also permits existing animation choices: changed presets still restart the owned animation normally, while native ownership survives until release. Mode, asset, Reset, missing required public evidence and actual faults retain their distinct restoration or fail-open behavior. No new dirty cache, callback stream or native readback is introduced.

The same six probe operations preserve both native texture gates and retiring-source paint contribution at zero after the correction. Full regression additionally checks animated blue/green/purple, partial/full desaturation and opacity changes, picker Cancel/Okay, subsequent release and safe restoration boundaries. These are modeled public callback/paint checkpoints, not client render captures.

### Failed restoration followed by pool reuse

If cleanup and native release both fail to restore a suppressed texture, ownership correctly remains retained. Previously, a later native SHOW while Proc was disabled or quarantined returned before attempting cleanup. An unrelated owner borrowing the same pooled object could remain transparent even after the setter fault was gone. The strict fixture reproduces both inactive and quarantine cases.

The SHOW hook now permits only the restoration of existing cleanup ownership while inactive/quarantined. It cannot acquire, render or restart Proc. The same public object checks apply; failed restoration remains owned for another legitimate cleanup opportunity. Quarantine is not cleared automatically.

### Scale animation API mismatch and quarantine

The later client snapshot narrows its separate failure to the artwork boundary but intentionally does not serialize arbitrary error objects. The source audit identifies a definite API mismatch: [the pinned Scale animation API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimScaleAPIDocumentation.lua) defines `SetScaleFrom(x, y)` and `SetScaleTo(x, y)`. The renderer instead called nonexistent `SetFromScale` and `SetToScale` methods. The old offline fixture incorrectly supplied those names.

The corrected calls cover scale/pulse entrances, active pulse and scale exit. The fixture removes the false aliases and exposes Alpha, Scale, Translation and Rotation methods only for their actual animation types. Existing Alpha fade/breathe and Rotation behavior remain supported. A real exception still enters the existing failure budget; no safety check is removed and no timer binding is changed.

This mismatch can produce repeated artwork failures and quarantine when a Scale path is chosen, consistent with the new report. The snapshot alone does not identify its exact thrown call or selected animation, and this cause must not be substituted for the original consumption-flash investigation.

## Offline regression scope

`tests/proc_suppression.lua` adds strict native frame/texture separation, delayed release, pooled reuse and write/read tripwires. Coverage includes:

- Demonic Core left Custom/right Native and the reverse, plus Timer Only siblings, in both event orders and at entrance checkpoints.
- Repeated SHOW during custom entrance/active phases; no redundant entrance or animation allocation.
- HIDE(nil), repeated HIDE, SHOW during native/custom exit, stale exit completion, release, pooled SHOW and final HIDE(owner).
- Multiple owners sharing a region, old-source fade checkpoints and late release without hiding the current source.
- Pooled objects reused by unrelated owners; Custom/Timer Only/Native configuration and selected-artwork changes.
- Missing public event RGB with legal native RGB, explicit custom RGB, independent preview, CVar/disable/spec cleanup.
- Acquisition/draw/restore failures, retained cleanup ownership, Proc quarantine, stale callbacks and explicit Retry.
- Restoration after failed release and unrelated pool reuse while disabled/quarantined, without new ownership or resources.

`tests/proc_animation_contract.lua` covers the real subtype API, live and preview animation paths, lifecycle completion and reuse. The false Scale methods must fail rather than pass through a permissive mock.

The existing actual-Lua suite continues to cover timer bindings, source priority, RC2 fonts/pickers/positions, configuration scope, Mobility/Free Move, transfers and lifecycle failure budgets. The new suite is also run against the frozen baseline renderer as a negative control. No restricted native state is read to make a test pass. Offline animation checkpoints model the pinned public contract; they are not GPU captures, client timing measurements or proof of native acceptance.

## New installer and author retest

Use the new `CarGOUI-1.0.1-dev-custom-controls-R1-<commit-prefix>.zip` and its manifest. Only the two staging TOCs use `1.0.1-dev.custom-controls.r1`; the repository's production version is unchanged. This candidate also contains the shared numeric controls and localized artwork tint controls described in [NUMERIC_CONTROLS.md](NUMERIC_CONTROLS.md). The frozen diagnostic baseline and `ee7b87b` candidate ZIPs retain their original names and hashes. This is a functional regression candidate, not a third memory-performance comparison.

1. Record package/commit, build, character/spec, addon set, settings scope, selected artwork/animation/color source and both opacity values. Install the matching two addon directories and start a fresh session. Keep Mobility and Free Move configuration fixed.
2. Confirm Native/Native acquisition, single-charge consumption and final expiration. Then test left Custom/right Native at the reported 100% / 1 opacity, followed by left Native/right Custom. Repeat actual acquisition and consumption; do not substitute TEST for live gameplay.
3. Record video spanning acquisition, partial consumption, rapid reacquisition during fade and final expiration. Note which side flashes and whether the visible shape is the native or selected custom asset. Use unchanged settings for the first run, then a separate no-animation control if needed; label both. Separately repeat the Animated setting that caused quarantine, record its exact entrance/active/exit choices, and exercise scale/pulse entrance, active pulse and scale exit through real live SHOW/HIDE plus preview. Confirm Timer and Custom remain available and failures/quarantine do not increase.
4. Switch Custom, Timer Only and Native while the Proc is shown and while hidden. Confirm only the selected region changes, native artwork returns on Native/disable, and Timer appearance/position remains independent.
5. With Custom and this Proc's original artwork, try blue/green/purple, 0/50/100% desaturation and lower opacity, including active animations. Cancel and commit separate color sessions; Timer RGB and artwork RGB must remain independent. Drag numeric controls, enter an exact decimal/negative offset, cancel with Escape and use Reset. Switch region/page, release the mouse outside the slider, and close Options during interaction. Test preview then close, repeated enable/disable and specialization changes. Check that no native artwork appears through the replacement, no stale edit/preview reappears, and normal font, Mobility/Free Move and gameplay behavior is retained.
6. Capture fresh raw `/cui diagnostics copy` output before the sequence, as soon as practical after a flash, and after cleanup. Label the actual failing interval and configuration; keep prior Native-only snapshots separate. Include errors/partial/quarantine, suppression request/completion/failure counts and retained ownership. These are public operations/bookkeeping, not native alpha readback or a census of private native activity.
7. If Proc quarantines, capture diagnostics before an explicit `/cui proc retry`; record restoration and Retry success/failure. Do not inject production faults or repeatedly retry an unknown failure. Offline failure tests do not replace this real outcome.

| Package / session | Side modes and artwork settings | Action / observed interval | Native exposure / custom animation | Diagnostics file | Restoration / errors / quarantine |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

Acceptance requires the same reported consumption/reacquisition scenario to pass in the client, safe native restoration at all boundaries, and no gameplay regression. If the flash remains, retain its video and contemporaneous raw snapshots before proposing another change. A passing offline suite or a reduced suppression count cannot close this functional blocker.

The prior HIDE audit, hidden-record reuse proposal, memory comparisons and raw evidence remain unchanged. No automatic GC, global GC setting, polling, root hiding, global overlay CVar mutation, masking layer, trigger/Timer change or new UI framework is introduced.
