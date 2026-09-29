-- Shared native picker tests exercise explicit confirmation and ownership.
-- Mock colors are public samples, not evidence of real client pixel rendering.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open(client)
    local env, addon, state = h.login(nil, false, client or { specID = 62, proc = {} })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    local entry = addon:GetSelectedProcColorEntry()
    truthy(addon:SetProcRegionAppearance(entry, { mode = "custom" }))
    return env, addon, state, panel, controls, entry
end

local function Choose(control, value)
    if control.menu then control:Click() end
    for _, row in ipairs(control.choices) do
        if row.value == value and row:IsShown() and row:IsEnabled() then row:Click(); return end
    end
    error("Missing choice: " .. tostring(value))
end

local function Presentation(addon, entry)
    local _, asset = addon:ResolveProcAppearance(entry, nil, nil, true)
    return asset and asset.color
end

test("ARTWORK PICKER Custom choice opens a native draft and unchanged Okay commits an explicit color", function()
    local env, addon, _, _, controls, entry = Open()
    local before = copy(addon.db)
    for _, channel in ipairs({ "r", "g", "b" }) do equal(controls["procArtRGB_" .. channel], nil) end
    Choose(controls.procArt_colorMode, "custom")
    truthy(env.ColorPickerFrame:IsShown())
    equal(addon.procColorPickerSession.target, "artwork")
    same(addon.db, before, "opening a custom color draft never writes settings")
    equal(addon:GetProcRegionAppearance(entry).artColor, nil)
    same(Presentation(addon, entry), { r = 1, g = 1, b = 1 })
    env.ColorPickerFrame.Footer.OkayButton:Click()
    same(addon:GetProcRegionAppearance(entry).artColor, { r = 1, g = 1, b = 1 })
    equal(addon.procColorPickerSession, nil); equal(addon.procArtworkColorPreview, nil)
    equal(addon:GetProcRegionColor(entry), nil, "artwork confirmation never sets the timer color")
    Choose(controls.procArt_colorMode, "native")
    equal(addon:GetProcRegionAppearance(entry).artColor, nil)
end)

test("ARTWORK PICKER swatch previews samples without DB writes and Cancel restores the committed appearance", function()
    local env, addon, state, _, controls, entry = Open()
    addon:SetProcRegionColor(entry, { r = .1, g = .2, b = .3 })
    addon:SetProcRegionAppearance(entry, { artColor = { r = .3, g = .4, b = .5 } })
    addon:SetPreview("single", entry.id)
    local before = copy(addon.db)
    controls.procArtColor:Click()
    state:pickerChange(.8, .6, .4)
    same(addon.db, before)
    same(addon:GetProcRegionAppearance(entry).artColor, { r = .3, g = .4, b = .5 })
    same(Presentation(addon, entry), { r = .8, g = .6, b = .4 })
    same(controls.procArtColor.swatch.color, { .8, .6, .4, 1 })
    same(addon.procPreviewArtworkFrames[entry.id].texture.vertexColor, { .8, .6, .4 })
    same(addon.previewFrames[entry.id].text.textColor, { .1, .2, .3, 1 })
    env.ColorPickerFrame.Footer.CancelButton:Click()
    same(addon.db, before)
    same(Presentation(addon, entry), { r = .3, g = .4, b = .5 })
    same(controls.procArtColor.swatch.color, { .3, .4, .5, 1 })
    equal(addon.procArtworkColorPreview, nil)
end)

test("ARTWORK PICKER timer and artwork sessions replace each other without cross-owner commits", function()
    local env, addon, state, _, controls, entry = Open()
    addon:SetProcRegionColor(entry, { r = .1, g = .2, b = .3 })
    controls.procArtColor:Click(); state:pickerChange(.8, .6, .4)
    local staleArtwork = env.ColorPickerFrame.swatchFunc
    controls.procColor:Click()
    equal(addon.procColorPickerSession.target, "timer"); equal(addon.procArtworkColorPreview, nil)
    staleArtwork(); state:pickerChange(.2, .7, .9)
    env.ColorPickerFrame.Footer.OkayButton:Click()
    same(addon:GetProcRegionColor(entry), { r = .2, g = .7, b = .9 })
    equal(addon:GetProcRegionAppearance(entry).artColor, nil)
    controls.procColor:Click(); state:pickerChange(.4, .4, .4)
    local staleTimer = env.ColorPickerFrame.swatchFunc
    controls.procArtColor:Click(); equal(addon.procRegionColorPreview, nil)
    staleTimer(); state:pickerChange(.9, .3, .1)
    env.ColorPickerFrame.Footer.OkayButton:Click()
    same(addon:GetProcRegionAppearance(entry).artColor, { r = .9, g = .3, b = .1 })
    same(addon:GetProcRegionColor(entry), { r = .2, g = .7, b = .9 })
    equal(addon.procArtworkColorPreview, nil); equal(addon.procRegionColorPreview, nil)
end)

test("ARTWORK PICKER seeds from current public SHOW and updates live owned artwork without timer changes", function()
    local env, addon, state, panel, controls = Open({ specID = 63, proc = {} })
    panel.selectedProcEntry = "mage_fire_hot_streak_left"; addon:RefreshOptions()
    local entry = addon:GetSelectedProcColorEntry()
    addon:SetProcRegionAppearance(entry, { mode = "custom" })
    local root, position = env.SpellActivationOverlayFrame, env.Enum.ScreenLocationType.Left
    root.overlaysInUse = {}
    function root:ShowOverlay(owner, texture, location)
        local nativeTexture = { alpha = 1 }
        function nativeTexture:SetAlpha(value) self.alpha = value end
        function nativeTexture:GetVertexColor() error("picker must not inspect native texture color") end
        self.overlaysInUse[owner] = self.overlaysInUse[owner] or {}
        self.overlaysInUse[owner][location] = { spellID = owner, position = location, texture = nativeTexture }
    end
    function root:ReleaseOverlay(overlay) self.overlaysInUse[overlay.spellID][overlay.position] = nil end
    truthy(addon:InstallProcArtworkHooks())
    root:ShowOverlay(48108, 449490, position, 1, 51, 102, 153)
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", 48108, 449490, env.Enum.ScreenLocationType.LeftRight, 1, 51, 102, 153)
    local before, bindings = copy(addon.db), #state.bindings
    controls.procArtColor:Click()
    same(env.ColorPickerFrame.rgb, { .2, .4, .6 }, "only current public event RGB seeds the native picker")
    state:pickerChange(.9, .1, .3)
    same(addon.procArtworkFrames[entry.id].texture.vertexColor, { .9, .1, .3 })
    same(addon.db, before); equal(#state.bindings, bindings)
    env.ColorPickerFrame.Footer.CancelButton:Click()
    same(addon.procArtworkFrames[entry.id].texture.vertexColor, { .2, .4, .6 })
    same(addon.db, before)
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    controls.procArtColor:Click()
    same(env.ColorPickerFrame.rgb, { 1, 1, 1 }, "expired SHOW color never seeds a new draft")
    env.ColorPickerFrame.Footer.CancelButton:Click()
end)

test("ARTWORK PICKER region page spec close and combat boundaries discard the matching draft", function()
    for _, boundary in ipairs({ "region", "page", "spec", "close", "escape", "combat", "mode", "reset" }) do
        local env, addon, state, panel, controls, entry = Open()
        local before = copy(addon:GetProcConfig().regions[entry.id])
        controls.procArtColor:Click(); state:pickerChange(.8, .3, .2)
        local stale = env.ColorPickerFrame.swatchFunc
        if boundary == "region" then
            local nextID
            for _, row in ipairs(controls.procEntry.choices) do if row.value ~= entry.id and row:IsShown() then nextID = row.value; break end end
            truthy(nextID); Choose(controls.procEntry, nextID)
        elseif boundary == "page" then addon:SelectOptionsCategory("general")
        elseif boundary == "spec" then state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
        elseif boundary == "close" then panel:Hide()
        elseif boundary == "escape" then
            -- Without a numeric editor focused, native Escape closes the
            -- registered special frame. Numeric Escape has its own cancel test.
            local registered = false
            for _, name in ipairs(env.UISpecialFrames) do if env[name] == panel then registered = true end end
            truthy(registered)
            panel:Hide()
        elseif boundary == "combat" then state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
        elseif boundary == "mode" then Choose(controls.procArt_mode, "timer")
        elseif boundary == "reset" then controls.procArtReset:Click() end
        stale()
        equal(addon.procColorPickerSession, nil, boundary)
        equal(addon.procArtworkColorPreview, nil, boundary)
        truthy(not env.ColorPickerFrame:IsShown(), boundary)
        local region = addon.db.classes.MAGE.proc[62].regions[entry.id]
        equal(region.appearance and region.appearance.artColor, nil, boundary .. " cannot commit the draft")
        if boundary ~= "mode" and boundary ~= "reset" then same(region, before, boundary .. " preserves the region") end
    end
end)

test("ARTWORK PICKER generic native hiding and foreign replacement cannot accept a draft", function()
    local env, addon, state, panel, controls, entry = Open()
    local before = copy(addon.db)
    controls.procArtColor:Click(); state:pickerChange(.8, .2, .4)
    env.ColorPickerFrame:Hide()
    same(addon.db, before); equal(addon.procArtworkColorPreview, nil)
    controls.procArtColor:Click(); state:pickerChange(.3, .7, .2)
    local picker, stale, owner = env.ColorPickerFrame, env.ColorPickerFrame.swatchFunc, {}
    local foreignSwatch, foreignCancel = function() end, function() error("foreign cancel must not run") end
    picker:SetupColorPickerAndShow({ r = .5, g = .5, b = .5, extraInfo = owner,
        swatchFunc = foreignSwatch, cancelFunc = foreignCancel })
    stale(); addon:CancelProcColorPicker(); panel:Hide()
    truthy(picker:IsShown()); equal(picker.extraInfo, owner)
    equal(picker.swatchFunc, foreignSwatch); equal(picker.cancelFunc, foreignCancel)
    equal(addon.procArtworkColorPreview, nil); same(addon.db, before)
    equal(addon:GetProcRegionAppearance(entry).artColor, nil)
end)

test("ARTWORK PICKER validation and unavailable capabilities never write a draft or saved color", function()
    local env, addon, state, _, controls, entry = Open()
    controls.procArtColor:Click()
    local before, draft = copy(addon.db), copy(addon.procArtworkColorPreview)
    for _, rgb in ipairs({ { 0/0, .2, .3 }, { -1, .2, .3 }, { .2, math.huge, .3 }, { h.secret(.4), .2, .3 } }) do
        env.ColorPickerFrame.rgb = rgb; env.ColorPickerFrame.swatchFunc()
        same(addon.procArtworkColorPreview, draft); same(addon.db, before)
    end
    env.ColorPickerFrame.Footer.CancelButton:Click()
    local _, unavailable, _, _, unavailableControls, unavailableEntry = Open({ specID = 62, proc = {}, pickerUnavailable = true })
    truthy(not unavailableControls.procArtColor:IsEnabled())
    local saved = copy(unavailable.db)
    equal(unavailable:OpenProcColorPicker(unavailableEntry, "artwork"), false)
    same(unavailable.db, saved)
    equal(unavailable.procArtworkColorPreview, nil)
end)

test("ARTWORK PICKER draft remains outside exported settings and performs no gameplay queries", function()
    local env, addon, state, _, controls, entry = Open()
    local encodedBefore = assert(addon:ExportSettings("all"))
    local before = copy(addon.db)
    local bindings = #state.bindings
    for key, value in pairs(env.C_UnitAuras or {}) do
        if type(value) == "function" then env.C_UnitAuras[key] = function() error("artwork draft queried Aura") end end
    end
    controls.procArtColor:Click(); state:pickerChange(.7, .1, .8)
    same(addon.db, before)
    same(h.unpackSettings(env, assert(addon:ExportSettings("all"))), h.unpackSettings(env, encodedBefore))
    equal(#state.bindings, bindings, "artwork drafts never rebind timer durations")
    env.ColorPickerFrame.Footer.CancelButton:Click()
    same(addon.db, before); equal(addon:GetProcRegionAppearance(entry).artColor, nil)
end)
