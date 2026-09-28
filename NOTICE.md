# CarGOUI notices

CarGOUI is an independent World of Warcraft Retail addon. It is not an official Blizzard product or certification.

## Project-owned code

Copyright (c) 2026 Tom Sheng (TomXingCan). **All Rights Reserved** applies to current project-owned source from the commit that introduces the ARR [LICENSE](LICENSE), and to future project-owned source unless expressly licensed otherwise. That commit is the 1.0.1 development baseline cutover. The unchanged production `1.0.0` version string is not the licensing boundary. Official distributions may be installed and run for personal gameplay; other permissions and the warranty disclaimer are set out in LICENSE. The ownership audit is retained in the source repository as `docs/LICENSING_AUDIT_1.0.1.md`; it records the reviewed history and third-party exclusions.

## Historical GPL release

**CarGOUI v1.0.0 remains GPL-3.0-only as originally distributed.** Its tag points to `121c6d1c94f6d55eb50e815403dffaa3787328ca`; its [original license](https://github.com/TomXingCan/CarGOUI/blob/v1.0.0/LICENSE), [Release and installer](https://github.com/TomXingCan/CarGOUI/releases/tag/v1.0.0) remain unchanged. The ARR cutover does not revoke, restrict, or replace any GPL rights already granted for v1.0.0 or other pre-cutover GPL distributions. No later-GPL-version option was granted by the v1.0.0 project notice.

## Branding assets

The emblem, logo, wordmark and other artwork/source artwork under `Media/Branding` are **All Rights Reserved**, outside the code license. See [Media/Branding/LICENSE.txt](Media/Branding/LICENSE.txt). These separate asset terms do not restrict the GPL rights already granted in historical project-owned code. The four runtime TGA files derive from the user-provided branding reference. Source artwork and production provenance remain in the repository; the runtime installer omits production sources. Body-theme watermarks use the project's existing static geometry.

## Embedded libraries and client resources

The installer embeds LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 and LibSharedMedia-3.0. Users do not need to install separate dependency addons. No full Ace3/AceGUI or codec library is bundled. [Libs/THIRD_PARTY_NOTICES.md](Libs/THIRD_PARTY_NOTICES.md) and adjacent license notices retain pinned sources, upstream copyrights and original redistribution terms. These libraries are not relicensed by CarGOUI. LibSharedMedia-3.0 by Elkano is used under its source-declared GNU LGPL v2.1; its unmodified Lua source, complete [license text](Libs/LibSharedMedia-3.0/LICENSE.txt) and [provenance notice](Libs/LibSharedMedia-3.0/LICENSE-NOTICE.txt) are included. Its library and use remain covered by LGPL, including the applicable modification and debugging rights.

Configuration encoding uses the client's C_EncodingUtil APIs. Font files are referenced from the WoW client or other installed media providers, not redistributed by CarGOUI. Native spell-overlay textures remain client references. Blizzard names and assets and third-party fonts retain their respective rights. External source quotations and excerpts retain their original rights and applicable terms; API references and source citations do not transfer ownership to CarGOUI. Historical source quotations, external evidence and third-party notices retain their original provenance/language rather than being rewritten as newly authored English evidence.

Source and development records: [TomXingCan/CarGOUI](https://github.com/TomXingCan/CarGOUI).
