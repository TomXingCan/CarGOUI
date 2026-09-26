# Loading and measurement boundary — alpha.15

This release keeps **CarGOUI + CarGOUI_Data** as the only installed addon directories. Native Load-on-Demand applies to the entire Data addon. Every Lua file listed in its TOC loads together, including the factories for all shipped classes. A class subdirectory is not an independent load boundary. This is the accepted two-directory tradeoff, not strict per-class code unloading.

## Four distinct layers

| Layer | Actual behavior |
| --- | --- |
| Files/modules | Core loads normally. The current supported class requests the whole Data package; all its TOC files execute and register isolated adapters. The exact executed TOC inventory is reported and checked against the source manifest. |
| Data instances | Only the current class factory runs. Common and current-spec candidate definitions are then filtered by actual learning, talent conditions and native replacements. Inactive class factories do not build candidate tables. No complete all-class default configuration tree is constructed. |
| Configuration | Core-owned account-wide `CarGOUIDB` can restore all previously saved class records. Normal reads/default initialization use only the current class Mobility and current class/spec Proc scope. Unaccessed is not unloaded. Data declares no separate SavedVariables. |
| Runtime | Cooldown/charge queries and live bindings use only the current selected skill set. Unsupported special-mechanism definitions stop before cooldown queries. Hidden/pooled frames and loaded function definitions are distinguished from active bindings and subscriptions. |

Real Proc monitoring uses the current class/spec's admitted catalogue, independently of Mobility learning or enabled state. All 13 class Proc factory files load with the unified Data TOC; only the current spec factory instantiates definitions. UI themes remain core identity-based data independent of the selected gameplay adapter; alpha.10 Header/Body definitions and artwork are unchanged.

## Registration and active sets

`Core/Modules.lua` retains a lightweight class capability index, explicit registration/selection and native `C_AddOns.LoadAddOn("CarGOUI_Data")`. A registered class must supply a real adapter; the index alone does not imply support. Duplicate registrations are rejected. Loading requested during combat is deferred to `PLAYER_REGEN_ENABLED`; a missing/failed addon is reported. The Data TOC marks registration complete only after its final manifest file executes.

Non-Mage class files register lazy factories through `Shared/Adapter.lua`. They do not overwrite shared global adapter methods. The selected factory creates only common/current-spec candidates. Actual `IsSpellKnown`, `GetOverrideSpell`, and documented talent conditions determine the final entries; mutually exclusive replacements share one ID/slot. An unrecognized override is reported, never silently timed using the old spell. The Mage Blink/Shimmer source classifier remains byte-identical to alpha.10; an explicit wrapper can append independent Mage entries without replacing it or the old Proc regions.

The event engine holds a list of states rather than one state. Each live reminder owns its own DurationTextBinding. It prunes obsolete IDs once, then renders all eligible states; updating one never hides another. Preview suppression applies to matching IDs (or the explicit Test current spec action). Stop/close/combat transition clears samples and re-queries live state independently.

Learning/spec/talent/world events rebuild the current class's candidate set. Druid alone subscribes to form changes to resolve form overrides. Cooldown events do not rerun the class factory or scan other classes. Event bursts coalesce into one cancellable next-turn task, with no recurring timer, frame scan or aura/usage history.

With no learned entries and no unresolved selection, the generic adapter retains identity/learning events but no cooldown subscriptions, queries, frames or bindings. An already learned family whose temporary override is unknown retains a bounded pending-family record and cooldown-event recovery; it makes no cooldown query or binding for the unverified target. Normal updates recheck only selected/pending family learning and base/actual overrides, so returning from a temporary button cannot freeze the old selection. The unchanged Mage primary entry is also its legacy UI/position context; its existence is not proof of learned Blink/Shimmer. Disabled Mobility stops its gameplay subscriptions and bindings. Re-enabling refreshes the roster so changes made while disabled are not frozen.

Spec changes stop previews, clear old live bindings/state and select the new set; class-scoped settings survive. Existing frames/bindings are reused by stable definition IDs. Their cache may grow to the bounded set of IDs actually visited in the session; it is not claimed to destroy WoW frames or unload Lua code. Curve caches clear when adapters deactivate. Repeated changes must not accumulate active callbacks or timers.

## Diagnostics

Existing `Copy diagnostics` / `Refresh snapshot` actions report:

- Actual client build, current class/spec, each selected spell and public status/path/reason.
- Entire loaded TOC inventory counts, registered definitions and selected adapter separately.
- Current instantiated entries, confirmed active skills and unavailable selected skills separately. A native-tracking status does not reveal final alpha to Lua.
- Registered events/callbacks, one pending event task at most, allocated live/preview frames, allocated and active bindings.
- SavedVariables restoration versus scoped access.
- Explicit runtime memory KB and, when scriptProfile already is enabled, cumulative CPU ms.

No raw charge, timing, alpha or native formatted text is serialized. Diagnostics do not change profiling settings, sample in the background or force garbage collection. They count bindings, not the hidden native final visibility result.

## Upgrade and retired Mage addon

Install both folders together. Do not delete WTF or SavedVariables. An old alpha.8 `CarGOUI_Mage` directory must be removed from AddOns program files when upgrading. The compatibility name `CarGOUI_Internal` is an isolated sink, so accidentally loaded legacy Mage code cannot replace the new host/adapter or write current configuration. The new ZIP contains no old Mage directory. Diagnostics distinguish loaded legacy code from active modern monitoring; “not loaded” does not prove a leftover directory is absent.

## Target API evidence

Source audit target: Blizzard UI source commit
`09b9db7948abc9b9648dedaab51eb0cf3ee67b31` (12.1.0 build 69933). This is source
verification, not proof that this development environment ran that client.

- [AddOnsDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnsDocumentation.lua)
  declares `C_AddOns.LoadAddOn(name)` returning a loaded flag and optional reason,
  `C_AddOns.IsAddOnLoaded(name)` returning loading/fully-loaded flags, and native
  `IsAddOnLoadOnDemand`. It also documents synchronous `ADDON_LOADED`.
- [Blizzard_AchievementUI_Mainline.toc](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_AchievementUI/Blizzard_AchievementUI_Mainline.toc)
  uses the native `LoadOnDemand: 1` and dependency TOC mechanism.
- [PerformanceDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/PerformanceDocumentation.lua)
  declares **global** `UpdateAddOnMemoryUsage`, `GetAddOnMemoryUsage`,
  `UpdateAddOnCPUUsage`, and `GetAddOnCPUUsage`. They are not `C_AddOns` methods.
- [CVarDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/CVarDocumentation.lua)
  documents `C_CVar.GetCVarBool`, used to check `scriptProfile` without changing
  it. When CPU profiling is disabled or the API is unavailable, diagnostics
  report that limitation rather than presenting zero as a measurement.

Only fixed addon names and public identity data are supplied to these APIs. This
loader adds no combat information access, protected actions, aura inspection,
cooldown inference, per-frame update, ticker, full-library scan, or forced GC.

## Actual-client resource capture — pending

No real WoW client exists in this development environment. Offline Lua/Python memory, elapsed test time, counts and ZIP size are not client CPU/memory results. Capture the existing diagnostic snapshot after each stage below, recording actual build/spec/talents:

1. Fresh login before Options, then open `/cui`. For a snapshot without creating Options, `/run print(CarGOUI_DataHost:GetMobilityDiagnostics())` invokes the same explicit diagnostic method.
2. Preview one skill, Preview all, stop, close Options. Bindings for unrelated live skills must remain active.
3. Exhaust two independent skills in combat; restore one; leave/re-enter combat. Record each public path, not inferred opacity.
4. Repeatedly switch specs/talents/forms as applicable (20 cycles), stop Preview and return to the starting context. Compare callbacks, allocated/active bindings, frame counts and memory after bounded reuse.
5. Relog another class; only that class should have active skills/queries. All Data code and existing shared saved records may still load. Relog the original class and verify its settings restore.
6. With no supported learned skill or disabled Mobility, theme still works, no cooldown bindings run. Learning/re-enabling activates only the new relevant set.

For CPU, compare cumulative deltas over equal-duration activity intervals and state whether profiling was enabled (including its overhead). Record CarGOUI and CarGOUI_Data separately. Natural GC and client activity can affect memory; no forced GC is used. All actual client CPU/memory, new ability combat behavior and repeated-spec measurements remain pending, not inferred from mocks.


## Historical alpha.12 native Proc / Free move addendum

The shared Data TOC now includes current-specialization Mage Proc factories and a small class-to-Time-Spiral receiver index. Those static files load together with all other listed Data files. Only the current Mage specialization's Proc region definitions and the current class's one Free move entry are instantiated. This does not change the shared SavedVariables boundary.

Proc uses one native AuraContainer slot per current mapped region, with a stable cache key; old-spec slots are disabled and reused on return. Free move owns its separate current-class slot and no countdown binding. Aura presence/timing and copied native bindings remain inside Blizzard's implementation; diagnostics count requested enabled slots rather than claiming a visible aura count. Core event counts exclude Blizzard-owned listeners.

Disabling a slot removes its active UNIT_AURA subscription immediately and queues one native clear pass. The public container and parent wrapper stay shown at alpha zero so that pass can clear the old assignment and copied duration binding. Cached native containers retain their static aura-data-provider-switch subscription; no claim is made that every native subscription or allocated frame is unloaded. No addon ticker, per-frame scan, buff enumeration or forced collection was added.

Actual client CPU and memory remain unmeasured; the alpha.12 package report supplied only offline object/lifecycle tests. That historical addendum describes its recorded release, not current class coverage or proof of native-aura internals.

## alpha.15 current Proc catalogue and event scope

All 13 registered adapters have explicit Proc capability version 1; this is separate from having any eligible current-spec entries. New class factories run only for the current spec and cache filtered definitions until identity/talent change. The 37 non-Mage specs have 63 admitted spec-scoped definitions / 81 regions in total, but those are not all instantiated or monitored together. Four reviewed specs currently have no admitted entry and no Proc business events/native slots. Known-driver filters do not query hidden Aura IDs as spellbook abilities.

Three generic callbacks (`SPELLS_CHANGED`, `PLAYER_TALENT_UPDATE`, `TRAIT_CONFIG_UPDATED`) remain available independently of Mobility and Proc enabled state so a newly eligible catalogue can be discovered. Current graphical SHOW/HIDE uses owner/texture/location indices and only refreshes affected definitions; unrelated events do not rerun factories or refresh the full panel. The public-event diagnostic ring is bounded at 16. Native provider identity is immutable for each pooled region; conflicts stop that slot instead of changing its Aura or discarding saved settings. No addon periodic timer or frame scanner is added.

Live/Preview entries are merged without making Proc depend on Mobility. Old-spec slots are disabled on transition; revisiting scopes reuses bounded allocated objects. Core callback counts and native-container requested enabled counts remain distinct. Native static provider-switch listeners on retained containers are not misreported as unloaded objects. Current validation and client measurement steps are in [UPGRADE_ALPHA15.md](UPGRADE_ALPHA15.md); real CPU/memory remain pending.
