local _, addon = ...

-- Business data lives only in the Mage Load-on-Demand addon.
addon.mobilitySpells = { [1953] = "Blink", [212653] = "Shimmer" }
local positionIDs = {
    [62] = "mage_arcane_shimmer", [63] = "mage_fire_shimmer",
    [64] = "mage_frost_shimmer", [0] = "mage_unspecialized_mobility",
}

function addon:CreateMageMobilityEntry(specID)
    local id = positionIDs[specID or 0]
    if not id then return nil end
    return { id = id, specID = specID, class = "MAGE", kind = "mobility", region = "CENTER",
        anchor = { x = 0, y = 0 }, label = "Blink / Shimmer - mobility sample",
        sample = { message = "No Shimmer", timer = "8.0" } }
end

function addon:GetMobilityEntry()
    local class, specID = self:GetCurrentModuleIdentity()
    if class ~= "MAGE" then return nil end
    if self.activeModuleClass ~= class or self.activeModuleSpec ~= specID then
        self:RefreshActiveEntries()
    end
    return self.activeMobilityEntry
end
