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
    equal(asset.width, addon:GetProcAsset(value.assetKey).geometry.width)
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
