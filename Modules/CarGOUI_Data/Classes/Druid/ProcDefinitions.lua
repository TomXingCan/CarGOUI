local _, data = ...

-- Retail 12.1.0.69933. Factories instantiate only the requested spec.
-- Evidence: docs/PROC_BATCH2.md; durations belong to native aura bindings.
data:RegisterProcFactory("DRUID", function(specID)
    if specID == 102 then
        return { data:ProcDefinition({
            id = "druid_balance_owlkin_frenzy", name = "Owlkin Frenzy", class = "DRUID", specID = 102,
            auraID = 157228, requiresKnown = { 24858 },
            condition = "Balance with Moonkin Form; native aura owns proc presence.",
            overlaySources = { { overlayID = 157228, textureID = 463452, locationTypeName = "Top", scale = 1 } },
            regions = { { id = "druid_balance_owlkin_frenzy_top", label = "Owlkin Frenzy - Top", location = "Top" } },
            evidence = "69933 overlay row 3369; finite aura 157228; target sc_druid conditions Balance + Moonkin Form.",
        }) }
    elseif specID == 103 then
        return { data:ProcDefinition({
            id = "druid_feral_clearcasting", name = "Clearcasting", class = "DRUID", specID = 103,
            auraID = 135700, requiresKnown = { 16864 },
            condition = "Feral Omen of Clarity talent 16864 triggers aura 135700.",
            overlaySources = { { overlayID = 135700, textureID = 510823, locationTypeName = "LeftRight", scale = 1 } },
            regions = {
                { id = "druid_feral_clearcasting_left", label = "Clearcasting - Left", location = "Left" },
                { id = "druid_feral_clearcasting_right", label = "Clearcasting - Right", location = "Right" },
            },
            evidence = "69933 overlay row 1899; target Omen of Clarity 16864 directly triggers finite aura 135700.",
        }) }
    elseif specID == 104 then
        return {
            data:ProcDefinition({
                id = "druid_guardian_gore", name = "Gore", class = "DRUID", specID = 104,
                auraID = 93622, requiresKnown = { 210706 },
                condition = "Guardian Gore talent 210706; timer is the finite Mangle bonus aura, not cooldown readiness.",
                overlaySources = { { overlayID = 93622, textureID = 510822, locationTypeName = "Top", scale = 1 } },
                regions = { { id = "druid_guardian_gore_top", label = "Gore - Top", location = "Top" } },
                evidence = "69933 overlay row 205; finite aura 93622 and sc_druid Gore talent -> buff construction.",
            }),
            data:ProcDefinition({
                id = "druid_guardian_galactic_guardian", name = "Galactic Guardian", class = "DRUID", specID = 104,
                auraID = 213708, requiresKnown = { 203964 }, excludesKnown = { 1252871 },
                condition = "Guardian Galactic Guardian talent 203964 without its Red Moon replacement 1252871.",
                overlaySources = { { overlayID = 213708, textureID = 450914, locationTypeName = "Left", scale = 1 } },
                regions = { { id = "druid_guardian_galactic_guardian_left", label = "Galactic Guardian - Left", location = "Left" } },
                evidence = "69933 overlay row 3193; finite aura 213708; target sc_druid excludes Red Moon from this buff.",
            }),
            data:ProcDefinition({
                id = "druid_guardian_celestial_might", name = "Celestial Might", class = "DRUID", specID = 104,
                auraID = 1272376, nativeEventOnly = true,
                condition = "Guardian 12.0 four-piece effect 1264816; requires an actual native graphic SHOW and matching aura.",
                overlaySources = { { overlayID = 1272376, textureID = 592058, locationTypeName = "Right", scale = 1 } },
                regions = { { id = "druid_guardian_celestial_might_right", label = "Celestial Might - Right", location = "Right" } },
                evidence = "69933 overlay row 4999; finite aura 1272376 directly triggered by set effect 1264816; no hidden-aura known check.",
            }),
        }
    elseif specID == 105 then
        return { data:ProcDefinition({
            id = "druid_restoration_clearcasting", name = "Clearcasting", class = "DRUID", specID = 105,
            auraID = 16870, requiresKnown = { 113043 },
            condition = "Restoration Omen of Clarity talent 113043 triggers aura 16870.",
            overlaySources = { { overlayID = 16870, textureID = 450929, locationTypeName = "LeftRight", scale = 0.75 } },
            regions = {
                { id = "druid_restoration_clearcasting_left", label = "Clearcasting - Left", location = "Left" },
                { id = "druid_restoration_clearcasting_right", label = "Clearcasting - Right", location = "Right" },
            },
            evidence = "69933 overlay row 148; target Omen of Clarity 113043 directly triggers finite Regrowth aura 16870.",
        }) }
    end
    return {}
end)
