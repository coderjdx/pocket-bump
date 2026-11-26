import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import 'poke_theme.dart';
import 'pokemon_sprite_image.dart';
import 'type_badge.dart';

class MoveLearnOutcome {
  final bool learned;
  final Move? forgottenMove;

  const MoveLearnOutcome({
    required this.learned,
    this.forgottenMove,
  });
}

String _moveCategoryLabel(MoveCategory cat) {
  switch (cat) {
    case MoveCategory.physical:
      return 'PHYS';
    case MoveCategory.special:
      return 'SPEC';
    case MoveCategory.status:
      return 'STAT';
  }
}

Color _moveCategoryColor(MoveCategory cat) {
  switch (cat) {
    case MoveCategory.physical:
      return const Color(0xFFD84315);
    case MoveCategory.special:
      return PokeColors.pokeBlue;
    case MoveCategory.status:
      return const Color(0xFF7B1FA2);
  }
}

Future<MoveLearnOutcome> showMoveLearnDialog(
  BuildContext context, {
  required PokemonInstance pokemon,
  required Move newMove,
  bool recordOnSkip = true,
  String? headerNote,
}) async {
  if (pokemon.moves.any((m) => m.id == newMove.id)) {
    return const MoveLearnOutcome(learned: false);
  }

  if (pokemon.moves.length < 4) {
    pokemon.recordLearnedMoveId(newMove.id);
    pokemon.moves.add(newMove.copy());
    return const MoveLearnOutcome(learned: true);
  }

  final Move? replaced = await showDialog<Move?>(
    context: context,
    barrierDismissible: false,
    builder: (dlgCtx) {
      return Dialog(
        backgroundColor: PokeColors.creamSurface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: newMove.type.color, width: 1.8),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dlgCtx).size.height * 0.85,
            maxWidth: 420,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PokemonSpriteImage.fromInstance(
                      pokemon,
                      width: 44,
                      height: 44,
                      fallbackIconSize: 32,
                      fallbackIconColor: pokemon.species.types.first.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (pokemon.isShiny) ...[
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: PokeColors.badgeGoldDark,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Flexible(
                                child: Text(
                                  "${pokemon.nickname.toUpperCase()} • Lv.${pokemon.level}",
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PokeColors.badgeGoldDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Learn ${newMove.name}?",
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  headerNote ??
                      "${pokemon.nickname} already knows 4 moves. Pick a move below to replace with ${newMove.name}:",
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),

                // Highlighted New Move Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PokeColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: newMove.type.color,
                      width: 1.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PokeColors.badgeGold,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              "NEW",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              newMove.name,
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          TypeBadge(type: newMove.type),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _moveCategoryColor(newMove.category)
                                  .withOpacity(0.14),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _moveCategoryLabel(newMove.category),
                              style: TextStyle(
                                color: _moveCategoryColor(newMove.category),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "PWR ${newMove.powerLabel} • ACC ${newMove.accuracy}% • PP ${newMove.maxPp}",
                            style: const TextStyle(
                              color: PokeColors.inkMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newMove.description,
                        style: const TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const Text(
                  "SELECT A MOVE TO REPLACE",
                  style: TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pokemon.moves.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, idx) {
                      final existing = pokemon.moves[idx];
                      return InkWell(
                        onTap: () => Navigator.pop(dlgCtx, existing),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: PokeDecorations.card(
                            fill: PokeColors.cardWhite,
                            border: existing.type.color.withOpacity(0.65),
                            radius: 12,
                            borderWidth: 1.4,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            existing.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: PokeColors.inkDark,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        TypeBadge(type: existing.type),
                                        const SizedBox(width: 6),
                                        Text(
                                          _moveCategoryLabel(existing.category),
                                          style: TextStyle(
                                            color: _moveCategoryColor(
                                                existing.category),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "PWR ${existing.powerLabel} • ACC ${existing.accuracy}% • PP ${existing.currentPp}/${existing.maxPp}",
                                      style: const TextStyle(
                                        color: PokeColors.inkMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      existing.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: PokeColors.inkSubtle,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 6),
                                decoration: BoxDecoration(
                                  color: PokeColors.pokeRed.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: PokeColors.pokeRed.withOpacity(0.65),
                                  ),
                                ),
                                child: const Text(
                                  "REPLACE",
                                  style: TextStyle(
                                    color: PokeColors.pokeRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),
                if (recordOnSkip)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Tip: Skipped level-up moves can still be swapped in later via Pokémon → Moves.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PokeColors.pokeBlue,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dlgCtx, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PokeColors.inkMuted,
                      side: const BorderSide(color: PokeColors.frameBorderSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "DO NOT LEARN ${newMove.name.toUpperCase()}",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (replaced != null) {
    final slotIdx = pokemon.moves.indexOf(replaced);
    if (slotIdx >= 0) {
      pokemon.swapActiveMove(slotIdx, newMove);
      return MoveLearnOutcome(learned: true, forgottenMove: replaced);
    }
  }

  if (recordOnSkip) {
    pokemon.recordLearnedMoveId(newMove.id);
  }
  return const MoveLearnOutcome(learned: false);
}
