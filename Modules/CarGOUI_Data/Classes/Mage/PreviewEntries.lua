local _, data = ...
local addon = data.adapters.MAGE

-- External Preview reuses the audited native mapping, but its sample text
-- remains separate from live aura state. Saved region IDs are unchanged.
local function AddProcPreviews(entries, specID)
    for _, definition in ipairs(addon:GetProcDefinitions(specID)) do
        if definition.preview then
            for _, region in ipairs(definition.regions) do
                entries[#entries + 1] = {
                    id = region.id, label = region.label, specID = specID,
                    class = "MAGE", kind = "proc", region = region.region,
                    sourceSpellID = definition.overlayID,
                    overlayID = definition.overlayID, auraID = definition.auraID,
                    nativeLocation = region.location, nativeScale = definition.scale,
                    anchor = { x = region.anchor.x, y = region.anchor.y },
                    guide = { texture = region.guide.texture,
                        width = region.guide.width, height = region.guide.height,
                        flipH = region.guide.flipH },
                    sample = { timer = "8.0" },
                }
            end
        end
    end
end

function addon:ActivateEntries(specID)
    if self.activeModuleClass == "MAGE" and self.activeModuleSpec == specID then return false end
    local mobility = self:CreateMageMobilityEntry(specID)
    local entries = {}
    if mobility then entries[1] = mobility end
    AddProcPreviews(entries, specID)
    self.activeModuleClass, self.activeModuleSpec = "MAGE", specID
    self.activeMobilityEntry = mobility
    self.mobilityEntries = mobility and { [specID or 0] = mobility } or {}
    self.previewEntries = entries
    return true
end

function addon:DeactivateEntries()
    self.activeModuleClass, self.activeModuleSpec, self.activeMobilityEntry = nil, nil, nil
    self.mobilityEntries, self.previewEntries = nil, nil
    self.procDefinitions, self.procDefinitionSpec = nil, nil
end

function addon:GetPreviewEntries()
    local result = {}
    for _, entry in ipairs(self.previewEntries or {}) do
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
