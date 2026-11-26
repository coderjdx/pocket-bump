import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/bump_service.dart';
import '../services/pokedex_database.dart';
import '../services/pvp_link_service.dart';
import '../services/pvp_transport.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import 'battle_screen.dart';
import 'double_battle_screen.dart';
import 'rivals_screen.dart';
import 'trade_screen.dart';

enum _BumpLinkState {
  scanning,
  linking,
  matched,
  timedOut,
}

class BumpScreen extends StatefulWidget {
  const BumpScreen({super.key});

  @override
  State<BumpScreen> createState() => _BumpScreenState();
}

class _BumpScreenState extends State<BumpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  PvpLobbyMatchmaker? _matchmaker;
  PvpMatchSession? _matchedSession;

  _BumpLinkState _linkState = _BumpLinkState.scanning;
  BumpLinkMode _selectedMode = BumpLinkMode.battle;
  List<NearbyRadarTrainer> _nearbyTrainers = const [];

  bool _sensorReceivingData = false;
  double _liveMagnitude = 0.0;
  double _liveDelta = 0.0;
  DateTime _lastUiMotionUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  String _motionPermissionState = 'granted';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    if (kIsWeb) {
      _motionPermissionState = getWebMotionPermissionState();
      _requestMotionPermission();
    }

    BumpService.startListening(
      onMotionUpdate: (magnitude, delta) {
        if (!mounted) return;
        final now = DateTime.now();
        final shouldRefresh = !_sensorReceivingData ||
            now.difference(_lastUiMotionUpdate).inMilliseconds >= 90;
        if (shouldRefresh) {
          _lastUiMotionUpdate = now;
          setState(() {
            _sensorReceivingData = true;
            _motionPermissionState = 'granted';
            _liveMagnitude = magnitude;
            _liveDelta = delta;
          });
        }
      },
      onBump: (_) {
        if (!mounted) return;
        _triggerBumpLink();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initMatchmaker();
    });
  }

  Future<void> _requestMotionPermission() async {
    if (!kIsWeb) return;
    final granted = await requestWebMotionPermission();
    if (!mounted) return;
    setState(() {
      _motionPermissionState =
          granted ? 'granted' : getWebMotionPermissionState();
    });
  }

  void _initMatchmaker() {
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (trainer.party.isEmpty) {
      return;
    }

    _matchmaker = PvpLobbyMatchmaker(
      trainer: trainer,
      mode: _selectedMode,
      onNearbyChanged: (nearby) {
        if (!mounted) return;
        setState(() {
          _nearbyTrainers = nearby;
        });
      },
      onOfferTimeout: () {
        if (!mounted) return;
        if (_linkState == _BumpLinkState.linking) {
          setState(() {
            _linkState = _BumpLinkState.timedOut;
          });
        }
      },
      onMatched: (session) {
        _handleMatchedSession(session);
      },
    )..start();
  }

  void _selectMode(BumpLinkMode newMode) {
    if (_selectedMode == newMode ||
        _linkState == _BumpLinkState.linking ||
        _linkState == _BumpLinkState.matched) {
      return;
    }
    SoundService.instance.playUiTap();
    setState(() {
      _selectedMode = newMode;
      if (_linkState == _BumpLinkState.timedOut) {
        _linkState = _BumpLinkState.scanning;
      }
    });
    _matchmaker?.setMode(newMode);
  }

  void _triggerBumpLink() {
    if (_linkState == _BumpLinkState.linking ||
        _linkState == _BumpLinkState.matched) {
      return;
    }
    final trainer = Provider.of<Trainer>(context, listen: false);
    if (trainer.party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You need at least one Pokémon in your party!"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_selectedMode.isBattle && !trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "All Pokémon in your party have fainted! Visit the Pokémon Center to heal your party."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_selectedMode == BumpLinkMode.doubleBattle &&
        trainer.party.where((p) => !p.isFainted).length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Doubles Battle requires at least 2 conscious Pokémon in your party!"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _requestMotionPermission();

    if (_matchmaker == null) {
      _initMatchmaker();
    }

    setState(() {
      _linkState = _BumpLinkState.linking;
    });

    HapticFeedback.heavyImpact();
    _matchmaker?.triggerBumpOffer();
  }

  void _handleMatchedSession(PvpMatchSession session) {
    if (!mounted || _linkState == _BumpLinkState.matched) {
      session.dispose();
      return;
    }
    BumpService.stopListening();
    _matchedSession = session;

    setState(() {
      _linkState = _BumpLinkState.matched;
    });
    SoundService.instance.playBumpChime();

    HapticFeedback.heavyImpact();

    if (session.mode == BumpLinkMode.trade) {
      final tradeSession = PvpTradeSession.fromMatch(session);
      _matchedSession = null;
      session.dispose();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) {
          tradeSession.dispose();
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TradeScreen(session: tradeSession),
          ),
        );
      });
      return;
    }

    Future.wait([
      Future.delayed(const Duration(milliseconds: 950)),
      precacheImage(
        const AssetImage('assets/images/battle_bg_pvp_arena.png'),
        context,
      ).catchError((_) {}),
    ]).then((_) {
      if (!mounted) {
        session.dispose();
        return;
      }

      final team = session.opponentTeam;
      final PokemonInstance firstOpp = team.firstWhere(
        (p) => !p.isFainted,
        orElse: () => team.first,
      );

      // Transfer session lifecycle to BattleScreen.
      _matchedSession = null;
      SoundService.instance.playBumpChime();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => session.mode == BumpLinkMode.doubleBattle
              ? DoubleBattleScreen(
                  pvpSession: session,
                  opponentTeam: team,
                  trainerName: session.opponentName,
                  trainerTitle: session.opponentTitle,
                  opponentSpriteId: session.opponentSpriteId,
                  battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
                  bgmCategory: BattleBgmCategory.special,
                )
              : BattleScreen(
                  pvpSession: session,
                  opponentPokemon: firstOpp,
                  opponentTeam: team,
                  isWild: false,
                  trainerName: session.opponentName,
                  trainerTitle: session.opponentTitle,
                  opponentSpriteId: session.opponentSpriteId,
                  battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
                  bgmCategory: BattleBgmCategory.special,
                ),
        ),
      );
    });
  }

  void _launchSoloPracticeBattle() {
    if (_linkState == _BumpLinkState.matched) return;
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
    final bool isDoublesPractice = _selectedMode == BumpLinkMode.doubleBattle;
    if (isDoublesPractice &&
        trainer.party.where((p) => !p.isFainted).length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Doubles Practice requires at least 2 conscious Pokémon in your party!"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    BumpService.stopListening();
    _matchmaker?.dispose();
    _matchmaker = null;

    setState(() {
      _linkState = _BumpLinkState.matched;
    });
    SoundService.instance.playBumpChime();

    Future.wait([
      Future.delayed(const Duration(milliseconds: 750)),
      precacheImage(
        const AssetImage('assets/images/battle_bg_pvp_arena.png'),
        context,
      ).catchError((_) {}),
    ]).then((_) {
      if (!mounted) return;
      final playerLevel = trainer.leadPokemon?.level ?? 5;

      if (isDoublesPractice) {
        final rivalTeam = [
          for (int i = 0; i < 4; i++)
            PokedexDatabase.generateRivalPokemon(playerLevel: playerLevel),
        ];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DoubleBattleScreen(
              opponentTeam: rivalTeam,
              trainerName: 'Rival Blue',
              trainerTitle: 'Doubles Practice',
              trainerIntroLine:
                  "Two on two? Hope your team's synergy can keep up with mine!",
              trainerDefeatLine:
                  "Not bad at all! Next time I'll bring an even stronger pair!",
              opponentSpriteId: 'male_blue',
              battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
              bgmCategory: BattleBgmCategory.special,
            ),
          ),
        );
      } else {
        final rivalMon =
            PokedexDatabase.generateRivalPokemon(playerLevel: playerLevel);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BattleScreen(
              opponentPokemon: rivalMon,
              isWild: false,
              trainerName: 'Rival Blue',
              trainerIntroLine:
                  "Hey! Think your team's tough enough? Smell ya if you lose!",
              trainerDefeatLine:
                  "What?! You actually beat me here? Next time I won't go easy!",
              opponentSpriteId: 'male_blue',
              battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
              bgmCategory: BattleBgmCategory.special,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    BumpService.stopListening();
    _matchmaker?.dispose();
    _matchedSession?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColorForState() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        return PokeColors.pokeGreen;
      case _BumpLinkState.linking:
        return PokeColors.badgeGoldDark;
      case _BumpLinkState.timedOut:
        return PokeColors.bagOrange;
      case _BumpLinkState.scanning:
        final hasMatchingNearby =
            _nearbyTrainers.any((t) => t.mode == _selectedMode);
        if (hasMatchingNearby) return PokeColors.linkTeal;
        return _selectedMode == BumpLinkMode.trade
            ? PokeColors.linkTeal
            : PokeColors.pokeRed;
    }
  }

  String _topBadgeText() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        final verb =
            _selectedMode == BumpLinkMode.trade ? "TRADING WITH" : "VS";
        return "LINK ESTABLISHED • $verb ${_matchedSession?.opponentName.toUpperCase() ?? 'TRAINER'}";
      case _BumpLinkState.linking:
        return "FIST-BUMP DETECTED • PAIRING DEVICES";
      case _BumpLinkState.timedOut:
        return "NO PARTNER RESPONDED";
      case _BumpLinkState.scanning:
        if (_nearbyTrainers.isNotEmpty) {
          final matching =
              _nearbyTrainers.where((t) => t.mode == _selectedMode);
          if (matching.isNotEmpty) {
            final names = matching.map((t) => t.name).join(', ');
            return "NEARBY ${_selectedMode.name.toUpperCase()} TRAINER: ${names.toUpperCase()}";
          }
          final first = _nearbyTrainers.first;
          return "NEARBY: ${first.name.toUpperCase()} (${first.mode.name.toUpperCase()} MODE)";
        }
        return _selectedMode == BumpLinkMode.trade
            ? "TRADE LINK • SCANNING NEARBY"
            : (_selectedMode == BumpLinkMode.doubleBattle
                ? "2v2 DOUBLES • SCANNING NEARBY"
                : "1v1 SINGLES • SCANNING NEARBY");
    }
  }

  String _headlineText() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        return "LINK ESTABLISHED!";
      case _BumpLinkState.linking:
        return _selectedMode == BumpLinkMode.trade
            ? "BUMP DETECTED! OPENING TRADE LINK..."
            : (_selectedMode == BumpLinkMode.doubleBattle
                ? "BUMP DETECTED! LINKING 2v2 DOUBLES..."
                : "BUMP DETECTED! LINKING WITH NEARBY TRAINER...");
      case _BumpLinkState.timedOut:
        return "No partner in ${_selectedMode.displayLabel} mode responded";
      case _BumpLinkState.scanning:
        final matching =
            _nearbyTrainers.where((t) => t.mode == _selectedMode).toList();
        if (matching.isNotEmpty) {
          return "${matching.first.name.toUpperCase()} READY — FIST-BUMP NOW!";
        }
        if (_nearbyTrainers.isNotEmpty) {
          final other = _nearbyTrainers.first;
          return "${other.name.toUpperCase()} IS IN ${other.mode.displayLabel.toUpperCase()}";
        }
        return _selectedMode == BumpLinkMode.trade
            ? "FIST-BUMP TO TRADE POKÉMON!"
            : "HOLD PHONES & FIST-BUMP!";
    }
  }

  String _sublineText() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        return _selectedMode == BumpLinkMode.trade
            ? "Opening secure Fist-Bump Link Trade room..."
            : "Synchronizing Kanto Battle Stadium arena...";
      case _BumpLinkState.linking:
        return _selectedMode == BumpLinkMode.trade
            ? "Pairing trainers for 1-for-1 Link Trade (7s window)..."
            : "Exchanging team rosters over VS Link (7s window)...";
      case _BumpLinkState.timedOut:
        return "Make sure both phones have ${_selectedMode.displayLabel} selected, then give a firm fist bump.";
      case _BumpLinkState.scanning:
        if (_selectedMode == BumpLinkMode.trade) {
          return "Select TRADE on both phones, then give a firm fist bump to swap Pokémon and trigger Link Trade evolutions!";
        }
        if (_selectedMode == BumpLinkMode.doubleBattle) {
          return "Select BATTLE • 2v2 DOUBLES on both phones, then give a firm fist bump for a Doubles match!";
        }
        return "Select BATTLE • 1v1 SINGLES on both phones, then give a firm fist bump to battle each other's team.";
    }
  }

  Widget _buildModeSelector() {
    final bool locked = _linkState == _BumpLinkState.linking ||
        _linkState == _BumpLinkState.matched;
    final bool battleSelected = _selectedMode.isBattle;
    final bool doublesSelected = _selectedMode == BumpLinkMode.doubleBattle;
    final bool tradeSelected = _selectedMode == BumpLinkMode.trade;

    Widget formatPill({
      required String label,
      required bool active,
      required VoidCallback? onTap,
    }) {
      return Expanded(
        child: Material(
          color: active ? PokeColors.pokeRedDark : PokeColors.cardWhite,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? PokeColors.pokeRedDark
                      : PokeColors.frameBorderSoft,
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : PokeColors.inkDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: PokePortraitButton(
                label: "BATTLE LINK",
                subtitle: battleSelected
                    ? (doublesSelected ? "2v2 DOUBLES" : "1v1 SINGLES")
                    : "VS TEAM",
                icon: Icons.sports_mma_rounded,
                topColor: battleSelected
                    ? PokeColors.pokeRed
                    : PokeColors.inkSubtle,
                bottomColor: battleSelected
                    ? PokeColors.pokeRedDark
                    : PokeColors.frameBorder,
                height: 100,
                iconSize: 30,
                selected: battleSelected,
                locked: locked && !battleSelected,
                badgeText: battleSelected
                    ? (doublesSelected ? "2v2" : "1v1")
                    : null,
                onTap: locked
                    ? null
                    : () => _selectMode(doublesSelected
                        ? BumpLinkMode.doubleBattle
                        : BumpLinkMode.battle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PokePortraitButton(
                label: "TRADE LINK",
                subtitle: tradeSelected ? "ACTIVE MODE" : "SWAP & EVOLVE",
                icon: Icons.swap_horiz_rounded,
                topColor: tradeSelected
                    ? PokeColors.linkTeal
                    : PokeColors.inkSubtle,
                bottomColor: tradeSelected
                    ? PokeColors.linkTealDark
                    : PokeColors.frameBorder,
                height: 100,
                iconSize: 30,
                selected: tradeSelected,
                locked: locked && !tradeSelected,
                badgeText: tradeSelected ? "ON" : null,
                onTap: locked ? null : () => _selectMode(BumpLinkMode.trade),
              ),
            ),
          ],
        ),
        if (battleSelected) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              formatPill(
                label: "1v1 SINGLES",
                active: !doublesSelected,
                onTap: locked ? null : () => _selectMode(BumpLinkMode.battle),
              ),
              const SizedBox(width: 8),
              formatPill(
                label: "2v2 DOUBLES",
                active: doublesSelected,
                onTap: locked
                    ? null
                    : () => _selectMode(BumpLinkMode.doubleBattle),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMotionMeterBanner() {
    final bool needsIosTap = kIsWeb &&
        !_sensorReceivingData &&
        _motionPermissionState != 'granted';
    final bool denied = kIsWeb &&
        !_sensorReceivingData &&
        _motionPermissionState == 'denied';

    final Color badgeColor = _sensorReceivingData
        ? PokeColors.pokeGreenDark
        : (denied ? PokeColors.pokeRed : PokeColors.badgeGoldDark);

    final String label = _sensorReceivingData
        ? "SENSOR ARMED • LIVE MOTION (${_liveMagnitude.toStringAsFixed(1)} m/s² • Δ${_liveDelta.toStringAsFixed(1)})"
        : (denied
            ? "MOTION PERMISSION DENIED • TAP TO RETRY OR USE LINK BUTTON"
            : (needsIosTap
                ? "TAP RADAR TO ENABLE iOS MOTION SENSOR"
                : "MOTION SENSOR STANDBY • MOVE OR TAP TO PAIR"));

    final double barProgress = _sensorReceivingData
        ? (_liveDelta / BumpService.jerkThreshold).clamp(0.08, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: _requestMotionPermission,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: PokeDecorations.card(
          fill: PokeColors.creamSurface.withOpacity(0.95),
          border: badgeColor.withOpacity(0.65),
          radius: 12,
          borderWidth: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _sensorReceivingData
                      ? Icons.sensors_rounded
                      : Icons.touch_app_rounded,
                  size: 16,
                  color: badgeColor,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            if (_sensorReceivingData) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: barProgress,
                  minHeight: 5,
                  backgroundColor: PokeColors.panelSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    barProgress > 0.75
                        ? PokeColors.badgeGold
                        : PokeColors.pokeGreen,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColorForState();
    final bool isPromptingIos = kIsWeb &&
        !_sensorReceivingData &&
        _motionPermissionState != 'granted';

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (kIsWeb && _motionPermissionState != 'granted') {
          _requestMotionPermission();
        }
      },
      child: Scaffold(
        backgroundColor: PokeColors.canvasCream,
        extendBodyBehindAppBar: true,
        appBar: buildPokeAppBar(
          context: context,
          title: "FIST-BUMP LINK",
          barColor: PokeColors.linkTeal,
          bottomBorderColor: PokeColors.linkTealDark,
          actions: [
            IconButton(
              tooltip: "Rivals & Friends",
              onPressed: () {
                SoundService.instance.playUiTap();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RivalsScreen()),
                );
              },
              icon: const Icon(Icons.people_alt_rounded,
                  color: Colors.white, size: 22),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PokeBackdrop(
              assetPath: 'assets/images/bg_bump_radar.png',
              topOpacity: 0.24,
              midOpacity: 0.48,
              bottomOpacity: 0.88,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 8),

                    // Top VS Link Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.cardWhite,
                        border: statusColor,
                        radius: 20,
                        borderWidth: 1.8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.55),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _topBadgeText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    _buildMotionMeterBanner(),

                    const Spacer(),

                    // Interactive Animated Pulsing VS Link Radar
                    GestureDetector(
                      onTap: () {
                        if (isPromptingIos) {
                          _requestMotionPermission();
                        } else {
                          _triggerBumpLink();
                        }
                      },
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 176 + (_pulseController.value * 54),
                                  height: 176 + (_pulseController.value * 54),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: statusColor.withOpacity(
                                          0.55 * (1 - _pulseController.value)),
                                      width: 3,
                                    ),
                                    color: statusColor.withOpacity(
                                        0.16 * (1 - _pulseController.value)),
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: 146,
                              height: 146,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    statusColor,
                                    PokeColors.darken(statusColor, 0.24),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.38),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _linkState == _BumpLinkState.matched
                                    ? Icons.check_circle_outline_rounded
                                    : (_linkState == _BumpLinkState.linking
                                        ? Icons.wifi_tethering_rounded
                                        : (_selectedMode == BumpLinkMode.trade
                                            ? Icons.swap_horiz_rounded
                                            : Icons.sports_mma_rounded)),
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.creamSurface.withOpacity(0.96),
                        border: statusColor.withOpacity(0.65),
                        radius: 16,
                        borderWidth: 1.6,
                      ),
                      child: Column(
                        children: [
                          Text(
                            _headlineText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _sublineText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: PokeColors.inkMuted,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    if (_linkState == _BumpLinkState.timedOut) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _triggerBumpLink,
                          icon: const Icon(Icons.refresh_rounded, size: 19),
                          label: const Text(
                            "TRY BUMP AGAIN",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12.5,
                              letterSpacing: 0.7,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PokeColors.pokeRed,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _launchSoloPracticeBattle,
                          icon: const Icon(Icons.smart_toy_outlined,
                              color: PokeColors.badgeGoldDark, size: 17),
                          label: Text(
                            _selectedMode == BumpLinkMode.doubleBattle
                                ? "PRACTICE VS RIVAL BLUE (2v2 DOUBLES)"
                                : "PRACTICE VS RIVAL BLUE (SOLO AI)",
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: PokeColors.cardWhite,
                            side: const BorderSide(
                              color: PokeColors.badgeGold,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _linkState == _BumpLinkState.linking ||
                                  _linkState == _BumpLinkState.matched
                              ? null
                              : _triggerBumpLink,
                          icon: Icon(
                            _linkState == _BumpLinkState.linking
                                ? Icons.sync_rounded
                                : Icons.link_rounded,
                            size: 19,
                          ),
                          label: Text(
                            _linkState == _BumpLinkState.linking
                                ? "SEARCHING FOR NEARBY TRAINER..."
                                : (_selectedMode == BumpLinkMode.trade
                                    ? "BUMP / PAIR FOR LINK TRADE"
                                    : "BUMP / PAIR FOR LINK BATTLE"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.6,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _selectedMode == BumpLinkMode.trade
                                    ? PokeColors.linkTeal
                                    : PokeColors.pokeRed,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: PokeColors.panelSoft,
                            disabledForegroundColor: PokeColors.inkMuted,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: _linkState == _BumpLinkState.linking ||
                                  _linkState == _BumpLinkState.matched
                              ? null
                              : _launchSoloPracticeBattle,
                          icon: const Icon(Icons.smart_toy_outlined,
                              color: PokeColors.pokeBlueDark, size: 16),
                          label: Text(
                            _selectedMode == BumpLinkMode.doubleBattle
                                ? "PRACTICE VS RIVAL BLUE (2v2 DOUBLES)"
                                : "PRACTICE VS RIVAL BLUE (SOLO AI)",
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: PokeColors.cardWhite,
                            side: const BorderSide(
                              color: PokeColors.frameBorderSoft,
                              width: 1.4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
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
