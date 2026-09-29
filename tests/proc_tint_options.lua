-- Tint controls write existing presentation fields. These checks verify widget
-- state and texture parameters, not the native shader's final pixel colors.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local guide = "0% keeps the artwork colors; 100% removes them before tinting. Values in between retain some original color."
local limitation = "Tint depends on the artwork brightness and transparency; the selected color may not appear as a solid flat color."

local function Choose(control, value)
    if control.menu then control:Click() end
    for _, choice in ipairs(control.choices) do
        if choice.value == value and choice:IsShown() and choice:IsEnabled() then choice:Click(); return end
    end
    error("Unavailable tint option: " .. tostring(value))
end

local function Open(locale)
    local env, addon, state = h.login(nil, false, { specID = 62, proc = {}, locale = locale or "enUS" })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    Choose(controls.procArt_mode, "custom")
    return env, addon, state, panel, controls, addon:GetSelectedProcColorEntry()
end

local function Drag(row, value)
    row.slider:GetScript("OnMouseDown")(row.slider, "LeftButton")
    truthy(row.dragging, "tint is editable without expanding Advanced")
    row.slider:SetValue(value)
    row.slider:GetScript("OnValueChanged")(row.slider, value, true)
    row.slider:GetScript("OnMouseUp")(row.slider, "LeftButton")
end

local function ConfirmColor(env, state, controls, r, g, b)
    Choose(controls.procArt_colorMode, "custom")
    truthy(env.ColorPickerFrame:IsShown())
    state:pickerChange(r, g, b)
    env.ColorPickerFrame.Footer.OkayButton:Click()
end

test("Proc tint places desaturation opacity and explanations beside artwork color in every locale", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU" }) do
        local _, addon, state, panel, controls = Open(locale)
        equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
        local card = panel.procArtworkSection
        equal(controls.procArt_desaturation:GetParent(), card.content)
        equal(controls.procArt_alpha:GetParent(), card.content)
        equal(controls.procArt_colorMode:GetParent(), card.content)
        equal(controls.procArt_scale:GetParent(), panel.procTransformSection.content)
        equal(panel.procAdvancedSection.collapsed, true)
        truthy(controls.procArt_desaturation:IsVisible()); truthy(controls.procArt_alpha:IsVisible())
        equal(controls.procArt_desaturation.valueButton:GetText(), "0%")
        equal(controls.procArt_alpha.valueButton:GetText(), "100%")
        equal(panel.procTintGuide:GetText(), addon:Text(guide))
        equal(panel.procTintLimit:GetText(), addon:Text(limitation))
        local bottom = -160
        for _, item in ipairs({ controls.procArt_desaturation, panel.procTintGuide,
            controls.procArt_alpha, panel.procTintLimit }) do
            local _, _, _, x, y = item:GetPoint()
            equal(x, 0); truthy(y < bottom, "tint rows and wrapped explanations have separate vertical space")
            bottom = y - item:GetHeight()
            equal(item:GetWidth(), 616)
            truthy(-bottom <= card:GetHeight() - 52, "every tint element fits inside its card")
        end
        truthy(panel.procTintGuide.wordWrap and panel.procTintLimit.wordWrap)
        for _, mode in ipairs({ "native", "timer" }) do
            Choose(controls.procArt_mode, mode)
            equal(card:IsShown(), false); equal(controls.procArt_alpha:IsVisible(), false)
            equal(controls.procArt_desaturation:IsVisible(), false)
            truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
        end
        Choose(controls.procArt_mode, "custom")
        truthy(card:IsShown()); equal(#state.errors, 0, locale)
    end
end)

test("Proc tint combines original partial and full desaturation with opacity for current and selected artwork", function()
    local env, addon, state, panel, controls, entry = Open()
    addon:SetProcRegionColor(entry, { r = .8, g = .4, b = .2 })
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 38, y = -91 } } } })
    local timerColor, timerPosition, typography = copy(addon:GetProcRegionColor(entry)),
        copy(addon:GetReminderPosition(entry)), copy(addon:GetReminderStyle(entry))
    ConfirmColor(env, state, controls, .2, .6, .85)
    local color = { r = .2, g = .6, b = .85 }
    truthy(addon:SetPreview("single", entry.id))
    controls.procGallery:Click()
    local tile = panel.procGallery.tiles[1]
    truthy(tile.asset)
    local asset = tile.asset
    tile:Click(); panel.procGallery:Hide()
    for _, useOwn in ipairs({ false, true }) do
        if useOwn then controls.procOwnArtwork:Click() end
        local frames, textures, groups = #state.frames, #state.textures, #state.animations
        for _, desaturation in ipairs({ 0, .45, 1 }) do
            for _, alpha in ipairs({ 0, .35, 1 }) do
                Drag(controls.procArt_desaturation, desaturation); Drag(controls.procArt_alpha, alpha)
                local appearance = addon:GetProcRegionAppearance(entry)
                equal(appearance.desaturation, desaturation); equal(appearance.alpha, alpha)
                equal(appearance.assetKey, not useOwn and asset.key or nil)
                same(appearance.artColor, color)
                local sample = addon.procPreviewArtworkFrames[entry.id]
                equal(sample.texture.desaturation, desaturation); equal(sample.alpha, alpha)
                same(sample.texture.vertexColor, { .2, .6, .85 })
                equal(sample.texture.texture, useOwn and entry.guide.texture or asset.textureID)
            end
        end
        equal(#state.frames, frames); equal(#state.textures, textures); equal(#state.animations, groups)
    end
    same(addon:GetProcRegionColor(entry), timerColor); same(addon:GetReminderPosition(entry), timerPosition)
    same(addon:GetReminderStyle(entry), typography)
    Choose(controls.procArt_colorMode, "native")
    local appearance = addon:GetProcRegionAppearance(entry)
    equal(appearance.artColor, nil); equal(appearance.desaturation, 1); equal(appearance.alpha, 1)
    same(addon.procPreviewArtworkFrames[entry.id].texture.vertexColor, { 1, 1, 1 })
    equal(#state.errors, 0)
end)

test("Proc tint picker drafts combine with numeric edits and cancel only their own unconfirmed color", function()
    local env, addon, state, _, controls, entry = Open()
    ConfirmColor(env, state, controls, .2, .3, .4)
    truthy(addon:SetPreview("single", entry.id))
    controls.procArtColor:Click(); state:pickerChange(.9, .6, .1)
    local session = addon.procColorPickerSession
    Drag(controls.procArt_desaturation, .75); Drag(controls.procArt_alpha, .55)
    equal(addon.procColorPickerSession, session, "numeric rows do not replace picker ownership")
    same(addon:GetProcRegionAppearance(entry).artColor, { r = .2, g = .3, b = .4 })
    local sample = addon.procPreviewArtworkFrames[entry.id]
    same(sample.texture.vertexColor, { .9, .6, .1 })
    equal(sample.texture.desaturation, .75); equal(sample.alpha, .55)
    env.ColorPickerFrame.Footer.CancelButton:Click()
    local saved = addon:GetProcRegionAppearance(entry)
    same(saved.artColor, { r = .2, g = .3, b = .4 })
    equal(saved.desaturation, .75); equal(saved.alpha, .55)
    same(sample.texture.vertexColor, { .2, .3, .4 })
    controls.procArtColor:Click(); state:pickerChange(.7, .4, .8)
    env.ColorPickerFrame.Footer.OkayButton:Click()
    saved = addon:GetProcRegionAppearance(entry)
    same(saved.artColor, { r = .7, g = .4, b = .8 })
    equal(saved.desaturation, .75); equal(saved.alpha, .55)
    controls.procArtColor:Click(); state:pickerChange(.1, .1, .1)
    Choose(controls.procArt_mode, "native")
    equal(addon.procColorPickerSession, nil); equal(addon.procArtworkColorPreview, nil)
    Choose(controls.procArt_mode, "custom")
    saved = addon:GetProcRegionAppearance(entry)
    same(saved.artColor, { r = .7, g = .4, b = .8 })
    equal(saved.desaturation, .75); equal(saved.alpha, .55)
    equal(#state.errors, 0)
end)

test("Proc tint persists only the selected region and artwork reset retains timer scope", function()
    local env, addon, state, panel, controls, entry = Open()
    local sibling
    for _, region in ipairs(addon:GetPreviewEntries()) do
        if region.kind == "proc" and region.id ~= entry.id then sibling = region; break end
    end
    truthy(sibling)
    local siblingBefore = copy(addon:GetProcRegionAppearance(sibling))
    addon:SetProcRegionColor(entry, { r = .4, g = .5, b = .6 })
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = -82, y = 26 } } } })
    ConfirmColor(env, state, controls, .7, .2, .4)
    Drag(controls.procArt_desaturation, 1); Drag(controls.procArt_alpha, .4)
    local saved = copy(addon:GetProcRegionAppearance(entry))
    same(addon:GetProcRegionAppearance(sibling), siblingBefore)
    local _, reloaded = h.login(copy(addon.db), false, { specID = 62, proc = {} })
    local fresh, freshControls = h.options(reloaded)
    reloaded:SelectOptionsCategory("proc")
    fresh.selectedProcEntry = entry.id; reloaded:RefreshOptions()
    same(reloaded:GetProcRegionAppearance(reloaded:GetSelectedProcColorEntry()), saved)
    equal(freshControls.procArt_desaturation:GetValue(), 1); equal(freshControls.procArt_alpha:GetValue(), .4)
    local timerColor, timerPosition = copy(addon:GetProcRegionColor(entry)), copy(addon:GetReminderPosition(entry))
    controls.procArtReset:Click()
    same(addon:GetProcRegionAppearance(entry), addon:NewProcAppearance())
    same(addon:GetProcRegionColor(entry), timerColor); same(addon:GetReminderPosition(entry), timerPosition)
    same(addon:GetProcRegionAppearance(sibling), siblingBefore)
    equal(panel.procArtworkSection:IsShown(), false)
    equal(controls.procArt_desaturation:GetValue(), 0); equal(controls.procArt_alpha:GetValue(), 1)
end)
