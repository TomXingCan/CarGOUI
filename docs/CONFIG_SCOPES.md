# Schema 5 — class Mobility / class-specialization Proc

This replaces alpha.7's per-spell/per-region appearance scope. Stage A only.

```lua
CarGOUIDB = {
  schemaVersion = 5,
  options = { position = { x = 0, y = 0 }, animatedTitle = true },
  classes = {
    MAGE = {
      mobility = { enabled = true, style = { font = {}, shadow = {}, scale = 1 },
        position = { anchor = "CENTER", x = 0, y = 0 }, preferences = {} },
      proc = { [62] = { style = {}, regions = {
        mage_arcane_clearcasting_left = { position = {} },
        mage_arcane_clearcasting_right = { position = {} },
      } } },
    },
  },
  migrations = { scope5 = { source = {}, mobility = {}, proc = {} } },
}
```

The example illustrates shape; it is not an eagerly constructed default tree.
Current class Mobility initializes on login; current Proc config initializes only
when requested. No other class default records or inactive Proc spec records are
constructed. Existing serialized class records still load with core SavedVariables
(see LOAD_BOUNDARIES.md). Mutable defaults/styles/coordinates are separate tables.

## Once-only migration rules

1. Capture legacy enabled/mobility/global style/global position/styles/reminders
   under `migrations.scope5.source`. Preserve unknown or conflicting old values
   there. Do not spread them to new classes. A non-Mage login leaves migration
   pending until Mage is used.
2. Existing valid schema-5 scoped values win. Missing/invalid fields are completed
   from a resolved legacy value only during that scope's migration; later changes
   are not overwritten at login.
3. For Mage appearance choose the currently confirmed learned Blink or Shimmer
   replacement. If learning metadata is unavailable/ambiguous, choose saved Blink,
   then saved Shimmer, then the legacy/factory fallback. The recorded rule and
   chosen key are in `.mobility`; no cooldown or secret value is used to choose.
   Schema 4 already retired global style inheritance, so missing schema-4 style
   fields use factory defaults. Earlier global font/shadow/scale values remain the
   migration source for pre-schema-4 records.
4. Mage position: choose the current specialization's legacy position, then first
   saved Arcane/Fire/Frost/unspecialized region if absent. Combine legacy global XY
   and that region's XY once, without multiplying either by Scale. Proc regions
   similarly retain each effective XY plus their unchanged visual anchor. Legacy
   combinations up to +/-20000 are preserved; normal new input limits stay +/-10000.
5. Only known Mage Proc regions are mapped. Each visited spec chooses the first
   saved defined region's style (left before right), with provenance in `.proc[id]`.
   Other conflicting styles and unrecognized sources remain backed up. Coordinates
   remain per-region. Pre-schema-4 global styles belong to this known Mage history,
   not every class. Old global disabled state does not disable Proc samples.
6. Migration writes completion markers. Factory defaults initialize new classes
   and new data; editing one scope cannot become another scope's default. Reset
   current style does not erase coordinates. Reset class + Options preserves other
   class records and historical backups.

Same class/spec style objects are intentionally shared by reminder consumers;
different class/module/spec styles must not share mutable child tables. Live and
Preview both read the same owning style. Old Mobility region IDs remain accepted
in the current catalog but now route to the one class position, preserving usable
coordinates rather than creating three future Mobility configurations.

## Client acceptance (not executed in the development environment)

Back up the previous SavedVariables file, keep it in place for upgrade, then:

1. Log in Mage in the spec/skill whose current appearance should be preserved.
   Verify enabled, font/size/outline/shadow/scale, reminder XY, Options position and
   animated title match the old effective result. Check migration provenance.
2. Change Mage Mobility style and XY. Switch Arcane/Fire/Frost; Blink/Shimmer
   selection may change, but every Mobility setting stays the same. `/reload` and
   revisit the initial spec. Unsubmitted input must not carry to a new context.
3. Change Arcane Proc style: left/right change together, their independent XY do
   not merge. Fire and Frost Proc styles stay independent; Mobility is unaffected.
   Modify region XY through the existing Test Mode menu, then reset only the style.
4. Relog Warrior. Mage user values must not become Warrior defaults. Edit Warrior
   Mobility settings (no live adapter this phase), then return Mage and verify its
   saved values. Never select a class/profile manually.
5. Verify Alliance Arcane blue-to-purple and Horde Arcane red-to-purple. Switch
   spec/faction and check only Options theme changes. Unknown identity uses fallback.
   No manual theme/class/spec/profile controls or new buttons should appear.
6. With Options closed and Preview stopped, regress Blink/Shimmer in and out of
   combat: 2->1 hidden, 1->0 visible, 0->1 hidden. Wait between uses and confirm the
   existing recharge remainder continues. Check GCD-only, resets, combat transitions.
   Style edits during native tracking must not restart/rebind time or change alpha.
7. Repeat spec changes and open/preview/stop/close cycles. Record the four-layer
   diagnostics and actual client CPU/memory using LOAD_BOUNDARIES.md; distinguish
   cached frame counts from active bindings and loaded files from active adapters.

Offline tests exercise these contracts with separate combat/secret-data fixtures.
They cannot validate actual taint, native rendering or real CPU/memory. The final
delivery report contains extracted-package test output, not client sign-off.


## alpha.13: optional Proc region RGB

Font, font size, outline, shadow and scale remain in `classes[classToken].proc[specID].style`. Only RGB is added to `regions[stableRegionID].color = {r=...,g=...,b=...}`. Existing `.position` is unchanged. Omitted color resolves dynamically to the current class color; the default is not persisted. Resetting region color removes the optional key. Valid custom RGB values are finite in [0,1], without alpha. Invalid optional color data falls back safely; valid colors are copied independently even when old tables were aliased. Only the current requested specialization is normalized.

Changing a timer Aura/graphic owner does not rename region IDs. Existing Clearcasting left/right coordinates, shared fonts, options and all other classes survive. Temporary picker drafts live outside SavedVariables; only a confirmed still-current class/spec/region writes through the shared configuration validator. Future classes reuse the same definition-driven interface. Mobility and Time Spiral Free move retain fixed class color.
