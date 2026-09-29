local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local id = "warlock_demonology_demonic_core_left"

local function Fixture()
    local env, addon, state = h.login(nil, false, { classToken = "WARLOCK", specID = 266,
        proc = {}, procKnown = { [267102] = true }, allowedSpellIDs = { [48020] = true },
        mobility = { known = {}, spells = {} } })
    local root, location = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType
    root.overlaysInUse = {}
    function root:ShowOverlay(owner, texture, position)
        self.overlaysInUse[owner] = self.overlaysInUse[owner] or {}
        local list = self.overlaysInUse[owner]
        if not list[position] then
            local owned = { alpha = 1, writes = 0 }
            function owned:SetAlpha(value) self.alpha = value; self.writes = self.writes + 1 end
            function owned:GetAlpha() error("Native alpha readback is forbidden") end
            list[position] = { spellID = owner, position = position, texture = owned }
        end
    end
    function root:ReleaseOverlay(overlay) self.overlaysInUse[overlay.spellID][overlay.position] = nil end
    truthy(addon:InstallProcArtworkHooks())
    local entry
    for _, region in ipairs(addon.procByRegion[id].regions) do if region.id == id then entry = region end end
    truthy(addon:SetProcRegionAppearance(entry, { mode = "custom",
        animation = { entrance = "scale", active = "pulse", exit = "scale" } }))
    root:ShowOverlay(264173, 2888300, location.Left, 1, 255, 128, 64)
    root:ShowOverlay(264173, 2888300, location.Right, 1, 255, 128, 64)
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 264173, 2888300, location.LeftRight, 1, 255, 128, 64)
    h.options(addon)
    truthy(addon:SetPreview("single", id))
    local function Numeric(patch)
        return addon:SetProcRegionAppearance(entry, patch, { skipOptionsRefresh = true, continuousAppearance = true })
    end
    return addon, state, entry, root.overlaysInUse[264173][location.Left],
        addon.procArtworkFrames[id], addon.procPreviewArtworkFrames[id], Numeric, root
end

local function Finish(group)
    group:Stop(); group:GetScript("OnFinished")(group)
end

test("Proc numeric artwork edits retain live and preview entrance ownership without new callbacks or resources", function()
    local addon, state, _, native, live, preview, Numeric = Fixture()
    local group, sample = live.groups.entrance_scale, preview.groups.entrance_scale
    local finished, sampleFinished = group:GetScript("OnFinished"), sample:GetScript("OnFinished")
    local plays, samplePlays, writes = group.plays, sample.plays, native.texture.writes
    local frames, textures, groups = #state.frames, #state.textures, #state.animations
    local before = addon:GetProcDiagnosticSnapshot().counters
    addon.RefreshOptions = function() error("Numeric edits must not rebuild the Options controls") end
    for index = 1, 30 do
        local value = index / 100
        truthy(Numeric({ alpha = value, desaturation = value, scale = 1 + value,
            width = 1 + value, height = 1 + value, rotation = -index, offset = { x = -index, y = index },
            animation = { speed = 1 + value, intensity = value } }))
        equal(live.phase, "entrance"); equal(preview.phase, "entrance")
        equal(live.alpha, value); equal(preview.alpha, value)
        equal(native.texture.alpha, 0); equal(native.texture.writes, writes)
        equal(group.plays, plays); equal(sample.plays, samplePlays)
        equal(group:GetScript("OnFinished"), finished); equal(sample:GetScript("OnFinished"), sampleFinished)
    end
    equal(#state.frames, frames); equal(#state.textures, textures); equal(#state.animations, groups)
    local after = addon:GetProcDiagnosticSnapshot().counters
    for _, key in ipairs({ "configureCalls", "wrapperFramesCreated", "containersCreated", "fontsCreated",
        "artworkFramesCreated", "animationGroupsCreated", "animationsCreated" }) do equal(after[key], before[key], key) end
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
    Finish(group); Finish(sample)
    equal(live.phase, "active"); equal(preview.phase, "active")
end)

test("Proc numeric animation speed and intensity update existing active pulse endpoints immediately", function()
    local addon, _, _, native, live, preview, Numeric = Fixture()
    Finish(live.groups.entrance_scale); Finish(preview.groups.entrance_scale)
    local pulse, sample = live.groups.active_pulse, preview.groups.active_pulse
    local plays, samplePlays = pulse.plays, sample.plays
    truthy(Numeric({ animation = { speed = 2, intensity = .8 } }))
    equal(pulse.animation.duration, .6); equal(sample.animation.duration, .6)
    same(pulse.animation.toScale, { 1.2, 1.2 }); same(sample.animation.toScale, { 1.2, 1.2 })
    equal(pulse.plays, plays); equal(sample.plays, samplePlays)
    equal(live.phase, "active"); equal(native.texture.alpha, 0)
    equal(addon:GetProcSafetyDiagnostics().failures, 0)
end)

test("Proc numeric hint cannot bypass mode or reset cleanup", function()
    local addon, _, entry, native, live, _, Numeric = Fixture()
    truthy(Numeric({ mode = "native" }))
    equal(native.texture.alpha, 1); truthy(not live:IsShown())
    truthy(Numeric({ mode = "custom", assetKey = "blizzard_449493" }))
    equal(native.texture.alpha, 0); equal(live.texture.texture, 449493)
    truthy(addon:UpdateSettings({ proc = { regions = { [entry.id] = { appearance = false } } } },
        { skipOptionsRefresh = true, continuousAppearance = true }))
    equal(native.texture.alpha, 1); truthy(not live:IsShown())
    equal(addon:GetProcRegionAppearance(entry).mode, "native")
end)

test("Proc numeric changes cancel a hidden exit without exposing its native fade or restarting quarantine", function()
    local addon, state, _, native, live, _, Numeric, root = Fixture()
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 264173)
    local exit = live.groups.exit_scale:GetScript("OnFinished")
    truthy(Numeric({ alpha = .4 }))
    truthy(not live:IsShown()); equal(native.texture.alpha, 0)
    exit(); equal(native.texture.alpha, 0)
    root:ReleaseOverlay(native); equal(native.texture.alpha, 1)
    addon:QuarantineProc("artwork")
    truthy(Numeric({ scale = 1.3 }))
    truthy(addon:IsProcQuarantined()); truthy(not live:IsShown())
    equal(next(addon.procSuppressedOverlays), nil)
end)
