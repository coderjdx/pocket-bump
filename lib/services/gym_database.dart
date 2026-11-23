import 'dart:math';
import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import 'pokedex_database.dart';

class GymPokemonSpec {
  final int speciesId;
  final int level;
  final List<String>? moveIds;
  final String? heldItemId;

  const GymPokemonSpec({
    required this.speciesId,
    required this.level,
    this.moveIds,
    this.heldItemId,
  });

  PokemonInstance createInstance({double hiddenAbilityChance = 0.05}) {
    final species = PokedexDatabase.species[speciesId] ?? PokedexDatabase.species[1]!;
    final moves = (moveIds != null && moveIds!.isNotEmpty)
        ? moveIds!
            .map((id) => PokedexDatabase.moves[id]?.copy())
            .whereType<Move>()
            .toList()
        : PokedexDatabase.movesForSpeciesAtLevel(species, level);
    final String ballId =
        level >= 35 ? 'ultra_ball' : (level >= 20 ? 'great_ball' : 'poke_ball');
    final rolled = PokedexDatabase.rollAbility(
      species,
      hiddenAbilityChance: hiddenAbilityChance,
    );
    return PokemonInstance(
      species: species,
      level: level,
      moves: moves,
      heldItemId: heldItemId,
      caughtBall: ballId,
      abilityId: rolled.id,
      abilitySlot: rolled.slot,
    );
  }
}

class GymTrainer {
  final String id;
  final String name;
  final String title;
  final String spriteId;
  final int prizeMoney;
  final String introDialogue;
  final List<GymPokemonSpec> team;

  const GymTrainer({
    required this.id,
    required this.name,
    required this.title,
    this.spriteId = 'npc_camper',
    required this.prizeMoney,
    required this.introDialogue,
    required this.team,
  });
}

class GymDefinition {
  final int id;
  final String name;
  final String city;
  final String leaderName;
  final String leaderTitle;
  final String badgeName;
  final String badgeAsset;
  final String badgeDescription;
  final String element;
  final Color elementColor;
  final String backgroundAsset;
  final int requiredCaught;
  final int requiredSteps;
  final String signatureHeldItemDrop;
  final String signatureStoneDrop;
  final List<String> tmDrops;
  final List<int> rematchTrainerSpeciesIds;
  final List<GymPokemonSpec> rematchLeaderSpecs;
  final List<GymTrainer> trainers; // 4 Junior Gym Trainers
  final GymTrainer leader; // The Gym Leader

  const GymDefinition({
    required this.id,
    required this.name,
    required this.city,
    required this.leaderName,
    required this.leaderTitle,
    required this.badgeName,
    required this.badgeAsset,
    required this.badgeDescription,
    required this.element,
    required this.elementColor,
    required this.backgroundAsset,
    required this.requiredCaught,
    required this.requiredSteps,
    required this.signatureHeldItemDrop,
    required this.signatureStoneDrop,
    required this.tmDrops,
    required this.rematchTrainerSpeciesIds,
    required this.rematchLeaderSpecs,
    required this.trainers,
    required this.leader,
  });

  List<GymTrainer> get fullGauntlet => [...trainers, leader];
}

class GymDatabase {
  static final List<GymDefinition> gyms = [
    // === 1. PEWTER GYM (Brock) ===
    GymDefinition(
      id: 1,
      name: "Pewter Gym",
      city: "Pewter City",
      leaderName: "Brock",
      leaderTitle: "The Rock-Solid Pokémon Trainer",
      badgeName: "Boulder Badge",
      badgeAsset: 'assets/images/badges/boulder_badge.png',
      badgeDescription: "+10% Phys ATK • Commands Pokémon up to Lv. 25",
      element: "Rock",
      elementColor: const Color(0xFFBCAAA4),
      backgroundAsset: 'assets/images/battle_bg_gym_rock.png',
      requiredCaught: 10,
      requiredSteps: 2000,
      signatureHeldItemDrop: 'hard_stone',
      signatureStoneDrop: 'moon_stone',
      tmDrops: const ['tm_34', 'tm_48', 'tm_28', 'tm_08', 'tm_09', 'tm_20'],
      rematchTrainerSpeciesIds: const [74, 75, 76, 95, 111, 27, 28, 138, 140],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 76,
          level: 50,
          moveIds: ['earthquake', 'rock_slide', 'explosion', 'body_slam'],
          heldItemId: 'hard_stone',
        ),
        GymPokemonSpec(
          speciesId: 95,
          level: 50,
          moveIds: ['earthquake', 'rock_slide', 'iron_head', 'toxic'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 139,
          level: 50,
          moveIds: ['hydro_pump', 'ice_beam', 'rock_slide', 'ancient_power'],
          heldItemId: 'mystic_water',
        ),
        GymPokemonSpec(
          speciesId: 141,
          level: 50,
          moveIds: ['waterfall', 'rock_slide', 'slash', 'swords_dance'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 142,
          level: 50,
          moveIds: ['sky_attack', 'rock_slide', 'earthquake', 'hyper_beam'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 112,
          level: 50,
          moveIds: ['earthquake', 'rock_slide', 'body_slam', 'fissure'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'pewter_t1',
          spriteId: 'npc_camper',
          name: 'Camper Liam',
          title: 'Gym Junior Trainer',
          prizeMoney: 400,
          introDialogue: "Stop right there! You're ten thousand light-years from facing Brock!",
          team: [
            GymPokemonSpec(speciesId: 27, level: 19), // Sandshrew
            GymPokemonSpec(speciesId: 74, level: 21), // Geodude
          ],
        ),
        const GymTrainer(
          id: 'pewter_t2',
          spriteId: 'npc_hiker',
          name: 'Hiker Anthony',
          title: 'Mountain Man',
          prizeMoney: 500,
          introDialogue: "My rock Pokémon have high defense! Can you scratch them?",
          team: [
            GymPokemonSpec(speciesId: 111, level: 19), // Rhyhorn
            GymPokemonSpec(speciesId: 140, level: 20), // Kabuto
            GymPokemonSpec(speciesId: 74, level: 21), // Geodude
          ],
        ),
        const GymTrainer(
          id: 'pewter_t3',
          spriteId: 'npc_lass',
          name: 'Picnicker Diana',
          title: 'Gym Trainer',
          prizeMoney: 600,
          introDialogue: "Watch out for sand attack! My Sandshrew and Sandslash are super swift!",
          team: [
            GymPokemonSpec(speciesId: 50, level: 18), // Diglett
            GymPokemonSpec(speciesId: 138, level: 19), // Omanyte
            GymPokemonSpec(speciesId: 27, level: 21), // Sandshrew
            GymPokemonSpec(speciesId: 28, level: 22), // Sandslash
          ],
        ),
        const GymTrainer(
          id: 'pewter_t4',
          spriteId: 'npc_camper',
          name: 'Jr. Trainer Jerry',
          title: 'Brock\'s Apprentice',
          prizeMoney: 750,
          introDialogue: "If you can't beat me, you'll never survive Brock's Onix!",
          team: [
            GymPokemonSpec(speciesId: 104, level: 18), // Cubone
            GymPokemonSpec(speciesId: 140, level: 19), // Kabuto
            GymPokemonSpec(speciesId: 111, level: 20), // Rhyhorn
            GymPokemonSpec(speciesId: 50, level: 21), // Diglett
            GymPokemonSpec(speciesId: 74, level: 22), // Geodude
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'brock',
        spriteId: 'leader_brock',
        name: 'Brock',
        title: 'Pewter Gym Leader',
        prizeMoney: 2400,
        introDialogue: "I'm Brock! I'm Pewter's Gym Leader! My rock-hard willpower is evident even in my Pokémon!",
        team: [
          GymPokemonSpec(speciesId: 27, level: 17), // Sandshrew
          GymPokemonSpec(speciesId: 140, level: 18), // Kabuto
          GymPokemonSpec(speciesId: 138, level: 19), // Omanyte
          GymPokemonSpec(speciesId: 111, level: 20), // Rhyhorn
          GymPokemonSpec(speciesId: 74, level: 22), // Geodude
          GymPokemonSpec(speciesId: 95, level: 24), // Onix
        ],
      ),
    ),

    // === 2. CERULEAN GYM (Misty) ===
    GymDefinition(
      id: 2,
      name: "Cerulean Gym",
      city: "Cerulean City",
      leaderName: "Misty",
      leaderTitle: "The Tomboyish Mermaid",
      badgeName: "Cascade Badge",
      badgeAsset: 'assets/images/badges/cascade_badge.png',
      badgeDescription: "+10% Spec ATK • Commands Pokémon up to Lv. 34",
      element: "Water",
      elementColor: const Color(0xFF4FC3F7),
      backgroundAsset: 'assets/images/battle_bg_gym_water.png',
      requiredCaught: 18,
      requiredSteps: 4000,
      signatureHeldItemDrop: 'mystic_water',
      signatureStoneDrop: 'water_stone',
      tmDrops: const ['tm_11', 'tm_12', 'tm_13', 'tm_14', 'tm_33', 'tm_39'],
      rematchTrainerSpeciesIds: const [118, 119, 116, 117, 60, 61, 90, 91, 120, 54, 55],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 55,
          level: 50,
          moveIds: ['hydro_pump', 'psychic', 'ice_beam', 'zen_headbutt'],
          heldItemId: 'mystic_water',
        ),
        GymPokemonSpec(
          speciesId: 62,
          level: 50,
          moveIds: ['waterfall', 'submission', 'ice_punch', 'body_slam'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 91,
          level: 50,
          moveIds: ['ice_beam', 'blizzard', 'hydro_pump', 'spike_cannon'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 134,
          level: 50,
          moveIds: ['surf', 'ice_beam', 'acid_armor', 'shadow_ball'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 131,
          level: 50,
          moveIds: ['surf', 'ice_beam', 'thunderbolt', 'body_slam'],
          heldItemId: 'leftovers',
        ),
        GymPokemonSpec(
          speciesId: 121,
          level: 50,
          moveIds: ['hydro_pump', 'psychic', 'thunderbolt', 'ice_beam'],
          heldItemId: 'mystic_water',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'cerulean_t1',
          spriteId: 'npc_swimmer',
          name: 'Swimmer Luis',
          title: 'Poolside Athlete',
          prizeMoney: 650,
          introDialogue: "Splash! Let's see if your team knows how to swim!",
          team: [
            GymPokemonSpec(speciesId: 116, level: 24), // Horsea
            GymPokemonSpec(speciesId: 118, level: 26), // Goldeen
          ],
        ),
        const GymTrainer(
          id: 'cerulean_t2',
          spriteId: 'npc_swimmer',
          name: 'Sailor Trevor',
          title: 'Ocean Sailor',
          prizeMoney: 800,
          introDialogue: "Anchors aweigh! My water partners won't take it easy on you!",
          team: [
            GymPokemonSpec(speciesId: 72, level: 24), // Tentacool
            GymPokemonSpec(speciesId: 116, level: 25), // Horsea
            GymPokemonSpec(speciesId: 90, level: 26), // Shellder
          ],
        ),
        const GymTrainer(
          id: 'cerulean_t3',
          spriteId: 'npc_lass',
          name: 'Picnicker Diana',
          title: 'Cerulean Swimmer',
          prizeMoney: 950,
          introDialogue: "My Water Pokémon will wash you right out of our gym pool!",
          team: [
            GymPokemonSpec(speciesId: 54, level: 23), // Psyduck
            GymPokemonSpec(speciesId: 98, level: 24), // Krabby
            GymPokemonSpec(speciesId: 60, level: 26), // Poliwag
            GymPokemonSpec(speciesId: 61, level: 27), // Poliwhirl
          ],
        ),
        const GymTrainer(
          id: 'cerulean_t4',
          spriteId: 'npc_beauty',
          name: 'Beauty Violet',
          title: 'Gym Sensational Sister',
          prizeMoney: 1100,
          introDialogue: "Misty is tough, but you'll have to get past our synchronized defense first!",
          team: [
            GymPokemonSpec(speciesId: 116, level: 23), // Horsea
            GymPokemonSpec(speciesId: 86, level: 24), // Seel
            GymPokemonSpec(speciesId: 61, level: 25), // Poliwhirl
            GymPokemonSpec(speciesId: 118, level: 26), // Goldeen
            GymPokemonSpec(speciesId: 120, level: 27), // Staryu
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'misty',
        spriteId: 'leader_misty',
        name: 'Misty',
        title: 'Cerulean Gym Leader',
        prizeMoney: 3200,
        introDialogue: "Hi, you're a new face! Only trainers with true policy and skill can win against my Water Pokémon!",
        team: [
          GymPokemonSpec(speciesId: 118, level: 22), // Goldeen
          GymPokemonSpec(speciesId: 54, level: 23), // Psyduck
          GymPokemonSpec(speciesId: 86, level: 24), // Seel
          GymPokemonSpec(speciesId: 61, level: 25), // Poliwhirl
          GymPokemonSpec(speciesId: 120, level: 27), // Staryu
          GymPokemonSpec(speciesId: 121, level: 29), // Starmie
        ],
      ),
    ),

    // === 3. VERMILION GYM (Lt. Surge) ===
    GymDefinition(
      id: 3,
      name: "Vermilion Gym",
      city: "Vermilion City",
      leaderName: "Lt. Surge",
      leaderTitle: "The Lightning American",
      badgeName: "Thunder Badge",
      badgeAsset: 'assets/images/badges/thunder_badge.png',
      badgeDescription: "+10% Speed • Commands Pokémon up to Lv. 42",
      element: "Electric",
      elementColor: const Color(0xFFFFD54F),
      backgroundAsset: 'assets/images/battle_bg_gym_electric.png',
      requiredCaught: 28,
      requiredSteps: 6000,
      signatureHeldItemDrop: 'magnet',
      signatureStoneDrop: 'thunder_stone',
      tmDrops: const ['tm_24', 'tm_25', 'tm_45', 'tm_01', 'tm_05', 'tm_49', 'tm_16'],
      rematchTrainerSpeciesIds: const [25, 26, 81, 82, 100, 101, 125, 135],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 101,
          level: 50,
          moveIds: ['thunderbolt', 'thunder_wave', 'explosion', 'swift'],
          heldItemId: 'magnet',
        ),
        GymPokemonSpec(
          speciesId: 82,
          level: 50,
          moveIds: ['thunderbolt', 'flash_cannon', 'tri_attack', 'reflect'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 135,
          level: 50,
          moveIds: ['thunderbolt', 'pin_missile', 'double_kick', 'quick_attack'],
          heldItemId: 'magnet',
        ),
        GymPokemonSpec(
          speciesId: 125,
          level: 50,
          moveIds: ['thunder_punch', 'thunderbolt', 'psychic', 'ice_punch'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 137,
          level: 50,
          moveIds: ['tri_attack', 'thunderbolt', 'ice_beam', 'recover'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 26,
          level: 50,
          moveIds: ['thunder', 'thunderbolt', 'mega_kick', 'body_slam'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'vermilion_t1',
          spriteId: 'npc_swimmer',
          name: 'Sailor Dwayne',
          title: 'Naval Recruit',
          prizeMoney: 1000,
          introDialogue: "Lt. Surge taught me the shock-and-awe combat doctrine!",
          team: [
            GymPokemonSpec(speciesId: 125, level: 33), // Electabuzz
            GymPokemonSpec(speciesId: 25, level: 35), // Pikachu
          ],
        ),
        const GymTrainer(
          id: 'vermilion_t2',
          spriteId: 'npc_engineer',
          name: 'Engineer Baily',
          title: 'Power Plant Tech',
          prizeMoney: 1200,
          introDialogue: "High voltage warning! Magnemite and Magneton are fully charged!",
          team: [
            GymPokemonSpec(speciesId: 100, level: 33), // Voltorb
            GymPokemonSpec(speciesId: 81, level: 34), // Magnemite
            GymPokemonSpec(speciesId: 82, level: 35), // Magneton
          ],
        ),
        const GymTrainer(
          id: 'vermilion_t3',
          spriteId: 'npc_engineer',
          name: 'Gentleman Tucker',
          title: 'Army Veteran',
          prizeMoney: 1400,
          introDialogue: "War is rough, rookie! Prepare for rapid electric fire!",
          team: [
            GymPokemonSpec(speciesId: 125, level: 32), // Electabuzz
            GymPokemonSpec(speciesId: 25, level: 33), // Pikachu
            GymPokemonSpec(speciesId: 100, level: 35), // Voltorb
            GymPokemonSpec(speciesId: 101, level: 36), // Electrode
          ],
        ),
        const GymTrainer(
          id: 'vermilion_t4',
          spriteId: 'npc_camper',
          name: 'Rocker Gene',
          title: 'Sound & Surge',
          prizeMoney: 1650,
          introDialogue: "Can you hear that hum? It's the electric current ready to buzz you!",
          team: [
            GymPokemonSpec(speciesId: 100, level: 32), // Voltorb
            GymPokemonSpec(speciesId: 81, level: 33), // Magnemite
            GymPokemonSpec(speciesId: 135, level: 34), // Jolteon
            GymPokemonSpec(speciesId: 101, level: 35), // Electrode
            GymPokemonSpec(speciesId: 82, level: 36), // Magneton
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'lt_surge',
        spriteId: 'leader_surge',
        name: 'Lt. Surge',
        title: 'Vermilion Gym Leader',
        prizeMoney: 4200,
        introDialogue: "Ten-hut! You won't live long in combat with just guts! I tell you, electric Pokémon saved me during the war!",
        team: [
          GymPokemonSpec(speciesId: 100, level: 31), // Voltorb
          GymPokemonSpec(speciesId: 25, level: 32), // Pikachu
          GymPokemonSpec(speciesId: 82, level: 33), // Magneton
          GymPokemonSpec(speciesId: 125, level: 34), // Electabuzz
          GymPokemonSpec(speciesId: 101, level: 36), // Electrode
          GymPokemonSpec(speciesId: 26, level: 38), // Raichu
        ],
      ),
    ),

    // === 4. CELADON GYM (Erika) ===
    GymDefinition(
      id: 4,
      name: "Celadon Gym",
      city: "Celadon City",
      leaderName: "Erika",
      leaderTitle: "The Nature-Loving Princess",
      badgeName: "Rainbow Badge",
      badgeAsset: 'assets/images/badges/rainbow_badge.png',
      badgeDescription: "+10% Spec DEF • Commands Pokémon up to Lv. 50",
      element: "Grass",
      elementColor: const Color(0xFF81C784),
      backgroundAsset: 'assets/images/battle_bg_gym_grass.png',
      requiredCaught: 40,
      requiredSteps: 8000,
      signatureHeldItemDrop: 'miracle_seed',
      signatureStoneDrop: 'leaf_stone',
      tmDrops: const ['tm_21', 'tm_22', 'tm_03', 'tm_10', 'tm_32', 'tm_37', 'tm_41'],
      rematchTrainerSpeciesIds: const [43, 44, 45, 69, 70, 71, 1, 2, 102, 103, 114],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 114,
          level: 50,
          moveIds: ['giga_drain', 'sleep_powder', 'ancient_power', 'sludge_bomb'],
          heldItemId: 'miracle_seed',
        ),
        GymPokemonSpec(
          speciesId: 47,
          level: 50,
          moveIds: ['spore', 'x_scissor', 'seed_bomb', 'slash'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 71,
          level: 50,
          moveIds: ['razor_leaf', 'sludge_bomb', 'sleep_powder', 'swords_dance'],
          heldItemId: 'poison_barb',
        ),
        GymPokemonSpec(
          speciesId: 103,
          level: 50,
          moveIds: ['psychic', 'solar_beam', 'sleep_powder', 'egg_bomb'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 3,
          level: 50,
          moveIds: ['petal_blizzard', 'sludge_bomb', 'earthquake', 'sleep_powder'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 45,
          level: 50,
          moveIds: ['petal_blizzard', 'sludge_bomb', 'moonblast', 'giga_drain'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'celadon_t1',
          spriteId: 'npc_lass',
          name: 'Lass Kay',
          title: 'Flower Arranger',
          prizeMoney: 1350,
          introDialogue: "Welcome to our botanical paradise! Watch out for sweet scents!",
          team: [
            GymPokemonSpec(speciesId: 70, level: 41), // Weepinbell
            GymPokemonSpec(speciesId: 44, level: 43), // Gloom
          ],
        ),
        const GymTrainer(
          id: 'celadon_t2',
          spriteId: 'npc_beauty',
          name: 'Beauty Tamia',
          title: 'Floral Designer',
          prizeMoney: 1600,
          introDialogue: "Our petals hide sharp thorns and paralyzing spores!",
          team: [
            GymPokemonSpec(speciesId: 44, level: 41), // Gloom
            GymPokemonSpec(speciesId: 70, level: 42), // Weepinbell
            GymPokemonSpec(speciesId: 71, level: 43), // Victreebel
          ],
        ),
        const GymTrainer(
          id: 'celadon_t3',
          spriteId: 'npc_lass',
          name: 'Picnicker Tina',
          title: 'Nature Scout',
          prizeMoney: 1850,
          introDialogue: "My Bulbasaur line has blossomed under Erika's serene guidance!",
          team: [
            GymPokemonSpec(speciesId: 1, level: 40), // Bulbasaur
            GymPokemonSpec(speciesId: 2, level: 41), // Ivysaur
            GymPokemonSpec(speciesId: 103, level: 43), // Exeggutor
            GymPokemonSpec(speciesId: 3, level: 44), // Venusaur
          ],
        ),
        const GymTrainer(
          id: 'celadon_t4',
          spriteId: 'npc_beauty',
          name: 'Cooltrainer Mary',
          title: 'Celadon Elite',
          prizeMoney: 2150,
          introDialogue: "Only those who respect the delicate strength of flora may challenge the mistress!",
          team: [
            GymPokemonSpec(speciesId: 114, level: 40), // Tangela
            GymPokemonSpec(speciesId: 70, level: 41), // Weepinbell
            GymPokemonSpec(speciesId: 44, level: 42), // Gloom
            GymPokemonSpec(speciesId: 71, level: 43), // Victreebel
            GymPokemonSpec(speciesId: 45, level: 44), // Vileplume
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'erika',
        spriteId: 'leader_erika',
        name: 'Erika',
        title: 'Celadon Gym Leader',
        prizeMoney: 5400,
        introDialogue: "Hello... Lovely weather, isn't it? It's so pleasant. My name is Erika. I am the Leader of Celadon Gym.",
        team: [
          GymPokemonSpec(speciesId: 103, level: 39), // Exeggutor
          GymPokemonSpec(speciesId: 47, level: 40), // Parasect
          GymPokemonSpec(speciesId: 3, level: 41), // Venusaur
          GymPokemonSpec(speciesId: 114, level: 42), // Tangela
          GymPokemonSpec(speciesId: 71, level: 44), // Victreebel
          GymPokemonSpec(speciesId: 45, level: 46), // Vileplume
        ],
      ),
    ),

    // === 5. FUCHSIA GYM (Koga) ===
    GymDefinition(
      id: 5,
      name: "Fuchsia Gym",
      city: "Fuchsia City",
      leaderName: "Koga",
      leaderTitle: "The Poisonous Ninja Master",
      badgeName: "Soul Badge",
      badgeAsset: 'assets/images/badges/soul_badge.png',
      badgeDescription: "+10% Phys DEF • Commands Pokémon up to Lv. 60",
      element: "Poison",
      elementColor: const Color(0xFFBA68C8),
      backgroundAsset: 'assets/images/battle_bg_gym_poison.png',
      requiredCaught: 55,
      requiredSteps: 10000,
      signatureHeldItemDrop: 'poison_barb',
      signatureStoneDrop: 'fire_stone',
      tmDrops: const ['tm_06', 'tm_36', 'tm_47', 'tm_31', 'tm_40', 'tm_44'],
      rematchTrainerSpeciesIds: const [41, 42, 48, 49, 23, 24, 88, 89, 109, 110, 97, 73],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 42,
          level: 50,
          moveIds: ['wing_attack', 'poison_jab', 'confuse_ray', 'bite'],
          heldItemId: 'poison_barb',
        ),
        GymPokemonSpec(
          speciesId: 24,
          level: 50,
          moveIds: ['poison_jab', 'glare', 'earthquake', 'crunch'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 49,
          level: 50,
          moveIds: ['psychic', 'sludge_bomb', 'silver_wind', 'sleep_powder'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 73,
          level: 50,
          moveIds: ['surf', 'sludge_bomb', 'ice_beam', 'acid_armor'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 89,
          level: 50,
          moveIds: ['sludge_bomb', 'fire_punch', 'ice_punch', 'body_slam'],
          heldItemId: 'poison_barb',
        ),
        GymPokemonSpec(
          speciesId: 110,
          level: 50,
          moveIds: ['sludge_bomb', 'fire_blast', 'thunderbolt', 'explosion'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'fuchsia_t1',
          spriteId: 'npc_ninja',
          name: 'Juggler Kirk',
          title: 'Ninja Illusionist',
          prizeMoney: 1750,
          introDialogue: "Fwahaha! The invisible walls are just the first of my illusions!",
          team: [
            GymPokemonSpec(speciesId: 97, level: 49), // Hypno
            GymPokemonSpec(speciesId: 64, level: 51), // Kadabra
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t2',
          spriteId: 'npc_ninja',
          name: 'Tamer Edgar',
          title: 'Beast Ninja',
          prizeMoney: 2050,
          introDialogue: "Venom courses through my serpentine companions!",
          team: [
            GymPokemonSpec(speciesId: 34, level: 49), // Nidoking
            GymPokemonSpec(speciesId: 24, level: 50), // Arbok
            GymPokemonSpec(speciesId: 28, level: 51), // Sandslash
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t3',
          spriteId: 'npc_psychic',
          name: 'Juggler Shawn',
          title: 'Hypnotic Master',
          prizeMoney: 2350,
          introDialogue: "Can your mind resist sleep while toxins sap your vitality?",
          team: [
            GymPokemonSpec(speciesId: 42, level: 48), // Golbat
            GymPokemonSpec(speciesId: 96, level: 49), // Drowzee
            GymPokemonSpec(speciesId: 49, level: 51), // Venomoth
            GymPokemonSpec(speciesId: 97, level: 52), // Hypno
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t4',
          spriteId: 'npc_ninja',
          name: 'Ninja Boy Lao',
          title: 'Shadow Disciple',
          prizeMoney: 2700,
          introDialogue: "Koga's ninja techniques have been passed down for four centuries!",
          team: [
            GymPokemonSpec(speciesId: 109, level: 48), // Koffing
            GymPokemonSpec(speciesId: 88, level: 49), // Grimer
            GymPokemonSpec(speciesId: 73, level: 50), // Tentacruel
            GymPokemonSpec(speciesId: 89, level: 51), // Muk
            GymPokemonSpec(speciesId: 110, level: 52), // Weezing
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'koga',
        spriteId: 'leader_koga',
        name: 'Koga',
        title: 'Fuchsia Gym Leader',
        prizeMoney: 6800,
        introDialogue: "Fwahahaha! A mere child challenges me? Very well, despair before the creeping terror of poison and sleep!",
        team: [
          GymPokemonSpec(speciesId: 109, level: 47), // Koffing
          GymPokemonSpec(speciesId: 42, level: 48), // Golbat
          GymPokemonSpec(speciesId: 24, level: 49), // Arbok
          GymPokemonSpec(speciesId: 49, level: 50), // Venomoth
          GymPokemonSpec(speciesId: 89, level: 52), // Muk
          GymPokemonSpec(speciesId: 110, level: 54), // Weezing
        ],
      ),
    ),

    // === 6. SAFFRON GYM (Sabrina) ===
    GymDefinition(
      id: 6,
      name: "Saffron Gym",
      city: "Saffron City",
      leaderName: "Sabrina",
      leaderTitle: "The Master of Psychic Pokémon",
      badgeName: "Marsh Badge",
      badgeAsset: 'assets/images/badges/marsh_badge.png',
      badgeDescription: "+10% Max HP • Commands Pokémon up to Lv. 70",
      element: "Psychic",
      elementColor: const Color(0xFFFF80AB),
      backgroundAsset: 'assets/images/battle_bg_gym_psychic.png',
      requiredCaught: 70,
      requiredSteps: 12000,
      signatureHeldItemDrop: 'twisted_spoon',
      signatureStoneDrop: 'moon_stone',
      tmDrops: const ['tm_46', 'tm_29', 'tm_30', 'tm_35', 'tm_42', 'tm_50'],
      rematchTrainerSpeciesIds: const [63, 64, 65, 96, 97, 79, 80, 122, 124, 103, 93, 94],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 122,
          level: 50,
          moveIds: ['psychic', 'moonblast', 'thunderbolt', 'reflect'],
          heldItemId: 'twisted_spoon',
        ),
        GymPokemonSpec(
          speciesId: 97,
          level: 50,
          moveIds: ['psychic', 'hypnosis', 'dream_eater', 'shadow_ball'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 80,
          level: 50,
          moveIds: ['psychic', 'surf', 'ice_beam', 'fire_blast'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 124,
          level: 50,
          moveIds: ['ice_beam', 'psychic', 'shadow_ball', 'blizzard'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 94,
          level: 50,
          moveIds: ['shadow_ball', 'sludge_bomb', 'thunderbolt', 'hypnosis'],
          heldItemId: 'twisted_spoon',
        ),
        GymPokemonSpec(
          speciesId: 65,
          level: 50,
          moveIds: ['psychic', 'shadow_ball', 'recover', 'thunder_punch'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'saffron_t1',
          spriteId: 'npc_psychic',
          name: 'Psychic Johan',
          title: 'Telekinetic Adept',
          prizeMoney: 2200,
          introDialogue: "I can read your mind! You are wondering if you can defeat me!",
          team: [
            GymPokemonSpec(speciesId: 64, level: 59), // Kadabra
            GymPokemonSpec(speciesId: 122, level: 61), // Mr. Mime
          ],
        ),
        const GymTrainer(
          id: 'saffron_t2',
          spriteId: 'npc_beauty',
          name: 'Channeler Stacy',
          title: 'Medium of Spirits',
          prizeMoney: 2550,
          introDialogue: "The unseen realm bows to Sabrina's overwhelming psionic will!",
          team: [
            GymPokemonSpec(speciesId: 92, level: 59), // Gastly
            GymPokemonSpec(speciesId: 93, level: 60), // Haunter
            GymPokemonSpec(speciesId: 94, level: 61), // Gengar
          ],
        ),
        const GymTrainer(
          id: 'saffron_t3',
          spriteId: 'npc_psychic',
          name: 'Psychic Cameron',
          title: 'Mind Bender',
          prizeMoney: 2950,
          introDialogue: "Physical attacks cannot breach a focused telepathic mind!",
          team: [
            GymPokemonSpec(speciesId: 79, level: 58), // Slowpoke
            GymPokemonSpec(speciesId: 103, level: 59), // Exeggutor
            GymPokemonSpec(speciesId: 124, level: 61), // Jynx
            GymPokemonSpec(speciesId: 80, level: 62), // Slowbro
          ],
        ),
        const GymTrainer(
          id: 'saffron_t4',
          spriteId: 'npc_psychic',
          name: 'Psychic Preston',
          title: 'High Esper',
          prizeMoney: 3400,
          introDialogue: "Sabrina foresaw your arrival three days ago. Your defeat was also predicted!",
          team: [
            GymPokemonSpec(speciesId: 64, level: 58), // Kadabra
            GymPokemonSpec(speciesId: 97, level: 59), // Hypno
            GymPokemonSpec(speciesId: 103, level: 60), // Exeggutor
            GymPokemonSpec(speciesId: 124, level: 61), // Jynx
            GymPokemonSpec(speciesId: 80, level: 62), // Slowbro
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'sabrina',
        spriteId: 'leader_sabrina',
        name: 'Sabrina',
        title: 'Saffron Gym Leader',
        prizeMoney: 8200,
        introDialogue: "I had a vision of your arrival! I have had psychic powers since I was a child. I do not like to fight, but I will not lose!",
        team: [
          GymPokemonSpec(speciesId: 64, level: 57), // Kadabra
          GymPokemonSpec(speciesId: 80, level: 58), // Slowbro
          GymPokemonSpec(speciesId: 97, level: 59), // Hypno
          GymPokemonSpec(speciesId: 122, level: 60), // Mr. Mime
          GymPokemonSpec(speciesId: 49, level: 62), // Venomoth
          GymPokemonSpec(speciesId: 65, level: 64), // Alakazam
        ],
      ),
    ),

    // === 7. CINNABAR GYM (Blaine) ===
    GymDefinition(
      id: 7,
      name: "Cinnabar Gym",
      city: "Cinnabar Island",
      leaderName: "Blaine",
      leaderTitle: "The Hotheaded Quiz Master",
      badgeName: "Volcano Badge",
      badgeAsset: 'assets/images/badges/volcano_badge.png',
      badgeDescription: "+10% Critical Hit Rate • Commands Pokémon up to Lv. 82",
      element: "Fire",
      elementColor: const Color(0xFFFF7043),
      backgroundAsset: 'assets/images/battle_bg_gym_fire.png',
      requiredCaught: 85,
      requiredSteps: 15000,
      signatureHeldItemDrop: 'charcoal',
      signatureStoneDrop: 'fire_stone',
      tmDrops: const ['tm_38', 'tm_15', 'tm_17', 'tm_18', 'tm_19', 'tm_23'],
      rematchTrainerSpeciesIds: const [58, 59, 37, 38, 77, 78, 126, 4, 5, 6, 136],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 38,
          level: 50,
          moveIds: ['flamethrower', 'psychic', 'solar_beam', 'confuse_ray'],
          heldItemId: 'charcoal',
        ),
        GymPokemonSpec(
          speciesId: 78,
          level: 50,
          moveIds: ['fire_blast', 'drill_run', 'mega_kick', 'agility'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 136,
          level: 50,
          moveIds: ['fire_blast', 'body_slam', 'shadow_ball', 'quick_attack'],
          heldItemId: 'charcoal',
        ),
        GymPokemonSpec(
          speciesId: 6,
          level: 50,
          moveIds: ['fire_blast', 'air_slash', 'earthquake', 'dragon_claw'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 126,
          level: 50,
          moveIds: ['fire_blast', 'thunder_punch', 'psychic', 'cross_chop'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 59,
          level: 50,
          moveIds: ['fire_blast', 'extreme_speed', 'crunch', 'iron_head'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'cinnabar_t1',
          spriteId: 'npc_ninja',
          name: 'Burglar Quinn',
          title: 'Torchbearer',
          prizeMoney: 2700,
          introDialogue: "Quiz time! Does fire burn? You're about to find out first hand!",
          team: [
            GymPokemonSpec(speciesId: 58, level: 69), // Growlithe
            GymPokemonSpec(speciesId: 38, level: 71), // Ninetales
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t2',
          spriteId: 'npc_engineer',
          name: 'Super Nerd Erik',
          title: 'Thermodynamics Researcher',
          prizeMoney: 3100,
          introDialogue: "The combustion reaction in Ninetales' nine tails is mathematically sublime!",
          team: [
            GymPokemonSpec(speciesId: 37, level: 69), // Vulpix
            GymPokemonSpec(speciesId: 136, level: 70), // Flareon
            GymPokemonSpec(speciesId: 38, level: 71), // Ninetales
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t3',
          spriteId: 'npc_hiker',
          name: 'Burglar Ramon',
          title: 'Fire Thief',
          prizeMoney: 3600,
          introDialogue: "Can your Pokémon withstand a 10,000-degree blaze?",
          team: [
            GymPokemonSpec(speciesId: 77, level: 68), // Ponyta
            GymPokemonSpec(speciesId: 58, level: 69), // Growlithe
            GymPokemonSpec(speciesId: 6, level: 71), // Charizard
            GymPokemonSpec(speciesId: 78, level: 72), // Rapidash
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t4',
          spriteId: 'npc_engineer',
          name: 'Super Nerd Avery',
          title: 'Volcano Expert',
          prizeMoney: 4100,
          introDialogue: "Magmar's body burns brighter than magma! You better bring Burn Heal!",
          team: [
            GymPokemonSpec(speciesId: 38, level: 68), // Ninetales
            GymPokemonSpec(speciesId: 136, level: 69), // Flareon
            GymPokemonSpec(speciesId: 6, level: 70), // Charizard
            GymPokemonSpec(speciesId: 78, level: 71), // Rapidash
            GymPokemonSpec(speciesId: 126, level: 72), // Magmar
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'blaine',
        spriteId: 'leader_blaine',
        name: 'Blaine',
        title: 'Cinnabar Gym Leader',
        prizeMoney: 9800,
        introDialogue: "Hah! I am Blaine, the red-hot quiz master! My fiery Pokémon will incinerate all challengers! You better have Burn Heal ready!",
        team: [
          GymPokemonSpec(speciesId: 58, level: 67), // Growlithe
          GymPokemonSpec(speciesId: 77, level: 68), // Ponyta
          GymPokemonSpec(speciesId: 38, level: 69), // Ninetales
          GymPokemonSpec(speciesId: 126, level: 70), // Magmar
          GymPokemonSpec(speciesId: 78, level: 72), // Rapidash
          GymPokemonSpec(speciesId: 59, level: 74), // Arcanine
        ],
      ),
    ),

    // === 8. VIRIDIAN GYM (Giovanni) ===
    GymDefinition(
      id: 8,
      name: "Viridian Gym",
      city: "Viridian City",
      leaderName: "Giovanni",
      leaderTitle: "The Master of Earth & Legendary Boss",
      badgeName: "Earth Badge",
      badgeAsset: 'assets/images/badges/earth_badge.png',
      badgeDescription: "Master Boost (+5% All Stats) • Commands Lv. 100 • Unlocks Expeditions",
      element: "Ground",
      elementColor: const Color(0xFFFFB300),
      backgroundAsset: 'assets/images/battle_bg_gym_ground.png',
      requiredCaught: 100,
      requiredSteps: 20000,
      signatureHeldItemDrop: 'soft_sand',
      signatureStoneDrop: 'leftovers',
      tmDrops: const ['tm_27', 'tm_26', 'tm_07', 'tm_02', 'tm_04', 'tm_43'],
      rematchTrainerSpeciesIds: const [24, 28, 30, 31, 33, 34, 51, 67, 68, 75, 76, 111, 112, 128, 53],
      rematchLeaderSpecs: const [
        GymPokemonSpec(
          speciesId: 51,
          level: 50,
          moveIds: ['earthquake', 'rock_slide', 'slash', 'fissure'],
          heldItemId: 'soft_sand',
        ),
        GymPokemonSpec(
          speciesId: 53,
          level: 50,
          moveIds: ['slash', 'hyper_beam', 'thunderbolt', 'shadow_ball'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 31,
          level: 50,
          moveIds: ['earthquake', 'sludge_bomb', 'ice_beam', 'thunderbolt'],
          heldItemId: 'lum_berry',
        ),
        GymPokemonSpec(
          speciesId: 34,
          level: 50,
          moveIds: ['earthquake', 'sludge_bomb', 'fire_blast', 'rock_slide'],
          heldItemId: 'soft_sand',
        ),
        GymPokemonSpec(
          speciesId: 128,
          level: 50,
          moveIds: ['body_slam', 'earthquake', 'rock_slide', 'hyper_beam'],
          heldItemId: 'sitrus_berry',
        ),
        GymPokemonSpec(
          speciesId: 112,
          level: 50,
          moveIds: ['earthquake', 'rock_slide', 'double_edge', 'fissure'],
          heldItemId: 'leftovers',
        ),
      ],
      trainers: [
        const GymTrainer(
          id: 'viridian_t1',
          spriteId: 'npc_hiker',
          name: 'Tamer Cole',
          title: 'Beast Master',
          prizeMoney: 3300,
          introDialogue: "The Viridian Gym was closed for so long... Now only the elite may tread here!",
          team: [
            GymPokemonSpec(speciesId: 24, level: 81), // Arbok
            GymPokemonSpec(speciesId: 128, level: 83), // Tauros
          ],
        ),
        const GymTrainer(
          id: 'viridian_t2',
          spriteId: 'npc_ninja',
          name: 'Black Belt Takashi',
          title: 'Dojo Champion',
          prizeMoney: 3850,
          introDialogue: "Earth and martial arts unite! We will crush your defenses to gravel!",
          team: [
            GymPokemonSpec(speciesId: 67, level: 81), // Machoke
            GymPokemonSpec(speciesId: 57, level: 82), // Primeape
            GymPokemonSpec(speciesId: 68, level: 83), // Machamp
          ],
        ),
        const GymTrainer(
          id: 'viridian_t3',
          spriteId: 'npc_psychic',
          name: 'Cooltrainer Samuel',
          title: 'Gym Enforcer',
          prizeMoney: 4450,
          introDialogue: "Rhydon's armor cannot be pierced by ordinary strikes! Tremble!",
          team: [
            GymPokemonSpec(speciesId: 105, level: 80), // Marowak
            GymPokemonSpec(speciesId: 111, level: 81), // Rhyhorn
            GymPokemonSpec(speciesId: 28, level: 83), // Sandslash
            GymPokemonSpec(speciesId: 112, level: 84), // Rhydon
          ],
        ),
        const GymTrainer(
          id: 'viridian_t4',
          spriteId: 'npc_psychic',
          name: 'Cooltrainer Yuji',
          title: 'Giovanni\'s Right Hand',
          prizeMoney: 5100,
          introDialogue: "You stand before the gateway to the Pokémon League! Show me your absolute peak!",
          team: [
            GymPokemonSpec(speciesId: 33, level: 80), // Nidorino
            GymPokemonSpec(speciesId: 75, level: 81), // Graveler
            GymPokemonSpec(speciesId: 51, level: 82), // Dugtrio
            GymPokemonSpec(speciesId: 34, level: 83), // Nidoking
            GymPokemonSpec(speciesId: 76, level: 84), // Golem
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'giovanni',
        spriteId: 'leader_giovanni',
        name: 'Giovanni',
        title: 'Viridian Gym Leader',
        prizeMoney: 12000,
        introDialogue: "Fwahaha! Welcome to my hideout! It seems you've made quite a name for yourself. But this is the end of the line! Behold the ultimate power of Earth!",
        team: [
          GymPokemonSpec(speciesId: 111, level: 79), // Rhyhorn
          GymPokemonSpec(speciesId: 53, level: 80), // Persian
          GymPokemonSpec(speciesId: 51, level: 81), // Dugtrio
          GymPokemonSpec(speciesId: 31, level: 82), // Nidoqueen
          GymPokemonSpec(speciesId: 34, level: 84), // Nidoking
          GymPokemonSpec(speciesId: 112, level: 86), // Rhydon
        ],
      ),
    ),
  ];

  static final Random _rng = Random();

  static List<int> _levelsForAverage(int count, int targetAvg) {
    switch (count) {
      case 2:
        return [(targetAvg - 1).clamp(2, 100), (targetAvg + 1).clamp(2, 100)];
      case 3:
        return [
          (targetAvg - 1).clamp(2, 100),
          targetAvg.clamp(2, 100),
          (targetAvg + 1).clamp(2, 100),
        ];
      case 4:
        return [
          (targetAvg - 2).clamp(2, 100),
          (targetAvg - 1).clamp(2, 100),
          (targetAvg + 1).clamp(2, 100),
          (targetAvg + 2).clamp(2, 100),
        ];
      case 5:
        return [
          (targetAvg - 2).clamp(2, 100),
          (targetAvg - 1).clamp(2, 100),
          targetAvg.clamp(2, 100),
          (targetAvg + 1).clamp(2, 100),
          (targetAvg + 2).clamp(2, 100),
        ];
      default:
        return [
          (targetAvg - 2).clamp(2, 100),
          (targetAvg - 1).clamp(2, 100),
          targetAvg.clamp(2, 100),
          targetAvg.clamp(2, 100),
          (targetAvg + 1).clamp(2, 100),
          (targetAvg + 2).clamp(2, 100),
        ];
    }
  }

  static int _upgradeSpeciesForLevel(int speciesId, int lvl) {
    int current = speciesId;
    for (int guard = 0; guard < 3; guard++) {
      final spec = PokedexDatabase.species[current];
      if (spec == null || spec.evolutionSpeciesId == null) break;
      if (spec.evolutionLevel != null && lvl >= spec.evolutionLevel!) {
        current = spec.evolutionSpeciesId!;
      } else {
        break;
      }
    }
    return current;
  }

  /// Generates a scaled rematch gauntlet for a cleared [gym]:
  /// - Each of the 4 Gym Trainers has a random party size between 2 and 5.
  /// - The Gym Leader always fields a full team of 6 powerhouse Pokémon with coverage/TM moves & held items.
  /// - Every opponent's party average level is centered on [playerAvgLevel].
  static List<GymTrainer> buildRematchGauntlet(
    GymDefinition gym, {
    required double playerAvgLevel,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final int targetAvg = playerAvgLevel.round().clamp(5, 100);
    final List<GymTrainer> result = [];

    for (int tIdx = 0; tIdx < gym.trainers.length; tIdx++) {
      final baseTrainer = gym.trainers[tIdx];
      final int partyCount = 2 + random.nextInt(4); // 2..5 Pokémon
      final List<int> levels = _levelsForAverage(partyCount, targetAvg);

      final pool = List<int>.from(gym.rematchTrainerSpeciesIds)..shuffle(random);
      final List<GymPokemonSpec> team = [];
      for (int slot = 0; slot < partyCount; slot++) {
        final rawId = pool[slot % pool.length];
        final lvl = levels[slot];
        final evolvedId = _upgradeSpeciesForLevel(rawId, lvl);
        final String? item = (slot == partyCount - 1 && tIdx >= 1)
            ? (tIdx >= 3 ? 'sitrus_berry' : 'oran_berry')
            : null;
        team.add(GymPokemonSpec(
          speciesId: evolvedId,
          level: lvl,
          heldItemId: item,
        ));
      }

      final int scaledPrize =
          max(baseTrainer.prizeMoney, (baseTrainer.prizeMoney * (1.0 + targetAvg / 25.0)).round());
      result.add(GymTrainer(
        id: baseTrainer.id,
        name: baseTrainer.name,
        title: "${baseTrainer.title} (Rematch)",
        spriteId: baseTrainer.spriteId,
        prizeMoney: scaledPrize,
        introDialogue: baseTrainer.introDialogue,
        team: team,
      ));
    }

    // Gym Leader ALWAYS fields 6 Pokémon scaled symmetrically to playerAvgLevel.
    final leaderLevels = _levelsForAverage(6, targetAvg);
    final List<GymPokemonSpec> leaderTeam = [];
    for (int i = 0; i < 6; i++) {
      final template = gym.rematchLeaderSpecs[i % gym.rematchLeaderSpecs.length];
      leaderTeam.add(GymPokemonSpec(
        speciesId: template.speciesId,
        level: leaderLevels[i],
        moveIds: template.moveIds,
        heldItemId: template.heldItemId,
      ));
    }

    final int leaderPrize =
        max(gym.leader.prizeMoney, (gym.leader.prizeMoney * (1.0 + targetAvg / 18.0)).round());
    result.add(GymTrainer(
      id: gym.leader.id,
      name: gym.leader.name,
      title: "${gym.leader.title} (Rematch)",
      spriteId: gym.leader.spriteId,
      prizeMoney: leaderPrize,
      introDialogue: gym.leader.introDialogue,
      team: leaderTeam,
    ));

    return result;
  }

  static GymDefinition? getGymById(int id) {
    if (id < 1 || id > gyms.length) return null;
    return gyms[id - 1];
  }
}
