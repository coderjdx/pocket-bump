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
  final String spriteUrl;
  final int? evolutionLevel;
  final int? evolutionSpeciesId;

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
    required this.spriteUrl,
    this.evolutionLevel,
    this.evolutionSpeciesId,
  });

  bool get isDualType => types.length > 1;
}
