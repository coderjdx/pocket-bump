import 'package:flutter/material.dart';

class HpBar extends StatelessWidget {
  final int currentHp;
  final int maxHp;

  const HpBar({
    super.key,
    required this.currentHp,
    required this.maxHp,
  });

  @override
  Widget build(BuildContext context) {
    final double targetPercent =
        maxHp > 0 ? (currentHp / maxHp).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            const Text(
              "HP",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3.5),
                  child: Stack(
                    children: [
                      // White/red trailing damage bar
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: targetPercent),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, trailVal, _) {
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: trailVal,
                            child: Container(color: Colors.white.withOpacity(0.75)),
                          );
                        },
                      ),
                      // Foreground colored HP bar
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: targetPercent),
                        duration: const Duration(milliseconds: 550),
                        curve: Curves.easeOutCubic,
                        builder: (context, animPercent, _) {
                          Color barColor = const Color(0xFF48D0B0); // Green
                          if (animPercent <= 0.2) {
                            barColor = const Color(0xFFF05030); // Red
                          } else if (animPercent <= 0.5) {
                            barColor = const Color(0xFFF8D030); // Yellow
                          }
                          return FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: animPercent,
                            child: Container(color: barColor),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "$currentHp / $maxHp",
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
