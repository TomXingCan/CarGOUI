-- Contextual controls use the existing preview engine and keep each editor local.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function Open()
    local env, addon, state = h.mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20 }, { specID = 62, proc = {} })
    local panel, controls = h.options(addon)
    return env, addon, state, panel, controls
end

local function UserText(edit, text)
    edit:SetText(text)
    edit:GetScript("OnTextChanged")(edit, true)
end

local function Enter(edit, text)
    UserText(edit, text)
    edit:GetScript("OnEnterPressed")(edit)
end

local function Descendant(frame, ancestor)
    while frame do
        if frame == ancestor then return true end
        frame = frame.GetParent and frame:GetParent() or nil
    end
    return false
end

local function VisibleSamples(addon)
    local count = 0
    for _, frame in pairs(addon.previewFrames) do
        if frame:IsShown() then count = count + 1 end
    end
    return count
end

test("contextual General owns only character interface window and all-entry quick testing", function()
    local _, addon, _, panel, controls = Open()
    equal(#panel.generalSections, 3)
    for _, key in ipairs({ "enabled", "x", "y", "centerPosition", "previewEntry", "previewSingle",
        "previewAll", "previewStop", "entryX", "entryY", "entryReset" }) do
        equal(controls[key], nil, "obsolete setting and Test page controls are absent")
    end
    for _, key in ipairs({ "mobilityEnabled", "mobilityX", "mobilityY", "mobilityReset" }) do
        truthy(Descendant(controls[key], panel.pages.mobility), "ordinary Mobility has one page owner")
        equal(Descendant(controls[key], panel.pages.general), false)
    end
    for _, key in ipairs({ "generalTest", "generalStop", "showMinimapIcon", "animatedTitle", "centerOptions" }) do
        truthy(Descendant(controls[key], panel.pages.general))
    end
    truthy(panel.generalCharacter:GetText():find(addon:GetLocalizedClassName(), 1, true))
    equal(addon.optionsPageRegistry.preview, nil); equal(panel.pages.preview, nil)
    equal(panel.categoryButtons.preview, nil); equal(addon.optionsPageRegistry.classTools, nil)
    local keys = {}
    for _, button in ipairs(panel.categories) do keys[#keys + 1] = button.key end
    same(keys, { "general", "mobility", "proc", "importExport" })
    local preview, calls = addon.SetPreview, {}
    addon.SetPreview = function(self, mode, entry, style)
        calls[#calls + 1] = { mode = mode, entry = entry, style = style }
        return preview(self, mode, entry, style)
    end
    local before = copy(addon.db)
    controls.generalTest:Click()
    equal(calls[1].mode, "all"); equal(calls[1].entry, nil)
    equal(addon.previewState.mode, "all"); equal(panel.activeCategory, "general")
    equal(VisibleSamples(addon), #addon:GetPreviewEntries())
    controls.generalStop:Click()
    equal(addon.previewState.mode, "off"); equal(VisibleSamples(addon), 0)
    same(addon.db, before, "quick tests are transient")
end)

test("contextual Mobility Proc and typography tests replace samples without changing the active page", function()
    local _, addon, _, panel, controls = Open()
    controls.generalTest:Click()
    addon:SelectOptionsCategory("mobility")
    controls.mobilityPreview:Click()
    equal(panel.activeCategory, "mobility")
    equal(addon.previewState.mode, "single")
    equal(addon.previewState.entryId, addon:GetMobilityEntry().id)
    equal(VisibleSamples(addon), 1, "single Mobility replaces the all-context test")
    controls.mobilityStop:Click(); equal(VisibleSamples(addon), 0)
    addon:SelectOptionsCategory("proc")
    controls.procPreview:Click()
    equal(panel.activeCategory, "proc")
    equal(addon.previewState.mode, "single")
    equal(addon.previewState.entryId, panel.selectedProcEntry)
    equal(VisibleSamples(addon), 1)
    controls.procStop:Click(); equal(VisibleSamples(addon), 0)
    controls.procAppearance:Click()
    controls.appearancePreview:Click()
    equal(panel.activeCategory, "appearance", "typography preview stays in its detail editor")
    equal(addon.previewState.mode, "single")
    equal(addon.previewState.styleKey, panel.selectedAppearanceKey)
    controls.appearanceBack:Click()
    equal(panel.activeCategory, "proc")
    controls.procStop:Click(); equal(VisibleSamples(addon), 0)
end)

test("contextual Free Move position remains independent atomic and previewed from Mobility", function()
    local _, addon, _, panel, controls = Open()
    addon:SelectOptionsCategory("mobility")
    local free = assert(addon:GetFreeMovePreviewEntry())
    truthy(panel.freeMoveSection:IsShown()); equal(panel.freeMoveEntryId, free.id)
    UserText(controls.freeMoveX, "240"); Enter(controls.freeMoveY, "-31")
    same(addon:GetReminderPosition(free), { anchor = "CENTER", x = 240, y = -31 })
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 0, y = 0 })
    UserText(controls.mobilityX, "-117"); Enter(controls.mobilityY, "53")
    same(addon:GetReminderPosition(free), { anchor = "CENTER", x = 240, y = -31 })
    local before = copy(addon.db)
    UserText(controls.freeMoveX, "999"); Enter(controls.freeMoveY, "bad")
    same(addon.db, before, "invalid independent position is an atomic rejection")
    controls.freeMoveReset:Click()
    same(addon:GetReminderPosition(free), { anchor = "CENTER", x = 0, y = 0 })
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = -117, y = 53 })
    Enter(controls.freeMoveX, "150")
    controls.mobilityReset:Click()
    equal(addon:GetReminderPosition(free).x, 150, "ordinary reset cannot reset Free Move")
    controls.mobilityPreview:Click(); controls.freeMovePreview:Click()
    equal(panel.activeCategory, "mobility")
    equal(addon.previewState.mode, "single"); equal(addon.previewState.entryId, free.id)
    equal(VisibleSamples(addon), 1)
    controls.mobilityStop:Click(); equal(VisibleSamples(addon), 0)
    UserText(controls.freeMoveX, "450")
    addon:CloseOptions(); addon:OpenOptions()
    equal(tonumber(controls.freeMoveX:GetText()), 150, "closing discards the unsubmitted independent draft")
    local _, reloaded = h.login(copy(addon.db), false, { specID = 62, proc = {} })
    equal(reloaded:GetReminderPosition(reloaded:GetFreeMovePreviewEntry()).x, 150)
end)

test("contextual unavailable Free Move hides its whole card and stale controls cannot commit", function()
    local _, addon, _, panel, controls = Open()
    addon:SelectOptionsCategory("mobility")
    local original, available = addon.GetPreviewEntries, false
    addon.GetPreviewEntries = function(self)
        local entries = {}
        for _, entry in ipairs(original(self)) do
            if available or not entry.freeMove then entries[#entries + 1] = entry end
        end
        return entries
    end
    controls.freeMoveX:SetFocus(); UserText(controls.freeMoveX, "444")
    addon:RefreshOptions()
    equal(panel.freeMoveSection:IsShown(), false); equal(panel.freeMoveEntryId, nil)
    equal(controls.freeMoveX:HasFocus(), false)
    for _, key in ipairs({ "freeMoveX", "freeMoveY", "freeMoveReset", "freeMovePreview" }) do
        equal(controls[key]:IsEnabled(), false)
    end
    local before = copy(addon.db)
    controls.freeMoveX:GetScript("OnEnterPressed")(controls.freeMoveX)
    controls.freeMoveReset:Click(); controls.freeMovePreview:Click()
    same(addon.db, before); equal(addon.previewState.mode, "off")
    equal(panel.mobilityEditor:GetHeight(), 424)
    available = true; addon:RefreshOptions()
    truthy(panel.freeMoveSection:IsShown()); truthy(controls.freeMoveX:IsEnabled())
    equal(tonumber(controls.freeMoveX:GetText()), 0, "obsolete draft does not reappear")
    addon.GetPreviewEntries = function() return {} end
    addon:RefreshOptions()
    equal(controls.generalTest:IsEnabled(), false)
    equal(panel.freeMoveSection:IsShown(), false)
end)

test("contextual tests stop immediately at close Escape combat and specialization boundaries", function()
    for _, boundary in ipairs({ "close", "escape", "combat", "spec" }) do
        local _, addon, state, panel, controls = Open()
        addon:SelectOptionsCategory("mobility")
        controls.mobilityPreview:Click(); truthy(VisibleSamples(addon) > 0)
        controls.mobilityX:SetFocus()
        if boundary == "close" then controls.close:Click()
        elseif boundary == "escape" then controls.mobilityX:GetScript("OnEscapePressed")(controls.mobilityX)
        elseif boundary == "combat" then state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
        else state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player") end
        equal(addon.previewState.mode, "off", boundary .. " stops the shared engine synchronously")
        equal(VisibleSamples(addon), 0)
        equal(controls.mobilityX:HasFocus(), false)
        for _, frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"), nil) end
        if boundary ~= "spec" then equal(panel:IsShown(), false) end
        equal(#state.errors, 0)
    end
end)
