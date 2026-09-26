local _, addon = ...

function addon:Initialize()
    if self.initialized then
        return
    end
    self:InitializeDatabase()
    self:RegisterSlashCommands()
    self.initialized = true
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
    self:Enable()
end

local function OnAddonLoaded(self, _, loadedAddon)
    if loadedAddon ~= self.name then
        return
    end

    -- WoW has restored this addon's SavedVariables before ADDON_LOADED.
    self:Initialize()
    self:UnregisterEvent("ADDON_LOADED", OnAddonLoaded)
    if IsLoggedIn() then
        self:Enable()
    else
        self:RegisterEvent("PLAYER_LOGIN", OnPlayerLogin)
    end
end

addon:RegisterEvent("ADDON_LOADED", OnAddonLoaded)

-- Style recovery is not tied to the Mage module's enabled state. This also
-- updates any reused Preview/future reminder frames after entering the world.
addon:RegisterEvent("PLAYER_ENTERING_WORLD", function(self)
    self:RefreshReminderClassColor()
end)
