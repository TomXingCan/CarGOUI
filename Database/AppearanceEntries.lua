local _, addon = ...

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

-- Identity is public metadata, not cooldown or spell-availability state. No
-- configuration for a different character/class is inspected here.
function addon:GetPlayerContext()
    local _, class = UnitClass("player")
    if not Public(class) or type(class) ~= "string" or not class:match("^[A-Z]+$") then return end
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    if not Public(index) then return class end
    local specID = index and getInfo and getInfo(index)
    if not Public(specID) or type(specID) ~= "number" or specID <= 0 or specID % 1 ~= 0 then
        return class
    end
    return class, specID
end

local mageSpecNames = { [62] = "Arcane", [63] = "Fire", [64] = "Frost" }

function addon:GetAppearanceContext(kind)
    local class, specID = self:GetPlayerContext()
    if not class then return end
    if kind == "mobility" then
        return { key = "mobility:" .. class, kind = kind, classToken = class,
            label = class:sub(1, 1) .. class:sub(2):lower() .. " Mobility" }
    end
    if kind == "proc" and specID then
        local specName = class == "MAGE" and mageSpecNames[specID]
        return { key = "proc:" .. class .. ":" .. specID, kind = kind,
            classToken = class, specID = specID, label = (specName or ("Specialization " .. specID)) .. " Proc" }
    end
end

function addon:RefreshAppearanceEntries()
    self.appearanceEntries, self.appearanceByKey = {}, {}
    for _, kind in ipairs({ "mobility", "proc" }) do
        local context = self:GetAppearanceContext(kind)
        if context then
            self.appearanceEntries[#self.appearanceEntries + 1] = context
            self.appearanceByKey[context.key] = context
        end
    end
end

function addon:GetReminderStyleKey(entry)
    if type(entry) == "string" then
        for _, kind in ipairs({ "mobility", "proc" }) do
            local context = self:GetAppearanceContext(kind)
            if context and entry == context.key then return entry end
        end
        return
    end
    if type(entry) ~= "table" then return end
    local context = self:GetAppearanceContext(entry.kind)
    if not context then return end
    if entry.class and entry.class ~= context.classToken then return end
    if entry.kind == "proc" and entry.specID and entry.specID ~= context.specID then return end
    return context.key
end

addon.appearanceEntries, addon.appearanceByKey = {}, {}
