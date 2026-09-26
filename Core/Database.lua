local _, addon = ...

local function BooleanSetting(value)
    return type(value) == "boolean", "Use a checkbox value (true or false)."
end

local function NumberSetting(range, message)
    return function(value) return addon:IsNumberInRange(value, range), message end
end

local styleSchema = {
    font = {
        face = function(value) return addon:IsSupportedFont(value), "Choose a supported font." end,
        size = NumberSetting(addon.limits.fontSize, "Font size must be a number from 8 to 72."),
        outline = function(value)
            return type(value) == "string" and addon.outlines[value] == true,
                "Outline must be none, outline, or thickoutline."
        end,
    },
    scale = NumberSetting(addon.limits.scale, "Scale must be a number from 0.5 to 3."),
    shadow = { enabled = BooleanSetting },
}
local positionSchema = {
    anchor = function(value) return value == "CENTER", "The reminder anchor must be CENTER." end,
    x = NumberSetting(addon.limits.offset, "X offset must be a number from -10000 to 10000."),
    y = NumberSetting(addon.limits.offset, "Y offset must be a number from -10000 to 10000."),
}
local optionsSchema = {
    animatedTitle = BooleanSetting,
    position = {
        x = NumberSetting(addon.limits.offset, "Window X must be from -10000 to 10000."),
        y = NumberSetting(addon.limits.offset, "Window Y must be from -10000 to 10000."),
    },
}

local function CopyTable(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, item in pairs(value) do copy[key] = CopyTable(item, seen) end
    return copy
end

local function ShallowCopy(value)
    local copy = {}
    if type(value) == "table" then
        for key, item in pairs(value) do copy[key] = item end
    end
    return copy
end

local function Complete(target, defaults, schema)
    target = type(target) == "table" and CopyTable(target) or {}
    for key, validator in pairs(schema) do
        if type(validator) == "table" then
            target[key] = Complete(target[key], defaults[key], validator)
        elseif not validator(target[key]) then
            target[key] = defaults[key]
        end
    end
    return target
end

local function Style(target, defaults)
    local style = Complete(target, defaults or addon:NewReminderStyle(), styleSchema)
    local _, canonical = addon:IsSupportedFont(style.font.face)
    style.font.face = canonical
    return style
end

local function Position(target, defaults)
    target = type(target) == "table" and CopyTable(target) or {}
    defaults = defaults or addon:NewReminderPosition()
    target.anchor = "CENTER"
    -- Old global + region offsets could each be valid at +/-10000. Preserve
    -- the combined effective position; new edits retain the original limits.
    local savedRange = { min = -20000, max = 20000 }
    for _, axis in ipairs({ "x", "y" }) do
        if not addon:IsNumberInRange(target[axis], savedRange) then target[axis] = defaults[axis] end
    end
    return target
end

local function ValidatePatch(patch, schema, path)
    if type(patch) ~= "table" then return false, "Settings must be supplied as a table." end
    for key, value in pairs(patch) do
        local validator = schema[key]
        local field = path .. tostring(key)
        if not validator then return false, "Unsupported setting: " .. field end
        if type(validator) == "table" then
            if type(value) ~= "table" then return false, field .. " must be supplied as a table." end
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
            if type(target[key]) ~= "table" then target[key] = {} end
            MergePatch(target[key], value)
        else target[key] = value end
    end
end

local function Preferences(value, seen)
    if type(value) ~= "table" then return false, "Preferences must be supplied as a table." end
    seen = seen or {}
    if seen[value] then return false, "Preferences cannot contain cycles." end
    seen[value] = true
    for key, item in pairs(value) do
        if type(key) ~= "string" then return false, "Preference keys must be strings." end
        if type(item) == "table" then
            local valid, message = Preferences(item, seen)
            if not valid then return false, message end
        elseif type(item) ~= "boolean" and type(item) ~= "string"
            and not addon:IsNumberInRange(item, { min = -1000000, max = 1000000 }) then
            return false, "Preferences must contain ordinary saved values."
        end
    end
    seen[value] = nil
    return true
end

local legacyFields = { "enabled", "mobility", "position", "font", "shadow", "scale", "styles", "reminders" }

local function CaptureLegacy(db)
    db.migrations = type(db.migrations) == "table" and db.migrations or {}
    if type(db.migrations.scope5) == "table" then return end
    local source = { schemaVersion = db.schemaVersion }
    local exists = false
    for _, key in ipairs(legacyFields) do
        if db[key] ~= nil then exists = true; source[key] = db[key]; db[key] = nil end
    end
    db.migrations.scope5 = { source = source, pendingMage = exists,
        mobilityComplete = not exists, proc = {},
        policy = "Legacy Mage only; active confirmed spell, then Blink/Shimmer fallback; current region then Arcane/Fire/Frost/unspecialized; Proc first saved defined region." }
end

local function LegacyStyle(source)
    -- Since schema 4, retired global typography no longer supplies missing
    -- entry values. Match that prior normalization instead of reviving it.
    if type(source.schemaVersion) == "number" and source.schemaVersion >= 4 then
        return addon:NewReminderStyle()
    end
    return Style({ font = source.font, shadow = source.shadow, scale = source.scale })
end

local function LegacyOffset(source, id)
    local global = type(source.position) == "table" and source.position or {}
    local reminders = type(source.reminders) == "table" and source.reminders or {}
    local record = type(reminders[id]) == "table" and reminders[id] or {}
    local region = type(record.position) == "table" and record.position or {}
    local offset = { anchor = "CENTER" }
    for _, axis in ipairs({ "x", "y" }) do
        local a = addon:IsNumberInRange(global[axis], addon.limits.offset) and global[axis] or 0
        local b = addon:IsNumberInRange(region[axis], addon.limits.offset) and region[axis] or 0
        offset[axis] = a + b
    end
    return offset
end

local function KnownMageSpell()
    if not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_Spell or not C_Spell.GetOverrideSpell then return end
    local blink, shimmer = C_SpellBook.IsSpellKnown(1953), C_SpellBook.IsSpellKnown(212653)
    local replacement = C_Spell.GetOverrideSpell(1953)
    if issecretvalue and (issecretvalue(blink) or issecretvalue(shimmer) or issecretvalue(replacement)) then return end
    if type(blink) ~= "boolean" or type(shimmer) ~= "boolean" then return end
    if shimmer and replacement == 212653 then
        local ownReplacement = C_Spell.GetOverrideSpell(212653)
        if issecretvalue and issecretvalue(ownReplacement) then return end
        if ownReplacement == 212653 then return 212653 end
    elseif blink and not shimmer and replacement == 1953 then return 1953 end
end

local magePositions = { [62] = "mage_arcane_shimmer", [63] = "mage_fire_shimmer",
    [64] = "mage_frost_shimmer", [0] = "mage_unspecialized_mobility" }

local function MigrateMageMobility(self, classConfig, specID)
    local migration = self.db.migrations.scope5
    if migration.mobilityComplete then return end
    local source = migration.source
    local styles = type(source.styles) == "table" and source.styles or {}
    local selectedSpell = KnownMageSpell()
    local selectedStyle = selectedSpell == 212653 and "mobility_shimmer" or selectedSpell == 1953 and "mobility_blink" or nil
    local rule = selectedStyle and "currently confirmed learned replacement" or "learning unavailable: Blink then Shimmer then legacy global"
    if not selectedStyle then
        if type(styles.mobility_blink) == "table" then selectedStyle = "mobility_blink"
        elseif type(styles.mobility_shimmer) == "table" then selectedStyle = "mobility_shimmer" end
    end
    local legacyStyle = Style(selectedStyle and styles[selectedStyle], LegacyStyle(source))
    local selectedPosition = magePositions[specID or 0]
    local reminders = type(source.reminders) == "table" and source.reminders or {}
    if not selectedPosition or type(reminders[selectedPosition]) ~= "table" then
        selectedPosition = nil
        for _, id in ipairs({ magePositions[62], magePositions[63], magePositions[64], magePositions[0] }) do
            if type(reminders[id]) == "table" then selectedPosition = id; break end
        end
    end
    local mobility = type(classConfig.mobility) == "table" and CopyTable(classConfig.mobility) or {}
    local legacyMobility = type(source.mobility) == "table" and source.mobility or {}
    if type(mobility.enabled) ~= "boolean" then
        mobility.enabled = source.enabled ~= false and legacyMobility.enabled ~= false
    end
    mobility.style = Style(mobility.style, legacyStyle)
    mobility.position = Position(mobility.position, LegacyOffset(source, selectedPosition or ""))
    if type(mobility.preferences) ~= "table" then mobility.preferences = {} end
    -- Preserve historical module-level fields inside Mage, never new classes.
    for key, value in pairs(legacyMobility) do
        if key ~= "enabled" and mobility[key] == nil then mobility[key] = CopyTable(value) end
    end
    classConfig.mobility = mobility
    migration.mobility = { styleSource = selectedStyle or "legacy global / factory", spellID = selectedSpell,
        rule = rule, positionSource = selectedPosition or "legacy global", coordinates = "global + region once; no scale multiplication",
        conflictBackup = "migrations.scope5.source" }
    migration.mobilityComplete, migration.pendingMage = true, false
end

local function MigrateMageProc(self, config, specID)
    local migration = self.db.migrations.scope5
    if migration.procReset or migration.proc[specID] then return config end
    local source = migration.source
    local styles = type(source.styles) == "table" and source.styles or {}
    local selectedStyle
    local regions = {}
    for _, entry in ipairs(self.previewEntries or {}) do
        if entry.class == "MAGE" and entry.kind == "proc" and entry.specID == specID then
            if not selectedStyle and type(styles[entry.id]) == "table" then selectedStyle = entry.id end
            regions[#regions + 1] = entry.id
        end
    end
    -- Unrecognized scopes are left at factory defaults; never guess a mapping.
    if #regions == 0 then return config end
    config.style = Style(config.style, Style(selectedStyle and styles[selectedStyle], LegacyStyle(source)))
    config.regions = type(config.regions) == "table" and config.regions or {}
    for _, id in ipairs(regions) do
        local record = type(config.regions[id]) == "table" and CopyTable(config.regions[id]) or {}
        record.position = Position(record.position, LegacyOffset(source, id))
        config.regions[id] = record
    end
    migration.proc[specID] = { styleSource = selectedStyle or "legacy global / factory",
        rule = "first saved defined region (left before right); existing scoped valid values win",
        conflictBackup = "migrations.scope5.source" }
    return config
end

function addon:GetMobilityConfig()
    if not self.db then return self:NewMobilityConfig() end
    local class, specID = self:GetPlayerContext()
    if not class then
        self.unresolvedMobilityConfig = self.unresolvedMobilityConfig or self:NewMobilityConfig()
        return self.unresolvedMobilityConfig
    end
    if self.configurationClass ~= class then self:RefreshConfigurationContext() end
    return self.db.classes[class].mobility
end

function addon:GetProcConfig(specID)
    if not self.db then return end
    local class, currentSpec = self:GetPlayerContext()
    specID = specID or currentSpec
    if not class or not currentSpec or specID ~= currentSpec then return end
    -- A deferred/missing Mage module has no migration catalog yet. Do not
    -- persist provisional factory values which would later mask old settings.
    if class == "MAGE" and (not self.dataPackageLoaded or self.activeAdapterClass ~= class
        or self.activeModuleSpec ~= specID) then return end
    if self.configurationClass ~= class then self:RefreshConfigurationContext() end
    local classConfig = self.db.classes[class]
    local cached = self.procConfigurationCache and self.procConfigurationCache[specID]
    if cached == classConfig.proc[specID] and cached then return cached end
    local config = type(classConfig.proc[specID]) == "table" and CopyTable(classConfig.proc[specID]) or {}
    if class == "MAGE" then config = MigrateMageProc(self, config, specID) end
    config.style = Style(config.style)
    if type(config.enabled) ~= "boolean" then config.enabled = true end
    config.regions = type(config.regions) == "table" and config.regions or {}
    classConfig.proc[specID] = config
    self.procConfigurationCache = self.procConfigurationCache or {}
    self.procConfigurationCache[specID] = config
    return config
end

function addon:RefreshConfigurationContext()
    if not self.db then return end
    local class, specID = self:GetPlayerContext()
    self:RefreshAppearanceEntries()
    if not class then self.configurationClass = nil; return end
    if self.configurationClass ~= class then
        -- Detach the current class container and its spec index without walking
        -- or normalizing saved payloads belonging to other specifications.
        local config = ShallowCopy(self.db.classes[class])
        config.proc = ShallowCopy(config.proc)
        if class == "MAGE" then MigrateMageMobility(self, config, specID) end
        local mobility = type(config.mobility) == "table" and CopyTable(config.mobility) or {}
        mobility.style = Style(mobility.style)
        mobility.position = Position(mobility.position)
        if type(mobility.enabled) ~= "boolean" then mobility.enabled = true end
        mobility.preferences = type(mobility.preferences) == "table" and CopyTable(mobility.preferences) or {}
        config.mobility = mobility
        self.db.classes[class] = config
        self.configurationClass, self.procConfigurationCache = class, {}
    end
end

function addon:InitializeDatabase()
    if type(CarGOUIDB) ~= "table" then CarGOUIDB = {} end
    CaptureLegacy(CarGOUIDB)
    CarGOUIDB.classes = type(CarGOUIDB.classes) == "table" and CarGOUIDB.classes or {}
    CarGOUIDB.options = Complete(CarGOUIDB.options, self.defaults.options, optionsSchema)
    CarGOUIDB.schemaVersion = self.defaults.schemaVersion
    self.db, self.configurationClass, self.procConfigurationCache = CarGOUIDB, nil, {}
    self:RefreshConfigurationContext()
end

function addon:GetReminderStyle(entryOrKey)
    local key = self:GetReminderStyleKey(entryOrKey)
    if not key or not self.db then return self:NewReminderStyle() end
    local mobility = self:GetAppearanceContext("mobility")
    if mobility and key == mobility.key then return self:GetMobilityConfig().style end
    local proc = self:GetProcConfig()
    return proc and proc.style or self:NewReminderStyle()
end

function addon:GetReminderPosition(entry)
    if type(entry) ~= "table" or not self:GetReminderStyleKey(entry) then return self:NewReminderPosition() end
    if entry.kind == "mobility" then return self:GetMobilityConfig().position end
    local proc = self:GetProcConfig()
    if not proc or type(entry.id) ~= "string" then return self:NewReminderPosition() end
    local region = proc.regions[entry.id]
    if type(region) ~= "table" then region = {}; proc.regions[entry.id] = region end
    if not region.position then region.position = self:NewReminderPosition()
    elseif self.normalizedRegionPositions == nil or not self.normalizedRegionPositions[region] then
        region.position = Position(region.position)
    end
    self.normalizedRegionPositions = self.normalizedRegionPositions or setmetatable({}, { __mode = "k" })
    self.normalizedRegionPositions[region] = true
    return region.position
end

function addon:GetReminderEnabled(entry)
    if type(entry) ~= "table" or not self:GetReminderStyleKey(entry) then return false end
    if entry.kind == "mobility" then return self:GetMobilityConfig().enabled end
    local proc = self:GetProcConfig()
    return proc and proc.enabled == true or false
end

function addon:UpdateReminderStyle(key, patch)
    if not self:GetReminderStyleKey(key) then return false, "Edit the current class / specialization Appearance." end
    return self:UpdateSettings({ styles = { [key] = patch } })
end

function addon:ResetReminderStyle(key)
    return self:UpdateReminderStyle(key, self:NewReminderStyle())
end

function addon:UpdateSettings(patch)
    if not self.db then return false, "Settings are not initialized yet." end
    if type(patch) ~= "table" then return false, "Settings must be supplied as a table." end
    local class = self:GetPlayerContext()
    local schema = { options = optionsSchema, enabled = BooleanSetting, position = positionSchema,
        mobility = { enabled = BooleanSetting, style = styleSchema, position = positionSchema, preferences = Preferences },
        proc = { style = styleSchema, regions = {} }, styles = {}, reminders = {} }
    local entries = {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
        entries[entry.id] = entry
        schema.reminders[entry.id] = { position = positionSchema }
        if entry.kind == "proc" then schema.proc.regions[entry.id] = { position = positionSchema } end
    end
    for _, kind in ipairs({ "mobility", "proc" }) do
        local context = self:GetAppearanceContext(kind)
        if context then schema.styles[context.key] = styleSchema end
    end
    local valid, message = ValidatePatch(patch, schema, "")
    if not valid then return false, message end
    for key in pairs(patch) do
        if key ~= "options" and not class then return false, "Player class is not available yet." end
    end
    local procContext = self:GetAppearanceContext("proc")
    local writesProc = patch.proc or (procContext and patch.styles and patch.styles[procContext.key])
    if writesProc and (not procContext or not self:GetProcConfig()) then
        return false, "Proc settings are unavailable until the current specialization module is ready."
    end
    local changedStyles, stylesOnly = {}, true
    local function RecordStyle(kind)
        local context = self:GetAppearanceContext(kind)
        if context then changedStyles[context.key] = true end
    end
    if patch.options then MergePatch(self.db.options, patch.options); stylesOnly = false end
    if patch.enabled ~= nil then self:GetMobilityConfig().enabled = patch.enabled; stylesOnly = false end
    if patch.position then MergePatch(self:GetMobilityConfig().position, patch.position); stylesOnly = false end
    if patch.mobility then
        MergePatch(self:GetMobilityConfig(), patch.mobility)
        for key in pairs(patch.mobility) do if key ~= "style" then stylesOnly = false end end
        if patch.mobility.style then RecordStyle("mobility") end
    end
    if patch.proc then
        MergePatch(self:GetProcConfig(), patch.proc)
        for key in pairs(patch.proc) do if key ~= "style" then stylesOnly = false end end
        if patch.proc.style then RecordStyle("proc") end
    end
    if patch.reminders then
        for id, record in pairs(patch.reminders) do MergePatch(self:GetReminderPosition(entries[id]), record.position or {}) end
        stylesOnly = false
    end
    if patch.styles then
        for key, record in pairs(patch.styles) do MergePatch(self:GetReminderStyle(key), record); changedStyles[key] = true end
    end
    for key in pairs(changedStyles) do
        local style = self:GetReminderStyle(key)
        local _, canonical = self:IsSupportedFont(style.font.face)
        style.font.face = canonical
    end
    if stylesOnly then
        if self.RefreshReminderStyle then for key in pairs(changedStyles) do self:RefreshReminderStyle(key) end end
    else self:ApplySettings() end
    if self.RefreshOptions then self:RefreshOptions() end
    return true
end

function addon:ResetDatabase()
    local class = self:GetPlayerContext()
    if class then self.db.classes[class] = nil end
    if class == "MAGE" then self.db.migrations.scope5.procReset = true end
    -- Reset is deliberately scoped. Other classes and historical migration
    -- backups remain intact; completed migrations never reapply old settings.
    self.db.options = CopyTable(self.defaults.options)
    self.configurationClass, self.procConfigurationCache = nil, {}
    self:RefreshConfigurationContext()
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
end
