import 'dart:math';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';

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
  });
}

class BattleEngine {
  static final Random _rng = Random();

  /// Resolves a full combat turn into ordered, animatable [BattleStepEvent]s.
  static List<BattleStepEvent> resolveTurn({
    required PokemonInstance playerMon,
    required BattleAction playerAction,
    required PokemonInstance opponentMon,
    required BattleAction opponentAction,
    bool isWild = true,
  }) {
    final List<BattleStepEvent> events = [];

    // Determine Move Execution Order (Priority -> Speed)
    bool playerGoesFirst = true;

    if (playerAction.type == BattleActionType.fight &&
        opponentAction.type == BattleActionType.fight) {
      final pPriority = playerAction.move!.priority;
      final oPriority = opponentAction.move!.priority;

      if (pPriority != oPriority) {
        playerGoesFirst = pPriority > oPriority;
      } else {
        final pSpe = playerMon.effectiveSpe;
        final oSpe = opponentMon.effectiveSpe;
        if (pSpe != oSpe) {
          playerGoesFirst = pSpe > oSpe;
        } else {
          playerGoesFirst = _rng.nextBool();
        }
      }
    }

    if (playerGoesFirst) {
      if (playerAction.type == BattleActionType.fight && !playerMon.isFainted) {
        events.addAll(executeSingleAttack(
          playerMon,
          playerAction.move!,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
        ));
      }
      if (!opponentMon.isFainted && opponentAction.type == BattleActionType.fight) {
        events.addAll(executeSingleAttack(
          opponentMon,
          opponentAction.move!,
          playerMon,
          isPlayer: false,
          isWild: isWild,
        ));
      }
    } else {
      if (opponentAction.type == BattleActionType.fight && !opponentMon.isFainted) {
        events.addAll(executeSingleAttack(
          opponentMon,
          opponentAction.move!,
          playerMon,
          isPlayer: false,
          isWild: isWild,
        ));
      }
      if (!playerMon.isFainted && playerAction.type == BattleActionType.fight) {
        events.addAll(executeSingleAttack(
          playerMon,
          playerAction.move!,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
        ));
      }
    }

    // End-of-turn Burn / Poison tick damage
    if (!playerMon.isFainted && !opponentMon.isFainted) {
      events.addAll(_processEndOfTurnStatus(playerMon, isPlayer: true, isWild: isWild));
      if (!playerMon.isFainted) {
        events.addAll(_processEndOfTurnStatus(opponentMon, isPlayer: false, isWild: isWild));
      }
    }

    return events;
  }

  static List<BattleStepEvent> executeSingleAttack(
    PokemonInstance attacker,
    Move move,
    PokemonInstance defender, {
    required bool isPlayer,
    bool isWild = true,
  }) {
    final List<BattleStepEvent> events = [];
    final attackerName = isPlayer
        ? attacker.nickname
        : (isWild ? "Wild ${attacker.nickname}" : attacker.nickname);
    final defenderName = isPlayer
        ? (isWild ? "Wild ${defender.nickname}" : defender.nickname)
        : defender.nickname;

    // 1. Pre-move status check (Sleep / Paralysis)
    if (attacker.status == StatusCondition.sleep) {
      if (_rng.nextInt(3) == 0) {
        attacker.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$attackerName woke up!",
          isPlayerActor: isPlayer,
        ));
      } else {
        events.add(BattleStepEvent(
          message: "$attackerName is fast asleep!",
          isPlayerActor: isPlayer,
          isMiss: true,
        ));
        return events;
      }
    } else if (attacker.status == StatusCondition.paralysis) {
      if (_rng.nextInt(4) == 0) {
        events.add(BattleStepEvent(
          message: "$attackerName is paralyzed! It can't move!",
          isPlayerActor: isPlayer,
          isMiss: true,
        ));
        return events;
      }
    }

    // 2. Spend PP
    if (move.currentPp > 0) {
      move.currentPp--;
    }

    // 3. Accuracy Check
    final accRoll = _rng.nextInt(100) + 1;
    if (accRoll > move.accuracy) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}, but it missed!",
        isPlayerActor: isPlayer,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
      ));
      return events;
    }

    // 4. Pure Status / Stat Moves
    if (move.category == MoveCategory.status || move.power == 0) {
      String? statLabel;
      String? statusLabel;
      bool selfBuff = false;
      String msg = "$attackerName used ${move.name}!";

      if (move.statTarget != null && move.statChange != 0) {
        selfBuff = move.statChange > 0;
        final targetMon = selfBuff ? attacker : defender;
        final targetLabel = selfBuff ? attackerName : defenderName;
        final actualDelta = targetMon.modifyStatStage(move.statTarget!, move.statChange);
        final statFullName = _statDisplayName(move.statTarget!);
        final arrow = move.statChange > 0 ? '▲' : '▼';
        statLabel = "${move.statTarget!.toUpperCase()} $arrow";

        if (actualDelta == 0) {
          msg = "$attackerName used ${move.name}! $targetLabel's $statFullName won't go any ${move.statChange > 0 ? 'higher' : 'lower'}!";
        } else if (move.statChange >= 2) {
          msg = "$attackerName used ${move.name}! $targetLabel's $statFullName rose sharply!";
        } else if (move.statChange > 0) {
          msg = "$attackerName used ${move.name}! $targetLabel's $statFullName rose!";
        } else if (move.statChange <= -2) {
          msg = "$attackerName used ${move.name}! $targetLabel's $statFullName harshly fell!";
        } else {
          msg = "$attackerName used ${move.name}! $targetLabel's $statFullName fell!";
        }
      } else if (move.statusEffect != null) {
        final inflicted = _tryInflictStatus(defender, move.statusEffect!);
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
      return events;
    }

    // 5. Damaging Move Calculation (Gen 4 Standard)
    int attackStat = move.category == MoveCategory.physical
        ? attacker.effectiveAtk
        : attacker.effectiveSpa;
    if (move.category == MoveCategory.physical && attacker.status == StatusCondition.burn) {
      attackStat = (attackStat * 0.5).round().clamp(1, 9999);
    }

    final int defenseStat = move.category == MoveCategory.physical
        ? defender.effectiveDef
        : defender.effectiveSpd;

    final double base =
        (((2 * attacker.level / 5 + 2) * move.power * attackStat / defenseStat) / 50) + 2;

    final double stab = attacker.species.types.contains(move.type) ? 1.5 : 1.0;
    final double typeMultiplier =
        PokemonTypeExtension.getEffectiveness(move.type, defender.species.types);

    final bool isCrit = typeMultiplier > 0 && _rng.nextInt(16) == 0;
    final double crit = isCrit ? 1.5 : 1.0;
    final double randomVariance = (85 + _rng.nextInt(16)) / 100.0;

    int damage = (base * crit * randomVariance * stab * typeMultiplier).floor();
    if (damage < 1 && typeMultiplier > 0) damage = 1;
    if (typeMultiplier == 0.0) damage = 0;

    defender.currentHp = (defender.currentHp - damage).clamp(0, defender.maxHp);

    // Secondary status chance on damaging move
    String? secondaryStatusLabel;
    if (!defender.isFainted &&
        typeMultiplier > 0 &&
        move.statusEffect != null &&
        move.statusChance > 0 &&
        _rng.nextInt(100) < move.statusChance) {
      secondaryStatusLabel = _tryInflictStatus(defender, move.statusEffect!);
    }

    final StringBuffer msgBuffer = StringBuffer("$attackerName used ${move.name}!");
    if (typeMultiplier == 0.0) {
      msgBuffer.write(" It had no effect on $defenderName.");
    } else {
      if (isCrit) msgBuffer.write(" A critical hit!");
      if (typeMultiplier >= 2.0) msgBuffer.write(" It's super effective!");
      if (typeMultiplier > 0 && typeMultiplier <= 0.5) {
        msgBuffer.write(" It's not very effective...");
      }
      if (secondaryStatusLabel != null) {
        msgBuffer.write(" $defenderName became $secondaryStatusLabel");
      }
    }

    events.add(BattleStepEvent(
      message: msgBuffer.toString(),
      isPlayerActor: isPlayer,
      moveId: move.id,
      moveType: move.type,
      moveCategory: move.category,
      damageDealt: damage,
      targetHpAfter: defender.currentHp,
      isCrit: isCrit,
      effectiveness: typeMultiplier,
      statusInflictedLabel: secondaryStatusLabel,
      targetFainted: defender.isFainted,
    ));

    if (defender.isFainted) {
      events.add(BattleStepEvent(
        message: "$defenderName fainted!",
        isPlayerActor: isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }

    return events;
  }

  static List<BattleStepEvent> _processEndOfTurnStatus(
    PokemonInstance mon, {
    required bool isPlayer,
    required bool isWild,
  }) {
    final List<BattleStepEvent> events = [];
    final monName = isPlayer
        ? mon.nickname
        : (isWild ? "Wild ${mon.nickname}" : mon.nickname);

    if (mon.status == StatusCondition.burn || mon.status == StatusCondition.poison) {
      final tickDmg = max(1, mon.maxHp ~/ 8);
      mon.currentHp = (mon.currentHp - tickDmg).clamp(0, mon.maxHp);
      final isBurn = mon.status == StatusCondition.burn;

      events.add(BattleStepEvent(
        message: isBurn
            ? "$monName was hurt by its burn!"
            : "$monName was hurt by poison!",
        isPlayerActor: !isPlayer, // Damage applies to this Pokémon as target
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
      }
    }
    return events;
  }

  static String? _tryInflictStatus(PokemonInstance target, String effect) {
    if (target.status != StatusCondition.none || target.isFainted) return null;

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
        return 'POISONED!';
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
}
