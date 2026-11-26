import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/egg_move_service.dart';
import '../services/sound_service.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/type_badge.dart';

class MoveTutorScreen extends StatefulWidget {
  const MoveTutorScreen({super.key});

  @override
  State<MoveTutorScreen> createState() => _MoveTutorScreenState();
}

class _MoveTutorScreenState extends State<MoveTutorScreen> {
  int _selectedPartyIdx = 0;

  String _categoryTag(MoveCategory cat) {
    switch (cat) {
      case MoveCategory.physical:
        return 'PHYS';
      case MoveCategory.special:
        return 'SPEC';
      case MoveCategory.status:
        return 'STAT';
    }
  }

  Color _categoryColor(MoveCategory cat) {
    switch (cat) {
      case MoveCategory.physical:
        return const Color(0xFFD84315);
      case MoveCategory.special:
        return PokeColors.pokeBlueDark;
      case MoveCategory.status:
        return const Color(0xFF7B1FA2);
    }
  }

  Future<void> _teachEggMove(
    Trainer trainer,
    PokemonInstance mon,
    Move eggMove,
  ) async {
    if (trainer.getItemCount('heart_scale') <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You need a Heart Scale! Defeat Gym Leaders or Team Rocket to earn Heart Scales.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (mon.moves.any((m) => m.id == eggMove.id) ||
        mon.learnedMoveIds.contains(eggMove.id)) {
      return;
    }

    final outcome = await showMoveLearnDialog(
      context,
      pokemon: mon,
      newMove: eggMove,
      recordOnSkip: false,
      headerNote:
          'Spend 1x Heart Scale to teach ${eggMove.name} to ${mon.nickname}?',
    );
    if (!outcome.learned || !mounted) return;

    trainer.adjustItemCount('heart_scale', -1);
    trainer.saveProgress();
    HapticFeedback.mediumImpact();
    SoundService.instance.playUiTap();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.forgottenMove != null
              ? '${mon.nickname} forgot ${outcome.forgottenMove!.name} and learned ${eggMove.name}!'
              : '${mon.nickname} learned ${eggMove.name}!',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int heartScales = trainer.getItemCount('heart_scale');
    final int safeIdx = trainer.party.isEmpty
        ? 0
        : _selectedPartyIdx.clamp(0, trainer.party.length - 1);
    final PokemonInstance? selectedMon =
        trainer.party.isEmpty ? null : trainer.party[safeIdx];
    final List<Move> eggMoves = selectedMon == null
        ? const []
        : EggMoveService.eggMovesForSpecies(selectedMon.species);

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: 'MOVE TUTOR',
        barColor: PokeColors.centerRose,
        bottomBorderColor: PokeColors.centerRoseDark,
        actions: [
          PokeCounterPill(
            icon: Icons.favorite_rounded,
            iconColor: PokeColors.centerRose,
            text: 'x$heartScales',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_pokemon_center.png',
            topOpacity: 0.22,
            midOpacity: 0.48,
            bottomOpacity: 0.88,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.creamSurface,
                      border: PokeColors.centerRose,
                      radius: 15,
                      borderWidth: 1.5,
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: PokeColors.centerRose,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Trade 1 Heart Scale to awaken an Egg Move for any party Pokémon. Heart Scales drop from Gym Leader rematches and Team Rocket.',
                            style: TextStyle(
                              color: PokeColors.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (trainer.party.isNotEmpty) ...[
                    const Text(
                      'CHOOSE PARTY POKÉMON',
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: trainer.party.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          final mon = trainer.party[idx];
                          final bool selected = idx == safeIdx;
                          final typeColor = mon.species.types.first.color;
                          return InkWell(
                            onTap: () =>
                                setState(() => _selectedPartyIdx = idx),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 96,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? PokeColors.cardWhite
                                    : PokeColors.creamSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? PokeColors.centerRose
                                      : typeColor.withOpacity(0.55),
                                  width: selected ? 2.2 : 1.2,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: PokeColors.centerRose
                                              .withOpacity(0.22),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  PokemonSpriteImage.fromInstance(
                                    mon,
                                    width: 40,
                                    height: 40,
                                    fallbackIconSize: 28,
                                    fallbackIconColor: typeColor,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mon.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? PokeColors.inkDark
                                          : PokeColors.inkMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'Lv.${mon.level}',
                                    style: const TextStyle(
                                      color: PokeColors.badgeGoldDark,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (selectedMon != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${selectedMon.nickname.toUpperCase()}'S EGG MOVES",
                          style: const TextStyle(
                            color: PokeColors.centerRoseDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${eggMoves.length} Available',
                          style: const TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  Expanded(
                    child: selectedMon == null || eggMoves.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: PokeDecorations.card(
                                fill: PokeColors.creamSurface,
                                border: PokeColors.frameBorderSoft,
                                radius: 16,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.egg_outlined,
                                    color: PokeColors.inkSubtle,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedMon == null
                                        ? 'No Pokémon in Party'
                                        : '${selectedMon.species.name} has no Egg Moves to tutor.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: PokeColors.inkMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: eggMoves.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, idx) {
                              final move = eggMoves[idx];
                              final bool alreadyActive = selectedMon.moves
                                  .any((m) => m.id == move.id);
                              final bool alreadyLearned = selectedMon
                                  .learnedMoveIds
                                  .contains(move.id);
                              final bool canTeach =
                                  !alreadyActive && !alreadyLearned;

                              return Opacity(
                                opacity: canTeach ? 1.0 : 0.65,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: PokeDecorations.card(
                                    fill: PokeColors.cardWhite,
                                    border: move.type.color,
                                    radius: 14,
                                    borderWidth: 1.4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    move.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: PokeColors.inkDark,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                TypeBadge(type: move.type),
                                                const SizedBox(width: 5),
                                                Text(
                                                  _categoryTag(move.category),
                                                  style: TextStyle(
                                                    color: _categoryColor(
                                                        move.category),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              alreadyLearned && !alreadyActive
                                                  ? 'Remembered — swap freely in Pokémon Info'
                                                  : 'PWR ${move.powerLabel} • ACC ${move.accuracy}% • PP ${move.maxPp}',
                                              style: const TextStyle(
                                                color: PokeColors.inkDark,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              move.description,
                                              style: const TextStyle(
                                                color: PokeColors.inkMuted,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton(
                                        onPressed: (canTeach && heartScales > 0)
                                            ? () => _teachEggMove(
                                                trainer, selectedMon, move)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: PokeColors.centerRose,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor:
                                              PokeColors.panelSoft,
                                          disabledForegroundColor:
                                              PokeColors.inkSubtle,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: Text(
                                          alreadyLearned
                                              ? 'KNOWN'
                                              : 'TEACH (1 ♥)',
                                          style: const TextStyle(
                                            fontSize: 10.5,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
