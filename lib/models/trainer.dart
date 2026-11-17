import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pokemon_instance.dart';
import 'trainer_avatar.dart';

class Trainer extends ChangeNotifier {
  static const String _saveKey = 'pocket_bump_save_v1';
  static const String _backupSaveKey = 'pocket_bump_save_backup';
  static const int currentSchemaVersion = 1;
  static const int maxEncounterSteps = 400;
  static final Random _rng = Random();

  bool _suppressAutoSave = false;
  String name;
  TrainerAvatar avatar;
  List<PokemonInstance> party;
  int pokeBalls;
  int greatBalls;
  int ultraBalls;
  int potions;
  int revives;
  int totalSteps;
  int dailySteps;
  String lastStepDate;
  int encounterSteps;
  int badges;
  Set<int> seenSpeciesIds;
  Set<int> caughtSpeciesIds;

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
    this.dailySteps = 0,
    String? lastStepDate,
    this.encounterSteps = 0,
    this.badges = 0,
    Set<int>? seenSpeciesIds,
    Set<int>? caughtSpeciesIds,
  })  : avatar = avatar ?? TrainerAvatar.presets.first,
        party = party ?? [],
        lastStepDate = lastStepDate ?? todayDateKey(),
        seenSpeciesIds = seenSpeciesIds ?? {},
        caughtSpeciesIds = caughtSpeciesIds ?? {} {
    for (final mon in this.party) {
      this.seenSpeciesIds.add(mon.species.id);
      this.caughtSpeciesIds.add(mon.species.id);
    }
  }

  static String todayDateKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

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

  bool isSpeciesCaught(int speciesId) =>
      caughtSpeciesIds.contains(speciesId) ||
      party.any((p) => p.species.id == speciesId);

  bool isSpeciesSeen(int speciesId) =>
      seenSpeciesIds.contains(speciesId) || isSpeciesCaught(speciesId);

  int get caughtCount => caughtSpeciesIds
      .union(party.map((p) => p.species.id).toSet())
      .length;

  int get seenCount => seenSpeciesIds
      .union(caughtSpeciesIds)
      .union(party.map((p) => p.species.id).toSet())
      .length;

  void markPokemonSeen(int speciesId) {
    final added = seenSpeciesIds.add(speciesId);
    if (added && party.isNotEmpty) {
      notifyListeners();
    }
  }

  void markPokemonCaught(int speciesId) {
    final addedSeen = seenSpeciesIds.add(speciesId);
    final addedCaught = caughtSpeciesIds.add(speciesId);
    if ((addedSeen || addedCaught) && party.isNotEmpty) {
      notifyListeners();
    }
  }

  void addPokemon(PokemonInstance mon) {
    mon.resetBattleStateAndHeal();
    seenSpeciesIds.add(mon.species.id);
    caughtSpeciesIds.add(mon.species.id);
    if (party.length < 6) {
      party.add(mon);
    }
    notifyListeners();
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

  int get todaySteps {
    _syncDailyRollover();
    return dailySteps;
  }

  /// Proportional encounter chance: 0.0 (0%) at 0 steps, 0.25 (25%) at 100, 0.50 (50%) at 200, 1.0 (100%) at 400.
  double get encounterChance =>
      (encounterSteps / maxEncounterSteps).clamp(0.0, 1.0);

  void _syncDailyRollover() {
    final today = todayDateKey();
    if (lastStepDate != today) {
      dailySteps = 0;
      lastStepDate = today;
    }
  }

  /// Processes each step individually: increments today's total & hidden 0..400 encounter counter
  /// and rolls probability `encounterSteps / 400.0` (1/400 at step 1, 2/400 at step 2, ..., 400/400 at 400).
  bool recordStepsAndCheckEncounter(int delta) {
    if (delta <= 0) return false;
    _syncDailyRollover();
    bool triggered = false;
    for (int i = 0; i < delta; i++) {
      dailySteps++;
      totalSteps++;
      encounterSteps = (encounterSteps + 1).clamp(0, maxEncounterSteps);
      final double chance = encounterSteps / maxEncounterSteps;
      if (encounterSteps >= maxEncounterSteps || _rng.nextDouble() < chance) {
        encounterSteps = 0;
        triggered = true;
        break;
      }
    }
    notifyListeners();
    return triggered;
  }

  void resetEncounterSteps() {
    if (encounterSteps != 0) {
      encounterSteps = 0;
      notifyListeners();
    }
  }

  void addSteps(int delta) {
    if (delta <= 0) return;
    _syncDailyRollover();
    dailySteps += delta;
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

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'name': name,
      'avatarId': avatar.id,
      'pokeBalls': pokeBalls,
      'greatBalls': greatBalls,
      'ultraBalls': ultraBalls,
      'potions': potions,
      'revives': revives,
      'totalSteps': totalSteps,
      'dailySteps': dailySteps,
      'lastStepDate': lastStepDate,
      'encounterSteps': encounterSteps,
      'badges': badges,
      'seenSpeciesIds': seenSpeciesIds.toList()..sort(),
      'caughtSpeciesIds': caughtSpeciesIds.toList()..sort(),
      'party': party.map((mon) => mon.toJson()).toList(),
    };
  }

  void applyFromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] as String?)?.trim() ?? 'Red';
    name = rawName.isEmpty ? 'Red' : rawName;
    final avatarId = json['avatarId'] as String?;
    avatar = TrainerAvatar.presets.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => TrainerAvatar.presets.first,
    );
    pokeBalls = ((json['pokeBalls'] as num?)?.toInt() ?? 10).clamp(0, 99);
    greatBalls = ((json['greatBalls'] as num?)?.toInt() ?? 3).clamp(0, 99);
    ultraBalls = ((json['ultraBalls'] as num?)?.toInt() ?? 1).clamp(0, 99);
    potions = ((json['potions'] as num?)?.toInt() ?? 5).clamp(0, 99);
    revives = ((json['revives'] as num?)?.toInt() ?? 2).clamp(0, 99);
    totalSteps = max(0, (json['totalSteps'] as num?)?.toInt() ?? 0);
    dailySteps = max(0, (json['dailySteps'] as num?)?.toInt() ?? 0);
    lastStepDate = (json['lastStepDate'] as String?) ?? todayDateKey();
    encounterSteps = ((json['encounterSteps'] as num?)?.toInt() ?? 0)
        .clamp(0, maxEncounterSteps);
    _syncDailyRollover();
    badges = max(0, (json['badges'] as num?)?.toInt() ?? 0);

    final rawParty = json['party'] as List<dynamic>? ?? const [];
    final loadedParty = <PokemonInstance>[];
    for (final item in rawParty) {
      if (item is Map) {
        loadedParty.add(
          PokemonInstance.fromJson(Map<String, dynamic>.from(item)),
        );
      }
      if (loadedParty.length >= 6) break;
    }
    party = loadedParty;

    seenSpeciesIds = (json['seenSpeciesIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    caughtSpeciesIds = (json['caughtSpeciesIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    for (final mon in party) {
      seenSpeciesIds.add(mon.species.id);
      caughtSpeciesIds.add(mon.species.id);
    }
  }

  Future<void> saveProgress() async {
    if (party.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(toJson());
      await prefs.setString(_saveKey, encoded);
      await prefs.setString(_backupSaveKey, encoded);
    } catch (_) {}
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_suppressAutoSave && party.isNotEmpty) {
      saveProgress();
    }
  }

  static Future<Trainer> loadOrCreate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey) ?? prefs.getString(_backupSaveKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final trainer = Trainer(name: 'Red');
          trainer.applyFromJson(Map<String, dynamic>.from(decoded));
          if (trainer.party.isNotEmpty) {
            return trainer;
          }
        }
      }
    } catch (_) {}
    return Trainer(name: 'Red');
  }

  Future<void> deleteSaveAndReset() async {
    _suppressAutoSave = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
      await prefs.remove(_backupSaveKey);
    } catch (_) {}
    name = 'Red';
    avatar = TrainerAvatar.presets.first;
    party = [];
    pokeBalls = 10;
    greatBalls = 3;
    ultraBalls = 1;
    potions = 5;
    revives = 2;
    totalSteps = 0;
    dailySteps = 0;
    lastStepDate = todayDateKey();
    encounterSteps = 0;
    badges = 0;
    seenSpeciesIds = {};
    caughtSpeciesIds = {};
    _suppressAutoSave = false;
    super.notifyListeners();
  }
}
