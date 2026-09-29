# Proc memory release-admission review for 1.0.1

Issue [#15](https://github.com/TomXingCan/CarGOUI/issues/15) remains open and a
P0 release-admission gate pending the author's focused final-RC review. This
is an unresolved admission decision, not a finding of a proven permanent
leak. Acceptance of independent artwork does not decide memory readiness.

## Evidence classification

| Source | Established observation | Limit |
| --- | --- | --- |
| Delivered code and failure-injection tests | Partial construction remains registered; retry and Proc quarantine are bounded; failed restoration retains ownership; native disable retains its dirty cleanup opportunity. | These fix concrete failure paths, not a demonstrated cause of normal-path memory growth. |
| Author report, WARLOCK/266, Demonic Core 264173 | One definition, two regions; Proc wrappers/containers/Fonts each remain at 2, with one separate requested Free move slot. Reported errors, partial construction and quarantine were zero. | This is author-provided context, not agent inspection of private native state. |
| Author memory observations | Reported totals of 3.90 MiB and 7.17 MiB; repeated growth into the twenty-plus MB range followed by return to single digits, on ground and in air with other addons disabled. | The full timestamped paired snapshots were not supplied for these totals. Two values do not establish a time series, total allocation or retained-leak rate. |
| Retained offline repeated-HIDE audit | In the specified PALADIN/65 two-definition/two-region control, render work dominated measured transient allocation. The proposed hidden-record reuse reduction was about 3%, without demonstrated speedup. | PALADIN control is not an exact replay of the WARLOCK configuration. Offline timings/allocation are not Retail performance. The proposal remains unapplied; no third performance package was made. |
| Author P1 independent-artwork acceptance | Four scoped functional checks passed on MAGE/62, Retail 69933, P1 `bc91f3fe975e`. | No memory acceptance, WARLOCK acceptance or universal source coverage follows from that report. |

A sawtooth curve is compatible with temporary allocation and collection; it
alone establishes neither a permanent leak nor acceptable processing cost.
The release gate removes access to legacy graphic takeover, but does not
replace native Timer containers or claim to repair unexplained memory growth.
Stable addon resource counts do not reveal private native listener counts.

The frozen baseline, candidate, R1 and P1 installers and prior raw evidence
remain unchanged. Documentation is supplemental and does not rewrite logs or
their diagnostic producers. Shared containers, hidden reuse, automatic GC,
global GC tuning and the full Reload framework remain outside this release.

## Minimal final-RC review

Use the newly identified RC once it is delivered; record its commit/checksum,
client build, class/spec, addon set, Proc strategy, Mobility and Free move
settings. Keep the agreed known WARLOCK/266 configuration for the previously
reported case. Do not repeat the whole historical experiment matrix.

1. Start a new session with Proc enabled, fixed Mobility/Free move settings and
   no Options visit. Exercise ordinary acquisition, consumption and ending of
   the actual Proc. Take manual `/cui diagnostics copy` snapshots at 1, 5, 15
   and 30 minutes. Preserve the full raw text beside the sample table.
2. After that series, briefly open Preview, stop/close Options, toggle Proc
   and switch away/back to the tested spec. Take a final snapshot after native
   cleanup has had a normal update opportunity. Compare the warmed resource
   stock and failure counters, not a requirement that static caches reach zero.
3. If an abnormal trend or functional failure remains, use a separate new
   session with Proc off and otherwise matched conditions. Do not compare a
   fresh session to an unrelated warmed one as though they were paired.

| RC / build / class-spec / addon set | Elapsed | Proc / Mobility / Free move / Options | Memory KB | Current resources / cumulative creations | Errors / partial / quarantine / functionality |
| --- | --- | --- | --- | --- | --- |
| Record once per session | 1 min | | | | |
| Same session | 5 min | | | | |
| Same session | 15 min | | | | |
| Same session | 30 min | | | | |
| Same session, after controlled settings cycle | Record actual time | | | | |

The manual command itself takes a snapshot and has measurement overhead; no
continuous sampling is installed. Keep natural collection observations
separate from an optional developer-run manual-GC experiment. A before/after
net memory delta is not total allocation, and one post-GC drop is not a fix.
No production code automatically collects or changes global GC parameters.

## Admission decision

- Already fixed: the identified partial-construction/retry/cleanup failure
  paths and delivered Proc-only isolation. Do not reimplement them.
- Not established: a permanent normal-path retained leak, its unique cause,
  or acceptable steady-state allocation/processing cost on Retail.
- Residual risk: unmeasured native work and ongoing normal-path allocation;
  the current release gate does not supply performance measurements.
- Current decision: keep #15 as a release blocker until the author reviews
  the focused final-RC evidence and explicitly accepts the residual risk or
  identifies a concrete failure for a minimal patch. Do not close or downgrade
  it automatically based on P1 or offline success.

Issue [#16](https://github.com/TomXingCan/CarGOUI/issues/16) still covers the
undelivered broader Reload-required framework. Only the completed diagnostics
and Proc quarantine subset is credited. No global recovery or automatic
restoration of Blizzard's manual opacity preference is claimed.
