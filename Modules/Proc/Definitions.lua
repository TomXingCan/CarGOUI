local _, addon = ...

local locations = { LeftRight = { "Left", "Right" }, TopBottom = { "Top", "Bottom" },
    LeftRightOutside = { "LeftOutside", "RightOutside" }, Left = { "Left" }, Right = { "Right" },
    LeftOutside = { "LeftOutside" }, RightOutside = { "RightOutside" }, Top = { "Top" },
    Bottom = { "Bottom" }, Center = { "Center" }, TopLeft = { "TopLeft" }, TopRight = { "TopRight" } }
addon.procLocations = locations

local function ID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0
end
local function Key(value) return type(value) == "string" and value:match("^[a-z0-9_]+$") end
local function Contains(values, value)
    if not values then return true end
    for _, candidate in ipairs(values) do if candidate == value then return true end end
    return false
end

-- Compile only the current catalog, on identity/talent changes. These are
-- static audited definitions, never game Aura payloads. Reject conflicts
-- instead of silently overwriting an owner or reusing a region/provider.
function addon:CompileProcDefinitions(definitions, class, spec)
    local byOverlay, byRegion, definitionsSeen = {}, {}, {}
    for _, definition in ipairs(definitions) do
        if not Key(definition.id) or definitionsSeen[definition.id] or definition.class ~= class
            or definition.specID ~= spec or not ID(definition.auraID)
            or type(definition.regions) ~= "table" or #definition.regions == 0 then
            return nil, "Invalid, duplicated or out-of-scope Proc definition."
        end
        definitionsSeen[definition.id] = true
        local regions = {}
        for _, region in ipairs(definition.regions) do
            if not Key(region.id) or byRegion[region.id] or not locations[region.location]
                or #locations[region.location] ~= 1 or type(region.label) ~= "string" then
                return nil, "Invalid or duplicated stable Proc region."
            end
            byRegion[region.id], regions[region.id] = definition, region
        end
        local normalized, sourcesSeen, covered = {}, {}, {}
        for _, source in ipairs(definition.overlaySources or { definition }) do
            local location = source.locationTypeName or definition.locationTypeName
            local scale = source.scale or definition.scale
            if not ID(source.overlayID) or not ID(source.textureID) or not locations[location]
                or type(scale) ~= "number" or scale <= 0 or scale > 10 then
                return nil, "Invalid Proc graphical source metadata."
            end
            local key = source.overlayID .. ":" .. source.textureID .. ":" .. location
            if sourcesSeen[key] then return nil, "Duplicate Proc graphical source." end
            sourcesSeen[key] = true
            local prepared = { overlayID = source.overlayID, textureID = source.textureID,
                locationTypeName = location, scale = scale, stateKey = key,
                shared = source.shared == true, regions = {} }
            for _, region in ipairs(definition.regions) do
                if Contains(locations[location], region.location) and Contains(source ~= definition and source.regions or nil, region.location)
                    and Contains(region.overlayIDs, source.overlayID) then
                    prepared.regions[#prepared.regions + 1] = region
                    covered[region.id] = true
                end
            end
            if #prepared.regions == 0 then return nil, "Proc source has no matching configured region." end
            local bindings = byOverlay[source.overlayID] or {}
            for _, binding in ipairs(bindings) do
                if binding.definition ~= definition and (not binding.source.shared or not prepared.shared) then
                    return nil, "Shared Proc owner needs an explicit audited one-to-many declaration."
                end
            end
            bindings[#bindings + 1] = { definition = definition, source = prepared }
            byOverlay[source.overlayID] = bindings
            normalized[#normalized + 1] = prepared
        end
        for id in pairs(regions) do
            if not covered[id] then return nil, "Proc region has no matching native graphic." end
        end
        definition.nativeSources = normalized
    end
    return { byOverlay = byOverlay, byRegion = byRegion }
end
