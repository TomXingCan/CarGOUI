local _, addon = ...

function addon:CreateDisplay()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "CarGOUIFrame", UIParent)
    frame:Hide()
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(false)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetTextColor(0.92, 0.97, 1, 1)
    frame.text = text
    self.frame = frame
end

function addon:ApplySettings()
    local frame, db = self.frame, self.db
    if not frame or not db then
        return
    end

    -- Keep offsets in UIParent units even when changing this frame's scale.
    frame:SetScale(db.scale)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER",
        db.position.x / db.scale, db.position.y / db.scale)

    local text = frame.text
    if not text:SetFont(db.font.face, db.font.size, db.font.outline) then
        -- Localized clients may need their standard font as a fallback.
        text:SetFont(STANDARD_TEXT_FONT or self.defaults.font.face,
            db.font.size, db.font.outline)
    end
    text:SetText("CarGOUI")
    if db.shadow.enabled then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    else
        text:SetShadowColor(0, 0, 0, 0)
        text:SetShadowOffset(0, 0)
    end

    frame:SetSize(math.max(1, text:GetStringWidth()) + 32,
        math.max(1, text:GetStringHeight()) + 16)
    frame:SetShown(db.enabled)
end
