import 'package:flutter/material.dart';
import 'game_version.dart';
import 'pokemon_type.dart';

enum PokemonRarity {
  common,
  uncommon,
  rare,
  special,
}

extension PokemonRarityExtension on PokemonRarity {
  String get displayName {
    switch (this) {
      case PokemonRarity.common:
        return 'Common';
      case PokemonRarity.uncommon:
        return 'Uncommon';
      case PokemonRarity.rare:
        return 'Rare';
      case PokemonRarity.special:
        return 'Special';
    }
  }

  double get encounterProbability {
    switch (this) {
      case PokemonRarity.common:
        return 0.65;
      case PokemonRarity.uncommon:
        return 0.30;
      case PokemonRarity.rare:
        return 0.05;
      case PokemonRarity.special:
        return 0.0;
    }
  }

  Color get color {
    switch (this) {
      case PokemonRarity.common:
        return const Color(0xFFB0BEC5);
      case PokemonRarity.uncommon:
        return const Color(0xFF4FC3F7);
      case PokemonRarity.rare:
        return const Color(0xFFFFD54F);
      case PokemonRarity.special:
        return const Color(0xFFE040FB);
    }
  }
}

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
  final double weightKg;
  final int evolutionStage;
  final bool isStarter;
  final bool isFossil;
  final bool isPseudoLegendary;
  final bool isLegendary;
  final bool isMythical;
  final PokemonRarity? rarityOverride;
  final int minEncounterLevel;
  final int? evolutionLevel;
  final int? evolutionSpeciesId;
  final List<LearnedMove> learnset;
  final String abilitySlot1Id;
  final String? abilitySlot2Id;
  final String? hiddenAbilityId;
  final bool allowWildEncounter;

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
    this.weightKg = 10.0,
    this.evolutionStage = 1,
    this.isStarter = false,
    this.isFossil = false,
    this.isPseudoLegendary = false,
    this.isLegendary = false,
    this.isMythical = false,
    this.rarityOverride,
    this.minEncounterLevel = 2,
    this.evolutionLevel,
    this.evolutionSpeciesId,
    this.learnset = const [LearnedMove(1, 'tackle')],
    this.abilitySlot1Id = 'run_away',
    this.abilitySlot2Id,
    this.hiddenAbilityId,
    this.allowWildEncounter = true,
  });

  String abilityForSlot(int slot) {
    if (slot == 3 && hiddenAbilityId != null) return hiddenAbilityId!;
    if (slot == 2 && abilitySlot2Id != null) return abilitySlot2Id!;
    return abilitySlot1Id;
  }

  List<String> get standardAbilityIds => [
        abilitySlot1Id,
        if (abilitySlot2Id != null) abilitySlot2Id!,
      ];

  bool isHiddenAbility(String? abilityId) =>
      abilityId != null && hiddenAbilityId != null && abilityId == hiddenAbilityId;

  int slotForAbility(String? abilityId) {
    if (abilityId == null) return 1;
    if (hiddenAbilityId != null && abilityId == hiddenAbilityId) return 3;
    if (abilitySlot2Id != null && abilityId == abilitySlot2Id) return 2;
    return 1;
  }

  bool get isFinalStage => evolutionSpeciesId == null;
  bool get isSingleStage => evolutionStage == 1 && evolutionSpeciesId == null;
  bool get isFossilPokemon =>
      isFossil || const {138, 139, 140, 141, 142}.contains(id);

  PokemonRarity get rarity {
    if (rarityOverride != null) return rarityOverride!;
    if (isLegendary || isMythical) {
      return PokemonRarity.special;
    }
    // Starters can only be encountered in their first stage and are Rare encounters
    if (isStarter) {
      return PokemonRarity.rare;
    }
    if (evolutionStage >= 3 || (isPseudoLegendary && isFinalStage)) {
      return PokemonRarity.rare;
    }
    if (evolutionStage == 2 || (isSingleStage && !isPseudoLegendary)) {
      return PokemonRarity.uncommon;
    }
    return PokemonRarity.common;
  }

  /// Whether this species can ever appear in wild encounters.
  /// Starter lines can only ever be encountered in the wild in their first stage.
  /// Fossil Pokémon cannot be encountered in the wild (must be restored at a Poké Lab).
  bool get isWildEncounterable {
    if (!allowWildEncounter) return false;
    if (rarity == PokemonRarity.special) return false;
    if (isFossilPokemon) return false;
    if (isStarter && evolutionStage > 1) return false;
    return true;
  }

  /// Minimum player level required to encounter this species in the wild:
  /// - 1st stage starters: available from player level 1 as Rare encounters
  /// - 1st stage (multi-stage line): any level (1)
  /// - 2nd stage or single-stage non-pseudo-legendary: within 5 levels of minEncounterLevel
  /// - 3rd stage or final-stage pseudo-legendary: within 10 levels of minEncounterLevel
  int get requiredPlayerLevelForEncounter {
    if (isStarter) {
      return 1;
    }
    if (evolutionStage >= 3 || (isPseudoLegendary && isFinalStage)) {
      return (minEncounterLevel - 10).clamp(1, 100);
    }
    if (evolutionStage == 2 || (isSingleStage && !isPseudoLegendary)) {
      return (minEncounterLevel - 5).clamp(1, 100);
    }
    return 1;
  }

  static const Set<int> redExclusiveIds = {
    23, 24, // Ekans, Arbok
    43, 44, 45, // Oddish, Gloom, Vileplume
    56, 57, // Mankey, Primeape
    58, 59, // Growlithe, Arcanine
    123, // Scyther
    125, // Electabuzz
  };

  static const Set<int> blueGreenExclusiveIds = {
    27, 28, // Sandshrew, Sandslash
    37, 38, // Vulpix, Ninetales
    52, 53, // Meowth, Persian
    69, 70, 71, // Bellsprout, Weepinbell, Victreebel
    126, // Magmar
    127, // Pinsir
  };

  GameVersion? get exclusiveVersion {
    if (redExclusiveIds.contains(id)) return GameVersion.red;
    if (blueGreenExclusiveIds.contains(id)) return GameVersion.blueGreen;
    return null;
  }

  bool isAvailableInVersion(GameVersion? version) {
    final ex = exclusiveVersion;
    if (ex == null || version == null) return true;
    return ex == version;
  }

  bool canEncounterAtPlayerLevel(int playerLevel, {GameVersion? gameVersion}) {
    if (!isWildEncounterable) return false;
    if (!isAvailableInVersion(gameVersion)) return false;
    return playerLevel >= requiredPlayerLevelForEncounter;
  }

  /// Visual standing/posture height in meters used for UI sprite scaling.
  /// Serpentine/coiled Pokémon use pokédex nose-to-tail length for [heightMeters]
  /// (kept intact for weight/height move formulas), so map their visual posture height here.
  double get visualHeightMeters {
    switch (id) {
      case 23: // Ekans (2.0m length, small coiled snake)
        return 0.7;
      case 24: // Arbok (3.5m length, coiled hood)
        return 1.5;
      case 95: // Onix (8.8m length, towering coiled rock snake)
        return 2.6;
      case 130: // Gyarados (6.5m length, towering sea serpent)
        return 2.6;
      case 147: // Dratini (1.8m length, tiny coiled dragon)
        return 0.7;
      case 148: // Dragonair (4.0m length, slender coiled dragon)
        return 1.4;
      case 497: // Serperior (3.3m length, regal coiled serpent)
        return 1.6;
      default:
        return heightMeters;
    }
  }

  /// Proportional visual scale factor derived from visual standing height.
  /// Calibrated smoothly across tiny Pokémon (~0.2-0.4m), mid-stage (~0.8-1.4m),
  /// and towering evolutions/legendaries (2.0m+).
  double get speciesScale {
    final h = visualHeightMeters;
    if (h <= 0.3) return 0.52;
    if (h <= 0.4) return 0.58;
    if (h <= 0.5) return 0.64;
    if (h <= 0.6) return 0.70;
    if (h <= 0.7) return 0.75;
    if (h <= 0.9) return 0.82;
    if (h <= 1.1) return 0.88;
    if (h <= 1.4) return 0.96;
    if (h <= 1.7) return 1.04;
    if (h <= 2.2) return 1.12;
    return 1.20;
  }

  /// Foreground (player) active Pokémon height in logical pixels
  double get battlePlayerSize => (148.0 * speciesScale).roundToDouble();

  /// Distant (opponent) Pokémon height in logical pixels (~0.73x foreground for natural depth)
  double get battleOpponentSize => (108.0 * speciesScale).roundToDouble();

  /// Lead companion display height next to the 92px Trainer on the Home screen stage
  double get homeCompanionSize =>
      (88.0 * speciesScale).roundToDouble().clamp(44.0, 112.0);

  /// Proportional showcase height for UI frames (Pokédex, Evolution, Detail cards)
  double scaledUiSize(double maxSize, {double minSize = 38.0}) {
    final normalized = (speciesScale / 1.15).clamp(0.42, 1.0);
    return (maxSize * normalized).roundToDouble().clamp(minSize, maxSize);
  }

  /// Habitat-appropriate pixel-art battle arena background for wild encounters
  String get battleBackgroundAsset {
    // 1. Cave / Subterranean Ruins (Zubat, Clefairy, Paras, Diglett, Geodude, Onix, Cubone, etc.)
    const caveIds = {
      35, 36, 39, 40, 41, 42, 46, 47, 50, 51, 66, 67, 68, 74, 75, 76,
      95, 104, 105, 106, 107, 111, 112, 138, 139, 140, 141, 142, 150,
    };
    if (caveIds.contains(id) || types.contains(PokemonType.rock)) {
      return 'assets/images/battle_bg_cave.png';
    }

    // 2. Coastal Beach / Sea (Staryu, Squirtle, Psyduck, Poliwag, Tentacool, Seel, Shellder, Krabby, etc.)
    const beachIds = {
      7, 8, 9, 54, 55, 60, 61, 62, 72, 73, 79, 80, 86, 87, 90, 91,
      98, 99, 116, 117, 118, 119, 120, 121, 129, 130, 131, 134, 144, 147, 148, 149,
    };
    if (beachIds.contains(id) ||
        types.contains(PokemonType.water) ||
        types.contains(PokemonType.ice)) {
      return 'assets/images/battle_bg_beach.png';
    }

    // 3. Volcanic Caldera / Magma Cavern (Charmander, Vulpix, Growlithe, Ponyta, Magmar, etc.)
    const volcanoIds = {4, 5, 6, 37, 38, 58, 59, 77, 78, 126, 136, 146};
    if (volcanoIds.contains(id) || types.contains(PokemonType.fire)) {
      return 'assets/images/battle_bg_volcano.png';
    }

    // 4. Forest Canopy (Bulbasaur, Caterpie, Weedle, Pikachu, Oddish, Bellsprout, Scyther, Pinsir, etc.)
    const forestIds = {
      1, 2, 3, 10, 11, 12, 13, 14, 15, 25, 26, 43, 44, 45, 48, 49,
      69, 70, 71, 102, 103, 113, 114, 123, 127, 151,
    };
    if (forestIds.contains(id) ||
        types.contains(PokemonType.bug) ||
        types.contains(PokemonType.grass)) {
      return 'assets/images/battle_bg_forest.png';
    }

    // 5. Power Plant / Urban Facility / Tower (Magnemite, Voltorb, Gastly, Abra, Meowth, Porygon, etc.)
    const urbanIds = {
      52, 53, 63, 64, 65, 81, 82, 88, 89, 92, 93, 94, 96, 97,
      100, 101, 109, 110, 122, 124, 125, 132, 135, 137, 145,
    };
    if (urbanIds.contains(id) ||
        types.contains(PokemonType.ghost) ||
        types.contains(PokemonType.electric) ||
        types.contains(PokemonType.psychic)) {
      return 'assets/images/battle_bg_urban.png';
    }

    // 6. Default Grassy Kanto Route
    return 'assets/images/battle_bg_route.png';
  }

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

  String get shinySpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/shiny/$id.gif';

  String get shinyBackSpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/back/shiny/$id.gif';

  String get staticShinySpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/shiny/$id.png';

  String get staticShinyBackSpriteUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/back/shiny/$id.png';

  String get shinyArtworkUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/shiny/$id.png';

  /// Bundled Pokémon cry asset path (relative to `assets/` for AudioPlayers AssetSource).
  String get cryAsset => 'audio/cries/$id.mp3';

  /// All Pokémon (including Legendaries and Mythicals) have shiny variants.
  bool get isShinyEligible => true;

  bool get isDualType => types.length > 1;
}
