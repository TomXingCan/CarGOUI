# CarGOUI notices

CarGOUI 1.0.0 is an independent World of Warcraft Retail addon. It is not an official Blizzard product or certification.

## Project-owned code

The project owner has selected **GNU General Public License version 3 only (GPL-3.0-only)** for CarGOUI's project-owned source code. You may redistribute and modify that code under that license. No later-version option is granted by this project's notice. The full, unmodified license text is in [LICENSE](LICENSE). The program is provided without warranty, including the implied warranties of merchantability and fitness for a particular purpose, to the extent permitted by applicable law.

The license text was obtained from the SPDX project's [GPL-3.0-only text](https://github.com/spdx/license-list-data/blob/main/text/GPL-3.0-only.txt), reproducing GNU GPL version 3 of 29 June 2007. Its instructional appendix is part of the unchanged license document, not a separate later-version grant by CarGOUI.

## Branding assets

The emblem, logo, wordmark and other artwork/source artwork under `Media/Branding` are **All Rights Reserved**, outside the code license. See [Media/Branding/LICENSE.txt](Media/Branding/LICENSE.txt). These separate asset terms do not restrict the GPL rights in project-owned code. The four runtime TGA files derive from the user-provided branding reference. Source artwork and production provenance remain in the repository; the runtime installer omits production sources. Body-theme watermarks use the project's existing static geometry.

## Embedded libraries and client resources

The installer embeds LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0. Users do not need to install separate dependency addons. No full Ace3/AceGUI or codec library is bundled. [Libs/THIRD_PARTY_NOTICES.md](Libs/THIRD_PARTY_NOTICES.md) and adjacent license notices retain pinned sources, upstream copyrights and original redistribution terms. These libraries are not relicensed by CarGOUI.

Configuration encoding uses the client's C_EncodingUtil APIs. Font files and native spell-overlay textures are referenced from the WoW client, not redistributed. Blizzard names and assets retain their respective rights. Historical source quotations, external evidence and third-party notices retain their original provenance/language rather than being rewritten as newly authored English evidence.

Source and development records: [TomXingCan/CarGOUI](https://github.com/TomXingCan/CarGOUI).
