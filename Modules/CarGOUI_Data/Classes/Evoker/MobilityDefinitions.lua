local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Hover movement cooldown only: no Free Move / cast-while-moving monitoring.
data:RegisterMobilityClass("EVOKER", function(specID)
    local breath = { id = "evoker_deep_breath", baseSpellID = 357210, slot = 2,
        blockedIfKnown = { [1266151] = "Strafing Run grants a conditional free recast; native exhaustion semantics are not verified." },
        variants = {
            { spellID = 357210, spellName = "Deep Breath",
                chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 1500, boundaryMS = 1000,
                    ignoreGCD = true, audit = "Wago:SpellCooldowns:spellID=357210;SpellCategories:spellID=357210" },
                audit = { build = 69933, cooldownMS = 1000, gcdMS = 1500, categoryCooldownMS = 0,
                    baseCharges = 1, rechargeMS = 120000, source = "evoker.txt#L772" } },
            { spellID = 1236943, spellName = "Deep Breath", onlyWhenBaseOverride = true,
                audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500,
                    source = "Wago:Spell:1236943;SpellCooldowns:94438;SpellCategories:172942" } },
            { spellID = 371838, spellName = "Recall",
                onlyWhenBaseOverride = true,
                unsupportedReason = "Recall return stage has no audited next-original-flight duration binding.",
                audit = { build = 69933, source = "Wago:SpellName:371838;Spell:371838" } },
        } }
    if specID == 1467 then
        breath.variants[#breath.variants + 1] = { spellID = 433874, spellName = "Deep Breath",
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 1500, boundaryMS = 1000,
                ignoreGCD = true, audit = "Wago:SpellCooldowns:88494;SpellCategories:spellID=433874" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 1500, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 120000, source = "evoker.txt#L10247" } }
    elseif specID == 1473 then
        breath.variants[#breath.variants + 1] = { spellID = 403631, spellName = "Breath of Eons",
            audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500, source = "evoker.txt#L6836" } }
        breath.variants[#breath.variants + 1] = { spellID = 442204, spellName = "Breath of Eons",
            audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500, source = "evoker.txt#L10861" } }
    end
    local definitions = {
        { id = "evoker_hover", spellID = 358267, spellName = "Hover", slot = 1,
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "evoker.txt#L978" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 35000, source = "evoker.txt#L978" } },
        breath,
        { id = "evoker_verdant_embrace", spellID = 360995, spellName = "Verdant Embrace", slot = 3,
            chargeVisibility = { baseCooldownMS = 500, baseGCDMS = 1500, boundaryMS = 500,
                ignoreGCD = true, audit = "Wago:SpellCooldowns:71020;SpellCategories:122199" },
            audit = { build = 69933, cooldownMS = 500, gcdMS = 1500, categoryCooldownMS = 500,
                baseCharges = 1, rechargeMS = 24000, source = "evoker.txt#L1357" } },
        { id = "evoker_rescue", spellID = 370665, spellName = "Rescue", slot = 4,
            audit = { build = 69933, cooldownMS = 60000, gcdMS = 1500, source = "evoker.txt#L2932" } },
    }
    if specID == 1468 then
        definitions[#definitions + 1] = { id = "evoker_dream_flight", baseSpellID = 359816,
            slot = 5, specs = { [1468] = true }, variants = {
                { spellID = 359816, spellName = "Dream Flight",
                    audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500, source = "evoker.txt#L1199" } },
                { spellID = 371838, spellName = "Recall",
                    onlyWhenBaseOverride = true,
                    unsupportedReason = "Recall return stage has no audited next-original-flight duration binding.",
                    audit = { build = 69933, source = "Wago:SpellName:371838;Spell:371838" } },
            } }
    end
    return definitions
end)
