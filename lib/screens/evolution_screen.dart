import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';

class EvolutionScreen extends StatefulWidget {
  final PokemonSpecies fromSpecies;
  final PokemonSpecies toSpecies;
  final String oldNickname;
  final List<String> learnedMoves;
  final bool isShiny;

  const EvolutionScreen({
    super.key,
    required this.fromSpecies,
    required this.toSpecies,
    required this.oldNickname,
    this.learnedMoves = const [],
    this.isShiny = false,
  });

  static Future<void> show(
    BuildContext context, {
    required PokemonSpecies fromSpecies,
    required PokemonSpecies toSpecies,
    required String oldNickname,
    List<String> learnedMoves = const [],
    bool isShiny = false,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, __, ___) => EvolutionScreen(
          fromSpecies: fromSpecies,
          toSpecies: toSpecies,
          oldNickname: oldNickname,
          learnedMoves: learnedMoves,
          isShiny: isShiny,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends State<EvolutionScreen>
    with TickerProviderStateMixin {
  late AnimationController _morphController;
  late AnimationController _flashController;
  late AnimationController _ambientController;

  String _phase = 'intro'; // 'intro' -> 'morph' -> 'reveal'
  String _dialogueText = '';
  bool _finished = false;
  int _lastHapticBucket = -1;

  @override
  void initState() {
    super.initState();
    _dialogueText = "What?\n${widget.oldNickname} is evolving!";

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..addListener(() {
        final t = _morphController.value;
        // Accelerating cadence haptic pulse during final rapid morph transitions
        final int bucket = (t * t * 14).floor();
        if (_phase == 'morph' && bucket != _lastHapticBucket) {
          _lastHapticBucket = bucket;
          HapticFeedback.selectionClick();
        }
      });

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runEvolutionSequence();
    });
  }

  String _spriteFor(PokemonSpecies species) =>
      widget.isShiny ? species.shinySpriteUrl : species.spriteUrl;

  String _staticSpriteFor(PokemonSpecies species) =>
      widget.isShiny ? species.staticShinySpriteUrl : species.staticSpriteUrl;

  Future<void> _runEvolutionSequence() async {
    if (!mounted) return;
    // Preload pre-evolution and evolved sprites so there's zero pop-in mid-morph
    await Future.wait([
      precacheImage(NetworkImage(_spriteFor(widget.fromSpecies)), context)
          .catchError((_) {}),
      precacheImage(NetworkImage(_spriteFor(widget.toSpecies)), context)
          .catchError((_) {}),
    ]).timeout(const Duration(milliseconds: 1200), onTimeout: () => const []);
    if (!mounted) return;

    // Phase 1: Dramatic anticipation hold
    await Future.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;

    // Phase 2: Accelerating glowing silhouette morph between old & new species
    setState(() {
      _phase = 'morph';
      _dialogueText = "${widget.oldNickname} is overflowing with evolution light!";
    });
    await _morphController.forward(from: 0.0);
    if (!mounted) return;

    // Phase 3: Climax white flash -> full reveal of evolved form
    HapticFeedback.heavyImpact();
    setState(() {
      _phase = 'reveal';
      _finished = true;
      _dialogueText =
          "Congratulations! Your ${widget.oldNickname} evolved into ${widget.toSpecies.name}!";
    });
    await _flashController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _morphController.dispose();
    _flashController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Widget _buildPokemonSprite(
    PokemonSpecies species, {
    required double size,
    required bool whiteSilhouette,
  }) {
    final Widget raw = Image.network(
      _spriteFor(species),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Image.network(
        _staticSpriteFor(species),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => Icon(
          Icons.catching_pokemon,
          size: size * 0.72,
          color: whiteSilhouette ? Colors.white : species.types.first.color,
        ),
      ),
    );
    if (!whiteSilhouette) return raw;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcATop),
      child: raw,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = _phase == 'reveal'
        ? widget.toSpecies.types.first.color
        : widget.fromSpecies.types.first.color;

    return PopScope(
      canPop: _finished,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D18),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Animated Cosmic Evolution Backdrop & Energy Particles
            AnimatedBuilder(
              animation: Listenable.merge([_ambientController, _morphController]),
              builder: (_, __) {
                return CustomPaint(
                  painter: _EvolutionBackdropPainter(
                    ambientProgress: _ambientController.value,
                    morphProgress:
                        _phase == 'morph' ? _morphController.value : 0.0,
                    isMorphing: _phase == 'morph',
                    isRevealed: _phase == 'reveal',
                    accentColor: primaryColor,
                  ),
                );
              },
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  children: [
                    // Header Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _phase == 'reveal'
                                ? "EVOLUTION COMPLETE"
                                : "EVOLUTION IN PROGRESS",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Center Morph Arena
                    Expanded(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _morphController,
                            _ambientController,
                          ]),
                          builder: (_, __) {
                            if (_phase == 'intro') {
                              final double pulse =
                                  1.0 + sin(_ambientController.value * pi * 2) * 0.03;
                              return Transform.scale(
                                scale: pulse,
                                child: _buildPokemonSprite(
                                  widget.fromSpecies,
                                  size: 148,
                                  whiteSilhouette: false,
                                ),
                              );
                            }

                            if (_phase == 'morph') {
                              final double t = _morphController.value;
                              // Frequency ramps smoothly up as evolution approaches climax
                              final double wave = sin(t * t * pi * 22);
                              final bool showNew = wave >= 0;
                              final double baseScale = 0.96 + 0.14 * wave.abs();
                              final double glowSize = 150 + 70 * sin(t * pi);
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: glowSize,
                                    height: glowSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.55),
                                          Colors.lightBlueAccent
                                              .withOpacity(0.22),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: baseScale,
                                    child: _buildPokemonSprite(
                                      showNew
                                          ? widget.toSpecies
                                          : widget.fromSpecies,
                                      size: showNew ? 154 : 146,
                                      whiteSilhouette: true,
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Reveal phase
                            final double floatY =
                                -sin(_ambientController.value * pi * 2) * 4.0;
                            return Transform.translate(
                              offset: Offset(0, floatY),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.72, end: 1.0),
                                    duration: const Duration(milliseconds: 360),
                                    curve: Curves.easeOutBack,
                                    builder: (_, s, child) =>
                                        Transform.scale(scale: s, child: child),
                                    child: _buildPokemonSprite(
                                      widget.toSpecies,
                                      size: 164,
                                      whiteSilhouette: false,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 6,
                                    children: widget.toSpecies.types.map((t) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: t.color.withOpacity(0.28),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: t.color.withOpacity(0.8)),
                                        ),
                                        child: Text(
                                          t.displayName.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Bottom Classic Dialogue Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171B2B),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _phase == 'reveal'
                              ? primaryColor.withOpacity(0.75)
                              : Colors.white24,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dialogueText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                          ),
                          if (_phase == 'reveal' &&
                              widget.learnedMoves.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.cyanAccent.withOpacity(0.45),
                                ),
                              ),
                              child: Text(
                                "Learned ${widget.learnedMoves.join(', ')}!",
                                style: const TextStyle(
                                  color: Colors.cyanAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (_finished) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text(
                                  "CONTINUE",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.black,
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
                  ],
                ),
              ),
            ),

            // Peak White/Gold Climax Flash Overlay
            AnimatedBuilder(
              animation: _flashController,
              builder: (_, __) {
                if (_phase != 'reveal' || _flashController.value >= 1.0) {
                  return const SizedBox.shrink();
                }
                final double opacity =
                    (1.0 - _flashController.value).clamp(0.0, 1.0) * 0.92;
                return IgnorePointer(
                  child: Container(color: Colors.white.withOpacity(opacity)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionBackdropPainter extends CustomPainter {
  final double ambientProgress;
  final double morphProgress;
  final bool isMorphing;
  final bool isRevealed;
  final Color accentColor;

  _EvolutionBackdropPainter({
    required this.ambientProgress,
    required this.morphProgress,
    required this.isMorphing,
    required this.isRevealed,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.44);

    // Deep cosmic gradient base
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.12),
        radius: 1.0,
        colors: [
          isMorphing
              ? const Color(0xFF1F3868)
              : (isRevealed
                  ? accentColor.withOpacity(0.32)
                  : const Color(0xFF161D36)),
          const Color(0xFF0A0D18),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Expanding concentric evolution waves
    final int ringCount = isMorphing ? 5 : 3;
    for (int i = 0; i < ringCount; i++) {
      final double phase = (ambientProgress + i / ringCount) % 1.0;
      final double radius = 40 + phase * (size.width * 0.65);
      final double alpha = (1.0 - phase) * (isMorphing ? 0.35 : 0.16);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = (isMorphing ? Colors.white : accentColor).withOpacity(alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isMorphing ? 2.6 : 1.8,
      );
    }

    // Orbiting / Rising evolution light motes
    final int particleCount = isMorphing ? 24 : 16;
    for (int i = 0; i < particleCount; i++) {
      final double seed = i * 2.39996;
      final double progress = (ambientProgress + i / particleCount) % 1.0;
      final double dist = isMorphing
          ? (1.0 - progress) * (size.width * 0.55) + 18
          : progress * (size.width * 0.52) + 30;
      final double angle = seed + (isMorphing ? morphProgress * pi * 3 : ambientProgress * pi);
      final px = center.dx + cos(angle) * dist;
      final py = center.dy + sin(angle) * dist * 0.72;
      final r = isMorphing ? 3.5 : 2.6;
      final alpha = (sin(progress * pi) * 0.85).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()
          ..color = (isRevealed ? Colors.amberAccent : Colors.lightBlueAccent)
              .withOpacity(alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EvolutionBackdropPainter oldDelegate) => true;
}
