# 1.0.1 release closeout status

The author confirmed the final RC checks complete and explicitly authorized
formal 1.0.1 integration and publication, including the version-only closeout.
The accepted identity is:

- Source: `9bef4c3b654c4a45a705b74cb1b0a46431367ace`.
- Archive: `CarGOUI-1.0.1-RC-closeout-1-9bef4c3b654c.zip`.
- SHA256: `85264a3ce0f769a2a4a6983f9910274fa15360203927f66c6001a52b2eabb5dc`.

Source: **author confirmation**. No new raw snapshots, measurements or video
were supplied, so no new per-class/source outcomes are asserted here. #15's
release-admission decision is approved while its technical investigation
continues. An open #15 is not by itself a blocker, nor is approval a claim that
a permanent leak has been fixed. #16 remains complete only for the delivered
diagnostics and Proc quarantine subset.

The author accepted four P1 independent Proc checks on `bc91f3fe975e059fda2196cb4b6d75d40e371006`:
real acquisition/consumption/reacquisition/end, artwork switches preserving Timer,
saved-zero cold startup, and stock-opacity restoration pausing independent
artwork while Timer/preferences remain. Source: **author onsite confirmation**
in the existing Retail 69933 MAGE/62 context, not automated or video verification.
See [the scoped record](PROC_INDEPENDENT_ACCEPTANCE.md).

1.0.1 exposes only Native artwork with CUI Timer and opt-in independent CUI
artwork with CUI Timer. Old per-region Custom/Timer Only suppression is unavailable; stored
data is retained, with no saved/imported route to reopen takeover. Its old
first-SHOW and consumption exposure defects are not marked fixed.

Use [the final release checklist](RELEASE_1_0_1_CHECKLIST.md) for the authorized
integration and verification sequence, and the [#15 review](PROC_MEMORY_RELEASE_REVIEW.md)
for remaining technical questions. Authorization comes from the current 1.0.1
task, independently of the old v1.0.0 permission. Historical evidence and
checklist rows below remain context, not new prerequisites or invented passes.

The accepted RC's actual Lua 5.1, six static suites and publisher results remain
historical evidence. The new formal package's commit, checksum and actual test
results must be recorded after it is produced. Authorization and RC acceptance
do not establish completion of a remote merge, tag, Release or upload.

---

# Release acceptance: RC3 baseline and 1.0.0 localization

RC3 was based on RC2 (`b2eeb3a4bd418c5d61f2a3b3ac71e8de9345585a`) and added launchers/minimap preferences. The user subsequently reported RC3 working in their test environment, without a complete per-build/class/manager matrix. Version 1.0.0 preserved that baseline and added automatic localization. [LAUNCHER_RC3.md](LAUNCHER_RC3.md) and [DRAG_RC2.md](DRAG_RC2.md) retain focused checks and evidence boundaries. The historical 1.0.0 publishing task was authorized; its [release notes](RELEASE_1.0.0.md) record that version's capability limitations. Automated tests/source declarations cannot establish native dragging, encoding, glyphs, taint or combat behavior. The following procedures and unchecked rows are retained historical references, not additional 1.0.1 admission gates.

## Final client regression

Use a copy of your SavedVariables for recovery; do not clear WTF. Install the two folders from the delivered ZIP together. Record the exact client version/build, locale, class/spec and UI scale. Enable Lua errors for the session if desired. Restore your previous error-display preference afterwards.

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
11. In supported client locales, inspect every current Options page, tooltip, help message, combat feedback, diagnostic label and import summary. Check placeholders, spell names and region directions/sizes. Unknown locale and missing translation/name data must use the documented fallback, without leaked keys or a manual language setting. The imported/exported protocol remains unchanged.
12. Check CJK, Cyrillic and accented glyphs in Options/live/TEST at several UI scales. Rendering fallback must preserve the requested saved font, size, outline, shadow and Scale; no timer text readback, restarted binding, regional XY/color change or duplicated launcher may result. Record native-speaker feedback separately from glyph/layout and offline checks.

Record native empty-table JSON round trips (the protocol accepts both empty `{}` and empty `[]` for otherwise map-shaped fields), numeric spec-key restoration and localized client font fallback. Report any native API failure with exact build and error. No offline test result substitutes for these steps.

## Evidence shipped with each delivery

- Repository Lua 5.1 tests and static safety checks run against the final ZIP's extracted runtime files; development tools are not installed with the addon.
- ZIP SHA256, exact source commit/tree and individual test stdout/stderr are in the adjacent `.sha256` and `.tests.txt` files.
- Offline encoding uses Python JSON/Base64 bridged to Lua to test validation and transactions. WoW's actual codec, combat security, clipboard interaction, visual appearance and CPU/memory remain client acceptance items.
- Existing gameplay mappings and safety paths are retained. Coverage tables in the repository distinguish implemented/admitted timer regions, event-only or excluded effects and pending client checks. Not every specialization necessarily has a native Proc timer.

## Historical v1.0.0 release checklist

- [x] User reported RC3 working in their test environment; retain the scope of that feedback without inventing individual matrix passes.
- [ ] Record new localization's native-client and native-speaker acceptance, including fonts/layout and exact locale/build.
- [ ] Resolve any reported errors and repeat checks on the exact replacement ZIP.
- [ ] Review supported interface/build metadata against the actual target client.
- [x] For the historical v1.0.0 release, the owner selected GPL-3.0-only for project-owned code and All Rights Reserved branding; [v1.0.0/LICENSE](https://github.com/TomXingCan/CarGOUI/blob/v1.0.0/LICENSE) and [v1.0.0/NOTICE.md](https://github.com/TomXingCan/CarGOUI/blob/v1.0.0/NOTICE.md) retain those scopes and original third-party terms. The later ARR baseline applies to current source without changing this historical release or its granted GPL rights; see [current NOTICE.md](../NOTICE.md).
- [ ] Review the CurseForge description draft and current coverage/known boundaries.
- [ ] Complete RC3's launcher/collector checks separately for each manager version and verify the embedded-library attribution/relationship requirements before any actual publisher upload.
- [x] User authorized the 1.0.0 publishing task after successful verification. Record each actual source/merge/tag/Release/asset/CurseForge operation separately; unavailable remote operations remain pending rather than claimed complete.
