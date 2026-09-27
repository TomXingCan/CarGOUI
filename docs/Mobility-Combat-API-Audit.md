# Phase 2A combat repair — API audit

> Later feedback: the user confirmed alpha.6 Blink/Shimmer worked in their scenarios, without a full build/boundary matrix. This preserves the original development evidence and limits. Alpha.7 then added styles/themes; see [its historical record](ENTRY_STYLES.md).

This describes the `0.1.0-alpha.6` increment. Alpha.5 was reported to work out of combat but not after entering combat; that was not new-version acceptance. **Development had no real WoW client. Combat visibility, native timing and taint remained user acceptance tasks, not fully verified combat support.**

## Scope and evidence levels

Only actually learned/effective Blink **1953** and Shimmer **212653**. API source pin: `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`. Supplemental SimulationCraft data pin: `18429d2f8fd75ebe7be92fec37394055a0254b77`, **12.1.0.69933 / hotfix 2026-09-24**. Actual user build was unknown; use GetBuildInfo in Options → Mobility → Copy diagnostics.

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| API declarations | DurationObject, native curve, SetAlpha, text binding signatures/secret-argument restrictions | Which cooldown object C++ selects for these spells |
| Pinned-build extracted data | Reviewed use intervals, GCD, base charges and talent modifiers | Every environment, future hotfix, combat restriction or C++ selection rule |
| Offline contract tests | Lua behavior for supplied API inputs, secret boundaries, events/UI lifecycle | Actual secret/taint permission, native pixels or gameplay |
| User client acceptance | Build-specific observations using the checklist | Was not yet performed at initial delivery |

No EUI dependency, all-class database, SimC runtime or third-party art was imported. EUI MovementAlert at `394319df23b67d4b09850a78a8d6a542beb80140` supplied only the interface idea: ordinary cooldown native evaluation controls alpha. Its code was not copied wholesale and its fixed 1.6-second boundary was not reused. Original pinned links remain below.

## Root cause and selected paths

Alpha.5 ReadMobilityState returned Restricted immediately for secret currentCharges, never supplying a duration to live rendering. The repair keeps secrecy checks and separates **visibility** from **which time digits show**.

| Actual API condition | Visibility | Time / diagnostics |
| --- | --- | --- |
| Valid public currentCharges | ≥1 hidden; exactly zero and valid recharge shown | GetSpellChargeDuration; Ready/Depleted may be known |
| Secret count, public maxCharges==1 and isActive==true | With actual capacity one, public active recovery means its only charge is recovering; never extend this inference to multiple charges | Actual recharge; Depleted without reading secret count |
| Secret count, public maxCharges>1/isActive=true, required metadata/native capabilities available | Ordinary cooldown total BaseTime evaluated by native step curve, passed directly to SetAlpha | Digits still use recharge; **Native tracking**, not Lua-known Ready/Depleted |
| Secret count, public isActive=false | Hidden/Unknown; no active recharge may also reflect zero-time/unavailable data, not proven Ready | No absent active timer bound |
| No charge record, valid ordinary cooldown record | Independent non-charge path excludes GCD | GetSpellCooldownDuration(spellID,true); nil charges alone is not Ready |
| Missing API/object/trustworthy public metadata | Explicit Unsupported/Unknown/Restricted, safely hidden | No old snapshots, fixed seconds or samples |

maxCharges/isActive are NeverSecret in SpellChargeInfo, but code still checks secrecy/type. Multicharge isActive means only recharging, never depletion. Silence/control/range/mana/IsSpellUsable=false do not participate.

## Separate duration responsibilities

GetSpellChargeDuration(spellID) returns the already-running next recharge. Spending the last charge several seconds later preserves that progress. The audited Spell declaration gives this API **no ignoreGCD parameter**.

For secret multicharge visibility, GetSpellCooldownDuration(spellID,false) retains ordinary cooldown native selection; do not indiscriminately pass true. It and charge duration are separate queries with separate purposes.

```lua
-- Public curve/enum; returned alpha may remain secret.
frame:SetAlpha(cooldownDuration:EvaluateTotalDuration(curve,
    Enum.DurationTimeModifier.BaseTime))
-- The digits use the existing next recharge instead.
binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
binding:SetDuration(chargeDuration)
```

EvaluateTotalDuration computes natively. BaseTime excludes the object's mod-time acceleration/deceleration; RealTime handles actual countdown. SimpleRegion SetAlpha explicitly permits secret arguments from tainted callers. Lua never compares, calculates, concatenates, serializes or reads back the curve output.

The implementation does not call curve:Evaluate(secretCurrentCharges): LuaCurveObject marks that parameter AllowedWhenUntainted, not permission for ordinary addon secret-count input. Reviewed Spell/SpellBook/ActionBar/CooldownViewer declarations had no dedicated public charge-depleted predicate.

## Visibility boundary evidence and limitations

Pinned-build base data below is **not a source of runtime countdown constants**:

| Skill | Interval between uses | GCD | Base charges | Base recharge |
| --- | --- | --- | --- | --- |
| Blink 1953 | 0.5 s | 1.5 s | 1 | 20 s |
| Shimmer 212653 | 0.5 s | 0 s | 1 | 30 s |

Evidence: Mage data line 220/4737 and generated fields line 459, retained below. Shimmer has no GCD but still a short use interval, so nonzero ordinary cooldown alone is insufficient.

Runtime global GetSpellBaseCooldown queries ordinary cooldown/GCD metadata for both supported IDs. Values must be public, finite, nonnegative and have maximum **exactly the audited 1500 ms bound**. The cached step curve then uses `(boundary+1)/1000`: **one millisecond above the bound**, solely excluding an interval/GCD equal to it. This is not a timer, delay or cast estimate. Missing/secret/invalid/mismatched metadata yields `Restricted / blocked: native charge visibility`. A longer recharge cannot become the threshold; no hidden fixed-1.6 fallback exists.

That global API is absent from the generated C_Spell document, so existence/return semantics still need capability checks and client acceptance. If it returns 20/30-second recharge, all zeroes or other mismatched metadata, the secret multicharge path explicitly blocks. **Its return behavior was not observed in the user's client, and blocked fallback is not completed combat support.** Public-count and valid single-capacity paths do not need this metadata gate. There is no build-number allowlist: actual build is logged; capabilities/results determine activation, with acceptance still required.

Input is **total BaseTime**, not remaining time, or an actual recovery at 0.2 seconds would disappear incorrectly. Public metadata supplies only the interval/recharge separator; secret timing is not read to build the curve.

Reviewed same-build modifiers include Flow of Time -3 s, Improved Blink -2 s, Bronze -15%, extra-charge talents and Time Walk reset. These reduced base periods remain distinct from 0.5/1.5-second intervals, but do not prove every old-content mechanism or future hotfix.

**Critical client-unverified condition:** ordinary C++ cooldown selection must yield zero/short interval while a charge remains and the real recovery period's total duration when empty. Depleting with under 0.5/1.5 seconds left in the first recovery, or under reduction/recovery changes, has no documented selection guarantee. A short remaining interval or genuine period below the boundary could miss; a long recovery object with an available charge could falsely show. Mocks cannot turn this unknown native semantic into established fact. Use the boundary acceptance checklist.

## Display, lifecycle and class color

Native visibility exclusively controls live parent alpha. DurationTextBinding owns child time text, not parent alpha. Styling does not write live alpha. Noncurve paths restore ordinary alpha explicitly when reusing frames. Active updates do not first Hide/clear bindings; only invalid or Preview-suppressed entries are cleared.

PLAYER_REGEN_DISABLED stops TEST and branding animation, not Mobility subscriptions. Closing Options/stopping Preview restores or refreshes live rather than unloading its events or valid binding. Separate pools isolate Preview/live. Existing events and a one-shot coalesced task remain; no persistent scan/per-frame Lua queries.

Shared reminder style uses UnitClass("player") token and C_ClassColor.GetClassColor, caches copied color on demand and applies SetTextColor to name/digits. Invalid color uses safe fallback and later recovers. No saved character RGB, global color/font mutation or separate Preview color logic. Reused frames/font refreshes use the same function. Options labels, TEST helpers and branding retain their own functional colors. At this stage no color picker/mode existed; later Proc RGB does not change Mobility's fixed class color.

Every live duration comes from a current API DurationObject. No secret digit/output readback, cast history, manual counting, precombat snapshot, fixed recovery, UI inference or error probing. Missing APIs, learning/override inconsistency and unavailable objects retain explicit fallback, never labeled completed combat support.

## Retained pinned source links

Exact original source pins and line anchors are retained here; API/document filenames and data line anchors identify the evidence discussed above.

- [ENTRY_STYLES.md](ENTRY_STYLES.md)
- [09b9db7948abc9b9648dedaab51eb0cf3ee67b31](https://github.com/Gethe/wow-ui-source/tree/09b9db7948abc9b9648dedaab51eb0cf3ee67b31)
- [build_info.txt](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/build_info.txt)
- [Mobility-Combat-Acceptance.md](Mobility-Combat-Acceptance.md)
- [EllesmereUIQoL_MovementAlert.lua](https://github.com/EllesmereGaming/EllesmereUI/blob/394319df23b67d4b09850a78a8d6a542beb80140/EllesmereUIQoL/EllesmereUIQoL_MovementAlert.lua)
- [SpellSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua)
- [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)
- [LuaDurationObjectSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectSharedDocumentation.lua)
- [SimpleRegionAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua)
- [LuaCurveObjectAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaCurveObjectAPIDocumentation.lua)
- [mage.txt#L220](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L220)
- [mage.txt#L4737](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L4737)
- [spell_data.hpp#L459](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/engine/dbc/spell_data.hpp#L459)
- [mage.txt#L9274](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L9274)
- [mage.txt#L15370](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15370)
- [evoker.txt#L5246](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/evoker.txt#L5246)
- [mage.txt#L15195](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15195)
- [mage.txt#L15232](https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/mage.txt#L15232)
