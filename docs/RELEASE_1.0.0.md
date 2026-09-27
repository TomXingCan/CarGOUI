# CarGOUI 1.0.0 — release and verification notes

## Scope and baseline

Version 1.0.0 continues the effective RC3 source and preserves user settings, RC2 Options dragging, launchers/collector safeguards, combat-deferred opening, class-owned Mobility, Time Spiral Free move, spec-owned Proc typography and independent region RGB/XY. The user reported RC3 working in their test environment. That feedback is retained as a user observation, without inventing a per-class, manager-version or build matrix.

This increment localizes the existing product and makes maintained project documentation English. It does not add skills, expand Proc/Mobility mappings, redesign Options, add a manual language selector or change native timing/visibility rules.

## Localization

- Automatically resolve GetLocale at load for enUS, zhCN, zhTW, deDE, frFR, esES, itIT and ruRU. enGB uses English, esMX Spanish, unknown locales English. English provides the complete fallback catalog.
- Retain English plus only the active locale overlay. Other locale files may execute and return before creating tables; this is not a claim of per-file zero loading.
- Localize existing UI labels, help, feedback, diagnostics presentation, fixed region/position descriptions and depletion/Free move text. Protocol tokens, saved keys, class tokens, spell IDs and source evidence remain stable.
- Obtain names for fixed public spell IDs from the client API. Cache within bounded current-context/catalog scope and retry only through defined events; missing data has safe text fallback. Names are display data, never identification or aura-state evidence.
- Preserve the requested saved font. Runtime fallback chooses an appropriate available client font where the request is missing or unsuitable for the active script, without modifying user typography records or reading secret timer text.
- No new language preference enters SavedVariables or transfer format 1. Existing schema 5 migration, RGB/XY isolation and import confirmation/atomicity remain.

See [localization design](LOCALIZATION.md) and [name/font API audit](LOCALIZATION_API.md) for exact implementation and limits. New language text has not received native-speaker certification. Offline locale coverage/formatting checks are not live glyph, clipping, input or combat acceptance.

## Installation and retained behavior

Exit WoW, replace **CarGOUI** and **CarGOUI_Data** together, and keep WTF/SavedVariables. An obsolete CarGOUI_Mage program directory can be removed; its saved data must not be deleted. `/cui`, `/cargoui`, minimap/LDB and native compartment still enter the same combat-safe Options lifecycle. Options remains lazy, Test Mode stays separate, and hiding an icon never stops real monitoring.

No reset is required. Current-class export excludes shell preferences; all-settings export contains only the validated shell fields, including minimap visibility/angle. Older RC1/RC2 strings lacking minimap data preserve current icon preferences. Runtime name/font localization does not rename configuration identifiers.

## Verification record

The retained RC3 baseline had **234 Lua 5.1 groups** (all 219 RC2 groups plus 15 launcher groups) and five static suites. The 1.0.0 delivery adds localization checks. Use the final ZIP's adjacent `.tests.txt`, `.sha256` and archive-verification data for the exact new counts, environment, source commit/tree and checksum; do not reuse a historical count as the current result.

Final validation must run the repository's tests against the **extracted installation ZIP**, not just the source checkout. Real embedded libraries execute in offline tests; WoW UI/API behavior is modeled and clearly separated from source/API evidence. No real WoW client or native-speaker review was available in development, and no client CPU/memory numbers are inferred from archive size.

Focused client checks:

1. Test supported client locales and one unsupported-locale fallback where available. Confirm every current page, tooltip, help/feedback and import summary is readable, without leaked keys or mixed placeholder formatting.
2. Verify native names for current abilities and each region's side/size description, including absent/loading spell-name fallback and later bounded recovery.
3. Check CJK/Cyrillic/accented glyphs in Options, live reminders and TEST at multiple UI scales. Saved requested fonts/size/outline/shadow/Scale must remain unchanged while fallback renders correctly.
4. Compare pre-upgrade positions/colors/styles and schema/transfer round trips. Language changes must not merge regional coordinates, change class/spec scopes or duplicate launcher objects.
5. Retest Options drag ownership, Enter/sliders, color Okay/Cancel, collector clicks/hiding, combat queue and live Blink/Shimmer/parallel Mobility/Proc/Free move without frozen/restarted timers or altered gate alpha.
6. Use the separate coverage tables for gameplay/theme gaps and exact manager-version notes. User RC3 success does not automatically certify new translations or every untested matrix row.

## License

The owner selected **GPL-3.0-only for project-owned code**, with **All Rights Reserved for branding artwork**. The full GPLv3 document is in root LICENSE, scope/attribution is in NOTICE.md, and Media/Branding/LICENSE.txt defines the separate artwork terms. Embedded libraries retain their original licenses and notices; Blizzard client fonts/textures are referenced rather than redistributed. No unspecified later GPL version is granted by the project's license notice.

## Publication status and prepared text

This document, [CurseForge description](CURSEFORGE_DESCRIPTION_DRAFT.md), changelog and package metadata are prepared for 1.0.0. Prepared text is not evidence of a remote upload. The available connector can update source/PR and merge after successful verification, but this environment currently has no callable GitHub About/Release creation/asset-upload endpoint or configured CurseForge publishing capability; browser retry was also unavailable. GitHub About/Release/asset and CurseForge publication remain pending unless a later verified result explicitly records completion. No hosted Release URL or uploaded ZIP is invented here.

Prepared GitHub About description:

> Retail WoW addon for real mobility depletion reminders, native Proc countdowns, Time Spiral Free move, and automatic multilingual settings.

Prepared release summary:

> CarGOUI 1.0.0 adds automatic UI localization for eight client languages, localized public ability names and safe font fallback while preserving the tested RC3 gameplay and settings. Install both CarGOUI and CarGOUI_Data; keep SavedVariables. Code is GPL-3.0-only, with separately reserved branding assets and original embedded-library licenses. Exact coverage, extracted-package tests and SHA256 accompany the release. New translations still need native-client/native-speaker acceptance; see the localization and coverage documents for limits.
