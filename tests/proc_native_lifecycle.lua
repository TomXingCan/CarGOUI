local h = ...
local test, equal, truthy = h.test, h.equal, h.truthy

local function Fixture()
    local env, addon, state = h.login(nil, false, { classToken = "UNKNOWN", specID = false, proc = {} })
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    local entry = { id = "native_lifecycle_audit", kind = "proc", class = "MAGE", specID = 63 }
    local function Construct()
        return addon:CreateNativeAuraSlot(parent, entry.id, 48108, nil, entry)
    end
    return env, addon, state, parent, entry, Construct
end

test("Proc native factories retain partial ownership and never repeat uncertain allocation", function()
    for _, target in ipairs({ "font", "container", "formatter", "binding" }) do
        local env, addon, state, _, entry, construct = Fixture()
        local calls = 0
        local function Fault(factory)
            return function(...)
                calls = calls + 1
                truthy(addon.nativeAuraSlots[entry.id], "registry precedes every factory")
                factory(...)
                error("factory threw after allocating")
            end
        end
        if target == "font" then env.CreateFont = Fault(env.CreateFont)
        elseif target == "container" then
            local create = env.CreateFrame
            env.CreateFrame = function(kind, ...)
                if kind == "AuraContainer" then return Fault(create)(kind, ...) end
                return create(kind, ...)
            end
        elseif target == "formatter" then
            env.C_StringUtil.CreateNumericRuleFormatter = Fault(env.C_StringUtil.CreateNumericRuleFormatter)
        else env.C_DurationUtil.CreateDurationTextBinding = Fault(env.C_DurationUtil.CreateDurationTextBinding) end
        equal(pcall(construct), false)
        local handle, frames = addon.nativeAuraSlots[entry.id], #state.frames
        truthy(handle); equal(handle.slotReady, false); equal(handle.slotAttempted, false)
        equal(addon:GetProcNativeRetryBlocker(), "reload-required")
        for _ = 1, 12 do equal(pcall(construct), false) end
        equal(calls, 1, target .. " factory cannot be retried without an object")
        equal(#state.frames, frames, "failed retry retains bounded native allocations")
        equal(addon.nativeAuraSlots[entry.id], handle)
        if handle.container then equal(handle.container.enabled, false) end
    end
end)

test("Proc native idempotent setters retry retained font container formatter and template", function()
    for _, target in ipairs({ "font", "unit", "binding" }) do
        local env, addon, state, _, entry, construct = Fixture()
        local original, owned, injected = nil, nil, false
        local function Once(object, method)
            owned, original = object, object[method]
            object[method] = function(self, ...)
                original(self, ...)
                if not injected then injected = true; error("setter interrupted after assignment") end
            end
        end
        if target == "font" then
            local factory = env.CreateFont
            env.CreateFont = function(...) local font = factory(...); Once(font, "SetFont"); return font end
        elseif target == "unit" then
            local factory = env.CreateFrame
            env.CreateFrame = function(kind, ...)
                local frame = factory(kind, ...)
                if kind == "AuraContainer" then Once(frame, "SetUnit") end
                return frame
            end
        else
            local factory = env.C_DurationUtil.CreateDurationTextBinding
            env.C_DurationUtil.CreateDurationTextBinding = function(...)
                local binding = factory(...)
                if not owned then Once(binding, "SetTextFormat") end
                return binding
            end
        end
        equal(pcall(construct), false)
        local partial = addon.nativeAuraSlots[entry.id]
        equal(addon:GetProcNativeRetryBlocker(), nil, "idempotent partial setup remains retryable")
        local font, container = partial.font, partial.container
        local ready = construct()
        equal(ready, partial); equal(ready.status, "ready"); truthy(ready.slotReady)
        equal(ready.font, font); if container then equal(ready.container, container) end
        local snapshot = addon:GetProcDiagnosticSnapshot()
        equal(snapshot.counters.fontsCreated, 1); equal(snapshot.counters.containersCreated, 1)
        equal(snapshot.counters.formattersCreated, 1); equal(snapshot.counters.durationTemplatesCreated, 1)
        equal(#state.formatters[1].breakpoints, 1, "retry does not append another formatting rule")
        local count = #state.frames
        for _ = 1, 12 do equal(construct(), ready) end
        equal(#state.frames, count); equal(#state.auraSlots, 1)
    end
end)

test("Proc native additive formatter failure cannot duplicate a breakpoint on retry", function()
    local env, addon, state, _, _, construct = Fixture()
    local factory = env.C_StringUtil.CreateNumericRuleFormatter
    env.C_StringUtil.CreateNumericRuleFormatter = function(...)
        local formatter = factory(...)
        local add = formatter.AddBreakpoint
        formatter.AddBreakpoint = function(self, ...)
            add(self, ...)
            error("breakpoint appended before failure")
        end
        return formatter
    end
    for _ = 1, 12 do equal(pcall(construct), false) end
    equal(#state.formatters, 1); equal(#state.formatters[1].breakpoints, 1)
    equal(addon.nativeAuraDurationTemplate, nil); equal(#state.auraSlots, 0)
    truthy(addon.nativeAuraDurationState.breakpointAttempted)
    equal(addon.nativeAuraDurationState.breakpointReady, nil)
    equal(addon:GetProcNativeRetryBlocker(), "reload-required")
end)

test("Proc native contained initialize failure remains uncertain despite successful AddAuraSlot return", function()
    local env, addon, state, _, entry, construct = Fixture()
    local factory, calls, outerReturns = env.CreateFrame, 0, 0
    env.CreateFrame = function(kind, ...)
        local frame = factory(kind, ...)
        if kind == "AuraContainer" then
            local add = frame.AddAuraSlot
            frame.AddAuraSlot = function(self, key, filter, options)
                calls = calls + 1
                local initialize = options.initializeFrame
                options.initializeFrame = function(button)
                    local set = button.SetDurationText
                    button.SetDurationText = function(native, ...)
                        set(native, ...)
                        error("native binding copied before callback failure")
                    end
                    initialize(button)
                end
                local result = add(self, key, filter, options)
                outerReturns = outerReturns + 1
                return result
            end
        end
        return frame
    end
    equal(pcall(construct), false)
    local handle = addon.nativeAuraSlots[entry.id]
    equal(outerReturns, 1, "secure callback error is contained by native fixture")
    equal(handle.status, "slot-uncertain"); equal(handle.slotReady, false)
    equal(handle.slotAttempted, true); equal(handle.initializeCompleted, nil)
    equal(addon:GetProcNativeRetryBlocker(), "reload-required")
    equal(handle.container.enabled, false)
    local frames = #state.frames
    for _ = 1, 12 do equal(pcall(construct), false) end
    equal(calls, 1); equal(#state.frames, frames); equal(#state.auraSlots, 1)
    truthy(addon:GetProcDiagnosticSnapshot().api.InitializeFrame.failed > 0)
end)

test("Proc native failure after slot registration never repeats AddAuraSlot", function()
    local env, addon, state, _, entry, construct = Fixture()
    local factory, calls = env.CreateFrame, 0
    env.CreateFrame = function(kind, ...)
        local frame = factory(kind, ...)
        if kind == "AuraContainer" then
            local add = frame.AddAuraSlot
            frame.AddAuraSlot = function(self, ...)
                calls = calls + 1
                add(self, ...)
                error("outer failure after native slot registration")
            end
        end
        return frame
    end
    for _ = 1, 12 do equal(pcall(construct), false) end
    local handle = addon.nativeAuraSlots[entry.id]
    equal(handle.initializeCompleted, true); equal(handle.slotReady, false)
    equal(handle.status, "slot-uncertain"); equal(calls, 1); equal(#state.auraSlots, 1)
    equal(addon:GetProcNativeRetryBlocker(), "reload-required", "completed callback cannot prove outer registration")
    equal(handle.container.enabled, false)
    equal(pcall(handle.SetEnabled, handle, true), false, "uncertain slot cannot activate")
end)

test("Proc native retry blocker ignores Free Move ownership and safe lifecycle failures", function()
    local _, addon, _, _, _, construct = Fixture()
    equal(addon:GetProcNativeRetryBlocker(), nil)
    addon.nativeAuraSlots = { free = { procOwned = false, status = "slot-uncertain", slotAttempted = true,
        allocationUncertain = true, fontAttempted = true, containerAttempted = true } }
    equal(addon:GetProcNativeRetryBlocker(), nil, "Free Move has independent recovery ownership")
    local handle = construct()
    handle.operationIncomplete, handle.requestedEnabled = true, true
    equal(addon:GetProcNativeRetryBlocker(), nil, "safe enable/disable setters can retry retained objects")
    handle:SetEnabled(false)
    equal(addon:GetProcNativeRetryBlocker(), nil)
end)

test("Proc native failed lifecycle commits only complete state and always attempts disable", function()
    for _, target in ipairs({ "alpha", "show", "native" }) do
        local _, _, _, parent, _, construct = Fixture()
        local handle = construct()
        local container, disabled = handle.container, 0
        local native = container.SetEnabled
        container.SetEnabled = function(self, value)
            if value == false then disabled = disabled + 1 end
            native(self, value)
            if target == "native" and value == true then error("enable interrupted after native mutation") end
        end
        local restore
        if target == "alpha" then
            local set = container.SetAlpha
            container.SetAlpha = function(self, value) if value == 1 then error("alpha failure") end; return set(self, value) end
            restore = function() container.SetAlpha = set end
        elseif target == "show" then
            local show = parent.Show
            parent.Show = function() error("parent Show failure") end
            restore = function() parent.Show = show end
        else restore = function() container.SetEnabled = native end end
        equal(pcall(handle.SetEnabled, handle, true), false)
        equal(handle.requestedEnabled, true); equal(handle.enabled, false)
        truthy(handle.operationIncomplete); truthy(disabled > 0)
        equal(container.enabled, false, "failed enable leaves native tracking disabled")
        restore()
        parent:Hide(); container:Hide()
        handle:SetEnabled(false)
        equal(handle.requestedEnabled, false); equal(handle.operationIncomplete, false)
        truthy(parent:IsShown()); truthy(container:IsShown()); equal(container.alpha, 0)
        handle:SetEnabled(true); equal(handle.enabled, true)
        handle:SetEnabled(false); equal(handle.enabled, false)
    end
end)

test("Proc native interrupted disable retries despite the requested value already being false", function()
    local _, _, _, parent, _, construct = Fixture()
    local handle = construct()
    handle:SetEnabled(true)
    local setter, calls = handle.container.SetEnabled, 0
    handle.container.SetEnabled = function(self, value)
        setter(self, value); calls = calls + 1
        if calls == 1 then error("disable interrupted after mutation") end
    end
    equal(pcall(handle.SetEnabled, handle, false), false)
    equal(handle.requestedEnabled, false); equal(handle.enabled, true); truthy(handle.operationIncomplete)
    handle:SetEnabled(false)
    equal(calls, 2); equal(handle.enabled, false); equal(handle.operationIncomplete, false)
    parent:Hide(); handle.container:Hide()
    handle:SetEnabled(false); equal(calls, 2, "completed stable lifecycle has no redundant native request")
    truthy(parent:IsShown()); truthy(handle.container:IsShown(), "disabled dirty ancestors stay visible")
end)
