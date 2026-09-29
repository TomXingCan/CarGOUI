-- Production fixtures use the shipped capability unchanged. A local opt-in is
-- used only to construct historical ownership for cleanup regression tests.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local leftID = "mage_fire_hot_streak_left"

local function Entry(addon)
    return assert(addon:GetCurrentProcRegion({ kind = "proc", id = leftID, class = "MAGE", specID = 63 }))
end

local function Forbidden() error("production renderer accessed a native lifecycle object") end
local function Opaque() return setmetatable({}, { __index = Forbidden, __newindex = Forbidden }) end
local function GeometryOnly(env)
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end },
        { __index = Forbidden, __newindex = Forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = Forbidden, Forbidden, Forbidden
end
local function Show(env, state)
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, env.Enum.ScreenLocationType.LeftRight, 1, 255, 128, 64)
end
local function NoAcquisition(addon)
    equal(next(addon.procSuppressedOverlays or {}), nil)
    equal(next(addon.procNativeOverlays or {}), nil)
    local api = addon:GetProcDiagnosticSnapshot().api
    equal(api.SuppressNativeAlpha.requested, 0)
    equal(api.RestoreNativeAlpha.requested, 0)
end

local function HistoricalOwnership(start)
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    equal(addon:IsProcLegacyReplacementAllowed(), false, "fixture starts with the production capability")
    local productionGate = addon.IsProcLegacyReplacementAllowed
    -- Development-only fixture opt-in: this is never a saved or runtime flag.
    addon.IsProcLegacyReplacementAllowed = function() return true end
    local root, callbacks = env.SpellActivationOverlayFrame, {}
    local nativeHook = env.hooksecurefunc
    env.hooksecurefunc = function(owner, method, callback)
        callbacks[method] = callback
        return nativeHook(owner, method, callback)
    end
    local texture = { alpha = 1, writes = {} }
    function texture:SetAlpha(value)
        self.writes[#self.writes + 1] = value
        if self.failRestore and value == 1 then error("injected cleanup failure") end
        self.alpha = value
    end
    local overlay = { texture = texture, spellID = 48108, position = env.Enum.ScreenLocationType.Left }
    root.overlaysInUse = {}
    function root:ShowOverlay(owner, _, position)
        self.overlaysInUse[owner] = self.overlaysInUse[owner] or {}
        self.overlaysInUse[owner][position] = overlay
    end
    function root:ReleaseOverlay()
        self.overlaysInUse = {}
    end
    truthy(addon:InstallProcArtworkHooks())
    addon:GetProcConfig().regions[leftID] = { appearance = { mode = "custom", alpha = .4 } }
    local f = { env = env, addon = addon, state = state, callbacks = callbacks, texture = texture,
        overlay = overlay, entry = Entry(addon), root = root }
    function f:Show()
        Show(env, state)
        root:ShowOverlay(48108, 449490, env.Enum.ScreenLocationType.Left, 1, 255, 128, 64)
    end
    function f:Close()
        addon.IsProcLegacyReplacementAllowed = productionGate
        GeometryOnly(env)
    end
    if start ~= false then
        f:Show()
        equal(texture.alpha, 0)
        truthy(addon.procSuppressedOverlays[overlay])
        truthy(addon.procArtworkFrames[leftID]:IsShown())
    end
    return f
end

test("Release renderer cold legacy Custom and Timer Only retain native artwork without hooks", function()
    for _, mode in ipairs({ "custom", "timer" }) do
        local _, seed = h.login(nil, false, { specID = 63, proc = {} })
        local appearance = { mode = mode, alpha = .25, rotation = 47,
            animation = { entrance = "scale", active = "rotate", exit = "fade" } }
        seed:GetProcConfig().regions[leftID] = { appearance = h.copy(appearance) }
        local env, addon, state = h.setup(h.copy(seed.db), false, { specID = 63, proc = {} })
        equal(addon:IsProcLegacyReplacementAllowed(), false)
        GeometryOnly(env)
        state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
        equal(addon:InstallProcArtworkHooks(), false, "direct install also stops before native method lookup")
        Show(env, state)
        local entry = Entry(addon)
        addon:RefreshProcAppearance(entry)
        addon:RefreshProcContinuousAppearance(entry)
        equal(addon.procArtworkHookRoot, nil)
        equal(addon.procArtworkHookParts, nil)
        equal(addon.procArtworkFrames, nil)
        truthy(h.procFrame(addon, leftID).auraHandle.enabled, "native-bound timer remains enabled")
        same(addon:GetProcConfig().regions[leftID].appearance, appearance, "legacy preferences are not migrated")
        equal(addon:GetProcArtworkPresentation(entry).mode, "native")
        truthy(addon:GetProcArtworkDiagnostic(entry):find("saved legacy mode=" .. mode, 1, true))
        equal(addon:GetProcSafetyDiagnostics().failures, 0)
        equal(#state.errors, 0)
        NoAcquisition(addon)
    end
end)

test("Release renderer direct preview ignores dormant legacy artwork and keeps a native sample", function()
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    equal(addon:IsProcLegacyReplacementAllowed(), false)
    GeometryOnly(env)
    local entry = Entry(addon)
    for _, mode in ipairs({ "custom", "timer" }) do
        addon:GetProcConfig().regions[leftID] = { appearance = { mode = mode, alpha = .1,
            desaturation = 1, rotation = 91, scale = 2, artColor = { r = .2, g = .4, b = .6 },
            offset = { x = 65, y = -79 }, animation = { entrance = "scale", active = "rotate" } } }
        -- Exercise the renderer boundary independently of the Core snapshot gate.
        addon.GetProcArtworkPresentation = addon.GetProcRegionAppearance
        addon:RenderProcArtworkPreview(entry)
        local frame = assert(addon.procPreviewArtworkFrames[leftID])
        truthy(frame:IsShown()); equal(frame.appearance.mode, "native")
        equal(frame.alpha, 1); equal(frame.rotation, 0); equal(frame.texture.desaturation, 0)
        same(frame.texture.vertexColor, { 1, 1, 1 })
        equal(frame.texture.texture, 449490)
        equal(next(frame.groups or {}), nil)
        equal(frame.appearance.offset.x, 0); equal(frame.appearance.offset.y, 0)
        addon:RefreshProcContinuousAppearance(entry)
        equal(frame.appearance.mode, "native"); equal(frame.alpha, 1)
    end
    -- Even a nonconforming resolver cannot feed legacy custom art to Draw.
    local resolve = addon.ResolveProcAppearance
    addon.ResolveProcAppearance = function(self, ...)
        local appearance, asset = resolve(self, ...)
        appearance.mode = "custom"
        return appearance, asset
    end
    addon:RenderProcArtworkPreview(entry)
    truthy(not addon.procPreviewArtworkFrames[leftID]:IsShown())
    equal(#state.errors, 0); NoAcquisition(addon)
end)

test("Release renderer installed hooks clean only known ownership after acquisition closes", function()
    local f = HistoricalOwnership()
    local suppressed = f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested
    f:Close()
    f.callbacks.ShowOverlay(Opaque(), h.secret(48108), h.secret(449490), h.secret(1))
    equal(f.texture.alpha, 1)
    equal(next(f.addon.procSuppressedOverlays), nil)
    equal(next(f.addon.procNativeOverlays), nil)
    truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
    for _ = 1, 3 do
        f.callbacks.ShowOverlay(Opaque())
        f.callbacks.ReleaseOverlay(Opaque(), Opaque())
        Show(f.env, f.state)
        f.addon:RefreshProcContinuousAppearance(f.entry)
    end
    equal(f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested, suppressed)
    equal(f.addon:GetProcSafetyDiagnostics().failures, 0)
    equal(#f.state.errors, 0)
end)

test("Release renderer closed hooks preserve failed cleanup ownership until Show or Release retry", function()
    for _, completion in ipairs({ "ShowOverlay", "ReleaseOverlay" }) do
        local f = HistoricalOwnership()
        local record = f.addon.procSuppressedOverlays[f.overlay]
        f:Close(); f.texture.failRestore = true
        f.callbacks[completion](Opaque(), f.overlay)
        equal(f.addon.procSuppressedOverlays[f.overlay], record)
        equal(f.texture.alpha, 0)
        truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
        local writes = #f.texture.writes
        f.callbacks.ReleaseOverlay(Opaque(), Opaque())
        equal(#f.texture.writes, writes, "unknown pooled object grants no cleanup authority")
        f.texture.failRestore = false
        f.callbacks[completion](Opaque(), f.overlay)
        equal(f.texture.alpha, 1)
        equal(next(f.addon.procSuppressedOverlays), nil)
        truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
        equal(f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested, 1)
        equal(#f.state.errors, 0)
    end
end)

test("Release renderer direct refresh retains failed cleanup handles without reviving legacy artwork", function()
    local f = HistoricalOwnership()
    local record = f.addon.procSuppressedOverlays[f.overlay]
    f:Close(); f.texture.failRestore = true
    f.addon:RefreshProcContinuousAppearance(f.entry)
    equal(f.addon.procSuppressedOverlays[f.overlay], record)
    truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
    truthy(f.addon:GetProcArtworkDiagnostic(f.entry):find("cleanup pending", 1, true))
    f.texture.failRestore = false
    f.addon:RefreshProcAppearance(f.entry)
    equal(f.texture.alpha, 1); equal(next(f.addon.procSuppressedOverlays), nil)
    truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
    equal(f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested, 1)
    equal(#f.state.errors, 0)
end)

test("Release renderer quarantined closed hook retains cleanup authority without reopening acquisition", function()
    local f = HistoricalOwnership()
    local record = f.addon.procSuppressedOverlays[f.overlay]
    f:Close(); f.texture.failRestore = true
    f.addon:QuarantineProc("artwork")
    truthy(f.addon:IsProcQuarantined())
    equal(f.addon.procSuppressedOverlays[f.overlay], record)
    f.texture.failRestore = false
    f.callbacks.ShowOverlay(Opaque())
    equal(f.texture.alpha, 1); equal(next(f.addon.procSuppressedOverlays), nil)
    f.callbacks.ReleaseOverlay(Opaque(), Opaque())
    truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
    equal(f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested, 1)
    equal(#f.state.errors, 0)
end)

test("Release renderer checks acquisition again when the gate closes during owned drawing", function()
    local f = HistoricalOwnership(false)
    local anchor = f.addon.AnchorProcReminder
    f.addon.AnchorProcReminder = function(self, ...)
        local ok, reason = anchor(self, ...)
        if select(4, ...) == true then self.IsProcLegacyReplacementAllowed = function() return false end end
        return ok, reason
    end
    f:Show()
    equal(f.texture.alpha, 1)
    equal(next(f.addon.procSuppressedOverlays or {}), nil)
    equal(f.addon:GetProcDiagnosticSnapshot().api.SuppressNativeAlpha.requested, 0)
    truthy(not f.addon.procArtworkFrames[leftID]:IsShown())
    equal(f.addon:GetProcSafetyDiagnostics().failures, 1)
    equal(#f.state.errors, 0)
end)

test("Release renderer independent public SHOW and disabled-Proc preview bypass no native authority", function()
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" } } })
    equal(addon:IsProcLegacyReplacementAllowed(), false)
    local config = addon:GetProcConfig()
    config.presentationPolicy = "independent"
    config.regions[leftID] = { independentArtworkEnabled = true, appearance = { mode = "timer", alpha = .42 } }
    GeometryOnly(env)
    addon:ConfigureProc(); Show(env, state)
    local frame = assert(addon.procArtworkFrames[leftID])
    truthy(frame:IsShown()); equal(frame.alpha, .42)
    same(frame.texture.vertexColor, { 1, 128 / 255, 64 / 255 })
    config.enabled = false; addon:ConfigureProc()
    addon:RenderProcArtworkPreview(Entry(addon))
    local preview = assert(addon.procPreviewArtworkFrames[leftID])
    truthy(preview:IsShown()); equal(preview.alpha, .42)
    equal(addon:GetProcConfig().regions[leftID].appearance.mode, "timer")
    NoAcquisition(addon); equal(#state.errors, 0)
end)
