import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_version.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import 'pokedex_database.dart';

class ExpeditionDestination {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String arrivalNarration;
  final int legendarySpeciesId;
  final Color accentColor;
  final String backgroundAsset;
  final List<int> wildSpeciesPool;

  const ExpeditionDestination({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.arrivalNarration,
    required this.legendarySpeciesId,
    required this.accentColor,
    required this.backgroundAsset,
    required this.wildSpeciesPool,
  });
}

class RocketChallenger {
  final String name;
  final String title;
  final String spriteId;
  final bool isJessieOrJames;
  final String introDialogue;
  final int prizeMoney;
  final List<PokemonInstance> team;

  const RocketChallenger({
    required this.name,
    required this.title,
    required this.spriteId,
    required this.isJessieOrJames,
    required this.introDialogue,
    required this.prizeMoney,
    required this.team,
  });
}

class ExpeditionDatabase {
  static final Random _rng = Random();

  static const int mewSpeciesId = 151;

  static const List<ExpeditionDestination> destinations = [
    ExpeditionDestination(
      id: 'seafoam_islands',
      name: 'Seafoam Islands',
      subtitle: 'Frozen Subterranean Sea',
      description:
          'Glacial sea caverns deep beneath southern Kanto where Articuno roosts.',
      arrivalNarration:
          'Icy mist swirls around subterranean tides as your team steps onto the frozen ledges of Seafoam Islands...',
      legendarySpeciesId: 144, // Articuno
      accentColor: Color(0xFF4FC3F7),
      backgroundAsset: 'assets/images/battle_bg_seafoam.png',
      wildSpeciesPool: [
        55, 73, 80, 87, 91, 99, 117, 119, 121, 124, 130, 131,
      ],
    ),
    ExpeditionDestination(
      id: 'power_plant',
      name: 'Power Plant',
      subtitle: 'Abandoned High-Voltage Hall',
      description:
          'Abandoned copper-wound generators crackling with static where Zapdos nests.',
      arrivalNarration:
          'Humming generators echo through overgrown turbine halls while arcs of lightning flash across the Power Plant...',
      legendarySpeciesId: 145, // Zapdos
      accentColor: Color(0xFFFFD54F),
      backgroundAsset: 'assets/images/battle_bg_power_plant.png',
      wildSpeciesPool: [
        25, 26, 81, 82, 89, 100, 101, 110, 125, 135, 137,
      ],
    ),
    ExpeditionDestination(
      id: 'victory_road',
      name: 'Victory Road',
      subtitle: 'Molten Summit Ridge',
      description:
          'Scorched volcanic caverns on Indigo Plateau where Moltres kindles eternal flames.',
      arrivalNarration:
          'Waves of dry volcanic heat rise from basalt fissures as you march deep into the fiery tunnels of Victory Road...',
      legendarySpeciesId: 146, // Moltres
      accentColor: Color(0xFFFF7043),
      backgroundAsset: 'assets/images/battle_bg_victory_road.png',
      wildSpeciesPool: [
        24, 28, 31, 34, 38, 45, 57, 59, 68, 71, 76, 78, 95, 105, 112, 126,
      ],
    ),
    ExpeditionDestination(
      id: 'cerulean_cave',
      name: 'Cerulean Cave',
      subtitle: 'Bioluminescent Crystal Sanctum',
      description:
          'Uncharted crystal chambers hiding Kanto\'s strongest wild Pokémon and Mewtwo.',
      arrivalNarration:
          'Violet-cyan crystals illuminate the mist-filled abyss of Cerulean Cave. An overwhelming psychic aura stirs nearby...',
      legendarySpeciesId: 150, // Mewtwo
      accentColor: Color(0xFFCE93D8),
      backgroundAsset: 'assets/images/battle_bg_cerulean_cave.png',
      wildSpeciesPool: [
        42, 49, 55, 65, 80, 82, 94, 97, 101, 105, 112, 113, 121, 123, 124, 125,
        126, 127, 130, 149,
      ],
    ),
  ];

  static const List<int> _rocketGruntPool = [
    20, // Raticate
    24, // Arbok
    28, // Sandslash
    42, // Golbat
    49, // Venomoth
    51, // Dugtrio
    53, // Persian
    57, // Primeape
    68, // Machamp
    76, // Golem
    89, // Muk
    97, // Hypno
    101, // Electrode
    110, // Weezing
    112, // Rhydon
  ];

  /// Generates 1 of the 3 strong wild Pokémon (Lv. 85-90), respecting
  /// the player's Red / Blue-Green version exclusives.
  static PokemonInstance generateWildEncounter(
    ExpeditionDestination destination, {
    GameVersion? gameVersion,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final filtered = destination.wildSpeciesPool.where((id) {
      final spec = PokedexDatabase.species[id];
      return spec != null && spec.isAvailableInVersion(gameVersion);
    }).toList();
    final pool = filtered.isNotEmpty ? filtered : destination.wildSpeciesPool;
    final chosenId = pool[random.nextInt(pool.length)];
    final species = PokedexDatabase.species[chosenId]!;
    final int level = 85 + random.nextInt(6); // 85..90
    final bool isShiny = PokedexDatabase.rollShiny(species);
    return PokedexDatabase.createPokemon(
      chosenId,
      level: level,
      isShiny: isShiny,
      respectMinEncounterLevel: false,
    );
  }

  /// Generates the Team Rocket ambush challenger (10% chance Jessie or James,
  /// 90% Team Rocket Grunt) with a full 6-Pokémon party averaging Lv. 90.
  static RocketChallenger generateRocketChallenger({Random? rng}) {
    final random = rng ?? _rng;
    final double roll = random.nextDouble();
    const List<int> levels = [88, 89, 90, 90, 91, 92]; // Exact avg = 90.0

    if (roll < 0.05) {
      const ids = [108, 42, 124, 89, 130, 24]; // Lickitung..Arbok
      final team = [
        for (int i = 0; i < 6; i++)
          PokedexDatabase.createPokemon(
            ids[i],
            level: levels[i],
            respectMinEncounterLevel: false,
            hiddenAbilityChance: 0.10,
          ),
      ];
      return RocketChallenger(
        name: 'Jessie',
        title: 'Team Rocket Duo',
        spriteId: 'rocket_jessie',
        isJessieOrJames: true,
        introDialogue:
            "Prepare for trouble! This rare hunting ground belongs to Team Rocket now!",
        prizeMoney: 10000,
        team: team,
      );
    }

    if (roll < 0.10) {
      const ids = [53, 73, 130, 49, 71, 110]; // Persian..Weezing
      final team = [
        for (int i = 0; i < 6; i++)
          PokedexDatabase.createPokemon(
            ids[i],
            level: levels[i],
            respectMinEncounterLevel: false,
            hiddenAbilityChance: 0.10,
          ),
      ];
      return RocketChallenger(
        name: 'James',
        title: 'Team Rocket Duo',
        spriteId: 'rocket_james',
        isJessieOrJames: true,
        introDialogue:
            "And make it double! Hand over your rarest Pokémon and step aside!",
        prizeMoney: 10000,
        team: team,
      );
    }

    final pool = List<int>.from(_rocketGruntPool)..shuffle(random);
    final team = [
      for (int i = 0; i < 6; i++)
        PokedexDatabase.createPokemon(
          pool[i % pool.length],
          level: levels[i],
          respectMinEncounterLevel: false,
        ),
    ];
    return RocketChallenger(
      name: 'Rocket Grunt',
      title: 'Team Rocket Raider',
      spriteId: 'rocket_grunt',
      isJessieOrJames: false,
      introDialogue:
          "Hold it! Team Rocket spotted a legendary energy spike here—no intruders allowed!",
      prizeMoney: 6000,
      team: team,
    );
  }

  /// Rolls whether Mew (0.01%) or the destination's Legendary (5%) appears
  /// at Lv. 99 after Team Rocket is defeated. Caught species never reappear.
  static PokemonInstance? rollPostRocketBoss({
    required ExpeditionDestination destination,
    required Trainer trainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final bool caughtMew = trainer.hasCaughtExpeditionSpecies(mewSpeciesId);
    final bool caughtDest =
        trainer.hasCaughtExpeditionSpecies(destination.legendarySpeciesId);

    if (!caughtMew && random.nextDouble() < 0.0001) {
      final spec = PokedexDatabase.species[mewSpeciesId];
      return PokedexDatabase.createPokemon(
        mewSpeciesId,
        level: 99,
        respectMinEncounterLevel: false,
        isShiny: spec != null && PokedexDatabase.rollShiny(spec),
        hiddenAbilityChance: 0.15,
      );
    }
    if (!caughtDest && random.nextDouble() < 0.05) {
      final spec = PokedexDatabase.species[destination.legendarySpeciesId];
      return PokedexDatabase.createPokemon(
        destination.legendarySpeciesId,
        level: 99,
        respectMinEncounterLevel: false,
        isShiny: spec != null && PokedexDatabase.rollShiny(spec),
        hiddenAbilityChance: 0.15,
      );
    }
    return null;
  }
}
