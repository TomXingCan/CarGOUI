# CarGOUI — 1.0.1 candidate preparation

Real Mobility depletion reminders, native-bound Proc countdowns and Time Spiral Free move for WoW Retail 12.1 / Interface 120100. Existing skill/API audits target build 69933. This candidate adds SharedMedia font support, Modern CUI controls and opt-in independent artwork. Production source still reports 1.0.0 until a separately approved formal version change; an RC has a separate staging name and checksum. It is not the historical v1.0.0 release.

## Install or upgrade

Exit WoW and place both `CarGOUI` and `CarGOUI_Data` directly in `_retail_/Interface/AddOns/`. Replace both program directories together. Keep WTF/SavedVariables. Remove an obsolete `CarGOUI_Mage` program directory if present; do not delete saved data.

Open Options with `/cui`, `/cargoui`, or plain left-click the minimap emblem, LDB launcher or native compartment. Combat requests queue once and open after unlocking. Entering combat closes settings without stopping real reminders or automatically requesting reopening.

General → **Show minimap icon** hides only the standard button; slash commands and the compartment remain available. Standard dragging positions an uncollected icon. Modified/right clicks remain available to collectors. Necessary libraries are embedded; see `Libs/THIRD_PARTY_NOTICES.md`. HidingBar defaults use the button only; enabling both LDB/minimap sources may create two representations, managed by its exclusions. WindTools/MBB interfaces were reviewed but exact versions need separate client acceptance.

## Language and appearance

The client locale automatically selects English, Simplified Chinese, Traditional Chinese, German, French, Spanish, Italian or Russian. enGB uses English, esMX Spanish, unknown locales English. Missing translations fall back to English. There is no manual language selector or saved language profile. Public ability names use the client API when available.

The font picker separates Blizzard / Client fonts from SharedMedia fonts registered by local addons. LibSharedMedia is embedded; no separate library addon is needed. CarGOUI ships no user font files and does not scan system fonts. Available fonts depend on client language and installed addons; the client default remains selectable.

Saved font choices stay intact. A missing SharedMedia choice keeps its name through export/import and can resolve again when its provider registers it. The picker shows the selected preference separately from the effective client fallback; hover a font button to read long names in full. Live reminders and Preview update immediately. New translations require native-speaker and client visual review; report missing glyphs, clipped labels or incorrect wording with locale/build.

- Faction Header and class/spec Body themes are automatic; there is no Themes page.
- Options uses the shared Modern CUI shell and controls, section cards and session-only Advanced disclosure. Class Tools has no production page or logger command.
- Mobility shares settings within each class. Free move shares appearance but has separate XY. Proc typography is class+spec; regions have independent XY and optional RGB. Mobility/Free move remain fixed class color.
- Numeric rows allow exact inline input: valid Enter or focus loss saves, Escape cancels, and close/context changes discard drafts. Sliders/menus update immediately. Proc colors preview until Okay; Cancel/close/context changes discard drafts.
- Blank Header/Body/sidebar/static areas drag Options; controls retain normal input. Reminders are not draggable.
- Proc Region Editor selects one Proc and stable region. The gallery offers audited client artwork, separate artwork tint/alpha/scale and animation presets; Advanced expands extra transforms. Timer color and timer XY remain separate.
- Reset artwork changes only that region's appearance settings, leaving strategy, region enablement and timer settings intact. Timer typography opens the editor shared by the current specialization.
- Test shows marked samples for the selected region. Close/Stop ends TEST. Independent TEST follows region artwork enablement and can run with the live artwork master off or live artwork paused; it never establishes live state or proves native timer behavior.

## Two Proc paths

**Blizzard Native + Timer** keeps Blizzard artwork with CarGOUI's existing native-bound digits. Old settings do not automatically enable independent artwork. Legacy per-region Custom replacement and Timer Only suppression remain compatibility code outside this candidate's supported scope; the older first-SHOW issue is not declared fixed.

**Independent CUI + Timer** draws CUI-owned artwork from public Spell Alert events and keeps native Aura duration binding for its timer. To opt in:

1. Keep Proc enabled and choose **Artwork strategy → Independent CUI**.
2. Enable the independent live artwork master and explicitly enable each wanted region. A missing region choice means off. These artwork switches do not disable Timer.
3. Manually set Blizzard **Spell Alert Opacity** to zero. Live artwork requires both `spellActivationOverlayOpacity=0` and `displaySpellActivationOverlays=0`. CUI never writes either setting.
4. Obtain a real Proc. Entering this strategy clears old graphical state, so a buff already present needs a new valid public SHOW before artwork appears. Timer bootstrap and TEST do not synthesize artwork events.

Global zero hides **all** Blizzard Proc artwork, including uncovered Procs; one side cannot remain genuinely Native. If either setting is unavailable or nonzero, independent artwork pauses and reports why, while Timer and saved preferences remain intact. Existing legacy modes, assets, tints, scale, animation and offsets are retained; independent rendering uses visual preferences without activating the old mode.

**Restore Blizzard Spell Alert Opacity manually to see native alerts again.** Turning artwork or Proc off, changing spec/strategy, or quarantine never restores the setting for you. Use the Native + Timer path when returning to stock graphics; retained legacy Custom choices are not an approved fallback. If a strategy change cannot clean previous artwork, it is rejected without committing settings. Copy diagnostics with `/cui diagnostics copy`; explicit `/cui proc retry` or `/reload` may be needed for internal failures.

## Import / Export

Choose Current class or All saved settings and Export; select text and Ctrl+C. The addon does not claim direct clipboard access. Paste and Import to validate/review; Confirm commits, Cancel preserves settings. Restore backup reviews the last pre-import snapshot. Closing/entering combat cancels pending drafts and confirmation.

Only user settings transfer. Class/spec identities are preserved: Mage import on Warrior saves Mage data without converting Warrior appearance. All-settings includes window placement/animation and validated minimap visibility/angle. Current-class excludes shell settings. Older strings without minimap fields preserve icon preferences. Proc artwork uses format 1 and schema 5 with strict catalog keys and bounded values; no texture path or arbitrary FileDataID can be imported. Included regions without artwork settings clear their old overrides. An included scope without a strategy returns to legacy replacement; independent regions need explicit enablement. Local edits that omit a field preserve its value. Import, Restore and Reset perform necessary policy cleanup before committing, and failed cleanup preserves the old configuration and recovery ownership.

## Features and limits

Mobility shows true next recovery when an admitted skill is depleted, hiding on the first recovered use. Proc keeps native-bound digits for admitted mappings; not every reviewed spec has an eligible timer. Free move is Time Spiral's receiving effect, text-only. Native interfaces retain secret state/timing; no fabricated fallback seconds or manual cast counting.

The author reported four P1 checks passing onsite for MAGE / 62, Retail build 69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`. This limited client confirmation is separate from offline tests. WARLOCK and final-RC font/SharedMedia, Mobility, Free move and integration checks remain pending. It does not certify every class/talent/collector/locale, language quality or client CPU/memory. Exact acceptance scope and final extracted-installer results belong to the repository records and this package's adjacent delivery report/checksum.

[Source and documentation](https://github.com/TomXingCan/CarGOUI). Current project-owned source from the ARR LICENSE cutover is All Rights Reserved; official distributions may be installed and run for personal gameplay. The previously released v1.0.0 remains GPL-3.0-only as originally distributed, and its granted GPL rights are not revoked. The unchanged 1.0.0 development version string does not identify the historical release. Branding artwork remains All Rights Reserved and embedded libraries retain original terms. See LICENSE, NOTICE.md and Media/Branding/LICENSE.txt. The installer contains runtime files; tests and production records stay in the repository.
