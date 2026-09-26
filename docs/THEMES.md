# Automatic Header and Body themes

Alpha.10 extends the user-confirmed alpha.9 separation to every target-client playable class/spec. The **Header follows faction only**; the **Body follows class/specialization only**. `/cui` resolves both identities each time Options opens. The Theme page displays both detected palettes without selectors, an Apply action, or saved theme settings. The three Mage specialization palettes, watermark geometry, Header palettes and branding remain unchanged.

| Surface | Identity | Direction |
| --- | --- | --- |
| Header and existing brand highlight | Alliance | Deep blue → brighter blue |
| Header and existing brand highlight | Horde | Dark red → ember red |
| Header | Neutral, missing or secret faction | Slate-grey fallback |
| Body, sidebar, footer, selections and controls | Mage / Arcane | Deep violet → arcane purple |
| Body, sidebar, footer, selections and controls | Mage / Fire | Dark red-brown → muted amber |
| Body, sidebar, footer, selections and controls | Mage / Frost | Deep blue → glacial cyan |
| Body | Every other supported class/spec | Explicit specialization palette and original static motif; see the coverage table |
| Body | Known class with no specialization | That class's base palette and motif; no specialization is presumed |
| Body | Unknown/unavailable class | Neutral fallback, no previous class motif |

The user has confirmed the Mage Header/Body effects in alpha.9. Other class/spec palettes and original geometric drawings are this release's design proposals, awaiting in-game visual acceptance. The earlier combined faction-to-specialization Header gradient is superseded: changing Arcane to Fire does not recolor the Alliance Header; changing Alliance to Horde does not recolor an Arcane Body. An unknown faction does not erase a confirmed specialization's Body theme.

The pinned target source supports **13 playable classes and 40 specializations**, including Demon Hunter Devourer (1480). `optionThemeClasses[classToken].specs[specID]` is an explicit pair mapping; mismatched class/spec IDs cannot accidentally select another class's theme. See [BODY_THEME_COVERAGE.md](BODY_THEME_COVERAGE.md) for the complete independent Body-theme coverage and real-client acceptance table. Theme coverage is separate from live Mobility adapter support. All lightweight theme definitions live in the core; opening a theme does not request CarGOUI_Data or an adapter.

`Database/Themes.lua` centralizes both palette tables, ordinary control backgrounds, opacity constants, class/spec labels and geometry. Header examples use `(0.025, 0.075, 0.18)` → `(0.06, 0.28, 0.52)` for Alliance and `(0.16, 0.025, 0.035)` → `(0.43, 0.07, 0.085)` for Horde. Arcane Body uses `(0.064, 0.031, 0.11)` → `(0.17, 0.078, 0.245)`. These are static native gradients, not time-varying color effects.

## Coverage and layering

The gradient covers the complete area beneath the Header. Dark translucent sidebar and footer surfaces organize the existing layout without adding pages. Registered buttons, inputs, dropdown menus, checkboxes, sliders and the diagnostics dialog reuse the Body accent. Input fills stay near-black and input text stays light. Ordinary labels, error messages and feedback keep their established readable styling.

`RegisterOptionsThemeControl(panel, control, kind)` adds a reusable skin record when an existing control is constructed; it does not add a clickable overlay or replace handlers. Supported kinds are `button`, `input`, `dropdown`, `menu`, `check`, `slider`, `dialog`, and `content`. Transparent content pages receive only a fine separator, so they do not conceal the Body gradient or watermark. Menus/dialogs reuse their existing backdrops. Other controls use bounded local flat fills/borders plus their existing highlight/thumb/checked textures.

The full-color emblem and wordmark remain unchanged. Only the pre-existing masked brand highlight and Header accent line use the faction accent. Title animation settings, combat-stop behavior, positions and glyph proportions are unchanged.

The Body watermark occupies a **200 × 200 design area in its lower-right corner**, above the footer and behind page controls/text. It is a recognizable but restrained outline at 16% opacity:

- Arcane: concentric segmented rings, a central sigil and four small rune marks (60 strokes).
- Fire: a rising flame silhouette and inner flame (27 strokes).
- Frost: a central crystal and six branched ice rays (36 strokes).

The other class/spec motifs use the same bounded original line vocabulary with distinct silhouettes and palette pairs. Same-class variants can share a base shape, but use their own palette and local geometry. Only the selected variant's segments are constructed. A theme change hides every unused pooled Line, including when switching to the neutral fallback, preventing residual Mage or other class strokes.

These are original code-authored geometries rendered with native solid-color `Line` objects. They do not reuse EUI artwork, extract game emblems, download media, or add image files. One shared pool of **64 Lines** is created with Options and reused; only the selected geometry's endpoint list is generated. `SetStartPoint`, `SetEndPoint`, and `SetThickness` define actual stroke geometry directly. Unused strokes are hidden. Lines add no input frame, and no decorative frame covers interactive controls.

Review caught that rotating UVs on a narrow solid-white rectangular texture would not prove the desired stroke geometry. That provisional path was replaced before delivery. The implementation does not rely on `Texture:SetRotation`, and earlier mock rotation checks were not evidence of actual client rendering.

The panel backdrop's center uses `BACKGROUND`; the Body uses sublevel 1, sidebar/footer sublevel 2, and watermark sublevel 3. Child controls and text remain above those backgrounds. Selected category gradients use `ARTWORK` sublevel -1, above the underlying button fill and below text.

## Runtime isolation

- `headerKey` and `bodyKey` are resolved and cached independently. A changed Body key cannot recolor the Header; a changed Header key cannot recreate or recolor Body geometry. `themeKey` remains the composite diagnostic identity.
- Identity queries are `UnitFactionGroup("player")`, `UnitClass("player")` and current-player specialization metadata. Secret/unavailable values are rejected before comparison, indexing or display.
- While Options is visible, shared event callbacks handle `PLAYER_SPECIALIZATION_CHANGED`, `UNIT_FACTION`, `NEUTRAL_FACTION_SELECT_RESULT`, `PLAYER_ENTERING_WORLD`, `PLAYER_TALENT_UPDATE`, and `SPELLS_CHANGED`. The latter two let temporarily unavailable identity recover after talent/spell metadata arrives, without a timer or refresh button. Unit events ignore non-player units. Hiding Options removes only the theme callbacks. Reopening rereads identity.
- No `OnUpdate`, ticker, periodic scan, animated watermark, forced garbage collection, cooldown query, native duration binding or reminder-frame alpha write is added.
- Existing controls are skinned once and reused. A newly needed dropdown choice may allocate its own small skin when that control is first created; repeated switching after those choices exist reuses them. The watermark pool itself remains exactly 64 Lines regardless of the number of switches.
- Themes never write SavedVariables, reminder fonts/positions/scales, class colors, Preview state or Mobility subscriptions. Real Blink/Shimmer state and the next-charge timer are outside this module.
- Themes never depend on Mobility enablement, known spells, cooldowns, Preview, an initialized adapter or the Data package. A no-specialization class receives a dedicated base palette/motif; unavailable identity receives neutral. An unknown future specialization explicitly reports an unmapped specialization and class-base fallback instead of claiming coverage.

## Target-client API review and acceptance

Reviewed against the pinned Blizzard source for **Retail 12.1.0 / build 69933**, commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [`Blizzard_ClassSpecializationsFrame.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/ClassSpecializations/Blizzard_ClassSpecializationsFrame.lua) lists all target specialization IDs and class-specific localization keys in `SPEC_FORMAT_STRINGS`; this is the coverage inventory, not an invented skill database.
- [`SimpleTextureBaseAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua) declares `SetGradient(orientation, minColor, maxColor)` using `ColorMixin`. Only ordinary palette constants enter this API. If gradients are absent on another client, a static solid fill is the capability fallback.
- [`SimpleFrameAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua) declares `CreateLine(name?, drawLayer?, templateName?, subLevel?)`; [`SimpleLineAPIDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleLineAPIDocumentation.lua) declares `SetStartPoint(relativePoint, relativeTo, offsetX, offsetY)`, `SetEndPoint(...)`, and `SetThickness(uiUnit)`. The explicit endpoint contract establishes geometry rather than texture-coordinate rotation. Blizzard's [`EditModeTemplates.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_EditMode/Shared/EditModeTemplates.lua) also positions native Lines by endpoints. Watermark inputs are only ordinary constant coordinates/colors.
- [`Backdrop.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXML/Backdrop.lua) creates the center in `BACKGROUND` and supplies local backdrop color/border setters. Body sublevels deliberately sit above that center, so an opaque backdrop cannot conceal the gradient.
- [`UnitDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) and [`SpecializationInfoDocumentation.lua`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua) document the existing identity queries/events.
- [`SecureUIPanelTemplates.xml`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml) documents the template background layers beneath the category selection texture. No secure action, combat spell query, or restricted value is introduced by this skin.

Offline tests verify every class/spec mapping, split keys/colors, stable pool identities, callback lifecycle, fallback behavior, absence of cooldown/adapter activation and unchanged live timer bindings. They cannot confirm actual client pixel rendering or mouse-hit behavior. Each new theme is marked pending real-client visual acceptance. Check all Body watermarks, stable faction Header across spec changes, stable Body across faction identity changes where available, readable controls, several UI scales, dropdown/slider interaction, dragging empty areas, class/neutral fallbacks, and unchanged live Blink/Shimmer combat behavior. Synthetic geometry/palette contact sheets are development inspection only, never client screenshots or performance evidence.
