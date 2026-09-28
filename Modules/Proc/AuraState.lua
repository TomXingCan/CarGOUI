local _, addon = ...

-- Native matching and duration ownership stay inside Blizzard's secure code.
-- Public registries record construction intent, never observed Aura presence.
function addon:CanUseNativeAuraSlots()
    if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function"
        or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") then
        return false, "The client does not provide CustomAuraContainerTemplate."
    end
    if not C_DurationUtil or type(C_DurationUtil.CreateDurationTextBinding) ~= "function"
        or not C_StringUtil or type(C_StringUtil.CreateNumericRuleFormatter) ~= "function"
        or type(CreateFont) ~= "function" then
        return false, "The client does not provide native aura duration text support."
    end
    return true
end

local function NativeCall(self, procOwned, operation, callback, ...)
    if procOwned then return self:ProcDiagnosticCall(operation, callback, ...) end
    return callback(...)
end

local function Count(self, procOwned, name)
    if procOwned then self:ProcDiagnosticCount(name) end
end

-- A factory can allocate before throwing. Without a returned object there is
-- no public way to recover that allocation, so a session never repeats it.
local function Allocate(self, state, field, operation, counter, procOwned, factory, ...)
    if state[field] then return state[field] end
    local attempted = field .. "Attempted"
    if state[attempted] then
        error("Native aura allocation is uncertain; Reload is required.", 0)
    end
    state[attempted] = true
    local ok, object = pcall(NativeCall, self, procOwned, operation, factory, ...)
    if not ok or object == nil then
        state.allocationUncertain = true
        if not ok then error(object, 0) end
        error("Native aura allocation returned no object; Reload is required.", 0)
    end
    state[field] = object
    Count(self, procOwned, counter)
    return object
end

local function ConfigureDurationTemplate(self, state)
    local formatter = Allocate(self, state, "formatter", "CreateNumericRuleFormatter", "formattersCreated",
        true, C_StringUtil.CreateNumericRuleFormatter)
    self.nativeAuraDurationFormatter = formatter
    if not state.breakpointReady then
        if state.breakpointAttempted then
            error("Native aura formatter configuration is uncertain; Reload is required.", 0)
        end
        -- AddBreakpoint is additive rather than an idempotent setter.
        state.breakpointAttempted = true
        formatter:AddBreakpoint({ threshold = 0, step = 0.1,
            rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f" })
        state.breakpointReady = true
    end
    local binding = Allocate(self, state, "binding", "CreateDurationTextBinding", "durationTemplatesCreated",
        true, C_DurationUtil.CreateDurationTextBinding)
    self.nativeAuraDurationTemplate = binding
    binding:SetTextFormat("{}", {
        { property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter },
    })
    binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
    binding:SetUpdateInterval(0.1)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:SetEnabled(false)
    state.ready = true
    return binding
end

local function DurationTemplate(self)
    local state = self.nativeAuraDurationState
    if not state then state = {}; self.nativeAuraDurationState = state end
    if state.ready then return state.binding end
    return self:ProcDiagnosticCall("durationTemplateConstruct", ConfigureDurationTemplate, self, state)
end

-- Completed shutdown does not undo a possibly completed native allocation or
-- slot registration. Inspect only our own intent flags and returned objects.
function addon:GetProcNativeRetryBlocker()
    for _, handle in pairs(self.nativeAuraSlots or {}) do
        if handle.procOwned and (handle.allocationUncertain
            or (handle.fontAttempted and not handle.font)
            or (handle.containerAttempted and not handle.container)
            or handle.status == "slot-uncertain"
            or (handle.slotAttempted and not handle.slotReady)) then
            return "reload-required"
        end
    end
    local state = self.nativeAuraDurationState
    if state and (state.allocationUncertain
        or (state.formatterAttempted and not state.formatter)
        or (state.bindingAttempted and not state.binding)
        or (state.breakpointAttempted and not state.breakpointReady)) then
        return "reload-required"
    end
end

local Handle = {}

function Handle:SetEnabled(enabled)
    enabled = enabled == true
    self.requestedEnabled = enabled
    if enabled and not self.slotReady then
        self.operationIncomplete = true
        error("A native aura slot must be ready before enabling.", 0)
    end
    local nativeStable = self.enabled == enabled and not self.operationIncomplete
    if nativeStable and enabled then return end
    self.operationIncomplete = true
    local failed, firstError
    local function Attempt(callback, ...)
        local ok, reason = pcall(callback, ...)
        if not ok then
            failed = true
            if firstError == nil then firstError = reason end
        end
        return ok
    end
    local container = self.container
    -- These are addon-owned wrappers. Showing an anchor would not repair a
    -- hidden parent chain; the native container remains their actual child.
    Attempt(self.parent.Show, self.parent)
    if container then
        Attempt(container.SetAlpha, container, enabled and 1 or 0)
        Attempt(container.Show, container)
        local function Request(value)
            if self.procOwned then
                self.owner:ProcDiagnosticAPI(value and "RegisterUnitAura" or "UnregisterUnitAura", "requested")
            end
            return NativeCall(self.owner, self.procOwned, value and "SetEnabledTrue" or "SetEnabledFalse",
                container.SetEnabled, container, value)
        end
        if enabled and not failed then Attempt(Request, true)
        elseif not enabled and (not nativeStable or failed) then Attempt(Request, false) end
        if failed and enabled then
            -- Even a failed alpha/Show/enable operation must request native
            -- disable. Every cleanup call gets its own protected boundary.
            Attempt(container.SetAlpha, container, 0)
            Attempt(Request, false)
            Attempt(self.parent.Show, self.parent)
            Attempt(container.Show, container)
        end
    elseif enabled then
        failed, firstError = true, "The native aura container is unavailable."
    end
    if failed then error(firstError, 0) end
    self.enabled, self.operationIncomplete = enabled, false
end

local function InitializeSlot(self, handle, button, binding)
    Count(self, handle.procOwned, "nativeInitializeCallbacks")
    if handle.initializeAttempted then
        error("A stable native aura slot cannot initialize twice.", 0)
    end
    handle.initializeAttempted = true
    -- ChangeParent is intrinsically forbidden even in this callback. Only
    -- presentation setup allowed before conditional access restrictions occurs.
    button:SetAllPoints(handle.container)
    button:EnableMouse(false)
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetAllPoints(button)
    text:SetFontObject(handle.font)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(false)
    if handle.textOnly then text:SetText(handle.textOnly)
    else button:SetDurationText(text, { binding = binding }) end
    -- Do not retain native button/text references or inspect their state.
    handle.initializeCompleted = true
end

local function Construct(self, handle, entry)
    if handle.status == "slot-uncertain" then
        error("Native aura slot registration is uncertain; Reload is required.", 0)
    end
    if handle.slotReady then return handle end
    if not handle.font then
        if not handle.fontName then
            self.nativeAuraFontCount = (self.nativeAuraFontCount or 0) + 1
            handle.fontName = "CarGOUINativeAuraFont" .. self.nativeAuraFontCount
        end
        Allocate(self, handle, "font", "CreateFont", "fontsCreated", handle.procOwned, CreateFont, handle.fontName)
    end
    handle.status = "font"
    if not handle.fontReady then
        handle.font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
        self:ApplyReminderColor(handle.font, entry)
        handle.fontReady = true
    end
    if not handle.container then
        Allocate(self, handle, "container", "CreateFrame", "containersCreated", handle.procOwned,
            CreateFrame, "AuraContainer", nil, handle.parent, "CustomAuraContainerTemplate")
        handle.operationIncomplete = true
        if handle.procOwned then self:ProcDiagnosticAPI("RegisterProviderSwitch", "requested") end
    end
    handle.status = "container"
    if not handle.containerReady then
        handle.container:SetAllPoints(handle.parent)
        handle:SetEnabled(false)
        NativeCall(self, handle.procOwned, "SetUnit", handle.container.SetUnit, handle.container, "player")
        handle.containerReady = true
    end
    local binding = not handle.textOnly and DurationTemplate(self) or nil
    if handle.slotAttempted then
        handle.status = "slot-uncertain"
        error("Native aura slot registration is uncertain; Reload is required.", 0)
    end
    handle.status, handle.slotAttempted = "slot-pending", true
    local ok, reason = pcall(NativeCall, self, handle.procOwned, "AddAuraSlot",
        handle.container.AddAuraSlot, handle.container, handle.key, "HELPFUL", {
            candidateFilters = { includeSpellIDs = { [handle.auraID] = true } },
            initializeFrame = function(button)
                -- Native securecallfunction may contain callback errors. This
                -- explicit flag is required in addition to an outer return.
                NativeCall(self, handle.procOwned, "InitializeFrame", InitializeSlot, self, handle, button, binding)
            end,
        })
    if not ok or not handle.initializeCompleted then
        handle.status = "slot-uncertain"
        if handle.procOwned and ok then self:RecordProcDiagnosticError("InitializeFrame", "initialization-incomplete") end
        if not ok then error(reason, 0) end
        error("Native aura initialization is incomplete; Reload is required.", 0)
    end
    handle.slotReady, handle.status = true, "ready"
    return handle
end

function addon:CreateNativeAuraSlot(parent, key, auraID, textOnly, entry)
    if type(auraID) ~= "number" or auraID <= 0 or auraID ~= math.floor(auraID)
        or type(key) ~= "string" or key == "" then
        return nil, "A native aura slot requires a verified public key and aura ID."
    end
    self.nativeAuraSlots = self.nativeAuraSlots or {}
    local handle = self.nativeAuraSlots[key]
    if handle and (handle.auraID ~= auraID or handle.textOnly ~= textOnly or handle.parent ~= parent) then
        return nil, "A native aura slot key cannot be reassigned to another effect or wrapper."
    end
    if not handle then
        -- Register ownership before the first fallible native allocation.
        handle = setmetatable({ owner = self, parent = parent, key = key, auraID = auraID, textOnly = textOnly,
            procOwned = entry and entry.kind == "proc", status = "new", requestedEnabled = false,
            slotAttempted = false, slotReady = false }, { __index = Handle })
        self.nativeAuraSlots[key] = handle
    end
    local supported, reason = self:CanUseNativeAuraSlots()
    if not supported then return nil, reason end
    local ok, result = pcall(Construct, self, handle, entry)
    if not ok then
        -- A partial handle remains in the registry for stop/quarantine cleanup.
        pcall(handle.SetEnabled, handle, false)
        error(result, 0)
    end
    return result
end
