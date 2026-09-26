local _, addon = ...

local function BooleanSetting(value)
    return type(value) == "boolean", "Use a checkbox value (true or false)."
end

local function NumberSetting(range, message)
    return function(value)
        return addon:IsNumberInRange(value, range), message
    end
end

local function NewStyleSchema()
    return {
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
    }
end

-- The same validators normalize saved data and accept edits from both UI and slash commands.
local settingsSchema = {
    enabled = BooleanSetting,
    mobility = { enabled = BooleanSetting },
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
    styles = {},
}

for _, entry in ipairs(addon.appearanceEntries) do
    settingsSchema.styles[entry.key] = NewStyleSchema()
end

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

local function CopyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[key] = CopyTable(item, seen) end
    return copy
end

local function NormalizeStyle(style, defaults, schema)
    style = type(style) == "table" and CopyTable(style) or {}
    -- A SavedVariables file may itself contain aliased tables. Break those
    -- aliases between styles and between their mutable sub-tables as well.
    if type(style.font) == "table" then style.font = CopyTable(style.font) end
    if type(style.shadow) == "table" then style.shadow = CopyTable(style.shadow) end
    ApplyDefaults(style, defaults)
    NormalizeSettings(style, defaults, schema)
    local _, canonicalFace = addon:IsSupportedFont(style.font.face)
    style.font.face = canonicalFace
    return style
end

function addon:InitializeDatabase()
    if type(CarGOUIDB) ~= "table" then
        CarGOUIDB = {}
    end
    local migrateStyles = not (type(CarGOUIDB.schemaVersion) == "number"
        and CarGOUIDB.schemaVersion >= 4)
    local savedStyles = type(CarGOUIDB.styles) == "table" and CarGOUIDB.styles or {}
    -- Detach first so normalizing legacy settings cannot mutate a style that
    -- happened to share a table with an old global font/shadow setting.
    local detachedStyles = {}
    for key, style in pairs(savedStyles) do detachedStyles[key] = CopyTable(style) end
    CarGOUIDB.styles = {}
    ApplyDefaults(CarGOUIDB, self.defaults)
    NormalizeSettings(CarGOUIDB, self.defaults, settingsSchema)
    local _, canonicalFace = self:IsSupportedFont(CarGOUIDB.font.face)
    CarGOUIDB.font.face = canonicalFace

    local initialStyle = self:NewReminderStyle()
    if migrateStyles then
        initialStyle.font = CopyTable(CarGOUIDB.font)
        initialStyle.shadow = CopyTable(CarGOUIDB.shadow)
        initialStyle.scale = CarGOUIDB.scale
    end
    -- Preserve unknown saved entries for forwards compatibility. Each known
    -- entry is normalized from its own snapshot, never another entry's table.
    CarGOUIDB.styles = detachedStyles
    for _, entry in ipairs(self.appearanceEntries) do
        CarGOUIDB.styles[entry.key] = NormalizeStyle(detachedStyles[entry.key],
            initialStyle, settingsSchema.styles[entry.key])
    end
    CarGOUIDB.schemaVersion = self.defaults.schemaVersion
    self.db = CarGOUIDB
end

function addon:GetReminderStyle(entryOrKey, spellID)
    local key = self:GetReminderStyleKey(entryOrKey, spellID)
    if not key or not self.db then return self:NewReminderStyle() end
    local style = self.db.styles[key]
    if type(style) ~= "table" then
        -- A newly introduced/missing entry always starts at factory defaults,
        -- even if legacy global values remain in the saved database.
        style = self:NewReminderStyle()
        self.db.styles[key] = style
    end
    return style
end

function addon:UpdateReminderStyle(styleKey, patch)
    if type(styleKey) ~= "string" or not self.appearanceByKey[styleKey] then
        return false, "Choose an existing reminder entry."
    end
    if type(patch) ~= "table" then return false, "Settings must be supplied as a table." end
    return self:UpdateSettings({ styles = { [styleKey] = patch } })
end

function addon:ResetReminderStyle(styleKey)
    return self:UpdateReminderStyle(styleKey, self:NewReminderStyle())
end

function addon:UpdateSettings(patch)
    if type(self.db) ~= "table" then
        return false, "Settings are not initialized yet."
    end
    if type(patch) == "table" and (patch.font ~= nil or patch.shadow ~= nil or patch.scale ~= nil) then
        return false, "Choose a reminder in Mobility or Proc and edit its Appearance."
    end
    -- Validate the entire edit before writing any part of it (including paired X/Y edits).
    local valid, message = ValidatePatch(patch, settingsSchema, "")
    if not valid then return false, message end

    local stylesOnly = patch.styles ~= nil
    for key in pairs(patch) do
        if key ~= "styles" then stylesOnly = false end
    end
    -- Complete style records before merging, in case an entry was added after
    -- database initialization. Copy inputs through scalar merging, not aliasing.
    if patch.styles then
        for key in pairs(patch.styles) do self:GetReminderStyle(key) end
    end
    MergePatch(self.db, patch)
    if patch.styles then
        for key in pairs(patch.styles) do
            local _, canonicalFace = self:IsSupportedFont(self.db.styles[key].font.face)
            self.db.styles[key].font.face = canonicalFace
        end
    end
    if stylesOnly then
        -- Changing typography must not query cooldown APIs or rebind a timer.
        if self.RefreshReminderStyle then
            for key in pairs(patch.styles) do self:RefreshReminderStyle(key) end
        end
    else
        self:ApplySettings()
    end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end

function addon:ResetDatabase()
    CarGOUIDB = {}
    self:InitializeDatabase()
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
end
