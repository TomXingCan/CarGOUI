local _, addon = ...
local L = addon.L

local function Available(panel)
    return panel and panel:IsShown() and panel.activeCategory == "importExport"
        and not (InCombatLockdown and InCombatLockdown())
end

-- Cleanup is safe during combat and does not apply settings or restore a draft.
-- Native editors have no size cap: the backend rejects oversized data explicitly.
function addon:ClearSettingsTransferPage()
    if self.CancelSettingsImport then self:CancelSettingsImport() end
    local panel = self.optionsFrame
    local state = panel and panel.transfer
    if not state or state.clearing then return end
    state.clearing = true
    state.transaction, state.exportText, state.summaryText = nil, nil, nil
    state.scope = "class"
    for _, edit in ipairs(state.editors) do
        edit:ClearFocus()
        edit:SetText("")
        edit:SetHeight(edit.minimumHeight)
        edit.scroll:SetVerticalScroll(0)
        edit.scroll:RefreshRange()
    end
    state.confirmation:Hide()
    state.body:Show()
    panel.controls.transferScope.menu:Hide()
    panel.controls.transferScope:SelectValue(state.scope)
    panel.controls.transferConfirm:Disable()
    panel.controls.transferSelectAll:Disable()
    state.class, state.specID = self:GetPlayerContext()
    state.clearing = nil
end

function addon:RefreshSettingsTransferPage()
    local panel = self.optionsFrame
    local state = panel and panel.transfer
    if not state then return end
    local class, specID = self:GetPlayerContext()
    if state.class ~= class or state.specID ~= specID or not Available(panel) then
        self:ClearSettingsTransferPage()
    end
    local ready = Available(panel)
    local controls = panel.controls
    controls.transferExport:SetEnabled(ready and not state.transaction)
    controls.transferImport:SetEnabled(ready and not state.transaction)
    controls.transferRestore:SetEnabled(ready and not state.transaction
        and self.HasSettingsImportBackup and self:HasSettingsImportBackup() == true)
    controls.transferConfirm:SetEnabled(ready and state.transaction ~= nil)
    controls.transferSelectAll:SetEnabled(ready and state.exportText ~= nil and state.exportText ~= "")
end

function addon:CreateSettingsTransferPage(panel, page, ui)
    if panel.transfer then return panel.transfer end
    if not Available(panel) then return end
    local CUI = addon.CUI
    local width = page:GetWidth()
    local inner = width - 2 * addon.DesignSystem.sectionPadding
    local state = { scope = "class", editors = {} }
    panel.transfer = state
    state.class, state.specID = self:GetPlayerContext()
    local controls = panel.controls
    local body = CreateFrame("Frame", nil, page)
    body:SetAllPoints(page)
    -- Normal page background still participates in the existing drag system;
    -- text editors and scrollbars own their mouse input above this surface.
    self:RegisterOptionsDragSurface(body)
    state.body = body
    local confirmation = CreateFrame("Frame", nil, page)
    confirmation:SetAllPoints(page)
    self:RegisterOptionsDragSurface(confirmation)
    confirmation:Hide()
    state.confirmation = confirmation

    local function Feedback(text, failed)
        ui.Feedback(panel, text, failed)
    end
    local function Ready()
        if Available(panel) then return true end
        addon:ClearSettingsTransferPage()
        if panel:IsShown() then Feedback(L.transferBlocked, true) end
        return false
    end
    local function DropTransaction()
        if addon.CancelSettingsImport then addon:CancelSettingsImport() end
        state.transaction, state.summaryText = nil, nil
        if controls.transferSummary then controls.transferSummary:SetText("") end
        confirmation:Hide()
        body:Show()
        controls.transferConfirm:Disable()
    end

    local function Editor(parent, key, y, height, readOnlyKey)
        local scroll = CUI.ScrollFrame(panel, parent, 0, y, inner - 16, height)
        ui.ThemeControl(scroll, "input")
        -- The editor and thin scrollbar own input; they are never drag surfaces.
        local edit = CUI.EditBox(panel, scroll, 0, 0, inner - 28)
        edit:SetHeight(height)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(0)
        edit:SetMaxBytes(0)
        edit:SetFontObject("ChatFontNormal")
        edit:SetTextInsets(6, 6, 6, 6)
        edit:SetJustifyH("LEFT")
        edit:SetJustifyV("TOP")
        ui.ThemeControl(edit, "input")
        scroll:SetScrollChild(edit)
        edit.scroll, edit.minimumHeight = scroll, height
        state.editors[#state.editors + 1] = edit
        controls[key] = edit
        local function Resize()
            local _, fontHeight = edit:GetFont()
            edit:SetHeight(math.max(height, edit:GetNumLines() * ((fontHeight or 14) + 2) + 12))
            scroll:UpdateScrollChildRect()
            scroll:RefreshRange()
        end
        edit:SetScript("OnTextChanged", function(self, userInput)
            if state.clearing then return end
            if readOnlyKey and userInput then
                self:SetText(state[readOnlyKey] or "")
                self:HighlightText()
                return
            end
            -- Text replacement invalidates review, but never parses a payload.
            if not readOnlyKey and state.transaction then
                DropTransaction()
                Feedback(L.transferCanceled)
                addon:RefreshSettingsTransferPage()
            end
            Resize()
        end)
        edit:SetScript("OnCursorChanged", function(_, _, yOffset, _, cursorHeight)
            local top = -yOffset
            local current = scroll:GetVerticalScroll()
            if top < current then scroll:SetVerticalScroll(math.max(0, top))
            elseif top + cursorHeight > current + height then
                scroll:SetVerticalScroll(math.min(scroll:GetVerticalScrollRange(), top + cursorHeight - height))
            end
        end)
        edit:SetScript("OnEscapePressed", function() panel:Hide() end)
        return edit
    end

    ui.Label(body, L.transferHint, 0, -34, width, 36)
    local exportSection = CUI.Section(body, L.transferExport, 0, -80, width, { height = 166 })
    local importSection = CUI.Section(body, L.transferInput, 0, -260, width, { height = 188 })
    local reviewSection = CUI.Section(confirmation, L.transferReview, 0, -36, width, { height = 412 })
    state.sections = { exportSection, importSection, reviewSection }
    for _, section in ipairs(state.sections) do
        section.content:SetWidth(inner)
        addon:RegisterOptionsDragSurface(section)
        addon:RegisterOptionsDragSurface(section.content)
    end
    local exportContent, importContent, reviewContent = exportSection.content, importSection.content, reviewSection.content
    controls.transferScope = ui.Dropdown(panel, exportContent, L.transferScope, 0, 0, {
        { value = "class", label = L.transferClass },
        { value = "all", label = L.transferAll },
    }, nil, function(value)
        if not Ready() then return end
        addon:ClearSettingsTransferPage()
        state.scope = value
        controls.transferScope:SelectValue(value)
        addon:RefreshSettingsTransferPage()
    end)
    controls.transferScope:SetWidth(292)
    if controls.transferScope.label then controls.transferScope.label:SetWidth(292) end
    controls.transferScope:SelectValue("class")
    controls.transferExport = ui.Button(exportContent, L.transferExport, 308, -26, 148, function()
        if not Ready() then return end
        DropTransaction()
        local text, message = addon:ExportSettings(state.scope)
        if not text then Feedback(message or L.invalid, true); return end
        state.exportText = text
        controls.transferOutput:SetText(text)
        controls.transferOutput.scroll:SetVerticalScroll(0)
        controls.transferOutput:SetFocus()
        controls.transferOutput:HighlightText()
        controls.transferSelectAll:Enable()
        Feedback(L.transferCopy)
    end)
    controls.transferSelectAll = ui.Button(exportContent, L.transferSelectAll, 472, -26, 164, function()
        if not Ready() or not state.exportText then return end
        controls.transferOutput:SetFocus()
        controls.transferOutput:HighlightText()
        Feedback(L.transferCopy)
    end)
    Editor(exportContent, "transferOutput", -70, 44, "exportText")
    Editor(importContent, "transferInput", 0, 78)

    local function Prepare(restore)
        if not Ready() then return end
        DropTransaction()
        local transaction, message
        if restore then transaction, message = addon:PrepareSettingsRestore()
        else transaction, message = addon:PrepareSettingsImport(controls.transferInput:GetText()) end
        if not transaction then Feedback(message or L.invalid, true); return end
        state.transaction, state.summaryText = transaction, transaction.summary
        for _, edit in ipairs(state.editors) do edit:ClearFocus() end
        controls.transferScope.menu:Hide()
        controls.transferSummary:SetText(transaction.summary)
        controls.transferSummary.scroll:SetVerticalScroll(0)
        body:Hide()
        confirmation:Show()
        addon:RefreshSettingsTransferPage()
        Feedback(L.transferPending)
    end
    controls.transferImport = ui.Button(importContent, L.transferImport, 0, -96, 308, function() Prepare(false) end)
    controls.transferRestore = ui.Button(importContent, L.transferRestore, 324, -96, 312, function() Prepare(true) end)
    Editor(reviewContent, "transferSummary", 0, 292, "summaryText")
    controls.transferConfirm = ui.Button(reviewContent, L.transferConfirm, 0, -316, 308, function()
        if not Ready() or not state.transaction then return end
        local transaction = state.transaction
        -- Backend owns the private transaction and rechecks combat/context/db.
        -- Clear this UI reference before its synchronous display refresh.
        state.transaction = nil
        local ok, message = addon:ConfirmSettingsImport(transaction)
        addon:ClearSettingsTransferPage()
        addon:RefreshSettingsTransferPage()
        Feedback(ok and (message or L.transferDone) or (message or L.invalid), not ok)
    end)
    controls.transferCancel = ui.Button(reviewContent, L.transferCancel, 324, -316, 312, function()
        if not Ready() then return end
        addon:ClearSettingsTransferPage()
        addon:RefreshSettingsTransferPage()
        Feedback(L.transferCanceled)
    end)
    self:RefreshSettingsTransferPage()
    return state
end
