local _, addon = ...

-- Free move is native aura presence, independent of the ordinary cooldown
-- states. It never clears, edits, or restarts another Mobility reminder.
function addon:GetFreeMoveEntry()
    local class = self:GetCurrentModuleIdentity()
    if not class or not self.dataPackageLoaded or not self.GetFreeMoveDefinition then
        self.freeMoveEntry = nil
        return
    end
    if not self.freeMoveEntry or self.freeMoveEntry.class ~= class then
        self.freeMoveEntry = self:GetFreeMoveDefinition(class)
    end
    return self.freeMoveEntry
end

function addon:GetFreeMovePreviewEntry()
    return self:GetFreeMoveEntry()
end

function addon:StopFreeMove()
    self.freeMoveTracking = false
    for _, frame in pairs(self.reminderFrames and self.reminderFrames.nativeAura or {}) do
        if frame.reminderEntry and frame.reminderEntry.freeMove then
            self:DisableAuraReminder(frame)
        end
    end
end

function addon:RenderFreeMoveState()
    if not self.freeMoveTracking then return end
    local entry = self:GetFreeMoveEntry()
    if not entry or not self:GetMobilityConfig().enabled then
        self:StopFreeMove()
        return
    end
    local frame, reason = self:AcquireAuraReminder(entry, entry.auraID, self:Text("Free move"))
    if not frame then
        self:StopFreeMove()
        self.freeMoveStatusReason = reason
        return
    end
    for _, previous in pairs(self.reminderFrames.nativeAura) do
        if previous ~= frame and previous.reminderEntry and previous.reminderEntry.freeMove then
            self:DisableAuraReminder(previous)
        end
    end
    local preview = self.previewState
    local suppressed = preview and preview.mode ~= "off"
        and (preview.mode == "all" or preview.entryId == entry.id)
    frame.auraHandle:SetEnabled(true)
    frame:SetAlpha(suppressed and 0 or 1)
    frame:Show()
end

function addon:ConfigureFreeMove()
    local entry = self:GetFreeMoveEntry()
    local supported, reason = self:CanUseNativeAuraSlots()
    if not entry or not self:GetMobilityConfig().enabled or not supported then
        self:StopFreeMove()
        self.freeMoveStatusReason = not supported and reason
            or (not entry and "No Time Spiral receiver is configured for the current class."
                or "Current class Mobility is disabled.")
        return
    end
    self.freeMoveTracking = true
    self.freeMoveStatusReason = "Native Time Spiral receiver tracking; text only. Lua does not read aura presence."
    self:RenderFreeMoveState()
end

function addon:GetFreeMoveDiagnostics()
    local entry = self.freeMoveEntry
    return "Free move: " .. (self.freeMoveTracking and "Native tracking" or "inactive")
        .. "; receiver aura=" .. (entry and entry.auraID or "unavailable")
        .. "; requested native slots=" .. (self.freeMoveTracking and 1 or 0)
        .. "\n" .. (self.freeMoveStatusReason or "Not initialized.")
end
