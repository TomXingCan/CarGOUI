local _, addon = ...

-- These checks inspect only whether a value is restricted, never its contents.
local function Secret(value)
    return issecretvalue(value)
end

local function Number(value)
    return not Secret(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function Result(entry, status, reason, spellID, path, duration, visibility)
    return { entry = entry, status = status, reason = reason or "",
        spellID = spellID, spellName = addon.mobilitySpells[spellID],
        path = path or "none", duration = duration, visibility = visibility }
end

local function DurationHandle(value)
    return not Secret(value) and (type(value) == "userdata" or type(value) == "table")
end

-- The supported spells' ordinary inter-use CD is 500 ms; Blink's base GCD
-- is 1500 ms (12.1.0.69933 client data). This is NOT a recharge estimate.
-- Validate public metadata, including Blink's GCD envelope for either spell,
-- rather than copying a generic 1.6-second cutoff. The next millisecond keeps
-- the exact upper bound on the invisible side of the step curve.
-- See docs/Mobility-Combat-API-Audit.md for evidence and client-test limits.
local function ChargeVisibilityCurve(self)
    if not C_CurveUtil or not C_CurveUtil.CreateCurve or not GetSpellBaseCooldown
        or not Enum or not Enum.LuaCurveType or Enum.LuaCurveType.Step == nil
        or not Enum.DurationTimeModifier or Enum.DurationTimeModifier.BaseTime == nil then
        return nil, "Native curve / public base-cooldown metadata API is unavailable."
    end
    local boundary = 0
    for _, id in ipairs({ 1953, 212653 }) do
        local cooldown, gcd = GetSpellBaseCooldown(id)
        if not Number(cooldown) or not Number(gcd) or cooldown < 0 or gcd < 0 then
            return nil, "Base-cooldown metadata is unavailable or restricted."
        end
        boundary = math.max(boundary, cooldown, gcd)
    end
    -- Do not silently apply this narrow classifier to a changed time domain.
    if boundary ~= 1500 then
        return nil, "Base-cooldown metadata differs from the audited Blink / Shimmer envelope (1500 ms)."
    end
    if not self.mobilityChargeAlphaCurve or self.mobilityChargeAlphaBoundary ~= boundary then
        local curve = C_CurveUtil.CreateCurve()
        if not DurationHandle(curve) or not curve.SetType or not curve.AddPoint then
            return nil, "Native step-curve construction is unavailable."
        end
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint((boundary + 1) / 1000, 1)
        self.mobilityChargeAlphaCurve = curve
        self.mobilityChargeAlphaBoundary = boundary
    end
    return self.mobilityChargeAlphaCurve
end

local function TimerAPIsAvailable()
    return C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
        and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum and Enum.DurationTextBindingProperty and Enum.DurationTimeModifier
        and Enum.NumericRuleFormatRounding
end

-- Reads only the two supported IDs. Spell metadata / preview entries are never
-- evidence of learning; specialization is used solely to select saved offsets.
function addon:ReadMobilityState()
    local entry = self:GetMobilityEntry()
    if not entry then return Result(nil, "Unsupported", "Mage Blink / Shimmer only.") end
    if not issecretvalue then
        return Result(entry, "Unsupported", "Secret-value detection API is unavailable.")
    end
    if not C_SpellBook or not C_SpellBook.IsSpellKnown or not C_Spell or not C_Spell.GetOverrideSpell then
        return Result(entry, "Unsupported", "Spell learning / override APIs are unavailable.")
    end
    local blinkKnown = C_SpellBook.IsSpellKnown(1953)
    local shimmerKnown = C_SpellBook.IsSpellKnown(212653)
    if Secret(blinkKnown) or Secret(shimmerKnown) then
        return Result(entry, "Restricted", "Learning state is restricted.")
    end
    if type(blinkKnown) ~= "boolean" or type(shimmerKnown) ~= "boolean" then
        return Result(entry, "Unknown", "Learning state has not been returned.")
    end
    if not blinkKnown and not shimmerKnown then
        return Result(entry, "Not learned", "Neither supported spell is currently learned.")
    end

    local effective = C_Spell.GetOverrideSpell(1953)
    if Secret(effective) then return Result(entry, "Restricted", "Spell replacement is restricted.") end
    if not Number(effective) then return Result(entry, "Unknown", "Spell replacement is unavailable.") end
    if effective ~= 1953 and effective ~= 212653 then
        return Result(entry, "Unsupported", "Blink has an unsupported active replacement.")
    end
    local spellID
    if shimmerKnown then
        if effective ~= 212653 then
            return Result(entry, "Unknown", "Learning and Blink replacement disagree; waiting for spell synchronization.")
        end
        local shimmer = C_Spell.GetOverrideSpell(212653)
        if Secret(shimmer) then return Result(entry, "Restricted", "Shimmer replacement is restricted.") end
        if not Number(shimmer) then return Result(entry, "Unknown", "Shimmer replacement is unavailable.") end
        if shimmer ~= 212653 then
            return Result(entry, "Unsupported", "Shimmer has an unsupported active replacement.")
        end
        spellID = 212653
    elseif blinkKnown and effective == 1953 then
        spellID = 1953
    else
        return Result(entry, "Unknown", "The active replacement is not yet confirmed as learned.")
    end

    if not C_Spell.GetSpellCharges or not C_Spell.GetSpellCooldown
        or not C_Spell.GetSpellChargeDuration or not C_Spell.GetSpellCooldownDuration then
        return Result(entry, "Unsupported", "Charge / cooldown duration APIs are unavailable.", spellID)
    end
    local charges = C_Spell.GetSpellCharges(spellID)
    if Secret(charges) then
        return Result(entry, "Restricted", "Charge capability is restricted.", spellID)
    end
    local duration, path, visibility
    if charges ~= nil then
        if type(charges) ~= "table" then
            return Result(entry, "Unknown", "Charge information is unavailable.", spellID)
        end
        if Secret(charges.maxCharges) then
            return Result(entry, "Restricted", "Charge capacity is restricted.", spellID)
        end
        if not Number(charges.maxCharges) or charges.maxCharges < 1
            or charges.maxCharges % 1 ~= 0 then
            return Result(entry, "Unknown", "Charge capacity is unavailable.", spellID)
        end
        if Secret(charges.isActive) then
            return Result(entry, "Restricted", "Recharge activity is restricted.", spellID)
        end
        if type(charges.isActive) ~= "boolean" then
            return Result(entry, "Unknown", "Recharge activity is unavailable.", spellID)
        end
        if Secret(charges.currentCharges) then
            -- A recharging SINGLE-slot pool is empty. Inactivity alone can
            -- also mean unavailable/zero duration, so do not claim Ready from
            -- it when the actual count cannot be read.
            if not charges.isActive then
                return Result(entry, "Unknown", "No active recharge; available charge count is restricted.",
                    spellID, "public recharge activity")
            end
            if charges.maxCharges == 1 then
                path = "native charge duration (single-slot recovery)"
            else
                -- For multiple slots, charging does not mean empty. The engine
                -- evaluates its ordinary total duration into display opacity;
                -- Lua cannot know whether that opacity is visible. Numeric time
                -- remains the independently obtained, already-running recharge.
                local curve, reason = ChargeVisibilityCurve(self)
                if not curve then
                    return Result(entry, "Restricted", reason, spellID, "blocked: native charge visibility")
                end
                local gate = C_Spell.GetSpellCooldownDuration(spellID, false)
                if not DurationHandle(gate) or not gate.EvaluateTotalDuration then
                    return Result(entry, "Restricted", "Native cooldown visibility duration is unavailable.", spellID,
                        "blocked: native charge visibility")
                end
                visibility = { duration = gate, curve = curve }
                path = "native charge timer + cooldown alpha (include GCD)"
            end
        else
            if not Number(charges.currentCharges) or charges.currentCharges < 0
                or charges.currentCharges > charges.maxCharges or charges.currentCharges % 1 ~= 0 then
                return Result(entry, "Unknown", "Available charge count is unavailable.", spellID)
            end
            if charges.currentCharges >= 1 then
                return Result(entry, "Ready", "At least one use is available.", spellID, "public charge count")
            end
        end
        if charges.isActive ~= true then
            return Result(entry, "Unknown", "No active recharge is available for zero charges.", spellID)
        end
        duration = C_Spell.GetSpellChargeDuration(spellID)
        path = path or "native charge duration"
    else
        -- nil charges can mean a non-charge spell. A valid cooldown record must
        -- also exist; nil is never interpreted as ready, or as zero charges.
        local cooldown = C_Spell.GetSpellCooldown(spellID)
        if Secret(cooldown) then
            return Result(entry, "Restricted", "Cooldown capability is restricted.", spellID)
        end
        if type(cooldown) ~= "table" then
            return Result(entry, "Unknown", "Cooldown information is unavailable.", spellID)
        end
        if Secret(cooldown.isEnabled) then
            return Result(entry, "Restricted", "Cooldown enable state is restricted.", spellID)
        end
        if cooldown.isEnabled ~= true then
            return Result(entry, "Unknown", "Cooldown is unavailable or on hold.", spellID)
        end
        -- Do not compare cooldown lengths or trust isOnGCD outside its event.
        -- The engine removes GCD in this duration on every synchronization path.
        duration = C_Spell.GetSpellCooldownDuration(spellID, true)
        path = "native cooldown duration (ignoreGCD)"
    end
    if Secret(duration) then
        return Result(entry, "Restricted", "Duration handle itself is restricted.", spellID, path)
    end
    if duration == nil then
        return Result(entry, "Unknown", "The real duration object is unavailable.", spellID, path)
    end
    if type(duration) ~= "userdata" and type(duration) ~= "table" then
        return Result(entry, "Unknown", "The duration object has an unexpected type.", spellID, path)
    end
    if not duration.IsZero then
        return Result(entry, "Unsupported", "DurationObject.IsZero is unavailable.", spellID, path)
    end
    local zero = duration:IsZero()
    if not Secret(zero) then
        if type(zero) ~= "boolean" then
            return Result(entry, "Unknown", "Duration activity is unavailable.", spellID, path)
        end
        if zero then
            if charges then
                return Result(entry, "Unknown", "Zero charges and zero recharge duration; waiting for synchronization.", spellID, path)
            end
            return Result(entry, "Ready", "No spell cooldown (GCD excluded).", spellID, path)
        end
    end
    if not TimerAPIsAvailable() then
        return Result(entry, "Unsupported", "Native DurationTextBinding / numeric formatter is unavailable.", spellID, path)
    end
    if charges then
        if visibility then
            return Result(entry, "Native tracking",
                "Native cooldown alpha controls visibility; Lua does not read the result. Client combat validation pending.",
                spellID, path, duration, visibility)
        end
        return Result(entry, "Depleted", "Zero uses confirmed; showing the next recharge only.", spellID, path, duration)
    end
    -- Native formatting handles opaque zero/expired durations without Lua
    -- branching, concatenating, measuring or reading the resulting text.
    return Result(entry, Secret(zero) and "Tracking" or "Depleted",
        Secret(zero) and "Timing is restricted; native display handles active/zero/expired state."
            or "Spell cooldown active (GCD excluded).", spellID, path, duration)
end
