local _, addon = ...

local events = { "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "PLAYER_ENTERING_WORLD", "CVAR_UPDATE", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }
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
    return definition.nativeSources or definition.overlaySources or { definition }
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
    if adapter and adapter.procCapability and adapter.procCapability.version == 1
        and type(adapter.GetProcDefinitions) == "function" then
        local class, spec = self:GetCurrentModuleIdentity()
        if class ~= adapter.classToken then return {} end
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
        local matches = not source.regions
        for _, region in ipairs(source.regions or {}) do if region.id == entry.id then matches = true; break end end
        local states = matches and self.procOverlayStates and self.procOverlayStates[source.stateKey or source.overlayID]
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

function addon:GetProcRetryBlocker()
    local pool = self.reminderFrames and self.reminderFrames.nativeAura or {}
    for key, kind in pairs(self.nativeAuraWrapperAttempts or {}) do
        if kind == "proc" and not pool[key] then return "reload-required" end
    end
    for _, name in ipairs({ "GetProcNativeRetryBlocker", "GetProcArtworkRetryBlocker",
        "GetProcPreviewRetryBlocker" }) do
        if self[name] then
            local reason = self[name](self)
            if reason then return reason end
        end
    end
end

function addon:StopProc()
    self:ProcDiagnosticCount("stopCalls")
    if self.procStopping then return false, "proc-cleanup-in-progress" end
    local notifyStopped = self.procTracking and self:IsProcIndependentPolicy()
    self.procStopping, self.procTracking = true, false
    self:InvalidateProcSafetyGeneration()
    local clean = true
    local function Attempt(callback, ...)
        local ok, result = pcall(callback, ...)
        if not ok or result == false then clean = false end
    end
    -- Clear our business subscriptions before any native cleanup can reenter.
    for _, event in ipairs(events) do Attempt(self.UnregisterEvent, self, event, OnProcEvent) end
    if self.StopProcArtwork then Attempt(self.StopProcArtwork, self) end
    if self.StopProcPreview then Attempt(self.StopProcPreview, self) end
    -- Partially constructed handles are registered before allocation. Never
    -- discard an owner merely because a public disable/restore call failed.
    for _, handle in pairs(self.nativeAuraSlots or {}) do
        if handle.procOwned then Attempt(handle.SetEnabled, handle, false) end
    end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry and frame.reminderEntry.kind == "proc" then
            Attempt(frame.SetAlpha, frame, 0)
            Attempt(frame.Show, frame)
        end
    end
    self.procDefinitions, self.procByOverlay, self.procOverlayStates = nil, nil, nil
    self.procByRegion, self.procOverlaySources, self.procRegionDiagnostics = nil, nil, nil
    if notifyStopped then Attempt(self.NotifyProcIndependentArtwork, self, "stopped") end
    self.procStopping = nil
    if not clean then self:RecordProcFailure("stop") end
    return clean, not clean and "proc-cleanup-incomplete" or nil
end

local function RenderProcState(self, changedDefinitions)
    if self:IsProcQuarantined() or not self.procTracking then return end
    local independent = self:IsProcIndependentPolicy()
    local visible = independent or CVar("displaySpellActivationOverlays", true)
    local opacity = independent and 1 or CVar("spellActivationOverlayOpacity")
    local keep = {}
    self.procRegionDiagnostics = self.procRegionDiagnostics or {}
    self.procStatusReason = "Native aura tracking; Lua does not read aura presence, stacks or time."
    for _, definition in ipairs(changedDefinitions or self.procDefinitions) do
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
                    .. (independent and "; independent timer gate" or "; display CVar=" .. tostring(visible))
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
    if not changedDefinitions then
        for id, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
            if frame.reminderEntry.kind == "proc" and not keep[id] then self:DisableAuraReminder(frame) end
        end
    end
    if self.RenderProcArtwork then self:RenderProcArtwork() end
end

function addon:RenderProcState(changedDefinitions)
    return self:RunProcSafe("render", RenderProcState, self, changedDefinitions)
end

local function ConfigureProc(self)
    local definitions = self:GetProcDefinitions()
    local class, spec = self:GetCurrentModuleIdentity()
    self:SetProcDiagnosticState("currentClass", class or "unavailable")
    self:SetProcDiagnosticState("currentSpec", spec or "unavailable")
    local config = #definitions > 0 and self:GetProcConfig() or nil
    local supported, reason = self:CanUseNativeAuraSlots()
    if not config or not config.enabled or not supported then
        self:StopProc()
        self.procStatusReason = not supported and reason or "Proc is disabled or unavailable for this specialization."
        return
    end
    local policy = self:GetProcPresentationPolicy(config)
    if (self.procPresentationPolicy or "replacement") ~= policy then
        local clean, problem = self:PrepareProcPresentationTransition(policy, true)
        if not clean then self.procStatusReason = problem; return false end
        self.procPresentationPolicy = policy
    else self.procPresentationPolicy = policy end
    if self.procClass ~= class or self.procSpec ~= spec or not self.procTracking then
        local clean = self:StopProc()
        if not clean then return false end
        self.procOverlayStates = {}
    end
    if self.procDefinitions ~= definitions then
        if self.StopProcArtwork and not self:StopProcArtwork() then
            self:RecordProcFailure("configure"); return false
        end
        local compiled, conflict = self:CompileProcDefinitions(definitions, class, spec)
        if not compiled then
            self:StopProc(); self.procStatusReason = conflict
            self:RecordProcFailure("configure"); return false
        end
        self.procByOverlay, self.procByRegion = compiled.byOverlay, compiled.byRegion
    end
    self.procClass, self.procSpec, self.procDefinitions = class, spec, definitions
    self.procTracking, self.procStatusReason = true, "Native aura tracking; Lua does not read aura presence, stacks or time."
    if not self:IsProcIndependentPolicy() and self.InstallProcArtworkHooks then self:InstallProcArtworkHooks() end
    if self:IsProcQuarantined() then return false end
    for _, event in ipairs(events) do self:RegisterEvent(event, OnProcEvent) end
    self:RenderProcState()
end

function addon:ConfigureProc()
    self:ProcDiagnosticCount("configureCalls")
    if self:IsProcQuarantined() then return false, "proc-quarantined" end
    return self:RunProcSafe("configure", ConfigureProc, self)
end

local function DispatchProcEvent(self, event, id, texture, locationType, scale, r, g, b)
    if self:IsProcQuarantined() or not self.procTracking then return end
    local changed, seen = {}, {}
    local function Changed(definition)
        if not seen[definition.id] then changed[#changed + 1] = definition; seen[definition.id] = true end
    end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        self:ProcDiagnosticCount("showEvents")
        if not ID(id) or not ID(texture) or not Public(locationType) or not Scale(scale) then
            Trace(self, event, id, texture, locationType, scale, "ignored: non-public/invalid event argument")
            return
        end
        local bindings = self.procByOverlay[id]
        if not bindings then
            Trace(self, event, id, texture, locationType, scale,
                "ignored: owner not mapped in current specialization")
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
        for _, binding in ipairs(bindings) do
            local definition, source = binding.definition, binding.source
            if source.textureID == texture and source.locationTypeName == location then
                Trace(self, event, id, texture, locationType, scale, "accepted: " .. definition.id)
                local state = self.procOverlayStates[source.stateKey] or {}
                self.procOverlayStates[source.stateKey] = state
                for _, entry in ipairs(source.regions) do
                    local key = entry.nativeLocation or entry.location
                    -- Replacement follows stock preferences. Independent
                    -- presentation records the validated public event itself.
                    state[key] = { shown = self:IsProcIndependentPolicy() or CVar("displaySpellActivationOverlays", true),
                        scale = scale, sequence = self.procEventSequence,
                        ownerID = id, textureID = texture, sourceKey = source.stateKey,
                        color = self.ProcPublicColor and self:ProcPublicColor(r, g, b) }
                end
                Changed(definition)
            end
        end
        if #changed == 0 then Trace(self, event, id, texture, locationType, scale, "ignored: texture/location mismatch"); return end
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        self:ProcDiagnosticCount("hideEvents")
        if not Public(id) or (id ~= nil and not ID(id)) then
            Trace(self, event, id, nil, nil, nil, "ignored: non-public/invalid owner")
            return
        end
        Trace(self, event, id, nil, nil, nil, id == nil and "accepted: hide all graphical owners"
            or (self.procByOverlay[id] and "accepted: hide this graphical owner" or "ignored: owner not mapped in current specialization"))
        if id ~= nil and not self.procByOverlay[id] then return end
        local function HideBindings(bindings)
            for _, binding in ipairs(bindings) do
                local source = binding.source
                local state = self.procOverlayStates[source.stateKey] or {}
                for _, entry in ipairs(source.regions) do
                    state[entry.nativeLocation or entry.location] = { shown = false, scale = source.scale,
                        sequence = self.procEventSequence }
                end
                self.procOverlayStates[source.stateKey] = state
                Changed(binding.definition)
            end
        end
        if id then HideBindings(self.procByOverlay[id])
        else for _, bindings in pairs(self.procByOverlay) do HideBindings(bindings) end end
    elseif event == "CVAR_UPDATE" then
        if not Public(id) or (id ~= "displaySpellActivationOverlays" and id ~= "spellActivationOverlayOpacity") then return end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Native containers resynchronize the real aura provider. No cached
        -- combat timers or cast/stack counts are replayed into the new world.
        if self.StopProcArtwork then self:StopProcArtwork() end
        self.procOverlayStates = {}
        Trace(self, event, nil, nil, nil, nil, "native aura resync; cleared public graphical gate history")
    end
    self:RenderProcState(#changed > 0 and changed or nil)
end

OnProcEvent = function(self, ...)
    if self:IsProcQuarantined() or not self.procTracking then return end
    return self:RunProcSafe("event", DispatchProcEvent, self, ...)
end

-- Lightweight catalog invalidation is independent of Mobility and active
-- Proc business listeners. Empty/disabled specs need it to discover a newly
-- learned eligible talent without starting an aura monitor or cooldown query.
local function RefreshProcCatalog(self)
    if not self.initialized then return end
    local adapter = self.activeClassAdapter
    if not adapter or not adapter.procCapability then return end
    if adapter.InvalidateProcDefinitions then adapter:InvalidateProcDefinitions() end
    if adapter.RebuildPreviewEntries then
        adapter:RebuildPreviewEntries()
        self.previewEntries = adapter.previewEntries
    end
    self:ConfigureProc()
    if self.RefreshPreview then self:RefreshPreview() end
    if self.RefreshOptions then self:RefreshOptions() end
end
local function OnProcCatalogChanged(self)
    if self:IsProcQuarantined() then return end
    return self:RunProcSafe("catalog", RefreshProcCatalog, self)
end
for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
    addon:RegisterEvent(event, OnProcCatalogChanged)
end

function addon:GetProcDiagnostics()
    local definitions, regions, enabled = self.procDefinitions or self:GetProcDefinitions(), 0, 0
    for _, definition in ipairs(definitions) do regions = regions + #definition.regions end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry and frame.reminderEntry.kind == "proc"
            and frame.auraHandle and frame.auraHandle.requestedEnabled then enabled = enabled + 1 end
    end
    local version, build, date, interface
    if GetBuildInfo then version, build, date, interface = GetBuildInfo() end
    local details = {
        "Client: version=" .. PublicText(version) .. "; build=" .. PublicText(build)
            .. "; interface=" .. PublicText(interface) .. "; build date=" .. PublicText(date),
        "Proc mapping audit target: 12.1.0.69933; client event receipt does not prove aura exposure.",
        "Proc presentation: saved=" .. self:GetProcPresentationPolicy()
            .. "; active=" .. (self.procPresentationPolicy or "replacement")
            .. "; Blizzard settings are never changed by CarGOUI.",
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
            if self.GetProcArtworkDiagnostic then
                details[#details + 1] = "    presentation: " .. self:GetProcArtworkDiagnostic(entry)
            end
        end
    end
    details[#details + 1] = "Recent public native graphic events (bounded 16; no aura payloads):"
    for _, line in ipairs(self.procEventTrace or {}) do details[#details + 1] = line end
    return "Proc: " .. (self.procTracking and "Native tracking" or "inactive")
        .. "; definitions=" .. #definitions .. "; regions=" .. regions .. "; requested native slots=" .. enabled
        .. "\n" .. (self.procStatusReason or "Not initialized.")
        .. "\nNative slots own actual presence/duration; enabled slots are not a count of visible auras."
        .. "\n" .. table.concat(details, "\n")
end
