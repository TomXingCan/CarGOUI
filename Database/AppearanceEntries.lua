local _, addon = ...

-- Appearance identities are separate from position identities. Blink and Shimmer
-- keep their existing specialization-specific position IDs, but each actual
-- spell has one style. Proc regions retain their already-defined region IDs.
addon.appearanceEntries = {
    { key = "mobility_blink", label = "Blink", kind = "mobility", spellID = 1953 },
    { key = "mobility_shimmer", label = "Shimmer", kind = "mobility", spellID = 212653 },
}

for _, entry in ipairs(addon.previewEntries) do
    if entry.kind == "proc" then
        addon.appearanceEntries[#addon.appearanceEntries + 1] = {
            key = entry.id, entryId = entry.id, label = entry.label,
            kind = "proc", specID = entry.specID,
        }
    end
end

addon.appearanceByKey = {}
for _, entry in ipairs(addon.appearanceEntries) do
    addon.appearanceByKey[entry.key] = entry
end

function addon:GetReminderStyleKey(entry, spellID)
    if type(entry) == "string" then
        return self.appearanceByKey[entry] and entry or nil
    end
    if type(entry) ~= "table" then return end
    if type(entry.styleKey) == "string" and self.appearanceByKey[entry.styleKey] then
        return entry.styleKey
    end
    if entry.kind == "mobility" then
        -- Live rendering supplies the public, already-identified spell ID. No
        -- spell-state query or inference from specialization/position is needed.
        if issecretvalue and issecretvalue(spellID) then return end
        if spellID == 1953 then return "mobility_blink" end
        if spellID == 212653 then return "mobility_shimmer" end
    elseif entry.kind == "proc" and self.appearanceByKey[entry.id] then
        return entry.id
    end
end
