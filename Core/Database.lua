local _, addon = ...

local function BooleanSetting(value)
    return type(value) == "boolean", addon:Text("Use a checkbox value (true or false).")
end

-- A region color is optional. Omission means dynamic class color; no default
-- RGB is written to SavedVariables. This validator also rejects alpha/extra keys.
function addon:IsValidProcRegionColor(value)
    if issecretvalue and issecretvalue(value) then return false end
    if type(value) ~= "table" then return false end
    for _, key in ipairs({ "r", "g", "b" }) do
        local component = value[key]
        if issecretvalue and issecretvalue(component) then return false end
        if type(component) ~= "number" or component ~= component or component < 0 or component > 1 then return false end
    end
    for key in pairs(value) do
        if key ~= "r" and key ~= "g" and key ~= "b" then return false end
    end
    return true
end

local function ColorCopy(value)
    if addon:IsValidProcRegionColor(value) then return { r = value.r, g = value.g, b = value.b } end
end

local function RegionColorSetting(value)
    if issecretvalue and issecretvalue(value) then return false, addon:Text("Color must be a public RGB value.") end
    return value == false or addon:IsValidProcRegionColor(value), addon:Text("Choose finite RGB values from 0 to 1; opacity is not configurable.")
end

local function RegionAppearanceSetting(value)
    if issecretvalue and issecretvalue(value) then return false, addon:Text("Artwork settings must contain public values.") end
    if value == false then return true end -- Reset only this region's artwork.
    return addon:ValidateProcAppearance(value, true)
end

local function NumberSetting(range, message)
    return function(value) return addon:IsNumberInRange(value, range), message end
end

local styleSchema = {
    font = {
        face = function(value) return addon:IsSupportedFont(value), addon:Text("Choose a supported font.") end,
        size = NumberSetting(addon.limits.fontSize, addon:Text("Font size must be a number from 8 to 72.")),
        outline = function(value)
            return type(value) == "string" and addon.outlines[value] == true,
                addon:Text("Outline must be none, outline, or thickoutline.")
        end,
    },
    scale = NumberSetting(addon.limits.scale, addon:Text("Scale must be a number from 0.5 to 3.")),
    shadow = { enabled = BooleanSetting },
}
local positionSchema = {
    anchor = function(value) return value == "CENTER", addon:Text("The reminder anchor must be CENTER.") end,
    x = NumberSetting(addon.limits.offset, addon:Text("X offset must be a number from -10000 to 10000.")),
    y = NumberSetting(addon.limits.offset, addon:Text("Y offset must be a number from -10000 to 10000.")),
}
local minimapSchema = {
    hide = BooleanSetting,
    -- LibDBIcon stores an angle, not XY. Equivalent negative angles are valid.
    minimapPos = function(value)
        if issecretvalue and issecretvalue(value) then return false, addon:Text("Minimap angle must be public.") end
        return addon:IsNumberInRange(value, { min = -360, max = 360 }),
            addon:Text("Minimap angle must be a finite number from -360 to 360.")
    end,
}
local optionsSchema = {
    animatedTitle = BooleanSetting,
    minimap = minimapSchema,
    position = {
        x = NumberSetting(addon.limits.offset, addon:Text("Window X must be from -10000 to 10000.")),
        y = NumberSetting(addon.limits.offset, addon:Text("Window Y must be from -10000 to 10000.")),
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
    if type(patch) ~= "table" then return false, addon:Text("Settings must be supplied as a table.") end
    for key, value in pairs(patch) do
        local validator = schema[key]
        local field = path .. tostring(key)
        if not validator then return false, addon:Text("Unsupported setting: ") .. field end
        if type(validator) == "table" then
            if type(value) ~= "table" then return false, field .. addon:Text(" must be supplied as a table.") end
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
    if type(value) ~= "table" then return false, addon:Text("Preferences must be supplied as a table.") end
    seen = seen or {}
    if seen[value] then return false, addon:Text("Preferences cannot contain cycles.") end
    seen[value] = true
    for key, item in pairs(value) do
        if type(key) ~= "string" then return false, addon:Text("Preference keys must be strings.") end
        if type(item) == "table" then
            local valid, message = Preferences(item, seen)
            if not valid then return false, message end
        elseif type(item) ~= "boolean" and type(item) ~= "string"
            and not addon:IsNumberInRange(item, { min = -1000000, max = 1000000 }) then
            return false, addon:Text("Preferences must contain ordinary saved values.")
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
    -- Normalize only the requested current specialization. Detach each region
    -- and color separately, even if an older external edit aliased the tables.
    for id, region in pairs(config.regions) do
        if type(region) == "table" then
            region = ShallowCopy(region)
            -- Detach positions before any direct proc.regions patch can merge
            -- into them, not only after the first render of each region.
            if region.position ~= nil then region.position = Position(region.position) end
            region.color = ColorCopy(region.color)
            region.appearance = self:CopyProcAppearance(region.appearance)
            config.regions[id] = region
        end
    end
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
        -- Additive, once-per-scope migration: old Free move used this class's
        -- ordinary Mobility offset. Copy that effective offset only when the
        -- independent field is absent; later edits never inherit it again.
        -- Position() detaches both existing/legacy tables, including aliases.
        local freePosition = mobility.freeMovePosition
        mobility.freeMovePosition = Position(freePosition, freePosition == nil and mobility.position or nil)
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
    -- Only our two persistent launcher values belong in this shell record.
    -- Detach the table and discard accidental runtime/third-party fields.
    local minimap = CarGOUIDB.options.minimap
    CarGOUIDB.options.minimap = { hide = minimap.hide, minimapPos = minimap.minimapPos }
    CarGOUIDB.schemaVersion = self.defaults.schemaVersion
    self.db, self.configurationClass, self.procConfigurationCache = CarGOUIDB, nil, {}
    if self.RefreshLauncherSettings then self:RefreshLauncherSettings() end
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
    if entry.kind == "mobility" then
        local config = self:GetMobilityConfig()
        -- Free move shares typography/enable scope, NOT the position table.
        return entry.freeMove and config.freeMovePosition or config.position
    end
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

-- Use the current definition catalog, not aura presence or a list index. This
-- works for future class adapters without a class-specific color UI/database.
function addon:GetCurrentProcRegion(entry)
    if type(entry) ~= "table" or entry.kind ~= "proc" or type(entry.id) ~= "string"
        or not self:GetReminderStyleKey(entry) then return end
    local class, spec = self:GetPlayerContext()
    if entry.class ~= class or entry.specID ~= spec then return end
    for _, candidate in ipairs(self:GetDefinedPreviewEntries() or {}) do
        if candidate.kind == "proc" and candidate.id == entry.id
            and candidate.class == class and candidate.specID == spec then return candidate end
    end
end

function addon:GetProcRegionColor(entry)
    if not self:GetCurrentProcRegion(entry) then return end
    local config = self:GetProcConfig()
    local region = config and config.regions[entry.id]
    return type(region) == "table" and ColorCopy(region.color) or nil
end

function addon:SetProcRegionColor(entry, color)
    if not self:GetCurrentProcRegion(entry) then return false, addon:Text("Choose a defined Proc region for your current specialization.") end
    if color ~= nil and not self:IsValidProcRegionColor(color) then return false, addon:Text("Choose finite RGB values from 0 to 1.") end
    return self:UpdateSettings({ proc = { regions = { [entry.id] = { color = color or false } } } })
end

function addon:GetProcRegionAppearance(entry)
    if not self:GetCurrentProcRegion(entry) then return self:NewProcAppearance() end
    local config = self:GetProcConfig()
    local region = config and config.regions[entry.id]
    return self:NormalizeProcAppearance(type(region) == "table" and region.appearance or nil)
end

function addon:SetProcRegionAppearance(entry, patch, options)
    if not self:GetCurrentProcRegion(entry) then return false, addon:Text("Choose a defined Proc region for your current specialization.") end
    local valid, message = self:ValidateProcAppearance(patch, true)
    if not valid then return false, message end
    return self:UpdateSettings({ proc = { regions = { [entry.id] = { appearance = patch } } } }, options)
end

function addon:ResetProcRegionAppearance(entry)
    if not self:GetCurrentProcRegion(entry) then return false, addon:Text("Choose a defined Proc region for your current specialization.") end
    return self:UpdateSettings({ proc = { regions = { [entry.id] = { appearance = false } } } })
end

function addon:UpdateReminderStyle(key, patch)
    if not self:GetReminderStyleKey(key) then return false, addon:Text("Edit the current class / specialization Appearance.") end
    return self:UpdateSettings({ styles = { [key] = patch } })
end

function addon:ResetReminderStyle(key)
    return self:UpdateReminderStyle(key, self:NewReminderStyle())
end

-- Pure coordinate edits only need to re-anchor their own existing wrappers.
-- These keys describe configuration ownership, not live aura/charge state.
local function PositionChanges(patch, entries)
    local changes = { proc = {} }
    local any = false
    local function Mark(entry)
        if entry.kind == "mobility" then
            changes[entry.freeMove and "freeMove" or "mobility"] = true
        elseif entry.kind == "proc" then changes.proc[entry.id] = true end
        any = true
    end
    for key, value in pairs(patch) do
        if key == "position" then changes.mobility, any = true, true
        elseif key == "mobility" then
            for field in pairs(value) do
                if field == "position" then changes.mobility, any = true, true
                elseif field == "freeMovePosition" then changes.freeMove, any = true, true
                else return end
            end
        elseif key == "reminders" then
            for id, record in pairs(value) do
                if record.position then Mark(entries[id]) end
            end
        elseif key == "proc" then
            for field, regions in pairs(value) do
                if field ~= "regions" then return end
                for id, record in pairs(regions) do
                    for setting in pairs(record) do if setting ~= "position" then return end end
                    if record.position then changes.proc[id], any = true, true end
                end
            end
        else return end
    end
    if any then return changes end
end

local function ContinuousAppearance(patch)
    if type(patch) ~= "table" then return false end
    local preset = false
    for key, value in pairs(patch) do
        if key == "offset" then
            for axis in pairs(value) do if axis ~= "x" and axis ~= "y" then return false end end
        elseif key == "animation" then
            for setting in pairs(value) do
                if setting == "entrance" or setting == "active" or setting == "exit" or setting == "direction" then preset = true
                elseif setting ~= "speed" and setting ~= "intensity" then return false end
            end
        elseif key ~= "artColor" and key ~= "alpha" and key ~= "scale" and key ~= "desaturation"
            and key ~= "rotation" and key ~= "width" and key ~= "height" then return false end
    end
    return true, patch.artColor ~= nil, preset
end

function addon:UpdateSettings(patch, options)
    if not self.db then return false, addon:Text("Settings are not initialized yet.") end
    if type(patch) ~= "table" then return false, addon:Text("Settings must be supplied as a table.") end
    local optionsOnly = patch.options ~= nil
    for key in pairs(patch) do if key ~= "options" then optionsOnly = false end end
    if optionsOnly then
        -- The shell needs neither a player class nor a gameplay catalog.
        -- This also keeps combat drag cleanup independent of active adapters.
        local valid, message = ValidatePatch(patch, { options = optionsSchema }, "")
        if not valid then return false, message end
        MergePatch(self.db.options, patch.options)
        if patch.options.position and self.ApplyOptionsPosition then self:ApplyOptionsPosition() end
        if patch.options.animatedTitle ~= nil and self.RefreshTitleAnimation then self:RefreshTitleAnimation() end
        if patch.options.minimap and self.RefreshLauncherSettings then self:RefreshLauncherSettings() end
        if not (options and options.skipOptionsRefresh) and self.RefreshOptions then self:RefreshOptions() end
        return true
    end
    local class = self:GetPlayerContext()
    local schema = { options = optionsSchema, enabled = BooleanSetting, position = positionSchema,
        mobility = { enabled = BooleanSetting, style = styleSchema, position = positionSchema,
            freeMovePosition = positionSchema, preferences = Preferences },
        proc = { enabled = BooleanSetting, style = styleSchema, regions = {} }, styles = {}, reminders = {} }
    local entries = {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
        entries[entry.id] = entry
        schema.reminders[entry.id] = { position = positionSchema }
        if entry.kind == "proc" then schema.proc.regions[entry.id] = {
            position = positionSchema, color = RegionColorSetting, appearance = RegionAppearanceSetting } end
    end
    for _, kind in ipairs({ "mobility", "proc" }) do
        local context = self:GetAppearanceContext(kind)
        if context then schema.styles[context.key] = styleSchema end
    end
    local valid, message = ValidatePatch(patch, schema, "")
    if not valid then return false, message end
    for key in pairs(patch) do
        if key ~= "options" and not class then return false, addon:Text("Player class is not available yet.") end
    end
    local procContext = self:GetAppearanceContext("proc")
    local writesProc = patch.proc or (procContext and patch.styles and patch.styles[procContext.key])
    if writesProc and (not procContext or not self:GetProcConfig()) then
        return false, addon:Text("Proc settings are unavailable until the current specialization module is ready.")
    end
    local changedPositions = PositionChanges(patch, entries)
    local changedStyles, changedColors, changedAppearances, stylesOnly = {}, {}, {}, true
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
        local config = self:GetProcConfig()
        -- Compute detached artwork objects before the generic merge. A reset
        -- or optional-field sentinel must never become a saved boolean.
        local appearances = {}
        for id, record in pairs(patch.proc.regions or {}) do
            if record.appearance ~= nil then
                local previous = config.regions[id]
                if record.appearance == false then appearances[id] = false
                else appearances[id] = self:MergeProcAppearance(type(previous) == "table" and previous.appearance or nil, record.appearance) end
            end
        end
        MergePatch(config, patch.proc)
        for key in pairs(patch.proc) do if key ~= "style" and key ~= "regions" then stylesOnly = false end end
        for id, record in pairs(patch.proc.regions or {}) do
            if record.position then stylesOnly = false end
            if record.color ~= nil then
                config.regions[id].color = ColorCopy(record.color)
                changedColors[id] = entries[id]
                local draft = self.procRegionColorPreview
                if draft and draft.id == id and draft.class == class and draft.specID == entries[id].specID then
                    self.procRegionColorPreview = nil
                end
            end
            if record.appearance ~= nil then
                config.regions[id].appearance = appearances[id] or nil
                changedAppearances[id] = entries[id]
            end
        end
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
    if changedPositions then
        if self.RefreshReminderPositions then self:RefreshReminderPositions(changedPositions) end
    elseif stylesOnly then
        if self.RefreshReminderStyle then for key in pairs(changedStyles) do self:RefreshReminderStyle(key) end end
        if self.RefreshProcRegionColor then for _, entry in pairs(changedColors) do self:RefreshProcRegionColor(entry) end end
        if self.RefreshProcAppearance then
            for id, entry in pairs(changedAppearances) do
                local appearance = patch.proc.regions[id].appearance
                -- Validated presentation edits retain native ownership. Tint
                -- and numeric edits may retain motion; preset choices still
                -- restart changed owned animations. Modes/sources/reset restore.
                local continuous, tint, preset = ContinuousAppearance(appearance)
                if continuous and (tint or preset or options and options.continuousAppearance)
                    and self.RefreshProcContinuousAppearance then self:RefreshProcContinuousAppearance(entry, not preset)
                else self:RefreshProcAppearance(entry) end
            end
        end
    else self:ApplySettings() end
    if patch.options and patch.options.minimap and self.RefreshLauncherSettings then self:RefreshLauncherSettings() end
    if options and options.skipOptionsRefresh then
        -- A numeric row already synchronizes its committed value. Avoid menu
        -- rebuilding and fresh callbacks on each drag; other callers refresh.
    elseif stylesOnly and next(changedColors) and not next(changedStyles) then
        if self.RefreshProcColorControls then self:RefreshProcColorControls() end
    elseif self.RefreshOptions then self:RefreshOptions() end
    return true
end

function addon:ResetDatabase()
    if self.CancelProcColorPicker then self:CancelProcColorPicker() end
    local class = self:GetPlayerContext()
    if class then self.db.classes[class] = nil end
    if class == "MAGE" then self.db.migrations.scope5.procReset = true end
    -- Reset is deliberately scoped. Other classes and historical migration
    -- backups remain intact; completed migrations never reapply old settings.
    self.db.options = CopyTable(self.defaults.options)
    if self.RefreshLauncherSettings then self:RefreshLauncherSettings() end
    self.configurationClass, self.procConfigurationCache = nil, {}
    self:RefreshConfigurationContext()
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
end
