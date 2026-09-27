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
        id = id, name = name, class = "DEATHKNIGHT", specID = specID,
        auraID = auraID, overlaySources = {
            { overlayID = auraID, textureID = textureID, locationTypeName = location, scale = 1 },
        },
        regions = regions, requiresKnown = known, requiresAnyKnown = anyKnown,
        nativeEventOnly = eventOnly == true,
        evidence = "12.1.0.69933 SAO row " .. row .. "; docs/PROC_BATCH1.md",
    })
end

data:RegisterProcFactory("DEATHKNIGHT", function(specID)
    if specID == 250 then
        return {
            Entry(250, "deathknight_blood_crimson_scourge", "Crimson Scourge", 81141, 511104, "LeftRight", { "Left", "Right" }, { 81136 }, 3166),
            Entry(250, "deathknight_blood_dance_midnight", "Dance of Midnight", 1264568, 449487, "Top", { "Top" }, { 1264506 }, 4960),
        }
    elseif specID == 251 then
        return {
            Entry(251, "deathknight_frost_rime", "Rime", 59052, 450930, "Top", { "Top" }, { 59057 }, 121),
            Entry(251, "deathknight_frost_killing_machine", "Killing Machine", 51124, 458740, "Left", { "Left" }, { 51128 }, 3150),
            -- Right artwork has its own finite owner aura. Never substitute
            -- the left aura or infer the right region from a Lua stack count.
            Entry(251, "deathknight_frost_killing_machine_second", "Killing Machine", 438833, 458740, "Right", { "Right" }, { 51128 }, 4495),
        }
    elseif specID == 252 then
        return {
            Entry(252, "deathknight_unholy_sudden_doom", "Sudden Doom", 81340, 450932, "Left", { "Left" }, { 49530 }, 120),
            Entry(252, "deathknight_unholy_sudden_doom_second", "Sudden Doom", 461135, 450932, "Right", { "Right" }, { 49530 }, 4649),
        }
    end
    return {}
end)
