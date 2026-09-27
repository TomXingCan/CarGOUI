local _, data = ...

data:RegisterProcFactory("ROGUE", function(specID)
    if specID == 259 then
        return { data:ProcDefinition({
            id = "rogue_assassination_blindside", name = "Blindside", class = "ROGUE", specID = 259,
            auraID = 121153, requiresKnown = { 328085 },
            condition = "Assassination Blindside talent 328085; not the obsolete cast spell 111240.",
            overlaySources = { { overlayID = 121153, textureID = 449493, locationTypeName = "LeftRight", scale = 1 } },
            regions = {
                { id = "rogue_assassination_blindside_left", label = "Blindside - Left", location = "Left" },
                { id = "rogue_assassination_blindside_right", label = "Blindside - Right", location = "Right" },
            },
            evidence = "69933 overlay row 1246; finite aura 121153; target sc_rogue selects this buff from the current Blindside talent.",
        }) }
    elseif specID == 260 then
        return { data:ProcDefinition({
            id = "rogue_outlaw_opportunity", name = "Opportunity", class = "ROGUE", specID = 260,
            auraID = 195627, requiresKnown = { 279876 },
            condition = "Outlaw Opportunity talent 279876; partial charges stay under native Aura ownership.",
            overlaySources = { { overlayID = 195627, textureID = 450926, locationTypeName = "Top", scale = 1 } },
            regions = { { id = "rogue_outlaw_opportunity_top", label = "Opportunity - Top", location = "Top" } },
            evidence = "69933 overlay row 3071; finite Pistol Shot bonus aura 195627; current talent 279876 and sc_rogue link this exact effect.",
        }) }
    elseif specID == 261 then
        return { data:ProcDefinition({
            id = "rogue_subtlety_ancient_arts", name = "Ancient Arts", class = "ROGUE", specID = 261,
            auraID = 1269163, requiresKnown = { 1268939 },
            condition = "Subtlety Ancient Arts final talent 1268939; timer tracks its finite finishing-move aura, not Shadow Techniques stacks.",
            overlaySources = { { overlayID = 1269163, textureID = 656728, locationTypeName = "LeftRight", scale = 1.29999995232 } },
            regions = {
                { id = "rogue_subtlety_ancient_arts_left", label = "Ancient Arts - Left", location = "Left" },
                { id = "rogue_subtlety_ancient_arts_right", label = "Ancient Arts - Right", location = "Right" },
            },
            evidence = "69933 overlay row 4974; finite aura 1269163; current sc_rogue ancient_arts_3 selects, triggers and consumes that exact buff.",
        }) }
    end
    return {}
end)
