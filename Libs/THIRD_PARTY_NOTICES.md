# Embedded launcher dependencies and third-party notices

Checked 2026-09-27. These four Lua files are included unmodified. They are the only new embedded libraries; CarGOUI does not embed Ace3, AceGUI, a codec or an addon manager. Users do not need to install separate library addons.

All files come from the [official LibDBIcon SVN release v12.0.3 at immutable repository revision 162](https://repos.curseforge.com/wow/libdbicon-1-0/!svn/bc/162/tags/v12.0.3/). Its TOC includes Retail Interface 120100. This identifies source compatibility, not a successful test in a running WoW 12.1 client.

| Embedded path | Runtime revision | SHA256 |
| --- | --- | --- |
| LibStub/LibStub.lua | LibStub minor 2 | f93f7dfbd280c0f8e0328bb194faa6db541c3c50b3d4d37eb064c816f0ec5576 |
| CallbackHandler-1.0/CallbackHandler-1.0.lua | minor 8; header SVN 26, 2022-12-12 | 84a15af505e728ac5e5eb6a8eaba8989d1131d5f8ba14d11abcfe4ce086de3c1 |
| LibDataBroker-1.1/LibDataBroker-1.1.lua | minor 4 | f3d4758f2060215492c9764b1d7dc2a336826d4cd253cd54ff9ff7c6d78f04e2 |
| LibDBIcon-1.0/LibDBIcon-1.0.lua | minor 56; v12.0.3 | 85c426947fa50319071b64c7cb845326c44316341713a3847dc8149c1e36716b |

Load order: LibStub → CallbackHandler → LibDataBroker → LibDBIcon. No vendor TOC or XML needs to execute. LibStub chooses a compatible already loaded equal/newer minor when another addon embeds it; exact runtime behavior can therefore be supplied by a newer shared copy. Test installed manager versions separately.

## Rights and attribution

- LibStub: public-domain dedication retained in source and LICENSE.txt.
- CallbackHandler: publisher's BSD terms preserved in its LICENSE.txt, with its published placeholders and the TOC attribution recorded rather than silently inventing copyright fields.
- LibDataBroker: upstream publisher says All Rights Reserved but explicitly directs addon authors to hard-embed it. LICENSE-NOTICE.txt records that authorization and source; no broader license is claimed. The original source is [Tekkub's revision 1a63ede0248c11aa1ee415187c1f9c9489ce3e02](https://github.com/tekkub/libdatabroker-1-1/blob/1a63ede0248c11aa1ee415187c1f9c9489ce3e02/LibDataBroker-1.1.lua); the release copy has the same content. The tools-used relationship is `libdatabroker-1-1`; any future CurseForge publication must add this relationship as directed by the author. This RC does not configure or invoke CurseForge publishing.
- LibDBIcon: complete publisher Ace3 Style BSD text preserved in LICENSE.txt. Embedding is permitted; standalone redistribution is restricted. The old standalone TOC X-License label discrepancy is explicitly recorded.

These statements apply only to the embedded dependencies, not the CarGOUI source or branding. The project owner retains the existing release/license decision.
