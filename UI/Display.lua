local _, addon = ...

-- Login initializes a renderer pool only. There is no always-visible placeholder
-- and no simulated reminder is placed in a future live runtime's state.
function addon:CreateDisplay()
    self.reminderFrames = self.reminderFrames or {}
end

function addon:ApplyFontSettings(text)
    local db = self.db
    if not text:SetFont(db.font.face, db.font.size, db.font.outline) then
        -- Localized clients may need their standard font as a fallback.
        text:SetFont(STANDARD_TEXT_FONT or self.defaults.font.face,
            db.font.size, db.font.outline)
    end
    if db.shadow.enabled then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    else
        text:SetShadowColor(0, 0, 0, 0)
        text:SetShadowOffset(0, 0)
    end
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
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetJustifyH("CENTER")
    frame.text:SetTextColor(0.92, 0.97, 1, 1)
    pool[entry.id] = frame
    return frame
end

-- Shared rendering boundary for sample state now and real reminder state later.
-- The caller owns content; this function never queries or stores live state.
-- Proc output is only a timer. Labels/textures/crosshairs belong to Test Mode.
function addon:RenderReminder(frame, entry, content, testMode)
    local db = self.db
    local setting = db.reminders and db.reminders[entry.id]
    local position = setting and setting.position or { x = 0, y = 0 }
    local x = entry.anchor.x + db.position.x + position.x
    local y = entry.anchor.y + db.position.y + position.y
    frame:SetScale(db.scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", x / db.scale, y / db.scale)

    self:ApplyFontSettings(frame.text)
    local text = content.timer or ""
    if entry.kind == "mobility" and content.message then
        text = content.message .. "\n" .. text
    end
    frame.text:SetText(text)
    frame:SetSize(math.max(1, frame.text:GetStringWidth()) + 8,
        math.max(1, frame.text:GetStringHeight()) + 8)
    if self.UpdatePreviewGuidance then
        self:UpdatePreviewGuidance(frame, entry, testMode and db.enabled)
    end
    frame:SetShown(db.enabled and text ~= "")
end

function addon:ApplySettings()
    if not self.db then return end
    if self.RefreshPreview then self:RefreshPreview() end
end
