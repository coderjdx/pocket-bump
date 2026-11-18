class RivalRecord {
  final String id;
  String name;
  String title;
  String spriteId;
  int matches;
  int wins;
  bool isFriend;
  String lastOutcome; // 'win' | 'loss'
  DateTime lastBattledAt;

  RivalRecord({
    required this.id,
    required this.name,
    this.title = 'Trainer',
    this.spriteId = 'male_red',
    this.matches = 0,
    this.wins = 0,
    this.isFriend = false,
    this.lastOutcome = 'win',
    DateTime? lastBattledAt,
  }) : lastBattledAt = lastBattledAt ?? DateTime.now();

  int get losses => (matches - wins).clamp(0, matches);

  int get winRatePercent =>
      matches <= 0 ? 0 : ((wins / matches) * 100).round().clamp(0, 100);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'spriteId': spriteId,
      'matches': matches,
      'wins': wins,
      'isFriend': isFriend,
      'lastOutcome': lastOutcome,
      'lastBattledAt': lastBattledAt.toUtc().toIso8601String(),
    };
  }

  factory RivalRecord.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] as String?)?.trim() ?? '';
    final rawName = (json['name'] as String?)?.trim() ?? 'Trainer';
    final int parsedMatches =
        ((json['matches'] as num?)?.toInt() ?? 0).clamp(0, 999999);
    final int parsedWins =
        ((json['wins'] as num?)?.toInt() ?? 0).clamp(0, parsedMatches);
    final rawDate = json['lastBattledAt'] as String?;
    final parsedDate =
        rawDate != null ? DateTime.tryParse(rawDate)?.toLocal() : null;

    return RivalRecord(
      id: rawId.isNotEmpty ? rawId : 'rival_${rawName.toLowerCase()}',
      name: rawName.isNotEmpty ? rawName : 'Trainer',
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Trainer',
      spriteId: (json['spriteId'] as String?)?.trim().isNotEmpty == true
          ? (json['spriteId'] as String).trim()
          : 'male_red',
      matches: parsedMatches,
      wins: parsedWins,
      isFriend: json['isFriend'] == true,
      lastOutcome: json['lastOutcome'] == 'loss' ? 'loss' : 'win',
      lastBattledAt: parsedDate ?? DateTime.now(),
    );
  }
}
