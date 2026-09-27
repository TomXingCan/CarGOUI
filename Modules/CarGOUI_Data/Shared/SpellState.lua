local _, data = ...

-- Learning, replacements and the current activity set are selected by the
-- class adapter. This engine receives one already-selected, public spell ID.
-- It never reads raw timing, cast history, target, resource or usability state.
local function Secret(value)
    return issecretvalue(value)
end

local function Number(value)
    return not Secret(value) and type(value) == "number"
        and value == value and value > -math.huge and value < math.huge
end

local function Handle(value)
    return not Secret(value) and (type(value) == "userdata" or type(value) == "table")
end

local function Result(entry, definition, status, reason, path, duration, visibility)
    return { entry = entry, status = status, reason = reason or "",
        spellID = definition and definition.spellID,
        spellName = definition and definition.spellName,
        path = path or "none", duration = duration, visibility = visibility }
end

local function TimerAPIsAvailable()
    return C_DurationUtil and C_DurationUtil.CreateDurationTextBinding
        and C_StringUtil and C_StringUtil.CreateNumericRuleFormatter
        and Enum and Enum.DurationTextBindingProperty and Enum.DurationTimeModifier
        and Enum.NumericRuleFormatRounding
end

-- This is an opt-in, per-ability classifier, not a universal charge heuristic.
-- A definition must document its ordinary/category inter-use envelope. GCD is
-- removed natively; the charge timer is a separate already-running object.
local function ChargeVisibilityCurve(self, definition)
    local rule = definition.chargeVisibility
    if type(rule) ~= "table" then
        return nil, "Restricted multi-charge visibility has no audited per-ability rule."
    end
    if not Number(rule.baseCooldownMS) or rule.baseCooldownMS < 0
        or not Number(rule.baseGCDMS) or rule.baseGCDMS < 0
        or not Number(rule.boundaryMS) or rule.boundaryMS < rule.baseCooldownMS
        or rule.ignoreGCD ~= true or type(rule.audit) ~= "string" or rule.audit == "" then
        return nil, "The per-ability visibility audit is incomplete."
    end
    if not C_CurveUtil or not C_CurveUtil.CreateCurve or not GetSpellBaseCooldown
        or not Enum or not Enum.LuaCurveType or Enum.LuaCurveType.Step == nil
        or not Enum.DurationTimeModifier or Enum.DurationTimeModifier.BaseTime == nil then
        return nil, "Native curve / public base-cooldown metadata API is unavailable."
    end
    local cooldown, gcd = GetSpellBaseCooldown(definition.spellID)
    if not Number(cooldown) or not Number(gcd) then
        return nil, "Base-cooldown metadata is unavailable or restricted."
    end
    if cooldown ~= rule.baseCooldownMS or gcd ~= rule.baseGCDMS then
        return nil, "Base-cooldown metadata differs from this ability's audited values."
    end
    self.abilityVisibilityCurves = self.abilityVisibilityCurves or {}
    local cached = self.abilityVisibilityCurves[definition.spellID]
    if not cached or cached.boundary ~= rule.boundaryMS then
        local curve = C_CurveUtil.CreateCurve()
        if not Handle(curve) or not curve.SetType or not curve.AddPoint then
            return nil, "Native step-curve construction is unavailable."
        end
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        -- Next millisecond excludes the exact audited inter-use boundary.
        -- This value never supplies, estimates or restarts a recharge timer.
        curve:AddPoint((rule.boundaryMS + 1) / 1000, 1)
        cached = { boundary = rule.boundaryMS, curve = curve }
        self.abilityVisibilityCurves[definition.spellID] = cached
    end
    return cached.curve
end

function data:ClearAbilityStateCache()
    self.abilityVisibilityCurves = nil
end

function data:ReadAbilityState(entry, definition)
    if not issecretvalue then
        return Result(entry, nil, "Unsupported", "Secret-value detection API is unavailable.")
    end
    if type(definition) ~= "table" or not Number(definition.spellID)
        or definition.spellID < 1 or definition.spellID % 1 ~= 0
        or Secret(definition.spellName) or type(definition.spellName) ~= "string"
        or definition.spellName == "" then
        return Result(entry, nil, "Unknown", "A public effective spell definition is unavailable.")
    end
    if type(definition.unsupportedReason) == "string" and definition.unsupportedReason ~= "" then
        return Result(entry, definition, "Unsupported", definition.unsupportedReason)
    end
    if not C_Spell or not C_Spell.GetSpellCharges or not C_Spell.GetSpellCooldown
        or not C_Spell.GetSpellChargeDuration or not C_Spell.GetSpellCooldownDuration then
        return Result(entry, definition, "Unsupported", "Charge / cooldown duration APIs are unavailable.")
    end

    local spellID = definition.spellID
    local charges = C_Spell.GetSpellCharges(spellID)
    if Secret(charges) then
        return Result(entry, definition, "Restricted", "Charge capability is restricted.")
    end
    local duration, path, visibility
    if charges ~= nil then
        if type(charges) ~= "table" then
            return Result(entry, definition, "Unknown", "Charge information is unavailable.")
        end
        if Secret(charges.maxCharges) or Secret(charges.isActive) then
            return Result(entry, definition, "Restricted", "Charge capacity or activity is restricted.")
        end
        if not Number(charges.maxCharges) or charges.maxCharges < 1
            or charges.maxCharges % 1 ~= 0 or type(charges.isActive) ~= "boolean" then
            return Result(entry, definition, "Unknown", "Charge capacity or activity is unavailable.")
        end
        if Secret(charges.currentCharges) then
            if not charges.isActive then
                return Result(entry, definition, "Unknown",
                    "No active recharge; available charge count is restricted.", "public recharge activity")
            end
            if charges.maxCharges == 1 then
                path = "native charge duration (single-slot recovery)"
            else
                local curve, reason = ChargeVisibilityCurve(self, definition)
                if not curve then
                    return Result(entry, definition, "Restricted", reason, "blocked: native charge visibility")
                end
                local gate = C_Spell.GetSpellCooldownDuration(spellID, true)
                if not Handle(gate) or not gate.EvaluateTotalDuration then
                    return Result(entry, definition, "Restricted",
                        "Native cooldown visibility duration is unavailable.", "blocked: native charge visibility")
                end
                visibility = { duration = gate, curve = curve }
                path = "native charge timer + audited cooldown alpha (ignoreGCD)"
            end
        else
            if not Number(charges.currentCharges) or charges.currentCharges < 0
                or charges.currentCharges > charges.maxCharges or charges.currentCharges % 1 ~= 0 then
                return Result(entry, definition, "Unknown", "Available charge count is unavailable.")
            end
            if charges.currentCharges >= 1 then
                return Result(entry, definition, "Ready", "At least one use is available.", "public charge count")
            end
        end
        if not charges.isActive then
            return Result(entry, definition, "Unknown", "No active recharge is available for zero charges.")
        end
        duration = C_Spell.GetSpellChargeDuration(spellID)
        path = path or "native charge duration"
    else
        local cooldown = C_Spell.GetSpellCooldown(spellID)
        if Secret(cooldown) then
            return Result(entry, definition, "Restricted", "Cooldown capability is restricted.")
        end
        if type(cooldown) ~= "table" then
            return Result(entry, definition, "Unknown", "Cooldown information is unavailable.")
        end
        if Secret(cooldown.isEnabled) then
            return Result(entry, definition, "Restricted", "Cooldown enable state is restricted.")
        end
        if cooldown.isEnabled ~= true then
            return Result(entry, definition, "Unknown", "Cooldown is unavailable or on hold.")
        end
        -- isOnGCD is only valid directly inside a cooldown event. Native GCD
        -- exclusion remains valid for coalesced, login and talent refreshes.
        duration = C_Spell.GetSpellCooldownDuration(spellID, true)
        path = "native cooldown duration (ignoreGCD)"
    end

    if Secret(duration) then
        return Result(entry, definition, "Restricted", "Duration handle itself is restricted.", path)
    end
    if not Handle(duration) then
        return Result(entry, definition, "Unknown", "The real duration object is unavailable.", path)
    end
    if not duration.IsZero then
        return Result(entry, definition, "Unsupported", "DurationObject.IsZero is unavailable.", path)
    end
    local zero = duration:IsZero()
    local restricted = Secret(zero)
    if not restricted then
        if type(zero) ~= "boolean" then
            return Result(entry, definition, "Unknown", "Duration activity is unavailable.", path)
        end
        if zero then
            if charges then
                return Result(entry, definition, "Unknown",
                    "Zero charges and zero recharge duration; waiting for synchronization.", path)
            end
            return Result(entry, definition, "Ready", "No spell cooldown (GCD excluded).", path)
        end
    end
    if not TimerAPIsAvailable() then
        return Result(entry, definition, "Unsupported",
            "Native DurationTextBinding / numeric formatter is unavailable.", path)
    end
    if visibility then
        return Result(entry, definition, "Native tracking",
            "Per-ability native cooldown alpha controls visibility; Lua does not read the result. Client validation pending.",
            path, duration, visibility)
    end
    if charges then
        return Result(entry, definition, "Depleted", "Zero uses confirmed; showing the next recharge only.", path, duration)
    end
    return Result(entry, definition, restricted and "Tracking" or "Depleted",
        restricted and "Timing is restricted; native display handles active/zero/expired state."
            or "Spell cooldown active (GCD excluded).", path, duration)
end
