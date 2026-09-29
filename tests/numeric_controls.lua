-- Shared numeric interaction contracts. Native pixels and physical pointer
-- capture still need client acceptance; the strict native Slider fixture stays
-- unchanged and only explicit user callbacks perform commits here.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same

local function Fixture(descriptor)
    local env, addon, state = h.login(nil, false, { classToken = "UNKNOWN", specID = false })
    local panel = env.CreateFrame("Frame", nil, env.UIParent)
    panel:SetSize(900, 640); panel.cuiPanel, panel.editBoxes, panel.dropdowns = panel, {}, {}
    panel.feedback = addon.CUI.Label(panel, "", 0, -500, 660)
    local page = env.CreateFrame("Frame", nil, panel); page:SetSize(660, 400)
    local context, writes = "first", {}
    descriptor = descriptor or { min = -10000, max = 10000, step = 1, default = 0 }
    descriptor.context = function() return context end
    local row = addon.CUI.NumberRow(panel, page, "Numeric setting", 0, 0, 616, descriptor,
        function(value, identity)
            writes[#writes + 1] = { value = value, identity = identity }
            return true
        end)
    return env, addon, state, panel, page, row, writes, function(value) context = value end
end

local function Type(row, text)
    row.editBox:SetText(text)
    row.editBox:GetScript("OnTextChanged")(row.editBox, true)
end

local function Drag(row, value)
    local slider = row.slider
    slider.value = value
    slider:GetScript("OnValueChanged")(slider, value, true)
end

local function Start(row)
    row.slider:GetScript("OnMouseDown")(row.slider, "LeftButton")
end

local function Resources(state)
    local animations = 0
    for _, group in ipairs(state.animations) do animations = animations + #group.animations end
    return { #state.frames, #state.textures, #state.fontStrings, #state.animations, animations, #state.pendingTimers }
end

test("NUMERIC rows use native Slider thumbs and stable labeled inline edit layout", function()
    local _, _, state, _, _, row = Fixture({ min = .5, max = 3, step = .01, default = 1, unit = "×" })
    local slider, thumb = row.slider, row.slider:GetThumbTexture()
    equal(slider.thumbTextureAsset, "Interface\\Buttons\\WHITE8X8")
    equal(thumb:GetParent(), slider); equal(slider.template, nil)
    equal(slider.valueStep, .01); equal(slider.obeyStep, true); equal(slider.mouseWheelEnabled, false)
    equal(slider:GetScript("OnMouseWheel"), nil)
    equal(row.valueButton:GetText(), "1×")
    equal(row.editBox:IsShown(), false); truthy(row.valueButton:IsShown())
    truthy(row.label.wordWrap); equal(row:GetHeight(), 32)
    local sizes = { row:GetWidth(), row:GetHeight(), slider:GetWidth(), row.valueButton:GetWidth() }
    local before = Resources(state)
    row.valueButton:Click()
    truthy(row.editBox:IsShown() and row.editBox:HasFocus()); equal(row.valueButton:IsShown(), false)
    truthy(row.editBox.highlight); equal(slider:IsEnabled(), false, "Exact edit is the only active write source")
    same({ row:GetWidth(), row:GetHeight(), slider:GetWidth(), row.editBox:GetWidth() }, sizes)
    row.editBox:GetScript("OnEscapePressed")(row.editBox)
    equal(row.editBox:HasFocus(), false); truthy(row.valueButton:IsShown())
    same(Resources(state), before, "Opening an exact editor reuses every resource")
end)

test("NUMERIC silent refresh and exact editing retain precision without false saves", function()
    local _, _, _, _, _, row, writes = Fixture({ min = .5, max = 3, step = .01, default = 1, precision = 2 })
    row:SetValue(1.2375); equal(#writes, 0); equal(row:GetValue(), 1.2375)
    equal(row.valueButton:GetText(), "1.24")
    row.valueButton:Click(); equal(tonumber(row.editBox:GetText()), 1.2375)
    row.editBox:ClearFocus(); equal(#writes, 0, "Unchanged blur cannot save rounded display text")
    row.valueButton:Click(); Type(row, "1.23456789")
    row:SetValue(1.5); equal(row.editBox:GetText(), "1.23456789", "Refresh preserves the draft in the same context")
    equal(#writes, 0)
    row.editBox:GetScript("OnEnterPressed")(row.editBox)
    equal(#writes, 1); equal(writes[1].value, 1.23456789); equal(row:GetValue(), 1.23456789)
    equal(row.editBox:IsShown(), false); equal(row.editBox:HasFocus(), false)
    row.valueButton:Click(); Type(row, "1.23456789"); row.editBox:ClearFocus()
    equal(#writes, 1, "Equal normalized exact values do not save twice")
end)

test("NUMERIC percentage dragging synchronizes immediately and keeps manual storage precision", function()
    local _, _, state, _, _, row, writes = Fixture({ min = 0, max = 1, step = .01, default = 1, displayFactor = 100, unit = "%" })
    Start(row); Drag(row, .257)
    equal(row:GetValue(), .26); equal(writes[1].value, .26); equal(row.valueButton:GetText(), "26%")
    equal(row.slider:GetValue(), .26)
    Drag(row, .260000001); equal(#writes, 1, "Dragging the same step does not resubmit")
    Drag(row, 0); equal(row:GetValue(), 0); Drag(row, 1); equal(row:GetValue(), 1)
    state:fire("GLOBAL_MOUSE_UP", "LeftButton"); equal(row.dragging, false)
    row.valueButton:Click(); Type(row, "37.125")
    row.editBox:GetScript("OnEnterPressed")(row.editBox)
    equal(row:GetValue(), .37125); equal(row.valueButton:GetText(), "37.125%")
    equal(writes[#writes].value, .37125, "Percent display does not replace storage units or drag-quantize typed input")
    row:SetValue(1); equal(row.valueButton:GetText(), "100%"); equal(row.slider:GetValue(), 1)
end)

test("NUMERIC exact editor prefers readable round-trip decimals without changing stored values", function()
    for _, rowCase in ipairs({
        { value = .3, factor = 1, unit = "×", text = "0.3" },
        { value = .3, factor = 100, unit = "%", text = "30" },
        { value = .375, factor = 100, unit = "%", text = "37.5" },
        { value = 1.2345678901234567, factor = 1, unit = "×", text = "1.2345678901234567" },
    }) do
        local _, _, _, _, _, row, writes = Fixture({ min = 0, max = 3, step = .01,
            default = 1, displayFactor = rowCase.factor, unit = rowCase.unit })
        row:SetValue(rowCase.value); row.valueButton:Click()
        equal(row.editBox:GetText(), rowCase.text)
        equal(tonumber(row.editBox:GetText()) / rowCase.factor, rowCase.value,
            "The readable editor text preserves storage units exactly")
        row.editBox:ClearFocus()
        equal(row:GetValue(), rowCase.value); equal(#writes, 0, "An unchanged exact editor never quantizes or saves")
    end
end)

test("NUMERIC invalid drafts Enter Escape blur and negative values follow transactional rules", function()
    local _, _, _, panel, _, row, writes = Fixture()
    row:SetValue(-120.25)
    for _, text in ipairs({ "", "-", ".", "nan", "1e999", "10001", "-10001" }) do
        row.valueButton:Click(); Type(row, text)
        equal(#writes, 0, "Draft typing never submits")
        row.editBox:GetScript("OnEnterPressed")(row.editBox)
        truthy(row.editing and row.editBox:HasFocus() and row.editBox.invalid)
        row.editBox:ClearFocus()
        equal(row.editing, false); equal(row:GetValue(), -120.25); equal(#writes, 0)
        truthy(panel.feedback:GetText() ~= "")
    end
    row.valueButton:Click(); Type(row, "-800.5"); row.editBox:GetScript("OnEscapePressed")(row.editBox)
    equal(row:GetValue(), -120.25); equal(#writes, 0); truthy(panel:IsShown(), "Escape cancels only the inline edit")
    row.valueButton:Click(); Type(row, "-800.5"); row.editBox:ClearFocus()
    equal(row:GetValue(), -800.5); equal(writes[1].value, -800.5)
end)

test("NUMERIC changing object identity cancels stale edit and drag callbacks before submission", function()
    local _, addon, _, _, _, row, writes, Context = Fixture()
    row.valueButton:Click(); Type(row, "200")
    local enter = row.editBox:GetScript("OnEnterPressed")
    Context("second"); row.editBox:ClearFocus()
    equal(#writes, 0); equal(row.editing, false)
    enter(row.editBox); equal(#writes, 0)
    Start(row); Context("third"); Drag(row, 400)
    equal(#writes, 0); equal(row.dragging, false)
    row:SetContext("third"); row:SetValue(12)
    row.valueButton:Click(); Type(row, "77")
    row:SetContext("fourth"); Context("fourth"); row:SetValue(24)
    enter(row.editBox); equal(#writes, 0); equal(row:GetValue(), 24)
    Drag(row, 900); equal(#writes, 0); equal(row:GetValue(), 24, "No late drag event may create a new interaction")
    addon.CUI.ClearNumericInteractions(row.cuiPanel)
    row:SetValue(0); equal(row.slider:GetValue(), 0); equal(row.valueButton:GetText(), "0")
end)

test("NUMERIC correcting invalid input to the saved value clears stale error without submitting", function()
    local _, addon, _, panel, _, row, writes = Fixture()
    row:SetValue(37)
    for _, blur in ipairs({ false, true }) do
        row.valueButton:Click(); Type(row, "invalid")
        row.editBox:GetScript("OnEnterPressed")(row.editBox)
        truthy(row.editBox.invalid); equal(panel.feedback:GetText(), addon.L.invalid)
        Type(row, "37")
        if blur then row.editBox:ClearFocus()
        else row.editBox:GetScript("OnEnterPressed")(row.editBox) end
        equal(#writes, 0, "Successful same-value validation never writes settings")
        equal(row:GetValue(), 37); equal(row.editing, false); equal(row.editBox.invalid, false)
        equal(panel.feedback:GetText(), addon.L.immediate, "Ordinary guidance replaces the old error")
        truthy(panel.feedback:GetText() ~= addon.L.saved, "No saved claim is made for an unchanged value")
        same(panel.feedback.textColor, addon.DesignSystem.textSecondary, "The feedback is no longer an error or success state")
    end
end)

test("NUMERIC clicking another numeric row commits valid blur and preserves a single write source", function()
    local _, addon, _, panel, page, row, writes = Fixture()
    local second = addon.CUI.NumberRow(panel, page, "Second", 0, -40, 616,
        { min = -10000, max = 10000, step = 1, default = 0 }, function(value) writes[#writes + 1] = value; return true end)
    row.valueButton:Click(); Type(row, "12.75"); second.valueButton:Click()
    equal(#writes, 1); equal(writes[1].value, 12.75)
    equal(row.editing, false); truthy(second.editing and second.editBox:HasFocus())
    Type(second, "-"); row.valueButton:Click()
    equal(#writes, 1); equal(second:GetValue(), 0); equal(second.editing, false)
    truthy(row.editing and row.editBox:HasFocus())
    Type(row, "16"); Start(second); Drag(second, 30)
    equal(#writes, 3); equal(writes[2].value, 16); equal(writes[3], 30)
    equal(row.editing, false); truthy(second.dragging)
end)

test("NUMERIC release hide combat spec and motion boundaries clear ownership focus and reusable resources", function()
    local _, addon, state, panel, page, row, writes = Fixture()
    local before = Resources(state)
    for _ = 1, 20 do
        Start(row); Drag(row, 42)
        state:fire("GLOBAL_MOUSE_UP", "RightButton"); truthy(row.dragging)
        state:fire("GLOBAL_MOUSE_UP", "LeftButton"); equal(row.dragging, false)
        equal(next(panel.numericEvents.events), nil, "Global subscriptions exist only during numeric interaction")
        row.valueButton:Click(); Type(row, "73"); addon.CUI.StopMotion(panel)
        equal(row.editBox:HasFocus(), false); equal(row.editing, false)
    end
    equal(#writes, 1, "Repeat normalized drag values do not save")
    same(Resources(state), before, "Repeated drag/edit/cancel adds no frames fonts animations or timers")
    for _, close in ipairs({ function() page:Hide() end, function() panel:Hide() end,
        function() row:Hide() end, function() state:fire("PLAYER_SPECIALIZATION_CHANGED", "player") end,
        function() state:fire("PLAYER_REGEN_DISABLED") end }) do
        state.inCombat = false; panel:Show(); page:Show(); row:Show()
        row.valueButton:Click(); Type(row, "73"); row.valueButton:GetScript("OnEnter")(row.valueButton)
        close()
        equal(row.editing, false); equal(row.dragging, false); equal(row.editBox:HasFocus(), false)
        equal(row.valueButton.hoverAnimation:IsPlaying(), false)
        equal(next(panel.numericEvents.events), nil); equal(#writes, 1)
    end
end)

test("NUMERIC disabled and transitioning section inputs cannot blur commit or restart a stale drag", function()
    local _, addon, _, panel, page, _, writes = Fixture()
    local section = addon.CUI.Section(page, "Advanced", 0, -40, 616, { collapsible = true, height = 120 })
    local row = addon.CUI.NumberRow(panel, section.content, "Scale", 0, 0, 592,
        { min = .5, max = 3, step = .01, default = 1 }, function(value) writes[#writes + 1] = value; return true end)
    row.valueButton:Click(); Type(row, "1.5"); section:SetCollapsed(true)
    equal(#writes, 0); equal(row.editing, false); equal(row.editBox:HasFocus(), false)
    row.valueButton:GetScript("OnClick")(row.valueButton); Drag(row, 2)
    equal(#writes, 0)
    section:SetCollapsed(false, true)
    row.valueButton:Click(); Type(row, "1.5"); row:SetEnabled(false)
    equal(#writes, 0); equal(row.editBox:HasFocus(), false)
    equal(row.slider:IsEnabled(), false); equal(row.valueButton:IsEnabled(), false)
    row:SetEnabled(true); Start(row); Drag(row, 1.5)
    equal(#writes, 1); equal(writes[1], 1.5)
end)
