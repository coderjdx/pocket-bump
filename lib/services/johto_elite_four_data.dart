import 'dart:math';
import 'package:flutter/material.dart';
import '../models/trainer.dart';
import 'elite_four_database.dart';
import 'gym_database.dart';
import 'sound_service.dart';

const List<int> johtoVictoryRoadWildSpeciesPool = [
  42, // Golbat
  95, // Onix
  112, // Rhydon
  169, // Crobat
  205, // Forretress
  207, // Gligar
  208, // Steelix
  214, // Heracross
  215, // Sneasel
  217, // Ursaring
  219, // Magcargo
  221, // Piloswine
  227, // Skarmory
  229, // Houndoom
  232, // Donphan
  247, // Pupitar
];

List<VictoryRoadStage> buildJohtoFirstAscentStages() {
  return const [
    VictoryRoadStage.wild(
      stageNumber: 1,
      level: 85,
      label: 'Tohjo Summit Cavern (Wild)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 2,
      customLabel: 'Ace Trainer Kendra',
      trainer: GymTrainer(
        id: 'johto_vr_ascent_t1',
        spriteId: 'npc_beauty',
        name: 'Ace Trainer Kendra',
        title: 'Johto Victory Road Challenger',
        prizeMoney: 4200,
        introDialogue:
            "With all eight Johto Badges earned, only Victory Road stands between us and Indigo Plateau!",
        defeatDialogue:
            "What crisp teamwork! You're ready for the Silver Conference summit!",
        team: [
          GymPokemonSpec(speciesId: 181, level: 86, heldItemId: 'magnet'), // Ampharos
          GymPokemonSpec(speciesId: 184, level: 87), // Azumarill
          GymPokemonSpec(speciesId: 196, level: 87, heldItemId: 'twisted_spoon'), // Espeon
          GymPokemonSpec(speciesId: 212, level: 88, heldItemId: 'sitrus_berry'), // Scizor
        ],
      ),
    ),
    VictoryRoadStage.wild(
      stageNumber: 3,
      level: 86,
      label: 'Gorge Passage (Wild)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 4,
      customLabel: 'Black Belt Kenji',
      trainer: GymTrainer(
        id: 'johto_vr_ascent_t2',
        spriteId: 'npc_ninja',
        name: 'Black Belt Kenji',
        title: 'Mt. Mortar Ascetic',
        prizeMoney: 4800,
        introDialogue:
            "From Mt. Mortar's waterfalls to Victory Road's cliffs—taste our unbreakable martial force!",
        defeatDialogue:
            "Hoo hah! Not even Heracross and Machamp could halt your climb!",
        team: [
          GymPokemonSpec(speciesId: 237, level: 87), // Hitmontop
          GymPokemonSpec(speciesId: 214, level: 88, heldItemId: 'black_belt'), // Heracross
          GymPokemonSpec(speciesId: 217, level: 88), // Ursaring
          GymPokemonSpec(speciesId: 62, level: 88, heldItemId: 'sitrus_berry'), // Poliwrath
          GymPokemonSpec(speciesId: 68, level: 89, heldItemId: 'lum_berry'), // Machamp
        ],
      ),
    ),
    VictoryRoadStage.wild(
      stageNumber: 5,
      level: 88,
      label: 'Silver Ridge (Wild)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 6,
      customLabel: 'Veteran Vance',
      trainer: GymTrainer(
        id: 'johto_vr_ascent_t3',
        spriteId: 'npc_engineer',
        name: 'Veteran Vance',
        title: 'Johto Gatekeeper',
        prizeMoney: 5600,
        introDialogue:
            "You stand at the northern threshold of Indigo Plateau! Show me your bond before facing Will and Lance!",
        defeatDialogue:
            "Incredible strength and trust... Step inside Indigo Plateau!",
        team: [
          GymPokemonSpec(speciesId: 208, level: 88, heldItemId: 'metal_coat'), // Steelix
          GymPokemonSpec(speciesId: 230, level: 89, heldItemId: 'mystic_water'), // Kingdra
          GymPokemonSpec(speciesId: 229, level: 89, heldItemId: 'charcoal'), // Houndoom
          GymPokemonSpec(speciesId: 232, level: 89, heldItemId: 'soft_sand'), // Donphan
          GymPokemonSpec(speciesId: 248, level: 90, heldItemId: 'lum_berry'), // Tyranitar
        ],
      ),
    ),
  ];
}

List<LeagueBossTrainer> buildJohtoEliteFourAndChampionStages(Trainer trainer) {
  return const [
    LeagueBossTrainer(
      id: 'e4_johto_will',
      spriteId: 'e4_will',
      name: 'Will',
      title: 'Final Four • Psychic Master',
      roleLabel: 'FINAL FOUR #1',
      chamberName: 'Astral Psychic Sanctum',
      backgroundAsset: 'assets/images/battle_bg_gym_psychic.png',
      accentColor: Color(0xFFAB47BC),
      prizeMoney: 11000,
      introDialogue:
          "Welcome to Pokémon League, challenger! Allow me to introduce myself. I am Will. I have trained all around the world, making my Psychic Pokémon powerful!",
      defeatDialogue:
          "I... I can't believe it... Retaining my pride, I must let you pass into the next chamber.",
      exclusiveHeldItemId: 'twisted_spoon',
      exclusiveTmId: 'tm_52',
      team: [
        GymPokemonSpec(speciesId: 203, level: 88, moveIds: ['psychic', 'crunch', 'thunderbolt', 'baton_pass'], heldItemId: 'sitrus_berry'), // Girafarig
        GymPokemonSpec(speciesId: 199, level: 89, moveIds: ['surf', 'psychic', 'ice_beam', 'flamethrower'], heldItemId: 'leftovers'), // Slowking
        GymPokemonSpec(speciesId: 124, level: 89, moveIds: ['ice_beam', 'psychic', 'lovely_kiss', 'shadow_ball'], heldItemId: 'lum_berry'), // Jynx
        GymPokemonSpec(speciesId: 103, level: 90, moveIds: ['psychic', 'leaf_storm', 'sleep_powder', 'sludge_bomb'], heldItemId: 'miracle_seed'), // Exeggutor
        GymPokemonSpec(speciesId: 196, level: 90, moveIds: ['psychic', 'shadow_ball', 'morning_sun', 'calm_mind'], heldItemId: 'twisted_spoon'), // Espeon
        GymPokemonSpec(speciesId: 178, level: 91, moveIds: ['psychic', 'air_slash', 'future_sight', 'confuse_ray'], heldItemId: 'twisted_spoon'), // Xatu
      ],
    ),
    LeagueBossTrainer(
      id: 'e4_johto_koga',
      spriteId: 'leader_koga',
      name: 'Koga',
      title: 'Final Four • Poison Master',
      roleLabel: 'FINAL FOUR #2',
      chamberName: 'Shadow Venom Dojo',
      backgroundAsset: 'assets/images/battle_bg_gym_poison.png',
      accentColor: Color(0xFF8E24AA),
      prizeMoney: 12000,
      introDialogue:
          "Fwahahaha! A formidable trainer steps from Johto's shadows! Despair before my evolved ninja techniques and lethal toxins!",
      defeatDialogue:
          "Hmph! You've mastered even the hidden depths of battle! Venture onward!",
      exclusiveHeldItemId: 'poison_barb',
      exclusiveTmId: 'tm_54',
      team: [
        GymPokemonSpec(speciesId: 168, level: 89, moveIds: ['poison_jab', 'x_scissor', 'sucker_punch', 'spider_web'], heldItemId: 'silver_powder'), // Ariados
        GymPokemonSpec(speciesId: 205, level: 90, moveIds: ['gyro_ball', 'earthquake', 'explosion', 'toxic_spikes'], heldItemId: 'sitrus_berry'), // Forretress
        GymPokemonSpec(speciesId: 49, level: 90, moveIds: ['bug_buzz', 'sludge_bomb', 'psychic', 'sleep_powder'], heldItemId: 'lum_berry'), // Venomoth
        GymPokemonSpec(speciesId: 89, level: 91, moveIds: ['gunk_shot', 'shadow_punch', 'ice_punch', 'fire_punch'], heldItemId: 'leftovers'), // Muk
        GymPokemonSpec(speciesId: 110, level: 91, moveIds: ['sludge_bomb', 'fire_blast', 'thunderbolt', 'explosion'], heldItemId: 'poison_barb'), // Weezing
        GymPokemonSpec(speciesId: 169, level: 92, moveIds: ['brave_bird', 'cross_poison', 'crunch', 'confuse_ray'], heldItemId: 'poison_barb'), // Crobat
      ],
    ),
    LeagueBossTrainer(
      id: 'e4_johto_bruno',
      spriteId: 'e4_bruno',
      name: 'Bruno',
      title: 'Final Four • Fighting Master',
      roleLabel: 'FINAL FOUR #3',
      chamberName: 'Fighting Cavern',
      backgroundAsset: 'assets/images/battle_bg_e4_fighting.png',
      accentColor: Color(0xFFFF7043),
      prizeMoney: 13000,
      introDialogue:
          "I am Bruno of the Final Four! My Fighting-type partners and Steelix crush boulders like dry leaves! Hoo hah!",
      defeatDialogue:
          "Having lost, I have no right to say anything. Go face your next test with pride!",
      exclusiveHeldItemId: 'black_belt',
      exclusiveTmId: 'tm_53',
      team: [
        GymPokemonSpec(speciesId: 237, level: 90, moveIds: ['triple_kick', 'close_combat', 'sucker_punch', 'stone_edge'], heldItemId: 'sitrus_berry'), // Hitmontop
        GymPokemonSpec(speciesId: 106, level: 91, moveIds: ['close_combat', 'blaze_kick', 'stone_edge', 'mach_punch'], heldItemId: 'black_belt'), // Hitmonlee
        GymPokemonSpec(speciesId: 107, level: 91, moveIds: ['close_combat', 'ice_punch', 'thunder_punch', 'bullet_punch'], heldItemId: 'lum_berry'), // Hitmonchan
        GymPokemonSpec(speciesId: 208, level: 92, moveIds: ['iron_tail', 'earthquake', 'stone_edge', 'crunch'], heldItemId: 'metal_coat'), // Steelix
        GymPokemonSpec(speciesId: 214, level: 92, moveIds: ['megahorn', 'close_combat', 'stone_edge', 'night_slash'], heldItemId: 'sitrus_berry'), // Heracross
        GymPokemonSpec(speciesId: 68, level: 93, moveIds: ['dynamic_punch', 'close_combat', 'stone_edge', 'bullet_punch'], heldItemId: 'black_belt'), // Machamp
      ],
    ),
    LeagueBossTrainer(
      id: 'e4_johto_karen',
      spriteId: 'e4_karen',
      name: 'Karen',
      title: 'Final Four • Dark Master',
      roleLabel: 'FINAL FOUR #4',
      chamberName: 'Moonlit Shadow Chamber',
      backgroundAsset: 'assets/images/battle_bg_e4_dark.png',
      accentColor: Color(0xFF546E7A),
      prizeMoney: 15000,
      introDialogue:
          "I am Karen of the Final Four. Strong Pokémon, weak Pokémon—that is only the selfish perception of people. Truly skilled trainers win with their favorites!",
      defeatDialogue:
          "Well, aren't you charming? Just as I thought... Someone awaits you in the Champion's chamber.",
      exclusiveHeldItemId: 'black_glasses',
      exclusiveTmId: 'tm_56',
      team: [
        GymPokemonSpec(speciesId: 197, level: 91, moveIds: ['dark_pulse', 'moonlight', 'toxic', 'confuse_ray'], heldItemId: 'leftovers'), // Umbreon
        GymPokemonSpec(speciesId: 198, level: 92, moveIds: ['night_slash', 'brave_bird', 'sucker_punch', 'steel_wing'], heldItemId: 'sharp_beak'), // Murkrow
        GymPokemonSpec(speciesId: 45, level: 93, moveIds: ['petal_dance', 'sludge_bomb', 'moonblast', 'sleep_powder'], heldItemId: 'sitrus_berry'), // Vileplume
        GymPokemonSpec(speciesId: 94, level: 93, moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'destiny_bond'], heldItemId: 'spell_tag'), // Gengar
        GymPokemonSpec(speciesId: 248, level: 94, moveIds: ['stone_edge', 'crunch', 'earthquake', 'dragon_dance'], heldItemId: 'lum_berry'), // Tyranitar
        GymPokemonSpec(speciesId: 229, level: 95, moveIds: ['flamethrower', 'dark_pulse', 'sludge_bomb', 'nasty_plot'], heldItemId: 'black_glasses'), // Houndoom
      ],
    ),
    LeagueBossTrainer(
      id: 'champion_johto_lance',
      spriteId: 'e4_lance',
      name: 'Champion Lance',
      title: 'Johto League Champion',
      roleLabel: 'CHAMPIONSHIP BATTLE',
      chamberName: "Champion's Throne Room",
      backgroundAsset: 'assets/images/battle_bg_champion_hall.png',
      accentColor: Color(0xFFFFB300),
      bgmCategory: BattleBgmCategory.special,
      prizeMoney: 30000,
      introDialogue:
          "I've been waiting for you! From the Lake of Rage to Indigo Plateau, I knew you with your courage would reach me as Johto's Challenger. Let our battle begin!",
      defeatDialogue:
          "It's over! But it's an odd feeling—I'm not angry that I lost. You are the new Johto Pokémon League Champion!",
      exclusiveHeldItemId: 'life_orb',
      exclusiveTmId: 'tm_55',
      team: [
        GymPokemonSpec(speciesId: 130, level: 94, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'), // Gyarados
        GymPokemonSpec(speciesId: 142, level: 95, moveIds: ['stone_edge', 'sky_attack', 'earthquake', 'crunch'], heldItemId: 'hard_stone'), // Aerodactyl
        GymPokemonSpec(speciesId: 230, level: 95, moveIds: ['hydro_pump', 'dragon_pulse', 'ice_beam', 'rain_dance'], heldItemId: 'sitrus_berry'), // Kingdra
        GymPokemonSpec(speciesId: 248, level: 96, moveIds: ['stone_edge', 'crunch', 'earthquake', 'fire_punch'], heldItemId: 'lum_berry'), // Tyranitar
        GymPokemonSpec(speciesId: 6, level: 96, moveIds: ['flare_blitz', 'air_slash', 'dragon_claw', 'roost'], heldItemId: 'charcoal'), // Charizard
        GymPokemonSpec(speciesId: 149, level: 98, moveIds: ['outrage', 'dragon_claw', 'earthquake', 'extreme_speed'], heldItemId: 'life_orb'), // Dragonite
      ],
    ),
  ];
}

List<LeagueBossTrainer> buildJohtoRematchLeagueBossPool(Trainer trainer) {
  return const [
    LeagueBossTrainer(
      id: 'rematch_johto_will',
      spriteId: 'e4_will',
      name: 'Will',
      title: 'Final Four • Master Rematch',
      roleLabel: 'MASTER FINAL BOSS',
      chamberName: 'Astral Psychic Sanctum',
      backgroundAsset: 'assets/images/battle_bg_gym_psychic.png',
      accentColor: Color(0xFFAB47BC),
      bgmCategory: BattleBgmCategory.gym,
      prizeMoney: 16000,
      introDialogue:
          "Champion! My psychic perception grew sharper since our last bout—witness my Lv. 99 mind!",
      defeatDialogue:
          "Incredible clarity! My foresight could not fathom your victory!",
      exclusiveHeldItemId: 'twisted_spoon',
      exclusiveTmId: 'tm_52',
      team: [
        GymPokemonSpec(speciesId: 203, level: 99, moveIds: ['psychic', 'crunch', 'thunderbolt', 'nasty_plot'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 199, level: 99, moveIds: ['surf', 'psychic', 'ice_beam', 'calm_mind'], heldItemId: 'leftovers'),
        GymPokemonSpec(speciesId: 124, level: 99, moveIds: ['blizzard', 'psychic', 'lovely_kiss', 'shadow_ball'], heldItemId: 'lum_berry'),
        GymPokemonSpec(speciesId: 103, level: 99, moveIds: ['leaf_storm', 'psychic', 'sludge_bomb', 'sleep_powder'], heldItemId: 'miracle_seed'),
        GymPokemonSpec(speciesId: 196, level: 99, moveIds: ['psychic', 'shadow_ball', 'morning_sun', 'calm_mind'], heldItemId: 'twisted_spoon'),
        GymPokemonSpec(speciesId: 178, level: 99, moveIds: ['psychic', 'air_slash', 'heat_wave', 'future_sight'], heldItemId: 'twisted_spoon'),
      ],
    ),
    LeagueBossTrainer(
      id: 'rematch_johto_koga',
      spriteId: 'leader_koga',
      name: 'Koga',
      title: 'Final Four • Master Rematch',
      roleLabel: 'MASTER FINAL BOSS',
      chamberName: 'Shadow Venom Dojo',
      backgroundAsset: 'assets/images/battle_bg_gym_poison.png',
      accentColor: Color(0xFF8E24AA),
      bgmCategory: BattleBgmCategory.gym,
      prizeMoney: 16500,
      introDialogue:
          "Fwahahaha! My Lv. 99 shadow arts and toxic traps await the Johto Champion!",
      defeatDialogue:
          "Splendid! You see right through every illusion and venom cloud!",
      exclusiveHeldItemId: 'poison_barb',
      exclusiveTmId: 'tm_54',
      team: [
        GymPokemonSpec(speciesId: 168, level: 99, moveIds: ['poison_jab', 'x_scissor', 'sucker_punch', 'spider_web'], heldItemId: 'silver_powder'),
        GymPokemonSpec(speciesId: 205, level: 99, moveIds: ['gyro_ball', 'earthquake', 'explosion', 'toxic_spikes'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 49, level: 99, moveIds: ['bug_buzz', 'sludge_bomb', 'psychic', 'quiver_dance'], heldItemId: 'lum_berry'),
        GymPokemonSpec(speciesId: 89, level: 99, moveIds: ['gunk_shot', 'shadow_punch', 'ice_punch', 'fire_punch'], heldItemId: 'leftovers'),
        GymPokemonSpec(speciesId: 110, level: 99, moveIds: ['sludge_bomb', 'fire_blast', 'thunderbolt', 'explosion'], heldItemId: 'poison_barb'),
        GymPokemonSpec(speciesId: 169, level: 99, moveIds: ['brave_bird', 'cross_poison', 'crunch', 'roost'], heldItemId: 'poison_barb'),
      ],
    ),
    LeagueBossTrainer(
      id: 'rematch_johto_bruno',
      spriteId: 'e4_bruno',
      name: 'Bruno',
      title: 'Final Four • Master Rematch',
      roleLabel: 'MASTER FINAL BOSS',
      chamberName: 'Fighting Cavern',
      backgroundAsset: 'assets/images/battle_bg_e4_fighting.png',
      accentColor: Color(0xFFFF7043),
      bgmCategory: BattleBgmCategory.gym,
      prizeMoney: 17000,
      introDialogue:
          "Champion! Feel the earth-shaking impact of my Lv. 99 Johto martial squad! Hoo hah!",
      defeatDialogue:
          "Gah! Even Steelix and Heracross couldn't break through! True mastery!",
      exclusiveHeldItemId: 'black_belt',
      exclusiveTmId: 'tm_53',
      team: [
        GymPokemonSpec(speciesId: 237, level: 99, moveIds: ['triple_kick', 'close_combat', 'sucker_punch', 'stone_edge'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 106, level: 99, moveIds: ['close_combat', 'blaze_kick', 'stone_edge', 'mach_punch'], heldItemId: 'lum_berry'),
        GymPokemonSpec(speciesId: 107, level: 99, moveIds: ['close_combat', 'ice_punch', 'thunder_punch', 'bullet_punch'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 208, level: 99, moveIds: ['iron_tail', 'earthquake', 'stone_edge', 'crunch'], heldItemId: 'metal_coat'),
        GymPokemonSpec(speciesId: 214, level: 99, moveIds: ['megahorn', 'close_combat', 'stone_edge', 'night_slash'], heldItemId: 'leftovers'),
        GymPokemonSpec(speciesId: 68, level: 99, moveIds: ['dynamic_punch', 'close_combat', 'stone_edge', 'bullet_punch'], heldItemId: 'black_belt'),
      ],
    ),
    LeagueBossTrainer(
      id: 'rematch_johto_karen',
      spriteId: 'e4_karen',
      name: 'Karen',
      title: 'Final Four • Master Rematch',
      roleLabel: 'MASTER FINAL BOSS',
      chamberName: 'Moonlit Shadow Chamber',
      backgroundAsset: 'assets/images/battle_bg_e4_dark.png',
      accentColor: Color(0xFF546E7A),
      bgmCategory: BattleBgmCategory.gym,
      prizeMoney: 18500,
      introDialogue:
          "Back for another moonlit dance, Champion? Show me how deeply you trust your favorites at Lv. 99!",
      defeatDialogue:
          "Just as I knew—victory belongs to those who believe in their partners.",
      exclusiveHeldItemId: 'black_glasses',
      exclusiveTmId: 'tm_56',
      team: [
        GymPokemonSpec(speciesId: 197, level: 99, moveIds: ['dark_pulse', 'moonlight', 'toxic', 'confuse_ray'], heldItemId: 'leftovers'),
        GymPokemonSpec(speciesId: 198, level: 99, moveIds: ['night_slash', 'brave_bird', 'sucker_punch', 'heat_wave'], heldItemId: 'sharp_beak'),
        GymPokemonSpec(speciesId: 45, level: 99, moveIds: ['petal_blizzard', 'sludge_bomb', 'moonblast', 'sleep_powder'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 94, level: 99, moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'destiny_bond'], heldItemId: 'spell_tag'),
        GymPokemonSpec(speciesId: 248, level: 99, moveIds: ['stone_edge', 'crunch', 'earthquake', 'dragon_dance'], heldItemId: 'lum_berry'),
        GymPokemonSpec(speciesId: 229, level: 99, moveIds: ['fire_blast', 'dark_pulse', 'sludge_bomb', 'nasty_plot'], heldItemId: 'black_glasses'),
      ],
    ),
    LeagueBossTrainer(
      id: 'rematch_johto_lance',
      spriteId: 'e4_lance',
      name: 'Champion Lance',
      title: 'Dragon Grandmaster • Lv.99 Rematch',
      roleLabel: 'MASTER FINAL BOSS',
      chamberName: "Champion's Throne Room",
      backgroundAsset: 'assets/images/battle_bg_champion_hall.png',
      accentColor: Color(0xFFFFB300),
      bgmCategory: BattleBgmCategory.special,
      prizeMoney: 25000,
      introDialogue:
          "So Johto's Champion returns to the Throne Room! Witness the full Lv. 99 majesty of Johto's mightiest Dragons!",
      defeatDialogue:
          "Magnificent! Truly, no trainer in Johto shines brighter than you!",
      exclusiveHeldItemId: 'life_orb',
      exclusiveTmId: 'tm_55',
      team: [
        GymPokemonSpec(speciesId: 130, level: 99, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'),
        GymPokemonSpec(speciesId: 142, level: 99, moveIds: ['stone_edge', 'brave_bird', 'earthquake', 'crunch'], heldItemId: 'hard_stone'),
        GymPokemonSpec(speciesId: 230, level: 99, moveIds: ['hydro_pump', 'dragon_pulse', 'ice_beam', 'rain_dance'], heldItemId: 'sitrus_berry'),
        GymPokemonSpec(speciesId: 248, level: 99, moveIds: ['stone_edge', 'crunch', 'earthquake', 'fire_punch'], heldItemId: 'lum_berry'),
        GymPokemonSpec(speciesId: 6, level: 99, moveIds: ['flare_blitz', 'air_slash', 'dragon_claw', 'roost'], heldItemId: 'charcoal'),
        GymPokemonSpec(speciesId: 149, level: 99, moveIds: ['outrage', 'dragon_claw', 'earthquake', 'extreme_speed'], heldItemId: 'life_orb'),
      ],
    ),
  ];
}

List<VictoryRoadStage> buildJohtoMasterRematchStages(
  Trainer trainer, {
  required Random random,
}) {
  final bossPool = buildJohtoRematchLeagueBossPool(trainer);
  final LeagueBossTrainer finalBoss = bossPool[random.nextInt(bossPool.length)];

  const intermediateTrainers = [
    GymTrainer(
      id: 'johto_vr_master_t1',
      spriteId: 'npc_swimmer',
      name: 'Rain Masters Kai & Maya',
      title: 'Johto Master Duo (2v2)',
      prizeMoney: 6500,
      introDialogue:
          "Politoed summons the storm while Kingdra tears through defenses in our Lv. 99 Double Battle!",
      defeatDialogue:
          "Not even Drizzle and Swift Swim could outpace your strategy!",
      team: [
        GymPokemonSpec(
          speciesId: 186, // Politoed
          level: 99,
          heldItemId: 'mystic_water',
          moveIds: ['muddy_water', 'ice_beam', 'helping_hand', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 230, // Kingdra
          level: 99,
          heldItemId: 'dragon_fang',
          moveIds: ['muddy_water', 'dragon_pulse', 'ice_beam', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 171, // Lanturn
          level: 99,
          heldItemId: 'magnet',
          moveIds: ['discharge', 'surf', 'ice_beam', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 184, // Azumarill
          level: 99,
          heldItemId: 'sitrus_berry',
          moveIds: ['waterfall', 'aqua_jet', 'superpower', 'protect'],
        ),
      ],
    ),
    GymTrainer(
      id: 'johto_vr_master_t2',
      spriteId: 'npc_hiker',
      name: 'Sandstorm Baron Gideon',
      title: 'Johto Master Tactician (2v2)',
      prizeMoney: 6800,
      introDialogue:
          "Feel the crushing Lv. 99 Sandstorm synergy of Tyranitar and Steelix!",
      defeatDialogue:
          "Even unyielding iron and stone fell before your bond!",
      team: [
        GymPokemonSpec(
          speciesId: 248, // Tyranitar
          level: 99,
          heldItemId: 'hard_stone',
          moveIds: ['rock_slide', 'crunch', 'earthquake', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 208, // Steelix
          level: 99,
          heldItemId: 'metal_coat',
          moveIds: ['iron_head', 'earthquake', 'rock_slide', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 227, // Skarmory
          level: 99,
          heldItemId: 'leftovers',
          moveIds: ['brave_bird', 'steel_wing', 'tailwind', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 232, // Donphan
          level: 99,
          heldItemId: 'soft_sand',
          moveIds: ['earthquake', 'rock_slide', 'ice_shard', 'protect'],
        ),
      ],
    ),
    GymTrainer(
      id: 'johto_vr_master_t3',
      spriteId: 'npc_psychic',
      name: 'Twin Seers Sol & Luna',
      title: 'Ecruteak Masters (2v2)',
      prizeMoney: 7000,
      introDialogue:
          "Day and night move as one! Face our Lv. 99 Espeon and Umbreon tag-team!",
      defeatDialogue:
          "Both sun and shadow bowed to your brilliance!",
      team: [
        GymPokemonSpec(
          speciesId: 196, // Espeon
          level: 99,
          heldItemId: 'twisted_spoon',
          moveIds: ['psychic', 'shadow_ball', 'helping_hand', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 197, // Umbreon
          level: 99,
          heldItemId: 'leftovers',
          moveIds: ['dark_pulse', 'moonlight', 'toxic', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 199, // Slowking
          level: 99,
          heldItemId: 'mystic_water',
          moveIds: ['surf', 'psychic', 'icy_wind', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 229, // Houndoom
          level: 99,
          heldItemId: 'charcoal',
          moveIds: ['heat_wave', 'dark_pulse', 'sludge_bomb', 'protect'],
        ),
      ],
    ),
    GymTrainer(
      id: 'johto_vr_master_t4',
      spriteId: 'npc_beauty',
      name: 'Ace Duelist Lyra',
      title: 'Johto Master Challenger (2v2)',
      prizeMoney: 7200,
      introDialogue:
          "My Johto champions know how to fight shoulder-to-shoulder at Lv. 99—ready when you are!",
      defeatDialogue:
          "Whoa! Your Pokémon move in total harmony—go claim the final challenge!",
      team: [
        GymPokemonSpec(
          speciesId: 242, // Blissey
          level: 99,
          heldItemId: 'leftovers',
          moveIds: ['soft_boiled', 'heal_pulse', 'helping_hand', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 212, // Scizor
          level: 99,
          heldItemId: 'metal_coat',
          moveIds: ['bullet_punch', 'x_scissor', 'aerial_ace', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 181, // Ampharos
          level: 99,
          heldItemId: 'magnet',
          moveIds: ['discharge', 'power_gem', 'light_screen', 'protect'],
        ),
        GymPokemonSpec(
          speciesId: 214, // Heracross
          level: 99,
          heldItemId: 'lum_berry',
          moveIds: ['megahorn', 'close_combat', 'rock_slide', 'protect'],
        ),
      ],
    ),
  ];

  final shuffled = List<GymTrainer>.from(intermediateTrainers)..shuffle(random);

  return [
    const VictoryRoadStage.wild(
      stageNumber: 1,
      level: 99,
      label: 'Tohjo Summit I (Wild Lv.99)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 2,
      trainer: shuffled[0],
      isDoubleBattle: true,
      customLabel: '${shuffled[0].name} (2v2 Doubles)',
    ),
    const VictoryRoadStage.wild(
      stageNumber: 3,
      level: 99,
      label: 'Tohjo Summit II (Wild Lv.99)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 4,
      trainer: shuffled[1],
      isDoubleBattle: true,
      customLabel: '${shuffled[1].name} (2v2 Doubles)',
    ),
    const VictoryRoadStage.wild(
      stageNumber: 5,
      level: 99,
      label: 'Tohjo Summit III (Wild Lv.99)',
    ),
    VictoryRoadStage.trainer(
      stageNumber: 6,
      trainer: finalBoss,
      isDoubleBattle: false,
      backgroundAsset: finalBoss.backgroundAsset,
      bgmCategory: finalBoss.bgmCategory,
      customLabel: '${finalBoss.name} (Master Boss)',
    ),
  ];
}
