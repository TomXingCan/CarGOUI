local _, addon = ...

-- This editor only writes the audited region presentation API. Selection,
-- disclosure and gallery paging are UI-session state, never SavedVariables.
local function ProcKey(entry)
    return tostring(entry.overlayID or entry.sourceSpellID or entry.id)
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
    local function Save(patch)
        local ok, message = addon:SetProcRegionAppearance(Selected(), patch)
        ui.Feedback(panel, ok and addon.L.saved or message or addon.L.invalid, not ok)
        addon:RefreshOptions()
        return ok
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
    local function Number(parent, text, key, x, y, min, max, build)
        Label(parent, text, x, y, half, 24)
        local edit = ui.EditBox(panel, parent, x, y - 28, half)
        edit.min, edit.max = min, max
        edit:SetScript("OnTextChanged", function(self, user)
            if user and not panel.refreshing then self.dirty = true end
        end)
        edit:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if not value or value ~= value or value < min or value > max then
                if self.SetInvalid then self:SetInvalid(true) end
                ui.Feedback(panel, addon:Format("%s: expected a finite number from %g to %g.", text, min, max), true)
                return
            end
            self.dirty = false
            if self.SetInvalid then self:SetInvalid(false) end
            if Save(build and build(value) or { [key] = value }) then self:ClearFocus() end
        end)
        controls["procArt_" .. key] = edit
        return edit
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
    panel.procStatus = Label(selection, "", 0, -42, inner, 38)
    controls.procSelector = Dropdown(panel, selection, addon:Text("Proc"), 0, -92, {}, nil, function(value)
        addon:CancelProcColorPicker()
        ui.ClearEdits(panel)
        session.proc = value
        panel.selectedProcEntry = nil
        addon:RefreshOptions()
    end)
    controls.procSelector:SetWidth(half)
    controls.procEntry = Dropdown(panel, selection, addon:Text("Region"), right, -92, {}, nil, function(value)
        addon:CancelProcColorPicker()
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
    local display, displayContent = Section(addon:Text("Display mode"), 160)
    panel.procDisplaySection = display
    controls.procArt_mode = CUI.Segmented(panel, displayContent, "", 0, 0, inner, {
        { value = "native", label = addon:Text("Native artwork") },
        { value = "custom", label = addon:Text("Custom artwork") },
        { value = "timer", label = addon:Text("Timer only") },
    }, function(value) Save({ mode = value }) end)
    controls.procArtReset = Button(displayContent, addon:Text("Reset artwork to Blizzard default"), 0, -68, inner, function()
        if addon:ResetProcRegionAppearance(Selected()) then ui.Feedback(panel, addon.L.saved) end
        addon:RefreshOptions()
    end)

    local art, artContent = Section(addon:Text("Artwork"), 292)
    panel.procArtworkSection = art
    panel.procAssetLabel = Label(artContent, "", 0, 0, inner, 36)
    controls.procGallery = Button(artContent, addon:Text("Choose artwork"), 0, -48, half, function()
        addon:OpenProcArtworkGallery()
    end)
    controls.procOwnArtwork = Button(artContent, addon:Text("Use this Proc artwork"), right, -48, half, function() Save({ assetKey = false }) end)
    Enum(artContent, addon:Text("Artwork color (this region)"), "colorMode", -100, {
        { value = "native", label = addon:Text("Blizzard event color") },
        { value = "custom", label = addon:Text("Custom RGB") },
    }, function(value)
        if value == "native" then return { artColor = false } end
        return { artColor = { r = 1, g = 1, b = 1 } }
    end)
    panel.procArtRGB = CreateFrame("Frame", nil, artContent)
    panel.procArtRGB:SetSize(inner, 64)
    panel.procArtRGB:SetPoint("TOPLEFT", artContent, "TOPLEFT", 0, -176)
    local channels = { { "r", "R" }, { "g", "G" }, { "b", "B" } }
    local third = (inner - gap * 2) / 3
    for index, channel in ipairs(channels) do
        local key, x = channel[1], (index - 1) * (third + gap)
        Label(panel.procArtRGB, channel[2], x, 0, third, 20)
        local edit = ui.EditBox(panel, panel.procArtRGB, x, -28, third)
        controls["procArtRGB_" .. key] = edit
        edit:SetScript("OnTextChanged", function(self, user)
            if user and not panel.refreshing then self.dirty = true end
        end)
        edit:SetScript("OnEnterPressed", function()
            local color = {}
            for _, item in ipairs(channels) do color[item[1]] = tonumber(controls["procArtRGB_" .. item[1]]:GetText()) end
            if not addon:IsValidProcRegionColor(color) then
                for _, item in ipairs(channels) do
                    local field = controls["procArtRGB_" .. item[1]]
                    if field.SetInvalid then field:SetInvalid(true) end
                end
                ui.Feedback(panel, addon:Text("Choose finite RGB values from 0 to 1."), true)
                return
            end
            for _, item in ipairs(channels) do
                local field = controls["procArtRGB_" .. item[1]]
                field.dirty = false
                if field.SetInvalid then field:SetInvalid(false) end
            end
            Save({ artColor = color })
        end)
    end

    local transform, transformContent = Section(addon:Text("Transform"), 116)
    panel.procTransformSection = transform
    Number(transformContent, addon:Text("Artwork opacity"), "alpha", 0, 0, 0, 1)
    Number(transformContent, addon:Text("Artwork scale"), "scale", right, 0, 0.25, 3)
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

    local advanced, advancedContent = Section(addon:Text("Advanced artwork settings"), 524, {
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
    Number(advancedContent, addon:Text("Desaturation"), "desaturation", 0, 0, 0, 1)
    Number(advancedContent, addon:Text("Rotation (degrees)"), "rotation", right, 0, -180, 180)
    Number(advancedContent, addon:Text("Width multiplier"), "width", 0, -80, 0.25, 3)
    Number(advancedContent, addon:Text("Height multiplier"), "height", right, -80, 0.25, 3)
    Check(advancedContent, addon:Text("Mirror X"), "mirrorX", 0, -160)
    Check(advancedContent, addon:Text("Mirror Y"), "mirrorY", right, -160)
    Number(advancedContent, addon:Text("Artwork X offset"), "offsetX", 0, -208, -1000, 1000,
        function(value) return { offset = { x = value } } end)
    Number(advancedContent, addon:Text("Artwork Y offset"), "offsetY", right, -208, -1000, 1000,
        function(value) return { offset = { y = value } } end)
    Label(advancedContent, addon:Text("Artwork offsets use the native visual center. Timer position is independent."), 0, -280, inner, 38)
    Number(advancedContent, addon:Text("Animation speed"), "speed", 0, -328, 0.25, 3,
        function(value) return { animation = { speed = value } } end)
    Number(advancedContent, addon:Text("Animation intensity"), "intensity", right, -328, 0, 1,
        function(value) return { animation = { intensity = value } } end)
    Enum(advancedContent, addon:Text("Rotation direction"), "direction", -408, {
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
    end)
    controls.procAppearance = Button(timerContent, addon:Text("Timer typography"), 0, -122, inner, function()
        addon:OpenAppearance("proc", panel.selectedProcEntry)
    end)
    Label(timerContent, addon:Text("Font, size, outline, shadow and text scale are shared by this specialization. Timer RGB and artwork RGB are separate per-region settings."), 0, -172, inner, 52)
    local position, positionContent = Section(addon:Text("Position / Test"), 202)
    panel.procPositionSection = position
    controls.procPreview = Button(positionContent, addon:Text("Preview this region"), 0, 0, half, function()
        local ok, message = addon:SetPreview("single", panel.selectedProcEntry)
        addon:RefreshOptions()
        if not ok then ui.Feedback(panel, message, true) end
    end)
    controls.procStop = Button(positionContent, addon.L.previewStop, right, 0, half, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    controls.procPosition = Button(positionContent, addon:Text("Timer position / Test Mode"), 0, -50, inner, function()
        panel.selectedPreviewEntry = panel.selectedProcEntry
        addon:SelectOptionsCategory("preview")
    end)
    Label(positionContent, addon:Text("Test Mode uses separate artwork samples and never hides live Blizzard graphics."), 0, -100, inner, 44)
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
    local custom = appearance and appearance.mode == "custom"
    for _, key in ipairs({ "procArt_mode", "procArtReset", "procAppearance", "procPosition" }) do controls[key]:SetEnabled(entry ~= nil) end
    if appearance then
        controls.procArt_mode:SelectValue(appearance.mode)
        controls.procArt_colorMode:SelectValue(appearance.artColor and "custom" or "native")
        for _, key in ipairs({ "alpha", "scale", "desaturation", "rotation", "width", "height" }) do
            local edit = controls["procArt_" .. key]
            if not edit.dirty then edit:SetText(string.format("%g", appearance[key])) end
        end
        for _, key in ipairs({ "mirrorX", "mirrorY" }) do controls["procArt_" .. key]:SetChecked(appearance[key]) end
        for _, key in ipairs({ "entrance", "active", "exit", "direction" }) do controls["procArt_" .. key]:SelectValue(appearance.animation[key]) end
        for _, key in ipairs({ "speed", "intensity" }) do
            local edit = controls["procArt_" .. key]
            if not edit.dirty then edit:SetText(string.format("%g", appearance.animation[key])) end
        end
        for _, axis in ipairs({ "X", "Y" }) do
            local edit = controls["procArt_offset" .. axis]
            if not edit.dirty then edit:SetText(string.format("%g", appearance.offset[axis:lower()])) end
        end
        for _, key in ipairs({ "r", "g", "b" }) do
            local edit = controls["procArtRGB_" .. key]
            if not edit.dirty then edit:SetText(string.format("%g", appearance.artColor and appearance.artColor[key] or 1)) end
        end
        local asset = appearance.assetKey and self:GetProcAsset(appearance.assetKey)
        panel.procAssetLabel:SetText(asset and (AssetClassName(asset.class) .. " - " .. AssetLabel(asset)) or self:Text("This Proc's native artwork"))
        panel.procArtRGB:SetShown(appearance.artColor ~= nil)
        panel.procArtworkSection:SetHeight(appearance.artColor and 300 or 224)
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
