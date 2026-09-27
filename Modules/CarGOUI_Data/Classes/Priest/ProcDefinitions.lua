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
        id = id, name = name, class = "PRIEST", specID = specID,
        auraID = auraID, overlaySources = {
            { overlayID = auraID, textureID = textureID, locationTypeName = location, scale = 1 },
        },
        regions = regions, requiresKnown = known, requiresAnyKnown = anyKnown,
        nativeEventOnly = eventOnly == true,
        evidence = "12.1.0.69933 SAO row " .. row .. "; docs/PROC_BATCH1.md",
    })
end

data:RegisterProcFactory("PRIEST", function(specID)
    if specID ~= 256 and specID ~= 257 and specID ~= 258 then return {} end
    local prefix = specID == 256 and "priest_discipline" or specID == 257 and "priest_holy" or "priest_shadow"
    -- The class-tree driver is present for all three specs. Hidden graphical
    -- aura 128654 is not passed to IsSpellKnown as a substitute for that driver.
    local surgeDrivers = specID == 257 and { 109186, 453783 } or { 109186 }
    local entries = {
        Entry(specID, prefix .. "_surge_light", "Surge of Light", 114255, 450933, "Left", { "Left" }, nil, 1080, false, surgeDrivers),
        Entry(specID, prefix .. "_surge_light_second", "Surge of Light", 128654, 450933, "Right", { "Right" }, nil, 1430, false, surgeDrivers),
    }
    if specID == 256 then
        entries[#entries + 1] = Entry(256, "priest_discipline_power_dark_side", "Power of the Dark Side", 198069, 592058, "LeftRight", { "Left", "Right" }, { 198068 }, 3146)
        -- Native artwork uses TriggerType=2 with threshold=2. Aura presence
        -- alone cannot bootstrap this graphic; only the public SHOW may gate it.
        entries[#entries + 1] = Entry(256, "priest_discipline_harsh_discipline", "Harsh Discipline", 373183, 469752, "Top", { "Top" }, { 373180 }, 4129, true)
    elseif specID == 257 then
        entries[#entries + 1] = Entry(257, "priest_holy_benediction", "Benediction", 1262766, 469752, "Top", { "Top" }, { 1262755 }, 4955)
    else
        -- Void Empowerment is an alternate verified driver, not an aura alias.
        entries[#entries + 1] = Entry(258, "priest_shadow_shadowy_insight", "Shadowy Insight", 375981, 627609, "Top", { "Top" }, nil, 4152, false, { 375888, 450138 })
        -- In this build Manifested Power grants the actual upgrade. The old
        -- Surge of Insanity talent 391399 only modifies damage/generation.
        entries[#entries + 1] = Entry(258, "priest_shadow_mind_flay_insanity", "Mind Flay: Insanity", 391401, 592058, "Left", { "Left" }, { 453783 }, 4290)
    end
    return entries
end)
