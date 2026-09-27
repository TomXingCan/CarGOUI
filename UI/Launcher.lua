local _, addon = ...

local NAME = "CarGOUI"
local ICON = "Interface\\AddOns\\CarGOUI\\Media\\Branding\\emblem.tga"

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function HasMinimapLayout(button)
    if not button or button:GetParent() ~= Minimap then return false end
    local count = button:GetNumPoints()
    if count == 0 then return true end
    if count ~= 1 then return false end
    -- MBB can keep the Minimap parent while anchoring to its own bar. This
    -- checks only our launcher's public layout, never game/secure effect state.
    local _, relative = button:GetPoint(1)
    return Public(relative) and (relative == Minimap or relative == "Minimap")
end

-- LDB uses (displayFrame, mouseButton); the TOC compartment wrapper receives
-- (addonName, mouseButton). Some broker hosts forward menu inputData instead.
-- Never use the caller's frame as our Options panel, or assume a missing button.
local function MouseButton(first, second)
    if Public(second) then
        if type(second) == "string" then return second end
        if type(second) == "table" then
            local button = rawget(second, "buttonName")
            if Public(button) and type(button) == "string" then return button end
        end
    end
    if Public(second) and second == nil and Public(first) and type(first) == "string" then return first end
end

local function ModifiedClick()
    return (IsControlKeyDown and IsControlKeyDown())
        or (IsShiftKeyDown and IsShiftKeyDown())
        or (IsAltKeyDown and IsAltKeyDown())
end

local function OnClick(first, second)
    if MouseButton(first, second) ~= "LeftButton" or ModifiedClick() then return end
    return addon:ToggleOptions()
end

-- Keep this global because Blizzard resolves the main TOC callback by name.
-- No RegisterAddon call: the TOC is the sole compartment registration owner.
function CarGOUI_OnAddonCompartmentClick(addonName, buttonName)
    return OnClick(addonName, buttonName)
end

local function OnTooltipShow(tooltip)
    tooltip:AddLine(NAME)
    tooltip:AddLine(addon.version, 0.75, 0.75, 0.75)
    tooltip:AddLine(addon:Text("Left-click: Open / close Options."), 1, 1, 1)
end

function addon:InitializeLauncher()
    if not self.initialized or not self.db then return false end
    if self.launcher then return true end
    local broker = LibStub("LibDataBroker-1.1", true)
    local icon = LibStub("LibDBIcon-1.0", true)
    if not broker or not icon then return false end
    local object = broker:GetDataObjectByName(NAME)
    if not object then
        object = broker:NewDataObject(NAME, {
            type = "launcher", label = NAME, icon = ICON,
            -- LibDBIcon insets each idle edge by 5% of this range. Cancel that
            -- inset so the emblem's four tips stay intact. The source's outer
            -- pixels are transparent, including the pressed/broker padding.
            iconCoords = { -1 / 18, 19 / 18, -1 / 18, 19 / 18 },
            OnClick = OnClick, OnTooltipShow = OnTooltipShow,
        })
    end
    self.launcher, self.launcherIcon = object, icon
    local fresh = not icon:IsRegistered(NAME)
    if fresh then
        -- Register owns initial visibility. Its IconCreated callback may hand
        -- the button to a collector; do not undo that decision with a Show.
        self.launcherHide = self.db.options.minimap.hide
        self.launcherPosition = self.db.options.minimap.minimapPos
        icon:Register(NAME, object, self.db.options.minimap)
    end
    local button = icon:GetMinimapButton(NAME)
    self.launcherMinimapSettings = button and button.db or self.db.options.minimap
    if fresh and button then
        -- The library's startup PLAYER_LOGIN may already have passed when the
        -- addon is loaded late. Finish only an unplaced, uncollected button;
        -- never Show over a collector's IconCreated visibility decision.
        if button:GetParent() == Minimap and button:GetNumPoints() == 0 then
            icon:SetButtonToPosition(button, self.launcherMinimapSettings.minimapPos)
        end
        if self.launcherMinimapSettings.hide then icon:Hide(NAME) end
    end
    if button then
        local startDrag, stopDrag = button:GetScript("OnDragStart"), button:GetScript("OnDragStop")
        button:HookScript("OnHide", function(frame)
            -- A hidden standard drag must release the library's temporary
            -- OnUpdate. Delegate its existing stop handler only while both
            -- layout and drag scripts still belong to LibDBIcon, not a collector.
            if HasMinimapLayout(frame) and frame.isMouseDown
                and frame:GetScript("OnDragStart") == startDrag
                and frame:GetScript("OnDragStop") == stopDrag and stopDrag then stopDrag(frame) end
        end)
    end
    self:RefreshLauncherSettings()
    return true
end

function addon:RefreshLauncherSettings()
    if not self.launcher or not self.launcherIcon or not self.db then return end
    -- Retain the registered table identity across atomic import/restore/reset.
    -- LibDBIcon:Refresh also resets drag handlers and Minimap anchors, which
    -- could break a collector's ownership. Copy only our validated fields back
    -- into the library-bound table; never copy a frame, broker or manager state.
    local source, db = self.db.options.minimap, self.launcherMinimapSettings
    if source ~= db then
        local hide, position = source.hide, source.minimapPos
        db.hide, db.minimapPos = hide, position
        self.db.options.minimap = db
    end
    local icon = self.launcherIcon
    local button = icon:GetMinimapButton(NAME)
    if self.launcherHide ~= db.hide then
        if db.hide then
            icon:Hide(NAME)
        elseif button and not HasMinimapLayout(button) then
            -- A collector owns the layout; honor the explicit visibility
            -- change without asking the library to reanchor it on Minimap.
            button:Show()
        else
            icon:Show(NAME)
        end
    end
    if self.launcherPosition ~= db.minimapPos and HasMinimapLayout(button) then
        icon:SetButtonToPosition(button, db.minimapPos)
    end
    self.launcherHide, self.launcherPosition = db.hide, db.minimapPos
end
