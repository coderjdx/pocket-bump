import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_region.dart';
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
import '../widgets/nickname_dialog.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_head_portrait.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/sound_controls.dart';
import '../widgets/trainer_bust_portrait.dart';
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
import 'region_travel_screen.dart';
import 'rivals_screen.dart';
import 'victory_road_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    SoundService.instance.playBgm(BgmTrack.hubTown);

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
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PokeColors.pokeBlue, width: 1.6),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded,
                color: PokeColors.pokeBlue, size: 22),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                "Update Available!",
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
            Text(
              "A new version of Pocket Bump (${update.latestVersion}) is available on GitHub.",
              style: const TextStyle(
                color: PokeColors.inkMuted,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: PokeDecorations.inset(radius: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Installed: v${update.currentVersion}",
                    style: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Latest: ${update.latestVersion}",
                    style: const TextStyle(
                      color: PokeColors.pokeGreenDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
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
            child: const Text(
              "Skip",
              style: TextStyle(color: PokeColors.inkSubtle),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text(
              "Later",
              style: TextStyle(
                color: PokeColors.inkMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
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
              backgroundColor: PokeColors.pokeBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
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
      region: trainer.activeRegion,
    );
    await precacheImage(
      AssetImage(wildMon.species.battleBackgroundAsset),
      context,
    ).catchError((_) {});
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BattleScreen(opponentPokemon: wildMon, isWild: true),
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

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/home_bg.png',
            alignment: Alignment.bottomCenter,
            topOpacity: 0.14,
            midOpacity: 0.34,
            bottomOpacity: 0.80,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopHudBar(trainer),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildTrainerHeroCard(trainer),
                  ),
                  const SizedBox(height: 12),
                  _buildMainCommandRow(trainer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. POKÉ RED TOP HUD BAR ──────────────────────────────────────────────
  Widget _buildTopHudBar(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [PokeColors.pokeRed, PokeColors.pokeRedDark],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: PokeColors.pokeRedDark.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.catching_pokemon, color: Colors.white, size: 19),
          const SizedBox(width: 6),
          const Text(
            "POCKET BUMP",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.9,
            ),
          ),
          if (trainer.gameVersion != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () {
                SoundService.instance.playUiTap();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegionTravelScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white.withOpacity(0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${trainer.activeRegion.displayName.toUpperCase()} • ${trainer.gameVersion!.shortLabel}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (trainer.isRegionUnlocked(GameRegion.johto)) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.public_rounded,
                          color: Colors.white, size: 10),
                    ],
                  ],
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
                  pillColor = PokeColors.pokeGreenDark;
                  pillIcon = Icons.sync_rounded;
                  break;
                case StepSyncStatus.syncedSensorOnly:
                  pillColor = PokeColors.pokeBlueDark;
                  pillIcon = Icons.sensors_rounded;
                  break;
                case StepSyncStatus.syncing:
                case StepSyncStatus.needsPermission:
                  pillColor = PokeColors.bagOrangeDark;
                  pillIcon = Icons.touch_app_rounded;
                  break;
                case StepSyncStatus.webPreview:
                case StepSyncStatus.unavailable:
                  pillColor = PokeColors.inkMuted;
                  pillIcon = Icons.sensors_off_rounded;
                  break;
              }
              return Tooltip(
                message: sync.detail,
                child: InkWell(
                  onTap: _handleManualStepSync,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: PokeColors.cardWhite,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: pillColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(pillIcon, size: 11, color: pillColor),
                        const SizedBox(width: 3),
                        Text(
                          sync.label,
                          style: TextStyle(
                            color: pillColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 8.8,
                            letterSpacing: 0.3,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: PokeColors.cardWhite,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: PokeColors.badgeGold, width: 1.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "₽",
                  style: TextStyle(
                    color: PokeColors.badgeGoldDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: PokeColors.inkDark,
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

  // ─── 2. 1/3 TRAINER BUST & BADGES + 2/3 SIX-SLOT PARTY SHOWCASE ────────────
  Widget _buildTrainerHeroCard(Trainer trainer) {
    return Container(
      decoration: BoxDecoration(
        color: PokeColors.creamSurface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: PokeColors.frameBorder.withOpacity(0.8),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: PokeColors.frameBorder.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
        child: Column(
          children: [
            // Compact Top Trainer Meta Strip
            Row(
              children: [
                _buildMiniMetaPill(
                  icon: Icons.menu_book_rounded,
                  color: PokeColors.pokeRed,
                  text:
                      "DEX ${trainer.caughtCount}/${PokedexDatabase.gen1TotalSpecies}",
                ),
                const SizedBox(width: 6),
                _buildMiniMetaPill(
                  icon: Icons.directions_walk_rounded,
                  color: PokeColors.pokeGreenDark,
                  text: "${trainer.todaySteps} STEPS",
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    SoundService.instance.playUiTap();
                    _openTrainerInfoSheet(trainer);
                  },
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: PokeColors.pokeBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: PokeColors.pokeBlue.withOpacity(0.55),
                      ),
                    ),
                    child: Text(
                      "OBEY Lv.${trainer.maxObedienceLevel}",
                      style: const TextStyle(
                        color: PokeColors.pokeBlueDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.2,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 1/3 Trainer Column + 2/3 Party 6-Slot Column
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildHomeTrainerColumn(trainer),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildHomePartyColumn(trainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniMetaPill({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: PokeColors.cardWhite,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: PokeColors.inkDark,
              fontSize: 9.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTrainerColumn(Trainer trainer) {
    final gyms = GymDatabase.gyms;
    return InkWell(
      onTap: () {
        SoundService.instance.playUiTap();
        _openTrainerInfoSheet(trainer);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: PokeDecorations.card(
          fill: PokeColors.cardWhite,
          border: PokeColors.pokeRed.withOpacity(0.55),
          radius: 16,
          borderWidth: 1.6,
        ),
        child: Column(
          children: [
            // 3/4 View Trainer Bust Portrait
            Expanded(
              flex: 5,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: PokeColors.pokeRed.withOpacity(0.45),
                    width: 1.4,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.6),
                  child: TrainerBustPortrait(
                    avatar: trainer.avatar,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),

            // Trainer Nameplate
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PokeColors.pokeRed, PokeColors.pokeRedDark],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    trainer.name.toUpperCase(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),

            // Collected Badges Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  size: 11,
                  color: PokeColors.badgeGoldDark,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    "BADGES ${trainer.clearedGymIds.length}/8",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),

            // 8 Kanto Gym Badges Grid (2 columns x 4 rows)
            Expanded(
              flex: 5,
              child: Column(
                children: List.generate(4, (rowIdx) {
                  return Expanded(
                    child: Row(
                      children: List.generate(2, (colIdx) {
                        final gymIdx = rowIdx * 2 + colIdx;
                        final gym = gymIdx < gyms.length ? gyms[gymIdx] : null;
                        if (gym == null) {
                          return const Expanded(child: SizedBox.shrink());
                        }
                        final earned =
                            trainer.clearedGymIds.contains(gym.id);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: Container(
                              decoration: BoxDecoration(
                                color: earned
                                    ? gym.elementColor.withOpacity(0.14)
                                    : PokeColors.panelSoft,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: earned
                                      ? gym.elementColor.withOpacity(0.75)
                                      : PokeColors.frameBorderSoft,
                                  width: earned ? 1.2 : 0.9,
                                ),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Opacity(
                                    opacity: earned ? 1.0 : 0.24,
                                    child: earned
                                        ? Image.asset(
                                            gym.badgeAsset,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.none,
                                            errorBuilder: (_, __, ___) => Icon(
                                              Icons.stars_rounded,
                                              size: 14,
                                              color: gym.elementColor,
                                            ),
                                          )
                                        : ColorFiltered(
                                            colorFilter: const ColorFilter.mode(
                                              Colors.grey,
                                              BlendMode.saturation,
                                            ),
                                            child: Image.asset(
                                              gym.badgeAsset,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.none,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.stars_rounded,
                                                size: 13,
                                                color: PokeColors.inkSubtle,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomePartyColumn(Trainer trainer) {
    return Column(
      children: List.generate(6, (idx) {
        final PokemonInstance? mon =
            idx < trainer.party.length ? trainer.party[idx] : null;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: idx == 5 ? 0 : 4.5),
            child: mon == null
                ? _buildEmptyPartySlotTile(idx)
                : _buildOccupiedPartySlotTile(idx, mon),
          ),
        );
      }),
    );
  }

  Widget _buildOccupiedPartySlotTile(int idx, PokemonInstance mon) {
    final Color typeColor = mon.species.types.first.color;
    final bool isLead = idx == 0;
    final Color hpColor = mon.hpPercent > 0.5
        ? PokeColors.pokeGreen
        : (mon.hpPercent > 0.2 ? PokeColors.badgeGold : PokeColors.pokeRed);
    final String? statusTag = mon.isFainted
        ? 'FNT'
        : (mon.status != StatusCondition.none ? mon.status.shortLabel : null);
    final Color statusBg = mon.isFainted
        ? PokeColors.pokeRed
        : statusConditionBadgeColor(mon.status);

    return InkWell(
      onTap: () {
        SoundService.instance.playUiTap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PokemonDetailScreen(partyIndex: idx),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 8, 4),
        decoration: PokeDecorations.card(
          fill: PokeColors.cardWhite,
          border: mon.isFainted
              ? PokeColors.pokeRed
              : (isLead ? PokeColors.badgeGold : typeColor.withOpacity(0.75)),
          radius: 12,
          borderWidth: isLead ? 1.8 : 1.3,
        ),
        child: Row(
          children: [
            LayoutBuilder(
              builder: (_, constraints) {
                final double maxH = constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 40;
                final double portraitSize = maxH.clamp(28.0, 42.0);
                return PokemonHeadPortrait(
                  pokemon: mon,
                  size: portraitSize,
                  borderRadius: 9,
                );
              },
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isLead) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: PokeColors.badgeGoldDark,
                        ),
                        const SizedBox(width: 2),
                      ],
                      Expanded(
                        child: Text(
                          mon.nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mon.isFainted
                                ? PokeColors.inkMuted
                                : PokeColors.inkDark,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (statusTag != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusTag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7.8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 5),
                      Text(
                        "Lv.${mon.level}",
                        style: const TextStyle(
                          color: PokeColors.badgeGoldDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3.5),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: mon.hpPercent,
                            minHeight: 5.5,
                            backgroundColor: PokeColors.panelSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(hpColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${mon.currentHp}/${mon.maxHp}",
                        style: TextStyle(
                          color: mon.isFainted
                              ? PokeColors.pokeRed
                              : PokeColors.inkMuted,
                          fontSize: 9.2,
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
      ),
    );
  }

  Widget _buildEmptyPartySlotTile(int idx) {
    return InkWell(
      onTap: () {
        SoundService.instance.playUiTap();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PcStorageScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: PokeDecorations.inset(
          fill: PokeColors.panelSoft.withOpacity(0.75),
          border: PokeColors.frameBorderSoft,
          radius: 12,
        ),
        child: Row(
          children: [
            Icon(
              Icons.catching_pokemon,
              size: 16,
              color: PokeColors.inkSubtle.withOpacity(0.6),
            ),
            const SizedBox(width: 7),
            Text(
              "EMPTY SLOT #${idx + 1}",
              style: const TextStyle(
                color: PokeColors.inkSubtle,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. FOUR BIG PORTRAIT BUTTONS IN A SINGLE HORIZONTAL ROW ───────────────
  Widget _buildMainCommandRow(Trainer trainer) {
    final badges = trainer.clearedGymIds.length;
    return Row(
      children: [
        Expanded(
          child: PokePortraitButton(
            label: "BATTLE",
            icon: Icons.flash_on_rounded,
            topColor: PokeColors.pokeRed,
            bottomColor: PokeColors.pokeRedDark,
            height: 146,
            iconSize: 40,
            onTap: () {
              SoundService.instance.playUiTap();
              _openBattleMenuSheet(trainer);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PokePortraitButton(
            label: "FACILITIES",
            icon: Icons.local_hospital_rounded,
            topColor: PokeColors.pokeGreen,
            bottomColor: PokeColors.pokeGreenDark,
            height: 146,
            iconSize: 40,
            onTap: () {
              SoundService.instance.playUiTap();
              _openFacilitiesMenuSheet(trainer);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PokePortraitButton(
            label: "TRAINER",
            icon: Icons.badge_rounded,
            topColor: PokeColors.pokeBlue,
            bottomColor: PokeColors.pokeBlueDark,
            height: 146,
            iconSize: 40,
            badgeText: "$badges/8",
            onTap: () {
              SoundService.instance.playUiTap();
              _openTrainerMenuSheet(trainer);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PokePortraitButton(
            label: "FISTBUMP\nLINK",
            icon: Icons.sports_mma_rounded,
            topColor: PokeColors.pokeGold,
            bottomColor: PokeColors.pokeGoldDark,
            height: 146,
            iconSize: 40,
            onTap: () {
              SoundService.instance.playUiTap();
              _openLinkMenuSheet(trainer);
            },
          ),
        ),
      ],
    );
  }

  // ─── 4. CATEGORY SUBMENUS (PORTRAIT-BUTTON ROWS IN CREAM SHEETS) ──────────
  void _openBattleMenuSheet(Trainer trainer) {
    final badges = trainer.clearedGymIds.length;
    final String victoryRoadSub = !trainer.isVictoryRoadUnlocked
        ? "$badges/8 Badges"
        : (!trainer.victoryRoadCleared
            ? "First Ascent"
            : (!trainer.isChampion ? "Final Four" : "Lv.99 Rematch"));

    showModalBottomSheet(
      context: context,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PokeSheetHeader(
                icon: Icons.flash_on_rounded,
                accentColor: PokeColors.pokeRed,
                title: "BATTLE",
                subtitle: "Choose your battle mode",
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PokePortraitButton(
                      label: "ADVENTURE",
                      subtitle: "5-Stage Wild",
                      icon: Icons.explore_rounded,
                      topColor: PokeColors.pokeGreen,
                      bottomColor: PokeColors.pokeGreenDark,
                      height: 136,
                      iconSize: 34,
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        _launchAdventure(trainer);
                      },
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: PokePortraitButton(
                      label: "GYM\nBATTLES",
                      subtitle: "Kanto Gyms",
                      icon: Icons.military_tech_rounded,
                      topColor: PokeColors.leagueIndigo,
                      bottomColor: PokeColors.leagueIndigoDark,
                      height: 136,
                      iconSize: 34,
                      badgeText: "$badges/8",
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
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: PokePortraitButton(
                      label: "EXPEDITION",
                      subtitle: trainer.isExpeditionsUnlocked
                          ? "Lv.99 Sites"
                          : "$badges/8 Badges",
                      icon: Icons.terrain_rounded,
                      topColor: PokeColors.linkTeal,
                      bottomColor: PokeColors.linkTealDark,
                      height: 136,
                      iconSize: 34,
                      locked: !trainer.isExpeditionsUnlocked,
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
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: PokePortraitButton(
                      label: "VICTORY\nROAD",
                      subtitle: victoryRoadSub,
                      icon: Icons.emoji_events_rounded,
                      topColor: PokeColors.bagOrange,
                      bottomColor: PokeColors.bagOrangeDark,
                      height: 136,
                      iconSize: 34,
                      locked: !trainer.isVictoryRoadUnlocked,
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        if (trainer.isVictoryRoadUnlocked) {
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                                builder: (_) => const VictoryRoadScreen()),
                          );
                        } else {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "Victory Road unlocks after earning all 8 Gym Badges! ($badges/8 earned)"),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
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
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PokeSheetHeader(
                icon: Icons.local_hospital_rounded,
                accentColor: PokeColors.pokeGreen,
                title: "FACILITIES",
                subtitle: "Heal, shop, restore fossils & tutor moves",
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PokePortraitButton(
                      label: "POKÉMON\nCENTER",
                      icon: Icons.local_hospital_rounded,
                      topColor: PokeColors.centerRose,
                      bottomColor: PokeColors.centerRoseDark,
                      height: 136,
                      iconSize: 36,
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
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PokePortraitButton(
                      label: "POKÉ\nMART",
                      subtitle: "₽${trainer.money}",
                      icon: Icons.storefront_rounded,
                      topColor: PokeColors.pokeBlue,
                      bottomColor: PokeColors.pokeBlueDark,
                      height: 136,
                      iconSize: 36,
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                              builder: (_) => const PokeMartScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PokePortraitButton(
                      label: "POKÉMON\nLAB",
                      subtitle: "${fossils + vouchers} Fossils",
                      icon: Icons.science_rounded,
                      topColor: PokeColors.pokeGreen,
                      bottomColor: PokeColors.pokeGreenDark,
                      height: 136,
                      iconSize: 36,
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                              builder: (_) => const PokemonLabScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PokePortraitButton(
                      label: "MOVE\nTUTOR",
                      icon: Icons.favorite_rounded,
                      topColor: const Color(0xFFEC407A),
                      bottomColor: PokeColors.centerRoseDark,
                      height: 136,
                      iconSize: 36,
                      badgeText: "x$heartScales",
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                              builder: (_) => const MoveTutorScreen()),
                        );
                      },
                    ),
                  ),
                ],
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
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PokeSheetHeader(
                  icon: Icons.badge_rounded,
                  accentColor: PokeColors.pokeBlue,
                  title: "TRAINER",
                  subtitle: "${trainer.name} • ${trainer.clearedGymIds.length}/8 Badges",
                  onClose: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: PokePortraitButton(
                        label: "TRAINER\nINFO",
                        icon: Icons.person_pin_rounded,
                        topColor: PokeColors.pokeBlue,
                        bottomColor: PokeColors.pokeBlueDark,
                        height: 128,
                        iconSize: 36,
                        badgeText: "${trainer.clearedGymIds.length}/8",
                        onTap: () {
                          SoundService.instance.playUiTap();
                          Navigator.pop(ctx);
                          _openTrainerInfoSheet(trainer);
                        },
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: PokePortraitButton(
                        label: "POKÉMON",
                        subtitle: "Party & PC",
                        icon: Icons.catching_pokemon,
                        topColor: PokeColors.pokeRed,
                        bottomColor: PokeColors.pokeRedDark,
                        height: 128,
                        iconSize: 36,
                        badgeText: "${trainer.party.length}/6",
                        onTap: () {
                          SoundService.instance.playUiTap();
                          Navigator.pop(ctx);
                          _openPartyManagerModal(trainer);
                        },
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: PokePortraitButton(
                        label: "BAG",
                        subtitle: "${trainer.totalItems} items",
                        icon: Icons.backpack_rounded,
                        topColor: PokeColors.bagOrange,
                        bottomColor: PokeColors.bagOrangeDark,
                        height: 128,
                        iconSize: 36,
                        onTap: () {
                          SoundService.instance.playUiTap();
                          Navigator.pop(ctx);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                                builder: (_) => const BagScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PokePortraitButton(
                        label: "POKÉDEX",
                        subtitle: "Kanto Dex",
                        icon: Icons.menu_book_rounded,
                        iconOverride:
                            const PokeBallSymbol(size: 32, isCaught: true),
                        topColor: PokeColors.pokeRed,
                        bottomColor: PokeColors.pokeRedDark,
                        height: 124,
                        iconSize: 36,
                        badgeText: "$caught/$totalSpecies",
                        onTap: () {
                          SoundService.instance.playUiTap();
                          Navigator.pop(ctx);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                                builder: (_) => const PokedexScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: PokePortraitButton(
                        label: "MYSTERY\nGIFT",
                        subtitle: "Events & Codes",
                        icon: Icons.card_giftcard_rounded,
                        topColor: PokeColors.giftCrimson,
                        bottomColor: PokeColors.giftCrimsonDark,
                        height: 124,
                        iconSize: 36,
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
                    ),
                  ],
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
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PokeSheetHeader(
                icon: Icons.sports_mma_rounded,
                accentColor: PokeColors.pokeGold,
                title: "FISTBUMP LINK",
                subtitle: "Local Union Room PvP & Trading",
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: PokePortraitButton(
                      label: "BATTLE &\nTRADE LINK",
                      subtitle: "Fistbump Nearby",
                      icon: Icons.sports_mma_rounded,
                      topColor: PokeColors.pokeGold,
                      bottomColor: PokeColors.pokeGoldDark,
                      height: 136,
                      iconSize: 38,
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(builder: (_) => const BumpScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PokePortraitButton(
                      label: "RIVALS &\nFRIENDS",
                      subtitle: "${trainer.friendCount} ★ Friends",
                      icon: Icons.people_alt_rounded,
                      topColor: PokeColors.linkTeal,
                      bottomColor: PokeColors.linkTealDark,
                      height: 136,
                      iconSize: 38,
                      badgeText: "${trainer.rivals.length}",
                      onTap: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(ctx);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                              builder: (_) => const RivalsScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 5. TRAINER INFO CARD SHEET ───────────────────────────────────────────
  void _openTrainerInfoSheet(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
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
                    PokeSheetHeader(
                      icon: Icons.person_pin_rounded,
                      accentColor: PokeColors.pokeBlue,
                      title: "TRAINER CARD",
                      onClose: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.cardWhite,
                        border: PokeColors.pokeBlue.withOpacity(0.55),
                        radius: 18,
                        borderWidth: 1.6,
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
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                Text(
                                  trainer.avatar.title,
                                  style: const TextStyle(
                                    color: PokeColors.pokeBlueDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Money: ₽${trainer.money} • Obey Lv.${trainer.maxObedienceLevel}",
                                  style: const TextStyle(
                                    color: PokeColors.badgeGoldDark,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Today: ${trainer.todaySteps} steps • Total: ${trainer.totalSteps}",
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
                    const SizedBox(height: 14),
                    const Text(
                      "KANTO GYM BADGES",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
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
                          decoration: PokeDecorations.card(
                            fill: earned
                                ? PokeColors.cardWhite
                                : PokeColors.panelSoft,
                            border: earned
                                ? g.elementColor
                                : PokeColors.frameBorderSoft,
                            radius: 11,
                            borderWidth: earned ? 1.6 : 1.0,
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
                                        : PokeColors.inkSubtle,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                g.badgeName.replaceAll(' Badge', ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: earned
                                      ? PokeColors.inkDark
                                      : PokeColors.inkSubtle,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: trainer.hasExpShare ? 6 : 10,
                      ),
                      decoration: PokeDecorations.card(
                        fill: trainer.hasExpShare
                            ? PokeColors.cardWhite
                            : PokeColors.panelSoft,
                        border: trainer.hasExpShare
                            ? PokeColors.pokeBlue.withOpacity(0.55)
                            : PokeColors.frameBorderSoft,
                        radius: 13,
                        borderWidth: 1.4,
                      ),
                      child: trainer.hasExpShare
                          ? Row(
                              children: [
                                const Icon(Icons.share_rounded,
                                    color: PokeColors.pokeBlue, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    "EXP Share",
                                    style: TextStyle(
                                      color: PokeColors.inkDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: trainer.isExpShareActive,
                                  activeColor: PokeColors.pokeBlue,
                                  onChanged: (_) {
                                    SoundService.instance.playUiTap();
                                    trainer.toggleExpShare();
                                    trainer.saveProgress();
                                  },
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded,
                                    color: PokeColors.inkSubtle, size: 18),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "EXP Share",
                                        style: TextStyle(
                                          color: PokeColors.inkMuted,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        "Defeat Giovanni (8th Gym) to unlock",
                                        style: TextStyle(
                                          color: PokeColors.inkSubtle,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: PokeColors.cardWhite,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: PokeColors.frameBorderSoft),
                                  ),
                                  child: const Text(
                                    "LOCKED",
                                    style: TextStyle(
                                      color: PokeColors.inkSubtle,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
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
                              foregroundColor: PokeColors.pokeBlueDark,
                              side: const BorderSide(color: PokeColors.pokeBlue),
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
                              foregroundColor: PokeColors.pokeRed,
                              side: const BorderSide(color: PokeColors.pokeRed),
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
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PokeColors.pokeRed, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: PokeColors.pokeRed),
            SizedBox(width: 8),
            Text(
              "Delete Saved Progress?",
              style: TextStyle(
                color: PokeColors.inkDark,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          "This will permanently erase your local save for ${trainer.name} "
          "(${trainer.party.length} Pokémon, ${trainer.totalSteps} steps, and ${trainer.totalItems} items) "
          "and return to the start screen.",
          style: const TextStyle(color: PokeColors.inkMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: PokeColors.inkMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  content: Text(
                      "Saved progress deleted. Starting a new adventure!"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.pokeRed,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Progress",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── 6. PARTY MANAGER MODAL ───────────────────────────────────────────────
  void _openPartyManagerModal(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<Trainer>(
          builder: (context, trainer, _) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                                  color: PokeColors.inkDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              Text(
                                "Tap a Pokémon for Stats & Moves • Lead #1 (${trainer.party.length}/6)",
                                style: const TextStyle(
                                    color: PokeColors.inkMuted, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const PcStorageScreen()),
                            );
                          },
                          icon: const Icon(Icons.computer, size: 14),
                          label: Text(
                            "PC (${trainer.totalPcPokemon}/${trainer.maxPcCapacity})",
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w900),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PokeColors.pcTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: PokeColors.inkMuted),
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
                              decoration: PokeDecorations.card(
                                fill: PokeColors.cardWhite,
                                border: isLead
                                    ? PokeColors.badgeGold
                                    : typeColor.withOpacity(0.55),
                                radius: 16,
                                borderWidth: isLead ? 1.8 : 1.3,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          PokemonSpriteImage.fromInstance(
                                            mon,
                                            width: 54,
                                            height: 54,
                                            fallbackIconSize: 40,
                                            fallbackIconColor: typeColor,
                                          ),
                                          if (mon.isShiny)
                                            const Positioned(
                                              top: -2,
                                              right: -2,
                                              child: Icon(
                                                Icons.auto_awesome_rounded,
                                                color: PokeColors.badgeGoldDark,
                                                size: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isLead
                                                        ? PokeColors.badgeGold
                                                            .withOpacity(0.22)
                                                        : PokeColors.panelSoft,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    isLead
                                                        ? "SPOT #1 • LEAD"
                                                        : "SPOT #${idx + 1}",
                                                    style: TextStyle(
                                                      color: isLead
                                                          ? PokeColors
                                                              .badgeGoldDark
                                                          : PokeColors.inkMuted,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    mon.nickname,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: PokeColors.inkDark,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Lv.${mon.level}",
                                                  style: const TextStyle(
                                                    color: PokeColors
                                                        .badgeGoldDark,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                if (mon.canSetNickname)
                                                  InkWell(
                                                    onTap: () async {
                                                      SoundService.instance
                                                          .playUiTap();
                                                      final chosen =
                                                          await showNicknamePokemonDialog(
                                                        ctx,
                                                        pokemon: mon,
                                                      );
                                                      if (!mounted ||
                                                          chosen == null) {
                                                        return;
                                                      }
                                                      trainer
                                                          .setPokemonNickname(
                                                              mon, chosen);
                                                    },
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            7),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: PokeColors
                                                            .pokeBlue
                                                            .withOpacity(0.12),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(7),
                                                        border: Border.all(
                                                            color: PokeColors
                                                                .pokeBlue),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .edit_rounded,
                                                              size: 10,
                                                              color: PokeColors
                                                                  .pokeBlueDark),
                                                          SizedBox(width: 2),
                                                          Text(
                                                            "NAME",
                                                            style: TextStyle(
                                                              color: PokeColors
                                                                  .pokeBlueDark,
                                                              fontSize: 8.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w900,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const Tooltip(
                                                    message:
                                                        "Nickname is permanent",
                                                    child: Icon(
                                                      Icons.lock_rounded,
                                                      size: 13,
                                                      color:
                                                          PokeColors.inkSubtle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "${mon.species.name} • OT: ${mon.originalTrainerDisplay(fallbackName: trainer.name)}",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: PokeColors.inkMuted,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            HpBar(
                                              currentHp: mon.currentHp,
                                              maxHp: mon.maxHp,
                                              textColor: PokeColors.inkMuted,
                                              hpLabelColor:
                                                  PokeColors.badgeGoldDark,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              mon.moves
                                                  .map((m) => m.name)
                                                  .join(' • '),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  color: PokeColors.inkMuted,
                                                  fontSize: 10),
                                            ),
                                            const SizedBox(height: 5),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                              decoration: PokeDecorations.inset(
                                                radius: 7,
                                                border: mon.hasHeldItem
                                                    ? PokeColors.badgeGold
                                                    : PokeColors
                                                        .frameBorderSoft,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    mon.hasHeldItem
                                                        ? Icons.shopping_bag
                                                        : Icons
                                                            .shopping_bag_outlined,
                                                    size: 13,
                                                    color: mon.hasHeldItem
                                                        ? PokeColors
                                                            .badgeGoldDark
                                                        : PokeColors.inkSubtle,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Expanded(
                                                    child: Text(
                                                      mon.hasHeldItem
                                                          ? "Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}"
                                                          : "No held item",
                                                      style: TextStyle(
                                                        color: mon.hasHeldItem
                                                            ? PokeColors
                                                                .badgeGoldDark
                                                            : PokeColors
                                                                .inkSubtle,
                                                        fontSize: 10,
                                                        fontWeight: mon
                                                                .hasHeldItem
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ),
                                                  if (mon.hasHeldItem)
                                                    InkWell(
                                                      onTap: () {
                                                        final unequipped = mon
                                                            .unequipHeldItem();
                                                        if (unequipped !=
                                                            null) {
                                                          trainer
                                                              .adjustItemCount(
                                                                  unequipped,
                                                                  1);
                                                          trainer
                                                              .saveProgress();
                                                        }
                                                      },
                                                      child: const Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                            horizontal: 4,
                                                            vertical: 1),
                                                        child: Text(
                                                          "TAKE",
                                                          style: TextStyle(
                                                            color: PokeColors
                                                                .pokeRed,
                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    InkWell(
                                                      onTap: () =>
                                                          _openGiveHeldItemModal(
                                                              ctx,
                                                              trainer,
                                                              mon),
                                                      child: const Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                            horizontal: 4,
                                                            vertical: 1),
                                                        child: Text(
                                                          "GIVE",
                                                          style: TextStyle(
                                                            color: PokeColors
                                                                .pokeBlue,
                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight.w900,
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
                                          onPressed: () =>
                                              trainer.setLeadPokemon(idx),
                                          icon:
                                              const Icon(Icons.star, size: 14),
                                          label: const Text(
                                            "Put in 1st Spot",
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                PokeColors.badgeGold,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: PokeColors.pokeGreen
                                                .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: PokeColors.pokeGreen
                                                    .withOpacity(0.5)),
                                          ),
                                          child: const Text(
                                            "Active Lead",
                                            style: TextStyle(
                                              color: PokeColors.pokeGreenDark,
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
                                              color: PokeColors.inkMuted,
                                              size: 18),
                                          onPressed: () => trainer
                                              .swapPartySlots(idx, idx - 1),
                                        ),
                                      if (idx < trainer.party.length - 1)
                                        IconButton(
                                          tooltip: "Move Down",
                                          icon: const Icon(Icons.arrow_downward,
                                              color: PokeColors.inkMuted,
                                              size: 18),
                                          onPressed: () => trainer
                                              .swapPartySlots(idx, idx + 1),
                                        ),
                                      if (trainer.party.length > 1) ...[
                                        IconButton(
                                          tooltip: "Deposit to PC Box",
                                          icon: const Icon(
                                              Icons.inventory_2_outlined,
                                              color: PokeColors.pcTealDark,
                                              size: 18),
                                          onPressed: () {
                                            final ok =
                                                trainer.depositPokemonToPc(idx);
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
                                              color: PokeColors.pokeRed,
                                              size: 18),
                                          onPressed: () =>
                                              _confirmReleasePokemon(
                                                  ctx, trainer, idx, mon),
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
                                          foregroundColor: PokeColors.pokeBlue,
                                          side: const BorderSide(
                                              color: PokeColors.pokeBlue),
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
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PokeColors.pokeRed, width: 1.5),
        ),
        title: Text(
          "Release ${mon.nickname}?",
          style: const TextStyle(
              color: PokeColors.inkDark, fontWeight: FontWeight.w900),
        ),
        content: Text(
          "Lv.${mon.level} ${mon.species.name} will be released from your carried party.",
          style: const TextStyle(color: PokeColors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancel",
                style: TextStyle(color: PokeColors.inkMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              trainer.releasePokemon(index);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.pokeRed,
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
      backgroundColor: PokeColors.creamSurface,
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
                  PokeSheetHeader(
                    icon: Icons.shopping_bag_rounded,
                    accentColor: PokeColors.bagOrange,
                    title: "GIVE ITEM TO ${mon.nickname.toUpperCase()}",
                    subtitle: mon.hasHeldItem
                        ? "Current item: ${ItemDatabase.allItems[mon.heldItemId]?.name ?? mon.heldItemId} (will return to bag)"
                        : "No item currently held",
                    onClose: () => Navigator.pop(dlgCtx),
                  ),
                  const SizedBox(height: 12),
                  if (eligibleItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: PokeDecorations.inset(radius: 12),
                      child: const Center(
                        child: Text(
                          "No Berries or Held Items in your Bag!\nFind berries on wild Pokémon or earn rare held items by re-challenging Gym Leaders.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: PokeColors.inkMuted, fontSize: 12),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                              decoration: PokeDecorations.card(
                                border: item.color.withOpacity(0.55),
                                radius: 12,
                                borderWidth: 1.4,
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
                                                color: PokeColors.inkDark,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color:
                                                    item.color.withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.isBerry
                                                    ? "BERRY"
                                                    : "HELD ITEM",
                                                style: TextStyle(
                                                  color: PokeColors.darken(
                                                      item.color, 0.14),
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          item.description,
                                          style: const TextStyle(
                                              color: PokeColors.inkMuted,
                                              fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "x$count",
                                    style: TextStyle(
                                      color:
                                          PokeColors.darken(item.color, 0.14),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
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
