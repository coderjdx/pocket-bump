import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/trainer.dart';
import '../services/elite_four_database.dart';
import '../services/gym_database.dart';
import '../services/item_drop_service.dart';
import '../services/sound_service.dart';
import '../widgets/gauntlet_checkpoint_sheets.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_head_portrait.dart';
import '../widgets/trainer_sprite.dart';
import 'battle_screen.dart';
import 'double_battle_screen.dart';
import 'hall_of_fame_screen.dart';

enum _VictoryRoadMode {
  firstAscent,
  eliteFourAndChampion,
  masterRematch,
}

class VictoryRoadScreen extends StatefulWidget {
  const VictoryRoadScreen({super.key});

  @override
  State<VictoryRoadScreen> createState() => _VictoryRoadScreenState();
}

class _VictoryRoadScreenState extends State<VictoryRoadScreen> {
  _VictoryRoadMode? _activeMode;
  List<VictoryRoadStage> _activeStages = const [];
  int _stageIndex = 0;
  bool _inCheckpoint = false;
  bool _busyLaunching = false;
  bool _isBagModalOpen = false;

  _VictoryRoadMode _currentModeForTrainer(Trainer trainer) {
    if (!trainer.victoryRoadCleared) {
      return _VictoryRoadMode.firstAscent;
    }
    if (!trainer.isChampion) {
      return _VictoryRoadMode.eliteFourAndChampion;
    }
    return _VictoryRoadMode.masterRematch;
  }

  Future<void> _startRun(Trainer trainer) async {
    if (_busyLaunching) return;
    if (!trainer.isVictoryRoadUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Victory Road requires all 8 Gym Badges (${trainer.clearedGymIds.length}/8 earned)."),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "All Pokémon in your party have fainted! Heal at the Pokémon Center first."),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final mode = _currentModeForTrainer(trainer);
    late final List<VictoryRoadStage> stages;
    switch (mode) {
      case _VictoryRoadMode.firstAscent:
        stages = EliteFourDatabase.buildFirstAscentStages();
        break;
      case _VictoryRoadMode.eliteFourAndChampion:
        final bosses =
            EliteFourDatabase.buildEliteFourAndChampionStages(trainer);
        stages = [
          for (int i = 0; i < bosses.length; i++)
            VictoryRoadStage.trainer(
              stageNumber: i + 1,
              trainer: bosses[i],
              backgroundAsset: bosses[i].backgroundAsset,
              bgmCategory: bosses[i].bgmCategory,
              customLabel: '${bosses[i].roleLabel}: ${bosses[i].name}',
            ),
        ];
        break;
      case _VictoryRoadMode.masterRematch:
        stages = EliteFourDatabase.buildMasterRematchStages(trainer);
        break;
    }

    setState(() {
      _activeMode = mode;
      _activeStages = stages;
      _stageIndex = 0;
      _inCheckpoint = false;
    });

    await _launchCurrentStage(trainer);
  }

  Future<void> _launchCurrentStage(Trainer trainer) async {
    if (_busyLaunching || _activeMode == null) return;
    if (_stageIndex >= _activeStages.length) {
      await _onRunCompleted(trainer);
      return;
    }
    if (!trainer.hasConsciousPokemon) {
      _abortRunOnDefeat(trainer);
      return;
    }

    final stage = _activeStages[_stageIndex];
    setState(() => _busyLaunching = true);

    try {
      await precacheImage(AssetImage(stage.backgroundAsset), context)
          .catchError((_) {});
      if (!mounted) return;

      final bool isLast = _stageIndex + 1 >= _activeStages.length;
      final String continueLabel = isLast
          ? (_activeMode == _VictoryRoadMode.eliteFourAndChampion
              ? 'ENTER HALL OF FAME'
              : 'COMPLETE CHALLENGE')
          : 'REST CHECKPOINT (${_stageIndex + 1}/${_activeStages.length})';

      bool won = false;
      if (stage.isWild) {
        final wildMon = EliteFourDatabase.rollWildVictoryRoadPokemon(
          level: stage.wildLevel ?? 85,
          gameVersion: trainer.gameVersion,
        );
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => BattleScreen(
              opponentPokemon: wildMon,
              isWild: true,
              preservePartyHpOnExit: true,
              battleBackgroundAsset: stage.backgroundAsset,
              bgmCategory: stage.bgmCategory,
              continueButtonLabel: continueLabel,
              defeatButtonLabel: 'LEAVE VICTORY ROAD',
            ),
          ),
        );
        if (!mounted) return;
        won = trainer.hasConsciousPokemon;
      } else {
        final GymTrainer opponent = stage.trainer!;
        final team = opponent.team
            .map((spec) => spec.createInstance(hiddenAbilityChance: 0.08))
            .toList();
        final bool? trainerWon = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => stage.isDoubleBattle
                ? DoubleBattleScreen(
                    opponentTeam: team,
                    trainerName: opponent.name,
                    trainerTitle: opponent.title,
                    trainerIntroLine: opponent.introDialogue,
                    trainerDefeatLine: opponent.defeatDialogue,
                    opponentSpriteId: opponent.spriteId,
                    partnerSpriteId: stage.partnerSpriteId,
                    prizeMoney: opponent.prizeMoney,
                    preservePartyHpOnExit: true,
                    battleBackgroundAsset: stage.backgroundAsset,
                    bgmCategory: stage.bgmCategory,
                    continueButtonLabel: continueLabel,
                    defeatButtonLabel: 'LEAVE CHALLENGE',
                  )
                : BattleScreen(
                    opponentPokemon: team.first,
                    opponentTeam: team,
                    isWild: false,
                    trainerName: opponent.name,
                    trainerTitle: opponent.title,
                    trainerIntroLine: opponent.introDialogue,
                    trainerDefeatLine: opponent.defeatDialogue,
                    opponentSpriteId: opponent.spriteId,
                    prizeMoney: opponent.prizeMoney,
                    preservePartyHpOnExit: true,
                    battleBackgroundAsset: stage.backgroundAsset,
                    bgmCategory: stage.bgmCategory,
                    continueButtonLabel: continueLabel,
                    defeatButtonLabel: 'LEAVE CHALLENGE',
                  ),
          ),
        );
        if (!mounted) return;
        won = trainerWon == true && trainer.hasConsciousPokemon;
      }

      if (!won) {
        _abortRunOnDefeat(trainer);
        return;
      }

      setState(() {
        _busyLaunching = false;
        _stageIndex++;
      });

      if (_stageIndex >= _activeStages.length) {
        _inCheckpoint = false;
        await _onRunCompleted(trainer);
      } else {
        setState(() => _inCheckpoint = true);
      }
    } finally {
      if (mounted && _busyLaunching) {
        setState(() => _busyLaunching = false);
      }
    }
  }

  void _abortRunOnDefeat(Trainer trainer) {
    trainer.resetAllPartyStatStages();
    trainer.saveProgress();
    final mode = _activeMode;
    setState(() {
      _busyLaunching = false;
      _inCheckpoint = false;
      _activeMode = null;
      _activeStages = const [];
      _stageIndex = 0;
    });
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PokeColors.pokeRed, width: 1.6),
        ),
        title: const Row(
          children: [
            Icon(Icons.healing_rounded, color: PokeColors.pokeRed),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "Challenge Ended",
                style: TextStyle(
                  color: PokeColors.pokeRedDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          mode == _VictoryRoadMode.eliteFourAndChampion
              ? "Your party fainted inside Indigo Plateau! Heal up at the Pokémon Center and challenge the Final Four again from Room 1."
              : "Your party fainted on Victory Road! Visit the Pokémon Center before trying again.",
          style: const TextStyle(
            color: PokeColors.inkMuted,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.pokeRed,
              foregroundColor: Colors.white,
            ),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Future<void> _onRunCompleted(Trainer trainer) async {
    final mode = _activeMode;
    final stages = _activeStages;
    trainer.resetAllPartyStatStages();
    HapticFeedback.heavyImpact();

    setState(() {
      _busyLaunching = false;
      _inCheckpoint = false;
      _activeMode = null;
      _activeStages = const [];
      _stageIndex = 0;
    });

    if (mode == _VictoryRoadMode.firstAscent) {
      trainer.markVictoryRoadCleared();
      const ascentRewards = [
        ItemDrop(
          itemId: 'full_restore',
          itemName: 'Full Restore',
          count: 2,
          rarity: PokemonRarity.rare,
        ),
        ItemDrop(
          itemId: 'max_revive',
          itemName: 'Max Revive',
          count: 2,
          rarity: PokemonRarity.rare,
        ),
        ItemDrop(
          itemId: 'rare_candy',
          itemName: 'Rare Candy',
          count: 1,
          rarity: PokemonRarity.rare,
        ),
      ];
      for (final d in ascentRewards) {
        trainer.adjustItemCount(d.itemId, d.count);
      }
      await trainer.saveProgress();
      if (!mounted) return;

      SoundService.instance.playVictoryFanfare(isTrainer: true);
      await showDialog<void>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: PokeColors.badgeGoldDark, width: 1.8),
          ),
          title: const Row(
            children: [
              Icon(Icons.landscape_rounded,
                  color: PokeColors.bagOrangeDark, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "VICTORY ROAD CLEARED!",
                  style: TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You fought your way through the mountain gauntlet and reached the gates of Indigo Plateau!\n\nThe Final Four and Championship Battle are now unlocked!",
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _rewardBundleBox("VICTORY ROAD CLEAR BONUS", ascentRewards),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.leagueIndigo,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "TO INDIGO PLATEAU",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (mode == _VictoryRoadMode.eliteFourAndChampion) {
      final rewards =
          EliteFourDatabase.buildChampionFirstClearRewards(trainer: trainer);
      for (final d in rewards) {
        trainer.adjustItemCount(d.itemId, d.count);
      }
      trainer.recordChampionVictory();
      await trainer.saveProgress();
      if (!mounted) return;

      SoundService.instance.playVictoryFanfare(isTrainer: true);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: PokeColors.badgeGoldDark, width: 2.0),
          ),
          title: const Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: PokeColors.badgeGoldDark, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "NEW KANTO CHAMPION!",
                  style: TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "You defeated all four Elite Trainers and toppled Champion Blue in one unstoppable run!\n\nLvl. 99 Victory Road Master Rematches are now unlocked.",
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _rewardBundleBox("CHAMPIONSHIP PRIZE REWARDS", rewards),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dlgCtx),
              icon: const Icon(Icons.workspace_premium_rounded, size: 18),
              label: const Text(
                "ENTER HALL OF FAME",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.badgeGoldDark,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const HallOfFameScreen(isNewInduction: true),
        ),
      );
      return;
    }

    if (mode == _VictoryRoadMode.masterRematch) {
      final finalStage = stages.isNotEmpty ? stages.last : null;
      final LeagueBossTrainer? boss = finalStage?.trainer is LeagueBossTrainer
          ? finalStage!.trainer as LeagueBossTrainer
          : null;
      final List<ItemDrop> drops = boss != null
          ? EliteFourDatabase.rollLeagueBossRematchDrops(
              boss: boss,
              trainer: trainer,
            )
          : const [];
      for (final d in drops) {
        trainer.adjustItemCount(d.itemId, d.count);
      }
      await trainer.saveProgress();
      if (!mounted) return;

      SoundService.instance.playVictoryFanfare(isTrainer: true);
      await showDialog<void>(
        context: context,
        builder: (dlgCtx) => AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: boss?.accentColor ?? PokeColors.badgeGoldDark,
              width: 1.8,
            ),
          ),
          title: Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: PokeColors.badgeGoldDark, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  boss != null
                      ? "${boss.name.toUpperCase()} DEFEATED!"
                      : "VICTORY ROAD COMPLETE!",
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                boss != null
                    ? "You conquered the Lv. 99 Victory Road gauntlet and defeated ${boss.name} (${boss.title})!"
                    : "You conquered the Lv. 99 Victory Road Master Rematch gauntlet!",
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              if (drops.isNotEmpty) ...[
                const SizedBox(height: 12),
                _rewardBundleBox(
                  boss != null
                      ? "${boss.name.toUpperCase()}'S EXCLUSIVE DROPS"
                      : "REMATCH REWARDS",
                  drops,
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.leagueIndigo,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                "AWESOME!",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _rewardBundleBox(String heading, List<ItemDrop> drops) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: PokeDecorations.inset(
        fill: PokeColors.cardWhite,
        border: PokeColors.badgeGold,
        radius: 11,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              color: PokeColors.badgeGoldDark,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          for (final drop in drops)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded,
                      size: 13, color: PokeColors.badgeGoldDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${drop.count}x ${drop.itemName}",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
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

  Future<void> _confirmGiveUp(Trainer trainer) async {
    if (_busyLaunching) return;
    final bool confirmed = await confirmGiveUpGauntletDialog(
      context,
      title: _activeMode == _VictoryRoadMode.eliteFourAndChampion
          ? "LEAVE INDIGO PLATEAU?"
          : "LEAVE VICTORY ROAD?",
      message:
          "Giving up now resets your current run ($_stageIndex/${_activeStages.length} battles cleared). Your party's current condition, EXP, and any caught Pokémon stay saved.",
    );
    if (confirmed && mounted) {
      trainer.resetAllPartyStatStages();
      trainer.saveProgress();
      setState(() {
        _inCheckpoint = false;
        _activeMode = null;
        _activeStages = const [];
        _stageIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);

    if (_inCheckpoint && _activeMode != null) {
      return _buildCheckpointScaffold(trainer);
    }

    final mode = _currentModeForTrainer(trainer);
    final bool unlocked = trainer.isVictoryRoadUnlocked;
    final Color barColor = mode == _VictoryRoadMode.eliteFourAndChampion
        ? PokeColors.leagueIndigo
        : (mode == _VictoryRoadMode.masterRematch
            ? PokeColors.bagOrangeDark
            : PokeColors.pokeRed);
    final String bgAsset = mode == _VictoryRoadMode.eliteFourAndChampion
        ? 'assets/images/bg_pokemon_league.png'
        : EliteFourDatabase.victoryRoadBgAsset;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: mode == _VictoryRoadMode.eliteFourAndChampion
            ? "INDIGO PLATEAU"
            : "VICTORY ROAD",
        barColor: barColor,
        bottomBorderColor: PokeColors.darken(barColor, 0.2),
        actions: [
          if (trainer.hallOfFameEntries.isNotEmpty)
            IconButton(
              tooltip: "Hall of Fame",
              onPressed: () {
                SoundService.instance.playUiTap();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HallOfFameScreen()),
                );
              },
              icon: const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 22),
            ),
        ],
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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                _buildStateProgressionStepper(trainer),
                const SizedBox(height: 12),
                if (!unlocked)
                  _buildLockedCard(trainer)
                else if (mode == _VictoryRoadMode.firstAscent)
                  _buildFirstAscentCard(trainer)
                else if (mode == _VictoryRoadMode.eliteFourAndChampion)
                  _buildEliteFourCard(trainer)
                else
                  _buildMasterRematchCard(trainer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateProgressionStepper(Trainer trainer) {
    final bool step1Done = trainer.victoryRoadCleared;
    final bool step2Done = trainer.isChampion;
    final bool unlocked = trainer.isVictoryRoadUnlocked;

    Widget chip(String title, String sub, bool active, bool done) {
      final Color col = done
          ? PokeColors.pokeGreenDark
          : (active ? PokeColors.badgeGoldDark : PokeColors.inkSubtle);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: PokeDecorations.card(
            fill: done
                ? const Color(0xFFE8F5E9)
                : (active ? const Color(0xFFFFF8E1) : PokeColors.cardWhite),
            border: col,
            radius: 11,
            borderWidth: active || done ? 1.6 : 1.1,
          ),
          child: Column(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : (active ? Icons.bolt_rounded : Icons.lock_outline_rounded),
                size: 16,
                color: col,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: col,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: PokeDecorations.card(
        fill: PokeColors.creamSurface.withOpacity(0.95),
        border: PokeColors.frameBorderSoft,
        radius: 16,
      ),
      child: Row(
        children: [
          chip(
            "1. ASCENT",
            "Lv.85–90",
            unlocked && !step1Done,
            step1Done,
          ),
          const SizedBox(width: 6),
          chip(
            "2. FINAL FOUR",
            "Lv.88–98",
            unlocked && step1Done && !step2Done,
            step2Done,
          ),
          const SizedBox(width: 6),
          chip(
            "3. REMATCH",
            "Lv.99 Boss",
            unlocked && step1Done && step2Done,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildLockedCard(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: PokeDecorations.card(
        fill: PokeColors.creamSurface,
        border: PokeColors.pokeRed,
        radius: 18,
        borderWidth: 1.8,
      ),
      child: Column(
        children: [
          const Icon(Icons.lock_rounded, size: 42, color: PokeColors.pokeRed),
          const SizedBox(height: 10),
          const Text(
            "BADGE CHECK GATE",
            style: TextStyle(
              color: PokeColors.inkDark,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Earn all 8 Kanto Gym Badges to enter Victory Road and challenge the Final Four.\n\nCurrent Progress: ${trainer.clearedGymIds.length}/8 Badges",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstAscentCard(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.bagOrangeDark,
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
                  color: PokeColors.bagOrange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PokeColors.bagOrangeDark),
                ),
                child: const Icon(Icons.terrain_rounded,
                    color: PokeColors.bagOrangeDark, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STATE 1 • FIRST ASCENT",
                      style: TextStyle(
                        color: PokeColors.bagOrangeDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      "Victory Road Cavern Trial",
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Conquer the 6-stage mountain trial alternating catchable wild Pokémon and veteran League gatekeepers (Lv. 85–90). Rest checkpoints with Bag and Party access open between every fight.",
            style: TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11.5,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 10),
          _stagePatternBanner(const [
            "1. Wild Lv.85",
            "2. Ace Naomi",
            "3. Wild Lv.86",
            "4. Black Belt",
            "5. Wild Lv.88",
            "6. Veteran Marcus",
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busyLaunching ? null : () => _startRun(trainer),
              icon: const Icon(Icons.hiking_rounded, size: 19),
              label: const Text(
                "CLIMB VICTORY ROAD",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.7,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.bagOrangeDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEliteFourCard(Trainer trainer) {
    final bosses = EliteFourDatabase.buildEliteFourAndChampionStages(trainer);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.leagueIndigo,
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
                  color: PokeColors.leagueIndigo.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PokeColors.leagueIndigo),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: PokeColors.leagueIndigo, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STATE 2 • INDIGO PLATEAU",
                      style: TextStyle(
                        color: PokeColors.leagueIndigo,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      "Final Four & Champion Battle",
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Defeat all 4 Elite Masters and the Indigo Champion in one continuous run (Lv. 88–98). No Poké Center heals are allowed between chambers—bring plenty of Full Restores and Revives!",
            style: TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11.5,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < bosses.length; i++) ...[
            _buildChamberPreviewTile(
              index: i + 1,
              boss: bosses[i],
              isMysteryChampion: i == bosses.length - 1,
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: PokeDecorations.inset(
              fill: const Color(0xFFFFF8E1),
              border: PokeColors.badgeGold,
              radius: 10,
            ),
            child: const Row(
              children: [
                Icon(Icons.album_rounded,
                    size: 16, color: PokeColors.badgeGoldDark),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    "First-Clear Prize: ₽30,000 + TM51 Giga Impact + 3x Heart Scales + Rare Candies & Hall of Fame Induction",
                    style: TextStyle(
                      color: PokeColors.badgeGoldDark,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busyLaunching ? null : () => _startRun(trainer),
              icon: const Icon(Icons.military_tech_rounded, size: 19),
              label: const Text(
                "CHALLENGE FINAL FOUR",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.7,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.leagueIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChamberPreviewTile({
    required int index,
    required LeagueBossTrainer boss,
    bool isMysteryChampion = false,
  }) {
    final color = isMysteryChampion ? PokeColors.badgeGoldDark : boss.accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: PokeDecorations.inset(
        fill: PokeColors.creamSurface,
        border: color.withOpacity(0.55),
        radius: 11,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PokeColors.cardWhite,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: color),
            ),
            child: isMysteryChampion
                ? Icon(Icons.help_outline_rounded, color: color, size: 20)
                : TrainerSpriteWidget(spriteId: boss.spriteId, size: 32),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMysteryChampion
                      ? "$index. ??? • CHAMPIONSHIP THRONE"
                      : "$index. ${boss.name.toUpperCase()} • ${boss.chamberName}",
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isMysteryChampion
                      ? "Mystery Champion • Lv.94–98 Team"
                      : "${boss.title} • 6 Pokémon",
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterRematchCard(Trainer trainer) {
    final pool = EliteFourDatabase.buildRematchLeagueBossPool(trainer);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.badgeGoldDark,
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
                  color: PokeColors.badgeGold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PokeColors.badgeGoldDark),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: PokeColors.badgeGoldDark, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STATE 3 • CHAMPION REMATCH",
                      style: TextStyle(
                        color: PokeColors.badgeGoldDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    Text(
                      "Victory Road Lv.99 Gauntlet",
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            "Alternate 6 intense Lv. 99 battles (Wild → Master 2v2 Doubles → Wild → Master 2v2 Doubles → Wild → 1v1 Random Final Four or Blue). The final boss drops their signature exclusive Held Item & Rare TM!",
            style: TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 11.5,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 10),
          _stagePatternBanner(const [
            "1. Wild Lv.99",
            "2. Master 2v2",
            "3. Wild Lv.99",
            "4. Master 2v2",
            "5. Wild Lv.99",
            "6. Final 4 / Blue (1v1)",
          ]),
          const SizedBox(height: 12),
          const Text(
            "RANDOM FINAL BOSS & EXCLUSIVE DROPS",
            style: TextStyle(
              color: PokeColors.inkDark,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          for (final boss in pool) ...[
            _buildExclusiveDropRow(boss, trainer),
            const SizedBox(height: 5),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _busyLaunching ? null : () => _startRun(trainer),
              icon: const Icon(Icons.flash_on_rounded, size: 19),
              label: const Text(
                "START LV.99 VICTORY ROAD",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.7,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.badgeGoldDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExclusiveDropRow(LeagueBossTrainer boss, Trainer trainer) {
    final heldName =
        ItemDatabase.byId(boss.exclusiveHeldItemId)?.name ?? boss.exclusiveHeldItemId;
    final tmName = ItemDatabase.byId(boss.exclusiveTmId)?.name ?? boss.exclusiveTmId;
    final bool hasTm = trainer.hasTm(boss.exclusiveTmId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: PokeDecorations.inset(
        fill: PokeColors.creamSurface,
        border: boss.accentColor.withOpacity(0.5),
        radius: 10,
      ),
      child: Row(
        children: [
          TrainerSpriteWidget(spriteId: boss.spriteId, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  boss.name,
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "$heldName + ${hasTm ? '$tmName (Owned)' : tmName}",
                  style: TextStyle(
                    color: PokeColors.darken(boss.accentColor, 0.2),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePatternBanner(List<String> steps) {
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (int i = 0; i < steps.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: i.isEven
                  ? PokeColors.pokeGreen.withOpacity(0.12)
                  : PokeColors.pokeRed.withOpacity(0.11),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: i.isEven
                    ? PokeColors.pokeGreen.withOpacity(0.55)
                    : PokeColors.pokeRed.withOpacity(0.55),
              ),
            ),
            child: Text(
              steps[i],
              style: TextStyle(
                color: i.isEven ? PokeColors.pokeGreenDark : PokeColors.pokeRedDark,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckpointScaffold(Trainer trainer) {
    final stage = _stageIndex < _activeStages.length
        ? _activeStages[_stageIndex]
        : null;
    final String title = _activeMode == _VictoryRoadMode.eliteFourAndChampion
        ? "INDIGO CHECKPOINT"
        : "VICTORY ROAD CHECKPOINT";
    final Color barColor = _activeMode == _VictoryRoadMode.eliteFourAndChampion
        ? PokeColors.leagueIndigo
        : PokeColors.bagOrangeDark;
    final String bgAsset =
        stage?.backgroundAsset ?? EliteFourDatabase.victoryRoadBgAsset;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busyLaunching && !_isBagModalOpen) {
          _confirmGiveUp(trainer);
        }
      },
      child: Scaffold(
        backgroundColor: PokeColors.canvasCream,
        appBar: AppBar(
          backgroundColor: barColor,
          foregroundColor: Colors.white,
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Text(
            title,
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
              topOpacity: 0.25,
              midOpacity: 0.52,
              bottomOpacity: 0.88,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.creamSurface,
                        border: barColor,
                        radius: 16,
                        borderWidth: 1.6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "STAGE $_stageIndex OF ${_activeStages.length} CLEARED",
                            style: TextStyle(
                              color: barColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stage != null
                                ? "NEXT: ${stage.label.toUpperCase()}"
                                : "FINALIZING...",
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            "Rest checkpoint: heal with Bag items or reorganize your party before the next match.",
                            style: TextStyle(
                              color: PokeColors.inkMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "POKÉMON CONDITION",
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Expanded(
                      child: ListView.separated(
                        itemCount: trainer.party.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (_, idx) {
                          final mon = trainer.party[idx];
                          final statusColor =
                              statusConditionBadgeColor(mon.status);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: mon.isFainted
                                  ? PokeColors.pokeRed
                                  : PokeColors.frameBorderSoft,
                              radius: 13,
                            ),
                            child: Row(
                              children: [
                                PokemonHeadPortrait(pokemon: mon, size: 38),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              mon.nickname,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: PokeColors.inkDark,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                              ),
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
                                          if (mon.isFainted ||
                                              mon.status !=
                                                  StatusCondition.none) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: mon.isFainted
                                                    ? PokeColors.pokeRed
                                                    : statusColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                mon.isFainted
                                                    ? "FNT"
                                                    : mon.status.shortLabel,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: mon.hpPercent,
                                                minHeight: 6,
                                                backgroundColor:
                                                    PokeColors.panelSoft,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  mon.hpPercent > 0.5
                                                      ? PokeColors.pokeGreen
                                                      : (mon.hpPercent > 0.2
                                                          ? PokeColors.badgeGold
                                                          : PokeColors.pokeRed),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "${mon.currentHp}/${mon.maxHp}",
                                            style: const TextStyle(
                                              color: PokeColors.inkMuted,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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
                      nextBattleColor: barColor,
                      nextBattleLabel: "NEXT BATTLE",
                      busy: _busyLaunching,
                      onNextBattle: () => _launchCurrentStage(trainer),
                      onBag: () async {
                        if (_busyLaunching || _isBagModalOpen) return;
                        _isBagModalOpen = true;
                        await showCheckpointBagSheet(
                          context,
                          trainer,
                          onUpdated: () {
                            if (mounted) setState(() {});
                          },
                        );
                        _isBagModalOpen = false;
                      },
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
