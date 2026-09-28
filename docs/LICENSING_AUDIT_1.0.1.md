# CarGOUI licensing ownership audit for the 1.0.1 baseline

Audit date: 2026-09-28. Audited production baseline: `3dd753427414321714b7502d77575236cd61f817` (`main`), tree `ad8fa0b3e9568226718f9d34d74553f65ccb5f2f`.

## Result

The reviewed repository history and current source identify no non-owner copyright contribution to project-owned CarGOUI source that requires an additional contributor's permission for the owner's prospective ARR cutover. The reviewed evidence supports proceeding with that cutover for project-owned material only. Third-party libraries, quoted external evidence, and referenced Blizzard resources are explicitly outside that ownership finding and must retain their respective notices and rights. This is an evidence-based repository audit, not a claim to have discovered unpublished agreements or unrecorded origins.

## History and contributor provenance

- Retrieved the complete GitHub commit collection for `main`: 37 commits, including 32 non-merge content commits and 5 merges. The oldest commit is the initial documentation commit `39c2b5fff41dcc18d60e7979f4527cd77c472a48`. Every parent SHA is present in the collection, establishing that the inspected graph reaches its root without a shallow-history gap.
- Every commit's author is `Tom Sheng <50365811+TomXingCan@users.noreply.github.com>`, and GitHub resolves every author to repository owner `TomXingCan`. All 32 non-merge commits have the same owner as committer. No Codex, bot, second human identity, `Co-authored-by`, or `Signed-off-by` attribution appears in these commit records/messages.
- The five merges have `GitHub <noreply@github.com>` / `web-flow` as committer. This is platform merge metadata, not evidence that GitHub authored CarGOUI. Each merge's tree is identical to its owner-authored second parent, so no separate merge-resolution source is introduced:

| PR | Merge | Owner branch tip | Shared tree |
| --- | --- | --- | --- |
| #1 | `121c6d1c94f6d55eb50e815403dffaa3787328ca` | `3d93679708e7117ef4444c57b70fb041c86cc3e2` | `218bd0284ed5dad4fe1d5f4729a9422a9f485d3f` |
| #2 | `22a5c65d5090ebf93ade3bade37f0999c50e2d2f` | `3969d551afcd7758ecde672bbea252a0f1e8b646` | `fc238bb32445d9e69a2e86851e73b5afa689cca4` |
| #3 | `c74db93b8b27cfce74cf9cc4fb6b1332441953c8` | `16c8630bad18aa6cc57997f0447ebd6aa1cccfa5` | `a4f78255d8b568925b7aab678ba87668641723c7` |
| #4 | `6d802d47a1722892b3db192fa1ba4697336ea909` | `93b18fd7391e8c3bc2b518ec53bc7d50b635840a` | `488ca826bb668c6f42225dd1cf470716bcc628ee` |
| #5 | `3dd753427414321714b7502d77575236cd61f817` | `61b9b1c5fa1b31fdaa1bc399d5231d7c0c011a37` | `ad8fa0b3e9568226718f9d34d74553f65ccb5f2f` |

- Retrieved all five existing PR records. Each was opened by `TomXingCan`, uses a branch in the same owner's repository, and is merged. All six currently listed branch tips belong to the audited graph. There is no external-fork PR contributor in this record.
- Retrieved changed-file lists and available textual patches for all 32 content commits, covering 184 historical paths. All 171 current tracked blobs have a changed-file provenance entry in that history. Scanned current source and historical additions for copyright, author, copying, adaptation, and upstream attribution; inspected the identified third-party/provenance cases below. Commit authors alone were not treated as proof of original authorship.

Primary history evidence: [commits](https://api.github.com/repos/TomXingCan/CarGOUI/commits?per_page=100&page=1), [pull requests](https://api.github.com/repos/TomXingCan/CarGOUI/pulls?state=all&per_page=100), [branches](https://api.github.com/repos/TomXingCan/CarGOUI/branches?per_page=100), [baseline tree](https://api.github.com/repos/TomXingCan/CarGOUI/git/trees/3dd753427414321714b7502d77575236cd61f817?recursive=1).

## Third-party and source-reference findings

All four embedded Lua libraries and their notices were introduced by owner commit `a0e31bfcf9594a008b104cc2b97e98fb7f0328e6`; no subsequent baseline history changes these files. The owner imported them but did not author them. Local bytes reproduce the four SHA256 values in `Libs/THIRD_PARTY_NOTICES.md`:

| Dependency | Attribution / preserved terms | Lua SHA256 |
| --- | --- | --- |
| LibStub | Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke; public-domain dedication | `f93f7dfbd280c0f8e0328bb194faa6db541c3c50b3d4d37eb064c816f0ec5576` |
| CallbackHandler-1.0 | Ace3 Development Team / Nevcairiel; publisher BSD notice | `84a15af505e728ac5e5eb6a8eaba8989d1131d5f8ba14d11abcfe4ce086de3c1` |
| LibDataBroker-1.1 | Tekkub; upstream ARR plus express embedding instructions; no invented MIT/BSD grant | `f3d4758f2060215492c9764b1d7dc2a336826d4cd253cd54ff9ff7c6d78f04e2` |
| LibDBIcon-1.0 | Rabbit, Funkeh/funkydude, copystring and contributors; Ace3 Style BSD embedding terms | `85c426947fa50319071b64c7cb845326c44316341713a3847dc8149c1e36716b` |

Their pinned distribution source is the [official LibDBIcon v12.0.3 SVN revision 162](https://repos.curseforge.com/wow/libdbicon-1-0/!svn/bc/162/tags/v12.0.3/). The adjacent original license notices remain controlling. In particular, preserving third-party ARR for LibDataBroker is distinct from applying the owner's ARR decision to CarGOUI.

The audit also followed the explicit EUI reference instead of assuming an owner-authored import was original. Retrieved [EllesmereUI MovementAlert at 394319df23b67d4b09850a78a8d6a542beb80140](https://github.com/EllesmereGaming/EllesmereUI/blob/394319df23b67d4b09850a78a8d6a542beb80140/EllesmereUIQoL/EllesmereUIQoL_MovementAlert.lua) and inspected its charge visibility implementation against `Modules/CarGOUI_Data/Classes/Mage/SpellState.lua`, `Modules/CarGOUI_Data/Shared/SpellState.lua`, and the CarGOUI rendering path. Both use native curve APIs, as the existing audit documents explicitly acknowledge. EUI's fixed 1.6-second classifier and direct-slot fallback structure are not carried over: CarGOUI validates public per-spell metadata, has separate cache/result/error handling, and conveys duration/curve handles to its renderer. A cross-check of non-comment complete source lines with at least 24 characters found only three identical generic WoW event/combat condition lines across current CarGOUI runtime directories; no distinctive copied implementation was identified. This supports the recorded interface-idea provenance without treating a textual comparison as exhaustive authorship proof.

Proc/Mobility definition tables and `tests/fixtures/proc_sources_69933.lua` cite pinned Blizzard DB2 IDs, durations, relations, and SimulationCraft spell-data facts. Inspected definitions/fixture retain those citations; they do not embed the SimulationCraft C++ implementation. Existing external quotations and factual-source attribution remain separate from the project's ownership claim. Client fonts and native textures are references, not bundled font/texture copies.

The phrase "copied native duration binding" in `Modules/Proc/AuraState.lua`, `UI/ProcDisplay.lua`, and the Proc API documents refers to Blizzard copying an in-memory binding template supplied by the addon, not CarGOUI copying Blizzard's source implementation. Independently fetched and inspected pinned Blizzard `Blizzard_CustomAuraButton.lua`, `Blizzard_CustomAuraContainer.lua`, and `Blizzard_FrameXML/SpellActivationOverlay.lua` at `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`. CarGOUI calls the client-provided `SetDurationText` and `AddAuraSlot` interfaces; it does not embed those mixin implementations. Its `AnchorProcReminder` computes text-center positions from the documented native root/edge geometry and public scale, while Blizzard's implementation lays out graphic overlay textures. The common API identifiers and geometry facts are not an imported Blizzard implementation. `docs/API_AUDIT_MOBILITY.md` labels its binding snippet as the historical CarGOUI setup and preserves the separately linked API declarations.

The cutover LICENSE records the following scope: "Third-party libraries, external source quotations and excerpts, and Blizzard/client resources retain their respective rights and applicable original terms. API references and source citations do not transfer ownership to CarGOUI." Existing citations and original notices are retained. This exclusion prevents an overbroad project ARR statement from claiming third-party material; it is not a new permission grant for that material.

Branding provenance is documented in `Media/Branding/README.md`, `source/prompts.md`, and `source/production-manifest.json`: generated assets derived from the owner's supplied reference, with a separate pre-existing ARR notice. This baseline must preserve that separate asset boundary rather than asserting that vendor imports or Blizzard resources are owner-authored branding.

## Historical GPL boundary and immutable baseline

The new policy is prospective: project-owned CarGOUI copies/source from the cutover commit forward are ARR. Existing GPL rights in copies already received under GPL remain intact, including the official v1.0.0 release. The cutover must not imply that unchanged historical code ceased to be available under its previously granted GPL terms. The [GNU GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#CanDeveloperThirdParty) distinguishes the copyright owner's ability to issue different licenses from the licenses already granted to recipients.

Before changes, the existing historical release was verified read-only:

- `refs/tags/v1.0.0` points to `121c6d1c94f6d55eb50e815403dffaa3787328ca`.
- [GitHub release v1.0.0](https://github.com/TomXingCan/CarGOUI/releases/tag/v1.0.0), release ID `397588667`, published `2026-09-27T09:42:45Z`, explicitly states GPL-3.0-only for project-owned code, ARR for branding, and original third-party licenses.
- Installer asset ID `592607785`, `CarGOUI-1.0.0.zip`, size `388040`, digest `sha256:84fb669b285c8cafb78507a35adf4ee300dd1be1e09c85f81969fbfbf6035ad1`, last updated `2026-09-27T09:41:33Z`.
- All four release asset identities, digests, sizes and update times were recorded for final read-only comparison.

The ownership audit was read-only. The baseline changes are proposed separately through a branch and PR; no historical tag, Release or asset is changed.
