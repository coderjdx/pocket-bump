import 'pokemon_type.dart';

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
  final int? evolutionLevel;
  final int? evolutionSpeciesId;
  final List<String> moveIds;

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
    this.evolutionLevel,
    this.evolutionSpeciesId,
    this.moveIds = const ['tackle'],
  });

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
