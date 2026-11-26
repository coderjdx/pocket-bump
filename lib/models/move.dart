import 'pokemon_type.dart';

enum MoveCategory {
  physical,
  special,
  status,
}

enum MoveTarget {
  singleAdjacent,
  allFoes,
  allOthers,
  self,
  allyOnly,
  allyOrSelf,
  userSide,
  foeSide,
  entireField,
  randomFoe,
}

enum MoveStageMechanic {
  none,
  twoTurnCharge,
  semiInvulnerable,
  rechargeAfterHit,
  bide,
  rampage,
  escalatingRoll,
  trapDot,
}

class Move {
  final String id;
  final String name;
  final PokemonType type;
  final MoveCategory category;
  final int power;
  final int accuracy;
  final int maxPp;
  int currentPp;
  final int priority;
  final String description;
  final String? statTarget; // 'atk', 'def', 'spa', 'spd', 'spe'
  final int statChange; // + buffs user, - debuffs target
  final String? statusEffect; // 'burn', 'poison', 'paralysis', 'sleep', 'confusion'
  final int statusChance; // 0-100
  final int minHits;
  final int maxHits;
  final MoveStageMechanic stageMechanic;
  final String? chargeStatusMessage;
  final String? chargeSelfStatTarget;
  final int chargeSelfStatChange;

  Move({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    required this.power,
    required this.accuracy,
    required this.maxPp,
    int? currentPp,
    this.priority = 0,
    required this.description,
    this.statTarget,
    this.statChange = 0,
    this.statusEffect,
    this.statusChance = 0,
    this.minHits = 1,
    this.maxHits = 1,
    this.stageMechanic = MoveStageMechanic.none,
    this.chargeStatusMessage,
    this.chargeSelfStatTarget,
    this.chargeSelfStatChange = 0,
  }) : currentPp = currentPp ?? maxPp;

  bool get isMultiHit => maxHits > 1;
  bool get isVariableMultiHit => maxHits > minHits;
  bool get isTwoTurnCharge =>
      stageMechanic == MoveStageMechanic.twoTurnCharge ||
      stageMechanic == MoveStageMechanic.semiInvulnerable;

  String get powerLabel {
    if (power <= 0) return '—';
    if (isMultiHit) {
      return minHits == maxHits ? '$power×$minHits' : '$power×$minHits-$maxHits';
    }
    return '$power';
  }

  Move copy() {
    return Move(
      id: id,
      name: name,
      type: type,
      category: category,
      power: power,
      accuracy: accuracy,
      maxPp: maxPp,
      currentPp: currentPp,
      priority: priority,
      description: description,
      statTarget: statTarget,
      statChange: statChange,
      statusEffect: statusEffect,
      statusChance: statusChance,
      minHits: minHits,
      maxHits: maxHits,
      stageMechanic: stageMechanic,
      chargeStatusMessage: chargeStatusMessage,
      chargeSelfStatTarget: chargeSelfStatTarget,
      chargeSelfStatChange: chargeSelfStatChange,
    );
  }
}
