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

  String get _assetPath {
    if (!isBackView) {
      return 'assets/images/trainers/${avatar.id}_front.png';
    }
    final clampedPose = pose.clamp(0, 2);
    return 'assets/images/trainers/${avatar.id}_back_$clampedPose.png';
  }

  @override
  Widget build(BuildContext context) {
    final double stepOffsetX = !isBackView
        ? 0.0
        : (pose == 1 ? -4.0 : (pose == 2 ? 8.0 : 0.0));
    final double stepScale = !isBackView
        ? 1.0
        : (pose == 2 ? 1.04 : 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(stepOffsetX, 0.0)
        ..scale(stepScale),
      transformAlignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          _assetPath,
          key: ValueKey<String>(_assetPath),
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
