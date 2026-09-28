local _, addon = ...

addon.previewState = { mode = "off" }
addon.previewFrames = {}

local function CreateGuidance(frame, entry)
    local proc = entry.kind == "proc"
    if proc then
        if frame.procGuidanceAttempted then error("Proc preview guidance construction is incomplete; Reload is required.", 0) end
        frame.procGuidanceAttempted = true
    end
    local guide = CreateFrame("Frame", nil, frame)
    if proc then frame.guidance = guide end
    -- A child's background would otherwise draw above its parent's timer text.
    guide:SetFrameLevel(frame:GetFrameLevel() - 1)
    guide:EnableMouse(false)
    guide:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local region = entry.guide
    guide:SetSize(region and region.width or 150, region and region.height or 64)
    if region and (entry.kind ~= "proc" or not addon.RenderProcArtworkPreview) then
        -- Native shape is faint, static, TEST-only guidance. Never feed sample
        -- events into Blizzard's overlay frame or start its animation/sounds.
        local shape = guide:CreateTexture(nil, "BACKGROUND")
        if proc then guide.shape = shape end
        shape:SetAllPoints(guide)
        shape:SetTexture(region.texture)
        shape:SetTexCoord(region.flipH and 1 or 0, region.flipH and 0 or 1,
            region.flipV and 1 or 0, region.flipV and 0 or 1)
        shape:SetVertexColor(0.65, 0.83, 1, 0.35)
        guide.shape = shape
    end

    local label = guide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if proc then guide.label = label end
    label:SetPoint("TOP", guide, "BOTTOM", 0, -6)
    label:SetWidth(240)
    label:SetJustifyH("CENTER")
    label:SetTextColor(0.55, 0.8, 1, 1)
    label:SetText(addon:Format("TEST: %s", addon:GetEntryDisplayLabel(entry)))
    guide.label = label
    if proc then guide.marks = {} end
    for index, arm in ipairs({ { -15, 0, 6, 1 }, { 15, 0, 6, 1 },
        { 0, -15, 1, 6 }, { 0, 15, 1, 6 } }) do
        local mark = guide:CreateTexture(nil, "BORDER")
        if proc then guide.marks[index] = mark end
        mark:SetColorTexture(0.85, 0.7, 0.35, 0.8)
        mark:SetSize(arm[3], arm[4])
        mark:SetPoint("CENTER", guide, "CENTER", arm[1], arm[2])
    end
    frame.guidance = guide
    if proc then guide.procGuidanceReady = true end
    return guide
end

function addon:UpdatePreviewGuidance(frame, entry, enabled)
    if not enabled then
        if frame.guidance then frame.guidance:Hide() end
        return
    end
    if entry.kind == "proc" and frame.procGuidanceAttempted
        and not (frame.guidance and frame.guidance.procGuidanceReady) then
        error("Proc preview guidance construction is incomplete; Reload is required.", 0)
    end
    local guide = frame.guidance or CreateGuidance(frame, entry)
    if entry.kind == "proc" and self.RenderProcArtworkPreview and guide.shape then guide.shape:Hide() end
    guide.label:SetText(self:Format("TEST: %s", self:GetEntryDisplayLabel(entry)))
    -- Typography scaling must not change the size of the stock region guide.
    guide:SetScale(1 / self:GetReminderStyle(frame.styleKey or entry).scale)
    guide:ClearAllPoints()
    if entry.kind == "proc" then
        -- Position edits move the timer relative to Blizzard's stationary shape.
        -- A guide that followed that timer would hide the effect of the offset.
        guide:SetPoint("CENTER", UIParent, "CENTER", entry.anchor.x, entry.anchor.y)
        if self.AnchorProcReminder then self:AnchorProcReminder(guide, entry, { scale = 1 }, true) end
    else
        guide:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    guide:Show()
end

local function FindEntry(entries, id)
    for _, entry in ipairs(entries) do
        if entry.id == id then return entry end
    end
end

local function OnSpecializationChanged(self, _, unit)
    if issecretvalue and issecretvalue(unit) then return end
    if unit and unit ~= "player" then return end
    self:StopPreview(self.previewState.mode == "off")
    if self.RefreshOptions then self:RefreshOptions() end
end

local function OnPreviewCombat(self)
    -- Options may already have stopped TEST earlier in this event snapshot.
    if self.previewState.mode == "off" then return end
    self:StopPreview()
    if self.RefreshMobilityOptions then self:RefreshMobilityOptions() end
end

function addon:GetPreviewState()
    return self.previewState
end

local function ProcSample(frame)
    return frame.previewKind == "proc" or (frame.reminderEntry and frame.reminderEntry.kind == "proc")
end

local function Quarantined(self)
    return self.IsProcQuarantined and self:IsProcQuarantined()
end

function addon:GetProcPreviewRetryBlocker()
    local pool = self.reminderFrames and self.reminderFrames.preview or {}
    for id in pairs(self.procPreviewFrameAttempts or {}) do
        local frame = pool[id]
        if not frame or not frame.procPreviewReady then return "reload-required" end
        if frame.procGuidanceAttempted and not (frame.guidance and frame.guidance.procGuidanceReady) then
            return "reload-required"
        end
    end
end

function addon:StopProcPreview()
    local clean = true
    -- This is a Proc-only cleanup boundary: neither the global preview session
    -- nor a Mobility/Free Move sample is changed by Proc isolation.
    for _, frame in pairs(self.previewFrames) do
        if ProcSample(frame) then
            local hidden = pcall(frame.Hide, frame)
            clean = hidden and clean
            if frame.guidance then
                hidden = pcall(frame.guidance.Hide, frame.guidance)
                clean = hidden and clean
            end
        end
    end
    if self.StopProcArtworkPreview then
        local ok, stopped = pcall(self.StopProcArtworkPreview, self)
        clean = ok and stopped ~= false and clean
    end
    return clean
end

local function CleanupProcSamples(self)
    if self.RunProcSafe and not Quarantined(self) then
        -- Nested artwork failures and the outer incomplete cleanup belong to
        -- one user operation and consume only one failure-budget entry.
        return self:RunProcSafe("preview", function()
            if not self:StopProcPreview() then error("Proc preview cleanup is incomplete.", 0) end
        end)
    end
    return self:StopProcPreview()
end

function addon:StopPreview(skipLiveRefresh)
    self.previewState.mode = "off"
    self.previewState.styleKey = nil
    CleanupProcSamples(self)
    for _, frame in pairs(self.previewFrames) do
        if not ProcSample(frame) then
            frame:Hide()
            if frame.guidance then frame.guidance:Hide() end
        end
    end
    self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecializationChanged)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED", OnPreviewCombat)
    -- Re-query the live APIs, not a pre-preview snapshot. Options may be closed.
    if not skipLiveRefresh and self.RefreshMobility then self:RefreshMobility() end
    if not skipLiveRefresh and self.RenderProcState then self:RenderProcState() end
    if not skipLiveRefresh and self.RenderFreeMoveState then self:RenderFreeMoveState() end
end

local function RenderSample(self, entry)
    local frame = self:AcquireReminderFrame(entry, "preview")
    frame.previewKind = entry.kind
    self.previewFrames[entry.id] = frame
    self:RenderReminder(frame, entry, self:GetLocalizedPreviewContent(entry), true)
    if entry.kind == "proc" and self.RenderProcArtworkPreview and self:GetReminderEnabled(entry) then
        self:RenderProcArtworkPreview(entry)
    end
end

function addon:RefreshPreview(appearanceOnly)
    local state = self.previewState
    if state.mode == "off" then return end
    if not self.optionsFrame or not self.optionsFrame:IsShown() then
        self:StopPreview()
        return
    end

    local entries = self:GetPreviewEntries()
    if #entries == 0 then self:StopPreview(); return end
    if not FindEntry(entries, state.entryId) then
        state.entryId, state.styleKey = entries[1].id, nil
    end
    CleanupProcSamples(self)
    for _, frame in pairs(self.previewFrames) do
        if not ProcSample(frame) then
            frame:Hide()
            if frame.guidance then frame.guidance:Hide() end
        end
    end
    -- Rendering only runs from explicit settings actions or a spec-change event.
    -- Samples are fixed values; no ticking timer, polling, or OnUpdate is needed.
    for _, entry in ipairs(entries) do
        if state.mode == "all" or state.entryId == entry.id then
            if entry.kind ~= "proc" then RenderSample(self, entry)
            elseif not Quarantined(self) then
                if self.RunProcSafe then
                    local ok = self:RunProcSafe("preview", RenderSample, self, entry)
                    if not ok then self:StopProcPreview() end
                else RenderSample(self, entry) end
            end
        end
    end
    if not appearanceOnly then
        if self.RenderMobilityState then self:RenderMobilityState() end
        if self.RenderProcState then self:RenderProcState() end
        if self.RenderFreeMoveState then self:RenderFreeMoveState() end
    end
end

function addon:SetPreview(mode, entryId, styleKey)
    if mode == "off" then self:StopPreview(); return true end
    if InCombatLockdown() then
        return false, self:Text("Test Mode is unavailable in combat. Live reminders remain active.")
    end
    if mode ~= "single" and mode ~= "all" then
        return false, self:Text("Choose a valid Test Mode.")
    end
    if not self.optionsFrame or not self.optionsFrame:IsShown() then
        return false, self:Text("Open Options before starting Test Mode.")
    end
    local entries = self:GetPreviewEntries()
    local entry = entryId and FindEntry(entries, entryId) or entries[1]
    if not entry or (entryId and entry.id ~= entryId) then
        return false, self:Text("No defined sample for this specialization and entry.")
    end
    if mode == "single" and entry.kind == "proc" and Quarantined(self) then
        self:StopProcPreview()
        return false, self:Text("Proc testing is unavailable while Proc is quarantined.")
    end
    if styleKey then
        local styleEntry = self.appearanceByKey[styleKey]
        if mode ~= "single" or not styleEntry or styleEntry.kind ~= entry.kind then
            return false, self:Text("Choose an appearance for this sample entry.")
        end
    end
    self.previewState.mode, self.previewState.entryId = mode, entry.id
    self.previewState.styleKey = styleKey
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecializationChanged)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", OnPreviewCombat)
    self:RefreshPreview()
    return true
end

function addon:StartAppearancePreview(key)
    local appearance = self.appearanceByKey[key]
    if not appearance then return false, self:Text("No style context is available.") end
    local entry = appearance.kind == "mobility" and self:GetMobilityEntry()
    if appearance.kind == "proc" then
        local selected = self.optionsFrame and self.optionsFrame.selectedProcEntry
        for _, candidate in ipairs(self:GetPreviewEntries()) do
            if candidate.kind == "proc" and (not entry or candidate.id == selected) then entry = candidate end
        end
    end
    if not entry then return false, self:Text("No defined sample for this context.") end
    return self:SetPreview("single", entry.id, key)
end
