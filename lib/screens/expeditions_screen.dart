import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_region.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/expedition_database.dart';
import '../services/item_drop_service.dart';
import '../services/sound_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/trainer_sprite.dart';
import 'battle_screen.dart';
import 'double_battle_screen.dart';

class ExpeditionsScreen extends StatelessWidget {
  const ExpeditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final bool unlocked = trainer.isExpeditionsUnlocked;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "EXPEDITIONS",
        barColor: PokeColors.linkTeal,
        bottomBorderColor: PokeColors.linkTealDark,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_expeditions.png',
            topOpacity: 0.22,
            midOpacity: 0.45,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                _buildOverviewBanner(trainer, unlocked),
                const SizedBox(height: 12),
                for (final dest in ExpeditionDatabase.destinationsForRegion(
                  trainer.activeRegion,
                )) ...[
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
    final Color statusColor =
        unlocked ? PokeColors.linkTealDark : PokeColors.pokeRed;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: PokeDecorations.card(
        fill: PokeColors.creamSurface,
        border: statusColor,
        radius: 16,
        borderWidth: 1.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.explore_rounded : Icons.lock_rounded,
                color: statusColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  unlocked
                      ? "HIGH-RISK EXPEDITIONS"
                      : "LOCKED • REQUIRES ALL 8 GYM BADGES (${trainer.clearedGymIds.length}/8)",
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Endure 3 Lv.99 wild battles with zero rest and defeat a Lv.99 ${trainer.activeRegion == GameRegion.johto ? 'Neo Team Rocket' : 'Team Rocket'} ambush deep in uncharted ${trainer.activeRegion.displayName}.",
            style: const TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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
    final Color darkAccent = PokeColors.darken(dest.accentColor, 0.16);
    return Container(
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: unlocked ? darkAccent : PokeColors.frameBorderSoft,
        radius: 18,
        borderWidth: 1.6,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 94,
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
                        Colors.black.withOpacity(0.72),
                        Colors.black.withOpacity(0.28),
                        Colors.black.withOpacity(0.55),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          color: Colors.white.withOpacity(0.9),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dest.description,
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
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
                      backgroundColor: darkAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PokeColors.panelSoft,
                      disabledForegroundColor: PokeColors.inkSubtle,
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
  List<ItemDrop> _rocketDrops = const [];
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
      _rocketChallenger = ExpeditionDatabase.generateRocketChallenger(
        region: trainer.activeRegion,
      );
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
        builder: (_) => rocket.isDoubleBattle
            ? DoubleBattleScreen(
                opponentTeam: rocket.team,
                trainerName: rocket.name,
                trainerTitle: rocket.title,
                trainerIntroLine: rocket.introDialogue,
                trainerDefeatLine: rocket.defeatDialogue,
                opponentSpriteId: rocket.spriteId,
                partnerSpriteId: rocket.partnerSpriteId,
                prizeMoney: rocket.prizeMoney,
                battleBackgroundAsset: widget.destination.backgroundAsset,
                bgmCategory: BattleBgmCategory.expedition,
                continueButtonLabel: "CONTINUE EXPEDITION",
              )
            : BattleScreen(
                opponentPokemon: rocket.team.first,
                opponentTeam: rocket.team,
                isWild: false,
                trainerName: rocket.name,
                trainerTitle: rocket.title,
                trainerIntroLine: rocket.introDialogue,
                trainerDefeatLine: rocket.defeatDialogue,
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

    final rocketDrops = ItemDropService.rollExpeditionRocketDrops(
      isJessieOrJames: rocket.isJessieOrJames,
    );
    for (final drop in rocketDrops) {
      trainer.adjustItemCount(drop.itemId, drop.count);
    }
    trainer.saveProgress();
    _rocketDrops = rocketDrops;

    if (rocket.isJessieOrJames &&
        !trainer.hasEarnedExpeditionMasterBall &&
        Random().nextDouble() < 0.01) {
      trainer.claimExpeditionMasterBall();
      _earnedMasterBall = true;
    }

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

    final bool caughtNow = !alreadyCaughtBefore &&
        trainer.hasCaughtExpeditionSpecies(boss.species.id);
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
        backgroundColor: PokeColors.canvasCream,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PokeBackdrop(
              assetPath: dest.backgroundAsset,
              topOpacity: 0.24,
              midOpacity: 0.48,
              bottomOpacity: 0.88,
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
    final Color darkAccent = PokeColors.darken(dest.accentColor, 0.16);
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
        color: darkAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              dest.name.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
                letterSpacing: 0.7,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stageText,
              style: TextStyle(
                color: darkAccent,
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
      decoration: PokeDecorations.card(
        fill: PokeColors.creamSurface,
        border: PokeColors.frameBorderSoft,
        radius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "PARTY CONDITION (NO REST BETWEEN BATTLES)",
            style: TextStyle(
              color: PokeColors.badgeGoldDark,
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
                              color: mon.isFainted
                                  ? PokeColors.pokeRed
                                  : PokeColors.inkDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          mon.isFainted ? "FNT" : "Lv.${mon.level}",
                          style: const TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    HpBar(
                      currentHp: mon.currentHp,
                      maxHp: mon.maxHp,
                      textColor: PokeColors.inkMuted,
                      hpLabelColor: PokeColors.badgeGoldDark,
                    ),
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
    final Color darkAccent = PokeColors.darken(dest.accentColor, 0.16);
    switch (_phase) {
      case _ExpeditionPhase.arrival:
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: PokeDecorations.card(
                  fill: PokeColors.creamSurface,
                  border: darkAccent,
                  radius: 20,
                  borderWidth: 1.6,
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
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dest.arrivalNarration,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PokeColors.inkMuted,
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
                  backgroundColor: darkAccent,
                  foregroundColor: Colors.white,
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
                decoration: PokeDecorations.card(
                  fill: PokeColors.creamSurface,
                  border: darkAccent,
                  radius: 20,
                  borderWidth: 1.6,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: darkAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Wild Encounter $_wildCompleted of 3 Cleared!",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Another fierce Lv.99 wild Pokémon blocks the path deeper into ${dest.name}. Your team gets no rest!",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PokeColors.inkMuted,
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
                  backgroundColor: darkAccent,
                  foregroundColor: Colors.white,
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
                decoration: PokeDecorations.card(
                  fill: PokeColors.creamSurface,
                  border: PokeColors.pokeRed,
                  radius: 20,
                  borderWidth: 1.8,
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
                        height: 124,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rocket.isDoubleBattle && rocket.partnerSpriteId != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TrainerSpriteWidget(
                            spriteId: rocket.spriteId,
                            size: 86,
                          ),
                          const SizedBox(width: 8),
                          TrainerSpriteWidget(
                            spriteId: rocket.partnerSpriteId!,
                            size: 86,
                          ),
                        ],
                      )
                    else
                      TrainerSpriteWidget(
                        spriteId: rocket.spriteId,
                        size: 96,
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: rocket.isJessieOrJames
                            ? const Color(0xFF7B1FA2)
                            : PokeColors.pokeRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rocket.isJessieOrJames
                            ? (trainer.activeRegion == GameRegion.johto
                                ? "RARE 2v2 DOUBLE BATTLE • ROCKET EXECUTIVES"
                                : "RARE 2v2 DOUBLE BATTLE • TEAM ROCKET DUO")
                            : (trainer.activeRegion == GameRegion.johto
                                ? "NEO TEAM ROCKET AMBUSH!"
                                : "TEAM ROCKET BALLOON DESCENDED!"),
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
                        color: PokeColors.inkMuted,
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rocket.isDoubleBattle
                          ? "Full Party of 6 • Lv. 99 • 2v2 Double Battle"
                          : "Full Party of 6 • Lv. 99",
                      style: const TextStyle(
                        color: PokeColors.badgeGoldDark,
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
                  backgroundColor: PokeColors.pokeRed,
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
        final bool isMythical =
            ExpeditionDatabase.isMythicalExpeditionSpecies(boss.species.id);
        final Color bossColor = isMythical ? PokeColors.centerRose : darkAccent;
        return Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: PokeDecorations.card(
                  fill: PokeColors.creamSurface,
                  border: bossColor,
                  radius: 20,
                  borderWidth: 2.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isMythical
                          ? "MYTHICAL POKÉMON APPEARED!"
                          : "LEGENDARY POKÉMON APPEARED!",
                      style: TextStyle(
                        color: bossColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PokemonSpriteImage.fromInstance(
                      boss,
                      width: 132,
                      height: 132,
                      fallbackIconSize: 72,
                      fallbackIconColor: bossColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Wild ${boss.species.name} • Lv. ${boss.level}",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Poké Balls will be deflected while it can still fight! Knock it out to earn your chance to catch it (calms to Lv. 50 if caught).",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 12,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_rocketDrops.isNotEmpty) ...[
              _buildRocketDropsBanner(),
              const SizedBox(height: 10),
            ],
            if (_earnedMasterBall) ...[
              _buildMasterBallRewardBanner(
                trainer.activeRegion == GameRegion.johto
                    ? "Archer & Ariana"
                    : "Jessie & James",
              ),
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
                  backgroundColor: bossColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        );

      case _ExpeditionPhase.summary:
        final Color summaryColor = _expeditionFailed
            ? PokeColors.pokeRed
            : (_caughtBossThisRun ? PokeColors.badgeGoldDark : darkAccent);
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
              decoration: PokeDecorations.card(
                fill: PokeColors.creamSurface,
                border: summaryColor,
                radius: 20,
                borderWidth: 1.8,
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
                    color: summaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  if (_rocketDrops.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildRocketDropsBanner(),
                  ],
                  if (_earnedMasterBall) ...[
                    const SizedBox(height: 14),
                    _buildMasterBallRewardBanner(
                      trainer.activeRegion == GameRegion.johto
                          ? "Archer & Ariana"
                          : "Jessie & James",
                    ),
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
                  backgroundColor: darkAccent,
                  foregroundColor: Colors.white,
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

  Widget _buildRocketDropsBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.pokeBlue,
        radius: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.backpack_rounded, color: PokeColors.pokeBlue, size: 17),
              SizedBox(width: 7),
              Text(
                "TEAM ROCKET LOOT DROPPED",
                style: TextStyle(
                  color: PokeColors.pokeBlueDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _rocketDrops.map((drop) {
              final itemDef = ItemDatabase.byId(drop.itemId);
              final bool isBall = itemDef?.isBall == true;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: PokeDecorations.inset(
                  radius: 8,
                  border:
                      (itemDef?.color ?? PokeColors.pokeBlue).withOpacity(0.45),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBall)
                      PokeBallSpriteWidget(ballType: drop.itemId, size: 16)
                    else
                      Icon(
                        itemDef?.icon ?? Icons.inventory_2_rounded,
                        color: itemDef?.color ?? PokeColors.inkDark,
                        size: 14,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      "${drop.count}x ${drop.itemName}",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterBallRewardBanner(String sourceDuoName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B1FA2), Color(0xFF4A148C)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
      ),
      child: Row(
        children: [
          const PokeBallSpriteWidget(ballType: 'master_ball', size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "RARE REWARD: MASTER BALL!",
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  "$sourceDuoName dropped your one-time Master Ball!",
                  style: const TextStyle(
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
