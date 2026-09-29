-- Only addon-owned test objects and injected public failures are inspected.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Safety()
    local messages, counts = {}, {}
    local addon = { clean = true, stops = 0, configurations = 0 }
    function addon:ProcDiagnosticCount(key) counts[key] = (counts[key] or 0) + 1 end
    function addon:SetProcDiagnosticState() end
    function addon:RecordProcDiagnosticError() end
    function addon:Text(message) return message end
    function addon:Print(message) messages[#messages + 1] = message end
    function addon:StopProc()
        self.stops = self.stops + 1
        truthy(self:IsProcQuarantined(), "gate closes before cleanup")
        return self.clean
    end
    function addon:ConfigureProc() self.configurations = self.configurations + 1 end
    local chunk = assert(loadfile(h.root .. "/Core/ProcSafety.lua"))
    chunk("CarGOUI", addon)
    return addon, messages, counts
end

local function Fail() error("injected public failure") end

test("PROC SAFETY cumulative budget gates future calls without touching foreign error objects", function()
    local addon, messages, counts = Safety()
    local generation, calls = addon:GetProcSafetyGeneration(), 0
    local foreign = setmetatable({}, { __tostring = function() error("foreign error must remain opaque") end })
    equal(addon:RunProcSafe("render", function() error(foreign) end), false)
    truthy(addon:RunProcSafe("render", function() calls = calls + 1 end))
    equal(addon:GetProcSafetyDiagnostics().failures, 1, "success does not erase session failures")
    addon:RunProcSafe("render", Fail); addon:RunProcSafe("render", Fail)
    truthy(addon:IsProcQuarantined()); equal(addon:GetProcSafetyDiagnostics().failures, 3)
    truthy(not addon:IsProcSafetyGenerationCurrent(generation))
    for _ = 1, 1000 do addon:RunProcSafe("render", function() calls = calls + 1 end) end
    equal(calls, 1); equal(addon.stops, 1); equal(#messages, 1); equal(counts.quarantineEntries, 1)
    truthy(messages[1]:find("/cui diagnostics copy", 1, true)); truthy(messages[1]:find("/cui proc retry", 1, true))
    truthy(messages[1]:find("/reload", 1, true))
end)

test("PROC SAFETY nested boundaries count one operation and normal nil results cost no budget", function()
    local addon = Safety()
    addon:RunProcSafe("event", function()
        addon:RunProcSafe("artwork", Fail)
        error("outer operation also failed")
    end)
    equal(addon:GetProcSafetyDiagnostics().failures, 1)
    for _ = 1, 20 do
        local ok, missing, reason = addon:RunProcSafe("render", function() return nil, "expected-unavailable" end)
        truthy(ok); equal(missing, nil); equal(reason, "expected-unavailable")
    end
    equal(addon:GetProcSafetyDiagnostics().failures, 1)
end)

test("PROC SAFETY cleanup failure retains quarantine until explicit successful retry", function()
    local addon, messages = Safety()
    addon.clean = false
    addon:QuarantineProc("render")
    local before = addon:GetProcSafetyGeneration()
    equal(addon:RetryProc(), false); equal(addon.configurations, 0)
    truthy(addon:IsProcQuarantined()); equal(#messages, 1)
    truthy(addon:GetProcSafetyGeneration() > before)
    equal(addon:GetProcSafetyDiagnostics().cleanupComplete, false)
    addon.clean = true
    truthy(addon:RetryProc()); equal(addon.configurations, 1)
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
    truthy(not addon:IsProcQuarantined())
end)

test("PROC SAFETY a retry failure trips immediately and cleanup failures cannot recursively trip", function()
    local addon, messages = Safety()
    function addon:StopProc()
        self.stops = self.stops + 1
        truthy(self:IsProcQuarantined())
        self:RecordProcFailure("stop")
        return true
    end
    addon:QuarantineProc("render")
    function addon:ConfigureProc() self.configurations = self.configurations + 1; error("retry failure") end
    equal(addon:RetryProc(), false)
    truthy(addon:IsProcQuarantined()); equal(addon:GetProcSafetyDiagnostics().failures, 1)
    equal(addon.configurations, 1); equal(#messages, 2); equal(addon.stops, 3)
    addon:RunProcSafe("configure", addon.ConfigureProc, addon)
    equal(addon.configurations, 1, "later automatic events do not retry")
end)

test("PROC SAFETY a known uncertain allocation blocks retry without misreporting successful cleanup", function()
    local addon, messages = Safety()
    function addon:GetProcRetryBlocker() return "owned-factory-requires-reload" end
    addon:QuarantineProc("artwork")
    equal(addon:RetryProc(), false)
    local diagnostics = addon:GetProcSafetyDiagnostics()
    truthy(diagnostics.quarantined); truthy(diagnostics.cleanupComplete)
    equal(diagnostics.reason, "reload-required"); equal(diagnostics.phase, "retry")
    equal(addon.configurations, 0); equal(#messages, 1)
end)

local function Artwork(skipPreview)
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local entry = addon.procByRegion.mage_fire_hot_streak_left.regions[1]
    truthy(addon:SetProcRegionAppearance(entry, { mode = "custom", artColor = { r = 1, g = .5, b = .2 },
        animation = { entrance = "fade", active = "pulse", exit = "fade" } }))
    if not skipPreview then addon:RenderProcArtworkPreview(entry) end
    return env, addon, state, entry, addon.procPreviewArtworkFrames and addon.procPreviewArtworkFrames[entry.id]
end

local function NativeArtwork(skipPreview)
    local env, addon, state, entry = Artwork(skipPreview)
    local root, location = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType
    local texture = { alpha = 1 }
    function texture:SetAlpha(value) self.alpha = value end
    local overlay = { spellID = 48108, position = location.Left, texture = texture }
    root.overlaysInUse = { [48108] = { [location.Left] = overlay } }
    function root:ShowOverlay() end
    function root:ReleaseOverlay() end
    truthy(addon:InstallProcArtworkHooks())
    local function Show(rgb)
        rgb = rgb or {}
        root:ShowOverlay(48108, 449490, location.Left, 1, unpack(rgb))
        state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, location.LeftRight, 1, unpack(rgb))
    end
    return env, addon, state, entry, Show, overlay
end

test("PROC SAFETY old animation callbacks cannot resume artwork after stop or retry", function()
    local _, addon, _, entry, frame = Artwork()
    local old = frame.groups.entrance_fade:GetScript("OnFinished")
    addon:QuarantineProc("artwork")
    truthy(not frame:IsShown()); equal(frame.phase, nil)
    truthy(addon:RetryProc())
    addon:RenderProcArtworkPreview(entry)
    equal(frame.phase, "entrance")
    old()
    equal(frame.phase, "entrance", "previous session callback cannot start current active animation")
    local current = frame.groups.entrance_fade:GetScript("OnFinished")
    addon:StopProcArtworkPreview(); addon:RenderProcArtworkPreview(entry)
    current()
    equal(frame.phase, "entrance", "previous play callback cannot advance a reused frame in the same session")
    frame.groups.entrance_fade:GetScript("OnFinished")()
    equal(frame.phase, "active")
end)

test("PROC SAFETY preview failures stop allocations and appearance refresh stays quarantined", function()
    local _, addon, state, entry, frame = Artwork()
    local saved, frames, allocations = copy(addon.db), #state.frames, addon:GetProcDiagnosticSnapshot().counters
    local setTexture = frame.texture.SetTexture
    frame.texture.SetTexture = Fail
    for _ = 1, 1000 do addon:RenderProcArtworkPreview(entry); addon:RefreshProcAppearance(entry) end
    truthy(addon:IsProcQuarantined()); equal(#state.frames, frames)
    same(addon:GetProcDiagnosticSnapshot().counters.artworkFramesCreated, allocations.artworkFramesCreated)
    same(addon.db, saved, "quarantine never persists session faults or changes appearance")
    equal(frame.phase, nil); truthy(not frame:IsShown())
    frame.texture.SetTexture = setTexture
    truthy(addon:RetryProc(), "a returned texture can recover after its setter is repaired")
    addon:RenderProcArtworkPreview(entry)
    equal(addon.procPreviewArtworkFrames[entry.id], frame); truthy(frame:IsShown())
    equal(#state.frames, frames)
end)

test("PROC SAFETY missing layout and opacity remain expected availability results", function()
    local env, addon, _, entry = Artwork()
    env.SpellActivationOverlayFrame.GetEffectiveScale = function() return nil end
    for _ = 1, 20 do addon:RenderProcArtworkPreview(entry) end
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
    env.C_CVar.GetCVar = function() return nil end
    for _ = 1, 20 do addon:RenderProcArtwork() end
    equal(addon:GetProcSafetyDiagnostics().failures, 0); truthy(not addon:IsProcQuarantined())
end)

test("PROC SAFETY artwork cleanup continues past failed resources and retains native owners", function()
    local _, addon, _, _, frame = Artwork()
    local stopped, hide = 0, frame.Hide
    frame.Hide = Fail
    frame.groups.other = { Stop = function() stopped = stopped + 1 end }
    local texture = { SetAlpha = Fail }
    local overlay = {}
    addon.procSuppressedOverlays = { [overlay] = { texture = texture, regionID = frame.entryID } }
    addon:QuarantineProc("artwork")
    truthy(stopped > 0, "Hide failure does not skip animation cleanup")
    truthy(addon.procSuppressedOverlays[overlay], "failed alpha restore remains owned")
    equal(addon:RetryProc(), false)
    texture.SetAlpha = function(self, alpha) self.alpha = alpha end
    frame.Hide = hide
    truthy(addon:RetryProc()); equal(texture.alpha, 1); equal(addon.procSuppressedOverlays[overlay], nil)
end)

test("PROC SAFETY permanent native hooks stay inert except releasing a retained owner", function()
    local env, addon, state, entry = Artwork()
    local root, position = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType.Left
    local overlay = { spellID = 48108, position = position }
    overlay.texture = { SetAlpha = Fail }
    root.overlaysInUse = { [48108] = { [position] = overlay } }
    function root:ShowOverlay() end
    function root:ReleaseOverlay() end
    truthy(addon:InstallProcArtworkHooks())
    addon.procSuppressedOverlays = { [overlay] = { texture = overlay.texture, regionID = entry.id } }
    addon:QuarantineProc("artwork")
    truthy(addon.procSuppressedOverlays[overlay])
    local frames, hooks = #state.frames, addon:GetProcDiagnosticSnapshot().counters.artworkHooksInstalled
    for _ = 1, 1000 do
        root:ShowOverlay(48108, 449490, position, 1, 255, 128, 64)
        addon:RenderProcArtworkPreview(entry); addon:RefreshProcAppearance(entry)
    end
    equal(#state.frames, frames)
    equal(addon:GetProcDiagnosticSnapshot().counters.artworkHooksInstalled, hooks)
    overlay.texture.SetAlpha = function(self, value) self.alpha = value end
    root:ReleaseOverlay(overlay)
    equal(overlay.texture.alpha, 1); equal(addon.procSuppressedOverlays[overlay], nil)
    truthy(addon:IsProcQuarantined(), "cleanup authority cannot reopen the renderer")
end)

test("PROC SAFETY absent public RGB and unmatched lifecycle consume no failure budget", function()
    local _, addon, _, entry, Show, overlay = NativeArtwork()
    local appearance = addon:GetProcRegionAppearance(entry)
    appearance.artColor = nil
    addon:GetProcConfig().regions[entry.id].appearance = appearance
    for _ = 1, 30 do Show() end
    equal(overlay.texture.alpha, 1, "stock native color remains authoritative")
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
    addon.procNativeOverlays = {}
    for _ = 1, 30 do addon:RenderProcArtwork() end
    equal(addon:GetProcSafetyDiagnostics().failures, 0); truthy(not addon:IsProcQuarantined())
end)

test("PROC SAFETY old exit callbacks cannot hide a reused live frame", function()
    local _, addon, state, entry, Show = NativeArtwork()
    Show({ 255, 128, 64 })
    local frame = addon.procArtworkFrames[entry.id]
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    equal(frame.phase, "exit")
    local old = frame.groups.exit_fade:GetScript("OnFinished")
    Show({ 255, 128, 64 }); state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    equal(frame.phase, "exit"); truthy(frame:IsShown())
    old()
    equal(frame.phase, "exit"); truthy(frame:IsShown(), "old exit cannot finish the current play")
    frame.groups.exit_fade:GetScript("OnFinished")()
    equal(frame.phase, nil); truthy(not frame:IsShown())
end)

for _, factory in ipairs({ "frame", "texture", "group", "animation" }) do
    test("PROC SAFETY " .. factory .. " factory post-allocation failure stays bounded across explicit retries", function()
        for _, preview in ipairs({ true, false }) do
            local env, addon, state, entry, Show = NativeArtwork(true)
            local created, attempts = env.CreateFrame, 0
            env.CreateFrame = function(...)
                local frame = created(...)
                if factory == "frame" then attempts = attempts + 1; error("failure after allocating frame") end
                local createTexture = frame.CreateTexture
                frame.CreateTexture = function(owner, ...)
                    local texture = createTexture(owner, ...)
                    if factory == "texture" then attempts = attempts + 1; error("failure after allocating texture") end
                    local createGroup = texture.CreateAnimationGroup
                    texture.CreateAnimationGroup = function(owner, ...)
                        local group = createGroup(owner, ...)
                        if factory == "group" then attempts = attempts + 1; error("failure after allocating group") end
                        local createAnimation = group.CreateAnimation
                        group.CreateAnimation = function(owner, ...)
                            local animation = createAnimation(owner, ...)
                            if factory == "animation" then attempts = attempts + 1; error("failure after allocating animation") end
                            return animation
                        end
                        return group
                    end
                    return texture
                end
                return frame
            end
            local function Trigger()
                if preview then addon:RenderProcArtworkPreview(entry) else Show({ 255, 128, 64 }) end
            end
            for _ = 1, 3 do Trigger() end
            truthy(addon:IsProcQuarantined()); equal(attempts, 1, "failed factory is attempted once per stable pool key")
            local frames, textures, groups = #state.frames, #state.textures, #state.animations
            for _ = 1, 20 do
                equal(addon:RetryProc(), false, "uncertain allocation needs Reload before reconfiguration")
                for _ = 1, 3 do Trigger() end
                truthy(addon:IsProcQuarantined())
                truthy(addon:GetProcSafetyDiagnostics().cleanupComplete, "known returned resources were cleaned")
                equal(addon:GetProcSafetyDiagnostics().reason, "reload-required")
            end
            equal(attempts, 1, "explicit retries require reload for an unreturned object")
            equal(#state.frames, frames); equal(#state.textures, textures); equal(#state.animations, groups)
            equal(#state.errors, 0, "failure remains inside the Proc boundary")
        end
    end)
end

test("PROC SAFETY a hook that registers before throwing cannot be installed again by explicit Retry", function()
    for _, failedMethod in ipairs({ "ShowOverlay", "ReleaseOverlay" }) do
        local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
        local root, hook = env.SpellActivationOverlayFrame, env.hooksecurefunc
        function root:ShowOverlay() end
        function root:ReleaseOverlay() end
        local registrations = { ShowOverlay = 0, ReleaseOverlay = 0 }
        env.hooksecurefunc = function(owner, method, callback)
            hook(owner, method, callback)
            registrations[method] = registrations[method] + 1
            if method == failedMethod then error("failure after registering permanent native hook") end
        end
        for _ = 1, 3 do equal(addon:InstallProcArtworkHooks(), false) end
        truthy(addon:IsProcQuarantined()); equal(registrations[failedMethod], 1)
        local before, frames = copy(registrations), #state.frames
        for _ = 1, 20 do
            equal(addon:RetryProc(), false)
            root:ShowOverlay(48108, 449490, env.Enum.ScreenLocationType.Left, 1, 255, 128, 64)
            equal(addon:InstallProcArtworkHooks(), false)
        end
        same(registrations, before, "irreversible post-hook registration is attempted once per root and method")
        equal(#state.frames, frames)
        equal(addon:GetProcDiagnosticSnapshot().counters.artworkHooksInstalled,
            failedMethod == "ShowOverlay" and 0 or 1, "counter records only known completed registrations")
        equal(addon:GetProcSafetyDiagnostics().reason, "reload-required")
        equal(#state.errors, 0)
    end
end)
