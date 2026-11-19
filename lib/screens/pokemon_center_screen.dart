import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../widgets/pokeball_sprite.dart';
import 'poke_mart_screen.dart';

class PokemonCenterScreen extends StatefulWidget {
  const PokemonCenterScreen({super.key});

  @override
  State<PokemonCenterScreen> createState() => _PokemonCenterScreenState();
}

class _PokemonCenterScreenState extends State<PokemonCenterScreen> {
  bool _isHealing = false;
  int _placedBalls = 0;
  int _pulseCount = 0;
  bool _pulseLit = false;
  String _nurseMessage =
      "Welcome to the Pokémon Center! Shall we restore your Pokémon to perfect condition?";

  Future<void> _runClassicHealAnimation(Trainer trainer) async {
    if (_isHealing) return;

    setState(() {
      _isHealing = true;
      _placedBalls = 0;
      _pulseCount = 0;
      _pulseLit = false;
      _nurseMessage = "Okay, I'll take your Pokémon for a few seconds...";
    });

    // Step 1: Place each party Pokémon's Poké Ball into the machine one-by-one
    for (int i = 1; i <= trainer.party.length; i++) {
      await Future.delayed(const Duration(milliseconds: 210));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() {
        _placedBalls = i;
      });
    }

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Step 2: 4 synchronized classic healing pulses ("doot-doot-doot-doot-da-da!")
    setState(() {
      _nurseMessage = "Restoring HP, PP, and curing status conditions...";
    });

    for (int pulse = 1; pulse <= 4; pulse++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _pulseLit = true;
        _pulseCount = pulse;
      });
      await Future.delayed(const Duration(milliseconds: 230));
      if (!mounted) return;
      setState(() {
        _pulseLit = false;
      });
      await Future.delayed(const Duration(milliseconds: 140));
    }

    if (!mounted) return;

    // Step 3: Complete full restoration
    trainer.healAndResetAllParty();
    trainer.saveProgress();
    HapticFeedback.heavyImpact();

    setState(() {
      _isHealing = false;
      _placedBalls = trainer.party.length;
      _pulseCount = 0;
      _pulseLit = false;
      _nurseMessage =
          "Thank you for waiting! Your Pokémon are fighting fit! We hope to see you again!";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Your entire party was restored to perfect condition! Full HP, PP, and status cured.",
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int fossils = trainer.getItemCount('unknown_fossil');
    final int vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final bool needsHeal = trainer.party.any(
      (mon) =>
          mon.currentHp < mon.maxHp ||
          mon.status != StatusCondition.none ||
          mon.moves.any((m) => m.currentPp < m.maxPp),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF100E18),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC0D0E18),
        elevation: 0,
        title: const Text(
          "POKÉMON CENTER",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: _isHealing ? null : () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "₽",
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_center.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF180E1B).withOpacity(0.76),
                  const Color(0xFF131120).withOpacity(0.62),
                  const Color(0xFF0B0A14).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── CLASSIC HEALING MACHINE CONSOLE ──────────────────────
                  _buildHealingMachineConsole(trainer, needsHeal),

                  const SizedBox(height: 10),

                  // ─── NURSE JOY CHARACTER STAGE ────────────────────────────
                  Expanded(
                    child: _buildNurseJoyStage(trainer, needsHeal),
                  ),

                  const SizedBox(height: 10),

                  // 1. Heal Pokemon Button (triggers Classic Healing Sequence)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isHealing
                          ? null
                          : () => _runClassicHealAnimation(trainer),
                      icon: Icon(
                        _isHealing
                            ? Icons.auto_awesome
                            : Icons.favorite_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isHealing ? "HEALING POKÉMON..." : "HEAL POKÉMON",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent.shade400,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.pinkAccent.withOpacity(0.35),
                        disabledForegroundColor: Colors.white70,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2 & 3. Poke Mart and Pokemon Lab Options
                  Row(
                    children: [
                      Expanded(
                        child: _buildFacilityTile(
                          onTap: _isHealing
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PokeMartScreen(),
                                    ),
                                  );
                                },
                          icon: Icons.storefront_rounded,
                          accentColor: Colors.cyanAccent,
                          title: "Poké Mart",
                          subtitle: "Items & Medicine",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFacilityTile(
                          onTap: _isHealing
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const PokemonLabScreen(),
                                    ),
                                  );
                                },
                          icon: Icons.science_rounded,
                          accentColor: const Color(0xFF4DD0E1),
                          title: "Pokémon Lab",
                          subtitle: "$fossils Fossil • $vouchers Voucher",
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
    );
  }

  Widget _buildNurseJoyStage(Trainer trainer, bool needsHeal) {
    final bool glowing = _isHealing && _pulseLit;
    final Color statusColor = _isHealing
        ? Colors.amberAccent
        : (needsHeal ? Colors.orangeAccent : Colors.greenAccent);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xE0161826), Color(0xE80E101B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glowing
              ? const Color(0xFFFFEE58).withOpacity(0.75)
              : Colors.pinkAccent.withOpacity(0.32),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: Colors.pinkAccent, size: 14),
                  SizedBox(width: 6),
                  Text(
                    "POKÉMON CENTER • NURSE JOY",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      letterSpacing: 0.9,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  _isHealing
                      ? "RECOVERING..."
                      : (needsHeal ? "NEEDS CARE" : "FULL HEALTH"),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: glowing ? 190 : 160,
                  height: glowing ? 190 : 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: glowing
                          ? [
                              const Color(0xFFFFEE58).withOpacity(0.34),
                              Colors.pinkAccent.withOpacity(0.16),
                              Colors.transparent,
                            ]
                          : [
                              Colors.pinkAccent.withOpacity(0.22),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AnimatedScale(
                    scale: glowing ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    child: Image.asset(
                      'assets/images/nurse_joy.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E2F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: glowing
                    ? const Color(0xFFFFEE58).withOpacity(0.55)
                    : Colors.pinkAccent.withOpacity(0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                  ),
                  child: const Text(
                    "NURSE JOY",
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nurseMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
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

  Widget _buildHealingMachineConsole(Trainer trainer, bool needsHeal) {
    final bool glowing = _isHealing && _pulseLit;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: glowing
              ? [
                  const Color(0xEE3C1A35),
                  const Color(0xEE24162A),
                ]
              : [
                  const Color(0xE8241928),
                  const Color(0xEE141522),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: glowing
              ? const Color(0xFFFFEE58)
              : Colors.pinkAccent.withOpacity(0.55),
          width: glowing ? 1.8 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: (glowing ? const Color(0xFFFFEE58) : Colors.pinkAccent)
                .withOpacity(glowing ? 0.36 : 0.16),
            blurRadius: glowing ? 18 : 10,
            spreadRadius: glowing ? 2 : 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nurse Dialogue Strip
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.55)),
                ),
                child: Icon(
                  glowing ? Icons.auto_awesome : Icons.local_hospital_rounded,
                  color: glowing ? const Color(0xFFFFEE58) : Colors.pinkAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "RECOVERY MACHINE",
                          style: TextStyle(
                            color: Colors.pinkAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (_isHealing)
                          Text(
                            _pulseCount > 0
                                ? "CHIME ${_pulseCount}/4"
                                : "LOADING $_placedBalls/${trainer.party.length}",
                            style: TextStyle(
                              color: glowing
                                  ? const Color(0xFFFFEE58)
                                  : Colors.pinkAccent.shade100,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nurseMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Classic 2x3 Metallic Recovery Tray with 6 Poké Ball Sockets
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B2435), Color(0xFF1A1725)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: glowing
                    ? const Color(0xFFFFEE58).withOpacity(0.8)
                    : Colors.white.withOpacity(0.16),
              ),
            ),
            child: Column(
              children: [
                for (int row = 0; row < 2; row++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int col = 0; col < 3; col++)
                        _buildMachineSocket(
                          index: row * 3 + col,
                          trainer: trainer,
                        ),
                    ],
                  ),
                  if (row == 0) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSocket({
    required int index,
    required Trainer trainer,
  }) {
    final bool hasMon = index < trainer.party.length;
    final bool isPlaced =
        hasMon && (_isHealing ? index < _placedBalls : true);
    final bool isLit = _isHealing && isPlaced && _pulseLit;
    final PokemonInstance? mon = hasMon ? trainer.party[index] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isLit
              ? [
                  const Color(0xFFFFEE58).withOpacity(0.55),
                  const Color(0xFF281C32),
                ]
              : [
                  const Color(0xFF0E101A),
                  const Color(0xFF1C2030),
                ],
        ),
        border: Border.all(
          color: isLit
              ? const Color(0xFFFFEE58)
              : (isPlaced
                  ? Colors.pinkAccent.withOpacity(0.65)
                  : Colors.white12),
          width: isLit ? 2.0 : 1.2,
        ),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: const Color(0xFFFFEE58).withOpacity(0.65),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isPlaced && mon != null
            ? AnimatedScale(
                scale: isLit ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Opacity(
                  opacity: (!_isHealing && mon.isFainted) ? 0.45 : 1.0,
                  child: PokeBallSpriteWidget(
                    ballType: mon.caughtBall,
                    size: 26,
                    buttonGlowColor:
                        isLit ? const Color(0xFFFFEE58) : null,
                  ),
                ),
              )
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                  border: Border.all(color: Colors.white12),
                ),
              ),
      ),
    );
  }

  Widget _buildFacilityTile({
    required VoidCallback? onTap,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withOpacity(0.16),
                const Color(0xE8161928),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: accentColor.withOpacity(0.55), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0D16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentColor.withOpacity(0.45)),
                ),
                child: Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: accentColor.withOpacity(0.75), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class PokemonLabScreen extends StatefulWidget {
  const PokemonLabScreen({super.key});

  @override
  State<PokemonLabScreen> createState() => _PokemonLabScreenState();
}

class _PokemonLabScreenState extends State<PokemonLabScreen> {
  void _restoreFossil(Trainer trainer) {
    if (trainer.getItemCount('unknown_fossil') <= 0 ||
        trainer.getItemCount('fossil_restoration_voucher') <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You need 1 Unknown Fossil and 1 Fossil Restoration Voucher to restore a fossil.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (trainer.isStorageFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Both your Party and all 16 PC Boxes are full (320/320)! Release a Pokémon first.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    trainer.adjustItemCount('unknown_fossil', -1);
    trainer.adjustItemCount('fossil_restoration_voucher', -1);

    final fossilPool = PokedexDatabase.firstStageFossilSpeciesIds.where((id) {
      final spec = PokedexDatabase.species[id];
      return spec != null && spec.isAvailableInVersion(trainer.gameVersion);
    }).toList();
    final chosenPool = fossilPool.isNotEmpty
        ? fossilPool
        : PokedexDatabase.firstStageFossilSpeciesIds;
    final chosenId = chosenPool[Random().nextInt(chosenPool.length)];
    final restoredMon = PokedexDatabase.createPokemon(
      chosenId,
      level: 10,
      respectMinEncounterLevel: false,
    );
    final boxNum = trainer.addPokemon(restoredMon);
    trainer.saveProgress();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1F222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.science, color: Color(0xFF4DD0E1), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "FOSSIL RESTORATION COMPLETE!",
                style: TextStyle(
                  color: Color(0xFF4DD0E1),
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Image.network(
                restoredMon.spriteUrl,
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => Image.network(
                  restoredMon.staticSpriteUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.catching_pokemon,
                    color: Colors.white54,
                    size: 56,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You went to a Poké Lab to get the fossil restored! The scientists revived a Lv. ${restoredMon.level} ${restoredMon.species.name}!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              boxNum == null
                  ? "${restoredMon.species.name} joined your Party!"
                  : "${restoredMon.species.name} was transferred to PC Box #$boxNum!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4DD0E1),
              foregroundColor: Colors.black,
            ),
            child: const Text(
              "AWESOME!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int fossils = trainer.getItemCount('unknown_fossil');
    final int vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final bool canRestore = fossils > 0 && vouchers > 0 && !trainer.isStorageFull;

    return Scaffold(
      backgroundColor: const Color(0xFF0C121A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC0A1018),
        elevation: 0,
        title: const Text(
          "POKÉMON LAB",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_lab.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A141E).withOpacity(0.72),
                  const Color(0xFF0C1622).withOpacity(0.58),
                  const Color(0xFF080E16).withOpacity(0.88),
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xE8132232), Color(0xE80D1622)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4DD0E1).withOpacity(0.55),
                        width: 1.3,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF091018),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: const Color(0xFF4DD0E1).withOpacity(0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            color: Color(0xFF4DD0E1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "FOSSIL RESTORATION CHAMBER",
                                style: TextStyle(
                                  color: Color(0xFF4DD0E1),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Combine 1 Unknown Fossil and 1 Fossil Restoration Voucher to revive a random Lv. 10 first-stage Fossil Pokémon!",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.8,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Counts of Unknown Fossil and Fossil Restoration Voucher
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.album_rounded,
                          color: const Color(0xFFD7CCC8),
                          title: "Unknown Fossils",
                          count: fossils,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.confirmation_number_rounded,
                          color: const Color(0xFF4DD0E1),
                          title: "Restoration Vouchers",
                          count: vouchers,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Possible Revived Fossil Species Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xE0141C29), Color(0xE80C121C)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "PREHISTORIC REVIVAL SPECIMENS (LV. 10)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: PokedexDatabase.firstStageFossilSpeciesIds
                                .map((id) {
                              final spec = PokedexDatabase.species[id]!;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      gradient: const RadialGradient(
                                        colors: [
                                          Color(0x444DD0E1),
                                          Color(0xFF0A1018),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF4DD0E1)
                                            .withOpacity(0.55),
                                        width: 1.3,
                                      ),
                                    ),
                                    child: Center(
                                      child: Image.network(
                                        spec.spriteUrl,
                                        width: 54,
                                        height: 54,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none,
                                        errorBuilder: (_, __, ___) =>
                                            Image.network(
                                          spec.staticSpriteUrl,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.catching_pokemon,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    spec.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const Text(
                                    "Lv. 10",
                                    style: TextStyle(
                                      color: Color(0xFF4DD0E1),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: const Text(
                              "Unknown Fossils and Fossil Restoration Vouchers drop as rare rewards when re-challenging Kanto Gym Leaders.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: canRestore ? () => _restoreFossil(trainer) : null,
                      icon: const Icon(Icons.biotech_rounded, size: 20),
                      label: Text(
                        canRestore
                            ? "RESTORE FOSSIL (1 FOSSIL + 1 VOUCHER)"
                            : (trainer.isStorageFull
                                ? "STORAGE FULL (320/320)"
                                : "NEED 1 FOSSIL & 1 VOUCHER"),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD0E1),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(count > 0 ? 0.16 : 0.04),
            const Color(0xE8121924),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0 ? color.withOpacity(0.65) : Colors.white12,
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            "x$count",
            style: TextStyle(
              color: count > 0 ? color : Colors.white38,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
