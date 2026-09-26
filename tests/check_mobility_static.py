"""Small structural guardrails, not a secret-value/taint certification."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
data_root = root / "Modules/CarGOUI_Data"
if not data_root.is_dir():
    data_root = root.parent / "CarGOUI_Data"
toc = (data_root / "CarGOUI_Data.toc").read_text(encoding="utf-8")
declared = [line.strip().replace("\\", "/") for line in toc.splitlines()
            if line.strip() and not line.strip().startswith("#")]
assert len(declared) == len(set(declared)), "Data TOC contains duplicate Lua entries"
business = sorted(path.relative_to(data_root).as_posix() for path in data_root.rglob("*.lua"))
assert sorted(declared) == business, "Every business Lua source must be loaded and audited; no orphan or omitted implementation"
for name in declared:
    path = (data_root / name).resolve()
    assert path.is_relative_to(data_root.resolve()) and path.suffix == ".lua", "Unsafe Data TOC entry"
modules = [data_root / name for name in declared] + [root / "Modules/Mobility/Runtime.lua", root / "Core/Modules.lua"]
sources = {path: path.read_text(encoding="utf-8") for path in modules}
print(f"PASS Auditing all {len(declared)} declared Data Lua files plus runtime and adapter dispatcher")


def code(text):
    return re.sub(r"--[^\n]*", "", text)


def absent(text, patterns, label):
    for pattern in patterns:
        assert not re.search(pattern, text), f"{label}: disallowed path {pattern}"
    print("PASS " + label)


runtime = "\n".join(code(text) for text in sources.values())
absent(runtime, [r"OnUpdate", r"NewTicker", r"COMBAT_LOG", r"UNIT_SPELLCAST",
                 r"UnitBuff\s*\(", r"UnitAura\s*\(", r"C_UnitAuras",
                 r"IsSpellUsable", r"GetSpellLossOfControl", r"pcall\s*\("],
       "Mobility has no polling, cast counting, aura scan, usability/LoC substitute or error-probing path")
absent(runtime, [r"GetTime\s*\(", r"\.cooldownStartTime", r"\.cooldownDuration",
                 r"\.chargeModRate", r"GetRemainingDuration\s*\(", r"GetFormattedText\s*\("],
       "Mobility does not calculate, stringify or recover raw native timing")
display = (root / "UI/Display.lua").read_text(encoding="utf-8")
live = code(display[display.index("function addon:RenderLiveMobility"):])
absent(live, [r"GetText\s*\(", r"GetStringWidth\s*\(", r"GetStringHeight\s*\(",
              r"GetFormattedText\s*\(", r"string\.format", r"tostring\s*\(",
              r"RenderReminder\s*\(", r"GetAlpha\s*\("],
       "Native live rendering never uses or measures the ordinary string output path")
absent(runtime, [r"GetAlpha\s*\(", r":Evaluate\s*\("],
       "Runtime never reads native opacity or passes a charge count to Curve.Evaluate")
assert re.search(r"frame:SetAlpha\(visibility\.duration:EvaluateTotalDuration\(visibility\.curve,\s*"
                 r"Enum\.DurationTimeModifier\.BaseTime\)\)", live)
print("PASS Native curve result goes directly to SetAlpha without a Lua fallback or transformation")
style = code((root / "UI/ReminderStyle.lua").read_text(encoding="utf-8"))
absent(style, [r"SetAlpha\s*\(", r"SetText\s*\(", r"OnUpdate", r"NewTicker",
               r"self\.db", r"CarGOUIDB", r"RAID_CLASS_COLORS", r"CUSTOM_CLASS_COLORS"],
       "Reminder styling changes owned Font color without alpha/text ownership, direct SavedVariables access, global-color edits or polling")
options = code((root / "UI/Options.lua").read_text(encoding="utf-8"))
absent(options, [r"controls\.(?:mobility|freeMove|global)[A-Za-z_]*(?:Color|RGB)",
                 r"controls\.(?:color|rgb|opacity|alpha)\s*=", r"\bColorSelect\b",
                 r"SetColorRGB"],
       "Options has no Mobility, Free move, global color or opacity controls; Proc color is checked separately")
assert 'entry.kind == "proc"' in style and "GetProcRegionColor(entry)" in style
assert "ResolveClassColor(self, false)" in style
print("PASS Only Proc entries consult region RGB; Mobility and Free move retain dynamic class color")
absent(runtime, [r"CarGOUIDB\s*[.\[]", r"self\.db[^\n]*=\s*(?:duration|charges|cooldown)"],
       "Runtime has no raw state writes into SavedVariables")
print("Static checks passed. These checks do not emulate WoW secret values, native APIs or taint.")
