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
        GetHeight = function() return 1080 end, GetEffectiveScale = function() return 1 end }
    function env.UIParent:GetCenter() return self:GetWidth() / 2, self:GetHeight() / 2 end
    env.STANDARD_TEXT_FONT = client.standardFont or "Fonts\\FRIZQT__.ttf"
    env.GameFontNormal = { template = "GameFontNormal" }
    env.GameFontHighlight = { template = "GameFontHighlight" }
    env.GameFontHighlightSmall = { template = "GameFontHighlightSmall" }
    local state = { frames = {}, errors = {}, messages = {}, loggedIn = loggedIn or false,
        fontWrites = 0, textWrites = 0, timers = 0, animations = {}, textures = {}, masks = {}, fontStrings = {},
        specID = client.specID or 63, classToken = client.classToken or "MAGE", realReads = 0,
        inCombat = client.inCombat or false }
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
    env.UnitClass = function() return state.classToken, state.classToken, state.classToken == "MAGE" and 8 or 1 end
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
    env.C_Timer = { After = function() error("Options must not schedule polling timers") end,
        NewTicker = function() error("Options must not schedule polling tickers") end,
        NewTimer = function() error("Options must not schedule polling timers") end }

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
    function object:GetAlpha() return self.alpha == nil and 1 or self.alpha end
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
    function object:GetTexture() return self.texture end
    function object:SetBlendMode(value) self.blendMode = value end
    function object:SetRotation(value) self.rotation = value end
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
    equal(addon.db.font.face, "Fonts\\FRIZQT__.ttf", "saved font face")
    equal(addon.db.font.size, size, "saved font size")
    equal(addon.db.font.outline, outline, "saved font outline")
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
    equal(addon.db.schemaVersion, 2, "schema version migrated")
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
    equal(addon.db.scale, 1.25, "saved scale")
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
        equal(addon.db.font.size, 24, "invalid root reset")
    end
    local env, addon = login({ schemaVersion = "invalid", enabled = "yes",
        position = { x = math.huge, y = 0 / 0 },
        font = { face = false, size = -10, outline = "INVALID" },
        scale = math.huge, shadow = { enabled = "yes" }, other = "preserve me" })
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
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
    savedPosition(addon3, env3, 0, 0)
    savedFont(addon3, 24, "OUTLINE")
    equal(addon3.db.scale, 1, "finite out-of-range scale")
end)

test("slash commands apply position, typography, visibility and reset", function()
    local env, addon, state = login(nil)
    local command = env.SlashCmdList.CARGOUI
    command("help")
    command("status")
    command("position 35 -60")
    savedPosition(addon, env, 35, -60)
    equal(addon.db.position.x, 35, "saved x")
    equal(addon.db.position.y, -60, "saved y")
    command("fontsize 30")
    savedFont(addon, 30, "OUTLINE")
    command("outline none")
    savedFont(addon, 30, "")
    command("outline thickoutline")
    savedFont(addon, 30, "THICKOUTLINE")
    command("outline outline")
    savedFont(addon, 30, "OUTLINE")
    command("scale 1.2")
    equal(addon.db.scale, 1.2, "saved scale")
    savedPosition(addon, env, 35, -60)
    command("shadow off")
    equal(addon.db.shadow.enabled, false, "disabled shadow")
    command("hide")
    equal(addon.db.enabled, false, "saved hidden state")
    command("show")
    equal(addon.db.enabled, true, "saved shown state")
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
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
    equal(addon.db.scale, 1, "reset scale")
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
    truthy(addon:UpdateSettings({ position = { x = 40 }, font = { size = 28 }, shadow = { enabled = false } }),
        "valid partial patch accepted")
    equal(addon.db, db, "DB reference stable")
    equal(env.CarGOUIDB, db, "SavedVariables references live DB")
    equal(addon.db.position, position, "position reference stable")
    equal(addon.db.font, fontSettings, "font reference stable")
    equal(addon.db.shadow, shadow, "shadow reference stable")
    savedPosition(addon, env, 40, 0)
    savedFont(addon, 28, "OUTLINE")
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
    changed(function() enter(controls.y, "-85") end, "position Enter")
    savedPosition(addon, env, 165, -85)
    changed(function() controls.enabled:Click() end, "visibility")
    equal(addon.db.enabled, false, "checkbox hides actual display")
    controls.enabled:Click()
    changed(function() controls.scale:SetValue(1.35) end, "scale slider")
    equal(addon.db.scale, 1.35, "slider saves scale")
    savedPosition(addon, env, 165, -85)
    changed(function() enter(controls.scale.editBox, "1.6") end, "scale numeric field")
    equal(addon.db.scale, 1.6, "numeric scale saved")
    addon:SelectOptionsCategory("typography")
    changed(function() controls.fontSize:SetValue(36) end, "font size slider")
    savedFont(addon, 36, "OUTLINE")
    changed(function() enter(controls.fontSize.editBox, "32") end, "font size numeric field")
    savedFont(addon, 32, "OUTLINE")
    changed(function() choose(controls.outline, "THICKOUTLINE") end, "outline dropdown")
    savedFont(addon, 32, "THICKOUTLINE")
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

test("dropdown lifecycle and hidden refresh remain idle", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("typography")
    controls.outline:Click()
    truthy(controls.outline.menu:IsShown(), "dropdown open")
    addon:SelectOptionsCategory("general")
    equal(controls.outline.menu:IsShown(), false, "category change dismisses dropdown")
    addon:SelectOptionsCategory("typography")
    controls.outline:Click()
    panel:Hide()
    equal(controls.outline.menu:IsShown(), false, "closing window dismisses menu")
    local fontWrites, textWrites = state.fontWrites, state.textWrites
    for _ = 1, 5 do addon:RefreshOptions() end
    equal(state.fontWrites, fontWrites, "hidden refresh does not redraw")
    equal(state.textWrites, textWrites, "hidden refresh does not update control text")
    local savedScale = addon.db.scale
    controls.scale:SetValue(2.25)
    equal(addon.db.scale, savedScale, "hidden slider cannot update settings")
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
    savedPosition(addon, env, 0, 0)
    savedFont(addon, 24, "OUTLINE")
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

test("sliders round safely while numeric inputs retain precision and require Enter", function()
    local _, addon, state = login(nil)
    local panel, controls = options(addon)
    equal(controls.applyPosition, nil, "no XY Apply button")
    equal(controls.scale.applyButton, nil, "no scale Apply button")
    equal(controls.fontSize.applyButton, nil, "no font-size Apply button")
    for _, frame in ipairs(state.frames) do
        if frame.kind == "Button" then
            truthy(frame:GetText() ~= "Apply", "Options contains no normal-setting Apply buttons")
        end
    end
    for _, value in ipairs({ 0.5, 0.5000001, 1.049999999, 2.999999999, 3 }) do
        controls.scale:SetValue(value)
        truthy(addon:IsNumberInRange(addon.db.scale, addon.limits.scale), "rounded scale stays valid")
        truthy(math.abs(addon.db.scale * 20 - math.floor(addon.db.scale * 20 + 0.5)) < 0.00001,
            "slider produces 0.05 increments")
    end
    enter(controls.scale.editBox, "1.2375")
    equal(addon.db.scale, 1.2375, "typed scale keeps precision")
    enter(controls.fontSize.editBox, "31.5")
    equal(addon.db.font.size, 31.5, "typed font size keeps precision")
    typeText(controls.scale.editBox, "2.8")
    typeText(controls.fontSize.editBox, "70")
    controls.scale.editBox:SetFocus()
    controls.scale.editBox:ClearFocus()
    controls.fontSize.editBox:SetFocus()
    controls.fontSize.editBox:ClearFocus()
    equal(addon.db.scale, 1.2375, "unconfirmed scale stays pending")
    equal(addon.db.font.size, 31.5, "unconfirmed font stays pending")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.scale.editBox:GetText()), 1.2375, "closing discards pending scale")
    equal(tonumber(controls.fontSize.editBox:GetText()), 31.5, "closing discards pending font size")
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
            equal(addon.db.font.size, 32, "saved appearance survives reload")
        end
        env.SlashCmdList.CARGOUI("")
        local panel, controls = addon.optionsFrame, addon.optionsFrame.controls
        local categories = {}
        for _, category in ipairs(panel.categories) do categories[category.key] = category end
        equal(categories.general:GetText(), "> General", "active category is English")
        equal(categories.typography:GetText(), "Font & appearance", "appearance category is English")
        equal(controls.close:GetText(), "Close", "close button is English")
        truthy(panel.feedback:GetText():find("Enter", 1, true), "opening guidance teaches Enter")
        truthy(not panel.feedback:GetText():find("Apply", 1, true), "obsolete Apply instruction gone")
        enter(controls.x, "invalid")
        truthy(panel.feedback:GetText():find("X", 1, true), "coordinate error is readable")
        enter(controls.x, "37")
        equal(panel.feedback:GetText(), "Settings applied.", "success feedback is English")
        addon:SelectOptionsCategory("typography")
        equal(controls.outline.choices[1]:GetText(), "None", "dropdown choice is English")
        enter(controls.fontSize.editBox, "32")
        controls.reset:Click()
        equal(controls.reset:GetText(), "Confirm reset", "reset confirmation button is English")
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
    local env, addon, state = login(nil)
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

test("external preview reacts to shared settings and selected-entry positions without moving Proc centers", function()
    local env, addon = login(nil)
    local panel, controls = options(addon)
    addon:SelectOptionsCategory("preview")
    local entries = addon:GetPreviewEntries()
    local selected
    for _, entry in ipairs(entries) do if entry.kind == "proc" then selected = entry; break end end
    truthy(selected, "spec defines a Proc preview")
    choose(controls.previewEntry, selected.id)
    controls.previewAll:Click()
    typeText(controls.entryX, "34")
    typeText(controls.entryY, "invalid")
    local prior = copy(addon.db)
    enter(controls.entryX, "34")
    same(addon.db, prior, "invalid entry offset pair is atomic")
    enter(controls.entryY, "-17")
    equal(addon.db.reminders[selected.id].position.x, 34, "per-entry X saved")
    equal(addon.db.reminders[selected.id].position.y, -17, "per-entry Y saved")
    for _, entry in ipairs(entries) do
        if entry.id ~= selected.id then
            equal(addon.db.reminders[entry.id].position.x, 0, "editing one region leaves other X offsets alone")
            equal(addon.db.reminders[entry.id].position.y, 0, "editing one region leaves other Y offsets alone")
        end
    end
    addon:SelectOptionsCategory("general")
    enter(controls.x, "25")
    enter(controls.y, "-50")
    enter(controls.scale.editBox, "1.5")
    addon:SelectOptionsCategory("typography")
    enter(controls.fontSize.editBox, "40")
    choose(controls.outline, "THICKOUTLINE")
    choose(controls.font, "Fonts\\MORPHEUS.TTF")
    controls.shadow:Click()
    equal(countKeys(visiblePreviews(addon)), #entries, "preview stays active while editing appearance")
    for _, entry in ipairs(entries) do
        local frame = addon.previewFrames[entry.id]
        reminderAnchor(frame, entry, addon, env)
        local face, size, outline = frame.text:GetFont()
        equal(face, "Fonts\\MORPHEUS.TTF", "external renderer updates font")
        equal(size, 40, "external renderer updates font size")
        equal(outline, "THICKOUTLINE", "external renderer updates outline")
        equal(frame:GetScale(), 1.5, "external renderer updates scale")
        if entry.kind == "proc" then
            local guide = frame.guidance
            local point, relative, relativePoint, x, y = guide:GetPoint()
            equal(point, "CENTER", "Proc guide anchor")
            equal(relative, env.UIParent, "Proc shape stays in stock UI space")
            equal(relativePoint, "CENTER", "Proc guide relative anchor")
            local factor = guide:GetEffectiveScale() / env.UIParent:GetEffectiveScale()
            truthy(math.abs(factor - 1) < 0.000001, "Proc shape ignores typography scale")
            truthy(math.abs(x * factor - entry.anchor.x) < 0.001, "timer offsets never move stock guide X")
            truthy(math.abs(y * factor - entry.anchor.y) < 0.001, "timer offsets never move stock guide Y")
        end
        local sx, sy = frame.text:GetShadowOffset()
        equal(sx, 0, "external renderer disables shadow X")
        equal(sy, 0, "external renderer disables shadow Y")
    end
    local reloadEnv, reloaded = login(copy(addon.db))
    options(reloaded)
    truthy(reloaded:SetPreview("single", selected.id), "saved region can be previewed after reload")
    equal(reloaded.db.reminders[selected.id].position.x, 34, "per-region X persists after reload")
    equal(reloaded.db.reminders[selected.id].position.y, -17, "per-region Y persists after reload")
    reminderAnchor(reloaded.previewFrames[selected.id], selected, reloaded, reloadEnv)
    addon:SelectOptionsCategory("preview")
    controls.entryReset:Click()
    equal(addon.db.reminders[selected.id].position.x, 0, "entry reset restores default-region X")
    equal(addon.db.reminders[selected.id].position.y, 0, "entry reset restores default-region Y")
    typeText(controls.entryX, "900")
    panel:Hide()
    addon:ToggleOptions()
    equal(tonumber(controls.entryX:GetText()), 0, "closing discards uncommitted entry offset")
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
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        local count = 0
        for _, frame in ipairs(state.frames) do
            if frame:IsEventRegistered(event) then count = count + 1 end
        end
        equal(count, expected, event .. " listener lifetime")
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
    truthy(textures <= 6, "branding stays within decorative texture budget")
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
    addon:UpdateSettings({ font = { size = 72, outline = "THICKOUTLINE" }, scale = 3 })
    addon:SelectOptionsCategory("typography")
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
    local fontWrites, textWrites = state.fontWrites, state.textWrites
    for _, event in ipairs({ "OnLoop", "OnFinished" }) do
        if group:GetScript(event) then group:GetScript(event)(group) end
    end
    state:fire("PLAYER_REGEN_DISABLED")
    state:fire("PLAYER_REGEN_ENABLED")
    equal(panelRefreshes, 0, "animation/combat callbacks never rebuild Options")
    equal(previewRefreshes, 0, "animation/combat callbacks never refresh simulated reminders")
    equal(renders, 0, "animation/combat callbacks never render reminder content")
    equal(state.fontWrites, fontWrites, "branding callbacks never recreate fonts")
    equal(state.textWrites, textWrites, "branding callbacks never rewrite text")
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
    same(header.sweep.vertexColor, { 0.2, 0.6, 0.9 }, "deferred theme accent applies to highlight")
    same(header.accentLine.vertexColor, { 0.2, 0.6, 0.9 }, "deferred accent applies to line")
    for _, color in ipairs({ false, "bad", {}, { 0.1, 0.2 }, { 0.1, 2, 0.3 }, { 0/0, 0.2, 0.3 } }) do
        equal(addon:UpdateBrandingTheme(color), false, "invalid theme accent rejected")
        same(header.sweep.vertexColor, { 0.2, 0.6, 0.9 }, "invalid accent leaves previous color intact")
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

print("All " .. total .. " offline smoke tests passed.")
