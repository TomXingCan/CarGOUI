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
    env.CarGOUIDB = saved
    env.SlashCmdList = {}
    env.UISpecialFrames = {}
    env.UIParent = { name = "UIParent", GetWidth = function() return 1920 end,
        GetHeight = function() return 1080 end, GetEffectiveScale = function() return 1 end }
    function env.UIParent:GetCenter() return self:GetWidth() / 2, self:GetHeight() / 2 end
    env.STANDARD_TEXT_FONT = client.standardFont or "Fonts\\FRIZQT__.ttf"
    env.GameFontNormal = { template = "GameFontNormal" }
    env.GameFontHighlight = { template = "GameFontHighlight" }
    env.GameFontHighlightSmall = { template = "GameFontHighlightSmall" }
    local state = { frames = {}, errors = {}, messages = {}, loggedIn = loggedIn or false,
        fontWrites = 0, textWrites = 0, timers = 0, animations = {}, textures = {}, masks = {}, fontStrings = {},
        specID = client.specID or 63, classToken = client.classToken or "MAGE", realReads = 0,
        inCombat = client.inCombat or false, clock = 100, pendingTimers = {},
        faction = client.faction or "Alliance", factionReads = 0, gradientWrites = 0,
        bindings = {}, formatters = {}, curves = {}, curveEvaluations = {},
        spellReads = {}, liveMeasurements = 0, alphaReads = 0, classColorReads = 0 }
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
    env.GetBuildInfo = function() return "12.1.0", "99999", "Sep 26 2026", 120100 end
    env.GetLocale = function() return client.locale or "enUS" end
    env.GetTime = function() return state.clock end
    env.issecretvalue = isSecret
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
        SpellBookSpellBank = { Player = 0, Pet = 1 }, LuaCurveType = { Step = 0 } }
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
        for _, binding in ipairs(self.bindings) do
            if binding.enabled then binding:UpdateFontString() end
        end
    end
    function state:advance(seconds) self.clock = self.clock + seconds; self:nativeTick() end

    if client.mobility then
        state.mobility = client.mobility
        state.mobility.known = state.mobility.known or { [1953] = true }
        state.mobility.spells = state.mobility.spells or {}
        -- Public metadata fixtures model the audited ordinary spell interval and
        -- GCD envelope. They do not prove actual client values or semantics.
        state.baseCooldowns = client.baseCooldowns or { [1953] = { 500, 1500 }, [212653] = { 500, 0 } }
        env.GetSpellBaseCooldown = function(id)
            truthy(id == 1953 or id == 212653, "base metadata remains limited to Blink/Shimmer")
            local record = state.baseCooldowns[id]
            if record then return unpack(record) end
        end
        local function spellData(id, api)
            truthy(id == 1953 or id == 212653, "live runtime only queries supported Mage spell IDs")
            state.realReads = state.realReads + 1
            state.spellReads[#state.spellReads + 1] = { id = id, api = api }
            return state.mobility.spells[id]
        end
        env.C_SpellBook = { IsSpellKnown = function(id)
            truthy(id == 1953 or id == 212653, "learning queries stay inside supported spell IDs")
            return state.mobility.known[id] or false
        end }
        env.C_Spell.GetOverrideSpell = function(id)
            truthy(id == 1953 or id == 212653, "override query scope")
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
    function object:GetObjectType() return self.kind end
    function object:SetPoint(point, relative, relativePoint, x, y)
        self.point = { point, relative, relativePoint, x or 0, y or 0 }
    end
    function object:ClearAllPoints() self.point = nil end
    function object:GetPoint() return unpack(self.point or {}) end
    function object:SetAllPoints(relative) self.allPoints = relative or self.parent end
    function object:SetScrollChild(child) self.scrollChild = child end
    function object:SetVerticalScroll(value) self.verticalScroll = value end
    function object:GetVerticalScroll() return self.verticalScroll or 0 end
    function object:GetVerticalScrollRange() return self.scrollChild and math.max(0, self.scrollChild:GetHeight() - self:GetHeight()) or 0 end
    function object:SetSize(width, height) self.width, self.height = width, height end
    function object:SetWidth(width) self.width = width end
    function object:SetHeight(height) self.height = height end
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
    function object:IsShown() return self.shown ~= false end
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
        self.fontWrites = (self.fontWrites or 0) + 1
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
        if self.nativeDurationText then self.nativeRenderedText = text end
        state.textWrites = state.textWrites + 1
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function object:GetText() return self.textValue end
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
    function object:GetTexture() return self.texture end
    function object:SetBlendMode(value) self.blendMode = value end
    function object:SetRotation(value) self.rotation = value end
    function object:SetGradient(orientation, first, last)
        equal(orientation, "HORIZONTAL", "Options gradient is native and static")
        self.gradient = { orientation = orientation, first = { first:GetRGBA() }, last = { last:GetRGBA() } }
        state.gradientWrites = state.gradientWrites + 1
    end
    function object:SetAtlas(value) self.atlas = value end
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
        state.textures[#state.textures + 1] = texture
        return texture
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
            function animation:SetFromAlpha(value) self.fromAlpha = value end
            function animation:SetToAlpha(value) self.toAlpha = value end
            function animation:SetSmoothing(value) self.smoothing = value end
            function animation:SetOffset(x, y) self.offset = { x, y } end
            function animation:SetScale(x, y) self.scale = { x, y } end
            function animation:SetFromScale(x, y) self.fromScale = { x, y } end
            function animation:SetToScale(x, y) self.toScale = { x, y } end
            self.animations[#self.animations + 1] = animation
            return animation
        end
        state.animations[#state.animations + 1] = group
        return group
    end
    if client.maskUnavailable then object.CreateMaskTexture = nil end
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

local function savedPosition(addon, env, x, y)
    equal(addon.db.position.x, x, "saved horizontal reminder offset")
    equal(addon.db.position.y, y, "saved vertical reminder offset")
end

local function savedFont(addon, size, outline)
    equal(addon.db.styles.mobility_shimmer.font.face, "Fonts\\FRIZQT__.ttf", "saved font face")
    equal(addon.db.styles.mobility_shimmer.font.size, size, "saved font size")
    equal(addon.db.styles.mobility_shimmer.font.outline, outline, "saved font outline")
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
    equal(addon.db.schemaVersion, 4, "schema version migrated")
    equal(addon.frame, nil, "display before login")
    equal(env.SLASH_CARGOUI1, "/cui", "primary slash")
    equal(env.SLASH_CARGOUI2, "/cargoui", "compatibility slash")
    equal(type(env.SlashCmdList.CARGOUI), "function", "slash callback")
    state:fire("PLAYER_LOGIN")
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
    equal(addon.db.styles.mobility_shimmer.scale, 1.25, "saved scale")
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
        equal(addon.db.styles.mobility_shimmer.font.size, 24, "invalid root reset")
    end
    local env, addon = login({ schemaVersion = "invalid", enabled = "yes",
        position = { x = math.huge, y = 0 / 0 },
        font = { face = false, size = -10, outline = "INVALID" },
        scale = math.huge, shadow = { enabled = "yes" }, other = "preserve me" })
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(addon.db.enabled, true, "invalid enabled setting")
    equal(addon.db.styles.mobility_shimmer.scale, 1, "invalid scale")
    equal(addon.db.styles.mobility_shimmer.shadow.enabled, true, "invalid shadow")
    equal(addon.db.other, "preserve me", "unrelated setting")
    local _, addon2 = login({ position = true, font = "bad", shadow = 9, scale = -1 })
    equal(addon2.db.position.x, 0, "malformed position")
    equal(addon2.db.styles.mobility_shimmer.font.size, 24, "malformed font")
    equal(addon2.db.styles.mobility_shimmer.shadow.enabled, true, "malformed shadow")
    local env3, addon3 = login({ position = { x = 10001, y = -10001 },
        font = { size = 73 }, scale = 3.01 })
    savedPosition(addon3, env3, 0, 0)
    savedFont(addon3, 24, "OUTLINE")
    equal(addon3.db.styles.mobility_shimmer.scale, 1, "finite out-of-range scale")
end)

test("slash commands retain positions visibility and reset but cannot edit global appearance", function()
    local env, addon, state = login(nil)
    local command = env.SlashCmdList.CARGOUI
    command("help"); command("status"); command("position 35 -60")
    savedPosition(addon, env, 35, -60)
    local appearance = copy(addon.db.styles)
    for _, legacy in ipairs({ "fontsize 30", "outline none", "outline thickoutline", "scale 1.2", "shadow off" }) do
        command(legacy)
        same(addon.db.styles, appearance, "legacy global style command cannot modify reminder styles")
    end
    command("hide"); equal(addon.db.enabled, false, "hidden state saved")
    command("show"); equal(addon.db.enabled, true, "shown state saved")
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
    equal(reloaded.db.enabled, false, "hidden preference persisted")
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
    truthy(addon:UpdateSettings({ position = { x = 40 } }),
        "valid partial patch accepted")
    equal(addon.db, db, "DB reference stable")
    equal(env.CarGOUIDB, db, "SavedVariables references live DB")
    equal(addon.db.position, position, "position reference stable")
    equal(addon.db.font, fontSettings, "font reference stable")
    equal(addon.db.shadow, shadow, "shadow reference stable")
    savedPosition(addon, env, 40, 0)
    savedFont(addon, 24, "OUTLINE")
end)

test("daily per-entry Appearance controls use shared validation and survive reload", function()
    local env, addon, state = login(nil)
    local panel, controls = options(addon)
    local writes = 0
    local update = addon.UpdateSettings
    addon.UpdateSettings = function(self, patch)
        if patch.styles then
            truthy(patch.styles.mobility_shimmer, "selected style is the target")
            for key in pairs(patch.styles) do equal(key, "mobility_shimmer", "only selected style is patched") end
            writes = writes + 1
        end
        return update(self, patch)
    end
    local function changed(callback, label)
        local before = writes
        callback()
        truthy(writes > before, label .. " uses shared per-entry validation")
    end
    typeText(controls.x, "165"); enter(controls.y, "-85")
    savedPosition(addon, env, 165, -85)
    controls.enabled:Click(); equal(addon.db.enabled, false, "checkbox hides reminders")
    controls.enabled:Click()
    addon:OpenAppearance("mobility", "mobility_shimmer")
    changed(function() controls.appearanceScale:SetValue(1.35) end, "scale slider")
    equal(addon.db.styles.mobility_shimmer.scale, 1.35, "scale slider saves immediately")
    changed(function() enter(controls.appearanceScale.editBox, "1.6") end, "scale Enter")
    changed(function() controls.appearanceFontSize:SetValue(36) end, "font slider")
    changed(function() enter(controls.appearanceFontSize.editBox, "32") end, "font Enter")
    changed(function() choose(controls.appearanceOutline, "THICKOUTLINE") end, "outline")
    savedFont(addon, 32, "THICKOUTLINE")
    changed(function() choose(controls.appearanceFont, controls.appearanceFont.choices[1].value) end, "font")
    changed(function() controls.appearanceShadow:Click() end, "shadow")
    equal(addon.db.styles.mobility_shimmer.shadow.enabled, false, "shadow saved")
    equal(addon.db.styles.mobility_blink.font.size, 24, "other Mobility style untouched")
    equal(addon.db.styles.mage_fire_hot_streak_left.font.size, 24, "Proc style untouched")
    controls.close:Click()
    local _, reloaded = login(copy(env.CarGOUIDB))
    same(reloaded.db, addon.db, "GUI settings persist across reload")
    equal(#state.errors, 0, "GUI interactions produce no errors")
end)

test("pending XY edits are atomic, preserved until Enter, and discarded on close", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    typeText(controls.x, "250")
    typeText(controls.y, "not a number")
    local before = copy(addon.db)
    enter(controls.x, "250")
    same(addon.db, before, "invalid coordinate pair changes neither axis")
    truthy(type(panel.feedback:GetText()) == "string" and #panel.feedback:GetText() > 0,
        "invalid input has visible feedback")
    controls.enabled:Click()
    equal(controls.x:GetText(), "250", "unrelated update preserves pending X")
    equal(controls.y:GetText(), "not a number", "unrelated update preserves pending Y")
    enter(controls.y, "-125")
    savedPosition(addon, env, 250, -125)
    typeText(controls.x, "900")
    controls.x:SetFocus()
    controls.close:Click()
    equal(controls.x:HasFocus(), false, "close clears keyboard focus")
    addon:ToggleOptions()
    equal(tonumber(controls.x:GetText()), 250, "reopen discards unapplied X")
    equal(tonumber(controls.y:GetText()), -125, "reopen restores saved Y")
    controls.centerPosition:Click()
    savedPosition(addon, env, 0, 0)
    equal(tonumber(controls.x:GetText()), 0, "center updates X field")
    equal(tonumber(controls.y:GetText()), 0, "center updates Y field")
end)

test("invalid numeric edits show errors without changing saved values", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility_shimmer")
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

test("categories expose entry Appearance and automatic Theme without unfinished feature controls", function()
    local _, addon = login(nil)
    local panel = options(addon)
    local found = {}
    for _, category in ipairs(panel.categories) do found[category.key] = category end
    equal(found.typography, nil, "global typography category is removed")
    for _, key in ipairs({ "general", "mobility", "proc", "themes", "preview" }) do
        truthy(found[key] and found[key]:IsEnabled(), key .. " enabled")
        found[key]:Click()
        truthy(panel.pages[key]:IsShown(), key .. " page active")
        for other, page in pairs(panel.pages) do
            if other ~= key then equal(page:IsShown(), false, "other page hidden") end
        end
    end
    truthy(found.importExport and not found.importExport:IsEnabled(), "import/export stays unavailable")
    found.importExport:Click()
    truthy(panel.pages.preview:IsShown(), "unfinished category cannot activate")
end)

test("dropdown lifecycle and hidden refresh remain idle", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility_shimmer")
    controls.appearanceOutline:Click()
    truthy(controls.appearanceOutline.menu:IsShown(), "dropdown open")
    addon:SelectOptionsCategory("general")
    equal(controls.appearanceOutline.menu:IsShown(), false, "category change dismisses dropdown")
    addon:OpenAppearance("mobility", "mobility_shimmer")
    controls.appearanceOutline:Click()
    panel:Hide()
    equal(controls.appearanceOutline.menu:IsShown(), false, "closing window dismisses menu")
    local fontWrites, textWrites = state.fontWrites, state.textWrites
    for _ = 1, 5 do addon:RefreshOptions() end
    equal(state.fontWrites, fontWrites, "hidden refresh does not redraw")
    equal(state.textWrites, textWrites, "hidden refresh does not update control text")
    local savedScale = addon.db.styles.mobility_shimmer.scale
    controls.appearanceScale:SetValue(2.25)
    equal(addon.db.styles.mobility_shimmer.scale, savedScale, "hidden slider cannot update settings")
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
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 36 }, scale = 1.7 })
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
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(addon.db.styles.mobility_shimmer.scale, 1, "confirmed reset restores scale")
    equal(tonumber(controls.x:GetText()), 0, "reset clears pending X")
    equal(tonumber(controls.y:GetText()), 0, "reset refreshes Y")
    truthy(panel:IsShown(), "reset keeps Options open")
end)

test("Escape from any editable field closes Options and releases input focus", function()
    local _, addon = login(nil)
    local panel, controls = options(addon)
    for _, editBox in ipairs({ controls.x, controls.y, controls.appearanceFontSize.editBox, controls.appearanceScale.editBox }) do
        if not panel:IsShown() then addon:ToggleOptions() end
        editBox:SetFocus()
        local escape = editBox:GetScript("OnEscapePressed")
        truthy(escape, "editable field has Escape handler")
        escape(editBox)
        equal(panel:IsShown(), false, "Escape closes Options")
        equal(editBox:HasFocus(), false, "Escape releases keyboard focus")
    end
end)

test("sliders round safely while numeric inputs retain precision and require Enter", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility_shimmer")
    equal(controls.applyPosition, nil, "no XY Apply button")
    equal(controls.appearanceScale.applyButton, nil, "no scale Apply button")
    equal(controls.appearanceFontSize.applyButton, nil, "no font-size Apply button")
    for _, frame in ipairs(state.frames) do
        if frame.kind == "Button" then
            truthy(frame:GetText() ~= "Apply", "Options contains no normal-setting Apply buttons")
        end
    end
    for _, value in ipairs({ 0.5, 0.5000001, 1.049999999, 2.999999999, 3 }) do
        controls.appearanceScale:SetValue(value)
        truthy(addon:IsNumberInRange(addon.db.styles.mobility_shimmer.scale, addon.limits.scale), "rounded scale stays valid")
        truthy(math.abs(addon.db.styles.mobility_shimmer.scale * 20 - math.floor(addon.db.styles.mobility_shimmer.scale * 20 + 0.5)) < 0.00001,
            "slider produces 0.05 increments")
    end
    enter(controls.appearanceScale.editBox, "1.2375")
    equal(addon.db.styles.mobility_shimmer.scale, 1.2375, "typed scale keeps precision")
    enter(controls.appearanceFontSize.editBox, "31.5")
    equal(addon.db.styles.mobility_shimmer.font.size, 31.5, "typed font size keeps precision")
    typeText(controls.appearanceScale.editBox, "2.8")
    typeText(controls.appearanceFontSize.editBox, "70")
    controls.appearanceScale.editBox:SetFocus()
    controls.appearanceScale.editBox:ClearFocus()
    controls.appearanceFontSize.editBox:SetFocus()
    controls.appearanceFontSize.editBox:ClearFocus()
    equal(addon.db.styles.mobility_shimmer.scale, 1.2375, "unconfirmed scale stays pending")
    equal(addon.db.styles.mobility_shimmer.font.size, 31.5, "unconfirmed font stays pending")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.appearanceScale.editBox:GetText()), 1.2375, "closing discards pending scale")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 31.5, "closing discards pending font size")
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

test("zhCN clients retain English Options and saved appearance on reload", function()
    local saved
    for pass = 1, 2 do
        local env, addon = login(saved, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
        equal(env.GetLocale(), "zhCN", "regression runs on Chinese client")
        if pass == 2 then
            equal(addon.db.position.x, 37, "saved position survives reload")
            equal(addon.db.styles.mobility_shimmer.font.size, 32, "saved appearance survives reload")
        end
        env.SlashCmdList.CARGOUI("")
        local panel, controls = addon.optionsFrame, addon.optionsFrame.controls
        local categories = {}
        for _, category in ipairs(panel.categories) do categories[category.key] = category end
        equal(categories.general:GetText(), "> General", "active category is English")
        equal(categories.mobility:GetText(), "Mobility", "appearance category is English")
        equal(controls.close:GetText(), "Close", "close button is English")
        truthy(panel.feedback:GetText():find("Enter", 1, true), "opening guidance teaches Enter")
        truthy(not panel.feedback:GetText():find("Apply", 1, true), "obsolete Apply instruction gone")
        enter(controls.x, "invalid")
        truthy(panel.feedback:GetText():find("X", 1, true), "coordinate error is readable")
        enter(controls.x, "37")
        equal(panel.feedback:GetText(), "Settings applied.", "success feedback is English")
        addon:OpenAppearance("mobility", "mobility_shimmer")
        equal(controls.appearanceOutline.choices[1]:GetText(), "None", "dropdown choice is English")
        enter(controls.appearanceFontSize.editBox, "32")
        controls.reset:Click()
        equal(controls.reset:GetText(), "Confirm reset", "reset confirmation button is English")
        controls.close:Click()
        saved = copy(addon.db)
    end
end)

test("font menu applies each supported face and localized client font persists", function()
    local _, addon = login(nil, false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility_shimmer")
    local foundFriz, foundClient = false, false
    for _, entry in ipairs(controls.appearanceFont.choices) do
        choose(controls.appearanceFont, entry.value)
        equal(addon.db.styles.mobility_shimmer.font.face, entry.value, "font dropdown writes chosen face")
        if entry.value == "Fonts\\FRIZQT__.ttf" then foundFriz = true end
        if entry.value == "Fonts\\ARKai_T.ttf" then foundClient = true end
    end
    truthy(foundFriz, "Friz Quadrata remains selectable")
    truthy(foundClient, "localized client font selectable")
    local chosen = addon.db.styles.mobility_shimmer.font.face
    local _, reloaded = login(copy(addon.db), false, { locale = "zhCN", standardFont = "Fonts\\ARKai_T.ttf" })
    equal(reloaded.db.styles.mobility_shimmer.font.face, chosen, "supported saved font survives reload")
    local ok = addon:UpdateReminderStyle("mobility_shimmer", { font = { face = "fonts\\frizqt__.TTF" } })
    truthy(ok, "supported font accepted case-insensitively")
    equal(addon.db.styles.mobility_shimmer.font.face, "Fonts\\FRIZQT__.ttf", "font path canonicalized")
    equal(panel:IsShown(), true, "Options created successfully with a localized client font")
end)


test("only the Options header starts dragging and its saved position is independent", function()
    local env, addon, state = login(nil)
    addon:UpdateSettings({ position = { x = 37, y = -19 } })
    local panel, controls = options(addon)
    truthy(panel.movable and panel.clampedToScreen, "Options movable and clamped")
    local header = panel.header
    truthy(header and header.parent == panel, "distinct title drag region")
    same(header.dragButtons, { "LeftButton" }, "header accepts only left drag")
    equal(panel:GetScript("OnDragStart"), nil, "panel body never starts dragging")
    equal(panel:GetScript("OnDragStop"), nil, "panel body has no drag handler")
    for _, frame in ipairs(state.frames) do
        if frame ~= header then
            equal(frame:GetScript("OnDragStart"), nil, "only header owns a drag-start handler")
        end
    end
    header:GetScript("OnDragStart")(header, "LeftButton")
    equal(state.movingFrame, panel, "header starts moving Options")
    panel.mockCenter = { (960 + 120) / panel:GetScale(), (540 - 80) / panel:GetScale() }
    header:GetScript("OnDragStop")(header)
    equal(panel.moving, false, "release stops moving")
    equal(addon.db.options.position.x, 120, "window X saved independently")
    equal(addon.db.options.position.y, -80, "window Y saved independently")
    savedPosition(addon, env, 37, -19)
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
    equal(#state.animations, 0, "branding animation deferred until Options opens")
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
    equal(addon.db.position.x, 15, "migration preserves reminder X")
    equal(addon.db.position.y, -25, "migration preserves reminder Y")
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
    local perEntry = addon.db.reminders[entry.id].position
    local expectedX = entry.anchor.x + addon.db.position.x + perEntry.x
    local expectedY = entry.anchor.y + addon.db.position.y + perEntry.y
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
        truthy(addon.db.reminders[entry.id], "known entry settings initialized")
        if entry.kind == "proc" then
            truthy(entry.anchor.x ~= 0 or entry.anchor.y ~= 0, "Proc timers do not use global screen center")
        end
    end
    for specID, expected in pairs({ [62] = 3, [63] = 3, [64] = 4 }) do
        state.specID = specID
        local entries = addon:GetPreviewEntries()
        equal(#entries, expected, "defined entries for current Mage spec")
        local regions = {}
        for _, entry in ipairs(entries) do
            equal(entry.specID, specID, "no cross-spec reminder entry")
            if entry.kind == "proc" then
                local key = entry.anchor.x .. ":" .. entry.anchor.y
                truthy(not regions[key], "separate Proc regions have separate centers")
                regions[key] = true
            end
        end
    end
    state.classToken = "WARRIOR"
    equal(#addon:GetPreviewEntries(), 0, "unsupported class has no fabricated preview entries")
    equal(state.realReads, 0, "catalog does not query real aura/cooldown state")
end)

test("external single/all preview renders fixed samples and cleans up on stop and close", function()
    -- Isolate preview-owned subscriptions; live ownership is covered below.
    local env, addon, state = login({ mobility = { enabled = false } })
    equal(countKeys(visiblePreviews(addon)), 0, "no samples at login")
    local panel, controls = options(addon)
    equal(panel.previewFrame, nil, "obsolete static in-panel preview removed")
    addon:SelectOptionsCategory("preview")
    local entries = addon:GetPreviewEntries()
    choose(controls.previewEntry, entries[1].id)
    local saved = copy(addon.db)
    controls.previewSingle:Click()
    equal(addon.previewState.mode, "single", "single preview mode")
    equal(addon.previewState.entryId, entries[1].id, "selected sample remembered for session")
    equal(countKeys(visiblePreviews(addon)), 1, "single mode shows one defined entry")
    controls.previewAll:Click()
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
        if entry.kind == "mobility" then
            truthy(frame.text:GetText():find("No Shimmer", 1, true), "Mobility uses sample label")
            truthy(frame.text:GetText():find("8.0", 1, true), "Mobility uses fixed sample time")
        else
            truthy(frame.text:GetText():match("^%d+%.%d+$"), "Proc timer has only numeric sample text")
        end
    end
    same(addon.db, saved, "sample content never pollutes saved reminder settings")
    controls.previewStop:Click()
    equal(addon.previewState.mode, "off", "Stop returns to off")
    equal(countKeys(visiblePreviews(addon)), 0, "Stop hides all simulated reminders")
    for _, frame in pairs(frames) do equal(frame.guidance:IsVisible(), false, "Stop hides region guidance") end
    controls.previewAll:Click()
    for id, frame in pairs(frames) do equal(addon.previewFrames[id], frame, "preview frames reused") end
    controls.close:Click()
    equal(countKeys(visiblePreviews(addon)), 0, "closing window removes external preview")
    equal(addon.previewState.mode, "off", "closing resets transient preview mode")
    for _, frame in ipairs(state.frames) do
        equal(frame:IsEventRegistered("PLAYER_SPECIALIZATION_CHANGED"), false, "closed preview unsubscribes spec changes")
        equal(frame:GetScript("OnUpdate"), nil, "preview never polls per frame")
    end
    addon:ToggleOptions()
    equal(countKeys(visiblePreviews(addon)), 0, "reopening does not silently re-enable samples")
    equal(state.realReads, 0, "simulated content never reads live buffs or cooldowns")
end)

test("external preview updates only the selected region appearance and keeps stock Proc centers", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("preview")
    local entries = addon:GetPreviewEntries()
    local selected = entries[2]
    choose(controls.previewEntry, selected.id)
    controls.previewAll:Click()
    typeText(controls.entryX, "34"); typeText(controls.entryY, "invalid")
    local prior = copy(addon.db)
    enter(controls.entryX, "34")
    same(addon.db, prior, "invalid offset pair is atomic")
    enter(controls.entryY, "-17")
    addon:SelectOptionsCategory("general")
    enter(controls.x, "25"); enter(controls.y, "-50")
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
        if entry.id == selected.id then
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
    same(reloaded.db.styles[selected.id], addon.db.styles[selected.id], "region style survives reload")
    addon:SelectOptionsCategory("preview"); controls.entryReset:Click()
    same(addon.db.reminders[selected.id].position, { x = 0, y = 0 }, "position reset only resets current coordinates")
    equal(addon.db.styles[selected.id].font.size, 40, "coordinate reset preserves independent appearance")
end)

test("active preview follows current specialization and unsupported classes disable preview controls", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("preview")
    controls.previewAll:Click()
    state.specID = 64
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(countKeys(visiblePreviews(addon)), 4, "active all mode switches to Frost entries")
    for id in pairs(visiblePreviews(addon)) do truthy(id:find("mage_frost_", 1, true), "old spec samples hidden") end
    state.classToken = "WARRIOR"
    state:fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(countKeys(visiblePreviews(addon)), 0, "unsupported class removes stale samples")
    equal(controls.previewSingle:IsEnabled(), false, "unsupported single-preview action disabled")
    equal(controls.previewAll:IsEnabled(), false, "unsupported all-preview action disabled")
    truthy(panel.previewStatus:GetText() and #panel.previewStatus:GetText() > 0, "unsupported state explained")
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
    equal(countKeys(visiblePreviews(addon)), 0, "display preference hides all samples")
    for _, frame in pairs(addon.previewFrames) do
        truthy(not frame.guidance or not frame.guidance:IsVisible(), "hidden samples have no visible guidance")
    end
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
    return { frames = #state.frames, textures = #state.textures, masks = #state.masks,
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

test("combat pauses branding and resumes only while visible and enabled", function()
    local env, addon, state = login(nil)
    local panel, controls = options(addon)
    local group, header = panel.titleAnimation, panel.brandingHeader
    combatSubscriptions(state, 1)
    state:fire("PLAYER_REGEN_DISABLED")
    equal(group:IsPlaying(), false, "entering combat stops sweep immediately")
    equal(header.wordmark:GetAlpha(), 1, "combat leaves base wordmark opaque")
    equal(header.sweep:GetAlpha(), 0, "combat clears highlight residue")
    combatSubscriptions(state, 1)
    state:fire("PLAYER_REGEN_ENABLED")
    truthy(group:IsPlaying(), "visible enabled title resumes after combat")
    state:fire("PLAYER_REGEN_DISABLED")
    controls.animatedTitle:Click()
    state:fire("PLAYER_REGEN_ENABLED")
    equal(group:IsPlaying(), false, "disabled preference prevents combat-end restart")
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
    local combatPanel = options(inCombatAddon)
    equal(combatPanel.titleAnimation:IsPlaying(), false, "opening during combat starts statically")
    combatState:fire("PLAYER_REGEN_ENABLED")
    truthy(combatPanel.titleAnimation:IsPlaying(), "first opening in combat can resume after combat")
end)

test("branding callbacks stay isolated and ordinary settings do not resize or restart the art", function()
    local _, addon, state = login(nil)
    local panel = options(addon)
    local header, group = panel.brandingHeader, panel.titleAnimation
    local base = { width = header.wordmark:GetWidth(), height = header.wordmark:GetHeight(),
        point = { unpack(header.wordmark.point or {}) }, uv = copy(header.wordmark.texCoord),
        scale = header.wordmark:GetScale(), alpha = header.wordmark:GetAlpha() }
    local initialPlays, initialStops = group.plays, group.stops
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 72, outline = "THICKOUTLINE" }, scale = 3 })
    addon:OpenAppearance("mobility", "mobility_shimmer")
    addon:SelectOptionsCategory("preview")
    addon:SelectOptionsCategory("general")
    panel.header:GetScript("OnDragStart")(panel.header, "LeftButton")
    panel.mockCenter = { 1000, 550 }
    panel.header:GetScript("OnDragStop")(panel.header)
    panel.mockCenter = nil
    equal(group.plays, initialPlays, "settings, categories and dragging do not restart playing sweep")
    equal(group.stops, initialStops, "ordinary settings never interrupt sweep")
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
    same(header.accentLine.vertexColor, automaticAccent, "automatic accent applies to line")
    for _, color in ipairs({ false, "bad", {}, { 0.1, 0.2 }, { 0.1, 2, 0.3 }, { 0/0, 0.2, 0.3 } }) do
        equal(addon:UpdateBrandingTheme(color), false, "invalid theme accent rejected")
        same(header.sweep.vertexColor, automaticAccent, "invalid accent leaves previous color intact")
    end
    truthy(addon:UpdateBrandingTheme({ 0.8, 0.7, 0.4 }), "valid theme accent accepted")
    same(header.sweep.vertexColor, { 0.8, 0.7, 0.4 }, "highlight accent updates")
    same(header.accentLine.vertexColor, { 0.8, 0.7, 0.4 }, "line accent updates")
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
    client.mobility = { known = { [1953] = true, [212653] = spellID == 212653 },
        override = spellID, spells = { [spellID] = data } }
    return login(saved, false, client)
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
    same(addon.db.reminders[id].position, { x = 87, y = -21 }, "replacement preserves configured position")
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
    same(addon.db.reminders[entry.id].position, { x = 54, y = -23 }, "active replacement preserves region settings")
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
    local _, other, unsupported = mobilityLogin(1953, { cooldownDuration = 15 }, { classToken = "WARRIOR" })
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
    equal(controls.mobilityPreview:IsEnabled(), false, "Mobility Preview control disabled in combat")
    data.charges = 1
    syncEvent(state, "SPELL_UPDATE_CHARGES")
    equal(nativeText(addon), "", "combat charge recovery hides normally")
    syncEvent(state, "PLAYER_REGEN_ENABLED")
    equal(addon.previewState.mode, "off", "leaving combat never silently restarts samples")
    truthy(panel.titleAnimation:IsPlaying(), "existing title resumes when eligible")
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
    equal(addon.db.schemaVersion, 4, "additive schema upgrade")
    for id, record in pairs(old.reminders) do same(addon.db.reminders[id], record, "existing region remains " .. id) end
    same(addon.db.options.position, old.options.position, "window position remains saved")
    same(addon.db.position, old.position, "global position remains saved")
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
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 38 }, scale = 1.5 })
    same(live.text.font, { "Fonts\\FRIZQT__.ttf", 38, "THICKOUTLINE" }, "live font changes apply immediately")
    reminderAnchor(live, entry, addon, env)
    equal(state.liveMeasurements, 0, "live text geometry is never measured")
end)

test("Mobility Options edits apply on Enter and expose working preview and copyable diagnostics", function()
    local _, addon, state = mobilityLogin(1953, { cooldownStart = 100, cooldownDuration = 15 })
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("mobility")
    truthy(panel.pages.mobility:IsShown(), "Mobility is a working category")
    equal(controls.mobilityEnabled:GetChecked(), true, "Mobility defaults enabled")
    truthy(panel.mobilitySpell:GetText():find("Blink", 1, true), "detected current spell displayed read-only")
    local id = addon:GetMobilityEntry().id
    typeText(controls.mobilityX, "45.5")
    typeText(controls.mobilityY, "-72")
    equal(addon.db.reminders[id].position.x, 0, "position waits for Enter")
    controls.mobilityX:GetScript("OnEnterPressed")(controls.mobilityX)
    same(addon.db.reminders[id].position, { x = 45.5, y = -72 }, "Enter commits both coordinates atomically")
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
    local id = addon:GetMobilityEntry().id
    typeText(controls.mobilityX, "47")
    typeText(controls.mobilityY, "-65")
    syncEvent(state, "SPELL_UPDATE_COOLDOWN")
    equal(controls.mobilityX:GetText(), "47", "event refresh preserves pending X")
    equal(controls.mobilityY:GetText(), "-65", "event refresh preserves pending Y")
    controls.mobilityDiagnostics:Click()
    local dialog = panel.diagnosticsFrame
    equal(controls.mobilityX:GetText(), "47", "copy dialog preserves unsaved X")
    equal(controls.mobilityY:GetText(), "-65", "copy dialog preserves unsaved Y")
    local snapshot = dialog.editBox:GetText()
    typeText(dialog.editBox, "overwrite")
    equal(dialog.editBox:GetText(), snapshot, "diagnostic snapshot permits selection but refuses user editing")
    dialog.close:Click()
    controls.mobilityY:GetScript("OnEnterPressed")(controls.mobilityY)
    same(addon.db.reminders[id].position, { x = 47, y = -65 }, "Enter after copying commits original pending pair")
    typeText(controls.mobilityX, "invalid")
    typeText(controls.mobilityY, "19")
    controls.mobilityX:GetScript("OnEnterPressed")(controls.mobilityX)
    same(addon.db.reminders[id].position, { x = 47, y = -65 }, "invalid X does not partially commit Y")
    truthy(panel.feedback:GetText() ~= "", "invalid pair has visible feedback")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.mobilityX:GetText()), 47, "closing discards invalid pending X")
    equal(tonumber(controls.mobilityY:GetText()), -65, "closing discards pending Y")
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
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 30 }, scale = 1.2 })
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
    equal(panel.controls.previewAll:IsEnabled(), false, "Options still updates its combat restriction")
    state:fire("PLAYER_REGEN_ENABLED")
    truthy(panel.titleAnimation:IsPlaying(), "branding still gets combat-end callback")
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
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 33 }, scale = 1.4 })
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
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 36 }, scale = 1.25 })
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

test("Options exposes no custom reminder colors and class style adds no polling or global mutations", function()
    local _, addon = login()
    local _, controls = options(addon)
    for key in pairs(controls) do
        truthy(not key:lower():find("color", 1, true), "no custom color controls: " .. key)
    end
    for _, path in ipairs({ "UI/Options.lua", "Config/Defaults.lua", "UI/ReminderStyle.lua" }) do
        local file = assert(io.open(root .. "/" .. path, "r"))
        local source = file:read("*a"); file:close()
        for _, forbidden in ipairs({ "ColorPickerFrame", "CUSTOM_CLASS_COLORS", "ElvUI", "Ellesmere", '"OnUpdate"', "NewTicker" }) do
            truthy(not source:find(forbidden, 1, true), path .. " does not introduce " .. forbidden)
        end
    end
end)


test("schema-4 migration copies valid legacy appearance once and breaks every mutable alias", function()
    local shared = { font = { size = 41 }, shadow = { enabled = false }, scale = 1.7 }
    local saved = { schemaVersion = 3, font = { face = "Fonts\\MORPHEUS.TTF", size = 30, outline = "THICKOUTLINE" },
        shadow = { enabled = false }, scale = 1.25, position = { x = 79, y = -51 },
        options = { animatedTitle = false, position = { x = 43, y = -18 } }, mobility = { enabled = false },
        reminders = { mage_fire_shimmer = { position = { x = 15, y = 27 } } },
        styles = { mobility_blink = { font = { size = 35 } },
            mage_fire_hot_streak_left = shared, mage_fire_hot_streak_right = shared } }
    local _, addon = login(saved)
    equal(addon.db, saved, "root SavedVariables identity retained")
    equal(addon.db.schemaVersion, 4, "migration version recorded")
    same(addon.db.position, { x = 79, y = -51 }, "global coordinates retained")
    same(addon.db.reminders.mage_fire_shimmer.position, { x = 15, y = 27 }, "existing position ID retained")
    same(addon.db.options.position, { x = 43, y = -18 }, "window coordinates retained")
    equal(addon.db.options.animatedTitle, false, "animation preference retained")
    equal(addon.db.mobility.enabled, false, "module preference retained")
    for _, entry in ipairs(addon.appearanceEntries) do
        local style = addon.db.styles[entry.key]
        equal(style.font.face, "Fonts\\MORPHEUS.TTF", "legacy face fills missing field")
        equal(style.font.outline, "THICKOUTLINE", "legacy outline fills missing field")
        for _, other in ipairs(addon.appearanceEntries) do
            if other.key ~= entry.key then
                local rhs = addon.db.styles[other.key]
                truthy(style ~= rhs and style.font ~= rhs.font and style.shadow ~= rhs.shadow,
                    "each style and mutable child table is independently owned")
            end
        end
        truthy(style.font ~= addon.db.font and style.shadow ~= addon.db.shadow, "legacy fields are detached")
    end
    equal(addon.db.styles.mobility_blink.font.size, 35, "valid preexisting independent value wins")
    equal(addon.db.styles.mobility_blink.scale, 1.25, "missing independent scale inherits once")
    equal(addon.db.styles.mage_fire_hot_streak_left.font.size, 41, "existing region size wins")
    equal(addon.db.styles.mobility_shimmer.font.size, 30, "legacy size copied to missing skill")
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 48 } })
    local after = copy(addon.db)
    after.font.size, after.scale = 66, 2.5
    after.styles.mage_arcane_clearcasting_left = nil
    local _, reloaded = login(after)
    equal(reloaded.db.styles.mobility_shimmer.font.size, 48, "reload never reapplies obsolete global appearance")
    same(reloaded.db.styles.mage_arcane_clearcasting_left, reloaded.factoryReminderStyle, "missing schema-4 entry gets factory values")
    equal(reloaded.db.styles.mobility_blink.font.size, 35, "new entry never modifies another style")
end)

test("entry style validation is atomic canonicalizes fonts and resets only selected appearance", function()
    local _, addon = login({ reminders = { mage_fire_shimmer = { position = { x = 23, y = -34 } } } })
    local before = copy(addon.db)
    for _, patch in ipairs({ { font = { size = 7 } }, { font = { size = 99 } },
        { font = { face = "bad.ttf" } }, { font = { outline = "bad" } },
        { scale = 0/0 }, { scale = 3.01 }, { shadow = { enabled = 1 } },
        { font = { size = 30 }, color = { 1, 0, 0 } }, { position = { x = 9 } } }) do
        equal(addon:UpdateReminderStyle("mobility_blink", patch), false, "invalid style rejected")
        same(addon.db, before, "invalid style leaves every setting unchanged")
    end
    equal(addon:UpdateReminderStyle("invented_entry", { scale = 2 }), false, "unknown entry rejected")
    truthy(addon:UpdateReminderStyle("mobility_blink", { font = { face = "fonts\\morpheus.ttf", size = 42 }, scale = 2 }), "valid style accepted")
    equal(addon.db.styles.mobility_blink.font.face, "Fonts\\MORPHEUS.TTF", "face canonicalized per entry")
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 37 } })
    local others = copy(addon.db.styles)
    addon:ResetReminderStyle("mobility_blink")
    same(addon.db.styles.mobility_blink, addon.factoryReminderStyle, "selected style reset to factory")
    for key, style in pairs(others) do
        if key ~= "mobility_blink" then same(addon.db.styles[key], style, "current reset leaves other entries intact") end
    end
    same(addon.db.reminders, before.reminders, "current style reset preserves all coordinates")
end)

test("Appearance selection discards drafts and each Proc region supports explicitly labeled Preview only", function()
    local _, addon, state = login()
    local panel, controls = options(addon)
    addon:OpenAppearance("mobility", "mobility_blink")
    enter(controls.appearanceFontSize.editBox, "29")
    typeText(controls.appearanceFontSize.editBox, "67")
    typeText(controls.appearanceScale.editBox, "2.7")
    choose(controls.appearanceEntry, "mobility_shimmer")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 24, "new entry loads its own saved size")
    equal(tonumber(controls.appearanceScale.editBox:GetText()), 1, "new entry has no previous draft scale")
    enter(controls.appearanceFontSize.editBox, "33")
    choose(controls.appearanceEntry, "mobility_blink")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 29, "returning entry discards former unsubmitted text")
    controls.appearanceReset:Click()
    equal(addon.db.styles.mobility_blink.font.size, 24, "UI resets only selected skill")
    equal(addon.db.styles.mobility_shimmer.font.size, 33, "other skill survives reset")
    addon:SelectOptionsCategory("proc")
    choose(controls.procEntry, "mage_fire_hot_streak_left")
    controls.procAppearance:Click()
    equal(panel.selectedAppearanceKey, "mage_fire_hot_streak_left", "Proc shortcut selects specific region")
    controls.appearanceFontSize:SetValue(45)
    equal(addon.db.styles.mage_fire_hot_streak_left.font.size, 45, "Proc size changes immediately")
    equal(addon.db.styles.mage_fire_hot_streak_right.font.size, 24, "same Proc other region remains independent")
    controls.appearancePreview:Click()
    equal(addon.previewState.entryId, "mage_fire_hot_streak_left", "Appearance opens only selected region sample")
    equal(addon.previewFrames.mage_fire_hot_streak_left.text.font[2], 45, "sample uses saved region style")
    typeText(controls.appearanceFontSize.editBox, "66")
    state.specID = 64
    syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 24, "spec switch discards draft when changing eligible entry")
    truthy(panel.selectedAppearanceKey:find("mage_frost_", 1, true), "spec switch selects only defined current-spec Proc entries")
    for _, category in ipairs(panel.categories) do
        equal(category.themeSelection:IsShown(), category.key == "proc", "appearance retains parent-category highlight after palette change")
    end
    state.specID = 63
    syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    addon:OpenAppearance("proc", "mage_fire_hot_streak_left")
    equal(tonumber(controls.appearanceFontSize.editBox:GetText()), 45, "returning to original specialization restores committed size")
    local sourceFile = assert(io.open(root .. "/UI/Options.lua", "r"))
    local source = sourceFile:read("*a"); sourceFile:close()
    truthy(source:find("Preview only", 1, true), "Proc limitation is explicitly labeled")
    for _, key in ipairs({ "font", "fontSize", "outline", "shadow", "scale" }) do
        equal(controls[key], nil, "old global appearance control removed")
    end
end)

test("actual Blink and Shimmer use distinct appearance without changing established position identities", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 97, chargeDuration = 20 }
    local env, addon, state = mobilityLogin(1953, data)
    addon:UpdateReminderStyle("mobility_blink", { font = { size = 27 }, scale = 1.2 })
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 43 }, scale = 1.8 })
    local id, blink = addon:GetMobilityEntry().id, currentLive(addon)
    addon:UpdateSettings({ reminders = { [id] = { position = { x = 52, y = -29 } } } })
    equal(blink.text.font[2], 27, "actual Blink gets Blink style")
    local savedPositionID = addon:GetMobilityEntry().id
    state.mobility.known[212653], state.mobility.override = true, 212653
    state.mobility.spells[212653] = data
    syncEvent(state, "SPELLS_CHANGED")
    equal(addon:GetMobilityEntry().id, savedPositionID, "learning replacement never renames position setting")
    equal(currentLive(addon).text.font[2], 43, "actual Shimmer gets distinct Shimmer style")
    equal(currentLive(addon):GetScale(), 1.8, "actual spell controls scale exactly once")
    reminderAnchor(currentLive(addon), addon:GetMobilityEntry(), addon, env)
    state.specID = 62
    syncEvent(state, "PLAYER_SPECIALIZATION_CHANGED", "player")
    equal(currentLive(addon).text.font[2], 43, "specialization switch retains actual skill style")
    equal(addon.db.reminders[savedPositionID].position.x, 52, "old specialization coordinates survive")
    local _, reloaded = mobilityLogin(212653, data, { specID = 62 }, copy(addon.db))
    equal(currentLive(reloaded).text.font[2], 43, "skill style survives reload and spec change")
end)

test("style edits preserve opaque live alpha and native countdown binding without any spell query", function()
    local data = { charges = 0, maxCharges = 2, chargeStart = 94, chargeDuration = 20,
        secretCharges = true, secretDuration = true, cooldownStart = 100, cooldownDuration = 20 }
    local env, addon, state = mobilityLogin(212653, data, { inCombat = true })
    local frame = currentLive(addon)
    local binding, originalAlpha, originalDuration = frame.durationBinding, frame.alpha, frame.durationBinding.duration
    local durationWrites, alphaWrites, reads = binding.durationWrites, frame.alphaWrites, copy(state.spellReads)
    local timer = nativeText(addon)
    truthy(addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 44, outline = "THICKOUTLINE" }, scale = 1.75, shadow = { enabled = false } }), "live style accepted")
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

test("explicit skill appearance Preview shares that skill style without altering learned live identity", function()
    local _, addon = mobilityLogin(1953, { charges = 0, maxCharges = 1, chargeStart = 100, chargeDuration = 20 })
    options(addon)
    addon:UpdateReminderStyle("mobility_blink", { font = { size = 32 }, scale = 1.25 })
    addon:UpdateReminderStyle("mobility_shimmer", { font = { size = 47 }, scale = 1.7 })
    truthy(addon:StartAppearancePreview("mobility_blink"), "actual skill sample starts")
    local id = addon:GetMobilityEntry().id
    local preview = addon.previewFrames[id]
    same(preview.text.font, currentLive(addon).text.font, "same entry preview/live typography matches")
    equal(preview:GetScale(), currentLive(addon):GetScale(), "same entry preview/live scale matches")
    truthy(addon:StartAppearancePreview("mobility_shimmer"), "alternative skill style is previewable without learning it")
    equal(preview.text.font[2], 47, "alternate sample selects alternate style")
    equal(addon:GetMobilityStatus().spellID, 1953, "preview does not manufacture learned Shimmer")
    addon:StopPreview()
    equal(currentLive(addon).text.font[2], 32, "stopping alternate sample restores actual Blink appearance")
    equal(nativeText(addon), "No Blink\n20.0", "real Blink timer retained")
end)

test("updating one displayed entry does not touch any other cached reminder font", function()
    local _, addon = mobilityLogin(212653, { charges = 0, maxCharges = 2, chargeStart = 100, chargeDuration = 20 })
    options(addon)
    addon:SetPreview("all")
    local snapshots = {}
    for _, pool in pairs(addon.reminderFrames) do
        for _, frame in pairs(pool) do snapshots[frame] = frame.text.fontWrites end
    end
    addon:UpdateReminderStyle("mage_fire_hot_streak_left", { font = { size = 39 } })
    for frame, writes in pairs(snapshots) do
        if frame.styleKey == "mage_fire_hot_streak_left" then
            truthy(frame.text.fontWrites > writes, "selected preview updates")
        else
            equal(frame.text.fontWrites, writes, "other live/preview entries receive no font writes")
        end
    end
end)

test("Alliance Arcane automatically uses the specified red-to-purple Options gradient only", function()
    local _, addon, state = login(nil, false, { specID = 62, faction = "Alliance" })
    equal(state.factionReads, 0, "hidden Options performs no decorative identity reads")
    local before = copy(addon.db)
    local panel, controls = options(addon)
    local info = addon:GetAutomaticThemeInfo()
    equal(info.mode, "Automatic", "theme mode is automatic")
    equal(info.faction, "Alliance", "faction detected")
    equal(info.specialization, "Arcane", "specialization detected")
    equal(info.themeKey, "alliance_arcane", "specified combination selected")
    same(panel.theme.header.gradient.first, { 0.48, 0.07, 0.13, 0.45 }, "header starts at requested red")
    same(panel.theme.header.gradient.last, { 0.36, 0.13, 0.58, 0.45 }, "header ends in Arcane purple")
    same(panel.brandingHeader.sweep.vertexColor, { 0.72, 0.46, 0.98 }, "brand highlight uses central accent")
    equal(panel.brandingHeader.wordmark.vertexColor, nil, "blue/gold wordmark receives no tint")
    same(addon.db, before, "automatic theme never writes saved reminder settings")
    for key in pairs(controls) do
        truthy(not key:lower():find("color", 1, true), "no custom color controls")
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
    for _, item in ipairs({ { "Neutral", "MAGE", 62, "mage" }, { "Unknown", "MAGE", 62, "mage" },
        { "Alliance", "MAGE", false, "mage" }, { "Horde", "MAGE", 999, "mage" },
        { "Alliance", "WARRIOR", 71, "neutral" }, { "Alliance", "UNKNOWN", false, "neutral" },
        { secret("Alliance"), "MAGE", 62, "mage" }, { "Alliance", "MAGE", secret(62), "mage" } }) do
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
        { inCombat = true })
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
    equal(panel.titleAnimation:IsPlaying(), false, "automatic theme respects combat-stopped brand animation")
    state:advance(1)
    equal(nativeText(addon), "No Shimmer\n12.0", "native countdown advances after theme changes")
end)

test("live runtime sources contain no polling cast-count inference or timer text readback", function()
    for _, path in ipairs({ "Modules/Mobility/Runtime.lua", "Modules/Mobility/SpellState.lua" }) do
        local file = assert(io.open(root .. "/" .. path, "r"))
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

print("All " .. total .. " offline smoke tests passed.")
