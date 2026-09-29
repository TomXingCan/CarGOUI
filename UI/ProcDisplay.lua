local _, addon = ...

local function Number(value)
    return issecretvalue and not issecretvalue(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

-- Public stock layout: Blizzard_FrameXML/SpellActivationOverlay.lua, build
-- 69933. Anchor to the stock root's edges, not a fixed screen-center offset.
-- Only geometry is read; no native child, visibility, alpha or aura is read.
function addon:AnchorProcReminder(frame, entry, style, guideOnly, preview)
    local root = SpellActivationOverlayFrame
    local location = entry.nativeLocation or entry.location
    if not root or not location or not root.GetEffectiveScale or not UIParent.GetEffectiveScale then
        return false, self:Text("The stock Proc layout root or mapped location is unavailable.")
    end
    local nativeScale, uiScale = root:GetEffectiveScale(), UIParent:GetEffectiveScale()
    if not Number(nativeScale) or not Number(uiScale) or nativeScale <= 0 or uiScale <= 0 then
        return false, self:Text("The stock Proc layout scale is not available as public geometry.")
    end
    local regionState = not preview and self.GetProcRegionOverlayState and self:GetProcRegionOverlayState(entry)
    local scale = regionState and regionState.scale or entry.nativeScale or 1
    if not Number(scale) or scale <= 0 or scale > 10 then
        return false, self:Text("The native Proc region scale is unavailable or unsupported.")
    end
    local half, gap = 128 * 0.8 * scale / 2, 128 * 0.8
    local point, x, y = "CENTER", 0, 0
    if location == "Left" then point, x = "LEFT", -half
    elseif location == "Right" then point, x = "RIGHT", half
    elseif location == "LeftOutside" then point, x = "LEFT", -gap - half
    elseif location == "RightOutside" then point, x = "RIGHT", gap + half
    elseif location == "Top" then point, y = "TOP", half
    elseif location == "Bottom" then point, y = "BOTTOM", -half
    elseif location == "TopLeft" then point, x, y = "TOPLEFT", -half, half
    elseif location == "TopRight" then point, x, y = "TOPRIGHT", half, half
    elseif location ~= "Center" then return false, self:Text("The native Proc region location is not mapped.") end
    local offset = guideOnly and { x = 0, y = 0 } or self:GetReminderPosition(entry)
    local ratio = nativeScale / uiScale
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", root, point, (x * ratio + offset.x) / style.scale,
        (y * ratio + offset.y) / style.scale)
    return true
end

local function AcquireAuraReminder(self, entry, auraID, textOnly)
    self:CreateDisplay()
    local pool = self.reminderFrames.nativeAura
    if not pool then pool = {}; self.reminderFrames.nativeAura = pool end
    local frame = pool[entry.id]
    if frame and (frame.nativeAuraID ~= auraID or frame.nativeTextOnly ~= textOnly
        or frame.reminderEntry.class ~= entry.class or frame.reminderEntry.specID ~= entry.specID) then
        self:DisableAuraReminder(frame)
        return nil, self:Text("A stable reminder region cannot reuse a native slot for another Aura or scope.")
    end
    if not frame then
        self.nativeAuraWrapperAttempts = self.nativeAuraWrapperAttempts or {}
        if self.nativeAuraWrapperAttempts[entry.id] then
            error("Proc wrapper allocation outcome is unknown; Reload is required.")
        end
        self.nativeAuraWrapperAttempts[entry.id] = entry.kind == "proc" and "proc" or "freeMove"
        frame = CreateFrame("Frame", nil, UIParent)
        -- Save the object before any configuration method may throw.
        pool[entry.id] = frame
        frame.reminderEntry, frame.nativeAuraID, frame.nativeTextOnly = entry, auraID, textOnly
        frame.entryId, frame.channel, frame.nativeAuraOwned = entry.id, "nativeAura", true
        if entry.kind == "proc" then self:ProcDiagnosticCount("wrapperFramesCreated") end
    end
    if not frame.nativeWrapperReady then
        frame:SetFrameStrata("MEDIUM")
        frame:SetFrameLevel(15)
        frame:EnableMouse(false)
        frame:SetAlpha(0)
        frame:Show()
        frame.nativeWrapperReady = true
    end
    if not frame.auraHandle or not frame.auraHandle.slotReady then
        local handle, reason = self:CreateNativeAuraSlot(frame, entry.id, auraID, textOnly, entry)
        if not handle then return nil, reason end
        frame.auraHandle, frame.text = handle, handle.font
    end
    frame.reminderEntry, frame.styleKey = entry, self:GetReminderStyleKey(entry)
    if self:StyleAuraReminder(frame) == false then return nil, "Proc styling failed; see session diagnostics." end
    return frame
end

function addon:AcquireAuraReminder(entry, auraID, textOnly)
    if entry.kind == "proc" then
        if self:IsProcQuarantined() then return nil, "Proc is quarantined for this session." end
        local frame = self.reminderFrames and self.reminderFrames.nativeAura and self.reminderFrames.nativeAura[entry.id]
        if not frame or not frame.auraHandle or not frame.auraHandle.slotReady then
            return self:ProcDiagnosticCall("nativeConstruct", AcquireAuraReminder, self, entry, auraID, textOnly)
        end
    end
    return AcquireAuraReminder(self, entry, auraID, textOnly)
end

local function StyleAuraReminder(self, frame)
    local entry = frame.reminderEntry
    if not frame.auraHandle or not frame.auraHandle.slotReady then return false end
    local style = self:GetReminderStyle(frame.styleKey or entry)
    frame:SetScale(style.scale)
    frame:SetSize(style.font.size * 12, style.font.size * 2)
    -- Our Font object changes style without accessing the denied native child.
    self:ApplyFontSettings(frame.auraHandle.font, style, entry)
    if entry.kind == "proc" then
        frame.procGeometryReady, frame.procGeometryReason = self:AnchorProcReminder(frame, entry, style)
    else
        local offset = self:GetReminderPosition(entry)
        frame:ClearAllPoints()
        frame:SetPoint(offset.anchor, UIParent, offset.anchor,
            (entry.anchor.x + offset.x) / style.scale, (entry.anchor.y + offset.y) / style.scale)
    end
end

function addon:StyleAuraReminder(frame)
    if frame.reminderEntry and frame.reminderEntry.kind == "proc" then
        return self:RunProcSafe("render", StyleAuraReminder, self, frame)
    end
    return StyleAuraReminder(self, frame)
end

function addon:DisableAuraReminder(frame)
    frame:SetAlpha(0)
    local handle = frame.auraHandle or (self.nativeAuraSlots and self.nativeAuraSlots[frame.entryId])
    if handle then handle:SetEnabled(false) end
    -- Do not hide: the native one-shot disable pass must be able to clear its
    -- assignment and copied binding. No aura/secret state is read back.
    frame:Show()
end
