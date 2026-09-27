"""Check the shipped launcher boundary; native manager behavior still needs WoW acceptance."""
import argparse
import hashlib
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--addon-root", type=Path, default=Path(__file__).resolve().parent.parent)
root = parser.parse_args().addon_root.resolve()
read = lambda path: (root / path).read_text(encoding="utf-8")
code = lambda text: re.sub(r"--[^\n]*", "", text)
toc = read("CarGOUI.toc")
entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
           if line.strip() and not line.strip().startswith("#")]

# Official upstream v12.0.3 / SVN r162, independently acquired by API audit.
# Normalize platform line endings only; no logic/source substitutions permitted.
vendors = {
    "Libs/LibStub/LibStub.lua": "f93f7dfbd280c0f8e0328bb194faa6db541c3c50b3d4d37eb064c816f0ec5576",
    "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua": "84a15af505e728ac5e5eb6a8eaba8989d1131d5f8ba14d11abcfe4ce086de3c1",
    "Libs/LibDataBroker-1.1/LibDataBroker-1.1.lua": "f3d4758f2060215492c9764b1d7dc2a336826d4cd253cd54ff9ff7c6d78f04e2",
    "Libs/LibDBIcon-1.0/LibDBIcon-1.0.lua": "85c426947fa50319071b64c7cb845326c44316341713a3847dc8149c1e36716b",
}
assert entries[:4] == list(vendors), "Native Lua dependencies must load in upstream dependency order"
for path, expected in vendors.items():
    assert entries.count(path) == 1
    assert hashlib.sha256((root / path).read_bytes().replace(b"\r\n", b"\n")).hexdigest() == expected, path
assert entries.index("UI/Options.lua") < entries.index("UI/Launcher.lua") < entries.index("Core/Initialize.lua")
print("PASS Actual pinned library sources are intact and loaded exactly once in dependency order")

data_root = root / "Modules/CarGOUI_Data"
if not data_root.exists():
    data_root = root.parent / "CarGOUI_Data"
data_toc = (data_root / "CarGOUI_Data.toc").read_text(encoding="utf-8")
icon = r"Interface\AddOns\CarGOUI\Media\Branding\emblem.tga"
for text in (toc, data_toc):
    assert re.search(r"^## IconTexture:\s*" + re.escape(icon) + r"\s*$", text, re.M)
assert (root / "Media/Branding/emblem.tga").is_file()
assert len(re.findall(r"^## AddonCompartmentFunc:", toc, re.M)) == 1
assert "## AddonCompartmentFunc: CarGOUI_OnAddonCompartmentClick" in toc
assert "AddonCompartmentFunc:" not in data_toc, "Internal Data is not a second launcher"
print("PASS Both AddOn rows have the packaged icon; only main CarGOUI declares a compartment entry")

launcher = code(read("UI/Launcher.lua"))
assert 'type = "launcher"' in launcher and 'local NAME = "CarGOUI"' in launcher
assert "return addon:ToggleOptions()" in launcher
assert 'MouseButton(first, second) ~= "LeftButton"' in launcher
assert all(name in launcher for name in ("IsControlKeyDown", "IsShiftKeyDown", "IsAltKeyDown", "rawget", "issecretvalue"))
assert not re.search(r"CreateFrame|CreateOptions|OpenOptions|RegisterAddon|C_Timer|OnUpdate|NewTicker|RegisterEvent|GetText|GetAlpha|C_Spell|C_UnitAuras", launcher)
assert not re.search(r":Refresh\s*\(|:SetScript\s*\(|:SetParent\s*\(|collectgarbage", launcher)
assert 'button:HookScript("OnHide"' in launcher and 'stopDrag(frame)' in launcher
assert 'button:GetParent() == Minimap' in launcher and 'button:GetParent() ~= Minimap' in launcher
assert "HasMinimapLayout(button)" in launcher and "HasMinimapLayout(frame)" in launcher
assert 'button:GetPoint(1)' in launcher and 'relative == Minimap' in launcher
print("PASS Launcher delegates Options, rejects unsafe click assumptions, and cannot override collector scripts or poll gameplay")

db = code(read("Core/Database.lua"))
backend = code(read("Core/SettingsTransfer.lua"))
assert "RefreshLauncherSettings" in db and "RefreshLauncherSettings" in backend
assert "launcherMinimapSettings" in launcher and "self.db.options.minimap = db" in launcher
assert "local hide, position = source.hide, source.minimapPos" in launcher
assert "controls.showMinimapIcon" in read("UI/Options.lua")
print("PASS Whitelisted shell changes synchronize the registered config reference without copying manager state")
print("Launcher static checks passed; real client and installed icon-manager acceptance remain separate.")
