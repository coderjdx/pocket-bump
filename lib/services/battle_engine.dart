import 'dart:math';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import 'pokedex_database.dart';

enum BattleActionType {
  fight,
  switchPokemon,
  useItem,
  run,
}

class BattleAction {
  final BattleActionType type;
  final Move? move;
  final PokemonInstance? switchTarget;
  final String? itemId;

  BattleAction.fight(this.move)
      : type = BattleActionType.fight,
        switchTarget = null,
        itemId = null;

  BattleAction.switchPokemon(this.switchTarget)
      : type = BattleActionType.switchPokemon,
        move = null,
        itemId = null;

  BattleAction.useItem(this.itemId)
      : type = BattleActionType.useItem,
        move = null,
        switchTarget = null;

  BattleAction.run()
      : type = BattleActionType.run,
        move = null,
        switchTarget = null,
        itemId = null;
}

class BattleStepEvent {
  final String message;
  final bool isPlayerActor;
  final String? moveId;
  final PokemonType? moveType;
  final MoveCategory? moveCategory;
  final int damageDealt;
  final int targetHpAfter;
  final bool isCrit;
  final double effectiveness;
  final String? statChangedLabel;
  final bool statTargetIsSelf;
  final String? statusInflictedLabel;
  final bool targetFainted;
  final bool isMiss;
  final bool isStatusTick;
  final int hitNumber;
  final int totalHits;
  final bool isChargeTurn;
  final bool submergeActorAfter;
  final bool surfaceActorOnAttack;
  final bool isMultiHitSummary;
  final bool hideMoveVfx;
  final bool isSelfDamage;
  final int healAmount;

  const BattleStepEvent({
    required this.message,
    required this.isPlayerActor,
    this.moveId,
    this.moveType,
    this.moveCategory,
    this.damageDealt = 0,
    this.targetHpAfter = 0,
    this.isCrit = false,
    this.effectiveness = 1.0,
    this.statChangedLabel,
    this.statTargetIsSelf = false,
    this.statusInflictedLabel,
    this.targetFainted = false,
    this.isMiss = false,
    this.isStatusTick = false,
    this.hitNumber = 0,
    this.totalHits = 0,
    this.isChargeTurn = false,
    this.submergeActorAfter = false,
    this.surfaceActorOnAttack = false,
    this.isMultiHitSummary = false,
    this.hideMoveVfx = false,
    this.isSelfDamage = false,
    this.healAmount = 0,
  });
}

class BattleEngine {
  static final Random _rng = Random();

  /// Resolves the move that [mon] will actually perform this turn, honoring
  /// any in-progress multi-stage move (Dig, Solar Beam, Bide, Thrash, Rollout).
  static Move? resolveEffectiveMove(PokemonInstance mon, Move? selectedMove) {
    final String? forcedId = mon.forcedMoveId;
    if (forcedId == null || forcedId == 'recharge') {
      return selectedMove;
    }
    for (final m in mon.moves) {
      if (m.id == forcedId) return m;
    }
    final dbMove = PokedexDatabase.moves[forcedId];
    return dbMove?.copy() ?? selectedMove;
  }

  /// Selects a move for an AI-controlled opponent.
  /// Self-KO moves (`self_destruct`, `explosion`) are withheld until HP is in the red (<= 20%).
  static Move? selectOpponentMove(PokemonInstance opponent, {Random? rng}) {
    if (opponent.moves.isEmpty) return null;
    final withPp = opponent.moves.where((m) => m.currentPp > 0).toList();
    final List<Move> available =
        withPp.isNotEmpty ? withPp : List<Move>.from(opponent.moves);

    final bool inRedHp =
        opponent.maxHp > 0 && (opponent.currentHp / opponent.maxHp) <= 0.20;
    final List<Move> pool;
    if (inRedHp) {
      pool = available;
    } else {
      final nonSelfKo = available
          .where((m) => m.id != 'self_destruct' && m.id != 'explosion')
          .toList();
      pool = nonSelfKo.isNotEmpty ? nonSelfKo : available;
    }

    final random = rng ?? _rng;
    return pool[random.nextInt(pool.length)];
  }

  /// Resolves a full combat turn into ordered, animatable [BattleStepEvent]s.
  static List<BattleStepEvent> resolveTurn({
    required PokemonInstance playerMon,
    required BattleAction playerAction,
    required PokemonInstance opponentMon,
    required BattleAction opponentAction,
    bool isWild = true,
    Trainer? playerTrainer,
  }) {
    final List<BattleStepEvent> events = [];

    // Pre-turn held berry triggers (e.g. status cures)
    final preBerryPlayer = checkAndConsumeHeldBerry(playerMon, isPlayer: true, isWild: isWild);
    if (preBerryPlayer != null) events.add(preBerryPlayer);
    final preBerryOpp = checkAndConsumeHeldBerry(opponentMon, isPlayer: false, isWild: isWild);
    if (preBerryOpp != null) events.add(preBerryOpp);

    final Move? effectivePlayerMove = playerAction.type == BattleActionType.fight
        ? resolveEffectiveMove(playerMon, playerAction.move)
        : null;
    final Move? effectiveOppMove = opponentAction.type == BattleActionType.fight
        ? resolveEffectiveMove(opponentMon, opponentAction.move)
        : null;

    // Determine Move Execution Order (Priority -> Speed)
    bool playerGoesFirst = true;

    if (effectivePlayerMove != null && effectiveOppMove != null) {
      final pPriority = playerMon.needsRecharge ? 0 : effectivePlayerMove.priority;
      final oPriority = opponentMon.needsRecharge ? 0 : effectiveOppMove.priority;

      if (pPriority != oPriority) {
        playerGoesFirst = pPriority > oPriority;
      } else {
        final pSpeedMod = playerTrainer != null ? playerTrainer.speBadgeMultiplier : 1.0;
        final pSpe = (playerMon.effectiveSpe * pSpeedMod).round();
        final oSpe = opponentMon.effectiveSpe;
        if (pSpe != oSpe) {
          playerGoesFirst = pSpe > oSpe;
        } else {
          playerGoesFirst = _rng.nextBool();
        }
      }
    } else if (effectiveOppMove != null && effectivePlayerMove == null) {
      playerGoesFirst = false;
    }

    if (playerGoesFirst) {
      if (effectivePlayerMove != null && !playerMon.isFainted) {
        events.addAll(executeSingleAttack(
          playerMon,
          effectivePlayerMove,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
      if (!playerMon.isFainted &&
          !opponentMon.isFainted &&
          effectiveOppMove != null) {
        events.addAll(executeSingleAttack(
          opponentMon,
          effectiveOppMove,
          playerMon,
          isPlayer: false,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
    } else {
      if (effectiveOppMove != null && !opponentMon.isFainted) {
        events.addAll(executeSingleAttack(
          opponentMon,
          effectiveOppMove,
          playerMon,
          isPlayer: false,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
      if (!playerMon.isFainted &&
          !opponentMon.isFainted &&
          effectivePlayerMove != null) {
        events.addAll(executeSingleAttack(
          playerMon,
          effectivePlayerMove,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
    }

    // End-of-turn Burn / Poison / Trap / Leech Seed / Leftovers
    if (!playerMon.isFainted && !opponentMon.isFainted) {
      events.addAll(processEndOfTurnStatus(
        playerMon,
        opponent: opponentMon,
        isPlayer: true,
        isWild: isWild,
      ));
      if (!playerMon.isFainted && !opponentMon.isFainted) {
        events.addAll(processEndOfTurnStatus(
          opponentMon,
          opponent: playerMon,
          isPlayer: false,
          isWild: isWild,
        ));
      }
    }

    return events;
  }

  static double _getHeldItemDamageMultiplier(PokemonInstance attacker, PokemonType moveType) {
    final held = attacker.heldItemId;
    if (held == null) return 1.0;
    switch (held) {
      case 'hard_stone':
        if (moveType == PokemonType.rock) return 1.20;
        break;
      case 'mystic_water':
        if (moveType == PokemonType.water) return 1.20;
        break;
      case 'magnet':
        if (moveType == PokemonType.electric) return 1.20;
        break;
      case 'miracle_seed':
        if (moveType == PokemonType.grass) return 1.20;
        break;
      case 'poison_barb':
        if (moveType == PokemonType.poison) return 1.20;
        break;
      case 'twisted_spoon':
        if (moveType == PokemonType.psychic) return 1.20;
        break;
      case 'charcoal':
        if (moveType == PokemonType.fire) return 1.20;
        break;
      case 'soft_sand':
        if (moveType == PokemonType.ground) return 1.20;
        break;
    }
    return 1.0;
  }

  static BattleStepEvent? checkAndConsumeHeldBerry(
    PokemonInstance mon, {
    required bool isPlayer,
    bool isWild = true,
  }) {
    if (mon.isFainted || mon.heldItemId == null) return null;
    final monName = isPlayer
        ? mon.nickname
        : (isWild ? "Wild ${mon.nickname}" : mon.nickname);
    final held = mon.heldItemId;

    // 1. HP recovery berries (trigger at <= 50% HP)
    if (mon.currentHp <= (mon.maxHp / 2).ceil()) {
      if (held == 'oran_berry') {
        final heal = min(10, mon.maxHp - mon.currentHp);
        mon.currentHp += heal;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message: "$monName ate its held Oran Berry and restored $heal HP!",
          isPlayerActor: isPlayer,
          targetHpAfter: mon.currentHp,
          isStatusTick: true,
        );
      } else if (held == 'sitrus_berry') {
        final heal = min(30, mon.maxHp - mon.currentHp);
        mon.currentHp += heal;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message: "$monName ate its held Sitrus Berry and restored $heal HP!",
          isPlayerActor: isPlayer,
          targetHpAfter: mon.currentHp,
          isStatusTick: true,
        );
      }
    }

    // 2. Status recovery berries
    if (mon.status != StatusCondition.none) {
      bool cured = false;
      String berryName = "";
      if (held == 'cheri_berry' && mon.status == StatusCondition.paralysis) {
        cured = true;
        berryName = "Cheri Berry";
      } else if (held == 'chesto_berry' && mon.status == StatusCondition.sleep) {
        cured = true;
        berryName = "Chesto Berry";
      } else if (held == 'pecha_berry' && mon.status == StatusCondition.poison) {
        cured = true;
        berryName = "Pecha Berry";
      } else if (held == 'rawst_berry' && mon.status == StatusCondition.burn) {
        cured = true;
        berryName = "Rawst Berry";
      } else if (held == 'aspear_berry' && mon.status == StatusCondition.freeze) {
        cured = true;
        berryName = "Aspear Berry";
      } else if (held == 'lum_berry') {
        cured = true;
        berryName = "Lum Berry";
      }

      if (cured) {
        final oldStatus = mon.status.name.toUpperCase();
        mon.status = StatusCondition.none;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message: "$monName ate its held $berryName and was cured of $oldStatus!",
          isPlayerActor: isPlayer,
          targetHpAfter: mon.currentHp,
          statusInflictedLabel: "CURED",
          isStatusTick: true,
        );
      }
    }
    return null;
  }

  static void _clearMoveLocks(PokemonInstance mon) {
    mon.chargingMoveId = null;
    mon.isUnderground = false;
    mon.bideTurnsRemaining = 0;
    mon.bideDamageStored = 0;
    mon.rampageMoveId = null;
    mon.rampageTurnsRemaining = 0;
    mon.rolloutTurnsRemaining = 0;
    mon.rolloutHitCount = 0;
  }

  static int _rollHitCount(Move move, Random random) {
    if (move.maxHits <= 1) return 1;
    if (move.minHits >= move.maxHits) return move.maxHits;
    if (move.minHits == 2 && move.maxHits == 5) {
      // Standard Pokémon distribution: 2 hits (3/8), 3 hits (3/8), 4 hits (1/8), 5 hits (1/8)
      final r = random.nextInt(8);
      if (r < 3) return 2;
      if (r < 6) return 3;
      return r == 6 ? 4 : 5;
    }
    return move.minHits + random.nextInt(move.maxHits - move.minHits + 1);
  }

  static ({int damage, bool isCrit, double typeMultiplier}) _computeHitDamage({
    required PokemonInstance attacker,
    required Move move,
    required PokemonInstance defender,
    required bool isPlayer,
    required Trainer? playerTrainer,
    required Random random,
    int? powerOverride,
    double extraMultiplier = 1.0,
  }) {
    final int movePower = powerOverride ?? move.power;
    int attackStat = move.category == MoveCategory.physical
        ? attacker.effectiveAtk
        : attacker.effectiveSpa;
    if (isPlayer && playerTrainer != null) {
      final double badgeMult = move.category == MoveCategory.physical
          ? playerTrainer.atkBadgeMultiplier
          : playerTrainer.spaBadgeMultiplier;
      attackStat = (attackStat * badgeMult).round();
    }
    if (move.category == MoveCategory.physical &&
        attacker.status == StatusCondition.burn) {
      attackStat = (attackStat * 0.5).round().clamp(1, 9999);
    }

    int defenseStat = move.category == MoveCategory.physical
        ? defender.effectiveDef
        : defender.effectiveSpd;
    if (!isPlayer && playerTrainer != null) {
      final double badgeMult = move.category == MoveCategory.physical
          ? playerTrainer.defBadgeMultiplier
          : playerTrainer.spdBadgeMultiplier;
      defenseStat = (defenseStat * badgeMult).round();
    }

    final double base =
        (((2 * attacker.level / 5 + 2) * movePower * attackStat / defenseStat) / 50) +
            2;
    final double stab = attacker.species.types.contains(move.type) ? 1.5 : 1.0;
    final double typeMultiplier =
        PokemonTypeExtension.getEffectiveness(move.type, defender.species.types);

    final int critThreshold =
        (isPlayer && playerTrainer != null && playerTrainer.critBadgeBonus > 0)
            ? 8
            : 16;
    final bool isCrit = typeMultiplier > 0 && random.nextInt(critThreshold) == 0;
    final double crit = isCrit ? 1.5 : 1.0;
    final double randomVariance = (85 + random.nextInt(16)) / 100.0;
    final double heldItemMultiplier =
        _getHeldItemDamageMultiplier(attacker, move.type);

    int damage = (base *
            crit *
            randomVariance *
            stab *
            typeMultiplier *
            heldItemMultiplier *
            extraMultiplier)
        .floor();
    if (damage < 1 && typeMultiplier > 0) damage = 1;
    if (typeMultiplier == 0.0) damage = 0;

    return (damage: damage, isCrit: isCrit, typeMultiplier: typeMultiplier);
  }

  static List<BattleStepEvent> executeSingleAttack(
    PokemonInstance attacker,
    Move move,
    PokemonInstance defender, {
    required bool isPlayer,
    bool isWild = true,
    Trainer? playerTrainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final List<BattleStepEvent> events = [];
    final attackerName = isPlayer
        ? attacker.nickname
        : (isWild ? "Wild ${attacker.nickname}" : attacker.nickname);
    final defenderName = isPlayer
        ? (isWild ? "Wild ${defender.nickname}" : defender.nickname)
        : defender.nickname;

    // 0. Mandatory Recharge Turn (Hyper Beam)
    if (attacker.needsRecharge) {
      attacker.needsRecharge = false;
      events.add(BattleStepEvent(
        message: "$attackerName must recharge!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
      return events;
    }

    // 1. Pre-move status check (Sleep / Paralysis / Confusion)
    if (attacker.status == StatusCondition.sleep) {
      if (random.nextInt(3) == 0) {
        attacker.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$attackerName woke up!",
          isPlayerActor: isPlayer,
        ));
      } else if (move.id != 'snore') {
        _clearMoveLocks(attacker);
        events.add(BattleStepEvent(
          message: "$attackerName is fast asleep!",
          isPlayerActor: isPlayer,
          isMiss: true,
        ));
        return events;
      }
    } else if (attacker.status == StatusCondition.paralysis) {
      if (random.nextInt(4) == 0) {
        _clearMoveLocks(attacker);
        events.add(BattleStepEvent(
          message: "$attackerName is paralyzed! It can't move!",
          isPlayerActor: isPlayer,
          isMiss: true,
        ));
        return events;
      }
    }

    if (attacker.isConfused) {
      attacker.confusionTurnsRemaining--;
      if (attacker.confusionTurnsRemaining <= 0) {
        attacker.isConfused = false;
        events.add(BattleStepEvent(
          message: "$attackerName snapped out of its confusion!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
      } else if (random.nextInt(3) == 0) {
        _clearMoveLocks(attacker);
        final double rawSelf =
            (((2 * attacker.level / 5 + 2) * 40 * attacker.effectiveAtk / attacker.effectiveDef) /
                    50) +
                2;
        final int selfDmg = max(1, rawSelf.floor());
        attacker.currentHp = (attacker.currentHp - selfDmg).clamp(0, attacker.maxHp);
        events.add(BattleStepEvent(
          message: "$attackerName hurt itself in its confusion!",
          isPlayerActor: isPlayer,
          moveType: PokemonType.normal,
          damageDealt: selfDmg,
          targetHpAfter: attacker.currentHp,
          targetFainted: attacker.isFainted,
          isSelfDamage: true,
          hideMoveVfx: true,
        ));
        if (attacker.isFainted) {
          events.add(BattleStepEvent(
            message: "$attackerName fainted!",
            isPlayerActor: !isPlayer,
            targetHpAfter: 0,
            targetFainted: true,
          ));
        }
        return events;
      }
    }

    // 2. Determine whether this turn continues a multi-stage move or initiates one
    final bool isContinuingCharge = attacker.chargingMoveId == move.id;
    final bool isContinuingBide =
        move.stageMechanic == MoveStageMechanic.bide && attacker.bideTurnsRemaining > 0;
    final bool isContinuingRampage =
        move.stageMechanic == MoveStageMechanic.rampage &&
        attacker.rampageMoveId == move.id &&
        attacker.rampageTurnsRemaining > 0;
    final bool isContinuingRollout =
        move.stageMechanic == MoveStageMechanic.escalatingRoll &&
        attacker.rolloutTurnsRemaining > 0;
    final bool isContinuation =
        isContinuingCharge || isContinuingBide || isContinuingRampage || isContinuingRollout;

    bool surfacedThisTurn = false;
    if (isContinuingCharge) {
      attacker.chargingMoveId = null;
      surfacedThisTurn = attacker.isUnderground;
      attacker.isUnderground = false;
    }

    // Spend PP only on Turn 1 of any move
    if (!isContinuation && move.currentPp > 0) {
      move.currentPp--;
    }

    // 2.0 Metronome: waggle a finger and randomly execute almost any move
    if (move.id == 'metronome') {
      final eligibleIds = PokedexDatabase.moves.keys
          .where((id) =>
              id != 'metronome' &&
              id != 'struggle' &&
              id != 'mimic')
          .toList()
        ..sort();
      if (eligibleIds.isNotEmpty) {
        final rolledId = eligibleIds[random.nextInt(eligibleIds.length)];
        final chosen = PokedexDatabase.moves[rolledId]!.copy();
        events.add(BattleStepEvent(
          message:
              "$attackerName waggled a finger! It turned into ${chosen.name}!",
          isPlayerActor: isPlayer,
          moveId: 'metronome',
          moveType: PokemonType.normal,
          moveCategory: MoveCategory.status,
          statTargetIsSelf: true,
        ));
        move = chosen;
      }
    }

    void appendSelfKoEventsIfNeeded() {
      if ((move.id == 'self_destruct' || move.id == 'explosion') &&
          !attacker.isFainted) {
        final int koDmg = attacker.currentHp;
        attacker.currentHp = 0;
        _clearMoveLocks(attacker);
        events.add(BattleStepEvent(
          message: "$attackerName collapsed from ${move.name}!",
          isPlayerActor: isPlayer,
          damageDealt: koDmg,
          targetHpAfter: 0,
          targetFainted: true,
          isSelfDamage: true,
          hideMoveVfx: true,
        ));
        events.add(BattleStepEvent(
          message: "$attackerName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
    }

    // 2a. Bide (Turn 1 store -> Turn 2 store -> Turn 3 unleash 2x damage)
    if (move.stageMechanic == MoveStageMechanic.bide) {
      if (!isContinuingBide) {
        attacker.bideTurnsRemaining = 2;
        attacker.bideDamageStored = 0;
        events.add(BattleStepEvent(
          message: "$attackerName is storing energy!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isChargeTurn: true,
        ));
        return events;
      }

      attacker.bideTurnsRemaining--;
      if (attacker.bideTurnsRemaining > 0) {
        events.add(BattleStepEvent(
          message: "$attackerName is storing energy!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isChargeTurn: true,
        ));
        return events;
      }

      final int unleashedDmg = attacker.bideDamageStored * 2;
      attacker.bideDamageStored = 0;
      if (unleashedDmg <= 0 || defender.isUnderground) {
        events.add(BattleStepEvent(
          message: "$attackerName unleashed energy, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
        ));
        return events;
      }

      defender.currentHp = (defender.currentHp - unleashedDmg).clamp(0, defender.maxHp);
      if (defender.bideTurnsRemaining > 0) {
        defender.bideDamageStored += unleashedDmg;
      }
      events.add(BattleStepEvent(
        message: "$attackerName unleashed energy!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: unleashedDmg,
        targetHpAfter: defender.currentHp,
        targetFainted: defender.isFainted,
      ));
      if (!defender.isFainted) {
        final berryEvent =
            checkAndConsumeHeldBerry(defender, isPlayer: !isPlayer, isWild: isWild);
        if (berryEvent != null) events.add(berryEvent);
      } else {
        events.add(BattleStepEvent(
          message: "$defenderName fainted!",
          isPlayerActor: isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
      return events;
    }

    // 2b. Two-Turn Charge / Semi-Invulnerable Turn 1 (Dig, Solar Beam, Sky Attack, Skull Bash, Razor Wind)
    if (!isContinuingCharge && move.isTwoTurnCharge) {
      attacker.chargingMoveId = move.id;
      final bool goUnderground =
          move.stageMechanic == MoveStageMechanic.semiInvulnerable;
      if (goUnderground) {
        attacker.isUnderground = true;
      }

      String? statLabel;
      String chargeMsg =
          "$attackerName ${move.chargeStatusMessage ?? 'is charging power!'}";
      if (move.chargeSelfStatTarget != null && move.chargeSelfStatChange != 0) {
        final delta = attacker.modifyStatStage(
          move.chargeSelfStatTarget!,
          move.chargeSelfStatChange,
        );
        final statName = _statDisplayName(move.chargeSelfStatTarget!);
        final arrow = move.chargeSelfStatChange > 0 ? '▲' : '▼';
        statLabel = "${move.chargeSelfStatTarget!.toUpperCase()} $arrow";
        if (delta != 0) {
          chargeMsg = "$chargeMsg $attackerName's $statName rose!";
        }
      }

      events.add(BattleStepEvent(
        message: chargeMsg,
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statChangedLabel: statLabel,
        statTargetIsSelf: true,
        isChargeTurn: true,
        submergeActorAfter: goUnderground,
      ));
      return events;
    }

    // Initialize rampage / rollout duration on Turn 1
    if (!isContinuation) {
      if (move.stageMechanic == MoveStageMechanic.rampage) {
        attacker.rampageMoveId = move.id;
        attacker.rampageTurnsRemaining = 1 + random.nextInt(2); // 2-3 turns total
      } else if (move.stageMechanic == MoveStageMechanic.escalatingRoll) {
        attacker.rolloutTurnsRemaining = 4; // up to 5 hits total
        attacker.rolloutHitCount = 0;
      }
    }

    // 3. Semi-Invulnerable, Snore Condition & Accuracy Check
    if (move.id == 'snore' && attacker.status != StatusCondition.sleep) {
      events.add(BattleStepEvent(
        message: "$attackerName used Snore, but it failed!",
        isPlayerActor: isPlayer,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        surfaceActorOnAttack: surfacedThisTurn,
      ));
      return events;
    }

    final bool hitsUnderground =
        move.id == 'earthquake' || move.id == 'fissure';
    final bool blockedByDig = defender.isUnderground && !hitsUnderground;
    final int effectiveAccuracy = move.id == 'swift'
        ? 100
        : (move.accuracy * attacker.accuracyMultiplier).round().clamp(1, 100);
    final int accRoll = random.nextInt(100) + 1;
    if (blockedByDig || accRoll > effectiveAccuracy) {
      if (move.stageMechanic == MoveStageMechanic.escalatingRoll) {
        attacker.rolloutTurnsRemaining = 0;
        attacker.rolloutHitCount = 0;
      } else if (move.stageMechanic == MoveStageMechanic.rampage) {
        attacker.rampageMoveId = null;
        attacker.rampageTurnsRemaining = 0;
      }
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}, but it missed!",
        isPlayerActor: isPlayer,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        surfaceActorOnAttack: surfacedThisTurn,
      ));
      appendSelfKoEventsIfNeeded();
      return events;
    }

    // 4. Pure Status / Stat / Direct Self-Healing Moves
    if (move.category == MoveCategory.status || move.power == 0) {
      if (move.id == 'recover' ||
          move.id == 'soft_boiled' ||
          move.id == 'rest') {
        if (attacker.currentHp >= attacker.maxHp) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used ${move.name}, but its HP is already full!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            targetHpAfter: attacker.currentHp,
          ));
          return events;
        }

        final bool isRest = move.id == 'rest';
        final int healAmt =
            isRest ? attacker.maxHp : max(1, (attacker.maxHp / 2).round());
        final int actualHeal = min(healAmt, attacker.maxHp - attacker.currentHp);
        attacker.currentHp += actualHeal;
        if (isRest) {
          attacker.status = StatusCondition.sleep;
        }

        events.add(BattleStepEvent(
          message: isRest
              ? "$attackerName went to sleep and restored full HP! (+$actualHeal HP)"
              : "$attackerName restored its HP! (+$actualHeal HP)",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          healAmount: actualHeal,
          statTargetIsSelf: true,
          statusInflictedLabel: isRest ? 'ASLEEP!' : null,
          targetHpAfter: attacker.currentHp,
        ));
        return events;
      }

      if (move.id == 'leech_seed') {
        if (defender.species.types.contains(PokemonType.grass)) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Leech Seed! It doesn't affect $defenderName...",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            effectiveness: 0.0,
            targetHpAfter: defender.currentHp,
          ));
        } else if (defender.substituteHp > 0) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Leech Seed! $defenderName's substitute blocked it!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'BLOCKED',
            targetHpAfter: defender.currentHp,
          ));
        } else if (defender.isSeeded) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Leech Seed! $defenderName is already seeded!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            targetHpAfter: defender.currentHp,
          ));
        } else {
          defender.isSeeded = true;
          events.add(BattleStepEvent(
            message: "$attackerName used Leech Seed! $defenderName was seeded!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'SEEDED!',
            targetHpAfter: defender.currentHp,
          ));
        }
        return events;
      }

      if (move.id == 'substitute') {
        final int cost = max(1, attacker.maxHp ~/ 4);
        if (attacker.substituteHp > 0) {
          events.add(BattleStepEvent(
            message: "$attackerName already has a substitute!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            targetHpAfter: attacker.currentHp,
          ));
        } else if (attacker.currentHp <= cost) {
          events.add(BattleStepEvent(
            message:
                "$attackerName tried Substitute, but it doesn't have enough HP!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            targetHpAfter: attacker.currentHp,
          ));
        } else {
          attacker.currentHp -= cost;
          attacker.substituteHp = cost;
          events.add(BattleStepEvent(
            message: "$attackerName put in a substitute!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            targetHpAfter: attacker.currentHp,
          ));
          events.add(BattleStepEvent(
            message: "$attackerName gave up $cost HP to create a decoy!",
            isPlayerActor: isPlayer,
            damageDealt: cost,
            targetHpAfter: attacker.currentHp,
            isSelfDamage: true,
            hideMoveVfx: true,
          ));
        }
        return events;
      }

      String? statLabel;
      String? statusLabel;
      bool selfBuff = false;
      String msg = "$attackerName used ${move.name}!";

      if (move.statTarget != null && move.statChange != 0) {
        selfBuff = move.statChange > 0;
        if (!selfBuff && defender.substituteHp > 0) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used ${move.name}! The substitute protected $defenderName!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'BLOCKED',
            targetHpAfter: defender.currentHp,
          ));
          return events;
        }
        final targetMon = selfBuff ? attacker : defender;
        final targetLabel = selfBuff ? attackerName : defenderName;
        final actualDelta =
            targetMon.modifyStatStage(move.statTarget!, move.statChange);
        final statFullName = _statDisplayName(move.statTarget!);
        final arrow = move.statChange > 0 ? '▲' : '▼';
        statLabel = "${move.statTarget!.toUpperCase()} $arrow";

        if (actualDelta == 0) {
          msg =
              "$attackerName used ${move.name}! $targetLabel's $statFullName won't go any ${move.statChange > 0 ? 'higher' : 'lower'}!";
        } else if (move.statChange >= 2) {
          msg =
              "$attackerName used ${move.name}! $targetLabel's $statFullName rose sharply!";
        } else if (move.statChange > 0) {
          msg =
              "$attackerName used ${move.name}! $targetLabel's $statFullName rose!";
        } else if (move.statChange <= -2) {
          msg =
              "$attackerName used ${move.name}! $targetLabel's $statFullName harshly fell!";
        } else {
          msg =
              "$attackerName used ${move.name}! $targetLabel's $statFullName fell!";
        }
      } else if (move.statusEffect != null) {
        if (defender.substituteHp > 0) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used ${move.name}! The substitute protected $defenderName!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'BLOCKED',
            targetHpAfter: defender.currentHp,
          ));
          return events;
        }
        final inflicted = _tryInflictStatus(defender, move.statusEffect!, random);
        if (inflicted != null) {
          statusLabel = inflicted;
          msg = "$attackerName used ${move.name}! $defenderName is $inflicted";
        } else {
          msg = "$attackerName used ${move.name}, but it failed!";
        }
      }

      events.add(BattleStepEvent(
        message: msg,
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statChangedLabel: statLabel,
        statTargetIsSelf: selfBuff,
        statusInflictedLabel: statusLabel,
        targetHpAfter: defender.currentHp,
      ));

      final berryEvent =
          checkAndConsumeHeldBerry(defender, isPlayer: !isPlayer, isWild: isWild);
      if (berryEvent != null) {
        events.add(berryEvent);
      }
      return events;
    }

    // 5. Damaging Move Calculation (Single-Hit or Multi-Hit)
    final double previewEff =
        PokemonTypeExtension.getEffectiveness(move.type, defender.species.types);
    if (previewEff == 0.0) {
      if (move.stageMechanic == MoveStageMechanic.escalatingRoll) {
        attacker.rolloutTurnsRemaining = 0;
        attacker.rolloutHitCount = 0;
      } else if (move.stageMechanic == MoveStageMechanic.rampage) {
        attacker.rampageMoveId = null;
        attacker.rampageTurnsRemaining = 0;
      }
      events.add(BattleStepEvent(
        message:
            "$attackerName used ${move.name}! It had no effect on $defenderName.",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: 0,
        targetHpAfter: defender.currentHp,
        effectiveness: 0.0,
        surfaceActorOnAttack: surfacedThisTurn,
      ));
      appendSelfKoEventsIfNeeded();
      return events;
    }

    final int hitCount = _rollHitCount(move, random);
    final int? powerOverride = move.stageMechanic == MoveStageMechanic.escalatingRoll
        ? move.power * (1 << attacker.rolloutHitCount.clamp(0, 4))
        : null;
    final double extraMultiplier =
        (move.id == 'earthquake' && defender.isUnderground) ? 2.0 : 1.0;

    int actualHits = 0;
    int totalDamageDealt = 0;
    for (int hit = 1; hit <= hitCount; hit++) {
      final hitResult = _computeHitDamage(
        attacker: attacker,
        move: move,
        defender: defender,
        isPlayer: isPlayer,
        playerTrainer: playerTrainer,
        random: random,
        powerOverride: powerOverride,
        extraMultiplier: extraMultiplier,
      );

      if (defender.substituteHp > 0) {
        final int absorbed = min(defender.substituteHp, hitResult.damage);
        defender.substituteHp -= absorbed;
        actualHits = hit;
        final bool broke = defender.substituteHp <= 0;
        events.add(BattleStepEvent(
          message: broke
              ? "${hit == 1 ? '$attackerName used ${move.name}! ' : ''}$defenderName's substitute broke!"
              : "${hit == 1 ? '$attackerName used ${move.name}! ' : ''}The substitute took the damage for $defenderName!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          damageDealt: 0,
          targetHpAfter: defender.currentHp,
          isCrit: hitResult.isCrit,
          effectiveness: hitResult.typeMultiplier,
          statusInflictedLabel: broke ? 'SUB BROKE!' : 'SUBSTITUTE!',
          hitNumber: hitCount > 1 ? hit : 0,
          totalHits: hitCount > 1 ? hitCount : 0,
          surfaceActorOnAttack: hit == 1 && surfacedThisTurn,
        ));
        continue;
      }

      final int prevDefenderHp = defender.currentHp;
      defender.currentHp =
          (defender.currentHp - hitResult.damage).clamp(0, defender.maxHp);
      totalDamageDealt += max(0, prevDefenderHp - defender.currentHp);
      actualHits = hit;

      if (defender.bideTurnsRemaining > 0 && hitResult.damage > 0) {
        defender.bideDamageStored += hitResult.damage;
      }

      String? secondaryStatusLabel;
      if (!defender.isFainted &&
          move.statusEffect != null &&
          move.statusChance > 0 &&
          random.nextInt(100) < move.statusChance) {
        secondaryStatusLabel =
            _tryInflictStatus(defender, move.statusEffect!, random);
      }

      final StringBuffer msgBuffer = StringBuffer(
        hit == 1
            ? "$attackerName used ${move.name}!"
            : "$attackerName's ${move.name} hit #$hit!",
      );
      if (hitResult.isCrit) msgBuffer.write(" A critical hit!");
      if (hit == 1 && hitResult.typeMultiplier >= 2.0) {
        msgBuffer.write(" It's super effective!");
      } else if (hit == 1 &&
          hitResult.typeMultiplier > 0 &&
          hitResult.typeMultiplier <= 0.5) {
        msgBuffer.write(" It's not very effective...");
      }
      if (secondaryStatusLabel != null) {
        msgBuffer.write(" $defenderName became $secondaryStatusLabel");
      }

      events.add(BattleStepEvent(
        message: msgBuffer.toString(),
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: hitResult.damage,
        targetHpAfter: defender.currentHp,
        isCrit: hitResult.isCrit,
        effectiveness: hitResult.typeMultiplier,
        statusInflictedLabel: secondaryStatusLabel,
        targetFainted: defender.isFainted,
        hitNumber: hitCount > 1 ? hit : 0,
        totalHits: hitCount > 1 ? hitCount : 0,
        surfaceActorOnAttack: hit == 1 && surfacedThisTurn,
      ));

      if (defender.isFainted) {
        break;
      }
    }

    if (hitCount > 1) {
      events.add(BattleStepEvent(
        message: "Hit $actualHits time${actualHits == 1 ? '' : 's'}!",
        isPlayerActor: isPlayer,
        targetHpAfter: defender.currentHp,
        isMultiHitSummary: true,
        hideMoveVfx: true,
      ));
    }

    // 5b. HP-Draining Attacks (Absorb, Mega Drain, Giga Drain, Dream Eater)
    const Set<String> drainMoveIds = {
      'absorb',
      'mega_drain',
      'giga_drain',
      'dream_eater',
    };
    if (drainMoveIds.contains(move.id) &&
        totalDamageDealt > 0 &&
        !attacker.isFainted &&
        attacker.currentHp < attacker.maxHp) {
      final int healAmt = max(1, totalDamageDealt ~/ 2);
      final int actualHeal = min(healAmt, attacker.maxHp - attacker.currentHp);
      attacker.currentHp += actualHeal;
      if (actualHeal > 0) {
        events.add(BattleStepEvent(
          message: "$defenderName had its energy drained! (+$actualHeal HP)",
          isPlayerActor: isPlayer,
          healAmount: actualHeal,
          targetHpAfter: attacker.currentHp,
          isStatusTick: true,
          hideMoveVfx: true,
        ));
      }
    }

    // 6. Post-hit multi-stage side effects
    if (move.stageMechanic == MoveStageMechanic.rechargeAfterHit &&
        !defender.isFainted) {
      attacker.needsRecharge = true;
    }

    if (move.stageMechanic == MoveStageMechanic.trapDot &&
        !defender.isFainted &&
        defender.trappedTurnsRemaining == 0) {
      defender.trappedTurnsRemaining = 4 + random.nextInt(2);
      defender.trappedByMoveId = move.id;
      defender.trappedByMoveName = move.name;
      events.add(BattleStepEvent(
        message: "$defenderName was trapped by ${move.name}!",
        isPlayerActor: isPlayer,
        targetHpAfter: defender.currentHp,
        hideMoveVfx: true,
      ));
    }

    if (move.stageMechanic == MoveStageMechanic.rampage &&
        attacker.rampageMoveId == move.id) {
      if (isContinuingRampage) {
        attacker.rampageTurnsRemaining--;
        if (attacker.rampageTurnsRemaining <= 0) {
          attacker.rampageMoveId = null;
          if (!attacker.isFainted && !attacker.isConfused) {
            attacker.isConfused = true;
            attacker.confusionTurnsRemaining = 2 + random.nextInt(3);
            events.add(BattleStepEvent(
              message: "$attackerName became confused due to fatigue!",
              isPlayerActor: isPlayer,
              statusInflictedLabel: 'CONFUSED!',
              statTargetIsSelf: true,
              targetHpAfter: attacker.currentHp,
              hideMoveVfx: true,
            ));
          }
        }
      }
    }

    if (move.stageMechanic == MoveStageMechanic.escalatingRoll) {
      if (defender.isFainted) {
        // Keep streak if more turns remain, or advance count cleanly
        if (isContinuingRollout) {
          attacker.rolloutTurnsRemaining--;
        }
        attacker.rolloutHitCount++;
        if (attacker.rolloutTurnsRemaining <= 0) {
          attacker.rolloutHitCount = 0;
        }
      } else {
        if (isContinuingRollout) {
          attacker.rolloutTurnsRemaining--;
        }
        attacker.rolloutHitCount++;
        if (attacker.rolloutTurnsRemaining <= 0) {
          attacker.rolloutHitCount = 0;
        }
      }
    }

    // Check if defender's held berry triggers (e.g. Oran/Sitrus on <=50% HP or status cure)
    if (!defender.isFainted) {
      final berryEvent =
          checkAndConsumeHeldBerry(defender, isPlayer: !isPlayer, isWild: isWild);
      if (berryEvent != null) {
        events.add(berryEvent);
      }
    }

    if (defender.isFainted) {
      events.add(BattleStepEvent(
        message: "$defenderName fainted!",
        isPlayerActor: isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }

    appendSelfKoEventsIfNeeded();
    return events;
  }

  static List<BattleStepEvent> processEndOfTurnStatus(
    PokemonInstance mon, {
    PokemonInstance? opponent,
    required bool isPlayer,
    required bool isWild,
  }) {
    final List<BattleStepEvent> events = [];
    final monName = isPlayer
        ? mon.nickname
        : (isWild ? "Wild ${mon.nickname}" : mon.nickname);

    if (mon.status == StatusCondition.burn || mon.status == StatusCondition.poison) {
      final bool isBurn = mon.status == StatusCondition.burn;
      final bool isToxic = !isBurn && mon.isBadlyPoisoned;
      final int tickDmg = isToxic
          ? max(1, (mon.maxHp * mon.toxicCounter) ~/ 16)
          : max(1, mon.maxHp ~/ 8);
      if (isToxic) {
        mon.toxicCounter = min(15, mon.toxicCounter + 1);
      }
      mon.currentHp = (mon.currentHp - tickDmg).clamp(0, mon.maxHp);

      events.add(BattleStepEvent(
        message: isBurn
            ? "$monName was hurt by its burn!"
            : (isToxic
                ? "$monName is hurt by toxin!"
                : "$monName was hurt by poison!"),
        isPlayerActor: !isPlayer,
        moveType: isBurn ? PokemonType.fire : PokemonType.poison,
        damageDealt: tickDmg,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));

      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
        return events;
      }
    }

    // Leech Seed sapping 1/8 max HP to heal the opposing active Pokémon
    if (!mon.isFainted && mon.isSeeded) {
      final int seedDmg = max(1, mon.maxHp ~/ 8);
      final int prevHp = mon.currentHp;
      mon.currentHp = (mon.currentHp - seedDmg).clamp(0, mon.maxHp);
      final int drained = max(0, prevHp - mon.currentHp);

      events.add(BattleStepEvent(
        message: "$monName's health is sapped by Leech Seed!",
        isPlayerActor: !isPlayer,
        moveId: 'leech_seed',
        moveType: PokemonType.grass,
        damageDealt: drained,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));

      if (opponent != null &&
          !opponent.isFainted &&
          drained > 0 &&
          opponent.currentHp < opponent.maxHp) {
        final int actualHeal = min(drained, opponent.maxHp - opponent.currentHp);
        opponent.currentHp += actualHeal;
        final opponentLabel = !isPlayer
            ? opponent.nickname
            : (isWild ? "Wild ${opponent.nickname}" : opponent.nickname);
        events.add(BattleStepEvent(
          message: "$opponentLabel absorbed Leech Seed energy! (+$actualHeal HP)",
          isPlayerActor: !isPlayer,
          healAmount: actualHeal,
          targetHpAfter: opponent.currentHp,
          isStatusTick: true,
          hideMoveVfx: true,
        ));
      }

      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
        return events;
      }
    }

    // Partial trapping chip damage (Fire Spin / Wrap)
    if (!mon.isFainted && mon.trappedTurnsRemaining > 0) {
      final trapDmg = max(1, mon.maxHp ~/ 8);
      final trapName = mon.trappedByMoveName ?? 'the vortex';
      final trapMoveId = mon.trappedByMoveId;
      mon.currentHp = (mon.currentHp - trapDmg).clamp(0, mon.maxHp);
      mon.trappedTurnsRemaining--;

      events.add(BattleStepEvent(
        message: "$monName is hurt by $trapName!",
        isPlayerActor: !isPlayer,
        moveId: trapMoveId,
        moveType: trapMoveId == 'fire_spin' ? PokemonType.fire : PokemonType.normal,
        damageDealt: trapDmg,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));

      if (mon.isFainted) {
        mon.trappedTurnsRemaining = 0;
        mon.trappedByMoveId = null;
        mon.trappedByMoveName = null;
        events.add(BattleStepEvent(
          message: "$monName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
        return events;
      } else if (mon.trappedTurnsRemaining == 0) {
        mon.trappedByMoveId = null;
        mon.trappedByMoveName = null;
        events.add(BattleStepEvent(
          message: "$monName was freed from $trapName!",
          isPlayerActor: !isPlayer,
          targetHpAfter: mon.currentHp,
          hideMoveVfx: true,
        ));
      }
    }

    // Leftovers healing at end of turn
    if (!mon.isFainted && mon.heldItemId == 'leftovers' && mon.currentHp < mon.maxHp) {
      final heal = max(1, mon.maxHp ~/ 16);
      final actualHeal = min(heal, mon.maxHp - mon.currentHp);
      mon.currentHp += actualHeal;
      events.add(BattleStepEvent(
        message: "$monName restored a little HP with its Leftovers!",
        isPlayerActor: isPlayer,
        healAmount: actualHeal,
        targetHpAfter: mon.currentHp,
        isStatusTick: true,
      ));
    }

    return events;
  }

  static String? _tryInflictStatus(
    PokemonInstance target,
    String effect, [
    Random? rng,
  ]) {
    if (target.isFainted) return null;
    if (effect == 'confusion') {
      if (target.isConfused) return null;
      final r = rng ?? _rng;
      target.isConfused = true;
      target.confusionTurnsRemaining = 2 + r.nextInt(4);
      return 'CONFUSED!';
    }
    if (target.status != StatusCondition.none) return null;

    switch (effect) {
      case 'burn':
        if (target.species.types.contains(PokemonType.fire)) return null;
        target.status = StatusCondition.burn;
        return 'BURNED!';
      case 'poison':
        if (target.species.types.contains(PokemonType.poison) ||
            target.species.types.contains(PokemonType.steel)) {
          return null;
        }
        target.status = StatusCondition.poison;
        target.isBadlyPoisoned = false;
        target.toxicCounter = 1;
        return 'POISONED!';
      case 'badly_poison':
        if (target.species.types.contains(PokemonType.poison) ||
            target.species.types.contains(PokemonType.steel)) {
          return null;
        }
        target.status = StatusCondition.poison;
        target.isBadlyPoisoned = true;
        target.toxicCounter = 1;
        return 'BADLY POISONED!';
      case 'paralysis':
        if (target.species.types.contains(PokemonType.electric)) return null;
        target.status = StatusCondition.paralysis;
        return 'PARALYZED!';
      case 'sleep':
        target.status = StatusCondition.sleep;
        return 'ASLEEP!';
      default:
        return null;
    }
  }

  static String _statDisplayName(String stat) {
    switch (stat) {
      case 'atk':
        return 'Attack';
      case 'def':
        return 'Defense';
      case 'spa':
        return 'Sp. Atk';
      case 'spd':
        return 'Sp. Def';
      case 'spe':
        return 'Speed';
      case 'acc':
        return 'Accuracy';
      default:
        return stat.toUpperCase();
    }
  }

  /// Gen 4 Capture Formula
  static bool attemptCapture({
    required PokemonInstance target,
    required String ballType,
  }) {
    double ballMod = 1.0;
    if (ballType == 'great_ball') ballMod = 1.5;
    if (ballType == 'ultra_ball') ballMod = 2.0;
    if (ballType == 'master_ball') return true;

    int maxHp = target.maxHp;
    int curHp = target.currentHp;
    int catchRate = target.species.baseCatchRate;

    double statusMod = 1.0;
    if (target.status == StatusCondition.sleep || target.status == StatusCondition.freeze) {
      statusMod = 2.0;
    } else if (target.status != StatusCondition.none) {
      statusMod = 1.5;
    }

    double a = (((3 * maxHp - 2 * curHp) * catchRate * ballMod) / (3 * maxHp)) * statusMod;
    if (a >= 255) return true;

    // Shake check
    double b = 65536.0 * pow(a / 255.0, 0.25).toDouble();
    for (int i = 0; i < 4; i++) {
      if (_rng.nextInt(65536) >= b) {
        return false; // Broke free on this shake
      }
    }
    return true; // All 4 shakes passed!
  }

  /// KO-to-catch formula used during Expedition Legendary / Mythical boss battles:
  /// Master Ball = 100%, Ultra Ball = 10%, Great Ball = 5%, Poké Ball / Special = 1%.
  static bool attemptLegendaryKoCapture({
    required String ballType,
    Random? rng,
  }) {
    if (ballType == 'master_ball') return true;
    final double rate;
    if (ballType == 'ultra_ball') {
      rate = 0.10;
    } else if (ballType == 'great_ball') {
      rate = 0.05;
    } else {
      rate = 0.01;
    }
    return (rng ?? _rng).nextDouble() < rate;
  }
}
