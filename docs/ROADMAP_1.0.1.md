# CarGOUI 1.0.1 roadmap

## Release scope

The 1.0.1 development baseline starts from `main` at
`3dd753427414321714b7502d77575236cd61f817`. This baseline separates research from
production and records the licensing cutover. It does not implement either
feature below.

| In scope | Planned work |
| --- | --- |
| [#6: Font selector and LibSharedMedia](https://github.com/TomXingCan/CarGOUI/issues/6) | Fix the ineffective font selector behavior and support fonts registered through LibSharedMedia while preserving existing saved preferences and safe client fallback. |
| [#7: Proc Appearance v2](https://github.com/TomXingCan/CarGOUI/issues/7) | A Blizzard FileDataID asset catalog, cross-class Blizzard Proc artwork, independent per-region visual customization, and animation presets. |

Proc Appearance v2 changes presentation only. Existing verified native Proc
trigger semantics remain authoritative. The catalog will ship metadata referring
to artwork in the WoW client, not copies of Blizzard texture files. Existing
1.0.0 visuals and settings must remain the default after upgrade.

## Paused and excluded

Production Class Tools development is paused and must not block 1.0.1. The
following are outside this release:

- Production Class Tools infrastructure and interface.
- Arcane Missiles Chain Check.
- Combustion Counter (Pyroblast / Flamestrike).
- Alter Time Recovery Feedback.

The [product specification](CLASS_TOOLS_PRODUCT_SPEC.md), [Phase 1 / 1.1
findings](CLASS_TOOLS_RESEARCH_PHASE1.md),
`Research/ClassToolsRawCapture.lua`, and research tests remain in the repository
for later development. Their continued presence does not commit them to 1.0.1.
The production TOC does not load the logger, and normal `/cui` routing/help does
not expose `ctlog`. Research tests explicitly load the module into their own
fixtures; no research SavedVariables are introduced.

## Baseline and release hardening

Both production TOCs retain `## Version: 1.0.0` during this baseline PR. The
formal 1.0.1 version bump belongs to later release hardening. This baseline does
not create a tag, GitHub Release, or CurseForge/Wago/WowUpHub publication.

Validation includes the complete actual Lua 5.1 smoke suite, all six static-check
groups, and the publisher unit tests. Production separation tests cover normal
login, command rejection, help, SavedVariables, existing 1.0.0 settings, and
continued Proc/Mobility/Free move behavior. Offline tests do not establish live
WoW client acceptance.
