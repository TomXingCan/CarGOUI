# Proc P0 diagnostic comparison and client acceptance

This is a controlled comparison protocol, not a claim that the reported P0 is fixed. [Issue #15](https://github.com/TomXingCan/CarGOUI/issues/15) remains open and blocks release. This round delivers only the diagnostics and Proc circuit-breaker subset of [issue #16](https://github.com/TomXingCan/CarGOUI/issues/16); its general reload-required settings framework remains unfinished.

## Packages and evidence boundaries

| Role | Revision | Use |
| --- | --- | --- |
| Confirmed pre-P0 RC2 code baseline | `72cbbcec577ea4809ac0cb7b03ad8b5db60d9290` | Starting code revision. The RC1 client report does not establish that RC2 has identical symptoms. |
| Diagnostic control | `dfc01f6ece382e32c01339bf9bc7e40e1b937458` | Baseline behavior with fixed session diagnostics. |
| Candidate runtime | `ebb1fa7052429cab222333a75a3ba07c1d2dfb4f` | Proc lifecycle and isolation changes, measured with the same diagnostic schema and producer. |

The final installer manifest records its exact source commit, including the documentation follow-up. Its production Lua files must match the candidate runtime revision above. The diagnostic control and candidate ship byte-identical `Core/ProcDiagnostics.lua` and `Core/Diagnostics.lua`.

Install each package's matching `CarGOUI` and `CarGOUI_Data` directories together. Do not mix files from the two packages. Keep the same saved configuration, client build, character, class, specialization, talents, enabled addons, locale, UI scale, location and workload for each matched pair. Preserve a SavedVariables backup before changing packages. Neither package requires a schema migration or a new SavedVariable.

Keep these evidence categories separate in every result:

| Category | What it establishes |
| --- | --- |
| Code facts | Owned allocation counters, registration bookkeeping, explicit cleanup paths, bounded error retention and the absence of a diagnostic polling loop. |
| RC1 user report | The symptoms and timing reported in #15. A report is an investigation input, not an independently reproduced measurement. |
| Hypotheses | Possible sources of growth, retained native work or incomplete construction. These need matched observations; do not label one as the cause from a single memory reading. |
| Offline tests | Mocked API failures, resource reuse, isolation and public/secret boundaries. These cannot prove native container disposal, secure listener completion, Retail memory behavior or a real-client fix. |
| Native acceptance pending | Client measurements and observed behavior collected with this protocol. Until reviewed, release remains blocked. |

## Recorded offline resource comparison

The actual-Lua fixture comparison uses the diagnostic control and candidate under the same conditions. The raw evidence files are `p0-resource-comparison.json` and `p0-failure-resource-comparison.json`; preserve their embedded source manifests with the acceptance record.

| Scenario | Diagnostic control | Candidate | Supported conclusion |
| --- | --- | --- | --- |
| Normal Fire / Frost setup | 8 / 3 Proc containers | 8 / 3 Proc containers | No normal container-count reduction is claimed. |
| Warm 40 class/spec contexts, including 36 eligible contexts | 97 stable regions / containers | 97 stable regions / containers | The warmed catalog covers the same resource set. |
| Repeat warmed contexts for 10 rounds; Fire/Frost 1,000 SHOW/HIDE cycles; 20 Stop/Configure cycles | Allocation increment 0 | Allocation increment 0 | Both implementations reuse normal warmed resources in this fixture. |
| One extra stable region in fresh Fire; CreateFont returns an object, then SetFont consistently throws; 30 direct protected Acquire calls without the safety budget | 30 failures, 30 returned wrappers and 30 returned Fonts; failed objects never registered | 30 failures, 1 returned wrapper and 1 returned Font; partial handle retained; no new allocation after the first failure | The candidate repairs this particular lost-registration/partial-construction path independently of quarantine. |

These observations do not identify the cause of the reported idle RC1 growth and are not client memory/CPU measurements. The native ownership audit also retains one reusable container per stable region; the proposed shared-container rewrite is not shipped. See [the native container contract](PROC_CONTAINER_CONTRACT.md) for its public-gating constraints.

## One explicit snapshot path

`/cui diagnostics` prints a snapshot without creating or opening Options. It uses the existing explicit memory/CPU sampling path. `/cui diagnostics copy` opens an independent read-only copy window; its Refresh action takes another snapshot. The copy window does not require Options and is not a gameplay monitor. Both commands work without starting TEST.

The snapshot is session-only. It does not write diagnostics to SavedVariables, force garbage collection, change profiling settings, start a ticker or install a per-frame sampling loop. Capture raw output as well as the numeric table; elapsed times in the table are operator observations, not timestamps inferred by the addon.

Sampling has a cost. Before the one-minute warm-up, take a command snapshot, open the copy window once, capture its first snapshot, then close it and take a second command snapshot. Record the memory difference and one-time diagnostic UI creation separately. Use this same warm-up procedure for every case. Do not open the copy window for the first time at minute 15 in only one package. Reopening it or pressing Refresh creates another measurement and must be noted. For the timed series, use `/cui diagnostics` consistently; an alternative copy-window series must be a separate, consistently sampled group.

Memory is runtime KB from the client API, not package size. Record `CarGOUI` and loaded `CarGOUI_Data` separately and sum them. If a module is not loaded, record that fact instead of inventing a reading. Include any detected retired package as a configuration discrepancy, rather than silently excluding it from a matched pair.

CPU sampling is optional. If used, enable profiling before the fresh session and keep it fixed for the whole matched group. Record cumulative CPU for both packages' loaded modules and compare deltas over the same elapsed interval. Do not compare a profiled candidate with an unprofiled control, and do not interpret “unavailable” as zero CPU.

## Matrix and timing

Run all 16 cases: two packages × Proc ON/OFF × Mobility ON/OFF × two Options paths. Start each case with a fresh client session or `/reload`; do not reuse the previous case's allocated frame pools. Set the intended switches before that reload so the “never open Options” case remains true during measurement.

| Dimension | Values |
| --- | --- |
| Package | Diagnostic control; candidate |
| Proc preference | ON; OFF |
| Mobility preference | ON; OFF |
| Options path | Never open Options; open, run contextual previews, stop and close |
| Timed samples | 1, 5, 15 and 30 minutes after the assigned warm-up setup |

For the Options path, perform the same sequence in each package before the one-minute sample: open General, Test Current Spec, Stop Test, open Mobility and test/stop its entry when available, open Proc and test/stop the selected region when available, then close Options. Do not silently enable a disabled feature to make its sample visible. Record the selected entry, unavailable controls, any incidental allocations and the memory change caused by this first UI/preview pass. Keep Options closed for the timed period. The other path never opens Options; the independent diagnostic copy window does not change that classification.

Free Move is controlled through the Mobility enabled preference; it is not an independent toggle in this matrix. Record whether the current context has a receiver, its reported tracking state and requested slot state. Do not describe requested tracking as observed Aura presence. Use the same Time Spiral exposure or lack of exposure in matched cases and record it in the workload notes.

Use the same reproducible workload throughout a matched case: for example, the same idle interval or the same documented Proc-trigger sequence. Record movement, combat, specialization changes, zoning and other deviations. Do not combine an idle control with a combat candidate. If the reported failure escalates during a run, capture the latest reachable snapshot, stop the run, reload and mark the case aborted with its actual elapsed time; leave later samples empty.

## Fields to record

Record the public fields exactly as labeled, including:

- Core/Data runtime memory and total, plus deltas from the one-minute sample; optional cumulative CPU and interval deltas.
- Cumulative actual returned owned allocations: wrappers, containers, Fonts, formatters, duration templates, artwork frames/textures and animation objects.
- Construction attempts, successes, failures and partial constructions. A returned object can exist even if it never reached the registry; do not substitute registry size for lifetime creation count.
- Current Proc registry stock, requested enabled/disabled flags, partial/uncertain handles, registered contexts, current-context slots and historical-context slots. Free Move stock is reported separately.
- API requested/completed/failed counts. “Completed” means the public call returned, not that secure native work or a dirty pass completed. Zero counts only mean no instrumented call was observed.
- Core router callbacks/events, owned hook parts, pending work, artwork stock and requested animation phases. These are addon bookkeeping, not a census of actual native listener or binding activity.
- Quarantine state, failure budget, generation, last public failure phase/reason, cleanup completion and retry result. The retained public error ring is capped at 16 entries of at most 160 bytes each; cumulative error counts can increase without increasing retained log size.
- Snapshot/copy-window cost and the first Options/preview construction cost, kept separate from steady-state growth.

The native listener state, copied binding state and actual Aura presence remain explicitly unobservable to these diagnostics. Do not add native button inspection, timer-text readback or secret-value serialization to fill those columns.

## Fault isolation and recovery checks

Use controlled development fault injection only in a separate test group; do not mix injected failures into the normal memory matrix. Confirm that repeated Proc failures reach the bounded budget and isolate Proc for the session. Existing Proc artwork, animations and timer samples must be cleaned up as far as the public API permits; Mobility, Free Move, their previews, Options and the diagnostic commands must remain usable.

After correcting a recoverable fault, `/cui proc retry` performs cleanup while Proc remains isolated, checks known construction blockers, then attempts to restart using the existing settings. Failed cleanup keeps Proc isolated and can be retried after correcting the public API failure. Unknown factory/slot completion, additive formatter failure, or deliberately non-repeatable preview initialization requires `/reload`; repeated explicit retries must not allocate another copy of the same poisoned object. Safe setters reuse their retained objects. A successful retry does not reset settings. An unchanged ordinary setter error may fail again and must re-isolate the session without opening an automatic retry loop.

Exercise close, Escape, combat entry, specialization changes and late owned animation completions. No stale Proc sample should restart after isolation. A requested native disable or restoration is not proof that the client finished it; record incomplete cleanup or an unobservable native result honestly.

## Interpretation and release decision

Compare memory trends across the matched 1/5/15/30-minute series and repeated cases. For already warmed entries and the same UI path, unexpected continued growth in actual allocation counts or registered owned work is a failure to investigate. Expected first-use construction must be identified separately. Stable registered counts do not prove memory is stable, and a lower memory reading does not prove all retained native work was released.

Do not run automatic GC. A manual GC comparison is allowed only as a separately labeled development control group with its own before/after readings. A one-time fall after manual or natural GC is not proof of a fix and must not replace the normal matrix.

Attach raw snapshots, completed table rows, build/configuration details, reproduction steps and aborted-run notes to the investigation. Offline success and the diagnostic/circuit-breaker subset are useful evidence, but #15 stays open and release remains blocked until the real-client report is reproduced or convincingly characterized, the candidate is tested under the same conditions, and the remaining native acceptance results are reviewed.
