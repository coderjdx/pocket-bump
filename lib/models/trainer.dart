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
  static const int numPcBoxes = 16;
  static const int maxPokemonPerBox = 20;
  static final Random _rng = Random();

  bool _suppressAutoSave = false;
  String name;
  TrainerAvatar avatar;
  List<PokemonInstance> party;
  late List<List<PokemonInstance>> pcBoxes;
  int activePcBoxIndex;
  int pokeBalls;
  int greatBalls;
  int ultraBalls;
  int potions;
  int superPotions;
  int hyperPotions;
  int revives;
  int antidotes;
  int paralyzeHeals;
  int awakenings;
  int burnHeals;
  int iceHeals;
  int fullHeals;
  int fullRestores;
  int money;
  int totalSteps;
  int dailySteps;
  String lastStepDate;
  int encounterSteps;
  int badges;
  Set<int> seenSpeciesIds;
  Set<int> caughtSpeciesIds;
  Set<int> shinyCaughtSpeciesIds;
  Set<int> unlockedGymIds;
  Set<int> clearedGymIds;
  Set<int> completedGymStepIds;
  Map<int, int> gymTodaySteps;
  Map<String, int> customItems;
  bool expShareEnabled;
  bool repelEnabled;

  Trainer({
    required this.name,
    TrainerAvatar? avatar,
    List<PokemonInstance>? party,
    List<List<PokemonInstance>>? pcBoxes,
    this.activePcBoxIndex = 0,
    this.pokeBalls = 20,
    this.greatBalls = 0,
    this.ultraBalls = 0,
    this.potions = 10,
    this.superPotions = 0,
    this.hyperPotions = 0,
    this.revives = 5,
    this.antidotes = 0,
    this.paralyzeHeals = 0,
    this.awakenings = 0,
    this.burnHeals = 0,
    this.iceHeals = 0,
    this.fullHeals = 0,
    this.fullRestores = 0,
    this.money = 3000,
    this.totalSteps = 0,
    this.dailySteps = 0,
    String? lastStepDate,
    this.encounterSteps = 0,
    this.badges = 0,
    Set<int>? seenSpeciesIds,
    Set<int>? caughtSpeciesIds,
    Set<int>? shinyCaughtSpeciesIds,
    Set<int>? unlockedGymIds,
    Set<int>? clearedGymIds,
    Set<int>? completedGymStepIds,
    Map<int, int>? gymTodaySteps,
    Map<String, int>? customItems,
    this.expShareEnabled = false,
    this.repelEnabled = false,
  })  : avatar = avatar ?? TrainerAvatar.presets.first,
        party = party ?? [],
        lastStepDate = lastStepDate ?? todayDateKey(),
        seenSpeciesIds = seenSpeciesIds ?? {},
        caughtSpeciesIds = caughtSpeciesIds ?? {},
        shinyCaughtSpeciesIds = shinyCaughtSpeciesIds ?? {},
        unlockedGymIds = unlockedGymIds ?? {1},
        clearedGymIds = clearedGymIds ?? {},
        completedGymStepIds = completedGymStepIds ?? {},
        gymTodaySteps = gymTodaySteps ?? {},
        customItems = customItems ?? {} {
    activePcBoxIndex = activePcBoxIndex.clamp(0, numPcBoxes - 1);
    this.pcBoxes = List.generate(numPcBoxes, (boxIdx) {
      if (pcBoxes != null && boxIdx < pcBoxes.length) {
        return List<PokemonInstance>.from(
          pcBoxes[boxIdx].take(maxPokemonPerBox),
        );
      }
      return <PokemonInstance>[];
    });
    for (final mon in this.party) {
      this.seenSpeciesIds.add(mon.species.id);
      this.caughtSpeciesIds.add(mon.species.id);
      if (mon.isShiny) {
        this.shinyCaughtSpeciesIds.add(mon.species.id);
      }
    }
    for (final box in this.pcBoxes) {
      for (final mon in box) {
        this.seenSpeciesIds.add(mon.species.id);
        this.caughtSpeciesIds.add(mon.species.id);
        if (mon.isShiny) {
          this.shinyCaughtSpeciesIds.add(mon.species.id);
        }
      }
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

  int get totalPcPokemon => pcBoxes.fold(0, (sum, box) => sum + box.length);
  int get maxPcCapacity => numPcBoxes * maxPokemonPerBox;
  bool get isStorageFull => party.length >= 6 && totalPcPokemon >= maxPcCapacity;
  List<PokemonInstance> get activePcBox => pcBoxes[activePcBoxIndex];

  Set<int> get _pcSpeciesIds =>
      pcBoxes.expand((box) => box.map((p) => p.species.id)).toSet();

  void setActivePcBox(int boxIndex) {
    final clamped = boxIndex.clamp(0, numPcBoxes - 1);
    if (activePcBoxIndex != clamped) {
      activePcBoxIndex = clamped;
      notifyListeners();
    }
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
      party.any((p) => p.species.id == speciesId) ||
      pcBoxes.any((box) => box.any((p) => p.species.id == speciesId));

  bool isSpeciesShinyCaught(int speciesId) =>
      shinyCaughtSpeciesIds.contains(speciesId) ||
      party.any((p) => p.species.id == speciesId && p.isShiny) ||
      pcBoxes.any(
          (box) => box.any((p) => p.species.id == speciesId && p.isShiny));

  bool isSpeciesSeen(int speciesId) =>
      seenSpeciesIds.contains(speciesId) || isSpeciesCaught(speciesId);

  int get caughtCount => caughtSpeciesIds
      .union(party.map((p) => p.species.id).toSet())
      .union(_pcSpeciesIds)
      .length;

  int get seenCount => seenSpeciesIds
      .union(caughtSpeciesIds)
      .union(party.map((p) => p.species.id).toSet())
      .union(_pcSpeciesIds)
      .length;

  void markPokemonSeen(int speciesId) {
    final added = seenSpeciesIds.add(speciesId);
    if (added && party.isNotEmpty) {
      notifyListeners();
    }
  }

  void markPokemonCaught(int speciesId, {bool isShiny = false}) {
    final addedSeen = seenSpeciesIds.add(speciesId);
    final addedCaught = caughtSpeciesIds.add(speciesId);
    final addedShiny = isShiny && shinyCaughtSpeciesIds.add(speciesId);
    if ((addedSeen || addedCaught || addedShiny) && party.isNotEmpty) {
      notifyListeners();
    }
  }

  int? _findAvailablePcBox([int? preferredIndex]) {
    if (preferredIndex != null) {
      if (preferredIndex < 0 || preferredIndex >= numPcBoxes) return null;
      return pcBoxes[preferredIndex].length < maxPokemonPerBox
          ? preferredIndex
          : null;
    }
    if (pcBoxes[activePcBoxIndex].length < maxPokemonPerBox) {
      return activePcBoxIndex;
    }
    for (int offset = 1; offset < numPcBoxes; offset++) {
      final idx = (activePcBoxIndex + offset) % numPcBoxes;
      if (pcBoxes[idx].length < maxPokemonPerBox) return idx;
    }
    return null;
  }

  /// Adds a newly captured Pokémon to the carried party (max 6) or stores it
  /// into the first available PC Box (16 boxes × 20 slots). Returns `null` if
  /// added to party, `1..16` if sent to a PC Box, or `-1` if all storage is full.
  int? addPokemon(PokemonInstance mon) {
    mon.resetBattleStateAndHeal();
    seenSpeciesIds.add(mon.species.id);
    caughtSpeciesIds.add(mon.species.id);
    if (mon.isShiny) {
      shinyCaughtSpeciesIds.add(mon.species.id);
    }
    if (party.length < 6) {
      party.add(mon);
      notifyListeners();
      return null;
    }
    final boxIdx = _findAvailablePcBox();
    if (boxIdx != null) {
      pcBoxes[boxIdx].add(mon);
      activePcBoxIndex = boxIdx;
      notifyListeners();
      return boxIdx + 1;
    }
    notifyListeners();
    return -1;
  }

  /// Replaces the traded Pokémon at [partyIndex] with [receivedMon], heals it,
  /// and registers its species (and shiny status if applicable) in Pokédex data.
  bool completeTradeSwap(int partyIndex, PokemonInstance receivedMon) {
    if (partyIndex < 0 || partyIndex >= party.length) return false;
    receivedMon.resetBattleStateAndHeal();
    party[partyIndex] = receivedMon;
    seenSpeciesIds.add(receivedMon.species.id);
    caughtSpeciesIds.add(receivedMon.species.id);
    if (receivedMon.isShiny) {
      shinyCaughtSpeciesIds.add(receivedMon.species.id);
    }
    notifyListeners();
    return true;
  }

  bool depositPokemonToPc(int partyIndex, {int? targetBoxIndex}) {
    if (party.length <= 1 || partyIndex < 0 || partyIndex >= party.length) {
      return false;
    }
    final boxIdx = _findAvailablePcBox(targetBoxIndex);
    if (boxIdx == null) return false;
    final mon = party.removeAt(partyIndex);
    mon.resetBattleStateAndHeal();
    pcBoxes[boxIdx].add(mon);
    if (targetBoxIndex == null) {
      activePcBoxIndex = boxIdx;
    }
    notifyListeners();
    return true;
  }

  bool withdrawPokemonFromPc(int boxIndex, int slotIndex) {
    if (party.length >= 6 || boxIndex < 0 || boxIndex >= numPcBoxes) {
      return false;
    }
    final box = pcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= box.length) return false;
    final mon = box.removeAt(slotIndex);
    mon.resetBattleStateAndHeal();
    party.add(mon);
    notifyListeners();
    return true;
  }

  bool swapPartyAndPcPokemon(int partyIndex, int boxIndex, int slotIndex) {
    if (partyIndex < 0 ||
        partyIndex >= party.length ||
        boxIndex < 0 ||
        boxIndex >= numPcBoxes) {
      return false;
    }
    final box = pcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= box.length) return false;
    final partyMon = party[partyIndex];
    final pcMon = box[slotIndex];
    partyMon.resetBattleStateAndHeal();
    pcMon.resetBattleStateAndHeal();
    party[partyIndex] = pcMon;
    box[slotIndex] = partyMon;
    notifyListeners();
    return true;
  }

  bool movePcPokemonToBox(int fromBoxIndex, int fromSlotIndex, int toBoxIndex) {
    if (fromBoxIndex < 0 ||
        fromBoxIndex >= numPcBoxes ||
        toBoxIndex < 0 ||
        toBoxIndex >= numPcBoxes ||
        fromBoxIndex == toBoxIndex) {
      return false;
    }
    final fromBox = pcBoxes[fromBoxIndex];
    final toBox = pcBoxes[toBoxIndex];
    if (fromSlotIndex < 0 ||
        fromSlotIndex >= fromBox.length ||
        toBox.length >= maxPokemonPerBox) {
      return false;
    }
    final mon = fromBox.removeAt(fromSlotIndex);
    toBox.add(mon);
    notifyListeners();
    return true;
  }

  bool releasePcPokemon(int boxIndex, int slotIndex) {
    if (boxIndex < 0 || boxIndex >= numPcBoxes) return false;
    final box = pcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= box.length) return false;
    final mon = box.removeAt(slotIndex);
    final held = mon.unequipHeldItem();
    if (held != null) {
      _applyItemDelta(held, 1);
    }
    notifyListeners();
    return true;
  }

  void resetAllPartyStatStages() {
    for (final mon in party) {
      mon.resetStatStages();
    }
    notifyListeners();
  }

  void healAndResetAllParty() {
    for (final mon in party) {
      mon.resetBattleStateAndHeal();
    }
    notifyListeners();
  }

  bool curePartyStatus(StatusCondition condition) {
    bool cured = false;
    for (final mon in party) {
      if (mon.status == condition) {
        mon.status = StatusCondition.none;
        cured = true;
      }
    }
    if (cured) notifyListeners();
    return cured;
  }

  bool cureAllPartyStatus() {
    bool cured = false;
    for (final mon in party) {
      if (mon.status != StatusCondition.none) {
        mon.status = StatusCondition.none;
        cured = true;
      }
    }
    if (cured) notifyListeners();
    return cured;
  }

  void fullRestoreParty() {
    for (final mon in party) {
      mon.currentHp = mon.maxHp;
      mon.status = StatusCondition.none;
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

  int get totalItems {
    int total = pokeBalls +
        greatBalls +
        ultraBalls +
        potions +
        superPotions +
        hyperPotions +
        revives +
        antidotes +
        paralyzeHeals +
        awakenings +
        burnHeals +
        iceHeals +
        fullHeals +
        fullRestores;
    for (final entry in customItems.entries) {
      if (entry.key == 'unknown_fossil' ||
          entry.key == 'fossil_restoration_voucher') {
        continue;
      }
      total += entry.value;
    }
    return total;
  }

  int get totalMedicine =>
      potions +
      superPotions +
      hyperPotions +
      revives +
      antidotes +
      paralyzeHeals +
      awakenings +
      burnHeals +
      iceHeals +
      fullHeals +
      fullRestores;

  void addMoney(int amount) {
    if (amount <= 0) return;
    money += amount;
    notifyListeners();
  }

  bool spendMoney(int amount) {
    if (amount <= 0) return true;
    if (money < amount) return false;
    money -= amount;
    notifyListeners();
    return true;
  }

  static int getGymStepRequirement(int gymId) {
    switch (gymId) {
      case 1:
        return 2000;
      case 2:
        return 4000;
      case 3:
        return 6000;
      case 4:
        return 8000;
      case 5:
        return 10000;
      case 6:
        return 12000;
      case 7:
        return 15000;
      case 8:
        return 20000;
      default:
        return 20000;
    }
  }

  static int getGymCaughtRequirement(int gymId) {
    switch (gymId) {
      case 1:
        return 10;
      case 2:
        return 18;
      case 3:
        return 28;
      case 4:
        return 40;
      case 5:
        return 55;
      case 6:
        return 70;
      case 7:
        return 85;
      case 8:
        return 100;
      default:
        return 100;
    }
  }

  bool isGymUnlocked(int gymId) => unlockedGymIds.contains(gymId);
  bool isGymCleared(int gymId) => clearedGymIds.contains(gymId);
  bool isGymStepCompleted(int gymId) => completedGymStepIds.contains(gymId);
  int getGymTodaySteps(int gymId) => gymTodaySteps[gymId] ?? 0;
  bool hasBadge(int gymId) => clearedGymIds.contains(gymId);

  bool canChallengeGym(int gymId) {
    if (!unlockedGymIds.contains(gymId)) return false;
    if (caughtCount < getGymCaughtRequirement(gymId)) return false;
    if (!completedGymStepIds.contains(gymId)) {
      if ((gymTodaySteps[gymId] ?? 0) < getGymStepRequirement(gymId)) {
        return false;
      }
    }
    return true;
  }

  void unlockGym(int gymId) {
    unlockedGymIds.add(gymId);
    notifyListeners();
  }

  void clearGym(int gymId) {
    clearedGymIds.add(gymId);
    badges = clearedGymIds.length;
    if (gymId < 8) {
      unlockedGymIds.add(gymId + 1);
    }
    notifyListeners();
  }

  int get maxObedienceLevel {
    final count = clearedGymIds.length;
    if (count >= 8) return 100;
    if (count >= 7) return 82;
    if (count >= 6) return 70;
    if (count >= 5) return 60;
    if (count >= 4) return 50;
    if (count >= 3) return 42;
    if (count >= 2) return 34;
    if (count >= 1) return 25;
    return 20;
  }

  static int getBadgesRequiredForLevel(int lvl) {
    if (lvl <= 20) return 0;
    if (lvl <= 25) return 1;
    if (lvl <= 34) return 2;
    if (lvl <= 42) return 3;
    if (lvl <= 50) return 4;
    if (lvl <= 60) return 5;
    if (lvl <= 70) return 6;
    if (lvl <= 82) return 7;
    return 8;
  }

  double getDisobedienceChance(int pokemonLevel) {
    final requiredBadges = getBadgesRequiredForLevel(pokemonLevel);
    final currentBadges = clearedGymIds.length;
    if (currentBadges >= requiredBadges) return 0.0;
    final missingBadges = (requiredBadges - currentBadges).clamp(1, 8);
    // Scales smoothly from 0.35 (missing 1 badge) to 0.60 (missing 8 badges)
    return 0.35 + (missingBadges - 1) * ((0.60 - 0.35) / 7.0);
  }

  bool get hasEarthBadge => clearedGymIds.contains(8);

  double get atkBadgeMultiplier =>
      (clearedGymIds.contains(1) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get spaBadgeMultiplier =>
      (clearedGymIds.contains(2) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get speBadgeMultiplier =>
      (clearedGymIds.contains(3) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get spdBadgeMultiplier =>
      (clearedGymIds.contains(4) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get defBadgeMultiplier =>
      (clearedGymIds.contains(5) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get hpBadgeMultiplier =>
      (clearedGymIds.contains(6) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);

  double get critBadgeBonus =>
      (clearedGymIds.contains(7) ? 0.10 : 0.0);

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
    final mon = party.removeAt(index);
    final held = mon.unequipHeldItem();
    if (held != null) {
      _applyItemDelta(held, 1);
    }
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
      gymTodaySteps.clear();
      lastStepDate = today;
    }
  }

  void _accumulateGymSteps(int delta) {
    if (delta <= 0) return;
    for (final gymId in unlockedGymIds) {
      if (!completedGymStepIds.contains(gymId)) {
        final current = (gymTodaySteps[gymId] ?? 0) + delta;
        gymTodaySteps[gymId] = current;
        if (current >= getGymStepRequirement(gymId)) {
          completedGymStepIds.add(gymId);
        }
      }
    }
  }

  /// Processes each step individually: increments today's total & hidden 0..400 encounter counter
  /// and rolls probability `encounterSteps / 400.0` (1/400 at step 1, 2/400 at step 2, ..., 400/400 at 400).
  /// When [repelEnabled] is true, wild encounters are suppressed.
  bool recordStepsAndCheckEncounter(int delta) {
    if (delta <= 0) return false;
    _syncDailyRollover();
    _accumulateGymSteps(delta);
    bool triggered = false;
    for (int i = 0; i < delta; i++) {
      dailySteps++;
      totalSteps++;
      if (!repelEnabled) {
        encounterSteps = (encounterSteps + 1).clamp(0, maxEncounterSteps);
        final double chance = encounterSteps / maxEncounterSteps;
        if (encounterSteps >= maxEncounterSteps || _rng.nextDouble() < chance) {
          encounterSteps = 0;
          triggered = true;
          break;
        }
      }
    }
    notifyListeners();
    return triggered;
  }

  void toggleExpShare([bool? value]) {
    expShareEnabled = value ?? !expShareEnabled;
    notifyListeners();
  }

  void toggleRepel([bool? value]) {
    repelEnabled = value ?? !repelEnabled;
    if (repelEnabled) {
      encounterSteps = 0;
    }
    notifyListeners();
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
    _accumulateGymSteps(delta);
    dailySteps += delta;
    totalSteps += delta;
    notifyListeners();
  }

  int getItemCount(String itemId) {
    switch (itemId) {
      case 'poke_ball':
        return pokeBalls;
      case 'great_ball':
        return greatBalls;
      case 'ultra_ball':
        return ultraBalls;
      case 'potion':
        return potions;
      case 'super_potion':
        return superPotions;
      case 'hyper_potion':
        return hyperPotions;
      case 'revive':
        return revives;
      case 'antidote':
        return antidotes;
      case 'paralyze_heal':
        return paralyzeHeals;
      case 'awakening':
        return awakenings;
      case 'burn_heal':
        return burnHeals;
      case 'ice_heal':
        return iceHeals;
      case 'full_heal':
        return fullHeals;
      case 'full_restore':
        return fullRestores;
      default:
        return customItems[itemId] ?? 0;
    }
  }

  void _applyItemDelta(String itemId, int delta) {
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
      case 'super_potion':
        superPotions = (superPotions + delta).clamp(0, 99);
        break;
      case 'hyper_potion':
        hyperPotions = (hyperPotions + delta).clamp(0, 99);
        break;
      case 'revive':
        revives = (revives + delta).clamp(0, 99);
        break;
      case 'antidote':
        antidotes = (antidotes + delta).clamp(0, 99);
        break;
      case 'paralyze_heal':
        paralyzeHeals = (paralyzeHeals + delta).clamp(0, 99);
        break;
      case 'awakening':
        awakenings = (awakenings + delta).clamp(0, 99);
        break;
      case 'burn_heal':
        burnHeals = (burnHeals + delta).clamp(0, 99);
        break;
      case 'ice_heal':
        iceHeals = (iceHeals + delta).clamp(0, 99);
        break;
      case 'full_heal':
        fullHeals = (fullHeals + delta).clamp(0, 99);
        break;
      case 'full_restore':
        fullRestores = (fullRestores + delta).clamp(0, 99);
        break;
      default:
        final current = customItems[itemId] ?? 0;
        final updated = (current + delta).clamp(0, 99);
        if (updated <= 0) {
          customItems.remove(itemId);
        } else {
          customItems[itemId] = updated;
        }
        break;
    }
  }

  void adjustItemCount(String itemId, int delta) {
    _applyItemDelta(itemId, delta);
    notifyListeners();
  }

  void grantWelcomeGift() {
    pokeBalls = 20;
    potions = 10;
    revives = 5;
    notifyListeners();
  }

  void claimSupplyDrop() {
    pokeBalls = (pokeBalls + 5).clamp(0, 99);
    greatBalls = (greatBalls + 2).clamp(0, 99);
    ultraBalls = (ultraBalls + 1).clamp(0, 99);
    potions = (potions + 3).clamp(0, 99);
    superPotions = (superPotions + 2).clamp(0, 99);
    revives = (revives + 1).clamp(0, 99);
    fullHeals = (fullHeals + 1).clamp(0, 99);
    antidotes = (antidotes + 1).clamp(0, 99);
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
      'superPotions': superPotions,
      'hyperPotions': hyperPotions,
      'revives': revives,
      'antidotes': antidotes,
      'paralyzeHeals': paralyzeHeals,
      'awakenings': awakenings,
      'burnHeals': burnHeals,
      'iceHeals': iceHeals,
      'fullHeals': fullHeals,
      'fullRestores': fullRestores,
      'money': money,
      'totalSteps': totalSteps,
      'dailySteps': dailySteps,
      'lastStepDate': lastStepDate,
      'encounterSteps': encounterSteps,
      'badges': badges,
      'seenSpeciesIds': seenSpeciesIds.toList()..sort(),
      'caughtSpeciesIds': caughtSpeciesIds.toList()..sort(),
      'shinyCaughtSpeciesIds': shinyCaughtSpeciesIds.toList()..sort(),
      'unlockedGymIds': unlockedGymIds.toList()..sort(),
      'clearedGymIds': clearedGymIds.toList()..sort(),
      'completedGymStepIds': completedGymStepIds.toList()..sort(),
      'gymTodaySteps': gymTodaySteps.map((k, v) => MapEntry(k.toString(), v)),
      'customItems': customItems,
      'expShareEnabled': expShareEnabled,
      'repelEnabled': repelEnabled,
      'party': party.map((mon) => mon.toJson()).toList(),
      'activePcBoxIndex': activePcBoxIndex,
      'pcBoxes': pcBoxes
          .map((box) => box.map((mon) => mon.toJson()).toList())
          .toList(),
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
    pokeBalls = ((json['pokeBalls'] as num?)?.toInt() ?? 20).clamp(0, 99);
    greatBalls = ((json['greatBalls'] as num?)?.toInt() ?? 0).clamp(0, 99);
    ultraBalls = ((json['ultraBalls'] as num?)?.toInt() ?? 0).clamp(0, 99);
    potions = ((json['potions'] as num?)?.toInt() ?? 10).clamp(0, 99);
    superPotions = ((json['superPotions'] as num?)?.toInt() ?? 0).clamp(0, 99);
    hyperPotions = ((json['hyperPotions'] as num?)?.toInt() ?? 0).clamp(0, 99);
    revives = ((json['revives'] as num?)?.toInt() ?? 5).clamp(0, 99);
    antidotes = ((json['antidotes'] as num?)?.toInt() ?? 0).clamp(0, 99);
    paralyzeHeals = ((json['paralyzeHeals'] as num?)?.toInt() ?? 0).clamp(0, 99);
    awakenings = ((json['awakenings'] as num?)?.toInt() ?? 0).clamp(0, 99);
    burnHeals = ((json['burnHeals'] as num?)?.toInt() ?? 0).clamp(0, 99);
    iceHeals = ((json['iceHeals'] as num?)?.toInt() ?? 0).clamp(0, 99);
    fullHeals = ((json['fullHeals'] as num?)?.toInt() ?? 0).clamp(0, 99);
    fullRestores = ((json['fullRestores'] as num?)?.toInt() ?? 0).clamp(0, 99);
    money = (json['money'] as num?)?.toInt() ?? 3000;
    totalSteps = max(0, (json['totalSteps'] as num?)?.toInt() ?? 0);
    dailySteps = max(0, (json['dailySteps'] as num?)?.toInt() ?? 0);
    lastStepDate = (json['lastStepDate'] as String?) ?? todayDateKey();
    encounterSteps = ((json['encounterSteps'] as num?)?.toInt() ?? 0)
        .clamp(0, maxEncounterSteps);
    _syncDailyRollover();
    badges = max(0, (json['badges'] as num?)?.toInt() ?? 0);

    unlockedGymIds = (json['unlockedGymIds'] as List<dynamic>? ?? [1])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    if (unlockedGymIds.isEmpty) unlockedGymIds.add(1);

    clearedGymIds = (json['clearedGymIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    badges = clearedGymIds.length;

    completedGymStepIds =
        (json['completedGymStepIds'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .toSet();

    gymTodaySteps = {};
    final rawGymSteps = json['gymTodaySteps'] as Map<String, dynamic>? ?? {};
    rawGymSteps.forEach((k, v) {
      final gid = int.tryParse(k);
      if (gid != null && v is num) {
        gymTodaySteps[gid] = v.toInt();
      }
    });

    customItems = {};
    final rawCustom = json['customItems'] as Map<String, dynamic>? ?? {};
    rawCustom.forEach((k, v) {
      if (v is num && v.toInt() > 0) {
        customItems[k] = v.toInt().clamp(0, 99);
      }
    });
    expShareEnabled = json['expShareEnabled'] == true;
    repelEnabled = json['repelEnabled'] == true;

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
    shinyCaughtSpeciesIds =
        (json['shinyCaughtSpeciesIds'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .toSet();
    for (final mon in party) {
      seenSpeciesIds.add(mon.species.id);
      caughtSpeciesIds.add(mon.species.id);
      if (mon.isShiny) {
        shinyCaughtSpeciesIds.add(mon.species.id);
      }
    }

    activePcBoxIndex = ((json['activePcBoxIndex'] as num?)?.toInt() ?? 0)
        .clamp(0, numPcBoxes - 1);
    final rawBoxes = json['pcBoxes'] as List<dynamic>? ?? const [];
    pcBoxes = List.generate(numPcBoxes, (boxIdx) {
      if (boxIdx >= rawBoxes.length || rawBoxes[boxIdx] is! List) {
        return <PokemonInstance>[];
      }
      final rawBox = rawBoxes[boxIdx] as List<dynamic>;
      final loadedBox = <PokemonInstance>[];
      for (final item in rawBox) {
        if (item is Map) {
          final mon = PokemonInstance.fromJson(Map<String, dynamic>.from(item));
          loadedBox.add(mon);
          seenSpeciesIds.add(mon.species.id);
          caughtSpeciesIds.add(mon.species.id);
          if (mon.isShiny) {
            shinyCaughtSpeciesIds.add(mon.species.id);
          }
        }
        if (loadedBox.length >= maxPokemonPerBox) break;
      }
      return loadedBox;
    });
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
    pcBoxes = List.generate(numPcBoxes, (_) => <PokemonInstance>[]);
    activePcBoxIndex = 0;
    pokeBalls = 20;
    greatBalls = 0;
    ultraBalls = 0;
    potions = 10;
    superPotions = 0;
    hyperPotions = 0;
    revives = 5;
    antidotes = 0;
    paralyzeHeals = 0;
    awakenings = 0;
    burnHeals = 0;
    iceHeals = 0;
    fullHeals = 0;
    fullRestores = 0;
    money = 3000;
    totalSteps = 0;
    dailySteps = 0;
    lastStepDate = todayDateKey();
    encounterSteps = 0;
    badges = 0;
    seenSpeciesIds = {};
    caughtSpeciesIds = {};
    shinyCaughtSpeciesIds = {};
    unlockedGymIds = {1};
    clearedGymIds = {};
    completedGymStepIds = {};
    gymTodaySteps = {};
    customItems = {};
    expShareEnabled = false;
    repelEnabled = false;
    _suppressAutoSave = false;
    super.notifyListeners();
  }
}
