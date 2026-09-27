# Changelog

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
