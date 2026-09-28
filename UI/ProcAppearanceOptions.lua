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
    local Label, Button, Dropdown = ui.Label, ui.Button, ui.Dropdown
    local controls, page = panel.controls, panel.pages.proc
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -32)
    scroll:SetSize(448, 336)
    self:RegisterOptionsDragSurface(scroll)
    local editor = CreateFrame("Frame", nil, scroll)
    editor:SetSize(438, 700)
    scroll:SetScrollChild(editor)
    self:RegisterOptionsDragSurface(editor)
    panel.procScroll, panel.procEditor = scroll, editor
    panel.procSession = { advanced = false, galleryClass = "all", galleryPage = 1 }
    local session = panel.procSession

    local function Selected() return addon:GetSelectedProcColorEntry() end
    local function Save(patch)
        local entry = Selected()
        local ok, message = addon:SetProcRegionAppearance(entry, patch)
        ui.Feedback(panel, ok and addon.L.saved or message or addon.L.invalid, not ok)
        addon:RefreshOptions()
        return ok
    end
    local function Section(text)
        local frame = CreateFrame("Frame", nil, editor)
        frame:SetSize(438, 100)
        self:RegisterOptionsDragSurface(frame)
        Label(frame, text, 0, 0, 430, 22, "GameFontNormal")
        return frame
    end
    local function Number(parent, text, key, x, y, min, max, build)
        Label(parent, text, x, y, 206, 20)
        local edit = ui.EditBox(panel, parent, x, y - 22, 200)
        edit.min, edit.max = min, max
        edit:SetScript("OnTextChanged", function(self, user)
            if user and not panel.refreshing then self.dirty = true end
        end)
        edit:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if not value or value ~= value or value < min or value > max then
                ui.Feedback(panel, addon:Format("%s: expected a finite number from %g to %g.", text, min, max), true)
                return
            end
            self.dirty = false
            if Save(build and build(value) or { [key] = value }) then self:ClearFocus() end
        end)
        controls["procArt_" .. key] = edit
        return edit
    end
    local function Enum(parent, text, key, y, entries, build)
        local dropdown = Dropdown(panel, parent, text, 0, y, entries, nil, function(value)
            Save(build and build(value) or { [key] = value })
        end)
        dropdown:SetWidth(430)
        controls["procArt_" .. key] = dropdown
        return dropdown
    end
    local function Check(parent, text, key, x, y)
        local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        check:SetSize(26, 26)
        ui.ThemeControl(check, "check")
        Label(parent, text, x + 30, y - 5, 170, 24)
        check:SetScript("OnClick", function(self) Save({ [key] = not not self:GetChecked() }) end)
        controls["procArt_" .. key] = check
        return check
    end

    panel.procContext = Label(editor, "", 0, 0, 430, 24, "GameFontHighlight")
    controls.procEnabled = ui.CheckBox(panel, editor, addon:Text("Enable Proc timers"), 0, -28,
        function(value) return { proc = { enabled = value } } end)
    panel.procStatus = Label(editor, "", 0, -62, 430, 42)
    controls.procSelector = Dropdown(panel, editor, addon:Text("Proc"), 0, -110, {}, nil, function(value)
        addon:CancelProcColorPicker()
        ui.ClearEdits(panel)
        session.proc = value
        panel.selectedProcEntry = nil
        addon:RefreshOptions()
    end)
    controls.procSelector:SetWidth(208)
    controls.procEntry = Dropdown(panel, editor, addon:Text("Region"), 222, -110, {}, nil, function(value)
        addon:CancelProcColorPicker()
        ui.ClearEdits(panel)
        panel.selectedProcEntry = value
        local entry = Selected()
        if entry then session.proc = ProcKey(entry) end
        addon:RefreshOptions()
    end)
    controls.procEntry:SetWidth(208)
    Enum(editor, addon:Text("Display mode"), "mode", -176, {
        { value = "native", label = addon:Text("Native artwork") },
        { value = "custom", label = addon:Text("Custom artwork") },
        { value = "timer", label = addon:Text("Timer only") },
    })
    controls.procArtReset = Button(editor, addon:Text("Reset artwork to Blizzard default"), 0, -242, 430, function()
        if addon:ResetProcRegionAppearance(Selected()) then ui.Feedback(panel, addon.L.saved) end
        addon:RefreshOptions()
    end)

    local art = Section(addon:Text("Artwork"))
    panel.procArtworkSection = art
    panel.procAssetLabel = Label(art, "", 0, -26, 430, 36)
    controls.procGallery = Button(art, addon:Text("Choose artwork"), 0, -66, 208, function()
        addon:OpenProcArtworkGallery()
    end)
    controls.procOwnArtwork = Button(art, addon:Text("Use this Proc artwork"), 222, -66, 208, function() Save({ assetKey = false }) end)
    Enum(art, addon:Text("Artwork color (this region)"), "colorMode", -106, {
        { value = "native", label = addon:Text("Blizzard event color") },
        { value = "custom", label = addon:Text("Custom RGB") },
    }, function(value)
        if value == "native" then return { artColor = false } end
        return { artColor = { r = 1, g = 1, b = 1 } }
    end)
    panel.procArtRGB = CreateFrame("Frame", nil, art)
    panel.procArtRGB:SetSize(430, 58)
    panel.procArtRGB:SetPoint("TOPLEFT", art, "TOPLEFT", 0, -174)
    local channels = { { "r", "R" }, { "g", "G" }, { "b", "B" } }
    for index, channel in ipairs(channels) do
        local key = channel[1]
        Label(panel.procArtRGB, channel[2], (index - 1) * 146, 0, 130, 20)
        local edit = ui.EditBox(panel, panel.procArtRGB, (index - 1) * 146, -22, 138)
        controls["procArtRGB_" .. key] = edit
        edit:SetScript("OnTextChanged", function(self, user)
            if user and not panel.refreshing then self.dirty = true end
        end)
        edit:SetScript("OnEnterPressed", function()
            local color = {}
            for _, item in ipairs(channels) do color[item[1]] = tonumber(controls["procArtRGB_" .. item[1]]:GetText()) end
            if not addon:IsValidProcRegionColor(color) then ui.Feedback(panel, addon:Text("Choose finite RGB values from 0 to 1."), true); return end
            for _, item in ipairs(channels) do controls["procArtRGB_" .. item[1]].dirty = false end
            Save({ artColor = color })
        end)
    end

    local transform = Section(addon:Text("Transform"))
    panel.procTransformSection = transform
    Number(transform, addon:Text("Artwork opacity"), "alpha", 0, -28, 0, 1)
    Number(transform, addon:Text("Artwork scale"), "scale", 222, -28, 0.25, 3)
    transform:SetHeight(88)
    local animation = Section(addon:Text("Animation"))
    panel.procAnimationSection = animation
    Enum(animation, addon:Text("Entrance"), "entrance", -28, {
        { value = "none", label = addon:Text("None") }, { value = "fade", label = addon:Text("Fade in") },
        { value = "scale", label = addon:Text("Scale in") }, { value = "pulse", label = addon:Text("Pulse in") },
    }, function(value) return { animation = { entrance = value } } end)
    Enum(animation, addon:Text("Active"), "active", -94, {
        { value = "none", label = addon:Text("None") }, { value = "pulse", label = addon:Text("Pulse") },
        { value = "breathe", label = addon:Text("Breathe") }, { value = "rotate", label = addon:Text("Slow rotate") },
    }, function(value) return { animation = { active = value } } end)
    Enum(animation, addon:Text("Exit"), "exit", -160, {
        { value = "none", label = addon:Text("None") }, { value = "fade", label = addon:Text("Fade out") },
        { value = "scale", label = addon:Text("Scale out") },
    }, function(value) return { animation = { exit = value } } end)
    animation:SetHeight(226)
    controls.procAdvanced = Button(editor, addon:Text("Advanced artwork settings"), 0, 0, 430, function()
        session.advanced = not session.advanced
        addon:RefreshOptions()
    end)
    local advanced = Section(addon:Text("Advanced artwork settings"))
    panel.procAdvancedSection = advanced
    Number(advanced, addon:Text("Desaturation"), "desaturation", 0, -28, 0, 1)
    Number(advanced, addon:Text("Rotation (degrees)"), "rotation", 222, -28, -180, 180)
    Number(advanced, addon:Text("Width multiplier"), "width", 0, -94, 0.25, 3)
    Number(advanced, addon:Text("Height multiplier"), "height", 222, -94, 0.25, 3)
    Check(advanced, addon:Text("Mirror X"), "mirrorX", 0, -160)
    Check(advanced, addon:Text("Mirror Y"), "mirrorY", 222, -160)
    Number(advanced, addon:Text("Artwork X offset"), "offsetX", 0, -202, -1000, 1000,
        function(value) return { offset = { x = value } } end)
    Number(advanced, addon:Text("Artwork Y offset"), "offsetY", 222, -202, -1000, 1000,
        function(value) return { offset = { y = value } } end)
    Label(advanced, addon:Text("Artwork offsets use the native visual center. Timer position is independent."), 0, -262, 430, 38)
    Number(advanced, addon:Text("Animation speed"), "speed", 0, -312, 0.25, 3,
        function(value) return { animation = { speed = value } } end)
    Number(advanced, addon:Text("Animation intensity"), "intensity", 222, -312, 0, 1,
        function(value) return { animation = { intensity = value } } end)
    Enum(advanced, addon:Text("Rotation direction"), "direction", -378, {
        { value = "clockwise", label = addon:Text("Clockwise") },
        { value = "counterclockwise", label = addon:Text("Counterclockwise") },
    }, function(value) return { animation = { direction = value } } end)
    advanced:SetHeight(448)

    local timer = Section(addon:Text("Timer"))
    panel.procTimerSection = timer
    panel.procColorSelection = Label(timer, "", 0, -26, 430, 22, "GameFontHighlight")
    Label(timer, addon:Text("Timer color (this region)"), 0, -54, 220, 22)
    controls.procColor = Button(timer, "", 0, -80, 38, function()
        local ok, message = addon:OpenProcColorPicker(Selected())
        if not ok then ui.Feedback(panel, message, true) end
    end)
    local swatch = controls.procColor:CreateTexture(nil, "OVERLAY")
    swatch:SetPoint("TOPLEFT", controls.procColor, "TOPLEFT", 5, -5)
    swatch:SetPoint("BOTTOMRIGHT", controls.procColor, "BOTTOMRIGHT", -5, 5)
    controls.procColor.swatch = swatch
    panel.procColorMode = Label(timer, "", 48, -86, 150, 22)
    controls.procColorReset = Button(timer, addon:Text("Use class color"), 222, -80, 208, function()
        addon:CancelProcColorPicker()
        if addon:SetProcRegionColor(Selected(), nil) then ui.Feedback(panel, addon.L.saved) end
        addon:RefreshProcColorControls()
    end)
    controls.procAppearance = Button(timer, addon:Text("Timer typography"), 0, -122, 430, function()
        addon:OpenAppearance("proc", panel.selectedProcEntry)
    end)
    Label(timer, addon:Text("Font, size, outline, shadow and text scale are shared by this specialization. Timer RGB and artwork RGB are separate per-region settings."), 0, -160, 430, 58)
    timer:SetHeight(226)
    local position = Section(addon:Text("Position / Test"))
    panel.procPositionSection = position
    controls.procPreview = Button(position, addon:Text("Preview this region"), 0, -28, 208, function()
        local ok, message = addon:SetPreview("single", panel.selectedProcEntry)
        addon:RefreshOptions()
        if not ok then ui.Feedback(panel, message, true) end
    end)
    controls.procStop = Button(position, addon.L.previewStop, 222, -28, 208, function()
        addon:StopPreview()
        addon:RefreshOptions()
    end)
    controls.procPosition = Button(position, addon:Text("Timer position / Test Mode"), 0, -66, 430, function()
        panel.selectedPreviewEntry = panel.selectedProcEntry
        addon:SelectOptionsCategory("preview")
    end)
    Label(position, addon:Text("Test Mode uses separate artwork samples and never hides live Blizzard graphics."), 0, -104, 430, 42)
    position:SetHeight(152)
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
        panel.procArtworkSection:SetHeight(appearance.artColor and 242 or 174)
    end
    local y = -286
    local function Place(frame, shown, height)
        frame:SetShown(not not shown)
        if not shown then return end
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", panel.procEditor, "TOPLEFT", 0, y)
        y = y - (height or frame:GetHeight()) - 14
    end
    Place(panel.procArtworkSection, custom)
    Place(panel.procTransformSection, custom)
    Place(panel.procAnimationSection, custom)
    controls.procAdvanced:SetText((session.advanced and "- " or "+ ") .. self:Text("Advanced artwork settings"))
    Place(controls.procAdvanced, custom, 28)
    Place(panel.procAdvancedSection, custom and session.advanced)
    Place(panel.procTimerSection, true)
    Place(panel.procPositionSection, true)
    panel.procEditor:SetHeight(-y)
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
        gallery:SetSize(474, 510)
        gallery:SetPoint("CENTER", panel, "CENTER", 0, 0)
        gallery:SetFrameLevel(panel:GetFrameLevel() + 30)
        gallery:EnableMouse(true)
        ui.Backdrop(gallery, 0.07, 0.09, 0.12)
        ui.ThemeControl(gallery, "menu")
        panel.procGallery = gallery
        ui.Label(gallery, self:Text("Artwork gallery"), 12, -10, 360, 22, "GameFontNormalLarge")
        ui.Button(gallery, self.L.close, 374, -8, 88, function() gallery:Hide() end)
        local classes, found = { { value = "all", label = self:Text("All source classes") } }, {}
        for _, asset in ipairs(self:GetProcAssets()) do
            for _, source in ipairs(asset.sources or { asset }) do found[source.class] = true end
        end
        local ordered = {}
        for class in pairs(found) do ordered[#ordered + 1] = class end
        table.sort(ordered)
        for _, class in ipairs(ordered) do classes[#classes + 1] = { value = class, label = AssetClassName(class) } end
        gallery.filter = ui.Dropdown(panel, gallery, self:Text("Source class"), 12, -44, classes, nil, function(value)
            panel.procSession.galleryClass, panel.procSession.galleryPage = value, 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.filter.menu:SetFrameLevel(gallery:GetFrameLevel() + 10)
        gallery.tiles = {}
        for index = 1, 9 do
            local tile = ui.Button(gallery, "", 12 + ((index - 1) % 3) * 151, -110 - math.floor((index - 1) / 3) * 112, 143, nil)
            tile:SetHeight(104)
            tile.texture = tile:CreateTexture(nil, "ARTWORK")
            tile.texture:SetPoint("TOP", tile, "TOP", 0, -5)
            tile.texture:SetSize(100, 60)
            tile.label = ui.Label(tile, "", 4, -69, 135, 30)
            tile.label:SetJustifyH("CENTER")
            tile.selected = ui.Label(tile, self:Text("Selected"), 4, -2, 135, 18, "GameFontNormalSmall")
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
        gallery.previous = ui.Button(gallery, self:Text("Previous"), 12, -452, 140, function()
            panel.procSession.galleryPage = panel.procSession.galleryPage - 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.next = ui.Button(gallery, self:Text("Next"), 322, -452, 140, function()
            panel.procSession.galleryPage = panel.procSession.galleryPage + 1
            addon:RefreshProcArtworkGallery()
        end)
        gallery.pageLabel = ui.Label(gallery, "", 162, -457, 150, 22)
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
            local scale = math.min(100 / width, 60 / height)
            tile.texture:SetSize(width * scale, height * scale)
            tile.label:SetText(AssetLabel(asset))
            tile.selected:SetShown(appearance and appearance.assetKey == asset.key)
        end
    end
    gallery.previous:SetEnabled(session.galleryPage > 1)
    gallery.next:SetEnabled(session.galleryPage < pages)
    gallery.pageLabel:SetText(string.format("%d / %d", session.galleryPage, pages))
end
