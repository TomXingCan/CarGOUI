-- Offline Lua 5.1 smoke tests. These mocks do not replace an in-game Retail test.
-- Run: python tests/run_tests.py --addon-root /path/to/CarGOUI
local root = assert(arg and arg[1], "Pass the CarGOUI AddOn directory as argument 1.")
local testRoot = arg[2] or root .. "/tests"
local launcherHarness = {}
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
local moduleRoot = root .. "/Modules/CarGOUI_Data"
local probe = io.open(moduleRoot .. "/CarGOUI_Data.toc", "r")
if probe then probe:close() else moduleRoot = root .. "/../CarGOUI_Data" end
local dataFiles, classFileCount = {}, 0
local dataTOC = assert(io.open(moduleRoot .. "/CarGOUI_Data.toc", "r"))
for line in dataTOC:lines() do
    local path = line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")
    if path ~= "" and path:sub(1, 1) ~= "#" then
        assert(path:match("%.lua$") and not path:find("..", 1, true), "Unsafe business TOC path")
        dataFiles[#dataFiles + 1] = path
        if path:match("^Classes/") then classFileCount = classFileCount + 1 end
    end
end
dataTOC:close()
local total, failed = 0, 0

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

-- Lua 5.1 cannot reproduce WoW's secret primitives or taint rules. Tokens catch
-- accidental string/arithmetic/ordering use; native mocks alone can unwrap them.
-- In particular Lua truth tests and unlike-type equality are not interceptable.
local secretValues = setmetatable({}, { __mode = "k" })
local function secret(value)
    local function forbidden() error("Attempt to inspect an opaque secret token", 2) end
    local token = setmetatable({}, { __tostring = forbidden, __add = forbidden,
        __sub = forbidden, __mul = forbidden, __div = forbidden, __mod = forbidden,
        __pow = forbidden, __unm = forbidden, __lt = forbidden, __le = forbidden,
        __concat = forbidden, __eq = forbidden })
    secretValues[token] = { value }
    return token
end

local function isSecret(value)
    return type(value) == "table" and secretValues[value] ~= nil
end

local function nativeValue(value)
    if isSecret(value) then return secretValues[value][1] end
    return value
end

local function setup(saved, loggedIn, client)
    client = client or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    -- Each fixture is an isolated WoW global environment, including upstream
    -- libraries that request it via getfenv(0) instead of the _G variable.
    env.getfenv = function(value)
        if value == 0 then return env end
        if type(value) == "number" then return getfenv(value + 1) end
        return getfenv(value)
    end
    env.CarGOUIDB = saved
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UIParent = { name = "UIParent", GetWidth = function() return client.uiWidth or 1920 end,
        GetHeight = function() return client.uiHeight or 1080 end,
        GetEffectiveScale = function() return client.uiScale or 1 end }
    function env.UIParent:GetCenter() return self:GetWidth() / 2, self:GetHeight() / 2 end
    env.STANDARD_TEXT_FONT = client.standardFont or "Fonts\\FRIZQT__.ttf"
    env.GameFontNormal = { template = "GameFontNormal" }
    env.GameFontHighlight = { template = "GameFontHighlight" }
    env.GameFontHighlightSmall = { template = "GameFontHighlightSmall" }
    local state = { frames = {}, errors = {}, messages = {}, loggedIn = loggedIn or false,
        fontWrites = 0, textWrites = 0, timers = 0, animations = {}, textures = {}, lines = {}, masks = {}, fontStrings = {},
        specID = client.specID or 63, classToken = client.classToken or "MAGE", realReads = 0,
        inCombat = client.inCombat or false, clock = 100, pendingTimers = {},
        faction = client.faction or "Alliance", factionReads = 0, gradientWrites = 0,
        bindings = {}, formatters = {}, curves = {}, curveEvaluations = {},
        spellReads = {}, knownReads = {}, overrideReads = {}, liveMeasurements = 0, alphaReads = 0, classColorReads = 0,
        loadedModules = {}, moduleNamespaces = {}, loadedFiles = {}, moduleLoads = 0,
        auraSlots = {}, auraFonts = {}, nativeAuraUpdates = 0, auraReads = 0,
        procKnown = client.procKnown or {}, procKnownReads = {},
        codecCalls = {}, codecFailures = {}, codecEmptyArrays = client.codecEmptyArrays == true }
    if client.specID == false then state.specID = nil end
    env.print = function(...) state.messages[#state.messages + 1] = { ... } end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, message)
        state.messages[#state.messages + 1] = message
    end }
    env.geterrorhandler = function()
        return function(message) state.errors[#state.errors + 1] = tostring(message) end
    end
    env.IsLoggedIn = function() return state.loggedIn end
    env.InCombatLockdown = function() return state.inCombat end
    env.IsShiftKeyDown = function() return state.shiftDown == true end
    env.IsControlKeyDown = function() return state.controlDown == true end
    env.IsAltKeyDown = function() return state.altDown == true end
    env.IsModifierKeyDown = function() return state.shiftDown or state.controlDown or state.altDown or false end
    env.WOW_PROJECT_MAINLINE, env.WOW_PROJECT_ID = 1, 1
    env.strmatch = string.match
    env.securecallfunction = function(callback, ...)
        local result = { pcall(callback, ...) }
        if not result[1] then env.geterrorhandler()(result[2]); return end
        return unpack(result, 2)
    end
    env.GetCursorPosition = function() return state.cursorX or 1100, state.cursorY or 960 end
    env.GetMinimapShape = function() return state.minimapShape or "ROUND" end
    env.GetBuildInfo = function() return "12.1.0", "99999", "Sep 26 2026", 120100 end
    env.GetLocale = function() return client.locale or "enUS" end
    env.C_UIFileAsset = { IsKnownFile = function(path)
        return type(path) == "string" and path ~= ""
            and not (client.unknownAssets and client.unknownAssets[path:lower()])
    end }
    -- Lua 5.1 has no built-in bit library. Model WoW's signed 32-bit AND for
    -- the real embedded LibSharedMedia locale masks; do not mock its registry.
    env.bit = { band = function(...)
        local result = 4294967295
        for index = 1, select("#", ...) do
            local left, right, value, place = result, select(index, ...) % 4294967296, 0, 1
            for _ = 1, 32 do
                if left % 2 == 1 and right % 2 == 1 then value = value + place end
                left, right, place = math.floor(left / 2), math.floor(right / 2), place * 2
            end
            result = value
        end
        return result >= 2147483648 and result - 4294967296 or result
    end }
    env.GetTime = function() return state.clock end
    env.issecretvalue = isSecret
    if not client.encodingUnavailable then
        local bridge = assert(_CAR_GO_UI_TEST_CODEC, "Run the complete suite with run_tests.py and lupa.lua51 encoding fixtures")
        env.C_EncodingUtil = {}
        for api, method in pairs({ SerializeJSON = "serialize", DeserializeJSON = "deserialize",
            EncodeBase64 = "encode", DecodeBase64 = "decode" }) do
            env.C_EncodingUtil[api] = function(value, argument)
                state.codecCalls[api] = (state.codecCalls[api] or 0) + 1
                if state.codecFailures[api] == "error" then error("offline native-shaped codec error") end
                if state.codecFailures[api] == "nil" then return nil end
                if api == "SerializeJSON" then
                    if argument then
                        for key in pairs(argument) do equal(key, "ignoreSerializationErrors", "only documented JSON option is accepted") end
                        equal(argument.ignoreSerializationErrors, false, "normal codec must not silently ignore invalid values")
                    end
                    return bridge[method](value, state.codecEmptyArrays)
                end
                if api == "DeserializeJSON" then return bridge[method](value) end
                return bridge[method](value, argument)
            end
        end
    end
    env.UnitFactionGroup = function(unit)
        equal(unit, "player", "automatic theme uses player faction")
        state.factionReads = state.factionReads + 1
        return state.faction, state.faction
    end
    env.CreateColor = function(r, g, b, a)
        return { r = r, g = g, b = b, a = a, GetRGBA = function() return r, g, b, a end }
    end
    env.UnitClass = function() return state.classToken, state.classToken, state.classToken == "MAGE" and 8 or 1 end
    state.classColors = client.classColors or { MAGE = { 0.25, 0.78, 0.92 }, WARRIOR = { 0.78, 0.61, 0.43 } }
    env.C_ClassColor = { GetClassColor = function(token)
        truthy(not isSecret(token), "class color lookup must receive a public class token")
        state.classColorReads = state.classColorReads + 1
        local rgb = state.classColors[token]
        if not rgb then return nil end
        return { GetRGB = function() return unpack(rgb) end }
    end }
    env.GetSpecialization = function() return state.specID and 2 or nil end
    env.GetSpecializationInfo = function() return state.specID, "Mock specialization" end
    env.C_SpecializationInfo = { GetSpecialization = env.GetSpecialization, GetSpecializationInfo = env.GetSpecializationInfo }
    local function noRealRead()
        state.realReads = state.realReads + 1
        error("Sample previews must not query live buffs, cooldowns, or charges")
    end
    env.UnitAura, env.UnitBuff, env.GetSpellCooldown, env.GetSpellCharges = noRealRead, noRealRead, noRealRead, noRealRead
    env.C_UnitAuras = { GetPlayerAuraBySpellID = noRealRead, GetAuraDataByIndex = noRealRead,
        GetAuraDataBySpellName = noRealRead }
    env.C_Spell = { GetSpellCooldown = noRealRead, GetSpellCharges = noRealRead }
    env.C_Timer = { After = function() error("No untracked scheduled work") end,
        NewTicker = function() error("Mobility and Options must not schedule polling tickers") end,
        NewTimer = function(delay, callback)
            equal(delay, 0, "only next-tick event coalescing timers are permitted")
            local timer = { callback = callback, cancelled = false }
            function timer:Cancel() self.cancelled = true end
            function timer:IsCancelled() return self.cancelled end
            state.pendingTimers[#state.pendingTimers + 1] = timer
            state.timers = state.timers + 1
            return timer
        end }
    function state:flushTimers()
        local pending = self.pendingTimers
        self.pendingTimers = {}
        for _, timer in ipairs(pending) do
            if not timer.cancelled then timer.callback(); timer.cancelled = true end
        end
        equal(#self.pendingTimers, 0, "event merge callback never schedules a polling retry")
    end
    function state:activeTimers()
        local count = 0
        for _, timer in ipairs(self.pendingTimers) do
            if not timer.cancelled then count = count + 1 end
        end
        return count
    end

    local durations = setmetatable({}, { __mode = "k" })
    local durationMethods = {}
    function durationMethods:IsZero()
        local item = assert(durations[self], "duration handle")
        local value = item.total <= 0
        return item.secret and secret(value) or value
    end
    function durationMethods:HasSecretValues() return durations[self].secret or false end
    function durationMethods:IsActive()
        local item = durations[self]
        local value = item.total > 0 and state.clock >= item.start
            and state.clock < item.start + item.total / item.rate
        return item.secret and secret(value) or value
    end
    function durationMethods:GetRemainingDuration()
        error("Live Lua must not calculate or read native remaining time")
    end
    function durationMethods:EvaluateTotalDuration(curve, modifier)
        equal(modifier, env.Enum.DurationTimeModifier.BaseTime, "visibility classifies base total, never remaining time")
        equal(curve.kind, env.Enum.LuaCurveType.Step, "charge visibility needs discrete native opacity")
        local item, value = durations[self], 0
        for _, point in ipairs(curve.points) do
            if item.total >= point[1] then value = point[2] end
        end
        state.curveEvaluations[#state.curveEvaluations + 1] = { duration = self, curve = curve }
        -- This unwrap/classification is the native mock, not an addon operation.
        return item.secret and secret(value) or value
    end
    function state:duration(start, total, restricted, rate)
        local handle = setmetatable({}, { __index = durationMethods })
        durations[handle] = { start = start or 0, total = total or 0,
            secret = restricted or false, rate = rate or 1 }
        return handle
    end

    env.Enum = { DurationTextBindingProperty = { RemainingDuration = 0 },
        DurationTimeModifier = { RealTime = 0, BaseTime = 1 },
        NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 },
        SpellBookSpellBank = { Player = 0, Pet = 1 }, LuaCurveType = { Step = 0 },
        Base64Variant = { Standard = 0, URLsafe = 1 } }
    env.C_CurveUtil = { CreateCurve = function()
        local curve = { points = {} }
        function curve:SetType(kind) self.kind = kind end
        function curve:AddPoint(x, y)
            truthy(not isSecret(x) and not isSecret(y), "curve points are public metadata, not decoded spell state")
            self.points[#self.points + 1] = { x, y }
        end
        state.curves[#state.curves + 1] = curve
        return curve
    end }
    if client.curveUnavailable then env.C_CurveUtil = nil end
    env.C_StringUtil = { CreateNumericRuleFormatter = function()
        local formatter = { breakpoints = {} }
        function formatter:AddBreakpoint(item) self.breakpoints[#self.breakpoints + 1] = item end
        function formatter:SetBreakpoints(items) self.breakpoints = items end
        state.formatters[#state.formatters + 1] = formatter
        return formatter
    end }
    env.C_DurationUtil = { CreateDurationTextBinding = function()
        local binding = { enabled = false }
        function binding:SetFontString(value) self.fontString = value; value.nativeDurationText = true end
        function binding:SetTextFormat(value, components) self.format, self.components = value, components end
        function binding:SetFormatter(value) self.formatter = value end
        function binding:SetTimeModifier(value) self.modifier = value end
        function binding:SetUpdateInterval(value) self.interval = value end
        function binding:SetExpiredText(value) self.expiredText = value end
        function binding:SetZeroDurationText(value) self.zeroText = value end
        function binding:SetDuration(value)
            truthy(durations[value], "SetDuration requires an ordinary opaque duration handle, never nil")
            self.duration = value
            self.durationWrites = (self.durationWrites or 0) + 1
        end
        function binding:SetEnabled(value)
            equal(type(value), "boolean", "binding enablement is public lifecycle state")
            self.enabled = value
        end
        function binding:Enable() self:SetEnabled(true) end
        function binding:Disable()
            self.disableCalls = (self.disableCalls or 0) + 1
            self:SetEnabled(false)
        end
        function binding:Assign(other)
            for _, key in ipairs({ "format", "components", "formatter", "modifier", "interval", "expiredText", "zeroText" }) do
                self[key] = other[key]
            end
        end
        function binding:SetToDefaults()
            self.enabled, self.duration, self.fontString = false, nil, nil
            self.format, self.components, self.formatter = nil, nil, nil
            self.expiredText, self.zeroText = nil, nil
        end
        function binding:UpdateFontString()
            local item, text = self.duration and durations[self.duration], ""
            if item then
                local remaining = math.max(0, (item.start + item.total / item.rate) - state.clock)
                if item.total <= 0 then text = self.zeroText or ""
                elseif remaining <= 0 then text = self.expiredText or ""
                else
                    local formatter = self.formatter or self.components and self.components[1].formatter
                    local rule = formatter and formatter.breakpoints[1]
                    local value = remaining
                    if rule and rule.step then
                        if rule.rounding == env.Enum.NumericRuleFormatRounding.Up then
                            value = math.ceil(value / rule.step - 0.000000001) * rule.step
                        else value = math.floor(value / rule.step + 0.5) * rule.step end
                    end
                    local number = string.format(rule and rule.format or "%.1f", value)
                    text = (self.format or "{}"):gsub("{}", number)
                end
            end
            if self.fontString then
                -- Native code writes without invoking any addon Lua text path.
                self.fontString.nativeRenderedText = text
                self.fontString.textValue = item and item.secret and secret(text) or text
            end
        end
        state.bindings[#state.bindings + 1] = binding
        return binding
    end }
    if client.nativeBindingUnavailable then env.C_DurationUtil = nil end
    function state:nativeTick()
        if self.refreshNativeAuras then self:refreshNativeAuras() end
        for _, binding in ipairs(self.bindings) do
            if binding.enabled then binding:UpdateFontString() end
        end
    end
    function state:advance(seconds) self.clock = self.clock + seconds; self:nativeTick() end

    if client.mobility then
        state.mobility = client.mobility
        state.mobility.known = state.mobility.known or { [1953] = true }
        state.mobility.spells = state.mobility.spells or {}
        state.allowedSpellIDs = client.allowedSpellIDs or { [1953] = true, [212653] = true,
            [342245] = true, [342247] = true, [389713] = true }
        -- Public metadata fixtures model the audited ordinary spell interval and
        -- GCD envelope. They do not prove actual client values or semantics.
        state.baseCooldowns = client.baseCooldowns or { [1953] = { 500, 1500 }, [212653] = { 500, 0 } }
        env.GetSpellBaseCooldown = function(id)
            truthy(state.allowedSpellIDs[id], "base metadata stays inside explicit current-class test fixture")
            local record = state.baseCooldowns[id]
            if record then return unpack(record) end
        end
        local function spellData(id, api)
            truthy(state.allowedSpellIDs[id], "live runtime only queries explicitly permitted current-class spell IDs")
            state.realReads = state.realReads + 1
            state.spellReads[#state.spellReads + 1] = { id = id, api = api }
            return state.mobility.spells[id]
        end
        env.C_SpellBook = { IsSpellKnown = function(id)
            -- This offline-only allowlist is learned metadata, not permission
            -- to query cooldowns, replacements, or hidden Proc aura IDs. The
            -- production factory remains lazy for the active class/spec.
            local data = state.moduleNamespaces.CarGOUI_Data
            local adapter = data and data.adapters and data.adapters[state.classToken]
            local factory = adapter and adapter.procFactory
            if factory and (state.procDriverFactory ~= factory or state.procDriverSpec ~= state.specID) then
                state.procDriverFactory, state.procDriverSpec, state.procDriverIDs = factory, state.specID, {}
                for _, definition in ipairs(state.specID and factory(state.specID) or {}) do
                    for _, field in ipairs({ "requiresKnown", "requiresAnyKnown", "excludesKnown" }) do
                        for _, driver in ipairs(definition[field] or {}) do state.procDriverIDs[driver] = true end
                    end
                end
            end
            if factory and state.procDriverIDs[id] then
                state.procKnownReads[#state.procKnownReads + 1] = { id = id, class = state.classToken, spec = state.specID }
                return state.procKnown[id] or false
            end
            truthy(state.allowedSpellIDs[id], "learning queries stay inside explicitly permitted current-class IDs")
            state.knownReads[#state.knownReads + 1] = id
            return state.mobility.known[id] or false
        end }
        env.C_Spell.GetOverrideSpell = function(id)
            truthy(state.allowedSpellIDs[id], "override queries stay inside explicit current-class IDs")
            state.overrideReads[#state.overrideReads + 1] = id
            if state.mobility.overrides then return state.mobility.overrides[id] or id end
            return state.mobility.override or id
        end
        env.C_Spell.GetSpellCharges = function(id)
            local item = spellData(id, "charges")
            if not item or item.unavailable or item.charges == nil then return nil end
            local active = item.charges < (item.maxCharges or 2)
            if item.active ~= nil then active = item.active end
            return { currentCharges = item.secretCharges and secret(item.charges) or item.charges,
                maxCharges = item.secretCapacity and secret(item.maxCharges or 2) or item.maxCharges or 2,
                isActive = item.secretActivity and secret(active) or active,
                cooldownStartTime = item.secretDuration and secret(item.chargeStart or 0) or item.chargeStart or 0,
                cooldownDuration = item.secretDuration and secret(item.chargeDuration or 0) or item.chargeDuration or 0,
                chargeModRate = item.secretDuration and secret(item.rate or 1) or item.rate or 1 }
        end
        env.C_Spell.GetSpellCooldown = function(id)
            local item = spellData(id, "cooldown")
            if not item or item.unavailable then return nil end
            local start, duration = item.cooldownStart or 0, item.cooldownDuration or 0
            return { startTime = item.secretDuration and secret(start) or start,
                duration = item.secretDuration and secret(duration) or duration,
                modRate = item.secretDuration and secret(item.rate or 1) or item.rate or 1,
                isEnabled = true, isActive = duration > 0, isOnGCD = item.isOnGCD or false }
        end
        env.C_Spell.GetSpellChargeDuration = function(id)
            local item = spellData(id, "charge-duration")
            if not item or item.unavailable or item.durationUnavailable or item.charges == nil then return nil end
            return state:duration(item.chargeStart, item.chargeDuration, item.secretDuration, item.rate)
        end
        env.C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD)
            equal(type(ignoreGCD), "boolean", "cooldown query explicitly selects its GCD purpose")
            local item = spellData(id, ignoreGCD and "cooldown-duration-timer" or "cooldown-duration-visibility")
            if not item or item.unavailable or item.durationUnavailable then return nil end
            return state:duration(item.cooldownStart, ignoreGCD and item.isOnGCD and 0 or item.cooldownDuration,
                item.secretDuration, item.rate)
        end
    end

    local object = {}
    function object:GetName() return self.name end
    function object:GetParent() return self.parent end
    function object:GetChildren()
        local children = {}
        for _, frame in ipairs(state.frames) do
            if frame.parent == self then children[#children + 1] = frame end
        end
        return unpack(children)
    end
    function object:SetParent(parent) self.parent = parent end
    function object:GetObjectType() return self.kind end
    function object:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "number" then
            x, y, relative, relativePoint = relative, relativePoint, self.parent, point
        end
        self.point = { point, relative, relativePoint, x or 0, y or 0 }
    end
    function object:ClearAllPoints() self.point = nil end
    function object:GetPoint() return unpack(self.point or {}) end
    function object:GetNumPoints() return self.point and 1 or 0 end
    function object:SetAllPoints(relative) self.allPoints = relative or self.parent end
    function object:SetScrollChild(child) self.scrollChild = child end
    function object:GetScrollChild() return self.scrollChild end
    function object:UpdateScrollChildRect() self.scrollChildUpdates = (self.scrollChildUpdates or 0) + 1 end
    function object:EnableMouseWheel(value) self.mouseWheelEnabled = value end
    function object:SetVerticalScroll(value)
        local changed = self.verticalScroll ~= value
        self.verticalScroll = value
        if changed and self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, value) end
    end
    function object:GetVerticalScroll() return self.verticalScroll or 0 end
    function object:GetVerticalScrollRange() return self.scrollChild and math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) or 0 end
    function object:SetSize(width, height)
        local changed = self.width ~= width or self.height ~= height
        self.width, self.height = width, height
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, width, height) end
    end
    function object:SetWidth(width) self:SetSize(width, self.height) end
    function object:SetHeight(height) self:SetSize(self.width, height) end
    function object:GetWidth() return self.width or (self.allPoints and self.allPoints:GetWidth()) end
    function object:GetHeight() return self.height or (self.allPoints and self.allPoints:GetHeight()) end
    function object:SetScale(scale) self.scale = scale end
    function object:GetScale() return self.scale or 1 end
    function object:GetEffectiveScale()
        return self:GetScale() * (self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1)
    end
    function object:GetCenter()
        if self.mockCenter then return unpack(self.mockCenter) end
        local relative = self.point and self.point[2] or env.UIParent
        local x, y = relative:GetCenter()
        local ratio = (relative.GetEffectiveScale and relative:GetEffectiveScale() or 1) / self:GetEffectiveScale()
        return x * ratio + (self.point and self.point[4] or 0), y * ratio + (self.point and self.point[5] or 0)
    end
    function object:SetMovable(value) self.movable = value end
    function object:RegisterForDrag(...) self.dragButtons = { ... } end
    function object:StartMoving()
        assert(self.movable, "Only movable frames can start moving")
        self.moving = true
        state.movingFrame = self
    end
    function object:StopMovingOrSizing() self.moving = false; state.movingFrame = nil end
    function object:Show()
        local wasShown = self:IsShown()
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function object:Hide()
        self.hideCalls = (self.hideCalls or 0) + 1
        local wasShown = self:IsShown()
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function object:IsShown()
        assert(not self.nativeAuraRestricted, "Addon must not read secure native aura child visibility")
        return self.shown ~= false
    end
    function object:IsVisible()
        return self:IsShown() and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible())
    end
    function object:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function object:SetAlpha(alpha)
        self.alpha = alpha
        self.alphaWrites = (self.alphaWrites or 0) + 1
    end
    function object:GetAlpha()
        if self.mobilityOwned then
            state.alphaReads = state.alphaReads + 1
            error("Live native visibility alpha must never be read back")
        end
        return self.alpha == nil and 1 or self.alpha
    end
    function object:SetFrameStrata(strata) self.strata = strata end
    function object:SetFixedFrameStrata(value) self.fixedFrameStrata = value end
    function object:SetFixedFrameLevel(value) self.fixedFrameLevel = value end
    function object:SetClampedToScreen(value) self.clampedToScreen = value end
    function object:SetFrameLevel(level) self.frameLevel = level end
    function object:GetFrameLevel() return self.frameLevel or 1 end
    function object:EnableMouse(enabled) self.mouseEnabled = enabled end
    function object:IsMouseEnabled() return self.mouseEnabled == true end
    function object:SetButtonState(value) self.buttonState = value end
    function object:GetButtonState() return self.buttonState or "NORMAL" end
    function object:SetScript(event, callback)
        assert(event ~= "OnUpdate" or callback == nil
            or (self.name == "LibDBIcon10_CarGOUI" and self.isMouseDown == true),
            "Only the vendored icon's active mouse drag may use a transient OnUpdate")
        self.baseScripts = self.baseScripts or {}
        self.baseScripts[event] = callback
        local hooks = self.scriptHooks and self.scriptHooks[event]
        if hooks then
            self.scripts[event] = function(...)
                if callback then callback(...) end
                for _, hook in ipairs(hooks) do hook(...) end
            end
        else self.scripts[event] = callback end
    end
    function object:GetScript(event) return self.scripts[event] end
    function object:HookScript(event, callback)
        -- Native post-hooks survive later SetScript replacements. Keep the
        -- event dispatcher available to fixture calls that simulate events.
        local previous
        if self.baseScripts then previous = self.baseScripts[event] else previous = self.scripts[event] end
        self.scriptHooks = self.scriptHooks or {}
        self.scriptHooks[event] = self.scriptHooks[event] or {}
        self.scriptHooks[event][#self.scriptHooks[event] + 1] = callback
        self:SetScript(event, previous)
    end
    function object:RegisterEvent(event) self.events[event] = true end
    function object:UnregisterEvent(event) self.events[event] = nil end
    function object:IsEventRegistered(event) return self.events[event] or false end
    function object:UnregisterAllEvents() self.events = {} end
    function object:SetFont(face, size, flags)
        assert(not self.nativeAuraRestricted, "Addon must style its owned Font, not restricted native aura text")
        assert(type(face) == "string" and type(size) == "number", "Invalid SetFont arguments")
        if client.unavailableFonts and client.unavailableFonts[face:lower()] then return nil end
        self.font = { face, size, flags or "" }
        self.fontWrites = (self.fontWrites or 0) + 1
        state.fontWrites = state.fontWrites + 1
        if not client.fontSetReturnsNil then return true end
    end
    function object:SetFontObject(value)
        assert(not self.nativeAuraRestricted, "Addon must not reassign a restricted native aura FontString")
        self.fontObject = value
    end
    function object:SetNormalFontObject(value) self.fontObject = value end
    function object:SetHighlightFontObject(value) self.highlightFontObject = value end
    function object:SetDisabledFontObject(value) self.disabledFontObject = value end
    function object:GetFont()
        assert(not self.nativeAuraRestricted, "Addon must not inspect a restricted native aura FontString")
        return unpack(self.font or {})
    end
    local function requireFont(fontString)
        local templateFont = fontString.template and (fontString.kind == "FontString" or fontString.kind == "GameTooltip"
            or fontString.template == "UIPanelButtonTemplate" or fontString.template == "InputBoxTemplate")
        assert(fontString.font or fontString.fontObject or templateFont,
            "FontString requires a font before setting or measuring text")
    end
    function object:SetText(text)
        requireFont(self.buttonLabel or self)
        self.textValue = text
        if self.buttonLabel then self.buttonLabel:SetText(text) end
        if self.nativeDurationText then self.nativeRenderedText = text end
        state.textWrites = state.textWrites + 1
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function object:GetText()
        assert(not self.nativeAuraRestricted, "Addon must not read secure native aura text")
        return self.textValue
    end
    function object:GetFontString()
        assert(self.kind == "Button", "GetFontString is a native Button API")
        if not self.buttonLabel then
            self.buttonLabel = self:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            self.buttonLabel:SetText(self.textValue or "")
        end
        return self.buttonLabel
    end
    function object:SetFontString(fontString)
        assert(self.kind == "Button" or self.kind == "CheckButton", "SetFontString is a native Button API")
        self.buttonLabel = fontString
    end
    function object:GetStringWidth()
        if self.nativeDurationText then
            state.liveMeasurements = state.liveMeasurements + 1
            error("Live native timer text width must never be inspected")
        end
        requireFont(self)
        return #tostring(self.textValue or "") * (self.font and self.font[2] or 24) * 0.6
    end
    function object:GetStringHeight()
        if self.nativeDurationText then
            state.liveMeasurements = state.liveMeasurements + 1
            error("Live native timer text height must never be inspected")
        end
        requireFont(self)
        return self.font and self.font[2] or 24
    end
    function object:SetTextColor(...)
        assert(not self.nativeAuraRestricted, "Addon must color its owned Font, not restricted native aura text")
        self.textColor = { ... }
    end
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
    function object:SetStartPoint(point, relative, x, y)
        equal(self.kind, "Line", "native start point belongs to Line geometry")
        self.startPoint = { point, relative, x, y }
    end
    function object:SetEndPoint(point, relative, x, y)
        equal(self.kind, "Line", "native end point belongs to Line geometry")
        self.endPoint = { point, relative, x, y }
    end
    function object:SetThickness(value)
        equal(self.kind, "Line", "native thickness belongs to Line geometry")
        truthy(type(value) == "number" and value > 0, "line thickness is positive")
        self.thickness = value
    end
    function object:SetTexture(value) self.texture = value end
    function object:GetTexture() return self.texture end
    function object:SetBlendMode(value) self.blendMode = value end
    function object:SetRotation(value) self.rotation = value end
    function object:SetDesaturation(value) self.desaturation = value end
    function object:SetGradient(orientation, first, last)
        truthy(orientation == "HORIZONTAL" or orientation == "VERTICAL", "native gradient direction is valid")
        self.gradient = { orientation = orientation, first = { first:GetRGBA() }, last = { last:GetRGBA() } }
        state.gradientWrites = state.gradientWrites + 1
    end
    function object:SetAtlas(value) self.atlas = value end
    function object:SetVertexColor(...) self.vertexColor = { ... } end
    function object:GetVertexColor() return unpack(self.vertexColor or { 1, 1, 1, 1 }) end
    function object:SetTexCoord(...) self.texCoord = { ... } end
    function object:SetDrawLayer(layer) self.layer = layer end
    function object:SetNormalTexture(value) self.normalTexture = value end
    function object:SetHighlightTexture(value) self.highlightTexture = value end
    function object:SetPushedTexture(value) self.pushedTexture = value end
    function object:SetDisabledTexture(value) self.disabledTexture = value end
    function object:SetCheckedTexture(value) self.checkedTexture = value end
    function object:LockHighlight() self.highlightLocked = true end
    function object:UnlockHighlight() self.highlightLocked = false end
    function object:SetOwner(owner, anchor) self.owner, self.ownerAnchor = owner, anchor; self.tooltipLines = {} end
    function object:GetOwner() return self.owner end
    function object:AddLine(text, ...) self.tooltipLines = self.tooltipLines or {}; self.tooltipLines[#self.tooltipLines + 1] = text end
    function object:SetAutoFocus(value) self.autoFocus = value end
    function object:SetNumeric(value) self.numeric = value end
    function object:SetMultiLine(value) self.multiLine = value end
    function object:SetMaxLetters(value) self.maxLetters = value end
    function object:SetMaxBytes(value) self.maxBytes = value end
    function object:SetCursorPosition(value) self.cursorPosition = value end
    function object:GetCursorPosition() return self.cursorPosition or 0 end
    function object:GetNumLines()
        return 1 + select(2, (self.textValue or ""):gsub("\n", ""))
    end
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
    local function nativeSetEnabled(self, value)
        local wasEnabled = self:IsEnabled()
        self.enabled = not not value
        local script = self.enabled and "OnEnable" or "OnDisable"
        if wasEnabled ~= self.enabled and self.scripts[script] then self.scripts[script](self) end
    end
    function object:SetEnabled(value) nativeSetEnabled(self, value) end
    -- Native Enable/Disable do not dispatch through a Lua SetEnabled override.
    function object:Enable() nativeSetEnabled(self, true) end
    function object:Disable() nativeSetEnabled(self, false) end
    function object:IsEnabled() return self.enabled ~= false end
    function object:SetChecked(value) self.checked = not not value end
    function object:GetChecked() return self.checked or false end
    function object:SetMinMaxValues(min, max) self.minValue, self.maxValue = min, max end
    function object:GetMinMaxValues() return self.minValue, self.maxValue end
    function object:SetValueStep(value) self.valueStep = value end
    function object:SetObeyStepOnDrag(value) self.obeyStep = value end
    function object:SetOrientation(value) self.orientation = value end
    function object:SetThumbTexture(value)
        assert(self.kind == "Slider", "SetThumbTexture is a native Slider API")
        -- TextureAsset is a path/FileDataID, never an existing SimpleTexture.
        assert(type(value) == "string" or type(value) == "number",
            "Slider:SetThumbTexture requires a TextureAsset string or number")
        self.thumbTextureAsset = value
        self.thumbTexture = self.thumbTexture or self:CreateTexture(nil, "ARTWORK")
        self.thumbTexture:SetTexture(value)
    end
    function object:GetThumbTexture()
        assert(self.kind == "Slider", "GetThumbTexture is a native Slider API")
        return self.thumbTexture
    end
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
        if self.scripts.PreClick then self.scripts.PreClick(self, "LeftButton", false) end
        -- Retail toggles CheckButton state natively before invoking OnClick;
        -- it does not call an addon override of the Lua SetChecked method.
        if self.kind == "CheckButton" then self.checked = not self:GetChecked() end
        if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton", false) end
        if self.scripts.PostClick then self.scripts.PostClick(self, "LeftButton", false) end
    end
    function object:CreateTexture(name, layer)
        local texture = setmetatable({ parent = self, name = name, layer = layer,
            scripts = {}, events = {}, kind = "Texture" }, { __index = object })
        if name then env[name] = texture end
        state.textures[#state.textures + 1] = texture
        return texture
    end
    function object:CreateLine(name, layer, template, sublevel)
        local line = setmetatable({ parent = self, name = name, layer = layer, template = template,
            sublevel = sublevel, scripts = {}, events = {}, kind = "Line" }, { __index = object })
        if name then env[name] = line end
        state.lines[#state.lines + 1] = line
        return line
    end
    function object:CreateMaskTexture(name, layer)
        local mask = setmetatable({ parent = self, name = name, layer = layer,
            scripts = {}, events = {}, kind = "MaskTexture" }, { __index = object })
        if name then env[name] = mask end
        state.masks[#state.masks + 1] = mask
        return mask
    end
    function object:AddMaskTexture(mask)
        assert(mask and mask.kind == "MaskTexture", "Glyph clipping requires a MaskTexture")
        self.masks = self.masks or {}
        self.masks[#self.masks + 1] = mask
    end
    function object:RemoveMaskTexture(mask)
        for index, existing in ipairs(self.masks or {}) do
            if existing == mask then table.remove(self.masks, index); return end
        end
    end
    function object:CreateFontString(name, layer, template)
        local fontString = setmetatable({ parent = self, name = name, layer = layer,
            template = template, scripts = {}, events = {}, kind = "FontString" }, { __index = object })
        if name then env[name] = fontString end
        state.fontStrings[#state.fontStrings + 1] = fontString
        return fontString
    end
    function object:CreateAnimationGroup()
        local group = { parent = self, animations = {}, scripts = {}, playing = false, plays = 0, stops = 0 }
        function group:SetLooping(value) self.looping = value end
        function group:SetScript(event, callback)
            assert(event ~= "OnUpdate" or callback == nil, "Decorative animation must use native interpolation")
            self.scripts[event] = callback
        end
        function group:GetScript(event) return self.scripts[event] end
        function group:Play()
            self.playing, self.plays = true, self.plays + 1
            if self.scripts.OnPlay then self.scripts.OnPlay(self) end
        end
        function group:Stop()
            local playing = self.playing
            self.playing, self.stops = false, self.stops + 1
            if playing and self.scripts.OnStop then self.scripts.OnStop(self) end
        end
        function group:IsPlaying() return self.playing end
        function group:SetToFinalAlpha(value) self.toFinalAlpha = value end
        function group:CreateAnimation(kind)
            local animation = { kind = kind }
            function animation:SetOrder(value) self.order = value end
            function animation:SetDuration(value) self.duration = value end
            function animation:SetStartDelay(value) self.startDelay = value end
            function animation:SetEndDelay(value) self.endDelay = value end
            function animation:SetSmoothing(value) self.smoothing = value end
            -- Retail 12.1 exposes subtype methods only on the matching kind.
            -- Scale uses SetScaleFrom/To, not the Alpha-style SetFrom/ToScale.
            if kind == "Alpha" then
                function animation:SetFromAlpha(value) self.fromAlpha = value end
                function animation:SetToAlpha(value) self.toAlpha = value end
            elseif kind == "Translation" then
                function animation:SetOffset(x, y) self.offset = { x, y } end
            elseif kind == "Scale" then
                function animation:SetScale(x, y) self.scale = { x, y } end
                function animation:SetScaleFrom(x, y) self.fromScale = { x, y } end
                function animation:SetScaleTo(x, y) self.toScale = { x, y } end
            elseif kind == "Rotation" then
                function animation:SetDegrees(value) self.degrees = value end
            end
            self.animations[#self.animations + 1] = animation
            return animation
        end
        state.animations[#state.animations + 1] = group
        return group
    end
    if client.maskUnavailable then object.CreateMaskTexture = nil end
    -- Existing Blizzard surfaces are native fixtures, not addon-created frames.
    env.Minimap = setmetatable({ name = "Minimap", kind = "Minimap", parent = env.UIParent,
        width = 140, height = 140, mockCenter = { 1800, 960 }, scripts = {}, events = {} }, { __index = object })
    env.GameTooltip = setmetatable({ name = "GameTooltip", kind = "GameTooltip", parent = env.UIParent,
        template = "GameTooltipTemplate", shown = false, scripts = {}, events = {} }, { __index = object })
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
    env.CreateFont = function(name)
        local font = setmetatable({ kind = "Font", name = name, scripts = {}, events = {} }, { __index = object })
        state.auraFonts[#state.auraFonts + 1] = font
        if name then env[name] = font end
        return font
    end
    -- Native ColorPickerFrame contract from the pinned Retail FrameXML: swatchFunc
    -- runs on every change AND on Okay before Hide. There is no acceptFunc.
    -- The fixture uses the actual button script order so an OnHide-only commit
    -- cannot incorrectly treat Escape, cancellation, or replacement as Okay.
    env.hooksecurefunc = function(owner, method, callback)
        if type(owner) == "string" then callback, method, owner = method, owner, env end
        local previous = assert(owner[method], "hooksecurefunc target exists")
        owner[method] = function(...)
            local result = { previous(...) }
            callback(...)
            return unpack(result)
        end
    end
    if not client.pickerUnavailable then
        local picker = env.CreateFrame("Frame", "ColorPickerFrame", env.UIParent)
        picker.shown = false
        picker.Footer = { OkayButton = env.CreateFrame("Button", nil, picker),
            CancelButton = env.CreateFrame("Button", nil, picker) }
        function picker:GetColorRGB() return unpack(self.rgb) end
        function picker:SetupColorPickerAndShow(info)
            self.swatchFunc, self.cancelFunc, self.extraInfo = info.swatchFunc, info.cancelFunc, info.extraInfo
            self.opacityFunc, self.hasOpacity = info.opacityFunc, info.hasOpacity
            self.previousValues = { r = info.r, g = info.g, b = info.b, a = info.opacity }
            self.rgb = { info.r, info.g, info.b }
            self:Show()
        end
        picker.Footer.OkayButton:SetScript("OnClick", function()
            if picker.swatchFunc then picker.swatchFunc() end
            picker:Hide()
        end)
        picker.Footer.CancelButton:SetScript("OnClick", function()
            if picker.cancelFunc then picker.cancelFunc(picker.previousValues) end
            picker:Hide()
        end)
        function state:pickerChange(r, g, b)
            truthy(picker:IsShown(), "native picker is open before user changes RGB")
            picker.rgb = { r, g, b }
            if picker.swatchFunc then picker.swatchFunc() end
        end
    end
    if client.proc then
        state.proc = client.proc
        state.proc.auras = state.proc.auras or {}
        state.proc.cvars = state.proc.cvars or { displaySpellActivationOverlays = true, spellActivationOverlayOpacity = "1" }
        env.C_CVar = { GetCVarBool = function(name) return state.proc.cvars[name] end,
            GetCVar = function(name) return state.proc.cvars[name] end }
        env.Enum.ScreenLocationType = {}
        for index, name in ipairs({ "Center", "Left", "Right", "Top", "Bottom", "TopLeft", "TopRight",
                "LeftRight", "TopBottom", "LeftRightOutside", "LeftOutside", "RightOutside" }) do
            env.Enum.ScreenLocationType[name] = index
        end
        env.SpellActivationOverlayFrame = env.CreateFrame("Frame", "SpellActivationOverlayFrame", env.UIParent)
        env.SpellActivationOverlayFrame:SetSize(256 * 0.8, 256 * 0.8)
        env.SpellActivationOverlayFrame:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
        env.SpellActivationOverlayFrame:SetScale(state.proc.overlayScale or 1)
        env.CustomAuraContainerMixin = {}
        env.C_XMLUtil = { GetTemplateInfo = function(name)
            equal(name, "CustomAuraContainerTemplate", "only the verified aura template is probed")
            return not state.proc.templateUnavailable and {} or nil
        end }
        local createFrame = env.CreateFrame
        local function NativeVisible(container)
            -- This is native test machinery, not an addon-accessible aura read.
            return container.enabled and container:IsVisible()
        end
        function state:refreshNativeAuras()
            local cleared = {}
            for _, slot in ipairs(self.auraSlots) do
                -- A native dirty pass is postponed while any public ancestor is
                -- hidden. Addon shutdown must leave the wrapper shown/alpha=0.
                if slot.container:IsVisible() and (slot.container.nativeAuraDirty or NativeVisible(slot.container)) then
                local candidate
                if NativeVisible(slot.container) then
                    for _, aura in pairs(self.proc.auras) do
                        local id = nativeValue(aura.spellID)
                        if slot.filters.includeSpellIDs[id] and aura.helpful ~= false then
                            local item = aura.duration and durations[aura.duration]
                            if not item or item.total == 0 or self.clock < item.start + item.total / item.rate then
                                candidate = aura; break
                            end
                        end
                    end
                end
                slot.nativeAura, slot.nativeShown = candidate, candidate ~= nil
                local binding = slot.nativeBinding
                if binding then
                    binding.duration = candidate and candidate.duration or nil
                    binding.enabled = candidate ~= nil and candidate.duration ~= nil
                    binding:UpdateFontString()
                end
                self.nativeAuraUpdates = self.nativeAuraUpdates + 1
                cleared[slot.container] = true
                end
            end
            for container in pairs(cleared) do container.nativeAuraDirty = false end
        end
        function state:nativeAuraText(container)
            self:nativeTick()
            local text = {}
            local ancestor = container
            while ancestor do
                if ancestor.shown == false or nativeValue(ancestor.alpha) == 0 then return "" end
                ancestor = ancestor.parent
            end
            for _, slot in ipairs(self.auraSlots) do
                if slot.container == container and slot.nativeShown and NativeVisible(container) then
                    for _, child in ipairs(slot.children) do
                        text[#text + 1] = child.nativeRenderedText or child.textValue or ""
                    end
                end
            end
            return table.concat(text, "")
        end
        function state:activeAuraSlots()
            local count = 0
            for _, slot in ipairs(self.auraSlots) do if NativeVisible(slot.container) then count = count + 1 end end
            return count
        end
        local nativeSlotKeys = {}
        env.CreateFrame = function(kind, name, parent, template)
            local frame = createFrame(kind, name, parent, template)
            if template and template:find("CustomAuraContainerTemplate", 1, true) then
                equal(kind, "AuraContainer", "custom native aura template uses native AuraContainer type")
                frame.nativeAuraContainer = true
                frame.nativeProviderSwitchRegistered = true
                frame.nativeDynamicListening = false
                frame.nativeAddSlotCalls = 0
                nativeSlotKeys[frame] = {}
                frame.enabled = false
                function frame:SetUnit(unit) equal(unit, "player", "only player helpful auras are configured"); self.unit = unit end
                function frame:SetEnabled(value)
                    equal(type(value), "boolean", "native container enable is public lifecycle state")
                    self.enabled = value
                    self.nativeDynamicListening = value and self:IsVisible() and next(nativeSlotKeys[self]) ~= nil
                    self.nativeAuraDirty = true
                end
                function frame:AddAuraSlot(key, filter, configuration)
                    self.nativeAddSlotCalls = self.nativeAddSlotCalls + 1
                    assert(not nativeSlotKeys[self][key], "Native AddAuraSlot rejects duplicate stable keys")
                    equal(filter, "HELPFUL", "Proc native filtering is helpful-player only")
                    truthy(configuration.candidateFilters.includeSpellIDs, "candidate filters declare audited aura IDs")
                    for id, enabled in pairs(configuration.candidateFilters.includeSpellIDs) do
                        truthy(type(id) == "number" and not isSecret(id) and enabled == true, "native spell filter is static public mapping")
                    end
                    local slot = { container = self, key = key, filters = configuration.candidateFilters, children = {} }
                    local button = createFrame("Button", nil, self)
                    slot.button = button
                    -- Intrinsic forbidden aspects precede initializeFrame.
                    function button:SetParent() error("AuraButton intrinsic forbids ChangeParent") end
                    for _, method in ipairs({ "SetAllPoints", "EnableMouse", "SetAlpha", "SetScale", "SetPoint" }) do
                        local original = button[method]
                        button[method] = function(object, ...)
                            assert(not object.nativeAuraRestricted, "Native child cannot be mutated after initialization")
                            return original(object, ...)
                        end
                    end
                    function button:SetDurationText(text, options)
                        assert(not self.nativeAuraRestricted, "Duration binding is initialization-only")
                        local binding = env.C_DurationUtil.CreateDurationTextBinding()
                        binding:Assign(options.binding)
                        binding:SetFontString(text)
                        slot.nativeBinding = binding
                    end
                    local createFontString = button.CreateFontString
                    function button:CreateFontString(...)
                        local text = createFontString(self, ...)
                        slot.children[#slot.children + 1] = text
                        return text
                    end
                    -- securecallfunction reports callback errors but its result
                    -- is ignored by the native provider. AddAuraSlot can return
                    -- normally with partially initialized content.
                    local initialized, failure = pcall(configuration.initializeFrame, button)
                    if not initialized then state.errors[#state.errors + 1] = failure end
                    -- Simulates the native restriction boundary after initialization.
                    button.nativeAuraRestricted = true
                    for _, text in ipairs(slot.children) do text.nativeAuraRestricted = true end
                    nativeSlotKeys[self][key] = true
                    state.auraSlots[#state.auraSlots + 1] = slot
                    self.nativeDynamicListening = self.enabled and self:IsVisible()
                    self.nativeAuraDirty = true
                    return button
                end
            end
            return frame
        end
    end
    function state:fire(event, ...)
        if event == "UNIT_AURA" and self.refreshNativeAuras then self:refreshNativeAuras() end
        if event == "PLAYER_LOGIN" then self.loggedIn = true end
        if event == "PLAYER_REGEN_DISABLED" then self.inCombat = true end
        if event == "PLAYER_REGEN_ENABLED" then self.inCombat = false end
        -- Only frames that existed at event dispatch start receive this event.
        local existing = {}
        for index, frame in ipairs(self.frames) do existing[index] = frame end
        for _, frame in ipairs(existing) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    local addon = {}
    state.addon = addon
    env.C_AddOns = {
        IsAddOnLoaded = function(name)
            return state.loadedModules[name] == true, state.loadedModules[name] == true
        end,
        LoadAddOn = function(name)
            equal(name, "CarGOUI_Data", "only the unified business data package may load")
            truthy(not state.inCombat, "native LoD loading must defer combat")
            if client.moduleUnavailable then return false, "MISSING" end
            if state.loadedModules[name] then return true end
            state.moduleLoads = state.moduleLoads + 1
            local namespace = {}
            state.moduleNamespaces[name] = namespace
            local moduleTOC = assert(io.open(moduleRoot .. "/CarGOUI_Data.toc", "r"))
            for line in moduleTOC:lines() do
                local path = line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")
                if path ~= "" and path:sub(1, 1) ~= "#" then
                    local chunk = assert(loadfile(moduleRoot .. "/" .. path))
                    state.loadedFiles[#state.loadedFiles + 1] = name .. "/" .. path
                    setfenv(chunk, env); chunk(name, namespace)
                end
            end
            moduleTOC:close()
            state.loadedModules[name] = true
            state:fire("ADDON_LOADED", name)
            return true
        end,
    }
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(root .. "/" .. file))
        state.loadedFiles[#state.loadedFiles + 1] = "CarGOUI/" .. file
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

local function savedPosition(addon, env, x, y)
    equal(addon:GetMobilityConfig().position.x, x, "saved horizontal reminder offset")
    equal(addon:GetMobilityConfig().position.y, y, "saved vertical reminder offset")
end

local function savedFont(addon, size, outline)
    equal(addon:GetMobilityConfig().style.font.face, "Fonts\\FRIZQT__.ttf", "saved font face")
    equal(addon:GetMobilityConfig().style.font.size, size, "saved font size")
    equal(addon:GetMobilityConfig().style.font.outline, outline, "saved font outline")
end

local function test(name, callback)
    total = total + 1
    local ok, message = pcall(callback)
    if ok then print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(message)) end
end

test("TOC declares the Retail target, SavedVariables and unique load entries", function()
    equal(metadata.Interface, "120100", "Retail 12.1 interface")
    equal(metadata.SavedVariables, "CarGOUIDB", "SavedVariables declaration")
    equal(metadata.SavedVariablesPerCharacter, nil, "no character-specific research persistence")
    local seen = {}
    for _, file in ipairs(files) do
        truthy(not seen[file], "Duplicate TOC entry: " .. file)
        truthy(not file:lower():match("^research/"), "production TOC never loads research: " .. file)
        seen[file] = true
    end
end)

test("baseline production startup has no research logger or research event subscriptions", function()
    local researchEvents = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_AURA", "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_HEALTH", "UNIT_MAXHEALTH" }
    for _, specID in ipairs({ 62, 63, 64 }) do
        for _, late in ipairs({ false, true }) do
            local _, addon, state = setup(nil, late, { specID = specID, proc = {} })
            equal(addon.ClassToolsRawCapture, nil, "TOC execution never attaches research")
            state:fire("ADDON_LOADED", "CarGOUI")
            if not late then state:fire("PLAYER_LOGIN") end
            equal(addon.ClassToolsRawCapture, nil, "login never attaches research")
            local diagnostics = addon:GetEventDiagnostics()
            for _, event in ipairs(researchEvents) do
                equal(diagnostics.perEvent[event], nil, "event router has no research listener for " .. event)
            end
            for _, file in ipairs(state.loadedFiles) do
                equal(file:lower():find("/research/", 1, true), nil, "loaded files exclude research")
            end
            equal(#state.errors, 0, "production startup has no research dependency")
        end
    end
end)

test("baseline production commands reject ctlog even when a logger is manually attached", function()
    for _, attached in ipairs({ false, true }) do
        local env, addon, state = login()
        local before, listeners, frames = copy(addon.db), addon:GetEventDiagnostics(), #state.frames
        local calls = 0
        if attached then
            addon.ClassToolsRawCapture = { HandleCommand = function() calls = calls + 1 end }
        end
        for _, message in ipairs({ "ctlog", "ctlog arcane on", "ctlog combustion on", "ctlog altertime on",
            "ctlog status", "ctlog dump", "ctlog off", "ctlog clear", "CTLOG ARCANE ON" }) do
            env.SlashCmdList.CARGOUI(message)
            truthy(state.messages[#state.messages]:find(addon:Text("Invalid command. Type /cui help for help."), 1, true),
                "removed research command follows ordinary invalid-command handling")
        end
        equal(calls, 0, "production command routing cannot invoke an attached research logger")
        local messagesBefore = #state.messages
        env.SlashCmdList.CARGOUI("help")
        truthy(#state.messages > messagesBefore, "production help remains available")
        for index = messagesBefore + 1, #state.messages do
            equal(state.messages[index]:lower():find("ctlog", 1, true), nil, "production help omits research commands")
        end
        same(addon.db, before, "removed commands never alter existing settings or persist research data")
        same(addon:GetEventDiagnostics(), listeners, "removed commands never add event subscriptions")
        equal(#state.frames, frames, "removed commands never create a research copy surface")
        equal(addon.optionsFrame, nil, "invalid commands and help preserve lazy Options")
        equal(#state.errors, 0, "missing research module causes no command error")
    end
end)

test("fresh install initializes once and waits for PLAYER_LOGIN", function()
    local env, addon, state = setup(nil, false)
    equal(addon.frame, nil, "display before ADDON_LOADED")
    state:fire("ADDON_LOADED", "AnotherAddOn")
    equal(env.CarGOUIDB, nil, "unrelated ADDON_LOADED must not initialize DB")
    truthy(not addon.initialized, "unrelated AddOn initialized CarGOUI")
    state:fire("ADDON_LOADED", "CarGOUI")
    truthy(not addon.initialized, "normal login waits for player identity before migration")
    equal(env.CarGOUIDB, nil, "DB is not migrated before identity is ready")
    state:fire("PLAYER_LOGIN")
    truthy(addon.initialized, "login initializes")
    equal(addon.db, env.CarGOUIDB, "saved variables reference")
    equal(addon.db.schemaVersion, 5, "schema version migrated")
    truthy(not addon.frame or not addon.frame:IsShown(), "no fabricated reminder display")
    equal(env.SLASH_CARGOUI1, "/cui", "primary slash")
    equal(env.SLASH_CARGOUI2, "/cargoui", "compatibility slash")
    equal(type(env.SlashCmdList.CARGOUI), "function", "slash callback")
    truthy(addon.enabled, "enabled after login")
    truthy(not addon.frame or not addon.frame:IsShown(), "no obsolete live placeholder at login")
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
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
    savedPosition(addon, env, 125, -75)
    savedFont(addon, 32, "THICKOUTLINE")
    equal(addon:GetMobilityConfig().style.scale, 1.25, "saved scale")
    equal(addon.db.futureOption.value, 42, "unrelated key preserved")
    local env2, addon2 = login(copy(env.CarGOUIDB))
    savedPosition(addon2, env2, 125, -75)
    savedFont(addon2, 32, "THICKOUTLINE")
    same(addon2.db, addon.db, "reload persistence")
end)

test("late loading initializes without showing fabricated reminder content", function()
    local _, addon, state = login(nil, true)
    truthy(addon.initialized and addon.enabled, "late-loaded startup")
    truthy(not addon.frame or not addon.frame:IsShown(), "no obsolete live placeholder")
    equal(addon.optionsFrame, nil, "late load defers Options")
    equal(state.realReads, 0, "startup never queries live reminder state")
end)

test("malformed SavedVariables and non-finite numbers recover safely", function()
    for _, malformed in ipairs({ false, 17, "invalid" }) do
        local _, addon = login(malformed)
        equal(addon:GetMobilityConfig().style.font.size, 24, "invalid root reset")
    end
    local env, addon = login({ schemaVersion = "invalid", enabled = "yes",
        position = { x = math.huge, y = 0 / 0 },
        font = { face = false, size = -10, outline = "INVALID" },
        scale = math.huge, shadow = { enabled = "yes" }, other = "preserve me" })
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(addon:GetMobilityConfig().enabled, true, "invalid enabled setting")
    equal(addon:GetMobilityConfig().style.scale, 1, "invalid scale")
    equal(addon:GetMobilityConfig().style.shadow.enabled, true, "invalid shadow")
    equal(addon.db.other, "preserve me", "unrelated setting")
    local _, addon2 = login({ position = true, font = "bad", shadow = 9, scale = -1 })
    equal(addon2:GetMobilityConfig().position.x, 0, "malformed position")
    equal(addon2:GetMobilityConfig().style.font.size, 24, "malformed font")
    equal(addon2:GetMobilityConfig().style.shadow.enabled, true, "malformed shadow")
    local env3, addon3 = login({ position = { x = 10001, y = -10001 },
        font = { size = 73 }, scale = 3.01 })
    savedPosition(addon3, env3, 0, 0)
    savedFont(addon3, 24, "OUTLINE")
    equal(addon3:GetMobilityConfig().style.scale, 1, "finite out-of-range scale")
end)

test("slash commands retain positions visibility and reset but cannot edit global appearance", function()
    local env, addon, state = login(nil)
    local command = env.SlashCmdList.CARGOUI
    command("help"); command("status"); command("position 35 -60")
    savedPosition(addon, env, 35, -60)
    local appearance = copy(addon:GetMobilityConfig().style)
    for _, legacy in ipairs({ "fontsize 30", "outline none", "outline thickoutline", "scale 1.2", "shadow off" }) do
        command(legacy)
        same(addon:GetMobilityConfig().style, appearance, "legacy global style command cannot modify reminder styles")
    end
    command("hide"); equal(addon:GetMobilityConfig().enabled, false, "hidden state saved")
    command("show"); equal(addon:GetMobilityConfig().enabled, true, "shown state saved")
    local prior = copy(addon.db)
    for _, invalid in ipairs({ "position nope 10", "position 10", "position 1e309 1",
        "position 10001 0", "position 0 -10001", "show extra", "reset extra", "unknowncommand" }) do
        command(invalid)
        same(addon.db, prior, "invalid commands do not mutate settings")
    end
    command("reset")
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(#state.errors, 0, "command errors")
end)

test("saved hidden state remains hidden on reload", function()
    local env, addon = login(nil)
    env.SlashCmdList.CARGOUI("hide")
    local _, reloaded = login(copy(addon.db))
    equal(reloaded:GetMobilityConfig().enabled, false, "hidden preference persisted")
    truthy(not reloaded.frame or not reloaded.frame:IsShown(), "reload shows no live placeholder")
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
    local row = editBox.slider and editBox or editBox.numericRow
    if row then
        if not row.editing then row.valueButton:Click() end
        editBox = row.editBox
    end
    editBox:SetText(tostring(value))
    local textChanged = editBox:GetScript("OnTextChanged")
    if textChanged then textChanged(editBox, true) end
    return editBox
end

local function enter(editBox, value)
    editBox = typeText(editBox, value)
    local callback = editBox:GetScript("OnEnterPressed")
    truthy(callback, "edit box has an Enter handler")
    callback(editBox)
end

local function dragValue(row, value)
    local slider = row.slider
    slider:GetScript("OnMouseDown")(slider, "LeftButton")
    slider:SetValue(value)
    slider:GetScript("OnValueChanged")(slider, value, true)
    slider:GetScript("OnMouseUp")(slider, "LeftButton")
end

local function choose(dropdown, value)
    dropdown:Click()
    truthy(dropdown.menu and dropdown.menu:IsShown(), "dropdown menu opens")
    for _, option in ipairs(dropdown.choices) do
        if option.value == value then
            option:Click()
            if dropdown.menu.cuiState == "closing" then
                equal(dropdown.menu.cuiInteractive, false, "outgoing menu cannot accept another action")
                equal(option:IsEnabled(), false, "outgoing rows are disabled during the close animation")
                dropdown.menu.closeAnimation:GetScript("OnFinished")()
            end
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
    local db, position, fontSettings, shadow = addon.db, addon:GetMobilityConfig().position, addon:GetMobilityConfig().style.font, addon:GetMobilityConfig().style.shadow
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
    truthy(addon:UpdateSettings({ position = { x = 40 } }),
        "valid partial patch accepted")
    equal(addon.db, db, "DB reference stable")
    equal(env.CarGOUIDB, db, "SavedVariables references live DB")
    equal(addon:GetMobilityConfig().position, position, "position reference stable")
    equal(addon:GetMobilityConfig().style.font, fontSettings, "font reference stable")
    equal(addon:GetMobilityConfig().style.shadow, shadow, "shadow reference stable")
    savedPosition(addon, env, 40, 0)
    savedFont(addon, 24, "OUTLINE")
end)

test("daily automatic-context Appearance controls use shared validation and survive reload", function()
    local env, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    local writes = 0
    local update = addon.UpdateSettings
    addon.UpdateSettings = function(self, patch)
        if patch.styles then
            truthy(patch.styles["mobility:MAGE"], "current class style is the target")
            for key in pairs(patch.styles) do equal(key, "mobility:MAGE", "only selected style is patched") end
            writes = writes + 1
        end
        return update(self, patch)
    end
    local function changed(callback, label)
        local before = writes
        callback()
        truthy(writes > before, label .. " uses shared context validation")
    end
    typeText(controls.mobilityX, "165"); enter(controls.mobilityY, "-85")
    savedPosition(addon, env, 165, -85)
    controls.mobilityEnabled:Click(); equal(addon:GetMobilityConfig().enabled, false, "checkbox hides reminders")
    controls.mobilityEnabled:Click()
    addon:OpenAppearance("mobility", "mobility:MAGE")
    changed(function() dragValue(controls.appearanceScale, 1.35) end, "scale slider")
    equal(addon:GetMobilityConfig().style.scale, 1.35, "scale slider saves immediately")
    changed(function() enter(controls.appearanceScale.editBox, "1.6") end, "scale Enter")
    changed(function() dragValue(controls.appearanceFontSize, 36) end, "font slider")
    changed(function() enter(controls.appearanceFontSize.editBox, "32") end, "font Enter")
    changed(function() choose(controls.appearanceOutline, "THICKOUTLINE") end, "outline")
    savedFont(addon, 32, "THICKOUTLINE")
    changed(function() choose(controls.appearanceFont, controls.appearanceFont.choices[1].value) end, "font")
    changed(function() controls.appearanceShadow:Click() end, "shadow")
    equal(addon:GetMobilityConfig().style.shadow.enabled, false, "shadow saved")
    equal(addon:GetProcConfig(63).style.font.size, 24, "Proc style untouched")
    controls.close:Click()
    local _, reloaded = login(copy(env.CarGOUIDB))
    same(reloaded.db, addon.db, "GUI settings persist across reload")
    equal(#state.errors, 0, "GUI interactions produce no errors")
end)

test("numeric XY drafts commit their own axis and are discarded at close boundaries", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    typeText(controls.mobilityX, "250")
    savedPosition(addon, env, 0, 0)
    typeText(controls.mobilityY, "not a number")
    savedPosition(addon, env, 250, 0)
    local before = copy(addon.db)
    enter(controls.mobilityY, "not a number")
    same(addon.db, before, "invalid axis never changes either coordinate")
    truthy(type(panel.feedback:GetText()) == "string" and #panel.feedback:GetText() > 0,
        "invalid input has visible feedback")
    controls.mobilityEnabled:Click()
    equal(controls.mobilityX.editBox:GetText(), "250", "committed X remains separate")
    equal(controls.mobilityY.editBox:GetText(), "not a number", "unrelated update preserves pending Y")
    enter(controls.mobilityY, "-125")
    savedPosition(addon, env, 250, -125)
    typeText(controls.mobilityX, "900")
    controls.mobilityX.editBox:SetFocus()
    controls.close:Click()
    equal(controls.mobilityX.editBox:HasFocus(), false, "close clears keyboard focus")
    addon:ToggleOptions()
    equal(tonumber(controls.mobilityX.editBox:GetText()), 250, "reopen discards unapplied X")
    equal(tonumber(controls.mobilityY.editBox:GetText()), -125, "reopen restores saved Y")
    controls.mobilityReset:Click()
    savedPosition(addon, env, 0, 0)
    equal(tonumber(controls.mobilityX.editBox:GetText()), 0, "center updates X field")
    equal(tonumber(controls.mobilityY.editBox:GetText()), 0, "center updates Y field")
end)

test("invalid numeric edits show errors without changing saved values", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    for _, field in ipairs({ controls.appearanceFontSize.editBox, controls.appearanceScale.editBox }) do
        for _, text in ipairs({ "", "invalid", "1e309", "-100" }) do
            local before = copy(addon.db)
            enter(field, text)
            same(addon.db, before, "invalid numeric edit leaves settings unchanged")
            truthy(panel.feedback:GetText() and #panel.feedback:GetText() > 0,
                "numeric validation feedback is visible")
        end
    end
end)

test("categories expose Appearance and usable Import Export while removed Themes routes safely to General", function()
    local _, addon = login(nil)
    local panel = options(addon)
    local found = {}
    for _, category in ipairs(panel.categories) do found[category.key] = category end
    equal(found.typography, nil, "global typography category is removed")
    equal(found.themes, nil, "Themes category is removed rather than disabled")
    equal(panel.pages.themes, nil, "Themes page is not allocated")
    for _, key in ipairs({ "general", "mobility", "proc", "importExport" }) do
        truthy(found[key] and found[key]:IsEnabled(), key .. " enabled")
        found[key]:Click()
        truthy(panel.pages[key]:IsShown(), key .. " page active")
        for other, page in pairs(panel.pages) do
            if other ~= key then equal(page:IsShown(), false, "other page hidden") end
        end
    end
    addon:SelectOptionsCategory("themes")
    equal(panel.activeCategory, "general", "old Themes path has safe explicit General fallback")
    truthy(panel.pages.general:IsShown(), "old category request cannot show a blank window")
    truthy(found.importExport:IsEnabled(), "existing import/export entry is active")
end)

test("dropdown lifecycle and hidden refresh remain idle", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    controls.appearanceOutline:Click()
    truthy(controls.appearanceOutline.menu:IsShown(), "dropdown open")
    addon:SelectOptionsCategory("general")
    equal(controls.appearanceOutline.menu:IsShown(), false, "category change dismisses dropdown")
    addon:OpenAppearance("mobility", "mobility:MAGE")
    controls.appearanceOutline:Click()
    panel:Hide()
    equal(controls.appearanceOutline.menu:IsShown(), false, "closing window dismisses menu")
    local fontWrites, textWrites = state.fontWrites, state.textWrites
    for _ = 1, 5 do addon:RefreshOptions() end
    equal(state.fontWrites, fontWrites, "hidden refresh does not redraw")
    equal(state.textWrites, textWrites, "hidden refresh does not update control text")
    local savedScale = addon:GetMobilityConfig().style.scale
    dragValue(controls.appearanceScale, 2.25)
    equal(addon:GetMobilityConfig().style.scale, savedScale, "hidden slider cannot update settings")
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
    addon:UpdateSettings({ position = { x = 90, y = 45 } })
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 36 }, scale = 1.7 })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    local before = copy(addon.db)
    controls.reset:Click()
    same(addon.db, before, "first reset click does not mutate settings")
    controls.close:Click()
    addon:ToggleOptions()
    controls.reset:Click()
    same(addon.db, before, "closing cancels old reset confirmation")
    typeText(controls.mobilityX, "999")
    controls.reset:Click()
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(addon:GetMobilityConfig().style.scale, 1, "confirmed reset restores scale")
    equal(tonumber(controls.mobilityX.editBox:GetText()), 0, "reset clears pending X")
    equal(tonumber(controls.mobilityY.editBox:GetText()), 0, "reset refreshes Y")
    truthy(panel:IsShown(), "reset keeps Options open")
end)

test("Escape cancels inline numeric editing without closing Options", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    for _, row in ipairs({ controls.mobilityX, controls.mobilityY, controls.appearanceFontSize, controls.appearanceScale }) do
        if row == controls.mobilityX or row == controls.mobilityY then addon:SelectOptionsCategory("mobility")
        else addon:OpenAppearance("mobility") end
        local before = copy(addon.db)
        local editBox = typeText(row, "-999")
        local escape = editBox:GetScript("OnEscapePressed")
        truthy(escape, "editable field has Escape handler")
        escape(editBox)
        equal(panel:IsShown(), true, "inline Escape stays on the current page")
        equal(editBox:HasFocus(), false, "Escape releases keyboard focus")
        same(addon.db, before, "Escape discards draft")
    end
end)

test("sliders round safely while exact inputs preserve precision and valid blur commits", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    equal(controls.applyPosition, nil, "no XY Apply button")
    equal(controls.appearanceScale.applyButton, nil, "no scale Apply button")
    equal(controls.appearanceFontSize.applyButton, nil, "no font-size Apply button")
    for _, frame in ipairs(state.frames) do
        if frame.kind == "Button" then
            truthy(frame:GetText() ~= "Apply", "Options contains no normal-setting Apply buttons")
        end
    end
    for _, value in ipairs({ 0.5, 0.5000001, 1.049999999, 2.999999999, 3 }) do
        dragValue(controls.appearanceScale, value)
        truthy(addon:IsNumberInRange(addon:GetMobilityConfig().style.scale, addon.limits.scale), "rounded scale stays valid")
        truthy(math.abs(addon:GetMobilityConfig().style.scale * 100 - math.floor(addon:GetMobilityConfig().style.scale * 100 + 0.5)) < 0.00001,
            "slider produces 0.01 increments")
    end
    enter(controls.appearanceScale.editBox, "1.2375")
    equal(addon:GetMobilityConfig().style.scale, 1.2375, "typed scale keeps precision")
    enter(controls.appearanceFontSize.editBox, "31.5")
    equal(addon:GetMobilityConfig().style.font.size, 31.5, "typed font size keeps precision")
    typeText(controls.appearanceScale.editBox, "2.8")
    equal(addon:GetMobilityConfig().style.scale, 1.2375, "text remains a draft while editing")
    typeText(controls.appearanceFontSize.editBox, "70")
    controls.appearanceFontSize.editBox:ClearFocus()
    equal(addon:GetMobilityConfig().style.scale, 2.8, "switching inline editors commits a valid focused value")
    equal(addon:GetMobilityConfig().style.font.size, 70, "valid blur commits font")
    typeText(controls.appearanceFontSize.editBox, "65")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.appearanceScale.editBox:GetText()), 2.8, "reopen retains committed scale")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 70, "closing cancels the remaining draft")
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

test("zhCN clients use automatic localization and retain saved appearance on reload", function()
    local saved
    for pass = 1, 2 do
        local env, addon = login(saved, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
        equal(env.GetLocale(), "zhCN", "regression runs on Chinese client")
        if pass == 2 then
            equal(addon:GetMobilityConfig().position.x, 37, "saved position survives reload")
            equal(addon:GetMobilityConfig().style.font.size, 32, "saved appearance survives reload")
        end
        env.SlashCmdList.CARGOUI("")
        local panel, controls = addon.optionsFrame, addon.optionsFrame.controls
        local categories = {}
        for _, category in ipairs(panel.categories) do categories[category.key] = category end
        equal(categories.general:GetText(), addon.L.general, "active category follows locale")
        truthy(categories.general.selected, "selection is an owned visual state, not an ASCII prefix")
        equal(categories.mobility:GetText(), addon.L.mobility, "Mobility category follows locale")
        equal(controls.close:GetText(), "关闭", "close button uses Simplified Chinese")
        truthy(panel.feedback:GetText():find("Enter", 1, true), "opening guidance teaches Enter")
        truthy(not panel.feedback:GetText():find("Apply", 1, true), "obsolete Apply instruction gone")
        addon:SelectOptionsCategory("mobility")
        enter(controls.mobilityX, "invalid")
        truthy(panel.feedback:GetText():find("X", 1, true), "coordinate error is readable")
        enter(controls.mobilityX, "37")
        equal(panel.feedback:GetText(), pass == 1 and addon.L.saved or addon.L.immediate,
            "changed input reports saved; an unchanged correction restores neutral localized guidance")
        addon:OpenAppearance("mobility", "mobility:MAGE")
        equal(controls.appearanceOutline.choices[1]:GetText(), addon.L.none, "dropdown choice follows locale")
        enter(controls.appearanceFontSize.editBox, "32")
        controls.reset:Click()
        equal(controls.reset:GetText(), addon.L.confirmReset, "reset confirmation follows locale")
        controls.close:Click()
        saved = copy(addon.db)
    end
end)

test("font menu applies each supported face and localized client font persists", function()
    local _, addon = login(nil, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility:MAGE")
    local foundFriz, foundClient = false, false
    for _, entry in ipairs(controls.appearanceFont.choices) do
        choose(controls.appearanceFont, entry.value)
        equal(addon:GetMobilityConfig().style.font.face, entry.value, "font dropdown writes chosen face")
        if entry.value == "Fonts\\FRIZQT__.ttf" then foundFriz = true end
        if entry.value == "Fonts\\ARKai_T.ttf" then foundClient = true end
    end
    equal(foundFriz, false, "locale-incompatible Roman font is not offered as a distinct usable face")
    truthy(foundClient, "localized client font selectable")
    local chosen = addon:GetMobilityConfig().style.font.face
    local _, reloaded = login(copy(addon.db), false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    equal(reloaded:GetMobilityConfig().style.font.face, chosen, "supported saved font survives reload")
    local ok = addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "fonts\\frizqt__.TTF" } })
    truthy(ok, "supported font accepted case-insensitively")
    equal(addon:GetMobilityConfig().style.font.face, "Fonts\\FRIZQT__.ttf", "font path canonicalized")
    equal(panel:IsShown(), true, "Options created successfully with a localized client font")
end)


test("Options backgrounds drag the same window while interactive controls keep their own input", function()
    local env, addon, state = login(nil)
    addon:UpdateSettings({ position = { x = 37, y = -19 } })
    local panel, controls = options(addon)
    truthy(panel.movable and panel.clampedToScreen, "Options movable and clamped")
    local header = panel.header
    truthy(header and header.parent == panel, "original title drag region retained")
    same(header.dragButtons, { "LeftButton" }, "header accepts only left drag")
    truthy(panel.optionsDragSurface, "window background is a drag surface")
    truthy(panel.appearanceScroll.optionsDragSurface, "Appearance scroll background is a drag surface")
    truthy(panel.appearanceScroll.scrollChild.optionsDragSurface, "Appearance editor empty area is a drag surface")
    for _, page in pairs(panel.pages) do truthy(page.optionsDragSurface, "every existing page background is draggable") end
    addon:ShowMobilityDiagnostics()
    truthy(panel.diagnosticsFrame.optionsDragSurface, "diagnostic dialog empty background can drag Options")
    equal(panel.diagnosticsFrame.editBox:GetScript("OnDragStart"), nil, "diagnostic selection field owns text input")
    local dragSurfaces = 0
    for _, frame in ipairs(state.frames) do
        if frame.optionsDragSurface then
            dragSurfaces = dragSurfaces + 1
            truthy(frame.kind == "Frame" or frame.kind == "ScrollFrame", "only backgrounds receive drag hooks")
            same(frame.dragButtons, { "LeftButton" }, "background accepts only left drag")
            truthy(frame:GetScript("OnDragStart") and frame:GetScript("OnDragStop") and frame:GetScript("OnMouseUp"), "background has release safety")
            local oldStart = frame:GetScript("OnDragStart")
            addon:RegisterOptionsDragSurface(frame)
            equal(frame:GetScript("OnDragStart"), oldStart, "re-registering does not stack hooks")
        elseif frame.name ~= "LibDBIcon10_CarGOUI" then
            equal(frame:GetScript("OnDragStart"), nil, "buttons inputs menus sliders and reminder frames never start window drag")
        else
            equal(frame.optionsDragSurface, nil, "vendor icon drag is never an Options drag surface")
        end
    end
    truthy(dragSurfaces >= 10, "existing empty surfaces covered without extra overlay frame")
    panel.diagnosticsFrame.close:Click()
    panel:GetScript("OnDragStart")(panel, "RightButton")
    equal(state.movingFrame, nil, "right mouse never drags window")
    header:GetScript("OnDragStart")(header, "LeftButton")
    equal(state.movingFrame, panel, "header starts moving Options")
    panel.mockCenter = { (960 + 120) / panel:GetScale(), (540 - 80) / panel:GetScale() }
    header:GetScript("OnDragStop")(header)
    equal(panel.moving, false, "release stops moving")
    equal(addon.db.options.position.x, 120, "window X saved independently")
    equal(addon.db.options.position.y, -80, "window Y saved independently")
    savedPosition(addon, env, 37, -19)
    panel:GetScript("OnDragStart")(panel, "LeftButton")
    panel.mockCenter = { (960 + 120) / panel:GetScale(), (540 - 80) / panel:GetScale() }
    panel:GetScript("OnMouseUp")(panel, "LeftButton")
    equal(panel.moving, false, "mouse-up on background also stops movement")
    panel.mockCenter = nil
    local saved = copy(addon.db)
    panel:Hide()
    addon:ToggleOptions()
    local x, y = panel:GetCenter()
    equal(x * panel:GetScale(), 1080, "reopen restores X")
    equal(y * panel:GetScale(), 460, "reopen restores Y")
    local _, reload = login(saved)
    local reloaded = options(reload)
    local rx, ry = reloaded:GetCenter()
    equal(rx * reloaded:GetScale(), 1080, "reload restores X")
    equal(ry * reloaded:GetScale(), 460, "reload restores Y")
    controls.centerOptions:Click()
    equal(addon.db.options.position.x, 0, "center-window button resets only Options X")
    equal(addon.db.options.position.y, 0, "center-window button resets only Options Y")
    savedPosition(addon, env, 37, -19)
    header:GetScript("OnDragStart")(header, "LeftButton")
    panel.mockCenter = { 960 - 45, 540 + 30 }
    panel:Hide()
    equal(panel.moving, false, "closing during drag releases movement")
    equal(addon.db.options.position.x, -45, "closing during drag saves final window X")
    equal(addon.db.options.position.y, 30, "closing during drag saves final window Y")
end)

test("title animation defaults on, has a static fallback, and stops when hidden", function()
    local _, addon, state = login(nil)
    for _, group in ipairs(state.animations) do
        equal(group.parent:GetName(), "LibDBIcon10_CarGOUI", "only the vendor's dormant fade exists before Options")
        equal(group:IsPlaying(), false, "the optional icon fade does not start at login")
    end
    local panel, controls = options(addon)
    local group = panel.titleAnimation
    truthy(group and #group.animations > 0, "native animation group created")
    equal(addon.db.options.animatedTitle, true, "animated title defaults on")
    truthy(group:IsPlaying(), "visible Options plays title animation")
    truthy(panel.brandingHeader:IsShown(), "designed title is visible")
    for _, animation in ipairs(group.animations) do
        truthy(animation.kind == "Alpha" or animation.kind == "Translation" or animation.kind == "Scale",
            "decoration uses native animation types")
        truthy(animation.duration and animation.duration > 0, "native animation has duration")
    end
    local count = #state.animations
    controls.animatedTitle:Click()
    equal(addon.db.options.animatedTitle, false, "toggle saved")
    equal(group:IsPlaying(), false, "disabled title animation stops")
    truthy(panel.brandingHeader:IsShown(), "disabled animation keeps static title art")
    controls.animatedTitle:Click()
    truthy(group:IsPlaying(), "enabled title animation resumes")
    panel:Hide()
    equal(group:IsPlaying(), false, "closing Options stops native animation")
    addon:RefreshTitleAnimation()
    equal(group:IsPlaying(), false, "hidden refresh cannot restart title animation")
    addon:ToggleOptions()
    equal(panel.titleAnimation, group, "reopen reuses native animation")
    equal(#state.animations, count, "reopen does not allocate animation groups")
    truthy(group:IsPlaying(), "reopen resumes enabled animation")
    controls.animatedTitle:Click()
    local _, reloaded = login(copy(addon.db))
    local reloadPanel = options(reloaded)
    equal(reloadPanel.titleAnimation:IsPlaying(), false, "disabled preference survives reload")
end)

test("new Options settings validate atomically and migrate malformed saved data", function()
    local _, addon = login({ schemaVersion = 1, options = { position = { x = math.huge, y = "bad" },
        animatedTitle = "yes" }, position = { x = 15, y = -25 }, futureOption = true })
    equal(addon.db.options.position.x, 0, "bad window X normalized")
    equal(addon.db.options.position.y, 0, "bad window Y normalized")
    equal(addon.db.options.animatedTitle, true, "bad title toggle normalized")
    equal(addon:GetMobilityConfig().position.x, 15, "migration preserves reminder X")
    equal(addon:GetMobilityConfig().position.y, -25, "migration preserves reminder Y")
    truthy(addon.db.futureOption, "migration preserves unknown keys")
    local before = copy(addon.db)
    for _, patch in ipairs({
        { options = false }, { options = { animatedTitle = 1 } },
        { options = { position = { x = 1, y = 0/0 } }, scale = 2 },
        { options = { position = { x = math.huge } } }, { options = { unsupported = true } },
    }) do
        local ok, message = addon:UpdateSettings(patch)
        equal(ok, false, "invalid Options patch rejected")
        truthy(type(message) == "string", "validation message returned")
        same(addon.db, before, "invalid Options patch has no partial effects")
    end
end)


local function visiblePreviews(addon)
    local result = {}
    for id, frame in pairs(addon.previewFrames or {}) do
        if frame:IsShown() then result[id] = frame end
    end
    return result
end

local function countKeys(value)
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function reminderAnchor(frame, entry, addon, env)
    local point, relative, relativePoint, x, y = frame:GetPoint()
    equal(point, "CENTER", "reminder anchor")
    equal(relative, env.UIParent, "preview renders in actual game UI space")
    equal(relativePoint, "CENTER", "reminder relative anchor")
    local position = addon:GetReminderPosition(entry)
    local expectedX = entry.anchor.x + position.x
    local expectedY = entry.anchor.y + position.y
    truthy(math.abs(x * frame:GetScale() - expectedX) < 0.001, "rendered reminder X matches visual region and offsets")
    truthy(math.abs(y * frame:GetScale() - expectedY) < 0.001, "rendered reminder Y matches visual region and offsets")
end

test("preview catalog separates Mage specs and gives each Proc region its own anchor", function()
    local _, addon, state = login(nil)
    local seen = {}
    for _, entry in ipairs(addon.previewEntries) do
        truthy(not seen[entry.id], "preview IDs unique")
        seen[entry.id] = true
        truthy(type(entry.label) == "string" and type(entry.region) == "string", "entry explains reminder region")
        truthy(addon:GetReminderPosition(entry), "active entry has scoped position")
        if entry.kind == "proc" then
            truthy(entry.anchor.x ~= 0 or entry.anchor.y ~= 0, "Proc timers do not use global screen center")
        end
    end
    for specID, expected in pairs({ [62] = 7, [63] = 9, [64] = 5 }) do
        state.specID = specID
        local entries = addon:GetPreviewEntries()
        equal(#entries, expected, "defined entries for current Mage spec")
        local regions = {}
        for _, entry in ipairs(entries) do
            if entry.freeMove then
                equal(entry.class, "MAGE", "Free move uses current class scope across every spec")
                equal(entry.specID, nil, "Free move is not duplicated by specialization")
            else equal(entry.specID, specID, "no cross-spec reminder entry") end
            if entry.kind == "proc" then
                local key = entry.anchor.x .. ":" .. entry.anchor.y
                truthy(not regions[key], "separate Proc regions have separate centers")
                regions[key] = true
            end
        end
    end
    state.classToken = "WARRIOR"
    local warriorPreviews = addon:GetPreviewEntries()
    equal(#warriorPreviews, 1, "unlearned Warrior has only its confirmed Free move preview")
    truthy(warriorPreviews[1].freeMove and warriorPreviews[1].class == "WARRIOR", "no foreign Mage Proc or fake ordinary skill")
    equal(state.realReads, 0, "catalog does not query real aura/cooldown state")
end)

test("external single/all preview renders fixed samples and cleans up on stop and close", function()
    local env, addon, state = login()
    equal(countKeys(visiblePreviews(addon)), 0, "no samples at login")
    local panel, controls = options(addon)
    equal(panel.previewFrame, nil, "obsolete static in-panel preview removed")
    addon:SelectOptionsCategory("general")
    local entries = addon:GetPreviewEntries()
    addon:GetProcConfig() -- materialize current-spec configuration before comparing preview-only writes
    local saved = copy(addon.db)
    truthy(addon:SetPreview("single", entries[1].id))
    equal(addon.previewState.mode, "single", "single preview mode")
    equal(addon.previewState.entryId, entries[1].id, "selected sample remembered for session")
    equal(countKeys(visiblePreviews(addon)), 1, "single mode shows one defined entry")
    controls.generalTest:Click()
    equal(addon.previewState.mode, "all", "all mode selected")
    equal(countKeys(visiblePreviews(addon)), #entries, "all current-spec entries visible")
    local frames = {}
    for _, entry in ipairs(entries) do
        local frame = addon.previewFrames[entry.id]
        frames[entry.id] = frame
        equal(frame:GetParent(), env.UIParent, "external frame parent is UIParent")
        equal(frame.mouseEnabled, false, "reminder cannot intercept mouse input")
        equal(frame:GetScript("OnDragStart"), nil, "reminder anchors are never draggable")
        reminderAnchor(frame, entry, addon, env)
        truthy(frame.guidance and frame.guidance:IsShown(), "test mode explains target visual region")
        truthy(frame.guidance:GetFrameLevel() < frame:GetFrameLevel(), "test guidance stays behind readable timer text")
        if entry.freeMove then
            equal(frame.text:GetText(), "Free move", "Free move preview is text only with no synthetic time")
        elseif entry.kind == "mobility" then
            truthy(frame.text:GetText():find("No Shimmer", 1, true), "Mobility uses sample label")
            truthy(frame.text:GetText():find("8.0", 1, true), "Mobility uses fixed sample time")
        else
            truthy(frame.text:GetText():match("^%d+%.%d+$"), "Proc timer has only numeric sample text")
        end
    end
    same(addon.db, saved, "sample content never pollutes saved reminder settings")
    controls.generalStop:Click()
    equal(addon.previewState.mode, "off", "Stop returns to off")
    equal(countKeys(visiblePreviews(addon)), 0, "Stop hides all simulated reminders")
    for _, frame in pairs(frames) do equal(frame.guidance:IsVisible(), false, "Stop hides region guidance") end
    controls.generalTest:Click()
    for id, frame in pairs(frames) do equal(addon.previewFrames[id], frame, "preview frames reused") end
    controls.close:Click()
    equal(countKeys(visiblePreviews(addon)), 0, "closing window removes external preview")
    equal(addon.previewState.mode, "off", "closing resets transient preview mode")
    for _, frame in ipairs(state.frames) do
        equal(frame:GetScript("OnUpdate"), nil, "preview never polls per frame")
    end
    addon:ToggleOptions()
    equal(countKeys(visiblePreviews(addon)), 0, "reopening does not silently re-enable samples")
    equal(state.realReads, 0, "simulated content never reads live buffs or cooldowns")
end)

test("external preview shares current Proc spec appearance but preserves each stock region center", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("general")
    local entries = addon:GetPreviewEntries()
    local selected = entries[2]
    controls.generalTest:Click()
    addon:SelectOptionsCategory("proc")
    choose(controls.procEntry, selected.id)
    typeText(controls.procPositionX, "34"); typeText(controls.procPositionY, "invalid")
    local prior = copy(addon.db)
    enter(controls.procPositionX, "34")
    same(addon.db, prior, "invalid offset pair is atomic")
    enter(controls.procPositionY, "-17")
    addon:SelectOptionsCategory("mobility")
    enter(controls.mobilityX, "25"); enter(controls.mobilityY, "-50")
    addon:OpenAppearance("proc", selected.id)
    enter(controls.appearanceScale.editBox, "1.5")
    enter(controls.appearanceFontSize.editBox, "40")
    choose(controls.appearanceOutline, "THICKOUTLINE")
    choose(controls.appearanceFont, "Fonts\\MORPHEUS.TTF")
    controls.appearanceShadow:Click()
    equal(countKeys(visiblePreviews(addon)), #entries, "all preview remains active during entry edits")
    for _, entry in ipairs(entries) do
        local frame = addon.previewFrames[entry.id]
        reminderAnchor(frame, entry, addon, env)
        if entry.kind == "proc" then
            same(frame.text.font, { "Fonts\\MORPHEUS.TTF", 40, "THICKOUTLINE" }, "selected appearance applied")
            equal(frame:GetScale(), 1.5, "selected scale applied")
            same(frame.text.shadowOffset, { 0, 0 }, "selected shadow off")
        else
            same(frame.text.font, { "Fonts\\FRIZQT__.ttf", 24, "OUTLINE" }, "other region font untouched")
            equal(frame:GetScale(), 1, "other scale untouched")
            same(frame.text.shadowOffset, { 1, -1 }, "other shadow untouched")
        end
        if entry.kind == "proc" then
            local guide = frame.guidance
            local _, relative, _, x, y = guide:GetPoint()
            equal(relative, env.UIParent, "guide remains in stock UI space")
            local factor = guide:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
            equal(factor, 1, "guide never inherits reminder scale")
            equal(x, entry.anchor.x, "guide X fixed")
            equal(y, entry.anchor.y, "guide Y fixed")
        end
    end
    local reloadEnv, reloaded = login(copy(addon.db))
    options(reloaded); reloaded:SetPreview("single", selected.id)
    reminderAnchor(reloaded.previewFrames[selected.id], selected, reloaded, reloadEnv)
    same(reloaded:GetProcConfig(63).style, addon:GetProcConfig(63).style, "spec style survives reload")
    addon:SelectOptionsCategory("proc"); controls.procPositionReset:Click()
    same(addon:GetReminderPosition(selected), { anchor = "CENTER", x = 0, y = 0 }, "position reset only resets current coordinates")
    equal(addon:GetProcConfig(63).style.font.size, 40, "coordinate reset preserves spec appearance")
end)

test("specialization changes clear obsolete previews and unsupported classes disable preview controls", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("general")
    controls.generalTest:Click()
    state.specID = 64
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(countKeys(visiblePreviews(addon)), 0, "spec switch stops obsolete simulated content")
    controls.generalTest:Click()
    equal(countKeys(visiblePreviews(addon)), 5, "new Preview includes current Frost regions plus class-level Free move")
    for id in pairs(visiblePreviews(addon)) do truthy(id:find("mage_frost_", 1, true) or id == "free_move_mage", "old spec samples hidden") end
    state.classToken = "UNKNOWN"
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(countKeys(visiblePreviews(addon)), 0, "unsupported class removes stale samples")
    equal(controls.mobilityPreview:IsEnabled(), false, "unsupported contextual Mobility action disabled")
    equal(controls.generalTest:IsEnabled(), false, "unsupported all-preview action disabled")
    truthy(panel.generalTestStatus:GetText() and #panel.generalTestStatus:GetText() > 0, "unsupported state explained")
    equal(state.realReads, 0, "specialization change does not read real reminder state")
end)

test("preview validation, visibility and shared renderer keep sample state separate", function()
    local _, addon, state = login(nil)
    local entries = addon:GetPreviewEntries()
    local entry = entries[2]
    equal(addon:SetPreview("single", entry.id), false, "cannot start preview with closed Options")
    equal(countKeys(visiblePreviews(addon)), 0, "closed request allocates no visible samples")
    options(addon)
    equal(addon:SetPreview("invalid", entry.id), false, "unknown mode rejected")
    equal(addon:SetPreview("single", "missing-entry"), false, "unknown entry rejected")
    truthy(addon:SetPreview("all"), "all preview started")
    addon:UpdateSettings({ enabled = false })
    local procCount = 0
    for _, candidate in ipairs(entries) do if candidate.kind == "proc" then procCount = procCount + 1 end end
    equal(countKeys(visiblePreviews(addon)), procCount, "Mobility disable hides ordinary and Free move while preserving Proc samples")
    local mobilityFrame = addon.previewFrames[entries[1].id]
    truthy(not mobilityFrame:IsShown() and not mobilityFrame.guidance:IsVisible(), "disabled Mobility hides its own sample and guide")
    addon:UpdateSettings({ enabled = true })
    equal(countKeys(visiblePreviews(addon)), #entries, "re-enabling restores requested test mode")
    local preview = addon.previewFrames[entry.id]
    local liveFrame = addon:AcquireReminderFrame(entry, "live")
    truthy(liveFrame ~= preview, "live and preview frames never share a pool entry")
    local callerContent = { timer = "6.0" }
    addon:RenderReminder(liveFrame, entry, callerContent, false)
    equal(liveFrame.text:GetText(), "6.0", "shared Proc renderer displays timer only")
    truthy(not liveFrame.guidance or not liveFrame.guidance:IsShown(), "normal renderer has no Test Mode decorations")
    same(callerContent, { timer = "6.0" }, "rendering leaves caller state untouched")
    addon:StopPreview()
    equal(liveFrame.text:GetText(), "6.0", "stopping samples does not replace caller reminder content")
    truthy(liveFrame:IsShown(), "stopping preview leaves a separate caller-owned frame alone")
    equal(state.realReads, 0, "renderer never reads live combat state")
end)


local function descendantOf(object, ancestor)
    while object do
        if object == ancestor then return true end
        object = object.parent
    end
    return false
end

local function resourceCounts(state)
    local animationCount = 0
    for _, group in ipairs(state.animations) do animationCount = animationCount + #group.animations end
    return { frames = #state.frames, textures = #state.textures, lines = #state.lines, masks = #state.masks,
        fontStrings = #state.fontStrings, groups = #state.animations, animations = animationCount }
end

local function brandAsset(texture)
    truthy(texture and (texture.kind == "Texture" or texture.kind == "MaskTexture"), "branding uses a texture asset")
    local path = texture:GetTexture()
    local prefix = "Interface\\AddOns\\CarGOUI\\"
    truthy(type(path) == "string" and path:sub(1, #prefix) == prefix, "branding uses an in-package asset")
    local relative = path:sub(#prefix + 1):gsub("\\", "/")
    truthy(relative:match("^Media/Branding/.+%.tga$"), "runtime branding uses a packaged TGA")
    local file = assert(io.open(root .. "/" .. relative, "rb"), "Missing game-loadable branding asset: " .. relative)
    local data = file:read("*a")
    file:close()
    truthy(#data >= 18, "TGA has a complete header")
    local imageType, bits, descriptor = data:byte(3), data:byte(17), data:byte(18)
    truthy(imageType == 2 or imageType == 10, "runtime TGA uses true-color pixels")
    equal(bits, 32, "runtime TGA has RGBA pixels")
    equal(descriptor % 16, 8, "runtime TGA declares its alpha channel")
    local width = data:byte(13) + data:byte(14) * 256
    local height = data:byte(15) + data:byte(16) * 256
    truthy(width > 0 and height > 0, "runtime TGA has valid dimensions")
    return { path = path, width = width, height = height, bytes = #data }
end

local function combatSubscriptions(state, expected)
    -- Options and live Mobility now also own combat callbacks on the shared
    -- event frame. Check branding's ownership without requiring those owners
    -- to unregister their still-needed callbacks.
    equal(not not state.addon.optionsFrame.brandingCombatEvents, expected > 0,
        "branding combat listener ownership")
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        local count = 0
        for _, frame in ipairs(state.frames) do
            if frame:IsEventRegistered(event) then count = count + 1 end
        end
        if expected > 0 then equal(count, 1, event .. " shared frame subscription") end
    end
end

test("branding uses aligned packaged artwork and a narrow native glyph-masked sweep", function()
    local _, addon, state = login(nil)
    local panel = options(addon)
    local header = panel.brandingHeader
    equal(header.wordmark.kind, "Texture", "brand name is artwork, not a FontString")
    equal(header.emblem.kind, "Texture", "emblem is actual artwork")
    local wordmark = brandAsset(header.wordmark)
    local emblem = brandAsset(header.emblem)
    local mask = brandAsset(header.mask)
    local sweep = brandAsset(header.sweep)
    truthy(wordmark.width <= 512 and wordmark.height <= 128, "wordmark source stays compact")
    equal(emblem.width, 128, "compact emblem texture width")
    equal(emblem.height, 128, "compact emblem texture height")
    equal(mask.width, wordmark.width, "glyph mask width aligns with wordmark")
    equal(mask.height, wordmark.height, "glyph mask height aligns with wordmark")
    equal(header.animationMode, "masked-sweep", "native glyph masking path selected")
    equal(header.mask.kind, "MaskTexture", "sweep has a real glyph mask")
    truthy(header.sweep.masks and header.sweep.masks[1] == header.mask, "mask attached to moving light")
    equal(header.mask:GetParent(), header, "glyph mask belongs to stationary header")
    truthy(header.mask.allPoints == header.wordmark
        or (header.mask.point and header.mask.point[2] == header.wordmark), "glyph mask follows stationary artwork geometry")
    local ratio = header.sweep:GetWidth() / header.wordmark:GetWidth()
    truthy(ratio >= 0.15 and ratio <= 0.20, "moving highlight is 15-20 percent of wordmark width")
    local uv = header.wordmark.texCoord or { 0, 1, 0, 1 }
    local contentRatio = wordmark.width * math.abs(uv[2] - uv[1]) / (wordmark.height * math.abs(uv[4] - uv[3]))
    truthy(math.abs(header.wordmark:GetWidth() / header.wordmark:GetHeight() - contentRatio) < 0.01,
        "wordmark layout preserves cropped artwork aspect ratio")
    equal(header.wordmark:GetAlpha(), 1, "base wordmark stays opaque")
    local textures, masks, groups, uniqueAssets = 0, 0, 0, {}
    for _, texture in ipairs(state.textures) do
        if descendantOf(texture, header) then
            textures = textures + 1
            if type(texture:GetTexture()) == "string" then
                local asset = brandAsset(texture)
                uniqueAssets[asset.path] = asset.bytes
            end
        end
    end
    for _, texture in ipairs(state.masks) do
        if descendantOf(texture, header) then masks = masks + 1; local asset = brandAsset(texture); uniqueAssets[asset.path] = asset.bytes end
    end
    local duration, translations = 0, 0
    for _, group in ipairs(state.animations) do
        if descendantOf(group.parent, header) then
            groups = groups + 1
            equal(group.parent, header.sweep, "only highlight layer moves or changes alpha")
            equal(group.looping, "REPEAT", "native sweep loop")
            local orders = {}
            for _, animation in ipairs(group.animations) do
                truthy(animation.kind == "Translation" or animation.kind == "Alpha", "no rotating/scaling/bouncing brand text")
                local span = (animation.startDelay or 0) + animation.duration + (animation.endDelay or 0)
                orders[animation.order or 1] = math.max(orders[animation.order or 1] or 0, span)
                if animation.kind == "Translation" then
                    translations = translations + 1
                    truthy(math.abs(animation.duration - 1.5) < 0.01, "light travels for about 1.5 seconds")
                    truthy(animation.offset[1] > 0 and animation.offset[2] == 0, "light moves left to right")
                else
                    truthy(animation.fromAlpha >= 0 and animation.toAlpha >= 0, "valid alpha endpoints")
                    truthy(animation.fromAlpha <= 0.25 and animation.toAlpha <= 0.25, "highlight peak remains subtle")
                end
            end
            for _, span in pairs(orders) do duration = duration + span end
        end
    end
    equal(translations, 1, "one native translation drives the sweep")
    truthy(math.abs(duration - 6.5) < 0.01, "sweep includes five seconds of native idle time")
    truthy(textures <= 6 + 1 + 8, "branding plus one static theme background and eight motif strokes stay bounded")
    equal(masks, 1, "one separately counted glyph mask")
    truthy(groups <= 2, "branding stays within animation group budget")
    local bytes = 0
    for _, size in pairs(uniqueAssets) do bytes = bytes + size end
    truthy(bytes <= 1024 * 1024, "referenced runtime branding assets fit initial 1 MiB budget")
end)

test("twenty Options reopen cycles reuse every branding object and stop motion immediately", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    local header, group = panel.brandingHeader, panel.titleAnimation
    local objects = resourceCounts(state)
    for _ = 1, 20 do
        panel:Hide()
        equal(group:IsPlaying(), false, "closing explicitly stops native sweep")
        equal(header.wordmark:GetAlpha(), 1, "closed wordmark retains readable base alpha")
        equal(header.sweep:GetAlpha(), 0, "closing clears any residual highlight alpha")
        combatSubscriptions(state, 0)
        addon:ToggleOptions()
        equal(panel.brandingHeader, header, "same header reused")
        equal(panel.titleAnimation, group, "same native animation group reused")
        truthy(group:IsPlaying(), "reopening resumes enabled title")
        same(resourceCounts(state), objects, "reopening allocates no duplicate branding resources")
    end
    local art, emblem = header.wordmark:GetTexture(), header.emblem:GetTexture()
    controls.animatedTitle:Click()
    equal(group:IsPlaying(), false, "toggle stops immediately")
    equal(header.wordmark:GetTexture(), art, "disabled mode uses same artwork")
    equal(header.emblem:GetTexture(), emblem, "disabled mode uses same emblem")
    equal(header.wordmark:GetAlpha(), 1, "disabled title remains fully readable")
    equal(header.sweep:GetAlpha(), 0, "disabled mode clears highlight residue")
    combatSubscriptions(state, 0)
end)

test("combat closes Options and branding resumes only on a later explicit visible open", function()
    local env, addon, state = login(nil)
    local panel, controls = options(addon)
    local group, header = panel.titleAnimation, panel.brandingHeader
    combatSubscriptions(state, 1)
    state:fire("PLAYER_REGEN_DISABLED")
    equal(group:IsPlaying(), false, "entering combat stops sweep immediately")
    equal(header.wordmark:GetAlpha(), 1, "combat leaves base wordmark opaque")
    equal(header.sweep:GetAlpha(), 0, "combat clears highlight residue")
    combatSubscriptions(state, 0)
    state:fire("PLAYER_REGEN_ENABLED")
    equal(panel:IsShown(), false, "automatic combat hide alone does not request reopening")
    equal(group:IsPlaying(), false, "combat ending with Options closed never restarts animation")
    addon:ToggleOptions()
    truthy(group:IsPlaying(), "explicit out-of-combat open resumes eligible title")
    controls.animatedTitle:Click()
    state:fire("PLAYER_REGEN_DISABLED")
    state:fire("PLAYER_REGEN_ENABLED")
    equal(group:IsPlaying(), false, "disabled preference prevents combat-end restart")
    addon:ToggleOptions()
    controls.animatedTitle:Click()
    truthy(group:IsPlaying(), "re-enabling while visible resumes")
    state:fire("PLAYER_REGEN_DISABLED")
    panel:Hide()
    combatSubscriptions(state, 0)
    state:fire("PLAYER_REGEN_ENABLED")
    equal(group:IsPlaying(), false, "combat ending with window closed never restarts motion")
    addon:ToggleOptions()
    env.UIParent.IsVisible = function() return false end
    addon:RefreshTitleAnimation()
    equal(group:IsPlaying(), false, "ancestor invisibility prevents playing a shown child")
    env.UIParent.IsVisible = function() return true end
    addon:RefreshTitleAnimation()
    truthy(group:IsPlaying(), "visible ancestor permits resumption")
    local _, inCombatAddon, combatState = login(nil, false, { inCombat = true })
    inCombatAddon:ToggleOptions()
    equal(inCombatAddon.optionsFrame, nil, "first combat request does not create branding or Options")
    combatState:fire("PLAYER_REGEN_ENABLED")
    truthy(inCombatAddon.optionsFrame.titleAnimation:IsPlaying(), "queued first opening starts branding only after combat")
end)

test("branding callbacks stay isolated and ordinary settings do not resize or restart the art", function()
    local _, addon, state = login(nil)
    local panel = options(addon)
    local header, group = panel.brandingHeader, panel.titleAnimation
    local base = { width = header.wordmark:GetWidth(), height = header.wordmark:GetHeight(),
        point = { unpack(header.wordmark.point or {}) }, uv = copy(header.wordmark.texCoord),
        scale = header.wordmark:GetScale(), alpha = header.wordmark:GetAlpha() }
    local initialPlays, initialStops = group.plays, group.stops
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 72, outline = "THICKOUTLINE" }, scale = 3 })
    addon:OpenAppearance("mobility", "mobility:MAGE")
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("general")
    panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
    panel.mockCenter = { 1000, 550 }
    panel.header:GetScript("OnDragStop")(panel.header)
    panel.mockCenter = nil
    equal(group.plays, initialPlays, "settings, categories and dragging do not restart playing sweep")
    equal(group.stops, initialStops + 1, "page changes settle the active UI sweep once")
    equal(group:IsPlaying(), false, "page navigation cannot leave old UI motion active")
    equal(header.wordmark:GetWidth(), base.width, "reminder font/scale do not change brand width")
    equal(header.wordmark:GetHeight(), base.height, "reminder font/scale do not change brand height")
    equal(header.wordmark:GetScale(), base.scale, "reminder scale does not change brand scale")
    equal(header.wordmark:GetAlpha(), base.alpha, "base wordmark alpha stays stable")
    for index = 1, 5 do equal(header.wordmark.point[index], base.point[index], "base wordmark position stays stable") end
    same(header.wordmark.texCoord, base.uv, "base wordmark UV coordinates stay stable")
    local refreshOptions, refreshPreview, renderReminder = addon.RefreshOptions, addon.RefreshPreview, addon.RenderReminder
    local panelRefreshes, previewRefreshes, renders = 0, 0, 0
    addon.RefreshOptions = function(self, ...) panelRefreshes = panelRefreshes + 1; return refreshOptions(self, ...) end
    addon.RefreshPreview = function(self, ...) previewRefreshes = previewRefreshes + 1; return refreshPreview(self, ...) end
    addon.RenderReminder = function(self, ...) renders = renders + 1; return renderReminder(self, ...) end
    local fontWrites = state.fontWrites
    local brandText = {}
    for _, fontString in ipairs(state.fontStrings) do
        if descendantOf(fontString, header) then brandText[fontString] = fontString:GetText() end
    end
    for _, event in ipairs({ "OnLoop", "OnFinished" }) do
        if group:GetScript(event) then group:GetScript(event)(group) end
    end
    state:fire("PLAYER_REGEN_DISABLED")
    state:fire("PLAYER_REGEN_ENABLED")
    equal(panelRefreshes, 0, "animation/combat callbacks never rebuild Options")
    equal(previewRefreshes, 0, "animation/combat callbacks never refresh simulated reminders")
    equal(renders, 0, "animation/combat callbacks never render reminder content")
    equal(state.fontWrites, fontWrites, "branding callbacks never recreate fonts")
    for fontString, text in pairs(brandText) do
        equal(fontString:GetText(), text, "branding callbacks never rewrite title text")
    end
    equal(state.realReads, 0, "decorative combat handling never reads skill or aura state")
end)

test("missing glyph-mask support falls back to aligned artwork rather than an unmasked rectangle", function()
    local _, addon, state = login(nil, false, { maskUnavailable = true })
    local panel, controls = options(addon)
    local header, group = panel.brandingHeader, panel.titleAnimation
    equal(header.animationMode, "glyph-pulse-fallback", "fallback mode is explicit")
    equal(header.wordmark.kind, "Texture", "fallback retains actual brand artwork")
    equal(#state.masks, 0, "unsupported mask API is not called")
    truthy(group:IsPlaying(), "fallback can animate native glyph highlight")
    equal(header.sweep:GetWidth(), header.wordmark:GetWidth(), "fallback highlight aligns with wordmark width")
    equal(header.sweep:GetHeight(), header.wordmark:GetHeight(), "fallback highlight aligns with wordmark height")
    for _, animation in ipairs(group.animations) do
        equal(animation.kind, "Alpha", "fallback never translates an unmasked rectangle")
    end
    local baseAsset = header.wordmark:GetTexture()
    controls.animatedTitle:Click()
    equal(group:IsPlaying(), false, "fallback stops immediately when disabled")
    equal(header.wordmark:GetTexture(), baseAsset, "fallback disabled art remains identical")
    equal(header.wordmark:GetAlpha(), 1, "fallback disabled base is never translucent")
    equal(header.sweep:GetAlpha(), 0, "fallback clears highlight residue")
end)


test("branding theme accents preserve artwork identity and never mutate reminder settings", function()
    local _, addon, state = login(nil)
    truthy(addon:UpdateBrandingTheme({ 0.2, 0.6, 0.9 }), "theme accent can be set before header allocation")
    equal(addon.optionsFrame, nil, "theme entry does not eagerly allocate Options")
    local panel = options(addon)
    local header, group = panel.brandingHeader, panel.titleAnimation
    local saved, art, emblem = copy(addon.db), header.wordmark:GetTexture(), header.emblem:GetTexture()
    local wordmarkColor, emblemColor = copy(header.wordmark.vertexColor), copy(header.emblem.vertexColor)
    local resources, plays = resourceCounts(state), group.plays
    local automaticAccent = copy(header.sweep.vertexColor)
    truthy(automaticAccent, "automatic theme supplies brand highlight")
    same(header.accentLine.vertexColor, { 1, 1, 1 }, "product gradient stays independent of faction tint")
    for _, color in ipairs({ false, "bad", {}, { 0.1, 0.2 }, { 0.1, 2, 0.3 }, { 0/0, 0.2, 0.3 } }) do
        equal(addon:UpdateBrandingTheme(color), false, "invalid theme accent rejected")
        same(header.sweep.vertexColor, automaticAccent, "invalid accent leaves previous color intact")
    end
    truthy(addon:UpdateBrandingTheme({ 0.8, 0.7, 0.4 }), "valid theme accent accepted")
    same(header.sweep.vertexColor, { 0.8, 0.7, 0.4 }, "highlight accent updates")
    same(header.accentLine.vertexColor, { 1, 1, 1 }, "faction changes preserve the cyan-violet strip")
    same(header.wordmark.vertexColor, wordmarkColor, "base wordmark colors remain authored")
    same(header.emblem.vertexColor, emblemColor, "emblem colors remain authored")
    equal(header.wordmark:GetTexture(), art, "theme retains brand artwork")
    equal(header.emblem:GetTexture(), emblem, "theme retains emblem artwork")
    equal(group.plays, plays, "theme changes do not restart sweep")
    same(resourceCounts(state), resources, "theme changes allocate no new objects")
    same(addon.db, saved, "branding accent never modifies reminder settings")
end)

local function mobilityLogin(spellID, data, client, saved)
    client = client or {}
    local enterCombat = client.inCombat
    client.inCombat = false
    client.mobility = { known = { [1953] = true, [212653] = spellID == 212653 },
        override = spellID, spells = { [spellID] = data } }
    local env, addon, state = login(saved, false, client)
    if enterCombat then
        state:fire("PLAYER_REGEN_DISABLED")
        state:flushTimers(); state:nativeTick()
    end
    return env, addon, state
end

local function currentLive(addon)
    local entry = addon:GetMobilityEntry()
    return entry and addon.reminderFrames.live and addon.reminderFrames.live[entry.id]
end

local function nativeText(addon)
    local frame = currentLive(addon)
    -- Test-only native render observation; addon code must never read this back.
    if not frame or not frame:IsVisible() or nativeValue(frame.alpha) == 0 then return "" end
    return frame.text.nativeRenderedText or ""
end

local function mobilityStatus(addon, expected)
    equal(addon:GetMobilityStatus().status, expected, "public Mobility status")
end

local function syncEvent(state, event, ...)
    state:fire(event, ...)
    state:flushTimers()
    state:nativeTick()
    equal(#state.errors, 0, "event sync errors")
end

test("live Shimmer 2 to 1 stays hidden, 1 to 0 shows next recharge, and 0 to 1 hides", function()
    local data = { charges = 2, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    mobilityStatus(addon, "Ready")
    equal(nativeText(addon), "", "two charges stay hidden with Options closed")
    equal(addon.optionsFrame, nil, "live runtime does not create Options")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    mobilityStatus(addon, "Ready")
    equal(nativeText(addon), "", "one available charge stays hidden while another is recharging")
    state:advance(7)
    data.charges = 0
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    mobilityStatus(addon, "Depleted")
    equal(nativeText(addon), "No Shimmer\n13.0", "last use retains the recharge already in progress")
    state:advance(1.5)
    equal(nativeText(addon), "No Shimmer\n11.5", "native clock updates genuine remaining duration")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    mobilityStatus(addon, "Ready")
    equal(nativeText(addon), "", "one restored charge hides immediately before full recharge")
    equal(currentLive(addon).durationBinding.enabled, false, "ready stops native text updates")
    equal(currentLive(addon).durationBinding.duration, nil, "ready detaches opaque duration")
    equal(addon.previewState.mode, "off", "real reminder never starts simulation")
end)

test("native Blink cooldown ignores GCD and unrelated unusability", function()
    local data = { cooldownStart = 100, cooldownDuration = 1.5, isOnGCD = true }
    local env, addon, state = mobilityLogin(1953, data)
    env.C_Spell.IsSpellUsable = function() error("Usability is not depletion") end
    mobilityStatus(addon, "Ready")
    equal(nativeText(addon), "", "GCD-only never renders a reminder")
    data.isOnGCD, data.cooldownDuration = false, 15
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(nativeText(addon), "No Blink\n15.0", "non-charge spell own cooldown is native")
    state:advance(4)
    equal(nativeText(addon), "No Blink\n11.0", "non-charge timer advances")
    data.cooldownStart, data.cooldownDuration = 0, 0
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    mobilityStatus(addon, "Ready")
    equal(nativeText(addon), "", "spell ready hides independently of mana/silence/range")
end)

test("single-charge and larger charge capacities use current client values", function()
    for _, maximum in ipairs({ 1, 3 }) do
        local data = { charges = maximum, maxCharges = maximum, chargeStart = 100, chargeDuration = 12 }
        local _, addon, state = mobilityLogin(1953, data)
        equal(nativeText(addon), "", "any positive capacity starts ready")
        data.charges = 0
        syncEvent(state, "SPELL_UPDATE_CHARGES")
        equal(nativeText(addon), "No Blink\n12.0", "zero of actual capacity renders")
        data.charges = 1
        syncEvent(state, "SPELL_UPDATE_CHARGES")
        equal(nativeText(addon), "", "one restored charge hides for every capacity")
    end
end)

test("learn and unlearn Shimmer resolves one actual spell without resetting saved positions", function()
    local blink = { cooldownStart = 100, cooldownDuration = 15 }
    local _, addon, state = mobilityLogin(1953, blink)
    local id = addon:GetMobilityEntry().id
    addon:UpdateSettings({ reminders = { [id] = { position = { x = 87, y = -21 } } } })
    local frame = currentLive(addon)
    equal(nativeText(addon), "No Blink\n15.0", "known Blink is monitored")
    state.mobility.known[212653] = true
    state.mobility.override = 212653
    state.mobility.spells[212653] = { charges = 0, maxCharges = 2, chargeStart = 98, chargeDuration = 20 }
    syncEvent(state, "SPELLS_CHANGED")
    equal(addon:GetMobilityStatus().spellID, 212653, "learned effective Shimmer replaces Blink")
    equal(nativeText(addon), "No Shimmer\n18.0", "replacement uses its own real duration")
    equal(currentLive(addon), frame, "mutually exclusive skills reuse one configured region")
    equal(addon:GetMobilityEntry().id, id, "replacement preserves compatibility ID")
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 87, y = -21 }, "replacement preserves configured position")
    local before = #state.spellReads
    addon:RefreshMobility()
    for index = before + 1, #state.spellReads do
        equal(state.spellReads[index].id, 212653, "only active Shimmer cooldown is read")
    end
    state.mobility.known[212653], state.mobility.override = false, 1953
    syncEvent(state, "PLAYER_TALENT_UPDATE")
    equal(addon:GetMobilityStatus().spellID, 1953, "removing Shimmer restores learned Blink")
    equal(currentLive(addon), frame, "return to Blink reuses frame")
end)

test("all Mage specs and unspecialized low-level Mage retain independent compatibility IDs", function()
    local data = { charges = 0, maxCharges = 1, chargeStart = 100, chargeDuration = 11 }
    local _, addon, state = mobilityLogin(1953, data, { specID = false })
    equal(addon:GetMobilityEntry().id, "mage_unspecialized_mobility", "no-spec Mage gets additive default ID")
    equal(nativeText(addon), "No Blink\n11.0", "no specialization is required for learned Blink")
    local expected = { [62] = "mage_arcane_shimmer", [63] = "mage_fire_shimmer", [64] = "mage_frost_shimmer" }
    for _, spec in ipairs({ 62, 63, 64 }) do
        state.specID = spec
        syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        equal(addon:GetMobilityEntry().id, expected[spec], "old specialization position ID retained")
        equal(nativeText(addon), "No Blink\n11.0", "current spell does not depend on preview catalog name")
        local shown = 0
        for _, frame in pairs(addon.reminderFrames.live) do if frame:IsShown() then shown = shown + 1 end end
        equal(shown, 1, "specialization switch leaves only one live frame visible")
    end
    local reads = state.realReads
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
    equal(state:activeTimers(), 0, "unrelated unit does not schedule own-spec sync")
    equal(state.realReads, reads, "unrelated spec event does not query spell APIs")
end)

test("inconsistent replacement states fail closed and active Preview follows confirmed spell changes", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 })
    state.mobility.spells[1953] = { cooldownStart = 100, cooldownDuration = 15 }
    local panel = options(addon)
    local entry = addon:GetMobilityEntry()
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 54, y = -23 } } } })
    addon:SetPreview("single", entry.id)
    local sample = addon.previewFrames[entry.id]
    equal(sample.text:GetText(), "No Shimmer\n8.0", "sample starts with confirmed Shimmer")
    state.mobility.known[212653], state.mobility.override = false, 1953
    syncEvent(state, "PLAYER_TALENT_UPDATE")
    equal(sample.text:GetText(), "No Blink\n8.0", "active sample updates after effective skill changes")
    truthy(sample.guidance.label:GetText():find("Blink", 1, true), "TEST guidance uses new skill name")
    equal(nativeText(addon), "", "replacement live remains suppressed by matching preview")
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 54, y = -23 }, "active replacement preserves region settings")
    state.mobility.known[212653], state.mobility.override = true, 1953
    syncEvent(state, "SPELLS_CHANGED")
    mobilityStatus(addon, "Unknown")
    equal(nativeText(addon), "", "inconsistent learned Shimmer plus effective Blink is not guessed")
    state.mobility.override = 999999
    syncEvent(state, "SPELLS_CHANGED")
    mobilityStatus(addon, "Unsupported")
    equal(nativeText(addon), "", "unsupported replacement is not read as a supported spell")
    state.mobility.override = 212653
    syncEvent(state, "TRAIT_CONFIG_UPDATED", 1)
    equal(sample.text:GetText(), "No Shimmer\n8.0", "confirmed return updates active preview again")
    addon:StopPreview()
    equal(nativeText(addon), "No Shimmer\n20.0", "confirmed live state resumes after preview")
    equal(#state.errors, 0, "replacement transition never raises an error")
end)

test("unlearned and unsupported characters do not manufacture live reminders", function()
    local env, addon, state = mobilityLogin(1953, { cooldownStart = 100, cooldownDuration = 15 })
    state.mobility.known[1953] = false
    syncEvent(state, "SPELLS_CHANGED")
    mobilityStatus(addon, "Not learned")
    equal(nativeText(addon), "", "spell data existence is not evidence of learning")
    local reads = state.realReads
    addon:RefreshMobility()
    equal(state.realReads, reads, "unlearned spell does not query cooldowns")
    local _, other, unsupported = mobilityLogin(1953, { cooldownDuration = 15 }, { classToken = "UNKNOWN" })
    mobilityStatus(other, "Unsupported")
    equal(unsupported.realReads, 0, "unsupported class never queries Mage state")
    equal(unsupported:activeTimers(), 0, "unsupported class schedules no updates")
    equal(other.mobilityTracking, false, "unsupported class runtime is inactive")
    env.C_SpellBook.IsSpellKnown = function() return secret(true) end
    addon:RefreshMobility()
    mobilityStatus(addon, "Restricted")
    equal(nativeText(addon), "", "secret learning state is not branched on")
end)

test("world entry reload resurrection and reset resynchronize current real API snapshots", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 92, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    equal(nativeText(addon), "No Shimmer\n12.0", "login restores an already-running cooldown")
    local _, reload, reloadedState = mobilityLogin(212653, copy(data), nil, copy(addon.db))
    equal(nativeText(reload), "No Shimmer\n12.0", "reload does not restart the timer")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }) do
        data.charges = 1
        syncEvent(state, event, true, false)
        equal(nativeText(addon), "", "restored availability wins during " .. event)
        data.charges, data.chargeStart = 0, 95
        syncEvent(state, event, false, false)
        equal(nativeText(addon), "No Shimmer\n15.0", "current state restored during " .. event)
    end
    data.charges = 2
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "early reset hides without waiting for old native expiry")
    equal(#reloadedState.errors, 0, "reloaded native display has no mock errors")
end)

test("Preview suppresses matching live output while background synchronization continues", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    local panel, controls = options(addon)
    local entry = addon:GetMobilityEntry()
    truthy(addon:SetPreview("single", entry.id), "matching external preview starts")
    equal(nativeText(addon), "", "matching live reminder is suppressed")
    equal(currentLive(addon).durationBinding.enabled, false, "suppression stops native binding updates")
    local sample = addon.previewFrames[entry.id]
    equal(sample.text:GetText(), "No Shimmer\n8.0", "sample remains explicitly fixed and separate")
    truthy(sample.guidance.label:GetText():find("TEST", 1, true), "sample label clearly marks TEST")
    local reads = state.realReads
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    truthy(state.realReads > reads, "preview never stops live state synchronization")
    mobilityStatus(addon, "Ready")
    equal(sample.text:GetText(), "No Shimmer\n8.0", "live transition never changes sample content")
    data.charges, data.chargeStart = 0, 95
    addon:StopPreview()
    equal(nativeText(addon), "No Shimmer\n15.0", "stop queries current state rather than restoring a stale snapshot")
    truthy(addon:SetPreview("all"), "all-preview starts")
    equal(nativeText(addon), "", "all-preview suppresses matching live output")
    controls.close:Click()
    equal(addon.previewState.mode, "off", "closing Options stops only simulation")
    equal(nativeText(addon), "No Shimmer\n15.0", "closing Options restores independent live reminder")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "closed Options still reacts to recovery")
end)

test("combat ends simulated previews blocks restart and preserves real Mobility", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    local panel, controls = options(addon)
    truthy(addon:SetPreview("all"), "out-of-combat sample can start")
    syncEvent(state, "PLAYER_REGEN_DISABLED")
    equal(addon.previewState.mode, "off", "combat stops Test Mode")
    equal(countKeys(visiblePreviews(addon)), 0, "combat hides every TEST sample")
    equal(nativeText(addon), "No Shimmer\n20.0", "real timer remains available in combat")
    equal(panel.titleAnimation:IsPlaying(), false, "existing combat-static branding remains")
    local ok, message = addon:SetPreview("all")
    equal(ok, false, "combat rejects restarting samples")
    truthy(message:find("combat", 1, true), "blocked preview explains combat restriction")
    equal(panel:IsShown(), false, "combat closes the panel instead of leaving interactive Preview controls visible")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "combat charge recovery hides normally")
    syncEvent(state, "PLAYER_REGEN_ENABLED")
    equal(addon.previewState.mode, "off", "leaving combat never silently restarts samples")
    equal(panel:IsShown(), false, "ending combat alone does not reopen Options")
    equal(panel.titleAnimation:IsPlaying(), false, "hidden title does not resume")
end)

test("live and preview share saved layout and style without resetting schema-2 coordinates", function()
    local saved = { schemaVersion = 2, position = { x = 30, y = -15 }, scale = 1.25,
        font = { face = "Fonts\\FRIZQT__.ttf", size = 31, outline = "THICKOUTLINE" },
        options = { position = { x = 119, y = -38 }, animatedTitle = false },
        reminders = { mage_arcane_shimmer = { position = { x = 11, y = 12 } },
            mage_fire_shimmer = { position = { x = 21, y = 22 } },
            mage_frost_shimmer = { position = { x = 31, y = 32 } },
            mage_fire_hot_streak_left = { position = { x = 77, y = -18 } } } }
    local old = copy(saved)
    local env, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }, nil, saved)
    equal(addon.db, saved, "migration retains SavedVariables identity")
    equal(addon.db.schemaVersion, 5, "additive schema upgrade")
    for id, record in pairs(old.reminders) do same(addon.db.migrations.scope5.source.reminders[id], record, "legacy region backed up " .. id) end
    same(addon.db.options.position, old.options.position, "window position remains saved")
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 51, y = 7 }, "global and current Fire offsets combined once")
    local live, entry = currentLive(addon), addon:GetMobilityEntry()
    reminderAnchor(live, entry, addon, env)
    same(live.text.font, { "Fonts\\FRIZQT__.ttf", 31, "THICKOUTLINE" }, "live typography uses shared setting")
    local point, scale = copy(live.point), live:GetScale()
    local panel = options(addon)
    addon:SetPreview("single", entry.id)
    local preview = addon.previewFrames[entry.id]
    same(preview.point, point, "preview and live use same fixed saved anchor")
    equal(preview:GetScale(), scale, "preview and live use same scale")
    same(preview.text.font, live.text.font, "preview and live share typography")
    addon:StopPreview()
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 38 }, scale = 1.5 })
    same(live.text.font, { "Fonts\\FRIZQT__.ttf", 38, "THICKOUTLINE" }, "live font changes apply immediately")
    reminderAnchor(live, entry, addon, env)
    equal(state.liveMeasurements, 0, "live text geometry is never measured")
end)

test("Mobility Options edits apply on Enter and expose working preview and copyable diagnostics", function()
    local _, addon, state = mobilityLogin(1953, { cooldownStart = 100, cooldownDuration = 15 })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("mobility")
    truthy(panel.pages.mobility:IsShown(), "Mobility is a working category")
    equal(controls.mobilityEnabled:GetChecked(), true, "Mobility defaults enabled")
    truthy(panel.mobilitySpell:GetText():find("Blink", 1, true), "detected current spell displayed read-only")
    local id = addon:GetMobilityEntry().id
    typeText(controls.mobilityX, "45.5")
    equal(addon:GetMobilityConfig().position.x, 0, "position text remains a draft")
    typeText(controls.mobilityY, "-72")
    equal(addon:GetMobilityConfig().position.x, 45.5, "valid blur commits X before editing Y")
    controls.mobilityY.editBox:GetScript("OnEnterPressed")(controls.mobilityY.editBox)
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 45.5, y = -72 }, "Enter commits the current Y axis")
    controls.mobilityTypography:Click()
    truthy(panel.pages.appearance:IsShown(), "Typography shortcut works")
    addon:SelectOptionsCategory("mobility")
    controls.mobilityPreview:Click()
    equal(addon.previewState.entryId, id, "corresponding skill preview starts")
    controls.mobilityStop:Click()
    equal(nativeText(addon), "No Blink\n15.0", "Stop Preview resumes live")
    controls.mobilityDiagnostics:Click()
    truthy(panel.diagnosticsFrame and panel.diagnosticsFrame:IsShown(), "diagnostic copy window opens")
    controls.mobilityEnabled:Click()
    mobilityStatus(addon, "Disabled")
    equal(nativeText(addon), "", "module checkbox immediately hides live")
    controls.mobilityEnabled:Click()
    equal(nativeText(addon), "No Blink\n15.0", "reenabling queries current state")
    panel:Hide()
    equal(panel.diagnosticsFrame:IsShown(), false, "closing Options hides diagnostic popup")
    equal(#state.errors, 0, "Mobility controls produce no mock errors")
end)

test("Mobility pending edits survive live refresh and diagnostic copying but invalid pairs stay atomic", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("mobility")
    local id = addon:GetMobilityEntry().id
    typeText(controls.mobilityX, "47")
    typeText(controls.mobilityY, "-65")
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(controls.mobilityX.editBox:GetText(), "47", "event refresh preserves pending X")
    equal(controls.mobilityY.editBox:GetText(), "-65", "event refresh preserves pending Y")
    controls.mobilityDiagnostics:Click()
    local dialog = panel.diagnosticsFrame
    equal(controls.mobilityX.editBox:GetText(), "47", "copy dialog preserves unsaved X")
    equal(controls.mobilityY.editBox:GetText(), "-65", "copy dialog preserves unsaved Y")
    local snapshot = dialog.editBox:GetText()
    typeText(dialog.editBox, "overwrite")
    equal(dialog.editBox:GetText(), snapshot, "diagnostic snapshot permits selection but refuses user editing")
    dialog.close:Click()
    controls.mobilityY.editBox:GetScript("OnEnterPressed")(controls.mobilityY)
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 47, y = -65 }, "Enter after copying commits original pending pair")
    typeText(controls.mobilityX, "invalid")
    typeText(controls.mobilityY, "19")
    controls.mobilityX.editBox:GetScript("OnEnterPressed")(controls.mobilityX)
    same(addon:GetMobilityConfig().position, { anchor = "CENTER", x = 47, y = -65 }, "invalid X does not partially commit Y")
    truthy(panel.feedback:GetText() ~= "", "invalid pair has visible feedback")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.mobilityX.editBox:GetText()), 47, "closing discards invalid pending X")
    equal(tonumber(controls.mobilityY.editBox:GetText()), -65, "closing discards pending Y")
    equal(#state.errors, 0, "copy and edit flow raises no errors")
end)

test("secret charges use native visibility while public zero still uses native secret timing", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 96, chargeDuration = 20,
        cooldownStart = 96, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local _, addon, state = mobilityLogin(212653, data)
    mobilityStatus(addon, "Native tracking")
    equal(nativeText(addon), "No Shimmer\n16.0", "native visibility accepts secret charge state")
    truthy(isSecret(currentLive(addon).alpha), "native curve result remains opaque through SetAlpha")
    data.secretCharges, data.secretDuration = false, true
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    mobilityStatus(addon, "Depleted")
    equal(nativeText(addon), "No Shimmer\n16.0", "ordinary zero count can gate native secret timer")
    local frame = currentLive(addon)
    truthy(isSecret(frame.text.textValue), "native rendering output is treated as opaque")
    state:advance(0.5)
    equal(nativeText(addon), "No Shimmer\n15.5", "secret duration advances only in native binding")
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 30 }, scale = 1.2 })
    equal(nativeText(addon), "No Shimmer\n15.5", "styling does not read secret text")
    equal(state.liveMeasurements, 0, "restricted text is never measured")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "public charge recovery ends restricted-duration display")
end)

test("opaque non-charge duration renders natively and blanks GCD or expiry without reading values", function()
    local data = { cooldownStart = 100, cooldownDuration = 15, secretDuration = true }
    local _, addon, state = mobilityLogin(1953, data)
    mobilityStatus(addon, "Tracking")
    equal(nativeText(addon), "No Blink\n15.0", "opaque cooldown is native display, not assumed Ready")
    state:advance(15)
    equal(nativeText(addon), "", "native expiration blanks full label and digits")
    data.isOnGCD, data.cooldownDuration, data.cooldownStart = true, 1.5, state.clock
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    mobilityStatus(addon, "Tracking")
    equal(nativeText(addon), "", "opaque GCD-only duration is natively blank")
    equal(state.liveMeasurements, 0, "opacity and zero state never leak through geometry")
end)

test("missing nil inconsistent and unsupported API paths never become fabricated Ready", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20, durationUnavailable = true }
    local env, addon, state = mobilityLogin(212653, data)
    mobilityStatus(addon, "Unknown")
    equal(nativeText(addon), "", "missing real duration hides instead of a sample")
    data.durationUnavailable, data.unavailable = false, true
    addon:RefreshMobility()
    mobilityStatus(addon, "Unknown")
    equal(nativeText(addon), "", "nil charge and cooldown records are unknown")
    data.unavailable, data.chargeDuration = false, 0
    addon:RefreshMobility()
    mobilityStatus(addon, "Unknown")
    equal(nativeText(addon), "", "zero charge count with no recharge is not Ready")
    data.chargeDuration = 20
    env.C_Spell.GetSpellChargeDuration = nil
    addon:RefreshMobility()
    mobilityStatus(addon, "Unsupported")
    local _, noNative = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }, { nativeBindingUnavailable = true })
    mobilityStatus(noNative, "Unsupported")
    equal(nativeText(noNative), "", "missing native rendering never falls back to fake numbers")
    equal(#state.errors, 0, "API error cases are handled without exceptions")
end)

test("diagnostics contain actual mock build and public state without secret serialization or persistence", function()
    local env, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20, secretDuration = true })
    local status = addon:GetMobilityStatus()
    equal(status.duration, nil, "public status excludes DurationObject")
    local diagnostic = addon:GetMobilityDiagnostics()
    truthy(diagnostic:find("build 99999", 1, true), "diagnostics use GetBuildInfo result")
    truthy(diagnostic:find("native charge duration", 1, true), "diagnostics identify selected path")
    truthy(diagnostic:find("212653", 1, true), "ordinary detected spell ID is safe to copy")
    truthy(diagnostic:find("restricted", 1, true), "restriction policy is explicit")
    local function publicSaved(value)
        truthy(not isSecret(value), "SavedVariables never contains secret tokens")
        if type(value) == "table" then
            equal(getmetatable(value), nil, "SavedVariables never contains opaque native objects")
            for key, child in pairs(value) do publicSaved(key); publicSaved(child) end
        end
    end
    publicSaved(env.CarGOUIDB)
    local before = copy(addon.db)
    state:advance(3)
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    same(addon.db, before, "live time and charge state are never saved")
    state.mobility.spells[212653].secretCharges = true
    addon:RefreshMobility()
    diagnostic = addon:GetMobilityDiagnostics()
    truthy(diagnostic:find("Native tracking", 1, true), "opaque native visibility is never claimed as known Ready or Depleted")
    equal(addon:GetMobilityStatus().visibility, nil, "public diagnostics exclude native visibility objects")
    equal(#state.errors, 0, "diagnostics never stringify secret tokens")
end)

test("event bursts coalesce cancel on disable and reuse objects across repeated depletion", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    local frame, binding = currentLive(addon), currentLive(addon).durationBinding
    local objects, formatters, bindings = resourceCounts(state), #state.formatters, #state.bindings
    local reads = state.realReads
    for _ = 1, 25 do state:fire("SPELL_UPDATE_CHARGES"); state:fire("SPELL_UPDATE_COOLDOWN") end
    equal(state:activeTimers(), 1, "burst has one pending update")
    equal(state.realReads, reads, "event handlers do not duplicate immediate API reads")
    state:flushTimers()
    truthy(state.realReads > reads, "merged update reads one fresh snapshot")
    equal(state:activeTimers(), 0, "merged update does not start a recurring timer")
    for _ = 1, 30 do
        data.charges = 1; syncEvent(state, "SPELL_UPDATE_CHARGES")
        data.charges = 0; syncEvent(state, "SPELL_UPDATE_CHARGES")
    end
    equal(currentLive(addon), frame, "depletion reuses frame")
    equal(currentLive(addon).durationBinding, binding, "depletion reuses binding")
    same(resourceCounts(state), objects, "depletion cycles allocate no UI objects")
    equal(#state.bindings, bindings, "depletion cycles allocate no bindings")
    equal(#state.formatters, formatters, "depletion cycles allocate no formatters")
    state:fire("SPELL_UPDATE_CHARGES")
    equal(state:activeTimers(), 1, "work pending before disable")
    addon:UpdateSettings({ mobility = { enabled = false } })
    equal(state:activeTimers(), 0, "disable cancels pending work")
    equal(binding.enabled, false, "disable stops native updates")
    equal(binding.duration, nil, "disable releases duration reference")
    reads = state.realReads
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(state.realReads, reads, "disabled module performs no cooldown reads")
    for _, object in ipairs(state.frames) do equal(object:GetScript("OnUpdate"), nil, "no per-frame scans") end
end)

test("module disable preserves shared Options and branding combat subscriptions", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 })
    local panel = options(addon)
    addon:UpdateSettings({ mobility = { enabled = false } })
    state:fire("PLAYER_REGEN_DISABLED")
    equal(panel.titleAnimation:IsPlaying(), false, "branding still gets combat-start callback")
    equal(panel:IsShown(), false, "Options still closes for combat with Mobility disabled")
    state:fire("PLAYER_REGEN_ENABLED")
    equal(panel:IsShown(), false, "disabled Mobility cannot change Options combat-close policy")
    equal(panel.titleAnimation:IsPlaying(), false, "hidden branding does not resume on combat end")
    panel:Hide()
    for _, frame in ipairs(state.frames) do
        equal(frame:IsEventRegistered("PLAYER_REGEN_DISABLED"), false, "all inactive owners clean combat-start listener")
        equal(frame:IsEventRegistered("SPELL_UPDATE_CHARGES"), false, "disabled Mobility cleans charge listener")
    end
    equal(state:activeTimers(), 0, "no inactive task remains")
end)

-- These tests model two separate native durations: an ongoing recharge supplies
-- the displayed time, while an ordinary cooldown supplies a native alpha curve.
-- Mock behavior verifies safe plumbing, not real-client Blink/Shimmer semantics.
test("depletion survives entering combat when charge count and timing become secret", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 96, chargeDuration = 20,
        cooldownStart = 96, cooldownDuration = 20 }
    local _, addon, state = mobilityLogin(212653, data)
    equal(nativeText(addon), "No Shimmer\n16.0", "public out-of-combat depletion is visible")
    local frame, binding = currentLive(addon), currentLive(addon).durationBinding
    local hides, disables = frame.hideCalls or 0, binding.disableCalls or 0
    data.secretCharges, data.secretDuration = true, true
    syncEvent(state, "PLAYER_REGEN_DISABLED")
    truthy(state.inCombat, "combat flag changes separately from data secrecy")
    mobilityStatus(addon, "Native tracking")
    equal(currentLive(addon), frame, "combat reuses the live frame")
    equal(frame.durationBinding, binding, "combat reuses the native binding")
    equal(frame.hideCalls or 0, hides, "active combat refresh does not hide then reshow the live frame")
    equal(binding.disableCalls or 0, disables, "active combat refresh does not detach the running timer")
    truthy(isSecret(frame.alpha), "secret native alpha is passed through without decoding")
    equal(nativeText(addon), "No Shimmer\n16.0", "combat transition does not hide or restart the countdown")
    state:advance(2.3)
    equal(nativeText(addon), "No Shimmer\n13.7", "native timer keeps progressing in combat")
    equal(state.alphaReads, 0, "addon never reads native alpha back")
    equal(state.liveMeasurements, 0, "addon never measures restricted duration text")
end)

test("secret combat charges preserve 2-to-1 hide 1-to-0 show and 0-to-1 hide for both skills", function()
    for _, id in ipairs({ 1953, 212653 }) do
        local name = id == 1953 and "Blink" or "Shimmer"
        local data = { charges = 2, maxCharges = 2, chargeStart = 100, chargeDuration = 20,
            cooldownStart = 100, cooldownDuration = 0, secretCharges = true, secretDuration = true }
        local _, addon, state = mobilityLogin(id, data, { inCombat = true })
        equal(nativeText(addon), "", "fully charged is hidden")
        data.charges, data.cooldownDuration = 1, 0.5
        syncEvent(state, "SPELL_UPDATE_CHARGES")
        mobilityStatus(addon, "Native tracking")
        equal(nativeText(addon), "", "one usable charge during a short spell interval remains hidden")
        local frame = currentLive(addon)
        state:advance(6)
        data.charges, data.cooldownDuration = 0, 20
        syncEvent(state, "SPELL_UPDATE_CHARGES")
        equal(currentLive(addon), frame, "native state transitions reuse the frame")
        equal(nativeText(addon), "No " .. name .. "\n14.0", "last use keeps the existing recharge start")
        local timerHandle = frame.durationBinding.duration
        local lastEvaluation = state.curveEvaluations[#state.curveEvaluations]
        truthy(timerHandle ~= lastEvaluation.duration, "visibility and digit timing use different native objects")
        data.charges, data.chargeStart, data.cooldownDuration = 1, state.clock, 0
        syncEvent(state, "SPELL_UPDATE_CHARGES")
        mobilityStatus(addon, "Native tracking")
        equal(nativeText(addon), "", "one recovered charge hides despite the next recharge still running")
        truthy(frame.durationBinding.enabled, "native tracking may continue while alpha is zero")
        equal(state.alphaReads, 0, "no alpha readback across secret transitions")
    end
end)

test("native visibility excludes GCD short intervals and unrelated unusability with one charge", function()
    local data = { charges = 1, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
        cooldownStart = 100, cooldownDuration = 1.5, isOnGCD = true,
        secretCharges = true, secretDuration = true }
    local env, addon, state = mobilityLogin(212653, data, { inCombat = true })
    env.C_Spell.IsSpellUsable = function() error("mana/silence/control usability is not charge exhaustion") end
    for _, totalDuration in ipairs({ 0, 0.5, 0.75, 1.5 }) do
        for _, rate in ipairs({ 1, 2, 4 }) do
            data.cooldownDuration, data.rate = totalDuration, rate
            syncEvent(state, "SPELL_UPDATE_COOLDOWN")
            equal(nativeText(addon), "", "native BaseTime classification keeps GCD/interval invisible")
        end
    end
    local visibilityReads = 0
    for _, read in ipairs(state.spellReads) do
        if read.api == "cooldown-duration-visibility" then visibilityReads = visibilityReads + 1 end
        truthy(read.api ~= "cooldown-duration-timer", "secret multi-charge visibility must retain GCD in the ordinary cooldown object")
    end
    truthy(visibilityReads > 0, "native alpha queried ordinary cooldown with explicit ignoreGCD=false")
    equal(#state.curves, 1, "identical metadata envelope reuses one native curve")
end)

test("native visibility classifies total not remaining and timer follows recharge rate changes", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 81, chargeDuration = 20,
        cooldownStart = 81, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local _, addon, state = mobilityLogin(212653, data, { inCombat = true })
    equal(nativeText(addon), "No Shimmer\n1.0", "less than GCD remaining is still genuine depletion")
    state:advance(0.9)
    equal(nativeText(addon), "No Shimmer\n0.1", "countdown does not disappear at the visibility threshold")
    data.chargeStart, data.cooldownStart, data.rate = state.clock - 3, state.clock - 3, 4
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(nativeText(addon), "No Shimmer\n2.0", "native timer reflects changed recharge rate without Lua calculations")
    data.chargeStart, data.chargeDuration, data.cooldownStart, data.cooldownDuration, data.rate = state.clock, 8, state.clock, 8, 2
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "No Shimmer\n4.0", "new API durations replace the native timer after cooldown reduction")
    equal(state.alphaReads, 0, "rate changes never inspect opacity")
end)

test("single secret charge capacity uses public recharge activity without multi-charge inference", function()
    local data = { charges = 1, maxCharges = 1, chargeStart = 100, chargeDuration = 12,
        cooldownStart = 100, cooldownDuration = 1.5, secretCharges = true, secretDuration = true, isOnGCD = true }
    local _, addon, state = mobilityLogin(1953, data, { inCombat = true, specID = false })
    mobilityStatus(addon, "Unknown")
    equal(nativeText(addon), "", "single charge is available even with GCD")
    data.charges = 0
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "No Blink\n12.0", "active recharge implies depletion only with public capacity one")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "first recovery ends single-charge reminder")
    equal(#state.curves, 0, "single-charge public activity does not need threshold visibility")
end)

test("secret cooldown resets and repeated combat transitions leave no stale or restarted output", function()
    local data = { charges = 0, maxCharges = 3, chargeStart = 97, chargeDuration = 20,
        cooldownStart = 97, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local _, addon, state = mobilityLogin(1953, data, { inCombat = true })
    equal(nativeText(addon), "No Blink\n17.0", "larger public capacity uses native tracking")
    local frame, binding, curve = currentLive(addon), currentLive(addon).durationBinding, state.curves[1]
    data.charges, data.chargeDuration, data.cooldownDuration = 3, 0, 0
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "real reset immediately hides")
    syncEvent(state, "PLAYER_REGEN_ENABLED")
    equal(nativeText(addon), "", "leaving combat cannot revive old duration")
    syncEvent(state, "PLAYER_REGEN_DISABLED")
    equal(nativeText(addon), "", "reentering combat cannot revive old duration")
    data.charges, data.chargeStart, data.chargeDuration = 0, 98, 20
    data.cooldownStart, data.cooldownDuration = 98, 20
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    for _ = 1, 3 do
        state:advance(1)
        syncEvent(state, "PLAYER_REGEN_ENABLED")
        syncEvent(state, "PLAYER_REGEN_DISABLED")
    end
    equal(nativeText(addon), "No Blink\n15.0", "combat transitions use fresh duration, never restart full cooldown")
    equal(currentLive(addon), frame, "reset and combat transition reuse frame")
    equal(frame.durationBinding, binding, "reset and combat transition reuse binding")
    equal(state.curves[1], curve, "reset and combat transition reuse curve")
    equal(#state.curves, 1, "no curve allocation growth")
end)

test("closing Options stopping Preview and styling preserve secret live visibility and monitoring", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 94, chargeDuration = 20,
        cooldownStart = 94, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local _, addon, state = mobilityLogin(212653, data)
    local panel, controls = options(addon)
    truthy(addon:SetPreview("all"), "out-of-combat sample begins")
    local live = currentLive(addon)
    equal(nativeText(addon), "", "sample suppresses matching live output")
    addon:StopPreview()
    equal(nativeText(addon), "No Shimmer\n14.0", "stop queries native tracking again")
    truthy(live.durationBinding.enabled and isSecret(live.alpha), "native timing and visibility are both restored")
    truthy(addon:SetPreview("all"), "sample can be started again")
    syncEvent(state, "PLAYER_REGEN_DISABLED")
    equal(addon.previewState.mode, "off", "combat removes only simulation")
    equal(nativeText(addon), "No Shimmer\n14.0", "combat keeps native live timer and alpha")
    controls.close:Click()
    truthy(not panel:IsShown() and addon.mobilityTracking, "closing Options leaves live module active")
    data.charges, data.cooldownDuration = 1, 1.5
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "closed Options still receives recovery and native hide")
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 33 }, scale = 1.4 })
    addon:RefreshReminderClassColor()
    equal(nativeText(addon), "", "font/color refresh cannot overwrite secret zero opacity")
    truthy(isSecret(live.alpha), "style alpha is confined to FontString text color")
    data.charges, data.cooldownDuration = 0, 20
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "No Shimmer\n14.0", "live monitoring resumes depletion with Options still closed")
    equal(state.alphaReads, 0, "render refresh never reads secret frame alpha")
    equal(state.liveMeasurements, 0, "native text remains outside string measurement")
end)

test("native charge visibility reports precise missing or restricted API prerequisites", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20,
        cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local env, addon, state = mobilityLogin(212653, data, { curveUnavailable = true })
    truthy(addon:GetMobilityStatus().status == "Unsupported" or addon:GetMobilityStatus().status == "Restricted",
        "missing native curve support is reported, not fabricated depletion")
    equal(nativeText(addon), "", "unavailable native display path stays safely hidden")
    local _, other, otherState = mobilityLogin(212653, copy(data),
        { baseCooldowns = { [1953] = { secret(500), 1500 }, [212653] = { 500, 0 } } })
    truthy(other:GetMobilityStatus().status == "Restricted" or other:GetMobilityStatus().status == "Unknown",
        "secret public-metadata candidate cannot be compared to build a threshold")
    equal(nativeText(other), "", "secret envelope metadata does not produce guessed alpha")
    equal(#otherState.errors, 0, "metadata secrets are rejected before arithmetic")
    local _, changedMetadata = mobilityLogin(212653, copy(data),
        { baseCooldowns = { [1953] = { 20000, 1500 }, [212653] = { 500, 0 } } })
    mobilityStatus(changedMetadata, "Restricted")
    equal(nativeText(changedMetadata), "", "changed metadata rejects the classifier instead of inflating its threshold")
    data.secretCapacity = true
    addon:RefreshMobility()
    mobilityStatus(addon, "Restricted")
    equal(nativeText(addon), "", "unknown capacity cannot use single-charge reasoning")
    data.secretCapacity, data.secretActivity = false, true
    addon:RefreshMobility()
    mobilityStatus(addon, "Restricted")
    equal(nativeText(addon), "", "secret recharge activity is never branched on")
    equal(#state.errors, 0, "restricted prerequisite paths do not throw")
end)

test("reminder names and native digits share fixed Blizzard class color with Preview and future Proc", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20,
        cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true }
    local _, addon, state = mobilityLogin(212653, data)
    local live = currentLive(addon)
    same(live.text.textColor, { 0.25, 0.78, 0.92, 1 }, "one native FontString colors both skill name and timer")
    truthy(live.durationBinding.format:find("No Shimmer\n{}", 1, true), "name and numeric token share styled string")
    truthy(not live.durationBinding.format:find("|c", 1, true), "restricted formatting contains no color escape markup")
    local panel = options(addon)
    truthy(addon:SetPreview("all"), "all defined test samples are shown")
    local guideColor
    for _, frame in pairs(addon.previewFrames) do
        same(frame.text.textColor, live.text.textColor, "Mobility/Proc Preview uses the same automatic class color")
        guideColor = frame.guidance.label.textColor
        same(guideColor, { 0.55, 0.8, 1, 1 }, "TEST label retains its helper style")
    end
    local saved, reads = copy(addon.db), state.classColorReads
    addon:RefreshPreview()
    addon:RefreshMobility()
    equal(state.classColorReads, reads, "ordinary renderer reuse reuses class color cache")
    same(addon.db, saved, "color does not persist RGB in account settings")
    truthy(panel.brandingHeader.wordmark.kind == "Texture", "brand remains authored artwork")
end)

test("class color survives font changes reuse spec changes and reload without saved RGB", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }
    local env, addon, state = mobilityLogin(212653, data)
    local frame = currentLive(addon)
    local savedColor = copy(frame.text.textColor)
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 36 }, scale = 1.25 })
    same(frame.text.textColor, savedColor, "changing font reapplies class color")
    data.charges = 1; syncEvent(state, "SPELL_UPDATE_CHARGES")
    data.charges = 0; syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(currentLive(addon), frame, "reused live frame remains pooled")
    same(frame.text.textColor, savedColor, "reused native frame keeps class color")
    for _, specID in ipairs({ 62, 63, 64 }) do
        state.specID = specID
        syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        same(currentLive(addon).text.textColor, savedColor, "Mage spec never selects a different color")
    end
    local _, reloaded = mobilityLogin(212653, copy(data), nil, copy(env.CarGOUIDB))
    same(currentLive(reloaded).text.textColor, savedColor, "reload derives current player color")
    local _, warrior = login(copy(env.CarGOUIDB), false, { classToken = "WARRIOR" })
    local sample = warrior:AcquireReminderFrame({ id = "future_proc" }, "preview")
    warrior:ApplyFontSettings(sample.text, warrior:GetReminderStyle(sample.styleKey))
    same(sample.text.textColor, { 0.78, 0.61, 0.43, 1 }, "shared account DB cannot carry Mage RGB onto another class")
    equal(addon.db.reminderClassColor, nil, "session cache is not a SavedVariables member")
end)

test("class color fallback retries and world entry refreshes hidden and live pooled frames", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 }, { classColors = {} })
    local live = currentLive(addon)
    same(live.text.textColor, { 1, 1, 1, 1 }, "initial unavailable color uses safe white")
    options(addon)
    addon:SetPreview("all")
    addon:StopPreview()
    addon:UpdateSettings({ mobility = { enabled = false } })
    state.classColors.MAGE = { 0.25, 0.78, 0.92 }
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    truthy(not addon.mobilityTracking, "style lifecycle does not enable disabled Mobility")
    for _, pool in pairs(addon.reminderFrames) do
        for _, frame in pairs(pool) do
            same(frame.text.textColor, { 0.25, 0.78, 0.92, 1 }, "world entry fixes all hidden/reused reminder text")
        end
    end
    for _, invalid in ipairs({ { 0 / 0, 0.4, 0.4 }, { math.huge, 0.4, 0.4 },
        { -0.1, 0.4, 0.4 }, { 1.1, 0.4, 0.4 }, { secret(0.25), 0.78, 0.92 } }) do
        state.classColors.MAGE = invalid
        equal(addon:RefreshReminderClassColor(), false, "invalid/secret color is rejected before comparison")
        same(live.text.textColor, { 1, 1, 1, 1 }, "invalid source never leaks invalid RGB into SetTextColor")
    end
    state.classColors.MAGE = { 0.25, 0.78, 0.92 }
    equal(addon:ApplyReminderColor(live.text), true, "failed lookup is retried on demand")
    same(live.text.textColor, { 0.25, 0.78, 0.92, 1 }, "class color recovers without reload")
    equal(#state.errors, 0, "color recovery produces no errors")
end)

test("custom color controls are confined to Proc and class style adds no polling or global mutations", function()
    local _, addon = login()
    local _, controls = options(addon)
    for key in pairs(controls) do
        truthy(not key:lower():find("color", 1, true) or key:match("^proc"), "only Proc may expose color controls: " .. key)
    end
    for _, path in ipairs({ "UI/Options.lua", "Config/Defaults.lua", "UI/ReminderStyle.lua" }) do
        local file = assert(io.open(root .. "/" .. path, "r"))
        local source = file:read("*a"); file:close()
        for _, forbidden in ipairs({ "CUSTOM_CLASS_COLORS", "ElvUI", "Ellesmere", '"OnUpdate"', "NewTicker" }) do
            truthy(not source:find(forbidden, 1, true), path .. " does not introduce " .. forbidden)
        end
    end
end)


test("schema-5 migration keeps actual Mage appearance, sums offsets once, and backs up conflicting legacy values", function()
    local shared = { font = { size = 41 }, shadow = { enabled = false }, scale = 1.7 }
    local saved = { schemaVersion = 4, font = { face = "Fonts\\MORPHEUS.TTF", size = 30, outline = "THICKOUTLINE" },
        shadow = { enabled = false }, scale = 1.25, position = { x = 79, y = -51 },
        options = { animatedTitle = false, position = { x = 43, y = -18 } }, mobility = { enabled = false },
        reminders = { mage_fire_shimmer = { position = { x = 15, y = 27 } },
            mage_fire_hot_streak_left = { position = { x = 11, y = 12 } },
            mage_fire_hot_streak_right = { position = { x = -17, y = 18 } } },
        styles = { mobility_blink = { font = { size = 35 } }, mobility_shimmer = { font = { size = 46 }, scale = 1.8 },
            mage_fire_hot_streak_left = shared, mage_fire_hot_streak_right = shared,
            unknown_region = { font = { size = 60 } } } }
    local _, addon = mobilityLogin(212653, { charges = 1, maxCharges = 2 }, nil, saved)
    equal(addon.db, saved, "root SavedVariables identity retained")
    equal(addon.db.schemaVersion, 5, "one-time migration recorded")
    local mobility, proc = addon:GetMobilityConfig(), addon:GetProcConfig(63)
    equal(mobility.style.font.size, 46, "actually selected Shimmer wins conflicting skill styles")
    equal(mobility.style.scale, 1.8, "selected scale copied exactly once")
    same(mobility.position, { anchor = "CENTER", x = 94, y = -24 }, "legacy global and active region offsets summed once")
    equal(mobility.enabled, false, "module switch retained")
    same(addon.db.options.position, { x = 43, y = -18 }, "shell position retained")
    equal(addon.db.options.animatedTitle, false, "animation retained")
    equal(proc.style.font.size, 41, "known Fire Proc style stays Fire scoped")
    truthy(proc.style ~= mobility.style and proc.style.font ~= mobility.style.font and proc.style.shadow ~= mobility.style.shadow,
        "Mobility and Proc own separate mutable styles")
    equal(proc.regions.mage_fire_hot_streak_left.position.x, 90, "left region offset preserved independently")
    equal(proc.regions.mage_fire_hot_streak_right.position.x, 62, "right region offset preserved independently")
    local backup = addon.db.migrations.scope5.source
    equal(backup.styles.mobility_blink.font.size, 35, "conflicting Blink value backed up")
    equal(backup.styles.unknown_region.font.size, 60, "unknown source retained without propagation")
    truthy(backup.styles.mage_fire_hot_streak_left ~= proc.style, "active style detached from immutable migration evidence")
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 48 } })
    backup.styles.mobility_shimmer.font.size = 66
    local _, reloaded = login(copy(addon.db))
    equal(reloaded:GetMobilityConfig().style.font.size, 48, "reload never reapplies legacy backup")
    equal(reloaded.db.classes.WARRIOR, nil, "migration never materializes another class")
end)

test("non-Mage login does not inherit or instantiate legacy Mage settings and returning Mage restores them", function()
    local saved = { schemaVersion = 4, position = { x = 55, y = -33 },
        mobility = { enabled = false }, styles = { mobility_blink = { font = { size = 52 }, scale = 2 } } }
    local _, warrior, ws = login(saved, false, { classToken = "WARRIOR", specID = 71 })
    same(warrior:GetMobilityConfig().style, warrior.factoryReminderStyle, "new class uses factory style")
    same(warrior:GetMobilityConfig().position, { anchor = "CENTER", x = 0, y = 0 }, "new class has factory position")
    equal(warrior:GetMobilityConfig().enabled, true, "Mage disable never leaks to Warrior")
    equal(warrior.db.classes.MAGE, nil, "pending migration does not allocate Mage config on Warrior")
    equal(ws.moduleLoads, 1, "Warrior loads unified Data without inheriting Mage configuration")
    warrior:UpdateReminderStyle("mobility:WARRIOR", { font = { size = 29 } })
    local _, mage = mobilityLogin(1953, { charges = 1, maxCharges = 1 }, nil, copy(warrior.db))
    equal(mage:GetMobilityConfig().style.font.size, 52, "Mage consumes its backed-up legacy appearance later")
    equal(mage:GetMobilityConfig().position.x, 55, "Mage consumes its own legacy coordinates")
    equal(mage.db.classes.WARRIOR.mobility.style.font.size, 29, "return preserves Warrior settings")
    truthy(mage.db.classes.MAGE.mobility.style.font ~= mage.db.classes.WARRIOR.mobility.style.font, "class font tables never alias")
    mage:UpdateReminderStyle("mobility:MAGE", { font = { size = 43 } })
    local _, back = login(copy(mage.db), false, { classToken = "WARRIOR", specID = 71 })
    equal(back:GetMobilityConfig().style.font.size, 29, "return to Warrior restores Warrior saved value")
    equal(back.db.classes.MAGE.mobility.style.font.size, 43, "other class persisted but is not the active context")
end)

test("context style validation is atomic and reset preserves other scopes and all positions", function()
    local _, addon = login()
    local before = copy(addon.db)
    for _, patch in ipairs({ { font = { size = 7 } }, { font = { size = 99 } },
        { font = { face = "bad.ttf" } }, { font = { outline = "bad" } },
        { scale = 0/0 }, { scale = 3.01 }, { shadow = { enabled = 1 } },
        { font = { size = 30 }, color = { 1, 0, 0 } }, { position = { x = 9 } } }) do
        equal(addon:UpdateReminderStyle("mobility:MAGE", patch), false, "invalid style rejected")
        same(addon.db, before, "invalid style is atomic")
    end
    equal(addon:UpdateReminderStyle("mobility:WARRIOR", { scale = 2 }), false, "foreign context rejected")
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { face = "fonts\\morpheus.ttf", size = 42 }, scale = 2 }), "current context accepted")
    equal(addon:GetMobilityConfig().style.font.face, "Fonts\\MORPHEUS.TTF", "font canonicalized")
    addon:UpdateReminderStyle("proc:MAGE:63", { font = { size = 37 } })
    local proc = copy(addon:GetProcConfig(63))
    addon:ResetReminderStyle("mobility:MAGE")
    same(addon:GetMobilityConfig().style, addon.factoryReminderStyle, "current style reset")
    same(addon:GetProcConfig(63), proc, "Mobility reset leaves Proc untouched")
    same(addon:GetMobilityConfig().position, before.classes.MAGE.mobility.position, "style reset leaves position")
end)

test("automatic Appearance context discards drafts while Proc regions share a spec style and independent positions", function()
    local _, addon, state = login()
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility")
    truthy(not controls.appearanceEntry:IsEnabled(), "Appearance context is read-only, no skill/class/spec selector")
    enter(controls.appearanceFontSize.editBox, "29")
    typeText(controls.appearanceScale.editBox, "2.7")
    addon:SelectOptionsCategory("proc")
    choose(controls.procEntry, "mage_fire_hot_streak_left")
    controls.procAppearance:Click()
    equal(panel.selectedAppearanceKey, "proc:MAGE:63", "Proc style context is current class and spec")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 24, "switching context discards unsubmitted draft")
    dragValue(controls.appearanceFontSize, 45)
    equal(addon:GetProcConfig(63).style.font.size, 45, "Proc size saves to spec")
    controls.appearancePreview:Click()
    equal(addon.previewFrames.mage_fire_hot_streak_left.text.font[2], 45, "selected region uses spec style")
    addon:SetPreview("all")
    equal(addon.previewFrames.mage_fire_hot_streak_right.text.font[2], 45, "opposite region uses same spec style")
    typeText(controls.appearanceFontSize.editBox, "66")
    state.specID = 64; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(panel.selectedAppearanceKey, "proc:MAGE:64", "spec context follows identity")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 24, "new spec discards draft and starts factory")
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 45, "returning spec restores committed value")
    addon:OpenAppearance("mobility")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 29, "Mobility retains its own committed value")
    for key in pairs(controls) do
        truthy(key ~= "classSelector" and key ~= "specSelector" and key ~= "profileSelector" and key ~= "loadModule", "no added context-management buttons")
    end
    local file = assert(io.open(root .. "/UI/Options.lua", "r")); local source = file:read("*a"); file:close()
    truthy(not source:find("real Proc / Buff monitoring is not implemented", 1, true), "obsolete Proc-only sample claim is removed")
    truthy(panel.procStatus:GetText():find("Contextual tests", 1, true) and panel.procStatus:GetText():find("separate", 1, true), "Proc page distinguishes native runtime from sample mode")
end)

test("Blink Shimmer and all Mage specs share every Mobility preference without merging Proc", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 97, chargeDuration = 20 }
    local env, addon, state = mobilityLogin(1953, data)
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 43 }, scale = 1.8 })
    addon:UpdateSettings({ position = { x = 52, y = -29 } })
    local scope = addon:GetMobilityConfig()
    local saved = copy(scope)
    local id = addon:GetMobilityEntry().id
    state.mobility.known[212653], state.mobility.override = true, 212653
    state.mobility.spells[212653] = data; syncEvent(state, "SPELLS_CHANGED")
    equal(addon:GetMobilityEntry().id, id, "replacement keeps compatibility position ID")
    equal(currentLive(addon).text.font[2], 43, "Shimmer uses same Mage appearance as Blink")
    equal(currentLive(addon):GetScale(), 1.8, "class scale applied once")
    for _, spec in ipairs({ 62, 64, 63 }) do
        state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        equal(addon:GetMobilityConfig(), scope, "all Mage specs use identical configuration object")
        same(addon:GetMobilityConfig(), saved, "spec change never rewrites Mobility settings")
        reminderAnchor(currentLive(addon), addon:GetMobilityEntry(), addon, env)
    end
    equal(addon:GetProcConfig(63).style.font.size, 24, "Mobility changes never affect Proc")
    local _, reloaded = mobilityLogin(212653, data, { specID = 62 }, copy(addon.db))
    same(reloaded:GetMobilityConfig(), saved, "reload on another spec restores shared class configuration")
end)

test("style edits preserve opaque live alpha and native countdown binding without any spell query", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 94, chargeDuration = 20,
        secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = 20 }
    local env, addon, state = mobilityLogin(212653, data, { inCombat = true })
    local frame = currentLive(addon)
    local binding, originalAlpha, originalDuration = frame.durationBinding, frame.alpha, frame.durationBinding.duration
    local durationWrites, alphaWrites, reads = binding.durationWrites, frame.alphaWrites, copy(state.spellReads)
    local timer = nativeText(addon)
    truthy(addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 44, outline = "THICKOUTLINE" }, scale = 1.75, shadow = { enabled = false } }), "live style accepted")
    equal(binding.duration, originalDuration, "style keeps exact native duration handle")
    equal(binding.durationWrites, durationWrites, "style never calls SetDuration")
    equal(frame.alpha, originalAlpha, "style keeps exact opaque native opacity")
    equal(frame.alphaWrites, alphaWrites, "style never overwrites native alpha")
    same(state.spellReads, reads, "style refresh never queries current combat APIs")
    equal(nativeText(addon), timer, "style never recalculates timer text")
    equal(frame:GetWidth(), 44 * 16, "live frame width follows entry font size")
    equal(frame:GetHeight(), 44 * 3, "live frame height follows entry font size")
    reminderAnchor(frame, addon:GetMobilityEntry(), addon, env)
    state:advance(2)
    equal(nativeText(addon), "No Shimmer\n12.0", "original recharge continues instead of restarting")
    equal(state.liveMeasurements, 0, "style does not measure restricted text")
    equal(state.alphaReads, 0, "style never reads native opacity back")
    data.charges, data.cooldownDuration = 1, 0
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "first restored charge still hides immediately")
end)

test("Mobility appearance Preview uses current actual skill and same class style as live", function()
    local _, addon = mobilityLogin(1953, { charges = 0, maxCharges = 1, chargeStart = 100, chargeDuration = 20 })
    options(addon)
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 32 }, scale = 1.25 })
    truthy(addon:StartAppearancePreview("mobility:MAGE"), "current Mobility sample starts")
    local preview = addon.previewFrames[addon:GetMobilityEntry().id]
    same(preview.text.font, currentLive(addon).text.font, "preview/live share typography")
    equal(preview:GetScale(), currentLive(addon):GetScale(), "preview/live share scale")
    equal(addon:GetMobilityStatus().spellID, 1953, "preview preserves actual learned Blink identity")
    addon:StopPreview()
    equal(nativeText(addon), "No Blink\n20.0", "real Blink timer restored")
end)

test("updating Proc spec style updates all its regions while leaving Mobility font untouched", function()
    local _, addon = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 })
    options(addon); addon:SetPreview("all")
    local snapshots = {}
    for _, pool in pairs(addon.reminderFrames) do
        for _, frame in pairs(pool) do snapshots[frame] = frame.text.fontWrites end
    end
    addon:UpdateReminderStyle("proc:MAGE:63", { font = { size = 39 } })
    for frame, writes in pairs(snapshots) do
        if frame.styleKey == "proc:MAGE:63" then
            truthy(frame.text.fontWrites > writes, "each current-spec Proc region updates")
            equal(frame.text.font[2], 39, "all Proc regions read one style")
        else
            equal(frame.text.fontWrites, writes, "Mobility receives no font writes")
        end
    end
end)

test("Alliance Arcane preserves faction and spec identity inside the graphite CUI design", function()
    local _, addon, state = login(nil, false, { specID = 62, faction = "Alliance" })
    equal(state.factionReads, 0, "hidden Options performs no decorative identity reads")
    local before = copy(addon.db)
    local panel, controls = options(addon)
    local info = addon:GetAutomaticThemeInfo()
    equal(info.mode, "Automatic", "theme mode is automatic")
    equal(info.faction, "Alliance", "faction detected")
    equal(info.specialization, "Arcane", "specialization detected")
    equal(info.themeKey, "alliance_arcane", "specified combination selected")
    equal(info.headerKey, "alliance", "Header identity depends only on faction")
    equal(info.bodyKey, "arcane", "Body identity depends only on current class and spec")
    same(panel.theme.header.gradient.first, { 0.025, 0.075, 0.18, .18 }, "header retains a restrained faction identity layer")
    same(panel.theme.header.gradient.last, { 0.06, 0.28, 0.52, .18 }, "header identity remains independent of spec")
    local base, raised = addon.DesignSystem.surfaceBase, addon.DesignSystem.surfaceRaised
    same(panel.theme.body.gradient.first, { base[1], base[2], base[3], 1 }, "body uses central graphite surface")
    same(panel.theme.body.gradient.last, { raised[1], raised[2], raised[3], 1 }, "body depth uses the raised surface token")
    same(panel.brandingHeader.sweep.vertexColor, { 0.30, 0.66, 1.00 }, "brand emphasis belongs to faction Header")
    equal(panel.brandingHeader.wordmark.vertexColor, nil, "blue/gold wordmark receives no tint")
    same(addon.db, before, "automatic theme never writes saved reminder settings")
    for key in pairs(controls) do
        truthy(not key:lower():find("color", 1, true) or key:match("^proc"), "theme exposes no color controls")
        truthy(key ~= "themeSelect" and key ~= "faction" and key ~= "specialization" and key ~= "applyTheme", "no manual theme selector")
    end
    for _, category in ipairs(panel.categories) do
        equal(category.themeSelection:IsShown(), category.key == panel.activeCategory, "selection gradient follows category")
    end
end)

test("all six Mage faction-spec combinations and unknown identities resolve safe automatic themes", function()
    local _, addon, state = login(nil, false, { mobility = nil })
    local panel = options(addon)
    for _, faction in ipairs({ "Alliance", "Horde" }) do
        for spec, name in pairs({ [62] = "arcane", [63] = "fire", [64] = "frost" }) do
            state.faction, state.specID = faction, spec
            addon:RefreshOptionsTheme()
            equal(addon:GetAutomaticThemeInfo().themeKey, faction:lower() .. "_" .. name, "all mapped combinations resolve")
        end
    end
    for _, item in ipairs({ { "Neutral", "MAGE", 62, "neutral_arcane" }, { "Unknown", "MAGE", 62, "neutral_arcane" },
        { "Alliance", "MAGE", false, "alliance_mage" }, { "Horde", "MAGE", 999, "horde_mage" },
        { "Alliance", "WARRIOR", 9999, "alliance_warrior" }, { "Alliance", "UNKNOWN", false, "alliance_neutral" },
        { secret("Alliance"), "MAGE", 62, "neutral_arcane" }, { "Alliance", "MAGE", secret(62), "alliance_mage" } }) do
        state.faction, state.classToken, state.specID = item[1], item[2], item[3] or nil
        addon:RefreshOptionsTheme()
        local info = addon:GetAutomaticThemeInfo()
        equal(info.themeKey, item[4], "unknown/unselected/secret identity never borrows wrong specialization")
        truthy(info.fallback, "fallback reason is explicit")
    end
    equal(panel:IsShown(), true, "fallback requires no manual selection or dialog")
    equal(#state.errors, 0, "opaque identity fallback is safe")
end)

test("theme events refresh visible Options only and closing preserves live Mobility subscriptions", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 96, chargeDuration = 20 })
    local panel = options(addon)
    -- First visiting Frost grows existing dropdown choice pools to their known
    -- maximum. Their static skins are reused afterwards, like reminder frames.
    for _, spec in ipairs({ 62, 64, 63 }) do state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player") end
    local resources, before = resourceCounts(state), copy(addon.db)
    state.specID = 62
    syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(addon:GetAutomaticThemeInfo().themeKey, "alliance_arcane", "visible spec event changes theme")
    same(addon.db, before, "spec change does not replace entry settings")
    state.faction = "Horde"
    state:fire("UNIT_FACTION", "target")
    equal(addon:GetAutomaticThemeInfo().themeKey, "alliance_arcane", "non-player faction event ignored")
    state:fire("UNIT_FACTION", "player")
    equal(addon:GetAutomaticThemeInfo().themeKey, "horde_arcane", "player faction event updates automatically")
    panel:Hide()
    local reads, gradients = state.factionReads, state.gradientWrites
    state.faction, state.specID = "Alliance", 64
    syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    state:fire("UNIT_FACTION", "player")
    addon:RefreshOptionsTheme()
    equal(state.factionReads, reads, "hidden theme stops identity reads")
    equal(state.gradientWrites, gradients, "hidden theme stops decorative writes")
    truthy(addon.mobilityTracking, "closing does not disable live monitoring")
    equal(nativeText(addon), "No Shimmer\n16.0", "live monitoring survives hidden spec events")
    addon:ToggleOptions()
    equal(addon:GetAutomaticThemeInfo().themeKey, "alliance_frost", "reopening freshly resolves current identity")
    -- One new live frame is allowed for each newly used position ID; decorations are reused.
    equal(#state.textures, resources.textures, "theme updates reuse all textures")
    equal(#state.animations, resources.groups, "theme updates allocate no animation groups")
    equal(panel.themeWatching, true, "visible theme subscribed")
    panel:Hide()
    equal(panel.themeWatching, false, "hidden theme unsubscribed independently")
end)

test("theme refresh cannot reset opaque timers opacity class colors or entry appearance", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 93, chargeDuration = 20,
            secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = 20 },
        { inCombat = false })
    local panel = options(addon)
    local frame, saved = currentLive(addon), copy(addon.db)
    local binding = frame.durationBinding
    local alpha, alphaWrites, duration, writes = frame.alpha, frame.alphaWrites, binding.duration, binding.durationWrites
    local reads, color = copy(state.spellReads), copy(frame.text.textColor)
    for _, id in ipairs({ 62, 64, 63 }) do
        state.specID = id
        addon:RefreshOptionsTheme()
    end
    same(addon.db, saved, "decorative themes never write any reminder setting")
    same(state.spellReads, reads, "theme resolver does not query skill state")
    equal(binding.duration, duration, "native duration binding unchanged")
    equal(binding.durationWrites, writes, "theme never rebinds native timer")
    equal(frame.alpha, alpha, "opaque alpha identity unchanged")
    equal(frame.alphaWrites, alphaWrites, "theme never writes live opacity")
    same(frame.text.textColor, color, "reminder class color independent of spec accents")
    truthy(panel.titleAnimation:IsPlaying(), "theme changes preserve currently eligible branding animation")
    state:advance(1)
    equal(nativeText(addon), "No Shimmer\n12.0", "native countdown advances after theme changes")
end)

test("saved schema-5 class settings win and new scopes use detached factory defaults", function()
    local _, first = login()
    first:UpdateReminderStyle("mobility:MAGE", { font = { size = 47 }, scale = 1.8 })
    first:UpdateSettings({ mobility = { preferences = { skillDisplay = { label = false } } }, position = { x = 71, y = -28 } })
    first:GetProcConfig(63)
    local saved = copy(first.db)
    saved.classes.MAGE.mobility.style.shadow = nil
    local _, mage = login(saved)
    equal(mage:GetMobilityConfig().style.font.size, 47, "valid v5 style wins missing-field normalization")
    equal(mage:GetMobilityConfig().style.scale, 1.8, "scale retained exactly")
    equal(mage:GetMobilityConfig().style.shadow.enabled, true, "missing field gets factory default")
    equal(mage:GetMobilityConfig().preferences.skillDisplay.label, false, "future module preference is retained inside class")
    equal(mage.db.classes.MAGE.proc[62], nil, "new Arcane config is not eagerly created")
    local _, warrior = login(copy(mage.db), false, { classToken = "WARRIOR", specID = 71 })
    same(warrior:GetMobilityConfig().style, warrior.factoryReminderStyle, "new class does not inherit latest edited style")
    same(warrior:GetMobilityConfig().preferences, {}, "new class does not inherit Mage module preferences")
    truthy(warrior:GetMobilityConfig().style.font ~= warrior.db.classes.MAGE.mobility.style.font, "class font tables are independent")
    equal(warrior.db.classes.MAGE.mobility.position.x, 71, "new class creation never overwrites old coordinates")
end)

test("Arcane and Fire Proc styles stay independent while same-spec region positions remain separate", function()
    local _, addon, state = login(nil, false, { specID = 62 })
    options(addon)
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 36 }, scale = 1.3 })
    local entries = addon:GetPreviewEntries()
    local left, right = entries[2], entries[3]
    addon:UpdateSettings({ reminders = { [left.id] = { position = { x = 31, y = 5 } },
        [right.id] = { position = { x = -19, y = 8 } } } })
    addon:SetPreview("all")
    equal(addon.previewFrames[left.id].text.font[2], 36, "left uses Arcane style")
    equal(addon.previewFrames[right.id].text.font[2], 36, "right uses same Arcane style")
    truthy(addon:GetProcConfig().regions[left.id].position ~= addon:GetProcConfig().regions[right.id].position,
        "independent region coordinates never alias")
    local mobility = copy(addon:GetMobilityConfig())
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    addon:UpdateReminderStyle("proc:MAGE:63", { font = { size = 49 } })
    equal(addon:GetProcConfig().style.font.size, 49, "Fire has separate style")
    truthy(addon.db.classes.MAGE.proc[62].style.font ~= addon:GetProcConfig().style.font, "Proc spec sub-tables do not alias")
    state.specID = 62; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(addon:GetProcConfig().style.font.size, 36, "returning Arcane restores saved style")
    equal(addon:GetReminderPosition(left).x, 31, "Arcane left position retained")
    equal(addon:GetReminderPosition(right).x, -19, "Arcane right position retained")
    same(addon:GetMobilityConfig(), mobility, "Proc style changes never change Mobility")
end)

test("native class loading distinguishes files active data saved configuration and runtime ownership", function()
    local _, mage, ms = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 96, chargeDuration = 20 })
    local report = mage:GetRuntimeLoadDiagnostics()
    equal(ms.moduleLoads, 1, "unified native data package loads exactly once")
    equal(report.modules.fileStatus, "loaded; current adapter active", "Data file status and current adapter activity are explicit")
    equal(report.modules.previewEntries, 8, "only audited active Fire catalog entries instantiated")
    equal(countKeys(mage.mobilityEntries), 1, "no unrelated spec Mobility entry instantiated")
    equal(mage.db.classes.MAGE.proc[62], nil, "unused Arcane config not initialized")
    equal(report.activeSkills, 1, "one effective current skill")
    equal(report.activeBindings, 1, "one live native timer")
    local saved = copy(mage.db)
    local _, warrior, ws = login(saved, false, { classToken = "UNKNOWN", specID = false })
    local wr = warrior:GetRuntimeLoadDiagnostics()
    equal(ws.moduleLoads, 0, "data package is not automatically loaded on unsupported Warrior")
    equal(wr.modules.fileStatus, "not loaded", "files not loaded distinct from inactive")
    equal(wr.modules.previewEntries, 0, "no unrelated preview catalog instantiated")
    equal(wr.liveFrames + wr.previewFrames + wr.allocatedBindings + wr.activeSkills, 0, "no unrelated runtime allocation")
    truthy(warrior.db.classes.MAGE, "shared SavedVariables really does deserialize earlier Mage settings")
    truthy(wr.modules.configuration:find("all previously saved class tables", 1, true), "diagnostic discloses shared storage limitation")
    equal(warrior:GetProcConfig(62), nil, "foreign spec cannot be read as current Proc context")
    for _, file in ipairs(ws.loadedFiles) do
        truthy(not file:find("CarGOUI_Data/", 1, true), "core cannot eagerly execute class business file")
    end
    equal(ws.realReads, 0, "Warrior never queries unrelated spell state")
end)

test("already loaded class module is reported inactive without pretending code or cached frames unload", function()
    local _, addon, state = mobilityLogin(1953, { charges = 0, maxCharges = 1, chargeStart = 100, chargeDuration = 20 })
    local old = currentLive(addon)
    state.classToken, state.specID = "UNKNOWN", nil
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    local report = addon:GetRuntimeLoadDiagnostics()
    equal(report.modules.fileStatus, "loaded; no current adapter active", "loaded code is never claimed unloaded")
    equal(report.activeSkills + report.activeBindings + report.modules.previewEntries, 0, "obsolete activity removed")
    equal(old.durationBinding.enabled, false, "old class timer detached")
    equal(old:IsShown(), false, "old class frame hidden")
    equal(state.moduleLoads, 1, "class change does not reload cached module")
    equal(report.liveFrames, 1, "cached reusable frame remains and is disclosed")
end)

test("unified data registration stays inactive on an unsupported class and never creates its saved defaults", function()
    local env, addon, state = login(nil, false, { classToken = "UNKNOWN", specID = false })
    equal(state.moduleLoads, 0, "unsupported current class does not request Data automatically")
    local before = addon:GetRuntimeLoadDiagnostics()
    truthy(env.C_AddOns.LoadAddOn("CarGOUI_Data"), "explicit native loading is modeled independently of activation")
    addon:RefreshActiveEntries()
    local after = addon:GetRuntimeLoadDiagnostics()
    equal(after.modules.dataPackageLoaded, true, "whole unified package is now loaded")
    equal(after.modules.registeredAdapters, 13, "all shipped class definitions are registered")
    equal(after.modules.loadedClassFiles, classFileCount, "file report counts loaded class business code honestly")
    equal(after.modules.loadedDataFiles, #dataFiles, "whole Data TOC is loaded, internal folders are not separately LoD")
    equal(after.modules.activeAdapterClass, nil, "Mage adapter not selected on Warrior")
    equal(after.modules.mobilityEntries + after.modules.previewEntries, 0, "registration does not instantiate Mage entries")
    equal(after.activeSkills + after.activeBindings + after.allocatedBindings + after.liveFrames + after.previewFrames, 0, "registration creates no unrelated runtime objects")
    equal(after.events.callbacks, before.events.callbacks, "registration adds no unrelated listeners")
    equal(addon.db.classes.MAGE, nil, "registration does not create another class configuration")
    equal(state.realReads, 0, "registration performs no cooldown or charge query")
end)

test("class adapter registry rejects duplicates and only activates the adapter for current class", function()
    local _, addon, state = mobilityLogin(1953, { charges = 0, maxCharges = 1, chargeStart = 98, chargeDuration = 20 })
    local adapter, before = addon.activeClassAdapter, addon:GetRuntimeLoadDiagnostics()
    local called = 0
    local function forbidden() called = called + 1; error("Duplicate adapter must never be dispatched") end
    local replacement = { classToken = "MAGE", ActivateEntries = forbidden, DeactivateEntries = forbidden,
        GetMobilityEntry = forbidden, GetPreviewEntries = forbidden, ReadMobilityState = forbidden }
    equal(addon:RegisterClassAdapter("MAGE", replacement), false, "duplicate class registration rejected")
    equal(addon:RegisterClassAdapter("WARRIOR", replacement), false, "class-token mismatch rejected")
    local selections, deactivations = 0, 0
    local synthetic = { classToken = "TESTCLASS", mobilityEntries = {}, previewEntries = {},
        ActivateEntries = function(self, spec) selections = selections + 1; self.spec = spec; return true end,
        DeactivateEntries = function() deactivations = deactivations + 1 end,
        GetMobilityEntry = function() return nil end,
        GetPreviewEntries = function() return {} end,
        ReadMobilityState = function() return { status = "Unsupported", reason = "Offline adapter fixture only", path = "none" } end }
    truthy(addon:RegisterClassAdapter("TESTCLASS", synthetic), "generic registry accepts an offline future-class fixture")
    equal(selections, 0, "registration does not activate non-current class")
    equal(addon.activeClassAdapter, adapter, "registered active adapter retains identity")
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "No Blink\n18.0", "validated Blink path remains current")
    equal(called, 0, "rejected record never executes a factory or reader")
    local after = addon:GetRuntimeLoadDiagnostics()
    equal(after.modules.registeredAdapters, 14, "13 shipped adapters plus one explicit offline fixture")
    equal(after.events.callbacks, before.events.callbacks, "duplicate rejection adds no listener")
    equal(after.allocatedBindings, before.allocatedBindings, "duplicate rejection adds no binding")
    state.classToken, state.specID = "TESTCLASS", 71
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    equal(addon.activeClassAdapter, synthetic, "current class selects its own registered adapter")
    equal(synthetic.spec, 71, "current specialization passed to selected adapter")
    truthy(selections >= 1, "selected adapter activates only after identity changed")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 0, "old Mage timer is detached on class switch")
    state.classToken, state.specID = "MAGE", 63
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    equal(addon.activeClassAdapter, adapter, "return selects original Mage adapter")
    equal(deactivations, 1, "old adapter deactivated exactly once")
    equal(nativeText(addon), "No Blink\n18.0", "Mage returns to real current cooldown")
end)

test("leftover alpha-8 Mage namespace cannot overwrite unified adapter state or duplicate monitoring", function()
    local function loadRetiredBridge(env, state)
        -- The exact alpha.8 namespace forwarding contract. All subsequent old
        -- business definitions write through __newindex; the new core must keep
        -- that old global detached rather than trusting the leftover folder.
        local chunk = assert(loadstring([[
            local _, module = ...
            local core = _G.CarGOUI_Internal
            assert(type(core) == "table", "CarGOUI core must load before its Mage module.")
            setmetatable(module, { __index = core, __newindex = function(_, key, value) core[key] = value end })
            core.mageModuleRegistered = true
            module.ReadMobilityState = function() error("Retired Mage adapter was dispatched") end
            module.GetMobilityEntry = function() error("Retired Mage entry was dispatched") end
            module.GetPreviewEntries = function() error("Retired Mage previews were dispatched") end
            module.ActivateMageEntries = function() error("Retired Mage activation was dispatched") end
            module.mageModuleLoaded = true
        ]]))
        setfenv(chunk, env); chunk("CarGOUI_Mage", {})
        state.loadedModules.CarGOUI_Mage = true
        state:fire("ADDON_LOADED", "CarGOUI_Mage")
    end
    local fixture = { known = { [1953] = true, [212653] = true }, override = 212653,
        spells = { [212653] = { charges = 0, maxCharges = 2, chargeStart = 96, chargeDuration = 20 } } }
    local env, addon, state = setup(nil, false, { mobility = fixture })
    truthy(env.CarGOUI_Internal ~= addon, "retired namespace is detached before any data module loads")
    loadRetiredBridge(env, state)
    state:fire("ADDON_LOADED", "CarGOUI"); state:fire("PLAYER_LOGIN")
    equal(#state.errors, 0, "stale module before login raises no dispatch error")
    equal(nativeText(addon), "No Shimmer\n16.0", "new registered adapter wins despite old folder loaded first")
    local diagnostics = addon:GetRuntimeLoadDiagnostics()
    local frame, binding, reader = currentLive(addon), currentLive(addon).durationBinding, addon.ReadMobilityState
    loadRetiredBridge(env, state)
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(addon.ReadMobilityState, reader, "old namespace cannot replace core dispatcher after login")
    equal(currentLive(addon), frame, "old module cannot create duplicate live region")
    equal(currentLive(addon).durationBinding, binding, "old module cannot create second binding")
    equal(addon:GetRuntimeLoadDiagnostics().events.callbacks, diagnostics.events.callbacks, "no duplicate monitoring subscription")
    equal(addon:GetRuntimeLoadDiagnostics().allocatedBindings, diagnostics.allocatedBindings, "no duplicate native timer allocation")
    equal(state.moduleLoads, 1, "only unified Data is automatically loaded")
    equal(nativeText(addon), "No Shimmer\n16.0", "countdown remains current after stale module attempt")
end)

test("combat-time initial Load-on-Demand defers safely then synchronizes actual learned spell", function()
    local client = { inCombat = true, mobility = { known = { [1953] = true, [212653] = true }, override = 212653,
        spells = { [212653] = { charges = 0, maxCharges = 2, chargeStart = 94, chargeDuration = 20,
            secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = 20 } } } }
    local _, addon, state = login(nil, true, client)
    equal(state.moduleLoads, 0, "combat load is deferred")
    equal(addon:GetRuntimeLoadDiagnostics().allocatedBindings, 0, "deferred module creates no timer")
    equal(#state.spellReads, 0, "no missing-module spell queries")
    local callbacks = addon:GetEventDiagnostics().callbacks
    addon:EnsureCurrentClassModule(); addon:EnsureCurrentClassModule()
    equal(addon:GetEventDiagnostics().callbacks, callbacks, "deferred callback registered only once")
    syncEvent(state, "PLAYER_REGEN_ENABLED")
    equal(state.moduleLoads, 1, "combat end loads current module once")
    equal(nativeText(addon), "No Shimmer\n14.0", "load re-queries existing recharge instead of starting fake CD")
    equal(addon.classModuleDeferred, false, "deferred listener completed")
end)

test("deferred Mage loading never replaces legacy Proc settings with provisional defaults", function()
    local saved = { schemaVersion = 4, position = { x = 30, y = -10 }, styles = {
        mage_fire_hot_streak_left = { font = { size = 42 }, scale = 1.6 },
        mage_fire_hot_streak_right = { font = { size = 19 } },
    }, reminders = {
        mage_fire_hot_streak_left = { position = { x = 11, y = 7 } },
        mage_fire_hot_streak_right = { position = { x = -22, y = 4 } },
    } }
    local _, addon, state = login(saved, true, { inCombat = true, specID = 63 })
    equal(addon:GetProcConfig(), nil, "no persistent factory Proc before migration catalog")
    addon:ToggleOptions()
    equal(addon.optionsFrame, nil, "deferred combat request cannot instantiate controls for unavailable catalog")
    local shell = copy(addon.db.options)
    equal(addon:UpdateSettings({ options = { animatedTitle = false },
        styles = { ["proc:MAGE:63"] = { font = { size = 50 } } } }), false,
        "deferred context rejects compound edits atomically")
    same(addon.db.options, shell, "rejected Proc edit cannot change shell settings")
    equal(addon:UpdateSettings({ proc = { style = { scale = 2 } } }), false,
        "direct Proc patch cannot write into absent config")
    equal(addon.db.classes.MAGE.proc[63], nil, "no saved provisional record")
    syncEvent(state, "PLAYER_REGEN_ENABLED")
    local panel = addon.optionsFrame
    truthy(panel and panel:IsShown(), "queued Options opens after actual module becomes available")
    addon:OpenAppearance("proc")
    local proc = addon:GetProcConfig()
    equal(proc.style.font.size, 42, "legacy first region style migrates after real module load")
    equal(proc.style.scale, 1.6, "legacy scale preserved once")
    equal(proc.regions.mage_fire_hot_streak_left.position.x, 41, "left global and region offset combine once")
    equal(proc.regions.mage_fire_hot_streak_right.position.x, 8, "right position stays independent")
    equal(addon.db.migrations.scope5.source.styles.mage_fire_hot_streak_right.font.size, 19,
        "conflicting region style is backed up")
    truthy(panel.controls.appearanceFontSize:IsEnabled(), "ready module re-enables existing controls")
    local _, reloaded = login(copy(addon.db), false, { specID = 63 })
    equal(reloaded:GetProcConfig().style.font.size, 42, "reload does not lose deferred migration result")
    equal(#state.errors, 0, "no lifecycle or nil-target errors")
end)

test("login Options Preview combat stop and repeated spec switches keep listeners and bindings bounded", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 94, chargeDuration = 20 })
    local function snapshot(stage)
        local report = addon:GetRuntimeLoadDiagnostics()
        equal(report.activeSkills, 1, stage .. " tracks only effective skill")
        truthy(report.activeBindings <= 1, stage .. " has at most one active timer")
        equal(report.pendingTasks, 0, stage .. " has no resident scanning task")
        print("OFFLINE-LIFECYCLE " .. stage .. ": events=" .. report.events.events .. ", callbacks=" .. report.events.callbacks
            .. ", activeSkills=" .. report.activeSkills .. ", bindings=" .. report.activeBindings .. "/" .. report.allocatedBindings
            .. ", cachedFrames=" .. report.liveFrames .. "/" .. report.previewFrames)
        return report
    end
    snapshot("login")
    local panel = options(addon); snapshot("Options")
    addon:SetPreview("all"); equal(snapshot("Preview").activeBindings, 0, "matching preview suspends timer display only")
    syncEvent(state, "PLAYER_REGEN_DISABLED"); equal(snapshot("combat").activeBindings, 1, "combat ends preview and retains live")
    syncEvent(state, "PLAYER_REGEN_ENABLED"); addon:StopPreview(); snapshot("Stop Preview")
    local function cycle()
        for _, spec in ipairs({ 62, 64, 63 }) do
            state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
            equal(addon.previewState.mode, "off", "switch removes old samples")
            addon:SetPreview("all"); addon:StopPreview()
        end
    end
    cycle()
    local warmed, resources = snapshot("all scopes warmed"), resourceCounts(state)
    for _ = 1, 12 do cycle() end
    local final = snapshot("36 further spec switches")
    equal(final.events.callbacks, warmed.events.callbacks, "callbacks never accumulate")
    equal(final.events.events, warmed.events.events, "native subscriptions never accumulate")
    equal(final.allocatedBindings, warmed.allocatedBindings, "native bindings remain bounded after every visited spec")
    same(resourceCounts(state), resources, "repeated switching reuses frames fonts textures and animations")
    equal(state.moduleLoads, 1, "native code loads once across all switches")
    panel:Hide(); equal(snapshot("Options closed").activeBindings, 1, "closing Options preserves live timer")
end)

test("runtime CPU and memory diagnostics sample only on demand and disclose unavailable profiling", function()
    local env, addon, state = login(nil, false, { classToken = "UNKNOWN", specID = false })
    local memoryReads, cpuReads, updates = {}, {}, 0
    env.UpdateAddOnMemoryUsage = function() updates = updates + 1 end
    env.GetAddOnMemoryUsage = function(name) memoryReads[#memoryReads + 1] = name; return 123.5 end
    env.C_CVar = { GetCVarBool = function() return false end }
    env.GetAddOnCPUUsage = function(name) cpuReads[#cpuReads + 1] = name; return 8.25 end
    options(addon)
    equal(updates, 0, "opening Options does not poll performance")
    addon:GetRuntimeLoadDiagnostics(); equal(updates, 0, "structural status does not sample CPU or memory")
    local text = addon:GetLoadDiagnosticsText()
    equal(updates, 1, "explicit diagnostic snapshot samples memory once")
    same(memoryReads, { "CarGOUI" }, "unloaded Mage does not get performance query")
    equal(#cpuReads, 0, "disabled profiling never fabricates CPU reading")
    truthy(text:find("unavailable (scriptProfile disabled)", 1, true), "unavailable CPU is explicit")
    env.C_CVar.GetCVarBool = function() return true end
    local cpuUpdates = 0
    env.UpdateAddOnCPUUsage = function() cpuUpdates = cpuUpdates + 1 end
    text = addon:GetLoadDiagnosticsText()
    equal(cpuUpdates, 1, "enabled profiling sampled only on request")
    equal(#cpuReads, 1, "one loaded core measured")
    truthy(text:find("123.5", 1, true) and text:find("8.25", 1, true), "mock measurements exercise client API plumbing only")
    for _, frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"), nil, "no performance polling frame") end
end)

test("live runtime sources contain no polling cast-count inference or timer text readback", function()
    local inspected = { root .. "/Modules/Mobility/Runtime.lua", root .. "/Core/Modules.lua" }
    for _, path in ipairs(dataFiles) do inspected[#inspected + 1] = moduleRoot .. "/" .. path end
    for _, path in ipairs(inspected) do
        local file = assert(io.open(path, "r"))
        local source = file:read("*a"); file:close()
        for _, forbidden in ipairs({ "NewTicker", '"OnUpdate"', "COMBAT_LOG_EVENT_UNFILTERED",
            "UNIT_SPELLCAST_SUCCEEDED", ":GetText(", ":GetStringWidth(", ":GetStringHeight(",
            ":GetRemainingDuration(", ":GetTotalDuration(", ":GetAlpha(", "GetSpellCastCount", "IsSpellUsable", "UnitAura" }) do
            truthy(not source:find(forbidden, 1, true), path .. " must not use " .. forbidden)
        end
    end
    local file = assert(io.open(root .. "/UI/Display.lua", "r"))
    local source = file:read("*a"); file:close()
    local live = assert(source:match("function addon:RenderLiveMobility(.*)"), "live renderer exists")
    for _, forbidden in ipairs({ ":GetText(", ":GetStringWidth(", ":GetStringHeight(", ":GetAlpha(", "GetRemainingDuration", "string.format" }) do
        truthy(not live:find(forbidden, 1, true), "native live rendering must not use " .. forbidden)
    end
end)

test("empty editor and diagnostic backgrounds release dragging without consuming normal control actions", function()
    local _, addon, state = login()
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility")
    local editor = panel.appearanceScroll.scrollChild
    editor:GetScript("OnDragStart")(editor, "LeftButton")
    equal(state.movingFrame, panel, "blank editor moves containing Options")
    panel.mockCenter = { (960 + 83) / panel:GetScale(), (540 - 27) / panel:GetScale() }
    editor:Hide()
    equal(state.movingFrame, nil, "hiding active drag surface cannot leave movement latched")
    equal(addon.db.options.position.x, 83, "empty editor drag saves window offset")
    editor:Show(); panel.mockCenter = nil
    enter(controls.appearanceFontSize.editBox, "35")
    equal(addon:GetMobilityConfig().style.font.size, 35, "Enter still edits font after background drag")
    dragValue(controls.appearanceScale, 1.25)
    equal(addon:GetMobilityConfig().style.scale, 1.25, "slider drag retains slider semantics")
    choose(controls.appearanceOutline, "THICKOUTLINE")
    equal(addon:GetMobilityConfig().style.font.outline, "THICKOUTLINE", "dropdown remains functional")
    equal(state.movingFrame, nil, "interactive edits never start window movement")
    addon:ShowMobilityDiagnostics()
    local dialog = panel.diagnosticsFrame
    dialog:GetScript("OnDragStart")(dialog, "LeftButton")
    equal(state.movingFrame, panel, "blank dialog background drags same Options root")
    dialog:GetScript("OnMouseUp")(dialog, "LeftButton")
    dialog.selectAll:Click()
    truthy(dialog.editBox.highlight, "diagnostic text selection still works")
    dialog.close:Click()
    equal(state.movingFrame, nil, "dialog close leaves no drag capture")
end)

test("faction Header and specialization Body update independently and keep scoped configuration untouched", function()
    local _, addon, state = login(nil, false, { specID = 62, faction = "Alliance" })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    local saved = copy(addon.db)
    local header = panel.theme.header.gradient
    local brand = panel.brandingHeader.sweep.vertexColor
    local body = panel.theme.body.gradient
    state.specID = 63; addon:RefreshOptionsTheme()
    equal(panel.theme.header.gradient, header, "changing spec does not rewrite Header gradient")
    equal(panel.brandingHeader.sweep.vertexColor, brand, "changing spec does not rewrite faction brand emphasis")
    truthy(panel.theme.body.gradient ~= body, "changing spec refreshes Body palette")
    equal(panel.theme.bodyKey, "fire", "Fire Body selected independently")
    local fire = panel.theme.body.gradient
    local input = controls.mobilityX.editBox.optionsThemeRecord.fill.color
    state.faction = "Horde"; addon:RefreshOptionsTheme()
    equal(panel.theme.body.gradient, fire, "changing faction does not rewrite Body gradient")
    equal(controls.mobilityX.editBox.optionsThemeRecord.fill.color, input, "changing faction does not rewrite input body skin")
    equal(panel.theme.headerKey, "horde", "Horde Header selected automatically")
    truthy(panel.theme.header.gradient.first[1] > panel.theme.header.gradient.first[3], "Horde Header remains red")
    truthy(panel.theme.header.gradient.last[1] > panel.theme.header.gradient.last[3], "both faction gradient endpoints are red")
    for _, rgb in ipairs({ panel.theme.body.gradient.first, panel.theme.body.gradient.last, input }) do
        truthy(math.max(rgb[1], rgb[2], rgb[3]) < 0.30, "Body surfaces stay dark for readable text")
    end
    same(addon.db, saved, "decorative changes never write shell or scoped reminder settings")
    equal(panel.brandingHeader.wordmark.vertexColor, nil, "base logo keeps original blue/gold artwork")
end)

test("Arcane Fire and Frost Body watermarks use distinct native endpoint geometry with one bounded Line pool", function()
    local _, addon, state = login(nil, false, { specID = 62 })
    local panel = options(addon)
    local resources = resourceCounts(state)
    local lines, counts, signatures = {}, {}, {}
    equal(#panel.theme.motif, 64, "one bounded static watermark Line pool")
    equal(panel.theme.watermarkSize, 200, "watermark remains a restrained body decoration")
    for i, line in ipairs(panel.theme.motif) do lines[i] = line end
    for _, spec in ipairs({ 62, 63, 64, 62, 64, 63 }) do
        state.specID = spec; addon:RefreshOptionsTheme()
        local pieces, visible = {}, 0
        for i, line in ipairs(panel.theme.motif) do
            equal(line, lines[i], "specializations reuse the same native Line objects")
            equal(line.kind, "Line", "watermark uses endpoint geometry, not rotated texture coordinates")
            equal(line.layer, "BACKGROUND", "watermark stays below interactive controls and text")
            equal(line.sublevel, 3, "watermark stays above Body fill")
            equal(line.parent, panel, "watermark adds no mouse-intercepting overlay frame")
            if line:IsShown() then
                visible = visible + 1
                equal(line.color[4], 0.16 * .55, "cropped watermark has reduced fixed opacity")
                for _, point in ipairs({ line.startPoint, line.endPoint }) do
                    equal(point[1], "BOTTOMRIGHT", "native endpoint uses stable panel anchor")
                    equal(point[2], panel, "native endpoint is relative to Options")
                    truthy(point[3] >= -300.000001 and point[3] <= -23.999999
                        and point[4] >= 79.999999 and point[4] <= 310.000001,
                        "both endpoints fit the quiet background crop")
                end
                truthy(line.startPoint[3] ~= line.endPoint[3] or line.startPoint[4] ~= line.endPoint[4], "native segment is non-degenerate")
                truthy(line.thickness == 2 or line.thickness == 3, "watermark has restrained line thickness")
                equal(line.rotation, nil, "Line geometry never depends on texture rotation")
                pieces[#pieces + 1] = table.concat({ line.startPoint[3], line.startPoint[4], line.endPoint[3], line.endPoint[4], line.thickness }, ":")
            end
        end
        counts[spec] = visible; signatures[spec] = table.concat(pieces, ";")
        equal(panel.theme.motifVisibleCount, visible, "reported visible count matches clipped strokes")
    end
    for spec, total in pairs({ [62] = 60, [63] = 27, [64] = 36 }) do
        truthy(counts[spec] > 0 and counts[spec] < total, "only part of each class/spec motif remains visible")
    end
    truthy(signatures[62] ~= signatures[63] and signatures[63] ~= signatures[64] and signatures[62] ~= signatures[64],
        "each specialization has different geometry, not merely a color swap")
    same(resourceCounts(state), resources, "theme-only updates allocate no extra lines textures frames fonts or animations")
    panel:Hide()
    local gradients, reads = state.gradientWrites, state.factionReads
    state.specID = 62; addon:RefreshOptionsTheme()
    equal(state.gradientWrites, gradients, "hidden watermark does not update")
    equal(state.factionReads, reads, "hidden theme performs no identity refresh")
end)

-- Independent Retail 12.1 build 69933 roster fixture, not generated from theme
-- implementation tables. Blizzard SPEC_FORMAT_STRINGS at pinned UI commit:
-- 09b9db7948abc9b9648dedaab51eb0cf3ee67b31 / Blizzard_ClassSpecializationsFrame.lua.
local themeRoster = {
    { "WARRIOR", { {71,"Arms"}, {72,"Fury"}, {73,"Protection"} } },
    { "PALADIN", { {65,"Holy"}, {66,"Protection"}, {70,"Retribution"} } },
    { "HUNTER", { {253,"Beast Mastery"}, {254,"Marksmanship"}, {255,"Survival"} } },
    { "ROGUE", { {259,"Assassination"}, {260,"Outlaw"}, {261,"Subtlety"} } },
    { "PRIEST", { {256,"Discipline"}, {257,"Holy"}, {258,"Shadow"} } },
    { "DEATHKNIGHT", { {250,"Blood"}, {251,"Frost"}, {252,"Unholy"} } },
    { "SHAMAN", { {262,"Elemental"}, {263,"Enhancement"}, {264,"Restoration"} } },
    { "MAGE", { {62,"Arcane"}, {63,"Fire"}, {64,"Frost"} } },
    { "WARLOCK", { {265,"Affliction"}, {266,"Demonology"}, {267,"Destruction"} } },
    { "MONK", { {268,"Brewmaster"}, {269,"Windwalker"}, {270,"Mistweaver"} } },
    { "DRUID", { {102,"Balance"}, {103,"Feral"}, {104,"Guardian"}, {105,"Restoration"} } },
    { "DEMONHUNTER", { {577,"Havoc"}, {581,"Vengeance"}, {1480,"Devourer"} } },
    { "EVOKER", { {1467,"Devastation"}, {1468,"Preservation"}, {1473,"Augmentation"} } },
}

local function motifFingerprint(segments)
    local first, second = 0, 0
    for _, segment in ipairs(segments) do
        for field = 1, 5 do
            local number = math.floor(segment[field] * 1000000 + 0.5)
            first = (first * 131 + number) % 2147483647
            second = (second * 257 + number) % 2147483629
        end
    end
    return #segments .. ":" .. first .. ":" .. second
end

test("all 13 classes and 40 independently verified specializations have class-qualified Body themes", function()
    local _, addon, state = login(nil, false, { classToken = "WARRIOR", specID = 71 })
    local panel = options(addon)
    local header, count, seenIDs = panel.theme.header.gradient, 0, {}
    equal(countKeys(addon.optionThemeClasses), 13, "complete current class roster with no invented classes")
    for _, row in ipairs(themeRoster) do
        local token, specs = row[1], row[2]
        local map = assert(addon.optionThemeClasses[token], "Missing class Body definition " .. token)
        equal(countKeys(map.specs), #specs, "exact verified spec count for " .. token)
        for _, spec in ipairs(specs) do
            local definition = assert(map.specs[spec[1]], "Missing independently verified spec " .. spec[1])
            equal(definition.label, spec[2], "spec identity from pinned roster")
            truthy(not seenIDs[spec[1]], "spec ID belongs to exactly one class")
            seenIDs[spec[1]], count = token, count + 1
            truthy(addon.optionBodyThemes[definition.key], "mapped Body palette exists")
            state.classToken, state.specID = token, spec[1]
            addon:RefreshOptionsTheme()
            local info = addon:GetAutomaticThemeInfo()
            equal(info.classToken, token, "class identity resolved")
            equal(info.specID, spec[1], "numeric spec identity resolved")
            equal(info.specialization, spec[2], "automatic labels use correct class/spec name")
            equal(info.bodyKey, definition.key, "current class-qualified Body selected")
            equal(info.coverage, "specialization", "supported theme is not reported as fallback")
            equal(info.fallback, nil, "known Alliance class/spec has no fallback reason")
            equal(panel.theme.header.gradient, header, "same faction Header stays unchanged through all 40 specs")
        end
    end
    equal(count, 40, "complete independently verified specialization roster")
    equal(seenIDs[1480], "DEMONHUNTER", "Devourer is mapped to Demon Hunter")
end)

test("each class has distinct spec palette and bounded non-degenerate watermark geometry", function()
    local _, addon = login(nil, false, { classToken = "WARRIOR", specID = 71 })
    for _, row in ipairs(themeRoster) do
        local palettes, geometries, keys = {}, {}, {}
        for _, spec in ipairs(row[2]) do
            local key = addon.optionThemeClasses[row[1]].specs[spec[1]].key
            local body = addon.optionBodyThemes[key]
            truthy(not keys[key], "same-class specs do not share a Body definition")
            keys[key] = true
            local colors = {}
            for _, field in ipairs({ "background", "left", "right", "accent", "input", "button" }) do
                local rgb = body[field]
                equal(#rgb, 3, "palette uses RGB triplets")
                for _, value in ipairs(rgb) do
                    truthy(type(value) == "number" and value == value and value >= 0 and value <= 1, "palette channels remain valid")
                    colors[#colors + 1] = value
                end
            end
            local signature = table.concat(colors, ":")
            truthy(not palettes[signature], "same-class specs are not identical color palettes")
            palettes[signature] = true
            local motif = addon:BuildOptionsThemeMotif(body.motif)
            truthy(#motif > 0 and #motif <= 64, "known specialization has a bounded explicit motif")
            for _, segment in ipairs(motif) do
                equal(#segment, 5, "native Line segment consists of two endpoints and thickness")
                for i = 1, 4 do truthy(math.abs(segment[i]) <= 100, "motif remains inside its 200px area") end
                truthy(segment[1] ~= segment[3] or segment[2] ~= segment[4], "no zero-length decorative segment")
                truthy(segment[5] > 0 and segment[5] <= 5, "restrained positive stroke thickness")
            end
            local fingerprint = motifFingerprint(motif)
            truthy(not geometries[fingerprint], "same-class specialization motifs differ in geometry, not just tint")
            geometries[fingerprint] = true
        end
    end
end)

test("all classes have automatic no-spec and unmapped-spec fallbacks without borrowing another class", function()
    local _, addon, state = login(nil, false, { classToken = "WARRIOR", specID = 71 })
    local panel = options(addon)
    local classKeys = {}
    for _, row in ipairs(themeRoster) do
        local token = row[1]
        local base = addon.optionThemeClasses[token].key
        truthy(base ~= "neutral" and not classKeys[base], "each known class owns an explicit base Body")
        classKeys[base] = true
        state.classToken, state.specID = token, nil
        addon:RefreshOptionsTheme()
        local info = addon:GetAutomaticThemeInfo()
        equal(info.bodyKey, base, "no spec uses own class theme")
        equal(info.coverage, "class fallback", "no spec fallback is explicit")
        equal(info.specialization, "Not selected", "no spec does not claim a specialization")
        truthy(info.fallback, "no-spec fallback reason supplied")
        state.specID = 9999; addon:RefreshOptionsTheme()
        info = addon:GetAutomaticThemeInfo()
        equal(info.bodyKey, base, "unknown spec cannot borrow a known theme")
        equal(info.coverage, "unmapped specialization", "unmapped spec is reported distinctly")
        state.specID = token == "MAGE" and 71 or 62; addon:RefreshOptionsTheme()
        equal(addon:GetAutomaticThemeInfo().bodyKey, base, "a valid spec of another class must not match")
    end
    state.classToken, state.specID = "UNKNOWN", 62; addon:RefreshOptionsTheme()
    equal(addon:GetAutomaticThemeInfo().bodyKey, "neutral", "unknown class uses neutral even with valid Mage spec ID")
    equal(panel.theme.motifCount, 0, "neutral fallback clears old spec watermark")
    for _, line in ipairs(panel.theme.motif) do equal(line:IsShown(), false, "neutral fallback has no residual strokes") end
    state.classToken, state.specID = secret("MAGE"), secret(62); addon:RefreshOptionsTheme()
    equal(addon:GetAutomaticThemeInfo().bodyKey, "neutral", "opaque identity safely selects neutral")
end)

test("all-class Body themes work without gameplay adapters or cooldown queries and do not write configuration", function()
    for _, row in ipairs(themeRoster) do
        local token, first = row[1], row[2][1]
        local _, addon, state = login(nil, false, { classToken = token, specID = first[1] })
        local initialLoads = state.moduleLoads
        options(addon)
        equal(state.moduleLoads, initialLoads, "theme coverage never causes another gameplay module to load")
        local saved, spellReads = copy(addon.db), copy(state.spellReads)
        local before = addon:GetRuntimeLoadDiagnostics()
        for _, spec in ipairs(row[2]) do
            state.specID = spec[1]; addon:RefreshOptionsTheme()
            equal(addon:GetAutomaticThemeInfo().coverage, "specialization", "theme available regardless of adapter support")
        end
        same(addon.db, saved, "theme-only updates do not write or initialize additional configuration")
        same(state.spellReads, spellReads, "theme-only updates do not query cooldown or charge state")
        equal(state.realReads, 0, "decorative themes never call live buff/cooldown APIs")
        local after = addon:GetRuntimeLoadDiagnostics()
        equal(after.allocatedBindings, before.allocatedBindings, "theme coverage creates no native cooldown binding")
        equal(after.liveFrames + after.previewFrames, 0, "opening unsupported or unlearned themes creates no reminders")
        if token ~= "MAGE" then
            equal(after.modules.activeAdapterClass, token, "theme preserves the registry selection made at login")
            equal(addon.db.classes.MAGE, nil, "non-Mage theme does not instantiate Mage configuration")
        end
    end
end)

test("visible identity recovery and disabled or unlearned Mobility do not block theme selection", function()
    local _, addon, state = login(nil, false, { classToken = "UNKNOWN", specID = false })
    local panel = options(addon)
    local saved = copy(addon.db)
    equal(addon:GetAutomaticThemeInfo().bodyKey, "neutral", "initial unavailable identity uses neutral")
    state.classToken, state.specID = "SHAMAN", 262
    state:fire("SPELLS_CHANGED")
    equal(addon:GetAutomaticThemeInfo().specialization, "Elemental", "visible spell-data event resolves newly available identity")
    state.specID = nil; state:fire("PLAYER_TALENT_UPDATE")
    equal(addon:GetAutomaticThemeInfo().coverage, "class fallback", "temporary no-spec state uses own class fallback")
    state.specID = 264; state:fire("PLAYER_TALENT_UPDATE")
    equal(addon:GetAutomaticThemeInfo().specialization, "Restoration", "visible talent event recovers current spec")
    same(addon.db, saved, "identity-only theme recovery leaves configuration untouched")
    equal(state.moduleLoads, 0, "identity-only recovery never loads gameplay code")
    equal(state.realReads, 0, "identity recovery never queries buffs or cooldowns")
    panel:Hide()
    local reads, gradients = state.factionReads, state.gradientWrites
    state.specID = 263; state:fire("SPELLS_CHANGED"); state:fire("PLAYER_TALENT_UPDATE")
    equal(state.factionReads, reads, "hidden identity recovery events perform no decoration lookup")
    equal(state.gradientWrites, gradients, "hidden identity recovery events perform no redraw")
    addon:ToggleOptions()
    equal(addon:GetAutomaticThemeInfo().specialization, "Enhancement", "reopening freshly resolves current identity")
    local _, mage, ms = login({ mobility = { enabled = false } }, false, { specID = 62 })
    options(mage)
    equal(mage:GetAutomaticThemeInfo().bodyKey, "arcane", "disabled Mobility cannot disable Arcane Options theme")
    ms.specID = 64; ms:fire("SPELLS_CHANGED")
    equal(mage:GetAutomaticThemeInfo().bodyKey, "frost", "unlearned disabled Mage still responds to theme identity events")
    equal(mage:GetRuntimeLoadDiagnostics().allocatedBindings, 0, "no timer is created for disabled/unlearned Mobility")
    equal(ms.realReads, 0, "disabled theme path does not read skill cooldowns")
end)

test("repeated full-roster theme cycles reuse 64 Lines and leave no stale motifs listeners or gameplay state", function()
    local _, addon, state = login(nil, false, { classToken = "WARRIOR", specID = 71 })
    local idleEvents = addon:GetEventDiagnostics()
    local panel = options(addon)
    local resources, events, saved = resourceCounts(state), addon:GetEventDiagnostics(), copy(addon.db)
    local lines = {}; for i, line in ipairs(panel.theme.motif) do lines[i] = line end
    local header, initialLoads = panel.theme.header.gradient, state.moduleLoads
    for _ = 1, 4 do
        for _, row in ipairs(themeRoster) do
            for _, spec in ipairs(row[2]) do
                state.classToken, state.specID = row[1], spec[1]
                addon:RefreshOptionsTheme()
                local expected = #addon:BuildOptionsThemeMotif(addon.optionBodyThemes[addon:GetAutomaticThemeInfo().bodyKey].motif)
                equal(panel.theme.motifCount, expected, "new motif owns exact active stroke count")
                local visible = 0
                for i, line in ipairs(panel.theme.motif) do
                    equal(line, lines[i], "every class reuses native Line pool")
                    if i > expected then equal(line:IsShown(), false, "unused old strokes stay hidden") end
                    if line:IsShown() then visible = visible + 1 end
                end
                equal(visible, panel.theme.motifVisibleCount, "reported crop matches visible pool members")
                equal(panel.theme.header.gradient, header, "Body cycling preserves same-faction Header object")
            end
        end
    end
    same(resourceCounts(state), resources, "160 theme transitions allocate no extra objects")
    same(addon:GetEventDiagnostics(), events, "theme refresh cannot accumulate identity listeners")
    same(addon.db, saved, "full-roster Body transitions never write saved settings")
    equal(state.moduleLoads, initialLoads, "theme cycling never causes another gameplay package load")
    equal(state.realReads, 0, "theme cycling never reads gameplay state")
    panel:Hide()
    same(addon:GetEventDiagnostics(), idleEvents, "closing removes all theme listeners and restores idle ownership")
    for _ = 1, 8 do addon:ToggleOptions(); panel:Hide() end
    same(resourceCounts(state), resources, "reopening known UI reuses all theme objects")
    same(addon:GetEventDiagnostics(), idleEvents, "repeated reopen/close leaves no hidden identity watcher")
end)

test("Mage Body palettes and all watermark endpoints exactly retain the accepted alpha-9 baseline", function()
    local _, addon = login()
    local palettes = {
        arcane = { background = {0.043,0.025,0.067}, left = {0.064,0.031,0.11}, right = {0.17,0.078,0.245},
            accent = {0.73,0.49,0.98}, input = {0.035,0.021,0.060}, button = {0.12,0.064,0.18} },
        fire = { background = {0.070,0.027,0.018}, left = {0.12,0.034,0.019}, right = {0.245,0.13,0.047},
            accent = {1,0.62,0.27}, input = {0.057,0.025,0.019}, button = {0.18,0.082,0.032} },
        frost = { background = {0.018,0.039,0.070}, left = {0.026,0.062,0.14}, right = {0.055,0.18,0.23},
            accent = {0.43,0.84,1}, input = {0.018,0.031,0.058}, button = {0.042,0.105,0.16} },
    }
    -- Dual rolling fingerprints calculated from git e033af9, six-decimal
    -- integer endpoint/thickness values; they do not inspect current UI output.
    local geometry = { arcane = "60:1027259727:123858337", fire = "27:1877310240:1128453855", frost = "36:584702318:1618801814" }
    for key, fields in pairs(palettes) do
        for field, expected in pairs(fields) do same(addon.optionBodyThemes[key][field], expected, "accepted Mage palette " .. key .. "/" .. field) end
        equal(motifFingerprint(addon:BuildOptionsThemeMotif(key)), geometry[key], "accepted Mage geometry " .. key)
    end
end)

-- Generic-engine fixtures are deliberately synthetic. Their explicit metadata
-- tests the native API contract, not the actual semantics of any real ability.
local function genericEngine(item, client)
    client = client or {}
    local enterCombat = client.inCombat
    client.inCombat = false
    client.classToken, client.specID = "UNKNOWN", false
    client.allowedSpellIDs = { [987001] = true, [987002] = true }
    client.mobility = { known = {}, spells = { [987001] = item } }
    client.baseCooldowns = client.baseCooldowns or { [987001] = { 1000, 1500 } }
    local env, addon, state = login(nil, false, client)
    truthy(env.C_AddOns.LoadAddOn("CarGOUI_Data"), "load engine without activating any gameplay adapter")
    if enterCombat then state:fire("PLAYER_REGEN_DISABLED") end
    local entry = { id = "offline_engine", class = "UNKNOWN", kind = "mobility", anchor = { x = 0, y = 0 } }
    return state.moduleNamespaces.CarGOUI_Data, entry, { spellID = 987001, spellName = "Offline fixture" }, addon, state, env
end

local function textFor(addon, id)
    local frame = addon.reminderFrames.live and addon.reminderFrames.live[id]
    if not frame or not frame:IsVisible() or nativeValue(frame.alpha) == 0 then return "" end
    return frame.text.nativeRenderedText or ""
end

test("generic engine uses actual public charge capacity and first recovery without learning or usability inference", function()
    for _, capacity in ipairs({ 1, 2, 3, 5 }) do
        local item = { charges = capacity, maxCharges = capacity, chargeStart = 91, chargeDuration = 23 }
        local engine, entry, definition, _, state = genericEngine(item)
        equal(engine:ReadAbilityState(entry, definition).status, "Ready", "capacity comes from current API")
        item.charges = 1
        equal(engine:ReadAbilityState(entry, definition).status, "Ready", "any available charge is enough")
        item.charges = 0
        local result = engine:ReadAbilityState(entry, definition)
        equal(result.status, "Depleted", "zero actual charges confirms depletion")
        truthy(result.duration, "zero uses binds real ongoing charge timer")
        local binding = state.moduleNamespaces.CarGOUI_Data.host:AcquireReminderFrame(entry, "live")
        engine.host:RenderLiveMobility(entry, definition.spellName, result.duration, result.visibility, definition.spellID)
        state:nativeTick()
        equal(textFor(engine.host, entry.id), "No Offline fixture\n14.0", "recharge already started nine seconds ago")
        item.charges = 1
        local recovered = engine:ReadAbilityState(entry, definition)
        equal(recovered.status, "Ready", "first recovery is immediately ready")
        equal(recovered.duration, nil, "no timer retained until full recharge")
        equal(#state.knownReads + #state.overrideReads, 0, "engine never selects learned or replacement candidates")
        truthy(binding.durationBinding, "native formatter used rather than restricted string formatting")
    end
end)

test("generic secret charges distinguish one-slot recovery and blocked unaudited multiple-slot visibility", function()
    local item = { charges = 0, maxCharges = 1, chargeStart = 96, chargeDuration = 15,
        secretCharges = true, secretDuration = true }
    local engine, entry, definition, _, state = genericEngine(item, { inCombat = true })
    local result = engine:ReadAbilityState(entry, definition)
    equal(result.status, "Depleted", "public active single-slot recovery proves empty slot")
    truthy(result.duration, "secret remaining duration stays in native handle")
    item.maxCharges = 2
    result = engine:ReadAbilityState(entry, definition)
    equal(result.status, "Restricted", "multiple secret charges require per-ability semantic audit")
    equal(result.path, "blocked: native charge visibility", "blocker precisely distinguishes missing visibility gate")
    equal(result.duration, nil, "restricted path does not fabricate depletion")
    equal(#state.curves, 0, "no universal Mage threshold borrowed")
    item.active = false
    equal(engine:ReadAbilityState(entry, definition).status, "Unknown", "inactive recharge with secret count is not falsely Ready")
    item.active, item.secretCapacity = true, true
    equal(engine:ReadAbilityState(entry, definition).status, "Restricted", "secret capacity is never branched on")
    item.secretCapacity, item.secretActivity = false, true
    equal(engine:ReadAbilityState(entry, definition).status, "Restricted", "secret activity is never branched on")
end)

test("generic audited fixture keeps native visibility separate from existing recharge and never reads secret alpha", function()
    local item = { charges = 1, maxCharges = 2, chargeStart = 93, chargeDuration = 20,
        cooldownStart = 100, cooldownDuration = 1, secretCharges = true, secretDuration = true }
    local engine, entry, definition, addon, state = genericEngine(item)
    definition.chargeVisibility = { baseCooldownMS = 1000, baseGCDMS = 1500,
        boundaryMS = 1000, ignoreGCD = true, audit = "Offline contract fixture, not a shipped spell audit" }
    for _, step in ipairs({ { 1, 1, "" }, { 0, 20, "No Offline fixture\n13.0" }, { 1, 1, "" } }) do
        item.charges, item.cooldownDuration = step[1], step[2]
        local result = engine:ReadAbilityState(entry, definition)
        equal(result.status, "Native tracking", "Lua does not claim native final Ready/Depleted")
        truthy(result.duration ~= result.visibility.duration, "separate native objects have different responsibilities")
        addon:RenderLiveMobility(entry, definition.spellName, result.duration, result.visibility, definition.spellID)
        state:nativeTick()
        equal(textFor(addon, entry.id), step[3], "native display alone evaluates opacity")
        truthy(isSecret(addon.reminderFrames.live[entry.id].alpha), "secret curve result reaches allowed SetAlpha sink")
    end
    equal(#state.curves, 1, "same explicit ability boundary reuses one curve")
    state.baseCooldowns[987001] = { 1500, 1500 }
    local mismatch = engine:ReadAbilityState(entry, definition)
    equal(mismatch.status, "Restricted", "previously cached gate cannot bypass changed public metadata")
    equal(mismatch.duration, nil, "cached classifier cannot claim current validity")
    state.baseCooldowns[987001] = { 1000, 1500 }
    equal(state.alphaReads + state.liveMeasurements, 0, "no opacity readback or restricted text measurement")
    for _, query in ipairs(state.spellReads) do
        truthy(query.api ~= "cooldown-duration-visibility", "generic fixture explicitly removes GCD in visibility purpose")
    end
    engine:ClearAbilityStateCache()
    engine:ReadAbilityState(entry, definition)
    equal(#state.curves, 2, "deactivation can release old per-ability curve cache")
end)

test("generic visibility audit rejects mismatched incomplete and opaque public metadata without timer guesses", function()
    local item = { charges = 0, maxCharges = 2, chargeStart = 90, chargeDuration = 20,
        secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = 20 }
    local engine, entry, definition, _, state = genericEngine(item)
    local valid = { baseCooldownMS = 1000, baseGCDMS = 1500, boundaryMS = 1000, ignoreGCD = true, audit = "Offline fixture" }
    for _, patch in ipairs({ { audit = "" }, { baseCooldownMS = 500 }, { baseGCDMS = 0 },
        { boundaryMS = 999 }, { ignoreGCD = false }, { boundaryMS = secret(1000) } }) do
        definition.chargeVisibility = copy(valid)
        for k, v in pairs(patch) do definition.chargeVisibility[k] = v end
        local result = engine:ReadAbilityState(entry, definition)
        equal(result.status, "Restricted", "invalid public per-ability evidence stays explicitly blocked")
        equal(result.duration, nil, "cannot treat active recharge as depletion")
    end
    definition.chargeVisibility = valid
    state.baseCooldowns[987001] = { secret(1000), 1500 }
    equal(engine:ReadAbilityState(entry, definition).status, "Restricted", "secret metadata does not enter arithmetic")
    equal(#state.curves, 0, "invalid evidence never creates a classifier")
end)

test("generic ordinary cooldowns exclude GCD and allow native secret zero expiry without raw timing reads", function()
    local item = { cooldownStart = 100, cooldownDuration = 1.5, isOnGCD = true, secretDuration = true }
    local engine, entry, definition, addon, state = genericEngine(item)
    local result = engine:ReadAbilityState(entry, definition)
    equal(result.status, "Tracking", "opaque zero stays native tracking instead of Lua inferred Ready")
    addon:RenderLiveMobility(entry, definition.spellName, result.duration, result.visibility, definition.spellID)
    state:nativeTick()
    equal(textFor(addon, entry.id), "", "native ignoreGCD zero duration is invisible")
    item.isOnGCD, item.cooldownStart, item.cooldownDuration = false, 90, 18
    result = engine:ReadAbilityState(entry, definition)
    addon:RenderLiveMobility(entry, definition.spellName, result.duration, result.visibility, definition.spellID)
    state:nativeTick()
    equal(textFor(addon, entry.id), "No Offline fixture\n8.0", "ordinary native cooldown uses actual start")
    state:advance(9)
    equal(textFor(addon, entry.id), "", "native binding expires without Lua polling")
    local before = state.realReads
    definition.unsupportedReason = "Explicit offline unsupported mechanism"
    equal(engine:ReadAbilityState(entry, definition).status, "Unsupported", "unsupported mechanism honest diagnostic")
    equal(state.realReads, before, "explicit unsupported mechanism does not query cooldown state")
end)

local warriorIDs = { [100] = true, [6544] = true, [3411] = true, [385952] = true }
local function warriorLogin(spells, known, spec, saved)
    return login(saved, false, { classToken = "WARRIOR", specID = spec or 71,
        allowedSpellIDs = warriorIDs, mobility = { known = known or { [100] = true, [6544] = true, [3411] = true },
            overrides = {}, spells = spells } })
end

test("Warrior concurrent live abilities keep independent real timers and hiding one cannot clear another", function()
    local charge = { charges = 0, maxCharges = 2, chargeStart = 91, chargeDuration = 20 }
    local leap = { charges = 0, maxCharges = 1, chargeStart = 95, chargeDuration = 45, secretDuration = true }
    local intervene = { charges = 1, maxCharges = 1, chargeStart = 100, chargeDuration = 30 }
    local _, addon, state = warriorLogin({ [100] = charge, [6544] = leap, [3411] = intervene })
    state:nativeTick()
    equal(#addon:GetMobilityEntries(), 3, "three currently learned abilities, not one compatibility slot")
    equal(textFor(addon, "warrior_charge"), "No Charge\n11.0", "first ability next recovery")
    equal(textFor(addon, "warrior_heroic_leap"), "No Heroic Leap\n40.0", "second ability independent remaining")
    equal(textFor(addon, "warrior_intervene"), "", "available third ability absent")
    local leapFrame = addon.reminderFrames.live.warrior_heroic_leap
    local disables = leapFrame.durationBinding.disableCalls or 0
    charge.charges = 1; syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(textFor(addon, "warrior_charge"), "", "one restored charge immediately hides only Charge")
    equal(textFor(addon, "warrior_heroic_leap"), "No Heroic Leap\n40.0", "Leap remains independently live")
    equal(leapFrame.durationBinding.disableCalls or 0, disables, "another skill cannot detach Leap timer")
    state:advance(4)
    equal(textFor(addon, "warrior_heroic_leap"), "No Heroic Leap\n36.0", "still-existing native timer advances")
    intervene.charges, intervene.chargeStart = 0, 104
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(textFor(addon, "warrior_intervene"), "No Intervene\n30.0", "third skill can independently become depleted")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 2, "only two depleted abilities bind timers")
    local statuses = addon:GetMobilityStatuses()
    equal(#statuses, 3, "diagnostics report every active ability")
    equal(addon:GetMobilityStatus("warrior_charge").status, "Ready", "named diagnostic selects correct ready ability")
    for _, status in ipairs(statuses) do
        equal(status.duration, nil, "public diagnostics cannot expose opaque duration")
        equal(status.visibility, nil, "public diagnostics cannot expose native alpha classifier")
    end
end)

test("Warrior shared class styles preserve independent slot anchors and never reset opaque live bindings", function()
    local _, addon, state = warriorLogin({
        [100] = { charges = 0, maxCharges = 1, chargeStart = 93, chargeDuration = 20, secretCharges = true, secretDuration = true },
        [6544] = { charges = 0, maxCharges = 1, chargeStart = 94, chargeDuration = 45, secretCharges = true, secretDuration = true },
        [3411] = { charges = 1, maxCharges = 1 },
    })
    addon:UpdateSettings({ position = { x = 38, y = -17 } })
    local snapshots, reads = {}, state.realReads
    for _, entry in ipairs(addon:GetMobilityEntries()) do
        equal(entry.anchor.y, -84 * (entry.slot - 1), "stable slot supplies deterministic separated anchor")
        local frame = addon.reminderFrames.live[entry.id]
        if frame then snapshots[entry.id] = { frame.durationBinding.duration, frame.durationBinding.durationWrites, frame.alpha, frame.alphaWrites } end
    end
    addon:UpdateReminderStyle("mobility:WARRIOR", { font = { size = 39 }, scale = 1.4, shadow = { enabled = false } })
    equal(state.realReads, reads, "style-only editing never queries real cooldowns")
    for _, entry in ipairs(addon:GetMobilityEntries()) do
        local frame = addon.reminderFrames.live[entry.id]
        if frame then
            local before = snapshots[entry.id]
            equal(frame.durationBinding.duration, before[1], "same native duration handle")
            equal(frame.durationBinding.durationWrites, before[2], "no rebind from styling")
            equal(frame.alpha, before[3], "same native opacity")
            equal(frame.alphaWrites, before[4], "style does not override gate")
            equal(frame.text.font[2], 39, "all current class abilities use shared font")
            equal(frame.point[4] * frame:GetScale(), 38, "scale does not move shared X anchor")
            truthy(math.abs(frame.point[5] * frame:GetScale() - (-17 + entry.anchor.y)) < 0.000001,
                "scale does not multiply slot or saved Y twice")
        end
    end
    equal(addon.db.classes.MAGE, nil, "Warrior creates no Mage settings")
    local _, reload = warriorLogin(state.mobility.spells, nil, 72, copy(addon.db))
    equal(reload:GetMobilityConfig().style.font.size, 39, "another Warrior spec retains class style")
    equal(reload:GetMobilityConfig().position.x, 38, "another Warrior spec retains class position")
    local _, mage = mobilityLogin(1953, { charges = 1, maxCharges = 1 }, nil, copy(addon.db))
    same(mage:GetMobilityConfig().style, mage.factoryReminderStyle, "first Mage does not inherit Warrior style")
    equal(mage.db.classes.WARRIOR.mobility.style.font.size, 39, "returnable Warrior settings preserved")
end)

test("single-entry and all Preview leave unrelated live Mobility independent and closing restores current reality", function()
    local _, addon, state = warriorLogin({ [100] = { charges = 0, maxCharges = 1, chargeStart = 90, chargeDuration = 20 },
        [6544] = { charges = 0, maxCharges = 1, chargeStart = 90, chargeDuration = 45 }, [3411] = { charges = 1, maxCharges = 1 } })
    local panel = options(addon)
    truthy(addon:SetPreview("single", "warrior_charge"), "single current ability can be previewed")
    equal(textFor(addon, "warrior_charge"), "", "matching live suppressed")
    equal(textFor(addon, "warrior_heroic_leap"), "No Heroic Leap\n35.0", "other live reminder remains active during single preview")
    state:advance(3)
    truthy(addon:SetPreview("all"), "existing all-preview entrypoint supports all current abilities")
    equal(textFor(addon, "warrior_charge"), "", "all preview suppresses first real frame")
    equal(textFor(addon, "warrior_heroic_leap"), "", "all preview suppresses second real frame")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 0, "simulation has no live native binding")
    addon:StopPreview(); state:nativeTick()
    equal(textFor(addon, "warrior_charge"), "No Charge\n7.0", "stop requeries real first timer")
    equal(textFor(addon, "warrior_heroic_leap"), "No Heroic Leap\n32.0", "stop requeries separate second timer")
    panel:Hide(); syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 2, "closing Options cannot end real monitoring")
    equal(#state.errors, 0, "preview/live transition has no API errors")
end)

test("active-only cooldown refresh never reselects class candidates and learning-zero retains only identity watchers", function()
    local _, addon, state = warriorLogin({ [100] = { charges = 0, maxCharges = 1, chargeStart = 100, chargeDuration = 20 } }, {})
    equal(#addon:GetMobilityEntries(), 0, "zero learned skills means zero active entries")
    equal(addon.mobilityIdentityWatching, true, "learning can be discovered without polling")
    equal(addon.mobilityCooldownWatching, false, "no unrelated cooldown listeners")
    local report = addon:GetRuntimeLoadDiagnostics()
    equal(report.activeSkills + report.liveFrames + report.allocatedBindings, 0, "unlearned current class creates no timers or live frames")
    equal(state.realReads, 0, "zero learned skills means no cooldown queries")
    state.mobility.known[100] = true
    syncEvent(state, "SPELLS_CHANGED")
    equal(#addon:GetMobilityEntries(), 1, "learning event activates exactly newly learned skill")
    equal(addon.mobilityCooldownWatching, true, "cooldown listeners begin only with active skill")
    local known, overrides, firstQuery = #state.knownReads, #state.overrideReads, #state.spellReads
    local factoryCalls, originalFactory = 0, addon.activeClassAdapter.definitionFactory
    addon.activeClassAdapter.definitionFactory = function(spec)
        factoryCalls = factoryCalls + 1
        return originalFactory(spec)
    end
    for _ = 1, 8 do syncEvent(state, "SPELL_UPDATE_COOLDOWN") end
    equal(factoryCalls, 0, "normal refresh revalidates retained families without rebuilding full current-class catalog")
    for i = known + 1, #state.knownReads do
        equal(state.knownReads[i], 100, "normal cooldown updates may revalidate active learning but never scan inactive candidates")
    end
    for i = overrides + 1, #state.overrideReads do
        equal(state.overrideReads[i], 100, "temporary replacement checks may inspect active ID only, never inactive candidates")
    end
    for i = firstQuery + 1, #state.spellReads do equal(state.spellReads[i].id, 100, "only active ID is queried") end
    state.mobility.known[100] = nil
    syncEvent(state, "SPELLS_CHANGED")
    equal(addon.mobilityCooldownWatching, false, "unlearning final skill detaches runtime listeners")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 0, "unlearning final skill detaches duration")
    equal(addon.mobilityIdentityWatching, true, "identity watchers remain for future learning")
end)

test("Data diagnostics inventory exactly matches the loaded manifest rather than claiming hardcoded class coverage", function()
    local _, addon, state = login()
    same(addon.dataFileManifest, dataFiles, "reported code inventory exactly equals actual TOC order")
    local loaded = {}
    for _, path in ipairs(state.loadedFiles) do
        local item = path:match("^CarGOUI_Data/(.*)$")
        if item then loaded[#loaded + 1] = item end
    end
    same(loaded, dataFiles, "native mock actually executed every shipped business file once")
    equal(addon:GetModuleLoadReport().loadedClassFiles, classFileCount, "derived class-file inventory")
    equal(addon:GetModuleLoadReport().loadedDataFiles, #dataFiles, "derived code-file inventory")
    equal(countKeys(addon.db.classes), 1, "shipping definitions does not instantiate other saved class trees")
end)

local function includeDefinitionIDs(ids, definition)
    if definition.spellID then ids[definition.spellID] = true end
    if definition.baseSpellID then ids[definition.baseSpellID] = true end
    for _, key in ipairs({ "requiresKnown", "excludesKnown", "preferKnown" }) do
        for _, id in ipairs(definition[key] or {}) do ids[id] = true end
    end
    for id in pairs(definition.blockedIfKnown or {}) do ids[id] = true end
    for _, variant in ipairs(definition.variants or {}) do includeDefinitionIDs(ids, variant) end
end

local function definitionsFor(data, class, spec)
    local adapter = data.adapters[class]
    truthy(adapter, "actual registered adapter required for " .. class)
    local generic = class == "MAGE" and adapter.additionalMobility or adapter
    truthy(generic and generic.definitionFactory, "actual lazy definition factory required for " .. class)
    return generic.definitionFactory(spec)
end

-- Independent family checklist from the bounded feature scope, not generated
-- from the addon registry. This checks meaningful coverage before a count can
-- be reported. Mage Blink/Shimmer retain their separate acceptance regressions.
local mobilityFamilies = {
    WARRIOR = { "warrior_charge", "warrior_heroic_leap", "warrior_intervene" },
    PALADIN = { "paladin_divine_steed" }, HUNTER = { "hunter_disengage", "hunter_aspect_of_the_cheetah" },
    ROGUE = { "rogue_sprint", "rogue_shadowstep" }, PRIEST = { "priest_angelic_feather" },
    DEATHKNIGHT = { "deathknight_deaths_advance", "deathknight_wraith_walk" },
    SHAMAN = { "shaman_spirit_walk", "shaman_gust_of_wind", "shaman_wind_rush_totem" }, WARLOCK = { "warlock_demonic_circle_teleport" },
    MONK = { "monk_roll", "monk_transcendence_transfer", "monk_tigers_lust" },
    DRUID = { "druid_dash", "druid_wild_charge", "druid_stampeding_roar" },
    DEMONHUNTER = { "demonhunter_movement", "demonhunter_vengeful_retreat" },
    EVOKER = { "evoker_hover", "evoker_deep_breath", "evoker_verdant_embrace", "evoker_rescue" },
}
local specFamilies = { warrior_shield_charge = { [73] = true }, hunter_harpoon = { [255] = true },
    rogue_grappling_hook = { [260] = true }, shaman_feral_lunge = { [263] = true }, monk_flying_serpent_kick = { [269] = true },
    demonhunter_felblade = { [577] = true, [581] = true }, demonhunter_voidblade = { [1480] = true },
    demonhunter_the_hunt = { [577] = true, [1480] = true }, demonhunter_metamorphosis = { [577] = true },
    evoker_dream_flight = { [1468] = true } }

test("every shipped non-Mage class and specialization has concrete audited families and no unrelated spec instances", function()
    local engine, _, _, addon, state = genericEngine({})
    local classCount, specCount, variants = 0, 0, 0
    for _, row in ipairs(themeRoster) do
        local class = row[1]
        if class ~= "MAGE" then
            classCount = classCount + 1
            for _, spec in ipairs(row[2]) do
                specCount = specCount + 1
                local definitions, seen, slots = definitionsFor(engine, class, spec[1]), {}, {}
                for _, definition in ipairs(definitions) do
                    truthy(not seen[definition.id], "stable family IDs unique within current specialization")
                    seen[definition.id] = true
                    truthy(not slots[definition.slot], "simultaneous abilities have independent preset slots")
                    slots[definition.slot] = true
                    for _, variant in ipairs(definition.variants or { definition }) do
                        variants = variants + 1
                        truthy(type(variant.spellID) == "number" and variant.spellID > 0, "real public ID exists")
                        truthy(type(variant.spellName) == "string" and variant.spellName ~= "", "real public spell name exists")
                        equal(variant.audit.build, 69933, "individual definition records audited target build")
                        truthy(type(variant.audit.source) == "string" and variant.audit.source ~= "", "individual primary-data evidence recorded")
                        if not variant.unsupportedReason then
                            truthy(type(variant.audit.cooldownMS) == "number" and type(variant.audit.gcdMS) == "number",
                                "supported variant has distinct ordinary cooldown and GCD metadata")
                        end
                    end
                end
                for _, id in ipairs(mobilityFamilies[class]) do truthy(seen[id], class .. " common family " .. id) end
                for id, specs in pairs(specFamilies) do
                    equal(seen[id] == true, specs[spec[1]] == true, "only current spec instantiates exclusive family " .. id)
                end
            end
            local base = definitionsFor(engine, class, nil)
            local seen = {}; for _, definition in ipairs(base) do seen[definition.id] = true end
            for _, id in ipairs(mobilityFamilies[class]) do truthy(seen[id], "unselected spec retains class-common family") end
            for id in pairs(specFamilies) do equal(seen[id], nil, "low-level unspecialized never instantiates spec-exclusive family") end
        end
    end
    equal(classCount, 12, "12 concrete new class factories plus separately tested Mage")
    equal(specCount, 37, "37 concrete non-Mage specializations plus three separately tested Mage")
    equal(state.realReads, 0, "building audited definition metadata does not query skill state")
    equal(addon:GetRuntimeLoadDiagnostics().allocatedBindings, 0, "factory metadata never creates native bindings")
    print("OFFLINE-DEFINITION-MATRIX classes=" .. classCount .. ", specs=" .. specCount .. ", variant-occurrences=" .. variants)
end)

test("every non-Mage variant selects independently through learned state and native public cooldown paths", function()
    local tested, unsupported = 0, 0
    for _, row in ipairs(themeRoster) do
        local class = row[1]
        if class ~= "MAGE" then
            local engine, _, _, addon, state = genericEngine({})
            local allowed = {}
            for _, spec in ipairs(row[2]) do
                for _, definition in ipairs(definitionsFor(engine, class, spec[1])) do includeDefinitionIDs(allowed, definition) end
            end
            state.allowedSpellIDs = allowed
            state.classToken = class
            for _, spec in ipairs(row[2]) do
                state.specID = spec[1]
                for _, definition in ipairs(definitionsFor(engine, class, spec[1])) do
                    for _, variant in ipairs(definition.variants or { definition }) do
                        state.mobility.known, state.mobility.overrides, state.mobility.spells = { [variant.spellID] = true }, {}, {}
                        if variant.onlyWhenBaseOverride then
                            truthy(definition.baseSpellID, "conditional return declares its audited base family")
                            state.mobility.known[definition.baseSpellID] = true
                            state.mobility.overrides[definition.baseSpellID] = variant.spellID
                        end
                        local item = { cooldownStart = 91, cooldownDuration = 27 }
                        if variant.audit.rechargeMS then item.charges, item.maxCharges, item.chargeStart, item.chargeDuration = 0, 3, 91, 27 end
                        state.mobility.spells[variant.spellID] = item
                        local beforeReads = #state.spellReads
                        syncEvent(state, "PLAYER_ENTERING_WORLD")
                        local entries = addon:GetMobilityEntries()
                        equal(#entries, 1, "only one learned variant becomes active: " .. class .. "/" .. variant.spellID)
                        equal(entries[1].spellID, variant.spellID, "effective selected identity preserved")
                        equal(entries[1].id, definition.id, "replacement family keeps stable saved-position key")
                        if variant.unsupportedReason then
                            unsupported = unsupported + 1
                            equal(addon:GetMobilityStatus(definition.id).status, "Unsupported", "blocked return-stage remains explicitly unsupported")
                            equal(#state.spellReads, beforeReads, "unsupported mechanism makes no timer-state queries")
                            equal(textFor(addon, definition.id), "", "unsupported mechanism cannot show invented countdown")
                            for _, preview in ipairs(addon:GetPreviewEntries()) do
                                truthy(preview.freeMove, "excluded return variant cannot masquerade as an available sample")
                            end
                        else
                            tested = tested + 1
                            equal(addon:GetMobilityStatus(definition.id).status, "Depleted", "actual API fixture reports zero uses/cooldown")
                            equal(textFor(addon, definition.id), "No " .. variant.spellName .. "\n18.0", "real object supplies arbitrary timer, not metadata duration")
                            local available = {}
                            for _, preview in ipairs(addon:GetPreviewEntries()) do available[preview.id] = true end
                            truthy(available[definition.id], "supported ordinary variant retains its external Preview")
                            truthy(available["free_move_" .. class:lower()], "confirmed class receiver has its independent text-only Preview")
                            if item.charges then item.charges = 1 else item.cooldownDuration = 0 end
                            syncEvent(state, "SPELL_UPDATE_CHARGES")
                            equal(addon:GetMobilityStatus(definition.id).status, "Ready", "first recovery/actual reset hides active skill")
                            equal(textFor(addon, definition.id), "", "ready variant removes existing native timer")
                        end
                        for i = beforeReads + 1, #state.spellReads do
                            equal(state.spellReads[i].id, variant.spellID, "runtime cannot read unlearned or unrelated class spell")
                        end
                    end
                end
            end
            equal(countKeys(addon.db.classes), 2, "only initial UNKNOWN and explicitly current class configs exist")
        end
    end
    truthy(tested > 100 and unsupported > 0, "matrix exercises real supported variants and honest unsupported stages")
    print("OFFLINE-VARIANT-MATRIX public-path-cases=" .. tested .. ", unsupported-stage-cases=" .. unsupported)
end)

test("every shipped generic charge gate uses its own audited metadata and opaque partial empty first-recovery cycle", function()
    local engine, entry, _, addon, state = genericEngine({})
    local seen, tested = {}, 0
    for _, row in ipairs(themeRoster) do
        if row[1] ~= "MAGE" then
            for _, spec in ipairs(row[2]) do
                for _, definition in ipairs(definitionsFor(engine, row[1], spec[1])) do
                    for _, variant in ipairs(definition.variants or { definition }) do
                        local rule = variant.chargeVisibility or definition.chargeVisibility
                        if rule and not seen[variant.spellID] then
                            seen[variant.spellID], tested = true, tested + 1
                            equal(rule.baseCooldownMS, variant.audit.cooldownMS, "gate ordinary interval matches this variant's audit")
                            equal(rule.baseGCDMS, variant.audit.gcdMS, "gate GCD metadata matches this variant's audit")
                            truthy(rule.boundaryMS >= math.max(variant.audit.cooldownMS, variant.audit.categoryCooldownMS or 0),
                                "gate excludes both ordinary and category interval metadata")
                            state.allowedSpellIDs[variant.spellID] = true
                            state.baseCooldowns[variant.spellID] = { rule.baseCooldownMS, rule.baseGCDMS }
                            local item = { charges = 1, maxCharges = 3, chargeStart = 93, chargeDuration = 17,
                                secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = rule.boundaryMS / 1000 }
                            state.mobility.spells[variant.spellID] = item
                            local selected = copy(variant); selected.chargeVisibility = rule
                            for _, depleted in ipairs({ false, true, false }) do
                                item.charges = depleted and 0 or 1
                                item.cooldownDuration = depleted and 17 or rule.boundaryMS / 1000
                                local result = engine:ReadAbilityState(entry, selected)
                                equal(result.status, "Native tracking", "per-ability gate never exposes Lua final visibility")
                                addon:RenderLiveMobility(entry, selected.spellName, result.duration, result.visibility, selected.spellID)
                                state:nativeTick()
                                equal(textFor(addon, entry.id), depleted and ("No " .. selected.spellName .. "\n10.0") or "",
                                    "partial hides, empty preserves seven-second-old recharge, first recovery hides")
                            end
                        end
                    end
                end
            end
        end
    end
    truthy(tested >= 15, "concrete per-ability gates tested, not borrowed universal classifier")
    equal(state.alphaReads + state.liveMeasurements, 0, "all native opaque gates are write-only display sinks")
    print("OFFLINE-CHARGE-GATES unique-audited-ability-rules=" .. tested .. "; native semantic/client validation remains separate")
end)

test("Druid form replacements deduplicate native overrides and only Druid owns form-change monitoring", function()
    local engine, _, _, addon, state = genericEngine({})
    local allowed = {}
    for _, definition in ipairs(definitionsFor(engine, "DRUID", 103)) do includeDefinitionIDs(allowed, definition) end
    state.allowedSpellIDs, state.classToken, state.specID = allowed, "DRUID", 103
    state.mobility.known = { [102401] = true, [49376] = true, [16979] = true }
    state.mobility.overrides = { [102401] = 49376, [16979] = 49376 }
    state.mobility.spells = { [49376] = { cooldownStart = 95, cooldownDuration = 15 }, [16979] = { cooldownStart = 97, cooldownDuration = 15 } }
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    equal(#addon:GetMobilityEntries(), 1, "base and current form are one family")
    equal(addon:GetMobilityEntry().spellID, 49376, "native Cat override selected")
    local frame = addon.reminderFrames.live.druid_wild_charge
    truthy(addon:GetEventDiagnostics().perEvent.UPDATE_SHAPESHIFT_FORM, "only current Druid adds form identity event")
    local before = #state.spellReads
    state.mobility.overrides = { [102401] = 16979, [49376] = 16979 }
    syncEvent(state, "UPDATE_SHAPESHIFT_FORM")
    equal(addon:GetMobilityEntry().spellID, 16979, "form-change event selects native Bear override")
    equal(#addon:GetMobilityEntries(), 1, "replacement does not duplicate family")
    equal(addon.reminderFrames.live.druid_wild_charge, frame, "same family reuses one native frame")
    equal(textFor(addon, "druid_wild_charge"), "No Wild Charge\n12.0", "replacement binds actual new form duration")
    for i = before + 1, #state.spellReads do equal(state.spellReads[i].id, 16979, "old form is not queried after replacement") end
    state.classToken, state.specID, state.allowedSpellIDs, state.mobility.known = "WARRIOR", 71, warriorIDs, {}
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    equal(addon:GetEventDiagnostics().perEvent.UPDATE_SHAPESHIFT_FORM, nil, "leaving Druid removes dedicated form listener")
    equal(frame.durationBinding.enabled, false, "leaving class disables old form binding")
    local reads = #state.knownReads
    syncEvent(state, "UPDATE_SHAPESHIFT_FORM")
    equal(#state.knownReads, reads, "other class performs no form-event roster scan")
end)

test("Warrior repeated spec changes detach exclusive skills and keep frames bindings and listener counts bounded", function()
    local _, addon, state = warriorLogin({ [100] = { charges = 0, maxCharges = 1, chargeStart = 93, chargeDuration = 20 },
        [6544] = { charges = 0, maxCharges = 1, chargeStart = 94, chargeDuration = 45 },
        [3411] = { charges = 1, maxCharges = 1 }, [385952] = { cooldownStart = 98, cooldownDuration = 45 } },
        { [100] = true, [6544] = true, [3411] = true, [385952] = true })
    equal(#addon:GetMobilityEntries(), 3, "Arms cannot activate learned Protection-only entry")
    options(addon)
    state.specID = 73; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(#addon:GetMobilityEntries(), 4, "Protection activates its actual exclusive skill")
    local exclusive = addon.reminderFrames.live.warrior_shield_charge
    local resources, report, saved = resourceCounts(state), addon:GetRuntimeLoadDiagnostics(), copy(addon:GetMobilityConfig())
    for _ = 1, 12 do
        for _, spec in ipairs({ 71, 72, 73 }) do
            state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
            equal(exclusive.durationBinding.enabled, spec == 73, "spec-exclusive binding active only in current spec")
            equal(#addon:GetMobilityEntries(), spec == 73 and 4 or 3, "current spec activity, not all spec scan")
        end
    end
    same(resourceCounts(state), resources, "36 warmed spec switches allocate no new frames or native widgets")
    equal(addon:GetRuntimeLoadDiagnostics().allocatedBindings, report.allocatedBindings, "bindings stay bounded by actual family IDs")
    same(addon:GetEventDiagnostics(), report.events, "repeated spec switching does not accumulate listeners")
    same(addon:GetMobilityConfig(), saved, "spec changes never rebuild class-shared settings")
    equal(state.liveMeasurements + state.alphaReads, 0, "switch lifecycle never inspects opaque display values")
end)

local function selectGenericClass(class, spec, known, spells, overrides)
    local engine, _, _, addon, state = genericEngine({})
    local allowed = {}
    for _, definition in ipairs(definitionsFor(engine, class, spec)) do includeDefinitionIDs(allowed, definition) end
    state.allowedSpellIDs, state.classToken, state.specID = allowed, class, spec
    state.mobility.known, state.mobility.spells, state.mobility.overrides = known, spells, overrides or {}
    syncEvent(state, "PLAYER_ENTERING_WORLD")
    return addon, state, engine
end

test("free-return talents stay explicitly unsupported without false exhaustion or queries and recover when removed", function()
    for _, fixture in ipairs({
        { class = "ROGUE", spec = 261, id = 36554, talent = 454433, family = "rogue_shadowstep" },
        { class = "ROGUE", spec = 260, id = 195457, talent = 454433, family = "rogue_grappling_hook" },
        { class = "EVOKER", spec = 1467, id = 357210, talent = 1266151, family = "evoker_deep_breath" },
    }) do
        local addon, state = selectGenericClass(fixture.class, fixture.spec, { [fixture.id] = true },
            { [fixture.id] = { charges = 0, maxCharges = 1, chargeStart = 90, chargeDuration = 20 } })
        equal(addon:GetMobilityStatus(fixture.family).status, "Depleted", "ordinary learned form reads real depletion")
        local frame, saved = addon.reminderFrames.live[fixture.family], copy(addon:GetMobilityConfig())
        state.mobility.known[fixture.talent] = true
        local reads = #state.spellReads
        syncEvent(state, "TRAIT_CONFIG_UPDATED")
        equal(addon:GetMobilityStatus(fixture.family).status, "Unsupported", "known conditional-free-return talent has exact blocker")
        equal(#state.spellReads, reads, "no base cooldown queried as substitute for free return availability")
        equal(frame.durationBinding.enabled, false, "obsolete outbound timer detached")
        equal(textFor(addon, fixture.family), "", "no misleading No-skill reminder during unsupported mechanism")
        options(addon)
        equal(addon:SetPreview("single", fixture.family), false, "excluded free-return mechanism is not offered as a usable Preview")
        addon:StopPreview()
        equal(addon:GetMobilityStatus(fixture.family).status, "Unsupported", "preview never upgrades unsupported live status")
        state.mobility.known[fixture.talent] = nil
        syncEvent(state, "TRAIT_CONFIG_UPDATED")
        equal(addon:GetMobilityStatus(fixture.family).status, "Depleted", "removing blocked talent resynchronizes current native state")
        same(addon:GetMobilityConfig(), saved, "mechanism transition never clears saved configuration")
    end
end)

test("temporary return-stage overrides noticed on cooldown events never leave stale outbound depletion", function()
    local addon, state = selectGenericClass("MONK", 269, { [101545] = true, [115057] = true },
        { [101545] = { cooldownStart = 94, cooldownDuration = 30 }, [115057] = { cooldownStart = 100, cooldownDuration = 0 } },
        { [115057] = 101545 })
    equal(addon:GetMobilityStatus("monk_flying_serpent_kick").status, "Depleted", "outbound learned stage initially active")
    state.mobility.overrides = { [101545] = 115057 }
    local before = #state.spellReads
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(textFor(addon, "monk_flying_serpent_kick"), "", "cooldown-only replacement immediately clears stale outbound alert")
    equal(addon:GetMobilityStatus("monk_flying_serpent_kick").status, "Unsupported", "current landing-stage blocker is reported")
    equal(#state.spellReads, before, "return stage does not query old outbound or landing cooldown as exhaustion")
    state.mobility.overrides = { [115057] = 101545 }
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(addon:GetMobilityStatus("monk_flying_serpent_kick").status, "Depleted", "cooldown-only return to outbound restores monitoring")
    equal(textFor(addon, "monk_flying_serpent_kick"), "No Flying Serpent Kick\n24.0", "restore uses actual existing timer")
    state.mobility.overrides[101545] = 999999
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(textFor(addon, "monk_flying_serpent_kick"), "", "unmapped transient override cannot show stale timer")
    local current = addon:GetMobilityStatuses()[1]
    truthy(current.status == "Unsupported" or current.status == "Unknown", "unmapped current stage has honest public diagnostic")
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(addon.mobilityCooldownWatching, true, "temporarily unresolved learned family retains bounded event recovery")
    state.mobility.overrides = {}
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(addon:GetMobilityStatus("monk_flying_serpent_kick").status, "Depleted", "native base identity wins when temporary return ends")
    equal(textFor(addon, "monk_flying_serpent_kick"), "No Flying Serpent Kick\n24.0", "unknown transient stage recovers without talent event or polling")
end)

test("conditional returns cannot activate from learned spell alone and shared Recall never invents its source", function()
    local addon, state = selectGenericClass("EVOKER", 1468, { [371838] = true }, {})
    equal(#addon:GetMobilityEntries(), 0, "learned shared return without native base override cannot claim either flight")
    equal(addon:GetRuntimeLoadDiagnostics().activeBindings, 0, "source-unknown return cannot create a cooldown timer")
    state.mobility.known[359816] = true
    state.mobility.overrides[359816] = 371838
    syncEvent(state, "SPELLS_CHANGED")
    equal(#addon:GetMobilityEntries(), 1, "native Dream Flight override resolves exactly one return family")
    equal(addon:GetMobilityEntry().id, "evoker_dream_flight", "known native family identity retains Dream Flight position")
    equal(addon:GetMobilityStatus("evoker_dream_flight").status, "Unsupported", "return mechanism still honestly lacks native depletion semantics")
    equal(state.realReads, 0, "no shared-return cooldown or unrelated Deep Breath query")
    state.mobility.spells[359816] = { cooldownStart = 93, cooldownDuration = 120 }
    state.mobility.overrides = {}
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(addon:GetMobilityEntry().spellID, 359816, "current native base override takes precedence despite learned Recall")
    equal(textFor(addon, "evoker_dream_flight"), "No Dream Flight\n113.0", "restored native flight starts no simulated timer")
end)

test("temporary restricted active identity clears its timer and recovers through existing cooldown subscriptions", function()
    local addon, state = selectGenericClass("MONK", 269, { [101545] = true },
        { [101545] = { cooldownStart = 95, cooldownDuration = 30 } })
    local frame = addon.reminderFrames.live.monk_flying_serpent_kick
    state.mobility.overrides[101545] = secret(115057)
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(textFor(addon, "monk_flying_serpent_kick"), "", "restricted current override cannot reuse previous identity")
    equal(frame.durationBinding.enabled, false, "restricted identity detaches native timer")
    equal(addon:GetMobilityStatus().status, "Restricted", "opaque identity has explicit safe diagnostic")
    state.mobility.overrides = {}
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(textFor(addon, "monk_flying_serpent_kick"), "No Flying Serpent Kick\n25.0", "public identity recovery resumes current real state")
    equal(#state.errors, 0, "restricted override never enters comparison arithmetic or string operations")
end)

test("authoritative unlearned base override cannot leave one old learned DH variant falsely active", function()
    local addon, state = selectGenericClass("DEMONHUNTER", 577, { [195072] = true },
        { [195072] = { charges = 0, maxCharges = 1, chargeStart = 96, chargeDuration = 10 } },
        { [344865] = 195072 })
    equal(addon:GetMobilityEntry().spellID, 195072, "learned spec variant resolves from unlearned generic base")
    equal(textFor(addon, "demonhunter_movement"), "No Fel Rush\n6.0", "initial real current variant timer")
    for _, step in ipairs({ { 999999, "Unsupported" }, { 427785, "Unknown" } }) do
        state.mobility.overrides[344865] = step[1]
        local reads = #state.spellReads
        syncEvent(state, "SPELL_UPDATE_COOLDOWN")
        equal(textFor(addon, "demonhunter_movement"), "", "changed base cannot fall back to old variant self-override")
        equal(addon:GetMobilityStatus().status, step[2], "unknown definition vs mapped unlearned replacement has exact diagnostic")
        equal(#state.spellReads, reads, "stale former variant never reaches cooldown engine")
        equal(addon.mobilityCooldownWatching, true, "temporarily unresolved family retains bounded event recovery")
    end
    state.mobility.overrides[344865] = 195072
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(addon:GetMobilityEntry().spellID, 195072, "authoritative base can restore supported current variant")
    equal(textFor(addon, "demonhunter_movement"), "No Fel Rush\n6.0", "real original timer resumes without manual state")
end)

test("Mage additional conditional returns remain honest unsupported entries and cannot replace tested Blink Shimmer", function()
    local _, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20, secretCharges = true,
            secretDuration = true, cooldownStart = 100, cooldownDuration = 20 })
    local main = addon:GetMobilityEntry()
    local frame = currentLive(addon)
    state.mobility.known[342245], state.mobility.known[389713] = true, true
    state.mobility.overrides = { [1953] = 212653 }
    syncEvent(state, "SPELLS_CHANGED")
    equal(addon:GetMobilityEntry(), main, "existing Mage mobility compatibility entry remains first")
    equal(currentLive(addon), frame, "existing tested Mage native frame reused")
    equal(#addon:GetMobilityEntries(), 3, "Mage primary plus two explicitly conditional return families")
    equal(addon:GetMobilityStatus("mage_alter_time").status, "Unsupported", "Alter Time cannot use initial cast cooldown as return availability")
    equal(addon:GetMobilityStatus("mage_reflection").status, "Unsupported", "Reflection diagnostic uses target build identity")
    equal(nativeText(addon), "No Shimmer\n15.0", "new definitions cannot overwrite accepted secret Shimmer pipeline")
    for _, query in ipairs(state.spellReads) do
        truthy(query.id ~= 342245 and query.id ~= 342247 and query.id ~= 389713, "blocked returns never read misleading duration")
    end
    state.mobility.known[342247] = true; state.mobility.overrides[342245] = 342247
    syncEvent(state, "SPELLS_CHANGED")
    equal(addon:GetMobilityStatus("mage_alter_time").status, "Unsupported", "Alter Time return stage retains exact blocker")
    equal(#addon:GetMobilityEntries(), 3, "replacement does not duplicate Alter Time family")
    options(addon)
    equal(addon:SetPreview("single", "mage_reflection"), false, "excluded unimplemented return cannot appear as a usable Preview")
    equal(nativeText(addon), "No Shimmer\n15.0", "preview of separate return family cannot hide actual Shimmer")
    addon:StopPreview(); state:nativeTick()
    equal(nativeText(addon), "No Shimmer\n15.0", "stopping sample preserves primary real countdown")
end)

-- Native aura fixtures emulate only the documented display contract. They do
-- not prove secure execution, retail aura filtering, or live overlay geometry.
local function auraFixture(specID)
    local env, addon, state = login(nil, false, { specID = specID or 63, proc = {} })
    return env, addon, state
end

test("native helpful aura slots handle opaque trigger partial stacks refresh expiry and consumption", function()
    local env, addon, state = auraFixture()
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    parent:SetSize(200, 100)
    local handle = assert(addon:CreateNativeAuraSlot(parent, "native_fixture_hot_streak", 48108))
    handle:SetEnabled(true)
    equal(state:nativeAuraText(handle.container), "", "no aura never fabricates timer")
    state.proc.auras[1] = { spellID = secret(48108), applications = secret(2), duration = state:duration(96, 17, true) }
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "13.0", "native slot renders actual opaque remaining duration")
    state.inCombat = true
    state.proc.auras[1].applications = secret(1)
    state:advance(2)
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "11.0", "partial consumption retains native timer and remaining layer")
    state.proc.auras[1].duration = state:duration(state.clock, 19, true)
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "19.0", "refresh supplies new real native duration without fixed lifetime")
    state:advance(19)
    equal(state:nativeAuraText(handle.container), "", "native expiry removes timer with no addon polling")
    state.proc.auras[1].duration = state:duration(state.clock, 23, true)
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "23.0", "retrigger after expiration reuses native display")
    state.proc.auras[1] = nil
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "", "full consumption clears instantly on aura event")
    equal(state.realReads, 0, "addon never reads a secret or public aura through Lua APIs")
    equal(state.liveMeasurements, 0, "native aura text never enters string measurement")
    equal(#state.errors, 0, "no native secret read or lifecycle errors")
end)

test("native aura presence and data secrecy are independent from the combat flag", function()
    for _, inCombat in ipairs({ false, true }) do
        for _, restricted in ipairs({ false, true }) do
            local env, addon, state = auraFixture()
            local parent = env.CreateFrame("Frame", nil, env.UIParent)
            local handle = assert(addon:CreateNativeAuraSlot(parent, "native_fixture_independent", 44544))
            handle:SetEnabled(true)
            state.inCombat = inCombat
            state.proc.auras[1] = { spellID = restricted and secret(44544) or 44544,
                applications = restricted and secret(2) or 2, duration = state:duration(90, 29, restricted) }
            state:fire("UNIT_AURA", "player")
            equal(state:nativeAuraText(handle.container), "19.0", "all four combat/secrecy combinations use native countdown")
            state.proc.auras[1] = nil
            state:fire("UNIT_AURA", "player")
            equal(state:nativeAuraText(handle.container), "", "all four combinations clear on actual absence")
            equal(#state.errors, 0, "no opaque data escapes native fixture")
        end
    end
end)

test("native slot reuse remains tied to one audited aura and releases display work on disable", function()
    local env, addon, state = auraFixture()
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    local handle = assert(addon:CreateNativeAuraSlot(parent, "native_fixture_stable", 48108))
    local allocatedSlots, allocatedBindings, allocatedFonts = #state.auraSlots, #state.bindings, #state.auraFonts
    for index = 1, 20 do
        equal(addon:CreateNativeAuraSlot(parent, "native_fixture_stable", 48108), handle, "slot handle is bounded and reusable")
        handle:SetEnabled(true)
        state.proc.auras[1] = { spellID = secret(48108), duration = state:duration(state.clock, index + 5, true) }
        state:fire("UNIT_AURA", "player")
        truthy(state:nativeAuraText(handle.container) ~= "", "matching aura gets current native timer")
        handle:SetEnabled(false)
        equal(state:nativeAuraText(handle.container), "", "disabled native slot is empty")
        equal(handle.container.enabled, false, "disabled container no longer owns active aura subscriptions")
        truthy(handle.container:IsShown(), "disabled shown ancestor permits queued native cleanup")
    end
    equal(addon:CreateNativeAuraSlot(parent, "native_fixture_stable", 44544), nil, "cached timer cannot be silently reassigned to another aura")
    equal(#state.auraSlots, allocatedSlots, "repeated lifecycle creates no additional native slots")
    equal(#state.bindings, allocatedBindings, "repeated lifecycle creates no additional timer bindings")
    equal(#state.auraFonts, allocatedFonts, "repeated lifecycle creates no additional font objects")
    equal(state:activeTimers(), 0, "native slot lifecycle adds no addon polling timers")
end)

test("Free move native helper displays only text for its independently filtered aura", function()
    local env, addon, state = auraFixture()
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    local before = #state.bindings
    local handle = assert(addon:CreateNativeAuraSlot(parent, "native_fixture_free_move", 375240, "Free move"))
    handle:SetEnabled(true)
    equal(#state.bindings, before, "text-only helper allocates no countdown binding")
    state.proc.auras[1] = { spellID = secret(375240), duration = state:duration(95, 21, true) }
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "Free move", "no duration or skill name is added")
    state.proc.auras[1] = { spellID = secret(358267), duration = state:duration(95, 21, true) }
    state:fire("UNIT_AURA", "player")
    equal(state:nativeAuraText(handle.container), "", "Hover duration cannot activate Time Spiral text")
    equal(state.realReads, 0, "static aura filter avoids any addon-side aura query")
end)

local function procFrame(addon, id)
    return assert(addon.reminderFrames and addon.reminderFrames.nativeAura and addon.reminderFrames.nativeAura[id],
        "missing live native Proc region " .. id)
end
local function procText(addon, state, id)
    return state:nativeAuraText(procFrame(addon, id).auraHandle.container)
end
local function putAura(state, id, duration, stacks, restricted)
    state.proc.auras[id] = { spellID = restricted and secret(id) or id,
        applications = restricted and secret(stacks or 1) or stacks or 1,
        duration = state:duration(state.clock, duration, restricted) }
    state:fire("UNIT_AURA", "player")
end
local function showProc(env, state, id, texture, location, scale)
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", id, texture, env.Enum.ScreenLocationType[location], scale or 1, 255, 255, 255)
end

test("Mage mappings preserve separate aura overlay region identities and include cast-time Pyroclasm", function()
    local _, addon, state = auraFixture(63)
    local all, regions, IDs = 0, 0, {}
    local expected = { [62] = { [1277420] = true, [451038] = true, [1277009] = true },
        [63] = { [48108] = true, [48107] = true, [269651] = true, [383874] = true, [383883] = true },
        [64] = { [44544] = true, [126084] = true, [190446] = true } }
    for _, spec in ipairs({ 62, 63, 64 }) do
        state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        local found = {}
        for _, definition in ipairs(addon:GetProcDefinitions()) do
            truthy(expected[spec][definition.overlayID], "only audited current-spec native graph rows")
            if definition.overlayID == 1277420 then
                equal(definition.auraID, 263725, "Clearcasting timer is distinct from native stack-graphic owner")
                equal(#definition.overlaySources, 3, "three audited native graphic owners share the verified timer source")
            else
                equal(definition.auraID, definition.overlayID, "other currently audited records retain their exact native Aura")
            end
            truthy(not found[definition.overlayID], "native graph identity is unique within spec")
            found[definition.overlayID] = true; all = all + 1
            for _, entry in ipairs(definition.regions) do
                truthy(not IDs[entry.id], "each native visual region retains independent position ID")
                IDs[entry.id] = true; regions = regions + 1
                equal(entry.kind, "proc", "native region uses Proc style/config namespace")
                equal(entry.specID, spec, "only current specialization styles apply")
            end
        end
        same(found, expected[spec], "audited mapping is complete for current spec")
    end
    equal(all, 11, "eleven audited native graph rows including event-only historical row")
    equal(regions, 16, "sixteen independently positioned graph regions")
    truthy(IDs.mage_fire_pyroclasm_top, "cast-time Pyroclasm is distinct from Hot Streak")
    truthy(IDs.mage_frost_fingers_left and IDs.mage_frost_fingers_right, "native second-stack graph is not inferred by Lua")
    equal(state.realReads, 0, "mapping and state changes perform no addon aura/cooldown reads")
end)

test("Fire live native timers coexist across Hot Streak Heating Up and Pyroclasm with independent lifecycle", function()
    local env, addon, state = auraFixture(63)
    truthy(addon.procTracking, "real Proc monitoring starts at login without Options or Test Mode")
    state.inCombat = true
    putAura(state, 48108, 17, 1, true)
    putAura(state, 48107, 11, 1, true)
    putAura(state, 269651, 23, 2, true)
    showProc(env, state, 48108, 449490, "LeftRight", 1)
    showProc(env, state, 48107, 449490, "LeftRight", 0.5)
    showProc(env, state, 269651, 457658, "Top", 0.7)
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "17.0", "Hot Streak left actual time")
    equal(procText(addon, state, "mage_fire_hot_streak_right"), "17.0", "Hot Streak right actual time")
    equal(procText(addon, state, "mage_fire_heating_up_left"), "11.0", "Heating Up has separate smaller graphic timer")
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "23.0", "Pyroclasm time is not Hot Streak time")
    state:advance(3)
    state.proc.auras[269651].applications = secret(1)
    state.proc.auras[48108] = nil
    state:fire("UNIT_AURA", "player")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 48108)
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "consumed Hot Streak removes its regions")
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "20.0", "partially consumed Pyroclasm remains active")
    equal(procText(addon, state, "mage_fire_heating_up_left"), "8.0", "another simultaneous Proc is untouched")
    putAura(state, 269651, 29, 2, true)
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "29.0", "refresh uses fresh native aura duration")
    state:advance(29)
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "", "natural expiry clears actual aura")
    equal(state.liveMeasurements, 0, "real Proc timer never enters ordinary string sizing")
    equal(state.realReads, 0, "secret aura data stays inside native matching and timing")
    equal(#state.errors, 0, "live secret Proc path has no addon errors")
end)

test("Frost native first and second stack regions clear independently while Brain Freeze remains", function()
    local env, addon, state = auraFixture(64)
    putAura(state, 44544, 14, 2, true)
    putAura(state, 126084, 14, 1, true)
    putAura(state, 190446, 19, 1, true)
    showProc(env, state, 44544, 449489, "Left", 1)
    showProc(env, state, 126084, 449489, "Right", 1)
    showProc(env, state, 190446, 450930, "Top", 1)
    equal(procText(addon, state, "mage_frost_fingers_left"), "14.0", "first native Fingers region")
    equal(procText(addon, state, "mage_frost_fingers_right"), "14.0", "second native Fingers region")
    state.proc.auras[44544].applications = secret(1)
    state.proc.auras[126084] = nil
    state:fire("UNIT_AURA", "player"); state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 126084)
    equal(procText(addon, state, "mage_frost_fingers_left"), "14.0", "one charge consumed does not clear the first region")
    equal(procText(addon, state, "mage_frost_fingers_right"), "", "absent native second-stack aura clears only its region")
    equal(procText(addon, state, "mage_frost_brain_freeze_top"), "19.0", "different Proc remains independent")
    state.proc.auras[44544] = nil; state:fire("UNIT_AURA", "player")
    equal(procText(addon, state, "mage_frost_fingers_left"), "", "fully consumed first effect disappears")
end)

test("Proc layout follows stock graph edges scales and independent saved region offsets", function()
    local env, addon, state = auraFixture(63)
    env.SpellActivationOverlayFrame:SetScale(1.5)
    addon:UpdateReminderStyle("proc:MAGE:63", { font = { size = 35 }, scale = 2 })
    truthy(addon:UpdateSettings({ reminders = { mage_fire_heating_up_left = { position = { x = 13, y = -7 } },
        mage_fire_hot_streak_right = { position = { x = -9, y = 3 } } } }), "existing per-region coordinates stay editable")
    showProc(env, state, 48107, 449490, "LeftRight", 0.5)
    showProc(env, state, 48108, 449490, "LeftRight", 1)
    local small, large = procFrame(addon, "mage_fire_heating_up_left"), procFrame(addon, "mage_fire_hot_streak_right")
    local point, relative, relativePoint, x, y = small:GetPoint()
    equal(point, "CENTER", "timer own visual center")
    equal(relative, env.SpellActivationOverlayFrame, "live timer is tied to current stock overlay root")
    equal(relativePoint, "LEFT", "left bracket uses native root left edge")
    equal(x * small:GetScale(), -25.6 * 1.5 + 13, "small bracket center includes stock scale and saved X exactly once")
    equal(y * small:GetScale(), -7, "saved Y independent of scale migration")
    local _, _, largeEdge, largeX, largeY = large:GetPoint()
    equal(largeEdge, "RIGHT", "opposite bracket owns its native edge")
    equal(largeX * large:GetScale(), 51.2 * 1.5 - 9, "large bracket center is not reused for smaller bracket")
    equal(largeY * large:GetScale(), 3, "other region position remains independent")
    same(small.auraHandle.font.textColor, { 0.25, 0.78, 0.92, 1 }, "Proc digits use player class color")
    equal(small.auraHandle.font.font[2], 35, "native child inherits current spec shared font")
end)

test("native graph lifecycle rejects unrelated or secret payloads and reused graphs cannot inherit old timers", function()
    local env, addon, state = auraFixture(63)
    local id, texture, region = 383883, 457658, "mage_fire_fury_sun_king_top"
    putAura(state, id, 27, 1, true)
    equal(procText(addon, state, region), "", "event-only graph is not invented from an old historical mapping")
    showProc(env, state, id, texture + 1, "Top", 0.7)
    equal(procText(addon, state, region), "", "wrong graphic never establishes a mapping")
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", secret(id), texture, env.Enum.ScreenLocationType.Top, 0.7)
    equal(procText(addon, state, region), "", "opaque event identity is not decoded")
    showProc(env, state, id, texture, "Top", 0.7)
    equal(procText(addon, state, region), "27.0", "actual matching native graph enables its exact aura slot")
    local frame = procFrame(addon, region)
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", id)
    equal(procText(addon, state, region), "", "graph hide detaches its timer")
    truthy(frame:IsShown(), "public wrapper stays shown for deferred native cleanup")
    putAura(state, 269651, 13, 1, true)
    showProc(env, state, 269651, 457658, "Top", 0.7)
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "13.0", "same stock texture reused by other effect gets its own real time")
    equal(procText(addon, state, region), "", "historical timer cannot remain on a reused native graphic")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    equal(procText(addon, state, "mage_fire_pyroclasm_top"), "", "hide-all releases every observed graph")
end)

test("Options Preview and class settings leave real Proc and Mobility ownership independent", function()
    local env, addon, state = login(nil, false, { specID = 63, proc = {}, mobility = {
        known = { [212653] = true, [1953] = true }, override = 212653,
        spells = { [212653] = { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
            cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true } } } })
    putAura(state, 48108, 18, 1, true)
    local live = currentLive(addon)
    options(addon); truthy(addon:SetPreview("single", "mage_fire_hot_streak_left"), "existing Test Mode can select Proc region")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "matching live region is independently suppressed during sample")
    equal(procText(addon, state, "mage_fire_hot_streak_right"), "18.0", "other native region continues")
    addon:StopPreview()
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "18.0", "stop sample restores current real aura")
    addon.optionsFrame:Hide()
    truthy(addon.procTracking, "closed Options does not stop Proc subscription")
    truthy(addon.mobilityTracking, "closed Options does not stop Mobility subscription")
    local duration, alpha = live.durationBinding.duration, live.alpha
    addon:UpdateReminderStyle("proc:MAGE:63", { font = { size = 38 } })
    equal(live.durationBinding.duration, duration, "Proc style change does not rebind real Mobility timer")
    equal(live.alpha, alpha, "Proc style never replaces secret Mobility visibility")
    equal(procFrame(addon, "mage_fire_hot_streak_left").auraHandle.font.font[2], 38, "native Proc font updates without restricted child access")
    truthy(addon:UpdateSettings({ proc = { enabled = false } }), "existing Proc module switch supports disable")
    state:nativeTick()
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "disabled Proc stops native slot")
    equal(addon:GetEventDiagnostics().perEvent.SPELL_ACTIVATION_OVERLAY_SHOW, nil, "disable removes own overlay subscription")
    truthy(addon.mobilityTracking, "disabling Proc never disables Mobility")
    equal(nativeText(addon), "No Shimmer\n15.0", "real Mobility still uses accepted path")
    truthy(addon:UpdateSettings({ proc = { enabled = true } }), "reenabling synchronizes native aura")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "18.0", "reenabling reads current native aura not stale cached timer")
end)

test("Proc specialization cycles and reload keep scoped styles coordinates slots and listeners bounded", function()
    local env, addon, state = auraFixture(62)
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 37 }, scale = 1.3 })
    addon:UpdateSettings({ reminders = { mage_arcane_clearcasting_left = { position = { x = 19, y = -8 } } } })
    putAura(state, 263725, 22, 2, true)
    local mobility = copy(addon:GetMobilityConfig())
    for _, spec in ipairs({ 63, 64, 62 }) do state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player") end
    local slots, bindings, fonts = #state.auraSlots, #state.bindings, #state.auraFonts
    local callbacks = addon:GetEventDiagnostics().callbacks
    for index = 1, 12 do
        for _, spec in ipairs({ 63, 64, 62 }) do
            state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
            state:nativeTick()
            for _, frame in pairs(addon.reminderFrames.nativeAura) do
                if frame.reminderEntry.kind == "proc" and frame.reminderEntry.specID ~= spec then
                    equal(frame.auraHandle.enabled, false, "previous spec slot is detached")
                end
            end
        end
    end
    equal(#state.auraSlots, slots, "spec cycles do not allocate unbounded native children")
    equal(#state.bindings, bindings, "spec cycles do not accumulate native bindings")
    equal(#state.auraFonts, fonts, "spec cycles do not accumulate font objects")
    equal(addon:GetEventDiagnostics().callbacks, callbacks, "spec cycles do not accumulate event callbacks")
    equal(procFrame(addon, "mage_arcane_clearcasting_left").auraHandle.font.font[2], 37, "returning Arcane restores current spec style")
    equal(addon:GetReminderPosition(procFrame(addon, "mage_arcane_clearcasting_left").reminderEntry).x, 19, "regional saved coordinate remains")
    same(addon:GetMobilityConfig(), mobility, "Proc spec changes leave Mage Mobility config untouched")
    local saved = copy(addon.db)
    local _, reloaded, fresh = login(saved, false, { specID = 62, proc = {} })
    putAura(fresh, 263725, 31, 1, true)
    syncEvent(fresh, "PLAYER_ENTERING_WORLD")
    equal(procText(reloaded, fresh, "mage_arcane_clearcasting_left"), "31.0", "reload synchronizes actual aura without waiting for another cast")
    equal(reloaded:GetProcConfig().style.font.size, 37, "reload preserves scoped Proc appearance")
    state.classToken, state.specID = "WARRIOR", 71; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(addon.procTracking, false, "non-Mage does not retain Mage Proc monitoring")
    equal(addon:GetEventDiagnostics().perEvent.SPELL_ACTIVATION_OVERLAY_SHOW, nil, "non-Mage retains no Proc overlay listener")
    for _, frame in pairs(addon.reminderFrames.nativeAura) do
        if frame.reminderEntry.kind == "proc" then equal(frame.auraHandle.enabled, false, "all Mage slots inactive off-class") end
    end
end)

test("Time Spiral Free move covers all thirteen class receiver auras without ordinary skill queries", function()
    local receivers = { DEATHKNIGHT = 375226, DEMONHUNTER = 375229, DRUID = 375230,
        EVOKER = 375234, HUNTER = 375238, MAGE = 375240, MONK = 375252,
        PALADIN = 375253, PRIEST = 375254, ROGUE = 375255, SHAMAN = 375256,
        WARLOCK = 375257, WARRIOR = 375258 }
    local tested = 0
    for _, row in ipairs(themeRoster) do
        local class, spec = row[1], row[2][1][1]
        local _, addon, state = login(nil, false, { classToken = class, specID = spec, proc = {} })
        local entry = assert(addon:GetFreeMoveEntry())
        equal(entry.auraID, receivers[class], "correct audited receiver for " .. class)
        equal(entry.sourceCastID, 374968, "cast identity remains distinct from receiver aura")
        equal(entry.class, class, "receiver entry uses current class Mobility configuration")
        equal(entry.specID, nil, "receiver configuration is not specialization-scoped")
        truthy(addon.freeMoveTracking, "confirmed receiver initializes even with no ordinary learned Mobility")
        equal(procText(addon, state, entry.id), "", "absent receiver shows no Free move")
        putAura(state, 374968, 30, 1, true)
        equal(procText(addon, state, entry.id), "", "caster spell ID cannot impersonate receiver aura")
        putAura(state, receivers[class], 30, 1, true)
        equal(procText(addon, state, entry.id), "Free move", "native secret receiver presence shows text")
        state.proc.auras[receivers[class]] = nil; state:fire("UNIT_AURA", "player")
        equal(procText(addon, state, entry.id), "", "consumed receiver disappears without manual counting")
        putAura(state, receivers[class], 3, 1, true); state:advance(3)
        equal(procText(addon, state, entry.id), "", "natural receiver expiry removes native text")
        equal(state.realReads, 0, "receiver tracking never starts unrelated ordinary cooldown queries")
        if class ~= "MAGE" then
            local definitions, expectedSlots = addon:GetProcDefinitions(), 1
            for _, definition in ipairs(definitions) do
                equal(definition.class, class, "receiver never causes another class's Proc data to activate")
                equal(definition.specID, spec, "receiver never activates a different specialization's Proc data")
                expectedSlots = expectedSlots + #definition.regions
            end
            equal(addon.procTracking, #definitions > 0, "Proc tracking follows actual eligible catalog independently of Free move")
            equal(#state.auraSlots, expectedSlots, "only independently eligible Proc regions and confirmed Free move allocate slots")
        end
        local found = false
        for _, preview in ipairs(addon:GetPreviewEntries()) do
            if preview.id == entry.id then
                found = true; truthy(preview.textOnly and preview.freeMove, "existing preview exposes the actual text-only feature")
                equal(preview.sample.timer, "", "no fabricated Free move countdown")
            end
        end
        truthy(found, "current class receiver has external Preview support")
        tested = tested + 1
    end
    equal(tested, 13, "all audited current-client receiver classes tested")
end)

test("Free move presence style Preview and disable never clear other Mobility or Proc", function()
    local env, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
            cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true }, { proc = {} })
    putAura(state, 48108, 19, 1, true)
    putAura(state, 375240, 17, 1, true)
    equal(procText(addon, state, "free_move_mage"), "Free move", "Time Spiral's receiver appears beside ordinary depletion")
    equal(nativeText(addon), "No Shimmer\n15.0", "Free move does not globally erase ordinary skill alerts")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "19.0", "Proc remains independent of Free move")
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 33 }, scale = 1.4 })
    local free = procFrame(addon, "free_move_mage")
    equal(free.auraHandle.font.font[2], 33, "Free move shares current class Mobility font")
    equal(free:GetScale(), 1.4, "Free move shares class Mobility scale")
    equal(procFrame(addon, "mage_fire_hot_streak_left").auraHandle.font.font[2], 24, "Mobility changes do not affect Proc spec style")
    options(addon)
    truthy(addon:SetPreview("single", "free_move_mage"), "existing Test Mode supports the confirmed Free move entry")
    equal(addon.previewFrames.free_move_mage.text:GetText(), "Free move", "sample is text only")
    equal(procText(addon, state, "free_move_mage"), "", "single Free move sample suppresses only corresponding live text")
    equal(nativeText(addon), "No Shimmer\n15.0", "Free move sample does not hide depleted Shimmer")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "19.0", "Free move sample does not hide Proc")
    state.proc.auras[375240] = nil; state:fire("UNIT_AURA", "player")
    addon:StopPreview()
    equal(procText(addon, state, "free_move_mage"), "", "stopping sample follows current consumed effect, not cached presence")
    addon.optionsFrame:Hide()
    putAura(state, 375240, 12, 1, true)
    equal(procText(addon, state, "free_move_mage"), "Free move", "closed Options does not stop receiver tracking")
    addon:UpdateSettings({ enabled = false }); state:nativeTick()
    equal(addon.freeMoveTracking, false, "class Mobility disable stops Free move")
    equal(free.auraHandle.enabled, false, "class disable detaches native receiver listener")
    equal(procText(addon, state, "free_move_mage"), "", "class disable clears receiver display")
    truthy(addon.procTracking, "class Mobility disable leaves independent Proc active")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "19.0", "Proc timer survives Mobility disable")
    addon:UpdateSettings({ enabled = true })
    equal(procText(addon, state, "free_move_mage"), "Free move", "reenabling follows currently active real receiver")
    equal(nativeText(addon), "No Shimmer\n15.0", "ordinary native charge path resumes unchanged")
end)

test("native aura template absence reports unsupported without simulated combat substitutes", function()
    local _, addon, state = login(nil, false, { proc = { templateUnavailable = true } })
    equal(addon.procTracking, false, "missing native aura template does not claim real Proc support")
    equal(addon.freeMoveTracking, false, "same missing API prevents falsely claiming receiver support")
    equal(#state.auraSlots, 0, "unsupported template creates no hidden substitute slots")
    truthy(addon:GetProcDiagnostics():find("CustomAuraContainerTemplate", 1, true), "diagnostic names exact missing native contract")
    truthy(addon:GetFreeMoveDiagnostics():find("CustomAuraContainerTemplate", 1, true), "Free move blocker names exact native contract")
    equal(state.realReads, 0, "fallback never probes restricted auras or guesses duration")
end)

test("disabled stock overlay preference does not replay ignored graph events on later CVar enable", function()
    local env, addon, state = auraFixture(63)
    state.proc.cvars.displaySpellActivationOverlays = false
    state:fire("CVAR_UPDATE", "displaySpellActivationOverlays")
    putAura(state, 48108, 17, 1, true)
    showProc(env, state, 48108, 449490, "LeftRight", 1)
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "native SHOW ignored while the stock preference is disabled")
    state.proc.cvars.displaySpellActivationOverlays = true
    state:fire("CVAR_UPDATE", "displaySpellActivationOverlays")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "enabling stock setting does not invent a graph for an ignored SHOW")
    showProc(env, state, 48108, 449490, "LeftRight", 1)
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "17.0", "subsequent actual native SHOW enables the current aura timer")
    state.proc.cvars.spellActivationOverlayOpacity = "0.35"
    state:fire("CVAR_UPDATE", "spellActivationOverlayOpacity")
    equal(procFrame(addon, "mage_fire_hot_streak_left").alpha, 0.35, "Proc follows public stock opacity preference without alpha readback")
    putAura(state, 375240, 8, 1, true)
    equal(procText(addon, state, "free_move_mage"), "Free move", "stock graphic settings do not gate independent Mobility receiver")
end)

test("Proc Options checkbox releases native slots after one pass and diagnostics never infer aura presence", function()
    local _, addon, state = auraFixture(63)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("proc")
    truthy(controls.procEnabled:IsEnabled() and controls.procEnabled:GetChecked(), "existing Proc switch operates on current spec")
    local before = addon:GetRuntimeLoadDiagnostics()
    truthy(before.nativeAuraEnabledSlots > 0, "configured native slots exist before any matching aura")
    equal(before.nativeAuraTextSlots, 1, "Free move owns one text-only native slot")
    truthy(before.nativeAuraDurationSlots > 0, "Proc owns native duration slots")
    truthy(addon:GetProcDiagnostics():find("not a count of visible auras", 1, true), "diagnostic does not claim presence knowledge")
    putAura(state, 48108, 18, 1, true)
    equal(addon:GetRuntimeLoadDiagnostics().nativeAuraEnabledSlots, before.nativeAuraEnabledSlots,
        "actual aura trigger does not become a Lua visible-aura count")
    controls.procEnabled:Click()
    equal(addon:GetProcConfig().enabled, false, "checkbox saves spec-specific Proc enablement immediately")
    state:nativeTick()
    for _, slot in ipairs(state.auraSlots) do
        if slot.nativeBinding then
            equal(slot.container.enabled, false, "Proc native listeners are disabled")
            equal(slot.nativeBinding.enabled, false, "one shown native dirty pass clears the copied binding")
        end
    end
    truthy(addon.freeMoveTracking, "Proc checkbox does not disable class Free move")
    equal(addon:GetRuntimeLoadDiagnostics().nativeAuraEnabledSlots, 1, "only Free move receiver remains requested")
    controls.procEnabled:Click()
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "18.0", "checkbox reenable synchronizes the already active real aura")
    equal(addon:GetRuntimeLoadDiagnostics().nativeAuraSlots, before.nativeAuraSlots, "reenable reuses the same bounded native slots")
    truthy(panel.procStatus:GetText():find("Contextual tests", 1, true) and panel.procStatus:GetText():find("separate", 1, true), "working controls retain honest mode separation")
end)

test("missing or secret stock geometry disables Proc with precise diagnostics and safely resumes on layout recovery", function()
    local env, addon, state = mobilityLogin(212653,
        { charges = 0, maxCharges = 2, chargeStart = 95, chargeDuration = 20,
            cooldownStart = 100, cooldownDuration = 20, secretCharges = true, secretDuration = true }, { proc = {} })
    putAura(state, 48108, 19, 1, true)
    putAura(state, 375240, 19, 1, true)
    local frame = procFrame(addon, "mage_fire_hot_streak_left")
    local mobility = currentLive(addon)
    local nativeTimer, nativeAlpha, reads = mobility.durationBinding.duration, mobility.alpha, state.realReads
    local stock = env.SpellActivationOverlayFrame
    local saved = copy(addon.db)
    equal(procText(addon, state, frame.entryId), "19.0", "initial real Proc is correctly anchored")
    env.SpellActivationOverlayFrame = nil
    state:fire("UI_SCALE_CHANGED")
    equal(frame.auraHandle.enabled, false, "missing stock root disables native Proc instead of inventing a center")
    equal(procText(addon, state, frame.entryId), "", "old anchored timer does not survive missing geometry")
    truthy(addon:GetProcDiagnostics():find("stock Proc layout root", 1, true), "diagnostic identifies the missing stock layout root")
    equal(procText(addon, state, "free_move_mage"), "Free move", "missing Proc layout does not disable unrelated class receiver")
    state:advance(2)
    env.SpellActivationOverlayFrame = stock
    local getScale = stock.GetEffectiveScale
    stock.GetEffectiveScale = function() return secret(1.5) end
    state:fire("UI_SCALE_CHANGED")
    equal(frame.auraHandle.enabled, false, "secret layout scale is not compared or used for positioning")
    equal(procText(addon, state, frame.entryId), "", "secret geometry remains safely undisplayed")
    truthy(addon:GetProcDiagnostics():find("not available as public geometry", 1, true), "diagnostic identifies restricted geometry precisely")
    stock.GetEffectiveScale = getScale
    state:fire("UI_SCALE_CHANGED")
    equal(frame.auraHandle.enabled, true, "public stock geometry recovery resumes native slots")
    equal(procText(addon, state, frame.entryId), "17.0", "recovered timer follows actual continuing aura duration")
    truthy(not addon:GetProcDiagnostics():find("not available as public geometry", 1, true), "recovered diagnostics do not retain stale geometry blocker")
    equal(mobility.durationBinding.duration, nativeTimer, "geometry failure and recovery do not rebind Mobility time")
    equal(mobility.alpha, nativeAlpha, "geometry failure and recovery preserve secret Mobility visibility")
    equal(nativeText(addon), "No Shimmer\n13.0", "Mobility continues its actual existing recharge")
    equal(state.realReads, reads, "geometry updates do not query ordinary cooldowns or aura APIs")
    same(addon.db, saved, "temporary geometry limitations do not reset user appearance or coordinates")
    equal(#state.errors, 0, "secret geometry never reaches arithmetic or string conversion")
end)

test("Clearcasting uses the verified duration Aura with independently identified native stack graphics", function()
    for _, combat in ipairs({ false, true }) do
        for _, restricted in ipairs({ false, true }) do
            local env, addon, state = auraFixture(62)
            state.inCombat = combat
            putAura(state, 276743, 53, 5, restricted)
            putAura(state, 277726, 41, 3, restricted)
            putAura(state, 1277420, 67, 1, restricted)
            showProc(env, state, 1277420, 1027131, "LeftRight", 1)
            equal(procText(addon, state, "mage_arcane_clearcasting_left"), "", "unverified simultaneous candidate cannot supply the timer")
            putAura(state, 263725, 17, 3, restricted)
            equal(procText(addon, state, "mage_arcane_clearcasting_left"), "17.0", "left timer comes from actual duration Aura only")
            equal(procText(addon, state, "mage_arcane_clearcasting_right"), "17.0", "right timer uses same verified Aura, independent region")
            for _, slot in ipairs(state.auraSlots) do
                if slot.key == "mage_arcane_clearcasting_left" or slot.key == "mage_arcane_clearcasting_right" then
                    same(slot.filters.includeSpellIDs, { [263725] = true }, "native filter never chooses among unverified candidate IDs")
                end
            end
            putAura(state, 451038, 29, 1, restricted); putAura(state, 1277009, 11, 1, restricted)
            for _, definition in ipairs(addon:GetProcDefinitions()) do
                if definition.auraID ~= 263725 then
                    showProc(env, state, definition.overlayID, definition.textureID, definition.locationTypeName, definition.scale)
                    for _, entry in ipairs(definition.regions) do
                        equal(procText(addon, state, entry.id), definition.auraID == 451038 and "29.0" or "11.0",
                            "other user-confirmed Arcane effects keep their own duration source")
                    end
                end
            end
            state:advance(3)
            state.proc.auras[263725].applications = restricted and secret(2) or 2
            state:fire("UNIT_AURA", "player")
            equal(procText(addon, state, "mage_arcane_clearcasting_left"), "14.0", "partial consumption preserves remaining native timer")
            putAura(state, 263725, 23, 2, restricted)
            equal(procText(addon, state, "mage_arcane_clearcasting_right"), "23.0", "refresh binds real refreshed duration")
            state.proc.auras[263725] = nil; state:fire("UNIT_AURA", "player")
            equal(procText(addon, state, "mage_arcane_clearcasting_left"), "", "last consumption clears despite competing candidate auras remaining")
            putAura(state, 263725, 4, 1, restricted); state:advance(4)
            equal(procText(addon, state, "mage_arcane_clearcasting_right"), "", "natural expiry clears with no fixed lifetime")
            equal(state.realReads, 0, "neither combat nor secrecy combination queries restricted Aura data")
            equal(#state.errors, 0, "opaque IDs stacks and times remain native-owned")
        end
    end
end)

test("Clearcasting native graphic transitions do not let an old-owner HIDE clear a new active owner", function()
    local env, addon, state = auraFixture(62)
    putAura(state, 263725, 26, 3, true)
    showProc(env, state, 1277422, 1027133, "LeftRight", 1)
    equal(procText(addon, state, "mage_arcane_clearcasting_left"), "26.0", "three-stack graphic uses verified timer")
    state:advance(2)
    showProc(env, state, 1277421, 1027132, "LeftRight", 1)
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277422)
    equal(procText(addon, state, "mage_arcane_clearcasting_left"), "24.0", "old graphic owner cannot hide newer active region")
    equal(procText(addon, state, "mage_arcane_clearcasting_right"), "24.0", "both shared visual regions survive transition")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277421)
    equal(procText(addon, state, "mage_arcane_clearcasting_left"), "", "all observed owners hidden closes region gate")
    showProc(env, state, 1277420, 1027131, "LeftRight", 1)
    equal(procText(addon, state, "mage_arcane_clearcasting_left"), "24.0", "valid new SHOW clears earlier HIDE for this owner")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 276743)
    equal(procText(addon, state, "mage_arcane_clearcasting_right"), "24.0", "excluded old PvP graphic HIDE cannot affect normal mapping")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", nil)
    equal(procText(addon, state, "mage_arcane_clearcasting_right"), "", "native global HIDE clears every current owner")
    state:fire("PLAYER_ENTERING_WORLD")
    equal(procText(addon, state, "mage_arcane_clearcasting_right"), "24.0", "world reentry synchronizes real present Aura and documented bootstrap geometry")
    equal(#state.errors, 0, "multi-owner lifecycle makes no secret comparisons")
end)

local function regionEntry(addon, id)
    for _, entry in ipairs(addon:GetPreviewEntries()) do if entry.id == id then return entry end end
    error("Missing current configurable region " .. id)
end

local function regionRGB(addon, id)
    return addon:GetProcRegionColor(regionEntry(addon, id))
end

test("Proc regions independently persist validated RGB while an unset color remains a dynamic class fallback", function()
    local _, addon, state = auraFixture(62)
    local entries = {}
    for _, definition in ipairs(addon:GetProcDefinitions()) do
        for _, entry in ipairs(definition.regions) do entries[#entries + 1] = entry end
    end
    truthy(#entries >= 5, "Arcane provides separately identified inner outside and upper regions")
    local mobility = copy(addon:GetMobilityConfig())
    local style = copy(addon:GetProcConfig().style)
    for index, entry in ipairs(entries) do
        equal(addon:GetProcRegionColor(entry), nil, "default does not persist computed class RGB")
        local input = { r = index / (#entries + 1), g = 0.2, b = 0.8 }
        truthy(addon:SetProcRegionColor(entry, input), "each stable current-spec region accepts RGB")
        input.r = 1
        equal(addon:GetProcRegionColor(entry).r, index / (#entries + 1), "saved RGB is detached from caller table")
        local returned = addon:GetProcRegionColor(entry); returned.g = 1
        equal(addon:GetProcRegionColor(entry).g, 0.2, "color getter cannot mutate persisted settings")
    end
    for index, entry in ipairs(entries) do
        same(addon:GetProcRegionColor(entry), { r = index / (#entries + 1), g = 0.2, b = 0.8 }, "regions do not share colors")
        same(procFrame(addon, entry.id).auraHandle.font.textColor,
            { index / (#entries + 1), 0.2, 0.8, 1 }, "live native owned Font uses that region's RGB")
    end
    truthy(addon:SetProcRegionColor(entries[1], nil), "reset clears only selected optional RGB")
    equal(addon:GetProcConfig().regions[entries[1].id].color, nil, "reset stores no class RGB")
    same(procFrame(addon, entries[1].id).text.textColor, { 0.25, 0.78, 0.92, 1 }, "reset dynamically uses class color")
    same(addon:GetMobilityConfig(), mobility, "Proc color leaves all Mobility settings unchanged")
    same(addon:GetProcConfig().style, style, "per-region colors do not create per-region font settings")
    equal(state.realReads, 0, "color editing never queries real aura or cooldown state")
end)

test("RGB validation rejects malformed partial secret out-of-range and opacity values atomically", function()
    local _, addon = auraFixture(63)
    local entry = regionEntry(addon, "mage_fire_hot_streak_left")
    truthy(addon:SetProcRegionColor(entry, { r = 0, g = 1, b = 0.25 }), "closed RGB endpoints are valid")
    local baseline = copy(addon.db)
    for _, invalid in ipairs({ false, "red", 1, {}, { r = 0.2, g = 0.3 },
        { r = -0.1, g = 0.2, b = 0.3 }, { r = 1.1, g = 0.2, b = 0.3 },
        { r = 0/0, g = 0.2, b = 0.3 }, { r = math.huge, g = 0.2, b = 0.3 },
        { r = "0.2", g = 0.2, b = 0.3 }, { r = secret(0.2), g = 0.2, b = 0.3 },
        { r = 0.2, g = 0.3, b = 0.4, a = 0.5 }, { 0.2, 0.3, 0.4 } }) do
        equal(addon:SetProcRegionColor(entry, invalid), false, "malformed optional RGB rejected")
        same(addon.db, baseline, "invalid color patch leaves all saved configuration unchanged")
    end
    equal(addon:UpdateSettings({ proc = { regions = { [entry.id] = { color = { r = 0.1 } } } } }), false,
        "generic UpdateSettings also validates a complete RGB value")
    local forged = copy(entry); forged.id = "not_a_real_proc_region"
    equal(addon:SetProcRegionColor(forged, { r = 1, g = 0, b = 0 }), false, "unknown ID cannot create arbitrary config")
    forged = copy(entry); forged.specID = 62
    equal(addon:SetProcRegionColor(forged, { r = 1, g = 0, b = 0 }), false, "stale spec identity cannot write active config")
    forged = copy(entry); forged.class = "WARRIOR"
    equal(addon:SetProcRegionColor(forged, { r = 1, g = 0, b = 0 }), false, "foreign class cannot acquire current region identity")
    local free = addon:GetFreeMoveEntry()
    equal(addon:SetProcRegionColor(free, { r = 1, g = 0, b = 0 }), false, "Free move cannot use Proc-only color settings")
end)

test("shared Proc font updates preserve every region color and coordinate across world theme spec and reload", function()
    local env, addon, state = auraFixture(62)
    local left = regionEntry(addon, "mage_arcane_clearcasting_left")
    local right = regionEntry(addon, "mage_arcane_clearcasting_right")
    addon:SetProcRegionColor(left, { r = 1, g = 0.2, b = 0.1 })
    addon:SetProcRegionColor(right, { r = 0.1, g = 0.3, b = 1 })
    addon:UpdateSettings({ proc = { regions = { [left.id] = { position = { x = 17, y = -23 } },
        [right.id] = { position = { x = -29, y = 31 } } } } })
    local before = copy(addon:GetProcConfig().regions)
    options(addon); addon:SetPreview("all")
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 41 }, shadow = { enabled = false }, scale = 1.4 })
    for _, entry in ipairs({ left, right }) do
        equal(procFrame(addon, entry.id).text.font[2], 41, "one specialization font updates every live region")
        equal(addon.previewFrames[entry.id].text.font[2], 41, "Preview uses the same specialization font")
        same(addon.previewFrames[entry.id].text.textColor, procFrame(addon, entry.id).text.textColor, "live and Preview agree per region")
    end
    addon:StopPreview()
    state:fire("PLAYER_ENTERING_WORLD")
    addon:RefreshReminderClassColor()
    state.faction = "Horde"; state:fire("NEUTRAL_FACTION_SELECT_RESULT")
    addon:RefreshOptions()
    same(addon:GetProcConfig().regions, before, "world and automatic theme preserve regional colors and positions")
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    local fire = regionEntry(addon, "mage_fire_hot_streak_left")
    equal(addon:GetProcRegionColor(fire), nil, "new spec inherits no recently edited region RGB")
    addon:SetProcRegionColor(fire, { r = 0.8, g = 0.6, b = 0.2 })
    state.specID = 62; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    same(addon:GetProcConfig().regions, before, "switching back restores exact Arcane settings")
    local _, reloaded = login(copy(env.CarGOUIDB), false, { specID = 62, proc = {} })
    same(reloaded:GetProcConfig().regions, before, "reload preserves all regional optional colors and coordinates")
    equal(reloaded:GetProcConfig().style.font.size, 41, "reload preserves shared spec font")
    same(procFrame(reloaded, left.id).text.textColor, { 1, 0.2, 0.1, 1 }, "native Font initialization resolves saved region RGB")
    same(procFrame(reloaded, right.id).text.textColor, { 0.1, 0.3, 1, 1 }, "native Font reuse preserves independent right RGB")
end)

test("all currently defined Fire Frost and Arcane regions accept colors without triggering a Buff", function()
    local _, addon, state = auraFixture(62)
    local ids = {}
    for _, spec in ipairs({ 62, 63, 64 }) do
        state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        for _, definition in ipairs(addon:GetProcDefinitions()) do
            for _, entry in ipairs(definition.regions) do
                local allowed = false
                for _, choice in ipairs(addon:GetPreviewEntries()) do if choice.id == entry.id then allowed = true end end
                if allowed then
                    truthy(not ids[entry.id], "region keys are stable and globally descriptive")
                    ids[entry.id] = true
                    truthy(addon:SetProcRegionColor(entry, { r = 0.2, g = 0.4, b = 0.6 }), "current supported region accepts saved RGB while absent")
                    same(addon:GetProcRegionColor(entry), { r = 0.2, g = 0.4, b = 0.6 }, "region is configurable independently of actual aura presence")
                end
            end
        end
    end
    truthy(ids.mage_fire_heating_up_left and ids.mage_fire_pyroclasm_top and ids.mage_frost_fingers_right
        and ids.mage_frost_brain_freeze_top and ids.mage_arcane_clearcasting_right,
        "the shared mechanism covers small brackets top graphics both Frost regions and Clearcasting")
    equal(state.realReads, 0, "defining or editing all current region colors never reads Buff data")
end)

test("color-only writes and temporary drafts never change native binding event subscription or gate alpha", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {} })
    putAura(state, 48108, 19, 1, true); putAura(state, 375240, 13, 1, true)
    local left = regionEntry(addon, "mage_fire_hot_streak_left")
    local right = procFrame(addon, "mage_fire_hot_streak_right")
    local target = procFrame(addon, left.id)
    local live, free = currentLive(addon), procFrame(addon, "free_move_mage")
    local samples, colors = {}, {}
    for _, pool in pairs(addon.reminderFrames) do for _, frame in pairs(pool) do
        samples[frame] = { alpha = frame.alpha, writes = frame.alphaWrites, handle = frame.auraHandle,
            duration = frame.durationBinding and frame.durationBinding.duration }
        colors[frame] = frame.text.textColor
    end end
    local bindings, slots, reads = #state.bindings, #state.auraSlots, state.realReads
    local listeners = addon:GetEventDiagnostics().callbacks
    local nativeBindings = {}
    for _, slot in ipairs(state.auraSlots) do
        nativeBindings[slot] = { binding = slot.nativeBinding, duration = slot.nativeBinding and slot.nativeBinding.duration }
    end
    truthy(addon:SetProcRegionColorPreview(left, { r = 1, g = 0.1, b = 0.2 }), "picker draft updates live style")
    equal(addon:GetProcRegionColor(left), nil, "temporary picker draft is not saved")
    same(target.text.textColor, { 1, 0.1, 0.2, 1 }, "draft reaches owned native Font")
    addon:SetProcRegionColorPreview(left, nil)
    same(target.text.textColor, { 0.25, 0.78, 0.92, 1 }, "draft cancel restores dynamic class fallback")
    truthy(addon:UpdateSettings({ proc = { regions = { [left.id] = { color = { r = 0.1, g = 0.8, b = 0.4 } } } } }),
        "generic color-only patch uses the targeted style path")
    same(target.text.textColor, { 0.1, 0.8, 0.4, 1 }, "direct patch reaches same color resolver")
    equal(right.text.textColor, colors[right], "editing left does not write the right Font")
    same(live.text.textColor, { 0.25, 0.78, 0.92, 1 }, "Mobility remains fixed class color")
    same(free.text.textColor, { 0.25, 0.78, 0.92, 1 }, "Free move remains fixed class color")
    for frame, sample in pairs(samples) do
        equal(frame.alpha, sample.alpha, "color-only mutation preserves existing opaque/public gate")
        equal(frame.alphaWrites, sample.writes, "color-only mutation does not reapply alpha")
        equal(frame.auraHandle, sample.handle, "native container is not replaced")
        if frame.durationBinding then equal(frame.durationBinding.duration, sample.duration, "Mobility native timer is not rebound") end
    end
    for slot, sample in pairs(nativeBindings) do
        equal(slot.nativeBinding, sample.binding, "color-only mutation preserves copied native binding identity")
        if slot.nativeBinding then equal(slot.nativeBinding.duration, sample.duration, "color-only mutation preserves original Aura duration object") end
    end
    equal(#state.bindings, bindings, "editing RGB adds no native bindings")
    equal(#state.auraSlots, slots, "editing RGB adds no native containers")
    equal(state.realReads, reads, "editing RGB performs no ordinary state reads")
    equal(addon:GetEventDiagnostics().callbacks, listeners, "editing RGB adds no business listeners")
end)

test("saved malformed optional RGB is removed while valid aliases detach and old coordinates remain intact", function()
    local _, seed = auraFixture(62)
    local saved = copy(seed.db)
    local shared = { r = 0.2, g = 0.5, b = 0.7 }
    local regions = saved.classes.MAGE.proc[62].regions
    regions.mage_arcane_clearcasting_left = { position = { x = 37, y = -41 }, color = shared }
    regions.mage_arcane_clearcasting_right = { position = { x = -19, y = 23 }, color = shared }
    local badID
    for _, definition in ipairs(seed:GetProcDefinitions()) do
        for _, entry in ipairs(definition.regions) do
            if entry.id ~= "mage_arcane_clearcasting_left" and entry.id ~= "mage_arcane_clearcasting_right" then badID = entry.id end
        end
    end
    regions[badID] = { position = { x = 3, y = 4 }, color = { r = 0/0, g = 0.2, b = 0.3 } }
    local _, addon = login(saved, false, { specID = 62, proc = {} })
    local current = addon:GetProcConfig().regions
    truthy(current.mage_arcane_clearcasting_left.color ~= current.mage_arcane_clearcasting_right.color,
        "historically aliased colors become independent mutable tables")
    same(current.mage_arcane_clearcasting_left.position, { anchor = "CENTER", x = 37, y = -41 }, "normalization keeps left offset")
    equal(current[badID].color, nil, "invalid saved optional color falls back without persisting a class RGB")
    equal(current[badID].position.x, 3, "invalid optional color never removes regional position")
    addon:SetProcRegionColor(regionEntry(addon, "mage_arcane_clearcasting_left"), { r = 1, g = 0, b = 0 })
    same(current.mage_arcane_clearcasting_right.color, shared, "editing left does not mutate right saved alias")
end)

test("native picker previews immediately saves only native Okay and restores prior color on cancel or hide", function()
    local env, addon = auraFixture(63)
    options(addon); addon:SelectOptionsCategory("proc")
    local entry = regionEntry(addon, "mage_fire_hot_streak_left")
    addon:SetPreview("single", entry.id)
    truthy(addon:OpenProcColorPicker(entry), "native supported picker opens for a current region")
    local picker = env.ColorPickerFrame
    equal(picker.hasOpacity, false, "Proc picker exposes no alpha setting")
    addon:SetProcRegionColorPreview(entry, { r = 0.6, g = 0.2, b = 0.8 })
    -- User-facing native callback, not a direct configuration write.
    picker.rgb = { 0.6, 0.2, 0.8 }; picker.swatchFunc()
    equal(addon:GetProcRegionColor(entry), nil, "intermediate swatch changes never save")
    same(addon.previewFrames[entry.id].text.textColor, { 0.6, 0.2, 0.8, 1 }, "picker draft updates external Preview")
    picker.Footer.OkayButton:Click()
    same(addon:GetProcRegionColor(entry), { r = 0.6, g = 0.2, b = 0.8 }, "native Okay commits the current region")
    truthy(not picker:IsShown(), "native Okay closes picker normally")
    truthy(addon:OpenProcColorPicker(entry), "picker reopens using saved RGB")
    picker.rgb = { 1, 1, 0 }; picker.swatchFunc(); picker.Footer.CancelButton:Click()
    same(addon:GetProcRegionColor(entry), { r = 0.6, g = 0.2, b = 0.8 }, "Cancel preserves original persisted RGB")
    same(addon.previewFrames[entry.id].text.textColor, { 0.6, 0.2, 0.8, 1 }, "Cancel restores original Preview RGB")
    addon:OpenProcColorPicker(entry); picker.rgb = { 0, 1, 0 }; picker.swatchFunc(); picker:Hide()
    same(addon:GetProcRegionColor(entry), { r = 0.6, g = 0.2, b = 0.8 }, "Escape or unaccepted Hide never commits")
    same(addon.previewFrames[entry.id].text.textColor, { 0.6, 0.2, 0.8, 1 }, "Escape clears temporary draft")
end)

test("picker sessions pin region and spec and cannot write after selection context or Options closes", function()
    local env, addon, state = auraFixture(62)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("proc")
    local left, right = regionEntry(addon, "mage_arcane_clearcasting_left"), regionEntry(addon, "mage_arcane_clearcasting_right")
    addon:OpenProcColorPicker(left)
    local stale = env.ColorPickerFrame.swatchFunc
    state:pickerChange(1, 0, 0)
    choose(controls.procEntry, right.id)
    addon:OpenProcColorPicker(right)
    stale()
    equal(addon:GetProcRegionColor(left), nil, "replaced session cannot commit old region")
    equal(addon:GetProcRegionColor(right), nil, "old callback cannot write new region")
    state:pickerChange(0, 0, 1); env.ColorPickerFrame.Footer.OkayButton:Click()
    same(addon:GetProcRegionColor(right), { r = 0, g = 0, b = 1 }, "current pinned session saves correct region")
    choose(controls.procEntry, left.id)
    addon:OpenProcColorPicker(left); state:pickerChange(1, 1, 0)
    stale = env.ColorPickerFrame.swatchFunc
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    stale()
    equal(regionRGB(addon, "mage_fire_hot_streak_left"), nil, "old Arcane callback cannot touch new Fire scope")
    truthy(not env.ColorPickerFrame:IsShown(), "spec switch ends this addon's picker session")
    local fire = regionEntry(addon, "mage_fire_hot_streak_left")
    addon:OpenProcColorPicker(fire); state:pickerChange(0, 1, 1); stale = env.ColorPickerFrame.swatchFunc
    panel:Hide(); stale()
    equal(addon:GetProcRegionColor(fire), nil, "closing Options cancels pending draft")
    truthy(not env.ColorPickerFrame:IsShown(), "closing Options ends owned picker")
    state.specID = 62; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(regionRGB(addon, left.id), nil, "unconfirmed old Arcane draft was never persisted")
    same(regionRGB(addon, right.id), { r = 0, g = 0, b = 1 }, "confirmed independent region persists through context changes")
end)

test("another addon's native picker ownership supersedes only our draft without callback or UI interference", function()
    local env, addon, state = auraFixture(63)
    local panel = options(addon); addon:SelectOptionsCategory("proc")
    local entry = regionEntry(addon, "mage_fire_hot_streak_left")
    addon:OpenProcColorPicker(entry); state:pickerChange(1, 0, 0)
    local picker, calls = env.ColorPickerFrame, 0
    local previous = picker.swatchFunc
    local external = { token = "other addon" }
    local externalSwatch = function() calls = calls + 1 end
    local externalCancel = function() calls = calls + 10 end
    picker:SetupColorPickerAndShow({ r = 0.7, g = 0.8, b = 0.9, hasOpacity = true,
        opacity = 0.4, extraInfo = external, swatchFunc = externalSwatch, cancelFunc = externalCancel })
    previous(); addon:CancelProcColorPicker(); panel:Hide()
    equal(picker.extraInfo, external, "later addon keeps native session token")
    equal(picker.swatchFunc, externalSwatch, "later addon keeps swatch callback")
    equal(picker.cancelFunc, externalCancel, "later addon keeps cancellation callback")
    truthy(picker:IsShown(), "our context cleanup cannot hide another addon's picker")
    equal(picker.hasOpacity, true, "our cleanup does not change another addon's options")
    equal(addon:GetProcRegionColor(entry), nil, "replaced session never writes user configuration")
    same(procFrame(addon, entry.id).text.textColor, { 0.25, 0.78, 0.92, 1 }, "replaced session clears only our temporary draft")
    picker.Footer.OkayButton:Click()
    equal(calls, 1, "other addon's native Okay callback still runs once")
    equal(addon:GetProcRegionColor(entry), nil, "global Okay hook cannot commit a foreign session")
end)

test("Proc color controls name exact regions reset only that region and unchanged Okay never saves class defaults", function()
    local env, addon, state = auraFixture(62)
    local panel, controls = options(addon); addon:SelectOptionsCategory("proc")
    local left = regionEntry(addon, "mage_arcane_clearcasting_left")
    local right = regionEntry(addon, "mage_arcane_clearcasting_right")
    equal(panel.procColorSelection:GetText(), left.label, "color row names current ability and region")
    controls.procColor:Click()
    truthy(env.ColorPickerFrame:IsShown(), "existing page swatch opens native picker")
    env.ColorPickerFrame.Footer.OkayButton:Click()
    equal(addon:GetProcRegionColor(left), nil, "accepting unchanged default does not persist current character class RGB")
    addon:SetProcRegionColor(left, { r = 1, g = 0, b = 0 })
    addon:SetProcRegionColor(right, { r = 0, g = 0, b = 1 })
    addon:UpdateSettings({ reminders = { [left.id] = { position = { x = 81, y = -23 } } } })
    local style = copy(addon:GetProcConfig().style)
    controls.procColorReset:Click()
    equal(addon:GetProcRegionColor(left), nil, "Use class color removes selected optional RGB")
    same(addon:GetProcRegionColor(right), { r = 0, g = 0, b = 1 }, "reset never clears another region")
    equal(addon:GetReminderPosition(left).x, 81, "reset leaves saved coordinates")
    same(addon:GetProcConfig().style, style, "reset leaves shared font configuration")
    choose(controls.procEntry, right.id)
    equal(panel.procColorSelection:GetText(), right.label, "switching dropdown shows exact next region name")
    same(controls.procColor.swatch.color, { 0, 0, 1, 1 }, "next region swatch restores its saved color")
    local hooks = addon.procColorPickerHooked
    local frames, fonts, bindings = #state.frames, #state.auraFonts, #state.bindings
    for index = 1, 25 do
        controls.procColor:Click(); state:pickerChange(index / 25, 0.5, 0.2)
        env.ColorPickerFrame.Footer.CancelButton:Click()
    end
    equal(addon.procColorPickerHooked, hooks, "native picker hooks remain installed once")
    equal(#state.frames, frames, "repeated edits create no persistent per-session frames")
    equal(#state.auraFonts, fonts, "repeated edits reuse owned region fonts")
    equal(#state.bindings, bindings, "repeated edits create no duration bindings")
end)

test("reentrant foreign cancellation keeps its newer native picker and unavailable picker never changes settings", function()
    local env, addon = auraFixture(63)
    options(addon); addon:SelectOptionsCategory("proc")
    local entry = regionEntry(addon, "mage_fire_hot_streak_left")
    local picker, newer, cancelled = env.ColorPickerFrame, {}, 0
    local newSwatch = function() end
    local newCancel = function() end
    picker:SetupColorPickerAndShow({ r = 0.1, g = 0.2, b = 0.3, extraInfo = {}, swatchFunc = function() end,
        cancelFunc = function()
            cancelled = cancelled + 1
            picker:SetupColorPickerAndShow({ r = 0.9, g = 0.8, b = 0.7, extraInfo = newer,
                swatchFunc = newSwatch, cancelFunc = newCancel })
        end })
    equal(addon:OpenProcColorPicker(entry), false, "cancel-triggered newer edit is not silently replaced")
    equal(cancelled, 1, "old foreign edit is cancelled once")
    equal(picker.extraInfo, newer, "newer owner retains native session token")
    equal(picker.swatchFunc, newSwatch, "newer owner retains callbacks")
    truthy(picker:IsShown(), "newer edit remains visible")
    equal(addon.procColorPickerSession, nil, "our attempted edit allocates no orphan session")
    local _, unavailable = login(nil, false, { specID = 63, proc = {}, pickerUnavailable = true })
    local _, controls = options(unavailable); unavailable:SelectOptionsCategory("proc")
    truthy(not controls.procColor:IsEnabled(), "missing native picker disables only the swatch operation")
    local saved = copy(unavailable.db)
    equal(unavailable:OpenProcColorPicker(regionEntry(unavailable, entry.id)), false, "unsupported native picker is reported")
    same(unavailable.db, saved, "missing native picker never modifies user settings")
    truthy(unavailable.procTracking, "native picker absence does not stop real Proc monitoring")
end)

test("Clearcasting diagnostics retain bounded public graph evidence build mapping gates and no secret payloads", function()
    local env, addon, state = auraFixture(62)
    local slots, bindings = #state.auraSlots, #state.bindings
    local callbacks = addon:GetEventDiagnostics().callbacks
    for index = 1, 42 do
        showProc(env, state, 1277420, 1027131, "LeftRight", 1)
        state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 1277420)
    end
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", secret(1277420), secret(1027131), secret(1), secret(1))
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", secret(1277421))
    equal(#addon.procEventTrace, 16, "diagnostic graphic-event retention stays bounded")
    local diagnostics = addon:GetProcDiagnostics()
    for _, expected in ipairs({ "build=99999", "timer aura=263725", "1277420", "1277421", "1277422",
        "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right", "restricted", "no aura payloads" }) do
        truthy(diagnostics:find(expected, 1, true), "targeted diagnostic records public evidence: " .. expected)
    end
    equal(#state.auraSlots, slots, "repeated graphic events do not allocate native slots")
    equal(#state.bindings, bindings, "repeated graphic events do not allocate bindings")
    equal(addon:GetEventDiagnostics().callbacks, callbacks, "diagnostic capture adds no listeners")
    equal(state.realReads, 0, "diagnostic never queries auras")
    equal(#state.errors, 0, "restricted event payloads are rejected before formatting")
end)

test("first combat Options requests queue once without creating any controls or persistent settings", function()
    local env, addon, state = login()
    addon:UpdateSettings({ mobility = { enabled = false } })
    local frames, messages = #state.frames, #state.messages
    local callbacks = addon:GetEventDiagnostics().callbacks
    local saved = copy(addon.db)
    state:fire("PLAYER_REGEN_DISABLED")
    for index = 1, 10 do
        if index % 2 == 0 then env.SlashCmdList.CARGOUI("") else addon:ToggleOptions() end
    end
    equal(addon:CreateOptions(), nil, "direct factory entry cannot bypass combat guard")
    equal(addon:OpenOptions(), false, "explicit open entry cannot bypass combat guard")
    equal(env.SLASH_CARGOUI1, "/cui", "short alias uses the shared command handler")
    equal(env.SLASH_CARGOUI2, "/cargoui", "long alias uses the same handler")
    truthy(addon.pendingOptionsOpen, "ten requests retain one session request")
    equal(addon.optionsFrame, nil, "combat never creates the Options root or descendants")
    equal(#state.frames, frames, "queued requests create no control frames")
    equal(#state.messages, messages + 1, "one queue notification per pending cycle")
    equal(addon:GetEventDiagnostics().callbacks, callbacks + 1, "one bounded deferred-open callback")
    equal(state:activeTimers(), 0, "queued requests start no polling or premature retry")
    same(addon.db, saved, "session request writes no SavedVariables")
    state:fire("PLAYER_REGEN_ENABLED")
    local panel = addon.optionsFrame
    truthy(panel and panel:IsShown(), "first unlocked event opens the queued panel")
    truthy(not addon.pendingOptionsOpen, "successful explicit open consumes the pending request")
    local created = #state.frames
    addon:OpenOptions(); addon:OpenOptions()
    truthy(panel:IsShown(), "explicit opens are idempotent and cannot toggle visible Options closed")
    equal(#state.frames, created, "explicit opens reuse existing panel")
    panel:Hide(); state:fire("PLAYER_REGEN_ENABLED")
    equal(panel:IsShown(), false, "a later combat-end event cannot reopen a consumed request")
end)

test("combat request retries once at the unlock boundary and rechecks combat before deferred execution", function()
    local env, addon, state = login()
    addon:UpdateSettings({ mobility = { enabled = false } })
    state:fire("PLAYER_REGEN_DISABLED"); addon:OpenOptions()
    local boundaryLocked = true
    env.InCombatLockdown = function() return state.inCombat or boundaryLocked end
    state:fire("PLAYER_REGEN_ENABLED")
    equal(addon.optionsFrame, nil, "event receipt alone does not override a still-locked client")
    equal(state:activeTimers(), 1, "one tracked next-tick boundary retry")
    local scheduled = state.timers
    state:fire("PLAYER_REGEN_ENABLED")
    equal(state:activeTimers(), 1, "duplicate boundary events do not duplicate a pending retry")
    equal(state.timers, scheduled, "duplicate boundary event allocates no extra timer")
    state:flushTimers()
    equal(addon.optionsFrame, nil, "still-locked retry never opens controls")
    truthy(addon.pendingOptionsOpen, "still-locked retry retains the request for a later actual unlock")
    equal(state:activeTimers(), 0, "retry does not recursively schedule itself")
    boundaryLocked = false
    state:fire("PLAYER_REGEN_ENABLED")
    truthy(addon.optionsFrame and addon.optionsFrame:IsShown(), "later unlocked event opens exactly once")
    addon.optionsFrame:Hide()
    state:fire("PLAYER_REGEN_DISABLED"); addon:OpenOptions()
    boundaryLocked = true; state:fire("PLAYER_REGEN_ENABLED")
    equal(state:activeTimers(), 1, "a new queued cycle has its own bounded boundary retry")
    state:fire("PLAYER_REGEN_DISABLED"); boundaryLocked = false
    state:flushTimers()
    equal(addon.optionsFrame:IsShown(), false, "combat reentry before callback blocks deferred open")
    truthy(addon.pendingOptionsOpen, "combat reentry does not discard the user's request")
    state:fire("PLAYER_REGEN_ENABLED")
    truthy(addon.optionsFrame:IsShown(), "next genuine unlock fulfills preserved request")
end)

test("manual fulfillment cancels the pending boundary retry without toggling the visible panel", function()
    local env, addon, state = login()
    addon:UpdateSettings({ mobility = { enabled = false } })
    state:fire("PLAYER_REGEN_DISABLED"); addon:OpenOptions()
    local locked = true
    env.InCombatLockdown = function() return state.inCombat or locked end
    state:fire("PLAYER_REGEN_ENABLED")
    equal(state:activeTimers(), 1, "boundary retry exists before manual fulfillment")
    locked = false; addon:OpenOptions()
    local panel = addon.optionsFrame
    truthy(panel and panel:IsShown(), "explicit open fulfills pending request immediately when safe")
    equal(state:activeTimers(), 0, "successful open cancels stale retry handle")
    state:flushTimers(); state:fire("PLAYER_REGEN_ENABLED")
    truthy(panel:IsShown(), "stale callback or later event cannot toggle visible panel closed")
    truthy(not addon.pendingOptionsOpen, "request is consumed once")
    equal(#state.errors, 0, "cancelled stale work is harmless")
end)

test("combat closure cleans drag keyboard menus picker draft and Test Mode without saving uncommitted edits", function()
    local env, addon, state = auraFixture(62)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("proc")
    local entry = regionEntry(addon, "mage_arcane_clearcasting_left")
    addon:SetProcRegionColor(entry, { r = 0.1, g = 0.2, b = 0.9 })
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 39 }, scale = 1.3 })
    addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = 41, y = -29 } } } })
    truthy(addon:SetPreview("all"), "Test Mode is active before combat")
    controls.procColor:Click(); state:pickerChange(1, 0, 0)
    controls.procEntry:Click()
    truthy(controls.procEntry.menu:IsShown(), "region menu is open before cleanup")
    typeText(controls.procPositionX, "918"); controls.procPositionX.editBox:SetFocus()
    addon:BeginOptionsDrag("LeftButton")
    panel.mockCenter = { 1003, 517 }
    local savedProc = copy(addon:GetProcConfig())
    local savedMobility = copy(addon:GetMobilityConfig())
    state:fire("PLAYER_REGEN_DISABLED"); state:flushTimers()
    equal(panel:IsShown(), false, "entering combat closes the entire Options window")
    truthy(not panel.dragging and not panel.moving and state.movingFrame == nil, "combat cleanup ends dragging")
    equal(controls.procPositionX.editBox:HasFocus(), false, "combat cleanup releases keyboard focus")
    for _, dropdown in ipairs(panel.dropdowns) do equal(dropdown.menu:IsShown(), false, "all menus close") end
    equal(env.ColorPickerFrame:IsShown(), false, "owned native picker closes")
    equal(addon.procColorPickerSession, nil, "owned picker callbacks and session are detached")
    equal(addon.procRegionColorPreview, nil, "temporary color draft is discarded")
    equal(addon.previewState.mode, "off", "combat closure stops Test Mode")
    equal(countKeys(visiblePreviews(addon)), 0, "all TEST sample frames are hidden")
    equal(panel.titleAnimation:IsPlaying(), false, "combat closure stops title animation")
    same(addon:GetProcConfig(), savedProc, "committed Proc RGB font and coordinates survive")
    same(addon:GetMobilityConfig(), savedMobility, "unsubmitted input cannot change Mobility settings")
    truthy(not addon.pendingOptionsOpen, "automatic hiding does not create a reopening request")
    state:fire("PLAYER_REGEN_ENABLED")
    equal(panel:IsShown(), false, "automatic hiding alone never reopens at combat end")
    addon:OpenOptions()
    equal(tonumber(controls.procPositionX.editBox:GetText()), savedProc.regions[entry.id].position.x, "reopen restores saved value rather than discarded text")
    same(procFrame(addon, entry.id).text.textColor, { 0.1, 0.2, 0.9, 1 }, "cancel restores committed live region RGB")
end)

test("combat closing Options leaves native Proc Mobility and Free move timing active for public and secret data", function()
    for _, restricted in ipairs({ false, true }) do
        local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
            chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
            secretCharges = restricted, secretDuration = restricted }, { proc = {} })
        putAura(state, 48108, 19, 1, restricted); putAura(state, 375240, 11, 1, restricted)
        local panel = options(addon)
        local live = currentLive(addon)
        local nativeBindings = {}
        for _, slot in ipairs(state.auraSlots) do nativeBindings[slot] = slot.nativeBinding end
        local slots, bindings = #state.auraSlots, #state.bindings
        state:fire("PLAYER_REGEN_DISABLED"); state:flushTimers()
        equal(panel:IsShown(), false, "Options combat lifecycle is independent of data secrecy")
        truthy(addon.mobilityTracking and addon.procTracking and addon.freeMoveTracking, "all real monitors remain active")
        equal(currentLive(addon), live, "real Mobility frame is reused")
        equal(#state.auraSlots, slots, "closing Options does not replace native aura containers")
        equal(#state.bindings, bindings, "closing Options does not allocate native bindings")
        for slot, binding in pairs(nativeBindings) do equal(slot.nativeBinding, binding, "native copied binding identity preserved") end
        state:advance(3)
        equal(nativeText(addon), "No Shimmer\n12.0", "accepted real recharge continues from original time")
        equal(procText(addon, state, "mage_fire_hot_streak_left"), "16.0", "real Proc duration continues independently")
        equal(procText(addon, state, "free_move_mage"), "Free move", "native receiver remains active")
        state.proc.auras[48108] = nil; state.proc.auras[375240] = nil; state:fire("UNIT_AURA", "player")
        equal(procText(addon, state, "mage_fire_hot_streak_left"), "", "real consumption still clears closed-panel Proc")
        equal(procText(addon, state, "free_move_mage"), "", "real consumption still clears closed-panel receiver")
        equal(#state.errors, 0, "combat plus secret/public data causes no lifecycle errors")
    end
end)

test("pending Options opens resolve current specialization and never persist across reload", function()
    local env, addon, state = auraFixture(62)
    local entry = regionEntry(addon, "mage_arcane_clearcasting_left")
    addon:SetProcRegionColor(entry, { r = 0.8, g = 0.1, b = 0.6 })
    local arcane = copy(addon:GetProcConfig())
    options(addon); addon:SelectOptionsCategory("proc")
    state:fire("PLAYER_REGEN_DISABLED"); addon:OpenOptions()
    truthy(addon.pendingOptionsOpen, "explicit request after combat close queues reopening")
    local queuedSaved = copy(env.CarGOUIDB)
    equal(queuedSaved.pendingOptionsOpen, nil, "pending intent is not stored in account data")
    equal(queuedSaved.options.pendingOptionsOpen, nil, "pending intent is not stored in shell settings")
    local _, reloaded, fresh = login(queuedSaved, false, { specID = 62, proc = {} })
    truthy(not reloaded.pendingOptionsOpen, "reload starts with no stale pending intent")
    fresh:fire("PLAYER_REGEN_ENABLED")
    equal(reloaded.optionsFrame, nil, "reload never fulfills an old-session queued request")
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    state:fire("PLAYER_REGEN_ENABLED")
    local panel = addon.optionsFrame
    truthy(panel:IsShown(), "queued request opens after current context is ready")
    local selected = addon:GetSelectedProcColorEntry()
    truthy(selected and selected.specID == 63, "deferred open selects current Fire regions, not stale Arcane")
    equal(panel.themeWatching, true, "current theme lifecycle starts on deferred actual show")
    same(addon.db.classes.MAGE.proc[62], arcane, "context-aware reopen preserves old spec RGB font and coordinates")
end)

test("repeated Options combat queues remain bounded and each successful cycle permits one new notice", function()
    local _, addon, state = login()
    addon:UpdateSettings({ mobility = { enabled = false } })
    addon:OpenOptions(); addon.optionsFrame:Hide()
    local frames, baseline = #state.frames, addon:GetEventDiagnostics().callbacks
    local messages = #state.messages
    for cycle = 1, 20 do
        state:fire("PLAYER_REGEN_DISABLED")
        for request = 1, 10 do addon:ToggleOptions() end
        equal(#state.messages, messages + cycle, "one queue notice per new successful cycle")
        equal(addon:GetEventDiagnostics().callbacks, baseline + 1, "queued cycle adds one deferred listener")
        equal(state:activeTimers(), 0, "ordinary combat request does not start timers")
        state:fire("PLAYER_REGEN_ENABLED")
        truthy(addon.optionsFrame:IsShown(), "queued cycle opens once when unlocked")
        addon.optionsFrame:Hide()
        equal(addon:GetEventDiagnostics().callbacks, baseline, "successful consumption and close release temporary listeners")
        equal(#state.frames, frames, "all cycles reuse existing Options and controls")
        equal(state:activeTimers(), 0, "all cycles leave no running work")
    end
end)

test("closing dragged Options without TEST saves only shell position and never reconfigures native monitors", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {} })
    putAura(state, 48108, 19, 1, true); putAura(state, 375240, 11, 1, true)
    local panel = options(addon)
    addon:BeginOptionsDrag("LeftButton"); panel.mockCenter = { 1008, 516 }
    local live = currentLive(addon)
    local alpha, duration = live.alpha, live.durationBinding.duration
    local alphaWrites, durationWrites = live.alphaWrites, live.durationBinding.durationWrites
    local reads, native = state.realReads, {}
    local slots, bindings, config = #state.auraSlots, #state.bindings, copy(addon.db.classes)
    for _, slot in ipairs(state.auraSlots) do native[slot] = slot.nativeBinding end
    for _, method in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "ApplySettings" }) do
        addon[method] = function() error("Options-only close cannot reconfigure gameplay: " .. method) end
    end
    state.inCombat = true
    addon:CloseOptions()
    truthy(not panel:IsShown() and not panel.dragging and not panel.moving, "close ends panel and drag state")
    truthy(addon.db.options.position.x ~= 0 or addon.db.options.position.y ~= 0, "actual dragged shell position is saved")
    same(addon.db.classes, config, "shell-only save preserves every class/spec/region setting")
    equal(state.realReads, reads, "shell-only save does not query live state")
    equal(live.alpha, alpha, "close preserves secret native Mobility alpha")
    equal(live.alphaWrites, alphaWrites, "close performs no replacement visibility write")
    equal(live.durationBinding.duration, duration, "close preserves existing native recharge object")
    equal(live.durationBinding.durationWrites, durationWrites, "close never restarts native countdown")
    equal(#state.auraSlots, slots, "close creates no native Aura container")
    equal(#state.bindings, bindings, "close creates no native timer binding")
    for slot, binding in pairs(native) do equal(slot.nativeBinding, binding, "native Proc/Free move bindings remain owned and stable") end
    equal(#state.errors, 0, "no unwanted gameplay reconfiguration or frame access")
end)

test("combat event snapshot cleanup stops TEST once even when old preview callbacks remain in dispatch", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {} })
    options(addon); addon:SetPreview("all")
    local refresh, stop = addon.RefreshMobility, addon.StopPreview
    local refreshes, stops = 0, 0
    addon.RefreshMobility = function(self, ...) refreshes = refreshes + 1; return refresh(self, ...) end
    addon.StopPreview = function(self, ...) stops = stops + 1; return stop(self, ...) end
    state:fire("PLAYER_REGEN_DISABLED")
    equal(stops, 1, "shared event snapshot cannot stop the already-cleared Preview twice")
    equal(refreshes, 1, "one immediate real-state restoration follows ending TEST")
    equal(addon.previewState.mode, "off", "TEST is fully stopped")
    equal(addon.optionsFrame:IsShown(), false, "Options remains combat-closed")
    state:flushTimers()
    equal(nativeText(addon), "No Shimmer\n15.0", "legitimate gameplay event coalescer retains true original recharge")
    equal(#state.errors, 0, "old snapshot callbacks remain harmless after unregister")
end)

test("non-Mage Frost Death Knight tracks separately filtered finite native Proc regions in combat", function()
    local env, addon, state = login(nil, false, { classToken = "DEATHKNIGHT", specID = 251,
        proc = {}, procKnown = { [59057] = true, [51128] = true },
        mobility = { known = {}, spells = {} },
        allowedSpellIDs = { [48265] = true, [444347] = true, [212552] = true } })
    truthy(addon:UpdateSettings({ mobility = { enabled = false } }), "Mobility can be disabled independently")
    equal(#addon:GetProcDefinitions(), 3, "current spec instantiates three audited providers")
    truthy(addon.procTracking, "real non-Mage Proc remains active without Mobility")
    equal(#state.spellReads, 0, "Proc activation does not query movement cooldowns")
    for _, record in ipairs(state.procKnownReads) do
        truthy(record.id == 59057 or record.id == 51128, "learning checks only actual DK drivers, never hidden second aura438833")
    end
    local rime = "deathknight_frost_rime_top"
    local left, right = "deathknight_frost_killing_machine_left", "deathknight_frost_killing_machine_second_right"
    state.inCombat = true
    putAura(state, 59052, 11, 1, true)
    putAura(state, 51124, 9, 2, true)
    putAura(state, 438833, 7, 1, true)
    showProc(env, state, 59052, 450930, "Top")
    showProc(env, state, 51124, 458740, "Left")
    showProc(env, state, 438833, 458740, "Right")
    equal(procText(addon, state, rime), "11.0", "Rime uses its real native duration")
    equal(procText(addon, state, left), "9.0", "left provider is independent")
    equal(procText(addon, state, right), "7.0", "right uses its own finite aura, not inferred stacks")
    state.proc.auras[438833] = nil; state:fire("UNIT_AURA", "player")
    equal(procText(addon, state, right), "", "consuming right aura immediately clears only right")
    equal(procText(addon, state, left), "9.0", "remaining left timer is not cleared with another aura")
    state:advance(2)
    equal(procText(addon, state, rime), "9.0", "native duration continues in combat")
    putAura(state, 59052, 17, 1, true)
    equal(procText(addon, state, rime), "17.0", "refresh binds the real new duration")
    state.inCombat = false; options(addon)
    truthy(addon:SetPreview("single", rime), "audited current non-Mage region is available in existing Test Mode")
    equal(procFrame(addon, rime).alpha, 0, "preview suppresses its live wrapper only")
    addon:StopPreview(); addon:CloseOptions()
    truthy(procFrame(addon, rime).alpha > 0, "live region returns after stopping preview and closing Options")
    equal(procText(addon, state, rime), "17.0", "Options never becomes live state provider")
    state:advance(17)
    equal(procText(addon, state, rime), "", "natural expiry has no fabricated remaining time")
    equal(state.realReads, 0, "no Lua aura, cooldown, or stack read occurs")
    equal(#state.errors, 0, "non-Mage native lifecycle produces no mock contract errors")
end)

-- This fixture intentionally models only the APIs, not the truth of any spell mapping.
local function procClassFixture(class, spec, known, saved)
    local data = genericEngine({})
    local allowed, allKnown = {}, {}
    for _, definition in ipairs(definitionsFor(data, class, spec ~= false and spec or nil)) do includeDefinitionIDs(allowed, definition) end
    for _, definition in ipairs(spec ~= false and data.adapters[class].procFactory(spec) or {}) do
        for _, field in ipairs({ "requiresKnown", "requiresAnyKnown" }) do
            for _, id in ipairs(definition[field] or {}) do allKnown[id] = true end
        end
        for _, id in ipairs(definition.excludesKnown or {}) do allKnown[id] = nil end
    end
    return login(saved, false, { classToken = class, specID = spec, proc = {},
        procKnown = known or allKnown, mobility = { known = {}, spells = {} }, allowedSpellIDs = allowed })
end

test("new Proc definitions agree with independently pinned target source facts before runtime simulation", function()
    local facts = assert(loadfile(testRoot .. "/fixtures/proc_sources_69933.lua"))()
    equal(facts.build, "12.1.0.69933", "source fixture targets the requested client")
    local data, _, _, addon, state = genericEngine({})
    local classes, specs, definitions, regions, ownerKeys = 0, 0, 0, 0, {}
    for _, row in ipairs(themeRoster) do
        if row[1] ~= "MAGE" then
            classes = classes + 1
            local adapter = assert(data.adapters[row[1]])
            truthy(adapter.procCapability and adapter.procCapability.version == 1 and adapter.procFactory,
                "audited class has a concrete Proc capability: " .. row[1])
            for _, spec in ipairs(row[2]) do
                specs = specs + 1
                local records = adapter.procFactory(spec[1])
                truthy(addon:CompileProcDefinitions(records, row[1], spec[1]), "source catalog has no ambiguous provider/region ownership")
                for _, definition in ipairs(records) do
                    definitions = definitions + 1
                    truthy(definition.evidence and #definition.evidence > 15, "every admitted record links its audit")
                    local aura = assert(facts.auras[definition.auraID], "timer has independent finite-aura evidence")
                    truthy(aura.durationSeconds > 0 and aura.durationSeconds < math.huge, "pure resource/infinite owners are not timers")
                    for _, source in ipairs(definition.overlaySources) do
                        local key = source.overlayID .. ":" .. source.textureID .. ":" .. source.locationTypeName
                        local fact = assert(facts.overlays[key], "exact owner/texture/location belongs to pinned native table: " .. key)
                        truthy(math.abs(source.scale - fact.scale) < 0.000001, "native graphical scale matches source data")
                        ownerKeys[key] = true
                    end
                    for _, region in ipairs(definition.regions) do
                        regions = regions + 1
                        equal(region.class, row[1], "region cannot inherit previous class")
                        equal(region.specID, spec[1], "region cannot inherit another spec")
                    end
                end
            end
            equal(#adapter.procFactory(nil), 0, "unselected spec never borrows a known catalog")
            equal(#adapter.procFactory(999999), 0, "unknown spec is explicitly empty")
            equal(adapter.procDefinitions, nil, "audit metadata iteration did not activate another class's runtime catalog")
        end
    end
    equal(classes, 12, "remaining target classes are independently enumerated")
    equal(specs, 37, "remaining target specs include Devourer")
    equal(#state.auraSlots, 0, "source audit does not create any native display")
    print("OFFLINE-PROC-SOURCE-AUDIT classes=" .. classes .. ", specs=" .. specs .. ", candidate-definitions=" .. definitions
        .. ", regions=" .. regions .. ", native-graphic-keys=" .. countKeys(ownerKeys) .. "; client acceptance separate")
end)

test("every new admitted current-spec Proc runs real native timers with combat and secrecy modeled independently", function()
    local exercised, regions, emptySpecs = 0, 0, 0
    for _, row in ipairs(themeRoster) do
        if row[1] ~= "MAGE" then
            for _, spec in ipairs(row[2]) do
                local env, addon, state = procClassFixture(row[1], spec[1])
                local definitions = addon:GetProcDefinitions()
                if #definitions == 0 then
                    emptySpecs = emptySpecs + 1
                    equal(addon.procTracking, false, "audited empty spec is not advertised as an active monitor")
                else
                    truthy(addon.procTracking, "concrete current-spec catalog activates real Proc tracking")
                    local count = 0
                    for _, definition in ipairs(definitions) do count = count + #definition.regions end
                    equal(#state.auraSlots, count + 1, "only active spec regions plus independent Free move own slots")
                    local slots, bindings, fonts = #state.auraSlots, #state.bindings, #state.auraFonts
                    exercised, regions = exercised + #definitions, regions + count
                    for _, combat in ipairs({ false, true }) do
                        for _, restricted in ipairs({ false, true }) do
                            state.inCombat = combat
                            local times = {}
                            for index, definition in ipairs(definitions) do
                                times[definition.auraID] = 20 + index
                                putAura(state, definition.auraID, times[definition.auraID], 2, restricted)
                                for _, source in ipairs(definition.overlaySources) do
                                    showProc(env, state, source.overlayID, source.textureID, source.locationTypeName, source.scale)
                                end
                            end
                            for _, definition in ipairs(definitions) do
                                for _, entry in ipairs(definition.regions) do
                                    equal(procText(addon, state, entry.id), string.format("%.1f", times[definition.auraID]),
                                        "native live timer for " .. entry.id .. " combat=" .. tostring(combat) .. " secret=" .. tostring(restricted))
                                end
                                state.proc.auras[definition.auraID].applications = restricted and secret(1) or 1
                            end
                            state:advance(1)
                            for _, definition in ipairs(definitions) do
                                for _, entry in ipairs(definition.regions) do
                                    equal(procText(addon, state, entry.id), string.format("%.1f", times[definition.auraID] - 1),
                                        "partial layers retain current native remaining time")
                                end
                            end
                            state.proc.auras = {}; state:fire("UNIT_AURA", "player")
                            for _, definition in ipairs(definitions) do
                                for _, entry in ipairs(definition.regions) do equal(procText(addon, state, entry.id), "", "native absence clears only real aura-owned digits") end
                            end
                        end
                    end
                    equal(#state.auraSlots, slots, "repeat combat/secrecy transitions reuse native slots")
                    equal(#state.bindings, bindings, "repeat events do not allocate new duration bindings")
                    equal(#state.auraFonts, fonts, "repeat events reuse own Font objects")
                end
                for class, adapter in pairs(state.moduleNamespaces.CarGOUI_Data.adapters) do
                    if class ~= row[1] then equal(adapter.procDefinitions, nil, "unrelated class code is loaded but Proc catalog is not instantiated") end
                end
                for class in pairs(addon.db.classes) do equal(class, row[1], "only current class saved defaults may be instantiated") end
                equal(#state.spellReads, 0, "Proc never obtains timer data from spell cooldown queries")
                equal(state.realReads, 0, "no Lua aura/state reading replaces native ownership")
                equal(#state.errors, 0, "all admitted records satisfy the offline native contract")
            end
        end
    end
    print("OFFLINE-PROC-RUNTIME candidate-definitions=" .. exercised .. ", regions=" .. regions .. ", empty-specs=" .. emptySpecs
        .. "; four independent combat/secrecy combinations; client acceptance separate")
end)

test("empty learned Proc catalogs react to talent changes while Mobility stays disabled", function()
    local env, addon, state = procClassFixture("PALADIN", 70, {})
    addon:UpdateSettings({ mobility = { enabled = false } })
    equal(#addon:GetProcDefinitions(), 0, "no relevant learned drivers means no Proc data or available sample")
    equal(addon.procTracking, false, "empty catalog starts no Proc business listeners")
    for _, entry in ipairs(addon:GetPreviewEntries()) do truthy(entry.kind ~= "proc", "empty spec cannot offer fake available Proc previews") end
    state.procKnown[406064] = true; syncEvent(state, "TRAIT_CONFIG_UPDATED")
    equal(#addon:GetProcDefinitions(), 0, "Art of War reset alone is not a finite timer Proc")
    state.procKnown[1261113] = true; syncEvent(state, "PLAYER_TALENT_UPDATE")
    equal(#addon:GetProcDefinitions(), 1, "Light Within activates the actual finite empowerment")
    truthy(addon.procTracking, "lightweight catalog listener can discover Proc while Mobility is disabled")
    local entry = regionEntry(addon, "paladin_retribution_art_war_left")
    truthy(entry, "eligible Proc is now in the same existing preview catalog")
    putAura(state, 406086, 23, 1, true)
    equal(procText(addon, state, entry.id), "23.0", "catalog activation supplies native real countdown")
    local slots, bindings, events = #state.auraSlots, #state.bindings, addon:GetEventDiagnostics().callbacks
    for _ = 1, 12 do
        state.procKnown[1261113] = nil; syncEvent(state, "SPELLS_CHANGED")
        equal(addon.procTracking, false, "removing required talent releases Proc subscriptions")
        equal(procFrame(addon, entry.id).auraHandle.enabled, false, "obsolete native provider is inactive")
        state.procKnown[1261113] = true; syncEvent(state, "SPELLS_CHANGED")
    end
    equal(#state.auraSlots, slots, "relearning reuses region slots")
    equal(#state.bindings, bindings, "relearning creates no unbounded duration bindings")
    equal(addon:GetEventDiagnostics().callbacks, events, "relearning has bounded event ownership")
    equal(#state.spellReads, 0, "learning Proc talents never starts disabled movement queries")
    equal(#state.errors, 0, "catalog changes remain independent of Mobility")
end)

test("Proc event index refreshes affected definitions only and unrelated secret events do not disturb other timers", function()
    local env, addon, state = procClassFixture("DEATHKNIGHT", 251)
    putAura(state, 59052, 19, 1, true); putAura(state, 51124, 17, 1, true)
    local calls, acquire = {}, addon.AcquireAuraReminder
    addon.AcquireAuraReminder = function(self, entry, ...) calls[#calls + 1] = entry.id; return acquire(self, entry, ...) end
    local left = procFrame(addon, "deathknight_frost_killing_machine_left")
    local writes, binding = left.alphaWrites, left.auraHandle.container.nativeBinding
    showProc(env, state, 59052, 450930, "Top")
    same(calls, { "deathknight_frost_rime_top" }, "indexed event touches the named definition only")
    equal(left.alphaWrites, writes, "unrelated Proc native visibility is not rewritten")
    equal(left.auraHandle.container.nativeBinding, binding, "unrelated native binding is preserved")
    calls = {}
    showProc(env, state, 999999, 450930, "Top")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 999999)
    state:fire("SPELL_ACTIVATION_OVERLAY_SHOW", secret(59052), secret(450930), secret(4), secret(1))
    equal(#calls, 0, "unmapped or restricted identities never trigger full-catalog rendering")
    equal(procText(addon, state, left.entryId), "17.0", "unrelated event cannot clear valid native reminder")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 59052)
    same(calls, { "deathknight_frost_rime_top" }, "HIDE is also indexed")
    equal(procText(addon, state, left.entryId), "17.0", "hiding Rime leaves Killing Machine intact")
    equal(#state.errors, 0, "secret payload never leaks into formatting or comparison")
end)

test("native Proc providers reject aura scope and text-mode reassignment before cached-frame reuse", function()
    local _, addon, state = procClassFixture("DEATHKNIGHT", 251)
    local entry = regionEntry(addon, "deathknight_frost_rime_top")
    local frame = procFrame(addon, entry.id)
    local original, slots, bindings = frame.auraHandle, #state.auraSlots, #state.bindings
    for _, variant in ipairs({ { aura = 51124 }, { aura = 59052, text = "Free move" },
        { aura = 59052, class = "MAGE" }, { aura = 59052, specID = 252 } }) do
        local invalid = copy(entry)
        invalid.class, invalid.specID = variant.class or invalid.class, variant.specID or invalid.specID
        local received, reason = addon:AcquireAuraReminder(invalid, variant.aura, variant.text)
        equal(received, nil, "stable region cannot be rebound to another native provider")
        truthy(reason and reason:find("another Aura or scope", 1, true), "rejection explains exact ownership conflict")
        equal(frame.auraHandle, original, "provider mismatch never mutates old slot")
        equal(original.enabled, false, "conflicting provider leaves old timer safely inactive")
        equal(addon:AcquireAuraReminder(entry, 59052), frame, "correct provider remains reusable")
    end
    equal(#state.auraSlots, slots, "mismatch cannot create replacement slot under old region ID")
    equal(#state.bindings, bindings, "mismatch cannot leak timer binding")
end)

test("Proc compiler rejects duplicate and ambiguous registrations while explicit shared owners update both providers", function()
    local env, addon, state = procClassFixture("DEATHKNIGHT", 251)
    local data = state.moduleNamespaces.CarGOUI_Data
    local function definition(id, aura, location, shared)
        return data:ProcDefinition({ id = id, name = id, class = "DEATHKNIGHT", specID = 251, auraID = aura,
            nativeEventOnly = true, evidence = "Synthetic contract test: explicit one-to-many owner, not a real spell mapping",
            overlaySources = { { overlayID = 987010, textureID = 987011, locationTypeName = "LeftRight", scale = 1, shared = shared } },
            regions = { { id = id .. "_region", label = id, location = location } } })
    end
    local first, second = definition("offline_shared_a", 987012, "Left", true), definition("offline_shared_b", 987013, "Right", true)
    truthy(addon:CompileProcDefinitions({ first, second }, "DEATHKNIGHT", 251), "explicit audited shared owner can address two actual providers")
    local invalid = copy(second); invalid.overlaySources[1].shared = false
    equal(addon:CompileProcDefinitions({ first, invalid }, "DEATHKNIGHT", 251), nil, "implicit owner overwrite is forbidden")
    invalid = copy(second); invalid.regions[1].id = first.regions[1].id
    equal(addon:CompileProcDefinitions({ first, invalid }, "DEATHKNIGHT", 251), nil, "duplicate stable region cannot reuse unrelated aura slot")
    invalid = copy(second); invalid.specID = 252
    equal(addon:CompileProcDefinitions({ first, invalid }, "DEATHKNIGHT", 251), nil, "foreign specialization cannot enter active catalog")
    invalid = copy(second); invalid.overlaySources[1].locationTypeName = "Top"
    equal(addon:CompileProcDefinitions({ invalid }, "DEATHKNIGHT", 251), nil, "unsupported region-to-graphic geometry is rejected")
    addon.activeClassAdapter.procDefinitions = { first, second }
    addon.activeClassAdapter.procDefinitionSpec = 251
    addon:ConfigureProc()
    putAura(state, 987012, 14, 1, true); putAura(state, 987013, 29, 1, true)
    equal(procText(addon, state, first.regions[1].id), "", "event-only entry does not invent graphic activation")
    showProc(env, state, 987010, 987011, "LeftRight")
    equal(procText(addon, state, first.regions[1].id), "14.0", "one owner activates first exact provider")
    equal(procText(addon, state, second.regions[1].id), "29.0", "one owner also activates the separate second provider")
    state.proc.auras[987012] = nil; state:fire("UNIT_AURA", "player")
    equal(procText(addon, state, first.regions[1].id), "", "one provider's absence cannot be guessed from the shared owner")
    equal(procText(addon, state, second.regions[1].id), "29.0", "other provider survives partial shared-owner consumption")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 987010)
    equal(procText(addon, state, second.regions[1].id), "", "shared owner HIDE visits every registered provider")
    equal(#state.errors, 0, "one-to-many dispatch never overwrites a provider")
end)

test("non-Mage Proc styles colors coordinates and native ownership survive spec cycles and reload", function()
    local env, addon, state = procClassFixture("DEATHKNIGHT", 251)
    local region = "deathknight_frost_rime_top"
    local entry = regionEntry(addon, region)
    addon:UpdateReminderStyle("proc:DEATHKNIGHT:251", { font = { size = 37 }, scale = 1.2 })
    addon:UpdateSettings({ reminders = { [region] = { position = { x = 18, y = -12 } } } })
    addon:SetProcRegionColor(entry, { r = 0.2, g = 0.8, b = 0.3 })
    putAura(state, 59052, 24, 1, true)
    options(addon); addon:SetPreview("single", region)
    same(addon.previewFrames[region].text.textColor, { 0.2, 0.8, 0.3, 1 }, "non-Mage external preview resolves its exact region RGB")
    same(procFrame(addon, region).text.textColor, addon.previewFrames[region].text.textColor, "live and sample resolve the same saved color")
    addon:StopPreview(); addon:CloseOptions()
    local mobility = copy(addon:GetMobilityConfig())
    state.procKnown[49530], state.procKnown[81136], state.procKnown[1264506] = true, true, true
    for _, spec in ipairs({ 250, 252, 251 }) do
        state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    end
    local slots, bindings, fonts, callbacks = #state.auraSlots, #state.bindings, #state.auraFonts, addon:GetEventDiagnostics().callbacks
    for _ = 1, 8 do
        for _, spec in ipairs({ 250, 252, 251 }) do
            state.specID = spec; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
            for _, frame in pairs(addon.reminderFrames.nativeAura) do
                if frame.reminderEntry.kind == "proc" and frame.reminderEntry.specID ~= spec then equal(frame.auraHandle.enabled, false, "old spec native slots are inactive") end
            end
        end
    end
    equal(#state.auraSlots, slots, "repeated DK spec changes do not grow native slot pool")
    equal(#state.bindings, bindings, "repeated DK spec changes do not grow binding pool")
    equal(#state.auraFonts, fonts, "repeated DK spec changes do not grow Font pool")
    equal(addon:GetEventDiagnostics().callbacks, callbacks, "repeated DK spec changes do not grow event listeners")
    same(addon:GetMobilityConfig(), mobility, "Proc spec and color changes leave class Mobility config intact")
    equal(addon:GetReminderPosition(entry).x, 18, "spec changes preserve region offset")
    equal(procFrame(addon, region).text.font[2], 37, "returning spec restores its own shared font")
    same(procFrame(addon, region).text.textColor, { 0.2, 0.8, 0.3, 1 }, "returning spec restores region RGB")
    local _, fresh, reloaded = procClassFixture("DEATHKNIGHT", 251, nil, copy(addon.db))
    putAura(reloaded, 59052, 31, 1, true); syncEvent(reloaded, "PLAYER_ENTERING_WORLD")
    equal(procText(fresh, reloaded, region), "31.0", "reload/world entry sync actual current native aura")
    equal(fresh:GetProcConfig().style.font.size, 37, "reload restores class/spec style")
    equal(fresh:GetReminderPosition(regionEntry(fresh, region)).y, -12, "reload restores independent region offset")
    same(procFrame(fresh, region).text.textColor, { 0.2, 0.8, 0.3, 1 }, "reload restores optional RGB without affecting other regions")
    equal(#state.errors + #reloaded.errors, 0, "non-Mage persistence and lifecycle produce no errors")
end)

test("Hunter Precise Shots separates actual timer aura from graphic tiers and preserves ongoing duration", function()
    local env, addon, state = procClassFixture("HUNTER", 254, { [260240] = true })
    local left, right = "hunter_254_precise_shots_left", "hunter_254_precise_shots_right"
    putAura(state, 270436, 90, 1, true); putAura(state, 270437, 90, 1, true)
    equal(procText(addon, state, left), "", "graphic owner auras cannot masquerade as actual Precise Shots duration")
    putAura(state, 260242, 18, 2, true)
    showProc(env, state, 270436, 1029138, "LeftRight")
    state:advance(4)
    showProc(env, state, 270437, 1029139, "LeftRight")
    state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", 270436)
    equal(procText(addon, state, left), "14.0", "new graphic tier keeps the already-running real aura duration")
    equal(procText(addon, state, right), "14.0", "old owner HIDE cannot kill current tier's other region")
    state.proc.auras[260242].applications = secret(1); state:fire("UNIT_AURA", "player")
    equal(procText(addon, state, left), "14.0", "partial aura consumption is not inferred from event count")
    state.proc.auras[260242] = nil; state:fire("UNIT_AURA", "player")
    equal(procText(addon, state, left), "", "real timer absence clears even while synthetic graphic owners remain present")
    equal(#state.errors, 0, "split graphic/timer mapping uses no hidden aura learning checks")
end)

test("alternate learned Proc drivers exclusions and non-talent finite-aura paths resolve without hidden Buff learning", function()
    local _, mageFree, dh = procClassFixture("DEMONHUNTER", 1480, {})
    equal(#mageFree:GetProcDefinitions(), 1, "Devourer exact aura covers talent OR set effect without guessing learned gear IDs")
    putAura(dh, 1238495, 11, 1, true)
    equal(procText(mageFree, dh, "demonhunter_1480_moment_of_craving_top"), "11.0", "set-provided finite aura uses the same true native timer")
    local _, hunter = procClassFixture("HUNTER", 254, { [1301406] = true })
    equal(#hunter:GetProcDefinitions(), 1, "Tactical Reload alone supplies the audited Lock and Load path")
    equal(hunter:GetProcDefinitions()[1].auraID, 194594, "alternate driver cannot become the timer ID")
    local _, monk = procClassFixture("MONK", 269, { [1250042] = true })
    equal(#monk:GetProcDefinitions(), 1, "Echo Technique alone supplies finite Blackout Kick")
    equal(monk:GetProcDefinitions()[1].auraID, 116768, "Monk uses hidden effect only as native aura filter")
    local _, druid, state = procClassFixture("DRUID", 104, { [203964] = true, [1252871] = true })
    for _, definition in ipairs(druid:GetProcDefinitions()) do truthy(definition.auraID ~= 213708, "Red Moon excludes replaced Galactic Guardian Proc") end
    state.procKnown[1252871] = nil; syncEvent(state, "TRAIT_CONFIG_UPDATED")
    local found = false
    for _, definition in ipairs(druid:GetProcDefinitions()) do if definition.auraID == 213708 then found = true end end
    truthy(found, "removing replacement discovers original without reading any Buff")
end)

test("all new native regions use existing Proc controls for independent RGB XY and shared specialization font", function()
    local totalRegions = 0
    for _, row in ipairs(themeRoster) do
        if row[1] ~= "MAGE" then
            for _, spec in ipairs(row[2]) do
                local env, addon, state = procClassFixture(row[1], spec[1])
                local panel, controls = options(addon)
                addon:SelectOptionsCategory("proc")
                local definitions, entries = addon:GetProcDefinitions(), {}
                for _, definition in ipairs(definitions) do
                    for _, entry in ipairs(definition.regions) do entries[#entries + 1] = entry end
                end
                if #entries == 0 then
                    equal(controls.procPreview:IsEnabled(), false, "audited-empty spec offers no dummy sample")
                    equal(controls.procColor:IsEnabled(), false, "no nonexistent region color control is active")
                else
                    local mobility = copy(addon:GetMobilityConfig())
                    local events, slots, bindings = addon:GetEventDiagnostics().callbacks, #state.auraSlots, #state.bindings
                    for index, entry in ipairs(entries) do
                        totalRegions = totalRegions + 1
                        -- The Region Editor first selects the owning Proc.
                        -- Keep all existing timer RGB/XY/font assertions intact.
                        choose(controls.procSelector, tostring(entry.overlayID or entry.sourceSpellID or entry.id))
                        choose(controls.procEntry, entry.id)
                        equal(panel.selectedProcEntry, entry.id, "existing selector resolves stable region identity")
                        controls.procPreview:Click()
                        truthy(addon.previewFrames[entry.id] and addon.previewFrames[entry.id]:IsShown(), "each admitted region has an operative external preview")
                        equal(addon:GetProcRegionColor(entry), nil, "every new region starts with dynamic class color")
                        controls.procColor:Click()
                        local picker = env.ColorPickerFrame
                        truthy(picker:IsShown(), "existing native picker opens on current non-Mage region")
                        local rgb = { index / (#entries + 1), 0.2, 0.7 }
                        picker.rgb = rgb; picker.swatchFunc(); picker.Footer.OkayButton:Click()
                        same(addon:GetProcRegionColor(entry), { r = rgb[1], g = rgb[2], b = rgb[3] }, "native confirmation saves only selected region")
                        truthy(addon:UpdateSettings({ reminders = { [entry.id] = { position = { x = index * 3, y = -index * 2 } } } }), "stable region stores independent offsets")
                    end
                    addon:StopPreview()
                    addon:UpdateReminderStyle("proc:" .. row[1] .. ":" .. spec[1], { font = { size = 32 }, scale = 1.1 })
                    for index, entry in ipairs(entries) do
                        equal(procFrame(addon, entry.id).text.font[2], 32, "one current specialization font styles every native region")
                        equal(addon:GetReminderPosition(entry).x, index * 3, "shared font does not merge or scale region coordinates")
                        same(procFrame(addon, entry.id).text.textColor, { index / (#entries + 1), 0.2, 0.7, 1 }, "shared font retains independent per-region RGB")
                    end
                    same(addon:GetMobilityConfig(), mobility, "all region edits preserve class Mobility style layout and switches")
                    equal(#state.auraSlots, slots, "all-region editor uses already-created active native providers")
                    equal(#state.bindings, bindings, "picker and style edits never allocate extra native bindings")
                    equal(addon:GetEventDiagnostics().callbacks, events, "editor adds no business monitor subscriptions")
                end
                addon:CloseOptions()
                equal(state.realReads, 0, "all-region UI never queries buffs or cooldowns")
                equal(#state.errors, 0, "all-region controls remain operational")
            end
        end
    end
    print("OFFLINE-PROC-CONTROLS verified-regions=" .. totalRegions .. "; actual existing picker/preview controls exercised")
end)

test("threshold and gear Proc sources require actual native SHOW while unknown identities stay empty", function()
    for _, row in ipairs({ { "PRIEST", 256, { [373180] = true }, 373183, 469752, "priest_discipline_harsh_discipline_top" },
        { "DRUID", 104, {}, 1272376, 592058, "druid_guardian_celestial_might_right" } }) do
        local env, addon, state = procClassFixture(row[1], row[2], row[3])
        local location = row[1] == "PRIEST" and "Top" or "Right"
        putAura(state, row[4], 22, 1, true)
        equal(procText(addon, state, row[6]), "", "finite aura alone cannot invent threshold/set graphic state")
        showProc(env, state, row[4], row[5] + 1, location)
        equal(procText(addon, state, row[6]), "", "unverified artwork does not unlock event-only mapping")
        state.inCombat = true
        showProc(env, state, row[4], row[5], location)
        equal(procText(addon, state, row[6]), "22.0", "public native graphic plus matching restricted finite aura supplies real countdown")
        state:fire("SPELL_ACTIVATION_OVERLAY_HIDE", row[4])
        equal(procText(addon, state, row[6]), "", "native threshold HIDE immediately suppresses timer without counting applications")
        state.specID = nil; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        equal(#addon:GetProcDefinitions(), 0, "unknown current spec does not borrow last valid spec mapping")
        equal(addon.procTracking, false, "unknown scope stops old Proc business subscriptions")
        equal(procFrame(addon, row[6]).auraHandle.enabled, false, "unknown scope stops old native slot")
        equal(#state.errors, 0, "public graphic lifecycle never reads hidden threshold or gear state")
    end
end)


-- XY isolation regressions: configuration and addon-owned geometry only.
-- Observation helpers below are offline mock assertions, never production APIs.
do
local function xy(frame)
    local _, _, _, x, y = frame:GetPoint()
    return { x = x * frame:GetScale(), y = y * frame:GetScale() }
end
local function pos(x, y) return { anchor = "CENTER", x = x, y = y } end
local function scopedSaved(class, spec, procRegions)
    return { schemaVersion = 5, classes = { [class] = {
        mobility = { enabled = true, position = pos(170, -95),
            style = { font = { face = "Fonts\\FRIZQT__.ttf", size = 30, outline = "OUTLINE" },
                shadow = { enabled = true }, scale = 1.5 } },
        proc = { [spec] = { regions = procRegions or {} } },
    } } }
end
local function counts(addon, state)
    return { frames = #state.frames, slots = #state.auraSlots, bindings = #state.bindings,
        callbacks = addon:GetEventDiagnostics().callbacks, reads = state.realReads }
end

test("XY FIX reproduces and isolates Free move from Mage ordinary position in live and TEST", function()
    local env, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2,
        chargeStart = 95, chargeDuration = 20, secretDuration = true }, { specID = 62, proc = {} })
    local freeEntry, ordinaryEntry = addon:GetFreeMoveEntry(), addon:GetMobilityEntry()
    local free = procFrame(addon, freeEntry.id)
    local before = xy(free)
    truthy(addon:UpdateSettings({ position = { x = 180, y = -100 } }))
    local after = xy(free)
    print("XY-OBSERVED before Mobility edit: Free move=(" .. before.x .. "," .. before.y
        .. "); after: (" .. after.x .. "," .. after.y .. ")")
    same(after, before, "ordinary class position must not move native Free move")
    truthy(addon:GetReminderPosition(freeEntry) ~= addon:GetMobilityConfig().position,
        "free/ordinary positions are different mutable objects")
    local ordinary = xy(currentLive(addon))
    truthy(addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = -210, y = 65 } } } }))
    same(xy(currentLive(addon)), ordinary, "Free move position must not move Shimmer")
    same(xy(free), { x = -210, y = 149 }, "independent free offset keeps original +84 default anchor")
    options(addon); addon:SetPreview("all")
    reminderAnchor(addon.previewFrames[ordinaryEntry.id], ordinaryEntry, addon, env)
    reminderAnchor(addon.previewFrames[freeEntry.id], freeEntry, addon, env)
    local freePreview = xy(addon.previewFrames[freeEntry.id])
    truthy(addon:UpdateSettings({ mobility = { position = { x = 321, y = -122 } } }))
    same(xy(addon.previewFrames[freeEntry.id]), freePreview, "ordinary update cannot move free sample")
    same(xy(free), freePreview, "native and TEST use the same independent position")
    truthy(addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = 0, y = 0 } } } }))
    same(xy(currentLive(addon)), { x = 321, y = -122 }, "Free move reset leaves ordinary anchor intact")
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 38 }, scale = 2 })
    equal(free.text.font[2], 38, "shared class font is intentionally retained")
    same(xy(free), { x = 0, y = 84 }, "scale is not applied twice to independent free coordinates")
    equal(#state.errors, 0, "no mock errors")
end)

test("XY FIX numeric Free move axes stay independent of Mobility and reject invalid input", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2,
        chargeStart = 95, chargeDuration = 20 }, { proc = {} })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    addon:SelectOptionsCategory("mobility")
    typeText(controls.freeMoveX, "240"); enter(controls.freeMoveY, "-31")
    same(addon:GetMobilityConfig().position, pos(0, 0), "Free move editor does not modify ordinary config")
    same(addon:GetReminderPosition(addon:GetFreeMoveEntry()), pos(240, -31), "Free move Enter updates both axes")
    addon:SelectOptionsCategory("mobility")
    equal(tonumber(controls.mobilityX.editBox:GetText()), 0, "ordinary editor reflects its own X")
    equal(tonumber(controls.mobilityY.editBox:GetText()), 0, "ordinary editor reflects its own Y")
    typeText(controls.mobilityX, "-117"); enter(controls.mobilityY, "53")
    addon:SelectOptionsCategory("mobility")
    equal(tonumber(controls.freeMoveX.editBox:GetText()), 240, "Free move X survives ordinary editor changes")
    equal(tonumber(controls.freeMoveY.editBox:GetText()), -31, "Free move Y survives ordinary editor changes")
    enter(controls.freeMoveX, "999")
    local before = copy(addon.db)
    enter(controls.freeMoveY, "bad")
    same(addon.db, before, "invalid axis cannot write either position scope")
    controls.freeMoveReset:Click()
    same(addon:GetMobilityConfig().position, pos(-117, 53), "Reset Free move does not reset class group")
    same(addon:GetReminderPosition(addon:GetFreeMoveEntry()), pos(0, 0), "Reset targets Free move only")
    typeText(controls.freeMoveX, "450")
    addon:CloseOptions(); addon:OpenOptions()
    addon:SelectOptionsCategory("mobility")
    equal(tonumber(controls.freeMoveX.editBox:GetText()), 0, "unconfirmed input discarded on close")
    equal(#state.errors, 0, "GUI input isolation")
end)

test("XY FIX every class and specialization separates Free move Mobility and each native Proc region", function()
    local visitedSpecs, visitedRegions = 0, 0
    for _, row in ipairs(themeRoster) do
        for _, spec in ipairs(row[2]) do
            local env, addon, state
            if row[1] == "MAGE" then env, addon, state = auraFixture(spec[1])
            else env, addon, state = procClassFixture(row[1], spec[1]) end
            visitedSpecs = visitedSpecs + 1
            local freeEntry = assert(addon:GetFreeMoveEntry())
            local free = procFrame(addon, freeEntry.id)
            local initialFree = xy(free)
            local regions = {}
            for _, definition in ipairs(addon:GetProcDefinitions()) do
                for _, entry in ipairs(definition.regions) do
                    regions[#regions + 1] = entry
                end
            end
            local function snapshots()
                local values = {}
                for _, entry in ipairs(regions) do values[entry.id] = xy(procFrame(addon, entry.id)) end
                return values
            end
            local configurable = {}
            for _, entry in ipairs(addon:GetPreviewEntries()) do
                if entry.kind == "proc" then configurable[entry.id] = true end
            end
            local initialProc = snapshots()
            truthy(addon:UpdateSettings({ position = { x = 207, y = -99 } }))
            same(xy(free), initialFree, row[1] .. " free follows its own offset in spec " .. spec[1])
            same(snapshots(), initialProc, "ordinary change cannot move any Proc")
            truthy(addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = -91, y = 122 } } } }))
            same(addon:GetMobilityConfig().position, pos(207, -99), "free writes do not mutate ordinary storage")
            same(snapshots(), initialProc, "free change cannot move any Proc")
            for i, entry in ipairs(regions) do
                -- Event-only legacy Mage definitions intentionally excluded
                -- from the existing settings catalog remain unchanged. They
                -- are still observed in snapshots of every native region.
                if configurable[entry.id] then
                visitedRegions = visitedRegions + 1
                local before = snapshots()
                truthy(addon:UpdateSettings({ proc = { regions = {
                    [entry.id] = { position = { x = i * 7, y = -i * 3 } },
                } } }))
                for _, other in ipairs(regions) do
                    if other.id ~= entry.id then same(xy(procFrame(addon, other.id)), before[other.id], "only selected region moves") end
                end
                same(xy(free), { x = -91, y = 206 }, "Proc does not move Free move")
                same(addon:GetMobilityConfig().position, pos(207, -99), "Proc does not mutate Mobility")
                end
            end
            options(addon); addon:SetPreview("all")
            for _, entry in ipairs(addon:GetPreviewEntries()) do
                local native = addon.reminderFrames.nativeAura[entry.id]
                local sample = addon.previewFrames[entry.id]
                if native and sample then same(xy(sample), xy(native), "each native region and its preview use identical offsets") end
            end
            local pooled = counts(addon, state)
            for i = 1, 10 do
                addon:UpdateSettings({ position = { x = i, y = -i },
                    reminders = { [freeEntry.id] = { position = { x = 50 + i, y = 60 + i } } } })
            end
            same(counts(addon, state), pooled, "position changes do not allocate or subscribe or query")
            equal(#state.errors, 0, "cross-class/spec position checks")
        end
    end
    equal(visitedSpecs, 40, "all catalogued specs tested, including audited-empty Proc scopes")
    print("XY-ISOLATION-MATRIX specs=" .. visitedSpecs .. "; configured/native/preview regions=" .. visitedRegions)
end)

test("XY FIX old class offsets migrate once without changing visual position or borrowing other classes", function()
    local saved = scopedSaved("MAGE", 62)
    saved.classes.WARRIOR = { mobility = { position = pos(-310, 120) }, proc = {} }
    local _, addon = login(saved, false, { specID = 62, proc = {} })
    local freeEntry = addon:GetFreeMoveEntry()
    same(xy(procFrame(addon, freeEntry.id)), { x = 170, y = -11 }, "old effective Free move screen position retained")
    same(addon:GetReminderPosition(freeEntry), pos(170, -95), "migration copies legacy offset exactly once without scale")
    addon:UpdateSettings({ position = { x = 25, y = 35 } })
    same(addon:GetReminderPosition(freeEntry), pos(170, -95), "later Mobility changes no longer inherit")
    addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = 99, y = -77 } } } })
    local persisted = copy(addon.db)
    local _, reloaded = login(persisted, false, { specID = 63, proc = {} })
    same(reloaded:GetReminderPosition(reloaded:GetFreeMoveEntry()), pos(99, -77), "same class different spec/reload retains independent choice")
    same(reloaded:GetMobilityConfig().position, pos(25, 35), "ordinary choice also retained")
    local _, warrior = login(copy(reloaded.db), false, { classToken = "WARRIOR", specID = 71, proc = {} })
    same(warrior:GetReminderPosition(warrior:GetFreeMoveEntry()), pos(-310, 120), "unvisited old class migrates from its own Mobility only")
    warrior:UpdateSettings({ reminders = { free_move_warrior = { position = { x = -70, y = -80 } } } })
    local _, mage = login(copy(warrior.db), false, { specID = 64, proc = {} })
    same(mage:GetReminderPosition(mage:GetFreeMoveEntry()), pos(99, -77), "other class writes cannot alter Mage free offsets")
    local _, fresh = login(copy(warrior.db), false, { classToken = "PALADIN", specID = 66, proc = {} })
    same(fresh:GetReminderPosition(fresh:GetFreeMoveEntry()), pos(0, 0), "fresh class does not inherit previous class")
end)

test("XY FIX detached preexisting position tables and direct Proc patches cannot mutate sibling regions", function()
    local shared = pos(17, -8)
    local left, right = "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right"
    local saved = scopedSaved("MAGE", 62, { [left] = { position = shared }, [right] = { position = shared } })
    saved.classes.MAGE.mobility.freeMovePosition = saved.classes.MAGE.mobility.position
    -- Force configuration normalization before any frame/GetReminderPosition call
    -- can mask aliasing through lazy rendering of both regions.
    local env, addon, state = login(saved, false, { specID = 62, proc = {} })
    local config = addon:GetProcConfig()
    local alias = pos(88, 99)
    config.regions[left].position, config.regions[right].position = alias, alias
    addon.procConfigurationCache = {} -- model a saved aliased current-spec load
    addon:GetProcConfig()
    truthy(addon:UpdateSettings({ proc = { regions = { [left] = { position = { x = 73, y = -12 } } } } }))
    same(addon:GetProcConfig().regions[right].position, pos(88, 99), "direct patch cannot mutate not-yet-rendered aliased sibling")
    local ordinary = copy(addon:GetMobilityConfig().position)
    truthy(addon:UpdateSettings({ reminders = { free_move_mage = { position = { x = -1, y = -2 } } } }))
    same(addon:GetMobilityConfig().position, ordinary, "aliased saved free/ordinary tables detached")
    equal(#state.errors, 0, "aliased saved input normalized safely")
end)

test("XY FIX pure coordinate edits never query spells reconfigure monitors replace timers or write alpha", function()
    local env, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2,
        chargeStart = 95, chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {}, specID = 62 })
    putAura(state, 263725, 22, 2, true); putAura(state, 375240, 20, 1, true)
    showProc(env, state, 1277420, 1027131, "LeftRight")
    options(addon); addon:SetPreview("all")
    local freeEntry = addon:GetFreeMoveEntry()
    local left = "mage_arcane_clearcasting_left"
    local original = {}
    local function forbidden() error("Coordinate-only editing must not reconfigure/query/rebind active state") end
    for _, name in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "RenderMobilityState",
        "RenderProcState", "RenderFreeMoveState", "RefreshMobility", "RefreshPreview" }) do
        original[name] = addon[name]; addon[name] = forbidden
    end
    local metrics, writeCounts = counts(addon, state), {}
    for _, pool in pairs(addon.reminderFrames) do
        for _, frame in pairs(pool) do
            writeCounts[frame] = frame.alphaWrites or 0
            if frame.durationBinding then frame.durationBinding.SetDuration = forbidden end
            if frame.auraHandle then frame.auraHandle.SetEnabled = forbidden end
        end
    end
    truthy(addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = 144, y = -28 } } } }))
    truthy(addon:UpdateSettings({ position = { x = -199, y = 36 } }))
    truthy(addon:UpdateSettings({ mobility = { freeMovePosition = { x = 101, y = 102 } } }))
    truthy(addon:UpdateSettings({ proc = { regions = { [left] = { position = { x = 21, y = 22 } } } } }))
    same(counts(addon, state), metrics, "coordinate-only edits are layout-only")
    for frame, writes in pairs(writeCounts) do equal(frame.alphaWrites or 0, writes, "no wrapper opacity write") end
    same(xy(procFrame(addon, freeEntry.id)), { x = 101, y = 186 }, "live free wrapper was relaid out")
    same(xy(addon.previewFrames[freeEntry.id]), { x = 101, y = 186 }, "same sample was relaid out")
    equal(#state.errors, 0, "native/data secrecy not read by editor")
end)

test("XY FIX intentional ordinary multi-skill class grouping is preserved without dragging Free move", function()
    local env, addon, state = warriorLogin({
        [100] = { charges = 0, maxCharges = 2, chargeStart = 90, chargeDuration = 20 },
        [6544] = { charges = 0, maxCharges = 1, chargeStart = 90, chargeDuration = 40 },
        [3411] = { charges = 1, maxCharges = 1, chargeStart = 100, chargeDuration = 30 },
    })
    -- This fixture has no native aura templates, but the same Free move position
    -- and Preview path are always defined for the current class.
    local freeEntry = addon:GetFreeMoveEntry()
    local before = copy(addon:GetReminderPosition(freeEntry))
    local entries = addon:GetMobilityEntries()
    truthy(#entries > 1, "multiple real ordinary Mobility families")
    truthy(addon:UpdateSettings({ reminders = { [entries[2].id] = { position = { x = 61, y = -27 } } } }))
    for _, entry in ipairs(entries) do
        same(addon:GetReminderPosition(entry), pos(61, -27), "ordinary reminders intentionally share class group offsets")
        local frame = addon.reminderFrames.live[entry.id]
        if frame then same(xy(frame), { x = entry.anchor.x + 61, y = entry.anchor.y - 27 }, "stable preset slot retained") end
    end
    same(addon:GetReminderPosition(freeEntry), before, "Free move is not an ordinary class slot anymore")
end)

test("XY FIX no-specialization scopes use class-owned independent offsets for all thirteen classes", function()
    local visited = 0
    for _, row in ipairs(themeRoster) do
        local _, addon, state = login(nil, false, { classToken = row[1], specID = false, proc = {} })
        local freeEntry = addon:GetFreeMoveEntry()
        truthy(freeEntry and freeEntry.class == row[1])
        addon:UpdateSettings({ position = { x = 90, y = 91 } })
        same(addon:GetReminderPosition(freeEntry), pos(0, 0), "unselected-spec free offset independent")
        addon:UpdateSettings({ reminders = { [freeEntry.id] = { position = { x = -20, y = -21 } } } })
        same(addon:GetMobilityConfig().position, pos(90, 91), "unselected-spec ordinary offset preserved")
        equal(#state.errors, 0)
        visited = visited + 1
    end
    equal(visited, 13)
end)
end

-- BEGIN RC SETTINGS TRANSFER REGRESSIONS
-- Real Python JSON/Base64 crosses the genuine Lua 5.1 boundary. This proves
-- our parser/transaction behavior, not WoW's C_EncodingUtil implementation.
do
local function transferPage(addon)
    if not addon.optionsFrame or not addon.optionsFrame:IsShown() then options(addon) end
    addon:SelectOptionsCategory("importExport")
    return addon.optionsFrame, addon.optionsFrame.controls
end
local function unpackSettings(env, text)
    local payload = assert(text:match("^CARGOUICFG:1:(.*)$"), "export has explicit independent format prefix")
    return env.C_EncodingUtil.DeserializeJSON(env.C_EncodingUtil.DecodeBase64(payload))
end
local function packSettings(env, value)
    return "CARGOUICFG:1:" .. env.C_EncodingUtil.EncodeBase64(env.C_EncodingUtil.SerializeJSON(value))
end
local function rawSettings(env, json)
    return "CARGOUICFG:1:" .. env.C_EncodingUtil.EncodeBase64(json)
end
local function prepareSettings(addon, text)
    transferPage(addon)
    local transaction, message = addon:PrepareSettingsImport(text)
    truthy(transaction, "valid settings prepare: " .. tostring(message))
    truthy(type(transaction.summary) == "string" and #transaction.summary > 0, "preparation returns reviewable summary")
    return transaction
end
local function transferMetrics(addon, state)
    return { frames = #state.frames, slots = #state.auraSlots, bindings = #state.bindings,
        callbacks = addon:GetEventDiagnostics().callbacks, reads = state.realReads, moduleLoads = state.moduleLoads }
end
local function transferSeed()
    local env, addon, state = auraFixture(62)
    addon:UpdateReminderStyle("mobility:MAGE", { font = { size = 31 }, scale = 1.4 })
    addon:UpdateSettings({ position = { x = 130, y = -80 }, mobility = { freeMovePosition = { x = -240, y = 75 } } })
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 34, outline = "THICKOUTLINE" }, shadow = { enabled = false }, scale = 1.2 })
    addon:UpdateSettings({ reminders = {
        mage_arcane_clearcasting_left = { position = { x = -41, y = 17 } },
        mage_arcane_clearcasting_right = { position = { x = 58, y = -23 } },
    } })
    addon:SetProcRegionColor(regionEntry(addon, "mage_arcane_clearcasting_left"), { r = 0.1, g = 0.7, b = 0.4 })
    local other = addon:NewProcConfig()
    other.style.font.size = 29
    other.regions.mage_fire_hot_streak_left = { position = { anchor = "CENTER", x = 38, y = -14 }, color = { r = 0.8, g = 0.1, b = 0.2 } }
    addon.db.classes.MAGE.proc[63] = other
    addon.db.classes.WARRIOR = { mobility = addon:NewMobilityConfig(), proc = {} }
    addon.db.classes.WARRIOR.mobility.position.x = -300
    addon.db.options.position = { x = 37, y = -22 }; addon.db.options.animatedTitle = false
    return env, addon, state
end
launcherHarness.transferSeed, launcherHarness.transferPage = transferSeed, transferPage
launcherHarness.prepareSettings, launcherHarness.packSettings = prepareSettings, packSettings
launcherHarness.unpackSettings, launcherHarness.transferMetrics = unpackSettings, transferMetrics

test("baseline preserves existing 1.0.0 schema 5 settings across login and reload", function()
    local _, original = transferSeed()
    local saved, before = copy(original.db), copy(original.db)
    equal(saved.schemaVersion, 5, "existing 1.0.0 configuration schema")
    local env, addon, state = login(saved, false, { specID = 62, proc = {} })
    equal(addon.db, saved, "existing SavedVariables root identity retained")
    equal(env.CarGOUIDB, saved, "runtime continues to share the existing SavedVariables")
    same(addon.db, before, "Mobility, Free move, Proc, other classes and Options survive unchanged")
    equal(addon.ClassToolsRawCapture, nil, "old settings do not enable research")
    env.SlashCmdList.CARGOUI("ctlog arcane on")
    same(addon.db, before, "removed research command writes no settings or logs")
    local _, reloaded = login(copy(addon.db), false, { specID = 62, proc = {} })
    same(reloaded.db, before, "a subsequent reload preserves the complete original configuration")
    equal(reloaded.ClassToolsRawCapture, nil, "research stays absent after reload")
    equal(#state.errors, 0, "old settings require no research runtime")
end)

test("RC export is a read-only whitelist snapshot of all saved specs in the selected class", function()
    local env, addon, state = transferSeed()
    addon.db.playerName, addon.db.guid, addon.db.debugLog = "PRIVATE PLAYER", "PRIVATE GUID", { "SECRET TRACE" }
    addon.db.importBackup = { private = "RECURSIVE BACKUP" }
    addon.db.classes.MAGE.playerName = "PRIVATE CLASS"
    addon.procEventTrace = { "PRIVATE EVENT" }; addon.pendingOptionsOpen = true
    local before, metrics = copy(addon.db), transferMetrics(addon, state)
    local text, message = addon:ExportSettings("class")
    truthy(text, tostring(message))
    same(addon.db, before, "export never normalizes or writes through getters")
    same(transferMetrics(addon, state), metrics, "export creates no adapter/frame/listener/binding or game query")
    local packet = unpackSettings(env, text)
    equal(packet.formatVersion, 1, "format version is separate")
    equal(packet.schemaVersion, 5, "settings schema is separate")
    equal(packet.addonVersion, addon.version, "source addon version is separate")
    equal(packet.project, "Retail", "project identity is explicit")
    equal(packet.scope, "class", "current-class scope is explicit")
    equal(countKeys(packet.classes), 1, "class export excludes other saved classes")
    truthy(packet.classes.MAGE.proc["62"] and packet.classes.MAGE.proc["63"], "all saved Mage specs export with JSON string keys")
    equal(packet.classes.MAGE.proc["64"], nil, "export does not initialize unvisited specs")
    equal(packet.options, nil, "class export excludes shell settings")
    local raw = env.C_EncodingUtil.DecodeBase64(text:match("^CARGOUICFG:1:(.*)$"))
    for _, forbidden in ipairs({ "PRIVATE", "SECRET TRACE", "RECURSIVE", "pendingOptionsOpen", "procEventTrace", "theme", "Aura" }) do
        equal(raw:find(forbidden, 1, true), nil, "whitelist does not serialize " .. forbidden)
    end
    local all = unpackSettings(env, assert(addon:ExportSettings("all")))
    truthy(all.classes.WARRIOR and all.classes.MAGE and all.options, "all scope includes saved classes and permitted shell")
    same(all.options.position, before.options.position, "shell coordinates retained")
    same(addon.db, before, "all export is also read-only")
end)

test("RC current-class round trip restores independent XY RGB and spec fonts without replacing DB identity", function()
    local env, addon, state = transferSeed()
    local original = copy(addon.db.classes.MAGE)
    local text = assert(addon:ExportSettings("class"))
    local db = addon.db
    addon:UpdateSettings({ position = { x = -999, y = 999 }, mobility = { freeMovePosition = { x = 10, y = 20 } } })
    addon:UpdateReminderStyle("proc:MAGE:62", { font = { size = 18 } })
    addon:SetProcRegionColor(regionEntry(addon, "mage_arcane_clearcasting_right"), { r = 1, g = 0, b = 0 })
    transferPage(addon)
    local before, metrics = copy(addon.db), transferMetrics(addon, state)
    local transaction = prepareSettings(addon, text)
    same(addon.db, before, "prepare has no partial writes")
    same(transferMetrics(addon, state), metrics, "prepare does not mutate live monitoring")
    truthy(addon:ConfirmSettingsImport(transaction), "explicit confirmation commits atomically")
    equal(addon.db, db, "runtime database root reference is retained")
    equal(env.CarGOUIDB, db, "SavedVariables and runtime still share the same root")
    same(addon.db.classes.MAGE, original, "class snapshot restores all included settings")
    same(addon.db.classes.WARRIOR, before.classes.WARRIOR, "other class untouched")
    same(addon.db.options, before.options, "class import does not change shell")
    equal(addon:GetProcRegionColor(regionEntry(addon, "mage_arcane_clearcasting_right")), nil, "omitted custom color clears target old RGB")
    truthy(addon:GetMobilityConfig().position ~= addon:GetMobilityConfig().freeMovePosition, "independent positions have no shared table")
    truthy(addon:HasSettingsImportBackup(), "latest pre-import snapshot is recoverable")
    local _, reloaded = login(copy(addon.db), false, { specID = 62, proc = {} })
    same(reloaded.db.classes.MAGE, original, "reload restores imported scopes")
end)

test("RC complete settings import on another class uses static metadata without activating foreign adapters", function()
    local env, source = transferSeed()
    local text = assert(source:ExportSettings("all"))
    local expected = copy(source.db.classes)
    local targetEnv, target, state = login(nil, false, { classToken = "WARRIOR", specID = 71, proc = {}, moduleUnavailable = true })
    transferPage(target)
    local db, metrics = target.db, transferMetrics(target, state)
    local transaction = prepareSettings(target, text)
    same(transferMetrics(target, state), metrics, "metadata validation requires no gameplay module load")
    truthy(target:ConfirmSettingsImport(transaction), "foreign class data keeps its original ownership")
    equal(target.db, db, "complete import retains database reference")
    same(target.db.classes, expected, "saved classes restore independently")
    same(target.db.options, source.db.options, "all import restores explicit shell snapshot")
    equal(state.moduleLoads, metrics.moduleLoads, "foreign settings never activate Mage adapter")
    target.db.classes.MAGE.mobility.position.x = 123
    equal(source.db.classes.MAGE.mobility.position.x, 130, "source and imported tables do not alias")
    equal(target.db.classes.WARRIOR.mobility.position.x, -300, "imported class configs do not alias")
    equal(targetEnv.CarGOUIDB, db, "global reference remains synchronized")
end)

test("RC partial scopes retain omitted classes specs and region records", function()
    local env, addon = transferSeed()
    local packet = unpackSettings(env, assert(addon:ExportSettings("class")))
    packet.classes.MAGE.mobility = nil
    packet.classes.MAGE.proc["63"] = nil
    local included = packet.classes.MAGE.proc["62"]
    included.style.font.size = 41
    included.regions = { mage_arcane_clearcasting_left = { position = { anchor = "CENTER", x = 19, y = 27 } } }
    local before = copy(addon.db)
    truthy(addon:ConfirmSettingsImport(prepareSettings(addon, packSettings(env, packet))))
    same(addon.db.classes.MAGE.mobility, before.classes.MAGE.mobility, "omitted Mobility remains intact")
    same(addon.db.classes.MAGE.proc[63], before.classes.MAGE.proc[63], "omitted spec remains intact")
    same(addon.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_right,
        before.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_right, "omitted region retains all settings")
    equal(addon.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_left.color, nil, "included full region snapshot removes absent RGB")
    equal(addon.db.classes.MAGE.proc[62].style.font.size, 41, "included spec shared font changes")
    same(addon.db.classes.WARRIOR, before.classes.WARRIOR, "unmentioned class retains its scope")
end)

test("RC malformed envelopes and payloads are rejected atomically with bounded native decoding", function()
    local env, addon, state = transferSeed()
    transferPage(addon)
    local valid = assert(addon:ExportSettings("class"))
    local base = unpackSettings(env, valid)
    local function rejected(text, label)
        addon:CancelSettingsImport()
        local before, metrics = copy(addon.db), transferMetrics(addon, state)
        local transaction, message = addon:PrepareSettingsImport(text)
        equal(transaction, nil, label .. " rejected")
        truthy(type(message) == "string" and #message > 0, label .. " explains rejection")
        same(addon.db, before, label .. " has no partial settings or backup write")
        same(transferMetrics(addon, state), metrics, label .. " has no gameplay side effects")
    end
    for _, text in ipairs({ "", "return {}", "CARGOUICFG:2:AAAA", "WRONG:1:AAAA", "CARGOUICFG:1:!@#$",
        valid:sub(1, -4), rawSettings(env, "{"), rawSettings(env, '{"formatVersion":1,}'),
        rawSettings(env, '{"formatVersion":1,"formatVersion":1}'),
        rawSettings(env, '{"formatVersion":1,"\\u0066ormatVersion":1}'),
        rawSettings(env, '{"ignored":null}'), rawSettings(env, '[{"formatVersion":1}]'),
        rawSettings(env, string.rep('[', 14) .. '0' .. string.rep(']', 14)),
        rawSettings(env, string.rep(' ', 131073) .. '{}'), "CARGOUICFG:1:" .. string.rep("A", 196609),
        rawSettings(env, '{"x":NaN}'), rawSettings(env, '{"x":Infinity}'), rawSettings(env, '{"x":1e309}') }) do
        rejected(text, "untrusted raw input")
    end
    local edits = {
        function(p) p.formatVersion = 2 end, function(p) p.schemaVersion = 999 end,
        function(p) p.project = "Classic" end, function(p) p.scope = "profile" end,
        function(p) p.addonVersion = {} end, function(p) p.unknown = true end,
        function(p) p.classes.ROGUE = p.classes.MAGE; p.classes.MAGE = nil end,
        function(p) p.classes.MAGE.proc["71"] = p.classes.MAGE.proc["62"] end,
        function(p) p.classes.MAGE.proc["62"].regions.arbitrary_region = { position = { x = 0, y = 0 } } end,
        function(p) p.classes.MAGE.mobility.style.font.face = "C:\\malicious\\font.ttf" end,
        function(p) p.classes.MAGE.mobility.style.font.size = 73 end,
        function(p) p.classes.MAGE.mobility.style.scale = 0.1 end,
        function(p) p.classes.MAGE.mobility.style.font.outline = "GLOW" end,
        function(p) p.classes.MAGE.mobility.position.x = 20001 end,
        function(p) p.classes.MAGE.mobility.freeMovePosition.y = -20001 end,
        function(p) p.classes.MAGE.mobility.position.anchor = "TOP" end,
        function(p) p.classes.MAGE.mobility.enabled = "yes" end,
        function(p) p.classes.MAGE.mobility.unlisted = true end,
        function(p) p.classes.MAGE.proc["62"].regions.mage_arcane_clearcasting_left.color = { r = 1, g = -0.1, b = 0 } end,
        function(p) p.classes.MAGE.proc["62"].regions.mage_arcane_clearcasting_left.color.a = 0.5 end,
        function(p) p.options = { position = { x = 0, y = 0 }, animatedTitle = true } end,
    }
    for index, edit in ipairs(edits) do
        local packet = copy(base); edit(packet)
        rejected(packSettings(env, packet), "invalid schema case " .. index)
    end
    local fields = {}
    for i = 1, 2050 do fields[#fields + 1] = '"key' .. i .. '":0' end
    rejected(rawSettings(env, '{' .. table.concat(fields, ',') .. '}'), "excess object fields")
    local beforeDecode = state.codecCalls.DeserializeJSON or 0
    rejected(rawSettings(env, '{"addonVersion":"' .. string.rep('[{\\"', 16) .. '"}'), "brackets and escapes inside a string")
    equal(state.codecCalls.DeserializeJSON, beforeDecode + 1, "preflight counts structural depth, not braces inside strings")
end)

test("RC historical coordinates and unavailable fonts round-trip with explicit fallback review", function()
    local env, addon = transferSeed()
    addon.db.classes.MAGE.mobility.position = { anchor = "CENTER", x = 19999, y = -19999 }
    addon.db.classes.MAGE.mobility.freeMovePosition = { anchor = "CENTER", x = -17000, y = 16000 }
    addon.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_left.position.x = 18000
    local original = copy(addon.db.classes.MAGE)
    local text = assert(addon:ExportSettings("class"))
    addon.db.classes.MAGE.mobility.position.x = 0
    truthy(addon:ConfirmSettingsImport(prepareSettings(addon, text)))
    same(addon.db.classes.MAGE, original, "all valid historical +/-20000 coordinates remain portable without double scaling")
    local packet = unpackSettings(env, text)
    packet.classes.MAGE.mobility.style.font.face = "morpheus"
    -- Resource availability differs from the stable configuration whitelist.
    -- A missing local file must not permanently replace a valid saved choice.
    local saved = copy(addon.db)
    env, addon = login(saved, false, { specID = 62, proc = {},
        unavailableFonts = { ["fonts\\morpheus.ttf"] = true } })
    local transaction = prepareSettings(addon, packSettings(env, packet))
    truthy(transaction.summary:lower():find("font", 1, true), "unavailable font replacement is shown before confirmation")
    truthy(addon:ConfirmSettingsImport(transaction))
    equal(addon:GetMobilityConfig().style.font.face, "Fonts\\MORPHEUS.TTF", "recognized requested font is retained separately from render fallback")
    equal(addon:GetMobilityConfig().position.x, 19999, "font fallback does not reset historic coordinates")
end)

test("RC native-shaped codecs handle both empty table formats and explicit nil or error results", function()
    for _, emptyArrays in ipairs({ false, true }) do
        local env, addon, state = login(nil, false, { specID = 62, proc = {}, codecEmptyArrays = emptyArrays })
        local exported = assert(addon:ExportSettings("class"))
        local value = unpackSettings(env, exported)
        truthy(value.classes.MAGE, "real JSON round-trip preserved string map key")
        truthy(addon:ConfirmSettingsImport(prepareSettings(addon, exported)), "empty maps remain portable under both native serialization possibilities")
        for _, api in ipairs({ "DecodeBase64", "DeserializeJSON" }) do
            for _, failure in ipairs({ "nil", "error" }) do
                local before = copy(addon.db)
                state.codecFailures[api] = failure
                local transaction = addon:PrepareSettingsImport(exported)
                equal(transaction, nil, "native decoder failure is reported, never treated as empty defaults")
                same(addon.db, before, "native decoder failure is atomic")
                state.codecFailures[api] = nil
            end
        end
        for _, api in ipairs({ "SerializeJSON", "EncodeBase64" }) do
            for _, failure in ipairs({ "nil", "error" }) do
                state.codecFailures[api] = failure
                equal(addon:ExportSettings("class"), nil, "native encoder failure cannot return a fabricated export")
                state.codecFailures[api] = nil
            end
        end
    end
    local _, addon = login(nil, false, { proc = {}, encodingUnavailable = true })
    equal(addon:ExportSettings("class"), nil, "missing native codecs are explicit unsupported capability")
    transferPage(addon)
    equal(addon:PrepareSettingsImport("CARGOUICFG:1:e30="), nil, "missing native codecs never execute another parser fallback")
end)

test("RC import confirmation rejects canceled stale tampered changed-context and combat transactions atomically", function()
    local env, addon, state = transferSeed()
    local text = assert(addon:ExportSettings("class"))
    local transaction = prepareSettings(addon, text)
    addon:CancelSettingsImport()
    local before = copy(addon.db)
    equal(addon:ConfirmSettingsImport(transaction), false, "canceled transaction cannot be replayed")
    same(addon.db, before, "cancel never writes a backup or settings")
    transaction = prepareSettings(addon, text)
    addon.db.classes.MAGE.mobility.position.x = addon.db.classes.MAGE.mobility.position.x + 1
    before = copy(addon.db)
    equal(addon:ConfirmSettingsImport(transaction), false, "changed settings require another review")
    same(addon.db, before, "stale review never overwrites intervening user edit")
    transaction = prepareSettings(addon, text)
    local forged = copy(transaction)
    equal(addon:ConfirmSettingsImport(forged), false, "a copied public summary is not an authenticated private transaction")
    transaction = prepareSettings(addon, text)
    state.specID = 63
    before = copy(addon.db)
    equal(addon:ConfirmSettingsImport(transaction), false, "changed identity invalidates old review")
    same(addon.db, before, "context rejection does not write partial state")
    state.specID = 62
    transaction = prepareSettings(addon, text)
    state.inCombat = true
    before = copy(addon.db)
    equal(addon:ConfirmSettingsImport(transaction), false, "combat is rechecked at the actual commit boundary")
    same(addon.db, before, "combat rejection leaves settings and backup intact")
    state.inCombat = false
    equal(addon:ConfirmSettingsImport(transaction), false, "combat-blocked transaction cannot auto-commit later")
end)

test("RC one-level backup restores only after review and is excluded from later exports", function()
    local env, addon = transferSeed()
    transferPage(addon)
    equal(addon:HasSettingsImportBackup(), false, "fresh install has no fictional backup")
    equal(addon:PrepareSettingsRestore(), nil, "restore without backup is rejected")
    local original = unpackSettings(env, assert(addon:ExportSettings("all")))
    local packet = copy(original)
    packet.classes.MAGE.mobility.position.x = 222
    truthy(addon:ConfirmSettingsImport(prepareSettings(addon, packSettings(env, packet))))
    local current = unpackSettings(env, assert(addon:ExportSettings("all")))
    equal(current.classes.MAGE.mobility.position.x, 222, "first confirmed import applied")
    local transaction = assert(addon:PrepareSettingsRestore())
    equal(addon:GetMobilityConfig().position.x, 222, "restore preview does not mutate settings")
    addon:CancelSettingsImport()
    equal(addon:ConfirmSettingsImport(transaction), false, "canceled restore cannot commit")
    transaction = assert(addon:PrepareSettingsRestore())
    truthy(addon:ConfirmSettingsImport(transaction), "restore uses the same atomic confirmation pipeline")
    same(unpackSettings(env, assert(addon:ExportSettings("all"))), original, "restored export is equivalent without recursively exporting backup")
    local length = #assert(addon:ExportSettings("all"))
    for _ = 1, 5 do truthy(addon:ConfirmSettingsImport(prepareSettings(addon, packSettings(env, original)))) end
    equal(#assert(addon:ExportSettings("all")), length, "repeated import cannot grow export through nested backup history")
end)

test("RC removed Theme page and drag copy leave contiguous navigation automatic visuals and actual dragging", function()
    local _, addon, state = auraFixture(62)
    local panel = options(addon)
    equal(panel.transfer, nil, "transfer editors are deferred until their page is first opened")
    equal(panel.pages.themes, nil, "Themes page does not exist")
    equal(addon.RefreshOptionsThemeLabels, nil, "deleted page label updater cannot be called")
    local previous, gap
    for _, button in ipairs(panel.categories) do
        truthy(button.key ~= "themes", "Themes is removed, not disabled")
        local y = button.point[5]
        if previous then
            if not gap then gap = previous - y else equal(previous - y, gap, "navigation has no removed-category gap") end
        end
        previous = y
    end
    for _, text in ipairs(state.fontStrings) do
        if type(text.textValue) == "string" then
            equal(text.textValue:find("Drag any empty area to move", 1, true), nil, "no duplicate drag instruction replaces old label")
        end
    end
    addon:SelectOptionsCategory("themes")
    equal(panel.activeCategory, "general", "stale theme category routes to General")
    local before = copy(addon.db.classes)
    local header = copy(panel.theme.header.gradient)
    state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(addon:GetAutomaticThemeInfo().bodyKey, "fire", "Body still updates without a Themes page")
    same(panel.theme.header.gradient, header, "same-faction Header is unchanged")
    same(addon.db.classes.MAGE.mobility, before.MAGE.mobility, "theme switching preserves Mobility settings")
    addon:BeginOptionsDrag("LeftButton")
    truthy(panel.dragging and panel.moving, "dragging still works without explanatory text")
    addon:CloseOptions()
    truthy(not panel.dragging and not panel.moving, "close still ends dragging")
end)

test("RC Import Export page keeps full multiline text without per-keystroke parsing or mouse capture", function()
    local _, addon, state = transferSeed()
    local panel, controls = transferPage(addon)
    equal(panel.transfer.scope, "class", "default export scope is Current class")
    for _, key in ipairs({ "transferInput", "transferOutput", "transferSummary" }) do
        local edit = controls[key]
        truthy(edit.multiLine, "transfer text is multiline")
        equal(edit.maxLetters, 0, "character cap cannot silently truncate")
        equal(edit.maxBytes, 0, "byte cap cannot silently truncate")
        equal(edit.optionsDragSurface, nil, "editor never registers as panel drag capture")
        equal(edit.scroll.optionsDragSurface, nil, "scroll area never steals selection for dragging")
    end
    local parserCalls = copy(state.codecCalls)
    local pasted = string.rep("payload line\n", 14000)
    typeText(controls.transferInput, pasted)
    equal(controls.transferInput:GetText(), pasted, "large multiline input is preserved until explicit backend validation")
    same(state.codecCalls, parserCalls, "typing does not parse, serialize, or decode")
    truthy(controls.transferInput:GetHeight() > controls.transferInput.minimumHeight, "long text creates scrollable content")
    controls.transferInput.scroll.scripts.OnMouseWheel(controls.transferInput.scroll, -3)
    truthy(controls.transferInput.scroll:GetVerticalScroll() > 0, "mouse wheel scrolls content")
    local before, metrics = copy(addon.db), transferMetrics(addon, state)
    controls.transferExport:Click()
    local exported = controls.transferOutput:GetText()
    truthy(exported:match("^CARGOUICFG:1:"), "Export produces a complete portable string")
    equal(exported, panel.transfer.exportText, "export display is not truncated")
    truthy(controls.transferOutput:HasFocus() and controls.transferOutput.highlight, "copy uses selectable text")
    controls.transferSelectAll:Click()
    truthy(controls.transferOutput.highlight, "Select all selects text rather than claiming clipboard access")
    same(addon.db, before, "UI Export is still read-only")
    same(transferMetrics(addon, state), metrics, "UI Export does not refresh monitors")
    addon:CloseOptions()
    for _, edit in ipairs(panel.transfer.editors) do equal(edit:GetText(), "", "close clears large text"); equal(edit:HasFocus(), false, "close releases focus") end
    equal(panel.transfer.exportText, nil, "close releases temporary export string")
end)

test("RC UI import reviews before commit supports wrapped paste and restores the last backup only after confirmation", function()
    local env, addon = transferSeed()
    local text = assert(addon:ExportSettings("class"))
    local prefix, payload = text:match("^(CARGOUICFG:1:)(.*)$")
    local parts = {}
    for i = 1, #payload, 71 do parts[#parts + 1] = payload:sub(i, i + 70) end
    local wrapped = "\n " .. prefix .. table.concat(parts, "\r\n") .. " \n"
    addon:UpdateSettings({ position = { x = 999 } })
    local panel, controls = transferPage(addon)
    local before = copy(addon.db)
    typeText(controls.transferInput, wrapped)
    controls.transferImport:Click()
    truthy(panel.transfer.transaction and panel.transfer.confirmation:IsShown(), "Import displays in-page review")
    same(addon.db, before, "review does not apply settings")
    truthy(#controls.transferSummary:GetText() > 0 and controls.transferConfirm:IsEnabled(), "summary and explicit confirmation available")
    controls.transferCancel:Click()
    same(addon.db, before, "Cancel is read-only")
    typeText(controls.transferInput, wrapped); controls.transferImport:Click(); controls.transferConfirm:Click()
    equal(addon:GetMobilityConfig().position.x, 130, "Confirm applied reviewed value")
    equal(controls.transferInput:GetText(), "", "successful commit clears text")
    truthy(controls.transferRestore:IsEnabled(), "one-level restore is now available")
    controls.transferRestore:Click()
    equal(addon:GetMobilityConfig().position.x, 130, "Restore also waits for confirmation")
    controls.transferConfirm:Click()
    equal(addon:GetMobilityConfig().position.x, 999, "confirmed restoration returns pre-import user configuration")
    truthy(panel.pages.importExport:IsShown(), "same page handles restore; no extra window")
end)

test("RC import review cancels on close category identity and combat without deferred auto-commit", function()
    local env, addon, state = transferSeed()
    local text = assert(addon:ExportSettings("class"))
    addon:UpdateSettings({ position = { x = 909 } })
    local panel, controls = transferPage(addon)
    for _, action in ipairs({ "close", "category", "identity", "combat" }) do
        transferPage(addon)
        typeText(controls.transferInput, text); controls.transferImport:Click()
        local transaction = assert(panel.transfer.transaction)
        if action == "close" then addon:CloseOptions()
        elseif action == "category" then addon:SelectOptionsCategory("general")
        elseif action == "identity" then state.specID = 63; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
        else state:fire("PLAYER_REGEN_DISABLED") end
        equal(panel.transfer.transaction, nil, action .. " drops pending review")
        equal(controls.transferInput:GetText(), "", action .. " drops uncommitted text")
        equal(addon:ConfirmSettingsImport(transaction), false, action .. " invalidates private transaction")
        equal(addon:GetMobilityConfig().position.x, 909, action .. " never changes current value")
        if action == "combat" then
            env.SlashCmdList.CARGOUI(""); state:fire("PLAYER_REGEN_ENABLED"); state:flushTimers()
            truthy(panel:IsShown(), "previous combat Options queue semantics still work")
            equal(addon:GetMobilityConfig().position.x, 909, "deferred open cannot submit old import")
            equal(panel.transfer.transaction, nil, "reopen has no executable old review")
        end
        state.specID = 62; syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    end
end)

test("RC repeated equivalent imports and open cancel cycles keep native resources bounded", function()
    local _, addon, state = transferSeed()
    local text = assert(addon:ExportSettings("class"))
    transferPage(addon)
    truthy(addon:ConfirmSettingsImport(prepareSettings(addon, text)))
    local metrics = transferMetrics(addon, state)
    local fonts = #state.auraFonts
    for _ = 1, 12 do
        truthy(addon:ConfirmSettingsImport(prepareSettings(addon, text)))
        same(transferMetrics(addon, state), metrics, "equivalent import cannot accumulate runtime resources")
        local transaction = prepareSettings(addon, text)
        addon:CancelSettingsImport()
        equal(addon:ConfirmSettingsImport(transaction), false, "canceled review never gains authority after repetition")
    end
    equal(#state.auraFonts, fonts, "font availability probing reuses bounded owned Font")
    addon:CloseOptions()
    local hiddenCalls = copy(state.codecCalls)
    for _ = 1, 4 do state:advance(1) end
    same(state.codecCalls, hiddenCalls, "hidden page does not generate or decode settings in the background")
end)

test("RC font availability accepts documented nil SetFont success and warns on actual missing resources", function()
    local env, source = transferSeed()
    local packet = unpackSettings(env, assert(source:ExportSettings("class")))
    packet.classes.MAGE.mobility.style.font.face = "morpheus"
    local text = packSettings(env, packet)
    local _, target, state = login(nil, false, { proc = {}, specID = 62, fontSetReturnsNil = true })
    truthy(target:ConfirmSettingsImport(prepareSettings(target, text)), "nil SetFont return is not a native failure indication")
    truthy(target:GetMobilityConfig().style.font.face:lower():find("morpheus", 1, true), "available requested font is preserved after nil SetFont result")
    local _, missing = login(nil, false, { proc = {}, specID = 62, fontSetReturnsNil = true,
        unavailableFonts = { ["fonts\\morpheus.ttf"] = true } })
    local transaction = prepareSettings(missing, text)
    truthy(transaction.summary:lower():find("font", 1, true), "unavailable resource is explained during review")
    truthy(missing:ConfirmSettingsImport(transaction))
    truthy(missing:GetMobilityConfig().style.font.face:lower():find("morpheus", 1, true), "requested font remains configured after an explicit fallback warning")
end)

test("RC appearance import preserves opaque live timing providers gates and business subscriptions", function()
    local env, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {}, specID = 62 })
    putAura(state, 263725, 19, 2, true); putAura(state, 375240, 13, 1, true)
    showProc(env, state, 1277420, 1027131, "LeftRight")
    transferPage(addon)
    local packet = unpackSettings(env, assert(addon:ExportSettings("class")))
    packet.classes.MAGE.mobility.position.x = 340
    packet.classes.MAGE.mobility.freeMovePosition.y = 150
    packet.classes.MAGE.mobility.style.font.size = 33
    packet.classes.MAGE.proc["62"].style.font.size = 36
    packet.classes.MAGE.proc["62"].regions.mage_arcane_clearcasting_left = {
        position = { anchor = "CENTER", x = 110, y = -90 }, color = { r = 0.15, g = 0.8, b = 0.4 } }
    local transaction = prepareSettings(addon, packSettings(env, packet))
    local metrics, reads, calls, wrappers, native = transferMetrics(addon, state), copy(state.spellReads), {}, {}, {}
    for _, name in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "RefreshMobility",
        "ApplySettings", "RenderMobilityState", "RenderProcState", "RenderFreeMoveState" }) do
        addon[name] = function() calls[name] = (calls[name] or 0) + 1; error("appearance import invoked " .. name) end
    end
    for _, pool in pairs(addon.reminderFrames) do for _, frame in pairs(pool) do
        wrappers[frame] = { alpha = frame.alpha, writes = frame.alphaWrites, handle = frame.auraHandle,
            duration = frame.durationBinding and frame.durationBinding.duration,
            durationWrites = frame.durationBinding and frame.durationBinding.durationWrites }
    end end
    for _, slot in ipairs(state.auraSlots) do native[slot] = { slot.nativeBinding, slot.nativeBinding and slot.nativeBinding.duration } end
    local success, message = addon:ConfirmSettingsImport(transaction)
    truthy(success, message); equal(message, nil, "targeted refresh must not conceal a presentation failure")
    equal(next(calls), nil, "pure appearance never restarts live monitoring or renders cached state")
    same(transferMetrics(addon, state), metrics, "appearance changes allocate no runtime objects or listeners")
    same(state.spellReads, reads, "appearance import performs no cooldown or charge queries")
    for frame, prior in pairs(wrappers) do
        equal(frame.alpha, prior.alpha, "opaque visibility token stays bound")
        equal(frame.alphaWrites, prior.writes, "appearance never writes live opacity")
        equal(frame.auraHandle, prior.handle, "native Aura provider is retained")
        if frame.durationBinding then
            equal(frame.durationBinding.duration, prior.duration, "existing recovery duration is not replaced")
            equal(frame.durationBinding.durationWrites, prior.durationWrites, "no repeated duration binding")
        end
    end
    for slot, prior in pairs(native) do
        equal(slot.nativeBinding, prior[1], "native Aura timer binding identity survives")
        if slot.nativeBinding then equal(slot.nativeBinding.duration, prior[2], "native Aura duration is unchanged") end
    end
    equal(addon:GetMobilityConfig().position.x, 340, "targeted position really applied")
    equal(currentLive(addon).text.font[2], 33, "live Mobility font really updated")
    same(procFrame(addon, "mage_arcane_clearcasting_left").text.textColor, { 0.15, 0.8, 0.4, 1 }, "live native Proc Font recolored")
end)

test("RC commit clears owned TEST and picker drafts then restores real live state without queries", function()
    local env, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {}, specID = 62 })
    putAura(state, 263725, 19, 2, true); putAura(state, 375240, 13, 1, true)
    showProc(env, state, 1277420, 1027131, "LeftRight")
    transferPage(addon)
    local text = assert(addon:ExportSettings("class"))
    local entry = addon:GetSelectedProcColorEntry()
    truthy(addon:SetPreview("all"), "TEST samples are active before commit")
    truthy(addon:OpenProcColorPicker(entry), "owned native picker can be active during direct backend review")
    state:pickerChange(0.9, 0.1, 0.2)
    truthy(addon.procColorPickerSession, "draft is active and uncommitted")
    local transaction = assert(addon:PrepareSettingsImport(text))
    local reads, calls = copy(state.spellReads), {}
    for _, name in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "RefreshMobility" }) do
        addon[name] = function() calls[name] = (calls[name] or 0) + 1; error("TEST cleanup restarted " .. name) end
    end
    local renders = {}
    for _, name in ipairs({ "RenderMobilityState", "RenderProcState", "RenderFreeMoveState" }) do
        local original = addon[name]
        addon[name] = function(self, ...) renders[name] = (renders[name] or 0) + 1; return original(self, ...) end
    end
    local ok, message = addon:ConfirmSettingsImport(transaction)
    truthy(ok, message); equal(message, nil, "TEST cleanup and live restoration both succeeded")
    equal(addon.previewState.mode, "off", "owned TEST state ends before committed settings are displayed")
    equal(addon.procColorPickerSession, nil, "owned picker session ends")
    equal(env.ColorPickerFrame:IsShown(), false, "owned picker closes")
    equal(addon:GetProcRegionColor(entry), nil, "unconfirmed picker RGB is not imported as user configuration")
    for _, frame in pairs(addon.previewFrames) do equal(frame:IsShown(), false, "no stale TEST samples remain") end
    for name, count in pairs(renders) do equal(count, 1, name .. " restores cached live state once") end
    equal(countKeys(renders), 3, "Mobility, Proc and Free move all resume their own live presentation")
    equal(next(calls), nil, "TEST cleanup preserves active monitor configuration")
    same(state.spellReads, reads, "restoring suppressed live state does not query cooldowns")
    state:nativeTick()
    truthy(nativeText(addon) ~= "", "real depleted Mobility is visible again")
    truthy(procText(addon, state, "mage_arcane_clearcasting_left") ~= "", "real native Aura timer is visible again")
    equal(procText(addon, state, "free_move_mage"), "Free move", "real receiver text is visible again")
    local foreign = { foreign = true }
    local foreignChange, foreignCancel = function() end, function() error("must not cancel foreign picker") end
    env.ColorPickerFrame:SetupColorPickerAndShow({ r = 0.2, g = 0.3, b = 0.4,
        swatchFunc = foreignChange, cancelFunc = foreignCancel, extraInfo = foreign })
    transaction = assert(addon:PrepareSettingsImport(text))
    truthy(addon:ConfirmSettingsImport(transaction))
    truthy(env.ColorPickerFrame:IsShown(), "another addon's shared picker remains open")
    equal(env.ColorPickerFrame.extraInfo, foreign, "another addon's owner survives")
    equal(env.ColorPickerFrame.swatchFunc, foreignChange, "another addon's callbacks survive")
end)

test("RC backup restoration removes classes created after the saved backup without scope aliasing", function()
    local env, addon = transferSeed()
    local before = unpackSettings(env, assert(addon:ExportSettings("all")))
    local packet = copy(before); packet.classes.MAGE.mobility.position.x = 771
    truthy(addon:ConfirmSettingsImport(prepareSettings(addon, packSettings(env, packet))))
    addon.db.classes.DRUID = { mobility = addon:NewMobilityConfig(), proc = { [102] = addon:NewProcConfig() } }
    addon.db.classes.DRUID.mobility.position.x = 834
    local transaction = assert(addon:PrepareSettingsRestore())
    truthy(addon.db.classes.DRUID, "preparation must not remove a post-backup class")
    truthy(addon:ConfirmSettingsImport(transaction))
    equal(addon.db.classes.DRUID, nil, "restore returns the exact prior formal class tree")
    same(unpackSettings(env, assert(addon:ExportSettings("all"))), before, "restored formal snapshot matches the pre-import backup")
    local backup = addon.db.settingsImportBackup.settings
    equal(backup.classes.DRUID, nil, "restoration preserves the latest pre-import backup")
    addon.db.classes.MAGE.mobility.position.x = 500
    equal(backup.classes.MAGE.mobility.position.x, before.classes.MAGE.mobility.position.x, "restored configuration cannot mutate the recoverable backup")
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    equal(addon.db.classes.MAGE.mobility.position.x, before.classes.MAGE.mobility.position.x, "repeated restoration stays at the pre-import snapshot instead of toggling")
end)

test("RC all-class maximum current metadata snapshot fits parser budgets and preserves independent scopes", function()
    local env, addon, state = auraFixture(62)
    local classes, specs, regions = 0, 0, 0
    for _, classRow in ipairs(themeRoster) do
        local class = classRow[1]
        local metadata = assert(addon.settingsMetadata.classes[class], "target class has explicit import ownership")
        local classConfig = { mobility = addon:NewMobilityConfig(), proc = {} }
        addon.db.classes[class] = classConfig; classes = classes + 1
        classConfig.mobility.position.x = 400 + classes
        for _, specRow in ipairs(classRow[2]) do
            local spec = specRow[1]
            local specMetadata = assert(metadata[spec], "target spec has explicit import ownership")
            local proc = addon:NewProcConfig(); classConfig.proc[spec] = proc; specs = specs + 1
            proc.style.font.size = 20 + specs % 20
            for id in pairs(specMetadata) do
                regions = regions + 1
                proc.regions[id] = { position = { anchor = "CENTER", x = 100 + regions, y = -100 - regions },
                    color = { r = (regions % 9) / 10, g = 0.5, b = 0.7 } }
            end
        end
        equal(countKeys(metadata), #classRow[2], "metadata has no extra spec under a different class")
    end
    equal(classes, 13, "independent target-client class roster")
    equal(specs, 40, "independent target-client spec roster includes Devourer")
    equal(regions, 97, "audited active and historical region metadata coverage")
    equal(countKeys(addon.settingsMetadata.classes), classes, "no unsupported metadata classes")
    local metrics = transferMetrics(addon, state)
    local text, message = addon:ExportSettings("all")
    truthy(text, message); truthy(#text < addon.settingsTransferLimits.inputBytes, "all admitted saved regions fit encoded input cap")
    local decoded = env.C_EncodingUtil.DecodeBase64(text:match("^CARGOUICFG:1:(.*)$"))
    truthy(#decoded < addon.settingsTransferLimits.decodedBytes, "all admitted saved regions fit decoded byte cap")
    same(transferMetrics(addon, state), metrics, "exporting foreign saved scopes does not activate their adapters")
    local _, target = login(nil, false, { proc = {}, specID = 62 })
    local transaction = prepareSettings(target, text)
    truthy(transaction.summary:find("MAGE", 1, true), "review names actual imported classes")
    truthy(transaction.summary:find("62", 1, true), "review identifies included specialization scopes")
    truthy(transaction.summary:find("mage_arcane_clearcasting_left", 1, true), "review names actual stable Proc regions before confirmation")
    truthy(target:ConfirmSettingsImport(transaction))
    same(unpackSettings(env, assert(target:ExportSettings("all"))), unpackSettings(env, text), "maximal whitelist data roundtrips exactly")
    local warriorX = target.db.classes.WARRIOR.mobility.position.x
    target.db.classes.MAGE.mobility.position.x = -777
    equal(target.db.classes.WARRIOR.mobility.position.x, warriorX, "separate classes never share writable tables")
    local fireSize = target.db.classes.MAGE.proc[63].style.font.size
    target.db.classes.MAGE.proc[62].style.font.size = 17
    equal(target.db.classes.MAGE.proc[63].style.font.size, fireSize, "Proc specs never share imported style tables")
    local left = target.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_left
    local right = target.db.classes.MAGE.proc[62].regions.mage_arcane_clearcasting_right
    local oldRight = copy(right); left.position.x = 999; left.color.r = 0.99
    same(right, oldRight, "distinct Proc regions never share position or RGB tables")
    print("OFFLINE-SETTINGS-CAPACITY classes=" .. classes .. ", specs=" .. specs .. ", regions=" .. regions
        .. ", encoded-bytes=" .. #text .. ", decoded-bytes=" .. #decoded .. "; native WoW codec acceptance separate")
end)

test("RC confirmed persistence with a display-refresh warning is visibly distinguished from rejection", function()
    local env, addon = transferSeed()
    local packet = unpackSettings(env, assert(addon:ExportSettings("class")))
    packet.classes.MAGE.mobility.position.x = 838
    local panel, controls = transferPage(addon)
    typeText(controls.transferInput, packSettings(env, packet)); controls.transferImport:Click()
    truthy(panel.transfer.transaction)
    addon.RefreshReminderPositions = function() error("injected presentation-only failure") end
    controls.transferConfirm:Click()
    equal(addon:GetMobilityConfig().position.x, 838, "validated persistence succeeded before presentation failed")
    equal(panel.transfer.transaction, nil, "committed transaction cannot be replayed")
    truthy(addon:HasSettingsImportBackup(), "recovery backup exists after presentation warning")
    truthy(panel.feedback:GetText():lower():find("reload", 1, true), "successful commit still explains that display needs reload")
end)

test("RC configuration metadata exactly matches class-spec region ownership without runtime activation", function()
    local data, _, _, addon, state = genericEngine({})
    local classes, scopes, regions = 0, 0, 0
    for _, row in ipairs(themeRoster) do
        classes = classes + 1
        local class, adapter = row[1], assert(data.adapters[row[1]])
        for _, specRow in ipairs(row[2]) do
            local spec, expected = specRow[1], {}
            local definitions = class == "MAGE" and adapter:GetProcDefinitions(spec) or adapter.procFactory(spec)
            for _, definition in ipairs(definitions) do for _, region in ipairs(definition.regions) do expected[region.id] = true end end
            same(addon.settingsMetadata.classes[class][spec], expected, "import ownership equals shipped source definitions for " .. class .. "/" .. spec)
            scopes = scopes + 1; regions = regions + countKeys(expected)
        end
    end
    equal(classes, 13, "all classes audited from independent target roster")
    equal(scopes, 40, "all target spec ownership scopes audited")
    equal(regions, 97, "all saved active/historical regions have exact source ownership")
    equal(#state.auraSlots, 0, "offline ownership audit never initializes native Aura providers")
    equal(state.realReads, 0, "metadata audit does not query gameplay")
end)
end

-- Append-only regression groups for the RC.1 drag hotfix.
-- Cursor-origin/Stop-shift injections are fault models, NOT observations of
-- Blizzard's C++ mover. The ordinary rc.1 204 tests remain unchanged.
do
local function near(actual, expected, label)
    truthy(type(actual) == "number" and math.abs(actual - expected) < 0.000001,
        (label or "coordinate") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function begin(surface)
    surface:GetScript("OnDragStart")(surface, "LeftButton")
end
local function stop(surface)
    surface:GetScript("OnDragStop")(surface)
end
local function instrument(panel)
    local nativeStart, nativeStop = panel.StartMoving, panel.StopMovingOrSizing
    local calls = { starts = 0, stops = 0 }
    function panel:StartMoving(always)
        calls.starts, calls.always = calls.starts + 1, always
        return nativeStart(self, always)
    end
    function panel:StopMovingOrSizing()
        calls.stops = calls.stops + 1
        return nativeStop(self)
    end
    function panel:SetUserPlaced(value) self.userPlaced = value end
    return calls
end

test("DRAG FIX every initiating surface requests the current native mouse origin without reanchoring at pickup", function()
    local env, addon, state = login()
    local panel = options(addon)
    local calls = instrument(panel)
    local surfaces = { panel, panel.header, panel.pages.general, panel.appearanceScroll.scrollChild }
    for _, surface in ipairs(surfaces) do
        local x, y = panel:GetCenter()
        begin(surface)
        equal(calls.always, true, "explicit alwaysStartFromMouse instead of stale root press origin")
        equal(panel.dragSource, surface, "source retained separately from moved root")
        equal(state.movingFrame, panel, "native mover only owns Options root")
        local nx, ny = panel:GetCenter()
        near(nx, x, "no Lua pickup reanchor X"); near(ny, y, "no Lua pickup reanchor Y")
        stop(surface)
        equal(panel.dragSource, nil, "source released")
        equal(panel.userPlaced, false, "one SavedVariables owner instead of a native saved position")
    end
    for _, frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"), nil, "no polling added") end
end)

test("DRAG FIX global mouse-up outside the initiating surface ends exactly one session", function()
    local _, addon, state = login()
    local panel = options(addon); local calls = instrument(panel)
    local old = copy(addon.db.options.position)
    begin(panel.pages.general)
    equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP, 1, "one temporary global release callback")
    panel.mockCenter = { 1130, 450 }
    state:fire("GLOBAL_MOUSE_UP", "RightButton")
    truthy(panel.dragging, "another button cannot end left drag")
    state:fire("GLOBAL_MOUSE_UP", "LeftButton")
    truthy(not panel.dragging and not panel.moving, "outside release unlatches mover")
    equal(calls.stops, 1, "one stop")
    near(addon.db.options.position.x, 170); near(addon.db.options.position.y, -90)
    state:fire("GLOBAL_MOUSE_UP", "LeftButton"); stop(panel.pages.general)
    equal(calls.stops, 1, "later duplicated local/global releases are no-ops")
    equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP, nil, "idle callback removed")
end)

test("DRAG FIX a fresh global left press releases a lost-up session before the next drag", function()
    local _, addon, state = login()
    local panel = options(addon); local calls = instrument(panel)
    begin(panel.header)
    state:fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    truthy(not panel.dragging and state.movingFrame == nil, "stale prior capture cleared without reload")
    begin(panel.pages.general)
    equal(calls.starts, 2, "new source starts fresh")
    equal(panel.dragSource, panel.pages.general)
    state:fire("GLOBAL_MOUSE_UP", "LeftButton")
end)

test("DRAG FIX unrelated child hide and delayed child STOP do not end a different source drag", function()
    local _, addon, state = login()
    local panel = options(addon)
    panel.pages.mobility:Show()
    begin(panel.header)
    panel.pages.mobility:Hide()
    truthy(panel.dragging and state.movingFrame == panel, "unrelated OnHide cannot save/reanchor moving parent")
    stop(panel.header)
    begin(panel.pages.general)
    stop(panel.header)
    truthy(panel.dragging, "late previous-source STOP cannot cancel current drag")
    panel.pages.general:Hide()
    truthy(not panel.dragging and state.movingFrame == nil, "actual source hide does end session")
end)

test("DRAG FIX source ancestor hiding and Options combat closure release ownership without disturbing reminders", function()
    local _, addon, state = login()
    local panel = options(addon)
    addon:OpenAppearance("mobility")
    begin(panel.appearanceScroll.scrollChild)
    panel.appearanceScroll:Hide()
    truthy(not panel.dragging and not panel.moving, "hidden source ancestor ends dragging")
    panel.appearanceScroll:Show()
    begin(panel.header)
    state.inCombat = true; state:fire("PLAYER_REGEN_DISABLED")
    truthy(not panel.dragging and not panel:IsShown() and not panel.moving, "combat ends root session")
    equal(panel.dragSource, nil); equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP, nil)
    equal(addon.pendingOptionsOpen, nil, "drag cleanup does not enqueue reopening")
    truthy(#state.errors == 0, "no event error")
end)

test("DRAG FIX stopping is reentrant-safe and persists visual center before native anchor conversion", function()
    local _, addon = login()
    local panel = options(addon); local native = panel.StopMovingOrSizing
    local calls = 0
    function panel:StopMovingOrSizing()
        calls = calls + 1
        -- Fault injection: native anchor conversion changes reported center.
        -- Also simulate an OnDragStop callback re-entering the save function.
        self.mockCenter = { 1700, 200 }
        if calls == 1 then addon:SaveOptionsPosition() end
        return native(self)
    end
    begin(panel.header); panel.mockCenter = { 1085, 495 }
    stop(panel.header)
    equal(calls, 1, "ownership cleared before native STOP reentry")
    near(addon.db.options.position.x, 125, "save before anchor-rewrite X")
    near(addon.db.options.position.y, -45, "save before anchor-rewrite Y")
end)

test("DRAG FIX invalid transient geometry releases capture without writing corrupt SavedVariables", function()
    local _, addon, state = login()
    local panel = options(addon); local before = copy(addon.db)
    begin(panel.header)
    panel.mockCenter = { 0 / 0, math.huge }
    stop(panel.header)
    same(addon.db, before, "invalid centers do not persist")
    truthy(not panel.dragging and not panel.moving, "invalid geometry cannot leave a drag latched")
    equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP, nil)
    equal(panel.dragSource, nil)
    truthy(#state.errors == 0)
end)

test("DRAG FIX scale matrix uses root visual center and never the source child coordinates", function()
    for _, parentScale in ipairs({0.533333, 0.71, 1, 1.25}) do
        for _, panelScale in ipairs({0.65, 0.85, 1}) do
            local env, addon, state = login()
            env.UIParent.GetEffectiveScale = function() return parentScale end
            local panel = options(addon)
            panel:SetScale(panelScale)
            panel.header:SetScale(0.6)
            for i = 1, 20 do
                begin(panel.header)
                local ox, oy = i * 7 - 130, 100 - i * 4
                panel.mockCenter = { (960 + ox) / panelScale, (540 + oy) / panelScale }
                stop(panel.header)
                near(addon.db.options.position.x, ox, "UIParent-relative x")
                near(addon.db.options.position.y, oy, "UIParent-relative y")
                panel.mockCenter = nil
                local x,y = panel:GetCenter()
                near(x * panelScale, 960 + ox); near(y * panelScale, 540 + oy)
            end
            equal(#state.errors, 0)
        end
    end
end)

test("DRAG FIX viewport or world transition ends a session and keeps unrelated subscriptions", function()
    for _, event in ipairs({"UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_LEAVING_WORLD"}) do
        local _, addon, state = login()
        local panel = options(addon)
        local other=0
        local function foreign() other=other+1 end
        addon:RegisterEvent(event,foreign)
        begin(panel.header)
        state:fire(event)
        truthy(not panel.dragging and state.movingFrame == nil, event .. " ends active dragging")
        equal(other,1,"other module event callback preserved")
        equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP,nil)
        state:fire(event); equal(other,2,"own-only unsubscribe")
    end
end)

test("DRAG FIX repeated source switching leaves no listeners timers frames or native work running", function()
    local _, addon, state = login()
    local panel = options(addon)
    local calls=instrument(panel)
    local baseline=copy(addon:GetEventDiagnostics())
    local frames=#state.frames
    local reads,slots,bindings=state.realReads,#state.auraSlots,#state.bindings
    for i=1,250 do
        local source=i%2==0 and panel.header or panel.pages.general
        begin(source); begin(source)
        equal(addon:GetEventDiagnostics().perEvent.GLOBAL_MOUSE_UP,1,"coalesced registration")
        state:fire("GLOBAL_MOUSE_UP", "LeftButton")
        same(addon:GetEventDiagnostics(), baseline,"idle event inventory restored")
        equal(panel.dragSource,nil); truthy(not panel.dragging)
    end
    equal(calls.starts,250,"one native start per session")
    equal(calls.stops,250,"one native stop per session")
    equal(#state.frames,frames); equal(state.realReads,reads)
    equal(#state.auraSlots,slots); equal(#state.bindings,bindings)
    equal(state:activeTimers(),0,"no drag timer survives")
    for _,frame in ipairs(state.frames) do equal(frame:GetScript("OnUpdate"),nil) end
end)
test("DRAG FIX a native synchronous stop during pickup does not leave boundary listeners registered", function()
    local _, addon, state = login()
    local panel = options(addon)
    local baseline = copy(addon:GetEventDiagnostics())
    local native = panel.StartMoving
    function panel:StartMoving(always)
        native(self, always)
        addon:SaveOptionsPosition() -- Fault-injected native reentrancy, not a live observation.
    end
    begin(panel.header)
    truthy(not panel.dragging and not panel.moving)
    same(addon:GetEventDiagnostics(), baseline, "finished pickup cannot register stale listeners afterward")
    equal(#state.errors, 0)
end)

end

test("RC2 drag cleanup preserves foreign global callbacks and ignores unrelated or opaque mouse buttons", function()
    local _, addon, state = login()
    local panel = options(addon)
    local events = { "GLOBAL_MOUSE_UP", "GLOBAL_MOUSE_DOWN", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_LEAVING_WORLD" }
    local calls = {}
    local function foreign(_, event) calls[event] = (calls[event] or 0) + 1 end
    for _, event in ipairs(events) do addon:RegisterEvent(event, foreign) end
    local baseline = copy(addon:GetEventDiagnostics())
    panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
    for _, event in ipairs(events) do
        equal(addon:GetEventDiagnostics().perEvent[event], baseline.perEvent[event] + 1, "drag adds only its own callback")
    end
    for _, event in ipairs({ "GLOBAL_MOUSE_UP", "GLOBAL_MOUSE_DOWN" }) do
        for _, button in ipairs({ "RightButton", "MiddleButton", secret("LeftButton") }) do
            state:fire(event, button)
            truthy(panel.dragging and state.movingFrame == panel, "unrelated/opaque button cannot release left drag")
        end
    end
    state:fire("GLOBAL_MOUSE_UP", "LeftButton")
    same(addon:GetEventDiagnostics(), baseline, "release removes only owned callbacks from all boundary events")
    equal(calls.GLOBAL_MOUSE_UP, 4, "foreign release callback sees every dispatched event")
    for _, event in ipairs(events) do
        local prior = calls[event] or 0
        state:fire(event, "LeftButton")
        equal(calls[event], prior + 1, "foreign callback remains live after drag release")
    end
    equal(#state.errors, 0, "no restricted button comparison or event ownership error")
end)

test("RC2 unavailable opaque or rejected drag geometry always releases capture without saving or poisoning the next drag", function()
    local cases = {
        { "missing center", center = function() return nil, nil end },
        { "opaque center", center = function() return secret(123), secret(456) end },
        { "non-numeric center", center = function() return "960", 540 end },
        { "zero panel effective scale", scale = 0 },
        { "negative panel effective scale", scale = -1 },
        { "opaque panel effective scale", scale = secret(1) },
        { "nonfinite panel effective scale", scale = math.huge },
        { "zero parent effective scale", parentScale = 0 },
        { "opaque parent effective scale", parentScale = secret(1) },
        { "coordinates rejected by setting range", center = function() return 1e6, 540 end },
    }
    for _, case in ipairs(cases) do
        local env, addon, state = login()
        local panel = options(addon)
        local before, baseline = copy(addon.db), copy(addon:GetEventDiagnostics())
        local center, scale, parentScale = panel.GetCenter, panel.GetEffectiveScale, env.UIParent.GetEffectiveScale
        panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
        panel.GetCenter = case.center or function() return 1080, 500 end
        if case.scale ~= nil then panel.GetEffectiveScale = function() return case.scale end end
        if case.parentScale ~= nil then
            -- Model each native getter's returned value directly. Do not make
            -- the Lua mock calculate the child's scale from an opaque parent.
            panel.GetEffectiveScale = function() return 1 end
            env.UIParent.GetEffectiveScale = function() return case.parentScale end
        end
        state:fire("GLOBAL_MOUSE_UP", "LeftButton")
        same(addon.db, before, case[1] .. " leaves stored configuration unchanged")
        truthy(not panel.dragging and not panel.moving and not state.movingFrame, case[1] .. " releases native movement")
        equal(panel.dragSource, nil, case[1] .. " releases source ownership")
        same(addon:GetEventDiagnostics(), baseline, case[1] .. " leaves no boundary listeners")
        panel.GetCenter, panel.GetEffectiveScale, env.UIParent.GetEffectiveScale = center, scale, parentScale
        panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
        panel.mockCenter = { 1080, 500 }; state:fire("GLOBAL_MOUSE_UP", "LeftButton")
        equal(addon.db.options.position.x, 120, "next normal drag recovers without reload")
        equal(addon.db.options.position.y, -40, "next normal drag does not inherit invalid geometry")
        equal(#state.errors, 0, case[1] .. " is safely handled")
    end
end)

test("RC2 global drag releases save only Options position while live native timers and opaque gates continue", function()
    local _, addon, state = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 95,
        chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {} })
    putAura(state, 48108, 19, 1, true); putAura(state, 375240, 11, 1, true)
    local panel = options(addon)
    local config, reads, native, frames = copy(addon.db.classes), copy(state.spellReads), {}, {}
    local slots, bindings = #state.auraSlots, #state.bindings
    for _, slot in ipairs(state.auraSlots) do native[slot] = { slot.nativeBinding, slot.nativeBinding and slot.nativeBinding.duration } end
    for _, pool in pairs(addon.reminderFrames) do for _, frame in pairs(pool) do
        frames[frame] = { alpha = frame.alpha, alphaWrites = frame.alphaWrites,
            duration = frame.durationBinding and frame.durationBinding.duration,
            durationWrites = frame.durationBinding and frame.durationBinding.durationWrites }
    end end
    for _, method in ipairs({ "ConfigureMobility", "ConfigureProc", "ConfigureFreeMove", "ApplySettings", "RefreshMobility" }) do
        addon[method] = function() error("global drag release cannot reconfigure or query gameplay: " .. method) end
    end
    for index, source in ipairs({ panel.header, panel.pages.general, panel }) do
        source:GetScript("OnDragStart")(source, "LeftButton")
        panel.mockCenter = { 960 + index * 24, 540 - index * 12 }
        state:fire("GLOBAL_MOUSE_UP", "LeftButton")
        equal(addon.db.options.position.x, index * 24, "global release saves actual shell offset")
        equal(addon.db.options.position.y, -index * 12, "global release saves actual shell offset")
    end
    same(addon.db.classes, config, "global release preserves every reminder configuration")
    same(state.spellReads, reads, "global release never queries protected spell state")
    equal(#state.auraSlots, slots); equal(#state.bindings, bindings)
    for frame, prior in pairs(frames) do
        equal(frame.alpha, prior.alpha, "native opaque gate remains bound")
        equal(frame.alphaWrites, prior.alphaWrites, "release does not overwrite visibility")
        if frame.durationBinding then
            equal(frame.durationBinding.duration, prior.duration, "native recovery timer object retained")
            equal(frame.durationBinding.durationWrites, prior.durationWrites, "release never rebinds recovery duration")
        end
    end
    for slot, prior in pairs(native) do
        equal(slot.nativeBinding, prior[1], "native Proc/Free move binding retained")
        if slot.nativeBinding then equal(slot.nativeBinding.duration, prior[2], "native Aura duration retained") end
    end
    state:advance(3)
    equal(nativeText(addon), "No Shimmer\n12.0", "real Mobility timer continues from original recovery")
    equal(procText(addon, state, "mage_fire_hot_streak_left"), "16.0", "real Proc timer continues from original aura")
    equal(procText(addon, state, "free_move_mage"), "Free move", "real Time Spiral receiver remains active")
    equal(#state.errors, 0, "no gameplay tripwire was reached")
end)

test("RC2 Options disables native position persistence at creation and restores only saved shell coordinates after reload", function()
    local env, addon = login()
    local create = env.CreateFrame
    local calls = {}
    env.CreateFrame = function(kind, name, ...)
        local frame = create(kind, name, ...)
        if name == "CarGOUIOptionsFrame" then
            function frame:SetDontSavePosition(value) calls.noSave = value end
            function frame:SetUserPlaced(value) calls.userPlaced = value; calls.userWrites = (calls.userWrites or 0) + 1 end
        end
        return frame
    end
    local panel = options(addon)
    equal(calls.noSave, true, "native layout-cache persistence disabled before first use")
    equal(calls.userPlaced, false, "new root does not inherit user-placed ownership")
    equal(calls.userWrites, 1, "creation initializes native persistence ownership once")
    panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
    panel.mockCenter = { 1100, 465 }
    panel.header:GetScript("OnDragStop")(panel.header)
    equal(calls.userPlaced, false, "release clears native user-placed state")
    equal(calls.userWrites, 2, "release resets native ownership once")
    local _, reloaded = login(copy(addon.db))
    local restored = options(reloaded)
    equal(reloaded.db.options.position.x, 140); equal(reloaded.db.options.position.y, -75)
    local x, y = restored:GetCenter()
    equal(x, 1100, "reload restores saved visual center X")
    equal(y, 465, "reload restores saved visual center Y")
end)

assert(loadfile(testRoot .. "/launcher_smoke.lua"))(setmetatable({ test = test, equal = equal, truthy = truthy,
    same = same, copy = copy, secret = secret, root = root, metadata = metadata, login = login, setup = setup,
    options = options, transferSeed = transferSeed, transferPage = transferPage,
    prepareSettings = prepareSettings, packSettings = packSettings, unpackSettings = unpackSettings,
    transferMetrics = transferMetrics, mobilityLogin = mobilityLogin, putAura = putAura,
    showProc = showProc, procFrame = procFrame, counts = counts }, { __index = launcherHarness }))

assert(loadfile(testRoot .. "/localization_smoke.lua"))(setmetatable({ test = test, equal = equal, truthy = truthy,
    same = same, copy = copy, secret = secret, root = root, login = login, setup = setup,
    options = options, putAura = putAura }, { __index = launcherHarness }))

assert(loadfile(testRoot .. "/font_resources_smoke.lua"))(setmetatable({ test = test, equal = equal, truthy = truthy,
    same = same, copy = copy, root = root, login = login, setup = setup, options = options,
    mobilityLogin = mobilityLogin, putAura = putAura, currentLive = currentLive, procFrame = procFrame },
    { __index = launcherHarness }))

assert(loadfile(testRoot .. "/class_tools_research_smoke.lua"))({ test = test, equal = equal,
    truthy = truthy, same = same, copy = copy, root = root, metadata = metadata,
    researchRoot = testRoot .. "/..",
    login = login, mobilityLogin = mobilityLogin, putAura = putAura,
    nativeText = nativeText, procText = procText })

for _, suite in ipairs({ "proc_appearance_data.lua", "proc_appearance_renderer.lua", "proc_suppression.lua", "proc_animation_contract.lua", "proc_numeric_renderer.lua", "proc_appearance_options.lua",
    "numeric_controls.lua", "numeric_options.lua", "proc_numeric_options.lua", "proc_tint_options.lua",
    "modern_controls.lua", "modern_shell.lua", "modern_pages.lua", "modern_slider_contract.lua", "contextual_options.lua", "proc_artwork_color_picker.lua", "proc_diagnostics.lua", "proc_native_lifecycle.lua", "proc_safety.lua", "proc_preview_safety.lua", "proc_runtime_lifecycle.lua" }) do
    assert(loadfile(testRoot .. "/" .. suite))(setmetatable({
        test = test, equal = equal, truthy = truthy, same = same, copy = copy, secret = secret,
        root = root, metadata = metadata, login = login, setup = setup, options = options,
        putAura = putAura, showProc = showProc, procFrame = procFrame, procText = procText,
        mobilityLogin = mobilityLogin, currentLive = currentLive, counts = counts,
        transferSeed = transferSeed, transferPage = transferPage, prepareSettings = prepareSettings,
        packSettings = packSettings, unpackSettings = unpackSettings, transferMetrics = transferMetrics,
    }, { __index = launcherHarness }))
end

assert(failed == 0, failed .. " of " .. total .. " offline smoke tests failed.")
print("All " .. total .. " offline smoke tests passed.")
