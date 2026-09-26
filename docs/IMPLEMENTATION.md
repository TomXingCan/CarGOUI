# Alpha 0.1 — Options, external Test Mode, branding

This phase extends the existing standalone Options frame and `UpdateSettings` pipeline. All UI remains English, including zhCN clients. `/cui` is primary; `/cargoui` resolves to the same slash handler.

## Interaction and persistence

The X/Y pair is committed on Enter in either field. Validation runs on the complete patch before any database field is changed. Scale/font size sliders apply immediately; their text fields apply on Enter. Removing Apply buttons allowed wider position fields and sliders. Draft text stays in the controls, never in SavedVariables; close/category changes clear it.

Schema 2 extends the same `CarGOUIDB`:

| Field | Purpose |
| --- | --- |
| `position` | Common reminder offset from each entry's base anchor |
| `reminders[id].position` | Independent offset for a defined reminder/visual region |
| `options.position` | Options window offset from UIParent center |
| `options.animatedTitle` | Native title animation preference, default true |

Missing/new fields are defaulted and malformed values normalized through the existing shared schema. Existing fonts, display offsets, appearance, and unknown saved keys are preserved. Reset all settings is explicit and confirmed in the GUI.

Only `panel.header` registers left-button drag handlers. It moves the unprotected parent Options frame with `StartMoving`/`StopMovingOrSizing`; other controls have no drag handlers. The panel is clamped to screen. Drag end converts its center to UIParent coordinates using the effective-scale ratio, then stores `options.position` through `UpdateSettings`. Closing mid-drag stops and saves it. Restoring divides the saved offset by the panel's local scale; reopening recalculates panel fit for the current viewport. None of this changes reminder positions.

## External simulation and future rendering boundary

`Database/PreviewEntries.lua` contains a small Mage-only simulation catalog, not real detection rules. Specialization lookup selects eligible entries. Every separate Proc region has a stable ID, including the two separate Fingers of Frost source rows.

`UI/Display.lua` exposes `AcquireReminderFrame(entry, channel)` and `RenderReminder(frame, entry, content, testMode)`. The renderer receives content from its caller and applies the same global font/shadow/scale/position and per-region offsets for every channel. Proc content is timer text only; Mobility supports a message plus timer. There is no always-visible login placeholder.

`UI/Preview.lua` owns transient `previewState` and the `preview` frame pool. `SetPreview('single', id)` or `SetPreview('all', id)` renders fixed sample data for the current spec in UIParent. No samples are written to SavedVariables or a real reminder state. Starting with an invalid mode, closed Options, or an unavailable entry is rejected. The `enabled` preference gates sample visibility.

Test-only guidance uses the client's existing shape texture by file ID, a faint tint, crosshair marks and an explicit TEST label. Proc guides remain at the stock Blizzard anchor and inverse-scale against text scaling; offsets move the timer relative to that stationary visual reference. None of those decorations is part of the non-test Proc renderer. No Blizzard overlay events, sounds, aura reads, or cooldown reads are fabricated.

`StopPreview` hides cached frames/guides and removes its spec-change subscription. Options closes stop preview and title animation, discard draft input/focus, close menus, and remove the window's own temporary spec listener. Reopening does not restart Test Mode. Switching categories keeps external samples active so appearance can be edited while viewing them. Unsupported specs show an explanation and disabled test controls.

The timer strings are fixed samples, so there is no timer tick, OnUpdate or polling. Rendering runs on explicit actions/settings changes or specialization events; pools and controls are reused.

## Proc geometry sources and limits

The catalog pins the extracted **12.1.0.69587 client data** and Blizzard renderer source:

- [SpellActivationOverlay table](https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/spellactivationoverlay.csv)
- [ScreenLocation table](https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/screenlocation.csv)
- [Blizzard SpellActivationOverlay renderer](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua)

Stock scale-1 regions use long side `256 * 0.8`, short side `128 * 0.8`. Side centers are X = ±153.6; top center is Y = 153.6. Side/right texture orientation is retained. These anchors are defaults for stock Blizzard layout; third-party overlay relocation/scaling needs manual offset calibration and is not detected. Real-client visual alignment still needs acceptance testing.

## Lightweight brand header

`UI/Branding.lua` now renders a separate transparent artwork wordmark and compact emblem based on the user's supplied logo. One native AnimationGroup translates a narrow highlight through a fixed glyph mask over 1.5 seconds, then rests for 5 seconds. The wordmark/emblem themselves stay static and independent of reminder typography. It plays only while Options is actually visible, Animated title is enabled, and the player is out of combat. Closing/disabling stops it, clears the highlight and releases combat listeners. There are no Lua animation callbacks or decorative OnUpdate scripts.

`Media/Branding/` includes four 32-bit uncompressed runtime TGA files (606,280 bytes), production PNG sources, full generation prompts, and a reproducible converter. The PNG sources stay in the repository and are excluded from the install ZIP. [Asset mapping/provenance](../Media/Branding/README.md) records the supplied reference and processing. [Branding implementation](BRANDING.md) documents the native masking APIs, object budgets, explicit glyph-pulse fallback and outstanding client checks. No Curse promo content is made in this increment.

## Verification and next runtime phase

37 Lua 5.1 mock tests pass, including paired validation, pending text, header-only dragging, scale-aware position persistence, title visibility/combat/static lifecycle, 20-cycle resource reuse, art/mask alignment and fallback, external single/all previews, fixed region guidance, class/spec changes, distinct renderer channels, and rejection of live state reads/polling. TGA format, power-of-two dimensions, alpha, payload and decoding checks pass. The header has been inspected in an offline asset composition; this is not an in-game screenshot.

Real Retail 12.1 rendering, templates, pointer interactions, client texture IDs, UI scaling and region alignment remain untested in-game. See the README acceptance steps.

The next real Mobility/Proc phase still needs talent/learned-spell eligibility, player cooldown/charge and aura event adapters compliant with Retail API restrictions, real state lifetimes/expiration handling, and coverage for the remaining spells/classes. Those adapters should pass independent real state into the existing rendering boundary. Theme switching and import/export also remain unimplemented.
