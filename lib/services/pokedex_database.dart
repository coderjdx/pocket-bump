import 'dart:math';
import '../models/move.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/pokemon_instance.dart';

class PokedexDatabase {
  static final Random _rng = Random();

  // ─── MOVES ─────────────────────────────────────────────────────────────
  static final Map<String, Move> moves = {
    // Normal
    'tackle': Move(
      id: 'tackle',
      name: 'Tackle',
      type: PokemonType.normal,
      category: MoveCategory.physical,
      power: 40,
      accuracy: 100,
      maxPp: 35,
      description: 'A physical charge attack.',
    ),
    'scratch': Move(
      id: 'scratch',
      name: 'Scratch',
      type: PokemonType.normal,
      category: MoveCategory.physical,
      power: 40,
      accuracy: 100,
      maxPp: 35,
      description: 'Hard, pointed, sharp claws rake the target.',
    ),
    'quick_attack': Move(
      id: 'quick_attack',
      name: 'Quick Attack',
      type: PokemonType.normal,
      category: MoveCategory.physical,
      power: 40,
      accuracy: 100,
      maxPp: 30,
      priority: 1,
      description: 'An almost invisibly fast strike with high priority.',
    ),
    'hyper_fang': Move(
      id: 'hyper_fang',
      name: 'Hyper Fang',
      type: PokemonType.normal,
      category: MoveCategory.physical,
      power: 80,
      accuracy: 90,
      maxPp: 15,
      description: 'Bites hard on the target with sharp front fangs.',
    ),
    'slash': Move(
      id: 'slash',
      name: 'Slash',
      type: PokemonType.normal,
      category: MoveCategory.physical,
      power: 70,
      accuracy: 100,
      maxPp: 20,
      description: 'The target is attacked with a slash of claws or blades.',
    ),
    'growl': Move(
      id: 'growl',
      name: 'Growl',
      type: PokemonType.normal,
      category: MoveCategory.status,
      power: 0,
      accuracy: 100,
      maxPp: 40,
      statTarget: 'atk',
      statChange: -1,
      description: 'Growls endearingly, lowering the target\'s Attack.',
    ),
    'tail_whip': Move(
      id: 'tail_whip',
      name: 'Tail Whip',
      type: PokemonType.normal,
      category: MoveCategory.status,
      power: 0,
      accuracy: 100,
      maxPp: 30,
      statTarget: 'def',
      statChange: -1,
      description: 'Wags its tail to lower the target\'s Defense.',
    ),
    'harden': Move(
      id: 'harden',
      name: 'Harden',
      type: PokemonType.normal,
      category: MoveCategory.status,
      power: 0,
      accuracy: 100,
      maxPp: 30,
      statTarget: 'def',
      statChange: 1,
      description: 'Stiffens all muscles to raise Defense.',
    ),
    'swords_dance': Move(
      id: 'swords_dance',
      name: 'Swords Dance',
      type: PokemonType.normal,
      category: MoveCategory.status,
      power: 0,
      accuracy: 100,
      maxPp: 20,
      statTarget: 'atk',
      statChange: 2,
      description: 'A frenetic dance that sharply raises Attack.',
    ),

    // Grass
    'vine_whip': Move(
      id: 'vine_whip',
      name: 'Vine Whip',
      type: PokemonType.grass,
      category: MoveCategory.physical,
      power: 45,
      accuracy: 100,
      maxPp: 25,
      description: 'The target is struck with slender, whiplike vines.',
    ),
    'razor_leaf': Move(
      id: 'razor_leaf',
      name: 'Razor Leaf',
      type: PokemonType.grass,
      category: MoveCategory.physical,
      power: 55,
      accuracy: 95,
      maxPp: 25,
      description: 'Sharp-edged leaves are launched to slice the target.',
    ),
    'solar_beam': Move(
      id: 'solar_beam',
      name: 'Solar Beam',
      type: PokemonType.grass,
      category: MoveCategory.special,
      power: 120,
      accuracy: 100,
      maxPp: 10,
      description: 'A powerful blast of concentrated solar light.',
    ),
    'sleep_powder': Move(
      id: 'sleep_powder',
      name: 'Sleep Powder',
      type: PokemonType.grass,
      category: MoveCategory.status,
      power: 0,
      accuracy: 75,
      maxPp: 15,
      statusEffect: 'sleep',
      statusChance: 100,
      description: 'Scatters a big cloud of sleep-inducing dust.',
    ),

    // Fire
    'ember': Move(
      id: 'ember',
      name: 'Ember',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 25,
      statusEffect: 'burn',
      statusChance: 10,
      description: 'Small flames that may inflict a burn.',
    ),
    'fire_fang': Move(
      id: 'fire_fang',
      name: 'Fire Fang',
      type: PokemonType.fire,
      category: MoveCategory.physical,
      power: 65,
      accuracy: 95,
      maxPp: 15,
      statusEffect: 'burn',
      statusChance: 20,
      description: 'Bites with flame-cloaked fangs; may cause a burn.',
    ),
    'flamethrower': Move(
      id: 'flamethrower',
      name: 'Flamethrower',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      statusEffect: 'burn',
      statusChance: 15,
      description: 'Scorches the target with an intense blast of fire.',
    ),
    'fire_blast': Move(
      id: 'fire_blast',
      name: 'Fire Blast',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 110,
      accuracy: 85,
      maxPp: 5,
      statusEffect: 'burn',
      statusChance: 20,
      description: 'An intense blast of all-consuming fire.',
    ),

    // Water
    'water_gun': Move(
      id: 'water_gun',
      name: 'Water Gun',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 25,
      description: 'Blasts the target with a forceful shot of water.',
    ),
    'water_pulse': Move(
      id: 'water_pulse',
      name: 'Water Pulse',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 60,
      accuracy: 100,
      maxPp: 20,
      description: 'Attacks the target with a pulsing blast of water.',
    ),
    'surf': Move(
      id: 'surf',
      name: 'Surf',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      description: 'Swamps the battlefield with a giant wave.',
    ),
    'hydro_pump': Move(
      id: 'hydro_pump',
      name: 'Hydro Pump',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 110,
      accuracy: 80,
      maxPp: 5,
      description: 'Blasts the target with high-pressure water.',
    ),

    // Bug
    'string_shot': Move(
      id: 'string_shot',
      name: 'String Shot',
      type: PokemonType.bug,
      category: MoveCategory.status,
      power: 0,
      accuracy: 95,
      maxPp: 40,
      statTarget: 'spe',
      statChange: -1,
      description: 'Binds the target with silk, lowering its Speed.',
    ),
    'bug_bite': Move(
      id: 'bug_bite',
      name: 'Bug Bite',
      type: PokemonType.bug,
      category: MoveCategory.physical,
      power: 60,
      accuracy: 100,
      maxPp: 20,
      description: 'The user bites the target forcefully.',
    ),
    'twinneedle': Move(
      id: 'twinneedle',
      name: 'Twineedle',
      type: PokemonType.bug,
      category: MoveCategory.physical,
      power: 50,
      accuracy: 100,
      maxPp: 20,
      statusEffect: 'poison',
      statusChance: 20,
      description: 'Jabs the target with twin stingers; may poison.',
    ),
    'silver_wind': Move(
      id: 'silver_wind',
      name: 'Silver Wind',
      type: PokemonType.bug,
      category: MoveCategory.special,
      power: 60,
      accuracy: 100,
      maxPp: 5,
      description: 'Powdery scales are blown at the target on a gust.',
    ),

    // Poison
    'poison_sting': Move(
      id: 'poison_sting',
      name: 'Poison Sting',
      type: PokemonType.poison,
      category: MoveCategory.physical,
      power: 25,
      accuracy: 100,
      maxPp: 35,
      statusEffect: 'poison',
      statusChance: 30,
      description: 'Stabs with a toxic barb; may poison the target.',
    ),
    'poison_powder': Move(
      id: 'poison_powder',
      name: 'Poison Powder',
      type: PokemonType.poison,
      category: MoveCategory.status,
      power: 0,
      accuracy: 75,
      maxPp: 35,
      statusEffect: 'poison',
      statusChance: 100,
      description: 'Scatters toxic dust that poisons the target.',
    ),
    'sludge_bomb': Move(
      id: 'sludge_bomb',
      name: 'Sludge Bomb',
      type: PokemonType.poison,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 10,
      statusEffect: 'poison',
      statusChance: 30,
      description: 'Unsanitary sludge is hurled at the target.',
    ),
    'poison_jab': Move(
      id: 'poison_jab',
      name: 'Poison Jab',
      type: PokemonType.poison,
      category: MoveCategory.physical,
      power: 80,
      accuracy: 100,
      maxPp: 20,
      statusEffect: 'poison',
      statusChance: 30,
      description: 'Stabs the target with a tentacle or arm steeped in poison.',
    ),

    // Flying
    'gust': Move(
      id: 'gust',
      name: 'Gust',
      type: PokemonType.flying,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 35,
      description: 'A gust of wind whipped up by wings.',
    ),
    'wing_attack': Move(
      id: 'wing_attack',
      name: 'Wing Attack',
      type: PokemonType.flying,
      category: MoveCategory.physical,
      power: 60,
      accuracy: 100,
      maxPp: 35,
      description: 'Strikes the target with large, imposing wings.',
    ),
    'air_slash': Move(
      id: 'air_slash',
      name: 'Air Slash',
      type: PokemonType.flying,
      category: MoveCategory.special,
      power: 75,
      accuracy: 95,
      maxPp: 15,
      description: 'Attacks with a blade of air that slices even the sky.',
    ),
    'agility': Move(
      id: 'agility',
      name: 'Agility',
      type: PokemonType.psychic,
      category: MoveCategory.status,
      power: 0,
      accuracy: 100,
      maxPp: 30,
      statTarget: 'spe',
      statChange: 2,
      description: 'Relaxes and lightens the body to sharply boost Speed.',
    ),

    // Electric
    'thunder_shock': Move(
      id: 'thunder_shock',
      name: 'Thunder Shock',
      type: PokemonType.electric,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 30,
      statusEffect: 'paralysis',
      statusChance: 10,
      description: 'A jolt of electricity; may cause paralysis.',
    ),
    'electro_ball': Move(
      id: 'electro_ball',
      name: 'Electro Ball',
      type: PokemonType.electric,
      category: MoveCategory.special,
      power: 65,
      accuracy: 100,
      maxPp: 10,
      description: 'Hurls an electric orb at the target.',
    ),
    'thunderbolt': Move(
      id: 'thunderbolt',
      name: 'Thunderbolt',
      type: PokemonType.electric,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      statusEffect: 'paralysis',
      statusChance: 15,
      description: 'A strong electric blast crashes down on the target.',
    ),
    'thunder_wave': Move(
      id: 'thunder_wave',
      name: 'Thunder Wave',
      type: PokemonType.electric,
      category: MoveCategory.status,
      power: 0,
      accuracy: 90,
      maxPp: 20,
      statusEffect: 'paralysis',
      statusChance: 100,
      description: 'A weak electric charge that paralyzes the target.',
    ),

    // Psychic & Dark
    'confusion': Move(
      id: 'confusion',
      name: 'Confusion',
      type: PokemonType.psychic,
      category: MoveCategory.special,
      power: 50,
      accuracy: 100,
      maxPp: 25,
      description: 'Hit by a weak telekinetic force.',
    ),
    'psybeam': Move(
      id: 'psybeam',
      name: 'Psybeam',
      type: PokemonType.psychic,
      category: MoveCategory.special,
      power: 65,
      accuracy: 100,
      maxPp: 20,
      description: 'Attacks the target with a peculiar ray.',
    ),
    'bite': Move(
      id: 'bite',
      name: 'Bite',
      type: PokemonType.dark,
      category: MoveCategory.physical,
      power: 60,
      accuracy: 100,
      maxPp: 25,
      description: 'The target is bitten with viciously sharp fangs.',
    ),
    'crunch': Move(
      id: 'crunch',
      name: 'Crunch',
      type: PokemonType.dark,
      category: MoveCategory.physical,
      power: 80,
      accuracy: 100,
      maxPp: 15,
      description: 'Crunches up the target with sharp fangs.',
    ),
  };

  // ─── SPECIES (22 POKÉMON ACROSS 8 LINES) ────────────────────────────────
  static final Map<int, PokemonSpecies> species = {
    // 1. Bulbasaur Line (#001-#003)
    1: const PokemonSpecies(
      id: 1,
      name: 'Bulbasaur',
      types: [PokemonType.grass, PokemonType.poison],
      baseHp: 45,
      baseAtk: 49,
      baseDef: 49,
      baseSpA: 65,
      baseSpD: 65,
      baseSpe: 45,
      baseCatchRate: 45,
      baseExp: 64,
      evolutionLevel: 16,
      evolutionSpeciesId: 2,
      moveIds: ['tackle', 'growl', 'vine_whip', 'poison_powder'],
    ),
    2: const PokemonSpecies(
      id: 2,
      name: 'Ivysaur',
      types: [PokemonType.grass, PokemonType.poison],
      baseHp: 60,
      baseAtk: 62,
      baseDef: 63,
      baseSpA: 80,
      baseSpD: 80,
      baseSpe: 60,
      baseCatchRate: 45,
      baseExp: 142,
      evolutionLevel: 32,
      evolutionSpeciesId: 3,
      moveIds: ['vine_whip', 'razor_leaf', 'sleep_powder', 'poison_powder'],
    ),
    3: const PokemonSpecies(
      id: 3,
      name: 'Venusaur',
      types: [PokemonType.grass, PokemonType.poison],
      baseHp: 80,
      baseAtk: 82,
      baseDef: 83,
      baseSpA: 100,
      baseSpD: 100,
      baseSpe: 80,
      baseCatchRate: 45,
      baseExp: 236,
      moveIds: ['razor_leaf', 'solar_beam', 'sludge_bomb', 'sleep_powder'],
    ),

    // 2. Charmander Line (#004-#006)
    4: const PokemonSpecies(
      id: 4,
      name: 'Charmander',
      types: [PokemonType.fire],
      baseHp: 39,
      baseAtk: 52,
      baseDef: 43,
      baseSpA: 60,
      baseSpD: 50,
      baseSpe: 65,
      baseCatchRate: 45,
      baseExp: 62,
      evolutionLevel: 16,
      evolutionSpeciesId: 5,
      moveIds: ['scratch', 'growl', 'ember', 'fire_fang'],
    ),
    5: const PokemonSpecies(
      id: 5,
      name: 'Charmeleon',
      types: [PokemonType.fire],
      baseHp: 58,
      baseAtk: 64,
      baseDef: 58,
      baseSpA: 80,
      baseSpD: 65,
      baseSpe: 80,
      baseCatchRate: 45,
      baseExp: 142,
      evolutionLevel: 36,
      evolutionSpeciesId: 6,
      moveIds: ['slash', 'fire_fang', 'flamethrower', 'growl'],
    ),
    6: const PokemonSpecies(
      id: 6,
      name: 'Charizard',
      types: [PokemonType.fire, PokemonType.flying],
      baseHp: 78,
      baseAtk: 84,
      baseDef: 78,
      baseSpA: 109,
      baseSpD: 85,
      baseSpe: 100,
      baseCatchRate: 45,
      baseExp: 240,
      moveIds: ['flamethrower', 'fire_blast', 'air_slash', 'slash'],
    ),

    // 3. Squirtle Line (#007-#009)
    7: const PokemonSpecies(
      id: 7,
      name: 'Squirtle',
      types: [PokemonType.water],
      baseHp: 44,
      baseAtk: 48,
      baseDef: 65,
      baseSpA: 50,
      baseSpD: 64,
      baseSpe: 43,
      baseCatchRate: 45,
      baseExp: 63,
      evolutionLevel: 16,
      evolutionSpeciesId: 8,
      moveIds: ['tackle', 'tail_whip', 'water_gun', 'bite'],
    ),
    8: const PokemonSpecies(
      id: 8,
      name: 'Wartortle',
      types: [PokemonType.water],
      baseHp: 59,
      baseAtk: 63,
      baseDef: 80,
      baseSpA: 65,
      baseSpD: 80,
      baseSpe: 58,
      baseCatchRate: 45,
      baseExp: 142,
      evolutionLevel: 36,
      evolutionSpeciesId: 9,
      moveIds: ['water_pulse', 'bite', 'tail_whip', 'surf'],
    ),
    9: const PokemonSpecies(
      id: 9,
      name: 'Blastoise',
      types: [PokemonType.water],
      baseHp: 79,
      baseAtk: 83,
      baseDef: 100,
      baseSpA: 85,
      baseSpD: 105,
      baseSpe: 78,
      baseCatchRate: 45,
      baseExp: 239,
      moveIds: ['surf', 'hydro_pump', 'crunch', 'harden'],
    ),

    // 4. Caterpie Line (#010-#012)
    10: const PokemonSpecies(
      id: 10,
      name: 'Caterpie',
      types: [PokemonType.bug],
      baseHp: 45,
      baseAtk: 30,
      baseDef: 35,
      baseSpA: 20,
      baseSpD: 20,
      baseSpe: 45,
      baseCatchRate: 255,
      baseExp: 39,
      evolutionLevel: 7,
      evolutionSpeciesId: 11,
      moveIds: ['tackle', 'string_shot', 'bug_bite'],
    ),
    11: const PokemonSpecies(
      id: 11,
      name: 'Metapod',
      types: [PokemonType.bug],
      baseHp: 50,
      baseAtk: 20,
      baseDef: 55,
      baseSpA: 25,
      baseSpD: 25,
      baseSpe: 30,
      baseCatchRate: 120,
      baseExp: 72,
      evolutionLevel: 10,
      evolutionSpeciesId: 12,
      moveIds: ['harden', 'tackle', 'bug_bite'],
    ),
    12: const PokemonSpecies(
      id: 12,
      name: 'Butterfree',
      types: [PokemonType.bug, PokemonType.flying],
      baseHp: 60,
      baseAtk: 45,
      baseDef: 50,
      baseSpA: 90,
      baseSpD: 80,
      baseSpe: 70,
      baseCatchRate: 45,
      baseExp: 178,
      moveIds: ['confusion', 'silver_wind', 'air_slash', 'sleep_powder'],
    ),

    // 5. Weedle Line (#013-#015)
    13: const PokemonSpecies(
      id: 13,
      name: 'Weedle',
      types: [PokemonType.bug, PokemonType.poison],
      baseHp: 40,
      baseAtk: 35,
      baseDef: 30,
      baseSpA: 20,
      baseSpD: 20,
      baseSpe: 50,
      baseCatchRate: 255,
      baseExp: 39,
      evolutionLevel: 7,
      evolutionSpeciesId: 14,
      moveIds: ['poison_sting', 'string_shot', 'bug_bite'],
    ),
    14: const PokemonSpecies(
      id: 14,
      name: 'Kakuna',
      types: [PokemonType.bug, PokemonType.poison],
      baseHp: 45,
      baseAtk: 25,
      baseDef: 50,
      baseSpA: 25,
      baseSpD: 25,
      baseSpe: 35,
      baseCatchRate: 120,
      baseExp: 72,
      evolutionLevel: 10,
      evolutionSpeciesId: 15,
      moveIds: ['harden', 'poison_sting', 'bug_bite'],
    ),
    15: const PokemonSpecies(
      id: 15,
      name: 'Beedrill',
      types: [PokemonType.bug, PokemonType.poison],
      baseHp: 65,
      baseAtk: 90,
      baseDef: 40,
      baseSpA: 45,
      baseSpD: 80,
      baseSpe: 75,
      baseCatchRate: 45,
      baseExp: 178,
      moveIds: ['twinneedle', 'poison_jab', 'agility', 'quick_attack'],
    ),

    // 6. Pidgey Line (#016-#018)
    16: const PokemonSpecies(
      id: 16,
      name: 'Pidgey',
      types: [PokemonType.normal, PokemonType.flying],
      baseHp: 40,
      baseAtk: 45,
      baseDef: 40,
      baseSpA: 35,
      baseSpD: 35,
      baseSpe: 56,
      baseCatchRate: 255,
      baseExp: 50,
      evolutionLevel: 18,
      evolutionSpeciesId: 17,
      moveIds: ['tackle', 'gust', 'quick_attack', 'growl'],
    ),
    17: const PokemonSpecies(
      id: 17,
      name: 'Pidgeotto',
      types: [PokemonType.normal, PokemonType.flying],
      baseHp: 63,
      baseAtk: 60,
      baseDef: 55,
      baseSpA: 50,
      baseSpD: 50,
      baseSpe: 71,
      baseCatchRate: 120,
      baseExp: 122,
      evolutionLevel: 36,
      evolutionSpeciesId: 18,
      moveIds: ['wing_attack', 'quick_attack', 'gust', 'agility'],
    ),
    18: const PokemonSpecies(
      id: 18,
      name: 'Pidgeot',
      types: [PokemonType.normal, PokemonType.flying],
      baseHp: 83,
      baseAtk: 80,
      baseDef: 75,
      baseSpA: 70,
      baseSpD: 70,
      baseSpe: 101,
      baseCatchRate: 45,
      baseExp: 216,
      moveIds: ['air_slash', 'wing_attack', 'quick_attack', 'agility'],
    ),

    // 7. Rattata Line (#019-#020)
    19: const PokemonSpecies(
      id: 19,
      name: 'Rattata',
      types: [PokemonType.normal],
      baseHp: 30,
      baseAtk: 56,
      baseDef: 35,
      baseSpA: 25,
      baseSpD: 35,
      baseSpe: 72,
      baseCatchRate: 255,
      baseExp: 51,
      evolutionLevel: 20,
      evolutionSpeciesId: 20,
      moveIds: ['tackle', 'tail_whip', 'quick_attack', 'bite'],
    ),
    20: const PokemonSpecies(
      id: 20,
      name: 'Raticate',
      types: [PokemonType.normal],
      baseHp: 55,
      baseAtk: 81,
      baseDef: 60,
      baseSpA: 50,
      baseSpD: 70,
      baseSpe: 97,
      baseCatchRate: 127,
      baseExp: 145,
      moveIds: ['hyper_fang', 'crunch', 'quick_attack', 'swords_dance'],
    ),

    // 8. Pikachu Line (#025-#026)
    25: const PokemonSpecies(
      id: 25,
      name: 'Pikachu',
      types: [PokemonType.electric],
      baseHp: 35,
      baseAtk: 55,
      baseDef: 40,
      baseSpA: 50,
      baseSpD: 50,
      baseSpe: 90,
      baseCatchRate: 190,
      baseExp: 112,
      evolutionLevel: 22,
      evolutionSpeciesId: 26,
      moveIds: ['thunder_shock', 'quick_attack', 'thunder_wave', 'electro_ball'],
    ),
    26: const PokemonSpecies(
      id: 26,
      name: 'Raichu',
      types: [PokemonType.electric],
      baseHp: 60,
      baseAtk: 90,
      baseDef: 55,
      baseSpA: 90,
      baseSpD: 80,
      baseSpe: 110,
      baseCatchRate: 75,
      baseExp: 218,
      moveIds: ['thunderbolt', 'quick_attack', 'thunder_wave', 'agility'],
    ),
  };

  static List<Move> movesForSpecies(PokemonSpecies spec) {
    return spec.moveIds
        .where((id) => moves.containsKey(id))
        .take(4)
        .map((id) => moves[id]!.copy())
        .toList();
  }

  static PokemonInstance createPokemon(
    int speciesId, {
    int level = 5,
    String? nickname,
  }) {
    final spec = species[speciesId]!;
    return PokemonInstance(
      species: spec,
      nickname: nickname,
      level: level,
      moves: movesForSpecies(spec),
    );
  }

  // ─── STARTER FACTORY ──────────────────────────────────────────────────
  static PokemonInstance createStarter(int speciesId, {String? nickname}) {
    return createPokemon(speciesId, level: 5, nickname: nickname);
  }

  // ─── WILD ENCOUNTER GENERATOR ─────────────────────────────────────────
  static PokemonInstance generateWildEncounter({int playerLevel = 5}) {
    final minLvl = (playerLevel - 2).clamp(2, 99);
    final maxLvl = (playerLevel + 1).clamp(minLvl, 100);
    final level = minLvl + _rng.nextInt(maxLvl - minLvl + 1);

    // Build an encounter pool reflecting the level tier across our 5 wild lines
    final List<int> wildPool = [];

    // Caterpie line (#10 -> #11 at 7 -> #12 at 10)
    if (level < 7) {
      wildPool.addAll([10, 10]);
    } else if (level < 10) {
      wildPool.addAll([11, 10]);
    } else {
      wildPool.addAll([12, 11]);
    }

    // Weedle line (#13 -> #14 at 7 -> #15 at 10)
    if (level < 7) {
      wildPool.addAll([13, 13]);
    } else if (level < 10) {
      wildPool.addAll([14, 13]);
    } else {
      wildPool.addAll([15, 14]);
    }

    // Pidgey line (#16 -> #17 at 18 -> #18 at 36)
    if (level < 18) {
      wildPool.addAll([16, 16]);
    } else if (level < 36) {
      wildPool.addAll([17, 16]);
    } else {
      wildPool.add(18);
    }

    // Rattata line (#19 -> #20 at 20)
    if (level < 20) {
      wildPool.addAll([19, 19]);
    } else {
      wildPool.add(20);
    }

    // Pikachu line (#25 -> #26 at 22)
    if (level < 22) {
      wildPool.add(25);
    } else {
      wildPool.addAll([25, 26]);
    }

    final speciesId = wildPool[_rng.nextInt(wildPool.length)];
    return createPokemon(speciesId, level: level);
  }

  // ─── RIVAL POKÉMON GENERATOR ──────────────────────────────────────────
  static PokemonInstance generateRivalPokemon({int playerLevel = 5}) {
    final level = (playerLevel + 1).clamp(5, 100);
    final List<int> rivalPool = [];

    // Starters scaled to level
    rivalPool.add(level >= 32 ? 3 : (level >= 16 ? 2 : 1));
    rivalPool.add(level >= 36 ? 6 : (level >= 16 ? 5 : 4));
    rivalPool.add(level >= 36 ? 9 : (level >= 16 ? 8 : 7));

    // Iconic rival Kanto picks
    rivalPool.add(level >= 36 ? 18 : (level >= 18 ? 17 : 16));
    rivalPool.add(level >= 20 ? 20 : 19);
    rivalPool.add(level >= 22 ? 26 : 25);
    if (level >= 10) rivalPool.addAll([12, 15]);

    final speciesId = rivalPool[_rng.nextInt(rivalPool.length)];
    return createPokemon(
      speciesId,
      level: level,
      nickname: "Rival's ${species[speciesId]!.name}",
    );
  }
}
