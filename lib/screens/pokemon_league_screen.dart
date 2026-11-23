import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/gym_database.dart';
import '../services/sound_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_pp_picker_dialog.dart';
import 'battle_screen.dart';

class PokemonLeagueScreen extends StatefulWidget {
  const PokemonLeagueScreen({super.key});

  @override
  State<PokemonLeagueScreen> createState() => _PokemonLeagueScreenState();
}

class _PokemonLeagueScreenState extends State<PokemonLeagueScreen> {
  // === GAUNTLET RUNNER STATE ===
  GymDefinition? _activeGym;
  List<GymTrainer> _activeGauntlet = const [];
  int _gauntletIndex = 0; // 0 to 4 (0-3: Gym Trainers, 4: Gym Leader)
  bool _inGauntletCheckpoint = false;
  bool _isLaunchingBattle = false;
  bool _isBagModalOpen = false;

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);

    // If currently in a rest checkpoint between gauntlet matches
    if (_inGauntletCheckpoint && _activeGym != null) {
      return _buildGauntletCheckpointScreen(trainer);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E18),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC0D0E18),
        elevation: 0,
        title: const Text(
          "POKÉMON LEAGUE",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded,
                    color: Color(0xFFFFD54F), size: 15),
                const SizedBox(width: 4),
                Text(
                  "${trainer.clearedGymIds.length}/8 BADGES",
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_league.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF140B12).withOpacity(0.76),
                  const Color(0xFF100E1A).withOpacity(0.62),
                  const Color(0xFF0A0A12).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                // Velvet Kanto Badge Case
                _buildBadgeShowcase(trainer),
                const SizedBox(height: 16),

                // Section Header
                Row(
                  children: [
                    const Icon(Icons.military_tech_rounded,
                        color: Color(0xFFFFD54F), size: 18),
                    const SizedBox(width: 7),
                    const Text(
                      "KANTO GYM GAUNTLETS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "WALK & CATCH TO UNLOCK",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 8 Gym Cards
                for (final gym in GymDatabase.gyms) ...[
                  _buildGymCard(context, trainer, gym),
                  const SizedBox(height: 11),
                ],

                const SizedBox(height: 6),

                // Elite Four & Champion Challenge Teaser
                _buildEliteFourTeaser(trainer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // === VELVET KANTO BADGE CASE ===
  Widget _buildBadgeShowcase(Trainer trainer) {
    const badgeNames = [
      "Boulder",
      "Cascade",
      "Thunder",
      "Rainbow",
      "Soul",
      "Marsh",
      "Volcano",
      "Earth",
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xEE1F1522), Color(0xEE110D18)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFD54F).withOpacity(0.5),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFFFD54F), size: 14),
                  SizedBox(width: 5),
                  Text(
                    "KANTO BADGE CASE",
                    style: TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0810),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFFD54F).withOpacity(0.4)),
                ),
                child: Text(
                  "OBEY UP TO LV.${trainer.maxObedienceLevel}",
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int id = 1; id <= 8; id++) ...[
                _buildBadgeSlot(
                  id: id,
                  name: badgeNames[id - 1],
                  isEarned: trainer.clearedGymIds.contains(id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSlot({
    required int id,
    required String name,
    required bool isEarned,
  }) {
    final gym = GymDatabase.getGymById(id);
    final color = gym?.elementColor ?? Colors.amber;
    final String badgeAsset =
        gym?.badgeAsset ?? 'assets/images/badges/boulder_badge.png';

    return Column(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isEarned
                  ? [color.withOpacity(0.35), const Color(0xFF14111D)]
                  : [const Color(0xFF0A0910), const Color(0xFF15121E)],
            ),
            border: Border.all(
              color: isEarned ? color : Colors.white12,
              width: isEarned ? 1.8 : 1.0,
            ),
            boxShadow: isEarned
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.42),
                      blurRadius: 9,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Opacity(
              opacity: isEarned ? 1.0 : 0.25,
              child: isEarned
                  ? Image.asset(
                      badgeAsset,
                      width: 24,
                      height: 24,
                      filterQuality: FilterQuality.none,
                    )
                  : ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.grey,
                        BlendMode.saturation,
                      ),
                      child: Image.asset(
                        badgeAsset,
                        width: 22,
                        height: 22,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: isEarned ? FontWeight.w900 : FontWeight.w500,
            color: isEarned ? Colors.white : Colors.white30,
          ),
        ),
      ],
    );
  }

  // === INDIVIDUAL GYM CARD ===
  Widget _buildGymCard(BuildContext context, Trainer trainer, GymDefinition gym) {
    final isUnlocked = trainer.isGymUnlocked(gym.id);
    final isCleared = trainer.isGymCleared(gym.id);
    final isStepDone = trainer.isGymStepCompleted(gym.id);
    final todaySteps = trainer.getGymTodaySteps(gym.id);
    final caughtCount = trainer.caughtCount;
    final canChallenge = trainer.canChallengeGym(gym.id);

    final bool caughtMet = caughtCount >= gym.requiredCaught;
    final bool stepsMet = isStepDone || (todaySteps >= gym.requiredSteps);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCleared
              ? [gym.elementColor.withOpacity(0.18), const Color(0xEA121524)]
              : (isUnlocked
                  ? [gym.elementColor.withOpacity(0.10), const Color(0xEA121422)]
                  : [const Color(0xDD10111B), const Color(0xDD0B0C14)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCleared
              ? gym.elementColor.withOpacity(0.65)
              : (isUnlocked
                  ? gym.elementColor.withOpacity(0.35)
                  : Colors.white.withOpacity(0.08)),
          width: isCleared ? 1.5 : 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym Header Row
            Row(
              children: [
                // Gym Badge image icon medallion
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0D16),
                    borderRadius: BorderRadius.circular(11),
                    border:
                        Border.all(color: gym.elementColor.withOpacity(0.65)),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: isCleared ? 1.0 : (isUnlocked ? 0.85 : 0.35),
                      child: Image.asset(
                        gym.badgeAsset,
                        width: 28,
                        height: 28,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              gym.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: gym.elementColor.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: gym.elementColor.withOpacity(0.7)),
                            ),
                            child: Text(
                              gym.element.toUpperCase(),
                              style: TextStyle(
                                color: gym.elementColor,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${gym.city} • Leader ${gym.leaderName}",
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCleared) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0E16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withOpacity(0.75)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: Color(0xFFFFD54F), size: 12),
                        SizedBox(width: 3),
                        Text(
                          "CLEARED",
                          style: TextStyle(
                            color: Color(0xFFFFD54F),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Badge & Reward Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E17),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: gym.elementColor, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${gym.badgeName}: ${gym.badgeDescription}",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Requirement Gates Row
            if (!isUnlocked) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: Colors.redAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "LOCKED: Clear Gym ${gym.id - 1} first to unlock entry permit.",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildRequirementPill(
                      label: "Pokédex Caught",
                      current: caughtCount,
                      target: gym.requiredCaught,
                      unit: "species",
                      isDone: caughtMet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRequirementPill(
                      label: "Single-Day Steps",
                      current: isStepDone ? gym.requiredSteps : todaySteps,
                      target: gym.requiredSteps,
                      unit: "steps",
                      isDone: stepsMet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Gauntlet Info / Challenge Button
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Gauntlet: 4 Gym Trainers + Gym Leader",
                          style: TextStyle(color: Colors.white60, fontSize: 10),
                        ),
                        if (isCleared) ...[
                          Text(
                            "Re-challenge (On-Par Lv. • 2–5 Trainer / 6 Leader Mons): Rare Gen 1 TMs, ${gym.signatureHeldItemDrop.replaceAll('_', ' ')}, Stones & Fossils",
                            style: TextStyle(
                              color: gym.elementColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: (canChallenge && !_isLaunchingBattle)
                        ? () => _startGymGauntlet(context, trainer, gym)
                        : null,
                    icon: Icon(
                      canChallenge
                          ? Icons.sports_martial_arts_rounded
                          : Icons.lock_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isCleared ? "RE-CHALLENGE" : "ENTER GAUNTLET",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gym.elementColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white10,
                      disabledForegroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementPill({
    required String label,
    required int current,
    required int target,
    required String unit,
    required bool isDone,
  }) {
    final double pct = (current / target).clamp(0.0, 1.0);
    final color = isDone ? const Color(0xFF34EB8C) : Colors.amberAccent;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E17),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isDone ? color.withOpacity(0.45) : Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 9.5),
              ),
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 12,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "$current / $target $unit",
            style: TextStyle(
              color: isDone ? Colors.white : color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 3.5,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // === ELITE FOUR TEASER CARD ===
  Widget _buildEliteFourTeaser(Trainer trainer) {
    final badges = trainer.clearedGymIds.length;
    final bool unlocked = badges >= 8;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: unlocked
              ? [const Color(0xEE2B2012), const Color(0xEE141118)]
              : [const Color(0xE0131522), const Color(0xE00C0D16)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? Colors.amberAccent.withOpacity(0.65) : Colors.white12,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0C14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.amberAccent.withOpacity(0.45)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: Colors.amberAccent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "INDIGO PLATEAU",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.9,
                      ),
                    ),
                    Text(
                      "Pokémon League Champion Road",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.55), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unlocked
                      ? Colors.amber.withOpacity(0.22)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: unlocked ? Colors.amberAccent : Colors.white12,
                  ),
                ),
                child: Text(
                  unlocked ? "READY" : "LOCKED (8 BADGES)",
                  style: TextStyle(
                    color: unlocked ? Colors.amberAccent : Colors.white38,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "The Elite Four (Lorelei, Bruno, Agatha, Lance) and the Regional Champion await the master trainer who conquers all 8 Kanto Gyms. Keep training and collecting badges!",
            style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // === GAUNTLET RUNNER & BATTLE LOOP ===
  Future<void> _startGymGauntlet(BuildContext context, Trainer trainer, GymDefinition gym) async {
    if (_isLaunchingBattle) return;
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All Pokémon in your party are fainted! Heal first.")),
      );
      return;
    }

    final bool isRematch = trainer.isGymCleared(gym.id);
    final List<GymTrainer> gauntletTeams;
    if (isRematch) {
      final double playerAvgLevel = trainer.party.isEmpty
          ? 5.0
          : trainer.party.fold<int>(0, (s, p) => s + p.level) /
              trainer.party.length;
      gauntletTeams = GymDatabase.buildRematchGauntlet(
        gym,
        playerAvgLevel: playerAvgLevel,
      );
    } else {
      gauntletTeams = gym.fullGauntlet;
    }

    setState(() {
      _activeGym = gym;
      _activeGauntlet = gauntletTeams;
      _gauntletIndex = 0;
      _inGauntletCheckpoint = false;
    });

    await _launchNextGauntletBattle(trainer);
  }

  Future<void> _launchNextGauntletBattle(Trainer trainer) async {
    if (_activeGym == null || _isLaunchingBattle) return;

    final gauntlet = _activeGauntlet.isNotEmpty
        ? _activeGauntlet
        : _activeGym!.fullGauntlet;
    if (_gauntletIndex >= gauntlet.length) {
      // Completed all 5 battles!
      _onGauntletVictorious(trainer, _activeGym!);
      return;
    }

    setState(() => _isLaunchingBattle = true);

    try {
      final currentOpponent = gauntlet[_gauntletIndex];
      final opponentTeamInstances =
          currentOpponent.team.map((spec) => spec.createInstance()).toList();
      final firstMon = opponentTeamInstances.first;

      await precacheImage(
        AssetImage(_activeGym!.backgroundAsset),
        context,
      ).catchError((_) {});
      if (!mounted) return;

      final bool? won = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            opponentPokemon: firstMon,
            opponentTeam: opponentTeamInstances,
            isWild: false,
            trainerName: currentOpponent.name,
            trainerTitle: currentOpponent.title,
            opponentSpriteId: currentOpponent.spriteId,
            prizeMoney: currentOpponent.prizeMoney,
            preservePartyHpOnExit: true,
            battleBackgroundAsset: _activeGym!.backgroundAsset,
            bgmCategory: BattleBgmCategory.gym,
          ),
        ),
      );
      if (!mounted) return;

      if (won == true) {
        // Advance to checkpoint
        setState(() {
          _isLaunchingBattle = false;
          _gauntletIndex++;
          if (_gauntletIndex >= gauntlet.length) {
            _inGauntletCheckpoint = false;
            _onGauntletVictorious(trainer, _activeGym!);
          } else {
            _inGauntletCheckpoint = true;
          }
        });
      } else {
        // Lost or fled — preserve party HP/PP/status (heal at Pokémon Center)
        trainer.resetAllPartyStatStages();
        trainer.saveProgress();
        setState(() {
          _isLaunchingBattle = false;
          _inGauntletCheckpoint = false;
          _activeGym = null;
          _activeGauntlet = const [];
          _gauntletIndex = 0;
        });
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E28),
              title: const Text(
                "GAUNTLET FAILED",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              content: const Text(
                "Your party was defeated or retreated. In the Gym Gauntlet, you must defeat all 4 Gym Trainers and the Gym Leader in sequence.\n\nHeal up your party and try again!",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (ModalRoute.of(ctx)?.isCurrent == true) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.amberAccent)),
                ),
              ],
            ),
          );
        }
      }
    } finally {
      if (mounted && _isLaunchingBattle) {
        setState(() => _isLaunchingBattle = false);
      }
    }
  }

  Future<void> _confirmRetreatFromGauntlet(Trainer trainer) async {
    if (_activeGym == null || _isLaunchingBattle) return;
    final gymName = _activeGym!.name;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text(
          "RETREAT FROM GAUNTLET?",
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        content: Text(
          "Retreating from $gymName will reset your current gauntlet progress (Match $_gauntletIndex of 5 cleared).\n\nYour party's current HP, PP, and status will be preserved.",
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (ModalRoute.of(ctx)?.isCurrent == true) {
                Navigator.pop(ctx, false);
              }
            },
            child: const Text(
              "STAY",
              style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              if (ModalRoute.of(ctx)?.isCurrent == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text(
              "RETREAT",
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      trainer.resetAllPartyStatStages();
      trainer.saveProgress();
      setState(() {
        _inGauntletCheckpoint = false;
        _activeGym = null;
        _activeGauntlet = const [];
        _gauntletIndex = 0;
      });
    }
  }

  // === REST CHECKPOINT SCREEN (BETWEEN MATCHES) ===
  Widget _buildGauntletCheckpointScreen(Trainer trainer) {
    final gym = _activeGym!;
    final gauntlet =
        _activeGauntlet.isNotEmpty ? _activeGauntlet : gym.fullGauntlet;
    final nextOpponent = gauntlet[_gauntletIndex];
    final bool isLeaderNext = _gauntletIndex == 4;
    final int nextAvgLvl = nextOpponent.team.isEmpty
        ? 5
        : (nextOpponent.team.fold<int>(0, (s, p) => s + p.level) /
                nextOpponent.team.length)
            .round();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isLaunchingBattle) {
          _confirmRetreatFromGauntlet(trainer);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C0E18),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: const Color(0xCC0D0E18),
          elevation: 0,
          title: Text(
            "${gym.name.toUpperCase()} CHECKPOINT",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            TextButton.icon(
              onPressed: _isLaunchingBattle
                  ? null
                  : () => _confirmRetreatFromGauntlet(trainer),
              icon: const Icon(
                Icons.exit_to_app_rounded,
                color: Colors.redAccent,
                size: 15,
              ),
              label: const Text(
                "RETREAT",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_league.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF140B12).withOpacity(0.76),
                  const Color(0xFF100E1A).withOpacity(0.62),
                  const Color(0xFF0A0A12).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkpoint Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          gym.elementColor.withOpacity(0.22),
                          const Color(0xEA121624),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: gym.elementColor.withOpacity(0.6),
                        width: 1.3,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: gym.elementColor, size: 18),
                            const SizedBox(width: 7),
                            Text(
                              "MATCH $_gauntletIndex OF 5 CLEARED",
                              style: TextStyle(
                                color: gym.elementColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLeaderNext
                              ? "NEXT: FINAL BATTLE WITH LEADER ${gym.leaderName.toUpperCase()} (${nextOpponent.team.length} Pokémon • Avg Lv.$nextAvgLvl)!"
                              : "NEXT: ${nextOpponent.name.toUpperCase()} (${nextOpponent.title} • ${nextOpponent.team.length} Pokémon • Avg Lv.$nextAvgLvl)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "HP, PP, and status do not auto-heal between gauntlet battles. Use items from your Bag to prepare!",
                          style: TextStyle(color: Colors.white70, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Party Status Header
                  const Text(
                    "POKÉMON CONDITION",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Party Pokémon Cards
                  Expanded(
                    child: ListView.separated(
                      itemCount: trainer.party.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (ctx, idx) {
                        final mon = trainer.party[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xE8141826),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: mon.isFainted
                                  ? Colors.redAccent.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        mon.nickname,
                                        style: TextStyle(
                                          color: mon.isFainted
                                              ? Colors.white38
                                              : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Lv.${mon.level}",
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (mon.status != StatusCondition.none) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent
                                                .withOpacity(0.22),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            mon.status.name.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "HP: ${mon.currentHp} / ${mon.maxHp}",
                                    style: TextStyle(
                                      color: mon.isFainted
                                          ? Colors.redAccent
                                          : Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 105,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (mon.currentHp / mon.maxHp)
                                        .clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: Colors.white10,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      mon.isFainted
                                          ? Colors.transparent
                                          : (mon.currentHp <= mon.maxHp / 5
                                              ? Colors.redAccent
                                              : (mon.currentHp <= mon.maxHp / 2
                                                  ? Colors.amberAccent
                                                  : const Color(0xFF34EB8C))),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLaunchingBattle
                              ? null
                              : () => _openBagModal(context, trainer),
                          icon: const Icon(Icons.medical_services_rounded,
                              size: 16),
                          label: const Text(
                            "USE BAG ITEMS",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFF121828),
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.tealAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLaunchingBattle
                              ? null
                              : () => _launchNextGauntletBattle(trainer),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            isLeaderNext ? "FACE LEADER" : "CONTINUE",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gym.elementColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // === BAG USE MODAL AT CHECKPOINT ===
  void _openBagModal(BuildContext context, Trainer trainer) {
    if (_isBagModalOpen || _isLaunchingBattle) return;
    _isBagModalOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isClosing = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final medicineItems = [
              'potion',
              'super_potion',
              'hyper_potion',
              'max_potion',
              'full_restore',
              'revive',
              'antidote',
              'paralyze_heal',
              'awakening',
              'burn_heal',
              'ice_heal',
              'full_heal',
              'ether',
              'max_ether',
              'elixir',
              'max_elixir',
              'leppa_berry',
            ];

            final available = medicineItems
                .where((id) => trainer.getItemCount(id) > 0)
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "USE ITEMS ON POKÉMON",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () {
                          if (isClosing) return;
                          if (ModalRoute.of(ctx)?.isCurrent == true) {
                            isClosing = true;
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (available.isEmpty) ...[
                    const Expanded(
                      child: Center(
                        child: Text(
                          "You don't have any healing items in your Bag!",
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ListView.separated(
                        itemCount: available.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (c, idx) {
                          final itemId = available[idx];
                          final itemDef = ItemDatabase.byId(itemId);
                          final count = trainer.getItemCount(itemId);

                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF282836),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  itemDef?.icon ?? Icons.medical_services,
                                  color: itemDef?.color ?? Colors.tealAccent,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${itemDef?.name ?? itemId} (x$count)",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        itemDef?.description ?? "",
                                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    _selectPartyTargetAndApply(
                                      context,
                                      trainer,
                                      itemId,
                                      () {
                                        if (ctx.mounted) {
                                          setModalState(() {});
                                        }
                                        if (mounted) {
                                          setState(() {});
                                        }
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  child: const Text("USE", style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _isBagModalOpen = false;
    });
  }

  void _selectPartyTargetAndApply(
    BuildContext context,
    Trainer trainer,
    String itemId,
    VoidCallback onUpdated,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isApplying = false;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E28),
          title: Text(
            "USE ${itemId.replaceAll('_', ' ').toUpperCase()} ON:",
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trainer.party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (c, idx) {
                final mon = trainer.party[idx];
                return ListTile(
                  tileColor: const Color(0xFF282836),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  title: Text(
                    "${mon.nickname} (HP ${mon.currentHp}/${mon.maxHp})",
                    style: TextStyle(
                      color: mon.isFainted ? Colors.white38 : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  subtitle: ItemDatabase.isPpRestoreItem(itemId)
                      ? Text(
                          "Total PP ${mon.moves.fold<int>(0, (s, m) => s + m.currentPp)}/${mon.moves.fold<int>(0, (s, m) => s + m.maxPp)}",
                          style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
                        )
                      : mon.status != StatusCondition.none
                          ? Text(
                              "Status: ${mon.status.name.toUpperCase()}",
                              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
                            )
                          : null,
                  onTap: () async {
                    if (isApplying) return;
                    if (!ItemDatabase.canUseMedicineOn(itemId, mon)) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text("It won't have any effect!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      return;
                    }
                    isApplying = true;
                    try {
                      int? moveIndex;
                      if (ItemDatabase.isSingleMovePpItem(itemId)) {
                        final itemDef = ItemDatabase.byId(itemId);
                        if (itemDef != null) {
                          moveIndex = await showMovePpPickerDialog(
                            ctx,
                            pokemon: mon,
                            item: itemDef,
                          );
                          if (moveIndex == null) return;
                        }
                      }
                      final String msg = ItemDatabase.applyMedicineToPokemon(
                        itemId: itemId,
                        targetMon: mon,
                        moveIndex: moveIndex,
                      );
                      trainer.adjustItemCount(itemId, -1);
                      trainer.saveProgress();
                      onUpdated();
                      if (ctx.mounted && ModalRoute.of(ctx)?.isCurrent == true) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } finally {
                      isApplying = false;
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // === GAUNTLET VICTORY CELEBRATION ===
  void _onGauntletVictorious(Trainer trainer, GymDefinition gym) {
    final bool firstClear = !trainer.isGymCleared(gym.id);
    if (firstClear) {
      trainer.clearGym(gym.id);
    }
    trainer.resetAllPartyStatStages();
    trainer.saveProgress();

    // Rare drop roll on repeat clears (Gen 1 TMs, held items, evolution stones, or fossil items)
    String? droppedItemName;
    if (!firstClear) {
      final rng = Random();
      final roll = rng.nextDouble();
      if (roll < 0.28 && gym.tmDrops.isNotEmpty) {
        // Rare Gen 1 TM drop (weighted toward the Gym Leader's signature TM)
        final int tmIdx =
            rng.nextDouble() < 0.35 ? 0 : rng.nextInt(gym.tmDrops.length);
        final String tmId = gym.tmDrops[tmIdx];
        trainer.adjustItemCount(tmId, 1);
        final itemDef = ItemDatabase.byId(tmId);
        droppedItemName = itemDef?.name ?? tmId.toUpperCase();
      } else if (roll < 0.46) {
        // Drop signature held item
        trainer.adjustItemCount(gym.signatureHeldItemDrop, 1);
        final itemDef = ItemDatabase.byId(gym.signatureHeldItemDrop);
        droppedItemName = itemDef?.name ?? gym.signatureHeldItemDrop;
      } else if (roll < 0.62) {
        // Drop signature stone
        trainer.adjustItemCount(gym.signatureStoneDrop, 1);
        final itemDef = ItemDatabase.byId(gym.signatureStoneDrop);
        droppedItemName = itemDef?.name ?? gym.signatureStoneDrop;
      } else if (roll < 0.74) {
        // Rare Unknown Fossil drop
        trainer.adjustItemCount('unknown_fossil', 1);
        droppedItemName =
            ItemDatabase.byId('unknown_fossil')?.name ?? 'Unknown Fossil';
      } else if (roll < 0.86) {
        // Rare Fossil Restoration Voucher drop
        trainer.adjustItemCount('fossil_restoration_voucher', 1);
        droppedItemName =
            ItemDatabase.byId('fossil_restoration_voucher')?.name ??
                'Fossil Restoration Voucher';
      }
      trainer.saveProgress();
    }

    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: gym.elementColor, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "GAUNTLET CONQUERED!",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You successfully defeated all 4 Gym Trainers and Gym Leader ${gym.leaderName} of ${gym.city}!",
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (firstClear) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: gym.elementColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gym.elementColor.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      gym.badgeAsset,
                      width: 42,
                      height: 42,
                      filterQuality: FilterQuality.none,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AWARDED: ${gym.badgeName.toUpperCase()}!",
                            style: TextStyle(
                              color: gym.elementColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            gym.badgeDescription,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (droppedItemName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.amberAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Rare Gym Leader Drop: Received 1x $droppedItemName!",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _activeGym = null;
                _activeGauntlet = const [];
                _gauntletIndex = 0;
                _inGauntletCheckpoint = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: gym.elementColor,
              foregroundColor: Colors.black,
            ),
            child: const Text("CONTINUE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
