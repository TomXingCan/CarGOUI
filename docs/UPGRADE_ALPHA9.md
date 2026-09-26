# Alpha.9 upgrade, interaction and acceptance

This release retains schema 5, class-scoped Mobility settings, class/spec Proc
styles, independent Proc coordinates, and the user-confirmed Blink/Shimmer live
path. No live Proc or additional class skill database is added.

## Two-directory installation

Exit WoW before updating. Replace the CarGOUI program directory with the new one,
and install CarGOUI_Data beside it under `_retail_/Interface/AddOns/`. If upgrading
from alpha.8, remove the obsolete **AddOns/CarGOUI_Mage program directory**. Do not
remove or reset anything under WTF. The new ZIP contains only CarGOUI and
CarGOUI_Data as its top-level addon folders. The addon does not perform filesystem
deletion and declares no new SavedVariables store.

The old Mage module was code, not a save directory. Its legacy bridge is isolated
if a leftover copy is loaded: it cannot write active core adapter methods or
register a second live monitor. Diagnostics distinguish the new Data package from
an old loaded-but-quarantined Mage module. Removing the obsolete program folder
also avoids leaving redundant code resident. Do not mistake quarantine for code
unloading or a promise that native texture caches are immediately discarded.

The repository stores Data under `Modules/CarGOUI_Data/`; the packaging script
maps it to the sibling installed addon. Data's class subdirectories share its TOC
loading boundary; see [LOAD_BOUNDARIES.md](LOAD_BOUNDARIES.md) for the explicit
file/static-data/configuration/active-runtime tradeoff.

## Background drag implementation

One `BeginOptionsDrag` / `SaveOptionsPosition` path handles Header, panel/body,
sidebar/border blank space, category-page blank space, and scroll content blank
space. Drag handlers are attached to the existing non-interactive Frames. There
is no transparent overlay over the controls and no recursive per-frame hit-test
scan. Static FontStrings/Textures do not capture the mouse; native child controls
keep their own click, text, slider and scrollbar behavior.

RegisterForDrag accepts only LeftButton. OnDragStart starts moving the parent
Options frame; OnDragStop or left OnMouseUp saves its center-based UI coordinates.
OnHide also ends movement, covering Esc, Close, toggling `/cui`, hidden child
surfaces and the diagnostic dialog. Header and other surfaces use the same path,
screen clamp and saved position. Reminder frames remain noninteractive.

The relevant native methods (`RegisterForDrag`, `StartMoving`,
`StopMovingOrSizing`, `SetClampedToScreen`) are declared by the pinned Retail
12.1.0 build 69933
[SimpleFrame API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua).
This is a source-level contract check, not a run of that client. No protected
gameplay frame, combat action or restricted cooldown data participates in dragging.

## Required real-client acceptance — pending

1. Upgrade from alpha.8 preserving SavedVariables. Verify all class settings,
   Proc spec font choices, region XY, Options position and title animation option.
   Open `/cui` and check the new Data package is loaded and one Mage adapter active.
2. Drag from Header, Body blank space, sidebar gaps, frame border, static labels,
   Appearance scroll content whitespace and diagnostics whitespace. Release the
   mouse outside the panel; then test Esc and Close during drag. No stuck movement.
3. Exercise font/region menus, checkboxes, button clicks, sliders, scrollbar thumb
   and wheel, text editing/selection and Enter submission. They must not move the
   panel. Reopen and `/reload`; saved window placement returns. Reminder positions
   stay unchanged and reminders cannot be dragged.
4. Alliance Arcane: blue Header and visible purple Body; Horde Arcane: red Header
   and same purple Body. Switch to Fire/Frost: Body changes to flame/frost identity,
   Header stays in its faction palette. Test neutral/unknown fallback.
5. Inspect full Body/sidebar/footer and button/input contrast. Arcane rune circle,
   Fire flame/embers and Frost crystal watermark should be recognizable in the
   lower-right background, never obscure labels or controls. Check several UI
   scales and small resolutions for clipping, overflow and scroll interactions.
6. With Options closed and Preview stopped, regress Blink/Shimmer in combat:
   at least one use hides; last use shows true next recharge; first restored use
   hides. Wait between uses; ensure no countdown restart. GCD-only, reset and
   combat transitions must preserve previous behavior. Changing the theme must
   not touch native alpha or duration bindings.
7. On a safe test installation, leave alpha.8 CarGOUI_Mage installed and explicitly
   load it before/after CarGOUI_Data. Diagnostics should mark legacy loading as
   quarantined, with one active adapter and no duplicate reminder/listener/binding.
   Remove the obsolete program folder after this upgrade test; never touch WTF.
8. Repeat open/close/Preview/spec changes and capture existing Copy diagnostics
   snapshots. Loaded files and registered adapters are different from active
   catalog instances and monitors. Record actual CPU/memory by addon name, including
   Data; profiling-disabled CPU is unavailable. No forced GC or polling is used.

Offline tests validate the scripted interactions, config isolation and mocked
native-state paths against the **extracted final ZIP**. They cannot establish
real mouse hit testing, native visuals/taint, CPU/memory or texture-cache behavior.
Any development rendering used for visual inspection is a synthetic illustration,
not an in-game screenshot or acceptance result.
