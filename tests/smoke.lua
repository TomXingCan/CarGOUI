-- Offline Lua 5.1 smoke tests. These mocks do not replace an in-game Retail test.
-- Run: lua5.1 tests/smoke.lua /path/to/CarGOUI
local root = assert(arg and arg[1], "Pass the CarGOUI AddOn directory as argument 1.")
local files, metadata = {}, {}
local toc = assert(io.open(root .. "/CarGOUI.toc", "r"))
for line in toc:lines() do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    local key, value = line:match("^##%s*([^:]+):%s*(.*)$")
    if key then
        metadata[key] = value
    elseif line ~= "" and line:sub(1, 1) ~= "#" then
        -- WoW TOCs conventionally use Windows separators; run on any host OS.
        local path = line:gsub("\\", "/")
        assert(path:match("%.lua$"), "Unsupported TOC entry in Phase 1 smoke suite: " .. path)
        local source = assert(io.open(root .. "/" .. path, "r"), "Missing TOC-listed file: " .. path)
        source:close()
        files[#files + 1] = path
    end
end
toc:close()
assert(#files > 0, "CarGOUI.toc contains no Lua files")
local total = 0

local function equal(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected)
            .. ", got " .. tostring(actual), 2)
    end
end

local function truthy(value, label)
    if not value then error(label or "Expected a truthy value", 2) end
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function same(actual, expected, label)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        return equal(actual, expected, label)
    end
    for key, value in pairs(expected) do
        same(actual[key], value, (label or "table") .. "." .. tostring(key))
    end
    for key in pairs(actual) do
        truthy(expected[key] ~= nil, (label or "table") .. " has unexpected key " .. tostring(key))
    end
end

local function setup(saved, loggedIn, client)
    client = client or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.CarGOUIDB = saved
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UIParent = { name = "UIParent", GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end }
    env.STANDARD_TEXT_FONT = client.standardFont or "Fonts\\FRIZQT__.ttf"
    env.GameFontNormal = { template = "GameFontNormal" }
    env.GameFontHighlight = { template = "GameFontHighlight" }
    env.GameFontHighlightSmall = { template = "GameFontHighlightSmall" }
    local state = { frames = {}, errors = {}, messages = {}, loggedIn = loggedIn or false,
        fontWrites = 0, textWrites = 0, timers = 0 }
    env.print = function(...) state.messages[#state.messages + 1] = { ... } end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
        state.messages[#state.messages + 1] = message
    end }
    env.geterrorhandler = function()
        return function(message) state.errors[#state.errors + 1] = tostring(message) end
    end
    env.IsLoggedIn = function() return state.loggedIn end
    env.InCombatLockdown = function() return false end
    env.GetBuildInfo = function() return "12.1.0", "99999", "Sep 26 2026", 120100 end
    env.GetLocale = function() return client.locale or "enUS" end
    env.C_Timer = { After = function() error("Options must not schedule polling timers") end,
        NewTicker = function() error("Options must not schedule polling tickers") end }

    local object = {}
    function object:GetName() return self.name end
    function object:GetParent() return self.parent end
    function object:GetObjectType() return self.kind end
    function object:SetPoint(point, relative, relativePoint, x, y)
        self.point = { point, relative, relativePoint, x or 0, y or 0 }
    end
    function object:ClearAllPoints() self.point = nil end
    function object:GetPoint() return unpack(self.point or {}) end
    function object:SetAllPoints(relative) self.allPoints = relative or self.parent end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:SetWidth(width) self.width = width end
    function object:SetHeight(height) self.height = height end
    function object:GetWidth() return self.width end
    function object:GetHeight() return self.height end
    function object:SetScale(scale) self.scale = scale end
    function object:GetScale() return self.scale or 1 end
    function object:Show()
        local wasShown = self:IsShown()
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function object:Hide()
        local wasShown = self:IsShown()
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function object:IsShown() return self.shown ~= false end
    function object:IsVisible()
        return self:IsShown() and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible())
    end
    function object:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function object:SetAlpha(alpha) self.alpha = alpha end
    function object:SetFrameStrata(strata) self.strata = strata end
    function object:SetClampedToScreen(value) self.clampedToScreen = value end
    function object:SetFrameLevel(level) self.frameLevel = level end
    function object:GetFrameLevel() return self.frameLevel or 1 end
    function object:EnableMouse(enabled) self.mouseEnabled = enabled end
    function object:SetScript(event, callback)
        assert(event ~= "OnUpdate" or callback == nil, "Options must not register OnUpdate scans")
        self.scripts[event] = callback
    end
    function object:GetScript(event) return self.scripts[event] end
    function object:HookScript(event, callback)
        local previous = self.scripts[event]
        self:SetScript(event, function(...)
            if previous then previous(...) end
            callback(...)
        end)
    end
    function object:RegisterEvent(event) self.events[event] = true end
    function object:UnregisterEvent(event) self.events[event] = nil end
    function object:IsEventRegistered(event) return self.events[event] or false end
    function object:UnregisterAllEvents() self.events = {} end
    function object:SetFont(face, size, flags)
        assert(type(face) == "string" and type(size) == "number", "Invalid SetFont arguments")
        self.font = { face, size, flags or "" }
        state.fontWrites = state.fontWrites + 1
        return true
    end
    function object:SetFontObject(value) self.fontObject = value end
    function object:SetNormalFontObject(value) self.fontObject = value end
    function object:SetHighlightFontObject(value) self.highlightFontObject = value end
    function object:SetDisabledFontObject(value) self.disabledFontObject = value end
    function object:GetFont() return unpack(self.font or {}) end
    local function requireFont(fontString)
        local templateFont = fontString.template and (fontString.kind == "FontString"
            or fontString.template == "UIPanelButtonTemplate" or fontString.template == "InputBoxTemplate")
        assert(fontString.font or fontString.fontObject or templateFont,
            "FontString requires a font before setting or measuring text")
    end
    function object:SetText(text)
        requireFont(self)
        self.textValue = text
        state.textWrites = state.textWrites + 1
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function object:GetText() return self.textValue end
    function object:GetStringWidth()
        requireFont(self)
        return #tostring(self.textValue or "") * (self.font and self.font[2] or 24) * 0.6
    end
    function object:GetStringHeight()
        requireFont(self)
        return self.font and self.font[2] or 24
    end
    function object:SetTextColor(...) self.textColor = { ... } end
    function object:SetJustifyH(value) self.justifyH = value end
    function object:SetJustifyV(value) self.justifyV = value end
    function object:SetWordWrap(value) self.wordWrap = value end
    function object:SetNonSpaceWrap(value) self.nonSpaceWrap = value end
    function object:SetSpacing(value) self.spacing = value end
    function object:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
    function object:GetShadowOffset() return unpack(self.shadowOffset or { 0, 0 }) end
    function object:SetShadowColor(...) self.shadowColor = { ... } end
    function object:SetBackdrop(value)
        assert(self.template and self.template:find("BackdropTemplate", 1, true),
            "Modern Retail SetBackdrop requires BackdropTemplate")
        self.backdrop = value
    end
    function object:SetBackdropColor(...) self.backdropColor = { ... } end
    function object:SetBackdropBorderColor(...) self.backdropBorderColor = { ... } end
    function object:SetColorTexture(...) self.color = { ... } end
    function object:SetTexture(value) self.texture = value end
    function object:SetVertexColor(...) self.vertexColor = { ... } end
    function object:SetTexCoord(...) self.texCoord = { ... } end
    function object:SetDrawLayer(layer) self.layer = layer end
    function object:SetNormalTexture(value) self.normalTexture = value end
    function object:SetHighlightTexture(value) self.highlightTexture = value end
    function object:SetPushedTexture(value) self.pushedTexture = value end
    function object:SetDisabledTexture(value) self.disabledTexture = value end
    function object:SetCheckedTexture(value) self.checkedTexture = value end
    function object:SetAutoFocus(value) self.autoFocus = value end
    function object:SetNumeric(value) self.numeric = value end
    function object:SetMultiLine(value) self.multiLine = value end
    function object:SetMaxLetters(value) self.maxLetters = value end
    function object:SetTextInsets(...) self.textInsets = { ... } end
    function object:SetFocus()
        if state.focus and state.focus ~= self then state.focus:ClearFocus() end
        state.focus, self.focused = self, true
        if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
    end
    function object:ClearFocus()
        local wasFocused = self.focused
        self.focused = false
        if state.focus == self then state.focus = nil end
        if wasFocused and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
    end
    function object:HasFocus() return self.focused or false end
    function object:HighlightText(...) self.highlight = { ... } end
    function object:SetEnabled(value) self.enabled = not not value end
    function object:Enable() self:SetEnabled(true) end
    function object:Disable() self:SetEnabled(false) end
    function object:IsEnabled() return self.enabled ~= false end
    function object:SetChecked(value) self.checked = not not value end
    function object:GetChecked() return self.checked or false end
    function object:SetMinMaxValues(min, max) self.minValue, self.maxValue = min, max end
    function object:GetMinMaxValues() return self.minValue, self.maxValue end
    function object:SetValueStep(value) self.valueStep = value end
    function object:SetObeyStepOnDrag(value) self.obeyStep = value end
    function object:SetOrientation(value) self.orientation = value end
    function object:SetThumbTexture(value)
        self.thumbTexture = self:CreateTexture(nil, "ARTWORK")
        self.thumbTexture:SetTexture(value)
    end
    function object:GetThumbTexture() return self.thumbTexture end
    function object:SetValue(value)
        if self.minValue then value = math.max(self.minValue, value) end
        if self.maxValue then value = math.min(self.maxValue, value) end
        local previous = self.value
        self.value = value
        if previous ~= value and self.scripts.OnValueChanged then
            self.scripts.OnValueChanged(self, value, false)
        end
    end
    function object:GetValue() return self.value end
    function object:RegisterForClicks(...) self.clickTypes = { ... } end
    function object:Click()
        if not self:IsEnabled() then return end
        if self.kind == "CheckButton" then self:SetChecked(not self:GetChecked()) end
        if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton", false) end
    end
    function object:CreateTexture(name, layer)
        local texture = setmetatable({ parent = self, name = name, layer = layer,
            scripts = {}, events = {}, kind = "Texture" }, { __index = object })
        if name then env[name] = texture end
        return texture
    end
    function object:CreateFontString(name, layer, template)
        local fontString = setmetatable({ parent = self, name = name, layer = layer,
            template = template, scripts = {}, events = {}, kind = "FontString" }, { __index = object })
        if name then env[name] = fontString end
        return fontString
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = setmetatable({ kind = kind, name = name, parent = parent, template = template,
            events = {}, scripts = {}, shown = true }, { __index = object })
        state.frames[#state.frames + 1] = frame
        if name then env[name] = frame end
        if template and template:find("OptionsSliderTemplate", 1, true) then
            for _, suffix in ipairs({ "Low", "High", "Text" }) do
                frame[suffix] = frame:CreateFontString(name and name .. suffix, "ARTWORK", "GameFontHighlightSmall")
            end
        elseif template and (template:find("CheckButtonTemplate", 1, true)
            or template:find("UICheckButtonTemplate", 1, true)) then
            frame.Text = frame:CreateFontString(name and name .. "Text", "ARTWORK", "GameFontNormal")
            frame.text = frame.Text
        end
        return frame
    end
    function state:fire(event, ...)
        if event == "PLAYER_LOGIN" then self.loggedIn = true end
        -- Only frames that existed at event dispatch start receive this event.
        local existing = {}
        for index, frame in ipairs(self.frames) do existing[index] = frame end
        for _, frame in ipairs(existing) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    local addon = {}
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(root .. "/" .. file))
        setfenv(chunk, env)
        chunk("CarGOUI", addon)
    end
    return env, addon, state
end

local function login(saved, late, client)
    local env, addon, state = setup(saved, late, client)
    state:fire("ADDON_LOADED", "CarGOUI")
    if not late then state:fire("PLAYER_LOGIN") end
    equal(#state.errors, 0, "startup errors")
    return env, addon, state
end

local function anchor(addon, env, x, y)
    local point, relative, relativePoint, actualX, actualY = addon.frame:GetPoint()
    equal(point, "CENTER", "anchor")
    equal(relative, env.UIParent, "relative frame")
    equal(relativePoint, "CENTER", "relative anchor")
    local scale = addon.frame:GetScale()
    truthy(math.abs(actualX * scale - x) < 0.000001, "horizontal offset in UIParent units")
    truthy(math.abs(actualY * scale - y) < 0.000001, "vertical offset in UIParent units")
end

local function font(addon, size, outline)
    local face, actualSize, actualOutline = addon.frame.text:GetFont()
    equal(face, "Fonts\\FRIZQT__.ttf", "font face")
    equal(actualSize, size, "font size")
    equal(actualOutline or "", outline, "font outline")
end

local function test(name, callback)
    callback()
    total = total + 1
    print("PASS " .. name)
end

test("TOC declares the Retail target, SavedVariables and unique load entries", function()
    equal(metadata.Interface, "120100", "Retail 12.1 interface")
    equal(metadata.SavedVariables, "CarGOUIDB", "SavedVariables declaration")
    local seen = {}
    for _, file in ipairs(files) do
        truthy(not seen[file], "Duplicate TOC entry: " .. file)
        seen[file] = true
    end
end)

test("fresh install initializes once and waits for PLAYER_LOGIN", function()
    local env, addon, state = setup(nil, false)
    equal(addon.frame, nil, "display before ADDON_LOADED")
    state:fire("ADDON_LOADED", "AnotherAddOn")
    equal(env.CarGOUIDB, nil, "unrelated ADDON_LOADED must not initialize DB")
    truthy(not addon.initialized, "unrelated AddOn initialized CarGOUI")
    state:fire("ADDON_LOADED", "CarGOUI")
    truthy(addon.initialized, "own ADDON_LOADED initializes")
    equal(addon.db, env.CarGOUIDB, "saved variables reference")
    equal(addon.db.schemaVersion, 1, "schema version")
    equal(addon.frame, nil, "display before login")
    equal(env.SLASH_CARGOUI1, "/cargoui", "slash alias")
    equal(type(env.SlashCmdList.CARGOUI), "function", "slash callback")
    state:fire("PLAYER_LOGIN")
    truthy(addon.enabled, "enabled after login")
    truthy(addon.frame and addon.frame.text, "frame and font string created")
    anchor(addon, env, 0, 0)
    font(addon, 24, "OUTLINE")
    truthy(addon.frame:GetWidth() > 0 and addon.frame:GetHeight() > 0, "display dimensions")
    local frame, db, frameCount = addon.frame, addon.db, #state.frames
    state:fire("ADDON_LOADED", "CarGOUI")
    state:fire("PLAYER_LOGIN")
    equal(addon.frame, frame, "display identity after repeated lifecycle events")
    equal(addon.db, db, "DB identity after repeated lifecycle events")
    equal(#state.frames, frameCount, "no duplicate frames")
    equal(#state.errors, 0, "startup errors")
end)

test("valid SavedVariables survive a simulated reload", function()
    local saved = { schemaVersion = 1, enabled = true, position = { x = 125, y = -75 },
        font = { face = "Fonts\\FRIZQT__.ttf", size = 32, outline = "THICKOUTLINE" },
        scale = 1.25, shadow = { enabled = false }, futureOption = { value = 42 } }
    local env, addon = login(saved)
    anchor(addon, env, 125, -75)
    font(addon, 32, "THICKOUTLINE")
    equal(addon.frame:GetScale(), 1.25, "saved scale")
    equal(addon.db.futureOption.value, 42, "unrelated key preserved")
    local env2, addon2 = login(copy(env.CarGOUIDB))
    anchor(addon2, env2, 125, -75)
    font(addon2, 32, "THICKOUTLINE")
    same(addon2.db, addon.db, "reload persistence")
end)

test("late loading after login creates the display", function()
    local env, addon = login(nil, true)
    truthy(addon.initialized and addon.enabled and addon.frame, "late-loaded startup")
    anchor(addon, env, 0, 0)
end)

test("malformed SavedVariables and non-finite numbers recover safely", function()
    for _, malformed in ipairs({ false, 17, "invalid" }) do
        local _, addon = login(malformed)
        equal(addon.db.font.size, 24, "invalid root reset")
    end
    local env, addon = login({ schemaVersion = "invalid", enabled = "yes",
        position = { x = math.huge, y = 0 / 0 },
        font = { face = false, size = -10, outline = "INVALID" },
        scale = math.huge, shadow = { enabled = "yes" }, other = "preserve me" })
    anchor(addon, env, 0, 0)
    font(addon, 24, "OUTLINE")
    equal(addon.db.enabled, true, "invalid enabled setting")
    equal(addon.db.scale, 1, "invalid scale")
    equal(addon.db.shadow.enabled, true, "invalid shadow")
    equal(addon.db.other, "preserve me", "unrelated setting")
    local _, addon2 = login({ position = true, font = "bad", shadow = 9, scale = -1 })
    equal(addon2.db.position.x, 0, "malformed position")
    equal(addon2.db.font.size, 24, "malformed font")
    equal(addon2.db.shadow.enabled, true, "malformed shadow")
    local env3, addon3 = login({ position = { x = 10001, y = -10001 },
        font = { size = 73 }, scale = 3.01 })
    anchor(addon3, env3, 0, 0)
    font(addon3, 24, "OUTLINE")
    equal(addon3.db.scale, 1, "finite out-of-range scale")
end)

test("slash commands apply position, typography, visibility and reset", function()
    local env, addon, state = login(nil)
    local command = env.SlashCmdList.CARGOUI
    command("help")
    command("status")
    command("position 35 -60")
    anchor(addon, env, 35, -60)
    equal(addon.db.position.x, 35, "saved x")
    equal(addon.db.position.y, -60, "saved y")
    command("fontsize 30")
    font(addon, 30, "OUTLINE")
    command("outline none")
    font(addon, 30, "")
    command("outline thickoutline")
    font(addon, 30, "THICKOUTLINE")
    command("outline outline")
    font(addon, 30, "OUTLINE")
    command("scale 1.2")
    equal(addon.frame:GetScale(), 1.2, "applied scale")
    anchor(addon, env, 35, -60)
    command("shadow off")
    equal(addon.db.shadow.enabled, false, "disabled shadow")
    local shadowX, shadowY = addon.frame.text:GetShadowOffset()
    equal(shadowX, 0, "disabled shadow x")
    equal(shadowY, 0, "disabled shadow y")
    command("hide")
    equal(addon.db.enabled, false, "saved hidden state")
    equal(addon.frame:IsShown(), false, "hidden display")
    command("show")
    equal(addon.db.enabled, true, "saved shown state")
    equal(addon.frame:IsShown(), true, "shown display")
    command("shadow on")
    equal(addon.db.shadow.enabled, true, "enabled shadow")
    local prior = copy(addon.db)
    for _, invalid in ipairs({ "position nope 10", "position 10", "position 1e309 1",
        "position 10001 0", "position 0 -10001", "fontsize -1", "fontsize 73",
        "fontsize 1e309", "fontsize nope", "outline bogus", "scale 0", "scale 3.01",
        "scale 1e309", "shadow maybe", "show extra", "reset extra", "unknowncommand" }) do
        command(invalid)
        same(addon.db, prior, "invalid command must not mutate settings: " .. invalid)
    end
    command("reset")
    anchor(addon, env, 0, 0)
    font(addon, 24, "OUTLINE")
    equal(addon.frame:GetScale(), 1, "reset scale")
    equal(#state.errors, 0, "command errors")
end)

test("saved hidden state remains hidden on reload", function()
    local env, addon = login(nil)
    env.SlashCmdList.CARGOUI("hide")
    local _, reloaded = login(copy(addon.db))
    equal(reloaded.db.enabled, false, "hidden preference persisted")
    equal(reloaded.frame:IsShown(), false, "reload honors hidden preference")
end)

test("event dispatch uses a snapshot and ignores duplicate listeners", function()
    local _, addon, state = login(nil)
    local calls = {}
    local third = function(_, event, value)
        equal(event, "CARGOUI_TEST", "listener event")
        equal(value, 7, "listener payload")
        calls[#calls + 1] = "third"
    end
    local second = function(self) equal(self, addon, "listener receiver"); calls[#calls + 1] = "second" end
    local first = function(self)
        calls[#calls + 1] = "first"
        self:UnregisterEvent("CARGOUI_TEST", second)
        self:RegisterEvent("CARGOUI_TEST", third)
    end
    addon:RegisterEvent("CARGOUI_TEST", first)
    addon:RegisterEvent("CARGOUI_TEST", second)
    addon:RegisterEvent("CARGOUI_TEST", second)
    state:fire("CARGOUI_TEST", 7)
    same(calls, { "first", "second" }, "initial dispatch snapshot")
    calls = {}
    state:fire("CARGOUI_TEST", 7)
    same(calls, { "first", "third" }, "next dispatch reflects listener changes")
    addon:UnregisterEvent("CARGOUI_TEST", first)
    addon:UnregisterEvent("CARGOUI_TEST", third)
    calls = {}
    state:fire("CARGOUI_TEST", 7)
    equal(#calls, 0, "unregistered listeners are not called")
end)

test("event payload preserves nil arguments and listener receiver", function()
    local _, addon, state = login(nil)
    local called = false
    addon:RegisterEvent("CARGOUI_TEST_ARGUMENTS", function(self, event, ...)
        equal(self, addon, "listener receiver")
        equal(event, "CARGOUI_TEST_ARGUMENTS", "listener event")
        equal(select("#", ...), 4, "argument count including trailing nil")
        local first, second, third, fourth = ...
        equal(first, "first", "first argument")
        equal(second, nil, "middle nil argument")
        equal(third, 3, "third argument")
        equal(fourth, nil, "trailing nil argument")
        called = true
    end)
    state:fire("CARGOUI_TEST_ARGUMENTS", "first", nil, 3, nil)
    truthy(called, "payload listener invoked")
    equal(#state.errors, 0, "argument dispatch errors")
end)

test("listener failures reach the error handler without stopping later listeners", function()
    local _, addon, state = login(nil)
    local laterCalled = false
    addon:RegisterEvent("CARGOUI_TEST_ERROR", function() error("expected test error") end)
    addon:RegisterEvent("CARGOUI_TEST_ERROR", function() laterCalled = true end)
    state:fire("CARGOUI_TEST_ERROR")
    truthy(laterCalled, "listener after error runs")
    equal(#state.errors, 1, "reported listener error")
    truthy(string.find(state.errors[1], "expected test error", 1, true), "original error preserved")
end)

local function options(addon)
    addon:ToggleOptions()
    truthy(addon.optionsFrame and addon.optionsFrame:IsShown(), "Options opened")
    return addon.optionsFrame, addon.optionsFrame.controls
end

local function typeText(editBox, value)
    editBox:SetText(tostring(value))
    local textChanged = editBox:GetScript("OnTextChanged")
    if textChanged then textChanged(editBox, true) end
end

local function enter(editBox, value)
    typeText(editBox, value)
    local callback = editBox:GetScript("OnEnterPressed")
    truthy(callback, "edit box has an Enter handler")
    callback(editBox)
end

local function choose(dropdown, value)
    dropdown:Click()
    truthy(dropdown.menu and dropdown.menu:IsShown(), "dropdown menu opens")
    for _, option in ipairs(dropdown.choices) do
        if option.value == value then
            option:Click()
            equal(dropdown.menu:IsShown(), false, "dropdown closes after selection")
            return
        end
    end
    error("Missing dropdown option " .. tostring(value))
end

test("empty slash lazily creates and toggles one reusable Options window", function()
    local env, addon, state = login(nil)
    equal(addon.optionsFrame, nil, "no Options allocation at login")
    local initialFrames, initialMessages = #state.frames, #state.messages
    env.SlashCmdList.CARGOUI("")
    local panel = addon.optionsFrame
    truthy(panel and panel:IsShown(), "empty slash opens Options")
    equal(panel:GetName(), "CarGOUIOptionsFrame", "ESC-addressable Options name")
    equal(#state.messages, initialMessages, "empty slash does not print help")
    truthy(#state.frames > initialFrames, "controls allocated on first open")
    local allocated = #state.frames
    local registrations = 0
    for _, name in ipairs(env.UISpecialFrames) do
        if name == panel:GetName() then registrations = registrations + 1 end
    end
    equal(registrations, 1, "ESC close registered once")
    for _ = 1, 10 do
        env.SlashCmdList.CARGOUI("  ")
        equal(panel:IsShown(), false, "slash closes Options")
        env.SlashCmdList.CARGOUI("")
        equal(addon.optionsFrame, panel, "Options identity reused")
        equal(panel:IsShown(), true, "slash reopens Options")
    end
    equal(#state.frames, allocated, "ten reopens allocate no frames")
    env.SlashCmdList.CARGOUI("help")
    truthy(#state.messages > initialMessages, "explicit help prints commands")
    equal(panel:IsShown(), true, "help leaves panel alone")
    equal(#state.errors, 0, "Options creation errors")
end)

test("settings API rejects malformed patches atomically and preserves DB identity", function()
    local env, addon = login(nil)
    local db, position, fontSettings, shadow = addon.db, addon.db.position, addon.db.font, addon.db.shadow
    local before = copy(db)
    local invalid = {
        false, 12, "bad", { enabled = "yes" }, { position = false },
        { position = { x = 10001 } }, { position = { y = 0 / 0 } },
        { position = { x = math.huge } }, { font = true }, { font = { size = 7 } },
        { font = { outline = "BOGUS" } }, { font = { face = "arbitrary\\asset.ttf" } },
        { scale = 0.49 }, { scale = math.huge }, { shadow = false },
        { shadow = { enabled = 1 } }, { position = { x = 12, y = -10001 }, enabled = false },
        { enabled = false, font = { size = 30, outline = "INVALID" } },
        { unknownSetting = true }, { position = { x = 12, z = 1 } },
    }
    for index, patch in ipairs(invalid) do
        local ok, message = addon:UpdateSettings(patch)
        equal(ok, false, "reject invalid patch " .. index)
        truthy(type(message) == "string" and #message > 0, "validation reason " .. index)
        same(addon.db, before, "invalid patch must be atomic " .. index)
    end
    truthy(addon:UpdateSettings({ position = { x = 40 }, font = { size = 28 }, shadow = { enabled = false } }),
        "valid partial patch accepted")
    equal(addon.db, db, "DB reference stable")
    equal(env.CarGOUIDB, db, "SavedVariables references live DB")
    equal(addon.db.position, position, "position reference stable")
    equal(addon.db.font, fontSettings, "font reference stable")
    equal(addon.db.shadow, shadow, "shadow reference stable")
    anchor(addon, env, 40, 0)
    font(addon, 28, "OUTLINE")
end)

test("all daily GUI controls route through shared settings and survive reload", function()
    local env, addon, state = login(nil)
    local panel, controls = options(addon)
    local writes = 0
    local update = addon.UpdateSettings
    addon.UpdateSettings = function(self, patch)
        writes = writes + 1
        return update(self, patch)
    end
    local function changed(callback, label)
        local before = writes
        callback()
        truthy(writes > before, label .. " uses shared UpdateSettings")
    end
    typeText(controls.x, "165")
    typeText(controls.y, "-85")
    changed(function() controls.applyPosition:Click() end, "position")
    anchor(addon, env, 165, -85)
    changed(function() controls.enabled:Click() end, "visibility")
    equal(addon.db.enabled, false, "checkbox hides actual display")
    equal(addon.frame:IsShown(), false, "actual display hidden")
    controls.enabled:Click()
    changed(function() controls.scale:SetValue(1.35) end, "scale slider")
    equal(addon.db.scale, 1.35, "slider saves scale")
    anchor(addon, env, 165, -85)
    changed(function() enter(controls.scale.editBox, "1.6") end, "scale numeric field")
    equal(addon.db.scale, 1.6, "numeric scale saved")
    addon:SelectOptionsCategory("typography")
    changed(function() controls.fontSize:SetValue(36) end, "font size slider")
    font(addon, 36, "OUTLINE")
    changed(function() enter(controls.fontSize.editBox, "32") end, "font size numeric field")
    font(addon, 32, "OUTLINE")
    changed(function() choose(controls.outline, "THICKOUTLINE") end, "outline dropdown")
    font(addon, 32, "THICKOUTLINE")
    truthy(controls.font.choices and #controls.font.choices >= 1, "font choices available")
    changed(function() choose(controls.font, controls.font.choices[1].value) end, "font dropdown")
    equal(addon.db.font.face, controls.font.choices[1].value, "font choice saved")
    changed(function() controls.shadow:Click() end, "shadow checkbox")
    equal(addon.db.shadow.enabled, false, "shadow checkbox saved")
    controls.close:Click()
    equal(panel:IsShown(), false, "close button works")
    local _, reloaded = login(copy(env.CarGOUIDB))
    same(reloaded.db, addon.db, "GUI changes persist through reload")
    equal(reloaded.optionsFrame, nil, "reload still defers Options allocation")
    equal(#state.errors, 0, "GUI interactions cause no errors")
end)

test("pending XY edits are atomic, preserved until Apply, and discarded on close", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    typeText(controls.x, "250")
    typeText(controls.y, "not a number")
    local before = copy(addon.db)
    controls.applyPosition:Click()
    same(addon.db, before, "invalid coordinate pair changes neither axis")
    truthy(type(panel.feedback:GetText()) == "string" and #panel.feedback:GetText() > 0,
        "invalid input has visible feedback")
    controls.enabled:Click()
    equal(controls.x:GetText(), "250", "unrelated update preserves pending X")
    equal(controls.y:GetText(), "not a number", "unrelated update preserves pending Y")
    enter(controls.y, "-125")
    anchor(addon, env, 250, -125)
    typeText(controls.x, "900")
    controls.x:SetFocus()
    controls.close:Click()
    equal(controls.x:HasFocus(), false, "close clears keyboard focus")
    addon:ToggleOptions()
    equal(tonumber(controls.x:GetText()), 250, "reopen discards unapplied X")
    equal(tonumber(controls.y:GetText()), -125, "reopen restores saved Y")
    controls.centerPosition:Click()
    anchor(addon, env, 0, 0)
    equal(tonumber(controls.x:GetText()), 0, "center updates X field")
    equal(tonumber(controls.y:GetText()), 0, "center updates Y field")
end)

test("invalid numeric edits show errors without changing saved values", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    for _, field in ipairs({ controls.fontSize.editBox, controls.scale.editBox }) do
        for _, text in ipairs({ "", "invalid", "1e309", "-100" }) do
            local before = copy(addon.db)
            enter(field, text)
            same(addon.db, before, "invalid numeric edit leaves settings unchanged")
            truthy(panel.feedback:GetText() and #panel.feedback:GetText() > 0,
                "numeric validation feedback is visible")
        end
    end
end)

test("categories expose working pages and disable unfinished features", function()
    local _, addon = login(nil)
    local panel = options(addon)
    local found = {}
    for _, category in ipairs(panel.categories) do found[category.key] = category end
    for _, key in ipairs({ "general", "typography", "preview" }) do
        truthy(found[key] and found[key]:IsEnabled(), key .. " category enabled")
        truthy(panel.pages[key], key .. " page exists")
        found[key]:Click()
        truthy(panel.pages[key]:IsShown(), key .. " button activates page")
        for other, page in pairs(panel.pages) do
            if other ~= key then equal(page:IsShown(), false, "other pages hidden") end
        end
    end
    for _, key in ipairs({ "mobility", "proc", "themes", "importExport" }) do
        local button = found[key]
        truthy(button, key .. " future category visible")
        equal(button:IsEnabled(), false, key .. " future category disabled")
        button:Click()
        addon:SelectOptionsCategory(key)
        truthy(panel.pages.preview:IsShown(), "unfinished category cannot activate")
    end
end)

test("preview and dropdowns stop on category change and close, hidden refresh is idle", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    equal(panel.previewFrame:IsShown(), false, "no preview on General page")
    addon:SelectOptionsCategory("preview")
    equal(panel.previewFrame:IsShown(), true, "preview visible on Preview page")
    addon:UpdateSettings({ font = { size = 40, outline = "" }, scale = 1.5, shadow = { enabled = false } })
    local _, size, outline = panel.previewFrame.text:GetFont()
    equal(size, 40, "visible preview updates font size")
    equal(outline or "", "", "visible preview updates outline")
    addon:SelectOptionsCategory("typography")
    equal(panel.previewFrame:IsShown(), false, "preview stops when leaving page")
    controls.outline:Click()
    truthy(controls.outline.menu:IsShown(), "dropdown open before close")
    addon:SelectOptionsCategory("general")
    equal(controls.outline.menu:IsShown(), false, "category change dismisses dropdown")
    addon:SelectOptionsCategory("typography")
    controls.outline:Click()
    panel:Hide()
    equal(controls.outline.menu:IsShown(), false, "closing window dismisses menu")
    addon:ToggleOptions()
    addon:SelectOptionsCategory("preview")
    panel:Hide()
    equal(panel.previewFrame:IsShown(), false, "closing window hides preview")
    local fontWrites, textWrites = state.fontWrites, state.textWrites
    for _ = 1, 5 do addon:RefreshOptions() end
    equal(state.fontWrites, fontWrites, "hidden refresh does not rerender preview font")
    equal(state.textWrites, textWrites, "hidden refresh does not update control text")
    local savedScale = addon.db.scale
    controls.scale:SetValue(2.25)
    equal(addon.db.scale, savedScale, "hidden slider event cannot update settings")
    local calls = 0
    local update = addon.UpdateSettings
    addon.UpdateSettings = function(self, patch) calls = calls + 1; return update(self, patch) end
    addon:ToggleOptions()
    for _ = 1, 5 do addon:RefreshOptions() end
    equal(calls, 0, "programmatic control refresh never writes settings")
    for _, frame in ipairs(state.frames) do
        equal(frame:GetScript("OnUpdate"), nil, "no frame runs permanent polling")
    end
end)

test("reset requires confirmation and close cancels an unconfirmed reset", function()
    local env, addon = login(nil)
    addon:UpdateSettings({ position = { x = 90, y = 45 }, font = { size = 36 }, scale = 1.7 })
    local panel, controls = options(addon)
    local before = copy(addon.db)
    controls.reset:Click()
    same(addon.db, before, "first reset click does not mutate settings")
    controls.close:Click()
    addon:ToggleOptions()
    controls.reset:Click()
    same(addon.db, before, "closing cancels old reset confirmation")
    typeText(controls.x, "999")
    controls.reset:Click()
    anchor(addon, env, 0, 0)
    font(addon, 24, "OUTLINE")
    equal(addon.db.scale, 1, "confirmed reset restores scale")
    equal(tonumber(controls.x:GetText()), 0, "reset clears pending X")
    equal(tonumber(controls.y:GetText()), 0, "reset refreshes Y")
    truthy(panel:IsShown(), "reset keeps Options open")
end)

test("Escape from any editable field closes Options and releases input focus", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    for _, editBox in ipairs({ controls.x, controls.y, controls.fontSize.editBox, controls.scale.editBox }) do
        if not panel:IsShown() then addon:ToggleOptions() end
        editBox:SetFocus()
        local escape = editBox:GetScript("OnEscapePressed")
        truthy(escape, "editable field has Escape handler")
        escape(editBox)
        equal(panel:IsShown(), false, "Escape closes Options")
        equal(editBox:HasFocus(), false, "Escape releases keyboard focus")
    end
end)

test("preview fits maximum settings and slider steps remain in range", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    for _, value in ipairs({ 0.5, 0.5000001, 1.049999999, 2.999999999, 3 }) do
        controls.scale:SetValue(value)
        truthy(addon:IsNumberInRange(addon.db.scale, addon.limits.scale), "rounded scale stays valid")
        truthy(math.abs(addon.db.scale * 20 - math.floor(addon.db.scale * 20 + 0.5)) < 0.00001,
            "slider produces 0.05 increments")
    end
    addon:UpdateSettings({ font = { size = 72 }, scale = 3 })
    addon:SelectOptionsCategory("preview")
    local preview = panel.previewFrame
    truthy(preview.text:GetStringWidth() * preview.text:GetScale() <= preview:GetWidth() - 32 + 0.001,
        "maximum-size preview fits horizontal bounds")
    truthy(preview.text:GetStringHeight() * preview.text:GetScale() <= preview:GetHeight() - 32 + 0.001,
        "maximum-size preview fits vertical bounds")
    equal(addon.db.scale, 3, "fitting preview does not alter actual scale setting")
    equal(addon.db.font.size, 72, "fitting preview does not alter actual font setting")
    equal(addon.frame:GetScale(), 3, "display keeps requested scale")
end)

test("interactive controls stay inside their pages and panel fits small screens", function()
    local env, addon, state = login(nil)
    local panel = options(addon)
    local containers = { [panel] = true }
    for _, page in pairs(panel.pages) do containers[page] = true end
    for _, frame in ipairs(state.frames) do
        local point = frame.point
        if containers[frame.parent] and point and point[1] == "TOPLEFT"
            and point[2] == frame.parent and point[3] == "TOPLEFT" then
            local x, y = point[4], point[5]
            truthy(x >= 0 and y <= 0, "control starts inside parent")
            truthy(x + frame:GetWidth() <= frame.parent:GetWidth(), "control fits parent width")
            truthy(-y + frame:GetHeight() <= frame.parent:GetHeight(), "control fits parent height")
        end
    end
    panel:Hide()
    env.UIParent.GetWidth = function() return 640 end
    env.UIParent.GetHeight = function() return 480 end
    addon:ToggleOptions()
    truthy(panel:GetWidth() * panel:GetScale() <= 640, "panel fits narrow viewport")
    truthy(panel:GetHeight() * panel:GetScale() <= 480, "panel fits short viewport")
end)

test("zhCN clients use English Options on first load and saved-data reload", function()
    local saved
    for pass = 1, 2 do
        local env, addon = login(saved, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
        equal(env.GetLocale(), "zhCN", "regression runs on a Chinese client")
        if pass == 2 then
            equal(addon.db.position.x, 37, "saved position survives reload")
            equal(addon.db.font.size, 32, "saved appearance survives reload")
        end
        env.SlashCmdList.CARGOUI("")
        local panel, controls = addon.optionsFrame, addon.optionsFrame.controls
        local categories = {}
        for _, category in ipairs(panel.categories) do categories[category.key] = category end
        equal(categories.general:GetText(), "> General", "active category is English")
        equal(categories.typography:GetText(), "Font & appearance", "appearance category is English")
        equal(controls.applyPosition:GetText(), "Apply", "apply button is English")
        equal(controls.close:GetText(), "Close", "close button is English")
        equal(panel.feedback:GetText(), "Changes apply immediately. For typed numbers, press Enter or Apply.",
            "opening guidance is English")

        enter(controls.x, "invalid")
        equal(panel.feedback:GetText(), "Enter X and Y from -10000 to 10000.",
            "validation feedback is English")
        enter(controls.x, "37")
        equal(panel.feedback:GetText(), "Settings applied.", "success feedback is English")
        addon:SelectOptionsCategory("typography")
        equal(controls.outline.choices[1]:GetText(), "None", "dropdown choice is English")
        enter(controls.fontSize.editBox, "32")
        addon:SelectOptionsCategory("preview")
        equal(panel.previewStatus:GetText(), "X: 37    Y: 0    Font size: 32    Scale: 1",
            "dynamic preview labels are English")
        controls.reset:Click()
        equal(controls.reset:GetText(), "Confirm reset", "reset confirmation button is English")
        equal(panel.feedback:GetText(), "Click Confirm reset to restore all CarGOUI defaults.",
            "reset confirmation guidance is English")
        controls.close:Click()
        saved = copy(addon.db)
    end
end)

test("font menu applies each supported face and localized client font persists", function()
    local _, addon = login(nil, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("typography")
    local foundFriz, foundClient = false, false
    for _, entry in ipairs(controls.font.choices) do
        choose(controls.font, entry.value)
        equal(addon.db.font.face, entry.value, "font dropdown writes chosen face")
        local face = addon.frame.text:GetFont()
        equal(face, entry.value, "font dropdown changes display face")
        if entry.value == "Fonts\\FRIZQT__.ttf" then foundFriz = true end
        if entry.value == "Fonts\\ARKai_T.ttf" then foundClient = true end
    end
    truthy(foundFriz, "Friz Quadrata remains selectable")
    truthy(foundClient, "localized client font selectable")
    local chosen = addon.db.font.face
    local _, reloaded = login(copy(addon.db), false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    equal(reloaded.db.font.face, chosen, "supported saved font survives reload")
    local ok = addon:UpdateSettings({ font = { face = "fonts\\frizqt__.TTF" } })
    truthy(ok, "supported font accepted case-insensitively")
    equal(addon.db.font.face, "Fonts\\FRIZQT__.ttf", "font path canonicalized")
    equal(panel:IsShown(), true, "Options created successfully with a localized client font")
end)

print("All " .. total .. " offline smoke tests passed.")
