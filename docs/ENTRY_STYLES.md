> Historical alpha.7 document. Per-spell/per-region styles were superseded by [Schema 5 scopes](CONFIG_SCOPES.md) in alpha.8. The historical red Alliance example was also superseded. Do not use this document as current setup guidance.

# Alpha.7: per-entry Appearance and automatic themes

An increment over alpha.6 (`3f903f6ac91a33232b9f36d57d9c47f03049cebb`), whose Blink/Shimmer behavior the user had confirmed. It did not modify SpellState.lua combat detection/native visibility or add live Proc/other-class monitoring. No WoW client was available; new styling and themes required client visual acceptance.

## Independent entry storage at this historical stage

Account-level `CarGOUIDB.styles[key]` stored `{font={face,size,outline},shadow={enabled},scale}`. Blink and Shimmer used `mobility_blink` and `mobility_shimmer`, respectively: each spell shared its own style across Mage specs but did not share with the other spell. Positions retained their existing `mage_*_shimmer` and unspecialized IDs; changing spell did not move saved coordinates.

Proc retained seven existing region IDs: Clearcasting left/right, Hot Streak left/right, Fingers of Frost left/right and Brain Freeze top. Every style/font/shadow table was independent. No mapping was added; Proc was still defined external simulation only.

Mobility → Appearance selected Blink or Shimmer; Proc selected the current spec's region before Appearance. The same-kind selector and native scroll area exposed all controls. Menus, switches and sliders saved immediately; numeric fields saved on Enter. Entry/category changes and closing discarded drafts. `Reset this entry's style` restored that style only, preserving coordinates and other entries.

Selecting the inactive Blink/Shimmer style could show an explicitly marked TEST sample. It did not change learned/override detection or enter live monitoring. Live used the actual detected spell; live and Preview shared the same entry record. Global Font/Scale editing and bulk style commands were removed. `/cui`, `/cargoui`, global position and visibility controls remained.

## One-time migration

Schema 3 or older to schema 4 validated global font/shadow/scale, then deep-copied valid values only into missing/invalid independent fields. Existing valid independent fields won. Separate copies broke historical aliases. Font path normalization preserved appearance, size and scale.

After migration, retired globals remained historical compatibility data, never renderer inheritance. Missing/new entries used factory defaults (Friz Quadrata / 24 / OUTLINE / Shadow on / Scale 1), not the previous entry or retired globals. Login did not overwrite valid settings. Reminder/window positions, switches and unknown fields remained; SavedVariables was not cleared.

`LayoutReminder` applied entry Scale once and compensated anchor offsets so resizing did not move the anchor. Live frame/text dimensions used the entry's font size, never secret digits. Preview shape guides used inverse entry Scale to retain their original size.

`RefreshReminderStyle(key)` updated only cached frames for that key. Styling did not query cooldowns, call SetDuration, read native text/alpha, restart a timer or replace native visibility. Shared class-color logic continued to call SetTextColor for label and digits; there was no color picker or saved character RGB at this stage.

## Historical automatic theme

Opening Options resolved faction/class/spec. Necessary identity events were subscribed only while visible and only the theme's own callbacks were removed on hide. Shared Mobility subscriptions were untouched. There was no manual theme, Apply Theme or theme-color editor.

The then-requested Alliance Arcane example used dark red → arcane purple. **That historical request was later revoked: current Alliance Headers are blue, and Body follows specialization.** The other five combinations and neutral/Mage fallback are documented in [theme mapping/API review](THEMES.md). Colors lived in Database/Themes.lua; native static gradients, a few reused low-opacity geometric textures and the existing branding-accent interface avoided tinting the whole blue/gold logo. Animation toggle and combat-stop rules remained.

## Historical acceptance checklist

Replace program files, keep WTF/SavedVariables, verify `0.1.0-alpha.7`, and compare pre/post-upgrade size, coordinates and window position before opening `/cui`.

| Check | Action and expected result for alpha.7 |
| --- | --- |
| Mobility independence | Edit Blink font/size/outline/shadow/scale; Shimmer and Proc stay unchanged. Shimmer shows its own saved values. |
| Proc-region independence | Edit a left region's size; its right counterpart and other regions stay unchanged. Proc clearly says Preview only. |
| Same-entry agreement | External TEST and live depletion use the same font, size, outline, shadow, Scale and fixed class color. |
| Drafts/spec/reload | Change a numeric draft without Enter and switch entries; it must not carry over. Returning shows the saved value. Spec changes and `/reload` preserve independent values. |
| Upgrade preservation | Nondefault typography/scale/offsets preserve appearance/anchor. Editing records does not couple them; reset leaves position alone. Offline tests separately verify no table aliasing. |
| Historical Alliance Arcane | Automatic dark red→purple at this stage; read-only Automatic/identity information, no manual selector. This color expectation is superseded. |
| Spec changes | Visible Options updates theme; reminder styles/coordinates remain saved. Reopening resolves the current identity. |
| Fallback | Missing spec/faction or unsupported identity uses neutral/class fallback, never a guessed Arcane theme. Unavailable character cases are recorded as untested. |
| Combat regression | Blink/Shimmer hide with one use available, show true next recovery when depleted, and hide immediately after one recovery; continue after Options/TEST closes. |
| Style during active timing | Editing that spell's style keeps progress/anchor, without flashing, full-CD restart or secret/taint errors. Editing another entry does not touch the timer. |

Also inspect Appearance's bottom Reset/Preview/Back controls, gradient/text contrast, original branding glyphs and disabled/combat animation stop. Record untested combinations explicitly.

Historical offline/static/extracted-ZIP results are in `CarGOUI-alpha.7-Test-Results.txt`. Native API doubles verify script contracts, not live secret/taint, gradients, focus or layout. Earlier user-confirmed combat behavior was not expanded into acceptance of the entire new package.
