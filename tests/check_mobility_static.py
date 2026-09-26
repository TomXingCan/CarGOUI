"""Small structural guardrails, not a secret-value/taint certification."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
mage_root = root / "Modules/CarGOUI_Data"
if not mage_root.is_dir():
    mage_root = root.parent / "CarGOUI_Data"
modules = [mage_root / "Classes/Mage/SpellState.lua", root / "Modules/Mobility/Runtime.lua"]
sources = {path: path.read_text(encoding="utf-8") for path in modules}


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
       "Reminder class styling has no alpha/text ownership, saved RGB, global-color edits or polling")
options = code((root / "UI/Options.lua").read_text(encoding="utf-8"))
absent(options, [r"ColorPicker", r"ColorSelect", r"SetupColorPickerAndShow",
                 r"GetColorRGB", r"SetColorRGB"],
       "Options contains no custom reminder color picker or RGB controls")
absent(runtime, [r"CarGOUIDB\s*[.\[]", r"self\.db[^\n]*=\s*(?:duration|charges|cooldown)"],
       "Runtime has no raw state writes into SavedVariables")
print("Static checks passed. These checks do not emulate WoW secret values, native APIs or taint.")
