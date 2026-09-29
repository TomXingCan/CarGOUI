-- Execute the shipped data/resolver/database/codec path with actual Lua 5.1.
-- Metadata provenance checks use existing definitions, never synthetic auras.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function region(addon, id)
    for _, entry in ipairs(addon:GetDefinedPreviewEntries()) do
        if entry.id == (id or "mage_arcane_clearcasting_left") then return entry end
    end
    error("Missing fixture region: " .. tostring(id))
end
local function artwork(addon)
    local value = addon:NewProcAppearance()
    value.mode, value.assetKey = "custom", "blizzard_603339"
    value.artColor, value.alpha, value.desaturation = { r = .2, g = .4, b = .7 }, .65, .4
    value.scale, value.width, value.height, value.rotation = 1.6, .75, 1.3, -45
    value.mirrorX, value.mirrorY, value.offset = true, true, { x = 41, y = -37 }
    value.animation = { entrance = "pulse", active = "breathe", exit = "scale",
        speed = 1.5, intensity = .3, direction = "counterclockwise" }
    return value
end

test("PROC ART old position/color-only regions retain exact schema 5 native defaults without writes", function()
    local _, original = h.transferSeed()
    local saved = copy(original.db)
    local _, addon = h.login(copy(saved), false, { specID = 62, proc = {} })
    local entry = region(addon)
    same(addon.db, saved, "old settings stay byte-equivalent as Lua values")
    local value = addon:GetProcRegionAppearance(entry)
    equal(value.mode, "native")
    same(addon.db, saved, "default read does not persist appearance")
    equal(addon:GetProcConfig().regions[entry.id].appearance, nil)
    value.offset.x, value.animation.active = 100, "pulse"
    equal(addon:GetProcRegionAppearance(entry).offset.x, 0, "defaults are detached")
    equal(addon.db.schemaVersion, 5)
end)

test("PROC ART catalog is exactly the audited source artwork union with no duplicate FileDataID", function()
    local _, addon = h.transferSeed()
    local classPaths = { DEATHKNIGHT = "DeathKnight", DEMONHUNTER = "DemonHunter", DRUID = "Druid",
        EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk", PALADIN = "Paladin",
        PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior" }
    local data = { adapters = {}, factories = {} }
    function data:ProcDefinition(value) return value end
    function data:RegisterProcFactory(class, factory) self.factories[class] = factory end
    local moduleRoot = h.root .. "/Modules/CarGOUI_Data"
    local probe = io.open(moduleRoot .. "/CarGOUI_Data.toc", "r")
    if probe then probe:close() else moduleRoot = h.root .. "/../CarGOUI_Data" end
    for class, path in pairs(classPaths) do
        data.adapters[class] = {}
        assert(loadfile(moduleRoot .. "/Classes/" .. path .. "/ProcDefinitions.lua"))("CarGOUI_Data", data)
    end
    local expected, references, actual, unique = {}, 0, {}, {}
    local function sourceKey(class, spec, proc, aura, overlay, texture, location, scale)
        return table.concat({ class, spec, proc, aura, overlay, texture, location, scale }, ":")
    end
    for class, specs in pairs(addon.settingsMetadata.classes) do
        for spec in pairs(specs) do
            local adapter = data.adapters[class]
            local definitions = data.factories[class] and data.factories[class](spec) or adapter:GetProcDefinitions(spec)
            for _, definition in ipairs(definitions) do
                for _, source in ipairs(definition.overlaySources or { definition }) do
                    expected[sourceKey(class, spec, definition.id, definition.auraID, source.overlayID,
                        source.textureID, source.locationTypeName or definition.locationTypeName, source.scale or definition.scale)] = true
                    references = references + 1
                end
            end
        end
    end
    for _, asset in ipairs(addon:GetProcAssets()) do
        truthy(not unique[asset.textureID], "one catalog tile per FileDataID")
        unique[asset.textureID] = true
        equal(addon:GetProcAsset(asset.key), asset)
        equal(addon:GetProcAssetByTexture(asset.textureID), asset)
        truthy(asset.geometry.width > 0 and asset.geometry.height > 0)
        truthy(type(asset.label) == "string" and asset.label ~= tostring(asset.textureID), "friendly label")
        for _, source in ipairs(asset.sources) do
            local key = sourceKey(source.class, source.specID, source.procID, source.auraID,
                source.sourceSpellID, asset.textureID, source.locationTypeName, source.scale)
            truthy(expected[key], "every catalog source has an audited definition")
            truthy(not actual[key], "no duplicate source record")
            actual[key] = true
        end
    end
    same(actual, expected, "no missing source or extra unreviewed artwork")
    equal(#addon:GetProcAssets(), 44)
    equal(references, 77)
    equal(addon:GetProcAsset("Interface\\Icons\\Custom.blp"), nil)
    equal(addon:GetProcAsset(603339), nil)
end)

test("PROC ART shared Heating Up artwork recommends full scale while own-native remains source specific", function()
    local _, addon = h.login(nil, false, { specID = 63, proc = {} })
    local asset = addon:GetProcAsset("blizzard_449490")
    equal(asset.recommendedScale, 1, "Hot Streak scale is not reduced by Heating Up metadata order")
    same(asset.geometry, { width = 128 * .8, height = 256 * .8, flipH = false, flipV = false }, "base geometry contains no source scale")
    equal(asset.canonicalVariant, "LeftRight")
    same(asset.variants[1].scales, { .5, 1 }, "both audited source scales remain explicit")
    local entry = region(addon, "mage_fire_heating_up_left")
    equal(entry.nativeScale, .5)
    local custom = { mode = "custom", assetKey = asset.key, artColor = { r = 1, g = 1, b = 1 } }
    local _, selected = addon:ResolveProcAppearance(entry, custom, { textureID = 449490, scale = .5 })
    equal(selected.width, 128 * .8, "catalog selection uses asset recommendation even on Heating Up")
    equal(selected.height, 256 * .8)
    custom.assetKey = nil
    local _, own = addon:ResolveProcAppearance(entry, custom, { textureID = 449490, scale = .5 })
    equal(own.width, 128 * .8 * .5, "own-native keeps the current Proc source scale")
    equal(own.height, 256 * .8 * .5)
    local _, nativePreview = addon:ResolveProcAppearance(entry, { mode = "native" }, nil, true)
    equal(nativePreview.width, own.width, "Native TEST also retains source-specific artwork dimensions")
end)

test("PROC ART nonunit scales and multiple locations keep explicit deterministic catalog variants", function()
    local _, addon = h.transferSeed()
    local entry = region(addon)
    for _, row in ipairs({ { 603339, .85000002384, "Right", 128 * .8, 256 * .8 },
        { 2851788, .80000001192, "Top", 256 * .8, 128 * .8 },
        { 656728, 1.29999995232, "LeftRight", 128 * .8, 256 * .8 },
        { 6160021, 1.5, "LeftRightOutside", 128 * .8, 256 * .8 },
        { 457658, .7, "Top", 256 * .8, 128 * .8 } }) do
        local asset = addon:GetProcAssetByTexture(row[1])
        equal(asset.recommendedScale, row[2]); equal(asset.canonicalVariant, row[3])
        equal(asset.geometry.width, row[4]); equal(asset.geometry.height, row[5])
        local _, resolved = addon:ResolveProcAppearance(entry, { mode = "custom", assetKey = asset.key }, nil, true)
        equal(resolved.width, row[4] * row[2], "selected artwork applies recommendation exactly once")
        equal(resolved.height, row[5] * row[2])
    end
    for _, row in ipairs({ { 449487, "Top", "horizontal", { "Top", "Bottom" } },
        { 449489, "Left", "vertical", { "Left", "Right" } },
        { 450932, "Left", "vertical", { "Left", "Right" } },
        { 450933, "Left", "vertical", { "Left", "Right" } },
        { 458740, "Left", "vertical", { "Left", "Right" } },
        { 459313, "Left", "vertical", { "Left", "Right" } },
        { 592058, "Left", "vertical", { "Left", "Right", "LeftRight" } } }) do
        local asset, locations = addon:GetProcAssetByTexture(row[1]), {}
        equal(asset.canonicalVariant, row[2]); equal(asset.locationTypeName, row[2])
        for _, variant in ipairs(asset.variants) do
            locations[#locations + 1] = variant.locationTypeName
            equal(variant.aspect, row[3]); same(variant.scales, { 1 })
        end
        same(locations, row[4], "fixed location order is explicit")
        local representative
        for _, source in ipairs(asset.sources) do
            if source.class == asset.class and source.specID == asset.specID and source.procID == asset.procID
                and source.sourceSpellID == asset.sourceSpellID and source.locationTypeName == asset.locationTypeName then
                representative = source
            end
        end
        truthy(representative, "gallery representative actually uses the canonical location")
    end
    -- Shape-conflict policy is tested without admitting another catalog key.
    local references = {}
    for index, location in ipairs({ "Center", "TopRight", "Top", "Left" }) do
        references[index] = copy(addon:GetProcAssetByTexture(449490).sources[1])
        references[index].locationTypeName, references[index].scale = location, index * .5
    end
    local metadata = addon:BuildProcAssetMetadata(9999999, references)
    equal(metadata.canonicalVariant, "Left", "fixed location policy resolves mixed aspects")
    equal(metadata.recommendedScale, 2, "maximum audited-reference scale policy is independent of aspect")
    equal(metadata.geometry.width, 128 * .8); equal(metadata.geometry.height, 256 * .8)
    same({ metadata.variants[1].aspect, metadata.variants[2].aspect,
        metadata.variants[3].aspect, metadata.variants[4].aspect }, { "vertical", "horizontal", "square", "square" })
    equal(addon:GetProcAsset(metadata.key), nil, "metadata construction cannot expand the whitelist")
end)

test("PROC ART every catalog asset is unchanged when audited source order is reversed or rotated", function()
    local _, addon = h.transferSeed()
    for _, asset in ipairs(addon:GetProcAssets()) do
        local references = copy(asset.sources)
        local before, reversed = copy(references), {}
        for index = #references, 1, -1 do reversed[#reversed + 1] = references[index] end
        same(addon:BuildProcAssetMetadata(asset.textureID, reversed), asset, "reverse preserves canonical metadata")
        for shift = 1, #references do
            local rotated = {}
            for index = 1, #references do rotated[index] = references[(index + shift - 1) % #references + 1] end
            same(addon:BuildProcAssetMetadata(asset.textureID, rotated), asset, "all rotations preserve canonical metadata")
        end
        same(references, before, "builder leaves original provenance unchanged")
    end
end)

test("PROC ART setter validates bounded detached patches and reset preserves all timer ownership", function()
    local _, addon, state = h.transferSeed()
    local entry, config = region(addon), addon:GetProcConfig()
    local timer, style, enabled = copy(config.regions[entry.id]), copy(config.style), config.enabled
    local value, beforeReads, beforeSlots = artwork(addon), state.auraReads, #state.auraSlots
    truthy(addon:SetProcRegionAppearance(entry, value))
    value.artColor.r, value.offset.x, value.animation.active = 1, 999, "rotate"
    local saved = config.regions[entry.id].appearance
    equal(saved.artColor.r, .2); equal(saved.offset.x, 41); equal(saved.animation.active, "breathe")
    same(config.regions[entry.id].position, timer.position)
    same(config.regions[entry.id].color, timer.color)
    same(config.style, style); equal(config.enabled, enabled)
    truthy(addon:SetProcRegionAppearance(entry, { artColor = false, assetKey = false, animation = { entrance = "fade" } }))
    equal(config.regions[entry.id].appearance.artColor, nil)
    equal(config.regions[entry.id].appearance.assetKey, nil)
    equal(config.regions[entry.id].appearance.animation.active, "breathe")
    truthy(addon:ResetProcRegionAppearance(entry))
    same(config.regions[entry.id], timer, "reset changes only region.appearance")
    same(config.style, style); equal(config.enabled, enabled)
    equal(state.auraReads, beforeReads, "appearance edits query no aura")
    equal(#state.auraSlots, beforeSlots, "appearance edits create no aura provider")
end)

test("PROC ART strict validation rejects unknown assets paths fields ranges booleans and animations", function()
    local _, addon = h.transferSeed()
    local invalid = {
        { mode = "all" }, { assetKey = "unknown" }, { assetKey = 603339 },
        { assetKey = "Interface\\AddOns\\Other\\art.tga" }, { textureID = 603339 },
        { artColor = { r = 1, g = .5, b = .5, a = 1 } }, { artColor = { r = 0 / 0, g = 0, b = 1 } },
        { artColor = { r = math.huge, g = 0, b = 1 } }, { alpha = -1 }, { desaturation = 1.1 },
        { scale = 0 }, { width = 3.1 }, { height = math.huge }, { rotation = 181 },
        { mirrorX = 1 }, { mirrorY = "false" }, { offset = { anchor = "CENTER" } },
        { offset = { x = 1001 } }, { animation = { entrance = "spin" } },
        { animation = { active = "fade" } }, { animation = { exit = "pulse" } },
        { animation = { speed = 0 } }, { animation = { intensity = 1.1 } },
        { animation = { direction = "left" } }, { animation = { mode = "native" } },
        { artColor = false }, { assetKey = false }, { alpha = h.secret(.5) },
    }
    for _, value in ipairs(invalid) do equal(addon:ValidateProcAppearance(value), false, "reject malformed artwork") end
    equal(addon:ValidateProcAppearance(setmetatable({}, {})), false, "reject metatable")
    truthy(addon:ValidateProcAppearance({ artColor = false, assetKey = false }, true), "sentinels are patch-only")
    truthy(addon:ValidateProcAppearance(artwork(addon)))
    for field, range in pairs(addon.procAppearanceLimits) do
        for _, bound in ipairs({ range.min, range.max }) do
            local value = (field == "speed" or field == "intensity") and { animation = { [field] = bound } }
                or field == "offset" and { offset = { x = bound, y = bound } } or { [field] = bound }
            truthy(addon:ValidateProcAppearance(value), field .. " inclusive finite endpoint")
        end
    end
end)

test("PROC ART shared resolver isolates timer fields and supports public RGB cross-class art and native TEST", function()
    local _, addon = h.transferSeed()
    local entry = region(addon)
    local value = artwork(addon)
    local resolved, asset = addon:ResolveProcAppearance(entry, value, { r = .9, g = .8, b = .7 })
    equal(asset.textureID, 603339, "a Mage can select audited Warrior artwork")
    same(asset.color, value.artColor, "custom artwork RGB wins over public color")
    equal(asset.x, entry.anchor.x); equal(asset.y, entry.anchor.y)
    local selected = addon:GetProcAsset(value.assetKey)
    equal(asset.width, selected.geometry.width * selected.recommendedScale)
    equal(resolved.width, .75); equal(resolved.height, 1.3)
    value.artColor, value.assetKey = nil, nil
    resolved, asset = addon:ResolveProcAppearance(entry, value,
        { textureID = 1027132, r = .9, g = .8, b = .7, scale = 1.5 })
    equal(asset.textureID, 1027132, "public verified native variant stays selected")
    same(asset.color, { r = .9, g = .8, b = .7 })
    equal(asset.width, entry.guide.width * 1.5 / entry.nativeScale)
    local _, missing, reason = addon:ResolveProcAppearance(entry, value, { r = h.secret(1), g = 1, b = 1 })
    equal(missing, nil); equal(reason, "native-color-unavailable")
    value.mode = "native"
    resolved, asset = addon:ResolveProcAppearance(entry, value, nil, true)
    same(resolved, addon:NewProcAppearance(), "native ignores dormant custom transforms")
    equal(asset.textureID, entry.guide.texture)
    same(asset.color, { r = 1, g = 1, b = 1 }, "TEST simulates public native color")
    value.mode = "timer"
    local timer, noArtwork = addon:ResolveProcAppearance(entry, value, nil, true)
    equal(timer.mode, "timer"); equal(noArtwork, nil)
end)

test("PROC ART appearance export roundtrip is deterministic schema 5 format 1 and rejects malicious additions", function()
    local env, addon = h.transferSeed()
    local entry = region(addon)
    truthy(addon:SetProcRegionAppearance(entry, artwork(addon)))
    local text = assert(addon:ExportSettings("all"))
    equal(addon:ExportSettings("all"), text, "deterministic new export")
    local packet = h.unpackSettings(env, text)
    equal(packet.schemaVersion, 5); equal(packet.formatVersion, 1)
    same(packet.classes.MAGE.proc["62"].regions[entry.id].appearance, artwork(addon))
    local _, target = h.login(nil, false, { specID = 62, proc = {} })
    truthy(target:ConfirmSettingsImport(h.prepareSettings(target, text)))
    equal(target:ExportSettings("all"), text, "full artwork roundtrip")
    for _, bad in ipairs({ { assetKey = "blizzard_1" }, { assetKey = 603339 }, { filename = "evil.blp" },
        { textureID = 603339 }, { alpha = 2 }, { mirrorX = "true" }, { animation = { active = "unknown" } },
        { offset = { z = 1 } }, { artColor = { r = 1, g = 0, b = 1, a = 1 } }, { artColor = false } }) do
        local changed = copy(packet)
        changed.classes.MAGE.proc["62"].regions[entry.id].appearance = bad
        local before = copy(target.db)
        equal(target:PrepareSettingsImport(h.packSettings(env, changed)), nil, "strict artwork import whitelist")
        same(target.db, before, "invalid import is atomic")
    end
    local old = copy(packet)
    old.classes.MAGE.proc["62"].regions[entry.id].appearance = nil
    truthy(target:ConfirmSettingsImport(h.prepareSettings(target, h.packSettings(env, old))))
    equal(target:GetProcRegionAppearance(region(target)).mode, "native", "old included region clears artwork override")
    equal(target:GetProcConfig().regions[entry.id].appearance, nil, "old import stays sparse")
end)

test("PROC ART maximal all-class appearance snapshot fits bounded parser and reimports exactly", function()
    local env, addon = h.transferSeed()
    local count = 0
    for class, specs in pairs(addon.settingsMetadata.classes) do
        local classConfig = { mobility = addon:NewMobilityConfig(), proc = {} }
        addon.db.classes[class] = classConfig
        for spec, ids in pairs(specs) do
            local config = addon:NewProcConfig()
            classConfig.proc[spec] = config
            for id in pairs(ids) do
                count = count + 1
                config.regions[id] = { position = { anchor = "CENTER", x = count, y = -count },
                    color = { r = .1, g = .2, b = .3 }, appearance = artwork(addon) }
            end
        end
    end
    local text = assert(addon:ExportSettings("all"))
    truthy(#text < addon.settingsTransferLimits.inputBytes)
    local _, target = h.login(nil, false, { specID = 62, proc = {} })
    truthy(target:ConfirmSettingsImport(h.prepareSettings(target, text)))
    equal(target:ExportSettings("all"), text, "all saved full appearance records are portable")
    equal(count, 97, "existing complete audited saved region roster")
    local left = target:GetProcConfig().regions.mage_arcane_clearcasting_left
    local right = target:GetProcConfig().regions.mage_arcane_clearcasting_right
    left.appearance.animation.active, left.appearance.offset.x = "rotate", 900
    equal(right.appearance.animation.active, "breathe")
    equal(right.appearance.offset.x, 41, "distinct imported regions never alias artwork")
end)

test("PROC ART database and transfer refresh only changed current regions without restarting siblings", function()
    local env, addon, state = h.transferSeed()
    local entry, refreshed = region(addon), {}
    function addon:RefreshProcAppearance(selected)
        truthy(selected and selected.id, "targeted refresh always supplies a stable region")
        refreshed[#refreshed + 1] = selected.id
    end
    truthy(addon:SetProcRegionAppearance(entry, { mode = "custom" }))
    same(refreshed, { entry.id }, "editing one region refreshes only that region")
    refreshed = {}
    truthy(addon:ResetProcRegionAppearance(entry))
    same(refreshed, { entry.id }, "artwork reset leaves sibling animation lifecycles alone")
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    packet.classes.MAGE.proc["62"].regions[entry.id].appearance = artwork(addon)
    packet.classes.MAGE.proc["63"].regions.mage_fire_hot_streak_left.appearance = artwork(addon)
    refreshed = {}
    local loads, reads = state.moduleLoads, state.auraReads
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    same(refreshed, { entry.id }, "import refreshes changed current region, not sibling or foreign spec")
    equal(state.moduleLoads, loads, "foreign appearance import does not activate adapters")
    equal(state.auraReads, reads, "targeted import performs no aura query")
    packet.classes.MAGE.proc["63"].regions.mage_fire_hot_streak_left.appearance.alpha = .2
    refreshed = {}
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    same(refreshed, {}, "foreign-only artwork import refreshes no current region")
    equal(state.moduleLoads, loads)
end)
