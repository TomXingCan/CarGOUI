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
assert not re.search(r"Apply Theme|themeSelector|SetColorRGB|classSelector|specSelector|profileSelector|loadModuleButton", options)
assert not re.search(r"controls\.(?:fontColor|mobilityColor|themeColor|classColor|opacity|alpha)\s*=", options)
print("PASS Options has automatic style context, scoped Proc-only RGB and no manual class/spec/profile/theme/module controls")
queue = options.split("function addon:QueueOptionsOpen()", 1)[1].split("local function ConsumeOptionsOpen", 1)[0]
assert 'self:RegisterEvent("PLAYER_REGEN_ENABLED", OnPendingOptionsCombatEnded)' in queue
assert "if not self.pendingOptionsOpen then" in queue and "self.pendingOptionsOpen = true" in queue
assert not re.search(r"CreateFrame|CreateOptions|C_Timer|CarGOUIDB|self\.db|OnUpdate|NewTicker", queue)
assert options.count("C_Timer.NewTimer(0,") == 1
retry = options.split("local function OnPendingOptionsCombatEnded", 1)[1].split("function addon:QueueOptionsOpen", 1)[0]
assert "not self.optionsOpenRetry" in retry and "self.optionsOpenRetry ~= retry" in retry
assert "self.pendingOptionsOpen and not InCombat()" in retry
assert not re.search(r"OnPendingOptionsCombatEnded\s*\(", retry.split("C_Timer.NewTimer(0,", 1)[1])
factory = options.split("function addon:CreateOptions()", 1)[1]
assert factory.index("if InCombat()") < factory.index("CreateFrame(")
opened = options.split("function addon:OpenOptions()", 1)[1].split("function addon:ToggleOptions", 1)[0]
assert opened.index("if InCombat()") < opened.index("self:CreateOptions()")
assert "if not panel:IsShown() then panel:Show() end" in opened and "ConsumeOptionsOpen(self)" in opened
assert "self.optionsOpenRetry:Cancel()" in options
assert not re.search(r"(?:CarGOUIDB|self\.db)[^\n]*pendingOptionsOpen", options)
print("PASS Options combat requests remain session-only, creation is guarded and one cancellable boundary retry uses explicit Show")

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
assert len(data_entries) == len(set(data_entries)), "Data TOC has duplicate business files"
assert data_entries[0] == "Bootstrap.lua" and data_entries[-1] == "Complete.lua", "Registration becomes complete only after all declarations"
actual_data_files = sorted(path.relative_to(mage_root).as_posix() for path in mage_root.rglob("*.lua"))
assert sorted(data_entries) == actual_data_files, "Data TOC and actual shipped business files must match exactly"
for name in data_entries:
    path = (mage_root / name).resolve()
    assert path.is_relative_to(mage_root.resolve()) and path.suffix == ".lua", "Unsafe business file declaration"
assert "Classes/Mage/SpellState.lua" in data_entries, "Validated Mage spell reader must remain shipped"
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
