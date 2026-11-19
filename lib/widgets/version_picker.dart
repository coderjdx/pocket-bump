import 'package:flutter/material.dart';
import '../models/game_version.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';

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
    final bool isRed = version == GameVersion.red;
    final Color primary = version.primaryColor;
    final Color secondary = version.secondaryColor;
    final mascot = PokedexDatabase.species[version.mascotSpeciesId];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(compact ? 11 : 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [
                    primary.withOpacity(0.32),
                    secondary.withOpacity(0.18),
                    const Color(0xEE111524),
                  ]
                : [
                    const Color(0xE2161B2B),
                    const Color(0xE60F1320),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : Colors.white12,
            width: isSelected ? 2.0 : 1.1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.28),
                    blurRadius: 12,
                  ),
                ]
              : null,
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
                    primary.withOpacity(0.34),
                    secondary.withOpacity(0.10),
                  ],
                ),
                border: Border.all(
                  color: primary.withOpacity(isSelected ? 0.85 : 0.4),
                ),
              ),
              child: Center(
                child: mascot != null
                    ? Image.network(
                        mascot.spriteUrl,
                        width: compact ? 46 : 56,
                        height: compact ? 46 : 56,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Image.network(
                          mascot.staticSpriteUrl,
                          width: compact ? 44 : 54,
                          height: compact ? 44 : 54,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.catching_pokemon,
                            color: primary,
                            size: compact ? 28 : 34,
                          ),
                        ),
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
                            color: Colors.white,
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
                          isRed ? 'FIRE' : 'WATER / LEAF',
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
                      color: Colors.white70,
                      fontSize: compact ? 10.2 : 11,
                      height: 1.32,
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
              color: isSelected ? primary : Colors.white24,
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
          backgroundColor: const Color(0xFF131726),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: selected.primaryColor.withOpacity(0.55)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
          contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
          actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          title: const Row(
            children: [
              Icon(Icons.catching_pokemon, color: Colors.amberAccent, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Choose Your Version",
                  style: TextStyle(
                    color: Colors.white,
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
                  "Pocket Bump now features Red and Blue / Green versions! Your existing Pokémon, items, and badges are completely safe. Pick your version to set which version-exclusive Pokémon appear in wild encounters:",
                  style: TextStyle(
                    color: Colors.white70,
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
                    color: Colors.amberAccent,
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
