# Changelog

## 1.0.1 — Unreleased / release preparation

- Fix font selection and integrate registered LibSharedMedia fonts while preserving logical saved choices, client-language filtering and safe rendering fallback. Keep the embedded library's original LGPL 2.1 terms and complete notices.
- Add the shared Modern CUI shell, reusable controls, exact inline numeric editing, separate Timer/artwork tint controls, and contextual Proc Test/Stop actions.
- Add the audited Blizzard artwork catalog and independent per-region visual preferences without packaging client texture files or changing schema 5 / transfer format 1.
- Include opt-in Independent CUI artwork alongside the existing Blizzard Native + Timer path. Independent artwork follows public graphical events and uses the existing native-bound Timer independently of the user's manually muted Blizzard artwork. Its master and per-region artwork switches do not disable Timer.
- Require manual Blizzard Spell Alert Opacity zero and display zero for live independent artwork. Preserve old modes/styles and pause artwork when either setting is unavailable or nonzero. Disabling Proc/artwork, changing strategy or quarantine never restores the game setting automatically; users must restore opacity manually to see native alerts again.
- Keep legacy per-region replacement/suppression outside the supported candidate scope. Its retained compatibility code and earlier regression repairs do not establish that the legacy first-SHOW defect is resolved.
- Bound Proc resource ownership and diagnostic capture, retain failed cleanup ownership, and quarantine repeated internal failures with explicit Retry/Reload recovery. Policy edits/import/restore/reset clean previous artwork before committing; failure leaves settings unchanged.
- Record the author's four P1 checks as onsite confirmation for MAGE / 62, Retail build 69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`. WARLOCK and final-RC font/SharedMedia, Mobility, Free move and integration checks remain pending; offline tests do not substitute for them.
- Keep production TOCs and `addon.version` at 1.0.0 during preparation. RC versions belong only to separately named staging packages. Formal 1.0.1 versioning, merge, tag, Release and publication require separate approval. Current source follows the existing ARR cutover; the historical v1.0.0 GPL distribution and the entries below remain unchanged.

## 1.0.0

- Automatically select the client-language UI for English, Simplified Chinese, Traditional Chinese, German, French, Spanish, Italian and Russian; retain English fallback without a manual language setting or new saved scope.
- Use bounded public spell-name localization and rendering-only font fallback while preserving requested fonts, stable IDs, native timer ownership and all existing settings.
- Make maintained project documentation English, retaining historical evidence, coverage limitations, pinned references and original third-party notices.
- Preserve the user-reported working RC3 baseline, including Options dragging, combat-deferred opening, standard launchers, Mobility, native Proc, Time Spiral Free move and separate regional positions/colors.
- Retain all 234 RC3 Lua 5.1 groups and extend localization/static checks; exact final extracted-installer results and SHA256 accompany delivery. New translations still require native-client and native-speaker acceptance.
- Apply the owner's license choice: GPL-3.0-only for project-owned code, separate All Rights Reserved branding assets, and unchanged original third-party licenses. Publication text is prepared; remote Release/asset/CurseForge publication is not implied by this changelog.

## 1.0.0-rc.3

- Reuse the existing transparent emblem for both AddOns list entries, one standard LDB launcher/minimap button, and the main addon's TOC-registered native compartment entry.
- Embed pinned LibStub, CallbackHandler, LibDataBroker and LibDBIcon sources with their notices; no separate dependency installation is required.
- Route plain left-clicks through the existing combat-safe Options toggle. Preserve RC2 dragging, lazy Options creation and all real reminders.
- Add General's Show minimap icon setting; keep shell display/angle independent of class settings and window/reminder positions.
- Include whitelisted minimap settings only in all-settings exports. Old imports retain existing preferences. Keep the library-bound settings table stable through import, restore and reset, without replacing collected-button drag scripts or layout.
- Retain all 219 RC2 regression groups and extend the Lua 5.1 suite with actual embedded library execution. Manager source checks and offline simulations are distinct from pending real-client acceptance.
- No formal Release, main merge or CurseForge upload.

## 1.0.0-rc.2

- Integrate the RC1 drag handoff: start native Options movement from the current mouse position and keep ownership of the initiating background surface.
- End active drags safely on outside release, source hiding, combat/close and viewport/world boundaries; remove temporary callbacks after each session.
- Capture and validate the visible center before stopping native movement, and keep SavedVariables as the Options position owner.
- Preserve the 204 RC1 regression groups and add the handoff's 11 drag groups, plus focused integration regressions. Gameplay monitoring and settings-transfer logic are unchanged.
- Native pickup-jump resolution remains pending real-client verification. No formal Release, main merge or CurseForge upload.

## 1.0.0-rc.1

- Remove the dragging hint and Themes category; keep whole-window background dragging and automatic faction/spec themes.
- Enable Import / Export with current-class and all-saved-settings scopes, validation, an impact summary, explicit confirmation and one recoverable pre-import backup.
- Preserve class-owned Mobility, independent Free move coordinates, specialization-owned Proc fonts and independent region RGB/XY.
- Ship a runtime-only two-folder installer; repository tests run against its extracted code.
- Release candidate only. Native encoding round trips and final client regression remain pending; no formal Release or CurseForge upload is performed.

## 0.1.0-alpha.16

- Isolate Free move coordinates from the ordinary class Mobility group, preserving old effective positions once.
- Reposition affected existing wrappers without restarting live monitoring on coordinate-only edits.
- Validate 183 Lua 5.1 smoke tests and three static suites on the extracted installer.

## 0.1.0-alpha.15

- Review 12 non-Mage classes / 37 specializations and add 63 admitted Proc definitions across 81 regions.
- Keep four reviewed specializations without an admitted timer explicitly empty; no invented timers or samples.
- Retain Mage mappings, Mobility, Time Spiral Free move, regional colors and combat-locked Options.

Earlier implementation history and source audits remain in the repository's docs directory.
