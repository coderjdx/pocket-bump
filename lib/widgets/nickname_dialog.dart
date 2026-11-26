import 'package:flutter/material.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../services/sound_service.dart';
import 'poke_theme.dart';
import 'pokemon_head_portrait.dart';

Future<String?> showNicknamePokemonDialog(
  BuildContext context, {
  required PokemonInstance pokemon,
  bool isOnCatch = false,
}) async {
  if (!pokemon.canSetNickname) return null;

  final controller = TextEditingController();
  final typeColor = pokemon.species.types.first.color;

  final result = await showDialog<String?>(
    context: context,
    barrierDismissible: !isOnCatch,
    builder: (dlgCtx) {
      return StatefulBuilder(
        builder: (context, setDlgState) {
          final trimmed = controller.text.trim();
          final canSave = trimmed.isNotEmpty;

          return AlertDialog(
            backgroundColor: PokeColors.creamSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: typeColor, width: 2.0),
            ),
            titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            contentPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            title: Row(
              children: [
                PokemonHeadPortrait(pokemon: pokemon, size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnCatch
                            ? "Give ${pokemon.species.name} a nickname?"
                            : "Nickname ${pokemon.species.name}",
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        "${pokemon.species.name} • Lv.${pokemon.level}",
                        style: const TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 14,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: pokemon.species.name,
                    hintStyle: const TextStyle(
                      color: PokeColors.inkSubtle,
                      fontWeight: FontWeight.w600,
                    ),
                    filled: true,
                    fillColor: PokeColors.cardWhite,
                    counterStyle: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 10,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: PokeColors.frameBorderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: PokeColors.frameBorderSoft,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: typeColor, width: 2.0),
                    ),
                  ),
                  onChanged: (_) => setDlgState(() {}),
                  onSubmitted: (_) {
                    if (controller.text.trim().isNotEmpty) {
                      SoundService.instance.playUiConfirm();
                      Navigator.pop(dlgCtx, controller.text.trim());
                    }
                  },
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: PokeDecorations.inset(
                    fill: const Color(0xFFFFF4E5),
                    border: PokeColors.bagOrange.withOpacity(0.55),
                    radius: 10,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_clock_rounded,
                        size: 16,
                        color: PokeColors.bagOrangeDark,
                      ),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          "Once nicknamed, this Pokémon's name is permanent and cannot be changed.",
                          style: TextStyle(
                            color: PokeColors.bagOrangeDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SoundService.instance.playUiTap();
                  Navigator.pop(dlgCtx, null);
                },
                child: Text(
                  isOnCatch ? "Skip" : "Cancel",
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: canSave
                    ? () {
                        SoundService.instance.playUiConfirm();
                        Navigator.pop(dlgCtx, trimmed);
                      }
                    : null,
                icon: const Icon(Icons.check_rounded, size: 17),
                label: const Text(
                  "Confirm Name",
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: PokeColors.panelSoft,
                  disabledForegroundColor: PokeColors.inkSubtle,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();
  return result;
}
