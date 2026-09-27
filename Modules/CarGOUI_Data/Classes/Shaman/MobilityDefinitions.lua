local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Spirit Walk / Gust of Wind are talent-choice spells: learned-state filtering
-- selects the available one. Ghost Wolf is a form, not an exhaustion cooldown.
data:RegisterMobilityClass("SHAMAN", function(specID)
    local definitions = {
        { id = "shaman_spirit_walk", spellID = 58875, spellName = "Spirit Walk", slot = 1,
            audit = { build = 69933, cooldownMS = 60000, gcdMS = 0, source = "shaman.txt#L1262" } },
        { id = "shaman_gust_of_wind", spellID = 192063, spellName = "Gust of Wind", slot = 2,
            audit = { build = 69933, cooldownMS = 20000, gcdMS = 1500, source = "shaman.txt#L4127" } },
        { id = "shaman_wind_rush_totem", spellID = 192077, spellName = "Wind Rush Totem", slot = 4,
            audit = { build = 69933, cooldownMS = 120000, gcdMS = 1000, source = "shaman.txt#L4149" } },
    }
    if specID == 263 then
        definitions[#definitions + 1] = { id = "shaman_feral_lunge", spellID = 196884,
            spellName = "Feral Lunge", slot = 3, specs = { [263] = true },
            audit = { build = 69933, cooldownMS = 30000, gcdMS = 500, source = "shaman.txt#L4438" } }
    end
    return definitions
end)
