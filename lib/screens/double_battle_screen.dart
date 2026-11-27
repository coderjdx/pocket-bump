import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/battle_engine.dart';
import '../services/battle_sprite_metrics.dart';
import '../services/double_battle_engine.dart';
import '../services/pokedex_database.dart';
import '../services/pvp_link_service.dart';
import '../services/sound_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/move_pp_picker_dialog.dart';
import '../widgets/move_vfx_effects.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/sound_controls.dart';
import '../widgets/trainer_sprite.dart';
import 'evolution_screen.dart';

class DoubleBattleScreen extends StatefulWidget {
  final List<PokemonInstance> opponentTeam;
  final String? trainerName;
  final String? trainerTitle;
  final String? trainerIntroLine;
  final String? trainerDefeatLine;
  final String? opponentSpriteId;
  final String? partnerSpriteId;
  final int prizeMoney;
  final bool preservePartyHpOnExit;
  final String? battleBackgroundAsset;
  final PvpMatchSession? pvpSession;
  final String? continueButtonLabel;
  final String? defeatButtonLabel;
  final BattleBgmCategory? bgmCategory;
  final bool isFrontierBattle;
  final bool clearBattlePartyOverrideOnExit;

  const DoubleBattleScreen({
    super.key,
    required this.opponentTeam,
    this.trainerName,
    this.trainerTitle,
    this.trainerIntroLine,
    this.trainerDefeatLine,
    this.opponentSpriteId,
    this.partnerSpriteId,
    this.prizeMoney = 0,
    this.preservePartyHpOnExit = false,
    this.battleBackgroundAsset,
    this.pvpSession,
    this.continueButtonLabel,
    this.defeatButtonLabel,
    this.bgmCategory,
    this.isFrontierBattle = false,
    this.clearBattlePartyOverrideOnExit = false,
  });

  @override
  State<DoubleBattleScreen> createState() => _DoubleBattleScreenState();
}

class _DoubleBattleScreenState extends State<DoubleBattleScreen>
    with TickerProviderStateMixin {
  late Trainer _trainer;
  late List<PokemonInstance> _opponentParty;
  // Active slots: 0 = P-Left, 1 = P-Right, 2 = O-Left, 3 = O-Right
  final List<PokemonInstance?> _slots = List<PokemonInstance?>.filled(4, null);
  final List<int> _displayedHps = [0, 0, 0, 0];
  final List<bool> _showSlotPokemon = [false, false, false, false];
  final List<double> _slotSummonScale = [0.05, 0.05, 0.05, 0.05];
  final List<bool> _visualFainted = [false, false, false, false];
  final List<bool> _slotFlash = [false, false, false, false];
  final List<bool> _slotSubmerged = [false, false, false, false];
  final List<Offset> _slotLungeOffset = [
    Offset.zero,
    Offset.zero,
    Offset.zero,
    Offset.zero,
  ];
  final List<bool> _slotSummonBurst = [false, false, false, false];
  final List<bool> _slotShinySparkle = [false, false, false, false];

  final List<PokemonInstance> _participatedPokemon = [];
  final Set<PokemonInstance> _expAwardedFoes = {};

  final BattleFieldState _fieldState = BattleFieldState();

  bool _playerWon = false;
  bool _battleEnded = false;
  bool _didHealOnExit = false;
  bool _didRecordPvpResult = false;
  bool _arenaAssetsReady = false;
  bool _introComplete = false;
  bool _isProcessingTurn = true;

  // Trainer sprites for intro & defeat speech
  bool _showOpponentTrainerSprite = false;
  double _opponentTrainerSlideX = 0.0;
  int _opponentTrainerPose = 0;
  bool _showTrainerSprite = false;
  double _trainerSlideX = 0.0;
  int _trainerPose = 0;

  // Command deck selection state (0 = player Left, 1 = player Right)
  int _commandSlot = 0;
  int _deckPage = 0; // 0 = Main Actions, 1 = Move List, 2 = Target Picker
  Move? _pendingTargetMove;
  final List<DoubleBattleSlotAction?> _queuedPlayerActions = [null, null];

  // Narration & Callouts
  String _currentMessage = "";
  String? _floatingCallout;
  int _calloutSlot = 0;
  Color _calloutColor = Colors.amberAccent;

  // VFX state
  late final AnimationController _vfxController;
  late final AnimationController _arenaShakeController;
  late final List<AnimationController> _shakeControllers;
  String? _activeMoveId;
  PokemonType? _activeVfxType;
  MoveCategory _activeVfxCategory = MoveCategory.physical;
  int _vfxActorSlot = 0;
  List<int> _vfxTargetSlots = const [];
  final Map<int, Offset> _slotCenters = {};

  int _pvpTurnIndex = 0;

  String get _resolvedBattleBackgroundAsset =>
      widget.battleBackgroundAsset ?? 'assets/images/battle_bg_pvp_arena.png';

  BattleBgmCategory get _resolvedBgmCategory {
    if (widget.bgmCategory != null) return widget.bgmCategory!;
    if (widget.pvpSession != null) return BattleBgmCategory.special;
    return BattleBgmCategory.gym;
  }

  void _recordParticipant(PokemonInstance mon) {
    if (!_participatedPokemon.contains(mon)) {
      _participatedPokemon.add(mon);
    }
  }

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

  @override
  void initState() {
    super.initState();
    _trainer = Provider.of<Trainer>(context, listen: false);
    _opponentParty = widget.opponentTeam;

    _vfxController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _arenaShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _shakeControllers = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
      ),
    );

    // Pick initial 2 conscious player Pokémon
    final consciousPlayer = _trainer.party.where((p) => !p.isFainted).toList();
    if (consciousPlayer.isNotEmpty) {
      _slots[0] = consciousPlayer[0];
      _displayedHps[0] = consciousPlayer[0].currentHp;
      _recordParticipant(consciousPlayer[0]);
    }
    if (consciousPlayer.length >= 2) {
      _slots[1] = consciousPlayer[1];
      _displayedHps[1] = consciousPlayer[1].currentHp;
      _recordParticipant(consciousPlayer[1]);
    }

    // Pick initial 2 conscious opponent Pokémon
    final consciousOpp = _opponentParty.where((p) => !p.isFainted).toList();
    if (consciousOpp.isNotEmpty) {
      _slots[2] = consciousOpp[0];
      _displayedHps[2] = consciousOpp[0].currentHp;
      _trainer.markPokemonSeen(consciousOpp[0].species.id);
    }
    if (consciousOpp.length >= 2) {
      _slots[3] = consciousOpp[1];
      _displayedHps[3] = consciousOpp[1].currentHp;
      _trainer.markPokemonSeen(consciousOpp[1].species.id);
    }

    SoundService.instance.playBattleBgm(_resolvedBgmCategory);

    if (widget.pvpSession != null) {
      widget.pvpSession!.onPeerForfeit = _handlePeerForfeit;
      widget.pvpSession!.startListening();
    }

    _currentMessage = widget.trainerName != null
        ? "${widget.trainerName} challenges you to a Double Battle!"
        : "Double Battle!";

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDoubleIntroSequence();
    });
  }

  @override
  void dispose() {
    if (!_battleEnded && widget.pvpSession != null) {
      widget.pvpSession!.sendForfeit();
    }
    widget.pvpSession?.onPeerForfeit = null;
    widget.pvpSession?.dispose();

    _vfxController.dispose();
    _arenaShakeController.dispose();
    for (final c in _shakeControllers) {
      c.dispose();
    }
    if (!_didHealOnExit) {
      _didHealOnExit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trainer.resetAllPartyStatStages();
        if (widget.clearBattlePartyOverrideOnExit) {
          _trainer.clearBattlePartyOverride();
        }
        _trainer.saveProgress();
      });
    }
    SoundService.instance.playBgm(BgmTrack.hubTown);
    super.dispose();
  }

  Future<void> _precacheInitialAssets() async {
    final futures = <Future<void>>[
      precacheImage(AssetImage(_resolvedBattleBackgroundAsset), context)
          .catchError((_) {}),
    ];
    for (final m in _slots) {
      if (m != null) {
        final isOpp = _slots.indexOf(m) >= 2;
        final assetPath = isOpp ? m.spriteAsset : m.backSpriteAsset;
        futures.add(precacheImage(AssetImage(assetPath), context)
            .catchError((_) {}));
      }
    }
    await Future.any([
      Future.wait(futures),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
  }

  Future<void> _startDoubleIntroSequence() async {
    await _precacheInitialAssets();
    if (!mounted) return;

    setState(() {
      _arenaAssetsReady = true;
      _showOpponentTrainerSprite = true;
      _opponentTrainerSlideX = 0.0;
      _opponentTrainerPose = 0;
    });

    final introLine = widget.trainerIntroLine?.trim();
    if (widget.pvpSession == null &&
        introLine != null &&
        introLine.isNotEmpty) {
      setState(() {
        _currentMessage = "${widget.trainerName ?? 'Trainer'}: \"$introLine\"";
      });
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
    }

    final oppNames = [
      for (final s in const [2, 3])
        if (_slots[s] != null) _slots[s]!.nickname,
    ].join(" & ");

    setState(() {
      _opponentTrainerPose = 1;
      _currentMessage =
          "${widget.trainerName ?? 'Opponent'} sent out $oppNames!";
    });
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;

    setState(() {
      _opponentTrainerPose = 2;
      _opponentTrainerSlideX = 0.9;
    });
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    setState(() {
      _showOpponentTrainerSprite = false;
      for (final s in const [2, 3]) {
        if (_slots[s] != null) {
          _showSlotPokemon[s] = true;
          _slotSummonScale[s] = 1.0;
          _slotSummonBurst[s] = true;
        }
      }
    });
    for (final s in const [2, 3]) {
      if (_slots[s] != null) {
        SoundService.instance.playPokemonCry(_slots[s]!.species.id);
        if (_slots[s]!.isShiny) {
          _slotShinySparkle[s] = true;
        }
      }
    }
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() {
      _slotSummonBurst[2] = false;
      _slotSummonBurst[3] = false;
      _slotShinySparkle[2] = false;
      _slotShinySparkle[3] = false;
    });

    // Player throws out 2 Pokémon
    final pNames = [
      for (final s in const [0, 1])
        if (_slots[s] != null) _slots[s]!.nickname,
    ].join(" & ");
    setState(() {
      _showTrainerSprite = true;
      _trainerSlideX = 0.0;
      _trainerPose = 0;
      _currentMessage = "Go, $pNames!";
    });
    await Future.delayed(const Duration(milliseconds: 240));
    if (!mounted) return;

    setState(() {
      _trainerPose = 1;
    });
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    setState(() {
      _trainerPose = 2;
      _trainerSlideX = -0.9;
      for (final s in const [0, 1]) {
        if (_slots[s] != null) {
          _showSlotPokemon[s] = true;
          _slotSummonScale[s] = 1.0;
          _slotSummonBurst[s] = true;
        }
      }
    });
    for (final s in const [0, 1]) {
      if (_slots[s] != null) {
        SoundService.instance.playPokemonCry(_slots[s]!.species.id);
        if (_slots[s]!.isShiny) {
          _slotShinySparkle[s] = true;
        }
      }
    }
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    setState(() {
      _showTrainerSprite = false;
      _slotSummonBurst[0] = false;
      _slotSummonBurst[1] = false;
      _slotShinySparkle[0] = false;
      _slotShinySparkle[1] = false;
    });

    // Entry abilities in Speed order across all 4 slots!
    final entrySlots = [
      for (int s = 0; s < 4; s++)
        if (_slots[s] != null && !_slots[s]!.isFainted) s,
    ];
    entrySlots.sort(
      (a, b) => _slots[b]!.effectiveSpe.compareTo(_slots[a]!.effectiveSpe),
    );
    for (final s in entrySlots) {
      final entryEvs = DoubleBattleEngine.triggerDoubleSwitchIn(
        slot: s,
        slots: _slots,
        field: _fieldState,
      );
      for (final ev in entryEvs) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
    }

    setState(() {
      _introComplete = true;
    });
    _beginPlayerCommandPhase();
  }

  void _handlePeerForfeit() {
    if (!mounted || _battleEnded) return;
    _recordPvpBattleOutcomeIfNeeded(playerWon: true);
    setState(() {
      _isProcessingTurn = false;
      _battleEnded = true;
      _playerWon = true;
      _currentMessage =
          "${widget.trainerName ?? 'Opponent'} disconnected or forfeited! You win!";
    });
    SoundService.instance.playVictoryFanfare(isTrainer: true);
  }

  void _beginPlayerCommandPhase() {
    if (!mounted || _battleEnded) return;
    _queuedPlayerActions[0] = null;
    _queuedPlayerActions[1] = null;
    _pendingTargetMove = null;
    _deckPage = 0;

    final int? firstSlot = _nextLivingPlayerCommandSlot(-1);
    if (firstSlot == null) {
      _submitCompletedTurn();
      return;
    }

    // Handle forced turn moves automatically (Recharge / Rampage / Rollout / Bide / Two-turn Charge)
    _commandSlot = firstSlot;
    _autoResolveForcedCommandSlotsFrom(firstSlot);
  }

  int? _nextLivingPlayerCommandSlot(int currentSlot) {
    for (int s = currentSlot + 1; s < 2; s++) {
      final mon = _slots[s];
      if (mon != null && !mon.isFainted && _queuedPlayerActions[s] == null) {
        return s;
      }
    }
    return null;
  }

  void _autoResolveForcedCommandSlotsFrom(int slot) {
    int? cursor = slot;
    while (cursor != null) {
      final mon = _slots[cursor];
      if (mon != null && !mon.isFainted && mon.hasForcedTurnAction) {
        final forcedMove = mon.activeMoves.firstWhere(
          (m) => m.id == mon.forcedMoveId,
          orElse: () => PokedexDatabase.moves['struggle']!.copy(),
        );
        final foe = [2, 3].firstWhere(
          (s) => _slots[s] != null && !_slots[s]!.isFainted,
          orElse: () => 2,
        );
        _queuedPlayerActions[cursor] =
            DoubleBattleSlotAction.fight(forcedMove, targetSlot: foe);
        cursor = _nextLivingPlayerCommandSlot(cursor);
      } else {
        break;
      }
    }

    if (cursor == null) {
      _submitCompletedTurn();
    } else {
      setState(() {
        _isProcessingTurn = false;
        _commandSlot = cursor!;
        _deckPage = 0;
        _pendingTargetMove = null;
        _currentMessage =
            "What will ${_slots[cursor]!.nickname} (${cursor == 0 ? 'Left' : 'Right'}) do?";
      });
    }
  }

  void _commitPlayerSlotAction(DoubleBattleSlotAction action) {
    SoundService.instance.playUiTap();
    _queuedPlayerActions[_commandSlot] = action;
    final int? next = _nextLivingPlayerCommandSlot(_commandSlot);
    if (next == null) {
      _submitCompletedTurn();
    } else {
      _autoResolveForcedCommandSlotsFrom(next);
    }
  }

  void _goBackToPreviousSlot() {
    if (_commandSlot == 1 && _slots[0] != null && !_slots[0]!.isFainted && !_slots[0]!.hasForcedTurnAction) {
      SoundService.instance.playUiTap();
      setState(() {
        _queuedPlayerActions[0] = null;
        _queuedPlayerActions[1] = null;
        _commandSlot = 0;
        _deckPage = 0;
        _pendingTargetMove = null;
        _currentMessage =
            "What will ${_slots[0]!.nickname} (Left) do?";
      });
    }
  }

  Future<void> _submitCompletedTurn() async {
    if (_battleEnded || !mounted) return;
    setState(() {
      _isProcessingTurn = true;
      _deckPage = 0;
      _pendingTargetMove = null;
    });

    final DoubleBattleSlotAction pAct0 =
        _queuedPlayerActions[0] ?? DoubleBattleSlotAction.pass();
    final DoubleBattleSlotAction pAct1 =
        _queuedPlayerActions[1] ?? DoubleBattleSlotAction.pass();

    if (widget.pvpSession != null) {
      await _executePvpDoubleTurn(pAct0, pAct1);
      return;
    }

    final oppActions = DoubleBattleEngine.chooseOpponentDoubleActions(
      slots: _slots,
      field: _fieldState,
    );

    final events = DoubleBattleEngine.resolveDoubleTurn(
      slots: _slots,
      slotActions: [pAct0, pAct1, oppActions[0], oppActions[1]],
      playerParty: _trainer.party,
      opponentParty: _opponentParty,
      field: _fieldState,
      playerTrainer: _trainer,
    );

    for (final ev in events) {
      await _playStepEvent(ev);
      if (!mounted || _battleEnded) return;
    }

    final eotEvents = DoubleBattleEngine.processDoubleEndOfTurn(
      slots: _slots,
      field: _fieldState,
      playerTrainer: _trainer,
    );
    for (final ev in eotEvents) {
      await _playStepEvent(ev);
      if (!mounted || _battleEnded) return;
    }

    await _checkPostTurnConditions();
  }

  Future<void> _executePvpDoubleTurn(
    DoubleBattleSlotAction myAct0,
    DoubleBattleSlotAction myAct1,
  ) async {
    final session = widget.pvpSession;
    if (session == null || _battleEnded || !mounted) return;

    final int turnNumber = ++_pvpTurnIndex;
    final int mySeed = Random().nextInt(0x3FFFFFFF);

    setState(() {
      _currentMessage =
          "Waiting for ${widget.trainerName ?? 'Opponent'} to choose actions...";
    });

    late final PvpTurnPacket peerPacket;
    try {
      peerPacket = await session.exchangeTurnAction(
        turn: turnNumber,
        mySeed: mySeed,
        action: {
          'format': 'doubles',
          'slots': [myAct0.toJson(), myAct1.toJson()],
        },
        activeMon: {
          'slots': [
            _slots[0]?.toJson(),
            _slots[1]?.toJson(),
          ],
        },
      );
    } catch (_) {
      return;
    }
    if (!mounted || _battleEnded) return;

    // Parse peer actions
    final peerRawSlots = peerPacket.action['slots'] as List? ?? const [];
    final peerAct0 = peerRawSlots.isNotEmpty && peerRawSlots[0] is Map
        ? DoubleBattleSlotAction.fromJson(
            Map<String, dynamic>.from(peerRawSlots[0] as Map),
            _slots[2],
          )
        : DoubleBattleSlotAction.pass();
    final peerAct1 = peerRawSlots.length > 1 && peerRawSlots[1] is Map
        ? DoubleBattleSlotAction.fromJson(
            Map<String, dynamic>.from(peerRawSlots[1] as Map),
            _slots[3],
          )
        : DoubleBattleSlotAction.pass();

    final int hostSeed = session.isHost ? mySeed : peerPacket.seed;
    final int guestSeed = session.isHost ? peerPacket.seed : mySeed;
    final int sharedSeed =
        (hostSeed ^ guestSeed ^ (turnNumber * 1000003)) & 0x7FFFFFFF;
    final Random turnRng = Random(sharedSeed);

    // Canonical slot mapping: Host is [0, 1], Guest is [2, 3]
    int mapActionTargetToCanonical(int? localTarget) {
      if (localTarget == null) return 2;
      return session.isHost ? localTarget : (localTarget ^ 2);
    }

    DoubleBattleSlotAction canonicalizeAction(
      DoubleBattleSlotAction a,
      bool belongsToHost,
    ) {
      if (a.type != DoubleBattleActionType.fight || a.targetSlot == null) {
        return a;
      }
      final t = a.targetSlot!;
      // On local machine, `myAct` targets local 0..3 and `peerAct` targets peer-local 0..3.
      final mapped = belongsToHost
          ? (session.isHost ? t : (t ^ 2))
          : (session.isHost ? (t ^ 2) : t);
      return a.copyWith(targetSlot: mapped);
    }

    // Build canonical view (`canonicalSlots` = Host 0,1 then Guest 2,3)
    final canonicalSlots = session.isHost
        ? <PokemonInstance?>[_slots[0], _slots[1], _slots[2], _slots[3]]
        : <PokemonInstance?>[_slots[2], _slots[3], _slots[0], _slots[1]];

    final canonicalActions = session.isHost
        ? <DoubleBattleSlotAction>[
            canonicalizeAction(myAct0, true),
            canonicalizeAction(myAct1, true),
            peerAct0.type == DoubleBattleActionType.fight && peerAct0.targetSlot != null
                ? peerAct0.copyWith(targetSlot: peerAct0.targetSlot! ^ 2)
                : peerAct0,
            peerAct1.type == DoubleBattleActionType.fight && peerAct1.targetSlot != null
                ? peerAct1.copyWith(targetSlot: peerAct1.targetSlot! ^ 2)
                : peerAct1,
          ]
        : <DoubleBattleSlotAction>[
            peerAct0,
            peerAct1,
            myAct0.type == DoubleBattleActionType.fight && myAct0.targetSlot != null
                ? myAct0.copyWith(targetSlot: mapActionTargetToCanonical(myAct0.targetSlot))
                : myAct0,
            myAct1.type == DoubleBattleActionType.fight && myAct1.targetSlot != null
                ? myAct1.copyWith(targetSlot: mapActionTargetToCanonical(myAct1.targetSlot))
                : myAct1,
          ];

    final canonicalField = BattleFieldState()
      ..weather = _fieldState.weather
      ..weatherTurnsRemaining = _fieldState.weatherTurnsRemaining
      ..gravityTurns = _fieldState.gravityTurns
      ..wonderRoomTurns = _fieldState.wonderRoomTurns
      ..uproarTurns = _fieldState.uproarTurns
      ..mudSportActive = _fieldState.mudSportActive
      ..waterSportActive = _fieldState.waterSportActive;

    // Copy side states cleanly
    void copySide(BattleSideState src, BattleSideState dst) {
      dst
        ..reflectTurns = src.reflectTurns
        ..lightScreenTurns = src.lightScreenTurns
        ..safeguardTurns = src.safeguardTurns
        ..mistTurns = src.mistTurns
        ..tailwindTurns = src.tailwindTurns
        ..luckyChantTurns = src.luckyChantTurns
        ..spikesLayers = src.spikesLayers
        ..toxicSpikesLayers = src.toxicSpikesLayers
        ..hasStealthRock = src.hasStealthRock
        ..hasHealingWishPending = src.hasHealingWishPending;
    }

    if (session.isHost) {
      copySide(_fieldState.playerSide, canonicalField.playerSide);
      copySide(_fieldState.opponentSide, canonicalField.opponentSide);
    } else {
      copySide(_fieldState.opponentSide, canonicalField.playerSide);
      copySide(_fieldState.playerSide, canonicalField.opponentSide);
    }

    final events = DoubleBattleEngine.resolveDoubleTurn(
      slots: canonicalSlots,
      slotActions: canonicalActions,
      playerParty: session.isHost ? _trainer.party : _opponentParty,
      opponentParty: session.isHost ? _opponentParty : _trainer.party,
      field: canonicalField,
      playerTrainer: null, // No badge scaling in PvP!
      rng: turnRng,
    );

    final eotEvents = DoubleBattleEngine.processDoubleEndOfTurn(
      slots: canonicalSlots,
      field: canonicalField,
      playerTrainer: null,
      rng: turnRng,
    );

    // Sync local slots & field back from canonical
    if (session.isHost) {
      for (int i = 0; i < 4; i++) {
        _slots[i] = canonicalSlots[i];
      }
      copySide(canonicalField.playerSide, _fieldState.playerSide);
      copySide(canonicalField.opponentSide, _fieldState.opponentSide);
    } else {
      for (int i = 0; i < 4; i++) {
        _slots[i] = canonicalSlots[i ^ 2];
      }
      copySide(canonicalField.playerSide, _fieldState.opponentSide);
      copySide(canonicalField.opponentSide, _fieldState.playerSide);
    }
    _fieldState
      ..weather = canonicalField.weather
      ..weatherTurnsRemaining = canonicalField.weatherTurnsRemaining
      ..gravityTurns = canonicalField.gravityTurns
      ..wonderRoomTurns = canonicalField.wonderRoomTurns
      ..uproarTurns = canonicalField.uproarTurns
      ..mudSportActive = canonicalField.mudSportActive
      ..waterSportActive = canonicalField.waterSportActive;

    DoubleBattleStepEvent toLocalUiEvent(DoubleBattleStepEvent ev) {
      if (session.isHost) return ev;
      final localSnapshots = <int, int>{};
      ev.slotHpSnapshots.forEach((k, v) {
        localSnapshots[k ^ 2] = v;
      });
      return DoubleBattleStepEvent(
        message: ev.message,
        actorSlot: ev.actorSlot ^ 2,
        targetSlot: ev.targetSlot ^ 2,
        vfxTargetSlots: [for (final t in ev.vfxTargetSlots) t ^ 2],
        moveId: ev.moveId,
        moveType: ev.moveType,
        moveCategory: ev.moveCategory,
        damageDealt: ev.damageDealt,
        isCrit: ev.isCrit,
        effectiveness: ev.effectiveness,
        statChangedLabel: ev.statChangedLabel,
        statTargetIsSelf: ev.statTargetIsSelf,
        statusInflictedLabel: ev.statusInflictedLabel,
        isMiss: ev.isMiss,
        isStatusTick: ev.isStatusTick,
        isSelfDamage: ev.isSelfDamage,
        healAmount: ev.healAmount,
        abilityTriggeredName: ev.abilityTriggeredName,
        hideMoveVfx: ev.hideMoveVfx,
        isChargeTurn: ev.isChargeTurn,
        submergeActorAfter: ev.submergeActorAfter,
        surfaceActorOnAttack: ev.surfaceActorOnAttack,
        swapUserWithAlly: ev.swapUserWithAlly,
        switchInSlot: ev.switchInSlot != null ? ev.switchInSlot! ^ 2 : null,
        switchedInMon: ev.switchedInMon,
        slotHpSnapshots: localSnapshots,
        faintedSlots: [for (final f in ev.faintedSlots) f ^ 2],
      );
    }

    for (final ev in [...events, ...eotEvents]) {
      await _playStepEvent(toLocalUiEvent(ev));
      if (!mounted || _battleEnded) return;
    }

    await _checkPostTurnConditions(pvpTurn: turnNumber);
  }

  Future<void> _playStepEvent(DoubleBattleStepEvent ev) async {
    if (!mounted) return;
    final actor = (ev.actorSlot >= 0 && ev.actorSlot < 4)
        ? _slots[ev.actorSlot]
        : null;

    if (ev.switchInSlot != null && ev.switchedInMon != null) {
      final s = ev.switchInSlot!;
      setState(() {
        _visualFainted[s] = false;
        _slotSubmerged[s] = false;
        _showSlotPokemon[s] = true;
        _slotSummonScale[s] = 1.0;
        _slotSummonBurst[s] = true;
        _displayedHps[s] = ev.switchedInMon!.currentHp;
        _currentMessage = ev.message;
      });
      SoundService.instance.playPokemonCry(ev.switchedInMon!.species.id);
      if (s < 2) _recordParticipant(ev.switchedInMon!);
      if (s >= 2) _trainer.markPokemonSeen(ev.switchedInMon!.species.id);
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() => _slotSummonBurst[s] = false);
      return;
    }

    setState(() {
      _currentMessage = ev.message;
      if (ev.submergeActorAfter && ev.actorSlot < 4) {
        _slotSubmerged[ev.actorSlot] = true;
      }
      if (ev.surfaceActorOnAttack && ev.actorSlot < 4) {
        _slotSubmerged[ev.actorSlot] = false;
      }
      if (ev.statChangedLabel != null) {
        _calloutText(
          slot: ev.statTargetIsSelf ? ev.actorSlot : ev.targetSlot,
          text: ev.statChangedLabel!,
          color: ev.statChangedLabel!.contains('▲') ||
                  ev.statChangedLabel!.contains('MAX')
              ? Colors.amberAccent
              : Colors.cyanAccent,
        );
      } else if (ev.statusInflictedLabel != null) {
        _calloutText(
          slot: ev.statTargetIsSelf ? ev.actorSlot : ev.targetSlot,
          text: ev.statusInflictedLabel!,
          color: Colors.purpleAccent,
        );
      } else if (ev.abilityTriggeredName != null) {
        _calloutText(
          slot: ev.actorSlot,
          text: ev.abilityTriggeredName!.toUpperCase(),
          color: Colors.lightBlueAccent,
        );
      }
    });

    // Play Attack Lunge + VFX across 1 or more targets
    final bool playVfx =
        !ev.hideMoveVfx && ev.moveId != null && ev.moveType != null && ev.vfxTargetSlots.isNotEmpty;
    if (playVfx) {
      SoundService.instance.playMoveSfx(
        ev.moveType!,
        ev.moveCategory ?? MoveCategory.physical,
      );

      if (ev.moveCategory == MoveCategory.physical &&
          !ev.isChargeTurn &&
          actor != null) {
        final targetSlot = ev.targetSlot;
        final Offset aCenter = _slotCenters[ev.actorSlot] ?? Offset.zero;
        final Offset tCenter = _slotCenters[targetSlot] ?? Offset.zero;
        final Offset delta = tCenter - aCenter;
        final double d = max(1.0, delta.distance);
        setState(() {
          _slotLungeOffset[ev.actorSlot] = (delta / d) * 18.0;
        });
      }

      setState(() {
        _activeMoveId = ev.moveId;
        _activeVfxType = ev.moveType;
        _activeVfxCategory = ev.moveCategory ?? MoveCategory.physical;
        _vfxActorSlot = ev.actorSlot;
        _vfxTargetSlots = ev.vfxTargetSlots;
      });
      await _vfxController.forward(from: 0.0);
      if (!mounted) return;
      setState(() {
        _activeMoveId = null;
        _slotLungeOffset[ev.actorSlot] = Offset.zero;
      });
    }

    // Impact shake / flash / HP update
    final int hitSlot = ev.isSelfDamage ? ev.actorSlot : ev.targetSlot;
    if (ev.damageDealt > 0 && hitSlot >= 0 && hitSlot < 4) {
      HapticFeedback.lightImpact();
      SoundService.instance.playHitSfx(
        isCrit: ev.isCrit,
        effectiveness: ev.effectiveness,
      );
      if (ev.damageDealt > 25 || ev.isCrit || ev.effectiveness >= 2.0) {
        _arenaShakeController.forward(from: 0.0);
      }
      _shakeControllers[hitSlot].forward(from: 0.0);
      setState(() {
        _slotFlash[hitSlot] = true;
      });
      await Future.delayed(const Duration(milliseconds: 140));
      if (!mounted) return;
      setState(() {
        _slotFlash[hitSlot] = false;
      });
    } else if (ev.healAmount > 0) {
      SoundService.instance.playHealSfx();
    } else if (ev.isMiss) {
      SoundService.instance.playHitSfx(isMiss: true);
    }

    // Sync displayed HP snapshots & newly fainted slots
    setState(() {
      ev.slotHpSnapshots.forEach((s, hp) {
        if (s >= 0 && s < 4) {
          _displayedHps[s] = hp;
        }
      });
      for (final fSlot in ev.faintedSlots) {
        if (fSlot >= 0 && fSlot < 4 && !_visualFainted[fSlot]) {
          _visualFainted[fSlot] = true;
          final fMon = _slots[fSlot];
          if (fMon != null) {
            SoundService.instance.playPokemonCry(fMon.species.id, fainted: true);
            Future.delayed(const Duration(milliseconds: 220), () {
              if (mounted) SoundService.instance.playFaintSfx();
            });
          }
        }
      }
    });

    await Future.delayed(
      Duration(milliseconds: ev.isStatusTick ? 540 : (playVfx ? 460 : 620)),
    );
    if (!mounted) return;
    if (_floatingCallout != null) {
      setState(() => _floatingCallout = null);
    }
  }

  void _calloutText({
    required int slot,
    required String text,
    required Color color,
  }) {
    _calloutSlot = slot.clamp(0, 3);
    _floatingCallout = text;
    _calloutColor = color;
  }

  Future<void> _checkPostTurnConditions({int? pvpTurn}) async {
    if (!mounted || _battleEnded) return;

    // 1. Award EXP for any newly fainted opposing Pokémon (PvE only)
    if (widget.pvpSession == null) {
      for (int s = 2; s <= 3; s++) {
        final foe = _slots[s];
        if (foe != null && foe.isFainted && !_expAwardedFoes.contains(foe)) {
          _expAwardedFoes.add(foe);
          await _awardExpForDefeatedFoe(foe);
          if (!mounted) return;
        }
      }
    }

    // 2. Check Total Victory or Defeat
    final bool oppAllDown = _opponentParty.every((p) => p.isFainted);
    final bool playerAllDown = !_trainer.hasConsciousPokemon;

    if (oppAllDown) {
      await _handleVictory();
      return;
    }
    if (playerAllDown) {
      _handleDefeat();
      return;
    }

    // 3. Handle replacements for fainted active slots
    final List<({int slot, int partyIndex})> playerForcedSwitches = [];
    for (int s = 0; s < 2; s++) {
      final mon = _slots[s];
      final bool hasBench = _trainer.party
          .any((p) => !p.isFainted && !_slots.contains(p));
      if ((mon == null || mon.isFainted) && hasBench) {
        final picked = await _promptForcedSwitchForSlot(s);
        if (!mounted || _battleEnded) return;
        if (picked != null) {
          final pIdx = _trainer.party.indexOf(picked);
          _slots[s] = picked;
          _recordParticipant(picked);
          _visualFainted[s] = false;
          _showSlotPokemon[s] = true;
          _slotSummonScale[s] = 1.0;
          _displayedHps[s] = picked.currentHp;
          SoundService.instance.playPokemonCry(picked.species.id);
          setState(() {
            _currentMessage = "Go! ${picked.nickname}!";
          });
          playerForcedSwitches.add((slot: s, partyIndex: pIdx));
          await Future.delayed(const Duration(milliseconds: 520));
          if (!mounted) return;
        }
      } else if (mon != null && mon.isFainted && !hasBench) {
        _slots[s] = null;
        setState(() {
          _showSlotPokemon[s] = false;
        });
      }
    }

    // Opponent forced switches
    if (widget.pvpSession != null) {
      final bool anyOppNeedBench = [2, 3].any((s) =>
          (_slots[s] == null || _slots[s]!.isFainted) &&
          _opponentParty.any((p) => !p.isFainted && !_slots.contains(p)));
      if (playerForcedSwitches.isNotEmpty) {
        await widget.pvpSession!.sendForcedSwitch(
          turn: pvpTurn ?? _pvpTurnIndex,
          partyIndex: playerForcedSwitches.first.partyIndex,
          activeMon: {
            'switches': [
              for (final sw in playerForcedSwitches)
                {'slot': sw.slot, 'partyIndex': sw.partyIndex},
            ],
          },
        );
      }
      if (anyOppNeedBench && mounted && !_battleEnded) {
        setState(() {
          _currentMessage =
              "Waiting for ${widget.trainerName ?? 'Opponent'} to send out Pokémon...";
        });
        try {
          final packet = await widget.pvpSession!
              .waitForPeerForcedSwitch(turn: pvpTurn ?? _pvpTurnIndex);
          if (!mounted || _battleEnded) return;
          final rawActive = packet['activeMon'];
          final rawSwitches = (rawActive is Map ? rawActive['switches'] : null) as List?;
          if (rawSwitches != null) {
            for (final sw in rawSwitches) {
              if (sw is Map) {
                final int localSlot = ((sw['slot'] as num?)?.toInt() ?? 0) + 2;
                final int pIdx = (sw['partyIndex'] as num?)?.toInt() ?? 0;
                if (localSlot >= 2 &&
                    localSlot <= 3 &&
                    pIdx >= 0 &&
                    pIdx < _opponentParty.length) {
                  final nextOpp = _opponentParty[pIdx];
                  _slots[localSlot] = nextOpp;
                  _visualFainted[localSlot] = false;
                  _showSlotPokemon[localSlot] = true;
                  _slotSummonScale[localSlot] = 1.0;
                  _displayedHps[localSlot] = nextOpp.currentHp;
                  SoundService.instance.playPokemonCry(nextOpp.species.id);
                }
              }
            }
          }
        } catch (_) {
          return;
        }
      }
    } else {
      // PvE opponent auto-sends next conscious bench Pokémon
      for (int s = 2; s <= 3; s++) {
        final mon = _slots[s];
        if (mon == null || mon.isFainted) {
          final nextBench = _opponentParty.cast<PokemonInstance?>().firstWhere(
                (p) => p != null && !p.isFainted && !_slots.contains(p),
                orElse: () => null,
              );
          if (nextBench != null) {
            _slots[s] = nextBench;
            _visualFainted[s] = false;
            _showSlotPokemon[s] = true;
            _slotSummonScale[s] = 1.0;
            _displayedHps[s] = nextBench.currentHp;
            _trainer.markPokemonSeen(nextBench.species.id);
            setState(() {
              _currentMessage =
                  "${widget.trainerName ?? 'Opponent'} sent out ${nextBench.nickname}!";
            });
            SoundService.instance.playPokemonCry(nextBench.species.id);
            await Future.delayed(const Duration(milliseconds: 520));
            if (!mounted) return;
            final entryEvs = DoubleBattleEngine.triggerDoubleSwitchIn(
              slot: s,
              slots: _slots,
              field: _fieldState,
            );
            for (final ev in entryEvs) {
              await _playStepEvent(ev);
              if (!mounted) return;
            }
          } else {
            _slots[s] = null;
            setState(() {
              _showSlotPokemon[s] = false;
            });
          }
        }
      }
    }

    // Entry abilities for newly sent-in player Pokémon
    for (final sw in playerForcedSwitches) {
      final entryEvs = DoubleBattleEngine.triggerDoubleSwitchIn(
        slot: sw.slot,
        slots: _slots,
        field: _fieldState,
      );
      for (final ev in entryEvs) {
        await _playStepEvent(ev);
        if (!mounted) return;
      }
    }

    _beginPlayerCommandPhase();
  }

  Future<void> _awardExpForDefeatedFoe(PokemonInstance foe) async {
    if (widget.isFrontierBattle) return;
    final activeParticipants = _participatedPokemon
        .where((p) => _trainer.party.contains(p) && !p.isFainted)
        .toList();
    final List<PokemonInstance> recipients = _trainer.isExpShareActive
        ? _trainer.party.where((p) => !p.isFainted).toList()
        : (activeParticipants.isNotEmpty
            ? activeParticipants
            : _trainer.party.where((p) => !p.isFainted).take(1).toList());
    if (recipients.isEmpty) return;

    final int winnerLevel =
        _slots[0]?.level ?? _slots[1]?.level ?? recipients.first.level;
    final int expGained = PokemonInstance.calculateBattleExp(
      defeated: foe,
      winnerLevel: winnerLevel,
      isTrainerBattle: true,
    );
    final int share = max(1, expGained ~/ recipients.length);

    setState(() {
      _currentMessage = recipients.length == 1
          ? "${recipients.first.nickname} gained $share EXP!"
          : "Party Pokémon each gained $share EXP!";
    });
    await Future.delayed(const Duration(milliseconds: 780));
    if (!mounted) return;

    for (final participant in recipients) {
      final result = participant.gainExpWithLearnset(
        share,
        PokedexDatabase.movesUnlockedAtExactLevel,
      );
      if (result.leveledUp) {
        SoundService.instance.playLevelUpSfx();
        setState(() {
          for (int s = 0; s < 2; s++) {
            if (_slots[s] == participant) {
              _displayedHps[s] = participant.currentHp;
            }
          }
          _currentMessage =
              "${participant.nickname} grew to Lv. ${participant.level}!";
        });
        await Future.delayed(const Duration(milliseconds: 850));
        if (!mounted) return;

        for (final moveName in result.learnedMoves) {
          setState(() {
            _currentMessage = "${participant.nickname} learned $moveName!";
          });
          await Future.delayed(const Duration(milliseconds: 750));
          if (!mounted) return;
        }

        for (final newMove in result.pendingMoves) {
          final outcome = await showMoveLearnDialog(
            context,
            pokemon: participant,
            newMove: newMove,
            recordOnSkip: true,
          );
          if (!mounted) return;
          setState(() {
            if (outcome.learned) {
              _currentMessage = "${participant.nickname} learned ${newMove.name}!";
            }
          });
          _trainer.saveProgress();
        }

        final int? nextEvoId = participant.resolveLevelUpEvolutionSpeciesId();
        if (nextEvoId != null &&
            PokedexDatabase.isSpeciesInRegion(
                nextEvoId, _trainer.activeRegion)) {
          final nextSpecies = PokedexDatabase.species[nextEvoId];
          if (nextSpecies != null) {
            final oldName = participant.nickname;
            final fromSpecies = participant.species;
            final pendingEvoMoves = <Move>[];
            final evoMoves = participant.evolve(
              nextSpecies,
              PokedexDatabase.movesUnlockedAtExactLevel(nextSpecies, participant.level),
              pendingMovesOut: pendingEvoMoves,
            );
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
            for (final m in pendingEvoMoves) {
              await showMoveLearnDialog(
                context,
                pokemon: participant,
                newMove: m,
                recordOnSkip: true,
              );
              if (!mounted) return;
            }
          }
        }
      }
    }
  }

  Future<void> _handleVictory() async {
    _recordPvpBattleOutcomeIfNeeded(playerWon: true);
    _trainer.recordBattleCompleted(isTrainerBattle: true, won: true);
    SoundService.instance.playVictoryFanfare(isTrainer: true);

    setState(() {
      _isProcessingTurn = false;
      _battleEnded = true;
      _playerWon = true;
    });

    final defeatLine = widget.trainerDefeatLine?.trim();
    if (widget.pvpSession == null &&
        defeatLine != null &&
        defeatLine.isNotEmpty) {
      setState(() {
        _showOpponentTrainerSprite = true;
        _opponentTrainerPose = 0;
        _opponentTrainerSlideX = 0.0;
        _currentMessage = "${widget.trainerName ?? 'Opponent'}: \"$defeatLine\"";
      });
      await Future.delayed(const Duration(milliseconds: 1650));
      if (!mounted) return;
    }

    if (widget.prizeMoney > 0 &&
        widget.pvpSession == null &&
        !widget.isFrontierBattle) {
      _trainer.addMoney(widget.prizeMoney);
      _trainer.saveProgress();
      setState(() {
        _currentMessage =
            "Defeated ${widget.trainerName ?? 'Opponent'}! Earned ₽${widget.prizeMoney}!";
      });
    } else {
      setState(() {
        _currentMessage =
            "You defeated ${widget.trainerName ?? 'Opponent'}!";
      });
    }
  }

  void _handleDefeat() {
    _recordPvpBattleOutcomeIfNeeded(playerWon: false);
    _trainer.recordBattleCompleted(isTrainerBattle: true, won: false);
    setState(() {
      _isProcessingTurn = false;
      _battleEnded = true;
      _playerWon = false;
      _currentMessage = "All your Pokémon fainted! You scurried back to safety...";
    });
  }

  Future<PokemonInstance?> _promptForcedSwitchForSlot(int slot) async {
    return showModalBottomSheet<PokemonInstance>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _buildSwitchListSheet(
          ctx,
          title:
              "SEND IN REPLACEMENT (${slot == 0 ? 'LEFT' : 'RIGHT'} SLOT)",
          forced: true,
          onSelect: (mon) => Navigator.pop(ctx, mon),
        );
      },
    );
  }

  void _openSwitchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _buildSwitchListSheet(
          ctx,
          title:
              "SWITCH ${_commandSlot == 0 ? 'LEFT' : 'RIGHT'} POKÉMON",
          forced: false,
          onSelect: (mon) {
            Navigator.pop(ctx);
            final pIdx = _trainer.party.indexOf(mon);
            if (pIdx >= 0) {
              _commitPlayerSlotAction(
                DoubleBattleSlotAction.switchPokemon(pIdx),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildSwitchListSheet(
    BuildContext ctx, {
    required String title,
    required bool forced,
    required void Function(PokemonInstance) onSelect,
  }) {
    final maxH = MediaQuery.of(ctx).size.height * 0.78;
    // Prevent Slot 1 from double-picking a bench Pokémon already chosen by Slot 0!
    final int? alreadyQueuedBench =
        (_commandSlot == 1 &&
                _queuedPlayerActions[0]?.type ==
                    DoubleBattleActionType.switchPokemon)
            ? _queuedPlayerActions[0]?.switchPartyIndex
            : null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (!forced)
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 20),
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
                    final bool onField = _slots[0] == mon || _slots[1] == mon;
                    final bool reserved = alreadyQueuedBench == idx;
                    final bool canSwitch =
                        !mon.isFainted && !onField && !reserved;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: onField
                            ? const Color(0xFF283044)
                            : const Color(0xFF1F1F2B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: onField
                              ? Colors.amberAccent.withOpacity(0.55)
                              : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          Opacity(
                            opacity: mon.isFainted ? 0.45 : 1.0,
                            child: PokemonSpriteImage.fromInstance(
                              mon,
                              width: 38,
                              height: 38,
                              fallbackIconSize: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${mon.nickname}  Lv.${mon.level}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
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
                          ElevatedButton(
                            onPressed: canSwitch ? () => onSelect(mon) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 32),
                            ),
                            child: Text(
                              onField
                                  ? "ACTIVE"
                                  : (reserved
                                      ? "QUEUED"
                                      : (mon.isFainted ? "FAINTED" : "SWITCH")),
                              style: const TextStyle(
                                fontSize: 10.5,
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
  }

  void _openBagModal() {
    if (widget.pvpSession != null || widget.isFrontierBattle) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final medicineRows = <Widget>[];
        final ballRows = <Widget>[];

        for (final ball in ItemDatabase.allBalls) {
          final int count = _trainer.getItemCount(ball.id);
          if (count <= 0) continue;
          ballRows.add(ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PokeBallSpriteWidget(ballType: ball.id, size: 28),
            title: Text(
              ball.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text("x$count • Trainer Battles forbid Poké Balls",
                style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
            trailing: ElevatedButton(
              onPressed: null,
              child: const Text("LOCKED"),
            ),
          ));
        }

        const medIds = [
          'potion',
          'super_potion',
          'hyper_potion',
          'max_potion',
          'full_restore',
          'revive',
          'antidote',
          'paralyze_heal',
          'awakening',
          'burn_heal',
          'ice_heal',
          'full_heal',
          'ether',
          'max_ether',
          'elixir',
          'max_elixir',
          'leppa_berry',
        ];
        for (final id in medIds) {
          final item = ItemDatabase.byId(id);
          final count = _trainer.getItemCount(id);
          if (item == null || count <= 0) continue;
          final bool anyEligible = _trainer.party
              .any((p) => ItemDatabase.canUseMedicineOn(id, p));
          medicineRows.add(ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(item.icon, color: item.color, size: 26),
            title: Text(
              item.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text("x$count remaining",
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            trailing: ElevatedButton(
              onPressed: anyEligible
                  ? () {
                      Navigator.pop(ctx);
                      _openMedicineTargetModal(item);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: item.color,
                foregroundColor: Colors.white,
              ),
              child: const Text("USE"),
            ),
          ));
        }

        return DefaultTabController(
          length: 2,
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.backpack_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "TRAINER BAG",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: const Color(0xFF3A3A4D),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white24),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      tabs: [
                        Tab(
                          height: 40,
                          text: "Medicine (${medicineRows.length})",
                        ),
                        Tab(
                          height: 40,
                          text: "Poké Balls (${ballRows.length})",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        medicineRows.isEmpty
                            ? const Center(
                                child: Text(
                                  "No Medicine in your Bag!",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : ListView(children: medicineRows),
                        ballRows.isEmpty
                            ? const Center(
                                child: Text(
                                  "No Poké Balls in your Bag!",
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : ListView(children: ballRows),
                      ],
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

  void _openMedicineTargetModal(Item item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dlgCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "USE ${item.name.toUpperCase()} ON WHICH POKÉMON?",
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dlgCtx).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _trainer.party.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final mon = _trainer.party[idx];
                      final bool usable =
                          ItemDatabase.canUseMedicineOn(item.id, mon);
                      return ListTile(
                        tileColor: const Color(0xFF1F1F2B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        title: Text(
                          "${mon.nickname}  Lv.${mon.level}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        subtitle: Text(
                          "HP ${mon.currentHp}/${mon.maxHp}",
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          onPressed: usable
                              ? () async {
                                  Navigator.pop(dlgCtx);
                                  String? moveIdForPp;
                                  if (item.id == 'ether' ||
                                      item.id == 'max_ether' ||
                                      item.id == 'leppa_berry') {
                                    final moveIdx = await showMovePpPickerDialog(
                                      context,
                                      pokemon: mon,
                                      item: item,
                                    );
                                    if (!mounted || moveIdx == null) return;
                                    moveIdForPp = mon.moves[moveIdx].id;
                                  }
                                  _commitPlayerSlotAction(
                                    DoubleBattleSlotAction.useItem(
                                      item.id,
                                      targetPartyIndex: idx,
                                      moveIdForPp: moveIdForPp,
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: item.color,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("SELECT"),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onRunPressed() {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2233),
        title: const Text(
          "Forfeit Double Battle?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          widget.pvpSession != null
              ? "Forfeiting counts as a loss against ${widget.trainerName ?? 'your rival'}."
              : "Do you want to forfeit this Double Battle?",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              if (widget.pvpSession != null) {
                widget.pvpSession!.sendForfeit();
                _recordPvpBattleOutcomeIfNeeded(playerWon: false);
              }
              _battleEnded = true;
              _playerWon = false;
              Navigator.pop(context, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("FORFEIT"),
          ),
        ],
      ),
    );
  }

  void _onMoveTapped(Move move) {
    final actor = _slots[_commandSlot];
    if (actor == null) return;
    if (move.currentPp <= 0) {
      final hasAnyPp = actor.activeMoves.any((m) => m.currentPp > 0);
      if (hasAnyPp) return;
      final struggle = PokedexDatabase.moves['struggle']!.copy();
      _commitPlayerSlotAction(DoubleBattleSlotAction.fight(struggle));
      return;
    }

    final targetKind = DoubleBattleEngine.classifyMoveTarget(move, user: actor);
    if (targetKind == MoveTarget.allFoes ||
        targetKind == MoveTarget.allOthers ||
        targetKind == MoveTarget.self ||
        targetKind == MoveTarget.userSide ||
        targetKind == MoveTarget.foeSide ||
        targetKind == MoveTarget.entireField ||
        targetKind == MoveTarget.randomFoe) {
      _commitPlayerSlotAction(DoubleBattleSlotAction.fight(move));
      return;
    }

    if (targetKind == MoveTarget.allyOnly) {
      final allySlot = _commandSlot ^ 1;
      _commitPlayerSlotAction(
        DoubleBattleSlotAction.fight(move, targetSlot: allySlot),
      );
      return;
    }

    // Single target or allyOrSelf -> check if only 1 foe left when singleAdjacent
    if (targetKind == MoveTarget.singleAdjacent) {
      final livingFoes = [
        for (final s in const [2, 3])
          if (_slots[s] != null && !_slots[s]!.isFainted) s,
      ];
      if (livingFoes.length == 1 && move.id != 'heal_pulse') {
        _commitPlayerSlotAction(
          DoubleBattleSlotAction.fight(move, targetSlot: livingFoes.first),
        );
        return;
      }
    }

    setState(() {
      _pendingTargetMove = move;
      _deckPage = 2;
      _currentMessage = "Select target for ${move.name}!";
    });
  }

  void _finishAndExit() {
    if (!_battleEnded && widget.pvpSession != null) {
      _onRunPressed();
      return;
    }
    Navigator.pop(context, _playerWon);
  }

  Offset _mapBgPoint(double bgX, double bgY, double arenaW, double arenaH) {
    const double imgW = 900.0;
    const double imgH = 750.0;
    final double scale = max(arenaW / imgW, arenaH / imgH);
    final double xOffset = (arenaW - imgW * scale) / 2.0;
    final double yOffset = (arenaH - imgH * scale) / 2.0;
    return Offset(xOffset + bgX * scale, yOffset + bgY * scale);
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
              // Header
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
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151C2B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (widget.pvpSession != null
                                      ? Colors.cyanAccent
                                      : Colors.amberAccent)
                                  .withOpacity(0.32),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.amberAccent.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  "2v2",
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  widget.pvpSession != null
                                      ? "VS LINK DOUBLES • ${(widget.trainerName ?? 'TRAINER').toUpperCase()}"
                                      : "${(widget.trainerName ?? 'DOUBLE BATTLE').toUpperCase()}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── 2V2 ARENA VIEW ───────────────────────────────────────────
              Expanded(
                flex: 60,
                child: AnimatedBuilder(
                  animation: _arenaShakeController,
                  builder: (context, child) {
                    final shake = sin(_arenaShakeController.value * pi * 6) *
                        6.0 *
                        (1 - _arenaShakeController.value);
                    return Transform.translate(
                      offset: Offset(shake, 0),
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
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final h = constraints.maxHeight;
                        final double bgScale = max(w / 900.0, h / 750.0);
                        final double vf = (bgScale / 0.455).clamp(0.75, 1.38);

                        // Staggered platform anchors for Opp pair & Player pair
                        final oppBase = _mapBgPoint(685, 404, w, h);
                        final playerBase = _mapBgPoint(290, 610, w, h);

                        final oppOffsets = [
                          Offset(
                            (oppBase.dx - w * 0.21).clamp(w * 0.36, w - 70.0),
                            oppBase.dy + 10.0 * vf,
                          ), // Opp Left (slot 2)
                          Offset(
                            (oppBase.dx + w * 0.03).clamp(w * 0.56, w - 42.0),
                            oppBase.dy - 14.0 * vf,
                          ), // Opp Right (slot 3)
                        ];
                        final playerOffsets = [
                          Offset(
                            (playerBase.dx - w * 0.12).clamp(58.0, w * 0.46),
                            playerBase.dy - 12.0 * vf,
                          ), // Player Left (slot 0)
                          Offset(
                            (playerBase.dx + w * 0.14).clamp(w * 0.24, w * 0.68),
                            playerBase.dy + 14.0 * vf,
                          ), // Player Right (slot 1)
                        ];

                        final double oppMaxW = min(w * 0.31, 132.0 * vf);
                        final double oppMaxH = min(max(78.0, h * 0.28), 118.0 * vf);
                        final double pMaxW = min(w * 0.38, 158.0 * vf);
                        final double pMaxH = min(max(92.0, h * 0.34), 142.0 * vf);

                        final layouts = <int, ResolvedBattleSpriteLayout>{};
                        for (int s = 0; s < 4; s++) {
                          final mon = _slots[s];
                          if (mon == null) continue;
                          final bool isBack = s < 2;
                          layouts[s] = BattleSpriteMetrics.resolve(
                            speciesId: mon.species.id,
                            isBack: isBack,
                            targetZoom: (isBack ? 1.46 : 1.12) * vf,
                            maxWidth: isBack ? pMaxW : oppMaxW,
                            maxHeight: isBack ? pMaxH : oppMaxH,
                          );
                        }

                        _slotCenters[2] = oppOffsets[0] -
                            Offset(0, layouts[2]?.bodyCenterFromBottom ?? 40);
                        _slotCenters[3] = oppOffsets[1] -
                            Offset(0, layouts[3]?.bodyCenterFromBottom ?? 40);
                        _slotCenters[0] = playerOffsets[0] -
                            Offset(0, layouts[0]?.bodyCenterFromBottom ?? 52);
                        _slotCenters[1] = playerOffsets[1] -
                            Offset(0, layouts[1]?.bodyCenterFromBottom ?? 52);

                        final weatherNow = _fieldState.effectiveWeatherMulti([
                          for (final m in _slots)
                            if (m != null) m,
                        ]);

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              _resolvedBattleBackgroundAsset,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.none,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Image.asset(
                                'assets/images/battle_bg_route.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                            if (!_arenaAssetsReady)
                              Container(color: const Color(0xFF141622)),

                            // Opponent pair HUD (Top Left)
                            Positioned(
                              top: 8,
                              left: 8,
                              right: 54,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _slots[2] != null
                                        ? _buildCompactHud(
                                            _slots[2]!,
                                            displayedHp: _displayedHps[2],
                                            isPlayer: false,
                                            slot: 2,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _slots[3] != null
                                        ? _buildCompactHud(
                                            _slots[3]!,
                                            displayedHp: _displayedHps[3],
                                            isPlayer: false,
                                            slot: 3,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),

                            // Sound + Weather Badge (Top Right)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const SoundToggleButton(size: 16),
                                  if (weatherNow != BattleWeather.none) ...[
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.white24),
                                      ),
                                      child: Text(
                                        weatherNow.name.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Opponent Trainer(s) during intro & defeat
                            if (_showOpponentTrainerSprite)
                              Positioned(
                                left: oppBase.dx - (widget.partnerSpriteId != null ? 92 : 60),
                                top: oppBase.dy - 118 * vf,
                                child: AnimatedSlide(
                                  offset: Offset(_opponentTrainerSlideX, 0),
                                  duration: const Duration(milliseconds: 260),
                                  child: widget.partnerSpriteId != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TrainerSpriteWidget(
                                              spriteId: widget.opponentSpriteId ??
                                                  'rocket_jessie',
                                              isBackView: false,
                                              pose: _opponentTrainerPose,
                                              size: 102 * vf,
                                            ),
                                            TrainerSpriteWidget(
                                              spriteId: widget.partnerSpriteId!,
                                              isBackView: false,
                                              pose: _opponentTrainerPose,
                                              size: 102 * vf,
                                            ),
                                          ],
                                        )
                                      : TrainerSpriteWidget(
                                          spriteId: widget.opponentSpriteId ??
                                              'male_blue',
                                          isBackView: false,
                                          pose: _opponentTrainerPose,
                                          size: 118 * vf,
                                        ),
                                ),
                              ),

                            // Opponent Right (slot 3 - back layer) & Opponent Left (slot 2 - front layer)
                            for (final s in const [3, 2])
                              if (_slots[s] != null && layouts[s] != null)
                                _buildCombatantPositioned(
                                  slot: s,
                                  anchor: oppOffsets[s - 2],
                                  layout: layouts[s]!,
                                  isBack: false,
                                ),

                            // Player Trainer Back Sprite during summon
                            if (_showTrainerSprite)
                              Positioned(
                                left: playerBase.dx - 76 * vf,
                                top: playerBase.dy - 150 * vf,
                                child: AnimatedSlide(
                                  offset: Offset(_trainerSlideX, 0),
                                  duration: const Duration(milliseconds: 260),
                                  child: TrainerSpriteWidget(
                                    avatar: _trainer.avatar,
                                    isBackView: true,
                                    pose: _trainerPose,
                                    size: 152 * vf,
                                  ),
                                ),
                              ),

                            // Player Left (slot 0 - back layer) & Player Right (slot 1 - front layer)
                            for (final s in const [0, 1])
                              if (_slots[s] != null && layouts[s] != null)
                                _buildCombatantPositioned(
                                  slot: s,
                                  anchor: playerOffsets[s],
                                  layout: layouts[s]!,
                                  isBack: true,
                                ),

                            // Floating callouts
                            if (_floatingCallout != null &&
                                _slotCenters[_calloutSlot] != null)
                              Positioned(
                                left: max(8, _slotCenters[_calloutSlot]!.dx - 55),
                                top: max(46, _slotCenters[_calloutSlot]!.dy - 58),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: _calloutColor, width: 1.3),
                                  ),
                                  child: Text(
                                    _floatingCallout!,
                                    style: TextStyle(
                                      color: _calloutColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),

                            // Player pair HUD (Bottom Right)
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _slots[0] != null
                                        ? _buildCompactHud(
                                            _slots[0]!,
                                            displayedHp: _displayedHps[0],
                                            isPlayer: true,
                                            slot: 0,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: _slots[1] != null
                                        ? _buildCompactHud(
                                            _slots[1]!,
                                            displayedHp: _displayedHps[1],
                                            isPlayer: true,
                                            slot: 1,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ),
                            ),

                            // Multi-target Move VFX Overlay
                            if (_activeMoveId != null && _activeVfxType != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: AnimatedBuilder(
                                    animation: _vfxController,
                                    builder: (context, _) {
                                      return CustomPaint(
                                        painter: _DoubleMoveVfxPainter(
                                          moveId: _activeMoveId!,
                                          moveType: _activeVfxType!,
                                          moveCategory: _activeVfxCategory,
                                          attackerCenter:
                                              _slotCenters[_vfxActorSlot] ??
                                                  Offset(w * 0.3, h * 0.68),
                                          targetCenters: [
                                            for (final ts in _vfxTargetSlots)
                                              _slotCenters[ts] ??
                                                  Offset(w * 0.68, h * 0.36),
                                          ],
                                          progress: _vfxController.value,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ─── DIALOGUE & ACTION DECK ──────────────────────────────────
              Expanded(
                flex: 40,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Column(
                    children: [
                      // Message box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151B29),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          _currentMessage,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(child: _buildCommandArea()),
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

  Widget _buildCombatantPositioned({
    required int slot,
    required Offset anchor,
    required ResolvedBattleSpriteLayout layout,
    required bool isBack,
  }) {
    final mon = _slots[slot]!;
    final bool isActiveActor =
        !_isProcessingTurn && !_battleEnded && _commandSlot == slot;
    final bool isHighlightedTarget =
        _deckPage == 2 &&
        _pendingTargetMove != null &&
        slot != _commandSlot;
    final double boxW = layout.width + 24;
    final double boxH = layout.height + 24;

    return Positioned(
      left: anchor.dx - boxW / 2,
      top: anchor.dy - boxH,
      child: GestureDetector(
        onTap: isHighlightedTarget && !mon.isFainted
            ? () => _commitPlayerSlotAction(
                  DoubleBattleSlotAction.fight(
                    _pendingTargetMove!,
                    targetSlot: slot,
                  ),
                )
            : null,
        child: SizedBox(
          width: boxW,
          height: boxH,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Active / Target Base Ring
              if (isActiveActor || (isHighlightedTarget && !mon.isFainted))
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: layout.width * 0.85,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActiveActor
                            ? Colors.amberAccent
                            : Colors.redAccent,
                        width: 2.0,
                      ),
                      color: (isActiveActor
                              ? Colors.amberAccent
                              : Colors.redAccent)
                          .withOpacity(0.18),
                    ),
                  ),
                ),
              AnimatedOpacity(
                opacity: _showSlotPokemon[slot]
                    ? (_visualFainted[slot]
                        ? 0.0
                        : (_slotSubmerged[slot] ? 0.25 : 1.0))
                    : 0.0,
                duration: const Duration(milliseconds: 220),
                child: AnimatedScale(
                  scale: _showSlotPokemon[slot] ? _slotSummonScale[slot] : 0.05,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  alignment: Alignment.bottomCenter,
                  child: AnimatedBuilder(
                    animation: _shakeControllers[slot],
                    builder: (_, child) {
                      final dx = sin(_shakeControllers[slot].value * pi * 6) *
                          7.0 *
                          (1 - _shakeControllers[slot].value);
                      return Transform.translate(
                        offset: Offset(dx, 0) + _slotLungeOffset[slot],
                        child: child,
                      );
                    },
                    child: ColorFiltered(
                      colorFilter: _slotFlash[slot]
                          ? const ColorFilter.mode(
                              Colors.white70, BlendMode.srcATop)
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst),
                      child: SizedBox(
                        width: layout.width,
                        height: layout.height,
                        child: PokemonSpriteImage.fromInstance(
                          mon,
                          isBack: isBack,
                          width: layout.width,
                          height: layout.height,
                          alignment: Alignment.bottomCenter,
                          fallbackIconColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHud(
    PokemonInstance mon, {
    required int displayedHp,
    required bool isPlayer,
    required int slot,
  }) {
    final bool isActiveTurnSlot =
        isPlayer && !_isProcessingTurn && !_battleEnded && _commandSlot == slot;
    return Opacity(
      opacity: mon.isFainted ? 0.45 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xD8141A28),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActiveTurnSlot
                ? Colors.amberAccent
                : (isPlayer
                    ? Colors.greenAccent.withOpacity(0.35)
                    : Colors.white24),
            width: isActiveTurnSlot ? 1.8 : 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (mon.isShiny) ...[
                  const Icon(Icons.auto_awesome,
                      color: Colors.amberAccent, size: 11),
                  const SizedBox(width: 3),
                ],
                Flexible(
                  child: Text(
                    mon.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "Lv.${mon.level}",
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 9.5,
                  ),
                ),
                if (mon.status != StatusCondition.none && !mon.isFainted) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      mon.status.shortLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 3),
            HpBar(currentHp: displayedHp, maxHp: mon.maxHp),
            if (isPlayer) ...[
              const SizedBox(height: 2),
              Text(
                "$displayedHp / ${mon.maxHp}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommandArea() {
    if (_battleEnded) {
      return Center(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _finishAndExit,
            icon: Icon(
              _playerWon ? Icons.emoji_events_rounded : Icons.exit_to_app,
            ),
            label: Text(
              _playerWon
                  ? (widget.continueButtonLabel ?? "CONTINUE")
                  : (widget.defeatButtonLabel ?? "RETURN"),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _playerWon ? Colors.green.shade700 : Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    }

    if (!_introComplete || _isProcessingTurn) {
      return const Center(
        child: Text(
          "Executing turn...",
          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
        ),
      );
    }

    final actor = _slots[_commandSlot];
    if (actor == null) return const SizedBox.shrink();

    // Target Picker
    if (_deckPage == 2 && _pendingTargetMove != null) {
      final move = _pendingTargetMove!;
      final List<int> candidateSlots = move.id == 'acupressure'
          ? [_commandSlot, _commandSlot ^ 1]
          : [
              2,
              3,
              if (_slots[_commandSlot ^ 1] != null) _commandSlot ^ 1,
            ];
      return Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() {
                  _deckPage = 1;
                  _pendingTargetMove = null;
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("BACK TO MOVES"),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const Spacer(),
              Text(
                "TARGET FOR ${move.name.toUpperCase()}",
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                for (final ts in candidateSlots)
                  if (_slots[ts] != null && !_slots[ts]!.isFainted)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildTargetCard(
                          slot: ts,
                          mon: _slots[ts]!,
                          move: move,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ],
      );
    }

    // Move List
    if (_deckPage == 1) {
      final moves = actor.activeMoves;
      return Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _deckPage = 0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text("BACK"),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
              const Spacer(),
              Text(
                "${actor.nickname.toUpperCase()} (${_commandSlot == 0 ? 'LEFT' : 'RIGHT'})",
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.35,
              ),
              itemCount: moves.length,
              itemBuilder: (_, idx) {
                final m = moves[idx];
                final tag =
                    DoubleBattleEngine.targetTagForMove(m, user: actor);
                final bool usable = m.currentPp > 0 ||
                    !actor.activeMoves.any((x) => x.currentPp > 0);
                return Material(
                  color: m.type.color.withOpacity(usable ? 0.24 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: usable ? () => _onMoveTapped(m) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: m.type.color.withOpacity(usable ? 0.85 : 0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${m.type.name.toUpperCase()} • ${m.powerLabel}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                "PP ${m.currentPp}/${m.maxPp}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
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
      );
    }

    // Main 4 Action Buttons (+ optional Back to Left slot when selecting Right slot)
    final bool canGoBack = _commandSlot == 1 &&
        _slots[0] != null &&
        !_slots[0]!.isFainted &&
        !_slots[0]!.hasForcedTurnAction;

    return Column(
      children: [
        if (canGoBack)
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _goBackToPreviousSlot,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: Colors.amberAccent, size: 15),
                    SizedBox(width: 4),
                    Text(
                      "RE-PICK LEFT SLOT",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDeckButton(
                        title: "FIGHT",
                        subtitle: "Choose Move",
                        top: const Color(0xFFE53935),
                        bottom: const Color(0xFFB71C1C),
                        icon: Icons.flash_on_rounded,
                        onTap: () => setState(() => _deckPage = 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDeckButton(
                        title: "BAG",
                        subtitle: widget.pvpSession != null
                            ? "Disabled in PvP"
                            : (widget.isFrontierBattle
                                ? "Disabled in Frontier"
                                : "Medicine & Balls"),
                        top: const Color(0xFFFB8C00),
                        bottom: const Color(0xFFE65100),
                        icon: Icons.backpack_rounded,
                        onTap: (widget.pvpSession != null ||
                                widget.isFrontierBattle)
                            ? null
                            : _openBagModal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildDeckButton(
                        title: "POKÉMON",
                        subtitle: "Switch Partner",
                        top: const Color(0xFF43A047),
                        bottom: const Color(0xFF1B5E20),
                        icon: Icons.catching_pokemon,
                        onTap: _openSwitchModal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDeckButton(
                        title: "FORFEIT",
                        subtitle: "End Battle",
                        top: const Color(0xFF546E7A),
                        bottom: const Color(0xFF37474F),
                        icon: Icons.flag_rounded,
                        onTap: _onRunPressed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetCard({
    required int slot,
    required PokemonInstance mon,
    required Move move,
  }) {
    final bool isAlly = slot < 2;
    final String roleLabel = slot == 2
        ? "FOE LEFT"
        : (slot == 3 ? "FOE RIGHT" : (slot == 0 ? "ALLY LEFT" : "ALLY RIGHT"));
    final double eff = move.category == MoveCategory.status
        ? 1.0
        : PokemonTypeExtension.getEffectiveness(
            move.type,
            BattleEngine.defensiveTypesOf(mon),
          );
    String? effBadge;
    Color effColor = Colors.white70;
    if (move.category != MoveCategory.status) {
      if (eff >= 2.0) {
        effBadge = "${eff.toStringAsFixed(0)}× SUPER!";
        effColor = Colors.greenAccent;
      } else if (eff == 0.0) {
        effBadge = "IMMUNE";
        effColor = Colors.redAccent;
      } else if (eff < 1.0) {
        effBadge = "${eff}× RESIST";
        effColor = Colors.orangeAccent;
      }
    }

    return InkWell(
      onTap: () => _commitPlayerSlotAction(
        DoubleBattleSlotAction.fight(move, targetSlot: slot),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isAlly ? const Color(0xFF1A2A24) : const Color(0xFF281D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAlly
                ? Colors.greenAccent.withOpacity(0.55)
                : Colors.redAccent.withOpacity(0.65),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              roleLabel,
              style: TextStyle(
                color: isAlly ? Colors.greenAccent : Colors.redAccent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            PokemonSpriteImage.fromInstance(
              mon,
              width: 36,
              height: 36,
              fallbackIconSize: 26,
            ),
            const SizedBox(height: 3),
            Text(
              mon.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            Text(
              "HP ${(mon.hpPercent * 100).round()}%",
              style: const TextStyle(color: Colors.white60, fontSize: 9.5),
            ),
            if (effBadge != null) ...[
              const SizedBox(height: 2),
              Text(
                effBadge,
                style: TextStyle(
                  color: effColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeckButton({
    required String title,
    required String subtitle,
    required Color top,
    required Color bottom,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: onTap != null
                ? [top, bottom]
                : [const Color(0xFF2B303D), const Color(0xFF1F232E)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon,
                    color: onTap != null ? Colors.white : Colors.white38,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: onTap != null ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onTap != null
                              ? Colors.white70
                              : Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoubleMoveVfxPainter extends CustomPainter {
  final String moveId;
  final PokemonType moveType;
  final MoveCategory moveCategory;
  final Offset attackerCenter;
  final List<Offset> targetCenters;
  final double progress;

  _DoubleMoveVfxPainter({
    required this.moveId,
    required this.moveType,
    required this.moveCategory,
    required this.attackerCenter,
    required this.targetCenters,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.clamp(0.0, 1.0);
    final fade = (1.0 - max(0.0, (t - 0.72) / 0.28)).clamp(0.0, 1.0);

    for (final defenderCenter in targetCenters) {
      final rawDir = defenderCenter - attackerCenter;
      final bool isSelfTarget = rawDir.distance < 2.0;
      final Offset dir =
          isSelfTarget ? const Offset(110, -90) : rawDir;
      final double dist = max(1.0, dir.distance);
      final Offset unit = dir / dist;
      final Offset perp = Offset(-unit.dy, unit.dx);

      final bool painted = MoveVfxEffects.tryPaintMove(
        canvas: canvas,
        size: size,
        moveId: moveId,
        moveType: moveType,
        moveCategory: moveCategory,
        t: t,
        fade: fade,
        isSelfTarget: isSelfTarget,
        attackerCenter: attackerCenter,
        defenderCenter: defenderCenter,
        attackerSize: 110.0,
        defenderSize: 100.0,
        dir: dir,
        dist: dist,
        unit: unit,
        perp: perp,
      );
      if (!painted) {
        MoveVfxEffects.paintFallback(
          canvas: canvas,
          size: size,
          moveType: moveType,
          moveCategory: moveCategory,
          t: t,
          fade: fade,
          isSelfTarget: isSelfTarget,
          attackerCenter: attackerCenter,
          defenderCenter: defenderCenter,
          unit: unit,
          perp: perp,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoubleMoveVfxPainter oldDelegate) => true;
}
