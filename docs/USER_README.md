# CarGOUI 1.0.0-rc.3

Release candidate for WoW Retail 12.1 / Interface 120100. Existing ability/API source audit targets build 69933. Final client acceptance is still required.

RC3 adds the existing brand emblem to the AddOns list, a standard minimap/LDB launcher and the native AddOn Compartment menu. It retains RC2's Options drag safeguards and all real monitoring. Native dragging, manager integration and visual acceptance remain client tests.

## Install or upgrade

Exit WoW and place both `CarGOUI` and `CarGOUI_Data` directly in `_retail_/Interface/AddOns/`. Replace the two program directories together. Keep WTF and SavedVariables. Remove an obsolete `CarGOUI_Mage` program directory if still present from older versions; do not delete its saved data.

Use `/cui` or `/cargoui` to open Options. Both queue one opening request during combat and open once after combat ends. Entering combat closes settings without stopping real reminders. The UI defaults to English.

Plain left-clicking the minimap icon, LDB launcher or native compartment entry uses the same combat-safe behavior. General → **Show minimap icon** hides only the standard button; slash commands and the compartment remain available. Standard dragging positions an uncollected icon. Modified/right clicks are left to button collectors.

Necessary small libraries are embedded inside CarGOUI; no extra addon installation is needed. See `Libs/THIRD_PARTY_NOTICES.md`. HidingBar's default source collects only the standard button. Enabling both its LDB and minimap sources may show duplicate representations; use the manager's exclusion settings. WindTools and MBB standard interfaces were reviewed, but their exact versions still require client acceptance. Test managers separately.

## Settings

- Faction Header and class/spec Body themes are automatic; there is no Themes page.
- Mobility uses one configuration per class. Free move shares its appearance but has independent XY. Proc typography is shared within a class/spec; regions have independent XY and optional RGB. Inputs save on Enter; sliders and menus update immediately.
- Test Mode shows marked samples, not real effect state. Close/Stop ends TEST; real timers keep working.
- Import / Export: choose Current class or All saved settings, then Export. Select the text and press Ctrl+C. Nothing claims to write directly to the clipboard.
- Paste a settings string and click Import to validate and review its impact. Confirm applies it; Cancel leaves settings intact. Restore backup previews the most recent pre-import settings and also requires confirmation. Closing the window or entering combat cancels drafts and pending confirmations.

Only user settings are transferred. Imported class/spec identities are preserved rather than converted to your current character. A Mage-only import on a Warrior saves Mage settings and leaves Warrior appearance unchanged. All-saved exports include Options placement/branding animation and the validated minimap visibility/angle. Current-class exports exclude these shell settings. RC1/RC2 strings without minimap fields preserve your current icon preferences. Imports, backup restore and reset keep the existing button connected to the active settings. Keep your existing saved-variable backup during RC testing.

## Features and limits

CarGOUI displays real mobility depletion reminders, native timed Proc digits over admitted Blizzard graphics, and the confirmed Time Spiral Free move text. Proc coverage is selective: all 13 classes were reviewed, but not every spec has an eligible timer. Combat/secret state remains owned by native interfaces; there are no fabricated fallback seconds.

Prior user feedback confirmed Mage and other reported features in tested usage, not every class/talent/build. New settings transfer, native encoding, taint, layout and final gameplay regression need in-game acceptance. Offline tests do not provide client CPU/memory results.

Source, exact coverage, import format and RC checklist: https://github.com/TomXingCan/CarGOUI/tree/feat/options-window

See NOTICE.md for asset and licensing status. This package contains runtime files only; tests and development records remain in the repository. Do not treat this RC as a formal public release.
