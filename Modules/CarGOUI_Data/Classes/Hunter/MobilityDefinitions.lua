local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
data:RegisterMobilityClass("HUNTER", function(specID)
    local definitions = {
        { id = "hunter_disengage", spellID = 781, spellName = "Disengage", slot = 1,
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "hunter.txt#L61" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 500,
                baseCharges = 1, rechargeMS = 20000, source = "hunter.txt#L61" } },
        { id = "hunter_aspect_of_the_cheetah", spellID = 186257, spellName = "Aspect of the Cheetah", slot = 2,
            audit = { build = 69933, cooldownMS = 180000, gcdMS = 0, source = "hunter.txt#L3340" } },
    }
    if specID == 255 then
        definitions[#definitions + 1] = { id = "hunter_harpoon", spellID = 190925,
            spellName = "Harpoon", slot = 3, specs = { [255] = true },
            chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 0, boundaryMS = 1000,
                ignoreGCD = true, audit = "hunter.txt#L3653" },
            audit = { build = 69933, cooldownMS = 1000, gcdMS = 0, categoryCooldownMS = 1000,
                baseCharges = 1, rechargeMS = 20000, source = "hunter.txt#L3653" } }
    end
    return definitions
end)
