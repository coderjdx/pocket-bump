import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/trainer.dart';
import '../services/bump_service.dart';
import '../services/pokedex_database.dart';
import 'battle_screen.dart';

class BumpScreen extends StatefulWidget {
  const BumpScreen({super.key});

  @override
  State<BumpScreen> createState() => _BumpScreenState();
}

class _BumpScreenState extends State<BumpScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _bumpDetected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Start listening to the hardware accelerometer!
    BumpService.startListening(
      onBump: (timestamp) {
        _triggerMatch();
      },
    );
  }

  void _triggerMatch() {
    if (_bumpDetected) return;
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
    setState(() => _bumpDetected = true);

    HapticFeedback.heavyImpact();

    // Show pairing animation & pre-cache PVP stadium arena then launch duel
    Future.wait([
      Future.delayed(const Duration(milliseconds: 1200)),
      precacheImage(
        const AssetImage('assets/images/battle_bg_pvp_arena.png'),
        context,
      ).catchError((_) {}),
    ]).then((_) {
      if (!mounted) return;

      final playerLevel = trainer.leadPokemon?.level ?? 5;
      final rivalMon = PokedexDatabase.generateRivalPokemon(playerLevel: playerLevel);

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        _bumpDetected ? const Color(0xFF34EB8C) : Colors.redAccent;

    return Scaffold(
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
          "VS LINK • FIST-BUMP RADAR",
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
                  const Color(0xFF080A12).withOpacity(0.90),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top VS Link Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xE00C101C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.65)),
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
                        Text(
                          _bumpDetected
                              ? "LINK ESTABLISHED"
                              : "SCANNING NEARBY TRAINERS",
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Animated Pulsing VS Link Radar
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: 210 + (_pulseController.value * 55),
                              height: 210 + (_pulseController.value * 55),
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
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: _bumpDetected
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
                            _bumpDetected
                                ? Icons.check_circle_outline_rounded
                                : Icons.sports_mma_rounded,
                            size: 76,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xE6111422),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _bumpDetected
                              ? "BUMP DETECTED!"
                              : "HOLD PHONES & FIST-BUMP!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _bumpDetected
                                ? const Color(0xFF34EB8C)
                                : Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _bumpDetected
                              ? "Synchronizing Battle Stadium arena..."
                              : "Both players hold phones and physically fist-bump to initiate a Kanto Stadium duel.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Test Button (Simulate Bump for testing without physically bumping)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _triggerMatch,
                      icon: const Icon(Icons.bolt_rounded,
                          color: Colors.amberAccent, size: 18),
                      label: const Text(
                        "SIMULATE FIST-BUMP (TEST DUEL)",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.7,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xDD141828),
                        side: BorderSide(
                            color: Colors.amberAccent.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
