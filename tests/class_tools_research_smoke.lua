-- Offline contract tests for the temporary Phase 1 / 1.1 logger. The real event router
-- is loaded below; secret tokens are tripwires, not a simulation of client taint.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local researchPath = h.root .. "/Research/ClassToolsRawCapture.lua"
local commonEvents = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_SENT",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_AURA", "COMBAT_LOG_EVENT_UNFILTERED",
}
local secrets, inaccessible = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local function opaque(asTable)
    local function forbidden() error("Research attempted to inspect an opaque value", 2) end
    local value = setmetatable({}, { __index = forbidden, __tostring = forbidden,
        __add = forbidden, __sub = forbidden, __mul = forbidden, __div = forbidden,
        __mod = forbidden, __pow = forbidden, __unm = forbidden, __lt = forbidden,
        __le = forbidden, __concat = forbidden, __eq = forbidden })
    secrets[value] = asTable and "table" or "value"
    return value
end

local function configure(env, state)
    state.clock, state.health, state.apiReads = state.clock or 100, 73.25, 0
    state.auraData = {}
    local function read(value) state.apiReads = state.apiReads + 1; return value end
    env.issecretvalue = function(value) return secrets[value] == "value" end
    env.issecrettable = function(value) return secrets[value] == "table" end
    env.canaccessvalue = function(value) return not secrets[value] and not inaccessible[value] end
    env.canaccesstable = function(value) return not secrets[value] and not inaccessible[value] end
    env.GetTime = function() return read(state.clock) end
    env.GetTimePreciseSec = env.GetTime
    env.GetBuildInfo = function() read(); return "12.1.0", "99999", "Sep 28 2026", 120100 end
    env.UnitClass = function() read(); return "Mage", "MAGE", 8 end
    env.GetSpecialization = function() return read(1) end
    env.GetSpecializationInfo = function() read(); return state.specID or 62, "Mock specialization" end
    env.C_SpecializationInfo = { GetSpecialization = env.GetSpecialization,
        GetSpecializationInfo = env.GetSpecializationInfo }
    env.GetHaste = function() return read(25.5) end
    env.GetNetStats = function() read(); return 0, 0, 32, 45 end
    env.GetCVar = function(name) equal(name, "SpellQueueWindow"); return read("400") end
    env.C_CVar = { GetCVar = env.GetCVar }
    env.UnitGUID = function(unit) equal(unit, "player"); return read("Player-Research") end
    env.CurveConstants = { ScaleTo100 = {} }
    env.UnitHealthPercent = function(unit, predicted, curve)
        equal(unit, "player"); equal(predicted, false, "no predicted health input")
        equal(curve, env.CurveConstants.ScaleTo100, "native curve supplies 0..100 percentage")
        return read(state.health)
    end
    env.UnitHealth = function() error("Research must not query raw health") end
    env.UnitHealthMax = function() error("Research must not divide raw health") end
    env.C_CombatLog = { IsCombatLogRestricted = function() return read(state.cleuRestricted or false) end }
    env.CombatLogGetCurrentEventInfo = function()
        state.cleuReads = (state.cleuReads or 0) + 1
        return unpack(state.cleu or {})
    end
    env.C_Spell = env.C_Spell or {}
    env.C_Spell.GetSpellName = function(id)
        truthy(not secrets[id] and not inaccessible[id], "only public spell IDs reach lookup")
        return read(state.spellName or ("Debug spell " .. tostring(id)))
    end
    env.C_Spell.GetSpellInfo = function(id)
        return { name = env.C_Spell.GetSpellName(id), spellID = id }
    end
    env.C_UnitAuras = env.C_UnitAuras or {}
    env.C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
        equal(unit, "player"); truthy(not secrets[id] and not inaccessible[id])
        state.auraReads = (state.auraReads or 0) + 1
        return state.auraData[id]
    end
    env.C_UnitAuras.GetPlayerAuraBySpellID = function()
        error("Research must not infer an aura window from candidate spell IDs")
    end
    env.C_AddOns = env.C_AddOns or {}
    env.C_AddOns.GetAddOnMetadata = function(_, field)
        equal(field, "Version"); return read("1.0.0")
    end
end

local function fixture(saved)
    local env = setmetatable({}, { __index = _G })
    local state = { frames = {}, errors = {}, messages = {}, clock = 100,
        registrations = {}, unregistrations = {}, apiReads = 0 }
    env._G, env.CarGOUIDB = env, saved or { marker = "existing settings" }
    configure(env, state)
    env.geterrorhandler = function()
        return function(message) state.errors[#state.errors + 1] = message end
    end
    env.CreateFrame = function()
        local frame = { events = {}, scripts = {} }
        function frame:RegisterEvent(event)
            if state.rejectEvent == event then error("Unsupported research event") end
            if state.falseEvent == event then return false end
            self.events[event] = true
            state.registrations[event] = (state.registrations[event] or 0) + 1
        end
        function frame:UnregisterEvent(event)
            self.events[event] = nil
            state.unregistrations[event] = (state.unregistrations[event] or 0) + 1
        end
        function frame:SetScript(name, callback)
            equal(name, "OnEvent", "research never creates OnUpdate polling")
            self.scripts[name] = callback
        end
        state.frames[#state.frames + 1] = frame
        return frame
    end
    env.C_Timer = { After = function() error("Research never schedules polling") end,
        NewTimer = function() error("Research never schedules timers") end,
        NewTicker = function() error("Research never schedules tickers") end }
    local addon = { name = "CarGOUI", version = "1.0.0", db = env.CarGOUIDB }
    function addon:Print(message) state.messages[#state.messages + 1] = message end
    for _, path in ipairs({ h.root .. "/Core/Events.lua", researchPath }) do
        local chunk = assert(loadfile(path)); setfenv(chunk, env); chunk("CarGOUI", addon)
    end
    function state:fire(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
        end
    end
    function state:cast(event, id, guid)
        self:fire(event or "UNIT_SPELLCAST_SUCCEEDED", "player", guid or "Cast-Research", id or 5143)
    end
    return env, addon, state, assert(addon.ClassToolsRawCapture, "research module is attached")
end

local function rows(logger)
    local result, header = {}, nil
    local dump = logger:Dump()
    truthy(type(dump) == "string", "dump is a copyable string")
    for line in (dump .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        if line:match("^t\tseq\t") then
            header = {}
            for field in (line .. "\t"):gmatch("(.-)\t") do header[#header + 1] = field end
        elseif header and line ~= "" and line:sub(1, 1) ~= "#" then
            local fields, row = {}, {}
            for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
            equal(#fields, #header, "every raw record keeps the TSV shape")
            for index, name in ipairs(header) do row[name] = fields[index] end
            result[#result + 1] = row
        end
    end
    truthy(header, "dump includes stable TSV header")
    return result, dump, header
end
local function last(logger) local records = rows(logger); return records[#records] end
local function noErrors(state) equal(#state.errors, 0, "event router caught no research errors") end
local function contains(text, part, label) truthy(text:find(part, 1, true), label or ("missing " .. part)) end

test("CT research defaults OFF and the existing event router owns every subscription", function()
    local _, addon, state, logger = fixture()
    local status = logger:GetStatus()
    equal(status.enabled, false); equal(status.count, 0); equal(status.truncated, false)
    equal(status.cap, 2000, "bounded memory cap")
    equal(addon:GetEventDiagnostics().callbacks, 0, "OFF has no research listeners")
    equal(state.apiReads, 0, "OFF metadata and gameplay APIs are not queried")
    equal(#state.frames, 1, "only the existing Core/Events frame is allocated")
    for _, event in ipairs(commonEvents) do state:fire(event, "player", "Cast-Off", 5143) end
    equal(logger:GetStatus().count, 0); equal(state.apiReads, 0)
    noErrors(state)
end)

test("CT research mode switching uses exact event sets without duplicate subscriptions", function()
    local _, addon, state, logger = fixture()
    for _, mode in ipairs({ "arcane", "combustion", "altertime", "arcane" }) do
        truthy(logger:Start(mode)); equal(logger:GetStatus().mode, mode)
        local before = logger:Dump()
        truthy(logger:Start(mode)); equal(logger:Dump(), before, "repeated ON preserves session")
        local expected = #commonEvents + (mode == "altertime" and 2 or 0)
        equal(addon:GetEventDiagnostics().callbacks, expected, "exact callback count")
        for _, event in ipairs(commonEvents) do
            equal(addon:GetEventDiagnostics().perEvent[event], 1, "one listener for " .. event)
        end
        equal(addon:GetEventDiagnostics().perEvent.UNIT_HEALTH, mode == "altertime" and 1 or nil)
        equal(addon:GetEventDiagnostics().perEvent.UNIT_MAXHEALTH, mode == "altertime" and 1 or nil)
        state:cast(); noErrors(state)
    end
    equal(logger:Start("invalid"), false, "invalid mode cannot disturb active session")
    equal(logger:GetStatus().mode, "arcane"); equal(logger:GetStatus().enabled, true)
end)

test("CT research OFF removes only its own callbacks and preserves its immutable dump", function()
    local _, addon, state, logger = fixture()
    local calls = 0
    addon:RegisterEvent("UNIT_AURA", function() calls = calls + 1 end)
    truthy(logger:Start("arcane")); state:cast(); logger:Stop()
    local before, reads = logger:Dump(), state.apiReads
    state:cast(); state:fire("UNIT_AURA", "player", {})
    equal(calls, 1, "pre-existing listener remains active")
    equal(addon:GetEventDiagnostics().callbacks, 1, "only owner callbacks are removed")
    equal(logger:Dump(), before, "stopped session receives no new records")
    equal(state.apiReads, reads, "OFF does not inspect events or gameplay APIs")
    logger:Stop(); equal(addon:GetEventDiagnostics().callbacks, 1); noErrors(state)
end)

test("CT research clear stops recording and removes all raw records and truncation", function()
    local _, addon, state, logger = fixture()
    truthy(logger:Start("altertime")); state:cast(); logger:Clear()
    equal(logger:GetStatus().enabled, false); equal(logger:GetStatus().count, 0)
    equal(logger:GetStatus().truncated, false); equal(addon:GetEventDiagnostics().callbacks, 0)
    equal(#rows(logger), 0); state:cast(); equal(logger:GetStatus().count, 0)
    truthy(logger:Start("combustion")); equal(rows(logger)[1].event, "SESSION_START")
    noErrors(state)
end)

test("CT research dump retains raw fields in insertion order with monotonic relative timestamps", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    state.clock = 100.125; state:cast("UNIT_SPELLCAST_CHANNEL_START", 5143, "Cast-First")
    state.clock = 100.375; state:cast("UNIT_SPELLCAST_CHANNEL_UPDATE", 5143, "Cast-First")
    state.clock = 100.25; state:cast("UNIT_SPELLCAST_CHANNEL_STOP", 5143, "Cast-First")
    local records, dump, header = rows(logger)
    same(header, { "t", "seq", "event", "unit", "castGUID", "spellID", "spellName",
        "sourceGUID", "destGUID", "subEvent", "healthPct", "detail", "auraInstanceID",
        "duration", "expirationTime", "applications", "cleuTimestamp",
        "castBarID", "interruptedBy", "channelSpellID", "channelStartTimeMs", "channelEndTimeMs", "channelCastBarID" })
    contains(dump, "\tformat=2\t", "appended fields have a new explicit dump format")
    equal(records[1].event, "SESSION_START"); equal(tonumber(records[1].t), 0)
    local previous = -1
    for index, row in ipairs(records) do
        equal(tonumber(row.seq), index, "sequence matches capture order")
        truthy(tonumber(row.t) >= previous, "relative timestamp never runs backward")
        previous = tonumber(row.t)
    end
    equal(records[#records - 2].event, "UNIT_SPELLCAST_CHANNEL_START")
    equal(records[#records - 1].event, "UNIT_SPELLCAST_CHANNEL_UPDATE")
    equal(records[#records].event, "UNIT_SPELLCAST_CHANNEL_STOP")
    equal(records[#records].unit, "player"); equal(records[#records].castGUID, "Cast-First")
    equal(records[#records].spellID, "5143"); contains(records[#records].spellName, "5143")
    equal(logger:Dump(), dump, "dump is deterministic and does not append records")
    noErrors(state)
end)

test("CT research session metadata is captured once and independently from event facts", function()
    local _, addon, state, logger = fixture()
    truthy(logger:Start("arcane")); state:cast(); state:cast()
    local records, dump, sessions = rows(logger), logger:Dump(), 0
    for _, row in ipairs(records) do if row.event == "SESSION_START" then sessions = sessions + 1 end end
    equal(sessions, 1)
    contains(records[1].detail, "addonVersion=1.0.0;")
    contains(records[1].detail, "researchLoggerRevision=phase1.1")
    equal(addon.version, "1.0.0", "research revision does not change the addon version")
    for _, value in ipairs({ "1.0.0", "12.1.0", "120100", "MAGE", "62", "25.5", "32", "45", "400", "arcane" }) do
        contains(dump, value, "session records " .. value)
    end
    noErrors(state)
end)

test("CT research records fourth-argument castBarID on ordinary cast and channel events", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    for index, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
        state:fire(event, "player", "Cast-" .. index, 5143, 200 + index)
        local row = last(logger)
        equal(row.event, event); equal(row.castGUID, "Cast-" .. index); equal(row.spellID, "5143")
        equal(row.castBarID, tostring(200 + index)); equal(row.interruptedBy, "")
    end
    noErrors(state)
end)

test("CT research CHANNEL_STOP and INTERRUPTED preserve interruptedBy before castBarID", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
        state:fire(event, "player", "Cast-Stop", 5143, "Player-Interrupter-1", 301)
        local row = last(logger)
        equal(row.event, event); equal(row.interruptedBy, "Player-Interrupter-1"); equal(row.castBarID, "301")
        equal(row.castGUID, "Cast-Stop"); equal(row.spellID, "5143")
        state:fire(event, "player", "Cast-Nil", 5143, nil, 302)
        equal(last(logger).interruptedBy, "UNAVAILABLE")
        equal(last(logger).castBarID, "302", "a nil interruptedBy cannot shift the fifth argument")
        state:fire(event, "player", "Cast-Missing", 5143, "Player-Interrupter-2")
        equal(last(logger).interruptedBy, "Player-Interrupter-2"); equal(last(logger).castBarID, "UNAVAILABLE")
    end
    noErrors(state)
end)

test("CT research guards interruptedBy and castBarID independently", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    local blocked = {}; inaccessible[blocked] = true
    for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
        for _, value in ipairs({ opaque(), blocked }) do
            state:fire(event, "player", "Cast-Secret", 5143, value, 401)
            equal(last(logger).interruptedBy, "RESTRICTED"); equal(last(logger).castBarID, "401")
            state:fire(event, "player", "Cast-Secret", 5143, "Player-Interrupter-1", value)
            equal(last(logger).interruptedBy, "Player-Interrupter-1"); equal(last(logger).castBarID, "RESTRICTED")
        end
    end
    state:fire("UNIT_SPELLCAST_START", "player", "Cast-Secret", 5143, opaque())
    equal(last(logger).castBarID, "RESTRICTED")
    noErrors(state)
end)

test("CT research public castBarID survives unavailable or restricted castGUID and spellID", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED" }) do
        for _, unavailable in ipairs({ false, true }) do
            local guid, spell = opaque(), opaque()
            if unavailable then guid, spell = nil, nil end
            if event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
                state:fire(event, "player", guid, spell, nil, 501)
            else state:fire(event, "player", guid, spell, 501) end
            local row = last(logger)
            equal(row.castBarID, "501")
            equal(row.castGUID, unavailable and "UNAVAILABLE" or "RESTRICTED")
            equal(row.spellID, unavailable and "UNAVAILABLE" or "RESTRICTED")
        end
    end
    noErrors(state)
end)

test("CT research SENT captures its own raw signature in every mode and never inspects target", function()
    local env, _, state, logger = fixture()
    local target, probes, oldSecret = opaque(), 0, env.issecretvalue
    env.issecretvalue = function(value)
        if rawequal(value, target) then probes = probes + 1; error("SENT target is irrelevant") end
        return oldSecret(value)
    end
    for _, mode in ipairs({ "arcane", "combustion", "altertime" }) do
        truthy(logger:Start(mode))
        state.clock = state.clock + 0.125
        state:fire("UNIT_SPELLCAST_SENT", "player", target, "Cast-Sent", 5143)
        local row = last(logger)
        equal(row.event, "UNIT_SPELLCAST_SENT"); equal(row.unit, "player")
        equal(row.castGUID, "Cast-Sent"); equal(row.spellID, "5143"); equal(tonumber(row.t), 0.125)
        equal(row.castBarID, ""); equal(row.interruptedBy, ""); equal(row.channelSpellID, "")
        equal(row.detail, "", "SENT adds no success or queue interpretation")
        state:fire("UNIT_SPELLCAST_SENT", "player", "Target-Never-Saved", opaque(), opaque())
        equal(last(logger).castGUID, "RESTRICTED"); equal(last(logger).spellID, "RESTRICTED")
        truthy(not logger:Dump():find("Target-Never-Saved", 1, true), "target is absent from raw logs")
    end
    equal(probes, 0, "target never reaches a secret predicate")
    noErrors(state)
end)

test("CT research channel events take exactly one snapshot with the native return positions", function()
    local env, _, state, logger = fixture()
    local calls = 0
    env.UnitChannelInfo = function(unit)
        equal(unit, "player"); calls = calls + 1
        return "Arcane Missiles", "Display", 123, 8506.687, 10056.172, false, false, 5143, false, 0, 601
    end
    for _, mode in ipairs({ "arcane", "combustion", "altertime" }) do
        truthy(logger:Start(mode))
        for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
            "UNIT_SPELLCAST_CHANNEL_STOP" }) do
            local before = calls
            if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                state:fire(event, "player", "Cast-Channel", 5143, nil, 602)
            else state:fire(event, "player", "Cast-Channel", 5143, 602) end
            equal(calls, before + 1, "each eligible event attempts one native query")
            local row = last(logger)
            equal(row.castBarID, "602"); equal(row.channelCastBarID, "601", "snapshot ID remains independent")
            equal(row.channelSpellID, "5143"); equal(tonumber(row.channelStartTimeMs), 8506.687)
            equal(tonumber(row.channelEndTimeMs), 10056.172, "native millisecond values are not transformed")
        end
    end
    equal(calls, 9); noErrors(state)
end)

test("CT research channel snapshot guards each field without gating on name or spell", function()
    local env, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    local blocked = {}; inaccessible[blocked] = true
    env.UnitChannelInfo = function()
        return opaque(), nil, nil, 1000, opaque(), nil, nil, blocked, nil, nil, 701
    end
    state:fire("UNIT_SPELLCAST_CHANNEL_START", "player", opaque(), 5143, 702)
    local row = last(logger)
    equal(row.channelStartTimeMs, "1000"); equal(row.channelEndTimeMs, "RESTRICTED")
    equal(row.channelSpellID, "RESTRICTED"); equal(row.channelCastBarID, "701")
    equal(row.castBarID, "702"); equal(row.castGUID, "RESTRICTED")
    env.UnitChannelInfo = function()
        return nil, nil, nil, opaque(), 2000, nil, nil, 5143, nil, nil, blocked
    end
    state:fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player", nil, 5143, 703)
    row = last(logger)
    equal(row.channelStartTimeMs, "RESTRICTED"); equal(row.channelEndTimeMs, "2000")
    equal(row.channelSpellID, "5143"); equal(row.channelCastBarID, "RESTRICTED")
    equal(row.castBarID, "703"); equal(row.castGUID, "UNAVAILABLE")
    noErrors(state)
end)

test("CT research channel snapshot tolerates absent throwing and empty native APIs", function()
    for _, variant in ipairs({ "missing", "throws", "empty" }) do
        local env, _, state, logger = fixture()
        local calls = 0
        if variant == "missing" then env.UnitChannelInfo = nil
        else
            env.UnitChannelInfo = function()
                calls = calls + 1
                if variant == "throws" then error("Channel info unavailable") end
            end
        end
        truthy(logger:Start("arcane"))
        for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
            "UNIT_SPELLCAST_CHANNEL_STOP" }) do
            state:fire(event, "player", nil, 5143)
            local row = last(logger)
            for _, field in ipairs({ "channelSpellID", "channelStartTimeMs", "channelEndTimeMs", "channelCastBarID" }) do
                equal(row[field], "UNAVAILABLE", event .. " preserves an unavailable " .. field)
            end
        end
        equal(calls, variant == "missing" and 0 or 3, "failed snapshots are not retried")
        noErrors(state)
    end
end)

test("CT research snapshot never polls or reads outside an active public player channel event", function()
    local env, _, state, logger = fixture()
    local calls = 0
    env.UnitChannelInfo = function() calls = calls + 1 end
    for _, event in ipairs(commonEvents) do state:fire(event, "player", "Cast-Off", 5143, 801) end
    equal(calls, 0, "default OFF never queries channel info")
    truthy(logger:Start("altertime")); equal(calls, 0, "metadata capture does not query channel info")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SENT",
        "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_AURA" }) do
        state:fire(event, "player", "Cast-Other", 5143, 801)
    end
    equal(calls, 0, "non-channel events never query channel info")
    for _, event in ipairs({ "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP" }) do
        state:fire(event, "party1", "Cast-Other", 5143, 801)
        state:fire(event, opaque(), "Cast-Unknown", 5143, 801)
        equal(last(logger).unit, "RESTRICTED")
        equal(last(logger).channelCastBarID, "UNAVAILABLE", "unknown unit cannot be attributed to player")
        state:fire(event, nil, "Cast-Unknown", 5143, 801)
        equal(last(logger).unit, "UNAVAILABLE"); equal(last(logger).channelSpellID, "UNAVAILABLE")
    end
    equal(calls, 0, "other or inaccessible units cannot trigger a player snapshot")
    state:fire("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 5143, 802)
    equal(calls, 1)
    local count, dump = logger:GetStatus().count, logger:Dump()
    state.clock = state.clock + 100
    logger:GetStatus(); equal(logger:Dump(), dump)
    equal(logger:GetStatus().count, count); equal(calls, 1, "time and inspection produce no observations")
    logger:Stop()
    local stoppedDump = logger:Dump()
    for _, event in ipairs(commonEvents) do state:fire(event, "player", "Cast-Off", 5143, 803) end
    equal(calls, 1, "explicit OFF never queries channel info"); equal(logger:Dump(), stoppedDump)
    noErrors(state)
end)

test("CT research hard cap stops capture without overwriting the earliest evidence", function()
    local _, addon, state, logger = fixture()
    truthy(logger:Start("arcane"))
    local first = rows(logger)[1]
    local cap = logger:GetStatus().cap
    for index = 1, cap + 30 do state.clock = 100 + index / 100; state:cast(nil, 5143, "Cast-" .. index) end
    local status = logger:GetStatus()
    equal(status.count, cap); equal(status.truncated, true); equal(status.enabled, false)
    equal(status.mode, "arcane", "truncated session retains its mode")
    equal(addon:GetEventDiagnostics().callbacks, 0, "cap releases all subscriptions")
    local records, dump = rows(logger)
    equal(#records, cap); same(records[1], first, "ring overwrite is forbidden")
    contains(dump, "TRUNCATED", "copyable dump carries truncation flag")
    state:cast(); equal(logger:Dump(), dump, "cap is stable after later events")
    truthy(logger:Start("arcane")); equal(logger:GetStatus().truncated, false)
    truthy(logger:GetStatus().count < cap, "new explicit ON begins a fresh session")
    noErrors(state)
end)

test("CT research unit events preserve unknown spell IDs without candidate classification", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    for _, id in ipairs({ 7268, 263725, 123456789 }) do
        state:cast("UNIT_SPELLCAST_SUCCEEDED", id)
        equal(last(logger).spellID, tostring(id), "candidate is raw evidence only")
    end
    noErrors(state)
end)

test("CT research public CLEU retains source destination subevent and original clock", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    state.cleu = { 800.25, "SPELL_PERIODIC_DAMAGE", false, "Player-Research", "Player", 0, 0,
        "Creature-Target", "Target", 0, 0, 7268, "Arcane Missiles", 64, 789 }
    state:fire("COMBAT_LOG_EVENT_UNFILTERED")
    local row = last(logger)
    equal(row.event, "COMBAT_LOG_EVENT_UNFILTERED"); equal(row.subEvent, "SPELL_PERIODIC_DAMAGE")
    equal(row.spellID, "7268"); equal(row.sourceGUID, "Player-Research")
    equal(row.destGUID, "Creature-Target"); equal(row.spellName, "Arcane Missiles")
    equal(tonumber(row.cleuTimestamp), 800.25); equal(state.cleuReads, 1); noErrors(state)
end)

test("CT research safely rejects unrelated unit and CLEU traffic without spell filtering", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    local before = logger:GetStatus().count
    state:fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast-Other", 5143)
    state:fire("UNIT_AURA", "target", {})
    state.cleu = { 801, "SPELL_PERIODIC_DAMAGE", false, "Player-Other", "Other", 0, 0,
        "Creature-OtherTarget", "Target", 0, 0, 7268, "Arcane Missiles", 64, 789 }
    state:fire("COMBAT_LOG_EVENT_UNFILTERED")
    equal(logger:GetStatus().count, before, "publicly unrelated traffic consumes no buffer")
    state.cleu[8] = "Player-Research"
    state:fire("COMBAT_LOG_EVENT_UNFILTERED")
    equal(last(logger).destGUID, "Player-Research", "incoming player events remain observable")
    noErrors(state)
end)

test("CT research restricted CLEU is marked and never subscribed or read", function()
    local _, addon, state, logger = fixture()
    state.cleuRestricted = true
    truthy(logger:Start("arcane"))
    equal(logger:GetStatus().subscriptions.COMBAT_LOG_EVENT_UNFILTERED, "RESTRICTED")
    equal(addon:GetEventDiagnostics().perEvent.COMBAT_LOG_EVENT_UNFILTERED, nil)
    state:fire("COMBAT_LOG_EVENT_UNFILTERED"); equal(state.cleuReads, nil)
    contains(logger:Dump(), "RESTRICTED"); noErrors(state)
end)

test("CT research unavailable CLEU capability fails closed while unit capture continues", function()
    for _, variant in ipairs({ "missing", "throws", "secret" }) do
        local env, addon, state, logger = fixture()
        if variant == "missing" then env.C_CombatLog = nil
        elseif variant == "throws" then env.C_CombatLog.IsCombatLogRestricted = function() error("Native API unavailable") end
        else env.C_CombatLog.IsCombatLogRestricted = function() return opaque() end end
        truthy(logger:Start("arcane"))
        local capability = logger:GetStatus().subscriptions.COMBAT_LOG_EVENT_UNFILTERED
        truthy(capability == "UNAVAILABLE" or capability == "RESTRICTED", "uncertain capability cannot grant access")
        equal(addon:GetEventDiagnostics().perEvent.COMBAT_LOG_EVENT_UNFILTERED, nil)
        state:cast(); equal(last(logger).event, "UNIT_SPELLCAST_SUCCEEDED")
        state:fire("COMBAT_LOG_EVENT_UNFILTERED"); equal(state.cleuReads, nil)
        noErrors(state)
    end
end)

test("CT research CLEU restriction changes release only CLEU and retain the observed capability gap", function()
    local _, addon, state, logger = fixture()
    truthy(logger:Start("arcane"))
    state.cleuRestricted = true
    state:fire("COMBAT_LOG_EVENT_UNFILTERED")
    equal(logger:GetStatus().subscriptions.COMBAT_LOG_EVENT_UNFILTERED, "RESTRICTED")
    equal(addon:GetEventDiagnostics().perEvent.COMBAT_LOG_EVENT_UNFILTERED, nil)
    equal(state.cleuReads, nil, "restricted native payload is never queried")
    equal(last(logger).event, "CAPABILITY")
    state:cast(); equal(last(logger).event, "UNIT_SPELLCAST_SUCCEEDED")
    equal(logger:GetStatus().enabled, true); noErrors(state)
end)

test("CT research secret CLEU payload fields never reach formatting or spell lookup", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    state.cleu = { opaque(), "SPELL_PERIODIC_DAMAGE", false, "Player-Research", "Player", 0, 0,
        opaque(), "Target", 0, 0, opaque(), opaque(), 64, 789 }
    state:fire("COMBAT_LOG_EVENT_UNFILTERED")
    local row = last(logger)
    equal(row.event, "COMBAT_LOG_EVENT_UNFILTERED")
    equal(row.destGUID, "RESTRICTED"); equal(row.spellID, "RESTRICTED")
    equal(row.spellName, "RESTRICTED"); equal(row.cleuTimestamp, "RESTRICTED")
    noErrors(state)
end)

test("CT research failed event registration degrades one capability without leaked listeners", function()
    for _, rejection in ipairs({ "rejectEvent", "falseEvent" }) do
        local _, addon, state, logger = fixture()
        state[rejection] = "UNIT_SPELLCAST_CHANNEL_UPDATE"
        truthy(logger:Start("arcane"))
        equal(logger:GetStatus().subscriptions.UNIT_SPELLCAST_CHANNEL_UPDATE, "UNAVAILABLE")
        equal(addon:GetEventDiagnostics().perEvent.UNIT_SPELLCAST_CHANNEL_UPDATE, nil)
        state:cast(); equal(last(logger).event, "UNIT_SPELLCAST_SUCCEEDED")
        logger:Stop(); equal(addon:GetEventDiagnostics().callbacks, 0); noErrors(state)
    end
end)

test("CT research Alter Time records only public percent at cast aura and health events", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("altertime"))
    for _, event in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH" }) do
        if event == "UNIT_AURA" then state:fire(event, "player", {})
        else state:fire(event, "player", "Cast-Alter", 342245) end
        equal(tonumber(last(logger).healthPct), 73.25, event .. " snapshots public native percentage")
    end
    noErrors(state)
end)

test("CT research health marks secrets inaccessible values and API failures without arithmetic", function()
    local env, _, state, logger = fixture()
    truthy(logger:Start("altertime"))
    state.health = opaque(); state:cast(nil, 342245); equal(last(logger).healthPct, "RESTRICTED")
    local inaccessibleHealth = {}; inaccessible[inaccessibleHealth] = true
    state.health = inaccessibleHealth; state:cast(nil, 342245); equal(last(logger).healthPct, "RESTRICTED")
    state.health = nil; state:cast(nil, 342245); equal(last(logger).healthPct, "UNAVAILABLE")
    env.UnitHealthPercent = function() error("Restricted native health API") end
    state:cast(nil, 342245); equal(last(logger).healthPct, "UNAVAILABLE")
    env.UnitHealthPercent = nil; state:cast(nil, 342245); equal(last(logger).healthPct, "UNAVAILABLE")
    env.UnitHealthPercent = function() error("An unscaled health ratio must not be queried") end
    env.CurveConstants = nil; state:cast(nil, 342245); equal(last(logger).healthPct, "UNAVAILABLE")
    noErrors(state)
end)

test("CT research missing safety predicates fail closed for health and raw scalar fields", function()
    local env, _, state, logger = fixture()
    env.issecretvalue = nil
    truthy(logger:Start("altertime")); state:cast(nil, 342245)
    local row = last(logger)
    equal(row.healthPct, "UNAVAILABLE")
    truthy(row.spellID ~= "342245", "unguarded scalar cannot escape to dump")
    contains(logger:Dump(), "UNAVAILABLE"); noErrors(state)
end)

test("CT research secret cast arguments are masked before formatting lookup or comparison", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("arcane"))
    state:fire("UNIT_SPELLCAST_SUCCEEDED", "player", opaque(), opaque())
    local row = last(logger)
    equal(row.castGUID, "RESTRICTED"); equal(row.spellID, "RESTRICTED")
    state:fire("UNIT_SPELLCAST_SUCCEEDED", opaque(), opaque(), opaque())
    noErrors(state); contains(logger:Dump(), "RESTRICTED")
end)

test("CT research secret aura update tables are never indexed", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("combustion"))
    state:fire("UNIT_AURA", "player", opaque(true))
    contains(logger:Dump(), "RESTRICTED"); noErrors(state)
end)

test("CT research public aura deltas retain instance IDs and observed duration changes", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("combustion"))
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = {
        { auraInstanceID = 42, spellId = 190319, name = "Combustion", duration = 10,
            expirationTime = 110, applications = 1 },
    } })
    local added
    for _, row in ipairs(rows(logger)) do if row.auraInstanceID == "42" then added = row end end
    truthy(added, "added aura has an independent raw observation")
    equal(added.spellID, "190319"); equal(tonumber(added.duration), 10)
    equal(tonumber(added.expirationTime), 110); equal(tonumber(added.applications), 1)
    state.auraData[42] = { auraInstanceID = 42, spellId = 190319, name = "Combustion",
        duration = 13, expirationTime = 113, applications = 1 }
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 42 } })
    local updated
    for _, row in ipairs(rows(logger)) do if row.auraInstanceID == "42" then updated = row end end
    equal(tonumber(updated.duration), 13); equal(tonumber(updated.expirationTime), 113)
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, removedAuraInstanceIDs = { 42 } })
    equal(last(logger).auraInstanceID, "42", "removal preserves observed instance identity")
    noErrors(state)
end)

test("CT research nested secret aura tables and fields remain opaque", function()
    local _, _, state, logger = fixture()
    truthy(logger:Start("combustion"))
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = opaque(true) })
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = { opaque(true) } })
    state:fire("UNIT_AURA", "player", { isFullUpdate = false, addedAuras = {
        { auraInstanceID = 42, spellId = opaque(), name = opaque(), duration = opaque(),
            expirationTime = opaque(), applications = opaque() },
    } })
    local row = last(logger)
    equal(row.spellID, "RESTRICTED"); equal(row.duration, "RESTRICTED")
    equal(row.expirationTime, "RESTRICTED"); equal(row.applications, "RESTRICTED")
    for _, value in ipairs({ opaque(), opaque(true) }) do
        state.auraData[42] = value
        state:fire("UNIT_AURA", "player", { isFullUpdate = false, updatedAuraInstanceIDs = { 42 } })
        local updated = last(logger)
        equal(updated.auraInstanceID, "42", "restricted query retains the public input instance ID")
        equal(updated.spellID, "RESTRICTED"); equal(updated.duration, "RESTRICTED")
    end
    noErrors(state)
end)

test("CT research absent table safety predicates prevent aura indexing", function()
    for _, missing in ipairs({ "issecrettable", "canaccesstable" }) do
        local env, _, state, logger = fixture()
        env[missing] = nil
        truthy(logger:Start("combustion"))
        local update = setmetatable({}, { __index = function() error("An unguarded aura table was indexed") end })
        state:fire("UNIT_AURA", "player", update)
        contains(logger:Dump(), "UNAVAILABLE"); noErrors(state)
    end
end)

test("CT research dump escapes raw tabs newlines and backslashes without breaking record boundaries", function()
    local _, _, state, logger = fixture()
    state.spellName = "Debug\tspell\nwith\\separators"
    truthy(logger:Start("arcane")); state:cast(nil, 5143, "Cast\tRaw\nValue")
    local records = rows(logger)
    equal(#records, logger:GetStatus().count, "one input record remains one TSV row")
    equal(last(logger).event, "UNIT_SPELLCAST_SUCCEEDED")
    noErrors(state)
end)

test("CT research secret session metadata is masked before concatenation", function()
    local env, _, state, logger = fixture()
    env.GetHaste = function() return opaque() end
    env.GetNetStats = function() return 0, 0, opaque(), opaque() end
    env.GetCVar = function() return opaque() end
    env.C_CVar.GetCVar = env.GetCVar
    truthy(logger:Start("arcane")); contains(logger:Dump(), "RESTRICTED"); noErrors(state)
end)

test("CT research preserves existing SavedVariables and reload always starts OFF", function()
    local env, addon, state, logger = fixture({ marker = "existing settings", options = { scale = 1.2 } })
    local before = copy(env.CarGOUIDB)
    env.UnitChannelInfo = function()
        return "Arcane Missiles", nil, nil, 1000, 2000, nil, nil, 5143, nil, nil, 901
    end
    for _, mode in ipairs({ "arcane", "combustion", "altertime" }) do
        truthy(logger:Start(mode)); state:cast()
        state:fire("UNIT_SPELLCAST_SENT", "player", opaque(), "Cast-Memory", 5143)
        state:fire("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 5143, 901)
        state:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 5143, opaque(), 901)
        logger:Stop()
    end
    same(env.CarGOUIDB, before, "capture adds no SavedVariables fields")
    same(addon.db, before, "capture writes no formal schema")
    local _, reloaded, _, nextLogger = fixture(copy(env.CarGOUIDB))
    equal(nextLogger:GetStatus().enabled, false); equal(nextLogger:GetStatus().count, 0)
    equal(reloaded:GetEventDiagnostics().callbacks, 0)
    equal(h.metadata.SavedVariables, "CarGOUIDB", "TOC declares no raw-log persistence")
    noErrors(state)
end)

test("CT research command routing works while Options stays lazy and DB unchanged", function()
    local env, addon, state = h.login()
    configure(env, state)
    local before = copy(addon.db)
    for _, mode in ipairs({ "arcane", "combustion", "altertime" }) do
        env.SlashCmdList.CARGOUI("ctlog " .. mode .. " on")
        equal(addon.ClassToolsRawCapture:GetStatus().mode, mode)
        equal(addon.ClassToolsRawCapture:GetStatus().enabled, true)
        equal(addon.optionsFrame, nil, "research does not instantiate an Options page")
    end
    env.SlashCmdList.CARGOUI("ctlog status")
    state:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-Dump", 342245)
    local framesBefore = #state.frames
    env.SlashCmdList.CARGOUI("ctlog dump")
    equal(#state.frames, framesBefore + 4, "explicit dump creates only its copy surface")
    local edit = state.frames[#state.frames]
    equal(edit.kind, "EditBox"); equal(edit:GetText(), addon.ClassToolsRawCapture:Dump())
    equal(edit.maxLetters, 0); equal(edit.maxBytes, 0, "full bounded timeline is copyable")
    truthy(edit:HasFocus()); truthy(edit.highlight, "dump text is selected for copying")
    equal(addon.optionsFrame, nil, "dump does not create formal Options")
    for index = framesBefore + 1, #state.frames do
        equal(state.frames[index]:GetScript("OnUpdate"), nil, "dump surface never polls")
    end
    env.SlashCmdList.CARGOUI("ctlog dump")
    equal(#state.frames, framesBefore + 4, "repeated dump reuses its UI")
    env.SlashCmdList.CARGOUI("ctlog off")
    equal(addon.ClassToolsRawCapture:GetStatus().enabled, false)
    env.SlashCmdList.CARGOUI("ctlog clear")
    equal(addon.ClassToolsRawCapture:GetStatus().count, 0)
    equal(edit:GetText(), "", "clear also removes copy-surface text")
    equal(edit:HasFocus(), false); equal(edit:GetParent():GetParent():IsShown(), false)
    same(addon.db, before)
    local _, reloaded = h.login(copy(addon.db))
    equal(reloaded.ClassToolsRawCapture:GetStatus().enabled, false)
    equal(reloaded.ClassToolsRawCapture:GetStatus().count, 0)
    noErrors(state)
end)

test("CT research start switch stop preserves actual Proc and Mobility native runtime", function()
    local env, addon, state = h.mobilityLogin(212653, { charges = 0, maxCharges = 2,
        chargeStart = 95, chargeDuration = 20, cooldownStart = 100, cooldownDuration = 20,
        secretCharges = true, secretDuration = true }, { proc = {} })
    h.putAura(state, 48108, 19, 1, true); h.putAura(state, 375240, 11, 1, true)
    local oldSecret = env.issecretvalue
    configure(env, state)
    local newSecret = env.issecretvalue
    env.issecretvalue = function(value) return oldSecret(value) or newSecret(value) end
    local db, listeners, reads = copy(addon.db), addon:GetEventDiagnostics(), copy(state.spellReads)
    local slots, bindings = #state.auraSlots, #state.bindings
    local logger = addon.ClassToolsRawCapture
    for _, mode in ipairs({ "arcane", "combustion", "altertime" }) do
        truthy(logger:Start(mode))
        state:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-Regression", 133)
        state:fire("UNIT_SPELLCAST_SENT", "player", "Research target", "Cast-Regression", 133)
        state:fire("UNIT_SPELLCAST_CHANNEL_START", "player", nil, 5143, 1001)
        state:fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", nil, 5143, nil, 1001)
        logger:Stop()
        same(addon:GetEventDiagnostics(), listeners, "shared event consumers survive cleanup")
    end
    same(addon.db, db); same(state.spellReads, reads, "capture does not query Mobility cooldown state")
    equal(#state.auraSlots, slots); equal(#state.bindings, bindings)
    state:advance(3)
    equal(h.nativeText(addon), "No Shimmer\n12.0", "Mobility native timer continues")
    equal(h.procText(addon, state, "mage_fire_hot_streak_left"), "16.0", "Proc native timer continues")
    equal(h.procText(addon, state, "free_move_mage"), "Free move", "Free move remains active")
    noErrors(state)
end)

test("CT research executes under the real Lua 5.1 runtime", function()
    equal(_VERSION, "Lua 5.1", "not a syntax compatibility shim")
    truthy(assert(loadfile(researchPath)), "Lua 5.1 parses the complete logger")
end)
