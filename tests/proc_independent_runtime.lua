-- Real public captures are replayed as ordered inputs, never as a new client run.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local left, right = "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right"
local top = "mage_arcane_overpowered_missiles_top"

local function Fixture(spec)
    local env, addon, state = h.login(nil, false, { specID = spec or 62, proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" } } })
    local config = addon:GetProcConfig()
    config.presentationPolicy = "independent"
    for _, definition in ipairs(addon:GetProcDefinitions()) do for _, entry in ipairs(definition.regions) do
        config.regions[entry.id] = { independentArtworkEnabled = true, appearance = { mode = "native" } }
    end end
    addon:ConfigureProc()
    local function Forbidden() error("independent runtime touched a native graphic or CVar writer") end
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end }, { __index = Forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = Forbidden, Forbidden, Forbidden
    return env, addon, state
end

test("Independent runtime preserves bootstrap duration bindings and public HIDE gates at zero preferences", function()
    local env, addon, state = Fixture()
    h.putAura(state, 263725, 30, 1, true)
    equal(h.procText(addon, state, left), "30.0"); equal(h.procText(addon, state, right), "30.0")
    equal(h.procFrame(addon, left).alpha, 1)
    equal(addon.procArtworkFrames, nil, "bootstrap is not a fabricated graphical SHOW")
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    truthy(addon.procArtworkFrames[left]:IsShown()); truthy(addon.procArtworkFrames[right]:IsShown())
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    equal(h.procText(addon, state, left), ""); equal(h.procFrame(addon, left).alpha, 0)
    truthy(not addon.procArtworkFrames[left]:IsShown())
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    equal(h.procText(addon, state, left), "30.0")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277420)
    equal(h.procText(addon, state, right), "")
    equal(#state.errors, 0); equal(addon:GetProcSafetyDiagnostics().failures, 0)
end)

test("Independent MAGE saved zero startup renders the first observed owner without Options", function()
    local _, saved = Fixture()
    local env, addon, state = h.setup(h.copy(saved.db), false, { specID = 62, proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" } } })
    local function Forbidden() error("cold startup accessed native graphical lifecycle") end
    env.SpellActivationOverlayFrame = setmetatable({ GetEffectiveScale = function() return 1 end }, { __index = Forbidden })
    env.hooksecurefunc, env.SetCVar, env.C_CVar.SetCVar = Forbidden, Forbidden, Forbidden
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    truthy(addon:IsProcIndependentPolicy()); equal(addon.procArtworkFrames, nil)
    h.putAura(state, 263725, 25, 1, true)
    equal(h.procText(addon, state, left), "25.0")
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    truthy(addon.procArtworkFrames[left]:IsShown()); equal(addon.procArtworkFrames[left].alpha, 1)
    equal(#state.errors, 0)
end)

test("Independent strategy entry while a buff exists clears old intent and cannot borrow Preview SHOW", function()
    local env, addon, state = h.login(nil, false, { specID = 62, proc = {} })
    h.putAura(state, 263725, 25, 1, true)
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    local entry = h.procFrame(addon, left).reminderEntry
    truthy(addon:GetProcRegionOverlayState(entry).shown)
    state.proc.cvars.displaySpellActivationOverlays = false
    state.proc.cvars.spellActivationOverlayOpacity = "0"
    truthy(addon:UpdateSettings({ proc = { presentationPolicy = "independent",
        regions = { [left] = { independentArtworkEnabled = true } } } }))
    equal(addon:GetProcRegionOverlayState(entry), nil)
    equal(h.procText(addon, state, left), "25.0", "exact-aura native bootstrap remains allowed")
    equal(addon.procArtworkFrames, nil)
    h.options(addon); truthy(addon:SetPreview("single", left))
    truthy(addon.procPreviewArtworkFrames[left]:IsShown())
    addon:StopPreview()
    equal(addon:GetProcRegionOverlayState(entry), nil); equal(addon.procArtworkFrames, nil)
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    truthy(addon.procArtworkFrames[left]:IsShown()); equal(#state.errors, 0)
end)

test("Independent artwork switches leave timer bindings and Free Move untouched", function()
    local env, addon, state = Fixture()
    h.putAura(state, 263725, 30, 1, true); h.putAura(state, 375240, 10, 1, true)
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    local timer, free = h.procFrame(addon, left), h.procFrame(addon, "free_move_mage")
    local binding, freeBinding = timer.auraHandle, free.auraHandle
    local api = addon:GetProcDiagnosticSnapshot().api
    local enabled, disabled = api.SetEnabledTrue.requested, api.SetEnabledFalse.requested
    local slots, bindings = #state.auraSlots, #state.bindings
    for _ = 1, 6 do
        truthy(addon:UpdateSettings({ proc = { independentArtworkEnabled = false } }))
        equal(h.procText(addon, state, left), "30.0"); equal(timer.alpha, 1)
        truthy(not addon.procArtworkFrames[left]:IsShown())
        truthy(addon:UpdateSettings({ proc = { independentArtworkEnabled = true } }))
        truthy(addon.procArtworkFrames[left]:IsShown())
    end
    truthy(addon:UpdateSettings({ proc = { regions = { [left] = { independentArtworkEnabled = false } } } }))
    truthy(not addon.procArtworkFrames[left]:IsShown()); truthy(addon.procArtworkFrames[right]:IsShown())
    equal(timer.auraHandle, binding); equal(free.auraHandle, freeBinding)
    equal(h.procText(addon, state, "free_move_mage"), "Free move")
    equal(#state.auraSlots, slots); equal(#state.bindings, bindings)
    api = addon:GetProcDiagnosticSnapshot().api
    equal(api.SetEnabledTrue.requested, enabled); equal(api.SetEnabledFalse.requested, disabled)
    equal(#state.errors, 0)
end)

test("Independent runtime retains event-only bootstrap and validates all SHOW identities", function()
    local env, addon, state = Fixture(63)
    local id = "mage_fire_fury_sun_king_top"
    h.putAura(state, 383883, 20, 1, true)
    equal(h.procFrame(addon, id).auraHandle.enabled, false)
    equal(h.procText(addon, state, id), "")
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", h.secret(383883), 457658, env.Enum.ScreenLocationType.Top, .7, 255, 255, 255)
    h.showProc(env, state, 383883, 449490, "Top", .7)
    h.showProc(env, state, 383883, 457658, "Left", .7)
    equal(h.procFrame(addon, id).auraHandle.enabled, false)
    h.showProc(env, state, 383883, 457658, "Top", .7)
    equal(h.procText(addon, state, id), "20.0")
    equal(addon.procArtworkFrames, nil, "historical event-only entry gains no selectable artwork scope")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 383883)
    equal(h.procFrame(addon, id).auraHandle.enabled, false)
    equal(#state.errors, 0); equal(addon:GetProcSafetyDiagnostics().failures, 0)
end)

test("Independent runtime latest public source wins and old owner HIDE cannot close a new source", function()
    local env, addon, state = Fixture()
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    h.showProc(env, state, 1277422, 1027133, "LeftRight")
    equal(addon.procArtworkFrames[left].texture.texture, 1027133)
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277420)
    truthy(addon.procArtworkFrames[left]:IsShown()); equal(addon.procArtworkFrames[left].texture.texture, 1027133)
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277422)
    truthy(not addon.procArtworkFrames[left]:IsShown())
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    h.showProc(env, state, 1277421, 1027132, "LeftRight")
    equal(addon.procArtworkFrames[left].texture.texture, 1027132)
    equal(#state.errors, 0)
end)

test("Independent quarantine blocks automatic restart and explicit Retry needs a fresh public SHOW", function()
    local env, addon, state = Fixture()
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    local art, count = addon.procArtworkFrames[left], #state.auraSlots
    local db = h.copy(addon.db)
    addon:QuarantineProc("artwork")
    for _ = 1, 4 do
        addon:ConfigureProc(); addon:ApplySettings()
        state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity")
        state:fire("PLAYER_TALENT_UPDATE")
        h.showProc(env, state, 1277420, 1027131, "LeftRight")
    end
    truthy(addon:IsProcQuarantined()); truthy(not art:IsShown())
    equal(h.procFrame(addon, left).auraHandle.enabled, false); same(addon.db, db)
    truthy(addon:RetryProc()); truthy(not art:IsShown())
    h.showProc(env, state, 1277420, 1027131, "LeftRight")
    truthy(art:IsShown()); equal(#state.auraSlots, count)
    local notices = #state.messages
    for _ = 1, 30 do addon:NotifyProcIndependentArtwork("renderer-failed") end
    equal(#state.messages, notices, "manual recovery notices use bounded session categories")
    equal(next(addon.procSuppressedOverlays or {}), nil); equal(#state.errors, 0)
end)

test("Independent stop and quarantine finish resource cleanup even when chat output throws", function()
    for _, quarantine in ipairs({ false, true }) do
        local env, addon, state = Fixture()
        h.showProc(env, state, 1277420, 1027131, "LeftRight")
        addon.Print = function() error("chat unavailable") end
        if quarantine then
            -- The existing quarantine chat report may throw after cleanup;
            -- the new manual-recovery notice must not move that failure earlier.
            equal(pcall(addon.QuarantineProc, addon, "artwork"), false)
            truthy(addon:GetProcSafetyDiagnostics().cleanupComplete)
        else truthy(addon:StopProc()) end
        equal(addon.procTracking, false); truthy(not addon.procArtworkFrames[left]:IsShown())
        equal(h.procFrame(addon, left).auraHandle.enabled, false)
        h.showProc(env, state, 1277420, 1027131, "LeftRight")
        truthy(not addon.procArtworkFrames[left]:IsShown()); equal(#state.errors, 0)
    end
end)

local captures = assert(loadfile(h.testRoot .. "/proc_public_event_fixture.lua"))()
for _, label in ipairs({ "A", "B" }) do
    test("Independent ordered author " .. label .. " capture replay preserves inputs without native objects", function()
        local env, addon, state = Fixture()
        -- Only these three public enum values occur in the supplied 69933 data.
        -- Reassign other synthetic harness values to avoid numeric collisions.
        for key, value in pairs(env.Enum.ScreenLocationType) do env.Enum.ScreenLocationType[key] = value + 100 end
        env.Enum.ScreenLocationType.Top, env.Enum.ScreenLocationType.LeftRight, env.Enum.ScreenLocationType.LeftRightOutside = 3, 9, 11
        local shows, first, last, owners = 0, nil, nil, {}
        for _, row in ipairs(captures[label]) do
            state.proc.cvars.displaySpellActivationOverlays = row.display == "1"
            state.proc.cvars.spellActivationOverlayOpacity = row.opacity
            -- CVar rows precede each recorded callback logically. This does not
            -- reproduce unknown scheduling or duplicate-HIDE timing intervals.
            for _ = 1, row.count do state:fire(row.event, unpack(row.args)) end
            if row.event == "SPELL_ACTIVATION_OVERLAY_SHOW" then
                shows, first, last = shows + 1, first or row.time, row.time
                owners[row.args[1]] = (owners[row.args[1]] or 0) + 1
                local definition = addon.procByOverlay[row.args[1]][1].definition
                for _, region in ipairs(definition.regions) do
                    equal(addon:GetProcRegionOverlayState(region).shown, true, "accepted state ignores stock display setting")
                    equal(h.procFrame(addon, region.id).auraHandle.enabled, true)
                    equal(h.procFrame(addon, region.id).alpha, 1)
                    local art = addon.procArtworkFrames and addon.procArtworkFrames[region.id]
                    if label == "B" then
                        equal(row.display, "0"); equal(row.opacity, "0")
                        truthy(art and art:IsShown(), "first and subsequent B SHOW draw immediately")
                        equal(art.texture.texture, row.args[2]); equal(art.alpha, 1)
                    else
                        truthy(not art or not art:IsShown(), "A leaves native settings alone and pauses independent artwork")
                    end
                end
            end
        end
        equal(shows, label == "A" and 55 or 16)
        if label == "B" then
            truthy(first > 6.616); truthy(last > 58)
            same(owners, { [1277420] = 11, [1277009] = 5 })
        end
        equal(addon:GetProcSafetyDiagnostics().failures, 0); equal(#state.errors, 0)
        equal(next(addon.procSuppressedOverlays or {}), nil)
        local api = addon:GetProcDiagnosticSnapshot().api
        equal(api.SuppressNativeAlpha.requested, 0); equal(api.RestoreNativeAlpha.requested, 0)
    end)
end
