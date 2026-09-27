local _, addon = ...

-- Configuration ownership only. No spell, aura, talent, texture or runtime
-- adapter data lives here. Keep stable saved-region IDs when mappings evolve.
-- Generated offline from the alpha.16 admitted definitions, including retained
-- historical Mage regions so valid existing settings remain portable.
addon.settingsMetadata = {
    schemaVersion = 5,
    classes = {
        DEATHKNIGHT = {
            [250] = {
                ["deathknight_blood_crimson_scourge_left"] = true,
                ["deathknight_blood_crimson_scourge_right"] = true,
                ["deathknight_blood_dance_midnight_top"] = true,
            },
            [251] = {
                ["deathknight_frost_killing_machine_left"] = true,
                ["deathknight_frost_killing_machine_second_right"] = true,
                ["deathknight_frost_rime_top"] = true,
            },
            [252] = {
                ["deathknight_unholy_sudden_doom_left"] = true,
                ["deathknight_unholy_sudden_doom_second_right"] = true,
            },
        },
        DEMONHUNTER = {
            [577] = {
                ["demonhunter_577_chaos_theory_left"] = true,
                ["demonhunter_577_chaos_theory_right"] = true,
            },
            [581] = {
                ["demonhunter_581_untethered_rage_top"] = true,
            },
            [1480] = {
                ["demonhunter_1480_moment_of_craving_top"] = true,
            },
        },
        DRUID = {
            [102] = {
                ["druid_balance_owlkin_frenzy_top"] = true,
            },
            [103] = {
                ["druid_feral_clearcasting_left"] = true,
                ["druid_feral_clearcasting_right"] = true,
            },
            [104] = {
                ["druid_guardian_celestial_might_right"] = true,
                ["druid_guardian_galactic_guardian_left"] = true,
                ["druid_guardian_gore_top"] = true,
            },
            [105] = {
                ["druid_restoration_clearcasting_left"] = true,
                ["druid_restoration_clearcasting_right"] = true,
            },
        },
        EVOKER = {
            [1467] = {
                ["evoker_devastation_essence_burst_left"] = true,
            },
            [1468] = {
                ["evoker_preservation_essence_burst_left"] = true,
                ["evoker_preservation_lifespark_top"] = true,
            },
            [1473] = {
                ["evoker_augmentation_essence_burst_left"] = true,
            },
        },
        HUNTER = {
            [253] = {
                ["hunter_253_deathblow_bottom"] = true,
                ["hunter_253_pack_leader_bear_left"] = true,
                ["hunter_253_pack_leader_bear_right"] = true,
                ["hunter_253_pack_leader_boar_left"] = true,
                ["hunter_253_pack_leader_boar_right"] = true,
                ["hunter_253_pack_leader_wyvern_left"] = true,
                ["hunter_253_pack_leader_wyvern_right"] = true,
            },
            [254] = {
                ["hunter_254_deathblow_bottom"] = true,
                ["hunter_254_lock_and_load_top"] = true,
                ["hunter_254_precise_shots_left"] = true,
                ["hunter_254_precise_shots_right"] = true,
            },
            [255] = {
                ["hunter_255_pack_leader_bear_left"] = true,
                ["hunter_255_pack_leader_bear_right"] = true,
                ["hunter_255_pack_leader_boar_left"] = true,
                ["hunter_255_pack_leader_boar_right"] = true,
                ["hunter_255_pack_leader_wyvern_left"] = true,
                ["hunter_255_pack_leader_wyvern_right"] = true,
            },
        },
        MAGE = {
            [62] = {
                ["mage_arcane_clearcasting_left"] = true,
                ["mage_arcane_clearcasting_right"] = true,
                ["mage_arcane_overpowered_missiles_top"] = true,
                ["mage_arcane_soul_left"] = true,
                ["mage_arcane_soul_right"] = true,
            },
            [63] = {
                ["mage_fire_fury_sun_king_top"] = true,
                ["mage_fire_heating_up_left"] = true,
                ["mage_fire_heating_up_right"] = true,
                ["mage_fire_hot_streak_left"] = true,
                ["mage_fire_hot_streak_right"] = true,
                ["mage_fire_hyperthermia_left"] = true,
                ["mage_fire_hyperthermia_right"] = true,
                ["mage_fire_pyroclasm_top"] = true,
            },
            [64] = {
                ["mage_frost_brain_freeze_top"] = true,
                ["mage_frost_fingers_left"] = true,
                ["mage_frost_fingers_right"] = true,
            },
        },
        MONK = {
            [268] = {
                ["monk_268_potential_energy_top"] = true,
            },
            [269] = {
                ["monk_269_blackout_kick_right"] = true,
                ["monk_269_strength_black_ox_left"] = true,
            },
            [270] = {
                ["monk_270_potential_energy_top"] = true,
                ["monk_270_strength_black_ox_left"] = true,
                ["monk_270_zen_pulse_right"] = true,
            },
        },
        PALADIN = {
            [65] = {
                ["paladin_holy_divine_purpose_top"] = true,
                ["paladin_holy_infusion_light_left"] = true,
                ["paladin_holy_infusion_light_second_right"] = true,
            },
            [66] = {
                ["paladin_protection_divine_purpose_top"] = true,
            },
            [70] = {
                ["paladin_retribution_art_war_left"] = true,
                ["paladin_retribution_divine_purpose_top"] = true,
                ["paladin_retribution_righteous_cause_left"] = true,
            },
        },
        PRIEST = {
            [256] = {
                ["priest_discipline_harsh_discipline_top"] = true,
                ["priest_discipline_power_dark_side_left"] = true,
                ["priest_discipline_power_dark_side_right"] = true,
                ["priest_discipline_surge_light_left"] = true,
                ["priest_discipline_surge_light_second_right"] = true,
            },
            [257] = {
                ["priest_holy_benediction_top"] = true,
                ["priest_holy_surge_light_left"] = true,
                ["priest_holy_surge_light_second_right"] = true,
            },
            [258] = {
                ["priest_shadow_mind_flay_insanity_left"] = true,
                ["priest_shadow_shadowy_insight_top"] = true,
                ["priest_shadow_surge_light_left"] = true,
                ["priest_shadow_surge_light_second_right"] = true,
            },
        },
        ROGUE = {
            [259] = {
                ["rogue_assassination_blindside_left"] = true,
                ["rogue_assassination_blindside_right"] = true,
            },
            [260] = {
                ["rogue_outlaw_opportunity_top"] = true,
            },
            [261] = {
                ["rogue_subtlety_ancient_arts_left"] = true,
                ["rogue_subtlety_ancient_arts_right"] = true,
            },
        },
        SHAMAN = {
            [262] = {
                ["shaman_elemental_lava_surge_left"] = true,
                ["shaman_elemental_lava_surge_right"] = true,
            },
            [263] = {
            },
            [264] = {
                ["shaman_restoration_high_tide_top"] = true,
                ["shaman_restoration_lava_surge_left"] = true,
                ["shaman_restoration_lava_surge_right"] = true,
            },
        },
        WARLOCK = {
            [265] = {
                ["warlock_affliction_nightfall_left"] = true,
                ["warlock_affliction_nightfall_right"] = true,
            },
            [266] = {
                ["warlock_demonology_demonic_core_left"] = true,
                ["warlock_demonology_demonic_core_right"] = true,
            },
            [267] = {
            },
        },
        WARRIOR = {
            [71] = {
            },
            [72] = {
            },
            [73] = {
                ["warrior_73_revenge_right"] = true,
            },
        },
    },
}
