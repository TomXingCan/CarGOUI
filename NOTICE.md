# CarGOUI notices

CarGOUI 1.0.0-rc.3 is a release candidate supplied for evaluation and final regression testing. It is not an official Blizzard product or certification.

The source baseline does not contain an open-source LICENSE file. This notice does not grant a new license or change ownership. A distribution license must be selected by the project owner before a formal public release; the RC does not silently assign one.

The installer embeds LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0 for its standard launcher. Users do not need to install separate dependency addons. No complete Ace3/AceGUI framework or codec library is bundled. See Libs/THIRD_PARTY_NOTICES.md and the adjacent library license notices for pinned sources, upstream copyrights and redistribution terms; these libraries are not relicensed by CarGOUI. Configuration encoding uses the client's C_EncodingUtil APIs. Font files and native spell-overlay textures are supplied by the World of Warcraft client and are referenced by the addon, not redistributed here. Blizzard names and assets retain their respective rights.

The four bundled CarGOUI branding TGA files were produced for this project from the user-provided branding reference. Source artwork and production provenance remain in the repository under Media/Branding; they are excluded from this runtime installer. Body-theme watermarks use the project's existing static geometry.

Repository and development documentation: https://github.com/TomXingCan/CarGOUI/tree/feat/options-window
