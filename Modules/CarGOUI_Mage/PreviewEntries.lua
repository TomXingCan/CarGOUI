local _, addon = ...

-- Preview only; these are the existing verified regions, not a live Proc DB.
-- Definitions are factories. Only the current specialization's entry tables
-- are instantiated; replacing them does not erase saved region coordinates.
-- Client row evidence and stock region geometry:
-- https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/spellactivationoverlay.csv
-- https://github.com/adavak/wow_db_csv_diff/blob/deabdc9acb4dec46ad55b9d281d6044118d8e4e9/same/screenlocation.csv
-- https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXML/SpellActivationOverlay.lua
local longSide, shortSide = 256 * 0.8, 128 * 0.8
local distance = (longSide + shortSide) / 2

local function Proc(specID, id, label, spellID, texture, region)
    local side = region ~= "TOP"
    return {
        id = id, label = label, specID = specID, class = "MAGE", kind = "proc",
        sourceSpellID = spellID, region = region,
        anchor = { x = side and (region == "LEFT" and -distance or distance) or 0,
            y = side and 0 or distance },
        guide = { texture = texture, width = side and shortSide or longSide,
            height = side and longSide or shortSide, flipH = region == "RIGHT" },
        sample = { timer = "8.0" },
    }
end

local factories = {
    [62] = function(entries)
        entries[#entries + 1] = Proc(62, "mage_arcane_clearcasting_left", "Clearcasting - left region", 276743, 449486, "LEFT")
        entries[#entries + 1] = Proc(62, "mage_arcane_clearcasting_right", "Clearcasting - right region", 276743, 449486, "RIGHT")
    end,
    [63] = function(entries)
        entries[#entries + 1] = Proc(63, "mage_fire_hot_streak_left", "Hot Streak - left region", 48108, 449490, "LEFT")
        entries[#entries + 1] = Proc(63, "mage_fire_hot_streak_right", "Hot Streak - right region", 48108, 449490, "RIGHT")
    end,
    [64] = function(entries)
        entries[#entries + 1] = Proc(64, "mage_frost_fingers_left", "Fingers of Frost - left region", 44544, 449489, "LEFT")
        entries[#entries + 1] = Proc(64, "mage_frost_fingers_right", "Fingers of Frost - right region", 126084, 449489, "RIGHT")
        entries[#entries + 1] = Proc(64, "mage_frost_brain_freeze_top", "Brain Freeze - top region", 190446, 450930, "TOP")
    end,
}

function addon:ActivateMageEntries(specID)
    if self.activeModuleClass == "MAGE" and self.activeModuleSpec == specID then return false end
    local mobility = self:CreateMageMobilityEntry(specID)
    local entries = {}
    if mobility then entries[1] = mobility end
    local factory = specID and factories[specID]
    if factory then factory(entries) end
    self.activeModuleClass, self.activeModuleSpec = "MAGE", specID
    self.activeMobilityEntry = mobility
    self.mobilityEntries = mobility and { [specID or 0] = mobility } or {}
    self.previewEntries = entries
    return true
end

function addon:GetPreviewEntries()
    local class, specID = self:GetCurrentModuleIdentity()
    if class ~= "MAGE" then return {} end
    if self.activeModuleClass ~= class or self.activeModuleSpec ~= specID then
        self:RefreshActiveEntries()
    end
    local result = {}
    for _, entry in ipairs(self.previewEntries) do
        if entry.kind == "mobility" then
            local status = self.GetMobilityStatus and self:GetMobilityStatus()
            local name = status and status.spellName or "Shimmer"
            local sample = {}
            for key, value in pairs(entry) do sample[key] = value end
            sample.label = name .. " - mobility sample"
            sample.styleKey = self:GetReminderStyleKey(entry, status and status.spellID or 212653)
            sample.sample = { message = "No " .. name, timer = "8.0" }
            result[#result + 1] = sample
        else
            result[#result + 1] = entry
        end
    end
    return result
end
