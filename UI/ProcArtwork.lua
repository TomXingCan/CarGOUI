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
    if not Number(opacity, 0, 1) then error("public overlay opacity unavailable") end
    return Public(enabled) and enabled == true, opacity
end

local function StopAnimations(frame)
    frame.phase = nil
    local ok = true
    for _, group in pairs(frame.groups or {}) do
        local stopped = pcall(group.Stop, group)
        ok = stopped and ok
    end
    local alpha = pcall(frame.texture.SetAlpha, frame.texture, 1)
    local rotation = pcall(frame.texture.SetRotation, frame.texture, frame.rotation or 0)
    if not ok or not alpha or not rotation then error("owned animation reset unavailable") end
end

local function HideArtwork(frame)
    if not frame then return end
    frame.active, frame.exiting = nil, nil
    frame:Hide()
    StopAnimations(frame)
end

function addon:RestoreProcNativeOverlay(overlay)
    local owned = self.procSuppressedOverlays and self.procSuppressedOverlays[overlay]
    if not owned then return true end
    -- Never inspect alpha. Keep failed restores owned so release/Stop retries.
    local ok = pcall(owned.texture.SetAlpha, owned.texture, 1)
    if ok then self.procSuppressedOverlays[overlay] = nil end
    return ok
end

function addon:RestoreProcRegionArtwork(id)
    for overlay, owned in pairs(self.procSuppressedOverlays or {}) do
        if not id or owned.regionID == id then self:RestoreProcNativeOverlay(overlay) end
    end
end

function addon:StopProcArtwork()
    self:RestoreProcRegionArtwork()
    for _, frame in pairs(self.procArtworkFrames or {}) do pcall(HideArtwork, frame) end
    self.procNativeOverlays, self.procArtworkDiagnostics = {}, {}
end

local function Animation(frame, name, kind)
    frame.groups = frame.groups or {}
    local group = frame.groups[name]
    if not group then
        group = frame.texture:CreateAnimationGroup()
        frame.groups[name] = group
    end
    if not group.animation then group.animation = group:CreateAnimation(kind) end
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
        animation:SetFromScale(1, 1)
        animation:SetToScale(1 + settings.intensity * 0.25, 1 + settings.intensity * 0.25)
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
        animation:SetFromScale(from, from); animation:SetToScale(1, 1)
    end
    group:SetLooping("NONE")
    group:SetScript("OnFinished", function()
        if frame.active and frame.phase == "entrance" then
            local ok = pcall(StartActive, frame)
            if not ok then
                if not frame.previewOwned then frame.rendererOwner:RestoreProcRegionArtwork(frame.entryID) end
                pcall(HideArtwork, frame)
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
        animation:SetFromScale(1, 1)
        animation:SetToScale(1 - settings.intensity * 0.75, 1 - settings.intensity * 0.75)
    end
    group:SetLooping("NONE")
    group:SetScript("OnFinished", function()
        if frame.phase == "exit" then
            local ok = pcall(HideArtwork, frame)
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
        frame = CreateFrame("Frame", nil, UIParent)
        self[key][entry.id] = frame
        frame.entryID, frame.previewOwned, frame.rendererOwner = entry.id, preview == true, self
        frame:Hide()
    end
    -- Cache each allocation immediately. A later initialization error must
    -- retry the same owned objects rather than leaking one per public SHOW.
    frame:SetFrameStrata("MEDIUM"); frame:SetFrameLevel(9); frame:EnableMouse(false)
    if not frame.texture then frame.texture = frame:CreateTexture(nil, "ARTWORK") end
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
    if not Number(nativeScale, 0.001, 100) or not Number(uiScale, 0.001, 100) then error("public-layout-unavailable") end
    local ratio = nativeScale / uiScale
    if not self:AnchorProcReminder(frame, entry, { scale = 1 }, true, preview) then error("public-layout-unavailable") end
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

local function FailOpen(self, entry, reason)
    self:RestoreProcRegionArtwork(entry.id)
    pcall(HideArtwork, self.procArtworkFrames and self.procArtworkFrames[entry.id])
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
    local appearance = self:GetProcRegionAppearance(entry)
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
            if matched then FailOpen(self, entry, "ambiguous native overlay"); return end
            matched = overlay
        end
    end
    if not matched then FailOpen(self, entry, self.procArtworkHookReason or "matching native lifecycle unavailable"); return end
    local record = self.procNativeOverlays[matched]
    if appearance.mode == "custom" then
        -- Both public callbacks must agree. Never use an older hook's RGB as
        -- fallback when a repeated SHOW carries missing/restricted RGB.
        if not appearance.artColor and (not state.color or not record.color
            or state.color.r ~= record.color.r or state.color.g ~= record.color.g or state.color.b ~= record.color.b) then
            FailOpen(self, entry, "native-color-unavailable"); return
        end
        local publicState = { textureID = state.textureID, scale = state.scale, color = state.color }
        local resolved, asset, reason = self:ResolveProcAppearance(entry, appearance, publicState, false)
        if not asset then FailOpen(self, entry, reason or "artwork resolver unavailable"); return end
        -- Prepare the complete owned graphic before taking native suppression.
        local rendered = Draw(self, entry, resolved, asset, opacity, false)
        rendered.nativeOverlay = matched
    else HideArtwork(frame) end
    for overlay, owned in pairs(self.procSuppressedOverlays or {}) do
        if owned.regionID == entry.id and overlay ~= matched then self:RestoreProcNativeOverlay(overlay) end
    end
    self.procSuppressedOverlays = self.procSuppressedOverlays or {}
    if not self.procSuppressedOverlays[matched] then
        self.procSuppressedOverlays[matched] = record
        record.texture:SetAlpha(0)
    end
    self.procArtworkDiagnostics[entry.id] = "ready"
end

function addon:RenderProcArtwork()
    if not self.procTracking then self:StopProcArtwork(); return end
    self.procArtworkDiagnostics = self.procArtworkDiagnostics or {}
    local preferencesOK, visible, opacity = pcall(Preferences)
    if not preferencesOK then
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
            -- A presentation fault must never leave the native graphic hidden.
            local ok = pcall(RenderRegion, self, entry, visible, opacity)
            if not ok then FailOpen(self, entry, "renderer failure; native retained") end
        end
    end
end

local function Observe(self, root, ownerID, textureID, position, scale, r, g, b)
    if not self.procTracking or root ~= SpellActivationOverlayFrame or self.procArtworkHookRoot ~= root
        or not Number(ownerID, 1, 2147483647) or not Number(textureID, 1, 2147483647)
        or not Number(position, 0, 100) or not Number(scale, 0.001, 10) then return end
    local lists = root.overlaysInUse
    if not Public(lists) or type(lists) ~= "table" then return end
    local list = lists[ownerID]
    if not Public(list) or type(list) ~= "table" then return end
    local overlay = list[position]
    if not Public(overlay) or type(overlay) ~= "table" or not Public(overlay.spellID)
        or overlay.spellID ~= ownerID or not Public(overlay.position) or overlay.position ~= position then return end
    if not self:RestoreProcNativeOverlay(overlay) then return end
    local previous = self.procNativeOverlays and self.procNativeOverlays[overlay]
    if previous then pcall(HideArtwork, self.procArtworkFrames and self.procArtworkFrames[previous.regionID]) end
    if self.procNativeOverlays then self.procNativeOverlays[overlay] = nil end
    local region, source
    for _, binding in ipairs(self.procByOverlay and self.procByOverlay[ownerID] or {}) do
        if binding.source.textureID == textureID then
            for _, entry in ipairs(binding.source.regions) do
                if Enum.ScreenLocationType[entry.nativeLocation or entry.location] == position then
                    if region then return end
                    region, source = entry, binding.source
                end
            end
        end
    end
    if not region then return end
    local texture = overlay.texture
    if not Public(texture) or not texture or type(texture.SetAlpha) ~= "function" then return end
    self.procNativeOverlays = self.procNativeOverlays or {}
    self.procNativeOverlays[overlay] = { regionID = region.id, root = root, ownerID = ownerID,
        textureID = textureID, position = position, sourceKey = source.stateKey, texture = texture,
        scale = scale, color = self:ProcPublicColor(r, g, b) }
    self:RenderProcArtwork()
end

function addon:InstallProcArtworkHooks()
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
    local ok = pcall(function()
        if not installed.show then hooksecurefunc(root, "ShowOverlay", function(owner, ...)
            local observed = pcall(Observe, self, owner, ...)
            if not observed then self:StopProcArtwork(); self.procArtworkHookReason = "native lifecycle unavailable" end
        end); installed.show = true end
        if not installed.release then hooksecurefunc(root, "ReleaseOverlay", function(_, overlay)
            self:RestoreProcNativeOverlay(overlay)
            local record = self.procNativeOverlays and self.procNativeOverlays[overlay]
            if record then
                self.procNativeOverlays[overlay] = nil
                local frame = self.procArtworkFrames and self.procArtworkFrames[record.regionID]
                if frame and frame.nativeOverlay == overlay and not frame.exiting then pcall(HideArtwork, frame) end
            end
        end); installed.release = true end
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
    for _, frame in pairs(self.procPreviewArtworkFrames or {}) do pcall(HideArtwork, frame) end
end

function addon:RenderProcArtworkPreview(entry)
    local appearance, asset = self:ResolveProcAppearance(entry, nil, nil, true)
    if appearance.mode == "timer" or not asset then return end
    -- TEST has a separate frame pool and never obtains/suppresses native handles.
    local ok = pcall(Draw, self, entry, appearance, asset, 1, true)
    if not ok then pcall(HideArtwork, self.procPreviewArtworkFrames and self.procPreviewArtworkFrames[entry.id]) end
end

function addon:RefreshProcAppearance(entry)
    local id = entry and entry.id
    -- Explicit configuration changes cancel an in-flight entrance/exit even
    -- after HIDE. This path never rebinds a native Aura timer slot.
    for regionID, frame in pairs(self.procArtworkFrames or {}) do
        if not id or regionID == id then pcall(HideArtwork, frame) end
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
