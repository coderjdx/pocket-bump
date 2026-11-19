import 'dart:math';
import 'package:flutter/material.dart';

/// Displays a pixel-art Poké Ball, Great Ball, or Ultra Ball with optional
/// open-capsule split state, pulsing center button glow, and capture lock sheen.
class PokeBallSpriteWidget extends StatelessWidget {
  final String ballType; // 'poke_ball', 'great_ball', 'ultra_ball'
  final double size;
  final bool isOpen;
  final Color? buttonGlowColor;
  final bool isLocked;

  const PokeBallSpriteWidget({
    super.key,
    required this.ballType,
    this.size = 34,
    this.isOpen = false,
    this.buttonGlowColor,
    this.isLocked = false,
  });

  String get _assetPath {
    switch (ballType) {
      case 'great_ball':
        return 'assets/images/balls/great_ball.png';
      case 'ultra_ball':
        return 'assets/images/balls/ultra_ball.png';
      case 'master_ball':
        return 'assets/images/balls/master_ball.png';
      case 'poke_ball':
      default:
        return 'assets/images/balls/poke_ball.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget coreBall = isOpen
        ? SizedBox(
            width: size,
            height: size * 1.25,
            child: CustomPaint(
              painter: _DetailedPokeBallPainter(
                ballType: ballType,
                isOpen: true,
                buttonGlowColor: buttonGlowColor,
                isLocked: isLocked,
              ),
            ),
          )
        : Image.asset(
            _assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, __, ___) => CustomPaint(
              size: Size(size, size),
              painter: _DetailedPokeBallPainter(
                ballType: ballType,
                isOpen: false,
                buttonGlowColor: buttonGlowColor,
                isLocked: isLocked,
              ),
            ),
          );

    return SizedBox(
      width: size,
      height: isOpen ? size * 1.25 : size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          coreBall,
          if (buttonGlowColor != null && !isOpen)
            Container(
              width: size * 0.30,
              height: size * 0.30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: buttonGlowColor!.withOpacity(0.92),
                boxShadow: [
                  BoxShadow(
                    color: buttonGlowColor!.withOpacity(0.85),
                    blurRadius: size * 0.36,
                    spreadRadius: size * 0.08,
                  ),
                ],
              ),
            ),
          if (isLocked && !isOpen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.black.withOpacity(0.16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailedPokeBallPainter extends CustomPainter {
  final String ballType;
  final bool isOpen;
  final Color? buttonGlowColor;
  final bool isLocked;

  _DetailedPokeBallPainter({
    required this.ballType,
    required this.isOpen,
    required this.buttonGlowColor,
    required this.isLocked,
  });

  Color get _topPrimary {
    switch (ballType) {
      case 'great_ball':
        return const Color(0xFF1E88E5);
      case 'ultra_ball':
        return const Color(0xFF2B2D36);
      case 'master_ball':
        return const Color(0xFF7B1FA2);
      case 'poke_ball':
      default:
        return const Color(0xFFE53935);
    }
  }

  Color get _topHighlight {
    switch (ballType) {
      case 'great_ball':
        return const Color(0xFF64B5F6);
      case 'ultra_ball':
        return const Color(0xFF4B4F5E);
      case 'master_ball':
        return const Color(0xFFCE93D8);
      case 'poke_ball':
      default:
        return const Color(0xFFFF6F60);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double r = w * 0.45;
    final Offset baseCenter = Offset(w / 2, isOpen ? size.height * 0.56 : size.height / 2);
    final double gap = isOpen ? w * 0.22 : 0.0;

    final Offset topCenter = Offset(baseCenter.dx, baseCenter.dy - gap * 0.65);
    final Offset bottomCenter = Offset(baseCenter.dx, baseCenter.dy + gap * 0.35);

    if (isOpen) {
      // Bright energy interior visible between separated halves
      final glowRect = Rect.fromCenter(
        center: baseCenter + Offset(0, -gap * 0.15),
        width: r * 1.75,
        height: r * 0.9,
      );
      canvas.drawOval(
        glowRect,
        Paint()
          ..color = const Color(0xFFFF80AB).withOpacity(0.92)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawOval(
        glowRect.deflate(r * 0.28),
        Paint()..color = Colors.white,
      );
    }

    // Bottom White Hemisphere
    final bottomRect = Rect.fromCircle(center: bottomCenter, radius: r);
    canvas.drawArc(
      bottomRect,
      0,
      pi,
      true,
      Paint()..color = const Color(0xFFF3F4F6),
    );
    canvas.drawArc(
      bottomRect,
      0.15,
      pi - 0.30,
      false,
      Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16,
    );
    canvas.drawArc(
      bottomRect,
      0,
      pi,
      true,
      Paint()
        ..color = const Color(0xFF14141A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.6, w * 0.065),
    );

    // Top Cap Hemisphere (rotated slightly backwards when open)
    canvas.save();
    if (isOpen) {
      canvas.translate(topCenter.dx, topCenter.dy);
      canvas.rotate(-0.22);
      canvas.translate(-topCenter.dx, -topCenter.dy);
    }

    final topRect = Rect.fromCircle(center: topCenter, radius: r);
    canvas.drawArc(topRect, pi, pi, true, Paint()..color = _topPrimary);

    // Gloss arc on top left
    canvas.drawArc(
      topRect.deflate(r * 0.24),
      pi + 0.35,
      0.85,
      false,
      Paint()
        ..color = _topHighlight.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, r * 0.18)
        ..strokeCap = StrokeCap.round,
    );

    if (ballType == 'great_ball') {
      // Twin Red Shoulder Fins
      final finPaint = Paint()..color = const Color(0xFFE53935);
      final leftFin = Path()
        ..moveTo(topCenter.dx - r * 0.72, topCenter.dy - r * 0.25)
        ..lineTo(topCenter.dx - r * 0.30, topCenter.dy - r * 0.68)
        ..lineTo(topCenter.dx - r * 0.18, topCenter.dy - r * 0.50)
        ..lineTo(topCenter.dx - r * 0.56, topCenter.dy - r * 0.12)
        ..close();
      final rightFin = Path()
        ..moveTo(topCenter.dx + r * 0.72, topCenter.dy - r * 0.25)
        ..lineTo(topCenter.dx + r * 0.30, topCenter.dy - r * 0.68)
        ..lineTo(topCenter.dx + r * 0.18, topCenter.dy - r * 0.50)
        ..lineTo(topCenter.dx + r * 0.56, topCenter.dy - r * 0.12)
        ..close();
      canvas.drawPath(leftFin, finPaint);
      canvas.drawPath(rightFin, finPaint);
    } else if (ballType == 'ultra_ball') {
      // Twin Gold/Yellow H Stripes
      final stripePaint = Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.2, r * 0.24)
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        topRect.deflate(r * 0.18),
        pi + 0.55,
        0.55,
        false,
        stripePaint,
      );
      canvas.drawArc(
        topRect.deflate(r * 0.18),
        -0.55 - 0.55,
        0.55,
        false,
        stripePaint,
      );
      canvas.drawLine(
        Offset(topCenter.dx - r * 0.42, topCenter.dy - r * 0.60),
        Offset(topCenter.dx + r * 0.42, topCenter.dy - r * 0.60),
        stripePaint..strokeWidth = max(2.0, r * 0.20),
      );
    }

    // Center Band + Outline on Top Cap
    canvas.drawLine(
      Offset(topCenter.dx - r, topCenter.dy),
      Offset(topCenter.dx + r, topCenter.dy),
      Paint()
        ..color = const Color(0xFF14141A)
        ..strokeWidth = max(2.4, r * 0.22),
    );
    canvas.drawArc(
      topRect,
      pi,
      pi,
      true,
      Paint()
        ..color = const Color(0xFF14141A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.6, w * 0.065),
    );
    canvas.restore();

    if (!isOpen) {
      // Center seam band & button
      canvas.drawLine(
        Offset(baseCenter.dx - r, baseCenter.dy),
        Offset(baseCenter.dx + r, baseCenter.dy),
        Paint()
          ..color = const Color(0xFF14141A)
          ..strokeWidth = max(2.4, r * 0.24),
      );
      canvas.drawCircle(
        baseCenter,
        r * 0.30,
        Paint()..color = const Color(0xFF14141A),
      );
      canvas.drawCircle(
        baseCenter,
        r * 0.19,
        Paint()..color = buttonGlowColor ?? (isLocked ? const Color(0xFFE0E0E0) : Colors.white),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DetailedPokeBallPainter oldDelegate) =>
      oldDelegate.ballType != ballType ||
      oldDelegate.isOpen != isOpen ||
      oldDelegate.buttonGlowColor != buttonGlowColor ||
      oldDelegate.isLocked != isLocked;
}
