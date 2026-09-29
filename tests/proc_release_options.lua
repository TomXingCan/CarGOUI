-- Release-facing checks intentionally use the unmodified production fixture.
-- Historical replacement behavior has a separate explicit development gate.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local regionID = "mage_fire_hot_streak_left"
local nativeGuide = "Native artwork stays under Blizzard control. CUI adds timers only. Saved Custom and Timer-only overrides are preserved but inactive; use Independent CUI for custom artwork."

local function Choose(control, value)
    if control.menu then control:Click() end
    for _, choice in ipairs(control.choices) do
        if choice.value == value and choice:IsShown() and choice:IsEnabled() then choice:Click(); return end
    end
    error("Unavailable release choice: " .. tostring(value))
end

local function Open(saved, locale)
    local env, addon, state = h.login(saved, false, { specID = 63, locale = locale or "enUS", proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" },
    } })
    equal(addon:IsProcLegacyReplacementAllowed(), false, "this suite cannot opt into historical replacement")
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    Choose(controls.procSelector, "48108"); Choose(controls.procEntry, regionID)
    local forbidden = function() error("release Options cannot change native Spell Alert preferences") end
    env.SetCVar, env.C_CVar.SetCVar = forbidden, forbidden
    return env, addon, state, panel, controls, addon:GetSelectedProcColorEntry()
end

local function NativeOnly(addon, panel, controls)
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(controls.procPresentationPolicy.value, "replacement")
    equal(controls.procPresentationPolicy.choices[1]:GetText(), addon:Text("Native artwork"))
    equal(#controls.procPresentationPolicy.choices, 2)
    equal(panel.procDisplaySection:IsShown(), false)
    equal(controls.procArt_mode:IsShown(), false); truthy(controls.procArt_mode.disabled)
    equal(controls.procArtReset:IsEnabled(), false)
    for _, choice in ipairs(controls.procArt_mode.choices) do equal(choice:IsEnabled(), false) end
    for _, section in ipairs({ panel.procArtworkSection, panel.procTransformSection,
        panel.procAnimationSection, panel.procAdvancedSection }) do equal(section:IsShown(), false) end
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    truthy(controls.procAppearance:IsEnabled()); truthy(controls.procPositionX:IsEnabled())
    equal(controls.procArtColor:IsEnabled(), false)
    truthy(panel.procNativePolicyGuide:IsShown())
    equal(panel.procNativePolicyGuide:GetText(), addon:Text(nativeGuide))
end

test("Proc release Options defaults to Native artwork plus Timer without replacement controls", function()
    local _, addon, state, panel, controls, entry = Open()
    NativeOnly(addon, panel, controls)
    equal(addon:GetProcRegionAppearance(entry).mode, "native")
    equal(addon:IsProcArtworkEditable(entry), false)
    equal(controls.procIndependentArtworkEnabled:IsShown(), false)
    equal(controls.procIndependentArtworkEnabled.label:IsShown(), false)
    equal(controls.procIndependentRegion:IsShown(), false)
    equal(controls.procIndependentRegion.label:IsShown(), false)
    local before = copy(addon.db)
    for _, choice in ipairs(controls.procArt_mode.choices) do choice:GetScript("OnClick")(choice) end
    controls.procArtReset:GetScript("OnClick")(controls.procArtReset)
    same(addon.db, before, "late hidden callbacks cannot activate or clear saved overrides")
    equal(#state.errors, 0)
end)

test("Proc release Options preserves old Custom and Timer-only saves while preview uses native defaults", function()
    for _, mode in ipairs({ "custom", "timer" }) do
        local _, seed = h.login(nil, false, { specID = 63, proc = {} })
        equal(seed:IsProcLegacyReplacementAllowed(), false)
        seed:GetProcConfig().regions[regionID] = { appearance = {
            mode = mode, alpha = .25, scale = 1.5, artColor = { r = .2, g = .4, b = .6 },
            animation = { entrance = "scale", active = "pulse", exit = "fade" },
        } }
        local _, addon, state, panel, controls, entry = Open(copy(seed.db))
        local before = copy(addon:GetProcRegionAppearance(entry))
        NativeOnly(addon, panel, controls)
        equal(before.mode, mode); equal(before.alpha, .25)
        controls.procPreview:Click()
        equal(panel.activeCategory, "proc")
        local sample = assert(addon.procPreviewArtworkFrames[regionID])
        truthy(sample:IsShown()); equal(sample.alpha, 1)
        same(sample.texture.vertexColor, { 1, 1, 1 })
        equal(sample.phase, "active")
        same(addon:GetProcRegionAppearance(entry), before)
        controls.procStop:Click(); same(addon:GetProcRegionAppearance(entry), before)
        equal(#state.errors, 0)
    end
end)

test("Proc release Options retains independent region style and explicit preview with live artwork disabled", function()
    local env, addon, state, panel, controls, entry = Open()
    Choose(controls.procPresentationPolicy, "independent")
    truthy(panel.procDisplaySection:IsShown()); equal(controls.procArt_mode:IsShown(), false)
    equal(panel.procNativePolicyGuide:IsShown(), false)
    truthy(panel.procPolicyGuide:IsShown()); truthy(panel.procPolicyWarning:IsShown())
    controls.procIndependentRegion:Click()
    truthy(panel.procArtworkSection:IsShown()); truthy(panel.procTransformSection:IsShown())
    truthy(panel.procAnimationSection:IsShown()); truthy(panel.procAdvancedSection:IsShown())
    truthy(controls.procArtColor:IsEnabled())
    controls.procIndependentArtworkEnabled:Click()
    equal(addon:GetProcConfig().independentArtworkEnabled, false)
    local row = controls.procArt_alpha
    row.valueButton:Click(); row.editBox:SetText("37.5")
    row.editBox:GetScript("OnTextChanged")(row.editBox, true)
    row.editBox:GetScript("OnEnterPressed")(row.editBox)
    controls.procArtColor:Click(); state:pickerChange(.2, .4, .6)
    env.ColorPickerFrame.Footer.OkayButton:Click()
    controls.procPreview:Click()
    local sample = assert(addon.procPreviewArtworkFrames[regionID])
    truthy(sample:IsShown()); equal(sample.alpha, .375)
    same(sample.texture.vertexColor, { .2, .4, .6 })
    equal(addon:GetProcRegionAppearance(entry).mode, "native", "independent edits do not rewrite the legacy mode")
    local before = copy(addon:GetProcRegionAppearance(entry))
    Choose(controls.procPresentationPolicy, "replacement")
    NativeOnly(addon, panel, controls); same(addon:GetProcRegionAppearance(entry), before)
    Choose(controls.procPresentationPolicy, "independent")
    truthy(controls.procIndependentRegion:GetChecked())
    equal(controls.procIndependentArtworkEnabled:GetChecked(), false)
    same(addon:GetProcRegionAppearance(entry), before)
    equal(#state.errors, 0)
end)

test("Proc release Options reserves native guidance and timer cards in every supported locale", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU" }) do
        local _, addon, state, panel, controls = Open(nil, locale)
        NativeOnly(addon, panel, controls)
        equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
        local guide = panel.procNativePolicyGuide
        local _, _, _, x, y = guide:GetPoint()
        equal(x, 0); equal(guide:GetWidth(), 616); truthy(guide.wordWrap)
        truthy(-y >= 58, "native guidance starts after the strategy selector")
        truthy(-y + guide:GetHeight() <= panel.procPolicySection:GetHeight() - 52)
        local bottom = 0
        for _, card in ipairs({ panel.procContextSection, panel.procPolicySection,
            panel.procTimerSection, panel.procPositionSection }) do
            local _, _, _, _, cardY = card:GetPoint()
            truthy(cardY <= bottom, "release cards do not overlap")
            bottom = cardY - card:GetHeight()
        end
        truthy(panel.procEditor:GetHeight() >= -bottom)
        equal(#state.errors, 0)
    end
end)
