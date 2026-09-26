# Increment A — artwork title with glyph-masked light

This is an incremental change on the existing Options branch. It preserves `/cui`, Enter-to-apply, header-only window dragging, shared SavedVariables, English UI, and external Test Mode cleanup. It does not produce Curse promotional content.

## Art and layout

The user provided `cargoui_arcane_cargo_emblem.png`. Two transparent art variants were created with the built-in image generation tool using the real file as a reference: a simplified satchel/orbit/gem emblem and the exact-case **CarGOUI** wordmark. The source PNGs and [full prompts](../Media/Branding/source/prompts.md) are retained in the repository. No font files or third-party addon artwork are bundled, and no global game font object is modified.

The existing panel remains 720 × 560. Its header is 720 × 76, with the 40 × 40 emblem at X24/Y-18 and the artwork at X76, vertically centered in a 44-unit slot. The artwork uses a shared 504 × 113 UV region of its 512 × 128 image and mask, producing a ratio-preserving 196.2478 × 44 display. Right-side Options/version text is static. A faint one-unit line completes the title area. Content pages and the Close button keep their existing positions. The panel's viewport-fit scale affects the entire window together; reminder font/size/scale do not affect header geometry.

Only the existing header Frame accepts dragging. Artwork, mask and line are texture regions without mouse handlers. No extra decorative frame can steal header input.

## Native animation and mask

The art and glyph mask share exactly the same alpha, texture coordinates and fixed anchors. A separate highlight strip (18% of wordmark display width) starts entirely to the left, moves entirely to the right, and is clipped by the fixed mask. The base artwork never translates, scales, rotates or fades.

One looping native AnimationGroup owns the strip:

- Translation: duration 1.5 seconds, end delay 5 seconds, IN_OUT smoothing.
- Alpha: 0 to 0.22 over the first 0.25 seconds; 0.22 to 0 over the final 0.25 seconds starting at 1.25 seconds, then 5 seconds end delay.
- All tracks use order 1, so total cycle length is 6.5 seconds, not a sum of track durations. There are no per-frame Lua callbacks, timers, SetText updates or regenerated textures.

Stopping calls `Stop()` when playing, sets strip alpha to exactly zero, and restores its initial anchor. `SetToFinalAlpha(false)` is explicit. The static art/emblem retain alpha 1. Ordinary input, categories and dragging do not restart a playing group.

The capability fallback is **glyph-pulse-fallback**, not an unmasked sweep: the same precomputed glyph highlight is gently alpha-pulsed over 4.8 seconds, with `Glyph pulse fallback` shown in the header hint. Normal Retail APIs select **masked-sweep**. This capability check is not proof of actual pixel rendering; the native sweep and fallback both await in-game visual acceptance.

## Visibility, combat, and theme entry point

`RefreshTitleAnimation()` requires `panel:IsVisible()`, `options.animatedTitle`, and no `InCombatLockdown()`. Combat events are subscribed only while the visible window has animation enabled. `PLAYER_REGEN_DISABLED` immediately stops/reset the highlight; `PLAYER_REGEN_ENABLED` re-evaluates visibility/preference before playing. Closing Options or disabling animation removes both listeners. No ability, Buff, cooldown or restricted state drives decoration.

The existing Options OnShow/OnHide handlers are not replaced. Their preview, dropdown and input-focus cleanup remains intact. Combat callbacks touch branding only; native animation has no Lua callbacks, so neither animation frames nor combat events refresh the Options controls or reminder renderer.

`UpdateBrandingTheme({r,g,b})` accepts finite normalized accent values and updates only the sweep and faint line. It does not recolor brand art, change reminder settings, start automatic class themes or add a spell/talent database.

## Measured resource budget

| Resource | Actual count / size |
| --- | --- |
| Decorative Texture | 4: emblem, wordmark, highlight, line |
| MaskTexture | 1 on the normal path; fallback can have 0 or an unused failed mask |
| Looping AnimationGroup | 1 |
| Native animation tracks | 3 normal; 2 in the explicit fallback |
| Header Frame | 1, reused and already the drag surface |
| Ordinary FontString | 2: Options/version and drag/fallback hint |
| Runtime TGA files | 4, total 606,280 bytes (592.07 KiB) |

Detailed sizes, alpha/UV geometry, hashes and conversion checks are in the [asset README](../Media/Branding/README.md). Source PNGs are development inputs, excluded from the install ZIP. File sizes are not GPU memory, CPU usage or zero-cost guarantees.

## API verification sources

- [PlayerChoice fixed mask with delayed looping Translation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerChoice/Blizzard_PlayerChoiceToggleButton.xml#L65)
- [Soulbinds texture-owned sheen under a fixed mask](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Soulbinds/Blizzard_SoulbindsNode.xml#L221)
- [SpellBook same-order delayed Alpha tracks](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/SpellBook/Blizzard_SpellBookItem.xml#L271)
- [Frame / CreateMaskTexture API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [Texture / AddMaskTexture API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureAPIDocumentation.lua)
- [AnimationGroup lifecycle API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleAnimGroupAPIDocumentation.lua)
- [InCombatLockdown boolean definition](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
- [QuestSession visible-only combat listeners](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/QuestSession.lua#L124)

These support API names and structure. They do not expose the renderer's exact mask-channel formula or validate our pixels in the client.

## Executed checks and remaining game acceptance

37 Lua 5.1 tests pass, retaining all previous interaction/preview coverage and adding packed TGA/art/mask checks, 20 open/close cycles with stable object counts, visibility/combat gating, no decorative panel/preview refresh, no animation restarts on routine edits, stable artwork dimensions, and explicit fallback/theme tests. Production conversion checks validate transparent edges, exact wordmark/mask alpha identity, dimensions, hashes, budget and decoding. Resized art was visually inspected on dark/light backgrounds.

**游戏内视觉未实测 — in-game visuals have not been tested.** The asset proof is not a game screenshot. Retail acceptance must still check:

1. Real TGA loading, transparent edges and exact readable CarGOUI lettering at multiple UI scales.
2. Highlight confined to glyphs: no rectangular backing, mask drift, doubled glyphs, residue or jump during the 5-second rest.
3. Identical static art when disabled/in combat, immediate stop/reset, correct visible-only recovery, and preference persistence after reload.
4. 20 open/close cycles, header dragging, Close/Esc, dropdowns/input focus and external preview cleanup without regressions.
5. Reminder Font Size/Scale changes leave branding untouched; no texture clipping or content overlap on smaller viewports.
