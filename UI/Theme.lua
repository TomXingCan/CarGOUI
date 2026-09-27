local _, addon = ...
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
    local selection = button.themeSelection
    if not selection then
        -- Retail UIPanelButtonNoTooltipTemplate puts Left/Right/Middle in
        -- BACKGROUND. ARTWORK -1 is above those textures and below button text.
        selection = button:CreateTexture(nil, "ARTWORK", nil, -1)
        selection:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        selection:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        button.themeSelection = selection
    end
    local info = self.automaticThemeInfo
    local theme = self.optionBodyThemes[info and info.bodyKey or "neutral"]
    Gradient(selection, theme, self.optionThemeOpacity.selection)
    selection:SetShown(selected == true)
end

local function IsSelectedCategory(panel, button)
    local key = panel.activeCategory == "appearance" and panel.appearanceKind or panel.activeCategory
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
    theme.body:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -76)
    theme.body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -1, 1)
    theme.sidebar = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    theme.sidebar:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -76)
    theme.sidebar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMLEFT", 192, 96)
    theme.footer = panel:CreateTexture(nil, "BACKGROUND", nil, 2)
    theme.footer:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 1, 96)
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
    if record.fill then
        if kind == "content" then Solid(record.fill, body.accent, 0.28)
        else Solid(record.fill, kind == "input" and body.input or body.button, 0.97) end
    end
    for _, line in ipairs(record.border or {}) do Solid(line, body.accent, 0.36) end
    if kind == "menu" or kind == "dialog" then
        control:SetBackdropColor(body.input[1], body.input[2], body.input[3], 1)
        control:SetBackdropBorderColor(body.accent[1], body.accent[2], body.accent[3], 0.65)
    end
    if kind == "input" and control.SetTextColor then control:SetTextColor(unpack(addon.optionThemeText)) end
    for _, method in ipairs({ "GetHighlightTexture", "GetCheckedTexture", "GetThumbTexture" }) do
        local texture = control[method] and control[method](control)
        if texture and texture.SetVertexColor then texture:SetVertexColor(body.accent[1], body.accent[2], body.accent[3]) end
    end
end

function addon:RegisterOptionsThemeControl(panel, control, kind)
    if not panel or not control then return end
    panel.themeControls = panel.themeControls or {}
    if control.optionsThemeRecord then return end
    local record = { control = control, kind = kind, border = {} }
    control.optionsThemeRecord = record
    panel.themeControls[#panel.themeControls + 1] = record
    if kind ~= "menu" and kind ~= "dialog" then
        local layer = (kind == "check" or kind == "slider" or kind == "content") and "BACKGROUND" or "ARTWORK"
        local fill = control:CreateTexture(nil, layer, nil, -2)
        record.fill = fill
        if kind == "content" then
            fill:SetPoint("TOPLEFT", control, "TOPLEFT", 0, -28)
            fill:SetPoint("TOPRIGHT", control, "TOPRIGHT", 0, -28)
            fill:SetHeight(1)
        elseif kind == "slider" then
            fill:SetPoint("LEFT", control, "LEFT", 0, 0)
            fill:SetPoint("RIGHT", control, "RIGHT", 0, 0)
            fill:SetHeight(4)
        else
            fill:SetPoint("TOPLEFT", control, "TOPLEFT", 1, -1)
            fill:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -1, 1)
        end
        if kind ~= "content" and kind ~= "slider" and kind ~= "check" then
            for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
                local border = control:CreateTexture(nil, "ARTWORK", nil, -1)
                if edge == "TOP" or edge == "BOTTOM" then
                    border:SetPoint(edge .. "LEFT", control, edge .. "LEFT", 0, 0)
                    border:SetPoint(edge .. "RIGHT", control, edge .. "RIGHT", 0, 0)
                    border:SetHeight(1)
                else
                    border:SetPoint("TOP" .. edge, control, "TOP" .. edge, 0, 0)
                    border:SetPoint("BOTTOM" .. edge, control, "BOTTOM" .. edge, 0, 0)
                    border:SetWidth(1)
                end
                record.border[#record.border + 1] = border
            end
        end
    end
    local info = self.automaticThemeInfo
    SkinControl(record, self.optionBodyThemes[info and info.bodyKey or "neutral"])
end

local function ApplyWatermark(self, panel, surfaces, body)
    local pattern = self:BuildOptionsThemeMotif(body.motif)
    surfaces.motifKey, surfaces.motifCount = body.motif, #pattern
    for i, line in ipairs(surfaces.motif) do
        local stroke = pattern[i]
        if stroke then
            -- Endpoints define actual native geometry. Rotating WHITE8X8 UVs
            -- on a narrow rectangular texture would not establish that shape.
            line:ClearAllPoints()
            line:SetStartPoint("BOTTOMRIGHT", panel, -122 + stroke[1], 202 + stroke[2])
            line:SetEndPoint("BOTTOMRIGHT", panel, -122 + stroke[3], 202 + stroke[4])
            line:SetThickness(stroke[5])
            line:SetColorTexture(body.accent[1], body.accent[2], body.accent[3], self.optionThemeOpacity.motif)
            line:Show()
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
        Gradient(surfaces.header, header, self.optionThemeOpacity.header)
        self:UpdateBrandingTheme(header.accent)
    end
    if surfaces.bodyKey ~= info.bodyKey then
        surfaces.bodyKey = info.bodyKey
        local opacity = self.optionThemeOpacity
        Gradient(surfaces.body, body, 1)
        Solid(surfaces.sidebar, body.input, 0.60)
        Solid(surfaces.footer, body.input, 0.76)
        panel:SetBackdropColor(body.background[1], body.background[2], body.background[3], 1)
        panel:SetBackdropBorderColor(body.accent[1], body.accent[2], body.accent[3], opacity.border)
        if panel.themeDivider then
            Solid(panel.themeDivider, body.accent, opacity.line)
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
