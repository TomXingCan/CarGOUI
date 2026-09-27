local _, addon = ...

-- Spell names are presentation metadata. The cache never stores cooldowns,
-- aura presence, native text, charges or player-controlled stable identifiers.
local LIMIT = 128
local OnSpellDataLoaded
local regionLabels = { LeftOutside = "Left outside", RightOutside = "Right outside",
    TopLeft = "Top left", TopRight = "Top right" }

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Name(value)
    return Public(value) and type(value) == "string" and value ~= "" and #value <= 512
end

local function SpellID(value)
    return Public(value) and type(value) == "number" and value > 0
        and value < 10000000 and value % 1 == 0
end

local function QueryName(id)
    if not C_Spell then return end
    local name = C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if Name(name) then return name end
    local info = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    if Public(info) and type(info) == "table" and Name(info.name) then return info.name end
end

local function Cache(self)
    local class, spec = self:GetPlayerContext()
    local cache = self.localizedNameCache
    if not cache or cache.class ~= class or cache.spec ~= spec or cache.locale ~= self.clientLocale then
        self:UnregisterEvent("SPELL_DATA_LOAD_RESULT", OnSpellDataLoaded)
        cache = { class = class, spec = spec, locale = self.clientLocale, names = {}, requested = {},
            pending = {}, pendingCount = 0, count = 0 }
        self.localizedNameCache = cache
    end
    return cache
end

OnSpellDataLoaded = function(self, _, id, success)
    if not SpellID(id) or not Public(success) then return end
    local cache = Cache(self)
    if not cache.pending[id] then return end
    cache.pending[id], cache.pendingCount = nil, cache.pendingCount - 1
    local name = success == true and QueryName(id)
    if name then cache.names[id] = name end
    if cache.pendingCount == 0 then self:UnregisterEvent("SPELL_DATA_LOAD_RESULT", OnSpellDataLoaded) end
    -- Synchronous completion is returned to the active caller below. Refreshing
    -- here could reenter RefreshOptions while it is still building menu labels.
    if name and cache.requestingID ~= id and self.RefreshLocalizedLabels then self:RefreshLocalizedLabels(id) end
end

function addon:GetLocalizedSpellName(id, fallback)
    fallback = Name(fallback) and fallback or self:Text("Unknown spell")
    if not SpellID(id) then return fallback end
    local cache = Cache(self)
    if cache.names[id] then return cache.names[id] end
    if cache.requested[id] then return fallback end
    if cache.count >= LIMIT then return fallback end
    cache.requested[id], cache.count = true, cache.count + 1
    local name = QueryName(id)
    if name then cache.names[id] = name; return name end
    if C_Spell and C_Spell.RequestLoadSpellData then
        cache.pending[id], cache.pendingCount = true, cache.pendingCount + 1
        self:RegisterEvent("SPELL_DATA_LOAD_RESULT", OnSpellDataLoaded)
        cache.requestingID = id
        C_Spell.RequestLoadSpellData(id)
        cache.requestingID = nil
        -- A host can deliver the result synchronously; reuse it if available.
        if cache.names[id] then return cache.names[id] end
    end
    return fallback
end

function addon:GetLocalizedClassName()
    local class = UnitClass and UnitClass("player")
    return Name(class) and class or self:Text("Unknown class")
end

function addon:GetLocalizedSpecName(specID)
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    if Public(index) and type(index) == "number" and getInfo then
        local id, name = getInfo(index)
        if Public(id) and id == specID and Name(name) then return name end
    end
    return self:Format("Specialization %d", specID)
end

function addon:GetEntryDisplaySpell(entry)
    if entry.kind == "proc" then
        -- Real aura identity is used for the display name, not the sometimes
        -- dummy activation-overlay ID. Neither is used to query aura state.
        local fallback = Name(entry.label) and entry.label:match("^(.-) %- ") or entry.label
        return entry.auraID or entry.sourceSpellID, fallback
    end
    local definition = entry.definition
    if entry.spellID then return entry.spellID, definition and definition.spellName or entry.spellName end
    if entry.class == "MAGE" then
        -- This is the existing public runtime snapshot, not another learned or
        -- cooldown query. Match the existing Mage sample fallback when unknown.
        local status = self.GetMobilityStatus and self:GetMobilityStatus(entry.id)
        return status and status.spellID or 212653, status and status.spellName or "Shimmer"
    end
    return entry.sourceSpellID, entry.spellName
end

function addon:FormatMobilityLabel(id, fallback)
    return self:Format("No %s", self:GetLocalizedSpellName(id, fallback))
end

function addon:GetEntryDisplayLabel(entry)
    if not entry then return "" end
    if entry.freeMove then
        return self:Format("Free move - %s", self:GetLocalizedSpellName(entry.sourceCastID, "Time Spiral"))
    end
    local id, fallback = self:GetEntryDisplaySpell(entry)
    local name = self:GetLocalizedSpellName(id, fallback)
    if entry.kind == "mobility" then
        local key = entry.definition and entry.definition.unsupportedReason
            and "%s - Preview only (live unsupported)" or "%s - mobility sample"
        return self:Format(key, name)
    end
    local suffix = Name(entry.label) and entry.label:match(" %- (.+)$")
        or entry.nativeLocation or entry.location or entry.region
    suffix = regionLabels[suffix] or suffix
    return suffix and self:Format("%s - %s", name, self:Text(suffix)) or name
end

function addon:GetLocalizedPreviewContent(entry)
    local sample = entry.sample or {}
    if entry.kind ~= "mobility" then return sample end
    local id, fallback = self:GetEntryDisplaySpell(entry)
    return { timer = sample.timer, message = entry.freeMove and self:Text("Free move")
        or self:FormatMobilityLabel(id, fallback) }
end

-- A successful metadata load only replaces our static public labels. It must
-- not reread combat state or restart a DurationObject / native aura slot.
function addon:RefreshLocalizedLabels(id)
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.live or {}) do
        if frame.mobilityBindingActive and frame.mobilityDisplaySpellID == id then
            self:UpdateMobilityTextFormat(frame)
        end
    end
    for _, frame in pairs(self.previewFrames or {}) do
        local entry = frame.reminderEntry
        if entry and frame:IsShown() then
            self:RenderReminder(frame, entry, self:GetLocalizedPreviewContent(entry), true)
        end
    end
    if self.optionsFrame and self.optionsFrame:IsShown() and self.RefreshOptions then self:RefreshOptions() end
end
