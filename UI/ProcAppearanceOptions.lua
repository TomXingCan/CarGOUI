local _, addon = ...

-- This editor only writes the audited region presentation API. Selection,
-- disclosure and gallery paging are UI-session state, never SavedVariables.
local function ProcKey(entry)
    return tostring(entry.overlayID or entry.sourceSpellID or entry.id)
end

local function NumericContext(entry)
    return entry and (entry.class .. ":" .. entry.specID .. ":" .. entry.id) or nil
end

local function AssetClassName(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return names and names[class] or class
end

local function AssetLabel(asset)
    return addon:GetLocalizedSpellName(asset.auraID or asset.sourceSpellID, asset.procName or asset.label)
end

function addon:GetProcGalleryAssets(class)
    local result = {}
    for _, asset in ipairs(self:GetProcAssets()) do
        local included = not class or class == "all" or asset.class == class
        for _, source in ipairs(asset.sources or {}) do
            if source.class == class then included = true end
        end
        if included then result[#result + 1] = asset end
    end
    return result
end

function addon:CreateProcAppearanceOptions(panel, ui)
    local CUI = addon.CUI
    local Label, Button, Dropdown = ui.Label, ui.Button, ui.Dropdown
    local controls, page = panel.controls, panel.pages.proc
    -- The viewport leaves room for the shared thin scrollbar. Every card uses
    -- the same twelve-unit inset and two-column grid; labels can wrap.
    local width, gap = 640, addon.DesignSystem.spacingL
    local inner = width - 2 * addon.DesignSystem.sectionPadding
    local half = (inner - gap) / 2
    local right = half + gap
    local scroll = CUI.ScrollFrame(panel, page, 0, -32, width, page:GetHeight() - 32)
    self:RegisterOptionsDragSurface(scroll)
    local editor = CreateFrame("Frame", nil, scroll)
    editor:SetSize(width, 800)
    scroll:SetScrollChild(editor)
    self:RegisterOptionsDragSurface(editor)
    panel.procScroll, panel.procEditor = scroll, editor
    panel.procSession = { advanced = false, galleryClass = "all", galleryPage = 1 }
    local session = panel.procSession

    local function Selected() return addon:GetSelectedProcColorEntry() end
    local function SaveProc(patch)
        addon:CancelProcColorPicker()
        CUI.ClearNumericInteractions(panel)
        ui.ClearEdits(panel)
        if panel.procGallery then panel.procGallery:Hide() end
        local ok, message = addon:UpdateSettings({ proc = patch })
        -- A rejected cleanup transaction must restore the visible selection.
        addon:RefreshOptions()
        ui.Feedback(panel, ok and addon.L.saved or message or addon.L.invalid, not ok)
    end
    local function Save(patch, numericContext)
        if patch.mode ~= nil then addon:CancelProcColorPicker() end
        local entry = Selected()
        if numericContext and numericContext ~= NumericContext(entry) then return false, addon.L.invalid end
        local ok, message = addon:SetProcRegionAppearance(entry, patch, numericContext and {
            skipOptionsRefresh = true, continuousAppearance = true,
        } or nil)
        ui.Feedback(panel, ok and addon.L.saved or message or addon.L.invalid, not ok)
        if not numericContext then addon:RefreshOptions() end
        return ok, message
    end
    local function Section(text, height, options)
        options = options or {}
        options.height = height
        local frame = CUI.Section(editor, text, 0, 0, width, options)
        frame.content:SetWidth(inner)
        self:RegisterOptionsDragSurface(frame)
        self:RegisterOptionsDragSurface(frame.content)
        return frame, frame.content
    end
    local defaults = addon:NewProcAppearance()
    local function Number(parent, text, key, y, build)
        local offset = key == "offsetX" or key == "offsetY"
        local range = addon.procAppearanceLimits[offset and "offset" or key]
        local percent = key == "alpha" or key == "desaturation" or key == "intensity"
        local integralStep = offset or key == "rotation"
        local default = offset and defaults.offset[key == "offsetX" and "x" or "y"]
            or defaults[key] or defaults.animation[key]
        -- Drag steps are presentation choices, not persistence quantization.
        -- Precise entry keeps the existing finite-number storage contract.
        local row = CUI.NumberRow(panel, parent, text, 0, y, inner, {
            min = range.min, max = range.max, default = default,
            step = integralStep and 1 or .01, precision = percent and 2 or 3,
            displayFactor = percent and 100 or 1,
            unit = percent and "%" or key == "rotation" and "°" or not offset and "×" or nil,
            labelWidth = 240, valueWidth = 88,
            context = function() return NumericContext(Selected()) end,
        }, function(value, context)
            if context ~= NumericContext(Selected()) then return false, addon.L.invalid end
            return Save(build and build(value) or { [key] = value }, context)
        end)
        controls["procArt_" .. key] = row
        return row
    end
    local function Enum(parent, text, key, y, entries, build, x, controlWidth)
        local dropdown = Dropdown(panel, parent, text, x or 0, y, entries, nil, function(value)
            Save(build and build(value) or { [key] = value })
        end)
        dropdown:SetWidth(controlWidth or inner)
        if dropdown.label then dropdown.label:SetWidth(controlWidth or inner) end
        controls["procArt_" .. key] = dropdown
        return dropdown
    end
    local function Check(parent, text, key, x, y)
        local check = CUI.Toggle(panel, parent, text, x, y, function(value) Save({ [key] = value }) end)
        if check.label then check.label:SetWidth(half - 60) end
        controls["procArt_" .. key] = check
        return check
    end

    local context, selection = Section(addon:Text("Proc"), 216)
    panel.procContextSection, panel.procContext = context, context.title
    controls.procEnabled = ui.CheckBox(panel, selection, addon:Text("Enable Proc timers"), 0, 0,
        function(value) return { proc = { enabled = value } } end)
    panel.procStatus = Label(selection, "", 0, -42, inner, 44)
    controls.procSelector = Dropdown(panel, selection, addon:Text("Proc"), 0, -92, {}, nil, function(value)
        addon:CancelProcColorPicker()
        CUI.ClearNumericInteractions(panel)
        ui.ClearEdits(panel)
        session.proc = value
        panel.selectedProcEntry = nil
        addon:RefreshOptions()
    end)
    controls.procSelector:SetWidth(half)
    controls.procEntry = Dropdown(panel, selection, addon:Text("Region"), right, -92, {}, nil, function(value)
        addon:CancelProcColorPicker()
        CUI.ClearNumericInteractions(panel)
        ui.ClearEdits(panel)
        panel.selectedProcEntry = value
        local entry = Selected()
        if entry then session.proc = ProcKey(entry) end
        addon:RefreshOptions()
    end)
    controls.procEntry:SetWidth(half)
    for _, control in ipairs({ controls.procSelector, controls.procEntry }) do
        if control.label then control.label:SetWidth(half) end
    end
    local policy, policyContent = Section(addon:Text("Artwork strategy"), 132)
    panel.procPolicySection = policy
    controls.procPresentationPolicy = Dropdown(panel, policyContent, addon:Text("Artwork strategy"), 0, 0, {
        { value = "replacement", label = addon:Text("Legacy region replacement") },
        { value = "independent", label = addon:Text("Independent CUI") },
    }, nil, function(value) SaveProc({ presentationPolicy = value }) end)
    controls.procPresentationPolicy:SetWidth(inner)
    controls.procIndependentArtworkEnabled = CUI.Toggle(panel, policyContent,
        addon:Text("Enable independent live artwork"), 0, -76,
        function(value) SaveProc({ independentArtworkEnabled = value }) end)
    controls.procIndependentArtworkEnabled.label:SetWidth(inner - 60)
    panel.procPolicyGuide = Label(policyContent,
        addon:Text("Set Blizzard Spell Alert Opacity to 0 manually. Independent CUI requires spellActivationOverlayOpacity=0 and displaySpellActivationOverlays=0. The master switch affects live artwork only."),
        0, -120, inner, 76)
    panel.procPolicyWarning = Label(policyContent,
        addon:Text("This hides all Blizzard alerts, including uncovered Procs. Per-side Native artwork is unavailable. If Independent CUI is stopped or fails, restore Blizzard Spell Alert Opacity manually."),
        0, -206, inner, 76)

    local display, displayContent = Section(addon:Text("Display mode"), 160)
    panel.procDisplaySection = display
    controls.procArt_mode = CUI.Segmented(panel, displayContent, "", 0, 0, inner, {
        { value = "native", label = addon:Text("Native artwork") },
        { value = "custom", label = addon:Text("Custom artwork") },
        { value = "timer", label = addon:Text("Timer only") },
    }, function(value)
        if addon:GetProcPresentationPolicy() == "replacement" then Save({ mode = value }) end
    end)
    controls.procIndependentRegion = CUI.Toggle(panel, displayContent,
        addon:Text("Enable independent artwork for this region"), 0, 0, function(value)
            local entry = Selected()
            if entry then SaveProc({ regions = { [entry.id] = { independentArtworkEnabled = value } } }) end
        end)
    controls.procIndependentRegion.label:SetWidth(inner - 60)
    panel.procRegionPolicyHint = Label(displayContent,
        addon:Text("Turning this off hides CUI artwork for this region; it does not restore a Native side. Enabled regions can still be edited and tested when the live master switch is off. Test uses separate samples."),
        0, -42, inner, 66)
    controls.procArtReset = Button(displayContent, addon:Text("Reset artwork to Blizzard default"), 0, -68, inner, function()
        addon:CancelProcColorPicker()
        CUI.ClearNumericInteractions(panel)
        if addon:ResetProcRegionAppearance(Selected()) then ui.Feedback(panel, addon.L.saved) end
        addon:RefreshOptions()
    end, "ghost")

    local art, artContent = Section(addon:Text("Artwork"), 432)
    panel.procArtworkSection = art
    panel.procAssetLabel = Label(artContent, "", 0, 0, inner, 36)
    controls.procGallery = Button(artContent, addon:Text("Choose artwork"), 0, -48, half, function()
        addon:OpenProcArtworkGallery()
    end)
    controls.procOwnArtwork = Button(artContent, addon:Text("Use this Proc artwork"), right, -48, half, function() Save({ assetKey = false }) end)
    controls.procArt_colorMode = Dropdown(panel, artContent, addon:Text("Artwork color (this region)"), 0, -100, {
        { value = "native", label = addon:Text("Blizzard event color") },
        { value = "custom", label = addon:Text("Custom color") },
    }, nil, function(value)
        addon:CancelProcColorPicker()
        if value == "native" then Save({ artColor = false })
        else
            local ok, message = addon:OpenProcColorPicker(Selected(), "artwork")
            if not ok then ui.Feedback(panel, message, true) end
            addon:RefreshProcColorControls()
        end
    end)
    controls.procArt_colorMode:SetWidth(inner - 64)
    controls.procArtColor = Button(artContent, "", inner - 40, -126, 40, function()
        local ok, message = addon:OpenProcColorPicker(Selected(), "artwork")
        if not ok then ui.Feedback(panel, message, true) end
    end)
    local artSwatch = controls.procArtColor:CreateTexture(nil, "OVERLAY")
    artSwatch:SetPoint("TOPLEFT", controls.procArtColor, "TOPLEFT", 6, -6)
    artSwatch:SetPoint("BOTTOMRIGHT", controls.procArtColor, "BOTTOMRIGHT", -6, 6)
    controls.procArtColor.swatch = artSwatch
    Number(artContent, addon:Text("Desaturation"), "desaturation", -176)
    panel.procTintGuide = Label(artContent,
        addon:Text("0% keeps the artwork colors; 100% removes them before tinting. Values in between retain some original color."),
        0, -216, inner, 44)
    Number(artContent, addon:Text("Artwork opacity"), "alpha", -272)
    panel.procTintLimit = Label(artContent,
        addon:Text("Tint depends on the artwork brightness and transparency; the selected color may not appear as a solid flat color."),
        0, -316, inner, 52)
    local third = (inner - gap * 2) / 3

    local transform, transformContent = Section(addon:Text("Transform"), 96)
    panel.procTransformSection = transform
    Number(transformContent, addon:Text("Artwork scale"), "scale", 0)
    local animation, animationContent = Section(addon:Text("Animation"), 120)
    panel.procAnimationSection = animation
    Enum(animationContent, addon:Text("Entrance"), "entrance", 0, {
        { value = "none", label = addon:Text("None") }, { value = "fade", label = addon:Text("Fade in") },
        { value = "scale", label = addon:Text("Scale in") }, { value = "pulse", label = addon:Text("Pulse in") },
    }, function(value) return { animation = { entrance = value } } end, 0, third)
    Enum(animationContent, addon:Text("Active"), "active", 0, {
        { value = "none", label = addon:Text("None") }, { value = "pulse", label = addon:Text("Pulse") },
        { value = "breathe", label = addon:Text("Breathe") }, { value = "rotate", label = addon:Text("Slow rotate") },
    }, function(value) return { animation = { active = value } } end, third + gap, third)
    Enum(animationContent, addon:Text("Exit"), "exit", 0, {
        { value = "none", label = addon:Text("None") }, { value = "fade", label = addon:Text("Fade out") },
        { value = "scale", label = addon:Text("Scale out") },
    }, function(value) return { animation = { exit = value } } end, (third + gap) * 2, third)

    local advanced, advancedContent = Section(addon:Text("Advanced artwork settings"), 532, {
        collapsible = true, collapsed = true,
        onToggle = function(_, collapsed)
            session.advanced = not collapsed
            if panel.procAdvancedSection and not panel.refreshing then addon:RefreshProcAppearanceOptions() end
        end,
        onSettled = function()
            -- Collapse keeps its expanded footprint during the shared fade;
            -- recompute the scroll range only once its final height is ready.
            if panel.procAdvancedSection and not panel.refreshing then addon:RefreshProcAppearanceOptions() end
        end,
    })
    panel.procAdvancedSection = advanced
    controls.procAdvanced = advanced.collapseButton
    Number(advancedContent, addon:Text("Rotation (degrees)"), "rotation", 0)
    Number(advancedContent, addon:Text("Width multiplier"), "width", -44)
    Number(advancedContent, addon:Text("Height multiplier"), "height", -88)
    Check(advancedContent, addon:Text("Mirror X"), "mirrorX", 0, -136)
    Check(advancedContent, addon:Text("Mirror Y"), "mirrorY", right, -136)
    Number(advancedContent, addon:Text("Artwork X offset"), "offsetX", -184,
        function(value) return { offset = { x = value } } end)
    Number(advancedContent, addon:Text("Artwork Y offset"), "offsetY", -228,
        function(value) return { offset = { y = value } } end)
    Label(advancedContent, addon:Text("Artwork offsets use the native visual center. Timer position is independent."), 0, -272, inner, 38)
    Number(advancedContent, addon:Text("Animation speed"), "speed", -318,
        function(value) return { animation = { speed = value } } end)
    Number(advancedContent, addon:Text("Animation intensity"), "intensity", -362,
        function(value) return { animation = { intensity = value } } end)
    Enum(advancedContent, addon:Text("Rotation direction"), "direction", -414, {
        { value = "clockwise", label = addon:Text("Clockwise") },
        { value = "counterclockwise", label = addon:Text("Counterclockwise") },
    }, function(value) return { animation = { direction = value } } end)

    local timer, timerContent = Section(addon:Text("Timer"), 278)
    panel.procTimerSection = timer
    panel.procColorSelection = Label(timerContent, "", 0, 0, inner, 24, "GameFontHighlight")
    Label(timerContent, addon:Text("Timer color (this region)"), 0, -38, half, 24)
    controls.procColor = Button(timerContent, "", 0, -70, 40, function()
        local ok, message = addon:OpenProcColorPicker(Selected())
        if not ok then ui.Feedback(panel, message, true) end
    end)
    local swatch = controls.procColor:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("TOPLEFT", controls.procColor, "TOPLEFT", 6, -6)
    swatch:SetPoint("BOTTOMRIGHT", controls.procColor, "BOTTOMRIGHT", -6, 6)
    controls.procColor.swatch = swatch
    panel.procColorMode = Label(timerContent, "", 52, -78, 248, 24)
    controls.procColorReset = Button(timerContent, addon:Text("Use class color"), right, -70, half, function()
        addon:CancelProcColorPicker()
        if addon:SetProcRegionColor(Selected(), nil) then ui.Feedback(panel, addon.L.saved) end
        addon:RefreshProcColorControls()
    end, "ghost")
    controls.procAppearance = Button(timerContent, addon:Text("Timer typography"), 0, -122, inner, function()
        addon:OpenAppearance("proc", panel.selectedProcEntry)
    end)
    Label(timerContent, addon:Text("Font, size, outline, shadow and text scale are shared by this specialization. Timer RGB and artwork RGB are separate per-region settings."), 0, -172, inner, 52)
    local position, positionContent = Section(addon:Text("Position / Test"), 292)
    panel.procPositionSection = position
    for _, axis in ipairs({ "X", "Y" }) do
        local coordinate = axis:lower()
        local limits = addon.limits.offset
        local row = CUI.NumberRow(panel, positionContent,
            axis == "X" and addon:Text("Timer X") or addon:Text("Timer Y"), 0, axis == "X" and 0 or -44, inner, {
                min = limits.min, max = limits.max, step = 1,
                default = addon:NewReminderPosition()[coordinate], precision = 3,
                labelWidth = 240, valueWidth = 88,
                context = function() return NumericContext(Selected()) end,
            }, function(value, context)
            local entry = Selected()
            if not entry or context ~= NumericContext(entry) then return false, addon.L.invalid end
            local ok, message = addon:UpdateSettings({ reminders = {
                [entry.id] = { position = { [coordinate] = value } },
            } }, { skipOptionsRefresh = true })
            ui.Feedback(panel, ok and addon.L.saved or message or addon.L.invalidPosition, not ok)
            return ok, message
        end)
        controls["procPosition" .. axis] = row
    end
    controls.procPositionReset = Button(positionContent, addon:Text("Reset timer position"), 0, -92, inner, function()
        local entry = Selected()
        if not entry then return end
        controls.procPositionX:CancelInteraction(); controls.procPositionY:CancelInteraction()
        panel.submit({ reminders = { [entry.id] = { position = addon:NewReminderPosition() } } })
    end, "ghost")
    controls.procPreview = Button(positionContent, addon:Text("Test selected region"), 0, -142, half, function()
        local ok, message = addon:SetPreview("single", panel.selectedProcEntry)
        addon:RefreshOptions()
        if not ok then ui.Feedback(panel, message, true) end
    end, "primary")
    controls.procStop = Button(positionContent, addon.L.previewStop, right, -142, half, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    Label(positionContent, addon:Text("Test Mode uses separate artwork samples and never hides live Blizzard graphics."), 0, -190, inner, 44)
    page:HookScript("OnHide", function() if panel.procGallery then panel.procGallery:Hide() end end)
    panel.procUI = ui
end

function addon:RefreshProcAppearanceOptions()
    local panel = self.optionsFrame
    if not panel or not panel.procEditor then return end
    local controls, session = panel.controls, panel.procSession
    local entries, procs, allowed, regions, procSeen = {}, {}, {}, {}, {}
    for _, entry in ipairs(self:GetPreviewEntries()) do
        if entry.kind == "proc" then
            entries[#entries + 1] = entry
            local key = ProcKey(entry)
            if not procSeen[key] then
                local id, fallback = self:GetEntryDisplaySpell(entry)
                procs[#procs + 1] = { value = key, label = self:GetLocalizedSpellName(id, fallback) }
                procSeen[key] = true
            end
        end
    end
    local current = self:GetSelectedProcColorEntry()
    if current then session.proc = ProcKey(current) end
    if not procSeen[session.proc] then session.proc = procs[1] and procs[1].value end
    for _, entry in ipairs(entries) do
        regions[#regions + 1] = { value = entry.id, label = self:GetEntryDisplayLabel(entry) }
        if ProcKey(entry) == session.proc then allowed[entry.id] = true end
    end
    if not allowed[panel.selectedProcEntry] then
        panel.selectedProcEntry = nil
        for _, entry in ipairs(entries) do
            if allowed[entry.id] then panel.selectedProcEntry = entry.id; break end
        end
    end
    if session.region ~= panel.selectedProcEntry then
        self.CUI.ClearNumericInteractions(panel)
        panel.procUI.ClearEdits(panel)
        if panel.procGallery then panel.procGallery:Hide() end
        panel.procScroll:SetVerticalScroll(0)
        session.region = panel.selectedProcEntry
    end
    controls.procSelector:SetEntries(procs)
    controls.procSelector:FilterChoices(procSeen)
    controls.procSelector:SelectValue(session.proc)
    controls.procEntry:SetEntries(regions)
    controls.procEntry:FilterChoices(allowed)
    controls.procEntry:SelectValue(panel.selectedProcEntry)
    local _, spec = self:GetPlayerContext()
    panel.procContext:SetText(spec and self:Format("Current specialization: %s", self:GetLocalizedSpecName(spec)) or self:Text("No defined style context"))
    local entry = self:GetSelectedProcColorEntry()
    local appearance = self:GetProcRegionAppearance(entry)
    local policy = self:GetProcPresentationPolicy()
    local independent = policy == "independent"
    local config = #entries > 0 and self:GetProcConfig()
    local region = config and entry and config.regions and config.regions[entry.id]
    local custom = entry and self:IsProcArtworkEditable(entry)
    controls.procPresentationPolicy:SelectValue(policy)
    controls.procPresentationPolicy:SetEnabled(config ~= nil and config ~= false)
    controls.procIndependentArtworkEnabled:SetChecked(config and config.independentArtworkEnabled ~= false or false)
    controls.procIndependentArtworkEnabled:SetEnabled(not not config)
    controls.procIndependentArtworkEnabled:SetShown(independent)
    controls.procIndependentArtworkEnabled.label:SetShown(independent)
    panel.procPolicyGuide:SetShown(independent)
    panel.procPolicyWarning:SetShown(independent)
    panel.procPolicySection:SetHeight(independent and 350 or 132)
    controls.procArt_mode:SetShown(not independent)
    controls.procIndependentRegion:SetShown(independent)
    controls.procIndependentRegion.label:SetShown(independent)
    controls.procIndependentRegion:SetEnabled(entry ~= nil)
    controls.procIndependentRegion:SetChecked(region and region.independentArtworkEnabled == true or false)
    panel.procRegionPolicyHint:SetShown(independent)
    panel.procDisplaySection.title:SetText(independent and self:Text("Region artwork") or self:Text("Display mode"))
    panel.procDisplaySection:SetHeight(independent and 218 or 160)
    controls.procArtReset:SetText(independent and self:Text("Reset artwork settings") or self:Text("Reset artwork to Blizzard default"))
    controls.procArtReset:ClearAllPoints()
    controls.procArtReset:SetPoint("TOPLEFT", panel.procDisplaySection.content, "TOPLEFT", 0, independent and -122 or -68)
    for _, key in ipairs({ "procArt_mode", "procArtReset", "procAppearance", "procPositionX", "procPositionY", "procPositionReset" }) do
        controls[key]:SetEnabled(entry ~= nil)
    end
    controls.procArt_mode:SetEnabled(entry ~= nil and not independent)
    local position = entry and self:GetReminderPosition(entry)
    for _, axis in ipairs({ "X", "Y" }) do
        local row = controls["procPosition" .. axis]
        row:SetContext(NumericContext(entry))
        row:SetValue(position and position[axis:lower()] or 0)
    end
    if appearance then
        controls.procArt_mode:SelectValue(appearance.mode)
        for _, key in ipairs({ "alpha", "scale", "desaturation", "rotation", "width", "height" }) do
            local row = controls["procArt_" .. key]
            row:SetContext(NumericContext(entry)); row:SetValue(appearance[key])
        end
        for _, key in ipairs({ "mirrorX", "mirrorY" }) do controls["procArt_" .. key]:SetChecked(appearance[key]) end
        for _, key in ipairs({ "entrance", "active", "exit", "direction" }) do controls["procArt_" .. key]:SelectValue(appearance.animation[key]) end
        for _, key in ipairs({ "speed", "intensity" }) do
            local row = controls["procArt_" .. key]
            row:SetContext(NumericContext(entry)); row:SetValue(appearance.animation[key])
        end
        for _, axis in ipairs({ "X", "Y" }) do
            local row = controls["procArt_offset" .. axis]
            row:SetContext(NumericContext(entry)); row:SetValue(appearance.offset[axis:lower()])
        end
        local asset = appearance.assetKey and self:GetProcAsset(appearance.assetKey)
        panel.procAssetLabel:SetText(asset and (AssetClassName(asset.class) .. " - " .. AssetLabel(asset)) or self:Text("This Proc's native artwork"))
    end
    local y = 0
    local function Place(frame, shown, height)
        frame:SetShown(not not shown)
        if not shown then return end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", panel.procEditor, "TOPLEFT", 0, y)
        y = y - (height or frame:GetHeight()) - addon.DesignSystem.sectionGap
    end
    Place(panel.procContextSection, true)
    Place(panel.procPolicySection, true)
    Place(panel.procDisplaySection, true)
    Place(panel.procArtworkSection, custom)
    Place(panel.procTransformSection, custom)
    Place(panel.procAnimationSection, custom)
    Place(panel.procTimerSection, true)
    Place(panel.procPositionSection, true)
    Place(panel.procAdvancedSection, custom)
    panel.procEditor:SetHeight(-y)
    panel.procScroll:RefreshRange()
    panel.procScroll:SetVerticalScroll(math.min(panel.procScroll:GetVerticalScroll(),
        math.max(0, -y - panel.procScroll:GetHeight())))
    if panel.procGallery and panel.procGallery:IsShown() then self:RefreshProcArtworkGallery() end
end

function addon:OpenProcArtworkGallery()
    local panel = self.optionsFrame
    if not panel or not self:GetSelectedProcColorEntry() then return end
    if not panel.procGallery then
        local ui = panel.procUI
        local gallery = CreateFrame("Frame", nil, panel, "BackdropTemplate")
        gallery:SetSize(650, 578)
        gallery:SetPoint("CENTER", panel, "CENTER", 0, 0)
        gallery:SetFrameLevel(panel:GetFrameLevel() + 30)
        gallery:EnableMouse(true)
        ui.ThemeControl(gallery, "menu")
        panel.procGallery = gallery
        ui.Label(gallery, self:Text("Artwork gallery"), 16, -16, 480, 28, "GameFontNormalLarge")
        ui.Button(gallery, self.L.close, 518, -12, 116, function() gallery:Hide() end)
        local classes, found = { { value = "all", label = self:Text("All source classes") } }, {}
        for _, asset in ipairs(self:GetProcAssets()) do
            for _, source in ipairs(asset.sources or { asset }) do found[source.class] = true end
        end
        local ordered = {}
        for class in pairs(found) do ordered[#ordered + 1] = class end
        table.sort(ordered)
        for _, class in ipairs(ordered) do classes[#classes + 1] = { value = class, label = AssetClassName(class) } end
        gallery.filter = ui.Dropdown(panel, gallery, self:Text("Source class"), 16, -56, classes, nil, function(value)
            panel.procSession.galleryClass, panel.procSession.galleryPage = value, 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.filter:SetWidth(360)
        gallery.filter.menu:SetFrameLevel(gallery:GetFrameLevel() + 10)
        gallery.tiles = {}
        for index = 1, 9 do
            local tile = addon.CUI.GalleryTile(gallery, "", 16 + ((index - 1) % 3) * 208,
                -128 - math.floor((index - 1) / 3) * 128, 202, 122, nil)
            tile.texture = tile:CreateTexture(nil, "ARTWORK")
            tile.texture:SetPoint("TOP", tile, "TOP", 0, -8)
            tile.texture:SetSize(168, 74)
            tile.label = tile.textLabel
            tile.label:ClearAllPoints()
            tile.label:SetPoint("BOTTOM", tile, "BOTTOM", 0, 6)
            tile.label:SetSize(186, 32)
            tile.label:SetJustifyH("CENTER")
            tile.label:SetWordWrap(true)
            tile.selectionLabel = ui.Label(tile, self:Text("Selected"), 6, -4, 190, 20, "GameFontNormalSmall")
            tile.selectionLabel:SetJustifyH("RIGHT")
            tile:SetScript("OnClick", function(self)
                if not self.asset then return end
                addon:SetProcRegionAppearance(addon:GetSelectedProcColorEntry(), { assetKey = self.asset.key })
                addon:RefreshOptions()
            end)
            tile:SetScript("OnEnter", function(self)
                local asset = self.asset
                if not asset then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(AssetLabel(asset), 1, 1, 1)
                GameTooltip:AddLine(addon:Format("Source: %s", AssetClassName(asset.class)))
                GameTooltip:AddLine(addon:Format("Native location: %s", asset.locationTypeName))
                GameTooltip:AddLine(string.format("FileDataID: %d", asset.textureID))
                GameTooltip:AddLine(addon:Text("Artwork availability does not add trigger or timer support."), 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            local function HideTooltip(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end
            tile:SetScript("OnLeave", HideTooltip)
            tile:HookScript("OnHide", HideTooltip)
            gallery.tiles[index] = tile
        end
        gallery.previous = ui.Button(gallery, self:Text("Previous"), 16, -528, 174, function()
            panel.procSession.galleryPage = panel.procSession.galleryPage - 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.next = ui.Button(gallery, self:Text("Next"), 460, -528, 174, function()
            panel.procSession.galleryPage = panel.procSession.galleryPage + 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.pageLabel = ui.Label(gallery, "", 208, -536, 234, 24)
        gallery.pageLabel:SetJustifyH("CENTER")
        gallery:HookScript("OnHide", function() gallery.filter.menu:Hide() end)
    end
    self:RefreshProcArtworkGallery()
    panel.procGallery:Show()
end

function addon:RefreshProcArtworkGallery()
    local panel = self.optionsFrame
    if not panel or not panel.procGallery then return end
    local gallery, session = panel.procGallery, panel.procSession
    local assets = self:GetProcGalleryAssets(session.galleryClass)
    local pages = math.max(1, math.ceil(#assets / 9))
    session.galleryPage = math.min(pages, math.max(1, session.galleryPage))
    local appearance = self:GetProcRegionAppearance(self:GetSelectedProcColorEntry())
    gallery.filter:SelectValue(session.galleryClass)
    for index, tile in ipairs(gallery.tiles) do
        local asset = assets[(session.galleryPage - 1) * 9 + index]
        tile.asset = asset
        tile:SetShown(asset ~= nil)
        if asset then
            -- Thumbnails are loaded directly from the audited client catalog.
            tile.texture:SetTexture(asset.textureID)
            local geometry = asset.geometry
            local width, height = geometry and geometry.width or 1, geometry and geometry.height or 1
            local scale = math.min(168 / width, 74 / height)
            tile.texture:SetSize(width * scale, height * scale)
            tile.label:SetText(AssetLabel(asset))
            local selected = appearance and appearance.assetKey == asset.key
            tile:SetSelected(not not selected)
            tile.selectionLabel:SetShown(selected)
        end
    end
    gallery.previous:SetEnabled(session.galleryPage > 1)
    gallery.next:SetEnabled(session.galleryPage < pages)
    gallery.pageLabel:SetText(string.format("%d / %d", session.galleryPage, pages))
end
