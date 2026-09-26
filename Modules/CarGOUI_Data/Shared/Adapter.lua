local _, data = ...

local methods = {}
local function Public(value)
    return issecretvalue and not issecretvalue(value)
end
local function ValidID(value)
    return Public(value) and type(value) == "number" and value > 0 and value < 10000000 and value % 1 == 0
end
local function Issue(status, reason, definition)
    return { status = status, reason = reason, path = "learning / replacement",
        spellID = definition and definition.spellID, spellName = definition and definition.spellName }
end
local function Known(id)
    local value = C_SpellBook.IsSpellKnown(id)
    if not Public(value) then return nil, "Restricted", "Spell learning state is restricted." end
    if type(value) ~= "boolean" then return nil, "Unknown", "Spell learning state is unavailable." end
    return value
end

local function Conditions(definition)
    for _, id in ipairs(definition.requiresKnown or {}) do
        local known, status, reason = Known(id)
        if known == nil then return nil, status, reason end
        if not known then return false end
    end
    for _, id in ipairs(definition.excludesKnown or {}) do
        local known, status, reason = Known(id)
        if known == nil then return nil, status, reason end
        if known then return false end
    end
    return true
end

local function SelectVariant(definition)
    local allowed, status, reason = Conditions(definition)
    if not allowed then return nil, status and Issue(status, reason, definition) end
    local variants = definition.variants or { definition }
    local byID, effective = {}, {}
    local baseOverride
    if definition.baseSpellID then
        baseOverride = C_Spell.GetOverrideSpell(definition.baseSpellID)
        if not Public(baseOverride) then return nil, Issue("Restricted", "Base replacement is restricted.", definition) end
        if not ValidID(baseOverride) then return nil, Issue("Unknown", "Base replacement is unavailable.", definition) end
    end
    for _, variant in ipairs(variants) do byID[variant.spellID] = variant end
    for _, variant in ipairs(variants) do
        local known, why, message = Known(variant.spellID)
        if known == nil then return nil, Issue(why, message, variant) end
        if known and (not variant.onlyWhenBaseOverride or baseOverride == variant.spellID) then
            local id = C_Spell.GetOverrideSpell(variant.spellID)
            if not Public(id) then return nil, Issue("Restricted", "Spell replacement is restricted.", variant) end
            if not ValidID(id) then return nil, Issue("Unknown", "Spell replacement is unavailable.", variant) end
            local target = byID[id]
            if not target then return nil, Issue("Unsupported", "An active replacement has no audited Mobility definition.", variant) end
            if target.onlyWhenBaseOverride and baseOverride ~= id then
                return nil, Issue("Unknown", "Return replacement is not synchronized with its source family.", variant)
            end
            local learned, targetStatus, targetReason = Known(id)
            if learned == nil then return nil, Issue(targetStatus, targetReason, target) end
            if not learned then return nil, Issue("Unknown", "Replacement is not yet confirmed as learned.", target) end
            local ok, conditionStatus, conditionReason = Conditions(target)
            if ok then effective[id] = target
            elseif conditionStatus then return nil, Issue(conditionStatus, conditionReason, target) end
        end
    end
    local count, selected = 0
    for _, variant in pairs(effective) do count = count + 1; selected = variant end
    if count > 0 and baseOverride and baseOverride ~= definition.baseSpellID then
        local target = byID[baseOverride]
        if not target then return nil, Issue("Unsupported", "The source family has an unaudited active replacement.", selected) end
        local learned, why, message = Known(baseOverride)
        if learned == nil then return nil, Issue(why, message, target) end
        if not learned or not effective[baseOverride] then
            return nil, Issue("Unknown", "The source family's replacement is not yet confirmed as active and learned.", target)
        end
        selected, count = effective[baseOverride], 1
    end
    if count > 1 and baseOverride and effective[baseOverride] then
        selected, count = effective[baseOverride], 1
    end
    if count > 1 and definition.preferKnown then
        for _, id in ipairs(definition.preferKnown) do
            if effective[id] then selected, count = effective[id], 1; break end
        end
    end
    if count > 1 then return nil, Issue("Unknown", "Multiple mutually exclusive variants appear learned; waiting for replacement synchronization.") end
    if not selected then return end
    local merged = {}
    for key, value in pairs(definition) do merged[key] = value end
    for key, value in pairs(selected) do merged[key] = value end
    for id, blockedReason in pairs(merged.blockedIfKnown or {}) do
        local known, why, message = Known(id)
        if known == nil then return nil, Issue(why, message, selected) end
        if known then merged.unsupportedReason = blockedReason; break end
    end
    return merged
end

local function SelectEntries(self, definitions)
    local entries, issues, retained, seen = {}, {}, {}, {}
    self.entryCache = self.entryCache or {}
    for _, definition in ipairs(definitions) do
        local selected, issue = SelectVariant(definition)
        -- Retain only a learned/resolved family or an unresolved selection.
        -- Never-learned families disappear until a learning/identity event.
        if selected or issue then retained[#retained + 1] = definition end
        if issue then issues[#issues + 1] = issue end
        if selected and not seen[selected.spellID] then
            seen[selected.spellID] = true
            local entry = self.entryCache[definition.id]
            if not entry then
                entry = { id = definition.id, class = self.classToken, kind = "mobility", region = "CENTER",
                    slot = definition.slot, anchor = { x = 0, y = -84 * ((definition.slot or 1) - 1) } }
                self.entryCache[definition.id] = entry
            end
            entry.specID, entry.spellID, entry.definition = self.specID, selected.spellID, selected
            entry.label = selected.spellName .. (selected.unsupportedReason
                and " - Preview only (live unsupported)" or " - mobility sample")
            entry.sample = { message = "No " .. selected.spellName, timer = "8.0" }
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b) return (a.slot or 1) < (b.slot or 1) end)
    self.entries, self.mobilityEntries, self.previewEntries, self.selectionIssues = entries, entries, entries, issues
    self.selectionFamilies = retained
end

function methods:ActivateEntries(specID, force)
    if not force and self.active and self.specID == specID then return false end
    self.active, self.specID = true, specID
    if not issecretvalue or not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_Spell or not C_Spell.GetOverrideSpell then
        self.entries, self.mobilityEntries, self.previewEntries, self.selectionFamilies = {}, {}, {}, {}
        self.selectionIssues = { Issue("Unsupported", "Public learning / override APIs are unavailable.") }
        return true
    end
    local candidates = {}
    for _, definition in ipairs(self.definitionFactory(specID)) do
        if not definition.specs or definition.specs[specID] or (not specID and definition.allowUnselected) then
            candidates[#candidates + 1] = definition
        end
    end
    SelectEntries(self, candidates)
    return true
end

function methods:DeactivateEntries()
    self.active, self.specID, self.entries, self.mobilityEntries, self.previewEntries, self.selectionIssues = false, nil, nil, nil, nil, nil
    self.selectionFamilies, self.entryCache = nil, nil
    if data.ClearAbilityStateCache then data:ClearAbilityStateCache() end
end
function methods:GetMobilityEntry() return self.entries and self.entries[1] end
function methods:GetMobilityEntries() return self.entries or {} end
function methods:GetPreviewEntries()
    local entries = {}
    for _, entry in ipairs(self.entries or {}) do
        -- Keep safety diagnostics for unsupported live branches, but do not
        -- advertise excluded return/free-recast mechanisms as usable samples.
        if not entry.definition.unsupportedReason then entries[#entries + 1] = entry end
    end
    return entries
end
function methods:NeedsMobilityEvents()
    return self.selectionFamilies and #self.selectionFamilies > 0 or false
end
function methods:ReadMobilityStates()
    if not issecretvalue or not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_Spell or not C_Spell.GetOverrideSpell then
        return { Issue("Unsupported", "Public learning / override APIs are unavailable.") }
    end
    -- A temporary return may start/end on cooldown-only events. Resolve only
    -- already-selected/pending families, including their base override; never
    -- rerun the class factory or scan inactive families on normal updates.
    if self.selectionFamilies and #self.selectionFamilies > 0 then
        SelectEntries(self, self.selectionFamilies)
        data.host:RefreshActiveEntries()
    end
    local states = {}
    for _, entry in ipairs(self.entries or {}) do states[#states + 1] = data:ReadAbilityState(entry, entry.definition) end
    for _, issue in ipairs(self.selectionIssues or {}) do states[#states + 1] = issue end
    return states
end
function methods:ReadMobilityState()
    return self:ReadMobilityStates()[1] or Issue("Not learned", "No supported Mobility skill is currently learned.")
end

function data:CreateMobilityAdapter(classToken, factory)
    assert(type(factory) == "function", "Class definitions must be lazy factories.")
    return setmetatable({ classToken = classToken, definitionFactory = factory }, { __index = methods })
end

function data:RegisterMobilityClass(classToken, factory)
    local adapter = self:CreateMobilityAdapter(classToken, factory)
    self.adapters[classToken] = adapter
    local accepted, reason = self.host:RegisterClassAdapter(classToken, adapter)
    assert(accepted, reason)
end

-- Add independent Mage travel skills without replacing the user-validated
-- Blink/Shimmer classifier, position IDs, or the existing Proc preview data.
function data:RegisterMageAdditionalMobility(factory)
    local mage = assert(self.adapters.MAGE)
    assert(not mage.additionalMobility, "Mage additions already registered.")
    local extra = self:CreateMobilityAdapter("MAGE", factory)
    mage.additionalMobility = extra
    local activate, deactivate = mage.ActivateEntries, mage.DeactivateEntries
    local getPreview, read = mage.GetPreviewEntries, mage.ReadMobilityState
    function mage:ActivateEntries(specID, force)
        local changed = activate(self, specID)
        if changed then self.basePreviewEntries = self.previewEntries end
        local additionsChanged = extra:ActivateEntries(specID, force)
        local entries = {}
        for _, entry in ipairs(self.basePreviewEntries or {}) do entries[#entries + 1] = entry end
        for _, entry in ipairs(extra:GetPreviewEntries()) do entries[#entries + 1] = entry end
        self.previewEntries = entries
        return changed or additionsChanged
    end
    function mage:DeactivateEntries()
        deactivate(self)
        extra:DeactivateEntries()
        self.basePreviewEntries = nil
    end
    function mage:GetMobilityEntries()
        local entries = {}
        local primary = self:GetMobilityEntry()
        if primary then entries[1] = primary end
        for _, entry in ipairs(extra:GetMobilityEntries()) do entries[#entries + 1] = entry end
        return entries
    end
    function mage:GetPreviewEntries()
        local view = setmetatable({ previewEntries = self.basePreviewEntries }, { __index = self })
        local entries = getPreview(view)
        for _, entry in ipairs(extra:GetPreviewEntries()) do entries[#entries + 1] = entry end
        return entries
    end
    function mage:NeedsMobilityEvents()
        return self:GetMobilityEntry() ~= nil or extra:NeedsMobilityEvents()
    end
    function mage:ReadMobilityStates()
        local states = { read(self) }
        for _, state in ipairs(extra:ReadMobilityStates()) do states[#states + 1] = state end
        return states
    end
end
