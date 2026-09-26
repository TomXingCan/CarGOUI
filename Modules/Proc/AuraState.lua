local _, addon = ...

-- The 12.1 native AuraContainer performs matching, assignment, refresh,
-- consumption and expiry in Blizzard's secure environment. No aura values,
-- native button state or formatted text are read by CarGOUI.
function addon:CanUseNativeAuraSlots()
    if not C_XMLUtil or type(C_XMLUtil.GetTemplateInfo) ~= "function"
        or not C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") then
        return false, "The client does not provide CustomAuraContainerTemplate."
    end
    if not C_DurationUtil or type(C_DurationUtil.CreateDurationTextBinding) ~= "function"
        or not C_StringUtil or type(C_StringUtil.CreateNumericRuleFormatter) ~= "function"
        or type(CreateFont) ~= "function" then
        return false, "The client does not provide native aura duration text support."
    end
    return true
end

local function DurationTemplate(self)
    if self.nativeAuraDurationTemplate then return self.nativeAuraDurationTemplate end
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:AddBreakpoint({ threshold = 0, step = 0.1,
        rounding = Enum.NumericRuleFormatRounding.Up, format = "%.1f" })
    local binding = C_DurationUtil.CreateDurationTextBinding()
    binding:SetTextFormat("{}", {
        { property = Enum.DurationTextBindingProperty.RemainingDuration, formatter = formatter },
    })
    binding:SetTimeModifier(Enum.DurationTimeModifier.RealTime)
    binding:SetUpdateInterval(0.1)
    binding:SetExpiredText("")
    binding:SetZeroDurationText("")
    binding:SetEnabled(false)
    self.nativeAuraDurationTemplate = binding
    return binding
end

local Handle = {}

function Handle:SetEnabled(enabled)
    enabled = enabled == true
    if self.enabled == enabled then return end
    self.enabled = enabled
    self.container:SetAlpha(enabled and 1 or 0)
    self.container:SetEnabled(enabled)
    -- Keep the public container and its ancestor wrapper shown. SetEnabled(false)
    -- queues one native dirty pass which clears assignments and disables copied
    -- duration bindings. Hiding it before that pass would suspend the clear.
    -- The disabled container has no active UNIT_AURA listener or recurring scan.
    self.container:Show()
end

-- parent is an addon-owned public wrapper. Position, scale and optional overlay
-- gating belong to that wrapper. Gate it using alpha rather than Hide, including
-- on module shutdown, so the native one-shot clear can finish.
-- textOnly is nil for a numeric timer, or a static public string ("Free move").
-- Update handle.font with the existing reminder style function. The Font object
-- is ours; the access-restricted native button/FontString are never touched again.
function addon:CreateNativeAuraSlot(parent, key, auraID, textOnly)
    local supported, reason = self:CanUseNativeAuraSlots()
    if not supported then return nil, reason end
    self.nativeAuraSlots = self.nativeAuraSlots or {}
    local existing = self.nativeAuraSlots[key]
    if existing then
        if existing.auraID ~= auraID or existing.textOnly ~= textOnly then
            return nil, "A native aura slot key cannot be reassigned to another effect."
        end
        return existing
    end
    if type(auraID) ~= "number" or auraID <= 0 or auraID ~= math.floor(auraID)
        or type(key) ~= "string" or key == "" then
        return nil, "A native aura slot requires a verified public key and aura ID."
    end

    self.nativeAuraFontCount = (self.nativeAuraFontCount or 0) + 1
    local font = CreateFont("CarGOUINativeAuraFont" .. self.nativeAuraFontCount)
    font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    self:ApplyReminderColor(font)

    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetAllPoints(parent)
    container:SetEnabled(false)
    container:SetAlpha(0)
    container:SetUnit("player")
    container:Show()

    local binding = not textOnly and DurationTemplate(self) or nil
    container:AddAuraSlot(key, "HELPFUL", {
        candidateFilters = { includeSpellIDs = { [auraID] = true } },
        initializeFrame = function(button)
            -- Initialization is the sanctioned public callback before Blizzard
            -- applies DenyTaintedAccessWhenAurasAreSecret to this native button.
            button:SetAllPoints(container)
            button:EnableMouse(false)
            local text = button:CreateFontString(nil, "OVERLAY")
            text:SetAllPoints(button)
            text:SetFontObject(font)
            text:SetJustifyH("CENTER")
            text:SetJustifyV("MIDDLE")
            text:SetWordWrap(false)
            if textOnly then
                text:SetText(textOnly)
            else
                -- Blizzard copies this template into its own persistent binding.
                -- The native button supplies its stable DurationObject, updated
                -- from secure aura metadata; addon Lua never reads that object.
                button:SetDurationText(text, { binding = binding })
            end
        end,
    })

    local handle = setmetatable({ container = container, font = font,
        key = key, auraID = auraID, textOnly = textOnly, enabled = false }, { __index = Handle })
    self.nativeAuraSlots[key] = handle
    return handle
end
