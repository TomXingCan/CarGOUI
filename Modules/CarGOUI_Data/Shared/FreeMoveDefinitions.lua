local _, data = ...

-- Time Spiral 374968 grants a class-specific receiver aura. These are aura
-- identities, not cast IDs or movement spell IDs. Source: target 12.1.0.69933
-- Evoker spell/effect dump; see docs/MAGE_PROC_COVERAGE.md. Static lookup data
-- is loaded with the shared Data package; only the current class gets an entry.
local receiverAuras = {
    DEATHKNIGHT = 375226, DEMONHUNTER = 375229, DRUID = 375230,
    EVOKER = 375234, HUNTER = 375238, MAGE = 375240, MONK = 375252,
    PALADIN = 375253, PRIEST = 375254, ROGUE = 375255, SHAMAN = 375256,
    WARLOCK = 375257, WARRIOR = 375258,
}

function data.host:GetFreeMoveDefinition(classToken)
    local auraID = receiverAuras[classToken]
    if not auraID then return end
    return {
        id = "free_move_" .. classToken:lower(), class = classToken,
        kind = "mobility", freeMove = true, textOnly = true,
        label = "Free move - Time Spiral", spellName = "Free move",
        auraID = auraID, sourceCastID = 374968, region = "CENTER", slot = 0,
        -- Keep the original default center (+84) for visual compatibility.
        -- Free move now uses its own class-scoped offset; ordinary Mobility
        -- movement must not translate this receiver or its Preview.
        anchor = { x = 0, y = 84 },
        sample = { message = "Free move", timer = "" },
    }
end
