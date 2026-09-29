# CarGOUI 1.0.1 release preparation

This checklist prepares a candidate; it does not authorize a merge, version
change, tag, GitHub Release, asset upload or third-party publication. Production
versions remain 1.0.0 in this round. Historical v1.0.0 remains unchanged.

## Frozen candidate scope

- Include the font selector/LibSharedMedia integration, Modern CUI controls,
  numeric/tint editing, audited artwork catalog and explicit Independent CUI
  strategy.
- Support two Proc paths: Blizzard Native artwork + native-bound Timer, and
  Independent CUI artwork + the same native-bound Timer.
- Keep legacy per-region replacement/suppression outside the supported release
  scope. Retained compatibility code and saved legacy modes are not a claim
  that the legacy first-SHOW defect has been fixed.
- Preserve old modes and visual preferences when independent strategy is
  selected; require explicit region opt-in and keep Timer settings separate.
- Explain that the user must manually set both Blizzard Spell Alert settings
  to zero for live independent artwork, and manually restore opacity when
  native alerts are needed. All native alerts are hidden at zero, including
  uncovered sources. CUI does not restore or maintain either CVar.
- Keep Class Tools, its logger, research material and standalone observers out
  of the production installer.

## Evidence and remaining acceptance

The author reported the four P1 checks passing onsite on MAGE / 62, Retail
build 69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`. Record this as
**author onsite confirmation**, not an offline result or an agent-run client
test. The [independent acceptance record](PROC_INDEPENDENT_ACCEPTANCE.md) owns
the exact four observations and their limits.

- [x] Complete the [scoped #15 readiness review](PROC_MEMORY_RELEASE_REVIEW.md)
  against its latest evidence and comments. The review retains the P0 gate;
  the author's final-RC admission decision is still pending.
- [ ] Record the requested WARLOCK check separately; do not infer it from
  MAGE/62 or a synthetic Lua fixture.
- [ ] Check font selection/SharedMedia, Mobility, Free move, native Timer,
  Options/Preview and settings transfer on the final staged RC. Record the
  installed RC identity and exact results rather than carrying P1 acceptance
  forward to different bytes.
- [x] Retain the agreed focused scope. Do not make a new universal class,
  locale, collector or full historical matrix a prerequisite by implication.
- [ ] Run actual Lua 5.1, all six static suites and publisher unit tests against
  the final source. Record actual counts; do not copy counts from an old RC.

Offline tests check addon decisions and modeled API contracts. They do not
measure native pixels, taint, event delivery, native duration behavior or
client CPU/memory. Public-event replay remains evidence about the recorded
events, not proof for every source or startup condition.

The remaining verification checkboxes are the per-artifact procedure. Exact
completion results, source SHA and hashes belong in the delivered RC manifest
and test report; they must not be guessed before that immutable build exists.

## Version and history rules

`CarGOUI.toc`, `Modules/CarGOUI_Data/CarGOUI_Data.toc` and `Core/Addon.lua` all
currently report 1.0.0. This matches the development convention in
[the roadmap](ROADMAP_1.0.1.md). Leave all three unchanged in this round.

An RC uses a unique staging directory and artifact name. Apply only its
documented TOC version overlay to staging copies, retain the committed source
identity, and state the unchanged internal `addon.version` in the delivery
record. Re-run verification against the final extracted staged artifact.
Neither an RC name nor this checklist authorizes a formal version bump.

After a separate formal release confirmation, update the two production TOCs
and `addon.version` together to 1.0.1, and update the current user/release text
consistently. The official packager enforces that the three versions match.
Schema 5 and transfer format 1 remain separate, unchanged contracts.

Keep the existing `CHANGELOG.md` v1.0.0 section, tag, Release and published ZIP
unchanged. The new Unreleased section describes preparation only. Do not
overwrite an old ZIP, rename an old release as the new one, or reuse its
checksum as candidate evidence.

## Integration order

The reviewed stack is:

1. [PR #12](https://github.com/TomXingCan/CarGOUI/pull/12):
   `feat/1.0.1-proc-appearance-v2` into `main`.
2. [PR #14](https://github.com/TomXingCan/CarGOUI/pull/14):
   `feat/1.0.1-modern-cui-shell` into the PR #12 branch, including independent
   artwork and the subsequent lifecycle/control fixes.

When integration is separately authorized and gates pass, the preferred order
is **PR #14 into the PR #12 branch, then PR #12 into main**, retaining all
commits. Recheck both PR heads/bases and the combined diff at that time. Verify
the resulting source tree against the accepted candidate, then perform final
package verification. Merging only PR #12 would omit the modern shell and
independent strategy. No merge or retarget is performed by this checklist.

## License and third-party gate

Source consistency was checked against the current notices:

- [x] Existing `LICENSE` and `NOTICE.md` identify current project-owned source
  after the recorded cutover as All Rights Reserved. No new license decision
  is introduced here.
- [x] Historical v1.0.0 remains GPL-3.0-only as distributed; its existing rights,
  tag, Release and installer are not revised. Branding remains separately ARR.
- [x] All five embedded library Lua files match the pinned hashes in
  `Libs/THIRD_PARTY_NOTICES.md`; original notices are retained.
- [x] LibSharedMedia source explicitly declares LGPL v2.1. Its source SHA256 is
  `ea359e44eae4355c51a49a69960c878889ee26adac9d72d1362c22a3db6af6d0`;
  the complete LGPL text SHA256 is
  `20e50fe7aae3e56378ebf0417d9de904f55a0e61e4df315333e632a4d3555d95`.
  Both match the provenance notice. The project LICENSE retains the stated
  own-use modification/debugging exception and compatible-library replacement
  rights; the library is not relicensed as ARR.
- [x] No font or Blizzard artwork file is supplied through the registry or
  asset catalog. Fonts from other providers remain supplied by those addons.
- [ ] Recheck the final ZIP includes project/branding notices, all embedded
  library notices, complete LGPL text and the unmodified library sources.
- [ ] Before a future CurseForge publication, confirm the existing project
  `tools-used: libdatabroker-1-1` relationship required by its retained notice.
  This preparation does not prove or change remote project configuration.

These are consistency/provenance checks against existing terms, not a new
relicensing authorization. See [the ownership audit](LICENSING_AUDIT_1.0.1.md)
and [third-party notices](../Libs/THIRD_PARTY_NOTICES.md).

## Installer contents and verification

Use `tools/package.py`'s TOC-derived `install_files` whitelist. It requires
exactly two top-level addon directories, `CarGOUI` and `CarGOUI_Data`; the data
TOC must remain load-on-demand and depend on CarGOUI. File counts are derived
from the final manifest, not from an earlier package.

Required non-Lua payload:

- Both addon TOCs.
- The four existing runtime TGAs: `emblem`, `wordmark`, `wordmark-mask`, `sweep`.
- Installed `CarGOUI/README.md` from `docs/USER_README.md`, plus `CHANGELOG.md`,
  `NOTICE.md` and the project `LICENSE`.
- `Media/Branding/LICENSE.txt`, `Libs/THIRD_PARTY_NOTICES.md`, and all adjacent
  embedded-library `LICENSE*` files, including both LibSharedMedia notices.

Include every declared runtime Lua dependency, including Proc presentation,
safety and diagnostics modules and the data package definitions. Exclude
Research/ctlog, Class Tools research, standalone capture/probe addons, tests,
tools, source art, development docs, logs, temporary exports and build scripts.
This checklist stays in the repository; the concise user README is what ships.

For an official version after authorization, `python tools/package.py --output
<new-directory>` reads a clean committed Git tree, builds deterministic bytes,
checks ZIP CRC/content, extracts, and runs repository tests against that
extraction. It emits a checksum and test report. For the current staging-only
RC, preserve the same whitelist and validate the final overlaid extraction;
the production packager is not a command to publish an RC or change versions.

- [ ] Record exact source commit/tree and the complete staging overlay.
- [ ] Check final ZIP paths, TOC dependencies/versions, required notices and
  all runtime bytes against that source plus the declared overlay.
- [ ] Run Lua/static tests against the extracted final ZIP and publisher unit
  tests separately. Check `git diff --check` before the source is committed.
- [ ] Emit the exact final ZIP filename, SHA256 and actual verification results
  alongside it. Do not insert an unmeasured checksum or count in this document.

## Future publication boundary

The [publisher workflow](CURSEFORGE_PUBLISHING.md) consumes an existing stable
GitHub Release's exact ZIP and checksum; it never builds or repackages source.
It requires canonical `vX.Y.Z`, matching TOCs, verified ZIP bytes and complete
named assets. RC/prerelease tags do not take this stable publishing path.

Publishing a stable GitHub Release can trigger CurseForge automatically. Treat
that action as publication authorization, not as a harmless packaging step.
Use the documented validate-only step when separately authorized. The workflow
blocks another 1.0.0 upload, duplicate versions and upload reruns; uncertain
uploads require investigation before recovery. This round does not merge,
retarget, tag, create a Release, upload assets, dispatch publishing, or alter
the historical v1.0.0 distribution.
