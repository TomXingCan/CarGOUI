local _, addon = ...

local events = { "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "PLAYER_ENTERING_WORLD", "CVAR_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }
local locations = { LeftRight = { "Left", "Right" }, TopBottom = { "Top", "Bottom" },
    LeftRightOutside = { "LeftOutside", "RightOutside" } }
local OnProcEvent

local function Public(value)
    return issecretvalue and not issecretvalue(value)
end
local function Scale(value)
    return Public(value) and type(value) == "number" and value > 0 and value <= 10
end
local function ID(value)
    return Public(value) and type(value) == "number" and value > 0
        and value < math.huge and value == math.floor(value)
end
local function PublicText(value)
    if not Public(value) then return "restricted" end
    if value == nil then return "nil" end
    if type(value) == "string" then return value:sub(1, 120) end
    if type(value) == "number" and value == value and math.abs(value) < math.huge then
        return tostring(value)
    end
    if type(value) == "boolean" then return value and "true" or "false" end
    return "unavailable"
end

local function Sources(definition)
    return definition.overlaySources or { definition }
end

local function Trace(self, event, id, texture, location, scale, result)
    -- Only public graphical-event arguments and our own decisions are retained.
    -- No UNIT_AURA payload, private native widget or timer text is inspected.
    self.procEventSequence = (self.procEventSequence or 0) + 1
    self.procEventTrace = self.procEventTrace or {}
    if #self.procEventTrace == 16 then table.remove(self.procEventTrace, 1) end
    self.procEventTrace[#self.procEventTrace + 1] = "#" .. self.procEventSequence
        .. " " .. event .. " owner=" .. PublicText(id)
        .. " texture=" .. PublicText(texture) .. " location=" .. PublicText(location)
        .. " scale=" .. PublicText(scale) .. "; " .. result
end
local function CVar(name, boolean)
    local api = C_CVar
    if boolean then
        local fn = api and api.GetCVarBool or GetCVarBool
        local value = fn and fn(name)
        return Public(value) and value == true
    end
    local fn = api and api.GetCVar or GetCVar
    local value = fn and fn(name)
    if not Public(value) then return 0 end
    value = tonumber(value)
    return value and value >= 0 and value <= 1 and value or 0
end

function addon:GetProcDefinitions()
    local adapter = self.activeClassAdapter
    if adapter and adapter.classToken == "MAGE" and adapter.GetProcDefinitions then
        local _, spec = self:GetCurrentModuleIdentity()
        local definitions = adapter:GetProcDefinitions(spec) or {}
        for _, definition in ipairs(definitions) do
            for _, entry in ipairs(definition.regions) do
                entry.kind, entry.class, entry.specID = "proc", definition.class, definition.specID
                entry.overlayID, entry.nativeScale = definition.overlayID, definition.scale
                entry.nativeLocation = entry.location
            end
        end
        return definitions
    end
    return {}
end

function addon:GetProcRegionOverlayState(entry)
    local definition = self.procByRegion and self.procByRegion[entry.id]
    local key = entry.nativeLocation or entry.location
    if not definition then
        local states = self.procOverlayStates and self.procOverlayStates[entry.overlayID]
        return states and states[key]
    end
    local shown, hidden
    for _, source in ipairs(Sources(definition)) do
        local states = self.procOverlayStates and self.procOverlayStates[source.overlayID]
        local state = states and states[key]
        if state then
            if state.shown and (not shown or (state.sequence or 0) > (shown.sequence or 0)) then
                shown = state
            elseif not state.shown then
                hidden = state
            end
        end
    end
    -- A late HIDE for the previous graphical tier cannot close a new tier.
    -- Unseen sibling sources also cannot override an explicit final HIDE.
    return shown or hidden
end

function addon:StopProc()
    self.procTracking = false
    for _, event in ipairs(events) do self:UnregisterEvent(event, OnProcEvent) end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry.kind == "proc" then self:DisableAuraReminder(frame) end
    end
    self.procDefinitions, self.procByOverlay, self.procOverlayStates = nil, nil, nil
    self.procByRegion, self.procOverlaySources, self.procRegionDiagnostics = nil, nil, nil
end

function addon:RenderProcState()
    if not self.procTracking then return end
    local visible = CVar("displaySpellActivationOverlays", true)
    local opacity = CVar("spellActivationOverlayOpacity")
    local keep = {}
    self.procRegionDiagnostics = {}
    self.procStatusReason = "Native aura tracking; Lua does not read aura presence, stacks or time."
    for _, definition in ipairs(self.procDefinitions) do
        for _, entry in ipairs(definition.regions) do
            local state = self:GetProcRegionOverlayState(entry)
            -- Bootstrap regular mapped timer auras in the native container.
            -- Timer and graphical owner IDs need not match. Historical/event-
            -- only records require an actual SHOW.
            local allowed = state and state.shown
            if state == nil then allowed = not definition.nativeEventOnly end
            local gate = state and (state.shown and "public SHOW" or "public HIDE/suppressed SHOW")
                or (definition.nativeEventOnly and "awaiting public SHOW" or "native aura bootstrap; graphic replay unverified")
            local preview = self.previewState
            local suppressed = preview and preview.mode ~= "off"
                and (preview.mode == "all" or preview.entryId == entry.id)
            local frame, reason = self:AcquireAuraReminder(entry, definition.auraID)
            if frame then
                keep[entry.id] = true
                -- Native presence/consumption remains entirely inside the slot.
                -- This alpha gates only public overlay lifecycle/preferences.
                if not frame.procGeometryReady then self.procStatusReason = frame.procGeometryReason end
                local enabled = visible and allowed and frame.procGeometryReady
                self.procRegionDiagnostics[entry.id] = gate
                    .. "; display CVar=" .. tostring(visible)
                    .. "; layout=" .. (frame.procGeometryReady and "ready" or (frame.procGeometryReason or "unavailable"))
                    .. "; native slot requested=" .. tostring(not not enabled)
                    .. "; Preview suppresses wrapper=" .. tostring(not not suppressed)
                frame.auraHandle:SetEnabled(not not enabled)
                frame:SetAlpha(enabled and not suppressed and opacity or 0)
                frame:Show()
            else
                self.procStatusReason = reason
                self.procRegionDiagnostics[entry.id] = gate .. "; interface=" .. (reason or "unavailable")
            end
        end
    end
    for id, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry.kind == "proc" and not keep[id] then self:DisableAuraReminder(frame) end
    end
end

function addon:ConfigureProc()
    local definitions = self:GetProcDefinitions()
    local class, spec = self:GetCurrentModuleIdentity()
    local config = #definitions > 0 and self:GetProcConfig() or nil
    local supported, reason = self:CanUseNativeAuraSlots()
    if not config or not config.enabled or not supported then
        self:StopProc()
        self.procStatusReason = not supported and reason or "Proc is disabled or unavailable for this specialization."
        return
    end
    if self.procClass ~= class or self.procSpec ~= spec or not self.procTracking then
        self:StopProc()
        self.procOverlayStates = {}
    end
    self.procClass, self.procSpec, self.procDefinitions = class, spec, definitions
    self.procByOverlay, self.procOverlaySources, self.procByRegion = {}, {}, {}
    for _, definition in ipairs(definitions) do
        for _, source in ipairs(Sources(definition)) do
            self.procByOverlay[source.overlayID] = definition
            self.procOverlaySources[source.overlayID] = source
        end
        for _, entry in ipairs(definition.regions) do self.procByRegion[entry.id] = definition end
    end
    self.procTracking, self.procStatusReason = true, "Native aura tracking; Lua does not read aura presence, stacks or time."
    for _, event in ipairs(events) do self:RegisterEvent(event, OnProcEvent) end
    self:RenderProcState()
end

OnProcEvent = function(self, event, id, texture, locationType, scale)
    if not self.procTracking then return end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        if not ID(id) or not ID(texture) or not Public(locationType) or not Scale(scale) then
            Trace(self, event, id, texture, locationType, scale, "ignored: non-public/invalid event argument")
            return
        end
        local definition = self.procByOverlay[id]
        local source = self.procOverlaySources[id]
        if not definition or not source or texture ~= source.textureID then
            Trace(self, event, id, texture, locationType, scale,
                definition and "ignored: texture mismatch" or "ignored: owner not mapped in current specialization")
            return
        end
        local location
        for name, value in pairs(Enum and Enum.ScreenLocationType or {}) do
            if value == locationType then location = name; break end
        end
        if not location then
            Trace(self, event, id, texture, locationType, scale, "ignored: location enum unavailable")
            return
        end
        Trace(self, event, id, texture, locationType, scale, "accepted: " .. definition.id)
        local shown = locations[location] or { location }
        local state = self.procOverlayStates[id] or {}
        self.procOverlayStates[id] = state
        for _, entry in ipairs(definition.regions) do
            local key = entry.nativeLocation or entry.location
            if not state[key] then state[key] = { shown = false, scale = source.scale or definition.scale } end
        end
        for _, key in ipairs(shown) do
            -- Stock SHOW is ignored when this CVar is off; later enabling it
            -- does not replay that ignored graphic. Preserve that public fact.
            if state[key] then state[key] = { shown = CVar("displaySpellActivationOverlays", true),
                scale = scale, sequence = self.procEventSequence } end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        if not Public(id) or (id ~= nil and not ID(id)) then
            Trace(self, event, id, nil, nil, nil, "ignored: non-public/invalid owner")
            return
        end
        Trace(self, event, id, nil, nil, nil, id == nil and "accepted: hide all graphical owners"
            or (self.procByOverlay[id] and "accepted: hide this graphical owner" or "ignored: owner not mapped in current specialization"))
        for overlayID, definition in pairs(self.procByOverlay) do
            if id == nil or id == overlayID then
                local state = {}
                for _, entry in ipairs(definition.regions) do
                    state[entry.nativeLocation or entry.location] = { shown = false,
                        scale = self.procOverlaySources[overlayID].scale or definition.scale,
                        sequence = self.procEventSequence }
                end
                self.procOverlayStates[overlayID] = state
            end
        end
    elseif event == "CVAR_UPDATE" then
        if not Public(id) or (id ~= "displaySpellActivationOverlays" and id ~= "spellActivationOverlayOpacity") then return end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Native containers resynchronize the real aura provider. No cached
        -- combat timers or cast/stack counts are replayed into the new world.
        self.procOverlayStates = {}
        Trace(self, event, nil, nil, nil, nil, "native aura resync; cleared public graphical gate history")
    end
    self:RenderProcState()
end

function addon:GetProcDiagnostics()
    local definitions, regions, enabled = self.procDefinitions or self:GetProcDefinitions(), 0, 0
    for _, definition in ipairs(definitions) do regions = regions + #definition.regions end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry.kind == "proc" and frame.auraHandle.enabled then enabled = enabled + 1 end
    end
    local version, build, date, interface
    if GetBuildInfo then version, build, date, interface = GetBuildInfo() end
    local details = {
        "Client: version=" .. PublicText(version) .. "; build=" .. PublicText(build)
            .. "; interface=" .. PublicText(interface) .. "; build date=" .. PublicText(date),
        "Proc mapping audit target: 12.1.0.69933; client event receipt does not prove aura exposure.",
    }
    for _, definition in ipairs(definitions) do
        local sources = {}
        for _, source in ipairs(Sources(definition)) do
            sources[#sources + 1] = source.overlayID .. "/texture=" .. source.textureID
        end
        details[#details + 1] = definition.id .. ": timer aura=" .. definition.auraID
            .. "; graphic owners=" .. table.concat(sources, ", ")
        for _, entry in ipairs(definition.regions) do
            details[#details + 1] = "  " .. entry.id .. ": "
                .. (self.procRegionDiagnostics and self.procRegionDiagnostics[entry.id] or "not initialized")
        end
    end
    details[#details + 1] = "Recent public native graphic events (bounded 16; no aura payloads):"
    for _, line in ipairs(self.procEventTrace or {}) do details[#details + 1] = line end
    return "Proc: " .. (self.procTracking and "Native tracking" or "inactive")
        .. "; definitions=" .. #definitions .. "; regions=" .. regions .. "; enabled native slots=" .. enabled
        .. "\n" .. (self.procStatusReason or "Not initialized.")
        .. "\nNative slots own actual presence/duration; enabled slots are not a count of visible auras."
        .. "\n" .. table.concat(details, "\n")
end
