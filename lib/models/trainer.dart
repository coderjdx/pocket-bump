import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pokedex_database.dart';
import 'game_region.dart';
import 'game_version.dart';
import 'item.dart';
import 'mystery_egg.dart';
import 'pokemon_instance.dart';
import 'region_save.dart';
import 'rival.dart';
import 'trainer_avatar.dart';

class Trainer extends ChangeNotifier {
  static const String _saveKey = 'pocket_bump_save_v1';
  static const String _backupSaveKey = 'pocket_bump_save_backup';
  static const int currentSchemaVersion = 2;
  static const int maxEncounterSteps = RegionSave.maxEncounterSteps;
  static const int numPcBoxes = RegionSave.numPcBoxes;
  static const int maxPokemonPerBox = RegionSave.maxPokemonPerBox;
  static final Random _rng = Random();

  bool _suppressAutoSave = false;
  String name;
  String? accountId; // Reserved for live trainer accounts
  TrainerAvatar avatar;
  int totalSteps;
  int dailySteps;
  String lastStepDate;
  Set<String> redeemedGiftCodes;
  List<RivalRecord> rivals;

  GameRegion activeRegion;
  Set<GameRegion> unlockedRegions;
  late Map<GameRegion, RegionSave> regionSaves;

  // Global Battle Frontier state
  List<PokemonInstance> frontierParty;
  late List<List<PokemonInstance>> frontierPcBoxes;
  int frontierBattlePoints;
  Map<String, int> frontierCustomItems;
  int frontierTowerBestSingles;
  int frontierTowerBestDoubles;
  int frontierFactoryBestSingles;
  int frontierFactoryBestDoubles;

  // Transient battle override (never saved; used by Battle Frontier & Frontier PvP)
  List<PokemonInstance>? _battlePartyOverride;
  bool _suppressBadgeBonuses = false;
  bool hp10MigrationApplied = true;

  Trainer({
    required this.name,
    this.accountId,
    TrainerAvatar? avatar,
    GameVersion? gameVersion,
    List<PokemonInstance>? party,
    List<List<PokemonInstance>>? pcBoxes,
    int activePcBoxIndex = 0,
    int pokeBalls = 20,
    int greatBalls = 0,
    int ultraBalls = 0,
    int masterBalls = 0,
    int potions = 10,
    int superPotions = 0,
    int hyperPotions = 0,
    int revives = 5,
    int antidotes = 0,
    int paralyzeHeals = 0,
    int awakenings = 0,
    int burnHeals = 0,
    int iceHeals = 0,
    int fullHeals = 0,
    int fullRestores = 0,
    int money = 3000,
    this.totalSteps = 0,
    this.dailySteps = 0,
    String? lastStepDate,
    int encounterSteps = 0,
    int badges = 0,
    Set<int>? seenSpeciesIds,
    Set<int>? caughtSpeciesIds,
    Set<int>? shinyCaughtSpeciesIds,
    Set<int>? unlockedGymIds,
    Set<int>? clearedGymIds,
    Set<int>? completedGymStepIds,
    Map<int, int>? gymTodaySteps,
    Map<String, int>? customItems,
    bool expShareEnabled = false,
    bool hasEarnedExpeditionMasterBall = false,
    Set<int>? caughtExpeditionLegendaryIds,
    bool victoryRoadCleared = false,
    int championClears = 0,
    List<Map<String, dynamic>>? hallOfFameEntries,
    Set<String>? redeemedGiftCodes,
    Set<String>? claimedEventGiftIds,
    List<RivalRecord>? rivals,
    this.activeRegion = GameRegion.kanto,
    Set<GameRegion>? unlockedRegions,
    Map<GameRegion, RegionSave>? regionSaves,
    List<PokemonInstance>? frontierParty,
    List<List<PokemonInstance>>? frontierPcBoxes,
    this.frontierBattlePoints = 0,
    Map<String, int>? frontierCustomItems,
    this.frontierTowerBestSingles = 0,
    this.frontierTowerBestDoubles = 0,
    this.frontierFactoryBestSingles = 0,
    this.frontierFactoryBestDoubles = 0,
  }) : avatar = avatar ?? TrainerAvatar.presets.first,
        lastStepDate = lastStepDate ?? todayDateKey(),
        redeemedGiftCodes = redeemedGiftCodes ?? {},
        rivals = rivals ?? [],
        unlockedRegions = unlockedRegions ?? {GameRegion.kanto},
        frontierParty = frontierParty ?? [],
        frontierCustomItems = frontierCustomItems ?? {} {
    if (regionSaves != null) {
      this.regionSaves = Map<GameRegion, RegionSave>.from(regionSaves);
      this.regionSaves.putIfAbsent(
            activeRegion,
            () => RegionSave(region: activeRegion),
          );
    } else {
      this.regionSaves = {
        activeRegion: RegionSave(
          region: activeRegion,
          gameVersion: gameVersion,
          party: party,
          pcBoxes: pcBoxes,
          activePcBoxIndex: activePcBoxIndex,
          pokeBalls: pokeBalls,
          greatBalls: greatBalls,
          ultraBalls: ultraBalls,
          masterBalls: masterBalls,
          potions: potions,
          superPotions: superPotions,
          hyperPotions: hyperPotions,
          revives: revives,
          antidotes: antidotes,
          paralyzeHeals: paralyzeHeals,
          awakenings: awakenings,
          burnHeals: burnHeals,
          iceHeals: iceHeals,
          fullHeals: fullHeals,
          fullRestores: fullRestores,
          money: money,
          encounterSteps: encounterSteps,
          badges: badges,
          seenSpeciesIds: seenSpeciesIds,
          caughtSpeciesIds: caughtSpeciesIds,
          shinyCaughtSpeciesIds: shinyCaughtSpeciesIds,
          unlockedGymIds: unlockedGymIds,
          clearedGymIds: clearedGymIds,
          completedGymStepIds: completedGymStepIds,
          gymTodaySteps: gymTodaySteps,
          customItems: customItems,
          expShareEnabled: expShareEnabled,
          hasEarnedExpeditionMasterBall: hasEarnedExpeditionMasterBall,
          caughtExpeditionLegendaryIds: caughtExpeditionLegendaryIds,
          victoryRoadCleared: victoryRoadCleared,
          championClears: championClears,
          hallOfFameEntries: hallOfFameEntries,
          claimedEventGiftIds: claimedEventGiftIds,
        ),
      };
    }

    this.frontierPcBoxes = List.generate(numPcBoxes, (boxIdx) {
      if (frontierPcBoxes != null && boxIdx < frontierPcBoxes.length) {
        return List<PokemonInstance>.from(
          frontierPcBoxes[boxIdx].take(maxPokemonPerBox),
        );
      }
      return <PokemonInstance>[];
    });
  }

  RegionSave get activeSave =>
      regionSaves.putIfAbsent(activeRegion, () => RegionSave(region: activeRegion));

  RegionSave saveForRegion(GameRegion region) =>
      regionSaves.putIfAbsent(region, () => RegionSave(region: region));

  bool get hasAnySaveData =>
      regionSaves.values.any((s) => s.party.isNotEmpty) ||
      frontierParty.isNotEmpty;

  // ─── ACTIVE REGION DELEGATED ACCESSORS ─────────────────────────────────
  GameVersion? get gameVersion => activeSave.gameVersion;
  set gameVersion(GameVersion? v) => activeSave.gameVersion = v;

  List<PokemonInstance> get party => _battlePartyOverride ?? activeSave.party;
  set party(List<PokemonInstance> v) {
    if (_battlePartyOverride != null) {
      _battlePartyOverride = v;
    } else {
      activeSave.party = v;
    }
  }

  bool get isUsingBattlePartyOverride => _battlePartyOverride != null;

  void setBattlePartyOverride(
    List<PokemonInstance>? overrideParty, {
    bool suppressBadgeBonuses = true,
  }) {
    _battlePartyOverride = overrideParty;
    _suppressBadgeBonuses = overrideParty != null && suppressBadgeBonuses;
    super.notifyListeners();
  }

  void clearBattlePartyOverride() {
    if (_battlePartyOverride == null && !_suppressBadgeBonuses) return;
    _battlePartyOverride = null;
    _suppressBadgeBonuses = false;
    super.notifyListeners();
  }

  List<List<PokemonInstance>> get pcBoxes => activeSave.pcBoxes;
  set pcBoxes(List<List<PokemonInstance>> v) => activeSave.pcBoxes = v;

  int get activePcBoxIndex => activeSave.activePcBoxIndex;
  set activePcBoxIndex(int v) => activeSave.activePcBoxIndex = v;

  int get pokeBalls => activeSave.pokeBalls;
  set pokeBalls(int v) => activeSave.pokeBalls = v;

  int get greatBalls => activeSave.greatBalls;
  set greatBalls(int v) => activeSave.greatBalls = v;

  int get ultraBalls => activeSave.ultraBalls;
  set ultraBalls(int v) => activeSave.ultraBalls = v;

  int get masterBalls => activeSave.masterBalls;
  set masterBalls(int v) => activeSave.masterBalls = v;

  int get potions => activeSave.potions;
  set potions(int v) => activeSave.potions = v;

  int get superPotions => activeSave.superPotions;
  set superPotions(int v) => activeSave.superPotions = v;

  int get hyperPotions => activeSave.hyperPotions;
  set hyperPotions(int v) => activeSave.hyperPotions = v;

  int get revives => activeSave.revives;
  set revives(int v) => activeSave.revives = v;

  int get antidotes => activeSave.antidotes;
  set antidotes(int v) => activeSave.antidotes = v;

  int get paralyzeHeals => activeSave.paralyzeHeals;
  set paralyzeHeals(int v) => activeSave.paralyzeHeals = v;

  int get awakenings => activeSave.awakenings;
  set awakenings(int v) => activeSave.awakenings = v;

  int get burnHeals => activeSave.burnHeals;
  set burnHeals(int v) => activeSave.burnHeals = v;

  int get iceHeals => activeSave.iceHeals;
  set iceHeals(int v) => activeSave.iceHeals = v;

  int get fullHeals => activeSave.fullHeals;
  set fullHeals(int v) => activeSave.fullHeals = v;

  int get fullRestores => activeSave.fullRestores;
  set fullRestores(int v) => activeSave.fullRestores = v;

  int get money => activeSave.money;
  set money(int v) => activeSave.money = v;

  int get encounterSteps => activeSave.encounterSteps;
  set encounterSteps(int v) => activeSave.encounterSteps = v;

  int get badges => activeSave.badges;
  set badges(int v) => activeSave.badges = v;

  Set<int> get seenSpeciesIds => activeSave.seenSpeciesIds;
  set seenSpeciesIds(Set<int> v) => activeSave.seenSpeciesIds = v;

  Set<int> get caughtSpeciesIds => activeSave.caughtSpeciesIds;
  set caughtSpeciesIds(Set<int> v) => activeSave.caughtSpeciesIds = v;

  Set<int> get shinyCaughtSpeciesIds => activeSave.shinyCaughtSpeciesIds;
  set shinyCaughtSpeciesIds(Set<int> v) => activeSave.shinyCaughtSpeciesIds = v;

  Set<int> get unlockedGymIds => activeSave.unlockedGymIds;
  set unlockedGymIds(Set<int> v) => activeSave.unlockedGymIds = v;

  Set<int> get clearedGymIds => activeSave.clearedGymIds;
  set clearedGymIds(Set<int> v) => activeSave.clearedGymIds = v;

  Set<int> get completedGymStepIds => activeSave.completedGymStepIds;
  set completedGymStepIds(Set<int> v) => activeSave.completedGymStepIds = v;

  Map<int, int> get gymTodaySteps => activeSave.gymTodaySteps;
  set gymTodaySteps(Map<int, int> v) => activeSave.gymTodaySteps = v;

  Map<String, int> get customItems => activeSave.customItems;
  set customItems(Map<String, int> v) => activeSave.customItems = v;

  bool get expShareEnabled => activeSave.expShareEnabled;
  set expShareEnabled(bool v) => activeSave.expShareEnabled = v;

  bool get hasEarnedExpeditionMasterBall =>
      activeSave.hasEarnedExpeditionMasterBall;
  set hasEarnedExpeditionMasterBall(bool v) =>
      activeSave.hasEarnedExpeditionMasterBall = v;

  Set<int> get caughtExpeditionLegendaryIds =>
      activeSave.caughtExpeditionLegendaryIds;
  set caughtExpeditionLegendaryIds(Set<int> v) =>
      activeSave.caughtExpeditionLegendaryIds = v;

  bool get victoryRoadCleared => activeSave.victoryRoadCleared;
  set victoryRoadCleared(bool v) => activeSave.victoryRoadCleared = v;

  int get championClears => activeSave.championClears;
  set championClears(int v) => activeSave.championClears = v;

  List<Map<String, dynamic>> get hallOfFameEntries =>
      activeSave.hallOfFameEntries;
  set hallOfFameEntries(List<Map<String, dynamic>> v) =>
      activeSave.hallOfFameEntries = v;

  Set<String> get claimedEventGiftIds => activeSave.claimedEventGiftIds;
  set claimedEventGiftIds(Set<String> v) => activeSave.claimedEventGiftIds = v;

  List<MysteryEgg> get mysteryEggs => activeSave.mysteryEggs;
  MysteryEgg? get incubatingEgg => activeSave.incubatingEgg;
  String? get equippedLabArmorId => activeSave.equippedLabArmorId;
  int get labHatchMultiplier => equippedLabArmorId != null ? 2 : 1;

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

  bool get hasConsciousPokemon => party.any((p) => !p.isFainted);

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

  void setGameVersion(GameVersion version) {
    if (gameVersion == version) return;
    gameVersion = version;
    notifyListeners();
  }

  // ─── POKÉDEX (REGIONAL + NATIONAL) ────────────────────────────────────
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

  Set<int> get nationalSeenSpeciesIds {
    final out = <int>{};
    for (final save in regionSaves.values) {
      out.addAll(save.seenSpeciesIds);
      out.addAll(save.caughtSpeciesIds);
      for (final m in save.party) {
        out.add(m.species.id);
      }
      for (final b in save.pcBoxes) {
        for (final m in b) {
          out.add(m.species.id);
        }
      }
    }
    for (final m in frontierParty) {
      out.add(m.species.id);
    }
    for (final b in frontierPcBoxes) {
      for (final m in b) {
        out.add(m.species.id);
      }
    }
    return out;
  }

  Set<int> get nationalCaughtSpeciesIds {
    final out = <int>{};
    for (final save in regionSaves.values) {
      out.addAll(save.caughtSpeciesIds);
      for (final m in save.party) {
        out.add(m.species.id);
      }
      for (final b in save.pcBoxes) {
        for (final m in b) {
          out.add(m.species.id);
        }
      }
    }
    for (final m in frontierParty) {
      out.add(m.species.id);
    }
    for (final b in frontierPcBoxes) {
      for (final m in b) {
        out.add(m.species.id);
      }
    }
    return out;
  }

  Set<int> get nationalShinyCaughtSpeciesIds {
    final out = <int>{};
    for (final save in regionSaves.values) {
      out.addAll(save.shinyCaughtSpeciesIds);
      for (final m in save.party) {
        if (m.isShiny) out.add(m.species.id);
      }
      for (final b in save.pcBoxes) {
        for (final m in b) {
          if (m.isShiny) out.add(m.species.id);
        }
      }
    }
    for (final m in frontierParty) {
      if (m.isShiny) out.add(m.species.id);
    }
    for (final b in frontierPcBoxes) {
      for (final m in b) {
        if (m.isShiny) out.add(m.species.id);
      }
    }
    return out;
  }

  int get nationalCaughtCount => nationalCaughtSpeciesIds.length;
  int get nationalSeenCount => nationalSeenSpeciesIds.length;

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

  // ─── PARTY & PC STORAGE ────────────────────────────────────────────────
  int? addPokemon(PokemonInstance mon) {
    mon.resetBattleStateAndHeal();
    if (mon.originalTrainerName == null ||
        mon.originalTrainerName!.trim().isEmpty) {
      mon.originalTrainerName = name;
      mon.originalTrainerId = accountId;
    }
    if (mon.originRegion.trim().isEmpty) {
      mon.originRegion = activeRegion.storageKey;
    }
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
    final boxIdx = activeSave.findAvailablePcBox();
    if (boxIdx != null) {
      pcBoxes[boxIdx].add(mon);
      activePcBoxIndex = boxIdx;
      notifyListeners();
      return boxIdx + 1;
    }
    notifyListeners();
    return -1;
  }

  bool setPokemonNickname(PokemonInstance mon, String rawName) {
    final bool updated = mon.setPermanentNickname(rawName);
    if (updated) {
      notifyListeners();
    }
    return updated;
  }

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
    final boxIdx = activeSave.findAvailablePcBox(targetBoxIndex);
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
        masterBalls +
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
      fullRestores +
      (customItems['ether'] ?? 0) +
      (customItems['max_ether'] ?? 0) +
      (customItems['elixir'] ?? 0) +
      (customItems['max_elixir'] ?? 0);

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

  // ─── GYMS, BADGES & REGION TRAVEL ──────────────────────────────────────
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
    final bool firstClear = !clearedGymIds.contains(gymId);
    clearedGymIds.add(gymId);
    badges = clearedGymIds.length;
    if (gymId < 8) {
      unlockedGymIds.add(gymId + 1);
    }
    if (gymId == 8 && firstClear) {
      expShareEnabled = true;
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
    if (_suppressBadgeBonuses) return 0.0;
    final requiredBadges = getBadgesRequiredForLevel(pokemonLevel);
    final currentBadges = clearedGymIds.length;
    if (currentBadges >= requiredBadges) return 0.0;
    final missingBadges = (requiredBadges - currentBadges).clamp(1, 8);
    return 0.35 + (missingBadges - 1) * ((0.60 - 0.35) / 7.0);
  }

  bool get hasEarthBadge => clearedGymIds.contains(8);
  bool get hasExpShare => hasEarthBadge;
  bool get isExpShareActive => hasExpShare && expShareEnabled;
  bool get isVictoryRoadUnlocked => clearedGymIds.length >= 8;
  bool get isChampion => championClears > 0;
  bool isRegionUnlocked(GameRegion region) => unlockedRegions.contains(region);

  void markVictoryRoadCleared() {
    if (victoryRoadCleared) return;
    victoryRoadCleared = true;
    notifyListeners();
  }

  void recordChampionVictory() {
    victoryRoadCleared = true;
    championClears += 1;
    hallOfFameEntries.add({
      'runNumber': championClears,
      'region': activeRegion.storageKey,
      'inductedAt': DateTime.now().toUtc().toIso8601String(),
      'party': party
          .map((mon) => {
                'speciesId': mon.species.id,
                'nickname': mon.nickname,
                'level': mon.level,
                'isShiny': mon.isShiny,
                'originalTrainerName': mon.originalTrainerName ?? name,
              })
          .toList(),
    });
    final next = activeRegion.nextRegion;
    if (next != null) {
      unlockedRegions.add(next);
    }
    notifyListeners();
  }

  bool travelToRegion(GameRegion region) {
    if (!unlockedRegions.contains(region)) return false;
    if (activeRegion == region) return true;
    activeRegion = region;
    regionSaves.putIfAbsent(region, () => RegionSave(region: region));
    notifyListeners();
    return true;
  }

  void startNewRegionAdventure({
    required GameRegion region,
    required GameVersion version,
    required PokemonInstance starter,
  }) {
    unlockedRegions.add(region);
    final save = saveForRegion(region);
    save.gameVersion = version;
    if (save.party.isEmpty) {
      starter.originRegion = region.storageKey;
      starter.originalTrainerName = name;
      starter.originalTrainerId = accountId;
      save.party.add(starter);
      save.syncDexFromStorage();
    }
    activeRegion = region;
    notifyListeners();
  }

  double get atkBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(1) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get spaBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(2) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get speBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(3) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get spdBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(4) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get defBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(5) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get hpBadgeMultiplier => _suppressBadgeBonuses
      ? 1.0
      : (clearedGymIds.contains(6) ? 1.10 : 1.0) * (hasEarthBadge ? 1.05 : 1.0);
  double get critBadgeBonus =>
      _suppressBadgeBonuses ? 0.0 : (clearedGymIds.contains(7) ? 0.10 : 0.0);

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

  // ─── STEPS, FRIENDSHIP & EGG INCUBATION ───────────────────────────────
  int get todaySteps {
    _syncDailyRollover();
    return dailySteps;
  }

  double get encounterChance =>
      (encounterSteps / maxEncounterSteps).clamp(0.0, 1.0);

  void _syncDailyRollover() {
    final today = todayDateKey();
    if (lastStepDate != today) {
      dailySteps = 0;
      for (final save in regionSaves.values) {
        save.gymTodaySteps.clear();
      }
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

  void _advancePartyFriendshipFromSteps(int delta) {
    if (delta <= 0 || party.isEmpty) return;
    activeSave.friendshipStepCarry += delta;
    final int gained = activeSave.friendshipStepCarry ~/ 50;
    if (gained > 0) {
      activeSave.friendshipStepCarry %= 50;
      for (final mon in party) {
        mon.addFriendship(gained);
      }
    }
  }

  bool recordStepsAndCheckEncounter(
    int delta, {
    bool allowEncounter = true,
  }) {
    if (delta <= 0) return false;
    _syncDailyRollover();
    _accumulateGymSteps(delta);
    dailySteps += delta;
    totalSteps += delta;
    _advancePartyFriendshipFromSteps(delta);
    if (activeSave.incubatingEgg != null) {
      activeSave.incubatingEgg!.advance(delta * labHatchMultiplier);
    }
    bool triggered = false;
    if (allowEncounter) {
      for (int i = 0; i < delta; i++) {
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

  void recordBattleCompleted({
    required bool isTrainerBattle,
    required bool won,
  }) {
    final int eggGain = (isTrainerBattle ? 450 : 250) * labHatchMultiplier;
    bool changed = false;
    if (activeSave.incubatingEgg != null &&
        activeSave.incubatingEgg!.advance(eggGain)) {
      changed = true;
    }
    final int baseGain = won ? (isTrainerBattle ? 6 : 4) : 2;
    for (final mon in party) {
      final int monGain =
          mon.isFainted ? (baseGain ~/ 2).clamp(1, baseGain) : baseGain;
      mon.addFriendship(monGain);
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void addMysteryEgg(MysteryEgg egg) {
    activeSave.mysteryEggs.add(egg);
    if (activeSave.incubatingEgg == null && activeSave.mysteryEggs.isNotEmpty) {
      activeSave.incubatingEgg = activeSave.mysteryEggs.removeAt(0);
    }
    notifyListeners();
  }

  bool startIncubatingEgg(int eggIndex) {
    if (activeSave.incubatingEgg != null) return false;
    if (eggIndex < 0 || eggIndex >= activeSave.mysteryEggs.length) {
      return false;
    }
    activeSave.incubatingEgg = activeSave.mysteryEggs.removeAt(eggIndex);
    notifyListeners();
    return true;
  }

  bool equipLabArmor(String? armorId) {
    if (armorId == null) {
      if (activeSave.equippedLabArmorId == null) return false;
      activeSave.equippedLabArmorId = null;
      notifyListeners();
      return true;
    }
    if (armorId != 'flame_armor' && armorId != 'magma_armor') return false;
    if (getItemCount(armorId) <= 0) return false;
    activeSave.equippedLabArmorId = armorId;
    notifyListeners();
    return true;
  }

  ({PokemonInstance pokemon, int? pcBoxNumber})? hatchIncubatingEgg() {
    final egg = activeSave.incubatingEgg;
    if (egg == null || !egg.isReadyToHatch) return null;
    if (isStorageFull) return null;
    final spec = PokedexDatabase.species[egg.speciesId];
    if (spec == null) return null;

    final hatchedMon = PokedexDatabase.createPokemon(
      egg.speciesId,
      level: 5,
      isShiny: PokedexDatabase.rollShiny(spec),
      hiddenAbilityChance: 0.05,
      guaranteedPerfectIvs: 2,
      friendship: 120,
      originRegion: egg.originRegion,
    );
    activeSave.incubatingEgg = null;
    final boxNum = addPokemon(hatchedMon);
    return (pokemon: hatchedMon, pcBoxNumber: boxNum);
  }

  // ─── BATTLE FRONTIER ORIGIN-LOCKED TRANSFERS ──────────────────────────
  bool get isBattleFrontierUnlocked =>
      regionSaves[GameRegion.kanto]?.isChampion ?? false;

  bool canTransferRegionToFrontier(GameRegion region) =>
      isBattleFrontierUnlocked && unlockedRegions.contains(region);

  int? _findAvailableFrontierPcBox([int? preferredIndex]) {
    if (preferredIndex != null) {
      if (preferredIndex < 0 || preferredIndex >= numPcBoxes) return null;
      return frontierPcBoxes[preferredIndex].length < maxPokemonPerBox
          ? preferredIndex
          : null;
    }
    for (int i = 0; i < numPcBoxes; i++) {
      if (frontierPcBoxes[i].length < maxPokemonPerBox) return i;
    }
    return null;
  }

  bool transferPcPokemonToFrontier(
    GameRegion fromRegion,
    int boxIndex,
    int slotIndex,
  ) {
    if (!canTransferRegionToFrontier(fromRegion)) return false;
    final srcSave = regionSaves[fromRegion];
    if (srcSave == null || boxIndex < 0 || boxIndex >= numPcBoxes) {
      return false;
    }
    final srcBox = srcSave.pcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= srcBox.length) return false;
    final destBoxIdx = _findAvailableFrontierPcBox();
    if (destBoxIdx == null) return false;

    final mon = srcBox.removeAt(slotIndex);
    mon.resetBattleStateAndHeal();
    if (mon.originRegion.trim().isEmpty) {
      mon.originRegion = fromRegion.storageKey;
    }
    frontierPcBoxes[destBoxIdx].add(mon);
    notifyListeners();
    return true;
  }

  bool returnFrontierPokemonToOrigin(int frontierBoxIndex, int frontierSlotIndex) {
    if (frontierBoxIndex < 0 || frontierBoxIndex >= numPcBoxes) return false;
    final srcBox = frontierPcBoxes[frontierBoxIndex];
    if (frontierSlotIndex < 0 || frontierSlotIndex >= srcBox.length) {
      return false;
    }
    final mon = srcBox[frontierSlotIndex];
    final originRegion = GameRegionExtension.fromStorageKey(mon.originRegion);
    final destSave = saveForRegion(originRegion);
    final destBoxIdx = destSave.findAvailablePcBox();
    if (destBoxIdx == null) return false;

    srcBox.removeAt(frontierSlotIndex);
    mon.resetBattleStateAndHeal();
    destSave.pcBoxes[destBoxIdx].add(mon);
    destSave.syncDexFromStorage();
    notifyListeners();
    return true;
  }

  int get totalFrontierPcPokemon =>
      frontierPcBoxes.fold(0, (sum, box) => sum + box.length);

  bool get hasConsciousFrontierPokemon =>
      frontierParty.any((p) => !p.isFainted);

  void healAllFrontierParty() {
    for (final mon in frontierParty) {
      mon.resetBattleStateAndHeal();
    }
    notifyListeners();
  }

  bool withdrawFrontierPokemon(int boxIndex, int slotIndex) {
    if (frontierParty.length >= 6 || boxIndex < 0 || boxIndex >= numPcBoxes) {
      return false;
    }
    final box = frontierPcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= box.length) return false;
    final mon = box.removeAt(slotIndex);
    mon.resetBattleStateAndHeal();
    frontierParty.add(mon);
    notifyListeners();
    return true;
  }

  bool depositFrontierPokemon(int partyIndex, {int? targetBoxIndex}) {
    if (partyIndex < 0 || partyIndex >= frontierParty.length) return false;
    final destIdx = _findAvailableFrontierPcBox(targetBoxIndex);
    if (destIdx == null) return false;
    final mon = frontierParty.removeAt(partyIndex);
    mon.resetBattleStateAndHeal();
    frontierPcBoxes[destIdx].add(mon);
    notifyListeners();
    return true;
  }

  bool swapFrontierPartyAndPc(int partyIndex, int boxIndex, int slotIndex) {
    if (partyIndex < 0 ||
        partyIndex >= frontierParty.length ||
        boxIndex < 0 ||
        boxIndex >= numPcBoxes) {
      return false;
    }
    final box = frontierPcBoxes[boxIndex];
    if (slotIndex < 0 || slotIndex >= box.length) return false;
    final pMon = frontierParty[partyIndex];
    final pcMon = box[slotIndex];
    pMon.resetBattleStateAndHeal();
    pcMon.resetBattleStateAndHeal();
    frontierParty[partyIndex] = pcMon;
    box[slotIndex] = pMon;
    notifyListeners();
    return true;
  }

  void setFrontierLead(int partyIndex) {
    if (partyIndex <= 0 || partyIndex >= frontierParty.length) return;
    final mon = frontierParty.removeAt(partyIndex);
    frontierParty.insert(0, mon);
    notifyListeners();
  }

  bool returnFrontierPartyPokemonToOrigin(int partyIndex) {
    if (partyIndex < 0 || partyIndex >= frontierParty.length) return false;
    final mon = frontierParty[partyIndex];
    final originRegion = GameRegionExtension.fromStorageKey(mon.originRegion);
    final destSave = saveForRegion(originRegion);
    final destBoxIdx = destSave.findAvailablePcBox();
    if (destBoxIdx == null) return false;
    frontierParty.removeAt(partyIndex);
    mon.resetBattleStateAndHeal();
    destSave.pcBoxes[destBoxIdx].add(mon);
    destSave.syncDexFromStorage();
    notifyListeners();
    return true;
  }

  void addBattlePoints(int amount) {
    if (amount <= 0) return;
    frontierBattlePoints += amount;
    notifyListeners();
  }

  bool spendBattlePoints(int amount) {
    if (amount <= 0) return true;
    if (frontierBattlePoints < amount) return false;
    frontierBattlePoints -= amount;
    notifyListeners();
    return true;
  }

  int getFrontierItemCount(String itemId) => frontierCustomItems[itemId] ?? 0;

  void adjustFrontierItemCount(String itemId, int delta) {
    final current = frontierCustomItems[itemId] ?? 0;
    final updated = (current + delta).clamp(0, 99);
    if (updated <= 0) {
      frontierCustomItems.remove(itemId);
    } else {
      frontierCustomItems[itemId] = updated;
    }
    notifyListeners();
  }

  bool equipFrontierItemOnPokemon(PokemonInstance mon, String? itemId) {
    if (itemId == null) {
      final prev = mon.unequipHeldItem();
      if (prev != null) {
        frontierCustomItems[prev] =
            ((frontierCustomItems[prev] ?? 0) + 1).clamp(0, 99);
        notifyListeners();
        return true;
      }
      return false;
    }
    final available = frontierCustomItems[itemId] ?? 0;
    if (available <= 0) return false;
    frontierCustomItems[itemId] = available - 1;
    if (frontierCustomItems[itemId]! <= 0) {
      frontierCustomItems.remove(itemId);
    }
    final prev = mon.unequipHeldItem();
    mon.equipHeldItem(itemId);
    if (prev != null) {
      frontierCustomItems[prev] =
          ((frontierCustomItems[prev] ?? 0) + 1).clamp(0, 99);
    }
    notifyListeners();
    return true;
  }

  void recordFrontierTowerStreak({required bool isDoubles, required int streak}) {
    if (isDoubles) {
      if (streak > frontierTowerBestDoubles) {
        frontierTowerBestDoubles = streak;
        notifyListeners();
      }
    } else {
      if (streak > frontierTowerBestSingles) {
        frontierTowerBestSingles = streak;
        notifyListeners();
      }
    }
  }

  void recordFrontierFactoryStreak({required bool isDoubles, required int streak}) {
    if (isDoubles) {
      if (streak > frontierFactoryBestDoubles) {
        frontierFactoryBestDoubles = streak;
        notifyListeners();
      }
    } else {
      if (streak > frontierFactoryBestSingles) {
        frontierFactoryBestSingles = streak;
        notifyListeners();
      }
    }
  }

  bool toggleExpShare([bool? value]) {
    if (!hasExpShare) {
      if (expShareEnabled) {
        expShareEnabled = false;
        notifyListeners();
      }
      return false;
    }
    expShareEnabled = value ?? !expShareEnabled;
    notifyListeners();
    return true;
  }

  void resetEncounterSteps() {
    if (encounterSteps != 0) {
      encounterSteps = 0;
      notifyListeners();
    }
  }

  bool get isExpeditionsUnlocked => clearedGymIds.length >= 8;

  bool hasCaughtExpeditionSpecies(int speciesId) =>
      caughtExpeditionLegendaryIds.contains(speciesId);

  void markExpeditionSpeciesCaught(int speciesId) {
    caughtExpeditionLegendaryIds.add(speciesId);
    notifyListeners();
  }

  void claimExpeditionMasterBall() {
    if (hasEarnedExpeditionMasterBall) return;
    hasEarnedExpeditionMasterBall = true;
    masterBalls = (masterBalls + 1).clamp(0, 99);
    notifyListeners();
  }

  bool hasRedeemedGiftCode(String code) =>
      redeemedGiftCodes.contains(code.toUpperCase());

  void markGiftCodeRedeemed(String code) {
    redeemedGiftCodes.add(code.toUpperCase());
    notifyListeners();
  }

  bool hasClaimedEventGift(String eventId) =>
      claimedEventGiftIds.contains(eventId);

  void markEventGiftClaimed(String eventId) {
    claimedEventGiftIds.add(eventId);
    notifyListeners();
  }

  bool hasTm(String tmId) => getItemCount(tmId) > 0;
  bool hasAdventureMap(String mapId) => getItemCount(mapId) > 0;

  int getItemCount(String itemId) {
    switch (itemId) {
      case 'poke_ball':
        return pokeBalls;
      case 'great_ball':
        return greatBalls;
      case 'ultra_ball':
        return ultraBalls;
      case 'master_ball':
        return masterBalls;
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
      case 'master_ball':
        masterBalls = (masterBalls + delta).clamp(0, 99);
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
        final itemDef = ItemDatabase.byId(itemId);
        final bool isUniqueUnlock = itemDef != null &&
            (itemDef.isTm || itemDef.isAdventureMap || itemDef.isLabGear);
        final current = customItems[itemId] ?? 0;
        if (isUniqueUnlock) {
          if (current >= 1 && delta > 0) return;
          final updated = (current + delta).clamp(0, 1);
          if (updated <= 0) {
            customItems.remove(itemId);
          } else {
            customItems[itemId] = 1;
          }
          break;
        }
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

  int get friendCount => rivals.where((r) => r.isFriend).length;
  int get totalPvpMatches => rivals.fold(0, (sum, r) => sum + r.matches);
  int get totalPvpWins => rivals.fold(0, (sum, r) => sum + r.wins);

  void recordPvpMatch({
    required String peerId,
    required String peerName,
    required String peerTitle,
    required String peerSpriteId,
    required bool playerWon,
  }) {
    final cleanId = peerId.trim();
    final cleanName = peerName.trim().isEmpty ? 'Trainer' : peerName.trim();
    final cleanTitle =
        peerTitle.trim().isEmpty ? 'Trainer' : peerTitle.trim();
    final cleanSprite =
        peerSpriteId.trim().isEmpty ? 'male_red' : peerSpriteId.trim();

    int existingIdx =
        rivals.indexWhere((r) => cleanId.isNotEmpty && r.id == cleanId);
    if (existingIdx < 0) {
      existingIdx = rivals.indexWhere(
          (r) => r.name.toLowerCase() == cleanName.toLowerCase());
    }

    final now = DateTime.now();
    if (existingIdx >= 0) {
      final existing = rivals[existingIdx];
      existing.name = cleanName;
      existing.title = cleanTitle;
      existing.spriteId = cleanSprite;
      existing.matches += 1;
      if (playerWon) {
        existing.wins += 1;
      }
      existing.lastOutcome = playerWon ? 'win' : 'loss';
      existing.lastBattledAt = now;
      if (existingIdx > 0) {
        rivals.removeAt(existingIdx);
        rivals.insert(0, existing);
      }
    } else {
      rivals.insert(
        0,
        RivalRecord(
          id: cleanId.isNotEmpty ? cleanId : 'rival_${cleanName.toLowerCase()}',
          name: cleanName,
          title: cleanTitle,
          spriteId: cleanSprite,
          matches: 1,
          wins: playerWon ? 1 : 0,
          isFriend: false,
          lastOutcome: playerWon ? 'win' : 'loss',
          lastBattledAt: now,
        ),
      );
    }
    notifyListeners();
  }

  bool toggleRivalFriend(String rivalId) {
    final idx = rivals.indexWhere((r) => r.id == rivalId);
    if (idx < 0) return false;
    rivals[idx].isFriend = !rivals[idx].isFriend;
    notifyListeners();
    return rivals[idx].isFriend;
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
      'hp10MigrationApplied': hp10MigrationApplied,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'name': name,
      'accountId': accountId,
      'avatarId': avatar.id,
      'totalSteps': totalSteps,
      'dailySteps': dailySteps,
      'lastStepDate': lastStepDate,
      'redeemedGiftCodes': redeemedGiftCodes.toList()..sort(),
      'rivals': rivals.map((r) => r.toJson()).toList(),
      'activeRegion': activeRegion.storageKey,
      'unlockedRegions': unlockedRegions.map((r) => r.storageKey).toList(),
      'regions': {
        for (final entry in regionSaves.entries)
          entry.key.storageKey: entry.value.toJson(),
      },
      'frontier': {
        'battlePoints': frontierBattlePoints,
        'towerBestSingles': frontierTowerBestSingles,
        'towerBestDoubles': frontierTowerBestDoubles,
        'factoryBestSingles': frontierFactoryBestSingles,
        'factoryBestDoubles': frontierFactoryBestDoubles,
        'customItems': frontierCustomItems,
        'party': frontierParty.map((m) => m.toJson()).toList(),
        'pcBoxes': frontierPcBoxes
            .map((box) => box.map((m) => m.toJson()).toList())
            .toList(),
      },
    };
  }

  void applyFromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] as String?)?.trim() ?? 'Red';
    name = rawName.isEmpty ? 'Red' : rawName;
    final rawAccId = (json['accountId'] as String?)?.trim();
    accountId = (rawAccId != null && rawAccId.isNotEmpty) ? rawAccId : null;
    final avatarId = json['avatarId'] as String?;
    avatar = TrainerAvatar.presets.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => TrainerAvatar.presets.first,
    );
    totalSteps = max(0, (json['totalSteps'] as num?)?.toInt() ?? 0);
    dailySteps = max(0, (json['dailySteps'] as num?)?.toInt() ?? 0);
    lastStepDate = (json['lastStepDate'] as String?) ?? todayDateKey();

    redeemedGiftCodes =
        (json['redeemedGiftCodes'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map((s) => s.toUpperCase())
            .toSet();

    final rawRivals = json['rivals'] as List<dynamic>? ?? const [];
    final loadedRivals = <RivalRecord>[];
    for (final item in rawRivals) {
      if (item is Map) {
        loadedRivals.add(RivalRecord.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    loadedRivals.sort((a, b) => b.lastBattledAt.compareTo(a.lastBattledAt));
    rivals = loadedRivals;

    final rawRegions = json['regions'];
    if (rawRegions is Map) {
      regionSaves = {};
      rawRegions.forEach((key, val) {
        if (val is Map) {
          final reg = GameRegionExtension.fromStorageKey(key.toString());
          regionSaves[reg] = RegionSave.fromJson(
            reg,
            Map<String, dynamic>.from(val),
            defaultOtName: name,
            defaultOtId: accountId,
          );
        }
      });
      if (regionSaves.isEmpty) {
        regionSaves[GameRegion.kanto] = RegionSave(region: GameRegion.kanto);
      }
      activeRegion =
          GameRegionExtension.fromStorageKey(json['activeRegion'] as String?);
      if (!regionSaves.containsKey(activeRegion)) {
        regionSaves[activeRegion] = RegionSave(region: activeRegion);
      }
      unlockedRegions = {GameRegion.kanto};
      for (final r in (json['unlockedRegions'] as List<dynamic>? ?? const [])) {
        if (r is String) {
          unlockedRegions.add(GameRegionExtension.fromStorageKey(r));
        }
      }
      unlockedRegions.addAll(regionSaves.keys);
      if (regionSaves[GameRegion.kanto]?.isChampion == true) {
        unlockedRegions.add(GameRegion.johto);
      }
    } else {
      // Schema v1 -> Schema v2 seamless Kanto migration
      final kantoSave = RegionSave.fromJson(
        GameRegion.kanto,
        json,
        defaultOtName: name,
        defaultOtId: accountId,
      );
      regionSaves = {GameRegion.kanto: kantoSave};
      activeRegion = GameRegion.kanto;
      unlockedRegions = {
        GameRegion.kanto,
        if (kantoSave.isChampion) GameRegion.johto,
      };
    }

    final rawFrontier = json['frontier'];
    if (rawFrontier is Map) {
      final fMap = Map<String, dynamic>.from(rawFrontier);
      frontierBattlePoints =
          max(0, (fMap['battlePoints'] as num?)?.toInt() ?? 0);
      frontierTowerBestSingles =
          max(0, (fMap['towerBestSingles'] as num?)?.toInt() ?? 0);
      frontierTowerBestDoubles =
          max(0, (fMap['towerBestDoubles'] as num?)?.toInt() ?? 0);
      frontierFactoryBestSingles =
          max(0, (fMap['factoryBestSingles'] as num?)?.toInt() ?? 0);
      frontierFactoryBestDoubles =
          max(0, (fMap['factoryBestDoubles'] as num?)?.toInt() ?? 0);
      frontierCustomItems = {};
      final rawFItems = fMap['customItems'] as Map<String, dynamic>? ?? {};
      rawFItems.forEach((k, v) {
        if (v is num && v.toInt() > 0) {
          frontierCustomItems[k] = v.toInt().clamp(0, 99);
        }
      });
      frontierParty = [];
      for (final item in (fMap['party'] as List<dynamic>? ?? const [])) {
        if (item is Map) {
          frontierParty
              .add(PokemonInstance.fromJson(Map<String, dynamic>.from(item)));
        }
        if (frontierParty.length >= 6) break;
      }
      final rawFBoxes = fMap['pcBoxes'] as List<dynamic>? ?? const [];
      frontierPcBoxes = List.generate(numPcBoxes, (boxIdx) {
        if (boxIdx >= rawFBoxes.length || rawFBoxes[boxIdx] is! List) {
          return <PokemonInstance>[];
        }
        final box = <PokemonInstance>[];
        for (final item in (rawFBoxes[boxIdx] as List<dynamic>)) {
          if (item is Map) {
            box.add(PokemonInstance.fromJson(Map<String, dynamic>.from(item)));
          }
          if (box.length >= maxPokemonPerBox) break;
        }
        return box;
      });
    } else {
      frontierBattlePoints = 0;
      frontierTowerBestSingles = 0;
      frontierTowerBestDoubles = 0;
      frontierFactoryBestSingles = 0;
      frontierFactoryBestDoubles = 0;
      frontierCustomItems = {};
      frontierParty = [];
      frontierPcBoxes = List.generate(numPcBoxes, (_) => <PokemonInstance>[]);
    }

    hp10MigrationApplied = json['hp10MigrationApplied'] == true;
    if (!hp10MigrationApplied) {
      for (final save in regionSaves.values) {
        for (final mon in save.party) {
          if (mon.currentHp == 10 && mon.maxHp > 10) {
            mon.currentHp = mon.maxHp;
          }
        }
        for (final box in save.pcBoxes) {
          for (final mon in box) {
            if (mon.currentHp == 10 && mon.maxHp > 10) {
              mon.currentHp = mon.maxHp;
            }
          }
        }
      }
      for (final mon in frontierParty) {
        if (mon.currentHp == 10 && mon.maxHp > 10) {
          mon.currentHp = mon.maxHp;
        }
      }
      for (final box in frontierPcBoxes) {
        for (final mon in box) {
          if (mon.currentHp == 10 && mon.maxHp > 10) {
            mon.currentHp = mon.maxHp;
          }
        }
      }
      hp10MigrationApplied = true;
    }

    _syncDailyRollover();
  }

  Future<void> saveProgress() async {
    if (!hasAnySaveData) return;
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
    if (!_suppressAutoSave && hasAnySaveData) {
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
          final decodedMap = Map<String, dynamic>.from(decoded);
          final bool hadHp10Migration =
              decodedMap['hp10MigrationApplied'] == true;
          final trainer = Trainer(name: 'Red');
          trainer.applyFromJson(decodedMap);
          if (trainer.hasAnySaveData) {
            if (!hadHp10Migration) {
              await trainer.saveProgress();
            }
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
      await prefs.remove('pb_step_last_hw_steps');
      await prefs.remove('pb_step_last_hw_date');
      await prefs.remove('pb_step_pending_hc_credit');
    } catch (_) {}
    name = 'Red';
    accountId = null;
    avatar = TrainerAvatar.presets.first;
    totalSteps = 0;
    dailySteps = 0;
    lastStepDate = todayDateKey();
    redeemedGiftCodes = {};
    rivals = [];
    activeRegion = GameRegion.kanto;
    unlockedRegions = {GameRegion.kanto};
    regionSaves = {GameRegion.kanto: RegionSave(region: GameRegion.kanto)};
    frontierParty = [];
    frontierPcBoxes = List.generate(numPcBoxes, (_) => <PokemonInstance>[]);
    frontierBattlePoints = 0;
    frontierCustomItems = {};
    frontierTowerBestSingles = 0;
    frontierTowerBestDoubles = 0;
    frontierFactoryBestSingles = 0;
    frontierFactoryBestDoubles = 0;
    hp10MigrationApplied = true;
    _suppressAutoSave = false;
    super.notifyListeners();
  }
}
