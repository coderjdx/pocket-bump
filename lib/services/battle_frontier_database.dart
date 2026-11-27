import 'dart:math';
import '../models/game_region.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_nature.dart';
import 'pokedex_database.dart';

class FrontierRentalTemplate {
  final int speciesId;
  final PokemonNature nature;
  final List<String> moveIds;
  final String heldItemId;
  final bool preferHiddenAbility;

  const FrontierRentalTemplate({
    required this.speciesId,
    required this.nature,
    required this.moveIds,
    required this.heldItemId,
    this.preferHiddenAbility = false,
  });

  PokemonInstance createInstance({
    required int level,
    Random? rng,
  }) {
    final spec = PokedexDatabase.species[speciesId] ?? PokedexDatabase.species[1]!;
    final String chosenAbility;
    final int abilitySlot;
    if (preferHiddenAbility && spec.hiddenAbilityId != null) {
      chosenAbility = spec.hiddenAbilityId!;
      abilitySlot = 3;
    } else {
      final rolled = PokedexDatabase.rollAbility(
        spec,
        hiddenAbilityChance: 0.12,
        rng: rng,
      );
      chosenAbility = rolled.id;
      abilitySlot = rolled.slot;
    }

    return PokedexDatabase.createPokemon(
      speciesId,
      level: level,
      explicitMoveIds: moveIds,
      heldItemId: heldItemId,
      nature: nature,
      hpIv: 31,
      atkIv: 31,
      defIv: 31,
      spaIv: 31,
      spdIv: 31,
      speIv: 31,
      abilityId: chosenAbility,
      abilitySlot: abilitySlot,
      respectMinEncounterLevel: false,
      originRegion:
          speciesId <= 151 ? GameRegion.kanto.storageKey : GameRegion.johto.storageKey,
      rng: rng,
    );
  }
}

class FrontierOpponent {
  final String name;
  final String title;
  final String spriteId;
  final String introDialogue;
  final String defeatDialogue;
  final bool isBoss;
  final List<PokemonInstance> team;

  const FrontierOpponent({
    required this.name,
    required this.title,
    required this.spriteId,
    required this.introDialogue,
    required this.defeatDialogue,
    this.isBoss = false,
    required this.team,
  });
}

class FrontierShopEntry {
  final String itemId;
  final int bpCost;
  final String categoryLabel;

  const FrontierShopEntry({
    required this.itemId,
    required this.bpCost,
    required this.categoryLabel,
  });
}

class BattleFrontierDatabase {
  static final Random _rng = Random();

  static const String frontierBgAsset = 'assets/images/battle_bg_frontier.png';

  static const int natureMintCostBp = 25;
  static const int bottleCapCostBp = 20;
  static const int goldBottleCapCostBp = 50;
  static const int abilityPatchCostBp = 40;

  static const List<FrontierShopEntry> shopItems = [
    FrontierShopEntry(itemId: 'focus_sash', bpCost: 24, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'expert_belt', bpCost: 24, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'muscle_band', bpCost: 20, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'wise_glasses', bpCost: 20, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'scope_lens', bpCost: 20, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'life_orb', bpCost: 32, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'leftovers', bpCost: 32, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'sitrus_berry', bpCost: 10, categoryLabel: 'Berry'),
    FrontierShopEntry(itemId: 'lum_berry', bpCost: 12, categoryLabel: 'Berry'),
    FrontierShopEntry(itemId: 'kings_rock', bpCost: 18, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'metal_coat', bpCost: 16, categoryLabel: 'Held Item'),
    FrontierShopEntry(itemId: 'charcoal', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'mystic_water', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'magnet', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'miracle_seed', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'twisted_spoon', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'black_belt', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'dragon_fang', bpCost: 16, categoryLabel: 'Type Boost'),
    FrontierShopEntry(itemId: 'black_glasses', bpCost: 16, categoryLabel: 'Type Boost'),
  ];

  /// Competitive Gen 1–2 Battle Frontier roster (strictly species #1..#251).
  static const List<FrontierRentalTemplate> competitiveRoster = [
    FrontierRentalTemplate(
      speciesId: 3, // Venusaur
      nature: PokemonNature.modest,
      moveIds: ['giga_drain', 'sludge_bomb', 'sleep_powder', 'synthesis'],
      heldItemId: 'leftovers',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 6, // Charizard
      nature: PokemonNature.timid,
      moveIds: ['flamethrower', 'air_slash', 'dragon_pulse', 'roost'],
      heldItemId: 'expert_belt',
    ),
    FrontierRentalTemplate(
      speciesId: 9, // Blastoise
      nature: PokemonNature.modest,
      moveIds: ['hydro_pump', 'ice_beam', 'aura_sphere', 'dark_pulse'],
      heldItemId: 'wise_glasses',
    ),
    FrontierRentalTemplate(
      speciesId: 34, // Nidoking
      nature: PokemonNature.timid,
      moveIds: ['earth_power', 'sludge_bomb', 'ice_beam', 'flamethrower'],
      heldItemId: 'life_orb',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 36, // Clefable
      nature: PokemonNature.calm,
      moveIds: ['moonblast', 'flamethrower', 'soft_boiled', 'thunder_wave'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 38, // Ninetales
      nature: PokemonNature.timid,
      moveIds: ['flamethrower', 'energy_ball', 'nasty_plot', 'will_o_wisp'],
      heldItemId: 'focus_sash',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 59, // Arcanine
      nature: PokemonNature.adamant,
      moveIds: ['flare_blitz', 'extreme_speed', 'crunch', 'close_combat'],
      heldItemId: 'muscle_band',
    ),
    FrontierRentalTemplate(
      speciesId: 62, // Poliwrath
      nature: PokemonNature.adamant,
      moveIds: ['waterfall', 'close_combat', 'ice_punch', 'belly_drum'],
      heldItemId: 'sitrus_berry',
    ),
    FrontierRentalTemplate(
      speciesId: 65, // Alakazam
      nature: PokemonNature.timid,
      moveIds: ['psychic', 'shadow_ball', 'aura_sphere', 'recover'],
      heldItemId: 'focus_sash',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 68, // Machamp
      nature: PokemonNature.adamant,
      moveIds: ['dynamic_punch', 'stone_edge', 'bullet_punch', 'ice_punch'],
      heldItemId: 'expert_belt',
    ),
    FrontierRentalTemplate(
      speciesId: 80, // Slowbro
      nature: PokemonNature.bold,
      moveIds: ['surf', 'psychic', 'ice_beam', 'slack_off'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 94, // Gengar
      nature: PokemonNature.timid,
      moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'destiny_bond'],
      heldItemId: 'focus_sash',
    ),
    FrontierRentalTemplate(
      speciesId: 103, // Exeggutor
      nature: PokemonNature.modest,
      moveIds: ['leaf_storm', 'psychic', 'sleep_powder', 'synthesis'],
      heldItemId: 'wise_glasses',
    ),
    FrontierRentalTemplate(
      speciesId: 121, // Starmie
      nature: PokemonNature.timid,
      moveIds: ['surf', 'psychic', 'ice_beam', 'thunderbolt'],
      heldItemId: 'expert_belt',
    ),
    FrontierRentalTemplate(
      speciesId: 130, // Gyarados
      nature: PokemonNature.jolly,
      moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'],
      heldItemId: 'lum_berry',
    ),
    FrontierRentalTemplate(
      speciesId: 131, // Lapras
      nature: PokemonNature.modest,
      moveIds: ['surf', 'ice_beam', 'thunderbolt', 'psychic'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 134, // Vaporeon
      nature: PokemonNature.bold,
      moveIds: ['surf', 'ice_beam', 'shadow_ball', 'protect'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 135, // Jolteon
      nature: PokemonNature.timid,
      moveIds: ['thunderbolt', 'shadow_ball', 'hidden_power', 'quick_attack'],
      heldItemId: 'wise_glasses',
    ),
    FrontierRentalTemplate(
      speciesId: 142, // Aerodactyl
      nature: PokemonNature.jolly,
      moveIds: ['stone_edge', 'brave_bird', 'earthquake', 'crunch'],
      heldItemId: 'focus_sash',
    ),
    FrontierRentalTemplate(
      speciesId: 143, // Snorlax
      nature: PokemonNature.careful,
      moveIds: ['body_slam', 'earthquake', 'crunch', 'rest'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 149, // Dragonite
      nature: PokemonNature.adamant,
      moveIds: ['dragon_claw', 'extreme_speed', 'earthquake', 'dragon_dance'],
      heldItemId: 'lum_berry',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 154, // Meganium
      nature: PokemonNature.calm,
      moveIds: ['giga_drain', 'moonblast', 'synthesis', 'leech_seed'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 157, // Typhlosion
      nature: PokemonNature.timid,
      moveIds: ['eruption', 'flamethrower', 'extrasensory', 'focus_punch'],
      heldItemId: 'expert_belt',
    ),
    FrontierRentalTemplate(
      speciesId: 160, // Feraligatr
      nature: PokemonNature.jolly,
      moveIds: ['waterfall', 'ice_fang', 'crunch', 'dragon_dance'],
      heldItemId: 'life_orb',
    ),
    FrontierRentalTemplate(
      speciesId: 169, // Crobat
      nature: PokemonNature.jolly,
      moveIds: ['brave_bird', 'cross_poison', 'crunch', 'roost'],
      heldItemId: 'sharp_beak',
    ),
    FrontierRentalTemplate(
      speciesId: 171, // Lanturn
      nature: PokemonNature.calm,
      moveIds: ['thunderbolt', 'surf', 'ice_beam', 'thunder_wave'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 181, // Ampharos
      nature: PokemonNature.modest,
      moveIds: ['thunderbolt', 'power_gem', 'signal_beam', 'thunder_wave'],
      heldItemId: 'wise_glasses',
    ),
    FrontierRentalTemplate(
      speciesId: 184, // Azumarill
      nature: PokemonNature.adamant,
      moveIds: ['waterfall', 'aqua_jet', 'superpower', 'ice_punch'],
      heldItemId: 'muscle_band',
    ),
    FrontierRentalTemplate(
      speciesId: 186, // Politoed
      nature: PokemonNature.modest,
      moveIds: ['hydro_pump', 'ice_beam', 'psychic', 'perish_song'],
      heldItemId: 'sitrus_berry',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 196, // Espeon
      nature: PokemonNature.timid,
      moveIds: ['psychic', 'shadow_ball', 'morning_sun', 'calm_mind'],
      heldItemId: 'wise_glasses',
      preferHiddenAbility: true,
    ),
    FrontierRentalTemplate(
      speciesId: 197, // Umbreon
      nature: PokemonNature.careful,
      moveIds: ['dark_pulse', 'moonlight', 'toxic', 'confuse_ray'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 199, // Slowking
      nature: PokemonNature.calm,
      moveIds: ['surf', 'psychic', 'flamethrower', 'slack_off'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 205, // Forretress
      nature: PokemonNature.relaxed,
      moveIds: ['gyro_ball', 'bug_bite', 'earthquake', 'explosion'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 208, // Steelix
      nature: PokemonNature.impish,
      moveIds: ['iron_head', 'earthquake', 'stone_edge', 'crunch'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 212, // Scizor
      nature: PokemonNature.adamant,
      moveIds: ['bullet_punch', 'x_scissor', 'superpower', 'swords_dance'],
      heldItemId: 'life_orb',
    ),
    FrontierRentalTemplate(
      speciesId: 214, // Heracross
      nature: PokemonNature.jolly,
      moveIds: ['megahorn', 'close_combat', 'stone_edge', 'night_slash'],
      heldItemId: 'scope_lens',
    ),
    FrontierRentalTemplate(
      speciesId: 217, // Ursaring
      nature: PokemonNature.adamant,
      moveIds: ['facade', 'close_combat', 'crunch', 'earthquake'],
      heldItemId: 'muscle_band',
    ),
    FrontierRentalTemplate(
      speciesId: 221, // Piloswine
      nature: PokemonNature.adamant,
      moveIds: ['earthquake', 'avalanche', 'ice_shard', 'stone_edge'],
      heldItemId: 'never_melt_ice',
    ),
    FrontierRentalTemplate(
      speciesId: 227, // Skarmory
      nature: PokemonNature.impish,
      moveIds: ['brave_bird', 'steel_wing', 'roost', 'stealth_rock'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 229, // Houndoom
      nature: PokemonNature.timid,
      moveIds: ['flamethrower', 'dark_pulse', 'sludge_bomb', 'nasty_plot'],
      heldItemId: 'focus_sash',
    ),
    FrontierRentalTemplate(
      speciesId: 230, // Kingdra
      nature: PokemonNature.modest,
      moveIds: ['hydro_pump', 'dragon_pulse', 'ice_beam', 'signal_beam'],
      heldItemId: 'scope_lens',
    ),
    FrontierRentalTemplate(
      speciesId: 232, // Donphan
      nature: PokemonNature.adamant,
      moveIds: ['earthquake', 'stone_edge', 'ice_shard', 'rapid_spin'],
      heldItemId: 'soft_sand',
    ),
    FrontierRentalTemplate(
      speciesId: 233, // Porygon2
      nature: PokemonNature.bold,
      moveIds: ['tri_attack', 'ice_beam', 'thunderbolt', 'recover'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 242, // Blissey
      nature: PokemonNature.bold,
      moveIds: ['soft_boiled', 'seismic_toss', 'ice_beam', 'toxic'],
      heldItemId: 'leftovers',
    ),
    FrontierRentalTemplate(
      speciesId: 248, // Tyranitar
      nature: PokemonNature.adamant,
      moveIds: ['stone_edge', 'crunch', 'earthquake', 'dragon_dance'],
      heldItemId: 'expert_belt',
    ),
  ];

  // Clean fixed version: notice Lapras entry #131 should not have 'freeze' (that's a status, not a move!)
  static List<FrontierRentalTemplate> get _sanitizedRoster => [
        for (final t in competitiveRoster)
          if (t.speciesId == 131)
            const FrontierRentalTemplate(
              speciesId: 131,
              nature: PokemonNature.modest,
              moveIds: ['surf', 'ice_beam', 'thunderbolt', 'psychic'],
              heldItemId: 'leftovers',
            )
          else
            t,
      ];

  static int opponentLevelForTowerStreak(int streakNumber) {
    if (streakNumber <= 6) {
      return (50 + (streakNumber - 1) * 2).clamp(50, 60);
    }
    if (streakNumber == 7) return 65;
    if (streakNumber <= 13) {
      return (70 + (streakNumber - 8) * 2).clamp(70, 80);
    }
    if (streakNumber == 14) return 85;
    if (streakNumber <= 20) {
      return (88 + (streakNumber - 15) * 2).clamp(88, 98);
    }
    return 100;
  }

  static int bpRewardForMatch({
    required int streakNumber,
    required bool isFactory,
  }) {
    final bool isBoss = streakNumber > 0 && streakNumber % 7 == 0;
    final int base = isFactory
        ? 4 + min(6, (streakNumber - 1) ~/ 3)
        : 3 + min(7, (streakNumber - 1) ~/ 3);
    return isBoss ? base + 15 : base;
  }

  static FrontierOpponent buildTowerOpponent({
    required int streakNumber,
    required bool isDoubles,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final int level = opponentLevelForTowerStreak(streakNumber);
    final int teamSize = isDoubles ? 4 : 3;
    final bool isBoss = streakNumber > 0 && streakNumber % 7 == 0;

    if (isBoss) {
      const bosses = [
        (
          name: 'Frontier Ace Blue',
          title: 'Tower Brain • Match #7 Boss',
          spriteId: 'champion_blue',
          intro: "Yo! Ready to test whether your Frontier squad can handle real championship pressure?!",
          defeat: "Hah! Even at the Battle Tower, you never disappoint!",
          species: [65, 130, 143, 6],
        ),
        (
          name: 'Sovereign Lance',
          title: 'Dragon Frontier Brain',
          spriteId: 'e4_lance',
          intro: "Only trainers who forge true harmony conquer the Frontier's pinnacle!",
          defeat: "Remarkable battle spirit! You conquered this milestone cleanly!",
          species: [130, 230, 248, 149],
        ),
        (
          name: 'Shadow Maven Karen',
          title: 'Night Frontier Brain',
          spriteId: 'e4_karen',
          intro: "Strong species mean nothing without conviction—show me what your team fights for!",
          defeat: "Well played! Even the shadows yield to your resolve!",
          species: [197, 94, 248, 229],
        ),
        (
          name: 'Steel Strategist Jasmine',
          title: 'Iron Frontier Brain',
          spriteId: 'leader_jasmine',
          intro: "Allow me to show you how unyielding Johto & Kanto steel stands in the Tower!",
          defeat: "...Wonderful battle! Your tactics gleam brighter than polished steel!",
          species: [227, 212, 233, 208],
        ),
      ];
      final pickedBoss = bosses[((streakNumber ~/ 7) - 1) % bosses.length];
      final rosterMap = {for (final r in _sanitizedRoster) r.speciesId: r};
      final team = <PokemonInstance>[
        for (final sid in pickedBoss.species.take(teamSize))
          rosterMap[sid]!.createInstance(level: level, rng: random),
      ];
      return FrontierOpponent(
        name: pickedBoss.name,
        title: '${pickedBoss.title} (${isDoubles ? '4v4 Doubles' : '3v3 Singles'})',
        spriteId: pickedBoss.spriteId,
        introDialogue: pickedBoss.intro,
        defeatDialogue: pickedBoss.defeat,
        isBoss: true,
        team: team,
      );
    }

    const regularChallengers = [
      (name: 'Ace Trainer Serena', title: 'Tower Challenger', spriteId: 'npc_beauty'),
      (name: 'Veteran Damian', title: 'Frontier Tactician', spriteId: 'npc_engineer'),
      (name: 'Psychic Orion', title: 'Mind Duelist', spriteId: 'npc_psychic'),
      (name: 'Black Belt Katsu', title: 'Tower Striker', spriteId: 'npc_ninja'),
      (name: 'Cooltrainer Mira', title: 'Frontier Ace', spriteId: 'npc_lass'),
      (name: 'Mountaineer Brockton', title: 'Tower Guardian', spriteId: 'npc_hiker'),
    ];
    final trainerMeta = regularChallengers[random.nextInt(regularChallengers.length)];
    final pool = List<FrontierRentalTemplate>.from(_sanitizedRoster)..shuffle(random);
    final team = [
      for (int i = 0; i < teamSize; i++)
        pool[i % pool.length].createInstance(level: level, rng: random),
    ];

    return FrontierOpponent(
      name: trainerMeta.name,
      title: 'Battle Tower #$streakNumber • ${isDoubles ? '4v4 Doubles' : '3v3 Singles'}',
      spriteId: trainerMeta.spriteId,
      introDialogue: "Battle Tower Match #$streakNumber! Let's see how far your streak can climb!",
      defeatDialogue: "What a battle! Keep climbing the Battle Tower!",
      isBoss: false,
      team: team,
    );
  }

  static List<PokemonInstance> rollFactoryDraftPool({
    int count = 6,
    int level = 70,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final pool = List<FrontierRentalTemplate>.from(_sanitizedRoster)..shuffle(random);
    return [
      for (int i = 0; i < min(count, pool.length); i++)
        pool[i].createInstance(level: level, rng: random),
    ];
  }

  static FrontierOpponent buildFactoryOpponent({
    required int streakNumber,
    required bool isDoubles,
    int level = 70,
    Set<int> excludeSpeciesIds = const {},
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final int teamSize = isDoubles ? 4 : 3;
    final bool isBoss = streakNumber > 0 && streakNumber % 7 == 0;

    final eligible = _sanitizedRoster
        .where((t) => !excludeSpeciesIds.contains(t.speciesId))
        .toList()
      ..shuffle(random);
    final pool = eligible.length >= teamSize
        ? eligible
        : (List<FrontierRentalTemplate>.from(_sanitizedRoster)..shuffle(random));

    final team = [
      for (int i = 0; i < teamSize; i++)
        pool[i % pool.length].createInstance(level: level, rng: random),
    ];

    if (isBoss) {
      return FrontierOpponent(
        name: 'Factory Head Noland',
        title: 'Battle Factory Boss • Match #$streakNumber',
        spriteId: 'e4_will',
        introDialogue:
            "Every trainer starts equal in the Battle Factory—victory comes from drafting and adapting on the fly!",
        defeatDialogue:
            "Genius drafting! You read my rental combinations like an open book!",
        isBoss: true,
        team: team,
      );
    }

    const scientists = [
      (name: 'Analyst Evelyn', spriteId: 'npc_beauty'),
      (name: 'Researcher Galen', spriteId: 'npc_engineer'),
      (name: 'Rental Ace Theo', spriteId: 'npc_psychic'),
      (name: 'Tactician Naomi', spriteId: 'npc_lass'),
    ];
    final picked = scientists[random.nextInt(scientists.length)];
    return FrontierOpponent(
      name: picked.name,
      title: 'Battle Factory #$streakNumber • ${isDoubles ? '4v4 Doubles' : '3v3 Singles'}',
      spriteId: picked.spriteId,
      introDialogue: "Factory Match #$streakNumber! Let's pit our drafted rentals head-to-head!",
      defeatDialogue: "Impressive adaptation! Feel free to trade for one of my rentals!",
      isBoss: false,
      team: team,
    );
  }
}
