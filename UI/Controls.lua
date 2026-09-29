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
    control.cuiSettleInteraction = Settle
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
    if C.ClearNumericInteractions then C.ClearNumericInteractions(panel) end
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

local function NumericPublic(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function NumericExactText(value, factor)
    local text = string.format("%.15g", value * factor)
    -- Prefer readable decimals only when display-unit parsing preserves the
    -- original storage value exactly. Unedited text never enters a commit.
    if tonumber(text) / factor == value then return text end
    return string.format("%.17g", value * factor)
end

local function NumericAvailable(row)
    if row.disabled or not row:IsVisible() then return false end
    local parent = row
    while parent do
        if parent.cuiSectionLocked then return false end
        parent = parent.GetParent and parent:GetParent()
    end
    return not InCombatLockdown()
end

function C.ClearNumericInteractions(panel)
    for _, row in ipairs(panel.numericRows or {}) do row:CancelInteraction() end
end

local function NumericEvents(panel)
    if panel.numericEvents then return panel.numericEvents end
    local frame = CreateFrame("Frame")
    panel.numericEvents = frame
    frame:SetScript("OnEvent", function(_, event, button)
        local row = panel.numericInteraction
        if not row then return end
        if event == "GLOBAL_MOUSE_UP" then
            if not (issecretvalue and issecretvalue(button)) and button == "LeftButton" and row.dragging then
                row:CancelInteraction()
            end
        else C.ClearNumericInteractions(panel) end
    end)
    panel:HookScript("OnHide", function() C.ClearNumericInteractions(panel) end)
    return frame
end

-- Values in storage units are never rounded by a program refresh or exact edit.
-- The step belongs only to native dragging; display precision is cosmetic.
function C.NumberRow(panel, parent, text, x, y, width, descriptor, onCommit)
    local range = descriptor
    assert(NumericPublic(range.min) and NumericPublic(range.max) and range.min < range.max, "Invalid numeric range")
    local step, factor = range.step or 1, range.displayFactor or 1
    assert(NumericPublic(step) and step > 0 and NumericPublic(factor) and factor > 0, "Invalid numeric step or factor")
    local row = CreateFrame("Frame", nil, parent)
    row.cuiPanel, row.descriptor, row.disabled = panel, descriptor, false
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); row:SetSize(width, 32)
    row.label = C.Label(row, text, 0, -3, range.labelWidth or width * .30, 28, "GameFontNormal")
    row.label:SetJustifyV("MIDDLE")
    local slider = CreateFrame("Slider", nil, row)
    row.slider = slider; slider.cuiPanel = panel
    slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(range.min, range.max)
    slider:SetValueStep(step); slider:SetObeyStepOnDrag(true); slider:EnableMouse(true); slider:EnableMouseWheel(false)
    local track = slider:CreateTexture(nil, "BACKGROUND"); track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0); track:SetHeight(4); D.Fill(track, "surfaceHover")
    local fill = slider:CreateTexture(nil, "ARTWORK"); fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4); D.ApplyGradient(fill)
    slider:SetThumbTexture(neutralThumbAsset)
    local thumb = slider:GetThumbTexture(); thumb:SetSize(12, 18); D.Fill(thumb, "textPrimary")
    slider.track, slider.fill = track, fill
    row.track, row.fill = track, fill
    local button = C.Button(row, "", 0, 0, range.valueWidth or 80, nil, "ghost")
    local edit = C.EditBox(panel, row, 0, 0, range.valueWidth or 80)
    edit:SetMaxLetters(32); edit:Hide()
    row.valueButton, row.editBox, row.editButton, row.editor = button, edit, button, edit
    edit.numericRow = row
    local eventFrame = NumericEvents(panel)
    panel.numericRows = panel.numericRows or {}; panel.numericRows[#panel.numericRows + 1] = row
    local function Context() return type(range.context) == "function" and range.context() or row.context end
    local function Current() return row.interactionContext == Context() end
    local function UpdateEvents(active)
        if active then
            panel.numericInteraction = row
            for _, event in ipairs({ "GLOBAL_MOUSE_UP", "PLAYER_REGEN_DISABLED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LEAVING_WORLD" }) do
                eventFrame:RegisterEvent(event)
            end
        elseif panel.numericInteraction == row then
            panel.numericInteraction = nil; eventFrame:UnregisterAllEvents()
        end
    end
    local function Display(value)
        local formatted = string.format("%." .. (range.precision or 6) .. "f", value * factor)
        if formatted:find(".", 1, true) then formatted = formatted:gsub("0+$", ""):gsub("%.$", "") end
        if formatted == "-0" then formatted = "0" end
        return formatted .. (range.unit or "")
    end
    local function Draw()
        row.settingValue = true; slider:SetValue(row.value); row.settingValue = nil
        local fraction = math.max(0, math.min(1, (row.value - range.min) / (range.max - range.min)))
        fill:SetWidth(math.max(.001, slider:GetWidth() * fraction)); fill:SetShown(fraction > 0)
        button:SetText(Display(row.value))
        if not row.editing then edit:SetText(NumericExactText(row.value, factor)) end
    end
    local function SyncEnabled()
        row.syncEnabled = true
        slider:SetEnabled(not row.disabled and not row.editing)
        slider:EnableMouse(not row.disabled and not row.editing)
        button:SetEnabled(not row.disabled)
        if row.disabled then edit:Disable() else edit:Enable() end
        thumb:SetAlpha(row.disabled and .45 or 1)
        row.label:SetTextColor(unpack(row.disabled and D.textDisabled or D.textPrimary))
        row.syncEnabled = nil
    end
    local function Invalid()
        edit:SetInvalid(true)
        if panel.feedback then C.Feedback(panel, range.errorText or addon.L.invalid, true) end
    end
    function row:GetValue() return self.value end
    function row:SetValue(value)
        if not NumericPublic(value) or value < range.min or value > range.max then return false end
        if (self.editing or self.dragging) and not Current() then self:CancelInteraction() end
        self.value = value; Draw(); return true
    end
    function row:CancelInteraction()
        local interacted = self.editing or self.dragging
        self.editing, self.dragging, self.interactionContext = false, false, nil
        UpdateEvents(false)
        edit.dirty = false; edit:SetInvalid(false); edit:ClearFocus(); edit:Hide(); button:Show()
        for _, control in ipairs({ button, edit }) do
            control.hoverAnimation:Stop()
            if control.cuiSettleInteraction then control.cuiSettleInteraction() end
        end
        -- A temporary disable ends native capture even if release happened
        -- outside the slider or the owning page is being replaced.
        if interacted then self.syncEnabled = true; slider:Disable(); self.syncEnabled = nil end
        SyncEnabled()
        if self.value ~= nil then Draw() end
    end
    row.CancelEdit = row.CancelInteraction
    function row:SetContext(value)
        if self.context ~= value then self:CancelInteraction(); self.context = value end
    end
    function row:SetEnabled(value)
        self.disabled = value ~= true
        if self.disabled then self:CancelInteraction() else SyncEnabled() end
    end
    function row:IsEnabled() return not self.disabled and (slider:IsEnabled() or self.editing and edit:IsEnabled()) end
    function row:Enable() self:SetEnabled(true) end
    function row:Disable() self:SetEnabled(false) end
    local function Commit(value, context)
        if value == row.value then Draw(); return true end
        local previous = row.value
        row.value = value; Draw()
        local ok = not onCommit or onCommit(value, context)
        if ok == false then
            if Context() == context then row.value = previous; Draw() end
            Invalid(); return false
        end
        return true
    end
    local function CommitEdit(blur)
        if not row.editing then return end
        if not NumericAvailable(row) or not Current() then row:CancelInteraction(); return end
        local context = row.interactionContext
        if not edit.dirty then row:CancelInteraction(); return end
        local value = tonumber(edit:GetText())
        value = value and value / factor
        if not NumericPublic(value) or value < range.min or value > range.max then
            if blur then row:CancelInteraction() end
            Invalid(); return
        end
        -- Close the write source before a commit can synchronously refresh UI.
        local draft = edit:GetText()
        local unchanged = value == row.value
        row:CancelInteraction()
        local committed = Commit(value, context)
        if committed and unchanged and panel.feedback then
            -- Validation succeeded, but no setting was written. Clear a prior
            -- draft error with ordinary guidance rather than a saved claim.
            C.Feedback(panel, addon.L.immediate)
        elseif not committed and not blur and NumericAvailable(row) and Context() == context then
            row:BeginEdit(); edit:SetText(draft); edit.dirty = true; Invalid()
        end
    end
    function row:BeginEdit()
        if not NumericAvailable(self) or not button:IsEnabled() then return end
        local previous = panel.numericInteraction
        if previous and previous ~= self and previous.editing then previous.editBox:ClearFocus() end
        C.ClearNumericInteractions(panel)
        if not NumericAvailable(self) or not button:IsEnabled() then return end
        self.editing, self.interactionContext = true, Context()
        edit.dirty = false; edit:SetInvalid(false)
        edit:SetText(NumericExactText(self.value, factor))
        button:Hide(); edit:Show(); SyncEnabled(); UpdateEvents(true)
        edit:SetFocus(); edit:HighlightText()
    end
    button:SetScript("OnClick", function() row:BeginEdit() end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and row.editing and not panel.refreshing then self.dirty = true; self:SetInvalid(false) end
    end)
    edit:SetScript("OnEnterPressed", function() CommitEdit(false) end)
    edit:SetScript("OnEscapePressed", function() row:CancelInteraction() end)
    edit:HookScript("OnEditFocusLost", function() CommitEdit(true) end)
    edit:HookScript("OnHide", function() if row.editing then row:CancelInteraction() end end)
    slider:SetScript("OnMouseDown", function(_, buttonName)
        if buttonName ~= "LeftButton" or not NumericAvailable(row) or not slider:IsEnabled() then return end
        local previous = panel.numericInteraction
        if previous and previous ~= row and previous.editing then previous.editBox:ClearFocus() end
        C.ClearNumericInteractions(panel)
        if not NumericAvailable(row) or not slider:IsEnabled() then return end
        row.dragging, row.interactionContext = true, Context(); UpdateEvents(true)
    end)
    slider:SetScript("OnMouseUp", function() if row.dragging then row:CancelInteraction() end end)
    slider:SetScript("OnValueChanged", function(_, value, userInput)
        if row.settingValue or not userInput or panel.refreshing then return end
        if not row.dragging then Draw(); return end
        if row.editing or not NumericAvailable(row) or not slider:IsEnabled() then Draw(); return end
        if row.dragging and not Current() then row:CancelInteraction(); return end
        if not NumericPublic(value) then return end
        value = math.max(range.min, math.min(range.max, value))
        if value ~= range.min and value ~= range.max then
            value = math.max(range.min, math.min(range.max,
                tonumber(string.format("%.10f", range.min + math.floor((value - range.min) / step + .5) * step))))
        end
        Commit(value, row.dragging and row.interactionContext or Context())
    end)
    slider:HookScript("OnDisable", function()
        thumb:SetAlpha(.45)
        if not row.syncEnabled then row:CancelInteraction() end
    end)
    slider:HookScript("OnEnable", function() thumb:SetAlpha(row.disabled and .45 or 1) end)
    local function Layout()
        local total = row:GetWidth()
        local labelWidth, valueWidth = range.labelWidth or total * .30, range.valueWidth or 80
        row.label:SetWidth(labelWidth)
        slider:ClearAllPoints(); slider:SetPoint("LEFT", row, "LEFT", labelWidth + 12, 0)
        slider:SetSize(math.max(24, total - labelWidth - valueWidth - 32), 18)
        for _, control in ipairs({ button, edit }) do
            control:ClearAllPoints(); control:SetPoint("RIGHT", row, "RIGHT", 0, 0); control:SetWidth(valueWidth)
        end
        if row.value ~= nil then Draw() end
    end
    row:HookScript("OnSizeChanged", Layout)
    row:HookScript("OnHide", function() row:CancelInteraction() end)
    parent:HookScript("OnHide", function() row:CancelInteraction() end)
    Layout(); row:SetValue(range.default or range.min); SyncEnabled()
    Register(slider, "slider", panel)
    C.GuardSectionControl(row)
    return row
end

function C.Slider(panel, parent, text, y, range, step, buildPatch, errorText)
    return C.NumberRow(panel, parent, text, 0, y, parent:GetWidth() or 474,
        { min = range.min, max = range.max, step = step, default = range.default or range.min, errorText = errorText },
        function(value) return Submit(panel, buildPatch(value), errorText) end)
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
