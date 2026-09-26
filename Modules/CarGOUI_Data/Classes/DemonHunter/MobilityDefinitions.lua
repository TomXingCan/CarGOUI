local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
data:RegisterMobilityClass("DEMONHUNTER", function(specID)
    local movement = { id = "demonhunter_movement", baseSpellID = 344865, slot = 1,
        variants = {
            { spellID = 344865, spellName = "Fel Rush",
                chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 250, boundaryMS = 1000,
                    ignoreGCD = true, audit = "demonhunter.txt#L6973" },
                audit = { build = 69933, cooldownMS = 1000, gcdMS = 250, categoryCooldownMS = 0,
                    baseCharges = 1, rechargeMS = 10000, source = "demonhunter.txt#L6973" } },
        } }
    if specID == 577 then
        movement.variants[#movement.variants + 1] = { spellID = 195072, spellName = "Fel Rush",
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 500, boundaryMS = 1000,
                ignoreGCD = true, audit = "demonhunter.txt#L682" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 500, categoryCooldownMS = 500,
                baseCharges = 1, rechargeMS = 10000, source = "demonhunter.txt#L682" } }
        movement.variants[#movement.variants + 1] = { spellID = 427785, spellName = "Fel Rush",
            onlyWhenBaseOverride = true,
            unsupportedReason = "Fel Rush return stage: no audited next-original-use cooldown binding.",
            audit = { build = 69933, source = "demonhunter.txt#L10137" } }
    elseif specID == 581 then
        movement.variants[#movement.variants + 1] = { spellID = 189110, spellName = "Infernal Strike",
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "demonhunter.txt#L566" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 15000, source = "demonhunter.txt#L566" } }
    elseif specID == 1480 then
        movement.variants[#movement.variants + 1] = { spellID = 1234796, spellName = "Shift",
            chargeVisibility = { baseCooldownMS = 800, baseGCDMS = 0, boundaryMS = 800,
                ignoreGCD = true, audit = "demonhunter.txt#L13999" },
            audit = { build = 69933, cooldownMS = 800, gcdMS = 0, categoryCooldownMS = 800,
                baseCharges = 1, rechargeMS = 20000, source = "demonhunter.txt#L13999" } }
    end
    local definitions = {
        movement,
        { id = "demonhunter_vengeful_retreat", baseSpellID = 344866, slot = 2,
            variants = {
                { spellID = 344866, spellName = "Vengeful Retreat",
                    audit = { build = 69933, cooldownMS = 25000, gcdMS = 0,
                        categoryCooldownMS = 25000, source = "demonhunter.txt#L6992" } },
                { spellID = 198793, spellName = "Vengeful Retreat",
                    chargeVisibility = { baseCooldownMS = 750, baseGCDMS = 0, boundaryMS = 750,
                        ignoreGCD = true, audit = "demonhunter.txt#L915" },
                    audit = { build = 69933, cooldownMS = 750, gcdMS = 0, categoryCooldownMS = 0,
                        baseCharges = 1, rechargeMS = 25000, source = "demonhunter.txt#L915" } },
            } },
    }
    if specID == 577 or specID == 581 then
        definitions[#definitions + 1] = { id = "demonhunter_felblade", spellID = 232893,
            spellName = "Felblade", slot = 3, specs = { [577] = true, [581] = true },
            audit = { build = 69933, cooldownMS = 12000, gcdMS = 500, source = "demonhunter.txt#L4105" } }
    elseif specID == 1480 then
        definitions[#definitions + 1] = { id = "demonhunter_voidblade", spellID = 1245412,
            spellName = "Voidblade", slot = 3, specs = { [1480] = true },
            chargeVisibility = { baseCooldownMS = 0, baseGCDMS = 500, boundaryMS = 0,
                ignoreGCD = true, audit = "demonhunter.txt#L14790" },
            audit = { build = 69933, cooldownMS = 0, gcdMS = 500, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 30000, source = "demonhunter.txt#L14790" } }
    end
    if specID == 577 then
        definitions[#definitions + 1] = { id = "demonhunter_the_hunt", spellID = 370965,
            spellName = "The Hunt", slot = 4, specs = { [577] = true },
            audit = { build = 69933, cooldownMS = 90000, gcdMS = 1500,
                categoryCooldownMS = 90000, source = "demonhunter.txt#L7735" } }
        definitions[#definitions + 1] = { id = "demonhunter_metamorphosis", spellID = 191427,
            spellName = "Metamorphosis", slot = 5, specs = { [577] = true },
            audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500,
                categoryCooldownMS = 120000, source = "demonhunter.txt#L617" } }
    elseif specID == 1480 then
        definitions[#definitions + 1] = { id = "demonhunter_the_hunt", spellID = 1246167,
            spellName = "The Hunt", slot = 4, specs = { [1480] = true },
            audit = { build = 69933, cooldownMS = 90000, gcdMS = 1500,
                source = "demonhunter.txt#L15144" } }
    end
    return definitions
end)
