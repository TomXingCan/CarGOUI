# Class Tools Product Specification — paused research

## Status and scope

**Production development is paused and is outside CarGOUI 1.0.1.** Arcane Missiles Chain Check, Combustion Counter and Alter Time Recovery Feedback must not block the [1.0.1 roadmap](ROADMAP_1.0.1.md). The product semantics below are retained for future development, without a committed release target. Phase 1 / 1.1 implementation, findings and tests remain available; the production TOC and normal `/cui` commands no longer load or expose the research logger.

This document records the agreed product semantics for **Class Tools / 职业辅助**. It defines the intended product, not a claim that the product is implemented in Research Phase 1. Phase 1 only adds a temporary, opt-in raw capture logger and its research documentation. See [Class Tools Research Phase 1](CLASS_TOOLS_RESEARCH_PHASE1.md).

No production Class Tools evaluation algorithm is implemented in Phase 1.

## Navigation and visibility

Class Tools is a top-level feature named **Class Tools** in English and **职业辅助** in Chinese. It shows only the player's current class. It has two sections:

- **Common Tools:** tools shared by the current class across its specializations.
- **Spec Tools:** tools for the current specialization only.

Changing class or specialization changes which tools are displayed. Other classes and inactive specializations are not shown. An empty specialization does not require adding a tool to fill the section.

Class Tools output is normally hidden. A tool briefly displays feedback only after it has a meaningful result. Exact evaluation rules, wording, and display durations require later design and validation. Research capture, a spell cast, or an unverified event sequence does not establish such a result.

## Settings ownership and runtime gates

Each tool has its own independent `enabled` preference. Common Tool settings are shared within the same class. Spec Tool settings are saved per specialization, and only the current specialization's tools appear in the interface.

The agreed setting scopes are:

| Setting | Scope |
| --- | --- |
| Class Tools master switch | Global |
| Common Tools group switch | Class-scoped |
| Spec Tools group switch | Specialization-scoped |
| Individual Common tool settings | Class-scoped |
| Individual Spec tool settings | Specialization-scoped |

The Class Tools master switch, Common group switch, and Spec group switch are runtime gates. They control whether eligible tools may run; they do not change the tool's own preference. The effective runtime eligibility is:

```text
Common tool: Class Tools master AND current-class Common group AND tool.enabled
Spec tool:   Class Tools master AND current-spec Spec group AND tool.enabled
```

Turning any master or group gate OFF must never overwrite, clear, reset, or normalize a child tool's `enabled` state. Turning that gate back ON restores eligibility according to each child's existing preference. A disabled child remains disabled. A specialization change must preserve the inactive specialization's preferences.

These are product semantics only. This document does not prescribe a database layout, add a formal Class Tools schema, or authorize a schema migration. The temporary capture logger has no relationship to these future saved preferences.

## Retained Mage product direction (no release target)

| Section | Tool | Product intent |
| --- | --- | --- |
| Common | Alter Time Recovery Feedback | Brief feedback associated with a meaningful Alter Time recovery result, subject to later API and data validation. |
| Arcane | Arcane Missiles Chain Check | Brief feedback about an Arcane Missiles chain, with evaluation semantics deferred until captured timelines are understood. |
| Fire | Combustion Pyroblast / Flamestrike Counter | A later tool concerned with Pyroblast and Flamestrike casts associated with Combustion; window and counting rules are not defined by Phase 1. |
| Frost | No tool added in this phase | Do not invent a Frost feature solely to populate the section. |

The tool names establish product direction. They do not establish spell identifiers, event ordering, success criteria, window boundaries, tick counts, health recovery rules, or spell-counting algorithms.

## Product exclusions

Class Tools is not intended to provide:

- A rotation assistant or next-spell recommendation.
- A WeakAuras-style editor.
- A DPS meter.
- A general cooldown HUD.

Existing Proc and Mobility features retain their independent behavior and settings. Phase 1 research must not change their event subscriptions or production output.

## Research Phase 1 boundary

Phase 1 may record public raw events and safe session context for the three research modes `arcane`, `combustion`, and `altertime`. It must not implement any of the following:

- Arcane success/failure evaluation or a seventh-tick protection interval.
- Wave grouping or AoE clustering.
- A Combustion window detector or Combustion Counter.
- An Alter Time recovery amount calculation.
- A production Class Tools Options page.
- A formal Class Tools database schema or schema migration.
- A production Class Tools registry or style inheritance.
- A 1.0.1 release or tag.

Candidate spell IDs and public API/source evidence remain research inputs until verified in WoW 12.1 on the target client. Restricted data must not be inspected or reconstructed to obtain a result.
