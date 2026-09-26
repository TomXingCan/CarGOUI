local _, addon = ...

addon.defaults = {
    schemaVersion = 3,
    enabled = true,
    mobility = { enabled = true },
    position = { x = 0, y = 0 },
    font = {
        face = "Fonts\\FRIZQT__.ttf",
        size = 24,
        outline = "OUTLINE",
    },
    scale = 1,
    shadow = { enabled = true },
    options = { position = { x = 0, y = 0 }, animatedTitle = true },
    reminders = {},
}

-- Per-region offsets share the same database and validation pipeline as other settings.
for _, entry in ipairs(addon.previewEntries) do
    addon.defaults.reminders[entry.id] = { position = { x = 0, y = 0 } }
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

function addon:IsSupportedFont(face)
    if type(face) ~= "string" then
        return false
    end
    for _, font in ipairs(self.fonts) do
        if string.lower(face) == string.lower(font.value) then
            return true, font.value
        end
    end
    return false
end

-- Localized clients can expose an additional font suitable for their alphabet.
if type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= ""
    and not addon:IsSupportedFont(STANDARD_TEXT_FONT) then
    addon.fonts[#addon.fonts + 1] = { value = STANDARD_TEXT_FONT, label = "Client default" }
end

function addon:IsNumberInRange(value, range)
    -- These comparisons also reject NaN and either infinity.
    return type(value) == "number" and value >= range.min and value <= range.max
end
