"""Settings-transfer trust/lifecycle guards against the actual installed sources.

These structural checks complement the Lua 5.1 malicious-input and roundtrip
tests. Neither suite substitutes for native WoW C_EncodingUtil acceptance.
"""
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--addon-root", type=Path, default=Path(__file__).resolve().parent.parent)
root = parser.parse_args().addon_root.resolve()


def read(relative):
    return (root / relative).read_text(encoding="utf-8")


def code(text):
    return re.sub(r"--[^\n]*", "", text)


def section(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def absent(text, patterns, label):
    for pattern in patterns:
        assert not re.search(pattern, text), f"{label}: forbidden path {pattern}"
    print("PASS " + label)


toc = [line.strip().replace("\\", "/") for line in read("CarGOUI.toc").splitlines()
       if line.strip() and not line.strip().startswith("#")]
for relative in ("Database/SettingsMetadata.lua", "Core/SettingsTransfer.lua", "UI/SettingsTransfer.lua"):
    assert toc.count(relative) == 1, f"Required transfer source is loaded exactly once: {relative}"
    assert (root / relative).is_file()
assert toc.index("Core/Database.lua") < toc.index("Database/SettingsMetadata.lua") < toc.index("Core/SettingsTransfer.lua")
assert toc.index("UI/SettingsTransfer.lua") < toc.index("UI/Options.lua")
assert not any(path.startswith(("tests/", "scripts/")) for path in toc)
print("PASS Transfer metadata, backend and page are manifest-loaded in dependency order; test fixtures are not runtime dependencies")

metadata = code(read("Database/SettingsMetadata.lua"))
backend = code(read("Core/SettingsTransfer.lua"))
ui = code(read("UI/SettingsTransfer.lua"))
options = code(read("UI/Options.lua"))
absent(metadata, [r"function\b", r"\b(?:auraID|spellID|overlayID|textureID)\b", r"Create(?:Frame|Font)",
                  r"Register(?:Event|ProcFactory|Adapter)", r"C_Spell|C_UnitAuras|C_Timer|CarGOUIDB"],
       "Import ownership metadata is inert class/spec/region data, with source-catalog equality independently checked in Lua")
assert "addon.settingsMetadata" in metadata and "schemaVersion = 5" in metadata
absent(backend + ui, [r"\b(?:load|loadstring|dofile|loadfile|RunScript|RunMacroText)\s*\(",
                     r"\b(?:io|os|package)\s*[.\[]", r"OnUpdate|NewTicker|collectgarbage",
                     r"C_Spell|C_UnitAuras|COMBAT_LOG|UNIT_SPELLCAST", r"LoadAddOn\s*\("],
       "Transfer never executes pasted text, accesses files, starts polling, loads adapters or reads protected gameplay state")
absent(backend, [r":(?:SetAlpha|SetDuration|GetRemainingDuration|GetFormattedText|GetAuraSlotFrame)\s*\("],
       "Transfer cannot overwrite or inspect native timer/visibility state")

assert all(name in backend for name in ("inputBytes", "decodedBytes", "depth", "tokens", "entries"))
scanner = section(backend, "local function ScanJSON(text)", "local function Map(")
assert "limits.depth" in scanner and "limits.tokens" in scanner and "limits.entries" in scanner
assert 'keys[key]' in scanner and 'emptyArray' in scanner and 'null' in scanner
decoder = section(backend, "local function Decode(text)", "local function Context(self)")
assert decoder.index("#text > limits.inputBytes") < decoder.index("api.DecodeBase64")
assert decoder.index("#payload / 4 * 3") < decoder.index("api.DecodeBase64")
assert decoder.index("ScanJSON(decoded)") < decoder.index("api.DeserializeJSON")
assert 'CARGOUICFG:' in decoder and 'version ~= "1"' in decoder
assert "encoded ~= payload" in decoder
for name in ("SerializeJSON", "DeserializeJSON", "EncodeBase64", "DecodeBase64"):
    assert f"api.{name}" in backend
assert "ignoreSerializationErrors = false" in backend
assert "value ~= value" in backend and "getmetatable(value)" in backend
print("PASS Size budgets and full duplicate-key/depth/type scanner precede native decoding; native codec output is checked")

validator = section(backend, "local function ValidateEnvelope(", "local function SavedPosition(")
assert all(token in validator for token in ("formatVersion", "schemaVersion", "addonVersion", "project", "scope"))
assert "self.settingsMetadata.classes" in validator and "roster[spec]" in validator
assert all(f"Number(region.color.{component}, 0, 1" in validator for component in "rgb")
assert "client-default" in backend and "GetSharedMediaFontName" in backend and "GetReminderFontStatus" in backend
font_export = section(backend, "local function FontToken(", "local function FontPath(")
assert "IsSupportedFont" in font_export and "GetSharedMediaFontName" in font_export
absent(font_export, [r"CreateFont|SetFont|GetFont|GetReminderFontStatus|ResolveReminderFont|Fetch|HashTable"],
       "Font export preserves logical identity without probing client resources or consulting registry availability")
absent(backend, [r"CreateFont\s*\(|SetFont\s*\(|GetFont\s*\("],
       "Import delegates local font availability to the shared resource resolver")
snapshot = section(backend, "local function Snapshot(self, scope)", "local function Codec()")
assert "classes = {}" in snapshot and "local target = {}" in snapshot
absent(snapshot, [r"settingsImportBackup|pendingOptionsOpen|previewState|procColorPicker|playerName|GUID|debugLog",
                  r"self\s*:\s*(?:GetMobilityConfig|GetProcConfig|GetClassConfig|UpdateSettings)\s*\("],
       "Export builds fresh whitelisted snapshots without runtime/draft/identity/backup data or mutating configuration getters")
assert "for spec, proc in pairs(record.proc)" in snapshot
assert "target.proc[tostring(spec)]" in snapshot
assert 'scope == "all"' in snapshot
print("PASS Schema identities, symbolic fonts, finite RGB and saved-only scope snapshots are explicit")
assert 'Keys("position color appearance")' in validator
assert 'ValidateProcAppearance(value)' in backend and 'CopyProcAppearance(value)' in backend
assert 'mode assetKey artColor desaturation alpha scale width height rotation mirrorX mirrorY offset animation' in backend
assert 'for id in pairs(appearances) do self:RefreshProcAppearance({ id = id }) end' in backend
appearance = code(read("Core/ProcAppearance.lua"))
assert 'GetProcAsset(item)' in appearance and 'procAppearanceEnums' in appearance
assert 'value == value' in appearance and 'getmetatable(value) == nil' in appearance
assert 'schemaVersion = 5' in code(read("Config/Defaults.lua"))
print("PASS Additive appearance transfer retains schema 5/format 1 and rejects unlisted resources and unbounded presentation settings")

context = section(backend, "local function Context(self)", "local function MergeCandidate(")
assert "InCombatLockdown()" in context and "panel:IsShown()" in context
assert "class = class" in context and "category = panel.activeCategory" in context and "db = self.db" in context
commit = backend.split("function addon:ConfirmSettingsImport(transaction)", 1)[1]
assert "local pending" in backend and "record.handle ~= transaction" in commit
assert "transaction.summary ~= record.summary" in commit and "for key in pairs(transaction)" in commit
assert commit.index("Context(self)") < commit.index("self.db.classes =")
assert commit.index('Snapshot(self, "all")') < commit.index("self.db.classes =")
assert commit.index("Serialize(record.before)") < commit.index("self.db.classes =")
assert commit.index("CancelProcColorPicker()") < commit.index("self.db.classes =")
assert commit.index("StopPreview(true)") < commit.index("self.db.classes =")
assert "record.restore and self.db.settingsImportBackup" in commit
assert "settings = Copy(record.before)" in commit and "self.db.settingsImportBackup = backup" in commit
absent(commit, [r"self\.db\s*=", r"CarGOUIDB\s*=", r"C_Timer"],
       "Confirmation revalidates synchronously, retains SavedVariables root identity and has no deferred commit")
apply = section(backend, "local function ApplyTransferredSettings(", "function addon:ConfirmSettingsImport(")
assert "if mobilityEnabled then" in apply and "if procEnabled then" in apply
assert "elseif wasPreview" in apply and 'RefreshReminderPositions(changes)' in apply
assert 'RefreshReminderStyle("mobility:"' in apply and 'RefreshProcRegionColor(entry)' in apply
print("PASS Private transactions, atomic pre-import backup, repeat-restore semantics and targeted appearance refresh are guarded")

assert 'if panel.transfer then return panel.transfer end' in ui
assert 'edit:SetMultiLine(true)' in ui and 'edit:SetMaxLetters(0)' in ui and 'edit:SetMaxBytes(0)' in ui
on_text = section(ui, 'edit:SetScript("OnTextChanged"', 'edit:SetScript("OnCursorChanged"')
absent(on_text, [r"PrepareSettings|ConfirmSettings|DeserializeJSON|DecodeBase64|ExportSettings"],
       "Typing only invalidates review and resizes text; payload parsing waits for explicit Import")
editor = section(ui, "local function Editor(", "ui.Label(body, L.transferHint")
absent(editor, [r"RegisterOptionsDragSurface\s*\(", r"RegisterForDrag\s*\("],
       "Full-text editors and scroll surfaces retain normal input and selection instead of dragging Options")
cleanup = section(ui, "function addon:ClearSettingsTransferPage()", "function addon:RefreshSettingsTransferPage()")
assert "CancelSettingsImport" in cleanup and 'edit:SetText("")' in cleanup and "edit:ClearFocus()" in cleanup
assert 'panel.activeCategory == "importExport"' in ui and 'InCombatLockdown()' in ui
assert 'Feedback(ok and (message or L.transferDone)' in ui
assert 'if not self.optionsPageRegistry[key] then key = "general" end' in options
absent(options, [r'pages\.themes', r'categoryButtons\.themes', r'RefreshOptionsThemeLabels', r'key\s*=\s*"themes"'],
       "Removed Themes route has no page or label updater; unknown old route falls back to General")
locale = read("Config/Locale.lua")
assert "Drag any empty area to move" not in locale and "拖动任意空白区域" not in locale
assert "RegisterOptionsDragSurface" in options and "BeginOptionsDrag" in options
assert "Database/Themes.lua" in toc and "UI/Theme.lua" in toc
print("PASS Transfer lifecycle clears uncommitted state; removed labels/page do not remove dragging or automatic theme engine")
print(f"All settings-transfer static checks passed against {root}.")
