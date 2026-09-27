local addonName, addon = ...
local assetPath = "Interface\\AddOns\\" .. addonName .. "\\Media\\Branding\\"

-- Shared art/mask UV rectangle [4,7,508,120] in their 512x128 canvases.
-- Preserve this content ratio inside a 224x44 slot; never stretch the letters.
local wordmarkUV = { 4 / 512, 508 / 512, 7 / 128, 120 / 128 }
local contentWidth, contentHeight = 504, 113
local wordmarkWidth = math.min(224, 44 * contentWidth / contentHeight)
local wordmarkHeight = wordmarkWidth * contentHeight / contentWidth
local accent = { 0.78, 0.94, 1 }

local function ResetHighlight(panel)
    local header = panel.brandingHeader
    if not header then return end
    if panel.titleAnimation and panel.titleAnimation:IsPlaying() then panel.titleAnimation:Stop() end
    header.sweep:SetAlpha(0)
    header.sweep:ClearAllPoints()
    if header.animationMode == "masked-sweep" then
        header.sweep:SetPoint("LEFT", header.wordmark, "LEFT", -header.bandWidth, 0)
    else
        header.sweep:SetPoint("CENTER", header.wordmark, "CENTER", 0, 0)
    end
end

local function OnBrandingCombatChanged(self, event)
    local panel = self.optionsFrame
    if not panel then return end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Do not refresh Options or sample frames in response to decoration events.
        ResetHighlight(panel)
    else
        self:RefreshTitleAnimation()
    end
end

local function WatchCombat(self, enabled)
    local panel = self.optionsFrame
    if panel.brandingCombatEvents == enabled then return end
    panel.brandingCombatEvents = enabled
    local method = enabled and self.RegisterEvent or self.UnregisterEvent
    method(self, "PLAYER_REGEN_DISABLED", OnBrandingCombatChanged)
    method(self, "PLAYER_REGEN_ENABLED", OnBrandingCombatChanged)
end

local function Alpha(group, from, to, duration, delay)
    local animation = group:CreateAnimation("Alpha")
    animation:SetOrder(1)
    animation:SetFromAlpha(from)
    animation:SetToAlpha(to)
    animation:SetDuration(duration)
    animation:SetStartDelay(delay or 0)
    animation:SetSmoothing("IN_OUT")
    return animation
end

function addon:CreateOptionsBranding(panel)
    if panel.brandingHeader then return panel.brandingHeader end
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    header:SetSize(720, 76)
    header:EnableMouse(true)
    panel.brandingHeader = header

    local emblem = header:CreateTexture(nil, "ARTWORK")
    emblem:SetPoint("TOPLEFT", header, "TOPLEFT", 24, -18)
    emblem:SetSize(40, 40)
    emblem:SetTexture(assetPath .. "emblem.tga")
    emblem:SetAlpha(1)
    header.emblem = emblem

    local wordmark = header:CreateTexture(nil, "ARTWORK")
    wordmark:SetPoint("TOPLEFT", header, "TOPLEFT", 76, -16 - (44 - wordmarkHeight) / 2)
    wordmark:SetSize(wordmarkWidth, wordmarkHeight)
    wordmark:SetTexture(assetPath .. "wordmark.tga")
    wordmark:SetTexCoord(unpack(wordmarkUV))
    wordmark:SetAlpha(1)
    header.wordmark = wordmark

    local line = header:CreateTexture(nil, "BORDER")
    line:SetPoint("TOPLEFT", header, "TOPLEFT", 24, -75)
    line:SetSize(672, 1)
    line:SetColorTexture(1, 1, 1, 0.13)
    header.accentLine = line

    local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPRIGHT", header, "TOPRIGHT", -24, -20)
    subtitle:SetSize(250, 18)
    subtitle:SetJustifyH("RIGHT")
    subtitle:SetTextColor(0.68, 0.74, 0.78)
    subtitle:SetText(self.L.options .. " / " .. self.version)
    header.subtitle = subtitle

    local sweep = header:CreateTexture(nil, "OVERLAY")
    sweep:SetAlpha(0)
    sweep:SetBlendMode("ADD")
    header.sweep = sweep
    header.bandWidth = wordmarkWidth * 0.18
    header.animationMode = "glyph-pulse-fallback"
    -- Blizzard's PlayerChoice/Soulbinds sheen uses a fixed same-parent mask and
    -- a translated texture. The mask never inherits the strip's animation.
    if header.CreateMaskTexture and sweep.AddMaskTexture then
        local ok = pcall(function()
            local mask = header:CreateMaskTexture(nil, "ARTWORK")
            header.mask = mask
            mask:SetAllPoints(wordmark)
            local loaded = mask:SetTexture(assetPath .. "wordmark-mask.tga",
                "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            if loaded == false then error("Glyph mask could not be loaded") end
            mask:SetTexCoord(unpack(wordmarkUV))
            sweep:AddMaskTexture(mask)
        end)
        if ok then header.animationMode = "masked-sweep" end
    end

    local group = sweep:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    group:SetToFinalAlpha(false)
    if header.animationMode == "masked-sweep" then
        sweep:SetTexture(assetPath .. "sweep.tga")
        sweep:SetSize(header.bandWidth, wordmarkHeight)
        local travel = group:CreateAnimation("Translation")
        travel:SetOrder(1)
        travel:SetOffset(wordmarkWidth + header.bandWidth, 0)
        travel:SetDuration(1.5)
        travel:SetEndDelay(5)
        travel:SetSmoothing("IN_OUT")
        Alpha(group, 0, 0.22, 0.25)
        Alpha(group, 0.22, 0, 0.25, 1.25):SetEndDelay(5)
    else
        -- Explicit capability fallback: a precomputed glyph highlight breathes;
        -- never pass an unmasked rectangle off as a completed text sweep.
        sweep:SetTexture(assetPath .. "wordmark-mask.tga")
        sweep:SetTexCoord(unpack(wordmarkUV))
        sweep:SetSize(wordmarkWidth, wordmarkHeight)
        Alpha(group, 0, 0.12, 2.4)
        Alpha(group, 0.12, 0, 2.4, 2.4)
    end
    panel.titleAnimation = group
    self:UpdateBrandingTheme(accent)
    ResetHighlight(panel)
    return header
end

function addon:UpdateBrandingTheme(color)
    if type(color) ~= "table" then return false end
    for i = 1, 3 do
        if type(color[i]) ~= "number" or not (color[i] >= 0 and color[i] <= 1) then return false end
    end
    accent = { color[1], color[2], color[3] }
    local panel = self.optionsFrame
    local header = panel and panel.brandingHeader
    if header then
        header.sweep:SetVertexColor(unpack(accent))
        header.accentLine:SetVertexColor(unpack(accent))
    end
    return true
end

function addon:StopTitleAnimation()
    local panel = self.optionsFrame
    if not panel or not panel.brandingHeader then return end
    ResetHighlight(panel)
    WatchCombat(self, false)
end

function addon:RefreshTitleAnimation()
    local panel = self.optionsFrame
    if not panel or not panel.titleAnimation then return end
    local active = panel:IsVisible() and self.db and self.db.options.animatedTitle
    if not active then self:StopTitleAnimation(); return end
    WatchCombat(self, true)
    if InCombatLockdown() then
        ResetHighlight(panel)
    elseif not panel.titleAnimation:IsPlaying() then
        panel.titleAnimation:Play()
    end
end
