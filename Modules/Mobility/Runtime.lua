local _, addon = ...

local events = { "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_CHARGES",
    "PLAYER_ALIVE", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

local function CancelPending(self)
    if self.mobilityPending then
        self.mobilityPending:Cancel()
        self.mobilityPending = nil
    end
end

function addon:GetMobilityStatus()
    local state = self.mobilityState or { status = "Unknown", reason = "Waiting for initialization.", path = "none" }
    -- Explicit allowlist. Never expose raw charge fields, durations or native text
    -- to diagnostic formatting or ordinary Options code.
    return { status = state.status, reason = state.reason, spellID = state.spellID,
        spellName = state.spellName, path = state.path, entry = state.entry }
end

function addon:RenderMobilityState()
    local state = self.mobilityState
    if not self.mobilityTracking or not self.db.enabled or not state or not state.duration then
        self:HideLiveMobility()
        return
    end
    local preview = self.previewState
    if preview and preview.mode ~= "off" then
        if preview.mode == "all" or preview.entryId == state.entry.id then
            self:HideLiveMobility()
            return
        end
    end
    -- Updating a continuing reminder need not clear/hide its native binding.
    -- Only obsolete/suppressed entries are explicitly torn down.
    self:HideLiveMobility(state.entry.id)
    self:RenderLiveMobility(state.entry, state.spellName, state.duration, state.visibility, state.spellID)
end

function addon:RefreshMobility()
    CancelPending(self)
    if not self.mobilityTracking then return end
    local previous = self.mobilityState
    self.mobilityState = self:ReadMobilityState()
    local state = self.mobilityState
    local identityChanged = not previous or previous.spellID ~= state.spellID
        or previous.entry ~= state.entry
    if identityChanged and self.previewState and self.previewState.mode ~= "off" then
        -- Static sample names follow learning/spec changes; cooldown ticks never
        -- rerender Preview or substitute a sample for the live state.
        self:RefreshPreview()
    else
        self:RenderMobilityState()
    end
    if self.RefreshMobilityOptions then self:RefreshMobilityOptions() end
end

local function OnMobilityEvent(self, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if issecretvalue and issecretvalue(unit) then return end
        if unit and unit ~= "player" then return end
    end
    if not self.mobilityTracking or self.mobilityPending then return end
    -- One cancellable, next-turn task per event burst, never a recurring timer.
    -- All cooldown events read the latest API snapshot together after the burst.
    self.mobilityPending = C_Timer.NewTimer(0, function()
        self.mobilityPending = nil
        if self.mobilityTracking then self:RefreshMobility() end
    end)
end

function addon:ConfigureMobility()
    local entry = self:GetMobilityEntry()
    local enabled = entry and self.db.mobility.enabled and self.db.enabled
    if enabled and (not C_Timer or not C_Timer.NewTimer) then
        enabled = false
        self.mobilityState = { status = "Unsupported", reason = "Event scheduling API is unavailable.", path = "none", entry = entry }
    elseif not enabled then
        self.mobilityState = { status = entry and "Disabled" or "Unsupported", entry = entry, path = "none",
            reason = entry and "Enable Mobility and General > Show reminders to monitor." or "Mage Blink / Shimmer only." }
    end
    if self.mobilityTracking ~= not not enabled then
        self.mobilityTracking = not not enabled
        local method = enabled and self.RegisterEvent or self.UnregisterEvent
        for _, event in ipairs(events) do method(self, event, OnMobilityEvent) end
    end
    if enabled then
        self:RefreshMobility()
    else
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
    local state = self:GetMobilityStatus()
    local version, build, date, interface
    if GetBuildInfo then version, build, date, interface = GetBuildInfo() end
    local _, class = UnitClass("player")
    local entry = self:GetMobilityEntry()
    return table.concat({
        "CarGOUI " .. self.version,
        "Client: " .. Public(version) .. " / build " .. Public(build) .. " / Interface " .. Public(interface),
        "Build date: " .. Public(date),
        "Class: " .. Public(class) .. " / spec: " .. (entry and Public(entry.specID or "unselected") or "unsupported"),
        "Skill: " .. Public(state.spellName) .. " / ID: " .. Public(state.spellID),
        "Status: " .. state.status,
        "Path: " .. state.path,
        "Reason: " .. state.reason,
        "Combat: " .. Public(InCombatLockdown()),
        "Saved position ID: " .. (entry and entry.id or "none"),
        "Charge/timing fields: not logged; restricted fields are never serialized.",
        "Native timing / combat behavior requires validation in this client.",
    }, "\n")
end
