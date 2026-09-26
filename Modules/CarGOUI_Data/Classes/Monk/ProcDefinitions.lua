local _, data = ...

-- Target data and current spec/talent scopes: docs/PROC_BATCH3.md.
local function Proc(specID, key, name, auraID, texture, location, scale, known, anyKnown, evidence)
    local id = "monk_" .. specID .. "_" .. key
    return data:ProcDefinition({ id = id, name = name, class = "MONK", specID = specID,
        auraID = auraID, overlaySources = { { overlayID = auraID, textureID = texture,
            locationTypeName = location, scale = scale } },
        regions = { { id = id .. "_" .. location:lower(), label = name .. " - " .. location, location = location } },
        requiresKnown = known, requiresAnyKnown = anyKnown, nativeEventOnly = false,
        evidence = "12.1.0.69933; " .. evidence .. "; docs/PROC_BATCH3.md" })
end

data:RegisterProcFactory("MONK", function(specID)
    local result = {}
    if specID == 269 then
        result[#result + 1] = Proc(specID, "blackout_kick", "Blackout Kick!", 116768, 1001511,
            "Right", 1, nil, { 137384, 1250042 },
            "Overlay1132; WW Combo Breaker137384 or Echo Technique1250042 explicitly grants finite116768")
    end
    if specID == 269 or specID == 270 then
        result[#result + 1] = Proc(specID, "strength_black_ox", "Strength of the Black Ox", 443112, 623950,
            "Left", 1.20000004768, { 443110 }, nil,
            "Overlay4561; Conduit WW/MW talent443110 explicitly names actual443112; SimC same provider")
    end
    if specID == 270 then
        result[#result + 1] = Proc(specID, "zen_pulse", "Zen Pulse", 446334, 623951,
            "Right", 1.10000002384, { 446326 }, nil,
            "Overlay4572; MW talent446326 and finite dummy empowerment446334 reference each other")
    end
    if specID == 268 or specID == 270 then
        result[#result + 1] = Proc(specID, "potential_energy", "Potential Energy", 1270990, 469752,
            "Top", 1, { 1270958 }, nil,
            "Overlay4985; Master of Harmony BrM/MW Harmonic Surge1270958 grants finite1270990; SimC same provider")
    end
    return result
end)
