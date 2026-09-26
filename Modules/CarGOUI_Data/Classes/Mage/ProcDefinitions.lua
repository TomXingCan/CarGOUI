local _, data = ...
local adapter = data.adapters.MAGE

-- Retail 12.1.0.69933 SpellActivationOverlay / ScreenLocation DB2 records.
-- Spell IDs, aura IDs and graphical overlay IDs are explicit fields. In
-- particular, the texture-less Clearcasting 263725 row is NOT substituted
-- for graphical 276743, and the hidden right-hand FoF aura is NOT guessed
-- from a Lua stack count. See docs/MAGE_PROC_COVERAGE.md for the evidence.
-- Only the requested specialization's tables are instantiated.
local longSide, shortSide = 256 * 0.8, 128 * 0.8

local function Region(id, label, location, textureID, scale)
    local left = location == "Left" or location == "LeftOutside"
    local right = location == "Right" or location == "RightOutside"
    local side = left or right
    local outside = location == "LeftOutside" or location == "RightOutside"
    local distance = longSide / 2 + shortSide * scale / 2
        + (outside and shortSide or 0)
    return {
        id = id, label = label, location = location,
        region = location:upper(),
        -- Stock-geometry guides are for the external Preview only. Live
        -- placement is tied to the corresponding native overlay region.
        anchor = { x = side and (left and -distance or distance) or 0,
            y = side and 0 or distance },
        guide = { texture = textureID,
            width = (side and shortSide or longSide) * scale,
            height = (side and longSide or shortSide) * scale,
            flipH = right },
    }
end

local function Proc(specID, id, name, auraID, overlayID, textureID, locationTypeName, scale, regions, nativeEventOnly)
    local result = {
        id = id, name = name, class = "MAGE", specID = specID,
        auraID = auraID, overlayID = overlayID, textureID = textureID,
        locationTypeName = locationTypeName, scale = scale, regions = {},
        nativeEventOnly = nativeEventOnly or false,
        preview = not nativeEventOnly,
        auditBootstrap = nativeEventOnly and "native-event-required" or "exact-aura-only",
    }
    for _, region in ipairs(regions) do
        result.regions[#result.regions + 1] = Region(region[1], region[2], region[3], textureID, scale)
    end
    return result
end

local factories = {
    [62] = function()
        return {
            Proc(62, "mage_arcane_clearcasting", "Clearcasting", 276743, 276743, 449486, "LeftRight", 1, {
                { "mage_arcane_clearcasting_left", "Clearcasting - left region", "Left" },
                { "mage_arcane_clearcasting_right", "Clearcasting - right region", "Right" },
            }),
            Proc(62, "mage_arcane_soul", "Arcane Soul", 451038, 451038, 449486, "LeftRightOutside", 1, {
                { "mage_arcane_soul_left", "Arcane Soul - outside left region", "LeftOutside" },
                { "mage_arcane_soul_right", "Arcane Soul - outside right region", "RightOutside" },
            }),
            Proc(62, "mage_arcane_overpowered_missiles", "Overpowered Missiles", 1277009, 1277009, 6160020, "Top", 1, {
                { "mage_arcane_overpowered_missiles_top", "Overpowered Missiles - top region", "Top" },
            }),
        }
    end,
    [63] = function()
        return {
            Proc(63, "mage_fire_hot_streak", "Hot Streak", 48108, 48108, 449490, "LeftRight", 1, {
                { "mage_fire_hot_streak_left", "Hot Streak - left region", "Left" },
                { "mage_fire_hot_streak_right", "Hot Streak - right region", "Right" },
            }),
            Proc(63, "mage_fire_heating_up", "Heating Up", 48107, 48107, 449490, "LeftRight", 0.5, {
                { "mage_fire_heating_up_left", "Heating Up - small left region", "Left" },
                { "mage_fire_heating_up_right", "Heating Up - small right region", "Right" },
            }),
            Proc(63, "mage_fire_pyroclasm", "Pyroclasm", 269651, 269651, 457658, "Top", 0.7, {
                { "mage_fire_pyroclasm_top", "Pyroclasm - top region", "Top" },
            }),
            -- Memory of Al'ar 449619 still grants this in the current
            -- Sunfury hero tree, independently of the former standalone
            -- Hyperthermia talent. It is an actual current mapping.
            Proc(63, "mage_fire_hyperthermia", "Hyperthermia", 383874, 383874, 6160021, "LeftRightOutside", 1.5, {
                { "mage_fire_hyperthermia_left", "Hyperthermia - outside left region", "LeftOutside" },
                { "mage_fire_hyperthermia_right", "Hyperthermia - outside right region", "RightOutside" },
            }),
            -- This retained graph row has no current talent-tree driver in
            -- the target dump. An actual native graph event must establish
            -- availability; no sample advertises it as a current talent.
            Proc(63, "mage_fire_fury_sun_king", "Fury of the Sun King", 383883, 383883, 457658, "Top", 0.7, {
                { "mage_fire_fury_sun_king_top", "Fury of the Sun King - top region", "Top" },
            }, true),
        }
    end,
    [64] = function()
        return {
            Proc(64, "mage_frost_fingers_left", "Fingers of Frost", 44544, 44544, 449489, "Left", 1, {
                { "mage_frost_fingers_left", "Fingers of Frost - left region", "Left" },
            }),
            Proc(64, "mage_frost_fingers_right", "Fingers of Frost", 126084, 126084, 449489, "Right", 1, {
                { "mage_frost_fingers_right", "Fingers of Frost - right region", "Right" },
            }),
            Proc(64, "mage_frost_brain_freeze", "Brain Freeze", 190446, 190446, 450930, "Top", 1, {
                { "mage_frost_brain_freeze_top", "Brain Freeze - top region", "Top" },
            }),
        }
    end,
}

function adapter:GetProcDefinitions(specID)
    if self.procDefinitionSpec ~= specID or not self.procDefinitions then
        local factory = specID and factories[specID]
        self.procDefinitions = factory and factory() or {}
        self.procDefinitionSpec = specID
    end
    return self.procDefinitions
end
