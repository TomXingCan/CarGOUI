# alpha.14 — Options combat lock and deferred opening

Baseline: alpha.13, commit `7ba1dae63b75fb27d5e593924d94af9836979630`.
Only the Options lifecycle changes. The user's 2026-09-27 report confirms
current Mage Proc behavior in their tested usage; its monitoring, mappings,
regional RGB, typography and coordinates are preserved. No other class Proc
implementation, new theme, control, spell definition or configuration schema
is added.

## Behavior and ownership

- `/cui` and `/cargoui` already share one slash handler. Empty input routes to
  `ToggleOptions`; `OpenOptions` explicitly opens without ever toggling closed.
  Both entry points, and the lazy `CreateOptions` constructor, check lockdown
  before allocating or showing the panel. `help` and `status` remain unchanged.
- A combat request sets **addon runtime state** `pendingOptionsOpen = true`
  and registers this feature's own `PLAYER_REGEN_ENABLED` callback through the
  shared event manager. The first request prints the English message
  `CarGOUI: Options will open when combat ends.` (using the existing colored
  chat prefix). Ten requests still represent one intent and one notification.
- The regen callback rechecks `InCombatLockdown()`. Only an initialized addon
  with its database ready may open. A successful explicit `OpenOptions`
  consumes the request, removes only its own callback, and cancels its timer.
  An already shown window counts as successfully open and is never toggled shut.
- If the event arrives while still locked, at most **one cancellable
  `C_Timer.NewTimer(0, ...)`** is pending. It rechecks lockdown on the next tick
  and never schedules another timer itself. A stale/cancelled callback cannot
  consume a newer request. If still locked or not initialized, intent is
  retained for the next regen event or explicit open request; it does not poll.
  This intentionally does not promise an immediate open while the API still
  reports lockdown. There is no permanent timer or per-frame scan.
- A shown Options panel listens for `PLAYER_REGEN_DISABLED` and hides through
  the existing `OnHide` cleanup. That cleanup stops/saves dragging, releases
  edit focus, discards unsubmitted numeric drafts, closes owned menus and the
  diagnostic popup, cancels this addon's unconfirmed RGB draft, and stops TEST
  and title animation. It does not hide or clear a later foreign picker owner.
- Automatic hiding neither creates nor clears a pending request. Without an
  explicit combat open request, the next combat end does not reopen anything.
  The queued flag and timer never enter SavedVariables. Reload/logout starts
  a new session without the old intent.
- The last page is preserved, but `OnShow` resolves the current identity/theme
  and validates current style/Proc/Preview lists. No old color session, sample
  mode or unsubmitted edit is restored. Native picker opening also checks
  lockdown before touching the shared picker; Test Mode retains its existing
  independent combat guard.

## Live reminder isolation

No `StopProc`, `StopFreeMove`, `HideLiveMobility`, aura-container cleanup,
duration reset, alpha override, or broad event unregistration is introduced
by Options lifecycle handling. Each event owner unsubscribes its own callback.

An audit found that saving the dragged Options position previously flowed
through general `ApplySettings`. A validated **Options-only patch** now updates
only the shell position/title and existing Options controls, without
reconfiguring live modules. Mixed patches retain the old shared validation and
application behavior. No new configuration system or saved field is introduced.

Closing TEST still uses the existing safe restoration of the affected live
output. Closing without TEST skips that restoration. Because the event manager
dispatches a snapshot, a removed Preview combat callback may still run once
in the same event: it now returns when TEST has already stopped. This prevents
duplicate restoration without changing real combat state or subscription owners.

## Target API check

The project targets Retail 12.1.0 / Interface 120100 (existing data audit build
69933). API source pin: `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`.

- [RestrictedActionsDocumentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/RestrictedActionsDocumentation.lua)
  declares global `InCombatLockdown()` with a non-nil boolean result.
- [UnitDocumentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  declares the synchronous regen events without payload. This declaration
  does not promise the lock has cleared before every enabled-event callback;
  hence the explicit recheck and one bounded next-tick fallback.
- [UITimerDocumentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua)
  declares `NewTimer` returning a timer handle;
  [Blizzard TimedCallback](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXMLBase/TimedCallback.lua)
  demonstrates cancelling and clearing that handle. No `After`, ticker or
  recursive retry loop is needed here.

These are source checks, not observations of the user's client event order.

## Upgrade and in-game acceptance

1. Exit WoW and replace the ZIP's **CarGOUI + CarGOUI_Data** program folders
   together under `_retail_/Interface/AddOns/`. Both TOCs should report
   `0.1.0-alpha.14`. Do not delete WTF, SavedVariables or user settings.
2. After login, enter combat before ever opening Options. Input `/cui` and
   `/cargoui` ten times. Expect one message, no visible panel/flash, no TEST
   or native picker. `/cui help` and `/cargoui status` still print normally.
3. End combat: Options opens once, TEST stays off, picker stays closed. Close
   Options and enter/end combat again without a request: it must stay closed.
4. Out of combat, visit Proc, set and confirm two different region colors,
   select a page and leave an unsubmitted numeric edit. Start a new color
   draft and TEST. Enter combat: panel/menus/picker/TEST close; saved colors
   and numeric settings survive. Without a combat request it stays closed.
5. Repeat while dragging the Header/Body; mouse release after auto-hide must
   not leave the window moving. A requested later opening retains the saved
   window position and normal drag, Enter and instant-slider behavior.
6. Open a different addon's native picker after opening ours, then enter
   combat: CarGOUI must not close or alter that later picker. Its own draft
   must not leak into another region or specialization.
7. During real Clearcasting/other Mage Proc, depleted Blink/Shimmer and
   Time Spiral receiver effects, repeat the open/close/queue transitions.
   Verify the native timers continue, partial recovery behaves normally and
   Free move reflects its real effect. TEST cleanup must restore affected
   real output without resetting time or clearing unrelated reminders.
8. Queue an open in combat then `/reload`; the old request must not reappear
   after combat. Repeat normal request/combat cycles and inspect the existing
   diagnostics: no growing listener/binding count. Current-context selection,
   saved RGB/font/coordinates and themes remain correct after specialization
   changes and reopening. No manual queue controls or selectors were added.

## Validation boundary

The delivery `.tests.txt` records the actual test count and all three static
suites, run from the **final extracted installer**, plus source commit/tree,
CRC/content verification and SHA256. Offline tests simulate combat lockdown
separately from data secrecy, delayed event order, cancellation, initialization
gates, competing picker ownership, active real reminder fixtures and bounded
event/timer reuse. They cannot certify Retail native taint, client input focus,
visual one-frame behavior, actual event scheduling or CPU/memory usage.

No real WoW client is available in this development environment. All newly
changed combat UI behavior remains **pending user in-game acceptance**. The
previous user acceptance of Mage Proc is retained and does not stand in for
acceptance of this new Options lifecycle.
