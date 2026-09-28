local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open()
    return h.login(nil, false, { classToken = "UNKNOWN", specID = false })
end

test("Proc diagnostics fixed keys reject restricted values and keep a detached bounded failure ring", function()
    local _, addon, fixture = Open()
    local saved, callbacks, frames = copy(addon.db), addon:GetEventDiagnostics(), #fixture.frames
    local restricted = h.secret("diagnostic tripwire")
    for _, value in ipairs({ restricted, {}, -1, math.huge, 0 / 0 }) do
        equal(addon:ProcDiagnosticCount("showEvents", value), false)
    end
    equal(addon:ProcDiagnosticCount("dynamic-unbounded-key"), false)
    equal(addon:ProcDiagnosticAPI(restricted, "requested"), false)
    equal(addon:ProcDiagnosticAPI("SetUnit", restricted), false)
    equal(addon:SetProcDiagnosticState("currentClass", restricted), false)
    equal(addon:SetProcDiagnosticState("quarantined", {}), false)
    equal(addon:RecordProcDiagnosticError("show", restricted), false)
    equal(addon:RecordProcDiagnosticError("show", {}), false)
    for index = 1, 100 do
        addon:ProcDiagnosticCount("showEvents")
        addon:RecordProcDiagnosticError("show", string.rep("x", 400) .. "\n" .. index)
    end
    local snapshot = addon:GetProcDiagnosticSnapshot()
    equal(snapshot.counters.showEvents, 100)
    equal(#snapshot.errors, 16); equal(snapshot.counters.errorsDropped, 84)
    equal(snapshot.errors[1].sequence, 85); equal(snapshot.errors[16].sequence, 100)
    for _, item in ipairs(snapshot.errors) do equal(#item.reason, 160); equal(item.reason:find("\n", 1, true), nil) end
    snapshot.counters.showEvents = -100; snapshot.api.SetUnit.requested = 44; snapshot.errors[1].reason = "mutated"
    local fresh = addon:GetProcDiagnosticSnapshot()
    equal(fresh.counters.showEvents, 100); equal(fresh.api.SetUnit.requested, 0)
    truthy(fresh.errors[1].reason ~= "mutated")
    equal(fresh.nativeListenerActual, "unobservable"); equal(fresh.nativeBindingActual, "unobservable")
    same(fresh.safety, { quarantined = false, generation = 1, failures = 0, budget = 3,
        phase = "none", reason = "none", cleanupComplete = true, retryAllowed = false })
    addon.GetProcSafetyDiagnostics = function() return { quarantined = true, failures = 2, budget = restricted,
        phase = "render", arbitrary = "ignored", cleanupComplete = false } end
    local safety = addon:GetProcDiagnosticSnapshot().safety
    equal(safety.quarantined, true); equal(safety.failures, 2); equal(safety.budget, 3)
    equal(safety.phase, "render"); equal(safety.cleanupComplete, false); equal(safety.arbitrary, nil)
    same(addon.db, saved); same(addon:GetEventDiagnostics(), callbacks); equal(#fixture.frames, frames)
    equal(#fixture.errors, 0)
end)

test("Proc diagnostics construction boundary preserves tuples errors and partial allocation evidence", function()
    local _, addon = Open()
    local a, b, c = addon:ProcDiagnosticCall("SetUnit", function() return nil, false, "third" end)
    equal(a, nil); equal(b, false); equal(c, "third")
    local owned = {}
    equal(addon:ProcDiagnosticCall("nativeConstruct", function()
        addon:ProcDiagnosticCount("containersCreated")
        return owned
    end), owned)
    local originalError = h.secret("do not stringify this failure object")
    local ok, thrown = pcall(function()
        addon:ProcDiagnosticCall("nativeConstruct", function()
            addon:ProcDiagnosticCount("fontsCreated")
            error(originalError)
        end)
    end)
    equal(ok, false); equal(thrown, originalError, "the original failure remains visible to its caller")
    local result, reason = addon:ProcDiagnosticCall("nativeConstruct", function() return nil, "unsupported" end)
    equal(result, nil); equal(reason, "unsupported", "ordinary unsupported returns remain unchanged")
    local report = addon:GetProcDiagnosticSnapshot()
    equal(report.counters.constructAttempts, 3); equal(report.counters.constructSuccesses, 1)
    equal(report.counters.constructFailures, 2); equal(report.counters.partialConstructions, 1)
    equal(report.counters.containersCreated, 1); equal(report.counters.fontsCreated, 1)
    same(report.api.nativeConstruct, { requested = 3, completed = 2, failed = 1 })
    equal(report.errors[1].reason, "call-failed"); equal(report.errors[2].reason, "returned-no-resource")
    equal(report.stock.nativeSlots, 0, "created resources need not have reached the registry")
end)

test("Proc diagnostics distinguish Proc Free Move and historical registration without reading native objects", function()
    local _, addon = Open()
    local function Denied() error("diagnostics must not invoke native object methods") end
    local container, font = { IsShown = Denied, GetAlpha = Denied }, { GetText = Denied }
    local current = { reminderEntry = { kind = "proc", class = "MAGE", specID = 62 } }
    local historical = { reminderEntry = { kind = "proc", class = "MAGE", specID = 63 } }
    local free = { reminderEntry = { kind = "mobility", class = "MAGE", freeMove = true } }
    addon.reminderFrames = { nativeAura = { current = current, historical = historical, free = free } }
    addon.nativeAuraSlots = {
        current = { procOwned = true, container = container, font = font, enabled = false, requestedEnabled = true,
            status = "slot-uncertain", slotAttempted = true },
        historical = { procOwned = true, container = container, font = font, enabled = false },
        free = { procOwned = false, container = {}, font = {}, enabled = true, textOnly = "Free move" },
    }
    addon:SetProcDiagnosticState("currentClass", "MAGE"); addon:SetProcDiagnosticState("currentSpec", 62)
    addon:ProcDiagnosticCount("containersCreated", 8)
    local group = { animation = {}, IsPlaying = Denied }
    addon.procArtworkFrames = { current = { texture = {}, active = true, phase = "active", groups = { pulse = group } } }
    local report = addon:GetProcDiagnosticSnapshot()
    equal(report.counters.containersCreated, 8); equal(report.stock.registeredContainers, 1)
    equal(report.stock.nativeSlots, 2); equal(report.stock.nativeWrappers, 2)
    equal(report.stock.registeredContexts, 2); equal(report.stock.requestedActiveContexts, 1)
    equal(report.stock.currentContextSlots, 1); equal(report.stock.historicalContextSlots, 1)
    equal(report.stock.requestedEnabledSlots, 1); equal(report.stock.enabledFlags, 0)
    equal(report.stock.readyHandles, 1); equal(report.stock.partialHandles, 1); equal(report.stock.uncertainSlots, 1)
    equal(report.freeMoveStock.nativeSlots, 1); equal(report.freeMoveStock.requestedEnabledSlots, 1)
    equal(report.stock.animationGroups, 1); equal(report.stock.animations, 1); equal(report.stock.activeArtwork, 1)
    local text = addon:GetProcDiagnosticText()
    truthy(text:find("not lifetime allocation totals", 1, true))
    truthy(text:find("actual listener/binding state and aura presence are unobservable", 1, true))
end)

test("Proc diagnostics slash snapshot samples performance only on demand without opening Options", function()
    local env, addon, fixture = Open()
    local memoryUpdates, cpuUpdates = 0, 0
    env.UpdateAddOnMemoryUsage = function() memoryUpdates = memoryUpdates + 1 end
    env.UpdateAddOnCPUUsage = function() cpuUpdates = cpuUpdates + 1 end
    env.GetAddOnMemoryUsage = function() return 128 end
    env.GetAddOnCPUUsage = function() return 32 end
    env.C_CVar = { GetCVarBool = function() return false end }
    local saved, callbacks, frames = copy(addon.db), addon:GetEventDiagnostics(), #fixture.frames
    addon:GetProcDiagnosticSnapshot(); equal(memoryUpdates, 0)
    addon:HandleSlashCommand("diagnostics")
    equal(memoryUpdates, 1); equal(cpuUpdates, 0); equal(addon.optionsFrame, nil)
    equal(#fixture.frames, frames); same(addon:GetEventDiagnostics(), callbacks); same(addon.db, saved)
    env.C_CVar.GetCVarBool = function() return true end
    local text = addon:PrintDiagnosticsSnapshot()
    equal(memoryUpdates, 2); equal(cpuUpdates, 1)
    truthy(text:find("Proc diagnostic baseline v1", 1, true))
    truthy(text:find("memory (runtime KB): 128", 1, true)); truthy(text:find("CPU (cumulative ms): 32", 1, true))
    env.GetAddOnMemoryUsage = function() error(h.secret("measurement error")) end
    truthy(addon:GetDiagnosticsSnapshotText():find("memory (runtime KB): unavailable", 1, true))
    equal(#fixture.errors, 0)
end)

test("Proc diagnostics standalone copy window is read-only reusable and releases focus on Escape", function()
    local _, addon, fixture = Open()
    local saved, callbacks = copy(addon.db), addon:GetEventDiagnostics()
    addon:HandleSlashCommand("diagnostics copy")
    local dialog = assert(addon.diagnosticsSnapshotFrame)
    truthy(dialog:IsShown()); equal(addon.optionsFrame, nil)
    truthy(dialog.snapshot:find("Proc diagnostic baseline v1", 1, true))
    local snapshot, frames = dialog.snapshot, #fixture.frames
    dialog.editBox:SetText("changed")
    dialog.editBox:GetScript("OnTextChanged")(dialog.editBox, true)
    equal(dialog.editBox:GetText(), snapshot)
    dialog.selectAll:Click(); truthy(dialog.editBox:HasFocus()); truthy(dialog.editBox.highlight)
    dialog.editBox:GetScript("OnEscapePressed")(dialog.editBox)
    equal(dialog:IsShown(), false); equal(dialog.editBox:HasFocus(), false)
    for _ = 1, 5 do addon:HandleSlashCommand("diagnostics copy"); dialog.refresh:Click(); dialog.close:Click() end
    equal(#fixture.frames, frames, "repeated manual snapshots reuse the independent copy dialog")
    same(addon:GetEventDiagnostics(), callbacks); same(addon.db, saved)
    for _, frame in ipairs(fixture.frames) do equal(frame:GetScript("OnUpdate"), nil) end
    equal(#fixture.errors, 0)
end)
