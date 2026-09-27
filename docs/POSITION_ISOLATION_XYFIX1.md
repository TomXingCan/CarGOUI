# alpha.16 — independent Free move coordinates

This release integrates the supplied `alpha.15-xyfix.1` coordinate repair onto alpha.15 commit `10bbad6b53382a9f352676f207ba83cf961b4d96` (tree `a5bfb5c62d3421892216980268e372ab60e3711c`). It adds no Proc, spell, theme or combat-policy feature. The incoming repair ZIP was independently compared with the original installer and reviewed before integration.

The five originally referenced Desktop/test paths were unavailable. Matching repair ZIP and two explanatory documents were found in Downloads. The standalone `.patch` and historical full test-output file were not located; this integration reconstructed a repository-path unified diff from the two verified ZIPs and passed `git apply --check` on the current clean branch. It does not claim to have applied or inspected the missing original patch/test-output files.

- Original alpha.15 installer SHA256: `8587df4ea605f5c428f3b3b87d12a1d21c99841b1169b299115934f998abb950`.
- Incoming repair installer SHA256: `30bb22b07e07ef1a254015f7b81d073c8e96d6febcc02c6c819290cfc02a1631` (matches the supplied review).
- Incoming review document SHA256: `e31650859fb547334d108f7e524583691ac2eca18ddb516ea7f14319e5a92edd`.
- Incoming integration note SHA256: `ff5180ac95957b324f4eb8a7f502045e7082981f72d1d1e2b06ef9b1d3e2fc5f`.

The incoming ZIP changes 11 existing files and adds this document; 100 installed files match the original byte-for-byte. Release integration updates version/package metadata and documentation while retaining the supplied fix logic and eight additional regression groups.

## Confirmed cause in the uploaded archive

`Core/Database.lua:GetReminderPosition()` returned the class's single `mobility.position` table for **every** entry with `kind == "mobility"`. `CarGOUI_Data/Shared/FreeMoveDefinitions.lua` gives all 13 receivers that kind, plus `freeMove = true`. The latter flag was ignored by position lookup. The native and TEST renderers consequently used the same saved XY as ordinary movement reminders. Separate edit boxes did not imply independent storage.

Original reproduction in the offline environment: Free move starts at `(0,84)`; setting ordinary Mobility XY to `(180,-100)` moves Free move to `(180,-16)`. The patched behavior keeps Free move at `(0,84)`.

## Corrected ownership

- `classes[classToken].mobility.position`: the **ordinary Mobility group**, including its existing stable per-skill slots. This intentional group behavior is retained.
- `classes[classToken].mobility.freeMovePosition`: independent Free move offset, shared only across that class's specializations. It never adds `mobility.position` while rendering.
- `classes[classToken].proc[specID].regions[regionID].position`: each Proc region, unchanged.
- `options.position`: Options shell, unchanged.

Free move keeps the class Mobility font, scale, color and enable behavior. It is only position ownership that changes. The default Free move base anchor `(0,84)` remains for backward visual compatibility; its own XY is relative to that base, not relative to the ordinary group's user offset.

Both existing live and TEST paths call the corrected shared resolver. The existing TEST entry selector/input boxes/reset button are reused. No new page or control is introduced.

## Additive migration

Schema 5 remains backward compatible. A class without `freeMovePosition` gets one independent copy of **its own** normalized ordinary offset the first time that class is initialized. This preserves the old effective Free move position without applying Scale again. Existing independent coordinates win; future edits do not recopy the ordinary offset. Another class is not eagerly initialized or used as the default. Fresh classes start at independent `(0,0)` offsets.

Malformed existing independent values fall back to factory fields, not to another class. Position tables are detached so manually aliased/older saved tables cannot retain an invisible link. Proc region positions are also detached during normalization of the current spec, before direct region patches can modify a shared child table. The Proc alias case was reproduced using a deliberately constructed legacy fixture; it is not evidence that ordinary user saves all contain such aliases.

No saved data is deleted. A number left unsubmitted in an edit box was never persisted and cannot be recovered by migration.

## Coordinate-only updates

Pure position patches now re-anchor only the relevant existing wrapper/sample instead of calling `ApplySettings()` and reconfiguring every live module. This path does not query cooldowns, replace DurationObjects, reset bindings, set native-slot enablement, write visibility alpha, regenerate samples or allocate additional native containers. Mixed functional patches retain the existing update pipeline.

## Verification

The supplied review reports 183 tests under **Lua 5.4 with `setfenv`/`unpack` compatibility**. That historical report is distinct from this integration's actual **Lua 5.1 (`lupa.lua51`)** execution. The reconstructed incoming package passes all 183 tests here, including the unchanged original 175 and eight additional regression groups. The release script executes those tests and all three static suites again against the final extracted alpha.16 installer; its `.tests.txt` records the actual output, Git tree and verification result.

The unchanged alpha.15 production archive separately passes its original 175 tests under Lua 5.1. Running the appended XY tests against that isolated baseline fails exactly the eight new groups while the original 175 still pass; the ordinary offset edit reproduces Free move changing from `(0,84)` to `(180,-16)`. The incoming fix keeps it at `(0,84)`. The test diff is append-only, with no weakened original assertions. Independent review also checked non-default Mobility/Proc scales and native-root/UI scale ratio: live and Preview align, the Proc reference guide stays at its default point, and inactive-spec pooled frames are skipped.

The position-isolation matrix traverses all 40 catalogued specs, 96 configurable native/TEST Proc regions (including Mage), and 13 no-spec class contexts. Deliberately excluded/event-only Mage items are not silently made configurable; their native geometry is still included in unrelated-change snapshots. Tests also cover existing GUI Enter/reset, migration/reload, cross-class restoration, aliased saved position tables, multiple ordinary Warrior reminders, shared typography, and tripwires preventing position edits from querying/rebinding/reconfiguring live state.

**This development environment has Lua 5.1 but no WoW client.** The results are not actual secret-value/taint, screen-rendering, CPU/memory or real-client acceptance. Existing mapping acceptance boundaries remain unchanged; the matrix verifies coordinate behavior in the mock environment, not every Proc's actual game mapping.

## Install and acceptance

Exit WoW. Back up the current `CarGOUI`/`CarGOUI_Data` program folders and the CarGOUI SavedVariables, then replace only those two program folders from the release ZIP. Keep WTF and SavedVariables. Both TOCs and the displayed runtime version use `0.1.0-alpha.16`, distinct from the original alpha.15 and the supplied temporary repair package.

Outside combat, open `/cui` and use the existing TEST selector:

1. Select Free move, edit its XY and press Enter. Ordinary reminders and all Proc regions must stay in place.
2. Edit ordinary Mobility XY. The ordinary group moves; Free move and Proc regions stay in place.
3. Edit a Proc region. Only that region moves. Its opposite side and other Proc effects stay in place.
4. Reset Free move's offsets, then reset ordinary offsets separately. Neither operation resets the other scope.
5. Change font/Scale, switch spec, `/reload` and relog another class: preserve the intended shared typography and independent coordinates.
6. Confirm actual Time Spiral text, Blink/Shimmer, and live Proc timers still trigger/expire correctly. The original combat Options queue and automatic closure must remain intact.

No new functionality follows this repair in the same increment. Real-client position/Time Spiral/Proc/Mobility and combat-window acceptance remains with the user; no existing configuration is deleted to make the tests pass.
