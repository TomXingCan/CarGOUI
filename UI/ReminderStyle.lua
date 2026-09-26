local _, addon = ...

local fallback = { r = 1, g = 1, b = 1 }

local function IsPublic(value)
    return not issecretvalue or not issecretvalue(value)
end

local function IsColorComponent(value)
    return IsPublic(value) and type(value) == "number"
        and value == value and value >= 0 and value <= 1
end

local function ResolveClassColor(self, refresh)
    local classToken
    if UnitClass then
        local _, token = UnitClass("player")
        classToken = token
    end
    if not IsPublic(classToken) or type(classToken) ~= "string" or classToken == "" then
        self.reminderClassColor = nil
        return fallback, false
    end

    local cached = self.reminderClassColor
    if not refresh and cached and cached.classToken == classToken then
        return cached, true
    end

    -- The cache belongs to this session, never to account-wide SavedVariables.
    -- An early unavailable API/color is retried on the next styling request.
    self.reminderClassColor = nil
    local color = C_ClassColor and C_ClassColor.GetClassColor
        and C_ClassColor.GetClassColor(classToken)
    if IsPublic(color) and (type(color) == "table" or type(color) == "userdata")
        and type(color.GetRGB) == "function" then
        local r, g, b = color:GetRGB()
        if IsColorComponent(r) and IsColorComponent(g) and IsColorComponent(b) then
            cached = { classToken = classToken, r = r, g = g, b = b }
            self.reminderClassColor = cached
            return cached, true
        end
    end
    return fallback, false
end

-- Name and native duration share one FontString. SetTextColor changes its style
-- without reading, concatenating or replacing native-bound timer text.
function addon:ApplyReminderColor(text)
    local color, available = ResolveClassColor(self, false)
    text:SetTextColor(color.r, color.g, color.b, 1)
    return available
end

-- Login/world-entry refresh also repairs already-created and hidden pool frames.
-- TEST guidance, Options labels and the brand title are outside this pool style.
function addon:RefreshReminderClassColor()
    local color, available = ResolveClassColor(self, true)
    for _, pool in pairs(self.reminderFrames or {}) do
        for _, frame in pairs(pool) do
            if frame.text then frame.text:SetTextColor(color.r, color.g, color.b, 1) end
        end
    end
    return available
end
