import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/expedition_database.dart';
import '../services/sound_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'battle_screen.dart';

class ExpeditionsScreen extends StatelessWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final bool unlocked = trainer.isExpeditionsUnlocked;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0D18),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC090D18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "EXPEDITIONS",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_expeditions.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF080C18).withOpacity(0.58),
                  const Color(0xFF0A0E1B).withOpacity(0.55),
                  const Color(0xFF070A12).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _buildOverviewBanner(trainer, unlocked),
                const SizedBox(height: 12),
                for (final dest in ExpeditionDatabase.destinations) ...[
                  _buildDestinationCard(context, trainer, dest, unlocked),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewBanner(Trainer trainer, bool unlocked) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE8131A2C), Color(0xEC0C101C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (unlocked ? Colors.cyanAccent : Colors.redAccent)
              .withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.explore_rounded : Icons.lock_rounded,
                color: unlocked ? Colors.cyanAccent : Colors.redAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unlocked
                      ? "HIGH-RISK EXPEDITIONS"
                      : "LOCKED • REQUIRES ALL 8 GYM BADGES (${trainer.clearedGymIds.length}/8)",
                  style: TextStyle(
                    color: unlocked ? Colors.cyanAccent : Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Endure 3 Lv.85–90 wild battles with zero rest and defeat a Lv.90 avg Team Rocket ambush deep in uncharted Kanto.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context,
    Trainer trainer,
    ExpeditionDestination dest,
    bool unlocked,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            dest.accentColor.withOpacity(0.18),
            const Color(0xEB101524),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dest.accentColor.withOpacity(unlocked ? 0.55 : 0.2),
          width: 1.3,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  dest.backgroundAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF0A0E1A).withOpacity(0.86),
                        const Color(0xFF0A0E1A).withOpacity(0.35),
                        const Color(0xFF0A0E1A).withOpacity(0.82),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              dest.name.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              dest.subtitle,
                              style: TextStyle(
                                color: dest.accentColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dest.description,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.32,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: !unlocked
                        ? null
                        : () {
                            if (!trainer.hasConsciousPokemon) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Heal your party at the Poké Center before starting an Expedition!"),
                                ),
                              );
                              return;
                            }
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    _ExpeditionRunScreen(destination: dest),
                              ),
                            );
                          },
                    icon: Icon(
                      unlocked ? Icons.flight_takeoff_rounded : Icons.lock,
                      size: 17,
                    ),
                    label: Text(
                      unlocked
                          ? "DEPART TO ${dest.name.toUpperCase()}"
                          : "EARN 8 BADGES TO UNLOCK",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dest.accentColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white38,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ExpeditionPhase {
  arrival,
  wildInterlude,
  rocketBalloon,
  legendaryReveal,
  summary,
}

class _ExpeditionRunScreen extends StatefulWidget {
  final ExpeditionDestination destination;

  const _ExpeditionRunScreen({required this.destination});

  @override
  State<_ExpeditionRunScreen> createState() => _ExpeditionRunScreenState();
}

class _ExpeditionRunScreenState extends State<_ExpeditionRunScreen>
    with SingleTickerProviderStateMixin {
  _ExpeditionPhase _phase = _ExpeditionPhase.arrival;
  int _wildCompleted = 0;
  RocketChallenger? _rocketChallenger;
  PokemonInstance? _bossEncounter;
  bool _earnedMasterBall = false;
  bool _expeditionFailed = false;
  bool _caughtBossThisRun = false;
  bool _bossEscapedThisRun = false;
  bool _busyLaunching = false;

  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _startWildStage(int wildIndex) async {
    if (_busyLaunching) return;
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (!trainer.hasConsciousPokemon) {
      setState(() {
        _expeditionFailed = true;
        _phase = _ExpeditionPhase.summary;
      });
      return;
    }

    setState(() => _busyLaunching = true);
    final wildMon = ExpeditionDatabase.generateWildEncounter(
      widget.destination,
      gameVersion: trainer.gameVersion,
    );
    await precacheImage(
      AssetImage(widget.destination.backgroundAsset),
      context,
    ).catchError((_) {});
    if (!mounted) return;

    final bool? won = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          opponentPokemon: wildMon,
          isWild: true,
          battleBackgroundAsset: widget.destination.backgroundAsset,
          bgmCategory: BattleBgmCategory.expedition,
          continueButtonLabel: wildIndex < 2
              ? "NEXT ENCOUNTER (${wildIndex + 2}/3)"
              : "PRESS FORWARD →",
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busyLaunching = false);

    if (won != true || !trainer.hasConsciousPokemon) {
      setState(() {
        _expeditionFailed = true;
        _phase = _ExpeditionPhase.summary;
      });
      return;
    }

    _wildCompleted = wildIndex + 1;
    if (_wildCompleted < 3) {
      setState(() {
        _phase = _ExpeditionPhase.wildInterlude;
      });
    } else {
      _rocketChallenger = ExpeditionDatabase.generateRocketChallenger();
      setState(() {
        _phase = _ExpeditionPhase.rocketBalloon;
      });
    }
  }

  Future<void> _startRocketBattle() async {
    if (_busyLaunching || _rocketChallenger == null) return;
    final trainer = Provider.of<Trainer>(context, listen: false);
    final rocket = _rocketChallenger!;
    if (!trainer.hasConsciousPokemon) {
      setState(() {
        _expeditionFailed = true;
        _phase = _ExpeditionPhase.summary;
      });
      return;
    }

    setState(() => _busyLaunching = true);
    final bool? won = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          opponentPokemon: rocket.team.first,
          opponentTeam: rocket.team,
          isWild: false,
          trainerName: rocket.name,
          trainerTitle: rocket.title,
          opponentSpriteId: rocket.spriteId,
          prizeMoney: rocket.prizeMoney,
          battleBackgroundAsset: widget.destination.backgroundAsset,
          bgmCategory: BattleBgmCategory.expedition,
          continueButtonLabel: "CONTINUE EXPEDITION",
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busyLaunching = false);

    if (won != true || !trainer.hasConsciousPokemon) {
      setState(() {
        _expeditionFailed = true;
        _phase = _ExpeditionPhase.summary;
      });
      return;
    }

    // 1% one-time Master Ball reward when defeating Jessie or James
    if (rocket.isJessieOrJames &&
        !trainer.hasEarnedExpeditionMasterBall &&
        Random().nextDouble() < 0.01) {
      trainer.claimExpeditionMasterBall();
      _earnedMasterBall = true;
    }

    // Roll 0.01% Mew or 5% Location Legendary
    final boss = ExpeditionDatabase.rollPostRocketBoss(
      destination: widget.destination,
      trainer: trainer,
    );

    if (boss != null) {
      setState(() {
        _bossEncounter = boss;
        _phase = _ExpeditionPhase.legendaryReveal;
      });
    } else {
      setState(() {
        _phase = _ExpeditionPhase.summary;
      });
    }
  }

  Future<void> _startBossBattle() async {
    if (_busyLaunching || _bossEncounter == null) return;
    final trainer = Provider.of<Trainer>(context, listen: false);
    final boss = _bossEncounter!;
    final bool alreadyCaughtBefore =
        trainer.hasCaughtExpeditionSpecies(boss.species.id);

    setState(() => _busyLaunching = true);
    final bool? won = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          opponentPokemon: boss,
          isWild: true,
          isLegendaryBoss: true,
          battleBackgroundAsset: widget.destination.backgroundAsset,
          bgmCategory: BattleBgmCategory.special,
          continueButtonLabel: "FINISH EXPEDITION",
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busyLaunching = false);

    final bool caughtNow =
        !alreadyCaughtBefore && trainer.hasCaughtExpeditionSpecies(boss.species.id);
    setState(() {
      _caughtBossThisRun = caughtNow;
      _bossEscapedThisRun = !caughtNow && won == true;
      _expeditionFailed = won != true || !trainer.hasConsciousPokemon;
      _phase = _ExpeditionPhase.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final dest = widget.destination;

    return PopScope(
      canPop: _phase == _ExpeditionPhase.summary,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D18),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              dest.backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF090D18).withOpacity(0.68),
                    const Color(0xFF0A0E1B).withOpacity(0.75),
                    const Color(0xFF070A12).withOpacity(0.94),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTopStepHeader(dest),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _buildPhaseBody(trainer, dest),
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

  Widget _buildTopStepHeader(ExpeditionDestination dest) {
    final String stageText;
    switch (_phase) {
      case _ExpeditionPhase.arrival:
        stageText = "ARRIVAL";
        break;
      case _ExpeditionPhase.wildInterlude:
        stageText = "WILD GAUNTLET ($_wildCompleted/3 CLEARED)";
        break;
      case _ExpeditionPhase.rocketBalloon:
        stageText = "TEAM ROCKET AMBUSH";
        break;
      case _ExpeditionPhase.legendaryReveal:
        stageText = "ANOMALY DETECTED";
        break;
      case _ExpeditionPhase.summary:
        stageText = "EXPEDITION REPORT";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xE0101626),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dest.accentColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dest.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
              letterSpacing: 0.7,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: dest.accentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dest.accentColor.withOpacity(0.65)),
            ),
            child: Text(
              stageText,
              style: TextStyle(
                color: dest.accentColor,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyStatusStrip(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE00C111E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PARTY CONDITION (NO REST BETWEEN BATTLES)",
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: trainer.party.map((mon) {
              return SizedBox(
                width: 145,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            mon.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  mon.isFainted ? Colors.redAccent : Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          mon.isFainted ? "FNT" : "Lv.${mon.level}",
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBody(Trainer trainer, ExpeditionDestination dest) {
    switch (_phase) {
      case _ExpeditionPhase.arrival:
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xE0111626),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dest.accentColor.withOpacity(0.45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        dest.backgroundAsset,
                        height: 155,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Arriving at ${dest.name}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dest.arrivalNarration,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPartyStatusStrip(trainer),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busyLaunching ? null : () => _startWildStage(0),
                icon: const Icon(Icons.bolt_rounded),
                label: const Text(
                  "VENTURE INTO THE WILDS (1/3)",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dest.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );

      case _ExpeditionPhase.wildInterlude:
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xE0111626),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: dest.accentColor.withOpacity(0.45)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: dest.accentColor, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Wild Encounter $_wildCompleted of 3 Cleared!",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Another fierce Lv.85–90 wild Pokémon blocks the path deeper into ${dest.name}. Your team gets no rest!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPartyStatusStrip(trainer),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busyLaunching
                    ? null
                    : () => _startWildStage(_wildCompleted),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dest.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "BATTLE WILD POKÉMON (${_wildCompleted + 1}/3)",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ],
        );

      case _ExpeditionPhase.rocketBalloon:
        final rocket = _rocketChallenger!;
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xE8171122),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _floatController,
                      builder: (_, child) => Transform.translate(
                        offset: Offset(
                          0,
                          -sin(_floatController.value * pi) * 8,
                        ),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/images/rocket_balloon.png',
                        height: 128,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TrainerSpriteWidget(
                      spriteId: rocket.spriteId,
                      size: 98,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: rocket.isJessieOrJames
                            ? Colors.purpleAccent.withOpacity(0.25)
                            : Colors.red.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: rocket.isJessieOrJames
                              ? Colors.purpleAccent
                              : Colors.redAccent,
                        ),
                      ),
                      child: Text(
                        rocket.isJessieOrJames
                            ? "RARE ENCOUNTER: ${rocket.name.toUpperCase()} (TEAM ROCKET)"
                            : "TEAM ROCKET BALLOON DESCENDED!",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "\"${rocket.introDialogue}\"",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Full Party of 6 • Average Lv. 90",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildPartyStatusStrip(trainer),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busyLaunching ? null : _startRocketBattle,
                icon: const Icon(Icons.sports_martial_arts_rounded),
                label: Text(
                  "CHALLENGE ${rocket.name.toUpperCase()}!",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );

      case _ExpeditionPhase.legendaryReveal:
        final boss = _bossEncounter!;
        final bool isMew = boss.species.id == ExpeditionDatabase.mewSpeciesId;
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      (isMew ? Colors.pinkAccent : dest.accentColor)
                          .withOpacity(0.28),
                      const Color(0xEC0E1322),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isMew ? Colors.pinkAccent : dest.accentColor,
                    width: 1.6,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMew
                          ? "MYTHICAL POKÉMON APPEARED!"
                          : "LEGENDARY POKÉMON APPEARED!",
                      style: TextStyle(
                        color: isMew ? Colors.pinkAccent : Colors.amberAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Image.network(
                      boss.spriteUrl,
                      width: 132,
                      height: 132,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, __, ___) => Image.network(
                        boss.staticSpriteUrl,
                        width: 120,
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Wild ${boss.species.name} • Lv. ${boss.level}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Poké Balls will be deflected while it can still fight! Knock it out to earn your chance to catch it (calms to Lv. 50 if caught).",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_earnedMasterBall) ...[
              _buildMasterBallRewardBanner(),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _busyLaunching ? null : _startBossBattle,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  "BATTLE WILD ${boss.species.name.toUpperCase()}!",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMew ? Colors.pinkAccent : dest.accentColor,
                  foregroundColor: isMew ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );

      case _ExpeditionPhase.summary:
        final String headline = _expeditionFailed
            ? "Expedition Failed!"
            : _caughtBossThisRun
                ? "${_bossEncounter!.species.name} Caught!"
                : _bossEscapedThisRun
                    ? "${_bossEncounter!.species.name} Escaped!"
                    : "Expedition Complete!";
        final String body = _expeditionFailed
            ? "Your party could not continue through ${dest.name}. Visit the Poké Center and prepare for another Expedition!"
            : _caughtBossThisRun
                ? "Incredible victory! You subdued ${_bossEncounter!.species.name} and added it to your collection at Lv. 50."
                : _bossEscapedThisRun
                    ? "You defeated ${_bossEncounter!.species.name}, though it fled before staying in the ball. It can still reappear on future Expeditions!"
                    : "You cleared all 3 wild battles and drove off Team Rocket's ${_rocketChallenger?.name ?? 'raiders'}! The area fell quiet.";

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xEB111626),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _expeditionFailed
                      ? Colors.redAccent
                      : (_caughtBossThisRun
                          ? Colors.amberAccent
                          : dest.accentColor),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _expeditionFailed
                        ? Icons.close_rounded
                        : (_caughtBossThisRun
                            ? Icons.workspace_premium_rounded
                            : Icons.verified_rounded),
                    size: 52,
                    color: _expeditionFailed
                        ? Colors.redAccent
                        : (_caughtBossThisRun
                            ? Colors.amberAccent
                            : dest.accentColor),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (_earnedMasterBall) ...[
                    const SizedBox(height: 14),
                    _buildMasterBallRewardBanner(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: dest.accentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "RETURN TO EXPEDITIONS",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildMasterBallRewardBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withOpacity(0.85),
            Colors.deepPurple.shade900.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purpleAccent),
      ),
      child: const Row(
        children: [
          PokeBallSpriteWidget(ballType: 'master_ball', size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "RARE REWARD: MASTER BALL!",
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  "Jessie & James dropped your one-time Master Ball!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
