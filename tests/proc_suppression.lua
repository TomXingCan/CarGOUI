-- Native lifecycle fixture pinned to wow-ui-source 09b9db7948abc9b9648dedaab51eb0cf3ee67b31:
-- SpellActivationOverlay.lua and its XML template. Alpha animations
-- target the overlay frame; the texture alpha is an independent multiplier.
-- Paint checkpoints run after complete callbacks or explicit animation ticks,
-- never between synchronous native setters and their secure posthooks.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local warlockLeft, warlockRight = "warlock_demonology_demonic_core_left", "warlock_demonology_demonic_core_right"
local arcaneLeft, arcaneRight = "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right"

local function Fixture(arcane, resetTextureAlpha)
    local client = { classToken = arcane and "MAGE" or "WARLOCK", specID = arcane and 62 or 266,
        procKnown = arcane and {} or { [267102] = true }, proc = {}, mobility = { known = {}, spells = {} } }
    if not arcane then client.allowedSpellIDs = { [48020] = true } end
    local env, addon, state = h.login(nil, false, client)
    local root, positions = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType
    local f = { env = env, addon = addon, state = state, root = root, pool = {}, overlays = {},
        writes = {}, paints = {}, nativeDepth = 0, resetTextureAlpha = resetTextureAlpha,
        left = arcane and arcaneLeft or warlockLeft, right = arcane and arcaneRight or warlockRight,
        owner = arcane and 1277420 or 264173, textureID = arcane and 1027131 or 2888300 }
    root.overlaysInUse = {}

    local function NewOverlay()
        local texture = { alpha = 1, writes = {} }
        function texture:SetAlpha(value)
            f.writes[#f.writes + 1] = { texture = self, alpha = value }
            self.writes[#self.writes + 1] = value
            if self.failAlpha == value then error("injected native alpha setter failure") end
            self.alpha = value
        end
        function texture:SetVertexColor(...)
            truthy(f.nativeDepth > 0, "addon must not write native vertex color")
            equal(select("#", ...), 3, "pinned ShowOverlay supplies exactly RGB")
            self.vertexColor = { ... }
            for _, channel in ipairs(self.vertexColor) do
                truthy(type(channel) == "number" and channel >= 0 and channel <= 1,
                    "native ShowOverlay normalizes each RGB channel")
            end
            -- Optional stress injection, not a claim about omitted-alpha engine
            -- behavior: a same-object native refresh may invalidate our gate.
            if f.resetTextureAlpha then self.alpha = 1 end
        end
        for _, method in ipairs({ "GetAlpha", "GetVertexColor", "GetTexture", "SetTexture", "SetTexCoord",
            "SetPoint", "SetSize", "SetWidth", "SetHeight", "CreateAnimationGroup" }) do
            texture[method] = function() error("forbidden native texture access: " .. method) end
        end
        local overlay = { texture = texture, shown = false, frameAlpha = 1, inPlays = 0, outPlays = 0 }
        for _, method in ipairs({ "GetAlpha", "SetAlpha", "Show", "Hide", "SetParent", "CreateAnimationGroup" }) do
            overlay[method] = function() error("addon must not control native overlay frame: " .. method) end
        end
        f.overlays[#f.overlays + 1] = overlay
        return overlay
    end

    function root:ShowOverlay(owner, textureID, position, scale, r, g, b)
        local list = self.overlaysInUse[owner] or {}
        self.overlaysInUse[owner] = list
        local overlay = list[position]
        if not overlay then overlay = table.remove(f.pool, 1) or NewOverlay(); list[position] = overlay end
        overlay.spellID, overlay.position = owner, position
        overlay.nativeTextureID, overlay.nativeScale = textureID, scale
        f.nativeDepth = f.nativeDepth + 1
        overlay.texture:SetVertexColor(r / 255, g / 255, b / 255)
        f.nativeDepth = f.nativeDepth - 1
        -- Stop native animOut before Show; OnShow starts animIn only if hidden.
        if overlay.nativePhase == "out" then overlay.nativePhase, overlay.frameAlpha = nil, 1 end
        if not overlay.shown then
            overlay.nativePhase, overlay.frameAlpha = "in", 0
            overlay.inDuration, overlay.inPlays = .2, overlay.inPlays + 1
        end
        overlay.shown = true
    end
    function root:ReleaseOverlay(overlay)
        -- The pool reset hides the object before the addon release posthook.
        overlay.shown, overlay.nativePhase = false, nil
        local list = self.overlaysInUse[overlay.spellID]
        if list and list[overlay.position] == overlay then list[overlay.position] = nil end
        f.pool[#f.pool + 1] = overlay
    end
    function f:Entry(id)
        for _, entry in ipairs(self.addon.procByRegion[id].regions) do if entry.id == id then return entry end end
        error("missing fixture region " .. id)
    end
    function f:Set(id, appearance)
        local regions = self.addon:GetProcConfig().regions
        regions[id] = regions[id] or {}
        regions[id].appearance = h.copy(appearance)
        self.addon:RefreshProcAppearance(self:Entry(id))
    end
    function f:Overlay(owner, side)
        return self.root.overlaysInUse[owner or self.owner][positions[side or "Left"]]
    end
    function f:Show(owner, textureID, eventFirst, rgb)
        owner, textureID = owner or self.owner, textureID or self.textureID
        -- false injects missing evidence only into the addon event callback.
        -- The native function still receives valid byte RGB: its pinned source
        -- divides all three channels before calling SetVertexColor.
        local nativeRGB = rgb or { 255, 128, 64 }
        local eventRGB = rgb == false and {} or nativeRGB
        local function Event()
            self.state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", owner, textureID, positions.LeftRight, 1, unpack(eventRGB))
        end
        if eventFirst then Event() end
        -- Pinned ShowAllOverlays expands LeftRight in this order.
        self.root:ShowOverlay(owner, textureID, positions.Left, 1, unpack(nativeRGB))
        self.root:ShowOverlay(owner, textureID, positions.Right, 1, unpack(nativeRGB))
        if not eventFirst then Event() end
        return self:Overlay(owner, "Left"), self:Overlay(owner, "Right")
    end
    function f:Hide(owner, eventFirst)
        local function Event() self.state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", owner) end
        if eventFirst then Event() end
        for id, list in pairs(self.root.overlaysInUse) do
            if owner == nil or owner == id then
                for _, overlay in pairs(list) do
                    if overlay.nativePhase ~= "out" then
                        overlay.nativePhase, overlay.frameAlpha = "out", 1
                        overlay.outDuration, overlay.outPlays = .1, overlay.outPlays + 1
                    end
                end
            end
        end
        if not eventFirst then Event() end
    end
    function f:Tick(overlay, progress)
        local phase = overlay.nativePhase
        if phase == "in" then overlay.frameAlpha = progress
        elseif phase == "out" then overlay.frameAlpha = 1 - progress end
        if progress == 1 then
            if phase == "out" then self.root:ReleaseOverlay(overlay) else overlay.nativePhase = nil end
        end
    end
    function f:Paint(overlay)
        local value = overlay.shown and overlay.frameAlpha * overlay.texture.alpha or 0
        self.paints[#self.paints + 1] = value
        return value
    end
    function f:Gate(overlay, expected, label)
        equal(overlay.texture.alpha, expected, label .. " texture gate")
        if expected == 0 then equal(self:Paint(overlay), 0, label .. " native paint")
        else equal(self:Paint(overlay), overlay.shown and overlay.frameAlpha or 0, label .. " original paint") end
    end
    function f:FinishOwned(id, phase)
        local frame = self.addon.procArtworkFrames[id]
        local group = frame.groups[phase]
        group.playing = false
        group:GetScript("OnFinished")()
    end
    env.C_CVar.SetCVar = function() error("presentation cannot write global CVar") end
    env.SetCVar = env.C_CVar.SetCVar
    truthy(addon:InstallProcArtworkHooks(), "complete native lifecycle hooks installed")
    return f
end

test("PROC SUPPRESSION Demonic Core opposite-side modes survive native frame fade checkpoints", function()
    for _, modes in ipairs({ { "custom", "native" }, { "native", "custom" }, { "custom", "timer" }, { "timer", "custom" } }) do
        for _, eventFirst in ipairs({ true, false }) do
            local f = Fixture()
            f:Set(f.left, { mode = modes[1] }); f:Set(f.right, { mode = modes[2] })
            h.putAura(f.state, 264173, 20, 2)
            local left, right = f:Show(nil, nil, eventFirst)
            same(left.texture.vertexColor, { 1, 128 / 255, 64 / 255 }, "native RGB uses normalized vertex channels")
            for _, progress in ipairs({ 0, .25, .5, .9, 1 }) do
                f:Tick(left, progress); f:Tick(right, progress)
                f:Gate(left, modes[1] == "native" and 1 or 0, "left at native entrance " .. progress)
                f:Gate(right, modes[2] == "native" and 1 or 0, "right at native entrance " .. progress)
            end
            for index, id in ipairs({ f.left, f.right }) do
                local frame = f.addon.procArtworkFrames and f.addon.procArtworkFrames[id]
                equal(not not (frame and frame:IsShown()), modes[index] == "custom", "only Custom paints owned artwork")
                truthy(h.procText(f.addon, f.state, id) ~= "", "all modes preserve the native-owned timer")
            end
            equal(left.inDuration, .2); equal(right.inDuration, .2)
            equal(f.state.realReads, 0, "no addon aura/cooldown read")
        end
    end
end)

test("PROC SUPPRESSION identical repeated SHOW preserves owned entrance and active phases", function()
    for _, eventFirst in ipairs({ true, false }) do
        local f = Fixture()
        f:Set(f.left, { mode = "custom", animation = { entrance = "fade", active = "pulse" } })
        local left, right = f:Show(nil, nil, eventFirst)
        local frame = f.addon.procArtworkFrames[f.left]
        local entrance = frame.groups.entrance_fade
        equal(entrance.plays, 1, "first complete SHOW plays one entrance")
        local allocations = #f.state.animations
        for index = 1, 4 do
            f:Tick(left, .25); f:Tick(right, .25)
            f:Show(nil, nil, eventFirst)
            equal(entrance.plays, 1, "identical SHOW must not restart owned entrance " .. index)
            equal(frame.phase, "entrance")
            f:Gate(left, 0, "repeated SHOW"); f:Gate(right, 1, "untouched sibling")
        end
        f:FinishOwned(f.left, "entrance_fade")
        local active = frame.groups.active_pulse
        equal(active.plays, 1)
        for _ = 1, 4 do f:Show(nil, nil, eventFirst) end
        equal(entrance.plays, 1); equal(active.plays, 1, "active phase is not restarted by repeated SHOW")
        equal(frame.phase, "active"); equal(left.inPlays, 1, "native OnShow did not repeat")
        equal(#f.state.animations, allocations + 1, "only the first active group was allocated")
    end
end)

test("PROC SUPPRESSION nil HIDE retains native gate through both fades and safely resumes SHOW", function()
    for _, eventFirst in ipairs({ true, false }) do
        local f = Fixture()
        f:Set(f.left, { mode = "custom", animation = { entrance = "fade", exit = "fade" } })
        f:Set(f.right, { mode = "timer" })
        local left, right = f:Show(nil, nil, eventFirst)
        f:Tick(left, 1); f:Tick(right, 1); f:FinishOwned(f.left, "entrance_fade")
        f:Hide(nil, eventFirst)
        local frame = f.addon.procArtworkFrames[f.left]
        local exit, staleExit = frame.groups.exit_fade, frame.groups.exit_fade:GetScript("OnFinished")
        equal(left.outDuration, .1); equal(exit.plays, 1)
        for _, progress in ipairs({ 0, .25, .5, .9 }) do
            f:Tick(left, progress); f:Tick(right, progress)
            f:Gate(left, 0, "custom native fade"); f:Gate(right, 0, "Timer Only native fade")
            f:Hide(nil, eventFirst)
            equal(exit.plays, 1, "duplicate nil HIDE does not restart owned exit")
        end
        f:Show(nil, nil, eventFirst)
        truthy(frame.active and not frame.exiting, "SHOW during native fade cancels owned exit")
        staleExit()
        truthy(frame:IsShown() and frame.active, "stale exit callback cannot hide the replacement generation")
        f:Gate(left, 0, "SHOW during native fade")
        f:Hide(nil, eventFirst); f:FinishOwned(f.left, "exit_fade")
        truthy(not frame:IsShown(), "owned exit completes independently")
        f:Tick(left, .5); f:Gate(left, 0, "native fade after custom exit completed")
        f:Tick(left, 1); f:Tick(right, 1)
        f:Gate(left, 1, "pool release"); equal(f:Paint(left), 0, "restored pooled texture is hidden")
        local pooledLeft, pooledRight = left, right
        left, right = f:Show(nil, nil, eventFirst)
        equal(left, pooledLeft); equal(right, pooledRight, "fresh SHOW reuses both released native objects")
        f:Tick(left, .5); f:Gate(left, 0, "fresh SHOW after release")
        f:Hide(f.owner, eventFirst)
        truthy(frame.exiting, "final owner-specific HIDE starts owned exit on reused overlay")
        for _, progress in ipairs({ 0, .25, .5, .9 }) do
            f:Tick(left, progress); f:Tick(right, progress)
            f:Gate(left, 0, "reused Custom owner-specific fade")
            f:Gate(right, 0, "reused Timer Only owner-specific fade")
        end
        f:Tick(left, 1); f:Tick(right, 1)
        f:Gate(left, 1, "reused Custom release"); f:Gate(right, 1, "reused Timer Only release")
        equal(f:Paint(left), 0); equal(f:Paint(right), 0, "both restored pooled textures are hidden")
        f:FinishOwned(f.left, "exit_fade")
        truthy(not frame:IsShown(), "owned exit finishes after final native release")
        equal(next(f.addon.procSuppressedOverlays), nil, "final release leaves no suppression owner")
    end
end)

test("PROC SUPPRESSION alternate Arcane owners keep old native fade gated until release", function()
    for _, hideFirst in ipairs({ true, false }) do
        for _, eventFirst in ipairs({ true, false }) do
            local f = Fixture(true)
            f:Set(f.left, { mode = "custom" }); f:Set(f.right, { mode = "timer" })
            local oldLeft, oldRight = f:Show(1277420, 1027131, eventFirst)
            f:Tick(oldLeft, 1); f:Tick(oldRight, 1)
            if hideFirst then f:Hide(1277420, eventFirst) end
            local newLeft, newRight = f:Show(1277421, 1027132, eventFirst)
            if not hideFirst then f:Hide(1277420, eventFirst) end
            for _, progress in ipairs({ 0, .25, .5, .9 }) do
                f:Tick(oldLeft, progress); f:Tick(oldRight, progress)
                f:Tick(newLeft, progress); f:Tick(newRight, progress)
                f:Gate(oldLeft, 0, "superseded Custom source fading beside replacement")
                f:Gate(oldRight, 0, "superseded Timer Only source fading beside replacement")
                f:Gate(newLeft, 0, "current Custom source"); f:Gate(newRight, 0, "current Timer Only source")
            end
            local frame = f.addon.procArtworkFrames[f.left]
            equal(frame.texture.texture, 1027132, "latest shown source supplies the artwork")
            f:Tick(oldLeft, 1); f:Tick(oldRight, 1)
            f:Gate(oldLeft, 1, "old source release")
            truthy(frame:IsShown() and frame.active, "late old release cannot hide new owner")
            equal(frame.nativeOverlay, newLeft); f:Gate(newLeft, 0, "new owner after old release")
        end
    end
end)

test("PROC SUPPRESSION pool reuse restores Native unrelated owners and opposite-side ownership", function()
    local f = Fixture()
    f:Set(f.left, { mode = "custom" }); f:Set(f.right, { mode = "timer" })
    local left, right = f:Show()
    f.root:ReleaseOverlay(left); f.root:ReleaseOverlay(right)
    f:Gate(left, 1, "released left"); f:Gate(right, 1, "released right")
    local unrelatedLeft, unrelatedRight = f:Show(999999, 2888300)
    equal(unrelatedLeft, left); equal(unrelatedRight, right, "native pool really reuses the same objects")
    f:Tick(unrelatedLeft, .5); f:Gate(unrelatedLeft, 1, "unrelated owner reuse")
    equal(next(f.addon.procSuppressedOverlays), nil, "no stale owner follows unrelated pool reuse")
    f.root:ReleaseOverlay(unrelatedLeft); f.root:ReleaseOverlay(unrelatedRight)
    f:Set(f.left, { mode = "native" }); f:Set(f.right, { mode = "custom" })
    local reusedLeft, reusedRight = f:Show()
    equal(reusedLeft.texture, left.texture); equal(reusedRight.texture, right.texture)
    f:Tick(reusedLeft, .5); f:Tick(reusedRight, .5)
    f:Gate(reusedLeft, 1, "left switched to Native"); f:Gate(reusedRight, 0, "right switched to Custom")
end)

test("PROC SUPPRESSION texture-refresh stress injection reasserts gate without replaying entrance", function()
    for _, eventFirst in ipairs({ true, false }) do
        local f = Fixture(false, true)
        f:Set(f.left, { mode = "custom", animation = { entrance = "fade" } })
        f:Set(f.right, { mode = "timer" })
        local left, right = f:Show(nil, nil, eventFirst)
        local entrance = f.addon.procArtworkFrames[f.left].groups.entrance_fade
        for _ = 1, 4 do
            f:Tick(left, .5); f:Tick(right, .5)
            f:Show(nil, nil, eventFirst)
            f:Gate(left, 0, "posthook repairs injected texture refresh")
            f:Gate(right, 0, "Timer Only posthook repairs injected texture refresh")
            equal(entrance.plays, 1, "stress refresh does not restart entrance")
        end
    end
end)

test("PROC SUPPRESSION configuration CVar disable and spec cleanup restore only owned native textures", function()
    local f = Fixture()
    f:Set(f.left, { mode = "custom" }); f:Set(f.right, { mode = "timer" })
    local left, right = f:Show()
    local unrelated = f:Show(999999, 2888300)
    f:Set(f.left, { mode = "native" })
    f:Gate(left, 1, "Custom to Native"); f:Gate(right, 0, "unchanged Timer Only")
    f:Set(f.left, { mode = "custom", mirrorX = true, artColor = { r = .2, g = .3, b = .4 }, assetKey = "blizzard_449490" })
    f:Gate(left, 0, "Custom transform edit")
    equal(f.addon.procArtworkFrames[f.left].texture.texture, 449490, "selected asset changes only owned artwork")
    equal(left.nativeTextureID, 2888300, "native texture identity remains untouched")
    f.state.proc.cvars.displaySpellActivationOverlays = false
    f.state:fire("CVAR_UPDATE", "displaySpellActivationOverlays")
    f:Gate(left, 1, "CVar disabled"); f:Gate(right, 1, "CVar disabled Timer Only")
    f.state.proc.cvars.displaySpellActivationOverlays = true
    f.state:fire("CVAR_UPDATE", "displaySpellActivationOverlays")
    f:Show(); f:Gate(left, 0, "CVar enabled")
    f.addon:GetProcConfig().enabled = false; f.addon:ConfigureProc()
    f:Gate(left, 1, "Proc disabled"); f:Gate(right, 1, "Proc disabled Timer Only")
    f.addon:GetProcConfig().enabled = true; f.addon:ConfigureProc(); f:Show()
    f.state.specID = 265
    f.state:fire("PLAYER_SPECIALIZATION_CHANGED", "player"); f.state:flushTimers()
    f:Gate(left, 1, "specialization cleanup"); f:Gate(right, 1, "specialization cleanup Timer Only")
    equal(#unrelated.texture.writes, 0, "unrelated native texture is never written")
end)

test("PROC SUPPRESSION preview and explicit custom RGB never acquire native color ownership", function()
    local f = Fixture()
    f:Set(f.left, { mode = "custom", artColor = { r = .2, g = .4, b = .6 } })
    f:Set(f.right, { mode = "custom" })
    local left, right = f:Show(nil, nil, false, false)
    f:Tick(left, .5); f:Tick(right, .5)
    f:Gate(left, 0, "explicit RGB works without event RGB")
    f:Gate(right, 1, "missing event RGB fails open despite valid native hook RGB")
    same(f.addon.procArtworkFrames[f.left].texture.vertexColor, { .2, .4, .6 })
    h.options(f.addon)
    local writes = #f.writes
    truthy(f.addon:SetPreview("single", f.left))
    local preview = f.addon.procPreviewArtworkFrames[f.left]
    truthy(preview and preview:IsShown())
    truthy(preview.texture ~= f.addon.procArtworkFrames[f.left].texture)
    equal(#f.writes, writes, "starting isolated preview writes no native texture")
    f.addon:StopPreview()
    equal(#f.writes, writes, "stopping isolated preview writes no native texture")
    equal(f.state.realReads, 0)
end)

test("PROC SUPPRESSION failed acquisition fails open and failed restore retains retry ownership", function()
    do
        local f = Fixture()
        local left = f:Show(); f:Tick(left, .5)
        left.texture.failAlpha = 0
        f:Set(f.left, { mode = "custom" })
        f:Gate(left, 1, "failed suppression")
        truthy(not f.addon.procArtworkFrames[f.left]:IsShown(), "failed suppression hides replacement")
        left.texture.failAlpha = nil
        f.addon:RefreshProcAppearance(f:Entry(f.left)); f:Gate(left, 0, "recoverable setter repair")
        left.texture.failAlpha = 1
        f.addon:StopProc()
        truthy(f.addon.procSuppressedOverlays[left], "failed restore retains exact owner")
        left.texture.failAlpha = nil; f.root:ReleaseOverlay(left)
        f:Gate(left, 1, "release retries retained restore")
        equal(next(f.addon.procSuppressedOverlays), nil)
    end
    do
        local f = Fixture()
        f:Set(f.left, { mode = "custom" })
        local left = f:Show(); f:Tick(left, .5)
        local frame = f.addon.procArtworkFrames[f.left]
        frame.texture.SetTexture = function() error("injected owned draw failure") end
        f.addon:RefreshProcAppearance(f:Entry(f.left))
        f:Gate(left, 1, "owned draw failure"); truthy(not frame:IsShown())
    end
end)

test("PROC SUPPRESSION quarantine restores native gates and stale callbacks cannot regain ownership", function()
    local f = Fixture()
    f:Set(f.left, { mode = "custom", animation = { entrance = "fade", active = "pulse" } })
    f:Set(f.right, { mode = "timer" })
    local left, right = f:Show()
    local unrelated = f:Show(999999, 2888300)
    local frame = f.addon.procArtworkFrames[f.left]
    local stale = frame.groups.entrance_fade:GetScript("OnFinished")
    local setter = frame.texture.SetTexture
    frame.texture.SetTexture = function() error("injected repeated owned draw failure") end
    for _ = 1, 3 do f.addon:RenderProcArtwork() end
    truthy(f.addon:IsProcQuarantined())
    f:Gate(left, 1, "quarantine Custom restore"); f:Gate(right, 1, "quarantine Timer Only restore")
    stale(); f:Show()
    truthy(not frame:IsShown(), "stale animation and public events stay quarantined")
    f:Gate(left, 1, "no automatic ownership resume")
    equal(#unrelated.texture.writes, 0, "quarantine never touches unrelated textures")
    frame.texture.SetTexture = setter
    truthy(f.addon:RetryProc()); f:Show(); f:Gate(left, 0, "explicit retry reconfigures")
    equal(f.addon.procArtworkFrames[f.left], frame, "retry reuses the bounded artwork pool")
end)

test("PROC SUPPRESSION inactive native SHOW restores retained cleanup owner without resuming Proc", function()
    for _, quarantine in ipairs({ false, true }) do
        local f = Fixture()
        f:Set(f.left, { mode = "custom", animation = { entrance = "fade" } })
        local old = f:Show()
        f:Tick(old, 1)
        local frame = f.addon.procArtworkFrames[f.left]
        local entrance = frame.groups.entrance_fade
        old.texture.failAlpha = 1
        if quarantine then f.addon:QuarantineProc("artwork")
        else f.addon:GetProcConfig().enabled = false; f.addon:ConfigureProc() end
        truthy(f.addon.procSuppressedOverlays[old], "failed cleanup retains the original texture owner")
        f.root:ReleaseOverlay(old)
        equal(old.texture.alpha, 0, "failed pool restore leaves the texture gate unchanged")
        truthy(f.addon.procSuppressedOverlays[old], "failed Release preserves cleanup authority")
        equal(f:Paint(old), 0, "native pool has hidden the failed-restore object")
        equal(f.addon.procTracking, false)
        equal(f.addon:IsProcQuarantined(), quarantine, "disabled and quarantined cases stay distinct")
        truthy(not frame:IsShown(), "cleanup has hidden custom artwork despite the failed native setter")

        old.texture.failAlpha = nil
        local generation = f.addon:GetProcSafetyGeneration()
        local frames, textures, animations = #f.state.frames, #f.state.textures, #f.state.animations
        local plays, writes = entrance.plays, #f.writes
        local reused = f:Show(999999, 2888300)
        equal(reused, old, "unrelated owner reuses the same failed-restore object")
        equal(reused.spellID, 999999)
        f:Tick(reused, .5)
        f:Gate(reused, 1, "inactive native SHOW completes retained restoration")
        equal(f:Paint(reused), .5, "unrelated native entrance is visible again")
        equal(next(f.addon.procSuppressedOverlays), nil, "successful recovery clears the retained owner")
        equal(next(f.addon.procNativeOverlays), nil, "cleanup-only hook cannot register a new native owner")
        equal(#f.writes, writes + 1, "reuse performs only the outstanding restore")
        f:Show(999999, 2888300)
        equal(#f.writes, writes + 1, "repeated unrelated SHOW has no suppression authority")
        equal(f.addon.procTracking, false, "native pool reuse cannot restart Proc tracking")
        equal(f.addon:IsProcQuarantined(), quarantine)
        equal(f.addon:GetProcSafetyGeneration(), generation, "recovery does not reconfigure the session")
        equal(f.addon.procArtworkFrames[f.left], frame)
        truthy(not frame:IsShown() and not frame.active, "custom artwork stays inactive")
        equal(entrance.plays, plays, "cleanup-only recovery does not replay custom animation")
        equal(#f.state.frames, frames); equal(#f.state.textures, textures); equal(#f.state.animations, animations)
        equal(#f.state.errors, 0)
    end
end)

local tintBase = { r = .25, g = .5, b = .75 }
local tintBlue = { r = .15, g = .35, b = .95 }

local function TintFixture(eventFirst, draftBeforeOverlap, missingEventColor)
    local f = Fixture(true)
    f:Set(f.left, { mode = "custom", artColor = tintBase, desaturation = .4, alpha = .6,
        animation = { entrance = "fade", active = "breathe", exit = "fade" } })
    local panel = h.options(f.addon)
    f.addon:SelectOptionsCategory("proc")
    panel.selectedProcEntry = f.left; f.addon:RefreshOptions()
    f.entry = f:Entry(f.left)
    truthy(f.addon:SetProcRegionColor(f.entry, { r = .7, g = .4, b = .2 }))
    truthy(f.addon:UpdateSettings({ reminders = { [f.left] = { position = { x = 37, y = -91 } } } }))
    truthy(f.addon:SetPreview("single", f.left))
    if draftBeforeOverlap then
        truthy(f.addon:OpenProcColorPicker(f.entry, "artwork"))
        f.state:pickerChange(tintBlue.r, tintBlue.g, tintBlue.b)
    end
    f.old = f:Show(1277420, 1027131, eventFirst)
    f:Tick(f.old, 1)
    f:Hide(1277420, eventFirst)
    local eventColor
    if missingEventColor then eventColor = false end
    f.current, f.sibling = f:Show(1277421, 1027132, eventFirst, eventColor)
    f:Tick(f.old, 0); f:Tick(f.current, .5); f:Tick(f.sibling, .5)
    f.live, f.sample = f.addon.procArtworkFrames[f.left], f.addon.procPreviewArtworkFrames[f.left]
    function f:CheckTintGate(stage, progress)
        self:Tick(self.old, progress or .5)
        self:Gate(self.old, 0, stage .. " retired native fade")
        self:Gate(self.current, 0, stage .. " current native source")
        self:Gate(self.sibling, 1, stage .. " Native sibling")
        truthy(self.live:IsShown() and self.live.active, stage .. " owned replacement remains active")
    end
    return f
end

test("PROC SUPPRESSION blue green purple tint drafts and numeric transforms retain fading source ownership", function()
    for _, eventFirst in ipairs({ true, false }) do
        local f = TintFixture(eventFirst)
        local liveGroup, sampleGroup = f.live.groups.entrance_fade, f.sample.groups.entrance_fade
        local liveFinish, sampleFinish = liveGroup:GetScript("OnFinished"), sampleGroup:GetScript("OnFinished")
        local livePlays, samplePlays = liveGroup.plays, sampleGroup.plays
        local frames, textures, groups, slots = #f.state.frames, #f.state.textures, #f.state.animations, #f.state.auraSlots
        local writes, saved = #f.writes, h.copy(f.addon.db)
        truthy(f.addon:OpenProcColorPicker(f.entry, "artwork"))
        f:CheckTintGate("picker opened", 0)
        same(f.addon.db, saved, "opening the native picker creates only a presentation draft")
        for index, color in ipairs({ tintBlue, { r = .2, g = .9, b = .35 }, { r = .65, g = .2, b = .9 } }) do
            local saturation, alpha = ({ 0, .45, 1 })[index], ({ .3, .65, 1 })[index]
            truthy(f.addon:SetProcRegionAppearance(f.entry, { desaturation = saturation, alpha = alpha,
                animation = { speed = 1 + index * .2, intensity = index * .2 } },
                { skipOptionsRefresh = true, continuousAppearance = true }))
            saved = h.copy(f.addon.db)
            f.state:pickerChange(color.r, color.g, color.b)
            f:CheckTintGate("color draft " .. index, index * .2)
            for _, owned in ipairs({ f.live, f.sample }) do
                same(owned.texture.vertexColor, { color.r, color.g, color.b })
                equal(owned.texture.desaturation, saturation); equal(owned.alpha, alpha)
            end
            same(f.addon.db, saved, "RGB draft never enters SavedVariables")
            same(f.addon:GetProcRegionAppearance(f.entry).artColor, tintBase)
            equal(liveGroup.plays, livePlays); equal(sampleGroup.plays, samplePlays)
            equal(liveGroup:GetScript("OnFinished"), liveFinish); equal(sampleGroup:GetScript("OnFinished"), sampleFinish)
        end
        f.env.ColorPickerFrame.Footer.CancelButton:Click()
        f:CheckTintGate("cancel restores saved tint", .8)
        same(f.live.texture.vertexColor, { tintBase.r, tintBase.g, tintBase.b })
        same(f.addon.db, saved, "Cancel retains committed numeric edits but never commits its tint")
        same(f.addon:GetProcRegionColor(f.entry), { r = .7, g = .4, b = .2 })
        same(f.addon:GetReminderPosition(f.entry), { anchor = "CENTER", x = 37, y = -91 })
        equal(#f.writes, writes, "color and parameter edits do not release or retake native suppression")
        equal(#f.state.frames, frames); equal(#f.state.textures, textures); equal(#f.state.animations, groups)
        equal(#f.state.auraSlots, slots); equal(f.state.realReads, 0)
        f:Tick(f.old, 1); f:Gate(f.old, 1, "retired tint source release")
        equal(f:Paint(f.old), 0); f:Gate(f.current, 0, "current tint survives old release")
    end
end)

for _, action in ipairs({ "Cancel", "Okay" }) do
    test("PROC SUPPRESSION tint " .. action .. " preserves a native owner that started fading during the picker session", function()
        for _, eventFirst in ipairs({ true, false }) do
            local f = TintFixture(eventFirst, true)
            local before, plays = h.copy(f.addon.db), f.live.groups.entrance_fade.plays
            f:CheckTintGate("before native " .. action, .25)
            f.env.ColorPickerFrame.Footer[action .. "Button"]:Click()
            f:CheckTintGate("after native " .. action, .75)
            local color = action == "Okay" and tintBlue or tintBase
            same(f.addon:GetProcRegionAppearance(f.entry).artColor, color)
            same(f.live.texture.vertexColor, { color.r, color.g, color.b })
            same(f.sample.texture.vertexColor, { color.r, color.g, color.b })
            if action == "Cancel" then same(f.addon.db, before) end
            equal(f.addon.procArtworkColorPreview, nil); equal(f.addon.procColorPickerSession, nil)
            equal(f.live.groups.entrance_fade.plays, plays, "finishing tint does not replay an entrance")
            f:Tick(f.old, 1); f:Gate(f.old, 1, "old owner releases after " .. action)
            f:Gate(f.current, 0, "new owner survives late release")
        end
    end)
end

test("PROC SUPPRESSION all animation preset changes restart owned motion without restoring a retired native fade", function()
    for _, option in ipairs({ { "entrance", "pulse" }, { "active", "rotate" }, { "exit", "scale" } }) do
        for _, eventFirst in ipairs({ true, false }) do
            local f = TintFixture(eventFirst)
            local oldGroup = f.live.groups.entrance_fade
            local stale = oldGroup:GetScript("OnFinished")
            local patch = { animation = { [option[1]] = option[2] }, artColor = tintBlue }
            truthy(f.addon:SetProcRegionAppearance(f.entry, patch))
            f:CheckTintGate(option[1] .. " preset changed", .25)
            local entrance = f.live.appearance.animation.entrance
            local currentGroup = f.live.groups["entrance_" .. entrance]
            local plays, token = currentGroup.plays, f.live.playToken
            truthy(currentGroup:GetScript("OnFinished") ~= stale, "changed preset creates a new owned lifecycle callback")
            stale(); equal(f.live.phase, "entrance", "previous preset callback cannot advance the new lifecycle")
            truthy(f.addon:SetProcRegionAppearance(f.entry, patch))
            equal(currentGroup.plays, plays, "unchanged preset and tint do not replay the entrance")
            equal(f.live.playToken, token)
            f:CheckTintGate(option[1] .. " preset unchanged", .75)
            f:FinishOwned(f.left, "entrance_" .. entrance)
            equal(f.live.phase, "active")
            f:Tick(f.old, 1); f:Gate(f.old, 1, "preset old owner release")
            f:Gate(f.current, 0, "preset current native remains suppressed")
            truthy(f.addon:SetProcRegionAppearance(f.entry, { mode = "native" }))
            f:Gate(f.current, 1, "mode change still releases preset ownership")
            truthy(not f.live:IsShown())
        end
    end
    do
        local f = TintFixture(true)
        f:Hide(1277421, true)
        truthy(f.live.exiting, "HIDE begins the owned exit before its preset changes")
        local stale = f.live.groups.exit_fade:GetScript("OnFinished")
        truthy(f.addon:SetProcRegionAppearance(f.entry, { animation = { exit = "scale" } }))
        truthy(not f.live:IsShown() and not f.live.active, "hidden preset changes settle owned exit motion")
        f:Tick(f.old, .5); f:Tick(f.current, .5)
        f:Gate(f.old, 0, "hidden preset retains retired native fade")
        f:Gate(f.current, 0, "hidden preset retains current native fade")
        stale(); truthy(not f.live:IsShown() and not f.live.active, "stale exit cannot revive hidden artwork")
        truthy(f.sample:IsShown(), "hidden live exit does not stop the independent sample")
        f:Tick(f.old, 1); f:Tick(f.current, 1)
        f:Gate(f.old, 1, "hidden preset retired release")
        f:Gate(f.current, 1, "hidden preset current release")
    end
end)

test("PROC SUPPRESSION clearing artColor without public event RGB fails open only for its current source", function()
    local f = TintFixture(true, false, true)
    truthy(f.addon:SetProcRegionAppearance(f.entry, { artColor = false }))
    f:Tick(f.old, .25); f:Gate(f.old, 0, "event-color fallback retains retired source")
    f:Gate(f.current, 1, "missing current public RGB fails open")
    truthy(not f.live:IsShown()); equal(f.addon:GetProcRegionAppearance(f.entry).artColor, nil)
    truthy(f.addon:GetProcArtworkDiagnostic(f.entry):find("native%-color%-unavailable"))
    truthy(f.addon:SetProcArtworkColorPreview(f.entry, tintBlue))
    f:CheckTintGate("explicit temporary color recovers current source", .5)
    truthy(f.addon:SetProcArtworkColorPreview(f.entry, nil))
    f:Tick(f.old, .75); f:Gate(f.old, 0, "cancel restores missing-evidence fallback")
    f:Gate(f.current, 1, "cancel does not retain stale draft RGB")
    truthy(f.sample:IsShown(), "the independent TEST sample can still use its public sample color")
    f:Tick(f.old, 1); f:Gate(f.old, 1, "missing-color retired release")
end)

test("PROC SUPPRESSION tint hints never bypass source mode or artwork reset cleanup", function()
    for _, change in ipairs({ "mode", "asset", "reset" }) do
        local f = TintFixture(true)
        local patch = change == "mode" and { mode = "native", artColor = tintBlue }
            or change == "asset" and { assetKey = "blizzard_449493", artColor = tintBlue } or false
        truthy(f.addon:UpdateSettings({ proc = { regions = { [f.left] = { appearance = patch } } } },
            { skipOptionsRefresh = true, continuousAppearance = true }))
        f:Tick(f.old, .5); f:Gate(f.old, 1, change .. " retains full retired-owner restoration")
        f:Gate(f.current, change == "asset" and 0 or 1, change .. " current-owner cleanup")
        if change == "asset" then equal(f.live.texture.texture, 449493)
        else truthy(not f.live:IsShown()) end
    end
end)

test("PROC SUPPRESSION tint failures retain failed owners and never resume inactive or quarantined Proc", function()
    do
        local f = TintFixture(true)
        local setter = f.live.texture.SetVertexColor
        f.live.texture.SetVertexColor = function() error("injected owned tint renderer failure") end
        f.old.texture.failAlpha = 1
        truthy(f.addon:SetProcRegionAppearance(f.entry, { artColor = tintBlue }))
        truthy(not f.live:IsShown(), "tint fault hides the custom renderer")
        truthy(f.addon.procSuppressedOverlays[f.old], "failed old-owner restoration remains owned")
        f:Gate(f.old, 0, "failed restore gate remains tracked"); f:Gate(f.current, 1, "genuine tint fault fails open")
        f.old.texture.failAlpha = nil; f:Tick(f.old, 1)
        f:Gate(f.old, 1, "release retries failed tint cleanup")
        equal(f.addon.procSuppressedOverlays[f.old], nil)
        f.live.texture.SetVertexColor = setter
    end
    for _, quarantine in ipairs({ false, true }) do
        local f = TintFixture(true)
        if quarantine then f.addon:QuarantineProc("artwork")
        else f.addon:GetProcConfig().enabled = false; f.addon:ConfigureProc() end
        local frames, groups = #f.state.frames, #f.state.animations
        truthy(f.addon:SetProcRegionAppearance(f.entry, { artColor = tintBlue }))
        truthy(f.addon:SetProcRegionAppearance(f.entry, { animation = { entrance = "pulse", active = "rotate", exit = "scale" } }))
        f.addon:SetProcArtworkColorPreview(f.entry, tintBlue)
        f.addon:SetProcArtworkColorPreview(f.entry, nil)
        f:Gate(f.old, 1, "inactive retired source"); f:Gate(f.current, 1, "inactive current source")
        truthy(not f.live:IsShown() and not f.sample:IsShown())
        equal(next(f.addon.procSuppressedOverlays), nil); equal(f.addon.procTracking, false)
        equal(f.addon:IsProcQuarantined(), quarantine)
        equal(#f.state.frames, frames); equal(#f.state.animations, groups)
    end
end)
