# Phase 2A — Blink / Shimmer API audit

> Historical alpha.5 record. The user later reported out-of-combat success but no combat display. Alpha.6 replaced the blanket secret-charge hiding branch; its implementation/evidence/remaining limits are in [the combat audit](Mobility-Combat-API-Audit.md). Detection, native text and event details here remain historical reference.

Only Blink **1953** and Shimmer **212653** were reviewed. Target declarations: **Retail 12.1.0 / build 69933 / Interface 120100**, pinned Blizzard UI mirror `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`. The user's actual version/build was **unknown**; a TOC is not live evidence. Options → Mobility → Copy diagnostics obtains version/build/date/Interface from GetBuildInfo.

## Detection

`C_SpellBook.IsSpellKnown(spellID, spellBank=Player) -> bool` checks both IDs. `C_Spell.GetOverrideSpell(spellIdentifier, spec=0, onlyKnown=true, ignoreOverrideSpellID=0) -> number` resolves learned overrides; default spec means current, and no override returns the original ID.

Select Shimmer only when it is learned, Blink resolves to 212653 and Shimmer itself still resolves to 212653. Otherwise select Blink only when Shimmer is not learned, Blink is learned and still resolves to 1953. Learning/override disagreement reports Unknown and awaits real resynchronization, not a guess. An out-of-scope override reports Unsupported. No specialization is required to query.

DoesSpellExist proves database existence only; IsSpellInSpellBook may include unlearned replacements. Neither proves learning. SpellBookDocumentation line 666 and SpellDocumentation line 165 provide the signatures. Levels/talent capacities are not hardcoded; actual replacement behavior still needs client acceptance.

| Source | Use and boundary |
| --- | --- |
| GetSpellCharges(spellIdentifier) → SpellChargeInfo? | Validate actual maxCharges. Readable currentCharges ≥1 hides; exactly zero plus valid recharge displays. Nil alone is neither Ready nor zero. |
| maxCharges / isActive | Declared NeverSecret. isActive means recharging, not depleted. |
| currentCharges / cooldownStartTime / cooldownDuration / chargeModRate | May be secret. Check issecretvalue before using count; no secret comparison/arithmetic and no manual recharge-time arithmetic. |
| GetSpellCooldown(spellIdentifier) → SpellCooldownInfo? | With no charge record, require a valid cooldown record and isEnabled=true rather than interpreting missing data as Ready. |
| isEnabled / isActive / isOnGCD | Declared NeverSecret. isOnGCD is guaranteed reliable only in response to SPELL_UPDATE_COOLDOWN, so it is not used for delayed/reload decisions. |

These APIs have MayReturnNothing and SecretWhenCooldownsRestricted. Individual never/always-secret spell attributes may override general policy. Neither universal combat secrecy nor universally readable self-spells follows from the declaration. SpellDocumentation line 250, SpellSharedDocumentation line 6 and SecretPredicatesDocumentation line 89 are retained below.

## Timing and rendering

1. Confirmed charge depletion uses GetSpellChargeDuration(spellIdentifier) → LuaDurationObject?, directly representing the **already-running next recharge**, never restarting at the final cast.
2. Non-charge skills use GetSpellCooldownDuration(spellIdentifier, ignoreGCD=false) → LuaDurationObject?, passing true here to exclude pure GCD. No duration threshold guesses GCD; usability/mana/range/control do not determine depletion. Both duration APIs are in SpellDocumentation line 233.
3. The object handle must be publicly accessible; internal time may remain secret. Check secrecy of duration:IsZero() before branching. Public zero can identify non-charge Ready; secret zero flows to native display. Zero charges with publicly zero duration reports Unknown and awaits a real event.
4. UI/Display.lua:RenderLiveMobility uses native DurationTextBinding. Public configured font.size ×16 and ×3 determine layout. It shares configured position/font/Scale without entering Preview string concatenation, empty-string comparison or text measurement, and never reads native output.

Historical concrete binding setup:

```lua
binding = C_DurationUtil.CreateDurationTextBinding()
formatter = C_StringUtil.CreateNumericRuleFormatter()
formatter:AddBreakpoint({ threshold = 0, step = 0.1,
    rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f" })
binding:SetFontString(fontString)
binding:SetTextFormat("No " .. publicSpellName .. "\n{}", {
    { property = Enum.DurationTextBindingProperty.RemainingDuration,
      formatter = formatter },
})
binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
binding:SetUpdateInterval(0.1)
binding:SetExpiredText("")
binding:SetZeroDurationText("")
binding:SetDuration(durationObject)
binding:Enable()
binding:UpdateFontString()
-- Hidden / disabled:
binding:Disable()
binding:SetToDefaults()
```

At alpha.5 publicSpellName came only from the addon's two-entry static catalog. RealTime uses engine timing modifiers; rounding up to one decimal avoids showing 0.0 before recovery. Empty expired/zero text clears the whole alert. New API state still decides reset/Ready, not manual counters or timers. Binding, shared format, numeric-rule and time-modifier declaration links are retained below. Later 1.0.0 public name localization does not change duration ownership.

## Exact historical restriction

**Secret currentCharges could not prove zero in alpha.5: Restricted hid live output.** Reviewed native boolean-alpha/color maps could not derive count==0 from a secret number. Recharge isActive cannot distinguish 1/2 from 0/2. Ordinary cooldown may exist between two usable charges, so was not treated as zero-count proof. CooldownViewer's charge-priority logic (line 909 below) neither proves every Blink/Shimmer case nor permits reading secret counts.

This differs from readable zero with secret internal time, which still uses native display. Secret non-charge time reports Tracking, letting binding handle active/zero/expiry; Lua does not label it Ready. Missing learning/override/secrecy/duration/binding APIs reports Unsupported; nil/inconsistent state reports Unknown. No pcall error probe, UI readback, cast history, fixed cooldown, manual counting or old snapshot estimates.

## Events, lifecycle and diagnostics

Only enabled Mage monitoring subscribed, querying at most two candidates per refresh without spellbook/buff scans.

| Event | Audited arguments |
| --- | --- |
| SPELL_UPDATE_CHARGES / SPELLS_CHANGED | None |
| SPELL_UPDATE_COOLDOWN | Optional spellID, baseSpellID, category, startRecoveryCategory, itemID; nil spellID means all. Coalesce and requery; do not calculate with secret event fields. |
| PLAYER_SPECIALIZATION_CHANGED | unitTarget; player only |
| PLAYER_TALENT_UPDATE / PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED | None |
| TRAIT_CONFIG_UPDATED | configID triggers rediscovery |
| PLAYER_ENTERING_WORLD | isInitialLogin, isUIReload |
| PLAYER_ALIVE / PLAYER_DEAD / PLAYER_UNGHOST | No used arguments; resynchronize |

SpellBook line 853, Unit line 3759, SpecializationInfo line 443, SharedTraits line 808 and shared/mainline EventImplementation line 297/221 supply event evidence.

C_Timer.NewTimer(0, callback) coalesces a burst into one cancelable next-turn refresh; no loop/unbounded retry. Native binding's 0.1-second interval updates text, not state scans. Disable cancels pending work, removes only module callbacks and clears live output; shared branding/Preview subscribers survive. Closing Options retains live. Same-entry Preview suppresses rendering only; stop rereads APIs. Combat stops TEST, retaining monitoring.

Diagnostics use a public-field whitelist, excluding raw charge tables, DurationObject, native text and account information. Historical SavedVariables retained positions, adding mobility.enabled and an unspecialized position only. Final offline/extracted tests are in delivery output. At that delivery, **real skills, secret/taint and native rendering were not client-tested**; see [historical acceptance](TESTING_MOBILITY.md).

## Retained pinned source links

The following are the original audit's source/continuation references, preserved with exact pins and line anchors. Their API/document filenames identify the corresponding evidence above.

- [Mobility-Combat-API-Audit.md](Mobility-Combat-API-Audit.md)
- [09b9db7948abc9b9648dedaab51eb0cf3ee67b31](https://github.com/Gethe/wow-ui-source/tree/09b9db7948abc9b9648dedaab51eb0cf3ee67b31)
- [SpellBookDocumentation.lua#L666](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua#L666)
- [SpellDocumentation.lua#L165](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L165)
- [SpellDocumentation.lua#L250](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L250)
- [SpellSharedDocumentation.lua#L6](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellSharedDocumentation.lua#L6)
- [SecretPredicatesDocumentation.lua#L89](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua#L89)
- [SpellDocumentation.lua#L233](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua#L233)
- [DurationTextBindingObjectAPIDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingObjectAPIDocumentation.lua)
- [DurationTextBindingSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingSharedDocumentation.lua)
- [NumericRuleFormatterSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericRuleFormatterSharedDocumentation.lua)
- [LuaDurationObjectSharedDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectSharedDocumentation.lua)
- [CooldownViewer.lua#L909](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua#L909)
- [SpellBookDocumentation.lua#L853](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua#L853)
- [UnitDocumentation.lua#L3759](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua#L3759)
- [SpecializationInfoDocumentation.lua#L443](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua#L443)
- [SharedTraitsDocumentation.lua#L808](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SharedTraitsDocumentation.lua#L808)
- [EventImplementation.lua#L297](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Game/Shared/EventImplementation.lua#L297)
- [EventImplementation.lua#L221](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Game/Mainline/EventImplementation.lua#L221)
- [TESTING_MOBILITY.md](TESTING_MOBILITY.md)
