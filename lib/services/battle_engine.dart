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

class BattleResult {
  final List<String> battleLog;
  final bool isBattleOver;
  final bool playerWon;
  final bool isCaught;

  BattleResult({
    required this.battleLog,
    this.isBattleOver = false,
    this.playerWon = false,
    this.isCaught = false,
  });
}

class BattleEngine {
  static final Random _rng = Random();

  /// Calculates turn results between Player's action and Opponent's action
  static List<String> resolveTurn({
    required PokemonInstance playerMon,
    required BattleAction playerAction,
    required PokemonInstance opponentMon,
    required BattleAction opponentAction,
  }) {
    List<String> log = [];

    // 1. Handle Switches or Items (Highest Priority)
    if (playerAction.type == BattleActionType.useItem) {
      log.add("You used an item!");
    }

    // 2. Determine Move Execution Order (Priority -> Speed)
    bool playerGoesFirst = true;

    if (playerAction.type == BattleActionType.fight && opponentAction.type == BattleActionType.fight) {
      final pPriority = playerAction.move!.priority;
      final oPriority = opponentAction.move!.priority;

      if (pPriority != oPriority) {
        playerGoesFirst = pPriority > oPriority;
      } else {
        if (playerMon.spe != opponentMon.spe) {
          playerGoesFirst = playerMon.spe > opponentMon.spe;
        } else {
          playerGoesFirst = _rng.nextBool();
        }
      }
    }

    // 3. Execute First Move
    if (playerGoesFirst) {
      if (playerAction.type == BattleActionType.fight && !playerMon.isFainted) {
        _executeAttack(playerMon, playerAction.move!, opponentMon, log, isPlayer: true);
      }
      if (!opponentMon.isFainted && opponentAction.type == BattleActionType.fight) {
        _executeAttack(opponentMon, opponentAction.move!, playerMon, log, isPlayer: false);
      }
    } else {
      if (opponentAction.type == BattleActionType.fight && !opponentMon.isFainted) {
        _executeAttack(opponentMon, opponentAction.move!, playerMon, log, isPlayer: false);
      }
      if (!playerMon.isFainted && playerAction.type == BattleActionType.fight) {
        _executeAttack(playerMon, playerAction.move!, opponentMon, log, isPlayer: true);
      }
    }

    return log;
  }

  static void _executeAttack(
    PokemonInstance attacker,
    Move move,
    PokemonInstance defender,
    List<String> log, {
    required bool isPlayer,
  }) {
    final attackerName = isPlayer ? attacker.nickname : "Wild ${attacker.nickname}";
    final defenderName = isPlayer ? "Wild ${defender.nickname}" : defender.nickname;

    log.add("$attackerName used ${move.name}!");

    // Accuracy Check
    final roll = _rng.nextInt(100) + 1;
    if (roll > move.accuracy) {
      log.add("$attackerName's attack missed!");
      return;
    }

    // Status Moves
    if (move.category == MoveCategory.status || move.power == 0) {
      log.add("It had a tactical effect!");
      return;
    }

    // Damage Calculation (Gen 4 Standard)
    final int A = move.category == MoveCategory.physical ? attacker.atk : attacker.spa;
    final int D = move.category == MoveCategory.physical ? defender.def : defender.spd;

    double base = (((2 * attacker.level / 5 + 2) * move.power * A / D) / 50) + 2;

    // STAB (Same-Type Attack Bonus)
    double stab = attacker.species.types.contains(move.type) ? 1.5 : 1.0;

    // Type Effectiveness
    double typeMultiplier = PokemonTypeExtension.getEffectiveness(move.type, defender.species.types);

    // Critical Hit (6.25% chance in Gen 4)
    bool isCrit = _rng.nextInt(16) == 0;
    double crit = isCrit ? 1.5 : 1.0;

    // Random Variance (0.85 to 1.00)
    double randomVariance = (85 + _rng.nextInt(16)) / 100.0;

    int damage = (base * crit * randomVariance * stab * typeMultiplier).floor();
    if (damage < 1 && typeMultiplier > 0) damage = 1;

    defender.currentHp = (defender.currentHp - damage).clamp(0, defender.maxHp);

    if (isCrit) log.add("A critical hit!");
    if (typeMultiplier >= 2.0) log.add("It's super effective!");
    if (typeMultiplier > 0 && typeMultiplier <= 0.5) log.add("It's not very effective...");
    if (typeMultiplier == 0.0) log.add("It had no effect on $defenderName.");

    if (defender.isFainted) {
      log.add("$defenderName fainted!");
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
    double b = 65536 * pow(a / 255.0, 0.25);
    for (int i = 0; i < 4; i++) {
      if (_rng.nextInt(65536) >= b) {
        return false; // Broke free on this shake
      }
    }
    return true; // All 4 shakes passed!
  }
}
