-- The Scale API names follow pinned Retail 12.1 SimpleAnimScale declarations.
-- This fixture verifies owned animation calls and lifecycle, not interpolation
-- or native overlay rendering. The shared smoke fixture must reject old names.
local h = ...
local test, equal, truthy = h.test, h.equal, h.truthy
local leftID = "warlock_demonology_demonic_core_left"
local rows = {
    { entrance = "none", active = "none", exit = "none" },
    { entrance = "scale", active = "pulse", exit = "scale" },
    { entrance = "pulse", active = "breathe", exit = "fade" },
    { entrance = "fade", active = "rotate", exit = "none" },
}

local function Fixture()
    local env, addon, state = h.login({ schemaVersion = 5, classes = {
        WARLOCK = { mobility = { enabled = false }, proc = {} },
    } }, false, { classToken = "WARLOCK", specID = 266, proc = {}, procKnown = { [267102] = true },
        mobility = { known = {}, spells = {} }, allowedSpellIDs = { [48020] = true } })
    local root, locations = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType
    root.overlaysInUse = {}
    function root:ShowOverlay(owner, textureID, position)
        local overlays = self.overlaysInUse[owner] or {}
        self.overlaysInUse[owner] = overlays
        if not overlays[position] then
            local texture = { alpha = 1 }
            function texture:SetAlpha(value) self.alpha = value end
            function texture:CreateAnimationGroup() error("Addon animations must not target a native texture") end
            overlays[position] = { spellID = owner, position = position, texture = texture }
        end
    end
    function root:ReleaseOverlay(overlay)
        self.overlaysInUse[overlay.spellID][overlay.position] = nil
    end
    truthy(addon:InstallProcArtworkHooks())
    local entry
    for _, candidate in ipairs(addon.procByRegion[leftID].regions) do
        if candidate.id == leftID then entry = candidate end
    end
    truthy(entry)
    local function Configure(settings)
        truthy(addon:SetProcRegionAppearance(entry, { mode = "custom", animation = {
            entrance = settings.entrance, active = settings.active, exit = settings.exit,
            speed = 1.25, intensity = .6, direction = "counterclockwise",
        } }))
    end
    local function Show()
        root:ShowOverlay(264173, 2888300, locations.Left, 1, 255, 255, 255)
        root:ShowOverlay(264173, 2888300, locations.Right, 1, 255, 255, 255)
        state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 264173, 2888300, locations.LeftRight, 1, 255, 255, 255)
        return assert(addon.procArtworkFrames and addon.procArtworkFrames[leftID])
    end
    return env, addon, state, Configure, Show
end

local function Healthy(addon, state)
    equal(addon:IsProcQuarantined(), false, "Supported animations must not isolate all Proc reminders")
    equal(addon:GetProcSafetyDiagnostics().failures, 0, "A swallowed animation API error is still a regression")
    equal(#state.errors, 0)
end

local function CheckGroup(frame, name, kind)
    local group = assert(frame.groups and frame.groups[name], "Expected owned animation group " .. name)
    equal(group.parent, frame.texture, "Animation belongs to the replacement texture")
    equal(group.animation.kind, kind)
    equal(group.animation.SetFromScale, nil, "The nonexistent historical method must remain absent")
    equal(group.animation.SetToScale, nil, "The nonexistent historical method must remain absent")
    if kind == "Scale" then
        equal(type(group.animation.SetScaleFrom), "function")
        equal(type(group.animation.SetScaleTo), "function")
    end
    truthy(group:IsPlaying())
    return group
end

local function Finish(group)
    local callback = assert(group:GetScript("OnFinished"))
    -- End the model's playback before delivering the native completion callback.
    group:Stop()
    callback(group)
end

local function EnterActive(frame, settings)
    if settings.entrance ~= "none" then
        equal(frame.phase, "entrance")
        Finish(CheckGroup(frame, "entrance_" .. settings.entrance,
            settings.entrance == "fade" and "Alpha" or "Scale"))
    end
    equal(frame.phase, "active")
    if settings.active ~= "none" then
        CheckGroup(frame, "active_" .. settings.active,
            settings.active == "rotate" and "Rotation" or settings.active == "breathe" and "Alpha" or "Scale")
    end
    truthy(frame:IsShown())
end

local function Remember(frame)
    local groups = {}
    for name, group in pairs(frame.groups or {}) do groups[name] = { group = group, animation = group.animation } end
    return groups
end

local function Reused(frame, remembered)
    for name, group in pairs(frame.groups or {}) do
        truthy(remembered[name], "Repeating presets must not create a new group identity")
        equal(group, remembered[name].group)
        equal(group.animation, remembered[name].animation)
    end
end

test("Proc animation contract Scale exposes only the actual Retail endpoint setters", function()
    local env = h.login(nil, false, { classToken = "UNKNOWN", specID = false })
    local animation = env.CreateFrame("Frame"):CreateAnimationGroup():CreateAnimation("Scale")
    equal(type(animation.SetScaleFrom), "function")
    equal(type(animation.SetScaleTo), "function")
    animation:SetScaleFrom(.5, .5)
    animation:SetScaleTo(1, 1)
    equal(animation.SetFromScale, nil)
    equal(animation.SetToScale, nil)
    equal(pcall(function() animation:SetFromScale(.5, .5) end), false,
        "Fixture must not silently accept the old nonexistent setter")
    equal(pcall(function() animation:SetToScale(1, 1) end), false)
end)

test("Proc animation contract live presets reach active and exit without faults and reuse owned groups", function()
    local _, addon, state, Configure, Show = Fixture()
    local remembered, warmedGroups
    for pass = 1, 2 do
        for _, settings in ipairs(rows) do
            Configure(settings)
            local frame = Show()
            EnterActive(frame, settings)
            state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 264173)
            if settings.exit ~= "none" then
                equal(frame.phase, "exit")
                Finish(CheckGroup(frame, "exit_" .. settings.exit, settings.exit == "fade" and "Alpha" or "Scale"))
            end
            equal(frame:IsShown(), false)
            Healthy(addon, state)
        end
        local frame = addon.procArtworkFrames[leftID]
        if pass == 1 then remembered, warmedGroups = Remember(frame), #state.animations
        else Reused(frame, remembered); equal(#state.animations, warmedGroups) end
    end
end)

test("Proc animation contract contextual preview shares valid entrance and active APIs with separate reusable groups", function()
    local _, addon, state, Configure = Fixture()
    h.options(addon)
    local remembered, warmedGroups
    for pass = 1, 2 do
        for _, settings in ipairs(rows) do
            Configure(settings)
            truthy(addon:SetPreview("single", leftID))
            local frame = assert(addon.procPreviewArtworkFrames and addon.procPreviewArtworkFrames[leftID])
            truthy(frame.previewOwned)
            equal(addon.procArtworkFrames, nil, "Preview does not allocate a live replacement")
            EnterActive(frame, settings)
            addon:StopPreview()
            equal(frame:IsShown(), false, "Preview stop cancels directly, without an exit animation")
            for _, group in pairs(frame.groups or {}) do equal(group:IsPlaying(), false) end
            Healthy(addon, state)
        end
        local frame = addon.procPreviewArtworkFrames[leftID]
        if pass == 1 then remembered, warmedGroups = Remember(frame), #state.animations
        else Reused(frame, remembered); equal(#state.animations, warmedGroups) end
    end
end)

test("Proc animation contract stale Scale phase callbacks cannot finish a newer live or stopped preview cycle", function()
    local _, addon, state, Configure, Show = Fixture()
    local settings = { entrance = "scale", active = "pulse", exit = "scale" }
    Configure(settings)
    local frame = Show()
    local oldEntrance = CheckGroup(frame, "entrance_scale", "Scale"):GetScript("OnFinished")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 264173)
    local oldExit = CheckGroup(frame, "exit_scale", "Scale"):GetScript("OnFinished")
    equal(Show(), frame)
    equal(frame.phase, "entrance")
    oldEntrance(); oldExit()
    equal(frame.phase, "entrance", "Previous completion callbacks cannot advance or hide the newer cycle")
    truthy(frame:IsShown())
    EnterActive(frame, settings)
    h.options(addon)
    truthy(addon:SetPreview("single", leftID))
    local preview = addon.procPreviewArtworkFrames[leftID]
    truthy(preview ~= frame and preview.groups.entrance_scale ~= frame.groups.entrance_scale)
    local previewFinished = preview.groups.entrance_scale:GetScript("OnFinished")
    local groups = #state.animations
    addon:StopPreview()
    previewFinished()
    equal(preview:IsShown(), false)
    equal(#state.animations, groups, "A late preview completion must not allocate active Scale groups")
    truthy(frame:IsShown(), "Stopping the sample preserves the live replacement")
    Healthy(addon, state)
end)
