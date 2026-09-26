local _, data = ...

data:RegisterProcFactory("EVOKER", function(specID)
    local spec, aura, driver, anyDrivers
    if specID == 1467 then
        spec, aura, anyDrivers = "devastation", 359618, { 375721, 376872 }
    elseif specID == 1468 then
        spec, aura, driver = "preservation", 369299, 369297
    elseif specID == 1473 then
        spec, aura, driver = "augmentation", 392268, 396187
    else return {} end
    local result = { data:ProcDefinition({
        id = "evoker_" .. spec .. "_essence_burst", name = "Essence Burst", class = "EVOKER", specID = specID,
        auraID = aura, requiresKnown = driver and { driver } or nil, requiresAnyKnown = anyDrivers,
        condition = "Current specialization's audited Essence Burst driver; Devastation accepts Ruby OR Azure Essence Burst.",
        overlaySources = { { overlayID = aura, textureID = 4699056, locationTypeName = "Left", scale = 1 } },
        regions = { { id = "evoker_" .. spec .. "_essence_burst_left", label = "Essence Burst - Left", location = "Left" } },
        evidence = "69933 overlay rows 4057/4110/4243; target sc_evoker chooses 359618/369299/392268 by specialization; native timer never uses cast spell IDs.",
    }) }
    if specID == 1468 then
        result[#result + 1] = data:ProcDefinition({
            id = "evoker_preservation_lifespark", name = "Lifespark", class = "EVOKER", specID = 1468,
            auraID = 394552, requiresKnown = { 443177 },
            condition = "Preservation Lifespark talent 443177 explicitly triggers aura 394552 in target spell effects.",
            overlaySources = { { overlayID = 394552, textureID = 4699057, locationTypeName = "Top", scale = 1 } },
            regions = { { id = "evoker_preservation_lifespark_top", label = "Lifespark - Top", location = "Top" } },
            evidence = "69933 overlay row 4259; finite aura 394552; talent 443177 effect 1138908 Trigger Spell 394552. Unproven 443176 variant is not an aura fallback.",
        })
    end
    -- The hidden right graphic 361519 is not aliased to any spec's timer:
    -- its live lifetime association is not established by the target sources.
    return result
end)
