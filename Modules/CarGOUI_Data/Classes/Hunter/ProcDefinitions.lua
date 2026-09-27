local _, data = ...

-- Retail 12.1.0.69933. Exact native graphic rows and current talent/buff
-- relationships are recorded in docs/PROC_BATCH3.md. No aura is queried here.
local function Source(id, texture, location)
    return { overlayID = id, textureID = texture, locationTypeName = location, scale = 1 }
end
local function Proc(specID, key, name, auraID, sources, locations, known, anyKnown, evidence)
    local id, regions = "hunter_" .. specID .. "_" .. key, {}
    for _, location in ipairs(locations) do
        regions[#regions + 1] = { id = id .. "_" .. location:lower(),
            label = name .. " - " .. location, location = location }
    end
    return data:ProcDefinition({ id = id, name = name, class = "HUNTER", specID = specID,
        auraID = auraID, overlaySources = sources, regions = regions,
        requiresKnown = known, requiresAnyKnown = anyKnown, nativeEventOnly = false,
        evidence = "12.1.0.69933; " .. evidence .. "; docs/PROC_BATCH3.md" })
end

data:RegisterProcFactory("HUNTER", function(specID)
    local result = {}
    if specID == 254 then
        result[#result + 1] = Proc(specID, "lock_and_load", "Lock and Load", 194594,
            { Source(194594, 450926, "Top") }, { "Top" }, nil, { 194595, 1301406 },
            "Overlay3043; talent194595 or Tactical Reload1301406 grants timed194594; current SimC lock_and_load_buff194594")
        result[#result + 1] = Proc(specID, "precise_shots", "Precise Shots", 260242,
            { Source(270436, 1029138, "LeftRight"), Source(270437, 1029139, "LeftRight") },
            { "Left", "Right" }, { 260240 }, nil,
            "Overlay3730/3731 owners explicitly reference driver260240, which names real260242; SimC precise_shots_buff260242")
    end
    if specID == 253 or specID == 254 then
        -- Actual learned talent IDs, not the hidden timer aura. MM can obtain
        -- Deathblow through its specialization talent or Dark Ranger branch.
        local drivers = specID == 253 and { 466930 } or { 343248, 466932 }
        result[#result + 1] = Proc(specID, "deathblow", "Deathblow", 378770,
            { Source(378770, 449487, "Bottom") }, { "Bottom" }, nil, drivers,
            "Overlay5084; current BM/MM Dark Ranger and MM Deathblow build actual buff378770")
    end
    if specID == 253 or specID == 255 then
        -- Three distinct finite consumable empowerment auras, each with its own
        -- provider. Never rebind one native slot or guess the next summoned beast.
        for _, beast in ipairs({ { "wyvern", "Wyvern", 471878 }, { "boar", "Boar", 472324 },
            { "bear", "Bear", 472325 } }) do
            result[#result + 1] = Proc(specID, "pack_leader_" .. beast[1],
                "Howl of the Pack Leader: " .. beast[2], beast[3],
                { Source(beast[3], 774420, "LeftRight") }, { "Left", "Right" }, { 471876 }, nil,
                "Overlay4745/4746/4747; finite next-Kill-Command empowerment; current SimC distinct ready buffs")
        end
    end
    return result
end)
