local _, addon = ...

local limits = { inputBytes = 196608, decodedBytes = 131072, depth = 12,
    tokens = 20000, entries = 2048 }
addon.settingsTransferLimits = limits
local pending
local function Fail(message) error(message, 0) end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end
local function Shallow(value)
    local result = {}
    for key, item in pairs(value or {}) do result[key] = item end
    return result
end
local function Equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function Number(value, low, high, path)
    if type(value) ~= "number" or value ~= value or value < low or value > high then
        Fail(addon:Format("%s: expected a finite number from %g to %g.", path, low, high))
    end
    return value
end
local function Boolean(value, path)
    if type(value) ~= "boolean" then Fail(path .. addon:Text(": expected true or false.")) end
    return value
end
local function Path(parent, key) return parent .. "/" .. key end

-- Full bounded lexical/structural check BEFORE native JSON deserialization.
-- Duplicate keys include escaped equivalents. Null and nonempty arrays are
-- rejected before a decoder can erase/coerce them. Only empty maps may use [].
local function ScanJSON(text)
    local index, tokens, entries, kinds = 1, 0, 0, {}
    local function Skip() local _, last = text:find("^[ \t\r\n]*", index); index = (last or index - 1) + 1 end
    local function Tick()
        tokens = tokens + 1
        if tokens > limits.tokens then Fail(addon:Text("JSON token limit exceeded.")) end
    end
    local function String()
        if text:sub(index, index) ~= '"' then Fail(addon:Text("Expected a JSON string.")) end
        index = index + 1
        local chars = {}
        while index <= #text do
            local ch = text:sub(index, index); index = index + 1
            if ch == '"' then return table.concat(chars) end
            if ch == "\\" then
                local escape = text:sub(index, index); index = index + 1
                local simple = { ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
                if escape == "u" then
                    local hex = text:sub(index, index + 3)
                    if not hex:match("^%x%x%x%x$") then Fail(addon:Text("Invalid JSON Unicode escape.")) end
                    local code = tonumber(hex, 16); index = index + 4
                    if code > 127 then Fail(addon:Text("Settings format uses ASCII protocol tokens only.")) end
                    ch = string.char(code)
                else ch = simple[escape]; if not ch then Fail(addon:Text("Invalid JSON escape.")) end end
            elseif ch:byte() < 32 or ch:byte() > 127 then Fail(addon:Text("Invalid or non-ASCII JSON string.")) end
            chars[#chars + 1] = ch
            if #chars > 160 then Fail(addon:Text("JSON string limit exceeded.")) end
        end
        Fail(addon:Text("Truncated JSON string."))
    end
    local Value
    Value = function(depth, path)
        if depth > limits.depth then Fail(addon:Text("JSON nesting limit exceeded.")) end
        Tick(); Skip()
        local ch = text:sub(index, index)
        if ch == "{" then
            kinds[path] = "object"; index = index + 1; Skip()
            local keys = {}
            if text:sub(index, index) == "}" then index = index + 1; return end
            while true do
                Tick(); Skip(); local key = String()
                if not key:match("^[A-Za-z0-9_]+$") or #key > 100 then Fail(addon:Text("Invalid JSON setting key.")) end
                if keys[key] then Fail(addon:Text("Duplicate JSON key: ") .. key) end
                keys[key] = true; entries = entries + 1
                if entries > limits.entries then Fail(addon:Text("JSON setting count limit exceeded.")) end
                Skip(); if text:sub(index, index) ~= ":" then Fail(addon:Text("Expected JSON colon.")) end
                index = index + 1; Value(depth + 1, Path(path, key)); Skip()
                ch = text:sub(index, index); index = index + 1
                if ch == "}" then return end
                if ch ~= "," then Fail(addon:Text("Expected JSON comma or closing brace.")) end
            end
        elseif ch == "[" then
            index = index + 1; Skip()
            if text:sub(index, index) ~= "]" then Fail(addon:Text("Nonempty JSON arrays are not settings maps.")) end
            index = index + 1; kinds[path] = "emptyArray"
        elseif ch == '"' then String()
        elseif text:sub(index, index + 3) == "null" then Fail(addon:Text("JSON null is not a setting value."))
        elseif text:sub(index, index + 3) == "true" then index = index + 4
        elseif text:sub(index, index + 4) == "false" then index = index + 5
        else
            local first = index
            if ch == "-" then index = index + 1 end
            if text:sub(index, index) == "0" then index = index + 1
            else
                local _, last = text:find("^[1-9][0-9]*", index)
                if not last then Fail(addon:Text("Invalid JSON value.")) end
                index = last + 1
            end
            if text:sub(index, index) == "." then
                index = index + 1; local _, last = text:find("^[0-9]+", index)
                if not last then Fail(addon:Text("Invalid JSON fraction.")) end; index = last + 1
            end
            if text:sub(index, index):match("[eE]") then
                index = index + 1
                if text:sub(index, index):match("[+-]") then index = index + 1 end
                local _, last = text:find("^[0-9]+", index)
                if not last then Fail(addon:Text("Invalid JSON exponent.")) end; index = last + 1
            end
            if index - first > 48 then Fail(addon:Text("JSON number limit exceeded.")) end
            Number(tonumber(text:sub(first, index - 1)), -1e9, 1e9, "JSON number")
        end
    end
    Value(1, ""); Skip()
    if index <= #text then Fail(addon:Text("Trailing or malformed JSON data.")) end
    return kinds
end

local function Map(value, allowed, path, kinds, empty)
    if type(value) ~= "table" or getmetatable(value) ~= nil then Fail(path .. addon:Text(": expected a plain settings object.")) end
    if kinds and kinds[path] == "emptyArray" and not empty then Fail(path .. addon:Text(": an object is required.")) end
    for key in pairs(value) do
        if type(key) ~= "string" or (allowed and not allowed[key]) then Fail(path .. addon:Text(": unknown field ") .. tostring(key)) end
    end
    return value
end
local function Keys(list)
    local result = {}; for key in list:gmatch("%S+") do result[key] = true end; return result
end
local fontPaths = { friz = "Fonts\\FRIZQT__.ttf", arial = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF", skurri = "Fonts\\skurri.ttf" }
local fontProbe
local function FontAvailable(self, face)
    if type(face) ~= "string" or not self:IsSupportedFont(face) then return false end
    if not fontProbe then
        if type(CreateFont) ~= "function" then Fail(addon:Text("Native font verification is unavailable.")) end
        fontProbe = CreateFont("CarGOUISettingsTransferFontProbe")
    end
    -- This is an isolated public scratch Font and a trusted built-in resource.
    -- Never inspect a timer FontString or infer anything about protected data.
    local ok, result = pcall(fontProbe.SetFont, fontProbe, face, 12, "")
    if not ok or result == false then return false end
    local actual = fontProbe:GetFont()
    return type(actual) == "string" and actual:lower():gsub("/", "\\") == face:lower():gsub("/", "\\")
end
local function FontToken(self, face)
    for token, path in pairs(fontPaths) do if type(face) == "string" and face:lower() == path:lower() then return token end end
    for _, path in ipairs(self.clientFontPaths) do
        if type(face) == "string" and face:lower() == path:lower() then return "client-default" end
    end
    if type(STANDARD_TEXT_FONT) == "string" and face == STANDARD_TEXT_FONT and self:IsSupportedFont(face) then return "client-default" end
    Fail(addon:Text("Unsupported saved font resource; choose a built-in or client default font before exporting."))
end
local function FontPath(self, token, warnings)
    local face = token == "client-default" and STANDARD_TEXT_FONT or fontPaths[token]
    if token ~= "client-default" and not fontPaths[token] then Fail(addon:Text("Unknown font token; external paths are not permitted.")) end
    if FontAvailable(self, face) then return face end
    local fallback = type(STANDARD_TEXT_FONT) == "string" and self:IsSupportedFont(STANDARD_TEXT_FONT)
        and STANDARD_TEXT_FONT or self.factoryReminderStyle.font.face
    if not FontAvailable(self, fallback) then Fail(addon:Text("Neither the requested font nor the local default font is available.")) end
    warnings[#warnings + 1] = addon:Format("Font %s is unavailable locally; a compatible font will be used for display. Your saved choice is retained.", token)
    return face or fallback -- Preserve a recognized saved choice; render fallback is separate.
end

local function Position(value, path, kinds, shell)
    Map(value, Keys(shell and "x y" or "anchor x y"), path, kinds)
    if not shell and value.anchor ~= "CENTER" then Fail(path .. addon:Text(": only CENTER is supported.")) end
    local bound = shell and 10000 or 20000
    local result = { x = Number(value.x, -bound, bound, path .. ".x"),
        y = Number(value.y, -bound, bound, path .. ".y") }
    if not shell then result.anchor = "CENTER" end
    return result
end
local function Minimap(value, path, kinds)
    Map(value, Keys("hide minimapPos"), path, kinds)
    return { hide = Boolean(value.hide, path .. ".hide"),
        minimapPos = Number(value.minimapPos, -360, 360, path .. ".minimapPos") }
end
local function Preferences(value, path, kinds)
    Map(value, Keys("skillDisplay"), path, kinds, true)
    local result = {}
    if value.skillDisplay ~= nil then
        Map(value.skillDisplay, Keys("label"), Path(path, "skillDisplay"), kinds)
        result.skillDisplay = { label = Boolean(value.skillDisplay.label, path .. ".skillDisplay.label") }
    end
    return result
end
local function Style(self, value, path, kinds, warnings)
    Map(value, Keys("font scale shadow"), path, kinds)
    Map(value.font, Keys("face size outline"), Path(path, "font"), kinds)
    Map(value.shadow, Keys("enabled"), Path(path, "shadow"), kinds)
    local font = value.font
    if type(font.face) ~= "string" then Fail(path .. addon:Text(": expected a symbolic font token.")) end
    if not self.outlines[font.outline] then Fail(path .. addon:Text(": invalid outline.")) end
    return { font = { face = FontPath(self, font.face, warnings),
        size = Number(font.size, 8, 72, path .. ".font.size"), outline = font.outline },
        scale = Number(value.scale, .5, 3, path .. ".scale"),
        shadow = { enabled = Boolean(value.shadow.enabled, path .. ".shadow.enabled") } }
end
local function ValidateEnvelope(self, value, kinds)
    Map(value, Keys("formatVersion schemaVersion addonVersion project scope classes options"), "", kinds)
    if value.formatVersion ~= 1 or value.schemaVersion ~= 5 then Fail(addon:Text("Unsupported settings format or schema version.")) end
    if value.project ~= "Retail" then Fail(addon:Text("This settings package is not for Retail.")) end
    if type(value.addonVersion) ~= "string" or #value.addonVersion > 48
        or not value.addonVersion:match("^[A-Za-z0-9%.%+%-]+$") then Fail(addon:Text("Invalid source addon version.")) end
    if value.scope ~= "class" and value.scope ~= "all" then Fail(addon:Text("Unknown export scope.")) end
    Map(value.classes, nil, "/classes", kinds, true)
    local result, warnings, count, totalRegions = { classes = {}, scope = value.scope }, {}, 0, 0
    for class, record in pairs(value.classes) do
        local roster = self.settingsMetadata.classes[class]
        if not roster then Fail(addon:Text("Unknown class: ") .. class) end
        count = count + 1
        local path = "/classes/" .. class
        Map(record, Keys("mobility proc"), path, kinds)
        if record.mobility == nil and record.proc == nil then Fail(path .. addon:Text(": no settings included.")) end
        local target = {}; result.classes[class] = target
        if record.mobility ~= nil then
            local m, mp = record.mobility, path .. "/mobility"
            Map(m, Keys("enabled style position freeMovePosition preferences"), mp, kinds)
            target.mobility = { enabled = Boolean(m.enabled, mp .. ".enabled"),
                style = Style(self, m.style, mp .. "/style", kinds, warnings),
                position = Position(m.position, mp .. "/position", kinds),
                freeMovePosition = Position(m.freeMovePosition, mp .. "/freeMovePosition", kinds),
                preferences = Preferences(m.preferences, mp .. "/preferences", kinds) }
        end
        if record.proc ~= nil then
            Map(record.proc, nil, path .. "/proc", kinds, true); target.proc = {}
            for key, proc in pairs(record.proc) do
                local spec = tonumber(key)
                if not spec or tostring(spec) ~= key or not roster[spec] then Fail(path .. addon:Text(": wrong or unknown specialization.")) end
                local pp = path .. "/proc/" .. key
                Map(proc, Keys("enabled style regions"), pp, kinds)
                Map(proc.regions, nil, pp .. "/regions", kinds, true)
                local out = { enabled = Boolean(proc.enabled, pp .. ".enabled"),
                    style = Style(self, proc.style, pp .. "/style", kinds, warnings), regions = {} }
                target.proc[spec] = out
                for id, region in pairs(proc.regions) do
                    if not roster[spec][id] then Fail(pp .. addon:Text(": unknown stable region ") .. id) end
                    totalRegions = totalRegions + 1
                    if totalRegions > 256 then Fail(addon:Text("Too many Proc regions.")) end
                    local rp = pp .. "/regions/" .. id
                    Map(region, Keys("position color"), rp, kinds)
                    local r = { position = Position(region.position, rp .. "/position", kinds) }
                    if region.color ~= nil then
                        Map(region.color, Keys("r g b"), rp .. "/color", kinds)
                        r.color = { r = Number(region.color.r, 0, 1, rp .. ".color.r"),
                            g = Number(region.color.g, 0, 1, rp .. ".color.g"), b = Number(region.color.b, 0, 1, rp .. ".color.b") }
                    end
                    out.regions[id] = r
                end
            end
        end
    end
    if count > 13 or (value.scope == "class" and count ~= 1) then Fail(addon:Text("Invalid class scope count.")) end
    if value.options ~= nil then
        if value.scope ~= "all" then Fail(addon:Text("Current class packages cannot change the Options shell.")) end
        Map(value.options, Keys("position animatedTitle minimap"), "/options", kinds)
        result.options = { position = Position(value.options.position, "/options/position", kinds, true),
            animatedTitle = Boolean(value.options.animatedTitle, "options.animatedTitle") }
        -- Optional for format-1 strings exported by RC1/RC2. Missing is not a
        -- request to overwrite the recipient's launcher preferences.
        if value.options.minimap ~= nil then
            result.options.minimap = Minimap(value.options.minimap, "/options/minimap", kinds)
        end
    end
    if count == 0 and result.options == nil then Fail(addon:Text("The package contains no settings.")) end
    return result, warnings
end

local function SavedPosition(value, fallback, shell)
    value = type(value) == "table" and value or {}
    fallback = fallback or { x = 0, y = 0 }
    local p = { x = value.x == nil and fallback.x or value.x, y = value.y == nil and fallback.y or value.y }
    if not shell then p.anchor = value.anchor or "CENTER" end
    return Position(p, "saved position", nil, shell)
end
local function SavedStyle(self, value)
    value = type(value) == "table" and value or {}
    local defaults = self:NewReminderStyle()
    local font = type(value.font) == "table" and value.font or {}
    local shadow = type(value.shadow) == "table" and value.shadow or {}
    local outline = font.outline == nil and defaults.font.outline or font.outline
    if not self.outlines[outline] then Fail(addon:Text("Invalid saved outline.")) end
    return { font = { face = FontToken(self, font.face or defaults.font.face),
        size = Number(font.size or defaults.font.size, 8, 72, "saved font size"), outline = outline },
        scale = Number(value.scale or defaults.scale, .5, 3, "saved scale"),
        shadow = { enabled = shadow.enabled == nil and defaults.shadow.enabled or Boolean(shadow.enabled, "saved shadow") } }
end
local function Snapshot(self, scope)
    if not self.db or not self.settingsMetadata then Fail(addon:Text("Settings are not initialized.")) end
    if scope ~= "class" and scope ~= "all" then Fail(addon:Text("Choose Current class or All saved settings.")) end
    local current = self:GetPlayerContext()
    if scope == "class" and not self.settingsMetadata.classes[current] then Fail(addon:Text("Player class is unavailable.")) end
    local result = { formatVersion = 1, schemaVersion = 5, addonVersion = self.version,
        project = "Retail", scope = scope, classes = {} }
    for class, roster in pairs(self.settingsMetadata.classes) do
        local record = self.db.classes and self.db.classes[class]
        if (scope == "all" or class == current) and type(record) == "table" then
            local target = {}
            if record.mobility ~= nil then
                if type(record.mobility) ~= "table" then Fail(addon:Text("Malformed saved Mobility: ") .. class) end
                local m = record.mobility
                local pos = SavedPosition(m.position)
                target.mobility = { enabled = m.enabled == nil and true or Boolean(m.enabled, "saved Mobility enabled"),
                    style = SavedStyle(self, m.style), position = pos,
                    freeMovePosition = SavedPosition(m.freeMovePosition, m.freeMovePosition == nil and pos or nil),
                    preferences = Preferences(m.preferences or {}, class .. ".preferences") }
            end
            if record.proc ~= nil then
                if type(record.proc) ~= "table" then Fail(addon:Text("Malformed saved Proc: ") .. class) end
                target.proc = {}
                for spec, proc in pairs(record.proc) do
                    if type(spec) ~= "number" or not roster[spec] or type(proc) ~= "table" then Fail(addon:Text("Unknown saved specialization in ") .. class) end
                    local out = { enabled = proc.enabled == nil and true or Boolean(proc.enabled, "saved Proc enabled"),
                        style = SavedStyle(self, proc.style), regions = {} }
                    target.proc[tostring(spec)] = out
                    if proc.regions ~= nil and type(proc.regions) ~= "table" then Fail(addon:Text("Malformed saved Proc regions.")) end
                    for id, region in pairs(proc.regions or {}) do
                        if not roster[spec][id] or type(region) ~= "table" then Fail(addon:Text("Unknown saved region in ") .. class .. ": " .. tostring(id)) end
                        local r = { position = SavedPosition(region.position) }
                        if region.color ~= nil then
                            if not self:IsValidProcRegionColor(region.color) then Fail(addon:Text("Malformed saved Proc color.")) end
                            r.color = { r = region.color.r, g = region.color.g, b = region.color.b }
                        end
                        out.regions[id] = r
                    end
                end
            end
            if next(target) then result.classes[class] = target end
        end
    end
    if scope == "all" then
        local options = self.db.options or {}
        local minimap = options.minimap
        if minimap ~= nil and type(minimap) ~= "table" then Fail(addon:Text("Malformed saved minimap settings.")) end
        minimap = minimap or self.defaults.options.minimap
        result.options = { position = SavedPosition(options.position, nil, true),
            animatedTitle = options.animatedTitle == nil and true or Boolean(options.animatedTitle, "saved title animation"),
            -- Pick our own fields instead of serializing library/runtime state.
            minimap = Minimap({ hide = minimap.hide, minimapPos = minimap.minimapPos }, "saved minimap") }
    elseif not result.classes[current] then Fail(addon:Text("No saved settings exist for the current class.")) end
    return result
end

local function Codec()
    local api = C_EncodingUtil
    if not api or type(api.SerializeJSON) ~= "function" or type(api.DeserializeJSON) ~= "function"
        or type(api.EncodeBase64) ~= "function" or type(api.DecodeBase64) ~= "function" then
        Fail(addon:Text("This client does not provide the required native JSON/Base64 APIs."))
    end
    return api
end
local function Serialize(value)
    local api = Codec()
    local ok, text = pcall(api.SerializeJSON, value, { ignoreSerializationErrors = false })
    if not ok or type(text) ~= "string" then Fail(addon:Text("Native JSON serialization failed.")) end
    if #text > limits.decodedBytes then Fail(addon:Text("Decoded settings size limit exceeded.")) end
    ScanJSON(text)
    return text
end
local function Decode(text)
    if type(text) ~= "string" or #text == 0 then Fail(addon:Text("Paste a complete settings string first.")) end
    if #text > limits.inputBytes then Fail(addon:Format("Input exceeds %d bytes; nothing was imported.", limits.inputBytes)) end
    text = text:match("^%s*(.-)%s*$")
    local version, payload = text:match("^CARGOUICFG:(%d+):(.*)$")
    if not version then Fail(addon:Text("Expected CARGOUICFG:1: settings prefix.")) end
    if version ~= "1" then Fail(addon:Text("Unsupported settings format version.")) end
    payload = payload:gsub("[ \t\r\n]", "")
    if #payload == 0 or #payload % 4 ~= 0 or not payload:match("^[A-Za-z0-9+/]*=?=?$") then
        Fail(addon:Text("Invalid or truncated standard Base64 payload."))
    end
    local padding = payload:sub(-2) == "==" and 2 or payload:sub(-1) == "=" and 1 or 0
    if #payload / 4 * 3 - padding > limits.decodedBytes then Fail(addon:Text("Decoded settings size limit exceeded.")) end
    local api = Codec()
    local ok, decoded = pcall(api.DecodeBase64, payload)
    if not ok or type(decoded) ~= "string" or #decoded > limits.decodedBytes then Fail(addon:Text("Native Base64 decoding failed.")) end
    local encodedOK, encoded = pcall(api.EncodeBase64, decoded)
    if not encodedOK or encoded ~= payload then Fail(addon:Text("Noncanonical or invalid Base64 payload.")) end
    local kinds = ScanJSON(decoded)
    local parsedOK, value = pcall(api.DeserializeJSON, decoded)
    if not parsedOK or type(value) ~= "table" then Fail(addon:Text("Native JSON parsing failed.")) end
    return value, kinds
end
local function Context(self)
    if not self.initialized or type(self.db) ~= "table" then Fail(addon:Text("Settings are not initialized.")) end
    if InCombatLockdown and InCombatLockdown() then Fail(addon:Text("Settings transfer is unavailable in combat.")) end
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then Fail(addon:Text("Open Options before preparing or confirming an import.")) end
    local class, spec = self:GetPlayerContext()
    if not class then Fail(addon:Text("Player identity is not ready.")) end
    return { class = class, spec = spec, panel = panel, category = panel.activeCategory, db = self.db }
end
local function MergeCandidate(self, incoming, restore)
    local classes = restore and {} or Shallow(self.db.classes)
    for class, value in pairs(incoming.classes) do
        local record = restore and {} or Shallow(classes[class])
        if value.mobility then record.mobility = Copy(value.mobility) end
        if value.proc then
            record.proc = restore and {} or Shallow(record.proc)
            for spec, proc in pairs(value.proc) do
                local existing = restore and {} or Shallow(record.proc[spec])
                existing.enabled, existing.style = proc.enabled, Copy(proc.style)
                existing.regions = restore and {} or Shallow(existing.regions)
                for id, region in pairs(proc.regions) do
                    -- A whole included region replaces its old override. An
                    -- omitted color explicitly restores dynamic class color.
                    existing.regions[id] = Copy(region)
                end
                record.proc[spec] = existing
            end
        end
        classes[class] = record
    end
    local options = incoming.options and Copy(incoming.options) or self.db.options
    if incoming.options and not incoming.options.minimap then
        -- Older all-settings imports and backups keep the current preference.
        -- A provided minimap snapshot instead owns a fresh validated table.
        options.minimap = self.db.options.minimap
    end
    return { classes = classes, options = options }
end
local function Summary(incoming, before, context, warnings, restore)
    local names, specs, regions, mobility = {}, 0, 0, 0
    for class, record in pairs(incoming.classes) do
        names[#names + 1] = class
        if record.mobility then mobility = mobility + 1 end
        for _, proc in pairs(record.proc or {}) do
            specs = specs + 1; for _ in pairs(proc.regions) do regions = regions + 1 end
        end
    end
    table.sort(names)
    local lines = { restore and addon:Text("Restore the saved configuration from before the latest import?") or addon:Text("Import validated settings?"),
        addon:Format("Classes: %s", #names > 0 and table.concat(names, ", ") or addon:Text("none")),
        addon:Format("Mobility snapshots: %d; Proc specializations: %d; Proc regions: %d.", mobility, specs, regions),
        incoming.options and (incoming.options.minimap
            and addon:Text("Options position, title animation and minimap icon settings are included.")
            or addon:Text("Options position and title animation are included; minimap icon settings are unchanged."))
            or addon:Text("Options shell settings are unchanged."),
        restore and addon:Text("This restores the complete backup; settings added after that backup are removed.")
            or addon:Text("Only included scopes are replaced. Other classes, specializations and regions are unchanged."),
        addon:Text("Included regions without RGB use the current class color, clearing any old override."),
        addon:Text("Mobility and Free move offsets remain independent.") }
    for _, class in ipairs(names) do
        local record = incoming.classes[class]
        lines[#lines + 1] = addon:Format("%s: Mobility %s", class, record.mobility and addon:Text("included.") or addon:Text("not included."))
        local orderedSpecs = {}
        for spec in pairs(record.proc or {}) do orderedSpecs[#orderedSpecs + 1] = spec end
        table.sort(orderedSpecs)
        for _, spec in ipairs(orderedSpecs) do
            local orderedRegions = {}
            for id in pairs(record.proc[spec].regions) do orderedRegions[#orderedRegions + 1] = id end
            table.sort(orderedRegions)
            lines[#lines + 1] = addon:Format("%s Proc %d: shared style and enabled setting; %d region record(s).", class, spec, #orderedRegions)
            if #orderedRegions > 0 then lines[#lines + 1] = addon:Format("Regions: %s", table.concat(orderedRegions, ", ")) end
        end
    end
    if not incoming.classes[context.class] and not restore then
        lines[#lines + 1] = addon:Format("The current %s reminder appearance is unchanged.", context.class)
    end
    for _, warning in ipairs(warnings) do lines[#lines + 1] = warning end
    lines[#lines + 1] = addon:Text("Confirm to save. Cancel leaves settings unchanged.")
    return table.concat(lines, "\n")
end
local function Prepare(self, wire, kinds, restore)
    local context = Context(self)
    local incoming, warnings = ValidateEnvelope(self, wire, kinds)
    local before = Snapshot(self, "all")
    Serialize(before) -- Bound and validate the one recoverable backup now.
    local candidate = MergeCandidate(self, incoming, restore)
    local summary = Summary(incoming, before, context, warnings, restore)
    local handle = { summary = summary }
    pending = { owner = self, handle = handle, summary = summary, context = context,
        before = before, incoming = incoming, candidate = candidate, restore = restore }
    return handle
end

function addon:ExportSettings(scope)
    local ok, result = pcall(function()
        if InCombatLockdown and InCombatLockdown() then Fail(addon:Text("Settings transfer is unavailable in combat.")) end
        local text = Serialize(Snapshot(self, scope or "class"))
        local success, payload = pcall(Codec().EncodeBase64, text)
        if not success or type(payload) ~= "string" then Fail(addon:Text("Native Base64 encoding failed.")) end
        local output = "CARGOUICFG:1:" .. payload
        if #output > limits.inputBytes then Fail(addon:Text("Encoded settings size limit exceeded.")) end
        return output
    end)
    if not ok then return nil, tostring(result) end
    return result
end
function addon:CancelSettingsImport()
    if pending and pending.owner == self then pending = nil end
end
function addon:PrepareSettingsImport(text)
    self:CancelSettingsImport()
    local ok, result = pcall(function()
        Context(self)
        local value, kinds = Decode(text)
        return Prepare(self, value, kinds, false)
    end)
    if not ok then return nil, tostring(result) end
    return result
end
function addon:HasSettingsImportBackup()
    local backup = self.db and self.db.settingsImportBackup
    return type(backup) == "table" and backup.version == 1 and type(backup.settings) == "table"
end
function addon:PrepareSettingsRestore()
    self:CancelSettingsImport()
    local ok, result = pcall(function()
        Context(self)
        if not self:HasSettingsImportBackup() then Fail(addon:Text("No settings import backup is available.")) end
        local wire = self.db.settingsImportBackup.settings
        -- Re-serialize and scan even persisted backup data. It cannot bypass
        -- parser budgets, schema checks or cycle/error handling on restoration.
        local text = Serialize(wire)
        return Prepare(self, wire, ScanJSON(text), true)
    end)
    if not ok then return nil, tostring(result) end
    return result
end

-- Compare only transferable settings. This facade lets the read-only snapshot
-- code inspect a proposed tree without installing it or calling config getters.
local function CandidateSnapshot(self, candidate)
    local facade = setmetatable({ db = candidate }, { __index = self })
    return Snapshot(facade, "all")
end
local function ApplyTransferredSettings(self, before, after, context, wasPreview)
    -- Synchronize even when imported scalar values are equal: atomic commit
    -- may have installed a fresh minimap table. The launcher retains its bound
    -- table, copies the validated preferences into it, and restores that ref.
    if self.RefreshLauncherSettings then self:RefreshLauncherSettings() end
    local oldClass, newClass = before.classes[context.class] or {}, after.classes[context.class] or {}
    local oldMobility, newMobility = oldClass.mobility or {}, newClass.mobility or {}
    local spec = context.spec and tostring(context.spec)
    local oldProc = spec and oldClass.proc and oldClass.proc[spec] or {}
    local newProc = spec and newClass.proc and newClass.proc[spec] or {}
    local mobilityEnabled = oldMobility.enabled ~= newMobility.enabled
    local procEnabled = oldProc.enabled ~= newProc.enabled
    local changes = { proc = {} }
    changes.mobility = not Equal(oldMobility.position, newMobility.position)
    changes.freeMove = not Equal(oldMobility.freeMovePosition, newMobility.freeMovePosition)
    local colors, ids = {}, {}
    for id in pairs(oldProc.regions or {}) do ids[id] = true end
    for id in pairs(newProc.regions or {}) do ids[id] = true end
    for id in pairs(ids) do
        local oldRegion, newRegion = (oldProc.regions or {})[id] or {}, (newProc.regions or {})[id] or {}
        if not Equal(oldRegion.position, newRegion.position) then changes.proc[id] = true end
        if not Equal(oldRegion.color, newRegion.color) then colors[id] = true end
    end
    if not Equal(oldClass, newClass) then
        -- Existing native bindings hold state/providers, not these getter caches.
        self.configurationClass, self.procConfigurationCache = nil, {}
        self:RefreshConfigurationContext()
    end
    if changes.mobility or changes.freeMove or next(changes.proc) then
        if self.RefreshReminderPositions then self:RefreshReminderPositions(changes) end
    end
    if not Equal(oldMobility.style, newMobility.style) and self.RefreshReminderStyle then
        self:RefreshReminderStyle("mobility:" .. context.class)
    end
    if spec and not Equal(oldProc.style, newProc.style) and self.RefreshReminderStyle then
        self:RefreshReminderStyle("proc:" .. context.class .. ":" .. spec)
    end
    if next(colors) and self.RefreshProcRegionColor then
        -- Existing wrappers are enough: do not initialize catalogs or adapters
        -- just to recolor settings imported for an inactive region.
        local touched = {}
        for _, pool in pairs(self.reminderFrames or {}) do
            for _, frame in pairs(pool) do
                local entry = frame.reminderEntry
                if entry and entry.kind == "proc" and entry.class == context.class
                    and entry.specID == context.spec and colors[entry.id] and not touched[entry.id] then
                    touched[entry.id] = true; self:RefreshProcRegionColor(entry)
                end
            end
        end
    end
    if not Equal(before.options.position, after.options.position) and self.ApplyOptionsPosition then self:ApplyOptionsPosition() end
    if before.options.animatedTitle ~= after.options.animatedTitle and self.RefreshTitleAnimation then self:RefreshTitleAnimation() end
    -- Functional enable changes can activate/deactivate a module. Appearance
    -- changes alone never query cooldowns, rebuild filters or bind durations.
    if mobilityEnabled then
        if self.ConfigureMobility then self:ConfigureMobility() end
        if self.ConfigureFreeMove then self:ConfigureFreeMove() end
    elseif wasPreview then
        if self.RenderMobilityState then self:RenderMobilityState() end
        if self.RenderFreeMoveState then self:RenderFreeMoveState() end
    end
    if procEnabled then
        if self.ConfigureProc then self:ConfigureProc() end
    elseif wasPreview and self.RenderProcState then self:RenderProcState() end
    if self.RefreshOptions then self:RefreshOptions() end
end

function addon:ConfirmSettingsImport(transaction)
    local record = pending
    local valid, result = pcall(function()
        if not record or record.owner ~= self or record.handle ~= transaction then Fail(addon:Text("Import confirmation is stale; prepare it again.")) end
        if type(transaction) ~= "table" or getmetatable(transaction) ~= nil
            or transaction.summary ~= record.summary then Fail(addon:Text("Import confirmation was modified; prepare it again.")) end
        for key in pairs(transaction) do if key ~= "summary" then Fail(addon:Text("Import confirmation was modified; prepare it again.")) end end
        local context = Context(self)
        for _, key in ipairs({ "class", "spec", "panel", "category", "db" }) do
            if context[key] ~= record.context[key] then Fail(addon:Text("Options or player context changed; prepare the import again.")) end
        end
        if not Equal(Snapshot(self, "all"), record.before) then Fail(addon:Text("Settings changed after the summary; prepare the import again.")) end
        local after = CandidateSnapshot(self, record.candidate)
        -- Validate backup size again before any owned UI or database mutation.
        Serialize(record.before)
        return after
    end)
    if not valid then
        self:CancelSettingsImport()
        return false, tostring(result)
    end
    pending = nil
    if self.CancelProcColorPicker then self:CancelProcColorPicker() end
    local wasPreview = self.previewState and self.previewState.mode ~= "off"
    if wasPreview and self.StopPreview then self:StopPreview(true) end
    -- No callbacks or yields occur between these assignments. Keep the root
    -- SavedVariables table so existing references remain valid.
    -- Restore always means the latest pre-import snapshot, not an undo/redo
    -- toggle. Only an ordinary new import replaces that recoverable snapshot.
    local backup = record.restore and self.db.settingsImportBackup
        or { version = 1, settings = Copy(record.before) }
    self.db.classes = record.candidate.classes
    self.db.options = record.candidate.options
    self.db.settingsImportBackup = backup
    local applied, message = pcall(ApplyTransferredSettings, self, record.before, result, record.context, wasPreview)
    if not applied then
        -- The validated commit succeeded. A presentation error must not be
        -- reported as a rejected import; the backup remains recoverable.
        if self.Print then self:Print(addon:Text("Settings saved, but display refresh failed: ") .. tostring(message)) end
        return true, addon:Text("Settings saved; reload to refresh the display.")
    end
    return true
end
