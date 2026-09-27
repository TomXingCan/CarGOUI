local _, addon = ...
local defaultFace = "Fonts\\FRIZQT__.ttf"
if (addon.clientLocale == "zhCN" or addon.clientLocale == "zhTW" or addon.clientLocale == "ruRU"
    or addon.clientLocale == "koKR") and type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "" then
    defaultFace = STANDARD_TEXT_FONT
end

addon.factoryReminderStyle = {
    font = { face = defaultFace, size = 24, outline = "OUTLINE" },
    scale = 1,
    shadow = { enabled = true },
}

-- Every call returns fresh nested tables: no entry inherits a mutable style.
function addon:NewReminderStyle()
    local style = self.factoryReminderStyle
    return {
        font = { face = style.font.face, size = style.font.size, outline = style.font.outline },
        scale = style.scale,
        shadow = { enabled = style.shadow.enabled },
    }
end

addon.defaults = {
    schemaVersion = 5,
    options = { position = { x = 0, y = 0 }, animatedTitle = true,
        minimap = { hide = false, minimapPos = 220 } },
    classes = {},
}

function addon:NewReminderPosition()
    return { anchor = "CENTER", x = 0, y = 0 }
end

function addon:NewMobilityConfig()
    return { enabled = true, style = self:NewReminderStyle(),
        position = self:NewReminderPosition(), freeMovePosition = self:NewReminderPosition(), preferences = {} }
end

function addon:NewProcConfig()
    return { enabled = true, style = self:NewReminderStyle(), regions = {} }
end

addon.limits = {
    offset = { min = -10000, max = 10000 },
    fontSize = { min = 8, max = 72 },
    scale = { min = 0.5, max = 3 },
}

addon.outlines = {
    [""] = true,
    OUTLINE = true,
    THICKOUTLINE = true,
}

-- These fonts are provided by the game client; no external media library is needed.
addon.fonts = {
    { value = "Fonts\\FRIZQT__.ttf", label = "Friz Quadrata" },
    { value = "Fonts\\ARIALN.TTF", label = "Arial Narrow" },
    { value = "Fonts\\MORPHEUS.TTF", label = "Morpheus" },
    { value = "Fonts\\skurri.ttf", label = "Skurri" },
}

-- Saved resource identifiers remain valid across client languages. This small
-- whitelist is independent of the local font menu and never loads font files.
addon.clientFontPaths = { "Fonts\\ARKai_T.ttf", "Fonts\\blei00d.TTF",
    "Fonts\\FRIZQT___CYR.TTF", "Fonts\\2002.TTF" }

function addon:IsSupportedFont(face)
    if type(face) ~= "string" then
        return false
    end
    for _, font in ipairs(self.fonts) do
        if string.lower(face) == string.lower(font.value) then
            return true, font.value
        end
    end
    for _, path in ipairs(self.clientFontPaths) do
        if string.lower(face) == string.lower(path) then return true, path end
    end
    return false
end

-- Localized clients can expose an additional font suitable for their alphabet.
if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= ""
    and string.lower(STANDARD_TEXT_FONT) ~= "fonts\\frizqt__.ttf" then
    addon.fonts[#addon.fonts + 1] = { value = STANDARD_TEXT_FONT, label = addon:Text("Client default") }
end

function addon:IsNumberInRange(value, range)
    -- These comparisons also reject NaN and either infinity.
    return type(value) == "number" and value >= range.min and value <= range.max
end
