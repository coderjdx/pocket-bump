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
        return Colors.orangeAccent;
      case MoveCategory.special:
        return Colors.lightBlueAccent;
      case MoveCategory.status:
        return Colors.purpleAccent;
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
      backgroundColor: const Color(0xFF100E18),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC120D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MOVE TUTOR',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF180C16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFF6B9D).withOpacity(0.65),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFFF6B9D),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'x$heartScales',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_center.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1B0F1E).withOpacity(0.84),
                  const Color(0xFF131122).withOpacity(0.76),
                  const Color(0xFF0A0912).withOpacity(0.94),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xE8161124),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFF6B9D).withOpacity(0.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF6B9D),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Trade 1 Heart Scale to awaken an Egg Move for any party Pokémon. Heart Scales drop from Gym Leader rematches and Team Rocket.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
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
                        color: Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: trainer.party.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, idx) {
                          final mon = trainer.party[idx];
                          final bool selected = idx == safeIdx;
                          final typeColor = mon.species.types.first.color;
                          return InkWell(
                            onTap: () => setState(() => _selectedPartyIdx = idx),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 96,
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF281934)
                                    : const Color(0xFF141726),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFF6B9D)
                                      : typeColor.withOpacity(0.32),
                                  width: selected ? 1.6 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    mon.spriteUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.catching_pokemon,
                                      color: typeColor,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    mon.nickname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Lv.${mon.level}',
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
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
                            color: Color(0xFFFF8BB3),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${eggMoves.length} Available',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
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
                              decoration: BoxDecoration(
                                color: const Color(0xE0141726),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.egg_outlined,
                                    color: Colors.white30,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    selectedMon == null
                                        ? 'No Pokémon in Party'
                                        : '${selectedMon.species.name} has no Egg Moves to tutor.',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
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
                                opacity: canTeach ? 1.0 : 0.62,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE815192B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: move.type.color.withOpacity(0.45),
                                    ),
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
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                    fontWeight: FontWeight.bold,
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
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                            ),
                                            Text(
                                              move.description,
                                              style: const TextStyle(
                                                color: Colors.white54,
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
                                          backgroundColor:
                                              const Color(0xFFFF6B9D),
                                          foregroundColor: Colors.black,
                                          disabledBackgroundColor:
                                              Colors.white10,
                                          disabledForegroundColor:
                                              Colors.white38,
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
