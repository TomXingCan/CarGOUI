# Settings transfer format 1

`CARGOUICFG:1:<standard Base64 of JSON>` transfers public user settings. It is not Lua, executable code, encryption or authentication. Only click Confirm after reviewing the scope of a string you intend to use. No compression or third-party serialization framework is installed.

The envelope separately records `formatVersion`, `schemaVersion`, `addonVersion`, `project`, `scope` and `classes`; `options` is permitted only for the all-saved scope. Format 1 currently accepts settings schema 5 and project `Retail`. The source addon version is descriptive metadata, not the format version. Unknown/future format or schema versions are rejected; there is no older supported public export format to guess or migrate.

## Ownership and fields

- `scope`: `class` (the default current-class export) or `all` (all saved classes plus saved Options shell). If no current-class settings have been saved, export reports that explicitly; it does not initialize a class/spec merely to produce data.
- `classes`: object keyed by a recognized class token. Each saved class may include `mobility` and `proc`.
- `mobility`: complete snapshot of `enabled`, `style`, `position`, `freeMovePosition` and `preferences`. Free move and ordinary Mobility always have separate position tables.
- `proc`: object keyed by decimal spec ID strings on the wire, restored as numeric keys in SavedVariables. The ID must belong to its stated class. A spec snapshot includes `enabled`, `style` and `regions`.
- `regions`: stable region IDs, validated against the small configuration metadata catalog. A region contains `position` and optionally `color = {r,g,b}`. This catalog includes retained historical Mage IDs and no spell database or adapters. Validation does not load another class's gameplay module.
- `style`: `font = {face,size,outline}`, `scale`, `shadow = {enabled}`. On the wire `face` is a semantic token (`friz`, `arial`, `morpheus`, `skurri`, `client-default`), never an arbitrary file path. Font size is 8–72, scale 0.5–3, outline is the existing empty/OUTLINE/THICKOUTLINE enum.
- Reminder `position`: `anchor = "CENTER"`, finite `x` and `y`. Transfer preserves valid historical migrated values from -20000 to 20000 without multiplying by scale. New manual UI edits retain their existing -10000 to 10000 limits.
- RGB components must be finite numbers from 0 to 1. No alpha is transferred. Missing `color` in an included region means remove an old custom RGB and use dynamic class color.
- Preferences currently admit the existing empty object or `skillDisplay = {label = boolean}` shape. Unknown preferences are explicitly rejected rather than silently exported as arbitrary private data. Future preferences require a deliberate whitelist update.
- `options`: the allowed shell snapshot (window `position`, XY -10000 to 10000, and `animatedTitle`). It never includes a selected class/spec, derived theme, focused input, test mode or pending combat request.

All imported mutable tables are reconstructed independently. Unlisted classes, Proc specs and region records remain unchanged. Included Mobility is replaced completely; included Proc specs replace shared style/enabled while merging only the included region records, each as a complete record. Imports keep their source class/spec; importing Mage on Warrior does not convert settings or activate Mage monitoring. Current-class strings cannot overwrite the shell.

## Bounded validation

The input limit is 196608 bytes, decoded JSON limit 131072 bytes, nesting depth 12, lexical token budget 20000 and aggregate object-member budget 2048. Strings and numeric literals also have small protocol limits. Supported settings fit comfortably within these bounds. Oversized input is rejected explicitly; the editors do not silently truncate it.

Before native JSON decoding a bounded grammar scan validates nesting, strings/escapes, duplicate keys (including escaped duplicates), numeric syntax and finite values. JSON null, nonempty arrays and non-ASCII protocol tokens are rejected. An empty `[]` is accepted only in fields that allow an empty map, because the native declaration does not promise whether an empty Lua table serializes as `{}` or `[]`. Required record objects cannot be replaced with arrays. After decoding, strict allowed-field/type/range/class/spec/region checks reconstruct user data; unknown fields are not copied to the database.

Recognized font tokens are resolved to local supported resources. Before review, a bounded reusable addon-owned font probe checks local availability without touching a reminder. A missing font is disclosed with its fallback before confirmation; an arbitrary path is rejected. Localized client defaults are semantic, so a source client's default font can become the target client's local default. Export itself performs no resource probes or writes.

## Transaction and backup

Prepare parses, validates and builds a candidate with independent imported scopes, then returns an impact summary. Untouched scopes retain their existing references; confirmation's snapshot check rejects intervening configuration changes. Preparation changes no saved configuration or live reminder. Confirmation also rechecks the current review, Options lifecycle, class/spec identity and combat lock. Expired, canceled or altered reviews are rejected. A successful commit preserves the root database reference and synchronizes configuration caches; it saves one bounded pre-import user snapshot and applies only the necessary display/module updates.

Restore uses the same review/confirmation rules. It restores the snapshot, including absence of scopes that were created by the intervening import. Repeating Restore restores that same pre-import snapshot; it does not toggle back to the imported values. Only a new ordinary import replaces the backup. Backups, old migrations, runtime objects, identity, themes, logs and other non-user fields never enter an export or recursively enter another backup. Closing the page/window, replacing pending text, changing identity or entering combat clears the in-memory transaction. Reopening cannot confirm an old import.

## Native API evidence and verification boundary

The pinned [EncodingUtil API declaration](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/EncodingUtilDocumentation.lua) declares `C_EncodingUtil.SerializeJSON`, `DeserializeJSON`, `EncodeBase64` and `DecodeBase64`. These public-setting inputs use the normal untainted argument path. Base64 uses the Standard variant; no unsupported JSON object/sorting option is invented. The declaration permits absent results, so API errors and missing/wrong return values must fail safely.

The same pin's [SimpleFont declaration](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontAPIDocumentation.lua) does not declare a success return from `SetFont`. Availability checks therefore inspect only the addon's reusable public scratch Font after a protected attempt to set a whitelisted path. They never read live Proc text, secret time or native reminder visibility.

The offline suite runs actual Lua 5.1 with Python JSON/Base64 behind the mocked API boundary. It tests hostile input, empty-map variations, string spec keys, scope merging, restore, failure atomicity and UI lifecycle. It does **not** establish actual WoW codec output or security/visual behavior. Follow [RC_ACCEPTANCE.md](RC_ACCEPTANCE.md) for native current-class/all-saved round trips, localized fonts, copy/paste, `/reload`, combat cancellation and live reminder checks. Record exact client build for that evidence.
