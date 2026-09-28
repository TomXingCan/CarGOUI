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
| Button | Owned surface/border/text with hover, press, selected and disabled feedback. |
| Toggle | Owned track, accent fill and moving thumb; existing boolean save semantics. |
| Dropdown | Reused menu/rows, selected/focus accents, optional bounded pagination and guarded interaction. |
| Input | Owned raw EditBox skin with normal, hover, focus, invalid and disabled states; Enter still commits. |
| Slider | Custom track, gradient active fill, owned thumb and numeric field; existing validation remains authoritative. |
| Section | Consistent title/padding/accent divider; optional session-only collapse. |
| Segmented control | Reusable mutually exclusive choices, independent of Proc-specific semantics. |
| Scroll frame | Native vertical scrolling, wheel handling and a thin owned scrollbar. |
| Gallery tile | Reused client-texture thumbnail and explicit selection emphasis. |

The shared layer does not use `UIPanelButtonTemplate`, `UICheckButtonTemplate`, `InputBoxTemplate`, `UIPanelScrollFrameTemplate` or stock dropdown visual chrome. `BackdropTemplate` is only a structural capability. The component layer has no gameplay queries or direct SavedVariables access; page callbacks retain their existing setting validation and transaction rules.

## Motion and cleanup

Dropdown opening uses a reusable AnimationGroup with a 120 ms fade and 8-unit translation. Closing uses a 90 ms reverse transition and hides after completion. Outgoing rows are disabled immediately, including callback guards; transferring ownership to another menu cannot leave invisible clickable rows. Rapid open/close, page change and parent close settle existing groups without allocating another set of rows or animations.

Hover and toggle feedback use short native animation groups; presses use an immediate restrained surface change. No component uses OnUpdate, a ticker, or inertial-scroll simulation. Close, Esc, combat, page and specialization boundaries stop/settle UI-only motion and close menus. A completion callback cannot reopen Options or apply a setting. Closed Options has no menu animation, decorative polling or background UI ticker. Existing branding motion remains bounded to the visible Options lifecycle.

## Pages and future Class Tools

`UI/OptionsShell.lua` provides a descriptor registry with a stable key, order, title and builder. The navigation engine sorts descriptors deterministically, builds registered pages, applies selected state and supports hidden detail pages. Icons are an optional descriptor slot, not a requirement or another global navigation hierarchy.

Only actual production pages are registered. `classTools` is deliberately absent: there is no placeholder, disabled item or empty page. A future Class Tools descriptor can register without editing shell dimensions, Sidebar code, layout or navigation. It will use the existing main area and reusable segmented controls for Common Tools versus Spec Tools, followed by a tool selector and selected-tool editor. Future semantics remain current-class-only, class-scoped Common Tools and current-specialization-scoped Spec Tools. This PR implements none of those gameplay tools or settings.

Proc Appearance is the first fully composed modern page: automatic specialization context, Proc/Region selection, Display segments, Artwork, Transform, Animation, Timer, Position/Test and session-only Advanced disclosure. Native and Timer Only continue hiding irrelevant artwork controls. Timer typography remains a link to the existing editor. The audited gallery retains its filters, pagination, stable keys and direct client thumbnails.

General, Mobility, Preview, typography, diagnostics and Import/Export retain their existing information architecture while adopting the same shared control skin. Import staging, confirmation, selection/copy, backup restore and unsubmitted-field semantics remain intact. Later releases may refine individual forms, accessibility and page composition; they should not require another global shell redesign.

## Compatibility and validation

This is a UI-only change. Schema 5, transfer format 1, production TOC version 1.0.0, settings ownership and saved Options position remain unchanged. Dropdown ownership, focus, collapse, navigation and motion are session state only. No new profile system or SavedVariables are introduced. Proc triggers/timers, Mobility, Free move, fonts/LibSharedMedia and live/TEST separation remain under the complete existing regression suite.

Offline checks cover the page registry and future mock page, controls/motion ownership, frame reuse, combat and queued-open cleanup, session-only state, Proc/gallery and transfer behavior, eight supported locales plus unsupported-locale fallback, and 1920x1080 / 2560x1440 / 1366x768 UIParent sizes. The actual Lua 5.1 full suite, all six static groups, publisher unit tests and `git diff --check` are required. Static styles/theme checks additionally ban stock visual templates, permanent update loops, decorative gameplay APIs, Class Tools loading and cosmetic SavedVariables in the new layer.

Offline frame mocks do not establish actual font metrics, clipping, animation interpolation, rendering or taint acceptance. Real Retail validation must inspect the entire shell and every page, long translated labels and shared-media names, keyboard focus, rapid dropdown switching, scrolling/slider dragging, small screens and UI scaling, saved-position restoration, combat/Esc/spec cleanup, simultaneous TEST/live reminders and closed-window CPU/memory. Record the client build, locale, screen/UI scale, class/spec and tested commit. No merge, release, tag or publication is part of this development task.
