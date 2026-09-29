# Modern CUI shell foundation

This implements [#13](https://github.com/TomXingCan/CarGOUI/issues/13), the 1.0.1 foundation slice of [#11](https://github.com/TomXingCan/CarGOUI/issues/11). It is stacked on Proc Appearance v2 [#12](https://github.com/TomXingCan/CarGOUI/pull/12), starting exactly at `cb1a40cf8daad77fdfdad4a9a19c1aac6025dffd`. Its initial PR base is `feat/1.0.1-proc-appearance-v2`, not `main`. Neither PR is merged by this work. Retargeting/rebasing belongs to a later step after #12 merges.

## Stable shell and layout

The shell separates a compact branded Header, one global Sidebar, a shared main-content container, and a status/action Footer. The base panel is 900 by 640 UI units. Header height is 76; Sidebar width is 192. Main content begins at x=216, y=100 with 24 units of right padding, giving a 660 by 460 content area. The Footer reserves 64 units. A full-width section's 12-unit interior padding on each side leaves 636 units for its editor. Proc's scrolling viewport and cards are 640 units wide, with a 616-unit editor interior and room for the owned scrollbar. Content owns native scrolling instead of extending beyond the window.

Whole-panel scale is capped at 1 and fits the current UIParent dimensions with an outer screen margin. Scaling and screen clamping run on explicit open/display/scale boundaries, never a polling loop. Existing saved Options XY remain in UIParent units and retain their original ownership; transient fit/clamp decisions do not become a new preference. Native current-pointer dragging, release cleanup and the existing position reset remain available.

## Design system and identity

`UI/DesignSystem.lua` is the single source for graphite/charcoal surfaces, raised/hover/selected states, subtle/strong borders, readable primary/secondary/muted/disabled text, teal/cyan-to-blue-violet accents, restrained glow, success/danger feedback, spacing, control height, section gap, content padding and motion timings.

The gradient is a repeated system motif: Header accent, selected navigation and segments, enabled toggles, slider fill, dropdown selection/focus and gallery selection. It uses static native `Texture:SetGradient` with a solid-color capability fallback. There are no per-frame gradient calculations and no new image files. Existing original CarGOUI branding keeps its provenance and licensing boundary.

Automatic faction Header and class/spec Body identity remain separate concepts. Their colors/motifs become restrained identity layers inside the common design system, rather than independently repainting every control. There is no manual theme selector and no change to reminder colors or appearance ownership.

## Owned component layer

`UI/Controls.lua` exposes reusable CUI primitives built from native Frame, Button/CheckButton, EditBox, Slider, ScrollFrame, Texture, FontString and AnimationGroup APIs:

| Primitive | Behavior |
| --- | --- |
| Button | Primary, secondary, ghost and danger variants with hover, press, selected and disabled feedback. |
| Toggle | Owned track, accent fill and moving thumb; existing boolean save semantics. |
| Dropdown | Reused menu/rows, selected/focus accents, optional bounded pagination and guarded interaction. |
| Input | Owned raw EditBox skin with normal, hover, focus, invalid and disabled states; Enter still commits. |
| Slider | Custom track, gradient active fill, owned thumb and numeric field; existing validation remains authoritative. |
| Section | Consistent title/padding/accent divider; optional session-only collapse. |
| Segmented control | Reusable mutually exclusive choices, independent of Proc-specific semantics. |
| Scroll frame | Native vertical scrolling, wheel handling and a thin owned scrollbar. |
| Gallery tile | Reused client-texture thumbnail and explicit selection emphasis. |

The shared layer does not use `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate` or stock dropdown visual chrome. `BackdropTemplate` is only a structural capability. The component layer has no gameplay queries or direct SavedVariables access; page callbacks retain their existing setting validation and transaction rules.

### Native slider thumb contract

Both the horizontal slider and vertical scrollbar pass the neutral client primitive `Interface\\Buttons\\WHITE8X8` to `SetThumbTexture`, then obtain the slider-owned `SimpleTexture` through `GetThumbTexture` and apply CarGOUI size/color tokens. This fallback adds no binary asset and does not restore Blizzard slider artwork, templates or chrome. The [pinned Retail API documentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleSliderAPIDocumentation.lua) declares the setter's argument as `TextureAsset` and the getter's result as `SimpleTexture`; they are not interchangeable. The offline fixture rejects Texture objects and returns a reused texture owned by the receiving Slider, so it cannot conceal the previous signature mismatch.

## Motion and cleanup

Dropdown opening uses a reusable AnimationGroup with a 120 ms fade and 8-unit translation. Closing uses a 90 ms reverse transition and hides after completion. Outgoing rows are disabled immediately, including callback guards; transferring ownership to another menu cannot leave invisible clickable rows. Rapid open/close, page change and parent close settle existing groups without allocating another set of rows or animations.

Collapsible sections use two reusable 120 ms Alpha animation groups. Expansion reserves the expanded layout footprint and fades content from 0 to 1; collapse fades from 1 to 0 while retaining that footprint, then hides content and settles to the 42-unit header. Inputs remain locked during either transition and while collapsed, including focus, outgoing dropdowns and stale callbacks. The latest requested collapse state is session-only. `StopMotion` and parent `OnHide` stop both groups and settle immediately to that state, so rapid toggles and close/Esc/combat/page/spec boundaries cannot leave a half-open interactive editor. Proc Advanced uses this shared primitive and its completion callback to recompute the scroll range; it has no private animation engine.

Hover and toggle feedback use short native animation groups; presses use an immediate restrained surface change. No component uses OnUpdate, a ticker, or inertial-scroll simulation. Close, Esc, combat, page and specialization boundaries stop/settle UI-only motion and close menus. A completion callback cannot reopen Options or apply a setting. Closed Options has no menu animation, decorative polling or background UI ticker. Existing branding motion remains bounded to the visible Options lifecycle.

## Pages and future Class Tools

`UI/OptionsShell.lua` provides a descriptor registry with a stable key, order, title and builder. The navigation engine sorts descriptors deterministically, builds registered pages, applies selected state and supports hidden detail pages. Icons are an optional descriptor slot, not a requirement or another global navigation hierarchy.

Only actual production pages are registered. `classTools` is deliberately absent: there is no placeholder, disabled item or empty page. A future Class Tools descriptor can register without editing shell dimensions, Sidebar code, layout or navigation. It will use the existing main area and reusable segmented controls for Common Tools versus Spec Tools, followed by a tool selector and selected-tool editor. Future semantics remain current-class-only, class-scoped Common Tools and current-specialization-scoped Spec Tools. This PR implements none of those gameplay tools or settings.

Proc Appearance is the first fully composed modern page: automatic specialization context, Proc/Region selection, Display segments, Artwork, Transform, Animation, Timer, Position/Test and session-only Advanced disclosure. Native and Timer Only continue hiding irrelevant artwork controls. Timer typography remains a link to the existing editor. The audited gallery retains its filters, pagination, stable keys and direct client thumbnails.

The RC2 navigation contains General, Mobility, Proc and Import / Export. Typography and diagnostics remain contextual detail pages. There is no registered `preview` descriptor, Test Mode sidebar row, placeholder or allocated Test Mode page. `UI/Preview.lua` remains loaded: removing its navigation does not remove `SetPreview`, `StopPreview`, `RefreshPreview`, the separate sample pool or the existing live/TEST boundary. Import staging, confirmation, selection/copy, backup restore and unsubmitted-field semantics remain intact.

### RC2 page responsibilities and contextual testing

General contains only app-level concerns, grouped into Current Character / Quick Test, Interface and Window cards. It shows current class/spec context, Test Current Spec and Stop Test, minimap visibility, animated-title preference and window centering. It has no Mobility enable switch or Mobility XY editor, and it introduces no global Enable CarGOUI preference.

Test Current Spec calls the existing `SetPreview("all")` for the entries defined in the current context. Mobility calls `SetPreview("single", mobilityEntry.id)`; Proc calls `SetPreview("single", selectedProcEntry)`. Each feature owns a Stop action that calls `StopPreview()`. Typography keeps its contextual appearance preview. These actions do not call category navigation or change `panel.activeCategory`. Starting a different test replaces the prior sample selection through the same preview runtime. Close, Escape, combat and specialization changes stop samples; they cannot revive on reopening the window. A page switch cancels an owned color edit and settles UI motion while allowing an intentional sample to remain available for contextual typography adjustments.

### Local position ownership

Mobility is the sole ordinary Mobility settings editor, including its enabled preference, XY and position reset. Proc's Position / Test card directly edits Timer X/Y and resets only the selected region's `region.position`. Artwork X/Y remain Advanced artwork controls for `region.appearance.offset`; neither editor writes the other's field. The former Timer position / Test Mode navigation button is removed.

Free Move / Time Spiral is a separate entry even though it shares Mobility typography and visibility semantics. When a current Free Move preview entry exists, Mobility shows a contextual subsection with independent XY, Reset and Test Free Move. The entire subsection is hidden when no entry exists. It uses the existing per-reminder position path and never folds Free Move offsets into ordinary Mobility group position. Changing either scope or resetting it preserves the other.

### Typeface-first font labels

Normal font picker rows display the typeface name without `SharedMedia:` or `Blizzard / Client:` prefixes. Known built-in client resources also use their actual font name; an unknown trusted client default retains its localized default label. Sorting, locale availability filtering and physical-resource deduplication are unchanged. The persisted logical identifier remains exactly `LSM:<name>`, and legacy client font paths remain valid. Provider/fallback information can remain in status or diagnostics. This is a presentation change with no schema migration.

### Shared native color picker

`UI/ProcColorPicker.lua` owns one native ColorPickerFrame session with an explicit `timer` or `artwork` target. Both targets reuse the existing picker ownership checks, native Okay/Cancel hooks, replacement protection and bounded cleanup. Timer sessions continue to use `Get/SetProcRegionColor`; artwork sessions use `GetProcRegionAppearance` and `SetProcRegionAppearance`. Draft rendering is transient presentation state, never a SavedVariables write or a transfer payload.

Artwork has a swatch/native picker and the modes Blizzard event color (`artColor = nil`) and Custom color (`artColor = { r, g, b }`). Normal UI exposes no raw R/G/B numeric fields. Swatch changes update the draft and rendered sample; Okay commits to only that target, while Cancel restores the saved presentation. Opening the other target cancels the old draft before taking ownership. Region, page, specialization, Options close, Escape and combat boundaries cancel the current owned session, and stale callbacks cannot commit to another region or target. A different addon's newer picker session is never hidden or overwritten by cleanup.

### RC2 visual hierarchy

The 900 by 640 shell and Header / Sidebar / Content / Footer grid remain unchanged. Navigation uses lightweight rows with a narrow cyan-to-violet selection rail, restrained wash and brighter selected text rather than a box around every item. The smaller wordmark/emblem leave more space for the product accent; version/status remain secondary metadata. Class/spec motifs are clipped, faint background geometry drawn with the existing static Line pool.

General, Mobility and Proc use consistent cards, title hierarchy and spacing. Primary actions receive stronger accent treatment, secondary actions retain a quiet surface, and Reset / Center / Back use ghost treatment; destructive confirmation can use danger. Inputs have a lower-contrast normal surface and a distinct focus border/bottom accent with soft glow. Toggles retain their reusable smooth motion with a darker OFF track, gradient ON track and polished thumb. Selected segments, slider fill and gallery selection repeat the restrained gradient language. Ordinary footer instructions use secondary/muted text; success green is reserved for actual saved/success feedback. No polling, new UI assets or persistent cosmetic preferences are needed for this pass.

## Compatibility and validation

This is a UI-only change. Schema 5, transfer format 1, production TOC version 1.0.0, settings ownership and saved Options position remain unchanged. Dropdown ownership, focus, collapse, navigation and motion are session state only. No new profile system or SavedVariables are introduced. Proc triggers/timers, Mobility, Free move, fonts/LibSharedMedia and live/TEST separation remain under the complete existing regression suite.

Offline checks cover the page registry and future mock page, controls/motion ownership, frame reuse, combat and queued-open cleanup, session-only state, Proc/gallery and transfer behavior, eight supported locales plus unsupported-locale fallback, and 1920x1080 / 2560x1440 / 1366x768 UIParent sizes. The actual Lua 5.1 full suite, all six static groups, publisher unit tests and `git diff --check` are required. Static styles/theme checks additionally ban stock visual templates, permanent update loops, decorative gameplay APIs, Class Tools loading and cosmetic SavedVariables in the new layer.

Offline frame mocks do not establish actual font metrics, clipping, animation interpolation, rendering or taint acceptance. Real Retail validation must inspect the entire shell and every page, long translated labels and shared-media names, keyboard focus, rapid dropdown switching, scrolling/slider dragging, small screens and UI scaling, saved-position restoration, combat/Esc/spec cleanup, simultaneous TEST/live reminders and closed-window CPU/memory. Record the client build, locale, screen/UI scale, class/spec and tested commit. No merge, release, tag or publication is part of this development task.
