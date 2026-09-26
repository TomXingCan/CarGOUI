local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Mount visuals are effects of this ability, not separate movement cooldowns.
data:RegisterMobilityClass("PALADIN", function()
    return {
        { id = "paladin_divine_steed", spellID = 190784, spellName = "Divine Steed", slot = 1,
            chargeVisibility = { baseCooldownMS = 750, baseGCDMS = 0, boundaryMS = 750,
                ignoreGCD = true, audit = "paladin.txt#L4046" },
            audit = { build = 69933, cooldownMS = 750, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 45000, source = "paladin.txt#L4046" } },
    }
end)
