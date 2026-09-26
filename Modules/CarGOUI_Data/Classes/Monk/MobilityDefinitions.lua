local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Transfer is verified separately in build-pinned Wago DB2, not summon CD.
data:RegisterMobilityClass("MONK", function(specID)
    local definitions = {
        { id = "monk_roll", baseSpellID = 109132, slot = 1,
            variants = {
                { spellID = 109132, spellName = "Roll",
                    chargeVisibility = { baseCooldownMS = 800, baseGCDMS = 0, boundaryMS = 800,
                        ignoreGCD = true, audit = "monk.txt#L463" },
                    audit = { build = 69933, cooldownMS = 800, gcdMS = 0, categoryCooldownMS = 0,
                        baseCharges = 2, rechargeMS = 20000, source = "monk.txt#L463" } },
                { spellID = 115008, spellName = "Chi Torpedo",
                    chargeVisibility = { baseCooldownMS = 0, baseGCDMS = 0, boundaryMS = 0,
                        ignoreGCD = true, audit = "monk.txt#L548" },
                    audit = { build = 69933, cooldownMS = 0, gcdMS = 0, categoryCooldownMS = 0,
                        baseCharges = 2, rechargeMS = 20000, source = "monk.txt#L548" } },
            } },
        { id = "monk_transcendence_transfer", spellID = 119996,
            spellName = "Transcendence: Transfer", slot = 2,
            audit = { build = 69933, cooldownMS = 45000, gcdMS = 1500,
                source = "Wago:Spell:119996;SpellCooldowns:10803;SpellCategories:28043" } },
        { id = "monk_tigers_lust", spellID = 116841, spellName = "Tiger's Lust", slot = 4,
            audit = { build = 69933, cooldownMS = 30000, gcdMS = 1500, source = "monk.txt#L1416" } },
    }
    if specID == 269 then
        definitions[#definitions + 1] = { id = "monk_flying_serpent_kick", baseSpellID = 101545,
            slot = 3, specs = { [269] = true }, variants = {
                { spellID = 101545, spellName = "Flying Serpent Kick",
                    audit = { build = 69933, cooldownMS = 30000, gcdMS = 1000, source = "monk.txt#L291" } },
                { spellID = 115057, spellName = "Flying Serpent Kick",
                    onlyWhenBaseOverride = true,
                    unsupportedReason = "Flying Serpent Kick landing stage is not the original movement cooldown.",
                    audit = { build = 69933, source = "monk.txt#L586" } },
            } }
    end
    return definitions
end)
