local _, addon = ...
local events = { "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "UNIT_FACTION", "NEUTRAL_FACTION_SELECT_RESULT" }

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
    local spec = classToken == "MAGE" and specID and addon.optionThemeSpecs[specID]
    local key, fallback = "neutral", "This identity has no dedicated theme."
    if classToken == "MAGE" then
        key = "mage"
        if faction ~= "Alliance" and faction ~= "Horde" then
            fallback = "No selected faction; using the Mage fallback."
        elseif not spec then
            fallback = specID and "This specialization has no dedicated theme." or "No selected specialization; using the Mage fallback."
        else
            key, fallback = string.lower(faction) .. "_" .. spec.key, nil
        end
    elseif not classToken or not addon.optionThemeClassNames[classToken] then
        fallback = "Player identity is unavailable; using the neutral fallback."
    end
    local theme = addon.optionThemes[key]
    return theme, {
        mode = "Automatic", faction = faction, class = addon.optionThemeClassNames[classToken] or "Unknown",
        specialization = spec and spec.label or (specID and ("Unmapped (" .. specID .. ")") or "Not selected"),
        palette = theme.label, themeKey = key, fallback = fallback,
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
    local _, info = ResolveTheme()
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
    local theme = self.optionThemes[info and info.themeKey or "neutral"]
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
    local theme = { motif = {} }
    panel.theme = theme
    theme.header = header:CreateTexture(nil, "BACKGROUND", nil, -1)
    theme.header:SetAllPoints(header)
    for i = 1, 8 do
        local texture = header:CreateTexture(nil, "BACKGROUND", nil, 0)
        texture:Hide()
        theme.motif[i] = texture
    end
    for _, button in ipairs(panel.categories) do
        self:ApplyOptionsCategoryTheme(button, IsSelectedCategory(panel, button))
    end
    return theme
end

local function OnThemeIdentityChanged(self, event, unit)
    if event == "UNIT_FACTION" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if not IsPublic(unit) or (unit ~= nil and unit ~= "player") then return end
    end
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
    local theme, info = ResolveTheme()
    self.automaticThemeInfo = info
    WatchIdentity(self, panel, true)
    if surfaces.key ~= info.themeKey then
        surfaces.key = info.themeKey
        local opacity = self.optionThemeOpacity
        Gradient(surfaces.header, theme, opacity.header)
        panel:SetBackdropColor(theme.background[1], theme.background[2], theme.background[3], 0.98)
        panel:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], opacity.border)
        if panel.themeDivider then
            panel.themeDivider:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], opacity.line)
        end
        self:UpdateBrandingTheme(theme.accent)
        local pattern = self.optionThemeMotifs[theme.motif] or {}
        for i, texture in ipairs(surfaces.motif) do
            local stroke = pattern[i]
            if stroke then
                texture:ClearAllPoints()
                texture:SetPoint("CENTER", panel.brandingHeader, "TOPLEFT", 346 + stroke[1], -38 + stroke[2])
                texture:SetSize(stroke[3], 1)
                texture:SetRotation(stroke[4] * math.pi / 180)
                texture:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], opacity.motif)
                texture:Show()
            else texture:Hide() end
        end
        for _, button in ipairs(panel.categories) do
            self:ApplyOptionsCategoryTheme(button, IsSelectedCategory(panel, button))
        end
    end
    if self.RefreshOptionsThemeLabels then self:RefreshOptionsThemeLabels(info) end
    return true
end

function addon:StopOptionsTheme()
    local panel = self.optionsFrame
    if panel then WatchIdentity(self, panel, false) end
end
