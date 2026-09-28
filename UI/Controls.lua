local _, addon = ...
local D, C = addon.DesignSystem, {}
addon.CUI = C

-- Neutral client pixel fallback, not Blizzard slider chrome. Retail requires
-- a TextureAsset here; only GetThumbTexture returns the slider-owned texture.
local neutralThumbAsset = "Interface\\Buttons\\WHITE8X8"

local function Panel(parent)
    local current = parent
    while current do
        if current.cuiPanel then return current.cuiPanel end
        if current.editBoxes and current.dropdowns then return current end
        current = current.GetParent and current:GetParent()
    end
end

local function Register(control, kind, panel)
    panel = panel or Panel(control)
    control.cuiPanel, control.cuiKind = panel, kind
    if panel and addon.RegisterOptionsThemeControl then addon:RegisterOptionsThemeControl(panel, control, kind) end
    if C.GuardSectionControl then C.GuardSectionControl(control) end
    return control
end

local function Track(panel, group, settle)
    if panel then
        panel.cuiMotion = panel.cuiMotion or {}
        panel.cuiMotion[#panel.cuiMotion + 1] = { group = group, settle = settle }
    end
    return group
end

local function Enabled(control) return not control.IsEnabled or control:IsEnabled() end
local function Submit(panel, patch, errorText) return panel.submit and panel.submit(patch, errorText) end

function C.Label(parent, text, x, y, width, height, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetSize(width, height or 20)
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP"); label:SetWordWrap(true)
    label:SetTextColor(unpack(D.textSecondary)); label:SetText(text)
    return label
end

local function Border(skin, token, alpha)
    for _, edge in ipairs(skin.border) do D.Fill(edge, token, alpha) end
end

local function Interactive(control, label, kind)
    local skin = D.Skin(control, kind)
    local selected = control:CreateTexture(nil, "BACKGROUND", nil, -1)
    selected:SetAllPoints(control); D.ApplyGradient(selected, .20); selected:Hide()
    control.themeSelection = selected
    local emphasis = control:CreateTexture(nil, "BACKGROUND", nil, -1)
    emphasis:SetAllPoints(control); emphasis:Hide()
    control.cuiEmphasis = emphasis
    if kind == "input" then
        control.focusGlow = control:CreateTexture(nil, "BACKGROUND", nil, -1)
        control.focusGlow:SetPoint("TOPLEFT", control, "TOPLEFT", -2, 2)
        control.focusGlow:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 2, -2)
        D.ApplyGradient(control.focusGlow, .055)
        control.focusAccent = control:CreateTexture(nil, "BORDER")
        control.focusAccent:SetPoint("BOTTOMLEFT", control, "BOTTOMLEFT", 1, 0)
        control.focusAccent:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", -1, 0)
        control.focusAccent:SetHeight(2)
    end
    local hover = control:CreateTexture(nil, "ARTWORK", nil, -2)
    hover:SetAllPoints(control); D.ApplyGradient(hover, .07); hover:SetAlpha(0)
    local animation = hover:CreateAnimationGroup()
    local fade = animation:CreateAnimation("Alpha")
    fade:SetOrder(1); fade:SetDuration(D.motionFast); fade:SetSmoothing("OUT")
    control.hoverAnimation = animation
    local function Settle()
        control.cuiHovered, control.cuiPressed = false, false
        hover:SetAlpha(0)
        if control.cuiRefresh then control:cuiRefresh() end
    end
    Track(Panel(control), animation, Settle)
    animation:SetScript("OnFinished", function() hover:SetAlpha(control.cuiHovered and Enabled(control) and 1 or 0) end)
    local function Animate(entering)
        animation:Stop()
        fade:SetFromAlpha(entering and 0 or 1); fade:SetToAlpha(entering and 1 or 0)
        animation:Play()
    end
    function control:cuiRefresh()
        local enabled = Enabled(self)
        local variant = self.variant or "secondary"
        local ghost, primary, danger = variant == "ghost", variant == "primary", variant == "danger"
        local active = enabled and (self.cuiHovered or self.cuiPressed)
        local fill = kind == "input" and "surfaceInput" or primary and "surfacePrimary"
            or danger and "surfaceDanger" or self.cuiPressed and "surfaceSelected"
            or self.selected and "surfaceSelected" or active and "surfaceHover" or "surfaceRaised"
        D.Fill(skin.fill, fill, ghost and (active and .55 or self.selected and .35 or 0) or 1)
        Border(skin, self.invalid and "danger" or self.cuiFocused and "accentGlow"
            or kind == "input" and (active and "borderSubtle" or "borderInput")
            or danger and "danger" or self.selected and "accentGlow" or primary and "borderStrong" or "borderSubtle",
            ghost and 0 or kind == "input" and not self.cuiFocused and not self.invalid and .7 or danger and .4 or 1)
        if primary then D.ApplyGradient(emphasis, enabled and .20 or .06)
        elseif danger then D.ApplyGradient(emphasis, enabled and .13 or .04, D.danger, D.surfaceDanger) end
        emphasis:SetShown(primary or danger)
        selected:SetShown(self.selected == true)
        if self.selectionRail then
            self.selectionRail:SetShown(self.selected == true)
            self.selectionGlow:SetShown(self.selected == true)
        end
        if label then label:SetTextColor(unpack(not enabled and D.textDisabled
            or self.cuiNavigation and not self.selected and not active and D.textSecondary or D.textPrimary)) end
        if kind == "input" then self:SetTextColor(unpack(not enabled and D.textDisabled or D.textPrimary)) end
        if self.focusAccent then
            if self.invalid then D.Fill(self.focusAccent, "danger") else D.ApplyGradient(self.focusAccent, .9) end
            self.focusAccent:SetShown(enabled and (self.cuiFocused or self.invalid) == true)
            self.focusGlow:SetShown(enabled and self.cuiFocused == true)
        end
        if not enabled then animation:Stop(); hover:SetAlpha(0) end
    end
    function control:SetSelected(value) self.selected = value == true; self:cuiRefresh() end
    function control:SetInvalid(value) self.invalid = value == true; self:cuiRefresh() end
    function control:SetVariant(value)
        self.variant = (value == "primary" or value == "ghost" or value == "danger") and value or "secondary"
        self:cuiRefresh()
    end
    function control:SetNavigationStyle()
        self.cuiNavigation = true
        if not self.selectionRail then
            self.selectionRail = self:CreateTexture(nil, "BORDER")
            self.selectionRail:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -5)
            self.selectionRail:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 5)
            self.selectionRail:SetWidth(2)
            D.ApplyGradient(self.selectionRail, .95, nil, nil, "VERTICAL")
            self.selectionGlow = self:CreateTexture(nil, "ARTWORK", nil, -1)
            self.selectionGlow:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -5)
            self.selectionGlow:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 0, 5)
            self.selectionGlow:SetWidth(6); D.ApplyGradient(self.selectionGlow, .10, nil, nil, "VERTICAL")
        end
        D.ApplyGradient(selected, .12)
        self:SetVariant("ghost")
    end
    control:HookScript("OnEnter", function(self)
        if not Enabled(self) or not self:IsVisible() then return end
        self.cuiHovered = true; self:cuiRefresh(); Animate(true)
    end)
    control:HookScript("OnLeave", function(self)
        self.cuiHovered, self.cuiPressed = false, false; self:cuiRefresh()
        if Enabled(self) and self:IsVisible() then Animate(false) else animation:Stop(); hover:SetAlpha(0) end
    end)
    control:HookScript("OnMouseDown", function(self) if Enabled(self) then self.cuiPressed = true; self:cuiRefresh() end end)
    control:HookScript("OnMouseUp", function(self) self.cuiPressed = false; self:cuiRefresh() end)
    control:HookScript("OnDisable", function(self) self:cuiRefresh() end)
    control:HookScript("OnEnable", function(self) self:cuiRefresh() end)
    control:HookScript("OnHide", function() animation:Stop(); Settle() end)
    control:cuiRefresh()
    return skin
end

function C.Button(parent, text, x, y, width, callback, variant)
    local button = CreateFrame("Button", nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); button:SetSize(width, D.controlHeight)
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0); label:SetSize(width - 16, D.controlHeight - 4)
    label:SetWordWrap(true); label:SetJustifyH("CENTER"); label:SetJustifyV("MIDDLE")
    button:SetFontString(label); button.textLabel = label; button:SetText(text)
    button:HookScript("OnSizeChanged", function(self) label:SetSize(math.max(1, self:GetWidth() - 16), math.max(1, self:GetHeight() - 4)) end)
    Interactive(button, label, "button")
    button:SetVariant(variant)
    button:SetScript("OnClick", callback)
    return Register(button, "button")
end

function C.EditBox(panel, parent, x, y, width)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); edit:SetSize(width, D.controlHeight)
    edit:SetAutoFocus(false); edit:SetMaxLetters(16); edit:SetFontObject("ChatFontNormal")
    edit:SetTextInsets(8, 8, 0, 0); edit:SetTextColor(unpack(D.textPrimary))
    edit.cuiPanel = panel
    Interactive(edit, nil, "input")
    edit:HookScript("OnEditFocusGained", function(self) panel.focusedInput = self; self.cuiFocused = true; self:cuiRefresh() end)
    edit:HookScript("OnEditFocusLost", function(self)
        if panel.focusedInput == self then panel.focusedInput = nil end
        self.cuiFocused = false; self:cuiRefresh()
    end)
    -- A script hook survives page-specific OnTextChanged replacement.
    edit:HookScript("OnTextChanged", function(self, userInput) if userInput then self:SetInvalid(false) end end)
    edit:SetScript("OnEscapePressed", function() panel:Hide() end)
    panel.editBoxes[#panel.editBoxes + 1] = edit
    return Register(edit, "input", panel)
end

function C.Toggle(panel, parent, text, x, y, onChanged)
    local toggle = CreateFrame("CheckButton", nil, parent)
    toggle.cuiPanel = panel
    toggle:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); toggle:SetSize(44, 26)
    local track = toggle:CreateTexture(nil, "BACKGROUND"); track:SetSize(42, 20)
    track:SetPoint("CENTER", toggle, "CENTER", 0, 0)
    local accent = toggle:CreateTexture(nil, "ARTWORK"); accent:SetAllPoints(track); D.ApplyGradient(accent)
    local glow = toggle:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetPoint("TOPLEFT", track, "TOPLEFT", -2, 2); glow:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", 2, -2)
    D.ApplyGradient(glow, .08)
    local thumb = toggle:CreateTexture(nil, "OVERLAY"); thumb:SetSize(16, 16)
    D.ApplyGradient(thumb, 1, D.thumbStart, D.thumbEnd, "VERTICAL")
    local label = C.Label(parent, text, x + 54, y - 4, math.max(1, (parent:GetWidth() or 470) - x - 54), 24, "GameFontHighlight")
    toggle.label, toggle.track, toggle.thumb, toggle.accent, toggle.glow = label, track, thumb, accent, glow
    local group = thumb:CreateAnimationGroup()
    local move = group:CreateAnimation("Translation"); move:SetOrder(1); move:SetDuration(D.motionNormal); move:SetSmoothing("OUT")
    toggle.toggleAnimation = group
    local function Settle()
        thumb:ClearAllPoints(); thumb:SetPoint("LEFT", toggle, "LEFT", toggle:GetChecked() and 24 or 4, 0)
    end
    function toggle:cuiRefresh()
        D.Fill(track, "toggleOff"); accent:SetShown(self:GetChecked() == true)
        accent:SetAlpha(Enabled(self) and .78 or .30); glow:SetShown(Enabled(self) and self:GetChecked() == true)
        label:SetTextColor(unpack(Enabled(self) and D.textPrimary or D.textDisabled))
        thumb:SetAlpha(Enabled(self) and 1 or .45)
        self.cuiToggleValue = self:GetChecked() == true
        Settle()
    end
    group:SetScript("OnFinished", Settle); Track(panel, group, Settle)
    local setChecked = toggle.SetChecked
    function toggle:SetChecked(value) group:Stop(); setChecked(self, value); self:cuiRefresh() end
    toggle:HookScript("OnDisable", function(self) group:Stop(); self:cuiRefresh() end)
    toggle:HookScript("OnEnable", function(self) self:cuiRefresh() end)
    toggle:HookScript("OnHide", function() group:Stop(); Settle() end)
    toggle:SetScript("OnClick", function(self)
        local previous = self.cuiToggleValue
        if onChanged then onChanged(self:GetChecked() == true) end
        self:cuiRefresh()
        local checked = self:GetChecked() == true
        if checked ~= previous then
            group:Stop(); thumb:ClearAllPoints(); thumb:SetPoint("LEFT", self, "LEFT", previous and 24 or 4, 0)
            move:SetOffset(checked and 20 or -20, 0); group:Play()
        end
    end)
    toggle:cuiRefresh()
    return Register(toggle, "check", panel)
end

function C.CheckBox(panel, parent, text, x, y, buildPatch)
    return C.Toggle(panel, parent, text, x, y, function(value) Submit(panel, buildPatch(value)) end)
end

local function MenuInteractive(dropdown, active)
    local menu = dropdown.menu
    menu.cuiInteractive = active == true; menu:EnableMouse(active == true)
    for _, choice in ipairs(dropdown.choices) do
        local enabled = active and choice.cuiAvailable == true
        choice:SetEnabled(not not enabled); choice:EnableMouse(not not enabled)
    end
    if dropdown.previousPage then
        dropdown.previousPage:SetEnabled(active and dropdown.page > 1)
        dropdown.nextPage:SetEnabled(active and dropdown.page < dropdown.pageCount)
        dropdown.previousPage:EnableMouse(active == true); dropdown.nextPage:EnableMouse(active == true)
    end
end

local function CloseMenu(dropdown, immediate)
    local menu, panel = dropdown.menu, dropdown.cuiPanel
    if panel.activeDropdown == dropdown then panel.activeDropdown = nil end
    MenuInteractive(dropdown, false)
    if menu.cuiState == "closed" then return end
    menu.openAnimation:Stop(); menu.closeAnimation:Stop()
    if immediate then menu.cuiState = "closed"; menu:Hide(); menu:SetAlpha(1)
    else menu.cuiState = "closing"; menu.closeAnimation:Play() end
end

function C.CloseMenus(panel, immediate)
    for _, dropdown in ipairs(panel.dropdowns or {}) do CloseMenu(dropdown, immediate) end
end

function C.StopMotion(panel)
    C.CloseMenus(panel, true)
    for _, record in ipairs(panel.cuiMotion or {}) do
        record.group:Stop()
        if record.settle then record.settle() end
    end
    if panel == addon.optionsFrame and addon.StopTitleAnimation then addon:StopTitleAnimation() end
end

local function MenuAnimation(menu, duration, opening)
    local group = menu:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha"); alpha:SetOrder(1); alpha:SetDuration(duration)
    alpha:SetFromAlpha(opening and 0 or 1); alpha:SetToAlpha(opening and 1 or 0); alpha:SetSmoothing("OUT")
    local translation = group:CreateAnimation("Translation"); translation:SetOrder(1); translation:SetDuration(duration)
    translation:SetOffset(0, opening and D.menuTravel or -D.menuTravel); translation:SetSmoothing("OUT")
    return group
end

function C.Dropdown(panel, parent, text, x, y, entries, buildPatch, onSelect, pageSize)
    local label = C.Label(parent, text, x, y, math.max(1, math.min(400, parent:GetWidth() or 400)), 22, "GameFontNormal")
    local dropdown = C.Button(parent, "", x, y - 26, 280, nil)
    dropdown.cuiPanel, dropdown.label, dropdown.page = panel, label, 1
    local menu = CreateFrame("Frame", nil, panel)
    menu.cuiPanel, menu.cuiState = panel, "closed"
    menu:Hide(); menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -3)
    menu:SetSize(474, 40); menu:SetFrameLevel(panel:GetFrameLevel() + 30)
    D.Skin(menu, "menu"); Register(menu, "menu", panel)
    dropdown.menu, dropdown.choices = menu, {}
    menu.openAnimation = MenuAnimation(menu, D.motionNormal, true)
    menu.closeAnimation = MenuAnimation(menu, D.menuClose, false)
    local function ResetAnchor(travel)
        local menuWidth = math.min(panel:GetWidth() - 24, pageSize and 474 or math.max(dropdown:GetWidth(), 300))
        menu:SetWidth(menuWidth)
        local dx, dy = dropdown:GetCenter()
        local px, py = panel:GetCenter()
        local shift, above = 0, false
        if dx and dy and px and py then
            local ratio = dropdown:GetEffectiveScale() / panel:GetEffectiveScale()
            local left = dx * ratio - px + panel:GetWidth() / 2 - dropdown:GetWidth() * ratio / 2
            shift = math.max(12, math.min(left, panel:GetWidth() - menuWidth - 12)) - left
            local bottom = dy * ratio - py + panel:GetHeight() / 2 - dropdown:GetHeight() * ratio / 2
            above = menu:GetHeight() + 6 > bottom and bottom < panel:GetHeight() / 2
        end
        menu:ClearAllPoints()
        menu:SetPoint(above and "BOTTOMLEFT" or "TOPLEFT", dropdown, above and "TOPLEFT" or "BOTTOMLEFT",
            shift, (above and 3 or -3) - (travel or 0))
        for _, choice in ipairs(dropdown.choices) do choice:SetWidth(menuWidth - 12) end
    end
    menu.openAnimation:SetScript("OnFinished", function()
        if menu.cuiState == "opening" then menu.cuiState = "open"; menu:SetAlpha(1); ResetAnchor() end
    end)
    menu.closeAnimation:SetScript("OnFinished", function()
        if menu.cuiState == "closing" then menu.cuiState = "closed"; menu:Hide(); menu:SetAlpha(1); ResetAnchor() end
    end)
    Track(panel, menu.openAnimation); Track(panel, menu.closeAnimation)
    menu:HookScript("OnHide", function()
        menu.openAnimation:Stop(); menu.closeAnimation:Stop(); menu.cuiState = "closed"
        MenuInteractive(dropdown, false)
        if panel.activeDropdown == dropdown then panel.activeDropdown = nil end
    end)
    function dropdown:SetEntries(newEntries)
        entries, self.entries = newEntries, newEntries
        self.pageCount = pageSize and math.max(1, math.ceil(#entries / pageSize)) or 1
        self.page = math.max(1, math.min(self.page, self.pageCount))
        local first = pageSize and (self.page - 1) * pageSize + 1 or 1
        local count = pageSize and math.min(pageSize, #entries - first + 1) or #entries
        for index = 1, count do
            local entry, choice = entries[first + index - 1], self.choices[index]
            if not choice then
                choice = C.Button(menu, "", 6, -6 - (index - 1) * D.controlHeight, 462, nil)
                self.choices[index] = choice
                choice:HookScript("OnEnter", function(self)
                    if not self.fontTooltip or not menu.cuiInteractive then return end
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(self.fontTooltip, 1, 1, 1, 1, true); GameTooltip:Show()
                end)
                local function HideTooltip(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end
                choice:HookScript("OnLeave", HideTooltip); choice:HookScript("OnHide", HideTooltip)
                choice:SetScript("OnClick", function(self)
                    if not menu.cuiInteractive or not self.cuiAvailable then return end
                    local value = self.value
                    CloseMenu(dropdown, false)
                    if onSelect then onSelect(value) elseif buildPatch then Submit(panel, buildPatch(value)) end
                end)
            end
            choice.value, choice.cuiAvailable = entry.value, true
            choice.fontTooltip = entry.label
            choice:ClearAllPoints(); choice:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (index - 1) * D.controlHeight)
            choice:SetText(entry.label); choice:SetSelected(entry.value == self.value); choice:Show()
        end
        for index = count + 1, #self.choices do
            local choice = self.choices[index]
            choice.value, choice.cuiAvailable = nil, false; choice:Hide()
        end
        menu:SetHeight(math.max(1, count) * D.controlHeight + (pageSize and 48 or 12))
        ResetAnchor()
        if self.pageLabel then self.pageLabel:SetText(string.format("%d / %d", self.page, self.pageCount)) end
        MenuInteractive(self, menu.cuiState == "opening" or menu.cuiState == "open")
    end
    function dropdown:SetPage(page) self.page = page; self:SetEntries(entries) end
    if pageSize then
        dropdown.previousPage = C.Button(menu, addon:Text("Previous"), 6, 0, 140, function() dropdown:SetPage(dropdown.page - 1) end)
        dropdown.nextPage = C.Button(menu, addon:Text("Next"), 328, 0, 140, function() dropdown:SetPage(dropdown.page + 1) end)
        dropdown.pageLabel = C.Label(menu, "", 160, 0, 150, 24)
        for _, control in ipairs({ dropdown.previousPage, dropdown.nextPage, dropdown.pageLabel }) do control:ClearAllPoints() end
        dropdown.previousPage:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 6, 6)
        dropdown.nextPage:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -6, 6)
        dropdown.pageLabel:SetPoint("BOTTOM", menu, "BOTTOM", 0, 8); dropdown.pageLabel:SetJustifyH("CENTER")
    end
    function dropdown:SelectValue(value)
        for index, entry in ipairs(entries) do
            if entry.value == value then
                self:SetText(entry.label .. "  v"); self.value = value
                if pageSize then self:SetPage(math.ceil(index / pageSize)) end
                for _, choice in ipairs(self.choices) do choice:SetSelected(choice.value == value) end
                return
            end
        end
    end
    function dropdown:SetEntryLabel(value, textValue)
        for _, entry in ipairs(entries) do if entry.value == value then entry.label = textValue end end
        for _, choice in ipairs(self.choices) do
            if choice.value == value then choice:SetText(textValue); choice.fontTooltip = textValue end
        end
        if self.value == value then self:SetText(textValue .. "  v") end
    end
    function dropdown:FilterChoices(allowed)
        local count = 0
        for _, choice in ipairs(self.choices) do
            choice.cuiAvailable = allowed[choice.value] == true
            choice:SetShown(choice.cuiAvailable)
            if choice.cuiAvailable then
                choice:ClearAllPoints(); choice:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - count * D.controlHeight)
                count = count + 1
            end
        end
        menu:SetHeight(math.max(1, count) * D.controlHeight + 12)
        self:SetEnabled(count > 0); MenuInteractive(self, menu.cuiInteractive)
        if count == 0 then self:SetText(addon:Text("No entries")); self.value = nil; CloseMenu(self, true) end
    end
    dropdown:SetEntries(entries)
    dropdown:SetScript("OnClick", function()
        local opening = menu.cuiState == "closed" or menu.cuiState == "closing"
        C.CloseMenus(panel, false)
        if not opening then return end
        menu.closeAnimation:Stop(); menu.openAnimation:Stop(); panel.activeDropdown = dropdown
        ResetAnchor(D.menuTravel)
        menu.cuiState = "opening"; menu:SetAlpha(1); menu:Show(); MenuInteractive(dropdown, true)
        menu.openAnimation:Play()
    end)
    dropdown:HookScript("OnHide", function() CloseMenu(dropdown, true) end)
    dropdown:HookScript("OnDisable", function() CloseMenu(dropdown, true) end)
    dropdown:HookScript("OnSizeChanged", function(self)
        label:SetWidth(self:GetWidth()); ResetAnchor(menu.cuiState == "opening" and D.menuTravel or 0)
    end)
    panel.dropdowns[#panel.dropdowns + 1] = dropdown
    return dropdown
end

function C.Slider(panel, parent, text, y, range, step, buildPatch, errorText)
    local parentWidth = math.max(260, parent:GetWidth() or 474)
    local trackWidth, editX = parentWidth - 144, parentWidth - 112
    local title = C.Label(parent, text, 0, y, parentWidth, 22, "GameFontNormal")
    local slider = CreateFrame("Slider", nil, parent)
    slider.cuiPanel, slider.label = panel, title
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 30); slider:SetSize(trackWidth, 18)
    slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(range.min, range.max)
    slider:SetValueStep(step); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true)
    local track = slider:CreateTexture(nil, "BACKGROUND"); track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0); track:SetHeight(4); D.Fill(track, "surfaceHover")
    local fill = slider:CreateTexture(nil, "ARTWORK"); fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4); D.ApplyGradient(fill)
    slider:SetThumbTexture(neutralThumbAsset)
    local thumb = slider:GetThumbTexture(); thumb:SetSize(12, 18); D.Fill(thumb, "textPrimary")
    slider.fill, slider.track = fill, track
    C.Label(parent, tostring(range.min), 0, y - 54, 56)
    local maximum = C.Label(parent, tostring(range.max), trackWidth - 56, y - 54, 56); maximum:SetJustifyH("RIGHT")
    local edit = C.EditBox(panel, parent, editX, y - 24, 112); slider.editBox = edit
    edit:SetScript("OnTextChanged", function(self, userInput) if userInput and not panel.refreshing then self.dirty = true end end)
    edit:SetScript("OnEnterPressed", function()
        edit.dirty = false
        local saved = Submit(panel, buildPatch(tonumber(edit:GetText())), errorText)
        edit:SetInvalid(not saved)
        if saved then edit:ClearFocus() else edit.dirty = true end
    end)
    local function FillValue()
        local value = slider:GetValue() or range.min
        local fraction = math.max(0, math.min(1, (value - range.min) / (range.max - range.min)))
        fill:SetWidth(math.max(.001, slider:GetWidth() * fraction)); fill:SetShown(fraction > 0)
    end
    slider:SetScript("OnValueChanged", function(_, value)
        FillValue()
        if panel.refreshing or not panel:IsShown() then return end
        local rounded = tonumber(string.format("%.2f", math.floor(value / step + .5) * step))
        edit.dirty = false; edit:SetInvalid(false); Submit(panel, buildPatch(rounded), errorText)
    end)
    slider:HookScript("OnSizeChanged", FillValue)
    slider:HookScript("OnDisable", function() thumb:SetAlpha(.45); edit:Disable() end)
    slider:HookScript("OnEnable", function() thumb:SetAlpha(1); edit:Enable() end)
    return Register(slider, "slider", panel)
end

-- Keep logical control states separate from a disclosure's temporary input lock.
-- Native enable callbacks can touch sibling inputs, so forced state changes must
-- not overwrite the most recent state requested by the page refresh.
local sectionEnforcement = 0
local function SectionLocked(control)
    local current = control
    while current do
        local section = current.cuiSectionContent
        if section and (current.cuiSectionLocked or not section:IsVisible()) then return true end
        current = current.GetParent and current:GetParent()
    end
    return false
end

local function SectionNativeEnabled(control, guard, value)
    if guard.setEnabled then guard.setEnabled(control, value)
    elseif value and guard.enable then guard.enable(control)
    elseif not value and guard.disable then guard.disable(control) end
end

local function ApplySectionGuard(control)
    local guard = control.cuiSectionGuard
    if not guard then return end
    local locked = SectionLocked(control)
    sectionEnforcement = sectionEnforcement + 1
    SectionNativeEnabled(control, guard, not locked and guard.enabled)
    if guard.enableMouse then guard.enableMouse(control, not locked and guard.mouse) end
    if locked and guard.clearFocus then guard.clearFocus(control) end
    if locked and control.menu then CloseMenu(control, true) end
    sectionEnforcement = sectionEnforcement - 1
end

function C.GuardSectionControl(control, defer)
    if control.cuiSectionGuard then return end
    local current, owner = control
    while current do
        owner = owner or current.cuiSectionContent
        current = current.GetParent and current:GetParent()
    end
    if not owner then return end
    local kind = control:GetObjectType()
    local input = kind == "Button" or kind == "CheckButton" or kind == "Slider" or kind == "EditBox"
    local guard = { enabled = not input or control:IsEnabled(), mouse = control:IsMouseEnabled(),
        enableMouse = control.EnableMouse, setScript = control.SetScript }
    control.cuiSectionGuard = guard
    if input then
        guard.setEnabled = control.SetEnabled
        guard.enable, guard.disable = control.Enable, control.Disable
        local function RequestEnabled(self, value)
            value = value == true
            if sectionEnforcement == 0 then
                guard.enabled = value
                -- A locked slider is already physically disabled, so its native
                -- OnDisable may not fire again for a new logical page state.
                if kind == "Slider" and self.editBox then
                    if value then self.editBox:Enable() else self.editBox:Disable() end
                end
            end
            -- Run the normal enable/disable callbacks for a page-requested state,
            -- then clamp the physical widget while the disclosure is locked.
            SectionNativeEnabled(self, guard, value)
            ApplySectionGuard(self)
        end
        if guard.setEnabled then control.SetEnabled = RequestEnabled end
        if guard.enable then control.Enable = function(self) RequestEnabled(self, true) end end
        if guard.disable then control.Disable = function(self) RequestEnabled(self, false) end end
    end
    if guard.enableMouse then
        function control:EnableMouse(value)
            if sectionEnforcement == 0 then guard.mouse = value == true end
            guard.enableMouse(self, not SectionLocked(self) and guard.mouse)
        end
    end
    if kind == "EditBox" then
        guard.clearFocus, guard.setFocus = control.ClearFocus, control.SetFocus
        function control:SetFocus(...) if not SectionLocked(self) then return guard.setFocus(self, ...) end end
    end
    local events = { OnMouseWheel = true, OnMouseDown = true, OnMouseUp = true }
    if kind == "Button" or kind == "CheckButton" then events.OnClick = true end
    if kind == "EditBox" then
        events.OnEnterPressed, events.OnTabPressed, events.OnChar = true, true, true
        events.OnTextChanged = "text"
    elseif kind == "Slider" then events.OnValueChanged = "value" end
    local function GuardScript(event, callback)
        local mode = events[event]
        if not callback or not mode then return callback end
        return function(self, ...)
            local userInput = mode == "text" and select(1, ...) or mode == "value" and select(2, ...)
            if SectionLocked(control) and (mode == true or userInput == true) then return end
            return callback(self, ...)
        end
    end
    for event in pairs(events) do
        local callback = control:GetScript(event)
        if callback then guard.setScript(control, event, GuardScript(event, callback)) end
    end
    function control:SetScript(event, callback) guard.setScript(self, event, GuardScript(event, callback)) end
    if not defer then ApplySectionGuard(control) end
end

local function SetSectionInput(section, locked)
    section.content.cuiSectionLocked = locked == true
    local controls = {}
    local function Visit(frame)
        controls[#controls + 1] = frame
        for _, child in ipairs({ frame:GetChildren() }) do Visit(child) end
    end
    Visit(section.content)
    -- Capture every descendant before disable hooks can affect another input.
    sectionEnforcement = sectionEnforcement + 1
    for _, control in ipairs(controls) do C.GuardSectionControl(control, true) end
    for _, control in ipairs(controls) do ApplySectionGuard(control) end
    sectionEnforcement = sectionEnforcement - 1
end

function C.Section(parent, text, x, y, width, opts)
    opts = opts or {}
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); section:SetSize(width, opts.height or 80)
    D.Skin(section, "section")
    section.title = C.Label(section, text, D.sectionPadding, -12, width - 24, 24, "GameFontNormal")
    section.title:SetTextColor(unpack(D.textPrimary))
    section.divider = section:CreateTexture(nil, "ARTWORK"); section.divider:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -36)
    section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -36); section.divider:SetHeight(1)
    D.ApplyGradient(section.divider, .45)
    section.content = CreateFrame("Frame", nil, section)
    section.content:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -40)
    section.content:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -12, 12)
    section.content:SetWidth(width - 24)
    section.expandedHeight = opts.height or 80
    section.collapsed = false
    if opts.collapsible then
        section.content.cuiSectionContent = section
        local function Settle()
            local transitioning = section.transition ~= nil
            section.motionRevision = (section.motionRevision or 0) + 1
            section.transition = nil
            section.expandAnimation:Stop(); section.collapseAnimation:Stop()
            section.content:SetAlpha(1)
            section.content:SetShown(not section.collapsed); section.divider:SetShown(not section.collapsed)
            section:SetHeight(section.collapsed and 42 or section.expandedHeight)
            SetSectionInput(section, section.collapsed or not section:IsVisible())
            if transitioning and opts.onSettled then opts.onSettled(section, section.collapsed) end
        end
        local function Animation(expanding)
            local group = section.content:CreateAnimationGroup()
            local fade = group:CreateAnimation("Alpha")
            fade:SetOrder(1); fade:SetDuration(D.motionNormal); fade:SetSmoothing("OUT")
            fade:SetFromAlpha(expanding and 0 or 1); fade:SetToAlpha(expanding and 1 or 0)
            return Track(Panel(section), group, Settle)
        end
        section.expandAnimation, section.collapseAnimation = Animation(true), Animation(false)
        function section:SetCollapsed(value, immediate)
            value = value == true
            if self.collapsed == value then if immediate then Settle() end; return end
            if value and not self.transition then self.expandedHeight = self:GetHeight() end
            self.collapsed = value
            self.expandAnimation:Stop(); self.collapseAnimation:Stop()
            self.transition = value and "collapsing" or "expanding"
            self.motionRevision = (self.motionRevision or 0) + 1
            local revision = self.motionRevision
            local animation = value and self.collapseAnimation or self.expandAnimation
            animation:SetScript("OnFinished", function()
                if self.motionRevision == revision and self.transition then Settle() end
            end)
            self:SetHeight(self.expandedHeight)
            self.content:Show(); self.divider:Show(); self.content:SetAlpha(1)
            SetSectionInput(self, true)
            self.collapseButton:SetText(value and "+" or "-")
            if opts.onToggle then opts.onToggle(self, value) end
            if immediate or not self:IsVisible() then Settle()
            elseif self.transition then (self.collapsed and self.collapseAnimation or self.expandAnimation):Play() end
        end
        section.title:SetWidth(width - 68)
        section.collapseButton = C.Button(section, "-", width - 40, -6, 30, function() section:SetCollapsed(not section.collapsed) end, "ghost")
        section:HookScript("OnHide", Settle)
        section:HookScript("OnShow", function() if not section.transition then SetSectionInput(section, section.collapsed) end end)
        if opts.collapsed then section:SetCollapsed(true, true) end
    end
    return Register(section, "section")
end

function C.Segmented(panel, parent, text, x, y, width, entries, onSelect)
    local control = CreateFrame("Frame", nil, parent)
    control.cuiPanel, control.choices, control.entries = panel, {}, entries
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); control:SetSize(width, 58)
    control.label = C.Label(control, text, 0, 0, width, 22, "GameFontNormal")
    local segmentWidth = (width - (#entries - 1) * D.spacingXS) / math.max(1, #entries)
    for index, entry in ipairs(entries) do
        local choice = C.Button(control, entry.label, (index - 1) * (segmentWidth + D.spacingXS), -26, segmentWidth, nil, "ghost")
        choice.value = entry.value
        choice:SetScript("OnClick", function(self)
            if not control.disabled and onSelect then onSelect(self.value) end
        end)
        control.choices[#control.choices + 1] = choice
    end
    function control:SelectValue(value)
        self.value = value
        for _, choice in ipairs(self.choices) do choice:SetSelected(choice.value == value) end
    end
    function control:SetEnabled(value)
        self.disabled = not value
        for _, choice in ipairs(self.choices) do choice:SetEnabled(value) end
    end
    return control
end

function C.ScrollFrame(panel, parent, x, y, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll.cuiPanel = panel
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); scroll:SetSize(width, height)
    scroll:EnableMouseWheel(true)
    local bar = CreateFrame("Slider", nil, parent)
    bar.cuiPanel = panel
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0); bar:SetSize(6, height)
    bar:SetOrientation("VERTICAL"); bar:SetMinMaxValues(0, 0); bar:SetValueStep(1); bar:EnableMouse(true)
    local track = bar:CreateTexture(nil, "BACKGROUND"); track:SetAllPoints(bar); D.Fill(track, "surfaceRaised")
    bar:SetThumbTexture(neutralThumbAsset)
    local thumb = bar:GetThumbTexture(); thumb:SetSize(6, 30); D.Fill(thumb, "borderStrong")
    scroll.scrollBar, scroll.thumb = bar, thumb
    function scroll:RefreshRange()
        local child = self:GetScrollChild()
        local maximum = math.max(0, (child and child:GetHeight() or 0) - self:GetHeight())
        self.cuiRange = maximum
        bar:SetMinMaxValues(0, maximum); bar:SetShown(maximum > 0); bar:SetHeight(self:GetHeight())
        thumb:SetHeight(math.max(18, self:GetHeight() * self:GetHeight() / math.max(self:GetHeight(), child and child:GetHeight() or 1)))
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScroll() or 0, maximum)))
        bar:SetValue(self:GetVerticalScroll() or 0)
    end
    scroll:SetScript("OnMouseWheel", function(self, delta)
        self:RefreshRange(); self:SetVerticalScroll(math.max(0, math.min(self.cuiRange, (self:GetVerticalScroll() or 0) - delta * 30)))
        bar:SetValue(self:GetVerticalScroll() or 0)
    end)
    scroll:SetScript("OnVerticalScroll", function(self, value) bar:SetValue(value) end)
    scroll:HookScript("OnSizeChanged", function(self) self:RefreshRange() end)
    scroll:HookScript("OnHide", function() bar:Hide() end)
    scroll:HookScript("OnShow", function(self) self:RefreshRange() end)
    bar:SetScript("OnValueChanged", function(_, value)
        if (scroll:GetVerticalScroll() or 0) ~= value then scroll:SetVerticalScroll(value) end
    end)
    bar:SetScript("OnEnter", function() D.Fill(thumb, "accentGlow") end)
    bar:SetScript("OnLeave", function() D.Fill(thumb, "borderStrong") end)
    C.GuardSectionControl(scroll); C.GuardSectionControl(bar)
    return scroll
end

function C.GalleryTile(parent, text, x, y, width, height, onClick)
    local tile = C.Button(parent, text, x, y, width, onClick)
    tile:SetHeight(height)
    tile.textLabel:ClearAllPoints(); tile.textLabel:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 8, 6)
    tile.textLabel:SetSize(width - 16, 30)
    tile.selectionAccent = tile:CreateTexture(nil, "BORDER")
    tile.selectionAccent:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 1, 1)
    tile.selectionAccent:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
    tile.selectionAccent:SetHeight(2); D.ApplyGradient(tile.selectionAccent, .8); tile.selectionAccent:Hide()
    local setSelected = tile.SetSelected
    function tile:SetSelected(value) setSelected(self, value); self.selectionAccent:SetShown(value == true) end
    return tile
end

function C.Backdrop(frame) return D.Skin(frame, "surface") end
function C.Feedback(panel, text, failed)
    local success = failed == false or text == addon.L.saved or text == addon.L.resetDone or text == addon.L.transferDone
    panel.feedback:SetText(text); panel.feedback:SetTextColor(unpack(failed and D.danger or success and D.success or D.textSecondary))
    if panel.focusedInput and panel.focusedInput.SetInvalid then panel.focusedInput:SetInvalid(failed == true) end
end
