> Alpha.9 update: Options now drags from all non-interactive backgrounds, Header is faction-only and Body is spec-themed; runtime package is CarGOUI_Data. See [UPGRADE_ALPHA9.md](UPGRADE_ALPHA9.md) and [LOAD_BOUNDARIES.md](LOAD_BOUNDARIES.md). Older header-only/module descriptions below are historical.

> Current alpha.8 configuration/loading changes: [CONFIG_SCOPES.md](CONFIG_SCOPES.md) and [LOAD_BOUNDARIES.md](LOAD_BOUNDARIES.md). Historical per-entry/global configuration paths below are superseded. Mage business files now reside in Modules/CarGOUI_Mage.

# Alpha 0.1 — Options, Test Mode, branding and Mage Mobility

This historical phase extends the existing standalone Options frame and `UpdateSettings` pipeline. Its UI remained English, including zhCN clients; version 1.0.0 later superseded that policy with automatic client-language localization. `/cui` is primary; `/cargoui` resolves to the same slash handler.

Alpha.7 preserves the user-confirmed Blink/Shimmer combat path and adds [independent appearance](ENTRY_STYLES.md) and [automatic Options themes](THEMES.md). `SpellState.lua` is unchanged; Runtime passes the already-known spell ID to the renderer so Blink/Shimmer styles remain distinct without changing their existing position IDs. This release's client appearance/regression acceptance is still pending.

## Interaction and persistence

The X/Y pair is committed on Enter in either field. Validation runs on the complete patch before any database field is changed. Scale/font size sliders apply immediately; their text fields apply on Enter. Removing Apply buttons allowed wider position fields and sliders. Draft text stays in the controls, never in SavedVariables; close/category changes clear it.

Schema 4 extends the same `CarGOUIDB` (the existing schema 2 fields are retained):

| Field | Purpose |
| --- | --- |
| `position` | Common reminder offset from each entry's base anchor |
| `reminders[id].position` | Independent offset for a defined reminder/visual region |
| `options.position` | Options window offset from UIParent center |
| `options.animatedTitle` | Native title animation preference, default true |
| `mobility.enabled` | Mage live module preference, default true |
| `styles[key]` | Independent font, shadow and scale per actual Mobility spell / defined Proc region |

Missing/new fields are defaulted and malformed values normalized through the existing shared schema. Existing fonts, display offsets, appearance, and unknown saved keys are preserved. Reset all settings is explicit and confirmed in the GUI.

Only `panel.header` registers left-button drag handlers. It moves the unprotected parent Options frame with `StartMoving`/`StopMovingOrSizing`; other controls have no drag handlers. The panel is clamped to screen. Drag end converts its center to UIParent coordinates using the effective-scale ratio, then stores `options.position` through `UpdateSettings`. Closing mid-drag stops and saves it. Restoring divides the saved offset by the panel's local scale; reopening recalculates panel fit for the current viewport. None of this changes reminder positions.

## External simulation and live rendering boundary

`Database/PreviewEntries.lua` contains a small Mage-only simulation catalog, not real detection rules. Specialization lookup selects eligible entries. Every separate Proc region has a stable ID, including the two separate Fingers of Frost source rows.

`UI/Display.lua` exposes `AcquireReminderFrame(entry, channel)` and the sample-only `RenderReminder(frame, entry, content, testMode)`. `LayoutReminder` applies shared font/shadow/scale/position and per-region offsets. Live `RenderLiveMobility` uses a separate native DurationTextBinding and fixed dimensions from ordinary font settings; it never sends opaque timing through Lua concatenation, empty-string checks, or text measurement. Native formatting owns zero/expired empty text, a 0.1-second update interval and RealTime rate handling. There is no always-visible login placeholder.

`UI/ReminderStyle.lua` copies the current Blizzard class RGB into a session-only cache keyed by UnitClass token. Both live and Preview FontStrings use SetTextColor; no global font/color table or saved color setting is modified. World entry refreshes existing frames and retries initialization fallback independently of whether the Mage runtime is enabled. Font/layout changes preserve this color and never overwrite the live parent frame's native alpha. Continuing state refreshes do not first clear/hide its binding; obsolete/suppressed output is still disabled explicitly.

`UI/Preview.lua` owns transient `previewState` and the `preview` frame pool. `SetPreview('single', id)` or `SetPreview('all', id)` renders fixed sample data for the current spec in UIParent. No samples are written to SavedVariables or a real reminder state. Starting with an invalid mode, closed Options, or an unavailable entry is rejected. The `enabled` preference gates sample visibility.

Test-only guidance uses the client's existing shape texture by file ID, a faint tint, crosshair marks and an explicit TEST label. Proc guides remain at the stock Blizzard anchor and inverse-scale against text scaling; offsets move the timer relative to that stationary visual reference. None of those decorations is part of the non-test Proc renderer. No Blizzard overlay events, sounds, aura reads, or cooldown reads are fabricated.

`StopPreview` hides cached frames/guides, removes its spec/combat subscriptions, and refreshes live state from the APIs. Options closes stop preview and title animation, discard draft input/focus, close menus, and remove the window's own temporary spec listener; the enabled live module retains its own callbacks. Reopening does not restart Test Mode. Switching categories keeps external samples active so appearance can be edited while viewing them. Starting a sample suppresses live rendering only for that region while real synchronization continues. Combat stops samples and forbids restarting them; live remains active within its API limits. Unsupported specs show an explanation and disabled test controls; unspecialized Mages have a Mobility entry.

Sample timer strings remain fixed, so samples have no timer tick, OnUpdate or polling. The live runtime combines event bursts with one cancellable `C_Timer.NewTimer(0, callback)` task; this is not recurring polling. Native bindings update their own text. No cooldown tick refreshes the entire Options panel or title. Pools, bindings and controls are reused.

`Database/MobilityEntries.lua` contains only Blink/Shimmer and four position mappings. `Modules/Mobility/SpellState.lua` resolves current knowledge/overrides and validates public state; `Runtime.lua` owns event synchronization, a safe diagnostic allowlist and preview suppression. Three existing `mage_*_shimmer` IDs are retained for either live spell; `mage_unspecialized_mobility` is additive. No transient count or duration object is saved, and no Proc visual source ID becomes a live aura rule.

## Proc geometry sources and limits

The catalog pins the extracted **12.1.0.69587 client data** and Blizzard renderer source:

- [SpellActivationOverlay table](https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/spellactivationoverlay.csv)
- [ScreenLocation table](https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/screenlocation.csv)
- [Blizzard SpellActivationOverlay renderer](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua)

Stock scale-1 regions use long side `256 * 0.8`, short side `128 * 0.8`. Side centers are X = ±153.6; top center is Y = 153.6. Side/right texture orientation is retained. These anchors are defaults for stock Blizzard layout; third-party overlay relocation/scaling needs manual offset calibration and is not detected. Real-client visual alignment still needs acceptance testing.

## Lightweight brand header

`UI/Branding.lua` now renders a separate transparent artwork wordmark and compact emblem based on the user's supplied logo. One native AnimationGroup translates a narrow highlight through a fixed glyph mask over 1.5 seconds, then rests for 5 seconds. The wordmark/emblem themselves stay static and independent of reminder typography. It plays only while Options is actually visible, Animated title is enabled, and the player is out of combat. Closing/disabling stops it, clears the highlight and releases combat listeners. There are no Lua animation callbacks or decorative OnUpdate scripts.

`Media/Branding/` includes four 32-bit uncompressed runtime TGA files (606,280 bytes), production PNG sources, full generation prompts, and a reproducible converter. The PNG sources stay in the repository and are excluded from the install ZIP. [Asset mapping/provenance](../Media/Branding/README.md) records the supplied reference and processing. [Branding implementation](BRANDING.md) documents the native masking APIs, object budgets, explicit glyph-pulse fallback and outstanding client checks. No Curse promo content is made in this increment.

## Verification and remaining scope

The alpha.4 baseline had 37 Lua 5.1 mock tests covering interaction, persistence, title visibility/combat lifecycle, reuse, assets and external preview. Phase 2A retains meaningful coverage and adds charge transitions, real-state adapters, missing/secret data, native binding boundaries, event lifecycle, migration and preview/live separation. See the delivery test report for final counts, install-ZIP hash and tests run against the actual extracted package. Ordinary Lua mocks do not fully reproduce Blizzard secret values, taint or native rendering.

The user has viewed the prior UI in-game and accepted its general appearance. This does not establish acceptance of the new live skill logic, native timer, combat restrictions, all visual scales or region alignment. This phase has no real-client testing environment.

Real Proc/aura detection, other classes and spells, Evoker Free move, manual theme switching and import/export remain unimplemented. Multiple secret charges now have a native visibility path subject to documented API/metadata prerequisites and outstanding real-client semantic acceptance. No fixed countdown, cast ledger, secret arithmetic or native-display readback substitutes for actual state.

## Entry style and theme boundaries

Schema 4 deep-copies validated legacy typography once into missing style fields, preserving existing independent values. After migration, factory defaults fill new/missing entries; renderers never multiply or inherit legacy global scale. Styles-only edits update matching cached frames without cooldown reads, duration rebinding or opacity changes. The native live frame and FontString dimensions derive from that entry's font size. Preview-only Proc settings use the existing catalog, with no new spell mappings.

Options replaces the global typography/scale controls with a per-entry Appearance editor reached from Mobility or Proc. Draft numbers are cleared on selection changes. Themes is a readonly Automatic identity page; visible-only theme callbacks coexist with Mobility callbacks and use native static gradients. The branded wordmark, title animation switch and combat-stop behavior are retained.
