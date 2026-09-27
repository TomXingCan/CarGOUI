local _, addon = ...

-- Login initializes a renderer pool only. There is no always-visible placeholder
-- and no simulated reminder is placed in a future live runtime's state.
function addon:CreateDisplay()
    self.reminderFrames = self.reminderFrames or {}
end

function addon:ApplyFontSettings(text, style, entry)
    if not text:SetFont(style.font.face, style.font.size, style.font.outline) then
        -- Localized clients may need their standard font as a fallback.
        text:SetFont(STANDARD_TEXT_FONT or self.factoryReminderStyle.font.face,
            style.font.size, style.font.outline)
    end
    if style.shadow.enabled then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    else
        text:SetShadowColor(0, 0, 0, 0)
        text:SetShadowOffset(0, 0)
    end
    self:ApplyReminderColor(text, entry)
end

function addon:AcquireReminderFrame(entry, channel)
    self:CreateDisplay()
    local pool = self.reminderFrames[channel]
    if not pool then
        pool = {}
        self.reminderFrames[channel] = pool
    end
    if pool[entry.id] then return pool[entry.id] end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    frame:EnableMouse(false)
    frame.entryId = entry.id
    frame.channel = channel
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetJustifyH("CENTER")
    self:ApplyReminderColor(frame.text, entry)
    pool[entry.id] = frame
    return frame
end

-- Shared rendering boundary for sample state now and real reminder state later.
-- The caller owns content; this function never queries or stores live state.
-- Proc output is only a timer. Labels/textures/crosshairs belong to Test Mode.
function addon:LayoutReminder(frame, entry)
    local style = self:GetReminderStyle(frame.styleKey or entry)
    frame.reminderEntry = entry
    local position = self:GetReminderPosition(entry)
    local x = entry.anchor.x + position.x
    local y = entry.anchor.y + position.y
    frame:SetScale(style.scale)
    frame:ClearAllPoints()
    frame:SetPoint(position.anchor or "CENTER", UIParent, position.anchor or "CENTER", x / style.scale, y / style.scale)

    if entry.kind == "proc" and self.AnchorProcReminder then
        self:AnchorProcReminder(frame, entry, style)
    end
    self:ApplyFontSettings(frame.text, style, entry)
end

function addon:RenderReminder(frame, entry, content, testMode)
    frame.styleKey = self:GetReminderStyleKey(entry)
    self:LayoutReminder(frame, entry)
    local enabled = self:GetReminderEnabled(entry)
    local text = content.timer or ""
    if entry.kind == "mobility" and content.message then
        text = entry.textOnly and content.message or (content.message .. "\n" .. text)
    end
    frame.text:SetText(text)
    frame:SetSize(math.max(1, frame.text:GetStringWidth()) + 8,
        math.max(1, frame.text:GetStringHeight()) + 8)
    if self.UpdatePreviewGuidance then
        self:UpdatePreviewGuidance(frame, entry, testMode and enabled)
    end
    frame:SetShown(enabled and text ~= "")
end

-- Styling never re-queries combat state or rebinds its DurationObject/alpha.
-- Only frames belonging to this class/module or class/spec style are touched.
function addon:RefreshReminderStyle(key)
    for _, pool in pairs(self.reminderFrames or {}) do
        for _, frame in pairs(pool) do
            if frame.styleKey == key and frame.reminderEntry then
                if frame.nativeAuraOwned then
                    -- Touch only the public wrapper and our Font object.
                    self:StyleAuraReminder(frame)
                else
                    self:LayoutReminder(frame, frame.reminderEntry)
                end
                if frame.mobilityOwned then
                    local size = self:GetReminderStyle(key).font.size
                    frame:SetSize(size * 16, size * 3)
                    frame.text:SetSize(size * 16, size * 3)
                elseif frame.channel == "preview" then
                    -- Only sample strings enter the ordinary measurement path.
                    frame:SetSize(math.max(1, frame.text:GetStringWidth()) + 8,
                        math.max(1, frame.text:GetStringHeight()) + 8)
                    self:UpdatePreviewGuidance(frame, frame.reminderEntry, frame:IsShown())
                end
            end
        end
    end
end

-- Position ownership is distinct from font ownership: Free move and ordinary
-- Mobility intentionally share one class font, but never translate together.
-- Only public addon wrappers are positioned; native timing/alpha are untouched.
function addon:RefreshReminderPositions(changes)
    for _, pool in pairs(self.reminderFrames or {}) do
        for _, frame in pairs(pool) do
            local entry = frame.reminderEntry
            if entry and self:GetReminderStyleKey(entry) then
                local changed
                if entry.kind == "mobility" then
                    if entry.freeMove then changed = changes.freeMove
                    else changed = changes.mobility end
                elseif entry.kind == "proc" then changed = changes.proc[entry.id] end
                if changed then
                    if frame.nativeAuraOwned then self:StyleAuraReminder(frame)
                    else self:LayoutReminder(frame, entry) end
                    if frame.channel == "preview" then
                        self:UpdatePreviewGuidance(frame, entry, frame:IsShown())
                    end
                end
            end
        end
    end
end

function addon:ApplySettings()
    if not self.db then return end
    if self.ConfigureMobility then self:ConfigureMobility() end
    if self.ConfigureProc then self:ConfigureProc() end
    if self.ConfigureFreeMove then self:ConfigureFreeMove() end
    if self.RefreshPreview then self:RefreshPreview() end
end

-- Live durations never enter RenderReminder's Lua string/measurement path.
-- The native binding owns all time sampling, formatting and expiration text.
function addon:RenderLiveMobility(entry, spellName, duration, visibility, spellID)
    local frame = self:AcquireReminderFrame(entry, "live")
    frame.mobilityOwned = true
    frame.styleKey = self:GetReminderStyleKey(entry, spellID)
    self:LayoutReminder(frame, entry)
    local size = self:GetReminderStyle(frame.styleKey).font.size
    frame:SetSize(size * 16, size * 3)
    frame.text:SetSize(size * 16, size * 3)
    if not frame.durationBinding then
        frame.durationBinding = C_DurationUtil.CreateDurationTextBinding()
    end
    if not self.mobilityFormatter then
        self.mobilityFormatter = C_StringUtil.CreateNumericRuleFormatter()
        self.mobilityFormatter:AddBreakpoint({ threshold = 0, step = 0.1,
            rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f" })
    end
    local binding = frame.durationBinding
    binding:SetFontString(frame.text)
    binding:SetTextFormat("No " .. spellName .. "\n{}", {
        { property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = self.mobilityFormatter },
    })
    binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
    binding:SetUpdateInterval(0.1)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:SetDuration(duration)
    binding:Enable()
    frame.mobilityBindingActive = true
    binding:UpdateFontString()
    -- A duration object may hold restricted timing. Its native evaluation goes
    -- straight to the approved display sink, never to a Lua test or readback.
    -- This is the only writer of live opacity; styling and the timer do not
    -- overwrite it. Ordinary paths explicitly restore opacity before showing.
    if visibility then
        frame:SetAlpha(visibility.duration:EvaluateTotalDuration(visibility.curve,
            Enum.DurationTimeModifier.BaseTime))
    else
        frame:SetAlpha(1)
    end
    frame:Show()
    return frame
end

function addon:HideLiveMobility(except)
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.live or {}) do
        local keep = type(except) == "table" and except[frame.entryId] or frame.entryId == except
        if frame.mobilityOwned and not keep then
            frame:Hide()
            if frame.durationBinding then
                frame.durationBinding:Disable()
                frame.durationBinding:SetToDefaults()
            end
            frame.mobilityBindingActive = false
            -- Overwrite rather than inspect any text supplied by the engine.
            frame.text:SetText("")
        end
    end
end
