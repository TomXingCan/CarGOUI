-- Page integration uses real NumberRow input surfaces and native userInput
-- dispatch. Programmatic SetValue is deliberately never used as a user gesture.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open(client)
    client = client or { specID = 62, proc = {} }
    local env, addon, state = h.mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20 }, client)
    local panel, controls = h.options(addon)
    return env, addon, state, panel, controls
end

local function Draft(row, value)
    row.valueButton:Click()
    local edit = row.editBox
    truthy(edit:IsShown() and edit:HasFocus(), "clicking the value opens the inline editor")
    edit:SetText(value); edit:GetScript("OnTextChanged")(edit, true)
    return edit
end

local function Enter(row, value)
    local edit = Draft(row, value)
    edit:GetScript("OnEnterPressed")(edit)
    return edit
end

local function Drag(row, value)
    local slider = row.slider
    truthy(slider:IsVisible() and slider:IsEnabled() and slider:IsMouseEnabled())
    if not row.dragging then slider:GetScript("OnMouseDown")(slider, "LeftButton") end
    -- The native widget owns its value before delivering a userInput event.
    slider:SetValue(value)
    slider:GetScript("OnValueChanged")(slider, value, true)
end

local function Release(row) row.slider:GetScript("OnMouseUp")(row.slider, "LeftButton") end

local function Resources(addon, state)
    local result = { frames = #state.frames, slots = #state.auraSlots, bindings = #state.bindings,
        callbacks = addon:GetEventDiagnostics().callbacks, reads = state.realReads }
    result.textures, result.fonts, result.animations = #state.textures, #state.auraFonts, #state.animations
    result.timers, result.fontStrings = state.timers, #state.fontStrings
    return result
end

test("NUMERIC OPTIONS inventory uses six shared slider-first rows with original ranges and defaults", function()
    local _, addon, _, panel, c = Open()
    addon:SelectOptionsCategory("mobility")
    for _, name in ipairs({ "mobilityX", "mobilityY", "freeMoveX", "freeMoveY" }) do
        local row = c[name]
        equal(row:GetObjectType(), "Frame"); equal(row.slider:GetObjectType(), "Slider")
        equal(row.editBox:IsShown(), false, "no bare numeric EditBox is shown by default")
        truthy(row.valueButton:IsShown()); truthy(row.label:GetText() ~= "")
        equal(row.descriptor.min, addon.limits.offset.min); equal(row.descriptor.max, addon.limits.offset.max)
        equal(row.descriptor.default, addon:NewReminderPosition().x); equal(row.descriptor.step, 1)
        equal(row:GetValue(), 0)
    end
    addon:OpenAppearance("mobility")
    equal(c.appearanceFontSize.descriptor.min, 8); equal(c.appearanceFontSize.descriptor.max, 72)
    equal(c.appearanceFontSize:GetValue(), 24); equal(c.appearanceFontSize.descriptor.step, 1)
    equal(c.appearanceScale.descriptor.min, .5); equal(c.appearanceScale.descriptor.max, 3)
    equal(c.appearanceScale:GetValue(), 1); equal(c.appearanceScale.descriptor.step, .01)
    equal(c.appearanceScale.valueButton:GetText(), "1×")
    for _, row in ipairs(panel.numericRows) do
        local parent = row:GetParent()
        while parent and parent ~= panel.pages.general do parent = parent.GetParent and parent:GetParent() or nil end
        equal(parent, nil, "General / Window gains no invented numerical setting")
    end
end)

test("NUMERIC OPTIONS Mobility and Free Move drags apply locally and deduplicate normalized values", function()
    local _, addon, state, panel, c = Open()
    addon:SelectOptionsCategory("mobility")
    local free = addon:GetFreeMovePreviewEntry()
    local before = Resources(addon, state)
    local update, submits, refreshes = addon.UpdateSettings, 0, 0
    addon.UpdateSettings = function(self, patch, options)
        submits = submits + 1
        truthy(options and options.skipOptionsRefresh, "continuous numbers request the local update route")
        return update(self, patch, options)
    end
    local refresh = addon.RefreshOptions
    addon.RefreshOptions = function(self) refreshes = refreshes + 1; return refresh(self) end
    addon.ApplySettings = function() error("numeric movement must not reconfigure all modules") end
    Drag(c.mobilityX, -120); equal(addon:GetMobilityConfig().position.x, -120)
    equal(c.mobilityX.slider:GetValue(), -120); equal(c.mobilityX.valueButton:GetText(), "-120")
    Drag(c.mobilityX, -119.6); equal(submits, 1, "same normalized drag value does not submit twice")
    Drag(c.mobilityX, -119); Release(c.mobilityX)
    Drag(c.freeMoveY, -31); Release(c.freeMoveY)
    equal(addon:GetReminderPosition(free).y, -31)
    equal(addon:GetMobilityConfig().position.y, 0, "Free Move never changes ordinary Mobility Y")
    equal(addon:GetReminderPosition(free).x, 0)
    equal(submits, 3); equal(refreshes, 0, "dragging never rebuilds page controls or dropdown callbacks")
    same(Resources(addon, state), before, "dragging adds no frames fonts groups timers bindings or callbacks")
    equal(panel.numericInteraction, nil)
end)

test("NUMERIC OPTIONS exact positions preserve fractional negatives and separate reset ownership", function()
    local _, addon, _, _, c = Open()
    addon:SelectOptionsCategory("mobility")
    local free = addon:GetFreeMovePreviewEntry()
    Enter(c.mobilityX, "-120.25"); Enter(c.mobilityY, "17.875")
    Enter(c.freeMoveX, "-333.125"); Enter(c.freeMoveY, "27.5")
    equal(addon:GetMobilityConfig().position.x, -120.25); equal(addon:GetMobilityConfig().position.y, 17.875)
    equal(addon:GetReminderPosition(free).x, -333.125); equal(addon:GetReminderPosition(free).y, 27.5)
    Draft(c.freeMoveX, "777.25"); c.freeMoveReset:Click()
    same(addon:GetReminderPosition(free), { anchor = "CENTER", x = 0, y = 0 })
    equal(c.freeMoveX:GetValue(), 0); equal(c.freeMoveX.slider:GetValue(), 0)
    equal(addon:GetMobilityConfig().position.x, -120.25)
    Enter(c.freeMoveX, "150.75"); Draft(c.mobilityY, "88.25"); c.mobilityReset:Click()
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 0, y = 0 })
    equal(c.mobilityY:GetValue(), 0); equal(addon:GetReminderPosition(free).x, 150.75)
    Drag(c.mobilityX, -10000); Release(c.mobilityX); equal(addon:GetMobilityConfig().position.x, -10000)
    Drag(c.mobilityY, 10000); Release(c.mobilityY); equal(addon:GetMobilityConfig().position.y, 10000)
end)

test("NUMERIC OPTIONS precise edit Enter Escape blur and invalid inputs preserve committed state", function()
    local _, addon, _, panel, c = Open()
    addon:SelectOptionsCategory("mobility")
    Enter(c.mobilityX, "-45.625")
    for _, invalid in ipairs({ "", "-", "not a number", "1e309", "-10000.01", "10000.01" }) do
        local edit = Enter(c.mobilityX, invalid)
        equal(addon:GetMobilityConfig().position.x, -45.625)
        truthy(edit:IsShown() and edit:HasFocus() and edit.invalid, "invalid Enter remains in the inline editor")
        edit:GetScript("OnEscapePressed")(edit)
        truthy(panel:IsShown(), "numeric Escape never closes Options")
        equal(c.mobilityX:GetValue(), -45.625); truthy(c.mobilityX.valueButton:IsShown())
    end
    local edit = Draft(c.mobilityX, "-81.125")
    equal(addon:GetMobilityConfig().position.x, -45.625, "typing is a draft")
    edit:ClearFocus(); equal(addon:GetMobilityConfig().position.x, -81.125, "valid blur saves immediately")
    edit = Draft(c.mobilityX, "-"); edit:ClearFocus()
    equal(c.mobilityX:GetValue(), -81.125); equal(addon:GetMobilityConfig().position.x, -81.125)
    truthy(not edit:IsShown() and c.mobilityX.valueButton:IsShown(), "invalid blur restores numeric display")
    truthy(panel.feedback:GetText() ~= "", "invalid blur gives short feedback")
end)

test("NUMERIC OPTIONS typography stays shared by context and keeps exact saved precision", function()
    local _, addon, state, panel, c = Open()
    addon:OpenAppearance("mobility")
    Enter(c.appearanceFontSize, "31.5"); Enter(c.appearanceScale, "1.2375")
    equal(addon:GetMobilityConfig().style.font.size, 31.5); equal(addon:GetMobilityConfig().style.scale, 1.2375)
    equal(c.appearanceScale.valueButton:GetText(), "1.2375×")
    addon:OpenAppearance("proc")
    local oldSpec = state.specID
    Enter(c.appearanceFontSize, "29.25"); Enter(c.appearanceScale, "1.425")
    local edit = Draft(c.appearanceFontSize, "70")
    local lateEnter = edit:GetScript("OnEnterPressed")
    state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player"); state:flushTimers()
    lateEnter(edit)
    equal(addon.db.classes.MAGE.proc[oldSpec].style.font.size, 29.25)
    equal(addon:GetReminderStyle(panel.selectedAppearanceKey).font.size, 24, "old draft never writes to new spec")
    equal(c.appearanceFontSize:GetValue(), 24); equal(edit:HasFocus(), false)
    addon:OpenAppearance("mobility")
    equal(c.appearanceFontSize:GetValue(), 31.5); equal(c.appearanceScale:GetValue(), 1.2375)
    c.appearanceReset:Click()
    equal(c.appearanceFontSize:GetValue(), 24); equal(c.appearanceScale:GetValue(), 1)
    equal(addon.db.classes.MAGE.proc[oldSpec].style.font.size, 29.25, "Mobility reset preserves Proc specialization typography")
end)

test("NUMERIC OPTIONS program refresh and equivalent exact values never save or allocate", function()
    local _, addon, state, panel, c = Open()
    addon:OpenAppearance("mobility")
    Enter(c.appearanceScale, "1.2375")
    local update, submits = addon.UpdateSettings, 0
    addon.UpdateSettings = function(self, ...) submits = submits + 1; return update(self, ...) end
    c.appearanceScale:SetValue(2.75)
    equal(addon:GetMobilityConfig().style.scale, 1.2375, "SetValue is always a silent UI refresh")
    addon:RefreshOptions(); equal(c.appearanceScale:GetValue(), 1.2375)
    Enter(c.appearanceScale, "1.2375000"); equal(submits, 0, "equivalent exact values do not resubmit")
    local before = Resources(addon, state)
    for index = 1, 30 do Drag(c.appearanceScale, 1 + index / 100) end
    Release(c.appearanceScale)
    equal(addon:GetMobilityConfig().style.scale, 1.3)
    same(Resources(addon, state), before, "continuous style updates reuse all owned resources")
    local edit = Draft(c.appearanceScale, "2.25")
    addon:RefreshOptions()
    equal(edit:GetText(), "2.25", "same-context refresh retains the active draft")
    equal(addon:GetMobilityConfig().style.scale, 1.3)
    edit:GetScript("OnEscapePressed")(edit)
    local allocations = #state.frames
    for _ = 1, 4 do addon:CloseOptions(); addon:OpenOptions() end
    equal(#state.frames, allocations); equal(panel.numericInteraction, nil)
end)

test("NUMERIC OPTIONS page close combat and specialization boundaries cancel drafts and native drag", function()
    for _, boundary in ipairs({ "page", "close", "combat", "spec" }) do
        local _, addon, state, panel, c = Open()
        addon:SelectOptionsCategory("mobility")
        local edit = Draft(c.mobilityX, "-901.375")
        local late = edit:GetScript("OnEnterPressed")
        if boundary == "page" then addon:SelectOptionsCategory("general")
        elseif boundary == "close" then addon:CloseOptions()
        elseif boundary == "combat" then state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
        else state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player") end
        late(edit)
        equal(addon:GetMobilityConfig().position.x, 0, boundary .. " cancels rather than blur-commits")
        equal(edit:HasFocus(), false); equal(c.mobilityX.editing, false); equal(panel.numericInteraction, nil)
    end
    local _, addon, state, panel, c = Open()
    addon:SelectOptionsCategory("mobility")
    Drag(c.mobilityX, 70)
    state:fire("GLOBAL_MOUSE_UP", "LeftButton")
    equal(c.mobilityX.dragging, false, "release outside the native slider ends capture")
    equal(panel.numericInteraction, nil)
    Drag(c.mobilityX, 71); addon:SelectOptionsCategory("general")
    equal(c.mobilityX.dragging, false)
    c.mobilityX.slider:GetScript("OnValueChanged")(c.mobilityX.slider, 800, true)
    equal(addon:GetMobilityConfig().position.x, 71, "hidden-page stale input is ignored")
    for _, frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"), nil) end
end)

test("NUMERIC OPTIONS localized labels retain the shared fixed row geometry under viewport clamping", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "koKR", "ruRU" }) do
        local _, addon, _, panel, c = Open({ specID = 62, proc = {}, locale = locale,
            uiWidth = 800, uiHeight = 600, uiScale = .8 })
        addon:SelectOptionsCategory("mobility")
        truthy(panel:GetScale() < 1)
        for _, row in ipairs({ c.mobilityX, c.mobilityY, c.freeMoveX, c.freeMoveY }) do
            truthy(row.label:GetText() ~= "")
            equal(row:GetHeight(), 32)
            truthy(row.label:GetWidth() + row.slider:GetWidth() + row.valueButton:GetWidth() + 32 <= row:GetWidth() + .001)
            local width, height = row:GetWidth(), row:GetHeight()
            Draft(row, "-120.25")
            equal(row:GetWidth(), width); equal(row:GetHeight(), height, "inline editing never shifts the row")
            row.editBox:GetScript("OnEscapePressed")(row.editBox)
        end
    end
end)
