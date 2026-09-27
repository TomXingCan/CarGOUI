# alpha.13 incremental upgrade and user retest

Baseline: alpha.12 commit `74d452516c1ce78ef213128133f95616f5df7707`. This historical increment repaired Clearcasting and added Proc region RGB. It did not expand other-class Proc, special Mobility or themes.

## Installation

1. Exit WoW. Back up existing program directories, then replace **CarGOUI + CarGOUI_Data** together under `_retail_/Interface/AddOns/`.
2. Each directory must directly contain its same-named TOC, version `0.1.0-alpha.13`. Remove only an obsolete `AddOns/CarGOUI_Mage` program directory, if present.
3. **Keep WTF, CarGOUIDB and all SavedVariables.** Schema 5, Clearcasting region IDs, saved coordinates, shared fonts, Mobility, Options placement and branding switches remain.
4. The only new field is optional `color={r,g,b}` per Proc region. Absence means dynamic class color. Valid RGB is copied independently; invalid values safely fall back. Other saved classes are not reinitialized.

## Clearcasting repair and evidence

Alpha.12 accepted only graphics owner `276743` and also used it as its timer Aura. Target build **69933** adds owners `1277420 / 1277421 / 1277422`. These are indefinite Dummy graphic carriers, not countdown sources. Missing those SHOW events could also leave a region in an old HIDE state.

Alpha.13 uses only finite-duration Aura **263725** as the native timer filter and handles the three graphic owners separately. Graphic transitions retain the original left/right regions and bindings; an old owner's HIDE cannot clear a new active owner. It does not mix 276743, 277726 or the three Dummy graphics into alternative timer candidates, read stacks, count casts or invent durations.

Evidence includes target DB2, Blizzard's official Clearcasting stack-graphics explanation and current Mage implementations using the actual Clearcasting Aura. **The association is source-supported; it was not directly observed in the user's client, and complete server-side association code is not public.** Implementation and offline tests are not proof of a client fix. See [CLEARCASTING_ALPHA13.md](CLEARCASTING_ALPHA13.md).

The user had confirmed **Arcane Soul and Overpowered Missiles in their alpha.12 scenario**. Those mappings were retained as scenario-specific evidence, without declaring other Procs/scenarios passed.

## Retest live Clearcasting first

Stop Test Mode, enable Blizzard Spell Alerts and use nonzero opacity.

1. Trigger Clearcasting. Left/right digits should sit at each actual graphic's visual midpoint plus saved offsets.
2. Gain and partly consume stacks through graphic transitions. Hiding the previous graphic must not erase all digits while the effect remains. Time comes from the actual Aura, never a new fixed duration.
3. Check duration refresh, final consumption and natural expiry, both in and out of combat.
4. Trigger Arcane Soul/Overpowered Missiles concurrently. Timers stay independent and continue after Options/Preview closes.
5. `/reload` with the buff present, then change specs and return. Resynchronize live state without changing coordinates/font/color. There is no universal native graphic-history replay API; verify this in-client.
6. If digits are missing, use **Mobility → Copy diagnostics** immediately after trigger and again after consumption. It records actual build, configured Aura/owners, the last 16 permitted graphic events and regional gating/layout/API reasons. It never reads restricted Auras or child frames; Native tracking does not mean Lua knows a buff exists.

## Retest regional color

In `/cui → Proc`, use the existing **Proc region** menu. The color target shows an ability and position, not an ambiguous left/right label.

1. Give Clearcasting left/right different RGB, then independently set Arcane Soul outer-left/right and Overpowered Missiles top. Defined entries remain editable without an active buff.
2. Click **Timer color**. Picker movement previews existing live/Preview digits; native **Okay** commits. Cancel, Esc, closing, changing region/spec or leaving the page discards unconfirmed edits.
3. **Use class color** removes only the selected region's RGB. Opening a default-color picker and accepting without changing it must not save a fixed class-color copy. There is no alpha control.
4. Appearance changes shared spec typography/size/outline/shadow/Scale for every region, preserving independent colors/positions. Mobility/Free move retain class color.
5. Edit Fire/Frost large/small, top and side regions, then return to Arcane. `/reload`, reopen and theme refresh must retain each color.
6. Change target/spec or close Options with the picker open. If another addon later owns the native picker, old CarGOUI callbacks must neither write a new target nor close that addon's picker.
7. Repeated color edits during live timing must not restart digits, change native gate alpha, erase other reminders or increase bindings. Diagnostics count public requests/allocations, never secret visibility.

The configurable menu contains **Arcane 5, Fire 7, Frost 3 regions**. Historical Fury of the Sun King has no verified current talent source and remains actual-native-event-only, not a selectable supported region. Future classes can reuse this color interface through stable region definitions.

## Regression and delivery

- Preserve confirmed Blink/Shimmer combat semantics: hide with a charge, show true next recovery when empty, hide on first recovery. Proc colors do not affect parallel Mobility or Free move.
- Keep two top-level addons. Shared Data TOC/static files and account SavedVariables may load together; unaccessed does not mean unloaded. Initialize only current business data and required color controls.
- No new OnUpdate, buff scan, background log polling, forced GC or large dependency. Public event history is bounded to 16; native picker hooks install once and do no idle business work.
- Build from committed source; verify bytes, TOCs, CRC and SHA256; run the complete suite on the **final extracted ZIP**. Report actual case count, three static suites, tree and packaging commit.
- At delivery there was no WoW client. New Clearcasting, RGB interactions and visual positions required user retesting. Offline simulations, source checks and feedback on two other Procs were not universal client acceptance.
