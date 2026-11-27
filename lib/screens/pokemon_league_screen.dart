import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_region.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/gym_database.dart';
import '../services/item_drop_service.dart';
import '../services/sound_service.dart';
import '../services/tm_service.dart';
import '../widgets/gauntlet_checkpoint_sheets.dart';
import '../widgets/poke_theme.dart';
import 'battle_screen.dart';
import 'hall_of_fame_screen.dart';
import 'victory_road_screen.dart';

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
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "POKÉMON LEAGUE",
        barColor: PokeColors.leagueIndigo,
        bottomBorderColor: PokeColors.leagueIndigoDark,
        actions: [
          PokeCounterPill(
            icon: Icons.stars_rounded,
            iconColor: PokeColors.badgeGoldDark,
            text: "${trainer.clearedGymIds.length}/8 BADGES",
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_pokemon_league.png',
            topOpacity: 0.22,
            midOpacity: 0.45,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                // Classic Kanto Badge Case
                _buildBadgeShowcase(trainer),
                const SizedBox(height: 16),

                // Section Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.creamSurface.withOpacity(0.95),
                    border: PokeColors.leagueIndigo,
                    radius: 11,
                    borderWidth: 1.3,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.military_tech_rounded,
                          color: PokeColors.leagueIndigo, size: 18),
                      const SizedBox(width: 7),
                      Text(
                        "${trainer.activeRegion.displayName.toUpperCase()} GYM GAUNTLETS",
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "WALK & CATCH",
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 8 Regional Gym Cards
                for (final gym in GymDatabase.gymsForRegion(trainer.activeRegion)) ...[
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

  // === ROYAL NAVY REGIONAL BADGE CASE ===
  Widget _buildBadgeShowcase(Trainer trainer) {
    final gyms = GymDatabase.gymsForRegion(trainer.activeRegion);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PokeColors.leagueIndigo, PokeColors.leagueIndigoDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: PokeColors.badgeGold,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: PokeColors.leagueIndigoDark.withOpacity(0.35),
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
              Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: Color(0xFFFFD54F), size: 15),
                  const SizedBox(width: 5),
                  Text(
                    "${trainer.activeRegion.displayName.toUpperCase()} BADGE CASE",
                    style: const TextStyle(
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
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFFD54F).withOpacity(0.65),
                  ),
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
              for (final gym in gyms) ...[
                _buildBadgeSlot(
                  gym: gym,
                  isEarned: trainer.clearedGymIds.contains(gym.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeSlot({
    required GymDefinition gym,
    required bool isEarned,
  }) {
    final color = gym.elementColor;
    final String badgeAsset = gym.badgeAsset;
    final String name = gym.badgeName.replaceAll(' Badge', '');

    return Column(
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: isEarned
                  ? [Colors.white.withOpacity(0.28), color.withOpacity(0.25)]
                  : [const Color(0xFF151C52), const Color(0xFF0E133D)],
            ),
            border: Border.all(
              color: isEarned ? color : Colors.white24,
              width: isEarned ? 2.0 : 1.0,
            ),
            boxShadow: isEarned
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.45),
                      blurRadius: 8,
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
            color: isEarned ? Colors.white : Colors.white38,
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
    final Color gymAccentDark = PokeColors.darken(gym.elementColor, 0.16);

    return Container(
      decoration: PokeDecorations.card(
        fill: isCleared || isUnlocked
            ? PokeColors.cardWhite
            : PokeColors.creamSurface,
        border: isCleared
            ? gymAccentDark
            : (isUnlocked
                ? gym.elementColor
                : PokeColors.frameBorderSoft),
        radius: 16,
        borderWidth: isCleared ? 1.8 : 1.4,
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gym Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: gym.elementColor.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: gymAccentDark.withOpacity(0.55),
                      width: 1.3,
                    ),
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
                                color: PokeColors.inkDark,
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
                              color: gymAccentDark,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              gym.element.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
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
                          color: PokeColors.inkMuted,
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
                      color: PokeColors.badgeGold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PokeColors.badgeGoldDark),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded,
                            color: PokeColors.badgeGoldDark, size: 12),
                        SizedBox(width: 3),
                        Text(
                          "CLEARED",
                          style: TextStyle(
                            color: PokeColors.badgeGoldDark,
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: PokeDecorations.inset(radius: 9),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: gymAccentDark, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${gym.badgeName}: ${gym.badgeDescription}",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
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
                  color: PokeColors.pokeRed.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: PokeColors.pokeRed.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: PokeColors.pokeRed, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      "LOCKED: Clear Gym ${gym.id - 1} first to unlock entry permit.",
                      style: const TextStyle(
                        color: PokeColors.pokeRedDark,
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
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isCleared) ...[
                          Text(
                            "Re-challenge (On-Par Lv. • 2–5 Trainer / 6 Leader Mons)",
                            style: TextStyle(
                              color: gymAccentDark,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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
                      backgroundColor: gymAccentDark,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PokeColors.panelSoft,
                      disabledForegroundColor: PokeColors.inkSubtle,
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
    final color = isDone ? PokeColors.pokeGreen : PokeColors.badgeGoldDark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: PokeDecorations.inset(
        radius: 9,
        border: isDone
            ? PokeColors.pokeGreen.withOpacity(0.55)
            : PokeColors.frameBorderSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
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
              color: isDone ? PokeColors.pokeGreenDark : PokeColors.inkDark,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: PokeColors.cardWhite,
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
    final bool unlocked = trainer.isVictoryRoadUnlocked;
    final String regionName = trainer.activeRegion.displayName;
    final String rosterSummary = trainer.activeRegion == GameRegion.johto
        ? "the Final Four (Will, Koga, Bruno, Karen), and Champion Lance"
        : "the Final Four (Lorelei, Bruno, Agatha, Lance), and Champion Blue";
    final String bossSummary = trainer.activeRegion == GameRegion.johto
        ? "Will, Koga, Bruno, Karen, and Champion Lance"
        : "Lorelei, Bruno, Agatha, Lance, and the Indigo Champion";
    final String rematchBossLabel = trainer.activeRegion == GameRegion.johto
        ? "Final Four Masters & Lance"
        : "Final Four Masters & Blue";
    final String stateBadge = !unlocked
        ? "LOCKED ($badges/8 BADGES)"
        : (!trainer.victoryRoadCleared
            ? "VICTORY ROAD READY"
            : (!trainer.isChampion ? "FINAL FOUR READY" : "LV.99 REMATCH"));
    final String description = !unlocked
        ? "Victory Road, $rosterSummary unlock as soon as you collect all 8 $regionName Gym Badges!"
        : (!trainer.victoryRoadCleared
            ? "All 8 Gym Badges earned! Clear the 6-stage Victory Road mountain gauntlet (Wild → Trainer) to unlock the Indigo Plateau Final Four."
            : (!trainer.isChampion
                ? "Victory Road cleared! Challenge $bossSummary in one continuous run."
                : "Champion title claimed (${trainer.championClears} clears)! Re-enter Victory Road at Lv. 99 to battle $rematchBossLabel for exclusive drops."));

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: PokeDecorations.card(
        fill: unlocked ? PokeColors.cardWhite : PokeColors.creamSurface,
        border: unlocked ? PokeColors.badgeGold : PokeColors.frameBorderSoft,
        radius: 16,
        borderWidth: 1.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PokeColors.badgeGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: PokeColors.badgeGoldDark.withOpacity(0.5)),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: PokeColors.badgeGoldDark, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "VICTORY ROAD & INDIGO PLATEAU",
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      "Final Four & Championship Challenge",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: unlocked
                      ? PokeColors.badgeGold.withOpacity(0.22)
                      : PokeColors.panelSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: unlocked
                        ? PokeColors.badgeGoldDark
                        : PokeColors.frameBorderSoft,
                  ),
                ),
                child: Text(
                  stateBadge,
                  style: TextStyle(
                    color: unlocked
                        ? PokeColors.badgeGoldDark
                        : PokeColors.inkSubtle,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (unlocked) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SoundService.instance.playUiTap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VictoryRoadScreen()),
                      );
                    },
                    icon: const Icon(Icons.hiking_rounded, size: 17),
                    label: Text(
                      !trainer.victoryRoadCleared
                          ? "ENTER VICTORY ROAD"
                          : (!trainer.isChampion
                              ? "CHALLENGE FINAL FOUR"
                              : "ENTER LV.99 REMATCH"),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PokeColors.leagueIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
                if (trainer.hallOfFameEntries.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      SoundService.instance.playUiTap();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HallOfFameScreen()),
                      );
                    },
                    icon: const Icon(Icons.workspace_premium_rounded, size: 16),
                    label: const Text(
                      "HOF",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PokeColors.badgeGoldDark,
                      side: const BorderSide(color: PokeColors.badgeGoldDark),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  // === GAUNTLET RUNNER & BATTLE LOOP ===
  Future<void> _startGymGauntlet(
      BuildContext context, Trainer trainer, GymDefinition gym) async {
    if (_isLaunchingBattle) return;
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("All Pokémon in your party are fainted! Heal first.")),
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
            trainerIntroLine: currentOpponent.introDialogue,
            trainerDefeatLine: currentOpponent.defeatDialogue,
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
              backgroundColor: PokeColors.creamSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: PokeColors.pokeRed, width: 1.5),
              ),
              title: const Text(
                "GAUNTLET FAILED",
                style: TextStyle(
                    color: PokeColors.pokeRed, fontWeight: FontWeight.w900),
              ),
              content: const Text(
                "Your party was defeated or retreated. In the Gym Gauntlet, you must defeat all 4 Gym Trainers and the Gym Leader in sequence.\n\nHeal up your party and try again!",
                style: TextStyle(color: PokeColors.inkMuted, fontSize: 13),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    if (ModalRoute.of(ctx)?.isCurrent == true) {
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PokeColors.leagueIndigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("OK",
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
    final bool confirmed = await confirmGiveUpGauntletDialog(
      context,
      title: "GIVE UP GAUNTLET?",
      message:
          "Giving up in $gymName will reset your current gauntlet progress (Match $_gauntletIndex of 5 cleared).\n\nYour party's current HP, PP, and status will be preserved.",
    );

    if (confirmed && mounted) {
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
    final Color gymAccentDark = PokeColors.darken(gym.elementColor, 0.16);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isLaunchingBattle) {
          _confirmRetreatFromGauntlet(trainer);
        }
      },
      child: Scaffold(
        backgroundColor: PokeColors.canvasCream,
        appBar: AppBar(
          backgroundColor: gymAccentDark,
          foregroundColor: Colors.white,
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          title: Text(
            "${gym.name.toUpperCase()} CHECKPOINT",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PokeBackdrop(
              assetPath: 'assets/images/bg_pokemon_league.png',
              topOpacity: 0.24,
              midOpacity: 0.50,
              bottomOpacity: 0.88,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkpoint Status Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.creamSurface,
                        border: gymAccentDark,
                        radius: 16,
                        borderWidth: 1.6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: gymAccentDark, size: 18),
                              const SizedBox(width: 7),
                              Text(
                                "MATCH $_gauntletIndex OF 5 CLEARED",
                                style: TextStyle(
                                  color: gymAccentDark,
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
                              color: PokeColors.inkDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "HP, PP, and status do not auto-heal between gauntlet battles. Use Bag items or organize your Pokémon before the next match!",
                            style: TextStyle(
                                color: PokeColors.inkMuted, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Party Status Header
                    const Text(
                      "POKÉMON CONDITION",
                      style: TextStyle(
                        color: PokeColors.inkDark,
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
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: mon.isFainted
                                  ? PokeColors.pokeRed
                                  : PokeColors.frameBorderSoft,
                              radius: 13,
                              borderWidth: 1.4,
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
                                                ? PokeColors.inkSubtle
                                                : PokeColors.inkDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Lv.${mon.level}",
                                          style: const TextStyle(
                                            color: PokeColors.badgeGoldDark,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (mon.status != StatusCondition.none) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: PokeColors.pokeRed
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              mon.status.name.toUpperCase(),
                                              style: const TextStyle(
                                                color: PokeColors.pokeRed,
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
                                            ? PokeColors.pokeRed
                                            : PokeColors.inkMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
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
                                      minHeight: 7,
                                      backgroundColor: PokeColors.panelSoft,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        mon.isFainted
                                            ? Colors.transparent
                                            : (mon.currentHp <= mon.maxHp / 5
                                                ? PokeColors.pokeRed
                                                : (mon.currentHp <= mon.maxHp / 2
                                                    ? PokeColors.badgeGold
                                                    : PokeColors.pokeGreen)),
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

                    // Action Buttons: 4 portrait buttons in a row
                    GauntletCheckpointActionBar(
                      nextBattleColor: gymAccentDark,
                      nextBattleLabel:
                          isLeaderNext ? 'NEXT:\nLEADER' : 'NEXT\nBATTLE',
                      busy: _isLaunchingBattle,
                      onNextBattle: () => _launchNextGauntletBattle(trainer),
                      onBag: () => _openBagModal(context, trainer),
                      onPokemon: () => _openPartyModal(context, trainer),
                      onGiveUp: () => _confirmRetreatFromGauntlet(trainer),
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

  // === BAG & PARTY MODALS AT CHECKPOINT ===
  void _openBagModal(BuildContext context, Trainer trainer) {
    if (_isBagModalOpen || _isLaunchingBattle) return;
    _isBagModalOpen = true;
    showCheckpointBagSheet(
      context,
      trainer,
      onUpdated: () {
        if (mounted) setState(() {});
      },
    ).whenComplete(() {
      _isBagModalOpen = false;
    });
  }

  void _openPartyModal(BuildContext context, Trainer trainer) {
    if (_isBagModalOpen || _isLaunchingBattle) return;
    _isBagModalOpen = true;
    showCheckpointPartySheet(
      context,
      trainer,
      onUpdated: () {
        if (mounted) setState(() {});
      },
    ).whenComplete(() {
      _isBagModalOpen = false;
    });
  }

  // === GAUNTLET VICTORY CELEBRATION ===
  void _onGauntletVictorious(Trainer trainer, GymDefinition gym) {
    final bool firstClear = !trainer.isGymCleared(gym.id);
    if (firstClear) {
      trainer.clearGym(gym.id);
    }
    trainer.resetAllPartyStatStages();
    trainer.saveProgress();

    List<ItemDrop> droppedItems = const [];
    if (!firstClear) {
      final Set<String> ownedTmIds = TmService.allTms
          .where((tm) => trainer.hasTm(tm.id))
          .map((tm) => tm.id)
          .toSet();
      final Set<String> ownedAdventureMapIds = ItemDatabase.adventureMapIds
          .where(trainer.hasAdventureMap)
          .toSet();
      droppedItems = ItemDropService.rollGymRematchDrops(
        gym: gym,
        ownedTmIds: ownedTmIds,
        ownedAdventureMapIds: ownedAdventureMapIds,
      );
      for (final drop in droppedItems) {
        trainer.adjustItemCount(drop.itemId, drop.count);
      }
      trainer.saveProgress();
    }

    HapticFeedback.heavyImpact();
    final Color gymAccentDark = PokeColors.darken(gym.elementColor, 0.16);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: gymAccentDark, width: 1.8),
        ),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: gymAccentDark, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "GAUNTLET CONQUERED!",
                style: TextStyle(
                  color: PokeColors.inkDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You successfully defeated all 4 Gym Trainers and Gym Leader ${gym.leaderName} of ${gym.city}!",
                style: const TextStyle(
                    color: PokeColors.inkMuted, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (firstClear) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.cardWhite,
                    border: gymAccentDark,
                    radius: 12,
                    borderWidth: 1.5,
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
                                color: gymAccentDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gym.badgeDescription,
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (gym.id == 8) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.cardWhite,
                      border: PokeColors.pokeBlue,
                      radius: 12,
                      borderWidth: 1.6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: PokeColors.pokeBlue.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.share_rounded,
                            color: PokeColors.pokeBlueDark,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "KEY ITEM REWARD: EXP SHARE!",
                                style: TextStyle(
                                  color: PokeColors.pokeBlueDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${gym.leaderName} handed over the EXP Share! Enabled automatically — toggle it anytime in Bag (Key & Special) or Trainer Info.",
                                style: const TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else if (droppedItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.cardWhite,
                    border: PokeColors.badgeGold,
                    radius: 12,
                    borderWidth: 1.5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.card_giftcard,
                              color: PokeColors.badgeGoldDark, size: 18),
                          SizedBox(width: 8),
                          Text(
                            "Gym Leader Rematch Rewards",
                            style: TextStyle(
                              color: PokeColors.badgeGoldDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...droppedItems.map((d) {
                        final itemDef = ItemDatabase.byId(d.itemId);
                        final String badgeText = (itemDef?.isTm == true)
                            ? 'REUSABLE'
                            : (itemDef?.isAdventureMap == true
                                ? 'UNLOCKED'
                                : 'x${d.count}');
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                itemDef?.icon ?? Icons.inventory_2_rounded,
                                color: itemDef?.color ??
                                    PokeColors.badgeGoldDark,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  d.itemName,
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              Text(
                                badgeText,
                                style: const TextStyle(
                                  color: PokeColors.badgeGoldDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
              backgroundColor: gymAccentDark,
              foregroundColor: Colors.white,
            ),
            child: const Text("CONTINUE",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
