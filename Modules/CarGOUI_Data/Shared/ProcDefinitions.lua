local _, data = ...

-- Static native geometry from the audited SpellActivationOverlay layout.
-- No graphic/aura state is read to build an external TEST guide.
local long, short = 256 * 0.8, 128 * 0.8
local sides = { Left = -1, Right = 1, LeftOutside = -1, RightOutside = 1 }
local function Region(region, source, definition)
    local location, scale = region.location, source.scale
    local side, outside = sides[location], location == "LeftOutside" or location == "RightOutside"
    local x, y, width, height = 0, 0, long, short
    local distance = long / 2 + short * scale / 2
    if side then
        x = side * (distance + (outside and short or 0)); width, height = short, long
    elseif location == "Top" then y = distance
    elseif location == "Bottom" then y = -distance
    elseif location == "Center" then width, height = long, long
    elseif location == "TopLeft" then x, y, width, height = -distance, distance, short, short
    elseif location == "TopRight" then x, y, width, height = distance, distance, short, short
    else error("Unsupported native Proc location: " .. tostring(location)) end
    region.kind, region.class, region.specID = "proc", definition.class, definition.specID
    region.region, region.nativeLocation, region.nativeScale = location:upper(), location, scale
    region.overlayID, region.auraID, region.sourceSpellID = source.overlayID, definition.auraID, source.overlayID
    region.anchor = { x = x, y = y }
    region.guide = { texture = source.textureID, width = width * scale, height = height * scale,
        flipH = side == 1, flipV = location == "Bottom" }
    region.sample = { timer = "8.0" }
    return region
end

function data:ProcDefinition(definition)
    local source = assert(definition.overlaySources and definition.overlaySources[1], "Missing native Proc source")
    definition.overlayID, definition.textureID = source.overlayID, source.textureID
    definition.locationTypeName, definition.scale = source.locationTypeName, source.scale
    definition.nativeEventOnly = definition.nativeEventOnly == true
    definition.preview = true
    definition.auditBootstrap = definition.nativeEventOnly and "native-event-required" or "exact-aura-only"
    for _, region in ipairs(definition.regions) do
        local selected = source
        if region.overlayIDs then
            for _, candidate in ipairs(definition.overlaySources) do
                if candidate.overlayID == region.overlayIDs[1] then selected = candidate; break end
            end
        end
        Region(region, selected, definition)
    end
    return definition
end

local function Known(id)
    local api = C_SpellBook and C_SpellBook.IsSpellKnown
    if not api then return nil end
    local value = api(id)
    if not issecretvalue or issecretvalue(value) or type(value) ~= "boolean" then return nil end
    return value
end

local function Eligible(definition)
    -- Only verified talent/learned-driver IDs belong here, never hidden aura
    -- IDs used as proxies for buff presence. Actual presence stays native.
    for _, id in ipairs(definition.requiresKnown or {}) do if Known(id) ~= true then return false end end
    if definition.requiresAnyKnown then
        local learned = false
        for _, id in ipairs(definition.requiresAnyKnown) do if Known(id) == true then learned = true; break end end
        if not learned then return false end
    end
    for _, id in ipairs(definition.excludesKnown or {}) do if Known(id) ~= false then return false end end
    return true
end

function data:RegisterProcFactory(classToken, factory)
    local adapter = assert(self.adapters[classToken], "Register the class adapter before its Proc factory")
    assert(type(factory) == "function" and not adapter.procCapability, "Duplicate or invalid Proc capability")
    adapter.procCapability = { version = 1 }
    adapter.procFactory = factory
    function adapter:InvalidateProcDefinitions()
        self.procDefinitions, self.procDefinitionSpec = nil, nil
    end
    function adapter:GetProcDefinitions(specID)
        if self.procDefinitionSpec ~= specID or not self.procDefinitions then
            self.procDefinitions, self.procDefinitionSpec = {}, specID
            -- Unknown/unselected identities never instantiate a spec factory.
            for _, definition in ipairs(specID and self.procFactory(specID) or {}) do
                assert(definition.class == classToken and definition.specID == specID, "Proc factory scope mismatch")
                if Eligible(definition) then self.procDefinitions[#self.procDefinitions + 1] = definition end
            end
        end
        return self.procDefinitions
    end
end
