# Localization and reminder font API audit

This change uses client language for interface text and game-owned localized names. It does not change spell IDs, aura IDs, native overlay mappings, saved scope keys, eligibility, combat visibility, duration objects, or color ownership.

## Source snapshot

The audit uses the published Blizzard UI/API source mirror at commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`. The AddOn targets Retail Interface `120100`. Source review and offline Lua execution are not a test inside that client build.

- [LocaleDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LocaleDocumentation.lua): `GetLocale()` returns the client locale name.
- [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua): `C_Spell.GetSpellName` and `GetSpellInfo` may return nothing; `RequestLoadSpellData` reports through `SPELL_DATA_LOAD_RESULT`, whose declared payload is `spellID, success`. The event is declared synchronous, so a listener and pending record must exist before requesting data.
- [GameFonts.xml](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Fonts_Shared/Shared/GameFonts.xml): Blizzard selects the locale's `STANDARD_TEXT_FONT` before defining shared fonts.
- [SimpleFontAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua): `SetFont` declares no return values; `GetFont` returns the font path, height, and flags. A public scratch Font can verify a trusted resource without examining reminder text.
- [SimpleButtonAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua): the normal `Button:GetFontString()` API returns its `SimpleFontString`. Options uses that ordinary label to enable wrapping at the existing font size; this does not involve any protected reminder FontString.

## Interface and game-owned names

`GetLocale()` is resolved once at load. Supported interface dictionaries are `enUS`, `zhCN`, `zhTW`, `deDE`, `frFR`, `esES`, `itIT`, and `ruRU`; `enGB` aliases `enUS` and `esMX` aliases `esES`. Other interface locales use English. There is no manual language setting or persistent locale field.

Spell names are requested with existing audited public numeric IDs through `C_Spell.GetSpellName`, with `GetSpellInfo(...).name` as a second path. Proc menu names prefer the actual aura ID over the activation-overlay ID: an overlay may be a dummy spell and is not interchangeable with the buff. Neither lookup establishes aura presence or remaining time. Player class and current specialization names come from the player's class/specialization metadata. Game-owned names therefore follow the actual client language even when the AddOn interface falls back to English.

The cache contains presentation metadata only. It is bounded to 128 requested spell IDs for the current class, specialization, and raw client locale. It does not instantiate every class's display entries. Missing data receives at most one load request per ID in that context. The shared event manager holds one callback while requests are outstanding and removes that callback when they complete; switching context discards the prior cache and callback on the next lookup or result. Synchronous completion returns the loaded name directly to the active caller and does not recursively refresh Options. No timer, cooldown query, aura scan, or permanent polling is added.

Every name/ID is checked for secrecy before string operations or numeric validation. Unavailable, secret, invalid, or failed metadata uses the entry's existing public English name; an unknown entry uses the translated `Unknown spell` label. No nil metadata result is interpreted as missing gameplay state.

Successful late metadata updates replace static display labels only. Live Mobility updates its native binding's text format, preserving the `{}` placeholder. It does not reset `DurationObject`, invoke `SetDuration`, read formatted timer text, alter alpha, or ask again about cooldown state. Preview resolves localized sample labels independently. Free move's static text is localized before the native aura reminder slot is acquired; native aura-slot lifecycle and stable identity remain unchanged.

## Effective reminder font

The four offered legacy Roman faces are retained in saved configuration. When rendering on `zhCN`, `zhTW`, `ruRU`, or `koKR`, these faces resolve to Blizzard's public `STANDARD_TEXT_FONT`. Custom/non-Roman face paths are preserved. This affects the effective per-reminder font only: it does not rewrite saved choices, global font objects, or global font variables, and it does not alter size, outline, shadow, scale, coordinates, or colors.

The audited source maps `zhCN` to `Fonts\\ARKai_T.ttf`, `zhTW` to `Fonts\\blei00d.TTF`, `ruRU` to `Fonts\\FRIZQT___CYR.TTF`, and `koKR` to `Fonts\\2002.TTF`. Code uses the client's own variable rather than hardcoding this table. A raw Korean client needs its native font for localized game names even though the interface dictionary falls back to English. Font selection happens during ordinary styling, not every frame. `SetFont` is treated as failed only on an explicit `false`; hosts returning no value on success must not silently replace the requested face.

A successful `SetFont` call confirms loading, not complete glyph coverage. Actual glyph rendering, clipping, and translated-label fit on Chinese, Traditional Chinese, Cyrillic, and other clients still require in-game visual acceptance.

For recognized imported built-in paths that are absent on the current installation, one reused public scratch Font checks the requested file using `SetFont` and its resulting `GetFont` face path. Availability is cached for these finite recognized paths. A missing file uses the current client standard font for rendering while retaining the saved choice. This probe never accesses a native timer FontString, aura child, rendered countdown, or combat state. A nil `SetFont` return alone does not establish failure.

## Verification boundary

The maintained offline Lua 5.1 suite covers localized spell metadata, actual-aura name selection, bounded synchronous/asynchronous loading and unsubscribe, opaque metadata fallback, context reset, the 128-entry cap, font fallback without database mutation, and native format-only updates without duration resets. It also opens every Options page, exercises launcher tooltips, status text, and import summaries in all eight interface locales; checks dictionary completeness and format placeholder compatibility; and round-trips full settings between languages including independent offsets, region RGB, and minimap preferences. Final extracted-package test output is the authoritative regression result for the delivered archive. No real WoW process, combat session, or multilingual client rendering was available for this audit.
