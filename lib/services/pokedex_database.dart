import '../models/move.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/pokemon_instance.dart';

class PokedexDatabase {
  // ─── MOVES ─────────────────────────────────────────────────────────────
  static final Map<String, Move> moves = {
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
    'ember': Move(
      id: 'ember',
      name: 'Ember',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 25,
      description: 'The target is attacked with small flames.',
    ),
    'flamethrower': Move(
      id: 'flamethrower',
      name: 'Flamethrower',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      description: 'The target is scorched with an intense blast of fire.',
    ),
    'fire_blast': Move(
      id: 'fire_blast',
      name: 'Fire Blast',
      type: PokemonType.fire,
      category: MoveCategory.special,
      power: 110,
      accuracy: 85,
      maxPp: 5,
      description: 'The target is attacked with an intense blast of all-consuming fire.',
    ),
    'water_gun': Move(
      id: 'water_gun',
      name: 'Water Gun',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 25,
      description: 'The target is blasted with a forceful shot of water.',
    ),
    'surf': Move(
      id: 'surf',
      name: 'Surf',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      description: 'The user attacks everything around it by swamping its surroundings with a giant wave.',
    ),
    'hydro_pump': Move(
      id: 'hydro_pump',
      name: 'Hydro Pump',
      type: PokemonType.water,
      category: MoveCategory.special,
      power: 110,
      accuracy: 80,
      maxPp: 5,
      description: 'The target is blasted by a huge volume of water launched under great pressure.',
    ),
    'thunder_shock': Move(
      id: 'thunder_shock',
      name: 'Thunder Shock',
      type: PokemonType.electric,
      category: MoveCategory.special,
      power: 40,
      accuracy: 100,
      maxPp: 30,
      description: 'A jolt of electricity is hurled at the target.',
    ),
    'thunderbolt': Move(
      id: 'thunderbolt',
      name: 'Thunderbolt',
      type: PokemonType.electric,
      category: MoveCategory.special,
      power: 90,
      accuracy: 100,
      maxPp: 15,
      description: 'A strong electric blast crashes down on the target.',
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
      description: 'The target is struck with large, imposing wings spread wide.',
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
  };

  // ─── SPECIES ───────────────────────────────────────────────────────────
  static final Map<int, PokemonSpecies> species = {
    // 001 - Bulbasaur Line
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png',
      evolutionLevel: 16,
      evolutionSpeciesId: 2,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/2.png',
      evolutionLevel: 32,
      evolutionSpeciesId: 3,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/3.png',
    ),

    // 004 - Charmander Line
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/4.png',
      evolutionLevel: 16,
      evolutionSpeciesId: 5,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/5.png',
      evolutionLevel: 36,
      evolutionSpeciesId: 6,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/6.png',
    ),

    // 007 - Squirtle Line
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/7.png',
      evolutionLevel: 16,
      evolutionSpeciesId: 8,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/8.png',
      evolutionLevel: 36,
      evolutionSpeciesId: 9,
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/9.png',
    ),

    // 016 - Pidgey Line
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/16.png',
      evolutionLevel: 18,
      evolutionSpeciesId: 17,
    ),

    // 019 - Rattata Line
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/19.png',
    ),

    // 025 - Pikachu
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
      spriteUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png',
    ),
  };

  // ─── STARTER FACTORY ──────────────────────────────────────────────────
  static PokemonInstance createStarter(int speciesId, {String? nickname}) {
    final spec = species[speciesId]!;
    List<Move> startingMoves = [];

    switch (speciesId) {
      case 1: // Bulbasaur
        startingMoves = [
          moves['tackle']!.copy(),
          moves['vine_whip']!.copy(),
        ];
        break;
      case 4: // Charmander
        startingMoves = [
          moves['scratch']!.copy(),
          moves['ember']!.copy(),
        ];
        break;
      case 7: // Squirtle
        startingMoves = [
          moves['tackle']!.copy(),
          moves['water_gun']!.copy(),
        ];
        break;
    }

    return PokemonInstance(
      species: spec,
      nickname: nickname,
      level: 5,
      moves: startingMoves,
    );
  }

  // ─── WILD ENCOUNTER GENERATOR ─────────────────────────────────────────
  static PokemonInstance generateWildEncounter({int minLevel = 2, int maxLevel = 5}) {
    final wildPool = [16, 19, 25]; // Pidgey, Rattata, Pikachu
    final speciesId = wildPool[(DateTime.now().millisecondsSinceEpoch) % wildPool.length];
    final spec = species[speciesId]!;
    final level = minLevel + (DateTime.now().microsecond % (maxLevel - minLevel + 1));

    List<Move> wildMoves = [moves['tackle']!.copy()];
    if (speciesId == 16) wildMoves.add(moves['gust']!.copy());
    if (speciesId == 19) wildMoves.add(moves['quick_attack']!.copy());
    if (speciesId == 25) wildMoves.add(moves['thunder_shock']!.copy());

    return PokemonInstance(
      species: spec,
      level: level,
      moves: wildMoves,
    );
  }
}
