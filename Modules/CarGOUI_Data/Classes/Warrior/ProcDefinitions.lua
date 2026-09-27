local _, data = ...

data:RegisterProcFactory("WARRIOR", function(specID)
    -- Arms Tactician is only a short Overpower-reset flash; Fury has no admitted
    -- finite native-screen timer in this target audit. Neither gets a fake sample.
    if specID ~= 73 then return {} end
    return { data:ProcDefinition({
        id = "warrior_73_revenge", name = "Revenge!", class = "WARRIOR", specID = specID,
        auraID = 5302, requiresKnown = { 6572 },
        overlaySources = { { overlayID = 5302, textureID = 603339,
            locationTypeName = "Right", scale = 0.85000002384 } },
        regions = { { id = "warrior_73_revenge_right", label = "Revenge! - Right", location = "Right" } },
        nativeEventOnly = false,
        evidence = "12.1.0.69933; Overlay1488; Protection passive5301 triggers finite free-Revenge5302; current SimC same buff; docs/PROC_BATCH3.md",
    }) }
end)
