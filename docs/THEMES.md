# Automatic Options themes

This release resolves the player's faction, class and specialization whenever `/cui` opens Options. The Theme page reports the detected identity and palette. There is no manual theme selector, RGB editor, or Apply Theme action. Theme values are not stored in SavedVariables.

Latest user correction: **Alliance uses blue, Horde uses red**. Arcane combines that faction accent with arcane purple over a dark background. This supersedes the earlier Alliance red direction.

| Combination | Header gradient | Status |
| --- | --- | --- |
| Alliance / Arcane | Deep blue → arcane purple | User-specified direction |
| Alliance / Fire | Deep blue → muted amber | Design proposal in this release |
| Alliance / Frost | Deep blue → glacial teal | Design proposal in this release |
| Horde / Arcane | Dark red → arcane purple | User-specified direction |
| Horde / Fire | Dark ember red → burnt orange | Design proposal in this release |
| Horde / Frost | Dark red → steel cyan | Design proposal in this release |
| Mage without a known faction or covered specialization | Slate teal → blue grey; no specialization motif | Automatic Mage fallback |
| Other classes or unknown identity | Slate grey; no specialization motif | Automatic neutral fallback |

Colors and static motif definitions are centralized in `Database/Themes.lua`. The Arcane palette uses RGB `(0.08, 0.22, 0.48)` → `(0.36, 0.13, 0.58)`, blended at 45% opacity above a dark body. Selected categories use the same gradient at 38%. Other controls and input backgrounds retain their readable dark treatment.

Themes affect the header background, selected category background, thin outer border/divider and the existing brand highlight accent. The full emblem and wordmark are not tinted. Arcane, Fire and Frost have small static geometric motifs made from at most eight reused 1-pixel texture strokes at 7% opacity. No external artwork, new image files, particles or animation loops are added.

## Runtime boundaries

- `UI/Theme.lua` uses `UnitFactionGroup("player")`, the class token from `UnitClass("player")` and specialization ID from `C_SpecializationInfo.GetSpecialization` / `GetSpecializationInfo`. Existing global specialization functions are a compatibility fallback. Values are checked for secrecy before comparisons, indexing, or display.
- While Options is visible, this module subscribes through the shared event manager to `PLAYER_SPECIALIZATION_CHANGED`, `UNIT_FACTION`, `NEUTRAL_FACTION_SELECT_RESULT` and `PLAYER_ENTERING_WORLD`. Unit-bearing events ignore units other than `player`. Hiding Options unregisters only this module's callbacks. Reopening always rereads identity.
- The texture pool is created once and reused. A changed identity only reapplies the palette if the resolved theme key changed. No `OnUpdate`, ticker, spell query, cooldown state or reminder-frame transparency is involved.
- This module uses `UpdateBrandingTheme` only for the existing highlight accent. The animated-title setting and existing combat-stop behavior are unchanged.
- Reminder text stays the Blizzard player class color. Automatic themes do not touch reminder appearance settings, coordinates, native duration bindings, preview state or Mobility subscriptions.
- A secret/unavailable/unrecognized identity safely uses a declared fallback, without asking the player to make a manual selection. Known Mage spec names are displayed in English; an unmapped spec is explicitly labelled as unmapped instead of being assigned a Mage specialization theme.

## Target-client API review

Reviewed against the pinned Blizzard UI-source snapshot for **Retail 12.1.0 / build 69933**, commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [`SimpleTextureBaseAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua) declares `SetGradient(orientation, minColor, maxColor)` with `ColorMixin` colors and `SetRotation(radians, normalizedRotationPoint?)`. Only ordinary constants from the theme mapping are passed to these APIs. If native gradients are absent on an older client, the surface uses a static solid-color capability fallback.
- [`UnitDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) declares `UnitFactionGroup`, `UnitClass`, and the unit/faction/specialization events used here. Secret identity values are discarded before use.
- [`SpecializationInfoDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua) declares the current-player specialization query signatures in `C_SpecializationInfo`.
- [`SecureUIPanelTemplates.xml`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml) places `UIPanelButtonNoTooltipTemplate`'s three normal button textures in `BACKGROUND`. The category selection gradient uses `ARTWORK` sublevel -1, above that background and below the button text. The nested Appearance page keeps its owning Mobility/Proc category selected, including after a theme update.

This source review and offline tests validate the implementation contract; they do not replace actual-client visual acceptance. In-game acceptance should verify Alliance Arcane's blue-to-purple header, all six Mage combinations where characters are available, low-level/no-faction fallback, theme updates after spec changes, unchanged readable input fields, and preserved title animation settings. Existing user-confirmed Blink/Shimmer combat behavior must also be checked after the update.
