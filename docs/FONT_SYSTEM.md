# Reminder fonts and LibSharedMedia

## Issue #6: cause and scope

The old picker always offered four Roman Blizzard font paths. On `zhCN`,
`zhTW`, `ruRU`, and `koKR`, `ResolveReminderFont` deliberately redirected those
paths to `STANDARD_TEXT_FONT` for glyph coverage. Selecting different menu
items could therefore produce the same effective face. The picker did not
explain this substitution and could label a missing saved font as the client
default instead of identifying the saved choice.

The old settings-update path already dispatched style-only changes to existing
Proc, Mobility, Free move, and Preview objects. This change retains that path,
centralizes resource resolution, and adds event-driven recovery when a shared
font becomes available. It does not change Proc triggers, Aura state, reminder
timing, configuration ownership, or the Class Tools production boundary.

## Font sources and language policy

CarGOUI embeds **LibSharedMedia-3.0** after the existing LibStub and
CallbackHandler-1.0. A separate library addon, SharedMedia, or ElvUI installation
is not required. See [third-party provenance](../Libs/THIRD_PARTY_NOTICES.md) for
the exact upstream revision, preserved LGPL notice, and source hash.

CarGOUI ships **no user font files**. The picker uses Blizzard/client font
references plus the fonts registered in the shared LibSharedMedia registry.
SharedMedia, MyMedia, ElvUI, or any other provider can contribute through that
registry. CarGOUI does not enumerate operating-system fonts, scan directories,
or accept arbitrary file paths in settings or imports.

| Client locale | Font policy |
| --- | --- |
| enUS / enGB, deDE, frFR, esES / esMX, itIT, ptBR | Client default, distinct available legacy Blizzard faces, and fonts accepted by LSM's Western-language registration rules. |
| ruRU | Client default plus LSM's Cyrillic-compatible registered fonts. |
| zhCN / zhTW / koKR | Client default plus fonts accepted by LSM for the corresponding locale. Western-only registrations excluded by LSM are not offered. |

The actual client locale controls font eligibility, independently of the
interface dictionary. For example, a Korean or Portuguese client can use its
proper font resources while CarGOUI's unsupported interface language falls
back to English. Existing Roman-path preferences on a wide-character client
remain saved but render with the client default and a visible explanation.

LSM's accepted font registry is authoritative for shared-font language support.
CarGOUI does not bypass its locale masks. An owned scratch Font additionally
checks whether the registered file can load; a successful load does not prove
complete glyph coverage or correct third-party locale declarations. Those
properties still require client rendering checks.

## Stored preference and effective resource

Database schema **5** and transfer format **1** are unchanged. Existing 1.0.0
recognized Blizzard/client paths remain valid, with their existing
case-insensitive canonicalization and scope ownership. New shared selections
store `LSM:<media-name>`, for example `LSM:Expressway`, in `style.font.face`.
They never store the provider's resolved physical path.

The `LSM:` prefix is canonicalized. The media name remains case-sensitive, as
in the upstream registry. Names must be 1–128 bytes with no leading/trailing
whitespace, control characters, path separators, colon, or WoW markup pipe.
Ordinary Unicode names and internal spaces are allowed. Registration and local
availability are not prerequisites for a valid stored preference.

On another machine without Expressway, `LSM:Expressway` remains saved and
exportable while the renderer uses the safe client default. Import review and
the picker disclose this fallback. A later accepted font registration makes
the existing preference resolve again without changing SavedVariables.

The resolver reads `HashTable("font")[name]` for the exact identity. Upstream
`Fetch("font", name, true)` still applies a global LSM override, so it could
silently return a different named font. CarGOUI intentionally does not apply
that override to an explicit saved selection.

## Picker and import/export

The existing Appearance page remains in place. Font choices have
**Blizzard / Client** or **SharedMedia** labels; the client default is always
present. Duplicate effective file paths are combined. Shared names are sorted
and displayed through an eight-entry paged popup with reusable controls.
No raw path is presented as a font name.

The selected button and status identify the saved choice. The status separately
reports availability or a language fallback and the font actually used. A
missing selection is not relabeled as though the user chose the fallback.
Font-button tooltips show complete names and status when long text exceeds
the compact controls. If even the client default cannot load, the status
explicitly reports that neither resource is available.

The existing `friz`, `arial`, `morpheus`, `skurri`, and `client-default` transfer
tokens keep their meaning. `LSM:<name>` is an additional symbolic token with the
same identity on export and import. Export does not probe files or depend on
installed media. Import uses the shared resolver to disclose local fallback
before confirmation and preserves the logical identity. Older CarGOUI clients
that do not understand LSM tokens reject them rather than treating them as
paths. No destructive migration, database reset, or new SavedVariable is used.

## Refresh and safety

Style edits use `RefreshReminderStyle` for the affected class or specialization:

- Proc live and Free move update the addon's existing Font object used by the
  native Aura slot, without reading its restricted FontString.
- Mobility updates the existing owned output and its public layout.
- Preview updates its separate sample output and sample bounds.
- Hidden current-scope pool objects update too; acquisition restyles reused
  frames through the normal path.

Each styled object also retains a session-only snapshot of its requested font
identity, size, and outline. `LibSharedMedia_Registered` for a font invalidates
the availability cache and reapplies these requests to existing pooled objects,
including inactive-spec pools. This recovery does not read another spec's
database or overwrite its preferences. An already open picker refreshes; a
closed Options window is not opened or constructed. Other media registrations
do not trigger font refreshes.

The availability probe reads only its own public scratch Font after `SetFont`;
nil success returns are supported. Typography refresh does not query Auras,
read timer text, inspect restricted native children, rebuild Aura slots, restart
duration bindings, change alpha, or add polling/OnUpdate callbacks.

## Verification boundary

The actual Lua 5.1 suite exercises the unmodified embedded LSM implementation,
its locale registration filter, logical identity round trips, fallback and late
registration, live/Preview/pool refresh, and unchanged Class Tools isolation.
All six existing static groups and the offline publisher tests remain required.
Offline mocks do not certify native glyph coverage, layout, taint, or actual
client font-provider installations; record those checks separately on WoW.
