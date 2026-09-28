-- The real editor and catalog run against the existing native widget fixture.
-- Client rendering, gallery cropping and localized text wrapping still need QA.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open()
    local env, addon, state = h.login(nil, false, { specID = 62, proc = {} })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    return env, addon, state, panel, controls
end

local function Choose(control, value)
    control:Click()
    for _, button in ipairs(control.choices) do
        if button.value == value and button:IsShown() and button:IsEnabled() then
            button:Click()
            return
        end
    end
    error("Missing visible choice: " .. tostring(value))
end

local function Enter(control, value)
    control:SetText(tostring(value))
    control:GetScript("OnTextChanged")(control, true)
    control:GetScript("OnEnterPressed")(control)
end

test("appearance region editor progressively discloses only custom controls", function()
    local _, addon, _, panel, controls = Open()
    local entry = addon:GetSelectedProcColorEntry()
    equal(addon:GetProcRegionAppearance(entry).mode, "native")
    equal(panel.procArtworkSection:IsShown(), false)
    equal(panel.procTransformSection:IsShown(), false)
    equal(panel.procAnimationSection:IsShown(), false)
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    Choose(controls.procArt_mode, "custom")
    truthy(panel.procArtworkSection:IsShown()); truthy(panel.procTransformSection:IsShown())
    truthy(panel.procAnimationSection:IsShown())
    equal(panel.procAdvancedSection:IsShown(), false)
    local saved = copy(addon.db)
    controls.procAdvanced:Click()
    truthy(panel.procAdvancedSection:IsShown())
    same(addon.db, saved, "Advanced is session-only disclosure")
    Choose(controls.procArt_mode, "timer")
    equal(panel.procArtworkSection:IsShown(), false); equal(panel.procAdvancedSection:IsShown(), false)
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    Choose(controls.procArt_mode, "native")
    local _, reloaded = h.login(copy(addon.db), false, { specID = 62, proc = {} })
    local fresh = h.options(reloaded)
    equal(fresh.procSession.advanced, false, "a new UI session starts Basic")
end)

test("appearance Proc selector scopes visible stable regions and region switches discard drafts", function()
    local _, addon, _, panel, controls = Open()
    local seen = 0
    for _, proc in ipairs(controls.procSelector.choices) do
        local key = proc.value
        Choose(controls.procSelector, key)
        for _, region in ipairs(controls.procEntry.choices) do
            if region:IsShown() then
                truthy(region:IsEnabled())
                Choose(controls.procEntry, region.value)
                local entry = addon:GetSelectedProcColorEntry()
                equal(entry.id, region.value)
                equal(tostring(entry.overlayID or entry.sourceSpellID or entry.id), key)
                equal(entry.specID, 62)
                seen = seen + 1
            end
        end
    end
    truthy(seen > 1, "multiple real stable regions are selectable")
    Choose(controls.procSelector, controls.procSelector.choices[1].value)
    Choose(controls.procArt_mode, "custom")
    controls.procArt_alpha:SetText("0.25")
    controls.procArt_alpha:GetScript("OnTextChanged")(controls.procArt_alpha, true)
    local before = addon:GetSelectedProcColorEntry().id
    for _, region in ipairs(controls.procEntry.choices) do
        if region:IsShown() and region.value ~= before then
            Choose(controls.procEntry, region.value)
            equal(controls.procArt_alpha.dirty, false)
            equal(controls.procArt_alpha:GetText(), "1")
            return
        end
    end
    error("Expected a second region for this Proc")
end)

test("appearance gallery uses audited thumbnails bounded pages and cross-class assets", function()
    local _, addon, state, panel, controls = Open()
    Choose(controls.procArt_mode, "custom")
    controls.procGallery:Click()
    local gallery = panel.procGallery
    truthy(gallery:IsShown()); equal(#gallery.tiles, 9)
    local assets = addon:GetProcGalleryAssets("all")
    local foreign
    for _, asset in ipairs(assets) do
        equal(addon:GetProcAsset(asset.key), asset, "gallery only enumerates catalog entries")
        if asset.class ~= "MAGE" then foreign = asset end
    end
    truthy(foreign)
    for _, tile in ipairs(gallery.tiles) do
        if tile.asset then equal(tile.texture.texture, tile.asset.textureID, "client FileDataID thumbnail") end
    end
    local frameCount = #state.frames
    for _ = 1, 6 do
        gallery.next:Click(); gallery.previous:Click()
        gallery:Hide(); controls.procGallery:Click()
    end
    equal(#state.frames, frameCount, "one reusable bounded gallery grid")
    Choose(gallery.filter, foreign.class)
    equal(panel.procSession.galleryPage, 1, "filter resets to first page")
    local tile = gallery.tiles[1]
    local entry = addon:GetSelectedProcColorEntry()
    tile:Click()
    equal(addon:GetProcRegionAppearance(entry).assetKey, tile.asset.key)
    truthy(tile.selected:IsShown())
    equal(entry.class, "MAGE", "choosing artwork does not change trigger ownership")
    controls.procOwnArtwork:Click()
    equal(addon:GetProcRegionAppearance(entry).assetKey, nil)
    addon:SelectOptionsCategory("general")
    equal(gallery:IsShown(), false)
    equal(gallery.filter.menu:IsShown(), false)
end)

test("appearance controls separate artwork RGB offset typography and timer settings", function()
    local _, addon, _, panel, controls = Open()
    local entry = addon:GetSelectedProcColorEntry()
    truthy(addon:SetProcRegionColor(entry, { r = 0.1, g = 0.2, b = 0.3 }))
    truthy(addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 41, y = 72 } } } }))
    local timer = copy(addon:GetProcConfig().regions[entry.id])
    Choose(controls.procArt_mode, "custom")
    Choose(controls.procArt_colorMode, "custom")
    truthy(panel.procArtRGB:IsShown())
    controls.procArtRGB_r:SetText("0.8"); controls.procArtRGB_g:SetText("0.6")
    Enter(controls.procArtRGB_b, "0.4")
    controls.procAdvanced:Click()
    Enter(controls.procArt_offsetX, 125); Enter(controls.procArt_offsetY, -99)
    local appearance = addon:GetProcRegionAppearance(entry)
    same(appearance.artColor, { r = 0.8, g = 0.6, b = 0.4 })
    same(appearance.offset, { x = 125, y = -99 })
    same(addon:GetProcConfig().regions[entry.id].color, timer.color)
    same(addon:GetProcConfig().regions[entry.id].position, timer.position)
    Choose(controls.procArt_colorMode, "native")
    equal(addon:GetProcRegionAppearance(entry).artColor, nil)
    equal(panel.procArtRGB:IsShown(), false)
    controls.procAppearance:Click()
    equal(panel.activeCategory, "appearance")
    equal(panel.appearanceKind, "proc", "the existing specialization typography editor is reused")
end)

test("appearance reset changes only selected region artwork and validated edits never query Aura", function()
    local env, addon, _, panel, controls = Open()
    local entry = addon:GetSelectedProcColorEntry()
    addon:SetProcRegionColor(entry, { r = 0.2, g = 0.4, b = 0.6 })
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 14, y = 28 } } } })
    local prior = copy(addon.db)
    for key in pairs(env.C_UnitAuras or {}) do
        if type(env.C_UnitAuras[key]) == "function" then
            env.C_UnitAuras[key] = function() error("Appearance edit queried Aura") end
        end
    end
    Choose(controls.procArt_mode, "custom")
    Enter(controls.procArt_alpha, 0.7)
    Enter(controls.procArt_scale, 1.4)
    Enter(controls.procArt_alpha, "nan")
    equal(addon:GetProcRegionAppearance(entry).alpha, 0.7, "invalid numeric text cannot save")
    Enter(controls.procArt_alpha, 2)
    equal(addon:GetProcRegionAppearance(entry).alpha, 0.7, "numeric bounds enforced in UI")
    Choose(controls.procArt_active, "breathe")
    controls.procArtReset:Click()
    same(addon.db, prior, "appearance reset preserves timer RGB/XY typography and Proc enabled")
    equal(addon:GetProcRegionAppearance(entry).mode, "native")
    equal(panel.procArtworkSection:IsShown(), false)
end)

test("appearance preview button uses selected independent Test lifecycle", function()
    local _, addon, _, panel, controls = Open()
    local entry = addon:GetSelectedProcColorEntry()
    Choose(controls.procArt_mode, "custom")
    controls.procPreview:Click()
    equal(addon.previewState.mode, "single")
    truthy(addon.previewFrames[entry.id]:IsShown())
    controls.procStop:Click()
    equal(addon.previewState.mode, "off")
    equal(addon.previewFrames[entry.id]:IsShown(), false)
    equal(panel.selectedProcEntry, entry.id)
end)
