local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Body and Soul is a passive trigger; Shield/Prayer of Mending cooldowns
-- cannot stand in for a movement charge, and are intentionally not registered.
data:RegisterMobilityClass("PRIEST", function()
    return {
        { id = "priest_angelic_feather", spellID = 121536, spellName = "Angelic Feather", slot = 1,
            chargeVisibility = { baseCooldownMS = 0, baseGCDMS = 1500, boundaryMS = 0,
                ignoreGCD = true, audit = "priest.txt#L2515" },
            audit = { build = 69933, cooldownMS = 0, gcdMS = 1500, categoryCooldownMS = 0,
                baseCharges = 3, rechargeMS = 20000, source = "priest.txt#L2515" } },
    }
end)
