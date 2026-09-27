# 1.0.0-rc.3 acceptance and release checklist

This candidate is based on RC2 (`b2eeb3a4bd418c5d61f2a3b3ac71e8de9345585a`). RC3 adds brand/launcher entries and minimap shell preferences; [LAUNCHER_RC3.md](LAUNCHER_RC3.md) gives its focused acceptance matrix and manager limitations. RC2's drag handoff remains intact; [DRAG_RC2.md](DRAG_RC2.md) contains its regression steps and evidence boundary. No formal release, main merge or CurseForge upload is authorized by this delivery. Automated tests and pinned API declarations cannot establish actual client dragging, encoding, rendering, taint or combat behavior.

## Final client regression

Use a copy of your SavedVariables for recovery; do not clear WTF. Install the two folders from the RC ZIP together. Record the exact client version/build, locale, class/spec and UI scale. Enable Lua errors for the session if desired. Restore your previous error-display preference afterwards.

1. Open `/cui` and `/cargoui` out of combat. No drag instruction or Themes category remains. Alternate grabs from Header, root/Body, sidebar and scroll-content blank areas, including different corners and UI scales: pickup must not jump. Inputs, sliders and buttons still receive their own input. Release outside the window, Esc, combat, hiding the source, resolution/UI-scale changes and world transitions must end an active drag cleanly. A later grab and `/reload` must restore sensible behavior and the saved position. Automatic themes continue working; unknown/deleted categories return to General. Screen-edge clamping and normal movement while the button remains held are not themselves failures.
2. In Import / Export choose **Current class**, export, select all and use Ctrl+C. Paste into a plain text editor and back, including normal line wrapping. Verify that the entire string survives copying and scrolling; selecting text is not an automatic clipboard write. Repeat with **All saved settings** large enough to require scrolling. This specifically exercises native `C_EncodingUtil` and real EditBox behavior, not the offline codec fixture.
3. Before export set different ordinary Mobility and Free move XY, a nondefault class style, different left/right Proc XY/RGB, and different styles in two saved specs. Export Current class, change those values, paste and click Import. Review the summary; Cancel must leave all new values. Re-import and Confirm must restore the exported scopes. Unincluded regions/specs/classes remain unchanged. A included region without a color must restore dynamic class color even if the target previously had RGB.
4. Export All saved settings; in a separate clean test saved-variable environment import it. Verify all previously saved classes/specs and shell settings restore, including negative offsets. Returning to the original saved-variable file must remain possible. This is a test procedure, not a requirement to erase your main settings.
5. On another class import the first class's export. The summary must identify that other class and say the current appearance is unaffected. It must not activate that other class's live adapter. Return to the original class and verify the stored settings. `/reload` retains committed data, independent tables/coordinates and backup, but never a pending confirmation.
6. Restore backup: review, Cancel and verify no changes; review again and Confirm. Verify the pre-import settings, including removal of newly imported scopes that were absent before that import. The backup is bounded to one snapshot and excluded from subsequent exports.
7. Try damaged Base64, a future prefix/version, malformed JSON, unknown region/field and invalid numbers/fonts. Each rejection must leave settings and live reminders intact. A recognized unavailable font must be reported with its local fallback in the review, before confirmation.
8. Begin a review then enter combat: Options closes, the text and transaction disappear, TEST and owned color drafts stop; live Proc/Mobility/Free move continue. Repeat `/cui` ten times in combat: one message/request; after combat it opens once without old text, confirmation, TEST or picker. Without an in-combat request it must not reopen automatically.
9. While ordinary reminders and multiple Proc regions are visible, confirm a style/XY/RGB-only import. Digits should continue their real remaining time, with no restarted cooldown, opacity flash, shared XY or changed unrelated region. Repeating the same import must not accumulate subscriptions, native containers or timers. Verify module-enabled changes start/stop only the affected current module.
10. Check the established gameplay paths: Mage Blink/Shimmer 2→1 stays hidden, 1→0 shows the next recovery, 0→1 hides; different Mobility skills coexist; native Proc trigger/partial consumption/refresh/end and specialization changes clean up correctly; Time Spiral Free move retains its separate position. Options closing and Test Mode stopping leave real monitoring active.

Record native empty-table JSON round trips (the protocol accepts both empty `{}` and empty `[]` for otherwise map-shaped fields), numeric spec-key restoration and localized client font fallback. Report any native API failure with exact build and error. No offline test result substitutes for these steps.

## Evidence shipped with this candidate

- Repository Lua 5.1 tests and static safety checks run against the final ZIP's extracted runtime files; development tools are not installed with the addon.
- ZIP SHA256, exact source commit/tree and individual test stdout/stderr are in the adjacent `.sha256` and `.tests.txt` files.
- Offline encoding uses Python JSON/Base64 bridged to Lua to test validation and transactions. WoW's actual codec, combat security, clipboard interaction, visual appearance and CPU/memory remain client acceptance items.
- Existing gameplay mappings and safety paths are retained. Coverage tables in the repository distinguish implemented/admitted timer regions, event-only or excluded effects and pending client checks. Not every specialization necessarily has a native Proc timer.

## Before a formal release

- [ ] User accepts this candidate's real-client regression, including native import/export round trips.
- [ ] Resolve any reported errors and repeat checks on the exact replacement ZIP.
- [ ] Review supported interface/build metadata against the actual target client.
- [ ] Confirm distribution rights and choose an explicit project license; `NOTICE.md` records current provenance and does not invent a license grant.
- [ ] Review the CurseForge description draft and current coverage/known boundaries.
- [ ] Complete RC3's launcher/collector checks separately for each manager version and verify the embedded-library attribution/relationship requirements before any actual publisher upload.
- [ ] User separately authorizes main merge, formal release/tag and any upload. None is performed by this RC task.
