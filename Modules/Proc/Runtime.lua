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

function addon:StopProc()
    self.procTracking = false
    for _, event in ipairs(events) do self:UnregisterEvent(event, OnProcEvent) end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry.kind == "proc" then self:DisableAuraReminder(frame) end
    end
    self.procDefinitions, self.procByOverlay, self.procOverlayStates = nil, nil, nil
end

function addon:RenderProcState()
    if not self.procTracking then return end
    local visible = CVar("displaySpellActivationOverlays", true)
    local opacity = CVar("spellActivationOverlayOpacity")
    local keep = {}
    self.procStatusReason = "Native aura tracking; Lua does not read aura presence, stacks or time."
    for _, definition in ipairs(self.procDefinitions) do
        local observed = self.procOverlayStates[definition.overlayID]
        for _, entry in ipairs(definition.regions) do
            local state = observed and observed[entry.nativeLocation or entry.location]
            -- Bootstrap regular exact-aura graphical records in the native
            -- container. Historical/event-only records require an actual SHOW.
            local allowed = state and state.shown
            if state == nil then allowed = not definition.nativeEventOnly end
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
                frame.auraHandle:SetEnabled(not not enabled)
                frame:SetAlpha(enabled and not suppressed and opacity or 0)
                frame:Show()
            else self.procStatusReason = reason end
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
    self.procByOverlay = {}
    for _, definition in ipairs(definitions) do self.procByOverlay[definition.overlayID] = definition end
    self.procTracking, self.procStatusReason = true, "Native aura tracking; Lua does not read aura presence, stacks or time."
    for _, event in ipairs(events) do self:RegisterEvent(event, OnProcEvent) end
    self:RenderProcState()
end

OnProcEvent = function(self, event, id, texture, locationType, scale)
    if not self.procTracking then return end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
        if not Public(id) or not Public(texture) or not Public(locationType) or not Scale(scale) then return end
        local definition = self.procByOverlay[id]
        if not definition or texture ~= definition.textureID then return end
        local location
        for name, value in pairs(Enum and Enum.ScreenLocationType or {}) do
            if value == locationType then location = name; break end
        end
        if not location then return end
        local shown = locations[location] or { location }
        local state = self.procOverlayStates[id] or {}
        self.procOverlayStates[id] = state
        for _, entry in ipairs(definition.regions) do
            local key = entry.nativeLocation or entry.location
            if not state[key] then state[key] = { shown = false, scale = definition.scale } end
        end
        for _, key in ipairs(shown) do
            -- Stock SHOW is ignored when this CVar is off; later enabling it
            -- does not replay that ignored graphic. Preserve that public fact.
            if state[key] then state[key] = { shown = CVar("displaySpellActivationOverlays", true), scale = scale } end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        if not Public(id) then return end
        for overlayID, definition in pairs(self.procByOverlay) do
            if id == nil or id == overlayID then
                local state = {}
                for _, entry in ipairs(definition.regions) do
                    state[entry.nativeLocation or entry.location] = { shown = false, scale = definition.scale }
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
    end
    self:RenderProcState()
end

function addon:GetProcDiagnostics()
    local definitions, regions, enabled = self.procDefinitions or {}, 0, 0
    for _, definition in ipairs(definitions) do regions = regions + #definition.regions end
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry.kind == "proc" and frame.auraHandle.enabled then enabled = enabled + 1 end
    end
    return "Proc: " .. (self.procTracking and "Native tracking" or "inactive")
        .. "; definitions=" .. #definitions .. "; regions=" .. regions .. "; enabled native slots=" .. enabled
        .. "\n" .. (self.procStatusReason or "Not initialized.")
        .. "\nNative slots own actual presence/duration; enabled slots are not a count of visible auras."
end
