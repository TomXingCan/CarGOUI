# Automatic client localization — 1.0.0

CarGOUI uses the text language reported by `GetLocale()` once when the AddOn loads. There is no language page, control, slash command, or saved preference. A changed client language takes effect on the next client launch or reload.

| Interface locale | Dictionary coverage | Offline validation | New client rendering | Native-speaker review |
| --- | --- | --- | --- | --- |
| enUS | 320 / 320 keys, complete base | Automated | Pending | Not performed |
| zhCN | 320 / 320 keys | Automated | Pending | Not performed |
| zhTW | 320 / 320 keys, separately maintained | Automated | Pending | Not performed |
| deDE | 320 / 320 keys | Automated | Pending | Not performed |
| frFR | 320 / 320 keys | Automated | Pending | Not performed |
| esES | 320 / 320 keys | Automated | Pending | Not performed |
| itIT | 320 / 320 keys | Automated | Pending | Not performed |
| ruRU | 320 / 320 keys | Automated | Pending | Not performed |

`enGB` is a defensive alias of `enUS`. `esMX` shares the Spanish interface dictionary, but game-owned spell names still come from that client's metadata. Unlisted locales use English interface text. A missing translation falls back to the English source text. Completeness checks ensure this fallback does not hide an untranslated supported page.

English is retained with at most one language overlay. All locale files listed by the same TOC execute; inactive files return **before constructing their translation table**. This is not a claim that those files are never loaded.

## Display boundaries

Controls, help, launcher tooltip, initialization/version message, combat queue notice, import/export review and errors, preview annotations, region labels, and color-editing explanations use the dictionaries. Internal status values, stable scope and region identifiers, file paths, API errors, and copied technical diagnostics remain language independent. Translations never select a spell or determine combat state.

Public spell IDs resolve game-owned names for the current active entries. The existing fallback name remains usable while metadata is unavailable; one bounded event-driven request per ID can update it. See [the API audit](LOCALIZATION_API.md). No full-class spell-name preload or name-based gameplay detection is introduced.

Mobility uses a complete translated `No %s` template with the name inserted before appending the native `\n{}` timer template. Only public names are formatted in Lua. The engine retains countdown rendering and visibility ownership. Proc live output remains digits only. Time Spiral's Free move label is translated before its native static-text slot is created, without adding a timer or changing the effect.

## Fonts and saved settings

New English installations retain Friz Quadrata. New Chinese, Traditional Chinese, Cyrillic, and Korean text clients use the client's standard font. Existing valid font choices remain stored, with a compatible font selected only at the render boundary when necessary. `Core/FontResources.lua` owns resource validation, LSM identity lookup, locale policy, effective status and a reused public scratch Font. The addon never reads native countdown text to check fonts; a nil `SetFont` return is not treated as failure. File availability is distinct from glyph coverage, which requires client inspection.

The picker separates Blizzard / Client and SharedMedia choices, combines duplicate effective paths and excludes the old Roman menu aliases on wide-language clients. Shared entries come only from LibSharedMedia's locale-filtered registry. CarGOUI embeds the library but no user font files; optional SharedMedia, MyMedia, ElvUI or other providers can register fonts. Availability differs with client language and installed addons. Font policy uses the actual client locale, including enGB, esMX, ptBR and koKR even when the addon interface uses an alias or English fallback. No operating-system font or directory scan occurs.

Known client font resources remain valid saved preferences across language changes. The existing `client-default` export identifier remains portable and resolves to the receiving client's default; the four existing named-font identifiers and the `CARGOUICFG:1:` format are unchanged. New shared selections use `LSM:<media-name>` in both saved settings and transfer payloads, never a resolved file path. A missing font renders with Client default while its logical preference remains unchanged and visible; a later font registration refreshes owned live, Preview and pooled font objects. Exports contain no translated labels or language setting. Current-class exports still exclude Options/minimap shell settings. Coordinates, scale, per-region Proc RGB, Free move offsets, import backups, and old RC compatibility retain their existing ownership. See [font architecture](FONT_SYSTEM.md).

Ordinary Options labels allow wrapping at the existing font size; dropdown popups provide more room and tooltips for localized names. No UTF-8 label is truncated by byte count. Original brand artwork is retained inside the [Modern CUI shell](MODERN_UI_1.0.1.md); the new grid and control layer replace the old global layout. No new fonts are bundled. Offline locale fixtures do not certify actual glyph metrics or clipping.

## Final client checks

The final archive's `.tests.txt` identifies its source commit, SHA256, actual extracted runtime path, Lua test result, and all static suites. These are offline checks, not a WoW combat, visual, or performance certification. The owner's RC.3 acceptance applies to that baseline, not automatically to this localization update.

1. Exit WoW, replace both AddOn program folders from the 1.0.0 ZIP, and retain WTF/SavedVariables. Check version 1.0.0 in the AddOns list and load message.
2. On each supported text client, visit General, Mobility, Proc, Appearance, Test Mode, and Import / Export. Inspect all buttons, dropdowns, empty states, errors, long hints, and launcher tooltip at normal and reduced UI scale. Check Chinese, Cyrillic, and accented glyphs; do not accept missing glyph boxes or clipped key actions.
3. Confirm actual spell names match the client; check Proc side/top/outside labels. Inspect localized Mobility live text and real native countdowns in and out of combat. Proc remains digits only; Time Spiral displays localized Free move without a countdown.
4. Export/import between English and Chinese, and between two European locales. Confirm the receiving-language review, unchanged scope IDs, independent XY/RGB/font settings, retained minimap preference, and backup restoration.
5. Check `/cui` and `/cargoui`, minimap/LDB/compartment entry points, single combat queue behavior, combat closing cleanup, drag ownership, and live Mobility/Proc/Free move continuity.
6. Reload and switch specialization repeatedly. Confirm no duplicated launchers, accumulated callbacks or timers, stale labels, changed coordinates, or overwritten appearance. Report the locale, client build, source version, and copied technical diagnostics with any issue.

Translations were authored and independently checked for source-key/format coverage. Dedicated native-speaker review has not been performed; terminology and visual acceptance remain separate checks.
