local _, addon = ...
local L = addon.L

-- Attach only to existing non-interactive frames. Native hit testing leaves
-- buttons, edits, sliders, menus and scrollbars in charge of their own input.
function addon:BeginOptionsDrag(button)
    local panel = self.optionsFrame
    if InCombatLockdown() or button ~= "LeftButton" or not panel or not panel:IsShown() or panel.dragging then return end
    panel.dragging = true
    panel:StartMoving()
end

function addon:RegisterOptionsDragSurface(surface)
    if surface.optionsDragSurface then return end
    surface.optionsDragSurface = true
    surface:EnableMouse(true)
    surface:RegisterForDrag("LeftButton")
    surface:SetScript("OnDragStart", function(_, button) addon:BeginOptionsDrag(button) end)
    surface:SetScript("OnDragStop", function() addon:SaveOptionsPosition() end)
    surface:HookScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then addon:SaveOptionsPosition() end
    end)
    surface:HookScript("OnHide", function() addon:SaveOptionsPosition() end)
end

local function ThemeControl(control, kind)
    if addon.optionsFrame and addon.RegisterOptionsThemeControl then
        addon:RegisterOptionsThemeControl(addon.optionsFrame, control, kind)
    end
end

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
    ThemeControl(button, "button")
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
    ThemeControl(edit, "input")
    panel.editBoxes[#panel.editBoxes + 1] = edit
    return edit
end

local function CheckBox(panel, parent, text, x, y, buildPatch)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    check:SetSize(26, 26)
    ThemeControl(check, "check")
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
    ThemeControl(menu, "menu")
    dropdown.menu = menu
    dropdown.choices = {}
    function dropdown:SetEntries(newEntries)
        entries = newEntries
        for index, entry in ipairs(entries) do
            local value = entry.value
            local choice = self.choices[index]
            if not choice then
                choice = Button(menu, entry.label, 6, -6 - (index - 1) * 28, 268, nil)
                self.choices[index] = choice
            end
            choice.value = value
            choice:SetText(entry.label)
            choice:SetScript("OnClick", function()
                if onSelect then onSelect(value) else Submit(panel, buildPatch(value)) end
                menu:Hide()
            end)
            choice:Show()
        end
        for index = #entries + 1, #self.choices do
            self.choices[index].value = nil
            self.choices[index]:Hide()
        end
    end
    dropdown:SetEntries(entries)
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
    ThemeControl(slider, "slider")
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

local function EligibleAppearance(kind)
    if kind == "proc" then
        local defined = false
        for _, entry in ipairs(addon:GetPreviewEntries()) do
            if entry.kind == "proc" then defined = true; break end
        end
        if not defined then return {} end
    end
    local context = addon:GetAppearanceContext(kind)
    return context and { [context.key] = true } or {}
end

local function FirstAppearance(allowed)
    for _, entry in ipairs(addon.appearanceEntries or {}) do
        if allowed[entry.key] then return entry.key end
    end
end

local function RefreshAppearanceControls(panel)
    local controls = panel.controls
    local allowed = EligibleAppearance(panel.appearanceKind or "mobility")
    if not allowed[panel.selectedAppearanceKey] then
        panel.selectedAppearanceKey = FirstAppearance(allowed)
        -- Never carry a draft from one entry/spec to another.
        controls.appearanceFontSize.editBox.dirty = false
        controls.appearanceScale.editBox.dirty = false
        controls.appearanceFontSize.editBox:ClearFocus()
        controls.appearanceScale.editBox:ClearFocus()
    end
    local key = panel.selectedAppearanceKey
    local context = addon:GetAppearanceContext(panel.appearanceKind or "mobility")
    -- Reuse the existing field as a read-only context label, not a selector.
    controls.appearanceEntry.menu:Hide()
    controls.appearanceEntry:SetText(key and context.label or "No defined style context")
    controls.appearanceEntry.value = key
    controls.appearanceEntry:Disable()
    for _, name in ipairs({ "appearanceFont", "appearanceFontSize", "appearanceOutline",
        "appearanceShadow", "appearanceScale", "appearanceReset" }) do
        controls[name]:SetEnabled(key ~= nil)
    end
    controls.appearanceFontSize.editBox:SetEnabled(key ~= nil)
    controls.appearanceScale.editBox:SetEnabled(key ~= nil)
    controls.appearancePreview:SetEnabled(key ~= nil and not InCombatLockdown()
        and (panel.appearanceKind == "proc" or addon:GetMobilityEntry() ~= nil))
    if key then
        local style = addon:GetReminderStyle(key)
        controls.appearanceFont:SelectValue(style.font.face)
        controls.appearanceOutline:SelectValue(style.font.outline)
        controls.appearanceShadow:SetChecked(style.shadow.enabled)
        SetSlider(controls.appearanceFontSize, style.font.size)
        SetSlider(controls.appearanceScale, style.scale)
    end
    panel.appearanceHint:SetText(panel.appearanceKind == "proc"
        and "Native Proc timers share this specialization style. Region offsets stay independent; Test Mode uses separate samples."
        or "All Mobility skills and specializations in your current class share these settings. Live uses the detected skill.")
end

function addon:OpenAppearance(kind, key)
    local panel = self.optionsFrame
    if not panel then return end
    panel.appearanceKind = kind == "proc" and "proc" or "mobility"
    local allowed = EligibleAppearance(panel.appearanceKind)
    panel.selectedAppearanceKey = FirstAppearance(allowed)
    self:SelectOptionsCategory("appearance")
end

function addon:RefreshOptionsThemeLabels(info)
    local panel = self.optionsFrame
    if not panel or not panel.themeIdentity then return end
    panel.themeIdentity:SetText("Theme: Automatic\nFaction: " .. info.faction
        .. "\nClass: " .. info.class .. "\nSpecialization: " .. info.specialization
        .. "\nHeader: " .. (info.headerPalette or info.palette)
        .. "\nBody: " .. (info.bodyPalette or info.palette))
    panel.themeFallback:SetText(info.fallback or "")
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
        or (mode == "off" and L.previewOff
        or string.format(L.previewRunning, mode == "all" and "all defined entries for this spec" or "selected entry"))))
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
    controls.mobilityEnabled:SetChecked(self:GetMobilityConfig().enabled)
    local spellName = state.spellName or L.mobilityNoSpell
    local states = self.GetMobilityStatuses and self:GetMobilityStatuses() or { state }
    local names, unavailable = {}, 0
    for _, current in ipairs(states) do
        if current.entry and current.spellName then names[#names + 1] = current.spellName end
        if current.status == "Restricted" or current.status == "Unsupported" or current.status == "Unknown" then
            unavailable = unavailable + 1
        end
    end
    if #names > 1 then
        local text = names[1] .. ", " .. names[2]
        if #names > 2 then text = text .. " (+" .. (#names - 2) .. ")" end
        SetPublicText(panel.mobilitySpell, "Detected: " .. text)
    else SetPublicText(panel.mobilitySpell, string.format(L.mobilitySpell, spellName)) end
    if id and state.spellName then
        local suffix = (state.status == "Unsupported" or state.status == "Restricted")
            and " - Preview only (live unavailable)" or " - mobility sample"
        controls.previewEntry:SetEntryLabel(id, state.spellName .. suffix)
    end
    local reason = state.reason or ""
    if not self:GetMobilityConfig().enabled then reason = L.mobilityDisabled end
    if #states > 1 and self:GetMobilityConfig().enabled then
        SetPublicText(panel.mobilityStatus, "Detected " .. #names .. " learned skills."
            .. "\n" .. (unavailable > 0 and (unavailable .. " unavailable/restricted; see Copy diagnostics.")
                or "Per-skill details: Copy diagnostics. Samples: Test Mode entry menu."))
    else SetPublicText(panel.mobilityStatus, string.format(L.mobilityStatus, state.status or "Unknown") .. "\n" .. reason) end
    local position = id and self:GetReminderPosition(entry)
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
        self:RegisterOptionsDragSurface(dialog)
        ThemeControl(dialog, "dialog")
        Label(dialog, L.diagnosticsTitle, 20, -16, 620, 24, "GameFontNormalLarge")
        Label(dialog, L.diagnosticsHint, 20, -48, 620, 36)
        local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", dialog, "TOPLEFT", 20, -88)
        scroll:SetSize(594, 288)
        self:RegisterOptionsDragSurface(scroll)
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
        dialog:HookScript("OnHide", function() edit:ClearFocus() end)
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
    local mobility = self:GetMobilityConfig()
    controls.enabled:SetChecked(mobility.enabled)
    controls.animatedTitle:SetChecked(db.options.animatedTitle)
    if not panel.positionDirty then
        controls.x:SetText(string.format("%g", mobility.position.x))
        controls.y:SetText(string.format("%g", mobility.position.y))
    end
    RefreshAppearanceControls(panel)
    local entries, procAllowed, procChoices, previewChoices = self:GetPreviewEntries(), {}, {}, {}
    for _, entry in ipairs(entries) do
        previewChoices[#previewChoices + 1] = { value = entry.id, label = entry.label }
        if entry.kind == "proc" then
            procAllowed[entry.id] = true
            procChoices[#procChoices + 1] = { value = entry.id, label = entry.label }
        end
    end
    controls.procEnabled:SetEnabled(#procChoices > 0)
    controls.procEnabled:SetChecked(#procChoices > 0 and self:GetProcConfig().enabled or false)
    panel.procStatus:SetText(#procChoices > 0
        and "Displays countdowns on supported Blizzard Proc graphics. Test Mode shows separate samples."
        or "No verified timed native Proc regions are available for this specialization / talent selection.")
    controls.procEntry:SetEntries(procChoices)
    controls.previewEntry:SetEntries(previewChoices)
    if not procAllowed[panel.selectedProcEntry] then
        panel.selectedProcEntry = procChoices[1] and procChoices[1].value
    end
    controls.procEntry:FilterChoices(procAllowed)
    controls.procEntry:SelectValue(panel.selectedProcEntry)
    self:RefreshProcColorControls()
    controls.procAppearance:SetEnabled(panel.selectedProcEntry ~= nil)
    controls.procPreview:SetEnabled(panel.selectedProcEntry ~= nil and not InCombatLockdown())
    controls.procStop:SetEnabled(self.previewState.mode ~= "off")
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
        local position
        for _, entry in ipairs(entries) do
            if entry.id == selected then position = self:GetReminderPosition(entry); break end
        end
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
    self:CancelProcColorPicker()
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
            local selected = button.key == key or (key == "appearance" and button.key == panel.appearanceKind)
            button:SetText((selected and "> " or "") .. L[button.key])
            self:ApplyOptionsCategoryTheme(button, selected)
        end
    end
    Feedback(panel, L.immediate)
    self:RefreshOptions()
end

local function OnOptionsSpecializationChanged(self, _, unit)
    if issecretvalue and issecretvalue(unit) then return end
    if unit and unit ~= "player" then return end
    self:CancelProcColorPicker()
    CloseMenus(self.optionsFrame)
    ClearEdits(self.optionsFrame)
    self:RefreshOptions()
end

local function CancelOptionsOpenRetry(self)
    if self.optionsOpenRetry then
        self.optionsOpenRetry:Cancel()
        self.optionsOpenRetry = nil
    end
end

local function OnPendingOptionsCombatEnded(self)
    if not self.pendingOptionsOpen then return end
    if not InCombat() then
        self:OpenOptions()
    elseif not self.optionsOpenRetry and C_Timer and C_Timer.NewTimer then
        -- The regen event can precede the lockdown transition. Retry exactly
        -- once next tick, never from this timer itself. If still locked, retain
        -- the request for the next regen event instead of polling in combat.
        local retry
        retry = C_Timer.NewTimer(0, function()
            if self.optionsOpenRetry ~= retry then return end
            self.optionsOpenRetry = nil
            if self.pendingOptionsOpen and not InCombat() then self:OpenOptions() end
        end)
        self.optionsOpenRetry = retry
    end
end

function addon:QueueOptionsOpen()
    if not self.pendingOptionsOpen then
        self.pendingOptionsOpen = true -- Session state only, never SavedVariables.
        self:Print("Options will open when combat ends.")
    end
    self:RegisterEvent("PLAYER_REGEN_ENABLED", OnPendingOptionsCombatEnded)
end

local function ConsumeOptionsOpen(self)
    self.pendingOptionsOpen = nil
    CancelOptionsOpenRetry(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED", OnPendingOptionsCombatEnded)
end

function addon:CloseOptions()
    local panel = self.optionsFrame
    if panel and panel:IsShown() then panel:Hide() end
    -- OnHide owns editing/preview cleanup. It must never consume a queued open.
end

local function OnOptionsCombatChanged(self)
    self:CloseOptions()
end

function addon:CreateOptions()
    if InCombat() then self:QueueOptionsOpen(); return nil end
    if not self.initialized or not self.db then return nil end
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
    self:RegisterOptionsDragSurface(panel)
    local header = self:CreateOptionsBranding(panel)
    panel.header = header
    self:RegisterOptionsDragSurface(header)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.22, 0.30, 0.34, 1)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 192, -82)
    divider:SetSize(1, 380)
    panel.themeDivider = divider

    for _, key in ipairs({ "general", "appearance", "preview", "mobility", "proc", "themes" }) do
        local page = CreateFrame("Frame", nil, panel)
        page:SetPoint("TOPLEFT", panel, "TOPLEFT", 216, -88)
        page:SetSize(480, 374)
        page:Hide()
        self:RegisterOptionsDragSurface(page)
        ThemeControl(page, "content")
        panel.pages[key] = page
        Label(page, L[key], 0, 0, 470, 24, "GameFontNormalLarge")
    end
    for index, key in ipairs({ "general", "preview", "mobility", "proc", "themes", "importExport" }) do
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
    self:CreateOptionsTheme(panel)
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
    panel.controls.centerPosition = Button(general, "Reset Mobility offsets", 0, -214, 180, function()
        panel.positionDirty = false
        Submit(panel, { position = { x = 0, y = 0 } })
    end)
    Label(general, L.positionHint, 0, -174, 470, 36)
    Label(general, "Mobility settings belong to your current class. Proc styles belong to your current class and specialization.", 0, -266, 470, 48)
    panel.controls.animatedTitle = CheckBox(panel, general, L.animatedTitle, 0, -332,
        function(value) return { options = { animatedTitle = value } } end)
    panel.controls.centerOptions = Button(general, L.centerOptions, 316, -332, 158, function()
        Submit(panel, { options = { position = { x = 0, y = 0 } } })
    end)

    local appearance = panel.pages.appearance
    local scroll = CreateFrame("ScrollFrame", nil, appearance, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", appearance, "TOPLEFT", 0, -32)
    scroll:SetSize(448, 336)
    self:RegisterOptionsDragSurface(scroll)
    local editor = CreateFrame("Frame", nil, scroll)
    editor:SetSize(448, 654)
    self:RegisterOptionsDragSurface(editor)
    scroll:SetScrollChild(editor)
    panel.appearanceScroll = scroll
    local appearanceChoices = {}
    for _, entry in ipairs(self.appearanceEntries) do
        appearanceChoices[#appearanceChoices + 1] = { value = entry.key, label = entry.label }
    end
    panel.controls.appearanceEntry = Dropdown(panel, editor, "Configuration context (automatic)", 0, 0, appearanceChoices, nil, function() end)
    panel.controls.appearanceEntry:Disable()
    panel.appearanceHint = Label(editor, "", 0, -64, 438, 44)
    local function StylePatch(patch)
        local key = panel.selectedAppearanceKey
        return key and { styles = { [key] = patch } } or { styles = false }
    end
    panel.controls.appearanceFont = Dropdown(panel, editor, L.font, 0, -122, addon.fonts,
        function(value) return StylePatch({ font = { face = value } }) end)
    panel.controls.appearanceFontSize = Slider(panel, editor, L.fontSize, -200, addon.limits.fontSize, 1,
        function(value) return StylePatch({ font = { size = value or false } }) end, L.invalidFontSize)
    panel.controls.appearanceOutline = Dropdown(panel, editor, L.outline, 0, -286, {
        { value = "", label = L.none }, { value = "OUTLINE", label = L.normal },
        { value = "THICKOUTLINE", label = L.thick },
    }, function(value) return StylePatch({ font = { outline = value } }) end)
    panel.controls.appearanceShadow = CheckBox(panel, editor, L.shadow, 0, -358,
        function(value) return StylePatch({ shadow = { enabled = value } }) end)
    panel.controls.appearanceScale = Slider(panel, editor, L.scale, -410, addon.limits.scale, 0.05,
        function(value) return StylePatch({ scale = value or false }) end, L.invalidScale)
    for _, slider in ipairs({ panel.controls.appearanceFontSize, panel.controls.appearanceScale }) do
        slider:SetWidth(288)
        slider.editBox:ClearAllPoints()
        slider.editBox:SetPoint("TOPLEFT", editor, "TOPLEFT", 318, slider == panel.controls.appearanceFontSize and -224 or -434)
    end
    Label(editor, L.appearanceHint, 0, -490, 430, 40)
    panel.controls.appearanceReset = Button(editor, "Reset this context's style", 0, -540, 220, function()
        ClearEdits(panel)
        CancelReset(panel)
        if addon:ResetReminderStyle(panel.selectedAppearanceKey) then Feedback(panel, L.saved) end
    end)
    panel.controls.appearancePreview = Button(editor, "Preview current reminder", 232, -540, 198, function()
        local ok, message = addon:StartAppearancePreview(panel.selectedAppearanceKey)
        addon:RefreshOptions()
        if not ok then Feedback(panel, message, true) end
    end)
    panel.controls.appearanceBack = Button(editor, "Back", 0, -592, 140, function()
        addon:SelectOptionsCategory(panel.appearanceKind or "mobility")
    end)

    local page = panel.pages.preview
    Label(page, L.previewHint, 0, -32, 470, 44)
    local previewEntries = {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
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

    local proc = panel.pages.proc
    panel.controls.procEnabled = CheckBox(panel, proc, "Enable Proc timers", 0, -32,
        function(value) return { proc = { enabled = value } } end)
    panel.procStatus = Label(proc, "", 0, -68, 470, 40)
    local procChoices = {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
        if entry.kind == "proc" then procChoices[#procChoices + 1] = { value = entry.id, label = entry.label } end
    end
    panel.controls.procEntry = Dropdown(panel, proc, "Proc region", 0, -110, procChoices, nil, function(key)
        addon:CancelProcColorPicker()
        ClearEdits(panel)
        panel.selectedProcEntry = key
        addon:RefreshOptions()
    end)
    panel.controls.procEntry:SetWidth(474)
    panel.procColorSelection = Label(proc, "", 0, -174, 474, 20, "GameFontHighlight")
    Label(proc, "Timer color:", 0, -202, 90, 20, "GameFontNormal")
    panel.controls.procColor = Button(proc, "", 94, -196, 38, function()
        local ok, message = addon:OpenProcColorPicker(addon:GetSelectedProcColorEntry())
        if not ok then Feedback(panel, message, true) end
    end)
    local swatch = panel.controls.procColor:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("TOPLEFT", panel.controls.procColor, "TOPLEFT", 5, -5)
    swatch:SetPoint("BOTTOMRIGHT", panel.controls.procColor, "BOTTOMRIGHT", -5, 5)
    panel.controls.procColor.swatch = swatch
    panel.procColorMode = Label(proc, "", 142, -202, 102, 20)
    panel.controls.procColorReset = Button(proc, "Use class color", 248, -196, 226, function()
        addon:CancelProcColorPicker()
        local entry = addon:GetSelectedProcColorEntry()
        if entry and addon:SetProcRegionColor(entry, nil) then Feedback(panel, L.saved) end
        addon:RefreshProcColorControls()
    end)
    panel.controls.procAppearance = Button(proc, "Appearance", 0, -242, 226, function()
        addon:OpenAppearance("proc", panel.selectedProcEntry)
    end)
    panel.controls.procPreview = Button(proc, "Preview this region", 248, -242, 226, function()
        local ok, message = addon:SetPreview("single", panel.selectedProcEntry)
        addon:RefreshOptions()
        if not ok then Feedback(panel, message, true) end
    end)
    panel.controls.procStop = Button(proc, L.previewStop, 0, -282, 226, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    Button(proc, "Region position / Test Mode", 248, -282, 226, function()
        panel.selectedPreviewEntry = panel.selectedProcEntry
        addon:SelectOptionsCategory("preview")
    end)
    Label(proc, "Proc font, size, outline, shadow and scale are shared within this specialization. Each region has its own position and optional timer color.", 0, -326, 470, 44)

    local themes = panel.pages.themes
    Label(themes, "Automatic faction Header and class / specialization Body. No manual selection or custom colors.", 0, -36, 470, 42)
    panel.themeIdentity = Label(themes, "", 0, -92, 470, 168, "GameFontHighlight")
    panel.themeFallback = Label(themes, "", 0, -276, 470, 72)

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
        function()
            addon:OpenAppearance("mobility")
        end)
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
        addon:RefreshOptionsTheme()
        addon:SelectOptionsCategory(panel.activeCategory)
    end)
    panel:HookScript("OnHide", function()
        addon:CancelProcColorPicker()
        addon:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnOptionsSpecializationChanged)
        addon:UnregisterEvent("PLAYER_REGEN_DISABLED", OnOptionsCombatChanged)
        addon:StopOptionsTheme()
        if panel.diagnosticsFrame then panel.diagnosticsFrame:Hide() end
        -- Restore live output only when it was actually suppressed by TEST.
        addon:StopPreview(addon.previewState.mode == "off")
        addon:StopTitleAnimation()
        addon:SaveOptionsPosition()
        CloseMenus(panel)
        ClearEdits(panel)
        CancelReset(panel)
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "CarGOUIOptionsFrame"
    return panel
end

function addon:OpenOptions()
    if InCombat() then self:QueueOptionsOpen(); return false end
    if not self.initialized or not self.db then return false end
    local panel = self:CreateOptions()
    if not panel then return false end
    -- OnShow retains the page but validates current class/spec and entry lists.
    -- Explicit Show is idempotent; a deferred request cannot toggle it closed.
    if not panel:IsShown() then panel:Show() end
    if panel:IsShown() then ConsumeOptionsOpen(self); return true end
    return false
end

function addon:ToggleOptions()
    if InCombat() then self:QueueOptionsOpen(); return false end
    local panel = self.optionsFrame
    if panel and panel:IsShown() then self:CloseOptions(); return true end
    return self:OpenOptions()
end
