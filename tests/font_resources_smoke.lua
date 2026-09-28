-- Execute the shipped font resolver and actual LibSharedMedia registry.
-- Synthetic Font loading proves resource handling, not native glyph coverage.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local sharedPath = "Interface\\AddOns\\SharedMedia_Test\\Expressway.ttf"

local function media(env)
    local library = assert(env.LibStub("LibSharedMedia-3.0"), "embedded LibSharedMedia executes")
    truthy(type(library.Register) == "function" and type(library.Fetch) == "function", "real registry API exists")
    return library
end

local function choice(addon, value)
    for _, item in ipairs(addon:GetReminderFontOptions()) do
        if item.value == value then return item end
    end
end

local function pathKey(value) return value:lower():gsub("/", "\\") end

local function liveSetup()
    local env, addon, state = h.mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
          cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true },
        { proc = {} })
    h.putAura(state, 48108, 19, 1, true)
    h.putAura(state, 375240, 17, 1, true)
    return env, addon, state
end

local function nativeSnapshot(addon, state)
    local result = { reads = copy(state.spellReads), auraReads = state.auraReads,
        timers = state.timers, frames = #state.frames, slots = #state.auraSlots,
        bindings = #state.bindings, callbacks = addon:GetEventDiagnostics().callbacks, wrappers = {} }
    for _, pool in pairs(addon.reminderFrames or {}) do for _, frame in pairs(pool) do
        result.wrappers[frame] = { alpha = frame.alpha, alphaWrites = frame.alphaWrites,
            handle = frame.auraHandle, binding = frame.durationBinding,
            duration = frame.durationBinding and frame.durationBinding.duration,
            durationWrites = frame.durationBinding and frame.durationBinding.durationWrites,
            nativeBinding = frame.auraHandle and frame.auraHandle.container.nativeBinding }
    end end
    return result
end

local function nativeUnchanged(addon, state, before)
    same(state.spellReads, before.reads, "font refresh never queries spells")
    equal(state.auraReads, before.auraReads, "font refresh never queries auras")
    equal(state.timers, before.timers, "font refresh schedules no polling or timer")
    equal(#state.frames, before.frames, "font refresh never rebuilds frames")
    equal(#state.auraSlots, before.slots, "font refresh never rebuilds aura slots")
    equal(#state.bindings, before.bindings, "font refresh never rebuilds duration bindings")
    equal(addon:GetEventDiagnostics().callbacks, before.callbacks, "font refresh retains subscriptions")
    for frame, prior in pairs(before.wrappers) do
        equal(frame.alpha, prior.alpha, "opaque alpha is untouched")
        equal(frame.alphaWrites, prior.alphaWrites, "no native alpha writes")
        equal(frame.auraHandle, prior.handle, "owned aura provider survives")
        equal(frame.durationBinding, prior.binding, "owned duration binding survives")
        if frame.durationBinding then
            equal(frame.durationBinding.duration, prior.duration, "duration identity survives")
            equal(frame.durationBinding.durationWrites, prior.durationWrites, "no duration rebind")
        end
        if frame.auraHandle then
            equal(frame.auraHandle.container.nativeBinding, prior.nativeBinding, "native timer binding survives")
        end
    end
    for _, frame in ipairs(state.frames) do
        equal(frame:GetScript("OnUpdate"), nil, "no permanent font polling")
    end
    equal(addon.ClassToolsRawCapture, nil, "font resources do not activate research")
    equal(#state.errors, 0, "no native access tripwires were reached")
end

test("FONT existing 1.0.0 paths stay valid and canonical without changing schema", function()
    local env, addon = h.login()
    for _, path in ipairs({ "Fonts\\FRIZQT__.ttf", "Fonts\\ARIALN.TTF", "Fonts\\MORPHEUS.TTF", "Fonts\\skurri.ttf",
            "Fonts\\ARKai_T.ttf", "Fonts\\blei00d.TTF", "Fonts\\FRIZQT___CYR.TTF", "Fonts\\2002.TTF" }) do
        local valid, canonical = addon:IsSupportedFont(path:lower())
        truthy(valid, "existing shipped path stays recognized")
        equal(pathKey(canonical), pathKey(path), "legacy path is canonically equivalent")
    end
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "fonts\\morpheus.ttf" } }))
    equal(pathKey(addon:ResolveReminderFont(addon:GetMobilityConfig().style.font.face)), "fonts\\morpheus.ttf")
    local saved = copy(addon.db)
    local _, reloaded = h.login(copy(saved))
    same(reloaded.db, saved, "old built-in font does not reset any saved settings")
    equal(reloaded.db.schemaVersion, 5, "resource identity is backward-compatible within schema 5")
    equal(env.STANDARD_TEXT_FONT, "Fonts\\FRIZQT__.ttf", "global client font remains unchanged")
end)

test("FONT actual LibSharedMedia registrations appear and resolve by stable logical identity", function()
    local env, addon = h.login()
    local library = media(env)
    truthy(library:Register("font", "Expressway", sharedPath))
    local item = assert(choice(addon, "LSM:Expressway"), "shared registration appears in picker choices")
    truthy(item.label:find("Expressway", 1, true), "friendly registry name is displayed")
    equal(item.label:find("Interface", 1, true), nil, "picker does not expose filesystem paths")
    equal(addon:ResolveReminderFont(item.value), library:Fetch("font", "Expressway", true))
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = item.value } }))
    equal(addon:GetMobilityConfig().style.font.face, "LSM:Expressway", "physical path is never persisted")
    local status = addon:GetReminderFontStatus("LSM:Expressway")
    equal(status.selectedFace, "LSM:Expressway"); equal(status.effectiveFace, sharedPath)
    equal(status.fallbackReason, nil, "registered loadable face is available")
end)

test("FONT exact registry identities ignore unrelated global overrides and unknown assets", function()
    local absent = "interface\\addons\\sharedmedia_test\\absent.ttf"
    local env, addon = h.login(nil, false, { unknownAssets = { [absent] = true } })
    local library = media(env)
    truthy(library:Register("font", "Exact face", sharedPath))
    truthy(library:Register("font", "Global face", "Interface\\AddOns\\SharedMedia_Test\\Global.ttf"))
    equal(library:Register("font", "Absent file", absent), false, "real LSM refuses an unknown file")
    equal(choice(addon, "LSM:Absent file"), nil, "unknown files never become picker entries")
    truthy(library:SetGlobal("font", "Global face"))
    truthy(library:Fetch("font", "Exact face", true) ~= sharedPath, "fixture exercises actual upstream override semantics")
    equal(addon:ResolveReminderFont("LSM:Exact face"), sharedPath, "explicit preference retains its exact registry identity")
    equal(addon:GetReminderFontStatus("LSM:Missing face").fallbackReason, "missing-media", "global override cannot disguise a missing identity")
    equal(addon:ResolveReminderFont("LSM:Missing face"), env.STANDARD_TEXT_FONT)
end)

test("FONT unavailable registered files fall back and font callbacks invalidate negative probes", function()
    local unavailable = { [sharedPath:lower()] = true }
    local env, addon, state = h.login(nil, false, { unavailableFonts = unavailable, fontSetReturnsNil = true })
    local library = media(env)
    truthy(library:Register("font", "Temporarily unavailable", sharedPath))
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Temporarily unavailable" } }))
    equal(addon:GetReminderFontStatus("LSM:Temporarily unavailable").fallbackReason, "unavailable")
    equal(addon:ResolveReminderFont("LSM:Temporarily unavailable"), env.STANDARD_TEXT_FONT)
    equal(choice(addon, "LSM:Temporarily unavailable"), nil, "failed local font load is not advertised as usable")
    local fontWrites = state.fontWrites
    truthy(library:Register("sound", "Unrelated sound", "Interface\\AddOns\\SharedMedia_Test\\sound.ogg"))
    equal(state.fontWrites, fontWrites, "non-font registry callbacks do no typography work")
    unavailable[sharedPath:lower()] = nil
    truthy(library:Register("font", "New media pack font", "Interface\\AddOns\\SharedMedia_Test\\New.ttf"))
    equal(addon:GetReminderFontStatus("LSM:Temporarily unavailable").fallbackReason, nil)
    equal(addon:ResolveReminderFont("LSM:Temporarily unavailable"), sharedPath, "font registration permits a previously failed file to be retried")
    equal(addon:GetMobilityConfig().style.font.face, "LSM:Temporarily unavailable", "negative availability never destroys identity")
    local brokenEnv, broken = h.login(nil, false, { unavailableFonts = { ["fonts\\frizqt__.ttf"] = true } })
    local brokenStatus = broken:GetReminderFontStatus("LSM:Missing on broken client")
    equal(brokenStatus.effectiveFace, brokenEnv.STANDARD_TEXT_FONT, "fallback remains the trusted client resource")
    equal(brokenStatus.effectiveAvailable, false, "failed fallback loading is not reported as available")
    equal(brokenStatus.fallbackReason, "missing-media", "the missing selected identity remains distinct from fallback availability")
end)

test("FONT locale registry filtering and unique effective picker faces cover global clients", function()
    local cases = {
        { "enUS" }, { "enGB" }, { "deDE" }, { "frFR" }, { "esES" }, { "esMX" }, { "itIT" }, { "ptBR" },
        { "ruRU", "Fonts\\FRIZQT___CYR.TTF", "ruRU" }, { "zhCN", "Fonts\\ARKai_T.ttf", "zhCN" },
        { "zhTW", "Fonts\\blei00d.TTF", "zhTW" }, { "koKR", "Fonts\\2002.TTF", "koKR" },
    }
    for _, case in ipairs(cases) do
        local env, addon = h.login(nil, false, { locale = case[1], standardFont = case[2] })
        local library = media(env)
        local western = library:Register("font", "Western fixture", sharedPath, library.LOCALE_BIT_western)
        if case[3] then
            equal(western, false, case[1] .. " upstream registry excludes Western-only media")
            equal(choice(addon, "LSM:Western fixture"), nil, "excluded registry font cannot be offered")
            local mask = assert(library["LOCALE_BIT_" .. case[3]], "actual library exposes locale mask")
            truthy(library:Register("font", "Locale fixture", sharedPath, mask))
            truthy(choice(addon, "LSM:Locale fixture"), "locale-compatible registry entry is offered")
            equal(choice(addon, "Fonts\\FRIZQT__.ttf"), nil, "Roman fallback is not a misleading extra choice")
        else
            truthy(western, case[1] .. " retains Western-compatible registry entries")
            truthy(choice(addon, "LSM:Western fixture"))
        end
        library:Register("font", "Duplicate client fixture", env.STANDARD_TEXT_FONT,
            case[3] and library["LOCALE_BIT_" .. case[3]] or library.LOCALE_BIT_western)
        local seen, foundDefault = {}, false
        for _, item in ipairs(addon:GetReminderFontOptions()) do
            local status = addon:GetReminderFontStatus(item.value)
            equal(status.fallbackReason, nil, "every offered font is an available effective choice")
            local key = pathKey(status.effectiveFace)
            truthy(not seen[key], case[1] .. " picker has no duplicate effective paths")
            seen[key] = true
            if key == pathKey(env.STANDARD_TEXT_FONT) then foundDefault = true end
        end
        truthy(foundDefault, case[1] .. " safe client default remains selectable")
    end
end)

test("FONT missing shared preference survives fallback reload and later real registration", function()
    local env, addon = h.login(nil, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Absent Expressway" } }))
    local before = copy(addon.db)
    local status = addon:GetReminderFontStatus("LSM:Absent Expressway")
    equal(status.selectedFace, "LSM:Absent Expressway")
    truthy(status.selectedLabel:find("Absent Expressway", 1, true))
    equal(status.effectiveFace, env.STANDARD_TEXT_FONT)
    equal(status.fallbackReason, "missing-media")
    same(addon.db, before, "resolving fallback is read-only")
    local nextEnv, nextAddon = h.login(copy(before), false, { locale = "zhTW", standardFont = "Fonts\\blei00d.TTF" })
    equal(nextAddon:GetMobilityConfig().style.font.face, "LSM:Absent Expressway")
    equal(nextAddon:ResolveReminderFont("LSM:Absent Expressway"), nextEnv.STANDARD_TEXT_FONT)
    local library = media(nextEnv)
    truthy(library:Register("font", "Absent Expressway", sharedPath, library.LOCALE_BIT_zhTW))
    equal(nextAddon:ResolveReminderFont("LSM:Absent Expressway"), sharedPath)
    equal(nextAddon:GetMobilityConfig().style.font.face, "LSM:Absent Expressway", "late resolution retains original identity")
end)

test("FONT malformed shared names and arbitrary raw paths are rejected atomically", function()
    local env, addon = h.login()
    local before = copy(addon.db)
    local invalid = { "LSM:", "LSM: leading", "LSM:trailing ", "LSM:a\nb", "LSM:a\000b", "LSM:a|b",
        "LSM:a:b", "LSM:a/b", "LSM:a\\b", "LSM:" .. string.rep("x", 129),
        "C:\\Fonts\\Injected.ttf", "/usr/share/fonts/injected.ttf", "Interface\\AddOns\\Unknown\\Injected.ttf" }
    for _, value in ipairs(invalid) do
        equal(addon:IsSupportedFont(value), false, "unsafe font identity is not accepted")
        equal(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = value } }), false)
        equal(addon:ResolveReminderFont(value), env.STANDARD_TEXT_FONT, "invalid value renders safe client fallback")
        same(addon.db, before, "invalid resource never partially mutates saved settings")
    end
    local valid, canonical = addon:IsSupportedFont("lsm:Expressway")
    truthy(valid); equal(canonical, "LSM:Expressway", "prefix normalizes while media name identity survives")
end)

test("FONT changing preferences refreshes Proc Mobility Free move and visible Preview typography", function()
    local env, addon, state = liveSetup()
    truthy(media(env):Register("font", "Expressway", sharedPath))
    h.options(addon)
    truthy(addon:SetPreview("all"))
    local before = nativeSnapshot(addon, state)
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Expressway" } }))
    truthy(addon:UpdateReminderStyle("proc:MAGE:63", { font = { face = "LSM:Expressway" } }))
    equal(h.currentLive(addon).text.font[1], sharedPath, "live Mobility-owned text refreshes")
    equal(h.procFrame(addon, "free_move_mage").auraHandle.font.font[1], sharedPath, "Free move owned Font refreshes")
    equal(h.procFrame(addon, "mage_fire_hot_streak_left").auraHandle.font.font[1], sharedPath, "Proc owned Font refreshes")
    local previews = 0
    for _, frame in pairs(addon.previewFrames) do
        if frame:IsShown() then
            equal(frame.text.font[1], sharedPath, "visible sample text refreshes")
            previews = previews + 1
        end
    end
    truthy(previews >= 3, "the preview scenario contains multiple reminder kinds")
    nativeUnchanged(addon, state, before)
end)

test("FONT late registry callbacks update existing and pooled Fonts without native state work", function()
    local env, addon, state = liveSetup()
    h.options(addon)
    truthy(addon:SetPreview("all")); addon:StopPreview()
    addon.optionsFrame:Hide()
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Late Expressway" } }))
    truthy(addon:UpdateReminderStyle("proc:MAGE:63", { font = { face = "LSM:Late Expressway" } }))
    local saved, before = copy(addon.db), nativeSnapshot(addon, state)
    local previewFonts = {}
    for id, frame in pairs(addon.previewFrames) do previewFonts[id] = frame end
    truthy(media(env):Register("font", "Late Expressway", sharedPath))
    equal(h.currentLive(addon).text.font[1], sharedPath)
    equal(h.procFrame(addon, "free_move_mage").auraHandle.font.font[1], sharedPath)
    equal(h.procFrame(addon, "mage_fire_hot_streak_left").auraHandle.font.font[1], sharedPath)
    for id, frame in pairs(previewFonts) do
        equal(frame.text.font[1], sharedPath, "hidden pooled preview receives late resource")
        equal(addon.previewFrames[id], frame, "pooled frame identity survives")
    end
    same(addon.db, saved, "registration never rewrites preferences")
    nativeUnchanged(addon, state, before)
    h.options(addon); truthy(addon:SetPreview("all"))
    for id, frame in pairs(previewFonts) do
        equal(addon.previewFrames[id], frame, "reused preview retains its existing frame")
        equal(frame.text.font[1], sharedPath, "reused preview retains the resolved resource")
    end
end)

test("FONT valid LSM identity round-trips deterministically through an unavailable client", function()
    local env, addon = h.login()
    truthy(media(env):Register("font", "Expressway", sharedPath))
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Expressway" } }))
    truthy(addon:UpdateReminderStyle("proc:MAGE:63", { font = { face = "LSM:Expressway" } }))
    local exported = assert(addon:ExportSettings("all"))
    local packet = h.unpackSettings(env, exported)
    equal(packet.formatVersion, 1); equal(packet.schemaVersion, 5)
    equal(packet.classes.MAGE.mobility.style.font.face, "LSM:Expressway")
    equal(packet.classes.MAGE.proc["63"].style.font.face, "LSM:Expressway")
    equal(exported, assert(addon:ExportSettings("all")), "same saved input has stable serialization")
    local missingEnv, missing = h.login()
    local transaction = h.prepareSettings(missing, exported)
    truthy(transaction.summary:lower():find("font", 1, true), "review discloses fallback")
    truthy(missing:ConfirmSettingsImport(transaction))
    equal(missing:GetMobilityConfig().style.font.face, "LSM:Expressway")
    equal(missing:GetProcConfig(63).style.font.face, "LSM:Expressway")
    equal(missing:ResolveReminderFont("LSM:Expressway"), missingEnv.STANDARD_TEXT_FONT)
    equal(assert(missing:ExportSettings("all")), exported, "missing local resource does not change the portable packet")
    for _, invalid in ipairs({ "LSM:", "LSM:a/b", "LSM:a|b", "Interface\\AddOns\\Unsafe\\font.ttf" }) do
        local changed = copy(packet); changed.classes.MAGE.mobility.style.font.face = invalid
        local before = copy(missing.db)
        equal(missing:PrepareSettingsImport(h.packSettings(missingEnv, changed)), nil, "malformed font import is refused before confirmation")
        same(missing.db, before, "invalid import cannot mutate the database")
    end
end)

test("FONT unavailable saved selection has distinct selected and effective UI status", function()
    local env, addon = h.login()
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Missing Expressway" } }))
    local _, controls = h.options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    local status = assert(controls.appearanceFontStatus, "font availability status is visible in existing Appearance page")
    local text = status:GetText()
    truthy(text:find("Missing Expressway", 1, true), "selected preference stays visible")
    truthy(text:lower():find("unavailable", 1, true), "fallback is explicitly disclosed")
    truthy(text:lower():find("client default", 1, true), "effective local font is named separately")
    equal(text:find("Interface\\", 1, true), nil, "status does not leak raw physical paths")
    equal(addon:GetMobilityConfig().style.font.face, "LSM:Missing Expressway", "opening Options does not replace missing preference")
    truthy(media(env):Register("font", "Missing Expressway", sharedPath))
    equal(status:GetText():lower():find("unavailable", 1, true), nil, "visible status refreshes when the registered resource arrives")
    truthy(status:GetText():find("Missing Expressway", 1, true), "selected identity remains visible after resolution")
    local _, broken = h.login(nil, false, { unavailableFonts = { ["fonts\\frizqt__.ttf"] = true } })
    truthy(broken:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:Also unavailable" } }))
    local _, brokenControls = h.options(broken)
    broken:OpenAppearance("mobility", "mobility:MAGE")
    truthy(brokenControls.appearanceFontStatus:GetText():find(
        "Neither the requested font nor the local default font is available.", 1, true),
        "UI explicitly discloses an unavailable client fallback instead of promising usable rendering")
end)

test("FONT full 128-byte names remain readable in button and menu tooltips without stealing ownership", function()
    local env, addon = h.login()
    local name = string.rep("LongName", 16)
    equal(#name, 128, "fixture exercises the full accepted media-name length")
    truthy(media(env):Register("font", name, sharedPath))
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "LSM:" .. name } }))
    local panel, controls = h.options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    local dropdown, tooltip = controls.appearanceFont, env.GameTooltip
    dropdown:GetScript("OnEnter")(dropdown)
    truthy(tooltip:IsShown()); equal(tooltip:GetOwner(), dropdown)
    truthy(tooltip.textValue:find(name, 1, true), "button tooltip preserves every byte of the selected name")
    truthy(tooltip.textValue:find("Using:", 1, true), "button tooltip includes effective rendering status")
    dropdown:GetScript("OnLeave")(dropdown)
    equal(tooltip:IsShown(), false, "leaving the font button hides its owned tooltip")
    dropdown:Click()
    local target
    for page = 1, dropdown.pageCount do
        dropdown:SetPage(page)
        for _, button in ipairs(dropdown.choices) do
            if button.value == "LSM:" .. name then target = button; break end
        end
        if target then break end
    end
    truthy(target, "long-name menu entry remains reachable")
    target:GetScript("OnEnter")(target)
    equal(tooltip:GetOwner(), target); truthy(tooltip:IsShown())
    truthy(tooltip.textValue:find(name, 1, true), "menu tooltip preserves the complete friendly name")
    target:GetScript("OnLeave")(target)
    equal(tooltip:IsShown(), false, "leaving the menu entry hides its owned tooltip")
    target:GetScript("OnEnter")(target); target:Hide()
    equal(tooltip:IsShown(), false, "hiding a reused menu row releases its tooltip")
    dropdown:GetScript("OnEnter")(dropdown)
    local foreignOwner = env.CreateFrame("Frame", nil, env.UIParent)
    tooltip:SetOwner(foreignOwner, "ANCHOR_RIGHT"); tooltip:Show()
    dropdown:GetScript("OnLeave")(dropdown)
    truthy(tooltip:IsShown(), "a stale font leave event cannot hide a foreign owner's tooltip")
    equal(tooltip:GetOwner(), foreignOwner)
    panel:Hide()
end)

test("FONT large shared registries stay selectable through bounded reusable picker pages", function()
    local env, addon, state = h.login()
    local library = media(env)
    for index = 1, 41 do
        truthy(library:Register("font", string.format("Paging %02d", index),
            string.format("Interface\\AddOns\\SharedMedia_Test\\Paging%02d.ttf", index)))
    end
    local _, controls = h.options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    local dropdown = controls.appearanceFont
    truthy(dropdown.pageCount >= 6, "registry size requires multiple pages")
    dropdown:Click()
    local frameCount, seen, count = #state.frames, {}, 0
    for page = 1, dropdown.pageCount do
        dropdown:SetPage(page)
        truthy(dropdown.menu:GetHeight() <= 8 * addon.DesignSystem.controlHeight + 48, "font popup height stays bounded")
        truthy(#dropdown.choices <= 8, "one bounded set of row buttons is reused")
        equal(dropdown.previousPage:IsEnabled(), page > 1)
        equal(dropdown.nextPage:IsEnabled(), page < dropdown.pageCount)
        for _, button in ipairs(dropdown.choices) do
            if button.value and button:IsShown() then
                truthy(not seen[button.value], "no duplicate logical entry across pages")
                seen[button.value] = true
                if button.value:find("LSM:Paging ", 1, true) then count = count + 1 end
            end
        end
    end
    equal(count, 41, "every shared registration remains reachable")
    equal(#state.frames, frameCount, "paging allocates no additional row frames")
    for _, button in ipairs(dropdown.choices) do
        if button.value == "LSM:Paging 41" then button:Click(); break end
    end
    equal(addon:GetMobilityConfig().style.font.face, "LSM:Paging 41", "last page selection writes the intended stable identity")
    equal(dropdown.menu.cuiState, "closing", "selection starts the owned close transition")
    equal(dropdown.menu.cuiInteractive, false, "outgoing font rows cannot receive input")
    dropdown.menu.closeAnimation:GetScript("OnFinished")()
    equal(dropdown.menu:IsShown(), false, "selection closes the font picker")
    equal(#state.errors, 0)
end)
