import 'package:flutter/foundation.dart';
import 'pokemon_instance.dart';
import 'trainer_avatar.dart';

class Trainer extends ChangeNotifier {
  String name;
  TrainerAvatar avatar;
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
    TrainerAvatar? avatar,
    List<PokemonInstance>? party,
    this.pokeBalls = 10,
    this.greatBalls = 3,
    this.ultraBalls = 1,
    this.potions = 5,
    this.revives = 2,
    this.totalSteps = 0,
    this.badges = 0,
  })  : avatar = avatar ?? TrainerAvatar.presets.first,
        party = party ?? [];

  PokemonInstance? get leadPokemon {
    if (party.isEmpty) return null;
    return party.firstWhere((p) => !p.isFainted, orElse: () => party.first);
  }

  bool get hasConsciousPokemon {
    return party.any((p) => !p.isFainted);
  }

  void setIdentity({
    required String newName,
    required TrainerAvatar newAvatar,
  }) {
    name = newName.trim().isEmpty ? 'Red' : newName.trim();
    avatar = newAvatar;
    notifyListeners();
  }

  void addPokemon(PokemonInstance mon) {
    mon.resetBattleStateAndHeal();
    if (party.length < 6) {
      party.add(mon);
      notifyListeners();
    }
  }

  void healAndResetAllParty() {
    for (final mon in party) {
      mon.resetBattleStateAndHeal();
    }
    notifyListeners();
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
