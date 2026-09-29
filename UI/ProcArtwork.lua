local _, addon = ...

local function Public(value)
    return issecretvalue and not issecretvalue(value)
end
local function Number(value, low, high)
    return Public(value) and type(value) == "number" and value == value and value >= low and value <= high
end

-- SHOW arguments use byte RGB in the audited Retail public lifecycle.
function addon:ProcPublicColor(r, g, b)
    if Number(r, 0, 255) and Number(g, 0, 255) and Number(b, 0, 255) then
        return { r = r / 255, g = g / 255, b = b / 255 }
    end
end

local function Preferences()
    local api = C_CVar
    local enabled = (api and api.GetCVarBool or GetCVarBool)
    local opacity = (api and api.GetCVar or GetCVar)
    enabled, opacity = enabled and enabled("displaySpellActivationOverlays"), opacity and opacity("spellActivationOverlayOpacity")
    if not Public(opacity) then opacity = nil else opacity = tonumber(opacity) end
    if not Number(opacity, 0, 1) then return nil end
    return Public(enabled) and enabled == true, opacity
end

local function StopAnimations(frame)
    frame.phase = nil
    frame.playToken = (frame.playToken or 0) + 1
    local ok = true
    for _, group in pairs(frame.groups or {}) do
        local stopped = pcall(group.Stop, group)
        ok = stopped and ok
    end
    local alpha, rotation = true, true
    if frame.texture then
        alpha = pcall(frame.texture.SetAlpha, frame.texture, 1)
        rotation = pcall(frame.texture.SetRotation, frame.texture, frame.rotation or 0)
    end
    if not ok or not alpha or not rotation then error("owned animation reset unavailable") end
end

local function HideArtwork(frame)
    if not frame then return end
    frame.active, frame.exiting = nil, nil
    frame.phase, frame.playToken = nil, (frame.playToken or 0) + 1
    local hidden = pcall(frame.Hide, frame)
    local stopped = pcall(StopAnimations, frame)
    if not hidden or not stopped then error("owned artwork cleanup unavailable") end
end

local function SuppressNativeOverlay(self, overlay, record)
    self.procSuppressedOverlays = self.procSuppressedOverlays or {}
    -- Ownership records cleanup authority, not the current native alpha. A
    -- public native refresh may write the texture again; never read it back.
    self.procSuppressedOverlays[overlay] = record
    self:ProcDiagnosticAPI("SuppressNativeAlpha", "requested")
    local ok = pcall(record.texture.SetAlpha, record.texture, 0)
    self:ProcDiagnosticAPI("SuppressNativeAlpha", ok and "completed" or "failed")
    if not ok then error("native artwork suppression unavailable") end
end

function addon:RestoreProcNativeOverlay(overlay)
    local owned = self.procSuppressedOverlays and self.procSuppressedOverlays[overlay]
    if not owned then return true end
    -- Never inspect alpha. Keep failed restores owned so release/Stop retries.
    self:ProcDiagnosticAPI("RestoreNativeAlpha", "requested")
    local ok = pcall(owned.texture.SetAlpha, owned.texture, 1)
    self:ProcDiagnosticAPI("RestoreNativeAlpha", ok and "completed" or "failed")
    if ok then self.procSuppressedOverlays[overlay] = nil end
    if not ok then self:RecordProcFailure("release") end
    return ok
end

function addon:RestoreProcRegionArtwork(id, sourceState)
    local clean = true
    for overlay, owned in pairs(self.procSuppressedOverlays or {}) do
        local currentSource = not sourceState or (owned.ownerID == sourceState.ownerID
            and owned.sourceKey == sourceState.sourceKey)
        if (not id or owned.regionID == id) and currentSource then
            local ok, restored = pcall(self.RestoreProcNativeOverlay, self, overlay)
            clean = ok and restored and clean
            if not ok then self:RecordProcFailure("release") end
        end
    end
    return clean
end

function addon:StopProcArtwork()
    local clean = self:RestoreProcRegionArtwork()
    for _, frame in pairs(self.procArtworkFrames or {}) do
        local ok = pcall(HideArtwork, frame)
        clean = ok and clean
        if not ok then self:RecordProcFailure("stop") end
    end
    self.procNativeOverlays, self.procArtworkDiagnostics = {}, {}
    return clean
end

function addon:GetProcArtworkRetryBlocker()
    -- A factory can allocate before throwing without returning its object.
    -- Such an attempt stays latched for this session, even after known owners
    -- were cleaned successfully. Only Reload can remove that uncertainty.
    for _, fields in ipairs({ { "procArtworkFrames", "procArtworkAttempts" },
        { "procPreviewArtworkFrames", "procPreviewArtworkAttempts" } }) do
        local frames = self[fields[1]] or {}
        for id in pairs(self[fields[2]] or {}) do
            if not frames[id] then return "artwork-frame-requires-reload" end
        end
        for _, frame in pairs(frames) do
            if frame.textureAttempted and not frame.texture then return "artwork-texture-requires-reload" end
            for name in pairs(frame.groupAttempts or {}) do
                if not (frame.groups and frame.groups[name]) then return "artwork-group-requires-reload" end
            end
            for _, group in pairs(frame.groups or {}) do
                if group.animationAttempted and not group.animation then return "artwork-animation-requires-reload" end
            end
        end
    end
    for _, installed in pairs(self.procArtworkHookParts or {}) do
        if installed.showAttempted and not installed.show then return "artwork-show-hook-requires-reload" end
        if installed.releaseAttempted and not installed.release then return "artwork-release-hook-requires-reload" end
    end
end

local function Animation(frame, name, kind)
    frame.groups = frame.groups or {}
    local group = frame.groups[name]
    if not group then
        frame.groupAttempts = frame.groupAttempts or {}
        if frame.groupAttempts[name] then error("owned animation group construction requires reload") end
        frame.groupAttempts[name] = true
        group = frame.texture:CreateAnimationGroup()
        if not group then error("owned animation group construction returned no object") end
        frame.groups[name] = group
        frame.rendererOwner:ProcDiagnosticCount("animationGroupsCreated")
    end
    if not group.animation then
        if group.animationAttempted then error("owned animation construction requires reload") end
        group.animationAttempted = true
        group.animation = group:CreateAnimation(kind)
        if not group.animation then error("owned animation construction returned no object") end
        frame.rendererOwner:ProcDiagnosticCount("animationsCreated")
    end
    group.animation:SetOrder(1)
    return group, group.animation
end

local function StartActive(frame)
    local settings = frame.appearance.animation
    frame.phase = "active"
    if settings.active == "none" then return end
    local kind = settings.active == "rotate" and "Rotation" or settings.active == "breathe" and "Alpha" or "Scale"
    local group, animation = Animation(frame, "active_" .. settings.active, kind)
    animation:SetDuration((settings.active == "rotate" and 12 or 1.2) / settings.speed)
    if kind == "Rotation" then
        animation:SetDegrees(settings.direction == "counterclockwise" and 360 or -360)
        group:SetLooping("REPEAT")
    elseif kind == "Alpha" then
        animation:SetFromAlpha(1); animation:SetToAlpha(1 - settings.intensity * 0.7)
        group:SetLooping("BOUNCE")
    else
        animation:SetScaleFrom(1, 1)
        animation:SetScaleTo(1 + settings.intensity * 0.25, 1 + settings.intensity * 0.25)
        group:SetLooping("BOUNCE")
    end
    group:Play()
end

local function StartEntrance(frame)
    local settings = frame.appearance.animation
    if settings.entrance == "none" then StartActive(frame); return end
    frame.phase = "entrance"
    local kind = settings.entrance == "fade" and "Alpha" or "Scale"
    local group, animation = Animation(frame, "entrance_" .. settings.entrance, kind)
    animation:SetDuration(0.25 / settings.speed)
    if kind == "Alpha" then animation:SetFromAlpha(0); animation:SetToAlpha(1)
    else
        local from = settings.entrance == "pulse" and (1 + settings.intensity * 0.5) or (1 - settings.intensity * 0.75)
        animation:SetScaleFrom(from, from); animation:SetScaleTo(1, 1)
    end
    group:SetLooping("NONE")
    local generation, token = frame.rendererOwner:GetProcSafetyGeneration(), frame.playToken
    group:SetScript("OnFinished", function()
        if frame.rendererOwner:IsProcSafetyGenerationCurrent(generation) and frame.playToken == token
            and frame.active and frame.phase == "entrance" then
            local ok = frame.rendererOwner:RunProcSafe("animation", StartActive, frame)
            if not ok then
                if not frame.previewOwned then frame.rendererOwner:RestoreProcRegionArtwork(frame.entryID) end
                local clean = pcall(HideArtwork, frame)
                if not clean then frame.rendererOwner:RecordProcFailure("animation") end
            end
        end
    end)
    group:Play()
end

local function StartExit(self, frame)
    if not frame or frame.exiting then return end
    if not frame.active or frame.appearance.animation.exit == "none" then
        if frame then HideArtwork(frame) end
        return
    end
    StopAnimations(frame)
    frame.active, frame.exiting, frame.phase = nil, true, "exit"
    local settings = frame.appearance.animation
    local kind = settings.exit == "fade" and "Alpha" or "Scale"
    local group, animation = Animation(frame, "exit_" .. settings.exit, kind)
    animation:SetDuration(0.2 / settings.speed)
    if kind == "Alpha" then animation:SetFromAlpha(1); animation:SetToAlpha(0)
    else
        animation:SetScaleFrom(1, 1)
        animation:SetScaleTo(1 - settings.intensity * 0.75, 1 - settings.intensity * 0.75)
    end
    group:SetLooping("NONE")
    local generation, token = self:GetProcSafetyGeneration(), frame.playToken
    group:SetScript("OnFinished", function()
        if self:IsProcSafetyGenerationCurrent(generation) and frame.playToken == token and frame.phase == "exit" then
            local ok = self:RunProcSafe("animation", HideArtwork, frame)
            if not ok then self:RestoreProcRegionArtwork(frame.entryID) end
        end
    end)
    group:Play()
end

local function Acquire(self, entry, preview)
    local key = preview and "procPreviewArtworkFrames" or "procArtworkFrames"
    self[key] = self[key] or {}
    local frame = self[key][entry.id]
    if not frame then
        local attemptsKey = preview and "procPreviewArtworkAttempts" or "procArtworkAttempts"
        self[attemptsKey] = self[attemptsKey] or {}
        if self[attemptsKey][entry.id] then error("owned artwork frame construction requires reload") end
        self[attemptsKey][entry.id] = true
        frame = CreateFrame("Frame", nil, UIParent)
        if not frame then error("owned artwork frame construction returned no object") end
        self[key][entry.id] = frame
        frame.entryID, frame.previewOwned, frame.rendererOwner = entry.id, preview == true, self
        self:ProcDiagnosticCount(preview and "previewArtworkFramesCreated" or "artworkFramesCreated")
        frame:Hide()
    end
    -- Cache each allocation immediately. A later initialization error must
    -- retry the same owned objects rather than leaking one per public SHOW.
    frame:SetFrameStrata("MEDIUM"); frame:SetFrameLevel(9); frame:EnableMouse(false)
    if not frame.texture then
        if frame.textureAttempted then error("owned artwork texture construction requires reload") end
        frame.textureAttempted = true
        frame.texture = frame:CreateTexture(nil, "ARTWORK")
        if not frame.texture then error("owned artwork texture construction returned no object") end
        self:ProcDiagnosticCount(preview and "previewArtworkTexturesCreated" or "artworkTexturesCreated")
    end
    frame.texture:SetAllPoints(frame)
    frame.texture:SetBlendMode("BLEND")
    return frame
end

local function Signature(appearance, asset, opacity)
    local values = { asset.textureID, asset.width, asset.height, asset.color.r, asset.color.g, asset.color.b,
        appearance.alpha, appearance.scale, appearance.width, appearance.height, appearance.rotation,
        tostring(appearance.mirrorX), tostring(appearance.mirrorY), appearance.offset.x, appearance.offset.y,
        appearance.desaturation, appearance.animation.entrance, appearance.animation.active,
        appearance.animation.exit, appearance.animation.speed, appearance.animation.intensity,
        appearance.animation.direction, opacity }
    return table.concat(values, ":")
end

local function Draw(self, entry, appearance, asset, opacity, preview)
    local frame = Acquire(self, entry, preview)
    local root = SpellActivationOverlayFrame
    local nativeScale, uiScale = root and root.GetEffectiveScale and root:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not Number(nativeScale, 0.001, 100) or not Number(uiScale, 0.001, 100) then return nil, "public-layout-unavailable" end
    local ratio = nativeScale / uiScale
    if not self:AnchorProcReminder(frame, entry, { scale = 1 }, true, preview) then return nil, "public-layout-unavailable" end
    local point, relative, relativePoint, x, y = frame:GetPoint(1)
    frame:ClearAllPoints()
    frame:SetPoint(point, relative, relativePoint, x + appearance.offset.x, y + appearance.offset.y)
    frame:SetSize(asset.width * ratio * appearance.scale * appearance.width,
        asset.height * ratio * appearance.scale * appearance.height)
    local signature = Signature(appearance, asset, opacity)
    local restart = not frame.active or frame.signature ~= signature
    if restart then StopAnimations(frame) end
    frame.appearance, frame.rotation, frame.signature = appearance, math.rad(appearance.rotation), signature
    frame.texture:SetTexture(asset.textureID)
    frame.texture:SetVertexColor(asset.color.r, asset.color.g, asset.color.b)
    frame.texture:SetDesaturation(appearance.desaturation)
    local flipH, flipV = (asset.flipH == true) ~= appearance.mirrorX, (asset.flipV == true) ~= appearance.mirrorY
    frame.texture:SetTexCoord(flipH and 1 or 0, flipH and 0 or 1, flipV and 1 or 0, flipV and 0 or 1)
    frame.texture:SetRotation(frame.rotation)
    frame:SetAlpha(opacity * appearance.alpha)
    frame.active, frame.exiting = true, nil
    frame:Show()
    if restart then StartEntrance(frame) end
    return frame
end

local function FailOpen(self, entry, reason, sourceState)
    -- Missing evidence for the new source cannot release a different native
    -- source that is still fading. Mode/visibility changes and faults omit this
    -- filter and retain their full-region cleanup behavior.
    self:RestoreProcRegionArtwork(entry.id, sourceState)
    local clean = pcall(HideArtwork, self.procArtworkFrames and self.procArtworkFrames[entry.id])
    if not clean then self:RecordProcFailure("artwork") end
    self.procArtworkDiagnostics = self.procArtworkDiagnostics or {}
    self.procArtworkDiagnostics[entry.id] = reason
end

local function MatchesCurrent(self, overlay, record, state)
    if record.root ~= SpellActivationOverlayFrame or record.sourceKey ~= state.sourceKey
        or record.ownerID ~= state.ownerID or record.textureID ~= state.textureID or record.scale ~= state.scale then return false end
    local list = record.root.overlaysInUse
    if not Public(list) or type(list) ~= "table" then return false end
    list = list[record.ownerID]
    return Public(list) and type(list) == "table" and Public(list[record.position]) and list[record.position] == overlay
end

local function RenderRegion(self, entry, visible, opacity)
    local appearance = self:GetProcArtworkPresentation(entry)
    local frame = self.procArtworkFrames and self.procArtworkFrames[entry.id]
    if appearance.mode == "native" then FailOpen(self, entry, "native mode"); return end
    if not visible then FailOpen(self, entry, "display CVar disabled"); return end
    if appearance.mode ~= "custom" then HideArtwork(frame) end
    local state = self:GetProcRegionOverlayState(entry)
    if not state or not state.shown then
        if frame and frame.active then StartExit(self, frame)
        end
        -- Native fade-out owns the release callback. Keep its texture hidden
        -- until that release so ending our exit does not reveal stock artwork.
        self.procArtworkDiagnostics[entry.id] = "awaiting public SHOW"
        return
    end
    local matched
    for overlay, record in pairs(self.procNativeOverlays or {}) do
        if record.regionID == entry.id and MatchesCurrent(self, overlay, record, state) then
            if matched then FailOpen(self, entry, "ambiguous native overlay", state); return end
            matched = overlay
        end
    end
    if not matched then FailOpen(self, entry, self.procArtworkHookReason or "matching native lifecycle unavailable", state); return end
    local record = self.procNativeOverlays[matched]
    if appearance.mode == "custom" then
        -- Both public callbacks must agree. Never use an older hook's RGB as
        -- fallback when a repeated SHOW carries missing/restricted RGB.
        if not appearance.artColor and (not state.color or not record.color
            or state.color.r ~= record.color.r or state.color.g ~= record.color.g or state.color.b ~= record.color.b) then
            FailOpen(self, entry, "native-color-unavailable", state); return
        end
        local publicState = { textureID = state.textureID, scale = state.scale, color = state.color }
        local resolved, asset, reason = self:ResolveProcAppearance(entry, appearance, publicState, false)
        if not asset then FailOpen(self, entry, reason or "artwork resolver unavailable", state); return end
        -- Prepare the complete owned graphic before taking native suppression.
        local rendered, unavailable = Draw(self, entry, resolved, asset, opacity, false)
        if not rendered then FailOpen(self, entry, unavailable, state); return end
        rendered.nativeOverlay = matched
    else HideArtwork(frame) end
    -- A superseded source can still be fading on its own native frame. Keep
    -- its texture suppressed until ReleaseOverlay, mode change or cleanup;
    -- restoring it here would draw the old native fade over the new artwork.
    if self:IsProcQuarantined() then return end
    if not (self.procSuppressedOverlays and self.procSuppressedOverlays[matched]) then
        SuppressNativeOverlay(self, matched, record)
    end
    self.procArtworkDiagnostics[entry.id] = "ready"
end

function addon:RenderProcArtwork()
    if self:IsProcQuarantined() then return end
    if not self.procTracking then self:StopProcArtwork(); return end
    self.procArtworkDiagnostics = self.procArtworkDiagnostics or {}
    local preferencesOK, visible, opacity = self:RunProcSafe("preferences", Preferences)
    if not preferencesOK or visible == nil then
        self:StopProcArtwork()
        for _, definition in ipairs(self.procDefinitions or {}) do
            for _, entry in ipairs(definition.regions) do
                self.procArtworkDiagnostics[entry.id] = "public overlay preferences unavailable"
            end
        end
        return
    end
    for _, definition in ipairs(self.procDefinitions or {}) do
        for _, entry in ipairs(definition.regions) do
            if self:IsProcQuarantined() then return end
            -- A presentation fault must never leave the native graphic hidden.
            local ok = self:RunProcSafe("artwork", RenderRegion, self, entry, visible, opacity)
            if not ok then FailOpen(self, entry, "renderer failure; native retained") end
        end
    end
end

local function Observe(self, root, ownerID, textureID, position, scale, r, g, b)
    if root ~= SpellActivationOverlayFrame or self.procArtworkHookRoot ~= root
        or not Number(ownerID, 1, 2147483647) or not Number(textureID, 1, 2147483647)
        or not Number(position, 0, 100) or not Number(scale, 0.001, 10) then return end
    local lists = root.overlaysInUse
    if not Public(lists) or type(lists) ~= "table" then return end
    local list = lists[ownerID]
    if not Public(list) or type(list) ~= "table" then return end
    local overlay = list[position]
    if not Public(overlay) or type(overlay) ~= "table" or not Public(overlay.spellID)
        or overlay.spellID ~= ownerID or not Public(overlay.position) or overlay.position ~= position then return end
    if self:IsProcQuarantined() or not self.procTracking then
        -- A failed release can leave cleanup ownership on a pooled texture.
        -- Retry restoration for its next native SHOW without acquiring anew.
        self:RestoreProcNativeOverlay(overlay)
        return
    end
    local previous = self.procNativeOverlays and self.procNativeOverlays[overlay]
    local region, source, ambiguous
    for _, binding in ipairs(self.procByOverlay and self.procByOverlay[ownerID] or {}) do
        if binding.source.textureID == textureID then
            for _, entry in ipairs(binding.source.regions) do
                if Enum.ScreenLocationType[entry.nativeLocation or entry.location] == position then
                    if region then ambiguous = true else region, source = entry, binding.source end
                end
            end
        end
    end
    if ambiguous then region, source = nil, nil end
    local texture = overlay.texture
    local writable = Public(texture) and texture and type(texture.SetAlpha) == "function"
    local sameIdentity = region and writable and previous and previous.root == root
        and previous.regionID == region.id and previous.ownerID == ownerID
        and previous.textureID == textureID and previous.position == position
        and previous.sourceKey == source.stateKey and previous.texture == texture
    if not sameIdentity then
        if not self:RestoreProcNativeOverlay(overlay) then return end
        if previous then HideArtwork(self.procArtworkFrames and self.procArtworkFrames[previous.regionID]) end
        if self.procNativeOverlays then self.procNativeOverlays[overlay] = nil end
    end
    if not region or not writable then return end
    self.procNativeOverlays = self.procNativeOverlays or {}
    local record = sameIdentity and previous or { regionID = region.id, root = root, ownerID = ownerID,
        textureID = textureID, position = position, sourceKey = source.stateKey, texture = texture,
    }
    record.scale, record.color = scale, self:ProcPublicColor(r, g, b)
    self.procNativeOverlays[overlay] = record
    -- Refreshing the same public identity is not a release or a new entrance.
    -- Preserve suppression even when our HIDE state precedes the next SHOW.
    if sameIdentity and self.procSuppressedOverlays and self.procSuppressedOverlays[overlay] then
        SuppressNativeOverlay(self, overlay, record)
    end
    self:RenderProcArtwork()
end

function addon:InstallProcArtworkHooks()
    if self:IsProcQuarantined() then return false end
    local root = SpellActivationOverlayFrame
    if self.procArtworkHookRoot == root and root then return true end
    if not root or type(hooksecurefunc) ~= "function" or type(root.ShowOverlay) ~= "function"
        or type(root.ReleaseOverlay) ~= "function" then
        self.procArtworkHookReason = "public native lifecycle unavailable"
        return false
    end
    if self.procArtworkHookRoot then self:StopProcArtwork() end
    self.procArtworkHookParts = self.procArtworkHookParts or setmetatable({}, { __mode = "k" })
    local installed = self.procArtworkHookParts[root] or {}
    self.procArtworkHookParts[root] = installed
    local ok = self:RunProcSafe("hook", function()
        if not installed.show then
            if installed.showAttempted then error("native show hook installation requires reload") end
            installed.showAttempted = true
            hooksecurefunc(root, "ShowOverlay", function(owner, ...)
            if self:IsProcQuarantined() or not self.procTracking then
                local cleaned = pcall(Observe, self, owner, ...)
                if not cleaned then self:RecordProcFailure("release") end
                return
            end
            local observed = self:RunProcSafe("hook", Observe, self, owner, ...)
            if not observed then self:StopProcArtwork(); self.procArtworkHookReason = "native lifecycle unavailable" end
        end); installed.show = true; self:ProcDiagnosticCount("artworkHooksInstalled") end
        if not installed.release then
            if installed.releaseAttempted then error("native release hook installation requires reload") end
            installed.releaseAttempted = true
            hooksecurefunc(root, "ReleaseOverlay", function(_, overlay)
            -- Release retains only cleanup authority while Proc is quarantined.
            local released = pcall(function()
                self:RestoreProcNativeOverlay(overlay)
                local record = self.procNativeOverlays and self.procNativeOverlays[overlay]
                if record then
                    self.procNativeOverlays[overlay] = nil
                    local frame = self.procArtworkFrames and self.procArtworkFrames[record.regionID]
                    if frame and frame.nativeOverlay == overlay and not frame.exiting then HideArtwork(frame) end
                end
            end)
            if not released then self:RecordProcFailure("release") end
        end); installed.release = true; self:ProcDiagnosticCount("artworkHooksInstalled") end
    end)
    if not ok then
        self:StopProcArtwork()
        self.procArtworkHookReason = "native lifecycle hook unavailable"
        return false
    end
    self.procArtworkHookRoot, self.procArtworkHookReason = root, nil
    return true
end

function addon:StopProcArtworkPreview()
    local clean = true
    for _, frame in pairs(self.procPreviewArtworkFrames or {}) do
        local ok = pcall(HideArtwork, frame)
        clean = ok and clean
        if not ok then self:RecordProcFailure("stop") end
    end
    return clean
end

function addon:RenderProcArtworkPreview(entry)
    if self:IsProcQuarantined() then return end
    -- TEST has a separate frame pool and never obtains/suppresses native handles.
    local ok, frame = self:RunProcSafe("preview", function()
        local appearance, asset = self:ResolveProcAppearance(entry, nil, nil, true)
        if appearance.mode == "timer" or not asset then return end
        return Draw(self, entry, appearance, asset, 1, true)
    end)
    if not ok or not frame then
        local clean = pcall(HideArtwork, self.procPreviewArtworkFrames and self.procPreviewArtworkFrames[entry.id])
        if not clean then self:RecordProcFailure("preview") end
    end
end

function addon:RefreshProcAppearance(entry)
    if self:IsProcQuarantined() then return end
    local id = entry and entry.id
    -- Explicit configuration changes cancel an in-flight entrance/exit even
    -- after HIDE. This path never rebinds a native Aura timer slot.
    for regionID, frame in pairs(self.procArtworkFrames or {}) do
        if not id or regionID == id then
            local ok = self:RunProcSafe("artwork", HideArtwork, frame)
            if not ok and self:IsProcQuarantined() then return end
        end
    end
    self:RestoreProcRegionArtwork(id)
    self:RenderProcArtwork()
    if self.RefreshPreview then self:RefreshPreview(true) end
end

function addon:GetProcArtworkDiagnostic(entry)
    local appearance = self:GetProcRegionAppearance(entry)
    local owned = false
    for _, record in pairs(self.procSuppressedOverlays or {}) do if record.regionID == entry.id then owned = true end end
    local reason = self.procArtworkDiagnostics and self.procArtworkDiagnostics[entry.id]
        or self.procArtworkHookReason or "not initialized"
    return "mode=" .. appearance.mode .. "; asset=" .. (appearance.assetKey or "native mapped artwork")
        .. "; renderer=" .. (reason == "ready" and "ready" or "unavailable")
        .. "; native suppression=" .. (owned and "owned" or "not owned") .. "; fail-open=" .. reason
end
