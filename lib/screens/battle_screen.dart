import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/move.dart';
import '../models/trainer.dart';
import '../services/battle_engine.dart';
import '../widgets/hp_bar.dart';
import '../widgets/type_badge.dart';

class BattleScreen extends StatefulWidget {
  final PokemonInstance opponentPokemon;
  final bool isWild;

  const BattleScreen({
    super.key,
    required this.opponentPokemon,
    this.isWild = true,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late PokemonInstance _playerPokemon;
  late PokemonInstance _opponentPokemon;
  List<String> _battleLog = [];
  bool _isSelectingMove = false;
  bool _isProcessingTurn = false;
  bool _battleEnded = false;

  @override
  void initState() {
    super.initState();
    final trainer = Provider.of<Trainer>(context, listen: false);
    _playerPokemon = trainer.leadPokemon!;
    _opponentPokemon = widget.opponentPokemon;

    _battleLog.add(widget.isWild
        ? "A wild ${_opponentPokemon.species.name} appeared!"
        : "Opponent sent out ${_opponentPokemon.species.name}!");
  }

  void _onMoveSelected(Move move) async {
    if (_isProcessingTurn || _battleEnded) return;

    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
    });

    // 1. Pick AI move for opponent
    final opponentMove = _opponentPokemon.moves.isNotEmpty
        ? _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)]
        : null;

    final playerAction = BattleAction.fight(move);
    final opponentAction = opponentMove != null
        ? BattleAction.fight(opponentMove)
        : BattleAction.run();

    // 2. Resolve turn using the BattleEngine
    final logs = BattleEngine.resolveTurn(
      playerMon: _playerPokemon,
      playerAction: playerAction,
      opponentMon: _opponentPokemon,
      opponentAction: opponentAction,
    );

    // 3. Play logs sequentially
    for (var log in logs) {
      if (!mounted) return;
      setState(() {
        _battleLog.add(log);
      });
      await Future.delayed(const Duration(milliseconds: 900));
    }

    // 4. Check Win/Loss conditions
    if (_opponentPokemon.isFainted) {
      int expGained = (_opponentPokemon.species.baseExp * _opponentPokemon.level) ~/ 7;
      bool leveledUp = _playerPokemon.gainExp(expGained);

      setState(() {
        _battleLog.add("${_playerPokemon.nickname} gained $expGained EXP!");
        if (leveledUp) {
          _battleLog.add("${_playerPokemon.nickname} grew to Level ${_playerPokemon.level}!");
        }
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else if (_playerPokemon.isFainted) {
      setState(() {
        _battleLog.add("${_playerPokemon.nickname} fainted! You lost the battle...");
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  void _onThrowPokeBall(String ballType) async {
    final trainer = Provider.of<Trainer>(context, listen: false);

    if (trainer.pokeBalls <= 0 && ballType == 'poke_ball') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have no Poké Balls left!")),
      );
      return;
    }

    setState(() {
      if (ballType == 'poke_ball') trainer.pokeBalls--;
      _isProcessingTurn = true;
      _battleLog.add("${trainer.name} threw a ${ballType.replaceAll('_', ' ').toUpperCase()}!");
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    bool caught = BattleEngine.attemptCapture(
      target: _opponentPokemon,
      ballType: ballType,
    );

    if (caught) {
      trainer.addPokemon(_opponentPokemon);
      setState(() {
        _battleLog.add("All right! ${_opponentPokemon.species.name} was caught!");
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else {
      setState(() {
        _battleLog.add("Oh no! The Pokémon broke free!");
      });

      // Opponent gets a free attack!
      await Future.delayed(const Duration(milliseconds: 800));
      if (_opponentPokemon.moves.isNotEmpty) {
        final oppMove = _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)];
        final logs = BattleEngine.resolveTurn(
          playerMon: _playerPokemon,
          playerAction: BattleAction.run(), // player spent turn throwing ball
          opponentMon: _opponentPokemon,
          opponentAction: BattleAction.fight(oppMove),
        );
        for (var log in logs) {
          if (!mounted) return;
          setState(() {
            _battleLog.add(log);
          });
          await Future.delayed(const Duration(milliseconds: 900));
        }
      }
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isWild ? "WILD ENCOUNTER" : "PVP BATTLE",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── ARENA / COMBATANTS VIEW ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // Opponent Pokémon Card (Top-Right)
                  Positioned(
                    top: 10,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildPokemonInfoCard(_opponentPokemon, isPlayer: false),
                        const SizedBox(height: 8),
                        Image.network(
                          _opponentPokemon.species.spriteUrl,
                          width: 110,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) =>
                              const Icon(Icons.catching_pokemon, size: 80, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Player Pokémon Card (Bottom-Left)
                  Positioned(
                    bottom: 10,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          _playerPokemon.species.spriteUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stack) =>
                              const Icon(Icons.catching_pokemon, size: 90, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        _buildPokemonInfoCard(_playerPokemon, isPlayer: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── BATTLE LOG BOX ──────────────────────────────────────────
            Container(
              height: 70,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _battleLog.isNotEmpty ? _battleLog.last : "What will you do?",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),

            // ─── ACTION MENUS / MOVE SELECTION ───────────────────────────
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: _battleEnded
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text("FINISH ENCOUNTER"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      )
                    : (_isSelectingMove ? _buildMoveSelection() : _buildMainActionMenu()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPokemonInfoCard(PokemonInstance mon, {required bool isPlayer}) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A35).withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  mon.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ),
              Text(
                "Lv.${mon.level}",
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
        ],
      ),
    );
  }

  Widget _buildMainActionMenu() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionButton("FIGHT", Colors.red.shade700, Icons.flash_on, () {
          setState(() => _isSelectingMove = true);
        }),
        _buildActionButton("BAG", Colors.amber.shade800, Icons.backpack, _openBagModal),
        _buildActionButton("POKÉMON", Colors.green.shade700, Icons.catching_pokemon, _openSwitchModal),
        _buildActionButton("RUN", Colors.blueGrey.shade700, Icons.directions_run, () {
          Navigator.pop(context);
        }),
      ],
    );
  }

  Widget _buildMoveSelection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("SELECT A MOVE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60)),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              onPressed: () => setState(() => _isSelectingMove = false),
            ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            gridDelegate: const dynamicDelegate(),
            itemCount: _playerPokemon.moves.length,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (ctx, idx) {
              final move = _playerPokemon.moves[idx];
              return ElevatedButton(
                onPressed: _isProcessingTurn ? null : () => _onMoveSelected(move),
                style: ElevatedButton.styleFrom(
                  backgroundColor: move.type.color.withOpacity(0.85),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(move.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(move.type.displayName.toUpperCase(), style: const TextStyle(fontSize: 9, color: Colors.white70)),
                        Text("PP ${move.currentPp}/${move.maxPp}", style: const TextStyle(fontSize: 9, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openBagModal() {
    final trainer = Provider.of<Trainer>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("TRAINER BAG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.catching_pokemon, color: Colors.redAccent, size: 30),
                title: const Text("Poké Ball", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("x${trainer.pokeBalls} remaining", style: const TextStyle(color: Colors.white60)),
                trailing: ElevatedButton(
                  onPressed: trainer.pokeBalls > 0
                      ? () {
                          Navigator.pop(ctx);
                          _onThrowPokeBall('poke_ball');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("THROW"),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.medical_services, color: Colors.greenAccent, size: 30),
                title: const Text("Potion", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("x${trainer.potions} remaining (+20 HP)", style: const TextStyle(color: Colors.white60)),
                trailing: ElevatedButton(
                  onPressed: trainer.potions > 0 && _playerPokemon.currentHp < _playerPokemon.maxHp
                      ? () {
                          trainer.potions--;
                          _playerPokemon.currentHp = (_playerPokemon.currentHp + 20).clamp(0, _playerPokemon.maxHp);
                          Navigator.pop(ctx);
                          setState(() {
                            _battleLog.add("${trainer.name} used a Potion! ${_playerPokemon.nickname} healed 20 HP.");
                          });
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("USE"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSwitchModal() {
    final trainer = Provider.of<Trainer>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("SWITCH POKÉMON", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              ...trainer.party.map((mon) {
                final isCurrent = mon == _playerPokemon;
                return ListTile(
                  leading: Image.network(mon.species.spriteUrl, width: 40, height: 40, errorBuilder: (c, e, s) => const Icon(Icons.catching_pokemon, color: Colors.white)),
                  title: Text(mon.nickname, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("Lv.${mon.level} • HP ${mon.currentHp}/${mon.maxHp}", style: const TextStyle(color: Colors.white60)),
                  trailing: isCurrent
                      ? const Text("ACTIVE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))
                      : ElevatedButton(
                          onPressed: mon.isFainted
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _playerPokemon = mon;
                                    _battleLog.add("Go! ${_playerPokemon.nickname}!");
                                  });
                                },
                          child: const Text("SWITCH"),
                        ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String title, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isProcessingTurn ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    );
  }
}

class dynamicDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const dynamicDelegate()
      : super(
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        );
}
