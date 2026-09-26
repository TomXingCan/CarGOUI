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
            elseif channel == "preview" then result.previewFrames = result.previewFrames + 1 end
            if frame.durationBinding then result.allocatedBindings = result.allocatedBindings + 1 end
            -- Our own public lifecycle flag, never alpha/text/secret visibility.
            if frame.mobilityBindingActive then result.activeBindings = result.activeBindings + 1 end
        end
    end
    return result
end

local function SamplePerformance(moduleNames)
    local lines = {}
    -- Invoked only by the existing Copy diagnostics / Refresh snapshot actions.
    -- No periodic sampling, forced GC or profiling-CVar mutation.
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
    local profiling = C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("scriptProfile")
    if issecretvalue and issecretvalue(profiling) then profiling = false end
    if profiling and UpdateAddOnCPUUsage then UpdateAddOnCPUUsage() end
    for _, name in ipairs(moduleNames) do
        local memory = GetAddOnMemoryUsage and GetAddOnMemoryUsage(name)
        lines[#lines + 1] = name .. " memory (runtime KB): " .. Public(memory)
        local cpu = profiling and GetAddOnCPUUsage and GetAddOnCPUUsage(name)
        lines[#lines + 1] = name .. " CPU (cumulative ms): "
            .. (profiling and Public(cpu) or "unavailable (scriptProfile disabled)")
    end
    return table.concat(lines, "\n")
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
        "Subscriptions: native events=" .. events.events .. ", callbacks=" .. events.callbacks,
        "Subscriptions by event: " .. table.concat(eventNames, ", "),
        "Cached frames (may be inactive): live=" .. report.liveFrames .. ", preview=" .. report.previewFrames,
        "Native bindings: allocated=" .. report.allocatedBindings .. ", active=" .. report.activeBindings,
        "Preview: " .. report.previewMode .. "; native alpha is not read back.",
        SamplePerformance(names),
        "CPU/memory are explicit client snapshots, not package-size estimates; compare deltas across the acceptance steps.",
    }, "\n")
end
