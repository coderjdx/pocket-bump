import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/battle_engine.dart';
import '../services/pokedex_database.dart';
import '../widgets/hp_bar.dart';
import '../widgets/trainer_sprite.dart';

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

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
  late Trainer _trainer;
  late PokemonInstance _playerPokemon;
  late PokemonInstance _opponentPokemon;

  late int _displayedPlayerHp;
  late int _displayedOpponentHp;

  String _currentMessage = "";
  bool _isSelectingMove = false;
  bool _isProcessingTurn = true;
  bool _battleEnded = false;
  bool _didHealOnExit = false;

  // Animation states
  late AnimationController _idleController;
  late AnimationController _playerShakeController;
  late AnimationController _opponentShakeController;
  late AnimationController _playerKoController;
  late AnimationController _opponentKoController;
  late AnimationController _arenaShakeController;
  late AnimationController _vfxController;
  late AnimationController _ballWobbleController;

  Offset _playerLungeOffset = Offset.zero;
  Offset _opponentLungeOffset = Offset.zero;
  bool _playerFlash = false;
  bool _opponentFlash = false;
  bool _visualPlayerFainted = false;
  bool _visualOpponentFainted = false;
  bool _opponentInBall = false;
  bool _showPokeBallThrow = false;
  bool _showEvolutionGlow = false;
  String _throwingBallType = 'poke_ball';

  // Trainer & summon throw states
  bool _showTrainerSprite = true;
  int _trainerPose = 0; // 0 = ready, 1 = windup, 2 = throw
  double _trainerSlideX = 0.0;
  bool _showPlayerPokemon = false;
  double _playerSummonScale = 0.05;
  bool _showSummonBallArc = false;
  bool _showSummonBurst = false;
  String _trainerHeldBallType = 'poke_ball';

  // Active full-arena VFX overlay state
  String? _activeMoveId;
  PokemonType? _activeVfxType;
  bool _vfxAttackerIsPlayer = true;
  bool _vfxTargetIsSelf = false;
  String? _floatingCallout;
  bool _calloutOnOpponent = true;
  Color _calloutColor = Colors.amberAccent;

  @override
  void initState() {
    super.initState();
    _trainer = Provider.of<Trainer>(context, listen: false);
    _playerPokemon = _trainer.leadPokemon!;
    _opponentPokemon = widget.opponentPokemon;
    _displayedPlayerHp = _playerPokemon.currentHp;
    _displayedOpponentHp = _opponentPokemon.currentHp;

    _currentMessage = widget.isWild
        ? "A wild ${_opponentPokemon.species.name} appeared!"
        : "Rival sent out ${_opponentPokemon.species.name}!";

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _playerShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _opponentShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _playerKoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );

    _opponentKoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );

    _arenaShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );

    _ballWobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trainer.markPokemonSeen(_opponentPokemon.species.id);
      _playBattleIntroSummon();
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    _playerShakeController.dispose();
    _opponentShakeController.dispose();
    _playerKoController.dispose();
    _opponentKoController.dispose();
    _arenaShakeController.dispose();
    _vfxController.dispose();
    _ballWobbleController.dispose();
    if (!_didHealOnExit) {
      _didHealOnExit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trainer.healAndResetAllParty();
      });
    }
    super.dispose();
  }

  void _finishAndExit() {
    if (!_didHealOnExit) {
      _didHealOnExit = true;
      _trainer.healAndResetAllParty();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// Maps pixel coordinates from the 900x750 battle_bg_route.png into the BoxFit.cover arena
  Offset _mapBgPoint(double bgX, double bgY, double arenaW, double arenaH) {
    const double imgW = 900.0;
    const double imgH = 750.0;
    final double scale = max(arenaW / imgW, arenaH / imgH);
    final double xOffset = (arenaW - imgW * scale) / 2.0;
    final double yOffset = (arenaH - imgH * scale) / 2.0;
    return Offset(xOffset + bgX * scale, yOffset + bgY * scale);
  }

  Future<void> _playBattleIntroSummon() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    setState(() {
      _currentMessage = "${_trainer.name}: Go! ${_playerPokemon.nickname}!";
    });

    await _animateTrainerSummonThrow(_playerPokemon);
    if (!mounted) return;

    setState(() {
      _isProcessingTurn = false;
    });
  }

  Future<void> _animateTrainerSummonThrow(PokemonInstance mon) async {
    if (!mounted) return;
    setState(() {
      _trainerHeldBallType = 'poke_ball';
      _showTrainerSprite = true;
      _trainerPose = 0;
      _trainerSlideX = 0.0;
      _showPlayerPokemon = false;
      _playerSummonScale = 0.05;
      _showSummonBallArc = false;
      _showSummonBurst = false;
    });

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Wind-up pose
    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 210));
    if (!mounted) return;

    // Throw follow-through pose held briefly in view, then Trainer steps aside as Poké Ball arcs
    setState(() {
      _trainerPose = 2;
      _showSummonBallArc = true;
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() {
      _trainerSlideX = -1.2;
    });
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    // Ball opens with summon burst & Pokémon pops onto the platform
    HapticFeedback.mediumImpact();
    setState(() {
      _showSummonBallArc = false;
      _showTrainerSprite = false;
      _showSummonBurst = true;
      _showPlayerPokemon = true;
      _playerSummonScale = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    setState(() {
      _showSummonBurst = false;
    });
  }

  Future<void> _performPokemonSwitch(
    PokemonInstance nextMon, {
    required bool forced,
  }) async {
    if (!mounted) return;
    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
    });

    if (!forced) {
      setState(() {
        _currentMessage = "Come back, ${_playerPokemon.nickname}!";
        _playerFlash = true;
        _playerSummonScale = 0.05;
        _showPlayerPokemon = false;
      });
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
      });
    } else {
      setState(() {
        _showPlayerPokemon = false;
        _playerSummonScale = 0.05;
      });
    }

    _playerKoController.reset();
    setState(() {
      _visualPlayerFainted = false;
      _playerPokemon = nextMon;
      _displayedPlayerHp = nextMon.currentHp;
      _currentMessage = "${_trainer.name}: Go! ${nextMon.nickname}!";
    });

    await _animateTrainerSummonThrow(nextMon);
    if (!mounted) return;

    if (!forced && _opponentPokemon.moves.isNotEmpty) {
      await Future.delayed(const Duration(milliseconds: 320));
      if (!mounted) return;
      final oppMove =
          _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)];
      final events = BattleEngine.executeSingleAttack(
        _opponentPokemon,
        oppMove,
        _playerPokemon,
        isPlayer: false,
        isWild: widget.isWild,
      );
      for (final ev in events) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
      await _checkPostTurnConditions();
    } else {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  Future<void> _playStepEvent(BattleStepEvent event) async {
    if (!mounted) return;
    setState(() {
      _currentMessage = event.message;
    });

    // Dedicated Knock-Out animation when a Pokémon faints AFTER the hit completes
    if (event.targetFainted && event.moveType == null && !event.isStatusTick) {
      HapticFeedback.heavyImpact();
      final bool oppFainted = event.isPlayerActor;
      setState(() {
        _floatingCallout = "KNOCKED OUT!";
        _calloutOnOpponent = oppFainted;
        _calloutColor = Colors.redAccent;
        if (oppFainted) {
          _visualOpponentFainted = true;
        } else {
          _visualPlayerFainted = true;
        }
      });
      if (oppFainted) {
        await _opponentKoController.forward(from: 0.0);
      } else {
        await _playerKoController.forward(from: 0.0);
      }
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _floatingCallout = null;
      });
      return;
    }

    // Status tick (Burn / Poison)
    if (event.isStatusTick) {
      final hurtPlayer = !event.isPlayerActor;
      setState(() {
        _activeMoveId =
            event.moveType == PokemonType.fire ? 'status_burn' : 'status_poison';
        _activeVfxType = event.moveType;
        _vfxAttackerIsPlayer = hurtPlayer;
        _vfxTargetIsSelf = true;
        _floatingCallout = "-${event.damageDealt}";
        _calloutOnOpponent = !hurtPlayer;
        _calloutColor = event.moveType?.color ?? Colors.purpleAccent;
        if (hurtPlayer) {
          _playerFlash = true;
          _displayedPlayerHp = event.targetHpAfter;
        } else {
          _opponentFlash = true;
          _displayedOpponentHp = event.targetHpAfter;
        }
      });
      _vfxController.forward(from: 0);
      if (hurtPlayer) {
        _playerShakeController.forward(from: 0);
      } else {
        _opponentShakeController.forward(from: 0);
      }
      await Future.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
        _opponentFlash = false;
      });
      await Future.delayed(const Duration(milliseconds: 620));
      if (!mounted) return;
      setState(() {
        _activeMoveId = null;
        _activeVfxType = null;
        _floatingCallout = null;
      });
      return;
    }

    // Standard attack / stat / status move
    if (event.moveType != null && !event.isMiss) {
      final isPlayer = event.isPlayerActor;
      final isSelfBuff = event.statChangedLabel != null && event.statTargetIsSelf;

      // 1. Lunge forward (unless self-buff)
      if (!isSelfBuff) {
        setState(() {
          if (isPlayer) {
            _playerLungeOffset = const Offset(0.16, -0.08);
          } else {
            _opponentLungeOffset = const Offset(-0.16, 0.08);
          }
        });
        await Future.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;
      }

      // 2. Trigger full-arena move-specific VFX
      setState(() {
        _playerLungeOffset = Offset.zero;
        _opponentLungeOffset = Offset.zero;
        _activeMoveId = event.moveId ?? event.moveType!.name;
        _activeVfxType = event.moveType;
        _vfxAttackerIsPlayer = isPlayer;
        _vfxTargetIsSelf = isSelfBuff;
      });
      _vfxController.forward(from: 0);

      // Pause briefly so projectile/beam reaches target before hit flash
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      // 3. Impact flash, shake, floating callout & HP animation
      final bool calloutOnOpp = isSelfBuff ? !isPlayer : isPlayer;
      if (event.damageDealt > 0 ||
          event.statChangedLabel != null ||
          event.statusInflictedLabel != null) {
        String? callout;
        Color calloutCol = Colors.white;
        if (event.effectiveness >= 2.0) {
          callout = "SUPER EFFECTIVE! -${event.damageDealt}";
          calloutCol = Colors.amberAccent;
        } else if (event.isCrit) {
          callout = "CRITICAL HIT! -${event.damageDealt}";
          calloutCol = Colors.orangeAccent;
        } else if (event.damageDealt > 0) {
          callout = "-${event.damageDealt}";
          calloutCol = Colors.white;
        } else if (event.statChangedLabel != null) {
          callout = event.statChangedLabel;
          calloutCol = isSelfBuff ? Colors.cyanAccent : Colors.orangeAccent;
        } else if (event.statusInflictedLabel != null) {
          callout = event.statusInflictedLabel;
          calloutCol = event.moveType?.color ?? Colors.purpleAccent;
        }

        if (event.damageDealt > 0) {
          HapticFeedback.mediumImpact();
          setState(() {
            if (isPlayer) {
              _opponentFlash = true;
              _displayedOpponentHp = event.targetHpAfter;
            } else {
              _playerFlash = true;
              _displayedPlayerHp = event.targetHpAfter;
            }
            _floatingCallout = callout;
            _calloutOnOpponent = calloutOnOpp;
            _calloutColor = calloutCol;
          });

          if (isPlayer) {
            _opponentShakeController.forward(from: 0);
          } else {
            _playerShakeController.forward(from: 0);
          }
          if (event.isCrit || event.effectiveness >= 2.0) {
            _arenaShakeController.forward(from: 0);
          }
        } else {
          setState(() {
            _floatingCallout = callout;
            _calloutOnOpponent = calloutOnOpp;
            _calloutColor = calloutCol;
          });
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
        _opponentFlash = false;
      });
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() {
        _activeMoveId = null;
        _activeVfxType = null;
        _floatingCallout = null;
      });
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
    }
  }

  Future<void> _onMoveSelected(Move move) async {
    if (_isProcessingTurn || _battleEnded) return;
    if (move.currentPp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${move.name} has no PP left!")),
      );
      return;
    }

    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
    });

    final opponentMove = _opponentPokemon.moves.isNotEmpty
        ? _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)]
        : null;

    final events = BattleEngine.resolveTurn(
      playerMon: _playerPokemon,
      playerAction: BattleAction.fight(move),
      opponentMon: _opponentPokemon,
      opponentAction:
          opponentMove != null ? BattleAction.fight(opponentMove) : BattleAction.run(),
      isWild: widget.isWild,
    );

    for (final event in events) {
      await _playStepEvent(event);
      if (!mounted) return;
    }

    await _checkPostTurnConditions();
  }

  Future<void> _checkPostTurnConditions() async {
    if (!mounted) return;
    if (_opponentPokemon.isFainted) {
      final int expGained = PokemonInstance.calculateBattleExp(
        defeated: _opponentPokemon,
        winnerLevel: _playerPokemon.level,
        isTrainerBattle: !widget.isWild,
      );
      final levelResult = _playerPokemon.gainExpWithLearnset(
        expGained,
        PokedexDatabase.movesUnlockedAtExactLevel,
      );
      _trainer.saveProgress();

      setState(() {
        _currentMessage = "${_playerPokemon.nickname} gained $expGained EXP!";
      });
      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;

      if (levelResult.leveledUp) {
        setState(() {
          _displayedPlayerHp = _playerPokemon.currentHp;
          _currentMessage = "${_playerPokemon.nickname} grew to Level ${_playerPokemon.level}!";
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;

        for (final moveName in levelResult.learnedMoves) {
          setState(() {
            _currentMessage = "${_playerPokemon.nickname} learned $moveName!";
          });
          await Future.delayed(const Duration(milliseconds: 950));
          if (!mounted) return;
        }

        if (_playerPokemon.checkCanEvolve()) {
          final nextId = _playerPokemon.species.evolutionSpeciesId!;
          final nextSpecies = PokedexDatabase.species[nextId];
          if (nextSpecies != null) {
            setState(() {
              _showEvolutionGlow = true;
              _currentMessage = "What? ${_playerPokemon.nickname} is evolving!";
            });
            await Future.delayed(const Duration(milliseconds: 1200));
            if (!mounted) return;

            final oldName = _playerPokemon.nickname;
            final evoMoves = _playerPokemon.evolve(
              nextSpecies,
              PokedexDatabase.movesUnlockedAtExactLevel(
                nextSpecies,
                _playerPokemon.level,
              ),
            );
            _trainer.markPokemonCaught(nextSpecies.id);
            _trainer.saveProgress();
            HapticFeedback.heavyImpact();
            setState(() {
              _showEvolutionGlow = false;
              _displayedPlayerHp = _playerPokemon.currentHp;
              _currentMessage =
                  "Congratulations! $oldName evolved into ${nextSpecies.name}!";
            });
            await Future.delayed(const Duration(milliseconds: 1200));
            if (!mounted) return;

            for (final moveName in evoMoves) {
              setState(() {
                _currentMessage = "${_playerPokemon.nickname} learned $moveName!";
              });
              await Future.delayed(const Duration(milliseconds: 950));
              if (!mounted) return;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else if (_playerPokemon.isFainted) {
      if (_trainer.hasConsciousPokemon) {
        setState(() {
          _isProcessingTurn = false;
          _currentMessage = "${_playerPokemon.nickname} fainted! Choose another Pokémon!";
        });
        _openSwitchModal(forced: true);
      } else {
        setState(() {
          _currentMessage =
              "${_playerPokemon.nickname} fainted! Your party is resting at the Pokémon Center...";
          _battleEnded = true;
          _isProcessingTurn = false;
        });
      }
    } else {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  Future<void> _onThrowPokeBall(String ballType) async {
    if (!widget.isWild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't catch another Trainer's Pokémon!")),
      );
      return;
    }

    if (ballType == 'poke_ball' && _trainer.pokeBalls <= 0) return;
    if (ballType == 'great_ball' && _trainer.greatBalls <= 0) return;
    if (ballType == 'ultra_ball' && _trainer.ultraBalls <= 0) return;

    setState(() {
      if (ballType == 'poke_ball') _trainer.pokeBalls--;
      if (ballType == 'great_ball') _trainer.greatBalls--;
      if (ballType == 'ultra_ball') _trainer.ultraBalls--;
      _trainer.saveProgress();
      _throwingBallType = ballType;
      _trainerHeldBallType = ballType;
      _isSelectingMove = false;
      _isProcessingTurn = true;
      _showPlayerPokemon = false;
      _playerSummonScale = 0.05;
      _showTrainerSprite = true;
      _trainerPose = 0;
      _trainerSlideX = 0.0;
      _currentMessage =
          "${_trainer.name} threw a ${ballType.replaceAll('_', ' ').toUpperCase()}!";
    });

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 210));
    if (!mounted) return;

    setState(() {
      _trainerPose = 2;
      _showPokeBallThrow = true;
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() {
      _trainerSlideX = -1.2;
    });
    await Future.delayed(const Duration(milliseconds: 370));
    if (!mounted) return;

    setState(() {
      _showTrainerSprite = false;
      _opponentFlash = true;
      _opponentInBall = true;
    });
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() {
      _opponentFlash = false;
    });

    for (int i = 0; i < 3; i++) {
      _ballWobbleController.forward(from: 0);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
    }

    final bool caught = BattleEngine.attemptCapture(
      target: _opponentPokemon,
      ballType: ballType,
    );

    if (caught) {
      _trainer.addPokemon(_opponentPokemon);
      HapticFeedback.heavyImpact();
      setState(() {
        _currentMessage = "Gotcha! ${_opponentPokemon.species.name} was caught!";
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else {
      setState(() {
        _opponentInBall = false;
        _showPokeBallThrow = false;
        _showTrainerSprite = false;
        _showPlayerPokemon = true;
        _playerSummonScale = 1.0;
        _currentMessage = "Oh no! The wild ${_opponentPokemon.species.name} broke free!";
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      if (_opponentPokemon.moves.isNotEmpty) {
        final oppMove =
            _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)];
        final events = BattleEngine.executeSingleAttack(
          _opponentPokemon,
          oppMove,
          _playerPokemon,
          isPlayer: false,
          isWild: widget.isWild,
        );
        for (final ev in events) {
          await _playStepEvent(ev);
          if (!mounted) return;
        }
      }

      await _checkPostTurnConditions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_didHealOnExit) {
          _didHealOnExit = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _trainer.healAndResetAllParty();
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E24),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _finishAndExit,
          ),
          title: Text(
            widget.isWild ? "WILD ENCOUNTER" : "RIVAL FIST-BUMP DUEL",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ─── ARENA / COMBATANTS VIEW ─────────────────────────────────
              Expanded(
                flex: 5,
                child: AnimatedBuilder(
                  animation: _arenaShakeController,
                  builder: (context, child) {
                    final shakeOffset = sin(_arenaShakeController.value * pi * 6) *
                        6.0 *
                        (1 - _arenaShakeController.value);
                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: child,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final arenaW = constraints.maxWidth;
                        final arenaH = constraints.maxHeight;

                        // Dynamic species + perspective sizes & platform anchors mapped from battle_bg_route.png
                        final double oppSize = _opponentPokemon.species.battleOpponentSize;
                        final double playerSize = _playerPokemon.species.battlePlayerSize;

                        final oppPlatform = _mapBgPoint(693, 406, arenaW, arenaH);
                        final playerPlatform = _mapBgPoint(284, 606, arenaW, arenaH);

                        final oppSpriteCenter = oppPlatform + Offset(0, -oppSize * 0.45);
                        final playerSpriteCenter = playerPlatform + Offset(0, -playerSize * 0.45);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Generated Pixel-Art Kanto Route Battle Background
                            Image.asset(
                              'assets/images/battle_bg_route.png',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.none,
                            ),

                            // Thunderbolt dark storm tint overlay
                            if (_activeMoveId == 'thunderbolt')
                              AnimatedBuilder(
                                animation: _vfxController,
                                builder: (context, _) {
                                  final flash = sin(_vfxController.value * pi);
                                  return Container(
                                    color: Colors.black.withOpacity(0.42 * flash),
                                  );
                                },
                              ),

                            // Opponent Info Card (Top-Left)
                            Positioned(
                              top: 10,
                              left: 10,
                              child: _buildPokemonInfoCard(
                                _opponentPokemon,
                                displayedHp: _displayedOpponentHp,
                                isPlayer: false,
                              ),
                            ),

                            // Opponent Animated Sprite (Centered & bottom-anchored on distant top-right platform)
                            Positioned(
                              left: oppPlatform.dx - 75,
                              top: oppPlatform.dy - 140,
                              child: SizedBox(
                                width: 150,
                                height: 140,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (!_opponentInBall)
                                      _buildAnimatedCombatant(
                                        url: _opponentPokemon.species.spriteUrl,
                                        fallbackUrl:
                                            _opponentPokemon.species.staticSpriteUrl,
                                        size: oppSize,
                                        isFainted: _visualOpponentFainted,
                                        lungeOffset: _opponentLungeOffset,
                                        shakeController: _opponentShakeController,
                                        koController: _opponentKoController,
                                        flashWhite: _opponentFlash,
                                        isPlayer: false,
                                      ),
                                    AnimatedBuilder(
                                      animation: _opponentKoController,
                                      builder: (context, _) {
                                        if (!_visualOpponentFainted ||
                                            _opponentKoController.value >= 1.0) {
                                          return const SizedBox.shrink();
                                        }
                                        return CustomPaint(
                                          size: const Size(150, 140),
                                          painter: _KoBurstPainter(
                                            progress: _opponentKoController.value,
                                          ),
                                        );
                                      },
                                    ),
                                    if (_floatingCallout != null && _calloutOnOpponent)
                                      _buildCalloutBanner(
                                        _floatingCallout!,
                                        _calloutColor,
                                        bottom: oppSize + 6,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Player Platform Area: Trainer Throw Sprite & Player Pokémon
                            Positioned(
                              left: playerPlatform.dx - 110,
                              top: playerPlatform.dy - 210,
                              child: SizedBox(
                                width: 220,
                                height: 210,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Generated Pixel-Art Trainer Sprite throwing a Poké Ball
                                    if (_showTrainerSprite)
                                      AnimatedSlide(
                                        offset: Offset(_trainerSlideX, 0),
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeInOutCubic,
                                        child: AnimatedOpacity(
                                          opacity: _showTrainerSprite ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 220),
                                          child: TrainerSpriteWidget(
                                            avatar: _trainer.avatar,
                                            isBackView: true,
                                            pose: _trainerPose,
                                            ballColor:
                                                _ballTopColor(_trainerHeldBallType),
                                            size: 192,
                                          ),
                                        ),
                                      ),

                                    // Player's summoned Pokémon
                                    AnimatedOpacity(
                                      opacity: _showPlayerPokemon ? 1.0 : 0.0,
                                      duration: const Duration(milliseconds: 220),
                                      child: AnimatedScale(
                                        scale:
                                            _showPlayerPokemon ? _playerSummonScale : 0.05,
                                        duration: const Duration(milliseconds: 280),
                                        curve: Curves.easeOutBack,
                                        child: _buildAnimatedCombatant(
                                          url: _playerPokemon.species.backSpriteUrl,
                                          fallbackUrl:
                                              _playerPokemon.species.staticBackSpriteUrl,
                                          size: playerSize,
                                          isFainted: _visualPlayerFainted,
                                          lungeOffset: _playerLungeOffset,
                                          shakeController: _playerShakeController,
                                          koController: _playerKoController,
                                          flashWhite:
                                              _playerFlash || _showEvolutionGlow,
                                          isPlayer: true,
                                        ),
                                      ),
                                    ),

                                    AnimatedBuilder(
                                      animation: _playerKoController,
                                      builder: (context, _) {
                                        if (!_visualPlayerFainted ||
                                            _playerKoController.value >= 1.0) {
                                          return const SizedBox.shrink();
                                        }
                                        return CustomPaint(
                                          size: const Size(220, 210),
                                          painter: _KoBurstPainter(
                                            progress: _playerKoController.value,
                                          ),
                                        );
                                      },
                                    ),

                                    // Summon flash starburst when ball pops open
                                    if (_showSummonBurst)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.0, end: 1.0),
                                        duration: const Duration(milliseconds: 280),
                                        builder: (context, t, _) {
                                          return CustomPaint(
                                            size: const Size(165, 165),
                                            painter: _SummonBurstPainter(progress: t),
                                          );
                                        },
                                      ),

                                    if (_floatingCallout != null && !_calloutOnOpponent)
                                      _buildCalloutBanner(
                                        _floatingCallout!,
                                        _calloutColor,
                                        bottom: playerSize + 6,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            // Full-Arena Move-Specific Attack VFX Overlay
                            if (_activeMoveId != null && _activeVfxType != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _vfxController,
                                    builder: (context, _) {
                                      final atkCenter = _vfxAttackerIsPlayer
                                          ? playerSpriteCenter
                                          : oppSpriteCenter;
                                      final defCenter = _vfxTargetIsSelf
                                          ? atkCenter
                                          : (_vfxAttackerIsPlayer
                                              ? oppSpriteCenter
                                              : playerSpriteCenter);
                                      return CustomPaint(
                                        painter: _MoveVfxPainter(
                                          moveId: _activeMoveId!,
                                          moveType: _activeVfxType!,
                                          attackerCenter: atkCenter,
                                          defenderCenter: defCenter,
                                          progress: _vfxController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                            // Summon Poké Ball arc (Trainer hand -> Player platform)
                            if (_showSummonBallArc)
                              _buildArcingBallOverlay(
                                start: playerPlatform + const Offset(36, -116),
                                end: playerPlatform + const Offset(0, -14),
                                arcHeight: 48,
                                durationMs: 400,
                                ballType: 'poke_ball',
                                wobble: false,
                              ),

                            // Catching Poké Ball throw (Trainer hand -> Wild Pokémon)
                            if (_showPokeBallThrow)
                              _buildArcingBallOverlay(
                                start: playerPlatform + const Offset(38, -118),
                                end: oppPlatform + Offset(0, -oppSize * 0.35),
                                arcHeight: 72,
                                durationMs: 520,
                                ballType: _throwingBallType,
                                wobble: true,
                              ),

                            // Player Info Card (Bottom-Right)
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: _buildPokemonInfoCard(
                                _playerPokemon,
                                displayedHp: _displayedPlayerHp,
                                isPlayer: true,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ─── BATTLE LOG BOX ──────────────────────────────────────────
              Container(
                height: 68,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12, width: 1.5),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _currentMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _battleEnded
                      ? Center(
                          child: ElevatedButton.icon(
                            onPressed: _finishAndExit,
                            icon: const Icon(Icons.favorite, color: Colors.white),
                            label: const Text("FINISH & RESTORE PARTY"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        )
                      : (_isSelectingMove
                          ? _buildMoveSelection()
                          : _buildMainActionMenu()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _ballTopColor(String ballType) {
    if (ballType == 'ultra_ball') return Colors.amber.shade700;
    if (ballType == 'great_ball') return Colors.blue.shade600;
    return Colors.red.shade600;
  }

  Widget _buildArcingBallOverlay({
    required Offset start,
    required Offset end,
    required double arcHeight,
    required int durationMs,
    required String ballType,
    required bool wobble,
  }) {
    final topColor = _ballTopColor(ballType);

    final ballWidget = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topColor, topColor, Colors.white, Colors.white],
          stops: const [0.0, 0.48, 0.52, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: durationMs),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final x = start.dx + (end.dx - start.dx) * t;
        final y = start.dy + (end.dy - start.dy) * t - sin(t * pi) * arcHeight;
        final spinAngle = (1.0 - t) * pi * 4;

        return Positioned(
          left: x - 16,
          top: y - 16,
          child: wobble
              ? AnimatedBuilder(
                  animation: _ballWobbleController,
                  builder: (context, inner) {
                    final wobbleAngle = sin(_ballWobbleController.value * pi * 2) *
                        0.38 *
                        (1 - _ballWobbleController.value);
                    return Transform.rotate(
                      angle: t < 1.0 ? spinAngle : wobbleAngle,
                      child: inner,
                    );
                  },
                  child: child,
                )
              : Transform.rotate(angle: spinAngle, child: child),
        );
      },
      child: ballWidget,
    );
  }

  Widget _buildAnimatedCombatant({
    required String url,
    required String fallbackUrl,
    required double size,
    required bool isFainted,
    required Offset lungeOffset,
    required AnimationController shakeController,
    required AnimationController koController,
    required bool flashWhite,
    required bool isPlayer,
  }) {
    final spriteImage = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none,
      errorBuilder: (ctx, err, stack) => Image.network(
        fallbackUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.none,
        errorBuilder: (c, e, s) => Icon(
          Icons.catching_pokemon,
          size: (size * 0.65).clamp(24.0, 80.0),
          color: Colors.white,
        ),
      ),
    );

    final animatedSprite = AnimatedBuilder(
      animation: Listenable.merge([_idleController, shakeController, koController]),
      builder: (context, child) {
        final double bobY =
            isFainted ? 0.0 : -sin(_idleController.value * pi) * (isPlayer ? 2.5 : 3.5);
        final double hitShakeX = sin(shakeController.value * pi * 6) *
            8.0 *
            (1 - shakeController.value);

        final double koT =
            isFainted ? (koController.isAnimating ? koController.value : 1.0) : 0.0;
        final double koShakeX = koT > 0 && koT < 0.30
            ? sin(koT * pi * 14) * 7.0 * (1.0 - koT / 0.30)
            : 0.0;
        final double sinkT = koT > 0.18
            ? Curves.easeInBack.transform(((koT - 0.18) / 0.82).clamp(0.0, 1.0))
            : 0.0;
        final double koSinkY = sinkT * (size * 0.85);
        final double koScaleY = (1.0 - 0.35 * sinkT).clamp(0.55, 1.2);
        final double koTilt = -0.18 * sinkT;
        final double koOpacity = koT > 0
            ? (1.0 - ((koT - 0.35) / 0.65).clamp(0.0, 1.0)).clamp(0.0, 1.0)
            : 1.0;
        final bool koStrobeRed = koT > 0 && koT < 0.25 && (koT * 20).floor().isEven;

        return Opacity(
          opacity: koOpacity,
          child: Transform.translate(
            offset: Offset(hitShakeX + koShakeX, bobY + koSinkY),
            child: Transform.rotate(
              angle: koTilt,
              alignment: Alignment.bottomCenter,
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1.0, koScaleY, 1.0),
                child: ColorFiltered(
                  colorFilter: koStrobeRed
                      ? ColorFilter.mode(
                          Colors.redAccent.withOpacity(0.55),
                          BlendMode.srcATop,
                        )
                      : (flashWhite
                          ? const ColorFilter.mode(Colors.white70, BlendMode.srcATop)
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: spriteImage,
    );

    return AnimatedSlide(
      offset: lungeOffset,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: isFainted ? ClipRect(child: animatedSprite) : animatedSprite,
    );
  }

  Widget _buildCalloutBanner(
    String text,
    Color color, {
    required double bottom,
  }) {
    return Positioned(
      bottom: bottom,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.85), width: 1.2),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPokemonInfoCard(
    PokemonInstance mon, {
    required int displayedHp,
    required bool isPlayer,
  }) {
    final stageBadges = <Widget>[];
    final statsMap = {
      'ATK': mon.atkStage,
      'DEF': mon.defStage,
      'SPA': mon.spaStage,
      'SPD': mon.spdStage,
      'SPE': mon.speStage,
    };
    statsMap.forEach((label, val) {
      if (val != 0) {
        final isBuff = val > 0;
        stageBadges.add(Container(
          margin: const EdgeInsets.only(right: 4, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: isBuff ? Colors.teal.shade700 : Colors.deepOrange.shade700,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            "$label ${isBuff ? '+$val' : '$val'}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ));
      }
    });

    final int prevLvlExp = (mon.level - 1) * (mon.level - 1) * (mon.level - 1);
    final int nextLvlExp = mon.expForNextLevel;
    final double expProgress = nextLvlExp > prevLvlExp
        ? ((mon.currentExp - prevLvlExp) / (nextLvlExp - prevLvlExp)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 170,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFF23232E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  mon.nickname,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mon.status != StatusCondition.none)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _statusColor(mon.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mon.status.shortLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    "Lv.${mon.level}",
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          HpBar(currentHp: displayedHp, maxHp: mon.maxHp),
          if (isPlayer) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: expProgress,
                minHeight: 3,
                backgroundColor: Colors.black38,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
              ),
            ),
          ],
          if (stageBadges.isNotEmpty) Wrap(children: stageBadges),
        ],
      ),
    );
  }

  Color _statusColor(StatusCondition status) {
    switch (status) {
      case StatusCondition.burn:
        return Colors.deepOrange;
      case StatusCondition.poison:
        return Colors.purple;
      case StatusCondition.paralysis:
        return Colors.amber.shade700;
      case StatusCondition.sleep:
        return Colors.blueGrey;
      case StatusCondition.freeze:
        return Colors.cyan;
      case StatusCondition.none:
        return Colors.transparent;
    }
  }

  Widget _buildMainActionMenu() {
    return GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 2.35,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildActionButton("FIGHT", Colors.red.shade700, Icons.flash_on, () {
          setState(() => _isSelectingMove = true);
        }),
        _buildActionButton("BAG", Colors.amber.shade800, Icons.backpack, _openBagModal),
        _buildActionButton(
            "POKÉMON", Colors.green.shade700, Icons.catching_pokemon, () => _openSwitchModal()),
        _buildActionButton("RUN", Colors.blueGrey.shade700, Icons.directions_run, _finishAndExit),
      ],
    );
  }

  Widget _buildMoveSelection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "SELECT A MOVE",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white60),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _isSelectingMove = false),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.25,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _playerPokemon.moves.length,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (ctx, idx) {
              final move = _playerPokemon.moves[idx];
              return ElevatedButton(
                onPressed: _isProcessingTurn ? null : () => _onMoveSelected(move),
                style: ElevatedButton.styleFrom(
                  backgroundColor: move.type.color.withOpacity(0.9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      move.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          move.type.displayName.toUpperCase(),
                          style: const TextStyle(fontSize: 9, color: Colors.white70),
                        ),
                        Text(
                          "PP ${move.currentPp}/${move.maxPp}",
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                        ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "TRAINER BAG",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (widget.isWild) ...[
                _bagRow(
                  icon: Icons.catching_pokemon,
                  iconColor: Colors.redAccent,
                  title: "Poké Ball",
                  subtitle: "x${_trainer.pokeBalls} remaining",
                  btnLabel: "THROW",
                  btnColor: Colors.redAccent,
                  enabled: _trainer.pokeBalls > 0,
                  onTap: () {
                    Navigator.pop(ctx);
                    _onThrowPokeBall('poke_ball');
                  },
                ),
                _bagRow(
                  icon: Icons.catching_pokemon,
                  iconColor: Colors.blueAccent,
                  title: "Great Ball (1.5x)",
                  subtitle: "x${_trainer.greatBalls} remaining",
                  btnLabel: "THROW",
                  btnColor: Colors.blueAccent,
                  enabled: _trainer.greatBalls > 0,
                  onTap: () {
                    Navigator.pop(ctx);
                    _onThrowPokeBall('great_ball');
                  },
                ),
                _bagRow(
                  icon: Icons.catching_pokemon,
                  iconColor: Colors.amberAccent,
                  title: "Ultra Ball (2.0x)",
                  subtitle: "x${_trainer.ultraBalls} remaining",
                  btnLabel: "THROW",
                  btnColor: Colors.amber.shade800,
                  enabled: _trainer.ultraBalls > 0,
                  onTap: () {
                    Navigator.pop(ctx);
                    _onThrowPokeBall('ultra_ball');
                  },
                ),
              ],
              _bagRow(
                icon: Icons.medical_services,
                iconColor: Colors.greenAccent,
                title: "Potion",
                subtitle: "x${_trainer.potions} remaining (+20 HP)",
                btnLabel: "USE",
                btnColor: Colors.green,
                enabled: _trainer.potions > 0 && _playerPokemon.currentHp < _playerPokemon.maxHp,
                onTap: () async {
                  _trainer.usePotion();
                  _playerPokemon.currentHp =
                      (_playerPokemon.currentHp + 20).clamp(0, _playerPokemon.maxHp);
                  Navigator.pop(ctx);
                  setState(() {
                    _isProcessingTurn = true;
                    _displayedPlayerHp = _playerPokemon.currentHp;
                    _currentMessage =
                        "${_trainer.name} used a Potion! ${_playerPokemon.nickname} healed 20 HP.";
                  });
                  await Future.delayed(const Duration(milliseconds: 900));
                  if (!mounted) return;
                  if (_opponentPokemon.moves.isNotEmpty) {
                    final oppMove = _opponentPokemon
                        .moves[Random().nextInt(_opponentPokemon.moves.length)];
                    final events = BattleEngine.executeSingleAttack(
                      _opponentPokemon,
                      oppMove,
                      _playerPokemon,
                      isPlayer: false,
                      isWild: widget.isWild,
                    );
                    for (final ev in events) {
                      await _playStepEvent(ev);
                      if (!mounted) return;
                    }
                  }
                  await _checkPostTurnConditions();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bagRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String btnLabel,
    required Color btnColor,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor, size: 28),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(backgroundColor: btnColor, foregroundColor: Colors.white),
        child: Text(btnLabel),
      ),
    );
  }

  void _openSwitchModal({bool forced = false}) {
    showModalBottomSheet(
      context: context,
      isDismissible: !forced,
      enableDrag: !forced,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "SWITCH POKÉMON",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ..._trainer.party.map((mon) {
                final isCurrent = mon == _playerPokemon;
                return ListTile(
                  leading: Image.network(
                    mon.species.spriteUrl,
                    width: 44,
                    height: 44,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (c, e, s) =>
                        const Icon(Icons.catching_pokemon, color: Colors.white),
                  ),
                  title: Text(
                    mon.nickname,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "Lv.${mon.level} • HP ${mon.currentHp}/${mon.maxHp}",
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: isCurrent
                      ? const Text(
                          "ACTIVE",
                          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                        )
                      : ElevatedButton(
                          onPressed: mon.isFainted
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  _performPokemonSwitch(mon, forced: forced);
                                },
                          child: const Text("SWITCH"),
                        ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
      String title, Color color, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isProcessingTurn ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    );
  }
}

class _SummonBurstPainter extends CustomPainter {
  final double progress;

  _SummonBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    canvas.drawCircle(
      center,
      14 + progress * 46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * opacity
        ..color = Colors.cyanAccent.withOpacity(opacity),
    );
    canvas.drawCircle(
      center,
      26 * (1 - progress * 0.4),
      Paint()..color = Colors.white.withOpacity(opacity * 0.85),
    );
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * pi * 2;
      final p1 = center +
          Offset(cos(angle) * (10 + progress * 20), sin(angle) * (10 + progress * 20));
      final p2 = center +
          Offset(cos(angle) * (24 + progress * 38), sin(angle) * (24 + progress * 38));
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = Colors.white.withOpacity(opacity)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SummonBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _KoBurstPainter extends CustomPainter {
  final double progress;

  _KoBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final baseCenter = Offset(size.width / 2, size.height - 8);
    final baseW = size.width;

    // 1. Twin expanding elliptical shockwave rings across the platform base
    if (t < 0.55) {
      final ringT = (t / 0.55).clamp(0.0, 1.0);
      final ringOp = (1.0 - ringT).clamp(0.0, 1.0);
      final rx = baseW * (0.16 + ringT * 0.34);
      final ry = rx * 0.34;
      canvas.drawOval(
        Rect.fromCenter(center: baseCenter, width: rx * 2, height: ry * 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * ringOp
          ..color = Colors.white.withOpacity(ringOp * 0.9),
      );
      if (ringT > 0.15) {
        final r2 = ((ringT - 0.15) / 0.85).clamp(0.0, 1.0);
        final rx2 = baseW * (0.12 + r2 * 0.28);
        canvas.drawOval(
          Rect.fromCenter(center: baseCenter, width: rx2 * 2, height: rx2 * 0.68),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * (1.0 - r2)
            ..color = Colors.redAccent.withOpacity((1.0 - r2) * 0.85),
        );
      }
    }

    // 2. Billowing dust/smoke puffs outward from platform as Pokémon collapses
    if (t > 0.12 && t < 0.92) {
      final dustT = ((t - 0.12) / 0.80).clamp(0.0, 1.0);
      final dustOp = ((1.0 - dustT) * 0.72).clamp(0.0, 1.0);
      for (int i = 0; i < 8; i++) {
        final side = i.isEven ? 1.0 : -1.0;
        final lane = (i ~/ 2) / 3.0;
        final spreadX = side * baseW * (0.08 + lane * 0.18 + dustT * 0.24);
        final liftY = -8.0 - dustT * (18.0 + lane * 14.0);
        final puffPos = baseCenter + Offset(spreadX, liftY);
        final puffR = (size.width * 0.055) * (0.7 + dustT * 0.75);
        canvas.drawCircle(
          puffPos,
          puffR,
          Paint()
            ..color = (i % 3 == 0 ? Colors.white70 : const Color(0xFFE0E0E0))
                .withOpacity(dustOp),
        );
      }
    }

    // 3. Six rising KO star bursts above the defeated Pokémon
    if (t > 0.20) {
      final starT = ((t - 0.20) / 0.80).clamp(0.0, 1.0);
      final starOp = ((1.0 - starT) * 0.95).clamp(0.0, 1.0);
      for (int i = 0; i < 6; i++) {
        final angle = -pi * 0.85 + (i / 5.0) * pi * 0.70;
        final radius = baseW * (0.14 + starT * 0.26);
        final starPos = baseCenter +
            Offset(cos(angle) * radius * 1.15, sin(angle) * radius * 0.9 - 18.0 - starT * 26.0);
        final r = (4.5 + (i % 2) * 2.0) * (1.0 - starT * 0.35);
        final starPath = Path()
          ..moveTo(starPos.dx, starPos.dy - r)
          ..lineTo(starPos.dx + r * 0.32, starPos.dy - r * 0.32)
          ..lineTo(starPos.dx + r, starPos.dy)
          ..lineTo(starPos.dx + r * 0.32, starPos.dy + r * 0.32)
          ..lineTo(starPos.dx, starPos.dy + r)
          ..lineTo(starPos.dx - r * 0.32, starPos.dy + r * 0.32)
          ..lineTo(starPos.dx - r, starPos.dy)
          ..lineTo(starPos.dx - r * 0.32, starPos.dy - r * 0.32)
          ..close();
        canvas.drawPath(
          starPath,
          Paint()
            ..color = (i.isEven ? Colors.amberAccent : Colors.white)
                .withOpacity(starOp),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KoBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MoveVfxPainter extends CustomPainter {
  final String moveId;
  final PokemonType moveType;
  final Offset attackerCenter;
  final Offset defenderCenter;
  final double progress;

  _MoveVfxPainter({
    required this.moveId,
    required this.moveType,
    required this.attackerCenter,
    required this.defenderCenter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final fade = (1.0 - max(0.0, (t - 0.72) / 0.28)).clamp(0.0, 1.0);
    final dir = defenderCenter - attackerCenter;
    final dist = max(1.0, dir.distance);
    final unit = dir / dist;
    final perp = Offset(-unit.dy, unit.dx);

    switch (moveId) {
      // ─── FIRE MOVES ─────────────────────────────────────────────────────
      case 'ember':
        for (int i = 0; i < 5; i++) {
          final lt = ((t - i * 0.09) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final arc = sin(lt * pi) * (28 + i * 6) * (i.isEven ? 1 : -1);
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * arc;
          canvas.drawCircle(pos, 10 * (1 - lt * 0.3) * fade,
              Paint()..color = Colors.deepOrange.withOpacity(0.9 * fade));
          canvas.drawCircle(pos, 5.5 * fade,
              Paint()..color = Colors.yellowAccent.withOpacity(fade));
        }
        break;

      case 'fire_fang':
        _drawJaws(canvas, defenderCenter, t, fade, Colors.deepOrangeAccent, Colors.yellowAccent);
        break;

      case 'flamethrower':
        for (int i = 0; i < 12; i++) {
          final lt = ((t - i * 0.045) / 0.45).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final wiggle = sin(lt * 14 + i) * 10;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * wiggle;
          final radius = (7 + lt * 14) * fade;
          canvas.drawCircle(
              pos,
              radius,
              Paint()
                ..color = (i % 3 == 0 ? Colors.yellowAccent : Colors.deepOrangeAccent)
                    .withOpacity(0.85 * fade));
        }
        break;

      case 'fire_blast':
        if (t < 0.45) {
          final lt = t / 0.45;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          canvas.drawCircle(pos, 22, Paint()..color = Colors.deepOrangeAccent);
          canvas.drawCircle(pos, 12, Paint()..color = Colors.yellowAccent);
        } else {
          // 5-pointed Daimonji 大 fire star on defender
          final st = (t - 0.45) / 0.55;
          final starRadius = 22 + st * 42;
          final p = Paint()
            ..color = Colors.deepOrange.withOpacity(fade)
            ..strokeWidth = 10 * fade
            ..strokeCap = StrokeCap.round;
          final pInner = Paint()
            ..color = Colors.yellowAccent.withOpacity(fade)
            ..strokeWidth = 5 * fade
            ..strokeCap = StrokeCap.round;
          final angles = [-pi / 2, -0.35, -pi + 0.35, 0.85, pi - 0.85];
          for (final a in angles) {
            final end = defenderCenter + Offset(cos(a) * starRadius, sin(a) * starRadius);
            canvas.drawLine(defenderCenter, end, p);
            canvas.drawLine(defenderCenter, end, pInner);
          }
          canvas.drawCircle(defenderCenter, 16 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
        }
        break;

      // ─── WATER MOVES ────────────────────────────────────────────────────
      case 'water_gun':
        final reach = min(1.0, t / 0.65);
        final endPt = Offset.lerp(attackerCenter, defenderCenter, reach)!;
        canvas.drawLine(
          attackerCenter,
          endPt,
          Paint()
            ..color = Colors.lightBlueAccent.withOpacity(0.9 * fade)
            ..strokeWidth = 10 * fade
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          attackerCenter,
          endPt,
          Paint()
            ..color = Colors.white.withOpacity(0.8 * fade)
            ..strokeWidth = 4 * fade
            ..strokeCap = StrokeCap.round,
        );
        if (t > 0.45) {
          final sp = (t - 0.45) / 0.55;
          for (int i = 0; i < 6; i++) {
            final ang = (i / 6) * pi * 2;
            canvas.drawCircle(
                defenderCenter + Offset(cos(ang) * sp * 36, sin(ang) * sp * 36),
                5 * fade,
                Paint()..color = Colors.cyanAccent.withOpacity(fade));
          }
        }
        break;

      case 'water_pulse':
        for (int i = 0; i < 4; i++) {
          final lt = ((t - i * 0.12) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          canvas.drawCircle(
            pos,
            10 + lt * 18,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * fade
              ..color = Colors.cyanAccent.withOpacity(fade),
          );
        }
        break;

      case 'surf':
        // Cresting tidal wave sweeping across the arena
        final waveX = size.width * (-0.2 + t * 1.4);
        final waveRect = Rect.fromLTWH(waveX - 70, size.height * 0.25, 140, size.height * 0.72);
        final wavePath = Path()
          ..moveTo(waveRect.left, waveRect.bottom)
          ..quadraticBezierTo(
              waveRect.center.dx - 20, waveRect.top, waveRect.right, waveRect.top + 30)
          ..quadraticBezierTo(
              waveRect.right + 16, waveRect.center.dy, waveRect.right, waveRect.bottom)
          ..close();
        canvas.drawPath(
          wavePath,
          Paint()..color = const Color(0xFF1E88E5).withOpacity(0.68 * fade),
        );
        canvas.drawPath(
          wavePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = Colors.white.withOpacity(0.85 * fade),
        );
        break;

      case 'hydro_pump':
        final reach = min(1.0, t / 0.55);
        final endPt = Offset.lerp(attackerCenter, defenderCenter, reach)!;
        for (final sign in [-1.0, 1.0]) {
          final off = perp * (6 * sign);
          canvas.drawLine(
            attackerCenter + off,
            endPt + off,
            Paint()
              ..color = Colors.blue.shade600.withOpacity(0.95 * fade)
              ..strokeWidth = 11 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter + off,
            endPt + off,
            Paint()
              ..color = Colors.white.withOpacity(0.9 * fade)
              ..strokeWidth = 4.5 * fade
              ..strokeCap = StrokeCap.round,
          );
        }
        if (t > 0.4) {
          canvas.drawCircle(defenderCenter, 18 + (t - 0.4) * 45,
              Paint()..color = Colors.lightBlueAccent.withOpacity(0.55 * fade));
        }
        break;

      // ─── GRASS MOVES ────────────────────────────────────────────────────
      case 'vine_whip':
        final reach = min(1.0, t / 0.65);
        for (final sign in [-1.0, 1.0]) {
          final ctrl = Offset.lerp(attackerCenter, defenderCenter, 0.5)! +
              perp * (42 * sign * sin(t * pi * 2));
          final endPt = Offset.lerp(attackerCenter, defenderCenter, reach)!;
          final path = Path()
            ..moveTo(attackerCenter.dx, attackerCenter.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, endPt.dx, endPt.dy);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 * fade
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF2E7D32).withOpacity(fade),
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.lightGreenAccent.withOpacity(fade),
          );
        }
        break;

      case 'razor_leaf':
        for (int i = 0; i < 8; i++) {
          final lt = ((t - i * 0.06) / 0.52).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final spread = (i - 3.5) * 9.0;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * spread;
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(lt * 10 + i);
          canvas.drawOval(
            const Rect.fromLTWH(-11, -4, 22, 8),
            Paint()..color = Colors.lightGreenAccent.withOpacity(fade),
          );
          canvas.restore();
        }
        break;

      case 'solar_beam':
        if (t < 0.35) {
          // Gathering sunlight on attacker
          final gt = t / 0.35;
          canvas.drawCircle(
            attackerCenter,
            34 * (1 - gt * 0.4),
            Paint()..color = Colors.yellowAccent.withOpacity(0.75 * gt),
          );
        } else {
          // Blazing solar beam
          final bt = (t - 0.35) / 0.65;
          final endPt = Offset.lerp(attackerCenter, defenderCenter, min(1.0, bt * 2.5))!;
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.lightGreenAccent.withOpacity(0.85 * fade)
              ..strokeWidth = 22 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.white.withOpacity(0.95 * fade)
              ..strokeWidth = 10 * fade
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'sleep_powder':
      case 'poison_powder':
        final isSleep = moveId == 'sleep_powder';
        final sporeColor = isSleep ? Colors.tealAccent : Colors.purpleAccent;
        for (int i = 0; i < 12; i++) {
          final ang = (i / 12) * pi * 2 + t * 2;
          final r = 10 + sin(t * pi) * 32;
          final pos = defenderCenter + Offset(cos(ang) * r, sin(ang) * r - t * 18);
          canvas.drawCircle(pos, 6, Paint()..color = sporeColor.withOpacity(0.8 * fade));
        }
        if (isSleep) {
          final tp = TextPainter(
            text: TextSpan(
              text: 'Zzz',
              style: TextStyle(
                color: Colors.white.withOpacity(fade),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, defenderCenter + Offset(-12, -32 - t * 20));
        }
        break;

      // ─── ELECTRIC MOVES ─────────────────────────────────────────────────
      case 'thunder_shock':
        _drawLightningBolt(canvas, attackerCenter, defenderCenter, fade, 3.5);
        break;

      case 'electro_ball':
        final pos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t / 0.75))!;
        canvas.drawCircle(pos, 16 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
        canvas.drawCircle(
          pos,
          22 * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.amber.withOpacity(fade),
        );
        break;

      case 'thunderbolt':
        for (int b = -1; b <= 1; b++) {
          final topPt = Offset(defenderCenter.dx + b * 18.0, 0);
          _drawLightningBolt(canvas, topPt, defenderCenter + Offset(b * 6.0, 0), fade, 5.0);
        }
        canvas.drawOval(
          Rect.fromCenter(center: defenderCenter + const Offset(0, 26), width: 90 * t, height: 26 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5
            ..color = Colors.yellowAccent.withOpacity(fade),
        );
        break;

      case 'thunder_wave':
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            defenderCenter,
            16 + i * 13 + t * 16,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.yellowAccent.withOpacity(fade),
          );
        }
        break;

      // ─── PHYSICAL / NORMAL / DARK MOVES ─────────────────────────────────
      case 'scratch':
        for (int i = -1; i <= 1; i++) {
          final off = Offset(i * 11.0, i * 6.0);
          final p1 = defenderCenter + const Offset(-26, -24) + off;
          final p2 = defenderCenter + const Offset(26, 24) + off;
          canvas.drawLine(
            p1,
            Offset.lerp(p1, p2, min(1.0, t * 1.8))!,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = 4.5
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'slash':
        final lt = min(1.0, t * 1.6);
        canvas.drawLine(
          defenderCenter + const Offset(-32, -30),
          Offset.lerp(defenderCenter + const Offset(-32, -30),
              defenderCenter + const Offset(32, 30), lt)!,
          Paint()
            ..color = Colors.white.withOpacity(fade)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          defenderCenter + const Offset(32, -30),
          Offset.lerp(defenderCenter + const Offset(32, -30),
              defenderCenter + const Offset(-32, 30), lt)!,
          Paint()
            ..color = Colors.cyanAccent.withOpacity(fade)
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
        break;

      case 'quick_attack':
        for (int i = 0; i < 4; i++) {
          final lt = ((t - i * 0.08) / 0.5).clamp(0.0, 1.0);
          final p1 = Offset.lerp(attackerCenter, defenderCenter, max(0.0, lt - 0.35))!;
          final p2 = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          canvas.drawLine(
            p1 + perp * ((i - 1.5) * 10),
            p2 + perp * ((i - 1.5) * 10),
            Paint()
              ..color = Colors.white.withOpacity(0.9 * fade)
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'bite':
      case 'crunch':
      case 'hyper_fang':
        final jawCol = moveId == 'crunch'
            ? Colors.deepPurpleAccent
            : (moveId == 'hyper_fang' ? Colors.amberAccent : Colors.white);
        _drawJaws(canvas, defenderCenter, t, fade, jawCol, Colors.white);
        break;

      case 'tackle':
        canvas.drawCircle(
          defenderCenter,
          16 + t * 38,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * fade
            ..color = Colors.white.withOpacity(fade),
        );
        for (int i = 0; i < 6; i++) {
          final ang = (i / 6) * pi * 2;
          canvas.drawLine(
            defenderCenter + Offset(cos(ang) * 12, sin(ang) * 12),
            defenderCenter + Offset(cos(ang) * (18 + t * 36), sin(ang) * (18 + t * 36)),
            Paint()
              ..color = Colors.amberAccent.withOpacity(fade)
              ..strokeWidth = 3.5
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      // ─── FLYING / BUG / POISON / PSYCHIC ────────────────────────────────
      case 'gust':
      case 'silver_wind':
        final col = moveId == 'silver_wind' ? Colors.white : Colors.lightBlue.shade100;
        for (int i = 0; i < 5; i++) {
          final yOff = 24 - i * 14.0;
          final w = 22 + i * 11.0;
          canvas.drawOval(
            Rect.fromCenter(
              center: defenderCenter + Offset(sin(t * 14 + i) * 10, yOff),
              width: w,
              height: 12,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = col.withOpacity(0.85 * fade),
          );
        }
        break;

      case 'wing_attack':
      case 'air_slash':
        for (int i = 0; i < 3; i++) {
          final lt = ((t - i * 0.12) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          canvas.drawArc(
            Rect.fromCenter(center: pos, width: 46, height: 32),
            -0.8,
            1.6,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round
              ..color = Colors.cyanAccent.withOpacity(fade),
          );
        }
        break;

      case 'string_shot':
        for (int i = -2; i <= 2; i++) {
          final endPt = Offset.lerp(attackerCenter, defenderCenter + Offset(i * 8.0, i * 5.0), min(1.0, t * 1.6))!;
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.white.withOpacity(0.9 * fade)
              ..strokeWidth = 2.5,
          );
        }
        break;

      case 'bug_bite':
        _drawJaws(canvas, defenderCenter, t, fade, Colors.lightGreenAccent, Colors.white);
        break;

      case 'poison_sting':
      case 'twinneedle':
        final count = moveId == 'twinneedle' ? 2 : 1;
        for (int i = 0; i < count; i++) {
          final lt = min(1.0, t * 1.7);
          final off = count == 2 ? perp * ((i == 0 ? -1 : 1) * 9.0) : Offset.zero;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + off;
          canvas.drawLine(
            pos - unit * 18,
            pos + unit * 10,
            Paint()
              ..color = Colors.purpleAccent.withOpacity(fade)
              ..strokeWidth = 5
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'poison_jab':
      case 'sludge_bomb':
      case 'status_poison':
        for (int i = 0; i < 7; i++) {
          final lt = ((t - i * 0.06) / 0.6).clamp(0.0, 1.0);
          final base = moveId == 'sludge_bomb'
              ? Offset.lerp(attackerCenter, defenderCenter, lt)! + Offset(0, -sin(lt * pi) * 45)
              : defenderCenter + Offset(cos(i * 1.1) * t * 34, sin(i * 1.1) * t * 34);
          canvas.drawCircle(base, 9 * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
        }
        break;

      case 'confusion':
      case 'psybeam':
        if (moveId == 'psybeam') {
          final colors = [Colors.pinkAccent, Colors.cyanAccent, Colors.yellowAccent, Colors.purpleAccent];
          final reach = min(1.0, t / 0.65);
          for (int i = 0; i < colors.length; i++) {
            final off = perp * ((i - 1.5) * 4.5);
            canvas.drawLine(
              attackerCenter + off,
              Offset.lerp(attackerCenter, defenderCenter, reach)! + off,
              Paint()
                ..color = colors[i].withOpacity(0.9 * fade)
                ..strokeWidth = 4
                ..strokeCap = StrokeCap.round,
            );
          }
        } else {
          for (int i = 0; i < 3; i++) {
            canvas.drawCircle(
              defenderCenter,
              (12 + i * 12) + t * 18,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5
                ..color = Colors.pinkAccent.withOpacity(fade),
            );
          }
        }
        break;

      // ─── STAT BUFFS & DEBUFFS ───────────────────────────────────────────
      case 'growl':
      case 'tail_whip':
        for (int i = 0; i < 3; i++) {
          final lt = ((t - i * 0.14) / 0.65).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          canvas.drawCircle(
            pos,
            10 + lt * 22,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white.withOpacity(fade),
          );
        }
        break;

      case 'swords_dance':
        for (int i = 0; i < 4; i++) {
          final ang = (i / 4) * pi * 2 + t * pi * 3;
          final pos = attackerCenter + Offset(cos(ang) * 34, sin(ang) * 14 - t * 24);
          canvas.drawLine(
            pos + const Offset(0, -14),
            pos + const Offset(0, 10),
            Paint()
              ..color = Colors.cyanAccent.withOpacity(fade)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            pos + const Offset(-6, 4),
            pos + const Offset(6, 4),
            Paint()
              ..color = Colors.amberAccent.withOpacity(fade)
              ..strokeWidth = 3,
          );
        }
        break;

      case 'harden':
      case 'agility':
        final col = moveId == 'harden' ? Colors.blueGrey.shade200 : Colors.cyanAccent;
        for (int i = 0; i < 4; i++) {
          final yOff = (t - i * 0.15) * -36;
          canvas.drawOval(
            Rect.fromCenter(center: attackerCenter + Offset(0, yOff), width: 72, height: 22),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = col.withOpacity(fade),
          );
        }
        break;

      // ─── NEW KANTO MOVES (FLYING, FIGHTING, GROUND, ROCK, FAIRY, GRASS, PSYCHIC) ─
      case 'peck':
      case 'drill_peck':
        final spins = moveId == 'drill_peck' ? 4 : 1;
        for (int i = 0; i < spins; i++) {
          final lt = ((t - i * 0.1) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final stabPos = attackerCenter + unit * (lt * dist * 0.92);
          canvas.drawLine(
            stabPos - unit * 16,
            stabPos + unit * 14,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = moveId == 'drill_peck' ? 6 : 4
              ..strokeCap = StrokeCap.round,
          );
        }
        if (t > 0.35) {
          canvas.drawCircle(
            defenderCenter,
            14 + (t - 0.35) * 28,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 * fade
              ..color = Colors.cyanAccent.withOpacity(fade),
          );
        }
        break;

      case 'double_kick':
        for (int kick = 0; kick < 2; kick++) {
          final lt = ((t - kick * 0.32) / 0.45).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final hitPos = defenderCenter + Offset(kick == 0 ? -12 : 12, kick == 0 ? 6 : -8);
          canvas.drawCircle(
            hitPos,
            10 + lt * 20,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * fade
              ..color = Colors.deepOrangeAccent.withOpacity(fade),
          );
          canvas.drawCircle(hitPos, 8 * (1 - lt * 0.4), Paint()..color = Colors.white.withOpacity(fade));
        }
        break;

      case 'mud_slap':
      case 'acid':
        final globColor = moveId == 'mud_slap' ? const Color(0xFF9C7A4C) : Colors.lightGreenAccent;
        for (int i = 0; i < 6; i++) {
          final lt = ((t - i * 0.06) / 0.6).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final spread = perp * ((i - 2.5) * 9.0 * lt);
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + spread;
          canvas.drawCircle(pos, (6 + i % 3 * 2.0) * fade, Paint()..color = globColor.withOpacity(fade));
        }
        break;

      case 'dig':
        if (t < 0.45) {
          final r = (t / 0.45) * 32;
          canvas.drawOval(
            Rect.fromCenter(center: attackerCenter + const Offset(0, 18), width: r * 2, height: r * 0.7),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5
              ..color = const Color(0xFF9C7A4C).withOpacity(fade),
          );
        } else {
          final pop = (t - 0.45) / 0.55;
          canvas.drawLine(
            defenderCenter + const Offset(0, 32),
            defenderCenter + Offset(0, 32 - pop * 64),
            Paint()
              ..color = const Color(0xFFD7A86E).withOpacity(fade)
              ..strokeWidth = 14
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'earthquake':
        for (int i = 0; i < 3; i++) {
          final lt = ((t - i * 0.14) / 0.65).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          canvas.drawOval(
            Rect.fromCenter(
              center: defenderCenter + const Offset(0, 18),
              width: 36 + lt * 130,
              height: 14 + lt * 46,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.5 * fade
              ..color = const Color(0xFFE0C068).withOpacity(fade),
          );
        }
        break;

      case 'rock_throw':
      case 'rock_slide':
        final boulderCount = moveId == 'rock_slide' ? 5 : 2;
        for (int i = 0; i < boulderCount; i++) {
          final lt = ((t - i * 0.08) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final xOff = (i - (boulderCount - 1) / 2.0) * 18.0;
          final startY = defenderCenter.dy - 120;
          final curY = startY + (defenderCenter.dy - startY) * lt;
          canvas.drawCircle(
            Offset(defenderCenter.dx + xOff, curY),
            moveId == 'rock_slide' ? 12 : 14,
            Paint()..color = const Color(0xFF8D7B68).withOpacity(fade),
          );
        }
        break;

      case 'power_gem':
        final reach = min(1.0, t / 0.65);
        final beamEnd = Offset.lerp(attackerCenter, defenderCenter, reach)!;
        canvas.drawLine(
          attackerCenter,
          beamEnd,
          Paint()
            ..color = Colors.amberAccent.withOpacity(0.95 * fade)
            ..strokeWidth = 7 * fade
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(beamEnd, 10 * fade, Paint()..color = Colors.white.withOpacity(fade));
        break;

      case 'sing':
      case 'disarming_voice':
        final ringCol = moveId == 'sing' ? Colors.pinkAccent : Colors.pink.shade200;
        for (int i = 0; i < 4; i++) {
          final lt = ((t - i * 0.14) / 0.65).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
              perp * (sin(lt * pi * 3 + i) * 12);
          canvas.drawCircle(
            pos,
            7 + i * 2.0,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.8 * fade
              ..color = ringCol.withOpacity(fade),
          );
        }
        break;

      case 'body_slam':
        final slamScale = 1.0 + sin(t * pi) * 0.8;
        canvas.drawOval(
          Rect.fromCenter(center: defenderCenter, width: 42 * slamScale, height: 22 * slamScale),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * fade
            ..color = Colors.white.withOpacity(fade),
        );
        break;

      case 'swift':
        for (int i = 0; i < 5; i++) {
          final lt = ((t - i * 0.08) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
              perp * (sin(lt * pi) * ((i - 2) * 14.0));
          canvas.drawCircle(pos, 7 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
          canvas.drawCircle(pos, 3.5 * fade, Paint()..color = Colors.white.withOpacity(fade));
        }
        break;

      case 'splash':
        for (int i = 0; i < 6; i++) {
          final ang = -pi * (i / 5.0);
          final hopPos = attackerCenter +
              Offset(cos(ang) * t * 34, sin(ang) * t * 28 + t * t * 24);
          canvas.drawCircle(hopPos, 5 * fade, Paint()..color = Colors.lightBlueAccent.withOpacity(fade));
        }
        break;

      case 'moonblast':
        final orbPos = Offset.lerp(
            defenderCenter + const Offset(0, -110), defenderCenter, min(1.0, t / 0.7))!;
        canvas.drawCircle(orbPos, 24 * fade, Paint()..color = Colors.pinkAccent.withOpacity(0.55 * fade));
        canvas.drawCircle(orbPos, 14 * fade, Paint()..color = Colors.white.withOpacity(0.9 * fade));
        break;

      case 'glare':
        for (final sign in [-1.0, 1.0]) {
          canvas.drawCircle(
            attackerCenter + Offset(sign * 8, -10),
            6 + t * 8,
            Paint()..color = Colors.redAccent.withOpacity(fade),
          );
        }
        canvas.drawCircle(
          defenderCenter,
          14 + t * 22,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * fade
            ..color = Colors.yellowAccent.withOpacity(fade),
        );
        break;

      case 'aqua_tail':
        canvas.drawArc(
          Rect.fromCenter(center: defenderCenter, width: 72, height: 54),
          -pi * 0.8 + t * 2.2,
          pi * 1.1,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10 * fade
            ..strokeCap = StrokeCap.round
            ..color = Colors.lightBlueAccent.withOpacity(fade),
        );
        break;

      case 'absorb':
        for (int i = 0; i < 6; i++) {
          final lt = ((t - i * 0.08) / 0.6).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(defenderCenter, attackerCenter, lt)! +
              perp * (sin(lt * pi * 2 + i) * 12);
          canvas.drawCircle(pos, 6 * fade, Paint()..color = Colors.lightGreenAccent.withOpacity(fade));
        }
        break;

      case 'petal_blizzard':
        for (int i = 0; i < 10; i++) {
          final lt = ((t - i * 0.05) / 0.6).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
              perp * (sin(lt * 10 + i * 1.3) * 24);
          canvas.drawOval(
            Rect.fromCenter(center: pos, width: 10, height: 6),
            Paint()..color = (i.isEven ? Colors.pinkAccent : Colors.lightGreenAccent).withOpacity(fade),
          );
        }
        break;

      case 'psychic':
        for (int i = 0; i < 4; i++) {
          final waveR = 14.0 + i * 10.0 + sin(t * pi * 3) * 8.0;
          canvas.drawCircle(
            defenderCenter,
            waveR,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 * fade
              ..color = (i.isEven ? Colors.purpleAccent : Colors.pinkAccent).withOpacity(fade),
          );
        }
        break;

      default:
        canvas.drawCircle(
          defenderCenter,
          16 + t * 34,
          Paint()..color = moveType.color.withOpacity(0.6 * fade),
        );
        break;
    }
  }

  void _drawLightningBolt(
      Canvas canvas, Offset start, Offset end, double fade, double strokeW) {
    final p1 = Offset.lerp(start, end, 0.33)! + const Offset(14, 0);
    final p2 = Offset.lerp(start, end, 0.66)! + const Offset(-14, 0);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.yellowAccent.withOpacity(fade)
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawJaws(Canvas canvas, Offset center, double t, double fade,
      Color toothColor, Color flashColor) {
    final snap = (1.0 - sin(min(1.0, t * 1.5) * pi * 0.5)) * 22.0;
    final paint = Paint()..color = toothColor.withOpacity(fade);
    for (int i = -1; i <= 1; i++) {
      final dx = i * 14.0;
      // Top teeth
      final topTooth = Path()
        ..moveTo(center.dx + dx - 6, center.dy - 14 - snap)
        ..lineTo(center.dx + dx + 6, center.dy - 14 - snap)
        ..lineTo(center.dx + dx, center.dy - 2 - snap)
        ..close();
      canvas.drawPath(topTooth, paint);
      // Bottom teeth
      final botTooth = Path()
        ..moveTo(center.dx + dx - 6, center.dy + 14 + snap)
        ..lineTo(center.dx + dx + 6, center.dy + 14 + snap)
        ..lineTo(center.dx + dx, center.dy + 2 + snap)
        ..close();
      canvas.drawPath(botTooth, paint);
    }
    if (t > 0.45) {
      canvas.drawCircle(center, 18 * fade, Paint()..color = flashColor.withOpacity(0.35 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _MoveVfxPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.moveId != moveId ||
      oldDelegate.attackerCenter != attackerCenter ||
      oldDelegate.defenderCenter != defenderCenter;
}
