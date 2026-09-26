"""Proc/native-aura structural guards; not a Retail secret-value or taint proof."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
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
absent(runtime, [r"OnUpdate", r"NewTicker", r"COMBAT_LOG", r"UNIT_SPELLCAST",
                 r"UnitBuff\s*\(", r"UnitAura\s*\(", r"C_UnitAuras", r"GetTime\s*\(",
                 r"pcall\s*\(", r"GetRemainingDuration\s*\(", r"GetFormattedText\s*\(",
                 r"\.expirationTime", r"\.applications"],
       "Proc and Free move have no polling, cast inference, addon aura scan, raw timer arithmetic or secret-state probing")
absent(runtime, [r"GetText\s*\(", r"GetStringWidth\s*\(", r"GetStringHeight\s*\(",
                 r"GetAlpha\s*\(", r"GetAuraSlotFrame\s*\(", r"GetAuraInstance\s*\("],
       "Proc never reads native aura child visibility, opacity, identity or timer text")
assert '"CustomAuraContainerTemplate"' in native
assert '"AuraContainer"' in native and ':SetUnit("player")' in native
assert 'container:AddAuraSlot(key, "HELPFUL"' in native
assert "candidateFilters = { includeSpellIDs = { [auraID] = true } }" in native
assert "button:SetDurationText(text, { binding = binding })" in native
assert "text:SetFontObject(font)" in native and "CreateFont(" in native
assert "self.container:SetEnabled(enabled)" in native
assert "self.container:Show()" in native
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
print("Proc static checks passed; native security, actual matching and combat visuals require Retail acceptance.")
