# CarGOUI 1.0.1 release checklist

The author confirmed the final RC checks complete and explicitly authorized
formal 1.0.1 integration and publication in this release task, including the
version-only closeout. This authorization is not a claim that a merge, tag,
Release or upload has already succeeded. Record those results after execution.
Historical v1.0.0 remains unchanged.

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

## Accepted RC and remaining artifact verification

The author's final confirmation identifies:

- Source: `9bef4c3b654c4a45a705b74cb1b0a46431367ace`.
- RC: `CarGOUI-1.0.1-RC-closeout-1-9bef4c3b654c.zip`.
- SHA256: `85264a3ce0f769a2a4a6983f9910274fa15360203927f66c6001a52b2eabb5dc`.

Source of acceptance is **author confirmation**. No new raw diagnostics,
measurements or video accompany that decision. Do not infer individual
class/source results or a new memory time series from the overall confirmation.

The author reported the four P1 checks passing onsite on MAGE / 62, Retail
build 69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`. Record this as
**author onsite confirmation**, not an offline result or an agent-run client
test. The [independent acceptance record](PROC_INDEPENDENT_ACCEPTANCE.md) owns
the exact four observations and their limits.

- [x] Complete the [scoped #15 readiness review](PROC_MEMORY_RELEASE_REVIEW.md)
  and record the author's final-RC admission approval. Technical investigation
  continues; the open issue is not by itself a release blocker.
- [x] Record the author's completed final-RC review against the exact identity
  above. Preserve the distinction between this overall acceptance and the
  separately documented P1 observations; no per-source results were supplied.
- [x] Retain the agreed focused scope. Do not make a new universal class,
  locale, collector or full historical matrix a prerequisite by implication.
- [ ] Run actual Lua 5.1, all six static suites and publisher unit tests against
  the final source. Record actual counts; do not copy counts from an old RC.

Offline tests check addon decisions and modeled API contracts. They do not
measure native pixels, taint, event delivery, native duration behavior or
client CPU/memory. Public-event replay remains evidence about the recorded
events, not proof for every source or startup condition.

The accepted RC's source and extracted-artifact results remain historical:
537 actual Lua 5.1 checks, 64 checks across six static suites, and 56 publisher
unit tests passed. These counts do not pre-fill the formal package report.
The remaining checkboxes concern the new formal artifact. Its actual source
SHA, hashes and verification results belong in its own manifest and test report
after the immutable build exists.

## Version and history rules

Synchronize `CarGOUI.toc`, `Modules/CarGOUI_Data/CarGOUI_Data.toc` and
`Core/Addon.lua` to formal 1.0.1 together, with consistent current user/release
text. This version-only closeout is explicitly authorized in the current task.
The official packager enforces that the three versions match. Schema 5 and
transfer format 1 remain separate, unchanged contracts.

The accepted RC remains frozen: its staging TOCs used `1.0.1-rc.closeout.1`,
while its committed version fields and internal `addon.version` were 1.0.0.
That historical overlay must not be rewritten to represent the formal package.
Build the formal version from its own clean committed source and verify its
final extracted bytes.

Keep the existing `CHANGELOG.md` v1.0.0 section, tag, Release and published ZIP
unchanged. Record 1.0.1 separately in the current release history. Do not
overwrite an old ZIP, rename an old release as the new one, or reuse its
checksum as candidate evidence.

## Integration order

The reviewed stack is:

1. [PR #12](https://github.com/TomXingCan/CarGOUI/pull/12):
   `feat/1.0.1-proc-appearance-v2` into `main`.
2. [PR #14](https://github.com/TomXingCan/CarGOUI/pull/14):
   `feat/1.0.1-modern-cui-shell` into the PR #12 branch, including independent
   artwork and the subsequent lifecycle/control fixes.

The authorized integration order is **PR #14 into the PR #12 branch, then
PR #12 into main**, retaining all commits. Recheck both PR heads/bases and the
combined diff before each operation. Verify
the resulting source tree against the accepted candidate, then perform final
package verification. Merging only PR #12 would omit the modern shell and
independent strategy. Record actual integration results separately; this
checklist does not establish that any remote operation has completed.

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
- [ ] Before CurseForge publication, confirm the existing project
  `tools-used: libdatabroker-1-1` relationship required by its retained notice.
  Source notices do not prove or change remote project configuration.

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

For the authorized official version, `python tools/package.py --output
<new-directory>` reads a clean committed Git tree, builds deterministic bytes,
checks ZIP CRC/content, extracts, and runs repository tests against that
extraction. It emits a checksum and test report. Packaging does not itself
publish the archive; publication uses the verified formal artifact.

- [ ] Record exact formal source commit/tree and any declared staging overlay.
- [ ] Check final ZIP paths, TOC dependencies/versions, required notices and
  all runtime bytes against that source plus the declared overlay.
- [ ] Run Lua/static tests against the extracted final ZIP and publisher unit
  tests separately. Check `git diff --check` before the source is committed.
- [ ] Emit the exact final ZIP filename, SHA256 and actual verification results
  alongside it. Do not insert an unmeasured checksum or count in this document.

## Publication sequence and safeguards

The [publisher workflow](CURSEFORGE_PUBLISHING.md) consumes an existing stable
GitHub Release's exact ZIP and checksum; it never builds or repackages source.
It requires canonical `vX.Y.Z`, matching TOCs, verified ZIP bytes and complete
named assets. RC/prerelease tags do not take this stable publishing path.

Publishing a stable GitHub Release can trigger CurseForge automatically and is
part of the current authorized publication task. Complete the documented
validate-only checks before publication. The workflow
blocks another 1.0.0 upload, duplicate versions and upload reruns; uncertain
uploads require investigation before recovery. Record the final tag, Release,
asset identities and actual publisher outcome separately; do not infer upload
success from authorization or prepared text. Do not alter the historical
v1.0.0 distribution.
