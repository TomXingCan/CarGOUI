# Automatic Body theme coverage

This table records the alpha.10 **Options appearance** increment: 13 class bases, 40 class/spec themes and neutral fallback. Class/spec determines Body only; Header remains Alliance blue, Horde red or neutral.

**Theme coverage is not Mobility or Proc coverage.** At alpha.10 only Mage Blink/Shimmer had real monitoring and Proc was Preview-only. Later implementations are recorded separately in [Mobility coverage](MOBILITY_COVERAGE.md) and [Proc coverage](PROC_COVERAGE.md); those later changes do not turn a theme table into gameplay evidence. Reminder colors, configuration scopes, coordinates and timing are not theme data.

New non-Mage palettes/geometries were original design proposals, not individually user-specified art. Mage Arcane/Fire/Frost palettes and watermark endpoints remain exactly the alpha.9 design the user had approved. That prior feedback is not per-theme visual acceptance of a newer package.

## Class bases: no selected or covered specialization

Each known class has a visible base instead of another class's or a guessed spec's theme. Pending means client visual/interaction acceptance; implementation/offline results are separate.

| Class | Body key | Dark gradient / accent | Base watermark | Implementation | Client acceptance |
| --- | --- | --- | --- | --- | --- |
| Death Knight | `deathknight` | Dark red iron → runic magenta | Rune sword, side diamond seals | Implemented | Pending |
| Demon Hunter | `demonhunter` | Dark ink green → fel emerald | Paired glaives, blindfold bar, central seal | Implemented | Pending |
| Druid | `druid` | Deep forest green → botanical amber | Antlers, leaves, tree veins | Implemented | Pending |
| Evoker | `evoker` | Dark teal → draconic emerald | Wings, dragon head, curved tail | Implemented | Pending |
| Hunter | `hunter` | Deep forest → olive | Bow, arrow, diamond hunting seal | Implemented | Pending |
| Mage | `mage` | Retained dark blue-gray | Generic orb, rays and staff; no assumed spec | Implemented | Pending |
| Monk | `monk` | Deep teal → jade | Intersecting rings, central chi diamond | Implemented | Pending |
| Paladin | `paladin` | Deep warm brown → restrained gold | Shield, hammer, central seal | Implemented | Pending |
| Priest | `priest` | Deep warm gray → ivory dark gold | Halo, staff, side robe folds | Implemented | Pending |
| Rogue | `rogue` | Charcoal → brass | Crossed daggers, central seal | Implemented | Pending |
| Shaman | `shaman` | Deep storm blue → cobalt | Ring, lightning, outer diamond totems | Implemented | Pending |
| Warlock | `warlock` | Deep purple-black → fel amethyst | Portal ring, curved horns, central sigil | Implemented | Pending |
| Warrior | `warrior` | Deep iron gray → rusty copper | Crossed swords, central military emblem | Implemented | Pending |

## Specialization coverage

Each spec has a distinct palette and line composition, retaining its class silhouette while adding spec detail. These abstract symbols never represent active spells, buffs, cooldowns or availability.

| Class | specID / specialization | Body key | Dark gradient / accent | Watermark variation | Implementation | Client acceptance |
| --- | --- | --- | --- | --- | --- | --- |
| Death Knight | 250 Blood | `deathknight_blood` | Dark blood red → crimson | Blood-drop sword sigil | Implemented | Pending |
| Death Knight | 251 Frost | `deathknight_frost` | Deep ice steel → frost blue | Six-point ice rays at each side | Implemented | Pending |
| Death Knight | 252 Unholy | `deathknight_unholy` | Dark moss → plague green | Angular bone-like side seals | Implemented | Pending |
| Demon Hunter | 577 Havoc | `demonhunter_havoc` | Dark green → acidic fel green | Split flame over glaives, four-point lower rays | Implemented | Pending |
| Demon Hunter | 581 Vengeance | `demonhunter_vengeance` | Charred brown → hot copper-gold | Central glaive shield | Implemented | Pending |
| Demon Hunter | 1480 Devourer | `demonhunter_devourer` | Deep void blue-purple → violet | Void ring and diamond core between glaives | Implemented | Pending |
| Druid | 102 Balance | `druid_balance` | Moonlit indigo → star violet | Crescent between antlers | Implemented | Pending |
| Druid | 103 Feral | `druid_feral` | Dark bark → rusty wild orange | Triple claw marks on both sides | Implemented | Pending |
| Druid | 104 Guardian | `druid_guardian` | Deep earth brown → bronze gold | Central paw print | Implemented | Pending |
| Druid | 105 Restoration | `druid_restoration` | Deep leaf green → new-growth emerald | Fresh side leaves | Implemented | Pending |
| Evoker | 1467 Devastation | `evoker_devastation` | Dark ruby → deep wing blue | Double split flames beneath wings | Implemented | Pending |
| Evoker | 1468 Preservation | `evoker_preservation` | Deep emerald → bronze-green | Side life leaves | Implemented | Pending |
| Evoker | 1473 Augmentation | `evoker_augmentation` | Obsidian brown → bronze gold | Faceted side diamond crystals | Implemented | Pending |
| Hunter | 253 Beast Mastery | `hunter_beastmastery` | Deep fern → botanical amber | Paw print beneath bow/arrow | Implemented | Pending |
| Hunter | 254 Marksmanship | `hunter_marksmanship` | Forest steel blue → cyan-blue | Sight ring and ticks ahead of arrow | Implemented | Pending |
| Hunter | 255 Survival | `hunter_survival` | Dark moss → rusty copper | Diagonal spear and trap diamond | Implemented | Pending |
| Mage | 62 Arcane | `arcane` | Deep purple → arcane purple | Original double rings, central seal, four-way runes; 60 lines | Implemented; alpha.9 retained | User approved alpha.9; newer package regression pending |
| Mage | 63 Fire | `fire` | Deep red-brown → dark amber | Original outer/inner flames; 27 lines | Implemented; alpha.9 retained | User approved alpha.9; newer package regression pending |
| Mage | 64 Frost | `frost` | Deep blue → ice cyan | Original central crystal and six ice branches; 36 lines | Implemented; alpha.9 retained | User approved alpha.9; newer package regression pending |
| Monk | 268 Brewmaster | `monk_brewmaster` | Dark amber → gold-jade | Barrel within intersecting chi rings | Implemented | Pending |
| Monk | 269 Windwalker | `monk_windwalker` | Deep azure → cyan-blue | Outer flowing chi arcs and arrow tails | Implemented | Pending |
| Monk | 270 Mistweaver | `monk_mistweaver` | Deep sea green → jade | Mist waves above/below rings | Implemented | Pending |
| Paladin | 65 Holy | `paladin_holy` | Warm dark gold → radiant amber | Sun disk and rays above shield | Implemented | Pending |
| Paladin | 66 Protection | `paladin_protection` | Deep blue steel → pale gold-gray-blue | Double shield | Implemented | Pending |
| Paladin | 70 Retribution | `paladin_retribution` | Dark crimson → copper-gold | Crossed judgment swords at shield sides | Implemented | Pending |
| Priest | 256 Discipline | `priest_discipline` | Dark blue → gold-purple-gray | Paired staff diamonds and order bars | Implemented | Pending |
| Priest | 257 Holy | `priest_holy` | Deep ivory-brown → warm dark gold | Rays outside halo | Implemented | Pending |
| Priest | 258 Shadow | `priest_shadow` | Deep purple-black → shadow violet | Void arcs at staff sides | Implemented | Pending |
| Rogue | 259 Assassination | `rogue_assassination` | Deep poison green → acidic olive | Three poison-drop seals | Implemented | Pending |
| Rogue | 260 Outlaw | `rogue_outlaw` | Dark brass → deep sea teal | Compass between daggers | Implemented | Pending |
| Rogue | 261 Subtlety | `rogue_subtlety` | Midnight blue → covert purple | Central dark eye | Implemented | Pending |
| Shaman | 262 Elemental | `shaman_elemental` | Dark lava red → storm indigo | Flame and stone marks beside lightning | Implemented | Pending |
| Shaman | 263 Enhancement | `shaman_enhancement` | Deep steel blue → lightning cyan | Extra side lightning | Implemented | Pending |
| Shaman | 264 Restoration | `shaman_restoration` | Deep tide blue → seawater cyan | Three tidal waves | Implemented | Pending |
| Warlock | 265 Affliction | `warlock_affliction` | Sickly dark green-gray → curse purple | Linked chain seals in portal ring | Implemented | Pending |
| Warlock | 266 Demonology | `warlock_demonology` | Deep amethyst → fel magenta | Horned inner seal and upper core | Implemented | Pending |
| Warlock | 267 Destruction | `warlock_destruction` | Dark ember red → scorched copper-gold | Central portal flame | Implemented | Pending |
| Warrior | 71 Arms | `warrior_arms` | Dark crimson → weapon bronze | Upright sword between crossed swords | Implemented | Pending |
| Warrior | 72 Fury | `warrior_fury` | Deep scarlet → raging ember | Split flame between swords | Implemented | Pending |
| Warrior | 73 Protection | `warrior_protection` | Deep iron blue → tempered steel blue | Shield between swords | Implemented | Pending |

## Acceptance and boundaries

At the alpha.10 theme increment, Mage had implemented Blink/Shimmer requiring package regression and Preview-only Proc; other classes had no real Mobility/Proc yet. That historical gap is now tracked by the separate live-coverage documents linked above, never inferred from theme completion.

1. Keep WTF/SavedVariables and replace both program directories. Open `/cui` and inspect faction Header and class/spec Body. Alpha.10 had a read-only Theme page; it was removed in RC1 without removing automatic themes.
2. Inspect every palette: broad gradient, sidebar/footer hierarchy, recognizable watermark, clear text/controls. Record exact build and results.
3. Same-faction spec changes update Body only, preserving Header/branding-animation rules. Switching characters must not leave another class's pattern.
4. Mobility/Preview off, an unlearned movement skill or inactive gameplay adapter must not affect themes. Unspecialized characters use their class base.
5. Repeated changes/reopening must not stack patterns. Check bounds at different UI scales/resolutions and retain blank-area dragging, Enter and sliders.
6. Return to Mage and compare original fonts/coordinates/class color and both movement skills' depletion/first-recovery behavior. Theme changes must not restart timing.
7. Use existing diagnostics for actual resource changes. Offline object counts are not measured CPU/memory.

Fallback/runtime rules:

- Known class without spec uses its class base. Unknown/uncovered/secret/wrong-class specID also uses that base with a fallback reason, never a guessed spec.
- Unknown/secret class uses `neutral`, without a misleading class/spec watermark.
- Unknown faction affects only Header. Faction changes do not change Body; spec changes do not change Header.
- Reuse the existing pool of 64 native Lines. Only selected-pattern endpoints are generated; no 40-spec frame/pool/image precaching. All endpoints fit within center ±100; the largest pattern remains 60 lines.
- The 13/40 maps are lightweight UI identity data loaded with the theme file. Other-class theme definitions are not claimed unloaded. Generating a current pattern and activating gameplay monitoring are separate tasks.
- Options palettes are not SavedVariables and query no skills/charges/buffs. They change no reminder class color, style, position, alpha or DurationTextBinding.

## Roster and API evidence

The 40-spec roster includes Demon Hunter **Devourer 1480**, not an inferred old 39-spec list. Review pins Retail **12.1.0 / build 69933** source `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Blizzard_ClassSpecializationsFrame.lua roster](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/ClassSpecializations/Blizzard_ClassSpecializationsFrame.lua)
- [Blizzard_ClassTalentUtil.lua SpecializationVisuals cross-check](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_PlayerSpells/ClassTalents/Blizzard_ClassTalentUtil.lua)

Static gradients/Lines retain the reviewed path in [THEMES.md](THEMES.md). New shapes are original project geometry, not copies of those client icons/textures or third-party art.

The theme increment passed 102 offline groups plus theme static checks: roster/ownership, distinct palettes/geometry, endpoint bounds, 64-Line cap and unchanged Mage data. After 160 switches, it reused the same pool. Final extracted-package results remain authoritative for each delivery. Recognition, readability, watermark scaling, spec transitions and reuse still need actual visuals; offline mapping checks cannot establish those results.
