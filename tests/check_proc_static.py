"""Proc/native-aura structural guards; not a Retail secret-value or taint proof."""
from pathlib import Path
import argparse
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--addon-root", type=Path, default=Path(__file__).resolve().parent.parent)
root = parser.parse_args().addon_root.resolve()
data_root = root / "Modules/CarGOUI_Data"
if not data_root.is_dir():
    data_root = root.parent / "CarGOUI_Data"


def code(text):
    return re.sub(r"--[^\n]*", "", text)


def absent(text, patterns, label):
    for pattern in patterns:
        assert not re.search(pattern, text), f"{label}: disallowed path {pattern}"
    print("PASS " + label)


toc = (root / "CarGOUI.toc").read_text(encoding="utf-8")
declared = [line.strip().replace("\\", "/") for line in toc.splitlines()
            if line.strip() and not line.strip().startswith("#")]
proc_files = sorted((root / "Modules/Proc").rglob("*.lua"))
assert proc_files, "Real Proc implementation must be shipped"
for path in proc_files:
    assert path.relative_to(root).as_posix() in declared, "Proc source must be TOC-loaded"
native = code((root / "Modules/Proc/AuraState.lua").read_text(encoding="utf-8"))
native_sources = proc_files + [root / "UI/ProcDisplay.lua", root / "Modules/Mobility/FreeMove.lua"]
for path in native_sources:
    assert path.relative_to(root).as_posix() in declared, "Native reminder source must be TOC-loaded and audited"
runtime = "\n".join(code(path.read_text(encoding="utf-8")) for path in native_sources)
mapping = code((data_root / "Classes/Mage/ProcDefinitions.lua").read_text(encoding="utf-8"))
class_mappings = sorted((data_root / "Classes").glob("*/ProcDefinitions.lua"))
data_toc = (data_root / "CarGOUI_Data.toc").read_text(encoding="utf-8").replace("\\", "/")
for path in class_mappings:
    assert path.relative_to(data_root).as_posix() in data_toc, "Every Proc class source must be TOC loaded"
    text = code(path.read_text(encoding="utf-8"))
    assert not re.search(r"CreateFrame|CreateFont|C_UnitAuras|RegisterEvent|C_Timer|CarGOUIDB|SetDuration|OnUpdate|GetTime", text)
    if path.parent.name != "Mage":
        assert "RegisterProcFactory" in text and "ProcDefinition" in text
        assert "evidence" in text, "Every admitted class catalog needs pinned mapping evidence"
print(f"PASS All {len(class_mappings)} shipped Proc class catalogs use lazy data-only factories with explicit evidence")
shared = code((data_root / "Shared/ProcDefinitions.lua").read_text(encoding="utf-8"))
proc_runtime = code((root / "Modules/Proc/Runtime.lua").read_text(encoding="utf-8"))
compiler = code((root / "Modules/Proc/Definitions.lua").read_text(encoding="utf-8"))
assert 'adapter.classToken == "MAGE"' not in proc_runtime
assert "adapter.procCapability.version == 1" in proc_runtime and "CompileProcDefinitions" in proc_runtime
assert "RegisterProcFactory" in shared and "requiresAnyKnown" in shared and "requiresKnown" in shared
assert "byRegion[region.id]" in compiler and "binding.source.shared" in compiler
assert "source.textureID == texture and source.locationTypeName == location" in proc_runtime
assert 'frame.nativeAuraID ~= auraID' in code((root / "UI/ProcDisplay.lua").read_text(encoding="utf-8"))
assert "proc_sources_69933.lua" not in toc and "fixtures" not in data_toc
print("PASS Proc capability, conflict validation, exact graphical dispatch and immutable Aura provider guards are explicit")
absent(runtime, [r"OnUpdate", r"NewTicker", r"COMBAT_LOG", r"UNIT_SPELLCAST",
                 r"UnitBuff\s*\(", r"UnitAura\s*\(", r"C_UnitAuras", r"GetTime\s*\(",
                 r"GetRemainingDuration\s*\(", r"GetFormattedText\s*\(",
                 r"\.expirationTime", r"\.applications"],
       "Proc and Free move have no polling, cast inference, addon aura scan, raw timer arithmetic or secret-state probing")
absent(runtime, [r"GetText\s*\(", r"GetStringWidth\s*\(", r"GetStringHeight\s*\(",
                 r"GetAlpha\s*\(", r"GetAuraSlotFrame\s*\(", r"GetAuraInstance\s*\("],
       "Proc never reads native aura child visibility, opacity, identity or timer text")
assert '"CustomAuraContainerTemplate"' in native
assert '"AuraContainer"' in native and '"SetUnit", handle.container.SetUnit, handle.container, "player"' in native
assert 'handle.container.AddAuraSlot, handle.container, handle.key, "HELPFUL"' in native
assert "candidateFilters = { includeSpellIDs = { [handle.auraID] = true } }" in native
assert "button:SetDurationText(text, { binding = binding })" in native
assert "text:SetFontObject(handle.font)" in native and '"fontsCreated", handle.procOwned, CreateFont' in native
assert "container.SetEnabled, container, value" in native
assert "Attempt(container.Show, container)" in native
absent(native, [r"self\.container:Hide\s*\(", r"self\.button", r"handle\.button",
                r"\.GetAuraDataBy", r"\.GetPlayerAura"],
       "Aura lifecycle uses native helpful-spell filtering, copied binding and no retained restricted child")
absent(mapping, [r"CreateFrame", r"CreateFont", r"C_UnitAuras", r"RegisterEvent", r"C_Timer",
                 r"CarGOUIDB", r"SetDuration"],
       "Mage Proc mapping stores static audited definitions without activating other specializations")
assert "function adapter:GetProcDefinitions(specID)" in mapping
assert "auraID = auraID, overlayID = overlayID" in mapping
print("PASS Proc mappings distinguish aura ID, native overlay ID and per-region saved-position keys")
picker = code((root / "UI/ProcColorPicker.lua").read_text(encoding="utf-8"))
style = code((root / "UI/ReminderStyle.lua").read_text(encoding="utf-8"))
assert "UI/ProcColorPicker.lua" in declared, "Shared native picker implementation must ship"
absent(picker + style, [r"OnUpdate", r"NewTicker", r"C_Timer", r"C_UnitAuras", r"C_Spell",
                       r"SetAlpha\s*\(", r"GetAlpha\s*\(", r"SetDuration\s*\(",
                       r"GetAuraSlotFrame", r"GetFormattedText", r"RAID_CLASS_COLORS", r"CUSTOM_CLASS_COLORS"],
       "RGB editing uses configuration and owned Fonts without queries, binding changes, alpha ownership or global color edits")
assert 'first.kind == "proc"' in picker and 'second.kind == "proc"' in picker
assert "first.class == second.class" in picker and "first.specID == second.specID" in picker
assert "first.id == second.id" in picker
assert "picker.extraInfo == session" in picker and "picker.swatchFunc == session.swatchFunc" in picker
assert "picker.cancelFunc == session.cancelFunc" in picker
assert "hasOpacity = false" in picker and 'HookScript("PreClick"' in picker
assert 'hooksecurefunc(picker, "SetupColorPickerAndShow"' in picker
assert "SetProcRegionColorPreview" in picker and "SetProcRegionColor(session.entry, session.draft)" in picker
assert "local frame = pool[entry.id]" in style and "SameRegion(frame.reminderEntry, entry)" in style
print("PASS Native picker pins class/spec/stable region, separates draft/Okay, and guards foreign picker ownership")
database = code((root / "Core/Database.lua").read_text(encoding="utf-8"))
assert "schema.proc.regions[entry.id]" in database and "color = RegionColorSetting" in database
assert "ColorCopy(region.color)" in database and "config.regions[id].color = ColorCopy(record.color)" in database
assert "changedColors" in database and "RefreshProcRegionColor(entry)" in database
print("PASS RGB schema is optional per stable Proc region and color-only writes use targeted styling")

# Protected calls now also isolate owned construction and shutdown failures.
# They never probe a restricted Aura, button, duration or native callback object.
stop = proc_runtime.split('function addon:StopProc()', 1)[1].split('local function RenderProcState', 1)[0]
assert "pcall(callback, ...)" in stop and "self.procStopping, self.procTracking = true, false" in stop
assert "self.nativeAuraSlots[key] = handle" in native and "handle.slotAttempted" in native
assert "handle.initializeCompleted" in native and '"slot-uncertain"' in native
absent(native, [r"SetParent\s*\(", r"HasAuraSlot\s*\(", r"RemoveAuraSlot\s*\(",
                r"UnregisterAuraSlot\s*\(", r"SetAuraSlotCandidateFilters\s*\("],
       "Native ownership avoids forbidden parenting private slot methods and refresh-time filter rebuilds")
safety = code((root / "Core/ProcSafety.lua").read_text(encoding="utf-8"))
diagnostics = code((root / "Core/ProcDiagnostics.lua").read_text(encoding="utf-8"))
assert "Core/ProcSafety.lua" in declared and "Core/ProcDiagnostics.lua" in declared
assert "local BUDGET = 3" in safety and "state.quarantined" in safety and "RetryProc" in safety
assert "RunProcSafe" in proc_runtime and "IsProcQuarantined" in proc_runtime
absent(safety + diagnostics, [r"OnUpdate", r"NewTicker", r"C_Timer", r"collectgarbage", r"CarGOUIDB",
       r"C_UnitAuras", r"GetText\s*\(", r"GetAlpha\s*\(", r"GetAuraSlotFrame\s*\(",
       r"geterrorhandler\s*\(", r"seterrorhandler\s*\("],
       "Proc-only diagnostics and quarantine have no polling GC persistence protected readback or global error handler")
artwork = code((root / "UI/ProcArtwork.lua").read_text(encoding="utf-8"))
resolver = code((root / "Core/ProcAppearance.lua").read_text(encoding="utf-8"))
catalog = code((root / "Database/ProcAssets.lua").read_text(encoding="utf-8"))
editor = code((root / "UI/ProcAppearanceOptions.lua").read_text(encoding="utf-8"))
for relative in ("UI/ProcArtwork.lua", "Core/ProcAppearance.lua", "Database/ProcAssets.lua", "UI/ProcAppearanceOptions.lua"):
    assert declared.count(relative) == 1, "Presentation source must load exactly once: " + relative
absent(artwork + resolver + editor, [r"OnUpdate", r"NewTicker", r"COMBAT_LOG", r"UNIT_AURA", r"C_UnitAuras",
       r"UnitBuff\s*\(", r"UnitAura\s*\(", r"GetVertexColor\s*\(", r"GetAlpha\s*\(",
       r"SetCVar\s*\(", r"SetCVarBool\s*\(", r"GetRemainingDuration\s*\("],
       "Appearance cannot poll, reconstruct triggers, read native opacity/color, query Aura state or write overlay CVars")
absent(catalog, [r"CreateFrame", r"RegisterEvent", r"GetProcDefinitions", r"RegisterProcFactory", r"C_Spell", r"C_UnitAuras",
       r"CarGOUIDB", r"Interface\\\\", r"\.(?:blp|tga|dds|png)"],
       "Artwork catalog is inert audited client-resource metadata with no trigger registration or bundled texture paths")
assert 'hooksecurefunc(root, "ShowOverlay"' in artwork and 'hooksecurefunc(root, "ReleaseOverlay"' in artwork
assert 'procSuppressedOverlays' in artwork and 'RestoreProcNativeOverlay' in artwork
assert 'procPreviewArtworkFrames' in artwork and 'procArtworkFrames' in artwork
assert 'CreateAnimationGroup()' in artwork and 'CreateTexture(nil, "ARTWORK")' in artwork
assert 'frame.texture:SetBlendMode("BLEND")' in artwork
absent(artwork, [r'SetBlendMode\s*\(\s*"ADD"\s*\)'],
       "Live and TEST artwork keep the native-equivalent default blend behavior")
assert 'ResolveProcAppearance' in artwork and 'ProcPublicColor' in proc_runtime
assert 'StopProcArtwork()' in proc_runtime and 'GetProcArtworkDiagnostic(entry)' in proc_runtime
absent(artwork, [r"(?:overlay|record|owned)\.texture\s*:\s*(?:SetTexture|SetVertexColor|SetTexCoord|SetPoint|SetSize|CreateAnimationGroup)\s*\("],
       "Captured native textures are not rewritten or animated by the artwork renderer")
refresh = artwork.split('function addon:RefreshProcAppearance(entry)', 1)[1].split('function addon:', 1)[0]
absent(refresh, [r"RenderProcState|ConfigureProc|SetDuration|CreateNativeAuraSlot|RefreshMobility"],
       "Appearance edits refresh only owned presentation without restarting timer or gameplay providers")
assert 'GetProcAsset(item)' in resolver and 'procAppearanceLimits' in resolver
assert 'appearance = RegionAppearanceSetting' in database and 'CopyProcAppearance(region.appearance)' in database
assert 'ResetProcRegionAppearance' in database
assert 'ProcArtwork' not in (root / 'Modules/Proc/AuraState.lua').read_text(encoding='utf-8')
print("PASS Separate appearance schema/resolver, bounded artwork pools, lifecycle hooks and native suppression ownership ship without changing Aura slots")
print("Proc static checks passed; native security, actual matching and combat visuals require Retail acceptance.")
