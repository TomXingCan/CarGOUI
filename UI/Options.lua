local _, addon = ...
local L = addon.L

local function Label(parent, text, x, y, width, height, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetSize(width, height or 20)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetText(text)
    return label
end

local function Backdrop(frame, r, g, b)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    frame:SetBackdropColor(r, g, b, 0.98)
    frame:SetBackdropBorderColor(0.22, 0.30, 0.34, 1)
end

local function Button(parent, text, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, 28)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function Feedback(panel, text, error)
    panel.feedback:SetText(text)
    if error then
        panel.feedback:SetTextColor(1, 0.40, 0.35)
    else
        panel.feedback:SetTextColor(0.55, 0.87, 0.79)
    end
end

local function CloseMenus(panel)
    for _, dropdown in ipairs(panel.dropdowns) do
        dropdown.menu:Hide()
    end
end

local function ClearEdits(panel)
    panel.positionDirty = false
    for _, edit in ipairs(panel.editBoxes) do
        edit.dirty = false
        edit:ClearFocus()
    end
end

local function CancelReset(panel)
    panel.resetArmed = false
    panel.controls.reset:SetText(L.reset)
end

local function Submit(panel, patch, errorText)
    local ok = addon:UpdateSettings(patch)
    if ok then
        CancelReset(panel)
        Feedback(panel, L.saved)
    else
        Feedback(panel, errorText or L.invalid, true)
    end
    return ok
end

local function EditBox(panel, parent, x, y, width)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetSize(width, 28)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(16)
    edit:SetFontObject("ChatFontNormal")
    edit:SetTextInsets(6, 6, 0, 0)
    edit:SetScript("OnEscapePressed", function() panel:Hide() end)
    panel.editBoxes[#panel.editBoxes + 1] = edit
    return edit
end

local function CheckBox(panel, parent, text, x, y, buildPatch)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetSize(26, 26)
    Label(parent, text, x + 32, y - 5, 390, 22, "GameFontHighlight")
    check:SetScript("OnClick", function(self)
        Submit(panel, buildPatch(not not self:GetChecked()))
    end)
    return check
end

local function Dropdown(panel, parent, text, x, y, entries, buildPatch)
    Label(parent, text, x, y, 400, 22, "GameFontNormal")
    local dropdown = Button(parent, "", x, y - 26, 280, nil)
    local menu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    menu:Hide()
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -3)
    menu:SetSize(280, #entries * 28 + 12)
    menu:SetFrameLevel(panel:GetFrameLevel() + 20)
    menu:EnableMouse(true)
    Backdrop(menu, 0.07, 0.09, 0.12)
    dropdown.menu = menu
    dropdown.choices = {}
    for index, entry in ipairs(entries) do
        local value = entry.value
        local choice = Button(menu, entry.label, 6, -6 - (index - 1) * 28, 268, function()
            Submit(panel, buildPatch(value))
            menu:Hide()
        end)
        choice.value = value
        dropdown.choices[#dropdown.choices + 1] = choice
    end
    dropdown:SetScript("OnClick", function()
        local opening = not menu:IsShown()
        CloseMenus(panel)
        if opening then menu:Show() end
    end)
    function dropdown:SelectValue(value)
        for _, entry in ipairs(entries) do
            if entry.value == value then
                self:SetText(entry.label .. "  v")
                self.value = value
                return
            end
        end
    end
    panel.dropdowns[#panel.dropdowns + 1] = dropdown
    return dropdown
end

local function Slider(panel, parent, text, y, range, step, buildPatch, errorText)
    Label(parent, text, 0, y, 470, 22, "GameFontNormal")
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 30)
    slider:SetSize(288, 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(range.min, range.max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:EnableMouse(true)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(6)
    track:SetColorTexture(0.20, 0.27, 0.30, 1)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(18, 24)
    Label(parent, tostring(range.min), 0, y - 54, 56)
    local maximum = Label(parent, tostring(range.max), 232, y - 54, 56)
    maximum:SetJustifyH("RIGHT")
    local edit = EditBox(panel, parent, 316, y - 24, 78)
    slider.editBox = edit
    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not panel.refreshing then self.dirty = true end
    end)
    local function CommitEdit()
        edit.dirty = false
        if Submit(panel, buildPatch(tonumber(edit:GetText())), errorText) then
            edit:ClearFocus()
        else
            edit.dirty = true
        end
    end
    edit:SetScript("OnEnterPressed", CommitEdit)
    slider.applyButton = Button(parent, L.apply, 406, y - 24, 68, CommitEdit)
    slider:SetScript("OnValueChanged", function(_, value)
        if panel.refreshing or not panel:IsShown() then return end
        local rounded = tonumber(string.format("%.2f", math.floor(value / step + 0.5) * step))
        edit.dirty = false
        Submit(panel, buildPatch(rounded), errorText)
    end)
    return slider
end

local function SetSlider(slider, value)
    slider:SetValue(value)
    if not slider.editBox.dirty then
        slider.editBox:SetText(string.format("%g", value))
    end
end

function addon:RefreshOptions()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return end
    local controls, db = panel.controls, self.db
    panel.refreshing = true
    controls.enabled:SetChecked(db.enabled)
    if not panel.positionDirty then
        controls.x:SetText(string.format("%g", db.position.x))
        controls.y:SetText(string.format("%g", db.position.y))
    end
    controls.font:SelectValue(db.font.face)
    controls.outline:SelectValue(db.font.outline)
    controls.shadow:SetChecked(db.shadow.enabled)
    SetSlider(controls.fontSize, db.font.size)
    SetSlider(controls.scale, db.scale)
    panel.refreshing = false

    if panel.activeCategory == "preview" then
        local preview = panel.previewFrame
        self:ApplyFontSettings(preview.text)
        preview.text:SetText("CarGOUI")
        preview.text:SetScale(math.min(db.scale,
            (preview:GetWidth() - 32) / math.max(1, preview.text:GetStringWidth()),
            (preview:GetHeight() - 32) / math.max(1, preview.text:GetStringHeight())))
        panel.previewStatus:SetText(string.format("X: %g    Y: %g    %s: %g    %s: %g",
            db.position.x, db.position.y, L.fontSize, db.font.size, L.scale, db.scale))
        panel.previewHidden:SetText(db.enabled and "" or L.previewHidden)
        preview:Show()
    else
        panel.previewFrame:Hide()
    end
end

function addon:SelectOptionsCategory(key)
    local panel = self.optionsFrame
    if not panel or not panel.pages[key] then return end
    CloseMenus(panel)
    ClearEdits(panel)
    CancelReset(panel)
    panel.activeCategory = key
    for pageKey, page in pairs(panel.pages) do
        page:SetShown(pageKey == key)
    end
    for _, button in ipairs(panel.categories) do
        if panel.pages[button.key] then
            button:SetText((button.key == key and "> " or "") .. L[button.key])
        end
    end
    Feedback(panel, L.immediate)
    self:RefreshOptions()
end

function addon:CreateOptions()
    if self.optionsFrame then return self.optionsFrame end
    local panel = CreateFrame("Frame", "CarGOUIOptionsFrame", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(720, 560)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    Backdrop(panel, 0.045, 0.06, 0.075)
    panel.controls, panel.pages, panel.categories = {}, {}, {}
    panel.editBoxes, panel.dropdowns = {}, {}
    panel.activeCategory = "general"
    self.optionsFrame = panel
    Label(panel, "CarGOUI  |  " .. L.options, 22, -20, 580, 26, "GameFontNormalLarge")
    Label(panel, "Alpha 0.1", 24, -50, 630)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.22, 0.30, 0.34, 1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 192, -82)
    divider:SetSize(1, 380)

    for _, key in ipairs({ "general", "typography", "preview" }) do
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", 216, -88)
        page:SetSize(480, 374)
        page:Hide()
        panel.pages[key] = page
        Label(page, L[key], 0, 0, 470, 24, "GameFontNormalLarge")
    end
    for index, key in ipairs({ "general", "typography", "preview", "mobility", "proc", "themes", "importExport" }) do
        local category = key
        local button = Button(panel, L[key], 16, -88 - (index - 1) * 40, 162, function()
            addon:SelectOptionsCategory(category)
        end)
        button.key = key
        if not panel.pages[key] then
            local status = Label(panel, L.unavailable, 22, -116 - (index - 1) * 40, 156, 12)
            status:SetTextColor(0.55, 0.58, 0.62)
            button:SetScript("OnClick", nil)
            button:Disable()
        end
        panel.categories[#panel.categories + 1] = button
    end
    Label(panel, L.future, 20, -382, 156, 72)
    panel.feedback = Label(panel, "", 24, -476, 672, 32)
    panel.controls.reset = Button(panel, L.reset, 24, -516, 170, function()
        CloseMenus(panel)
        if not panel.resetArmed then
            panel.resetArmed = true
            panel.controls.reset:SetText(L.confirmReset)
            Feedback(panel, L.resetHint)
            return
        end
        ClearEdits(panel)
        addon:ResetDatabase()
        CancelReset(panel)
        Feedback(panel, L.resetDone)
    end)
    panel.controls.close = Button(panel, L.close, 580, -516, 116, function() panel:Hide() end)

    local general = panel.pages.general
    Label(general, L.generalHint, 0, -32, 470, 32)
    panel.controls.enabled = CheckBox(panel, general, L.enabled, 0, -70,
        function(value) return { enabled = value } end)
    Label(general, L.x, 0, -118, 130, 22, "GameFontNormal")
    Label(general, L.y, 156, -118, 130, 22, "GameFontNormal")
    panel.controls.x = EditBox(panel, general, 0, -146, 130)
    panel.controls.y = EditBox(panel, general, 156, -146, 130)
    local function CommitPosition()
        panel.positionDirty = false
        local c = panel.controls
        local x, y = tonumber(c.x:GetText()), tonumber(c.y:GetText())
        -- Use false for missing values so an invalid field cannot become an omitted patch key.
        if Submit(panel, { position = { x = x or false, y = y or false } }, L.invalidPosition) then
            c.x:ClearFocus()
            c.y:ClearFocus()
        else
            panel.positionDirty = true
        end
    end
    for _, edit in ipairs({ panel.controls.x, panel.controls.y }) do
        edit:SetScript("OnEnterPressed", CommitPosition)
        edit:SetScript("OnTextChanged", function(_, userInput)
            if userInput and not panel.refreshing then panel.positionDirty = true end
        end)
    end
    panel.controls.applyPosition = Button(general, L.apply, 316, -146, 158, CommitPosition)
    panel.controls.centerPosition = Button(general, L.center, 0, -188, 130, function()
        panel.positionDirty = false
        Submit(panel, { position = { x = 0, y = 0 } })
    end)
    Label(general, L.positionHint, 0, -232, 470, 40)
    panel.controls.scale = Slider(panel, general, L.scale, -284, addon.limits.scale, 0.05,
        function(value) return { scale = value or false } end, L.invalidScale)

    local typography = panel.pages.typography
    Label(typography, L.appearanceHint, 0, -32, 470, 32)
    panel.controls.font = Dropdown(panel, typography, L.font, 0, -74, addon.fonts,
        function(value) return { font = { face = value } } end)
    panel.controls.fontSize = Slider(panel, typography, L.fontSize, -158, addon.limits.fontSize, 1,
        function(value) return { font = { size = value or false } } end, L.invalidFontSize)
    panel.controls.outline = Dropdown(panel, typography, L.outline, 0, -242, {
        { value = "", label = L.none }, { value = "OUTLINE", label = L.normal },
        { value = "THICKOUTLINE", label = L.thick },
    }, function(value) return { font = { outline = value } } end)
    panel.controls.shadow = CheckBox(panel, typography, L.shadow, 0, -316,
        function(value) return { shadow = { enabled = value } } end)
    Button(typography, L.openPreview, 316, -316, 158, function() addon:SelectOptionsCategory("preview") end)

    local page = panel.pages.preview
    Label(page, L.previewHint, 0, -32, 470, 44)
    local preview = CreateFrame("Frame", nil, page, "BackdropTemplate")
    preview:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -94)
    preview:SetSize(474, 150)
    Backdrop(preview, 0.025, 0.03, 0.04)
    preview.text = preview:CreateFontString(nil, "OVERLAY")
    preview.text:SetPoint("CENTER", preview, "CENTER", 0, 0)
    preview.text:SetTextColor(0.92, 0.97, 1, 1)
    preview:Hide()
    panel.previewFrame = preview
    panel.previewStatus = Label(page, "", 0, -262, 470, 24)
    panel.previewHidden = Label(page, "", 0, -294, 470, 24)
    Label(page, L.previewFit, 0, -328, 470, 44)

    panel:SetScript("OnShow", function()
        -- Re-evaluate only when opened; no frame or timer keeps the panel updating.
        panel:SetScale(math.min(1, UIParent:GetWidth() / 752, UIParent:GetHeight() / 592))
        addon:SelectOptionsCategory(panel.activeCategory)
    end)
    panel:SetScript("OnHide", function()
        CloseMenus(panel)
        ClearEdits(panel)
        CancelReset(panel)
        preview:Hide()
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "CarGOUIOptionsFrame"
    return panel
end

function addon:ToggleOptions()
    if not self.initialized then return end
    local panel = self:CreateOptions()
    panel:SetShown(not panel:IsShown())
end
