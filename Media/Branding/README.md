# CarGOUI in-game branding assets

These runtime assets implement the incremental animated-title specification. The supplied `cargoui_arcane_cargo_emblem.png` was inspected and used as the visual reference: a traveling satchel, cyan orbit arrow, gold compass ornament, and blue diamond gems. The reference was genuinely available in this task. It is not bundled as a large in-game texture.

Two original transparent artwork variants were produced with the built-in image generation tool using that reference. The exact prompts are in [source/prompts.md](source/prompts.md), and the full generated RGBA PNG sources are retained beside them. These are newly generated compact emblem and wordmark assets, not a crop of the large reference, an ElvUI asset, or ordinary recolored Friz text. The wordmark spells **CarGOUI** with the specified case, champagne/gold `Car`, ice-blue `GOUI`, beveled contours, and a small star inside `O`.

## Runtime files

| File | Dimensions | Bytes | Role |
| --- | --- | ---: | --- |
| `wordmark.tga` | 512 × 128 | 262,162 | Static transparent artwork wordmark; no runtime font dependency. |
| `wordmark-mask.tga` | 512 × 128 | 262,162 | Exactly aligned glyph alpha for a masked highlight; white glyph RGB, transparent-black exterior. |
| `emblem.tga` | 128 × 128 | 65,554 | Small satchel/orbit/compass emblem. |
| `sweep.tga` | 32 × 128 | 16,402 | Soft white sweep strip, with zero alpha at both horizontal edges. It must be constrained by the glyph mask. |
| **Total** | | **606,280** | **592.07 KiB of runtime image files; below 1 MiB.** |

All runtime images are power-of-two, uncompressed 32-bit TGA true-color BGRA with 8-bit alpha and a top-left origin. File size is not a claim about GPU memory, CPU cost, or client-side allocation. The prior geometric header, glow, and emblem SVGs have been retired; the old header/glow TGA files are no longer needed or packaged.

The `source/` directory contains production PNG sources, prompt provenance, and a generated manifest. These are development assets retained in the repository and excluded from the installable add-on ZIP. The PNG sources are not loaded by the add-on. This phase does not create a Curse promo image.

## Geometry and masking contract

Wordmark and mask share the identical 512 × 128 canvas and alpha bytes. Use the same texture coordinates for both: **left 0.0078125, right 0.9921875, top 0.0546875, bottom 0.9375**. This samples the padded pixel rectangle `[4, 7, 508, 120]`, a **504 × 113** region. Displaying it at **196.2477876 × 44** UI units preserves its ratio inside the requested maximum 224 × 44 title area. The glyph alpha bounds are `[6, 9, 506, 118]` on the original canvas. The small transparent safety margin prevents clipped edge filtering.

The emblem uses the whole 128 × 128 texture at 40 × 40 UI units; its alpha occupies `[4, 4, 124, 124]`. Do not stretch either asset. The highlight strip is intentionally a separate neutral texture; the rendering code supplies its accent color and constrains it to the fixed mask. A standalone moving rectangle is not the intended result.

## Reproducible production preparation

Run from the repository root with Python and Pillow:

```sh
python Media/Branding/generate.py
python Media/Branding/generate.py --check
```

The converter preserves the generated alpha rather than extracting a black background. It removes only near-invisible alpha values 1–3 left by generation, trims transparent margins, fits the result without distorting its aspect ratio, and converts it to TGA. It derives the mask directly from the finalized wordmark alpha. The sweep is a deterministic cosine-squared gradient. The manifest records source hashes, crop/fit geometry, and final texture hashes. Validation checks decoding, dimensions, alpha corners, exact mask alignment and RGB behavior, payload length, hashes, and the runtime texture budget.

No font files are included. The fixed artwork is used only for branding; user-selected reminder fonts and ordinary readable Options labels are independent. The animation, combat/visibility lifecycle, and theme-color entry point live in `UI/Branding.lua`; changing reminder font size or scale must not change these artwork dimensions.

## Validation limits

Generated text spelling and the resized artwork were visually inspected on dark and light backgrounds at several output scales. An offline composition is an asset check, not a game screenshot. **In-game visuals have not been tested.** Retail must still verify TGA loading, transparency and edges, native mask/translation alignment, sweep clipping and lack of residue, readable sizing under UI scale changes, and the static fallback after stop/disable/combat. No in-game acceptance is claimed from the image source, conversion checks, or API mocks.
