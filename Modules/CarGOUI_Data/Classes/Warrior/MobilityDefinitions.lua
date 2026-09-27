local _, data = ...

-- Extracted client 12.1.0.69933; metadata is never used as a running timer.
-- https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/warrior.txt
data:RegisterMobilityClass("WARRIOR", function(specID)
    local definitions = {
        { id = "warrior_charge", spellID = 100, spellName = "Charge", slot = 1,
            chargeVisibility = { baseCooldownMS = 1500, baseGCDMS = 0, boundaryMS = 1500,
                ignoreGCD = true, audit = "warrior.txt#L28" },
            audit = { build = 69933, cooldownMS = 1500, gcdMS = 0, categoryCooldownMS = 1000,
                baseCharges = 1, rechargeMS = 20000, source = "warrior.txt#L28" } },
        { id = "warrior_heroic_leap", spellID = 6544, spellName = "Heroic Leap", slot = 2,
            chargeVisibility = { baseCooldownMS = 1500, baseGCDMS = 0, boundaryMS = 1500,
                ignoreGCD = true, audit = "warrior.txt#L602" },
            audit = { build = 69933, cooldownMS = 1500, gcdMS = 0, categoryCooldownMS = 1000,
                baseCharges = 1, rechargeMS = 45000, source = "warrior.txt#L602" } },
        { id = "warrior_intervene", spellID = 3411, spellName = "Intervene", slot = 3,
            chargeVisibility = { baseCooldownMS = 1500, baseGCDMS = 0, boundaryMS = 1500,
                ignoreGCD = true, audit = "warrior.txt#L431" },
            audit = { build = 69933, cooldownMS = 1500, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 30000, source = "warrior.txt#L431" } },
    }
    if specID == 73 then
        definitions[#definitions + 1] = { id = "warrior_shield_charge", spellID = 385952,
            spellName = "Shield Charge", slot = 4, specs = { [73] = true },
            audit = { build = 69933, cooldownMS = 45000, gcdMS = 1500,
                source = "warrior.txt#L10112" } }
    end
    return definitions
end)
