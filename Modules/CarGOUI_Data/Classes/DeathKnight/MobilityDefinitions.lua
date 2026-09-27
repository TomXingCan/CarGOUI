local _, data = ...

-- https://github.com/SimulationCraft/simc/blob/18429d2f8fd75ebe7be92fec37394055a0254b77/SpellDataDump/deathknight.txt
data:RegisterMobilityClass("DEATHKNIGHT", function(specID)
    local advance = { id = "deathknight_deaths_advance", baseSpellID = 48265, slot = 1,
        variants = {
            { spellID = 48265, spellName = "Death's Advance",
                chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                    ignoreGCD = true, audit = "deathknight.txt#L512" },
                audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 0,
                    baseCharges = 1, rechargeMS = 45000, source = "deathknight.txt#L512" } },
        } }
    if specID == 251 or specID == 252 then
        advance.variants[#advance.variants + 1] = { spellID = 444347, spellName = "Death Charge",
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "deathknight.txt#L15072" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 0,
                baseCharges = 1, rechargeMS = 45000, source = "deathknight.txt#L15072" } }
    end
    return {
        advance,
        { id = "deathknight_wraith_walk", spellID = 212552, spellName = "Wraith Walk", slot = 2,
            audit = { build = 69933, cooldownMS = 60000, gcdMS = 1500, source = "deathknight.txt#L5410" } },
    }
end)
