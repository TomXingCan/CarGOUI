"""Structural boundaries only; not a substitute for WoW native rendering tests."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent

def source(path):
    return re.sub(r"--[^\n]*", "", (root / path).read_text(encoding="utf-8"))

display = source("UI/Display.lua")
preview = source("UI/Preview.lua")
assert not re.search(r"(?:self\.)?db\.(?:font|shadow|scale)\b", display + preview)
print("PASS Reminder renderers do not inherit legacy global font/shadow/scale")
targeted = display.split("function addon:RefreshReminderStyle", 1)[1].split("function addon:ApplySettings", 1)[0]
assert not re.search(r"C_Spell|SetDuration\s*\(|SetAlpha\s*\(|GetAlpha\s*\(|GetText\s*\(|RefreshMobility|RenderLiveMobility", targeted)
print("PASS Entry styling cannot query combat state, rebind duration, or read/write native opacity/text")
theme = source("UI/Theme.lua")
assert not re.search(r"OnUpdate|NewTicker|C_Timer|C_Spell|SetFont\s*\(|UpdateSettings|RefreshMobility|RenderLiveMobility|CarGOUIDB", theme)
assert "UpdateBrandingTheme" in theme and "SetGradient" in theme
print("PASS Automatic theme changes only Options surfaces, with no polling or reminder/configuration writes")
options = source("UI/Options.lua")
assert not re.search(r"controls\.(?:font|fontSize|scale|outline|shadow)\s*=", options)
assert not re.search(r"ColorPicker|Apply Theme|themeSelector|SetColorRGB", options)
print("PASS Options exposes entry appearance instead of global styles or manual theme/color controls")
print("Style/theme static checks passed; actual-client layout and appearance remain to be accepted.")
