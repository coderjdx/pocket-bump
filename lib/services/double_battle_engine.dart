import 'dart:math';
import '../models/ability.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import 'battle_engine.dart';
import 'pokedex_database.dart';

enum DoubleBattleActionType {
  fight,
  switchPokemon,
  useItem,
  pass,
}

class DoubleBattleSlotAction {
  final DoubleBattleActionType type;
  final Move? move;
  final int? targetSlot; // 0: P-Left, 1: P-Right, 2: O-Left, 3: O-Right
  final int? switchPartyIndex;
  final String? itemId;
  final int? itemTargetPartyIndex;
  final String? moveIdForPp;

  const DoubleBattleSlotAction._({
    required this.type,
    this.move,
    this.targetSlot,
    this.switchPartyIndex,
    this.itemId,
    this.itemTargetPartyIndex,
    this.moveIdForPp,
  });

  factory DoubleBattleSlotAction.fight(Move move, {int? targetSlot}) =>
      DoubleBattleSlotAction._(
        type: DoubleBattleActionType.fight,
        move: move,
        targetSlot: targetSlot,
      );

  factory DoubleBattleSlotAction.switchPokemon(int partyIndex) =>
      DoubleBattleSlotAction._(
        type: DoubleBattleActionType.switchPokemon,
        switchPartyIndex: partyIndex,
      );

  factory DoubleBattleSlotAction.useItem(
    String itemId, {
    int? targetPartyIndex,
    String? moveIdForPp,
  }) =>
      DoubleBattleSlotAction._(
        type: DoubleBattleActionType.useItem,
        itemId: itemId,
        itemTargetPartyIndex: targetPartyIndex,
        moveIdForPp: moveIdForPp,
      );

  factory DoubleBattleSlotAction.pass() => const DoubleBattleSlotAction._(
        type: DoubleBattleActionType.pass,
      );

  DoubleBattleSlotAction copyWith({int? targetSlot}) {
    return DoubleBattleSlotAction._(
      type: type,
      move: move,
      targetSlot: targetSlot ?? this.targetSlot,
      switchPartyIndex: switchPartyIndex,
      itemId: itemId,
      itemTargetPartyIndex: itemTargetPartyIndex,
      moveIdForPp: moveIdForPp,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (move != null) 'moveId': move!.id,
        if (targetSlot != null) 'targetSlot': targetSlot,
        if (switchPartyIndex != null) 'switchPartyIndex': switchPartyIndex,
        if (itemId != null) 'itemId': itemId,
        if (itemTargetPartyIndex != null)
          'itemTargetPartyIndex': itemTargetPartyIndex,
        if (moveIdForPp != null) 'moveIdForPp': moveIdForPp,
      };

  factory DoubleBattleSlotAction.fromJson(
    Map<String, dynamic> json,
    PokemonInstance? actor,
  ) {
    final typeName = json['type'] as String? ?? 'pass';
    switch (typeName) {
      case 'fight':
        final moveId = json['moveId'] as String?;
        Move? matched;
        if (actor != null && moveId != null) {
          for (final m in actor.activeMoves) {
            if (m.id == moveId) {
              matched = m;
              break;
            }
          }
          matched ??= PokedexDatabase.moves[moveId]?.copy();
        } else if (moveId != null) {
          matched = PokedexDatabase.moves[moveId]?.copy();
        }
        matched ??= PokedexDatabase.moves['struggle']?.copy();
        return DoubleBattleSlotAction.fight(
          matched!,
          targetSlot: (json['targetSlot'] as num?)?.toInt(),
        );
      case 'switchPokemon':
        return DoubleBattleSlotAction.switchPokemon(
          (json['switchPartyIndex'] as num?)?.toInt() ?? 0,
        );
      case 'useItem':
        return DoubleBattleSlotAction.useItem(
          json['itemId'] as String? ?? 'potion',
          targetPartyIndex: (json['itemTargetPartyIndex'] as num?)?.toInt(),
          moveIdForPp: json['moveIdForPp'] as String?,
        );
      default:
        return DoubleBattleSlotAction.pass();
    }
  }
}

class DoubleBattleStepEvent {
  final String message;
  final int actorSlot; // 0..3
  final int targetSlot; // 0..3 (primary target for UI)
  final List<int> vfxTargetSlots; // all slots hit by spread VFX
  final String? moveId;
  final PokemonType? moveType;
  final MoveCategory? moveCategory;
  final int damageDealt;
  final bool isCrit;
  final double effectiveness;
  final String? statChangedLabel;
  final bool statTargetIsSelf;
  final String? statusInflictedLabel;
  final bool isMiss;
  final bool isStatusTick;
  final bool isSelfDamage;
  final int healAmount;
  final String? abilityTriggeredName;
  final bool hideMoveVfx;
  final bool isChargeTurn;
  final bool submergeActorAfter;
  final bool surfaceActorOnAttack;
  final bool swapUserWithAlly;
  final int? switchInSlot;
  final PokemonInstance? switchedInMon;
  final Map<int, int> slotHpSnapshots;
  final List<int> faintedSlots;

  const DoubleBattleStepEvent({
    required this.message,
    required this.actorSlot,
    this.targetSlot = 0,
    this.vfxTargetSlots = const [],
    this.moveId,
    this.moveType,
    this.moveCategory,
    this.damageDealt = 0,
    this.isCrit = false,
    this.effectiveness = 1.0,
    this.statChangedLabel,
    this.statTargetIsSelf = false,
    this.statusInflictedLabel,
    this.isMiss = false,
    this.isStatusTick = false,
    this.isSelfDamage = false,
    this.healAmount = 0,
    this.abilityTriggeredName,
    this.hideMoveVfx = false,
    this.isChargeTurn = false,
    this.submergeActorAfter = false,
    this.surfaceActorOnAttack = false,
    this.swapUserWithAlly = false,
    this.switchInSlot,
    this.switchedInMon,
    this.slotHpSnapshots = const {},
    this.faintedSlots = const [],
  });
}

class DoubleBattleEngine {
  static final Random _rng = Random();

  static const Set<String> _allOthersMoves = {
    'earthquake',
    'surf',
    'discharge',
    'lava_plume',
    'sludge_wave',
    'bulldoze',
    'magnitude',
    'petal_blizzard',
    'explosion',
    'self_destruct',
    'synchronoise',
  };

  static const Set<String> _allFoesMoves = {
    'rock_slide',
    'blizzard',
    'heat_wave',
    'icy_wind',
    'muddy_water',
    'eruption',
    'razor_leaf',
    'acid',
    'swift',
    'disarming_voice',
    'powder_snow',
    'bubble',
    'razor_wind',
    'twister',
    'hyper_voice',
    'air_cutter',
    'growl',
    'tail_whip',
    'string_shot',
    'leer',
    'sweet_scent',
    'poison_gas',
    'captivate',
  };

  static const Set<String> _allyOnlyMoves = {
    'helping_hand',
    'after_you',
  };

  static const Set<String> _allyOrSelfMoves = {
    'acupressure',
  };

  static const Set<String> _userSideMoves = {
    'reflect',
    'light_screen',
    'safeguard',
    'mist',
    'tailwind',
    'lucky_chant',
    'wide_guard',
    'quick_guard',
    'aromatherapy',
  };

  static const Set<String> _foeSideMoves = {
    'spikes',
    'toxic_spikes',
    'stealth_rock',
  };

  static const Set<String> _entireFieldMoves = {
    'rain_dance',
    'sunny_day',
    'sandstorm',
    'hail',
    'haze',
    'perish_song',
    'gravity',
    'wonder_room',
    'mud_sport',
    'water_sport',
  };

  static const Set<String> _randomFoeMoves = {
    'outrage',
    'petal_dance',
    'thrash',
    'uproar',
    'struggle',
  };

  static const Set<String> _selfOnlyMoves = {
    'harden',
    'swords_dance',
    'agility',
    'splash',
    'rest',
    'soft_boiled',
    'acid_armor',
    'sharpen',
    'recover',
    'withdraw',
    'teleport',
    'double_team',
    'bide',
    'metronome',
    'substitute',
    'growth',
    'meditate',
    'minimize',
    'defense_curl',
    'barrier',
    'focus_energy',
    'conversion',
    'conversion_2',
    'protect',
    'belly_drum',
    'destiny_bond',
    'detect',
    'endure',
    'sleep_talk',
    'baton_pass',
    'synthesis',
    'moonlight',
    'morning_sun',
    'milk_drink',
    'heal_bell',
    'stockpile',
    'swallow',
    'follow_me',
    'charge',
    'ingrain',
    'magic_coat',
    'recycle',
    'imprison',
    'refresh',
    'grudge',
    'camouflage',
    'slack_off',
    'cosmic_power',
    'iron_defense',
    'calm_mind',
    'dragon_dance',
    'roost',
    'healing_wish',
    'aqua_ring',
    'magnet_rise',
    'rock_polish',
    'nasty_plot',
    'rage_powder',
    'quiver_dance',
    'coil',
    'ally_switch',
    'shell_smash',
    'work_up',
    'bulk_up',
    'copycat',
    'mirror_move',
    'counter',
    'mirror_coat',
    'amnesia',
  };

  static bool isPlayerSlot(int slot) => slot == 0 || slot == 1;
  static int allySlotOf(int slot) => slot ^ 1;
  static List<int> opposingSlotsOf(int slot) =>
      isPlayerSlot(slot) ? const [2, 3] : const [0, 1];

  /// Canon Gen 5 MoveTarget classification across all PokedexDatabase moves.
  static MoveTarget classifyMoveTarget(Move move, {PokemonInstance? user}) {
    if (_allOthersMoves.contains(move.id)) return MoveTarget.allOthers;
    if (_allFoesMoves.contains(move.id)) return MoveTarget.allFoes;
    if (_allyOnlyMoves.contains(move.id)) return MoveTarget.allyOnly;
    if (_allyOrSelfMoves.contains(move.id)) return MoveTarget.allyOrSelf;
    if (_userSideMoves.contains(move.id)) return MoveTarget.userSide;
    if (_foeSideMoves.contains(move.id)) return MoveTarget.foeSide;
    if (_entireFieldMoves.contains(move.id)) return MoveTarget.entireField;
    if (_randomFoeMoves.contains(move.id)) return MoveTarget.randomFoe;
    if (move.id == 'curse') {
      final isGhost =
          user?.effectiveTypes.contains(PokemonType.ghost) ?? false;
      return isGhost ? MoveTarget.singleAdjacent : MoveTarget.self;
    }
    if (_selfOnlyMoves.contains(move.id)) return MoveTarget.self;
    if (move.category == MoveCategory.status &&
        move.statTarget != null &&
        move.statChange > 0 &&
        move.id != 'swagger' &&
        move.id != 'flatter') {
      return MoveTarget.self;
    }
    return MoveTarget.singleAdjacent;
  }

  static String targetTagForMove(Move move, {PokemonInstance? user}) {
    switch (classifyMoveTarget(move, user: user)) {
      case MoveTarget.allFoes:
        return 'ALL FOES';
      case MoveTarget.allOthers:
        return 'ALL OTHERS';
      case MoveTarget.allyOnly:
        return 'ALLY';
      case MoveTarget.allyOrSelf:
        return 'ALLY/SELF';
      case MoveTarget.userSide:
        return 'TEAM';
      case MoveTarget.foeSide:
        return 'FOE SIDE';
      case MoveTarget.entireField:
        return 'FIELD';
      case MoveTarget.randomFoe:
        return 'RANDOM';
      case MoveTarget.self:
        return 'SELF';
      case MoveTarget.singleAdjacent:
        return 'TARGET';
    }
  }

  static Map<int, int> snapshotHps(List<PokemonInstance?> slots) {
    final map = <int, int>{};
    for (int i = 0; i < 4; i++) {
      final mon = slots[i];
      if (mon != null) map[i] = mon.currentHp;
    }
    return map;
  }

  static List<int> livingFaintedSlots(List<PokemonInstance?> slots) {
    final fainted = <int>[];
    for (int i = 0; i < 4; i++) {
      final mon = slots[i];
      if (mon != null && mon.isFainted) fainted.add(i);
    }
    return fainted;
  }

  static DoubleBattleStepEvent _adaptStepEvent(
    BattleStepEvent ev, {
    required int actorSlot,
    required int targetSlot,
    List<int>? vfxTargetSlots,
    required List<PokemonInstance?> slots,
    bool forceHideVfx = false,
  }) {
    return DoubleBattleStepEvent(
      message: ev.message,
      actorSlot: actorSlot,
      targetSlot: targetSlot,
      vfxTargetSlots: vfxTargetSlots ?? [targetSlot],
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
      hideMoveVfx: forceHideVfx || ev.hideMoveVfx,
      isChargeTurn: ev.isChargeTurn,
      submergeActorAfter: ev.submergeActorAfter,
      surfaceActorOnAttack: ev.surfaceActorOnAttack,
      slotHpSnapshots: snapshotHps(slots),
      faintedSlots: livingFaintedSlots(slots),
    );
  }

  static List<int> _livingSlots(List<PokemonInstance?> slots, List<int> pool) =>
      [
        for (final s in pool)
          if (slots[s] != null && !slots[s]!.isFainted) s,
      ];

  static bool _isAllyFriendGuardActive(
    List<PokemonInstance?> slots,
    int defenderSlot, {
    required bool bypassDefAbility,
  }) {
    if (bypassDefAbility) return false;
    final ally = slots[allySlotOf(defenderSlot)];
    return ally != null &&
        !ally.isFainted &&
        ally.effectiveAbilityId == 'friend_guard';
  }

  static bool _isDoubleScreenActive(
    List<PokemonInstance?> slots,
    bool sideIsPlayer,
  ) {
    final pair = sideIsPlayer ? const [0, 1] : const [2, 3];
    return _livingSlots(slots, pair).length >= 2;
  }

  /// Entry hazards + switch-in abilities for a slot in a Double Battle.
  /// Intimidate hits both active foes cleanly.
  static List<DoubleBattleStepEvent> triggerDoubleSwitchIn({
    required int slot,
    required List<PokemonInstance?> slots,
    required BattleFieldState field,
  }) {
    final mon = slots[slot];
    if (mon == null || mon.isFainted) return const [];
    final isPlayer = isPlayerSlot(slot);
    final foes = _livingSlots(slots, opposingSlotsOf(slot));
    final firstFoe = foes.isNotEmpty
        ? slots[foes.first]!
        : (slots[opposingSlotsOf(slot).first] ?? mon);

    // For non-Intimidate entry hazards & abilities, reuse BattleEngine.onPokemonEnterBattle
    // (temporarily passing neutral ability if intimidate so we handle multi-foe Intimidate below).
    final bool isIntimidate = mon.effectiveAbilityId == 'intimidate';
    final savedActiveAb = mon.activeAbilityId;
    if (isIntimidate) {
      mon.activeAbilityId = 'run_away';
    }
    final baseEvents = BattleEngine.onPokemonEnterBattle(
      mon,
      firstFoe,
      isPlayer: isPlayer,
      isWild: false,
      field: field,
    );
    if (isIntimidate) {
      mon.activeAbilityId = savedActiveAb;
    }

    final events = <DoubleBattleStepEvent>[
      for (final ev in baseEvents)
        _adaptStepEvent(
          ev,
          actorSlot: slot,
          targetSlot: foes.isNotEmpty ? foes.first : slot,
          vfxTargetSlots: const [],
          slots: slots,
        ),
    ];

    if (!mon.isFainted && isIntimidate) {
      for (final foeSlot in foes) {
        final foe = slots[foeSlot];
        if (foe == null || foe.isFainted) continue;
        final foeAb = foe.effectiveAbilityId;
        final foeSide = field.sideFor(isPlayerSlot(foeSlot));
        if (foe.substituteHp > 0 || foeSide.mistTurns > 0) {
          events.add(DoubleBattleStepEvent(
            message: foe.substituteHp > 0
                ? "${foe.nickname}'s substitute blocked Intimidate!"
                : "${foe.nickname} is protected by Mist!",
            actorSlot: slot,
            targetSlot: foeSlot,
            hideMoveVfx: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
          continue;
        }
        if (foeAb == 'clear_body' || foeAb == 'hyper_cutter') {
          events.add(DoubleBattleStepEvent(
            message:
                "${foe.nickname}'s ${AbilityDatabase.nameOf(foeAb)} prevented Intimidate!",
            actorSlot: foeSlot,
            targetSlot: foeSlot,
            hideMoveVfx: true,
            abilityTriggeredName: AbilityDatabase.nameOf(foeAb),
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          final delta = foe.modifyStatStage('atk', -1);
          events.add(DoubleBattleStepEvent(
            message: delta != 0
                ? "${mon.nickname}'s Intimidate cut ${foe.nickname}'s Attack!"
                : "${mon.nickname}'s Intimidate had no further effect on ${foe.nickname}!",
            actorSlot: slot,
            targetSlot: foeSlot,
            statChangedLabel: delta != 0 ? 'ATK ▼' : null,
            statTargetIsSelf: false,
            hideMoveVfx: true,
            abilityTriggeredName: 'Intimidate',
            slotHpSnapshots: snapshotHps(slots),
          ));
          if (delta != 0 && foeAb == 'defiant') {
            foe.modifyStatStage('atk', 2);
            events.add(DoubleBattleStepEvent(
              message: "${foe.nickname}'s Defiant sharply raised its Attack!",
              actorSlot: foeSlot,
              targetSlot: foeSlot,
              statChangedLabel: 'ATK ▲▲',
              statTargetIsSelf: true,
              hideMoveVfx: true,
              abilityTriggeredName: 'Defiant',
              slotHpSnapshots: snapshotHps(slots),
            ));
          } else if (delta != 0 && foeAb == 'rattled') {
            foe.modifyStatStage('spe', 1);
            events.add(DoubleBattleStepEvent(
              message: "${foe.nickname}'s Rattled boosted its Speed!",
              actorSlot: foeSlot,
              targetSlot: foeSlot,
              statChangedLabel: 'SPE ▲',
              statTargetIsSelf: true,
              hideMoveVfx: true,
              abilityTriggeredName: 'Rattled',
              slotHpSnapshots: snapshotHps(slots),
            ));
          }
        }
      }
    }

    return events;
  }

  static int _effectiveMovePriority(
    PokemonInstance actor,
    Move move,
  ) {
    int p = move.priority;
    if (move.id == 'helping_hand') p = 5;
    if (move.id == 'wide_guard' || move.id == 'quick_guard') p = 3;
    if (move.id == 'follow_me' ||
        move.id == 'rage_powder' ||
        move.id == 'ally_switch') {
      p = 2;
    }
    if (move.category == MoveCategory.status &&
        actor.effectiveAbilityId == 'prankster') {
      p += 1;
    }
    return p;
  }

  static int _effectiveDoubleSpeed(
    PokemonInstance mon,
    BattleSideState side,
    BattleWeather weather, {
    bool isPlayer = false,
    Trainer? playerTrainer,
  }) {
    double spe = mon.effectiveSpe.toDouble();
    final ab = mon.effectiveAbilityId;
    if (weather == BattleWeather.sun && ab == 'chlorophyll') spe *= 2.0;
    if (weather == BattleWeather.rain && ab == 'swift_swim') spe *= 2.0;
    if (weather == BattleWeather.sandstorm && ab == 'sand_rush') spe *= 2.0;
    if (side.tailwindTurns > 0) spe *= 2.0;
    if (isPlayer && playerTrainer != null) {
      spe *= playerTrainer.speBadgeMultiplier;
    }
    return spe.round().clamp(1, 99999);
  }

  /// Resolves one complete 2v2 turn deterministically given [slotActions] (length 4)
  /// and active [slots] (length 4: [P-Left, P-Right, O-Left, O-Right]).
  static List<DoubleBattleStepEvent> resolveDoubleTurn({
    required List<PokemonInstance?> slots,
    required List<DoubleBattleSlotAction> slotActions,
    required List<PokemonInstance> playerParty,
    required List<PokemonInstance> opponentParty,
    required BattleFieldState field,
    Trainer? playerTrainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final List<DoubleBattleStepEvent> events = [];

    // 0. Clear per-turn transient flags & side guards
    field.playerSide.clearTurnGuards();
    field.opponentSide.clearTurnGuards();
    for (int i = 0; i < 4; i++) {
      final mon = slots[i];
      if (mon == null) continue;
      mon
        ..isProtectedThisTurn = false
        ..isEnduringThisTurn = false
        ..flinchedThisTurn = false
        ..actedFirstThisTurn = false
        ..lastDamageTakenThisTurn = 0
        ..lastPhysicalDamageTakenThisTurn = 0
        ..lastSpecialDamageTakenThisTurn = 0
        ..isRoostedThisTurn = false
        ..hasMagicCoatThisTurn = false;
    }

    // 1. Handle Item uses (player side only in Trainer/Campaign Doubles)
    for (int s = 0; s < 4; s++) {
      final act = slotActions[s];
      if (act.type == DoubleBattleActionType.useItem &&
          act.itemId != null &&
          isPlayerSlot(s)) {
        final party = playerParty;
        final tIdx = act.itemTargetPartyIndex ?? 0;
        if (tIdx >= 0 && tIdx < party.length && playerTrainer != null) {
          final targetMon = party[tIdx];
          final int beforeHp = targetMon.currentHp;
          final int? moveIdx = act.moveIdForPp != null
              ? () {
                  final idx = targetMon.moves
                      .indexWhere((m) => m.id == act.moveIdForPp);
                  return idx >= 0 ? idx : null;
                }()
              : null;
          final bool applied =
              ItemDatabase.canUseMedicineOn(act.itemId!, targetMon);
          final String msg = applied
              ? ItemDatabase.applyMedicineToPokemon(
                  itemId: act.itemId!,
                  targetMon: targetMon,
                  moveIndex: moveIdx,
                  actorName: playerTrainer.name,
                  inBattle: true,
                )
              : "${playerTrainer.name} tried to use ${ItemDatabase.byId(act.itemId!)?.name ?? act.itemId}, but it had no effect!";
          if (applied) {
            playerTrainer.adjustItemCount(act.itemId!, -1);
          }
          events.add(DoubleBattleStepEvent(
            message: msg,
            actorSlot: s,
            targetSlot: s,
            healAmount: max(0, targetMon.currentHp - beforeHp),
            isStatusTick: true,
            hideMoveVfx: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
      }
    }

    // 2. Handle Voluntary Switches (ordered by current effective Speed)
    final switchSlots = <int>[
      for (int s = 0; s < 4; s++)
        if (slotActions[s].type == DoubleBattleActionType.switchPokemon &&
            slots[s] != null)
          s,
    ];
    final weatherNow =
        field.effectiveWeatherMulti([for (final m in slots) if (m != null) m]);
    switchSlots.sort((a, b) {
      final ma = slots[a]!;
      final mb = slots[b]!;
      final sa = _effectiveDoubleSpeed(
        ma,
        field.sideFor(isPlayerSlot(a)),
        weatherNow,
        isPlayer: isPlayerSlot(a),
        playerTrainer: playerTrainer,
      );
      final sb = _effectiveDoubleSpeed(
        mb,
        field.sideFor(isPlayerSlot(b)),
        weatherNow,
        isPlayer: isPlayerSlot(b),
        playerTrainer: playerTrainer,
      );
      return sb.compareTo(sa);
    });

    for (final s in switchSlots) {
      final leaving = slots[s];
      final party = isPlayerSlot(s) ? playerParty : opponentParty;
      final partyIdx = slotActions[s].switchPartyIndex;
      if (leaving == null ||
          partyIdx == null ||
          partyIdx < 0 ||
          partyIdx >= party.length) {
        continue;
      }
      final incoming = party[partyIdx];
      if (incoming.isFainted || slots.contains(incoming)) continue;

      final leaveEvs = BattleEngine.onPokemonLeaveBattle(
        leaving,
        isPlayer: isPlayerSlot(s),
        isWild: false,
      );
      for (final ev in leaveEvs) {
        events.add(_adaptStepEvent(
          ev,
          actorSlot: s,
          targetSlot: s,
          slots: slots,
          forceHideVfx: true,
        ));
      }

      slots[s] = incoming;
      events.add(DoubleBattleStepEvent(
        message: isPlayerSlot(s)
            ? "Come back, ${leaving.nickname}! Go, ${incoming.nickname}!"
            : "Foe withdrew ${leaving.nickname} and sent out ${incoming.nickname}!",
        actorSlot: s,
        targetSlot: s,
        switchInSlot: s,
        switchedInMon: incoming,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      events.addAll(triggerDoubleSwitchIn(
        slot: s,
        slots: slots,
        field: field,
      ));
    }

    // 3. Collect all queued Fight actions and sort by Canon Priority + Speed
    final pendingFightSlots = <int>[
      for (int s = 0; s < 4; s++)
        if (slotActions[s].type == DoubleBattleActionType.fight &&
            slots[s] != null &&
            !slots[s]!.isFainted)
          s,
    ];
    final Map<int, Move> resolvedMoves = {};
    final Map<int, int> movePriority = {};
    for (final s in pendingFightSlots) {
      final mon = slots[s]!;
      final actMove =
          BattleEngine.resolveEffectiveMove(mon, slotActions[s].move) ??
              PokedexDatabase.moves['struggle']!.copy();
      resolvedMoves[s] = actMove;
      movePriority[s] = _effectiveMovePriority(mon, actMove);
    }

    int compareFightOrder(int a, int b) {
      final pa = movePriority[a] ?? 0;
      final pb = movePriority[b] ?? 0;
      if (pa != pb) return pb.compareTo(pa);
      final w = field.effectiveWeatherMulti(
          [for (final m in slots) if (m != null) m]);
      final sa = _effectiveDoubleSpeed(
        slots[a]!,
        field.sideFor(isPlayerSlot(a)),
        w,
        isPlayer: isPlayerSlot(a),
        playerTrainer: playerTrainer,
      );
      final sb = _effectiveDoubleSpeed(
        slots[b]!,
        field.sideFor(isPlayerSlot(b)),
        w,
        isPlayer: isPlayerSlot(b),
        playerTrainer: playerTrainer,
      );
      if (sa != sb) return sb.compareTo(sa);
      return random.nextBool() ? -1 : 1;
    }

    final remainingOrder = List<int>.from(pendingFightSlots)
      ..sort(compareFightOrder);
    final Set<int> actedSlots = {};

    bool firstMoversMarked = false;

    while (remainingOrder.isNotEmpty) {
      // Re-sort dynamically for Tailwind / Paralysis / Stat changes (canon Dynamic Speed Gen V+)
      remainingOrder.sort(compareFightOrder);
      final int actorSlot = remainingOrder.removeAt(0);
      if (actedSlots.contains(actorSlot)) continue;
      actedSlots.add(actorSlot);

      final PokemonInstance? actor = slots[actorSlot];
      if (actor == null || actor.isFainted) continue;

      if (!firstMoversMarked) {
        actor.actedFirstThisTurn = true;
        firstMoversMarked = true;
      }

      final Move move = resolvedMoves[actorSlot]!;
      final int allySlot = allySlotOf(actorSlot);
      final PokemonInstance? ally = slots[allySlot];
      final List<int> foeSlots = opposingSlotsOf(actorSlot);
      final Move? foeIntended = () {
        for (final fs in foeSlots) {
          if (slots[fs] != null && !slots[fs]!.isFainted) {
            return resolvedMoves[fs];
          }
        }
        return null;
      }();

      // Special canon Doubles move handlers
      final MoveTarget targetKind = classifyMoveTarget(move, user: actor);

      // Run pre-move status / sleep / freeze / flinch / recharge checks cleanly
      final preBlock = _checkPreMoveActionability(
        actor: actor,
        actorSlot: actorSlot,
        move: move,
        slots: slots,
        random: random,
      );
      if (preBlock != null) {
        events.addAll(preBlock);
        continue;
      }

      // Deduct PP once (for special Doubles moves & spread moves handled directly here)
      void consumePpOnce() {
        if (move.currentPp <= 0) return;
        int ppCost = 1;
        for (final fs in _livingSlots(slots, foeSlots)) {
          if (actor.effectiveAbilityId != 'mold_breaker' &&
              slots[fs]!.effectiveAbilityId == 'pressure') {
            ppCost = 2;
            break;
          }
        }
        move.currentPp = max(0, move.currentPp - ppCost);
      }

      if (move.id == 'helping_hand') {
        consumePpOnce();
        if (ally == null || ally.isFainted || actedSlots.contains(allySlot)) {
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used Helping Hand, but it failed!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            hideMoveVfx: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          ally.helpingHandBoosted = true;
          events.add(DoubleBattleStepEvent(
            message:
                "${actor.nickname} is ready to help ${ally.nickname}!",
            actorSlot: actorSlot,
            targetSlot: allySlot,
            vfxTargetSlots: [allySlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statChangedLabel: 'PWR ▲',
            statTargetIsSelf: false,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
        continue;
      }

      if (move.id == 'after_you') {
        consumePpOnce();
        final bool allyWaiting =
            ally != null && !ally.isFainted && remainingOrder.contains(allySlot);
        if (!allyWaiting) {
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used After You, but it failed!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            hideMoveVfx: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          remainingOrder.remove(allySlot);
          remainingOrder.insert(0, allySlot);
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} took ${ally.nickname}'s kind offer!",
            actorSlot: actorSlot,
            targetSlot: allySlot,
            vfxTargetSlots: [allySlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            slotHpSnapshots: snapshotHps(slots),
          ));
          // Prevent dynamic sort on next iteration from re-pushing ally down
          // by running ally immediately in the next loop step? To ensure
          // After You sticks across sort, mark ally priority arbitrarily high.
          movePriority[allySlot] = 99;
        }
        continue;
      }

      if (move.id == 'wide_guard' || move.id == 'quick_guard') {
        consumePpOnce();
        final double successProb =
            1.0 / pow(2, actor.consecutiveProtectCount).toDouble();
        if (random.nextDouble() < successProb) {
          actor.consecutiveProtectCount++;
          final userSide = field.sideFor(isPlayerSlot(actorSlot));
          if (move.id == 'wide_guard') {
            userSide.wideGuardActiveThisTurn = true;
          } else {
            userSide.quickGuardActiveThisTurn = true;
          }
          events.add(DoubleBattleStepEvent(
            message:
                "${move.name} protected ${isPlayerSlot(actorSlot) ? 'your team' : 'the opposing team'}!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            vfxTargetSlots: _livingSlots(
              slots,
              isPlayerSlot(actorSlot) ? const [0, 1] : const [2, 3],
            ),
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: move.id == 'wide_guard' ? 'WIDE GUARD' : 'QUICK GUARD',
            statTargetIsSelf: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          actor.consecutiveProtectCount = 0;
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used ${move.name}, but it failed!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
        continue;
      }

      if (move.id == 'follow_me' || move.id == 'rage_powder') {
        consumePpOnce();
        final userSide = field.sideFor(isPlayerSlot(actorSlot));
        userSide.redirectSlotIndex = actorSlot;
        userSide.redirectIsPowder = move.id == 'rage_powder';
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} became the center of attention!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          vfxTargetSlots: [actorSlot],
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statusInflictedLabel: 'CENTER',
          statTargetIsSelf: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      if (move.id == 'ally_switch') {
        consumePpOnce();
        final swapTarget = slots[allySlot];
        if (swapTarget == null && _livingSlots(slots, isPlayerSlot(actorSlot) ? const [0, 1] : const [2, 3]).length <= 1) {
          // Fails if alone with only 1 Pokémon on field (empty slot allowed in Gen 5+, wait: in Gen 5 Ally Switch fails if partner is empty; works if 2 active mons!)
        }
        if (swapTarget == null || swapTarget.isFainted) {
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used Ally Switch, but it failed!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          slots[actorSlot] = swapTarget;
          slots[allySlot] = actor;
          // Remap remaining queued order + actedSlots referencing actorSlot <-> allySlot
          final bool allyHadActed = actedSlots.contains(allySlot);
          actedSlots.remove(actorSlot);
          actedSlots.add(allySlot);
          if (allyHadActed) {
            actedSlots.add(actorSlot);
          }
          for (int i = 0; i < remainingOrder.length; i++) {
            if (remainingOrder[i] == actorSlot) {
              remainingOrder[i] = allySlot;
            } else if (remainingOrder[i] == allySlot) {
              remainingOrder[i] = actorSlot;
            }
          }
          final savedPriority = movePriority[allySlot];
          if (savedPriority != null) {
            movePriority[actorSlot] = savedPriority;
          }
          final savedMove = resolvedMoves[allySlot];
          if (savedMove != null) {
            resolvedMoves[actorSlot] = savedMove;
          }
          final actSwap = slotActions[allySlot];
          slotActions[allySlot] = slotActions[actorSlot];
          slotActions[actorSlot] = actSwap;
          for (int s = 0; s < 4; s++) {
            final t = slotActions[s].targetSlot;
            if (t == actorSlot) {
              slotActions[s] = slotActions[s].copyWith(targetSlot: allySlot);
            } else if (t == allySlot) {
              slotActions[s] = slotActions[s].copyWith(targetSlot: actorSlot);
            }
          }
          events.add(DoubleBattleStepEvent(
            message:
                "${actor.nickname} and ${swapTarget.nickname} switched places!",
            actorSlot: actorSlot,
            targetSlot: allySlot,
            vfxTargetSlots: [actorSlot, allySlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            swapUserWithAlly: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
        continue;
      }

      if (move.id == 'aromatherapy') {
        consumePpOnce();
        final party = isPlayerSlot(actorSlot) ? playerParty : opponentParty;
        for (final m in party) {
          if (!m.isFainted && m.status != StatusCondition.none) {
            m.status = StatusCondition.none;
            m.isBadlyPoisoned = false;
            m.sleepTurnsRemaining = 0;
          }
        }
        events.add(DoubleBattleStepEvent(
          message: "A soothing aroma wafted through the area!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          vfxTargetSlots: _livingSlots(
              slots, isPlayerSlot(actorSlot) ? const [0, 1] : const [2, 3]),
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statusInflictedLabel: 'CURED!',
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      if (move.id == 'haze') {
        consumePpOnce();
        for (int s = 0; s < 4; s++) {
          final m = slots[s];
          if (m != null && !m.isFainted) {
            m
              ..atkStage = 0
              ..defStage = 0
              ..spaStage = 0
              ..spdStage = 0
              ..speStage = 0
              ..accStage = 0
              ..evaStage = 0;
          }
        }
        events.add(DoubleBattleStepEvent(
          message: "All stat changes were eliminated!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          vfxTargetSlots: [for (int s = 0; s < 4; s++) if (slots[s] != null && !slots[s]!.isFainted) s],
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statChangedLabel: 'RESET',
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      if (move.id == 'perish_song') {
        consumePpOnce();
        final affected = <int>[];
        for (int s = 0; s < 4; s++) {
          final m = slots[s];
          if (m == null || m.isFainted) continue;
          if (m.effectiveAbilityId == 'soundproof') {
            events.add(DoubleBattleStepEvent(
              message: "${m.nickname}'s Soundproof blocked Perish Song!",
              actorSlot: s,
              targetSlot: s,
              hideMoveVfx: true,
              abilityTriggeredName: 'Soundproof',
              slotHpSnapshots: snapshotHps(slots),
            ));
            continue;
          }
          if (m.perishTurnsRemaining == 0) {
            m.perishTurnsRemaining = 3;
          }
          affected.add(s);
        }
        events.add(DoubleBattleStepEvent(
          message: "All Pokémon that heard the song will faint in 3 turns!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          vfxTargetSlots: affected,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      if (move.id == 'heal_pulse') {
        consumePpOnce();
        final int tSlot = _resolveSingleTargetSlot(
          actorSlot: actorSlot,
          requestedTargetSlot: slotActions[actorSlot].targetSlot,
          move: move,
          slots: slots,
          field: field,
          random: random,
          events: events,
          allowAlly: true,
        );
        final target = (tSlot >= 0 && tSlot < 4) ? slots[tSlot] : null;
        if (target == null || target.isFainted) {
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used Heal Pulse, but there was no target!",
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            isMiss: true,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else if (target.currentHp >= target.maxHp) {
          events.add(DoubleBattleStepEvent(
            message: "${actor.nickname} used Heal Pulse, but ${target.nickname}'s HP is full!",
            actorSlot: actorSlot,
            targetSlot: tSlot,
            vfxTargetSlots: [tSlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            slotHpSnapshots: snapshotHps(slots),
          ));
        } else {
          final int heal = min(max(1, target.maxHp ~/ 2), target.maxHp - target.currentHp);
          target.currentHp += heal;
          events.add(DoubleBattleStepEvent(
            message: "${target.nickname}'s HP was restored! (+$heal HP)",
            actorSlot: actorSlot,
            targetSlot: tSlot,
            vfxTargetSlots: [tSlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            healAmount: heal,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
        continue;
      }

      if (move.id == 'acupressure') {
        consumePpOnce();
        final int tSlot = slotActions[actorSlot].targetSlot ?? actorSlot;
        final PokemonInstance? target =
            (tSlot == actorSlot || tSlot == allySlot) &&
                    slots[tSlot] != null &&
                    !slots[tSlot]!.isFainted
                ? slots[tSlot]
                : actor;
        if (target != null) {
          const stats = ['atk', 'def', 'spa', 'spd', 'spe', 'acc', 'eva'];
          final picked = stats[random.nextInt(stats.length)];
          target.modifyStatStage(picked, 2);
          events.add(DoubleBattleStepEvent(
            message: "${target.nickname}'s ${picked.toUpperCase()} sharply rose!",
            actorSlot: actorSlot,
            targetSlot: tSlot,
            vfxTargetSlots: [tSlot],
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statChangedLabel: '${picked.toUpperCase()} ▲▲',
            statTargetIsSelf: tSlot == actorSlot,
            slotHpSnapshots: snapshotHps(slots),
          ));
        }
        continue;
      }

      // Spread moves (allFoes or allOthers)
      if (targetKind == MoveTarget.allFoes || targetKind == MoveTarget.allOthers) {
        _executeSpreadMove(
          actor: actor,
          actorSlot: actorSlot,
          move: move,
          hitAllyAlso: targetKind == MoveTarget.allOthers,
          slots: slots,
          field: field,
          playerTrainer: playerTrainer,
          defenderIntended: foeIntended,
          random: random,
          events: events,
          consumePpOnce: consumePpOnce,
        );
        continue;
      }

      // Self / UserSide / FoeSide / EntireField -> target is actorSlot (or living foe for reference)
      if (targetKind == MoveTarget.self ||
          targetKind == MoveTarget.userSide ||
          targetKind == MoveTarget.foeSide ||
          targetKind == MoveTarget.entireField) {
        final livingFoes = _livingSlots(slots, foeSlots);
        final int foeRefSlot = livingFoes.isNotEmpty ? livingFoes.first : foeSlots.first;
        final PokemonInstance foeRef = slots[foeRefSlot] ?? actor;
        final evs = BattleEngine.executeSingleAttack(
          actor,
          move,
          foeRef,
          isPlayer: isPlayerSlot(actorSlot),
          defenderIsPlayer: isPlayerSlot(foeRefSlot),
          isWild: false,
          playerTrainer: playerTrainer,
          field: field,
          defenderIntendedMove: foeIntended,
          rng: random,
          isSubMove: true, // Pre-checks already ran above!
          consumePp: false,
          isDoubleBattleScreen: _isDoubleScreenActive(slots, isPlayerSlot(foeRefSlot)),
        );
        consumePpOnce();
        for (final ev in evs) {
          events.add(_adaptStepEvent(
            ev,
            actorSlot: actorSlot,
            targetSlot: actorSlot,
            vfxTargetSlots: [actorSlot],
            slots: slots,
          ));
        }
        continue;
      }

      // Single-target & random-foe moves (canon Quick Guard, redirection, faint retarget, Flame Burst)
      int? requested = slotActions[actorSlot].targetSlot;
      if (targetKind == MoveTarget.randomFoe) {
        final foes = _livingSlots(slots, foeSlots);
        requested = foes.isNotEmpty ? foes[random.nextInt(foes.length)] : -1;
      }

      final int targetSlot = _resolveSingleTargetSlot(
        actorSlot: actorSlot,
        requestedTargetSlot: requested,
        move: move,
        slots: slots,
        field: field,
        random: random,
        events: events,
      );

      if (targetSlot < 0 || slots[targetSlot] == null || slots[targetSlot]!.isFainted) {
        consumePpOnce();
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} used ${move.name}, but there was no target!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      final PokemonInstance defender = slots[targetSlot]!;
      final bool defIsPlayer = isPlayerSlot(targetSlot);
      final targetSide = field.sideFor(defIsPlayer);

      // Quick Guard blocks priority moves targeting opposing side unless Feint
      if (defIsPlayer != isPlayerSlot(actorSlot) &&
          move.priority > 0 &&
          move.id != 'feint' &&
          targetSide.quickGuardActiveThisTurn) {
        consumePpOnce();
        events.add(DoubleBattleStepEvent(
          message: "${defender.nickname} protected itself with Quick Guard!",
          actorSlot: actorSlot,
          targetSlot: targetSlot,
          vfxTargetSlots: [targetSlot],
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      // Telepathy immunity if targeting own ally with damaging move
      if (targetSlot == allySlot &&
          move.category != MoveCategory.status &&
          actor.effectiveAbilityId != 'mold_breaker' &&
          defender.effectiveAbilityId == 'telepathy') {
        consumePpOnce();
        events.add(DoubleBattleStepEvent(
          message: "${defender.nickname} avoids attacks with Telepathy!",
          actorSlot: actorSlot,
          targetSlot: targetSlot,
          hideMoveVfx: true,
          abilityTriggeredName: 'Telepathy',
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      // Canon Feint breaks Wide Guard & Quick Guard as well as Protect
      if (move.id == 'feint') {
        targetSide.wideGuardActiveThisTurn = false;
        targetSide.quickGuardActiveThisTurn = false;
      }

      final int preDefHp = defender.currentHp;
      final evs = BattleEngine.executeSingleAttack(
        actor,
        move,
        defender,
        isPlayer: isPlayerSlot(actorSlot),
        defenderIsPlayer: defIsPlayer,
        isWild: false,
        playerTrainer: playerTrainer,
        field: field,
        defenderIntendedMove: foeIntended,
        rng: random,
        isSubMove: true,
        consumePp: false,
        isDoubleBattleScreen: _isDoubleScreenActive(slots, defIsPlayer),
        allyHasFriendGuard: _isAllyFriendGuardActive(
          slots,
          targetSlot,
          bypassDefAbility: actor.effectiveAbilityId == 'mold_breaker',
        ),
      );
      consumePpOnce();

      for (final ev in evs) {
        events.add(_adaptStepEvent(
          ev,
          actorSlot: actorSlot,
          targetSlot: targetSlot,
          vfxTargetSlots: [targetSlot],
          slots: slots,
        ));
      }

      // Canon Flame Burst splashes 1/16 max HP onto the target's partner!
      if (move.id == 'flame_burst' && defender.currentHp < preDefHp) {
        final int splashSlot = allySlotOf(targetSlot);
        final PokemonInstance? splashMon = slots[splashSlot];
        if (splashMon != null &&
            !splashMon.isFainted &&
            splashMon.effectiveAbilityId != 'magic_guard') {
          final int splash = max(1, splashMon.maxHp ~/ 16);
          splashMon.currentHp = (splashMon.currentHp - splash).clamp(0, splashMon.maxHp);
          events.add(DoubleBattleStepEvent(
            message: "The bursting flame hit ${splashMon.nickname}!",
            actorSlot: actorSlot,
            targetSlot: splashSlot,
            damageDealt: splash,
            hideMoveVfx: true,
            isStatusTick: true,
            slotHpSnapshots: snapshotHps(slots),
            faintedSlots: livingFaintedSlots(slots),
          ));
          if (splashMon.isFainted) {
            events.add(DoubleBattleStepEvent(
              message: "${splashMon.nickname} fainted!",
              actorSlot: actorSlot,
              targetSlot: splashSlot,
              hideMoveVfx: true,
              slotHpSnapshots: snapshotHps(slots),
              faintedSlots: livingFaintedSlots(slots),
            ));
          }
        }
      }
    }

    return events;
  }

  static List<DoubleBattleStepEvent>? _checkPreMoveActionability({
    required PokemonInstance actor,
    required int actorSlot,
    required Move move,
    required List<PokemonInstance?> slots,
    required Random random,
  }) {
    final List<DoubleBattleStepEvent> events = [];
    final atkAb = actor.effectiveAbilityId;

    if (actor.needsRecharge) {
      actor.needsRecharge = false;
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} must recharge!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return events;
    }

    if (actor.flinchedThisTurn) {
      actor.flinchedThisTurn = false;
      BattleEngine.clearMoveLocks(actor);
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} flinched and couldn't move!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        isMiss: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return events;
    }

    if (actor.isTaunted && move.category == MoveCategory.status) {
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} can't use ${move.name} after the taunt!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        isMiss: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return events;
    }

    if (actor.disableTurnsRemaining > 0 && actor.disabledMoveId == move.id) {
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname}'s ${move.name} is disabled!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        isMiss: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return events;
    }

    if (actor.status == StatusCondition.sleep) {
      if (actor.sleepTurnsRemaining <= 0) {
        actor.sleepTurnsRemaining = 2 + random.nextInt(3);
      }
      final int step = atkAb == 'early_bird' ? 2 : 1;
      actor.sleepTurnsRemaining = max(0, actor.sleepTurnsRemaining - step);
      if (actor.sleepTurnsRemaining <= 0) {
        actor.status = StatusCondition.none;
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} woke up!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
      } else if (move.id != 'snore' && move.id != 'sleep_talk') {
        BattleEngine.clearMoveLocks(actor);
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} is fast asleep!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          isMiss: true,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        return events;
      }
    } else if (actor.status == StatusCondition.freeze) {
      if (move.type == PokemonType.fire || random.nextInt(5) == 0) {
        actor.status = StatusCondition.none;
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} thawed out!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
      } else {
        BattleEngine.clearMoveLocks(actor);
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} is frozen solid!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          isMiss: true,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        return events;
      }
    } else if (actor.status == StatusCondition.paralysis) {
      if (random.nextInt(4) == 0) {
        BattleEngine.clearMoveLocks(actor);
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} is paralyzed! It can't move!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          isMiss: true,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
        return events;
      }
    }

    if (actor.isConfused) {
      actor.confusionTurnsRemaining--;
      if (actor.confusionTurnsRemaining <= 0) {
        actor.isConfused = false;
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} snapped out of its confusion!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
      } else if (random.nextInt(2) == 0) {
        BattleEngine.clearMoveLocks(actor);
        final int hitSelfDmg = max(
          1,
          (((2 * actor.level / 5 + 2) * 40 * actor.effectiveAtk / max(1, actor.effectiveDef)) / 50 + 2).floor(),
        );
        actor.currentHp = (actor.currentHp - hitSelfDmg).clamp(0, actor.maxHp);
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} hurt itself in its confusion!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          damageDealt: hitSelfDmg,
          isSelfDamage: true,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
          faintedSlots: livingFaintedSlots(slots),
        ));
        return events;
      }
    }

    if (move.id == 'focus_punch' && actor.lastDamageTakenThisTurn > 0) {
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} lost its focus and couldn't move!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        isMiss: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return events;
    }

    if (actor.effectiveAbilityId != 'protect' &&
        move.id != 'protect' &&
        move.id != 'detect' &&
        move.id != 'endure' &&
        move.id != 'quick_guard' &&
        move.id != 'wide_guard') {
      actor.consecutiveProtectCount = 0;
    }

    return null;
  }

  static int _resolveSingleTargetSlot({
    required int actorSlot,
    required int? requestedTargetSlot,
    required Move move,
    required List<PokemonInstance?> slots,
    required BattleFieldState field,
    required Random random,
    required List<DoubleBattleStepEvent> events,
    bool allowAlly = false,
  }) {
    final bool actorIsPlayer = isPlayerSlot(actorSlot);
    final actor = slots[actorSlot]!;
    final List<int> foeSlots = opposingSlotsOf(actorSlot);
    final List<int> livingFoes = _livingSlots(slots, foeSlots);
    final foeSide = field.sideFor(!actorIsPlayer);
    final bool bypassDefAb = actor.effectiveAbilityId == 'mold_breaker';

    int targetSlot = requestedTargetSlot ?? (livingFoes.isNotEmpty ? livingFoes.first : -1);

    // If targeting ally (e.g., Heal Pulse or attacking partner) and ally fainted -> fail (no foe retarget)
    if (targetSlot == allySlotOf(actorSlot)) {
      final ally = slots[targetSlot];
      if (ally == null || ally.isFainted) {
        return allowAlly ? -1 : -1;
      }
    } else if (targetSlot != actorSlot) {
      // Targeting an opposing slot -> apply canon redirection!
      final bool targetingFoes = isPlayerSlot(targetSlot) != actorIsPlayer;
      if (targetingFoes) {
        // 1. Follow Me / Rage Powder on opposing side
        final int? redir = foeSide.redirectSlotIndex;
        if (redir != null &&
            slots[redir] != null &&
            !slots[redir]!.isFainted) {
          final bool ignoredPowder = foeSide.redirectIsPowder &&
              (actor.effectiveTypes.contains(PokemonType.grass) ||
                  actor.effectiveAbilityId == 'overcoat');
          if (!ignoredPowder) {
            targetSlot = redir;
          }
        }

        // 2. Lightning Rod / Storm Drain redirection across OTHER active slots
        if (!bypassDefAb && move.id != 'hidden_power') {
          final String? redirectAb = move.type == PokemonType.electric
              ? 'lightning_rod'
              : (move.type == PokemonType.water ? 'storm_drain' : null);
          if (redirectAb != null && targetSlot != actorSlot) {
            for (final candidate in const [0, 1, 2, 3]) {
              if (candidate == actorSlot || candidate == targetSlot) continue;
              final mon = slots[candidate];
              if (mon != null &&
                  !mon.isFainted &&
                  mon.effectiveAbilityId == redirectAb) {
                targetSlot = candidate;
                break;
              }
            }
          }
        }

        // 3. Faint retargeting: if chosen foe fainted, auto-retarget surviving foe
        if (targetSlot < 0 ||
            targetSlot >= 4 ||
            slots[targetSlot] == null ||
            slots[targetSlot]!.isFainted) {
          targetSlot = livingFoes.isNotEmpty ? livingFoes.first : -1;
        }
      }
    }

    return targetSlot;
  }

  static void _executeSpreadMove({
    required PokemonInstance actor,
    required int actorSlot,
    required Move move,
    required bool hitAllyAlso,
    required List<PokemonInstance?> slots,
    required BattleFieldState field,
    required Trainer? playerTrainer,
    required Move? defenderIntended,
    required Random random,
    required List<DoubleBattleStepEvent> events,
    required void Function() consumePpOnce,
  }) {
    final bool actorIsPlayer = isPlayerSlot(actorSlot);
    final String atkAb = actor.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';
    final bool isSelfKoMove = move.id == 'explosion' || move.id == 'self_destruct';

    consumePpOnce();

    // Canon Damp checks ALL active Pokémon on the field before Explosion / Self-Destruct
    if (isSelfKoMove) {
      for (int s = 0; s < 4; s++) {
        final mon = slots[s];
        if (mon != null &&
            !mon.isFainted &&
            mon.effectiveAbilityId == 'damp' &&
            (s == actorSlot || !bypassDefAb)) {
          events.add(DoubleBattleStepEvent(
            message: "Damp prevented ${actor.nickname} from using ${move.name}!",
            actorSlot: actorSlot,
            targetSlot: s,
            hideMoveVfx: true,
            abilityTriggeredName: 'Damp',
            slotHpSnapshots: snapshotHps(slots),
          ));
          return;
        }
      }
    }

    // Build target order: foes first, then ally if `allOthers`
    final foeSlots = _livingSlots(slots, opposingSlotsOf(actorSlot));
    final allySlot = allySlotOf(actorSlot);
    final candidateTargets = <int>[
      ...foeSlots,
      if (hitAllyAlso && slots[allySlot] != null && !slots[allySlot]!.isFainted)
        allySlot,
    ];

    if (candidateTargets.isEmpty) {
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} used ${move.name}, but there was no target!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
      ));
      return;
    }

    // Canon spread multiplier: 0.75x when 2+ valid targets exist, 1.0x against 1 remaining target
    final double spreadMult = candidateTargets.length >= 2 ? 0.75 : 1.0;
    final bool sheerForceBlocks =
        atkAb == 'sheer_force' && BattleEngine.hasSheerForceBoost(move);

    bool anyDamageDealt = false;
    bool firstVisualTargetEmitted = false;
    final List<int> allVfxSlots = List<int>.from(candidateTargets);

    for (final tSlot in candidateTargets) {
      final defender = slots[tSlot];
      if (defender == null || defender.isFainted) continue;
      final bool defIsPlayer = isPlayerSlot(tSlot);
      final defSide = field.sideFor(defIsPlayer);

      // Telepathy protects ally from ally's damaging spread moves!
      if (tSlot == allySlot &&
          move.category != MoveCategory.status &&
          !bypassDefAb &&
          defender.effectiveAbilityId == 'telepathy') {
        events.add(DoubleBattleStepEvent(
          message: "${defender.nickname} avoids attacks with Telepathy!",
          actorSlot: actorSlot,
          targetSlot: tSlot,
          hideMoveVfx: true,
          abilityTriggeredName: 'Telepathy',
          slotHpSnapshots: snapshotHps(slots),
        ));
        continue;
      }

      // Wide Guard blocks spread moves targeting foes (not user's own partner if foe used Wide Guard)
      if (defSide.wideGuardActiveThisTurn &&
          defIsPlayer != actorIsPlayer &&
          move.id != 'feint') {
        events.add(DoubleBattleStepEvent(
          message: "${defender.nickname} is protected by Wide Guard!",
          actorSlot: actorSlot,
          targetSlot: tSlot,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: firstVisualTargetEmitted,
          vfxTargetSlots: firstVisualTargetEmitted ? const [] : allVfxSlots,
          slotHpSnapshots: snapshotHps(slots),
        ));
        firstVisualTargetEmitted = true;
        continue;
      }

      final int preHp = defender.currentHp;
      final evs = BattleEngine.executeSingleAttack(
        actor,
        move,
        defender,
        isPlayer: actorIsPlayer,
        defenderIsPlayer: defIsPlayer,
        isWild: false,
        playerTrainer: playerTrainer,
        field: field,
        defenderIntendedMove: defenderIntended,
        rng: random,
        isSubMove: true,
        consumePp: false,
        spreadDamageMultiplier: spreadMult,
        isDoubleBattleScreen: _isDoubleScreenActive(slots, defIsPlayer),
        allyHasFriendGuard: _isAllyFriendGuardActive(
          slots,
          tSlot,
          bypassDefAbility: bypassDefAb,
        ),
        skipLifeOrbRecoil: true,
        clearHelpingHandAfter: false,
        deferSelfKo: true,
      );

      if (defender.currentHp < preHp) {
        anyDamageDealt = true;
      }

      for (final ev in evs) {
        final bool showVfxHere = !firstVisualTargetEmitted && !ev.hideMoveVfx;
        events.add(_adaptStepEvent(
          ev,
          actorSlot: actorSlot,
          targetSlot: tSlot,
          vfxTargetSlots: showVfxHere ? allVfxSlots : const [],
          slots: slots,
          forceHideVfx: firstVisualTargetEmitted,
        ));
        if (showVfxHere) {
          firstVisualTargetEmitted = true;
        }
      }
    }

    actor.helpingHandBoosted = false;

    // Self-KO moves (Explosion / Self-Destruct) faint the user once after all targets resolve
    if (isSelfKoMove && !actor.isFainted) {
      final int cost = actor.currentHp;
      actor.currentHp = 0;
      BattleEngine.clearMoveLocks(actor);
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} fainted from ${move.name}!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        damageDealt: cost,
        isSelfDamage: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
        faintedSlots: livingFaintedSlots(slots),
      ));
    }

    // Life Orb recoil applies ONCE per spread move use if any target took damage
    if (anyDamageDealt &&
        !actor.isFainted &&
        actor.heldItemId == 'life_orb' &&
        atkAb != 'magic_guard' &&
        !sheerForceBlocks) {
      final int orbRecoil = max(1, actor.maxHp ~/ 10);
      actor.currentHp = (actor.currentHp - orbRecoil).clamp(0, actor.maxHp);
      events.add(DoubleBattleStepEvent(
        message: "${actor.nickname} lost some of its HP from Life Orb!",
        actorSlot: actorSlot,
        targetSlot: actorSlot,
        damageDealt: orbRecoil,
        isSelfDamage: true,
        hideMoveVfx: true,
        slotHpSnapshots: snapshotHps(slots),
        faintedSlots: livingFaintedSlots(slots),
      ));
      if (actor.isFainted) {
        events.add(DoubleBattleStepEvent(
          message: "${actor.nickname} fainted!",
          actorSlot: actorSlot,
          targetSlot: actorSlot,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
          faintedSlots: livingFaintedSlots(slots),
        ));
      }
    }
  }

  /// End-of-turn weather, status, Leftovers, Leech Seed, Speed Boost, Perish Song,
  /// and side screen/Tailwind countdown across all active slots.
  static List<DoubleBattleStepEvent> processDoubleEndOfTurn({
    required List<PokemonInstance?> slots,
    required BattleFieldState field,
    Trainer? playerTrainer,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final List<DoubleBattleStepEvent> events = [];
    final weather =
        field.effectiveWeatherMulti([for (final m in slots) if (m != null) m]);

    // 1. Weather countdown & weather damage per slot
    if (field.weather != BattleWeather.none && field.weatherTurnsRemaining > 0) {
      field.weatherTurnsRemaining--;
      if (field.weatherTurnsRemaining == 0) {
        final String endedMsg = switch (field.weather) {
          BattleWeather.sun => 'The sunlight faded.',
          BattleWeather.rain => 'The rain stopped.',
          BattleWeather.sandstorm => 'The sandstorm subsided.',
          BattleWeather.hail => 'The hail stopped.',
          BattleWeather.none => '',
        };
        field.weather = BattleWeather.none;
        events.add(DoubleBattleStepEvent(
          message: endedMsg,
          actorSlot: 0,
          targetSlot: 0,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
      }
    }

    if (weather == BattleWeather.sandstorm || weather == BattleWeather.hail) {
      for (int s = 0; s < 4; s++) {
        final mon = slots[s];
        if (mon == null || mon.isFainted) continue;
        final ab = mon.effectiveAbilityId;
        if (ab == 'magic_guard' || ab == 'overcoat') continue;
        final types = BattleEngine.defensiveTypesOf(mon);
        final immune = weather == BattleWeather.sandstorm
            ? (types.contains(PokemonType.rock) ||
                types.contains(PokemonType.ground) ||
                types.contains(PokemonType.steel) ||
                ab == 'sand_veil' ||
                ab == 'sand_rush' ||
                ab == 'sand_force')
            : (types.contains(PokemonType.ice) || ab == 'snow_cloak');
        if (!immune) {
          final int dmg = max(1, mon.maxHp ~/ 16);
          mon.currentHp = (mon.currentHp - dmg).clamp(0, mon.maxHp);
          events.add(DoubleBattleStepEvent(
            message: weather == BattleWeather.sandstorm
                ? "${mon.nickname} is buffeted by the sandstorm!"
                : "${mon.nickname} is pelted by hail!",
            actorSlot: s,
            targetSlot: s,
            damageDealt: dmg,
            isStatusTick: true,
            isSelfDamage: true,
            hideMoveVfx: true,
            slotHpSnapshots: snapshotHps(slots),
            faintedSlots: livingFaintedSlots(slots),
          ));
          if (mon.isFainted) {
            events.add(DoubleBattleStepEvent(
              message: "${mon.nickname} fainted!",
              actorSlot: s,
              targetSlot: s,
              hideMoveVfx: true,
              slotHpSnapshots: snapshotHps(slots),
              faintedSlots: livingFaintedSlots(slots),
            ));
          }
        }
      }
    }

    // 2. Per-slot residual effects (status, Leftovers, Speed Boost, Perish Song, etc.)
    for (int s = 0; s < 4; s++) {
      final mon = slots[s];
      if (mon == null || mon.isFainted) continue;
      mon.turnsActiveInBattle++;
      final foes = _livingSlots(slots, opposingSlotsOf(s));
      final foe = foes.isNotEmpty ? slots[foes.first] : null;
      final isPlayer = isPlayerSlot(s);

      // Re-use BattleEngine end-of-turn status (passing neutral field so weather tick doesn't repeat 4x)
      final statusEvents = BattleEngine.processEndOfTurnStatus(
        mon,
        opponent: foe,
        isPlayer: isPlayer,
        isWild: false,
        field: BattleFieldState(), // weather handled globally above
      );
      for (final ev in statusEvents) {
        events.add(_adaptStepEvent(
          ev,
          actorSlot: s,
          targetSlot: s,
          slots: slots,
          forceHideVfx: true,
        ));
      }
    }

    // 3. Tick screens / Tailwind / Gravity / Wonder Room / Uproar
    field.playerSide.tickTurn();
    field.opponentSide.tickTurn();
    if (field.gravityTurns > 0) field.gravityTurns--;
    if (field.uproarTurns > 0) field.uproarTurns--;
    if (field.wonderRoomTurns > 0) {
      field.wonderRoomTurns--;
      if (field.wonderRoomTurns == 0) {
        events.add(DoubleBattleStepEvent(
          message: "Wonder Room wore off, and Defense and Sp. Def returned to normal!",
          actorSlot: 0,
          targetSlot: 0,
          hideMoveVfx: true,
          slotHpSnapshots: snapshotHps(slots),
        ));
      }
    }

    return events;
  }

  /// Smart Doubles AI choosing both opponent slots' moves & targets, favoring
  /// effective matchups, safe spread attacks, and occasional support moves.
  static List<DoubleBattleSlotAction> chooseOpponentDoubleActions({
    required List<PokemonInstance?> slots,
    required BattleFieldState field,
    Random? rng,
  }) {
    final random = rng ?? _rng;
    final actions = <DoubleBattleSlotAction>[];

    for (final s in const [2, 3]) {
      final actor = slots[s];
      if (actor == null || actor.isFainted) {
        actions.add(DoubleBattleSlotAction.pass());
        continue;
      }

      if (actor.hasForcedTurnAction) {
        final forced = actor.activeMoves.firstWhere(
          (m) => m.id == actor.forcedMoveId,
          orElse: () => PokedexDatabase.moves['struggle']!.copy(),
        );
        final foes = _livingSlots(slots, const [0, 1]);
        actions.add(DoubleBattleSlotAction.fight(
          forced,
          targetSlot: foes.isNotEmpty ? foes[random.nextInt(foes.length)] : 0,
        ));
        continue;
      }

      final usableMoves = actor.activeMoves.where((m) {
        if (m.currentPp <= 0) return false;
        if (actor.disableTurnsRemaining > 0 && actor.disabledMoveId == m.id) {
          return false;
        }
        if (actor.isTaunted && m.category == MoveCategory.status) return false;
        return true;
      }).toList();

      if (usableMoves.isEmpty) {
        final foes = _livingSlots(slots, const [0, 1]);
        actions.add(DoubleBattleSlotAction.fight(
          PokedexDatabase.moves['struggle']!.copy(),
          targetSlot: foes.isNotEmpty ? foes.first : 0,
        ));
        continue;
      }

      final livingFoes = _livingSlots(slots, const [0, 1]);
      final allySlot = allySlotOf(s);
      final PokemonInstance? ally =
          slots[allySlot] != null && !slots[allySlot]!.isFainted
              ? slots[allySlot]
              : null;

      double bestScore = -9999.0;
      Move bestMove = usableMoves.first;
      int? bestTarget = livingFoes.isNotEmpty ? livingFoes.first : null;

      for (final m in usableMoves) {
        final tKind = classifyMoveTarget(m, user: actor);
        if (tKind == MoveTarget.allFoes || tKind == MoveTarget.allOthers) {
          double score = 0;
          for (final fs in livingFoes) {
            final foe = slots[fs]!;
            final mult = PokemonTypeExtension.getEffectiveness(
                m.type, BattleEngine.defensiveTypesOf(foe));
            final stab = actor.effectiveTypes.contains(m.type) ? 1.5 : 1.0;
            score += (m.power * 0.75 * mult * stab);
          }
          if (tKind == MoveTarget.allOthers && ally != null) {
            final allyImmune =
                ally.effectiveAbilityId == 'telepathy' ||
                (m.type == PokemonType.ground &&
                    !BattleEngine.isGroundedForBattle(ally, field)) ||
                (m.type == PokemonType.water &&
                    (ally.effectiveAbilityId == 'water_absorb' ||
                        ally.effectiveAbilityId == 'dry_skin' ||
                        ally.effectiveAbilityId == 'storm_drain')) ||
                (m.type == PokemonType.electric &&
                    (ally.effectiveAbilityId == 'volt_absorb' ||
                        ally.effectiveAbilityId == 'lightning_rod'));
            if (!allyImmune) {
              final allyMult = PokemonTypeExtension.getEffectiveness(
                  m.type, BattleEngine.defensiveTypesOf(ally));
              // Penalize nuking non-immune ally heavily unless huge gain vs 2 foes
              score -= m.power * 0.9 * allyMult;
            } else {
              score += 18.0; // Bonus for EQ/Surf + immune partner!
            }
          }
          score += random.nextDouble() * 14.0;
          if (score > bestScore) {
            bestScore = score;
            bestMove = m;
            bestTarget = livingFoes.isNotEmpty ? livingFoes.first : null;
          }
        } else if (tKind == MoveTarget.allyOnly && ally != null) {
          final double score = 70.0 + random.nextDouble() * 25.0;
          if (score > bestScore) {
            bestScore = score;
            bestMove = m;
            bestTarget = allySlot;
          }
        } else if (tKind == MoveTarget.self ||
            tKind == MoveTarget.userSide ||
            tKind == MoveTarget.foeSide ||
            tKind == MoveTarget.entireField) {
          double score = 55.0;
          if (m.id == 'protect' || m.id == 'detect' || m.id == 'wide_guard') {
            score = actor.consecutiveProtectCount == 0 ? 35.0 : -100.0;
          }
          score += random.nextDouble() * 25.0;
          if (score > bestScore) {
            bestScore = score;
            bestMove = m;
            bestTarget = s;
          }
        } else {
          // Single-target move: score against each living foe
          for (final fs in livingFoes) {
            final foe = slots[fs]!;
            double score;
            if (m.category == MoveCategory.status) {
              score = 45.0 + random.nextDouble() * 20.0;
            } else {
              final mult = PokemonTypeExtension.getEffectiveness(
                  m.type, BattleEngine.defensiveTypesOf(foe));
              final stab = actor.effectiveTypes.contains(m.type) ? 1.5 : 1.0;
              score = m.power * mult * stab + random.nextDouble() * 18.0;
            }
            if (score > bestScore) {
              bestScore = score;
              bestMove = m;
              bestTarget = fs;
            }
          }
        }
      }

      actions.add(DoubleBattleSlotAction.fight(bestMove, targetSlot: bestTarget));
    }

    return actions;
  }
}
