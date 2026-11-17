import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/battle_engine.dart';
import '../services/item_drop_service.dart';
import '../services/pokedex_database.dart';
import '../widgets/hp_bar.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/trainer_sprite.dart';

enum _BallAnimPhase {
  none,
  flight,
  absorb,
  bounce,
  wobble,
  locked,
  breakout,
}

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
  late AnimationController _ballPhaseController;

  Offset _playerLungeOffset = Offset.zero;
  Offset _opponentLungeOffset = Offset.zero;
  bool _playerFlash = false;
  bool _opponentFlash = false;
  bool _playerSubmerged = false;
  bool _opponentSubmerged = false;
  bool _visualPlayerFainted = false;
  bool _visualOpponentFainted = false;
  bool _opponentInBall = false;
  double _opponentCaptureScale = 1.0;
  bool _showPokeBallThrow = false;
  _BallAnimPhase _catchBallPhase = _BallAnimPhase.none;
  Color? _ballButtonGlowColor;
  bool _showCaptureLockBurst = false;
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
      duration: const Duration(milliseconds: 420),
    );

    _ballPhaseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
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
    _ballPhaseController.dispose();
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

    // Throw follow-through pose held briefly in view, then Trainer steps aside as Poké Ball arcs & bounces
    setState(() {
      _trainerPose = 2;
      _showSummonBallArc = true;
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() {
      _trainerSlideX = -1.2;
    });
    await Future.delayed(const Duration(milliseconds: 370));
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

  bool _isHeavyMove(String moveId) {
    const heavyMoves = {
      'earthquake',
      'rock_slide',
      'body_slam',
      'submission',
      'cross_chop',
      'crabhammer',
      'drill_peck',
      'aqua_tail',
      'fire_blast',
      'hydro_pump',
      'solar_beam',
      'thunderbolt',
    };
    return heavyMoves.contains(moveId);
  }

  Offset _lungeForMove(String moveId, bool isPlayer) {
    const highLeapMoves = {
      'body_slam',
      'submission',
      'double_kick',
      'crabhammer',
      'waterfall',
      'splash',
    };
    const rapidBlitzMoves = {
      'quick_attack',
      'drill_peck',
      'peck',
      'horn_attack',
      'slash',
      'x_scissor',
      'karate_chop',
      'cross_chop',
      'fury_swipes',
      'aqua_tail',
      'wing_attack',
      'poison_jab',
      'twinneedle',
      'tackle',
    };
    if (highLeapMoves.contains(moveId)) {
      return isPlayer ? const Offset(0.18, -0.26) : const Offset(-0.18, 0.22);
    }
    if (rapidBlitzMoves.contains(moveId)) {
      return isPlayer ? const Offset(0.26, -0.13) : const Offset(-0.26, 0.13);
    }
    return isPlayer ? const Offset(0.16, -0.08) : const Offset(-0.16, 0.08);
  }

    // Standard attack / stat / status move
    if (event.moveType != null && !event.isMiss) {
      final isPlayer = event.isPlayerActor;
      final isSelfBuff = event.statChangedLabel != null && event.statTargetIsSelf;
      final moveId = event.moveId ?? event.moveType!.name;
      final isDig = moveId == 'dig';

      // 1. Move-specific attacker choreography (submerge for Dig, lunge/leap otherwise)
      if (isDig) {
        setState(() {
          if (isPlayer) {
            _playerSubmerged = true;
          } else {
            _opponentSubmerged = true;
          }
        });
        await Future.delayed(const Duration(milliseconds: 180));
        if (!mounted) return;
      } else if (!isSelfBuff) {
        final lunge = _lungeForMove(moveId, isPlayer);
        setState(() {
          if (isPlayer) {
            _playerLungeOffset = lunge;
          } else {
            _opponentLungeOffset = lunge;
          }
        });
        await Future.delayed(const Duration(milliseconds: 140));
        if (!mounted) return;
      }

      // 2. Trigger full-arena move-specific VFX
      setState(() {
        _playerLungeOffset = Offset.zero;
        _opponentLungeOffset = Offset.zero;
        _activeMoveId = moveId;
        _activeVfxType = event.moveType;
        _vfxAttackerIsPlayer = isPlayer;
        _vfxTargetIsSelf = isSelfBuff;
      });
      _vfxController.forward(from: 0);

      // Pause briefly so projectile/beam/burrow reaches target before hit flash
      await Future.delayed(Duration(milliseconds: isDig ? 280 : 220));
      if (!mounted) return;

      if (isDig) {
        setState(() {
          _playerSubmerged = false;
          _opponentSubmerged = false;
        });
      }

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
          if (event.isCrit || event.effectiveness >= 2.0 || _isHeavyMove(moveId)) {
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
        _playerSubmerged = false;
        _opponentSubmerged = false;
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
          int nextId = _playerPokemon.species.evolutionSpeciesId!;
          if (_playerPokemon.species.id == 133) {
            const eeveelutions = [134, 135, 136];
            nextId = eeveelutions[Random().nextInt(eeveelutions.length)];
          }
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

      // Roll chance for Pokémon item drop based on its rarity
      final itemDrop = ItemDropService.rollDrop(_opponentPokemon.species);
      if (itemDrop != null) {
        _trainer.adjustItemCount(itemDrop.itemId, itemDrop.count);
        _trainer.saveProgress();
        setState(() {
          _currentMessage =
              "${_opponentPokemon.nickname} dropped ${itemDrop.count > 1 ? '${itemDrop.count}x ' : 'a '}${itemDrop.itemName}!";
        });
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
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
      _opponentInBall = false;
      _opponentCaptureScale = 1.0;
      _showCaptureLockBurst = false;
      _ballButtonGlowColor = null;
      _catchBallPhase = _BallAnimPhase.none;
      _currentMessage =
          "${_trainer.name} threw a ${ballType.replaceAll('_', ' ').toUpperCase()}!";
    });

    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;

    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;

    // Phase 1: Throw Flight Arc from Trainer hand to wild Pokémon
    setState(() {
      _trainerPose = 2;
      _showPokeBallThrow = true;
      _catchBallPhase = _BallAnimPhase.flight;
    });
    _ballPhaseController.duration = const Duration(milliseconds: 360);
    _ballPhaseController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() {
      _trainerSlideX = -1.2;
    });
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    // Phase 2: Open Capsule & Laser Absorption (wild Pokémon shrinks into beam)
    HapticFeedback.lightImpact();
    setState(() {
      _showTrainerSprite = false;
      _catchBallPhase = _BallAnimPhase.absorb;
      _opponentFlash = true;
      _opponentCaptureScale = 0.08;
    });
    _ballPhaseController.duration = const Duration(milliseconds: 360);
    _ballPhaseController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() {
      _opponentFlash = false;
    });
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    // Phase 3: Gravity Drop & Multi-Bounce on Opponent Platform
    setState(() {
      _opponentInBall = true;
      _catchBallPhase = _BallAnimPhase.bounce;
    });
    _ballPhaseController.duration = const Duration(milliseconds: 560);
    _ballPhaseController.forward(from: 0);

    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    // Phase 4: Bottom-Pivoted Ground Wobble Checks (3 checks)
    setState(() {
      _catchBallPhase = _BallAnimPhase.wobble;
    });
    for (int i = 0; i < 3; i++) {
      setState(() {
        _ballButtonGlowColor = Colors.redAccent;
      });
      _ballWobbleController.forward(from: 0);
      HapticFeedback.selectionClick();
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() {
        _ballButtonGlowColor = null;
      });
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
    }

    final bool caught = BattleEngine.attemptCapture(
      target: _opponentPokemon,
      ballType: ballType,
    );

    if (caught) {
      // Phase 5a: Capture Lock & Golden Stars
      _trainer.addPokemon(_opponentPokemon);
      final itemDrop = ItemDropService.rollDrop(_opponentPokemon.species);
      if (itemDrop != null) {
        _trainer.adjustItemCount(itemDrop.itemId, itemDrop.count);
        _trainer.saveProgress();
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _catchBallPhase = _BallAnimPhase.locked;
        _ballButtonGlowColor = Colors.amberAccent;
        _showCaptureLockBurst = true;
        _currentMessage = itemDrop != null
            ? "Gotcha! ${_opponentPokemon.species.name} was caught!\n${_opponentPokemon.species.name} dropped ${itemDrop.count > 1 ? '${itemDrop.count}x ' : 'a '}${itemDrop.itemName}!"
            : "Gotcha! ${_opponentPokemon.species.name} was caught!";
        _battleEnded = true;
        _isProcessingTurn = false;
      });
      _ballPhaseController.duration = const Duration(milliseconds: 520);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 520));
      if (!mounted) return;
      setState(() {
        _ballButtonGlowColor = null;
        _showCaptureLockBurst = false;
      });
    } else {
      // Phase 5b: Break-Free Open Capsule Burst
      setState(() {
        _catchBallPhase = _BallAnimPhase.breakout;
        _ballButtonGlowColor = null;
        _showCaptureLockBurst = false;
        _opponentInBall = false;
        _opponentFlash = true;
        _opponentCaptureScale = 0.12;
      });
      _ballPhaseController.duration = const Duration(milliseconds: 280);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return;
      setState(() {
        _opponentCaptureScale = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 190));
      if (!mounted) return;

      setState(() {
        _opponentFlash = false;
        _showPokeBallThrow = false;
        _catchBallPhase = _BallAnimPhase.none;
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

                            // Atmospheric Arena Tint Overlay for dramatic moves
                            if (const {
                              'thunderbolt',
                              'night_shade',
                              'shadow_ball',
                              'moonblast',
                              'hypnosis',
                              'glare',
                            }.contains(_activeMoveId))
                              AnimatedBuilder(
                                animation: _vfxController,
                                builder: (context, _) {
                                  final flash = sin(_vfxController.value * pi);
                                  final tint = _activeMoveId == 'moonblast'
                                      ? const Color(0xFF1A0E2E)
                                      : Colors.black;
                                  return Container(
                                    color: tint.withOpacity(0.46 * flash),
                                  );
                                },
                              )
                            else if (const {
                              'solar_beam',
                              'fire_blast',
                              'psychic',
                              'ice_beam',
                              'aurora_beam',
                              'power_gem',
                            }.contains(_activeMoveId))
                              AnimatedBuilder(
                                animation: _vfxController,
                                builder: (context, _) {
                                  final flash = sin(_vfxController.value * pi);
                                  return Container(
                                    color: (_activeVfxType?.color ?? Colors.white)
                                        .withOpacity(0.18 * flash),
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
                                    AnimatedOpacity(
                                      opacity: _opponentInBall ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 110),
                                      child: AnimatedScale(
                                        scale: _opponentCaptureScale,
                                        duration: const Duration(milliseconds: 220),
                                        curve: Curves.easeInOutCubic,
                                        alignment: Alignment.bottomCenter,
                                        child: _buildAnimatedCombatant(
                                          url: _opponentPokemon.species.spriteUrl,
                                          fallbackUrl: _opponentPokemon
                                              .species.staticSpriteUrl,
                                          size: oppSize,
                                          isFainted: _visualOpponentFainted,
                                          isSubmerged: _opponentSubmerged,
                                          lungeOffset: _opponentLungeOffset,
                                          shakeController: _opponentShakeController,
                                          koController: _opponentKoController,
                                          flashWhite: _opponentFlash,
                                          isPlayer: false,
                                        ),
                                      ),
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
                                          isSubmerged: _playerSubmerged,
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

                            // Summon Poké Ball arc & ground bounce (Trainer hand -> Player platform)
                            if (_showSummonBallArc)
                              _buildSummonBallOverlay(
                                playerPlatform: playerPlatform,
                              ),

                            // Multi-phase Catching Poké Ball throw, beam, bounce, wobble & lock
                            if (_showPokeBallThrow)
                              _buildCatchBallOverlay(
                                playerPlatform: playerPlatform,
                                oppPlatform: oppPlatform,
                                oppSize: oppSize,
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

  Widget _buildBallShadow({
    required Offset floorPos,
    required double width,
    required double opacity,
  }) {
    return Positioned(
      left: floorPos.dx - width / 2,
      top: floorPos.dy - width * 0.16,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: width * 0.32,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(opacity.clamp(0.0, 0.5)),
            borderRadius: BorderRadius.circular(width),
          ),
        ),
      ),
    );
  }

  Widget _buildSummonBallOverlay({required Offset playerPlatform}) {
    final Offset start = playerPlatform + const Offset(36, -116);
    final Offset end = playerPlatform + const Offset(0, -14);
    final Offset startFloor = playerPlatform + const Offset(30, -2);
    final Offset endFloor = playerPlatform + const Offset(0, -2);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 520),
      builder: (context, t, _) {
        double x;
        double y;
        double spinAngle = 0.0;
        double scaleX = 1.0;
        double scaleY = 1.0;
        bool isOpen = false;
        Offset floorPos = endFloor;

        if (t < 0.72) {
          final u = Curves.easeOutCubic.transform(t / 0.72);
          x = start.dx + (end.dx - start.dx) * u;
          y = start.dy + (end.dy - start.dy) * u - sin(u * pi) * 48;
          floorPos = Offset(
            startFloor.dx + (endFloor.dx - startFloor.dx) * u,
            startFloor.dy + (endFloor.dy - startFloor.dy) * u,
          );
          spinAngle = u * pi * 5;
        } else if (t < 0.90) {
          final b = (t - 0.72) / 0.18;
          x = end.dx;
          y = end.dy - sin(b * pi) * 14;
          spinAngle = pi * 5;
          if (b < 0.28) {
            scaleX = 1.15;
            scaleY = 0.85;
          }
        } else {
          x = end.dx;
          y = end.dy;
          spinAngle = 0.0;
          isOpen = true;
        }

        final double heightAboveFloor = (floorPos.dy - y).clamp(0.0, 140.0);
        final double shadowFactor = (1.0 - heightAboveFloor / 160.0).clamp(0.45, 1.0);
        const double ballSize = 30.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBallShadow(
              floorPos: floorPos,
              width: 24.0 * shadowFactor,
              opacity: 0.36 * shadowFactor,
            ),
            Positioned(
              left: x - ballSize / 2,
              top: y - (isOpen ? ballSize * 0.75 : ballSize / 2),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                child: Transform.rotate(
                  angle: spinAngle,
                  child: PokeBallSpriteWidget(
                    ballType: 'poke_ball',
                    size: ballSize,
                    isOpen: isOpen,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCatchBallOverlay({
    required Offset playerPlatform,
    required Offset oppPlatform,
    required double oppSize,
  }) {
    final Offset startPos = playerPlatform + const Offset(38, -118);
    final Offset impactPos = oppPlatform + Offset(0, -oppSize * 0.48);
    final Offset groundPos = oppPlatform + const Offset(0, -13);
    final Offset startFloor = playerPlatform + const Offset(24, -2);
    final Offset oppFloor = oppPlatform + const Offset(0, -1);

    return AnimatedBuilder(
      animation: Listenable.merge([_ballPhaseController, _ballWobbleController]),
      builder: (context, _) {
        final phase = _catchBallPhase;
        if (phase == _BallAnimPhase.none) {
          return const SizedBox.shrink();
        }

        Offset ballPos = groundPos;
        Offset shadowFloor = oppFloor;
        double ballSize = 26.0;
        double angle = 0.0;
        Alignment rotatePivot = Alignment.center;
        double scaleX = 1.0;
        double scaleY = 1.0;
        bool isOpen = false;
        bool isLocked = false;
        Color? glowColor = _ballButtonGlowColor;
        Widget? phaseFx;

        switch (phase) {
          case _BallAnimPhase.flight:
            final u = Curves.easeOutCubic.transform(_ballPhaseController.value);
            ballPos = Offset(
              startPos.dx + (impactPos.dx - startPos.dx) * u,
              startPos.dy + (impactPos.dy - startPos.dy) * u - sin(u * pi) * 76,
            );
            shadowFloor = Offset(
              startFloor.dx + (oppFloor.dx - startFloor.dx) * u,
              startFloor.dy + (oppFloor.dy - startFloor.dy) * u,
            );
            ballSize = 34.0 + (26.0 - 34.0) * u;
            angle = u * pi * 7;
            break;

          case _BallAnimPhase.absorb:
            final t = _ballPhaseController.value;
            ballPos = impactPos + Offset(0, -sin(t * pi) * 14);
            ballSize = 28.0;
            isOpen = true;
            glowColor = Colors.white;
            phaseFx = Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CaptureAbsorbPainter(
                    ballCenter: ballPos,
                    targetCenter: oppPlatform + Offset(0, -oppSize * 0.36),
                    progress: t,
                  ),
                ),
              ),
            );
            break;

          case _BallAnimPhase.bounce:
            final t = _ballPhaseController.value;
            ballSize = 26.0;
            double y;
            if (t < 0.25) {
              final fallU = (t / 0.25).clamp(0.0, 1.0);
              final fallEase = fallU * fallU;
              y = impactPos.dy + (groundPos.dy - impactPos.dy) * fallEase;
              if (fallU > 0.90) {
                scaleX = 1.12;
                scaleY = 0.88;
              }
            } else {
              final bt = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
              final maxBounce = max(26.0, (groundPos.dy - impactPos.dy).abs() * 0.62);
              final hop = sin(bt * pi * 3.0).abs() * pow(1.0 - bt, 1.55) * maxBounce;
              y = groundPos.dy - hop;
              if (hop < 2.8 && bt < 0.92) {
                scaleX = 1.16;
                scaleY = 0.84;
              }
            }
            ballPos = Offset(groundPos.dx, y);
            break;

          case _BallAnimPhase.wobble:
            final wt = _ballWobbleController.isAnimating ? _ballWobbleController.value : 0.0;
            angle = sin(wt * pi * 2.5) * 0.44 * (1.0 - wt * 0.55);
            ballPos = groundPos + Offset(angle * 14.0, 0);
            rotatePivot = Alignment.bottomCenter;
            ballSize = 26.0;
            break;

          case _BallAnimPhase.locked:
            ballPos = groundPos;
            ballSize = 26.0;
            isLocked = true;
            if (_showCaptureLockBurst) {
              phaseFx = Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CaptureLockBurstPainter(
                      center: groundPos,
                      progress: _ballPhaseController.value,
                    ),
                  ),
                ),
              );
            }
            break;

          case _BallAnimPhase.breakout:
            final t = _ballPhaseController.value;
            ballPos = groundPos + Offset(0, -10.0 * sin(t * pi));
            ballSize = 28.0;
            isOpen = true;
            glowColor = Colors.white;
            phaseFx = Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CaptureLockBurstPainter(
                    center: groundPos,
                    progress: t,
                    isBreakout: true,
                  ),
                ),
              ),
            );
            break;

          case _BallAnimPhase.none:
            break;
        }

        final double heightAboveFloor = (shadowFloor.dy - ballPos.dy).clamp(0.0, 160.0);
        final double shadowFactor = (1.0 - heightAboveFloor / 180.0).clamp(0.40, 1.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (phaseFx != null) phaseFx,
            _buildBallShadow(
              floorPos: Offset(
                phase == _BallAnimPhase.wobble ? ballPos.dx : shadowFloor.dx,
                shadowFloor.dy,
              ),
              width: (ballSize * 0.90) * shadowFactor,
              opacity: 0.40 * shadowFactor,
            ),
            Positioned(
              left: ballPos.dx - ballSize / 2,
              top: ballPos.dy - (isOpen ? ballSize * 0.75 : ballSize / 2),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(scaleX, scaleY, 1.0),
                child: Transform.rotate(
                  angle: angle,
                  alignment: rotatePivot,
                  child: PokeBallSpriteWidget(
                    ballType: _throwingBallType,
                    size: ballSize,
                    isOpen: isOpen,
                    buttonGlowColor: glowColor,
                    isLocked: isLocked,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCombatant({
    required String url,
    required String fallbackUrl,
    required double size,
    required bool isFainted,
    bool isSubmerged = false,
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

    return AnimatedOpacity(
      opacity: isSubmerged ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 140),
      child: AnimatedSlide(
        offset: isSubmerged ? const Offset(0, 0.35) : lungeOffset,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: isFainted ? ClipRect(child: animatedSprite) : animatedSprite,
      ),
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
      width: 184,
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
                  if (!isPlayer)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: mon.species.rarity.color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: mon.species.rarity.color.withOpacity(0.7),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        mon.species.rarity.displayName.toUpperCase(),
                        style: TextStyle(
                          color: mon.species.rarity.color,
                          fontSize: 7.5,
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

  Future<void> _useHealingItem(
    String itemId,
    int healAmount,
    String itemName,
  ) async {
    _trainer.adjustItemCount(itemId, -1);
    _playerPokemon.currentHp =
        (_playerPokemon.currentHp + healAmount).clamp(0, _playerPokemon.maxHp);
    Navigator.pop(context);
    setState(() {
      _isProcessingTurn = true;
      _displayedPlayerHp = _playerPokemon.currentHp;
      _currentMessage =
          "${_trainer.name} used a $itemName! ${_playerPokemon.nickname} healed $healAmount HP.";
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
  }

  Future<void> _useReviveItem() async {
    final faintedMon = _trainer.party.firstWhere((p) => p.isFainted);
    _trainer.adjustItemCount('revive', -1);
    faintedMon.currentHp = (faintedMon.maxHp / 2).ceil();
    Navigator.pop(context);
    setState(() {
      _isProcessingTurn = true;
      _currentMessage =
          "${_trainer.name} used a Revive! ${faintedMon.nickname} was revived to half HP!";
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
  }

  void _openBagModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.72,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TRAINER BAG",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (widget.isWild) ...[
                        _bagRow(
                          icon: Icons.catching_pokemon,
                          iconColor: Colors.redAccent,
                          leadingWidget: const PokeBallSpriteWidget(
                              ballType: 'poke_ball', size: 28),
                          title: "Poké Ball",
                          rarity: "Common",
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
                          leadingWidget: const PokeBallSpriteWidget(
                              ballType: 'great_ball', size: 28),
                          title: "Great Ball (1.5x)",
                          rarity: "Uncommon",
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
                          leadingWidget: const PokeBallSpriteWidget(
                              ballType: 'ultra_ball', size: 28),
                          title: "Ultra Ball (2.0x)",
                          rarity: "Rare",
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
                        rarity: "Common",
                        subtitle: "x${_trainer.potions} remaining (+20 HP)",
                        btnLabel: "USE",
                        btnColor: Colors.green,
                        enabled: _trainer.potions > 0 &&
                            _playerPokemon.currentHp < _playerPokemon.maxHp,
                        onTap: () =>
                            _useHealingItem('potion', 20, "Potion"),
                      ),
                      _bagRow(
                        icon: Icons.medical_services,
                        iconColor: Colors.tealAccent,
                        title: "Super Potion",
                        rarity: "Uncommon",
                        subtitle:
                            "x${_trainer.superPotions} remaining (+50 HP)",
                        btnLabel: "USE",
                        btnColor: Colors.teal.shade700,
                        enabled: _trainer.superPotions > 0 &&
                            _playerPokemon.currentHp < _playerPokemon.maxHp,
                        onTap: () => _useHealingItem(
                            'super_potion', 50, "Super Potion"),
                      ),
                      _bagRow(
                        icon: Icons.medical_services,
                        iconColor: Colors.pinkAccent,
                        title: "Hyper Potion",
                        rarity: "Rare",
                        subtitle:
                            "x${_trainer.hyperPotions} remaining (+200 HP)",
                        btnLabel: "USE",
                        btnColor: Colors.pink.shade700,
                        enabled: _trainer.hyperPotions > 0 &&
                            _playerPokemon.currentHp < _playerPokemon.maxHp,
                        onTap: () => _useHealingItem(
                            'hyper_potion', 200, "Hyper Potion"),
                      ),
                      _bagRow(
                        icon: Icons.favorite,
                        iconColor: Colors.orangeAccent,
                        title: "Revive",
                        rarity: "Rare",
                        subtitle:
                            "x${_trainer.revives} remaining (+50% HP)",
                        btnLabel: "USE",
                        btnColor: Colors.orange.shade800,
                        enabled: _trainer.revives > 0 &&
                            _trainer.party.any((p) => p.isFainted),
                        onTap: _useReviveItem,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bagRow({
    required IconData icon,
    required Color iconColor,
    Widget? leadingWidget,
    required String title,
    String? rarity,
    required String subtitle,
    required String btnLabel,
    required Color btnColor,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leadingWidget ?? Icon(icon, color: iconColor, size: 28),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          if (rarity != null) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: iconColor.withOpacity(0.6),
                  width: 0.8,
                ),
              ),
              child: Text(
                rarity.toUpperCase(),
                style: TextStyle(
                  color: iconColor,
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 12)),
      trailing: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
            backgroundColor: btnColor, foregroundColor: Colors.white),
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

class _CaptureAbsorbPainter extends CustomPainter {
  final Offset ballCenter;
  final Offset targetCenter;
  final double progress;

  _CaptureAbsorbPainter({
    required this.ballCenter,
    required this.targetCenter,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final beamOpacity = (sin(t * pi) * 0.95).clamp(0.0, 1.0);

    // Conical crimson/pink capture beam between the open ball and the wild Pokémon
    final dir = targetCenter - ballCenter;
    final len = dir.distance.clamp(1.0, 500.0);
    final perp = Offset(-dir.dy / len, dir.dx / len);
    final spread = 24.0 * (1.0 - t * 0.55);

    final conePath = Path()
      ..moveTo(ballCenter.dx - perp.dx * 4, ballCenter.dy - perp.dy * 4)
      ..lineTo(ballCenter.dx + perp.dx * 4, ballCenter.dy + perp.dy * 4)
      ..lineTo(targetCenter.dx + perp.dx * spread, targetCenter.dy + perp.dy * spread)
      ..lineTo(targetCenter.dx - perp.dx * spread, targetCenter.dy - perp.dy * spread)
      ..close();

    canvas.drawPath(
      conePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.9 * beamOpacity),
            const Color(0xFFFF4081).withOpacity(0.55 * beamOpacity),
          ],
        ).createShader(Rect.fromPoints(ballCenter, targetCenter)),
    );

    // Contracting capture rings zooming up into the open ball
    for (int i = 0; i < 3; i++) {
      final frac = ((t + i * 0.22) % 1.0).clamp(0.0, 1.0);
      final ringCenter = Offset(
        targetCenter.dx + (ballCenter.dx - targetCenter.dx) * frac,
        targetCenter.dy + (ballCenter.dy - targetCenter.dy) * frac,
      );
      final radius = (22.0 * (1.0 - frac)).clamp(2.0, 26.0);
      canvas.drawCircle(
        ringCenter,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = Colors.white.withOpacity((1.0 - frac) * 0.85),
      );
    }

    // Core glow inside the open capsule
    canvas.drawCircle(
      ballCenter,
      16 * beamOpacity + 4,
      Paint()..color = const Color(0xFFFF80AB).withOpacity(0.45 * beamOpacity),
    );
  }

  @override
  bool shouldRepaint(covariant _CaptureAbsorbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ballCenter != ballCenter ||
      oldDelegate.targetCenter != targetCenter;
}

class _CaptureLockBurstPainter extends CustomPainter {
  final Offset center;
  final double progress;
  final bool isBreakout;

  _CaptureLockBurstPainter({
    required this.center,
    required this.progress,
    this.isBreakout = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final opacity = (1.0 - t).clamp(0.0, 1.0);

    if (isBreakout) {
      canvas.drawCircle(
        center,
        14 + t * 44,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5 * opacity
          ..color = const Color(0xFFFF5252).withOpacity(opacity),
      );
      canvas.drawCircle(
        center,
        24 * (1.0 - t * 0.5),
        Paint()..color = Colors.white.withOpacity(opacity * 0.85),
      );
      for (int i = 0; i < 8; i++) {
        final ang = (i / 8) * pi * 2;
        final p1 = center + Offset(cos(ang) * (10 + t * 18), sin(ang) * (10 + t * 18));
        final p2 = center + Offset(cos(ang) * (24 + t * 34), sin(ang) * (24 + t * 34));
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.white.withOpacity(opacity)
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }

    // Capture Lock Click: soft golden ring + 3 classic rising lock stars
    canvas.drawCircle(
      center,
      12 + t * 28,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * opacity
        ..color = Colors.amberAccent.withOpacity(opacity * 0.85),
    );

    const starOffsets = [-16.0, 0.0, 16.0];
    const starHeights = [22.0, 30.0, 22.0];
    for (int i = 0; i < 3; i++) {
      final starPos = center +
          Offset(
            starOffsets[i] * (0.8 + t * 0.45),
            -starHeights[i] - sin(t * pi * 0.85) * 14.0,
          );
      final r = (5.5 + (i == 1 ? 1.5 : 0.0)) * (1.0 - t * 0.25);
      final starPath = Path()
        ..moveTo(starPos.dx, starPos.dy - r)
        ..lineTo(starPos.dx + r * 0.34, starPos.dy - r * 0.34)
        ..lineTo(starPos.dx + r, starPos.dy)
        ..lineTo(starPos.dx + r * 0.34, starPos.dy + r * 0.34)
        ..lineTo(starPos.dx, starPos.dy + r)
        ..lineTo(starPos.dx - r * 0.34, starPos.dy + r * 0.34)
        ..lineTo(starPos.dx - r, starPos.dy)
        ..lineTo(starPos.dx - r * 0.34, starPos.dy - r * 0.34)
        ..close();
      canvas.drawPath(
        starPath,
        Paint()..color = Colors.amberAccent.withOpacity((1.0 - max(0.0, t - 0.35) / 0.65).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CaptureLockBurstPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.center != center ||
      oldDelegate.isBreakout != isBreakout;
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

      // ─── NEW KANTO MOVES (FLYING, FIGHTING, GROUND, ROCK, FAIRY, GRASS, PSYCHIC, GHOST, ICE) ─
      case 'peck':
      case 'drill_peck':
        {
          final isDrill = moveId == 'drill_peck';
          final strikes = isDrill ? 3 : 2;
          for (int i = 0; i < strikes; i++) {
            final lt = ((t - i * 0.14) / 0.48).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final off = perp * ((i - (strikes - 1) / 2.0) * 14.0);
            final tip = Offset.lerp(attackerCenter + off, defenderCenter + off * 0.4, lt)!;
            final beakLen = isDrill ? 26.0 : 18.0;
            final beakW = isDrill ? 10.0 : 7.0;
            final beakPath = Path()
              ..moveTo(tip.dx + unit.dx * beakLen, tip.dy + unit.dy * beakLen)
              ..lineTo(tip.dx - unit.dx * 8 + perp.dx * beakW, tip.dy - unit.dy * 8 + perp.dy * beakW)
              ..lineTo(tip.dx - unit.dx * 8 - perp.dx * beakW, tip.dy - unit.dy * 8 - perp.dy * beakW)
              ..close();
            canvas.drawPath(
              beakPath,
              Paint()..color = (isDrill ? Colors.cyanAccent : Colors.amberAccent).withOpacity(fade),
            );
            canvas.drawPath(
              beakPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0
                ..color = Colors.white.withOpacity(fade),
            );
            if (isDrill) {
              // Spinning helical wind-tunnel rings along drill shaft
              for (int r = 0; r < 3; r++) {
                final ringPos = tip - unit * (r * 11.0);
                canvas.drawOval(
                  Rect.fromCenter(center: ringPos, width: 22 - r * 3.0, height: 10),
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2.5 * fade
                    ..color = Colors.white.withOpacity(0.85 * fade),
                );
              }
            }
          }
          if (t > 0.35) {
            final st = (t - 0.35) / 0.65;
            for (int f = 0; f < 6; f++) {
              final ang = (f / 6) * pi * 2 + st * 2.0;
              final fp = defenderCenter + Offset(cos(ang) * st * 42, sin(ang) * st * 34);
              _drawStarPath(canvas, fp, 6 * fade, 2.5 * fade, Colors.white, fade, points: 4);
            }
          }
        }
        break;

      case 'double_kick':
        {
          for (int kick = 0; kick < 2; kick++) {
            final lt = ((t - kick * 0.30) / 0.45).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final hitPos = defenderCenter + Offset(kick == 0 ? -15 : 15, kick == 0 ? 8 : -10);
            canvas.drawCircle(
              hitPos,
              12 + lt * 28,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * (1.0 - lt * 0.4) * fade
                ..color = Colors.deepOrangeAccent.withOpacity(fade),
            );
            for (int r = 0; r < 8; r++) {
              final ang = (r / 8) * pi * 2 + kick * 0.4;
              canvas.drawLine(
                hitPos + Offset(cos(ang) * 8, sin(ang) * 8),
                hitPos + Offset(cos(ang) * (14 + lt * 26), sin(ang) * (14 + lt * 26)),
                Paint()
                  ..color = (r.isEven ? Colors.white : Colors.amberAccent).withOpacity(fade)
                  ..strokeWidth = 3.2
                  ..strokeCap = StrokeCap.round,
              );
            }
            canvas.drawCircle(
              hitPos,
              10 * (1.0 - lt * 0.45),
              Paint()..color = Colors.white.withOpacity(0.9 * fade),
            );
          }
        }
        break;

      case 'mud_slap':
      case 'acid':
        {
          final isMud = moveId == 'mud_slap';
          final mainCol = isMud ? const Color(0xFF8D6E63) : Colors.lightGreenAccent;
          final darkCol = isMud ? const Color(0xFF4E342E) : Colors.green.shade700;
          for (int i = 0; i < 8; i++) {
            final lt = ((t - i * 0.05) / 0.55).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final arc = sin(lt * pi) * (18 + (i % 3) * 8.0);
            final spread = perp * ((i - 3.5) * 8.0 * lt);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                spread +
                Offset(0, -arc);
            canvas.drawCircle(pos, (6 + (i % 3) * 2.5) * fade, Paint()..color = darkCol.withOpacity(fade));
            canvas.drawCircle(
                pos + const Offset(-1.5, -1.5), (4 + (i % 2) * 1.5) * fade, Paint()..color = mainCol.withOpacity(fade));
          }
          if (t > 0.42) {
            final bt = (t - 0.42) / 0.58;
            for (int b = 0; b < 5; b++) {
              final bx = (b - 2.0) * 14.0;
              final by = isMud ? bt * 24.0 : -bt * 34.0;
              final bp = defenderCenter + Offset(bx, by + sin(b * 1.7) * 8.0);
              canvas.drawCircle(
                bp,
                (isMud ? 6.0 : 5.0 + (b % 2) * 2.0) * (1.0 - bt * 0.35) * fade,
                Paint()..color = mainCol.withOpacity(0.85 * fade),
              );
              if (!isMud) {
                canvas.drawCircle(
                  bp,
                  6.5 * (1.0 - bt * 0.3),
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.6
                    ..color = Colors.white.withOpacity(0.7 * fade),
                );
              }
            }
          }
        }
        break;

      case 'dig':
        {
          if (t < 0.48) {
            // Phase 1: Burrow mound at attacker + subterranean dirt trail toward defender
            final bt = (t / 0.48).clamp(0.0, 1.0);
            for (int cl = 0; cl < 5; cl++) {
              final cx = (cl - 2.0) * 10.0;
              final cy = -sin(bt * pi * 2 + cl) * 12.0 + 18.0;
              canvas.drawCircle(
                attackerCenter + Offset(cx, cy),
                7.0 * (1.0 - bt * 0.4),
                Paint()..color = const Color(0xFF795548).withOpacity(0.9),
              );
            }
            canvas.drawOval(
              Rect.fromCenter(center: attackerCenter + const Offset(0, 20), width: 52, height: 18),
              Paint()..color = const Color(0xFF4E342E).withOpacity(0.85),
            );
            // Moving subterranean tremor mounds along the path
            final steps = (bt * 6).floor();
            for (int s = 0; s <= steps; s++) {
              final mp = Offset.lerp(attackerCenter + const Offset(0, 18),
                  defenderCenter + const Offset(0, 18), s / 6.0)!;
              canvas.drawOval(
                Rect.fromCenter(center: mp, width: 20, height: 8),
                Paint()..color = const Color(0xFF8D6E63).withOpacity(0.85),
              );
            }
          } else {
            // Phase 2: Ground fissure & earthen geyser eruption beneath defender
            final et = ((t - 0.48) / 0.52).clamp(0.0, 1.0);
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter + const Offset(0, 20),
                width: 30 + et * 64,
                height: 12 + et * 24,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * fade
                ..color = const Color(0xFFD7A86E).withOpacity(fade),
            );
            for (int sp = -2; sp <= 2; sp++) {
              final basePt = defenderCenter + Offset(sp * 11.0, 22);
              final peakPt = defenderCenter + Offset(sp * 14.0, 18 - sin(et * pi) * 68);
              canvas.drawLine(
                basePt,
                peakPt,
                Paint()
                  ..color = (sp.isEven ? const Color(0xFFD7A86E) : const Color(0xFF8D6E63))
                      .withOpacity(fade)
                  ..strokeWidth = 8.0 * fade
                  ..strokeCap = StrokeCap.round,
              );
            }
            for (int r = 0; r < 6; r++) {
              final ang = -pi * (0.15 + r / 6.0 * 0.70);
              final rp = defenderCenter + Offset(cos(ang) * et * 48, 12 + sin(ang) * et * 54);
              _drawPolygonBoulder(canvas, rp, 7.0, et * 5 + r, fade);
            }
          }
        }
        break;

      case 'earthquake':
        {
          // Jagged tectonic fault cracks + expanding seismic shockwaves + bouncing boulders
          for (int k = 0; k < 4; k++) {
            final ang = (k / 4) * pi * 2 + 0.35;
            final crackPath = Path()..moveTo(defenderCenter.dx, defenderCenter.dy + 18);
            Offset cur = defenderCenter + const Offset(0, 18);
            for (int seg = 1; seg <= 4; seg++) {
              final reachSeg = min(1.0, t * 1.8) * (seg / 4.0) * 68.0;
              final jitter = (seg.isEven ? 1 : -1) * 11.0;
              cur = defenderCenter +
                  const Offset(0, 18) +
                  Offset(cos(ang) * reachSeg + sin(ang) * jitter,
                      sin(ang) * reachSeg * 0.45 + cos(ang) * jitter * 0.4);
              crackPath.lineTo(cur.dx, cur.dy);
            }
            canvas.drawPath(
              crackPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * fade
                ..strokeCap = StrokeCap.round
                ..color = const Color(0xFF3E2723).withOpacity(fade),
            );
            canvas.drawPath(
              crackPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0 * fade
                ..color = const Color(0xFFFFD54F).withOpacity(0.8 * fade),
            );
          }
          for (int i = 0; i < 3; i++) {
            final lt = ((t - i * 0.14) / 0.65).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter + const Offset(0, 18),
                width: 40 + lt * 145,
                height: 14 + lt * 48,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * fade
                ..color = const Color(0xFFE0C068).withOpacity(fade),
            );
          }
          for (int b = 0; b < 6; b++) {
            final bx = (b - 2.5) * 24.0;
            final hop = sin((t * pi * 2 + b * 0.7).clamp(0.0, pi)) * 26.0;
            _drawPolygonBoulder(
              canvas,
              defenderCenter + Offset(bx, 16 - hop),
              7.5,
              t * 6 + b,
              fade,
            );
          }
        }
        break;

      case 'rock_throw':
      case 'rock_slide':
        {
          final isSlide = moveId == 'rock_slide';
          final boulderCount = isSlide ? 5 : 2;
          for (int i = 0; i < boulderCount; i++) {
            final lt = ((t - i * 0.08) / 0.56).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final xOff = (i - (boulderCount - 1) / 2.0) * (isSlide ? 20.0 : 18.0);
            final startY = defenderCenter.dy - 125;
            final curY = startY + (defenderCenter.dy + 6 - startY) * (lt * lt);
            final boulderPos = Offset(defenderCenter.dx + xOff, curY);
            _drawPolygonBoulder(
              canvas,
              boulderPos,
              isSlide ? 13.0 : 16.0,
              lt * 4.5 + i,
              fade,
            );
            if (lt > 0.85) {
              final dt = (lt - 0.85) / 0.15;
              for (int d = -1; d <= 1; d += 2) {
                canvas.drawCircle(
                  boulderPos + Offset(d * dt * 16, 4 - dt * 8),
                  5 * fade,
                  Paint()..color = const Color(0xFFD7CCC8).withOpacity(0.75 * fade),
                );
              }
            }
          }
          if (t > 0.45) {
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter + const Offset(0, 16),
                width: 44 + (t - 0.45) * 76,
                height: 16 + (t - 0.45) * 24,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = const Color(0xFFD7CCC8).withOpacity(0.8 * fade),
            );
          }
        }
        break;

      case 'power_gem':
        {
          // Rotating crystalline gem prism at attacker + refracted gold/magenta beam + gem burst
          final gemR = 16.0;
          final rot = t * pi * 3;
          final prism = Path()
            ..moveTo(attackerCenter.dx + cos(rot) * gemR, attackerCenter.dy + sin(rot) * gemR)
            ..lineTo(attackerCenter.dx + cos(rot + pi / 2) * gemR * 0.65,
                attackerCenter.dy + sin(rot + pi / 2) * gemR * 0.65)
            ..lineTo(attackerCenter.dx - cos(rot) * gemR, attackerCenter.dy - sin(rot) * gemR)
            ..lineTo(attackerCenter.dx - cos(rot + pi / 2) * gemR * 0.65,
                attackerCenter.dy - sin(rot + pi / 2) * gemR * 0.65)
            ..close();
          canvas.drawPath(prism, Paint()..color = Colors.pinkAccent.withOpacity(0.85 * fade));
          canvas.drawPath(
            prism,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..color = Colors.white.withOpacity(fade),
          );
          final beamReach = min(1.0, t / 0.60);
          final beamEnd = Offset.lerp(attackerCenter, defenderCenter, beamReach)!;
          canvas.drawLine(
            attackerCenter,
            beamEnd,
            Paint()
              ..color = Colors.amberAccent.withOpacity(0.9 * fade)
              ..strokeWidth = 10 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            beamEnd,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = 4 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.40) {
            final st = (t - 0.40) / 0.60;
            for (int g = 0; g < 6; g++) {
              final ang = (g / 6) * pi * 2 + st * 2.5;
              final gp = defenderCenter + Offset(cos(ang) * st * 38, sin(ang) * st * 38);
              _drawStarPath(
                canvas,
                gp,
                7 * fade,
                3 * fade,
                g.isEven ? Colors.pinkAccent : Colors.amberAccent,
                fade,
                points: 4,
              );
            }
          }
        }
        break;

      case 'sing':
        {
          const notes = ['♪', '♫', '♬', '♪', '♫'];
          for (int i = 0; i < notes.length; i++) {
            final lt = ((t - i * 0.11) / 0.65).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final wave = perp * (sin(lt * pi * 3 + i * 1.1) * 18);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                wave +
                Offset(0, -lt * 16);
            canvas.drawCircle(
              pos,
              14,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0 * fade
                ..color = Colors.pinkAccent.withOpacity(0.55 * fade),
            );
            final tp = TextPainter(
              text: TextSpan(
                text: notes[i],
                style: TextStyle(
                  color: (i.isEven ? Colors.pinkAccent : Colors.cyanAccent).withOpacity(fade),
                  fontSize: 18 + (i % 2) * 3.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
          }
          if (t > 0.55) {
            final tp = TextPainter(
              text: TextSpan(
                text: 'Zzz',
                style: TextStyle(
                  color: Colors.white.withOpacity(fade),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, defenderCenter + Offset(-12, -32 - (t - 0.55) * 28));
          }
        }
        break;

      case 'disarming_voice':
        {
          for (int i = 0; i < 4; i++) {
            final lt = ((t - i * 0.12) / 0.62).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final wave = perp * (sin(lt * pi * 2.5 + i) * 14);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + wave;
            _drawHeartPath(
              canvas,
              pos,
              10 + lt * 8.0,
              Paint()..color = (i.isEven ? Colors.pinkAccent : Colors.pink.shade200).withOpacity(0.85 * fade),
            );
            _drawHeartPath(
              canvas,
              pos,
              12 + lt * 8.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0 * fade
                ..color = Colors.white.withOpacity(0.75 * fade),
            );
          }
          if (t > 0.45) {
            final st = (t - 0.45) / 0.55;
            for (int s = 0; s < 5; s++) {
              final ang = (s / 5) * pi * 2 + st * 2;
              _drawStarPath(
                canvas,
                defenderCenter + Offset(cos(ang) * st * 36, sin(ang) * st * 36),
                6 * fade,
                2.5 * fade,
                Colors.pinkAccent,
                fade,
                points: 4,
              );
            }
          }
        }
        break;

      case 'body_slam':
        {
          final slamScale = 1.0 + sin(t * pi) * 0.85;
          canvas.drawOval(
            Rect.fromCenter(
                center: defenderCenter + const Offset(0, 14),
                width: 58 * slamScale,
                height: 24 * slamScale),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * fade
              ..color = Colors.white.withOpacity(fade),
          );
          canvas.drawOval(
            Rect.fromCenter(
                center: defenderCenter + const Offset(0, 14),
                width: 84 * t,
                height: 34 * t),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 * fade
              ..color = Colors.amberAccent.withOpacity(fade),
          );
          for (int i = 0; i < 8; i++) {
            final ang = (i / 8) * pi * 2;
            canvas.drawLine(
              defenderCenter + Offset(cos(ang) * 14, sin(ang) * 10),
              defenderCenter + Offset(cos(ang) * (20 + t * 42), sin(ang) * (16 + t * 32)),
              Paint()
                ..color = Colors.white.withOpacity(fade)
                ..strokeWidth = 4.0 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
        }
        break;

      case 'swift':
        {
          for (int i = 0; i < 7; i++) {
            final lt = ((t - i * 0.065) / 0.52).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final spread = (i - 3.0) * 11.0;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                perp * (sin(lt * pi) * spread);
            final prevPos = Offset.lerp(attackerCenter, defenderCenter, max(0.0, lt - 0.14))! +
                perp * (sin(max(0.0, lt - 0.14) * pi) * spread);
            canvas.drawLine(
              prevPos,
              pos,
              Paint()
                ..color = Colors.amberAccent.withOpacity(0.55 * fade)
                ..strokeWidth = 4.5 * fade
                ..strokeCap = StrokeCap.round,
            );
            _drawStarPath(
              canvas,
              pos,
              11 * fade,
              4.8 * fade,
              Colors.amberAccent,
              fade,
              rotation: lt * 8 + i,
            );
            _drawStarPath(
              canvas,
              pos,
              6 * fade,
              2.6 * fade,
              Colors.white,
              fade,
              rotation: lt * 8 + i,
            );
          }
        }
        break;

      case 'splash':
        {
          // Flopping water splash crown + droplet arcs + ripple rings around attacker
          for (int r = 0; r < 2; r++) {
            final rt = ((t - r * 0.22) / 0.78).clamp(0.0, 1.0);
            if (rt <= 0) continue;
            canvas.drawOval(
              Rect.fromCenter(
                center: attackerCenter + const Offset(0, 18),
                width: 26 + rt * 72,
                height: 10 + rt * 26,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * fade
                ..color = Colors.lightBlueAccent.withOpacity(fade),
            );
          }
          for (int i = 0; i < 8; i++) {
            final ang = -pi * (0.08 + (i / 7.0) * 0.84);
            final hopPos = attackerCenter +
                Offset(cos(ang) * t * 44, sin(ang) * t * 38 + t * t * 32);
            canvas.drawCircle(hopPos, 5.5 * fade, Paint()..color = Colors.lightBlueAccent.withOpacity(fade));
            canvas.drawCircle(hopPos + const Offset(-1, -1), 2.5 * fade, Paint()..color = Colors.white.withOpacity(fade));
          }
        }
        break;

      case 'moonblast':
        {
          // Glowing crescent moon high in the sky projecting a celestial pink lunar beam + star bursts
          final moonCenter = Offset(defenderCenter.dx - 44, max(36.0, defenderCenter.dy - 110));
          canvas.drawCircle(
            moonCenter,
            26 * fade,
            Paint()..color = Colors.pinkAccent.withOpacity(0.28 * fade),
          );
          final moonPath = Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: moonCenter, radius: 18)),
            Path()..addOval(Rect.fromCircle(center: moonCenter + const Offset(7, -4), radius: 15)),
          );
          canvas.drawPath(moonPath, Paint()..color = const Color(0xFFFFE0F0).withOpacity(fade));

          final beamReach = min(1.0, t / 0.55);
          final beamEnd = Offset.lerp(moonCenter, defenderCenter, beamReach)!;
          canvas.drawLine(
            moonCenter,
            beamEnd,
            Paint()
              ..color = Colors.pinkAccent.withOpacity(0.55 * fade)
              ..strokeWidth = 26 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            moonCenter,
            beamEnd,
            Paint()
              ..color = Colors.white.withOpacity(0.9 * fade)
              ..strokeWidth = 10 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.35) {
            final st = (t - 0.35) / 0.65;
            for (int s = 0; s < 6; s++) {
              final ang = (s / 6) * pi * 2 + st * 2;
              _drawStarPath(
                canvas,
                defenderCenter + Offset(cos(ang) * st * 44, sin(ang) * st * 40),
                8 * fade,
                3.5 * fade,
                s.isEven ? Colors.pinkAccent : Colors.white,
                fade,
                points: 4,
              );
            }
          }
        }
        break;

      case 'glare':
        {
          // Menacing almond reptile eyes with glowing red irises & vertical slit pupils + petrifying rings
          for (final sign in [-1.0, 1.0]) {
            final eyeC = attackerCenter + Offset(sign * 15, -14);
            final eyeShape = Path()
              ..moveTo(eyeC.dx - 11, eyeC.dy)
              ..quadraticBezierTo(eyeC.dx, eyeC.dy - 9, eyeC.dx + 11, eyeC.dy)
              ..quadraticBezierTo(eyeC.dx, eyeC.dy + 9, eyeC.dx - 11, eyeC.dy)
              ..close();
            canvas.drawPath(eyeShape, Paint()..color = Colors.redAccent.withOpacity(0.95 * fade));
            canvas.drawLine(
              eyeC + const Offset(0, -6),
              eyeC + const Offset(0, 6),
              Paint()
                ..color = Colors.black.withOpacity(fade)
                ..strokeWidth = 3.0,
            );
          }
          for (int i = 0; i < 3; i++) {
            final lt = ((t - i * 0.14) / 0.65).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            canvas.drawCircle(
              defenderCenter,
              14 + lt * 34,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.2 * fade
                ..color = (i.isEven ? Colors.redAccent : Colors.yellowAccent).withOpacity(fade),
            );
          }
        }
        break;

      case 'aqua_tail':
        {
          // Dual S-curve bezier water whip + swirling crash vortex
          for (int pass = 0; pass < 2; pass++) {
            final whipAngle = -pi * 0.85 + t * 3.0 + pass * 0.25;
            final tailRect = Rect.fromCenter(center: defenderCenter, width: 82, height: 60);
            canvas.drawArc(
              tailRect,
              whipAngle,
              pi * 1.15,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (pass == 0 ? 12.0 : 5.0) * fade
                ..strokeCap = StrokeCap.round
                ..color = (pass == 0 ? const Color(0xFF1E88E5) : Colors.white).withOpacity(fade),
            );
          }
          for (int s = 0; s < 8; s++) {
            final ang = (s / 8) * pi * 2 + t * 4;
            final sp = defenderCenter + Offset(cos(ang) * t * 42, sin(ang) * t * 32);
            canvas.drawCircle(sp, 5 * fade, Paint()..color = Colors.cyanAccent.withOpacity(fade));
          }
        }
        break;

      case 'absorb':
        {
          // Double-helix emerald life orbs spiraling FROM defender INTO attacker + healing aura
          for (int i = 0; i < 10; i++) {
            final lt = ((t - i * 0.05) / 0.58).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final side = i.isEven ? 1.0 : -1.0;
            final spiral = perp * (sin(lt * pi * 3 + i) * 18.0 * side);
            final pos = Offset.lerp(defenderCenter, attackerCenter, lt)! + spiral;
            canvas.drawCircle(pos, 7.5 * fade, Paint()..color = Colors.lightGreenAccent.withOpacity(0.85 * fade));
            canvas.drawCircle(pos, 3.5 * fade, Paint()..color = Colors.white.withOpacity(fade));
          }
          if (t > 0.40) {
            final ht = (t - 0.40) / 0.60;
            canvas.drawOval(
              Rect.fromCenter(center: attackerCenter + Offset(0, -ht * 24), width: 68, height: 22),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.greenAccent.withOpacity(fade),
            );
          }
        }
        break;

      case 'petal_blizzard':
        {
          // Arena-spanning swirling wind ribbons + 18 rotating cherry-blossom petals
          for (int w = 0; w < 2; w++) {
            final yBase = size.height * (0.38 + w * 0.24);
            final ribbon = Path()..moveTo(0, yBase);
            ribbon.quadraticBezierTo(
              size.width * 0.5,
              yBase + sin(t * pi * 2 + w) * 44,
              size.width * min(1.0, t * 1.4),
              yBase - 28,
            );
            canvas.drawPath(
              ribbon,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.0 * fade
                ..color = Colors.pink.shade100.withOpacity(0.55 * fade),
            );
          }
          for (int i = 0; i < 18; i++) {
            final lt = ((t - i * 0.03) / 0.55).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final spread = (i % 5 - 2.0) * 14.0;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                perp * (spread + sin(lt * 10 + i * 1.3) * 18);
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(lt * 9 + i);
            canvas.drawOval(
              const Rect.fromLTWH(-6, -3.5, 12, 7),
              Paint()
                ..color = (i % 3 == 0
                        ? Colors.pinkAccent
                        : (i % 3 == 1 ? Colors.pink.shade100 : Colors.lightGreenAccent))
                    .withOpacity(fade),
            );
            canvas.restore();
          }
        }
        break;

      case 'psychic':
        {
          // Concentric distortion rings + 6 orbiting telekinetic spheres collapsing inward
          for (int i = 0; i < 4; i++) {
            final waveR = 14.0 + i * 12.0 + sin(t * pi * 3) * 10.0;
            canvas.drawOval(
              Rect.fromCenter(center: defenderCenter, width: waveR * 2.1, height: waveR * 1.5),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = (i.isEven ? Colors.purpleAccent : Colors.pinkAccent).withOpacity(0.8 * fade),
            );
          }
          final orbitR = 52.0 * (1.0 - sin(min(1.0, t * 1.25) * pi * 0.5) * 0.85);
          for (int o = 0; o < 6; o++) {
            final ang = (o / 6) * pi * 2 + t * pi * 3;
            final op = defenderCenter + Offset(cos(ang) * orbitR, sin(ang) * orbitR * 0.72);
            canvas.drawCircle(op, 7 * fade, Paint()..color = Colors.cyanAccent.withOpacity(fade));
            canvas.drawCircle(op, 3.5 * fade, Paint()..color = Colors.white.withOpacity(fade));
          }
        }
        break;

      // ─── ADDITIONAL GEN 1 SIGNATURE MOVE VFX ──────────────────────────────
      case 'karate_chop':
      case 'cross_chop':
        {
          final isCross = moveId == 'cross_chop';
          final blades = isCross ? 2 : 1;
          for (int i = 0; i < blades; i++) {
            final lt = ((t - i * 0.12) / 0.50).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final sign = isCross ? (i == 0 ? 1.0 : -1.0) : 0.4;
            final pA = defenderCenter + Offset(-28 * sign, -36);
            final pB = defenderCenter + Offset(28 * sign, 32);
            final tip = Offset.lerp(pA, pB, lt)!;
            canvas.drawLine(
              pA,
              tip,
              Paint()
                ..color = Colors.deepOrangeAccent.withOpacity(fade)
                ..strokeWidth = 10 * fade
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawLine(
              pA,
              tip,
              Paint()
                ..color = Colors.white.withOpacity(fade)
                ..strokeWidth = 4.5 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
          if (t > 0.35) {
            final bt = (t - 0.35) / 0.65;
            for (int r = 0; r < 8; r++) {
              final ang = (r / 8) * pi * 2;
              canvas.drawLine(
                defenderCenter + Offset(cos(ang) * 10, sin(ang) * 10),
                defenderCenter + Offset(cos(ang) * (16 + bt * 34), sin(ang) * (16 + bt * 34)),
                Paint()
                  ..color = Colors.amberAccent.withOpacity(fade)
                  ..strokeWidth = 3.5 * fade
                  ..strokeCap = StrokeCap.round,
              );
            }
          }
        }
        break;

      case 'submission':
        {
          // Whirling grapple cyclone rings + slam shockwaves + impact stars
          for (int i = 0; i < 4; i++) {
            final lt = ((t - i * 0.1) / 0.58).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final yOff = (1.0 - lt) * -28.0 + 10.0;
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter + Offset(0, yOff),
                width: 34 + lt * 54,
                height: 16 + lt * 22,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.0 * fade
                ..color = (i.isEven ? Colors.deepOrangeAccent : Colors.amberAccent).withOpacity(fade),
            );
          }
          for (int s = 0; s < 5; s++) {
            final ang = (s / 5) * pi * 2 + t * 3;
            _drawStarPath(
              canvas,
              defenderCenter + Offset(cos(ang) * t * 38, sin(ang) * t * 30),
              7 * fade,
              3 * fade,
              Colors.white,
              fade,
              points: 4,
            );
          }
        }
        break;

      case 'pay_day':
        {
          // Shower of spinning gold Koban coins with center stamps + glints
          for (int i = 0; i < 8; i++) {
            final lt = ((t - i * 0.06) / 0.58).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final arc = sin(lt * pi) * (20 + (i % 3) * 10.0);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                perp * ((i - 3.5) * 9.0 * lt) +
                Offset(0, -arc);
            _drawKobanCoin(canvas, pos, 1.0, lt * 6 + i, fade);
          }
          if (t > 0.45) {
            final st = (t - 0.45) / 0.55;
            for (int g = 0; g < 6; g++) {
              final ang = (g / 6) * pi * 2 + st * 2;
              _drawStarPath(
                canvas,
                defenderCenter + Offset(cos(ang) * st * 40, sin(ang) * st * 34),
                7 * fade,
                2.5 * fade,
                Colors.amberAccent,
                fade,
                points: 4,
              );
            }
          }
        }
        break;

      case 'fury_swipes':
      case 'x_scissor':
        {
          final isScissor = moveId == 'x_scissor';
          final slashAngles = isScissor ? [-0.78, 0.78] : [-0.55, 0.0, 0.55, -0.35];
          final bladeCol = isScissor ? Colors.lightGreenAccent : Colors.white;
          for (int i = 0; i < slashAngles.length; i++) {
            final lt = ((t - i * 0.10) / 0.46).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final ang = slashAngles[i];
            final off = isScissor ? Offset.zero : Offset((i - 1.5) * 8.0, (i - 1.5) * 4.0);
            final delta = Offset(cos(ang) * 34, sin(ang) * 34);
            final pStart = defenderCenter - delta + off;
            final pEnd = Offset.lerp(pStart, defenderCenter + delta + off, lt)!;
            canvas.drawLine(
              pStart,
              pEnd,
              Paint()
                ..color = (isScissor ? Colors.tealAccent : Colors.amberAccent).withOpacity(fade)
                ..strokeWidth = 9 * fade
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawLine(
              pStart,
              pEnd,
              Paint()
                ..color = bladeCol.withOpacity(fade)
                ..strokeWidth = 4.5 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
        }
        break;

      case 'horn_attack':
        {
          // Spiraling metallic horn lance + speed streaks + piercing shock cone
          final lt = min(1.0, t * 1.55);
          final tip = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          final hornLen = 34.0;
          final hornW = 12.0;
          final hornPath = Path()
            ..moveTo(tip.dx + unit.dx * hornLen, tip.dy + unit.dy * hornLen)
            ..lineTo(tip.dx - unit.dx * 8 + perp.dx * hornW, tip.dy - unit.dy * 8 + perp.dy * hornW)
            ..lineTo(tip.dx - unit.dx * 8 - perp.dx * hornW, tip.dy - unit.dy * 8 - perp.dy * hornW)
            ..close();
          canvas.drawPath(hornPath, Paint()..color = Colors.white.withOpacity(fade));
          canvas.drawPath(
            hornPath,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.grey.shade400.withOpacity(fade),
          );
          for (int s = -1; s <= 1; s++) {
            final off = perp * (s * 11.0);
            canvas.drawLine(
              tip - unit * 42 + off,
              tip - unit * 10 + off,
              Paint()
                ..color = Colors.amberAccent.withOpacity(0.8 * fade)
                ..strokeWidth = 3.0 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
        }
        break;

      case 'sonic_boom':
        {
          // 5 tilted supersonic Mach shockwave ovals racing along path
          final travelAngle = atan2(dir.dy, dir.dx);
          for (int i = 0; i < 5; i++) {
            final lt = ((t - i * 0.085) / 0.56).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(travelAngle + pi / 2);
            canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 22 + lt * 46, height: 10 + lt * 12),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = (i.isEven ? Colors.cyanAccent : Colors.white).withOpacity(fade),
            );
            canvas.restore();
          }
        }
        break;

      case 'bubble_beam':
        {
          // 14 glossy translucent bubbles with white highlight crescents spiraling to defender
          for (int i = 0; i < 14; i++) {
            final lt = ((t - i * 0.04) / 0.54).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final wave = sin(lt * 11 + i * 0.9) * 14.0;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * wave;
            final rad = (5.5 + (i % 3) * 3.0) * fade;
            canvas.drawCircle(pos, rad, Paint()..color = Colors.lightBlueAccent.withOpacity(0.32 * fade));
            canvas.drawCircle(
              pos,
              rad,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0
                ..color = Colors.cyanAccent.withOpacity(fade),
            );
            canvas.drawArc(
              Rect.fromCircle(center: pos, radius: max(1.0, rad * 0.65)),
              -pi * 0.85,
              pi * 0.45,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..strokeCap = StrokeCap.round
                ..color = Colors.white.withOpacity(fade),
            );
          }
        }
        break;

      case 'waterfall':
      case 'crabhammer':
        {
          final isHammer = moveId == 'crabhammer';
          if (isHammer) {
            // Giant crimson upper & lower crab claw jaws slamming together + water jets
            final snap = (1.0 - sin(min(1.0, t * 1.45) * pi * 0.5)) * 28.0;
            final clawPaint = Paint()..color = Colors.redAccent.withOpacity(fade);
            final clawRim = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = Colors.white.withOpacity(fade);
            final topClaw = Path()
              ..moveTo(defenderCenter.dx - 26, defenderCenter.dy - 14 - snap)
              ..quadraticBezierTo(defenderCenter.dx, defenderCenter.dy - 46 - snap,
                  defenderCenter.dx + 28, defenderCenter.dy - 4 - snap)
              ..quadraticBezierTo(defenderCenter.dx, defenderCenter.dy - 14 - snap,
                  defenderCenter.dx - 26, defenderCenter.dy - 14 - snap)
              ..close();
            final botClaw = Path()
              ..moveTo(defenderCenter.dx - 22, defenderCenter.dy + 12 + snap)
              ..quadraticBezierTo(defenderCenter.dx + 4, defenderCenter.dy + 34 + snap,
                  defenderCenter.dx + 26, defenderCenter.dy + 2 + snap)
              ..quadraticBezierTo(defenderCenter.dx, defenderCenter.dy + 12 + snap,
                  defenderCenter.dx - 22, defenderCenter.dy + 12 + snap)
              ..close();
            canvas.drawPath(topClaw, clawPaint);
            canvas.drawPath(topClaw, clawRim);
            canvas.drawPath(botClaw, clawPaint);
            canvas.drawPath(botClaw, clawRim);
          } else {
            // Thundering vertical waterfall pillar + cresting foam splash
            final reachH = min(1.0, t / 0.55);
            final topY = defenderCenter.dy - 120;
            final curBot = topY + (defenderCenter.dy + 18 - topY) * reachH;
            for (final sign in [-1.0, 0.0, 1.0]) {
              canvas.drawLine(
                Offset(defenderCenter.dx + sign * 10, topY),
                Offset(defenderCenter.dx + sign * 10, curBot),
                Paint()
                  ..color = (sign == 0.0 ? Colors.white : const Color(0xFF1E88E5)).withOpacity(0.85 * fade)
                  ..strokeWidth = (sign == 0.0 ? 8.0 : 12.0) * fade
                  ..strokeCap = StrokeCap.round,
              );
            }
          }
          if (t > 0.38) {
            final st = (t - 0.38) / 0.62;
            for (int f = 0; f < 8; f++) {
              final ang = (f / 8) * pi * 2;
              final fp = defenderCenter + Offset(cos(ang) * st * 44, 10 + sin(ang) * st * 22);
              canvas.drawCircle(fp, 6 * fade, Paint()..color = Colors.cyanAccent.withOpacity(0.8 * fade));
            }
          }
        }
        break;

      case 'aurora_beam':
      case 'ice_beam':
        {
          final isAurora = moveId == 'aurora_beam';
          final beamColors = isAurora
              ? [Colors.pinkAccent, Colors.amberAccent, Colors.lightGreenAccent, Colors.cyanAccent, Colors.purpleAccent]
              : [Colors.cyanAccent, Colors.white, Colors.lightBlueAccent];
          final reachBeam = min(1.0, t / 0.62);
          for (int c = 0; c < beamColors.length; c++) {
            final path = Path();
            final lane = (c - (beamColors.length - 1) / 2.0) * 4.5;
            for (int seg = 0; seg <= 12; seg++) {
              final f = (seg / 12.0) * reachBeam;
              final ripple = isAurora ? sin(f * pi * 4 + t * 14 + c) * 6.0 : 0.0;
              final pt = Offset.lerp(attackerCenter, defenderCenter, f)! + perp * (lane + ripple);
              if (seg == 0) {
                path.moveTo(pt.dx, pt.dy);
              } else {
                path.lineTo(pt.dx, pt.dy);
              }
            }
            canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = (isAurora ? 3.5 : 6.0) * fade
                ..strokeCap = StrokeCap.round
                ..color = beamColors[c].withOpacity(0.92 * fade),
            );
          }
          if (t > 0.38) {
            final ct = (t - 0.38) / 0.62;
            for (int k = 0; k < 6; k++) {
              final ang = (k / 6) * pi * 2 + 0.3;
              final kp = defenderCenter + Offset(cos(ang) * (12 + ct * 26), sin(ang) * (10 + ct * 22));
              _drawIceCrystal(canvas, kp, isAurora ? 7.0 : 10.0, ct * 3 + k, fade);
            }
          }
        }
        break;

      case 'spore':
        {
          // Expanding glowing spore cloud + 16 bioluminescent drifting spores + floating Zzz
          canvas.drawCircle(
            defenderCenter,
            18 + sin(t * pi) * 32,
            Paint()..color = Colors.amberAccent.withOpacity(0.18 * fade),
          );
          for (int i = 0; i < 16; i++) {
            final lt = ((t - i * 0.03) / 0.62).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final ang = (i / 16) * pi * 2 + lt * 3.0;
            final r = 10 + sin(lt * pi) * 36.0;
            final pos = defenderCenter + Offset(cos(ang) * r, sin(ang) * r * 0.85 - lt * 22);
            canvas.drawCircle(
              pos,
              (i % 3 == 0 ? 6.0 : 4.5) * fade,
              Paint()..color = (i.isEven ? Colors.yellowAccent : Colors.amberAccent).withOpacity(0.9 * fade),
            );
          }
          if (t > 0.45) {
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
            tp.paint(canvas, defenderCenter + Offset(-12, -32 - (t - 0.45) * 26));
          }
        }
        break;

      case 'hypnosis':
        {
          // Rotating purple Archimedes hypnotic spiral over defender + swinging golden pendulum
          final spiral = Path();
          for (int step = 0; step <= 48; step++) {
            final a = (step / 48.0) * pi * 5 - t * pi * 4;
            final r = (step / 48.0) * 38.0 * min(1.0, t * 1.4);
            final pt = defenderCenter + Offset(cos(a) * r, sin(a) * r * 0.85);
            if (step == 0) {
              spiral.moveTo(pt.dx, pt.dy);
            } else {
              spiral.lineTo(pt.dx, pt.dy);
            }
          }
          canvas.drawPath(
            spiral,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.purpleAccent.withOpacity(0.9 * fade),
          );
          // Swinging golden pendulum above target
          final swing = sin(t * pi * 4) * 24.0;
          final anchor = defenderCenter + const Offset(0, -68);
          final bob = anchor + Offset(swing, 34);
          canvas.drawLine(
            anchor,
            bob,
            Paint()
              ..color = Colors.amberAccent.withOpacity(fade)
              ..strokeWidth = 2.0,
          );
          canvas.drawCircle(bob, 6.5 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
        }
        break;

      case 'lick':
        {
          // Sweeping pink curved tongue with center groove + saliva droplets & paralysis sparks
          final sweep = min(1.0, t * 1.5);
          final tongue = Path()
            ..moveTo(defenderCenter.dx - 26, defenderCenter.dy + 20)
            ..quadraticBezierTo(
              defenderCenter.dx - 2,
              defenderCenter.dy - 24 * sweep,
              defenderCenter.dx + 24 * sweep,
              defenderCenter.dy - 14 * sweep,
            );
          canvas.drawPath(
            tongue,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 14 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.pinkAccent.withOpacity(0.92 * fade),
          );
          canvas.drawPath(
            tongue,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.pink.shade100.withOpacity(0.8 * fade),
          );
          for (int d = 0; d < 5; d++) {
            final dp = defenderCenter + Offset((d - 2) * 10.0, -10 + t * 24 + (d % 2) * 8);
            canvas.drawCircle(dp, 3.5 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
          }
        }
        break;

      case 'night_shade':
      case 'shadow_ball':
        {
          final isBall = moveId == 'shadow_ball';
          if (isBall) {
            final travel = min(1.0, t / 0.62);
            final orbPos = Offset.lerp(attackerCenter, defenderCenter, travel)!;
            // Churning black/violet energy orb with orbiting dark tendrils
            canvas.drawCircle(
              orbPos,
              24 * fade,
              Paint()..color = Colors.deepPurpleAccent.withOpacity(0.45 * fade),
            );
            canvas.drawCircle(
              orbPos,
              17 * fade,
              Paint()..color = const Color(0xFF1A0033).withOpacity(0.95 * fade),
            );
            canvas.drawCircle(
              orbPos,
              17 * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * fade
                ..color = Colors.purpleAccent.withOpacity(fade),
            );
            for (int w = 0; w < 6; w++) {
              final ang = (w / 6) * pi * 2 + t * 8;
              final wp = orbPos + Offset(cos(ang) * 20, sin(ang) * 20);
              canvas.drawCircle(wp, 4 * fade, Paint()..color = Colors.purpleAccent.withOpacity(0.75 * fade));
            }
            if (t > 0.45) {
              final bt = (t - 0.45) / 0.55;
              canvas.drawCircle(
                defenderCenter,
                16 + bt * 38,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 4.5 * fade
                  ..color = Colors.deepPurpleAccent.withOpacity(fade),
              );
            }
          } else {
            // Night Shade: eerie void vortex + spectral glowing crimson eyes + shadow tendrils
            canvas.drawCircle(
              defenderCenter,
              28 + t * 34,
              Paint()..color = const Color(0xFF1A0033).withOpacity(0.75 * fade),
            );
            for (int r = 0; r < 6; r++) {
              final ang = (r / 6) * pi * 2 + t * 3;
              canvas.drawLine(
                defenderCenter + Offset(cos(ang) * 14, sin(ang) * 14),
                defenderCenter + Offset(cos(ang) * (32 + t * 28), sin(ang) * (32 + t * 28)),
                Paint()
                  ..color = Colors.deepPurpleAccent.withOpacity(fade)
                  ..strokeWidth = 5 * fade
                  ..strokeCap = StrokeCap.round,
              );
            }
            for (final sign in [-1.0, 1.0]) {
              canvas.drawOval(
                Rect.fromCenter(center: attackerCenter + Offset(sign * 12, -16), width: 12, height: 7),
                Paint()..color = Colors.redAccent.withOpacity(fade),
              );
            }
          }
        }
        break;


      // ─── EXPANDED GEN 1 MOVES VFX ─────────────────────────────────────────
      case 'headbutt':
        if (t < 0.6) {
          final surge = t / 0.6;
          final pos = Offset.lerp(attackerCenter, defenderCenter, surge * 0.75)!;
          canvas.drawCircle(pos, 18 * fade, Paint()..color = Colors.white.withOpacity(0.8 * fade));
        } else {
          final imp = (t - 0.6) / 0.4;
          canvas.drawCircle(defenderCenter, (16 + imp * 28) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * fade..color = Colors.white.withOpacity(fade));
          _drawStarPath(canvas, defenderCenter, 20 * fade, 8 * fade, Colors.amberAccent, fade);
        }
        break;

      case 'take_down':
        final surge = min(1.0, t * 1.3);
        final pos = Offset.lerp(attackerCenter, defenderCenter, surge)!;
        canvas.drawCircle(pos, 22 * fade, Paint()..color = Colors.orangeAccent.withOpacity(0.6 * fade));
        canvas.drawLine(attackerCenter, pos, Paint()..color = Colors.white.withOpacity(0.7 * fade)..strokeWidth = 6 * fade);
        if (t > 0.5) {
          canvas.drawCircle(defenderCenter, 26 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(0.5 * fade));
        }
        break;

      case 'stomp':
        final drop = (1.0 - cos(min(1.0, t * 1.4) * pi * 0.5)) * 40.0;
        final footCenter = defenderCenter - Offset(0, 40 - drop);
        final footRect = Rect.fromCenter(center: footCenter, width: 36 * fade, height: 22 * fade);
        canvas.drawOval(footRect, Paint()..color = const Color(0xFF795548).withOpacity(0.85 * fade));
        if (t > 0.5) {
          canvas.drawCircle(defenderCenter, (20 + (t - 0.5) * 35) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.white.withOpacity(fade));
        }
        break;

      case 'mega_punch':
        final punchT = min(1.0, t * 1.5);
        final punchPos = Offset.lerp(attackerCenter, defenderCenter, punchT)!;
        canvas.drawCircle(punchPos, (16 + punchT * 12) * fade, Paint()..color = Colors.amberAccent.withOpacity(0.9 * fade));
        if (t > 0.4) {
          final impT = (t - 0.4) / 0.6;
          for (int i = 0; i < 4; i++) {
            final ang = i * pi * 0.5 + t * 2;
            final spark = defenderCenter + Offset(cos(ang) * impT * 35, sin(ang) * impT * 35);
            _drawStarPath(canvas, spark, 12 * fade, 5 * fade, Colors.yellowAccent, fade);
          }
        }
        break;

      case 'mach_punch':
        for (int i = 0; i < 3; i++) {
          final offT = ((t - i * 0.1) / 0.6).clamp(0.0, 1.0);
          final pos = Offset.lerp(attackerCenter, defenderCenter, offT)! + perp * ((i - 1) * 12.0);
          canvas.drawLine(pos - unit * 18, pos, Paint()..color = Colors.white.withOpacity(0.8 * fade)..strokeWidth = 3 * fade);
          canvas.drawCircle(pos, 8 * fade, Paint()..color = Colors.orangeAccent.withOpacity(fade));
        }
        break;

      case 'fire_punch':
        final fpT = min(1.0, t * 1.4);
        final fPos = Offset.lerp(attackerCenter, defenderCenter, fpT)!;
        canvas.drawCircle(fPos, 18 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(0.9 * fade));
        canvas.drawCircle(fPos, 10 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
        if (t > 0.4) {
          for (int i = 0; i < 6; i++) {
            final ang = i * pi / 3 + t * 4;
            final spark = defenderCenter + Offset(cos(ang) * (t - 0.4) * 45, sin(ang) * (t - 0.4) * 45);
            canvas.drawCircle(spark, 5 * fade, Paint()..color = Colors.deepOrange.withOpacity(fade));
          }
        }
        break;

      case 'ice_punch':
        final ipT = min(1.0, t * 1.4);
        final iPos = Offset.lerp(attackerCenter, defenderCenter, ipT)!;
        canvas.drawCircle(iPos, 18 * fade, Paint()..color = Colors.cyanAccent.withOpacity(0.85 * fade));
        if (t > 0.4) {
          _drawIceCrystal(canvas, defenderCenter, 28 * fade, t * 2, fade);
        }
        break;

      case 'thunder_punch':
        final tpT = min(1.0, t * 1.4);
        final tPos = Offset.lerp(attackerCenter, defenderCenter, tpT)!;
        canvas.drawCircle(tPos, 18 * fade, Paint()..color = Colors.yellowAccent.withOpacity(0.9 * fade));
        if (t > 0.3) {
          _drawLightningBolt(canvas, tPos - const Offset(15, 15), defenderCenter, fade, 4.0);
          _drawLightningBolt(canvas, tPos + const Offset(15, -15), defenderCenter, fade, 4.0);
        }
        break;

      case 'mega_kick':
      case 'jump_kick':
      case 'high_jump_kick':
      case 'rolling_kick':
        final sweep = sin(t * pi);
        final arcPos = defenderCenter + perp * (sweep * 35.0);
        canvas.drawLine(attackerCenter, arcPos, Paint()..color = Colors.orangeAccent.withOpacity(0.8 * fade)..strokeWidth = 6 * fade);
        canvas.drawCircle(defenderCenter, (14 + sweep * 22) * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
        _drawStarPath(canvas, defenderCenter, 22 * fade, 9 * fade, Colors.white, fade, points: 6, rotation: t * pi);
        break;

      case 'close_combat':
        for (int i = 0; i < 6; i++) {
          final strikeT = ((t - i * 0.08) / 0.45).clamp(0.0, 1.0);
          if (strikeT <= 0) continue;
          final ang = i * 1.1;
          final offset = Offset(cos(ang) * 22, sin(ang) * 22);
          final strikePos = defenderCenter + offset;
          canvas.drawLine(strikePos - offset * 0.8, strikePos,
              Paint()..color = (i.isEven ? Colors.redAccent : Colors.amberAccent).withOpacity(fade)..strokeWidth = 4 * fade);
          _drawStarPath(canvas, strikePos, 12 * fade, 5 * fade, Colors.white, fade);
        }
        break;

      case 'hyper_beam':
        final beamWidth = 24.0 * sin(t * pi);
        final pCore = Paint()..color = Colors.white.withOpacity(0.95 * fade)..strokeWidth = beamWidth * 0.5..strokeCap = StrokeCap.round;
        final pGlow = Paint()..color = Colors.amberAccent.withOpacity(0.85 * fade)..strokeWidth = beamWidth..strokeCap = StrokeCap.round;
        canvas.drawLine(attackerCenter, defenderCenter, pGlow);
        canvas.drawLine(attackerCenter, defenderCenter, pCore);
        for (int i = 1; i <= 3; i++) {
          final ringPos = Offset.lerp(attackerCenter, defenderCenter, (i / 4.0) + (t * 0.25) % 0.25)!;
          canvas.drawCircle(ringPos, (beamWidth * 0.9 * i).clamp(6.0, 36.0),
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.yellowAccent.withOpacity(fade));
        }
        canvas.drawCircle(defenderCenter, (20 + t * 30) * fade, Paint()..color = Colors.yellow.withOpacity(0.5 * fade));
        break;

      case 'tri_attack':
        final tA = min(1.0, t * 1.5);
        final endA = Offset.lerp(attackerCenter, defenderCenter, tA)!;
        // Fire beam (red), Ice beam (cyan), Electric beam (yellow)
        final colors = [Colors.redAccent, Colors.cyanAccent, Colors.yellowAccent];
        for (int i = 0; i < 3; i++) {
          final off = perp * ((i - 1) * 14.0);
          canvas.drawLine(attackerCenter + off, endA + off,
              Paint()..color = colors[i].withOpacity(0.9 * fade)..strokeWidth = 4.5 * fade..strokeCap = StrokeCap.round);
        }
        if (t > 0.45) {
          canvas.drawCircle(defenderCenter, 22 * fade, Paint()..color = Colors.white.withOpacity(fade));
        }
        break;

      case 'flash_cannon':
        final fcT = min(1.0, t * 1.4);
        final fcPos = Offset.lerp(attackerCenter, defenderCenter, fcT)!;
        canvas.drawLine(attackerCenter, fcPos,
            Paint()..color = Colors.blueGrey.shade100.withOpacity(0.95 * fade)..strokeWidth = 14 * fade..strokeCap = StrokeCap.round);
        canvas.drawLine(attackerCenter, fcPos,
            Paint()..color = Colors.white.withOpacity(fade)..strokeWidth = 6 * fade..strokeCap = StrokeCap.round);
        canvas.drawCircle(defenderCenter, 24 * fade, Paint()..color = Colors.lightBlueAccent.withOpacity(0.6 * fade));
        break;

      case 'blizzard':
        for (int i = 0; i < 8; i++) {
          final ang = (i / 8) * pi * 2 + t * 4;
          final r = 20 + t * 50;
          final p = defenderCenter + Offset(cos(ang) * r, sin(ang) * r * 0.5);
          _drawIceCrystal(canvas, p, 10 * fade, t * 5 + i, fade);
        }
        canvas.drawCircle(defenderCenter, 35 * fade, Paint()..color = Colors.lightBlue.withOpacity(0.35 * fade));
        break;

      case 'powder_snow':
        for (int i = 0; i < 10; i++) {
          final lt = ((t - i * 0.05) / 0.6).clamp(0.0, 1.0);
          final p = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * (sin(lt * 10 + i) * 18);
          canvas.drawCircle(p, 4.5 * fade, Paint()..color = Colors.white.withOpacity(0.85 * fade));
        }
        break;

      case 'thunder':
        final skyStart = Offset(defenderCenter.dx + sin(t * 10) * 10, defenderCenter.dy - 120);
        _drawLightningBolt(canvas, skyStart, defenderCenter, fade, 7.0);
        _drawLightningBolt(canvas, skyStart, defenderCenter, fade, 3.5);
        canvas.drawCircle(defenderCenter, (20 + t * 35) * fade,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 5 * fade..color = Colors.yellowAccent.withOpacity(fade));
        break;

      case 'shock_wave':
      case 'discharge':
        for (int i = 0; i < 8; i++) {
          final ang = (i / 8) * pi * 2;
          final rad = 15 + t * 55;
          final p = attackerCenter + Offset(cos(ang) * rad, sin(ang) * rad);
          _drawLightningBolt(canvas, attackerCenter, p, fade, 2.5);
        }
        break;

      case 'sludge':
        for (int i = 0; i < 5; i++) {
          final lt = ((t - i * 0.08) / 0.6).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final arc = sin(lt * pi) * 35;
          final p = Offset.lerp(attackerCenter, defenderCenter, lt)! - Offset(0, arc);
          canvas.drawCircle(p, 10 * fade, Paint()..color = Colors.purple.shade800.withOpacity(fade));
          canvas.drawCircle(p + const Offset(-2, -2), 4 * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
        }
        break;

      case 'toxic':
      case 'poison_gas':
        for (int i = 0; i < 7; i++) {
          final ang = (i / 7) * pi * 2 + t * 3;
          final r = 10 + t * 35;
          final p = defenderCenter + Offset(cos(ang) * r, sin(ang) * r * 0.7);
          canvas.drawCircle(p, (8 + sin(t * 6 + i) * 4) * fade,
              Paint()..color = Colors.purple.shade700.withOpacity(0.6 * fade));
        }
        break;

      case 'acid_armor':
        final aaRect = Rect.fromCenter(center: attackerCenter, width: 45 * fade, height: 60 * fade);
        canvas.drawOval(aaRect, Paint()..color = Colors.deepPurpleAccent.withOpacity(0.45 * fade));
        canvas.drawOval(aaRect,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.purpleAccent.withOpacity(fade));
        break;

      case 'bone_club':
        final bPos = defenderCenter;
        canvas.save();
        canvas.translate(bPos.dx, bPos.dy);
        canvas.rotate(sin(t * pi) * 1.5);
        final bPaint = Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade)..strokeWidth = 6 * fade..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-18, 0), const Offset(18, 0), bPaint);
        canvas.drawCircle(const Offset(-18, -4), 4 * fade, Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
        canvas.drawCircle(const Offset(-18, 4), 4 * fade, Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
        canvas.drawCircle(const Offset(18, -4), 4 * fade, Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
        canvas.drawCircle(const Offset(18, 4), 4 * fade, Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
        canvas.restore();
        break;

      case 'bonemerang':
        final ang = t * pi * 4;
        final radX = dist * 0.5 * sin(t * pi);
        final bPos = Offset.lerp(attackerCenter, defenderCenter, sin(t * pi))! + perp * radX;
        canvas.save();
        canvas.translate(bPos.dx, bPos.dy);
        canvas.rotate(ang);
        final bmPaint = Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade)..strokeWidth = 5 * fade..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), bmPaint);
        canvas.restore();
        break;

      case 'drill_run':
      case 'horn_drill':
        final drillT = min(1.0, t * 1.4);
        final drillPos = Offset.lerp(attackerCenter, defenderCenter, drillT)!;
        for (int i = 0; i < 4; i++) {
          final spin = t * 16 + i * (pi / 2);
          final drillW = (6 + i * 4) * fade;
          final dP = drillPos + perp * (sin(spin) * drillW);
          canvas.drawCircle(dP, 4 * fade, Paint()..color = Colors.grey.shade300.withOpacity(fade));
        }
        canvas.drawCircle(drillPos, 14 * fade, Paint()..color = Colors.amber.withOpacity(0.7 * fade));
        break;

      case 'pin_missile':
        for (int i = 0; i < 6; i++) {
          final pT = ((t - i * 0.08) / 0.5).clamp(0.0, 1.0);
          if (pT <= 0) continue;
          final pPos = Offset.lerp(attackerCenter, defenderCenter, pT)! + perp * ((i.isEven ? 1 : -1) * 8.0);
          canvas.drawLine(pPos - unit * 12, pPos,
              Paint()..color = Colors.limeAccent.withOpacity(fade)..strokeWidth = 2.5 * fade);
        }
        break;

      case 'dragon_rage':
        final drT = min(1.0, t * 1.3);
        final drPos = Offset.lerp(attackerCenter, defenderCenter, drT)!;
        canvas.drawCircle(drPos, (16 + drT * 18) * fade, Paint()..color = Colors.indigoAccent.withOpacity(0.85 * fade));
        canvas.drawCircle(drPos, (8 + drT * 10) * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
        if (t > 0.45) {
          canvas.drawCircle(defenderCenter, 30 * fade, Paint()..color = Colors.purple.withOpacity(0.5 * fade));
        }
        break;

      case 'dragon_claw':
        for (int i = -1; i <= 1; i++) {
          final p1 = defenderCenter + Offset(-24 + i * 14, -28 + t * 15);
          final p2 = defenderCenter + Offset(18 + i * 14, 28 + t * 15);
          canvas.drawLine(p1, p2,
              Paint()..color = Colors.tealAccent.withOpacity(fade)..strokeWidth = 4.5 * fade..strokeCap = StrokeCap.round);
        }
        break;

      case 'dragon_breath':
        for (int i = 0; i < 10; i++) {
          final lt = ((t - i * 0.05) / 0.55).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final cone = sin(lt * pi) * (15 + i * 4);
          final p = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * cone;
          canvas.drawCircle(p, (6 + lt * 10) * fade,
              Paint()..color = (i.isEven ? Colors.indigoAccent : Colors.tealAccent).withOpacity(0.8 * fade));
        }
        break;

      case 'outrage':
        canvas.drawCircle(attackerCenter, (20 + t * 40) * fade,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 5 * fade..color = Colors.redAccent.withOpacity(fade));
        for (int i = -1; i <= 1; i++) {
          final p1 = defenderCenter + Offset(-28, i * 18);
          final p2 = defenderCenter + Offset(28, -i * 18);
          canvas.drawLine(p1, p2,
              Paint()..color = Colors.deepOrangeAccent.withOpacity(fade)..strokeWidth = 5 * fade..strokeCap = StrokeCap.round);
        }
        break;

      case 'ancient_power':
        for (int i = 0; i < 4; i++) {
          final ang = (i / 4) * pi * 2 + t * 2;
          final rockPos = attackerCenter + Offset(cos(ang) * 35, sin(ang) * 35);
          final dest = Offset.lerp(rockPos, defenderCenter, min(1.0, t * 1.6))!;
          _drawPolygonBoulder(canvas, dest, 12 * fade, t * 4 + i, fade);
        }
        break;

      case 'egg_bomb':
        final arc = sin(t * pi) * 45;
        final eggPos = Offset.lerp(attackerCenter, defenderCenter, t)! - Offset(0, arc);
        canvas.drawOval(Rect.fromCenter(center: eggPos, width: 16 * fade, height: 22 * fade),
            Paint()..color = const Color(0xFFFFF9C4).withOpacity(fade));
        if (t > 0.55) {
          canvas.drawCircle(defenderCenter, 24 * fade, Paint()..color = Colors.yellow.withOpacity(0.8 * fade));
        }
        break;

      case 'fire_spin':
        for (int i = 0; i < 8; i++) {
          final ang = (i / 8) * pi * 2 + t * 6;
          final r = 16 + sin(t * 8 + i) * 10;
          final p = defenderCenter + Offset(cos(ang) * r, sin(ang) * r * 0.6);
          canvas.drawCircle(p, 6 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(fade));
          canvas.drawCircle(p, 3 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
        }
        break;

      case 'flame_wheel':
        final wheelPos = Offset.lerp(attackerCenter, defenderCenter, t)!;
        for (int i = 0; i < 6; i++) {
          final ang = (i / 6) * pi * 2 + t * 10;
          final p = wheelPos + Offset(cos(ang) * 18, sin(ang) * 18);
          canvas.drawCircle(p, 7 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(fade));
        }
        canvas.drawCircle(wheelPos, 10 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
        break;

      case 'rest':
        for (int i = 0; i < 3; i++) {
          final zT = (t + i * 0.3) % 1.0;
          final zPos = attackerCenter + Offset(15 + i * 10, -10 - zT * 35);
          canvas.drawCircle(zPos, 5 * (1 - zT) * fade, Paint()..color = Colors.lightBlueAccent.withOpacity(fade));
        }
        canvas.drawCircle(attackerCenter, 25 * fade, Paint()..color = Colors.cyan.withOpacity(0.3 * fade));
        break;

      case 'snore':
        for (int i = 1; i <= 3; i++) {
          final ringR = (i * 15 + t * 30) * fade;
          canvas.drawCircle(attackerCenter, ringR,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5 * fade..color = Colors.white.withOpacity(fade * (1 - t * 0.7)));
        }
        break;

      case 'rollout':
        final rollX = attackerCenter.dx + (defenderCenter.dx - attackerCenter.dx) * t;
        final rollY = defenderCenter.dy + sin(t * pi * 3).abs() * -12;
        _drawPolygonBoulder(canvas, Offset(rollX, rollY), 16 * fade, t * 8, fade);
        break;

      case 'explosion':
        canvas.drawCircle(defenderCenter, (15 + t * 65) * fade,
            Paint()..color = Colors.white.withOpacity(fade));
        canvas.drawCircle(defenderCenter, (20 + t * 50) * fade,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 8 * fade..color = Colors.yellowAccent.withOpacity(fade));
        canvas.drawCircle(defenderCenter, (30 + t * 40) * fade,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * fade..color = Colors.deepOrangeAccent.withOpacity(fade));
        break;

      case 'extreme_speed':
        canvas.drawLine(attackerCenter, defenderCenter,
            Paint()..color = Colors.white.withOpacity(0.9 * fade)..strokeWidth = 10 * fade..strokeCap = StrokeCap.round);
        _drawStarPath(canvas, defenderCenter, 28 * fade, 10 * fade, Colors.amberAccent, fade);
        break;

      case 'seed_bomb':
        for (int i = -1; i <= 1; i++) {
          final arc = sin(t * pi) * (35 + i.abs() * 10);
          final sPos = Offset.lerp(attackerCenter, defenderCenter, t)! + perp * (i * 12.0) - Offset(0, arc);
          canvas.drawCircle(sPos, 6 * fade, Paint()..color = Colors.green.shade800.withOpacity(fade));
        }
        if (t > 0.5) {
          canvas.drawCircle(defenderCenter, 25 * fade, Paint()..color = Colors.lightGreenAccent.withOpacity(0.7 * fade));
        }
        break;

      case 'transform':
        final colors = [Colors.pinkAccent, Colors.purpleAccent, Colors.cyanAccent, Colors.amberAccent];
        for (int i = 0; i < 4; i++) {
          final r = (12 + i * 8 + sin(t * pi) * 10) * fade;
          canvas.drawCircle(attackerCenter, r,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5 * fade..color = colors[i].withOpacity(fade));
        }
        break;

      case 'struggle':
        canvas.drawCircle(defenderCenter, 20 * fade, Paint()..color = Colors.redAccent.withOpacity(fade));
        canvas.drawCircle(attackerCenter, 14 * fade, Paint()..color = Colors.red.withOpacity(0.5 * fade));
        break;

      case 'soft_boiled':
        canvas.drawOval(Rect.fromCenter(center: attackerCenter, width: 30 * fade, height: 42 * fade),
            Paint()..color = const Color(0xFFFFF59D).withOpacity(0.75 * fade));
        canvas.drawCircle(attackerCenter, 24 * fade, Paint()..color = Colors.white.withOpacity(fade * 0.5));
        break;

      case 'light_screen':
        final lsCenter = attackerCenter + unit * 25;
        final lsRect = Rect.fromCenter(center: lsCenter, width: 14 * fade, height: 50 * fade);
        canvas.drawRRect(RRect.fromRectAndRadius(lsRect, const Radius.circular(6)),
            Paint()..color = Colors.lightBlueAccent.withOpacity(0.7 * fade));
        break;

      case 'mega_drain':
      case 'giga_drain':
        for (int i = 0; i < 5; i++) {
          final drainT = ((t - i * 0.1) / 0.6).clamp(0.0, 1.0);
          if (drainT <= 0) continue;
          final pos = Offset.lerp(defenderCenter, attackerCenter, drainT)!;
          canvas.drawCircle(pos, 6 * fade, Paint()..color = Colors.greenAccent.withOpacity(fade));
        }
        break;

      case 'dizzy_punch':
        final dpT = min(1.0, t * 1.4);
        final dpPos = Offset.lerp(attackerCenter, defenderCenter, dpT)!;
        canvas.drawCircle(dpPos, 16 * fade, Paint()..color = Colors.pinkAccent.withOpacity(fade));
        if (t > 0.4) {
          for (int i = 0; i < 3; i++) {
            final ang = i * (pi * 2 / 3) + t * 6;
            final starPos = defenderCenter + Offset(cos(ang) * 22, sin(ang) * 12);
            _drawStarPath(canvas, starPos, 9 * fade, 4 * fade, Colors.yellowAccent, fade);
          }
        }
        break;

      case 'vise_grip':
      case 'guillotine':
        final pinch = (1.0 - sin(min(1.0, t * 1.5) * pi * 0.5)) * 30.0;
        final pPaint = Paint()..color = Colors.blueGrey.shade700.withOpacity(fade)..strokeWidth = 6 * fade..strokeCap = StrokeCap.round;
        // Left jaw
        canvas.drawLine(defenderCenter + Offset(-25 - pinch, -15), defenderCenter + Offset(-pinch * 0.3, 0), pPaint);
        // Right jaw
        canvas.drawLine(defenderCenter + Offset(25 + pinch, -15), defenderCenter + Offset(pinch * 0.3, 0), pPaint);
        if (t > 0.5) {
          _drawStarPath(canvas, defenderCenter, 20 * fade, 7 * fade, Colors.redAccent, fade);
        }
        break;

      case 'zen_headbutt':
        canvas.drawCircle(attackerCenter, 24 * fade, Paint()..color = Colors.purpleAccent.withOpacity(0.5 * fade));
        final zhPos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.5))!;
        canvas.drawCircle(zhPos, 16 * fade, Paint()..color = Colors.deepPurpleAccent.withOpacity(fade));
        if (t > 0.4) {
          canvas.drawCircle(defenderCenter, 28 * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * fade..color = Colors.purpleAccent.withOpacity(fade));
        }
        break;

      case 'sharpen':
      case 'withdraw':
        final sRect = Rect.fromCenter(center: attackerCenter, width: 40 * fade, height: 40 * fade);
        canvas.drawRect(sRect,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.cyanAccent.withOpacity(fade));
        break;

      case 'recover':
        canvas.drawCircle(attackerCenter, (15 + sin(t * pi) * 20) * fade,
            Paint()..color = Colors.greenAccent.withOpacity(0.4 * fade));
        break;

      case 'spike_cannon':
        for (int i = 0; i < 5; i++) {
          final sT = ((t - i * 0.08) / 0.5).clamp(0.0, 1.0);
          if (sT <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, sT)!;
          canvas.drawLine(pos - unit * 10, pos,
              Paint()..color = Colors.white.withOpacity(fade)..strokeWidth = 3 * fade);
        }
        break;

      case 'aqua_jet':
        final ajPos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.4))!;
        canvas.drawOval(Rect.fromCenter(center: ajPos, width: 34 * fade, height: 18 * fade),
            Paint()..color = Colors.cyanAccent.withOpacity(0.85 * fade));
        break;

      case 'iron_head':
        final ihPos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.4))!;
        canvas.drawCircle(ihPos, 18 * fade, Paint()..color = Colors.blueGrey.shade200.withOpacity(fade));
        if (t > 0.4) {
          _drawStarPath(canvas, defenderCenter, 22 * fade, 8 * fade, Colors.white, fade);
        }
        break;

      case 'constrict':
      case 'wrap':
        for (int i = 0; i < 3; i++) {
          final squeeze = sin(t * pi * 2 + i) * 6;
          canvas.drawOval(Rect.fromCenter(center: defenderCenter + Offset(0, (i - 1) * 12.0), width: (28 + squeeze) * fade, height: 12 * fade),
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.amber.shade700.withOpacity(fade));
        }
        break;

      case 'confuse_ray':
        for (int i = 0; i < 2; i++) {
          final sign = i == 0 ? 1 : -1;
          final crT = (t * 1.3).clamp(0.0, 1.0);
          final p = Offset.lerp(attackerCenter, defenderCenter, crT)! + perp * (sin(crT * pi * 3) * 18 * sign);
          canvas.drawCircle(p, 7 * fade, Paint()..color = (i == 0 ? Colors.amberAccent : Colors.purpleAccent).withOpacity(fade));
        }
        break;

      case 'fury_attack':
      case 'double_slap':
      case 'pound':
      case 'slam':
        for (int i = 0; i < 3; i++) {
          final sT = ((t - i * 0.12) / 0.5).clamp(0.0, 1.0);
          if (sT <= 0) continue;
          final strikeP = defenderCenter + Offset((i - 1) * 10.0, (i % 2 == 0 ? 1 : -1) * 8.0);
          _drawStarPath(canvas, strikeP, 14 * fade, 5 * fade, Colors.white, fade);
        }
        break;

      case 'smokescreen':
        for (int i = 0; i < 6; i++) {
          final ang = (i / 6) * pi * 2;
          final r = t * 28;
          final p = defenderCenter + Offset(cos(ang) * r, sin(ang) * r * 0.7);
          canvas.drawCircle(p, 12 * fade, Paint()..color = Colors.blueGrey.shade800.withOpacity(0.7 * fade));
        }
        break;

      case 'comet_punch':
        for (int i = 0; i < 5; i++) {
          final cpT = ((t - i * 0.08) / 0.5).clamp(0.0, 1.0);
          if (cpT <= 0) continue;
          final ang = i * 1.3;
          final pos = defenderCenter + Offset(cos(ang) * 16, sin(ang) * 16);
          canvas.drawCircle(pos, 8 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
          _drawStarPath(canvas, pos, 12 * fade, 5 * fade, Colors.white, fade);
        }
        break;

      case 'seismic_toss':
        final tossY = sin(t * pi) * -50.0;
        final tossPos = defenderCenter + Offset(0, tossY);
        canvas.drawCircle(tossPos, 16 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(fade));
        if (t > 0.6) {
          canvas.drawCircle(defenderCenter, (20 + (t - 0.6) * 40) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 4 * fade..color = Colors.brown.withOpacity(fade));
        }
        break;

      case 'thrash':
        for (int i = 0; i < 4; i++) {
          final thT = ((t - i * 0.1) / 0.5).clamp(0.0, 1.0);
          if (thT <= 0) continue;
          final ang = i * 1.57;
          final p1 = defenderCenter + Offset(cos(ang) * 22, sin(ang) * 22);
          final p2 = defenderCenter - Offset(cos(ang) * 22, sin(ang) * 22);
          canvas.drawLine(p1, p2, Paint()..color = Colors.redAccent.withOpacity(fade)..strokeWidth = 4 * fade);
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

  void _drawStarPath(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    Color color,
    double fade, {
    int points = 5,
    double rotation = 0.0,
  }) {
    final path = Path();
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = rotation - pi / 2 + i * step;
      final pt = center + Offset(cos(a) * r, sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(fade));
  }

  void _drawPolygonBoulder(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    double fade,
  ) {
    final path = Path();
    const sides = 6;
    const offsets = [1.0, 0.85, 1.05, 0.9, 1.08, 0.82];
    for (int i = 0; i < sides; i++) {
      final a = rotation + (i / sides) * pi * 2;
      final r = radius * offsets[i];
      final pt = center + Offset(cos(a) * r, sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFF8D7B68).withOpacity(fade),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF4E342E).withOpacity(fade),
    );
    canvas.drawCircle(
      center + Offset(-radius * 0.25, -radius * 0.25),
      radius * 0.25,
      Paint()..color = const Color(0xFFD7CCC8).withOpacity(0.55 * fade),
    );
  }

  void _drawIceCrystal(
    Canvas canvas,
    Offset center,
    double radius,
    double rotation,
    double fade,
  ) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withOpacity(fade)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final corePaint = Paint()
      ..color = Colors.white.withOpacity(fade)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final a = rotation + (i / 6) * pi * 2;
      final p1 = center + Offset(cos(a) * radius, sin(a) * radius);
      canvas.drawLine(center, p1, paint);
      canvas.drawLine(center, p1, corePaint);
      // Small V barbs
      final mid = center + Offset(cos(a) * radius * 0.6, sin(a) * radius * 0.6);
      for (final side in [-1.0, 1.0]) {
        final bAng = a + side * 0.65;
        canvas.drawLine(
          mid,
          mid + Offset(cos(bAng) * radius * 0.32, sin(bAng) * radius * 0.32),
          corePaint,
        );
      }
    }
  }

  void _drawHeartPath(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.38)
      ..cubicTo(
        center.dx - size * 0.65,
        center.dy - size * 0.05,
        center.dx - size * 0.48,
        center.dy - size * 0.62,
        center.dx,
        center.dy - size * 0.22,
      )
      ..cubicTo(
        center.dx + size * 0.48,
        center.dy - size * 0.62,
        center.dx + size * 0.65,
        center.dy - size * 0.05,
        center.dx,
        center.dy + size * 0.38,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawKobanCoin(
    Canvas canvas,
    Offset center,
    double scale,
    double rotation,
    double fade,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCenter(center: Offset.zero, width: 12 * scale, height: 17 * scale);
    canvas.drawOval(rect, Paint()..color = Colors.amberAccent.withOpacity(fade));
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.orange.shade800.withOpacity(fade),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 5 * scale, height: 2.2 * scale),
      Paint()..color = Colors.brown.withOpacity(fade),
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -4.5), width: 6 * scale, height: 1.5 * scale),
      Paint()..color = Colors.orange.shade900.withOpacity(0.75 * fade),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MoveVfxPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.moveId != moveId ||
      oldDelegate.attackerCenter != attackerCenter ||
      oldDelegate.defenderCenter != defenderCenter;
}
