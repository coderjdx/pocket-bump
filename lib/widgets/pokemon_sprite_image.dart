import 'package:flutter/material.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';

/// Offline-first animated Gen 5 Pokémon sprite widget.
///
/// Renders directly from bundled `assets/sprites/...` GIFs so battles, PC boxes,
/// Pokédex entries, and menus work without an internet connection, falling back
/// to the PokeAPI network sprite and then a crisp Poké Ball icon if an asset
/// ever fails to load.
class PokemonSpriteImage extends StatelessWidget {
  final String assetPath;
  final String fallbackNetworkUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double fallbackIconSize;
  final Color fallbackIconColor;

  const PokemonSpriteImage({
    super.key,
    required this.assetPath,
    required this.fallbackNetworkUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.fallbackIconSize = 32,
    this.fallbackIconColor = Colors.white54,
  });

  factory PokemonSpriteImage.fromInstance(
    PokemonInstance pokemon, {
    Key? key,
    bool isBack = false,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    double fallbackIconSize = 32,
    Color fallbackIconColor = Colors.white54,
  }) {
    return PokemonSpriteImage(
      key: key,
      assetPath: isBack ? pokemon.backSpriteAsset : pokemon.spriteAsset,
      fallbackNetworkUrl:
          isBack ? pokemon.staticBackSpriteUrl : pokemon.staticSpriteUrl,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fallbackIconSize: fallbackIconSize,
      fallbackIconColor: fallbackIconColor,
    );
  }

  factory PokemonSpriteImage.fromSpecies(
    PokemonSpecies species, {
    Key? key,
    bool isBack = false,
    bool isShiny = false,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    AlignmentGeometry alignment = Alignment.center,
    double fallbackIconSize = 32,
    Color fallbackIconColor = Colors.white54,
  }) {
    final String asset = isBack
        ? (isShiny ? species.shinyBackSpriteAsset : species.backSpriteAsset)
        : (isShiny ? species.shinySpriteAsset : species.spriteAsset);
    final String fallback = isBack
        ? (isShiny ? species.staticShinyBackSpriteUrl : species.staticBackSpriteUrl)
        : (isShiny ? species.staticShinySpriteUrl : species.staticSpriteUrl);
    return PokemonSpriteImage(
      key: key,
      assetPath: asset,
      fallbackNetworkUrl: fallback,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      fallbackIconSize: fallbackIconSize,
      fallbackIconColor: fallbackIconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: FilterQuality.none,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.network(
        fallbackNetworkUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Icon(
          Icons.catching_pokemon,
          size: fallbackIconSize,
          color: fallbackIconColor,
        ),
      ),
    );
  }
}
