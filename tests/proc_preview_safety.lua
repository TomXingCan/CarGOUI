local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open()
    local env, addon, state = h.mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20 }, { specID = 62, proc = {} })
    local panel, controls = h.options(addon)
    return env, addon, state, panel, controls
end

local function Samples(addon, kind)
    local result = {}
    for id, frame in pairs(addon.previewFrames) do
        if frame.reminderEntry and frame.reminderEntry.kind == kind then result[id] = frame end
    end
    return result
end

local function Hidden(frames)
    for _, frame in pairs(frames) do
        equal(frame:IsShown(), false)
        if frame.guidance then equal(frame.guidance:IsShown(), false) end
    end
end

test("Proc preview safety quarantined contextual tests cannot allocate Proc but Mobility remains testable", function()
    local _, addon, state, panel, controls = Open()
    addon:SelectOptionsCategory("mobility"); controls.mobilityPreview:Click()
    local mobilityID = addon.previewState.entryId
    local mobility = addon.previewFrames[mobilityID]
    addon:QuarantineProc("preview")
    local saved, before = copy(addon.db), addon:GetProcDiagnosticSnapshot().counters
    addon:SelectOptionsCategory("proc"); controls.procPreview:Click()
    equal(panel.activeCategory, "proc"); equal(addon.previewState.mode, "single")
    equal(addon.previewState.entryId, mobilityID); truthy(mobility:IsShown())
    for _, entry in ipairs(addon:GetPreviewEntries()) do
        if entry.kind == "proc" then equal(addon.previewFrames[entry.id], nil) end
    end
    equal(addon.procPreviewArtworkFrames, nil)
    addon:SelectOptionsCategory("general"); controls.generalTest:Click()
    equal(panel.activeCategory, "general"); equal(addon.previewState.mode, "all")
    truthy(mobility:IsShown()); equal(next(Samples(addon, "proc")), nil)
    local after = addon:GetProcDiagnosticSnapshot().counters
    equal(after.previewArtworkFramesCreated, before.previewArtworkFramesCreated)
    equal(after.previewArtworkTexturesCreated, before.previewArtworkTexturesCreated)
    same(addon.db, saved); equal(#state.errors, 0)
end)

test("Proc preview safety quarantine clears existing Proc samples without changing all-context Mobility", function()
    local _, addon, _, panel, controls = Open()
    controls.generalTest:Click()
    local proc, mobility = Samples(addon, "proc"), Samples(addon, "mobility")
    truthy(next(proc)); truthy(next(mobility))
    for _, frame in pairs(proc) do truthy(frame:IsShown()) end
    local mode, entry = addon.previewState.mode, addon.previewState.entryId
    addon:QuarantineProc("preview")
    equal(addon.previewState.mode, mode); equal(addon.previewState.entryId, entry)
    Hidden(proc)
    for _, frame in pairs(mobility) do truthy(frame:IsShown()) end
    for _, frame in pairs(addon.procPreviewArtworkFrames or {}) do
        equal(frame:IsShown(), false)
        for _, group in pairs(frame.groups or {}) do equal(group:IsPlaying(), false) end
    end
    local before = addon:GetProcDiagnosticSnapshot().counters
    for _ = 1, 12 do addon:RefreshPreview(true) end
    Hidden(proc)
    equal(addon:GetProcDiagnosticSnapshot().counters.previewArtworkFramesCreated, before.previewArtworkFramesCreated)
    equal(panel:IsShown(), true)
    controls.generalStop:Click(); equal(addon.previewState.mode, "off"); Hidden(mobility)
end)

test("Proc preview safety failures are bounded and cannot stop a Mobility sample or poison Options", function()
    local _, addon, state, panel, controls = Open()
    local render, failures = addon.RenderReminder, 0
    addon.RenderReminder = function(self, frame, entry, ...)
        if entry.kind == "proc" then failures = failures + 1; error(h.secret("opaque preview failure")) end
        return render(self, frame, entry, ...)
    end
    local saved = copy(addon.db)
    for _ = 1, 10 do controls.generalTest:Click() end
    equal(failures, 3); truthy(addon:IsProcQuarantined())
    equal(addon:GetProcSafetyDiagnostics().failures, 3)
    equal(panel:IsShown(), true); equal(panel.activeCategory, "general")
    local mobility = Samples(addon, "mobility")
    truthy(next(mobility)); for _, frame in pairs(mobility) do truthy(frame:IsShown()) end
    for _, frame in pairs(addon.previewFrames) do
        if frame.previewKind == "proc" then equal(frame:IsShown(), false) end
    end
    same(addon.db, saved); equal(#state.errors, 0)
end)

test("Proc preview safety cleanup aggregates Proc failures and leaves unrelated preview errors unchanged", function()
    local _, addon, _, _, controls = Open()
    controls.generalTest:Click()
    local proc = Samples(addon, "proc")
    local _, broken = next(proc)
    local hide = broken.Hide
    broken.Hide = function() error("owned Proc Hide failure") end
    equal(addon:StopProcPreview(), false)
    for _, frame in pairs(proc) do
        if frame ~= broken then equal(frame:IsShown(), false) end
        if frame.guidance then equal(frame.guidance:IsShown(), false) end
    end
    for _, frame in pairs(Samples(addon, "mobility")) do truthy(frame:IsShown()) end
    broken.Hide = hide; truthy(addon:StopProcPreview())
    local before, render = addon:GetProcSafetyDiagnostics().failures, addon.RenderReminder
    addon.RenderReminder = function(self, frame, entry, ...)
        if entry.kind == "mobility" then error("unrelated Mobility error") end
        return render(self, frame, entry, ...)
    end
    local ok, message = pcall(addon.SetPreview, addon, "single", addon:GetMobilityEntry().id)
    equal(ok, false); truthy(message:find("unrelated Mobility error", 1, true))
    equal(addon:GetProcSafetyDiagnostics().failures, before, "Proc boundary never absorbs a foreign subsystem error")
end)

test("Proc preview safety incomplete frame and guidance factories never allocate again across explicit retries", function()
    for _, stage in ipairs({ "frame", "sample-font", "guidance", "guidance-font", "guidance-mark" }) do
        local env, addon, state, panel = Open()
        local id = panel.selectedProcEntry
        local create = env.CreateFrame
        env.CreateFrame = function(kind, name, parent, ...)
            local frame = create(kind, name, parent, ...)
            if kind == "Frame" and name == nil and parent == env.UIParent then
                if stage == "frame" then error("factory allocated before failing") end
                if stage == "sample-font" then
                    local font = frame.CreateFontString
                    frame.CreateFontString = function(self, ...)
                        font(self, ...); error("sample font allocated before failing")
                    end
                end
            elseif kind == "Frame" and parent and parent.previewKind == "proc" then
                if stage == "guidance" then error("guidance allocated before failing") end
                if stage == "guidance-font" then
                    local font = frame.CreateFontString
                    frame.CreateFontString = function(self, ...)
                        font(self, ...); error("guidance font allocated before failing")
                    end
                elseif stage == "guidance-mark" then
                    local texture = frame.CreateTexture
                    frame.CreateTexture = function(self, ...)
                        texture(self, ...); error("guidance mark allocated before failing")
                    end
                end
            end
            return frame
        end
        local function Resources()
            return { #state.frames, #state.textures, #state.fontStrings, #state.animations }
        end
        addon:SetPreview("single", id)
        local first = Resources()
        for _ = 1, 5 do addon:SetPreview("single", id) end
        truthy(addon:IsProcQuarantined(), stage)
        same(Resources(), first, stage .. " failure does not allocate another partial resource")
        for _ = 1, 4 do
            equal(addon:GetProcPreviewRetryBlocker(), "reload-required")
            equal(addon:RetryProc(), false, "known partial preview resources require Reload before unlocking")
            for _ = 1, 3 do addon:SetPreview("single", id) end
            truthy(addon:IsProcQuarantined())
            same(Resources(), first, stage .. " explicit retry cannot bypass the allocation latch")
        end
        local frame = addon.previewFrames[id]
        if frame then
            equal(frame:IsShown(), false)
            if frame.guidance then equal(frame.guidance:IsShown(), false) end
        end
        equal(#state.errors, 0, "Proc errors remain in the local failure boundary")
    end
end)

test("Proc preview safety partial and quarantined samples do not block saved position and typography edits", function()
    local _, addon, state, panel, controls = Open()
    addon:SelectOptionsCategory("proc"); controls.procPreview:Click()
    local id, entry = panel.selectedProcEntry, addon:GetSelectedProcColorEntry()
    local frame = addon.previewFrames[id]
    frame.procGuidanceAttempted, frame.guidance.procGuidanceReady = true, false
    frame.text.GetStringWidth = function() error("partial sample cannot be measured") end
    truthy(addon:UpdateSettings({ reminders = { [id] = { position = { x = 31, y = -18 } } } }))
    equal(addon:GetReminderPosition(entry).x, 31)
    addon:QuarantineProc("preview")
    truthy(addon:UpdateReminderStyle(addon:GetReminderStyleKey(entry), { font = { size = 38 } }))
    truthy(addon:UpdateSettings({ reminders = { [id] = { position = { x = 77, y = -25 } } } }))
    addon:RefreshReminderFonts()
    equal(addon:GetReminderStyle(entry).font.size, 38); equal(addon:GetReminderPosition(entry).x, 77)
    equal(panel:IsShown(), true); equal(#state.errors, 0)
end)

test("Proc preview safety direct Stop records one failed Proc cleanup without swallowing Mobility work", function()
    local _, addon, _, _, controls = Open()
    controls.generalTest:Click()
    local _, frame = next(Samples(addon, "proc"))
    local hide = frame.Hide
    frame.Hide = function() error("Proc hide failed") end
    local before = addon:GetProcSafetyDiagnostics().failures
    addon:StopPreview(true)
    equal(addon:GetProcSafetyDiagnostics().failures, before + 1)
    equal(addon.previewState.mode, "off")
    Hidden(Samples(addon, "mobility"))
    frame.Hide = hide; truthy(addon:StopProcPreview())
end)
