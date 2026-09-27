# CarGOUI — CurseForge description draft

**Prepared for 1.0.0; not uploaded by writing this file.**

CarGOUI is a Retail reminder addon with a standalone `/cui` settings window.

- Mobility reminders stay hidden while a supported ability has a use available, then show its real next-availability countdown when depleted.
- Native Proc digits appear over the corresponding Blizzard screen graphic. Multiple regions retain their own positions and optional RGB colors.
- Time Spiral's confirmed free-use effect shows **Free move**, with coordinates independent from ordinary Mobility.
- Mobility settings belong to each class. Proc typography belongs to each class and specialization. Automatic faction Headers and class/spec Body themes require no manual selection.
- Options automatically follows English, Simplified/Traditional Chinese, German, French, Spanish, Italian or Russian clients, with English fallback. Public ability names use the client language when available; runtime font fallback preserves saved font preferences.
- Import / Export shares current-class or all-saved settings through a copyable string, with validation, impact review, confirmation and one recoverable pre-import backup.
- Options closes safely in combat. An explicit combat opening request waits once until combat ends. Sliders update immediately; numerical edits save on Enter.
- A standard minimap/LDB launcher and native AddOn Compartment entry open the same settings. Hide only the minimap icon in General; slash commands and the compartment remain available.

## Install and upgrade

Install both **CarGOUI** and **CarGOUI_Data** in `_retail_/Interface/AddOns/`. The internal Data addon loads automatically. Keep WTF and SavedVariables. Required launcher libraries are embedded; no separate dependency addon is needed. Use `/cui` or `/cargoui` to open Options.

## Coverage and verification

Target: Retail 12.1 / Interface 120100; existing skill/API audits pin build 69933. Coverage is selective, based on verified finite effects with native graphics. It does not mean every specialization has a Proc timer. Exact mappings/exclusions and source evidence are maintained in the repository's Proc and Mobility coverage documents. Samples are explicitly TEST and isolated from real effects; no fixed seconds substitute for restricted runtime state.

Version 1.0.0 keeps RC3's gameplay, launchers and drag safeguards and adds automatic localization. The user reported RC3 working in their own test environment. New translations and locale-specific glyph/layout behavior remain pending native-client and native-speaker review. Offline tests, source audits and user reports are separate evidence; neither universal manager compatibility nor measured zero resource use is claimed. Test collectors separately; HidingBar dual-source settings may create two representations and can exclude one source.

## License and sources

Project-owned code: **GPL-3.0-only**. Branding artwork: **All Rights Reserved**, under a separate notice. Embedded libraries retain original licenses; client fonts/graphics are referenced, not redistributed. CarGOUI is not an official or certified Blizzard product.

Source, exact coverage, localization notes and license notices: [TomXingCan/CarGOUI](https://github.com/TomXingCan/CarGOUI).

This is ready-to-review publishing text. Actual CurseForge project creation/upload is a separate operation and remains pending until a verified publishing result is recorded.
