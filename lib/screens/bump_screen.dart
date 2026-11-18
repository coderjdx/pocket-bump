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
    setState(() => _bumpDetected = true);

    HapticFeedback.heavyImpact();

    // Show pairing animation then launch duel
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      final trainer = Provider.of<Trainer>(context, listen: false);
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("FIST-BUMP RADAR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated Pulsing Radar
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 220 + (_pulseController.value * 40),
                          height: 220 + (_pulseController.value * 40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.15 * (1 - _pulseController.value)),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _bumpDetected ? Colors.green.shade700 : const Color(0xFF2A2A35),
                        border: Border.all(color: _bumpDetected ? Colors.greenAccent : Colors.redAccent, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: (_bumpDetected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _bumpDetected ? Icons.check_circle_outline : Icons.sports_mma,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              Text(
                _bumpDetected ? "BUMP DETECTED! ⚡" : "HOLD PHONES & FIST-BUMP!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bumpDetected ? Colors.greenAccent : Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _bumpDetected
                  ? "Connecting with nearby Trainer..."
                  : "Both players hold phones and physically bump fists to initiate the duel.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.4),
              ),

              const Spacer(),

              // Test Button (Simulate Bump for testing without physically bumping)
              OutlinedButton.icon(
                onPressed: _triggerMatch,
                icon: const Icon(Icons.touch_app, color: Colors.white70),
                label: const Text(
                  "SIMULATE BUMP (TEST MODE)",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
