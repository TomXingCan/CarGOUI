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
options = source("UI/Options.lua")
assert not re.search(r"controls\.(?:font|fontSize|scale|outline|shadow)\s*=", options)
assert not re.search(r"ColorPicker|Apply Theme|themeSelector|SetColorRGB|classSelector|specSelector|profileSelector|loadModuleButton", options)
print("PASS Options has automatic style context and no manual class/spec/profile/theme/color/module controls")

toc = (root / "CarGOUI.toc").read_text(encoding="utf-8")
entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
           if line.strip() and not line.strip().startswith("#")]
assert not any(path in entries for path in ("Database/MobilityEntries.lua", "Database/PreviewEntries.lua",
                                            "Modules/Mobility/SpellState.lua"))
assert all("CarGOUI_Mage" not in path for path in entries)
mage_root = root / "Modules/CarGOUI_Mage"
if not mage_root.is_dir():
    mage_root = root.parent / "CarGOUI_Mage"
mage_toc = (mage_root / "CarGOUI_Mage.toc").read_text(encoding="utf-8")
assert re.search(r"^## LoadOnDemand:\s*1\s*$", mage_toc, re.M)
assert re.search(r"^## (?:Dependencies|RequiredDeps):\s*CarGOUI\s*$", mage_toc, re.M)
loader = source("Core/Modules.lua")
assert "C_AddOns.LoadAddOn" in loader and "InCombatLockdown" in loader
assert "PLAYER_REGEN_ENABLED" in loader and "loaded but inactive" in loader
print("PASS Mage business files use native LoD and core distinguishes loaded from active state")

core = "\n".join(source(path) for path in entries)
assert not re.search(r"collectgarbage\s*\(|UpdateAddOnMemoryUsage[^\n]*OnUpdate|NewTicker", core)
diagnostics = source("Core/Diagnostics.lua")
assert "GetAddOnMemoryUsage" in diagnostics and "GetAddOnCPUUsage" in diagnostics
assert "scriptProfile disabled" in diagnostics
assert not re.search(r"C_Timer|OnUpdate|SetCVar|collectgarbage", diagnostics)
print("PASS CPU/memory diagnostics use explicit runtime snapshots without polling, forced GC or profiling changes")
print("Scope/theme/loading static checks passed; actual-client behavior and performance remain to be accepted.")
