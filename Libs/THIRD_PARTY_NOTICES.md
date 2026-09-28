# Embedded dependencies and third-party notices

Checked 2026-09-28. Five library Lua files are included unmodified: the four launcher dependencies below and LibSharedMedia-3.0 for registered fonts. CarGOUI does not embed full Ace3, AceGUI, a codec or an addon manager. Users do not need to install separate library addons. No font, sound or texture files are added with LibSharedMedia.

The four launcher files come from the [official LibDBIcon SVN release v12.0.3 at immutable repository revision 162](https://repos.curseforge.com/wow/libdbicon-1-0/!svn/bc/162/tags/v12.0.3/). Its TOC includes Retail Interface 120100. This identifies source compatibility, not a successful test in a running WoW 12.1 client.

| Embedded path | Runtime revision | SHA256 |
| --- | --- | --- |
| LibStub/LibStub.lua | LibStub minor 2 | f93f7dfbd280c0f8e0328bb194faa6db541c3c50b3d4d37eb064c816f0ec5576 |
| CallbackHandler-1.0/CallbackHandler-1.0.lua | minor 8; header SVN 26, 2022-12-12 | 84a15af505e728ac5e5eb6a8eaba8989d1131d5f8ba14d11abcfe4ce086de3c1 |
| LibDataBroker-1.1/LibDataBroker-1.1.lua | minor 4 | f3d4758f2060215492c9764b1d7dc2a336826d4cd253cd54ff9ff7c6d78f04e2 |
| LibDBIcon-1.0/LibDBIcon-1.0.lua | minor 56; v12.0.3 | 85c426947fa50319071b64c7cb845326c44316341713a3847dc8149c1e36716b |

Launcher load order: LibStub → CallbackHandler → LibDataBroker → LibDBIcon. LibSharedMedia must load after LibStub and CallbackHandler. No vendor TOC or XML needs to execute. LibStub chooses a compatible already loaded equal/newer minor when another addon embeds it; exact runtime behavior can therefore be supplied by a newer shared copy. Test installed manager and media-provider versions separately.

## LibSharedMedia-3.0 font registry

The unmodified source is pinned to the [official v12.1.0 release at SVN repository revision 177](https://repos.wowace.com/wow/libsharedmedia-3-0/!svn/bc/177/tags/v12.1.0/LibSharedMedia-3.0/LibSharedMedia-3.0.lua). The Lua file last changed at revision 176; its LibStub minor is `12000002`. The [release page](https://www.wowace.com/projects/libsharedmedia-3-0/files/8691989) identifies v12.1.0 and the added known-file validation. Only the Lua file is embedded, using the existing LibStub and CallbackHandler dependencies.

| Embedded path | Runtime revision | SHA256 |
| --- | --- | --- |
| LibSharedMedia-3.0/LibSharedMedia-3.0.lua | minor 12000002; v12.1.0 / SVN r176 | ea359e44eae4355c51a49a69960c878889ee26adac9d72d1362c22a3db6af6d0 |

The source header explicitly states **LGPL v2.1**, credited to Elkano with inspiration from Haste/Otravi's SurfaceLib. The project overview's generic ARR label differs from this explicit source declaration; it is not used to relicense the library. [LICENSE-NOTICE.txt](LibSharedMedia-3.0/LICENSE-NOTICE.txt) records that distinction and provenance. [LICENSE.txt](LibSharedMedia-3.0/LICENSE.txt) contains the complete, unmodified LGPL 2.1 text from GNU. The library remains separately licensed and replaceable; the project ARR terms do not override LGPL rights.

CarGOUI uses the font registry only. The library's built-in entries reference client files, and other addons supply their own registered font files. CarGOUI does not copy those files, enumerate OS fonts, expose SharedMedia textures, or create a texture-pack dependency.

The pinned `Register("font", key, path, langmask)` accepts only known files and fonts declared compatible with the current locale. Locale bits are `koKR=1`, `ruRU=2`, `zhCN=4`, `zhTW=8`, and `western=128`; no mask defaults to Western-only registration. CarGOUI consumes the accepted registry rather than bypassing registration filters. `LibSharedMedia_Registered` reports the event name, media type and key for successful late registration. `Fetch` may respect a global override even with `noDefault=true`; `IsValid`/`HashTable` distinguish an actual registered key from fallback behavior. See the [official API documentation](https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation) and pinned source for the exact current behavior. These declarations are not a guarantee of font glyph quality in a running client.

The WoW 12.1 [pinned client API documentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UIFileAssetAPIDocumentation.lua) includes the `C_UIFileAsset.IsKnownFile` function used by this release. A known loose-file reference does not prove that the file exists or can be opened; CarGOUI separately probes the resolved font with an owned scratch Font. That probe checks whether the font can be applied, not its glyph coverage.

## Rights and attribution

- LibStub: public-domain dedication retained in source and LICENSE.txt.
- CallbackHandler: publisher's BSD terms preserved in its LICENSE.txt, with its published placeholders and the TOC attribution recorded rather than silently inventing copyright fields.
- LibDataBroker: upstream publisher says All Rights Reserved but explicitly directs addon authors to hard-embed it. LICENSE-NOTICE.txt records that authorization and source; no broader license is claimed. The original source is [Tekkub's revision 1a63ede0248c11aa1ee415187c1f9c9489ce3e02](https://github.com/tekkub/libdatabroker-1-1/blob/1a63ede0248c11aa1ee415187c1f9c9489ce3e02/LibDataBroker-1.1.lua); the release copy has the same content. The tools-used relationship is `libdatabroker-1-1`; any future CurseForge publication must add this relationship as directed by the author. This RC does not configure or invoke CurseForge publishing.
- LibDBIcon: complete publisher Ace3 Style BSD text preserved in LICENSE.txt. Embedding is permitted; standalone redistribution is restricted. The old standalone TOC X-License label discrepancy is explicitly recorded.

These statements apply only to the embedded dependencies, not the CarGOUI source or branding. The project owner retains the existing release/license decision.
