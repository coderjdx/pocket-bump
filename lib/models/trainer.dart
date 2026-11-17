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

  int get totalItems => pokeBalls + greatBalls + ultraBalls + potions + revives;

  void setLeadPokemon(int index) {
    if (index <= 0 || index >= party.length) return;
    final selected = party.removeAt(index);
    party.insert(0, selected);
    notifyListeners();
  }

  void swapPartySlots(int indexA, int indexB) {
    if (indexA < 0 ||
        indexB < 0 ||
        indexA >= party.length ||
        indexB >= party.length ||
        indexA == indexB) {
      return;
    }
    final tmp = party[indexA];
    party[indexA] = party[indexB];
    party[indexB] = tmp;
    notifyListeners();
  }

  bool releasePokemon(int index) {
    if (party.length <= 1 || index < 0 || index >= party.length) return false;
    party.removeAt(index);
    notifyListeners();
    return true;
  }

  void addSteps(int delta) {
    if (delta <= 0) return;
    totalSteps += delta;
    notifyListeners();
  }

  void adjustItemCount(String itemId, int delta) {
    switch (itemId) {
      case 'poke_ball':
        pokeBalls = (pokeBalls + delta).clamp(0, 99);
        break;
      case 'great_ball':
        greatBalls = (greatBalls + delta).clamp(0, 99);
        break;
      case 'ultra_ball':
        ultraBalls = (ultraBalls + delta).clamp(0, 99);
        break;
      case 'potion':
        potions = (potions + delta).clamp(0, 99);
        break;
      case 'revive':
        revives = (revives + delta).clamp(0, 99);
        break;
      default:
        return;
    }
    notifyListeners();
  }

  void claimSupplyDrop() {
    pokeBalls = (pokeBalls + 5).clamp(0, 99);
    greatBalls = (greatBalls + 2).clamp(0, 99);
    ultraBalls = (ultraBalls + 1).clamp(0, 99);
    potions = (potions + 3).clamp(0, 99);
    revives = (revives + 1).clamp(0, 99);
    notifyListeners();
  }
}
