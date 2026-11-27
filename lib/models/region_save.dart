import 'dart:math';
import 'game_region.dart';
import 'game_version.dart';
import 'item.dart';
import 'mystery_egg.dart';
import 'pokemon_instance.dart';

class RegionSave {
  static const int numPcBoxes = 16;
  static const int maxPokemonPerBox = 20;
  static const int maxEncounterSteps = 400;

  final GameRegion region;
  GameVersion? gameVersion;
  List<PokemonInstance> party;
  late List<List<PokemonInstance>> pcBoxes;
  int activePcBoxIndex;
  int pokeBalls;
  int greatBalls;
  int ultraBalls;
  int masterBalls;
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
  bool hasEarnedExpeditionMasterBall;
  Set<int> caughtExpeditionLegendaryIds;
  bool victoryRoadCleared;
  int championClears;
  List<Map<String, dynamic>> hallOfFameEntries;
  Set<String> claimedEventGiftIds;

  // Egg Incubator state (per-region Lab)
  List<MysteryEgg> mysteryEggs;
  MysteryEgg? incubatingEgg;
  String? equippedLabArmorId;
  int friendshipStepCarry;

  RegionSave({
    required this.region,
    this.gameVersion,
    List<PokemonInstance>? party,
    List<List<PokemonInstance>>? pcBoxes,
    this.activePcBoxIndex = 0,
    this.pokeBalls = 20,
    this.greatBalls = 0,
    this.ultraBalls = 0,
    this.masterBalls = 0,
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
    this.hasEarnedExpeditionMasterBall = false,
    Set<int>? caughtExpeditionLegendaryIds,
    this.victoryRoadCleared = false,
    this.championClears = 0,
    List<Map<String, dynamic>>? hallOfFameEntries,
    Set<String>? claimedEventGiftIds,
    List<MysteryEgg>? mysteryEggs,
    this.incubatingEgg,
    this.equippedLabArmorId,
    this.friendshipStepCarry = 0,
  })  : party = party ?? [],
        seenSpeciesIds = seenSpeciesIds ?? {},
        caughtSpeciesIds = caughtSpeciesIds ?? {},
        shinyCaughtSpeciesIds = shinyCaughtSpeciesIds ?? {},
        unlockedGymIds = unlockedGymIds ?? {1},
        clearedGymIds = clearedGymIds ?? {},
        completedGymStepIds = completedGymStepIds ?? {},
        gymTodaySteps = gymTodaySteps ?? {},
        customItems = customItems ?? {},
        caughtExpeditionLegendaryIds = caughtExpeditionLegendaryIds ?? {},
        hallOfFameEntries = hallOfFameEntries ?? [],
        claimedEventGiftIds = claimedEventGiftIds ?? {},
        mysteryEggs = mysteryEggs ?? [] {
    activePcBoxIndex = activePcBoxIndex.clamp(0, numPcBoxes - 1);
    this.pcBoxes = List.generate(numPcBoxes, (boxIdx) {
      if (pcBoxes != null && boxIdx < pcBoxes.length) {
        return List<PokemonInstance>.from(
          pcBoxes[boxIdx].take(maxPokemonPerBox),
        );
      }
      return <PokemonInstance>[];
    });
    syncDexFromStorage();
  }

  void syncDexFromStorage() {
    for (final mon in party) {
      seenSpeciesIds.add(mon.species.id);
      caughtSpeciesIds.add(mon.species.id);
      if (mon.isShiny) {
        shinyCaughtSpeciesIds.add(mon.species.id);
      }
    }
    for (final box in pcBoxes) {
      for (final mon in box) {
        seenSpeciesIds.add(mon.species.id);
        caughtSpeciesIds.add(mon.species.id);
        if (mon.isShiny) {
          shinyCaughtSpeciesIds.add(mon.species.id);
        }
      }
    }
  }

  bool get isChampion => championClears > 0;
  bool get hasExpShare => clearedGymIds.contains(8);

  int? findAvailablePcBox([int? preferredIndex]) {
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

  Map<String, dynamic> toJson() {
    return {
      'region': region.storageKey,
      'gameVersion': gameVersion?.storageKey,
      'pokeBalls': pokeBalls,
      'greatBalls': greatBalls,
      'ultraBalls': ultraBalls,
      'masterBalls': masterBalls,
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
      'hasEarnedExpeditionMasterBall': hasEarnedExpeditionMasterBall,
      'caughtExpeditionLegendaryIds':
          caughtExpeditionLegendaryIds.toList()..sort(),
      'victoryRoadCleared': victoryRoadCleared,
      'championClears': championClears,
      'hallOfFameEntries': hallOfFameEntries,
      'claimedEventGiftIds': claimedEventGiftIds.toList()..sort(),
      'mysteryEggs': mysteryEggs.map((e) => e.toJson()).toList(),
      if (incubatingEgg != null) 'incubatingEgg': incubatingEgg!.toJson(),
      if (equippedLabArmorId != null) 'equippedLabArmorId': equippedLabArmorId,
      'friendshipStepCarry': friendshipStepCarry,
      'party': party.map((mon) => mon.toJson()).toList(),
      'activePcBoxIndex': activePcBoxIndex,
      'pcBoxes': pcBoxes
          .map((box) => box.map((mon) => mon.toJson()).toList())
          .toList(),
    };
  }

  factory RegionSave.fromJson(
    GameRegion region,
    Map<String, dynamic> json, {
    String defaultOtName = 'Red',
    String? defaultOtId,
  }) {
    final unlocked = (json['unlockedGymIds'] as List<dynamic>? ?? [1])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();
    if (unlocked.isEmpty) unlocked.add(1);

    final cleared = (json['clearedGymIds'] as List<dynamic>? ?? const [])
        .whereType<num>()
        .map((n) => n.toInt())
        .toSet();

    final completedSteps =
        (json['completedGymStepIds'] as List<dynamic>? ?? const [])
            .whereType<num>()
            .map((n) => n.toInt())
            .toSet();

    final gymSteps = <int, int>{};
    final rawGymSteps = json['gymTodaySteps'] as Map<String, dynamic>? ?? {};
    rawGymSteps.forEach((k, v) {
      final gid = int.tryParse(k);
      if (gid != null && v is num) {
        gymSteps[gid] = v.toInt();
      }
    });

    final loadedCustom = <String, int>{};
    final rawCustom = json['customItems'] as Map<String, dynamic>? ?? {};
    rawCustom.forEach((k, v) {
      if (v is num && v.toInt() > 0) {
        final itemDef = ItemDatabase.byId(k);
        final bool isUniqueUnlock = itemDef != null &&
            (itemDef.isTm || itemDef.isAdventureMap || itemDef.isLabGear);
        loadedCustom[k] = isUniqueUnlock ? 1 : v.toInt().clamp(0, 99);
      }
    });

    final hofRaw = json['hallOfFameEntries'] as List<dynamic>? ?? const [];
    final loadedHof = <Map<String, dynamic>>[
      for (final item in hofRaw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    int champClears = max(0, (json['championClears'] as num?)?.toInt() ?? 0);
    if (loadedHof.isNotEmpty && champClears < loadedHof.length) {
      champClears = loadedHof.length;
    }
    bool vrCleared = json['victoryRoadCleared'] == true;
    if (champClears > 0) vrCleared = true;

    final loadedParty = <PokemonInstance>[];
    for (final item in (json['party'] as List<dynamic>? ?? const [])) {
      if (item is Map) {
        final mon = PokemonInstance.fromJson(Map<String, dynamic>.from(item));
        if (mon.originalTrainerName == null ||
            mon.originalTrainerName!.trim().isEmpty) {
          mon.originalTrainerName = defaultOtName;
          mon.originalTrainerId = defaultOtId;
        }
        loadedParty.add(mon);
      }
      if (loadedParty.length >= 6) break;
    }

    final rawBoxes = json['pcBoxes'] as List<dynamic>? ?? const [];
    final loadedBoxes = List.generate(numPcBoxes, (boxIdx) {
      if (boxIdx >= rawBoxes.length || rawBoxes[boxIdx] is! List) {
        return <PokemonInstance>[];
      }
      final rawBox = rawBoxes[boxIdx] as List<dynamic>;
      final box = <PokemonInstance>[];
      for (final item in rawBox) {
        if (item is Map) {
          final mon = PokemonInstance.fromJson(Map<String, dynamic>.from(item));
          if (mon.originalTrainerName == null ||
              mon.originalTrainerName!.trim().isEmpty) {
            mon.originalTrainerName = defaultOtName;
            mon.originalTrainerId = defaultOtId;
          }
          box.add(mon);
        }
        if (box.length >= maxPokemonPerBox) break;
      }
      return box;
    });

    final loadedEggs = <MysteryEgg>[];
    for (final item in (json['mysteryEggs'] as List<dynamic>? ?? const [])) {
      if (item is Map) {
        loadedEggs.add(MysteryEgg.fromJson(Map<String, dynamic>.from(item)));
      }
    }

    final rawIncubating = json['incubatingEgg'];
    final MysteryEgg? restoredIncubating = rawIncubating is Map
        ? MysteryEgg.fromJson(Map<String, dynamic>.from(rawIncubating))
        : null;

    String? armorId = json['equippedLabArmorId'] as String?;
    if (armorId != null && (loadedCustom[armorId] ?? 0) <= 0) {
      armorId = null;
    }

    final save = RegionSave(
      region: region,
      gameVersion: GameVersionExtension.fromStorageKey(
        json['gameVersion'] as String?,
      ),
      party: loadedParty,
      pcBoxes: loadedBoxes,
      activePcBoxIndex: ((json['activePcBoxIndex'] as num?)?.toInt() ?? 0)
          .clamp(0, numPcBoxes - 1),
      pokeBalls: ((json['pokeBalls'] as num?)?.toInt() ?? 20).clamp(0, 99),
      greatBalls: ((json['greatBalls'] as num?)?.toInt() ?? 0).clamp(0, 99),
      ultraBalls: ((json['ultraBalls'] as num?)?.toInt() ?? 0).clamp(0, 99),
      masterBalls: ((json['masterBalls'] as num?)?.toInt() ?? 0).clamp(0, 99),
      potions: ((json['potions'] as num?)?.toInt() ?? 10).clamp(0, 99),
      superPotions: ((json['superPotions'] as num?)?.toInt() ?? 0).clamp(0, 99),
      hyperPotions: ((json['hyperPotions'] as num?)?.toInt() ?? 0).clamp(0, 99),
      revives: ((json['revives'] as num?)?.toInt() ?? 5).clamp(0, 99),
      antidotes: ((json['antidotes'] as num?)?.toInt() ?? 0).clamp(0, 99),
      paralyzeHeals:
          ((json['paralyzeHeals'] as num?)?.toInt() ?? 0).clamp(0, 99),
      awakenings: ((json['awakenings'] as num?)?.toInt() ?? 0).clamp(0, 99),
      burnHeals: ((json['burnHeals'] as num?)?.toInt() ?? 0).clamp(0, 99),
      iceHeals: ((json['iceHeals'] as num?)?.toInt() ?? 0).clamp(0, 99),
      fullHeals: ((json['fullHeals'] as num?)?.toInt() ?? 0).clamp(0, 99),
      fullRestores: ((json['fullRestores'] as num?)?.toInt() ?? 0).clamp(0, 99),
      money: (json['money'] as num?)?.toInt() ?? 3000,
      encounterSteps: ((json['encounterSteps'] as num?)?.toInt() ?? 0)
          .clamp(0, maxEncounterSteps),
      badges: cleared.length,
      seenSpeciesIds: (json['seenSpeciesIds'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet(),
      caughtSpeciesIds: (json['caughtSpeciesIds'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet(),
      shinyCaughtSpeciesIds:
          (json['shinyCaughtSpeciesIds'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((n) => n.toInt())
              .toSet(),
      unlockedGymIds: unlocked,
      clearedGymIds: cleared,
      completedGymStepIds: completedSteps,
      gymTodaySteps: gymSteps,
      customItems: loadedCustom,
      expShareEnabled:
          cleared.contains(8) && (json['expShareEnabled'] == true),
      hasEarnedExpeditionMasterBall:
          json['hasEarnedExpeditionMasterBall'] == true,
      caughtExpeditionLegendaryIds:
          (json['caughtExpeditionLegendaryIds'] as List<dynamic>? ?? const [])
              .whereType<num>()
              .map((n) => n.toInt())
              .toSet(),
      victoryRoadCleared: vrCleared,
      championClears: champClears,
      hallOfFameEntries: loadedHof,
      claimedEventGiftIds:
          (json['claimedEventGiftIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toSet(),
      mysteryEggs: loadedEggs,
      incubatingEgg: restoredIncubating,
      equippedLabArmorId: armorId,
      friendshipStepCarry:
          max(0, (json['friendshipStepCarry'] as num?)?.toInt() ?? 0),
    );
    return save;
  }
}
