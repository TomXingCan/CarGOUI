local _, data = ...

-- The actual Lava Surge passive is learned by Elemental / Restoration only.
-- Maelstrom Weapon threshold graphics are not finite-proc countdown targets.
data:RegisterProcFactory("SHAMAN", function(specID)
    if specID ~= 262 and specID ~= 264 then return {} end
    local spec = specID == 262 and "elemental" or "restoration"
    local result = { data:ProcDefinition({
        id = "shaman_" .. spec .. "_lava_surge", name = "Lava Surge", class = "SHAMAN", specID = specID,
        auraID = 77762, requiresKnown = { 77756 },
        condition = "Elemental / Restoration Lava Surge passive 77756; native aura is the instant Lava Burst proc.",
        overlaySources = { { overlayID = 77762, textureID = 449491, locationTypeName = "LeftRight", scale = 1 } },
        regions = {
            { id = "shaman_" .. spec .. "_lava_surge_left", label = "Lava Surge - Left", location = "Left" },
            { id = "shaman_" .. spec .. "_lava_surge_right", label = "Lava Surge - Right", location = "Right" },
        },
        evidence = "12.1.0.69933 overlay row 1204; finite aura 77762; passive 77756 is explicitly Elemental / Restoration in target spell data.",
    }) }
    if specID == 264 then
        result[#result + 1] = data:ProcDefinition({
            id = "shaman_restoration_high_tide", name = "High Tide", class = "SHAMAN", specID = 264,
            auraID = 288675, requiresKnown = { 157154 },
            condition = "Restoration High Tide talent 157154; finite Chain Heal bonus, not mana-resource counting.",
            overlaySources = { { overlayID = 288675, textureID = 2851788, locationTypeName = "Top", scale = 0.80000001192 } },
            regions = { { id = "shaman_restoration_high_tide_top", label = "High Tide - Top", location = "Top" } },
            evidence = "69933 overlay row 3881; SpellMisc 362564 -> Duration 63 finite; TraitDefinition 131799/132049 -> Restoration trees 1033/1034. See PROC_BATCH2.md.",
        })
    end
    return result
end)
