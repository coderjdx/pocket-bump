import 'package:flutter/material.dart';
import '../models/game_version.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import 'poke_theme.dart';
import 'pokemon_sprite_image.dart';

class VersionChoiceCard extends StatelessWidget {
  final GameVersion version;
  final bool isSelected;
  final VoidCallback onTap;
  final bool compact;

  const VersionChoiceCard({
    super.key,
    required this.version,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color primary = version.primaryColor;
    final Color secondary = version.secondaryColor;
    final mascot = PokedexDatabase.species[version.mascotSpeciesId];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(compact ? 11 : 14),
        decoration: BoxDecoration(
          color: isSelected ? PokeColors.cardWhite : PokeColors.creamSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : PokeColors.frameBorderSoft,
            width: isSelected ? 2.2 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? primary : PokeColors.frameBorder)
                  .withOpacity(isSelected ? 0.22 : 0.08),
              blurRadius: isSelected ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 54 : 66,
              height: compact ? 54 : 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primary.withOpacity(0.24),
                    secondary.withOpacity(0.08),
                  ],
                ),
                border: Border.all(
                  color: primary.withOpacity(isSelected ? 0.9 : 0.45),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: mascot != null
                    ? PokemonSpriteImage.fromSpecies(
                        mascot,
                        width: compact ? 46 : 56,
                        height: compact ? 46 : 56,
                        fallbackIconSize: compact ? 28 : 34,
                        fallbackIconColor: primary,
                      )
                    : Icon(Icons.catching_pokemon, color: primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          version.displayName.toUpperCase(),
                          style: TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 13 : 14.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [primary, secondary]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          version.elementTag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Exclusives: ${version.exclusivesSummary}",
                    style: TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: compact ? 10.2 : 11,
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? primary : PokeColors.inkSubtle,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-dismissible prompt for existing players whose save predates game versions.
Future<void> showVersionMigrationDialog(
  BuildContext context,
  Trainer trainer,
) async {
  GameVersion selected = GameVersion.red;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dlgCtx) => StatefulBuilder(
      builder: (dlgCtx, setDialogState) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected.primaryColor, width: 1.8),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          title: Row(
            children: [
              Icon(Icons.catching_pokemon, color: selected.primaryColor, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Choose Your Version",
                  style: TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Pocket Bump now features Red and Blue versions! Your existing Pokémon, items, and badges are completely safe. Pick your version to set which version-exclusive Pokémon appear in wild encounters:",
                  style: TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 12,
                    height: 1.38,
                  ),
                ),
                const SizedBox(height: 12),
                VersionChoiceCard(
                  version: GameVersion.red,
                  isSelected: selected == GameVersion.red,
                  compact: true,
                  onTap: () => setDialogState(() => selected = GameVersion.red),
                ),
                const SizedBox(height: 10),
                VersionChoiceCard(
                  version: GameVersion.blueGreen,
                  isSelected: selected == GameVersion.blueGreen,
                  compact: true,
                  onTap: () =>
                      setDialogState(() => selected = GameVersion.blueGreen),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Trade with friends on the other version via Fist Bump to complete your Pokédex!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PokeColors.pokeBlueDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  trainer.setGameVersion(selected);
                  Navigator.pop(dlgCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "START IN ${selected.displayName.toUpperCase()}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
