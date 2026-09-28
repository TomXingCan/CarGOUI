local _, addon = ...

local function Public(value)
    if issecretvalue and issecretvalue(value) then return "restricted" end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return tostring(value) end
    return "unavailable"
end

function addon:GetRuntimeLoadDiagnostics()
    local result = { modules = self:GetModuleLoadReport(), events = self:GetEventDiagnostics(),
        liveFrames = 0, previewFrames = 0, allocatedBindings = 0, activeBindings = 0,
        activeSkills = 0, unavailableSkills = 0,
        nativeAuraFrames = 0, nativeAuraSlots = 0, nativeAuraEnabledSlots = 0,
        nativeAuraDurationSlots = 0, nativeAuraTextSlots = 0,
        nativeAuraTemplateBindings = self.nativeAuraDurationTemplate and 1 or 0,
        pendingTasks = self.mobilityPending and 1 or 0,
        previewMode = self.previewState and self.previewState.mode or "off" }
    for _, state in ipairs(self.mobilityStates or {}) do
        if self.mobilityTracking and state.entry and state.spellID then
            if state.status == "Restricted" or state.status == "Unsupported" or state.status == "Unknown" then
                result.unavailableSkills = result.unavailableSkills + 1
            else result.activeSkills = result.activeSkills + 1 end
        end
    end
    for channel, pool in pairs(self.reminderFrames or {}) do
        for _, frame in pairs(pool) do
            if channel == "live" then result.liveFrames = result.liveFrames + 1
            elseif channel == "preview" then result.previewFrames = result.previewFrames + 1
            elseif channel == "nativeAura" then result.nativeAuraFrames = result.nativeAuraFrames + 1 end
            if frame.durationBinding then result.allocatedBindings = result.allocatedBindings + 1 end
            -- Our own public lifecycle flag, never alpha/text/secret visibility.
            if frame.mobilityBindingActive then result.activeBindings = result.activeBindings + 1 end
        end
    end
    for _, handle in pairs(self.nativeAuraSlots or {}) do
        result.nativeAuraSlots = result.nativeAuraSlots + 1
        if handle.enabled then result.nativeAuraEnabledSlots = result.nativeAuraEnabledSlots + 1 end
        if handle.textOnly then result.nativeAuraTextSlots = result.nativeAuraTextSlots + 1
        else result.nativeAuraDurationSlots = result.nativeAuraDurationSlots + 1 end
    end
    return result
end

local function SampleCall(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, value = pcall(callback, ...)
    if ok then return value end
end

local function SamplePerformance(moduleNames)
    local lines = {}
    -- Invoked only by explicit slash snapshots or Copy / Refresh actions.
    -- No periodic sampling, forced GC or profiling-CVar mutation.
    SampleCall(UpdateAddOnMemoryUsage)
    local profiling = C_CVar and SampleCall(C_CVar.GetCVarBool, "scriptProfile")
    if issecretvalue and issecretvalue(profiling) then profiling = false end
    if profiling then SampleCall(UpdateAddOnCPUUsage) end
    for _, name in ipairs(moduleNames) do
        local memory = SampleCall(GetAddOnMemoryUsage, name)
        lines[#lines + 1] = name .. " memory (runtime KB): " .. Public(memory)
        local cpu = profiling and SampleCall(GetAddOnCPUUsage, name)
        lines[#lines + 1] = name .. " CPU (cumulative ms): "
            .. (profiling and Public(cpu) or "unavailable (scriptProfile disabled)")
    end
    return table.concat(lines, "\n")
end

local function DiagnosticText(self, callback, fallback)
    if type(callback) ~= "function" then return fallback end
    local ok, text = pcall(callback, self)
    if ok and not (issecretvalue and issecretvalue(text)) and type(text) == "string" then return text end
    return fallback
end

function addon:GetLoadDiagnosticsText()
    local report = self:GetRuntimeLoadDiagnostics()
    local modules, events = report.modules, report.events
    local names = { self.name }
    if modules.dataPackageLoaded then names[#names + 1] = "CarGOUI_Data" end
    if modules.retiredMageLoaded then names[#names + 1] = "CarGOUI_Mage" end
    local eventNames = {}
    for event, count in pairs(events.perEvent) do eventNames[#eventNames + 1] = event .. "=" .. count end
    table.sort(eventNames)
    return table.concat({
        "Files: CarGOUI loaded; CarGOUI_Data " .. modules.fileStatus,
        "Loaded Data package TOC inventory: code files=" .. modules.loadedDataFiles .. "; class-definition files=" .. modules.loadedClassFiles,
        "Registered adapter definitions=" .. modules.registeredAdapters
            .. "; selected adapter=" .. Public(modules.activeAdapterClass),
        "Retired CarGOUI_Mage: " .. ((modules.retiredMageLoaded or modules.retiredMageRegistered)
            and "present/loaded; isolated legacy namespace, not selected. Remove the old AddOns program directory."
            or "not loaded (this does not assert its directory is absent)"),
        "Module load note: " .. (modules.reason or "none"),
        "Current class/spec: " .. Public(modules.currentClass) .. "/" .. Public(modules.currentSpec),
        "Instantiated active data: Mobility=" .. modules.mobilityEntries .. ", Preview=" .. modules.previewEntries,
        "Loading boundary: every file listed in CarGOUI_Data.toc loads together; class subdirectories are not independent LoD addons.",
        "Configuration loaded: " .. modules.configuration,
        "Configuration access: only current class Mobility / requested current spec Proc is normalized; legacy backup remains loaded.",
        "Runtime: active skills=" .. report.activeSkills .. ", unavailable selected skills=" .. report.unavailableSkills
            .. ", pending event tasks=" .. report.pendingTasks,
        "Core subscriptions: events=" .. events.events .. ", callbacks=" .. events.callbacks,
        "Subscriptions by event: " .. table.concat(eventNames, ", "),
        "Cached frames (may be inactive): live=" .. report.liveFrames .. ", preview=" .. report.previewFrames,
        "Mobility native bindings: allocated=" .. report.allocatedBindings .. ", active=" .. report.activeBindings,
        "Aura wrappers=" .. report.nativeAuraFrames .. "; native slots allocated=" .. report.nativeAuraSlots
            .. "; requested enabled slots=" .. report.nativeAuraEnabledSlots .. " (not visible aura count)",
        "Aura presentation: duration slots=" .. report.nativeAuraDurationSlots
            .. "; static-text slots=" .. report.nativeAuraTextSlots
            .. "; addon binding templates=" .. report.nativeAuraTemplateBindings,
        "Aura bindings: copied bindings and their active state are native-private and are not introspected.",
        "Native aura lifecycle: enabled/disabled are addon requests; completion of the native dirty pass is unobservable.",
        "Native template listener ownership is separate from core callbacks; actual native registration state is unobservable.",
        DiagnosticText(self, self.GetProcDiagnostics, "Proc detail: unavailable (snapshot failed or not initialized)."),
        DiagnosticText(self, self.GetFreeMoveDiagnostics, "Free move detail: unavailable (snapshot failed or not initialized)."),
        DiagnosticText(self, self.GetProcDiagnosticText, "Proc allocation baseline: not initialized."),
        "Preview: " .. report.previewMode .. "; native alpha is not read back.",
        SamplePerformance(names),
        "CPU/memory are explicit client snapshots, not package-size estimates; compare deltas across the acceptance steps.",
    }, "\n")
end

function addon:GetDiagnosticsSnapshotText()
    -- The same producer serves the existing Mobility Copy diagnostics dialog
    -- and the independent slash entry. Opening Options is never a prerequisite.
    return DiagnosticText(self, self.GetMobilityDiagnostics,
        "CarGOUI diagnostic snapshot unavailable.")
end

function addon:PrintDiagnosticsSnapshot()
    local snapshot = self:GetDiagnosticsSnapshotText()
    for line in snapshot:gmatch("[^\n]+") do self:Print(line) end
    return snapshot
end

function addon:ShowDiagnosticsSnapshot()
    local dialog = self.diagnosticsSnapshotFrame
    if not dialog then
        local C = self.CUI
        if not C then return self:PrintDiagnosticsSnapshot() end
        dialog = CreateFrame("Frame", "CarGOUIDiagnosticsSnapshotFrame", UIParent)
        dialog:Hide(); dialog:SetSize(720, 520); dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        dialog:SetFrameStrata("DIALOG"); dialog:SetClampedToScreen(true); dialog:EnableMouse(true)
        dialog.editBoxes, dialog.dropdowns, dialog.cuiPanel = {}, {}, dialog
        self.DesignSystem.Skin(dialog, "dialog")
        C.Label(dialog, self.L.mobilityDiagnostics, 20, -16, 680, 24, "GameFontNormalLarge")
        C.Label(dialog, self.L.diagnosticsHint, 20, -50, 680, 40)
        local scroll = C.ScrollFrame(dialog, dialog, 20, -100, 668, 350)
        local edit = C.EditBox(dialog, scroll, 0, 0, 650)
        edit:SetMultiLine(true); edit:SetMaxLetters(0)
        if edit.SetMaxBytes then edit:SetMaxBytes(0) end
        edit:SetHeight(350); edit:SetJustifyH("LEFT"); edit:SetJustifyV("TOP")
        scroll:SetScrollChild(edit)
        dialog.editBox, dialog.scroll = edit, scroll
        edit:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(dialog.snapshot or ""); self:HighlightText() end
        end)
        local function Refresh()
            dialog.snapshot = addon:GetDiagnosticsSnapshotText()
            local lines = 0
            for line in dialog.snapshot:gmatch("[^\n]+") do lines = lines + math.max(1, math.ceil(#line / 60)) end
            edit:SetHeight(math.max(350, (lines + 1) * 20)); edit:SetText(dialog.snapshot)
            scroll:SetVerticalScroll(0); scroll:RefreshRange()
            edit:SetFocus(); edit:HighlightText()
        end
        dialog.refresh = C.Button(dialog, self.L.diagnosticsRefresh, 20, -470, 180, Refresh)
        dialog.selectAll = C.Button(dialog, self.L.diagnosticsSelect, 220, -470, 180,
            function() edit:SetFocus(); edit:HighlightText() end)
        dialog.close = C.Button(dialog, self.L.close, 580, -470, 120, function() dialog:Hide() end, "ghost")
        dialog.RefreshSnapshot = Refresh
        dialog:HookScript("OnHide", function() edit:ClearFocus(); C.StopMotion(dialog) end)
        UISpecialFrames[#UISpecialFrames + 1] = "CarGOUIDiagnosticsSnapshotFrame"
        self.diagnosticsSnapshotFrame = dialog
    end
    dialog:Show(); dialog.RefreshSnapshot()
    return dialog
end
