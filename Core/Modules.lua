local _, addon = ...

-- A capability index, not a spell database. One native Data addon contains all
-- shipped definitions; its subdirectories are not separately load-on-demand.
local supportedClasses = { MAGE = true }
local classAdapters, noEntries = {}, {}
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

function addon:RegisterClassAdapter(class, adapter)
    if type(class) ~= "string" or not class:match("^[A-Z]+$") or type(adapter) ~= "table"
        or adapter.classToken ~= class then return false, "Invalid class adapter." end
    if classAdapters[class] then return false, "Class adapter already registered." end
    for _, method in ipairs({ "ActivateEntries", "DeactivateEntries", "GetMobilityEntry",
        "GetPreviewEntries", "ReadMobilityState" }) do
        if type(adapter[method]) ~= "function" then return false, "Incomplete class adapter: " .. method end
    end
    -- Registration stores definitions only. No entry factory, cooldown query,
    -- frame, timer, event registration or saved-class tree is created here.
    classAdapters[class] = adapter
    return true
end

function addon:RefreshActiveEntries()
    local class, specID = self:GetCurrentModuleIdentity()
    local selected = self.dataPackageLoaded and classAdapters[class] or nil
    local previous = self.activeClassAdapter
    local changed = previous ~= selected
    if changed and previous then previous:DeactivateEntries() end
    self.activeClassAdapter, self.activeAdapterClass = selected, selected and class or nil
    if selected then
        changed = selected:ActivateEntries(specID) or changed
        self.activeModuleClass, self.activeModuleSpec = class, specID
        self.activeMobilityEntry = selected:GetMobilityEntry()
        self.mobilityEntries, self.previewEntries = selected.mobilityEntries, selected.previewEntries
    else
        self.activeModuleClass, self.activeModuleSpec, self.activeMobilityEntry = nil, nil, nil
        self.mobilityEntries, self.previewEntries = nil, noEntries
    end
    return changed
end

local function CurrentAdapter(self)
    local class, spec = self:GetCurrentModuleIdentity()
    if class ~= self.activeAdapterClass or spec ~= self.activeModuleSpec then self:RefreshActiveEntries() end
    return self.activeClassAdapter
end

function addon:GetMobilityEntry()
    local adapter = CurrentAdapter(self)
    return adapter and adapter:GetMobilityEntry() or nil
end

function addon:GetPreviewEntries()
    local adapter = CurrentAdapter(self)
    return adapter and adapter:GetPreviewEntries() or noEntries
end

function addon:GetDefinedPreviewEntries() return self.previewEntries end

function addon:ReadMobilityState()
    local adapter = CurrentAdapter(self)
    if adapter then return adapter:ReadMobilityState() end
    return { status = "Unsupported", reason = self.classModuleReason or "No current class adapter is active.", path = "none" }
end

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
    if not supportedClasses[class] and not classAdapters[class] then
        self.classModuleReason = "No Mobility adapter is implemented for the current class."
        return false
    end
    if self.dataPackageLoaded and classAdapters[class] then
        self.classModuleReason = nil
        return true
    end
    if InCombatLockdown and InCombatLockdown() then
        self.classModuleReason = "Data package load deferred until combat ends."
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
    local loaded, reason = C_AddOns.LoadAddOn("CarGOUI_Data")
    if Public(loaded) and loaded and self.dataPackageLoaded and classAdapters[class] then
        self.classModuleReason = nil
        return true
    end
    self.classModuleReason = "Data package unavailable: "
        .. (Public(reason) and type(reason) == "string" and reason or "load did not complete")
    return false
end

local function ClientLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local _, complete = C_AddOns.IsAddOnLoaded(name)
        if Public(complete) and type(complete) == "boolean" then return complete end
    end
end

function addon:GetModuleLoadReport()
    local class, specID = self:GetCurrentModuleIdentity()
    local loaded, actualLoaded = self.dataPackageLoaded == true, ClientLoaded("CarGOUI_Data")
    local active = self.activeClassAdapter ~= nil and self.activeAdapterClass == class
    local registered = 0
    for _ in pairs(classAdapters) do registered = registered + 1 end
    return {
        currentClass = class, currentSpec = specID, module = "CarGOUI_Data",
        dataPackageLoaded = loaded, clientDataPackageLoaded = actualLoaded,
        registeredAdapters = registered, loadedClassFiles = loaded and 5 or 0,
        loadedDataFiles = loaded and 7 or 0,
        activeAdapterClass = active and self.activeAdapterClass or nil,
        retiredMageLoaded = ClientLoaded("CarGOUI_Mage") == true,
        retiredMageRegistered = type(_G.CarGOUI_Internal) == "table"
            and rawget(_G.CarGOUI_Internal, "mageModuleRegistered") == true,
        fileStatus = loaded and (active and "loaded; current adapter active" or "loaded; no current adapter active")
            or (actualLoaded and "loaded but registration incomplete" or "not loaded"),
        active = active, activeSpec = active and self.activeModuleSpec or nil,
        mobilityEntries = active and self.activeMobilityEntry and 1 or 0,
        previewEntries = active and #self.previewEntries or 0,
        configuration = "CarGOUIDB is shared: all previously saved class tables are restored by the core.",
        reason = self.classModuleReason,
    }
end
