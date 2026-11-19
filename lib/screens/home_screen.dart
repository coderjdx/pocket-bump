import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_version.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/app_update_service.dart';
import '../services/mystery_gift_service.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../services/step_counter_service.dart';
import '../services/tm_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/move_pp_picker_dialog.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/sound_controls.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/version_picker.dart';
import 'battle_screen.dart';
import 'bump_screen.dart';
import 'evolution_screen.dart';
import 'expeditions_screen.dart';
import 'mystery_gift_screen.dart';
import 'pc_storage_screen.dart';
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

    StepCounterService.initialize(
      onStepDelta: (diff) {
        if (!mounted) return;
        final trainer = Provider.of<Trainer>(context, listen: false);
        final triggered = trainer.recordStepsAndCheckEncounter(diff);
        if (triggered && trainer.gameVersion != null) {
          StepCounterService.triggerEncounterAlert();
          _launchWildEncounter();
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _promptVersionChoiceIfNeeded();
      if (!mounted) return;
      await _checkAppUpdate();
    });
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
    if (trainer.repelEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Repel is active! Toggle Repel off to encounter wild Pokémon."),
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

  void _simulateSteps(Trainer trainer, int delta) {
    final triggered = trainer.recordStepsAndCheckEncounter(delta);
    if (triggered && trainer.gameVersion != null) {
      _launchWildEncounter();
    }
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
                stops: const [0.0, 0.42, 0.78, 1.0],
                colors: [
                  const Color(0xFF0A0D16).withOpacity(0.68),
                  const Color(0xFF0F1320).withOpacity(0.18),
                  const Color(0xFF0C101B).withOpacity(0.55),
                  const Color(0xFF090B12).withOpacity(0.86),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  // ─── 1. GAME HUD BAR ─────────────────────────────────────
                  _buildTopHudBar(trainer),
                  const SizedBox(height: 8),

                  // ─── MAIN OVERWORLD VIEW & COMMAND DECK ──────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── 2. SCENIC TRAINER + LEAD PARTNER STAGE ─────
                          _buildCompanionStage(trainer, leadPokemon),
                          const SizedBox(height: 8),

                          // ─── 3. POKÉWALKER FIELD GEAR CONSOLE ────────────
                          _buildStepCounterCard(trainer),
                          const SizedBox(height: 8),

                          // ─── 4. COMMAND DECK (6 GAME TILES) ──────────────
                          _buildHubRow(trainer),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ─── 5. VERSUS LINK / FIST-BUMP DUEL + RIVALS BAR ─────────
                  Row(
                    children: [
                      Expanded(child: _buildChallengeTrainerButton()),
                      const SizedBox(width: 8),
                      _buildRivalsButton(trainer),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. GAME HUD BAR (NON-EDITABLE TRAINER IDENTITY + RESOURCES) ─────────
  Widget _buildTopHudBar(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE8161B2B), Color(0xE80F1320)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4C597D).withOpacity(0.65), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Trainer Emblem & Identity (Static — chosen at adventure start)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.redAccent.shade700.withOpacity(0.9),
                  Colors.red.shade900,
                ],
              ),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trainer.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (trainer.gameVersion != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              trainer.gameVersion!.primaryColor,
                              trainer.gameVersion!.secondaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          trainer.gameVersion!.shortLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  "POKÉMON ${trainer.party.length}/6 • OBEY Lv.${trainer.maxObedienceLevel}",
                  style: TextStyle(
                    color: Colors.cyanAccent.withOpacity(0.85),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          // Badges & Currency Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: Color(0xFFFFD54F), size: 13),
                const SizedBox(width: 3),
                Text(
                  "${trainer.clearedGymIds.length}/8",
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: Colors.white12,
                ),
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
          Tooltip(
            message: "Delete Saved Progress",
            child: InkWell(
              onTap: () => _confirmDeleteProgress(trainer),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.32),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.45)),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.redAccent, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. SCENIC OVERWORLD COMPANION STAGE (TRAINER + LEAD POKÉMON) ───────
  Widget _buildCompanionStage(Trainer trainer, PokemonInstance? lead) {
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
            const Color(0x550C101E),
            accentColor.withOpacity(0.14),
            const Color(0xDF101422),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withOpacity(0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top stage bar: Lead Pill & Swap Lead Trigger
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xCC0B0E18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withOpacity(0.65)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: accentColor, blurRadius: 5),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        "LEAD PARTNER",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SoundToggleButton(size: 14),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        SoundService.instance.playUiTap();
                        _openPartyManagerModal(trainer);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28324C), Color(0xFF1B2235)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded,
                            color: Colors.cyanAccent, size: 13),
                        SizedBox(width: 4),
                        Text(
                          "SWAP LEAD",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                  ],
                ),
              ],
            ),
          ),

          // Hero Character Stage: Trainer Portrait next to Lead Pokémon
          SizedBox(
            height: 124,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Subtle Horizon Glow Band
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 6,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: RadialGradient(
                        radius: 2.2,
                        colors: [
                          accentColor.withOpacity(0.28),
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
                    // Trainer Full Portrait
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TrainerSpriteWidget(
                          avatar: trainer.avatar,
                          isBackView: false,
                          size: 92,
                        ),
                        Container(
                          width: 58,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.48),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Animated Lead Pokémon Standing Next to Trainer (height-scaled)
                    if (lead != null)
                      Builder(builder: (_) {
                        final double companionSize =
                            lead.species.homeCompanionSize;
                        final double shadowWidth =
                            (companionSize * 0.72).clamp(32.0, 84.0);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedBuilder(
                              animation: _leadBobController,
                              builder: (context, child) {
                                final dy =
                                    -sin(_leadBobController.value * pi) * 3.5;
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
                                        errorBuilder: (c, e, s) => Image.network(
                                          lead.staticSpriteUrl,
                                          width: companionSize * 1.38,
                                          height: companionSize,
                                          fit: BoxFit.contain,
                                          alignment: Alignment.bottomCenter,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (c2, e2, s2) => Icon(
                                            Icons.catching_pokemon,
                                            color: accentColor,
                                            size: (companionSize * 0.62)
                                                .clamp(28.0, 60.0),
                                          ),
                                        ),
                                      ),
                                      if (lead.isShiny)
                                        Positioned(
                                          top: 0,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xCC151824),
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

          const SizedBox(height: 6),

          // Compact Partner Nameplate (No Raw Stats or Move Clutter)
          if (lead != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(
                color: const Color(0xEB101422),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16.5),
                ),
                border: Border.all(color: accentColor.withOpacity(0.28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      PokeBallSpriteWidget(ballType: lead.caughtBall, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          lead.nickname,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD54F).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFFFD54F).withOpacity(0.45)),
                        ),
                        child: Text(
                          "Lv.${lead.level}",
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (lead.isFainted) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.24),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: const Text(
                            "FNT",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ] else if (lead.status != StatusCondition.none) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.purpleAccent),
                          ),
                          child: Text(
                            lead.status.shortLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      ...lead.species.types.map((t) {
                        return Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.26),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: t.color.withOpacity(0.85)),
                          ),
                          child: Text(
                            t.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        "HP",
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 9.5,
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
                          fontSize: 10,
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
                            minHeight: 4,
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
        ],
      ),
    );
  }

  // ─── 3. POKÉWALKER FIELD GEAR CONSOLE ─────────────────────────────────────
  Widget _buildStepCounterCard(Trainer trainer) {
    final int stepsToday = trainer.todaySteps;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xEA1A2138), Color(0xEA101526)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4E67B0).withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.indigoAccent.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(7),
                  border:
                      Border.all(color: Colors.indigoAccent.withOpacity(0.5)),
                ),
                child: const Icon(Icons.directions_walk_rounded,
                    color: Colors.cyanAccent, size: 14),
              ),
              const SizedBox(width: 7),
              const Text(
                "POKÉWALKER GEAR",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0E18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.cyanAccent.withOpacity(0.35)),
                ),
                child: Text(
                  "$stepsToday STEPS",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 1),
                  icon: const Icon(Icons.directions_walk_rounded, size: 13),
                  label: const Text(
                    "+1 STEP",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF141A2E),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.indigoAccent.withOpacity(0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 25),
                  icon: const Icon(Icons.add_circle_outline, size: 13),
                  label: const Text(
                    "+25 STEPS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF141A2E),
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.indigoAccent.withOpacity(0.6)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _launchWildEncounter,
                  icon: const Icon(Icons.explore_rounded,
                      size: 13, color: Colors.black87),
                  label: const Text(
                    "TALL GRASS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF34EB8C),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildUtilityToggleRow(trainer),
        ],
      ),
    );
  }

  Widget _buildUtilityToggleRow(Trainer trainer) {
    Widget pill({
      required bool active,
      required IconData icon,
      required String label,
      required Color activeColor,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: active
                  ? activeColor.withOpacity(0.18)
                  : const Color(0xFF0C101C),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: active
                    ? activeColor.withOpacity(0.8)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? activeColor : Colors.white24,
                    boxShadow: active
                        ? [BoxShadow(color: activeColor, blurRadius: 5)]
                        : null,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  icon,
                  size: 12,
                  color: active ? activeColor : Colors.white54,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? activeColor : Colors.white60,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          active: trainer.expShareEnabled,
          icon: Icons.share_rounded,
          label: trainer.expShareEnabled ? "EXP SHARE ON" : "EXP SHARE OFF",
          activeColor: Colors.cyanAccent,
          onTap: () {
            SoundService.instance.playUiTap();
            trainer.toggleExpShare();
          },
        ),
        const SizedBox(width: 6),
        pill(
          active: trainer.repelEnabled,
          icon: Icons.shield_rounded,
          label: trainer.repelEnabled ? "REPEL ON" : "REPEL OFF",
          activeColor: Colors.orangeAccent,
          onTap: () {
            SoundService.instance.playUiTap();
            trainer.toggleRepel();
          },
        ),
      ],
    );
  }

  // ─── 4. GAME COMMAND PLATES (PARTY, BAG, POKÉDEX, LEAGUE, CENTER, PC) ────
  Widget _buildHubTile({
    required VoidCallback onTap,
    required Color accentColor,
    required Widget iconWidget,
    required String title,
    required String subtitle,
    Color subtitleColor = Colors.white60,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          SoundService.instance.playUiTap();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 8, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.18),
                const Color(0xE8161A29),
                const Color(0xEE0F1320),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withOpacity(0.55),
              width: 1.15,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0D16),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: accentColor.withOpacity(0.5)),
                    ),
                    child: iconWidget,
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: accentColor.withOpacity(0.7), size: 16),
                ],
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubRow(Trainer trainer) {
    final int totalSpecies = PokedexDatabase.species.length;
    final int caught = trainer.caughtCount;
    final int badges = trainer.clearedGymIds.length;

    return Column(
      children: [
        // Row 1: Party, Bag, Pokédex
        Row(
          children: [
            _buildHubTile(
              onTap: () => _openPartyManagerModal(trainer),
              accentColor: Colors.redAccent,
              iconWidget: const Icon(Icons.catching_pokemon,
                  color: Colors.redAccent, size: 15),
              title: "Pokémon",
              subtitle: "${trainer.party.length}/6 Carried",
            ),
            const SizedBox(width: 7),
            _buildHubTile(
              onTap: () => _openItemsManagerModal(trainer),
              accentColor: Colors.amberAccent,
              iconWidget: const Icon(Icons.backpack_rounded,
                  color: Colors.amberAccent, size: 15),
              title: "Bag",
              subtitle: "${trainer.totalItems} Items",
            ),
            const SizedBox(width: 7),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PokedexScreen()),
                );
              },
              accentColor: const Color(0xFFFF5252),
              iconWidget: const PokeBallSymbol(size: 15, isCaught: true),
              title: "Pokédex",
              subtitle: "$caught/$totalSpecies Caught",
            ),
          ],
        ),
        const SizedBox(height: 7),

        // Row 2: Pokémon League, Poké Center, PC Boxes
        Row(
          children: [
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PokemonLeagueScreen()),
                );
              },
              accentColor: const Color(0xFFFFD54F),
              iconWidget: const Icon(Icons.military_tech_rounded,
                  color: Color(0xFFFFD54F), size: 15),
              title: "Pokémon League",
              subtitle: "$badges/8 Badges",
              subtitleColor: const Color(0xFFFFD54F),
            ),
            const SizedBox(width: 7),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PokemonCenterScreen()),
                );
              },
              accentColor: Colors.pinkAccent,
              iconWidget: const Icon(Icons.local_hospital_rounded,
                  color: Colors.pinkAccent, size: 15),
              title: "Poké Center",
              subtitle: "Heal • Mart • Lab",
              subtitleColor: Colors.pinkAccent.shade100,
            ),
            const SizedBox(width: 7),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PcStorageScreen()),
                );
              },
              accentColor: Colors.purpleAccent,
              iconWidget: const Icon(Icons.computer_rounded,
                  color: Colors.purpleAccent, size: 15),
              title: "PC Boxes",
              subtitle: "${trainer.totalPcPokemon}/${trainer.maxPcCapacity}",
              subtitleColor: Colors.purpleAccent.shade100,
            ),
          ],
        ),
        const SizedBox(height: 7),

        // Row 3: Expeditions (Unlocks at 8 Badges)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: trainer.isExpeditionsUnlocked
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ExpeditionsScreen()),
                    );
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Expeditions unlock after earning all 8 Gym Badges! ($badges/8 earned)"),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(13),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: trainer.isExpeditionsUnlocked
                      ? [
                          const Color(0xFF00ACC1).withOpacity(0.24),
                          const Color(0xEC101728),
                        ]
                      : [
                          const Color(0xD8111524),
                          const Color(0xE00B0E18),
                        ],
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: trainer.isExpeditionsUnlocked
                      ? Colors.cyanAccent.withOpacity(0.6)
                      : Colors.white12,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    trainer.isExpeditionsUnlocked
                        ? Icons.explore_rounded
                        : Icons.lock_rounded,
                    color: trainer.isExpeditionsUnlocked
                        ? Colors.cyanAccent
                        : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "EXPEDITIONS",
                          style: TextStyle(
                            color: trainer.isExpeditionsUnlocked
                                ? Colors.white
                                : Colors.white60,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Text(
                          trainer.isExpeditionsUnlocked
                              ? "4 Legendary Sites • Team Rocket • Master Ball Hunt"
                              : "Locked • Earn all 8 Badges to unlock ($badges/8)",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: trainer.isExpeditionsUnlocked
                                ? Colors.cyanAccent
                                : Colors.white38,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: trainer.isExpeditionsUnlocked
                        ? Colors.cyanAccent
                        : Colors.white24,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),

        // Row 4: Mystery Gift (Event Distributions & 16-Char Promo Codes)
        Builder(
          builder: (context) {
            final unclaimedCount =
                MysteryGiftService.unclaimedEvents(trainer).length;
            final hasPromoAvailable = !trainer
                .hasRedeemedGiftCode(MysteryGiftService.sinnohStarterCode);
            final alertCount = unclaimedCount + (hasPromoAvailable ? 1 : 0);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  SoundService.instance.playUiTap();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MysteryGiftScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(13),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1F1634), Color(0xFF151226)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: alertCount > 0
                          ? Colors.pinkAccent.withOpacity(0.55)
                          : Colors.white.withOpacity(0.14),
                      width: 1.1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.pinkAccent.withOpacity(0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.card_giftcard_rounded,
                          color: Colors.pinkAccent,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MYSTERY GIFT",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              unclaimedCount > 0
                                  ? "$unclaimedCount Event Distribution${unclaimedCount == 1 ? '' : 's'} Ready • Enter Gift Code"
                                  : "Check Event Gifts • Enter 16-Char Promo Code",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unclaimedCount > 0
                                    ? Colors.pinkAccent.shade100
                                    : Colors.white54,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (alertCount > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: Colors.pinkAccent.withOpacity(0.6),
                            ),
                          ),
                          child: Text(
                            "$alertCount NEW",
                            style: const TextStyle(
                              color: Colors.pinkAccent,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.pinkAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── 5. VERSUS LINK / FIST-BUMP DUEL BANNER ───────────────────────────────
  Widget _buildChallengeTrainerButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BumpScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFD32F2F),
                  Color(0xFFE64A19),
                  Color(0xFFFF6D00),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amberAccent.withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepOrange.shade900.withOpacity(0.55),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.24),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.sports_mma_rounded,
                        color: Colors.amberAccent, size: 19),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "FIST-BUMP LINK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "BATTLE OR TRADE POKÉMON",
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 8.8,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.double_arrow_rounded,
                      color: Colors.white, size: 17),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRivalsButton(Trainer trainer) {
    final int rivalCount = trainer.rivals.length;
    final int friends = trainer.friendCount;
    return SizedBox(
      width: 94,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RivalsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2542), Color(0xFF10172B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.cyanAccent.withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        color: Colors.cyanAccent, size: 15),
                    const SizedBox(width: 4),
                    const Text(
                      "RIVALS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  "$rivalCount • $friends ★",
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
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
                          label: const Text(
                            "OPEN PC",
                            style: TextStyle(
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

  void _useEvolutionStone(
    BuildContext parentContext,
    Trainer trainer,
    Item stoneItem,
  ) {
    final compatible = trainer.party
        .where((p) =>
            ItemDatabase.getStoneEvolutionTarget(stoneItem.id, p.species.id) !=
            null)
        .toList();

    if (compatible.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
              "No Pokémon in your party can evolve using ${stoneItem.name}."),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121624),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(stoneItem.icon, color: stoneItem.color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Use ${stoneItem.name}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select a party Pokémon to evolve:",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...compatible.map((mon) {
                final targetId = ItemDatabase.getStoneEvolutionTarget(
                    stoneItem.id, mon.species.id)!;
                final targetSpecies = PokedexDatabase.species[targetId];
                return InkWell(
                  onTap: () {
                    Navigator.pop(dlgCtx);
                    if (targetSpecies == null) return;
                    _executeStoneEvolution(
                        parentContext, trainer, mon, stoneItem, targetSpecies);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2033),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: stoneItem.color.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.network(
                            mon.spriteUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Image.network(
                              mon.staticSpriteUrl,
                              width: 42,
                              height: 42,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.catching_pokemon,
                                color: Colors.white54,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mon.nickname,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                "Lv. ${mon.level}",
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          targetSpecies?.name ?? "???",
                          style: TextStyle(
                            color: stoneItem.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeStoneEvolution(
    BuildContext parentContext,
    Trainer trainer,
    PokemonInstance mon,
    Item stoneItem,
    PokemonSpecies nextSpecies,
  ) async {
    if (trainer.getItemCount(stoneItem.id) <= 0) return;
    trainer.adjustItemCount(stoneItem.id, -1);
    final fromSpecies = mon.species;
    final oldName = mon.nickname;
    final List<Move> pendingEvoMoves = [];
    final evoMoves = mon.evolve(
      nextSpecies,
      PokedexDatabase.movesUnlockedAtExactLevel(nextSpecies, mon.level),
      pendingMovesOut: pendingEvoMoves,
    );
    trainer.markPokemonCaught(nextSpecies.id, isShiny: mon.isShiny);
    trainer.saveProgress();

    await EvolutionScreen.show(
      parentContext,
      fromSpecies: fromSpecies,
      toSpecies: nextSpecies,
      oldNickname: oldName,
      learnedMoves: evoMoves,
      isShiny: mon.isShiny,
    );
    if (mounted && pendingEvoMoves.isNotEmpty) {
      for (final newMove in pendingEvoMoves) {
        final outcome = await showMoveLearnDialog(
          this.context,
          pokemon: mon,
          newMove: newMove,
          recordOnSkip: true,
        );
        if (outcome.learned) {
          trainer.saveProgress();
        }
      }
      trainer.saveProgress();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _useBagMedicineOnPartyPokemon(
    BuildContext parentContext,
    Trainer trainer,
    Item medicineItem,
  ) {
    showDialog(
      context: parentContext,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121624),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(medicineItem.icon, color: medicineItem.color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "USE ${medicineItem.name.toUpperCase()} ON:",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trainer.party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, idx) {
                final mon = trainer.party[idx];
                final bool usable =
                    ItemDatabase.canUseMedicineOn(medicineItem.id, mon);
                final bool isPpItem =
                    ItemDatabase.isPpRestoreItem(medicineItem.id);
                final int curPp =
                    mon.moves.fold<int>(0, (s, m) => s + m.currentPp);
                final int maxPp =
                    mon.moves.fold<int>(0, (s, m) => s + m.maxPp);

                return InkWell(
                  onTap: usable
                      ? () async {
                          int? moveIndex;
                          if (ItemDatabase.isSingleMovePpItem(medicineItem.id)) {
                            moveIndex = await showMovePpPickerDialog(
                              dlgCtx,
                              pokemon: mon,
                              item: medicineItem,
                            );
                            if (moveIndex == null) return;
                          }
                          final String msg =
                              ItemDatabase.applyMedicineToPokemon(
                            itemId: medicineItem.id,
                            targetMon: mon,
                            moveIndex: moveIndex,
                          );
                          trainer.adjustItemCount(medicineItem.id, -1);
                          trainer.saveProgress();
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) setState(() {});
                          if (parentContext.mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: usable ? 1.0 : 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2033),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: usable
                              ? medicineItem.color.withOpacity(0.55)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Image.network(
                            mon.spriteUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              color: Colors.white54,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${mon.nickname} • Lv.${mon.level}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                HpBar(
                                  currentHp: mon.currentHp,
                                  maxHp: mon.maxHp,
                                ),
                                Text(
                                  isPpItem
                                      ? "PP $curPp/$maxPp • HP ${mon.currentHp}/${mon.maxHp}"
                                      : "HP ${mon.currentHp}/${mon.maxHp}${mon.status != StatusCondition.none ? ' • ${mon.status.shortLabel}' : ''}",
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            usable ? "USE" : "N/A",
                            style: TextStyle(
                              color: usable
                                  ? medicineItem.color
                                  : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white60)),
            ),
          ],
        );
      },
    );
  }

  // ─── ITEMS MANAGER MODAL ──────────────────────────────────────────────────
  void _openItemsManagerModal(Trainer rootTrainer) {
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
            // Only display Bag-usable items the player possesses (fossils live in Pokémon Lab)
            final availableItems = ItemDatabase.allItems.values
                .where((item) =>
                    !item.isFossil && trainer.getItemCount(item.id) > 0)
                .toList();

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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MANAGE ITEMS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              "${trainer.totalItems} total items in Trainer Bag",
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildUtilityToggleRow(trainer),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          trainer.claimSupplyDrop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Claimed Supply Drop: +5 Poké Balls, +2 Great Balls, +1 Ultra Ball, +3 Potions, +1 Revive!",
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.card_giftcard, size: 18),
                        label: const Text(
                          "CLAIM POKÉ MART SUPPLY DROP (+ITEMS)",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: availableItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      size: 48, color: Colors.white24),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Your Bag is empty!",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Claim a Poké Mart supply drop above, visit the Poké Mart, or explore to get item drops from wild Pokémon encounters.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: availableItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (c, idx) {
                                final item = availableItems[idx];
                                final count = trainer.getItemCount(item.id);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A2033),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: item.color.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: item.color.withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: item.isBall
                                              ? PokeBallSpriteWidget(
                                                  ballType: item.id, size: 30)
                                              : Icon(item.icon,
                                                  color: item.color, size: 24),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: item.color
                                                        .withOpacity(0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: item.color
                                                          .withOpacity(0.6),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.rarity.name.toUpperCase(),
                                                    style: TextStyle(
                                                      color: item.color,
                                                      fontSize: 7.5,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black38,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    "x$count",
                                                    style: TextStyle(
                                                      color: count > 0
                                                          ? item.color
                                                          : Colors.white38,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 11),
                                            ),
                                            if (item.isMedicine ||
                                                item.id == 'leppa_berry') ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 28,
                                                child: OutlinedButton(
                                                  onPressed: count > 0
                                                      ? () =>
                                                          _useBagMedicineOnPartyPokemon(
                                                            ctx,
                                                            trainer,
                                                            item,
                                                          )
                                                      : null,
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: item.color,
                                                    side: BorderSide(color: item.color.withOpacity(0.6)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: const Text(
                                                    "Use on Pokémon",
                                                    style: TextStyle(
                                                        fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ] else if (item.isEvolutionStone) ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 28,
                                                child: ElevatedButton.icon(
                                                  onPressed: count > 0
                                                      ? () => _useEvolutionStone(ctx, trainer, item)
                                                      : null,
                                                  icon: const Icon(Icons.auto_awesome, size: 14),
                                                  label: const Text(
                                                    "Evolve Pokémon",
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.color.withOpacity(0.25),
                                                    foregroundColor: item.color,
                                                    side: BorderSide(color: item.color.withOpacity(0.7)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ] else if (item.isTm) ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 28,
                                                child: ElevatedButton.icon(
                                                  onPressed: count > 0
                                                      ? () => _useTmFromBag(
                                                            ctx,
                                                            trainer,
                                                            item,
                                                          )
                                                      : null,
                                                  icon: const Icon(
                                                      Icons.album_rounded,
                                                      size: 14),
                                                  label: const Text(
                                                    "Teach Pokémon",
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: item.color
                                                        .withOpacity(0.24),
                                                    foregroundColor: item.color,
                                                    side: BorderSide(
                                                        color: item.color
                                                            .withOpacity(0.7)),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8)),
                                                  ),
                                                ),
                                              ),
                                            ] else if (item.isHeldItem || item.isBerry) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.isBerry
                                                      ? "Held item: auto-consumed in battle or equip via Pokémon"
                                                      : "Held item: equip via Pokémon to boost battle power",
                                                  style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          IconButton(
                                            tooltip: "Add 1",
                                            onPressed: () => trainer.adjustItemCount(item.id, 1),
                                            icon: const Icon(Icons.add_circle_outline,
                                                color: Colors.white70, size: 20),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          IconButton(
                                            tooltip: "Discard 1",
                                            onPressed: count > 0
                                                ? () => trainer.adjustItemCount(item.id, -1)
                                                : null,
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: count > 0 ? Colors.redAccent : Colors.white24,
                                              size: 20,
                                            ),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                        ],
                                      ),
                                    ],
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

  void _useTmFromBag(
    BuildContext parentContext,
    Trainer trainer,
    Item tmItem,
  ) {
    final tmMove = TmService.getMoveForTm(tmItem);
    if (tmMove == null) return;

    showDialog(
      context: parentContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(tmItem.icon, color: tmItem.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Teach ${tmItem.name}",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dlgCtx).size.height * 0.48,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trainer.party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final mon = trainer.party[idx];
                final compatible = TmService.canLearnTm(mon.species, tmItem);
                final known = mon.learnedMoveIds.contains(tmMove.id);
                final canTeach = compatible && !known;
                return InkWell(
                  onTap: canTeach
                      ? () async {
                          Navigator.pop(dlgCtx);
                          final outcome = await showMoveLearnDialog(
                            this.context,
                            pokemon: mon,
                            newMove: tmMove,
                            recordOnSkip: false,
                            headerNote:
                                "Use 1x ${tmItem.name} to teach ${tmMove.name} to ${mon.nickname}?",
                          );
                          if (outcome.learned) {
                            trainer.adjustItemCount(tmItem.id, -1);
                            trainer.saveProgress();
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    outcome.forgottenMove != null
                                        ? "${mon.nickname} forgot ${outcome.forgottenMove!.name} and learned ${tmMove.name}!"
                                        : "${mon.nickname} learned ${tmMove.name}!",
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: canTeach ? 1.0 : 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2033),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: canTeach
                              ? tmItem.color.withOpacity(0.55)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Image.network(
                            mon.spriteUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              color: Colors.white54,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${mon.nickname} • Lv.${mon.level}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5),
                                ),
                                Text(
                                  known
                                      ? "Already learned ${tmMove.name}"
                                      : (compatible
                                          ? "Compatible"
                                          : "Not compatible"),
                                  style: TextStyle(
                                    color: canTeach
                                        ? Colors.cyanAccent
                                        : Colors.white54,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            known ? "KNOWN" : (compatible ? "TEACH" : "N/A"),
                            style: TextStyle(
                              color: canTeach ? tmItem.color : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }
}
