local _, addon = ...

-- Page descriptors own construction and navigation metadata. The shell knows
-- only the shared grid, so future production editors need no global redesign.
addon.optionsPageRegistry = {}

local function Resolve(value, panel, descriptor)
    if type(value) == "function" then return value(addon, panel, descriptor) end
    return value
end

function addon:GetOptionsPageTitle(descriptor, panel)
    return Resolve(descriptor.title, panel, descriptor) or self.L[descriptor.key] or descriptor.key
end

function addon:GetOptionsPageDescriptors()
    local result = {}
    for _, descriptor in pairs(self.optionsPageRegistry) do result[#result + 1] = descriptor end
    table.sort(result, function(a, b)
        if a.order == b.order then return a.key < b.key end
        return a.order < b.order
    end)
    return result
end

function addon:RegisterOptionsPage(descriptor)
    if type(descriptor) ~= "table" or type(descriptor.key) ~= "string"
        or not descriptor.key:match("^[A-Za-z][A-Za-z0-9_]*$")
        or type(descriptor.builder) ~= "function" or type(descriptor.order) ~= "number"
        or descriptor.order ~= descriptor.order or math.abs(descriptor.order) == math.huge
        or self.optionsPageRegistry[descriptor.key] then return false end
    local saved = {}
    for key, value in pairs(descriptor) do saved[key] = value end
    self.optionsPageRegistry[saved.key] = saved
    local panel = self.optionsFrame
    if panel then
        panel.navigationDirty = true
        if panel:IsShown() and not InCombatLockdown() then self:RefreshOptionsNavigation() end
    end
    return true
end

function addon:BuildOptionsPage(key)
    local panel, descriptor = self.optionsFrame, self.optionsPageRegistry[key]
    if not panel or not descriptor then return end
    local page = panel.pages[key]
    if not page then
        page = CreateFrame("Frame", nil, panel.contentContainer)
        page:SetPoint("TOPLEFT", panel.contentContainer, "TOPLEFT", 0, 0)
        page:SetSize(panel.shellGrid.contentWidth, panel.shellGrid.contentHeight)
        page:Hide()
        page.descriptor = descriptor
        page.title = self.CUI.Label(page, self:GetOptionsPageTitle(descriptor, panel), 0, 0,
            panel.shellGrid.contentWidth, 26, "GameFontNormalLarge")
        panel.pages[key] = page
        self:RegisterOptionsDragSurface(page)
        if self.RegisterOptionsThemeControl then self:RegisterOptionsThemeControl(panel, page, "content") end
    end
    if not page.built then
        page.built = true
        descriptor.builder(self, panel, page, descriptor)
    end
    return page
end

function addon:RefreshOptionsNavigation()
    local panel = self.optionsFrame
    if not panel then return end
    panel.categoryButtons = panel.categoryButtons or {}
    local categories, index = {}, 0
    for _, descriptor in ipairs(self:GetOptionsPageDescriptors()) do
        if not descriptor.lazy then self:BuildOptionsPage(descriptor.key) end
        if not descriptor.hidden then
            index = index + 1
            local key = descriptor.key
            local button = panel.categoryButtons[key]
            if not button then
                button = self.CUI.Button(panel.sidebarContent, self:GetOptionsPageTitle(descriptor, panel),
                    0, 0, panel.shellGrid.navigationWidth, function() addon:SelectOptionsCategory(key) end)
                button.key, button.descriptor = key, descriptor
                if descriptor.icon then
                    button.iconSlot = button:CreateTexture(nil, "ARTWORK")
                    button.iconSlot:SetSize(16, 16)
                    button.iconSlot:SetPoint("LEFT", button, "LEFT", 12, 0)
                    button.iconSlot:SetTexture(descriptor.icon)
                end
                panel.categoryButtons[key] = button
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", panel.sidebarContent, "TOPLEFT", 0, -(index - 1) * 46)
            button:SetSize(panel.shellGrid.navigationWidth, 38)
            button:SetText(self:GetOptionsPageTitle(descriptor, panel))
            local label, inset = button:GetFontString(), button.iconSlot and 36 or 12
            label:ClearAllPoints()
            label:SetPoint("LEFT", button, "LEFT", inset, 0)
            label:SetSize(panel.shellGrid.navigationWidth - inset - 12, 34)
            label:SetJustifyH("LEFT")
            button:Show()
            categories[#categories + 1] = button
        end
    end
    panel.categories, panel.navigationDirty = categories, nil
    panel.sidebarContent:SetHeight(math.max(panel.shellGrid.contentHeight, index * 46))
    panel.sidebarScroll:RefreshRange()
    self:RefreshOptionsNavigationSelection()
end

function addon:RefreshOptionsNavigationSelection()
    local panel = self.optionsFrame
    if not panel then return end
    local descriptor = self.optionsPageRegistry[panel.activeCategory]
    local selectedKey = descriptor and Resolve(descriptor.navParent, panel, descriptor) or panel.activeCategory
    for _, button in ipairs(panel.categories) do
        local selected = button.key == selectedKey
        button:SetSelected(selected)
        if self.ApplyOptionsCategoryTheme then self:ApplyOptionsCategoryTheme(button, selected) end
    end
end

function addon:CreateOptionsShell(panel)
    local tokens, CUI = self.DesignSystem, self.CUI
    local width, height = tokens.Token("shellWidth"), tokens.Token("shellHeight")
    local header, sidebar, padding = tokens.Token("headerHeight"), tokens.Token("sidebarWidth"), tokens.Token("contentPadding")
    local footer, gap = tokens.Token("footerHeight"), tokens.Token("sectionGap")
    panel.shellGrid = { width = width, height = height, headerHeight = header, sidebarWidth = sidebar,
        padding = padding, footerHeight = footer, contentX = sidebar + padding, contentY = header + padding,
        contentWidth = width - sidebar - padding * 2,
        contentHeight = height - header - padding - footer - gap,
        navigationWidth = sidebar - padding * 2 }
    local grid = panel.shellGrid
    panel:SetSize(width, height)
    tokens.Skin(panel, "surface")
    panel.contentContainer = CreateFrame("Frame", nil, panel)
    panel.contentContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", grid.contentX, -grid.contentY)
    panel.contentContainer:SetSize(grid.contentWidth, grid.contentHeight)
    self:RegisterOptionsDragSurface(panel.contentContainer)
    panel.sidebarScroll = CUI.ScrollFrame(panel, panel, padding, -grid.contentY,
        sidebar - padding * 2, grid.contentHeight)
    local sidebarContent = CreateFrame("Frame", nil, panel.sidebarScroll)
    sidebarContent:SetSize(grid.navigationWidth, grid.contentHeight)
    panel.sidebarScroll:SetScrollChild(sidebarContent)
    panel.sidebarContent = sidebarContent
    self:RegisterOptionsDragSurface(panel.sidebarScroll)
    self:RegisterOptionsDragSurface(sidebarContent)
    local divider = panel:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", sidebar, -header)
    divider:SetSize(1, height - header - footer)
    tokens.Fill(divider, "borderSubtle")
    panel.themeDivider = divider
end

function addon:ClampOptionsShell()
    local panel = self.optionsFrame
    if not panel or panel.dragging then return end
    local grid = panel.shellGrid
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if (issecretvalue and (issecretvalue(width) or issecretvalue(height)))
        or type(width) ~= "number" or type(height) ~= "number"
        or width ~= width or height ~= height or width <= 0 or height <= 0 then return end
    -- Coordinates are already UIParent units. Native screen clamping is visual
    -- only and never rewrites the user's existing saved position preference.
    panel:SetScale(math.min(1, width / (grid.width + grid.padding * 2), height / (grid.height + grid.padding * 2)))
    self:ApplyOptionsPosition(true)
end
