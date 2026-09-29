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
