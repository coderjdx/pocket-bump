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
    );
  }
}
