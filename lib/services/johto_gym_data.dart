import 'package:flutter/material.dart';
import '../models/game_region.dart';
import 'gym_database.dart';

final List<GymDefinition> johtoGymDefinitions = [
  // === 1. VIOLET GYM (Falkner) ===
  GymDefinition(
    id: 1,
    region: GameRegion.johto,
    name: "Violet Gym",
    city: "Violet City",
    leaderName: "Falkner",
    leaderTitle: "The Elegant Master of Flying Pokémon",
    badgeName: "Zephyr Badge",
    badgeAsset: 'assets/images/badges/zephyr_badge.png',
    badgeDescription: "+10% Phys ATK • Commands Pokémon up to Lv. 25",
    element: "Flying",
    elementColor: const Color(0xFF64B5F6),
    backgroundAsset: 'assets/images/battle_bg_gym_flying.png',
    requiredCaught: 10,
    requiredSteps: 2000,
    signatureHeldItemDrop: 'sharp_beak',
    signatureStoneDrop: 'sun_stone',
    signatureAdventureMapDrop: 'map_thunder_plains',
    tmDrops: const ['tm_43', 'tm_04', 'tm_02', 'tm_39', 'tm_32', 'tm_20'],
    rematchTrainerSpeciesIds: const [16, 17, 18, 21, 22, 84, 85, 163, 164, 177, 178, 198, 227],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 164, // Noctowl
        level: 50,
        moveIds: ['air_slash', 'psychic', 'hypnosis', 'roost'],
        heldItemId: 'sharp_beak',
      ),
      GymPokemonSpec(
        speciesId: 85, // Dodrio
        level: 50,
        moveIds: ['drill_peck', 'body_slam', 'steel_wing', 'quick_attack'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 178, // Xatu
        level: 50,
        moveIds: ['psychic', 'air_slash', 'shadow_ball', 'confuse_ray'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 227, // Skarmory
        level: 50,
        moveIds: ['steel_wing', 'drill_peck', 'rock_slide', 'stealth_rock'],
        heldItemId: 'metal_coat',
      ),
      GymPokemonSpec(
        speciesId: 169, // Crobat
        level: 50,
        moveIds: ['brave_bird', 'cross_poison', 'crunch', 'confuse_ray'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 18, // Pidgeot
        level: 50,
        moveIds: ['brave_bird', 'double_edge', 'steel_wing', 'roost'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'violet_t1',
        spriteId: 'npc_camper',
        name: 'Bird Keeper Rod',
        title: 'Sky Scout',
        prizeMoney: 400,
        introDialogue: "The high winds atop Violet Gym test every trainer's footing!",
        team: [
          GymPokemonSpec(speciesId: 16, level: 19), // Pidgey
          GymPokemonSpec(speciesId: 163, level: 21), // Hoothoot
        ],
      ),
      const GymTrainer(
        id: 'violet_t2',
        spriteId: 'npc_camper',
        name: 'Bird Keeper Abe',
        title: 'Wing Cadet',
        prizeMoney: 500,
        introDialogue: "Those who underestimate bird Pokémon soon find themselves blown away!",
        team: [
          GymPokemonSpec(speciesId: 21, level: 19), // Spearow
          GymPokemonSpec(speciesId: 177, level: 20), // Natu
          GymPokemonSpec(speciesId: 163, level: 21), // Hoothoot
        ],
      ),
      const GymTrainer(
        id: 'violet_t3',
        spriteId: 'npc_lass',
        name: 'Picnicker Erin',
        title: 'Breeze Tamer',
        prizeMoney: 600,
        introDialogue: "Watch how gracefully our Flying partners dance between cloudbursts!",
        team: [
          GymPokemonSpec(speciesId: 165, level: 18), // Ledyba
          GymPokemonSpec(speciesId: 193, level: 19), // Yanma
          GymPokemonSpec(speciesId: 17, level: 21), // Pidgeotto
          GymPokemonSpec(speciesId: 164, level: 22), // Noctowl
        ],
      ),
      const GymTrainer(
        id: 'violet_t4',
        spriteId: 'npc_camper',
        name: 'Bird Keeper Toby',
        title: 'Falkner\'s Wingman',
        prizeMoney: 750,
        introDialogue: "Prove to me your ground-bound team can even touch Falkner's flock!",
        team: [
          GymPokemonSpec(speciesId: 163, level: 18), // Hoothoot
          GymPokemonSpec(speciesId: 84, level: 19), // Doduo
          GymPokemonSpec(speciesId: 177, level: 20), // Natu
          GymPokemonSpec(speciesId: 198, level: 21), // Murkrow
          GymPokemonSpec(speciesId: 17, level: 22), // Pidgeotto
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'falkner',
      spriteId: 'leader_falkner',
      name: 'Falkner',
      title: 'Violet Gym Leader',
      prizeMoney: 2400,
      introDialogue: "I'm Falkner, the Violet Pokémon Gym Leader! People say you can clip Flying-type wings with a jolt of electricity... I won't allow such insults!",
      defeatDialogue: "...Darn! My dad's cherished bird Pokémon... All right. Take this official Zephyr Badge!",
      team: [
        GymPokemonSpec(speciesId: 163, level: 17), // Hoothoot
        GymPokemonSpec(speciesId: 21, level: 18), // Spearow
        GymPokemonSpec(speciesId: 16, level: 19), // Pidgey
        GymPokemonSpec(speciesId: 198, level: 20), // Murkrow
        GymPokemonSpec(speciesId: 164, level: 22), // Noctowl
        GymPokemonSpec(speciesId: 17, level: 24), // Pidgeotto
      ],
    ),
  ),

  // === 2. AZALEA GYM (Bugsy) ===
  GymDefinition(
    id: 2,
    region: GameRegion.johto,
    name: "Azalea Gym",
    city: "Azalea Town",
    leaderName: "Bugsy",
    leaderTitle: "The Walking Bug Pokémon Encyclopedia",
    badgeName: "Hive Badge",
    badgeAsset: 'assets/images/badges/hive_badge.png',
    badgeDescription: "+10% Spec ATK • Commands Pokémon up to Lv. 34",
    element: "Bug",
    elementColor: const Color(0xFF9CCC65),
    backgroundAsset: 'assets/images/battle_bg_gym_bug.png',
    requiredCaught: 18,
    requiredSteps: 4000,
    signatureHeldItemDrop: 'silver_powder',
    signatureStoneDrop: 'leaf_stone',
    signatureAdventureMapDrop: 'map_emerald_forest',
    tmDrops: const ['tm_03', 'tm_21', 'tm_32', 'tm_06', 'tm_09', 'tm_31'],
    rematchTrainerSpeciesIds: const [12, 15, 47, 49, 123, 127, 165, 166, 167, 168, 193, 204, 205, 212, 213, 214],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 193, // Yanma
        level: 50,
        moveIds: ['bug_buzz', 'air_slash', 'shadow_ball', 'detect'],
        heldItemId: 'silver_powder',
      ),
      GymPokemonSpec(
        speciesId: 205, // Forretress
        level: 50,
        moveIds: ['bug_bite', 'iron_head', 'earthquake', 'explosion'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 127, // Pinsir
        level: 50,
        moveIds: ['x_scissor', 'close_combat', 'stone_edge', 'swords_dance'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 213, // Shuckle
        level: 50,
        moveIds: ['toxic', 'rock_slide', 'bug_bite', 'rest'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 214, // Heracross
        level: 50,
        moveIds: ['megahorn', 'close_combat', 'stone_edge', 'night_slash'],
        heldItemId: 'silver_powder',
      ),
      GymPokemonSpec(
        speciesId: 212, // Scizor
        level: 50,
        moveIds: ['bullet_punch', 'x_scissor', 'aerial_ace', 'swords_dance'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'azalea_t1',
        spriteId: 'npc_camper',
        name: 'Bug Catcher Benny',
        title: 'Forest Entomologist',
        prizeMoney: 650,
        introDialogue: "Don't call them creepy-crawlies! Johto Bug Pokémon are ferocious!",
        team: [
          GymPokemonSpec(speciesId: 165, level: 24), // Ledyba
          GymPokemonSpec(speciesId: 167, level: 26), // Spinarak
        ],
      ),
      const GymTrainer(
        id: 'azalea_t2',
        spriteId: 'npc_lass',
        name: 'Twins Amy & Mimi',
        title: 'Canopy Twins',
        prizeMoney: 800,
        introDialogue: "Our Bug duo coordinates silk webs faster than the eye can follow!",
        team: [
          GymPokemonSpec(speciesId: 165, level: 24), // Ledyba
          GymPokemonSpec(speciesId: 167, level: 25), // Spinarak
          GymPokemonSpec(speciesId: 193, level: 26), // Yanma
        ],
      ),
      const GymTrainer(
        id: 'azalea_t3',
        spriteId: 'npc_camper',
        name: 'Bug Catcher Josh',
        title: 'Cocoon Collector',
        prizeMoney: 950,
        introDialogue: "Pineco's hard shell shrugs off weak blows before striking back!",
        team: [
          GymPokemonSpec(speciesId: 12, level: 23), // Butterfree
          GymPokemonSpec(speciesId: 15, level: 24), // Beedrill
          GymPokemonSpec(speciesId: 204, level: 26), // Pineco
          GymPokemonSpec(speciesId: 168, level: 27), // Ariados
        ],
      ),
      const GymTrainer(
        id: 'azalea_t4',
        spriteId: 'npc_camper',
        name: 'Bug Catcher Al',
        title: 'Bugsy\'s Research Aide',
        prizeMoney: 1100,
        introDialogue: "Wait till you see our research on Fury Cutter's escalating strike power!",
        team: [
          GymPokemonSpec(speciesId: 166, level: 23), // Ledian
          GymPokemonSpec(speciesId: 168, level: 24), // Ariados
          GymPokemonSpec(speciesId: 193, level: 25), // Yanma
          GymPokemonSpec(speciesId: 204, level: 26), // Pineco
          GymPokemonSpec(speciesId: 127, level: 27), // Pinsir
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'bugsy',
      spriteId: 'leader_bugsy',
      name: 'Bugsy',
      title: 'Azalea Gym Leader',
      prizeMoney: 3200,
      introDialogue: "I'm Bugsy! I never lose when it comes to Bug Pokémon! My research is going to make me the authority on Bug-types!",
      defeatDialogue: "Whoa, amazing! You're an expert on Pokémon! My research isn't complete yet—OK, you win! Take the Hive Badge!",
      team: [
        GymPokemonSpec(speciesId: 167, level: 22), // Spinarak
        GymPokemonSpec(speciesId: 165, level: 23), // Ledyba
        GymPokemonSpec(speciesId: 193, level: 24), // Yanma
        GymPokemonSpec(speciesId: 204, level: 25), // Pineco
        GymPokemonSpec(speciesId: 168, level: 27), // Ariados
        GymPokemonSpec(speciesId: 123, level: 29), // Scyther
      ],
    ),
  ),

  // === 3. GOLDENROD GYM (Whitney) ===
  GymDefinition(
    id: 3,
    region: GameRegion.johto,
    name: "Goldenrod Gym",
    city: "Goldenrod City",
    leaderName: "Whitney",
    leaderTitle: "The Incredibly Pretty Girl",
    badgeName: "Plain Badge",
    badgeAsset: 'assets/images/badges/plain_badge.png',
    badgeDescription: "+10% Speed • Commands Pokémon up to Lv. 42",
    element: "Normal",
    elementColor: const Color(0xFFF48FB1),
    backgroundAsset: 'assets/images/battle_bg_gym_normal.png',
    requiredCaught: 28,
    requiredSteps: 6000,
    signatureHeldItemDrop: 'silk_scarf',
    signatureStoneDrop: 'moon_stone',
    signatureAdventureMapDrop: 'map_mystic_sanctum',
    tmDrops: const ['tm_08', 'tm_05', 'tm_01', 'tm_49', 'tm_10', 'tm_35', 'tm_16'],
    rematchTrainerSpeciesIds: const [35, 36, 39, 40, 128, 161, 162, 183, 184, 203, 209, 210, 217, 234, 241, 242],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 36, // Clefable
        level: 50,
        moveIds: ['moonblast', 'flamethrower', 'thunderbolt', 'soft_boiled'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 210, // Granbull
        level: 50,
        moveIds: ['body_slam', 'crunch', 'earthquake', 'close_combat'],
        heldItemId: 'silk_scarf',
      ),
      GymPokemonSpec(
        speciesId: 217, // Ursaring
        level: 50,
        moveIds: ['facade', 'crunch', 'earthquake', 'hammer_arm'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 128, // Tauros
        level: 50,
        moveIds: ['body_slam', 'earthquake', 'zen_headbutt', 'stone_edge'],
        heldItemId: 'silk_scarf',
      ),
      GymPokemonSpec(
        speciesId: 242, // Blissey
        level: 50,
        moveIds: ['soft_boiled', 'ice_beam', 'thunderbolt', 'toxic'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 241, // Miltank
        level: 50,
        moveIds: ['rollout', 'milk_drink', 'body_slam', 'earthquake'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'goldenrod_t1',
        spriteId: 'npc_lass',
        name: 'Lass Carrie',
        title: 'Goldenrod Idol',
        prizeMoney: 1000,
        introDialogue: "Don't let cute pink Pokémon fool you—their attacks hit like a meteor!",
        team: [
          GymPokemonSpec(speciesId: 209, level: 33), // Snubbull
          GymPokemonSpec(speciesId: 162, level: 35), // Furret
        ],
      ),
      const GymTrainer(
        id: 'goldenrod_t2',
        spriteId: 'npc_beauty',
        name: 'Beauty Victoria',
        title: 'Starlet Duelist',
        prizeMoney: 1200,
        introDialogue: "Let's test your nerves against my charming Sentret and Furret!",
        team: [
          GymPokemonSpec(speciesId: 161, level: 33), // Sentret
          GymPokemonSpec(speciesId: 162, level: 34), // Furret
          GymPokemonSpec(speciesId: 40, level: 35), // Wigglytuff
        ],
      ),
      const GymTrainer(
        id: 'goldenrod_t3',
        spriteId: 'npc_lass',
        name: 'Lass Bridget',
        title: 'Metro Challenger',
        prizeMoney: 1400,
        introDialogue: "Aipom and Togetic pack way more speed than you expect!",
        team: [
          GymPokemonSpec(speciesId: 190, level: 32), // Aipom
          GymPokemonSpec(speciesId: 176, level: 33), // Togetic
          GymPokemonSpec(speciesId: 203, level: 35), // Girafarig
          GymPokemonSpec(speciesId: 210, level: 36), // Granbull
        ],
      ),
      const GymTrainer(
        id: 'goldenrod_t4',
        spriteId: 'npc_beauty',
        name: 'Beauty Samantha',
        title: 'Whitney\'s Fan Club',
        prizeMoney: 1650,
        introDialogue: "Wait until you face Miltank's Rollout—even hardened trainers get flattened!",
        team: [
          GymPokemonSpec(speciesId: 35, level: 32), // Clefairy
          GymPokemonSpec(speciesId: 40, level: 33), // Wigglytuff
          GymPokemonSpec(speciesId: 203, level: 34), // Girafarig
          GymPokemonSpec(speciesId: 234, level: 35), // Stantler
          GymPokemonSpec(speciesId: 242, level: 36), // Blissey
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'whitney',
      spriteId: 'leader_whitney',
      name: 'Whitney',
      title: 'Goldenrod Gym Leader',
      prizeMoney: 4200,
      introDialogue: "Hi! I'm Whitney! Everyone was into Pokémon, so I got into it too! My Pokémon are super cute—wanna battle?",
      defeatDialogue: "Waaaaah! Waaaaah! ...Sniffle. Hic... You meanie! Oh, right—I forgot to give you the Plain Badge!",
      team: [
        GymPokemonSpec(speciesId: 39, level: 31), // Jigglypuff
        GymPokemonSpec(speciesId: 35, level: 32), // Clefairy
        GymPokemonSpec(speciesId: 209, level: 33), // Snubbull
        GymPokemonSpec(speciesId: 162, level: 34), // Furret
        GymPokemonSpec(speciesId: 203, level: 36), // Girafarig
        GymPokemonSpec(
          speciesId: 241, // Miltank
          level: 38,
          moveIds: ['rollout', 'milk_drink', 'attract', 'body_slam'],
          heldItemId: 'lum_berry',
        ),
      ],
    ),
  ),

  // === 4. ECRUTEAK GYM (Morty) ===
  GymDefinition(
    id: 4,
    region: GameRegion.johto,
    name: "Ecruteak Gym",
    city: "Ecruteak City",
    leaderName: "Morty",
    leaderTitle: "The Mystic Seer of the Future",
    badgeName: "Fog Badge",
    badgeAsset: 'assets/images/badges/fog_badge.png',
    badgeDescription: "+10% Spec DEF • Commands Pokémon up to Lv. 50",
    element: "Ghost",
    elementColor: const Color(0xFF9575CD),
    backgroundAsset: 'assets/images/battle_bg_e4_ghost.png',
    requiredCaught: 40,
    requiredSteps: 8000,
    signatureHeldItemDrop: 'spell_tag',
    signatureStoneDrop: 'moon_stone',
    signatureAdventureMapDrop: 'map_toxic_marsh',
    tmDrops: const ['tm_54', 'tm_42', 'tm_30', 'tm_46', 'tm_32', 'tm_50'],
    rematchTrainerSpeciesIds: const [92, 93, 94, 164, 197, 198, 200, 229, 234],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 164, // Noctowl
        level: 50,
        moveIds: ['air_slash', 'shadow_ball', 'psychic', 'hypnosis'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 234, // Stantler
        level: 50,
        moveIds: ['shadow_ball', 'zen_headbutt', 'hypnosis', 'body_slam'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 197, // Umbreon
        level: 50,
        moveIds: ['dark_pulse', 'shadow_ball', 'confuse_ray', 'toxic'],
        heldItemId: 'black_glasses',
      ),
      GymPokemonSpec(
        speciesId: 200, // Misdreavus
        level: 50,
        moveIds: ['shadow_ball', 'psychic', 'thunderbolt', 'pain_split'],
        heldItemId: 'spell_tag',
      ),
      GymPokemonSpec(
        speciesId: 229, // Houndoom
        level: 50,
        moveIds: ['flamethrower', 'dark_pulse', 'shadow_ball', 'nasty_plot'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 94, // Gengar
        level: 50,
        moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'hypnosis'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'ecruteak_t1',
        spriteId: 'npc_psychic',
        name: 'Sage Ping',
        title: 'Burned Tower Seer',
        prizeMoney: 1350,
        introDialogue: "Watch your step in the darkness—the abyss gazes back!",
        team: [
          GymPokemonSpec(speciesId: 92, level: 41), // Gastly
          GymPokemonSpec(speciesId: 93, level: 43), // Haunter
        ],
      ),
      const GymTrainer(
        id: 'ecruteak_t2',
        spriteId: 'npc_beauty',
        name: 'Medium Grace',
        title: 'Spirit Whisperer',
        prizeMoney: 1600,
        introDialogue: "Misdreavus delights in eerie cries that freeze challenger resolve!",
        team: [
          GymPokemonSpec(speciesId: 93, level: 41), // Haunter
          GymPokemonSpec(speciesId: 200, level: 42), // Misdreavus
          GymPokemonSpec(speciesId: 94, level: 43), // Gengar
        ],
      ),
      const GymTrainer(
        id: 'ecruteak_t3',
        spriteId: 'npc_psychic',
        name: 'Sage Jeffrey',
        title: 'Tower Ascetic',
        prizeMoney: 1850,
        introDialogue: "Noctowl and Umbreon see through every trick in the midnight fog!",
        team: [
          GymPokemonSpec(speciesId: 164, level: 40), // Noctowl
          GymPokemonSpec(speciesId: 198, level: 41), // Murkrow
          GymPokemonSpec(speciesId: 200, level: 43), // Misdreavus
          GymPokemonSpec(speciesId: 197, level: 44), // Umbreon
        ],
      ),
      const GymTrainer(
        id: 'ecruteak_t4',
        spriteId: 'npc_beauty',
        name: 'Medium Martha',
        title: 'Morty\'s Attendant',
        prizeMoney: 2150,
        introDialogue: "The spirits of Ecruteak remember every legend—prove you belong before them!",
        team: [
          GymPokemonSpec(speciesId: 93, level: 40), // Haunter
          GymPokemonSpec(speciesId: 164, level: 41), // Noctowl
          GymPokemonSpec(speciesId: 200, level: 42), // Misdreavus
          GymPokemonSpec(speciesId: 229, level: 43), // Houndoom
          GymPokemonSpec(speciesId: 94, level: 44), // Gengar
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'morty',
      spriteId: 'leader_morty',
      name: 'Morty',
      title: 'Ecruteak Gym Leader',
      prizeMoney: 5400,
      introDialogue: "Good of you to have come! Here in Ecruteak, Pokémon have been revered for generations. Let me test whether your future shines alongside Ho-Oh!",
      defeatDialogue: "I'm not good enough yet... That Fog Badge is yours—you may indeed glimpse the legendary rainbow!",
      team: [
        GymPokemonSpec(speciesId: 92, level: 39), // Gastly
        GymPokemonSpec(speciesId: 93, level: 40), // Haunter
        GymPokemonSpec(speciesId: 164, level: 41), // Noctowl
        GymPokemonSpec(speciesId: 200, level: 42), // Misdreavus
        GymPokemonSpec(speciesId: 93, level: 44), // Haunter
        GymPokemonSpec(speciesId: 94, level: 46), // Gengar
      ],
    ),
  ),

  // === 5. CIANWOOD GYM (Chuck) ===
  GymDefinition(
    id: 5,
    region: GameRegion.johto,
    name: "Cianwood Gym",
    city: "Cianwood City",
    leaderName: "Chuck",
    leaderTitle: "His Roaring Fists Do the Talking",
    badgeName: "Storm Badge",
    badgeAsset: 'assets/images/badges/storm_badge.png',
    badgeDescription: "+10% Phys DEF • Commands Pokémon up to Lv. 60",
    element: "Fighting",
    elementColor: const Color(0xFFFF7043),
    backgroundAsset: 'assets/images/battle_bg_e4_fighting.png',
    requiredCaught: 55,
    requiredSteps: 10000,
    signatureHeldItemDrop: 'black_belt',
    signatureStoneDrop: 'water_stone',
    signatureAdventureMapDrop: 'map_victory_highlands',
    tmDrops: const ['tm_17', 'tm_18', 'tm_19', 'tm_40', 'tm_44', 'tm_08'],
    rematchTrainerSpeciesIds: const [56, 57, 62, 66, 67, 68, 106, 107, 214, 237],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 106, // Hitmonlee
        level: 50,
        moveIds: ['close_combat', 'blaze_kick', 'stone_edge', 'mach_punch'],
        heldItemId: 'black_belt',
      ),
      GymPokemonSpec(
        speciesId: 107, // Hitmonchan
        level: 50,
        moveIds: ['close_combat', 'ice_punch', 'thunder_punch', 'mach_punch'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 237, // Hitmontop
        level: 50,
        moveIds: ['triple_kick', 'close_combat', 'sucker_punch', 'rapid_spin'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 214, // Heracross
        level: 50,
        moveIds: ['megahorn', 'close_combat', 'stone_edge', 'night_slash'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 68, // Machamp
        level: 50,
        moveIds: ['dynamic_punch', 'stone_edge', 'bullet_punch', 'ice_punch'],
        heldItemId: 'black_belt',
      ),
      GymPokemonSpec(
        speciesId: 62, // Poliwrath
        level: 50,
        moveIds: ['waterfall', 'focus_punch', 'ice_punch', 'hypnosis'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'cianwood_t1',
        spriteId: 'npc_ninja',
        name: 'Black Belt Yoshi',
        title: 'Waterfall Trainee',
        prizeMoney: 1750,
        introDialogue: "Standing beneath Cianwood's freezing waterfall forged our spirits of iron!",
        team: [
          GymPokemonSpec(speciesId: 236, level: 49), // Tyrogue
          GymPokemonSpec(speciesId: 237, level: 51), // Hitmontop
        ],
      ),
      const GymTrainer(
        id: 'cianwood_t2',
        spriteId: 'npc_ninja',
        name: 'Black Belt Lao',
        title: 'Dojo Disciple',
        prizeMoney: 2050,
        introDialogue: "Hoo-hah! Can you endure three relentless spinning kicks in a row?!",
        team: [
          GymPokemonSpec(speciesId: 106, level: 49), // Hitmonlee
          GymPokemonSpec(speciesId: 107, level: 50), // Hitmonchan
          GymPokemonSpec(speciesId: 237, level: 51), // Hitmontop
        ],
      ),
      const GymTrainer(
        id: 'cianwood_t3',
        spriteId: 'npc_hiker',
        name: 'Black Belt Nob',
        title: 'Boulder Lifter',
        prizeMoney: 2350,
        introDialogue: "We lift boulders just like Chuck does—feel our dynamic impacts!",
        team: [
          GymPokemonSpec(speciesId: 67, level: 48), // Machoke
          GymPokemonSpec(speciesId: 57, level: 49), // Primeape
          GymPokemonSpec(speciesId: 214, level: 51), // Heracross
          GymPokemonSpec(speciesId: 68, level: 52), // Machamp
        ],
      ),
      const GymTrainer(
        id: 'cianwood_t4',
        spriteId: 'npc_ninja',
        name: 'Black Belt Lung',
        title: 'Cianwood Senior',
        prizeMoney: 2700,
        introDialogue: "Master Chuck waits past the waterfall! Only true fighters advance!",
        team: [
          GymPokemonSpec(speciesId: 57, level: 48), // Primeape
          GymPokemonSpec(speciesId: 106, level: 49), // Hitmonlee
          GymPokemonSpec(speciesId: 214, level: 50), // Heracross
          GymPokemonSpec(speciesId: 68, level: 51), // Machamp
          GymPokemonSpec(speciesId: 62, level: 52), // Poliwrath
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'chuck',
      spriteId: 'leader_chuck',
      name: 'Chuck',
      title: 'Cianwood Gym Leader',
      prizeMoney: 6800,
      introDialogue: "WAHAHAHA! You came all the way across the sea just to challenge me?! Come on—witness 24-hour boulder-crushing power!",
      defeatDialogue: "Whaaat? Lost?! ...Oof, all right! That was a good match—take the Storm Badge!",
      team: [
        GymPokemonSpec(speciesId: 67, level: 47), // Machoke
        GymPokemonSpec(speciesId: 57, level: 48), // Primeape
        GymPokemonSpec(speciesId: 237, level: 49), // Hitmontop
        GymPokemonSpec(speciesId: 214, level: 50), // Heracross
        GymPokemonSpec(speciesId: 68, level: 52), // Machamp
        GymPokemonSpec(speciesId: 62, level: 54), // Poliwrath
      ],
    ),
  ),

  // === 6. OLIVINE GYM (Jasmine) ===
  GymDefinition(
    id: 6,
    region: GameRegion.johto,
    name: "Olivine Gym",
    city: "Olivine City",
    leaderName: "Jasmine",
    leaderTitle: "The Steel-Clad Defense Girl",
    badgeName: "Mineral Badge",
    badgeAsset: 'assets/images/badges/mineral_badge.png',
    badgeDescription: "+10% Max HP • Commands Pokémon up to Lv. 70",
    element: "Steel",
    elementColor: const Color(0xFF90A4AE),
    backgroundAsset: 'assets/images/battle_bg_gym_steel.png',
    requiredCaught: 70,
    requiredSteps: 12000,
    signatureHeldItemDrop: 'metal_coat',
    signatureStoneDrop: 'thunder_stone',
    signatureAdventureMapDrop: 'map_underground_cave',
    tmDrops: const ['tm_24', 'tm_45', 'tm_33', 'tm_34', 'tm_48', 'tm_28'],
    rematchTrainerSpeciesIds: const [81, 82, 95, 205, 208, 212, 227, 232],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 82, // Magneton
        level: 50,
        moveIds: ['thunderbolt', 'flash_cannon', 'tri_attack', 'thunder_wave'],
        heldItemId: 'magnet',
      ),
      GymPokemonSpec(
        speciesId: 205, // Forretress
        level: 50,
        moveIds: ['gyro_ball', 'bug_bite', 'earthquake', 'explosion'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 227, // Skarmory
        level: 50,
        moveIds: ['steel_wing', 'brave_bird', 'stealth_rock', 'roost'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 212, // Scizor
        level: 50,
        moveIds: ['bullet_punch', 'x_scissor', 'iron_head', 'swords_dance'],
        heldItemId: 'metal_coat',
      ),
      GymPokemonSpec(
        speciesId: 232, // Donphan
        level: 50,
        moveIds: ['earthquake', 'stone_edge', 'ice_shard', 'gyro_ball'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 208, // Steelix
        level: 50,
        moveIds: ['iron_tail', 'earthquake', 'rock_slide', 'crunch'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'olivine_t1',
        spriteId: 'npc_engineer',
        name: 'Engineer Preston',
        title: 'Lighthouse Mechanic',
        prizeMoney: 2200,
        introDialogue: "Steel-type armor resists almost everything! Let's see your plan!",
        team: [
          GymPokemonSpec(speciesId: 81, level: 59), // Magnemite
          GymPokemonSpec(speciesId: 82, level: 61), // Magneton
        ],
      ),
      const GymTrainer(
        id: 'olivine_t2',
        spriteId: 'npc_swimmer',
        name: 'Sailor Huey',
        title: 'S.S. Aqua Guard',
        prizeMoney: 2550,
        introDialogue: "The beacon of Olivine shines thanks to our Ampharos and Steel partners!",
        team: [
          GymPokemonSpec(speciesId: 181, level: 59), // Ampharos
          GymPokemonSpec(speciesId: 205, level: 60), // Forretress
          GymPokemonSpec(speciesId: 227, level: 61), // Skarmory
        ],
      ),
      const GymTrainer(
        id: 'olivine_t3',
        spriteId: 'npc_engineer',
        name: 'Gentleman Alfred',
        title: 'Harbor Benefactor',
        prizeMoney: 2950,
        introDialogue: "Kindly pardon the chill of gleaming steel!",
        team: [
          GymPokemonSpec(speciesId: 95, level: 58), // Onix
          GymPokemonSpec(speciesId: 82, level: 59), // Magneton
          GymPokemonSpec(speciesId: 212, level: 61), // Scizor
          GymPokemonSpec(speciesId: 208, level: 62), // Steelix
        ],
      ),
      const GymTrainer(
        id: 'olivine_t4',
        spriteId: 'npc_engineer',
        name: 'Engineer Connor',
        title: 'Alloy Architect',
        prizeMoney: 3400,
        introDialogue: "Jasmine treats every Steel Pokémon with gentle warmth—and unbreakable resolve!",
        team: [
          GymPokemonSpec(speciesId: 82, level: 58), // Magneton
          GymPokemonSpec(speciesId: 205, level: 59), // Forretress
          GymPokemonSpec(speciesId: 227, level: 60), // Skarmory
          GymPokemonSpec(speciesId: 212, level: 61), // Scizor
          GymPokemonSpec(speciesId: 208, level: 62), // Steelix
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'jasmine',
      spriteId: 'leader_jasmine',
      name: 'Jasmine',
      title: 'Olivine Gym Leader',
      prizeMoney: 8200,
      introDialogue: "...Thank you for helping Amphy at the Lighthouse. But this is different... Please allow me to introduce you to Steel-type Pokémon!",
      defeatDialogue: "...You are a better trainer than me, in both skill and kindness. Here is the Mineral Badge.",
      team: [
        GymPokemonSpec(speciesId: 81, level: 57), // Magnemite
        GymPokemonSpec(speciesId: 205, level: 58), // Forretress
        GymPokemonSpec(speciesId: 82, level: 59), // Magneton
        GymPokemonSpec(speciesId: 227, level: 60), // Skarmory
        GymPokemonSpec(speciesId: 212, level: 62), // Scizor
        GymPokemonSpec(speciesId: 208, level: 64), // Steelix
      ],
    ),
  ),

  // === 7. MAHOGANY GYM (Pryce) ===
  GymDefinition(
    id: 7,
    region: GameRegion.johto,
    name: "Mahogany Gym",
    city: "Mahogany Town",
    leaderName: "Pryce",
    leaderTitle: "The Teacher of Winter's Harshness",
    badgeName: "Glacier Badge",
    badgeAsset: 'assets/images/badges/glacier_badge.png',
    badgeDescription: "+10% Critical Hit Rate • Commands Pokémon up to Lv. 82",
    element: "Ice",
    elementColor: const Color(0xFF4DD0E1),
    backgroundAsset: 'assets/images/battle_bg_e4_ice.png',
    requiredCaught: 85,
    requiredSteps: 15000,
    signatureHeldItemDrop: 'never_melt_ice',
    signatureStoneDrop: 'kings_rock',
    signatureAdventureMapDrop: 'map_deep_sea',
    tmDrops: const ['tm_13', 'tm_14', 'tm_11', 'tm_12', 'tm_44', 'tm_36'],
    rematchTrainerSpeciesIds: const [86, 87, 90, 91, 124, 131, 215, 220, 221, 225],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 87, // Dewgong
        level: 50,
        moveIds: ['ice_beam', 'surf', 'signal_beam', 'ice_shard'],
        heldItemId: 'never_melt_ice',
      ),
      GymPokemonSpec(
        speciesId: 91, // Cloyster
        level: 50,
        moveIds: ['icicle_spear', 'hydro_pump', 'ice_shard', 'explosion'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 215, // Sneasel
        level: 50,
        moveIds: ['ice_punch', 'night_slash', 'low_kick', 'ice_shard'],
        heldItemId: 'black_glasses',
      ),
      GymPokemonSpec(
        speciesId: 124, // Jynx
        level: 50,
        moveIds: ['ice_beam', 'psychic', 'lovely_kiss', 'shadow_ball'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 131, // Lapras
        level: 50,
        moveIds: ['blizzard', 'surf', 'thunderbolt', 'ice_beam'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 221, // Piloswine
        level: 50,
        moveIds: ['earthquake', 'avalanche', 'ice_shard', 'stone_edge'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'mahogany_t1',
        spriteId: 'npc_lass',
        name: 'Skier Roxanne',
        title: 'Snowfield Glider',
        prizeMoney: 2700,
        introDialogue: "Don't slip on our ice floor! My Jynx freezes challengers solid!",
        team: [
          GymPokemonSpec(speciesId: 225, level: 69), // Delibird
          GymPokemonSpec(speciesId: 124, level: 71), // Jynx
        ],
      ),
      const GymTrainer(
        id: 'mahogany_t2',
        spriteId: 'npc_camper',
        name: 'Boarder Ronald',
        title: 'Ice Path Veteran',
        prizeMoney: 3100,
        introDialogue: "We trained through Ice Path blizzards—your pace will freeze right here!",
        team: [
          GymPokemonSpec(speciesId: 86, level: 69), // Seel
          GymPokemonSpec(speciesId: 87, level: 70), // Dewgong
          GymPokemonSpec(speciesId: 91, level: 71), // Cloyster
        ],
      ),
      const GymTrainer(
        id: 'mahogany_t3',
        spriteId: 'npc_beauty',
        name: 'Skier Clarissa',
        title: 'Frost Choreographer',
        prizeMoney: 3600,
        introDialogue: "Winter teaches patience—and rewards decisive Blizzard strikes!",
        team: [
          GymPokemonSpec(speciesId: 220, level: 68), // Swinub
          GymPokemonSpec(speciesId: 215, level: 69), // Sneasel
          GymPokemonSpec(speciesId: 131, level: 71), // Lapras
          GymPokemonSpec(speciesId: 221, level: 72), // Piloswine
        ],
      ),
      const GymTrainer(
        id: 'mahogany_t4',
        spriteId: 'npc_camper',
        name: 'Boarder Douglas',
        title: 'Pryce\'s Senior Pupil',
        prizeMoney: 4100,
        introDialogue: "Few trainers possess the warmth to overcome Pryce's fifty-year chill!",
        team: [
          GymPokemonSpec(speciesId: 91, level: 68), // Cloyster
          GymPokemonSpec(speciesId: 87, level: 69), // Dewgong
          GymPokemonSpec(speciesId: 215, level: 70), // Sneasel
          GymPokemonSpec(speciesId: 131, level: 71), // Lapras
          GymPokemonSpec(speciesId: 221, level: 72), // Piloswine
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'pryce',
      spriteId: 'leader_pryce',
      name: 'Pryce',
      title: 'Mahogany Gym Leader',
      prizeMoney: 9800,
      introDialogue: "Pokémon have many experiences in their lives, just like we do. I, too, have seen and suffered much—let me show you the harshness of winter!",
      defeatDialogue: "Ah, I am impressed by your prowess. With your strong will, you have earned the Glacier Badge!",
      team: [
        GymPokemonSpec(speciesId: 86, level: 67), // Seel
        GymPokemonSpec(speciesId: 220, level: 68), // Swinub
        GymPokemonSpec(speciesId: 87, level: 69), // Dewgong
        GymPokemonSpec(speciesId: 215, level: 70), // Sneasel
        GymPokemonSpec(speciesId: 124, level: 72), // Jynx
        GymPokemonSpec(speciesId: 221, level: 74), // Piloswine
      ],
    ),
  ),

  // === 8. BLACKTHORN GYM (Clair) ===
  GymDefinition(
    id: 8,
    region: GameRegion.johto,
    name: "Blackthorn Gym",
    city: "Blackthorn City",
    leaderName: "Clair",
    leaderTitle: "The Blessed User of Dragon Pokémon",
    badgeName: "Rising Badge",
    badgeAsset: 'assets/images/badges/rising_badge.png',
    badgeDescription: "Master Boost (+5% All Stats) • Commands Lv. 100 • Unlocks EXP Share & Expeditions",
    element: "Dragon",
    elementColor: const Color(0xFF5C6BC0),
    backgroundAsset: 'assets/images/battle_bg_e4_dragon.png',
    requiredCaught: 100,
    requiredSteps: 20000,
    signatureHeldItemDrop: 'dragon_fang',
    signatureStoneDrop: 'dragon_scale',
    signatureAdventureMapDrop: 'map_volcanic_ridge',
    tmDrops: const ['tm_23', 'tm_38', 'tm_25', 'tm_26', 'tm_15', 'tm_07'],
    rematchTrainerSpeciesIds: const [6, 116, 117, 130, 131, 142, 147, 148, 149, 230, 248],
    rematchLeaderSpecs: const [
      GymPokemonSpec(
        speciesId: 130, // Gyarados
        level: 50,
        moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'],
        heldItemId: 'mystic_water',
      ),
      GymPokemonSpec(
        speciesId: 148, // Dragonair
        level: 50,
        moveIds: ['dragon_pulse', 'thunderbolt', 'ice_beam', 'extreme_speed'],
        heldItemId: 'sitrus_berry',
      ),
      GymPokemonSpec(
        speciesId: 131, // Lapras
        level: 50,
        moveIds: ['surf', 'ice_beam', 'thunderbolt', 'dragon_pulse'],
        heldItemId: 'lum_berry',
      ),
      GymPokemonSpec(
        speciesId: 248, // Tyranitar
        level: 50,
        moveIds: ['stone_edge', 'crunch', 'earthquake', 'dragon_dance'],
        heldItemId: 'hard_stone',
      ),
      GymPokemonSpec(
        speciesId: 149, // Dragonite
        level: 50,
        moveIds: ['dragon_claw', 'fire_punch', 'earthquake', 'extreme_speed'],
        heldItemId: 'dragon_fang',
      ),
      GymPokemonSpec(
        speciesId: 230, // Kingdra
        level: 50,
        moveIds: ['hydro_pump', 'dragon_pulse', 'ice_beam', 'rain_dance'],
        heldItemId: 'leftovers',
      ),
    ],
    trainers: [
      const GymTrainer(
        id: 'blackthorn_t1',
        spriteId: 'npc_camper',
        name: 'Cooltrainer Paul',
        title: 'Dragon Sanctum Guard',
        prizeMoney: 3300,
        introDialogue: "Dragon Pokémon tolerate no hesitation! Brace for their might!",
        team: [
          GymPokemonSpec(speciesId: 147, level: 81), // Dratini
          GymPokemonSpec(speciesId: 148, level: 83), // Dragonair
        ],
      ),
      const GymTrainer(
        id: 'blackthorn_t2',
        spriteId: 'npc_beauty',
        name: 'Cooltrainer Fran',
        title: 'Dragon Tamer',
        prizeMoney: 3850,
        introDialogue: "The elders of Dragon's Den tested us—let's see if you survive!",
        team: [
          GymPokemonSpec(speciesId: 117, level: 81), // Seadra
          GymPokemonSpec(speciesId: 130, level: 82), // Gyarados
          GymPokemonSpec(speciesId: 230, level: 83), // Kingdra
        ],
      ),
      const GymTrainer(
        id: 'blackthorn_t3',
        spriteId: 'npc_engineer',
        name: 'Cooltrainer Cody',
        title: 'Wyvern Strategist',
        prizeMoney: 4450,
        introDialogue: "Kingdra has only one weakness—good luck cracking its defenses!",
        team: [
          GymPokemonSpec(speciesId: 148, level: 80), // Dragonair
          GymPokemonSpec(speciesId: 142, level: 81), // Aerodactyl
          GymPokemonSpec(speciesId: 6, level: 83), // Charizard
          GymPokemonSpec(speciesId: 149, level: 84), // Dragonite
        ],
      ),
      const GymTrainer(
        id: 'blackthorn_t4',
        spriteId: 'npc_beauty',
        name: 'Cooltrainer Lola',
        title: 'Clair\'s First Apprentice',
        prizeMoney: 5100,
        introDialogue: "Beyond this lava bridge stands Clair, proud cousin of Champion Lance!",
        team: [
          GymPokemonSpec(speciesId: 117, level: 80), // Seadra
          GymPokemonSpec(speciesId: 148, level: 81), // Dragonair
          GymPokemonSpec(speciesId: 131, level: 82), // Lapras
          GymPokemonSpec(speciesId: 149, level: 83), // Dragonite
          GymPokemonSpec(speciesId: 230, level: 84), // Kingdra
        ],
      ),
    ],
    leader: const GymTrainer(
      id: 'clair',
      spriteId: 'leader_clair',
      name: 'Clair',
      title: 'Blackthorn Gym Leader',
      prizeMoney: 12000,
      introDialogue: "I am Clair, the world's best Dragon master! I can hold my own against even the Pokémon League's Champion... Come—face me as an equal!",
      defeatDialogue: "I lost?! I don't believe it... Very well, you have proven worthy of Dragon's Den. Take the Rising Badge!",
      team: [
        GymPokemonSpec(speciesId: 117, level: 79), // Seadra
        GymPokemonSpec(speciesId: 148, level: 80), // Dragonair
        GymPokemonSpec(speciesId: 130, level: 81), // Gyarados
        GymPokemonSpec(speciesId: 131, level: 82), // Lapras
        GymPokemonSpec(speciesId: 149, level: 84), // Dragonite
        GymPokemonSpec(speciesId: 230, level: 86), // Kingdra
      ],
    ),
  ),
];
