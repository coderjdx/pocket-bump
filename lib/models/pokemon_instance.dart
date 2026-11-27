import 'dart:math';
import 'ability.dart';
import 'pokemon_gender.dart';
import 'pokemon_nature.dart';
import 'pokemon_species.dart';
import 'pokemon_type.dart';
import 'move.dart';
import '../services/pokedex_database.dart';
import '../services/time_of_day_service.dart';

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
  bool hasCustomNickname;
  String? originalTrainerName;
  String? originalTrainerId; // Reserved for live trainer accounts
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
  StatusCondition _status;
  int sleepTurnsRemaining = 0;
  StatusCondition get status => _status;
  set status(StatusCondition value) {
    _status = value;
    if (value != StatusCondition.sleep) {
      hasNightmare = false;
      sleepTurnsRemaining = 0;
    }
  }
  String? heldItemId;
  String caughtBall;
  final bool isShiny;
  String abilityId;
  int abilitySlot; // 1 = standard slot 1, 2 = standard slot 2, 3 = Hidden Ability
  PokemonNature nature;
  int hpIv;
  int atkIv;
  int defIv;
  int spaIv;
  int spdIv;
  int speIv;
  PokemonGender gender;
  int friendship;
  String originRegion;
  String? formId;

  // In-battle stat stages (-6 to +6)
  int atkStage = 0;
  int defStage = 0;
  int spaStage = 0;
  int spdStage = 0;
  int speStage = 0;
  int accStage = 0;
  int evaStage = 0;

  // Transient in-battle multi-stage & volatile state (reset on switch/KO/exit)
  String? activeAbilityId;
  bool flashFireBoosted = false;
  bool consumedHeldItemForUnburden = false;
  String? consumedBerryIdForHarvest;
  bool isProtectedThisTurn = false;
  bool isEnduringThisTurn = false;
  int consecutiveProtectCount = 0;
  bool isTaunted = false;
  int tauntTurnsRemaining = 0;
  bool isIngrained = false;
  bool hasAquaRing = false;
  bool hasMagnetRise = false;
  int magnetRiseTurnsRemaining = 0;
  bool isYawnDrowsy = false;
  bool hasDestinyBond = false;
  int perishTurnsRemaining = 0;
  bool actedFirstThisTurn = false;
  int lastDamageTakenThisTurn = 0;
  String? lastMoveUsedId;
  String? encoredMoveId;
  int encoreTurnsRemaining = 0;
  String? chargingMoveId;
  bool isUnderground = false;
  bool needsRecharge = false;
  int bideTurnsRemaining = 0;
  int bideDamageStored = 0;
  String? rampageMoveId;
  int rampageTurnsRemaining = 0;
  int rolloutTurnsRemaining = 0;
  int rolloutHitCount = 0;
  int trappedTurnsRemaining = 0;
  String? trappedByMoveId;
  String? trappedByMoveName;
  bool isConfused = false;
  int confusionTurnsRemaining = 0;
  bool isSeeded = false;
  bool hasNightmare = false;
  bool isBadlyPoisoned = false;
  int toxicCounter = 1;
  int substituteHp = 0;
  bool flinchedThisTurn = false;
  int turnsActiveInBattle = 0;
  int lastPhysicalDamageTakenThisTurn = 0;
  int lastSpecialDamageTakenThisTurn = 0;
  int consecutiveFuryCutterHits = 0;
  bool hasFocusEnergy = false;
  int sureHitAgainstTurns = 0;
  bool isIdentified = false;
  bool isMeanLookTrapped = false;
  bool isTormented = false;
  String? disabledMoveId;
  int disableTurnsRemaining = 0;
  bool isRoostedThisTurn = false;
  bool isChargedElectric = false;
  bool hasMagicCoatThisTurn = false;
  bool isImprisoning = false;
  bool hasGrudge = false;
  bool helpingHandBoosted = false;
  List<PokemonType>? activeTypesOverride;
  List<Move>? transformedMoves;
  Map<String, int>? transformedBaseStats;
  int stockpileCount = 0;

  List<PokemonType> get effectiveTypes => activeTypesOverride ?? species.types;
  List<Move> get activeMoves => transformedMoves ?? moves;

  int get combatBaseAtk => transformedBaseStats?['atk'] ?? atk;
  int get combatBaseDef => transformedBaseStats?['def'] ?? def;
  int get combatBaseSpa => transformedBaseStats?['spa'] ?? spa;
  int get combatBaseSpd => transformedBaseStats?['spd'] ?? spd;
  int get combatBaseSpe => transformedBaseStats?['spe'] ?? spe;

  bool get hasForcedTurnAction =>
      needsRecharge ||
      chargingMoveId != null ||
      bideTurnsRemaining > 0 ||
      (rampageMoveId != null && rampageTurnsRemaining > 0) ||
      rolloutTurnsRemaining > 0;

  String? get forcedMoveId {
    if (needsRecharge) return 'recharge';
    if (chargingMoveId != null) return chargingMoveId;
    if (bideTurnsRemaining > 0) return 'bide';
    if (rampageMoveId != null && rampageTurnsRemaining > 0) {
      return rampageMoveId;
    }
    if (rolloutTurnsRemaining > 0) return 'rollout';
    return null;
  }

  String get forcedActionLabel {
    if (needsRecharge) return 'RECHARGE TURN';
    if (chargingMoveId == 'dig') return 'DIG • STRIKE';
    if (chargingMoveId != null) {
      final matched = moves.where((m) => m.id == chargingMoveId).toList();
      final moveTitle = matched.isNotEmpty
          ? matched.first.name.toUpperCase()
          : chargingMoveId!.replaceAll('_', ' ').toUpperCase();
      return 'UNLEASH $moveTitle';
    }
    if (bideTurnsRemaining > 1) return 'BIDE • STORING';
    if (bideTurnsRemaining == 1) return 'BIDE • UNLEASH';
    if (rampageMoveId != null && rampageTurnsRemaining > 0) {
      final matched = moves.where((m) => m.id == rampageMoveId).toList();
      final moveTitle = matched.isNotEmpty
          ? matched.first.name.toUpperCase()
          : rampageMoveId!.toUpperCase();
      return '$moveTitle ($rampageTurnsRemaining LEFT)';
    }
    if (rolloutTurnsRemaining > 0) {
      return 'ROLLOUT ($rolloutTurnsRemaining LEFT)';
    }
    return 'CONTINUE';
  }

  String get effectiveAbilityId => activeAbilityId ?? abilityId;
  bool get isHiddenAbility =>
      abilitySlot == 3 && species.hiddenAbilityId != null;
  AbilityDefinition? get abilityDefinition => AbilityDatabase.byId(abilityId);
  AbilityDefinition? get effectiveAbilityDefinition =>
      AbilityDatabase.byId(effectiveAbilityId);

  bool get canSetNickname => !hasCustomNickname;

  /// Permanently sets this Pokémon's nickname. Once assigned, it cannot be changed.
  bool setPermanentNickname(String rawName) {
    if (hasCustomNickname) return false;
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return false;
    nickname = trimmed.length > 14 ? trimmed.substring(0, 14) : trimmed;
    hasCustomNickname = true;
    return true;
  }

  /// Displays the Original Trainer (and future live account ID once available).
  String originalTrainerDisplay({String? fallbackName}) {
    final trimmedName = originalTrainerName?.trim();
    final String baseName = (trimmedName != null && trimmedName.isNotEmpty)
        ? trimmedName
        : ((fallbackName != null && fallbackName.trim().isNotEmpty)
            ? fallbackName.trim()
            : 'Unknown');
    final trimmedId = originalTrainerId?.trim();
    if (trimmedId != null && trimmedId.isNotEmpty) {
      return '$baseName (#$trimmedId)';
    }
    return baseName;
  }

  static ({int slot, String id}) rollAbilityForSpecies(
    PokemonSpecies species, {
    double hiddenChance = 0.02,
    Random? rng,
  }) {
    final random = rng ?? Random();
    if (species.hiddenAbilityId != null &&
        hiddenChance > 0 &&
        random.nextDouble() < hiddenChance) {
      return (slot: 3, id: species.hiddenAbilityId!);
    }
    if (species.abilitySlot2Id != null && random.nextBool()) {
      return (slot: 2, id: species.abilitySlot2Id!);
    }
    return (slot: 1, id: species.abilitySlot1Id);
  }

  static Map<String, int> rollIvs({
    int guaranteedPerfectCount = 0,
    Random? rng,
  }) {
    final random = rng ?? Random();
    final ivs = <String, int>{
      'hp': random.nextInt(32),
      'atk': random.nextInt(32),
      'def': random.nextInt(32),
      'spa': random.nextInt(32),
      'spd': random.nextInt(32),
      'spe': random.nextInt(32),
    };
    if (guaranteedPerfectCount > 0) {
      final keys = ivs.keys.toList()..shuffle(random);
      for (int i = 0; i < guaranteedPerfectCount.clamp(0, 6); i++) {
        ivs[keys[i]] = 31;
      }
    }
    return ivs;
  }

  PokemonInstance({
    required this.species,
    String? nickname,
    bool? hasCustomNickname,
    this.originalTrainerName,
    this.originalTrainerId,
    this.level = 5,
    int? currentHp,
    List<Move>? moves,
    List<String>? learnedMoveIds,
    int? currentExp,
    StatusCondition status = StatusCondition.none,
    this.heldItemId,
    this.caughtBall = 'poke_ball',
    bool isShiny = false,
    String? abilityId,
    int? abilitySlot,
    PokemonNature? nature,
    int? hpIv,
    int? atkIv,
    int? defIv,
    int? spaIv,
    int? spdIv,
    int? speIv,
    PokemonGender? gender,
    int? friendship,
    String? originRegion,
    this.formId,
    Random? rng,
  })  : _status = status,
        isShiny = isShiny && species.isShinyEligible,
        nickname = (nickname != null && nickname.trim().isNotEmpty)
            ? nickname.trim()
            : species.name,
        hasCustomNickname = hasCustomNickname ?? false,
        abilitySlot = abilitySlot ??
            (abilityId != null
                ? species.slotForAbility(abilityId)
                : rollAbilityForSpecies(species, rng: rng).slot),
        abilityId = '',
        nature = nature ?? PokemonNatureExtension.random(rng),
        hpIv = (hpIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        atkIv = (atkIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        defIv = (defIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        spaIv = (spaIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        spdIv = (spdIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        speIv = (speIv ?? (rng ?? Random()).nextInt(32)).clamp(0, 31),
        gender = gender ?? PokemonGenderExtension.rollForSpeciesId(species.id, rng),
        friendship = (friendship ?? 70).clamp(0, 255),
        originRegion = (originRegion != null && originRegion.trim().isNotEmpty)
            ? originRegion.trim()
            : 'kanto',
        moves = (moves ?? []).take(4).toList(),
        learnedMoveIds = <String>[],
        currentExp = currentExp ?? ((level - 1) * (level - 1) * (level - 1)),
        maxHp = 10,
        currentHp = 10,
        atk = 5,
        def = 5,
        spa = 5,
        spd = 5,
        spe = 5 {
    maxHp = _calculateMaxHp(species.baseHp, level, iv: this.hpIv);
    currentHp = (currentHp ?? maxHp).clamp(0, maxHp);
    atk = _calculateStat(species.baseAtk, level,
        iv: this.atkIv, natureMult: this.nature.multiplierFor('atk'));
    def = _calculateStat(species.baseDef, level,
        iv: this.defIv, natureMult: this.nature.multiplierFor('def'));
    spa = _calculateStat(species.baseSpA, level,
        iv: this.spaIv, natureMult: this.nature.multiplierFor('spa'));
    spd = _calculateStat(species.baseSpD, level,
        iv: this.spdIv, natureMult: this.nature.multiplierFor('spd'));
    spe = _calculateStat(species.baseSpe, level,
        iv: this.speIv, natureMult: this.nature.multiplierFor('spe'));
    this.abilityId = abilityId ?? species.abilityForSlot(this.abilitySlot);
    if (AbilityDatabase.byId(this.abilityId) == null) {
      this.abilitySlot = 1;
      this.abilityId = species.abilitySlot1Id;
    }
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

  static int _calculateMaxHp(int base, int lvl, {int iv = 31}) {
    // Standard Pokémon Gen 4 HP formula with per-Pokémon IV & 0 EV
    return (((2 * base + iv) * lvl) ~/ 100) + lvl + 10;
  }

  static int _calculateStat(
    int base,
    int lvl, {
    int iv = 31,
    double natureMult = 1.0,
  }) {
    // Standard Pokémon Gen 4 Stat formula with IV & Nature modifier
    final int raw = (((2 * base + iv) * lvl) ~/ 100) + 5;
    return (raw * natureMult).floor().clamp(1, 9999);
  }

  int get ivTotal => hpIv + atkIv + defIv + spaIv + spdIv + speIv;

  String get ivRatingLabel {
    if (ivTotal >= 151) return 'Amazing';
    if (ivTotal >= 121) return 'Great';
    if (ivTotal >= 91) return 'Good';
    return 'Decent';
  }

  void addFriendship(int delta) {
    if (delta == 0) return;
    friendship = (friendship + delta).clamp(0, 255);
  }

  static const List<PokemonType> _hiddenPowerTypes = [
    PokemonType.fighting,
    PokemonType.flying,
    PokemonType.poison,
    PokemonType.ground,
    PokemonType.rock,
    PokemonType.bug,
    PokemonType.ghost,
    PokemonType.steel,
    PokemonType.fire,
    PokemonType.water,
    PokemonType.grass,
    PokemonType.electric,
    PokemonType.psychic,
    PokemonType.ice,
    PokemonType.dragon,
    PokemonType.dark,
  ];

  PokemonType get hiddenPowerType {
    final int bit0 = hpIv & 1;
    final int bit1 = atkIv & 1;
    final int bit2 = defIv & 1;
    final int bit3 = speIv & 1;
    final int bit4 = spaIv & 1;
    final int bit5 = spdIv & 1;
    final int rawSum =
        bit0 + 2 * bit1 + 4 * bit2 + 8 * bit3 + 16 * bit4 + 32 * bit5;
    final int idx = ((rawSum * 15) ~/ 63).clamp(0, _hiddenPowerTypes.length - 1);
    return _hiddenPowerTypes[idx];
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

  int get effectiveAtk => (combatBaseAtk * _stageMultiplier(atkStage)).round().clamp(1, 9999);
  int get effectiveDef => (combatBaseDef * _stageMultiplier(defStage)).round().clamp(1, 9999);
  int get effectiveSpa => (combatBaseSpa * _stageMultiplier(spaStage)).round().clamp(1, 9999);
  int get effectiveSpd => (combatBaseSpd * _stageMultiplier(spdStage)).round().clamp(1, 9999);
  int get effectiveSpe {
    double base = combatBaseSpe * _stageMultiplier(speStage);
    if (status == StatusCondition.paralysis && effectiveAbilityId != 'quick_feet') {
      base *= 0.5;
    }
    if (status != StatusCondition.none && effectiveAbilityId == 'quick_feet') {
      base *= 1.5;
    }
    if (consumedHeldItemForUnburden &&
        !hasHeldItem &&
        effectiveAbilityId == 'unburden') {
      base *= 2.0;
    }
    return base.round().clamp(1, 9999);
  }

  double get accuracyMultiplier {
    final s = accStage.clamp(-6, 6);
    return s >= 0 ? (3 + s) / 3.0 : 3.0 / (3 - s);
  }

  double get evasionMultiplier {
    final s = evaStage.clamp(-6, 6);
    return s >= 0 ? 3.0 / (3 + s) : (3 - s) / 3.0;
  }

  bool get isFainted => currentHp <= 0;
  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

  int get expForNextLevel => (level * level * level); // Medium-fast curve

  /// Applies a stat stage change (-6 to +6) and returns the actual delta applied.
  int modifyStatStage(String statTarget, int delta) {
    if (effectiveAbilityId == 'contrary') {
      delta = -delta;
    }
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
      case 'acc':
        before = accStage;
        accStage = (accStage + delta).clamp(-6, 6);
        after = accStage;
        break;
      case 'eva':
        before = evaStage;
        evaStage = (evaStage + delta).clamp(-6, 6);
        after = evaStage;
        break;
      default:
        return 0;
    }
    return after - before;
  }

  void recalculateStats() {
    int oldMax = maxHp;
    maxHp = _calculateMaxHp(species.baseHp, level, iv: hpIv);
    currentHp = (currentHp + (maxHp - oldMax)).clamp(0, maxHp);
    atk = _calculateStat(species.baseAtk, level,
        iv: atkIv, natureMult: nature.multiplierFor('atk'));
    def = _calculateStat(species.baseDef, level,
        iv: defIv, natureMult: nature.multiplierFor('def'));
    spa = _calculateStat(species.baseSpA, level,
        iv: spaIv, natureMult: nature.multiplierFor('spa'));
    spd = _calculateStat(species.baseSpD, level,
        iv: spdIv, natureMult: nature.multiplierFor('spd'));
    spe = _calculateStat(species.baseSpe, level,
        iv: speIv, natureMult: nature.multiplierFor('spe'));
  }

  void applyNatureMint(PokemonNature newNature) {
    nature = newNature;
    recalculateStats();
  }

  bool hyperTrainStat(String statKey) {
    switch (statKey) {
      case 'hp':
        if (hpIv >= 31) return false;
        hpIv = 31;
        break;
      case 'atk':
        if (atkIv >= 31) return false;
        atkIv = 31;
        break;
      case 'def':
        if (defIv >= 31) return false;
        defIv = 31;
        break;
      case 'spa':
        if (spaIv >= 31) return false;
        spaIv = 31;
        break;
      case 'spd':
        if (spdIv >= 31) return false;
        spdIv = 31;
        break;
      case 'spe':
        if (speIv >= 31) return false;
        speIv = 31;
        break;
      default:
        return false;
    }
    recalculateStats();
    return true;
  }

  bool hyperTrainAll() {
    if (hpIv >= 31 &&
        atkIv >= 31 &&
        defIv >= 31 &&
        spaIv >= 31 &&
        spdIv >= 31 &&
        speIv >= 31) {
      return false;
    }
    hpIv = 31;
    atkIv = 31;
    defIv = 31;
    spaIv = 31;
    spdIv = 31;
    speIv = 31;
    recalculateStats();
    return true;
  }

  bool applyAbilityPatch() {
    if (species.hiddenAbilityId != null && abilitySlot != 3) {
      abilityId = species.hiddenAbilityId!;
      abilitySlot = 3;
      return true;
    }
    if (species.abilitySlot2Id != null &&
        species.abilitySlot2Id != species.abilitySlot1Id) {
      if (abilitySlot == 1) {
        abilityId = species.abilitySlot2Id!;
        abilitySlot = 2;
      } else {
        abilityId = species.abilitySlot1Id;
        abilitySlot = 1;
      }
      return true;
    }
    return false;
  }

  /// Levels a newly caught Legendary/Mythical boss down cleanly (e.g. Lv.99 -> Lv.50),
  /// syncing EXP, moves, stats, full HP, and clearing status/volatile effects.
  void resetToCatchLevel(int targetLevel) {
    level = targetLevel.clamp(1, 100);
    currentExp = level <= 1 ? 0 : (level - 1) * (level - 1) * (level - 1);
    final freshMoves = PokedexDatabase.movesForSpeciesAtLevel(species, level);
    moves = freshMoves;
    learnedMoveIds.clear();
    for (final id in PokedexDatabase.learnedMoveIdsUpToLevel(species, level)) {
      recordLearnedMoveId(id);
    }
    for (final m in moves) {
      recordLearnedMoveId(m.id);
    }
    clearVolatileBattleState();
    status = StatusCondition.none;
    maxHp = _calculateMaxHp(species.baseHp, level, iv: hpIv);
    currentHp = maxHp;
    atk = _calculateStat(species.baseAtk, level,
        iv: atkIv, natureMult: nature.multiplierFor('atk'));
    def = _calculateStat(species.baseDef, level,
        iv: defIv, natureMult: nature.multiplierFor('def'));
    spa = _calculateStat(species.baseSpA, level,
        iv: spaIv, natureMult: nature.multiplierFor('spa'));
    spd = _calculateStat(species.baseSpD, level,
        iv: spdIv, natureMult: nature.multiplierFor('spd'));
    spe = _calculateStat(species.baseSpe, level,
        iv: speIv, natureMult: nature.multiplierFor('spe'));
  }

  void recordLearnedMoveId(String moveId) {
    if (moveId.isEmpty || !PokedexDatabase.moves.containsKey(moveId)) return;
    if (!learnedMoveIds.contains(moveId)) {
      learnedMoveIds.add(moveId);
    }
  }

  /// All moves this Pokémon can remember or swap in: every level-up move in
  /// its evolutionary line up to its current level plus any TMs or replaced
  /// moves recorded on this instance, excluding its currently active 4 moves.
  List<Move> get rememberedReserveMoves {
    final activeIds = moves.map((m) => m.id).toSet();
    final List<String> poolIds = [];
    void addUnique(String id) {
      if (id.isEmpty || !PokedexDatabase.moves.containsKey(id)) return;
      if (!poolIds.contains(id)) {
        poolIds.add(id);
      }
    }

    for (final id
        in PokedexDatabase.learnedMoveIdsUpToLevel(species, level)) {
      recordLearnedMoveId(id);
      addUnique(id);
    }
    for (final id in learnedMoveIds) {
      addUnique(id);
    }

    final List<Move> reserve = [];
    for (final id in poolIds) {
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

  int? resolveLevelUpEvolutionSpeciesId({DateTime? now}) {
    for (final rule in species.evolutionRules) {
      if (rule.itemId != null || rule.viaTrade) continue;
      if (!PokedexDatabase.species.containsKey(rule.targetSpeciesId)) continue;
      if (rule.minLevel != null && level < rule.minLevel!) continue;
      if (rule.minFriendship != null && friendship < rule.minFriendship!) {
        continue;
      }
      if (rule.requiresDaytime && !TimeOfDayService.isDaytime(now)) continue;
      if (rule.requiresNighttime && !TimeOfDayService.isNighttime(now)) {
        continue;
      }
      if (rule.requiredGender != null && gender != rule.requiredGender) {
        continue;
      }
      if (rule.requiredMoveId != null &&
          !moves.any((m) => m.id == rule.requiredMoveId)) {
        continue;
      }
      if (rule.statCompare != null) {
        switch (rule.statCompare!) {
          case EvolutionStatCompare.atkGreaterThanDef:
            if (atk <= def) continue;
            break;
          case EvolutionStatCompare.defGreaterThanAtk:
            if (def <= atk) continue;
            break;
          case EvolutionStatCompare.atkEqualsDef:
            if (atk != def) continue;
            break;
        }
      }
      return rule.targetSpeciesId;
    }

    if (species.evolutionLevel != null &&
        species.evolutionSpeciesId != null &&
        level >= species.evolutionLevel! &&
        PokedexDatabase.species.containsKey(species.evolutionSpeciesId!)) {
      return species.evolutionSpeciesId;
    }
    return null;
  }

  bool checkCanEvolve() => resolveLevelUpEvolutionSpeciesId() != null;

  List<String> evolve(
    PokemonSpecies nextSpecies,
    List<Move> unlockedEvolutionMoves, {
    List<Move>? pendingMovesOut,
  }) {
    if (!hasCustomNickname) {
      nickname = nextSpecies.name;
    }
    species = nextSpecies;
    abilityId = nextSpecies.abilityForSlot(abilitySlot);
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

  void clearVolatileBattleState() {
    activeAbilityId = null;
    flashFireBoosted = false;
    consumedHeldItemForUnburden = false;
    consumedBerryIdForHarvest = null;
    isProtectedThisTurn = false;
    isEnduringThisTurn = false;
    consecutiveProtectCount = 0;
    isTaunted = false;
    tauntTurnsRemaining = 0;
    isIngrained = false;
    hasAquaRing = false;
    hasMagnetRise = false;
    magnetRiseTurnsRemaining = 0;
    isYawnDrowsy = false;
    hasDestinyBond = false;
    perishTurnsRemaining = 0;
    actedFirstThisTurn = false;
    lastDamageTakenThisTurn = 0;
    lastMoveUsedId = null;
    encoredMoveId = null;
    encoreTurnsRemaining = 0;
    chargingMoveId = null;
    isUnderground = false;
    needsRecharge = false;
    bideTurnsRemaining = 0;
    bideDamageStored = 0;
    rampageMoveId = null;
    rampageTurnsRemaining = 0;
    rolloutTurnsRemaining = 0;
    rolloutHitCount = 0;
    trappedTurnsRemaining = 0;
    trappedByMoveId = null;
    trappedByMoveName = null;
    isConfused = false;
    confusionTurnsRemaining = 0;
    isSeeded = false;
    hasNightmare = false;
    toxicCounter = 1;
    substituteHp = 0;
    flinchedThisTurn = false;
    turnsActiveInBattle = 0;
    lastPhysicalDamageTakenThisTurn = 0;
    lastSpecialDamageTakenThisTurn = 0;
    consecutiveFuryCutterHits = 0;
    hasFocusEnergy = false;
    sureHitAgainstTurns = 0;
    isIdentified = false;
    isMeanLookTrapped = false;
    isTormented = false;
    disabledMoveId = null;
    disableTurnsRemaining = 0;
    isRoostedThisTurn = false;
    isChargedElectric = false;
    hasMagicCoatThisTurn = false;
    isImprisoning = false;
    hasGrudge = false;
    helpingHandBoosted = false;
    activeTypesOverride = null;
    transformedMoves = null;
    transformedBaseStats = null;
    stockpileCount = 0;
  }

  void resetStatStages() {
    atkStage = 0;
    defStage = 0;
    spaStage = 0;
    spdStage = 0;
    speStage = 0;
    accStage = 0;
    evaStage = 0;
    clearVolatileBattleState();
  }

  void resetBattleStateAndHeal() {
    currentHp = maxHp;
    status = StatusCondition.none;
    isBadlyPoisoned = false;
    resetStatStages();
    for (var m in moves) {
      m.currentPp = m.maxPp;
    }
  }

  void healFull() => resetBattleStateAndHeal();

  bool get hasHeldItem => heldItemId != null && heldItemId!.isNotEmpty;

  String get spriteAsset => isShiny ? species.shinySpriteAsset : species.spriteAsset;
  String get backSpriteAsset =>
      isShiny ? species.shinyBackSpriteAsset : species.backSpriteAsset;
  String get spriteUrl => isShiny ? species.shinySpriteUrl : species.spriteUrl;
  String get backSpriteUrl =>
      isShiny ? species.shinyBackSpriteUrl : species.backSpriteUrl;
  String get staticSpriteUrl =>
      isShiny ? species.staticShinySpriteUrl : species.staticSpriteUrl;
  String get staticBackSpriteUrl =>
      isShiny ? species.staticShinyBackSpriteUrl : species.staticBackSpriteUrl;
  String get artworkUrl =>
      isShiny ? species.shinyArtworkUrl : species.artworkUrl;

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
      'hasCustomNickname': hasCustomNickname,
      'originalTrainerName': originalTrainerName,
      'originalTrainerId': originalTrainerId,
      'level': level,
      'currentHp': currentHp,
      'currentExp': currentExp,
      'status': status.name,
      'sleepTurnsRemaining': sleepTurnsRemaining,
      'heldItemId': heldItemId,
      'caughtBall': caughtBall,
      'isShiny': isShiny,
      'abilityId': abilityId,
      'abilitySlot': abilitySlot,
      'nature': nature.name,
      'hpIv': hpIv,
      'atkIv': atkIv,
      'defIv': defIv,
      'spaIv': spaIv,
      'spdIv': spdIv,
      'speIv': speIv,
      'gender': gender.name,
      'friendship': friendship,
      'originRegion': originRegion,
      if (formId != null) 'formId': formId,
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

    final int restoredHpIv = (json['hpIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final int restoredAtkIv = (json['atkIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final int restoredDefIv = (json['defIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final int restoredSpaIv = (json['spaIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final int restoredSpdIv = (json['spdIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final int restoredSpeIv = (json['speIv'] as num?)?.toInt().clamp(0, 31) ?? 31;
    final PokemonNature restoredNature =
        PokemonNatureExtension.fromStorageKey(json['nature'] as String?);
    final PokemonGender restoredGender = json['gender'] is String
        ? PokemonGenderExtension.fromStorageKey(json['gender'] as String?)
        : PokemonGenderExtension.rollForSpeciesId(spec.id);
    final int restoredFriendship =
        ((json['friendship'] as num?)?.toInt() ?? 70).clamp(0, 255);
    final String restoredOriginRegion =
        (json['originRegion'] as String?)?.trim().isNotEmpty == true
            ? (json['originRegion'] as String).trim()
            : 'kanto';
    final String? restoredFormId =
        (json['formId'] as String?)?.trim().isNotEmpty == true
            ? (json['formId'] as String).trim()
            : null;

    final int computedMaxHp = _calculateMaxHp(spec.baseHp, lvl, iv: restoredHpIv);
    final int rawHp = (json['currentHp'] as num?)?.toInt() ?? computedMaxHp;
    final int hp = rawHp.clamp(0, computedMaxHp);

    final String? statusName = json['status'] as String?;
    final StatusCondition restoredStatus = StatusCondition.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => StatusCondition.none,
    );

    final rawNickname = json['nickname'] as String?;
    final String resolvedNickname =
        (rawNickname != null && rawNickname.trim().isNotEmpty)
            ? rawNickname.trim()
            : spec.name;
    final bool restoredHasCustomNickname = json['hasCustomNickname'] is bool
        ? json['hasCustomNickname'] == true
        : (rawNickname != null &&
            rawNickname.trim().isNotEmpty &&
            rawNickname.trim() != spec.name);
    final String? rawOtName = json['originalTrainerName'] as String?;
    final String? rawOtId = json['originalTrainerId'] as String?;
    final String? heldItem = json['heldItemId'] as String?;
    final String caughtBall = (json['caughtBall'] as String?) ?? 'poke_ball';
    final bool isShiny = json['isShiny'] == true;
    final String? rawAbilityId = json['abilityId'] as String?;
    final int? rawAbilitySlot = (json['abilitySlot'] as num?)?.toInt();
    late final int resolvedSlot;
    late final String resolvedAbilityId;
    if (rawAbilityId != null &&
        rawAbilityId.isNotEmpty &&
        AbilityDatabase.byId(rawAbilityId) != null) {
      resolvedAbilityId = rawAbilityId;
      resolvedSlot = (rawAbilitySlot != null && rawAbilitySlot >= 1 && rawAbilitySlot <= 3)
          ? rawAbilitySlot
          : spec.slotForAbility(rawAbilityId);
    } else {
      // Backfill Ability for existing saved Pokémon (including ~2% Hidden Ability chance)
      final rolled = rollAbilityForSpecies(spec, hiddenChance: 0.02);
      resolvedSlot = rolled.slot;
      resolvedAbilityId = rolled.id;
    }
    final rawLearned = json['learnedMoveIds'] as List<dynamic>?;
    final List<String>? savedLearnedIds =
        rawLearned?.whereType<String>().toList();
    final instance = PokemonInstance(
      species: spec,
      nickname: resolvedNickname,
      hasCustomNickname: restoredHasCustomNickname,
      originalTrainerName:
          (rawOtName != null && rawOtName.trim().isNotEmpty)
              ? rawOtName.trim()
              : null,
      originalTrainerId:
          (rawOtId != null && rawOtId.trim().isNotEmpty)
              ? rawOtId.trim()
              : null,
      level: lvl,
      currentHp: hp,
      moves: restoredMoves,
      learnedMoveIds: savedLearnedIds,
      currentExp: exp,
      status: restoredStatus,
      heldItemId: heldItem,
      caughtBall: caughtBall,
      isShiny: isShiny,
      abilityId: resolvedAbilityId,
      abilitySlot: resolvedSlot,
      nature: restoredNature,
      hpIv: restoredHpIv,
      atkIv: restoredAtkIv,
      defIv: restoredDefIv,
      spaIv: restoredSpaIv,
      spdIv: restoredSpdIv,
      speIv: restoredSpeIv,
      gender: restoredGender,
      friendship: restoredFriendship,
      originRegion: restoredOriginRegion,
      formId: restoredFormId,
    );
    instance.sleepTurnsRemaining = restoredStatus == StatusCondition.sleep
        ? ((json['sleepTurnsRemaining'] as num?)?.toInt() ?? 2).clamp(1, 4)
        : 0;
    return instance;
  }
}
