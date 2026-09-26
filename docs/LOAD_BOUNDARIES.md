# Loading and measurement boundary — alpha.10, unified Data package

Alpha.10 adds all 13 classes / 40 specializations to the core's lightweight
Options theme definitions. These UI palette tables and geometry-generating code
are loaded with CarGOUI, regardless of Mobility support. They are not business
adapters or a spell database. Only the current Body motif's segments are built,
using the existing 64-Line pool while Options exists; no additional reminder
frames, gameplay subscriptions or cooldown queries are created for a theme.
This does not provide full-class Mobility support: the shipped live adapter is
still Mage. The previously documented Data/storage tradeoff below is unchanged.

## Explicit architecture tradeoff

This revision deliberately replaces the per-class top-level addon model with
two installed directories: `CarGOUI` and `CarGOUI_Data`. Native Load-on-Demand
applies to the **whole Data addon**, not to its class subdirectories. Every file
listed in `CarGOUI_Data.toc`, including static class definitions, loads together
when Data is loaded. Future class files added to that TOC will therefore be
loaded together, even when their adapter is not selected. This design does not
claim strict per-class file loading isolation.

Only the current supported class adapter is selected and only its current spec
entry factories are run. Unselected adapter definitions are not active cooldown
monitors. The Data addon declares no SavedVariables. Existing account-wide
`CarGOUIDB` remains owned by CarGOUI and can restore all saved class records at
once; a record being unaccessed does **not** mean it is unloaded. No saved class
settings are deleted or compressed to hide this cost. This is the explicitly
accepted package-organization tradeoff, not fulfillment of the former strict
per-class file/storage-unloaded target.

This release prepares class-scoped configuration and automatic loading. It does
not add another class's live Mobility adapter or real Proc monitoring. The
previously client-tested Mage spell classifier is relocated with only its two-line
private-namespace preamble changed; its classification body is unchanged. Mage
combat behavior still needs an installation regression test
after the packaging change.

## Native load-on-demand implementation

The single installer contains two sibling AddOn directories:

```text
Interface/AddOns/CarGOUI/CarGOUI.toc
Interface/AddOns/CarGOUI_Data/CarGOUI_Data.toc
```

Install both directories together. CarGOUI chooses its internal module; the user
does not select a class package, press a load button, or change profiles.
The internal Data TOC declares `LoadOnDemand: 1` and a required dependency on
CarGOUI. The root TOC does not list Mage business-data files or SpellState.lua.
The repository stores the internal addon under `Modules/CarGOUI_Data`; packaging
maps that directory to the sibling addon directory above.

`Core/Modules.lua` contains a lightweight supported-class index and generic
registration/selection/loading/reporting functions. It requests
`C_AddOns.LoadAddOn("CarGOUI_Data")` only when the current class has shipped support
(Mage in this release). Loading during combat is deferred until the shared
event manager delivers `PLAYER_REGEN_ENABLED`; only that loader callback is
removed afterward. A failed/missing internal module is reported as unavailable.

Each class directory owns an isolated adapter namespace. The Data host explicitly
registers it with `RegisterClassAdapter(classToken, adapter)`; duplicate registration
is rejected. The core dispatch methods select the current class adapter without
letting class files overwrite core methods. Narrow bound read delegates provide
identity, current public status and style-key access. There is no write-through
metatable into the core and no second configuration store. Adapter factories
create only the current spec's
Mobility entry and existing Proc preview regions. They replace the active list
on spec changes, rather than retaining all spec entry instances in a catalog.
The Lua factory definitions for the three Mage specs are loaded together with
the Data package; they are **loaded definitions, not unloaded code**. Frames
already created during the session can be pooled and reused. Native Lua addon
code and WoW frame objects are not claimed to be unloadable.

## Four distinct layers

| Layer | Mage session | Other-class session |
| --- | --- | --- |
| Files/modules | Core plus the entire `CarGOUI_Data` TOC loaded on demand | Core; Data not automatically requested by this Mage-only release. If loaded externally, all Data files remain loaded. |
| Business-data instances | Current Mage spec entries only; zero or one active Mobility entry | No Mage entry instances; registered definitions may exist if Data was loaded externally |
| Saved configuration | Core `CarGOUIDB` restored; current scope selected for normal reads | Core `CarGOUIDB` restored; current class defaults created only when needed |
| Monitoring | Existing Mage adapter handles only Blink/Shimmer; runtime selects actual learned replacement | No live class adapter, cooldown queries, or Mobility bindings |

**The strict requirement that other classes' stored configuration is not loaded
is not yet met.** `CarGOUIDB` is still an account-wide SavedVariables object
owned by the core, so the client restores all previously saved class tables
when the core loads. Normal configuration access is scoped, and untouched class
defaults are not constructed, but scoped access is not storage isolation. The
Data package has no separate SavedVariables declaration. The two-directory
organization takes precedence over the earlier per-class package proposal;
adding more class subdirectories cannot create independent native file or
SavedVariables load boundaries. Storage and runtime costs require actual client
measurement rather than a claim of strict per-class unloading.

The diagnostic snapshot distinguishes `not loaded` from `loaded but inactive`,
reports entry counts in the **active catalog**, and separately reports active
runtime listeners/bindings. The one Mobility catalog entry is the existing
current-spec UI/position record; it is not proof that Blink/Shimmer is learned.
The separately reported `activeSkills` follows the adapter's confirmed spell ID
and is zero when learning has not been confirmed. Proc catalog entries remain
static Preview-only regions, never live Proc monitors. Previously used pooled frames may retain their own
entry references; active catalog counts do not claim those references were
destroyed. On a real client, changing characters rebuilds the UI
environment; a synthetic test that changes class tokens inside one environment
can leave the previously loaded Mage code resident but inactive. That is not an
unload operation.

## Alpha.8 residual Mage addon

The new core publishes its current host as `CarGOUI_DataHost`. The retired
`CarGOUI_Internal` name points to an isolated empty compatibility sink. If an
alpha.8 `CarGOUI_Mage` is left installed and explicitly loaded, its old bootstrap
and class functions write into that sink. They cannot replace the new dispatch
methods, register a second active Mage adapter or use the real saved settings.
Its declared dependency requires the new CarGOUI core to load first; this guard
works whether the retired addon runs before or after Data is requested. This is
collision prevention, not proof that the old code or its memory is unloaded.

The new ZIP includes no `CarGOUI_Mage` directory. For a clean upgrade, exit WoW,
remove the old **AddOns program directories** `CarGOUI` and `CarGOUI_Mage` (and a
prior `CarGOUI_Data` when replacing this release), then extract the new two
directories. Keep WTF and all SavedVariables files. CarGOUI never deletes these
directories or user settings automatically. Diagnostics distinguish retired code
being loaded/registered in quarantine from an active adapter; “not loaded” does
not assert that the directory is absent.

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
   snapshot without creating Options, run `/run print(CarGOUI_DataHost:GetMobilityDiagnostics())`
   in chat. This calls the same explicit diagnostic method; it does not start a sampler.
2. Start the existing external Preview; stop Preview; close Options.
3. Enter combat, exhaust Blink/Shimmer, restore one use, and leave combat.
4. Switch Arcane/Fire/Frost repeatedly (at least 20 changes), using Preview and
   stopping it between changes; return to the initial spec and close Options.
5. Relog a Warrior, open Options and attempt Preview. This release must not
   automatically request Data, and has no active Mage skills/listeners/bindings.
   Separately, if Data is explicitly loaded for an isolation test, its Mage
   definitions must be reported loaded but inactive, with zero instantiated
   active Mage entries and no Mobility subscriptions/bindings. A saved Mage
   configuration table may still be restored because the storage limitation above
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
CarGOUI_Data separately with the loaded-state field (and retired CarGOUI_Mage if
accidentally loaded); do not report an unloaded
module's absent metric as measured zero. Natural GC and other client activity
can change memory between snapshots; no forced collection is used to hide that.

Actual client CPU, memory, combat packaging regression, and repeated-spec
results remain **pending user acceptance** until those snapshots are collected.
