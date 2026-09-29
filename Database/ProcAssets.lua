local _, addon = ...

-- Audited artwork metadata only; this is not a trigger or timer catalog.
-- Generated from the existing class ProcDefinitions for Retail 12.1.0.69933.
-- One stable key per client FileDataID. No images or external paths are shipped.
-- Each source retains its exact class/spec/Proc owner, layout, and native scale.
local sources = {
    [449486] = {
        { class = "MAGE", specID = 62, procID = "mage_arcane_soul", procName = "Arcane Soul", auraID = 451038, sourceSpellID = 451038, locationTypeName = "LeftRightOutside", scale = 1 },
    },
    [449487] = {
        { class = "DEATHKNIGHT", specID = 250, procID = "deathknight_blood_dance_midnight", procName = "Dance of Midnight", auraID = 1264568, sourceSpellID = 1264568, locationTypeName = "Top", scale = 1 },
        { class = "HUNTER", specID = 253, procID = "hunter_253_deathblow", procName = "Deathblow", auraID = 378770, sourceSpellID = 378770, locationTypeName = "Bottom", scale = 1 },
        { class = "HUNTER", specID = 254, procID = "hunter_254_deathblow", procName = "Deathblow", auraID = 378770, sourceSpellID = 378770, locationTypeName = "Bottom", scale = 1 },
    },
    [449489] = {
        { class = "MAGE", specID = 64, procID = "mage_frost_fingers_left", procName = "Fingers of Frost", auraID = 44544, sourceSpellID = 44544, locationTypeName = "Left", scale = 1 },
        { class = "MAGE", specID = 64, procID = "mage_frost_fingers_right", procName = "Fingers of Frost", auraID = 126084, sourceSpellID = 126084, locationTypeName = "Right", scale = 1 },
    },
    [449490] = {
        { class = "MAGE", specID = 63, procID = "mage_fire_heating_up", procName = "Heating Up", auraID = 48107, sourceSpellID = 48107, locationTypeName = "LeftRight", scale = 0.5 },
        { class = "MAGE", specID = 63, procID = "mage_fire_hot_streak", procName = "Hot Streak", auraID = 48108, sourceSpellID = 48108, locationTypeName = "LeftRight", scale = 1 },
    },
    [449491] = {
        { class = "SHAMAN", specID = 262, procID = "shaman_elemental_lava_surge", procName = "Lava Surge", auraID = 77762, sourceSpellID = 77762, locationTypeName = "LeftRight", scale = 1 },
        { class = "SHAMAN", specID = 264, procID = "shaman_restoration_lava_surge", procName = "Lava Surge", auraID = 77762, sourceSpellID = 77762, locationTypeName = "LeftRight", scale = 1 },
    },
    [449492] = {
        { class = "WARLOCK", specID = 265, procID = "warlock_affliction_nightfall", procName = "Nightfall", auraID = 264571, sourceSpellID = 264571, locationTypeName = "LeftRight", scale = 1 },
    },
    [449493] = {
        { class = "ROGUE", specID = 259, procID = "rogue_assassination_blindside", procName = "Blindside", auraID = 121153, sourceSpellID = 121153, locationTypeName = "LeftRight", scale = 1 },
    },
    [450913] = {
        { class = "PALADIN", specID = 70, procID = "paladin_retribution_art_war", procName = "Art of War", auraID = 406086, sourceSpellID = 406086, locationTypeName = "Left", scale = 1 },
        { class = "PALADIN", specID = 70, procID = "paladin_retribution_righteous_cause", procName = "Righteous Cause", auraID = 402916, sourceSpellID = 402916, locationTypeName = "Left", scale = 1 },
    },
    [450914] = {
        { class = "DRUID", specID = 104, procID = "druid_guardian_galactic_guardian", procName = "Galactic Guardian", auraID = 213708, sourceSpellID = 213708, locationTypeName = "Left", scale = 1 },
    },
    [450926] = {
        { class = "HUNTER", specID = 254, procID = "hunter_254_lock_and_load", procName = "Lock and Load", auraID = 194594, sourceSpellID = 194594, locationTypeName = "Top", scale = 1 },
        { class = "ROGUE", specID = 260, procID = "rogue_outlaw_opportunity", procName = "Opportunity", auraID = 195627, sourceSpellID = 195627, locationTypeName = "Top", scale = 1 },
    },
    [450929] = {
        { class = "DRUID", specID = 105, procID = "druid_restoration_clearcasting", procName = "Clearcasting", auraID = 16870, sourceSpellID = 16870, locationTypeName = "LeftRight", scale = 0.75 },
    },
    [450930] = {
        { class = "DEATHKNIGHT", specID = 251, procID = "deathknight_frost_rime", procName = "Rime", auraID = 59052, sourceSpellID = 59052, locationTypeName = "Top", scale = 1 },
        { class = "DEMONHUNTER", specID = 581, procID = "demonhunter_581_untethered_rage", procName = "Untethered Rage", auraID = 1270476, sourceSpellID = 1270476, locationTypeName = "Top", scale = 1 },
        { class = "MAGE", specID = 64, procID = "mage_frost_brain_freeze", procName = "Brain Freeze", auraID = 190446, sourceSpellID = 190446, locationTypeName = "Top", scale = 1 },
    },
    [450932] = {
        { class = "DEATHKNIGHT", specID = 252, procID = "deathknight_unholy_sudden_doom", procName = "Sudden Doom", auraID = 81340, sourceSpellID = 81340, locationTypeName = "Left", scale = 1 },
        { class = "DEATHKNIGHT", specID = 252, procID = "deathknight_unholy_sudden_doom_second", procName = "Sudden Doom", auraID = 461135, sourceSpellID = 461135, locationTypeName = "Right", scale = 1 },
    },
    [450933] = {
        { class = "PRIEST", specID = 256, procID = "priest_discipline_surge_light", procName = "Surge of Light", auraID = 114255, sourceSpellID = 114255, locationTypeName = "Left", scale = 1 },
        { class = "PRIEST", specID = 256, procID = "priest_discipline_surge_light_second", procName = "Surge of Light", auraID = 128654, sourceSpellID = 128654, locationTypeName = "Right", scale = 1 },
        { class = "PRIEST", specID = 257, procID = "priest_holy_surge_light", procName = "Surge of Light", auraID = 114255, sourceSpellID = 114255, locationTypeName = "Left", scale = 1 },
        { class = "PRIEST", specID = 257, procID = "priest_holy_surge_light_second", procName = "Surge of Light", auraID = 128654, sourceSpellID = 128654, locationTypeName = "Right", scale = 1 },
        { class = "PRIEST", specID = 258, procID = "priest_shadow_surge_light", procName = "Surge of Light", auraID = 114255, sourceSpellID = 114255, locationTypeName = "Left", scale = 1 },
        { class = "PRIEST", specID = 258, procID = "priest_shadow_surge_light_second", procName = "Surge of Light", auraID = 128654, sourceSpellID = 128654, locationTypeName = "Right", scale = 1 },
    },
    [457658] = {
        { class = "MAGE", specID = 63, procID = "mage_fire_fury_sun_king", procName = "Fury of the Sun King", auraID = 383883, sourceSpellID = 383883, locationTypeName = "Top", scale = 0.7 },
        { class = "MAGE", specID = 63, procID = "mage_fire_pyroclasm", procName = "Pyroclasm", auraID = 269651, sourceSpellID = 269651, locationTypeName = "Top", scale = 0.7 },
    },
    [458740] = {
        { class = "DEATHKNIGHT", specID = 251, procID = "deathknight_frost_killing_machine", procName = "Killing Machine", auraID = 51124, sourceSpellID = 51124, locationTypeName = "Left", scale = 1 },
        { class = "DEATHKNIGHT", specID = 251, procID = "deathknight_frost_killing_machine_second", procName = "Killing Machine", auraID = 438833, sourceSpellID = 438833, locationTypeName = "Right", scale = 1 },
    },
    [459313] = {
        { class = "PALADIN", specID = 65, procID = "paladin_holy_infusion_light", procName = "Infusion of Light", auraID = 54149, sourceSpellID = 54149, locationTypeName = "Left", scale = 1 },
        { class = "PALADIN", specID = 65, procID = "paladin_holy_infusion_light_second", procName = "Infusion of Light", auraID = 458213, sourceSpellID = 458213, locationTypeName = "Right", scale = 1 },
    },
    [459314] = {
        { class = "PALADIN", specID = 65, procID = "paladin_holy_divine_purpose", procName = "Divine Purpose", auraID = 223819, sourceSpellID = 223819, locationTypeName = "Top", scale = 1 },
        { class = "PALADIN", specID = 66, procID = "paladin_protection_divine_purpose", procName = "Divine Purpose", auraID = 223819, sourceSpellID = 223819, locationTypeName = "Top", scale = 1 },
        { class = "PALADIN", specID = 70, procID = "paladin_retribution_divine_purpose", procName = "Divine Purpose", auraID = 408458, sourceSpellID = 408458, locationTypeName = "Top", scale = 1 },
    },
    [463452] = {
        { class = "DRUID", specID = 102, procID = "druid_balance_owlkin_frenzy", procName = "Owlkin Frenzy", auraID = 157228, sourceSpellID = 157228, locationTypeName = "Top", scale = 1 },
    },
    [469752] = {
        { class = "MONK", specID = 268, procID = "monk_268_potential_energy", procName = "Potential Energy", auraID = 1270990, sourceSpellID = 1270990, locationTypeName = "Top", scale = 1 },
        { class = "MONK", specID = 270, procID = "monk_270_potential_energy", procName = "Potential Energy", auraID = 1270990, sourceSpellID = 1270990, locationTypeName = "Top", scale = 1 },
        { class = "PRIEST", specID = 256, procID = "priest_discipline_harsh_discipline", procName = "Harsh Discipline", auraID = 373183, sourceSpellID = 373183, locationTypeName = "Top", scale = 1 },
        { class = "PRIEST", specID = 257, procID = "priest_holy_benediction", procName = "Benediction", auraID = 1262766, sourceSpellID = 1262766, locationTypeName = "Top", scale = 1 },
    },
    [510822] = {
        { class = "DRUID", specID = 104, procID = "druid_guardian_gore", procName = "Gore", auraID = 93622, sourceSpellID = 93622, locationTypeName = "Top", scale = 1 },
    },
    [510823] = {
        { class = "DRUID", specID = 103, procID = "druid_feral_clearcasting", procName = "Clearcasting", auraID = 135700, sourceSpellID = 135700, locationTypeName = "LeftRight", scale = 1 },
    },
    [511104] = {
        { class = "DEATHKNIGHT", specID = 250, procID = "deathknight_blood_crimson_scourge", procName = "Crimson Scourge", auraID = 81141, sourceSpellID = 81141, locationTypeName = "LeftRight", scale = 1 },
    },
    [592058] = {
        { class = "DRUID", specID = 104, procID = "druid_guardian_celestial_might", procName = "Celestial Might", auraID = 1272376, sourceSpellID = 1272376, locationTypeName = "Right", scale = 1 },
        { class = "PRIEST", specID = 256, procID = "priest_discipline_power_dark_side", procName = "Power of the Dark Side", auraID = 198069, sourceSpellID = 198069, locationTypeName = "LeftRight", scale = 1 },
        { class = "PRIEST", specID = 258, procID = "priest_shadow_mind_flay_insanity", procName = "Mind Flay: Insanity", auraID = 391401, sourceSpellID = 391401, locationTypeName = "Left", scale = 1 },
    },
    [603339] = {
        { class = "WARRIOR", specID = 73, procID = "warrior_73_revenge", procName = "Revenge!", auraID = 5302, sourceSpellID = 5302, locationTypeName = "Right", scale = 0.85000002384 },
    },
    [623950] = {
        { class = "MONK", specID = 269, procID = "monk_269_strength_black_ox", procName = "Strength of the Black Ox", auraID = 443112, sourceSpellID = 443112, locationTypeName = "Left", scale = 1.20000004768 },
        { class = "MONK", specID = 270, procID = "monk_270_strength_black_ox", procName = "Strength of the Black Ox", auraID = 443112, sourceSpellID = 443112, locationTypeName = "Left", scale = 1.20000004768 },
    },
    [623951] = {
        { class = "MONK", specID = 270, procID = "monk_270_zen_pulse", procName = "Zen Pulse", auraID = 446334, sourceSpellID = 446334, locationTypeName = "Right", scale = 1.10000002384 },
    },
    [627609] = {
        { class = "PRIEST", specID = 258, procID = "priest_shadow_shadowy_insight", procName = "Shadowy Insight", auraID = 375981, sourceSpellID = 375981, locationTypeName = "Top", scale = 1 },
    },
    [656728] = {
        { class = "ROGUE", specID = 261, procID = "rogue_subtlety_ancient_arts", procName = "Ancient Arts", auraID = 1269163, sourceSpellID = 1269163, locationTypeName = "LeftRight", scale = 1.29999995232 },
    },
    [774420] = {
        { class = "HUNTER", specID = 253, procID = "hunter_253_pack_leader_bear", procName = "Howl of the Pack Leader: Bear", auraID = 472325, sourceSpellID = 472325, locationTypeName = "LeftRight", scale = 1 },
        { class = "HUNTER", specID = 253, procID = "hunter_253_pack_leader_boar", procName = "Howl of the Pack Leader: Boar", auraID = 472324, sourceSpellID = 472324, locationTypeName = "LeftRight", scale = 1 },
        { class = "HUNTER", specID = 253, procID = "hunter_253_pack_leader_wyvern", procName = "Howl of the Pack Leader: Wyvern", auraID = 471878, sourceSpellID = 471878, locationTypeName = "LeftRight", scale = 1 },
        { class = "HUNTER", specID = 255, procID = "hunter_255_pack_leader_bear", procName = "Howl of the Pack Leader: Bear", auraID = 472325, sourceSpellID = 472325, locationTypeName = "LeftRight", scale = 1 },
        { class = "HUNTER", specID = 255, procID = "hunter_255_pack_leader_boar", procName = "Howl of the Pack Leader: Boar", auraID = 472324, sourceSpellID = 472324, locationTypeName = "LeftRight", scale = 1 },
        { class = "HUNTER", specID = 255, procID = "hunter_255_pack_leader_wyvern", procName = "Howl of the Pack Leader: Wyvern", auraID = 471878, sourceSpellID = 471878, locationTypeName = "LeftRight", scale = 1 },
    },
    [801267] = {
        { class = "DEMONHUNTER", specID = 577, procID = "demonhunter_577_chaos_theory", procName = "Chaos Theory", auraID = 390195, sourceSpellID = 390195, locationTypeName = "LeftRight", scale = 1 },
    },
    [1001511] = {
        { class = "MONK", specID = 269, procID = "monk_269_blackout_kick", procName = "Blackout Kick!", auraID = 116768, sourceSpellID = 116768, locationTypeName = "Right", scale = 1 },
    },
    [1027131] = {
        { class = "MAGE", specID = 62, procID = "mage_arcane_clearcasting", procName = "Clearcasting", auraID = 263725, sourceSpellID = 1277420, locationTypeName = "LeftRight", scale = 1 },
    },
    [1027132] = {
        { class = "MAGE", specID = 62, procID = "mage_arcane_clearcasting", procName = "Clearcasting", auraID = 263725, sourceSpellID = 1277421, locationTypeName = "LeftRight", scale = 1 },
    },
    [1027133] = {
        { class = "MAGE", specID = 62, procID = "mage_arcane_clearcasting", procName = "Clearcasting", auraID = 263725, sourceSpellID = 1277422, locationTypeName = "LeftRight", scale = 1 },
    },
    [1029138] = {
        { class = "HUNTER", specID = 254, procID = "hunter_254_precise_shots", procName = "Precise Shots", auraID = 260242, sourceSpellID = 270436, locationTypeName = "LeftRight", scale = 1 },
    },
    [1029139] = {
        { class = "HUNTER", specID = 254, procID = "hunter_254_precise_shots", procName = "Precise Shots", auraID = 260242, sourceSpellID = 270437, locationTypeName = "LeftRight", scale = 1 },
    },
    [2851788] = {
        { class = "SHAMAN", specID = 264, procID = "shaman_restoration_high_tide", procName = "High Tide", auraID = 288675, sourceSpellID = 288675, locationTypeName = "Top", scale = 0.80000001192 },
    },
    [2888300] = {
        { class = "WARLOCK", specID = 266, procID = "warlock_demonology_demonic_core", procName = "Demonic Core", auraID = 264173, sourceSpellID = 264173, locationTypeName = "LeftRight", scale = 1 },
    },
    [4699056] = {
        { class = "EVOKER", specID = 1467, procID = "evoker_devastation_essence_burst", procName = "Essence Burst", auraID = 359618, sourceSpellID = 359618, locationTypeName = "Left", scale = 1 },
        { class = "EVOKER", specID = 1468, procID = "evoker_preservation_essence_burst", procName = "Essence Burst", auraID = 369299, sourceSpellID = 369299, locationTypeName = "Left", scale = 1 },
        { class = "EVOKER", specID = 1473, procID = "evoker_augmentation_essence_burst", procName = "Essence Burst", auraID = 392268, sourceSpellID = 392268, locationTypeName = "Left", scale = 1 },
    },
    [4699057] = {
        { class = "EVOKER", specID = 1468, procID = "evoker_preservation_lifespark", procName = "Lifespark", auraID = 394552, sourceSpellID = 394552, locationTypeName = "Top", scale = 1 },
    },
    [6160020] = {
        { class = "MAGE", specID = 62, procID = "mage_arcane_overpowered_missiles", procName = "Overpowered Missiles", auraID = 1277009, sourceSpellID = 1277009, locationTypeName = "Top", scale = 1 },
    },
    [6160021] = {
        { class = "MAGE", specID = 63, procID = "mage_fire_hyperthermia", procName = "Hyperthermia", auraID = 383874, sourceSpellID = 383874, locationTypeName = "LeftRightOutside", scale = 1.5 },
    },
    [7549806] = {
        { class = "DEMONHUNTER", specID = 1480, procID = "demonhunter_1480_moment_of_craving", procName = "Moment of Craving", auraID = 1238495, sourceSpellID = 1238495, locationTypeName = "Top", scale = 1 },
    },
}

local long, short = 256 * .8, 128 * .8
-- Canonical presentation is an explicit catalog policy, not an intrinsic
-- FileDataID property. Shape and orientation come only from the layout;
-- recommended scale is the largest audited source scale for the asset.
-- Preserve every native source and location variant for provenance. The
-- fixed order resolves assets used with different locations or aspect ratios
-- without depending on declaration order, class names, or Proc names.
local locationOrder = { "Left", "Right", "LeftOutside", "RightOutside",
    "LeftRight", "LeftRightOutside", "Top", "Bottom", "TopBottom",
    "Center", "TopLeft", "TopRight" }
local locationPriority = {}
for priority, location in ipairs(locationOrder) do locationPriority[location] = priority end

local function Geometry(location)
    local width, height = long, short
    local aspect = "horizontal"
    if location == "Left" or location == "Right" or location == "LeftRight"
        or location == "LeftOutside" or location == "RightOutside" or location == "LeftRightOutside" then
        width, height, aspect = short, long, "vertical"
    elseif location == "Center" then width, height, aspect = long, long, "square"
    elseif location == "TopLeft" or location == "TopRight" then width, height, aspect = short, short, "square" end
    return { width = width, height = height,
        flipH = location == "Right" or location == "RightOutside", flipV = location == "Bottom" }, aspect
end

local function SourceBefore(a, b)
    for _, field in ipairs({ "class", "specID", "procID", "sourceSpellID", "auraID", "locationTypeName", "scale", "procName" }) do
        if a[field] ~= b[field] then return a[field] < b[field] end
    end
    return false
end

-- Pure metadata construction. Only the audited static table above is
-- registered; building metadata never adds an asset or a trigger capability.
function addon:BuildProcAssetMetadata(textureID, references)
    local ordered, byLocation, variants, recommendedScale = {}, {}, {}, 0
    for _, reference in ipairs(references) do
        local source = {}
        for key, value in pairs(reference) do source[key] = value end
        ordered[#ordered + 1] = source
        local location = source.locationTypeName
        assert(locationPriority[location], "Unsupported audited asset location")
        local variant = byLocation[location]
        if not variant then
            local geometry, aspect = Geometry(location)
            variant = { locationTypeName = location, aspect = aspect, geometry = geometry, scales = {} }
            byLocation[location], variants[#variants + 1] = variant, variant
        end
        variant.scales[source.scale] = true
        recommendedScale = math.max(recommendedScale, source.scale)
    end
    table.sort(ordered, SourceBefore)
    table.sort(variants, function(a, b)
        return locationPriority[a.locationTypeName] < locationPriority[b.locationTypeName]
    end)
    for _, variant in ipairs(variants) do
        local scales = {}
        for scale in pairs(variant.scales) do scales[#scales + 1] = scale end
        table.sort(scales)
        variant.scales = scales
    end
    local canonical, source = assert(variants[1])
    -- This representative supplies gallery labels and provenance only; it
    -- never determines geometry or recommended scale. Display a real source
    -- of the chosen location, with stable ordering to break source-label ties.
    for _, candidate in ipairs(ordered) do
        if candidate.locationTypeName == canonical.locationTypeName then source = candidate; break end
    end
    assert(source, "Canonical asset variant requires an audited source")
    return { key = "blizzard_" .. textureID, textureID = textureID,
        label = source.procName, class = source.class, specID = source.specID,
        procID = source.procID, procName = source.procName, auraID = source.auraID,
        sourceSpellID = source.sourceSpellID, locationTypeName = canonical.locationTypeName,
        canonicalVariant = canonical.locationTypeName, recommendedScale = recommendedScale,
        geometry = canonical.geometry, variants = variants, sources = ordered }
end

addon.procAssets, addon.procAssetList, addon.procAssetsByTexture = {}, {}, {}
for textureID, references in pairs(sources) do
    local asset = addon:BuildProcAssetMetadata(textureID, references)
    addon.procAssets[asset.key], addon.procAssetsByTexture[textureID] = asset, asset
    addon.procAssetList[#addon.procAssetList + 1] = asset
end
table.sort(addon.procAssetList, function(a, b)
    if a.label == b.label then return a.key < b.key end
    return a.label < b.label
end)

function addon:GetProcAsset(key)
    if issecretvalue and issecretvalue(key) then return end
    if type(key) == "string" then return self.procAssets[key] end
end
function addon:GetProcAssetByTexture(textureID)
    if issecretvalue and issecretvalue(textureID) then return end
    if type(textureID) == "number" then return self.procAssetsByTexture[textureID] end
end
function addon:GetProcAssets() return self.procAssetList end
