local _, addon = ...

-- Proc-only, session-only circuit breaker. Error objects and native payloads
-- are deliberately neither inspected nor retained by this boundary.
local BUDGET = 3
local phases = { configure = true, render = true, event = true, catalog = true,
    stop = true, retry = true, artwork = true, preview = true, animation = true,
    hook = true, release = true, preferences = true, nativeConstruct = true,
    InitializeFrame = true, durationTemplateConstruct = true }

local function State(self)
    if not self.procSafety then
        self.procSafety = { quarantined = false, generation = 1, failures = 0,
            budget = BUDGET, phase = "none", reason = "none", cleanupComplete = true }
    end
    return self.procSafety
end

local function Phase(value)
    if type(value) == "string" and phases[value] then return value end
    return "operation"
end

local function Diagnostics(self, state)
    self:SetProcDiagnosticState("quarantined", state.quarantined)
    self:SetProcDiagnosticState("retryAllowed", state.quarantined and not state.cleaning)
    self:SetProcDiagnosticState("failureStage", state.phase)
    self:SetProcDiagnosticState("failureReason", state.reason)
end

function addon:IsProcQuarantined() return State(self).quarantined end
function addon:GetProcSafetyGeneration() return State(self).generation end
function addon:IsProcSafetyGenerationCurrent(generation)
    local state = State(self)
    return not state.quarantined and generation == state.generation
end
function addon:InvalidateProcSafetyGeneration()
    local state = State(self)
    state.generation = state.generation + 1
    return state.generation
end

local function Cleanup(self, state)
    state.cleaning = true
    local ok, clean = pcall(self.StopProc, self)
    state.cleaning = nil
    state.cleanupComplete = ok and clean == true
    if not state.cleanupComplete then state.reason = "cleanup-incomplete" end
    Diagnostics(self, state)
    return state.cleanupComplete
end

function addon:QuarantineProc(phase)
    local state = State(self)
    if state.quarantined then return false end
    -- Lock entry points before cleanup can invoke another callback.
    state.quarantined, state.phase, state.reason = true, Phase(phase), "failure-budget-exhausted"
    self:InvalidateProcSafetyGeneration()
    self:ProcDiagnosticCount("quarantineEntries")
    self:RecordProcDiagnosticError("quarantine", state.reason)
    Diagnostics(self, state)
    Cleanup(self, state)
    self:Print(self:Text("Proc was quarantined for this session after repeated errors. Use /cui diagnostics copy, then /cui proc retry or /reload."))
    return true
end

function addon:RecordProcFailure(phase)
    local state = State(self)
    if state.quarantined or state.cleaning then return false end
    if state.operation and state.operation.failed then return false end
    if state.operation then state.operation.failed = true end
    state.failures = math.min(BUDGET, state.failures + 1)
    state.phase, state.reason = Phase(phase), "call-failed"
    -- The bounded diagnostics ring accepts only its fixed public stage set.
    self:RecordProcDiagnosticError("safety", "proc-" .. state.phase .. "-call-failed")
    Diagnostics(self, state)
    if state.retrying or state.failures >= BUDGET then self:QuarantineProc(state.phase) end
    return true
end

local function Pack(...) return { n = select("#", ...), ... } end

function addon:RunProcSafe(phase, callback, ...)
    local state = State(self)
    if state.quarantined then return false, "proc-quarantined" end
    local previous = state.operation
    state.operation = previous or {}
    local result = Pack(pcall(callback, ...))
    if not result[1] then self:RecordProcFailure(phase) end
    state.operation = previous
    return unpack(result, 1, result.n)
end

function addon:RetryProc()
    local state = State(self)
    self:ProcDiagnosticCount("retryRequests")
    if not state.quarantined then return true end
    if state.cleaning or state.retrying then return false, "proc-retry-in-progress" end
    self:InvalidateProcSafetyGeneration()
    if not Cleanup(self, state) then return false, "proc-cleanup-incomplete" end
    if self.GetProcRetryBlocker then
        local ok, blocker = pcall(self.GetProcRetryBlocker, self)
        if not ok or blocker ~= nil then
            state.phase, state.reason = "retry", "reload-required"
            Diagnostics(self, state)
            return false, "proc-reload-required"
        end
    end
    state.failures, state.phase, state.reason = 0, "retry", "none"
    state.quarantined, state.retrying = false, true
    Diagnostics(self, state)
    local ok = self:RunProcSafe("retry", self.ConfigureProc, self)
    state.retrying = nil
    Diagnostics(self, state)
    return ok and not state.quarantined, state.quarantined and "proc-retry-failed" or nil
end

function addon:GetProcSafetyDiagnostics()
    local state = State(self)
    return { quarantined = state.quarantined, generation = state.generation,
        failures = state.failures, budget = BUDGET, phase = state.phase, reason = state.reason,
        cleanupComplete = state.cleanupComplete, retryAllowed = state.quarantined and not state.cleaning }
end
