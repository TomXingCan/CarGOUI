local _, addon = ...

local identityEvents = { "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }
local runtimeEvents = { "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES", "PLAYER_ALIVE", "PLAYER_DEAD",
    "PLAYER_UNGHOST", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local formEvents = { "UPDATE_SHAPESHIFT_FORM" }
local identitySet = {}
for _, event in ipairs(identityEvents) do identitySet[event] = true end
identitySet.UPDATE_SHAPESHIFT_FORM = true
local OnMobilityEvent

local function CancelPending(self)
    if self.mobilityPending then self.mobilityPending:Cancel(); self.mobilityPending = nil end
end

local function Snapshot(state)
    -- Explicit allowlist: no raw charges, native opacity, durations or text.
    return { status = state.status, reason = state.reason, spellID = state.spellID,
        spellName = state.spellName, path = state.path, entry = state.entry }
end

function addon:GetMobilityStatus(id)
    if id then
        for _, state in ipairs(self.mobilityStates or {}) do
            if state.entry and state.entry.id == id then return Snapshot(state) end
        end
    end
    return Snapshot(self.mobilityState or { status = "Unknown", reason = "Waiting for initialization.", path = "none" })
end

function addon:GetMobilityStatuses()
    local result = {}
    for _, state in ipairs(self.mobilityStates or {}) do result[#result + 1] = Snapshot(state) end
    return result
end

local function Watch(self, field, events, enabled)
    if self[field] == enabled then return end
    self[field] = enabled
    local method = enabled and self.RegisterEvent or self.UnregisterEvent
    for _, event in ipairs(events) do method(self, event, OnMobilityEvent) end
end

local function NeedsCooldownEvents(self)
    local adapter = self.activeClassAdapter
    if adapter and adapter.NeedsMobilityEvents then return adapter:NeedsMobilityEvents() end
    return #self:GetMobilityEntries() > 0
end

function addon:RenderMobilityState()
    if not self.mobilityTracking or not self:GetMobilityConfig().enabled then self:HideLiveMobility(); return end
    local keep, render = {}, {}
    local preview = self.previewState
    for _, state in ipairs(self.mobilityStates or {}) do
        if state.entry and state.duration then
            local suppressed = preview and preview.mode ~= "off"
                and (preview.mode == "all" or preview.entryId == state.entry.id)
            if not suppressed then keep[state.entry.id] = true; render[#render + 1] = state end
        end
    end
    -- Prune obsolete/suppressed entries once; one skill cannot clear another.
    self:HideLiveMobility(keep)
    for _, state in ipairs(render) do
        self:RenderLiveMobility(state.entry, state.spellName, state.duration, state.visibility, state.spellID)
    end
end

local function SameIdentities(previous, current)
    if not previous or #previous ~= #current then return false end
    for i, state in ipairs(current) do
        local old = previous[i]
        if old.spellID ~= state.spellID or old.entry ~= state.entry then return false end
    end
    return true
end

function addon:RefreshMobility()
    CancelPending(self)
    if not self.mobilityTracking then return end
    local rosterChanged = false
    if self.mobilityRosterDirty then
        self.mobilityRosterDirty = false
        rosterChanged = self:RefreshActiveEntries(true)
    end
    Watch(self, "mobilityFormWatching", formEvents, self.activeAdapterClass == "DRUID")
    local previous = self.mobilityStates
    self.mobilityStates = self:ReadMobilityStates()
    Watch(self, "mobilityCooldownWatching", runtimeEvents, NeedsCooldownEvents(self))
    self.mobilityState = self.mobilityStates[1] or { status = "Not learned", path = "none",
        reason = "No supported Mobility skill is currently learned for this specialization." }
    local identitiesChanged = not SameIdentities(previous, self.mobilityStates)
    if identitiesChanged and self.previewState and self.previewState.mode ~= "off" then
        self:RefreshPreview()
    else self:RenderMobilityState() end
    -- Learning changes rebuild choices; cooldown bursts only refresh status.
    if (rosterChanged or identitiesChanged) and self.RefreshOptions then self:RefreshOptions()
    elseif self.RefreshMobilityOptions then self:RefreshMobilityOptions() end
end

OnMobilityEvent = function(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if issecretvalue and issecretvalue(unit) then return end
        if unit and unit ~= "player" then return end
    end
    if not self.mobilityTracking then return end
    if identitySet[event] then self.mobilityRosterDirty = true end
    if self.mobilityPending then return end
    -- One cancellable next-turn task per event burst; never periodic.
    self.mobilityPending = C_Timer.NewTimer(0, function()
        self.mobilityPending = nil
        if self.mobilityTracking then self:RefreshMobility() end
    end)
end

function addon:ConfigureMobility()
    local entry = self:GetMobilityEntry()
    local enabled = self.activeClassAdapter ~= nil and self:GetMobilityConfig().enabled
    if enabled and (not C_Timer or not C_Timer.NewTimer) then
        enabled = false
        self.mobilityState = { status = "Unsupported", reason = "Event scheduling API is unavailable.", path = "none", entry = entry }
    elseif not enabled then
        self.mobilityState = { status = self.activeClassAdapter and "Disabled" or "Unsupported", entry = entry, path = "none",
            reason = self.activeClassAdapter and "Enable Mobility for the current class to monitor."
                or self.classModuleReason or "No current class Mobility adapter is available." }
    end
    if enabled and not self.mobilityTracking then self.mobilityRosterDirty = true end
    self.mobilityTracking = not not enabled
    -- No learned skills: retain learning events, no cooldown queries/bindings.
    Watch(self, "mobilityIdentityWatching", identityEvents, not not enabled)
    Watch(self, "mobilityFormWatching", formEvents, not not enabled and self.activeAdapterClass == "DRUID")
    Watch(self, "mobilityCooldownWatching", runtimeEvents, not not enabled and NeedsCooldownEvents(self))
    if enabled then self:RefreshMobility()
    else
        self.mobilityStates = { self.mobilityState }
        CancelPending(self)
        self:HideLiveMobility()
        if self.RefreshMobilityOptions then self:RefreshMobilityOptions() end
    end
end

local function Public(value)
    if issecretvalue and issecretvalue(value) then return "restricted" end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" then return tostring(value) end
    return "unknown"
end

function addon:GetMobilityDiagnostics()
    local version, build, date, interface
    if GetBuildInfo then version, build, date, interface = GetBuildInfo() end
    local class, spec = self:GetPlayerContext()
    local lines = { "CarGOUI " .. self.version,
        "Client: " .. Public(version) .. " / build " .. Public(build) .. " / Interface " .. Public(interface),
        "Build date: " .. Public(date), "Class: " .. Public(class) .. " / spec: " .. Public(spec or "unselected"),
        "Combat: " .. Public(InCombatLockdown()), "Active skill entries: " .. #self:GetMobilityEntries() }
    local states = self:GetMobilityStatuses()
    if #states == 0 then states[1] = self:GetMobilityStatus() end
    for _, state in ipairs(states) do
        lines[#lines + 1] = "Skill: " .. Public(state.spellName) .. " / ID: " .. Public(state.spellID)
        lines[#lines + 1] = "Status: " .. state.status .. " / Path: " .. state.path
        lines[#lines + 1] = "Reason: " .. (state.reason or "")
        lines[#lines + 1] = "Saved position ID: " .. (state.entry and state.entry.id or "none")
    end
    lines[#lines + 1] = "Charge/timing fields: not logged; restricted fields are never serialized."
    lines[#lines + 1] = "Native timing / combat behavior requires validation in this client."
    lines[#lines + 1] = self.GetLoadDiagnosticsText and self:GetLoadDiagnosticsText() or "Loading diagnostics unavailable."
    return table.concat(lines, "\n")
end
