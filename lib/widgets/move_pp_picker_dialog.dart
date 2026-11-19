import 'package:flutter/material.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';

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
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: item.color.withOpacity(0.45)),
        ),
        title: Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "RESTORE PP FOR ${pokemon.nickname.toUpperCase()}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
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
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
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
                      opacity: needsPp ? 1.0 : 0.42,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2236),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: needsPp
                                ? typeColor.withOpacity(0.55)
                                : Colors.white12,
                          ),
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
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    move.type.displayName.toUpperCase(),
                                    style: TextStyle(
                                      color: typeColor,
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
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "PP ${move.currentPp}/${move.maxPp}",
                                style: TextStyle(
                                  color: needsPp
                                      ? Colors.amberAccent
                                      : Colors.white54,
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
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    },
  );
}
