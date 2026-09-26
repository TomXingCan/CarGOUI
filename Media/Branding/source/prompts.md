# CarGOUI runtime branding generation

Built-in image_gen mode, 2026-09-26. Both requests use the user's supplied `cargoui_arcane_cargo_emblem.png` as a reference image. This reference was inspected before generation and is not bundled as a runtime texture.

## Wordmark prompt

Use case: logo-brand. Asset type: production game UI transparent artwork wordmark ONLY.
Input image 1 is a visual reference, not a crop/edit target: the user's CarGOUI logo, gold ornate satchel compass and ice blue arcane style. Create a newly designed horizontal brand wordmark derived from that direction, isolated on a GENUINELY TRANSPARENT BACKGROUND with alpha.
Exact text, case-sensitive: "CarGOUI" (C uppercase, a lowercase, r lowercase, G uppercase, O uppercase, U uppercase, I uppercase). Precisely seven letters. No other text.
Only the letterforms, no emblem, no satchel, no panel, no plaque, no underline, no outer border, no black backing, no environment. Delicate proprietary fantasy serif lettering with hand-shaped silhouettes and small angular serif cuts; professional premium addon brand. Car uses restrained champagne gold #D9B878; GOUI uses luminous but restrained icy cyan-blue #72D9EA. Fine beveled metallic rims, crisp subtly textured metal, very restrained shadow contained close to the glyph. Subtle small four-point star in the empty center of the O, as in reference. Letter spacing compact and balanced without overlap. All letters aligned on a stable baseline, no decorative extensions that compromise readability.
Design specifically to survive reduction to a 224 by 44 UI-unit title, so clear open counters, clean defined glyph edges, no tiny noisy runes. Target actual wordmark ratio about5.2:1, wide and shallow, centered with plenty of transparent padding around complete glyphs. Crisp, flat frontal view, no perspective, no glow fog. Avoid heavy game-login-screen mass and large flourishes. Transparent alpha, do not bake checkerboard or dark background. This is a runtime artwork asset, not a promo page or screenshot.

## Emblem prompt

Use case: logo-brand. Asset type: production game UI compact emblem ONLY.
Input image1 is the user's CarGOUI logo, used only as style/identity reference. Create a newly drawn simplified small emblem, isolated on GENUINELY TRANSPARENT BACKGROUND with alpha. Preserve the recognizable combination: dark blue traveling cargo satchel with champagne gold straps, one clean icy cyan orbit arrow wrapping around the satchel to suggest movement/utility, subtle fine gold circular compass rim and a small cyan diamond gem at the top. No words, no letters, no plaque, no hanging wordmark.
The emblem must remain visually readable when reduced to40x40 UI units, so simplify heavily: a clear bag silhouette and bold single orbit arrow, generous negative space, fine crisp gold outline, minimal small details. Premium tasteful blue/gold arcane fantasy art, small metallic bevels, quiet gold #D9B878 with icy cyan #72D9EA. Do not copy the source composition pixel-for-pixel or just crop it. No runic text, no complex rings, no particles, no many stars, no black square/background. Near-square icon composition, centered, complete outline and gem inside safe transparent padding. Clean alpha cutout, no checkerboard baked in, no background shadows. This is a compact transparent runtime game emblem, not a Curse promo image.
