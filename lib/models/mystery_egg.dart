class MysteryEgg {
  final String eggId;
  final int speciesId; // Kept hidden in UI until hatched
  final int requiredProgress;
  int currentProgress;
  final String originRegion;
  final String createdAtIso;

  MysteryEgg({
    required this.eggId,
    required this.speciesId,
    required this.requiredProgress,
    this.currentProgress = 0,
    this.originRegion = 'kanto',
    String? createdAtIso,
  }) : createdAtIso = createdAtIso ?? DateTime.now().toUtc().toIso8601String();

  /// Final stages of the 8 Gen 2 Baby Pokémon lines -> corresponding baby species ID.
  static const Map<int, int> babyEggSourceToBabySpecies = {
    26: 172, // Raichu -> Pichu
    36: 173, // Clefable -> Cleffa
    40: 174, // Wigglytuff -> Igglybuff
    176: 175, // Togetic -> Togepi
    106: 236, // Hitmonlee -> Tyrogue
    107: 236, // Hitmonchan -> Tyrogue
    237: 236, // Hitmontop -> Tyrogue
    124: 238, // Jynx -> Smoochum
    125: 239, // Electabuzz -> Elekid
    126: 240, // Magmar -> Magby
  };

  static int requiredProgressForBaby(int babySpeciesId) {
    switch (babySpeciesId) {
      case 172: // Pichu
      case 173: // Cleffa
      case 174: // Igglybuff
      case 175: // Togepi
        return 2500;
      case 236: // Tyrogue
      case 238: // Smoochum
      case 239: // Elekid
      case 240: // Magby
      default:
        return 4500;
    }
  }

  String get displayName => 'Mystery Egg';

  double get progressPercent => requiredProgress > 0
      ? (currentProgress / requiredProgress).clamp(0.0, 1.0)
      : 1.0;

  bool get isReadyToHatch => currentProgress >= requiredProgress;

  String get statusHint {
    if (isReadyToHatch) {
      return 'Oh? The Mystery Egg is ready to hatch!';
    }
    final pct = progressPercent;
    if (pct < 0.35) {
      return "What will hatch from this? It doesn't seem close to hatching.";
    }
    if (pct < 0.70) {
      return 'It appears to move occasionally. It may be close to hatching.';
    }
    return 'Sounds can be heard from inside! It will hatch soon!';
  }

  bool advance(int amount) {
    if (amount <= 0 || isReadyToHatch) return false;
    final before = currentProgress;
    currentProgress = (currentProgress + amount).clamp(0, requiredProgress);
    return currentProgress != before;
  }

  Map<String, dynamic> toJson() {
    return {
      'eggId': eggId,
      'speciesId': speciesId,
      'requiredProgress': requiredProgress,
      'currentProgress': currentProgress,
      'originRegion': originRegion,
      'createdAtIso': createdAtIso,
    };
  }

  factory MysteryEgg.fromJson(Map<String, dynamic> json) {
    final int specId = (json['speciesId'] as num?)?.toInt() ?? 172;
    final int req = ((json['requiredProgress'] as num?)?.toInt() ??
            requiredProgressForBaby(specId))
        .clamp(1, 100000);
    final int cur = ((json['currentProgress'] as num?)?.toInt() ?? 0).clamp(0, req);
    return MysteryEgg(
      eggId: (json['eggId'] as String?) ??
          'egg_${specId}_${DateTime.now().microsecondsSinceEpoch}',
      speciesId: specId,
      requiredProgress: req,
      currentProgress: cur,
      originRegion: (json['originRegion'] as String?) ?? 'kanto',
      createdAtIso: json['createdAtIso'] as String?,
    );
  }
}
