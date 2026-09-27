local _, data = ...

local function Proc(specID, key, name, auraID, talent, texture, locations, layout, evidence)
    local id, regions = "demonhunter_" .. specID .. "_" .. key, {}
    for _, location in ipairs(locations) do
        regions[#regions + 1] = { id = id .. "_" .. location:lower(), label = name .. " - " .. location, location = location }
    end
    return data:ProcDefinition({ id = id, name = name, class = "DEMONHUNTER", specID = specID,
        auraID = auraID, requiresKnown = talent and { talent } or nil,
        overlaySources = { { overlayID = auraID, textureID = texture, locationTypeName = layout, scale = 1 } },
        regions = regions, nativeEventOnly = false,
        evidence = "12.1.0.69933; " .. evidence .. "; docs/PROC_BATCH3.md" })
end

data:RegisterProcFactory("DEMONHUNTER", function(specID)
    if specID == 577 then
        return { Proc(specID, "chaos_theory", "Chaos Theory", 390195, 389687, 801267,
            { "Left", "Right" }, "LeftRight", "Overlay4225; Havoc talent389687 finite buff390195; current SimC chaos_theory_buff") }
    elseif specID == 581 then
        return { Proc(specID, "untethered_rage", "Untethered Rage", 1270476, 1270444, 450930,
            { "Top" }, "Top", "Overlay4983; Vengeance apex1270444 grants finite temporary free-Metamorphosis1270476; current SimC same buff") }
    elseif specID == 1480 then
        return { Proc(specID, "moment_of_craving", "Moment of Craving", 1238495, nil, 7549806,
            { "Top" }, "Top", "Overlay4853; Devourer talent1238488 OR set bonus1296616 grants finite buff1238495; exact native aura is authoritative for both sources; current SimC same buff") }
    end
    return {}
end)
