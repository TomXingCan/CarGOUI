local _, addon = ...

-- Only these player spells are supported. This is not the Proc sample catalog.
addon.mobilitySpells = { [1953] = "Blink", [212653] = "Shimmer" }
addon.mobilityEntries = {
    [62] = { id = "mage_arcane_shimmer", specID = 62 },
    [63] = { id = "mage_fire_shimmer", specID = 63 },
    [64] = { id = "mage_frost_shimmer", specID = 64 },
    [0] = { id = "mage_unspecialized_mobility" },
}
for _, entry in pairs(addon.mobilityEntries) do
    entry.class, entry.kind, entry.region = "MAGE", "mobility", "CENTER"
    entry.anchor = { x = 0, y = 0 }
end

function addon:GetMobilityEntry()
    local _, class = UnitClass("player")
    if issecretvalue and issecretvalue(class) then return end
    if class ~= "MAGE" then return end
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    if issecretvalue and issecretvalue(index) then return end
    local specID = index and getInfo and getInfo(index)
    if issecretvalue and issecretvalue(specID) then return end
    return self.mobilityEntries[specID or 0]
end
