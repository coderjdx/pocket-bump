import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_region.dart';
import '../models/game_version.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/trainer.dart';
import 'gym_database.dart';
import 'item_drop_service.dart';
import 'johto_elite_four_data.dart';
import 'pokedex_database.dart';
import 'sound_service.dart';

class LeagueBossTrainer extends GymTrainer {
  final String roleLabel;
  final String chamberName;
  final String backgroundAsset;
  final Color accentColor;
  final BattleBgmCategory bgmCategory;
  final String exclusiveHeldItemId;
  final String exclusiveTmId;

  const LeagueBossTrainer({
    required super.id,
    required super.name,
    required super.title,
    required super.spriteId,
    required super.prizeMoney,
    required super.introDialogue,
    required super.defeatDialogue,
    required super.team,
    required this.roleLabel,
    required this.chamberName,
    required this.backgroundAsset,
    required this.accentColor,
    this.bgmCategory = BattleBgmCategory.gym,
    this.exclusiveHeldItemId = '',
    this.exclusiveTmId = '',
  });
}

class VictoryRoadStage {
  final int stageNumber;
  final bool isWild;
  final int? wildLevel;
  final GymTrainer? trainer;
  final String backgroundAsset;
  final BattleBgmCategory bgmCategory;
  final bool isDoubleBattle;
  final String? partnerSpriteId;
  final String? _customLabel;

  String get label => _customLabel ?? trainer?.name ?? 'Wild Ambush';

  const VictoryRoadStage.wild({
    required this.stageNumber,
    required int level,
    this.backgroundAsset = 'assets/images/battle_bg_victory_road.png',
    String label = 'Wild Ambush',
  })  : isWild = true,
        wildLevel = level,
        trainer = null,
        bgmCategory = BattleBgmCategory.wild,
        isDoubleBattle = false,
        partnerSpriteId = null,
        _customLabel = label;

  const VictoryRoadStage.trainer({
    required this.stageNumber,
    required GymTrainer this.trainer,
    this.backgroundAsset = 'assets/images/battle_bg_victory_road.png',
    this.bgmCategory = BattleBgmCategory.gym,
    this.isDoubleBattle = false,
    this.partnerSpriteId,
    String? customLabel,
  })  : isWild = false,
        wildLevel = null,
        _customLabel = customLabel;
}

class EliteFourDatabase {
  static final Random _rng = Random();

  static const String victoryRoadBgAsset =
      'assets/images/battle_bg_victory_road.png';

  /// Catchable Victory Road cavern species pool (non-legendary, strong late-game Kanto lines).
  static const List<int> victoryRoadWildPool = [
    24, // Arbok
    28, // Sandslash
    34, // Nidoking
    38, // Ninetales
    42, // Golbat
    51, // Dugtrio
    57, // Primeape
    59, // Arcanine
    67, // Machoke
    68, // Machamp
    75, // Graveler
    76, // Golem
    78, // Rapidash
    82, // Magneton
    95, // Onix
    105, // Marowak
    112, // Rhydon
    126, // Magmar
  ];

  static PokemonInstance rollWildVictoryRoadPokemon({
    required int level,
    GameVersion? gameVersion,
    GameRegion region = GameRegion.kanto,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final basePool = region == GameRegion.johto
        ? johtoVictoryRoadWildSpeciesPool
        : victoryRoadWildPool;
    final filtered = basePool.where((id) {
      final spec = PokedexDatabase.species[id];
      return spec != null && spec.isAvailableInVersion(gameVersion);
    }).toList();
    final pool = filtered.isNotEmpty ? filtered : basePool;
    final chosenId = pool[random.nextInt(pool.length)];
    final spec = PokedexDatabase.species[chosenId]!;
    final bool isShiny = PokedexDatabase.rollShiny(spec);
    return PokedexDatabase.createPokemon(
      chosenId,
      level: level,
      isShiny: isShiny,
      respectMinEncounterLevel: false,
      eggMoveChance: 0.25,
      hiddenAbilityChance: 0.04,
      rng: random,
    );
  }

  /// State 1: First Ascent Victory Road (6 stages: Wild → Trainer → Wild → Trainer → Wild → Trainer, Lv. 85–90).
  static List<VictoryRoadStage> buildFirstAscentStages({
    GameRegion region = GameRegion.kanto,
  }) {
    if (region == GameRegion.johto) {
      return buildJohtoFirstAscentStages();
    }
    return const [
      VictoryRoadStage.wild(
        stageNumber: 1,
        level: 85,
        label: 'Entrance Cavern (Wild)',
      ),
      VictoryRoadStage.trainer(
        stageNumber: 2,
        customLabel: 'Ace Trainer Naomi',
        trainer: GymTrainer(
          id: 'vr_ascent_t1',
          spriteId: 'npc_beauty',
          name: 'Ace Trainer Naomi',
          title: 'Victory Road Challenger',
          prizeMoney: 4200,
          introDialogue:
              "Only trainers with all eight Kanto Badges can walk Victory Road! Show me what got you past Giovanni!",
          defeatDialogue:
              "Incredible! You really earned your way into the Indigo Plateau!",
          team: [
            GymPokemonSpec(speciesId: 36, level: 86, heldItemId: 'sitrus_berry'), // Clefable
            GymPokemonSpec(speciesId: 121, level: 87), // Starmie
            GymPokemonSpec(speciesId: 45, level: 87), // Vileplume
            GymPokemonSpec(speciesId: 38, level: 88, heldItemId: 'charcoal'), // Ninetales
          ],
        ),
      ),
      VictoryRoadStage.wild(
        stageNumber: 3,
        level: 86,
        label: 'Boulder Pass (Wild)',
      ),
      VictoryRoadStage.trainer(
        stageNumber: 4,
        customLabel: 'Black Belt Takeshi',
        trainer: GymTrainer(
          id: 'vr_ascent_t2',
          spriteId: 'npc_ninja',
          name: 'Black Belt Takeshi',
          title: 'Victory Road Guardian',
          prizeMoney: 4800,
          introDialogue:
              "Our fists shatter the boulders blocking the summit! Brace yourself!",
          defeatDialogue:
              "What overwhelming force! Go on—the summit awaits!",
          team: [
            GymPokemonSpec(speciesId: 57, level: 87), // Primeape
            GymPokemonSpec(speciesId: 106, level: 88), // Hitmonlee
            GymPokemonSpec(speciesId: 107, level: 88), // Hitmonchan
            GymPokemonSpec(speciesId: 62, level: 88, heldItemId: 'sitrus_berry'), // Poliwrath
            GymPokemonSpec(speciesId: 68, level: 89, heldItemId: 'black_belt'), // Machamp
          ],
        ),
      ),
      VictoryRoadStage.wild(
        stageNumber: 5,
        level: 88,
        label: 'Summit Ridge (Wild)',
      ),
      VictoryRoadStage.trainer(
        stageNumber: 6,
        customLabel: 'Veteran Marcus',
        trainer: GymTrainer(
          id: 'vr_ascent_t3',
          spriteId: 'npc_engineer',
          name: 'Veteran Marcus',
          title: 'League Gatekeeper',
          prizeMoney: 5600,
          introDialogue:
              "I stand watch at the final gate of Victory Road! Beat me, and the Indigo League doors open!",
          defeatDialogue:
              "Magnificent! You're ready to challenge the Final Four at Indigo Plateau!",
          team: [
            GymPokemonSpec(speciesId: 103, level: 88, heldItemId: 'miracle_seed'), // Exeggutor
            GymPokemonSpec(speciesId: 135, level: 89, heldItemId: 'magnet'), // Jolteon
            GymPokemonSpec(speciesId: 76, level: 89, heldItemId: 'hard_stone'), // Golem
            GymPokemonSpec(speciesId: 112, level: 89, heldItemId: 'soft_sand'), // Rhydon
            GymPokemonSpec(speciesId: 149, level: 90, heldItemId: 'lum_berry'), // Dragonite
          ],
        ),
      ),
    ];
  }

  /// Infers a counter-starter for Champion Blue based on the player's party/history (classic Kanto rivalry).
  static int championStarterCounterId(Trainer trainer) {
    final allSpecies = {
      ...trainer.party.map((p) => p.species.id),
      ...trainer.pcBoxes.expand((b) => b.map((p) => p.species.id)),
    };
    if (allSpecies.any((id) => id >= 1 && id <= 3)) {
      return 6; // Player has Bulbasaur line -> Blue leads Charizard ace
    }
    if (allSpecies.any((id) => id >= 4 && id <= 6)) {
      return 9; // Player has Charmander line -> Blue leads Blastoise ace
    }
    if (allSpecies.any((id) => id >= 7 && id <= 9)) {
      return 3; // Player has Squirtle line -> Blue leads Venusaur ace
    }
    return 6;
  }

  /// State 2: Indigo Plateau Final Four → Regional Champion (5 consecutive chambers, Lv. 88–98).
  static List<LeagueBossTrainer> buildEliteFourAndChampionStages(
    Trainer trainer,
  ) {
    if (trainer.activeRegion == GameRegion.johto) {
      return buildJohtoEliteFourAndChampionStages(trainer);
    }
    final int blueAceId = championStarterCounterId(trainer);
    final List<GymPokemonSpec> blueTeam;
    if (blueAceId == 6) {
      // Charizard ace -> Gyarados + Exeggutor support
      blueTeam = const [
        GymPokemonSpec(speciesId: 18, level: 94, moveIds: ['brave_bird', 'double_edge', 'heat_wave', 'roost'], heldItemId: 'sitrus_berry'), // Pidgeot
        GymPokemonSpec(speciesId: 65, level: 95, moveIds: ['psychic', 'shadow_ball', 'aura_sphere', 'calm_mind'], heldItemId: 'twisted_spoon'), // Alakazam
        GymPokemonSpec(speciesId: 112, level: 95, moveIds: ['earthquake', 'stone_edge', 'megahorn', 'body_slam'], heldItemId: 'hard_stone'), // Rhydon
        GymPokemonSpec(speciesId: 130, level: 96, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'), // Gyarados
        GymPokemonSpec(speciesId: 103, level: 96, moveIds: ['leaf_storm', 'psychic', 'sludge_bomb', 'sleep_powder'], heldItemId: 'miracle_seed'), // Exeggutor
        GymPokemonSpec(speciesId: 6, level: 98, moveIds: ['flare_blitz', 'air_slash', 'dragon_claw', 'roost'], heldItemId: 'lum_berry'), // Charizard
      ];
    } else if (blueAceId == 9) {
      // Blastoise ace -> Arcanine + Exeggutor support
      blueTeam = const [
        GymPokemonSpec(speciesId: 18, level: 94, moveIds: ['brave_bird', 'double_edge', 'heat_wave', 'roost'], heldItemId: 'sitrus_berry'), // Pidgeot
        GymPokemonSpec(speciesId: 65, level: 95, moveIds: ['psychic', 'shadow_ball', 'aura_sphere', 'calm_mind'], heldItemId: 'twisted_spoon'), // Alakazam
        GymPokemonSpec(speciesId: 112, level: 95, moveIds: ['earthquake', 'stone_edge', 'megahorn', 'body_slam'], heldItemId: 'hard_stone'), // Rhydon
        GymPokemonSpec(speciesId: 59, level: 96, moveIds: ['flare_blitz', 'extreme_speed', 'crunch', 'thunder_fang'], heldItemId: 'charcoal'), // Arcanine
        GymPokemonSpec(speciesId: 103, level: 96, moveIds: ['leaf_storm', 'psychic', 'sludge_bomb', 'sleep_powder'], heldItemId: 'miracle_seed'), // Exeggutor
        GymPokemonSpec(speciesId: 9, level: 98, moveIds: ['hydro_pump', 'ice_beam', 'aura_sphere', 'dark_pulse'], heldItemId: 'leftovers'), // Blastoise
      ];
    } else {
      // Venusaur ace -> Arcanine + Gyarados support
      blueTeam = const [
        GymPokemonSpec(speciesId: 18, level: 94, moveIds: ['brave_bird', 'double_edge', 'heat_wave', 'roost'], heldItemId: 'sitrus_berry'), // Pidgeot
        GymPokemonSpec(speciesId: 65, level: 95, moveIds: ['psychic', 'shadow_ball', 'aura_sphere', 'calm_mind'], heldItemId: 'twisted_spoon'), // Alakazam
        GymPokemonSpec(speciesId: 112, level: 95, moveIds: ['earthquake', 'stone_edge', 'megahorn', 'body_slam'], heldItemId: 'hard_stone'), // Rhydon
        GymPokemonSpec(speciesId: 59, level: 96, moveIds: ['flare_blitz', 'extreme_speed', 'crunch', 'thunder_fang'], heldItemId: 'charcoal'), // Arcanine
        GymPokemonSpec(speciesId: 130, level: 96, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'), // Gyarados
        GymPokemonSpec(speciesId: 3, level: 98, moveIds: ['energy_ball', 'sludge_bomb', 'earthquake', 'sleep_powder'], heldItemId: 'leftovers'), // Venusaur
      ];
    }

    return [
      const LeagueBossTrainer(
        id: 'e4_lorelei',
        spriteId: 'e4_lorelei',
        name: 'Lorelei',
        title: 'Final Four • Ice Master',
        roleLabel: 'FINAL FOUR #1',
        chamberName: 'Glacial Ice Chamber',
        backgroundAsset: 'assets/images/battle_bg_e4_ice.png',
        accentColor: Color(0xFF4FC3F7),
        prizeMoney: 11000,
        introDialogue:
            "Welcome to the Pokémon League! I am Lorelei of the Final Four. No one can best me when it comes to icy Pokémon—freeze solid!",
        defeatDialogue:
            "How dare you melt through my frost! You may just have what it takes to face the rest of us...",
        exclusiveHeldItemId: 'never_melt_ice',
        exclusiveTmId: 'tm_52',
        team: [
          GymPokemonSpec(speciesId: 87, level: 88, moveIds: ['surf', 'ice_beam', 'signal_beam', 'rest'], heldItemId: 'sitrus_berry'), // Dewgong
          GymPokemonSpec(speciesId: 91, level: 89, moveIds: ['icicle_spear', 'hydro_pump', 'ice_shard', 'spike_cannon'], heldItemId: 'never_melt_ice'), // Cloyster
          GymPokemonSpec(speciesId: 80, level: 89, moveIds: ['surf', 'psychic', 'ice_beam', 'calm_mind'], heldItemId: 'leftovers'), // Slowbro
          GymPokemonSpec(speciesId: 124, level: 90, moveIds: ['ice_beam', 'psychic', 'shadow_ball', 'lovely_kiss'], heldItemId: 'lum_berry'), // Jynx
          GymPokemonSpec(speciesId: 134, level: 90, moveIds: ['surf', 'ice_beam', 'aurora_beam', 'acid_armor'], heldItemId: 'mystic_water'), // Vaporeon
          GymPokemonSpec(speciesId: 131, level: 91, moveIds: ['blizzard', 'hydro_pump', 'thunderbolt', 'ice_beam'], heldItemId: 'never_melt_ice'), // Lapras
        ],
      ),
      const LeagueBossTrainer(
        id: 'e4_bruno',
        spriteId: 'e4_bruno',
        name: 'Bruno',
        title: 'Final Four • Fighting Master',
        roleLabel: 'FINAL FOUR #2',
        chamberName: 'Fighting Cavern',
        backgroundAsset: 'assets/images/battle_bg_e4_fighting.png',
        accentColor: Color(0xFFFF7043),
        prizeMoney: 12000,
        introDialogue:
            "I am Bruno of the Final Four! Through rigorous training, people and Pokémon become stronger without fail! Hoo hah!",
        defeatDialogue:
            "Why?! How could I lose after all that training? Keep forging ahead, challenger!",
        exclusiveHeldItemId: 'black_belt',
        exclusiveTmId: 'tm_53',
        team: [
          GymPokemonSpec(speciesId: 76, level: 89, moveIds: ['earthquake', 'stone_edge', 'explosion', 'body_slam'], heldItemId: 'hard_stone'), // Golem
          GymPokemonSpec(speciesId: 107, level: 90, moveIds: ['close_combat', 'ice_punch', 'thunder_punch', 'mach_punch'], heldItemId: 'sitrus_berry'), // Hitmonchan
          GymPokemonSpec(speciesId: 106, level: 90, moveIds: ['close_combat', 'blaze_kick', 'stone_edge', 'mega_kick'], heldItemId: 'black_belt'), // Hitmonlee
          GymPokemonSpec(speciesId: 62, level: 91, moveIds: ['waterfall', 'close_combat', 'ice_punch', 'belly_drum'], heldItemId: 'lum_berry'), // Poliwrath
          GymPokemonSpec(speciesId: 57, level: 91, moveIds: ['close_combat', 'cross_chop', 'rock_slide', 'thrash'], heldItemId: 'sitrus_berry'), // Primeape
          GymPokemonSpec(speciesId: 68, level: 92, moveIds: ['close_combat', 'cross_chop', 'stone_edge', 'bullet_punch'], heldItemId: 'black_belt'), // Machamp
        ],
      ),
      const LeagueBossTrainer(
        id: 'e4_agatha',
        spriteId: 'e4_agatha',
        name: 'Agatha',
        title: 'Final Four • Ghost Master',
        roleLabel: 'FINAL FOUR #3',
        chamberName: 'Haunted Ghost Crypt',
        backgroundAsset: 'assets/images/battle_bg_e4_ghost.png',
        accentColor: Color(0xFFAB47BC),
        prizeMoney: 13000,
        introDialogue:
            "I am Agatha of the Final Four! I hear Oak's taken a lot of interest in you, child. Show me what a real trainer looks like!",
        defeatDialogue:
            "Ooh-hoo! You're something special after all, child! Go see what awaits in the next chamber!",
        exclusiveHeldItemId: 'spell_tag',
        exclusiveTmId: 'tm_54',
        team: [
          GymPokemonSpec(speciesId: 94, level: 90, moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'hypnosis'], heldItemId: 'sitrus_berry'), // Gengar
          GymPokemonSpec(speciesId: 42, level: 91, moveIds: ['air_slash', 'cross_poison', 'crunch', 'confuse_ray'], heldItemId: 'lum_berry'), // Golbat
          GymPokemonSpec(speciesId: 49, level: 91, moveIds: ['bug_buzz', 'sludge_bomb', 'psychic', 'sleep_powder'], heldItemId: 'poison_barb'), // Venomoth
          GymPokemonSpec(speciesId: 24, level: 92, moveIds: ['gunk_shot', 'crunch', 'earthquake', 'glare'], heldItemId: 'poison_barb'), // Arbok
          GymPokemonSpec(speciesId: 89, level: 92, moveIds: ['gunk_shot', 'shadow_punch', 'ice_punch', 'minimize'], heldItemId: 'leftovers'), // Muk
          GymPokemonSpec(speciesId: 94, level: 93, moveIds: ['shadow_ball', 'dark_pulse', 'sludge_bomb', 'aura_sphere'], heldItemId: 'spell_tag'), // Gengar Ace
        ],
      ),
      const LeagueBossTrainer(
        id: 'e4_lance',
        spriteId: 'e4_lance',
        name: 'Lance',
        title: 'Final Four • Dragon Master',
        roleLabel: 'FINAL FOUR #4',
        chamberName: 'Dragon Sanctum',
        backgroundAsset: 'assets/images/battle_bg_e4_dragon.png',
        accentColor: Color(0xFF5C6BC0),
        prizeMoney: 15000,
        introDialogue:
            "I am Lance, the dragon trainer! Dragons are mythical, virtually indestructible—can your team endure their wrath?!",
        defeatDialogue:
            "That's it! I hate to admit it, but you are a true Pokémon Master! Yet one final battle still awaits beyond that door...",
        exclusiveHeldItemId: 'dragon_fang',
        exclusiveTmId: 'tm_55',
        team: [
          GymPokemonSpec(speciesId: 130, level: 91, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'), // Gyarados
          GymPokemonSpec(speciesId: 148, level: 92, moveIds: ['dragon_pulse', 'thunderbolt', 'ice_beam', 'extreme_speed'], heldItemId: 'sitrus_berry'), // Dragonair
          GymPokemonSpec(speciesId: 142, level: 93, moveIds: ['stone_edge', 'sky_attack', 'crunch', 'earthquake'], heldItemId: 'hard_stone'), // Aerodactyl
          GymPokemonSpec(speciesId: 6, level: 93, moveIds: ['flare_blitz', 'air_slash', 'dragon_claw', 'roost'], heldItemId: 'charcoal'), // Charizard
          GymPokemonSpec(speciesId: 148, level: 94, moveIds: ['outrage', 'fire_blast', 'aqua_tail', 'thunder_wave'], heldItemId: 'lum_berry'), // Dragonair 2
          GymPokemonSpec(speciesId: 149, level: 95, moveIds: ['outrage', 'dragon_claw', 'fire_punch', 'extreme_speed'], heldItemId: 'dragon_fang'), // Dragonite
        ],
      ),
      LeagueBossTrainer(
        id: 'champion_blue',
        spriteId: 'champion_blue',
        name: 'Champion Blue',
        title: 'Indigo Plateau Champion',
        roleLabel: 'CHAMPIONSHIP BATTLE',
        chamberName: "Champion's Throne Room",
        backgroundAsset: 'assets/images/battle_bg_champion_hall.png',
        accentColor: const Color(0xFFFFB300),
        bgmCategory: BattleBgmCategory.special,
        prizeMoney: 30000,
        introDialogue:
            "Hey! I was looking forward to seeing you! I beat the Final Four ahead of you—now I'm the most powerful trainer in the world!",
        defeatDialogue:
            "NO! That can't be! You beat my best?! ...Fine! You're the new Indigo Plateau Champion. Enjoy the Hall of Fame!",
        exclusiveHeldItemId: 'life_orb',
        exclusiveTmId: 'tm_56',
        team: blueTeam,
      ),
    ];
  }

  /// First-time Champion Blue reward bundle (Master Ball remains exclusive to Jessie/James).
  static List<ItemDrop> buildChampionFirstClearRewards({required Trainer trainer}) {
    final List<ItemDrop> rewards = [];
    final tm51 = ItemDatabase.byId('tm_51');
    if (tm51 != null && !trainer.hasTm('tm_51')) {
      rewards.add(ItemDrop(
        itemId: tm51.id,
        itemName: tm51.name,
        count: 1,
        rarity: PokemonRarity.special,
      ));
    }
    rewards.addAll(const [
      ItemDrop(
        itemId: 'heart_scale',
        itemName: 'Heart Scale',
        count: 3,
        rarity: PokemonRarity.rare,
      ),
      ItemDrop(
        itemId: 'rare_candy',
        itemName: 'Rare Candy',
        count: 3,
        rarity: PokemonRarity.rare,
      ),
      ItemDrop(
        itemId: 'full_restore',
        itemName: 'Full Restore',
        count: 5,
        rarity: PokemonRarity.rare,
      ),
      ItemDrop(
        itemId: 'max_revive',
        itemName: 'Max Revive',
        count: 3,
        rarity: PokemonRarity.rare,
      ),
    ]);
    return rewards;
  }

  /// Lv. 99 Master Rematch pool for Final Stage 6 (random pick of the regional Final Four or Champion).
  static List<LeagueBossTrainer> buildRematchLeagueBossPool(Trainer trainer) {
    if (trainer.activeRegion == GameRegion.johto) {
      return buildJohtoRematchLeagueBossPool(trainer);
    }
    final int blueAceId = championStarterCounterId(trainer);
    final int supportA = blueAceId == 6 ? 130 : 59; // Gyarados vs Arcanine
    final int supportB = blueAceId == 3 ? 130 : 103; // Gyarados vs Exeggutor

    return [
      const LeagueBossTrainer(
        id: 'rematch_lorelei',
        spriteId: 'e4_lorelei',
        name: 'Lorelei',
        title: 'Final Four • Master Rematch',
        roleLabel: 'MASTER FINAL BOSS',
        chamberName: 'Glacial Ice Chamber',
        backgroundAsset: 'assets/images/battle_bg_e4_ice.png',
        accentColor: Color(0xFF4FC3F7),
        bgmCategory: BattleBgmCategory.gym,
        prizeMoney: 16000,
        introDialogue:
            "So the Champion climbs Victory Road once more! Let's see if you can survive my absolute zero assault!",
        defeatDialogue:
            "Brrr... Even at full strength, your bond shattered my glacier!",
        exclusiveHeldItemId: 'never_melt_ice',
        exclusiveTmId: 'tm_52',
        team: [
          GymPokemonSpec(speciesId: 91, level: 99, moveIds: ['icicle_spear', 'hydro_pump', 'ice_shard', 'explosion'], heldItemId: 'sitrus_berry'),
          GymPokemonSpec(speciesId: 80, level: 99, moveIds: ['surf', 'psychic', 'ice_beam', 'calm_mind'], heldItemId: 'leftovers'),
          GymPokemonSpec(speciesId: 124, level: 99, moveIds: ['blizzard', 'psychic', 'shadow_ball', 'lovely_kiss'], heldItemId: 'lum_berry'),
          GymPokemonSpec(speciesId: 134, level: 99, moveIds: ['hydro_pump', 'ice_beam', 'shadow_ball', 'acid_armor'], heldItemId: 'mystic_water'),
          GymPokemonSpec(speciesId: 87, level: 99, moveIds: ['ice_beam', 'surf', 'signal_beam', 'sheer_cold'], heldItemId: 'sitrus_berry'),
          GymPokemonSpec(speciesId: 131, level: 99, moveIds: ['blizzard', 'hydro_pump', 'thunderbolt', 'ice_shard'], heldItemId: 'never_melt_ice'),
        ],
      ),
      const LeagueBossTrainer(
        id: 'rematch_bruno',
        spriteId: 'e4_bruno',
        name: 'Bruno',
        title: 'Final Four • Master Rematch',
        roleLabel: 'MASTER FINAL BOSS',
        chamberName: 'Fighting Cavern',
        backgroundAsset: 'assets/images/battle_bg_e4_fighting.png',
        accentColor: Color(0xFFFF7043),
        bgmCategory: BattleBgmCategory.gym,
        prizeMoney: 16000,
        introDialogue:
            "Champion! Since our last clash I've trained day and night—feel the crushing weight of my Lv. 99 team!",
        defeatDialogue:
            "Gah! Even my fiercest training could not break your defense! Respect!",
        exclusiveHeldItemId: 'black_belt',
        exclusiveTmId: 'tm_53',
        team: [
          GymPokemonSpec(speciesId: 76, level: 99, moveIds: ['earthquake', 'stone_edge', 'explosion', 'sucker_punch'], heldItemId: 'hard_stone'),
          GymPokemonSpec(speciesId: 107, level: 99, moveIds: ['close_combat', 'ice_punch', 'thunder_punch', 'mach_punch'], heldItemId: 'sitrus_berry'),
          GymPokemonSpec(speciesId: 106, level: 99, moveIds: ['close_combat', 'blaze_kick', 'stone_edge', 'poison_jab'], heldItemId: 'lum_berry'),
          GymPokemonSpec(speciesId: 62, level: 99, moveIds: ['waterfall', 'close_combat', 'ice_punch', 'belly_drum'], heldItemId: 'leftovers'),
          GymPokemonSpec(speciesId: 112, level: 99, moveIds: ['earthquake', 'stone_edge', 'close_combat', 'megahorn'], heldItemId: 'soft_sand'),
          GymPokemonSpec(speciesId: 68, level: 99, moveIds: ['close_combat', 'cross_chop', 'stone_edge', 'bullet_punch'], heldItemId: 'black_belt'),
        ],
      ),
      const LeagueBossTrainer(
        id: 'rematch_agatha',
        spriteId: 'e4_agatha',
        name: 'Agatha',
        title: 'Final Four • Master Rematch',
        roleLabel: 'MASTER FINAL BOSS',
        chamberName: 'Haunted Ghost Crypt',
        backgroundAsset: 'assets/images/battle_bg_e4_ghost.png',
        accentColor: Color(0xFFAB47BC),
        bgmCategory: BattleBgmCategory.gym,
        prizeMoney: 17000,
        introDialogue:
            "Heh heh... Returning for another haunt, Champion? My spectral legion won't go easy this time!",
        defeatDialogue:
            "Magnificent! You walk untouched through shadow and venom alike!",
        exclusiveHeldItemId: 'spell_tag',
        exclusiveTmId: 'tm_54',
        team: [
          GymPokemonSpec(speciesId: 94, level: 99, moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'hypnosis'], heldItemId: 'sitrus_berry'),
          GymPokemonSpec(speciesId: 42, level: 99, moveIds: ['brave_bird', 'cross_poison', 'crunch', 'confuse_ray'], heldItemId: 'lum_berry'),
          GymPokemonSpec(speciesId: 49, level: 99, moveIds: ['bug_buzz', 'sludge_bomb', 'psychic', 'quiver_dance'], heldItemId: 'poison_barb'),
          GymPokemonSpec(speciesId: 89, level: 99, moveIds: ['gunk_shot', 'shadow_punch', 'ice_punch', 'fire_punch'], heldItemId: 'leftovers'),
          GymPokemonSpec(speciesId: 24, level: 99, moveIds: ['gunk_shot', 'crunch', 'earthquake', 'glare'], heldItemId: 'poison_barb'),
          GymPokemonSpec(speciesId: 94, level: 99, moveIds: ['shadow_ball', 'dark_pulse', 'sludge_bomb', 'aura_sphere'], heldItemId: 'spell_tag'),
        ],
      ),
      const LeagueBossTrainer(
        id: 'rematch_lance',
        spriteId: 'e4_lance',
        name: 'Lance',
        title: 'Final Four • Master Rematch',
        roleLabel: 'MASTER FINAL BOSS',
        chamberName: 'Dragon Sanctum',
        backgroundAsset: 'assets/images/battle_bg_e4_dragon.png',
        accentColor: Color(0xFF5C6BC0),
        bgmCategory: BattleBgmCategory.gym,
        prizeMoney: 19000,
        introDialogue:
            "So you conquered Victory Road again, Champion! Now face the full, unrestrained fury of my Lv. 99 dragons!",
        defeatDialogue:
            "Unbelievable! Truly worthy of the Kanto Championship crown!",
        exclusiveHeldItemId: 'dragon_fang',
        exclusiveTmId: 'tm_55',
        team: [
          GymPokemonSpec(speciesId: 130, level: 99, moveIds: ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance'], heldItemId: 'mystic_water'),
          GymPokemonSpec(speciesId: 142, level: 99, moveIds: ['stone_edge', 'brave_bird', 'earthquake', 'crunch'], heldItemId: 'hard_stone'),
          GymPokemonSpec(speciesId: 6, level: 99, moveIds: ['flare_blitz', 'air_slash', 'dragon_claw', 'roost'], heldItemId: 'charcoal'),
          GymPokemonSpec(speciesId: 148, level: 99, moveIds: ['dragon_pulse', 'thunderbolt', 'ice_beam', 'extreme_speed'], heldItemId: 'sitrus_berry'),
          GymPokemonSpec(speciesId: 149, level: 99, moveIds: ['outrage', 'earthquake', 'fire_punch', 'dragon_dance'], heldItemId: 'lum_berry'),
          GymPokemonSpec(speciesId: 149, level: 99, moveIds: ['outrage', 'dragon_claw', 'hurricane', 'extreme_speed'], heldItemId: 'dragon_fang'),
        ],
      ),
      LeagueBossTrainer(
        id: 'rematch_blue',
        spriteId: 'champion_blue',
        name: 'Blue',
        title: 'Grand Rival • Lv.99 Rematch',
        roleLabel: 'MASTER FINAL BOSS',
        chamberName: "Champion's Throne Room",
        backgroundAsset: 'assets/images/battle_bg_champion_hall.png',
        accentColor: const Color(0xFFFFB300),
        bgmCategory: BattleBgmCategory.special,
        prizeMoney: 25000,
        introDialogue:
            "Yo, Champ! Didn't think I'd let you keep the crown without a real rematch, did you?! Time to settle this at Lv. 99!",
        defeatDialogue:
            "Still as sharp as ever... All right, you win again, Champ. Take this—you earned it!",
        exclusiveHeldItemId: 'life_orb',
        exclusiveTmId: 'tm_56',
        team: [
          const GymPokemonSpec(speciesId: 18, level: 99, moveIds: ['brave_bird', 'double_edge', 'heat_wave', 'roost'], heldItemId: 'sitrus_berry'),
          const GymPokemonSpec(speciesId: 65, level: 99, moveIds: ['psychic', 'shadow_ball', 'aura_sphere', 'calm_mind'], heldItemId: 'twisted_spoon'),
          const GymPokemonSpec(speciesId: 112, level: 99, moveIds: ['earthquake', 'stone_edge', 'megahorn', 'body_slam'], heldItemId: 'hard_stone'),
          GymPokemonSpec(
            speciesId: supportA,
            level: 99,
            moveIds: supportA == 130
                ? const ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance']
                : const ['flare_blitz', 'extreme_speed', 'crunch', 'thunder_fang'],
            heldItemId: supportA == 130 ? 'mystic_water' : 'charcoal',
          ),
          GymPokemonSpec(
            speciesId: supportB,
            level: 99,
            moveIds: supportB == 130
                ? const ['waterfall', 'ice_fang', 'earthquake', 'dragon_dance']
                : const ['leaf_storm', 'psychic', 'sludge_bomb', 'sleep_powder'],
            heldItemId: supportB == 130 ? 'lum_berry' : 'miracle_seed',
          ),
          GymPokemonSpec(
            speciesId: blueAceId,
            level: 99,
            moveIds: blueAceId == 6
                ? const ['flare_blitz', 'air_slash', 'dragon_claw', 'roost']
                : (blueAceId == 9
                    ? const ['hydro_pump', 'ice_beam', 'aura_sphere', 'dark_pulse']
                    : const ['energy_ball', 'sludge_bomb', 'earthquake', 'sleep_powder']),
            heldItemId: 'life_orb',
          ),
        ],
      ),
    ];
  }

  /// State 3: Master Rematch (6 alternating Lv. 99 stages: Wild → Trainer → Wild → Trainer → Wild → Random Final Four / Champion).
  static List<VictoryRoadStage> buildMasterRematchStages(
    Trainer trainer, {
    Random? rng,
  }) {
    final random = rng ?? _rng;
    if (trainer.activeRegion == GameRegion.johto) {
      return buildJohtoMasterRematchStages(trainer, random: random);
    }
    final bossPool = buildRematchLeagueBossPool(trainer);
    final LeagueBossTrainer finalBoss = bossPool[random.nextInt(bossPool.length)];

    const intermediateTrainers = [
      GymTrainer(
        id: 'vr_master_t1',
        spriteId: 'npc_ninja',
        name: 'Ninja Master Kaito',
        title: 'Victory Road Master (2v2)',
        prizeMoney: 6500,
        introDialogue:
            "At the summit of Victory Road, our shadow duo strikes as one in Double Battles!",
        defeatDialogue:
            "Your speed and precision cut right through our coordinated shadow arts!",
        team: [
          GymPokemonSpec(
            speciesId: 49, // Venomoth
            level: 99,
            heldItemId: 'poison_barb',
            moveIds: ['bug_buzz', 'sludge_wave', 'rage_powder', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 94, // Gengar
            level: 99,
            heldItemId: 'spell_tag',
            moveIds: ['shadow_ball', 'sludge_wave', 'icy_wind', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 123, // Scyther
            level: 99,
            heldItemId: 'sitrus_berry',
            moveIds: ['x_scissor', 'aerial_ace', 'quick_guard', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 65, // Alakazam
            level: 99,
            heldItemId: 'twisted_spoon',
            moveIds: ['psychic', 'shadow_ball', 'ally_switch', 'protect'],
          ),
        ],
      ),
      GymTrainer(
        id: 'vr_master_t2',
        spriteId: 'npc_psychic',
        name: 'Ace Esper Reina',
        title: 'Victory Road Master (2v2)',
        prizeMoney: 6800,
        introDialogue:
            "Double minds move as one! Face our coordinated Lv. 99 psychic tag-team!",
        defeatDialogue:
            "Even dual foresight couldn't predict a victory like that!",
        team: [
          GymPokemonSpec(
            speciesId: 122, // Mr. Mime
            level: 99,
            heldItemId: 'twisted_spoon',
            moveIds: ['psychic', 'helping_hand', 'reflect', 'light_screen'],
          ),
          GymPokemonSpec(
            speciesId: 121, // Starmie
            level: 99,
            heldItemId: 'mystic_water',
            moveIds: ['surf', 'blizzard', 'psychic', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 80, // Slowbro
            level: 99,
            heldItemId: 'leftovers',
            moveIds: ['surf', 'psychic', 'heal_pulse', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 103, // Exeggutor
            level: 99,
            heldItemId: 'miracle_seed',
            moveIds: ['leaf_storm', 'psychic', 'sleep_powder', 'protect'],
          ),
        ],
      ),
      GymTrainer(
        id: 'vr_master_t3',
        spriteId: 'npc_hiker',
        name: 'Mountaineer Magnus',
        title: 'Victory Road Master (2v2)',
        prizeMoney: 7000,
        introDialogue:
            "Wait till you feel twin Rock Slides shaking the summit in a Lv. 99 Double Battle!",
        defeatDialogue:
            "Granite and iron shattered like glass! Keep marching to the hall!",
        team: [
          GymPokemonSpec(
            speciesId: 142, // Aerodactyl
            level: 99,
            heldItemId: 'lum_berry',
            moveIds: ['rock_slide', 'earthquake', 'tailwind', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 76, // Golem
            level: 99,
            heldItemId: 'hard_stone',
            moveIds: ['rock_slide', 'earthquake', 'explosion', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 141, // Kabutops
            level: 99,
            heldItemId: 'sitrus_berry',
            moveIds: ['rock_slide', 'waterfall', 'aqua_jet', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 112, // Rhydon
            level: 99,
            heldItemId: 'soft_sand',
            moveIds: ['earthquake', 'rock_slide', 'megahorn', 'protect'],
          ),
        ],
      ),
      GymTrainer(
        id: 'vr_master_t4',
        spriteId: 'npc_beauty',
        name: 'Ace Duelist Valerie',
        title: 'Victory Road Master (2v2)',
        prizeMoney: 7200,
        introDialogue:
            "Champions command two Pokémon in harmony—let's see how you handle a Lv. 99 Double Battle!",
        defeatDialogue:
            "What poise and synergy! You truly shine like a Champion!",
        team: [
          GymPokemonSpec(
            speciesId: 36, // Clefable
            level: 99,
            heldItemId: 'leftovers',
            moveIds: ['moonblast', 'follow_me', 'helping_hand', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 59, // Arcanine
            level: 99,
            heldItemId: 'charcoal',
            moveIds: ['heat_wave', 'extreme_speed', 'close_combat', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 135, // Jolteon
            level: 99,
            heldItemId: 'magnet',
            moveIds: ['discharge', 'shadow_ball', 'helping_hand', 'protect'],
          ),
          GymPokemonSpec(
            speciesId: 131, // Lapras
            level: 99,
            heldItemId: 'mystic_water',
            moveIds: ['surf', 'blizzard', 'icy_wind', 'protect'],
          ),
        ],
      ),
    ];

    final shuffled = List<GymTrainer>.from(intermediateTrainers)..shuffle(random);

    return [
      const VictoryRoadStage.wild(
        stageNumber: 1,
        level: 99,
        label: 'Master Ridge I (Wild Lv.99)',
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
        label: 'Master Ridge II (Wild Lv.99)',
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
        label: 'Master Ridge III (Wild Lv.99)',
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

  /// Exclusive rematch reward drops tailored to whichever Final Four member or Champion Blue appeared.
  static List<ItemDrop> rollLeagueBossRematchDrops({
    required LeagueBossTrainer boss,
    required Trainer trainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final List<ItemDrop> drops = [];

    // 1. Signature Exclusive Held Item (e.g. Never-Melt Ice, Black Belt, Spell Tag, Dragon Fang, Life Orb)
    final held = ItemDatabase.byId(boss.exclusiveHeldItemId);
    if (held != null) {
      drops.add(ItemDrop(
        itemId: held.id,
        itemName: held.name,
        count: 1,
        rarity: held.rarity,
      ));
    }

    // 2. Signature Exclusive Rare TM (if not owned yet); otherwise bonus Rare Candy
    final tm = ItemDatabase.byId(boss.exclusiveTmId);
    if (tm != null && !trainer.hasTm(tm.id)) {
      drops.add(ItemDrop(
        itemId: tm.id,
        itemName: tm.name,
        count: 1,
        rarity: PokemonRarity.special,
      ));
    } else {
      drops.add(const ItemDrop(
        itemId: 'rare_candy',
        itemName: 'Rare Candy',
        count: 2,
        rarity: PokemonRarity.rare,
      ));
    }

    // 3. Heart Scales & Max-tier Recovery
    final bool isChampionBoss =
        boss.id.contains('blue') || boss.id.contains('johto_lance');
    if (isChampionBoss) {
      drops.add(const ItemDrop(
        itemId: 'heart_scale',
        itemName: 'Heart Scale',
        count: 2,
        rarity: PokemonRarity.rare,
      ));
      drops.add(const ItemDrop(
        itemId: 'max_revive',
        itemName: 'Max Revive',
        count: 2,
        rarity: PokemonRarity.rare,
      ));
    } else {
      if (random.nextDouble() < 0.75) {
        drops.add(const ItemDrop(
          itemId: 'heart_scale',
          itemName: 'Heart Scale',
          count: 1,
          rarity: PokemonRarity.rare,
        ));
      }
      drops.add(const ItemDrop(
        itemId: 'full_restore',
        itemName: 'Full Restore',
        count: 2,
        rarity: PokemonRarity.rare,
      ));
    }

    return ItemDropService.mergeDrops(drops);
  }
}
