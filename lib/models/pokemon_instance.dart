import 'dart:math';
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

class PokemonInstance {
  final PokemonSpecies species;
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

  PokemonInstance({
    required this.species,
    String? nickname,
    this.level = 5,
    int? currentHp,
    List<Move>? moves,
    this.currentExp = 0,
    this.status = StatusCondition.none,
  })  : nickname = nickname ?? species.name,
        moves = moves ?? [],
        maxHp = _calculateMaxHp(species.baseHp, level),
        currentHp = currentHp ?? _calculateMaxHp(species.baseHp, level),
        atk = _calculateStat(species.baseAtk, level),
        def = _calculateStat(species.baseDef, level),
        spa = _calculateStat(species.baseSpA, level),
        spd = _calculateStat(species.baseSpD, level),
        spe = _calculateStat(species.baseSpe, level);

  static int _calculateMaxHp(int base, int lvl) {
    // Standard Pokémon Gen 4 HP formula assuming 31 IV & 0 EV for simplicity
    return (((2 * base + 31) * lvl) ~/ 100) + lvl + 10;
  }

  static int _calculateStat(int base, int lvl) {
    // Standard Pokémon Gen 4 Stat formula
    return (((2 * base + 31) * lvl) ~/ 100) + 5;
  }

  bool get isFainted => currentHp <= 0;
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  int get expForNextLevel => (level * level * level); // Medium-fast curve

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

  void healFull() {
    currentHp = maxHp;
    status = StatusCondition.none;
    for (var m in moves) {
      m.currentPp = m.maxPp;
    }
  }
}
