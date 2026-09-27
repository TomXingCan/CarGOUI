"""Localization resource, initialization and protected-timer structural checks.

These checks do not certify native glyph rendering or native-speaker review.
"""
from pathlib import Path
import argparse
import json
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--addon-root', type=Path, default=Path(__file__).resolve().parent.parent)
root = parser.parse_args().addon_root.resolve()
def source(path): return (root / path).read_text(encoding='utf-8-sig')
locales = ('enUS', 'zhCN', 'zhTW', 'deDE', 'frFR', 'esES', 'itIT', 'ruRU')
string = r'"(?:\\.|[^"\\])*"'
pair = re.compile(r'^\s*\[(' + string + r')\]\s*=\s*(' + string + r'),\s*$', re.M)
tables = {}
for locale in locales:
    text = source('Locales/' + locale + '.lua')
    matches = pair.findall(text)
    tables[locale] = {json.loads(k): json.loads(v) for k, v in matches}
    assert len(matches) == len(tables[locale]), locale + ': duplicate key'
    if locale != 'enUS':
        guard = 'if addon.locale ~= "' + locale + '" then return end'
        assert guard in text and text.index(guard) < text.index('addon:RegisterLocale('), locale
        assert text.index(guard) < text.index('{'), locale + ': table must not be constructed before guard'
base = tables['enUS']
assert base and all(key == value for key, value in base.items())
def formats(value):
    return re.findall(r'%[-+ #0]*\d*\.?\d*[cdeEfgGiouXxqs]', value.replace('%%', ''))
for locale, table in tables.items():
    assert table.keys() == base.keys(), (locale, 'dictionary keys differ', base.keys() - table.keys(), table.keys() - base.keys())
    for key, value in table.items():
        assert formats(value) == formats(base[key]), (locale, key, 'format mismatch')
        assert value.count('{}') == base[key].count('{}'), (locale, key, 'native placeholder')
        assert value.count('\n') == base[key].count('\n'), (locale, key, 'line boundaries')
    if locale != 'enUS':
        assert sum(value != base[key] for key, value in table.items()) > len(base) * .8, locale + ': incomplete translation'
print('PASS Eight complete dictionaries; printf/native placeholders and line boundaries match; inactive tables return before construction')

entries = [line.strip().replace('\\', '/') for line in source('CarGOUI.toc').splitlines()
           if line.strip() and not line.startswith('#')]
ordered = ['Config/Locale.lua'] + ['Locales/' + locale + '.lua' for locale in locales] + ['Config/LocaleFinalize.lua', 'Core/LocalizedNames.lua']
assert [entries.index(path) for path in ordered] == sorted(entries.index(path) for path in ordered)
for path in entries:
    if path.startswith(('UI/', 'Modules/', 'Database/', 'Config/Defaults')):
        assert entries.index(path) > entries.index(ordered[-1]), path
selection = source('Config/Locale.lua')
assert selection.count('GetLocale()') == 1
assert 'requested == "enGB"' in selection and 'requested == "esMX"' in selection
assert 'or "enUS"' in selection
assert not re.search(r'SavedVariables|self\.db|CarGOUIDB|OnUpdate|NewTicker|C_Timer|GetCVar', selection)
assert 'current and current[source]' in selection and 'english and english[source]' in selection
print('PASS Client locale resolves before all authored UI/entries; aliases/fallback have no language preference or polling')

lookup = re.compile(r':(?:Text|Format)\(\s*(' + string + ')')
for path in entries:
    if path.startswith(('Libs/', 'Locales/')): continue
    for literal in lookup.findall(source(path)):
        key = json.loads(literal)
        assert key in base, (path, 'untranslated authored source key', key)
options = source('UI/Options.lua') + source('UI/SettingsTransfer.lua')
commands = source('Config/Commands.lua')
assert not re.search(r'(?:language|locale)\s*=|[.]pages[.](?:language|locale)|command\s*==\s*"(?:language|locale)"', options + commands, re.I)
names = source('Core/LocalizedNames.lua')
assert 'C_Spell.GetSpellName' in names and 'SPELL_DATA_LOAD_RESULT' in names and 'LIMIT = 128' in names
assert not re.search(r'GetSpellCooldown|GetSpellCharges|GetAura|GetText\(|GetAlpha\(|GetStringWidth|OnUpdate|NewTicker|C_Timer', names)
display = source('UI/Display.lua')
update = display.split('function addon:UpdateMobilityTextFormat', 1)[1].split('\nend', 1)[0]
assert 'SetTextFormat' in update and '"\\n{}"' in update
assert not re.search(r'SetDuration|SetAlpha|GetText|GetFont|GetWidth|GetString', update)
assert 'AcquireAuraReminder(entry, entry.auraID, self:Text("Free move"))' in source('Modules/Mobility/FreeMove.lua')
print('PASS Authored lookup keys exist; language controls absent; stable ID name cache cannot query gameplay or read native timer state')

fonts = source('UI/ReminderStyle.lua')
assert 'CarGOUIReminderFontProbe' in fonts and 'fontProbe:GetFont()' in fonts
assert not re.search(r'text:GetFont\(|frame[.]text:GetFont\(|STANDARD_TEXT_FONT\s*=|GameFont\w+\s*=', fonts)
assert 'return face or fallback' in source('Core/SettingsTransfer.lua')
assert 'clientFontPaths' in source('Config/Defaults.lua')
assert 'button:GetFontString()' in options and 'label:SetWordWrap(true)' in options
assert not re.search(r'utf8?.*sub\(|label:sub\(|text:sub\(', options, re.I)
print('PASS Font availability probes only an owned public Font; saved choices remain separate; Options wraps full text without byte truncation')
print('Localization static checks passed; real-client layout and native-speaker review remain separate.')
