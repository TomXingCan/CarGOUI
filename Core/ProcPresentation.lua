local _, addon = ...

-- Legacy per-region native takeover is retained for development regressions,
-- but no SavedVariables, import, UI, or slash setting can enable it in 1.0.1.
function addon:IsProcLegacyReplacementAllowed()
    return false
end

-- Explicit policy selection is scoped to the current class/spec. The legacy
-- region mode is never rewritten to opt a region into independent artwork.
function addon:GetProcPresentationPolicy(config)
    if not config then
        -- Transaction preflight must not normalize or migrate a saved scope.
        local class, spec = self:GetPlayerContext()
        local classes = self.db and self.db.classes
        local current = classes and classes[class]
        config = type(current) == "table" and type(current.proc) == "table" and current.proc[spec]
    end
    return type(config) == "table" and config.presentationPolicy == "independent" and "independent" or "replacement"
end

function addon:IsProcIndependentPolicy()
    -- Only ConfigureProc commits the live policy after old ownership cleanup.
    return self.procPresentationPolicy == "independent"
end

function addon:IsProcIndependentArtworkRegionEnabled(entry)
    if not self:GetCurrentProcRegion(entry) then return false end
    local config = self:GetProcConfig()
    local region = config and config.regions[entry.id]
    return type(region) == "table" and region.independentArtworkEnabled == true
end

function addon:IsProcArtworkEditable(entry)
    if self:GetProcPresentationPolicy() == "independent" then
        return self:IsProcIndependentArtworkRegionEnabled(entry)
    end
    return self:IsProcLegacyReplacementAllowed() and self:GetProcRegionAppearance(entry).mode == "custom"
end

function addon:NotifyProcLegacyArtworkDisabled(config)
    if self.procLegacyArtworkNotice or self:IsProcLegacyReplacementAllowed()
        or self:GetProcPresentationPolicy(config) == "independent" then return end
    for _, region in pairs(config and config.regions or {}) do
        local appearance = type(region) == "table" and region.appearance
        if type(appearance) == "table" and (appearance.mode == "custom" or appearance.mode == "timer") then
            self.procLegacyArtworkNotice = true
            local ok = pcall(function()
                self:Print(self:Text("Native artwork stays under Blizzard control. CUI adds timers only. Saved Custom and Timer-only overrides are preserved but inactive; use Independent CUI for custom artwork."))
            end)
            if not ok then self:RecordProcFailure("preferences") end
            return
        end
    end
end

local function Public(value)
    return issecretvalue and not issecretvalue(value)
end

function addon:GetProcIndependentNativeMuteState()
    local api = C_CVar
    local boolean = api and api.GetCVarBool or GetCVarBool
    local number = api and api.GetCVar or GetCVar
    if type(boolean) ~= "function" or type(number) ~= "function" then
        return false, "native-preferences-unavailable"
    end
    local display, opacity = boolean("displaySpellActivationOverlays"), number("spellActivationOverlayOpacity")
    if not Public(display) or type(display) ~= "boolean" or not Public(opacity)
        or (type(opacity) ~= "number" and type(opacity) ~= "string") then
        return false, "native-preferences-unavailable"
    end
    opacity = tonumber(opacity)
    if not opacity or opacity ~= opacity or opacity < 0 or opacity > 1 then
        return false, "native-preferences-unavailable"
    end
    if display or opacity ~= 0 then return false, "native-mute-required" end
    return true, "ready"
end

function addon:GetProcIndependentArtworkStatus(entry)
    local config = self:GetProcConfig()
    if not config or not self:IsProcIndependentPolicy() then return false, "policy-unavailable" end
    if config.independentArtworkEnabled == false then return false, "artwork-disabled" end
    if not self:IsProcIndependentArtworkRegionEnabled(entry) then return false, "region-disabled" end
    return self:GetProcIndependentNativeMuteState()
end

-- A fixed set of session notice categories bounds both storage and output.
-- Preference mismatch and missing public RGB are not internal failures.
function addon:NotifyProcIndependentArtwork(reason)
    if reason == "region-disabled" or reason == "ready" then return end
    local category = reason == "native-mute-required" or reason == "native-preferences-unavailable"
    category = category and "preferences" or (reason == "artwork-disabled" and "disabled"
        or reason == "policy-change" and "policy" or reason == "stopped" and "stopped" or "unavailable")
    self.procIndependentNotices = self.procIndependentNotices or {}
    if self.procIndependentNotices[category] then return end
    self.procIndependentNotices[category] = true
    local ok = pcall(function()
        if category == "preferences" then
            self:Print(self:Text("Independent CUI artwork is paused because Blizzard Spell Alert settings are not both zero. Timer settings and artwork preferences are preserved."))
        elseif category == "policy" or category == "stopped" then
            self:Print(self:Text("Blizzard Spell Alert Opacity is still a manual setting. Restore it in the game settings if you want native alerts after switching or disabling Proc."))
        else
            self:Print(self:Text("Independent CUI artwork is stopped or unavailable. Blizzard Spell Alert Opacity is unchanged; restore it manually to see native alerts."))
        end
    end)
    -- Chat output must never interrupt resource shutdown or recovery.
    if not ok then self:RecordProcFailure("preferences") end
end

function addon:PrepareProcPresentationTransition(nextPolicy, force)
    if nextPolicy ~= "replacement" and nextPolicy ~= "independent" then
        return false, self:Text("Unknown Proc presentation strategy.")
    end
    if not force and nextPolicy == self:GetProcPresentationPolicy() then return true end
    local function Cleanup()
        if self.CancelProcColorPicker then self:CancelProcColorPicker() end
        if self.previewFrames and self.StopProcPreview and self:StopProcPreview() == false then
            error("Proc presentation preview cleanup incomplete")
        end
        if self.StopProcArtwork and self:StopProcArtwork() == false then
            error("Proc presentation artwork cleanup incomplete")
        end
        if next(self.procSuppressedOverlays or {}) ~= nil then
            error("Proc presentation retains unresolved native ownership")
        end
        -- Old policy state cannot stand in for a new first graphical event.
        -- Native timer bootstrap remains a separate, unchanged contract.
        self.procOverlayStates = {}
        return true
    end
    local ok, clean
    if self.IsProcQuarantined and self:IsProcQuarantined() then
        ok, clean = pcall(Cleanup)
    elseif self.RunProcSafe then
        ok, clean = self:RunProcSafe("preferences", Cleanup)
    else ok, clean = pcall(Cleanup) end
    if not ok or clean ~= true then
        return false, self:Text("Proc presentation could not change because old artwork cleanup is incomplete. Retry or reload before switching.")
    end
    if self:IsProcIndependentPolicy() and nextPolicy ~= "independent" then
        self:NotifyProcIndependentArtwork("policy-change")
    end
    return true
end
