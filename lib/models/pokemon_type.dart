import 'package:flutter/material.dart';

enum PokemonType {
  normal,
  fire,
  water,
  grass,
  electric,
  ice,
  fighting,
  poison,
  ground,
  flying,
  psychic,
  bug,
  rock,
  ghost,
  dragon,
  steel,
  dark,
  fairy,
}

extension PokemonTypeExtension on PokemonType {
  String get displayName {
    return name[0].toUpperCase() + name.substring(1);
  }

  Color get color {
    switch (this) {
      case PokemonType.normal:
        return const Color(0xFFA8A878);
      case PokemonType.fire:
        return const Color(0xFFF08030);
      case PokemonType.water:
        return const Color(0xFF6890F0);
      case PokemonType.grass:
        return const Color(0xFF78C850);
      case PokemonType.electric:
        return const Color(0xFFF8D030);
      case PokemonType.ice:
        return const Color(0xFF98D8D8);
      case PokemonType.fighting:
        return const Color(0xFFC03028);
      case PokemonType.poison:
        return const Color(0xFFA040A0);
      case PokemonType.ground:
        return const Color(0xFFE0C068);
      case PokemonType.flying:
        return const Color(0xFFA890F0);
      case PokemonType.psychic:
        return const Color(0xFFF85888);
      case PokemonType.bug:
        return const Color(0xFFA8B820);
      case PokemonType.rock:
        return const Color(0xFFB8A038);
      case PokemonType.ghost:
        return const Color(0xFF705898);
      case PokemonType.dragon:
        return const Color(0xFF7038F8);
      case PokemonType.steel:
        return const Color(0xFFB8B8D0);
      case PokemonType.dark:
        return const Color(0xFF705848);
      case PokemonType.fairy:
        return const Color(0xFFEE99AC);
    }
  }

  /// Exact Gen 4 / Modern Type Effectiveness Matrix
  static double getEffectiveness(PokemonType attackType, List<PokemonType> defenderTypes) {
    double multiplier = 1.0;
    for (var defType in defenderTypes) {
      multiplier *= _singleTypeMultiplier(attackType, defType);
    }
    return multiplier;
  }

  static double _singleTypeMultiplier(PokemonType atk, PokemonType def) {
    switch (atk) {
      case PokemonType.normal:
        if (def == PokemonType.rock || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.ghost) return 0.0;
        return 1.0;

      case PokemonType.fire:
        if (def == PokemonType.fire || def == PokemonType.water || def == PokemonType.rock || def == PokemonType.dragon) return 0.5;
        if (def == PokemonType.grass || def == PokemonType.ice || def == PokemonType.bug || def == PokemonType.steel) return 2.0;
        return 1.0;

      case PokemonType.water:
        if (def == PokemonType.water || def == PokemonType.grass || def == PokemonType.dragon) return 0.5;
        if (def == PokemonType.fire || def == PokemonType.ground || def == PokemonType.rock) return 2.0;
        return 1.0;

      case PokemonType.grass:
        if (def == PokemonType.fire || def == PokemonType.grass || def == PokemonType.poison || def == PokemonType.flying || def == PokemonType.bug || def == PokemonType.dragon || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.water || def == PokemonType.ground || def == PokemonType.rock) return 2.0;
        return 1.0;

      case PokemonType.electric:
        if (def == PokemonType.electric || def == PokemonType.grass || def == PokemonType.dragon) return 0.5;
        if (def == PokemonType.water || def == PokemonType.flying) return 2.0;
        if (def == PokemonType.ground) return 0.0;
        return 1.0;

      case PokemonType.ice:
        if (def == PokemonType.fire || def == PokemonType.water || def == PokemonType.ice || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.grass || def == PokemonType.ground || def == PokemonType.flying || def == PokemonType.dragon) return 2.0;
        return 1.0;

      case PokemonType.fighting:
        if (def == PokemonType.poison || def == PokemonType.flying || def == PokemonType.psychic || def == PokemonType.bug || def == PokemonType.fairy) return 0.5;
        if (def == PokemonType.normal || def == PokemonType.ice || def == PokemonType.rock || def == PokemonType.dark || def == PokemonType.steel) return 2.0;
        if (def == PokemonType.ghost) return 0.0;
        return 1.0;

      case PokemonType.poison:
        if (def == PokemonType.poison || def == PokemonType.ground || def == PokemonType.rock || def == PokemonType.ghost) return 0.5;
        if (def == PokemonType.grass || def == PokemonType.fairy) return 2.0;
        if (def == PokemonType.steel) return 0.0;
        return 1.0;

      case PokemonType.ground:
        if (def == PokemonType.grass || def == PokemonType.bug) return 0.5;
        if (def == PokemonType.fire || def == PokemonType.electric || def == PokemonType.poison || def == PokemonType.rock || def == PokemonType.steel) return 2.0;
        if (def == PokemonType.flying) return 0.0;
        return 1.0;

      case PokemonType.flying:
        if (def == PokemonType.electric || def == PokemonType.rock || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.grass || def == PokemonType.fighting || def == PokemonType.bug) return 2.0;
        return 1.0;

      case PokemonType.psychic:
        if (def == PokemonType.psychic || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.fighting || def == PokemonType.poison) return 2.0;
        if (def == PokemonType.dark) return 0.0;
        return 1.0;

      case PokemonType.bug:
        if (def == PokemonType.fire || def == PokemonType.fighting || def == PokemonType.poison || def == PokemonType.flying || def == PokemonType.ghost || def == PokemonType.steel || def == PokemonType.fairy) return 0.5;
        if (def == PokemonType.grass || def == PokemonType.psychic || def == PokemonType.dark) return 2.0;
        return 1.0;

      case PokemonType.rock:
        if (def == PokemonType.fighting || def == PokemonType.ground || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.fire || def == PokemonType.ice || def == PokemonType.flying || def == PokemonType.bug) return 2.0;
        return 1.0;

      case PokemonType.ghost:
        if (def == PokemonType.dark) return 0.5;
        if (def == PokemonType.psychic || def == PokemonType.ghost) return 2.0;
        if (def == PokemonType.normal) return 0.0;
        return 1.0;

      case PokemonType.dragon:
        if (def == PokemonType.steel) return 0.5;
        if (def == PokemonType.dragon) return 2.0;
        if (def == PokemonType.fairy) return 0.0;
        return 1.0;

      case PokemonType.steel:
        if (def == PokemonType.fire || def == PokemonType.water || def == PokemonType.electric || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.ice || def == PokemonType.rock || def == PokemonType.fairy) return 2.0;
        return 1.0;

      case PokemonType.dark:
        if (def == PokemonType.fighting || def == PokemonType.dark || def == PokemonType.fairy) return 0.5;
        if (def == PokemonType.psychic || def == PokemonType.ghost) return 2.0;
        return 1.0;

      case PokemonType.fairy:
        if (def == PokemonType.fire || def == PokemonType.poison || def == PokemonType.steel) return 0.5;
        if (def == PokemonType.fighting || def == PokemonType.dragon || def == PokemonType.dark) return 2.0;
        return 1.0;
    }
  }
}
