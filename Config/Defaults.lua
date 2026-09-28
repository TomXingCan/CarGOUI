local _, addon = ...

addon.factoryReminderStyle = {
    font = { face = addon.defaultReminderFont, size = 24, outline = "OUTLINE" },
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

function addon:IsNumberInRange(value, range)
    -- These comparisons also reject NaN and either infinity.
    return type(value) == "number" and value >= range.min and value <= range.max
end
