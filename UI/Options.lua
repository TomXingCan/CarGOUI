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
local CheckBox, Dropdown, NumberRow = CUI.CheckBox, CUI.Dropdown, CUI.NumberRow
local Backdrop, Feedback, CloseMenus = CUI.Backdrop, CUI.Feedback, CUI.CloseMenus

local function ClearEdits(panel)
    CUI.ClearNumericInteractions(panel)
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

local function SubmitNumeric(panel, patch, errorText)
    local ok = addon:UpdateSettings(patch, { skipOptionsRefresh = true })
    if ok then
        CancelReset(panel)
        Feedback(panel, L.saved)
    else Feedback(panel, errorText or L.invalid, true) end
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
        -- Never carry a draft from one entry/spec to another.
        controls.appearanceFontSize:CancelInteraction()
        controls.appearanceScale:CancelInteraction()
        panel.selectedAppearanceKey = FirstAppearance(allowed)
    end
    local key = panel.selectedAppearanceKey
    controls.appearanceFontSize:SetContext(key)
    controls.appearanceScale:SetContext(key)
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
        controls.appearanceFontSize:SetValue(style.font.size)
        controls.appearanceScale:SetValue(style.scale)
    else
        controls.appearanceFontStatus:SetText("")
        controls.appearanceFont.fontTooltip = nil
    end
    panel.appearanceHint:SetText(panel.appearanceKind == "proc"
        and addon:Text("Native Proc timers share this specialization style. Region offsets stay independent; contextual tests use separate samples.")
        or addon:Text("All Mobility skills and specializations in your current class share these settings. Live uses the detected skill."))
end

function addon:OpenAppearance(kind, key)
    local panel = self.optionsFrame
    if not panel then return end
    CUI.ClearNumericInteractions(panel)
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

local function RefreshContextualTests(panel)
    local controls, combat = panel.controls, InCombat()
    local entries = addon:GetPreviewEntries()
    controls.generalTest:SetEnabled(#entries > 0 and not combat)
    local state = addon.previewState
    local mode = state and state.mode or "off"
    controls.generalStop:SetEnabled(mode ~= "off")
    controls.mobilityStop:SetEnabled(mode ~= "off")
    controls.procStop:SetEnabled(mode ~= "off")
    SetPublicText(panel.generalTestStatus, combat and L.previewCombat or (#entries == 0 and L.noEntries
        or (mode == "off" and L.previewOff
        or string.format(L.previewRunning, mode == "all" and addon:Text("all defined entries for this spec") or addon:Text("selected entry")))))
end

-- State-change events update existing public context controls. No title rebuild,
-- gameplay query, or new widget allocation is needed for this refresh.
function addon:RefreshMobilityOptions()
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() then return end
    local controls = panel.controls
    local state = self.GetMobilityStatus and self:GetMobilityStatus() or { status = "Unsupported" }
    local entry = self.GetMobilityEntry and self:GetMobilityEntry() or nil
    local id = entry and entry.id
    if panel.mobilityEntryId ~= id then
        controls.mobilityX:CancelInteraction()
        controls.mobilityY:CancelInteraction()
        panel.mobilityEntryId = id
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
                or addon:Text("Per-skill details are available in Copy diagnostics.")))
    else SetPublicText(panel.mobilityStatus, string.format(L.mobilityStatus, self:Text(state.status or "Unknown")) .. "\n" .. reason) end
    local position = self:GetMobilityConfig().position
    local context = self:GetAppearanceContext("mobility")
    local contextKey = context and context.key
    controls.mobilityX:SetContext(contextKey); controls.mobilityY:SetContext(contextKey)
    controls.mobilityX:SetValue(position.x); controls.mobilityY:SetValue(position.y)
    local combat = InCombat()
    controls.mobilityPreview:SetEnabled(id ~= nil and state.spellID ~= nil and not combat)
    SetPublicText(panel.mobilityPreviewNote, combat and L.previewCombat or addon:Text("TEST uses fixed samples, never live timing."))
    local freeEntry
    for _, candidate in ipairs(self:GetPreviewEntries()) do
        if candidate.freeMove then freeEntry = candidate; break end
    end
    local freeId = freeEntry and freeEntry.id
    if panel.freeMoveEntryId ~= freeId then
        controls.freeMoveX:CancelInteraction(); controls.freeMoveY:CancelInteraction()
        panel.freeMoveEntryId = freeId
    end
    panel.freeMoveSection:SetShown(freeEntry ~= nil)
    for _, key in ipairs({ "freeMoveX", "freeMoveY", "freeMoveReset" }) do controls[key]:SetEnabled(freeEntry ~= nil) end
    controls.freeMovePreview:SetEnabled(freeEntry ~= nil and not combat)
    local freeContext = freeId and contextKey and contextKey .. ":" .. freeId or nil
    controls.freeMoveX:SetContext(freeContext); controls.freeMoveY:SetContext(freeContext)
    local freePosition = freeEntry and self:GetReminderPosition(freeEntry) or self:NewReminderPosition()
    controls.freeMoveX:SetValue(freePosition.x); controls.freeMoveY:SetValue(freePosition.y)
    panel.mobilityEditor:SetHeight(freeEntry and 638 or 424)
    panel.mobilityScroll:RefreshRange()
    RefreshContextualTests(panel)
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
        dialog.close = Button(dialog, L.close, 520, -386, 120, function() dialog:Hide() end, "ghost")
        dialog:HookScript("OnHide", function() edit:ClearFocus() end)
        panel.diagnosticsFrame = dialog
    end
    CloseMenus(panel)
    -- Ordinary focus loss uses each numeric row's validated commit/cancel path.
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
    controls.animatedTitle:SetChecked(db.options.animatedTitle)
    controls.showMinimapIcon:SetChecked(not db.options.minimap.hide)
    local _, spec = self:GetPlayerContext()
    panel.generalCharacter:SetText(self:GetLocalizedClassName() .. "  /  "
        .. (spec and self:GetLocalizedSpecName(spec) or self:Text("No defined style context")))
    RefreshAppearanceControls(panel)
    local entries, procChoices = self:GetPreviewEntries(), {}
    for _, entry in ipairs(entries) do
        if entry.kind == "proc" then
            procChoices[#procChoices + 1] = { value = entry.id, label = self:GetEntryDisplayLabel(entry) }
        end
    end
    controls.procEnabled:SetEnabled(#procChoices > 0)
    controls.procEnabled:SetChecked(#procChoices > 0 and self:GetProcConfig().enabled or false)
    local independent = self:GetProcPresentationPolicy() == "independent"
    controls.procEnabled.label:SetText(independent and addon:Text("Enable Proc") or addon:Text("Enable Proc timers"))
    panel.procStatus:SetText(#procChoices > 0
        and (independent and addon:Text("Independent Proc uses public Spell Alert events. Timers and artwork have separate settings; Test uses separate samples.")
            or addon:Text("Displays countdowns on supported Blizzard Proc graphics. Contextual tests show separate samples."))
        or addon:Text("No verified timed native Proc regions are available for this specialization / talent selection."))
    self:RefreshProcAppearanceOptions()
    self:RefreshProcColorControls()
    controls.procAppearance:SetEnabled(panel.selectedProcEntry ~= nil)
    controls.procPreview:SetEnabled(panel.selectedProcEntry ~= nil and not InCombatLockdown())
    controls.procStop:SetEnabled(self.previewState.mode ~= "off")
    panel.refreshing = false
    self:ApplyOptionsPosition()

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
    self:StopPreview(self.previewState.mode == "off")
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
    local inner, gap = width - 24, 16
    local half, right = (inner - gap) / 2, (inner + gap) / 2
    local character = CUI.Section(general, addon:Text("Current Character / Quick Test"), 0, -32, width, { height = 158 })
    local interface = CUI.Section(general, addon:Text("Interface"), 0, -198, width, { height = 128 })
    local window = CUI.Section(general, addon:Text("Window"), 0, -338, width, { height = 100 })
    panel.generalSections = { character, interface, window }
    panel.generalCharacter = Label(character.content, "", 0, 0, inner, 24, "GameFontNormal")
    panel.controls.generalTest = Button(character.content, L.previewAll, 0, -32, half, function()
        local ok, message = addon:SetPreview("all")
        addon:RefreshOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end, "primary")
    panel.controls.generalStop = Button(character.content, L.previewStop, right, -32, half, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    panel.generalTestStatus = Label(character.content, "", 0, -72, inner, 32)
    panel.controls.showMinimapIcon = CheckBox(panel, interface.content, L.showMinimapIcon, 0, 0,
        function(value) return { options = { minimap = { hide = not value } } } end)
    panel.controls.animatedTitle = CheckBox(panel, interface.content, L.animatedTitle, 0, -38,
        function(value) return { options = { animatedTitle = value } } end)
    panel.controls.centerOptions = Button(window.content, L.centerOptions, 0, 0, half, function()
        Submit(panel, { options = { position = { x = 0, y = 0 } } })
    end, "ghost")
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
    local function StyleContext() return panel.selectedAppearanceKey end
    panel.controls.appearanceFontSize = NumberRow(panel, editor, L.fontSize, 0, -266, width,
        { min = addon.limits.fontSize.min, max = addon.limits.fontSize.max, step = 1,
            default = addon.factoryReminderStyle.font.size, context = StyleContext, errorText = L.invalidFontSize },
        function(value, context)
            return SubmitNumeric(panel, { styles = { [context] = { font = { size = value } } } }, L.invalidFontSize)
        end)
    panel.controls.appearanceOutline = Dropdown(panel, editor, L.outline, 0, -352, {
        { value = "", label = L.none }, { value = "OUTLINE", label = L.normal },
        { value = "THICKOUTLINE", label = L.thick },
    }, function(value) return StylePatch({ font = { outline = value } }) end)
    panel.controls.appearanceShadow = CheckBox(panel, editor, L.shadow, 0, -424,
        function(value) return StylePatch({ shadow = { enabled = value } }) end)
    panel.controls.appearanceScale = NumberRow(panel, editor, L.scale, 0, -476, width,
        { min = addon.limits.scale.min, max = addon.limits.scale.max, step = .01,
            default = addon.factoryReminderStyle.scale, unit = "×", context = StyleContext, errorText = L.invalidScale },
        function(value, context)
            return SubmitNumeric(panel, { styles = { [context] = { scale = value } } }, L.invalidScale)
        end)
    Label(editor, L.appearanceHint, 0, -556, width, 40)
    panel.controls.appearanceReset = Button(editor, addon:Text("Reset this context's style"), 0, -606, (width - 24) / 2, function()
        ClearEdits(panel)
        CancelReset(panel)
        if addon:ResetReminderStyle(panel.selectedAppearanceKey) then Feedback(panel, L.saved) end
    end, "ghost")
    panel.controls.appearancePreview = Button(editor, addon:Text("Preview current reminder"), (width + 24) / 2, -606, (width - 24) / 2, function()
        local ok, message = addon:StartAppearancePreview(panel.selectedAppearanceKey)
        addon:RefreshOptions()
        if not ok then Feedback(panel, message, true) end
    end, "primary")
    panel.controls.appearanceBack = Button(editor, addon:Text("Back"), 0, -658, 140, function()
        addon:SelectOptionsCategory(panel.appearanceKind or "mobility")
    end, "ghost")
end

local function BuildProc(self, panel, page)
    self:CreateProcAppearanceOptions(panel, {
        Label = Label, Button = Button, Dropdown = Dropdown, EditBox = EditBox,
        CheckBox = CheckBox, ThemeControl = ThemeControl, Backdrop = Backdrop,
        Feedback = Feedback, ClearEdits = ClearEdits,
    })
end

local function BuildMobility(self, panel, mobility)
    local width = panel.shellGrid.contentWidth - 20
    local inner, gap = width - 24, 16
    local half, right = (inner - gap) / 2, (inner + gap) / 2
    local scroll = CUI.ScrollFrame(panel, mobility, 0, -32, width, mobility:GetHeight() - 32)
    local editor = CreateFrame("Frame", nil, scroll)
    editor:SetSize(width, 638); scroll:SetScrollChild(editor)
    self:RegisterOptionsDragSurface(scroll); self:RegisterOptionsDragSurface(editor)
    panel.mobilityScroll, panel.mobilityEditor = scroll, editor
    local status = CUI.Section(editor, addon:Text("Mobility"), 0, 0, width, { height = 194 })
    local position = CUI.Section(editor, addon:Text("Position / Test"), 0, -206, width, { height = 206 })
    local free = CUI.Section(editor, addon:Text("Free move"), 0, -424, width, { height = 202 })
    panel.mobilitySections, panel.freeMoveSection = { status, position, free }, free
    panel.controls.mobilityEnabled = CheckBox(panel, status.content, L.mobilityEnabled, 0, 0,
        function(value) return { mobility = { enabled = value } } end)
    panel.mobilitySpell = Label(status.content, "", 0, -36, inner, 24, "GameFontNormal")
    panel.mobilityStatus = Label(status.content, "", 0, -66, inner, 42)
    panel.controls.mobilityTypography = Button(status.content, L.mobilityTypography, 0, -110, half,
        function() addon:OpenAppearance("mobility") end)
    panel.controls.mobilityDiagnostics = Button(status.content, L.mobilityDiagnostics, right, -110, half,
        function() addon:ShowMobilityDiagnostics() end, "ghost")

    -- Each axis commits independently; an unfinished draft can never supply the
    -- other coordinate. Both rows share scope, while Free Move owns its position.
    local function PositionPair(parent, prefix, xLabel, yLabel, buildPatch)
        local function Context()
            local context = addon:GetAppearanceContext("mobility")
            if prefix == "freeMove" then
                return context and panel.freeMoveEntryId and context.key .. ":" .. panel.freeMoveEntryId or nil
            end
            return context and context.key
        end
        for index, axis in ipairs({ "x", "y" }) do
            local row = NumberRow(panel, parent, axis == "x" and xLabel or yLabel, 0, -(index - 1) * 38, inner,
                { min = addon.limits.offset.min, max = addon.limits.offset.max, step = 1, default = 0,
                    context = Context, errorText = L.invalidPosition }, function(value)
                    local patch = buildPatch({ [axis] = value })
                    return patch and SubmitNumeric(panel, patch, L.invalidPosition) or false
                end)
            panel.controls[prefix .. axis:upper()] = row
        end
        panel.controls[prefix .. "Reset"] = Button(parent, L.entryReset, right, -76, half, function()
            panel.controls[prefix .. "X"]:CancelInteraction()
            panel.controls[prefix .. "Y"]:CancelInteraction()
            local patch = buildPatch({ x = 0, y = 0 })
            if not patch then return end
            Submit(panel, patch)
        end, "ghost")
    end
    PositionPair(position.content, "mobility", L.entryX, L.entryY,
        function(position) return { mobility = { position = position } } end)
    PositionPair(free.content, "freeMove",
        addon:Text("Free Move position X"), addon:Text("Free Move position Y"), function(position)
            local id = panel.freeMoveEntryId
            return id and { reminders = { [id] = { position = position } } } or nil
        end)
    panel.controls.mobilityPreview = Button(position.content, addon:Text("Test Mobility"), 0, -76, half, function()
        local entry = addon.GetMobilityEntry and addon:GetMobilityEntry()
        local ok, message = false, L.mobilityNoSpell
        if entry then ok, message = addon:SetPreview("single", entry.id) end
        addon:RefreshMobilityOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end, "primary")
    panel.controls.mobilityStop = Button(position.content, L.previewStop, 0, -118, half, function()
        addon:StopPreview()
        addon:RefreshMobilityOptions()
    end)
    panel.mobilityPreviewNote = Label(position.content, "", right, -118, half, 36)
    panel.controls.freeMovePreview = Button(free.content, addon:Text("Test Free Move"), 0, -76, half, function()
        if not panel.freeMoveEntryId then return end
        local ok, message = addon:SetPreview("single", panel.freeMoveEntryId)
        addon:RefreshMobilityOptions()
        if ok == false then Feedback(panel, message or L.noEntries, true) end
    end, "primary")
    Label(free.content, addon:Text("Free Move position is independent of ordinary Mobility offsets."), 0, -118, inner, 30)
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
        local ok, message = addon:ResetDatabase()
        CancelReset(panel)
        if not ok then addon:RefreshOptions() end
        Feedback(panel, ok and L.resetDone or message or L.invalid, not ok)
    end, "ghost")
    panel.controls.close = Button(panel, L.close, panel.shellGrid.width - 140, footerY, 116, function() panel:Hide() end, "ghost")

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
