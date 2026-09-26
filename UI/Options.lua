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
    panel.entryPositionDirty = false
    panel.mobilityPositionDirty = false
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

local function Dropdown(panel, parent, text, x, y, entries, buildPatch, onSelect)
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
            if onSelect then onSelect(value) else Submit(panel, buildPatch(value)) end
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
    function dropdown:SetEntryLabel(value, label)
        for _, entry in ipairs(entries) do
            if entry.value == value then
                if entry.label == label then return end
                entry.label = label
                for _, choice in ipairs(self.choices) do
                    if choice.value == value then choice:SetText(label); break end
                end
                if self.value == value then self:SetText(label .. "  v") end
                return
            end
        end
    end
    function dropdown:FilterChoices(allowed)
        local count = 0
        for _, choice in ipairs(self.choices) do
            local available = allowed[choice.value] == true
            choice:SetShown(available)
            choice:SetEnabled(available)
            if available then
                choice:ClearAllPoints()
                choice:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - count * 28)
                count = count + 1
            end
        end
        menu:SetHeight(math.max(1, count) * 28 + 12)
        self:SetEnabled(count > 0)
        if count == 0 then self:SetText("No entries"); self.value = nil; menu:Hide() end
    end
    panel.dropdowns[#panel.dropdowns + 1] = dropdown
    return dropdown
end

local function Slider(panel, parent, text, y, range, step, buildPatch, errorText)
    Label(parent, text, 0, y, 470, 22, "GameFontNormal")
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 30)
    slider:SetSize(330, 18)
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
    local maximum = Label(parent, tostring(range.max), 274, y - 54, 56)
    maximum:SetJustifyH("RIGHT")
    local edit = EditBox(panel, parent, 362, y - 24, 112)
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

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function SetPublicText(control, text)
    if control:GetText() ~= text then control:SetText(text) end
end

local function RefreshPreviewControls(panel)
    local controls, selected, combat = panel.controls, panel.selectedPreviewEntry, InCombat()
    controls.previewSingle:SetEnabled(selected ~= nil and not combat)
    controls.previewAll:SetEnabled(selected ~= nil and not combat)
    local state = addon.previewState
    local mode = state and state.mode or "off"
    controls.previewStop:SetEnabled(mode ~= "off")
    SetPublicText(panel.previewStatus, combat and L.previewCombat or (not selected and L.noEntries
        or (mode == "off" and L.previewOff or (not addon.db.enabled and L.previewHidden
        or string.format(L.previewRunning, mode == "all" and "all defined entries for this spec" or "selected entry")))))
end

-- This method is safe to call from a state-change event: it only updates public
-- Mobility labels and existing controls, never the title, layout or other pages.
function addon:RefreshMobilityOptions()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return end
    local controls = panel.controls
    local state = self.GetMobilityStatus and self:GetMobilityStatus() or { status = "Unsupported" }
    local entry = self.GetMobilityEntry and self:GetMobilityEntry() or nil
    local id = entry and entry.id
    if panel.mobilityEntryId ~= id then
        panel.mobilityEntryId = id
        panel.mobilityPositionDirty = false
        controls.mobilityX:ClearFocus()
        controls.mobilityY:ClearFocus()
    end
    controls.mobilityEnabled:SetChecked(self.db.mobility.enabled)
    local spellName = state.spellName or L.mobilityNoSpell
    SetPublicText(panel.mobilitySpell, string.format(L.mobilitySpell, spellName))
    if id and state.spellName then
        controls.previewEntry:SetEntryLabel(id, state.spellName .. " - mobility sample")
    end
    local reason = state.reason or ""
    if not self.db.enabled then reason = L.mobilityDisabled end
    SetPublicText(panel.mobilityStatus, string.format(L.mobilityStatus, state.status or "Unknown") .. "\n" .. reason)
    local position = id and self.db.reminders[id] and self.db.reminders[id].position
    controls.mobilityX:SetEnabled(position ~= nil)
    controls.mobilityY:SetEnabled(position ~= nil)
    if not panel.mobilityPositionDirty then
        SetPublicText(controls.mobilityX, position and string.format("%g", position.x) or "")
        SetPublicText(controls.mobilityY, position and string.format("%g", position.y) or "")
    end
    local combat = InCombat()
    controls.mobilityPreview:SetEnabled(id ~= nil and state.spellID ~= nil and not combat)
    controls.mobilityStop:SetEnabled(self.previewState and self.previewState.mode ~= "off")
    SetPublicText(panel.mobilityPreviewNote, combat and L.previewCombat or "TEST uses fixed samples, never live timing.")
    RefreshPreviewControls(panel)
end

function addon:ShowMobilityDiagnostics()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return end
    local dialog = panel.diagnosticsFrame
    if not dialog then
        dialog = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        dialog:Hide()
        dialog:SetSize(660, 430)
        dialog:SetPoint("CENTER", panel, "CENTER", 0, 0)
        dialog:SetFrameLevel(panel:GetFrameLevel() + 30)
        dialog:EnableMouse(true)
        Backdrop(dialog, 0.045, 0.06, 0.075)
        Label(dialog, L.diagnosticsTitle, 20, -16, 620, 24, "GameFontNormalLarge")
        Label(dialog, L.diagnosticsHint, 20, -48, 620, 36)
        local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -88)
        scroll:SetSize(594, 288)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetSize(588, 288)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(0)
        edit:SetFontObject("ChatFontNormal")
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetJustifyH("LEFT")
        edit:SetJustifyV("TOP")
        scroll:SetScrollChild(edit)
        dialog.editBox = edit
        edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
        edit:SetScript("OnTextChanged", function(self, userInput)
            -- Read-only snapshot while retaining normal selection and Ctrl+C.
            if userInput then self:SetText(dialog.snapshot or ""); self:HighlightText() end
        end)
        local function RefreshSnapshot()
            dialog.snapshot = addon.GetMobilityDiagnostics and addon:GetMobilityDiagnostics() or L.diagnosticsUnavailable
            local _, lines = string.gsub(dialog.snapshot, "\n", "")
            edit:SetHeight(math.max(288, (lines + 1) * 20))
            edit:SetText(dialog.snapshot)
            edit:SetFocus()
            edit:HighlightText()
        end
        dialog.RefreshSnapshot = RefreshSnapshot
        dialog.refresh = Button(dialog, L.diagnosticsRefresh, 20, -386, 160, RefreshSnapshot)
        dialog.selectAll = Button(dialog, L.diagnosticsSelect, 192, -386, 140, function()
            edit:SetFocus(); edit:HighlightText()
        end)
        dialog.close = Button(dialog, L.close, 520, -386, 120, function() dialog:Hide() end)
        dialog:SetScript("OnHide", function() edit:ClearFocus() end)
        panel.diagnosticsFrame = dialog
    end
    CloseMenus(panel)
    -- Copying diagnostics should not discard numbers the user is still editing.
    for _, edit in ipairs(panel.editBoxes) do edit:ClearFocus() end
    dialog:Show()
    dialog.RefreshSnapshot()
end

function addon:RefreshOptions()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return end
    local controls, db = panel.controls, self.db
    panel.refreshing = true
    controls.enabled:SetChecked(db.enabled)
    controls.animatedTitle:SetChecked(db.options.animatedTitle)
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
    self:ApplyOptionsPosition()
    self:RefreshTitleAnimation()

    local entries, allowed = self:GetPreviewEntries(), {}
    for _, entry in ipairs(entries) do allowed[entry.id] = true end
    if not allowed[panel.selectedPreviewEntry] then
        panel.selectedPreviewEntry = entries[1] and entries[1].id
        panel.entryPositionDirty = false
        controls.entryX:ClearFocus()
        controls.entryY:ClearFocus()
    end
    local selected = panel.selectedPreviewEntry
    controls.previewEntry:FilterChoices(allowed)
    controls.previewEntry:SelectValue(selected)
    controls.entryReset:SetEnabled(selected ~= nil)
    if selected then controls.entryX:Enable(); controls.entryY:Enable()
    else controls.entryX:Disable(); controls.entryY:Disable() end
    if not panel.entryPositionDirty then
        local position = selected and db.reminders[selected].position
        controls.entryX:SetText(position and string.format("%g", position.x) or "")
        controls.entryY:SetText(position and string.format("%g", position.y) or "")
    end
    self:RefreshMobilityOptions()
end

function addon:ApplyOptionsPosition(force)
    local panel, position = self.optionsFrame, self.db.options.position
    if not panel or panel.dragging then return end
    local scale = panel:GetScale()
    if force or panel.appliedX ~= position.x or panel.appliedY ~= position.y or panel.appliedScale ~= scale then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", position.x / scale, position.y / scale)
        panel.appliedX, panel.appliedY, panel.appliedScale = position.x, position.y, scale
    end
end

function addon:SaveOptionsPosition()
    local panel = self.optionsFrame
    if not panel or not panel.dragging then return end
    panel:StopMovingOrSizing()
    panel.dragging = false
    local x, y = panel:GetCenter()
    local px, py = UIParent:GetCenter()
    if not x or not y or not px or not py then return end
    local factor = panel:GetEffectiveScale() / UIParent:GetEffectiveScale()
    panel.appliedX = nil
    self:UpdateSettings({ options = { position = { x = x * factor - px, y = y * factor - py } } })
end

function addon:SelectOptionsCategory(key)
    local panel = self.optionsFrame
    if not panel or not panel.pages[key] then return end
    CloseMenus(panel)
    if panel.diagnosticsFrame then panel.diagnosticsFrame:Hide() end
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

local function OnOptionsSpecializationChanged(self, _, unit)
    if unit and unit ~= "player" then return end
    CloseMenus(self.optionsFrame)
    self:RefreshOptions()
end

local function OnOptionsCombatChanged(self)
    self:RefreshMobilityOptions()
end

function addon:CreateOptions()
    if self.optionsFrame then return self.optionsFrame end
    local panel = CreateFrame("Frame", "CarGOUIOptionsFrame", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(720, 560)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    Backdrop(panel, 0.045, 0.06, 0.075)
    panel.controls, panel.pages, panel.categories = {}, {}, {}
    panel.editBoxes, panel.dropdowns = {}, {}
    panel.activeCategory = "general"
    self.optionsFrame = panel
    local header = self:CreateOptionsBranding(panel)
    panel.header = header
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        panel.dragging = true
        panel:StartMoving()
    end)
    header:SetScript("OnDragStop", function() addon:SaveOptionsPosition() end)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.22, 0.30, 0.34, 1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 192, -82)
    divider:SetSize(1, 380)

    for _, key in ipairs({ "general", "typography", "preview", "mobility" }) do
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
    Label(general, L.x, 0, -112, 222, 22, "GameFontNormal")
    Label(general, L.y, 248, -112, 226, 22, "GameFontNormal")
    panel.controls.x = EditBox(panel, general, 0, -138, 222)
    panel.controls.y = EditBox(panel, general, 248, -138, 226)
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
    panel.controls.centerPosition = Button(general, "Reset global offsets", 0, -214, 180, function()
        panel.positionDirty = false
        Submit(panel, { position = { x = 0, y = 0 } })
    end)
    Label(general, L.positionHint, 0, -174, 470, 36)
    panel.controls.scale = Slider(panel, general, L.scale, -250, addon.limits.scale, 0.05,
        function(value) return { scale = value or false } end, L.invalidScale)
    panel.controls.animatedTitle = CheckBox(panel, general, L.animatedTitle, 0, -332,
        function(value) return { options = { animatedTitle = value } } end)
    panel.controls.centerOptions = Button(general, L.centerOptions, 316, -332, 158, function()
        Submit(panel, { options = { position = { x = 0, y = 0 } } })
    end)

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
    local previewEntries = {}
    for _, entry in ipairs(self.previewEntries) do
        previewEntries[#previewEntries + 1] = { value = entry.id, label = entry.label }
    end
    panel.controls.previewEntry = Dropdown(panel, page, L.previewEntry, 0, -86, previewEntries, nil, function(id)
        panel.selectedPreviewEntry = id
        panel.entryPositionDirty = false
        panel.controls.entryX:ClearFocus()
        panel.controls.entryY:ClearFocus()
        if addon.previewState and addon.previewState.mode == "single" then addon:SetPreview("single", id) end
        addon:RefreshOptions()
    end)
    panel.controls.previewEntry:SetWidth(474)
    local function StartPreview(mode)
        local ok, message = addon:SetPreview(mode, panel.selectedPreviewEntry)
        addon:RefreshOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end
    panel.controls.previewSingle = Button(page, L.previewSingle, 0, -154, 148, function() StartPreview("single") end)
    panel.controls.previewAll = Button(page, L.previewAll, 160, -154, 158, function() StartPreview("all") end)
    panel.controls.previewStop = Button(page, L.previewStop, 330, -154, 144, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    Label(page, L.entryX, 0, -198, 140, 22, "GameFontNormal")
    Label(page, L.entryY, 158, -198, 140, 22, "GameFontNormal")
    panel.controls.entryX = EditBox(panel, page, 0, -224, 140)
    panel.controls.entryY = EditBox(panel, page, 158, -224, 140)
    local function CommitEntryPosition()
        local id = panel.selectedPreviewEntry
        if not id then return end
        local x, y = tonumber(panel.controls.entryX:GetText()), tonumber(panel.controls.entryY:GetText())
        panel.entryPositionDirty = false
        if Submit(panel, { reminders = { [id] = { position = { x = x or false, y = y or false } } } }, L.invalidPosition) then
            panel.controls.entryX:ClearFocus()
            panel.controls.entryY:ClearFocus()
        else panel.entryPositionDirty = true end
    end
    for _, edit in ipairs({ panel.controls.entryX, panel.controls.entryY }) do
        edit:SetScript("OnEnterPressed", CommitEntryPosition)
        edit:SetScript("OnTextChanged", function(_, userInput)
            if userInput and not panel.refreshing then panel.entryPositionDirty = true end
        end)
    end
    panel.controls.entryReset = Button(page, L.entryReset, 316, -224, 158, function()
        local id = panel.selectedPreviewEntry
        if not id then return end
        panel.entryPositionDirty = false
        Submit(panel, { reminders = { [id] = { position = { x = 0, y = 0 } } } })
    end)
    Label(page, L.entryHint, 0, -266, 470, 44)
    panel.previewStatus = Label(page, "", 0, -324, 470, 48)

    local mobility = panel.pages.mobility
    panel.controls.mobilityEnabled = CheckBox(panel, mobility, L.mobilityEnabled, 0, -32,
        function(value) return { mobility = { enabled = value } } end)
    panel.mobilitySpell = Label(mobility, "", 0, -72, 470, 22, "GameFontNormal")
    panel.mobilityStatus = Label(mobility, "", 0, -98, 470, 48)
    Label(mobility, L.mobilityPosition, 0, -152, 470, 22)
    Label(mobility, L.entryX, 0, -178, 226, 22, "GameFontNormal")
    Label(mobility, L.entryY, 248, -178, 226, 22, "GameFontNormal")
    panel.controls.mobilityX = EditBox(panel, mobility, 0, -202, 226)
    panel.controls.mobilityY = EditBox(panel, mobility, 248, -202, 226)
    local function CommitMobilityPosition()
        local id = panel.mobilityEntryId
        if not id then return end
        local x, y = tonumber(panel.controls.mobilityX:GetText()), tonumber(panel.controls.mobilityY:GetText())
        panel.mobilityPositionDirty = false
        if Submit(panel, { reminders = { [id] = { position = { x = x or false, y = y or false } } } }, L.invalidPosition) then
            panel.controls.mobilityX:ClearFocus()
            panel.controls.mobilityY:ClearFocus()
        else panel.mobilityPositionDirty = true end
    end
    for _, edit in ipairs({ panel.controls.mobilityX, panel.controls.mobilityY }) do
        edit:SetScript("OnEnterPressed", CommitMobilityPosition)
        edit:SetScript("OnTextChanged", function(_, userInput)
            if userInput and not panel.refreshing then panel.mobilityPositionDirty = true end
        end)
    end
    panel.controls.mobilityGeneral = Button(mobility, L.mobilityGeneral, 0, -242, 226,
        function() addon:SelectOptionsCategory("general") end)
    panel.controls.mobilityTypography = Button(mobility, L.mobilityTypography, 248, -242, 226,
        function() addon:SelectOptionsCategory("typography") end)
    panel.controls.mobilityPreview = Button(mobility, L.mobilityPreview, 0, -282, 226, function()
        local entry = addon.GetMobilityEntry and addon:GetMobilityEntry()
        local ok, message = false, L.mobilityNoSpell
        if entry then ok, message = addon:SetPreview("single", entry.id) end
        addon:RefreshMobilityOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end)
    panel.controls.mobilityStop = Button(mobility, L.previewStop, 248, -282, 226, function()
        addon:StopPreview()
        addon:RefreshMobilityOptions()
    end)
    panel.controls.mobilityDiagnostics = Button(mobility, L.mobilityDiagnostics, 0, -326, 200,
        function() addon:ShowMobilityDiagnostics() end)
    panel.mobilityPreviewNote = Label(mobility, "", 220, -326, 254, 46)

    panel:SetScript("OnShow", function()
        -- Re-evaluate only when opened; no frame or timer keeps the panel updating.
        panel:SetScale(math.min(1, UIParent:GetWidth() / 752, UIParent:GetHeight() / 592))
        addon:ApplyOptionsPosition(true)
        addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnOptionsSpecializationChanged)
        addon:RegisterEvent("PLAYER_REGEN_DISABLED", OnOptionsCombatChanged)
        addon:RegisterEvent("PLAYER_REGEN_ENABLED", OnOptionsCombatChanged)
        addon:SelectOptionsCategory(panel.activeCategory)
    end)
    panel:SetScript("OnHide", function()
        addon:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnOptionsSpecializationChanged)
        addon:UnregisterEvent("PLAYER_REGEN_DISABLED", OnOptionsCombatChanged)
        addon:UnregisterEvent("PLAYER_REGEN_ENABLED", OnOptionsCombatChanged)
        if panel.diagnosticsFrame then panel.diagnosticsFrame:Hide() end
        addon:StopPreview()
        addon:StopTitleAnimation()
        addon:SaveOptionsPosition()
        CloseMenus(panel)
        ClearEdits(panel)
        CancelReset(panel)
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "CarGOUIOptionsFrame"
    return panel
end

function addon:ToggleOptions()
    if not self.initialized then return end
    local panel = self:CreateOptions()
    panel:SetShown(not panel:IsShown())
end
