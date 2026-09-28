local _, addon = ...

-- Temporary, memory-only research. No evaluation, configuration or saved state.
local capture = {}
addon.ClassToolsRawCapture = capture
local CAP = 2000
local RESTRICTED, UNAVAILABLE = "RESTRICTED", "UNAVAILABLE"
local modes = { arcane = true, combustion = true, altertime = true }
local events = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_AURA", "COMBAT_LOG_EVENT_UNFILTERED",
}
local healthEvents = { "UNIT_HEALTH", "UNIT_MAXHEALTH" }
local columns = { "t", "seq", "event", "unit", "castGUID", "spellID", "spellName",
    "sourceGUID", "destGUID", "subEvent", "healthPct", "detail", "auraInstanceID",
    "duration", "expirationTime", "applications", "cleuTimestamp",
    "castBarID", "interruptedBy", "channelSpellID", "channelStartTimeMs", "channelEndTimeMs", "channelCastBarID" }
local buffer, subscriptions = {}, {}
local enabled, mode, truncated = false, nil, false
local clock, startedAt, lastTime, playerGUID
local dumpFrame, dumpEdit
local OnEvent

-- Never compare, format, index or calculate with a value before these guards.
-- Missing secret introspection fails closed even in older/mock clients.
local function Access(value)
    if type(issecretvalue) ~= "function" then return UNAVAILABLE end
    local ok, secret = pcall(issecretvalue, value)
    if not ok then return UNAVAILABLE end
    if secret then return RESTRICTED end
    if type(canaccessvalue) == "function" then
        local accessible
        ok, accessible = pcall(canaccessvalue, value)
        if not ok then return UNAVAILABLE end
        if not accessible then return RESTRICTED end
    end
end

local function Public(value)
    local reason = Access(value)
    if reason then return reason end
    local kind = type(value)
    if kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return UNAVAILABLE end
        return value
    end
    if kind == "string" or kind == "boolean" then return value end
    return UNAVAILABLE
end

local function TableAccess(value)
    local reason = Access(value)
    if reason then return reason end
    if value == RESTRICTED or value == UNAVAILABLE then return value end
    if type(value) ~= "table" then return UNAVAILABLE end
    if type(issecrettable) ~= "function" or type(canaccesstable) ~= "function" then return UNAVAILABLE end
    local ok, secret = pcall(issecrettable, value)
    if not ok then return UNAVAILABLE end
    if secret then return RESTRICTED end
    local accessible
    ok, accessible = pcall(canaccesstable, value)
    if not ok then return UNAVAILABLE end
    if not accessible then return RESTRICTED end
end

local function Field(value, key)
    local reason = TableAccess(value)
    if reason then return reason end
    local ok, result = pcall(function() return value[key] end)
    if not ok then return UNAVAILABLE end
    return result
end

local function Read(fn, index, ...)
    if type(fn) ~= "function" then return UNAVAILABLE end
    local result = { pcall(fn, ...) }
    if not result[1] then return UNAVAILABLE end
    return Public(result[index + 1])
end

local function IsNumber(value) return type(value) == "number" end
local function IsKnown(value) return value ~= RESTRICTED and value ~= UNAVAILABLE end
local function Escape(value)
    if value == nil then return "" end
    return tostring(value):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\r", "\\r")
        :gsub("\n", "\\n"):gsub("|", "\\x7c")
end

local function Health()
    -- No fallback reconstruction from UnitHealth/UnitHealthMax or native UI.
    -- The native curve converts 0..1 to 0..100; it does not declassify secrets.
    if not CurveConstants or not CurveConstants.ScaleTo100 then return UNAVAILABLE end
    local value = Read(UnitHealthPercent, 1, "player", false, CurveConstants.ScaleTo100)
    if value == RESTRICTED then return value end
    if not IsNumber(value) then return UNAVAILABLE end
    return value
end

local function SpellName(id)
    if not IsNumber(id) then return IsKnown(id) and UNAVAILABLE or id end
    return Read(C_Spell and C_Spell.GetSpellName, 1, id)
end

local function Timestamp()
    local now = Read(clock, 1)
    if not IsNumber(now) or not IsNumber(startedAt) then return UNAVAILABLE end
    lastTime = math.max(lastTime, now - startedAt)
    return lastTime
end

local function Append(row)
    if not enabled then return end
    row.t, row.seq = Timestamp(), #buffer + 1
    buffer[#buffer + 1] = row
    if #buffer >= CAP then
        -- Stop at the bound, retaining the oldest complete prefix for analysis.
        truncated = true
        capture:Stop()
    end
end

local function SessionMetadata()
    local build = { "addonVersion=" .. Escape(Public(addon.version)) }
    local function Put(key, value) build[#build + 1] = key .. "=" .. Escape(value) end
    Put("wowVersion", Read(GetBuildInfo, 1))
    Put("build", Read(GetBuildInfo, 2))
    Put("interface", Read(GetBuildInfo, 4))
    Put("class", Read(UnitClass, 2, "player"))
    local specAPI = C_SpecializationInfo
    local specIndex = Read(specAPI and specAPI.GetSpecialization or GetSpecialization, 1)
    Put("specID", IsNumber(specIndex)
        and Read(specAPI and specAPI.GetSpecializationInfo or GetSpecializationInfo, 1, specIndex) or specIndex)
    Put("haste", Read(GetHaste, 1))
    Put("homeLatencyMS", Read(GetNetStats, 3))
    Put("worldLatencyMS", Read(GetNetStats, 4))
    Put("spellQueueWindowMS", Read(C_CVar and C_CVar.GetCVar or GetCVar, 1, "SpellQueueWindow"))
    Put("researchMode", mode)
    Put("clock", type(GetTimePreciseSec) == "function" and "GetTimePreciseSec" or "GetTime")
    Put("activeTalentConfigID", Read(C_ClassTalents and C_ClassTalents.GetActiveConfigID, 1))
    -- Public item IDs only: no asynchronous item loads, links or talent traversal.
    local equipment = {}
    for slot = 1, 19 do
        equipment[#equipment + 1] = slot .. ":" .. Escape(Read(GetInventoryItemID, 1, "player", slot))
    end
    Put("equipmentItemIDs", table.concat(equipment, ","))
    Put("researchLoggerRevision", "phase1.1")
    Append({ event = "SESSION_START", unit = "player", sourceGUID = playerGUID,
        detail = table.concat(build, ";") })
end

local function CombatLogAccess()
    if not C_CombatLog or type(C_CombatLog.IsCombatLogRestricted) ~= "function" then
        return UNAVAILABLE
    end
    local restricted = Read(C_CombatLog.IsCombatLogRestricted, 1)
    if restricted == true or restricted == RESTRICTED then return RESTRICTED end
    if restricted ~= false then return UNAVAILABLE end
    if type(CombatLogGetCurrentEventInfo) ~= "function" then return UNAVAILABLE end
end

local function Subscribe(event)
    local reason
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then reason = CombatLogAccess() end
    if not reason then
        local ok, result = pcall(addon.RegisterEvent, addon, event, OnEvent)
        if not ok or result == false then
            reason = UNAVAILABLE
            -- Also clean up a router implementation that partially subscribed.
            addon:UnregisterEvent(event, OnEvent)
        end
    end
    subscriptions[event] = reason or "REGISTERED"
    Append({ event = "CAPABILITY", detail = event .. "=" .. subscriptions[event] })
end

local function AuraRow(action, aura, id, hp)
    local reason = TableAccess(aura)
    local row = { event = "UNIT_AURA", unit = "player", detail = action,
        healthPct = hp, auraInstanceID = id }
    if reason then
        row.detail = action .. ":" .. reason
        row.spellID, row.spellName = reason, reason
        row.duration, row.expirationTime, row.applications = reason, reason, reason
    else
        row.auraInstanceID = Public(Field(aura, "auraInstanceID"))
        row.spellID, row.spellName = Public(Field(aura, "spellId")), Public(Field(aura, "name"))
        row.duration = Public(Field(aura, "duration"))
        row.expirationTime = Public(Field(aura, "expirationTime"))
        row.applications = Public(Field(aura, "applications"))
        local sourceUnit = Public(Field(aura, "sourceUnit"))
        row.sourceGUID = IsKnown(sourceUnit) and type(sourceUnit) == "string"
            and Read(UnitGUID, 1, sourceUnit) or sourceUnit
    end
    row.destGUID = playerGUID
    Append(row)
end

local function AuraList(update, key, action, hp)
    if not enabled then return end
    local list = Field(update, key)
    local access = Access(list)
    if not access and list == nil then return end
    local reason = TableAccess(list)
    if reason then
        Append({ event = "UNIT_AURA", unit = "player", detail = action .. ":" .. reason, healthPct = hp })
        return
    end
    local ok, count = pcall(function() return #list end)
    if not ok then
        Append({ event = "UNIT_AURA", unit = "player", detail = action .. ":" .. UNAVAILABLE, healthPct = hp })
        return
    end
    -- Event payload traversal is bounded by the session cap, never polled.
    for i = 1, count do
        if not enabled then break end
        local value = Field(list, i)
        if action == "added" then
            AuraRow(action, value, nil, hp)
        else
            local id = Public(value)
            if action == "removed" then
                Append({ event = "UNIT_AURA", unit = "player", detail = action,
                    auraInstanceID = id, healthPct = hp, destGUID = playerGUID })
            else
                local aura = IsKnown(id) and UNAVAILABLE or id
                if IsNumber(id) and C_UnitAuras and type(C_UnitAuras.GetAuraDataByAuraInstanceID) == "function" then
                    local success, result = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", id)
                    if success then aura = result end
                end
                -- A failed/secret query is not replaced with another aura API.
                AuraRow(action, aura, id, hp)
            end
        end
    end
end

local function CaptureAura(update, hp)
    local reason = TableAccess(update)
    if reason then
        Append({ event = "UNIT_AURA", unit = "player", detail = reason, healthPct = hp })
        return
    end
    local full = Public(Field(update, "isFullUpdate"))
    Append({ event = "UNIT_AURA", unit = "player", detail = "isFullUpdate=" .. Escape(full), healthPct = hp })
    -- Full updates report the observed invalidation only. No scan or inferred diff.
    AuraList(update, "addedAuras", "added", hp)
    AuraList(update, "updatedAuraInstanceIDs", "updated", hp)
    AuraList(update, "removedAuraInstanceIDs", "removed", hp)
end

local function CaptureCombatLog(hp)
    local reason = CombatLogAccess()
    if reason then
        addon:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", OnEvent)
        subscriptions.COMBAT_LOG_EVENT_UNFILTERED = reason
        Append({ event = "CAPABILITY", detail = "COMBAT_LOG_EVENT_UNFILTERED=" .. reason, healthPct = hp })
        return
    end
    local values = { pcall(CombatLogGetCurrentEventInfo) }
    if not values[1] then
        Append({ event = "COMBAT_LOG_EVENT_UNFILTERED", detail = UNAVAILABLE, healthPct = hp })
        return
    end
    -- pcall shifts the native tuple by one; no damage/heal amounts are consumed.
    local source, dest = Public(values[5]), Public(values[9])
    if IsKnown(playerGUID) and IsKnown(source) and IsKnown(dest)
        and source ~= playerGUID and dest ~= playerGUID then return end
    local subEvent = Public(values[3])
    local row = { event = "COMBAT_LOG_EVENT_UNFILTERED", sourceGUID = source, destGUID = dest,
        subEvent = subEvent, cleuTimestamp = Public(values[2]), healthPct = hp }
    if type(subEvent) == "string" and IsKnown(subEvent) then
        if subEvent:match("^SPELL_") or subEvent:match("^RANGE_")
            or subEvent == "DAMAGE_SHIELD" or subEvent == "DAMAGE_SHIELD_MISSED" or subEvent == "DAMAGE_SPLIT" then
            row.spellID, row.spellName = Public(values[13]), Public(values[14])
        end
    else
        row.spellID, row.spellName = subEvent, subEvent
    end
    if not IsKnown(playerGUID) or not IsKnown(source) or not IsKnown(dest) then
        row.detail = "playerFilter=UNAVAILABLE"
    end
    Append(row)
end

local function ChannelSnapshot(row)
    row.channelSpellID, row.channelStartTimeMs = UNAVAILABLE, UNAVAILABLE
    row.channelEndTimeMs, row.channelCastBarID = UNAVAILABLE, UNAVAILABLE
    if row.unit ~= "player" or type(UnitChannelInfo) ~= "function" then return end
    -- One optional observation, including STOP after the native channel disappears.
    -- Do not gate public fields on the name, cast GUID or another returned field.
    local values = { pcall(UnitChannelInfo, "player") }
    if not values[1] then return end
    -- Native positions: start=4, end=5, spellID=8, castBarID=11; pcall adds one.
    row.channelSpellID = Public(values[9])
    row.channelStartTimeMs = Public(values[5])
    row.channelEndTimeMs = Public(values[6])
    row.channelCastBarID = Public(values[12])
end

local function CaptureSpellcast(event, unit, arg2, arg3, arg4, arg5, hp)
    local row = { event = event, unit = unit, healthPct = hp }
    if event == "UNIT_SPELLCAST_SENT" then
        -- SENT is (unit, target, castGUID, spellID). The target is never inspected.
        -- This event does not establish success, queue acceptance or button timing.
        row.castGUID, row.spellID = Public(arg3), Public(arg4)
    else
        row.castGUID, row.spellID = Public(arg2), Public(arg3)
        if event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            -- These signatures insert interruptedBy before castBarID.
            row.interruptedBy, row.castBarID = Public(arg4), Public(arg5)
        else
            row.castBarID = Public(arg4)
        end
    end
    row.spellName = SpellName(row.spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        ChannelSnapshot(row)
    end
    Append(row)
end

OnEvent = function(_, event, unit, arg2, arg3, arg4, arg5)
    if not enabled then return end
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CaptureCombatLog(mode == "altertime" and Health() or nil)
        return
    end
    local publicUnit = Public(unit)
    if IsKnown(publicUnit) and publicUnit ~= "player" then return end
    local hp = mode == "altertime" and Health() or nil
    if event == "UNIT_AURA" and publicUnit == "player" then
        CaptureAura(arg2, hp)
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_AURA" then
        Append({ event = event, unit = publicUnit, healthPct = hp,
            detail = event == "UNIT_AURA" and publicUnit or nil })
    else
        CaptureSpellcast(event, publicUnit, arg2, arg3, arg4, arg5, hp)
    end
end

function capture:Stop()
    enabled = false
    for event, state in pairs(subscriptions) do
        if state == "REGISTERED" then addon:UnregisterEvent(event, OnEvent) end
    end
end

local function ClearDump()
    if dumpFrame then dumpFrame:Hide(); dumpEdit:SetText("") end
end

function capture:Clear()
    self:Stop()
    buffer, subscriptions = {}, {}
    mode, truncated, clock, startedAt, lastTime, playerGUID = nil, false, nil, nil, nil, nil
    ClearDump()
end

function capture:Start(requested)
    if not modes[requested] then return false end
    if enabled and requested == mode then return true end
    self:Clear()
    mode, enabled = requested, true
    clock = type(GetTimePreciseSec) == "function" and GetTimePreciseSec or GetTime
    startedAt, lastTime, playerGUID = Read(clock, 1), 0, Read(UnitGUID, 1, "player")
    SessionMetadata()
    for _, event in ipairs(events) do Subscribe(event) end
    if mode == "altertime" then
        for _, event in ipairs(healthEvents) do Subscribe(event) end
    end
    return true
end

function capture:GetStatus()
    local registered = {}
    for event, state in pairs(subscriptions) do
        registered[event] = not enabled and state == "REGISTERED" and "OFF" or state
    end
    return { enabled = enabled, mode = mode, count = #buffer, cap = CAP,
        truncated = truncated, subscriptions = registered }
end

function capture:Dump()
    local lines = { "# CarGOUI CTLOG Phase1\tformat=2\tmode=" .. (mode or "NONE")
        .. "\tenabled=" .. tostring(enabled) .. "\tcount=" .. #buffer .. "\tcap=" .. CAP
        .. "\tTRUNCATED=" .. tostring(truncated), table.concat(columns, "\t") }
    for _, row in ipairs(buffer) do
        local cells = {}
        for i, key in ipairs(columns) do
            cells[i] = key == "t" and IsNumber(row[key]) and string.format("%.6f", row[key]) or Escape(row[key])
        end
        lines[#lines + 1] = table.concat(cells, "\t")
    end
    return table.concat(lines, "\n")
end

-- A copy surface created only by an explicit dump request, separate from Options.
function capture:ShowDump()
    if not dumpFrame then
        dumpFrame = CreateFrame("Frame", nil, UIParent)
        dumpFrame:SetSize(860, 540)
        dumpFrame:SetPoint("CENTER")
        dumpFrame:SetFrameStrata("DIALOG")
        dumpFrame:EnableMouse(true)
        local background = dumpFrame:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(dumpFrame)
        background:SetColorTexture(0.04, 0.05, 0.07, 0.98)
        local title = dumpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Class Tools raw capture - Ctrl+A / Ctrl+C to copy; Escape to close")
        local close = CreateFrame("Button", nil, dumpFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() dumpFrame:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, dumpFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -48)
        scroll:SetSize(800, 472)
        dumpEdit = CreateFrame("EditBox", nil, scroll)
        dumpEdit:SetSize(792, 472)
        dumpEdit:SetMultiLine(true)
        dumpEdit:SetAutoFocus(false)
        dumpEdit:SetMaxLetters(0)
        dumpEdit:SetMaxBytes(0)
        dumpEdit:SetFontObject("ChatFontNormal")
        scroll:SetScrollChild(dumpEdit)
        dumpEdit:SetScript("OnEscapePressed", function() dumpFrame:Hide() end)
        dumpEdit:SetScript("OnTextChanged", function(self)
            self:SetHeight(math.max(472, self:GetNumLines() * 16 + 16))
            scroll:UpdateScrollChildRect()
        end)
        dumpFrame:SetScript("OnHide", function() dumpEdit:ClearFocus() end)
    end
    dumpEdit:SetText(self:Dump())
    dumpFrame:Show()
    dumpEdit:SetFocus()
    dumpEdit:HighlightText()
end

function capture:HandleCommand(args)
    local action = args[2]
    if #args == 3 and modes[action] and args[3] == "on" then
        self:Start(action)
    elseif #args == 2 and action == "off" then
        self:Stop()
    elseif #args == 2 and action == "clear" then
        self:Clear()
    elseif #args == 2 and action == "dump" then
        self:ShowDump()
        return
    elseif not (#args == 2 and action == "status") then
        addon:Print("Usage: /cui ctlog <arcane|combustion|altertime> on | off | status | clear | dump")
        return
    end
    addon:Print("CTLOG " .. (enabled and "ON" or "OFF") .. " mode=" .. (mode or "NONE")
        .. " records=" .. #buffer .. "/" .. CAP .. " TRUNCATED=" .. tostring(truncated))
    local ordered = {}
    for event in pairs(subscriptions) do ordered[#ordered + 1] = event end
    table.sort(ordered)
    local status = self:GetStatus()
    for _, event in ipairs(ordered) do addon:Print("CTLOG " .. event .. "=" .. status.subscriptions[event]) end
end
