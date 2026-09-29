-- These checks drive the shared numeric row's actual slider/editor controls.
-- Native cursor capture, clipping, and localized glyph fit still need client QA.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local fields = {
    { "procArt_alpha", "alpha", 0, 1, .01, 1, 100, "%" },
    { "procArt_scale", "scale", .25, 3, .01, 1, 1, "×" },
    { "procArt_desaturation", "desaturation", 0, 1, .01, 0, 100, "%" },
    { "procArt_rotation", "rotation", -180, 180, 1, 0, 1, "°" },
    { "procArt_width", "width", .25, 3, .01, 1, 1, "×" },
    { "procArt_height", "height", .25, 3, .01, 1, 1, "×" },
    { "procArt_offsetX", "offset", -1000, 1000, 1, 0, 1 },
    { "procArt_offsetY", "offset", -1000, 1000, 1, 0, 1 },
    { "procArt_speed", "speed", .25, 3, .01, 1, 1, "×" },
    { "procArt_intensity", "intensity", 0, 1, .01, .2, 100, "%" },
    { "procPositionX", "position", -10000, 10000, 1, 0, 1 },
    { "procPositionY", "position", -10000, 10000, 1, 0, 1 },
}

local function Choose(control, value)
    if control.menu then control:Click() end
    for _, choice in ipairs(control.choices) do
        if choice.value == value and choice:IsShown() and choice:IsEnabled() then choice:Click(); return end
    end
    error("Unavailable choice: " .. tostring(value))
end

local function Open(locale)
    local env, addon, state = h.login(nil, false, { specID = 62, proc = {}, locale = locale or "enUS" })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    Choose(controls.procArt_mode, "custom")
    controls.procAdvanced:Click()
    local group = panel.procAdvancedSection.expandAnimation
    group.playing = false; group:GetScript("OnFinished")(group)
    return env, addon, state, panel, controls, addon:GetSelectedProcColorEntry()
end

local function Type(row, text)
    if not row.editing then row.valueButton:Click() end
    truthy(row.editing and row.editBox:IsShown(), "clicking the value opens the in-place editor")
    row.editBox:SetText(tostring(text))
    row.editBox:GetScript("OnTextChanged")(row.editBox, true)
    return row.editBox
end

local function Enter(row, text)
    local edit = Type(row, text)
    edit:GetScript("OnEnterPressed")(edit)
end

local function Move(row, value)
    -- The native slider changes its physical value before its user callback.
    row.slider.value = value
    row.slider:GetScript("OnValueChanged")(row.slider, value, true)
end

test("Proc numeric rows cover all twelve existing values with original metadata and explicit units", function()
    local _, addon, _, _, controls = Open()
    for _, item in ipairs(fields) do
        local row = controls[item[1]]
        truthy(row and row.slider and row.valueButton and row.editBox, item[1])
        equal(row.slider.cuiKind, "slider")
        equal(row:GetWidth(), 616); equal(row:GetHeight(), 32)
        truthy(row.label.wordWrap)
        equal(row.editBox:IsShown(), false, "precise editor is hidden by default")
        truthy(row.valueButton:IsShown())
        local descriptor = row.descriptor
        equal(descriptor.min, item[3]); equal(descriptor.max, item[4])
        equal(descriptor.step, item[5]); equal(descriptor.default, item[6])
        equal(descriptor.displayFactor or 1, item[7]); equal(descriptor.unit, item[8])
        local min, max = row.slider:GetMinMaxValues()
        equal(min, descriptor.min); equal(max, descriptor.max)
        local range = item[2] == "position" and addon.limits.offset or addon.procAppearanceLimits[item[2]]
        equal(min, range.min); equal(max, range.max)
        equal(type(row.slider.thumbTextureAsset), "string", "the native thumb API receives an asset path")
        equal(row.slider:GetScript("OnMouseWheel"), nil, "page scrolling has no numeric mutation callback")
    end
    equal(controls.procArt_alpha.valueButton:GetText(), "100%")
    equal(controls.procArt_scale.valueButton:GetText(), "1×")
    equal(controls.procArt_rotation.valueButton:GetText(), "0°")
end)

test("Proc numeric dragging saves locally once per normalized value without reconfiguration or allocation growth", function()
    local _, addon, state, panel, controls, entry = Open()
    local timerColor, timerStyle = copy(addon:GetProcRegionColor(entry)), copy(addon:GetReminderStyle(entry))
    local frames, textures, groups, slots, fonts = #state.frames, #state.textures, #state.animations, #state.auraSlots, #state.auraFonts
    local update, saves = addon.UpdateSettings, 0
    addon.UpdateSettings = function(self, patch, options)
        saves = saves + 1
        truthy(options and options.skipOptionsRefresh, "numeric save requests local UI handling")
        return update(self, patch, options)
    end
    for _, method in ipairs({ "ConfigureProc", "ConfigureMobility", "ApplySettings", "RefreshOptions" }) do
        addon[method] = function() error("numeric drag cannot rebuild configuration or page: " .. method) end
    end
    local alpha = controls.procArt_alpha
    alpha.slider:GetScript("OnMouseDown")(alpha.slider, "LeftButton")
    Move(alpha, .435); equal(addon:GetProcRegionAppearance(entry).alpha, .44)
    equal(alpha.valueButton:GetText(), "44%")
    local once = saves
    Move(alpha, .436); equal(saves, once, "equal normalized drag values are deduplicated")
    state:fire("GLOBAL_MOUSE_UP", "LeftButton")
    equal(alpha.dragging, false); equal(panel.numericInteraction, nil)
    for _ = 1, 3 do
        for _, item in ipairs(fields) do
            local row = controls[item[1]]
            row.slider:GetScript("OnMouseDown")(row.slider, "LeftButton")
            Move(row, item[3]); equal(row:GetValue(), item[3], "minimum endpoint is reachable")
            Move(row, item[4]); equal(row:GetValue(), item[4], "maximum endpoint is reachable")
            state:fire("GLOBAL_MOUSE_UP", "LeftButton")
        end
    end
    equal(addon:GetReminderPosition(entry).x, 10000)
    equal(addon:GetProcRegionAppearance(entry).offset.x, 1000, "timer and artwork offsets retain different ownership/ranges")
    same(addon:GetProcRegionColor(entry), timerColor); same(addon:GetReminderStyle(entry), timerStyle)
    equal(#state.frames, frames); equal(#state.textures, textures); equal(#state.animations, groups)
    equal(#state.auraSlots, slots); equal(#state.auraFonts, fonts)
    equal(#state.errors, 0)
end)

test("Proc numeric precise edits preserve fractions and percent storage while invalid and canceled drafts never save", function()
    local _, addon, _, _, controls, entry = Open()
    Enter(controls.procArt_alpha, "12.345")
    truthy(math.abs(addon:GetProcRegionAppearance(entry).alpha - .12345) < 1e-12)
    Enter(controls.procArt_scale, "1.23456789")
    equal(addon:GetProcRegionAppearance(entry).scale, 1.23456789)
    Enter(controls.procPositionX, "-12.375")
    equal(addon:GetReminderPosition(entry).x, -12.375)
    local before = copy(addon.db)
    local row = controls.procPositionX
    for _, value in ipairs({ "", "-", "nan", "inf", "10001" }) do
        Enter(row, value)
        truthy(row.editing and row.editBox.invalid, "invalid Enter remains editable")
        same(addon.db, before)
        row.editBox:GetScript("OnEscapePressed")(row.editBox)
        equal(row.editing, false); equal(row:GetValue(), -12.375)
    end
    local edit = Type(row, "73.125")
    same(addon.db, before, "typing remains a draft")
    edit:ClearFocus()
    equal(row.editing, false); equal(addon:GetReminderPosition(entry).x, 73.125, "valid blur commits only this axis")
    local committed = copy(addon.db)
    edit = Type(row, "-10001"); edit:ClearFocus()
    equal(row.editing, false); equal(row:GetValue(), 73.125)
    same(addon.db, committed, "invalid blur restores the committed value")
end)

test("Proc numeric program refresh is silent and preserves the current precise draft", function()
    local _, addon, _, _, controls, entry = Open()
    local row = controls.procArt_scale
    local edit = Type(row, "1.375")
    local before = copy(addon.db)
    addon.UpdateSettings = function() error("programmatic refresh must not save") end
    addon:RefreshProcAppearanceOptions()
    truthy(row.editing); equal(edit:GetText(), "1.375")
    for _, item in ipairs(fields) do
        local numeric = controls[item[1]]
        numeric:SetValue(numeric:GetValue())
    end
    equal(edit:GetText(), "1.375"); same(addon.db, before)
    equal(addon:GetProcRegionAppearance(entry).scale, 1)
    edit:GetScript("OnEscapePressed")(edit)
    equal(row.editing, false)
end)

test("Proc numeric region page spec close and combat boundaries cancel drafts drag sessions and stale callbacks", function()
    for _, boundary in ipairs({ "region", "page", "spec", "close", "combat" }) do
      for _, interaction in ipairs({ "edit", "drag" }) do
        local _, addon, state, panel, controls, entry = Open()
        local position = copy(addon:GetReminderPosition(entry))
        local row, edit = controls.procPositionX, controls.procPositionX.editBox
        if interaction == "edit" then Type(row, "777")
        else row.slider:GetScript("OnMouseDown")(row.slider, "LeftButton"); truthy(row.dragging) end
        local stale = edit:GetScript("OnEnterPressed")
        if boundary == "region" then
            local target
            for _, choice in ipairs(controls.procEntry.choices) do
                if choice.value ~= entry.id and choice:IsShown() then target = choice.value; break end
            end
            truthy(target); Choose(controls.procEntry, target)
        elseif boundary == "page" then addon:SelectOptionsCategory("general")
        elseif boundary == "spec" then state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        elseif boundary == "close" then panel:Hide()
        else state:fire("PLAYER_REGEN_DISABLED") end
        stale(edit)
        Move(row, 777)
        equal(row.editing, false, boundary)
        equal(row.dragging, false, boundary)
        equal(edit:HasFocus(), false, boundary)
        equal(panel.numericInteraction, nil, "a canceled source cannot retain ownership")
        equal(next(panel.numericEvents.events), nil, "numeric boundary listeners return to idle")
        local saved = addon.db.classes.MAGE.proc[62].regions[entry.id]
        same(saved.position, position, boundary .. " cannot write the old or new region")
        if boundary == "region" then
            equal(addon:GetReminderPosition(addon:GetSelectedProcColorEntry()).x, 0)
        end
      end
    end
end)

test("Proc numeric resets synchronize rows while preserving timer artwork and specialization scopes", function()
    local _, addon, _, _, controls, entry = Open()
    addon:SetProcRegionColor(entry, { r = .2, g = .4, b = .6 })
    local typography = copy(addon:GetReminderStyle(entry))
    Enter(controls.procPositionX, -173.25); Enter(controls.procPositionY, 81)
    Enter(controls.procArt_offsetX, 91); Enter(controls.procArt_offsetY, -32)
    Enter(controls.procArt_alpha, 67)
    local position, color = copy(addon:GetReminderPosition(entry)), copy(addon:GetProcRegionColor(entry))
    controls.procArtReset:Click()
    same(addon:GetProcRegionAppearance(entry), addon:NewProcAppearance())
    same(addon:GetReminderPosition(entry), position); same(addon:GetProcRegionColor(entry), color)
    same(addon:GetReminderStyle(entry), typography)
    equal(controls.procArt_alpha:GetValue(), 1); equal(controls.procArt_offsetX:GetValue(), 0)
    local appearance = copy(addon:GetProcRegionAppearance(entry))
    Type(controls.procPositionX, "not-a-number")
    controls.procPositionReset:Click()
    same(addon:GetReminderPosition(entry), addon:NewReminderPosition())
    same(addon:GetProcRegionAppearance(entry), appearance)
    equal(controls.procPositionX:GetValue(), 0); equal(controls.procPositionY:GetValue(), 0)
    equal(controls.procPositionX.editing, false)
end)

test("Proc numeric rows retain fixed readable geometry across supported locales", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU" }) do
        local _, _, state, panel, controls = Open(locale)
        equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
        for _, item in ipairs(fields) do
            local row = controls[item[1]]
            equal(row:GetWidth(), row:GetParent():GetWidth())
            equal(row.label:GetWidth(), 240); equal(row.valueButton:GetWidth(), 88)
            truthy(row.slider:GetWidth() >= 200, "all twelve settings retain a usable track")
            local _, _, _, x, y = row:GetPoint()
            truthy(x >= 0 and x + row:GetWidth() <= row:GetParent():GetWidth())
            local section = row:GetParent():GetParent()
            truthy(-y + row:GetHeight() <= section:GetHeight() - 52, "number row stays in its card")
            equal(row.editBox:IsShown(), false)
        end
        equal(#state.errors, 0, locale)
    end
end)
