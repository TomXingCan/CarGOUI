local _, addon = ...

-- Header identity is faction-only. Body identity is class/spec-only. Neither
-- palette participates in reminder styles, class colors, or SavedVariables.
addon.optionHeaderThemes = {
    alliance = { label = "Alliance blue", left = { 0.025, 0.075, 0.18 },
        right = { 0.06, 0.28, 0.52 }, accent = { 0.30, 0.66, 1.00 } },
    horde = { label = "Horde red", left = { 0.16, 0.025, 0.035 },
        right = { 0.43, 0.07, 0.085 }, accent = { 1.00, 0.34, 0.30 } },
    neutral = { label = "Neutral faction fallback", left = { 0.065, 0.075, 0.09 },
        right = { 0.14, 0.17, 0.20 }, accent = { 0.62, 0.69, 0.76 } },
}

addon.optionBodyThemes = {
    neutral = { label = "Neutral Body fallback", motif = "none",
        background = { 0.035, 0.04, 0.048 }, left = { 0.045, 0.052, 0.064 }, right = { 0.080, 0.095, 0.115 },
        accent = { 0.56, 0.65, 0.75 }, input = { 0.025, 0.032, 0.042 }, button = { 0.075, 0.092, 0.115 } },
    mage = { label = "Mage Body fallback", motif = "none",
        background = { 0.03, 0.043, 0.057 }, left = { 0.045, 0.069, 0.088 }, right = { 0.078, 0.105, 0.14 },
        accent = { 0.47, 0.70, 0.83 }, input = { 0.022, 0.036, 0.050 }, button = { 0.065, 0.105, 0.14 } },
    arcane = { label = "Arcane violet", motif = "arcane",
        background = { 0.043, 0.025, 0.067 }, left = { 0.064, 0.031, 0.11 }, right = { 0.17, 0.078, 0.245 },
        accent = { 0.73, 0.49, 0.98 }, input = { 0.035, 0.021, 0.060 }, button = { 0.12, 0.064, 0.18 } },
    fire = { label = "Fire ember / amber", motif = "fire",
        background = { 0.070, 0.027, 0.018 }, left = { 0.12, 0.034, 0.019 }, right = { 0.245, 0.13, 0.047 },
        accent = { 1.00, 0.62, 0.27 }, input = { 0.057, 0.025, 0.019 }, button = { 0.18, 0.082, 0.032 } },
    frost = { label = "Frost deep blue / cyan", motif = "frost",
        background = { 0.018, 0.039, 0.070 }, left = { 0.026, 0.062, 0.14 }, right = { 0.055, 0.18, 0.23 },
        accent = { 0.43, 0.84, 1.00 }, input = { 0.018, 0.031, 0.058 }, button = { 0.042, 0.105, 0.16 } },
}

addon.optionThemeSpecs = { [62] = { key = "arcane", label = "Arcane" },
    [63] = { key = "fire", label = "Fire" }, [64] = { key = "frost", label = "Frost" } }
addon.optionThemeClassNames = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid",
    EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", WARRIOR = "Warrior",
}
addon.optionThemeOpacity = { header = 1, selection = 0.56, motif = 0.16, border = 0.50, line = 0.34 }
addon.optionThemeText = { 0.90, 0.91, 0.94 }
addon.optionThemeWatermarkSize, addon.optionThemeMotifLimit = 200, 64

-- Original geometric outlines; no external art or game atlas is copied. Only
-- the selected shape's short segment list is generated, then discarded.
function addon:BuildOptionsThemeMotif(kind)
    local result = {}
    local function line(x1, y1, x2, y2, width)
        result[#result + 1] = { x1, y1, x2, y2, width or 2 }
    end
    local function ring(radius, count)
        for i = 1, count do
            local a, b = (i - 1) * 2 * math.pi / count, i * 2 * math.pi / count
            line(radius * math.cos(a), radius * math.sin(a), radius * math.cos(b), radius * math.sin(b))
        end
    end
    if kind == "arcane" then
        ring(88, 28); ring(64, 20)
        line(0, 48, 38, 0, 3); line(38, 0, 0, -48, 3)
        line(0, -48, -38, 0, 3); line(-38, 0, 0, 48, 3)
        for _, angle in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2 }) do
            local x, y = 76 * math.cos(angle), 76 * math.sin(angle)
            line(x - 5, y - 6, x + 5, y + 6); line(x - 5, y + 6, x + 5, y - 6)
        end
    elseif kind == "fire" then
        local outer = { {-12,94}, {16,65}, {29,39}, {22,15}, {44,34}, {68,2}, {74,-29},
            {61,-60}, {36,-81}, {0,-91}, {-36,-82}, {-61,-59}, {-70,-24}, {-60,5},
            {-37,32}, {-39,7}, {-22,24}, {-8,48}, {-12,94} }
        for i = 2, #outer do line(outer[i-1][1], outer[i-1][2], outer[i][1], outer[i][2], 3) end
        local inner = { {4,24}, {25,-6}, {30,-30}, {16,-56}, {0,-71}, {-22,-58}, {-31,-34}, {-24,-12}, {-8,-30}, {4,24} }
        for i = 2, #inner do line(inner[i-1][1], inner[i-1][2], inner[i][1], inner[i][2], 2) end
    elseif kind == "frost" then
        ring(34, 6)
        for i = 0, 5 do
            local angle = i * math.pi / 3
            local dx, dy = math.cos(angle), math.sin(angle)
            line(0, 0, 92 * dx, 92 * dy, 3)
            for _, distance in ipairs({ 48, 70 }) do
                local x, y = distance * dx, distance * dy
                line(x, y, x - 17 * dx - 14 * dy, y - 17 * dy + 14 * dx)
                line(x, y, x - 17 * dx + 14 * dy, y - 17 * dy - 14 * dx)
            end
        end
    end
    return result
end
