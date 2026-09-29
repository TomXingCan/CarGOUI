# Independent Proc artwork: 1.0.1 acceptance

The author confirmed the final RC checks complete and authorized formal 1.0.1
integration and publication, including the version-only closeout:

- Source: `9bef4c3b654c4a45a705b74cb1b0a46431367ace`.
- Archive: `CarGOUI-1.0.1-RC-closeout-1-9bef4c3b654c.zip`.
- SHA256: `85264a3ce0f769a2a4a6983f9910274fa15360203927f66c6001a52b2eabb5dc`.

This is **author confirmation**. No new raw snapshots, measurements, videos or
individual source results accompany it. The final RC is accepted for release;
the formal package must still be built and verified against its own exact
source and archive. Do not copy RC counts into a not-yet-produced formal report.

Previously, the author accepted the P1 initial client screen on
`bc91f3fe975e059fda2196cb4b6d75d40e371006` and approved independent Proc artwork
for 1.0.1. Scope is frozen. The four results below are **author onsite
confirmation**, not automated measurements or video verification. Inherited
context is Retail 12.1.0 / build 69933, MAGE / 62, P1 independent strategy,
manually muted Blizzard settings and the selected region opt-ins.

- First real acquisition, consumption, reacquisition and final ending display normally.
- Master and per-region artwork switches do not break Timer.
- Saved independent strategy and zero Blizzard settings work on cold startup.
- Restoring nonzero Blizzard opacity pauses independent artwork with a notice;
  Timer and saved preferences remain intact.

These four P1 checks are not a sign-off for every class/source or all historic
acceptance rows. The later overall RC confirmation does not invent those
missing detailed records either.
Do not repeat A/B capture, require video, or create another observer to reconfirm
the established premise. Formal artifact verification is in
[the release checklist](RELEASE_1_0_1_CHECKLIST.md).

The only production paths are Blizzard native artwork plus CUI Timer, and
explicitly enabled independent CUI artwork plus CUI Timer. Legacy per-region
suppression is **not available in this release**. Its first-SHOW/consumption
exposure defects remain historical follow-up, not fixed by this change. The
memory investigation in #15 and remaining framework in #16 are separate. The
author has allowed release admission for #15; keeping that investigation open
does not block this release. Only the delivered Proc subset of #16 is complete.

## Evidence and limits

The author supplied public-event observer captures from Retail 12.1.0 / build
69933, MAGE / 62, with CarGOUI, CarGOUI_Data and the old first-show observer
unloaded. Native artwork visibility below is the author's visual confirmation,
not an instrumented GPU observation.

| Capture | Observed settings and public events | Author's visual observation |
| --- | --- | --- |
| A | Approximately 60.004 seconds at opacity 1 / display 1; 55 SHOW; no observer faults | Native artwork visible |
| B | The whole 60.005-second window is mixed. From about 6.616 seconds onward it stays at opacity 0 / display 0. All 16 SHOW occur in that stable segment, including events after 41 and 58 seconds | Native artwork invisible after the slider reaches zero |

The B events contain public owner/texture/location/scale/RGB fields:
`1277420 / 1027131 / 9 / 1 / 255,255,255` eleven times and
`1277009 / 6160020 / 3 / 1 / 255,255,255` five times. Both specific-owner HIDE and
HIDE(nil) are present. This is positive evidence that public graphical events
remain available under B for these recorded conditions. It does not establish
all classes/sources, startup/reload replay, or event loss rates. Comparing 55
and 16 would not establish a missing-event rate. Condition C is not required.

Raw-file SHA256:

- A.txt: `624debdc990718ceb2aeb0835ea7e471fce825dc29450cb9150116f92454ca06`
- b.txt: `fef6e02ac4109cf5ea9a0e97e18d9cf51172be2122be7e2caf4c7628d8fff194`

`tests/proc_public_event_fixture.lua` contains only the ordered public callbacks
derived from those files. Aggregated HIDE rows retain their count but have no
invented intermediate timestamps. The Lua replay tests verify addon decisions;
they do not re-measure engine delivery, animation timing, native pixels, memory
performance, or actual secure timer behavior.

## Scope and behavior

The strategy is stored per class/spec as optional
`proc.presentationPolicy = "independent"`. Missing fields and the compatible
`"replacement"` value mean native artwork with no takeover. Existing region
`appearance.mode`, assets, colors, scale,
animation, positions and timer settings are retained. The live artwork master
defaults to enabled, while every independent region requires explicit opt-in.
Neither switch disables Proc timers. Saved legacy Custom/Timer Only overrides
remain inactive in native strategy. The release gate cannot be enabled by a
saved field, import, slash command or UI control; historical takeover tests use
an explicit test-only method override outside the installed runtime. New hooks
are not installed, and any already-existing hook can only clean recorded owners.
Failed cleanup retains ownership. Native is not a per-side choice in independent
strategy: the user's global setting has hidden all native artwork.

A validated public SHOW records its own graphical state regardless of the
display CVar. Independent artwork uses the existing asset resolver, region
pool, style and animation code; its alpha is the CUI artwork alpha alone. Public
event RGB is sufficient, unless the region has an explicit CUI tint. This path
does not wait for, acquire, read, suppress, or restore native artwork objects.
Already-installed replacement hooks become inert. Public native root geometry
is still used by the existing audited layout, not as evidence of an active buff.

Timers keep the native DurationTextBinding and exact mapped aura provider.
Their public enable/alpha gates no longer depend on either Spell Alert CVar.
Existing bootstrap rules, nativeEventOnly, source priority, owner HIDE,
HIDE(nil), preview isolation and lifecycle/fault boundaries still apply. Native
bootstrap is not a fabricated artwork SHOW. Entering a strategy clears the
previous graphical state: an already-existing buff needs a new valid public
SHOW for artwork; no aura, stack, cast or preview inference fills that gap.

The independent path requires the measured B settings for live artwork:
`spellActivationOverlayOpacity=0` and `displaySpellActivationOverlays=0`.
If either is unavailable or not zero, artwork pauses with a bounded notice;
saved preferences and Timer behavior remain intact. Returning to B can resume
an existing validated public state. CUI never writes or maintains these CVars.
Explicit Test samples remain separately editable when live artwork is off or
paused; they never establish live state or suppress native artwork.

Strategy changes, imports, restores and reset perform old artwork/preview
cleanup before committing policy changes. A failed native restore or owned
animation cleanup aborts the transaction and retains cleanup ownership. Active
and desired policies are distinct until configuration succeeds. Imports stay
format 1 / schema 5 with strict optional fields; an included legacy scope that
omits the policy restores native artwork. An omitted field in a local patch keeps
the current policy. Inactive scopes do not clean up or start live work.

Missing public evidence pauses only the affected independent artwork and is not
an internal-failure strike. Genuine exceptions still use the existing Proc
quarantine; Retry is manual and does not synthesize SHOW. Notices cannot stop
resource cleanup. No automatic GC, global GC tuning, event polling, ticker,
permanent OnUpdate, new observer or native-child readback was added.

## Manual setup and recovery

1. Record the installed ZIP/SHA, client build, class, spec, enabled addons and
   Free Move state. Preserve the frozen historical packages and their evidence.
2. Keep the existing Proc enable control on. In Proc settings, select
   **Artwork strategy: Independent CUI**. Enable the live artwork master and
   explicitly enable the desired region(s). Existing artwork style controls
   and the separate Timer controls remain available.
3. Manually set Blizzard **Spell Alert Opacity** to zero. The game setting also
   disables `displaySpellActivationOverlays`; CUI performs neither write.
4. Close Options and obtain a real Proc. Test is only an isolated sample and
   cannot demonstrate public event delivery or native duration behavior.
5. To return to stock artwork, disable independent live artwork or select
   **Native artwork**, then manually restore Blizzard opacity. Preserved legacy
   Custom/Timer Only selections do not regain native takeover authority.

Global zero hides **all** native Proc artwork, including sources CarGOUI does
not cover. It cannot preserve one genuinely Native side. Disabling artwork,
disabling Proc, changing spec, a plugin error or quarantine does not restore the
global setting. Restore it manually if native alerts are needed; CUI does not
claim to have restored visible stock pixels. Nonzero stock opacity pauses live
independent artwork to avoid silently drawing both. If cleanup fails, copy
diagnostics and use explicit Retry or Reload before changing strategy.

## Detailed Retail evidence ledger

The final RC has the author's overall acceptance above. This ledger preserves
the detailed observations actually supplied. Rows without a separate result
must not be converted into claimed per-case passes; they are follow-up
references, not additional release-admission gates. For future investigation,
change one listed factor at a time and keep unrelated settings/Free Move fixed.

| Case | Required result | Actual result / diagnostics |
| --- | --- | --- |
| P1 reported MAGE/62 context: first obtain, consume, re-obtain and end | Artwork and timer function normally | Author onsite confirmation; not an all-source census |
| Saved B and independent strategy, cold startup | First real SHOW works; bootstrap timer is not a made-up graphical event | Author onsite confirmation |
| Enter independent while buff already exists | No artwork until valid public SHOW; native timer bootstrap follows its existing contract | No separate client result supplied |
| Master artwork off/on and one region off/on | Artwork changes only; Timer stays intact | Author onsite confirmation |
| Original styles; no animation; entrance/active/exit animation; low CUI alpha | CUI style remains independent of stock opacity; no native graphics under B | No separate client result supplied |
| Color confirm/cancel, numeric sliders, Preview then close | Preview/live isolated; no timer rebinding caused by artwork switches | No separate client result supplied |
| Restore stock opacity while independent remains saved | Independent live artwork pauses with notice; Timer and saved preferences remain | Author onsite confirmation |
| Native strategy and independent switch; old import/reset/restore | Saved legacy modes stay inactive; cleanup completes before policy commit | Overall final-RC acceptance recorded; no separate case report |
| Quarantine/Retry, explicit cleanup failure (offline injection only) | No auto-restart; failed owner retained; notice directs manual native setting recovery | Retain delivered offline failure checks; no new client measurement |
| Repeated toggles/spec changes, font/Mobility/Free Move/import/export checks | No persistent resource growth or unrelated regression | Overall final-RC acceptance recorded; no new resource measurements |

Use `/cui diagnostics copy` outside Options after each relevant failure or
boundary. Keep raw snapshots separate from interpretations. No new detailed
source-by-source record, including WARLOCK/266 Demonic Core, was supplied with
the final confirmation; the MAGE observer files are not evidence of those
client scenarios. This evidence limit does not reverse the author's overall
release-admission decision.
Independent rendering must not be labeled a fix for the legacy first-SHOW defect, a
memory fix, or completion of the remaining Reload-required framework.
