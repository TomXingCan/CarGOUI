local _, addon = ...

local function BooleanSetting(value)
    return type(value) == "boolean", "Use a checkbox value (true or false)."
end

local function NumberSetting(range, message)
    return function(value)
        return addon:IsNumberInRange(value, range), message
    end
end

-- The same validators normalize saved data and accept edits from both UI and slash commands.
local settingsSchema = {
    enabled = BooleanSetting,
    position = {
        x = NumberSetting(addon.limits.offset, "X offset must be a number from -10000 to 10000."),
        y = NumberSetting(addon.limits.offset, "Y offset must be a number from -10000 to 10000."),
    },
    font = {
        face = function(value)
            return addon:IsSupportedFont(value), "Choose a supported font."
        end,
        size = NumberSetting(addon.limits.fontSize, "Font size must be a number from 8 to 72."),
        outline = function(value)
            return type(value) == "string" and addon.outlines[value] == true,
                "Outline must be none, outline, or thickoutline."
        end,
    },
    scale = NumberSetting(addon.limits.scale, "Scale must be a number from 0.5 to 3."),
    shadow = { enabled = BooleanSetting },
    options = {
        animatedTitle = BooleanSetting,
        position = {
            x = NumberSetting(addon.limits.offset, "Window X must be from -10000 to 10000."),
            y = NumberSetting(addon.limits.offset, "Window Y must be from -10000 to 10000."),
        },
    },
    reminders = {},
}

for _, entry in ipairs(addon.previewEntries) do
    settingsSchema.reminders[entry.id] = { position = {
        x = NumberSetting(addon.limits.offset, "Region X must be from -10000 to 10000."),
        y = NumberSetting(addon.limits.offset, "Region Y must be from -10000 to 10000."),
    } }
end

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end

local function NormalizeSettings(target, defaults, schema)
    for key, validator in pairs(schema) do
        if type(validator) == "table" then
            NormalizeSettings(target[key], defaults[key], validator)
        elseif not validator(target[key]) then
            target[key] = defaults[key]
        end
    end
end

local function ValidatePatch(patch, schema, path)
    if type(patch) ~= "table" then
        return false, "Settings must be supplied as a table."
    end
    for key, value in pairs(patch) do
        local validator = schema[key]
        local field = path .. tostring(key)
        if not validator then
            return false, "Unsupported setting: " .. field
        end
        if type(validator) == "table" then
            if type(value) ~= "table" then
                return false, field .. " must be supplied as a table."
            end
            local valid, message = ValidatePatch(value, validator, field .. ".")
            if not valid then return false, message end
        else
            local valid, message = validator(value)
            if not valid then return false, message end
        end
    end
    return true
end

local function MergePatch(target, patch)
    for key, value in pairs(patch) do
        if type(value) == "table" then
            MergePatch(target[key], value)
        else
            target[key] = value
        end
    end
end

function addon:InitializeDatabase()
    if type(CarGOUIDB) ~= "table" then
        CarGOUIDB = {}
    end
    ApplyDefaults(CarGOUIDB, self.defaults)
    NormalizeSettings(CarGOUIDB, self.defaults, settingsSchema)
    CarGOUIDB.schemaVersion = self.defaults.schemaVersion
    local _, canonicalFace = self:IsSupportedFont(CarGOUIDB.font.face)
    CarGOUIDB.font.face = canonicalFace
    self.db = CarGOUIDB
end

function addon:UpdateSettings(patch)
    if type(self.db) ~= "table" then
        return false, "Settings are not initialized yet."
    end
    -- Validate the entire edit before writing any part of it (including paired X/Y edits).
    local valid, message = ValidatePatch(patch, settingsSchema, "")
    if not valid then return false, message end

    MergePatch(self.db, patch)
    local _, canonicalFace = self:IsSupportedFont(self.db.font.face)
    self.db.font.face = canonicalFace
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end

function addon:ResetDatabase()
    CarGOUIDB = {}
    self:InitializeDatabase()
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
end
