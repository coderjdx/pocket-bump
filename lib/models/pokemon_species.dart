import 'pokemon_type.dart';

class LearnedMove {
  final int level;
  final String moveId;

  const LearnedMove(this.level, this.moveId);
}

class PokemonSpecies {
  final int id;
  final String name;
  final List<PokemonType> types;
  final int baseHp;
  final int baseAtk;
  final int baseDef;
  final int baseSpA;
  final int baseSpD;
  final int baseSpe;
  final int baseCatchRate;
  final int baseExp;
  final double heightMeters;
  final int? evolutionLevel;
  final int? evolutionSpeciesId;
  final List<LearnedMove> learnset;

  const PokemonSpecies({
    required this.id,
    required this.name,
    required this.types,
    required this.baseHp,
    required this.baseAtk,
    required this.baseDef,
    required this.baseSpA,
    required this.baseSpD,
    required this.baseSpe,
    this.baseCatchRate = 45,
    this.baseExp = 64,
    this.heightMeters = 0.7,
    this.evolutionLevel,
    this.evolutionSpeciesId,
    this.learnset = const [LearnedMove(1, 'tackle')],
  });

  double get speciesScale {
    if (heightMeters <= 0.2) return 0.44;
    if (heightMeters <= 0.3) return 0.49;
    if (heightMeters <= 0.4) return 0.56;
    if (heightMeters <= 0.5) return 0.63;
    if (heightMeters <= 0.6) return 0.65;
    if (heightMeters <= 0.7) return 0.67;
    if (heightMeters <= 0.8) return 0.76;
    if (heightMeters <= 1.0) return 0.82;
    if (heightMeters <= 1.1) return 0.85;
    if (heightMeters <= 1.5) return 1.00;
    if (heightMeters <= 1.6) return 1.05;
    if (heightMeters <= 1.7) return 1.10;
    return 1.14;
  }

  /// Foreground (player) active Pokémon size in logical pixels (base 162px for a 1.5m Pokémon)
  double get battlePlayerSize => (162.0 * speciesScale).roundToDouble();

  /// Distant (opponent) Pokémon size in logical pixels (~0.56x foreground size for perspective depth)
  double get battleOpponentSize => (90.0 * speciesScale).roundToDouble();

  String get spriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/$id.gif';

  String get backSpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/back/$id.gif';

  String get staticSpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$id.png';

  String get staticBackSpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/$id.png';

  String get artworkUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

  bool get isDualType => types.length > 1;
}
