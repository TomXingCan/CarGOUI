local _, data = ...

-- These conditional return abilities are discovered and diagnosed separately.
-- They never replace the existing, client-tested Blink / Shimmer classifier.
-- Build-pinned Wago SpellName/Spell/SpellCooldowns 12.1.0.69933.
data:RegisterMageAdditionalMobility(function()
    return {
        { id = "mage_alter_time", baseSpellID = 342245, slot = 2,
            unsupportedReason = "Alter Time can return while its initial cast is cooling down; native return availability is not verified.",
            variants = {
                { spellID = 342245, spellName = "Alter Time",
                    audit = { build = 69933, cooldownMS = 60000, gcdMS = 0, source = "Wago:Spell:342245;SpellCooldowns:67212" } },
                { spellID = 342247, spellName = "Alter Time",
                    onlyWhenBaseOverride = true,
                    audit = { build = 69933, source = "Wago:Spell:342247" } },
            } },
        { id = "mage_reflection", spellID = 389713, spellName = "Reflection", slot = 3,
            unsupportedReason = "Reflection is available only after Blink / Shimmer; no audited native exhaustion-duration path exists for its return window.",
            audit = { build = 69933, source = "Wago:SpellName:389713;Spell:389713;Spell:389714" } },
    }
end)
