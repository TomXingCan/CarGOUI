-- The native fixture models only the audited public ShowOverlay/ReleaseOverlay
-- contract. Native timing, secure execution and visuals still need client QA.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local leftID, rightID = "mage_fire_hot_streak_left", "mage_fire_hot_streak_right"

local function Fixture(partialHookFailure)
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local root, positions = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType
    root.overlaysInUse = {}
    state.nativeTextureWrites = {}
    function root:ShowOverlay(owner, textureID, position, scale, r, g, b)
        self.overlaysInUse[owner] = self.overlaysInUse[owner] or {}
        local overlay = self.overlaysInUse[owner][position]
        if not overlay then
            local texture = { alpha = 1, writes = {} }
            function texture:SetAlpha(value)
                self.writes[#self.writes + 1] = value
                state.nativeTextureWrites[#state.nativeTextureWrites + 1] = { self, value }
                if self.failAlpha == value then error("native setter unavailable") end
                self.alpha = value
            end
            for _, method in ipairs({ "GetAlpha", "SetTexture", "SetVertexColor", "GetVertexColor",
                "SetTexCoord", "SetPoint", "SetSize", "SetWidth", "SetHeight", "CreateAnimationGroup" }) do
                texture[method] = function() error("forbidden native texture access: " .. method) end
            end
            overlay = { spellID = owner, position = position, texture = texture }
            self.overlaysInUse[owner][position] = overlay
        end
        overlay.spellID, overlay.position = owner, position
    end
    function root:ReleaseOverlay(overlay)
        self.overlaysInUse[overlay.spellID][overlay.position] = nil
        self.released = overlay
    end
    env.C_CVar.SetCVar = function() error("presentation must not write CVar") end
    env.SetCVar = env.C_CVar.SetCVar
    if partialHookFailure then
        local hook = env.hooksecurefunc
        env.hooksecurefunc = function(owner, method, callback)
            if method == "ReleaseOverlay" then error("missing release capability") end
            return hook(owner, method, callback)
        end
        equal(addon:InstallProcArtworkHooks(), false, "partial lifecycle capability unavailable")
        env.hooksecurefunc = hook
    else truthy(addon:InstallProcArtworkHooks(), "audited native lifecycle hooks installed") end
    for _, id in ipairs({ leftID, rightID }) do
        addon:GetProcConfig().regions[id] = addon:GetProcConfig().regions[id] or {}
    end
    local entry = addon.procByRegion[leftID].regions[1]
    local function Set(id, appearance)
        addon:GetProcConfig().regions[id] = addon:GetProcConfig().regions[id] or {}
        addon:GetProcConfig().regions[id].appearance = appearance
        addon:RefreshProcAppearance()
    end
    local function Show(owner, textureID, location, scale, rgb, eventFirst)
        owner, textureID, location, scale, rgb = owner or 48108, textureID or 449490,
            location or "LeftRight", scale or 1, rgb or { 255, 128, 64 }
        local function Event()
            state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", owner, textureID, positions[location], scale, unpack(rgb))
        end
        if eventFirst then Event() end
        for _, simple in ipairs(addon.procLocations[location] or { location }) do
            root:ShowOverlay(owner, textureID, positions[simple], scale, unpack(rgb))
        end
        if not eventFirst then Event() end
        return root.overlaysInUse[owner][positions[addon.procLocations[location][1]]]
    end
    return env, addon, state, root, entry, Set, Show
end

test("Proc appearance old timer records and Native mode never suppress native graphics", function()
    local _, addon, state, _, entry, Set, Show = Fixture()
    local old = { position = { x = 21, y = -17, anchor = "CENTER" }, color = { r = .2, g = .4, b = .6 } }
    addon:GetProcConfig().regions[leftID] = copy(old)
    local overlay = Show()
    equal(overlay.texture.alpha, 1)
    equal(#state.nativeTextureWrites, 0, "default Native performs zero native texture writes")
    equal(addon.procArtworkFrames, nil, "default Native does not create custom artwork")
    same(addon:GetProcConfig().regions[leftID], old, "old timer position/color untouched")
    Set(leftID, { mode = "native", alpha = .1, rotation = 45 })
    equal(#state.nativeTextureWrites, 0, "explicit Native ignores dormant transforms")
    equal(addon:GetProcRegionAppearance(entry).mode, "native")
end)

test("Proc custom suppression requires exact audited owner texture and simple region", function()
    local env, addon, state, root, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" })
    local overlay = Show()
    equal(overlay.texture.alpha, 0, "matching left native texture suppressed")
    local right = root.overlaysInUse[48108][env.Enum.ScreenLocationType.Right]
    equal(right.texture.alpha, 1, "unconfigured sibling stays Native")
    local owned = addon.procArtworkFrames[leftID]
    truthy(owned and owned.active and owned.texture ~= overlay.texture, "replacement is addon-owned")
    equal(owned.texture.texture, 449490)
    local unrelated = Show(999999, 449490)
    equal(unrelated.texture.alpha, 1, "unmapped owner untouched")
    local bad = Show(48108, 999999)
    equal(bad.texture.alpha, 1, "unaudited texture never suppressed")
    truthy(not addon.procSuppressedOverlays[bad], "mismatched source is not owned")
    equal(state.realReads, 0, "presentation never queries Aura")
end)

test("Proc Timer Only suppresses safely without allocating artwork texture", function()
    local _, addon, state, root, _, Set, Show = Fixture()
    Set(leftID, { mode = "timer" })
    local overlay = Show()
    equal(overlay.texture.alpha, 0)
    equal(addon.procArtworkFrames, nil, "timer-only creates no custom texture")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    equal(overlay.texture.alpha, 0, "Timer Only retains suppression during native fade")
    root:ReleaseOverlay(overlay)
    equal(overlay.texture.alpha, 1, "release restores Timer Only pooled texture")
    overlay = Show()
    Set(leftID, { mode = "native" })
    equal(overlay.texture.alpha, 1, "timer to Native restores immediately")
end)

test("Proc cross-class selected catalog artwork uses audited FileDataID and reset restores Native", function()
    local _, addon, _, _, entry, Set, Show = Fixture()
    local asset
    for _, candidate in ipairs(addon:GetProcAssets()) do if candidate.class ~= "MAGE" then asset = candidate; break end end
    truthy(asset)
    addon:GetProcConfig().regions[leftID].color = { r = .2, g = .3, b = .4 }
    addon:GetProcConfig().regions[leftID].position = { x = 29, y = 31, anchor = "CENTER" }
    Set(leftID, { mode = "custom", assetKey = asset.key, artColor = { r = .8, g = .7, b = .6 } })
    local overlay = Show()
    equal(addon.procArtworkFrames[leftID].texture.texture, asset.textureID)
    truthy(addon:ResetProcRegionAppearance(entry))
    equal(overlay.texture.alpha, 1)
    same(addon:GetProcRegionColor(entry), { r = .2, g = .3, b = .4 })
    equal(addon:GetReminderPosition(entry).x, 29)
end)

test("Proc partial hook installation cannot suppress without a restoration hook", function()
    local _, addon, state, _, _, Set, Show = Fixture(true)
    Set(leftID, { mode = "custom" })
    local overlay = Show()
    equal(overlay.texture.alpha, 1)
    equal(#state.nativeTextureWrites, 0, "installed Show hook stays dormant until complete")
    equal(addon:InstallProcArtworkHooks(), false, "an uncertain hook attempt cannot be repeated")
    equal(addon:InstallProcArtworkHooks(), false)
    truthy(addon:IsProcQuarantined())
    equal(addon:RetryProc(), false, "unknown hook completion requires Reload")
    Show(); equal(overlay.texture.alpha, 1)
    equal(#state.nativeTextureWrites, 0, "partial lifecycle hooks never gain suppression authority")
end)

test("Proc suppression missing lifecycle wrong handles RGB and renderer errors fail open", function()
    local env, addon, state, root, entry, Set, Show = Fixture()
    Set(leftID, { mode = "custom" })
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, env.Enum.ScreenLocationType.LeftRight, 1, 255, 255, 255)
    equal(next(addon.procSuppressedOverlays or {}), nil, "event alone cannot obtain native handle")
    local overlay = Show(nil, nil, nil, nil, { h.secret(255), 128, 64 })
    equal(overlay.texture.alpha, 1, "secret public RGB retains original artwork")
    truthy(addon:GetProcArtworkDiagnostic(entry):find("native%-color%-unavailable"))
    overlay = Show()
    equal(overlay.texture.alpha, 0)
    addon.procArtworkFrames[leftID].texture.SetTexture = function() error("owned texture load failure") end
    addon:RefreshProcAppearance()
    equal(overlay.texture.alpha, 1, "renderer fault restores native ownership")
    truthy(not addon.procArtworkFrames[leftID]:IsShown(), "failed replacement hidden")
    root.overlaysInUse[48108][env.Enum.ScreenLocationType.Left] = nil
    addon:RefreshProcAppearance()
    truthy(addon:GetProcArtworkDiagnostic(entry):find("unavailable"))
end)

test("Proc custom native color is public byte RGB independent of timer RGB", function()
    local _, addon, _, _, entry, Set, Show = Fixture()
    addon:GetProcConfig().regions[leftID].color = { r = .1, g = .2, b = .3 }
    Set(leftID, { mode = "custom" })
    Show(nil, nil, nil, nil, { 51, 102, 153 }, true)
    local color = addon.procArtworkFrames[leftID].texture.vertexColor
    same(color, { .2, .4, .6 }, "native artwork RGB derived from public SHOW")
    same(addon:GetProcRegionColor(entry), { r = .1, g = .2, b = .3 }, "timer RGB remains independent")
    Set(leftID, { mode = "custom", artColor = { r = .7, g = .6, b = .5 } })
    same(addon.procArtworkFrames[leftID].texture.vertexColor, { .7, .6, .5 })
end)

test("Proc repeated invalid public RGB cannot reuse a prior SHOW color in either callback order", function()
    local _, addon, _, _, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" })
    for _, eventFirst in ipairs({ false, true }) do
        local overlay = Show()
        equal(overlay.texture.alpha, 0)
        Show(nil, nil, nil, nil, { h.secret(255), 128, 64 }, eventFirst)
        equal(overlay.texture.alpha, 1, "invalid repeated SHOW restores native artwork")
        truthy(not addon.procArtworkFrames[leftID]:IsShown(), "stale color cannot render custom")
    end
end)

test("Proc artwork geometry transforms and CVar alpha preserve timer ownership", function()
    local env, addon, state, _, entry, Set, Show = Fixture()
    addon:GetProcConfig().regions[leftID].position = { x = 83, y = -92, anchor = "CENTER" }
    state.proc.cvars.spellActivationOverlayOpacity = "0.6"
    Set(leftID, { mode = "custom", alpha = .5, scale = 1.5, width = 2, height = .5,
        desaturation = .7, rotation = 90, mirrorX = true, mirrorY = true, offset = { x = 20, y = -30 } })
    Show()
    local frame = addon.procArtworkFrames[leftID]
    equal(frame.width, 128 * .8 * 1.5 * 2)
    equal(frame.height, 256 * .8 * 1.5 * .5)
    equal(frame.alpha, .3)
    equal(frame.texture.desaturation, .7)
    equal(frame.texture.rotation, math.pi / 2)
    same(frame.texture.texCoord, { 1, 0, 1, 0 })
    local _, relative, point, x, y = frame:GetPoint(1)
    equal(relative, env.SpellActivationOverlayFrame); equal(point, "LEFT")
    equal(x, -128 * .8 / 2 + 20); equal(y, -30)
    equal(addon:GetReminderPosition(entry).x, 83, "artwork transform leaves timer XY alone")
    Set(rightID, { mode = "custom", mirrorX = true })
    same(addon.procArtworkFrames[rightID].texture.texCoord, { 0, 1, 0, 1 }, "extra mirror cancels native Right base flip")
    state.proc.cvars.displaySpellActivationOverlays = false
    state:fire("CVAR_UPDATE", "displaySpellActivationOverlays")
    truthy(not frame:IsShown(), "custom artwork respects display CVar")
    equal(next(addon.procSuppressedOverlays), nil, "display disable restores originals")
end)

test("Proc current public SHOW scale changes native geometry without timer offsets", function()
    local _, addon, _, _, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" })
    Show(nil, nil, nil, .5)
    equal(addon.procArtworkFrames[leftID].width, 128 * .8 * .5)
    equal(addon.procArtworkFrames[leftID].height, 256 * .8 * .5)
end)

test("Proc release StopProc disable rebuild and Native switch restore owned overlays", function()
    local env, addon, state, root, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" }); Set(rightID, { mode = "timer" })
    local left = Show()
    local right = root.overlaysInUse[48108][env.Enum.ScreenLocationType.Right]
    Set(leftID, { mode = "native" }); equal(left.texture.alpha, 1)
    Set(leftID, { mode = "custom" }); equal(left.texture.alpha, 0)
    root:ReleaseOverlay(left); equal(left.texture.alpha, 1, "pool release restores native texture")
    addon:StopProc(); equal(right.texture.alpha, 1, "StopProc restores every region")
    equal(next(addon.procSuppressedOverlays), nil)
    addon:ConfigureProc(); left = Show()
    equal(left.texture.alpha, 0)
    addon:GetProcConfig().enabled = false; addon:ConfigureProc()
    equal(left.texture.alpha, 1, "disabled Proc restores")
    addon:GetProcConfig().enabled = true; addon:ConfigureProc(); left = Show()
    state.specID = 64
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player"); state:flushTimers()
    equal(left.texture.alpha, 1, "specialization change restores former owner")
end)

test("Proc same-context definition rebuild restores even removed regions", function()
    local _, addon, _, _, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" }); Set(rightID, { mode = "timer" })
    local overlay = Show()
    local definitions = {}
    for _, definition in ipairs(addon.procDefinitions) do
        if definition.id ~= addon.procByRegion[leftID].id then definitions[#definitions + 1] = definition end
    end
    addon.GetProcDefinitions = function() return definitions end
    addon:ConfigureProc()
    equal(overlay.texture.alpha, 1, "context rebuild restores removed owner")
    equal(next(addon.procSuppressedOverlays), nil, "all former regions restored")
    truthy(not addon.procArtworkFrames[leftID]:IsShown())
end)

test("Proc suppression setter failure restores and failed restore stays owned for retry", function()
    local _, addon, _, root, _, Set, Show = Fixture()
    local overlay = Show()
    overlay.texture.failAlpha = 0
    Set(leftID, { mode = "custom" })
    equal(overlay.texture.alpha, 1)
    truthy(not addon.procArtworkFrames[leftID]:IsShown())
    overlay.texture.failAlpha = nil; addon:RefreshProcAppearance()
    equal(overlay.texture.alpha, 0)
    overlay.texture.failAlpha = 1
    addon:StopProc()
    truthy(addon.procSuppressedOverlays[overlay], "failed restore retains ownership for retry")
    overlay.texture.failAlpha = nil; root:ReleaseOverlay(overlay)
    equal(overlay.texture.alpha, 1)
    equal(next(addon.procSuppressedOverlays), nil)
end)

test("Proc animation reset callback and CVar failures cannot leave duplicate or hidden artwork", function()
    do
        local _, addon, _, _, _, Set, Show = Fixture()
        Set(leftID, { mode = "custom", animation = { entrance = "fade", active = "rotate" } })
        local overlay = Show()
        local frame = addon.procArtworkFrames[leftID]
        frame.texture.CreateAnimationGroup = function() error("animation capability disappeared") end
        for _ = 1, 3 do
            frame.groups.entrance_fade:GetScript("OnFinished")()
            equal(overlay.texture.alpha, 1)
            truthy(not frame:IsShown(), "failed callback hides custom before restoration")
            Show()
        end
        truthy(addon:IsProcQuarantined()); equal(addon:RetryProc(), false)
        Show(); equal(overlay.texture.alpha, 1, "unknown group creation stays fail-open until Reload")
    end
    do
        local _, addon, _, _, _, Set, Show = Fixture()
        Set(leftID, { mode = "custom" })
        local overlay = Show()
        local frame = addon.procArtworkFrames[leftID]
        local setRotation = frame.texture.SetRotation
        frame.texture.SetRotation = function() error("transform setter failed") end
        for _ = 1, 3 do addon:RefreshProcAppearance() end
        equal(overlay.texture.alpha, 1)
        truthy(not frame:IsShown(), "cleanup hides frame even when transform reset fails")
        truthy(addon:IsProcQuarantined())
        frame.texture.SetRotation = setRotation
        Show(); equal(overlay.texture.alpha, 1, "repair alone does not bypass quarantine")
        truthy(addon:RetryProc()); Show(); equal(overlay.texture.alpha, 0)
        equal(addon.procArtworkFrames[leftID], frame, "explicit retry keeps the returned frame")
    end
    do
        local env, addon, _, _, _, Set, Show = Fixture()
        Set(leftID, { mode = "timer" })
        local overlay = Show()
        equal(overlay.texture.alpha, 0)
        local getCVar = env.C_CVar.GetCVar
        env.C_CVar.GetCVar = function() error("public preference reader unavailable") end
        for _ = 1, 3 do addon:RenderProcArtwork() end
        equal(overlay.texture.alpha, 1, "CVar API failure restores all native ownership")
        truthy(addon:IsProcQuarantined())
        env.C_CVar.GetCVar = getCVar
        Show(); equal(overlay.texture.alpha, 1, "recovered preference reader does not auto-resume")
        truthy(addon:RetryProc()); Show(); equal(overlay.texture.alpha, 0)
    end
end)

test("Proc all entrance active and exit presets execute within a reusable animation pool", function()
    local _, addon, state, _, _, Set, Show = Fixture()
    for pass = 1, 2 do
        local before = #state.animations
        for _, entrance in ipairs({ "none", "fade", "scale", "pulse" }) do
            for _, active in ipairs({ "none", "pulse", "breathe", "rotate" }) do
                for _, exit in ipairs({ "none", "fade", "scale" }) do
                    Set(leftID, { mode = "custom", animation = { entrance = entrance, active = active,
                        exit = exit, speed = .25, intensity = 1, direction = "clockwise" } })
                    Show()
                    local frame = addon.procArtworkFrames[leftID]
                    if entrance ~= "none" then frame.groups["entrance_" .. entrance]:GetScript("OnFinished")() end
                    equal(frame.phase, "active")
                    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
                    if exit ~= "none" then frame.groups["exit_" .. exit]:GetScript("OnFinished")() end
                    truthy(not frame:IsShown())
                end
            end
        end
        if pass == 2 then equal(#state.animations, before, "every preset is reused on subsequent cycles") end
    end
    equal(#state.errors, 0)
end)

test("Proc partial artwork and animation initialization failures reuse allocated objects", function()
    local env, addon, state, _, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom" })
    local create = env.CreateFrame
    env.CreateFrame = function(...)
        local frame = create(...)
        local texture = frame.CreateTexture
        frame.CreateTexture = function(owner, ...)
            local result = texture(owner, ...)
            result.SetBlendMode = function() error("texture initialization unavailable") end
            return result
        end
        return frame
    end
    local overlay = Show()
    local frame = addon.procArtworkFrames[leftID]
    local frames, textures = #state.frames, #state.textures
    for _ = 1, 8 do Show() end
    equal(#state.frames, frames, "failed initialization reuses cached frame")
    equal(#state.textures, textures, "failed initialization reuses cached texture")
    equal(overlay.texture.alpha, 1); truthy(not frame:IsShown())
    truthy(addon:IsProcQuarantined(), "repeated setter failures exhaust the session budget")
    env.CreateFrame = create
    frame.texture.SetBlendMode = function(self, value) self.blendMode = value end
    Show(); equal(overlay.texture.alpha, 1, "repair does not automatically resume rendering")
    truthy(addon:RetryProc(), "the cached texture can recover after a setter repair")
    Show(); equal(overlay.texture.alpha, 0)
    equal(addon.procArtworkFrames[leftID], frame)
    equal(#state.frames, frames); equal(#state.textures, textures)
    local createGroup = frame.texture.CreateAnimationGroup
    frame.texture.CreateAnimationGroup = function(owner)
        local group = createGroup(owner)
        local createAnimation = group.CreateAnimation
        group.CreateAnimation = function(self, kind)
            local animation = createAnimation(self, kind)
            animation.SetOrder = function() error("animation initialization unavailable") end
            return animation
        end
        return group
    end
    Set(leftID, { mode = "custom", animation = { entrance = "fade" } })
    local groups = #state.animations
    for _ = 1, 8 do Show() end
    equal(#state.animations, groups, "failed animation initialization reuses group")
    equal(#frame.groups.entrance_fade.animations, 1, "failed animation initialization reuses animation")
    equal(overlay.texture.alpha, 1); truthy(not frame:IsShown())
end)

test("Proc artwork edits cancel pending exit and invalid opacity fails open", function()
    local _, addon, state, _, entry, Set, Show = Fixture()
    Set(leftID, { mode = "custom", animation = { exit = "fade" } })
    local overlay = Show()
    local frame = addon.procArtworkFrames[leftID]
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    truthy(frame.exiting)
    truthy(addon:SetProcRegionAppearance(entry, { rotation = 30 }))
    truthy(not frame.exiting and not frame:IsShown(), "editing cancels old exit lifecycle")
    equal(overlay.texture.alpha, 1, "explicit reconfiguration restores prior ownership")
    overlay = Show()
    equal(overlay.texture.alpha, 0)
    state.proc.cvars.spellActivationOverlayOpacity = h.secret(.6)
    addon:RenderProcArtwork()
    equal(overlay.texture.alpha, 1)
    truthy(not frame:IsShown())
    truthy(addon:GetProcArtworkDiagnostic(entry):find("preferences unavailable"))
end)

test("Proc animations reuse groups reset on configuration and restore on native release", function()
    local _, addon, state, root, _, Set, Show = Fixture()
    Set(leftID, { mode = "custom", animation = { entrance = "fade", active = "pulse", exit = "scale", speed = 2, intensity = .4 } })
    local overlay = Show()
    local frame = addon.procArtworkFrames[leftID]
    equal(frame.phase, "entrance")
    local entrance = frame.groups.entrance_fade
    equal(entrance.animation.duration, .125)
    entrance:GetScript("OnFinished")()
    equal(frame.phase, "active"); truthy(frame.groups.active_pulse:IsPlaying())
    local before = #state.animations
    for _ = 1, 8 do Show(); entrance:GetScript("OnFinished")() end
    equal(#state.animations, before, "repeated SHOW reuses bounded groups")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    equal(frame.phase, "exit"); equal(overlay.texture.alpha, 0)
    frame.groups.exit_scale:GetScript("OnFinished")()
    equal(overlay.texture.alpha, 0, "native fade remains suppressed until its own release")
    truthy(not frame:IsShown())
    root:ReleaseOverlay(overlay); equal(overlay.texture.alpha, 1)
    overlay = Show(); Set(leftID, { mode = "custom", animation = { active = "rotate", direction = "counterclockwise" } })
    truthy(frame.groups.active_rotate:IsPlaying()); equal(frame.groups.active_rotate.animation.degrees, 360)
    Set(leftID, { mode = "native" })
    equal(overlay.texture.alpha, 1)
    for _, group in pairs(frame.groups) do truthy(not group:IsPlaying()) end
    equal(frame.texture.rotation, frame.rotation)
    for _, group in ipairs(state.animations) do equal(group:GetScript("OnUpdate"), nil) end
end)

test("Proc live and TEST use BLEND while retaining artwork color transforms and animation", function()
    local _, addon, state, _, _, Set, Show = Fixture()
    state.proc.cvars.spellActivationOverlayOpacity = "0.6"
    Set(leftID, { mode = "custom", artColor = { r = .2, g = .4, b = .6 },
        alpha = .5, desaturation = .7, rotation = 90, mirrorX = true, mirrorY = true,
        animation = { entrance = "fade", active = "pulse", intensity = .4 } })
    local overlay = Show()
    h.options(addon)
    local nativeWrites = #state.nativeTextureWrites
    truthy(addon:SetPreview("single", leftID))
    local live, preview = addon.procArtworkFrames[leftID], addon.procPreviewArtworkFrames[leftID]
    truthy(live.texture ~= preview.texture, "shared blend defaults preserve independent textures")
    for _, frame in ipairs({ live, preview }) do
        equal(frame.texture.blendMode, "BLEND", "owned artwork uses ordinary alpha blending")
        same(frame.texture.vertexColor, { .2, .4, .6 }, "RGB tint survives the blend default")
        equal(frame.texture.desaturation, .7)
        equal(frame.texture.rotation, math.pi / 2)
        same(frame.texture.texCoord, { 1, 0, 1, 0 })
        equal(frame.phase, "entrance")
        truthy(frame.groups.entrance_fade:IsPlaying())
        frame.groups.entrance_fade:GetScript("OnFinished")()
        equal(frame.phase, "active")
        truthy(frame.groups.active_pulse:IsPlaying(), "native AnimationGroups remain active")
        equal(frame.texture.blendMode, "BLEND", "animation does not replace the blend default")
    end
    equal(live.alpha, .3, "live opacity remains CVar opacity times artwork alpha")
    equal(preview.alpha, .5, "TEST retains its independent sample alpha")
    equal(overlay.texture.alpha, 0, "live replacement retains native suppression")
    equal(#state.nativeTextureWrites, nativeWrites, "TEST and its animation never write native texture state")
end)

test("Proc preview owns separate textures and never changes live suppression", function()
    local _, addon, state, _, entry, Set, Show = Fixture()
    Set(leftID, { mode = "custom", animation = { entrance = "fade", active = "pulse" } })
    local overlay = Show()
    h.options(addon)
    local writes = #state.nativeTextureWrites
    truthy(addon:SetPreview("single", leftID))
    equal(#state.nativeTextureWrites, writes, "TEST start does not touch native textures")
    local preview = addon.procPreviewArtworkFrames[leftID]
    truthy(preview and preview.previewOwned and preview ~= addon.procArtworkFrames[leftID])
    equal(preview.texture.texture, 449490)
    preview.groups.entrance_fade.animation.SetDuration = function() error("unused") end
    local create = preview.texture.CreateAnimationGroup
    preview.texture.CreateAnimationGroup = function() error("TEST active animation failure") end
    preview.groups.entrance_fade:GetScript("OnFinished")()
    equal(#state.nativeTextureWrites, writes, "TEST animation failure cannot restore native ownership")
    preview.texture.CreateAnimationGroup = create
    addon:StopPreview()
    equal(#state.nativeTextureWrites, writes, "TEST stop does not touch native textures")
    equal(overlay.texture.alpha, 0, "live custom remains independent")
    local beforeReads, slots = state.realReads, #state.auraSlots
    addon:RefreshProcAppearance(entry)
    equal(state.realReads, beforeReads); equal(#state.auraSlots, slots)
end)

test("Proc preview Native ignores dormant customization and Timer Only has no artwork", function()
    local _, addon, state, _, _, Set = Fixture()
    h.options(addon)
    Set(leftID, { mode = "native", alpha = .1, scale = 2, rotation = 70,
        offset = { x = 60, y = 90 }, animation = { active = "rotate" } })
    addon:SetPreview("single", leftID)
    local frame = addon.procPreviewArtworkFrames[leftID]
    equal(frame.texture.texture, 449490); equal(frame.alpha, 1)
    equal(frame.width, 128 * .8); equal(frame.texture.rotation, 0)
    equal(frame.appearance.animation.active, "none")
    Set(leftID, { mode = "timer" })
    truthy(not frame:IsShown(), "timer-only TEST hides artwork")
    truthy(addon.previewFrames[leftID]:IsShown(), "timer sample remains")
    equal(#state.nativeTextureWrites, 0)
end)
