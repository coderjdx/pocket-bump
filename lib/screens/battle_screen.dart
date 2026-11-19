import 'dart:async';
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
import '../services/pvp_link_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'evolution_screen.dart';

enum _BallAnimPhase {
  none,
  flight,
  absorb,
  bounce,
  wobble,
  locked,
  breakout,
  blocked,
}

class BattleScreen extends StatefulWidget {
  final PokemonInstance opponentPokemon;
  final bool isWild;
  final String? trainerName;
  final String? trainerTitle;
  final String? opponentSpriteId;
  final int prizeMoney;
  final bool preservePartyHpOnExit;
  final List<PokemonInstance>? opponentTeam;
  final String? battleBackgroundAsset;
  final PvpMatchSession? pvpSession;

  const BattleScreen({
    super.key,
    required this.opponentPokemon,
    this.isWild = true,
    this.trainerName,
    this.trainerTitle,
    this.opponentSpriteId,
    this.prizeMoney = 0,
    this.preservePartyHpOnExit = false,
    this.opponentTeam,
    this.battleBackgroundAsset,
    this.pvpSession,
  });

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with TickerProviderStateMixin {
  late Trainer _trainer;
  late PokemonInstance _playerPokemon;
  late PokemonInstance _opponentPokemon;
  late List<PokemonInstance> _opponentParty;
  late List<PokemonInstance> _opponentFullTeam;
  final List<PokemonInstance> _participatedPokemon = [];
  bool _playerWon = false;
  bool _didRecordPvpResult = false;
  int _pvpTurnIndex = 0;

  void _recordPvpBattleOutcomeIfNeeded({required bool playerWon}) {
    final session = widget.pvpSession;
    if (session == null || _didRecordPvpResult) return;
    _didRecordPvpResult = true;
    _trainer.recordPvpMatch(
      peerId: session.peerDeviceId,
      peerName: session.opponentName,
      peerTitle: session.opponentTitle,
      peerSpriteId: session.opponentSpriteId,
      playerWon: playerWon,
    );
  }

  String get _resolvedBattleBackgroundAsset {
    if (widget.battleBackgroundAsset != null) {
      return widget.battleBackgroundAsset!;
    }
    if (widget.isWild) {
      return _opponentPokemon.species.battleBackgroundAsset;
    }
    return 'assets/images/battle_bg_pvp_arena.png';
  }

  void _recordParticipant(PokemonInstance mon) {
    if (!_participatedPokemon.contains(mon)) {
      _participatedPokemon.add(mon);
    }
  }

  late int _displayedPlayerHp;
  late int _displayedOpponentHp;

  String _currentMessage = "";
  bool _isSelectingMove = false;
  bool _isProcessingTurn = true;
  bool _battleEnded = false;
  bool _didHealOnExit = false;
  bool _arenaAssetsReady = false;

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

  // Player Trainer & summon throw states
  bool _showTrainerSprite = true;
  int _trainerPose = 0; // 0 = ready, 1 = windup, 2 = throw
  double _trainerSlideX = 0.0;
  bool _showPlayerPokemon = false;
  double _playerSummonScale = 0.05;
  bool _showSummonBallArc = false;
  bool _showSummonBurst = false;
  String _trainerHeldBallType = 'poke_ball';

  // Opposing Trainer & summon throw states
  bool _showOpponentTrainerSprite = false;
  int _opponentTrainerPose = 0;
  double _opponentTrainerSlideX = 0.0;
  bool _showOpponentPokemon = true;
  double _opponentSummonScale = 1.0;
  bool _showOpponentSummonBallArc = false;
  bool _showOpponentSummonBurst = false;
  bool _showOpponentShinySparkle = false;
  bool _showPlayerShinySparkle = false;
  String _opponentHeldBallType = 'poke_ball';

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
    for (final mon in _trainer.party) {
      mon.clearVolatileBattleState();
    }
    _playerPokemon = _trainer.leadPokemon!;
    _trainerHeldBallType = _playerPokemon.caughtBall;
    _recordParticipant(_playerPokemon);

    _opponentFullTeam =
        (widget.opponentTeam != null && widget.opponentTeam!.isNotEmpty)
            ? List<PokemonInstance>.from(widget.opponentTeam!)
            : [widget.opponentPokemon];
    for (final mon in _opponentFullTeam) {
      mon.clearVolatileBattleState();
    }
    _opponentParty = List<PokemonInstance>.from(_opponentFullTeam);
    final int oppLeadIdx = _opponentParty.indexWhere((p) => !p.isFainted);
    _opponentPokemon =
        _opponentParty.removeAt(oppLeadIdx >= 0 ? oppLeadIdx : 0);
    _opponentHeldBallType = _opponentPokemon.caughtBall;

    if (widget.pvpSession != null) {
      widget.pvpSession!.startListening();
      widget.pvpSession!.onPeerForfeit = () {
        if (!mounted || _battleEnded) return;
        _recordPvpBattleOutcomeIfNeeded(playerWon: true);
        setState(() {
          _playerWon = true;
          _battleEnded = true;
          _isSelectingMove = false;
          _isProcessingTurn = false;
          _currentMessage =
              "${widget.trainerName ?? 'Opponent'} forfeited the Link Battle! You win!";
        });
      };
    }

    if (!widget.isWild) {
      _showOpponentTrainerSprite = true;
      _showOpponentPokemon = false;
      _opponentSummonScale = 0.05;
    }

    _displayedPlayerHp = _playerPokemon.currentHp;
    _displayedOpponentHp = _opponentPokemon.currentHp;

    _currentMessage = widget.isWild
        ? (_opponentPokemon.isShiny
            ? "A shiny wild ${_opponentPokemon.species.name} appeared!"
            : "A wild ${_opponentPokemon.species.name} appeared!")
        : "${widget.trainerName ?? 'Rival Blue'} wants to battle!";

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
      _prepareAndPlayIntro();
    });
  }

  Future<void> _prepareAndPlayIntro() async {
    if (!mounted) return;
    await Future.wait([
      precacheImage(AssetImage(_resolvedBattleBackgroundAsset), context)
          .catchError((_) {}),
      precacheImage(
        AssetImage('assets/images/trainers/${_trainer.avatar.id}_back_0.png'),
        context,
      ).catchError((_) {}),
      if (!widget.isWild && widget.opponentSpriteId != null)
        precacheImage(
          AssetImage(
              'assets/images/trainers/${widget.opponentSpriteId}_front_0.png'),
          context,
        ).catchError((_) {}),
    ]);
    if (!mounted) return;
    setState(() {
      _arenaAssetsReady = true;
    });
    _trainer.markPokemonSeen(_opponentPokemon.species.id);
    _playBattleIntroSummon();
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
      final bool exitedMidPvp = !_battleEnded && widget.pvpSession != null;
      if (exitedMidPvp) {
        widget.pvpSession!.sendForfeit();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (exitedMidPvp) {
          _recordPvpBattleOutcomeIfNeeded(playerWon: false);
        }
        _trainer.resetAllPartyStatStages();
        _trainer.saveProgress();
      });
    }
    widget.pvpSession?.dispose();
    super.dispose();
  }

  void _finishAndExit([bool? playerWon]) {
    final bool won = playerWon ?? _playerWon;
    if (!_didHealOnExit) {
      _didHealOnExit = true;
      if (!_battleEnded && widget.pvpSession != null) {
        widget.pvpSession!.sendForfeit();
        _recordPvpBattleOutcomeIfNeeded(playerWon: false);
      }
      _trainer.resetAllPartyStatStages();
      _trainer.saveProgress();
    }
    if (mounted) {
      Navigator.pop(context, won);
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

  Future<void> _playShinySparkle({required bool isPlayer}) async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      if (isPlayer) {
        _showPlayerShinySparkle = true;
      } else {
        _showOpponentShinySparkle = true;
      }
    });
    await Future.delayed(const Duration(milliseconds: 880));
    if (!mounted) return;
    setState(() {
      if (isPlayer) {
        _showPlayerShinySparkle = false;
      } else {
        _showOpponentShinySparkle = false;
      }
    });
  }

  Future<void> _playBattleIntroSummon() async {
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    if (widget.isWild && _opponentPokemon.isShiny) {
      await _playShinySparkle(isPlayer: false);
      if (!mounted) return;
    }

    if (!widget.isWild) {
      setState(() {
        _currentMessage =
            "${widget.trainerName ?? 'Trainer'} sent out ${_opponentPokemon.species.name}!";
      });
      await _animateOpponentSummonThrow(_opponentPokemon);
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;
    }

    setState(() {
      _currentMessage = "${_trainer.name}: Go! ${_playerPokemon.nickname}!";
    });

    await _animateTrainerSummonThrow(_playerPokemon);
    if (!mounted) return;

    setState(() {
      _isProcessingTurn = false;
    });
  }

  Future<void> _animateOpponentSummonThrow(PokemonInstance mon) async {
    if (!mounted) return;
    setState(() {
      _opponentHeldBallType = mon.caughtBall;
      _showOpponentTrainerSprite = true;
      _opponentTrainerPose = 0;
      _opponentTrainerSlideX = 0.0;
      _showOpponentPokemon = false;
      _opponentSummonScale = 0.05;
      _showOpponentSummonBallArc = false;
      _showOpponentSummonBurst = false;
    });

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      _opponentTrainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 210));
    if (!mounted) return;

    setState(() {
      _opponentTrainerPose = 2;
      _showOpponentSummonBallArc = true;
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    setState(() {
      _opponentTrainerSlideX = 1.2;
    });
    await Future.delayed(const Duration(milliseconds: 370));
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _showOpponentSummonBallArc = false;
      _showOpponentTrainerSprite = false;
      _showOpponentSummonBurst = true;
      _showOpponentPokemon = true;
      _opponentSummonScale = 1.0;
    });
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    setState(() {
      _showOpponentSummonBurst = false;
    });
    if (mon.isShiny) {
      await _playShinySparkle(isPlayer: false);
    }
  }

  Future<void> _animateTrainerSummonThrow(PokemonInstance mon) async {
    if (!mounted) return;
    setState(() {
      _trainerHeldBallType = mon.caughtBall;
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
    if (mon.isShiny) {
      await _playShinySparkle(isPlayer: true);
    }
  }

  Future<void> _performPokemonSwitch(
    PokemonInstance nextMon, {
    required bool forced,
  }) async {
    if (!mounted) return;
    if (widget.pvpSession != null && !forced) {
      await _executePvpTurn(<String, dynamic>{
        'type': 'switch',
        'partyIndex': _trainer.party.indexOf(nextMon),
        'activeMon': nextMon.toJson(),
      });
      return;
    }

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

    _playerPokemon.resetStatStages();
    _opponentPokemon.trappedTurnsRemaining = 0;
    _opponentPokemon.trappedByMoveId = null;
    _opponentPokemon.trappedByMoveName = null;
    _playerKoController.reset();
    _recordParticipant(nextMon);
    setState(() {
      _playerSubmerged = false;
      _visualPlayerFainted = false;
      _playerPokemon = nextMon;
      _displayedPlayerHp = nextMon.currentHp;
      _currentMessage = "${_trainer.name}: Go! ${nextMon.nickname}!";
    });

    await _animateTrainerSummonThrow(nextMon);
    if (!mounted) return;

    if (widget.pvpSession != null && forced) {
      await widget.pvpSession!.sendForcedSwitch(
        turn: _pvpTurnIndex,
        partyIndex: _trainer.party.indexOf(nextMon),
        activeMon: nextMon.toJson(),
      );
      if (!mounted || _battleEnded) return;
      if (_opponentPokemon.isFainted &&
          _opponentParty.any((p) => !p.isFainted)) {
        await _waitForAndSummonPeerForcedSwitch(_pvpTurnIndex);
        if (!mounted || _battleEnded) return;
      }
      setState(() {
        _isProcessingTurn = false;
      });
      return;
    }

    if (!forced) {
      await _runOpponentFreeAttack();
      if (!mounted) return;
      await _checkPostTurnConditions();
    } else {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  Future<void> _runOpponentFreeAttack() async {
    if (_opponentPokemon.isFainted || _opponentPokemon.moves.isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    final rawOppMove =
        _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)];
    final effectiveOppMove =
        BattleEngine.resolveEffectiveMove(_opponentPokemon, rawOppMove) ??
            rawOppMove;
    final events = BattleEngine.executeSingleAttack(
      _opponentPokemon,
      effectiveOppMove,
      _playerPokemon,
      isPlayer: false,
      isWild: widget.isWild,
      playerTrainer: _trainer,
    );
    for (final ev in events) {
      await _playStepEvent(ev);
      if (!mounted) return;
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

    // Confusion self-damage event
    if (event.isSelfDamage) {
      final hurtPlayer = event.isPlayerActor;
      HapticFeedback.mediumImpact();
      setState(() {
        _floatingCallout = "-${event.damageDealt}";
        _calloutOnOpponent = !hurtPlayer;
        _calloutColor = Colors.amberAccent;
        if (hurtPlayer) {
          _playerFlash = true;
          _displayedPlayerHp = event.targetHpAfter;
        } else {
          _opponentFlash = true;
          _displayedOpponentHp = event.targetHpAfter;
        }
      });
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
      await Future.delayed(const Duration(milliseconds: 560));
      if (!mounted) return;
      setState(() {
        _floatingCallout = null;
      });
      return;
    }

    // Status tick (Burn / Poison / Partial Trap / Berry / Leftovers)
    if (event.isStatusTick) {
      final hurtPlayer = !event.isPlayerActor;
      if (event.damageDealt > 0) {
        setState(() {
          _activeMoveId = event.moveId ??
              (event.moveType == PokemonType.fire ? 'status_burn' : 'status_poison');
          _activeVfxType = event.moveType ?? PokemonType.normal;
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
        await Future.delayed(const Duration(milliseconds: 520));
      } else {
        if (event.targetHpAfter > 0 || event.healAmount > 0) {
          setState(() {
            if (event.isPlayerActor) {
              _displayedPlayerHp = event.targetHpAfter;
            } else {
              _displayedOpponentHp = event.targetHpAfter;
            }
            if (event.healAmount > 0) {
              _floatingCallout = "+${event.healAmount} HP";
              _calloutOnOpponent = !event.isPlayerActor;
              _calloutColor = const Color(0xFF34EB8C);
            }
          });
        }
        await Future.delayed(const Duration(milliseconds: 680));
      }
      if (!mounted) return;
      setState(() {
        _activeMoveId = null;
        _activeVfxType = null;
        _floatingCallout = null;
      });
      return;
    }

    // Multi-hit summary toast, recharge message, trap-applied notice, etc.
    if (event.hideMoveVfx || event.isMultiHitSummary) {
      await Future.delayed(Duration(milliseconds: event.isMultiHitSummary ? 620 : 720));
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
      'self_destruct',
      'explosion',
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

    // Standard attack / charge turn / stat / status move
    if (event.moveType != null && !event.isMiss) {
      final isPlayer = event.isPlayerActor;
      final isSelfBuff = event.statChangedLabel != null && event.statTargetIsSelf;
      final bool isSelfEffect =
          isSelfBuff || event.isChargeTurn || event.statTargetIsSelf;
      final moveId = event.moveId ?? event.moveType!.name;
      final isDig = moveId == 'dig';
      final bool isMultiHitStrike = event.hitNumber > 0;

      // Handle Dig Turn 1 submerge vs Turn 2 surface choreography
      if (event.isChargeTurn && event.submergeActorAfter) {
        setState(() {
          if (isPlayer) {
            _playerSubmerged = true;
          } else {
            _opponentSubmerged = true;
          }
        });
        await Future.delayed(const Duration(milliseconds: 240));
        if (!mounted) return;
        setState(() {
          _activeMoveId = moveId;
          _activeVfxType = event.moveType;
          _vfxAttackerIsPlayer = isPlayer;
          _vfxTargetIsSelf = true;
        });
        _vfxController.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 620));
        if (!mounted) return;
        setState(() {
          _activeMoveId = null;
          _activeVfxType = null;
          _playerSubmerged = _playerPokemon.isUnderground;
          _opponentSubmerged = _opponentPokemon.isUnderground;
        });
        return;
      }

      if (event.surfaceActorOnAttack) {
        setState(() {
          if (isPlayer) {
            _playerSubmerged = false;
          } else {
            _opponentSubmerged = false;
          }
        });
      }

      // 1. Move-specific attacker choreography (lunge/leap)
      if (!isSelfEffect) {
        final lunge = _lungeForMove(moveId, isPlayer);
        setState(() {
          if (isPlayer) {
            _playerLungeOffset = lunge;
          } else {
            _opponentLungeOffset = lunge;
          }
        });
        await Future.delayed(Duration(milliseconds: isMultiHitStrike ? 85 : 140));
        if (!mounted) return;
      }

      // 2. Trigger full-arena move-specific VFX
      setState(() {
        _playerLungeOffset = Offset.zero;
        _opponentLungeOffset = Offset.zero;
        _activeMoveId = moveId;
        _activeVfxType = event.moveType;
        _vfxAttackerIsPlayer = isPlayer;
        _vfxTargetIsSelf = isSelfEffect;
      });
      _vfxController.forward(from: 0);

      // Pause briefly so projectile/beam/burrow reaches target before hit flash
      await Future.delayed(Duration(
        milliseconds: isMultiHitStrike ? 150 : (isDig ? 240 : 220),
      ));
      if (!mounted) return;

      // 3. Impact flash, shake, floating callout & HP animation
      final bool calloutOnOpp = isSelfBuff ? !isPlayer : isPlayer;
      final bool isNoEffectHit =
          event.effectiveness == 0.0 && event.moveCategory != MoveCategory.status;
      if (event.damageDealt > 0 ||
          event.healAmount > 0 ||
          isNoEffectHit ||
          event.statChangedLabel != null ||
          event.statusInflictedLabel != null) {
        String? callout;
        Color calloutCol = Colors.white;
        if (isNoEffectHit) {
          callout = "NO EFFECT!";
          calloutCol = Colors.white70;
        } else if (isMultiHitStrike && event.damageDealt > 0) {
          final String hitTag = "HIT ${event.hitNumber}/${event.totalHits}";
          callout = event.isCrit
              ? "CRIT! $hitTag • -${event.damageDealt}"
              : "$hitTag • -${event.damageDealt}";
          calloutCol = event.isCrit
              ? Colors.orangeAccent
              : (event.effectiveness >= 2.0 ? Colors.amberAccent : Colors.white);
        } else if (event.effectiveness >= 2.0) {
          callout = event.isCrit
              ? "CRIT! SUPER EFFECTIVE! -${event.damageDealt}"
              : "SUPER EFFECTIVE! -${event.damageDealt}";
          calloutCol = Colors.amberAccent;
        } else if (event.effectiveness > 0.0 && event.effectiveness < 1.0) {
          callout = event.isCrit
              ? "CRIT! NOT VERY EFFECTIVE -${event.damageDealt}"
              : "NOT VERY EFFECTIVE -${event.damageDealt}";
          calloutCol = const Color(0xFF90CAF9);
        } else if (event.isCrit) {
          callout = "CRITICAL HIT! -${event.damageDealt}";
          calloutCol = Colors.orangeAccent;
        } else if (event.damageDealt > 0) {
          callout = "-${event.damageDealt}";
          calloutCol = Colors.white;
        } else if (event.healAmount > 0) {
          callout = "+${event.healAmount} HP";
          calloutCol = const Color(0xFF34EB8C);
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
        } else if (event.healAmount > 0) {
          setState(() {
            if (isPlayer) {
              _displayedPlayerHp = event.targetHpAfter;
            } else {
              _displayedOpponentHp = event.targetHpAfter;
            }
            _floatingCallout = callout;
            _calloutOnOpponent = !isPlayer;
            _calloutColor = calloutCol;
          });
        } else {
          setState(() {
            _floatingCallout = callout;
            _calloutOnOpponent = calloutOnOpp;
            _calloutColor = calloutCol;
          });
        }
      }

      await Future.delayed(Duration(milliseconds: isMultiHitStrike ? 130 : 200));
      if (!mounted) return;
      setState(() {
        _playerFlash = false;
        _opponentFlash = false;
        _playerSubmerged = _playerPokemon.isUnderground;
        _opponentSubmerged = _opponentPokemon.isUnderground;
      });
      await Future.delayed(Duration(
        milliseconds: isMultiHitStrike ? 150 : (event.isChargeTurn ? 420 : 620),
      ));
      if (!mounted) return;
      setState(() {
        _activeMoveId = null;
        _activeVfxType = null;
        _floatingCallout = null;
      });
    } else {
      if (event.surfaceActorOnAttack) {
        setState(() {
          _playerSubmerged = _playerPokemon.isUnderground;
          _opponentSubmerged = _opponentPokemon.isUnderground;
        });
      }
      await Future.delayed(const Duration(milliseconds: 780));
    }
  }

  Future<void> _executeForcedPlayerTurn() async {
    if (_isProcessingTurn ||
        _battleEnded ||
        !_playerPokemon.hasForcedTurnAction) {
      return;
    }
    final String? forcedId = _playerPokemon.forcedMoveId;
    if (widget.pvpSession != null) {
      await _executePvpTurn(<String, dynamic>{
        'type': 'fight',
        'moveId': forcedId ??
            (_playerPokemon.moves.isNotEmpty
                ? _playerPokemon.moves.first.id
                : 'tackle'),
      });
      return;
    }

    final Move? fallbackMove = _playerPokemon.moves.isNotEmpty
        ? _playerPokemon.moves.first
        : PokedexDatabase.moves['tackle']?.copy();
    final Move? effectiveMove =
        BattleEngine.resolveEffectiveMove(_playerPokemon, fallbackMove) ??
            fallbackMove;
    if (effectiveMove == null) return;

    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
    });

    final opponentMove = _opponentPokemon.moves.isNotEmpty
        ? _opponentPokemon.moves[Random().nextInt(_opponentPokemon.moves.length)]
        : null;

    final events = BattleEngine.resolveTurn(
      playerMon: _playerPokemon,
      playerAction: BattleAction.fight(effectiveMove),
      opponentMon: _opponentPokemon,
      opponentAction: opponentMove != null
          ? BattleAction.fight(opponentMove)
          : BattleAction.run(),
      isWild: widget.isWild,
      playerTrainer: _trainer,
    );

    for (final event in events) {
      await _playStepEvent(event);
      if (!mounted) return;
    }

    await _checkPostTurnConditions();
  }

  Future<void> _onMoveSelected(Move move) async {
    if (_isProcessingTurn || _battleEnded) return;
    if (_playerPokemon.hasForcedTurnAction) {
      await _executeForcedPlayerTurn();
      return;
    }
    if (move.currentPp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${move.name} has no PP left!")),
      );
      return;
    }

    if (widget.pvpSession != null) {
      await _executePvpTurn(<String, dynamic>{
        'type': 'fight',
        'moveId': move.id,
      });
      return;
    }

    // Scaling Disobedience Check
    final double disobeyChance = _trainer.getDisobedienceChance(_playerPokemon.level);
    if (disobeyChance > 0 && Random().nextDouble() < disobeyChance) {
      final roll = Random().nextInt(100);
      if (roll < 30) {
        // 1. Loafing around (skip turn)
        setState(() {
          _isSelectingMove = false;
          _isProcessingTurn = true;
          _currentMessage = "${_playerPokemon.nickname} is loafing around!";
        });
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        await _runOpponentFreeAttack();
        if (!mounted) return;
        await _checkPostTurnConditions();
        return;
      } else if (roll < 55) {
        // 2. Ignoring commands (skip turn)
        setState(() {
          _isSelectingMove = false;
          _isProcessingTurn = true;
          _currentMessage = "${_playerPokemon.nickname} turned away and pretended not to hear!";
        });
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        await _runOpponentFreeAttack();
        if (!mounted) return;
        await _checkPostTurnConditions();
        return;
      } else if (roll < 75) {
        // 3. Napping (inflicts sleep)
        _playerPokemon.status = StatusCondition.sleep;
        setState(() {
          _isSelectingMove = false;
          _isProcessingTurn = true;
          _currentMessage = "${_playerPokemon.nickname} began to nap!";
        });
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        await _runOpponentFreeAttack();
        if (!mounted) return;
        await _checkPostTurnConditions();
        return;
      } else if (roll < 90) {
        // 4. Random move
        final randomMove = _playerPokemon.moves[Random().nextInt(_playerPokemon.moves.length)];
        setState(() {
          _currentMessage = "${_playerPokemon.nickname} ignored orders and used ${randomMove.name} instead!";
        });
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        move = randomMove;
      } else {
        // 5. Confusion self-harm
        final selfDmg = max(1, _playerPokemon.maxHp ~/ 8);
        _playerPokemon.currentHp = (_playerPokemon.currentHp - selfDmg).clamp(0, _playerPokemon.maxHp);
        setState(() {
          _displayedPlayerHp = _playerPokemon.currentHp;
          _isSelectingMove = false;
          _isProcessingTurn = true;
          _currentMessage = "${_playerPokemon.nickname} won't obey and hurt itself in confusion!";
        });
        await Future.delayed(const Duration(milliseconds: 1100));
        if (!mounted) return;
        if (_playerPokemon.isFainted) {
          setState(() {
            _visualPlayerFainted = true;
          });
          await _playerKoController.forward(from: 0.0);
          if (!mounted) return;
          await _checkPostTurnConditions();
          return;
        }
        await _runOpponentFreeAttack();
        if (!mounted) return;
        await _checkPostTurnConditions();
        return;
      }
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
      playerTrainer: _trainer,
    );

    for (final event in events) {
      await _playStepEvent(event);
      if (!mounted) return;
    }

    await _checkPostTurnConditions();
  }

  Future<void> _handleEvolution(PokemonInstance participant) async {
    int nextId = participant.species.evolutionSpeciesId!;
    if (participant.species.id == 133) {
      const eeveelutions = [134, 135, 136];
      nextId = eeveelutions[Random().nextInt(eeveelutions.length)];
    }
    final nextSpecies = PokedexDatabase.species[nextId];
    if (nextSpecies == null) return;

    final bool isActiveOnField = participant == _playerPokemon;
    final bool wasFainted = participant.isFainted;
    final fromSpecies = participant.species;
    final oldName = participant.nickname;

    setState(() {
      if (isActiveOnField) _showEvolutionGlow = true;
      _currentMessage = "What? $oldName is evolving!";
    });

    final List<Move> pendingEvoMoves = [];
    final evoMoves = participant.evolve(
      nextSpecies,
      PokedexDatabase.movesUnlockedAtExactLevel(
        nextSpecies,
        participant.level,
      ),
      pendingMovesOut: pendingEvoMoves,
    );
    if (wasFainted) {
      participant.currentHp = 0;
    }
    _trainer.markPokemonCaught(nextSpecies.id, isShiny: participant.isShiny);
    _trainer.saveProgress();

    await EvolutionScreen.show(
      context,
      fromSpecies: fromSpecies,
      toSpecies: nextSpecies,
      oldNickname: oldName,
      learnedMoves: evoMoves,
      isShiny: participant.isShiny,
    );
    if (!mounted) return;

    setState(() {
      if (isActiveOnField) {
        _showEvolutionGlow = false;
        _displayedPlayerHp = participant.currentHp;
      }
      _currentMessage = "$oldName evolved into ${nextSpecies.name}!";
    });
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    for (final newMove in pendingEvoMoves) {
      setState(() {
        _currentMessage =
            "${participant.nickname} wants to learn ${newMove.name}!";
      });
      await Future.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;

      final outcome = await showMoveLearnDialog(
        context,
        pokemon: participant,
        newMove: newMove,
        recordOnSkip: true,
      );
      if (!mounted) return;
      setState(() {
        if (outcome.learned && outcome.forgottenMove != null) {
          _currentMessage =
              "1, 2, and... Poof! ${participant.nickname} forgot ${outcome.forgottenMove!.name} and learned ${newMove.name}!";
        } else if (outcome.learned) {
          _currentMessage = "${participant.nickname} learned ${newMove.name}!";
        } else {
          _currentMessage =
              "${participant.nickname} did not learn ${newMove.name}.";
        }
      });
      _trainer.saveProgress();
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
    }
  }

  Future<void> _checkPostTurnConditions({int? pvpTurn}) async {
    if (!mounted) return;

    // 1. All party Pokémon fainted -> player immediately loses and gains nothing
    if (!_trainer.hasConsciousPokemon) {
      _playerWon = false;
      _recordPvpBattleOutcomeIfNeeded(playerWon: false);
      setState(() {
        _displayedPlayerHp = 0;
        _visualPlayerFainted = true;
        _currentMessage =
            "${_playerPokemon.nickname} fainted! All of your Pokémon have fainted! You lost the battle.";
        _battleEnded = true;
        _isProcessingTurn = false;
      });
      return;
    }

    if (_opponentPokemon.isFainted) {
      _opponentPokemon.clearVolatileBattleState();
      _playerPokemon.trappedTurnsRemaining = 0;
      _playerPokemon.trappedByMoveId = null;
      _playerPokemon.trappedByMoveName = null;
      _opponentSubmerged = false;
      await _awardExpForOpponent();
      if (!mounted) return;

      if (widget.pvpSession != null) {
        final bool peerHasReserve = _opponentParty.any((p) => !p.isFainted);
        if (peerHasReserve) {
          if (_playerPokemon.isFainted) {
            // Let local player pick and broadcast their replacement first to avoid deadlock.
            setState(() {
              _isProcessingTurn = false;
              _currentMessage =
                  "${_playerPokemon.nickname} fainted! Choose another Pokémon!";
            });
            _openSwitchModal(forced: true);
          } else {
            await _waitForAndSummonPeerForcedSwitch(pvpTurn ?? _pvpTurnIndex);
            if (!mounted || _battleEnded) return;
            setState(() {
              _isProcessingTurn = false;
            });
          }
          return;
        }
      }

      // If trainer has more Pokémon in reserve, summon next Pokémon
      if (widget.pvpSession == null && _opponentParty.isNotEmpty) {
        final nextMon = _opponentParty.removeAt(0);
        setState(() {
          _currentMessage =
              "${widget.trainerName ?? 'Trainer'} is about to send out ${nextMon.nickname}!";
        });
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;

        setState(() {
          _opponentPokemon = nextMon;
          _displayedOpponentHp = _opponentPokemon.currentHp;
          _visualOpponentFainted = false;
          _opponentKoController.reset();
          _currentMessage =
              "${widget.trainerName ?? 'Trainer'} sent out ${_opponentPokemon.nickname}!";
        });
        _trainer.markPokemonSeen(_opponentPokemon.species.id);
        await _animateOpponentSummonThrow(_opponentPokemon);
        if (!mounted) return;

        _participatedPokemon.clear();
        if (!_playerPokemon.isFainted) {
          _recordParticipant(_playerPokemon);
        }

        if (_playerPokemon.isFainted) {
          setState(() {
            _isProcessingTurn = false;
            _currentMessage =
                "${_playerPokemon.nickname} fainted! Choose another Pokémon!";
          });
          _openSwitchModal(forced: true);
        } else {
          setState(() {
            _isProcessingTurn = false;
          });
        }
        return;
      }

      if (widget.isWild) {
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
      } else {
        // Trainer defeated! Award prize money
        final purse = widget.prizeMoney;
        if (purse > 0) {
          _trainer.addMoney(purse);
          _trainer.saveProgress();
          setState(() {
            _currentMessage =
                "You defeated ${widget.trainerName ?? 'the Trainer'}! Received ₽$purse for winning!";
          });
          await Future.delayed(const Duration(milliseconds: 1400));
          if (!mounted) return;
        } else {
          setState(() {
            _currentMessage =
                "You defeated ${widget.trainerName ?? 'the Trainer'}!";
          });
          await Future.delayed(const Duration(milliseconds: 1100));
          if (!mounted) return;
        }
      }

      _playerWon = true;
      _recordPvpBattleOutcomeIfNeeded(playerWon: true);
      if (!mounted) return;
      setState(() {
        _battleEnded = true;
        _isProcessingTurn = false;
      });
    } else if (_playerPokemon.isFainted) {
      _playerPokemon.clearVolatileBattleState();
      _opponentPokemon.trappedTurnsRemaining = 0;
      _opponentPokemon.trappedByMoveId = null;
      _opponentPokemon.trappedByMoveName = null;
      setState(() {
        _playerSubmerged = false;
        _isProcessingTurn = false;
        _currentMessage =
            "${_playerPokemon.nickname} fainted! Choose another Pokémon!";
      });
      _openSwitchModal(forced: true);
    } else {
      setState(() {
        _isProcessingTurn = false;
      });
    }
  }

  Future<void> _onThrowPokeBall(String ballType) async {
    if (widget.isWild && _trainer.isStorageFull) {
      setState(() {
        _currentMessage =
            "Both your Party and all 16 PC Boxes are full (320/320)! Release a Pokémon first.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              "Both your Party and all 16 PC Boxes are full! Release a Pokémon first."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (ballType == 'poke_ball' && _trainer.pokeBalls <= 0) return;
    if (ballType == 'great_ball' && _trainer.greatBalls <= 0) return;
    if (ballType == 'ultra_ball' && _trainer.ultraBalls <= 0) return;

    if (widget.pvpSession != null) {
      setState(() {
        if (ballType == 'poke_ball') _trainer.pokeBalls--;
        if (ballType == 'great_ball') _trainer.greatBalls--;
        if (ballType == 'ultra_ball') _trainer.ultraBalls--;
        _trainer.saveProgress();
        _throwingBallType = ballType;
        _trainerHeldBallType = ballType;
      });
      await _executePvpTurn(<String, dynamic>{
        'type': 'ball',
        'ballType': ballType,
      });
      return;
    }

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

    if (!widget.isWild) {
      HapticFeedback.heavyImpact();
      setState(() {
        _showTrainerSprite = false;
        _showOpponentTrainerSprite = true;
        _opponentTrainerSlideX = 0.0;
        _opponentTrainerPose = 2;
        _catchBallPhase = _BallAnimPhase.blocked;
        _floatingCallout = "BLOCKED!";
        _calloutOnOpponent = true;
        _calloutColor = Colors.redAccent;
        _currentMessage =
            "${widget.trainerName ?? 'The Trainer'} blocked the Poké Ball! Don't be a thief!";
      });
      _arenaShakeController.forward(from: 0);
      _ballPhaseController.duration = const Duration(milliseconds: 420);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;

      setState(() {
        _opponentTrainerSlideX = 1.2;
        _showPokeBallThrow = false;
        _catchBallPhase = _BallAnimPhase.none;
        _floatingCallout = null;
        _showPlayerPokemon = true;
        _playerSummonScale = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;

      setState(() {
        _showOpponentTrainerSprite = false;
      });

      await _runOpponentFreeAttack();
      if (!mounted) return;
      await _checkPostTurnConditions();
      return;
    }

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
      // Snapshot eligible EXP recipients before adding the newly caught Pokémon
      // so it does not take a share of its own capture EXP when EXP Share is ON.
      final List<PokemonInstance> captureExpRecipients = _resolveExpRecipients();

      // Phase 5a: Capture Lock & Golden Stars
      _opponentPokemon.caughtBall = ballType;
      final int? sentToBox = _trainer.addPokemon(_opponentPokemon);
      final itemDrop = ItemDropService.rollDrop(_opponentPokemon.species);
      if (itemDrop != null) {
        _trainer.adjustItemCount(itemDrop.itemId, itemDrop.count);
        _trainer.saveProgress();
      }
      final String boxNote = (sentToBox != null && sentToBox > 0)
          ? "\n${_opponentPokemon.nickname} was sent to PC Box $sentToBox!"
          : "";
      final String dropNote = itemDrop != null
          ? "\n${_opponentPokemon.species.name} dropped ${itemDrop.count > 1 ? '${itemDrop.count}x ' : 'a '}${itemDrop.itemName}!"
          : "";
      HapticFeedback.heavyImpact();
      setState(() {
        _catchBallPhase = _BallAnimPhase.locked;
        _ballButtonGlowColor = Colors.amberAccent;
        _showCaptureLockBurst = true;
        _currentMessage =
            "Gotcha! ${_opponentPokemon.species.name} was caught!";
      });
      _ballPhaseController.duration = const Duration(milliseconds: 520);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      setState(() {
        _ballButtonGlowColor = null;
        _showCaptureLockBurst = false;
      });

      await _awardExpForOpponent(explicitRecipients: captureExpRecipients);
      if (!mounted) return;

      _playerWon = true;
      setState(() {
        _currentMessage =
            "Gotcha! ${_opponentPokemon.species.name} was caught!$boxNote$dropNote";
        _battleEnded = true;
        _isProcessingTurn = false;
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

      await _runOpponentFreeAttack();
      if (!mounted) return;

      await _checkPostTurnConditions();
    }
  }

  List<PokemonInstance> _resolveExpRecipients() {
    final List<PokemonInstance> consciousParticipants = _trainer.expShareEnabled
        ? _trainer.party.where((p) => !p.isFainted).toList()
        : _participatedPokemon.where((p) => !p.isFainted).toList();
    if (consciousParticipants.isEmpty && !_playerPokemon.isFainted) {
      consciousParticipants.add(_playerPokemon);
    }
    return consciousParticipants;
  }

  Future<void> _awardExpForOpponent({
    List<PokemonInstance>? explicitRecipients,
  }) async {
    final List<PokemonInstance> recipients =
        explicitRecipients ?? _resolveExpRecipients();
    if (recipients.isEmpty) return;

    final int expGained = PokemonInstance.calculateBattleExp(
      defeated: _opponentPokemon,
      winnerLevel: _playerPokemon.level,
      isTrainerBattle: !widget.isWild,
    );

    final int share = max(1, expGained ~/ recipients.length);
    setState(() {
      if (recipients.length == 1) {
        _currentMessage = "${recipients.first.nickname} gained $share EXP!";
      } else if (_trainer.expShareEnabled && recipients.length > 3) {
        _currentMessage =
            "All conscious party Pokémon each gained $share EXP (EXP Share)!";
      } else {
        _currentMessage =
            "${recipients.map((p) => p.nickname).join(', ')} each gained $share EXP!";
      }
    });
    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;

    for (final participant in recipients) {
      final levelResult = participant.gainExpWithLearnset(
        share,
        PokedexDatabase.movesUnlockedAtExactLevel,
      );
      if (levelResult.leveledUp) {
        setState(() {
          if (participant == _playerPokemon) {
            _displayedPlayerHp = _playerPokemon.currentHp;
          }
          _currentMessage =
              "${participant.nickname} grew to Level ${participant.level}!";
        });
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;

        for (final moveName in levelResult.learnedMoves) {
          setState(() {
            _currentMessage = "${participant.nickname} learned $moveName!";
          });
          await Future.delayed(const Duration(milliseconds: 950));
          if (!mounted) return;
        }

        for (final newMove in levelResult.pendingMoves) {
          setState(() {
            _currentMessage =
                "${participant.nickname} wants to learn ${newMove.name}!";
          });
          await Future.delayed(const Duration(milliseconds: 550));
          if (!mounted) return;

          final outcome = await showMoveLearnDialog(
            context,
            pokemon: participant,
            newMove: newMove,
            recordOnSkip: true,
          );
          if (!mounted) return;
          setState(() {
            if (outcome.learned && outcome.forgottenMove != null) {
              _currentMessage =
                  "1, 2, and... Poof! ${participant.nickname} forgot ${outcome.forgottenMove!.name} and learned ${newMove.name}!";
            } else if (outcome.learned) {
              _currentMessage = "${participant.nickname} learned ${newMove.name}!";
            } else {
              _currentMessage =
                  "${participant.nickname} did not learn ${newMove.name}.";
            }
          });
          _trainer.saveProgress();
          await Future.delayed(const Duration(milliseconds: 900));
          if (!mounted) return;
        }

        if (participant.checkCanEvolve()) {
          await _handleEvolution(participant);
          if (!mounted) return;
        }
      }
    }
    _trainer.saveProgress();
  }

  String _applyItemEffectToPokemon({
    required String itemId,
    required String itemName,
    required String actorName,
    required PokemonInstance targetMon,
  }) {
    switch (itemId) {
      case 'revive':
        targetMon.currentHp = (targetMon.maxHp / 2).ceil();
        targetMon.status = StatusCondition.none;
        return "$actorName used Revive! ${targetMon.nickname} was revived to half HP!";
      case 'potion':
        final heal = min(20, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$actorName used Potion! ${targetMon.nickname} restored $heal HP.";
      case 'super_potion':
        final heal = min(50, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$actorName used Super Potion! ${targetMon.nickname} restored $heal HP.";
      case 'hyper_potion':
        final heal = min(200, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$actorName used Hyper Potion! ${targetMon.nickname} restored $heal HP.";
      case 'max_potion':
        targetMon.currentHp = targetMon.maxHp;
        return "$actorName used Max Potion! ${targetMon.nickname}'s HP was fully restored!";
      case 'full_restore':
        targetMon.currentHp = targetMon.maxHp;
        targetMon.status = StatusCondition.none;
        return "$actorName used Full Restore! ${targetMon.nickname} fully restored HP and cured status!";
      default:
        targetMon.status = StatusCondition.none;
        return "$actorName used $itemName! ${targetMon.nickname}'s status condition was cured!";
    }
  }

  void _syncPokemonStateFromJson(
    PokemonInstance target,
    Map<String, dynamic> json,
  ) {
    if (json['currentHp'] is num) {
      target.currentHp = (json['currentHp'] as num).toInt().clamp(0, target.maxHp);
    }
    if (json['status'] is String) {
      final statusName = json['status'] as String;
      target.status = StatusCondition.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => target.status,
      );
    }
  }

  PokemonInstance? _resolveOpponentSwitchTarget({
    Map<String, dynamic>? monJson,
    int? partyIndex,
  }) {
    if (_opponentParty.isEmpty) return null;
    final int? speciesId = (monJson?['speciesId'] as num?)?.toInt();
    final String? nick = monJson?['nickname'] as String?;
    final int? level = (monJson?['level'] as num?)?.toInt();

    if (partyIndex != null &&
        partyIndex >= 0 &&
        partyIndex < _opponentFullTeam.length) {
      final candidate = _opponentFullTeam[partyIndex];
      if (!candidate.isFainted &&
          _opponentParty.contains(candidate) &&
          (speciesId == null || candidate.species.id == speciesId)) {
        return candidate;
      }
    }

    for (final mon in _opponentParty) {
      if (!mon.isFainted &&
          (speciesId == null || mon.species.id == speciesId) &&
          (nick == null || mon.nickname == nick) &&
          (level == null || mon.level == level)) {
        return mon;
      }
    }

    for (final mon in _opponentParty) {
      if (!mon.isFainted && (speciesId == null || mon.species.id == speciesId)) {
        return mon;
      }
    }

    return _opponentParty.firstWhere(
      (p) => !p.isFainted,
      orElse: () => _opponentParty.first,
    );
  }

  PokemonInstance _resolveOpponentItemTarget(Map<String, dynamic> action) {
    final String itemId = (action['itemId'] as String?) ?? '';
    final int? targetIdx = (action['targetPartyIndex'] as num?)?.toInt();
    final int? speciesId = (action['targetSpeciesId'] as num?)?.toInt();

    if (itemId == 'revive') {
      if (targetIdx != null &&
          targetIdx >= 0 &&
          targetIdx < _opponentFullTeam.length) {
        final cand = _opponentFullTeam[targetIdx];
        if (cand.isFainted &&
            (speciesId == null || cand.species.id == speciesId)) {
          return cand;
        }
      }
      for (final mon in _opponentFullTeam) {
        if (mon.isFainted &&
            (speciesId == null || mon.species.id == speciesId)) {
          return mon;
        }
      }
      for (final mon in _opponentFullTeam) {
        if (mon.isFainted) return mon;
      }
      return _opponentPokemon;
    }

    if (!_opponentPokemon.isFainted &&
        (speciesId == null || _opponentPokemon.species.id == speciesId)) {
      return _opponentPokemon;
    }
    if (targetIdx != null &&
        targetIdx >= 0 &&
        targetIdx < _opponentFullTeam.length) {
      final cand = _opponentFullTeam[targetIdx];
      if (!cand.isFainted &&
          (speciesId == null || cand.species.id == speciesId)) {
        return cand;
      }
    }
    for (final mon in _opponentFullTeam) {
      if (!mon.isFainted &&
          (speciesId == null || mon.species.id == speciesId)) {
        return mon;
      }
    }
    return _opponentPokemon;
  }

  Move? _resolveMoveForPokemon(PokemonInstance mon, String? moveId) {
    if (moveId != null) {
      for (final m in mon.moves) {
        if (m.id == moveId) return m;
      }
      final fallback = PokedexDatabase.moves[moveId];
      if (fallback != null) return fallback.copy();
    }
    return mon.moves.isNotEmpty ? mon.moves.first : null;
  }

  Future<void> _waitForAndSummonPeerForcedSwitch(int turnNumber) async {
    final session = widget.pvpSession;
    if (session == null || !mounted || _battleEnded) return;
    setState(() {
      _currentMessage =
          "Waiting for ${widget.trainerName ?? 'Opponent'} to send out their next Pokémon...";
    });
    late final Map<String, dynamic> packet;
    try {
      packet = await session.waitForPeerForcedSwitch(turn: turnNumber);
    } catch (_) {
      return;
    }
    if (!mounted || _battleEnded) return;

    final int? partyIdx = (packet['partyIndex'] as num?)?.toInt();
    final rawMon = packet['activeMon'];
    final Map<String, dynamic>? monJson =
        rawMon is Map ? Map<String, dynamic>.from(rawMon) : null;

    final nextMon = _resolveOpponentSwitchTarget(
      monJson: monJson,
      partyIndex: partyIdx,
    );
    if (nextMon == null) return;

    if (!_opponentParty.contains(_opponentPokemon)) {
      _opponentParty.add(_opponentPokemon);
    }
    _opponentPokemon.resetStatStages();
    _opponentParty.remove(nextMon);
    if (monJson != null) {
      _syncPokemonStateFromJson(nextMon, monJson);
    }

    setState(() {
      _opponentPokemon = nextMon;
      _displayedOpponentHp = _opponentPokemon.currentHp;
      _visualOpponentFainted = false;
      _opponentKoController.reset();
      _currentMessage =
          "${widget.trainerName ?? 'Opponent'} sent out ${_opponentPokemon.nickname}!";
    });
    _trainer.markPokemonSeen(_opponentPokemon.species.id);
    await _animateOpponentSummonThrow(_opponentPokemon);
    if (!mounted) return;

    _participatedPokemon.clear();
    if (!_playerPokemon.isFainted) {
      _recordParticipant(_playerPokemon);
    }
  }

  Future<void> _playBlockedBallThrow({
    required String ballType,
    required bool isPlayerActor,
  }) async {
    if (!mounted) return;
    final String ballLabel = ballType.replaceAll('_', ' ').toUpperCase();
    final String thrower =
        isPlayerActor ? _trainer.name : (widget.trainerName ?? 'Opponent');
    final String blocker =
        isPlayerActor ? (widget.trainerName ?? 'The Trainer') : _trainer.name;

    if (isPlayerActor) {
      setState(() {
        _throwingBallType = ballType;
        _trainerHeldBallType = ballType;
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
        _currentMessage = "$thrower threw a $ballLabel!";
      });

      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() => _trainerPose = 1);
      await Future.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;

      setState(() {
        _trainerPose = 2;
        _showPokeBallThrow = true;
        _catchBallPhase = _BallAnimPhase.flight;
      });
      _ballPhaseController.duration = const Duration(milliseconds: 340);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      setState(() => _trainerSlideX = -1.2);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      HapticFeedback.heavyImpact();
      setState(() {
        _showTrainerSprite = false;
        _showOpponentTrainerSprite = true;
        _opponentTrainerSlideX = 0.0;
        _opponentTrainerPose = 2;
        _catchBallPhase = _BallAnimPhase.blocked;
        _floatingCallout = "BLOCKED!";
        _calloutOnOpponent = true;
        _calloutColor = Colors.redAccent;
        _currentMessage = "$blocker blocked the Poké Ball! Don't be a thief!";
      });
      _arenaShakeController.forward(from: 0);
      _ballPhaseController.duration = const Duration(milliseconds: 420);
      _ballPhaseController.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;

      setState(() {
        _opponentTrainerSlideX = 1.2;
        _showPokeBallThrow = false;
        _catchBallPhase = _BallAnimPhase.none;
        _floatingCallout = null;
        _showPlayerPokemon = true;
        _playerSummonScale = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;
      setState(() => _showOpponentTrainerSprite = false);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _floatingCallout = "BLOCKED!";
        _calloutOnOpponent = false;
        _calloutColor = Colors.redAccent;
        _currentMessage =
            "$thrower threw a $ballLabel! $blocker blocked it! Don't be a thief!";
      });
      _arenaShakeController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (!mounted) return;
      setState(() {
        _floatingCallout = null;
      });
    }
  }

  Future<void> _executePvpTurn(Map<String, dynamic> myAction) async {
    final session = widget.pvpSession;
    if (session == null || _battleEnded || !mounted) return;

    final int turnNumber = ++_pvpTurnIndex;
    final int mySeed = Random().nextInt(0x3FFFFFFF);

    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
      _currentMessage =
          "Waiting for ${widget.trainerName ?? 'Opponent'} to choose an action...";
    });

    late final PvpTurnPacket peerPacket;
    try {
      peerPacket = await session.exchangeTurnAction(
        turn: turnNumber,
        mySeed: mySeed,
        action: myAction,
        activeMon: _playerPokemon.toJson(),
      );
    } catch (_) {
      return;
    }
    if (!mounted || _battleEnded) return;

    final int hostSeed = session.isHost ? mySeed : peerPacket.seed;
    final int guestSeed = session.isHost ? peerPacket.seed : mySeed;
    final int sharedSeed =
        (hostSeed ^ guestSeed ^ (turnNumber * 1000003)) & 0x7FFFFFFF;
    final Random orderRng = Random(sharedSeed ^ 0x55AA55AA);
    final Random hostAtkRng = Random(sharedSeed ^ 0x13579BDF);
    final Random guestAtkRng = Random(sharedSeed ^ 0x2468ACE0);

    final List<({bool isPlayer, bool isHost, Map<String, dynamic> action})>
        hostFirstOrder = session.isHost
            ? [
                (isPlayer: true, isHost: true, action: myAction),
                (isPlayer: false, isHost: false, action: peerPacket.action),
              ]
            : [
                (isPlayer: false, isHost: true, action: peerPacket.action),
                (isPlayer: true, isHost: false, action: myAction),
              ];

    // 1. Resolve switches in canonical Host -> Guest order.
    for (final actor in hostFirstOrder) {
      if (!mounted || _battleEnded) return;
      if (actor.action['type'] != 'switch') continue;

      if (actor.isPlayer) {
        final int? idx = (actor.action['partyIndex'] as num?)?.toInt();
        final PokemonInstance? nextMon =
            (idx != null && idx >= 0 && idx < _trainer.party.length)
                ? _trainer.party[idx]
                : null;
        if (nextMon != null && nextMon != _playerPokemon && !nextMon.isFainted) {
          setState(() {
            _currentMessage = "Come back, ${_playerPokemon.nickname}!";
            _playerFlash = true;
            _playerSummonScale = 0.05;
            _showPlayerPokemon = false;
          });
          await Future.delayed(const Duration(milliseconds: 320));
          if (!mounted) return;
          _playerPokemon.resetStatStages();
          _opponentPokemon.trappedTurnsRemaining = 0;
          _opponentPokemon.trappedByMoveId = null;
          _opponentPokemon.trappedByMoveName = null;
          _playerKoController.reset();
          _recordParticipant(nextMon);
          setState(() {
            _playerSubmerged = false;
            _playerFlash = false;
            _visualPlayerFainted = false;
            _playerPokemon = nextMon;
            _displayedPlayerHp = nextMon.currentHp;
            _currentMessage = "${_trainer.name}: Go! ${nextMon.nickname}!";
          });
          await _animateTrainerSummonThrow(nextMon);
          if (!mounted) return;
        }
      } else {
        final rawMon = actor.action['activeMon'];
        final Map<String, dynamic>? monJson =
            rawMon is Map ? Map<String, dynamic>.from(rawMon) : null;
        final int? idx = (actor.action['partyIndex'] as num?)?.toInt();
        final PokemonInstance? nextOpp = _resolveOpponentSwitchTarget(
          monJson: monJson,
          partyIndex: idx,
        );
        if (nextOpp != null && nextOpp != _opponentPokemon && !nextOpp.isFainted) {
          setState(() {
            _currentMessage =
                "${widget.trainerName ?? 'Opponent'} withdrew ${_opponentPokemon.nickname}!";
            _opponentFlash = true;
            _opponentSummonScale = 0.05;
            _showOpponentPokemon = false;
          });
          await Future.delayed(const Duration(milliseconds: 320));
          if (!mounted) return;

          if (!_opponentParty.contains(_opponentPokemon)) {
            _opponentParty.add(_opponentPokemon);
          }
          _opponentPokemon.resetStatStages();
          _playerPokemon.trappedTurnsRemaining = 0;
          _playerPokemon.trappedByMoveId = null;
          _playerPokemon.trappedByMoveName = null;
          _opponentParty.remove(nextOpp);
          if (monJson != null) {
            _syncPokemonStateFromJson(nextOpp, monJson);
          }

          setState(() {
            _opponentSubmerged = false;
            _opponentFlash = false;
            _visualOpponentFainted = false;
            _opponentKoController.reset();
            _opponentPokemon = nextOpp;
            _displayedOpponentHp = nextOpp.currentHp;
            _currentMessage =
                "${widget.trainerName ?? 'Opponent'} sent out ${nextOpp.nickname}!";
          });
          _trainer.markPokemonSeen(nextOpp.species.id);
          await _animateOpponentSummonThrow(nextOpp);
          if (!mounted) return;
        }
      }
    }

    // 2. Resolve bag items and blocked Poké Balls in canonical Host -> Guest order.
    for (final actor in hostFirstOrder) {
      if (!mounted || _battleEnded) return;
      final kind = actor.action['type'];
      if (kind == 'item') {
        final String itemId = (actor.action['itemId'] as String?) ?? '';
        final String itemName = (actor.action['itemName'] as String?) ?? itemId;
        if (actor.isPlayer) {
          final int? targetIdx =
              (actor.action['targetPartyIndex'] as num?)?.toInt();
          final PokemonInstance targetMon =
              (targetIdx != null &&
                      targetIdx >= 0 &&
                      targetIdx < _trainer.party.length)
                  ? _trainer.party[targetIdx]
                  : _playerPokemon;
          final msg = _applyItemEffectToPokemon(
            itemId: itemId,
            itemName: itemName,
            actorName: _trainer.name,
            targetMon: targetMon,
          );
          _trainer.saveProgress();
          setState(() {
            if (targetMon == _playerPokemon) {
              _displayedPlayerHp = _playerPokemon.currentHp;
              _visualPlayerFainted = _playerPokemon.isFainted;
            }
            _currentMessage = msg;
          });
        } else {
          final targetMon = _resolveOpponentItemTarget(actor.action);
          final msg = _applyItemEffectToPokemon(
            itemId: itemId,
            itemName: itemName,
            actorName: widget.trainerName ?? 'Opponent',
            targetMon: targetMon,
          );
          setState(() {
            if (targetMon == _opponentPokemon) {
              _displayedOpponentHp = _opponentPokemon.currentHp;
              _visualOpponentFainted = _opponentPokemon.isFainted;
            }
            _currentMessage = msg;
          });
        }
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
      } else if (kind == 'ball') {
        final String ballType =
            (actor.action['ballType'] as String?) ?? 'poke_ball';
        await _playBlockedBallThrow(
          ballType: ballType,
          isPlayerActor: actor.isPlayer,
        );
        if (!mounted) return;
      }
    }

    // 3. Pre-turn held berries in canonical Host -> Guest order.
    for (final actor in hostFirstOrder) {
      if (!mounted || _battleEnded) return;
      final mon = actor.isPlayer ? _playerPokemon : _opponentPokemon;
      final berryEv = BattleEngine.checkAndConsumeHeldBerry(
        mon,
        isPlayer: actor.isPlayer,
        isWild: false,
      );
      if (berryEv != null) {
        await _playStepEvent(berryEv);
        if (!mounted) return;
      }
    }

    // 4. Resolve Fight moves with deterministic order & seeds (flat PvP rules).
    final Move? rawPlayerMove =
        (myAction['type'] == 'fight' && !_playerPokemon.isFainted)
            ? _resolveMoveForPokemon(
                _playerPokemon,
                myAction['moveId'] as String?,
              )
            : null;
    final Move? rawOppMove =
        (peerPacket.action['type'] == 'fight' && !_opponentPokemon.isFainted)
            ? _resolveMoveForPokemon(
                _opponentPokemon,
                peerPacket.action['moveId'] as String?,
              )
            : null;

    final Move? playerMove = rawPlayerMove != null
        ? BattleEngine.resolveEffectiveMove(_playerPokemon, rawPlayerMove)
        : null;
    final Move? oppMove = rawOppMove != null
        ? BattleEngine.resolveEffectiveMove(_opponentPokemon, rawOppMove)
        : null;

    bool playerGoesFirst = true;
    if (playerMove != null && oppMove != null) {
      final int pPriority = _playerPokemon.needsRecharge ? 0 : playerMove.priority;
      final int oPriority = _opponentPokemon.needsRecharge ? 0 : oppMove.priority;
      if (pPriority != oPriority) {
        playerGoesFirst = pPriority > oPriority;
      } else {
        final int pSpe = _playerPokemon.effectiveSpe;
        final int oSpe = _opponentPokemon.effectiveSpe;
        if (pSpe != oSpe) {
          playerGoesFirst = pSpe > oSpe;
        } else {
          final bool hostFirst = orderRng.nextBool();
          playerGoesFirst = session.isHost ? hostFirst : !hostFirst;
        }
      }
    } else {
      playerGoesFirst = playerMove != null;
    }

    final Random playerAtkRng = session.isHost ? hostAtkRng : guestAtkRng;
    final Random oppAtkRng = session.isHost ? guestAtkRng : hostAtkRng;

    Future<void> runPlayerAttack() async {
      if (playerMove == null ||
          _playerPokemon.isFainted ||
          _opponentPokemon.isFainted) {
        return;
      }
      final events = BattleEngine.executeSingleAttack(
        _playerPokemon,
        playerMove,
        _opponentPokemon,
        isPlayer: true,
        isWild: false,
        playerTrainer: null,
        rng: playerAtkRng,
      );
      for (final ev in events) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
    }

    Future<void> runOppAttack() async {
      if (oppMove == null ||
          _opponentPokemon.isFainted ||
          _playerPokemon.isFainted) {
        return;
      }
      final events = BattleEngine.executeSingleAttack(
        _opponentPokemon,
        oppMove,
        _playerPokemon,
        isPlayer: false,
        isWild: false,
        playerTrainer: null,
        rng: oppAtkRng,
      );
      for (final ev in events) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
    }

    if (playerGoesFirst) {
      await runPlayerAttack();
      if (!mounted) return;
      await runOppAttack();
    } else {
      await runOppAttack();
      if (!mounted) return;
      await runPlayerAttack();
    }
    if (!mounted) return;

    // 5. End-of-turn Burn / Poison / Leftovers in canonical Host -> Guest order.
    if (!_playerPokemon.isFainted && !_opponentPokemon.isFainted) {
      final first = hostFirstOrder.first;
      final firstMon = first.isPlayer ? _playerPokemon : _opponentPokemon;
      final second = hostFirstOrder.last;
      final secondMon = second.isPlayer ? _playerPokemon : _opponentPokemon;

      for (final ev in BattleEngine.processEndOfTurnStatus(
        firstMon,
        opponent: first.isPlayer ? _opponentPokemon : _playerPokemon,
        isPlayer: first.isPlayer,
        isWild: false,
      )) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
      if (!firstMon.isFainted && !secondMon.isFainted) {
        for (final ev in BattleEngine.processEndOfTurnStatus(
          secondMon,
          opponent: second.isPlayer ? _opponentPokemon : _playerPokemon,
          isPlayer: second.isPlayer,
          isWild: false,
        )) {
          await _playStepEvent(ev);
          if (!mounted) return;
        }
      }
    }

    // 6. Post-turn KO / Forced Switch / Victory check.
    await _checkPostTurnConditions(pvpTurn: turnNumber);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_didHealOnExit) {
          _didHealOnExit = true;
          if (!_battleEnded && widget.pvpSession != null) {
            widget.pvpSession!.sendForfeit();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _trainer.resetAllPartyStatStages();
            _trainer.saveProgress();
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0C1018),
        body: SafeArea(
          child: Column(
            children: [
              // ─── COMPACT BATTLE HEADER ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Material(
                        color: const Color(0xFF171E2E),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          onTap: _finishAndExit,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.14),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151C2B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (widget.isWild
                                      ? Colors.greenAccent
                                      : (widget.pvpSession != null
                                          ? Colors.cyanAccent
                                          : Colors.amberAccent))
                                  .withOpacity(0.28),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isWild
                                      ? Colors.greenAccent
                                      : (widget.pvpSession != null
                                          ? Colors.cyanAccent
                                          : Colors.amberAccent),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (widget.isWild
                                              ? Colors.greenAccent
                                              : (widget.pvpSession != null
                                                  ? Colors.cyanAccent
                                                  : Colors.amberAccent))
                                          .withOpacity(0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.isWild
                                      ? "WILD ENCOUNTER"
                                      : (widget.pvpSession != null
                                          ? "VS LINK • ${(widget.trainerName ?? 'TRAINER').toUpperCase()}"
                                          : (widget.trainerTitle?.toUpperCase() ??
                                              "RIVAL FIST-BUMP DUEL")),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFF171E2E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Icon(
                          widget.isWild
                              ? Icons.explore_rounded
                              : (widget.pvpSession != null
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.military_tech_rounded),
                          size: 16,
                          color: widget.isWild
                              ? Colors.greenAccent
                              : (widget.pvpSession != null
                                  ? Colors.cyanAccent
                                  : Colors.amberAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── ARENA / COMBATANTS VIEW ─────────────────────────────────
              Expanded(
                flex: 60,
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
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                            // Habitat / Gym / PVP Pixel-Art Battle Background (pre-cached before summon)
                            Image.asset(
                              _resolvedBattleBackgroundAsset,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.none,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/battle_bg_route.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                                gaplessPlayback: true,
                              ),
                            ),
                            if (!_arenaAssetsReady)
                              Container(color: const Color(0xFF141622)),

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

                            // Opponent Animated Sprite / Opposing Trainer Throw Sprite (Bottom-anchored on distant platform)
                            Positioned(
                              left: oppPlatform.dx - 120,
                              top: oppPlatform.dy - 200,
                              child: SizedBox(
                                width: 240,
                                height: 200,
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (_showOpponentTrainerSprite)
                                      AnimatedSlide(
                                        offset: Offset(_opponentTrainerSlideX, 0),
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeInOutCubic,
                                        child: AnimatedOpacity(
                                          opacity: _showOpponentTrainerSprite ? 1.0 : 0.0,
                                          duration: const Duration(milliseconds: 220),
                                          child: TrainerSpriteWidget(
                                            spriteId: widget.opponentSpriteId ?? 'male_blue',
                                            isBackView: false,
                                            pose: _opponentTrainerPose,
                                            ballColor: _ballTopColor(_opponentHeldBallType),
                                            size: 138,
                                          ),
                                        ),
                                      ),
                                    AnimatedOpacity(
                                      opacity: (_opponentInBall || !_showOpponentPokemon) ? 0.0 : 1.0,
                                      duration: const Duration(milliseconds: 140),
                                      child: AnimatedScale(
                                        scale: _showOpponentPokemon
                                            ? (_opponentCaptureScale * _opponentSummonScale)
                                            : 0.05,
                                        duration: const Duration(milliseconds: 260),
                                        curve: Curves.easeOutBack,
                                        alignment: Alignment.bottomCenter,
                                        child: _buildAnimatedCombatant(
                                          url: _opponentPokemon.spriteUrl,
                                          fallbackUrl:
                                              _opponentPokemon.staticSpriteUrl,
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
                                    if (_showOpponentSummonBurst)
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(begin: 0.0, end: 1.0),
                                        duration: const Duration(milliseconds: 280),
                                        builder: (context, t, _) {
                                          return CustomPaint(
                                            size: const Size(140, 140),
                                            painter: _SummonBurstPainter(progress: t),
                                          );
                                        },
                                      ),
                                    if (_showOpponentShinySparkle)
                                      IgnorePointer(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween<double>(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 880),
                                          builder: (context, t, _) {
                                            return CustomPaint(
                                              size: const Size(156, 156),
                                              painter:
                                                  _ShinySparklePainter(progress: t),
                                            );
                                          },
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
                              left: playerPlatform.dx - 170,
                              top: playerPlatform.dy - 260,
                              child: SizedBox(
                                width: 340,
                                height: 260,
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
                                        alignment: Alignment.bottomCenter,
                                        child: _buildAnimatedCombatant(
                                          url: _playerPokemon.backSpriteUrl,
                                          fallbackUrl:
                                              _playerPokemon.staticBackSpriteUrl,
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

                                    if (_showPlayerShinySparkle)
                                      IgnorePointer(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween<double>(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 880),
                                          builder: (context, t, _) {
                                            return CustomPaint(
                                              size: const Size(184, 184),
                                              painter:
                                                  _ShinySparklePainter(progress: t),
                                            );
                                          },
                                        ),
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
                                      final double atkSize = _vfxAttackerIsPlayer
                                          ? playerSize
                                          : oppSize;
                                      final double defSize = _vfxTargetIsSelf
                                          ? atkSize
                                          : (_vfxAttackerIsPlayer
                                              ? oppSize
                                              : playerSize);
                                      return CustomPaint(
                                        painter: _MoveVfxPainter(
                                          moveId: _activeMoveId!,
                                          moveType: _activeVfxType!,
                                          attackerCenter: atkCenter,
                                          defenderCenter: defCenter,
                                          attackerSize: atkSize,
                                          defenderSize: defSize,
                                          progress: _vfxController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),

                            // Summon Poké Ball arc & ground bounce (Trainer hand -> platform)
                            if (_showSummonBallArc)
                              _buildSummonBallOverlay(
                                platform: playerPlatform,
                                ballType: _trainerHeldBallType,
                                isOpponent: false,
                              ),
                            if (_showOpponentSummonBallArc)
                              _buildSummonBallOverlay(
                                platform: oppPlatform,
                                ballType: _opponentHeldBallType,
                                isOpponent: true,
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

              // ─── RPG BATTLE DIALOGUE STRIP ──────────────────────────────
              Container(
                height: 52,
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A2234),
                      Color(0xFF111723),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isProcessingTurn && !_battleEnded
                        ? Colors.cyanAccent.withOpacity(0.35)
                        : Colors.white.withOpacity(0.16),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: _battleEnded
                            ? (_playerWon
                                ? Colors.amberAccent
                                : Colors.redAccent)
                            : (_isProcessingTurn
                                ? Colors.cyanAccent
                                : Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _currentMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          height: 1.28,
                        ),
                      ),
                    ),
                    if (_isProcessingTurn && !_battleEnded) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ] else if (!_battleEnded) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.white30,
                      ),
                    ],
                  ],
                ),
              ),

              // ─── COMMAND DECK ────────────────────────────────────────────
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: _battleEnded
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151C2C),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: (_playerWon
                                              ? Colors.amberAccent
                                              : Colors.redAccent)
                                          .withOpacity(0.32),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _playerWon
                                            ? Icons.emoji_events_rounded
                                            : Icons.shield_outlined,
                                        color: _playerWon
                                            ? Colors.amberAccent
                                            : Colors.redAccent,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _playerWon
                                              ? "Battle Complete! Ready to proceed."
                                              : "Return and regroup your team.",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _finishAndExit(_playerWon),
                                    icon: Icon(
                                      widget.preservePartyHpOnExit
                                          ? (_playerWon
                                              ? Icons.arrow_forward_rounded
                                              : Icons.close_rounded)
                                          : (_playerWon
                                              ? Icons.check_circle_outline_rounded
                                              : Icons.exit_to_app_rounded),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    label: Text(
                                      widget.preservePartyHpOnExit
                                          ? (_playerWon
                                              ? "CONTINUE GAUNTLET"
                                              : "RETREAT FROM GYM")
                                          : (_playerWon
                                              ? "CONTINUE"
                                              : "RETURN"),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13.5,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.preservePartyHpOnExit
                                          ? (_playerWon
                                              ? Colors.indigo.shade600
                                              : Colors.blueGrey.shade700)
                                          : (_playerWon
                                              ? const Color(0xFFD32F2F)
                                              : const Color(0xFF334155)),
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : AnimatedOpacity(
                          opacity: _isProcessingTurn ? 0.52 : 1.0,
                          duration: const Duration(milliseconds: 160),
                          child: _isSelectingMove
                              ? _buildMoveSelection()
                              : _buildMainActionMenu(),
                        ),
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

  Widget _buildSummonBallOverlay({
    required Offset platform,
    required String ballType,
    bool isOpponent = false,
  }) {
    final Offset start =
        platform + (isOpponent ? const Offset(-26, -88) : const Offset(36, -116));
    final Offset end = platform + Offset(0, isOpponent ? -11 : -14);
    final Offset startFloor =
        platform + (isOpponent ? const Offset(-22, -2) : const Offset(30, -2));
    final Offset endFloor = platform + const Offset(0, -2);
    final double arcHeight = isOpponent ? 36.0 : 48.0;
    final double ballSize = isOpponent ? 24.0 : 30.0;

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
          y = start.dy + (end.dy - start.dy) * u - sin(u * pi) * arcHeight;
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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBallShadow(
              floorPos: floorPos,
              width: (ballSize * 0.8) * shadowFactor,
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
                    ballType: ballType,
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

          case _BallAnimPhase.blocked:
            final t = _ballPhaseController.value;
            ballPos = impactPos + Offset(-t * 95, -sin(t * pi) * 48 + t * 55);
            shadowFloor = oppFloor + Offset(-t * 85, t * 18);
            ballSize = 26.0 * (1.0 - t * 0.25);
            angle = -t * pi * 6;
            phaseFx = Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CaptureLockBurstPainter(
                    center: impactPos,
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
    // Allow horizontal headroom (1.45x) so wide-winged/tail Gen V sprites
    // scale by their canonical height rather than shrinking to fit a square box.
    final spriteImage = Image.network(
      url,
      width: size * 1.45,
      height: size,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.none,
      errorBuilder: (ctx, err, stack) => Image.network(
        fallbackUrl,
        width: size * 1.45,
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

  static const List<double> _grayscaleMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  Widget _buildPartySlotsRow(List<PokemonInstance> team) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (idx) {
        final bool hasMon = idx < team.length;
        final bool isFainted = hasMon && team[idx].isFainted;
        final String ballId = hasMon ? team[idx].caughtBall : 'poke_ball';

        return Container(
          width: 13,
          height: 13,
          margin: EdgeInsets.only(right: idx < 5 ? 2.5 : 0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasMon
                ? (isFainted ? Colors.black54 : Colors.black26)
                : Colors.black38,
            border: Border.all(
              color: hasMon
                  ? (isFainted ? Colors.white24 : Colors.white54)
                  : Colors.white12,
              width: 0.9,
            ),
          ),
          child: !hasMon
              ? null
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isFainted ? 0.35 : 1.0,
                      child: isFainted
                          ? ColorFiltered(
                              colorFilter:
                                  const ColorFilter.matrix(_grayscaleMatrix),
                              child: PokeBallSpriteWidget(
                                ballType: ballId,
                                size: 10.5,
                              ),
                            )
                          : PokeBallSpriteWidget(
                              ballType: ballId,
                              size: 10.5,
                            ),
                    ),
                    if (isFainted)
                      const Icon(
                        Icons.close,
                        size: 11.5,
                        color: Colors.redAccent,
                      ),
                  ],
                ),
        );
      }),
    );
  }

  Widget _buildPokemonInfoCard(
    PokemonInstance mon, {
    required int displayedHp,
    required bool isPlayer,
  }) {
    final int prevLvlExp = (mon.level - 1) * (mon.level - 1) * (mon.level - 1);
    final int nextLvlExp = mon.expForNextLevel;
    final double expProgress = nextLvlExp > prevLvlExp
        ? ((mon.currentExp - prevLvlExp) / (nextLvlExp - prevLvlExp)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 184,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF23232E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mon.isShiny
              ? Colors.amberAccent.withOpacity(0.75)
              : Colors.white24,
          width: mon.isShiny ? 1.4 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (mon.isShiny ? Colors.amberAccent : Colors.black)
                .withOpacity(mon.isShiny ? 0.25 : 0.35),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPlayer && !widget.isWild) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.trainerName ?? 'Trainer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _buildPartySlotsRow(_opponentFullTeam),
              ],
            ),
            const SizedBox(height: 3),
          ] else if (isPlayer) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _trainer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _buildPartySlotsRow(_trainer.party),
              ],
            ),
            const SizedBox(height: 3),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isPlayer &&
                        _trainer.caughtSpeciesIds.contains(mon.species.id)) ...[
                      const PokeBallSpriteWidget(
                        ballType: 'poke_ball',
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (mon.isShiny) ...[
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.amberAccent,
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                    ],
                    Flexible(
                      child: Text(
                        mon.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          HpBar(currentHp: displayedHp, maxHp: mon.maxHp),
          if (isPlayer) ...[
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: expProgress,
                minHeight: 2.5,
                backgroundColor: Colors.black38,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
              ),
            ),
          ],
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
    final bool hasLockedMove = _playerPokemon.hasForcedTurnAction;
    final bool isTrapped = _playerPokemon.trappedTurnsRemaining > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 168;
        final double gap = compact ? 8 : 10;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 204),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          hasLockedMove
                              ? (_playerPokemon.needsRecharge
                                  ? "RECHARGE"
                                  : "CONTINUE")
                              : "FIGHT",
                          hasLockedMove
                              ? _playerPokemon.forcedActionLabel
                              : "Use a move",
                          hasLockedMove
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFE53935),
                          hasLockedMove
                              ? const Color(0xFF9A4D05)
                              : const Color(0xFF991B1B),
                          hasLockedMove
                              ? Icons.bolt_rounded
                              : Icons.flash_on_rounded,
                          hasLockedMove
                              ? _executeForcedPlayerTurn
                              : () => setState(() => _isSelectingMove = true),
                          compact: compact,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildActionButton(
                          "BAG",
                          hasLockedMove ? "Locked in move" : "Items & Balls",
                          const Color(0xFFF59E0B),
                          const Color(0xFF9A4D05),
                          Icons.backpack_rounded,
                          hasLockedMove
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          "Finish ${_playerPokemon.forcedActionLabel} first!"),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : _openBagModal,
                          compact: compact,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          "POKÉMON",
                          hasLockedMove
                              ? "Locked in move"
                              : (isTrapped
                                  ? "Trapped!"
                                  : "Switch party"),
                          const Color(0xFF22C55E),
                          const Color(0xFF0E6E33),
                          Icons.catching_pokemon,
                          (hasLockedMove || isTrapped)
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        hasLockedMove
                                            ? "${_playerPokemon.nickname} is mid-move and cannot switch!"
                                            : "${_playerPokemon.nickname} is trapped by ${_playerPokemon.trappedByMoveName ?? 'the vortex'}!",
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : () => _openSwitchModal(),
                          compact: compact,
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _buildActionButton(
                          "RUN",
                          widget.isWild ? "Escape battle" : "Trainer duel",
                          const Color(0xFF64748B),
                          const Color(0xFF334155),
                          Icons.directions_run_rounded,
                          () {
                            if (!widget.isWild) {
                              setState(() {
                                _currentMessage =
                                    "No! There's no running from a Trainer battle!";
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "No! There's no running from a Trainer battle!"),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            _finishAndExit(false);
                          },
                          compact: compact,
                        ),
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

  Widget _buildMoveSelection() {
    final moves = _playerPokemon.moves;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxHeight < 176;
        final double rowGap = compact ? 7 : 9;
        final double colGap = compact ? 8 : 10;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 214),
            child: Column(
              children: [
                SizedBox(
                  height: compact ? 24 : 28,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Colors.amberAccent.shade200,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            "CHOOSE MOVE",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: const Color(0xFF1A2234),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _isProcessingTurn
                              ? null
                              : () => setState(() => _isSelectingMove = false),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 10,
                                  color: Colors.white70,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "BACK",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.7,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: compact ? 5 : 7),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: moves.isNotEmpty
                                  ? _buildMoveButton(moves[0], compact: compact)
                                  : _buildEmptyMoveSlot(),
                            ),
                            SizedBox(width: colGap),
                            Expanded(
                              child: moves.length > 1
                                  ? _buildMoveButton(moves[1], compact: compact)
                                  : _buildEmptyMoveSlot(),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: rowGap),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: moves.length > 2
                                  ? _buildMoveButton(moves[2], compact: compact)
                                  : _buildEmptyMoveSlot(),
                            ),
                            SizedBox(width: colGap),
                            Expanded(
                              child: moves.length > 3
                                  ? _buildMoveButton(moves[3], compact: compact)
                                  : _buildEmptyMoveSlot(),
                            ),
                          ],
                        ),
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

  Widget _buildEmptyMoveSlot() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131823),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.07),
        ),
      ),
      child: const Center(
        child: Text(
          "—",
          style: TextStyle(
            color: Colors.white12,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMoveButton(Move move, {bool compact = false}) {
    final Color typeColor = move.type.color;
    final bool noPp = move.currentPp <= 0;
    final double eff = move.power > 0
        ? PokemonTypeExtension.getEffectiveness(
            move.type,
            _opponentPokemon.species.types,
          )
        : 1.0;

    String? effLabel;
    Color? effColor;
    if (move.power > 0) {
      if (eff >= 4.0) {
        effLabel = "4×";
        effColor = Colors.amberAccent;
      } else if (eff >= 2.0) {
        effLabel = "2×";
        effColor = Colors.greenAccent;
      } else if (eff == 0.0) {
        effLabel = "0×";
        effColor = Colors.redAccent;
      } else if (eff < 1.0) {
        effLabel = eff <= 0.25 ? "¼×" : "½×";
        effColor = Colors.orangeAccent;
      }
    }

    final Color ppColor = noPp
        ? Colors.redAccent
        : (move.currentPp <= (move.maxPp / 4).ceil()
            ? Colors.amberAccent
            : Colors.white);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(const Color(0xFF182032), typeColor, noPp ? 0.08 : 0.26)!,
              Color.lerp(const Color(0xFF121723), typeColor, noPp ? 0.05 : 0.14)!,
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: noPp ? Colors.white24 : typeColor.withOpacity(0.75),
            width: 1.3,
          ),
          boxShadow: [
            if (!noPp)
              BoxShadow(
                color: typeColor.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: InkWell(
          onTap: _isProcessingTurn ? null : () => _onMoveSelected(move),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4.5,
                color: noPp ? Colors.white24 : typeColor,
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    9,
                    compact ? 6 : 8,
                    9,
                    compact ? 6 : 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              move.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: compact ? 12.5 : 13.5,
                                color: noPp ? Colors.white54 : Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (effLabel != null && effColor != null) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: effColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: effColor.withOpacity(0.75),
                                  width: 0.9,
                                ),
                              ),
                              child: Text(
                                effLabel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: effColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: typeColor.withOpacity(0.28),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: typeColor.withOpacity(0.85),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Text(
                                      move.type.displayName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    move.power > 0
                                        ? "PWR ${move.powerLabel}"
                                        : (move.category == MoveCategory.status
                                            ? "STATUS"
                                            : "—"),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  if (move.isTwoTurnCharge) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        "2T",
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.amberAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${move.currentPp}/${move.maxPp}",
                            style: TextStyle(
                              fontSize: compact ? 10 : 10.5,
                              color: ppColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canUseBattleItemOn(String itemId, PokemonInstance mon) {
    switch (itemId) {
      case 'revive':
        return mon.isFainted;
      case 'potion':
      case 'super_potion':
      case 'hyper_potion':
      case 'max_potion':
        return !mon.isFainted && mon.currentHp < mon.maxHp;
      case 'antidote':
        return !mon.isFainted && mon.status == StatusCondition.poison;
      case 'paralyze_heal':
        return !mon.isFainted && mon.status == StatusCondition.paralysis;
      case 'awakening':
        return !mon.isFainted && mon.status == StatusCondition.sleep;
      case 'burn_heal':
        return !mon.isFainted && mon.status == StatusCondition.burn;
      case 'ice_heal':
        return !mon.isFainted && mon.status == StatusCondition.freeze;
      case 'full_heal':
        return !mon.isFainted && mon.status != StatusCondition.none;
      case 'full_restore':
        return !mon.isFainted &&
            (mon.currentHp < mon.maxHp || mon.status != StatusCondition.none);
      default:
        return false;
    }
  }

  void _openBattleItemTargetModal({
    required String itemId,
    required String itemName,
    required Color itemColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dlgCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "USE ${itemName.toUpperCase()} ON WHICH POKÉMON?",
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(dlgCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _trainer.party.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final mon = _trainer.party[idx];
                    final bool usable = _canUseBattleItemOn(itemId, mon);
                    final bool isActive = mon == _playerPokemon;
                    return InkWell(
                      onTap: usable
                          ? () {
                              Navigator.pop(dlgCtx);
                              _applyBattleItemOnPokemon(
                                itemId: itemId,
                                itemName: itemName,
                                targetMon: mon,
                              );
                            }
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Opacity(
                        opacity: usable ? 1.0 : 0.48,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F2B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: usable
                                  ? itemColor.withOpacity(0.5)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.network(
                                mon.spriteUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, __, ___) => Image.network(
                                  mon.staticSpriteUrl,
                                  width: 42,
                                  height: 42,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.catching_pokemon,
                                    color: Colors.white54,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (mon.isShiny) ...[
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: Colors.amberAccent,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          mon.nickname,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Lv.${mon.level}",
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.cyanAccent
                                                  .withOpacity(0.18),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "ACTIVE",
                                              style: TextStyle(
                                                color: Colors.cyanAccent,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (mon.isFainted) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "FAINTED",
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ] else if (mon.status !=
                                            StatusCondition.none) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _statusColor(mon.status),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              mon.status.shortLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    HpBar(
                                      currentHp: mon.currentHp,
                                      maxHp: mon.maxHp,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: usable ? itemColor : Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  usable ? "SELECT" : "N/A",
                                  style: TextStyle(
                                    color: usable ? Colors.white : Colors.white38,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
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
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _applyBattleItemOnPokemon({
    required String itemId,
    required String itemName,
    required PokemonInstance targetMon,
  }) async {
    _trainer.adjustItemCount(itemId, -1);
    if (widget.pvpSession != null) {
      _trainer.saveProgress();
      await _executePvpTurn(<String, dynamic>{
        'type': 'item',
        'itemId': itemId,
        'itemName': itemName,
        'targetPartyIndex': _trainer.party.indexOf(targetMon),
        'targetSpeciesId': targetMon.species.id,
      });
      return;
    }

    final String effectMsg = _applyItemEffectToPokemon(
      itemId: itemId,
      itemName: itemName,
      actorName: _trainer.name,
      targetMon: targetMon,
    );
    _trainer.saveProgress();

    setState(() {
      _isSelectingMove = false;
      _isProcessingTurn = true;
      if (targetMon == _playerPokemon) {
        _displayedPlayerHp = _playerPokemon.currentHp;
        _visualPlayerFainted = _playerPokemon.isFainted;
      }
      _currentMessage = effectMsg;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await _runOpponentFreeAttack();
    if (!mounted) return;
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
        final rows = <Widget>[];

        // Balls (available in both wild & trainer battles; trainers block throws)
        if (_trainer.pokeBalls > 0) {
          rows.add(_bagRow(
            icon: Icons.catching_pokemon,
            iconColor: Colors.redAccent,
            leadingWidget:
                const PokeBallSpriteWidget(ballType: 'poke_ball', size: 28),
            title: "Poké Ball",
            rarity: "Common",
            subtitle: "x${_trainer.pokeBalls} remaining",
            btnLabel: "THROW",
            btnColor: Colors.redAccent,
            enabled: true,
            onTap: () {
              Navigator.pop(ctx);
              _onThrowPokeBall('poke_ball');
            },
          ));
        }
        if (_trainer.greatBalls > 0) {
          rows.add(_bagRow(
            icon: Icons.catching_pokemon,
            iconColor: Colors.blueAccent,
            leadingWidget:
                const PokeBallSpriteWidget(ballType: 'great_ball', size: 28),
            title: "Great Ball (1.5x)",
            rarity: "Uncommon",
            subtitle: "x${_trainer.greatBalls} remaining",
            btnLabel: "THROW",
            btnColor: Colors.blueAccent,
            enabled: true,
            onTap: () {
              Navigator.pop(ctx);
              _onThrowPokeBall('great_ball');
            },
          ));
        }
        if (_trainer.ultraBalls > 0) {
          rows.add(_bagRow(
            icon: Icons.catching_pokemon,
            iconColor: Colors.amberAccent,
            leadingWidget:
                const PokeBallSpriteWidget(ballType: 'ultra_ball', size: 28),
            title: "Ultra Ball (2.0x)",
            rarity: "Rare",
            subtitle: "x${_trainer.ultraBalls} remaining",
            btnLabel: "THROW",
            btnColor: Colors.amber.shade800,
            enabled: true,
            onTap: () {
              Navigator.pop(ctx);
              _onThrowPokeBall('ultra_ball');
            },
          ));
        }

        // Medicines (only if count > 0; prompts player to pick target Pokémon)
        final medicineDefs = [
          (
            id: 'potion',
            name: 'Potion',
            effect: '+20 HP',
            rarity: 'Common',
            color: Colors.greenAccent,
            btnColor: Colors.green,
            icon: Icons.medical_services,
          ),
          (
            id: 'super_potion',
            name: 'Super Potion',
            effect: '+50 HP',
            rarity: 'Uncommon',
            color: Colors.tealAccent,
            btnColor: Colors.teal.shade700,
            icon: Icons.medical_services,
          ),
          (
            id: 'hyper_potion',
            name: 'Hyper Potion',
            effect: '+200 HP',
            rarity: 'Rare',
            color: Colors.pinkAccent,
            btnColor: Colors.pink.shade700,
            icon: Icons.medical_services,
          ),
          (
            id: 'max_potion',
            name: 'Max Potion',
            effect: 'Full HP',
            rarity: 'Rare',
            color: Colors.lightBlueAccent,
            btnColor: Colors.lightBlue.shade700,
            icon: Icons.medical_services,
          ),
          (
            id: 'revive',
            name: 'Revive',
            effect: 'Revives +50% HP',
            rarity: 'Rare',
            color: Colors.orangeAccent,
            btnColor: Colors.orange.shade800,
            icon: Icons.favorite,
          ),
          (
            id: 'antidote',
            name: 'Antidote',
            effect: 'Cures Poison',
            rarity: 'Common',
            color: Colors.purpleAccent,
            btnColor: Colors.purple,
            icon: Icons.healing,
          ),
          (
            id: 'paralyze_heal',
            name: 'Paralyze Heal',
            effect: 'Cures Paralysis',
            rarity: 'Common',
            color: Colors.amberAccent,
            btnColor: Colors.amber.shade800,
            icon: Icons.bolt,
          ),
          (
            id: 'awakening',
            name: 'Awakening',
            effect: 'Cures Sleep',
            rarity: 'Common',
            color: Colors.lightBlueAccent,
            btnColor: Colors.lightBlue.shade700,
            icon: Icons.alarm,
          ),
          (
            id: 'burn_heal',
            name: 'Burn Heal',
            effect: 'Cures Burn',
            rarity: 'Common',
            color: Colors.deepOrangeAccent,
            btnColor: Colors.deepOrange,
            icon: Icons.local_fire_department,
          ),
          (
            id: 'ice_heal',
            name: 'Ice Heal',
            effect: 'Cures Freeze',
            rarity: 'Common',
            color: Colors.cyanAccent,
            btnColor: Colors.cyan.shade700,
            icon: Icons.ac_unit,
          ),
          (
            id: 'full_heal',
            name: 'Full Heal',
            effect: 'Cures all status',
            rarity: 'Uncommon',
            color: Colors.tealAccent,
            btnColor: Colors.teal.shade700,
            icon: Icons.auto_fix_high,
          ),
          (
            id: 'full_restore',
            name: 'Full Restore',
            effect: '100% HP + Cures status',
            rarity: 'Rare',
            color: const Color(0xFFFF80AB),
            btnColor: Colors.pink.shade700,
            icon: Icons.stars,
          ),
        ];

        for (final med in medicineDefs) {
          final count = _trainer.getItemCount(med.id);
          if (count <= 0) continue;
          final bool anyEligible =
              _trainer.party.any((p) => _canUseBattleItemOn(med.id, p));
          rows.add(_bagRow(
            icon: med.icon,
            iconColor: med.color,
            title: med.name,
            rarity: med.rarity,
            subtitle: "x$count remaining (${med.effect})",
            btnLabel: "USE",
            btnColor: med.btnColor,
            enabled: anyEligible,
            onTap: () {
              Navigator.pop(ctx);
              _openBattleItemTargetModal(
                itemId: med.id,
                itemName: med.name,
                itemColor: med.btnColor,
              );
            },
          ));
        }

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
                  child: rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.inventory_2_outlined,
                                  color: Colors.white24, size: 40),
                              SizedBox(height: 10),
                              Text(
                                "Your Bag is empty!",
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          children: rows,
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
      isScrollControlled: true,
      isDismissible: !forced,
      enableDrag: !forced,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.78;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxSheetHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "SWITCH POKÉMON",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "${_trainer.party.length}/6",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!forced)
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white60, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _trainer.party.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, idx) {
                        final mon = _trainer.party[idx];
                        final bool isCurrent = mon == _playerPokemon;
                        final bool canSwitch = !isCurrent && !mon.isFainted;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? const Color(0xFF283044)
                                : const Color(0xFF1F1F2B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? Colors.amberAccent.withOpacity(0.6)
                                  : mon.isFainted
                                      ? Colors.redAccent.withOpacity(0.28)
                                      : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Opacity(
                                opacity: mon.isFainted ? 0.45 : 1.0,
                                child: Image.network(
                                  mon.spriteUrl,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (c, e, s) => Image.network(
                                    mon.staticSpriteUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (c2, e2, s2) => const Icon(
                                      Icons.catching_pokemon,
                                      color: Colors.white54,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        if (mon.isShiny) ...[
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            color: Colors.amberAccent,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Flexible(
                                          child: Text(
                                            mon.nickname,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "Lv.${mon.level}",
                                          style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (mon.isFainted) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "FAINTED",
                                              style: TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ] else if (mon.status !=
                                            StatusCondition.none) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _statusColor(mon.status),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              mon.status.shortLabel,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: HpBar(
                                            currentHp: mon.currentHp,
                                            maxHp: mon.maxHp,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${mon.currentHp}/${mon.maxHp}",
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              isCurrent
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent
                                            .withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.amberAccent
                                                .withOpacity(0.5)),
                                      ),
                                      child: const Text(
                                        "ACTIVE",
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: canSwitch
                                          ? () {
                                              Navigator.pop(ctx);
                                              _performPokemonSwitch(mon,
                                                  forced: forced);
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        "SWITCH",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    Color topColor,
    Color bottomColor,
    IconData icon,
    VoidCallback onPressed, {
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.24),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: bottomColor.withOpacity(0.45),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: _isProcessingTurn ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned(
                right: -8,
                bottom: -10,
                child: Icon(
                  icon,
                  size: compact ? 46 : 56,
                  color: Colors.white.withOpacity(0.11),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 8 : 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 34 : 40,
                      height: compact ? 34 : 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                        ),
                      ),
                      child: Icon(
                        icon,
                        size: compact ? 19 : 22,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: compact ? 9 : 11),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                              fontSize: compact ? 13.5 : 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 9.5 : 10.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

class _ShinySparklePainter extends CustomPainter {
  final double progress;

  _ShinySparklePainter({required this.progress});

  void _drawFourPointStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - r)
      ..quadraticBezierTo(
          center.dx + r * 0.16, center.dy - r * 0.16, center.dx + r, center.dy)
      ..quadraticBezierTo(
          center.dx + r * 0.16, center.dy + r * 0.16, center.dx, center.dy + r)
      ..quadraticBezierTo(
          center.dx - r * 0.16, center.dy + r * 0.16, center.dx - r, center.dy)
      ..quadraticBezierTo(
          center.dx - r * 0.16, center.dy - r * 0.16, center.dx, center.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.52);
    final fade = t < 0.2 ? (t / 0.2) : (1.0 - ((t - 0.2) / 0.8)).clamp(0.0, 1.0);

    // Subtle expanding prismatic golden aura ring
    final ringRadius = size.width * (0.18 + t * 0.34);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * fade
        ..color = Colors.amberAccent.withOpacity(0.65 * fade),
    );

    const colors = [
      Colors.amberAccent,
      Colors.white,
      Colors.cyanAccent,
      Color(0xFFFFD54F),
    ];

    // Orbiting 4-point diamond stars bursting outward cleanly
    for (int i = 0; i < 8; i++) {
      final baseAngle = (i / 8) * pi * 2 + t * 1.4;
      final dist = size.width * (0.14 + Curves.easeOut.transform(t) * 0.36);
      final starCenter =
          center + Offset(cos(baseAngle) * dist, sin(baseAngle) * dist * 0.82);
      final starScale = sin(t * pi).clamp(0.0, 1.0);
      final starRadius = ((i.isEven ? 12.0 : 8.5) * starScale).clamp(0.0, 16.0);
      if (starRadius > 0.5) {
        _drawFourPointStar(
          canvas,
          starCenter,
          starRadius,
          Paint()..color = colors[i % colors.length].withOpacity(0.95 * fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShinySparklePainter oldDelegate) =>
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
  static const Set<String> _bodyAnchoredMoves = {
    'swords_dance',
    'harden',
    'agility',
    'tail_whip',
    'splash',
    'glare',
    'dig',
    'absorb',
    'mega_drain',
    'giga_drain',
    'dream_eater',
    'mimic',
    'night_shade',
    'discharge',
    'acid_armor',
    'ancient_power',
    'flame_wheel',
    'rest',
    'rollout',
    'explosion',
    'self_destruct',
    'transform',
    'struggle',
    'soft_boiled',
    'light_screen',
    'reflect',
    'sharpen',
    'withdraw',
    'recover',
    'counter',
    'double_edge',
    'double_team',
    'metronome',
    'rage',
    'skull_bash',
    'sky_attack',
    'substitute',
    'teleport',
    'surf',
    'outrage',
    'quick_attack',
    'extreme_speed',
    'aqua_jet',
    'take_down',
  };

  final String moveId;
  final PokemonType moveType;
  final Offset attackerCenter;
  final Offset defenderCenter;
  final double attackerSize;
  final double defenderSize;
  final double progress;

  _MoveVfxPainter({
    required this.moveId,
    required this.moveType,
    required this.attackerCenter,
    required this.defenderCenter,
    this.attackerSize = 140.0,
    this.defenderSize = 140.0,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final fade = (1.0 - max(0.0, (t - 0.72) / 0.28)).clamp(0.0, 1.0);
    final rawDir = defenderCenter - attackerCenter;
    final bool isSelfTarget = rawDir.distance < 2.0;
    final Offset baseDir = isSelfTarget
        ? ((attackerCenter.dy > size.height * 0.5)
            ? const Offset(150, -120)
            : const Offset(-150, 120))
        : rawDir;
    final double baseDist = max(1.0, baseDir.distance);
    final Offset baseUnit = baseDir / baseDist;

    // Position ranged projectiles, beams, breath attacks, and strikes cleanly
    // in front of the user rather than emerging from its torso center.
    final bool useLaunchOrigin =
        !isSelfTarget && !_bodyAnchoredMoves.contains(moveId);
    final double leadDist =
        min(baseDist * 0.28, max(28.0, attackerSize * 0.36));
    final Offset mouthLift = Offset(0, -min(16.0, attackerSize * 0.08));
    final Offset origin = useLaunchOrigin
        ? (attackerCenter + baseUnit * leadDist + mouthLift)
        : attackerCenter;

    final Offset dir = isSelfTarget ? baseDir : (defenderCenter - origin);
    final double dist = max(1.0, dir.distance);
    final Offset unit = dir / dist;
    final Offset perp = Offset(-unit.dy, unit.dx);

    _paintMoveVfx(
      canvas,
      size,
      t,
      fade,
      isSelfTarget,
      origin,
      dir,
      dist,
      unit,
      perp,
    );
  }

  void _paintMoveVfx(
    Canvas canvas,
    Size size,
    double t,
    double fade,
    bool isSelfTarget,
    Offset attackerCenter,
    Offset dir,
    double dist,
    Offset unit,
    Offset perp,
  ) {

    switch (moveId) {
      // ─── FIRE MOVES ─────────────────────────────────────────────────────
      case 'ember':
        {
          for (int i = 0; i < 6; i++) {
            final lt = ((t - i * 0.08) / 0.56).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final arc = sin(lt * pi) * (24.0 + i * 5.0) * (i.isEven ? 1.0 : -1.0);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * arc;
            final trail = pos - unit * 12.0;
            canvas.drawCircle(trail, 5.5 * fade,
                Paint()..color = Colors.redAccent.withOpacity(0.55 * fade));
            canvas.drawCircle(pos, 11.5 * (1.0 - lt * 0.25) * fade,
                Paint()..color = Colors.deepOrange.withOpacity(0.9 * fade));
            canvas.drawCircle(pos, 6.0 * fade,
                Paint()..color = Colors.yellowAccent.withOpacity(fade));
          }
          if (t > 0.45) {
            final imp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
            for (int k = 0; k < 6; k++) {
              final ang = (k / 6.0) * pi * 2.0 + t * 5.0;
              final sp = defenderCenter + Offset(cos(ang) * (10.0 + imp * 26.0), sin(ang) * (10.0 + imp * 26.0));
              canvas.drawCircle(sp, 3.5 * (1.0 - imp * 0.5) * fade,
                  Paint()..color = Colors.amberAccent.withOpacity(fade));
            }
          }
        }
        break;

      case 'fire_fang':
        _drawJaws(canvas, defenderCenter, t, fade, Colors.deepOrangeAccent, Colors.yellowAccent);
        break;

      case 'flamethrower':
        {
          final reach = min(1.0, t / 0.48);
          final endTip = Offset.lerp(attackerCenter, defenderCenter, reach)!;
          // Roaring outer crimson/orange jet cone
          for (int i = 0; i < 16; i++) {
            final lt = ((t - i * 0.038) / 0.5).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final wiggle = sin(lt * 16.0 + i * 1.3) * (8.0 + lt * 10.0);
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * wiggle;
            final radius = (8.0 + lt * 18.0) * fade;
            canvas.drawCircle(
              pos,
              radius,
              Paint()
                ..color = (i % 4 == 0
                        ? Colors.yellowAccent
                        : (i.isEven ? Colors.deepOrangeAccent : Colors.redAccent))
                    .withOpacity(0.82 * fade),
            );
          }
          // Bright white-yellow inner flame stream
          canvas.drawLine(
            attackerCenter,
            endTip,
            Paint()
              ..color = Colors.amberAccent.withOpacity(0.6 * fade)
              ..strokeWidth = 10.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.42) {
            final imp = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
            canvas.drawCircle(
              defenderCenter,
              (22.0 + sin(imp * pi * 3.0) * 10.0) * fade,
              Paint()..color = Colors.deepOrange.withOpacity(0.45 * fade),
            );
          }
        }
        break;

      case 'fire_blast':
        {
          if (t < 0.36) {
            final lt = t / 0.36;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
            canvas.drawCircle(pos, 26.0 * fade, Paint()..color = Colors.redAccent.withOpacity(0.65 * fade));
            canvas.drawCircle(pos, 18.0 * fade, Paint()..color = Colors.deepOrangeAccent);
            canvas.drawCircle(pos, 10.0 * fade, Paint()..color = Colors.yellowAccent);
          } else {
            // Iconic blazing Daimonji (大) fire emblem erupting across defender
            final st = ((t - 0.36) / 0.64).clamp(0.0, 1.0);
            final spread = Curves.easeOut.transform(min(1.0, st * 1.4));
            final outerR = (16.0 + spread * 46.0) * fade;
            final pOuter = Paint()
              ..color = Colors.deepOrange.withOpacity(0.85 * fade)
              ..strokeWidth = 14.0 * fade
              ..strokeCap = StrokeCap.round;
            final pMid = Paint()
              ..color = Colors.orangeAccent.withOpacity(0.95 * fade)
              ..strokeWidth = 8.0 * fade
              ..strokeCap = StrokeCap.round;
            final pCore = Paint()
              ..color = Colors.yellowAccent.withOpacity(fade)
              ..strokeWidth = 3.5 * fade
              ..strokeCap = StrokeCap.round;
            final topVert = defenderCenter + Offset(0, -outerR);
            final leftArm = defenderCenter + Offset(-outerR * 0.92, -outerR * 0.16);
            final rightArm = defenderCenter + Offset(outerR * 0.92, -outerR * 0.16);
            final leftLeg = defenderCenter + Offset(-outerR * 0.68, outerR * 0.92);
            final rightLeg = defenderCenter + Offset(outerR * 0.68, outerR * 0.92);
            for (final p in [pOuter, pMid, pCore]) {
              canvas.drawLine(leftArm, rightArm, p);
              canvas.drawLine(topVert, defenderCenter, p);
              canvas.drawLine(defenderCenter, leftLeg, p);
              canvas.drawLine(defenderCenter, rightLeg, p);
            }
            for (final pt in [topVert, leftArm, rightArm, leftLeg, rightLeg, defenderCenter]) {
              canvas.drawCircle(pt, 9.0 * fade, Paint()..color = Colors.yellowAccent.withOpacity(0.8 * fade));
            }
            canvas.drawCircle(
              defenderCenter,
              (28.0 + st * 36.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * fade
                ..color = Colors.orangeAccent.withOpacity(0.65 * fade),
            );
          }
        }
        break;

      // ─── WATER MOVES ────────────────────────────────────────────────────
      case 'water_gun':
        {
          final reach = min(1.0, t / 0.58);
          final endPt = Offset.lerp(attackerCenter, defenderCenter, reach)!;
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = const Color(0xFF0288D1).withOpacity(0.88 * fade)
              ..strokeWidth = 14 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.cyanAccent.withOpacity(0.95 * fade)
              ..strokeWidth = 8 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.white.withOpacity(0.9 * fade)
              ..strokeWidth = 3.2 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.36) {
            final sp = ((t - 0.36) / 0.64).clamp(0.0, 1.0);
            for (int i = 0; i < 10; i++) {
              final ang = (i / 10) * pi * 2 + sp * 1.4;
              final rad = 10 + sp * (i.isEven ? 42 : 28);
              final dp = defenderCenter + Offset(cos(ang) * rad, sin(ang) * rad * 0.78);
              canvas.drawCircle(
                dp,
                (i.isEven ? 5.0 : 3.5) * fade,
                Paint()
                  ..color = (i.isEven ? Colors.cyanAccent : Colors.white)
                      .withOpacity(fade),
              );
            }
          }
        }
        break;

      case 'water_pulse':
        {
          // Phase 1 (0..0.34): Swirling water ribbons condense into a glowing hydro-pulse sphere
          if (t < 0.42) {
            final ct = (t / 0.38).clamp(0.0, 1.0);
            for (int r = 0; r < 3; r++) {
              final ang = t * 14 + r * (pi * 2 / 3);
              final orbitR = (1.0 - ct) * 28.0 + 6.0;
              final pt = attackerCenter + Offset(cos(ang) * orbitR, sin(ang) * orbitR * 0.7);
              canvas.drawCircle(
                pt,
                (6.5 - r) * fade,
                Paint()..color = Colors.cyanAccent.withOpacity(0.9 * fade),
              );
            }
            canvas.drawCircle(
              attackerCenter,
              (8 + ct * 12) * fade,
              Paint()..color = const Color(0xFF0288D1).withOpacity(0.75 * fade),
            );
          }

          // Phase 2 (0.18..0.62): Glowing hydro sphere + trailing pulse rings travel to defender
          if (t >= 0.14 && t <= 0.68) {
            final pt = ((t - 0.14) / 0.48).clamp(0.0, 1.0);
            final orbPos = Offset.lerp(attackerCenter, defenderCenter, pt)!;
            canvas.drawCircle(
              orbPos,
              18 * fade,
              Paint()..color = const Color(0xFF039BE5).withOpacity(0.45 * fade),
            );
            canvas.drawCircle(
              orbPos,
              12 * fade,
              Paint()..color = Colors.cyanAccent.withOpacity(0.92 * fade),
            );
            canvas.drawCircle(
              orbPos - const Offset(3, 3),
              5 * fade,
              Paint()..color = Colors.white.withOpacity(0.95 * fade),
            );
            // Trailing ripple wakes
            for (int w = 1; w <= 2; w++) {
              final wakeT = max(0.0, pt - w * 0.16);
              final wakePos = Offset.lerp(attackerCenter, defenderCenter, wakeT)!;
              canvas.drawCircle(
                wakePos,
                10 + w * 4.0,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.6 * fade
                  ..color = Colors.lightBlueAccent.withOpacity(0.75 * fade),
              );
            }
          }

          // Phase 3 (0.48..1.0): Expanding ultrasonic concentric water pulse waves + droplet spray
          if (t >= 0.44) {
            final rt = ((t - 0.44) / 0.56).clamp(0.0, 1.0);
            for (int w = 0; w < 4; w++) {
              final waveT = ((rt - w * 0.14) / 0.72).clamp(0.0, 1.0);
              if (waveT <= 0) continue;
              final radX = 12 + waveT * 46;
              final radY = 9 + waveT * 34;
              canvas.drawOval(
                Rect.fromCenter(center: defenderCenter, width: radX * 2, height: radY * 2),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = (5.0 - w * 0.8) * (1.0 - waveT * 0.45) * fade
                  ..color = (w.isEven ? Colors.cyanAccent : Colors.white)
                      .withOpacity((1.0 - waveT * 0.35) * fade),
              );
            }
            // Splash droplets
            for (int d = 0; d < 8; d++) {
              final ang = (d / 8) * pi * 2 + rt * 1.6;
              final distR = 14 + Curves.easeOut.transform(rt) * 38;
              final dp = defenderCenter +
                  Offset(cos(ang) * distR, sin(ang) * distR * 0.78 - sin(rt * pi) * 10);
              canvas.drawCircle(
                dp,
                (d.isEven ? 4.2 : 3.0) * fade,
                Paint()
                  ..color = (d.isEven ? const Color(0xFF29B6F6) : Colors.white)
                      .withOpacity(fade),
              );
            }
          }
        }
        break;

      case 'surf':
        {
          // Rising ocean swell flooding across the battlefield toward defender,
          // led by a curling multi-layered tsunami crest with seafoam & spray.
          final travel = Curves.easeInOutCubic.transform(t);
          final swellAlpha = sin(t * pi).clamp(0.0, 1.0);
          final dirSign = unit.dx >= 0 ? 1.0 : -1.0;

          // 1. Arena-wide rolling ocean base surge rising from bottom
          final waterTop = size.height * (0.94 - 0.34 * swellAlpha);
          final basePath = Path()..moveTo(0, size.height);
          for (int s = 0; s <= 18; s++) {
            final fx = s / 18.0;
            final x = size.width * fx;
            final ripple = sin(fx * pi * 5 - t * pi * 6 * dirSign) * 8.0 * swellAlpha;
            basePath.lineTo(x, waterTop + ripple);
          }
          basePath
            ..lineTo(size.width, size.height)
            ..close();
          canvas.drawPath(
            basePath,
            Paint()..color = const Color(0xFF0D47A1).withOpacity(0.42 * swellAlpha * fade),
          );

          // 2. Main towering curling tidal wave sweeping past attacker onto defender
          final startCenter = attackerCenter - unit * 48.0;
          final endCenter = defenderCenter + unit * 72.0;
          final crestPos = Offset.lerp(startCenter, endCenter, travel)!;
          final waveHeight = 86.0 + sin(t * pi) * 44.0;
          final waveHalfW = 72.0 + sin(t * pi) * 20.0;
          final floorY = max(attackerCenter.dy, defenderCenter.dy) + 56.0;
          final peakY = crestPos.dy - waveHeight * 0.58;
          final frontX = crestPos.dx + dirSign * waveHalfW;
          final backX = crestPos.dx - dirSign * waveHalfW * 1.15;

          final deepWave = Path()
            ..moveTo(backX, floorY)
            ..quadraticBezierTo(
              crestPos.dx - dirSign * waveHalfW * 0.45,
              peakY - 12.0,
              frontX + dirSign * 14.0,
              peakY + 18.0,
            )
            ..quadraticBezierTo(
              frontX - dirSign * 22.0,
              peakY + 34.0,
              frontX - dirSign * 6.0,
              floorY,
            )
            ..close();
          canvas.drawPath(
            deepWave,
            Paint()..color = const Color(0xFF1565C0).withOpacity(0.76 * fade),
          );

          // Inner translucent turquoise body layer
          final midWave = Path()
            ..moveTo(backX + dirSign * 16.0, floorY)
            ..quadraticBezierTo(
              crestPos.dx - dirSign * waveHalfW * 0.28,
              peakY + 6.0,
              frontX + dirSign * 4.0,
              peakY + 26.0,
            )
            ..quadraticBezierTo(
              frontX - dirSign * 26.0,
              peakY + 42.0,
              frontX - dirSign * 14.0,
              floorY,
            )
            ..close();
          canvas.drawPath(
            midWave,
            Paint()..color = const Color(0xFF29B6F6).withOpacity(0.68 * fade),
          );

          // Rolling curled seafoam crest lip along the top ridge
          final crestRibbon = Path()
            ..moveTo(crestPos.dx - dirSign * waveHalfW * 0.65, peakY + 18.0)
            ..quadraticBezierTo(
              crestPos.dx - dirSign * 6.0,
              peakY - 10.0,
              frontX + dirSign * 14.0,
              peakY + 18.0,
            )
            ..quadraticBezierTo(
              frontX + dirSign * 2.0,
              peakY + 38.0,
              frontX - dirSign * 20.0,
              peakY + 28.0,
            );
          canvas.drawPath(
            crestRibbon,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 10.0
              ..color = Colors.white.withOpacity(0.92 * fade),
          );
          canvas.drawPath(
            crestRibbon,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..strokeWidth = 4.5
              ..color = const Color(0xFFB3E5FC).withOpacity(0.9 * fade),
          );

          // 3. Whitewater foam spheres & cresting spray droplets
          for (int i = 0; i < 12; i++) {
            final frac = i / 11.0;
            final foamPt = Offset(
              crestPos.dx - dirSign * (waveHalfW * 0.5) + dirSign * frac * (waveHalfW * 1.45),
              peakY + 6.0 + sin(frac * pi * 2.2 + t * 14.0) * 14.0,
            );
            final radius = (4.5 + (i % 3) * 2.5) * fade;
            canvas.drawCircle(
              foamPt,
              radius,
              Paint()..color = Colors.white.withOpacity(0.88 * fade),
            );
            // Ahead spray droplets
            final sprayPt = Offset(
              frontX + dirSign * (10.0 + (i % 4) * 11.0 + t * 18.0),
              peakY + 12.0 + ((i * 19) % 48).toDouble(),
            );
            canvas.drawCircle(
              sprayPt,
              2.6 * fade,
              Paint()..color = const Color(0xFFE1F5FE).withOpacity(0.85 * fade),
            );
          }

          // 4. Impact crash splash rings & plumes on defender
          if (t > 0.38) {
            final imp = ((t - 0.38) / 0.62).clamp(0.0, 1.0);
            final impFade = (1.0 - imp * 0.7) * fade;
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter + const Offset(0, 26),
                width: 48.0 + imp * 110.0,
                height: 18.0 + imp * 34.0,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * impFade
                ..color = Colors.white.withOpacity(impFade),
            );
            for (int k = 0; k < 8; k++) {
              final ang = -pi * 0.85 + (k / 7.0) * pi * 0.7;
              final sp = defenderCenter +
                  Offset(cos(ang) * (24.0 + imp * 64.0), sin(ang) * (20.0 + imp * 58.0));
              canvas.drawCircle(
                sp,
                (5.0 - imp * 2.5).clamp(1.5, 5.0),
                Paint()..color = (k.isEven ? Colors.white : const Color(0xFF4FC3F7)).withOpacity(impFade),
              );
            }
          }
        }
        break;

      case 'hydro_pump':
        {
          final reach = min(1.0, t / 0.52);
          final endPt = Offset.lerp(attackerCenter, defenderCenter, reach)!;
          final pathA = Path();
          final pathB = Path();
          for (int seg = 0; seg <= 16; seg++) {
            final f = (seg / 16.0) * reach;
            final twist = sin(f * pi * 4 - t * 18) * 9.0;
            final base = Offset.lerp(attackerCenter, defenderCenter, f)!;
            final pA = base + perp * twist;
            final pB = base - perp * twist;
            if (seg == 0) {
              pathA.moveTo(pA.dx, pA.dy);
              pathB.moveTo(pB.dx, pB.dy);
            } else {
              pathA.lineTo(pA.dx, pA.dy);
              pathB.lineTo(pB.dx, pB.dy);
            }
          }
          canvas.drawPath(
            pathA,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 10 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.blue.shade600.withOpacity(0.9 * fade),
          );
          canvas.drawPath(
            pathB,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.cyanAccent.withOpacity(0.9 * fade),
          );
          canvas.drawLine(
            attackerCenter,
            endPt,
            Paint()
              ..color = Colors.white.withOpacity(0.85 * fade)
              ..strokeWidth = 5 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.36) {
            final st = (t - 0.36) / 0.64;
            canvas.drawCircle(
              defenderCenter,
              18 + st * 44,
              Paint()..color = Colors.lightBlueAccent.withOpacity(0.42 * fade),
            );
            for (int k = 0; k < 8; k++) {
              final ang = (k / 8) * pi * 2 + st * 2;
              final fp = defenderCenter +
                  Offset(cos(ang) * (14 + st * 42), sin(ang) * (10 + st * 32));
              canvas.drawCircle(fp, 5 * fade, Paint()..color = Colors.white.withOpacity(fade));
            }
          }
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
        {
          for (int i = 0; i < 8; i++) {
            final lt = ((t - i * 0.055) / 0.5).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final spread = (i - 3.5) * 11.0;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! +
                perp * (spread * (1.0 - lt * 0.45)) +
                Offset(0, sin(lt * pi) * -12.0);
            // Speed trail streak behind leaf
            canvas.drawLine(
              pos - unit * 18.0,
              pos,
              Paint()
                ..color = Colors.lightGreenAccent.withOpacity(0.45 * fade)
                ..strokeWidth = 2.5 * fade
                ..strokeCap = StrokeCap.round,
            );
            canvas.save();
            canvas.translate(pos.dx, pos.dy);
            canvas.rotate(lt * 14.0 + i * 0.8);
            final leaf = Path()
              ..moveTo(-14.0, 0)
              ..quadraticBezierTo(0, -7.5, 14.0, 0)
              ..quadraticBezierTo(0, 7.5, -14.0, 0)
              ..close();
            canvas.drawPath(leaf, Paint()..color = const Color(0xFF43A047).withOpacity(fade));
            canvas.drawPath(
              leaf,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.8
                ..color = Colors.lightGreenAccent.withOpacity(fade),
            );
            canvas.drawLine(
              const Offset(-10, 0),
              const Offset(10, 0),
              Paint()..color = Colors.yellowAccent.withOpacity(0.8 * fade)..strokeWidth = 1.4,
            );
            canvas.restore();
          }
          if (t > 0.42) {
            _drawStarPath(canvas, defenderCenter, 22.0 * fade, 7.0 * fade, Colors.lightGreenAccent, fade, points: 4);
          }
        }
        break;

      case 'leech_seed':
        {
          if (isSelfTarget) {
            // End-of-turn Leech Seed tick: sprouting glowing tendrils & sapping spores
            for (int i = 0; i < 6; i++) {
              final ang = (i / 6.0) * pi * 2.0 + t * 2.5;
              final sp = defenderCenter + Offset(cos(ang) * 20.0, 8.0 - t * 34.0 + sin(ang) * 8.0);
              canvas.drawCircle(sp, 5.0 * fade,
                  Paint()..color = Colors.lightGreenAccent.withOpacity(0.9 * fade));
            }
            canvas.drawOval(
              Rect.fromCenter(center: defenderCenter + const Offset(0, 10), width: 52.0 * fade, height: 18.0 * fade),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = const Color(0xFF43A047).withOpacity(fade),
            );
          } else {
            // Throw seed from launchOrigin onto defender, then sprout wrapping tendrils
            final seedT = min(1.0, t / 0.52);
            if (seedT < 1.0) {
              final arc = sin(seedT * pi) * 44.0;
              final sPos = Offset.lerp(attackerCenter, defenderCenter, seedT)! - Offset(0, arc);
              canvas.drawCircle(sPos, 7.5 * fade,
                  Paint()..color = const Color(0xFF2E7D32).withOpacity(fade));
              canvas.drawCircle(sPos + const Offset(-2, -2), 3.0 * fade,
                  Paint()..color = Colors.lightGreenAccent.withOpacity(fade));
            } else {
              final wrap = ((t - 0.52) / 0.48).clamp(0.0, 1.0);
              for (int w = 0; w < 3; w++) {
                canvas.drawOval(
                  Rect.fromCenter(
                    center: defenderCenter + Offset(0, (w - 1) * 10.0),
                    width: (24.0 + wrap * 26.0) * fade,
                    height: 12.0 * fade,
                  ),
                  Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3.0 * fade
                    ..color = Colors.lightGreenAccent.withOpacity(fade),
                );
              }
            }
          }
        }
        break;

      case 'solar_beam':
        if (isSelfTarget) {
          // Turn 1 charge: gathering golden sunlight rings around attacker
          for (int r = 0; r < 3; r++) {
            final ang = t * 10 + r * (pi * 2 / 3);
            final orbit = 32 * (1.0 - t * 0.5);
            canvas.drawCircle(
              attackerCenter + Offset(cos(ang) * orbit, sin(ang) * orbit * 0.7),
              6 * fade,
              Paint()..color = Colors.yellowAccent.withOpacity(0.9 * fade),
            );
          }
          canvas.drawCircle(
            attackerCenter,
            (18 + sin(t * pi) * 14) * fade,
            Paint()..color = Colors.yellowAccent.withOpacity(0.45 * fade),
          );
        } else if (t < 0.35) {
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
        {
          canvas.drawCircle(
            attackerCenter,
            15 * (1.0 - min(1.0, t * 1.4) * 0.4) * fade,
            Paint()..color = Colors.yellowAccent.withOpacity(0.8 * fade),
          );
          for (int b = -1; b <= 1; b += 2) {
            final off = perp * (b * 7.0);
            _drawLightningBolt(
                canvas, attackerCenter + off, defenderCenter + off, fade, 3.8);
          }
          if (t > 0.25) {
            for (int s = 0; s < 5; s++) {
              final ang = (s / 5) * pi * 2 + t * 8;
              final sp = defenderCenter + Offset(cos(ang) * 26, sin(ang) * 22);
              _drawStarPath(
                  canvas, sp, 7 * fade, 2.5 * fade, Colors.yellowAccent, fade,
                  points: 4);
            }
          }
        }
        break;

      case 'electro_ball':
        {
          final travel = min(1.0, t / 0.68);
          final pos = Offset.lerp(attackerCenter, defenderCenter, travel)!;
          canvas.drawCircle(pos, 22.0 * fade, Paint()..color = Colors.amber.withOpacity(0.45 * fade));
          canvas.drawCircle(pos, 15.0 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
          canvas.drawCircle(pos, 7.5 * fade, Paint()..color = Colors.white.withOpacity(fade));
          for (int s = 0; s < 4; s++) {
            final ang = (s / 4.0) * pi * 2.0 + t * 14.0;
            final p1 = pos + Offset(cos(ang) * 10.0, sin(ang) * 10.0);
            final p2 = pos + Offset(cos(ang + 0.45) * 28.0, sin(ang + 0.45) * 28.0);
            _drawLightningBolt(canvas, p1, p2, fade, 2.4);
          }
          if (t > 0.62) {
            final imp = ((t - 0.62) / 0.38).clamp(0.0, 1.0);
            canvas.drawCircle(
              defenderCenter,
              (18.0 + imp * 36.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.0 * fade
                ..color = Colors.yellowAccent.withOpacity(fade),
            );
          }
        }
        break;

      case 'thunderbolt':
        {
          final impactFlash = sin(min(1.0, t * 1.4) * pi).clamp(0.0, 1.0);
          // Luminous sky column glow behind lightning bolts
          canvas.drawLine(
            Offset(defenderCenter.dx, 0),
            defenderCenter,
            Paint()
              ..color = Colors.yellowAccent.withOpacity(0.28 * impactFlash * fade)
              ..strokeWidth = 36.0,
          );
          for (int b = -1; b <= 1; b++) {
            final topPt = Offset(defenderCenter.dx + b * 22.0, 0);
            _drawLightningBolt(canvas, topPt, defenderCenter + Offset(b * 8.0, 0), fade, 5.5);
          }
          // Ground electric shock rings + scattering sparks
          canvas.drawOval(
            Rect.fromCenter(center: defenderCenter + const Offset(0, 24), width: 108.0 * t, height: 32.0 * t),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.0
              ..color = Colors.yellowAccent.withOpacity(fade),
          );
          for (int k = 0; k < 6; k++) {
            final ang = (k / 6.0) * pi * 2.0 + t * 9.0;
            final sp = defenderCenter + Offset(cos(ang) * (16.0 + t * 34.0), sin(ang) * (12.0 + t * 24.0));
            canvas.drawCircle(sp, 3.2 * fade, Paint()..color = Colors.white.withOpacity(fade));
          }
        }
        break;

      case 'thunder_wave':
        for (int i = 0; i < 3; i++) {
          final rad = 14 + i * 12 + sin(t * pi) * 14;
          canvas.drawOval(
            Rect.fromCenter(
                center: defenderCenter, width: rad * 2.1, height: rad * 1.4),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2 * fade
              ..color =
                  (i.isEven ? Colors.yellowAccent : Colors.lightBlueAccent)
                      .withOpacity(fade),
          );
        }
        for (int z = 0; z < 4; z++) {
          final ang = (z / 4) * pi * 2 + t * 7;
          final p1 = defenderCenter + Offset(cos(ang) * 16, sin(ang) * 12);
          final p2 = defenderCenter + Offset(cos(ang + 0.4) * 34, sin(ang + 0.4) * 26);
          _drawLightningBolt(canvas, p1, p2, fade, 2.4);
        }
        break;

      // ─── PHYSICAL / NORMAL / DARK MOVES ─────────────────────────────────
      case 'scratch':
        {
          final prog = min(1.0, t * 1.75);
          for (int i = -1; i <= 1; i++) {
            final off = Offset(i * 12.0, i * 7.0);
            final p1 = defenderCenter + const Offset(-28, -26) + off;
            final p2 = defenderCenter + const Offset(28, 26) + off;
            final tip = Offset.lerp(p1, p2, prog)!;
            final mid = Offset.lerp(p1, tip, 0.5)! + const Offset(-6, 6);
            final claw = Path()
              ..moveTo(p1.dx, p1.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
            canvas.drawPath(
              claw,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6.0 * fade
                ..strokeCap = StrokeCap.round
                ..color = Colors.redAccent.withOpacity(0.45 * fade),
            );
            canvas.drawPath(
              claw,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..strokeCap = StrokeCap.round
                ..color = Colors.white.withOpacity(fade),
            );
          }
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
        {
          for (int i = 0; i < 5; i++) {
            final lt = ((t - i * 0.06) / 0.45).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final p1 = Offset.lerp(attackerCenter, defenderCenter, max(0.0, lt - 0.38))!;
            final p2 = Offset.lerp(attackerCenter, defenderCenter, lt)!;
            final laneOff = perp * ((i - 2.0) * 9.0);
            canvas.drawLine(
              p1 + laneOff,
              p2 + laneOff,
              Paint()
                ..color = (i.isEven ? Colors.white : Colors.lightBlueAccent).withOpacity(0.88 * fade)
                ..strokeWidth = (i == 2 ? 7.0 : 4.0) * fade
                ..strokeCap = StrokeCap.round,
            );
          }
          if (t > 0.35) {
            final imp = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
            _drawStarPath(canvas, defenderCenter, (18.0 + imp * 16.0) * fade, 7.0 * fade, Colors.white, fade, points: 4);
            canvas.drawCircle(
              defenderCenter,
              (12.0 + imp * 34.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * fade
                ..color = Colors.cyanAccent.withOpacity((1.0 - imp * 0.6) * fade),
            );
          }
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
        {
          final reach = min(1.0, t * 1.85);
          for (int i = -2; i <= 2; i++) {
            final endPt = Offset.lerp(attackerCenter, defenderCenter + perp * (i * 9.0), reach)!;
            final silkPath = Path()..moveTo(attackerCenter.dx, attackerCenter.dy);
            for (int seg = 1; seg <= 10; seg++) {
              final f = seg / 10.0;
              final pt = Offset.lerp(attackerCenter, endPt, f)! +
                  perp * (sin(f * pi * 3.0 + i * 0.9 + t * 8.0) * 6.0);
              silkPath.lineTo(pt.dx, pt.dy);
            }
            canvas.drawPath(
              silkPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.6 * fade
                ..strokeCap = StrokeCap.round
                ..color = Colors.white.withOpacity(0.9 * fade),
            );
          }
          if (t > 0.42) {
            final wrap = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
            for (int w = 0; w < 3; w++) {
              canvas.drawOval(
                Rect.fromCenter(
                  center: defenderCenter + Offset(0, (w - 1) * 11.0),
                  width: 44.0 * wrap + 14.0,
                  height: 12.0,
                ),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.8 * fade
                  ..color = Colors.white.withOpacity(0.85 * fade),
              );
            }
          }
        }
        break;

      case 'bug_bite':
        _drawJaws(canvas, defenderCenter, t, fade, Colors.lightGreenAccent, Colors.white);
        break;

      case 'poison_sting':
      case 'twinneedle':
        {
          final count = moveId == 'twinneedle' ? 2 : 1;
          for (int i = 0; i < count; i++) {
            final lt = ((t - i * 0.12) / 0.55).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final off = count == 2 ? perp * ((i == 0 ? -1.0 : 1.0) * 11.0) : Offset.zero;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)! + off;
            final tip = pos + unit * 14.0;
            final dart = Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo((pos - unit * 14.0 + perp * 4.5).dx, (pos - unit * 14.0 + perp * 4.5).dy)
              ..lineTo((pos - unit * 14.0 - perp * 4.5).dx, (pos - unit * 14.0 - perp * 4.5).dy)
              ..close();
            canvas.drawPath(dart, Paint()..color = Colors.purpleAccent.withOpacity(fade));
            canvas.drawLine(pos - unit * 26.0, pos - unit * 10.0,
                Paint()..color = Colors.white.withOpacity(0.8 * fade)..strokeWidth = 2.5 * fade);
          }
          if (t > 0.45) {
            for (int k = 0; k < 5; k++) {
              final ang = (k / 5.0) * pi * 2.0 + t * 4.0;
              final drop = defenderCenter + Offset(cos(ang) * (12.0 + t * 22.0), sin(ang) * (12.0 + t * 22.0));
              canvas.drawCircle(drop, 4.0 * fade, Paint()..color = Colors.purple.shade400.withOpacity(fade));
            }
          }
        }
        break;

      case 'poison_jab':
      case 'sludge_bomb':
      case 'status_poison':
        {
          if (moveId == 'sludge_bomb') {
            final lob = min(1.0, t / 0.55);
            final arcPos = Offset.lerp(attackerCenter, defenderCenter, lob)! +
                Offset(0, -sin(lob * pi) * 54.0);
            if (t < 0.55) {
              canvas.drawCircle(arcPos, 17.0 * fade, Paint()..color = Colors.purple.shade800.withOpacity(fade));
              canvas.drawCircle(arcPos + const Offset(-4, -4), 6.5 * fade,
                  Paint()..color = Colors.purpleAccent.withOpacity(fade));
            } else {
              final splat = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
              canvas.drawOval(
                Rect.fromCenter(center: defenderCenter + const Offset(0, 16), width: 30.0 + splat * 56.0, height: 14.0 + splat * 18.0),
                Paint()..style = PaintingStyle.stroke..strokeWidth = 4.0 * fade..color = Colors.purpleAccent.withOpacity(fade),
              );
              for (int i = 0; i < 8; i++) {
                final ang = (i / 8.0) * pi * 2.0;
                final drop = defenderCenter + Offset(cos(ang) * (10.0 + splat * 38.0), sin(ang) * (8.0 + splat * 28.0));
                canvas.drawCircle(drop, 6.5 * fade, Paint()..color = (i.isEven ? Colors.purple.shade700 : Colors.purpleAccent).withOpacity(fade));
              }
            }
          } else {
            for (int i = 0; i < 8; i++) {
              final lt = ((t - i * 0.05) / 0.58).clamp(0.0, 1.0);
              if (lt <= 0) continue;
              final ang = (i / 8.0) * pi * 2.0 + t * 2.5;
              final p = defenderCenter + Offset(cos(ang) * (10.0 + lt * 34.0), sin(ang) * (10.0 + lt * 26.0));
              canvas.drawCircle(p, 7.5 * fade, Paint()..color = Colors.purple.shade700.withOpacity(0.85 * fade));
              canvas.drawCircle(p + const Offset(-2, -2), 3.0 * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
            }
          }
        }
        break;

      case 'confusion':
      case 'psybeam':
        if (moveId == 'psybeam') {
          final colors = [
            Colors.pinkAccent,
            Colors.cyanAccent,
            Colors.yellowAccent,
            Colors.purpleAccent,
            Colors.white,
          ];
          final reach = min(1.0, t / 0.62);
          for (int c = 0; c < colors.length; c++) {
            final beamPath = Path();
            final lane = (c - 2.0) * 4.5;
            for (int seg = 0; seg <= 16; seg++) {
              final f = (seg / 16.0) * reach;
              final wave = sin(f * pi * 5 - t * 16 + c * 0.6) * 8.0;
              final pt =
                  Offset.lerp(attackerCenter, defenderCenter, f)! + perp * (lane + wave);
              if (seg == 0) {
                beamPath.moveTo(pt.dx, pt.dy);
              } else {
                beamPath.lineTo(pt.dx, pt.dy);
              }
            }
            canvas.drawPath(
              beamPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.4 * fade
                ..strokeCap = StrokeCap.round
                ..color = colors[c].withOpacity(0.92 * fade),
            );
          }
          if (t > 0.4) {
            canvas.drawCircle(
              defenderCenter,
              14 + (t - 0.4) * 38,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.pinkAccent.withOpacity(fade),
            );
          }
        } else {
          for (int i = 0; i < 4; i++) {
            final pulse = sin(t * pi * 3 + i) * 7.0;
            canvas.drawOval(
              Rect.fromCenter(
                center: defenderCenter,
                width: (28 + i * 16 + pulse) * fade,
                height: (20 + i * 11 - pulse * 0.5) * fade,
              ),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.2 * fade
                ..color = (i.isEven ? Colors.pinkAccent : Colors.purpleAccent)
                    .withOpacity(fade),
            );
          }
          for (int s = 0; s < 5; s++) {
            final ang = (s / 5) * pi * 2 + t * 5;
            final sp = defenderCenter + Offset(cos(ang) * 28, sin(ang) * 20);
            _drawStarPath(
                canvas, sp, 6 * fade, 2.5 * fade, Colors.cyanAccent, fade,
                points: 4);
          }
        }
        break;

      // ─── STAT BUFFS & DEBUFFS ───────────────────────────────────────────
      case 'growl':
        for (int i = 0; i < 4; i++) {
          final lt = ((t - i * 0.11) / 0.65).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
          final ang = atan2(dir.dy, dir.dx);
          canvas.drawArc(
            Rect.fromCenter(
                center: pos, width: 22 + lt * 32, height: 22 + lt * 32),
            ang - 0.9,
            1.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 * fade
              ..strokeCap = StrokeCap.round
              ..color = (i.isEven ? Colors.amberAccent : Colors.white)
                  .withOpacity(fade),
          );
        }
        break;

      case 'tail_whip':
        {
          final wag = sin(t * pi * 4);
          final arcCenter = attackerCenter + Offset(wag * 14, -4);
          canvas.drawArc(
            Rect.fromCenter(center: arcCenter, width: 52, height: 34),
            0.2 + wag * 0.5,
            pi * 0.75,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.amberAccent.withOpacity(fade),
          );
          for (int s = 0; s < 4; s++) {
            final sp = attackerCenter +
                Offset((s - 1.5) * 14.0, -18 - sin(t * pi) * 14);
            _drawStarPath(
                canvas, sp, 7 * fade, 3 * fade, Colors.white, fade,
                points: 4);
          }
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
        for (int i = 0; i < 6; i++) {
          final a1 = (i / 6) * pi * 2;
          final a2 = ((i + 1) / 6) * pi * 2;
          final r = 24 + (1.0 - min(1.0, t * 1.4)) * 18;
          canvas.drawLine(
            attackerCenter + Offset(cos(a1) * r, sin(a1) * r),
            attackerCenter + Offset(cos(a2) * r, sin(a2) * r),
            Paint()
              ..color = Colors.blueGrey.shade100.withOpacity(fade)
              ..strokeWidth = 4 * fade
              ..strokeCap = StrokeCap.round,
          );
        }
        canvas.drawCircle(
          attackerCenter,
          26 * fade,
          Paint()..color = Colors.white.withOpacity(0.28 * sin(t * pi)),
        );
        break;

      case 'agility':
        for (int i = 0; i < 5; i++) {
          final dashX = sin(t * pi * 5 + i * 0.9) * 32.0;
          final yOff = (i - 2) * 10.0;
          canvas.drawLine(
            attackerCenter + Offset(dashX - 24, yOff),
            attackerCenter + Offset(dashX + 24, yOff),
            Paint()
              ..color = (i.isEven ? Colors.cyanAccent : Colors.white)
                  .withOpacity(0.85 * fade)
              ..strokeWidth = 3.2 * fade
              ..strokeCap = StrokeCap.round,
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
          if (isSelfTarget || t < 0.48) {
            // Burrow mound & dirt clods at attacker (+ tremor trail on strike turn)
            final bt = isSelfTarget ? t : (t / 0.48).clamp(0.0, 1.0);
            for (int cl = 0; cl < 5; cl++) {
              final cx = (cl - 2.0) * 10.0;
              final cy = -sin(bt * pi * 2 + cl) * 12.0 + 18.0;
              canvas.drawCircle(
                attackerCenter + Offset(cx, cy),
                7.0 * (1.0 - bt * 0.4),
                Paint()..color = const Color(0xFF795548).withOpacity(0.9 * fade),
              );
            }
            canvas.drawOval(
              Rect.fromCenter(center: attackerCenter + const Offset(0, 20), width: 52, height: 18),
              Paint()..color = const Color(0xFF4E342E).withOpacity(0.85 * fade),
            );
            if (!isSelfTarget) {
              // Moving subterranean tremor mounds along the path on Turn 2
              final steps = (bt * 6).floor();
              for (int s = 0; s <= steps; s++) {
                final mp = Offset.lerp(attackerCenter + const Offset(0, 18),
                    defenderCenter + const Offset(0, 18), s / 6.0)!;
                canvas.drawOval(
                  Rect.fromCenter(center: mp, width: 20, height: 8),
                  Paint()..color = const Color(0xFF8D6E63).withOpacity(0.85),
                );
              }
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
        {
          final reach = min(1.0, t / 0.56);
          final elemColors = [Colors.redAccent, Colors.cyanAccent, Colors.yellowAccent];
          // 3 twisting helical streams converging at defender
          for (int i = 0; i < 3; i++) {
            final helixPath = Path();
            for (int seg = 0; seg <= 16; seg++) {
              final f = (seg / 16.0) * reach;
              final amp = (1.0 - f * 0.72) * 24.0;
              final ang = f * pi * 4.0 + i * (pi * 2.0 / 3.0) - t * 6.0;
              final pt = Offset.lerp(attackerCenter, defenderCenter, f)! + perp * (sin(ang) * amp);
              if (seg == 0) {
                helixPath.moveTo(pt.dx, pt.dy);
              } else {
                helixPath.lineTo(pt.dx, pt.dy);
              }
            }
            canvas.drawPath(
              helixPath,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5.0 * fade
                ..strokeCap = StrokeCap.round
                ..color = elemColors[i].withOpacity(0.9 * fade),
            );
            final orbPos = Offset.lerp(attackerCenter, defenderCenter, reach)! +
                perp * (sin(reach * pi * 4.0 + i * (pi * 2.0 / 3.0) - t * 6.0) * (1.0 - reach * 0.72) * 24.0);
            canvas.drawCircle(orbPos, 8.5 * fade, Paint()..color = elemColors[i].withOpacity(fade));
          }
          if (t > 0.5) {
            final imp = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
            for (int i = 0; i < 3; i++) {
              final a = (i / 3.0) * pi * 2.0 - pi / 2.0 + imp * pi;
              final corner = defenderCenter + Offset(cos(a) * 32.0 * imp, sin(a) * 32.0 * imp);
              canvas.drawCircle(corner, 10.0 * fade, Paint()..color = elemColors[i].withOpacity(0.85 * fade));
            }
            _drawStarPath(canvas, defenderCenter, (18.0 + imp * 20.0) * fade, 7.0 * fade, Colors.white, fade);
          }
        }
        break;

      case 'flash_cannon':
        {
          // Brief metallic compression charge -> silver-cyan beam with containment rings
          final chargeR = (26.0 * (1.0 - min(1.0, t / 0.28))).clamp(0.0, 26.0);
          if (chargeR > 1.0) {
            canvas.drawCircle(
              attackerCenter,
              chargeR,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.cyanAccent.withOpacity(fade),
            );
          }
          final fcT = min(1.0, max(0.0, (t - 0.12) / 0.42));
          final fcPos = Offset.lerp(attackerCenter, defenderCenter, fcT)!;
          canvas.drawLine(
            attackerCenter,
            fcPos,
            Paint()
              ..color = Colors.lightBlueAccent.withOpacity(0.55 * fade)
              ..strokeWidth = 24.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            fcPos,
            Paint()
              ..color = Colors.blueGrey.shade100.withOpacity(0.95 * fade)
              ..strokeWidth = 14.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawLine(
            attackerCenter,
            fcPos,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = 6.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          for (int r = 1; r <= 3; r++) {
            final ringPos = Offset.lerp(attackerCenter, fcPos, r / 3.5)!;
            canvas.drawCircle(
              ringPos,
              (10.0 + r * 4.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5 * fade
                ..color = Colors.white.withOpacity(0.85 * fade),
            );
          }
          if (fcT > 0.7) {
            _drawStarPath(canvas, defenderCenter, 28.0 * fade, 10.0 * fade, Colors.lightBlueAccent, fade, points: 6, rotation: t * 4.0);
          }
        }
        break;

      case 'blizzard':
        {
          // Howling diagonal snowstorm gale lines sweeping across the entire battle arena
          for (int s = 0; s < 10; s++) {
            final baseY = size.height * ((s + 0.5) / 10.0);
            final shift = ((t * 1.8 + s * 0.11) % 1.2) * size.width;
            final p1 = Offset(size.width - shift, baseY - 24.0);
            final p2 = Offset(size.width - shift - 95.0, baseY + 28.0);
            canvas.drawLine(
              p1,
              p2,
              Paint()
                ..color = (s.isEven ? Colors.white : const Color(0xFF81D4FA)).withOpacity(0.55 * fade)
                ..strokeWidth = (2.5 + (s % 3) * 1.4) * fade
                ..strokeCap = StrokeCap.round,
            );
          }
          // Frigid frost mist & ground chill around defender
          canvas.drawOval(
            Rect.fromCenter(center: defenderCenter + const Offset(0, 14), width: (70.0 + t * 50.0) * fade, height: (28.0 + t * 18.0) * fade),
            Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.32 * fade),
          );
          for (int i = 0; i < 12; i++) {
            final ang = (i / 12.0) * pi * 2.0 + t * 5.0;
            final rad = 16.0 + (i % 3) * 16.0 + sin(t * pi) * 28.0;
            final p = defenderCenter + Offset(cos(ang) * rad, sin(ang) * rad * 0.65);
            _drawIceCrystal(canvas, p, (7.0 + (i % 2) * 3.5) * fade, t * 6.0 + i, fade);
          }
        }
        break;

      case 'powder_snow':
        for (int i = 0; i < 10; i++) {
          final lt = ((t - i * 0.05) / 0.6).clamp(0.0, 1.0);
          if (lt <= 0) continue;
          final p = Offset.lerp(attackerCenter, defenderCenter, lt)! +
              perp * (sin(lt * 10 + i) * 20);
          _drawIceCrystal(canvas, p, 6.5 * fade, lt * 5 + i, fade);
        }
        break;

      case 'thunder':
        final skyStart =
            Offset(defenderCenter.dx + sin(t * 10) * 10, defenderCenter.dy - 120);
        _drawLightningBolt(canvas, skyStart, defenderCenter, fade, 7.5);
        _drawLightningBolt(canvas, skyStart, defenderCenter, fade, 3.5);
        canvas.drawCircle(
          defenderCenter,
          (20 + t * 35) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * fade
            ..color = Colors.yellowAccent.withOpacity(fade),
        );
        break;

      case 'shock_wave':
        {
          for (int i = 0; i < 3; i++) {
            final lt = ((t - i * 0.1) / 0.58).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
            canvas.drawCircle(
              pos,
              12 + i * 3.0,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 * fade
                ..color = Colors.yellowAccent.withOpacity(fade),
            );
            _drawLightningBolt(
                canvas, pos - perp * 12, pos + perp * 12, fade, 2.5);
          }
          if (t > 0.45) {
            _drawStarPath(canvas, defenderCenter, 22 * fade, 8 * fade,
                Colors.yellowAccent, fade,
                points: 6);
          }
        }
        break;

      case 'discharge':
        for (int i = 0; i < 8; i++) {
          final ang = (i / 8) * pi * 2 + t * 1.5;
          final rad = 16 + t * 58;
          final p = attackerCenter + Offset(cos(ang) * rad, sin(ang) * rad);
          _drawLightningBolt(canvas, attackerCenter, p, fade, 3.2);
        }
        canvas.drawCircle(
          attackerCenter,
          (18 + t * 48) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * fade
            ..color = Colors.yellowAccent.withOpacity(0.8 * fade),
        );
        break;

      case 'sludge':
        {
          for (int i = 0; i < 6; i++) {
            final lt = ((t - i * 0.07) / 0.55).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final arc = sin(lt * pi) * (32.0 + i * 4.0);
            final p = Offset.lerp(attackerCenter, defenderCenter, lt)! - Offset(0, arc) + perp * ((i - 2.5) * 4.0);
            canvas.drawCircle(p, 11.0 * fade, Paint()..color = Colors.purple.shade800.withOpacity(fade));
            canvas.drawCircle(p + const Offset(-2.5, -2.5), 4.5 * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
          }
          if (t > 0.42) {
            final imp = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
            canvas.drawOval(
              Rect.fromCenter(center: defenderCenter + const Offset(0, 18), width: (28.0 + imp * 46.0) * fade, height: (10.0 + imp * 14.0) * fade),
              Paint()..color = Colors.purple.shade700.withOpacity(0.65 * fade),
            );
            for (int b = 0; b < 4; b++) {
              final bp = defenderCenter + Offset((b - 1.5) * 14.0, 10.0 - imp * (18.0 + b * 5.0));
              canvas.drawCircle(bp, 4.0 * fade, Paint()..color = Colors.purpleAccent.withOpacity(fade));
            }
          }
        }
        break;

      case 'toxic':
        for (int i = 0; i < 6; i++) {
          final dropT = ((t - i * 0.07) / 0.55).clamp(0.0, 1.0);
          if (dropT <= 0) continue;
          final xOff = (i - 2.5) * 11.0;
          final p = defenderCenter + Offset(xOff, -34 + dropT * 46);
          canvas.drawCircle(p, 6 * fade,
              Paint()..color = Colors.deepPurple.shade800.withOpacity(fade));
          canvas.drawCircle(p + const Offset(-1.5, -1.5), 2.5 * fade,
              Paint()..color = Colors.purpleAccent.withOpacity(fade));
        }
        if (t > 0.4) {
          canvas.drawOval(
            Rect.fromCenter(
                center: defenderCenter + const Offset(0, 16),
                width: 44 + (t - 0.4) * 36,
                height: 16 + (t - 0.4) * 12),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..color = Colors.purpleAccent.withOpacity(fade),
          );
        }
        break;

      case 'poison_gas':
        {
          // Rolling billowing smog cloud traveling from attacker to engulf defender
          for (int i = 0; i < 11; i++) {
            final drift = min(1.0, (t + i * 0.04) * 1.35);
            final cloudBase = Offset.lerp(attackerCenter, defenderCenter, drift * 0.85 + 0.15)!;
            final ang = (i / 11.0) * pi * 2.0 + t * 2.8;
            final rad = 12.0 + sin(t * pi) * 28.0 + (i % 3) * 6.0;
            final p = cloudBase + Offset(cos(ang) * rad, sin(ang) * rad * 0.68);
            final puffR = (10.0 + sin(t * 7.0 + i) * 4.0) * fade;
            canvas.drawCircle(p, puffR,
                Paint()..color = (i.isEven ? Colors.purple.shade800 : Colors.deepPurple).withOpacity(0.55 * fade));
            canvas.drawCircle(p + const Offset(-2, -2), puffR * 0.55,
                Paint()..color = Colors.purpleAccent.withOpacity(0.45 * fade));
          }
        }
        break;

      case 'acid_armor':
        {
          // Shimmering liquefying translucent wave + rising protective bubbles around attacker
          for (int r = 0; r < 3; r++) {
            final swell = sin(t * pi * 3.0 + r) * 6.0;
            final aaRect = Rect.fromCenter(
              center: attackerCenter,
              width: (38.0 + r * 12.0 + swell) * fade,
              height: (52.0 + r * 8.0 - swell * 0.5) * fade,
            );
            canvas.drawOval(aaRect, Paint()..color = Colors.lightBlueAccent.withOpacity(0.22 * fade));
            canvas.drawOval(
              aaRect,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5 * fade
                ..color = (r.isEven ? Colors.purpleAccent : Colors.cyanAccent).withOpacity(0.8 * fade),
            );
          }
          for (int d = 0; d < 6; d++) {
            final dt = (t + d * 0.16) % 1.0;
            final dp = attackerCenter + Offset((d - 2.5) * 11.0, 22.0 - dt * 46.0);
            canvas.drawCircle(dp, 3.8 * (1.0 - dt * 0.4) * fade,
                Paint()..color = Colors.white.withOpacity(0.8 * fade));
          }
        }
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
        {
          // Curved out-and-back boomerang flight hitting defender at midpoint
          final progress = sin(t * pi);
          final arcSide = (t < 0.5 ? 1.0 : -1.0) * sin(t * pi * 2.0).abs() * 38.0;
          final bPos = Offset.lerp(attackerCenter, defenderCenter, progress)! + perp * arcSide;
          canvas.save();
          canvas.translate(bPos.dx, bPos.dy);
          canvas.rotate(t * pi * 6.0);
          final bmPaint = Paint()
            ..color = const Color(0xFFF5F5DC).withOpacity(fade)
            ..strokeWidth = 6.5 * fade
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(const Offset(-16, 0), const Offset(16, 0), bmPaint);
          for (final ex in [-16.0, 16.0]) {
            for (final ey in [-4.5, 4.5]) {
              canvas.drawCircle(Offset(ex, ey), 4.2 * fade,
                  Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
            }
          }
          canvas.restore();
          if (t > 0.4 && t < 0.7) {
            _drawStarPath(canvas, defenderCenter, 22.0 * fade, 8.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'drill_run':
      case 'horn_drill':
        {
          final drillT = min(1.0, t * 1.35);
          final drillPos = Offset.lerp(attackerCenter, defenderCenter, drillT)!;
          final tip = drillPos + unit * 24.0;
          final base = drillPos - unit * 22.0;
          final cone = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((base + perp * 16.0).dx, (base + perp * 16.0).dy)
            ..lineTo((base - perp * 16.0).dx, (base - perp * 16.0).dy)
            ..close();
          canvas.drawPath(cone, Paint()..color = Colors.blueGrey.shade200.withOpacity(0.92 * fade));
          canvas.drawPath(
            cone,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5 * fade
              ..color = Colors.white.withOpacity(fade),
          );
          // Rotating spiral helix bands along the cone
          for (int i = 0; i < 4; i++) {
            final f = i / 4.0;
            final center = Offset.lerp(base, tip, f)!;
            final w = (1.0 - f * 0.75) * 14.0;
            final spinOff = sin(t * 20.0 + i * 1.4) * w;
            canvas.drawLine(
              center - perp * w,
              center + perp * spinOff,
              Paint()
                ..color = Colors.amberAccent.withOpacity(0.85 * fade)
                ..strokeWidth = 3.0 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
          if (t > 0.45) {
            final imp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
            canvas.drawCircle(
              defenderCenter,
              (16.0 + imp * 30.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.amber.withOpacity(fade),
            );
          }
        }
        break;

      case 'pin_missile':
        {
          for (int i = 0; i < 8; i++) {
            final pT = ((t - i * 0.06) / 0.48).clamp(0.0, 1.0);
            if (pT <= 0) continue;
            final spread = (i - 3.5) * 5.0;
            final pPos = Offset.lerp(attackerCenter, defenderCenter, pT)! + perp * spread;
            final tip = pPos + unit * 11.0;
            final tail = pPos - unit * 12.0;
            final needle = Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo((tail + perp * 3.5).dx, (tail + perp * 3.5).dy)
              ..lineTo((tail - perp * 3.5).dx, (tail - perp * 3.5).dy)
              ..close();
            canvas.drawPath(needle, Paint()..color = Colors.limeAccent.withOpacity(fade));
            canvas.drawLine(pPos - unit * 24.0, tail,
                Paint()..color = Colors.white.withOpacity(0.75 * fade)..strokeWidth = 2.0 * fade);
          }
          if (t > 0.4) {
            _drawStarPath(canvas, defenderCenter, 20.0 * fade, 7.0 * fade, Colors.limeAccent, fade, points: 5);
          }
        }
        break;

      case 'dragon_rage':
        {
          final drT = min(1.0, t * 1.45);
          final drPos = Offset.lerp(attackerCenter, defenderCenter, drT)!;
          // Swirling dragonfire shock-orb + raging vortex pillar on defender
          canvas.drawCircle(drPos, (20.0 + drT * 14.0) * fade,
              Paint()..color = Colors.indigoAccent.withOpacity(0.7 * fade));
          canvas.drawCircle(drPos, (11.0 + drT * 8.0) * fade,
              Paint()..color = Colors.cyanAccent.withOpacity(fade));
          canvas.drawLine(
            attackerCenter,
            drPos,
            Paint()
              ..color = Colors.purpleAccent.withOpacity(0.55 * fade)
              ..strokeWidth = 8.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          if (t > 0.45) {
            final imp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
            for (int f = 0; f < 5; f++) {
              final ang = (f / 5.0) * pi * 2.0 + t * 8.0;
              final fp = defenderCenter + Offset(cos(ang) * 20.0, -imp * 34.0 + sin(ang) * 14.0);
              canvas.drawCircle(fp, 11.0 * (1.0 - imp * 0.3) * fade,
                  Paint()..color = (f.isEven ? Colors.deepPurpleAccent : Colors.cyanAccent).withOpacity(0.75 * fade));
            }
          }
        }
        break;

      case 'dragon_claw':
        {
          final prog = min(1.0, t * 1.6);
          for (int i = -1; i <= 1; i++) {
            final off = Offset(i * 15.0, i * 4.0);
            final p1 = defenderCenter + const Offset(-32, -32) + off;
            final p2 = defenderCenter + const Offset(28, 32) + off;
            final tip = Offset.lerp(p1, p2, prog)!;
            final mid = Offset.lerp(p1, tip, 0.5)! + const Offset(-10, 10);
            final slash = Path()
              ..moveTo(p1.dx, p1.dy)
              ..quadraticBezierTo(mid.dx, mid.dy, tip.dx, tip.dy);
            canvas.drawPath(
              slash,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 9.0 * fade
                ..strokeCap = StrokeCap.round
                ..color = Colors.deepPurpleAccent.withOpacity(0.7 * fade),
            );
            canvas.drawPath(
              slash,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * fade
                ..strokeCap = StrokeCap.round
                ..color = Colors.tealAccent.withOpacity(fade),
            );
          }
          if (t > 0.35) {
            _drawStarPath(canvas, defenderCenter, 24.0 * fade, 9.0 * fade, Colors.tealAccent, fade);
          }
        }
        break;

      case 'dragon_breath':
        {
          for (int i = 0; i < 14; i++) {
            final lt = ((t - i * 0.04) / 0.54).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final cone = sin(lt * pi * 0.85) * (12.0 + (i - 6.5) * 4.5);
            final p = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * cone;
            canvas.drawCircle(
              p,
              (7.0 + lt * 12.0) * fade,
              Paint()
                ..color = (i % 3 == 0
                        ? Colors.cyanAccent
                        : (i.isEven ? Colors.tealAccent : Colors.indigoAccent))
                    .withOpacity(0.78 * fade),
            );
          }
          if (t > 0.45) {
            for (int k = 0; k < 4; k++) {
              final ang = (k / 4.0) * pi * 2.0 + t * 8.0;
              _drawLightningBolt(
                canvas,
                defenderCenter,
                defenderCenter + Offset(cos(ang) * 28.0, sin(ang) * 24.0),
                fade,
                2.5,
              );
            }
          }
        }
        break;

      case 'outrage':
        {
          // Fierce crimson-orange rage aura on attacker + chaotic dragon slashes on defender
          for (int r = 0; r < 2; r++) {
            canvas.drawCircle(
              attackerCenter,
              (22.0 + r * 14.0 + t * 28.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4.5 * fade
                ..color = (r == 0 ? Colors.redAccent : Colors.orangeAccent).withOpacity(fade),
            );
          }
          for (int i = 0; i < 5; i++) {
            final st = ((t - i * 0.09) / 0.45).clamp(0.0, 1.0);
            if (st <= 0) continue;
            final ang = i * 1.25 + 0.4;
            final d = Offset(cos(ang) * 32.0, sin(ang) * 32.0);
            canvas.drawLine(
              defenderCenter - d,
              Offset.lerp(defenderCenter - d, defenderCenter + d, st)!,
              Paint()
                ..color = (i.isEven ? Colors.deepOrangeAccent : Colors.redAccent).withOpacity(fade)
                ..strokeWidth = 6.0 * fade
                ..strokeCap = StrokeCap.round,
            );
            _drawStarPath(canvas, defenderCenter + d * 0.35, 14.0 * fade, 5.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'ancient_power':
        {
          // Silver-cyan telekinetic stones levitating, then hurling in rapid barrage
          final firePhase = ((t - 0.25) / 0.55).clamp(0.0, 1.0);
          for (int i = 0; i < 5; i++) {
            final ang = (i / 5.0) * pi * 2.0 + t * 4.0;
            final hover = attackerCenter + Offset(cos(ang) * 38.0, sin(ang) * 28.0 - 12.0 * min(1.0, t * 4.0));
            final dest = Offset.lerp(hover, defenderCenter + perp * ((i - 2.0) * 8.0), firePhase)!;
            canvas.drawCircle(dest, 15.0 * fade, Paint()..color = Colors.cyanAccent.withOpacity(0.35 * fade));
            _drawPolygonBoulder(canvas, dest, 12.5 * fade, t * 6.0 + i, fade);
          }
          if (t > 0.65) {
            final imp = ((t - 0.65) / 0.35).clamp(0.0, 1.0);
            canvas.drawCircle(
              defenderCenter,
              (16.0 + imp * 28.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.amberAccent.withOpacity(fade),
            );
          }
        }
        break;

      case 'egg_bomb':
        {
          final lob = min(1.0, t / 0.56);
          final arc = sin(lob * pi) * 58.0;
          final eggPos = Offset.lerp(attackerCenter, defenderCenter, lob)! - Offset(0, arc);
          if (t < 0.56) {
            canvas.save();
            canvas.translate(eggPos.dx, eggPos.dy);
            canvas.rotate(lob * pi * 3.0);
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 18.0 * fade, height: 24.0 * fade),
                Paint()..color = const Color(0xFFFFF9C4).withOpacity(fade));
            canvas.drawOval(
              Rect.fromCenter(center: Offset.zero, width: 18.0 * fade, height: 24.0 * fade),
              Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..color = Colors.amber.shade700.withOpacity(fade),
            );
            canvas.restore();
          } else {
            final exp = ((t - 0.56) / 0.44).clamp(0.0, 1.0);
            canvas.drawCircle(defenderCenter, (18.0 + exp * 44.0) * fade,
                Paint()..color = Colors.deepOrangeAccent.withOpacity(0.75 * fade));
            canvas.drawCircle(defenderCenter, (12.0 + exp * 28.0) * fade,
                Paint()..color = Colors.yellowAccent.withOpacity(fade));
            _drawStarPath(canvas, defenderCenter, (22.0 + exp * 24.0) * fade, 9.0 * fade, Colors.white, fade, points: 8);
          }
        }
        break;

      case 'fire_spin':
        {
          // Spiraling 3D cone of fire vortex trapping defender from bottom to top
          for (int i = 0; i < 16; i++) {
            final frac = i / 15.0;
            final ang = frac * pi * 4.0 + t * 11.0;
            final radius = 16.0 + frac * 24.0 + sin(t * pi * 3.0) * 6.0;
            final yOff = 24.0 - frac * 54.0;
            final p = defenderCenter + Offset(cos(ang) * radius, yOff + sin(ang) * 9.0);
            final r = (7.5 - frac * 2.5) * fade;
            canvas.drawCircle(p, r,
                Paint()..color = (i.isEven ? Colors.deepOrangeAccent : Colors.redAccent).withOpacity(0.88 * fade));
            canvas.drawCircle(p, r * 0.5,
                Paint()..color = Colors.yellowAccent.withOpacity(fade));
          }
        }
        break;

      case 'flame_wheel':
        {
          final wheelPos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.12))!;
          canvas.drawLine(
            attackerCenter,
            wheelPos,
            Paint()
              ..color = Colors.deepOrange.withOpacity(0.42 * fade)
              ..strokeWidth = 14.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          for (int i = 0; i < 8; i++) {
            final ang = (i / 8.0) * pi * 2.0 + t * 15.0;
            final p = wheelPos + Offset(cos(ang) * 20.0, sin(ang) * 20.0);
            canvas.drawCircle(p, 8.5 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(fade));
            canvas.drawCircle(p + Offset(cos(ang + 0.4) * 4.0, sin(ang + 0.4) * 4.0), 4.5 * fade,
                Paint()..color = Colors.yellowAccent.withOpacity(fade));
          }
          canvas.drawCircle(wheelPos, 13.0 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
        }
        break;

      case 'rest':
        {
          canvas.drawCircle(
            attackerCenter,
            (22.0 + sin(t * pi) * 14.0) * fade,
            Paint()..color = Colors.lightBlueAccent.withOpacity(0.28 * fade),
          );
          final zPaint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * fade
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.lightBlueAccent.withOpacity(fade);
          for (int i = 0; i < 3; i++) {
            final zT = (t + i * 0.28) % 1.0;
            final zPos = attackerCenter + Offset(14.0 + i * 11.0, -8.0 - zT * 38.0);
            final zS = (6.0 + i * 1.5) * (1.0 - zT * 0.35);
            final zPath = Path()
              ..moveTo(zPos.dx - zS * 0.5, zPos.dy - zS * 0.5)
              ..lineTo(zPos.dx + zS * 0.5, zPos.dy - zS * 0.5)
              ..lineTo(zPos.dx - zS * 0.5, zPos.dy + zS * 0.5)
              ..lineTo(zPos.dx + zS * 0.5, zPos.dy + zS * 0.5);
            canvas.drawPath(zPath, zPaint);
          }
        }
        break;

      case 'snore':
        {
          for (int i = 0; i < 4; i++) {
            final st = ((t - i * 0.1) / 0.65).clamp(0.0, 1.0);
            if (st <= 0) continue;
            final wPos = Offset.lerp(attackerCenter, defenderCenter, st)!;
            canvas.drawCircle(
              wPos,
              (10.0 + st * 22.0) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.0 * fade
                ..color = (i.isEven ? Colors.white : Colors.lightBlueAccent).withOpacity((1.0 - st * 0.5) * fade),
            );
          }
        }
        break;

      case 'rollout':
        {
          final rollT = min(1.0, t * 1.25);
          final rollPos = Offset.lerp(attackerCenter, defenderCenter, rollT)! +
              Offset(0, -sin(rollT * pi * 3.0).abs() * 16.0);
          for (int d = 1; d <= 3; d++) {
            final dustPos = rollPos - unit * (d * 14.0);
            canvas.drawCircle(dustPos + const Offset(0, 10), (7.0 - d * 1.5) * fade,
                Paint()..color = Colors.brown.shade300.withOpacity(0.45 * fade));
          }
          _drawPolygonBoulder(canvas, rollPos, 18.0 * fade, t * 12.0, fade);
          if (t > 0.65) {
            _drawStarPath(canvas, defenderCenter, 22.0 * fade, 8.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'explosion':
        {
          // Arena-spanning blinding white & amber fireball detonation
          final boom = Curves.easeOutCubic.transform(min(1.0, t * 1.2));
          canvas.drawCircle(attackerCenter, (22.0 + boom * 150.0) * fade,
              Paint()..color = Colors.deepOrange.withOpacity(0.45 * fade));
          canvas.drawCircle(attackerCenter, (18.0 + boom * 115.0) * fade,
              Paint()..color = Colors.yellowAccent.withOpacity(0.62 * fade));
          canvas.drawCircle(attackerCenter, (14.0 + boom * 85.0) * fade,
              Paint()..color = Colors.white.withOpacity(0.85 * fade));
          for (int r = 0; r < 10; r++) {
            final ang = (r / 10.0) * pi * 2.0;
            final p1 = attackerCenter + Offset(cos(ang) * (20.0 + boom * 50.0), sin(ang) * (20.0 + boom * 50.0));
            final p2 = attackerCenter + Offset(cos(ang) * (40.0 + boom * 110.0), sin(ang) * (40.0 + boom * 110.0));
            canvas.drawLine(p1, p2,
                Paint()..color = Colors.amberAccent.withOpacity(fade)..strokeWidth = 4.0 * fade..strokeCap = StrokeCap.round);
          }
        }
        break;

      case 'extreme_speed':
        {
          // Hyper-velocity zip zigzags & golden sonic boom rings
          final midA = Offset.lerp(attackerCenter, defenderCenter, 0.45)! + perp * 28.0;
          final midB = Offset.lerp(attackerCenter, defenderCenter, 0.72)! - perp * 24.0;
          final reach = min(1.0, t * 1.8);
          final pts = [attackerCenter, midA, midB, defenderCenter];
          for (int i = 0; i < 3; i++) {
            final segT = ((reach * 3.0) - i).clamp(0.0, 1.0);
            if (segT <= 0) continue;
            canvas.drawLine(
              pts[i],
              Offset.lerp(pts[i], pts[i + 1], segT)!,
              Paint()
                ..color = Colors.amberAccent.withOpacity(0.65 * fade)
                ..strokeWidth = 11.0 * fade
                ..strokeCap = StrokeCap.round,
            );
            canvas.drawLine(
              pts[i],
              Offset.lerp(pts[i], pts[i + 1], segT)!,
              Paint()
                ..color = Colors.white.withOpacity(fade)
                ..strokeWidth = 5.0 * fade
                ..strokeCap = StrokeCap.round,
            );
          }
          if (t > 0.4) {
            _drawStarPath(canvas, defenderCenter, 32.0 * fade, 11.0 * fade, Colors.amberAccent, fade, points: 6);
          }
        }
        break;

      case 'seed_bomb':
        {
          for (int i = -1; i <= 1; i++) {
            final lt = ((t - (i + 1) * 0.08) / 0.5).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final arc = sin(lt * pi) * (42.0 + i.abs() * 12.0);
            final sPos = Offset.lerp(attackerCenter, defenderCenter, lt)! + perp * (i * 13.0) - Offset(0, arc);
            canvas.drawCircle(sPos, 7.5 * fade, Paint()..color = const Color(0xFF2E7D32).withOpacity(fade));
            canvas.drawCircle(sPos + const Offset(-2, -2), 2.5 * fade,
                Paint()..color = Colors.lightGreenAccent.withOpacity(fade));
          }
          if (t > 0.45) {
            final exp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
            canvas.drawCircle(defenderCenter, (18.0 + exp * 30.0) * fade,
                Paint()..color = Colors.lightGreenAccent.withOpacity(0.65 * fade));
            _drawStarPath(canvas, defenderCenter, (18.0 + exp * 22.0) * fade, 8.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'transform':
        {
          final colors = [Colors.pinkAccent, Colors.purpleAccent, Colors.cyanAccent, Colors.amberAccent];
          for (int i = 0; i < 4; i++) {
            final ang = t * pi * 4.0 + i * (pi / 2.0);
            final r = (14.0 + i * 7.0 + sin(t * pi) * 14.0) * fade;
            canvas.drawOval(
              Rect.fromCenter(center: attackerCenter, width: r * 2.1, height: r * 1.4),
              Paint()..style = PaintingStyle.stroke..strokeWidth = 2.8 * fade..color = colors[i].withOpacity(fade),
            );
            canvas.drawCircle(
              attackerCenter + Offset(cos(ang) * 26.0, sin(ang) * 18.0),
              4.0 * fade,
              Paint()..color = colors[i].withOpacity(fade),
            );
          }
        }
        break;

      case 'struggle':
        {
          for (int s = 0; s < 4; s++) {
            final st = ((t - s * 0.1) / 0.45).clamp(0.0, 1.0);
            if (st <= 0) continue;
            final ang = s * 0.9 + 0.3;
            final off = Offset(cos(ang) * 24.0, sin(ang) * 24.0);
            canvas.drawLine(
              defenderCenter - off,
              Offset.lerp(defenderCenter - off, defenderCenter + off, st)!,
              Paint()..color = Colors.redAccent.withOpacity(fade)..strokeWidth = 5.0 * fade..strokeCap = StrokeCap.round,
            );
          }
          _drawStarPath(canvas, defenderCenter, 20.0 * fade, 7.0 * fade, Colors.white, fade);
          if (t > 0.4) {
            canvas.drawCircle(
              attackerCenter,
              (12.0 + t * 14.0) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0 * fade..color = Colors.red.withOpacity(0.75 * fade),
            );
          }
        }
        break;

      case 'soft_boiled':
        {
          canvas.drawOval(
            Rect.fromCenter(center: attackerCenter, width: 32.0 * fade, height: 42.0 * fade),
            Paint()..color = const Color(0xFFFFF59D).withOpacity(0.68 * fade),
          );
          for (int p = 0; p < 5; p++) {
            final lt = (t + p * 0.18) % 1.0;
            final pt = attackerCenter + Offset((p - 2.0) * 12.0, 10.0 - lt * 38.0);
            _drawStarPath(canvas, pt, 6.0 * fade, 2.5 * fade, Colors.greenAccent, fade, points: 4);
          }
        }
        break;

      case 'light_screen':
        {
          // Shimmering hexagonal prismatic shield barrier
          final lsCenter = attackerCenter + unit * 28.0;
          final w = 16.0 * fade;
          final h = 34.0 * fade;
          final hex = Path()
            ..moveTo(lsCenter.dx, lsCenter.dy - h)
            ..lineTo(lsCenter.dx + w, lsCenter.dy - h * 0.45)
            ..lineTo(lsCenter.dx + w, lsCenter.dy + h * 0.45)
            ..lineTo(lsCenter.dx, lsCenter.dy + h)
            ..lineTo(lsCenter.dx - w, lsCenter.dy + h * 0.45)
            ..lineTo(lsCenter.dx - w, lsCenter.dy - h * 0.45)
            ..close();
          canvas.drawPath(hex, Paint()..color = Colors.lightBlueAccent.withOpacity(0.35 * fade));
          canvas.drawPath(
            hex,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5 * fade..color = Colors.cyanAccent.withOpacity(fade),
          );
          canvas.drawLine(
            lsCenter - Offset(0, h * 0.7),
            lsCenter + Offset(0, h * 0.7),
            Paint()..color = Colors.white.withOpacity(0.7 * fade)..strokeWidth = 2.0 * fade,
          );
        }
        break;

      case 'mega_drain':
      case 'giga_drain':
        {
          final isGiga = moveId == 'giga_drain';
          for (int i = 0; i < (isGiga ? 7 : 5); i++) {
            final drainT = ((t - i * 0.08) / 0.62).clamp(0.0, 1.0);
            if (drainT <= 0) continue;
            final wave = perp * (sin(drainT * pi * 3 + i) * 14.0);
            final pos = Offset.lerp(defenderCenter, attackerCenter, drainT)! + wave;
            canvas.drawCircle(pos, (isGiga ? 8.0 : 6.0) * fade,
                Paint()..color = Colors.lightGreenAccent.withOpacity(fade));
            canvas.drawCircle(pos, 3.0 * fade,
                Paint()..color = Colors.white.withOpacity(fade));
          }
          if (t > 0.48) {
            canvas.drawCircle(
              attackerCenter,
              (16 + (t - 0.48) * 34) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 * fade
                ..color = Colors.greenAccent.withOpacity(fade),
            );
          }
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
        {
          final zhT = min(1.0, t * 1.45);
          final zhPos = Offset.lerp(attackerCenter, defenderCenter, zhT)!;
          canvas.drawLine(
            attackerCenter,
            zhPos,
            Paint()
              ..color = Colors.purpleAccent.withOpacity(0.45 * fade)
              ..strokeWidth = 14.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(zhPos, 20.0 * fade, Paint()..color = Colors.deepPurpleAccent.withOpacity(0.8 * fade));
          canvas.drawCircle(zhPos, 11.0 * fade, Paint()..color = Colors.pinkAccent.withOpacity(fade));
          if (t > 0.42) {
            final imp = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
            for (int r = 0; r < 2; r++) {
              canvas.drawCircle(
                defenderCenter,
                (18.0 + r * 14.0 + imp * 22.0) * fade,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3.5 * fade
                  ..color = (r == 0 ? Colors.pinkAccent : Colors.cyanAccent).withOpacity(fade),
              );
            }
          }
        }
        break;

      case 'sharpen':
      case 'withdraw':
        {
          // Rotating faceted polygon shell snapping around attacker
          final r = (24.0 + (1.0 - min(1.0, t * 1.5)) * 18.0) * fade;
          final shell = Path();
          for (int i = 0; i < 6; i++) {
            final ang = (i / 6.0) * pi * 2.0 + t * 2.5;
            final pt = attackerCenter + Offset(cos(ang) * r, sin(ang) * r);
            if (i == 0) {
              shell.moveTo(pt.dx, pt.dy);
            } else {
              shell.lineTo(pt.dx, pt.dy);
            }
          }
          shell.close();
          canvas.drawPath(shell, Paint()..color = Colors.cyanAccent.withOpacity(0.24 * fade));
          canvas.drawPath(
            shell,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2 * fade..color = Colors.cyanAccent.withOpacity(fade),
          );
          _drawStarPath(canvas, attackerCenter + const Offset(-14, -14), 8.0 * fade, 3.0 * fade, Colors.white, fade, points: 4);
        }
        break;

      case 'recover':
        canvas.drawCircle(
          attackerCenter,
          (18 + sin(t * pi) * 24) * fade,
          Paint()..color = Colors.greenAccent.withOpacity(0.32 * fade),
        );
        for (int p = 0; p < 4; p++) {
          final lt = (t + p * 0.18) % 1.0;
          final pt = attackerCenter + Offset((p - 1.5) * 14.0, 8 - lt * 40.0);
          final plusPaint = Paint()
            ..color = Colors.greenAccent.withOpacity(fade)
            ..strokeWidth = 3.0
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(pt + const Offset(-5, 0), pt + const Offset(5, 0), plusPaint);
          canvas.drawLine(pt + const Offset(0, -5), pt + const Offset(0, 5), plusPaint);
        }
        break;

      case 'spike_cannon':
        {
          for (int i = 0; i < 6; i++) {
            final sT = ((t - i * 0.07) / 0.48).clamp(0.0, 1.0);
            if (sT <= 0) continue;
            final off = perp * ((i - 2.5) * 6.5);
            final pos = Offset.lerp(attackerCenter, defenderCenter, sT)! + off;
            final tip = pos + unit * 12.0;
            final tail = pos - unit * 10.0;
            final spike = Path()
              ..moveTo(tip.dx, tip.dy)
              ..lineTo((tail + perp * 4.0).dx, (tail + perp * 4.0).dy)
              ..lineTo((tail - perp * 4.0).dx, (tail - perp * 4.0).dy)
              ..close();
            canvas.drawPath(spike, Paint()..color = Colors.white.withOpacity(fade));
            canvas.drawLine(pos - unit * 22.0, tail,
                Paint()..color = Colors.amberAccent.withOpacity(0.7 * fade)..strokeWidth = 2.0 * fade);
          }
          if (t > 0.42) {
            _drawStarPath(canvas, defenderCenter, 20.0 * fade, 7.0 * fade, Colors.white, fade, points: 5);
          }
        }
        break;

      case 'aqua_jet':
        {
          final ajT = min(1.0, t * 1.45);
          final ajPos = Offset.lerp(attackerCenter, defenderCenter, ajT)!;
          // Sleek aerodynamic water cloak + swept V-wake + impact splash
          canvas.drawLine(
            attackerCenter,
            ajPos,
            Paint()
              ..color = Colors.lightBlueAccent.withOpacity(0.55 * fade)
              ..strokeWidth = 18.0 * fade
              ..strokeCap = StrokeCap.round,
          );
          final tip = ajPos + unit * 24.0;
          final wake = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo((ajPos - unit * 22.0 + perp * 16.0).dx, (ajPos - unit * 22.0 + perp * 16.0).dy)
            ..lineTo((ajPos - unit * 12.0).dx, (ajPos - unit * 12.0).dy)
            ..lineTo((ajPos - unit * 22.0 - perp * 16.0).dx, (ajPos - unit * 22.0 - perp * 16.0).dy)
            ..close();
          canvas.drawPath(wake, Paint()..color = Colors.cyanAccent.withOpacity(0.88 * fade));
          canvas.drawPath(
            wake,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.white.withOpacity(fade),
          );
          if (t > 0.48) {
            canvas.drawCircle(
              defenderCenter,
              (16.0 + (t - 0.48) * 52.0) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5 * fade..color = Colors.white.withOpacity(fade),
            );
          }
        }
        break;

      case 'iron_head':
        {
          final ihT = min(1.0, t * 1.4);
          final ihPos = Offset.lerp(attackerCenter, defenderCenter, ihT)!;
          canvas.drawLine(
            attackerCenter,
            ihPos,
            Paint()..color = Colors.blueGrey.shade300.withOpacity(0.55 * fade)..strokeWidth = 14.0 * fade..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(ihPos, 20.0 * fade, Paint()..color = Colors.blueGrey.shade200.withOpacity(fade));
          canvas.drawCircle(ihPos + const Offset(-4, -4), 8.0 * fade, Paint()..color = Colors.white.withOpacity(0.9 * fade));
          if (t > 0.45) {
            final imp = ((t - 0.45) / 0.55).clamp(0.0, 1.0);
            _drawStarPath(canvas, defenderCenter, (22.0 + imp * 16.0) * fade, 8.0 * fade, Colors.white, fade, points: 6);
            canvas.drawCircle(
              defenderCenter,
              (16.0 + imp * 30.0) * fade,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5 * fade..color = Colors.blueGrey.shade100.withOpacity(fade),
            );
          }
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
        {
          // Double-helix spectral orbs weaving to defender, then orbiting dizzy stars
          final crT = (t / 0.62).clamp(0.0, 1.0);
          for (int i = 0; i < 2; i++) {
            final sign = i == 0 ? 1.0 : -1.0;
            final trailPath = Path();
            for (int seg = 0; seg <= 12; seg++) {
              final f = (seg / 12.0) * crT;
              final pt = Offset.lerp(attackerCenter, defenderCenter, f)! + perp * (sin(f * pi * 3.5) * 20.0 * sign);
              if (seg == 0) {
                trailPath.moveTo(pt.dx, pt.dy);
              } else {
                trailPath.lineTo(pt.dx, pt.dy);
              }
            }
            final col = i == 0 ? Colors.amberAccent : Colors.purpleAccent;
            canvas.drawPath(
              trailPath,
              Paint()..style = PaintingStyle.stroke..strokeWidth = 3.0 * fade..color = col.withOpacity(0.55 * fade),
            );
            final orbPos = Offset.lerp(attackerCenter, defenderCenter, crT)! +
                perp * (sin(crT * pi * 3.5) * 20.0 * sign);
            canvas.drawCircle(orbPos, 8.5 * fade, Paint()..color = col.withOpacity(fade));
          }
          if (t > 0.5) {
            for (int d = 0; d < 3; d++) {
              final ang = (d / 3.0) * pi * 2.0 + t * 10.0;
              final starPt = defenderCenter + Offset(cos(ang) * 24.0, -24.0 + sin(ang) * 9.0);
              _drawStarPath(canvas, starPt, 8.0 * fade, 3.5 * fade, Colors.amberAccent, fade);
            }
          }
        }
        break;

      case 'double_slap':
        for (int s = 0; s < 2; s++) {
          final st = ((t - s * 0.28) / 0.48).clamp(0.0, 1.0);
          if (st <= 0) continue;
          final side = s == 0 ? -1.0 : 1.0;
          canvas.drawArc(
            Rect.fromCenter(center: defenderCenter, width: 58, height: 34),
            s == 0 ? -0.5 : pi - 0.8,
            1.4,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.pinkAccent.withOpacity(fade),
          );
          _drawStarPath(
            canvas,
            defenderCenter + Offset(side * 12, -4),
            12 * fade,
            5 * fade,
            Colors.white,
            fade,
          );
        }
        break;

      case 'fury_attack':
        for (int i = 0; i < 5; i++) {
          final st = ((t - i * 0.08) / 0.42).clamp(0.0, 1.0);
          if (st <= 0) continue;
          final off = Offset((i - 2) * 8.0, (i % 2 == 0 ? -1 : 1) * 10.0);
          final p2 = defenderCenter + off;
          final p1 = p2 - unit * (28 * (1.0 - st * 0.4));
          canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = 3.5 * fade
              ..strokeCap = StrokeCap.round,
          );
        }
        break;

      case 'pound':
      case 'slam':
        {
          final isSlam = moveId == 'slam';
          canvas.drawArc(
            Rect.fromCenter(
                center: defenderCenter,
                width: isSlam ? 66 : 48,
                height: isSlam ? 42 : 30),
            -pi * 0.85,
            pi * 0.85 * min(1.0, t * 1.6),
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (isSlam ? 7 : 5) * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.amberAccent.withOpacity(fade),
          );
          if (t > 0.35) {
            canvas.drawCircle(
              defenderCenter,
              (12 + (t - 0.35) * (isSlam ? 44 : 28)) * fade,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = Colors.white.withOpacity(fade),
            );
          }
        }
        break;

      case 'smokescreen':
        {
          // Pressurized dark smoke plume streaming from attacker to shroud defender
          final reach = min(1.0, t * 1.45);
          for (int i = 0; i < 11; i++) {
            final frac = min(1.0, reach * (0.4 + i * 0.08));
            final origin = Offset.lerp(attackerCenter, defenderCenter, frac)!;
            final ang = (i / 11.0) * pi * 2.0 + t * 2.5;
            final r = t * 30.0 * (i > 4 ? 1.0 : 0.45);
            final p = origin + Offset(cos(ang) * r, sin(ang) * r * 0.72);
            canvas.drawCircle(
              p,
              (10.0 + (i % 3) * 4.5) * fade,
              Paint()..color = (i.isEven ? Colors.blueGrey.shade800 : Colors.blueGrey.shade600).withOpacity(0.76 * fade),
            );
          }
        }
        break;

      case 'comet_punch':
        {
          for (int i = 0; i < 6; i++) {
            final cpT = ((t - i * 0.07) / 0.46).clamp(0.0, 1.0);
            if (cpT <= 0) continue;
            final ang = i * 1.25;
            final strikeOff = Offset(cos(ang) * 20.0, sin(ang) * 18.0);
            final pos = defenderCenter + strikeOff;
            canvas.drawLine(
              pos - strikeOff * (1.2 - cpT * 0.6),
              pos,
              Paint()..color = Colors.amberAccent.withOpacity(0.8 * fade)..strokeWidth = 5.0 * fade..strokeCap = StrokeCap.round,
            );
            canvas.drawCircle(pos, 9.0 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
            _drawStarPath(canvas, pos, 13.0 * fade, 5.5 * fade, Colors.white, fade);
          }
        }
        break;

      case 'seismic_toss':
        {
          // Orbital toss arc launching high overhead then slamming down in a ground crater
          final arcY = -sin(t * pi) * 76.0;
          final slam = Offset.lerp(defenderCenter + const Offset(0, -6), defenderCenter, min(1.0, t * 1.25))!;
          final tossPos = slam + Offset(sin(t * pi * 2.0) * 18.0, arcY);
          canvas.drawCircle(
            tossPos,
            18.0 * fade,
            Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5 * fade..color = Colors.amberAccent.withOpacity(fade),
          );
          canvas.drawCircle(tossPos, 13.0 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(0.75 * fade));
          if (t > 0.55) {
            final imp = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
            canvas.drawOval(
              Rect.fromCenter(center: defenderCenter + const Offset(0, 22), width: 34.0 + imp * 72.0, height: 14.0 + imp * 24.0),
              Paint()..style = PaintingStyle.stroke..strokeWidth = 4.5 * fade..color = Colors.brown.shade300.withOpacity(fade),
            );
            _drawStarPath(canvas, defenderCenter, (18.0 + imp * 16.0) * fade, 7.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'thrash':
        {
          for (int i = 0; i < 6; i++) {
            final thT = ((t - i * 0.08) / 0.45).clamp(0.0, 1.0);
            if (thT <= 0) continue;
            final ang = i * 1.05;
            final dirVec = Offset(cos(ang) * 28.0, sin(ang) * 28.0);
            canvas.drawLine(
              defenderCenter - dirVec,
              Offset.lerp(defenderCenter - dirVec, defenderCenter + dirVec, thT)!,
              Paint()
                ..color = (i.isEven ? Colors.redAccent : Colors.deepOrangeAccent).withOpacity(fade)
                ..strokeWidth = 5.5 * fade
                ..strokeCap = StrokeCap.round,
            );
            _drawStarPath(canvas, defenderCenter + dirVec * 0.3, 12.0 * fade, 5.0 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      // ─── GEN 1 TM MOVES VFX ─────────────────────────────────────────────
      case 'bide':
        canvas.drawCircle(
          attackerCenter,
          (34 * (1.0 - min(1.0, t * 1.2) * 0.55)) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5 * fade
            ..color = Colors.redAccent.withOpacity(fade),
        );
        if (!isSelfTarget && t > 0.45) {
          final bt = (t - 0.45) / 0.55;
          canvas.drawLine(
            attackerCenter,
            Offset.lerp(attackerCenter, defenderCenter, min(1.0, bt * 2.0))!,
            Paint()
              ..color = Colors.deepOrangeAccent.withOpacity(fade)
              ..strokeWidth = 10 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(defenderCenter, 16 + bt * 30,
              Paint()..color = Colors.amberAccent.withOpacity(0.55 * fade));
        }
        break;

      case 'counter':
        canvas.drawCircle(
          attackerCenter,
          24 * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * fade
            ..color = Colors.amberAccent.withOpacity(fade),
        );
        if (t > 0.25) {
          final ct = min(1.0, (t - 0.25) / 0.5);
          final pos = Offset.lerp(attackerCenter, defenderCenter, ct)!;
          canvas.drawCircle(pos, 18 * fade, Paint()..color = Colors.deepOrangeAccent.withOpacity(fade));
          _drawStarPath(canvas, defenderCenter, 26 * fade, 10 * fade, Colors.amberAccent, fade);
        }
        break;

      case 'double_edge':
        {
          final pos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.45))!;
          canvas.drawLine(
            attackerCenter,
            pos,
            Paint()
              ..color = Colors.redAccent.withOpacity(0.85 * fade)
              ..strokeWidth = 14 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(pos, 22 * fade, Paint()..color = Colors.white.withOpacity(0.9 * fade));
          if (t > 0.42) {
            final st = (t - 0.42) / 0.58;
            canvas.drawCircle(
              defenderCenter,
              18 + st * 44,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5 * fade
                ..color = Colors.redAccent.withOpacity(fade),
            );
          }
        }
        break;

      case 'double_team':
        for (int sign in [-1, 1]) {
          final spread = sin(t * pi) * 32.0 * sign;
          canvas.drawOval(
            Rect.fromCenter(
              center: attackerCenter + Offset(spread, -4),
              width: 34,
              height: 48,
            ),
            Paint()..color = Colors.cyanAccent.withOpacity(0.38 * fade),
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: attackerCenter + Offset(spread, -4),
              width: 34,
              height: 48,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0 * fade
              ..color = Colors.white.withOpacity(0.75 * fade),
          );
        }
        break;

      case 'dream_eater':
        for (int i = 0; i < 6; i++) {
          final dt = ((t - i * 0.08) / 0.62).clamp(0.0, 1.0);
          if (dt <= 0) continue;
          final arc = perp * (sin(dt * pi * 2 + i) * 16.0);
          final pos = Offset.lerp(defenderCenter, attackerCenter, dt)! + arc;
          canvas.drawCircle(
            pos,
            8 * fade,
            Paint()..color = (i.isEven ? Colors.purpleAccent : Colors.pinkAccent).withOpacity(0.85 * fade),
          );
        }
        canvas.drawArc(
          Rect.fromCenter(center: defenderCenter + const Offset(0, -24), width: 22, height: 22),
          0.4,
          pi * 1.35,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * fade
            ..color = Colors.amberAccent.withOpacity(fade),
        );
        break;

      case 'fissure':
        {
          final base = defenderCenter + const Offset(0, 18);
          final crack = Path()
            ..moveTo(base.dx - 44, base.dy + 6)
            ..lineTo(base.dx - 18, base.dy - 4)
            ..lineTo(base.dx - 4, base.dy + 8)
            ..lineTo(base.dx + 16, base.dy - 6)
            ..lineTo(base.dx + 44, base.dy + 5);
          canvas.drawPath(
            crack,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8 * fade
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF3E2723).withOpacity(fade),
          );
          canvas.drawPath(
            crack,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..strokeCap = StrokeCap.round
              ..color = Colors.deepOrangeAccent.withOpacity(fade),
          );
          for (int b = -2; b <= 2; b++) {
            final rp = base + Offset(b * 14.0, -sin(t * pi) * (28 + (b.abs() * 8)));
            _drawPolygonBoulder(canvas, rp, 8 * fade, t * 5 + b, fade);
          }
        }
        break;

      case 'metronome':
        {
          final pivot = attackerCenter + const Offset(0, -48);
          final swing = sin(t * pi * 5) * 0.85;
          final tip = pivot + Offset(sin(swing) * 34, cos(swing) * 34);
          canvas.drawLine(
            pivot,
            tip,
            Paint()
              ..color = Colors.white.withOpacity(fade)
              ..strokeWidth = 4 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(tip, 6 * fade, Paint()..color = Colors.amberAccent.withOpacity(fade));
          _drawStarPath(canvas, tip, 10 * fade, 4 * fade, Colors.cyanAccent, fade, points: 4);
        }
        break;

      case 'mimic':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: defenderCenter, width: 52 * fade, height: 52 * fade),
            const Radius.circular(10),
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * fade
            ..color = Colors.pinkAccent.withOpacity(fade),
        );
        canvas.drawLine(
          defenderCenter,
          Offset.lerp(defenderCenter, attackerCenter, min(1.0, t * 1.4))!,
          Paint()
            ..color = Colors.cyanAccent.withOpacity(0.75 * fade)
            ..strokeWidth = 3.5 * fade,
        );
        break;

      case 'psywave':
        {
          final waveColors = [Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent];
          final reach = min(1.0, t / 0.65);
          for (int w = 0; w < 3; w++) {
            final pth = Path();
            for (int s = 0; s <= 18; s++) {
              final f = (s / 18.0) * reach;
              final amp = sin(f * pi * 6 - t * 14 + w * 1.2) * (10 + w * 4.0);
              final pt = Offset.lerp(attackerCenter, defenderCenter, f)! + perp * amp;
              if (s == 0) {
                pth.moveTo(pt.dx, pt.dy);
              } else {
                pth.lineTo(pt.dx, pt.dy);
              }
            }
            canvas.drawPath(
              pth,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.5 * fade
                ..color = waveColors[w].withOpacity(0.9 * fade),
            );
          }
        }
        break;

      case 'rage':
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            attackerCenter,
            (18 + i * 11 + sin(t * pi * 3) * 6) * fade,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..color = Colors.redAccent.withOpacity(fade),
          );
        }
        for (int s = 0; s < 5; s++) {
          final lt = (t + s * 0.2) % 1.0;
          canvas.drawCircle(
            attackerCenter + Offset((s - 2) * 11.0, 12 - lt * 42),
            4 * fade,
            Paint()..color = Colors.deepOrangeAccent.withOpacity(fade),
          );
        }
        break;

      case 'razor_wind':
        if (isSelfTarget) {
          for (int i = 0; i < 3; i++) {
            final ang = t * 10 + i * (pi * 2 / 3);
            canvas.drawArc(
              Rect.fromCenter(center: attackerCenter, width: 58, height: 34),
              ang,
              0.9,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 4 * fade
                ..strokeCap = StrokeCap.round
                ..color = (i.isEven ? Colors.white : Colors.cyanAccent).withOpacity(fade),
            );
          }
        } else {
          for (int i = 0; i < 2; i++) {
            final lt = ((t - i * 0.2) / 0.55).clamp(0.0, 1.0);
            if (lt <= 0) continue;
            final pos = Offset.lerp(attackerCenter, defenderCenter, lt)!;
            canvas.drawArc(
              Rect.fromCenter(center: pos, width: 54, height: 22),
              -0.3,
              pi + 0.6,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 5 * fade
                ..strokeCap = StrokeCap.round
                ..color = (i == 0 ? Colors.white : Colors.cyanAccent).withOpacity(fade),
            );
          }
        }
        break;

      case 'reflect':
        {
          final shieldCenter = attackerCenter + unit * 26;
          final hex = Path();
          for (int i = 0; i < 6; i++) {
            final a = (i / 6) * pi * 2;
            final pt = shieldCenter + Offset(cos(a) * 20 * fade, sin(a) * 28 * fade);
            if (i == 0) {
              hex.moveTo(pt.dx, pt.dy);
            } else {
              hex.lineTo(pt.dx, pt.dy);
            }
          }
          hex.close();
          canvas.drawPath(hex, Paint()..color = Colors.amberAccent.withOpacity(0.28 * fade));
          canvas.drawPath(
            hex,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2 * fade
              ..color = Colors.amberAccent.withOpacity(fade),
          );
        }
        break;

      case 'self_destruct':
        canvas.drawCircle(
          attackerCenter,
          (22 + t * 88) * fade,
          Paint()..color = Colors.white.withOpacity(0.88 * fade),
        );
        canvas.drawCircle(
          attackerCenter,
          (26 + t * 72) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * fade
            ..color = Colors.deepOrangeAccent.withOpacity(fade),
        );
        break;

      case 'skull_bash':
        canvas.drawCircle(
          attackerCenter,
          24 * (1.0 - min(1.0, t * 1.6) * 0.4) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * fade
            ..color = const Color(0xFFF5F5DC).withOpacity(fade),
        );
        if (!isSelfTarget) {
          final sbPos = Offset.lerp(attackerCenter, defenderCenter, min(1.0, t * 1.45))!;
          canvas.drawCircle(sbPos, 20 * fade, Paint()..color = const Color(0xFFF5F5DC).withOpacity(fade));
          if (t > 0.42) {
            _drawStarPath(canvas, defenderCenter, 28 * fade, 11 * fade, Colors.amberAccent, fade);
          }
        }
        break;

      case 'sky_attack':
        if (isSelfTarget) {
          canvas.drawCircle(
            attackerCenter,
            (22 + sin(t * pi) * 14) * fade,
            Paint()..color = Colors.amberAccent.withOpacity(0.45 * fade),
          );
          for (int f = 0; f < 5; f++) {
            final ang = (f / 5) * pi * 2 + t * 6;
            final fp = attackerCenter + Offset(cos(ang) * 28, sin(ang) * 22);
            _drawStarPath(canvas, fp, 7 * fade, 2.5 * fade, Colors.white, fade, points: 4);
          }
        } else {
          final diveT = min(1.0, t * 1.4);
          final pos = Offset.lerp(attackerCenter, defenderCenter, diveT)!;
          canvas.drawLine(
            attackerCenter,
            pos,
            Paint()
              ..color = Colors.amberAccent.withOpacity(0.92 * fade)
              ..strokeWidth = 14 * fade
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(pos, 22 * fade, Paint()..color = Colors.white.withOpacity(fade));
          if (t > 0.4) {
            for (int f = 0; f < 6; f++) {
              final ang = (f / 6) * pi * 2 + t * 4;
              final fp = defenderCenter + Offset(cos(ang) * 34, sin(ang) * 28);
              _drawStarPath(canvas, fp, 8 * fade, 3 * fade, Colors.cyanAccent, fade, points: 4);
            }
          }
        }
        break;

      case 'substitute':
        canvas.drawCircle(
          attackerCenter,
          26 * sin(min(1.0, t * 1.2) * pi * 0.65) * fade,
          Paint()..color = const Color(0xFF4DB6AC).withOpacity(0.55 * fade),
        );
        canvas.drawOval(
          Rect.fromCenter(center: attackerCenter, width: 32 * fade, height: 38 * fade),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * fade
            ..color = Colors.greenAccent.withOpacity(fade),
        );
        break;

      case 'teleport':
        {
          final squeeze = (1.0 - t * 0.7).clamp(0.15, 1.0);
          canvas.drawOval(
            Rect.fromCenter(center: attackerCenter, width: 46 * squeeze, height: (56 + t * 44) * fade),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.5 * fade
              ..color = Colors.cyanAccent.withOpacity(fade),
          );
          canvas.drawLine(
            attackerCenter + const Offset(0, -52),
            attackerCenter + const Offset(0, 42),
            Paint()
              ..color = Colors.purpleAccent.withOpacity(0.75 * fade)
              ..strokeWidth = 6 * squeeze,
          );
        }
        break;

      case 'whirlwind':
        for (int i = 0; i < 6; i++) {
          final yOff = 24 - i * 13.0;
          final w = 18 + i * 11.0;
          canvas.drawOval(
            Rect.fromCenter(
              center: defenderCenter + Offset(sin(t * 16 + i) * 12, yOff),
              width: w,
              height: 11,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade
              ..color = (i.isEven ? Colors.white : Colors.lightBlueAccent).withOpacity(0.9 * fade),
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
      oldDelegate.defenderCenter != defenderCenter ||
      oldDelegate.attackerSize != attackerSize ||
      oldDelegate.defenderSize != defenderSize;
}
