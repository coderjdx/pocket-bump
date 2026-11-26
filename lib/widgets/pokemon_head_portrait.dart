import 'package:flutter/material.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import 'poke_theme.dart';
import 'pokemon_sprite_image.dart';

Color statusConditionBadgeColor(StatusCondition status) {
  switch (status) {
    case StatusCondition.burn:
      return const Color(0xFFE65100);
    case StatusCondition.paralysis:
      return const Color(0xFFD89600);
    case StatusCondition.poison:
      return const Color(0xFF8E24AA);
    case StatusCondition.sleep:
      return const Color(0xFF3949AB);
    case StatusCondition.freeze:
      return const Color(0xFF0097A7);
    case StatusCondition.none:
      return Colors.transparent;
  }
}

class PokemonHeadPortrait extends StatelessWidget {
  final PokemonInstance pokemon;
  final double size;
  final double borderRadius;

  const PokemonHeadPortrait({
    super.key,
    required this.pokemon,
    this.size = 44,
    this.borderRadius = 11,
  });

  @override
  Widget build(BuildContext context) {
    final types = pokemon.species.types;
    final Color primary = types.first.color;
    final Color secondary = types.length > 1 ? types[1].color : primary;
    final bool fainted = pokemon.isFainted;

    Widget localPortraitFallback() => PokemonSpriteImage.fromInstance(
          pokemon,
          width: size,
          height: size,
          fallbackIconSize: size * 0.56,
          fallbackIconColor: Colors.white,
        );

    Widget portraitImage = Transform.scale(
      scale: 1.38,
      alignment: const Alignment(0.0, -0.44),
      child: Image.network(
        pokemon.artworkUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return localPortraitFallback();
        },
        errorBuilder: (_, __, ___) => localPortraitFallback(),
      ),
    );

    if (fainted) {
      portraitImage = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0xFF8E96A3),
          BlendMode.saturation,
        ),
        child: Opacity(opacity: 0.6, child: portraitImage),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: fainted
                    ? [const Color(0xFFDADDE3), const Color(0xFFBDC3CE)]
                    : [
                        Color.lerp(primary, Colors.white, 0.42)!,
                        Color.lerp(secondary, Colors.white, 0.22)!,
                      ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: fainted
                    ? PokeColors.inkSubtle
                    : (pokemon.isShiny ? PokeColors.badgeGold : primary),
                width: pokemon.isShiny ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 3,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular((borderRadius - 1.5).clamp(2, 24)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -size * 0.2,
                    left: -size * 0.1,
                    right: -size * 0.1,
                    height: size * 0.65,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.45),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  portraitImage,
                ],
              ),
            ),
          ),
          if (pokemon.isShiny)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: PokeColors.cardWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: PokeColors.badgeGoldDark, width: 1.0),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 9,
                  color: PokeColors.badgeGoldDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
