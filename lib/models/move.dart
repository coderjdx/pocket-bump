import 'pokemon_type.dart';

enum MoveCategory {
  physical,
  special,
  status,
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
  final String? statusEffect; // 'burn', 'poison', 'paralysis', 'sleep'
  final int statusChance; // 0-100

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
  }) : currentPp = currentPp ?? maxPp;

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
    );
  }
}
