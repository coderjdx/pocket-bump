import 'dart:math';
import 'package:flutter/material.dart';
import '../models/trainer_avatar.dart';

class TrainerSpriteWidget extends StatelessWidget {
  final TrainerAvatar avatar;
  final bool isBackView;
  final int pose; // 0 = ready, 1 = windup, 2 = throw (used in back view)
  final Color ballColor;
  final double size;

  const TrainerSpriteWidget({
    super.key,
    required this.avatar,
    this.isBackView = false,
    this.pose = 0,
    this.ballColor = const Color(0xFFE53935),
    this.size = 110,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.9, size),
      painter: isBackView
          ? _TrainerBackPainter(
              avatar: avatar,
              pose: pose,
              ballColor: ballColor,
            )
          : _TrainerFrontPainter(avatar: avatar),
    );
  }
}

class _TrainerFrontPainter extends CustomPainter {
  final TrainerAvatar avatar;

  _TrainerFrontPainter({required this.avatar});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 130.0;
    canvas.save();
    canvas.scale(s, s);

    final cx = (size.width / s) * 0.5;
    const bottomY = 122.0;

    final skinPaint = Paint()..color = const Color(0xFFF6C8A0);
    final hairPaint = Paint()..color = avatar.hairColor;
    final outfitPaint = Paint()..color = avatar.outfitPrimary;
    final accentPaint = Paint()..color = avatar.outfitSecondary;
    final bottomPaint = Paint()..color = avatar.bottomColor;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, bottomY + 2), width: 46, height: 10),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    // Back hair layer for long hairstyles
    if (avatar.hairStyle == TrainerHairStyle.longStraight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 21, bottomY - 100, 42, 42), const Radius.circular(14)),
        hairPaint,
      );
    } else if (avatar.hairStyle == TrainerHairStyle.twinPonytails) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 21, bottomY - 82), width: 14, height: 32),
        hairPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 21, bottomY - 82), width: 14, height: 32),
        hairPaint,
      );
    } else if (avatar.hairStyle == TrainerHairStyle.twinPigtails) {
      canvas.drawCircle(Offset(cx - 20, bottomY - 88), 9, hairPaint);
      canvas.drawCircle(Offset(cx + 20, bottomY - 88), 9, hairPaint);
      canvas.drawCircle(Offset(cx - 23, bottomY - 76), 7, hairPaint);
      canvas.drawCircle(Offset(cx + 23, bottomY - 76), 7, hairPaint);
    }

    // Legs & Bottoms
    if (avatar.isFemale) {
      // Legs
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 12, bottomY - 34, 9, 30), const Radius.circular(4)),
        skinPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 3, bottomY - 34, 9, 30), const Radius.circular(4)),
        skinPaint,
      );
      // Skirt or Shorts
      final skirtPath = Path()
        ..moveTo(cx - 16, bottomY - 46)
        ..lineTo(cx + 16, bottomY - 46)
        ..lineTo(cx + 21, bottomY - 26)
        ..lineTo(cx - 21, bottomY - 26)
        ..close();
      canvas.drawPath(skirtPath, bottomPaint);
    } else {
      // Jeans / Pants
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 14, bottomY - 44, 12, 40), const Radius.circular(4)),
        bottomPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 2, bottomY - 44, 12, 40), const Radius.circular(4)),
        bottomPaint,
      );
    }

    // Sneakers
    final shoePaint = Paint()..color = avatar.hatPrimary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 15, bottomY - 8, 13, 8), const Radius.circular(4)),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + 2, bottomY - 8, 13, 8), const Radius.circular(4)),
      shoePaint,
    );

    // Torso & Outfit
    final torsoWidth = avatar.isFemale ? 32.0 : 36.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - torsoWidth / 2, bottomY - 80, torsoWidth, 38),
          const Radius.circular(8)),
      outfitPaint,
    );
    // Center shirt / jacket zipper detail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 6, bottomY - 79, 12, 34), const Radius.circular(3)),
      accentPaint,
    );

    // Left Arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - torsoWidth / 2 - 8, bottomY - 76, 9, 26),
          const Radius.circular(4)),
      skinPaint,
    );
    // Right Arm holding Poké Ball
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + torsoWidth / 2 - 1, bottomY - 76, 9, 24),
          const Radius.circular(4)),
      skinPaint,
    );
    final ballPos = Offset(cx + torsoWidth / 2 + 4, bottomY - 50);
    _drawMiniBall(canvas, ballPos, 7.0, avatar.hatPrimary);

    // Head
    canvas.drawCircle(Offset(cx, bottomY - 96), 16, skinPaint);

    // Hair Bangs
    if (avatar.hairStyle == TrainerHairStyle.spikyShort) {
      final bangs = Path()
        ..moveTo(cx - 15, bottomY - 99)
        ..lineTo(cx - 10, bottomY - 90)
        ..lineTo(cx - 4, bottomY - 97)
        ..lineTo(cx + 2, bottomY - 89)
        ..lineTo(cx + 9, bottomY - 97)
        ..lineTo(cx + 15, bottomY - 99)
        ..lineTo(cx + 14, bottomY - 108)
        ..lineTo(cx - 14, bottomY - 108)
        ..close();
      canvas.drawPath(bangs, hairPaint);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, bottomY - 98), width: 32, height: 22),
        pi,
        pi,
        true,
        hairPaint,
      );
    }

    // Eyes & Smile
    final eyePaint = Paint()..color = const Color(0xFF1F1F28);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 6, bottomY - 93), width: 3.5, height: 5),
        eyePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 6, bottomY - 93), width: 3.5, height: 5),
        eyePaint);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, bottomY - 87), width: 8, height: 5),
      0.15,
      pi - 0.3,
      false,
      Paint()
        ..color = const Color(0xFF795548)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );

    // Hat Style
    _drawFrontHat(canvas, cx, bottomY - 103);

    canvas.restore();
  }

  void _drawFrontHat(Canvas canvas, double cx, double y) {
    final hatPaint = Paint()..color = avatar.hatPrimary;
    final hatAccentPaint = Paint()..color = avatar.hatAccent;

    switch (avatar.hatStyle) {
      case TrainerHatStyle.classicCap:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 34, height: 26),
          pi,
          pi,
          true,
          hatPaint,
        );
        // White/accent front badge patch
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y - 1), width: 16, height: 14),
          pi,
          pi,
          true,
          hatAccentPaint,
        );
        // Cap visor brim
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 16, y - 2, 32, 5), const Radius.circular(3)),
          Paint()..color = avatar.hatPrimary.withOpacity(0.9),
        );
        break;

      case TrainerHatStyle.backwardCap:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 34, height: 26),
          pi,
          pi,
          true,
          hatPaint,
        );
        // Gold band across front
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 13, y - 4, 26, 4), const Radius.circular(2)),
          hatAccentPaint,
        );
        break;

      case TrainerHatStyle.sunHat:
        // Wide sun hat brim
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, y), width: 46, height: 10),
          hatPaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 32, height: 24),
          pi,
          pi,
          true,
          hatPaint,
        );
        // Ribbon band
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 15, y - 4, 30, 4), const Radius.circular(2)),
          hatAccentPaint,
        );
        break;

      case TrainerHatStyle.beret:
        canvas.save();
        canvas.translate(cx - 2, y - 6);
        canvas.rotate(-0.14);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 20), hatPaint);
        canvas.restore();
        canvas.drawCircle(Offset(cx + 8, y - 5), 3.5, hatAccentPaint);
        break;

      case TrainerHatStyle.explorerHat:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 36, height: 28),
          pi,
          pi,
          true,
          hatPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 18, y - 3, 36, 5), const Radius.circular(3)),
          hatAccentPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TrainerFrontPainter oldDelegate) =>
      oldDelegate.avatar.id != avatar.id;
}

class _TrainerBackPainter extends CustomPainter {
  final TrainerAvatar avatar;
  final int pose;
  final Color ballColor;

  _TrainerBackPainter({
    required this.avatar,
    required this.pose,
    required this.ballColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.height / 132.0;
    canvas.save();
    canvas.scale(s, s);

    final cx = (size.width / s) * 0.48;
    const bottomY = 126.0;

    final skinPaint = Paint()..color = const Color(0xFFF3C39B);
    final hairPaint = Paint()..color = avatar.hairColor;
    final outfitPaint = Paint()..color = avatar.outfitPrimary;
    final accentPaint = Paint()..color = avatar.outfitSecondary;
    final bottomPaint = Paint()..color = avatar.bottomColor;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, bottomY), width: 54, height: 14),
      Paint()..color = Colors.black.withOpacity(0.28),
    );

    // Legs / Skirt
    if (avatar.isFemale) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 14, bottomY - 34, 10, 32), const Radius.circular(4)),
        skinPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 4, bottomY - 34, 10, 32), const Radius.circular(4)),
        skinPaint,
      );
      final skirtPath = Path()
        ..moveTo(cx - 18, bottomY - 46)
        ..lineTo(cx + 18, bottomY - 46)
        ..lineTo(cx + 22, bottomY - 26)
        ..lineTo(cx - 22, bottomY - 26)
        ..close();
      canvas.drawPath(skirtPath, bottomPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 17, bottomY - 42, 14, 40), const Radius.circular(5)),
        bottomPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx + 3, bottomY - 42, 14, 40), const Radius.circular(5)),
        bottomPaint,
      );
    }

    // Sneakers
    final shoePaint = Paint()..color = avatar.hatPrimary;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 18, bottomY - 8, 15, 8), const Radius.circular(4)),
      shoePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + 3, bottomY - 8, 15, 8), const Radius.circular(4)),
      shoePaint,
    );

    // Torso
    final torsoWidth = avatar.isFemale ? 36.0 : 42.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - torsoWidth / 2, bottomY - 82, torsoWidth, 44),
          const Radius.circular(8)),
      outfitPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 10, bottomY - 85, 20, 7), const Radius.circular(3)),
      accentPaint,
    );

    // Backpack / Shoulder bag
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 15, bottomY - 78, 28, 33), const Radius.circular(7)),
      Paint()..color = avatar.bagColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 13, bottomY - 62, 24, 13), const Radius.circular(4)),
      Paint()..color = Colors.black.withOpacity(0.18),
    );

    // Left Arm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - torsoWidth / 2 - 8, bottomY - 78, 10, 26),
          const Radius.circular(5)),
      skinPaint,
    );

    // Head & Hair (back view)
    canvas.drawCircle(Offset(cx, bottomY - 98), 16, hairPaint);
    if (avatar.hairStyle == TrainerHairStyle.longStraight) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - 18, bottomY - 98, 36, 36), const Radius.circular(10)),
        hairPaint,
      );
    } else if (avatar.hairStyle == TrainerHairStyle.twinPonytails) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - 22, bottomY - 86), width: 13, height: 30),
        hairPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx + 22, bottomY - 86), width: 13, height: 30),
        hairPaint,
      );
    } else if (avatar.hairStyle == TrainerHairStyle.twinPigtails) {
      canvas.drawCircle(Offset(cx - 20, bottomY - 90), 8, hairPaint);
      canvas.drawCircle(Offset(cx + 20, bottomY - 90), 8, hairPaint);
      canvas.drawCircle(Offset(cx - 23, bottomY - 78), 6.5, hairPaint);
      canvas.drawCircle(Offset(cx + 23, bottomY - 78), 6.5, hairPaint);
    }

    // Back Hat
    _drawBackHat(canvas, cx, bottomY - 103);

    // Right Throwing Arm + Poké Ball
    final armPaint = Paint()
      ..color = const Color(0xFFF3C39B)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    final shoulder = Offset(cx + torsoWidth / 2 - 1, bottomY - 75);
    Offset handPos;
    if (pose == 0) {
      handPos = Offset(cx + 34, bottomY - 84);
      canvas.drawLine(shoulder, handPos, armPaint);
    } else if (pose == 1) {
      handPos = Offset(cx + 42, bottomY - 56);
      canvas.drawLine(shoulder, handPos, armPaint);
    } else {
      handPos = Offset(cx + 32, bottomY - 112);
      canvas.drawLine(shoulder, handPos, armPaint);
    }

    if (pose != 2) {
      _drawMiniBall(canvas, handPos, 8.5, ballColor);
    }

    canvas.restore();
  }

  void _drawBackHat(Canvas canvas, double cx, double y) {
    final hatPaint = Paint()..color = avatar.hatPrimary;
    final hatAccentPaint = Paint()..color = avatar.hatAccent;

    switch (avatar.hatStyle) {
      case TrainerHatStyle.classicCap:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 34, height: 28),
          pi,
          pi,
          true,
          hatPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 10, y - 3, 20, 5), const Radius.circular(3)),
          hatAccentPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx + 8, y - 1, 16, 4), const Radius.circular(2)),
          hatPaint,
        );
        break;

      case TrainerHatStyle.backwardCap:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 34, height: 28),
          pi,
          pi,
          true,
          hatPaint,
        );
        // Backward brim sticking out back-left
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 24, y - 1, 20, 5), const Radius.circular(3)),
          hatAccentPaint,
        );
        break;

      case TrainerHatStyle.sunHat:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, y), width: 46, height: 12),
          hatPaint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 32, height: 24),
          pi,
          pi,
          true,
          hatPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 15, y - 4, 30, 4), const Radius.circular(2)),
          hatAccentPaint,
        );
        break;

      case TrainerHatStyle.beret:
        canvas.save();
        canvas.translate(cx - 2, y - 6);
        canvas.rotate(-0.14);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 20), hatPaint);
        canvas.restore();
        break;

      case TrainerHatStyle.explorerHat:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, y), width: 36, height: 28),
          pi,
          pi,
          true,
          hatPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(cx - 17, y - 3, 34, 5), const Radius.circular(3)),
          hatAccentPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TrainerBackPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.ballColor != ballColor ||
      oldDelegate.avatar.id != avatar.id;
}

void _drawMiniBall(Canvas canvas, Offset center, double radius, Color topColor) {
  canvas.drawCircle(center, radius, Paint()..color = Colors.white);
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: radius),
    pi,
    pi,
    true,
    Paint()..color = topColor,
  );
  canvas.drawLine(
    center + Offset(-radius, 0),
    center + Offset(radius, 0),
    Paint()
      ..color = Colors.black
      ..strokeWidth = 2,
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.black,
  );
  canvas.drawCircle(center, 2.5, Paint()..color = Colors.white);
}
