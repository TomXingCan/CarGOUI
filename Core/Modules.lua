local _, addon = ...

-- This is an index, not a class database. Only the current supported class's
-- native Load-on-Demand addon is requested. New classes are not implemented.
local classModules = { MAGE = "CarGOUI_Mage" }
local noEntries = {}
addon.previewEntries = noEntries

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

function addon:GetCurrentModuleIdentity()
    if self.GetPlayerContext then return self:GetPlayerContext() end
    local _, class = UnitClass("player")
    if not Public(class) or type(class) ~= "string" then return nil, nil end
    local api = C_SpecializationInfo
    local getSpec = api and api.GetSpecialization or GetSpecialization
    local getInfo = api and api.GetSpecializationInfo or GetSpecializationInfo
    local index = getSpec and getSpec()
    if not Public(index) then return class, nil end
    local specID = index and getInfo and getInfo(index)
    if not Public(specID) or type(specID) ~= "number" or specID <= 0 or specID % 1 ~= 0 then return class, nil end
    return class, specID
end

function addon:GetMobilityEntry() return nil end
function addon:GetPreviewEntries() return noEntries end
function addon:GetDefinedPreviewEntries() return self.previewEntries end
local function UnavailableMobilityState(self)
    return { status = "Unsupported", reason = self.classModuleReason or "No current class adapter is loaded.",
        path = "none" }
end
addon.ReadMobilityState = UnavailableMobilityState

local function OnDeferredLoad(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED", OnDeferredLoad)
    self.classModuleDeferred = false
    if self:EnsureCurrentClassModule() then
        self:RefreshActiveEntries()
        if self.OnClassModuleAvailable then
            self:OnClassModuleAvailable()
        elseif self.initialized and self.ApplySettings then
            self:ApplySettings()
        end
    end
end

function addon:EnsureCurrentClassModule()
    local class = self:GetCurrentModuleIdentity()
    local module = class and classModules[class]
    if not module then
        self.classModuleReason = "No Mobility adapter is implemented for the current class."
        return false
    end
    if self.mageModuleLoaded and self.ActivateMageEntries then
        self.classModuleReason = nil
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        self.classModuleReason = "Current class module load deferred until combat ends."
        if not self.classModuleDeferred then
            self.classModuleDeferred = true
            self:RegisterEvent("PLAYER_REGEN_ENABLED", OnDeferredLoad)
        end
        return false
    end
    if not C_AddOns or not C_AddOns.LoadAddOn then
        self.classModuleReason = "C_AddOns.LoadAddOn is unavailable."
        return false
    end
    local loaded, reason = C_AddOns.LoadAddOn(module)
    if Public(loaded) and loaded and self.ActivateMageEntries and self.mageModuleRegistered
        and self.ReadMobilityState ~= UnavailableMobilityState then
        self.mageModuleLoaded = true
        self.classModuleReason = nil
        return true
    end
    self.classModuleReason = "Current class module unavailable: "
        .. (Public(reason) and type(reason) == "string" and reason or "load did not complete")
    return false
end

function addon:RefreshActiveEntries()
    local class, specID = self:GetCurrentModuleIdentity()
    if class == "MAGE" and self.mageModuleLoaded and self.ActivateMageEntries then
        return self:ActivateMageEntries(specID)
    end
    local changed = self.activeModuleClass ~= nil or self.activeModuleSpec ~= nil
        or self.activeMobilityEntry ~= nil
    self.activeModuleClass, self.activeModuleSpec, self.activeMobilityEntry = nil, nil, nil
    self.mobilityEntries, self.previewEntries = nil, noEntries
    return changed
end

function addon:GetModuleLoadReport()
    local class, specID = self:GetCurrentModuleIdentity()
    local module = class and classModules[class]
    local loaded = self.mageModuleLoaded == true
    local active = class == "MAGE" and self.activeModuleClass == class
    local actualLoaded
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local _, complete = C_AddOns.IsAddOnLoaded("CarGOUI_Mage")
        if Public(complete) and type(complete) == "boolean" then actualLoaded = complete end
    end
    return {
        currentClass = class, currentSpec = specID, module = module,
        mageLoaded = loaded, clientMageLoaded = actualLoaded,
        fileStatus = loaded and (active and "loaded and active" or "loaded but inactive")
            or (actualLoaded and "loaded but adapter incomplete" or "not loaded"),
        active = active, activeSpec = active and self.activeModuleSpec or nil,
        mobilityEntries = active and self.activeMobilityEntry and 1 or 0,
        previewEntries = active and #self.previewEntries or 0,
        configuration = "CarGOUIDB is shared: all previously saved class tables are loaded by the core.",
        reason = self.classModuleReason,
    }
end
