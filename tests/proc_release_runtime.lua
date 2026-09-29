-- Production defaults only. Historical takeover suites opt in separately.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local left, right = "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right"

local function Entry(addon, id)
    return assert(addon:GetCurrentProcRegion({ kind = "proc", id = id or left, class = "MAGE", specID = 62 }))
end

local function Start(saved, muted)
    local env, addon, state = h.productionSetup(saved, false, { specID = 62, proc = { cvars = {
        displaySpellActivationOverlays = not muted, spellActivationOverlayOpacity = muted and "0" or "1" } } })
    local function Forbidden() error("production native policy accessed artwork takeover or CVar writer") end
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end }, { __index = Forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = Forbidden, Forbidden, Forbidden
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    equal(addon:IsProcLegacyReplacementAllowed(), false)
    equal(#state.errors, 0)
    return env, addon, state
end

local function NoTakeover(addon, state)
    equal(next(addon.procSuppressedOverlays or {}), nil)
    equal(next(addon.procNativeOverlays or {}), nil)
    local snapshot = addon:GetProcDiagnosticSnapshot()
    equal(snapshot.api.SuppressNativeAlpha.requested, 0)
    equal(snapshot.api.RestoreNativeAlpha.requested, 0)
    equal(addon.procArtworkHookRoot, nil)
    equal(addon:GetProcSafetyDiagnostics().failures, 0); equal(#state.errors, 0)
end

test("Release fresh login defaults to native artwork and native-bound timers without artwork hooks", function()
    local env, addon, state = Start()
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(addon:GetProcConfig().presentationPolicy, nil)
    h.putAura(state, 263725, 20, 1, true)
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    equal(h.procText(addon, state, left), "20.0"); equal(h.procText(addon, state, right), "20.0")
    equal(addon.procArtworkFrames, nil)
    NoTakeover(addon, state)
end)

test("Release legacy Custom and Timer Only saves remain intact across login ApplySettings and Preview", function()
    local _, seed = h.transferSeed()
    truthy(seed:SetProcRegionAppearance(Entry(seed), { mode = "custom", assetKey = "blizzard_4699056",
        alpha = .3, artColor = { r = .1, g = .4, b = .8 }, rotation = 45 }))
    truthy(seed:SetProcRegionAppearance(Entry(seed, right), { mode = "timer", scale = 1.8 }))
    local saved = copy(seed.db)
    local env, addon, state = Start(copy(saved))
    local before = assert(addon:ExportSettings("all"))
    for _ = 1, 4 do
        addon:ApplySettings(); addon:ConfigureProc()
        state:fire("PLAYER_ENTERING_WORLD"); state:fire("PLAYER_TALENT_UPDATE")
        h.showProc(env, state, 1277420, 1027131, "LeftRight")
        state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    end
    equal(addon:GetProcRegionAppearance(Entry(addon)).mode, "custom")
    equal(addon:GetProcRegionAppearance(Entry(addon, right)).mode, "timer")
    same(addon:GetProcArtworkPresentation(Entry(addon)), addon:NewProcAppearance())
    equal(addon:IsProcArtworkEditable(Entry(addon)), false)
    h.options(addon); truthy(addon:SetPreview("single", left))
    local preview = assert(addon.procPreviewArtworkFrames[left])
    equal(preview.texture.texture, 1027131, "native sample does not reuse the stored custom asset")
    equal(preview.alpha, 1, "native sample does not reuse stored custom alpha")
    addon:StopPreview()
    equal(addon:ExportSettings("all"), before, "effective fallback never rewrites stored overrides")
    equal(addon.procArtworkFrames, nil)
    local notices = 0
    for _, message in ipairs(state.messages) do
        if type(message) == "string" and message:find("Saved Custom and Timer-only overrides", 1, true) then notices = notices + 1 end
    end
    equal(notices, 1, "one bounded explanation for legacy development settings")
    NoTakeover(addon, state)
end)

test("Release saved independent policy and region opt-in retain first SHOW and timer isolation", function()
    local _, seed = h.transferSeed()
    truthy(seed:SetProcRegionAppearance(Entry(seed), { mode = "native", alpha = .4 }))
    truthy(seed:UpdateSettings({ proc = { presentationPolicy = "independent",
        regions = { [left] = { independentArtworkEnabled = true } } } }))
    local env, addon, state = Start(copy(seed.db), true)
    truthy(addon:IsProcIndependentPolicy()); equal(addon.procArtworkFrames, nil)
    h.putAura(state, 263725, 18, 1, true)
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    local art = assert(addon.procArtworkFrames[left])
    truthy(art:IsShown()); equal(art.alpha, .4)
    truthy(addon:UpdateSettings({ proc = { independentArtworkEnabled = false } }))
    truthy(not art:IsShown()); equal(h.procText(addon, state, left), "18.0")
    state.proc.cvars.spellActivationOverlayOpacity = "1"
    state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity")
    truthy(addon:UpdateSettings({ proc = { independentArtworkEnabled = true } }))
    truthy(not art:IsShown()); equal(h.procText(addon, state, left), "18.0")
    equal(addon:GetProcConfig().regions[left].independentArtworkEnabled, true)
    NoTakeover(addon, state)
end)

test("Release import backup restore and reset cannot enable historical native takeover", function()
    local sourceEnv, source = h.transferSeed()
    source:SetProcRegionAppearance(Entry(source), { mode = "custom", alpha = .25 })
    source:SetProcRegionAppearance(Entry(source, right), { mode = "timer" })
    local exported = assert(source:ExportSettings("all"))
    local env, addon, state = Start()
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, exported)))
    equal(addon:GetProcRegionAppearance(Entry(addon)).mode, "custom")
    local packet = h.unpackSettings(sourceEnv, exported)
    packet.classes.MAGE.proc["62"].presentationPolicy = "independent"
    packet.classes.MAGE.proc["62"].regions[left].independentArtworkEnabled = true
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(sourceEnv, packet))))
    truthy(addon:IsProcIndependentPolicy())
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(addon:GetProcRegionAppearance(Entry(addon)).mode, "custom", "backup remains data-compatible")
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    equal(addon.procArtworkFrames, nil)
    packet.classes.MAGE.proc["62"].legacyProcDevelopment = true
    equal(addon:PrepareSettingsImport(h.packSettings(sourceEnv, packet)), nil, "import cannot contain a production override switch")
    truthy(addon:ResetDatabase()); equal(addon:GetProcPresentationPolicy(), "replacement")
    NoTakeover(addon, state)
end)

test("Release spec changes retain inactive development overrides without installing takeover hooks", function()
    local _, seed = h.transferSeed()
    seed:SetProcRegionAppearance(Entry(seed), { mode = "custom" })
    seed.db.classes.MAGE.proc[63].regions.mage_fire_hot_streak_left.appearance = { mode = "timer", scale = 1.6 }
    local env, addon, state = Start(copy(seed.db))
    for _ = 1, 5 do
        state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        h.showProc(env, state, 48108, 449490, "LeftRight")
        state.specID = 62; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        h.showProc(env, state, 1277420, 1027131, "LeftRight")
    end
    equal(addon:GetProcRegionAppearance(Entry(addon)).mode, "custom")
    equal(addon.db.classes.MAGE.proc[63].regions.mage_fire_hot_streak_left.appearance.mode, "timer")
    equal(addon.procArtworkFrames, nil); NoTakeover(addon, state)
end)
