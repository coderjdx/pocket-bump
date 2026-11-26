import 'package:flutter/material.dart';
import '../models/trainer_avatar.dart';
import 'poke_theme.dart';

class TrainerBustPortrait extends StatelessWidget {
  final TrainerAvatar? avatar;
  final String? spriteId;
  final BoxFit fit;

  const TrainerBustPortrait({
    super.key,
    this.avatar,
    this.spriteId,
    this.fit = BoxFit.cover,
  }) : assert(avatar != null || spriteId != null, 'Provide avatar or spriteId');

  String get _resolvedId => spriteId ?? avatar?.id ?? 'male_red';

  @override
  Widget build(BuildContext context) {
    final bustAsset = 'assets/images/trainers/${_resolvedId}_bust.png';
    final frontAsset = 'assets/images/trainers/${_resolvedId}_front.png';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD5ECFD), Color(0xFFF3F9FF)],
        ),
      ),
      child: Image.asset(
        bustAsset,
        fit: fit,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 0.58,
            child: Transform.scale(
              scale: 1.55,
              alignment: const Alignment(0, -0.78),
              child: Image.asset(
                frontAsset,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: PokeColors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
