import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/adventure_database.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/gauntlet_checkpoint_sheets.dart';
import '../widgets/poke_theme.dart';
import '../widgets/type_badge.dart';
import 'battle_screen.dart';

class AdventureScreen extends StatelessWidget {
  const AdventureScreen({super.key});

  Future<void> _startAdventure(
    BuildContext context,
    Trainer trainer, {
    AdventureBiome? biome,
  }) async {
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All Pokémon in your party have fainted! Visit the Pokémon Center to heal your party.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    SoundService.instance.playUiTap();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AdventureRunScreen(biome: biome),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final unlockedBiomes = AdventureDatabase.biomes
        .where((b) => trainer.hasAdventureMap(b.mapItemId))
        .toList();
    final lockedBiomes = AdventureDatabase.biomes
        .where((b) => !trainer.hasAdventureMap(b.mapItemId))
        .toList();

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: 'GO ON AN ADVENTURE',
        barColor: PokeColors.pokeGreen,
        bottomBorderColor: PokeColors.pokeGreenDark,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/battle_bg_route.png',
            topOpacity: 0.24,
            midOpacity: 0.48,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.creamSurface,
                    border: PokeColors.pokeGreen,
                    radius: 16,
                    borderWidth: 1.6,
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.explore_rounded,
                        color: PokeColors.pokeGreenDark,
                        size: 26,
                      ),
                      SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Face a 5-wild-Pokémon gauntlet with rest checkpoints between battles. Unlock Biomes with Adventure Maps from Gym Leader rematches to target specific types!',
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            height: 1.38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Always-unlocked Random Adventure card
                _buildRandomAdventureCard(context, trainer),
                const SizedBox(height: 18),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.creamSurface.withOpacity(0.95),
                    border: PokeColors.badgeGold,
                    radius: 11,
                    borderWidth: 1.3,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_rounded,
                          color: PokeColors.badgeGoldDark, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'BIOME ADVENTURES (${unlockedBiomes.length}/${AdventureDatabase.biomes.length} UNLOCKED)',
                        style: const TextStyle(
                          color: PokeColors.badgeGoldDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                for (final biome in unlockedBiomes) ...[
                  _buildBiomeCard(
                    context,
                    trainer,
                    biome: biome,
                    unlocked: true,
                  ),
                  const SizedBox(height: 10),
                ],
                for (final biome in lockedBiomes) ...[
                  _buildBiomeCard(
                    context,
                    trainer,
                    biome: biome,
                    unlocked: false,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRandomAdventureCard(BuildContext context, Trainer trainer) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.pokeGreen,
        radius: 18,
        borderWidth: 1.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: PokeColors.pokeGreen.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: PokeColors.pokeGreen.withOpacity(0.55),
                  ),
                ),
                child: const Icon(
                  Icons.shuffle_rounded,
                  color: PokeColors.pokeGreenDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RANDOM ADVENTURE',
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '5 Random Wild Encounters • Rest Between Battles',
                      style: TextStyle(
                        color: PokeColors.pokeGreenDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'Encounter 5 wild Pokémon across all habitats using standard wild encounter rates.',
            style: TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startAdventure(context, trainer),
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text(
                'START RANDOM ADVENTURE',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.6),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.pokeGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomeCard(
    BuildContext context,
    Trainer trainer, {
    required AdventureBiome biome,
    required bool unlocked,
  }) {
    final Color darkAccent = PokeColors.darken(biome.accentColor, 0.16);
    return Opacity(
      opacity: unlocked ? 1.0 : 0.82,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: PokeDecorations.card(
          fill: unlocked ? PokeColors.cardWhite : PokeColors.creamSurface,
          border: unlocked ? biome.accentColor : PokeColors.frameBorderSoft,
          radius: 16,
          borderWidth: unlocked ? 1.6 : 1.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? biome.accentColor.withOpacity(0.15)
                        : PokeColors.panelSoft,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: unlocked
                          ? biome.accentColor.withOpacity(0.6)
                          : PokeColors.frameBorderSoft,
                    ),
                  ),
                  child: Icon(
                    unlocked ? biome.icon : Icons.lock_rounded,
                    color: unlocked ? darkAccent : PokeColors.inkSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        biome.name.toUpperCase(),
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        biome.subtitle,
                        style: const TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: biome.types.map((t) => TypeBadge(type: t)).toList(),
            ),
            const SizedBox(height: 11),
            if (unlocked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _startAdventure(context, trainer, biome: biome),
                  icon: Icon(biome.icon, size: 17),
                  label: Text(
                    'ENTER ${biome.name.toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: PokeDecorations.inset(
                  radius: 10,
                  border: PokeColors.badgeGold.withOpacity(0.55),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      color: PokeColors.badgeGoldDark,
                      size: 15,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Locked • Rematch ${biome.sourceGymName} for its Adventure Map',
                        style: const TextStyle(
                          color: PokeColors.badgeGoldDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdventureRunScreen extends StatefulWidget {
  final AdventureBiome? biome;

  const _AdventureRunScreen({this.biome});

  @override
  State<_AdventureRunScreen> createState() => _AdventureRunScreenState();
}

enum _AdventurePhase {
  checkpoint,
  summary,
}

class _AdventureRunScreenState extends State<_AdventureRunScreen> {
  static const int totalEncounters = 5;

  _AdventurePhase _phase = _AdventurePhase.checkpoint;
  int _encountersCompleted = 0;
  bool _failed = false;
  bool _gaveUp = false;
  bool _busyLaunching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _encountersCompleted == 0) {
        _launchNextEncounter();
      }
    });
  }

  Color get _accentColor =>
      widget.biome?.accentColor ?? PokeColors.pokeGreen;

  Color get _accentDark => PokeColors.darken(_accentColor, 0.16);

  String get _title =>
      widget.biome?.name.toUpperCase() ?? 'RANDOM ADVENTURE';

  Future<void> _launchNextEncounter() async {
    if (_busyLaunching) return;
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (!trainer.hasConsciousPokemon) {
      setState(() {
        _failed = true;
        _phase = _AdventurePhase.summary;
      });
      return;
    }

    setState(() => _busyLaunching = true);
    try {
      final int playerLevel = trainer.leadPokemon?.level ?? 5;
      final PokemonInstance wildMon = PokedexDatabase.generateAdventureEncounter(
        playerLevel: playerLevel,
        gameVersion: trainer.gameVersion,
        region: trainer.activeRegion,
        allowedTypes: widget.biome?.typeSet,
      );
      final String bgAsset =
          widget.biome?.backgroundAsset ?? wildMon.species.battleBackgroundAsset;

      await precacheImage(AssetImage(bgAsset), context).catchError((_) {});
      if (!mounted) return;

      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => BattleScreen(
            opponentPokemon: wildMon,
            isWild: true,
            preservePartyHpOnExit: true,
            battleBackgroundAsset: bgAsset,
            bgmCategory: BattleBgmCategory.wild,
            continueButtonLabel: _encountersCompleted + 1 < totalEncounters
                ? 'REST CHECKPOINT (${_encountersCompleted + 1}/$totalEncounters)'
                : 'FINISH ADVENTURE',
            defeatButtonLabel: 'LEAVE ADVENTURE',
          ),
        ),
      );
      if (!mounted) return;

      if (!trainer.hasConsciousPokemon) {
        trainer.resetAllPartyStatStages();
        trainer.saveProgress();
        setState(() {
          _busyLaunching = false;
          _failed = true;
          _phase = _AdventurePhase.summary;
        });
        return;
      }

      setState(() {
        _busyLaunching = false;
        _encountersCompleted++;
        if (_encountersCompleted >= totalEncounters) {
          trainer.resetAllPartyStatStages();
          trainer.saveProgress();
          _phase = _AdventurePhase.summary;
          HapticFeedback.heavyImpact();
        } else {
          _phase = _AdventurePhase.checkpoint;
        }
      });
    } finally {
      if (mounted && _busyLaunching) {
        setState(() => _busyLaunching = false);
      }
    }
  }

  Future<void> _confirmGiveUp(Trainer trainer) async {
    if (_busyLaunching) return;
    final bool confirmed = await confirmGiveUpGauntletDialog(
      context,
      title: 'GIVE UP ADVENTURE?',
      message:
          'Giving up will end your current $_title run ($_encountersCompleted of $totalEncounters encounters cleared).\n\nYour party condition and any caught Pokémon or drops will be kept.',
    );
    if (confirmed && mounted) {
      trainer.resetAllPartyStatStages();
      trainer.saveProgress();
      setState(() {
        _gaveUp = true;
        _phase = _AdventurePhase.summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final String bgAsset =
        widget.biome?.backgroundAsset ?? 'assets/images/battle_bg_route.png';

    return PopScope(
      canPop: _phase == _AdventurePhase.summary,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _phase == _AdventurePhase.checkpoint && !_busyLaunching) {
          _confirmGiveUp(trainer);
        }
      },
      child: Scaffold(
        backgroundColor: PokeColors.canvasCream,
        appBar: AppBar(
          backgroundColor: _accentDark,
          foregroundColor: Colors.white,
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
            _phase == _AdventurePhase.checkpoint
                ? '$_title CHECKPOINT'
                : _title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            PokeBackdrop(
              assetPath: bgAsset,
              topOpacity: 0.24,
              midOpacity: 0.50,
              bottomOpacity: 0.88,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _phase == _AdventurePhase.summary
                    ? _buildSummaryView()
                    : _buildCheckpointView(trainer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckpointView(Trainer trainer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: _accentDark,
            radius: 16,
            borderWidth: 1.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: _accentDark, size: 18),
                  const SizedBox(width: 7),
                  Text(
                    'ENCOUNTER $_encountersCompleted OF $totalEncounters CLEARED',
                    style: TextStyle(
                      color: _accentDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _encountersCompleted == 0
                    ? 'Preparing first wild encounter...'
                    : 'NEXT: WILD ENCOUNTER #${_encountersCompleted + 1} OF $totalEncounters',
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rest checkpoint: heal up with Bag items or reorganize your party before continuing.',
                style: TextStyle(color: PokeColors.inkMuted, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'POKÉMON CONDITION',
          style: TextStyle(
            color: PokeColors.inkDark,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: trainer.party.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, idx) {
              final mon = trainer.party[idx];
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              'Lv.${mon.level}',
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
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: PokeColors.pokeRed.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(4),
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
                          'HP: ${mon.currentHp} / ${mon.maxHp}',
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
                          value: (mon.currentHp / mon.maxHp).clamp(0.0, 1.0),
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
        GauntletCheckpointActionBar(
          nextBattleColor: _accentDark,
          nextBattleLabel: 'NEXT BATTLE',
          busy: _busyLaunching,
          onNextBattle: _launchNextEncounter,
          onBag: () => showCheckpointBagSheet(
            context,
            trainer,
            onUpdated: () {
              if (mounted) setState(() {});
            },
          ),
          onPokemon: () => showCheckpointPartySheet(
            context,
            trainer,
            onUpdated: () {
              if (mounted) setState(() {});
            },
          ),
          onGiveUp: () => _confirmGiveUp(trainer),
        ),
      ],
    );
  }

  Widget _buildSummaryView() {
    final Color outcomeColor = _failed
        ? PokeColors.pokeRed
        : (_gaveUp ? PokeColors.bagOrange : _accentDark);
    final String headline = _failed
        ? 'Adventure Ended'
        : _gaveUp
            ? 'Adventure Left Early'
            : 'Adventure Complete!';
    final String body = _failed
        ? 'All of your Pokémon fainted during $_title ($_encountersCompleted of $totalEncounters encounters completed). Visit the Pokémon Center to heal up!'
        : _gaveUp
            ? 'You stepped back from $_title after $_encountersCompleted of $totalEncounters encounters.'
            : 'You completed all $totalEncounters wild encounters in $_title!';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: outcomeColor,
            radius: 20,
            borderWidth: 1.8,
          ),
          child: Column(
            children: [
              Icon(
                _failed
                    ? Icons.close_rounded
                    : (_gaveUp
                        ? Icons.flag_rounded
                        : Icons.workspace_premium_rounded),
                size: 52,
                color: outcomeColor,
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
              backgroundColor: _accentDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'RETURN TO ADVENTURES',
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
