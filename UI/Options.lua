local _, addon = ...
local L = addon.L

-- One native movement session belongs to the actual empty surface that received
-- OnDragStart, while only the Options root is ever moved. Retail's explicit
-- current-mouse option avoids using a stale root-frame mouse-down origin when
-- a child (page/header/scroll content) forwards the drag. No polling is needed.
local dragBoundaryEvents = { "GLOBAL_MOUSE_UP", "GLOBAL_MOUSE_DOWN",
    "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_LEAVING_WORLD" }

local function PublicNumber(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function OnOptionsDragBoundary(self, event, button)
    if event == "GLOBAL_MOUSE_UP" or event == "GLOBAL_MOUSE_DOWN" then
        if (issecretvalue and issecretvalue(button)) or button ~= "LeftButton" then return end
        -- UP works even outside the initiating child. A new DOWN also releases
        -- an obsolete session if a prior release was lost during focus loss.
    end
    self:SaveOptionsPosition()
    if event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        local panel = self.optionsFrame
        if panel and panel:IsShown() then
            self:ClampOptionsShell()
        end
    end
end

local function WatchOptionsDrag(self, enabled)
    local method = enabled and self.RegisterEvent or self.UnregisterEvent
    for _, event in ipairs(dragBoundaryEvents) do method(self, event, OnOptionsDragBoundary) end
end

local function OnOptionsViewportChanged(self)
    local panel = self.optionsFrame
    -- A live drag keeps its existing boundary handler as the sole position
    -- owner. Ordinary viewport changes only clamp the visible presentation.
    if panel and panel:IsShown() and not panel.dragging then self:ClampOptionsShell() end
end

function addon:BeginOptionsDrag(button, surface)
    local panel = self.optionsFrame
    if InCombatLockdown() or button ~= "LeftButton" or not panel or not panel:IsShown() or panel.dragging then return end
    surface = surface or panel
    if not surface.optionsDragSurface then return end
    panel.dragging, panel.dragSource = true, surface
    -- Do not SetPoint, restore saved position or change scale at pickup.
    panel:StartMoving(true)
    if panel.dragging and panel.dragSource == surface then WatchOptionsDrag(self, true) end
end

local function OwnsDragSurface(panel, surface, ancestorAllowed)
    if not panel or not panel.dragging then return false end
    if surface == panel or surface == panel.dragSource then return true end
    if ancestorAllowed then
        local current = panel.dragSource
        while current and current ~= panel do
            current = current:GetParent()
            if current == surface then return true end
        end
    end
    return false
end

function addon:RegisterOptionsDragSurface(surface)
    if surface.optionsDragSurface then return end
    surface.optionsDragSurface = true
    surface:EnableMouse(true)
    surface:RegisterForDrag("LeftButton")
    surface:SetScript("OnDragStart", function(frame, button) addon:BeginOptionsDrag(button, frame) end)
    surface:SetScript("OnDragStop", function(frame)
        local panel = addon.optionsFrame
        -- Late STOP from a different child must not cancel a new session.
        if panel and panel.dragSource == frame then addon:SaveOptionsPosition() end
    end)
    surface:HookScript("OnMouseUp", function(frame, button)
        if button == "LeftButton" and OwnsDragSurface(addon.optionsFrame, frame, false) then
            addon:SaveOptionsPosition()
        end
    end)
    surface:HookScript("OnHide", function(frame)
        -- Hiding an unrelated page/dialog is not the end of this drag.
        if OwnsDragSurface(addon.optionsFrame, frame, true) then addon:SaveOptionsPosition() end
    end)
end

local function ThemeControl(control, kind)
    if addon.optionsFrame and addon.RegisterOptionsThemeControl then
        addon:RegisterOptionsThemeControl(addon.optionsFrame, control, kind)
    end
end

local CUI = addon.CUI
local Label, Button, EditBox = CUI.Label, CUI.Button, CUI.EditBox
local CheckBox, Dropdown, Slider = CUI.CheckBox, CUI.Dropdown, CUI.Slider
local Backdrop, Feedback, CloseMenus = CUI.Backdrop, CUI.Feedback, CUI.CloseMenus

local function ClearEdits(panel)
    panel.positionDirty = false
    panel.entryPositionDirty = false
    panel.mobilityPositionDirty = false
    for _, edit in ipairs(panel.editBoxes) do
        edit.dirty = false
        edit:ClearFocus()
        if edit.SetInvalid then edit:SetInvalid(false) end
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

local function FontTooltip(control)
    control:HookScript("OnEnter", function(self)
        if not self.fontTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.fontTooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    local function HideTooltip(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
    end
    control:HookScript("OnLeave", HideTooltip)
    control:HookScript("OnHide", HideTooltip)
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
    controls.appearanceEntry:SetText(key and context.label or addon:Text("No defined style context"))
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
        controls.appearanceFont:SetEntries(addon:GetReminderFontOptions())
        controls.appearanceFont:SelectValue(style.font.face)
        local status = addon:GetReminderFontStatus(style.font.face)
        -- The button always names the saved choice, including a missing media
        -- name. The separate status names the effective local fallback.
        controls.appearanceFont:SetText(status.selectedLabel .. "  v")
        controls.appearanceFont.value = style.font.face
        local reason = status.fallbackReason
        local detail = not status.effectiveAvailable
            and addon:Text("Neither the requested font nor the local default font is available.")
            or reason == "locale" and addon:Text("Not suitable for this client language.")
            or reason == "missing-media" and addon:Text("SharedMedia font is unavailable on this client.")
            or reason == "invalid" and addon:Text("Invalid font preference.")
            or reason and addon:Text("Unavailable on this client.")
            or addon:Text("Available on this client.")
        local fontStatus = addon:Format("Selected: %s\n%s\nUsing: %s",
            status.selectedLabel, detail, status.effectiveLabel)
        controls.appearanceFontStatus:SetText(fontStatus)
        controls.appearanceFont.fontTooltip = fontStatus
        controls.appearanceOutline:SelectValue(style.font.outline)
        controls.appearanceShadow:SetChecked(style.shadow.enabled)
        SetSlider(controls.appearanceFontSize, style.font.size)
        SetSlider(controls.appearanceScale, style.scale)
    else
        controls.appearanceFontStatus:SetText("")
        controls.appearanceFont.fontTooltip = nil
    end
    panel.appearanceHint:SetText(panel.appearanceKind == "proc"
        and addon:Text("Native Proc timers share this specialization style. Region offsets stay independent; Test Mode uses separate samples.")
        or addon:Text("All Mobility skills and specializations in your current class share these settings. Live uses the detected skill."))
end

function addon:OpenAppearance(kind, key)
    local panel = self.optionsFrame
    if not panel then return end
    panel.appearanceKind = kind == "proc" and "proc" or "mobility"
    local allowed = EligibleAppearance(panel.appearanceKind)
    panel.selectedAppearanceKey = FirstAppearance(allowed)
    self:SelectOptionsCategory("appearance")
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
        or string.format(L.previewRunning, mode == "all" and addon:Text("all defined entries for this spec") or addon:Text("selected entry")))))
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
    local spellName = state.spellName and self:GetLocalizedSpellName(state.spellID, state.spellName) or L.mobilityNoSpell
    local states = self.GetMobilityStatuses and self:GetMobilityStatuses() or { state }
    local names, unavailable = {}, 0
    for _, current in ipairs(states) do
        if current.entry and current.spellName then
            names[#names + 1] = self:GetLocalizedSpellName(current.spellID, current.spellName)
        end
        if current.status == "Restricted" or current.status == "Unsupported" or current.status == "Unknown" then
            unavailable = unavailable + 1
        end
    end
    if #names > 1 then
        local text = names[1] .. ", " .. names[2]
        if #names > 2 then text = text .. " (+" .. (#names - 2) .. ")" end
        SetPublicText(panel.mobilitySpell, addon:Text("Detected: ") .. text)
    else SetPublicText(panel.mobilitySpell, string.format(L.mobilitySpell, spellName)) end
    if id and state.spellName then
        local suffix = (state.status == "Unsupported" or state.status == "Restricted")
            and addon:Text(" - Preview only (live unavailable)") or addon:Text(" - mobility sample")
        controls.previewEntry:SetEntryLabel(id, spellName .. suffix)
    end
    -- Keep machine status and detailed API reasons stable in Copy diagnostics.
    local descriptions = {
        Ready = "At least one use is available.",
        Depleted = "No uses remain; tracking the next recovery.",
        ["Native tracking"] = "Visibility and timing are controlled by the client.",
        ["Not learned"] = "No supported Mobility skill is currently learned for this specialization.",
    }
    local reason = self:Text(descriptions[state.status] or "Details are available in Copy diagnostics.")
    if not self:GetMobilityConfig().enabled then reason = L.mobilityDisabled end
    if #states > 1 and self:GetMobilityConfig().enabled then
        SetPublicText(panel.mobilityStatus, addon:Format("Detected %d learned skills.", #names)
            .. "\n" .. (unavailable > 0 and addon:Format("%d unavailable/restricted; see Copy diagnostics.", unavailable)
                or addon:Text("Per-skill details: Copy diagnostics. Samples: Test Mode entry menu.")))
    else SetPublicText(panel.mobilityStatus, string.format(L.mobilityStatus, self:Text(state.status or "Unknown")) .. "\n" .. reason) end
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
    SetPublicText(panel.mobilityPreviewNote, combat and L.previewCombat or addon:Text("TEST uses fixed samples, never live timing."))
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
        local scroll = CUI.ScrollFrame(panel, dialog, 20, -88, 620, 288)
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
        addon.DesignSystem.Skin(edit, "input")
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
            scroll:RefreshRange()
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
    if self.RefreshSettingsTransferPage then self:RefreshSettingsTransferPage() end
    local controls, db = panel.controls, self.db
    panel.refreshing = true
    local mobility = self:GetMobilityConfig()
    controls.enabled:SetChecked(mobility.enabled)
    controls.animatedTitle:SetChecked(db.options.animatedTitle)
    controls.showMinimapIcon:SetChecked(not db.options.minimap.hide)
    if not panel.positionDirty then
        controls.x:SetText(string.format("%g", mobility.position.x))
        controls.y:SetText(string.format("%g", mobility.position.y))
    end
    RefreshAppearanceControls(panel)
    local entries, procAllowed, procChoices, previewChoices = self:GetPreviewEntries(), {}, {}, {}
    for _, entry in ipairs(entries) do
        previewChoices[#previewChoices + 1] = { value = entry.id, label = self:GetEntryDisplayLabel(entry) }
        if entry.kind == "proc" then
            procAllowed[entry.id] = true
            procChoices[#procChoices + 1] = { value = entry.id, label = self:GetEntryDisplayLabel(entry) }
        end
    end
    controls.procEnabled:SetEnabled(#procChoices > 0)
    controls.procEnabled:SetChecked(#procChoices > 0 and self:GetProcConfig().enabled or false)
    panel.procStatus:SetText(#procChoices > 0
        and addon:Text("Displays countdowns on supported Blizzard Proc graphics. Test Mode shows separate samples.")
        or addon:Text("No verified timed native Proc regions are available for this specialization / talent selection."))
    controls.previewEntry:SetEntries(previewChoices)
    self:RefreshProcAppearanceOptions()
    self:RefreshProcColorControls()
    controls.procAppearance:SetEnabled(panel.selectedProcEntry ~= nil)
    controls.procPreview:SetEnabled(panel.selectedProcEntry ~= nil and not InCombatLockdown())
    controls.procStop:SetEnabled(self.previewState.mode ~= "off")
    panel.refreshing = false
    self:ApplyOptionsPosition()

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
    -- Capture the visual center before native Stop changes the anchor basis.
    -- All persistence is in UIParent units, independent of the initiating child.
    local x, y = panel:GetCenter()
    local px, py = UIParent:GetCenter()
    local frameScale, parentScale = panel:GetEffectiveScale(), UIParent:GetEffectiveScale()
    -- Clear ownership first: native STOP/OnHide may invoke another release hook.
    panel.dragging, panel.dragSource = false, nil
    WatchOptionsDrag(self, false)
    panel:StopMovingOrSizing()
    if panel.SetUserPlaced then panel:SetUserPlaced(false) end
    panel.appliedX = nil
    if not (PublicNumber(x) and PublicNumber(y) and PublicNumber(px) and PublicNumber(py)
        and PublicNumber(frameScale) and frameScale > 0
        and PublicNumber(parentScale) and parentScale > 0) then
        self:ApplyOptionsPosition(true)
        return
    end
    local factor = frameScale / parentScale
    local ok = self:UpdateSettings({ options = { position = { x = x * factor - px, y = y * factor - py } } })
    if not ok then self:ApplyOptionsPosition(true) end
end

function addon:SelectOptionsCategory(key)
    local panel = self.optionsFrame
    if not panel then return end
    if InCombat() then self:CloseOptions(); return end
    if not self.optionsPageRegistry[key] then key = "general" end
    if self.ClearSettingsTransferPage then self:ClearSettingsTransferPage() end
    self:CancelProcColorPicker()
    CUI.StopMotion(panel)
    if panel.diagnosticsFrame then panel.diagnosticsFrame:Hide() end
    ClearEdits(panel)
    CancelReset(panel)
    panel.activeCategory = key
    self:BuildOptionsPage(key)
    for pageKey, page in pairs(panel.pages) do
        page:SetShown(pageKey == key)
    end
    self:RefreshOptionsNavigationSelection()
    local descriptor = self.optionsPageRegistry[key]
    local hint = descriptor.hint
    if type(hint) == "function" then hint = hint(self, panel, descriptor) end
    Feedback(panel, hint or L.immediate)
    self:RefreshOptions()
end

local function OnOptionsSpecializationChanged(self, _, unit)
    if issecretvalue and issecretvalue(unit) then return end
    if unit and unit ~= "player" then return end
    if self.ClearSettingsTransferPage then self:ClearSettingsTransferPage() end
    self:CancelProcColorPicker()
    CUI.StopMotion(self.optionsFrame)
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
        self:Print(addon:Text("Options will open when combat ends."))
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

local function BuildGeneral(self, panel, general)
    local width = panel.shellGrid.contentWidth
    local half, right = (width - 24) / 2, (width + 24) / 2
    Label(general, L.generalHint, 0, -32, width, 32)
    panel.controls.enabled = CheckBox(panel, general, L.enabled, 0, -70,
        function(value) return { enabled = value } end)
    Label(general, L.x, 0, -112, half, 22, "GameFontNormal")
    Label(general, L.y, right, -112, half, 22, "GameFontNormal")
    panel.controls.x = EditBox(panel, general, 0, -138, half)
    panel.controls.y = EditBox(panel, general, right, -138, half)
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
    panel.controls.centerPosition = Button(general, addon:Text("Reset Mobility offsets"), 0, -214, half, function()
        panel.positionDirty = false
        Submit(panel, { position = { x = 0, y = 0 } })
    end)
    Label(general, L.positionHint, 0, -174, width, 36)
    Label(general, addon:Text("Mobility settings belong to your current class. Proc styles belong to your current class and specialization."), 0, -250, width, 40)
    panel.controls.animatedTitle = CheckBox(panel, general, L.animatedTitle, 0, -332,
        function(value) return { options = { animatedTitle = value } } end)
    panel.controls.centerOptions = Button(general, L.centerOptions, 0, -390, half, function()
        Submit(panel, { options = { position = { x = 0, y = 0 } } })
    end)
    panel.controls.showMinimapIcon = CheckBox(panel, general, L.showMinimapIcon, 0, -296,
        function(value) return { options = { minimap = { hide = not value } } } end)
end

local function BuildAppearance(self, panel, appearance)
    local width = panel.shellGrid.contentWidth - 20
    local scroll = CUI.ScrollFrame(panel, appearance, 0, -36,
        panel.shellGrid.contentWidth, panel.shellGrid.contentHeight - 36)
    self:RegisterOptionsDragSurface(scroll)
    local editor = CreateFrame("Frame", nil, scroll)
    editor:SetSize(panel.shellGrid.contentWidth - 20, 720)
    self:RegisterOptionsDragSurface(editor)
    scroll:SetScrollChild(editor)
    panel.appearanceScroll = scroll
    local appearanceChoices = {}
    for _, entry in ipairs(self.appearanceEntries) do
        appearanceChoices[#appearanceChoices + 1] = { value = entry.key, label = entry.label }
    end
    panel.controls.appearanceEntry = Dropdown(panel, editor, addon:Text("Configuration context (automatic)"), 0, 0, appearanceChoices, nil, function() end)
    panel.controls.appearanceEntry:Disable()
    panel.appearanceHint = Label(editor, "", 0, -64, width, 44)
    local function StylePatch(patch)
        local key = panel.selectedAppearanceKey
        return key and { styles = { [key] = patch } } or { styles = false }
    end
    panel.controls.appearanceFont = Dropdown(panel, editor, L.font, 0, -122, addon:GetReminderFontOptions(),
        function(value) return StylePatch({ font = { face = value } }) end, nil, 8)
    panel.controls.appearanceFont:SetWidth(width)
    FontTooltip(panel.controls.appearanceFont)
    panel.controls.appearanceFontStatus = Label(editor, "", 0, -184, width, 60)
    panel.controls.appearanceFontSize = Slider(panel, editor, L.fontSize, -266, addon.limits.fontSize, 1,
        function(value) return StylePatch({ font = { size = value or false } }) end, L.invalidFontSize)
    panel.controls.appearanceOutline = Dropdown(panel, editor, L.outline, 0, -352, {
        { value = "", label = L.none }, { value = "OUTLINE", label = L.normal },
        { value = "THICKOUTLINE", label = L.thick },
    }, function(value) return StylePatch({ font = { outline = value } }) end)
    panel.controls.appearanceShadow = CheckBox(panel, editor, L.shadow, 0, -424,
        function(value) return StylePatch({ shadow = { enabled = value } }) end)
    panel.controls.appearanceScale = Slider(panel, editor, L.scale, -476, addon.limits.scale, 0.05,
        function(value) return StylePatch({ scale = value or false }) end, L.invalidScale)
    Label(editor, L.appearanceHint, 0, -556, width, 40)
    panel.controls.appearanceReset = Button(editor, addon:Text("Reset this context's style"), 0, -606, (width - 24) / 2, function()
        ClearEdits(panel)
        CancelReset(panel)
        if addon:ResetReminderStyle(panel.selectedAppearanceKey) then Feedback(panel, L.saved) end
    end)
    panel.controls.appearancePreview = Button(editor, addon:Text("Preview current reminder"), (width + 24) / 2, -606, (width - 24) / 2, function()
        local ok, message = addon:StartAppearancePreview(panel.selectedAppearanceKey)
        addon:RefreshOptions()
        if not ok then Feedback(panel, message, true) end
    end)
    panel.controls.appearanceBack = Button(editor, addon:Text("Back"), 0, -658, 140, function()
        addon:SelectOptionsCategory(panel.appearanceKind or "mobility")
    end)
end

local function BuildPreview(self, panel, page)
    local width = panel.shellGrid.contentWidth
    local third, stride = (width - 48) / 3, (width + 24) / 3
    Label(page, L.previewHint, 0, -32, width, 44)
    local previewEntries = {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
        previewEntries[#previewEntries + 1] = { value = entry.id, label = self:GetEntryDisplayLabel(entry) }
    end
    panel.controls.previewEntry = Dropdown(panel, page, L.previewEntry, 0, -86, previewEntries, nil, function(id)
        panel.selectedPreviewEntry = id
        panel.entryPositionDirty = false
        panel.controls.entryX:ClearFocus()
        panel.controls.entryY:ClearFocus()
        if addon.previewState and addon.previewState.mode == "single" then addon:SetPreview("single", id) end
        addon:RefreshOptions()
    end)
    panel.controls.previewEntry:SetWidth(width)
    local function StartPreview(mode)
        local ok, message = addon:SetPreview(mode, panel.selectedPreviewEntry)
        addon:RefreshOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end
    panel.controls.previewSingle = Button(page, L.previewSingle, 0, -154, third, function() StartPreview("single") end)
    panel.controls.previewAll = Button(page, L.previewAll, stride, -154, third, function() StartPreview("all") end)
    panel.controls.previewStop = Button(page, L.previewStop, stride * 2, -154, third, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    Label(page, L.entryX, 0, -198, third, 22, "GameFontNormal")
    Label(page, L.entryY, stride, -198, third, 22, "GameFontNormal")
    panel.controls.entryX = EditBox(panel, page, 0, -224, third)
    panel.controls.entryY = EditBox(panel, page, stride, -224, third)
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
    panel.controls.entryReset = Button(page, L.entryReset, stride * 2, -224, third, function()
        local id = panel.selectedPreviewEntry
        if not id then return end
        panel.entryPositionDirty = false
        Submit(panel, { reminders = { [id] = { position = { x = 0, y = 0 } } } })
    end)
    Label(page, L.entryHint, 0, -266, width, 44)
    panel.previewStatus = Label(page, "", 0, -324, width, 48)
end

local function BuildProc(self, panel, page)
    self:CreateProcAppearanceOptions(panel, {
        Label = Label, Button = Button, Dropdown = Dropdown, EditBox = EditBox,
        CheckBox = CheckBox, ThemeControl = ThemeControl, Backdrop = Backdrop,
        Feedback = Feedback, ClearEdits = ClearEdits,
    })
end

local function BuildMobility(self, panel, mobility)
    local width = panel.shellGrid.contentWidth
    local half, right = (width - 24) / 2, (width + 24) / 2
    panel.controls.mobilityEnabled = CheckBox(panel, mobility, L.mobilityEnabled, 0, -32,
        function(value) return { mobility = { enabled = value } } end)
    panel.mobilitySpell = Label(mobility, "", 0, -72, width, 22, "GameFontNormal")
    panel.mobilityStatus = Label(mobility, "", 0, -98, width, 48)
    Label(mobility, L.mobilityPosition, 0, -152, width, 22)
    Label(mobility, L.entryX, 0, -178, half, 22, "GameFontNormal")
    Label(mobility, L.entryY, right, -178, half, 22, "GameFontNormal")
    panel.controls.mobilityX = EditBox(panel, mobility, 0, -202, half)
    panel.controls.mobilityY = EditBox(panel, mobility, right, -202, half)
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
    panel.controls.mobilityGeneral = Button(mobility, L.mobilityGeneral, 0, -242, half,
        function() addon:SelectOptionsCategory("general") end)
    panel.controls.mobilityTypography = Button(mobility, L.mobilityTypography, right, -242, half,
        function()
            addon:OpenAppearance("mobility")
        end)
    panel.controls.mobilityPreview = Button(mobility, L.mobilityPreview, 0, -282, half, function()
        local entry = addon.GetMobilityEntry and addon:GetMobilityEntry()
        local ok, message = false, L.mobilityNoSpell
        if entry then ok, message = addon:SetPreview("single", entry.id) end
        addon:RefreshMobilityOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end)
    panel.controls.mobilityStop = Button(mobility, L.previewStop, right, -282, half, function()
        addon:StopPreview()
        addon:RefreshMobilityOptions()
    end)
    panel.controls.mobilityDiagnostics = Button(mobility, L.mobilityDiagnostics, 0, -326, half,
        function() addon:ShowMobilityDiagnostics() end)
    panel.mobilityPreviewNote = Label(mobility, "", right, -326, half, 46)
end

local function BuildSettingsTransfer(self, panel, page)
    self:CreateSettingsTransferPage(panel, page, {
        Label = Label, Button = Button, Dropdown = Dropdown,
        ThemeControl = ThemeControl, Feedback = Feedback,
    })
end

addon:RegisterOptionsPage({ key = "general", order = 10, builder = BuildGeneral })
addon:RegisterOptionsPage({ key = "mobility", order = 20, builder = BuildMobility })
addon:RegisterOptionsPage({ key = "proc", order = 30, builder = BuildProc })
addon:RegisterOptionsPage({ key = "preview", order = 40, builder = BuildPreview })
addon:RegisterOptionsPage({ key = "importExport", order = 50, lazy = true,
    hint = function() return L.transferHint end, builder = BuildSettingsTransfer })
addon:RegisterOptionsPage({ key = "appearance", order = 60, hidden = true,
    navParent = function(_, panel) return panel.appearanceKind or "mobility" end, builder = BuildAppearance })

function addon:CreateOptions()
    if InCombat() then self:QueueOptionsOpen(); return nil end
    if not self.initialized or not self.db then return nil end
    if self.optionsFrame then return self.optionsFrame end
    local panel = CreateFrame("Frame", "CarGOUIOptionsFrame", UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    -- SavedVariables is the sole persistence owner, not the native layout cache.
    if panel.SetDontSavePosition then panel:SetDontSavePosition(true) end
    if panel.SetUserPlaced then panel:SetUserPlaced(false) end
    panel:EnableMouse(true)
    panel.controls, panel.pages, panel.categories = {}, {}, {}
    panel.editBoxes, panel.dropdowns = {}, {}
    panel.activeCategory = "general"
    self.optionsFrame, panel.cuiPanel = panel, panel
    panel.submit = function(patch, errorText) return Submit(panel, patch, errorText) end
    self:RegisterOptionsDragSurface(panel)
    self:CreateOptionsShell(panel)
    local header = self:CreateOptionsBranding(panel)
    panel.header = header
    self:RegisterOptionsDragSurface(header)
    self:CreateOptionsTheme(panel)
    local footerY = -panel.shellGrid.height + panel.shellGrid.footerHeight - 16
    panel.feedback = Label(panel, "", panel.shellGrid.contentX, footerY,
        panel.shellGrid.contentWidth - 140, 32)
    panel.controls.reset = Button(panel, L.reset, 24, footerY, 144, function()
        CloseMenus(panel)
        if not panel.resetArmed then
            panel.resetArmed = true
            panel.controls.reset:SetText(L.confirmReset)
            Feedback(panel, L.resetHint)
            return
        end
        ClearEdits(panel)
        if addon.ClearSettingsTransferPage then addon:ClearSettingsTransferPage() end
        addon:ResetDatabase()
        CancelReset(panel)
        Feedback(panel, L.resetDone)
    end)
    panel.controls.close = Button(panel, L.close, panel.shellGrid.width - 140, footerY, 116, function() panel:Hide() end)

    self:RefreshOptionsNavigation()

    panel:SetScript("OnShow", function()
        -- Re-evaluate only when opened; no frame or timer keeps the panel updating.
        addon:ClampOptionsShell()
        if panel.navigationDirty then addon:RefreshOptionsNavigation() end
        addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnOptionsSpecializationChanged)
        addon:RegisterEvent("PLAYER_REGEN_DISABLED", OnOptionsCombatChanged)
        addon:RegisterEvent("UI_SCALE_CHANGED", OnOptionsViewportChanged)
        addon:RegisterEvent("DISPLAY_SIZE_CHANGED", OnOptionsViewportChanged)
        addon:RefreshOptionsTheme()
        addon:SelectOptionsCategory(panel.activeCategory)
        addon:RefreshTitleAnimation()
    end)
    panel:HookScript("OnHide", function()
        if addon.ClearSettingsTransferPage then addon:ClearSettingsTransferPage() end
        addon:CancelProcColorPicker()
        addon:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnOptionsSpecializationChanged)
        addon:UnregisterEvent("PLAYER_REGEN_DISABLED", OnOptionsCombatChanged)
        addon:UnregisterEvent("UI_SCALE_CHANGED", OnOptionsViewportChanged)
        addon:UnregisterEvent("DISPLAY_SIZE_CHANGED", OnOptionsViewportChanged)
        addon:StopOptionsTheme()
        if panel.diagnosticsFrame then panel.diagnosticsFrame:Hide() end
        -- Restore live output only when it was actually suppressed by TEST.
        addon:StopPreview(addon.previewState.mode == "off")
        addon:StopTitleAnimation()
        addon:SaveOptionsPosition()
        CUI.StopMotion(panel)
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
