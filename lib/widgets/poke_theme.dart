import 'package:flutter/material.dart';

/// Authentic Pokémon handheld-inspired color system & bright game surfaces.
class PokeColors {
  PokeColors._();

  // Zone & Command Button Primaries
  static const Color pokeRed = Color(0xFFE53935);
  static const Color pokeRedDark = Color(0xFFB71C1C);

  static const Color pokeGreen = Color(0xFF2E9E5B);
  static const Color pokeGreenDark = Color(0xFF1B6E3E);

  static const Color pokeBlue = Color(0xFF1E88E5);
  static const Color pokeBlueDark = Color(0xFF1557B0);

  static const Color pokeGold = Color(0xFFFB8C00);
  static const Color pokeGoldDark = Color(0xFFD84315);

  static const Color badgeGold = Color(0xFFFFB300);
  static const Color badgeGoldDark = Color(0xFFA66300);

  static const Color centerRose = Color(0xFFE53960);
  static const Color centerRoseDark = Color(0xFFB01E44);

  static const Color bagOrange = Color(0xFFEF6C00);
  static const Color bagOrangeDark = Color(0xFFB54700);

  static const Color leagueIndigo = Color(0xFF283593);
  static const Color leagueIndigoDark = Color(0xFF1A237E);

  static const Color pcTeal = Color(0xFF0288D1);
  static const Color pcTealDark = Color(0xFF01579B);

  static const Color linkTeal = Color(0xFF00838F);
  static const Color linkTealDark = Color(0xFF005662);

  static const Color giftCrimson = Color(0xFFC62828);
  static const Color giftCrimsonDark = Color(0xFF8E0000);

  // Cream / Ivory Game Panels & Crisp Ink
  static const Color canvasCream = Color(0xFFECE9DF);
  static const Color creamSurface = Color(0xFFF8F6EF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color panelSoft = Color(0xFFEEEAE0);
  static const Color frameBorder = Color(0xFF2F3B4C);
  static const Color frameBorderSoft = Color(0xFFD0CBBF);

  static const Color inkDark = Color(0xFF1E2430);
  static const Color inkMuted = Color(0xFF526074);
  static const Color inkSubtle = Color(0xFF7B8798);

  /// Slightly darkens saturated type colors so white header/badge text always pops.
  static Color darken(Color color, [double amount = 0.22]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.18, 0.72))
        .toColor();
  }
}

/// Tactile portrait-oriented Pokémon command button with large centered icon.
class PokePortraitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color topColor;
  final Color bottomColor;
  final VoidCallback? onTap;
  final double height;
  final double iconSize;
  final String? badgeText;
  final String? subtitle;
  final Widget? iconOverride;
  final bool locked;
  final bool selected;

  const PokePortraitButton({
    super.key,
    required this.label,
    required this.icon,
    required this.topColor,
    required this.bottomColor,
    required this.onTap,
    this.height = 144,
    this.iconSize = 38,
    this.badgeText,
    this.subtitle,
    this.iconOverride,
    this.locked = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color effectiveTop = locked ? const Color(0xFF788596) : topColor;
    final Color effectiveBottom =
        locked ? const Color(0xFF475569) : bottomColor;

    return SizedBox(
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [effectiveTop, effectiveBottom],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(selected ? 0.98 : 0.85),
                width: selected ? 2.4 : 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: effectiveBottom.withOpacity(0.45),
                  offset: const Offset(0, 5),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: effectiveBottom,
                  offset: const Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Top gloss strip
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.24),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Subtle Poké Ball watermark
                  Positioned(
                    right: -14,
                    bottom: -14,
                    child: Icon(
                      Icons.catching_pokemon,
                      size: 76,
                      color: Colors.white.withOpacity(0.11),
                    ),
                  ),
                  if (badgeText != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.28),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (badgeText != null) const SizedBox(height: 8),
                        Container(
                          width: iconSize + 18,
                          height: iconSize + 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.45),
                              width: 1.4,
                            ),
                          ),
                          child: Center(
                            child: iconOverride ??
                                Icon(
                                  locked ? Icons.lock_rounded : icon,
                                  size: iconSize,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                height: 1.12,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.32),
                                    offset: const Offset(0, 1.5),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontSize: 8.8,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class PokeDecorations {
  PokeDecorations._();

  static BoxDecoration card({
    Color? fill,
    Color? border,
    double radius = 16,
    double borderWidth = 1.6,
  }) {
    return BoxDecoration(
      color: fill ?? PokeColors.cardWhite,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: border ?? PokeColors.frameBorderSoft,
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: PokeColors.frameBorder.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static BoxDecoration inset({
    Color? fill,
    Color? border,
    double radius = 12,
  }) {
    return BoxDecoration(
      color: fill ?? PokeColors.panelSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: border ?? PokeColors.frameBorderSoft,
        width: 1.2,
      ),
    );
  }
}

/// Renders scenic pixel-art background art brightly under a light sunlit cream veil.
class PokeBackdrop extends StatelessWidget {
  final String assetPath;
  final Color tint;
  final double topOpacity;
  final double midOpacity;
  final double bottomOpacity;
  final Alignment alignment;

  const PokeBackdrop({
    super.key,
    required this.assetPath,
    this.tint = PokeColors.creamSurface,
    this.topOpacity = 0.22,
    this.midOpacity = 0.44,
    this.bottomOpacity = 0.86,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          assetPath,
          fit: BoxFit.cover,
          alignment: alignment,
          filterQuality: FilterQuality.none,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tint.withOpacity(topOpacity),
                tint.withOpacity(midOpacity),
                tint.withOpacity(bottomOpacity),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

PreferredSizeWidget buildPokeAppBar({
  required BuildContext context,
  required String title,
  required Color barColor,
  Color? bottomBorderColor,
  VoidCallback? onBack,
  Widget? titleLeading,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
}) {
  final Color bevel = bottomBorderColor ?? PokeColors.darken(barColor, 0.14);
  return AppBar(
    backgroundColor: barColor,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: bevel.withOpacity(0.45),
    surfaceTintColor: Colors.transparent,
    centerTitle: titleLeading == null,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size: 18,
      ),
      onPressed: onBack ?? () => Navigator.pop(context),
    ),
    title: titleLeading == null
        ? Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              titleLeading,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    actions: actions,
    bottom: bottom ??
        PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: bevel),
        ),
  );
}

class PokeSheetHeader extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final VoidCallback onClose;
  final String? subtitle;

  const PokeSheetHeader({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.onClose,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.28),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: PokeColors.inkMuted),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class PokeCurrencyPill extends StatelessWidget {
  final int money;

  const PokeCurrencyPill(this.money, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PokeColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PokeColors.badgeGold, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '₽',
            style: TextStyle(
              color: PokeColors.badgeGoldDark,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$money',
            style: const TextStyle(
              color: PokeColors.inkDark,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class PokeCounterPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const PokeCounterPill({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PokeColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.65), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: PokeColors.inkDark,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
