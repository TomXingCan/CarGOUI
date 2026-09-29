-- Real shell/page code runs against the ordinary Lua 5.1 UI fixture. Geometry
-- checks cover layout contracts, not native font shaping or pixel screenshots.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy

local function keys(descriptors)
    local result = {}
    for _, descriptor in ipairs(descriptors) do result[#result + 1] = descriptor.key end
    return result
end

local function settled(panel)
    truthy(not panel.titleAnimation:IsPlaying(), "branding loop is stopped")
    for _, record in ipairs(panel.cuiMotion or {}) do
        truthy(not record.group:IsPlaying(), "owned control animation is stopped")
    end
    for _, dropdown in ipairs(panel.dropdowns) do
        truthy(not dropdown.menu:IsShown(), "no hidden-page menu remains visible")
        equal(dropdown.menu.cuiInteractive, false, "closed menu has no active input ownership")
        equal(dropdown.menu:IsMouseEnabled(), false, "closed menu releases its mouse input")
    end
end

test("MODERN SHELL registry builds only production pages in deterministic navigation order", function()
    local _, addon = h.login()
    same(keys(addon:GetOptionsPageDescriptors()), { "general", "mobility", "proc", "importExport", "appearance" })
    equal(addon.optionsPageRegistry.preview, nil, "Test Mode has no production descriptor")
    equal(addon.optionsPageRegistry.classTools, nil, "future Class Tools has no production descriptor")
    local panel = h.options(addon)
    same(keys(panel.categories), { "general", "mobility", "proc", "importExport" })
    equal(panel.categoryButtons.preview, nil); equal(panel.pages.preview, nil)
    equal(panel.categoryButtons.classTools, nil)
    equal(panel.categoryButtons.appearance, nil, "typography is a contextual hidden route")
    truthy(panel.pages.general.built and panel.pages.mobility.built and panel.pages.proc.built)
    equal(panel.pages.importExport, nil, "transfer editor stays lazy until its builder is selected")
    addon:SelectOptionsCategory("importExport")
    truthy(panel.pages.importExport.built and panel.transfer, "descriptor builder creates a real transfer editor")
    truthy(panel.categoryButtons.importExport.selected)
    addon:OpenAppearance("mobility")
    equal(panel.activeCategory, "appearance")
    truthy(panel.categoryButtons.mobility.selected, "hidden page delegates selected navigation to navParent")
    truthy(not panel.categoryButtons.importExport.selected)
    equal(panel.categoryButtons.mobility:GetText(), addon.L.mobility, "selection uses owned skin rather than text prefixes")
end)

test("MODERN SHELL future page builders register without changing layout or navigation implementation", function()
    local _, addon = h.login()
    local built = {}
    truthy(addon:RegisterOptionsPage({ key = "mockClassTools", order = 25, title = "Future tools fixture",
        builder = function(self, panel, page)
            built.mockClassTools = (built.mockClassTools or 0) + 1
            page.fixture = self.CUI.Segmented(panel, page, "Fixture scope", 0, -40, page:GetWidth(), {
                { value = "common", label = "Common Tools" }, { value = "spec", label = "Spec Tools" },
            }, function(value) page.fixture:SelectValue(value) end)
            page.fixture:SelectValue("common")
        end }))
    local panel = h.options(addon)
    local grid, width, height = copy(panel.shellGrid), panel:GetWidth(), panel:GetHeight()
    same(keys(panel.categories), { "general", "mobility", "mockClassTools", "proc", "importExport" })
    addon:SelectOptionsCategory("mockClassTools")
    truthy(panel.pages.mockClassTools:IsShown() and panel.pages.mockClassTools.fixture)
    equal(built.mockClassTools, 1)
    panel.pages.mockClassTools.fixture.choices[2]:Click()
    equal(panel.pages.mockClassTools.fixture.value, "spec")
    for _, key in ipairs({ "mockZulu", "mockAlpha" }) do
        truthy(addon:RegisterOptionsPage({ key = key, order = 35, title = key,
            builder = function(_, _, page) built[page.descriptor.key] = true end }))
    end
    same(keys(panel.categories), { "general", "mobility", "mockClassTools", "proc", "mockAlpha", "mockZulu", "importExport" })
    truthy(built.mockAlpha and built.mockZulu, "registration after opening invokes each new real builder")
    truthy(panel.categoryButtons.mockClassTools.selected, "registration preserves current navigation ownership")
    equal(addon:RegisterOptionsPage({ key = "mockAlpha", order = 99, builder = function() end }), false)
    addon:SelectOptionsCategory("general"); addon:SelectOptionsCategory("mockClassTools")
    equal(built.mockClassTools, 1, "revisiting never rebuilds page controls")
    same(panel.shellGrid, grid); equal(panel:GetWidth(), width); equal(panel:GetHeight(), height)
    equal(addon.optionsPageRegistry.classTools, nil, "mock reservation does not expose real Class Tools")
end)

test("MODERN SHELL fixed grid fits all target resolutions locales and UIParent scales without rewriting position", function()
    for _, locale in ipairs({ "enUS", "zhCN", "zhTW", "deDE", "frFR", "esES", "itIT", "ruRU", "koKR" }) do
        for _, size in ipairs({ { 1920, 1080 }, { 2560, 1440 }, { 1366, 768 } }) do
            local env, addon = h.login(nil, false, { locale = locale, uiWidth = size[1], uiHeight = size[2], uiScale = .8 })
            addon.db.options.position = { x = 117, y = -83 }
            local saved = copy(addon.db.options.position)
            local panel = h.options(addon)
            equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
            same(panel.shellGrid, { width = 900, height = 640, headerHeight = 76, sidebarWidth = 192,
                padding = 24, footerHeight = 64, contentX = 216, contentY = 100,
                contentWidth = 660, contentHeight = 460, navigationWidth = 144 })
            truthy(panel:GetWidth() * panel:GetScale() <= env.UIParent:GetWidth())
            truthy(panel:GetHeight() * panel:GetScale() <= env.UIParent:GetHeight())
            equal(panel.contentContainer:GetWidth(), 660)
            for _, button in ipairs(panel.categories) do
                truthy(button:GetWidth() <= panel.shellGrid.navigationWidth)
                truthy(button:GetFontString().wordWrap, "localized navigation wraps within its slot")
            end
            same(addon.db.options.position, saved)
            equal(panel.appliedX, saved.x); equal(panel.appliedY, saved.y)
        end
    end
end)

test("MODERN SHELL viewport changes clamp a visible stationary panel and preserve saved coordinates", function()
    local env, addon, state = h.login()
    addon.db.options.position = { x = -210, y = 95 }
    local panel = h.options(addon)
    local before = copy(addon.db.options.position)
    env.UIParent.GetWidth = function() return 800 end
    env.UIParent.GetHeight = function() return 600 end
    state:fire("DISPLAY_SIZE_CHANGED")
    equal(panel:GetScale(), math.min(1, 800 / 948, 600 / 688))
    same(addon.db.options.position, before, "responsive layout never migrates saved XY")
    env.UIParent.GetWidth = function() return 2560 end
    env.UIParent.GetHeight = function() return 1440 end
    state:fire("UI_SCALE_CHANGED")
    equal(panel:GetScale(), 1)
    same(addon.db.options.position, before)
    panel:Hide()
    env.UIParent.GetWidth = function() return 640 end
    state:fire("DISPLAY_SIZE_CHANGED")
    equal(panel:GetScale(), 1, "closed shell performs no viewport work")
    truthy(addon:OpenOptions()); truthy(panel:GetScale() < 1, "next opening samples the current viewport")
end)

test("MODERN SHELL page specialization combat and Escape settle all control and branding motion", function()
    local env, addon, state = h.login()
    local panel = h.options(addon)
    truthy(panel.titleAnimation:IsPlaying(), "opening may start the configured branding motion")
    addon:OpenAppearance("mobility")
    local dropdown = panel.controls.appearanceFont
    dropdown:Click(); truthy(dropdown.menu:IsShown())
    addon:RefreshTitleAnimation()
    addon:SelectOptionsCategory("general")
    settled(panel)
    addon:OpenAppearance("mobility"); dropdown:Click(); addon:RefreshTitleAnimation()
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    settled(panel)
    addon:OpenAppearance("mobility"); dropdown:Click(); addon:RefreshTitleAnimation()
    state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
    truthy(not panel:IsShown()); settled(panel)
    equal(addon.previewState.mode, "off")
    truthy(not addon:OpenOptions()); truthy(addon.pendingOptionsOpen)
    state.inCombat = false; state:fire("PLAYER_REGEN_ENABLED"); state:flushTimers()
    truthy(panel:IsShown()); equal(addon.pendingOptionsOpen, nil)
    addon:SelectOptionsCategory("mobility")
    local row = panel.controls.mobilityX
    row.valueButton:Click()
    row.editBox:SetText("777")
    row.editBox:GetScript("OnTextChanged")(row.editBox, true)
    row.editBox:GetScript("OnEscapePressed")(row.editBox)
    truthy(panel:IsShown(), "numeric Escape only cancels inline editing")
    equal(addon:GetMobilityConfig().position.x, 0)
    for _, name in ipairs(env.UISpecialFrames) do if name == panel:GetName() then env[name]:Hide() end end
    truthy(not panel:IsShown()); settled(panel)
    for _, frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"), nil) end
end)

test("MODERN SHELL real Proc Advanced transitions settle immediately at every navigation boundary", function()
    local function FinishSection(section)
        local group = section.collapsed and section.collapseAnimation or section.expandAnimation
        truthy(group:IsPlaying())
        group.playing = false
        group:GetScript("OnFinished")(group)
    end
    local function EffectiveVisible(frame)
        while frame do
            if frame.IsShown and not frame:IsShown() then return false end
            frame = frame.GetParent and frame:GetParent() or nil
        end
        return true
    end
    for _, boundary in ipairs({ "page", "spec", "escape", "combat", "hide" }) do
        for _, collapsing in ipairs({ false, true }) do
            local env, addon, state = h.login(nil, false, { specID = 62, proc = {} })
            local panel = h.options(addon)
            -- Materialize both real spec contexts before checking that a UI-only
            -- transition and its cleanup never add cosmetic SavedVariables.
            state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player"); state:flushTimers()
            state.specID = 62; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player"); state:flushTimers()
            addon:SelectOptionsCategory("proc")
            local controls, section = panel.controls, panel.procAdvancedSection
            -- Exercise the release-facing editor; legacy replacement controls
            -- remain covered only by the explicit development fixtures.
            controls.procPresentationPolicy:Click()
            truthy(controls.procPresentationPolicy.menu:IsShown())
            for _, choice in ipairs(controls.procPresentationPolicy.choices) do
                if choice.value == "independent" and choice:IsShown() and choice:IsEnabled() then
                    choice:Click(); break
                end
            end
            equal(addon:GetProcPresentationPolicy(), "independent")
            truthy(addon:GetSelectedProcColorEntry())
            truthy(controls.procIndependentRegion:IsShown() and controls.procIndependentRegion:IsEnabled())
            controls.procIndependentRegion:Click()
            truthy(controls.procIndependentRegion:GetChecked()); truthy(section:IsShown())
            local before = copy(addon.db)
            controls.procAdvanced:Click()
            if collapsing then
                FinishSection(section)
                local row = controls.procArt_offsetX
                row.valueButton:Click()
                row.editBox:SetText("149")
                row.editBox:GetScript("OnTextChanged")(row.editBox, true)
                controls.procAdvanced:Click()
            end
            equal(section.transition, collapsing and "collapsing" or "expanding")
            equal(section.content.cuiSectionLocked, true)
            equal(controls.procArt_offsetX.slider:IsMouseEnabled(), false, "transition releases descendant mouse input")
            local pending = collapsing and section.collapseAnimation or section.expandAnimation
            local lateCompletion = pending:GetScript("OnFinished")
            if boundary == "page" then addon:SelectOptionsCategory("general")
            elseif boundary == "spec" then state.specID = 63; state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
            elseif boundary == "escape" then
                for _, name in ipairs(env.UISpecialFrames) do if name == panel:GetName() then env[name]:Hide() end end
            elseif boundary == "combat" then state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
            else panel:Hide() end
            equal(section.transition, nil, boundary .. " settles immediately without waiting for a frame")
            truthy(not section.expandAnimation:IsPlaying() and not section.collapseAnimation:IsPlaying())
            equal(section.collapsed, collapsing, "cleanup respects the latest requested session state")
            equal(section:GetHeight(), collapsing and 42 or section.expandedHeight)
            equal(controls.procArt_offsetX.editBox:HasFocus(), false)
            truthy(not EffectiveVisible(controls.procArt_offsetX.slider) or not controls.procArt_offsetX.slider:IsEnabled(),
                "a hidden editor retains no reachable input target")
            settled(panel)
            local shown, category = panel:IsShown(), panel.activeCategory
            lateCompletion(pending)
            equal(panel:IsShown(), shown, "a stale native completion cannot reopen Options")
            equal(panel.activeCategory, category, "a stale completion cannot restore an old page")
            equal(section.transition, nil)
            equal(controls.procArt_offsetX.editBox:HasFocus(), false)
            same(addon.db, before, boundary .. " cleanup does not save disclosure or draft state")
        end
    end
end)

test("MODERN SHELL navigation viewport and hidden editors add no cosmetic SavedVariables", function()
    local env, addon, state = h.login()
    local panel = h.options(addon)
    local before = copy(addon.db)
    addon:SelectOptionsCategory("proc"); addon:SelectOptionsCategory("mobility")
    addon:OpenAppearance("mobility")
    panel.controls.appearanceFont:Click()
    addon:SelectOptionsCategory("general")
    state:fire("DISPLAY_SIZE_CHANGED")
    panel:Hide(); addon:OpenOptions()
    same(addon.db, before, "shell state remains session-only")
    equal(env.CarGOUIDB.schemaVersion, 5)
end)

test("MODERN SHELL RC2 navigation branding and clipped identity retain the fixed grid", function()
    local _, addon, state = h.login(nil, false, { classToken = "MAGE", specID = 62 })
    local panel = h.options(addon)
    local D, header, theme = addon.DesignSystem, panel.brandingHeader, panel.theme
    equal(panel:GetWidth(), 900); equal(panel:GetHeight(), 640)
    equal(header.emblem:GetWidth(), 30); equal(header.emblem:GetHeight(), 30)
    equal(header.wordmark:GetHeight(), 33)
    truthy(math.abs(header.wordmark:GetWidth() / header.wordmark:GetHeight() - 504 / 113) < .001)
    equal(header.accentLine:GetHeight(), 2)
    same(header.accentLine.vertexColor, { 1, 1, 1 }, "faction tint does not muddy the shared header gradient")
    truthy(header.accentWash.gradient); same(header.subtitle.textColor, D.textMuted)
    for _, button in ipairs(panel.categories) do
        equal(button.variant, "ghost"); equal(button.selectionRail:GetWidth(), 2)
        equal(button.selectionRail.gradient.orientation, "VERTICAL")
        equal(button.selectionRail:IsShown(), button.selected)
        equal(button.selectionGlow:IsShown(), button.selected)
        for _, edge in ipairs(button.cuiSkin.border) do equal(edge.color[4], 0, "navigation has no boxed chrome") end
        if not button.selected then
            equal(button.cuiSkin.fill.color[4], 0)
            same(button:GetFontString().textColor, D.textSecondary)
        end
    end
    local visible, cropped = 0, false
    for _, line in ipairs(theme.motif) do
        if line:IsShown() then
            visible = visible + 1
            for _, point in ipairs({ line.startPoint, line.endPoint }) do
                truthy(point[3] >= -300 and point[3] <= -24)
                truthy(point[4] >= 80 and point[4] <= 310)
                if math.abs(point[3] + 24) < .001 or math.abs(point[4] - 80) < .001 then cropped = true end
            end
            truthy(line.color[4] < addon.optionThemeOpacity.motif, "motif becomes a quiet background layer")
        end
    end
    equal(visible, theme.motifVisibleCount); truthy(visible > 0 and visible < theme.motifCount)
    truthy(cropped, "identity geometry is cropped rather than shown as a complete stamp")
    local frames, animations = #state.frames, #state.animations
    for _ = 1, 5 do addon:RefreshOptionsTheme(); addon:RefreshOptionsNavigationSelection() end
    equal(#state.frames, frames); equal(#state.animations, animations)
end)
