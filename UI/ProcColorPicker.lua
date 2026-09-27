local _, addon = ...

-- This edits an ordinary RGB setting. It never reads native aura children,
-- duration text, aura state or visibility, and it never changes timer alpha.
local function SameRegion(first, second)
    return first and second and first.id == second.id and first.class == second.class
        and first.specID == second.specID and first.kind == "proc" and second.kind == "proc"
end

local function OwnsPicker(session)
    local picker = session and session.picker
    return picker and picker.extraInfo == session
        and picker.swatchFunc == session.swatchFunc and picker.cancelFunc == session.cancelFunc
end

local function PickerAvailable()
    local picker = ColorPickerFrame
    return picker and type(picker.SetupColorPickerAndShow) == "function"
        and type(picker.GetColorRGB) == "function" and type(picker.HookScript) == "function"
        and picker.Footer and picker.Footer.OkayButton
        and type(picker.Footer.OkayButton.HookScript) == "function"
        and type(hooksecurefunc) == "function"
end

function addon:GetSelectedProcColorEntry()
    local panel = self.optionsFrame
    if not panel then return nil end
    for _, entry in ipairs(self:GetDefinedPreviewEntries() or {}) do
        if entry.kind == "proc" and entry.id == panel.selectedProcEntry then return entry end
    end
end

function addon:RefreshProcColorControls()
    local panel = self.optionsFrame
    if not panel or not panel.controls.procColor then return end
    local entry = self:GetSelectedProcColorEntry()
    local session = self.procColorPickerSession
    if session and not SameRegion(session.entry, entry) then self:CancelProcColorPicker() end
    panel.procColorSelection:SetText(entry and self:GetEntryDisplayLabel(entry) or addon:Text("No configurable Proc region"))
    panel.controls.procColor:SetEnabled(entry ~= nil and not not PickerAvailable())
    panel.controls.procColorReset:SetEnabled(entry ~= nil)
    if entry then
        local color = self:ResolveReminderColor(entry)
        panel.controls.procColor.swatch:SetColorTexture(color.r, color.g, color.b, 1)
        panel.procColorMode:SetText(self:GetProcRegionColor(entry) and addon:Text("Custom RGB") or addon:Text("Class default"))
    else
        panel.controls.procColor.swatch:SetColorTexture(0.35, 0.35, 0.35, 1)
        panel.procColorMode:SetText("")
    end
end

local function Finish(session, accepted, hidePicker)
    if addon.procColorPickerSession ~= session then return end
    local owned = OwnsPicker(session)
    addon.procColorPickerSession = nil
    if accepted and owned and session.changed and SameRegion(session.entry, addon:GetSelectedProcColorEntry()) then
        -- Only the native Okay button takes this branch. Live color changes
        -- remain a temporary draft, without touching SavedVariables.
        addon:SetProcRegionColor(session.entry, session.draft)
    end
    addon:SetProcRegionColorPreview(session.entry, nil)
    -- A different addon may already have opened the shared picker. Never
    -- remove its callbacks, change its colors, or hide its window.
    if owned and OwnsPicker(session) then
        local picker = session.picker
        picker.swatchFunc, picker.cancelFunc, picker.extraInfo = nil, nil, nil
        if hidePicker then picker:Hide() end
    end
    addon:RefreshProcColorControls()
end

function addon:CancelProcColorPicker()
    local session = self.procColorPickerSession
    if session then Finish(session, false, true) end
end

local function InstallPickerHooks(picker)
    if addon.procColorPickerHooked == picker then return end
    addon.procColorPickerHooked = picker
    -- Retail's native Okay handler calls swatchFunc and then Hide. PreClick
    -- identifies explicit confirmation before that Hide; generic hiding is
    -- cancellation. These bounded hooks are inert without an owned session.
    picker.Footer.OkayButton:HookScript("PreClick", function()
        local session = addon.procColorPickerSession
        if OwnsPicker(session) then session.accepted = true end
    end)
    picker.Footer.OkayButton:HookScript("OnClick", function()
        local session = addon.procColorPickerSession
        if OwnsPicker(session) then session.accepted = false end
    end)
    picker:HookScript("OnHide", function()
        local session = addon.procColorPickerSession
        if session and session.picker == picker then Finish(session, session.accepted, false) end
    end)
    hooksecurefunc(picker, "SetupColorPickerAndShow", function()
        addon.procColorPickerGeneration = (addon.procColorPickerGeneration or 0) + 1
        local session = addon.procColorPickerSession
        if session and session.picker == picker and not OwnsPicker(session) then
            Finish(session, false, false)
        end
    end)
end

function addon:OpenProcColorPicker(entry)
    if InCombatLockdown() then return false, addon:Text("The color picker is unavailable in combat.") end
    local panel = self.optionsFrame
    if not panel or not panel:IsShown() or not SameRegion(entry, self:GetSelectedProcColorEntry()) then
        return false, addon:Text("Select a Proc region first.")
    end
    if not PickerAvailable() then return false, addon:Text("The native color picker is unavailable.") end
    self:CancelProcColorPicker()
    local picker = ColorPickerFrame
    InstallPickerHooks(picker)
    -- When replacing an existing native picker, honor its own cancellation
    -- before supplying our callbacks. The native API does not do this itself.
    if picker:IsShown() then
        local previousCancel, previousSwatch, previousOwner = picker.cancelFunc, picker.swatchFunc, picker.extraInfo
        local previousGeneration = self.procColorPickerGeneration
        if previousCancel then previousCancel(picker.previousValues) end
        -- A cancellation callback is allowed to open a newer edit. Do not
        -- hide or replace that newer owner while unwinding the older one.
        if self.procColorPickerGeneration ~= previousGeneration or picker.cancelFunc ~= previousCancel
            or picker.swatchFunc ~= previousSwatch or picker.extraInfo ~= previousOwner then
            return false, addon:Text("Another color edit opened. Finish it before editing this Proc region.")
        end
        picker:Hide()
    end
    local color = self:ResolveReminderColor(entry)
    local session = {
        picker = picker,
        entry = { id = entry.id, class = entry.class, specID = entry.specID,
            kind = "proc", label = entry.label },
        draft = { r = color.r, g = color.g, b = color.b },
        original = { r = color.r, g = color.g, b = color.b },
    }
    session.swatchFunc = function()
        if self.procColorPickerSession ~= session or not OwnsPicker(session) then return end
        if not SameRegion(session.entry, self:GetSelectedProcColorEntry()) then
            Finish(session, false, true)
            return
        end
        local r, g, b = picker:GetColorRGB()
        local draft = { r = r, g = g, b = b }
        if self:SetProcRegionColorPreview(session.entry, draft) then
            session.draft = draft
            session.changed = r ~= session.original.r or g ~= session.original.g or b ~= session.original.b
            self:RefreshProcColorControls()
        end
    end
    session.cancelFunc = function()
        if self.procColorPickerSession == session then Finish(session, false, false) end
    end
    self.procColorPickerSession = session
    picker:SetupColorPickerAndShow({
        r = color.r, g = color.g, b = color.b, hasOpacity = false,
        swatchFunc = session.swatchFunc, cancelFunc = session.cancelFunc, extraInfo = session,
    })
    return true
end
