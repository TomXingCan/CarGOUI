-- These are native-widget model checks, not screenshots or glyph acceptance.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open(locale)
    local env, addon, state = h.login(nil, false, { specID = 62, proc = {}, locale = locale or "enUS" })
    local panel, controls = h.options(addon)
    addon:SelectOptionsCategory("proc")
    return env, addon, state, panel, controls
end

local function Finish(group)
    if not group then return end
    group:Stop()
    local callback = group:GetScript("OnFinished")
    if callback then callback(group) end
end

local function Choose(control, value)
    if control.menu then control:Click(); Finish(control.menu.openAnimation) end
    for _, choice in ipairs(control.choices) do
        if choice.value == value and choice:IsShown() and choice:IsEnabled() then
            choice:Click()
            if control.menu then Finish(control.menu.closeAnimation) end
            return
        end
    end
    error("Missing visible modern choice: " .. tostring(value))
end

local function UserText(edit, text)
    edit:SetText(text)
    local changed = edit:GetScript("OnTextChanged")
    if changed then changed(edit, true) end
end

local function Enter(edit, text)
    UserText(edit, text)
    edit:GetScript("OnEnterPressed")(edit)
end

local function Descendant(frame, parent)
    while frame do
        if frame == parent then return true end
        frame = frame.GetParent and frame:GetParent() or nil
    end
    return false
end

local function AssertOwnedWidgets(state, parent)
    local forbidden = { UIPanelButtonTemplate = true, UICheckButtonTemplate = true,
        InputBoxTemplate = true, UIPanelScrollFrameTemplate = true }
    for _, frame in ipairs(state.frames) do
        if Descendant(frame, parent) then
            truthy(not forbidden[frame.template], "modern page must own its visible widget skin")
            equal(frame:GetScript("OnUpdate"), nil, "modern page does not poll")
            if frame.cuiKind == "button" then
                truthy(frame.textLabel.wordWrap, "full button labels deliberately wrap")
                truthy(frame.textLabel:GetWidth() > 0 and frame.textLabel:GetWidth() <= frame:GetWidth())
                truthy(frame.textLabel:GetHeight() >= 24, "button reserves two native text lines")
            end
        end
    end
end

test("modern Proc page composes section hierarchy segmented modes and session-only disclosure", function()
    local _, addon, state, panel, controls = Open()
    equal(panel.pages.proc:GetWidth(), 660)
    equal(panel.procScroll:GetWidth(), 640)
    equal(panel.procEditor:GetWidth(), 640)
    equal(panel.procContextSection.content:GetWidth(), 616)
    truthy(panel.procScroll.scrollBar and panel.procScroll.thumb)
    equal(controls.procArt_mode.menu, nil, "mode choices are a real reusable segmented control")
    equal(#controls.procArt_mode.choices, 3)
    Choose(controls.procArt_mode, "custom")
    local before = copy(addon.db)
    equal(panel.procAdvancedSection.collapsed, true)
    truthy(panel.procAdvancedSection:IsShown(), "Basic retains the Advanced section heading")
    equal(panel.procAdvancedSection.content:IsShown(), false)
    controls.procAdvanced:Click()
    equal(panel.procAdvancedSection.collapsed, false)
    truthy(panel.procAdvancedSection.content:IsShown())
    same(addon.db, before, "disclosure remains transient UI state")
    local cards = { panel.procContextSection, panel.procDisplaySection, panel.procArtworkSection,
        panel.procTransformSection, panel.procAnimationSection, panel.procTimerSection,
        panel.procPositionSection, panel.procAdvancedSection }
    local previousBottom = 1
    for _, card in ipairs(cards) do
        equal(card.cuiKind, "section")
        equal(card:GetWidth(), 640); equal(card.content:GetWidth(), 616)
        local _, _, _, x, y = card:GetPoint()
        equal(x, 0)
        truthy(y < previousBottom, "ordered cards never overlap")
        previousBottom = y - card:GetHeight()
    end
    panel.procScroll:GetScript("OnMouseWheel")(panel.procScroll, -3)
    truthy(panel.procScroll:GetVerticalScroll() > 0, "custom thin scrollbar supports the wheel")
    Choose(controls.procArt_mode, "timer")
    equal(panel.procArtworkSection:IsShown(), false)
    equal(panel.procAdvancedSection:IsShown(), false)
    truthy(panel.procTimerSection:IsShown()); truthy(panel.procPositionSection:IsShown())
    AssertOwnedWidgets(state, panel.pages.proc)
end)

test("modern artwork inputs and toggles preserve validation Enter semantics and independent timer settings", function()
    local _, addon, _, panel, controls = Open()
    local entry = addon:GetSelectedProcColorEntry()
    addon:SetProcRegionColor(entry, { r = 0.1, g = 0.3, b = 0.5 })
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 18, y = -30 } } } })
    local timer = copy(addon:GetProcConfig().regions[entry.id])
    Choose(controls.procArt_mode, "custom")
    UserText(controls.procArt_alpha, "0.45")
    equal(addon:GetProcRegionAppearance(entry).alpha, 1, "typing alone does not save")
    controls.procArt_alpha:GetScript("OnEnterPressed")(controls.procArt_alpha)
    equal(addon:GetProcRegionAppearance(entry).alpha, 0.45)
    Enter(controls.procArt_alpha, "5")
    equal(controls.procArt_alpha.invalid, true)
    equal(addon:GetProcRegionAppearance(entry).alpha, 0.45)
    controls.procAdvanced:Click()
    truthy(controls.procArt_mirrorX.track and controls.procArt_mirrorX.thumb and controls.procArt_mirrorX.accent)
    controls.procArt_mirrorX:Click()
    equal(addon:GetProcRegionAppearance(entry).mirrorX, true)
    Enter(controls.procArt_offsetX, "123")
    same(addon:GetProcConfig().regions[entry.id].position, timer.position)
    same(addon:GetProcConfig().regions[entry.id].color, timer.color)
    addon:SelectOptionsCategory("general")
    equal(controls.procArt_alpha.invalid, false, "discarded draft does not retain an invalid border")
end)

test("modern gallery tiles retain audited paging selection and bounded object reuse", function()
    local _, addon, state, panel, controls = Open()
    Choose(controls.procArt_mode, "custom")
    controls.procGallery:Click()
    local gallery = panel.procGallery
    equal(#gallery.tiles, 9)
    equal(gallery:GetWidth(), 650)
    truthy(gallery.cuiSkin)
    local count = #state.frames
    for _ = 1, 5 do
        gallery.next:Click(); gallery.previous:Click()
        gallery:Hide(); controls.procGallery:Click()
    end
    equal(#state.frames, count)
    local tile = gallery.tiles[1]
    truthy(tile.cuiSkin and tile.SetSelected)
    tile:Click()
    equal(tile.selected, true)
    truthy(tile.selectionLabel:IsShown())
    equal(addon:GetProcRegionAppearance(addon:GetSelectedProcColorEntry()).assetKey, tile.asset.key)
    for _, item in ipairs(gallery.tiles) do
        if item.asset then
            equal(item.texture.texture, item.asset.textureID)
            truthy(item.texture:GetWidth() <= 168 and item.texture:GetHeight() <= 74)
            equal(item.label.wordWrap, true)
            truthy(item.label:GetWidth() <= item:GetWidth() and item.label:GetHeight() >= 30)
        end
    end
    AssertOwnedWidgets(state, gallery)
end)

test("modern transfer editors retain read-only exports typing cancellation and explicit confirmation", function()
    local _, addon, state, panel, controls = Open()
    addon:SelectOptionsCategory("importExport")
    local transfer = panel.transfer
    for _, key in ipairs({ "transferOutput", "transferInput", "transferSummary" }) do
        local edit = controls[key]
        equal(edit.cuiKind, "input"); truthy(edit.cuiSkin)
        truthy(edit.scroll.scrollBar and edit.scroll.thumb)
        truthy(edit:GetWidth() < edit.scroll:GetWidth())
        equal(edit.maxLetters, 0); equal(edit.maxBytes, 0)
    end
    local before = copy(addon.db)
    controls.transferExport:Click()
    local exported = controls.transferOutput:GetText()
    truthy(exported:match("^CARGOUICFG:1:"))
    UserText(controls.transferOutput, "changed output")
    equal(controls.transferOutput:GetText(), exported)
    UserText(controls.transferInput, exported)
    equal(transfer.transaction, nil)
    same(addon.db, before, "typing does not parse or commit")
    controls.transferImport:Click()
    truthy(transfer.transaction and transfer.confirmation:IsShown())
    UserText(controls.transferInput, exported .. " ")
    equal(transfer.transaction, nil, "replacing reviewed text invalidates confirmation")
    equal(controls.transferConfirm:IsEnabled(), false)
    same(addon.db, before)
    UserText(controls.transferInput, exported)
    controls.transferImport:Click(); controls.transferConfirm:Click()
    equal(transfer.transaction, nil)
    truthy(addon:HasSettingsImportBackup(), "only explicit confirmation creates a backup")
    AssertOwnedWidgets(state, panel.pages.importExport)
end)

test("modern pages construct bounded wrapped layouts across eight locales and unsupported fallback", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU", "koKR" }) do
        local _, addon, state, panel, controls = Open(locale)
        if locale == "koKR" then equal(addon.locale, "enUS", "unsupported UI locale safely uses English") end
        Choose(controls.procArt_mode, "custom")
        for _, key in ipairs({ "procArt_entrance", "procArt_active", "procArt_exit" }) do
            local control = controls[key]
            truthy(control:GetWidth() < 200 and control:GetWidth() > 190)
            truthy(control.label.wordWrap and control.label:GetWidth() <= control:GetWidth())
            truthy(control.textLabel.wordWrap and control.textLabel:GetHeight() >= 24)
            local _, _, _, x = control:GetPoint()
            truthy(x >= 0 and x + control:GetWidth() <= 616.01, "three-column controls stay within their card")
        end
        for _, key in ipairs({ "general", "mobility", "preview", "appearance", "importExport" }) do
            addon:SelectOptionsCategory(key)
            equal(panel.pages[key]:GetWidth(), 660)
            AssertOwnedWidgets(state, panel.pages[key])
        end
        for _, section in ipairs(panel.transfer.sections) do
            truthy(section.title.wordWrap)
            truthy(section.title:GetWidth() <= section:GetWidth() - 24)
            equal(section:GetWidth(), 660); equal(section.content:GetWidth(), 636)
        end
        for _, key in ipairs({ "transferExport", "transferSelectAll", "transferImport", "transferRestore", "transferConfirm", "transferCancel" }) do
            local control = controls[key]
            truthy(control.textLabel.wordWrap)
            equal(control:GetText(), addon.L[key], "localized text is preserved without byte truncation")
            local _, _, _, x = control:GetPoint()
            truthy(x + control:GetWidth() <= 636, "localized transfer control stays in its section")
        end
        equal(#state.errors, 0, "all locale models construct without errors")
    end
end)
