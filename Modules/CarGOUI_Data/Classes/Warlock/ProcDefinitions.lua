local _, data = ...

-- Audited against Retail 12.1.0.69933, not a generic spell-name lookup.
-- All timers below use their exact graphical owner aura. Finite durations
-- are evidence only: no duration constants are used by the runtime.
-- See docs/PROC_BATCH1.md for DB2 rows, drivers, exclusions and client limits.
local function Entry(specID, id, name, auraID, textureID, location, locations, known, row, eventOnly, anyKnown)
    local regions = {}
    for _, region in ipairs(locations) do
        regions[#regions + 1] = { id = id .. "_" .. region:lower(),
            label = name .. " - " .. region, location = region }
    end
    return data:ProcDefinition({
        id = id, name = name, class = "WARLOCK", specID = specID,
        auraID = auraID, overlaySources = {
            { overlayID = auraID, textureID = textureID, locationTypeName = location, scale = 1 },
        },
        regions = regions, requiresKnown = known, requiresAnyKnown = anyKnown,
        nativeEventOnly = eventOnly == true,
        evidence = "12.1.0.69933 SAO row " .. row .. "; docs/PROC_BATCH1.md",
    })
end

data:RegisterProcFactory("WARLOCK", function(specID)
    if specID == 265 then
        return {
            Entry(265, "warlock_affliction_nightfall", "Nightfall", 264571, 449492, "LeftRight", { "Left", "Right" }, { 108558 }, 3693),
        }
    elseif specID == 266 then
        return {
            Entry(266, "warlock_demonology_demonic_core", "Demonic Core", 264173, 2888300, "LeftRight", { "Left", "Right" }, { 267102 }, 3697),
        }
    end
    -- Destruction: no admitted native finite-duration graphic in this audit.
    return {}
end)
