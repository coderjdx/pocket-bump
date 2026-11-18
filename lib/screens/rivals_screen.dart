import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rival.dart';
import '../models/trainer.dart';
import '../widgets/trainer_sprite.dart';
import 'bump_screen.dart';

class RivalsScreen extends StatefulWidget {
  const RivalsScreen({super.key});

  @override
  State<RivalsScreen> createState() => _RivalsScreenState();
}

class _RivalsScreenState extends State<RivalsScreen> {
  bool _friendsOnly = false;

  String _formatRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return "${timestamp.year}-$month-$day";
  }

  Future<void> _handleFriendToggle(Trainer trainer, RivalRecord rival) async {
    if (!rival.isFriend) {
      trainer.toggleRivalFriend(rival.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Added ${rival.name} as a Friend!"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          "Remove ${rival.name}?",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(
          "${rival.name} will still remain in your Rivals list with ${rival.matches} ${rival.matches == 1 ? 'match' : 'matches'} recorded.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Remove Friend",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      trainer.toggleRivalFriend(rival.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final List<RivalRecord> visibleRivals = _friendsOnly
        ? trainer.rivals.where((r) => r.isFriend).toList()
        : trainer.rivals;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1424),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "RIVALS & FRIENDS",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Fist-Bump Link",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BumpScreen()),
              );
            },
            icon: const Icon(Icons.sports_mma_rounded,
                color: Colors.amberAccent, size: 20),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(trainer),
          _buildFilterTabs(trainer),
          Expanded(
            child: visibleRivals.isEmpty
                ? _buildEmptyState(trainer)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                    itemCount: visibleRivals.length,
                    itemBuilder: (context, index) {
                      return _buildRivalCard(trainer, visibleRivals[index]);
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF121728),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.cyanAccent, size: 15),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Saved locally on this device. Social & friend features will expand with trainer accounts.",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Trainer trainer) {
    final int totalMatches = trainer.totalPvpMatches;
    final int totalWins = trainer.totalPvpWins;
    final int winPct =
        totalMatches <= 0 ? 0 : ((totalWins / totalMatches) * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2138), Color(0xFF111626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          _buildSummaryStat("RIVALS", "${trainer.rivals.length}", Colors.white),
          _buildDivider(),
          _buildSummaryStat("MATCHES", "$totalMatches", Colors.lightBlueAccent),
          _buildDivider(),
          _buildSummaryStat("WINS", "$totalWins ($winPct%)",
              const Color(0xFF34EB8C)),
          _buildDivider(),
          _buildSummaryStat(
              "FRIENDS", "${trainer.friendCount}", Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 26,
      color: Colors.white12,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildFilterTabs(Trainer trainer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterButton(
              label: "ALL RIVALS (${trainer.rivals.length})",
              selected: !_friendsOnly,
              accent: Colors.cyanAccent,
              onTap: () => setState(() => _friendsOnly = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterButton(
              label: "FRIENDS (${trainer.friendCount})",
              selected: _friendsOnly,
              accent: Colors.amberAccent,
              onTap: () => setState(() => _friendsOnly = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.18) : const Color(0xFF141828),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? accent : Colors.white12,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }

  Widget _buildRivalCard(Trainer trainer, RivalRecord rival) {
    final bool lastWon = rival.lastOutcome == 'win';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rival.isFriend
              ? [const Color(0xFF1B243B), const Color(0xFF13192B)]
              : [const Color(0xFF171C2E), const Color(0xFF101423)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rival.isFriend
              ? Colors.amberAccent.withOpacity(0.5)
              : Colors.white12,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E18),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: rival.isFriend
                    ? Colors.amberAccent.withOpacity(0.55)
                    : Colors.cyanAccent.withOpacity(0.3),
              ),
            ),
            child: TrainerSpriteWidget(
              spriteId: rival.spriteId,
              size: 48,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rival.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (rival.isFriend) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.7)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 11, color: Colors.amberAccent),
                            SizedBox(width: 2),
                            Text(
                              "FRIEND",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "${rival.title} • ${_formatRelativeTime(rival.lastBattledAt)}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMetricChip(
                      "MATCHES ${rival.matches}",
                      Colors.lightBlueAccent,
                    ),
                    _buildMetricChip(
                      "WINS ${rival.wins}",
                      const Color(0xFF34EB8C),
                    ),
                    _buildMetricChip(
                      "LAST: ${lastWon ? 'WIN' : 'LOSS'}",
                      lastWon ? const Color(0xFF34EB8C) : Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          rival.isFriend
              ? OutlinedButton.icon(
                  onPressed: () => _handleFriendToggle(trainer, rival),
                  icon: const Icon(Icons.check_rounded, size: 15),
                  label: const Text(
                    "FRIEND",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: BorderSide(
                        color: Colors.amberAccent.withOpacity(0.65)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: () => _handleFriendToggle(trainer, rival),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                  label: const Text(
                    "ADD FRIEND",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00ACC1),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildEmptyState(Trainer trainer) {
    final bool hasAnyRivals = trainer.rivals.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF131829),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasAnyRivals
                    ? Icons.star_border_rounded
                    : Icons.sports_mma_rounded,
                size: 44,
                color: hasAnyRivals ? Colors.amberAccent : Colors.cyanAccent,
              ),
              const SizedBox(height: 12),
              Text(
                hasAnyRivals ? "No Friends Added Yet" : "No Rivals Yet",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasAnyRivals
                    ? "Switch to All Rivals and tap Add Friend on any trainer you've battled."
                    : "Complete a Fist-Bump Battle with another player to record your rivalry, match count, and wins here.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (hasAnyRivals)
                OutlinedButton(
                  onPressed: () => setState(() => _friendsOnly = false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyanAccent,
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                  child: const Text("SHOW ALL RIVALS",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BumpScreen()),
                    );
                  },
                  icon: const Icon(Icons.sensors_rounded, size: 18),
                  label: const Text(
                    "OPEN FIST-BUMP LINK",
                    style: TextStyle(
                        fontWeight: FontWeight.w900, letterSpacing: 0.6),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
