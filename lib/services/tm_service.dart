import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import 'pokedex_database.dart';

class TmService {
  static List<Item> get allTms => ItemDatabase.allItems.values
      .where((item) => item.isTm)
      .toList();

  static Move? getMoveForTm(Item tmItem) {
    final moveId = tmItem.moveId;
    if (moveId == null) return null;
    return PokedexDatabase.moves[moveId]?.copy();
  }

  /// Non-TM learners (Gen 1–2)
  static const Set<int> _noTmSpeciesIds = {10, 11, 13, 14, 129, 132, 201, 202, 235};

  static const Set<int> _universalTmNumbers = {
    6, // Toxic
    8, // Body Slam
    9, // Take Down
    10, // Double-Edge
    20, // Rage
    31, // Mimic
    32, // Double Team
    34, // Bide
    39, // Swift
    40, // Skull Bash
    44, // Rest
    50, // Substitute
  };

  /// Returns true if [species] can learn Gen 1 [tmItem].
  static bool canLearnTm(PokemonSpecies species, Item tmItem) {
    if (!tmItem.isTm || tmItem.moveId == null) return false;
    final id = species.id;

    // Mew can learn every Gen 1 TM; Celebi can learn broad Grass/Psychic/Support TMs.
    if (id == 151) return true;
    // Cocoon/basic bugs, Magikarp, Ditto, Unown, Wobbuffet, Smeargle cannot learn TMs.
    if (_noTmSpeciesIds.contains(id)) return false;

    final int? tmNum = int.tryParse(tmItem.id.replaceFirst('tm_', ''));
    if (tmNum == null) return false;

    if (_universalTmNumbers.contains(tmNum)) {
      return true;
    }

    if (species.learnset.any((lm) => lm.moveId == tmItem.moveId)) {
      return true;
    }

    final types = species.types;
    switch (tmNum) {
      case 1: // Mega Punch
      case 5: // Mega Kick
      case 17: // Submission
      case 18: // Counter
      case 19: // Seismic Toss
        return types.contains(PokemonType.fighting) ||
            const {
              4, 5, 6, 7, 8, 9, 25, 26, 31, 34, 35, 36, 39, 40,
              54, 55, 61, 62, 63, 64, 65, 79, 80, 92, 93, 94,
              96, 97, 104, 105, 108, 112, 113, 115, 122, 124, 125, 126, 143, 150,
            }.contains(id);

      case 2: // Razor Wind
      case 4: // Whirlwind
      case 43: // Sky Attack
        return types.contains(PokemonType.flying) ||
            const {12, 15, 49, 123, 127, 142, 149}.contains(id);

      case 3: // Swords Dance
        return types.contains(PokemonType.grass) ||
            const {
              4, 5, 6, 15, 27, 28, 46, 47, 83, 98, 99, 108, 123, 127, 140, 141,
            }.contains(id);

      case 7: // Horn Drill
        return const {
          29, 30, 31, 32, 33, 34, 86, 87, 111, 112, 118, 119, 128,
        }.contains(id);

      case 11: // Bubble Beam
      case 12: // Water Gun
        return types.contains(PokemonType.water) ||
            const {31, 34, 108, 112, 113, 115, 128, 137, 143, 147, 148, 149}
                .contains(id);

      case 13: // Ice Beam
      case 14: // Blizzard
        return types.contains(PokemonType.water) ||
            types.contains(PokemonType.ice) ||
            const {
              19, 20, 31, 34, 35, 36, 39, 40, 108, 112, 113, 115, 128, 137,
              143, 147, 148, 149, 150,
            }.contains(id);

      case 15: // Hyper Beam
        return species.isFinalStage || species.isPseudoLegendary || species.isLegendary;

      case 16: // Pay Day
        return const {19, 20, 25, 26, 52, 53, 56, 57, 112, 143}.contains(id);

      case 21: // Mega Drain
        return types.contains(PokemonType.grass) ||
            const {12, 15, 41, 42, 48, 49, 72, 73, 92, 93, 94, 140, 141}
                .contains(id);

      case 22: // Solar Beam
        return types.contains(PokemonType.grass) ||
            const {35, 36, 39, 40, 150}.contains(id);

      case 23: // Dragon Rage
        return types.contains(PokemonType.dragon) ||
            const {4, 5, 6, 116, 117, 130, 142}.contains(id);

      case 24: // Thunderbolt
      case 25: // Thunder
        return types.contains(PokemonType.electric) ||
            const {
              19, 20, 25, 26, 31, 34, 35, 36, 39, 40, 52, 53, 88, 89, 92, 93, 94,
              109, 110, 112, 113, 115, 120, 121, 128, 130, 131, 137, 143, 147, 148, 149, 150,
            }.contains(id);

      case 26: // Earthquake
      case 27: // Fissure
        return types.contains(PokemonType.ground) ||
            types.contains(PokemonType.rock) ||
            const {
              3, 6, 9, 31, 34, 54, 55, 62, 66, 67, 68, 79, 80, 108, 113,
              115, 128, 130, 143,
            }.contains(id);

      case 28: // Dig
        return types.contains(PokemonType.ground) ||
            types.contains(PokemonType.rock) ||
            const {
              4, 5, 6, 7, 8, 9, 19, 20, 23, 24, 37, 38, 46, 47, 52, 53, 54, 55,
              56, 57, 58, 59, 60, 61, 62, 66, 67, 68, 79, 80, 98, 99, 115,
              133, 134, 135, 136,
            }.contains(id);

      case 29: // Psychic
      case 30: // Teleport
      case 33: // Reflect
      case 42: // Dream Eater
      case 46: // Psywave
        return types.contains(PokemonType.psychic) ||
            types.contains(PokemonType.ghost) ||
            const {12, 35, 36, 39, 40, 48, 49, 54, 55, 60, 61, 62, 113, 120, 121, 137, 163, 164, 173, 174, 175, 176, 198, 200, 211, 242, 249, 250, 251}
                .contains(id);

      case 35: // Metronome
        return const {
          25, 26, 35, 36, 39, 40, 54, 55, 61, 62, 63, 64, 65, 66, 67, 68,
          74, 75, 76, 92, 93, 94, 96, 97, 113, 122, 124, 125, 126, 143, 150,
        }.contains(id);

      case 36: // Self-Destruct
      case 47: // Explosion
        return const {
          74, 75, 76, 81, 82, 88, 89, 90, 91, 92, 93, 94, 95, 100, 101,
          102, 103, 109, 110, 143, 150,
        }.contains(id);

      case 37: // Egg Bomb
        return const {102, 103, 113, 150}.contains(id);

      case 38: // Fire Blast
        return types.contains(PokemonType.fire) ||
            const {
              31, 34, 35, 36, 39, 40, 79, 80, 88, 89, 104, 105, 108, 109, 110,
              112, 113, 115, 128, 130, 142, 143, 147, 148, 149, 150,
            }.contains(id);

      case 41: // Soft-Boiled
        return const {35, 36, 113, 150}.contains(id);

      case 45: // Thunder Wave
        return types.contains(PokemonType.electric) ||
            types.contains(PokemonType.psychic) ||
            const {
              12, 35, 36, 39, 40, 79, 80, 113, 120, 121, 130, 137, 147, 148, 149,
            }.contains(id);

      case 48: // Rock Slide
        return types.contains(PokemonType.rock) ||
            types.contains(PokemonType.ground) ||
            types.contains(PokemonType.fighting) ||
            const {6, 115, 142, 143}.contains(id);

      case 49: // Tri Attack
        return const {35, 36, 81, 82, 84, 85, 113, 120, 121, 137, 150}.contains(id);

      case 51: // Giga Impact
        return species.isFinalStage || species.isPseudoLegendary || species.isLegendary || species.isMythical;

      case 52: // Ice Punch
        return types.contains(PokemonType.ice) ||
            types.contains(PokemonType.water) ||
            types.contains(PokemonType.fighting) ||
            const {
              7, 8, 9, 31, 34, 35, 36, 39, 40, 54, 55, 62, 63, 64, 65,
              79, 80, 92, 93, 94, 96, 97, 106, 107, 108, 112, 113, 115,
              122, 124, 125, 143, 149, 150,
            }.contains(id);

      case 53: // Close Combat
        return types.contains(PokemonType.fighting) ||
            const {
              6, 9, 25, 26, 31, 34, 56, 57, 58, 59, 62, 66, 67, 68, 76,
              106, 107, 112, 115, 123, 127, 128, 141, 142, 143, 149, 150,
            }.contains(id);

      case 54: // Shadow Ball
        return types.contains(PokemonType.ghost) ||
            types.contains(PokemonType.psychic) ||
            types.contains(PokemonType.poison) ||
            const {
              12, 19, 20, 35, 36, 39, 40, 52, 53, 79, 80, 92, 93, 94,
              96, 97, 108, 113, 115, 120, 121, 122, 124, 131, 133, 134,
              135, 136, 137, 143, 144, 150,
            }.contains(id);

      case 55: // Dragon Claw
        return types.contains(PokemonType.dragon) ||
            const {
              4, 5, 6, 31, 34, 108, 112, 115, 123, 127, 130, 141, 142,
              147, 148, 149, 150,
            }.contains(id);

      case 56: // Dark Pulse
        return types.contains(PokemonType.ghost) ||
            types.contains(PokemonType.psychic) ||
            types.contains(PokemonType.poison) ||
            const {
              9, 23, 24, 52, 53, 58, 59, 92, 93, 94, 109, 110, 130,
              131, 133, 134, 135, 136, 142, 149, 150,
            }.contains(id);

      default:
        return true;
    }
  }
}
