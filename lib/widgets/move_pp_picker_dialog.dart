import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import 'poke_theme.dart';

/// Prompts the player to choose which move on [pokemon] should receive PP from [item].
/// Returns the chosen move index (`0..pokemon.moves.length - 1`), or `null` if cancelled.
Future<int?> showMovePpPickerDialog(
  BuildContext context, {
  required PokemonInstance pokemon,
  required Item item,
}) {
  return showDialog<int>(
    context: context,
    builder: (dlgCtx) {
      return AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: item.color.withOpacity(0.65), width: 1.6),
        ),
        title: Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "RESTORE PP FOR ${pokemon.nickname.toUpperCase()}",
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.id == 'max_ether'
                    ? "Choose a move to fully restore its PP:"
                    : "Choose a move to restore up to 10 PP:",
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                itemCount: pokemon.moves.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, idx) {
                  final move = pokemon.moves[idx];
                  final bool needsPp = move.currentPp < move.maxPp;
                  final Color typeColor = move.type.color;
                  return InkWell(
                    onTap: needsPp ? () => Navigator.pop(dlgCtx, idx) : null,
                    borderRadius: BorderRadius.circular(11),
                    child: Opacity(
                      opacity: needsPp ? 1.0 : 0.48,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: PokeDecorations.card(
                          fill: PokeColors.cardWhite,
                          border: needsPp
                              ? typeColor.withOpacity(0.7)
                              : PokeColors.frameBorderSoft,
                          radius: 11,
                          borderWidth: 1.4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 26,
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    move.name,
                                    style: const TextStyle(
                                      color: PokeColors.inkDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    move.type.displayName.toUpperCase(),
                                    style: TextStyle(
                                      color: PokeColors.darken(typeColor, 0.14),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: needsPp
                                    ? PokeColors.badgeGold.withOpacity(0.16)
                                    : PokeColors.panelSoft,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: needsPp
                                      ? PokeColors.badgeGold
                                      : PokeColors.frameBorderSoft,
                                ),
                              ),
                              child: Text(
                                "PP ${move.currentPp}/${move.maxPp}",
                                style: TextStyle(
                                  color: needsPp
                                      ? PokeColors.badgeGoldDark
                                      : PokeColors.inkSubtle,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, null),
            child: const Text(
              "Cancel",
              style: TextStyle(
                color: PokeColors.inkMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    },
  );
}
