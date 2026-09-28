local _, addon = ...

-- Presentation only. These defaults never populate an old saved region and
-- never change its timer position, timer color, or specialization typography.
addon.procAppearanceLimits = {
    desaturation = { min = 0, max = 1 }, alpha = { min = 0, max = 1 },
    scale = { min = .25, max = 3 }, width = { min = .25, max = 3 },
    height = { min = .25, max = 3 }, rotation = { min = -180, max = 180 },
    offset = { min = -1000, max = 1000 }, speed = { min = .25, max = 3 },
    intensity = { min = 0, max = 1 },
}
addon.procAppearanceEnums = {
    mode = { native = true, custom = true, timer = true },
    entrance = { none = true, fade = true, scale = true, pulse = true },
    active = { none = true, pulse = true, breathe = true, rotate = true },
    exit = { none = true, fade = true, scale = true },
    direction = { clockwise = true, counterclockwise = true },
}

local function Public(value) return not issecretvalue or not issecretvalue(value) end
local function Finite(value, range)
    return Public(value) and type(value) == "number" and value == value
        and value >= range.min and value <= range.max
end
local function Plain(value)
    return Public(value) and type(value) == "table" and getmetatable(value) == nil
end
local function RGB(value)
    if not Plain(value) then return false end
    for key in pairs(value) do if key ~= "r" and key ~= "g" and key ~= "b" then return false end end
    for _, key in ipairs({ "r", "g", "b" }) do
        if not Finite(value[key], { min = 0, max = 1 }) then return false end
    end
    return true
end
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = Copy(item) end
    return result
end

function addon:NewProcAppearance()
    return { mode = "native", desaturation = 0, alpha = 1, scale = 1,
        width = 1, height = 1, rotation = 0, mirrorX = false, mirrorY = false,
        offset = { x = 0, y = 0 },
        animation = { entrance = "none", active = "none", exit = "none",
            speed = 1, intensity = .2, direction = "clockwise" } }
end

-- Sparse saved objects are valid. false is a UI patch sentinel only; import
-- and export use omission for the optional audited asset and public RGB.
function addon:ValidateProcAppearance(value, patch)
    if not Plain(value) then return false, self:Text("Artwork settings must be a plain object.") end
    for key, item in pairs(value) do
        if not Public(key) or not Public(item) or type(key) ~= "string" then
            return false, self:Text("Artwork settings must contain public values.")
        end
        if key == "mode" then
            if type(item) ~= "string" or not self.procAppearanceEnums.mode[item] then return false, self:Text("Unknown artwork display mode.") end
        elseif key == "assetKey" then
            if not (patch and item == false) and (type(item) ~= "string" or not self:GetProcAsset(item)) then
                return false, self:Text("Choose an audited artwork catalog entry.")
            end
        elseif key == "artColor" then
            if not (patch and item == false) and not RGB(item) then return false, self:Text("Artwork color must contain finite RGB values from 0 to 1.") end
        elseif key == "mirrorX" or key == "mirrorY" then
            if type(item) ~= "boolean" then return false, self:Text("Artwork mirrors must be true or false.") end
        elseif key == "offset" then
            if not Plain(item) then return false, self:Text("Artwork offset must be an object.") end
            for axis, coordinate in pairs(item) do
                if (axis ~= "x" and axis ~= "y") or not Finite(coordinate, self.procAppearanceLimits.offset) then
                    return false, self:Text("Artwork offsets must be finite values from -1000 to 1000.")
                end
            end
        elseif key == "animation" then
            if not Plain(item) then return false, self:Text("Artwork animation must be an object.") end
            for setting, choice in pairs(item) do
                local options = self.procAppearanceEnums[setting]
                if setting == "speed" or setting == "intensity" then
                    if not Finite(choice, self.procAppearanceLimits[setting]) then return false, self:Text("Artwork animation value is outside its finite bounds.") end
                elseif setting == "entrance" or setting == "active" or setting == "exit" or setting == "direction" then
                    if not Public(choice) or type(choice) ~= "string" or not options[choice] then return false, self:Text("Unknown artwork animation choice.") end
                else return false, self:Text("Unknown artwork animation field.") end
            end
        elseif key == "desaturation" or key == "alpha" or key == "scale" or key == "width" or key == "height" or key == "rotation" then
            if not Finite(item, self.procAppearanceLimits[key]) then return false, self:Text("Artwork transform is outside its finite bounds.") end
        else return false, self:Text("Unknown artwork setting: ") .. key end
    end
    return true
end

function addon:CopyProcAppearance(value)
    if value ~= nil and self:ValidateProcAppearance(value) then return Copy(value) end
end

function addon:MergeProcAppearance(value, patch)
    local result = self:CopyProcAppearance(value) or {}
    for key, item in pairs(patch) do
        if (key == "assetKey" or key == "artColor") and item == false then result[key] = nil
        elseif key == "offset" or key == "animation" then
            result[key] = result[key] or {}
            for field, choice in pairs(item) do result[key][field] = choice end
        else result[key] = Copy(item) end
    end
    return result
end

function addon:NormalizeProcAppearance(value)
    local defaults = self:NewProcAppearance()
    if value ~= nil and self:ValidateProcAppearance(value) then return self:MergeProcAppearance(defaults, value) end
    return defaults
end

-- Both TEST and live rendering use this resolver. It reads only explicit
-- public SHOW data and audited metadata, never a native texture or aura.
-- Dimensions include the asset's recommended scale; user transforms remain
-- separate. Anchors always belong to the current region's native artwork.
function addon:ResolveProcAppearance(entry, appearance, publicState, preview)
    if appearance == nil and self.GetProcRegionAppearance then appearance = self:GetProcRegionAppearance(entry) end
    local result = self:NormalizeProcAppearance(appearance)
    if result.mode == "timer" then return result end
    if result.mode == "native" then result = self:NewProcAppearance() end
    if type(entry) ~= "table" or type(entry.guide) ~= "table" or type(entry.anchor) ~= "table" then
        return result, nil, "native-geometry-unavailable"
    end
    local selected = result.mode == "custom" and result.assetKey and self:GetProcAsset(result.assetKey)
    local guide, anchor = entry.guide, entry.anchor
    local textureID = guide.texture
    if not preview and Plain(publicState) then
        textureID = publicState.textureID or publicState.texture or textureID
    end
    -- Even native artwork selection is restricted to the audited catalog.
    local native = self:GetProcAssetByTexture(textureID)
    if not selected and not native then return result, nil, "native-asset-unavailable" end
    local asset = { key = selected and selected.key or nil,
        textureID = selected and selected.textureID or textureID,
        width = selected and selected.geometry.width or guide.width,
        height = selected and selected.geometry.height or guide.height,
        flipH = guide.flipH == true, flipV = guide.flipV == true,
        x = anchor.x, y = anchor.y }
    if not selected and not preview and Plain(publicState)
        and Finite(publicState.scale, { min = .01, max = 10 })
        and Finite(entry.nativeScale, { min = .01, max = 10 }) then
        local relative = publicState.scale / entry.nativeScale
        asset.width, asset.height = asset.width * relative, asset.height * relative
    end
    local color = result.mode == "custom" and result.artColor or nil
    if not color and Plain(publicState) then
        local publicColor = publicState.color or { r = publicState.r, g = publicState.g, b = publicState.b }
        if RGB(publicColor) then color = publicColor end
    end
    if not color and preview then color = { r = 1, g = 1, b = 1 } end
    if not color then return result, nil, "native-color-unavailable" end
    asset.color = Copy(color)
    return result, asset
end
