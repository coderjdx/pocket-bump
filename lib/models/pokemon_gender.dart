import 'dart:math';
import 'package:flutter/material.dart';

enum PokemonGender {
  male,
  female,
  genderless,
}

extension PokemonGenderExtension on PokemonGender {
  String get symbol {
    switch (this) {
      case PokemonGender.male:
        return '♂';
      case PokemonGender.female:
        return '♀';
      case PokemonGender.genderless:
        return '';
    }
  }

  String get displayName {
    switch (this) {
      case PokemonGender.male:
        return 'Male';
      case PokemonGender.female:
        return 'Female';
      case PokemonGender.genderless:
        return 'Genderless';
    }
  }

  Color get color {
    switch (this) {
      case PokemonGender.male:
        return const Color(0xFF1E88E5);
      case PokemonGender.female:
        return const Color(0xFFEC407A);
      case PokemonGender.genderless:
        return const Color(0xFF78909C);
    }
  }

  static const Set<int> _genderlessSpeciesIds = {
    81, 82, // Magnemite, Magneton
    100, 101, // Voltorb, Electrode
    120, 121, // Staryu, Starmie
    132, // Ditto
    137, // Porygon
    144, 145, 146, 150, 151, // Birds, Mewtwo, Mew
    201, // Unown
    233, // Porygon2
    243, 244, 245, 249, 250, 251, // Beasts, Lugia, Ho-Oh, Celebi
  };

  static const Set<int> _maleOnlySpeciesIds = {
    32, 33, 34, // Nidoran♂, Nidorino, Nidoking
    106, 107, // Hitmonlee, Hitmonchan
    128, // Tauros
    236, 237, // Tyrogue, Hitmontop
  };

  static const Set<int> _femaleOnlySpeciesIds = {
    29, 30, 31, // Nidoran♀, Nidorina, Nidoqueen
    113, // Chansey
    115, // Kangaskhan
    124, // Jynx
    238, // Smoochum
    241, // Miltank
    242, // Blissey
  };

  static const Set<int> _highMaleSpeciesIds = {
    // Starters (Gen 1–5)
    1, 2, 3, 4, 5, 6, 7, 8, 9,
    152, 153, 154, 155, 156, 157, 158, 159, 160,
    252, 253, 254, 255, 256, 257, 258, 259, 260,
    387, 388, 389, 390, 391, 392, 393, 394, 395,
    495, 496, 497, 498, 499, 500, 501, 502, 503,
    // Eevee line
    133, 134, 135, 136, 196, 197,
    // Fossils, Snorlax, Togepi line
    138, 139, 140, 141, 142, 143, 175, 176,
  };

  static const Set<int> _highFemaleSpeciesIds = {
    35, 36, // Clefairy, Clefable
    37, 38, // Vulpix, Ninetales
    39, 40, // Jigglypuff, Wigglytuff
    173, 174, // Cleffa, Igglybuff
    209, 210, // Snubbull, Granbull
    222, // Corsola
  };

  static PokemonGender fromStorageKey(String? raw) {
    if (raw == null || raw.isEmpty) return PokemonGender.genderless;
    for (final g in PokemonGender.values) {
      if (g.name == raw) return g;
    }
    return PokemonGender.genderless;
  }

  static PokemonGender rollForSpeciesId(int speciesId, [Random? rng]) {
    if (_genderlessSpeciesIds.contains(speciesId)) {
      return PokemonGender.genderless;
    }
    if (_maleOnlySpeciesIds.contains(speciesId)) {
      return PokemonGender.male;
    }
    if (_femaleOnlySpeciesIds.contains(speciesId)) {
      return PokemonGender.female;
    }
    final r = rng ?? Random();
    if (_highMaleSpeciesIds.contains(speciesId)) {
      return r.nextInt(8) == 0 ? PokemonGender.female : PokemonGender.male;
    }
    if (_highFemaleSpeciesIds.contains(speciesId)) {
      return r.nextInt(4) == 0 ? PokemonGender.male : PokemonGender.female;
    }
    return r.nextBool() ? PokemonGender.male : PokemonGender.female;
  }
}
