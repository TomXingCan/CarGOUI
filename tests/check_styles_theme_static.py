"""Structural boundaries only; not a substitute for WoW native rendering tests."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent

def source(path):
    return re.sub(r"--[^\n]*", "", (root / path).read_text(encoding="utf-8"))

display = source("UI/Display.lua")
preview = source("UI/Preview.lua")
assert not re.search(r"(?:self\.)?db\.(?:font|shadow|scale|position|styles|reminders)\b", display + preview)
print("PASS Reminder renderers read scoped styles/positions and never inherit legacy global appearance")
targeted = display.split("function addon:RefreshReminderStyle", 1)[1].split("function addon:ApplySettings", 1)[0]
assert not re.search(r"C_Spell|SetDuration\s*\(|SetAlpha\s*\(|GetAlpha\s*\(|GetText\s*\(|RefreshMobility|RenderLiveMobility", targeted)
print("PASS Context styling cannot query combat state, rebind duration, or read/write native opacity/text")
theme = source("UI/Theme.lua")
assert not re.search(r"OnUpdate|NewTicker|C_Timer|C_Spell|SetFont\s*\(|UpdateSettings|RefreshMobility|RenderLiveMobility|CarGOUIDB", theme)
assert "UpdateBrandingTheme" in theme and "SetGradient" in theme
print("PASS Automatic theme changes only Options surfaces, with no polling or reminder/configuration writes")
assert "optionThemeClasses[classToken]" in theme and "class.specs[specID]" in theme
assert not re.search(r"GetMobilityState|GetMobilityStatus|GetMobilityConfig|GetReminderStyle|EnsureCurrentClassModule|RegisterClassAdapter|mobilityTracking", theme)
theme_data = source("Database/Themes.lua")
assert not re.search(r"C_AddOns|C_Spell|C_Timer|RegisterEvent|CreateFrame|CarGOUIDB|GetProcConfig|GetMobilityConfig", theme_data)
print("PASS All-class Body selection uses class-qualified specialization keys independently of gameplay adapters and configuration")
options = source("UI/Options.lua")
assert not re.search(r"controls\.(?:font|fontSize|scale|outline|shadow)\s*=", options)
assert not re.search(r"ColorPicker|Apply Theme|themeSelector|SetColorRGB|classSelector|specSelector|profileSelector|loadModuleButton", options)
print("PASS Options has automatic style context and no manual class/spec/profile/theme/color/module controls")

toc = (root / "CarGOUI.toc").read_text(encoding="utf-8")
entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
           if line.strip() and not line.strip().startswith("#")]
assert not any(path in entries for path in ("Database/MobilityEntries.lua", "Database/PreviewEntries.lua",
                                            "Modules/Mobility/SpellState.lua"))
assert all("CarGOUI_Data" not in path for path in entries)
mage_root = root / "Modules/CarGOUI_Data"
if not mage_root.is_dir():
    mage_root = root.parent / "CarGOUI_Data"
mage_toc = (mage_root / "CarGOUI_Data.toc").read_text(encoding="utf-8")
assert re.search(r"^## LoadOnDemand:\s*1\s*$", mage_toc, re.M)
assert re.search(r"^## (?:Dependencies|RequiredDeps):\s*CarGOUI\s*$", mage_toc, re.M)
loader = source("Core/Modules.lua")
assert "C_AddOns.LoadAddOn" in loader and "InCombatLockdown" in loader
assert "PLAYER_REGEN_ENABLED" in loader and "loaded; no current adapter active" in loader
assert 'C_AddOns.LoadAddOn("CarGOUI_Data")' in loader
assert not re.search(r'C_AddOns\.LoadAddOn\("CarGOUI_Mage"\)', loader)
data_entries = [line.strip().replace("\\", "/") for line in mage_toc.splitlines()
                if line.strip() and not line.strip().startswith("#")]
assert data_entries == ["Bootstrap.lua", "Classes/Mage/Bootstrap.lua", "Classes/Mage/MobilityEntries.lua",
                        "Classes/Mage/PreviewEntries.lua", "Classes/Mage/SpellState.lua",
                        "Classes/Mage/Register.lua", "Complete.lua"]
assert "RegisterClassAdapter" in loader and "activeClassAdapter" in loader
assert not (root / "Modules/CarGOUI_Mage/CarGOUI_Mage.toc").exists()
print("PASS One native Data package registers isolated adapters and distinguishes loaded files from current activation")

assert "surfaces.headerKey ~= info.headerKey" in theme and "surfaces.bodyKey ~= info.bodyKey" in theme
assert 'CreateLine(nil, "BACKGROUND", nil, 3)' in theme
assert ":SetStartPoint(" in theme and ":SetEndPoint(" in theme and ":SetThickness(" in theme
assert not re.search(r"SetRotation\s*\(", theme)
assert not re.search(r"CreateFrame\s*\(|CreateAnimationGroup|NewTicker|OnUpdate", theme)
assert 'surface:RegisterForDrag("LeftButton")' in options
assert "surface.optionsDragSurface" in options and 'surface:HookScript("OnMouseUp"' in options
print("PASS Header/Body update independently; watermark and dragging add no animated or input-blocking overlay frame")

core = "\n".join(source(path) for path in entries)
assert not re.search(r"collectgarbage\s*\(|UpdateAddOnMemoryUsage[^\n]*OnUpdate|NewTicker", core)
diagnostics = source("Core/Diagnostics.lua")
assert "GetAddOnMemoryUsage" in diagnostics and "GetAddOnCPUUsage" in diagnostics
assert "scriptProfile disabled" in diagnostics
assert not re.search(r"C_Timer|OnUpdate|SetCVar|collectgarbage", diagnostics)
print("PASS CPU/memory diagnostics use explicit runtime snapshots without polling, forced GC or profiling changes")
print("Scope/theme/loading static checks passed; actual-client behavior and performance remain to be accepted.")
