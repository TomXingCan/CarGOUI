local _, addon = ...

addon.defaults = {
    schemaVersion = 1,
    enabled = true,
    position = { x = 0, y = 0 },
    font = {
        face = "Fonts\\FRIZQT__.ttf",
        size = 24,
        outline = "OUTLINE",
    },
    scale = 1,
    shadow = { enabled = true },
}

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

function addon:IsNumberInRange(value, range)
    -- These comparisons also reject NaN and either infinity.
    return type(value) == "number" and value >= range.min and value <= range.max
end
