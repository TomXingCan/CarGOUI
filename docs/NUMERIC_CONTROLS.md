# Shared numeric controls

Numeric settings use `CUI.NumberRow`: a label, native Slider, and a value button that changes into an inline precise editor. The row keeps its footprint while editing. The Slider receives a TextureAsset and skins the texture returned by `GetThumbTexture`; it does not use Blizzard slider chrome or pass a Texture object as the asset.

The initial inventory contains 18 controls. There are no editable numeric Window or Interface fields in this Options build: those cards contain toggles, a center action, and the existing window drag behavior. This migration does not add window scale, window coordinate inputs, minimap angle inputs, or another setting merely because its storage model contains a number.

| Existing control | Storage and scope | Range | Default | Drag step | Display |
| --- | --- | --- | --- | --- | --- |
| Mobility X / Y (2) | Current class Mobility position | -10000..10000 | 0 | 1 | Coordinates |
| Free Move X / Y (2) | Independent Free Move position | -10000..10000 | 0 | 1 | Coordinates |
| Timer X / Y (2) | Selected Proc region position | -10000..10000 | 0 | 1 | Coordinates |
| Font size (1 reused by contexts) | Current class Mobility or current specialization Proc typography | 8..72 | 24 | 1 | Font size |
| Text scale (1 reused by contexts) | Same existing typography context | 0.5..3 | 1 | 0.01 | Multiplier |
| Artwork scale (1) | Selected region appearance | 0.25..3 | 1 | 0.01 | Multiplier |
| Artwork opacity (1) | Selected region appearance alpha | 0..1 | 1 | 0.01 | Percent |
| Desaturation (1) | Selected region appearance | 0..1 | 0 | 0.01 | Percent |
| Width / height (2) | Selected region appearance | 0.25..3 | 1 | 0.01 | Multiplier |
| Rotation (1) | Selected region appearance | -180..180 | 0 | 1 | Degrees |
| Artwork X / Y (2) | Selected region appearance offset | -1000..1000 | 0 | 1 | Coordinates |
| Animation speed (1) | Selected region appearance animation | 0.25..3 | 1 | 0.01 | Multiplier |
| Animation intensity (1) | Selected region appearance animation | 0..1 | 0.2 | 0.01 | Percent |

Ranges and defaults come from `Config/Defaults.lua`, `Core/ProcAppearance.lua`, and existing style/position factories. Typography scale previously dragged in 0.05 increments; 0.01 now gives finer feedback. Previously text-only fields receive steps appropriate to their units. Steps apply only to dragging. Valid precise inputs such as font size 31.5, scale 1.2375 and position -120.25 keep their existing stored precision; refresh and Reset do not quantize saved values. Percent display multiplies storage by 100 and precise input divides by 100. No schema, transfer format or SavedVariables field is added.

## Interaction and update ownership

- Programmatic `row:SetValue` is silent. User drag events update the slider, value display and existing presentation immediately. Identical normalized values do not submit twice. There is no delayed value animation or permanent polling.
- Clicking the value selects its numeric portion. Text changes are drafts; Enter commits a valid finite in-range value, Escape cancels, and ordinary valid focus loss can commit. Invalid Enter keeps the editor and feedback; invalid focus loss restores the last committed value. Changing targets or closing a page cancels instead of committing to another target.
- Dragging and editing have one active owner. Context is captured when interaction starts and checked before commit. Global mouse release ends native capture even outside the slider. Page/region/spec/combat/close boundaries cancel interaction and release focus. Mouse wheel belongs to the page, not the numeric Slider.
- Continuous UI edits use the existing validated settings API with `skipOptionsRefresh`; only the active numeric row needs to update its display. Position and typography changes retain the existing local re-anchor/style paths. Full page/selector reconstruction and Proc reconfiguration are unnecessary for these edits.
- Pure numeric artwork patches can additionally request `continuousAppearance`. A whitelist prevents modes, asset selection or Reset from using that shortcut. An active replacement and active preview update their current geometry/color/alpha and animation parameters without replaying entrance or replacing completion callbacks. A hidden exit may be canceled while native suppression remains owned until native release. Exceptions and quarantine keep their existing cleanup behavior.

Color remains the existing swatch/native picker workflow. Names, search, import/export and explanatory text remain text controls. Diagnostics and resource IDs remain read-only. Their numeric content does not make them editable settings.

## Offline and client acceptance

The regression suites exercise actual Slider assets/owned thumbs, silent refresh, drag normalization, negative/boundary/precise values, percent conversion, draft commit/cancel/focus loss, late callbacks, target changes, cleanup and bounded resource reuse. Existing scope, Reset, imports/exports, font and gameplay tests remain in the full suite.

Offline layouts verify geometric bounds, supported locales and viewport fitting, but cannot establish native font metrics or drag feel. In Retail, test negative X/Y, precise decimal entry, percent endpoints, Reset, releasing outside the row, page/region switches, and combat close. Confirm that the 900x640 shell remains usable at the existing supported window/UI scales and with long localized labels. Native suppression and the separate memory investigation retain their own acceptance gates.
