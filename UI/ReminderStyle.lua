local _, addon = ...

local fallback = { r = 1, g = 1, b = 1 }

local function IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsColorComponent(value)
    return IsPublic(value) and type(value) == "number"
        and value == value and value >= 0 and value <= 1
end

local romanFonts = {
    ["fonts\\frizqt__.ttf"] = true, ["fonts\\arialn.ttf"] = true,
    ["fonts\\morpheus.ttf"] = true, ["fonts\\skurri.ttf"] = true,
}
local wideLocales = { zhCN = true, zhTW = true, ruRU = true, koKR = true }
local fontProbe, fontAvailability = nil, {}

local function FontAvailable(face)
    if not IsPublic(face) or type(face) ~= "string" then return false end
    if not CreateFont then return true end
    local key = face:lower():gsub("/", "\\")
    if fontAvailability[key] ~= nil then return fontAvailability[key] end
    fontProbe = fontProbe or CreateFont("CarGOUIReminderFontProbe")
    -- This scratch Font contains no timer text or aura state. SetFont can return
    -- nil on success; inspect only this public resource's resulting face path.
    local ok, result = pcall(fontProbe.SetFont, fontProbe, face, 12, "")
    local actual = ok and result ~= false and fontProbe:GetFont()
    local available = IsPublic(actual) and type(actual) == "string"
        and actual:lower():gsub("/", "\\") == key
    fontAvailability[key] = available
    return available
end

-- A successful SetFont only confirms that the file loaded, not that it covers
-- the client alphabet. Use Blizzard's own locale font for the offered Roman
-- faces on these clients; preserve the user's stored face and all style values.
function addon:ResolveReminderFont(face)
    if wideLocales[self.clientLocale] and IsPublic(face) and type(face) == "string"
        and romanFonts[face:lower()] and IsPublic(STANDARD_TEXT_FONT)
        and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
        return STANDARD_TEXT_FONT
    end
    -- Imports retain the user's recognized font even when that file is absent
    -- from this client installation. Only the effective rendering face changes.
    if self:IsSupportedFont(face) and not FontAvailable(face) then
        return STANDARD_TEXT_FONT or self.factoryReminderStyle.font.face
    end
    return face
end

local function ResolveClassColor(self, refresh)
    local classToken
    if UnitClass then
        local _, token = UnitClass("player")
        classToken = token
    end
    if not IsPublic(classToken) or type(classToken) ~= "string" or classToken == "" then
        self.reminderClassColor = nil
        return fallback, false
    end

    local cached = self.reminderClassColor
    if not refresh and cached and cached.classToken == classToken then
        return cached, true
    end

    -- The cache belongs to this session, never to account-wide SavedVariables.
    -- An early unavailable API/color is retried on the next styling request.
    self.reminderClassColor = nil
    local color = C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(classToken)
    if IsPublic(color) and (type(color) == "table" or type(color) == "userdata")
        and type(color.GetRGB) == "function" then
        local r, g, b = color:GetRGB()
        if IsColorComponent(r) and IsColorComponent(g) and IsColorComponent(b) then
            cached = { classToken = classToken, r = r, g = g, b = b }
            self.reminderClassColor = cached
            return cached, true
        end
    end
    return fallback, false
end

local function SameRegion(left, right)
    return left and right and left.kind == "proc" and right.kind == "proc"
        and left.class == right.class and left.specID == right.specID and left.id == right.id
end

-- Proc typography is shared by spec; RGB belongs to the stable region. This
-- resolver uses only addon configuration/temporary picker state, never an aura.
function addon:ResolveReminderColor(entry)
    if entry and entry.kind == "proc" and self:GetCurrentProcRegion(entry) then
        local draft = self.procRegionColorPreview
        if SameRegion(draft, entry) then return { r = draft.color.r, g = draft.color.g, b = draft.color.b }, true end
        local custom = self:GetProcRegionColor(entry)
        if custom then return custom, true end
    end
    local color, available = ResolveClassColor(self, false)
    return { r = color.r, g = color.g, b = color.b }, available
end

-- For live Aura slots, text is our Font object, not the restricted FontString.
-- No formatted native text, alpha, geometry or binding is read or changed here.
function addon:ApplyReminderColor(text, entry)
    local color, available = self:ResolveReminderColor(entry)
    text:SetTextColor(color.r, color.g, color.b, 1)
    return available
end

function addon:RefreshProcRegionColor(entry, restoredColor)
    for _, pool in pairs(self.reminderFrames or {}) do
        local frame = pool[entry.id]
        if frame and frame.text and SameRegion(frame.reminderEntry, entry) then
            if restoredColor then
                frame.text:SetTextColor(restoredColor.r, restoredColor.g, restoredColor.b, 1)
            else self:ApplyReminderColor(frame.text, entry) end
        end
    end
end

function addon:SetProcRegionColorPreview(entry, color)
    local draft = self.procRegionColorPreview
    if color == nil then
        if SameRegion(draft, entry) then
            self.procRegionColorPreview = nil
            -- A context switch must clean the old owned Font without reading
            -- another spec's configuration or writing either spec's database.
            local restored = not self:GetCurrentProcRegion(entry) and draft.originalColor or nil
            self:RefreshProcRegionColor(entry, restored)
        end
        if self.RefreshProcColorControls then self:RefreshProcColorControls() end
        return true
    end
    if not self:GetCurrentProcRegion(entry) or not self:IsValidProcRegionColor(color) then
        return false, self:Text("Choose a current Proc region and finite RGB values from 0 to 1.")
    end
    if draft and not SameRegion(draft, entry) then
        self:SetProcRegionColorPreview(draft, nil)
        draft = nil
    end
    local original = draft and draft.originalColor or self:ResolveReminderColor(entry)
    self.procRegionColorPreview = { kind = "proc", class = entry.class, specID = entry.specID,
        id = entry.id, color = { r = color.r, g = color.g, b = color.b }, originalColor = original }
    self:RefreshProcRegionColor(entry)
    if self.RefreshProcColorControls then self:RefreshProcColorControls() end
    return true
end

-- Login/world-entry refresh also repairs already-created and hidden pool frames.
-- TEST guidance, Options labels and the brand title are outside this pool style.
function addon:RefreshReminderClassColor()
    local _, available = ResolveClassColor(self, true)
    for _, pool in pairs(self.reminderFrames or {}) do
        for _, frame in pairs(pool) do
            -- Inactive spec frames are styled when reused. Do not replace an
            -- inactive region's custom RGB with a different character's color.
            local entry = frame.reminderEntry
            if frame.text and (not entry or entry.kind ~= "proc" or self:GetCurrentProcRegion(entry)) then
                self:ApplyReminderColor(frame.text, entry)
            end
        end
    end
    return available
end
