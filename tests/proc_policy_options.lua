-- Widget and transaction checks do not establish native event delivery or
-- localized glyph fit. Independent Preview is an explicitly requested sample.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local leftID, rightID = "mage_fire_hot_streak_left", "mage_fire_hot_streak_right"

local function Choose(control, value)
    if control.menu then control:Click() end
    for _, choice in ipairs(control.choices) do
        if choice.value == value and choice:IsShown() and choice:IsEnabled() then choice:Click(); return end
    end
    error("Unavailable policy option: " .. tostring(value))
end

local function Open(locale)
    local env, addon, state = h.login(nil, false, { specID = 63, locale = locale or "enUS", proc = {
        cvars = { displaySpellActivationOverlays = false, spellActivationOverlayOpacity = "0" },
    } })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    Choose(controls.procSelector, "48108")
    Choose(controls.procEntry, leftID)
    local forbidden = function() error("Options must not write Blizzard Spell Alert preferences") end
    env.SetCVar, env.C_CVar.SetCVar = forbidden, forbidden
    return env, addon, state, panel, controls, addon:GetSelectedProcColorEntry()
end

local function Draft(row, text)
    row.valueButton:Click()
    truthy(row.editing)
    row.editBox:SetText(text)
    row.editBox:GetScript("OnTextChanged")(row.editBox, true)
    return row.editBox
end

test("Proc policy UI preserves legacy modes and requires an explicit independent region", function()
    local _, addon, state, panel, controls, entry = Open()
    truthy(addon:SetProcRegionAppearance(entry, { mode = "timer", alpha = .37,
        offset = { x = 19.5, y = -38.25 }, animation = { active = "breathe" } }))
    local before = copy(addon:GetProcRegionAppearance(entry))
    local position = copy(addon:GetReminderPosition(entry))
    Choose(controls.procPresentationPolicy, "independent")
    equal(addon:GetProcPresentationPolicy(), "independent")
    equal(controls.procPresentationPolicy.value, "independent")
    same(addon:GetProcRegionAppearance(entry), before)
    equal(controls.procArt_mode:IsShown(), false); equal(controls.procArt_mode.disabled, true)
    for _, choice in ipairs(controls.procArt_mode.choices) do equal(choice:IsEnabled(), false) end
    equal(controls.procIndependentRegion:GetChecked(), false)
    equal(panel.procArtworkSection:IsShown(), false)
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    equal(addon:OpenProcColorPicker(entry, "artwork"), false)
    controls.procIndependentRegion:Click()
    truthy(addon:IsProcArtworkEditable(entry)); truthy(panel.procArtworkSection:IsShown())
    equal(addon:GetProcArtworkPresentation(entry).mode, "custom")
    same(addon:GetProcRegionAppearance(entry), before)
    Choose(controls.procEntry, rightID)
    equal(controls.procIndependentRegion:GetChecked(), false)
    equal(panel.procArtworkSection:IsShown(), false, "a sibling is not opted in automatically")
    Choose(controls.procEntry, leftID)
    Choose(controls.procPresentationPolicy, "replacement")
    truthy(controls.procArt_mode:IsShown()); equal(controls.procArt_mode.value, "timer")
    equal(controls.procIndependentRegion:IsShown(), false)
    equal(controls.procIndependentRegion.label:IsShown(), false)
    equal(panel.procArtworkSection:IsShown(), false)
    same(addon:GetProcRegionAppearance(entry), before); same(addon:GetReminderPosition(entry), position)
    equal(#state.errors, 0)
end)

test("Proc policy UI master only gates live artwork while enabled regions remain editable and testable", function()
    local env, addon, state, panel, controls, entry = Open()
    Choose(controls.procPresentationPolicy, "independent")
    local timer = h.procFrame(addon, leftID)
    local handle = timer.auraHandle
    local configured = 0
    addon.ConfigureProc = function() configured = configured + 1; error("artwork flags cannot rebind timers") end
    controls.procIndependentRegion:Click()
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, env.Enum.ScreenLocationType.LeftRight, 1, 255, 128, 64)
    truthy(addon.procArtworkFrames[leftID]:IsShown())
    controls.procIndependentArtworkEnabled:Click()
    equal(addon:GetProcConfig().independentArtworkEnabled, false)
    equal(addon.procArtworkFrames[leftID]:IsShown(), false)
    truthy(addon:IsProcArtworkEditable(entry)); truthy(controls.procArtColor:IsEnabled())
    local editor = Draft(controls.procArt_alpha, "37.5")
    editor:GetScript("OnEnterPressed")(editor)
    equal(addon:GetProcRegionAppearance(entry).alpha, .375)
    controls.procArtColor:Click(); truthy(addon.procColorPickerSession)
    state:pickerChange(.1, .2, .3); env.ColorPickerFrame.Footer.OkayButton:Click()
    same(addon:GetProcRegionAppearance(entry).artColor, { r = .1, g = .2, b = .3 })
    controls.procPreview:Click()
    equal(panel.activeCategory, "proc")
    local sample = assert(addon.procPreviewArtworkFrames[leftID])
    truthy(sample:IsShown()); equal(sample.alpha, .375)
    controls.procIndependentRegion:Click()
    equal(sample:IsShown(), false, "the region gate also stops its explicit artwork sample")
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    equal(timer.auraHandle, handle); equal(handle.enabled, true)
    equal(configured, 0); equal(#state.errors, 0)
end)

test("Proc policy UI cancels artwork drafts and leaves reset scoped to appearance", function()
    local env, addon, state, panel, controls, entry = Open()
    Choose(controls.procPresentationPolicy, "independent")
    controls.procIndependentRegion:Click()
    local before = copy(addon:GetProcRegionAppearance(entry))
    controls.procArtColor:Click(); state:pickerChange(.8, .7, .6)
    local edit = Draft(controls.procArt_alpha, "42")
    controls.procIndependentRegion:Click()
    equal(addon.procColorPickerSession, nil); equal(addon.procArtworkColorPreview, nil)
    equal(controls.procArt_alpha.editing, false); equal(edit:HasFocus(), false)
    edit:GetScript("OnEditFocusLost")(edit)
    same(addon:GetProcRegionAppearance(entry), before, "retired draft callbacks cannot save after an opt-out")
    controls.procIndependentRegion:Click()
    truthy(addon:SetProcRegionAppearance(entry, { alpha = .4, artColor = { r = .2, g = .5, b = .8 } }))
    truthy(addon:SetProcRegionColor(entry, { r = .3, g = .2, b = .1 }))
    local timerColor = copy(addon:GetProcRegionColor(entry))
    controls.procArtReset:Click()
    same(addon:GetProcRegionAppearance(entry), addon:NewProcAppearance())
    truthy(addon:GetProcConfig().regions[leftID].independentArtworkEnabled)
    truthy(panel.procArtworkSection:IsShown()); same(addon:GetProcRegionColor(entry), timerColor)
    controls.procArtColor:Click(); truthy(env.ColorPickerFrame:IsShown())
    Choose(controls.procPresentationPolicy, "replacement")
    equal(addon.procColorPickerSession, nil); equal(env.ColorPickerFrame:IsShown(), false)
    equal(#state.errors, 0)
end)

test("Proc policy UI rejected transitions and class resets retain saved and displayed choices", function()
    local _, addon, _, panel, controls = Open()
    Choose(controls.procPresentationPolicy, "independent")
    controls.procIndependentRegion:Click()
    local before = copy(addon.db)
    addon.PrepareProcPresentationTransition = function() return false, "cleanup unavailable" end
    Choose(controls.procPresentationPolicy, "replacement")
    same(addon.db, before); equal(controls.procPresentationPolicy.value, "independent")
    truthy(controls.procIndependentRegion:GetChecked())
    equal(controls.procArt_mode:IsShown(), false)
    equal(panel.feedback:GetText(), "cleanup unavailable")
    controls.reset:Click(); controls.reset:Click()
    same(addon.db, before); equal(controls.procPresentationPolicy.value, "independent")
    equal(panel.feedback:GetText(), "cleanup unavailable")
    equal(panel.resetArmed, false)
end)

test("Proc policy UI gives every locale separate bounded guidance and full width controls", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU" }) do
        local _, addon, state, panel, controls = Open(locale)
        Choose(controls.procPresentationPolicy, "independent")
        equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
        equal(controls.procPresentationPolicy:GetWidth(), 616)
        for _, record in ipairs({ { panel.procPolicySection, {
            controls.procIndependentArtworkEnabled.label, panel.procPolicyGuide, panel.procPolicyWarning,
        } }, { panel.procDisplaySection, { controls.procIndependentRegion.label, panel.procRegionPolicyHint,
            controls.procArtReset } } }) do
            local bottom = 0
            for _, widget in ipairs(record[2]) do
                local _, _, _, x, y = widget:GetPoint()
                truthy(y <= bottom, "localized guidance has a dedicated vertical rectangle")
                bottom = y - widget:GetHeight()
                truthy(x + widget:GetWidth() <= 616, locale)
                truthy(-bottom <= record[1]:GetHeight() - 52, locale)
                if widget.wordWrap ~= nil then truthy(widget.wordWrap) end
            end
        end
        local bottom = 0
        for _, card in ipairs({ panel.procContextSection, panel.procPolicySection, panel.procDisplaySection,
            panel.procTimerSection, panel.procPositionSection }) do
            local _, _, _, _, y = card:GetPoint()
            truthy(y <= bottom); bottom = y - card:GetHeight()
        end
        truthy(panel.procEditor:GetHeight() >= -bottom)
        truthy(panel.procPolicyGuide:IsShown()); truthy(panel.procPolicyWarning:IsShown())
        equal(controls.procEnabled.label:GetText(), addon:Text("Enable Proc"))
        equal(#state.errors, 0)
    end
end)
