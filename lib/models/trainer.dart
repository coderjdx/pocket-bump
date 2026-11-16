import 'package:flutter/foundation.dart';
import 'pokemon_instance.dart';

class Trainer extends ChangeNotifier {
  String name;
  List<PokemonInstance> party;
  int pokeBalls;
  int greatBalls;
  int ultraBalls;
  int potions;
  int revives;
  int totalSteps;
  int badges;

  Trainer({
    required this.name,
    List<PokemonInstance>? party,
    this.pokeBalls = 10,
    this.greatBalls = 3,
    this.ultraBalls = 1,
    this.potions = 5,
    this.revives = 2,
    this.totalSteps = 0,
    this.badges = 0,
  }) : party = party ?? [];

  PokemonInstance? get leadPokemon {
    return party.firstWhere((p) => !p.isFainted, orElse: () => party.first);
  }

  bool get hasConsciousPokemon {
    return party.any((p) => !p.isFainted);
  }

  void addPokemon(PokemonInstance mon) {
    if (party.length < 6) {
      party.add(mon);
      notifyListeners();
    }
  }

  void usePokeBall() {
    if (pokeBalls > 0) {
      pokeBalls--;
      notifyListeners();
    }
  }

  void usePotion() {
    if (potions > 0) {
      potions--;
      notifyListeners();
    }
  }
}
