local _, addon = ...

-- Options-only art direction, not reminder colors or SavedVariables defaults.
-- Faction accents (Alliance blue / Horde red) and Arcane purple are specified.
-- Fire/Frost secondary colors are
-- this release's design proposals; all share a restrained, dark visual style.
addon.optionThemes = {
    neutral = {
        label = "Neutral fallback", motif = "none",
        background = { 0.040, 0.047, 0.058 },
        left = { 0.16, 0.20, 0.25 }, right = { 0.23, 0.25, 0.31 },
        accent = { 0.55, 0.62, 0.71 },
    },
    mage = {
        label = "Mage fallback", motif = "none",
        background = { 0.036, 0.046, 0.059 },
        left = { 0.13, 0.22, 0.29 }, right = { 0.22, 0.25, 0.38 },
        accent = { 0.49, 0.72, 0.85 },
    },
    alliance_arcane = {
        label = "Alliance / Arcane", motif = "arcane",
        background = { 0.035, 0.032, 0.050 },
        left = { 0.08, 0.22, 0.48 }, right = { 0.36, 0.13, 0.58 },
        accent = { 0.72, 0.46, 0.98 },
    },
    alliance_fire = {
        label = "Alliance / Fire", motif = "fire",
        background = { 0.050, 0.035, 0.033 },
        left = { 0.08, 0.20, 0.40 }, right = { 0.55, 0.27, 0.08 },
        accent = { 1.00, 0.64, 0.28 },
    },
    alliance_frost = {
        label = "Alliance / Frost", motif = "frost",
        background = { 0.030, 0.044, 0.059 },
        left = { 0.10, 0.19, 0.38 }, right = { 0.13, 0.37, 0.47 },
        accent = { 0.48, 0.83, 1.00 },
    },
    horde_arcane = {
        label = "Horde / Arcane", motif = "arcane",
        background = { 0.046, 0.031, 0.045 },
        left = { 0.35, 0.08, 0.16 }, right = { 0.36, 0.13, 0.58 },
        accent = { 0.90, 0.44, 0.79 },
    },
    horde_fire = {
        label = "Horde / Fire", motif = "fire",
        background = { 0.050, 0.032, 0.028 },
        left = { 0.46, 0.08, 0.06 }, right = { 0.50, 0.20, 0.08 },
        accent = { 1.00, 0.48, 0.27 },
    },
    horde_frost = {
        label = "Horde / Frost", motif = "frost",
        background = { 0.033, 0.036, 0.054 },
        left = { 0.38, 0.07, 0.10 }, right = { 0.10, 0.30, 0.43 },
        accent = { 0.55, 0.73, 0.94 },
    },
}

addon.optionThemeSpecs = {
    [62] = { key = "arcane", label = "Arcane" },
    [63] = { key = "fire", label = "Fire" },
    [64] = { key = "frost", label = "Frost" },
}

addon.optionThemeClassNames = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid",
    EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", WARRIOR = "Warrior",
}

-- Tiny static WHITE8X8 texture strokes: {x, y, length, rotation in degrees}.
-- They suggest a sigil, rising flame or frost crystal without new art assets.
addon.optionThemeMotifs = {
    arcane = {
        { -12, 12, 34, 45 }, { 12, 12, 34, -45 },
        { -12, -12, 34, -45 }, { 12, -12, 34, 45 },
        { -6, 6, 17, 45 }, { 6, 6, 17, -45 },
        { -6, -6, 17, -45 }, { 6, -6, 17, 45 },
    },
    fire = {
        { -11, -6, 28, 62 }, { 7, -6, 28, -58 },
        { -4, 11, 19, 62 }, { 4, 11, 19, -62 },
        { -5, -14, 16, 70 }, { 5, -14, 16, -70 },
    },
    frost = {
        { 0, 0, 48, 90 }, { 0, 0, 48, 30 }, { 0, 0, 48, -30 },
        { -5, 16, 12, -35 }, { 5, 16, 12, 35 },
        { -5, -16, 12, 35 }, { 5, -16, 12, -35 },
    },
}

addon.optionThemeOpacity = { header = 0.45, selection = 0.38, motif = 0.07, border = 0.40, line = 0.32 }
