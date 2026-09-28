# CarGOUI 1.0.0

Real Mobility depletion reminders, native Proc countdown digits and Time Spiral Free move for WoW Retail 12.1 / Interface 120100. Existing skill/API audits target build 69933. This version keeps RC3 gameplay and adds automatic localization and safe font fallback.

## Install or upgrade

Exit WoW and place both `CarGOUI` and `CarGOUI_Data` directly in `_retail_/Interface/AddOns/`. Replace both program directories together. Keep WTF/SavedVariables. Remove an obsolete `CarGOUI_Mage` program directory if present; do not delete saved data.

Open Options with `/cui`, `/cargoui`, or plain left-click the minimap emblem, LDB launcher or native compartment. Combat requests queue once and open after unlocking. Entering combat closes settings without stopping real reminders or automatically requesting reopening.

General → **Show minimap icon** hides only the standard button; slash commands and the compartment remain available. Standard dragging positions an uncollected icon. Modified/right clicks remain available to collectors. Necessary libraries are embedded; see `Libs/THIRD_PARTY_NOTICES.md`. HidingBar defaults use the button only; enabling both LDB/minimap sources may create two representations, managed by its exclusions. WindTools/MBB interfaces were reviewed but exact versions need separate client acceptance.

## Language and appearance

The client locale automatically selects English, Simplified Chinese, Traditional Chinese, German, French, Spanish, Italian or Russian. enGB uses English, esMX Spanish, unknown locales English. Missing translations fall back to English. There is no manual language selector or saved language profile. Public ability names use the client API when available.

Saved font choices stay intact. If their resource/glyph coverage is unsuitable, live and Preview rendering can use a compatible client fallback without rewriting settings. New translations require native-speaker and client visual review; report missing glyphs, clipped labels or incorrect wording with locale/build.

- Faction Header and class/spec Body themes are automatic; there is no Themes page.
- Mobility shares settings within each class. Free move shares appearance but has separate XY. Proc typography is class+spec; regions have independent XY and optional RGB. Mobility/Free move remain fixed class color.
- Inputs save on Enter; sliders/menus update immediately. Proc colors preview until Okay; Cancel/close/context changes discard drafts.
- Blank Header/Body/sidebar/static areas drag Options; controls retain normal input. Reminders are not draggable.
- Test Mode shows marked samples. Close/Stop ends TEST; real timers keep working.

## Import / Export

Choose Current class or All saved settings and Export; select text and Ctrl+C. The addon does not claim direct clipboard access. Paste and Import to validate/review; Confirm commits, Cancel preserves settings. Restore backup reviews the last pre-import snapshot. Closing/entering combat cancels pending drafts and confirmation.

Only user settings transfer. Class/spec identities are preserved: Mage import on Warrior saves Mage data without converting Warrior appearance. All-settings includes window placement/animation and validated minimap visibility/angle. Current-class excludes shell settings. RC1/RC2 strings without minimap fields preserve icon preferences; import/restore/reset keeps the original button connected to active saved data. Automatic language and runtime font fallback do not add locale data to the transfer format.

## Features and limits

Mobility shows true next recovery when an admitted skill is depleted, hiding on the first recovered use. Proc shows digits over admitted Blizzard graphics; not every reviewed spec has an eligible timer. Free move is Time Spiral's receiving effect, text-only. Native interfaces retain secret state/timing; no fabricated fallback seconds or manual cast counting.

The user reported RC3 working in their test environment; this does not certify every class/talent/collector/locale. New localization needs client/native-speaker acceptance. Offline tests cannot establish native taint/rendering or client CPU/memory. Exact coverage, API evidence and final extracted-installer results are in the repository and adjacent delivery report/checksum.

[Source and documentation](https://github.com/TomXingCan/CarGOUI). Current project-owned source from the ARR LICENSE cutover is All Rights Reserved; official distributions may be installed and run for personal gameplay. The previously released v1.0.0 remains GPL-3.0-only as originally distributed, and its granted GPL rights are not revoked. The unchanged 1.0.0 development version string does not identify the historical release. Branding artwork remains All Rights Reserved and embedded libraries retain original terms. See LICENSE, NOTICE.md and Media/Branding/LICENSE.txt. The installer contains runtime files; tests and production records stay in the repository.
