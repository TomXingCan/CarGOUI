local _, data = ...

-- Client 12.1.0.69933: build-pinned Wago Spell/SpellCooldowns/SpellCategories.
-- Only the teleport cooldown is tracked, never circle placement or range.
-- Burning Rush is a toggle and Gateway use has a separate per-player lockout.
data:RegisterMobilityClass("WARLOCK", function()
    return {
        { id = "warlock_demonic_circle_teleport", spellID = 48020,
            spellName = "Demonic Circle: Teleport", slot = 1,
            audit = { build = 69933, cooldownMS = 30000, gcdMS = 1500,
                source = "Wago:Spell:48020;SpellCooldowns:3370;SpellCategories:10702" } },
    }
end)
