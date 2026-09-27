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
        id = id, name = name, class = "PALADIN", specID = specID,
        auraID = auraID, overlaySources = {
            { overlayID = auraID, textureID = textureID, locationTypeName = location, scale = 1 },
        },
        regions = regions, requiresKnown = known, requiresAnyKnown = anyKnown,
        nativeEventOnly = eventOnly == true,
        evidence = "12.1.0.69933 SAO row " .. row .. "; docs/PROC_BATCH1.md",
    })
end

data:RegisterProcFactory("PALADIN", function(specID)
    if specID == 65 then
        return {
            Entry(65, "paladin_holy_infusion_light", "Infusion of Light", 54149, 459313, "Left", { "Left" }, { 53576 }, 4349),
            Entry(65, "paladin_holy_infusion_light_second", "Infusion of Light", 458213, 459313, "Right", { "Right" }, { 53576 }, 4628),
            Entry(65, "paladin_holy_divine_purpose", "Divine Purpose", 223819, 459314, "Top", { "Top" }, { 223817 }, 3232),
        }
    elseif specID == 66 then
        return {
            Entry(66, "paladin_protection_divine_purpose", "Divine Purpose", 223819, 459314, "Top", { "Top" }, { 223817 }, 3232),
        }
    elseif specID == 70 then
        return {
            Entry(70, "paladin_retribution_divine_purpose", "Divine Purpose", 408458, 459314, "Top", { "Top" }, { 408459 }, 4322),
            -- Without Light Within these are only cooldown-reset indicators,
            -- outside the Proc timer scope. The two choices are exclusive.
            Entry(70, "paladin_retribution_art_war", "Art of War", 406086, 450913, "Left", { "Left" }, { 406064, 1261113 }, 4312),
            Entry(70, "paladin_retribution_righteous_cause", "Righteous Cause", 402916, 450913, "Left", { "Left" }, { 402912, 1261113 }, 4303),
        }
    end
    return {}
end)
