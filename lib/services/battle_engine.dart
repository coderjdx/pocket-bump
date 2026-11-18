import 'dart:math';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';

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
    Trainer? playerTrainer,
  }) {
    final List<BattleStepEvent> events = [];

    // Pre-turn held berry triggers (e.g. status cures)
    final preBerryPlayer = checkAndConsumeHeldBerry(playerMon, isPlayer: true, isWild: isWild);
    if (preBerryPlayer != null) events.add(preBerryPlayer);
    final preBerryOpp = checkAndConsumeHeldBerry(opponentMon, isPlayer: false, isWild: isWild);
    if (preBerryOpp != null) events.add(preBerryOpp);

    // Determine Move Execution Order (Priority -> Speed)
    bool playerGoesFirst = true;

    if (playerAction.type == BattleActionType.fight &&
        opponentAction.type == BattleActionType.fight) {
      final pPriority = playerAction.move!.priority;
      final oPriority = opponentAction.move!.priority;

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
    }

    if (playerGoesFirst) {
      if (playerAction.type == BattleActionType.fight && !playerMon.isFainted) {
        events.addAll(executeSingleAttack(
          playerMon,
          playerAction.move!,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
      if (!opponentMon.isFainted && opponentAction.type == BattleActionType.fight) {
        events.addAll(executeSingleAttack(
          opponentMon,
          opponentAction.move!,
          playerMon,
          isPlayer: false,
          isWild: isWild,
          playerTrainer: playerTrainer,
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
          playerTrainer: playerTrainer,
        ));
      }
      if (!playerMon.isFainted && playerAction.type == BattleActionType.fight) {
        events.addAll(executeSingleAttack(
          playerMon,
          playerAction.move!,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
        ));
      }
    }

    // End-of-turn Burn / Poison tick damage & Leftovers
    if (!playerMon.isFainted && !opponentMon.isFainted) {
      events.addAll(processEndOfTurnStatus(playerMon, isPlayer: true, isWild: isWild));
      if (!playerMon.isFainted) {
        events.addAll(processEndOfTurnStatus(opponentMon, isPlayer: false, isWild: isWild));
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

    // 1. Pre-move status check (Sleep / Paralysis)
    if (attacker.status == StatusCondition.sleep) {
      if (random.nextInt(3) == 0) {
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
      if (random.nextInt(4) == 0) {
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
    final accRoll = random.nextInt(100) + 1;
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

      // Check if defender holds a berry that cures the newly inflicted status
      final berryEvent = checkAndConsumeHeldBerry(defender, isPlayer: !isPlayer, isWild: isWild);
      if (berryEvent != null) {
        events.add(berryEvent);
      }
      return events;
    }

    // 5. Damaging Move Calculation (Gen 4 Standard + Badge Boosts + Held Item Boosts)
    int attackStat = move.category == MoveCategory.physical
        ? attacker.effectiveAtk
        : attacker.effectiveSpa;
    if (isPlayer && playerTrainer != null) {
      final double badgeMult = move.category == MoveCategory.physical
          ? playerTrainer.atkBadgeMultiplier
          : playerTrainer.spaBadgeMultiplier;
      attackStat = (attackStat * badgeMult).round();
    }
    if (move.category == MoveCategory.physical && attacker.status == StatusCondition.burn) {
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
        (((2 * attacker.level / 5 + 2) * move.power * attackStat / defenseStat) / 50) + 2;

    final double stab = attacker.species.types.contains(move.type) ? 1.5 : 1.0;
    final double typeMultiplier =
        PokemonTypeExtension.getEffectiveness(move.type, defender.species.types);

    final int critThreshold =
        (isPlayer && playerTrainer != null && playerTrainer.critBadgeBonus > 0) ? 8 : 16;
    final bool isCrit = typeMultiplier > 0 && random.nextInt(critThreshold) == 0;
    final double crit = isCrit ? 1.5 : 1.0;
    final double randomVariance = (85 + random.nextInt(16)) / 100.0;
    final double heldItemMultiplier = _getHeldItemDamageMultiplier(attacker, move.type);

    int damage = (base * crit * randomVariance * stab * typeMultiplier * heldItemMultiplier).floor();
    if (damage < 1 && typeMultiplier > 0) damage = 1;
    if (typeMultiplier == 0.0) damage = 0;

    defender.currentHp = (defender.currentHp - damage).clamp(0, defender.maxHp);

    // Secondary status chance on damaging move
    String? secondaryStatusLabel;
    if (!defender.isFainted &&
        typeMultiplier > 0 &&
        move.statusEffect != null &&
        move.statusChance > 0 &&
        random.nextInt(100) < move.statusChance) {
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

    // Check if defender's held berry triggers (e.g. Oran/Sitrus on <=50% HP or status cure)
    if (!defender.isFainted) {
      final berryEvent = checkAndConsumeHeldBerry(defender, isPlayer: !isPlayer, isWild: isWild);
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

    return events;
  }

  static List<BattleStepEvent> processEndOfTurnStatus(
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
      }
    }

    // Leftovers healing at end of turn
    if (!mon.isFainted && mon.heldItemId == 'leftovers' && mon.currentHp < mon.maxHp) {
      final heal = max(1, mon.maxHp ~/ 16);
      mon.currentHp = min(mon.maxHp, mon.currentHp + heal);
      events.add(BattleStepEvent(
        message: "$monName restored a little HP with its Leftovers!",
        isPlayerActor: isPlayer,
        targetHpAfter: mon.currentHp,
        isStatusTick: true,
      ));
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
