-- Exercise the shipped schema, normalization, and transactional transfer paths.
local h = ...
local test, equal, truthy, same, copy = h.test, h.equal, h.truthy, h.same, h.copy
local left, right = "mage_arcane_clearcasting_left", "mage_arcane_clearcasting_right"

local function entry(addon, id)
    for _, value in ipairs(addon:GetDefinedPreviewEntries()) do if value.id == (id or left) then return value end end
    error("Missing current Proc fixture region")
end

local function independent(proc)
    proc.presentationPolicy = "independent"
    proc.independentArtworkEnabled = false
    proc.regions[left].independentArtworkEnabled = true
    proc.regions[right].independentArtworkEnabled = false
end

test("INDEPENDENT SETTINGS legacy schema 5 scopes stay sparse and never infer opt-in from Custom", function()
    local env, addon = h.transferSeed()
    truthy(addon:SetProcRegionAppearance(entry(addon), { mode = "custom", assetKey = "blizzard_4699056" }))
    local saved = copy(addon.db)
    local _, reloaded = h.login(copy(saved), false, { specID = 62, proc = {} })
    same(reloaded.db, saved, "legacy save is unchanged on login")
    equal(reloaded:GetProcPresentationPolicy(), "replacement")
    equal(reloaded:GetProcRegionAppearance(entry(reloaded)).mode, "custom")
    equal(reloaded:IsProcIndependentArtworkRegionEnabled(entry(reloaded)), false)
    equal(reloaded:GetProcConfig().presentationPolicy, nil)
    equal(reloaded:GetProcConfig().independentArtworkEnabled, nil)
    equal(reloaded:GetProcConfig().regions[left].independentArtworkEnabled, nil)
    same(reloaded.db, saved, "policy and region reads add no persistent defaults")
    local packet = h.unpackSettings(env, assert(reloaded:ExportSettings("all")))
    equal(packet.schemaVersion, 5); equal(packet.formatVersion, 1)
    for _, class in pairs(packet.classes) do for _, proc in pairs(class.proc or {}) do
        equal(proc.presentationPolicy, nil); equal(proc.independentArtworkEnabled, nil)
        for _, region in pairs(proc.regions) do equal(region.independentArtworkEnabled, nil) end
    end end
end)

test("INDEPENDENT SETTINGS validated opt-in preserves legacy region and timer settings", function()
    local _, addon = h.transferSeed()
    truthy(addon:SetProcRegionAppearance(entry(addon), { mode = "timer", alpha = .65, offset = { x = 27, y = -31 } }))
    local before, other = copy(addon:GetProcConfig()), addon.db.classes.MAGE.proc[63]
    truthy(addon:UpdateSettings({ proc = { presentationPolicy = "independent",
        independentArtworkEnabled = false, regions = { [left] = { independentArtworkEnabled = true } } } }))
    local current = addon:GetProcConfig()
    equal(addon:GetProcPresentationPolicy(), "independent")
    equal(current.independentArtworkEnabled, false)
    equal(current.regions[left].independentArtworkEnabled, true)
    equal(current.regions[right].independentArtworkEnabled, nil, "sibling remains explicitly opt-out")
    equal(addon.db.classes.MAGE.proc[63], other, "inactive specialization is not normalized")
    local unchanged = copy(current)
    unchanged.presentationPolicy, unchanged.independentArtworkEnabled = nil, nil
    unchanged.regions[left].independentArtworkEnabled = nil
    same(unchanged, before, "mode, typography, timer color, offsets, and Proc enable are retained")
    truthy(addon:UpdateSettings({ proc = { regions = { [right] = { independentArtworkEnabled = true } } } }))
    equal(addon:GetProcPresentationPolicy(), "independent", "local patches omit and preserve policy")
    equal(current.independentArtworkEnabled, false, "local patches preserve master opt-out")
    truthy(addon:ResetProcRegionAppearance(entry(addon)))
    equal(current.regions[left].independentArtworkEnabled, true, "appearance reset does not reset independent ownership")
end)

test("INDEPENDENT SETTINGS new fields reject invalid and restricted values before cleanup or mixed writes", function()
    local _, addon = h.transferSeed()
    local cleanups = 0
    function addon:PrepareProcPresentationTransition() cleanups = cleanups + 1; error("invalid patch reached cleanup") end
    local invalid = {
        { presentationPolicy = false }, { presentationPolicy = 1 }, { presentationPolicy = "custom" },
        { presentationPolicy = {} }, { presentationPolicy = h.secret("independent") },
        { independentArtworkEnabled = 1 }, { independentArtworkEnabled = "true" },
        { independentArtworkEnabled = h.secret(true) },
        { regions = { [left] = { independentArtworkEnabled = "false" } } },
        { regions = { [left] = { independentArtworkEnabled = 0 } } },
        { regions = { [left] = { independentArtworkEnabled = h.secret(false) } } },
        { regions = { unknown_region = { independentArtworkEnabled = true } } },
        { regions = { [left] = { presentationPolicy = "independent" } } },
    }
    for _, proc in ipairs(invalid) do
        local before = copy(addon.db)
        equal(addon:UpdateSettings({ options = { animatedTitle = true }, mobility = { enabled = false }, proc = proc }), false)
        same(addon.db, before, "invalid mixed patch cannot write unrelated settings")
    end
    equal(cleanups, 0)
end)

test("INDEPENDENT SETTINGS normalization removes malformed optional values only in the active scope", function()
    local _, original = h.transferSeed()
    local saved = copy(original.db)
    local active, inactive = saved.classes.MAGE.proc[62], saved.classes.MAGE.proc[63]
    active.presentationPolicy, active.independentArtworkEnabled = "custom", 0
    active.regions[left].independentArtworkEnabled = "true"
    inactive.presentationPolicy, inactive.independentArtworkEnabled = "independent", false
    inactive.regions.mage_fire_hot_streak_left.independentArtworkEnabled = true
    local oldInactive, oldPosition, oldColor = copy(inactive), copy(active.regions[left].position), copy(active.regions[left].color)
    local _, addon = h.login(saved, false, { specID = 62, proc = {} })
    local config = addon:GetProcConfig()
    equal(config.presentationPolicy, nil); equal(config.independentArtworkEnabled, nil)
    equal(config.regions[left].independentArtworkEnabled, nil)
    equal(addon:GetProcPresentationPolicy(), "replacement")
    same(config.regions[left].position, oldPosition); same(config.regions[left].color, oldColor)
    same(addon.db.classes.MAGE.proc[63], oldInactive, "other scope stays raw and preserves explicit opt-in")
end)

test("INDEPENDENT SETTINGS cleanup failure rejects an entire mixed patch before normalization and retains owners", function()
    local _, addon = h.transferSeed()
    addon.procConfigurationCache = {}
    local owner = {}; addon.procSuppressedOverlays = { [owner] = { regionID = left } }
    local oldStop, oldApply = addon.StopProcArtwork, addon.ApplySettings
    local cleanups, applies = 0, 0
    function addon:StopProcArtwork() cleanups = cleanups + 1; return false end
    function addon:ApplySettings() applies = applies + 1 end
    local before, classes, scope = copy(addon.db), addon.db.classes, addon.db.classes.MAGE.proc[62]
    local ok, message = addon:UpdateSettings({ options = { animatedTitle = true }, mobility = { enabled = false },
        proc = { presentationPolicy = "independent", regions = { [left] = { independentArtworkEnabled = true } } } })
    equal(ok, false); truthy(type(message) == "string" and #message > 0)
    same(addon.db, before); equal(addon.db.classes, classes); equal(addon.db.classes.MAGE.proc[62], scope)
    truthy(addon.procSuppressedOverlays[owner], "failed native ownership remains available to Retry")
    equal(cleanups, 1); equal(applies, 0)
    addon.StopProcArtwork, addon.ApplySettings = oldStop, oldApply
end)

test("INDEPENDENT SETTINGS successful policy transaction cleans under old settings before commit", function()
    local _, addon = h.transferSeed()
    local before, stopped, configured = copy(addon.db), 0, 0
    addon.procOverlayStates = { old = { visible = true, sequence = 9 } }
    function addon:StopProcArtwork()
        same(addon.db, before, "cleanup observes the entire old mixed patch")
        stopped = stopped + 1; return true
    end
    function addon:ApplySettings()
        equal(addon:GetProcPresentationPolicy(), "independent", "configuration runs after commit")
        equal(next(addon.procOverlayStates), nil, "old graphical state cannot synthesize a first SHOW")
        configured = configured + 1
    end
    truthy(addon:UpdateSettings({ options = { animatedTitle = true }, mobility = { enabled = false },
        proc = { presentationPolicy = "independent", regions = { [left] = { independentArtworkEnabled = true } } } }))
    equal(stopped, 1); equal(configured, 1)
    equal(addon.db.options.animatedTitle, true); equal(addon:GetMobilityConfig().enabled, false)
end)

test("INDEPENDENT SETTINGS master and region flags refresh only artwork and preserve native timer resources", function()
    local _, addon, state = h.transferSeed()
    local rendered, previews = 0, 0
    function addon:ConfigureProc() error("artwork flag must not reconfigure timers") end
    function addon:ApplySettings() error("artwork flag must not globally configure gameplay") end
    function addon:RenderProcArtwork() rendered = rendered + 1 end
    function addon:RefreshPreview(keep) equal(keep, true); previews = previews + 1 end
    local slots, bindings, frames = #state.auraSlots, #state.bindings, #state.frames
    local native = {}
    for _, slot in ipairs(state.auraSlots) do native[slot] = slot.nativeBinding end
    local enabled, style = addon:GetProcConfig().enabled, copy(addon:GetProcConfig().style)
    for _, value in ipairs({ false, true }) do
        truthy(addon:UpdateSettings({ proc = { independentArtworkEnabled = value } }))
        truthy(addon:UpdateSettings({ proc = { regions = { [left] = { independentArtworkEnabled = value } } } }))
    end
    equal(rendered, 4); equal(previews, 4)
    equal(#state.auraSlots, slots); equal(#state.bindings, bindings); equal(#state.frames, frames)
    for slot, binding in pairs(native) do equal(slot.nativeBinding, binding, "timer binding identity is retained") end
    equal(addon:GetProcConfig().enabled, enabled); same(addon:GetProcConfig().style, style)
end)

test("INDEPENDENT SETTINGS schema 5 format 1 roundtrip preserves explicit false and inactive opt-ins", function()
    local env, addon = h.transferSeed()
    independent(addon:GetProcConfig())
    local inactive = addon.db.classes.MAGE.proc[63]
    inactive.presentationPolicy, inactive.independentArtworkEnabled = "independent", true
    inactive.regions.mage_fire_hot_streak_left.independentArtworkEnabled = true
    local text = assert(addon:ExportSettings("all"))
    equal(addon:ExportSettings("all"), text)
    local packet = h.unpackSettings(env, text)
    equal(packet.formatVersion, 1); equal(packet.schemaVersion, 5)
    equal(packet.classes.MAGE.proc["62"].independentArtworkEnabled, false)
    equal(packet.classes.MAGE.proc["62"].regions[right].independentArtworkEnabled, false)
    local _, target = h.login(nil, false, { specID = 62, proc = {} })
    local transaction = h.prepareSettings(target, text)
    truthy(transaction.summary:find("Strategy: Independent CUI; independent live artwork: Disabled; explicitly enabled included regions: 1.", 1, true),
        "confirmation exposes policy, effective master, and included region opt-ins")
    truthy(target:ConfirmSettingsImport(transaction))
    equal(target:ExportSettings("all"), text)
    same(target.db.classes.MAGE.proc[63], inactive, "inactive scope is restored without opening its adapter")
end)

test("INDEPENDENT SETTINGS import validates exact policy and artwork flag types atomically", function()
    local env, addon = h.transferSeed()
    h.transferPage(addon)
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    local invalid = {
        function(proc) proc.presentationPolicy = "custom" end,
        function(proc) proc.presentationPolicy = true end,
        function(proc) proc.presentationPolicy = {} end,
        function(proc) proc.independentArtworkEnabled = 1 end,
        function(proc) proc.independentArtworkEnabled = "false" end,
        function(proc) proc.regions[left].independentArtworkEnabled = "true" end,
        function(proc) proc.regions[left].independentArtworkEnabled = {} end,
        function(proc) proc.regions[left].presentationPolicy = "independent" end,
    }
    local calls = 0
    function addon:PrepareProcPresentationTransition() calls = calls + 1; error("invalid import reached cleanup") end
    for _, mutate in ipairs(invalid) do
        local changed = copy(packet); mutate(changed.classes.MAGE.proc["62"])
        local before = copy(addon.db)
        equal(addon:PrepareSettingsImport(h.packSettings(env, changed)), nil)
        same(addon.db, before)
    end
    equal(calls, 0)
end)

test("INDEPENDENT SETTINGS old scope import cleans before commit and cannot bypass cleanup failure", function()
    local env, addon = h.transferSeed()
    local old = assert(addon:ExportSettings("all"))
    truthy(addon:UpdateSettings({ proc = { presentationPolicy = "independent", independentArtworkEnabled = false,
        regions = { [left] = { independentArtworkEnabled = true } } } }))
    local transaction = h.prepareSettings(addon, old)
    local before, classes = copy(addon.db), addon.db.classes
    local owner = {}; addon.procSuppressedOverlays = { [owner] = { regionID = left } }
    local originalStop = addon.StopProcArtwork
    function addon:StopProcArtwork() return false end
    equal(addon:ConfirmSettingsImport(transaction), false)
    same(addon.db, before); equal(addon.db.classes, classes)
    truthy(addon.procSuppressedOverlays[owner], "rejected import retains failed owner")
    equal(addon.db.settingsImportBackup, nil, "rejected import creates no misleading backup")
    addon.procSuppressedOverlays = {}; addon.StopProcArtwork = originalStop
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, old)))
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(addon:GetProcConfig().presentationPolicy, nil, "old whole scope clears persisted independent policy")
    equal(addon:GetProcConfig().independentArtworkEnabled, nil)
    equal(addon:GetProcConfig().regions[left].independentArtworkEnabled, nil)
    local restored = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    same(restored, h.unpackSettings(env, old), "old wire remains sparse after a successful policy transition")
end)

test("INDEPENDENT SETTINGS Restore and Reset reject failed policy cleanup without losing settings or backup", function()
    local env, addon = h.transferSeed()
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    independent(packet.classes.MAGE.proc["62"])
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    local before, backup = copy(addon.db), addon.db.settingsImportBackup
    local originalStop = addon.StopProcArtwork
    function addon:StopProcArtwork() return false end
    equal(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())), false)
    same(addon.db, before); equal(addon.db.settingsImportBackup, backup)
    equal(addon:ResetDatabase(), false)
    same(addon.db, before); equal(addon.db.settingsImportBackup, backup)
    addon.StopProcArtwork = originalStop
    truthy(addon:ConfirmSettingsImport(assert(addon:PrepareSettingsRestore())))
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(addon.db.settingsImportBackup, backup, "restore retains the recoverable pre-import backup")
    truthy(addon:UpdateSettings({ proc = { presentationPolicy = "independent" } }))
    truthy(addon:ResetDatabase())
    equal(addon:GetProcPresentationPolicy(), "replacement")
end)

test("INDEPENDENT SETTINGS inactive policy imports never transition or initialize the current runtime", function()
    local env, addon, state = h.transferSeed()
    h.transferPage(addon)
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    local other = packet.classes.MAGE.proc["63"]
    other.presentationPolicy, other.independentArtworkEnabled = "independent", false
    other.regions.mage_fire_hot_streak_left.independentArtworkEnabled = true
    function addon:PrepareProcPresentationTransition() error("inactive policy cannot clean current runtime") end
    function addon:ConfigureProc() error("inactive policy cannot reconfigure current timers") end
    local getConfig = addon.GetProcConfig
    function addon:GetProcConfig(spec)
        truthy(spec == nil or spec == 62, "import never initializes an inactive scope")
        return getConfig(self, spec)
    end
    local loads, reads, slots = state.moduleLoads, state.auraReads, #state.auraSlots
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    equal(addon:GetProcPresentationPolicy(), "replacement")
    equal(addon.db.classes.MAGE.proc[63].presentationPolicy, "independent")
    equal(addon.db.classes.MAGE.proc[63].independentArtworkEnabled, false)
    equal(state.moduleLoads, loads); equal(state.auraReads, reads); equal(#state.auraSlots, slots)
end)

test("INDEPENDENT SETTINGS flag-only import refreshes artwork without timer reconfiguration", function()
    local env, addon, state = h.transferSeed()
    h.transferPage(addon)
    local packet = h.unpackSettings(env, assert(addon:ExportSettings("all")))
    packet.classes.MAGE.proc["62"].independentArtworkEnabled = false
    packet.classes.MAGE.proc["62"].regions[left].independentArtworkEnabled = true
    local rendered = 0
    function addon:RenderProcArtwork() rendered = rendered + 1 end
    function addon:ConfigureProc() error("flag-only import cannot reconfigure timers") end
    local slots, bindings = #state.auraSlots, #state.bindings
    truthy(addon:ConfirmSettingsImport(h.prepareSettings(addon, h.packSettings(env, packet))))
    equal(rendered, 1); equal(#state.auraSlots, slots); equal(#state.bindings, bindings)
    equal(addon:GetProcConfig().enabled, true)
end)

test("INDEPENDENT SETTINGS all saved scoped opt-ins fit the unchanged bounded transfer format", function()
    local _, addon = h.transferSeed()
    local count = 0
    for class, specs in pairs(addon.settingsMetadata.classes) do
        local record = { mobility = addon:NewMobilityConfig(), proc = {} }; addon.db.classes[class] = record
        for spec, ids in pairs(specs) do
            local proc = addon:NewProcConfig(); record.proc[spec] = proc
            proc.presentationPolicy, proc.independentArtworkEnabled = "independent", false
            for id in pairs(ids) do
                count = count + 1
                proc.regions[id] = { position = { anchor = "CENTER", x = count, y = -count },
                    independentArtworkEnabled = true, appearance = addon:NewProcAppearance() }
            end
        end
    end
    local text = assert(addon:ExportSettings("all"))
    truthy(#text < addon.settingsTransferLimits.inputBytes)
    local _, target = h.login(nil, false, { specID = 62, proc = {} })
    truthy(target:ConfirmSettingsImport(h.prepareSettings(target, text)))
    equal(target:ExportSettings("all"), text); equal(count, 97)
end)
