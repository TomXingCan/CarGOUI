local _, addon = ...

local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyDefaults(target[key], value)
        elseif type(target[key]) ~= type(value) then
            target[key] = value
        end
    end
end

function addon:InitializeDatabase()
    if type(CarGOUIDB) ~= "table" then
        CarGOUIDB = {}
    end
    ApplyDefaults(CarGOUIDB, self.defaults)

    local db = CarGOUIDB
    db.schemaVersion = self.defaults.schemaVersion
    for _, axis in ipairs({ "x", "y" }) do
        if not self:IsNumberInRange(db.position[axis], self.limits.offset) then
            db.position[axis] = self.defaults.position[axis]
        end
    end
    if not self:IsNumberInRange(db.font.size, self.limits.fontSize) then
        db.font.size = self.defaults.font.size
    end
    if not self.outlines[db.font.outline] then
        db.font.outline = self.defaults.font.outline
    end
    if not self:IsNumberInRange(db.scale, self.limits.scale) then
        db.scale = self.defaults.scale
    end

    -- Phase 1 ships no font assets; Friz Quadrata comes from the game client.
    db.font.face = self.defaults.font.face
    self.db = db
end

function addon:ResetDatabase()
    CarGOUIDB = {}
    self:InitializeDatabase()
    self:ApplySettings()
end
