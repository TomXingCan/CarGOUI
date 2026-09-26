local _, addon = ...

addon.previewState = { mode = "off" }
addon.previewFrames = {}

local function CreateGuidance(frame, entry)
    local guide = CreateFrame("Frame", nil, frame)
    -- A child's background would otherwise draw above its parent's timer text.
    guide:SetFrameLevel(frame:GetFrameLevel() - 1)
    guide:EnableMouse(false)
    guide:SetPoint("CENTER", frame, "CENTER", 0, 0)
    local region = entry.guide
    guide:SetSize(region and region.width or 150, region and region.height or 64)
    if region then
        -- Native shape is faint, static, TEST-only guidance. Never feed sample
        -- events into Blizzard's overlay frame or start its animation/sounds.
        local shape = guide:CreateTexture(nil, "BACKGROUND")
        shape:SetAllPoints(guide)
        shape:SetTexture(region.texture)
        shape:SetTexCoord(region.flipH and 1 or 0, region.flipH and 0 or 1, 0, 1)
        shape:SetVertexColor(0.65, 0.83, 1, 0.35)
        guide.shape = shape
    end

    local label = guide:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOP", guide, "BOTTOM", 0, -6)
    label:SetWidth(240)
    label:SetJustifyH("CENTER")
    label:SetTextColor(0.55, 0.8, 1, 1)
    label:SetText("TEST: " .. entry.label)
    guide.label = label
    for _, arm in ipairs({ { -15, 0, 6, 1 }, { 15, 0, 6, 1 },
        { 0, -15, 1, 6 }, { 0, 15, 1, 6 } }) do
        local mark = guide:CreateTexture(nil, "BORDER")
        mark:SetColorTexture(0.85, 0.7, 0.35, 0.8)
        mark:SetSize(arm[3], arm[4])
        mark:SetPoint("CENTER", guide, "CENTER", arm[1], arm[2])
    end
    frame.guidance = guide
    return guide
end

function addon:UpdatePreviewGuidance(frame, entry, enabled)
    if not enabled then
        if frame.guidance then frame.guidance:Hide() end
        return
    end
    local guide = frame.guidance or CreateGuidance(frame, entry)
    guide.label:SetText("TEST: " .. entry.label)
    -- Typography scaling must not change the size of the stock region guide.
    guide:SetScale(1 / self:GetReminderStyle(frame.styleKey or entry).scale)
    guide:ClearAllPoints()
    if entry.kind == "proc" then
        -- Position edits move the timer relative to Blizzard's stationary shape.
        -- A guide that followed that timer would hide the effect of the offset.
        guide:SetPoint("CENTER", UIParent, "CENTER", entry.anchor.x, entry.anchor.y)
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
    self:RefreshPreview()
    if self.RefreshOptions then self:RefreshOptions() end
end

local function OnPreviewCombat(self)
    self:StopPreview()
    if self.RefreshMobilityOptions then self:RefreshMobilityOptions() end
end

function addon:GetPreviewState()
    return self.previewState
end

function addon:StopPreview(skipLiveRefresh)
    self.previewState.mode = "off"
    self.previewState.styleKey = nil
    for _, frame in pairs(self.previewFrames) do
        frame:Hide()
        if frame.guidance then frame.guidance:Hide() end
    end
    self:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnSpecializationChanged)
    self:UnregisterEvent("PLAYER_REGEN_DISABLED", OnPreviewCombat)
    -- Re-query the live APIs, not a pre-preview snapshot. Options may be closed.
    if not skipLiveRefresh and self.RefreshMobility then self:RefreshMobility() end
end

function addon:RefreshPreview()
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
    for _, frame in pairs(self.previewFrames) do
        frame:Hide()
        if frame.guidance then frame.guidance:Hide() end
    end
    -- Rendering only runs from explicit settings actions or a spec-change event.
    -- Samples are fixed values; no ticking timer, polling, or OnUpdate is needed.
    for _, entry in ipairs(entries) do
        if state.mode == "all" or state.entryId == entry.id then
            local frame = self:AcquireReminderFrame(entry, "preview")
            self.previewFrames[entry.id] = frame
            self:RenderReminder(frame, entry, entry.sample, true)
        end
    end
    if self.RenderMobilityState then self:RenderMobilityState() end
end

function addon:SetPreview(mode, entryId, styleKey)
    if mode == "off" then self:StopPreview(); return true end
    if InCombatLockdown() then
        return false, "Test Mode is unavailable in combat. Live Mobility remains active."
    end
    if mode ~= "single" and mode ~= "all" then
        return false, "Choose a valid Test Mode."
    end
    if not self.optionsFrame or not self.optionsFrame:IsShown() then
        return false, "Open Options before starting Test Mode."
    end
    local entries = self:GetPreviewEntries()
    local entry = entryId and FindEntry(entries, entryId) or entries[1]
    if not entry or (entryId and entry.id ~= entryId) then
        return false, "No defined sample for this specialization and entry."
    end
    if styleKey then
        local styleEntry = self.appearanceByKey[styleKey]
        if mode ~= "single" or not styleEntry or styleEntry.kind ~= entry.kind then
            return false, "Choose an appearance for this sample entry."
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
    if not appearance then return false, "No style context is available." end
    local entry = appearance.kind == "mobility" and self:GetMobilityEntry()
    if appearance.kind == "proc" then
        local selected = self.optionsFrame and self.optionsFrame.selectedProcEntry
        for _, candidate in ipairs(self:GetPreviewEntries()) do
            if candidate.kind == "proc" and (not entry or candidate.id == selected) then entry = candidate end
        end
    end
    if not entry then return false, "No defined sample for this context." end
    return self:SetPreview("single", entry.id, key)
end
