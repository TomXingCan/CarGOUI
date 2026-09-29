local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

test("Proc fixture enforces intrinsic parenting private slots and deferred native disable", function()
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local left = h.procFrame(addon, "mage_fire_hot_streak_left")
    local right = h.procFrame(addon, "mage_fire_hot_streak_right")
    truthy(left.auraHandle.container ~= right.auraHandle.container)
    local target
    for _, slot in ipairs(state.auraSlots) do if slot.key == left.entryId then target = slot end end
    equal(pcall(target.button.SetParent, target.button, right), false)
    equal(left.auraHandle.container.HasAuraSlot, nil, "private slot lookup is not a public API")
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    local native = env.CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    local reparented
    native:AddAuraSlot("intrinsic", "HELPFUL", { candidateFilters = { includeSpellIDs = { [48108] = true } },
        initializeFrame = function(button) reparented = pcall(button.SetParent, button, left) end })
    equal(reparented, false, "intrinsic restriction also applies before the access-denial boundary")
    equal(pcall(native.AddAuraSlot, native, "intrinsic", "HELPFUL", {}), false)
    h.putAura(state, 48108, 30, 1, true)
    equal(h.procText(addon, state, left.entryId), "30.0")
    equal(h.procText(addon, state, right.entryId), "30.0", "same opaque Aura independently populates both regions")
    truthy(target.nativeBinding.enabled)
    local container = left.auraHandle.container
    truthy(container.nativeDynamicListening)
    left.auraHandle:SetEnabled(false)
    equal(container.nativeDynamicListening, false, "dynamic registration closes synchronously")
    truthy(container.nativeProviderSwitchRegistered, "bounded static provider listener survives disable")
    truthy(target.nativeBinding.enabled, "binding clear waits for the dirty pass")
    left:Hide(); state:nativeTick()
    truthy(target.nativeBinding.enabled, "hidden ancestor suspends native clear")
    left.auraHandle:SetEnabled(false)
    truthy(left:IsShown()); state:nativeTick()
    equal(target.nativeBinding.enabled, false)
    equal(h.procText(addon, state, right.entryId), "30.0", "independent region remains active")
end)

test("Proc repeated configurations talent changes toggles and spec cycles plateau after warmup", function()
    local _, addon, state = h.login(nil, false, { specID = 62, proc = {} })
    local function Cycle()
        for _, spec in ipairs({ 63, 64, 62 }) do
            state.specID = spec; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
            state:fire("TRAIT_CONFIG_UPDATED"); state:fire("PLAYER_TALENT_UPDATE"); state:fire("SPELLS_CHANGED")
            addon:ConfigureProc(); addon:ConfigureProc()
            truthy(addon:UpdateSettings({ proc = { enabled = false } }))
            state:nativeTick()
            for _, handle in pairs(addon.nativeAuraSlots) do
                if handle.procOwned then equal(handle.container.nativeDynamicListening, false) end
            end
            truthy(addon:UpdateSettings({ proc = { enabled = true } }))
        end
    end
    Cycle()
    local before = addon:GetProcDiagnosticSnapshot()
    local frames, bindings, slots = #state.frames, #state.bindings, #state.auraSlots
    for _ = 1, 30 do Cycle() end
    local after = addon:GetProcDiagnosticSnapshot()
    equal(#state.frames, frames); equal(#state.bindings, bindings); equal(#state.auraSlots, slots)
    for _, key in ipairs({ "wrapperFramesCreated", "containersCreated", "fontsCreated",
        "formattersCreated", "durationTemplatesCreated", "nativeInitializeCallbacks" }) do
        equal(after.counters[key], before.counters[key], key .. " remains bounded by warmed stable regions")
    end
    equal(after.stock.registeredContexts, 3); equal(after.stock.requestedActiveContexts, 1)
    equal(after.coreCallbacks, before.coreCallbacks)
    equal(after.safety.failures, 0); equal(#state.errors, 0)
end)

test("Proc wrapper failure is owned before styling and later settings cannot revive a partial region", function()
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local entry = copy(h.procFrame(addon, "mage_fire_hot_streak_left").reminderEntry)
    entry.id = "partial_wrapper_fixture"
    local create = env.CreateFrame
    local partial, original
    env.CreateFrame = function(kind, ...)
        local frame = create(kind, ...)
        if kind == "Frame" and not partial then
            partial, original = frame, frame.SetFrameStrata
            frame.SetFrameStrata = function() error("public wrapper setup failed") end
        end
        return frame
    end
    for _ = 1, 3 do addon:RunProcSafe("render", addon.AcquireAuraReminder, addon, entry, 48108) end
    truthy(addon:IsProcQuarantined())
    equal(addon.reminderFrames.nativeAura[entry.id], partial)
    equal(partial.auraHandle, nil)
    local frames = #state.frames
    addon:RefreshReminderPositions({ proc = { [entry.id] = true } })
    addon:RefreshReminderStyle("proc:MAGE:63")
    addon:ApplySettings(); state:fire("TRAIT_CONFIG_UPDATED")
    equal(#state.frames, frames); equal(partial.auraHandle, nil)
    truthy(addon.freeMoveTracking); truthy(addon:GetMobilityConfig().enabled)
    partial.SetFrameStrata = original
    truthy(addon:RetryProc())
    local reused = addon:AcquireAuraReminder(entry, 48108)
    equal(reused, partial); truthy(reused.auraHandle.slotReady)
end)

test("Proc shutdown attempts every owner and explicit retry cannot lie about cleanup", function()
    local _, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local left = h.procFrame(addon, "mage_fire_hot_streak_left")
    local original = left.auraHandle.container.SetEnabled
    left.auraHandle.container.SetEnabled = function() error("disable unavailable") end
    local free = h.procFrame(addon, "free_move_mage").auraHandle
    addon:QuarantineProc("stop")
    equal(addon:GetProcSafetyDiagnostics().cleanupComplete, false)
    for _, handle in pairs(addon.nativeAuraSlots) do
        if handle.procOwned and handle ~= left.auraHandle then equal(handle.enabled, false) end
    end
    truthy(free.enabled); truthy(free.container.nativeDynamicListening)
    local slots = #state.auraSlots
    for _ = 1, 12 do equal(addon:RetryProc(), false); addon:ApplySettings() end
    equal(#state.auraSlots, slots); truthy(addon:IsProcQuarantined())
    equal(addon.nativeAuraSlots[left.entryId], left.auraHandle)
    left.auraHandle.container.SetEnabled = original
    truthy(addon:RetryProc()); equal(#state.auraSlots, slots)
    equal(addon:GetProcSafetyDiagnostics().cleanupComplete, true)
    equal(#state.errors, 0)
end)

test("Proc slash retry is explicit and preserves the saved enabled preference", function()
    local _, addon = h.login(nil, false, { specID = 63, proc = {} })
    local saved = copy(addon.db)
    addon:QuarantineProc("render")
    addon:ConfigureProc(); addon:ApplySettings()
    truthy(addon:IsProcQuarantined()); same(addon.db, saved)
    addon:HandleSlashCommand("proc retry")
    truthy(not addon:IsProcQuarantined()); truthy(addon.procTracking); same(addon.db, saved)
end)

test("Proc unknown wrapper factory completion refuses retry without another allocation", function()
    local env, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local entry = copy(h.procFrame(addon, "mage_fire_hot_streak_left").reminderEntry)
    entry.id = "unknown_wrapper_fixture"
    local create, calls = env.CreateFrame, 0
    env.CreateFrame = function(kind, ...)
        local object = create(kind, ...)
        if kind == "Frame" then calls = calls + 1; error("wrapper allocated but no object returned") end
        return object
    end
    for _ = 1, 3 do addon:RunProcSafe("render", addon.AcquireAuraReminder, addon, entry, 48108) end
    truthy(addon:IsProcQuarantined()); equal(calls, 1)
    equal(addon.reminderFrames.nativeAura[entry.id], nil)
    local frames = #state.frames
    env.CreateFrame = create
    for _ = 1, 20 do equal(addon:RetryProc(), false) end
    equal(#state.frames, frames); truthy(addon:IsProcQuarantined())
    local safety = addon:GetProcSafetyDiagnostics()
    equal(safety.cleanupComplete, true, "public cleanup can succeed while allocation remains unrecoverable")
    equal(safety.reason, "reload-required")
end)

test("Proc event faults enter the same quarantine and catalog ApplySettings cannot restart it", function()
    local _, addon, state = h.login(nil, false, { specID = 63, proc = {} })
    local render = addon.RenderProcState
    addon.RenderProcState = function() error("injected internal event failure") end
    for _ = 1, 3 do state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity") end
    truthy(addon:IsProcQuarantined()); equal(addon:GetProcSafetyDiagnostics().failures, 3)
    equal(addon:GetEventDiagnostics().perEvent.SPELL_ACTIVATION_OVERLAY_SHOW, nil)
    addon.RenderProcState = render
    for _ = 1, 20 do
        addon:ApplySettings(); addon:ConfigureProc()
        for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do state:fire(event) end
    end
    truthy(addon:IsProcQuarantined()); equal(addon.procTracking, false)
    truthy(addon:RetryProc()); truthy(addon.procTracking)
    equal(#state.errors, 0, "only the Proc boundary contains these failures")
end)
