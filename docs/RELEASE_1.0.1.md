# CarGOUI 1.0.1 — release notes

CarGOUI 1.0.1 adds SharedMedia font support, the Modern CUI settings interface
and opt-in independent Proc artwork for WoW Retail 12.1 / Interface 120100.
Existing native Timer bindings, Mobility, Time Spiral Free move, saved settings,
launchers and combat-safe Options behavior remain part of the release.

## Changes

- Correct font selection and consume fonts registered through LibSharedMedia.
  Save logical font preferences and keep compatible client fallback when a
  provider is missing, without packaging third-party font files.
- Use a shared Options shell and controls, precise inline numeric editing,
  separate Timer/artwork color editing, and contextual Proc Test/Stop actions.
- Offer an audited catalog of Blizzard client artwork and separate region
  tint, alpha, scale, transforms and animation preferences. The catalog stores
  client FileDataIDs; Blizzard texture files are not redistributed.
- Add independent artwork driven by valid public Spell Alert events, separate
  from native Aura duration bindings and native artwork ownership.
- Preserve settings through strict schema 5 / transfer format 1 validation.
  Strategy edits, import, restore and reset clean old artwork before policy
  changes commit; a cleanup failure leaves settings unchanged and retains the
  unresolved owner for recovery.
- Bound Proc resource ownership and diagnostics, isolate repeated Proc
  failures, and provide explicit Retry/Reload recovery for that Proc subset.

## Two supported Proc paths

**Blizzard Native + Timer** preserves Blizzard artwork and CarGOUI's existing
native-bound Timer. Old settings do not automatically enable independent
artwork.

**Independent CUI + Timer** uses CUI-owned artwork with the same native-bound
Timer. Keep Proc enabled, select **Artwork strategy → Independent CUI**, enable
the live artwork master, and explicitly enable each desired region. The
artwork master and region switches do not disable Timer.

Manually set Blizzard **Spell Alert Opacity** to zero. Live independent artwork
requires both `spellActivationOverlayOpacity=0` and
`displaySpellActivationOverlays=0`. CUI never writes either CVar. When either
value is unavailable or nonzero, independent artwork pauses with a notice;
Timer and saved preferences remain intact.

Global zero hides **all** Blizzard Proc artwork, including uncovered sources,
and cannot preserve a genuinely Native side. **Restore Blizzard Spell Alert
Opacity manually when native alerts are needed.** Turning artwork or Proc off,
switching strategy/spec, or quarantine never restores that game setting.

Existing legacy modes, selected assets, tints, transforms and animation values
are retained. Independent rendering uses the visual preferences without
activating the old mode. Legacy per-region Custom replacement and Timer Only
suppression are unavailable in 1.0.1; retained modes have no native takeover
authority. Their first-SHOW/consumption exposure defects are not declared fixed.

A strategy change clears old graphical state. A buff already present needs a
new valid public SHOW before independent artwork appears; native Timer
bootstrap and TEST do not fabricate that event. TEST uses separate marked
samples and does not establish live event delivery or native duration behavior.

## Author confirmation and remaining limits

The author reported four P1 checks passing onsite for MAGE / 62, Retail build
69933, source `bc91f3fe975e059fda2196cb4b6d75d40e371006`: normal first
acquisition/consumption/reacquisition/ending, Timer independence from artwork
switches, cold startup with saved independent settings, and pausing artwork
when nonzero Blizzard opacity is restored. The
[acceptance record](PROC_INDEPENDENT_ACCEPTANCE.md) retains their exact scope.

The author subsequently confirmed completion of the final RC checks for
`9bef4c3b654c4a45a705b74cb1b0a46431367ace` and explicitly authorized formal
1.0.1 delivery. This is **author confirmation**, not agent-run client testing
or a new set of instrumented measurements. No per-item timing/memory figures,
all-class acceptance matrix, or universal locale/collector certification is
inferred from that confirmation.

The [#15 release-admission decision](PROC_MEMORY_RELEASE_REVIEW.md) permits
this release; it does not establish a permanent leak, identify a unique cause,
or prove that memory growth has been fixed. Stable addon resource counts and
offline allocation tests are not native-client memory measurements. Existing
evidence and its limits remain available for follow-up.

Only the delivered diagnostics and **Proc** quarantine/recovery subset of
[#16](https://github.com/TomXingCan/CarGOUI/issues/16) is included. The broader
Reload-required settings framework is not complete. Class Tools production
features, its logger, research modules and external observer addons are excluded.

## Install or upgrade

Exit WoW and replace both **CarGOUI** and **CarGOUI_Data** in
`_retail_/Interface/AddOns/` with the folders from `CarGOUI-1.0.1.zip`. Each TOC
must sit directly inside its matching folder. Keep WTF/SavedVariables. No
settings reset or separately installed library addon is required.

Open Options with `/cui`, `/cargoui`, the minimap/LDB launcher or native AddOn
Compartment. Combat requests queue until unlocking. For Proc failures, copy
diagnostics with `/cui diagnostics copy`; `/cui proc retry` is explicit and
may require `/reload` when cleanup cannot safely complete. These actions do
not restore Blizzard's manual opacity setting.

An included old transfer scope without a strategy returns to the default
Native + Timer path through the legacy policy value; its inactive legacy mode
data remains separate from release behavior. Included independent regions need
explicit enablement. Local edits that omit a field preserve its value. Older
strict importers may reject the new optional fields safely. Schema 5 and
transfer format 1 remain unchanged.

## Artifact verification

The formal package is `CarGOUI-1.0.1.zip`, with matching 1.0.1 versions in both
addon TOCs and `addon.version`. The adjacent `.sha256` and verification report
identify its exact bytes, source commit/tree and actual source/extracted-package
test results. Use those final records rather than an earlier RC checksum,
historical test count or an unmeasured result in this document.

The installer contains only the two addon roots, TOC-declared Lua, required
branding TGAs, the concise user README/changelog and project/third-party
notices. Tests, development documents, scripts, source art, research and
standalone observers remain outside the installer. Frozen earlier RCs and
the historical v1.0.0 assets are unchanged.

## License

Current project-owned source, including 1.0.1, follows the existing
**All Rights Reserved** cutover in [LICENSE](../LICENSE). Official distributions
may be installed and run for personal gameplay under those terms. This release
does not make a new relicensing decision.

The historical v1.0.0 remains **GPL-3.0-only as originally distributed**; its
tag, Release, installer and granted rights are unchanged. Branding is separately
All Rights Reserved. Embedded libraries retain their original terms and notices,
including LibSharedMedia's source-declared LGPL 2.1, complete license text and
the stated library replacement/modification/debugging rights. See
[NOTICE](../NOTICE.md) and [third-party notices](../Libs/THIRD_PARTY_NOTICES.md).
