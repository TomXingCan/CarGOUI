local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Shadowstep is additionally verified in the build-pinned Wago DB2 tables.
data:RegisterMobilityClass("ROGUE", function(specID)
    local definitions = {
        { id = "rogue_sprint", spellID = 2983, spellName = "Sprint", slot = 1,
            audit = { build = 69933, cooldownMS = 120000, gcdMS = 0,
                categoryCooldownMS = 120000, source = "rogue.txt#L609" } },
        { id = "rogue_shadowstep", spellID = 36554, spellName = "Shadowstep", slot = 2,
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "Wago:SpellCooldowns:82249;SpellCategories:7589" },
            blockedIfKnown = { [454433] = "Death's Arrival grants a conditional free recast; native exhaustion semantics are not verified." },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 0,
                chargeCategory = 1206, rechargeMS = 30000, source = "Wago:SpellCooldowns:82249;SpellCategories:7589;SpellCategory:1206" } },
    }
    if specID == 260 then
        definitions[#definitions + 1] = { id = "rogue_grappling_hook", spellID = 195457,
            spellName = "Grappling Hook", slot = 3, specs = { [260] = true },
            chargeVisibility = { baseCooldownMS = 800, baseGCDMS = 0, boundaryMS = 800,
                ignoreGCD = true, audit = "rogue.txt:195457" },
            blockedIfKnown = { [454433] = "Death's Arrival grants a conditional free recast; native exhaustion semantics are not verified." },
            audit = { build = 69933, cooldownMS = 800, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 45000, source = "rogue.txt#L3416" } }
    end
    return definitions
end)
