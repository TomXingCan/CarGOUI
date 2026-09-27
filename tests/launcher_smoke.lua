-- Executes the shipped libraries and launcher, never replacement library stubs.
-- Native widget/drag behavior is modeled by smoke.lua, not client acceptance.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local function libraries(env)
    truthy(env.LibStub, "actual vendored LibStub executed")
    local ldb = assert(env.LibStub("LibDataBroker-1.1"))
    local icon = assert(env.LibStub("LibDBIcon-1.0"))
    local object = assert(ldb:GetDataObjectByName("CarGOUI"))
    local button = assert(icon:GetMinimapButton("CarGOUI"))
    return ldb, icon, object, button
end
local function callback(env, button)
    return env.CarGOUI_OnAddonCompartmentClick("CarGOUI", button)
end

test("RC3 shipped libraries create one launcher and initialization stays idempotent", function()
    local env, addon, state = h.login()
    local ldb, icon, object, button = libraries(env)
    equal(object.type, "launcher", "LDB is a launcher, not a data feed")
    truthy(icon:IsRegistered("CarGOUI"), "real DBIcon registry contains the addon")
    equal(button.db, addon.db.options.minimap, "DBIcon owns the current shell table reference")
    equal(addon.optionsFrame, nil, "login icon registration leaves Options lazy")
    local frames, events = #state.frames, addon:GetEventDiagnostics().callbacks
    for _ = 1, 8 do addon:InitializeLauncher(); addon:RefreshLauncherSettings() end
    equal(ldb:GetDataObjectByName("CarGOUI"), object, "object identity does not change")
    equal(icon:GetMinimapButton("CarGOUI"), button, "icon frame is reused")
    equal(#state.frames, frames, "reinitialization allocates no frames")
    equal(addon:GetEventDiagnostics().callbacks, events, "no duplicate addon callbacks")
    equal(#state.errors, 0)
end)

test("RC3 late initialization restores a saved hidden minimap icon without waiting for another login event", function()
    local env, addon = h.login({ options = { minimap = { hide = true, minimapPos = 73 } } }, true)
    local _, _, _, button = libraries(env)
    equal(button:IsShown(), false, "already logged-in initialization honors saved hide immediately")
    equal(button.db, addon.db.options.minimap)
    truthy(button.point, "late loading provides a native icon anchor without a second PLAYER_LOGIN")
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false } } }))
    truthy(button:IsShown())
    equal(addon.optionsFrame, nil, "late initialization leaves Options lazy")
end)

test("RC3 standard library drag updates only its angle and leaves no permanent update script", function()
    local env, addon, state = h.login()
    local _, _, _, button = libraries(env)
    local classes, shell = copy(addon.db.classes), copy(addon.db.options.position)
    local metrics = h.transferMetrics(addon, state)
    equal(button:GetScript("OnUpdate"), nil, "idle icon never polls")
    local startDrag, stopDrag = button:GetScript("OnDragStart"), button:GetScript("OnDragStop")
    truthy(startDrag and stopDrag, "actual standard library owns dragging")
    for _, cursor in ipairs({ { 1950, 960 }, { 1800, 1100 }, { 1650, 960 }, { 1800, 810 } }) do
        state.cursorX, state.cursorY = cursor[1], cursor[2]
        startDrag(button)
        truthy(button:GetScript("OnUpdate"), "only active mouse drag installs native library update")
        button:GetScript("OnUpdate")(button, 0.016)
        stopDrag(button)
        equal(button:GetScript("OnUpdate"), nil, "release removes update")
        equal(button.isMouseDown, false)
        truthy(addon.db.options.minimap.minimapPos >= 0 and addon.db.options.minimap.minimapPos < 360)
    end
    same(addon.db.classes, classes, "icon angle never changes reminder positions/styles")
    same(addon.db.options.position, shell, "icon drag never moves Options")
    same(h.transferMetrics(addon, state), metrics, "repeated vendor dragging does not query gameplay or grow resources")
    equal(addon.optionsFrame, nil, "drag does not lazy-create Options")
    local _, reloaded = h.login(copy(addon.db))
    equal(reloaded.db.options.minimap.minimapPos, addon.db.options.minimap.minimapPos, "angle survives reload")
end)

test("RC3 hiding an actively dragged native icon releases library capture once", function()
    local env, addon = h.login()
    local _, _, _, button = libraries(env)
    local hidden = button:GetScript("OnHide")
    for _ = 1, 8 do addon:InitializeLauncher() end
    equal(button:GetScript("OnHide"), hidden, "initialization never stacks cleanup hooks")
    button:GetScript("OnDragStart")(button)
    truthy(button:GetScript("OnUpdate")); truthy(button.highlightLocked)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = true } } }))
    equal(button:GetScript("OnUpdate"), nil, "hiding ends vendor drag without leaked polling")
    equal(button.isMouseDown, false); equal(button.highlightLocked, false)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false } } }))
    button:GetScript("OnDragStart")(button); button:GetScript("OnDragStop")(button)
    equal(button:GetScript("OnUpdate"), nil, "normal drag still works after hide/show")
end)

test("RC3 collected icon anchors parent and manager handlers survive refresh import restore and reset", function()
    local env, addon = h.transferSeed()
    local _, icon, broker, button = libraries(env)
    local manager = env.CreateFrame("Frame", "MockMinimapCollector", env.UIParent)
    manager:SetSize(220, 90); manager:SetPoint("CENTER", env.UIParent, "CENTER", 400, 250)
    button:SetParent(manager); button:SetPoint("TOPLEFT", manager, "TOPLEFT", 19, -13)
    local managerDrag, managerStop = function() end, function() end
    local managerClick = function(frame, mouse) return broker.OnClick(frame, mouse) end
    button:SetScript("OnDragStart", managerDrag); button:SetScript("OnDragStop", managerStop)
    button:SetScript("OnClick", managerClick)
    local registered = button.db
    icon.Refresh = function() error("Refresh would replace collector anchors and drag handlers") end
    icon.Register = function() error("existing collected icon must never be registered twice") end
    local function Preserved()
        equal(button:GetParent(), manager)
        equal(button.point[1], "TOPLEFT"); equal(button.point[2], manager)
        equal(button.point[4], 19); equal(button.point[5], -13)
        equal(button:GetScript("OnDragStart"), managerDrag); equal(button:GetScript("OnDragStop"), managerStop)
        equal(button:GetScript("OnClick"), managerClick)
        equal(button.db, registered); equal(addon.db.options.minimap, registered)
    end
    addon:RefreshLauncherSettings(); Preserved()
    truthy(addon:UpdateSettings({ options = { minimap = { hide = true, minimapPos = 100 } } })); Preserved()
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false } } })); Preserved()
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    packet.options.minimap = { hide = true, minimapPos = -76 }
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet)))); Preserved()
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore()))); Preserved()
    addon:ResetDatabase(); Preserved()
end)

test("RC3 an IconCreated collector keeps its initial hidden layout and custom scripts", function()
    local env, addon, state = h.setup(nil, false)
    local icon = env.LibStub("LibDBIcon-1.0")
    local manager = env.CreateFrame("Frame", "EarlyCollector", env.UIParent)
    manager:SetSize(100, 100)
    local drag, stop, created = function() end, function() end, 0
    icon.RegisterCallback("OfflineCollector", "LibDBIcon_IconCreated", function(event, button, name)
        equal(event, "LibDBIcon_IconCreated"); equal(name, "CarGOUI")
        created = created + 1
        button:SetParent(manager); button:SetPoint("TOPLEFT", manager, "TOPLEFT", 9, -7)
        button:SetScript("OnDragStart", drag); button:SetScript("OnDragStop", stop)
        button:Hide()
    end)
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    local _, _, _, button = libraries(env)
    equal(created, 1); equal(button:IsShown(), false, "initial refresh does not override collector Hide")
    equal(button:GetParent(), manager); equal(button.point[2], manager)
    equal(button.point[4], 9); equal(button.point[5], -7)
    equal(button:GetScript("OnDragStart"), drag); equal(button:GetScript("OnDragStop"), stop)
    for _ = 1, 4 do addon:InitializeLauncher(); addon:RefreshLauncherSettings() end
    equal(created, 1); equal(button:IsShown(), false)
    equal(#state.errors, 0)
end)

test("RC3 a collector keeping the Minimap parent still owns its different anchor and mouse state", function()
    local env, addon = h.transferSeed()
    local _, icon, _, button = libraries(env)
    local bar = env.CreateFrame("Frame", "MBBLikeBar", env.UIParent)
    bar:SetSize(100, 100)
    -- MBB may retain Minimap parent and the original library drag handlers.
    -- Even without its SetPoint suppression wrappers, the foreign anchor alone
    -- must prevent CarGOUI from requesting a standard minimap layout.
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", 23, -17)
    equal(button:GetParent(), env.Minimap)
    local drag, stop = button:GetScript("OnDragStart"), button:GetScript("OnDragStop")
    icon.SetButtonToPosition = function() error("collector-owned anchor cannot be repositioned") end
    icon.Show = function() error("standard Show would overwrite the collector anchor") end
    button.isMouseDown, button.highlightLocked = true, true
    truthy(addon:UpdateSettings({ options = { minimap = { hide = true, minimapPos = 77 } } }))
    equal(button.isMouseDown, true, "OnHide does not call a foreign-layout stop handler")
    equal(button.highlightLocked, true)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false } } }))
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    packet.options.minimap.minimapPos = -100
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    addon:ResetDatabase()
    equal(button.point[2], bar); equal(button.point[4], 23); equal(button.point[5], -17)
    equal(button:GetScript("OnDragStart"), drag); equal(button:GetScript("OnDragStop"), stop)
    equal(button.isMouseDown, true, "neither resetting options nor restoring config owns collector capture")
end)

test("RC3 icon TOC broker texture and standard tooltip identify the same CarGOUI entry", function()
    local env, addon = h.login()
    local _, icon, broker, button = libraries(env)
    local expected = "Interface\\AddOns\\CarGOUI\\Media\\Branding\\emblem.tga"
    equal(h.metadata.IconTexture, expected)
    equal(h.metadata.AddonCompartmentFunc, "CarGOUI_OnAddonCompartmentClick")
    equal(broker.icon, expected); equal(button.icon:GetTexture(), expected)
    local coords = button.icon.texCoord
    for index, expectedCoord in ipairs({ 0, 1, 0, 1 }) do
        truthy(math.abs(coords[index] - expectedCoord) < 0.000001, "vendor idle inset does not crop the padded emblem")
    end
    button:GetScript("OnEnter")(button)
    same(icon.tooltip.tooltipLines, { "CarGOUI", addon.version, "Left-click: Open / close Options." })
    button:GetScript("OnLeave")(button); equal(icon.tooltip:IsShown(), false)
    equal(button.fadeOut:IsPlaying(), false, "ordinary tooltip does not enable fading/polling")
end)

test("RC3 each launcher boundary uses the existing Options toggle with an explicit left button", function()
    local env, addon = h.login()
    local _, _, broker, button = libraries(env)
    local calls, marker = 0, {}
    addon.ToggleOptions = function(self) equal(self, addon); calls = calls + 1; return marker end
    broker.OnClick(button, "LeftButton")
    equal(calls, 1, "standard LDB frame/button boundary")
    callback(env, "LeftButton")
    equal(calls, 2, "documented TOC addonName/button boundary")
    broker.OnClick(button, { buttonName = "LeftButton" })
    equal(calls, 3, "manager public inputData boundary")
    env.CarGOUI_OnAddonCompartmentClick("LeftButton")
    equal(calls, 4, "direct-button manager boundary")
    equal(addon.optionsFrame, nil, "wrappers do not directly create a second panel")
end)

test("RC3 modified and unsupported clicks never steal manager gestures or guess a missing button", function()
    local env, addon, state = h.login()
    local _, _, broker, button = libraries(env)
    local calls = 0
    addon.ToggleOptions = function() calls = calls + 1 end
    for _, modifier in ipairs({ "shiftDown", "controlDown", "altDown" }) do
        state[modifier] = true
        broker.OnClick(button, "LeftButton"); broker.OnClick(button, "RightButton")
        callback(env, "LeftButton"); callback(env, "RightButton")
        state[modifier] = false
    end
    for _, value in ipairs({ "RightButton", "MiddleButton", "Button4", "CarGOUI", 1, false, {},
            { buttonName = "RightButton" }, { button = "LeftButton" } }) do
        broker.OnClick(button, value); callback(env, value)
    end
    broker.OnClick(button); callback(env)
    broker.OnClick(nil); env.CarGOUI_OnAddonCompartmentClick("CarGOUI")
    local opaque = h.secret("LeftButton")
    broker.OnClick(button, opaque); callback(env, opaque)
    broker.OnClick(button, { buttonName = opaque }); env.CarGOUI_OnAddonCompartmentClick(opaque)
    local virtual = setmetatable({}, { __index = function() error("Click input must use raw public fields") end })
    broker.OnClick(button, virtual); callback(env, virtual)
    equal(calls, 0, "only an explicit unmodified left click requests Options")
    equal(addon.pendingOptionsOpen, nil, "invalid input cannot enqueue a combat request")
    equal(addon.optionsFrame, nil)
end)

test("RC3 a closed-panel minimap change does not initialize appearance catalogs or read player gameplay", function()
    local env, addon, state = h.login()
    local _, _, _, button = libraries(env)
    local classes = copy(addon.db.classes)
    local metrics = h.transferMetrics(addon, state)
    for _, name in ipairs({ "GetPreviewEntries", "GetAppearanceContext", "GetPlayerContext",
            "GetMobilityConfig", "GetProcConfig", "ApplySettings", "ApplyOptionsPosition",
            "RefreshTitleAnimation", "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove" }) do
        addon[name] = function() error("closed-panel shell setting must not call " .. name) end
    end
    truthy(addon:UpdateSettings({ options = { minimap = { hide = true, minimapPos = 91 } } }))
    equal(button:IsShown(), false)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false } } }))
    truthy(button:IsShown()); equal(addon.optionsFrame, nil)
    same(addon.db.classes, classes); same(h.transferMetrics(addon, state), metrics)
end)

test("RC3 broker compartment and slash clicks coalesce into the same combat queue", function()
    local env, addon, state = h.login()
    local _, _, broker, button = libraries(env)
    state:fire("PLAYER_REGEN_DISABLED")
    local frames, messages = #state.frames, #state.messages
    for _ = 1, 5 do
        broker.OnClick(button, "LeftButton")
        callback(env, "LeftButton")
        env.SlashCmdList.CARGOUI("")
    end
    equal(addon.pendingOptionsOpen, true)
    equal(#state.frames, frames, "no panel or hidden control creation while locked")
    equal(addon.optionsFrame, nil)
    equal(#state.messages, messages + 1, "queue feedback occurs once across all entry points")
    state:fire("PLAYER_REGEN_ENABLED")
    if state:activeTimers() > 0 then state:flushTimers() end
    truthy(addon.optionsFrame:IsShown(), "combat end opens one existing Options")
    equal(addon.pendingOptionsOpen, nil)
    local panel = addon.optionsFrame
    state:fire("PLAYER_REGEN_ENABLED")
    equal(addon.optionsFrame, panel); truthy(panel:IsShown(), "another event does not toggle it closed")
    broker.OnClick(button, "LeftButton"); equal(panel:IsShown(), false)
    callback(env, "LeftButton"); truthy(panel:IsShown(), "same panel reopens")
end)

test("RC3 minimap settings default normalize detach and remain independent of gameplay", function()
    local bad = { hide = "yes", minimapPos = 0 / 0, lock = true, radius = 900, profile = "private" }
    local env, addon, state = h.login({ options = { minimap = bad } })
    local _, _, _, button = libraries(env)
    same(addon.db.options.minimap, { hide = false, minimapPos = 220 })
    truthy(addon.db.options.minimap ~= bad, "saved nested table is detached")
    equal(button.db, addon.db.options.minimap)
    local panel, controls = h.options(addon)
    truthy(controls.showMinimapIcon:GetChecked())
    local classes, position, metrics = copy(addon.db.classes), copy(addon.db.options.position), h.transferMetrics(addon, state)
    for _, name in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "ApplySettings",
            "RefreshMobility", "RenderMobilityState", "RenderProcState", "RenderFreeMoveState" }) do
        addon[name] = function() error("minimap shell changes must not touch gameplay") end
    end
    controls.showMinimapIcon:Click()
    equal(addon.db.options.minimap.hide, true); equal(button:IsShown(), false)
    controls.showMinimapIcon:Click()
    equal(addon.db.options.minimap.hide, false); truthy(button:IsShown())
    same(addon.db.classes, classes); same(addon.db.options.position, position)
    same(h.transferMetrics(addon, state), metrics)
    truthy(panel:IsShown()); equal(#state.errors, 0)
end)

test("RC3 current class excludes launcher settings while all settings use the narrow shell whitelist", function()
    local env, addon = h.transferSeed()
    h.transferPage(addon)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = true, minimapPos = -125 } } }))
    local current = h.unpackSettings(env, assert(addon:ExportSettings("class")))
    equal(current.options, nil, "class scope never exports a shell")
    addon.db.options.minimap.private = "do not serialize"
    local all = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    same(all.options.minimap, { hide = true, minimapPos = -125 }, "only permitted launcher values are exported")
    for _, invalid in ipairs({ { hide = "true", minimapPos = 0 }, { hide = false, minimapPos = 361 },
            { hide = false, minimapPos = -361 }, { hide = true }, { minimapPos = 220 },
            { hide = false, minimapPos = 0, radius = 90 } }) do
        all.options.minimap = invalid
        local before = copy(addon.db)
        equal(addon:PrepareSettingsImport(h.packSettings(env, all)), nil, "invalid imported launcher settings reject")
        same(addon.db, before)
    end
end)

test("RC3 imports restores and reset synchronize the actual DBIcon table without losing old-format icon preferences", function()
    local env, addon = h.transferSeed()
    local _, _, _, button = libraries(env)
    h.transferPage(addon)
    truthy(addon:UpdateSettings({ options = { minimap = { hide = false, minimapPos = -88 } } }))
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    packet.options.minimap = { hide = true, minimapPos = 47 }
    local old = addon.db.options.minimap
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    equal(addon.db.options.minimap, old, "registered vendor table identity remains stable")
    equal(button.db, addon.db.options.minimap); equal(button:IsShown(), false)
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    same(addon.db.options.minimap, { hide = false, minimapPos = -88 })
    equal(button.db, addon.db.options.minimap); truthy(button:IsShown())
    packet.options.minimap = nil
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    same(addon.db.options.minimap, { hide = false, minimapPos = -88 }, "RC1/2 payload preserves local icon preference")
    equal(button.db, addon.db.options.minimap)
    addon.db.settingsImportBackup.settings.options.minimap = nil -- persisted RC1/2 backup shape
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    same(addon.db.options.minimap, { hide = false, minimapPos = -88 }, "older backup without icon fields also preserves them")
    equal(button.db, addon.db.options.minimap)
    local imported = addon.db.options.minimap
    addon:ResetDatabase()
    same(addon.db.options.minimap, { hide = false, minimapPos = 220 })
    equal(addon.db.options.minimap, imported); equal(button.db, addon.db.options.minimap)
    local _, reloaded = h.login(copy(addon.db))
    same(reloaded.db.options.minimap, { hide = false, minimapPos = 220 })
end)
