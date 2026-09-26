# Proc timer colors

The existing Proc page edits the selected region's timer color. It does not
change the shared specialization font style, the region's position, the
Options theme, or any Mobility / Free move color.

## In game

1. Open `/cui`, then **Proc**.
2. Choose a **Proc region**. Its definition supplies the ability name and
   location, for example `Clearcasting - left region` or
   `Arcane Soul - outside right region`. The Buff does not need to be active.
3. Click the swatch beside **Timer color**. Blizzard's native picker previews
   the selected region's color immediately on existing live and Preview text.
4. Click the picker's **Okay** to save. **Cancel**, Escape, clicking outside
   the picker, switching region/specification/page, or closing Options
   discards an unconfirmed edit. Generic hiding also discards it.
5. **Use class color** removes this region's custom RGB. The timer then follows
   the current player's class color dynamically. It does not save a copy of
   today's class RGB. Opening the picker and accepting an unchanged color
   also leaves an automatic default automatic.

The picker has no opacity control. `Appearance` continues to edit one shared
font, size, outline, shadow and scale for the current class + specialization.
Each region retains its own coordinate offsets and optional RGB. In particular,
Clearcasting's left and right timers may differ, while a shared font-size
change affects both without replacing either color.

## Storage and rendering contract

An optional independent table is stored at
`classes[classToken].proc[specID].regions[stableRegionID].color = { r, g, b }`.
Valid components are finite numbers in `[0, 1]`. No alpha is accepted. Existing
style and position tables are preserved; changing an Aura mapping does not
change the stable region key. New regions have no custom color unless the user
sets one. Color tables are copied rather than shared between regions.

The same resolver supplies Preview text and the addon-owned per-region Font
objects used by native Aura slots. Their font parameters remain shared by
specialization, while their RGB is independent. Color-only updates use
`SetTextColor` on those owned style objects and existing Preview text. They do
not inspect protected Aura buttons or their FontStrings, read timer output,
restart bindings, change opacity, or rebuild the layout. Mobility and
Time Spiral's **Free move** continue to use fixed class color.

The UI and storage path are definition-driven. A future supported class adds
its stable Proc region definitions and reuses these methods; it does not need
a class-specific color page.

## Native picker API audit

Target: Retail **12.1.0.69933**. The inspected Blizzard UI source is pinned to
[`09b9db7948abc9b9648dedaab51eb0cf3ee67b31`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.lua).
The corresponding
[XML layout](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_ColorPickerFrame/Mainline/ColorPickerFrame.xml)
defines the native Footer Okay/Cancel buttons. This is a source audit, not
evidence of an in-game picker test.

`ColorPickerFrame:SetupColorPickerAndShow(info)` accepts `r`, `g`, `b`,
`hasOpacity`, `swatchFunc`, `cancelFunc`, and `extraInfo`.
`GetColorRGB()` supplies the user's ordinary picker RGB. Blizzard calls
`swatchFunc` both during color changes **and** on Okay, so that callback alone
cannot mean "save." The native Okay handler calls it and then hides the
picker. Cancel, Escape and outside clicks call `cancelFunc(previousValues)`
before hiding.

CarGOUI therefore previews only in `swatchFunc`, pins the original class,
specialization and stable region, and identifies Okay with a bounded
`Footer.OkayButton` `PreClick` hook. The native handler's following `OnHide`
commits only this explicitly accepted, still-valid session. A bounded
post-click hook clears an acceptance flag if some other handler kept the
picker open. No script replacement, timer, `OnUpdate`, or polling is used.

Ownership requires the current `extraInfo`, `swatchFunc` and `cancelFunc` all
to match this exact session. A secure post-hook on `SetupColorPickerAndShow`
detects a later owner and discards only CarGOUI's draft. Cleanup removes only
callbacks that still belong to CarGOUI; it never hides or clears a later
owner's picker. The handful of hooks are installed once and remain inert
without an owned session. The picker is capability-checked before use.

## Acceptance status

Automated tests cover independent regions, class fallback, confirmation,
cancellation, pinned context and another addon's takeover separately from
live timer behavior. Consult the delivered extracted-package test output for
the run result. **Real-client color-picker interaction and visual placement
remain pending user acceptance.** Check both Clearcasting sides, Arcane Soul
outside regions, Overpowered Missiles top, the Fire region sizes/locations,
and Frost regions; then change the shared font size and reload. Their colors
and positions should stay independent. Verify that canceling a color edit
leaves no saved change and that Mobility / Free move remain class-colored.
