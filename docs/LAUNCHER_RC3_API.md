# RC3 launcher API / compatibility audit

Audit date: 2026-09-27. Target: Retail 12.1 / Interface 120100. The work environment has no running WoW client. This document records inspected primary-source interfaces, integration decisions and remaining client acceptance; it does not certify external manager compatibility.

## Source pins and libraries

The four embedded libraries are unmodified copies from the official LibDBIcon v12.0.3 SVN package, fixed at revision 162. Versions, immutable download paths, SHA256 values and rights notes are in [Libs/THIRD_PARTY_NOTICES.md](../Libs/THIRD_PARTY_NOTICES.md). The dependency footprint is LibStub minor 2 → CallbackHandler minor 8 → LibDataBroker minor 4 → LibDBIcon minor 56. There is no embedded Ace3/AceGUI or addon manager, and no separate installation requirement.

LibStub may select a newer shared copy already supplied by another addon. The pinned-copy tests cannot prove all future library versions.

| Subject | Audited source |
| --- | --- |
| Native TOC compartment registration | [Blizzard AddonCompartment.lua, retail source mirror 09b9db7948abc9b9648dedaab51eb0cf3ee67b31](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_Minimap/Mainline/AddonCompartment.lua) |
| LibDBIcon registration, placement and settings | [Official v12.0.3 Lua, SVN r162](https://repos.curseforge.com/wow/libdbicon-1-0/!svn/bc/162/tags/v12.0.3/LibDBIcon-1.0/LibDBIcon-1.0.lua) |
| LDB registry | [Tekkub 1a63ede0248c11aa1ee415187c1f9c9489ce3e02](https://github.com/tekkub/libdatabroker-1-1/blob/1a63ede0248c11aa1ee415187c1f9c9489ce3e02/LibDataBroker-1.1.lua) |
| HidingBar retail | [08897f63f1a3cb53d3a10f68e9307580b40152df](https://github.com/sfmict/HidingBar/blob/08897f63f1a3cb53d3a10f68e9307580b40152df/HidingBar/HidingBar.lua) |
| WindTools 4.21, Interface 120100 | [0342e0c3c68920db5ef3f9bb1053105082bddb46](https://github.com/wind-addons/ElvUI_WindTools/blob/0342e0c3c68920db5ef3f9bb1053105082bddb46/Modules/Maps/MinimapButtons.lua) |
| MBB Reborn 4.0.29, Interface 120005 | [3f865b47e9ac3ae47644a843f450bcb1eb395525](https://github.com/pereira-a/MBB/blob/3f865b47e9ac3ae47644a843f450bcb1eb395525/MBB.lua) |

HidingBar's source TOC uses a packaging placeholder for Version, so the commit is the exact audited identifier rather than an invented release version. The original [vallantv/MBB repository](https://github.com/vallantv/MBB) is archived; the audited Reborn fork is distinct. Reborn's source TOC does not declare 120100, so actual 12.1 usability is not established here.

## Native entry and click boundary

Blizzard's `RegisterAddons` reads the main TOC `AddonCompartmentFunc` and `IconTexture` metadata once on PLAYER_ENTERING_WORLD. It calls the named global as:

```lua
_G[addonCompartmentFunc](addonName, menuInputData.buttonName)
```

The callback must not treat the first argument as an Options frame. LDB/LibDBIcon use `OnClick(displayFrame, buttonName)`; broker hosts may also supply a menu input table. CarGOUI adapts the click argument only, then calls the existing `ToggleOptions`. Only unmodified left clicks open settings; Ctrl+right-click and other manager gestures are left to the manager. Missing or unsupported click arguments do not open settings accidentally.

Only the main TOC declares a compartment callback. Data has no launcher. LibDBIcon registers a compartment item only when its settings contain `showInCompartment` or its compartment API is explicitly called. Neither path is enabled by CarGOUI. Hiding the minimap icon does not remove the TOC entry. The addon never assumes AddonCompartmentFrame is present or visible.

The shared Options gate continues to own combat detection, the single queued request and deferred opening. Launcher callbacks do not show/create the Options frame themselves, start Preview, open the color picker, or allocate another combat queue.

## LibDBIcon state and manager ownership

The broker is uniquely named `CarGOUI`, type `launcher`. LibDBIcon names its button `LibDBIcon10_CarGOUI` and exposes it through `GetMinimapButton`. The LDB object and LibDBIcon registration are reused.

The important API distinction is visible in upstream `Refresh(name, db)`: it assigns `button.db`, but also repositions to Minimap, shows/hides the button and reinstalls drag handlers. `Show(name)` also repositions. Unconditional Refresh on every import, specialization or Options opening would interfere with managers.

CarGOUI therefore keeps its originally registered minimap table identity across atomic import/reset/restore, copying only validated `hide` and `minimapPos` fields back into that table. It does not serialize library objects or manager state. Placement updates require both a Minimap parent and a Minimap anchor target (or a newly unplaced button); parent identity alone is insufficient for MBB. Captured buttons retain the collector's layout and drag handlers. Show/Hide is requested only for a changed user visibility preference, not repeatedly because a collector hid it. Initial registration never forces Show after a collector's IconCreated callback; late-loaded, unplaced buttons get their saved angle and a saved hidden preference is honored without waiting for a second PLAYER_LOGIN.

LibDBIcon uses an OnUpdate only between drag start and drag stop. Its fade animation is event-driven and opt-in; CarGOUI does not enable mouseover fading. The library has one startup PLAYER_LOGIN handler and two Minimap hover hooks, not a permanent polling scan. CarGOUI's OnHide guard delegates the original library stop handler only for a still-owned standard drag. No gameplay query is added to the launcher or Tooltip.

LibDBIcon supports ROUND, SQUARE, four CORNER shapes, four SIDE shapes and four TRICORNER shapes. These are library placement semantics; actual custom-map geometry and UI scale require client testing.

## Collection tools: evidence and limits

### HidingBar

The inspected source keeps `createdButtonsByName` for LDB displays and separate `minimapButtons` for captured frames. `ldb_add` accepts launcher objects; `ldbi_add` accepts the LibDBIcon callback and standard button. There is no universal cross-source name deduplication between these two collections.

In `checkProfile`, the old default enabling `addFromDataBroker` is commented out, while `grabMinimap` defaults true. A fresh default profile therefore collects the one standard LibDBIcon button, without also creating an LDB display. This is the source basis for the default single-entry expectation.

An existing profile that explicitly enables both sources can show both representations. CarGOUI does not silently edit that profile, add private markers, or hide its own button on HidingBar detection. If both sources are enabled, use HidingBar's own exclusion/visibility controls to choose one representation. The manager also controls whether addon-requested visibility is followed through its per-button auto show/hide setting; its user exclusions remain authoritative.

This is intentionally not described as automatic dedup under every HidingBar profile. HidingBar can render the LDB launcher even if the standalone minimap icon is hidden, when its DataBroker source is enabled.

### WindTools Minimap Buttons Bar

`HandleLibDBIconButton` recognizes the standard button surface and hooks Show/Hide/SetShown for layout updates. The module examines Minimap children and respects its ignore/hidden lists. On capture it reparents the existing button and removes its drag scripts; on detach it can restore the original geometry and scripts. CarGOUI neither overrides those methods nor reinstalls drag scripts while captured.

WindTools has its own skinning/timing behavior. No WindTools code or dependency is embedded, and CarGOUI does not add another scan to track it. Verify with ElvUI plus the specific installed WindTools version, not multiple managers competing for the same frame.

### MBB / MBB Reborn

The Reborn source scans named Minimap children with click scripts, records/restores those scripts and honors `MBB_Exclude`. The standard LibDBIcon button meets that public shape without a private compatibility marker. Its collection preserves the Minimap parent, replaces SetPoint/ClearAllPoints and anchors through saved methods to the MBB root or previous button. It leaves the library drag scripts present. CarGOUI therefore checks the current public launcher anchor target as well as the parent, and never replaces those manager methods.

MBB's OnClick wrapper reserves Ctrl+right-click for detach/reattach, and otherwise calls the original handler with `select(1, ...)`, which forwards all arguments. CarGOUI leaves those gestures untouched. MBB Reborn itself has legacy polling and APIs; those belong to the external manager and are not added to CarGOUI. Source shape compatibility is not proof that the whole external addon runs on Retail 12.1.

## Branding

All four entry surfaces refer to the existing transparent 128×128 `Media/Branding/emblem.tga`. TOC icons do not depend on Options or the Data package executing. No branding animation, replacement logo or AddOnList hook is introduced.

LibDBIcon's default icon coordinates are cropped by 5% at rest and use the supplied range while pressed. CarGOUI compensates this through the supported broker `iconCoords` field so the four emblem tips are not clipped. Broker displays and managers may apply their own skins/crops. Static 16/20/32-pixel inspection checks the shipped source; in-game filtering, manager skins and actual device/UI scale remain client acceptance items.

## Acceptance classification

| Environment | Source interface review | Offline status | Actual client status |
| --- | --- | --- | --- |
| No manager / pinned libraries | Audited | Actual vendored libraries exercised by release smoke harness; final counts in package test log | Pending |
| Native compartment | Exact TOC callback inspected | TOC uniqueness, click adaptation and common combat queue simulated | Pending |
| HidingBar pinned retail commit | Default source selection and separate collections inspected | Generic capture ownership modeled; default-source choice checked in source only, not an executed HidingBar UI | Pending |
| WindTools 4.21 source pin | Standard capture and visibility hooks inspected | Ownership/callback model exercised; no full ElvUI/WindTools runtime | Pending |
| MBB Reborn 4.0.29 source pin | Standard named-button/click scan inspected | Click boundary and ownership model exercised; no full MBB runtime | Pending; 120100 not declared by audited TOC |
| Original archived MBB | Archive status identified | No whole-addon compatibility claim | Not certified |

Use the final extracted-package test log for exact results; source inspection is not a replacement for tests. Offline geometry cannot certify native drag dispatch, rendered clarity, third-party skinning or client CPU/memory.

For each manager **separately**: record its exact version and client build; start with its default profile, confirm one CarGOUI entry, left-click and Tooltip; test explicit hide/restore, manager exclusion, /reload, round/square map and UI scale; drag the standalone minimap icon and confirm Options/reminder coordinates do not change; test all three click surfaces in combat, repeated requests and a single post-combat opening; import old/new settings, reset and restore a backup, then drag and /reload to confirm new minimap position persists. Recheck Proc/Mobility/Free move and the RC2 Options drag acceptance steps. Do not run two collectors against the same button and infer single-manager compatibility from that conflict.
