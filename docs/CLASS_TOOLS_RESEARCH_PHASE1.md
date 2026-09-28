# Class Tools Research Phase 1 / Phase 1.1 instrumentation

## Purpose and delivery boundary

Phase 1 supplies one temporary, opt-in **Class Tools Raw Capture Logger** for gathering event timelines on WoW Retail 12.1. The logger lives in [`Research/ClassToolsRawCapture.lua`](../Research/ClassToolsRawCapture.lua) and is exposed internally as `addon.ClassToolsRawCapture`. Product direction is recorded separately in [Class Tools Product Specification](CLASS_TOOLS_PRODUCT_SPEC.md).

**No production Class Tools evaluation algorithm is implemented in Phase 1.**

This phase does not implement Arcane success/failure, a seventh-tick protection interval, wave grouping, AoE clustering, Combustion window evaluation, a Combustion Counter, or Alter Time recovery calculations. It also adds no production Class Tools Options page, formal Class Tools database schema, schema migration, production registry, style inheritance, 1.0.1 release, or tag. The existing addon version is recorded as session context; this research phase is not a release-version change.

Phase 1.1 extends raw instrumentation only. It appends guarded event identifiers and optional channel snapshots, adds a client-send observation, and identifies the logger revision independently of the addon version. The production boundary above continues to apply.

## First target-client observation and Phase 1.1 motivation

The author reported the first Arcane sample from **WoW Retail 12.1.0, build 69933**. The following describes that one supplied sample; it does not claim broader client coverage or establish final algorithm rules:

| Observation | Reported result |
| --- | --- |
| `COMBAT_LOG_EVENT_UNFILTERED` | `RESTRICTED`. |
| `UNIT_AURA` | Registration succeeded, but aura payloads during Arcane Missiles were largely `RESTRICTED`. |
| Arcane Missiles channel spell ID | `5143` observed. |
| Complete sample `UNIT_SPELLCAST_CHANNEL_START` | Relative timestamp `8.506687`. |
| Complete sample `UNIT_SPELLCAST_SUCCEEDED` | Relative timestamp `8.507931`, immediately after CHANNEL_START, not at channel completion. |
| Complete sample `UNIT_SPELLCAST_CHANNEL_STOP` | Relative timestamp `10.056172`. |
| `UNIT_SPELLCAST_CHANNEL_UPDATE` | Zero observations in the complete sample. |
| Channel START/STOP cast GUID | `UNAVAILABLE` in this sample. |
| SUCCEEDED cast GUID | Readable in this sample. |

These gaps motivate capturing `castBarID` independently of `castGUID`: the target API declarations mark this event field `NeverSecret`, while each observed value still passes the logger's secret/access guards. Its presence records a raw identifier; it does not establish a chain, wave, or success result. Optional `UnitChannelInfo` snapshots add observable channel fields without polling or deriving ticks from times.

Phase 1.1 also records `UNIT_SPELLCAST_SENT` to research the time when the client emits the next cast/Spell Queue send event. **SENT is only a raw event observation.** It is not a successful cast, queued success, chain success, or the absolute true time of a player's button press. Its target argument is not necessary for this research and is neither inspected nor saved.

## Commands and session lifecycle

| Command | Behavior |
| --- | --- |
| `/cui ctlog arcane on` | Start a new Arcane research session. |
| `/cui ctlog combustion on` | Start a new Combustion research session. |
| `/cui ctlog altertime on` | Start a new Alter Time research session. |
| `/cui ctlog off` | Stop capture and remove the logger's subscriptions; retain the current buffer for inspection. |
| `/cui ctlog status` | Report capture state, mode, record count/cap, and truncation state. |
| `/cui ctlog clear` | Stop capture and clear the buffer and session state. |
| `/cui ctlog dump` | Open the copyable raw timeline dump. |

Capture is OFF by default and OFF after every `/reload`. Raw data is held only in Lua memory and is never written to SavedVariables. Session context and initial `CAPABILITY` rows also count toward the 2,000-record bound. Reloading or exiting the client discards it, so copy a session before doing either.

Turning ON a different mode replaces the previous session and starts a new relative timeline. Repeating ON for the already active mode is idempotent: it neither creates duplicate subscriptions nor resets the session. Starting ON after capture has stopped begins a new session and clears the previous buffer. Copy a completed session before starting another.

The hard cap is **2,000 records, including session metadata**. The logger never overwrites early rows. Reaching the cap sets `TRUNCATED`, stops capture, and releases the logger's event subscriptions. The dump exposes the truncation flag outside the bounded record buffer, so it remains visible even when no additional record fits. A truncated session is an incomplete timeline, not evidence of a clean terminal game event.

The dump UI is created only when requested. There is no per-event chat output, OnUpdate polling, periodic scan, or timer-based sampling. When OFF, the logger has no research subscriptions or CLEU callback. Existing consumers of the shared event router can still require the underlying game event; stopping this logger must not remove their subscriptions.

## Event subscriptions

All subscriptions use the existing [`Core/Events.lua`](../Core/Events.lua) router. The three modes request the following common event set:

```text
UNIT_SPELLCAST_START
UNIT_SPELLCAST_STOP
UNIT_SPELLCAST_FAILED
UNIT_SPELLCAST_INTERRUPTED
UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_SENT
UNIT_SPELLCAST_CHANNEL_START
UNIT_SPELLCAST_CHANNEL_UPDATE
UNIT_SPELLCAST_CHANNEL_STOP
UNIT_AURA
COMBAT_LOG_EVENT_UNFILTERED
```

| Mode | Additional requested events | Research focus |
| --- | --- | --- |
| `arcane` | None | Channel/cast ordering, interruption, raw aura changes, and player-related combat-log records. |
| `combustion` | None | Raw Combustion apply/remove/update observations, Pyroblast and Flamestrike casts, and possible extension-related observations. |
| `altertime` | `UNIT_HEALTH`, `UNIT_MAXHEALTH` | First cast, aura changes, later casts/return-related observations, and safe player health snapshots. |

These are the requested subscriptions, not a guarantee that the target client permits each event or payload. On Retail 12.x, including the target 12.1 client, `COMBAT_LOG_EVENT_UNFILTERED` (CLEU) may be entirely unavailable to addon code. Phase 1 must not assume that CLEU is usable. A `RESTRICTED` or `UNAVAILABLE` CLEU stream is a valid research result.

Future Arcane and Combustion algorithms must not depend on CLEU unless actual target-client testing proves that the required stream is safely and reliably available. Preserve the current fail-closed implementation; do not change it merely to force CLEU access or attempt any workaround around Blizzard restrictions.

Before CLEU registration the logger requires a publicly readable `C_CombatLog.IsCombatLogRestricted()` result of `false` and an available `CombatLogGetCurrentEventInfo` function. A restricted result records `RESTRICTED`; a missing or failed check records `UNAVAILABLE`. Both paths skip CLEU registration. Failed event registrations also record `UNAVAILABLE`. If CLEU becomes restricted during a received event, its subscription is released and a new capability row records the change. A missing CLEU stream is not silently replaced with an inferred combat timeline.

Public non-player unit events are discarded. A restricted or unavailable unit token is retained as a marked record; its aura payload is not inspected as though it identified the player. CLEU records with public GUIDs are retained only when the source or destination identifies the player. If the player/source/destination GUID is restricted or unavailable, the logger retains the record with markers and `playerFilter=UNAVAILABLE` instead of claiming it proved player attribution. Candidate spell IDs do not filter admission, allowing unknown spell aliases and supporting events to remain observable.

Initial `CAPABILITY` rows record each requested event's registration result. Later status output reports a formerly registered subscription as `OFF` after stopping, while the historical row remains `REGISTERED`; the row describes its capture-time result, not current subscription state. `off` does not add a synthetic game event.

## Raw timeline contract

Records carry a monotonically nondecreasing relative timestamp and an increasing sequence number. The selected session clock is `GetTimePreciseSec` when available, otherwise `GetTime`; no profiling timer is reset. The timestamp is relative to the start of that capture session and is `UNAVAILABLE` if the selected clock cannot be read safely. Sequence order remains authoritative for equal or unavailable timestamps. The event name is preserved. Applicable records include:

- Unit, cast GUID, spell ID, cast bar ID, applicable interruption field, and a public spell name for debug readability only.
- Optional channel spell ID, start/end times in native milliseconds, and channel cast bar ID, observed once on each eligible channel event.
- Public source/destination GUIDs and the CLEU subevent.
- Raw aura update facts, including available added/updated/removed aura instance IDs and public spell/duration/expiration fields.
- Publicly safe player health percentage when applicable.

Inapplicable or unsupplied fields are empty TSV cells. Attempted reads that are missing, fail, or cannot be safely inspected use `UNAVAILABLE`; restricted fields use `RESTRICTED`. Spell names are never identifiers and no localization-dependent matching is performed. Raw aura duration and expiration observations are not converted into a combustion window, extension duration, expiry prediction, or success criterion.

There is no initial aura baseline scan when a session begins. Full `UNIT_AURA` updates record the `isFullUpdate` flag without enumerating auras or deriving a diff; only incremental lists supplied by the event are traversed. Updated public instance IDs may trigger one protected instance query. Removed instance IDs are recorded without looking up or caching a former spell ID. Consequently, a pre-existing aura, an unqueryable update, or a full update may leave a gap in the spell-level timeline, and a removal can have an instance ID with an empty spell ID. These gaps must remain explicit during analysis.

A CLEU record is an observation of a received event, not proof of a completed missile wave or a successful chain. A `UNIT_SPELLCAST_SUCCEEDED` record is not a Phase 1 product success result. An aura removal does not by itself distinguish manual return from expiration or another mechanic. Those distinctions must be investigated against a deliberately recorded live-client scenario.

### Spellcast event signatures

Payload arguments after the event name are read according to each event's signature, rather than treating every fourth argument as a cast bar ID:

| Event | Payload order | Captured event fields |
| --- | --- | --- |
| `UNIT_SPELLCAST_START` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_STOP` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_FAILED` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_SUCCEEDED` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_CHANNEL_START` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_CHANNEL_UPDATE` | `unit, castGUID, spellID, castBarID` | `unit`, `castGUID`, `spellID`, `castBarID` |
| `UNIT_SPELLCAST_CHANNEL_STOP` | `unit, castGUID, spellID, interruptedBy, castBarID` | `unit`, `castGUID`, `spellID`, `interruptedBy`, `castBarID` |
| `UNIT_SPELLCAST_INTERRUPTED` | `unit, castGUID, spellID, interruptedBy, castBarID` | `unit`, `castGUID`, `spellID`, `interruptedBy`, `castBarID` |
| `UNIT_SPELLCAST_SENT` | `unit, target, castGUID, spellID` | `unit`, `castGUID`, `spellID`; discard `target` |

Each captured field is guarded independently. An inaccessible `castGUID` does not suppress an accessible `castBarID`, and an inaccessible `interruptedBy` does not suppress the following cast bar ID. `interruptedBy` is the raw field, not a classification of the interruption. Events whose signatures do not supply one of these fields leave its TSV cell empty; a supplied but inaccessible or missing expected value uses the corresponding marker.

### Optional channel snapshots

Only a publicly identified `player` event of type `UNIT_SPELLCAST_CHANNEL_START`, `UNIT_SPELLCAST_CHANNEL_UPDATE`, or `UNIT_SPELLCAST_CHANNEL_STOP` triggers one protected `UnitChannelInfo("player")` call, if the API exists. No other event requests this snapshot. The native return positions are read independently:

| TSV field | Native return position | Meaning |
| --- | --- | --- |
| `channelSpellID` | 8 | Raw channel spell ID. |
| `channelStartTimeMs` | 4 | Raw native channel start time in milliseconds. |
| `channelEndTimeMs` | 5 | Raw native channel end time in milliseconds. |
| `channelCastBarID` | 11 | Raw channel cast bar ID. |

Snapshot fields use the existing secret/access guards independently of the channel name, cast GUID, and each other. A secret field becomes `RESTRICTED`; a missing API, failed call, absent return, or inaccessible unit identity leaves the attempted snapshot field `UNAVAILABLE`. A STOP snapshot may have no result because the channel is already gone; that absence is retained as an observation. Snapshot cells on unrelated events are empty.

There is no polling or OnUpdate handler. The logger does not subtract or normalize the native channel start/end times, infer ticks, calculate protection windows, or establish a cast/channel relationship from these identifiers.

## Dump format and synthetic example

The dump is deterministic UTF-8-compatible text with a status/comment line, one fixed TSV header, and records in insertion order. `t` uses six decimal places when numeric. `seq` is the one-based buffer index. Tabs, newlines, carriage returns, backslashes, and WoW markup pipes in values are escaped to keep cells and the copy surface stable. There is no sort by spell, target, subevent, or inferred wave.

Phase 1.1 uses **`format=2` with 23 fixed TSV columns**. The original 17 columns retain their order and meaning; six fields are appended: `castBarID`, `interruptedBy`, `channelSpellID`, `channelStartTimeMs`, `channelEndTimeMs`, and `channelCastBarID`. Consumers must read the format marker and header rather than assume the older format=1 width.

The fixed column order is shown below. `detail` carries session metadata, capability status, aura action/update markers, or a limitation. `cleuTimestamp` preserves the public native combat-log timestamp separately from the relative observation clock `t`. `duration`, `expirationTime`, and `applications` are public aura facts only; no arithmetic uses them. The new channel time fields preserve their native millisecond values and are not relative session timestamps.

**Synthetic offline dump excerpt, not a WoW sample.** All observations below are synthetic fixture data. These identifiers, timings, and event pairings do not establish target-client mappings or a cast relationship. The real dump starts with one `SESSION_START` row and eleven common-mode `CAPABILITY` rows; those twelve rows are omitted from this excerpt for readability, so the first displayed sequence is 13. The status line describes a stopped, untruncated 15-record session. Stopping does not append a row.

```tsv
# CarGOUI CTLOG Phase1	format=2	mode=arcane	enabled=false	count=15	cap=2000	TRUNCATED=false
t	seq	event	unit	castGUID	spellID	spellName	sourceGUID	destGUID	subEvent	healthPct	detail	auraInstanceID	duration	expirationTime	applications	cleuTimestamp	castBarID	interruptedBy	channelSpellID	channelStartTimeMs	channelEndTimeMs	channelCastBarID
0.125000	13	UNIT_SPELLCAST_CHANNEL_START	player	UNAVAILABLE	5143	Debug spell 5143											314		5143	10000125	10001625	314
0.375000	14	UNIT_SPELLCAST_CHANNEL_UPDATE	player	UNAVAILABLE	5143	Debug spell 5143											314		5143	10000125	10001625	314
1.625000	15	UNIT_SPELLCAST_CHANNEL_STOP	player	UNAVAILABLE	5143	Debug spell 5143											314	UNAVAILABLE	UNAVAILABLE	UNAVAILABLE	UNAVAILABLE	UNAVAILABLE
```

`dump` is a point-in-time copy; subsequent events do not rewrite an already open copy surface. Use `/cui ctlog off`, then `/cui ctlog dump`, select all, and copy before clearing, restarting, or reloading. Record a short scenario note beside the dump so deliberate manual actions remain distinguishable from unclassified event facts.

## Session context

At session start the logger captures the following once in the `SESSION_START.detail` field, when the APIs and values are publicly accessible:

| Context | Purpose and limitation |
| --- | --- |
| CarGOUI version | Identify the code version producing the timeline. |
| WoW version/build/interface | Identify the precise target client, rather than assuming all 12.x builds behave alike. |
| Class and specialization | Record the environment in which the selected research mode ran. |
| Haste | Record a public haste snapshot; it is not used to predict ticks or cast lengths. |
| Home and world latency | Record the network snapshot without adjusting event timestamps. |
| Spell Queue Window | Record a safely readable CVar value without using it as a chain threshold. |
| Research mode | Identify the explicitly selected capture mode. |
| Equipment item IDs | A low-cost inventory snapshot, not item-effect inference. |
| Active talent configuration ID | A low-cost identifier; no talent-tree traversal or inferred talent effects. |
| Research logger revision | `researchLoggerRevision=phase1.1` identifies this instrumentation revision without changing the formal addon version. |

The metadata keys, in order, are `addonVersion`, `wowVersion`, `build`, `interface`, `class`, `specID`, `haste`, `homeLatencyMS`, `worldLatencyMS`, `spellQueueWindowMS`, `researchMode`, `clock`, `activeTalentConfigID`, `equipmentItemIDs`, and `researchLoggerRevision`. An `addonVersion=1.0.0` session can therefore explicitly identify the Phase 1.1 logger without a formal version bump, release, or tag. Equipment covers inventory slots 1–19 as `slot:itemID` pairs. Unavailable or restricted metadata is recorded as such. Equipment and talent configuration identifiers are only partial environment context; they do not constitute a complete reproducible talent/effect model. Note the relevant selected talents, gear effects, and intended action sequence alongside the copied dump when preparing live samples.

## Secret and restricted data

Every value must pass the available public secret/access checks before it is compared, formatted, used as a table key, or used in arithmetic. Table access also needs a table-level check before indexing or traversal; a public outer table does not make nested tables or leaf values public. Catching an API failure does not grant permission to inspect a returned secret value. The logger does not read native UI text, hidden frames, secure state, combat-log files, or another addon to reconstruct restricted data.

Health percentage is requested as `UnitHealthPercent("player", false, CurveConstants.ScaleTo100)` and recorded only when the native result is a publicly accessible number on the 0–100 scale. Predicted health is not requested. If the native conversion curve is absent, the result is `UNAVAILABLE`. The logger does not query raw `UnitHealth` / `UnitHealthMax` or divide raw health values. Secret/restricted health is recorded only as `RESTRICTED`; absent, failed, or unsupported health access is recorded only as `UNAVAILABLE`. It must never be converted to zero, estimated from another field, used for a delta, or interpreted as an Alter Time recovery amount. No recovery amount calculation exists in this phase.

Restriction states describe observability, not game-state outcomes. A restricted or unavailable aura/health/CLEU field cannot be treated as proof that a spell, aura, heal, return, or tick was absent.

## Research questions and first sample order

The first live capture order is fixed: **Arcane → Fire → Alter Time**. Arcane has the most complex timeline and should first establish whether the raw data is sufficient before relying on the logger for the other modes.

### 1. Arcane

Start with `/cui ctlog arcane on`. Record separate deliberate examples of uninterrupted Arcane Missiles, early interruption, channel replacement/chaining, movement or other causes of interruption, and different relevant talent/haste conditions. Stop and copy each short scenario before starting another.

The external candidates **Arcane Missiles damage/tick `7268`** and **Clearcasting `263725`** are research labels only. Neither is hardcoded as a final algorithm fact or an admission filter. Channel spell ID `5143` is observed in the reported build 69933 sample, not installed as an algorithm rule or admission filter. Continue checking the actual player cast/channel IDs, damage/tick IDs, aura IDs, cast GUID/cast bar ID availability, optional channel snapshots, and ordering across SENT, channel START/UPDATE/STOP, INTERRUPTED, SUCCEEDED, UNIT_AURA, and any safely available CLEU stream on the target client. Record both single-target and multiple-target samples without grouping waves or clustering targets.

The logger must not label any sample success/failure, synthesize a seventh tick, create a seventh-tick protection interval, or group events into waves.

### 2. Fire / Combustion

Start with `/cui ctlog combustion on`. Deliberately record Combustion activation, available aura apply/update/removal observations, Pyroblast casts, Flamestrike casts, and scenarios with and without relevant duration-extension mechanics. Include failed/interrupted casts where reproducible.

Confirm exact spell/aura IDs, whether normal and triggered casts have distinct event patterns, and which public events or raw aura changes actually accompany extension mechanics. No Phase 1 code establishes a combustion window, decides which cast belongs to one, computes an extension, or reports a count.

### 3. Alter Time

Start with `/cui ctlog altertime on`. Record separate scenarios for the first Alter Time cast, manual return, natural expiration, and relevant automatic mechanics. Include deliberate health changes when safely reproducible, and capture public health percentage or the exact restriction/unavailability marker at the relevant events.

Scenario notes identify the action attempted; the logger does not classify the received sequence as a manual return, natural expiration, or automatic return. Confirm first-cast/return spell IDs, aura identity and lifecycle, event ordering, and safe health availability in the actual target context. No Phase 1 code subtracts health snapshots or calculates recovery.

## Public API evidence

These public source declarations guide defensive capture; they do not replace WoW 12.1 client observations:

- [Combat log API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/CombatLogDocumentation.lua) mark CLEU as restricted-capable and expose `C_CombatLog.IsCombatLogRestricted`. A restricted registration/access path must be recorded as a capability gap, not reported as a working stream.
- [Unit event and health declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) describe the differing spellcast/channel signatures, `NeverSecret` cast bar IDs, the conditional-secret SENT target, secret-capable health returns, and `UnitChannelInfo` return positions. The logger discards the SENT target and still guards all recorded fields independently; documentation does not replace runtime checks. [Secret predicate declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua) include conditions that can make otherwise familiar fields secret.
- [Aura API declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) and [aura payload structures](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitConstantsDocumentation.lua) describe restricted-capable `UNIT_AURA` updates and access-limited instance queries. A missing field or failed instance query is not proof of aura absence.
- [Native percentage scale](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXMLBase/CurveConstants.lua) defines `ScaleTo100` with points `(0, 0)` and `(1, 100)`. The health API receives that native curve; addon Lua does not reconstruct or scale secret health.
- [FrameScript access-check declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameScriptDocumentation.lua) distinguish value checks (`issecretvalue` / `canaccessvalue`) from table checks (`issecrettable` / `canaccesstable`).

The source links use the live branch and can change. The exact build recorded in each capture is the relevant acceptance target. The logger must tolerate an inaccessible stream even when documentation describes its existence.

## Target-client verification still required

Offline mocks and public documentation/source declarations establish intended behavior and safety boundaries, not live WoW 12.1 verification. The single author-reported build 69933 sample above provides limited target-client evidence; Phase 1.1 additions still require their own live capture. Existing Proc mappings and native aura bindings do not prove that direct raw aura or CLEU data is readable by this logger in combat.

The following remain live-client acceptance items:

- Availability and exact payloads of every requested spellcast/channel event, particularly SENT, channel UPDATE/STOP versus INTERRUPTED/SUCCEEDED ordering, public cast GUIDs/cast bar IDs, and `interruptedBy` accessibility. The absence of UPDATE in the reported sample is not a universal rule.
- `UnitChannelInfo` field availability and cast bar IDs during START/UPDATE/STOP, including independent field restrictions and no-result STOP snapshots; no inferred tick count or cast relationship is an acceptance criterion.
- CLEU registration and `CombatLogGetCurrentEventInfo` access in town, training-dummy combat, and actual instance combat; source/destination GUID and spell-field restrictions.
- `UNIT_AURA` update payload accessibility, incremental versus full updates, and aura-instance query access; completeness of raw apply/update/removal observations when fields are restricted or unavailable.
- Arcane candidates `7268` and `263725`, plus all observed cast/channel, Combustion, Pyroblast, Flamestrike, Alter Time first-cast/return, and duration-extension aliases.
- Whether public aura duration/expiration observations actually expose extension changes, without interpreting them as an algorithm.
- Secret/access check behavior and public `UnitHealthPercent` availability and health-event timing at every relevant Alter Time event; no taint or Lua errors under restrictions.
- Session metadata APIs for haste, latency, Spell Queue Window, specialization, equipment, and talent configuration on the exact build.
- OFF/reload/cap cleanup, copyable dump behavior, and unchanged Proc/Mobility behavior under the real shared event router.

If the data is insufficient, preserve the actual missing/restricted capability as a research result. Do not invent an evaluation rule or bypass restrictions to fill the gap.

## Automated validation

Phase 1 automated coverage must verify default OFF and reload-like fresh load, mode switching, idempotent same-mode start, no duplicate subscriptions, no records after OFF, clear behavior, stable dump ordering, the hard cap and visible truncation flag, secret-safe health handling, and no SavedVariables persistence. Regression coverage must also check that stopping or switching research leaves existing Proc/Mobility subscriptions and behavior intact, and all new Lua remains compatible with Lua 5.1.

Phase 1.1 coverage additionally checks event-specific cast bar positions on START/STOP/FAILED/SUCCEEDED and channel START/UPDATE/STOP, INTERRUPTED ordering, secret `interruptedBy`, public cast bar IDs alongside unavailable/restricted cast GUIDs, SENT capture without reading its target, and one optional channel snapshot per eligible player event. Snapshot tests include public fields, independent restricted fields, missing API, failed/no-result calls, and inaccessible unit identity. The format=2 header and ordering, unchanged first 17 column meanings, research revision, absence of polling, and absence of new SavedVariables remain part of the validation boundary.

The new coverage lives in [`tests/class_tools_research_smoke.lua`](../tests/class_tools_research_smoke.lua) and is included by the main smoke suite. From the repository root, run `python tests/run_tests.py --addon-root .` in an environment that already has `lupa.lua51`; the runner requires actual Lua 5.1 and does not silently skip the full suite or install dependencies. Run the complete existing test suite as well as the new research tests before opening the PR. Mock results are reported separately from unperformed live-client acceptance. They do not certify combat secrecy, taint, native-client event access, or actual gameplay event order.
