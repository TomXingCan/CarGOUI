local _, addon = ...

local wideLocales = { zhCN = true, zhTW = true, ruRU = true, koKR = true }
local builtins = {
    { value = "Fonts\\FRIZQT__.ttf", label = "Friz Quadrata", roman = true },
    { value = "Fonts\\ARIALN.TTF", label = "Arial Narrow", roman = true },
    { value = "Fonts\\MORPHEUS.TTF", label = "Morpheus", roman = true },
    { value = "Fonts\\skurri.ttf", label = "Skurri", roman = true },
    { value = "Fonts\\ARKai_T.ttf", label = "ARKai", locale = "zhCN" },
    { value = "Fonts\\blei00d.TTF", label = "Blei", locale = "zhTW" },
    { value = "Fonts\\FRIZQT___CYR.TTF", label = "Friz Quadrata (Cyrillic)", locale = "ruRU" },
    { value = "Fonts\\2002.TTF", label = "2002", locale = "koKR" },
}
local builtinByPath, fontAvailability = {}, {}
local media, fontProbe

local function PublicString(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "string" and value ~= ""
end

local function PathKey(face)
    return face:lower():gsub("/", "\\")
end

for _, entry in ipairs(builtins) do builtinByPath[PathKey(entry.value)] = entry end
local clientFace = PublicString(STANDARD_TEXT_FONT) and STANDARD_TEXT_FONT or builtins[1].value
local knownClient = builtinByPath[PathKey(clientFace)]
if knownClient then clientFace = knownClient.value end
addon.defaultReminderFont = wideLocales[addon.clientLocale] and clientFace or builtins[1].value
-- Historical persisted resources remain valid across client installations.
addon.clientFontPaths = { builtins[5].value, builtins[6].value, builtins[7].value, builtins[8].value }

function addon:GetSharedMediaFontName(face)
    if not PublicString(face) or face:sub(1, 4):upper() ~= "LSM:" then return nil end
    local name = face:sub(5)
    if #name == 0 or #name > 128 or name:find("^%s") or name:find("%s$")
        or name:find("[%c\\/:|]") then return nil end
    return name
end

function addon:IsSupportedFont(face)
    if not PublicString(face) then return false end
    local name = self:GetSharedMediaFontName(face)
    if name then return true, "LSM:" .. name end
    -- Arbitrary raw paths are never configuration identifiers. The sole extra
    -- client path comes from Blizzard's trusted global, not an imported value.
    local entry = builtinByPath[face:lower()]
    if entry then return true, entry.value end
    if face:lower() == clientFace:lower() then return true, clientFace end
    return false
end

local function FontAvailable(face)
    if not PublicString(face) then return false end
    local key = PathKey(face)
    if fontAvailability[key] ~= nil then return fontAvailability[key] end
    if type(CreateFont) ~= "function" then return false end
    fontProbe = fontProbe or CreateFont("CarGOUIReminderFontProbe")
    -- This public scratch Font proves file availability only. Glyph coverage
    -- comes from the locale policy and LSM's filtered registration contract.
    local ok, result = pcall(fontProbe.SetFont, fontProbe, face, 12, "")
    local readOK, actual = false, nil
    if ok and result ~= false then readOK, actual = pcall(fontProbe.GetFont, fontProbe) end
    local available = readOK and PublicString(actual) and PathKey(actual) == key or false
    fontAvailability[key] = available
    return available
end

local function OnMediaRegistered(_, mediaType)
    if mediaType ~= "font" then return end
    fontAvailability = {}
    if addon.RefreshReminderFonts then addon:RefreshReminderFonts() end
    if addon.RefreshOptions then addon:RefreshOptions() end
end

local function GetMedia()
    if not media and LibStub then
        media = LibStub("LibSharedMedia-3.0", true)
        if media and media.RegisterCallback then
            media.RegisterCallback(addon, "LibSharedMedia_Registered", OnMediaRegistered)
        end
    end
    return media
end

local function MediaPath(name)
    local library = GetMedia()
    if not library or not library.HashTable then return nil end
    -- HashTable contains only fonts accepted by LSM's locale mask filter.
    -- Fetch(..., true) still applies a global override; exact saved identities
    -- must resolve their own registered path instead of an unrelated font.
    local registered = library:HashTable("font")
    local path = registered and registered[name]
    return PublicString(path) and path or nil
end

local function CompatibleWithLocale(face)
    if not wideLocales[addon.clientLocale] or PathKey(face) == PathKey(clientFace) then return true end
    local entry = builtinByPath[PathKey(face)]
    return not entry or (not entry.roman and entry.locale == addon.clientLocale)
end

local function PhysicalLabel(face)
    if PathKey(face) == PathKey(clientFace) then return addon:Text("Client default") end
    local entry = builtinByPath[PathKey(face)]
    return entry and entry.label or addon:Text("Client default")
end

function addon:GetReminderFontStatus(face)
    local valid, canonical = self:IsSupportedFont(face)
    local name = valid and self:GetSharedMediaFontName(canonical)
    local selectedLabel, path, reason
    if not valid then
        selectedLabel, reason = self:Text("Unsupported font"), "invalid"
    elseif name then
        selectedLabel, path = name, MediaPath(name)
        if not path then reason = "missing-media" end
    else
        selectedLabel, path = PhysicalLabel(canonical), canonical
    end
    if path and not name and not CompatibleWithLocale(path) then reason = "locale" end
    if path and not reason and not FontAvailable(path) then reason = "unavailable" end
    local effectiveFace = not reason and path or clientFace
    return {
        selectedFace = canonical, selectedLabel = selectedLabel,
        effectiveFace = effectiveFace,
        effectiveLabel = not reason and name or PhysicalLabel(effectiveFace),
        fallbackReason = reason, effectiveAvailable = FontAvailable(effectiveFace),
    }
end

function addon:ResolveReminderFont(face)
    return self:GetReminderFontStatus(face).effectiveFace
end

function addon:GetReminderFontOptions()
    local result, seen = {}, {}
    local function Add(value, label, always)
        local status = self:GetReminderFontStatus(value)
        local key = PathKey(status.effectiveFace)
        if not seen[key] and (always or (not status.fallbackReason and status.effectiveAvailable)) then
            seen[key] = true
            -- Picker labels identify the typeface; persisted values retain provenance.
            result[#result + 1] = { value = value, label = label }
        end
    end
    Add(clientFace, knownClient and knownClient.label or self:Text("Client default"), true)
    if not wideLocales[self.clientLocale] then
        for index = 1, 4 do Add(builtins[index].value, builtins[index].label) end
    end
    local library = GetMedia()
    local names = {}
    for name in pairs(library and library:HashTable("font") or {}) do
        if self:GetSharedMediaFontName("LSM:" .. name) then names[#names + 1] = name end
    end
    table.sort(names, function(left, right)
        local a, b = left:lower(), right:lower()
        if a == b then return left < right end
        return a < b
    end)
    for _, name in ipairs(names) do Add("LSM:" .. name, name) end
    return result
end

GetMedia()
