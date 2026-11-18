import 'dart:math';
import 'pokemon_species.dart';
import 'move.dart';
import '../services/pokedex_database.dart';

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

class LevelUpResult {
  final bool leveledUp;
  final List<String> learnedMoves;
  final List<Move> pendingMoves;

  const LevelUpResult({
    required this.leveledUp,
    required this.learnedMoves,
    this.pendingMoves = const [],
  });
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
  List<String> learnedMoveIds;
  int currentExp;
  StatusCondition status;
  String? heldItemId;
  String caughtBall;

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
    List<String>? learnedMoveIds,
    int? currentExp,
    this.status = StatusCondition.none,
    this.heldItemId,
    this.caughtBall = 'poke_ball',
  })  : nickname = nickname ?? species.name,
        moves = (moves ?? []).take(4).toList(),
        learnedMoveIds = <String>[],
        currentExp = currentExp ?? ((level - 1) * (level - 1) * (level - 1)),
        maxHp = _calculateMaxHp(species.baseHp, level),
        currentHp = currentHp ?? _calculateMaxHp(species.baseHp, level),
        atk = _calculateStat(species.baseAtk, level),
        def = _calculateStat(species.baseDef, level),
        spa = _calculateStat(species.baseSpA, level),
        spd = _calculateStat(species.baseSpD, level),
        spe = _calculateStat(species.baseSpe, level) {
    if (learnedMoveIds != null) {
      for (final id in learnedMoveIds) {
        recordLearnedMoveId(id);
      }
    }
    for (final id in PokedexDatabase.learnedMoveIdsUpToLevel(species, level)) {
      recordLearnedMoveId(id);
    }
    for (final m in this.moves) {
      recordLearnedMoveId(m.id);
    }
  }

  static int _calculateMaxHp(int base, int lvl) {
    // Standard Pokémon Gen 4 HP formula assuming 31 IV & 0 EV
    return (((2 * base + 31) * lvl) ~/ 100) + lvl + 10;
  }

  static int _calculateStat(int base, int lvl) {
    // Standard Pokémon Gen 4 Stat formula
    return (((2 * base + 31) * lvl) ~/ 100) + 5;
  }

  /// Balanced Gen 5/7 EXP formula (midpoint between classic and boosted curves)
  static int calculateBattleExp({
    required PokemonInstance defeated,
    required int winnerLevel,
    required bool isTrainerBattle,
  }) {
    final double trainerMultiplier = isTrainerBattle ? 1.5 : 1.0;
    final double baseYield =
        (trainerMultiplier * defeated.species.baseExp * defeated.level) / 3.5;
    final double levelCurveScale = 1.0 + (defeated.level * 0.02);
    final double rawLevelFactor = pow(
      (2.0 * defeated.level + 10.0) / (defeated.level + winnerLevel + 10.0),
      2.25,
    ).toDouble();
    final double levelFactor = max(0.85, rawLevelFactor);
    return max(5, (baseYield * levelCurveScale * levelFactor).round());
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

  void recordLearnedMoveId(String moveId) {
    if (moveId.isEmpty || !PokedexDatabase.moves.containsKey(moveId)) return;
    if (!learnedMoveIds.contains(moveId)) {
      learnedMoveIds.add(moveId);
    }
  }

  /// Remembered moves this Pokémon has previously learned that are not currently active.
  List<Move> get rememberedReserveMoves {
    final activeIds = moves.map((m) => m.id).toSet();
    final List<Move> reserve = [];
    for (final id in learnedMoveIds) {
      if (activeIds.contains(id)) continue;
      final template = PokedexDatabase.moves[id];
      if (template != null) {
        reserve.add(template.copy());
      }
    }
    return reserve;
  }

  bool swapActiveMove(int activeSlotIndex, Move replacement) {
    if (activeSlotIndex < 0 || activeSlotIndex >= moves.length) return false;
    if (moves.any((m) => m.id == replacement.id)) return false;
    recordLearnedMoveId(moves[activeSlotIndex].id);
    recordLearnedMoveId(replacement.id);
    moves[activeSlotIndex] = replacement.copy();
    return true;
  }

  bool equipReserveMove(Move replacement) {
    if (moves.any((m) => m.id == replacement.id)) return false;
    recordLearnedMoveId(replacement.id);
    if (moves.length < 4) {
      moves.add(replacement.copy());
      return true;
    }
    return false;
  }

  void swapMoveSlots(int indexA, int indexB) {
    if (indexA < 0 ||
        indexA >= moves.length ||
        indexB < 0 ||
        indexB >= moves.length ||
        indexA == indexB) {
      return;
    }
    final tmp = moves[indexA];
    moves[indexA] = moves[indexB];
    moves[indexB] = tmp;
  }

  LevelUpResult gainExpWithLearnset(
    int amount,
    List<Move> Function(PokemonSpecies spec, int newLevel) unlockedLookup,
  ) {
    currentExp += amount;
    bool leveledUp = false;
    final List<String> learned = [];
    final List<Move> pending = [];

    while (currentExp >= expForNextLevel && level < 100) {
      level++;
      leveledUp = true;
      recalculateStats();

      final newMoves = unlockedLookup(species, level);
      for (final m in newMoves) {
        recordLearnedMoveId(m.id);
        final alreadyActive = moves.any((existing) => existing.id == m.id);
        final alreadyPending = pending.any((existing) => existing.id == m.id);
        if (alreadyActive || alreadyPending) continue;
        if (moves.length < 4) {
          moves.add(m);
          learned.add(m.name);
        } else {
          pending.add(m);
        }
      }
    }

    return LevelUpResult(
      leveledUp: leveledUp,
      learnedMoves: learned,
      pendingMoves: pending,
    );
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

  List<String> evolve(
    PokemonSpecies nextSpecies,
    List<Move> unlockedEvolutionMoves, {
    List<Move>? pendingMovesOut,
  }) {
    if (nickname == species.name) {
      nickname = nextSpecies.name;
    }
    species = nextSpecies;
    recalculateStats();

    for (final id
        in PokedexDatabase.learnedMoveIdsUpToLevel(nextSpecies, level)) {
      recordLearnedMoveId(id);
    }

    final List<String> learned = [];
    for (final m in unlockedEvolutionMoves) {
      recordLearnedMoveId(m.id);
      final alreadyActive = moves.any((existing) => existing.id == m.id);
      final alreadyPending =
          pendingMovesOut?.any((existing) => existing.id == m.id) ?? false;
      if (alreadyActive || alreadyPending) continue;
      if (moves.length < 4) {
        moves.add(m);
        learned.add(m.name);
      } else {
        pendingMovesOut?.add(m);
      }
    }
    return learned;
  }

  void resetStatStages() {
    atkStage = 0;
    defStage = 0;
    spaStage = 0;
    spdStage = 0;
    speStage = 0;
  }

  void resetBattleStateAndHeal() {
    currentHp = maxHp;
    status = StatusCondition.none;
    resetStatStages();
    for (var m in moves) {
      m.currentPp = m.maxPp;
    }
  }

  void healFull() => resetBattleStateAndHeal();

  bool get hasHeldItem => heldItemId != null && heldItemId!.isNotEmpty;

  void equipHeldItem(String id) {
    heldItemId = id;
  }

  String? unequipHeldItem() {
    final old = heldItemId;
    heldItemId = null;
    return old;
  }

  Map<String, dynamic> toJson() {
    return {
      'speciesId': species.id,
      'nickname': nickname,
      'level': level,
      'currentHp': currentHp,
      'currentExp': currentExp,
      'status': status.name,
      'heldItemId': heldItemId,
      'caughtBall': caughtBall,
      'learnedMoveIds': learnedMoveIds,
      'moves': moves
          .map((m) => {
                'id': m.id,
                'currentPp': m.currentPp,
              })
          .toList(),
    };
  }

  factory PokemonInstance.fromJson(Map<String, dynamic> json) {
    final int speciesId = (json['speciesId'] as num?)?.toInt() ?? 1;
    final spec = PokedexDatabase.species[speciesId] ?? PokedexDatabase.species[1]!;
    final int lvl = ((json['level'] as num?)?.toInt() ?? 5).clamp(1, 100);
    final int minExpForLevel = (lvl - 1) * (lvl - 1) * (lvl - 1);
    final int rawExp = (json['currentExp'] as num?)?.toInt() ?? minExpForLevel;
    final int exp = max(minExpForLevel, rawExp);

    final List<Move> restoredMoves = [];
    final rawMoves = json['moves'] as List<dynamic>? ?? const [];
    for (final item in rawMoves) {
      final String? moveId = item is Map ? item['id'] as String? : item as String?;
      final template = moveId != null ? PokedexDatabase.moves[moveId] : null;
      if (template != null) {
        final copy = template.copy();
        if (item is Map && item['currentPp'] is num) {
          copy.currentPp = (item['currentPp'] as num).toInt().clamp(0, copy.maxPp);
        }
        restoredMoves.add(copy);
      }
      if (restoredMoves.length >= 4) break;
    }
    if (restoredMoves.isEmpty) {
      restoredMoves.addAll(PokedexDatabase.movesForSpeciesAtLevel(spec, lvl));
    }

    final int computedMaxHp = _calculateMaxHp(spec.baseHp, lvl);
    final int rawHp = (json['currentHp'] as num?)?.toInt() ?? computedMaxHp;
    final int hp = rawHp.clamp(0, computedMaxHp);

    final String? statusName = json['status'] as String?;
    final StatusCondition restoredStatus = StatusCondition.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => StatusCondition.none,
    );

    final rawNickname = json['nickname'] as String?;
    final String? heldItem = json['heldItemId'] as String?;
    final String caughtBall = (json['caughtBall'] as String?) ?? 'poke_ball';
    final rawLearned = json['learnedMoveIds'] as List<dynamic>?;
    final List<String>? savedLearnedIds =
        rawLearned?.whereType<String>().toList();
    return PokemonInstance(
      species: spec,
      nickname: (rawNickname != null && rawNickname.trim().isNotEmpty)
          ? rawNickname
          : spec.name,
      level: lvl,
      currentHp: hp,
      moves: restoredMoves,
      learnedMoveIds: savedLearnedIds,
      currentExp: exp,
      status: restoredStatus,
      heldItemId: heldItem,
      caughtBall: caughtBall,
    );
  }
}
