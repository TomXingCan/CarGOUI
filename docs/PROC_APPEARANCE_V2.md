# Proc Appearance v2: architecture and acceptance

This presentation extension is developed from `f40b854e04ffe13914e1669eba4f37bbfb23068c` for issue [#7](https://github.com/TomXingCan/CarGOUI/issues/7). It retains schema 5, settings-transfer format 1, and both production TOC versions at 1.0.0. It does not restore Class Tools or constitute a release. Offline validation does not replace actual Retail-client acceptance.

## Separate responsibilities

| Component | Authority and ownership |
| --- | --- |
| Trigger | Existing audited Proc definitions and public SPELL_ACTIVATION_OVERLAY_SHOW/HIDE lifecycle. No new trigger inputs. |
| Timer | Existing native helpful-Aura slot and native duration binding. Specialization-wide typography, per-region timer RGB and XY. |
| Native artwork | Blizzard's stock graphic and animation. The default mode does not suppress or rewrite it. |
| Custom artwork | A CarGOUI-owned frame and texture, using an audited client FileDataID. All transforms and AnimationGroups belong to this presentation. |
| Asset catalog | Metadata derived solely from the already audited source definitions. Cross-class artwork selection grants no trigger or timer support. No texture files or thumbnails are bundled. |
| Suppression | A separately recorded, reversible `nativeOverlay.texture:SetAlpha(0)` for a positively identified current region; release always writes `SetAlpha(1)`. |

No arbitrary SpellID editor, UNIT_AURA guessing, combat-log reconstruction, rotation recommendation, external texture path, or SharedMedia texture source is added. SharedMedia remains a font facility only.

## Saved representation and finite limits

```lua
classes[classToken].proc[specID].regions[stableRegionID] = {
    position = { anchor = "CENTER", x = 12, y = -6 }, -- Timer only; unchanged.
    color = { r = 1, g = .8, b = .2 }, -- Timer only; unchanged.
    appearance = {
        mode = "custom", -- native, custom, timer
        -- assetKey omitted: this Proc's own audited native artwork.
        -- artColor omitted: public Blizzard SHOW RGB.
        alpha = 1, desaturation = 0,
        scale = 1, width = 1, height = 1, rotation = 0,
        mirrorX = false, mirrorY = false,
        offset = { x = 0, y = 0 }, -- Artwork only.
        animation = { entrance = "none", active = "none", exit = "none",
            speed = 1, intensity = .2, direction = "clockwise" },
    },
}
```

The example is descriptive, not an eagerly populated default. Sparse appearance objects are valid; the pure resolver completes defaults in detached tables. Missing or invalid saved appearance resolves safely to Native. Existing position/color-only records are not rewritten with a new appearance object. No schema migration is introduced.

| Field | Allowed values / bounds | Default |
| --- | --- | --- |
| mode | native / custom / timer | native |
| assetKey | An existing stable audited catalog key, or omission | Own native asset |
| artColor | Complete finite `{r,g,b}`, each 0–1, or omission | Public SHOW RGB |
| desaturation / alpha | 0–1 | 0 / 1 |
| scale / width / height | 0.25–3 each | 1 |
| rotation | -180–180 degrees | 0 |
| mirrorX / mirrorY | Boolean | false |
| offset.x / offset.y | -1000–1000 UI units each | 0 |
| animation.entrance | none / fade / scale / pulse | none |
| animation.active | none / pulse / breathe / rotate | none |
| animation.exit | none / fade / scale | none |
| animation.speed | 0.25–3 | 1 |
| animation.intensity | 0–1 | 0.2 |
| animation.direction | clockwise / counterclockwise | clockwise |

`Reset artwork to Blizzard default` removes only the selected region's optional `appearance`. Timer color, timer position, shared typography and Proc enabled state survive. The existing style reset still resets Timer typography.

## Audited catalog and geometry

`Database/ProcAssets.lua` is an inert metadata catalog: **44 entries / 44 unique FileDataIDs**, retaining **77 source references**. Each unique client FileDataID has one stable `blizzard_<FileDataID>` key and retains all audited source relationships: class, specialization, Proc identity/name, graphical owner, timer Aura, source location and native scale. Repeated use by several specs does not create redundant gallery items. Tests compare the catalog back to all admitted source factories, including alternate graphical stages. No runtime scan or activation of another class is required for browsing.

Custom geometry starts at the current target region's native visual center, using the audited 204.8/102.4-unit overlay layout, stock root layout scale and public SHOW scale. It supports Left, Right, LeftOutside, RightOutside, Top, Bottom, Center, TopLeft and TopRight. The timer's saved position never becomes the artwork's anchor. An independently selected asset contributes its native dimensions and recommended scale; user overall scale and width/height multiply those dimensions. Target right/bottom orientation supplies the native base flip, and user mirrors toggle it additionally.

## Native lifecycle and fail-open ownership

The current Retail source audit on 2026-09-28 resolves to mirror commit [`09b9db7948abc9b9648dedaab51eb0cf3ee67b31`](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua), dated 2026-09-22. `ShowAllOverlays` expands compound locations into simple `ShowOverlay` calls. `ShowOverlay(spellID, texturePath, position, scale, r, g, b)` assigns public owner/position metadata to `overlaysInUse[spellID][position]`. `ReleaseOverlay` removes that index and returns the frame to its pool. The post-hook restores the owned texture's alpha synchronously before another acquisition. This audit authorizes a narrow presentation path, not unrestricted access to the native hierarchy or a claim of client taint acceptance.

The renderer hooks public stock `ShowOverlay` and `ReleaseOverlay` methods. Both hooks must be ready before any replacement is allowed; a partial hook-install failure remains fail-open. A SHOW is eligible only when its public owner, audited source texture, simple location and current class/spec stable region agree. It captures the corresponding stock object from the audited manager's in-use index; it does not enumerate unrelated children or infer activity from native alpha. Compound locations are matched through their stock simple-region calls.

The native object is never assigned a replacement file, vertex color, texcoords, anchors, dimensions, animations or global alpha. The only permitted native texture mutation is alpha 0 for owned suppression and alpha 1 for restoration. Blizzard's root alpha and both overlay CVars are never written. Native alpha is never read to decide state.

Mode changes to Native, disabling Proc, StopProc, spec/context rebuilds (including same-spec talent-catalog changes), world resynchronization, configuration reset, native object release and renderer failures restore all affected owned suppression. Release restoration happens before the pooled object can be reused. A normal public HIDE runs the owned exit animation but retains suppression until native ReleaseOverlay, preventing a stock fade-out graphic from reappearing behind the finished custom exit. Missing/ambiguous matching, invalid public color, unavailable rendering or unsupported geometry leave or restore Blizzard artwork; live Custom becomes unavailable rather than drawing a duplicate replacement. Other audited or unaudited Blizzard Procs are unaffected unless they independently match the selected current region.

Custom requires the original public graphical lifecycle as well as safe native ownership. Native Aura bootstrap is not proof that a stock graphic exists; the artwork renderer never synthesizes a live SHOW from a timer slot. The Timer remains governed by its existing verified native Aura binding.

Public SHOW RGB is 0–255 and is normalized to 0–1. Native-color Custom requires valid agreeing RGB from the event and native lifecycle hook; a repeated SHOW with invalid RGB cannot reuse an older callback's color. It does not read `GetVertexColor`, Aura payloads or restricted widgets. Preview uses a documented neutral white sample when no live RGB is available. Custom RGB affects the owned texture alone.

`displaySpellActivationOverlays` continues to gate artwork. Custom effective alpha is `spellActivationOverlayOpacity * appearance.alpha`. Existing Timer opacity semantics are retained. Changes use public CVar notifications; there is no CVar write or polling loop.

## Rendering and animation lifecycle

Live and TEST use the same appearance resolver with independent bounded frame/texture pools. Test Mode never invokes Blizzard SHOW or owns/restores a native overlay. Native TEST renders a mapped sample; Custom TEST renders the selected client FileDataID; Timer Only creates no custom artwork. Stop/close/combat/context changes clear preview objects independently of live presentation.

Only addon-owned artwork receives native AnimationGroups. Entrance presets are None, Fade In, Scale In and Pulse In; active presets are None, Pulse, Breathe and Slow Rotate; exit presets are None, Fade Out and Scale Out. Speed, intensity and rotation direction are bounded. Groups/animations are created once per owned renderer and reused across SHOWs. Config/mode changes stop active groups and reset visual transforms before applying new values. Exit completion hides the owned artwork. There is no addon OnUpdate or ticker, and no animation of native Blizzard children.

Appearance-only edits call the targeted presentation refresh. They do not query Auras/cooldowns, rebuild native slots, rebind duration text, change Timer alpha or change trigger catalogs.

## Region Editor and gallery

The Proc page selects the current specialization, one Proc and one stable region. Native shows Display Mode, Timer and Position/Test controls. Custom also shows Artwork, Transform and Animation; Timer Only hides artwork controls. Basic exposes selection, color, alpha, overall scale and animation presets. Advanced is collapsed by default and stores expansion only in the UI session, exposing desaturation, independent dimensions, rotation, mirrors, artwork offsets and animation tuning.

The gallery shows at most nine direct client-texture thumbnails per page, with source-class filtering, Previous/Next navigation, friendly source labels and selected indication. Tooltips contain source class/Proc, native location and FileDataID. Normal choices are not named by FileDataID. The current Proc's own artwork is a separate omission/default choice. No PNG thumbnails or packaged Blizzard image files are generated.

Timer typography links to the existing Appearance editor, shared across the current specialization. Timer RGB and artwork RGB are labeled separately and are per selected region. Position/Test retains the existing timer-coordinate workflow; Advanced artwork XY is explicitly separate.

## Transfer and diagnostics

Settings Transfer strictly whitelists appearance fields, enums, catalog keys, RGB, finite ranges, booleans, offsets and animation values. Raw FileDataIDs, texture paths and filenames are rejected. Exports are deterministic. An included old region without `appearance` clears a previous custom appearance and becomes Native. Untouched regions/classes/specs retain their settings. New appearance fields require a compatible importer; the old strict importer may reject them safely. Schema and wire format versions stay unchanged.

Proc diagnostics report each stable region's mode, selected asset, renderer readiness/unavailability, owned/not-owned native suppression and a bounded fail-open reason. They contain public presentation state only, not secret combat or Aura data.

## Required real-client acceptance

Offline verification uses an existing actual Lua 5.1 runtime through `lupa.lua51`; it does not install dependencies or substitute LuaJIT/another Lua version. Run:

```sh
python tests/run_tests.py
python tests/check_launcher_static.py
python tests/check_localization_static.py
python tests/check_mobility_static.py
python tests/check_proc_static.py
python tests/check_settings_transfer_static.py
python tests/check_styles_theme_static.py
python -B -m unittest discover -s .github/scripts -p 'test_*.py' -v
```

The appearance suites are loaded by the full runner: `proc_appearance_data.lua`, `proc_appearance_renderer.lua` and `proc_appearance_options.lua`. Existing timer, Mobility/Free move and font/LibSharedMedia assertions remain in the full regression suite. The legacy all-region editor test now selects the owning Proc before selecting a region, matching the new two-step editor; its original timer assertions are unchanged. Native texture mocks reject all mutation/readback methods except the two allowed alpha writes, and independent event/hook order fixtures cover color freshness.

The offline tests model stock ownership and native APIs; they cannot certify taint, protected access or actual client rendering. Record client version/build, locale, class/spec/talents and exact revision for these checks:

1. Upgrade a position/color-only 1.0.0 SavedVariables file. Verify identical Native graphics and timer position, RGB, font and text scale before any editing.
2. Exercise real Proc SHOW/HIDE, compound sides, alternate stages and concurrent unrelated overlays. Test Custom and Timer Only, then switch to Native, disable Proc, change spec, reset, reload and recycle a released stock object. No missing or doubled graphics and no alpha leakage into another Proc are allowed.
3. Verify native RGB, explicit RGB, desaturation, both CVar states, opacity extremes and missing/restricted public RGB. Failure must keep the stock graphic visible.
4. Check all nine supported locations with root/UI scaling, per-region timer XY, artwork XY, selected asset geometry, scale, width/height, rotation and extra mirrors. Right/bottom native symmetry must survive default mirror settings.
5. Run every entrance/active/exit preset and tuning extreme; rapidly retrigger and change mode/config during animation. Check transform reset, pooled-object reuse and absence of visual residue.
6. With a simultaneous real Proc, start/stop Native, Custom and Timer Only TEST. Preview must neither suppress nor restore the live object. Close, combat and context changes must clean only their own lifecycle.
7. Browse all gallery pages and class filters, choose a cross-class asset, and test long labels/eight locales, scrolling, keyboard focus, picker cancellation and advanced disclosure. Confirm clear Timer/artwork ownership and readable layout.
8. Round-trip old/new native client `C_EncodingUtil` strings, including all saved specs, backup restore and artwork-only reset. Check invalid keys/paths are rejected before commit.
9. Regress Proc timer refresh/consumption/expiry and shared fonts/LibSharedMedia recovery, Mobility depletion and Free move independence. Capture taint/error logs and actual CPU/memory deltas over repeated SHOW/spec/preview cycles.

Keep the PR unmerged until review and any separately required client acceptance. No release/tag or publisher run is authorized by this development change.
