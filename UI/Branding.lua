local addonName, addon = ...
local assetPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\Branding\\"

-- Native alpha animation only: no timers, events, or per-frame Lua callbacks.
function addon:CreateOptionsBranding(panel)
    if panel.brandingHeader then return panel.brandingHeader end
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -8)
    header:SetSize(692, 66)
    header:EnableMouse(true)

    local background = header:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(header)
    background:SetTexture(assetPath .. "header.tga")

    local glow = header:CreateTexture(nil, "ARTWORK")
    glow:SetPoint("TOPLEFT", header, "TOPLEFT", 70, -2)
    glow:SetSize(250, 60)
    glow:SetTexture(assetPath .. "glow.tga")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.35)
    header.glow = glow

    local emblem = header:CreateTexture(nil, "OVERLAY")
    emblem:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -1)
    emblem:SetSize(64, 64)
    emblem:SetTexture(assetPath .. "emblem.tga")

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", header, "TOPLEFT", 90, -7)
    title:SetSize(260, 32)
    if not title:SetFont("Fonts\\FRIZQT__.ttf", 28, "") then
        title:SetFont(STANDARD_TEXT_FONT, 28, "")
    end
    title:SetJustifyH("LEFT")
    title:SetTextColor(0.94, 0.84, 0.61)
    title:SetShadowColor(0.04, 0.29, 0.48, 0.9)
    title:SetShadowOffset(1, -1)
    title:SetText("CarGOUI")
    header.wordmark = title

    local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", header, "TOPLEFT", 92, -42)
    subtitle:SetSize(230, 16)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.48, 0.75, 0.88)
    subtitle:SetText("OPTIONS  /  ALPHA 0.1")

    local hint = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", header, "TOPRIGHT", -18, -26)
    hint:SetSize(180, 18)
    hint:SetJustifyH("RIGHT")
    hint:SetTextColor(0.56, 0.65, 0.71)
    hint:SetText("Drag header to move")

    local animation = glow:CreateAnimationGroup()
    local brighten = animation:CreateAnimation("Alpha")
    brighten:SetFromAlpha(0.25)
    brighten:SetToAlpha(0.58)
    brighten:SetDuration(2.4)
    brighten:SetOrder(1)
    brighten:SetSmoothing("IN_OUT")
    local soften = animation:CreateAnimation("Alpha")
    soften:SetFromAlpha(0.58)
    soften:SetToAlpha(0.25)
    soften:SetDuration(2.4)
    soften:SetOrder(2)
    soften:SetSmoothing("IN_OUT")
    animation:SetLooping("REPEAT")
    panel.brandingHeader = header
    panel.titleAnimation = animation
    return header
end

function addon:StopTitleAnimation()
    local panel = self.optionsFrame
    if not panel or not panel.titleAnimation then return end
    panel.titleAnimation:Stop()
    -- Stop restores an animation target's base alpha; keep the fallback explicit.
    panel.brandingHeader.glow:SetAlpha(0.35)
end

function addon:RefreshTitleAnimation()
    local panel = self.optionsFrame
    if not panel or not panel.titleAnimation then return end
    if panel:IsShown() and self.db and self.db.options.animatedTitle then
        if not panel.titleAnimation:IsPlaying() then panel.titleAnimation:Play() end
    else
        self:StopTitleAnimation()
    end
end
