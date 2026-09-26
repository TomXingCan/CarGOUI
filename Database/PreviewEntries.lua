local _, addon = ...

-- A deliberately small simulation catalog, not a live buff/cooldown database.
-- Region definitions come from the extracted 12.1.0.69587 client tables:
-- https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/spellactivationoverlay.csv
-- https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/screenlocation.csv
-- Geometry/orientation follows Blizzard's renderer (no artwork is bundled):
-- https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua
-- longSide = 256 * 0.8, shortSide = 128 * 0.8. A scale-1 side region's
-- center is longSide / 2 + shortSide / 2 = 153.6 from the screen center.
-- These are stock Blizzard region centers, not a shared central Proc anchor.
local longSide, shortSide = 256 * 0.8, 128 * 0.8
local distance = (longSide + shortSide) / 2

local function Mobility(specID, name)
    return {
        id = "mage_" .. name .. "_shimmer", label = "Shimmer - mobility sample",
        specID = specID, class = "MAGE", kind = "mobility", region = "CENTER",
        anchor = { x = 0, y = 0 },
        sample = { message = "No Shimmer", timer = "8.0" },
    }
end

local function Proc(specID, id, label, spellID, texture, region)
    local side = region ~= "TOP"
    return {
        id = id, label = label, specID = specID, class = "MAGE", kind = "proc",
        -- sourceSpellID documents the visual's client row; it is never queried.
        sourceSpellID = spellID, region = region,
        anchor = { x = side and (region == "LEFT" and -distance or distance) or 0,
            y = side and 0 or distance },
        guide = { texture = texture, width = side and shortSide or longSide,
            height = side and longSide or shortSide, flipH = region == "RIGHT" },
        sample = { timer = "8.0" },
    }
end

addon.previewEntries = {
    Mobility(62, "arcane"),
    Proc(62, "mage_arcane_clearcasting_left", "Clearcasting - left region", 276743, 449486, "LEFT"),
    Proc(62, "mage_arcane_clearcasting_right", "Clearcasting - right region", 276743, 449486, "RIGHT"),
    Mobility(63, "fire"),
    Proc(63, "mage_fire_hot_streak_left", "Hot Streak - left region", 48108, 449490, "LEFT"),
    Proc(63, "mage_fire_hot_streak_right", "Hot Streak - right region", 48108, 449490, "RIGHT"),
    Mobility(64, "frost"),
    -- Fingers of Frost uses two client rows for its independently placed regions.
    Proc(64, "mage_frost_fingers_left", "Fingers of Frost - left region", 44544, 449489, "LEFT"),
    Proc(64, "mage_frost_fingers_right", "Fingers of Frost - right region", 126084, 449489, "RIGHT"),
    Proc(64, "mage_frost_brain_freeze_top", "Brain Freeze - top region", 190446, 450930, "TOP"),
}

-- Additive configuration ID for players who have not selected a specialization.
local lowLevel = Mobility(nil, "unspecialized")
lowLevel.id = "mage_unspecialized_mobility"
lowLevel.label = "Blink / Shimmer - mobility sample"
addon.previewEntries[#addon.previewEntries + 1] = lowLevel

function addon:GetPreviewEntries()
    local _, class = UnitClass("player")
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    local specID = index and getInfo and getInfo(index)
    local result = {}
    for _, entry in ipairs(self.previewEntries) do
        if entry.class == class and entry.specID == specID then
            if entry.kind == "mobility" then
                -- The sample remains fixed, but its static name follows identification.
                local status = self.GetMobilityStatus and self:GetMobilityStatus()
                local name = status and status.spellName or "Shimmer"
                local sample = {}
                for key, value in pairs(entry) do sample[key] = value end
                sample.label = name .. " - mobility sample"
                sample.sample = { message = "No " .. name, timer = "8.0" }
                result[#result + 1] = sample
            else
                result[#result + 1] = entry
            end
        end
    end
    return result
end
