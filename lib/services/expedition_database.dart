import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_region.dart';
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
  final String? partnerSpriteId;
  final bool isJessieOrJames;
  final bool isDoubleBattle;
  final String introDialogue;
  final String defeatDialogue;
  final int prizeMoney;
  final List<PokemonInstance> team;

  const RocketChallenger({
    required this.name,
    required this.title,
    required this.spriteId,
    this.partnerSpriteId,
    required this.isJessieOrJames,
    this.isDoubleBattle = false,
    required this.introDialogue,
    this.defeatDialogue = "No way! Back to the balloon!",
    required this.prizeMoney,
    required this.team,
  });
}

class ExpeditionDatabase {
  static final Random _rng = Random();

  static const int mewSpeciesId = 151;
  static const int celebiSpeciesId = 251;

  static bool isMythicalExpeditionSpecies(int speciesId) =>
      speciesId == mewSpeciesId || speciesId == celebiSpeciesId;

  static const List<ExpeditionDestination> destinations = [
    ExpeditionDestination(
      id: 'seafoam_islands',
      name: 'Seafoam Islands',
      subtitle: 'Frozen Subterranean Sea',
      description:
          'Glacial sea caverns deep beneath southern Kanto, carved by freezing subterranean tides.',
      arrivalNarration:
          'Icy mist swirls around subterranean tides as your team steps onto the frozen ledges of Seafoam Islands...',
      legendarySpeciesId: 144, // Articuno
      accentColor: Color(0xFF4FC3F7),
      backgroundAsset: 'assets/images/battle_bg_seafoam.png',
      wildSpeciesPool: [
        55, 73, 80, 87, 91, 99, 117, 119, 121, 124, 130, 131, 176,
      ],
    ),
    ExpeditionDestination(
      id: 'power_plant',
      name: 'Power Plant',
      subtitle: 'Abandoned High-Voltage Hall',
      description:
          'Abandoned copper-wound generators crackling with restless high-voltage static.',
      arrivalNarration:
          'Humming generators echo through overgrown turbine halls while arcs of lightning flash across the Power Plant...',
      legendarySpeciesId: 145, // Zapdos
      accentColor: Color(0xFFFFD54F),
      backgroundAsset: 'assets/images/battle_bg_power_plant.png',
      wildSpeciesPool: [
        25, 26, 81, 82, 89, 100, 101, 110, 125, 135, 137, 176,
      ],
    ),
    ExpeditionDestination(
      id: 'victory_road',
      name: 'Victory Road',
      subtitle: 'Molten Summit Ridge',
      description:
          'Scorched volcanic caverns on Indigo Plateau where searing heat rises from basalt fissures.',
      arrivalNarration:
          'Waves of dry volcanic heat rise from basalt fissures as you march deep into the fiery tunnels of Victory Road...',
      legendarySpeciesId: 146, // Moltres
      accentColor: Color(0xFFFF7043),
      backgroundAsset: 'assets/images/battle_bg_victory_road.png',
      wildSpeciesPool: [
        24, 28, 31, 34, 38, 45, 57, 59, 68, 71, 76, 78, 95, 105, 112, 126, 176,
      ],
    ),
    ExpeditionDestination(
      id: 'cerulean_cave',
      name: 'Cerulean Cave',
      subtitle: 'Bioluminescent Crystal Sanctum',
      description:
          'Uncharted crystal chambers pulsing with intense energy deep beneath Cerulean City.',
      arrivalNarration:
          'Violet-cyan crystals illuminate the mist-filled abyss of Cerulean Cave. An overwhelming psychic aura stirs nearby...',
      legendarySpeciesId: 150, // Mewtwo
      accentColor: Color(0xFFCE93D8),
      backgroundAsset: 'assets/images/battle_bg_cerulean_cave.png',
      wildSpeciesPool: [
        42, 49, 55, 65, 80, 82, 94, 97, 101, 105, 112, 113, 121, 123, 124, 125,
        126, 127, 130, 149, 176,
      ],
    ),
  ];

  static const List<ExpeditionDestination> johtoDestinations = [
    ExpeditionDestination(
      id: 'burned_tower_raikou',
      name: 'Burned Tower • Storm Spire',
      subtitle: 'Thunder-Scarred Ruin',
      description:
          'The lightning-struck upper beams of Burned Tower in Ecruteak, humming with volatile static.',
      arrivalNarration:
          'Crackling sparks dance across charred timber beams as thunder rumbles above Burned Tower...',
      legendarySpeciesId: 243, // Raikou
      accentColor: Color(0xFFFFD54F),
      backgroundAsset: 'assets/images/battle_bg_burned_tower.png',
      wildSpeciesPool: [
        82, 94, 101, 125, 135, 169, 176, 181, 198, 200, 229,
      ],
    ),
    ExpeditionDestination(
      id: 'burned_tower_entei',
      name: 'Burned Tower • Ember Vault',
      subtitle: 'Smoldering Ash Basalt',
      description:
          'Deep volcanic fissures beneath Burned Tower where glowing embers never quite go cold.',
      arrivalNarration:
          'Warm volcanic embers drift upward through scorched stone vaults deep beneath Burned Tower...',
      legendarySpeciesId: 244, // Entei
      accentColor: Color(0xFFFF7043),
      backgroundAsset: 'assets/images/battle_bg_burned_tower.png',
      wildSpeciesPool: [
        38, 59, 78, 110, 126, 169, 176, 208, 219, 229, 247,
      ],
    ),
    ExpeditionDestination(
      id: 'burned_tower_suicune',
      name: 'Burned Tower • Mist Sanctum',
      subtitle: 'Purifying North-Wind Shrine',
      description:
          'Rain-washed flagstones in Ecruteak where cool northern winds clear away lingering smoke.',
      arrivalNarration:
          'A sudden northern breeze sweeps crystalline mist across the quiet courtyard of Burned Tower...',
      legendarySpeciesId: 245, // Suicune
      accentColor: Color(0xFF4FC3F7),
      backgroundAsset: 'assets/images/battle_bg_burned_tower.png',
      wildSpeciesPool: [
        55, 62, 131, 134, 176, 184, 186, 199, 215, 221, 224,
      ],
    ),
    ExpeditionDestination(
      id: 'whirl_islands',
      name: 'Whirl Islands',
      subtitle: 'Abyssal Sea Cavern',
      description:
          'Labyrinthine tidal caves off Cianwood City roaring with underground waterfalls.',
      arrivalNarration:
          'Thunderous waterfalls echo off wet slate walls inside the Whirl Islands as silver feathers glint in the mist...',
      legendarySpeciesId: 249, // Lugia
      accentColor: Color(0xFF5C6BC0),
      backgroundAsset: 'assets/images/battle_bg_whirl_islands.png',
      wildSpeciesPool: [
        73, 87, 91, 99, 117, 121, 130, 131, 171, 176, 199, 222, 226, 230,
      ],
    ),
    ExpeditionDestination(
      id: 'bell_tower',
      name: 'Bell Tower',
      subtitle: 'Rainbow Pagoda Summit',
      description:
          'Ecruteak\'s towering crimson pagoda reaching above autumn clouds toward the sacred rainbow.',
      arrivalNarration:
          'Crimson eaves gleam beneath sunset clouds atop Bell Tower as a sacred chime rings across Johto...',
      legendarySpeciesId: 250, // Ho-Oh
      accentColor: Color(0xFFFFB300),
      backgroundAsset: 'assets/images/battle_bg_bell_tower.png',
      wildSpeciesPool: [
        164, 169, 176, 178, 196, 197, 200, 212, 214, 227, 233, 241, 248,
      ],
    ),
  ];

  static List<ExpeditionDestination> destinationsForRegion(GameRegion region) {
    return region == GameRegion.johto ? johtoDestinations : destinations;
  }

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

  static const List<int> _neoRocketGruntPool = [
    20, // Raticate
    24, // Arbok
    89, // Muk
    110, // Weezing
    168, // Ariados
    169, // Crobat
    198, // Murkrow
    205, // Forretress
    208, // Steelix
    215, // Sneasel
    217, // Ursaring
    229, // Houndoom
  ];

  /// Generates 1 of the 3 strong wild Pokémon (Lv. 99), respecting
  /// the player's current game version exclusives.
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
    const int level = 99;
    final bool isShiny = PokedexDatabase.rollShiny(species);
    return PokedexDatabase.createPokemon(
      chosenId,
      level: level,
      isShiny: isShiny,
      respectMinEncounterLevel: false,
      eggMoveChance: 0.30,
      rng: random,
    );
  }

  /// Generates the Team Rocket ambush challenger at Lv. 99:
  /// - Kanto: 10% Jessie & James (2v2 Double Battle), 90% Rocket Grunt (Singles)
  /// - Johto: 15% Archer & Ariana (2v2 Executive Duo), 18% Executive Proton,
  ///          17% Executive Petrel, 50% Neo Rocket Grunt
  static RocketChallenger generateRocketChallenger({
    GameRegion region = GameRegion.kanto,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final double roll = random.nextDouble();
    const List<int> levels = [99, 99, 99, 99, 99, 99];

    if (region == GameRegion.johto) {
      if (roll < 0.15) {
        // Neo Team Rocket Top Executives 2v2 Double Battle
        const ids = [229, 198, 169, 24, 45, 248];
        final team = [
          for (int i = 0; i < 6; i++)
            PokedexDatabase.createPokemon(
              ids[i],
              level: levels[i],
              respectMinEncounterLevel: false,
              hiddenAbilityChance: 0.14,
              rng: random,
            ),
        ];
        return RocketChallenger(
          name: 'Archer & Ariana',
          title: 'Neo Team Rocket Executives',
          spriteId: 'rocket_archer',
          partnerSpriteId: 'rocket_ariana',
          isJessieOrJames: true,
          isDoubleBattle: true,
          introDialogue:
              "Archer: Neo Team Rocket rises again! Ariana: No challenger will interfere with our legendary awakening!",
          defeatDialogue:
              "Archer & Ariana: Impossible! Giovanni's legacy cannot end like this!",
          prizeMoney: 10000,
          team: team,
        );
      }

      if (roll < 0.33) {
        const ids = [169, 110, 229, 212, 89, 208];
        final team = [
          for (int i = 0; i < 6; i++)
            PokedexDatabase.createPokemon(
              ids[i],
              level: levels[i],
              respectMinEncounterLevel: false,
              hiddenAbilityChance: 0.10,
              rng: random,
            ),
        ];
        return RocketChallenger(
          name: 'Executive Proton',
          title: 'Neo Team Rocket Executive',
          spriteId: 'rocket_proton',
          isJessieOrJames: false,
          introDialogue:
              "Heh! Executive Proton here. I'm the coldest commander in Neo Team Rocket—say goodbye to your streak!",
          defeatDialogue:
              "Tch! You actually overpowered my Golbat and Steelix squad!",
          prizeMoney: 8000,
          team: team,
        );
      }

      if (roll < 0.50) {
        const ids = [110, 20, 24, 169, 101, 215];
        final team = [
          for (int i = 0; i < 6; i++)
            PokedexDatabase.createPokemon(
              ids[i],
              level: levels[i],
              respectMinEncounterLevel: false,
              hiddenAbilityChance: 0.10,
              rng: random,
            ),
        ];
        return RocketChallenger(
          name: 'Executive Petrel',
          title: 'Master of Disguise • Rocket Executive',
          spriteId: 'rocket_petrel',
          isJessieOrJames: false,
          introDialogue:
              "Surprise! Executive Petrel! Thought you slipped past Neo Team Rocket? Enjoy my explosion trap!",
          defeatDialogue:
              "Ack! Foiled again! Archer isn't going to like this report!",
          prizeMoney: 8000,
          team: team,
        );
      }

      final pool = List<int>.from(_neoRocketGruntPool)..shuffle(random);
      final team = [
        for (int i = 0; i < 6; i++)
          PokedexDatabase.createPokemon(
            pool[i % pool.length],
            level: levels[i],
            respectMinEncounterLevel: false,
            rng: random,
          ),
      ];
      return RocketChallenger(
        name: 'Neo Rocket Grunt',
        title: 'Neo Team Rocket Raider',
        spriteId: 'rocket_grunt',
        isJessieOrJames: false,
        introDialogue:
            "Hold it right there! Neo Team Rocket has sealed off this Johto sanctum on Executive orders!",
        defeatDialogue:
            "Urk! Wait till Executives Proton and Archer hear about this!",
        prizeMoney: 6000,
        team: team,
      );
    }

    if (roll < 0.10) {
      // Kanto Tag-team 2v2 Double Battle: Arbok & Weezing lead, backed by Lickitung, Victreebel, Gyarados, Persian
      const ids = [24, 110, 108, 71, 130, 53];
      final team = [
        for (int i = 0; i < 6; i++)
          PokedexDatabase.createPokemon(
            ids[i],
            level: levels[i],
            respectMinEncounterLevel: false,
            hiddenAbilityChance: 0.12,
            rng: random,
          ),
      ];
      return RocketChallenger(
        name: 'Jessie & James',
        title: 'Team Rocket Duo',
        spriteId: 'rocket_jessie',
        partnerSpriteId: 'rocket_james',
        isJessieOrJames: true,
        isDoubleBattle: true,
        introDialogue:
            "Jessie: Prepare for trouble! James: And make it double! Hand over your rarest Pokémon!",
        defeatDialogue:
            "Jessie & James: No way! Looks like Team Rocket's blasting off again!",
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
          rng: random,
        ),
    ];
    return RocketChallenger(
      name: 'Rocket Grunt',
      title: 'Team Rocket Raider',
      spriteId: 'rocket_grunt',
      isJessieOrJames: false,
      introDialogue:
          "Hold it! Team Rocket spotted a legendary energy spike here—no intruders allowed!",
      defeatDialogue:
          "Tch! Wait till the boss hears about a trainer this strong!",
      prizeMoney: 6000,
      team: team,
    );
  }

  /// Rolls whether the region's hidden Mythical (Mew in Kanto, Celebi in any Johto Expedition, 0.01%)
  /// or the destination's Legendary (5%) appears at Lv. 99 after Team Rocket is defeated.
  /// Caught species never reappear.
  static PokemonInstance? rollPostRocketBoss({
    required ExpeditionDestination destination,
    required Trainer trainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final int mythicalId = trainer.activeRegion == GameRegion.johto
        ? celebiSpeciesId
        : mewSpeciesId;
    final bool caughtMythical = trainer.hasCaughtExpeditionSpecies(mythicalId);
    final bool caughtDest =
        trainer.hasCaughtExpeditionSpecies(destination.legendarySpeciesId);

    if (!caughtMythical && random.nextDouble() < 0.0001) {
      final spec = PokedexDatabase.species[mythicalId];
      return PokedexDatabase.createPokemon(
        mythicalId,
        level: 99,
        respectMinEncounterLevel: false,
        isShiny: spec != null && PokedexDatabase.rollShiny(spec),
        hiddenAbilityChance: 0.15,
        rng: random,
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
        rng: random,
      );
    }
    return null;
  }
}
