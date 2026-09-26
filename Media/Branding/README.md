# CarGOUI branding assets

This is original geometric artwork created for CarGOUI in this phase, following the requested blue/gold arcane, movement, and utility direction. No existing logo file was supplied; these assets are not a reproduction of an assumed source logo. No ElvUI, EUI, ToxiUI, Blizzard artwork, or external font files are copied or bundled here.

| Asset | Purpose |
| --- | --- |
| `header.tga` | In-game Options header background, navy light, gold rails, and quiet arcane accents; 1024 × 128. |
| `emblem.tga` | In-game cargo-cube and movement/compass emblem; transparent, 128 × 128. |
| `glow.tga` | In-game blue light beneath the wordmark; transparent, 128 × 128. |
| `header.svg`, `emblem.svg`, `glow.svg` | Editable vector source/reference for a future Curse promotional composition. No full Curse promo image is claimed in this phase. |
| `generate.py` | Reproducible source geometry for the SVG and TGA assets. Uses Python and Pillow only. |

All TGA files are power-of-two, uncompressed 32-bit BGRA true-color with 8-bit alpha and a top-left origin. Combined uncompressed image payload is 640 KiB. They load only when the Options window is first created and are reused on subsequent opens. SVG/Python files are development assets, not runtime loads.

The `CarGOUI` wordmark is a native WoW font string using the game's Friz Quadrata, with a client-font fallback. It is not rasterized into a texture. This keeps text readable and avoids redistributing a font. When creating promotional artwork, use a separately licensed serif font for the wordmark; do not assume the game's font license permits redistribution.

The same static header remains visible with **Animated title** disabled. When enabled, one native `AnimationGroup` breathes the decorative blue glow from alpha 0.25 to 0.58 and back over 4.8 seconds. Closing Options stops the group; there is no `OnUpdate`, timer, polling, or animation Lua callback. Interaction and dragging are owned by `UI/Options.lua`; `UI/Branding.lua` supplies only the mouse-enabled header surface and its visual lifecycle helpers.

Regenerate from the repository root:

```sh
python Media/Branding/generate.py
```

Run `python Media/Branding/generate.py --check` to check texture format, power-of-two dimensions, alpha, byte length, Pillow decoding, and source presence without rewriting files.

The generator exports identical authored shape geometry to both formats. The SVG background/radiance uses native SVG gradients while the runtime TGA uses sampled gradients, so those soft fills are visual references rather than a byte-for-byte rendering contract.
