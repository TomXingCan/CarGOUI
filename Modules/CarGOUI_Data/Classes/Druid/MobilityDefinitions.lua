local _, data = ...

-- Client 12.1.0.69933, SimC 18429d2f8fd75ebe7be92fec37394055a0254b77.
-- Form variants share one reminder. Only the native current override is selected.
data:RegisterMobilityClass("DRUID", function()
    return {
        { id = "druid_dash", baseSpellID = 1850, slot = 1,
            variants = {
                { spellID = 1850, spellName = "Dash",
                    audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500,
                        categoryCooldownMS = 120000, source = "druid.txt#L358" } },
                { spellID = 252216, spellName = "Tiger Dash",
                    audit = { build = 69933, cooldownMS = 45000, gcdMS = 1500,
                        categoryCooldownMS = 45000, source = "druid.txt#L7994" } },
            } },
        { id = "druid_wild_charge", baseSpellID = 102401, slot = 2,
            variants = {
                { spellID = 102401, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000, source = "druid.txt#L3034" } },
                { spellID = 16979, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000, source = "druid.txt#L1021" } },
                { spellID = 49376, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000, source = "druid.txt#L2000" } },
                { spellID = 102383, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000, source = "druid.txt#L3010" } },
                { spellID = 102417, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000, source = "druid.txt#L3061" } },
                { spellID = 102416, spellName = "Wild Charge",
                    audit = { build = 69933, cooldownMS = 15000, gcdMS = 0, categoryCooldownMS = 15000,
                        source = "Wago:Spell:102416;SpellCooldowns:8836;SpellCategories:24322" } },
            } },
        { id = "druid_stampeding_roar", baseSpellID = 106898, slot = 3,
            variants = {
                { spellID = 106898, spellName = "Stampeding Roar",
                    audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500,
                        categoryCooldownMS = 120000, source = "druid.txt#L3517" } },
                { spellID = 77761, spellName = "Stampeding Roar",
                    audit = { build = 69933, cooldownMS = 120000, gcdMS = 1500, source = "druid.txt#L2468" } },
                { spellID = 77764, spellName = "Stampeding Roar",
                    audit = { build = 69933, cooldownMS = 120000, gcdMS = 1000, source = "druid.txt#L2493" } },
            } },
    }
end)
