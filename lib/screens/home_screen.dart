import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_version.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/app_update_service.dart';
import '../services/gym_database.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../services/step_counter_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/sound_controls.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/version_picker.dart';
import 'adventure_screen.dart';
import 'bag_screen.dart';
import 'battle_screen.dart';
import 'bump_screen.dart';
import 'expeditions_screen.dart';
import 'move_tutor_screen.dart';
import 'mystery_gift_screen.dart';
import 'pc_storage_screen.dart';
import 'poke_mart_screen.dart';
import 'pokedex_screen.dart';
import 'pokemon_center_screen.dart';
import 'pokemon_detail_screen.dart';
import 'pokemon_league_screen.dart';
import 'rivals_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _leadBobController;

  @override
  void initState() {
    super.initState();
    SoundService.instance.playBgm(BgmTrack.hubTown);
    _leadBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _promptVersionChoiceIfNeeded();
      if (!mounted) return;
      await _initStepCounterSync();
      if (!mounted) return;
      await _checkAppUpdate();
    });
  }

  Future<void> _initStepCounterSync() async {
    await StepCounterService.initialize(
      getCurrentDailySteps: () {
        if (!mounted) return 0;
        return Provider.of<Trainer>(context, listen: false).todaySteps;
      },
      onStepDelta: (diff, {required bool isLiveStep}) {
        if (!mounted || diff <= 0) return;
        final trainer = Provider.of<Trainer>(context, listen: false);
        final bool onHomeTopRoute = ModalRoute.of(context)?.isCurrent == true;
        final triggered = trainer.recordStepsAndCheckEncounter(
          diff,
          allowEncounter: isLiveStep && onHomeTopRoute,
        );
        if (triggered && onHomeTopRoute && trainer.gameVersion != null) {
          StepCounterService.triggerEncounterAlert();
          _launchWildEncounter();
        }
      },
      requestPermissions: true,
    );
  }

  Future<void> _handleManualStepSync() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Phone step counter sync is available in the Android APK app."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final res = await StepCounterService.syncNow(
      requestPermissions: true,
      openSettingsIfDenied: true,
      forceSensorRefresh: true,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _promptVersionChoiceIfNeeded() async {
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (trainer.gameVersion != null) return;
    await showVersionMigrationDialog(context, trainer);
  }

  Future<void> _checkAppUpdate() async {
    final update = await AppUpdateService.checkForUpdate();
    if (!mounted || update == null) return;

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.amberAccent.withOpacity(0.45)),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded,
                color: Colors.amberAccent, size: 22),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                "Update Available!",
                style: TextStyle(
                  color: Colors.white,
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
              "A new version of Pocket Bump (${update.latestVersion}) is available on GitHub.",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Installed: v${update.currentVersion}",
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "Latest: ${update.latestVersion}",
                    style: const TextStyle(
                        color: Color(0xFF34EB8C),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppUpdateService.skipVersion(update.latestVersion);
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
            },
            child: const Text("Skip", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Later", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final uri = Uri.tryParse(update.downloadUrl);
              Navigator.pop(dlgCtx);
              bool opened = false;
              if (uri != null) {
                try {
                  opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {}
              }
              if (!opened) {
                await Clipboard.setData(ClipboardData(text: update.downloadUrl));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Copied APK download link to clipboard!"),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text(
              "Download",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _leadBobController.dispose();
    super.dispose();
  }

  Future<void> _launchWildEncounter() async {
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "All Pokémon in your party have fainted! Visit the Pokémon Center to heal your party."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (trainer.gameVersion == null) {
      await _promptVersionChoiceIfNeeded();
      if (!mounted || trainer.gameVersion == null) return;
    }
    trainer.resetEncounterSteps();
    final playerLevel = trainer.leadPokemon?.level ?? 5;
    final wildMon = PokedexDatabase.generateWildEncounter(
      playerLevel: playerLevel,
      gameVersion: trainer.gameVersion,
    );
    await precacheImage(
      AssetImage(wildMon.species.battleBackgroundAsset),
      context,
    ).catchError((_) {});
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BattleScreen(opponentPokemon: wildMon, isWild: true),
      ),
    );
  }

  Future<void> _launchAdventure(Trainer trainer) async {
    if (!trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "All Pokémon in your party have fainted! Visit the Pokémon Center to heal your party."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (trainer.gameVersion == null) {
      await _promptVersionChoiceIfNeeded();
      if (!mounted || trainer.gameVersion == null) return;
    }
    SoundService.instance.playUiTap();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdventureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final PokemonInstance? leadPokemon =
        trainer.party.isNotEmpty ? trainer.party.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0E111B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.38, 0.76, 1.0],
                colors: [
                  const Color(0xFF0A0D16).withOpacity(0.72),
                  const Color(0xFF0F1320).withOpacity(0.24),
                  const Color(0xFF0C101B).withOpacity(0.62),
                  const Color(0xFF090B12).withOpacity(0.90),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopHudBar(trainer),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildTrainerHeroCard(trainer, leadPokemon),
                  ),
                  const SizedBox(height: 12),
                  _buildMainCommandGrid(trainer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. COMPACT TOP HUD BAR ───────────────────────────────────────────────
  Widget _buildTopHudBar(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE6121726),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4C597D).withOpacity(0.55),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.catching_pokemon,
              color: Color(0xFFFF5252), size: 18),
          const SizedBox(width: 7),
          const Text(
            "POCKET BUMP",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.0,
            ),
          ),
          if (trainer.gameVersion != null) ...[
            const SizedBox(width: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    trainer.gameVersion!.primaryColor,
                    trainer.gameVersion!.secondaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                trainer.gameVersion!.shortLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
          const Spacer(),
          ValueListenableBuilder<StepSyncState>(
            valueListenable: StepCounterService.syncState,
            builder: (context, sync, _) {
              final Color pillColor;
              final IconData pillIcon;
              switch (sync.status) {
                case StepSyncStatus.syncedHealthAndSensor:
                case StepSyncStatus.syncedHealthOnly:
                  pillColor = Colors.greenAccent;
                  pillIcon = Icons.sync_rounded;
                  break;
                case StepSyncStatus.syncedSensorOnly:
                  pillColor = Colors.cyanAccent;
                  pillIcon = Icons.sensors_rounded;
                  break;
                case StepSyncStatus.syncing:
                  pillColor = Colors.amberAccent;
                  pillIcon = Icons.sync_rounded;
                  break;
                case StepSyncStatus.needsPermission:
                  pillColor = Colors.amberAccent;
                  pillIcon = Icons.touch_app_rounded;
                  break;
                case StepSyncStatus.webPreview:
                case StepSyncStatus.unavailable:
                  pillColor = Colors.white54;
                  pillIcon = Icons.sensors_off_rounded;
                  break;
              }
              return Tooltip(
                message: sync.detail,
                child: InkWell(
                  onTap: _handleManualStepSync,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: pillColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: pillColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(pillIcon, size: 11, color: pillColor),
                        const SizedBox(width: 4),
                        Text(
                          sync.label,
                          style: TextStyle(
                            color: pillColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D16),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "₽",
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const SoundToggleButton(size: 14),
        ],
      ),
    );
  }

  // ─── 2. HERO TRAINER PORTRAIT + BASIC INFO + LEAD STAGE ───────────────────
  Widget _buildTrainerHeroCard(Trainer trainer, PokemonInstance? lead) {
    final Color accentColor =
        lead != null ? lead.species.types.first.color : Colors.cyanAccent;
    final int prevLvlExp = lead != null
        ? (lead.level - 1) * (lead.level - 1) * (lead.level - 1)
        : 0;
    final int nextLvlExp = lead != null ? lead.expForNextLevel : 1;
    final double expProgress = (lead != null && nextLvlExp > prevLvlExp)
        ? ((lead.currentExp - prevLvlExp) / (nextLvlExp - prevLvlExp))
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xCC0D1220),
            accentColor.withOpacity(0.14),
            const Color(0xEC0E1322),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accentColor.withOpacity(0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          children: [
            // Trainer Identity Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.shade700,
                        Colors.red.shade900,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    trainer.avatar.title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 9,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trainer.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.9,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    SoundService.instance.playUiTap();
                    _openTrainerInfoSheet(trainer);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      "OBEY Lv.${trainer.maxObedienceLevel}",
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Scenic Trainer Portrait + Lead Partner Stage
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 4,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          gradient: RadialGradient(
                            radius: 2.3,
                            colors: [
                              accentColor.withOpacity(0.32),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            SoundService.instance.playUiTap();
                            _openTrainerInfoSheet(trainer);
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TrainerSpriteWidget(
                                avatar: trainer.avatar,
                                isBackView: false,
                                size: 112,
                              ),
                              Container(
                                width: 66,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.48),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        if (lead != null)
                          Builder(builder: (_) {
                            final double companionSize =
                                (lead.species.homeCompanionSize * 1.1)
                                    .clamp(56.0, 124.0);
                            final double shadowWidth =
                                (companionSize * 0.72).clamp(36.0, 88.0);
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _leadBobController,
                                  builder: (context, child) {
                                    final dy =
                                        -sin(_leadBobController.value * pi) *
                                            4.0;
                                    return Transform.translate(
                                      offset: Offset(0, dy),
                                      child: child,
                                    );
                                  },
                                  child: GestureDetector(
                                    onTap: () => SoundService.instance
                                        .playPokemonCry(lead.species.id),
                                    child: Opacity(
                                      opacity: lead.isFainted ? 0.5 : 1.0,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Image.network(
                                            lead.spriteUrl,
                                            width: companionSize * 1.38,
                                            height: companionSize,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.bottomCenter,
                                            filterQuality: FilterQuality.none,
                                            errorBuilder: (c, e, s) =>
                                                Image.network(
                                              lead.staticSpriteUrl,
                                              width: companionSize * 1.38,
                                              height: companionSize,
                                              fit: BoxFit.contain,
                                              alignment: Alignment.bottomCenter,
                                              filterQuality: FilterQuality.none,
                                              errorBuilder: (c2, e2, s2) =>
                                                  Icon(
                                                Icons.catching_pokemon,
                                                color: accentColor,
                                                size: (companionSize * 0.62)
                                                    .clamp(32.0, 64.0),
                                              ),
                                            ),
                                          ),
                                          if (lead.isShiny)
                                            Positioned(
                                              top: 0,
                                              right: -2,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xCC151824),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.amberAccent
                                                        .withOpacity(0.8),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.auto_awesome_rounded,
                                                  color: Colors.amberAccent,
                                                  size: 13,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: shadowWidth,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.48),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ],
                            );
                          }),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 4 Basic Info Stats Row (Badges, Pokédex, Steps Today, Party)
            Row(
              children: [
                _buildInfoStatChip(
                  icon: Icons.stars_rounded,
                  color: const Color(0xFFFFD54F),
                  label: "BADGES",
                  value: "${trainer.clearedGymIds.length}/8",
                ),
                const SizedBox(width: 6),
                _buildInfoStatChip(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFFF5252),
                  label: "POKÉDEX",
                  value:
                      "${trainer.caughtCount}/${PokedexDatabase.gen1TotalSpecies}",
                ),
                const SizedBox(width: 6),
                _buildInfoStatChip(
                  icon: Icons.directions_walk_rounded,
                  color: Colors.cyanAccent,
                  label: "STEPS",
                  value: "${trainer.todaySteps}",
                ),
                const SizedBox(width: 6),
                _buildInfoStatChip(
                  icon: Icons.catching_pokemon,
                  color: const Color(0xFF34EB8C),
                  label: "PARTY",
                  value: "${trainer.party.length}/6",
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Lead Partner Nameplate & Party Status Dots
            if (lead != null)
              InkWell(
                onTap: () {
                  SoundService.instance.playUiTap();
                  _openPartyManagerModal(trainer);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
                  decoration: BoxDecoration(
                    color: const Color(0xEA0C101C),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor.withOpacity(0.38)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          PokeBallSpriteWidget(
                              ballType: lead.caughtBall, size: 15),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              lead.nickname,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Lv.${lead.level}",
                            style: const TextStyle(
                              color: Color(0xFFFFD54F),
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                            ),
                          ),
                          if (lead.status != StatusCondition.none) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purpleAccent.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                lead.status.shortLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(6, (i) {
                              if (i >= trainer.party.length) {
                                return Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(left: 3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                );
                              }
                              final p = trainer.party[i];
                              final dotColor = p.isFainted
                                  ? Colors.redAccent
                                  : (p.hpPercent <= 0.25
                                      ? Colors.orangeAccent
                                      : const Color(0xFF34EB8C));
                              return Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(left: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dotColor,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            "HP",
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: HpBar(
                              currentHp: lead.currentHp,
                              maxHp: lead.maxHp,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${lead.currentHp}/${lead.maxHp}",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            "EXP",
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: expProgress,
                                minHeight: 3.5,
                                backgroundColor: Colors.black54,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.lightBlueAccent,
                                ),
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

  Widget _buildInfoStatChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xE00C101C),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(0.32)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 11, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. FOUR MAIN COMMAND BUTTONS (2x2 GRID) ───────────────────────────────
  Widget _buildMainCommandGrid(Trainer trainer) {
    final badges = trainer.clearedGymIds.length;
    return Column(
      children: [
        Row(
          children: [
            _buildPrimaryActionTile(
              title: "BATTLE",
              subtitle: "Adventures • Gyms • Expeditions",
              icon: Icons.flash_on_rounded,
              gradStart: const Color(0xFFD32F2F),
              gradEnd: const Color(0xFF7F1D1D),
              accent: const Color(0xFFFFD54F),
              onTap: () {
                SoundService.instance.playUiTap();
                _openBattleMenuSheet(trainer);
              },
            ),
            const SizedBox(width: 10),
            _buildPrimaryActionTile(
              title: "FACILITIES",
              subtitle: "Center • Mart • Lab • Tutor",
              icon: Icons.local_hospital_rounded,
              gradStart: const Color(0xFFAD1457),
              gradEnd: const Color(0xFF4A148C),
              accent: const Color(0xFFF48FB1),
              onTap: () {
                SoundService.instance.playUiTap();
                _openFacilitiesMenuSheet(trainer);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildPrimaryActionTile(
              title: "TRAINER",
              subtitle: "Info • Pokémon • Bag • Pokédex",
              icon: Icons.badge_rounded,
              gradStart: const Color(0xFF1565C0),
              gradEnd: const Color(0xFF0D254C),
              accent: Colors.cyanAccent,
              badgeText: "$badges/8",
              onTap: () {
                SoundService.instance.playUiTap();
                _openTrainerMenuSheet(trainer);
              },
            ),
            const SizedBox(width: 10),
            _buildPrimaryActionTile(
              title: "FISTBUMP LINK",
              subtitle: "PvP • Trade • Rivals",
              icon: Icons.sports_mma_rounded,
              gradStart: const Color(0xFFE65100),
              gradEnd: const Color(0xFF6A1B09),
              accent: Colors.amberAccent,
              onTap: () {
                SoundService.instance.playUiTap();
                _openLinkMenuSheet(trainer);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrimaryActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color gradStart,
    required Color gradEnd,
    required Color accent,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return Expanded(
      child: SizedBox(
        height: 82,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradStart, gradEnd],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: accent.withOpacity(0.65),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: gradEnd.withOpacity(0.55),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.26),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(icon, color: accent, size: 19),
                      ),
                      const Spacer(),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      else
                        Icon(Icons.chevron_right_rounded,
                            color: accent.withOpacity(0.9), size: 20),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.84),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 4. CATEGORY SUBMENUS (BATTLE / FACILITIES / TRAINER / LINK) ──────────
  Widget _buildMenuOptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? leadingOverride,
    bool locked = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2033),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: locked ? Colors.white12 : color.withOpacity(0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (locked ? Colors.white24 : color).withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: leadingOverride ??
                      Icon(
                        locked ? Icons.lock_rounded : icon,
                        color: locked ? Colors.white38 : color,
                        size: 22,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: locked ? Colors.white60 : Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: locked ? Colors.white38 : Colors.white60,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: locked ? Colors.white24 : color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBattleMenuSheet(Trainer trainer) {
    final badges = trainer.clearedGymIds.length;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on_rounded,
                      color: Color(0xFFFFD54F), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "BATTLE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.explore_rounded,
                color: const Color(0xFF34EB8C),
                title: "Adventures",
                subtitle: "5-battle wild & Biome gauntlets with rest between stages",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  _launchAdventure(trainer);
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.military_tech_rounded,
                color: const Color(0xFFFFD54F),
                title: "Gym Battles",
                subtitle: "$badges/8 Kanto Badges earned • Gyms & Leader rematches",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                        builder: (_) => const PokemonLeagueScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.terrain_rounded,
                color: Colors.cyanAccent,
                locked: !trainer.isExpeditionsUnlocked,
                title: "Expeditions",
                subtitle: trainer.isExpeditionsUnlocked
                    ? "4 Lv. 99 Kanto Sites • Team Rocket & Rare Legendaries"
                    : "Locked • Earn all 8 Gym Badges to unlock ($badges/8)",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  if (trainer.isExpeditionsUnlocked) {
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                          builder: (_) => const ExpeditionsScreen()),
                    );
                  } else {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Expeditions unlock after earning all 8 Gym Badges! ($badges/8 earned)"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFacilitiesMenuSheet(Trainer trainer) {
    final fossils = trainer.getItemCount('unknown_fossil');
    final vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final heartScales = trainer.getItemCount('heart_scale');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_hospital_rounded,
                      color: Colors.pinkAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "FACILITIES",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.local_hospital_rounded,
                color: Colors.pinkAccent,
                title: "Pokémon Center",
                subtitle: "Nurse Joy • Restore HP, PP, and status ailments",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(
                        builder: (_) => const PokemonCenterScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.storefront_rounded,
                color: const Color(0xFF42A5F5),
                title: "Poké Mart",
                subtitle: "Buy Poké Balls, Medicine & Stones • Balance: ₽${trainer.money}",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (_) => const PokeMartScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.science_rounded,
                color: Colors.amberAccent,
                title: "Pokémon Lab",
                subtitle: "Restore Fossils • $fossils Fossils, $vouchers Vouchers",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (_) => const PokemonLabScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.favorite_rounded,
                color: const Color(0xFFFF6B9D),
                title: "Move Tutor",
                subtitle: "Teach Egg Moves • $heartScales Heart Scale${heartScales == 1 ? '' : 's'}",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (_) => const MoveTutorScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTrainerMenuSheet(Trainer trainer) {
    final int caught = trainer.caughtCount;
    const int totalSpecies = PokedexDatabase.gen1TotalSpecies;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.badge_rounded,
                        color: Colors.cyanAccent, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      "TRAINER",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildMenuOptionCard(
                  icon: Icons.person_pin_rounded,
                  color: Colors.cyanAccent,
                  title: "Trainer Info",
                  subtitle: "${trainer.name} • ${trainer.clearedGymIds.length}/8 Badges • ${trainer.totalSteps} Total Steps",
                  onTap: () {
                    SoundService.instance.playUiTap();
                    Navigator.pop(ctx);
                    _openTrainerInfoSheet(trainer);
                  },
                ),
                const SizedBox(height: 10),
                _buildMenuOptionCard(
                  icon: Icons.catching_pokemon,
                  color: Colors.redAccent,
                  title: "Pokémon",
                  subtitle: "Party (${trainer.party.length}/6) & PC Boxes (${trainer.totalPcPokemon}/${trainer.maxPcCapacity})",
                  onTap: () {
                    SoundService.instance.playUiTap();
                    Navigator.pop(ctx);
                    _openPartyManagerModal(trainer);
                  },
                ),
                const SizedBox(height: 10),
                _buildMenuOptionCard(
                  icon: Icons.backpack_rounded,
                  color: Colors.amberAccent,
                  title: "Bag",
                  subtitle: "${trainer.totalItems} items • Organized by Medicine, Balls, Berries, TMs & Key",
                  onTap: () {
                    SoundService.instance.playUiTap();
                    Navigator.pop(ctx);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (_) => const BagScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildMenuOptionCard(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFFF5252),
                  leadingOverride: const PokeBallSymbol(size: 22, isCaught: true),
                  title: "Pokédex",
                  subtitle: "$caught/$totalSpecies Kanto Pokédex Caught",
                  onTap: () {
                    SoundService.instance.playUiTap();
                    Navigator.pop(ctx);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(builder: (_) => const PokedexScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildMenuOptionCard(
                  icon: Icons.card_giftcard_rounded,
                  color: Colors.pinkAccent,
                  title: "Mystery Gift",
                  subtitle: "Event Distributions & 16-Character Gift Codes",
                  onTap: () {
                    SoundService.instance.playUiTap();
                    Navigator.pop(ctx);
                    Navigator.push(
                      this.context,
                      MaterialPageRoute(
                          builder: (_) => const MysteryGiftScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLinkMenuSheet(Trainer trainer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sports_mma_rounded,
                      color: Colors.amberAccent, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "FISTBUMP LINK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.sports_mma_rounded,
                color: Colors.deepOrangeAccent,
                title: "Battle or Trade Link",
                subtitle: "Connect nearby for live PvP battles or Pokémon trades",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (_) => const BumpScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuOptionCard(
                icon: Icons.people_alt_rounded,
                color: Colors.cyanAccent,
                title: "Rivals & Friends",
                subtitle: "${trainer.rivals.length} Rivals recorded • ${trainer.friendCount} ★ Friends",
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(ctx);
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (_) => const RivalsScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTrainerInfoSheet(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<Trainer>(
        builder: (context, trainer, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded,
                            color: Colors.cyanAccent, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          "TRAINER CARD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1B233A), Color(0xFF131828)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          TrainerSpriteWidget(
                            avatar: trainer.avatar,
                            isBackView: false,
                            size: 84,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trainer.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                Text(
                                  trainer.avatar.title,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Money: ₽${trainer.money} • Obey Lv.${trainer.maxObedienceLevel}",
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Today: ${trainer.todaySteps} steps • Total: ${trainer.totalSteps}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "KANTO GYM BADGES",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: GymDatabase.gyms.map((g) {
                        final earned = trainer.clearedGymIds.contains(g.id);
                        return Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 7),
                          decoration: BoxDecoration(
                            color: earned
                                ? g.elementColor.withOpacity(0.16)
                                : const Color(0xFF0E121E),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: earned
                                  ? g.elementColor.withOpacity(0.7)
                                  : Colors.white12,
                            ),
                          ),
                          child: Column(
                            children: [
                              Opacity(
                                opacity: earned ? 1.0 : 0.25,
                                child: Image.asset(
                                  g.badgeAsset,
                                  width: 26,
                                  height: 26,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.stars_rounded,
                                    size: 24,
                                    color: earned
                                        ? g.elementColor
                                        : Colors.white24,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.badgeName.replaceAll(' Badge', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: earned ? Colors.white : Colors.white38,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2033),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.share_rounded,
                              color: Colors.cyanAccent, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "EXP Share",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: trainer.expShareEnabled,
                            activeColor: Colors.cyanAccent,
                            onChanged: (_) {
                              SoundService.instance.playUiTap();
                              trainer.toggleExpShare();
                              trainer.saveProgress();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _handleManualStepSync,
                            icon: const Icon(Icons.sync_rounded, size: 16),
                            label: const Text(
                              "Sync Steps",
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: BorderSide(
                                  color: Colors.cyanAccent.withOpacity(0.55)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmDeleteProgress(trainer,
                                modalContext: ctx),
                            icon: const Icon(Icons.delete_forever_rounded,
                                size: 16),
                            label: const Text(
                              "Reset Save",
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(
                                  color: Colors.redAccent.withOpacity(0.55)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
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
          );
        },
      ),
    );
  }

  void _confirmDeleteProgress(
    Trainer trainer, {
    BuildContext? modalContext,
  }) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Delete Saved Progress?",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "This will permanently erase your local save for ${trainer.name} "
          "(${trainer.party.length} Pokémon, ${trainer.totalSteps} steps, and ${trainer.totalItems} items) "
          "and return to the start screen.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              if (modalContext != null && modalContext.mounted) {
                Navigator.pop(modalContext);
              }
              await StepCounterService.resetPersistedBaselines();
              await trainer.deleteSaveAndReset();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Saved progress deleted. Starting a new adventure!"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Progress", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── PARTY MANAGER MODAL ──────────────────────────────────────────────────
  void _openPartyManagerModal(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<Trainer>(
          builder: (context, trainer, _) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "MANAGE POKÉMON",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                "Tap a Pokémon for Stats, Moves & Held Item • Lead #1 (${trainer.party.length}/6)",
                                style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                  builder: (context) => const PcStorageScreen()),
                            );
                          },
                          icon: const Icon(Icons.computer, size: 14),
                          label: Text(
                            "PC (${trainer.totalPcPokemon}/${trainer.maxPcCapacity})",
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purpleAccent.shade100,
                            side: BorderSide(
                                color: Colors.purpleAccent.withOpacity(0.55)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: trainer.party.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, idx) {
                          final mon = trainer.party[idx];
                          final isLead = idx == 0;
                          final typeColor = mon.species.types.first.color;

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PokemonDetailScreen(partyIndex: idx),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2033),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLead ? Colors.amberAccent : Colors.white12,
                                width: isLead ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Image.network(
                                          mon.spriteUrl,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (_, __, ___) =>
                                              Image.network(
                                            mon.staticSpriteUrl,
                                            width: 54,
                                            height: 54,
                                            filterQuality: FilterQuality.none,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.catching_pokemon,
                                              color: typeColor,
                                              size: 40,
                                            ),
                                          ),
                                        ),
                                        if (mon.isShiny)
                                          const Positioned(
                                            top: -2,
                                            right: -2,
                                            child: Icon(
                                              Icons.auto_awesome_rounded,
                                              color: Colors.amberAccent,
                                              size: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isLead
                                                      ? Colors.amberAccent.withOpacity(0.2)
                                                      : Colors.white10,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isLead ? "SPOT #1 • LEAD" : "SPOT #${idx + 1}",
                                                  style: TextStyle(
                                                    color: isLead
                                                        ? Colors.amberAccent
                                                        : Colors.white60,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  mon.nickname,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Lv.${mon.level}",
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                                          const SizedBox(height: 4),
                                          Text(
                                            mon.moves.map((m) => m.name).join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white60, fontSize: 10),
                                          ),
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: mon.hasHeldItem
                                                    ? Colors.amberAccent.withOpacity(0.4)
                                                    : Colors.white12,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  mon.hasHeldItem ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                                                  size: 13,
                                                  color: mon.hasHeldItem ? Colors.amberAccent : Colors.white38,
                                                ),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    mon.hasHeldItem
                                                        ? "Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}"
                                                        : "No held item",
                                                    style: TextStyle(
                                                      color: mon.hasHeldItem ? Colors.amberAccent : Colors.white38,
                                                      fontSize: 10,
                                                      fontWeight: mon.hasHeldItem ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (mon.hasHeldItem)
                                                  InkWell(
                                                    onTap: () {
                                                      final unequipped = mon.unequipHeldItem();
                                                      if (unequipped != null) {
                                                        trainer.adjustItemCount(unequipped, 1);
                                                        trainer.saveProgress();
                                                      }
                                                    },
                                                    child: const Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      child: Text(
                                                        "TAKE",
                                                        style: TextStyle(
                                                          color: Colors.redAccent,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  InkWell(
                                                    onTap: () => _openGiveHeldItemModal(ctx, trainer, mon),
                                                    child: const Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      child: Text(
                                                        "GIVE",
                                                        style: TextStyle(
                                                          color: Colors.cyanAccent,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
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
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isLead)
                                      ElevatedButton.icon(
                                        onPressed: () => trainer.setLeadPokemon(idx),
                                        icon: const Icon(Icons.star, size: 14),
                                        label: const Text(
                                          "Put in 1st Spot",
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade700,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10)),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.greenAccent.withOpacity(0.4)),
                                        ),
                                        child: const Text(
                                          "Active Lead",
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    if (idx > 0)
                                      IconButton(
                                        tooltip: "Move Up",
                                        icon: const Icon(Icons.arrow_upward,
                                            color: Colors.white70, size: 18),
                                        onPressed: () => trainer.swapPartySlots(idx, idx - 1),
                                      ),
                                    if (idx < trainer.party.length - 1)
                                      IconButton(
                                        tooltip: "Move Down",
                                        icon: const Icon(Icons.arrow_downward,
                                            color: Colors.white70, size: 18),
                                        onPressed: () => trainer.swapPartySlots(idx, idx + 1),
                                      ),
                                    if (trainer.party.length > 1) ...[
                                      IconButton(
                                        tooltip: "Deposit to PC Box",
                                        icon: Icon(Icons.inventory_2_outlined,
                                            color: Colors.purpleAccent.shade100,
                                            size: 18),
                                        onPressed: () {
                                          final ok = trainer.depositPokemonToPc(idx);
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(ok
                                                  ? "${mon.nickname} was deposited into Box ${trainer.activePcBoxIndex + 1}!"
                                                  : "All 16 PC Boxes are full (320/320)!"),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: "Release Pokémon",
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 18),
                                        onPressed: () => _confirmReleasePokemon(ctx, trainer, idx, mon),
                                      ),
                                    ],
                                    const SizedBox(width: 2),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          this.context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PokemonDetailScreen(
                                                    partyIndex: idx),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.auto_stories_rounded,
                                          size: 13),
                                      label: const Text(
                                        "INFO",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.cyanAccent,
                                        side: BorderSide(
                                            color: Colors.cyanAccent
                                                .withOpacity(0.55)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 5),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(9)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmReleasePokemon(
    BuildContext modalContext,
    Trainer trainer,
    int index,
    PokemonInstance mon,
  ) {
    showDialog(
      context: modalContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        title: Text(
          "Release ${mon.nickname}?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Lv.${mon.level} ${mon.species.name} will be released from your carried party.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              trainer.releasePokemon(index);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Release"),
          ),
        ],
      ),
    );
  }

  void _openGiveHeldItemModal(
    BuildContext parentContext,
    Trainer trainer,
    PokemonInstance mon,
  ) {
    final eligibleItems = ItemDatabase.allItems.values
        .where((item) =>
            (item.isBerry || item.isHeldItem) &&
            trainer.getItemCount(item.id) > 0)
        .toList();

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: const Color(0xFF121624),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GIVE ITEM TO ${mon.nickname.toUpperCase()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            mon.hasHeldItem
                                ? "Current item: ${ItemDatabase.allItems[mon.heldItemId]?.name ?? mon.heldItemId} (will return to bag)"
                                : "No item currently held",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(dlgCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (eligibleItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          "No Berries or Held Items in your Bag!\nFind berries on wild Pokémon or earn rare held items by re-challenging Gym Leaders.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: eligibleItems.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final item = eligibleItems[idx];
                          final count = trainer.getItemCount(item.id);
                          return InkWell(
                            onTap: () {
                              final oldItem = mon.unequipHeldItem();
                              if (oldItem != null) {
                                trainer.adjustItemCount(oldItem, 1);
                              }
                              mon.equipHeldItem(item.id);
                              trainer.adjustItemCount(item.id, -1);
                              trainer.saveProgress();
                              Navigator.pop(dlgCtx);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${mon.nickname} is now holding ${item.name}!",
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A2033),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: item.color.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Icon(item.icon, color: item.color, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: item.color
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.isBerry
                                                    ? "BERRY"
                                                    : "HELD ITEM",
                                                style: TextStyle(
                                                  color: item.color,
                                                  fontSize: 8.5,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          item.description,
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "x$count",
                                    style: TextStyle(
                                      color: item.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
