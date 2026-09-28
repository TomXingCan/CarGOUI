local _, addon = ...
local D = addon.DesignSystem
-- Identity can become available after the window opens (login / talent load).
-- Subscribe only while shown; these callbacks never start a gameplay adapter.
local events = { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "UNIT_FACTION",
    "NEUTRAL_FACTION_SELECT_RESULT", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }

local function IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function ReadIdentity()
    local faction, classToken, specID
    if UnitFactionGroup then faction = UnitFactionGroup("player") end
    if not IsPublic(faction) or type(faction) ~= "string" then faction = "Unknown" end
    if faction ~= "Alliance" and faction ~= "Horde" and faction ~= "Neutral" then faction = "Unknown" end
    if UnitClass then local _, token = UnitClass("player"); classToken = token end
    if not IsPublic(classToken) or type(classToken) ~= "string" then classToken = nil end
    local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
    local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
    if getSpec and getInfo then
        local index = getSpec()
        if IsPublic(index) and type(index) == "number" and index >= 1 and index <= 5 and index % 1 == 0 then
            local id = getInfo(index)
            if IsPublic(id) and type(id) == "number" and id > 0 and id < 10000 and id % 1 == 0 then specID = id end
        end
    end
    return faction, classToken, specID
end

local function ResolveTheme()
    local faction, classToken, specID = ReadIdentity()
    local class = classToken and addon.optionThemeClasses[classToken]
    local spec = class and specID and class.specs[specID]
    local headerKey = faction == "Alliance" and "alliance" or faction == "Horde" and "horde" or "neutral"
    local bodyKey, fallback, coverage = "neutral", nil, "neutral fallback"
    if class then
        bodyKey = spec and spec.key or class.key
        coverage = spec and "specialization" or "class fallback"
        if spec then fallback = nil
        elseif specID then
            coverage = "unmapped specialization"
            fallback = "Unmapped specialization; using this class's base Body theme."
        else fallback = "No specialization selected; using this class's base Body theme." end
    else
        fallback = "Class identity is unavailable; using the neutral Body fallback."
    end
    if headerKey == "neutral" then
        fallback = (fallback and (fallback .. " ") or "") .. "No known faction; using the neutral Header."
    end
    local header, body = addon.optionHeaderThemes[headerKey], addon.optionBodyThemes[bodyKey]
    return header, body, {
        mode = "Automatic", faction = faction, class = addon.optionThemeClassNames[classToken] or "Unknown",
        classToken = classToken, specID = specID, coverage = coverage,
        specialization = spec and spec.label or (specID and ("Unmapped (" .. specID .. ")") or "Not selected"),
        headerKey = headerKey, bodyKey = bodyKey, headerPalette = header.label, bodyPalette = body.label,
        palette = header.label .. " / " .. body.label, themeKey = headerKey .. "_" .. bodyKey, fallback = fallback,
    }
end

local function Gradient(texture, theme, alpha)
    texture:SetColorTexture(1, 1, 1, 1)
    if texture.SetGradient and CreateColor then
        texture:SetGradient("HORIZONTAL",
            CreateColor(theme.left[1], theme.left[2], theme.left[3], alpha),
            CreateColor(theme.right[1], theme.right[2], theme.right[3], alpha))
    else
        -- Only a capability fallback for older clients; Retail 12.1 has SetGradient.
        texture:SetColorTexture(theme.left[1], theme.left[2], theme.left[3], alpha)
    end
end

function addon:GetAutomaticThemeInfo()
    if self.automaticThemeInfo then return self.automaticThemeInfo end
    local _, _, info = ResolveTheme()
    return info
end

function addon:ApplyOptionsCategoryTheme(button, selected)
    if button.SetSelected then button:SetSelected(selected); return end
    local selection = button.themeSelection
    if not selection then
        -- The selected layer is addon-owned and stays below its label.
        selection = button:CreateTexture(nil, "ARTWORK", nil, -1)
        selection:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        selection:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        button.themeSelection = selection
    end
    D.ApplyGradient(selection, .20)
    selection:SetShown(selected == true)
end

local function IsSelectedCategory(panel, button)
    local descriptor = addon.optionsPageRegistry and addon.optionsPageRegistry[panel.activeCategory]
    local parent = descriptor and descriptor.navParent
    local key = type(parent) == "function" and parent(addon, panel, descriptor) or parent or panel.activeCategory
    return button.key == key
end

function addon:CreateOptionsTheme(panel)
    if panel.theme then return panel.theme end
    local header = panel.brandingHeader
    local theme = { motif = {}, watermarkSize = self.optionThemeWatermarkSize }
    panel.theme = theme
    theme.header = header:CreateTexture(nil, "BACKGROUND", nil, -1)
    theme.header:SetAllPoints(header)
    -- BackdropTemplate's center occupies BACKGROUND sublevel 0. These surfaces
    -- sit above it while remaining below BORDER, child widgets and text.
    theme.body = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
    theme.body:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -D.headerHeight)
    theme.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    theme.sidebar = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    theme.sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -D.headerHeight)
    theme.sidebar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", D.sidebarWidth, D.footerHeight)
    theme.footer = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    theme.footer:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 1, D.footerHeight)
    theme.footer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    -- Native Lines do not create input frames. Their BACKGROUND layer lies below
    -- child-page controls and the panel's text; no overlay frame is needed.
    for i = 1, self.optionThemeMotifLimit do
        local line = panel:CreateLine(nil, "BACKGROUND", nil, 3)
        line:Hide()
        theme.motif[i] = line
    end
    for _, button in ipairs(panel.categories) do
        self:ApplyOptionsCategoryTheme(button, IsSelectedCategory(panel, button))
    end
    return theme
end

local function Solid(texture, color, alpha)
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

local function SkinControl(record, body)
    local control, kind = record.control, record.kind
    if control.cuiRefresh then control:cuiRefresh(); return end
    if record.fill then
        if kind == "content" then D.ApplyGradient(record.fill, .35)
        else D.Fill(record.fill, kind == "input" and "surfaceInput" or kind == "section" and "surfaceCard" or "surfaceRaised") end
    end
    for _, line in ipairs(record.border or {}) do D.Fill(line, "borderSubtle", kind == "section" and .55 or 1) end
    if kind == "input" and control.SetTextColor then control:SetTextColor(unpack(D.textPrimary)) end
end

function addon:RegisterOptionsThemeControl(panel, control, kind)
    if not panel or not control then return end
    panel.themeControls = panel.themeControls or {}
    if control.optionsThemeRecord then return end
    local record
    if kind == "content" then
        -- Page containers stay transparent so the root identity watermark is
        -- visible. Only cards and controls own full surface backgrounds.
        local divider = control:CreateTexture(nil, "BACKGROUND")
        divider:SetPoint("TOPLEFT", control, "TOPLEFT", 0, -28)
        divider:SetPoint("TOPRIGHT", control, "TOPRIGHT", 0, -28)
        divider:SetHeight(1)
        record = { fill = divider, border = {} }
    elseif kind == "check" or kind == "slider" then record = { fill = control.track, border = {} }
    else record = D.Skin(control, kind) end
    record.control, record.kind = control, kind
    control.optionsThemeRecord = record
    panel.themeControls[#panel.themeControls + 1] = record
    local info = self.automaticThemeInfo
    SkinControl(record, self.optionBodyThemes[info and info.bodyKey or "neutral"])
end

-- Clip each native line to the quiet lower-right background area. The source
-- class/spec geometry remains unchanged and no overlay frame captures input.
local function CropStroke(x1, y1, x2, y2)
    local dx, dy, first, last = x2 - x1, y2 - y1, 0, 1
    local function Edge(p, q)
        if p == 0 then return q >= 0 end
        local ratio = q / p
        if p < 0 then if ratio > last then return false end; first = math.max(first, ratio)
        else if ratio < first then return false end; last = math.min(last, ratio) end
        return true
    end
    if not Edge(-dx, x1 + 300) or not Edge(dx, -24 - x1)
        or not Edge(-dy, y1 - 80) or not Edge(dy, 310 - y1) or first >= last then return end
    return x1 + dx * first, y1 + dy * first, x1 + dx * last, y1 + dy * last
end

local function ApplyWatermark(self, panel, surfaces, body)
    local pattern = self:BuildOptionsThemeMotif(body.motif)
    surfaces.motifKey, surfaces.motifCount, surfaces.motifVisibleCount = body.motif, #pattern, 0
    for i, line in ipairs(surfaces.motif) do
        local stroke = pattern[i]
        local x1, y1, x2, y2
        if stroke then
            x1, y1, x2, y2 = CropStroke(-12 + stroke[1] * 1.45, 155 + stroke[2] * 1.45,
                -12 + stroke[3] * 1.45, 155 + stroke[4] * 1.45)
        end
        if x1 then
            -- Endpoints define actual native geometry. Rotating WHITE8X8 UVs
            -- on a narrow rectangular texture would not establish that shape.
            line:ClearAllPoints()
            line:SetStartPoint("BOTTOMRIGHT", panel, x1, y1)
            line:SetEndPoint("BOTTOMRIGHT", panel, x2, y2)
            line:SetThickness(stroke[5])
            line:SetColorTexture(body.accent[1], body.accent[2], body.accent[3], self.optionThemeOpacity.motif * .55)
            line:Show()
            surfaces.motifVisibleCount = surfaces.motifVisibleCount + 1
        else line:Hide() end
    end
end

local function OnThemeIdentityChanged(self, event, unit)
    if event == "UNIT_FACTION" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not IsPublic(unit) or (unit ~= nil and unit ~= "player") then return end
    end
    if self.RefreshSettingsTransferPage then self:RefreshSettingsTransferPage() end
    self:RefreshOptionsTheme()
end

local function WatchIdentity(self, panel, enabled)
    if panel.themeWatching == enabled then return end
    panel.themeWatching = enabled
    local method = enabled and self.RegisterEvent or self.UnregisterEvent
    for _, event in ipairs(events) do method(self, event, OnThemeIdentityChanged) end
end

function addon:RefreshOptionsTheme()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return false end
    local surfaces = self:CreateOptionsTheme(panel)
    local header, body, info = ResolveTheme()
    self.automaticThemeInfo = info
    WatchIdentity(self, panel, true)
    surfaces.key = info.themeKey
    if surfaces.headerKey ~= info.headerKey then
        surfaces.headerKey = info.headerKey
        Gradient(surfaces.header, header, .18)
        self:UpdateBrandingTheme(header.accent)
    end
    if surfaces.bodyKey ~= info.bodyKey then
        surfaces.bodyKey = info.bodyKey
        local opacity = self.optionThemeOpacity
        -- Identity is a restrained watermark/tint. Shared controls retain the
        -- same graphite surfaces and teal-to-violet interaction language.
        Gradient(surfaces.body, { left = D.surfaceBase, right = D.surfaceRaised }, 1)
        Solid(surfaces.sidebar, D.surfaceBase, .94)
        Solid(surfaces.footer, D.surfaceRaised, .98)
        if panel.SetBackdropColor then panel:SetBackdropColor(unpack(D.surfaceBase)) end
        if panel.SetBackdropBorderColor then panel:SetBackdropBorderColor(unpack(D.borderSubtle)) end
        if panel.themeDivider then
            D.ApplyGradient(panel.themeDivider, .55)
        end
        ApplyWatermark(self, panel, surfaces, body)
        for _, record in ipairs(panel.themeControls or {}) do SkinControl(record, body) end
        for _, button in ipairs(panel.categories) do
            self:ApplyOptionsCategoryTheme(button, IsSelectedCategory(panel, button))
        end
    end
    return true
end

function addon:StopOptionsTheme()
    local panel = self.optionsFrame
    if panel then WatchIdentity(self, panel, false) end
end
