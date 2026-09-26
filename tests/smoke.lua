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

local function setup(saved, loggedIn)
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.CarGOUIDB = saved
    env.SlashCmdList = {}
    env.UIParent = { name = "UIParent" }
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.ttf"
    local state = { frames = {}, errors = {}, messages = {}, loggedIn = loggedIn or false }
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

    local object = {}
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
    function object:Show() self.shown = true end
    function object:Hide() self.shown = false end
    function object:IsShown() return self.shown ~= false end
    function object:SetShown(shown) self.shown = not not shown end
    function object:SetAlpha(alpha) self.alpha = alpha end
    function object:SetFrameStrata(strata) self.strata = strata end
    function object:EnableMouse(enabled) self.mouseEnabled = enabled end
    function object:SetScript(event, callback) self.scripts[event] = callback end
    function object:GetScript(event) return self.scripts[event] end
    function object:RegisterEvent(event) self.events[event] = true end
    function object:UnregisterEvent(event) self.events[event] = nil end
    function object:IsEventRegistered(event) return self.events[event] or false end
    function object:UnregisterAllEvents() self.events = {} end
    function object:SetFont(face, size, flags)
        assert(type(face) == "string" and type(size) == "number", "Invalid SetFont arguments")
        self.font = { face, size, flags or "" }
        return true
    end
    function object:GetFont() return unpack(self.font or {}) end
    local function requireFont(fontString)
        assert(fontString.font or fontString.template,
            "FontString requires a font before setting or measuring text")
    end
    function object:SetText(text)
        requireFont(self)
        self.textValue = text
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
    function object:SetShadowOffset(x, y) self.shadowOffset = { x, y } end
    function object:GetShadowOffset() return unpack(self.shadowOffset or { 0, 0 }) end
    function object:SetShadowColor(...) self.shadowColor = { ... } end
    function object:CreateFontString(name, layer, template)
        local fontString = setmetatable({ parent = self, name = name, layer = layer, template = template }, { __index = object })
        if name then env[name] = fontString end
        return fontString
    end
    env.CreateFrame = function(kind, name, parent, template)
        local frame = setmetatable({ kind = kind, name = name, parent = parent, template = template,
            events = {}, scripts = {}, shown = true }, { __index = object })
        state.frames[#state.frames + 1] = frame
        if name then env[name] = frame end
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

local function login(saved, late)
    local env, addon, state = setup(saved, late)
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

print("All " .. total .. " offline smoke tests passed.")
