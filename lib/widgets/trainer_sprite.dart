import 'package:flutter/material.dart';
import '../models/trainer_avatar.dart';

class TrainerSpriteWidget extends StatelessWidget {
  final TrainerAvatar? avatar;
  final String? spriteId;
  final bool isBackView;
  final int pose; // 0 = ready, 1 = windup, 2 = throw
  final Color ballColor;
  final double size;

  const TrainerSpriteWidget({
    super.key,
    this.avatar,
    this.spriteId,
    this.isBackView = false,
    this.pose = 0,
    this.ballColor = const Color(0xFFE53935),
    this.size = 140,
  }) : assert(avatar != null || spriteId != null, 'Provide avatar or spriteId');

  String get _resolvedId => spriteId ?? avatar?.id ?? 'male_red';

  String get _fallbackFrontPath => 'assets/images/trainers/${_resolvedId}_front.png';

  String get _assetPath {
    final clampedPose = pose.clamp(0, 2);
    if (!isBackView) {
      if (clampedPose == 0) {
        return _fallbackFrontPath;
      }
      return 'assets/images/trainers/${_resolvedId}_front_$clampedPose.png';
    }
    return 'assets/images/trainers/${_resolvedId}_back_$clampedPose.png';
  }

  @override
  Widget build(BuildContext context) {
    final double stepOffsetX = isBackView
        ? (pose == 1 ? -6.0 : (pose == 2 ? 12.0 : 0.0))
        : (pose == 1 ? 6.0 : (pose == 2 ? -12.0 : 0.0));
    final double stepScale = pose == 2 ? 1.06 : 1.0;

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
          alignment: Alignment.bottomCenter,
          filterQuality: FilterQuality.none,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Image.asset(
            _fallbackFrontPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person,
              size: size * 0.65,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
