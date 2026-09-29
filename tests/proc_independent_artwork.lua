-- Independent artwork uses public events and owned pixels only. This fixture
-- rejects native lifecycle access rather than fabricating suppressed overlays.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local leftID, rightID = "mage_fire_hot_streak_left", "mage_fire_hot_streak_right"

local function Fixture(appearance, legacyHooks)
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" } } })
    local callbacks = {}
    if legacyHooks then
        local root, hook = env.SpellActivationOverlayFrame, env.hooksecurefunc
        root.ShowOverlay, root.ReleaseOverlay = function() end, function() end
        env.hooksecurefunc = function(owner, method, callback)
            callbacks[method] = callback
            return hook(owner, method, callback)
        end
        truthy(addon:InstallProcArtworkHooks())
    end
    local config = addon:GetProcConfig()
    config.presentationPolicy = "independent"
    config.regions[leftID] = { independentArtworkEnabled = true, appearance = appearance or { mode = "native", alpha = .37 } }
    addon:ConfigureProc()
    truthy(addon:IsProcIndependentPolicy(), "configuration commits independent runtime policy")
    local entry = addon:GetCurrentProcRegion({ kind = "proc", id = leftID, class = "MAGE", specID = 63 })
    truthy(entry)
    local forbidden = function() error("Independent policy accessed a native lifecycle object") end
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end }, { __index = forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = forbidden, forbidden, forbidden
    local f = { env = env, addon = addon, state = state, entry = entry, config = config, callbacks = callbacks }
    function f:Show(rgb)
        rgb = rgb or { 255, 128, 64 }
        self.state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490,
            env.Enum.ScreenLocationType.LeftRight, 1, unpack(rgb))
        return addon.procArtworkFrames and addon.procArtworkFrames[leftID]
    end
    function f:Frame() return assert(addon.procArtworkFrames[leftID]) end
    function f:NoNative()
        equal(next(addon.procSuppressedOverlays or {}), nil, "no native suppression ownership")
        equal(next(addon.procNativeOverlays or {}), nil, "no native lifecycle records")
        local apis = addon:GetProcDiagnosticSnapshot().api
        for _, key in ipairs({ "SuppressNativeAlpha", "RestoreNativeAlpha" }) do
            equal(apis[key].requested, 0, key)
        end
        equal(#state.errors, 0, "no event tripwire failed")
    end
    return f
end

local function Finish(group)
    group:Stop()
    group:GetScript("OnFinished")(group)
end

test("Independent Proc first public SHOW draws at CUI alpha with no native hook or overlay", function()
    local f = Fixture()
    truthy(f.addon:InstallProcArtworkHooks(), "independent install returns before native capability lookup")
    equal(f.addon.procArtworkFrames, nil, "timer bootstrap does not invent artwork SHOW")
    local frame = assert(f:Show())
    truthy(frame:IsShown()); equal(frame.alpha, .37)
    equal(frame.texture.texture, 449490)
    same(frame.texture.vertexColor, { 1, 128 / 255, 64 / 255 })
    equal(frame.texture.blendMode, "BLEND")
    equal(f.addon:GetProcRegionAppearance(f.entry).mode, "native", "saved legacy mode stays untouched")
    equal(f.addon.procArtworkFrames[rightID], nil, "unselected sibling draws nothing")
    equal(f.addon:GetProcSafetyDiagnostics().failures, 0)
    f:NoNative()
end)

test("Independent Proc saved startup needs only root geometry and one public SHOW", function()
    local f = Fixture()
    local env, addon, state = h.setup(h.copy(f.addon.db), false, { specID = 63, proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" } } })
    local function Forbidden() error("cold independent startup touched native lifecycle") end
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end }, { __index = Forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = Forbidden, Forbidden, Forbidden
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    truthy(addon:IsProcIndependentPolicy()); equal(#state.errors, 0)
    equal(addon.procArtworkFrames, nil, "cold bootstrap does not synthesize graphical intent")
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, env.Enum.ScreenLocationType.LeftRight, 1, 255, 128, 64)
    local frame = assert(addon.procArtworkFrames[leftID])
    truthy(frame:IsShown()); equal(frame.alpha, .37); equal(#state.errors, 0)
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
    equal(next(addon.procSuppressedOverlays or {}), nil)
end)

test("Independent Proc installed legacy hooks are inert before any native object access", function()
    local f = Fixture(nil, true)
    local opaque = setmetatable({}, { __index = function() error("native object was inspected") end })
    f.callbacks.ShowOverlay(opaque, h.secret(48108), h.secret(449490), h.secret(1))
    f.callbacks.ReleaseOverlay(opaque, opaque)
    equal(f.addon:GetProcSafetyDiagnostics().failures, 0)
    truthy(f:Show():IsShown())
    f.addon:QuarantineProc("artwork")
    f.callbacks.ShowOverlay(opaque); f.callbacks.ReleaseOverlay(opaque, opaque)
    truthy(not f:Frame():IsShown())
    f:NoNative()
end)

test("Independent Proc reuses owned motion across SHOW numeric tint preview and late exit", function()
    local f = Fixture({ mode = "timer", alpha = .8, rotation = 30, mirrorX = true, desaturation = .4,
        animation = { entrance = "scale", active = "pulse", exit = "fade" } })
    local addon, frame = f.addon, assert(f:Show())
    local entrance, frames, textures = frame.groups.entrance_scale, #f.state.frames, #f.state.textures
    local plays, callback = entrance.plays, entrance:GetScript("OnFinished")
    for _ = 1, 20 do f:Show() end
    equal(entrance.plays, plays); equal(entrance:GetScript("OnFinished"), callback)
    equal(#f.state.frames, frames); equal(#f.state.textures, textures)
    h.options(addon); truthy(addon:SetPreview("single", leftID))
    local preview = assert(addon.procPreviewArtworkFrames[leftID])
    truthy(addon:SetProcRegionAppearance(f.entry, { alpha = .24, desaturation = .75,
        animation = { speed = 2, intensity = .8 } }, { skipOptionsRefresh = true, continuousAppearance = true }))
    equal(frame.alpha, .24); equal(preview.alpha, .24); equal(frame.texture.desaturation, .75)
    equal(entrance.plays, plays); equal(entrance:GetScript("OnFinished"), callback)
    truthy(addon:SetProcArtworkColorPreview(f.entry, { r = .2, g = .6, b = .9 }))
    same(frame.texture.vertexColor, { .2, .6, .9 }); same(preview.texture.vertexColor, { .2, .6, .9 })
    truthy(addon:SetProcArtworkColorPreview(f.entry, nil))
    same(frame.texture.vertexColor, { 1, 128 / 255, 64 / 255 })
    Finish(entrance); equal(frame.phase, "active")
    f.state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    local exit = frame.groups.exit_fade:GetScript("OnFinished")
    f:Show(); exit()
    truthy(frame:IsShown(), "old exit completion cannot hide a reacquired graphic")
    f.state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    Finish(frame.groups.exit_fade); truthy(not frame:IsShown())
    addon:StopPreview(); f:NoNative()
end)

test("Independent Proc unavailable RGB stops only owned artwork and explicit tint restores it", function()
    local f = Fixture()
    local frame = assert(f:Show())
    f:Show({ h.secret(255), 128, 64 })
    truthy(not frame:IsShown())
    equal(f.addon.procArtworkDiagnostics[leftID], "native-color-unavailable")
    truthy(f.addon:SetProcRegionAppearance(f.entry, { artColor = { r = .1, g = .2, b = .3 } }))
    truthy(frame:IsShown()); same(frame.texture.vertexColor, { .1, .2, .3 })
    equal(f.addon:GetProcSafetyDiagnostics().failures, 0, "missing public evidence is not an API exception")
    f:NoNative()
end)

test("Independent Proc native preference changes pause artwork while preserving timer binding", function()
    local f = Fixture()
    local frame = assert(f:Show())
    local timer = h.procFrame(f.addon, leftID)
    local handle = timer.auraHandle
    f.state.proc.cvars.spellActivationOverlayOpacity = "0.4"
    f.state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity")
    truthy(not frame:IsShown()); equal(f.addon.procArtworkDiagnostics[leftID], "native-mute-required")
    equal(timer.auraHandle, handle); equal(handle.enabled, true); equal(timer.alpha, 1)
    f.state.proc.cvars.spellActivationOverlayOpacity = "0"
    f.state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity")
    truthy(f:Show():IsShown()); equal(frame.alpha, .37)
    f.config.independentArtworkEnabled = false
    f.addon:RenderProcArtwork(); truthy(not frame:IsShown())
    equal(timer.auraHandle, handle); equal(handle.enabled, true)
    h.options(f.addon); truthy(f.addon:SetPreview("single", leftID))
    truthy(f.addon.procPreviewArtworkFrames[leftID]:IsShown(), "explicit sample remains editable with live artwork off")
    f:NoNative()
end)

test("Independent Proc animation failure and unexpected ownership never access native textures", function()
    local f = Fixture({ animation = { entrance = "scale", active = "pulse" } })
    local frame = assert(f:Show())
    local create = frame.texture.CreateAnimationGroup
    frame.texture.CreateAnimationGroup = function() error("owned active animation unavailable") end
    Finish(frame.groups.entrance_scale)
    truthy(not frame:IsShown()); truthy(f.addon:GetProcSafetyDiagnostics().failures > 0)
    frame.texture.CreateAnimationGroup = create
    f:NoNative()
    local overlay, touched = {}, 0
    local record = { regionID = leftID, texture = { SetAlpha = function() touched = touched + 1 end } }
    f.addon.procSuppressedOverlays = { [overlay] = record }
    equal(f.addon:StopProcArtwork(), false, "invariant violation cannot report cleanup success")
    equal(f.addon.procSuppressedOverlays[overlay], record, "unresolved cleanup authority is retained")
    equal(touched, 0, "independent cleanup never writes native texture")
    truthy(f.addon:GetProcArtworkDiagnostic(f.entry):find("unexpected retained ownership", 1, true),
        "diagnostics do not mislabel an invariant violation as no ownership")
end)
