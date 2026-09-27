local _, addon = ...

function addon:Initialize()
    if self.initialized then
        return
    end
    self:EnsureCurrentClassModule()
    self:RefreshActiveEntries()
    self:InitializeDatabase()
    self.configurationClass, self.configurationSpec = self:GetPlayerContext()
    self:RegisterSlashCommands()
    self.initialized = true
    self:InitializeLauncher()
end

function addon:Enable()
    if self.enabled or not self.initialized then
        return
    end
    self:CreateDisplay()
    self:RefreshReminderClassColor()
    self:ApplySettings()
    self.enabled = true
    self:Print("Alpha 0.1 loaded. Type /cui for Mobility settings and separate Test Mode.")
end

local function OnPlayerLogin(self)
    self:UnregisterEvent("PLAYER_LOGIN", OnPlayerLogin)
    self:Initialize()
    self:Enable()
end

local function OnAddonLoaded(self, _, loadedAddon)
    if loadedAddon ~= self.name then
        return
    end

    -- SavedVariables are restored here, but wait for player identity and known
    -- skills before resolving legacy Mage scope during normal login.
    self:UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
    if IsLoggedIn() then
        self:Initialize()
        self:Enable()
    else
        self:RegisterEvent("PLAYER_LOGIN", OnPlayerLogin)
    end
end

addon:RegisterEvent("ADDON_LOADED", OnAddonLoaded)

function addon:OnClassModuleAvailable()
    if not self.initialized then return end
    if self.CancelProcColorPicker then self:CancelProcColorPicker() end
    self:StopPreview(true)
    if self.StopProc then self:StopProc() end
    if self.StopFreeMove then self:StopFreeMove() end
    self:HideLiveMobility()
    self.mobilityState, self.mobilityStates = nil, nil
    self:RefreshActiveEntries()
    self:RefreshConfigurationContext()
    self.configurationClass, self.configurationSpec = self:GetPlayerContext()
    self:ApplySettings()
    if self.RefreshOptions then self:RefreshOptions() end
end

local function OnConfigurationContextChanged(self, event, unit)
    if not self.initialized then return end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if issecretvalue and issecretvalue(unit) then return end
        if unit and unit ~= "player" then return end
    end
    local class, spec = self:GetPlayerContext()
    if class == self.configurationClass and spec == self.configurationSpec then return end
    if self.CancelProcColorPicker then self:CancelProcColorPicker() end
    -- Tear down temporary state before switching catalogs. The saved class
    -- Mobility record survives all spec changes; cached frames remain reusable.
    self:StopPreview(true)
    if self.StopProc then self:StopProc() end
    if self.StopFreeMove then self:StopFreeMove() end
    self:HideLiveMobility()
    self.mobilityState, self.mobilityStates = nil, nil
    self:EnsureCurrentClassModule()
    self:OnClassModuleAvailable()
end
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", OnConfigurationContextChanged)
addon:RegisterEvent("PLAYER_ENTERING_WORLD", OnConfigurationContextChanged)

-- Style recovery is not tied to the Mage module's enabled state. This also
-- updates any reused Preview/future reminder frames after entering the world.
addon:RegisterEvent("PLAYER_ENTERING_WORLD", function(self)
    self:RefreshReminderClassColor()
end)
