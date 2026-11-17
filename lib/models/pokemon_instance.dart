import 'pokemon_species.dart';
import 'move.dart';

enum StatusCondition {
  none,
  burn,
  freeze,
  paralysis,
  poison,
  sleep,
}

extension StatusConditionExtension on StatusCondition {
  String get shortLabel {
    switch (this) {
      case StatusCondition.none:
        return '';
      case StatusCondition.burn:
        return 'BRN';
      case StatusCondition.freeze:
        return 'FRZ';
      case StatusCondition.paralysis:
        return 'PAR';
      case StatusCondition.poison:
        return 'PSN';
      case StatusCondition.sleep:
        return 'SLP';
    }
  }
}

class PokemonInstance {
  PokemonSpecies species;
  String nickname;
  int level;
  int currentHp;
  int maxHp;
  int atk;
  int def;
  int spa;
  int spd;
  int spe;
  List<Move> moves;
  int currentExp;
  StatusCondition status;

  // In-battle stat stages (-6 to +6)
  int atkStage = 0;
  int defStage = 0;
  int spaStage = 0;
  int spdStage = 0;
  int speStage = 0;

  PokemonInstance({
    required this.species,
    String? nickname,
    this.level = 5,
    int? currentHp,
    List<Move>? moves,
    int? currentExp,
    this.status = StatusCondition.none,
  })  : nickname = nickname ?? species.name,
        moves = moves ?? [],
        currentExp = currentExp ?? ((level - 1) * (level - 1) * (level - 1)),
        maxHp = _calculateMaxHp(species.baseHp, level),
        currentHp = currentHp ?? _calculateMaxHp(species.baseHp, level),
        atk = _calculateStat(species.baseAtk, level),
        def = _calculateStat(species.baseDef, level),
        spa = _calculateStat(species.baseSpA, level),
        spd = _calculateStat(species.baseSpD, level),
        spe = _calculateStat(species.baseSpe, level);

  static int _calculateMaxHp(int base, int lvl) {
    // Standard Pokémon Gen 4 HP formula assuming 31 IV & 0 EV
    return (((2 * base + 31) * lvl) ~/ 100) + lvl + 10;
  }

  static int _calculateStat(int base, int lvl) {
    // Standard Pokémon Gen 4 Stat formula
    return (((2 * base + 31) * lvl) ~/ 100) + 5;
  }

  static double _stageMultiplier(int stage) {
    final s = stage.clamp(-6, 6);
    return s >= 0 ? (2 + s) / 2.0 : 2.0 / (2 - s);
  }

  int get effectiveAtk => (atk * _stageMultiplier(atkStage)).round().clamp(1, 9999);
  int get effectiveDef => (def * _stageMultiplier(defStage)).round().clamp(1, 9999);
  int get effectiveSpa => (spa * _stageMultiplier(spaStage)).round().clamp(1, 9999);
  int get effectiveSpd => (spd * _stageMultiplier(spdStage)).round().clamp(1, 9999);
  int get effectiveSpe {
    double base = spe * _stageMultiplier(speStage);
    if (status == StatusCondition.paralysis) {
      base *= 0.5;
    }
    return base.round().clamp(1, 9999);
  }

  bool get isFainted => currentHp <= 0;
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  int get expForNextLevel => (level * level * level); // Medium-fast curve

  /// Applies a stat stage change (-6 to +6) and returns the actual delta applied.
  int modifyStatStage(String statTarget, int delta) {
    int before;
    int after;
    switch (statTarget) {
      case 'atk':
        before = atkStage;
        atkStage = (atkStage + delta).clamp(-6, 6);
        after = atkStage;
        break;
      case 'def':
        before = defStage;
        defStage = (defStage + delta).clamp(-6, 6);
        after = defStage;
        break;
      case 'spa':
        before = spaStage;
        spaStage = (spaStage + delta).clamp(-6, 6);
        after = spaStage;
        break;
      case 'spd':
        before = spdStage;
        spdStage = (spdStage + delta).clamp(-6, 6);
        after = spdStage;
        break;
      case 'spe':
        before = speStage;
        speStage = (speStage + delta).clamp(-6, 6);
        after = speStage;
        break;
      default:
        return 0;
    }
    return after - before;
  }

  void recalculateStats() {
    int oldMax = maxHp;
    maxHp = _calculateMaxHp(species.baseHp, level);
    currentHp = (currentHp + (maxHp - oldMax)).clamp(0, maxHp);
    atk = _calculateStat(species.baseAtk, level);
    def = _calculateStat(species.baseDef, level);
    spa = _calculateStat(species.baseSpA, level);
    spd = _calculateStat(species.baseSpD, level);
    spe = _calculateStat(species.baseSpe, level);
  }

  bool gainExp(int amount) {
    currentExp += amount;
    bool leveledUp = false;
    while (currentExp >= expForNextLevel && level < 100) {
      level++;
      leveledUp = true;
      recalculateStats();
    }
    return leveledUp;
  }

  bool checkCanEvolve() {
    return species.evolutionLevel != null &&
        species.evolutionSpeciesId != null &&
        level >= species.evolutionLevel!;
  }

  PokemonSpecies? evolve(PokemonSpecies nextSpecies, List<Move> newMoves) {
    if (nickname == species.name) {
      nickname = nextSpecies.name;
    }
    species = nextSpecies;
    if (newMoves.isNotEmpty) {
      moves = newMoves.take(4).toList();
    }
    recalculateStats();
    return species;
  }

  void resetBattleStateAndHeal() {
    currentHp = maxHp;
    status = StatusCondition.none;
    atkStage = 0;
    defStage = 0;
    spaStage = 0;
    spdStage = 0;
    speStage = 0;
    for (var m in moves) {
      m.currentPp = m.maxPp;
    }
  }

  void healFull() => resetBattleStateAndHeal();
}
