# Loading and measurement boundary — alpha.8, stage A

This release prepares class-scoped configuration and automatic loading. It does
not add another class's live Mobility adapter or real Proc monitoring. The
previously client-tested Mage spell classifier is relocated without changing its
source bytes. Mage combat behavior still needs an installation regression test
after the packaging change.

## Native load-on-demand implementation

The single installer contains two sibling AddOn directories:

```text
Interface/AddOns/CarGOUI/CarGOUI.toc
Interface/AddOns/CarGOUI_Mage/CarGOUI_Mage.toc
```

Install both directories together. CarGOUI chooses its internal module; the user
does not select a class package, press a load button, or change profiles.
The internal Mage TOC declares `LoadOnDemand: 1` and a required dependency on
CarGOUI. The root TOC does not list Mage business-data files or SpellState.lua.
The repository stores the internal addon under `Modules/CarGOUI_Mage`; packaging
maps that directory to the sibling addon directory above.

`Core/Modules.lua` contains only the `MAGE -> CarGOUI_Mage` module index and generic
loading/identity/reporting functions. `C_AddOns.LoadAddOn` is called only for the
current supported class. Loading during combat is deferred until the shared
event manager delivers `PLAYER_REGEN_ENABLED`; only that loader callback is
removed afterward. A failed/missing internal module is reported as unavailable.

The module's small namespace bridge forwards to the core addon object. There is
one configuration system. Module factories create only the current spec's
Mobility entry and existing Proc preview regions. They replace the active list
on spec changes, rather than retaining all spec entry instances in a catalog.
The Lua factory definitions for the three Mage specs are loaded together with
the Mage module; they are **loaded definitions, not unloaded code**. Frames
already created during the session can be pooled and reused. Native Lua addon
code and WoW frame objects are not claimed to be unloadable.

## Four distinct layers

| Layer | Mage session | Other-class session |
| --- | --- | --- |
| Files/modules | Core plus `CarGOUI_Mage` loaded on demand | Core; Mage module not requested |
| Business-data instances | Current Mage spec entries only; zero or one active Mobility entry | No Mage entry instances |
| Saved configuration | Core `CarGOUIDB` restored; current scope selected for normal reads | Core `CarGOUIDB` restored; current class defaults created only when needed |
| Monitoring | Existing Mage adapter handles only Blink/Shimmer; runtime selects actual learned replacement | No live class adapter, cooldown queries, or Mobility bindings |

**The strict requirement that other classes' stored configuration is not loaded
is not yet met.** `CarGOUIDB` is still an account-wide SavedVariables object
owned by the core, so the client restores all previously saved class tables
when the core loads. Normal configuration access is scoped, and untouched class
defaults are not constructed, but scoped access is not storage isolation. The
module has no separate SavedVariables declaration in this stage. Before stage B
claims strict per-class storage loading, storage must move to matching native
module-owned SavedVariables with a tested migration; simply adding more adapters
or claiming that unread tables are unloaded would not satisfy the requirement.

The diagnostic snapshot distinguishes `not loaded` from `loaded but inactive`,
reports entry counts in the **active catalog**, and separately reports active
runtime listeners/bindings. Previously used pooled frames may retain their own
entry references; active catalog counts do not claim those references were
destroyed. On a real client, changing characters rebuilds the UI
environment; a synthetic test that changes class tokens inside one environment
can leave the previously loaded Mage code resident but inactive. That is not an
unload operation.

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

## Client acceptance and resource capture — pending

No WoW client is available in the development environment. Offline tests can
verify module requests, lazy entry creation, subscription counts, binding reuse,
and the independent secret-value combat fixtures. Offline Python/Lua memory or
elapsed time is **not** a WoW CPU/memory measurement, and ZIP size is not a proxy.

On the target client, preserve SavedVariables and record the build with the
existing diagnostics. Capture the same diagnostic snapshot at each stage:

1. Fresh Mage login, before opening Options; then open `/cui`. For the first
   snapshot without creating Options, run `/run print(CarGOUI_Internal:GetMobilityDiagnostics())`
   in chat. This calls the same explicit diagnostic method; it does not start a sampler.
2. Start the existing external Preview; stop Preview; close Options.
3. Enter combat, exhaust Blink/Shimmer, restore one use, and leave combat.
4. Switch Arcane/Fire/Frost repeatedly (at least 20 changes), using Preview and
   stopping it between changes; return to the initial spec and close Options.
5. Relog a Warrior, open Options and attempt Preview. Mage code must remain
   unrequested, with no active Mage skills/listeners/bindings. A saved Mage
   configuration table may still be present because the storage limitation above
   is explicit. Relog Mage and check settings restore unchanged.

Record the module/file state, active class/spec, instantiated entries, actual
selected skill, event callbacks, pooled frames, and active/allocated timing
bindings separately. Repeating the spec cycle should not grow listener or
binding counts after bounded frame reuse. A pooled hidden frame or loaded
function is not an active cooldown monitor.

Use the existing diagnostic action to request memory/CPU snapshots; there is no
background sampling loop or new performance button. If testing legacy CPU
profiling, the tester may enable `scriptProfile` and reload for that measurement
session, then restore their previous setting afterward. CarGOUI does not toggle
it. Record CPU deltas between equal-duration activity intervals, not just a
cumulative number, and label profiling overhead. Record memory for CarGOUI and
CarGOUI_Mage separately with the loaded-state field; do not report an unloaded
module's absent metric as measured zero. Natural GC and other client activity
can change memory between snapshots; no forced collection is used to hide that.

Actual client CPU, memory, combat packaging regression, and repeated-spec
results remain **pending user acceptance** until those snapshots are collected.
