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
  late AnimationController _arenaShakeController;
  late AnimationController _vfxController;
  late AnimationController _ballWobbleController;

  Offset _playerLungeOffset = Offset.zero;
  Offset _opponentLungeOffset = Offset.zero;
  bool _playerFlash = false;
  bool _opponentFlash = false;
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

  // Active VFX overlay state
  PokemonType? _activeVfxType;
  bool _vfxOnOpponent = true;
  bool _vfxIsStat = false;
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

    _arenaShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _ballWobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _playBattleIntroSummon();
    });
  }

  @override
  void dispose() {
    _idleController.dispose();
    _playerShakeController.dispose();
    _opponentShakeController.dispose();
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

    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;

    // Wind-up pose
    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Throw pose + Trainer steps aside + Poké Ball arcs onto player platform
    setState(() {
      _trainerPose = 2;
      _trainerSlideX = -1.25;
      _showSummonBallArc = true;
    });
    await Future.delayed(const Duration(milliseconds: 380));
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

    setState(() {
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

    // Status tick (Burn / Poison)
    if (event.isStatusTick) {
      final hurtPlayer = !event.isPlayerActor;
      setState(() {
        _activeVfxType = event.moveType;
        _vfxOnOpponent = !hurtPlayer;
        _vfxIsStat = false;
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
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
        _opponentFlash = false;
      });
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() {
        _activeVfxType = null;
        _floatingCallout = null;
      });
      return;
    }

    // Standard attack / stat / status move
    if (event.moveType != null && !event.isMiss) {
      final isPlayer = event.isPlayerActor;

      // 1. Lunge forward
      setState(() {
        if (isPlayer) {
          _playerLungeOffset = const Offset(0.18, -0.10);
        } else {
          _opponentLungeOffset = const Offset(-0.18, 0.10);
        }
      });
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;

      // Return from lunge & trigger VFX
      final bool vfxTargetOpponent = event.statChangedLabel != null && event.statTargetIsSelf
          ? !isPlayer
          : isPlayer;

      setState(() {
        _playerLungeOffset = Offset.zero;
        _opponentLungeOffset = Offset.zero;
        _activeVfxType = event.moveType;
        _vfxOnOpponent = vfxTargetOpponent;
        _vfxIsStat = event.statChangedLabel != null;
      });
      _vfxController.forward(from: 0);

      // 2. Impact flash, shake, floating callout & HP animation
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
          calloutCol = event.statTargetIsSelf ? Colors.cyanAccent : Colors.orangeAccent;
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
            _calloutOnOpponent = vfxTargetOpponent;
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
            _calloutOnOpponent = vfxTargetOpponent;
            _calloutColor = calloutCol;
          });
        }
      }

      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
        _opponentFlash = false;
      });
      await Future.delayed(const Duration(milliseconds: 680));
      if (!mounted) return;
      setState(() {
        _activeVfxType = null;
        _floatingCallout = null;
      });
    } else {
      await Future.delayed(const Duration(milliseconds: 850));
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

        // Check for Evolution!
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

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    // Trainer wind-up
    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Trainer throws ball & steps back while ball arcs across the battlefield
    setState(() {
      _trainerPose = 2;
      _trainerSlideX = -1.25;
      _showPokeBallThrow = true;
    });
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;

    // Absorption red flash + hide wild Pokémon
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

    // Wobble 3 times on opponent platform
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

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Vibrant daytime route background
                            CustomPaint(painter: _ArenaBackdropPainter()),

                            // Opponent Info Card (Top-Left)
                            Positioned(
                              top: 12,
                              left: 12,
                              child: _buildPokemonInfoCard(
                                _opponentPokemon,
                                displayedHp: _displayedOpponentHp,
                                isPlayer: false,
                              ),
                            ),

                            // Opponent Animated Sprite (Top-Right)
                            Positioned(
                              top: 34,
                              right: 22,
                              child: SizedBox(
                                width: 125,
                                height: 125,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (!_opponentInBall)
                                      _buildAnimatedCombatant(
                                        url: _opponentPokemon.species.spriteUrl,
                                        fallbackUrl:
                                            _opponentPokemon.species.staticSpriteUrl,
                                        size: 112,
                                        isFainted: _opponentPokemon.isFainted,
                                        lungeOffset: _opponentLungeOffset,
                                        shakeController: _opponentShakeController,
                                        flashWhite: _opponentFlash,
                                        isPlayer: false,
                                      ),
                                    if (_activeVfxType != null && _vfxOnOpponent)
                                      _buildVfxWidget(_activeVfxType!, _vfxIsStat),
                                    if (_floatingCallout != null && _calloutOnOpponent)
                                      _buildCalloutBanner(
                                          _floatingCallout!, _calloutColor),
                                  ],
                                ),
                              ),
                            ),

                            // Player Platform Area: Trainer Throw Sprite & Player Pokémon (Bottom-Left)
                            Positioned(
                              bottom: 12,
                              left: 20,
                              child: SizedBox(
                                width: 140,
                                height: 140,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Trainer back-sprite throwing a Poké Ball
                                    if (_showTrainerSprite)
                                      AnimatedSlide(
                                        offset: Offset(_trainerSlideX, 0),
                                        duration: const Duration(milliseconds: 360),
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
                                            size: 125,
                                          ),
                                        ),
                                      ),

                                    // Player's summoned Pokémon
                                    AnimatedOpacity(
                                      opacity:
                                          (_showPlayerPokemon && !_playerPokemon.isFainted)
                                              ? 1.0
                                              : 0.0,
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
                                          size: 130,
                                          isFainted: _playerPokemon.isFainted,
                                          lungeOffset: _playerLungeOffset,
                                          shakeController: _playerShakeController,
                                          flashWhite:
                                              _playerFlash || _showEvolutionGlow,
                                          isPlayer: true,
                                        ),
                                      ),
                                    ),

                                    // Summon flash starburst when ball pops open
                                    if (_showSummonBurst)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.0, end: 1.0),
                                        duration: const Duration(milliseconds: 280),
                                        builder: (context, t, _) {
                                          return CustomPaint(
                                            size: const Size(130, 130),
                                            painter: _SummonBurstPainter(progress: t),
                                          );
                                        },
                                      ),

                                    if (_activeVfxType != null && !_vfxOnOpponent)
                                      _buildVfxWidget(_activeVfxType!, _vfxIsStat),
                                    if (_floatingCallout != null && !_calloutOnOpponent)
                                      _buildCalloutBanner(
                                          _floatingCallout!, _calloutColor),
                                  ],
                                ),
                              ),
                            ),

                            // Summon Poké Ball arc (Trainer hand -> Player platform)
                            if (_showSummonBallArc)
                              _buildArcingBallOverlay(
                                start: Offset(96, arenaH - 102),
                                end: Offset(90, arenaH - 36),
                                arcHeight: 46,
                                durationMs: 360,
                                ballType: 'poke_ball',
                                wobble: false,
                              ),

                            // Catching Poké Ball throw (Trainer hand -> Wild Pokémon)
                            if (_showPokeBallThrow)
                              _buildArcingBallOverlay(
                                start: Offset(104, arenaH - 104),
                                end: Offset(arenaW - 84, 114),
                                arcHeight: 68,
                                durationMs: 500,
                                ballType: _throwingBallType,
                                wobble: true,
                              ),

                            // Player Info Card (Bottom-Right)
                            Positioned(
                              bottom: 14,
                              right: 12,
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
    required bool flashWhite,
    required bool isPlayer,
  }) {
    return AnimatedSlide(
      offset: lungeOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isFainted ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 450),
        child: AnimatedBuilder(
          animation: Listenable.merge([_idleController, shakeController]),
          builder: (context, child) {
            final double bobY = sin(_idleController.value * pi) * (isPlayer ? 3.0 : 4.0);
            final double hitShakeX = sin(shakeController.value * pi * 6) *
                8.0 *
                (1 - shakeController.value);
            return Transform.translate(
              offset: Offset(hitShakeX, bobY + (isFainted ? 24.0 : 0.0)),
              child: child,
            );
          },
          child: ColorFiltered(
            colorFilter: flashWhite
                ? const ColorFilter.mode(Colors.white70, BlendMode.srcATop)
                : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
              errorBuilder: (ctx, err, stack) => Image.network(
                fallbackUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.catching_pokemon, size: 70, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVfxWidget(PokemonType type, bool isStat) {
    return AnimatedBuilder(
      animation: _vfxController,
      builder: (context, _) {
        final t = _vfxController.value;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final scale = 0.6 + (t * 0.9);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              size: const Size(110, 110),
              painter: _ElementalVfxPainter(
                type: type,
                progress: t,
                isStat: isStat,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalloutBanner(String text, Color color) {
    return Positioned(
      top: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.8), width: 1),
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
      width: 175,
      padding: const EdgeInsets.all(10),
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
                  backgroundColor: move.type.color.withOpacity(0.88),
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

class _ArenaBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Bright daytime route sky gradient
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.56);
    canvas.drawRect(
      skyRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4FA8FF),
            Color(0xFF8ED2FF),
            Color(0xFFCCF0FF),
          ],
          stops: [0.0, 0.58, 1.0],
        ).createShader(skyRect),
    );

    // 2. Soft drifting clouds
    final cloudPaint = Paint()..color = Colors.white.withOpacity(0.85);
    void drawCloud(double cx, double cy, double w) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: w * 0.42), cloudPaint);
      canvas.drawCircle(Offset(cx - w * 0.24, cy - w * 0.08), w * 0.18, cloudPaint);
      canvas.drawCircle(Offset(cx + w * 0.18, cy - w * 0.12), w * 0.22, cloudPaint);
    }
    drawCloud(size.width * 0.22, size.height * 0.14, 72);
    drawCloud(size.width * 0.72, size.height * 0.19, 86);

    // 3. Distant sunlit mountain silhouettes
    final mtnPath = Path()
      ..moveTo(0, size.height * 0.48)
      ..lineTo(size.width * 0.18, size.height * 0.30)
      ..lineTo(size.width * 0.38, size.height * 0.45)
      ..lineTo(size.width * 0.58, size.height * 0.27)
      ..lineTo(size.width * 0.80, size.height * 0.44)
      ..lineTo(size.width, size.height * 0.33)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(0, size.height * 0.55)
      ..close();
    canvas.drawPath(
      mtnPath,
      Paint()..color = const Color(0xFF7CA7C9).withOpacity(0.65),
    );

    // 4. Vibrant grassy ground floor
    final groundRect = Rect.fromLTWH(0, size.height * 0.48, size.width, size.height * 0.52);
    canvas.drawRect(
      groundRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF66BB6A),
            Color(0xFF43A047),
          ],
        ).createShader(groundRect),
    );

    // Light turf stripes for depth
    final stripePaint = Paint()..color = const Color(0xFF81C784).withOpacity(0.32);
    for (int i = 0; i < 4; i++) {
      final y = size.height * (0.56 + i * 0.11);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 10 + i * 3.0), stripePaint);
    }

    // 5. Lush forest treeline along the horizon
    final treeDark = Paint()..color = const Color(0xFF2E7D32);
    final treeLight = Paint()..color = const Color(0xFF388E3C);
    final horizonY = size.height * 0.48;
    for (double x = -10; x < size.width + 20; x += 28) {
      canvas.drawCircle(Offset(x, horizonY - 4), 20, treeDark);
      canvas.drawCircle(Offset(x + 14, horizonY - 9), 17, treeLight);
    }

    // 6. Stylized 3D grassy battle platforms
    void drawPlatform(Offset center, double w, double h) {
      final rect = Rect.fromCenter(center: center, width: w, height: h);
      // Drop shadow
      canvas.drawOval(
        rect.shift(const Offset(0, 8)),
        Paint()..color = Colors.black.withOpacity(0.24),
      );
      // Earthy rim (3D thickness)
      canvas.drawOval(
        rect.shift(const Offset(0, 4)),
        Paint()..color = const Color(0xFF6D4C41),
      );
      // Bright grass surface
      canvas.drawOval(
        rect,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFA5D6A7), Color(0xFF4CAF50)],
          ).createShader(rect),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = const Color(0xFFE8F5E9).withOpacity(0.65),
      );
    }

    drawPlatform(Offset(size.width - 84, 134), 148, 42);
    drawPlatform(Offset(90, size.height - 26), 172, 48);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      14 + progress * 44,
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
      final p1 = center + Offset(cos(angle) * (10 + progress * 20), sin(angle) * (10 + progress * 20));
      final p2 = center + Offset(cos(angle) * (24 + progress * 38), sin(angle) * (24 + progress * 38));
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

class _ElementalVfxPainter extends CustomPainter {
  final PokemonType type;
  final double progress;
  final bool isStat;

  _ElementalVfxPainter({
    required this.type,
    required this.progress,
    required this.isStat,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseColor = type.color;

    if (isStat) {
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = baseColor.withOpacity((1 - progress).clamp(0.0, 1.0));
      for (int i = 0; i < 3; i++) {
        final yOffset = (progress - i * 0.2) * -35;
        canvas.drawOval(
          Rect.fromCenter(center: center.translate(0, yOffset), width: 70, height: 22),
          ringPaint,
        );
      }
      return;
    }

    switch (type) {
      case PokemonType.fire:
        for (int i = 0; i < 8; i++) {
          final angle = (i / 8) * pi * 2 + progress * 1.2;
          final dist = 12 + progress * 38;
          final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
          canvas.drawCircle(
            pos,
            12 * (1 - progress * 0.5),
            Paint()..color = (i.isEven ? Colors.orangeAccent : Colors.yellowAccent),
          );
        }
        break;

      case PokemonType.water:
        final ripple = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = Colors.lightBlueAccent;
        canvas.drawCircle(center, 15 + progress * 35, ripple);
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * pi * 2;
          final pos =
              center + Offset(cos(angle) * (progress * 44), sin(angle) * (progress * 44));
          canvas.drawCircle(pos, 6, Paint()..color = Colors.cyanAccent);
        }
        break;

      case PokemonType.electric:
        final boltPaint = Paint()
          ..color = Colors.yellowAccent
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        final path = Path()
          ..moveTo(center.dx - 16, center.dy - 44)
          ..lineTo(center.dx + 8, center.dy - 10)
          ..lineTo(center.dx - 10, center.dy + 4)
          ..lineTo(center.dx + 18, center.dy + 42);
        canvas.drawPath(path, boltPaint);
        canvas.drawCircle(
            center, 18 * (1 - progress), Paint()..color = Colors.yellow.withOpacity(0.5));
        break;

      case PokemonType.grass:
        for (int i = 0; i < 6; i++) {
          final angle = (i / 6) * pi * 2 + progress * 4.0;
          final dist = 10 + progress * 36;
          final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
          canvas.save();
          canvas.translate(pos.dx, pos.dy);
          canvas.rotate(angle);
          canvas.drawOval(
            const Rect.fromLTWH(-10, -4, 20, 8),
            Paint()..color = Colors.lightGreenAccent,
          );
          canvas.restore();
        }
        break;

      case PokemonType.poison:
      case PokemonType.bug:
        for (int i = 0; i < 7; i++) {
          final angle = (i / 7) * pi * 2;
          final dist = 8 + progress * 34;
          final pos =
              center + Offset(cos(angle) * dist, sin(angle) * dist - progress * 12);
          canvas.drawCircle(pos, 8, Paint()..color = baseColor);
        }
        break;

      case PokemonType.psychic:
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            center,
            (14 + i * 12) + progress * 16,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.pinkAccent.withOpacity(0.85),
          );
        }
        break;

      default:
        final slashPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        final offset = -24 + progress * 48;
        canvas.drawLine(
          center + Offset(-26 + offset * 0.3, -26),
          center + Offset(26 + offset * 0.3, 26),
          slashPaint,
        );
        canvas.drawLine(
          center + Offset(-14 + offset * 0.3, -32),
          center + Offset(32 + offset * 0.3, 14),
          slashPaint..color = baseColor,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ElementalVfxPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.type != type;
}
