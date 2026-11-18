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
import 'battle_screen.dart';
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
    if (_selectedMode == BumpLinkMode.battle && !trainer.hasConsciousPokemon) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "All Pokémon in your party have fainted! Visit the Pokémon Center to heal your party."),
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

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            pvpSession: session,
            opponentPokemon: firstOpp,
            opponentTeam: team,
            isWild: false,
            trainerName: session.opponentName,
            trainerTitle: session.opponentTitle,
            opponentSpriteId: session.opponentSpriteId,
            battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
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

    BumpService.stopListening();
    _matchmaker?.dispose();
    _matchmaker = null;

    setState(() {
      _linkState = _BumpLinkState.matched;
    });

    Future.wait([
      Future.delayed(const Duration(milliseconds: 750)),
      precacheImage(
        const AssetImage('assets/images/battle_bg_pvp_arena.png'),
        context,
      ).catchError((_) {}),
    ]).then((_) {
      if (!mounted) return;
      final playerLevel = trainer.leadPokemon?.level ?? 5;
      final rivalMon =
          PokedexDatabase.generateRivalPokemon(playerLevel: playerLevel);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            opponentPokemon: rivalMon,
            isWild: false,
            trainerName: 'Rival Blue',
            opponentSpriteId: 'male_blue',
            battleBackgroundAsset: 'assets/images/battle_bg_pvp_arena.png',
          ),
        ),
      );
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
        return const Color(0xFF34EB8C);
      case _BumpLinkState.linking:
        return Colors.amberAccent;
      case _BumpLinkState.timedOut:
        return Colors.orangeAccent;
      case _BumpLinkState.scanning:
        final hasMatchingNearby =
            _nearbyTrainers.any((t) => t.mode == _selectedMode);
        if (hasMatchingNearby) return Colors.cyanAccent;
        return _selectedMode == BumpLinkMode.trade
            ? Colors.tealAccent
            : Colors.redAccent;
    }
  }

  String _topBadgeText() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        final verb = _selectedMode == BumpLinkMode.trade ? "TRADING WITH" : "VS";
        return "LINK ESTABLISHED • $verb ${_matchedSession?.opponentName.toUpperCase() ?? 'TRAINER'}";
      case _BumpLinkState.linking:
        return "FIST-BUMP DETECTED • PAIRING DEVICES";
      case _BumpLinkState.timedOut:
        return "NO PARTNER RESPONDED";
      case _BumpLinkState.scanning:
        if (_nearbyTrainers.isNotEmpty) {
          final matching = _nearbyTrainers.where((t) => t.mode == _selectedMode);
          if (matching.isNotEmpty) {
            final names = matching.map((t) => t.name).join(', ');
            return "NEARBY ${_selectedMode.name.toUpperCase()} TRAINER: ${names.toUpperCase()}";
          }
          final first = _nearbyTrainers.first;
          return "NEARBY: ${first.name.toUpperCase()} (${first.mode.name.toUpperCase()} MODE)";
        }
        return _selectedMode == BumpLinkMode.trade
            ? "TRADE LINK • SCANNING NEARBY"
            : "BATTLE LINK • SCANNING NEARBY";
    }
  }

  String _headlineText() {
    switch (_linkState) {
      case _BumpLinkState.matched:
        return "LINK ESTABLISHED!";
      case _BumpLinkState.linking:
        return _selectedMode == BumpLinkMode.trade
            ? "BUMP DETECTED! OPENING TRADE LINK..."
            : "BUMP DETECTED! LINKING WITH NEARBY TRAINER...";
      case _BumpLinkState.timedOut:
        return "No partner in ${_selectedMode == BumpLinkMode.trade ? 'Trade' : 'Battle'} mode responded";
      case _BumpLinkState.scanning:
        final matching =
            _nearbyTrainers.where((t) => t.mode == _selectedMode).toList();
        if (matching.isNotEmpty) {
          return "${matching.first.name.toUpperCase()} READY — FIST-BUMP NOW!";
        }
        if (_nearbyTrainers.isNotEmpty) {
          final other = _nearbyTrainers.first;
          return "${other.name.toUpperCase()} IS IN ${other.mode.name.toUpperCase()} MODE";
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
        return "Make sure both phones have ${_selectedMode == BumpLinkMode.trade ? 'Trade' : 'Battle'} mode selected, then give a firm fist bump.";
      case _BumpLinkState.scanning:
        return _selectedMode == BumpLinkMode.trade
            ? "Select TRADE on both phones, then give a firm fist bump to swap Pokémon and trigger Link Trade evolutions!"
            : "Select BATTLE on both phones, then give a firm fist bump to battle each other's team.";
    }
  }

  Widget _buildModeSelector() {
    final bool locked = _linkState == _BumpLinkState.linking ||
        _linkState == _BumpLinkMode.matched;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xE00C101C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTab(
              mode: BumpLinkMode.battle,
              label: "BATTLE",
              icon: Icons.sports_mma_rounded,
              activeColor: const Color(0xFFE53935),
              locked: locked,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeTab(
              mode: BumpLinkMode.trade,
              label: "TRADE",
              icon: Icons.swap_horiz_rounded,
              activeColor: const Color(0xFF00ACC1),
              locked: locked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required BumpLinkMode mode,
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool locked,
  }) {
    final bool selected = _selectedMode == mode;
    return GestureDetector(
      onTap: locked ? null : () => _selectMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.24) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? activeColor : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
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
        ? const Color(0xFF34EB8C)
        : (denied ? Colors.redAccent : Colors.amberAccent);

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
        decoration: BoxDecoration(
          color: const Color(0xE60D111E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withOpacity(0.55)),
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
                  size: 15,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    barProgress > 0.75
                        ? Colors.amberAccent
                        : const Color(0xFF34EB8C),
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
        backgroundColor: const Color(0xFF0C0E18),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: const Color(0xCC0D0E18),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "LINK RADAR • FIST-BUMP",
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/bg_bump_radar.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0D18).withOpacity(0.76),
                    const Color(0xFF0D101E).withOpacity(0.58),
                    const Color(0xFF080A12).withOpacity(0.92),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Column(
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 8),

                    // Top VS Link Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xE00C101C),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: statusColor.withOpacity(0.65)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: statusColor,
                              boxShadow: [
                                BoxShadow(color: statusColor, blurRadius: 6),
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
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
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
                                  width: 196 + (_pulseController.value * 52),
                                  height: 196 + (_pulseController.value * 52),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: statusColor.withOpacity(
                                          0.35 * (1 - _pulseController.value)),
                                      width: 2,
                                    ),
                                    color: statusColor.withOpacity(
                                        0.12 * (1 - _pulseController.value)),
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: 162,
                              height: 162,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: _linkState == _BumpLinkState.matched
                                      ? [
                                          const Color(0xFF1D6B42),
                                          const Color(0xFF0E291C),
                                        ]
                                      : [
                                          const Color(0xFF281825),
                                          const Color(0xFF101220),
                                        ],
                                ),
                                border: Border.all(
                                  color: statusColor,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.42),
                                    blurRadius: 24,
                                    spreadRadius: 4,
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
                                size: 68,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xE6111422),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _headlineText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              color: statusColor == Colors.redAccent
                                  ? Colors.white
                                  : statusColor,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _sublineText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
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
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _triggerBumpLink,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text(
                            "TRY BUMP AGAIN",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.7,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
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
                              color: Colors.amberAccent, size: 16),
                          label: const Text(
                            "PRACTICE VS RIVAL BLUE (SOLO AI)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xDD141828),
                            side: BorderSide(
                                color: Colors.amberAccent.withOpacity(0.45)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _linkState == _BumpLinkState.linking ||
                                  _linkState == _BumpLinkState.matched
                              ? null
                              : _triggerBumpLink,
                          icon: Icon(
                            _linkState == _BumpLinkState.linking
                                ? Icons.sync_rounded
                                : Icons.link_rounded,
                            color: Colors.black87,
                            size: 18,
                          ),
                          label: Text(
                            _linkState == _BumpLinkState.linking
                                ? "SEARCHING FOR NEARBY TRAINER..."
                                : (_selectedMode == BumpLinkMode.trade
                                    ? "BUMP / PAIR FOR LINK TRADE"
                                    : "BUMP / PAIR FOR LINK BATTLE"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFD54F),
                            foregroundColor: Colors.black87,
                            disabledBackgroundColor:
                                Colors.amberAccent.withOpacity(0.35),
                            disabledForegroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: _linkState == _BumpLinkState.linking ||
                                  _linkState == _BumpLinkState.matched
                              ? null
                              : _launchSoloPracticeBattle,
                          icon: const Icon(Icons.smart_toy_outlined,
                              color: Colors.white70, size: 15),
                          label: const Text(
                            "PRACTICE VS RIVAL BLUE (SOLO AI)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xCC121624),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.18)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
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
