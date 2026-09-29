-- Real shipped localization/render code, synthetic client metadata only.
-- This does not certify native glyph rendering or WoW combat execution.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local locales = { "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU" }

local function dictionaries()
    local result = {}
    local registry = { RegisterLocale = function(_, locale, strings) result[locale] = strings end }
    for _, locale in ipairs(locales) do
        registry.locale = locale
        assert(loadfile(h.root .. "/Locales/" .. locale .. ".lua"))("CarGOUI", registry)
    end
    return result
end

local function placeholders(text)
    local result = {}
    -- Escaped percentages are text. No private timer placeholders are translated.
    text = text:gsub("%%%%", "")
    for token in text:gmatch("%%[-+ #0]*%d*%.?%d*[cdeEfgGiouXxqs]") do
        result[#result + 1] = token:sub(-1)
    end
    return table.concat(result, ",")
end

local function localizedSetup(locale, names, client, saved)
    client = client or {}; client.locale = locale
    local env, addon, state = h.setup(saved, false, client)
    local reads, requests, info = {}, {}, {}
    names = names or {}
    env.C_Spell.GetSpellName = function(id)
        truthy(not env.issecretvalue(id), "metadata ID must be public")
        reads[id] = (reads[id] or 0) + 1
        return names[id]
    end
    env.C_Spell.GetSpellInfo = function(id) return info[id] end
    env.C_Spell.RequestLoadSpellData = function(id) requests[id] = (requests[id] or 0) + 1 end
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    equal(#state.errors, 0, "localized setup errors")
    return env, addon, state, names, reads, requests, info
end

test("1.0 localization dictionaries cover English keys and preserve public format placeholders", function()
    local all = dictionaries()
    local keys = 0
    for key, source in pairs(all.enUS) do
        equal(type(source), "string"); keys = keys + 1
        for _, locale in ipairs(locales) do
            equal(type(all[locale][key]), "string", locale .. " contains " .. key)
            equal(placeholders(all[locale][key]), placeholders(source), locale .. " format types for " .. key)
        end
    end
    truthy(keys > 0)
    for _, locale in ipairs(locales) do
        for key in pairs(all[locale]) do truthy(all.enUS[key] ~= nil, locale .. " has no orphan key: " .. key) end
    end
end)

test("1.0 client locale chooses eight dictionaries aliases and a safe English fallback", function()
    local all = dictionaries()
    for _, case in ipairs({ { "enUS", "enUS" }, { "enGB", "enUS" }, { "zhCN", "zhCN" },
        { "zhTW", "zhTW" }, { "deDE", "deDE" }, { "frFR", "frFR" }, { "esES", "esES" },
        { "esMX", "esES" }, { "itIT", "itIT" }, { "ruRU", "ruRU" }, { "koKR", "enUS" },
        { "xxXX", "enUS" } }) do
        local _, addon = h.setup(nil, false, { locale = case[1] })
        equal(addon.clientLocale, case[1], "raw client locale retained for rendering")
        equal(addon.locale, case[2], "canonical dictionary locale")
        equal(addon:Text("General"), all[case[2]].General)
        equal(addon:Text("UNREGISTERED SAFE TEXT"), "UNREGISTERED SAFE TEXT")
        equal(addon:Format("No %s", "SPELL"), string.format(all[case[2]]["No %s"], "SPELL"))
    end
    local _, addon = h.setup(nil, false, { locale = "zhCN" })
    addon:RegisterLocale("zhCN", { ["one test key"] = "value" })
    equal(addon:Text("General"), all.enUS.General, "missing overlay key falls back to English")
end)

test("1.0 inactive locale files return before registering their dictionary tables", function()
    for _, selected in ipairs(locales) do
        local calls = {}
        local registry = { locale = selected, RegisterLocale = function(_, locale, strings)
            truthy(type(strings) == "table", "only active file supplies its dictionary")
            calls[#calls + 1] = locale
        end }
        for _, fileLocale in ipairs(locales) do
            assert(loadfile(h.root .. "/Locales/" .. fileLocale .. ".lua"))("CarGOUI", registry)
        end
        if selected == "enUS" then same(calls, { "enUS" }, "English loads just its base dictionary")
        else same(calls, { "enUS", selected }, "only English plus the selected overlay is instantiated") end
    end
end)

test("1.0 localized client does not persist language or rename configuration scope identifiers", function()
    local _, english = h.login()
    local before = copy(english.db)
    local _, chinese = h.login(copy(before), false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    same(chinese.db, before, "existing saved styles coordinates colors and class/spec keys are unchanged")
    equal(chinese.db.locale, nil); equal(chinese.db.options.locale, nil)
    equal(chinese.db.classes.MAGE ~= nil, true, "class token remains MAGE")
    equal(chinese:GetMobilityEntry().id, english:GetMobilityEntry().id, "stable entry identity remains unchanged")
end)

test("1.0 spell names use public current metadata and actual Proc aura IDs", function()
    local env, addon, state, names, reads, requests, info = localizedSetup("zhCN", {
        [1953] = "闪现术", [263725] = "节能施法", [374968] = "时间螺旋" })
    equal(addon:GetLocalizedSpellName(1953, "Blink"), "闪现术")
    equal(addon:GetLocalizedSpellName(1953, "Blink"), "闪现术")
    equal(reads[1953], 1, "cached names do not repeat API calls")
    equal(addon:FormatMobilityLabel(1953, "Blink"), addon:Format("No %s", "闪现术"))
    local label = addon:GetEntryDisplayLabel({ kind = "proc", auraID = 263725, sourceSpellID = 1277420,
        label = "Clearcasting - left region" })
    equal(label, addon:Format("%s - %s", "节能施法", addon:Text("left region")))
    equal(reads[1277420], nil, "dummy overlay not queried as a display buff")
    info[999001] = { name = "备用名称" }
    equal(addon:GetLocalizedSpellName(999001, "Fallback"), "备用名称", "GetSpellInfo name fallback")
    equal(requests[999001], nil)
    env.UnitClass = function() return "法师", "MAGE", 8 end
    env.C_SpecializationInfo.GetSpecializationInfo = function() return state.specID, "火焰" end
    equal(addon:GetLocalizedClassName(), "法师"); equal(addon:GetLocalizedSpecName(state.specID), "火焰")
end)

test("1.0 missing or opaque spell metadata gets bounded requests without exposing private values", function()
    local env, addon, state, names, reads, requests, info = localizedSetup("enUS")
    names[1953] = h.secret("private"); info[1953] = h.secret({ name = "private" })
    equal(addon:GetLocalizedSpellName(1953, "Blink"), "Blink")
    equal(addon:GetLocalizedSpellName(1953, "Blink"), "Blink")
    equal(reads[1953], 1); equal(requests[1953], 1)
    equal(addon:GetLocalizedSpellName(h.secret(1953), "Safe"), "Safe", "opaque ID never queried")
    equal(addon:GetLocalizedSpellName(0, "Safe"), "Safe")
    equal(addon:GetLocalizedSpellName(999, h.secret("private fallback")), "Unknown spell")
    local otherCalls = 0
    local other = function() otherCalls = otherCalls + 1 end
    addon:RegisterEvent("SPELL_DATA_LOAD_RESULT", other)
    equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, 2, "one own callback plus unrelated listener")
    names[1953] = "Blink loaded"
    state:fire("SPELL_DATA_LOAD_RESULT", 1953, true)
    equal(addon:GetLocalizedSpellName(1953, "Blink"), "Blink loaded")
    state:fire("SPELL_DATA_LOAD_RESULT", 999, false)
    equal(addon:GetLocalizedSpellName(999, "Fallback"), "Fallback", "failed load keeps static fallback")
    equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, 1, "only own listener removed")
    equal(otherCalls, 2); equal(#state.errors, 0)
    equal(state:activeTimers(), 0, "metadata does not poll")
end)

test("1.0 synchronous name completion is safe and context changes bound cache growth", function()
    local env, addon, state, names, reads, requests = localizedSetup("enUS")
    local refreshes, refresh = 0, addon.RefreshLocalizedLabels
    addon.RefreshLocalizedLabels = function(self, id) refreshes = refreshes + 1; return refresh(self, id) end
    env.C_Spell.RequestLoadSpellData = function(id)
        requests[id] = (requests[id] or 0) + 1
        names[id] = "Synchronous name"
        state:fire("SPELL_DATA_LOAD_RESULT", id, true)
    end
    equal(addon:GetLocalizedSpellName(888001, "Fallback"), "Synchronous name")
    equal(refreshes, 0, "synchronous result returns directly and never reenters Options refresh")
    equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, nil, "synchronous listener removed")
    env.C_Spell.RequestLoadSpellData = function(id) requests[id] = (requests[id] or 0) + 1 end
    addon:GetLocalizedSpellName(888002, "Pending")
    local previous = addon.localizedNameCache
    state.specID = 64
    addon:GetLocalizedSpellName(888003, "Current")
    truthy(addon.localizedNameCache ~= previous, "new scope gets fresh presentation cache")
    names[888002] = "Old scope"
    state:fire("SPELL_DATA_LOAD_RESULT", 888002, true)
    equal(addon.localizedNameCache.names[888002], nil, "late old result never enters current cache")
    state:fire("SPELL_DATA_LOAD_RESULT", 888003, false)
    equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, nil)
    for id = 900001, 900200 do addon:GetLocalizedSpellName(id, "Fallback") end
    equal(addon.localizedNameCache.count, 128, "cache cap is enforced")
    equal(requests[900200], nil, "overflow cannot create requests")
    equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, 1, "many pending IDs share one callback")
    state.specID = 62
    equal(addon:GetLocalizedSpellName(888001, "Fallback"), "Synchronous name")
    equal(addon.localizedNameCache.count, 1); equal(addon:GetEventDiagnostics().perEvent.SPELL_DATA_LOAD_RESULT, nil)
end)

test("1.0 reminder font fallback preserves saved user choices and native nil success", function()
    for _, case in ipairs({ { "zhCN", "Fonts\\ARKai_T.ttf" }, { "zhTW", "Fonts\\blei00d.TTF" },
        { "ruRU", "Fonts\\FRIZQT___CYR.TTF" }, { "koKR", "Fonts\\2002.TTF" } }) do
        local env, addon = h.login(nil, false, { locale = case[1], standardFont = case[2] })
        local style = copy(addon.factoryReminderStyle)
        style.font.face = "Fonts\\FRIZQT__.ttf"
        local original = copy(style)
        local frame = env.CreateFrame("Frame", nil, env.UIParent)
        local text = frame:CreateFontString(nil, "OVERLAY")
        addon:ApplyFontSettings(text, style, addon:GetMobilityEntry())
        equal(text.font[1], case[2]); same(style, original, "effective fallback never rewrites saved choice")
        equal(env.STANDARD_TEXT_FONT, case[2], "client global font is unchanged")
        equal(addon:IsSupportedFont("Interface\\AddOns\\Custom\\font.ttf"), false, "unregistered raw font paths cannot be saved")
        equal(addon:ResolveReminderFont("Interface\\AddOns\\Custom\\font.ttf"), case[2], "invalid raw paths render through safe client fallback")
    end
    local env, addon = h.login(nil, false, { fontSetReturnsNil = true, proc = {} })
    local style = copy(addon.factoryReminderStyle); style.font.face = "Fonts\\MORPHEUS.ttf"
    local frame = env.CreateFrame("Frame", nil, env.UIParent)
    local text = frame:CreateFontString(nil, "OVERLAY")
    addon:ApplyFontSettings(text, style, addon:GetMobilityEntry())
    equal(text.font[1]:lower(), style.font.face:lower(), "nil SetFont success keeps the same available font with canonical path spelling")
    local missingEnv, missingAddon = h.login(nil, false, { proc = {}, unavailableFonts = { ["fonts\\blei00d.ttf"] = true } })
    local savedStyle = copy(missingAddon.factoryReminderStyle); savedStyle.font.face = "Fonts\\blei00d.TTF"
    local before = copy(savedStyle)
    local fallbackText = missingEnv.CreateFrame("Frame", nil, missingEnv.UIParent):CreateFontString(nil, "OVERLAY")
    missingAddon:ApplyFontSettings(fallbackText, savedStyle, missingAddon:GetMobilityEntry())
    equal(fallbackText.font[1], missingEnv.STANDARD_TEXT_FONT, "unavailable imported client font renders with local fallback")
    same(savedStyle, before, "cross-client render fallback retains imported preference")
end)

test("1.0 late localized live Mobility prefix preserves native timing opaque alpha and saved geometry", function()
    local env, addon, state, names = localizedSetup("zhCN", {}, { standardFont = "Fonts\\ARKai_T.ttf", mobility = {
        known = { [1953] = true, [212653] = true }, override = 212653,
        spells = { [212653] = { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
            cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true } } } })
    local frame = assert(addon.reminderFrames.live[addon:GetMobilityEntry().id])
    local binding = frame.durationBinding
    local duration, writes, alpha, alphaWrites = binding.duration, binding.durationWrites, frame.alpha, frame.alphaWrites
    local saved, reads = copy(addon.db), copy(state.spellReads)
    truthy(env.issecretvalue(alpha), "visibility result is independently opaque")
    names[212653] = "闪光术"
    state:fire("SPELL_DATA_LOAD_RESULT", 212653, true)
    equal(binding.format, addon:Format("No %s", "闪光术") .. "\n{}")
    equal(binding.duration, duration); equal(binding.durationWrites, writes)
    equal(frame.alpha, alpha); equal(frame.alphaWrites, alphaWrites)
    same(addon.db, saved); same(state.spellReads, reads, "metadata does not trigger gameplay queries")
    state:advance(2)
    equal(frame.text.nativeRenderedText, addon:Format("No %s", "闪光术") .. "\n13.0")
    equal(state.liveMeasurements, 0, "restricted native text never enters string measurement")
    equal(#state.errors, 0)
end)

test("1.0 Preview labels localize without changing public samples stable regions or native Free move", function()
    local env, addon, state = localizedSetup("zhCN", { [212653] = "闪光术", [263725] = "节能施法" },
        { specID = 62, standardFont = "Fonts\\ARKai_T.ttf", proc = {} })
    local sample = { kind = "mobility", id = "test", spellID = 212653, spellName = "Shimmer", sample = { timer = "8.0" } }
    local before = copy(sample)
    local content = addon:GetLocalizedPreviewContent(sample)
    equal(content.message, addon:Format("No %s", "闪光术")); equal(content.timer, "8.0")
    same(sample, before, "presentation leaves definition and sample tables unchanged")
    local proc = { kind = "proc", sample = { timer = "8.0" } }
    equal(addon:GetLocalizedPreviewContent(proc), proc.sample, "Proc remains numbers only")
    local free = { kind = "mobility", freeMove = true, sample = {} }
    equal(addon:GetLocalizedPreviewContent(free).message, addon:Text("Free move"))
    h.putAura(state, 375240, 10, 1, true)
    local native = assert(addon.reminderFrames.nativeAura.free_move_mage)
    equal(native.auraHandle.textOnly, addon:Text("Free move"), "localized static label belongs to native slot")
    equal(#state.errors, 0)
end)

test("1.0 every locale exercises all Options pages status launcher tooltip and import summary", function()
    for _, locale in ipairs(locales) do
        local env, addon, state = h.login(nil, false, { locale = locale, proc = {} })
        local classes = {}; for key in pairs(addon.db.classes) do classes[key] = true end
        local panel = h.options(addon)
        for key, page in pairs(panel.pages) do
            addon:SelectOptionsCategory(key)
            truthy(page:IsShown(), locale .. " page is accessible: " .. key)
        end
        addon:SelectOptionsCategory("general")
        truthy(addon:SetPreview("all"), locale .. " samples start")
        addon:StopPreview()
        local before = #state.messages
        env.SlashCmdList.CARGOUI("status")
        truthy(#state.messages > before, locale .. " read-only status emits a message")
        local broker = env.LibStub("LibDataBroker-1.1"):GetDataObjectByName("CarGOUI")
        local lines = {}
        broker.OnTooltipShow({ AddLine = function(_, line) lines[#lines + 1] = line end })
        same(lines, { "CarGOUI", addon.version, addon:Text("Left-click: Open / close Options.") })
        local exported = assert(addon:ExportSettings("all"))
        local review = h.prepareSettings(addon, exported)
        truthy(review.summary:find(addon:Text("Import validated settings?"), 1, true), locale .. " localized import summary")
        addon:CancelSettingsImport()
        for key in pairs(addon.db.classes) do truthy(classes[key], "translation does not allocate unrelated class: " .. key) end
        equal(#state.errors, 0, locale .. " UI/tooltip/summary/status runs without errors")
    end
end)

test("1.0 full configuration crosses all interface languages without translating schema or values", function()
    local sourceEnv, source = h.transferSeed()
    truthy(source:UpdateSettings({ options = { minimap = { hide = true, minimapPos = 143 } } }))
    local text = assert(source:ExportSettings("all"))
    local packet = h.unpackSettings(sourceEnv, text)
    for _, locale in ipairs(locales) do
        local env, addon, state = h.login(nil, false, { locale = locale, specID = 62, proc = {} })
        truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, text)), locale .. " accepts original schema")
        local after = h.unpackSettings(env, assert(addon:ExportSettings("all")))
        same(after, packet, locale .. " complete roundtrip keeps stable IDs font tokens RGB independent XY and minimap")
        equal(addon.db.classes.MAGE.mobility.freeMovePosition.x, -240)
        equal(addon.db.classes.MAGE.mobility.position.x, 130)
        equal(addon.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_left.color.g, 0.7)
        equal(addon.db.options.minimap.minimapPos, 143); equal(addon.db.options.minimap.hide, true)
        local classCount = 0; for _ in pairs(addon.db.classes) do classCount = classCount + 1 end
        equal(classCount, 2, "only imported Mage/Warrior records exist")
        local _, reloaded = h.login(copy(addon.db), false, { locale = "enUS", specID = 62, proc = {} })
        same(reloaded.db.classes, addon.db.classes, "English reload preserves cross-client saved font choices")
        equal(#state.errors, 0)
    end
end)
