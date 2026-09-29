local _, addon = ...

-- Session-only instrumentation. Fixed keys and a capped ring prevent an error
-- storm or repeated context changes from creating an unbounded diagnostic log.
local counterKeys = {
    "constructAttempts", "constructSuccesses", "constructFailures", "partialConstructions",
    "configureCalls", "stopCalls", "showEvents", "hideEvents", "wrapperFramesCreated",
    "containersCreated", "fontsCreated", "formattersCreated", "durationTemplatesCreated",
    "nativeInitializeCallbacks", "artworkFramesCreated", "artworkTexturesCreated",
    "previewArtworkFramesCreated", "previewArtworkTexturesCreated", "animationGroupsCreated",
    "animationsCreated", "artworkHooksInstalled", "quarantineEntries", "retryRequests",
    "errorsRecorded", "errorsDropped",
}
local operationKeys = {
    "nativeConstruct", "durationTemplateConstruct", "CreateFrame", "CreateFont",
    "CreateNumericRuleFormatter", "CreateDurationTextBinding", "AddAuraSlot", "SetEnabledTrue",
    "SetEnabledFalse", "SetUnit", "InitializeFrame", "RegisterUnitAura", "UnregisterUnitAura",
    "RegisterProviderSwitch", "UnregisterProviderSwitch", "HookNativeShow", "HookNativeHide",
    "RestoreNativeAlpha", "SuppressNativeAlpha", "ArtworkConstruct", "AnimationConstruct",
}
local createdKeys = { "wrapperFramesCreated", "containersCreated", "fontsCreated", "formattersCreated",
    "durationTemplatesCreated", "artworkFramesCreated", "artworkTexturesCreated",
    "previewArtworkFramesCreated", "previewArtworkTexturesCreated", "animationGroupsCreated", "animationsCreated" }
local stages = { configure = true, stop = true, show = true, hide = true, quarantine = true, retry = true, safety = true }
local numericState = { pendingTasks = true, nativeEnableRequested = true, nativeDisableRequested = true, hookParts = true }
local booleanState = { quarantined = true, retryAllowed = true }
local textState = { failureStage = true, failureReason = true, currentClass = true, currentSpec = true }
local MAX_COUNT, ERROR_CAP, TEXT_CAP = 9007199254740991, 16, 160
local counters, operations = {}, {}
for _, key in ipairs(counterKeys) do counters[key] = 0 end
for _, key in ipairs(operationKeys) do
    operations[key] = { requested = 0, completed = 0, failed = 0 }
    stages[key] = true
end
local state = { quarantined = false, retryAllowed = false, pendingTasks = 0,
    nativeEnableRequested = 0, nativeDisableRequested = 0, hookParts = 0,
    failureStage = "none", failureReason = "none", currentClass = "unavailable", currentSpec = "unavailable" }
local errors, errorCursor = {}, 0

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Text(value)
    if not Public(value) then return end
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return end
        value = tostring(value)
    end
    if type(value) ~= "string" then return end
    -- Reasons are public codes, never native error objects, stack traces, aura
    -- payloads, native button state, or formatted timer output.
    return value:sub(1, TEXT_CAP):gsub("[%c]", " ")
end

local function Add(values, key, amount)
    values[key] = math.min(MAX_COUNT, values[key] + amount)
end

function addon:ProcDiagnosticCount(name, delta)
    if not Public(name) or type(name) ~= "string" or counters[name] == nil then return false end
    if delta == nil then delta = 1 end
    if not Public(delta) or type(delta) ~= "number" or delta < 0 or delta > MAX_COUNT
        or delta ~= math.floor(delta) then return false end
    Add(counters, name, delta)
    return true
end

function addon:ProcDiagnosticAPI(operation, outcome)
    if not Public(operation) or type(operation) ~= "string" or not operations[operation]
        or not Public(outcome) or type(outcome) ~= "string" or operations[operation][outcome] == nil then return false end
    Add(operations[operation], outcome, 1)
    return true
end

function addon:SetProcDiagnosticState(name, value)
    if not Public(name) or type(name) ~= "string" or not Public(value) then return false end
    if numericState[name] then
        if type(value) ~= "number" or value < 0 or value > 1000000 or value ~= math.floor(value) then return false end
    elseif booleanState[name] then
        if type(value) ~= "boolean" then return false end
    elseif textState[name] then
        value = Text(value)
        if not value then return false end
    else return false end
    state[name] = value
    return true
end

function addon:RecordProcDiagnosticError(stage, reason)
    if not Public(stage) or type(stage) ~= "string" or not stages[stage] then return false end
    reason = Text(reason)
    if not reason then return false end
    self:ProcDiagnosticCount("errorsRecorded")
    if #errors == ERROR_CAP then self:ProcDiagnosticCount("errorsDropped") end
    errorCursor = errorCursor % ERROR_CAP + 1
    errors[errorCursor] = { sequence = counters.errorsRecorded, stage = stage, reason = reason }
    state.failureStage, state.failureReason = stage, reason
    return true
end

local function CreatedTotal()
    local total = 0
    for _, key in ipairs(createdKeys) do total = total + counters[key] end
    return total
end

local function Pack(...) return { n = select("#", ...), ... } end

-- Use only around explicitly owned construction/API boundaries. The original
-- return tuple or original error is preserved; diagnostics do not swallow a
-- failure, retry a call, or reinterpret a nil/secret native return value.
function addon:ProcDiagnosticCall(operation, callback, ...)
    if not Public(operation) or type(operation) ~= "string" or not operations[operation] then
        error("Unknown Proc diagnostic operation.", 2)
    end
    local construction = operation == "nativeConstruct"
    local before = construction and CreatedTotal()
    self:ProcDiagnosticAPI(operation, "requested")
    if construction then self:ProcDiagnosticCount("constructAttempts") end
    local result = Pack(pcall(callback, ...))
    self:ProcDiagnosticAPI(operation, result[1] and "completed" or "failed")
    if construction then
        local created = result[1] and Public(result[2])
            and (type(result[2]) == "table" or type(result[2]) == "userdata")
        self:ProcDiagnosticCount(created and "constructSuccesses" or "constructFailures")
        if not created and CreatedTotal() > before then self:ProcDiagnosticCount("partialConstructions") end
        if result[1] and not created then self:RecordProcDiagnosticError(operation, "returned-no-resource") end
    end
    if not result[1] then
        self:RecordProcDiagnosticError(operation, "call-failed")
        error(result[2], 0)
    end
    return unpack(result, 2, result.n)
end

local function Table(value)
    return Public(value) and type(value) == "table" and value or nil
end

local function Object(value)
    if not Public(value) then return end
    local kind = type(value)
    if kind == "table" or kind == "userdata" then return value end
end

local function CountPublicReferences(pool, seen)
    local count = 0
    for _, object in pairs(Table(pool) or {}) do
        if Object(object) and not seen[object] then seen[object] = true; count = count + 1 end
    end
    return count
end

local function NewNativeStock()
    return { nativeSlots = 0, requestedEnabledSlots = 0, requestedDisabledSlots = 0, unreportedEnabledSlots = 0, enabledFlags = 0,
        durationSlots = 0, textSlots = 0, registeredContainers = 0, registeredFonts = 0,
        nativeWrappers = 0, readyHandles = 0, partialHandles = 0, uncertainSlots = 0,
        attemptedSlots = 0, pendingSlots = 0, registeredContexts = 0, requestedActiveContexts = 0,
        currentContextSlots = 0, historicalContextSlots = 0 }
end

local function Context(entry)
    if not Table(entry) then return end
    local class, spec = Text(entry.class), Text(entry.specID)
    if class then return class .. ":" .. (spec or "unselected") end
end

local function CurrentContext(self)
    local class = state.currentClass ~= "unavailable" and state.currentClass or Text(self.activeAdapterClass)
    local spec = state.currentSpec ~= "unavailable" and state.currentSpec or Text(self.activeModuleSpec)
    return class, spec, class and (class .. ":" .. (spec or "unselected")) or "unavailable"
end

local function Stock(self, currentContext)
    local result, free = NewNativeStock(), NewNativeStock()
    local frames = Table(self.reminderFrames)
    local wrappers = Table(frames and frames.nativeAura) or {}
    local containers, fonts, freeContainers, freeFonts, groups, animations = {}, {}, {}, {}, {}, {}
    local contexts, activeContexts = {}, {}
    for key, handle in pairs(Table(self.nativeAuraSlots) or {}) do
        if Table(handle) and Public(handle.procOwned) then
            local proc = handle.procOwned == true
            local target, containerSet, fontSet = proc and result or free, proc and containers or freeContainers, proc and fonts or freeFonts
            target.nativeSlots = target.nativeSlots + 1
            local requested
            if Public(handle.requestedEnabled) and type(handle.requestedEnabled) == "boolean" then requested = handle.requestedEnabled
            elseif Public(handle.enabled) and type(handle.enabled) == "boolean" then requested = handle.enabled end
            if requested == true then target.requestedEnabledSlots = target.requestedEnabledSlots + 1
            elseif requested == false then target.requestedDisabledSlots = target.requestedDisabledSlots + 1
            else target.unreportedEnabledSlots = target.unreportedEnabledSlots + 1 end
            if Public(handle.enabled) and handle.enabled == true then target.enabledFlags = target.enabledFlags + 1 end
            if Public(handle.textOnly) and type(handle.textOnly) == "string" then target.textSlots = target.textSlots + 1
            else target.durationSlots = target.durationSlots + 1 end
            target.registeredContainers = target.registeredContainers + CountPublicReferences({ handle.container }, containerSet)
            target.registeredFonts = target.registeredFonts + CountPublicReferences({ handle.font }, fontSet)
            local status = Text(handle.status) or "ready"
            if status == "ready" then target.readyHandles = target.readyHandles + 1
            else target.partialHandles = target.partialHandles + 1 end
            if status == "slot-uncertain" then target.uncertainSlots = target.uncertainSlots + 1 end
            if status == "slot-pending" then target.pendingSlots = target.pendingSlots + 1 end
            if (Public(handle.slotAttempted) and handle.slotAttempted == true) or status == "ready" then target.attemptedSlots = target.attemptedSlots + 1 end
            local wrapper = Public(key) and wrappers[key]
            local context = Object(wrapper) and Context(wrapper.reminderEntry)
            if proc and context then
                if not contexts[context] then contexts[context] = true; result.registeredContexts = result.registeredContexts + 1 end
                if requested and not activeContexts[context] then activeContexts[context] = true; result.requestedActiveContexts = result.requestedActiveContexts + 1 end
                local scope = context == currentContext and "currentContextSlots" or "historicalContextSlots"
                result[scope] = result[scope] + 1
            end
        end
    end
    for _, frame in pairs(wrappers) do
        if Object(frame) and Table(frame.reminderEntry) then
            local kind = frame.reminderEntry.kind
            if Public(kind) then
                local target = kind == "proc" and result or free
                target.nativeWrappers = target.nativeWrappers + 1
            end
        end
    end
    result.registeredDurationTemplates = Object(self.nativeAuraDurationTemplate) and 1 or 0
    result.artworkFrames, result.previewArtworkFrames, result.artworkTextures = 0, 0, 0
    result.animationGroups, result.animations, result.activeArtwork, result.exitingArtwork = 0, 0, 0, 0
    result.requestedAnimationPhases, result.suppressedOverlays, result.pendingTasks, result.registeredHookParts = 0, 0, 0, 0
    for _, parts in pairs(Table(self.procArtworkHookParts) or {}) do
        if Table(parts) then
            for _, key in ipairs({ "show", "release" }) do
                if Public(parts[key]) and parts[key] == true then result.registeredHookParts = result.registeredHookParts + 1 end
            end
        end
    end
    for _, field in ipairs({ "procArtworkFrames", "procPreviewArtworkFrames" }) do
        for _, frame in pairs(Table(self[field]) or {}) do
            if Object(frame) then
                local stockKey = field == "procArtworkFrames" and "artworkFrames" or "previewArtworkFrames"
                result[stockKey] = result[stockKey] + 1
                if Object(frame.texture) then result.artworkTextures = result.artworkTextures + 1 end
                if Public(frame.active) and frame.active == true then result.activeArtwork = result.activeArtwork + 1 end
                if Public(frame.exiting) and frame.exiting == true then result.exitingArtwork = result.exitingArtwork + 1 end
                if Public(frame.phase) and type(frame.phase) == "string" then result.requestedAnimationPhases = result.requestedAnimationPhases + 1 end
                result.animationGroups = result.animationGroups + CountPublicReferences(frame.groups, groups)
                for _, group in pairs(Table(frame.groups) or {}) do
                    if Object(group) then result.animations = result.animations + CountPublicReferences({ group.animation }, animations) end
                end
            end
        end
    end
    for _, owned in pairs(Table(self.procSuppressedOverlays) or {}) do
        if Table(owned) then result.suppressedOverlays = result.suppressedOverlays + 1 end
    end
    if Public(self.procPending) and self.procPending then result.pendingTasks = result.pendingTasks + 1 end
    return result, free
end

local function Safety(self)
    local result = { quarantined = false, generation = 1, failures = 0, budget = 3,
        phase = "none", reason = "none", cleanupComplete = true, retryAllowed = false }
    if type(self.GetProcSafetyDiagnostics) ~= "function" then return result end
    local ok, supplied = pcall(self.GetProcSafetyDiagnostics, self)
    if not ok or not Table(supplied) then return result end
    for key, fallback in pairs(result) do
        local value = supplied[key]
        if Public(value) and type(value) == type(fallback) then
            if type(value) == "string" then result[key] = Text(value)
            elseif type(value) == "boolean" then result[key] = value
            elseif value >= 0 and value <= MAX_COUNT and value == math.floor(value) then result[key] = value end
        end
    end
    return result
end

function addon:GetProcDiagnosticSnapshot()
    local class, spec, context = CurrentContext(self)
    local stock, freeStock = Stock(self, context)
    local result = { format = 1, scope = "session", counters = {}, api = {}, state = {}, stock = stock, freeMoveStock = freeStock,
        errors = {}, errorCapacity = ERROR_CAP, reasonCapacity = TEXT_CAP, safety = Safety(self),
        nativeListenerActual = "unobservable", nativeBindingActual = "unobservable", nativeAuraPresence = "unobservable" }
    for _, key in ipairs(counterKeys) do result.counters[key] = counters[key] end
    for _, key in ipairs(operationKeys) do
        local value = operations[key]
        result.api[key] = { requested = value.requested, completed = value.completed, failed = value.failed }
    end
    for key, value in pairs(state) do result.state[key] = value end
    result.state.currentClass, result.state.currentSpec = class or "unavailable", spec or "unavailable"
    result.state.nativeEnableRequested, result.state.nativeDisableRequested = stock.requestedEnabledSlots, stock.requestedDisabledSlots
    result.state.hookParts = stock.registeredHookParts
    result.state.pendingTasks = math.max(state.pendingTasks, stock.pendingTasks)
    local events = self.GetEventDiagnostics and self:GetEventDiagnostics() or {}
    result.coreCallbacks, result.coreEvents = events.callbacks or 0, events.events or 0
    for index = 1, #errors do
        local position = #errors == ERROR_CAP and (errorCursor + index - 1) % ERROR_CAP + 1 or index
        local item = errors[position]
        result.errors[index] = { sequence = item.sequence, stage = item.stage, reason = item.reason }
    end
    return result
end

local function Fields(values, keys)
    local result = {}
    for _, key in ipairs(keys) do result[#result + 1] = key .. "=" .. tostring(values[key]) end
    return table.concat(result, "; ")
end

function addon:GetProcDiagnosticText()
    local snapshot = self:GetProcDiagnosticSnapshot()
    local stockKeys = { "nativeSlots", "requestedEnabledSlots", "registeredContainers", "registeredFonts",
        "registeredDurationTemplates", "nativeWrappers", "durationSlots", "textSlots", "pendingTasks",
        "artworkFrames", "previewArtworkFrames", "artworkTextures", "animationGroups", "animations",
        "activeArtwork", "exitingArtwork", "requestedAnimationPhases", "suppressedOverlays",
        "enabledFlags", "requestedDisabledSlots", "unreportedEnabledSlots", "registeredHookParts", "readyHandles", "partialHandles", "uncertainSlots", "attemptedSlots", "pendingSlots",
        "registeredContexts", "requestedActiveContexts", "currentContextSlots", "historicalContextSlots" }
    local lines = { "Proc diagnostic baseline v1 (session only; no SavedVariables):",
        "Cumulative actual owned allocations and lifecycle calls: " .. Fields(snapshot.counters, counterKeys),
        "Current Proc addon registry stock (not lifetime allocation totals): " .. Fields(snapshot.stock, stockKeys),
        "Separate Free move registry stock (not included in Proc allocation counters): " .. Fields(snapshot.freeMoveStock,
            { "nativeSlots", "requestedEnabledSlots", "nativeWrappers", "registeredContainers", "registeredFonts" }),
        "Core router: events=" .. snapshot.coreEvents .. "; callbacks=" .. snapshot.coreCallbacks,
        "Proc safety: " .. Fields(snapshot.safety, { "quarantined", "generation", "failures", "budget", "phase", "reason", "cleanupComplete", "retryAllowed" }),
        "Native listener registrations are requests only; actual listener/binding state and aura presence are unobservable.",
        "Requested state: " .. Fields(snapshot.state, { "quarantined", "retryAllowed", "pendingTasks",
            "nativeEnableRequested", "nativeDisableRequested", "hookParts", "currentClass", "currentSpec", "failureStage", "failureReason" }),
        "Native API completed means the call returned; it does not prove secure/native work completed.",
        "Zero API counters mean no instrumented call was observed; they do not prove an internal API was never used.",
    }
    for _, key in ipairs(operationKeys) do lines[#lines + 1] = "API " .. key .. ": " .. Fields(snapshot.api[key], { "requested", "completed", "failed" }) end
    lines[#lines + 1] = "Bounded public failures: retained=" .. #snapshot.errors .. "/" .. ERROR_CAP
        .. "; reason bytes<=" .. TEXT_CAP .. "; dropped=" .. snapshot.counters.errorsDropped
    for _, item in ipairs(snapshot.errors) do
        lines[#lines + 1] = "#" .. item.sequence .. " " .. item.stage .. ": " .. item.reason
    end
    return table.concat(lines, "\n")
end
