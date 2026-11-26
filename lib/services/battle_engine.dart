import 'dart:math';
import '../models/ability.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import 'pokedex_database.dart';

enum BattleActionType {
  fight,
  switchPokemon,
  useItem,
  run,
}

enum BattleWeather {
  none,
  sun,
  rain,
  sandstorm,
  hail,
}

class BattleSideState {
  int reflectTurns = 0;
  int lightScreenTurns = 0;
  int safeguardTurns = 0;
  int mistTurns = 0;
  int tailwindTurns = 0;
  int luckyChantTurns = 0;
  int spikesLayers = 0; // 0..3
  int toxicSpikesLayers = 0; // 0..2
  bool hasStealthRock = false;
  bool hasHealingWishPending = false;
  bool allyFaintedLastTurn = false;
  int futureSightTurns = 0; // Set to 3 on use -> ticks end of T1 (2), T2 (1), T3 (0 & strikes!)
  PokemonInstance? futureSightAttacker;
  bool futureSightFromPlayer = false;
  Move? futureSightMove;
  bool wideGuardActiveThisTurn = false;
  bool quickGuardActiveThisTurn = false;
  int? redirectSlotIndex;
  bool redirectIsPowder = false;

  void clearTurnGuards() {
    wideGuardActiveThisTurn = false;
    quickGuardActiveThisTurn = false;
    redirectSlotIndex = null;
    redirectIsPowder = false;
  }

  void clearFutureSight() {
    futureSightTurns = 0;
    futureSightAttacker = null;
    futureSightFromPlayer = false;
    futureSightMove = null;
  }

  void clearHazards() {
    spikesLayers = 0;
    toxicSpikesLayers = 0;
    hasStealthRock = false;
  }

  void clearScreens() {
    reflectTurns = 0;
    lightScreenTurns = 0;
  }

  void tickTurn() {
    if (reflectTurns > 0) reflectTurns--;
    if (lightScreenTurns > 0) lightScreenTurns--;
    if (safeguardTurns > 0) safeguardTurns--;
    if (mistTurns > 0) mistTurns--;
    if (tailwindTurns > 0) tailwindTurns--;
    if (luckyChantTurns > 0) luckyChantTurns--;
  }
}

class BattleFieldState {
  BattleWeather weather = BattleWeather.none;
  int weatherTurnsRemaining = 0; // -1 = permanent (Drought/Drizzle Gen V)
  int gravityTurns = 0;
  int wonderRoomTurns = 0;
  int uproarTurns = 0;
  bool mudSportActive = false;
  bool waterSportActive = false;
  final BattleSideState playerSide = BattleSideState();
  final BattleSideState opponentSide = BattleSideState();

  BattleSideState sideFor(bool isPlayer) => isPlayer ? playerSide : opponentSide;

  BattleWeather effectiveWeather(PokemonInstance a, PokemonInstance? b) {
    if (a.effectiveAbilityId == 'cloud_nine' ||
        (b != null && b.effectiveAbilityId == 'cloud_nine')) {
      return BattleWeather.none;
    }
    return weather;
  }

  BattleWeather effectiveWeatherMulti(Iterable<PokemonInstance> activeMons) {
    for (final mon in activeMons) {
      if (!mon.isFainted && mon.effectiveAbilityId == 'cloud_nine') {
        return BattleWeather.none;
      }
    }
    return weather;
  }

  void resetAll() {
    weather = BattleWeather.none;
    weatherTurnsRemaining = 0;
    gravityTurns = 0;
    wonderRoomTurns = 0;
    uproarTurns = 0;
    mudSportActive = false;
    waterSportActive = false;
    playerSide
      ..reflectTurns = 0
      ..lightScreenTurns = 0
      ..safeguardTurns = 0
      ..mistTurns = 0
      ..tailwindTurns = 0
      ..luckyChantTurns = 0
      ..hasHealingWishPending = false
      ..allyFaintedLastTurn = false
      ..clearTurnGuards()
      ..clearFutureSight()
      ..clearHazards();
    opponentSide
      ..reflectTurns = 0
      ..lightScreenTurns = 0
      ..safeguardTurns = 0
      ..mistTurns = 0
      ..tailwindTurns = 0
      ..luckyChantTurns = 0
      ..hasHealingWishPending = false
      ..allyFaintedLastTurn = false
      ..clearTurnGuards()
      ..clearFutureSight()
      ..clearHazards();
  }
}

class BattleAction {
  final BattleActionType type;
  final Move? move;
  final PokemonInstance? switchTarget;
  final String? itemId;

  BattleAction.fight(this.move)
      : type = BattleActionType.fight,
        switchTarget = null,
        itemId = null;

  BattleAction.switchPokemon(this.switchTarget)
      : type = BattleActionType.switchPokemon,
        move = null,
        itemId = null;

  BattleAction.useItem(this.itemId)
      : type = BattleActionType.useItem,
        move = null,
        switchTarget = null;

  BattleAction.run()
      : type = BattleActionType.run,
        move = null,
        switchTarget = null,
        itemId = null;
}

class BattleStepEvent {
  final String message;
  final bool isPlayerActor;
  final String? moveId;
  final PokemonType? moveType;
  final MoveCategory? moveCategory;
  final int damageDealt;
  final int targetHpAfter;
  final bool isCrit;
  final double effectiveness;
  final String? statChangedLabel;
  final bool statTargetIsSelf;
  final String? statusInflictedLabel;
  final bool targetFainted;
  final bool isMiss;
  final bool isStatusTick;
  final int hitNumber;
  final int totalHits;
  final bool isChargeTurn;
  final bool submergeActorAfter;
  final bool surfaceActorOnAttack;
  final bool isMultiHitSummary;
  final bool hideMoveVfx;
  final bool isSelfDamage;
  final int healAmount;
  final String? abilityTriggeredName;
  final bool requestBatonPassSwitch;

  const BattleStepEvent({
    required this.message,
    required this.isPlayerActor,
    this.moveId,
    this.moveType,
    this.moveCategory,
    this.damageDealt = 0,
    this.targetHpAfter = 0,
    this.isCrit = false,
    this.effectiveness = 1.0,
    this.statChangedLabel,
    this.statTargetIsSelf = false,
    this.statusInflictedLabel,
    this.targetFainted = false,
    this.isMiss = false,
    this.isStatusTick = false,
    this.hitNumber = 0,
    this.totalHits = 0,
    this.isChargeTurn = false,
    this.submergeActorAfter = false,
    this.surfaceActorOnAttack = false,
    this.isMultiHitSummary = false,
    this.hideMoveVfx = false,
    this.isSelfDamage = false,
    this.healAmount = 0,
    this.abilityTriggeredName,
    this.requestBatonPassSwitch = false,
  });
}

class BattleEngine {
  static final Random _rng = Random();

  // ─── MOVE METADATA TABLES ───────────────────────────────────────────────────
  static const Set<String> _soundMoves = {
    'growl', 'roar', 'sing', 'supersonic', 'screech', 'snore', 'uproar',
    'metal_sound', 'hyper_voice', 'bug_buzz', 'round', 'perish_song',
  };

  static const Set<String> _powderMoves = {
    'poison_powder', 'sleep_powder', 'stun_spore', 'spore', 'rage_powder',
  };

  static const Set<String> _punchMoves = {
    'comet_punch', 'mega_punch', 'fire_punch', 'ice_punch', 'thunder_punch',
    'dizzy_punch', 'mach_punch', 'dynamic_punch', 'focus_punch', 'sky_uppercut',
    'meteor_mash', 'shadow_punch', 'bullet_punch', 'hammer_arm', 'drain_punch',
  };

  static const Map<String, double> _recoilFraction = {
    'take_down': 0.25,
    'submission': 0.25,
    'double_edge': 0.33,
    'flare_blitz': 0.33,
    'brave_bird': 0.33,
    'wood_hammer': 0.33,
    'volt_tackle': 0.33,
    'wild_charge': 0.25,
    'head_smash': 0.50,
  };

  static const Set<String> _drainMoves = {
    'absorb', 'mega_drain', 'giga_drain', 'dream_eater', 'leech_life', 'drain_punch',
  };

  static const Set<String> _highCritMoves = {
    'karate_chop', 'razor_leaf', 'slash', 'crabhammer', 'cross_chop',
    'air_cutter', 'blaze_kick', 'leaf_blade', 'night_slash', 'shadow_claw',
    'psycho_cut', 'cross_poison', 'stone_edge', 'drill_run',
    'razor_wind', 'sky_attack',
  };

  static const Set<String> _ohkoMoves = {
    'guillotine', 'horn_drill', 'fissure', 'sheer_cold',
  };

  static const Set<String> _nonContactMoves = {
    'earthquake', 'rock_throw', 'rock_slide', 'stone_edge', 'rock_blast',
    'rock_tomb', 'razor_leaf', 'seed_bomb', 'bullet_seed', 'pin_missile',
    'spike_cannon', 'barrage', 'bone_club', 'bonemerang', 'bone_rush',
    'egg_bomb', 'icicle_spear', 'icicle_crash', 'poison_sting', 'gunk_shot',
    'smack_down', 'self_destruct', 'explosion', 'pay_day', 'fling',
    'natural_gift', 'fissure', 'bulldoze', 'sand_tomb', 'razor_wind',
    'psycho_cut', 'secret_power', 'present', 'rock_wreck',
  };

  static bool _isContactMove(Move move) =>
      move.category == MoveCategory.physical && !_nonContactMoves.contains(move.id);

  static const Map<String, int> _flinchChances = {
    'bite': 30, 'crunch': 0, 'headbutt': 30, 'stomp': 30, 'rolling_kick': 30,
    'bone_club': 10, 'hyper_fang': 10, 'rock_slide': 30, 'twister': 20,
    'fake_out': 100, 'astonish': 30, 'extrasensory': 10, 'air_slash': 30,
    'dark_pulse': 20, 'dragon_rush': 20, 'thunder_fang': 10, 'ice_fang': 10,
    'fire_fang': 10, 'waterfall': 20, 'zen_headbutt': 20, 'iron_head': 30,
    'heart_stamp': 30, 'steamroller': 30, 'icicle_crash': 30, 'sky_attack': 30,
    'snore': 30,
  };

  /// Multi-stat moves: list of `(stat, delta, appliesToSelf)`
  static const Map<String, List<({String stat, int delta, bool self})>> _multiStatMoves = {
    'growth': [(stat: 'atk', delta: 1, self: true), (stat: 'spa', delta: 1, self: true)],
    'work_up': [(stat: 'atk', delta: 1, self: true), (stat: 'spa', delta: 1, self: true)],
    'bulk_up': [(stat: 'atk', delta: 1, self: true), (stat: 'def', delta: 1, self: true)],
    'calm_mind': [(stat: 'spa', delta: 1, self: true), (stat: 'spd', delta: 1, self: true)],
    'dragon_dance': [(stat: 'atk', delta: 1, self: true), (stat: 'spe', delta: 1, self: true)],
    'cosmic_power': [(stat: 'def', delta: 1, self: true), (stat: 'spd', delta: 1, self: true)],
    'coil': [
      (stat: 'atk', delta: 1, self: true),
      (stat: 'def', delta: 1, self: true),
      (stat: 'acc', delta: 1, self: true),
    ],
    'quiver_dance': [
      (stat: 'spa', delta: 1, self: true),
      (stat: 'spd', delta: 1, self: true),
      (stat: 'spe', delta: 1, self: true),
    ],
    'shell_smash': [
      (stat: 'def', delta: -1, self: true),
      (stat: 'spd', delta: -1, self: true),
      (stat: 'atk', delta: 2, self: true),
      (stat: 'spa', delta: 2, self: true),
      (stat: 'spe', delta: 2, self: true),
    ],
    'stockpile': [(stat: 'def', delta: 1, self: true), (stat: 'spd', delta: 1, self: true)],
    'tickle': [(stat: 'atk', delta: -1, self: false), (stat: 'def', delta: -1, self: false)],
    'memento': [(stat: 'atk', delta: -2, self: false), (stat: 'spa', delta: -2, self: false)],
    'superpower': [(stat: 'atk', delta: -1, self: true), (stat: 'def', delta: -1, self: true)],
    'close_combat': [(stat: 'def', delta: -1, self: true), (stat: 'spd', delta: -1, self: true)],
  };

  /// Secondary stat effects on damaging moves: `(chance, stat, delta, appliesToSelf)`
  static const Map<String, ({int chance, String stat, int delta, bool self})>
      _damagingStatEffects = {
    'acid': (chance: 10, stat: 'spd', delta: -1, self: false),
    'acid_spray': (chance: 100, stat: 'spd', delta: -2, self: false),
    'aurora_beam': (chance: 10, stat: 'atk', delta: -1, self: false),
    'bubble': (chance: 10, stat: 'spe', delta: -1, self: false),
    'bubble_beam': (chance: 10, stat: 'spe', delta: -1, self: false),
    'bug_buzz': (chance: 10, stat: 'spd', delta: -1, self: false),
    'bulldoze': (chance: 100, stat: 'spe', delta: -1, self: false),
    'charge_beam': (chance: 70, stat: 'spa', delta: 1, self: true),
    'constrict': (chance: 10, stat: 'spe', delta: -1, self: false),
    'crunch': (chance: 20, stat: 'def', delta: -1, self: false),
    'crush_claw': (chance: 50, stat: 'def', delta: -1, self: false),
    'earth_power': (chance: 10, stat: 'spd', delta: -1, self: false),
    'energy_ball': (chance: 10, stat: 'spd', delta: -1, self: false),
    'flame_charge': (chance: 100, stat: 'spe', delta: 1, self: true),
    'flash_cannon': (chance: 10, stat: 'spd', delta: -1, self: false),
    'hammer_arm': (chance: 100, stat: 'spe', delta: -1, self: true),
    'icy_wind': (chance: 100, stat: 'spe', delta: -1, self: false),
    'iron_tail': (chance: 30, stat: 'def', delta: -1, self: false),
    'leaf_storm': (chance: 100, stat: 'spa', delta: -2, self: true),
    'leaf_tornado': (chance: 50, stat: 'acc', delta: -1, self: false),
    'low_sweep': (chance: 100, stat: 'spe', delta: -1, self: false),
    'metal_claw': (chance: 10, stat: 'atk', delta: 1, self: true),
    'meteor_mash': (chance: 20, stat: 'atk', delta: 1, self: true),
    'mirror_shot': (chance: 30, stat: 'acc', delta: -1, self: false),
    'moonblast': (chance: 30, stat: 'spa', delta: -1, self: false),
    'mud_bomb': (chance: 30, stat: 'acc', delta: -1, self: false),
    'mud_shot': (chance: 100, stat: 'spe', delta: -1, self: false),
    'mud_slap': (chance: 100, stat: 'acc', delta: -1, self: false),
    'muddy_water': (chance: 30, stat: 'acc', delta: -1, self: false),
    'psychic': (chance: 10, stat: 'spd', delta: -1, self: false),
    'rapid_spin': (chance: 100, stat: 'spe', delta: 1, self: true),
    'razor_shell': (chance: 50, stat: 'def', delta: -1, self: false),
    'rock_tomb': (chance: 100, stat: 'spe', delta: -1, self: false),
    'shadow_ball': (chance: 20, stat: 'spd', delta: -1, self: false),
  };

  static String _labelFor(PokemonInstance mon, bool isPlayer, bool isWild) {
    return isPlayer ? mon.nickname : (isWild ? "Wild ${mon.nickname}" : mon.nickname);
  }

  static bool isPowderMove(String moveId) => _powderMoves.contains(moveId);
  static bool isSoundMove(String moveId) => _soundMoves.contains(moveId);
  static bool hasSheerForceBoost(Move move) => _hasSheerForceBoost(move);
  static void clearMoveLocks(PokemonInstance mon) => _clearMoveLocks(mon);
  static bool isGroundedForBattle(PokemonInstance mon, BattleFieldState? field, {bool bypassAbility = false}) =>
      _isGrounded(mon, field, bypassAbility: bypassAbility);
  static List<PokemonType> defensiveTypesOf(PokemonInstance mon) => _defensiveTypes(mon);
  static String? tryInflictStatus(
    PokemonInstance target,
    String effect, {
    Random? random,
    BattleFieldState? field,
    bool targetIsPlayer = false,
    PokemonInstance? source,
    bool bypassDefAbility = false,
  }) =>
      _tryInflictStatus(
        target,
        effect,
        random: random,
        field: field,
        targetIsPlayer: targetIsPlayer,
        source: source,
        bypassDefAbility: bypassDefAbility,
      );
  static bool applySingleStatStage({
    required PokemonInstance target,
    required PokemonInstance foe,
    required String stat,
    required int delta,
    required String targetLabel,
    required bool targetIsPlayer,
    required bool byFoe,
    required bool bypassDefAbility,
    required List<BattleStepEvent> events,
    Move? move,
    String? actorLabel,
    bool? isPlayerActor,
    BattleFieldState? field,
    bool hideMoveVfx = false,
  }) =>
      _applySingleStatStage(
        target: target,
        foe: foe,
        stat: stat,
        delta: delta,
        targetLabel: targetLabel,
        targetIsPlayer: targetIsPlayer,
        byFoe: byFoe,
        bypassDefAbility: bypassDefAbility,
        events: events,
        move: move,
        actorLabel: actorLabel,
        isPlayerActor: isPlayerActor,
        field: field,
        hideMoveVfx: hideMoveVfx,
      );

  static List<PokemonType> _defensiveTypes(PokemonInstance mon) {
    final base = mon.effectiveTypes;
    if (!mon.isRoostedThisTurn || !base.contains(PokemonType.flying)) {
      return base;
    }
    final withoutFlying =
        base.where((t) => t != PokemonType.flying).toList();
    return withoutFlying.isEmpty ? [PokemonType.normal] : withoutFlying;
  }

  static bool _isGrounded(PokemonInstance mon, BattleFieldState? field, {bool bypassAbility = false}) {
    if (mon.isRoostedThisTurn) return true;
    if (field != null && field.gravityTurns > 0) return true;
    if (mon.hasMagnetRise) return false;
    if (mon.effectiveTypes.contains(PokemonType.flying)) return false;
    if (!bypassAbility && mon.effectiveAbilityId == 'levitate') return false;
    return true;
  }

  // ─── ENTRY & SWITCH-OUT ABILITY HOOKS ───────────────────────────────────────
  static List<BattleStepEvent> onPokemonLeaveBattle(
    PokemonInstance mon, {
    required bool isPlayer,
    required bool isWild,
  }) {
    final List<BattleStepEvent> events = [];
    final monName = _labelFor(mon, isPlayer, isWild);
    final ab = mon.effectiveAbilityId;

    if (!mon.isFainted && ab == 'natural_cure' && mon.status != StatusCondition.none) {
      mon.status = StatusCondition.none;
      mon.isBadlyPoisoned = false;
      events.add(BattleStepEvent(
        message: "$monName's Natural Cure healed its status problem!",
        isPlayerActor: isPlayer,
        statusInflictedLabel: 'CURED',
        hideMoveVfx: true,
        abilityTriggeredName: 'Natural Cure',
      ));
    }

    if (!mon.isFainted && ab == 'regenerator' && mon.currentHp < mon.maxHp) {
      final heal = min(max(1, mon.maxHp ~/ 3), mon.maxHp - mon.currentHp);
      mon.currentHp += heal;
      events.add(BattleStepEvent(
        message: "$monName restored HP with Regenerator!",
        isPlayerActor: isPlayer,
        healAmount: heal,
        targetHpAfter: mon.currentHp,
        hideMoveVfx: true,
        abilityTriggeredName: 'Regenerator',
      ));
    }

    mon.resetStatStages();
    return events;
  }

  static List<BattleStepEvent> onPokemonEnterBattle(
    PokemonInstance mon,
    PokemonInstance foe, {
    required bool isPlayer,
    required bool isWild,
    BattleFieldState? field,
  }) {
    final List<BattleStepEvent> events = [];
    if (mon.isFainted) return events;
    mon.turnsActiveInBattle = 0;

    final monName = _labelFor(mon, isPlayer, isWild);
    final foeName = _labelFor(foe, !isPlayer, isWild);
    final activeField = field ?? BattleFieldState();

    // 1. Entry Hazards on entering side & Healing Wish
    final side = activeField.sideFor(isPlayer);
    if (side.hasHealingWishPending &&
        (mon.currentHp < mon.maxHp || mon.status != StatusCondition.none)) {
      side.hasHealingWishPending = false;
      final int heal = mon.maxHp - mon.currentHp;
      mon.currentHp = mon.maxHp;
      mon.status = StatusCondition.none;
      mon.isBadlyPoisoned = false;
      events.add(BattleStepEvent(
        message: "The healing wish came true for $monName!",
        isPlayerActor: isPlayer,
        moveId: 'healing_wish',
        moveType: PokemonType.psychic,
        moveCategory: MoveCategory.status,
        healAmount: heal,
        targetHpAfter: mon.currentHp,
        statTargetIsSelf: true,
        statusInflictedLabel: 'HEALED!',
      ));
    }
    final bool magicGuard = mon.effectiveAbilityId == 'magic_guard';
    final bool grounded = _isGrounded(mon, activeField);

    if (side.hasStealthRock && !magicGuard) {
      final double mult =
          PokemonTypeExtension.getEffectiveness(PokemonType.rock, mon.effectiveTypes);
      final int srDmg = max(1, (mon.maxHp * mult / 8.0).floor());
      mon.currentHp = (mon.currentHp - srDmg).clamp(0, mon.maxHp);
      events.add(BattleStepEvent(
        message: "Pointed stones dug into $monName!",
        isPlayerActor: !isPlayer,
        moveType: PokemonType.rock,
        damageDealt: srDmg,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));
      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
        return events;
      }
    }

    if (side.spikesLayers > 0 && grounded && !magicGuard) {
      final int denom = side.spikesLayers == 1 ? 8 : (side.spikesLayers == 2 ? 6 : 4);
      final int spDmg = max(1, mon.maxHp ~/ denom);
      mon.currentHp = (mon.currentHp - spDmg).clamp(0, mon.maxHp);
      events.add(BattleStepEvent(
        message: "$monName was hurt by the spikes!",
        isPlayerActor: !isPlayer,
        moveType: PokemonType.ground,
        damageDealt: spDmg,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));
      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
        return events;
      }
    }

    if (side.toxicSpikesLayers > 0 && grounded) {
      if (mon.effectiveTypes.contains(PokemonType.poison)) {
        side.toxicSpikesLayers = 0;
        events.add(BattleStepEvent(
          message: "$monName absorbed the poison spikes!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
      } else if (!magicGuard && side.safeguardTurns <= 0) {
        final String eff = side.toxicSpikesLayers >= 2 ? 'badly_poison' : 'poison';
        final label = _tryInflictStatus(mon, eff);
        if (label != null) {
          events.add(BattleStepEvent(
            message: "$monName was poisoned by the toxic spikes!",
            isPlayerActor: !isPlayer,
            statusInflictedLabel: label,
            hideMoveVfx: true,
          ));
        }
      }
    }

    // 2. Entry Ability Announcements & Triggers
    final String ab = mon.effectiveAbilityId;
    switch (ab) {
      case 'intimidate':
        if (!foe.isFainted) {
          final foeAb = foe.effectiveAbilityId;
          if (foeAb == 'clear_body' || foeAb == 'hyper_cutter') {
            events.add(BattleStepEvent(
              message: "$foeName's ${AbilityDatabase.nameOf(foeAb)} prevented Intimidate!",
              isPlayerActor: !isPlayer,
              hideMoveVfx: true,
              abilityTriggeredName: AbilityDatabase.nameOf(foeAb),
            ));
          } else {
            final delta = foe.modifyStatStage('atk', -1);
            events.add(BattleStepEvent(
              message: delta != 0
                  ? "$monName's Intimidate cut $foeName's Attack!"
                  : "$monName's Intimidate had no further effect on $foeName!",
              isPlayerActor: isPlayer,
              statChangedLabel: delta != 0 ? 'ATK ▼' : null,
              statTargetIsSelf: false,
              hideMoveVfx: true,
              abilityTriggeredName: 'Intimidate',
            ));
            if (delta != 0 && foeAb == 'defiant') {
              foe.modifyStatStage('atk', 2);
              events.add(BattleStepEvent(
                message: "$foeName's Defiant sharply raised its Attack!",
                isPlayerActor: !isPlayer,
                statChangedLabel: 'ATK ▲▲',
                statTargetIsSelf: true,
                hideMoveVfx: true,
                abilityTriggeredName: 'Defiant',
              ));
            } else if (delta != 0 && foeAb == 'rattled') {
              foe.modifyStatStage('spe', 1);
              events.add(BattleStepEvent(
                message: "$foeName's Rattled boosted its Speed!",
                isPlayerActor: !isPlayer,
                statChangedLabel: 'SPE ▲',
                statTargetIsSelf: true,
                hideMoveVfx: true,
                abilityTriggeredName: 'Rattled',
              ));
            }
          }
        }
        break;
      case 'drought':
        if (activeField.weather != BattleWeather.sun) {
          activeField.weather = BattleWeather.sun;
          activeField.weatherTurnsRemaining = -1;
          events.add(BattleStepEvent(
            message: "$monName's Drought intensified the sun's rays!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
            abilityTriggeredName: 'Drought',
          ));
        }
        break;
      case 'drizzle':
        if (activeField.weather != BattleWeather.rain) {
          activeField.weather = BattleWeather.rain;
          activeField.weatherTurnsRemaining = -1;
          events.add(BattleStepEvent(
            message: "$monName's Drizzle made it rain!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
            abilityTriggeredName: 'Drizzle',
          ));
        }
        break;
      case 'download':
        if (!foe.isFainted) {
          final String targetStat = foe.effectiveDef < foe.effectiveSpd ? 'atk' : 'spa';
          mon.modifyStatStage(targetStat, 1);
          events.add(BattleStepEvent(
            message:
                "$monName's Download raised its ${_statDisplayName(targetStat)}!",
            isPlayerActor: isPlayer,
            statChangedLabel: '${targetStat.toUpperCase()} ▲',
            statTargetIsSelf: true,
            hideMoveVfx: true,
            abilityTriggeredName: 'Download',
          ));
        }
        break;
      case 'trace':
        final targetAb = foe.effectiveAbilityId;
        if (!foe.isFainted && targetAb != 'trace' && targetAb != 'imposter') {
          mon.activeAbilityId = targetAb;
          events.add(BattleStepEvent(
            message:
                "$monName traced $foeName's ${AbilityDatabase.nameOf(targetAb)}!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
            abilityTriggeredName: 'Trace',
          ));
        }
        break;
      case 'imposter':
        if (!foe.isFainted &&
            foe.effectiveAbilityId != 'imposter' &&
            mon.transformedMoves == null) {
          _applyTransformCopy(mon, foe);
          events.add(BattleStepEvent(
            message: "$monName transformed into ${foe.species.name}!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
            abilityTriggeredName: 'Imposter',
          ));
        }
        break;
      case 'frisk':
        if (!foe.isFainted && foe.hasHeldItem) {
          final itemName = ItemDatabase.byId(foe.heldItemId!)?.name ?? foe.heldItemId!;
          events.add(BattleStepEvent(
            message: "$monName frisked $foeName and found its $itemName!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
            abilityTriggeredName: 'Frisk',
          ));
        }
        break;
      case 'anticipation':
        if (!foe.isFainted) {
          final hasDanger = foe.activeMoves.any((m) =>
              _ohkoMoves.contains(m.id) ||
              (m.power > 0 &&
                  PokemonTypeExtension.getEffectiveness(m.type, mon.effectiveTypes) >= 2.0));
          if (hasDanger) {
            events.add(BattleStepEvent(
              message: "$monName shuddered with Anticipation!",
              isPlayerActor: isPlayer,
              hideMoveVfx: true,
              abilityTriggeredName: 'Anticipation',
            ));
          }
        }
        break;
      case 'forewarn':
        if (!foe.isFainted && foe.activeMoves.isNotEmpty) {
          Move best = foe.activeMoves.first;
          for (final m in foe.activeMoves) {
            if (m.power > best.power) best = m;
          }
          if (best.power > 0) {
            events.add(BattleStepEvent(
              message: "$monName's Forewarn alerted it to ${best.name}!",
              isPlayerActor: isPlayer,
              hideMoveVfx: true,
              abilityTriggeredName: 'Forewarn',
            ));
          }
        }
        break;
      case 'pressure':
        events.add(BattleStepEvent(
          message: "$monName is exerting its Pressure!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Pressure',
        ));
        break;
      case 'unnerve':
        events.add(BattleStepEvent(
          message: "$monName's Unnerve makes $foeName too nervous to eat Berries!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Unnerve',
        ));
        break;
      case 'cloud_nine':
        events.add(BattleStepEvent(
          message: "The effects of the weather disappeared ($monName's Cloud Nine)!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Cloud Nine',
        ));
        break;
    }

    return events;
  }

  static void _applyTransformCopy(PokemonInstance target, PokemonInstance source) {
    target.transformedBaseStats = {
      'atk': source.combatBaseAtk,
      'def': source.combatBaseDef,
      'spa': source.combatBaseSpa,
      'spd': source.combatBaseSpd,
      'spe': source.combatBaseSpe,
    };
    target
      ..atkStage = source.atkStage
      ..defStage = source.defStage
      ..spaStage = source.spaStage
      ..spdStage = source.spdStage
      ..speStage = source.speStage
      ..accStage = source.accStage
      ..evaStage = source.evaStage;
    target.activeTypesOverride = List<PokemonType>.from(source.effectiveTypes);
    target.activeAbilityId = source.effectiveAbilityId;
    target.transformedMoves = source.activeMoves
        .map(
          (m) => Move(
            id: m.id,
            name: m.name,
            type: m.type,
            category: m.category,
            power: m.power,
            accuracy: m.accuracy,
            maxPp: 5,
            currentPp: 5,
            priority: m.priority,
            description: m.description,
            statTarget: m.statTarget,
            statChange: m.statChange,
            statusEffect: m.statusEffect,
            statusChance: m.statusChance,
            minHits: m.minHits,
            maxHits: m.maxHits,
            stageMechanic: m.stageMechanic,
            chargeStatusMessage: m.chargeStatusMessage,
            chargeSelfStatTarget: m.chargeSelfStatTarget,
            chargeSelfStatChange: m.chargeSelfStatChange,
          ),
        )
        .toList();
  }

  static double _applyIdentifiedTypeOverride(
    double typeMultiplier,
    PokemonType moveType,
    PokemonInstance defender, {
    required bool bypassGhostWithScrappy,
  }) {
    final List<PokemonType> types = defender.effectiveTypes;
    if (types.contains(PokemonType.ghost) &&
        (moveType == PokemonType.normal || moveType == PokemonType.fighting) &&
        (bypassGhostWithScrappy || defender.isIdentified)) {
      final nonGhost = types.where((t) => t != PokemonType.ghost).toList();
      return nonGhost.isEmpty
          ? 1.0
          : PokemonTypeExtension.getEffectiveness(moveType, nonGhost);
    }
    if (types.contains(PokemonType.dark) &&
        moveType == PokemonType.psychic &&
        defender.isIdentified) {
      final nonDark = types.where((t) => t != PokemonType.dark).toList();
      return nonDark.isEmpty
          ? 1.0
          : PokemonTypeExtension.getEffectiveness(moveType, nonDark);
    }
    return typeMultiplier;
  }

  // ─── MOVE RESOLUTION & AI ───────────────────────────────────────────────────
  static Move? resolveEffectiveMove(PokemonInstance mon, Move? selectedMove) {
    final String? forcedId = mon.forcedMoveId;
    if (forcedId == null || forcedId == 'recharge') {
      if (mon.encoreTurnsRemaining > 0 && mon.encoredMoveId != null) {
        final encored = mon.activeMoves.where(
          (m) => m.id == mon.encoredMoveId && m.currentPp > 0,
        );
        if (encored.isNotEmpty) return encored.first;
      }
      return selectedMove;
    }
    for (final m in mon.activeMoves) {
      if (m.id == forcedId) return m;
    }
    final dbMove = PokedexDatabase.moves[forcedId];
    return dbMove?.copy() ?? selectedMove;
  }

  static const Set<String> _uncallableSleepTalkMoves = {
    'sleep_talk',
    'rest',
    'bide',
    'focus_punch',
    'metronome',
    'mirror_move',
    'copycat',
    'me_first',
    'uproar',
    'mimic',
    'struggle',
  };

  static List<Move> _sleepTalkCandidates(PokemonInstance mon) {
    return mon.activeMoves
        .where(
          (m) =>
              !_uncallableSleepTalkMoves.contains(m.id) && !m.isTwoTurnCharge,
        )
        .toList();
  }

  static Move? selectOpponentMove(
    PokemonInstance opponent, {
    PokemonInstance? target,
    BattleFieldState? field,
    bool opponentIsPlayer = false,
    Random? rng,
  }) {
    final moves = opponent.activeMoves;
    if (moves.isEmpty) return null;
    if (opponent.encoreTurnsRemaining > 0 && opponent.encoredMoveId != null) {
      final encored = moves.where(
        (m) => m.id == opponent.encoredMoveId && m.currentPp > 0,
      );
      if (encored.isNotEmpty) return encored.first;
    }
    final withPp = moves.where((m) => m.currentPp > 0).toList();
    final List<Move> available =
        withPp.isNotEmpty ? withPp : List<Move>.from(moves);

    final bool inRedHp =
        opponent.maxHp > 0 && (opponent.currentHp / opponent.maxHp) <= 0.20;
    final filtered = available.where((m) {
      if (!inRedHp && (m.id == 'self_destruct' || m.id == 'explosion' || m.id == 'memento')) {
        return false;
      }
      if (opponent.disableTurnsRemaining > 0 && m.id == opponent.disabledMoveId) {
        return false;
      }
      if (opponent.isTormented && m.id == opponent.lastMoveUsedId) {
        return false;
      }
      if (opponent.isTaunted && m.category == MoveCategory.status) {
        return false;
      }
      if (target != null &&
          target.isImprisoning &&
          target.activeMoves.any((em) => em.id == m.id)) {
        return false;
      }
      if (m.id == 'rest' && field != null && field.uproarTurns > 0) {
        return false;
      }
      if (m.id == 'snore' && opponent.status != StatusCondition.sleep) {
        return false;
      }
      if (m.id == 'sleep_talk' &&
          (opponent.status != StatusCondition.sleep ||
              _sleepTalkCandidates(opponent).isEmpty)) {
        return false;
      }
      if ((m.id == 'dream_eater' || m.id == 'nightmare') &&
          target != null &&
          (target.status != StatusCondition.sleep ||
              (m.id == 'nightmare' && target.hasNightmare))) {
        return false;
      }
      if (m.id == 'fake_out' && opponent.turnsActiveInBattle > 0) {
        return false;
      }
      if (m.id == 'last_resort' && opponent.lastMoveUsedId == null) {
        return false;
      }
      if (m.id == 'future_sight' &&
          field != null &&
          field.sideFor(!opponentIsPlayer).futureSightTurns > 0) {
        return false;
      }
      return true;
    }).toList();
    final pool = filtered.isNotEmpty ? filtered : available;
    return pool[(rng ?? _rng).nextInt(pool.length)];
  }

  static int effectiveCombatSpeed(
    PokemonInstance mon,
    PokemonInstance foe,
    BattleFieldState? field, {
    bool isPlayer = false,
    Trainer? playerTrainer,
  }) {
    double spe = mon.effectiveSpe.toDouble();
    final weather = field?.effectiveWeather(mon, foe) ?? BattleWeather.none;
    final ab = mon.effectiveAbilityId;
    if (weather == BattleWeather.sun && ab == 'chlorophyll') spe *= 2.0;
    if (weather == BattleWeather.rain && ab == 'swift_swim') spe *= 2.0;
    if (weather == BattleWeather.sandstorm && ab == 'sand_rush') spe *= 2.0;
    if (field != null && field.sideFor(isPlayer).tailwindTurns > 0) spe *= 2.0;
    if (isPlayer && playerTrainer != null) {
      spe *= playerTrainer.speBadgeMultiplier;
    }
    return spe.round().clamp(1, 99999);
  }

  // ─── FULL TURN RESOLUTION ───────────────────────────────────────────────────
  static List<BattleStepEvent> resolveTurn({
    required PokemonInstance playerMon,
    required BattleAction playerAction,
    required PokemonInstance opponentMon,
    required BattleAction opponentAction,
    bool isWild = true,
    Trainer? playerTrainer,
    BattleFieldState? field,
  }) {
    final List<BattleStepEvent> events = [];
    final activeField = field ?? BattleFieldState();
    final bool playerWasFainted = playerMon.isFainted;
    final bool oppWasFainted = opponentMon.isFainted;

    // Reset per-turn flags
    playerMon
      ..isProtectedThisTurn = false
      ..isEnduringThisTurn = false
      ..isRoostedThisTurn = false
      ..hasMagicCoatThisTurn = false
      ..actedFirstThisTurn = false
      ..flinchedThisTurn = false
      ..lastDamageTakenThisTurn = 0
      ..lastPhysicalDamageTakenThisTurn = 0
      ..lastSpecialDamageTakenThisTurn = 0;
    opponentMon
      ..isProtectedThisTurn = false
      ..isEnduringThisTurn = false
      ..isRoostedThisTurn = false
      ..hasMagicCoatThisTurn = false
      ..actedFirstThisTurn = false
      ..flinchedThisTurn = false
      ..lastDamageTakenThisTurn = 0
      ..lastPhysicalDamageTakenThisTurn = 0
      ..lastSpecialDamageTakenThisTurn = 0;

    final preBerryPlayer = checkAndConsumeHeldBerry(
      playerMon,
      opponent: opponentMon,
      isPlayer: true,
      isWild: isWild,
    );
    if (preBerryPlayer != null) events.add(preBerryPlayer);
    final preBerryOpp = checkAndConsumeHeldBerry(
      opponentMon,
      opponent: playerMon,
      isPlayer: false,
      isWild: isWild,
    );
    if (preBerryOpp != null) events.add(preBerryOpp);

    final Move? effectivePlayerMove = playerAction.type == BattleActionType.fight
        ? resolveEffectiveMove(playerMon, playerAction.move)
        : null;
    final Move? effectiveOppMove = opponentAction.type == BattleActionType.fight
        ? resolveEffectiveMove(opponentMon, opponentAction.move)
        : null;

    bool playerGoesFirst = true;
    if (effectivePlayerMove != null && effectiveOppMove != null) {
      final pPriority = playerMon.needsRecharge ? 0 : effectivePlayerMove.priority;
      final oPriority = opponentMon.needsRecharge ? 0 : effectiveOppMove.priority;

      if (pPriority != oPriority) {
        playerGoesFirst = pPriority > oPriority;
      } else {
        final pSpe = effectiveCombatSpeed(
          playerMon,
          opponentMon,
          activeField,
          isPlayer: true,
          playerTrainer: playerTrainer,
        );
        final oSpe = effectiveCombatSpeed(
          opponentMon,
          playerMon,
          activeField,
          isPlayer: false,
        );
        if (pSpe != oSpe) {
          playerGoesFirst = pSpe > oSpe;
        } else {
          playerGoesFirst = _rng.nextBool();
        }
      }
    } else if (effectiveOppMove != null && effectivePlayerMove == null) {
      playerGoesFirst = false;
    }

    if (playerGoesFirst) {
      playerMon.actedFirstThisTurn = true;
      if (effectivePlayerMove != null && !playerMon.isFainted) {
        events.addAll(executeSingleAttack(
          playerMon,
          effectivePlayerMove,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
          field: activeField,
          defenderIntendedMove: effectiveOppMove,
        ));
      }
      if (!playerMon.isFainted && !opponentMon.isFainted && effectiveOppMove != null) {
        events.addAll(executeSingleAttack(
          opponentMon,
          effectiveOppMove,
          playerMon,
          isPlayer: false,
          isWild: isWild,
          playerTrainer: playerTrainer,
          field: activeField,
          defenderIntendedMove: effectivePlayerMove,
        ));
      }
    } else {
      opponentMon.actedFirstThisTurn = true;
      if (effectiveOppMove != null && !opponentMon.isFainted) {
        events.addAll(executeSingleAttack(
          opponentMon,
          effectiveOppMove,
          playerMon,
          isPlayer: false,
          isWild: isWild,
          playerTrainer: playerTrainer,
          field: activeField,
          defenderIntendedMove: effectivePlayerMove,
        ));
      }
      if (!playerMon.isFainted && !opponentMon.isFainted && effectivePlayerMove != null) {
        events.addAll(executeSingleAttack(
          playerMon,
          effectivePlayerMove,
          opponentMon,
          isPlayer: true,
          isWild: isWild,
          playerTrainer: playerTrainer,
          field: activeField,
          defenderIntendedMove: effectiveOppMove,
        ));
      }
    }

    if (!playerMon.isFainted && !opponentMon.isFainted) {
      events.addAll(processEndOfTurnStatus(
        playerMon,
        opponent: opponentMon,
        isPlayer: true,
        isWild: isWild,
        field: activeField,
      ));
      if (!playerMon.isFainted && !opponentMon.isFainted) {
        events.addAll(processEndOfTurnStatus(
          opponentMon,
          opponent: playerMon,
          isPlayer: false,
          isWild: isWild,
          field: activeField,
        ));
      }
    }
    events.addAll(processEndOfTurnField(
      activeField,
      playerMon,
      opponentMon,
      isWild: isWild,
      playerTrainer: playerTrainer,
    ));
    if (!playerMon.isFainted) {
      playerMon.turnsActiveInBattle++;
    }
    if (!opponentMon.isFainted) {
      opponentMon.turnsActiveInBattle++;
    }
    activeField.playerSide.allyFaintedLastTurn =
        !playerWasFainted && playerMon.isFainted;
    activeField.opponentSide.allyFaintedLastTurn =
        !oppWasFainted && opponentMon.isFainted;

    return events;
  }

  // ─── HELD ITEMS & BERRIES ───────────────────────────────────────────────────
  static double _getHeldItemDamageMultiplier(PokemonInstance attacker, PokemonType moveType) {
    switch (attacker.heldItemId) {
      case 'hard_stone':
        return moveType == PokemonType.rock ? 1.20 : 1.0;
      case 'mystic_water':
        return moveType == PokemonType.water ? 1.20 : 1.0;
      case 'magnet':
        return moveType == PokemonType.electric ? 1.20 : 1.0;
      case 'miracle_seed':
        return moveType == PokemonType.grass ? 1.20 : 1.0;
      case 'poison_barb':
        return moveType == PokemonType.poison ? 1.20 : 1.0;
      case 'twisted_spoon':
        return moveType == PokemonType.psychic ? 1.20 : 1.0;
      case 'charcoal':
        return moveType == PokemonType.fire ? 1.20 : 1.0;
      case 'soft_sand':
        return moveType == PokemonType.ground ? 1.20 : 1.0;
      case 'never_melt_ice':
        return moveType == PokemonType.ice ? 1.20 : 1.0;
      case 'black_belt':
        return moveType == PokemonType.fighting ? 1.20 : 1.0;
      case 'spell_tag':
        return moveType == PokemonType.ghost ? 1.20 : 1.0;
      case 'dragon_fang':
        return moveType == PokemonType.dragon ? 1.20 : 1.0;
      case 'life_orb':
        return 1.30;
      default:
        return 1.0;
    }
  }

  static BattleStepEvent? checkAndConsumeHeldBerry(
    PokemonInstance mon, {
    PokemonInstance? opponent,
    required bool isPlayer,
    bool isWild = true,
  }) {
    if (mon.isFainted || mon.heldItemId == null) return null;
    if (opponent != null && !opponent.isFainted && opponent.effectiveAbilityId == 'unnerve') {
      return null;
    }

    final monName = _labelFor(mon, isPlayer, isWild);
    final held = mon.heldItemId!;
    final bool hasGluttony = mon.effectiveAbilityId == 'gluttony';
    final double hpThreshold = hasGluttony ? 0.65 : 0.50;

    if (mon.hpPercent <= hpThreshold) {
      int? healCap;
      String? berryName;
      if (held == 'oran_berry') {
        healCap = 10;
        berryName = 'Oran Berry';
      } else if (held == 'sitrus_berry') {
        healCap = max(30, mon.maxHp ~/ 4);
        berryName = 'Sitrus Berry';
      }
      if (healCap != null && berryName != null && mon.currentHp < mon.maxHp) {
        final heal = min(healCap, mon.maxHp - mon.currentHp);
        mon.currentHp += heal;
        mon.consumedBerryIdForHarvest = held;
        mon.consumedHeldItemForUnburden = true;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message: "$monName ate its held $berryName and restored $heal HP!",
          isPlayerActor: isPlayer,
          healAmount: heal,
          targetHpAfter: mon.currentHp,
          isStatusTick: true,
        );
      }
    }

    if (mon.status != StatusCondition.none) {
      String? berryName;
      if (held == 'cheri_berry' && mon.status == StatusCondition.paralysis) {
        berryName = 'Cheri Berry';
      } else if (held == 'chesto_berry' && mon.status == StatusCondition.sleep) {
        berryName = 'Chesto Berry';
      } else if (held == 'pecha_berry' && mon.status == StatusCondition.poison) {
        berryName = 'Pecha Berry';
      } else if (held == 'rawst_berry' && mon.status == StatusCondition.burn) {
        berryName = 'Rawst Berry';
      } else if (held == 'aspear_berry' && mon.status == StatusCondition.freeze) {
        berryName = 'Aspear Berry';
      } else if (held == 'lum_berry') {
        berryName = 'Lum Berry';
      }
      if (berryName != null) {
        final oldStatus = mon.status.name.toUpperCase();
        mon.status = StatusCondition.none;
        mon.isBadlyPoisoned = false;
        mon.consumedBerryIdForHarvest = held;
        mon.consumedHeldItemForUnburden = true;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message: "$monName ate its held $berryName and was cured of $oldStatus!",
          isPlayerActor: isPlayer,
          targetHpAfter: mon.currentHp,
          statusInflictedLabel: "CURED",
          isStatusTick: true,
        );
      }
    }

    if (held == 'leppa_berry') {
      final depleted = mon.activeMoves.where((m) => m.currentPp <= 0).toList();
      if (depleted.isNotEmpty) {
        final targetMove = depleted.first;
        final int restored = min(10, targetMove.maxPp - targetMove.currentPp);
        targetMove.currentPp = min(targetMove.maxPp, targetMove.currentPp + 10);
        mon.consumedBerryIdForHarvest = held;
        mon.consumedHeldItemForUnburden = true;
        mon.unequipHeldItem();
        return BattleStepEvent(
          message:
              "$monName ate its held Leppa Berry and restored $restored PP to ${targetMove.name}!",
          isPlayerActor: isPlayer,
          targetHpAfter: mon.currentHp,
          isStatusTick: true,
          hideMoveVfx: true,
        );
      }
    }
    return null;
  }

  static void _clearMoveLocks(PokemonInstance mon) {
    mon.chargingMoveId = null;
    mon.isUnderground = false;
    mon.bideTurnsRemaining = 0;
    mon.bideDamageStored = 0;
    mon.rampageMoveId = null;
    mon.rampageTurnsRemaining = 0;
    mon.rolloutTurnsRemaining = 0;
    mon.rolloutHitCount = 0;
  }

  static int _rollHitCount(PokemonInstance attacker, Move move, Random random) {
    if (move.maxHits <= 1) return 1;
    if (attacker.effectiveAbilityId == 'skill_link') return move.maxHits;
    if (move.minHits >= move.maxHits) return move.maxHits;
    if (move.minHits == 2 && move.maxHits == 5) {
      final r = random.nextInt(8);
      if (r < 3) return 2;
      if (r < 6) return 3;
      return r == 6 ? 4 : 5;
    }
    return move.minHits + random.nextInt(move.maxHits - move.minHits + 1);
  }

  static int _resolveDynamicPower(
    PokemonInstance attacker,
    Move move,
    PokemonInstance defender, {
    BattleFieldState? field,
    bool isPlayer = true,
  }) {
    switch (move.id) {
      case 'low_kick':
      case 'grass_knot':
        final w = defender.species.weightKg;
        if (w >= 200.0) return 120;
        if (w >= 100.0) return 100;
        if (w >= 50.0) return 80;
        if (w >= 25.0) return 60;
        return w >= 10.0 ? 40 : 20;
      case 'heavy_slam':
      case 'heat_crash':
        final ratio = attacker.species.weightKg / max(0.1, defender.species.weightKg);
        if (ratio >= 5.0) return 120;
        if (ratio >= 4.0) return 100;
        if (ratio >= 3.0) return 80;
        if (ratio >= 2.0) return 60;
        return 40;
      case 'eruption':
      case 'water_spout':
        return max(1, (150 * attacker.hpPercent).round());
      case 'gyro_ball':
        final sRatio = (25.0 * defender.effectiveSpe / max(1, attacker.effectiveSpe)).round();
        return sRatio.clamp(1, 150);
      case 'flail':
      case 'reversal':
        final p = attacker.hpPercent;
        if (p < 0.042) return 200;
        if (p < 0.105) return 150;
        if (p < 0.208) return 100;
        if (p < 0.354) return 80;
        if (p < 0.687) return 40;
        return 20;
      case 'wring_out':
        return max(1, (120 * defender.hpPercent).round());
      case 'trump_card':
        final rem = move.currentPp;
        if (rem <= 1) return 200;
        if (rem == 2) return 80;
        if (rem == 3) return 60;
        if (rem == 4) return 50;
        return 40;
      case 'stored_power':
        int boosts = 0;
        for (final s in [
          attacker.atkStage, attacker.defStage, attacker.spaStage,
          attacker.spdStage, attacker.speStage, attacker.accStage, attacker.evaStage,
        ]) {
          if (s > 0) boosts += s;
        }
        return 20 + boosts * 20;
      case 'brine':
        return defender.hpPercent <= 0.50 ? 130 : 65;
      case 'hex':
        return defender.status != StatusCondition.none ? 130 : 65;
      case 'venoshock':
        return defender.status == StatusCondition.poison ? 130 : 65;
      case 'facade':
        return attacker.status != StatusCondition.none ? 140 : 70;
      case 'wake_up_slap':
        return defender.status == StatusCondition.sleep ? 140 : 70;
      case 'smelling_salts':
        return defender.status == StatusCondition.paralysis ? 140 : 70;
      case 'acrobatics':
        return !attacker.hasHeldItem ? 110 : 55;
      case 'payback':
        return !attacker.actedFirstThisTurn ? 100 : 50;
      case 'revenge':
      case 'avalanche':
        return attacker.lastDamageTakenThisTurn > 0 ? 120 : 60;
      case 'assurance':
        return defender.lastDamageTakenThisTurn > 0 ? 120 : 60;
      case 'spit_up':
        return 100 * attacker.stockpileCount.clamp(1, 3);
      case 'magnitude':
        return 70;
      case 'punishment':
        int oppBoosts = 0;
        for (final s in [
          defender.atkStage, defender.defStage, defender.spaStage,
          defender.spdStage, defender.speStage, defender.accStage, defender.evaStage,
        ]) {
          if (s > 0) oppBoosts += s;
        }
        return min(200, 60 + 20 * oppBoosts);
      case 'fury_cutter':
        return min(160, 40 * (1 << attacker.consecutiveFuryCutterHits.clamp(0, 2)));
      case 'fling':
        return attacker.hasHeldItem ? 60 : 0;
      case 'natural_gift':
        final heldObj = attacker.hasHeldItem ? ItemDatabase.byId(attacker.heldItemId!) : null;
        return (heldObj != null && heldObj.isBerry) ? 80 : 0;
      case 'retaliate':
        return (field?.sideFor(isPlayer).allyFaintedLastTurn ?? false)
            ? 140
            : 70;
      default:
        return move.power;
    }
  }

  // ─── DAMAGE COMPUTATION ─────────────────────────────────────────────────────
  static ({int damage, bool isCrit, double typeMultiplier}) _computeHitDamage({
    required PokemonInstance attacker,
    required Move move,
    required PokemonInstance defender,
    required bool isPlayer,
    bool? defenderIsPlayer,
    required Trainer? playerTrainer,
    required Random random,
    BattleFieldState? field,
    int? powerOverride,
    double extraMultiplier = 1.0,
    bool isDoubleBattleScreen = false,
    bool allyHasFriendGuard = false,
  }) {
    final bool defIsPlayer = defenderIsPlayer ?? !isPlayer;
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = defender.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';
    final bool unawareAtk = atkAb == 'unaware';
    final bool unawareDef = !bypassDefAb && defAb == 'unaware';
    final BattleWeather weather =
        field?.effectiveWeather(attacker, defender) ?? BattleWeather.none;

    double movePowerDouble = (powerOverride ??
            _resolveDynamicPower(attacker, move, defender,
                field: field, isPlayer: isPlayer))
        .toDouble();
    if (attacker.isChargedElectric && move.type == PokemonType.electric) {
      movePowerDouble *= 2.0;
    }
    if (attacker.helpingHandBoosted) {
      movePowerDouble *= 1.5;
    }

    // Attacker power-modifying Abilities
    if (atkAb == 'technician' && movePowerDouble <= 60) {
      movePowerDouble *= 1.5;
    }
    if (atkAb == 'iron_fist' && _punchMoves.contains(move.id)) {
      movePowerDouble *= 1.2;
    }
    if (atkAb == 'reckless' && _recoilFraction.containsKey(move.id)) {
      movePowerDouble *= 1.2;
    }
    if (atkAb == 'sheer_force' && _hasSheerForceBoost(move)) {
      movePowerDouble *= 1.3;
    }
    if (atkAb == 'analytic' && !attacker.actedFirstThisTurn) {
      movePowerDouble *= 1.3;
    }
    if (atkAb == 'sand_force' &&
        weather == BattleWeather.sandstorm &&
        (move.type == PokemonType.rock ||
            move.type == PokemonType.ground ||
            move.type == PokemonType.steel)) {
      movePowerDouble *= 1.3;
    }
    if (atkAb == 'rivalry' &&
        attacker.effectiveTypes.any((t) => defender.effectiveTypes.contains(t))) {
      movePowerDouble *= 1.25;
    }
    if (atkAb == 'flash_fire' && attacker.flashFireBoosted && move.type == PokemonType.fire) {
      movePowerDouble *= 1.5;
    }
    // Pinch Abilities (<= 1/3 HP)
    if (attacker.hpPercent <= (1.0 / 3.0)) {
      if ((atkAb == 'blaze' && move.type == PokemonType.fire) ||
          (atkAb == 'overgrow' && move.type == PokemonType.grass) ||
          (atkAb == 'torrent' && move.type == PokemonType.water) ||
          (atkAb == 'swarm' && move.type == PokemonType.bug)) {
        movePowerDouble *= 1.5;
      }
    }
    if (move.id == 'knock_off' && defender.hasHeldItem) {
      movePowerDouble *= 1.5;
    }
    if (field != null) {
      if (field.mudSportActive && move.type == PokemonType.electric) {
        movePowerDouble *= 0.33;
      }
      if (field.waterSportActive && move.type == PokemonType.fire) {
        movePowerDouble *= 0.33;
      }
    }

    final int movePower = movePowerDouble.round().clamp(1, 999);

    // Crit check (check before Attack/Defense ignores on Crit!)
    final bool critBlocked = (!bypassDefAb && (defAb == 'battle_armor' || defAb == 'shell_armor')) ||
        (field != null && field.sideFor(defIsPlayer).luckyChantTurns > 0);
    int critChanceDenom =
        (isPlayer && playerTrainer != null && playerTrainer.critBadgeBonus > 0) ? 8 : 16;
    if (_highCritMoves.contains(move.id)) {
      critChanceDenom = max(2, critChanceDenom ~/ 2);
    }
    if (attacker.hasFocusEnergy) {
      critChanceDenom = max(1, critChanceDenom ~/ 4);
    }

    double typeMultiplier = _applyIdentifiedTypeOverride(
      PokemonTypeExtension.getEffectiveness(move.type, _defensiveTypes(defender)),
      move.type,
      defender,
      bypassGhostWithScrappy: atkAb == 'scrappy',
    );

    final bool isCrit = !critBlocked &&
        typeMultiplier > 0 &&
        (move.id == 'storm_throw' || random.nextInt(critChanceDenom) == 0);

    // Attack & Defense stat selection (Psystrike / Psyshock hit Def!)
    final bool baseHitsPhysicalDef =
        move.category == MoveCategory.physical ||
        move.id == 'psystrike' ||
        move.id == 'psyshock';
    final bool wonderRoomSwapped = field != null && field.wonderRoomTurns > 0;
    final bool usePhysicalDefStat = wonderRoomSwapped ? !baseHitsPhysicalDef : baseHitsPhysicalDef;

    int attackStat;
    if (move.category == MoveCategory.physical) {
      attackStat = unawareDef
          ? attacker.combatBaseAtk
          : (isCrit && attacker.atkStage < 0 ? attacker.combatBaseAtk : attacker.effectiveAtk);
    } else {
      attackStat = unawareDef
          ? attacker.combatBaseSpa
          : (isCrit && attacker.spaStage < 0 ? attacker.combatBaseSpa : attacker.effectiveSpa);
    }
    if (isPlayer && playerTrainer != null) {
      final double badgeMult = move.category == MoveCategory.physical
          ? playerTrainer.atkBadgeMultiplier
          : playerTrainer.spaBadgeMultiplier;
      attackStat = (attackStat * badgeMult).round();
    }
    if (move.category == MoveCategory.physical) {
      if (atkAb == 'guts' && attacker.status != StatusCondition.none) {
        attackStat = (attackStat * 1.5).round();
      } else if (atkAb == 'hustle') {
        attackStat = (attackStat * 1.5).round();
      } else if (attacker.status == StatusCondition.burn && move.id != 'facade') {
        attackStat = (attackStat * 0.5).round().clamp(1, 9999);
      }
    } else if (atkAb == 'solar_power' && weather == BattleWeather.sun) {
      attackStat = (attackStat * 1.5).round();
    }

    int defenseStat = usePhysicalDefStat
        ? (unawareAtk
            ? defender.combatBaseDef
            : (isCrit && defender.defStage > 0 ? defender.combatBaseDef : defender.effectiveDef))
        : (unawareAtk
            ? defender.combatBaseSpd
            : (isCrit && defender.spdStage > 0 ? defender.combatBaseSpd : defender.effectiveSpd));
    if (defIsPlayer && playerTrainer != null) {
      final double badgeMult = baseHitsPhysicalDef
          ? playerTrainer.defBadgeMultiplier
          : playerTrainer.spdBadgeMultiplier;
      defenseStat = (defenseStat * badgeMult).round();
    }
    if (!bypassDefAb &&
        usePhysicalDefStat &&
        defAb == 'marvel_scale' &&
        defender.status != StatusCondition.none) {
      defenseStat = (defenseStat * 1.5).round();
    }
    if (!baseHitsPhysicalDef &&
        weather == BattleWeather.sandstorm &&
        defender.effectiveTypes.contains(PokemonType.rock)) {
      defenseStat = (defenseStat * 1.5).round();
    }

    final double base =
        (((2 * attacker.level / 5 + 2) * movePower * attackStat / max(1, defenseStat)) / 50) +
            2;
    final bool hasStab = attacker.effectiveTypes.contains(move.type);
    final double stab = hasStab ? (atkAb == 'adaptability' ? 2.0 : 1.5) : 1.0;

    final double crit = isCrit ? (atkAb == 'sniper' ? 2.25 : 1.5) : 1.0;
    final double randomVariance = (85 + random.nextInt(16)) / 100.0;
    final double heldItemMultiplier = _getHeldItemDamageMultiplier(attacker, move.type);

    double abilityDamageMult = 1.0;
    if (atkAb == 'tinted_lens' && typeMultiplier > 0 && typeMultiplier < 1.0) {
      abilityDamageMult *= 2.0;
    }
    if (!bypassDefAb) {
      if (defAb == 'thick_fat' &&
          (move.type == PokemonType.fire || move.type == PokemonType.ice)) {
        abilityDamageMult *= 0.5;
      }
      if (defAb == 'filter' && typeMultiplier >= 2.0) {
        abilityDamageMult *= 0.75;
      }
      if (defAb == 'multiscale' && defender.currentHp >= defender.maxHp) {
        abilityDamageMult *= 0.5;
      }
      if (defAb == 'friend_guard') {
        abilityDamageMult *= 0.85;
      }
      if (allyHasFriendGuard) {
        abilityDamageMult *= 0.75;
      }
      if (defAb == 'dry_skin' && move.type == PokemonType.fire) {
        abilityDamageMult *= 1.25;
      }
    }

    // Weather damage multipliers
    double weatherMult = 1.0;
    if (weather == BattleWeather.sun) {
      if (move.type == PokemonType.fire) weatherMult = 1.5;
      if (move.type == PokemonType.water) weatherMult = 0.5;
    } else if (weather == BattleWeather.rain) {
      if (move.type == PokemonType.water) weatherMult = 1.5;
      if (move.type == PokemonType.fire) weatherMult = 0.5;
    }

    // Screens (Reflect / Light Screen) bypassed by Critical Hit, Brick Break, or Infiltrator
    double screenMult = 1.0;
    if (field != null && !isCrit && atkAb != 'infiltrator' && move.id != 'brick_break') {
      final defSide = field.sideFor(defIsPlayer);
      final double screenFactor = isDoubleBattleScreen ? (2.0 / 3.0) : 0.5;
      if (baseHitsPhysicalDef && defSide.reflectTurns > 0) screenMult = screenFactor;
      if (!baseHitsPhysicalDef && defSide.lightScreenTurns > 0) screenMult = screenFactor;
    }

    int damage = (base *
            crit *
            randomVariance *
            stab *
            typeMultiplier *
            heldItemMultiplier *
            abilityDamageMult *
            weatherMult *
            screenMult *
            extraMultiplier)
        .floor();
    if (damage < 1 && typeMultiplier > 0) damage = 1;
    if (typeMultiplier == 0.0) damage = 0;

    return (damage: damage, isCrit: isCrit, typeMultiplier: typeMultiplier);
  }

  static bool _hasSheerForceBoost(Move move) =>
      (move.statusChance > 0 && move.statusEffect != null) ||
      (_flinchChances[move.id] ?? 0) > 0 ||
      move.id == 'tri_attack' ||
      move.id == 'ancient_power' ||
      move.id == 'silver_wind' ||
      (_damagingStatEffects.containsKey(move.id) &&
          _damagingStatEffects[move.id]!.delta != 0 &&
          !_damagingStatEffects[move.id]!.self);

  static void _applyJumpKickCrashIfApplicable(
    Move move,
    PokemonInstance attacker,
    String attackerName,
    bool isPlayer,
    List<BattleStepEvent> events,
  ) {
    if ((move.id != 'jump_kick' && move.id != 'high_jump_kick') ||
        attacker.isFainted ||
        attacker.effectiveAbilityId == 'magic_guard') {
      return;
    }
    final int crashDmg = max(1, attacker.maxHp ~/ 2);
    attacker.currentHp = (attacker.currentHp - crashDmg).clamp(0, attacker.maxHp);
    events.add(BattleStepEvent(
      message: "$attackerName kept going and crashed!",
      isPlayerActor: isPlayer,
      moveType: move.type,
      damageDealt: crashDmg,
      targetHpAfter: attacker.currentHp,
      targetFainted: attacker.isFainted,
      isSelfDamage: true,
      hideMoveVfx: true,
    ));
    if (attacker.isFainted) {
      events.add(BattleStepEvent(
        message: "$attackerName fainted!",
        isPlayerActor: !isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }
  }

  // ─── SINGLE ATTACK EXECUTION ────────────────────────────────────────────────
  static List<BattleStepEvent> executeSingleAttack(
    PokemonInstance attacker,
    Move move,
    PokemonInstance defender, {
    required bool isPlayer,
    bool? defenderIsPlayer,
    bool isWild = true,
    Trainer? playerTrainer,
    BattleFieldState? field,
    Move? defenderIntendedMove,
    Random? rng,
    bool consumePp = true,
    bool isSubMove = false,
    int? powerOverride,
    double spreadDamageMultiplier = 1.0,
    bool isDoubleBattleScreen = false,
    bool allyHasFriendGuard = false,
    bool skipLifeOrbRecoil = false,
    bool clearHelpingHandAfter = true,
    bool deferSelfKo = false,
  }) {
    final random = rng ?? _rng;
    final activeField = field ?? BattleFieldState();
    final List<BattleStepEvent> events = [];
    if (attacker.isFainted || defender.isFainted) return events;
    final bool defIsPlayer = defenderIsPlayer ?? !isPlayer;
    final attackerName = _labelFor(attacker, isPlayer, isWild);
    final defenderName = _labelFor(defender, defIsPlayer, isWild);
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = defender.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';

    if (!isSubMove) {
      // 0. Mandatory Recharge Turn
      if (attacker.needsRecharge) {
        attacker.needsRecharge = false;
        events.add(BattleStepEvent(
          message: "$attackerName must recharge!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
        return events;
      }

      // 0a. Flinch check
      if (attacker.flinchedThisTurn) {
        attacker.flinchedThisTurn = false;
        _clearMoveLocks(attacker);
        events.add(BattleStepEvent(
          message: "$attackerName flinched and couldn't move!",
          isPlayerActor: isPlayer,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }

      // 0b. Taunt / Disable / Torment / Imprison guards
      if (attacker.isTaunted && move.category == MoveCategory.status) {
        events.add(BattleStepEvent(
          message: "$attackerName can't use ${move.name} after the taunt!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
        return events;
      }
      if (attacker.disableTurnsRemaining > 0 && attacker.disabledMoveId == move.id) {
        events.add(BattleStepEvent(
          message: "$attackerName's ${move.name} is disabled!",
          isPlayerActor: isPlayer,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
      if (attacker.isTormented &&
          attacker.lastMoveUsedId == move.id &&
          move.id != 'struggle') {
        events.add(BattleStepEvent(
          message: "$attackerName can't use the same move twice in a row due to Torment!",
          isPlayerActor: isPlayer,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
      if (defender.isImprisoning &&
          move.id != 'struggle' &&
          defender.activeMoves.any((m) => m.id == move.id)) {
        events.add(BattleStepEvent(
          message: "$attackerName can't use its sealed ${move.name}!",
          isPlayerActor: isPlayer,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }

      // 1. Pre-move status check (Sleep / Freeze / Paralysis / Confusion)
      if (attacker.status == StatusCondition.sleep) {
        if (attacker.sleepTurnsRemaining <= 0) {
          attacker.sleepTurnsRemaining = 2 + random.nextInt(3);
        }
        final int step = atkAb == 'early_bird' ? 2 : 1;
        attacker.sleepTurnsRemaining = max(0, attacker.sleepTurnsRemaining - step);
        if (attacker.sleepTurnsRemaining <= 0) {
          attacker.status = StatusCondition.none;
          events.add(BattleStepEvent(
            message: "$attackerName woke up!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
          ));
        } else if (move.id != 'snore' && move.id != 'sleep_talk') {
          _clearMoveLocks(attacker);
          events.add(BattleStepEvent(
            message: "$attackerName is fast asleep!",
            isPlayerActor: isPlayer,
            isMiss: true,
            hideMoveVfx: true,
          ));
          return events;
        }
      } else if (attacker.status == StatusCondition.freeze) {
        if (move.type == PokemonType.fire || random.nextInt(5) == 0) {
          attacker.status = StatusCondition.none;
          events.add(BattleStepEvent(
            message: "$attackerName thawed out!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
          ));
        } else {
          _clearMoveLocks(attacker);
          events.add(BattleStepEvent(
            message: "$attackerName is frozen solid!",
            isPlayerActor: isPlayer,
            isMiss: true,
            hideMoveVfx: true,
          ));
          return events;
        }
      } else if (attacker.status == StatusCondition.paralysis) {
        if (random.nextInt(4) == 0) {
          _clearMoveLocks(attacker);
          events.add(BattleStepEvent(
            message: "$attackerName is paralyzed! It can't move!",
            isPlayerActor: isPlayer,
            isMiss: true,
            hideMoveVfx: true,
          ));
          return events;
        }
      }

      if (attacker.isConfused) {
        attacker.confusionTurnsRemaining--;
        if (attacker.confusionTurnsRemaining <= 0) {
          attacker.isConfused = false;
          events.add(BattleStepEvent(
            message: "$attackerName snapped out of its confusion!",
            isPlayerActor: isPlayer,
            hideMoveVfx: true,
          ));
        } else if (random.nextInt(3) == 0) {
          _clearMoveLocks(attacker);
          final double rawSelf =
              (((2 * attacker.level / 5 + 2) * 40 * attacker.effectiveAtk / attacker.effectiveDef) /
                      50) +
                  2;
          final int selfDmg = max(1, rawSelf.floor());
          attacker.currentHp = (attacker.currentHp - selfDmg).clamp(0, attacker.maxHp);
          events.add(BattleStepEvent(
            message: "$attackerName hurt itself in its confusion!",
            isPlayerActor: isPlayer,
            moveType: PokemonType.normal,
            damageDealt: selfDmg,
            targetHpAfter: attacker.currentHp,
            targetFainted: attacker.isFainted,
            isSelfDamage: true,
            hideMoveVfx: true,
          ));
          if (attacker.isFainted) {
            events.add(BattleStepEvent(
              message: "$attackerName fainted!",
              isPlayerActor: !isPlayer,
              targetHpAfter: 0,
              targetFainted: true,
            ));
          }
          return events;
        }
      }

      // Focus Punch check if hit earlier in turn
      if (move.id == 'focus_punch' && attacker.lastDamageTakenThisTurn > 0) {
        events.add(BattleStepEvent(
          message: "$attackerName lost its focus and couldn't move!",
          isPlayerActor: isPlayer,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
    }

    // 2. Multi-stage turn check
    final bool isContinuingCharge = attacker.chargingMoveId == move.id;
    final bool isContinuingBide = attacker.bideTurnsRemaining > 0;
    final bool isContinuingRampage =
        attacker.rampageMoveId == move.id && attacker.rampageTurnsRemaining > 0;
    final bool isContinuingRollout =
        move.stageMechanic == MoveStageMechanic.escalatingRoll &&
        attacker.rolloutTurnsRemaining > 0;

    final String? previousMoveUsedId = attacker.lastMoveUsedId;
    if (!isSubMove &&
        !isContinuingCharge &&
        !isContinuingBide &&
        !isContinuingRampage &&
        !isContinuingRollout) {
      attacker.hasDestinyBond = false;
      attacker.hasGrudge = false;
      if (consumePp && move.currentPp > 0) {
        final int ppCost = (!bypassDefAb && defAb == 'pressure') ? 2 : 1;
        move.currentPp = max(0, move.currentPp - ppCost);
      }
      attacker.lastMoveUsedId = move.id;
      if (move.id != 'fury_cutter') {
        attacker.consecutiveFuryCutterHits = 0;
      }
    }

    if (!isSubMove &&
        move.id != 'protect' &&
        move.id != 'detect' &&
        move.id != 'endure' &&
        move.id != 'quick_guard' &&
        move.id != 'wide_guard') {
      attacker.consecutiveProtectCount = 0;
    }

    // Prerequisite checks for conditional moves
    if (move.id == 'dream_eater' && defender.status != StatusCondition.sleep) {
      events.add(BattleStepEvent(
        message:
            "$attackerName used ${move.name}! But it failed because $defenderName isn't asleep!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }
    if (move.id == 'snore' && attacker.status != StatusCondition.sleep) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! But it failed!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }
    if (move.id == 'fake_out' && attacker.turnsActiveInBattle > 0) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! But it failed!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }
    if (move.id == 'last_resort' &&
        (previousMoveUsedId == null || previousMoveUsedId == 'last_resort')) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! But it failed!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }
    if (move.id == 'fling' && !attacker.hasHeldItem) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! But it had no item to throw!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }
    if (move.id == 'natural_gift') {
      final heldObj = attacker.hasHeldItem ? ItemDatabase.byId(attacker.heldItemId!) : null;
      if (heldObj == null || !heldObj.isBerry) {
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}! But it has no Berry!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
    }
    if ((move.id == 'spit_up' || move.id == 'swallow') &&
        attacker.stockpileCount <= 0) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! But it hadn't stockpiled any power!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        hideMoveVfx: true,
      ));
      return events;
    }

    // Sleep Talk picks another move cleanly (never itself, Rest, or uncallable moves)
    if (move.id == 'sleep_talk') {
      if (isSubMove || attacker.status != StatusCondition.sleep) {
        events.add(BattleStepEvent(
          message: "$attackerName used Sleep Talk, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
          targetHpAfter: defender.currentHp,
        ));
        return events;
      }
      final candidates = _sleepTalkCandidates(attacker)
          .where((m) => m.id != move.id)
          .toList();
      if (candidates.isEmpty) {
        events.add(BattleStepEvent(
          message: "$attackerName used Sleep Talk, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
          targetHpAfter: defender.currentHp,
        ));
        return events;
      }
      final picked = candidates[random.nextInt(candidates.length)];
      events.add(BattleStepEvent(
        message: "$attackerName used Sleep Talk! (${picked.name})",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statTargetIsSelf: true,
      ));
      events.addAll(executeSingleAttack(
        attacker,
        picked.copy(),
        defender,
        isPlayer: isPlayer,
        isWild: isWild,
        playerTrainer: playerTrainer,
        field: activeField,
        defenderIntendedMove: defenderIntendedMove,
        consumePp: false,
        isSubMove: true,
        rng: random,
      ));
      return events;
    }

    if (move.id == 'synchronoise' &&
        !attacker.effectiveTypes.any((t) => _defensiveTypes(defender).contains(t))) {
      events.add(BattleStepEvent(
        message: "$attackerName used Synchronoise! It doesn't affect $defenderName...",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        effectiveness: 0.0,
        isMiss: true,
        targetHpAfter: defender.currentHp,
      ));
      return events;
    }

    // Sucker Punch prerequisite
    if (move.id == 'sucker_punch') {
      final bool foeAttacking = defenderIntendedMove != null &&
          defenderIntendedMove.category != MoveCategory.status;
      if (!foeAttacking) {
        events.add(BattleStepEvent(
          message: "$attackerName used Sucker Punch, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
        ));
        return events;
      }
    }

    // Future Sight: foresee attack on target's side, striking 2 turns later (end of turn T+2)
    if (move.id == 'future_sight') {
      final targetSide = activeField.sideFor(!isPlayer);
      if (targetSide.futureSightTurns > 0) {
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}! But it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
      targetSide.futureSightTurns = 3;
      targetSide.futureSightAttacker = attacker;
      targetSide.futureSightFromPlayer = isPlayer;
      targetSide.futureSightMove = move.copy();
      events.add(BattleStepEvent(
        message: "$attackerName foresaw an attack!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statTargetIsSelf: true,
        isChargeTurn: true,
      ));
      return events;
    }

    // Damp blocks Self-Destruct & Explosion
    final bool isSelfKoMove = move.id == 'self_destruct' || move.id == 'explosion';
    if (isSelfKoMove &&
        ((!bypassDefAb && defAb == 'damp') || atkAb == 'damp')) {
      events.add(BattleStepEvent(
        message: "Damp prevented $attackerName from using ${move.name}!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
        abilityTriggeredName: 'Damp',
      ));
      return events;
    }

    void appendSelfKoEventsIfNeeded() {
      if (deferSelfKo) return;
      if (!isSelfKoMove && move.id != 'memento' && move.id != 'healing_wish') {
        return;
      }
      if (attacker.isFainted) return;
      final int selfCost = attacker.currentHp;
      attacker.currentHp = 0;
      _clearMoveLocks(attacker);
      events.add(BattleStepEvent(
        message: "$attackerName fainted from ${move.name}!",
        isPlayerActor: isPlayer,
        moveType: move.type,
        damageDealt: selfCost,
        targetHpAfter: 0,
        targetFainted: true,
        isSelfDamage: true,
        hideMoveVfx: true,
      ));
      events.add(BattleStepEvent(
        message: "$attackerName fainted!",
        isPlayerActor: !isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }

    // Protect / Detect / Endure
    if (move.id == 'protect' || move.id == 'detect' || move.id == 'endure') {
      final double successProb = 1.0 / pow(2, attacker.consecutiveProtectCount).toDouble();
      if (random.nextDouble() < successProb) {
        attacker.consecutiveProtectCount++;
        if (move.id == 'endure') {
          attacker.isEnduringThisTurn = true;
          events.add(BattleStepEvent(
            message: "$attackerName braced itself!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            statusInflictedLabel: 'ENDURE',
          ));
        } else {
          attacker.isProtectedThisTurn = true;
          events.add(BattleStepEvent(
            message: "$attackerName protected itself!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            statusInflictedLabel: 'PROTECTED',
          ));
        }
      } else {
        attacker.consecutiveProtectCount = 0;
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
        ));
      }
      return events;
    }

    // Bide handling
    if (move.stageMechanic == MoveStageMechanic.bide) {
      if (!isContinuingBide) {
        attacker.bideTurnsRemaining = 2;
        attacker.bideDamageStored = 0;
        events.add(BattleStepEvent(
          message: "$attackerName is storing energy!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          isChargeTurn: true,
          statusInflictedLabel: 'BIDE!',
        ));
        return events;
      }
      if (attacker.bideTurnsRemaining > 1) {
        attacker.bideTurnsRemaining--;
        events.add(BattleStepEvent(
          message: "$attackerName is still storing energy!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          isChargeTurn: true,
          statusInflictedLabel: 'STORING',
        ));
        return events;
      }
      attacker.bideTurnsRemaining = 0;
      final int unleashedDmg = max(0, attacker.bideDamageStored * 2);
      attacker.bideDamageStored = 0;
      if (unleashedDmg <= 0 || defender.isUnderground || defender.isProtectedThisTurn) {
        events.add(BattleStepEvent(
          message: "$attackerName unleashed energy, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
        ));
        return events;
      }
      defender.currentHp = (defender.currentHp - unleashedDmg).clamp(0, defender.maxHp);
      defender.lastDamageTakenThisTurn += unleashedDmg;
      events.add(BattleStepEvent(
        message: "$attackerName unleashed energy!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: unleashedDmg,
        targetHpAfter: defender.currentHp,
        targetFainted: defender.isFainted,
      ));
      if (!defender.isFainted) {
        final berryEv = checkAndConsumeHeldBerry(defender,
            opponent: attacker, isPlayer: !isPlayer, isWild: isWild);
        if (berryEv != null) events.add(berryEv);
      } else {
        events.add(BattleStepEvent(
          message: "$defenderName fainted!",
          isPlayerActor: isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
      return events;
    }

    // Two-turn Charge / Semi-invulnerable Turn 1 (Solar Beam skips charge in Sun!)
    final weatherNow = activeField.effectiveWeather(attacker, defender);
    final bool sunSkipSolarBeam = move.id == 'solar_beam' && weatherNow == BattleWeather.sun;
    if (!isContinuingCharge && move.isTwoTurnCharge && !sunSkipSolarBeam) {
      attacker.chargingMoveId = move.id;
      final bool goSub = move.stageMechanic == MoveStageMechanic.semiInvulnerable;
      if (goSub) attacker.isUnderground = true;
      String chargeMsg =
          "$attackerName ${move.chargeStatusMessage ?? 'is charging power!'}";
      String? statLabel;
      if (move.chargeSelfStatTarget != null && move.chargeSelfStatChange != 0) {
        final delta = attacker.modifyStatStage(
          move.chargeSelfStatTarget!,
          move.chargeSelfStatChange,
        );
        statLabel = "${move.chargeSelfStatTarget!.toUpperCase()} ▲";
        if (delta != 0) {
          chargeMsg = "$chargeMsg $attackerName's ${_statDisplayName(move.chargeSelfStatTarget!)} rose!";
        }
      }
      events.add(BattleStepEvent(
        message: chargeMsg,
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statChangedLabel: statLabel,
        statTargetIsSelf: true,
        isChargeTurn: true,
        submergeActorAfter: goSub,
      ));
      return events;
    }

    bool surfacedThisTurn = false;
    if (isContinuingCharge) {
      attacker.chargingMoveId = null;
      if (attacker.isUnderground) {
        attacker.isUnderground = false;
        surfacedThisTurn = true;
      }
    }

    if (move.stageMechanic == MoveStageMechanic.rampage && !isContinuingRampage) {
      attacker.rampageMoveId = move.id;
      attacker.rampageTurnsRemaining = 2 + random.nextInt(2);
    }
    if (move.stageMechanic == MoveStageMechanic.escalatingRoll && !isContinuingRollout) {
      attacker.rolloutTurnsRemaining = 5;
      attacker.rolloutHitCount = 0;
    }

    // Protect check (Feint breaks Protect!)
    if (defender.isProtectedThisTurn && move.id != 'feint') {
      final bool selfStatus =
          move.category == MoveCategory.status &&
          ((move.statChange > 0 && move.statTarget != null) ||
              move.id == 'recover' || move.id == 'soft_boiled' || move.id == 'rest' ||
              move.id == 'roost' || move.id == 'slack_off' || move.id == 'synthesis' ||
              move.id == 'moonlight' || move.id == 'morning_sun' || move.id == 'belly_drum' ||
              move.id == 'substitute' || move.id == 'focus_energy' || move.id == 'acupressure' ||
              move.id == 'wonder_room' || move.id == 'recycle' || move.id == 'conversion' ||
              move.id == 'conversion_2' || move.id == 'camouflage' || move.id == 'reflect_type' ||
              move.id == 'rain_dance' || move.id == 'sunny_day' ||
              move.id == 'sandstorm' || move.id == 'hail' ||
              move.id == 'charge' || move.id == 'healing_wish' || move.id == 'magic_coat' ||
              move.id == 'imprison' || move.id == 'grudge' || move.id == 'baton_pass' ||
              move.id == 'helping_hand' || move.id == 'after_you' || move.id == 'ally_switch' ||
              _multiStatMoves.containsKey(move.id));
      if (!selfStatus) {
        _clearMoveLocks(attacker);
        attacker.consecutiveFuryCutterHits = 0;
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}! $defenderName protected itself!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        _applyJumpKickCrashIfApplicable(move, attacker, attackerName, isPlayer, events);
        return events;
      }
    }

    if (move.id == 'feint' && defender.isProtectedThisTurn) {
      defender.isProtectedThisTurn = false;
    }

    // Underground / Semi-invulnerable evasion
    if (defender.isUnderground &&
        move.id != 'earthquake' &&
        move.id != 'magnitude' &&
        atkAb != 'no_guard' &&
        defAb != 'no_guard') {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}, but $defenderName avoided it!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        isMiss: true,
        surfaceActorOnAttack: surfacedThisTurn,
      ));
      return events;
    }

    // Ability-based move immunities (Soundproof, Overcoat, Levitate, Flash Fire, Water/Volt Absorb, Dry Skin, Lightning Rod)
    if (!bypassDefAb) {
      if (defAb == 'soundproof' && _soundMoves.contains(move.id)) {
        events.add(BattleStepEvent(
          message: "$defenderName's Soundproof blocked ${move.name}!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          effectiveness: 0.0,
          hideMoveVfx: true,
          abilityTriggeredName: 'Soundproof',
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (defAb == 'overcoat' && _powderMoves.contains(move.id)) {
        events.add(BattleStepEvent(
          message: "$defenderName's Overcoat blocked ${move.name}!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Overcoat',
        ));
        return events;
      }
      if (move.type == PokemonType.ground &&
          move.category != MoveCategory.status &&
          !_isGrounded(defender, activeField)) {
        events.add(BattleStepEvent(
          message:
              "$attackerName used ${move.name}! It doesn't affect $defenderName...",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          effectiveness: 0.0,
          abilityTriggeredName: defAb == 'levitate' ? 'Levitate' : null,
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (move.type == PokemonType.fire &&
          defAb == 'flash_fire' &&
          move.id != 'will_o_wisp') {
        defender.flashFireBoosted = true;
        events.add(BattleStepEvent(
          message: "$defenderName's Flash Fire absorbed the Fire attack!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Flash Fire',
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (move.type == PokemonType.fire &&
          move.id == 'will_o_wisp' &&
          defAb == 'flash_fire') {
        defender.flashFireBoosted = true;
        events.add(BattleStepEvent(
          message: "$defenderName's Flash Fire absorbed Will-O-Wisp!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: 'Flash Fire',
        ));
        return events;
      }
      if (move.type == PokemonType.water &&
          move.category != MoveCategory.status &&
          (defAb == 'water_absorb' || defAb == 'dry_skin')) {
        final heal = min(max(1, defender.maxHp ~/ 4), defender.maxHp - defender.currentHp);
        defender.currentHp += heal;
        events.add(BattleStepEvent(
          message: heal > 0
              ? "$defenderName restored HP with ${AbilityDatabase.nameOf(defAb)}!"
              : "$defenderName absorbed the Water move cleanly!",
          isPlayerActor: !isPlayer,
          healAmount: heal,
          targetHpAfter: defender.currentHp,
          isStatusTick: heal > 0,
          hideMoveVfx: heal <= 0,
          abilityTriggeredName: AbilityDatabase.nameOf(defAb),
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (move.type == PokemonType.electric &&
          move.category != MoveCategory.status &&
          defAb == 'volt_absorb') {
        final heal = min(max(1, defender.maxHp ~/ 4), defender.maxHp - defender.currentHp);
        defender.currentHp += heal;
        events.add(BattleStepEvent(
          message: heal > 0
              ? "$defenderName restored HP with Volt Absorb!"
              : "$defenderName absorbed the Electric move!",
          isPlayerActor: !isPlayer,
          healAmount: heal,
          targetHpAfter: defender.currentHp,
          isStatusTick: heal > 0,
          hideMoveVfx: heal <= 0,
          abilityTriggeredName: 'Volt Absorb',
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (move.type == PokemonType.electric && defAb == 'lightning_rod') {
        defender.modifyStatStage('spa', 1);
        events.add(BattleStepEvent(
          message: "$defenderName's Lightning Rod absorbed the electricity and raised Sp. Atk!",
          isPlayerActor: defIsPlayer,
          statChangedLabel: 'SPA ▲',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Lightning Rod',
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
      if (move.type == PokemonType.water &&
          move.category != MoveCategory.status &&
          defAb == 'storm_drain') {
        defender.modifyStatStage('spa', 1);
        events.add(BattleStepEvent(
          message: "$defenderName's Storm Drain drew in the water and raised Sp. Atk!",
          isPlayerActor: defIsPlayer,
          statChangedLabel: 'SPA ▲',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Storm Drain',
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        return events;
      }
    }

    // 3. Accuracy Check (accounting for Abilities, Weather, Never-Miss Moves, Lock-On)
    const Set<String> neverMissMoves = {
      'swift', 'shock_wave', 'aerial_ace', 'feint_attack', 'magical_leaf',
      'aura_sphere', 'magnet_bomb', 'shadow_punch', 'vital_throw', 'clear_smog',
      'trump_card', 'roost', 'recover', 'soft_boiled', 'rest', 'slack_off',
      'synthesis', 'moonlight', 'morning_sun', 'haze', 'belly_drum', 'refresh',
      'aromatherapy', 'rain_dance', 'sunny_day', 'sandstorm', 'hail', 'safeguard',
      'mist', 'tailwind', 'spikes', 'toxic_spikes', 'stealth_rock', 'gravity',
      'lucky_chant', 'substitute', 'splash', 'focus_energy', 'destiny_bond',
      'perish_song', 'magnet_rise', 'aqua_ring', 'ingrain', 'mean_look', 'block',
      'curse', 'mirror_move', 'copycat', 'metronome', 'mimic', 'transform',
      'conversion', 'conversion_2', 'camouflage', 'reflect_type', 'psych_up',
      'shell_smash', 'quiver_dance', 'calm_mind', 'dragon_dance', 'coil',
      'work_up', 'cosmic_power', 'growth', 'nasty_plot', 'rock_polish',
      'barrier', 'amnesia', 'iron_defense', 'minimize', 'stockpile', 'swallow',
      'acupressure', 'power_swap', 'guard_swap', 'mud_sport', 'water_sport',
      'wonder_room', 'recycle', 'lock_on', 'mind_reader', 'foresight',
      'odor_sleuth', 'miracle_eye', 'quick_guard', 'wide_guard', 'teleport',
      'charge', 'healing_wish', 'magic_coat', 'imprison', 'grudge', 'baton_pass',
      'helping_hand', 'follow_me', 'after_you', 'ally_switch', 'sleep_talk',
      'swords_dance', 'harden', 'agility', 'double_team', 'meditate',
      'defense_curl', 'light_screen', 'reflect', 'withdraw', 'acid_armor',
    };
    final bool noGuard = atkAb == 'no_guard' || defAb == 'no_guard';
    final bool sureHit = defender.sureHitAgainstTurns > 0;
    if (sureHit) {
      defender.sureHitAgainstTurns = 0;
    }
    final bool bypassAcc = noGuard ||
        sureHit ||
        neverMissMoves.contains(move.id) ||
        (move.category == MoveCategory.status && move.statTarget != null && move.statChange > 0);

    if (!bypassAcc) {
      double baseAcc = move.accuracy.toDouble();
      if ((move.id == 'thunder' || move.id == 'hurricane')) {
        if (weatherNow == BattleWeather.rain) baseAcc = 100.0;
        if (weatherNow == BattleWeather.sun) baseAcc = 50.0;
      } else if (move.id == 'blizzard' && weatherNow == BattleWeather.hail) {
        baseAcc = 100.0;
      }
      if (!bypassDefAb && defAb == 'wonder_skin' && move.category == MoveCategory.status) {
        baseAcc = min(baseAcc, 50.0);
      }
      double mod = 1.0;
      if (atkAb == 'compound_eyes') mod *= 1.3;
      if (atkAb == 'hustle' && move.category == MoveCategory.physical) mod *= 0.8;
      if (!bypassDefAb) {
        if (defAb == 'tangled_feet' && defender.isConfused) mod *= 0.5;
        if (defAb == 'sand_veil' && weatherNow == BattleWeather.sandstorm) mod *= 0.8;
        if (defAb == 'snow_cloak' && weatherNow == BattleWeather.hail) mod *= 0.8;
      }
      final double defEvaMult =
          (defender.isIdentified && defender.evaStage > 0) ? 1.0 : defender.evasionMultiplier;
      final double effAcc =
          (baseAcc * mod * attacker.accuracyMultiplier * defEvaMult)
              .clamp(1.0, 100.0);
      if (random.nextDouble() * 100.0 >= effAcc) {
        _clearMoveLocks(attacker);
        attacker.consecutiveFuryCutterHits = 0;
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}, but it missed!",
          isPlayerActor: isPlayer,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          surfaceActorOnAttack: surfacedThisTurn,
        ));
        _applyJumpKickCrashIfApplicable(move, attacker, attackerName, isPlayer, events);
        appendSelfKoEventsIfNeeded();
        return events;
      }
    }

    // 4. Status / Fixed-Damage / Utility Moves
    if (move.category == MoveCategory.status) {
      if (!isSubMove && defender.hasMagicCoatThisTurn) {
        const selfOrFieldStatusMoves = {
          'rain_dance', 'sunny_day', 'sandstorm', 'hail', 'gravity', 'wonder_room',
          'mud_sport', 'water_sport', 'haze', 'reflect', 'light_screen', 'safeguard',
          'mist', 'tailwind', 'lucky_chant', 'protect', 'detect', 'endure',
          'quick_guard', 'wide_guard', 'magic_coat', 'substitute', 'recover',
          'soft_boiled', 'rest', 'roost', 'slack_off', 'synthesis', 'moonlight',
          'morning_sun', 'swallow', 'stockpile', 'belly_drum', 'focus_energy',
          'acupressure', 'psych_up', 'power_swap', 'guard_swap', 'recycle',
          'refresh', 'aromatherapy', 'ingrain', 'aqua_ring', 'magnet_rise',
          'destiny_bond', 'perish_song', 'imprison', 'grudge', 'baton_pass',
          'helping_hand', 'after_you', 'ally_switch', 'follow_me', 'charge',
          'healing_wish', 'splash', 'teleport', 'conversion', 'conversion_2',
          'camouflage', 'reflect_type', 'transform', 'mimic', 'metronome',
          'copycat', 'mirror_move', 'me_first', 'sleep_talk',
        };
        final bool isSelfBuffStatus =
            (move.statTarget != null && move.statChange > 0) ||
                (_multiStatMoves.containsKey(move.id) &&
                    move.id != 'tickle' &&
                    move.id != 'memento') ||
                (move.id == 'curse' &&
                    !attacker.effectiveTypes.contains(PokemonType.ghost));
        if (!selfOrFieldStatusMoves.contains(move.id) && !isSelfBuffStatus) {
          defender.hasMagicCoatThisTurn = false;
          events.add(BattleStepEvent(
            message: "$defenderName bounced ${move.name} back with Magic Coat!",
            isPlayerActor: !isPlayer,
            moveId: 'magic_coat',
            moveType: PokemonType.psychic,
            moveCategory: MoveCategory.status,
            statTargetIsSelf: true,
          ));
          events.addAll(executeSingleAttack(
            defender,
            move.copy(),
            attacker,
            isPlayer: !isPlayer,
            isWild: isWild,
            playerTrainer: playerTrainer,
            field: activeField,
            consumePp: false,
            isSubMove: true,
            rng: random,
          ));
          return events;
        }
      }
      return _executeStatusMove(
        attacker: attacker,
        move: move,
        defender: defender,
        isPlayer: isPlayer,
        defenderIsPlayer: defIsPlayer,
        isWild: isWild,
        playerTrainer: playerTrainer,
        defenderIntendedMove: defenderIntendedMove,
        field: activeField,
        random: random,
        appendSelfKo: appendSelfKoEventsIfNeeded,
      );
    }

    // Fixed / Special HP-formula damaging moves
    const Set<String> specialFormulaMoveIds = {
      'dragon_rage',
      'sonic_boom',
      'seismic_toss',
      'night_shade',
      'super_fang',
      'endeavor',
      'final_gambit',
      'guillotine',
      'horn_drill',
      'fissure',
      'sheer_cold',
      'psywave',
      'counter',
      'mirror_coat',
    };
    if (specialFormulaMoveIds.contains(move.id)) {
      return _executeSpecialFormulaAttack(
        attacker: attacker,
        move: move,
        defender: defender,
        isPlayer: isPlayer,
        defenderIsPlayer: defIsPlayer,
        isWild: isWild,
        surfacedThisTurn: surfacedThisTurn,
        random: random,
        field: activeField,
      );
    }

    // 5. Damaging Multi-Hit / Standard Moves
    final int hitCount = _rollHitCount(attacker, move, random);
    int? resolvedPowerOverride = powerOverride;
    if (resolvedPowerOverride == null && move.stageMechanic == MoveStageMechanic.escalatingRoll) {
      resolvedPowerOverride = 30 * pow(2, attacker.rolloutHitCount.clamp(0, 4)).toInt();
    } else if (resolvedPowerOverride == null && move.id == 'magnitude') {
      final int r = random.nextInt(100);
      final int magLevel;
      final int magPower;
      if (r < 5) {
        magLevel = 4;
        magPower = 10;
      } else if (r < 15) {
        magLevel = 5;
        magPower = 30;
      } else if (r < 35) {
        magLevel = 6;
        magPower = 50;
      } else if (r < 65) {
        magLevel = 7;
        magPower = 70;
      } else if (r < 85) {
        magLevel = 8;
        magPower = 90;
      } else if (r < 95) {
        magLevel = 9;
        magPower = 110;
      } else {
        magLevel = 10;
        magPower = 150;
      }
      resolvedPowerOverride = magPower;
      events.add(BattleStepEvent(
        message: "Magnitude $magLevel!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
    }
    int totalDamageDealt = 0;
    int actualHits = 0;
    final bool sheerForceBlocksSec = atkAb == 'sheer_force' && _hasSheerForceBoost(move);

    for (int hit = 1; hit <= hitCount; hit++) {
      final hitResult = _computeHitDamage(
        attacker: attacker,
        move: move,
        defender: defender,
        isPlayer: isPlayer,
        defenderIsPlayer: defIsPlayer,
        playerTrainer: playerTrainer,
        random: random,
        field: activeField,
        powerOverride: resolvedPowerOverride,
        extraMultiplier:
            (isSelfKoMove ? 2.0 : 1.0) * spreadDamageMultiplier,
        isDoubleBattleScreen: isDoubleBattleScreen,
        allyHasFriendGuard: allyHasFriendGuard,
      );

      if (hitResult.typeMultiplier == 0.0) {
        _clearMoveLocks(attacker);
        attacker.consecutiveFuryCutterHits = 0;
        events.add(BattleStepEvent(
          message:
              "$attackerName used ${move.name}! It doesn't affect $defenderName...",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          effectiveness: 0.0,
          targetHpAfter: defender.currentHp,
          surfaceActorOnAttack: hit == 1 && surfacedThisTurn,
        ));
        _applyJumpKickCrashIfApplicable(move, attacker, attackerName, isPlayer, events);
        appendSelfKoEventsIfNeeded();
        return events;
      }

      if (defender.substituteHp > 0 &&
          atkAb != 'infiltrator' &&
          !_soundMoves.contains(move.id)) {
        defender.substituteHp = max(0, defender.substituteHp - hitResult.damage);
        final bool broke = defender.substituteHp <= 0;
        actualHits = hit;
        events.add(BattleStepEvent(
          message: broke
              ? "${hit == 1 ? '$attackerName used ${move.name}! ' : ''}$defenderName's substitute broke!"
              : "${hit == 1 ? '$attackerName used ${move.name}! ' : ''}The substitute took the damage for $defenderName!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          damageDealt: 0,
          targetHpAfter: defender.currentHp,
          isCrit: hitResult.isCrit,
          effectiveness: hitResult.typeMultiplier,
          statusInflictedLabel: broke ? 'SUB BROKE!' : 'SUBSTITUTE!',
          hitNumber: hitCount > 1 ? hit : 0,
          totalHits: hitCount > 1 ? hitCount : 0,
          surfaceActorOnAttack: hit == 1 && surfacedThisTurn,
        ));
        continue;
      }

      int dealtDamage = hitResult.damage;
      bool sturdySaved = false;
      bool enduredHit = false;
      if (dealtDamage >= defender.currentHp) {
        if (move.id == 'false_swipe' || defender.isEnduringThisTurn) {
          dealtDamage = max(0, defender.currentHp - 1);
          enduredHit = defender.isEnduringThisTurn;
        } else if (!bypassDefAb &&
            defAb == 'sturdy' &&
            defender.currentHp == defender.maxHp) {
          dealtDamage = max(0, defender.currentHp - 1);
          sturdySaved = true;
        }
      }

      final int prevDefHp = defender.currentHp;
      defender.currentHp = (defender.currentHp - dealtDamage).clamp(0, defender.maxHp);
      final actualLost = max(0, prevDefHp - defender.currentHp);
      totalDamageDealt += actualLost;
      defender.lastDamageTakenThisTurn += actualLost;
      if (move.category == MoveCategory.physical) {
        defender.lastPhysicalDamageTakenThisTurn += actualLost;
      } else if (move.category == MoveCategory.special) {
        defender.lastSpecialDamageTakenThisTurn += actualLost;
      }
      actualHits = hit;

      if (defender.bideTurnsRemaining > 0 && actualLost > 0) {
        defender.bideDamageStored += actualLost;
      }

      // Secondary status from move (suppressed by Shield Dust or Sheer Force!)
      String? secondaryStatusLabel;
      final bool defShieldDust = !bypassDefAb && defAb == 'shield_dust';
      if (!defender.isFainted &&
          !sheerForceBlocksSec &&
          !defShieldDust &&
          move.statusEffect != null &&
          move.statusChance > 0) {
        final int chance = (atkAb == 'serene_grace' ? move.statusChance * 2 : move.statusChance).clamp(0, 100);
        if (random.nextInt(100) < chance) {
          secondaryStatusLabel = _tryInflictStatus(
            defender,
            move.statusEffect!,
            random: random,
            field: activeField,
            targetIsPlayer: defIsPlayer,
            source: attacker,
            bypassDefAbility: bypassDefAb,
          );
        }
      }

      final StringBuffer msgBuffer = StringBuffer(
        hit == 1 ? "$attackerName used ${move.name}!" : "$attackerName's ${move.name} hit #$hit!",
      );
      if (hitResult.isCrit) msgBuffer.write(" A critical hit!");
      if (hit == 1 && hitResult.typeMultiplier >= 2.0) {
        msgBuffer.write(" It's super effective!");
      } else if (hit == 1 && hitResult.typeMultiplier > 0 && hitResult.typeMultiplier < 1.0) {
        msgBuffer.write(" It's not very effective...");
      }
      if (sturdySaved) {
        msgBuffer.write(" $defenderName endured the hit with Sturdy!");
      } else if (enduredHit) {
        msgBuffer.write(" $defenderName endured the hit!");
      }
      if (secondaryStatusLabel != null) {
        msgBuffer.write(" $defenderName became $secondaryStatusLabel");
      }

      events.add(BattleStepEvent(
        message: msgBuffer.toString(),
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: dealtDamage,
        targetHpAfter: defender.currentHp,
        isCrit: hitResult.isCrit,
        effectiveness: hitResult.typeMultiplier,
        statusInflictedLabel: secondaryStatusLabel,
        targetFainted: defender.isFainted,
        hitNumber: hitCount > 1 ? hit : 0,
        totalHits: hitCount > 1 ? hitCount : 0,
        surfaceActorOnAttack: hit == 1 && surfacedThisTurn,
        abilityTriggeredName: sturdySaved ? 'Sturdy' : null,
      ));

      // Anger Point on Critical Hit
      if (hitResult.isCrit && !defender.isFainted && !bypassDefAb && defAb == 'anger_point') {
        defender.atkStage = 6;
        events.add(BattleStepEvent(
          message: "$defenderName's Anger Point maxed out its Attack!",
          isPlayerActor: !isPlayer,
          statChangedLabel: 'ATK MAX!',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Anger Point',
        ));
      }

      // Synchronize status bounce back
      if (secondaryStatusLabel != null &&
          !bypassDefAb &&
          defAb == 'synchronize' &&
          !attacker.isFainted &&
          (move.statusEffect == 'burn' ||
              move.statusEffect == 'poison' ||
              move.statusEffect == 'badly_poison' ||
              move.statusEffect == 'paralysis')) {
        final synced = _tryInflictStatus(
          attacker,
          move.statusEffect == 'badly_poison' ? 'poison' : move.statusEffect!,
          random: random,
          field: activeField,
          targetIsPlayer: isPlayer,
        );
        if (synced != null) {
          events.add(BattleStepEvent(
            message: "$defenderName's Synchronize passed $synced to $attackerName!",
            isPlayerActor: !isPlayer,
            statusInflictedLabel: synced,
            hideMoveVfx: true,
            abilityTriggeredName: 'Synchronize',
          ));
        }
      }

      if (defender.isFainted) break;
    }

    if (hitCount > 1) {
      events.add(BattleStepEvent(
        message: "Hit $actualHits time${actualHits == 1 ? '' : 's'}!",
        isPlayerActor: isPlayer,
        targetHpAfter: defender.currentHp,
        isMultiHitSummary: true,
        hideMoveVfx: true,
      ));
    }

    // Wake-Up Slap & SmellingSalts wake/cure target on hit
    if (!defender.isFainted && totalDamageDealt > 0) {
      if (move.id == 'wake_up_slap' && defender.status == StatusCondition.sleep) {
        defender.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$defenderName was woken up by the slap!",
          isPlayerActor: !isPlayer,
          hideMoveVfx: true,
        ));
      } else if (move.id == 'smelling_salts' &&
          defender.status == StatusCondition.paralysis) {
        defender.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$defenderName was cured of paralysis!",
          isPlayerActor: !isPlayer,
          hideMoveVfx: true,
        ));
      }
    }

    // Brick Break shatters screens & Rapid Spin clears hazards/traps
    if (move.id == 'brick_break' && totalDamageDealt > 0) {
      final defSide = activeField.sideFor(defIsPlayer);
      if (defSide.reflectTurns > 0 || defSide.lightScreenTurns > 0) {
        defSide.clearScreens();
        events.add(BattleStepEvent(
          message: "$attackerName shattered the protective barrier!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
      }
    }
    if (move.id == 'rapid_spin' && totalDamageDealt > 0 && !attacker.isFainted) {
      activeField.sideFor(isPlayer).clearHazards();
      attacker.isSeeded = false;
      attacker.trappedTurnsRemaining = 0;
      attacker.trappedByMoveId = null;
      attacker.trappedByMoveName = null;
    }
    if (move.id == 'clear_smog' && !defender.isFainted && totalDamageDealt > 0) {
      defender
        ..atkStage = 0
        ..defStage = 0
        ..spaStage = 0
        ..spdStage = 0
        ..speStage = 0
        ..accStage = 0
        ..evaStage = 0;
      events.add(BattleStepEvent(
        message: "$defenderName's stat changes were eliminated!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
    }
    if (move.id == 'knock_off' &&
        !defender.isFainted &&
        totalDamageDealt > 0 &&
        defender.hasHeldItem &&
        !(!bypassDefAb && defAb == 'sticky_hold')) {
      final knockedName =
          ItemDatabase.byId(defender.heldItemId!)?.name ?? defender.heldItemId!;
      defender.consumedHeldItemForUnburden = true;
      defender.unequipHeldItem();
      events.add(BattleStepEvent(
        message: "$attackerName knocked off $defenderName's $knockedName!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
    }

    // Consume held items & discharge Stockpile after hitting
    if (move.id == 'fury_cutter' && totalDamageDealt > 0) {
      attacker.consecutiveFuryCutterHits = min(2, attacker.consecutiveFuryCutterHits + 1);
    }
    if ((move.id == 'fling' || move.id == 'natural_gift') &&
        totalDamageDealt > 0 &&
        attacker.hasHeldItem) {
      final usedItemId = attacker.heldItemId!;
      final heldObj = ItemDatabase.byId(usedItemId);
      if (heldObj != null && heldObj.isBerry) {
        attacker.consumedBerryIdForHarvest = usedItemId;
      }
      attacker.consumedHeldItemForUnburden = true;
      attacker.unequipHeldItem();
      events.add(BattleStepEvent(
        message: "$attackerName used up its ${heldObj?.name ?? usedItemId}!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
    }
    if (move.id == 'spit_up' && attacker.stockpileCount > 0) {
      final int stacks = attacker.stockpileCount;
      attacker.stockpileCount = 0;
      attacker.modifyStatStage('def', -stacks);
      attacker.modifyStatStage('spd', -stacks);
      events.add(BattleStepEvent(
        message: "$attackerName's stockpile effect wore off!",
        isPlayerActor: isPlayer,
        statChangedLabel: 'DEF ▼ SPD ▼',
        statTargetIsSelf: true,
        hideMoveVfx: true,
      ));
    }

    // Secondary stat changes on damaging moves (and multi-stat self drops like Superpower)
    if (totalDamageDealt > 0 && !sheerForceBlocksSec) {
      if (_multiStatMoves.containsKey(move.id)) {
        _applyMultiStats(attacker, defender, move.id, attackerName, defenderName, isPlayer, events, bypassDefAb: bypassDefAb);
      } else if (_damagingStatEffects.containsKey(move.id)) {
        final eff = _damagingStatEffects[move.id]!;
        final bool defGuard = !eff.self && !bypassDefAb && defAb == 'shield_dust';
        if (!defGuard && (!defender.isFainted || eff.self)) {
          final int chance = (atkAb == 'serene_grace' ? eff.chance * 2 : eff.chance).clamp(0, 100);
          if (random.nextInt(100) < chance) {
            _applySingleStatStage(
              target: eff.self ? attacker : defender,
              foe: eff.self ? defender : attacker,
              stat: eff.stat,
              delta: eff.delta,
              targetLabel: eff.self ? attackerName : defenderName,
              targetIsPlayer: eff.self ? isPlayer : defIsPlayer,
              byFoe: !eff.self,
              bypassDefAbility: bypassDefAb,
              events: events,
            );
          }
        }
      }

      if ((move.id == 'ancient_power' || move.id == 'silver_wind') &&
          !attacker.isFainted) {
        final int chance = (atkAb == 'serene_grace' ? 20 : 10).clamp(0, 100);
        if (random.nextInt(100) < chance) {
          for (final stat in const ['atk', 'def', 'spa', 'spd', 'spe']) {
            attacker.modifyStatStage(stat, 1);
          }
          events.add(BattleStepEvent(
            message: "$attackerName's stats all rose!",
            isPlayerActor: isPlayer,
            statChangedLabel: 'ALL ▲',
            statTargetIsSelf: true,
            hideMoveVfx: true,
          ));
        }
      }

      if (move.id == 'tri_attack' &&
          !defender.isFainted &&
          defender.status == StatusCondition.none &&
          !(!bypassDefAb && defAb == 'shield_dust')) {
        final int chance = (atkAb == 'serene_grace' ? 40 : 20).clamp(0, 100);
        if (random.nextInt(100) < chance) {
          const choices = ['burn', 'paralysis', 'freeze'];
          final pickedStatus = choices[random.nextInt(choices.length)];
          final label = _tryInflictStatus(
            defender,
            pickedStatus,
            random: random,
            field: activeField,
            targetIsPlayer: !isPlayer,
            source: attacker,
            bypassDefAbility: bypassDefAb,
          );
          if (label != null) {
            events.add(BattleStepEvent(
              message: "$defenderName became $label",
              isPlayerActor: isPlayer,
              statusInflictedLabel: label,
              hideMoveVfx: true,
            ));
          }
        }
      }
    }

    // HP Draining attacks & Liquid Ooze check
    if (_drainMoves.contains(move.id) && totalDamageDealt > 0 && !attacker.isFainted) {
      final int amt = max(1, totalDamageDealt ~/ 2);
      if (!bypassDefAb && defAb == 'liquid_ooze' && atkAb != 'magic_guard') {
        attacker.currentHp = (attacker.currentHp - amt).clamp(0, attacker.maxHp);
        events.add(BattleStepEvent(
          message: "$attackerName sucked up the Liquid Ooze!",
          isPlayerActor: isPlayer,
          damageDealt: amt,
          targetHpAfter: attacker.currentHp,
          targetFainted: attacker.isFainted,
          isSelfDamage: true,
          abilityTriggeredName: 'Liquid Ooze',
          hideMoveVfx: true,
        ));
        if (attacker.isFainted) {
          events.add(BattleStepEvent(
            message: "$attackerName fainted!",
            isPlayerActor: !isPlayer,
            targetHpAfter: 0,
            targetFainted: true,
          ));
        }
      } else if (attacker.currentHp < attacker.maxHp) {
        final int actualHeal = min(amt, attacker.maxHp - attacker.currentHp);
        attacker.currentHp += actualHeal;
        events.add(BattleStepEvent(
          message: "$defenderName had its energy drained! (+$actualHeal HP)",
          isPlayerActor: isPlayer,
          healAmount: actualHeal,
          targetHpAfter: attacker.currentHp,
          isStatusTick: true,
          hideMoveVfx: true,
        ));
      }
    }

    // Recoil damage (Rock Head & Magic Guard prevent recoil!)
    final double? recoilFrac = _recoilFraction[move.id];
    if (recoilFrac != null &&
        totalDamageDealt > 0 &&
        !attacker.isFainted &&
        atkAb != 'rock_head' &&
        atkAb != 'magic_guard') {
      final int recoil = max(1, (totalDamageDealt * recoilFrac).round());
      attacker.currentHp = (attacker.currentHp - recoil).clamp(0, attacker.maxHp);
      events.add(BattleStepEvent(
        message: "$attackerName was damaged by the recoil!",
        isPlayerActor: isPlayer,
        damageDealt: recoil,
        targetHpAfter: attacker.currentHp,
        targetFainted: attacker.isFainted,
        isSelfDamage: true,
        hideMoveVfx: true,
      ));
      if (attacker.isFainted) {
        events.add(BattleStepEvent(
          message: "$attackerName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
    }

    // Life Orb (+30% power, 10% max HP recoil on damaging hits unless Magic Guard / Sheer Force)
    if (!skipLifeOrbRecoil &&
        totalDamageDealt > 0 &&
        !attacker.isFainted &&
        attacker.heldItemId == 'life_orb' &&
        atkAb != 'magic_guard' &&
        !sheerForceBlocksSec) {
      final int orbRecoil = max(1, attacker.maxHp ~/ 10);
      attacker.currentHp = (attacker.currentHp - orbRecoil).clamp(0, attacker.maxHp);
      events.add(BattleStepEvent(
        message: "$attackerName lost some of its HP from Life Orb!",
        isPlayerActor: isPlayer,
        damageDealt: orbRecoil,
        targetHpAfter: attacker.currentHp,
        targetFainted: attacker.isFainted,
        isSelfDamage: true,
        hideMoveVfx: true,
      ));
      if (attacker.isFainted) {
        events.add(BattleStepEvent(
          message: "$attackerName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
    }

    // Contact Ability & Hit-Reaction Triggers
    if (totalDamageDealt > 0) {
      _processPostHitAbilityReactions(
        attacker: attacker,
        move: move,
        defender: defender,
        isPlayer: isPlayer,
        isWild: isWild,
        attackerName: attackerName,
        defenderName: defenderName,
        bypassDefAb: bypassDefAb,
        field: activeField,
        random: random,
        events: events,
      );
    }

    // Flinch chance (respecting Shield Dust / Inner Focus / Steadfast)
    final int moveFlinch = _flinchChances[move.id] ?? 0;
    final int stenchFlinch = (atkAb == 'stench' && moveFlinch == 0 && !sheerForceBlocksSec) ? 10 : 0;
    final int flinchChance = sheerForceBlocksSec
        ? 0
        : (atkAb == 'serene_grace' ? max(moveFlinch, stenchFlinch) * 2 : max(moveFlinch, stenchFlinch));
    if (!defender.isFainted &&
        defender.substituteHp <= 0 &&
        flinchChance > 0 &&
        attacker.actedFirstThisTurn &&
        (!bypassDefAb ? defAb != 'inner_focus' && defAb != 'shield_dust' : true) &&
        random.nextInt(100) < flinchChance) {
      defender.flinchedThisTurn = true;
      // Steadfast boosts Speed +1 when flinched!
      if (defAb == 'steadfast') {
        defender.modifyStatStage('spe', 1);
        events.add(BattleStepEvent(
          message: "$defenderName's Steadfast raised its Speed!",
          isPlayerActor: !isPlayer,
          statChangedLabel: 'SPE ▲',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Steadfast',
        ));
      }
    }

    // Recharge / Trap / Rampage / Rollout bookkeeping
    if (move.stageMechanic == MoveStageMechanic.rechargeAfterHit && !defender.isFainted) {
      attacker.needsRecharge = true;
    }
    if (move.stageMechanic == MoveStageMechanic.trapDot &&
        !defender.isFainted &&
        defender.trappedTurnsRemaining == 0) {
      defender.trappedTurnsRemaining = 4 + random.nextInt(2);
      defender.trappedByMoveId = move.id;
      defender.trappedByMoveName = move.name;
      events.add(BattleStepEvent(
        message: "$defenderName was trapped by ${move.name}!",
        isPlayerActor: isPlayer,
        targetHpAfter: defender.currentHp,
        hideMoveVfx: true,
      ));
    }
    if (move.stageMechanic == MoveStageMechanic.rampage && attacker.rampageMoveId == move.id) {
      if (isContinuingRampage) {
        attacker.rampageTurnsRemaining--;
        if (attacker.rampageTurnsRemaining <= 0) {
          attacker.rampageMoveId = null;
          if (!attacker.isFainted && !attacker.isConfused && atkAb != 'own_tempo') {
            attacker.isConfused = true;
            attacker.confusionTurnsRemaining = 2 + random.nextInt(3);
            events.add(BattleStepEvent(
              message: "$attackerName became confused due to fatigue!",
              isPlayerActor: isPlayer,
              statusInflictedLabel: 'CONFUSED!',
              statTargetIsSelf: true,
              targetHpAfter: attacker.currentHp,
              hideMoveVfx: true,
            ));
          }
        }
      }
    }
    if (move.stageMechanic == MoveStageMechanic.escalatingRoll) {
      if (isContinuingRollout) attacker.rolloutTurnsRemaining--;
      attacker.rolloutHitCount++;
      if (attacker.rolloutTurnsRemaining <= 0) attacker.rolloutHitCount = 0;
    }

    // Berry trigger after hit
    if (!defender.isFainted) {
      final berryEvent = checkAndConsumeHeldBerry(
        defender,
        opponent: attacker,
        isPlayer: !isPlayer,
        isWild: isWild,
      );
      if (berryEvent != null) events.add(berryEvent);
    }

    // Consume Charge / Helping Hand after damaging attack, plus Uproar / Covet / Pluck / Bug Bite / Throw switches
    if (clearHelpingHandAfter) {
      attacker.helpingHandBoosted = false;
    }
    if (move.id != 'charge') {
      attacker.isChargedElectric = false;
    }

    if (move.id == 'uproar' && totalDamageDealt > 0) {
      activeField.uproarTurns = 3;
      if (attacker.status == StatusCondition.sleep) {
        attacker.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$attackerName woke up from the Uproar!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
        ));
      }
      if (!defender.isFainted && defender.status == StatusCondition.sleep) {
        defender.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$defenderName woke up from the Uproar!",
          isPlayerActor: !isPlayer,
          hideMoveVfx: true,
        ));
      }
    }

    if (move.id == 'covet' &&
        totalDamageDealt > 0 &&
        !attacker.isFainted &&
        !defender.isFainted &&
        !attacker.hasHeldItem &&
        defender.hasHeldItem &&
        !(!bypassDefAb && defAb == 'sticky_hold')) {
      final stolenId = defender.heldItemId!;
      final stolenName = ItemDatabase.byId(stolenId)?.name ?? stolenId;
      defender.unequipHeldItem();
      attacker.equipHeldItem(stolenId);
      events.add(BattleStepEvent(
        message: "$attackerName stole $defenderName's $stolenName!",
        isPlayerActor: isPlayer,
        hideMoveVfx: true,
      ));
    }

    if ((move.id == 'pluck' || move.id == 'bug_bite') &&
        totalDamageDealt > 0 &&
        !attacker.isFainted &&
        !defender.isFainted &&
        defender.hasHeldItem) {
      final heldId = defender.heldItemId!;
      final heldObj = ItemDatabase.byId(heldId);
      if (heldObj != null && heldObj.isBerry) {
        defender.consumedBerryIdForHarvest = heldId;
        defender.consumedHeldItemForUnburden = true;
        defender.unequipHeldItem();
        final int heal = min(
          max(1, attacker.maxHp ~/ 4),
          attacker.maxHp - attacker.currentHp,
        );
        attacker.currentHp += heal;
        events.add(BattleStepEvent(
          message: heal > 0
              ? "$attackerName stole and ate $defenderName's ${heldObj.name}! (+$heal HP)"
              : "$attackerName stole and ate $defenderName's ${heldObj.name}!",
          isPlayerActor: isPlayer,
          healAmount: heal,
          targetHpAfter: attacker.currentHp,
          isStatusTick: heal > 0,
          hideMoveVfx: true,
        ));
      }
    }

    if ((move.id == 'circle_throw' || move.id == 'dragon_tail') &&
        totalDamageDealt > 0 &&
        !defender.isFainted) {
      bool clearedAny = false;
      if (defender.atkStage > 0) {
        defender.atkStage = 0;
        clearedAny = true;
      }
      if (defender.defStage > 0) {
        defender.defStage = 0;
        clearedAny = true;
      }
      if (defender.spaStage > 0) {
        defender.spaStage = 0;
        clearedAny = true;
      }
      if (defender.spdStage > 0) {
        defender.spdStage = 0;
        clearedAny = true;
      }
      if (defender.speStage > 0) {
        defender.speStage = 0;
        clearedAny = true;
      }
      if (clearedAny) {
        events.add(BattleStepEvent(
          message: "$defenderName was knocked off balance and lost its boosts!",
          isPlayerActor: isPlayer,
          statChangedLabel: 'RESET',
          hideMoveVfx: true,
        ));
      } else {
        _applySingleStatStage(
          target: defender,
          foe: attacker,
          stat: 'spe',
          delta: -1,
          targetLabel: defenderName,
          targetIsPlayer: !isPlayer,
          byFoe: true,
          bypassDefAbility: bypassDefAb,
          events: events,
          field: activeField,
        );
      }
    }

    // Attacker Leppa Berry trigger if a move just dropped to 0 PP
    if (!attacker.isFainted && attacker.heldItemId == 'leppa_berry') {
      final leppaEvent = checkAndConsumeHeldBerry(
        attacker,
        opponent: defender,
        isPlayer: isPlayer,
        isWild: isWild,
      );
      if (leppaEvent != null) events.add(leppaEvent);
    }

    if (defender.isFainted) {
      events.add(BattleStepEvent(
        message: "$defenderName fainted!",
        isPlayerActor: isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
      if (defender.hasGrudge && move.currentPp > 0) {
        move.currentPp = 0;
        events.add(BattleStepEvent(
          message: "$attackerName's ${move.name} lost all its PP due to the grudge!",
          isPlayerActor: !isPlayer,
          hideMoveVfx: true,
        ));
      }
      // Destiny Bond KO trade
      if (defender.hasDestinyBond && !attacker.isFainted) {
        final dCost = attacker.currentHp;
        attacker.currentHp = 0;
        events.add(BattleStepEvent(
          message: "$defenderName took $attackerName down with Destiny Bond!",
          isPlayerActor: isPlayer,
          damageDealt: dCost,
          targetHpAfter: 0,
          targetFainted: true,
          isSelfDamage: true,
          hideMoveVfx: true,
        ));
        events.add(BattleStepEvent(
          message: "$attackerName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      } else if (!attacker.isFainted && atkAb == 'moxie') {
        attacker.modifyStatStage('atk', 1);
        events.add(BattleStepEvent(
          message: "$attackerName's Moxie raised its Attack!",
          isPlayerActor: isPlayer,
          statChangedLabel: 'ATK ▲',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Moxie',
        ));
      }
    }

    appendSelfKoEventsIfNeeded();
    return events;
  }

  // ─── POST-HIT CONTACT & REACTIVE ABILITIES ─────────────────────────────────
  static void _processPostHitAbilityReactions({
    required PokemonInstance attacker,
    required Move move,
    required PokemonInstance defender,
    required bool isPlayer,
    required bool isWild,
    required String attackerName,
    required String defenderName,
    required bool bypassDefAb,
    required BattleFieldState field,
    required Random random,
    required List<BattleStepEvent> events,
  }) {
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = defender.effectiveAbilityId;
    final bool isContact = _isContactMove(move);

    // Weak Armor (Physical move lowers Def -1, raises Spe +1)
    if (!defender.isFainted &&
        !bypassDefAb &&
        defAb == 'weak_armor' &&
        move.category == MoveCategory.physical) {
      defender.modifyStatStage('def', -1);
      defender.modifyStatStage('spe', 1);
      events.add(BattleStepEvent(
        message: "$defenderName's Weak Armor lowered Defense and raised Speed!",
        isPlayerActor: !isPlayer,
        statChangedLabel: 'DEF ▼ SPE ▲',
        statTargetIsSelf: true,
        hideMoveVfx: true,
        abilityTriggeredName: 'Weak Armor',
      ));
    }

    // Justified (+1 Atk when hit by Dark)
    if (!defender.isFainted &&
        !bypassDefAb &&
        defAb == 'justified' &&
        move.type == PokemonType.dark) {
      defender.modifyStatStage('atk', 1);
      events.add(BattleStepEvent(
        message: "$defenderName's Justified raised its Attack!",
        isPlayerActor: !isPlayer,
        statChangedLabel: 'ATK ▲',
        statTargetIsSelf: true,
        hideMoveVfx: true,
        abilityTriggeredName: 'Justified',
      ));
    }

    // Rattled (+1 Spe when hit by Bug, Ghost, or Dark)
    if (!defender.isFainted &&
        !bypassDefAb &&
        defAb == 'rattled' &&
        (move.type == PokemonType.bug ||
            move.type == PokemonType.ghost ||
            move.type == PokemonType.dark)) {
      defender.modifyStatStage('spe', 1);
      events.add(BattleStepEvent(
        message: "$defenderName's Rattled boosted its Speed!",
        isPlayerActor: !isPlayer,
        statChangedLabel: 'SPE ▲',
        statTargetIsSelf: true,
        hideMoveVfx: true,
        abilityTriggeredName: 'Rattled',
      ));
    }

    if (!isContact) return;

    // Attacker Poison Touch (30% chance to poison on contact)
    if (!defender.isFainted &&
        atkAb == 'poison_touch' &&
        !(!bypassDefAb && defAb == 'shield_dust') &&
        random.nextInt(100) < 30) {
      final p = _tryInflictStatus(defender, 'poison',
          random: random, field: field, targetIsPlayer: !isPlayer);
      if (p != null) {
        events.add(BattleStepEvent(
          message: "$attackerName's Poison Touch poisoned $defenderName!",
          isPlayerActor: isPlayer,
          statusInflictedLabel: p,
          hideMoveVfx: true,
          abilityTriggeredName: 'Poison Touch',
        ));
      }
    }

    // Defender Aftermath (1/4 max HP damage to attacker on contact KO)
    if (defender.isFainted &&
        !attacker.isFainted &&
        !bypassDefAb &&
        defAb == 'aftermath' &&
        atkAb != 'damp' &&
        atkAb != 'magic_guard') {
      final int dmg = max(1, attacker.maxHp ~/ 4);
      attacker.currentHp = (attacker.currentHp - dmg).clamp(0, attacker.maxHp);
      events.add(BattleStepEvent(
        message: "$attackerName was hurt by $defenderName's Aftermath!",
        isPlayerActor: isPlayer,
        damageDealt: dmg,
        targetHpAfter: attacker.currentHp,
        targetFainted: attacker.isFainted,
        isSelfDamage: true,
        abilityTriggeredName: 'Aftermath',
        hideMoveVfx: true,
      ));
      if (attacker.isFainted) {
        events.add(BattleStepEvent(
          message: "$attackerName fainted!",
          isPlayerActor: !isPlayer,
          targetHpAfter: 0,
          targetFainted: true,
        ));
      }
    }

    if (attacker.isFainted || bypassDefAb) return;

    // Contact Status Abilities (Static, Poison Point, Flame Body, Effect Spore, Cute Charm)
    if (defAb == 'static' && random.nextInt(100) < 30) {
      final label = _tryInflictStatus(attacker, 'paralysis',
          random: random, field: field, targetIsPlayer: isPlayer);
      if (label != null) {
        events.add(BattleStepEvent(
          message: "$defenderName's Static paralyzed $attackerName!",
          isPlayerActor: !isPlayer,
          statusInflictedLabel: label,
          hideMoveVfx: true,
          abilityTriggeredName: 'Static',
        ));
      }
    } else if (defAb == 'poison_point' && random.nextInt(100) < 30) {
      final label = _tryInflictStatus(attacker, 'poison',
          random: random, field: field, targetIsPlayer: isPlayer);
      if (label != null) {
        events.add(BattleStepEvent(
          message: "$defenderName's Poison Point poisoned $attackerName!",
          isPlayerActor: !isPlayer,
          statusInflictedLabel: label,
          hideMoveVfx: true,
          abilityTriggeredName: 'Poison Point',
        ));
      }
    } else if (defAb == 'flame_body' && random.nextInt(100) < 30) {
      final label = _tryInflictStatus(attacker, 'burn',
          random: random, field: field, targetIsPlayer: isPlayer);
      if (label != null) {
        events.add(BattleStepEvent(
          message: "$defenderName's Flame Body burned $attackerName!",
          isPlayerActor: !isPlayer,
          statusInflictedLabel: label,
          hideMoveVfx: true,
          abilityTriggeredName: 'Flame Body',
        ));
      }
    } else if (defAb == 'effect_spore' &&
        atkAb != 'overcoat' &&
        !attacker.effectiveTypes.contains(PokemonType.grass) &&
        random.nextInt(100) < 30) {
      final roll = random.nextInt(3);
      final chosen = roll == 0 ? 'sleep' : (roll == 1 ? 'paralysis' : 'poison');
      final label = _tryInflictStatus(attacker, chosen,
          random: random, field: field, targetIsPlayer: isPlayer);
      if (label != null) {
        events.add(BattleStepEvent(
          message: "$defenderName's Effect Spore inflicted $label on $attackerName!",
          isPlayerActor: !isPlayer,
          statusInflictedLabel: label,
          hideMoveVfx: true,
          abilityTriggeredName: 'Effect Spore',
        ));
      }
    } else if (defAb == 'cute_charm' &&
        atkAb != 'oblivious' &&
        random.nextInt(100) < 30) {
      final delta = attacker.modifyStatStage('atk', -1);
      if (delta != 0) {
        events.add(BattleStepEvent(
          message: "$defenderName's Cute Charm infatuated $attackerName (ATK ▼)!",
          isPlayerActor: !isPlayer,
          statChangedLabel: 'ATK ▼',
          hideMoveVfx: true,
          abilityTriggeredName: 'Cute Charm',
        ));
      }
    }
  }

  // ─── STATUS & UTILITY MOVES ─────────────────────────────────────────────────
  static List<BattleStepEvent> _executeStatusMove({
    required PokemonInstance attacker,
    required Move move,
    required PokemonInstance defender,
    required bool isPlayer,
    bool? defenderIsPlayer,
    required bool isWild,
    Trainer? playerTrainer,
    Move? defenderIntendedMove,
    required BattleFieldState field,
    required Random random,
    required void Function() appendSelfKo,
  }) {
    final List<BattleStepEvent> events = [];
    final bool defIsPlayer = defenderIsPlayer ?? !isPlayer;
    final attackerName = _labelFor(attacker, isPlayer, isWild);
    final defenderName = _labelFor(defender, defIsPlayer, isWild);
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = defender.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';
    final weather = field.effectiveWeather(attacker, defender);

    // 1. Weather moves
    if (move.id == 'rain_dance' ||
        move.id == 'sunny_day' ||
        move.id == 'sandstorm' ||
        move.id == 'hail') {
      final w = move.id == 'rain_dance'
          ? BattleWeather.rain
          : (move.id == 'sunny_day'
              ? BattleWeather.sun
              : (move.id == 'sandstorm' ? BattleWeather.sandstorm : BattleWeather.hail));
      field.weather = w;
      field.weatherTurnsRemaining = 5;
      final wMsg = switch (w) {
        BattleWeather.rain => 'It started to rain!',
        BattleWeather.sun => 'The sunlight turned harsh!',
        BattleWeather.sandstorm => 'A sandstorm kicked up!',
        BattleWeather.hail => 'It started to hail!',
        BattleWeather.none => '',
      };
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! $wMsg",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statTargetIsSelf: true,
      ));
      return events;
    }

    // 2. Healing & Rest moves
    if (const {
      'recover', 'soft_boiled', 'rest', 'roost', 'slack_off', 'heal_pulse',
      'synthesis', 'moonlight', 'morning_sun', 'swallow',
    }.contains(move.id)) {
      if (attacker.currentHp >= attacker.maxHp) {
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}, but its HP is already full!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          targetHpAfter: attacker.currentHp,
        ));
        return events;
      }
      final bool isRest = move.id == 'rest';
      if (isRest &&
          (atkAb == 'insomnia' || atkAb == 'vital_spirit')) {
        events.add(BattleStepEvent(
          message: "$attackerName stayed awake thanks to ${AbilityDatabase.nameOf(atkAb)}!",
          isPlayerActor: isPlayer,
          hideMoveVfx: true,
          abilityTriggeredName: AbilityDatabase.nameOf(atkAb),
        ));
        return events;
      }
      if (isRest && field.uproarTurns > 0) {
        events.add(BattleStepEvent(
          message: "$attackerName stayed awake because of the uproar!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          isMiss: true,
          hideMoveVfx: true,
        ));
        return events;
      }
      if (isRest && attacker.status == StatusCondition.sleep) {
        events.add(BattleStepEvent(
          message: "$attackerName used Rest, but it is already asleep!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          targetHpAfter: attacker.currentHp,
        ));
        return events;
      }
      int healAmt;
      if (isRest) {
        healAmt = attacker.maxHp;
      } else if (move.id == 'swallow') {
        final int stacks = attacker.stockpileCount.clamp(1, 3);
        healAmt = stacks == 1
            ? max(1, attacker.maxHp ~/ 4)
            : (stacks == 2 ? max(1, attacker.maxHp ~/ 2) : attacker.maxHp);
      } else if (move.id == 'synthesis' || move.id == 'moonlight' || move.id == 'morning_sun') {
        if (weather == BattleWeather.sun) {
          healAmt = max(1, (attacker.maxHp * 2 / 3).round());
        } else if (weather == BattleWeather.none) {
          healAmt = max(1, (attacker.maxHp / 2).round());
        } else {
          healAmt = max(1, (attacker.maxHp / 4).round());
        }
      } else {
        healAmt = max(1, (attacker.maxHp / 2).round());
      }
      final int actualHeal = min(healAmt, attacker.maxHp - attacker.currentHp);
      attacker.currentHp += actualHeal;
      if (isRest) {
        attacker.status = StatusCondition.sleep;
        attacker.sleepTurnsRemaining = 3;
        attacker.isBadlyPoisoned = false;
      } else if (move.id == 'roost') {
        attacker.isRoostedThisTurn = true;
      } else if (move.id == 'swallow' && attacker.stockpileCount > 0) {
        final int stacks = attacker.stockpileCount;
        attacker.stockpileCount = 0;
        attacker.modifyStatStage('def', -stacks);
        attacker.modifyStatStage('spd', -stacks);
      }
      events.add(BattleStepEvent(
        message: isRest
            ? "$attackerName went to sleep and restored full HP! (+$actualHeal HP)"
            : "$attackerName restored its HP! (+$actualHeal HP)",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        healAmount: actualHeal,
        statTargetIsSelf: true,
        statusInflictedLabel: isRest ? 'ASLEEP!' : null,
        targetHpAfter: attacker.currentHp,
      ));
      return events;
    }

    // 3. Belly Drum
    if (move.id == 'belly_drum') {
      final int cost = max(1, attacker.maxHp ~/ 2);
      if (attacker.currentHp <= cost || attacker.atkStage >= 6) {
        events.add(BattleStepEvent(
          message: "$attackerName used Belly Drum, but it failed!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
        ));
        return events;
      }
      attacker.currentHp -= cost;
      attacker.atkStage = 6;
      events.add(BattleStepEvent(
        message: "$attackerName cut its HP and maximized its Attack!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        damageDealt: cost,
        targetHpAfter: attacker.currentHp,
        statChangedLabel: 'ATK MAX!',
        statTargetIsSelf: true,
        isSelfDamage: true,
      ));
      return events;
    }

    // 4. Curse
    if (move.id == 'curse') {
      if (attacker.effectiveTypes.contains(PokemonType.ghost)) {
        final int cost = max(1, attacker.maxHp ~/ 2);
        attacker.currentHp = (attacker.currentHp - cost).clamp(0, attacker.maxHp);
        defender.isSeeded = true;
        events.add(BattleStepEvent(
          message: "$attackerName cut its own HP and laid a curse on $defenderName!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          damageDealt: cost,
          targetHpAfter: attacker.currentHp,
          targetFainted: attacker.isFainted,
          isSelfDamage: true,
        ));
        if (attacker.isFainted) {
          events.add(BattleStepEvent(
            message: "$attackerName fainted!",
            isPlayerActor: !isPlayer,
            targetHpAfter: 0,
            targetFainted: true,
          ));
        }
        return events;
      }
      attacker.modifyStatStage('spe', -1);
      attacker.modifyStatStage('atk', 1);
      attacker.modifyStatStage('def', 1);
      events.add(BattleStepEvent(
        message: "$attackerName used Curse! Speed fell, Attack and Defense rose!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statChangedLabel: 'ATK ▲ DEF ▲ SPE ▼',
        statTargetIsSelf: true,
      ));
      return events;
    }

    // 5. Field / Side Buffs, Hazards & Specialized Status Mechanics
    final selfSide = field.sideFor(isPlayer);
    final oppSide = field.sideFor(!isPlayer);
    switch (move.id) {
      case 'reflect':
        selfSide.reflectTurns = 5;
        events.add(BattleStepEvent(
          message: "Reflect made $attackerName's team stronger against physical moves!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'light_screen':
        selfSide.lightScreenTurns = 5;
        events.add(BattleStepEvent(
          message: "Light Screen made $attackerName's team stronger against special moves!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'safeguard':
        selfSide.safeguardTurns = 5;
        events.add(BattleStepEvent(
          message: "$attackerName's team is cloaked in Safeguard!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'mist':
        selfSide.mistTurns = 5;
        events.add(BattleStepEvent(
          message: "$attackerName shrouded its side in Mist!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'tailwind':
        selfSide.tailwindTurns = 4;
        events.add(BattleStepEvent(
          message: "The Tailwind blew from behind $attackerName!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'lucky_chant':
        selfSide.luckyChantTurns = 5;
        events.add(BattleStepEvent(
          message: "Lucky Chant shielded $attackerName from critical hits!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'spikes':
        oppSide.spikesLayers = min(3, oppSide.spikesLayers + 1);
        events.add(BattleStepEvent(
          message: "Spikes were scattered around $defenderName's feet!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'toxic_spikes':
        oppSide.toxicSpikesLayers = min(2, oppSide.toxicSpikesLayers + 1);
        events.add(BattleStepEvent(
          message: "Poison spikes were scattered around $defenderName's feet!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'stealth_rock':
        oppSide.hasStealthRock = true;
        events.add(BattleStepEvent(
          message: "Pointed stones float in the air around $defenderName's team!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'gravity':
        field.gravityTurns = 5;
        events.add(BattleStepEvent(
          message: "Gravity intensified!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'mud_sport':
        field.mudSportActive = true;
        events.add(BattleStepEvent(
          message: "Electricity's power was weakened!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'water_sport':
        field.waterSportActive = true;
        events.add(BattleStepEvent(
          message: "Fire's power was weakened!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'wonder_room':
        field.wonderRoomTurns = field.wonderRoomTurns > 0 ? 0 : 5;
        events.add(BattleStepEvent(
          message: field.wonderRoomTurns > 0
              ? "It created a bizarre area in which Defense and Sp. Def stats are swapped!"
              : "Wonder Room wore off, and Defense and Sp. Def stats returned to normal!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'haze':
        attacker..atkStage = 0..defStage = 0..spaStage = 0..spdStage = 0..speStage = 0..accStage = 0..evaStage = 0;
        defender..atkStage = 0..defStage = 0..spaStage = 0..spdStage = 0..speStage = 0..accStage = 0..evaStage = 0;
        events.add(BattleStepEvent(
          message: "All stat changes were eliminated!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'psych_up':
        attacker
          ..atkStage = defender.atkStage
          ..defStage = defender.defStage
          ..spaStage = defender.spaStage
          ..spdStage = defender.spdStage
          ..speStage = defender.speStage
          ..accStage = defender.accStage
          ..evaStage = defender.evaStage;
        events.add(BattleStepEvent(
          message: "$attackerName copied $defenderName's stat changes!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'power_swap':
        final int tmpAtk = attacker.atkStage;
        final int tmpSpa = attacker.spaStage;
        attacker..atkStage = defender.atkStage..spaStage = defender.spaStage;
        defender..atkStage = tmpAtk..spaStage = tmpSpa;
        events.add(BattleStepEvent(
          message: "$attackerName switched all changes to its Attack and Sp. Atk with the target!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'guard_swap':
        final int tmpDef = attacker.defStage;
        final int tmpSpd = attacker.spdStage;
        attacker..defStage = defender.defStage..spdStage = defender.spdStage;
        defender..defStage = tmpDef..spdStage = tmpSpd;
        events.add(BattleStepEvent(
          message: "$attackerName switched all changes to its Defense and Sp. Def with the target!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'focus_energy':
        if (attacker.hasFocusEnergy) {
          events.add(BattleStepEvent(
            message: "$attackerName used ${move.name}, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        } else {
          attacker.hasFocusEnergy = true;
          events.add(BattleStepEvent(
            message: "$attackerName is getting pumped!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
            statusInflictedLabel: 'CRIT UP!',
          ));
        }
        return events;
      case 'acupressure':
        final boostable = <String>[];
        if (attacker.atkStage < 6) boostable.add('atk');
        if (attacker.defStage < 6) boostable.add('def');
        if (attacker.spaStage < 6) boostable.add('spa');
        if (attacker.spdStage < 6) boostable.add('spd');
        if (attacker.speStage < 6) boostable.add('spe');
        if (attacker.accStage < 6) boostable.add('acc');
        if (attacker.evaStage < 6) boostable.add('eva');
        if (boostable.isEmpty) {
          events.add(BattleStepEvent(
            message: "$attackerName used Acupressure, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        } else {
          final pickedStat = boostable[random.nextInt(boostable.length)];
          _applySingleStatStage(
            target: attacker,
            foe: defender,
            stat: pickedStat,
            delta: 2,
            targetLabel: attackerName,
            targetIsPlayer: isPlayer,
            byFoe: false,
            bypassDefAbility: bypassDefAb,
            events: events,
            move: move,
            actorLabel: attackerName,
            isPlayerActor: isPlayer,
            field: field,
          );
        }
        return events;
      case 'lock_on':
      case 'mind_reader':
        defender.sureHitAgainstTurns = 2;
        events.add(BattleStepEvent(
          message: "$attackerName took aim at $defenderName!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'telekinesis':
        defender.sureHitAgainstTurns = 3;
        events.add(BattleStepEvent(
          message: "$defenderName was hurled into the air!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'foresight':
      case 'odor_sleuth':
      case 'miracle_eye':
        defender.isIdentified = true;
        events.add(BattleStepEvent(
          message: "$attackerName identified $defenderName!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'mean_look':
      case 'block':
        defender.isMeanLookTrapped = true;
        events.add(BattleStepEvent(
          message: "$defenderName can no longer escape!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'disable':
        final lastId = defender.lastMoveUsedId;
        if (lastId == null ||
            defender.disableTurnsRemaining > 0 ||
            !defender.activeMoves.any((m) => m.id == lastId)) {
          events.add(BattleStepEvent(
            message: "$attackerName used Disable, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          defender.disabledMoveId = lastId;
          defender.disableTurnsRemaining = 4;
          final disabledName = defender.activeMoves.firstWhere((m) => m.id == lastId).name;
          events.add(BattleStepEvent(
            message: "$defenderName's $disabledName was disabled!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'torment':
        if (defender.isTormented) {
          events.add(BattleStepEvent(
            message: "$attackerName used Torment, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          defender.isTormented = true;
          events.add(BattleStepEvent(
            message: "$defenderName was subjected to Torment!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'spite':
        final lastId = defender.lastMoveUsedId;
        final matched = lastId == null
            ? const <Move>[]
            : defender.activeMoves.where((m) => m.id == lastId).toList();
        if (matched.isNotEmpty && matched.first.currentPp > 0) {
          final targetMove = matched.first;
          final int drop = min(4, targetMove.currentPp);
          targetMove.currentPp = max(0, targetMove.currentPp - 4);
          events.add(BattleStepEvent(
            message: "It reduced the PP of $defenderName's ${targetMove.name} by $drop!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName used Spite, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'trick':
      case 'switcheroo':
        if ((!attacker.hasHeldItem && !defender.hasHeldItem) ||
            (!bypassDefAb && defAb == 'sticky_hold') ||
            atkAb == 'sticky_hold') {
          events.add(BattleStepEvent(
            message: "$attackerName used ${move.name}, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          final tmp = attacker.heldItemId;
          attacker.heldItemId = defender.heldItemId;
          defender.heldItemId = tmp;
          events.add(BattleStepEvent(
            message: "$attackerName switched items with $defenderName!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'bestow':
        if (!attacker.hasHeldItem || defender.hasHeldItem) {
          events.add(BattleStepEvent(
            message: "$attackerName used Bestow, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          final itemId = attacker.heldItemId!;
          final itemName = ItemDatabase.byId(itemId)?.name ?? itemId;
          defender.heldItemId = itemId;
          attacker.heldItemId = null;
          attacker.consumedHeldItemForUnburden = true;
          events.add(BattleStepEvent(
            message: "$defenderName received $itemName from $attackerName!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'recycle':
        if (attacker.hasHeldItem || attacker.consumedBerryIdForHarvest == null) {
          events.add(BattleStepEvent(
            message: "$attackerName used Recycle, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        } else {
          final restoredId = attacker.consumedBerryIdForHarvest!;
          attacker.heldItemId = restoredId;
          attacker.consumedBerryIdForHarvest = null;
          events.add(BattleStepEvent(
            message: "$attackerName found one ${ItemDatabase.byId(restoredId)?.name ?? restoredId}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        }
        return events;
      case 'refresh':
      case 'aromatherapy':
        attacker.status = StatusCondition.none;
        attacker.isBadlyPoisoned = false;
        events.add(BattleStepEvent(
          message: "$attackerName cured its status conditions!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true, statusInflictedLabel: 'CURED',
        ));
        return events;
      case 'ingrain':
        attacker.isIngrained = true;
        events.add(BattleStepEvent(
          message: "$attackerName planted its roots!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'aqua_ring':
        attacker.hasAquaRing = true;
        events.add(BattleStepEvent(
          message: "$attackerName surrounded itself with a veil of water!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'magnet_rise':
        attacker.hasMagnetRise = true;
        attacker.magnetRiseTurnsRemaining = 5;
        events.add(BattleStepEvent(
          message: "$attackerName levitated with electromagnetism!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'destiny_bond':
        attacker.hasDestinyBond = true;
        events.add(BattleStepEvent(
          message: "$attackerName is hoping to take the attacker down with it!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'perish_song':
        if (attacker.perishTurnsRemaining == 0) attacker.perishTurnsRemaining = 3;
        if (defender.perishTurnsRemaining == 0 && (!bypassDefAb && defAb != 'soundproof')) {
          defender.perishTurnsRemaining = 3;
        }
        events.add(BattleStepEvent(
          message: "All Pokémon that hear the song will faint in 3 turns!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'yawn':
        if (defender.status == StatusCondition.none && !defender.isYawnDrowsy) {
          defender.isYawnDrowsy = true;
          events.add(BattleStepEvent(
            message: "$defenderName grew drowsy!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName used Yawn, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'taunt':
        if (!bypassDefAb && defAb == 'oblivious') {
          events.add(BattleStepEvent(
            message: "$defenderName's Oblivious prevented Taunt!",
            isPlayerActor: isPlayer, hideMoveVfx: true, abilityTriggeredName: 'Oblivious',
          ));
        } else {
          defender.isTaunted = true;
          defender.tauntTurnsRemaining = 3;
          events.add(BattleStepEvent(
            message: "$defenderName fell for the taunt!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'encore':
        if (defender.lastMoveUsedId != null &&
            defender.activeMoves.any((m) => m.id == defender.lastMoveUsedId)) {
          defender.encoredMoveId = defender.lastMoveUsedId;
          defender.encoreTurnsRemaining = 3;
          events.add(BattleStepEvent(
            message: "$defenderName received an encore!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName used Encore, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'gastro_acid':
        defender.activeAbilityId = '_suppressed';
        events.add(BattleStepEvent(
          message: "$defenderName's Ability was suppressed!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'worry_seed':
        defender.activeAbilityId = 'insomnia';
        if (defender.status == StatusCondition.sleep) defender.status = StatusCondition.none;
        events.add(BattleStepEvent(
          message: "$defenderName's Ability became Insomnia!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'role_play':
        if (defAb != 'trace' && defAb != 'imposter') {
          attacker.activeAbilityId = defender.effectiveAbilityId;
          events.add(BattleStepEvent(
            message:
                "$attackerName copied $defenderName's ${AbilityDatabase.nameOf(attacker.effectiveAbilityId)}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
          return events;
        }
        break;
      case 'soak':
        defender.activeTypesOverride = [PokemonType.water];
        events.add(BattleStepEvent(
          message: "$defenderName transformed into the Water type!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
        ));
        return events;
      case 'nightmare':
        if (defender.status != StatusCondition.sleep) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Nightmare! But it failed because $defenderName isn't asleep!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            hideMoveVfx: true,
          ));
        } else if (defender.hasNightmare) {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Nightmare, but $defenderName is already having a nightmare!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            isMiss: true,
            hideMoveVfx: true,
          ));
        } else if (defender.substituteHp > 0 && atkAb != 'infiltrator') {
          events.add(BattleStepEvent(
            message:
                "$attackerName used Nightmare! $defenderName's substitute blocked it!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'BLOCKED',
            targetHpAfter: defender.currentHp,
          ));
        } else {
          defender.hasNightmare = true;
          events.add(BattleStepEvent(
            message: "$defenderName began having a nightmare!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statusInflictedLabel: 'NIGHTMARE!',
            targetHpAfter: defender.currentHp,
          ));
        }
        return events;
      case 'conversion':
        final PokemonType nextType = attacker.activeMoves.first.type;
        attacker.activeTypesOverride = [nextType];
        events.add(BattleStepEvent(
          message: "$attackerName transformed into the ${nextType.displayName} type!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'conversion_2':
        final lastFoeMove = defender.lastMoveUsedId != null
            ? PokedexDatabase.moves[defender.lastMoveUsedId!]
            : null;
        PokemonType chosenType = PokemonType.steel;
        if (lastFoeMove != null) {
          final candidates = PokemonType.values.where((t) {
            final mult = PokemonTypeExtension.getEffectiveness(lastFoeMove.type, [t]);
            return mult < 1.0 && !attacker.effectiveTypes.contains(t);
          }).toList();
          if (candidates.isNotEmpty) {
            chosenType = candidates[random.nextInt(candidates.length)];
          }
        }
        attacker.activeTypesOverride = [chosenType];
        events.add(BattleStepEvent(
          message: "$attackerName transformed into the ${chosenType.displayName} type!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'camouflage':
        final PokemonType terrainType = switch (weather) {
          BattleWeather.sandstorm => PokemonType.rock,
          BattleWeather.rain => PokemonType.water,
          BattleWeather.hail => PokemonType.ice,
          _ => PokemonType.normal,
        };
        attacker.activeTypesOverride = [terrainType];
        events.add(BattleStepEvent(
          message: "$attackerName transformed into the ${terrainType.displayName} type!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'reflect_type':
        attacker.activeTypesOverride = List<PokemonType>.from(defender.effectiveTypes);
        events.add(BattleStepEvent(
          message: "$attackerName's type changed to match $defenderName's!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        return events;
      case 'transform':
        if (attacker.transformedMoves != null) {
          events.add(BattleStepEvent(
            message: "$attackerName used Transform, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        } else {
          _applyTransformCopy(attacker, defender);
          events.add(BattleStepEvent(
            message: "$attackerName transformed into ${defender.species.name}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        }
        return events;
      case 'metronome':
        const blockedMetronome = {
          'metronome', 'struggle', 'transform', 'mimic', 'copycat',
          'mirror_move', 'me_first', 'sleep_talk', 'snore', 'focus_punch',
        };
        final allPool = PokedexDatabase.moves.values
            .where((m) => !blockedMetronome.contains(m.id))
            .toList();
        if (allPool.isEmpty) break;
        final chosen = allPool[random.nextInt(allPool.length)];
        events.add(BattleStepEvent(
          message: "$attackerName used Metronome! Waggling a finger let it use ${chosen.name}!",
          isPlayerActor: isPlayer, hideMoveVfx: true,
        ));
        events.addAll(executeSingleAttack(
          attacker,
          chosen.copy(),
          defender,
          isPlayer: isPlayer,
          isWild: isWild,
          playerTrainer: playerTrainer,
          field: field,
          defenderIntendedMove: defenderIntendedMove,
          consumePp: false,
          isSubMove: true,
          rng: random,
        ));
        return events;
      case 'copycat':
      case 'mirror_move':
        const blockedCopy = {
          'copycat', 'mirror_move', 'metronome', 'sleep_talk', 'struggle',
        };
        final lastId = defender.lastMoveUsedId;
        final copied = lastId != null ? PokedexDatabase.moves[lastId] : null;
        if (copied == null || blockedCopy.contains(copied.id)) {
          events.add(BattleStepEvent(
            message: "$attackerName used ${move.name}, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName used ${move.name}! (${copied.name})",
            isPlayerActor: isPlayer, hideMoveVfx: true,
          ));
          events.addAll(executeSingleAttack(
            attacker,
            copied.copy(),
            defender,
            isPlayer: isPlayer,
            isWild: isWild,
            playerTrainer: playerTrainer,
            field: field,
            defenderIntendedMove: defenderIntendedMove,
            consumePp: false,
            isSubMove: true,
            rng: random,
          ));
        }
        return events;
      case 'me_first':
        const blockedMeFirst = {'me_first', 'counter', 'mirror_coat', 'focus_punch'};
        Move? candidate;
        if (defenderIntendedMove != null &&
            defenderIntendedMove.category != MoveCategory.status &&
            defenderIntendedMove.power > 0 &&
            !blockedMeFirst.contains(defenderIntendedMove.id)) {
          candidate = defenderIntendedMove;
        } else {
          final dmgs = defender.activeMoves
              .where((m) =>
                  m.category != MoveCategory.status &&
                  m.power > 0 &&
                  !blockedMeFirst.contains(m.id))
              .toList();
          if (dmgs.isNotEmpty) {
            candidate = dmgs[random.nextInt(dmgs.length)];
          }
        }
        if (candidate == null) {
          events.add(BattleStepEvent(
            message: "$attackerName used Me First, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName used Me First! (${candidate.name})",
            isPlayerActor: isPlayer, hideMoveVfx: true,
          ));
          events.addAll(executeSingleAttack(
            attacker,
            candidate.copy(),
            defender,
            isPlayer: isPlayer,
            isWild: isWild,
            playerTrainer: playerTrainer,
            field: field,
            defenderIntendedMove: defenderIntendedMove,
            consumePp: false,
            isSubMove: true,
            powerOverride: (candidate.power * 1.5).round(),
            rng: random,
          ));
        }
        return events;
      case 'mimic':
        final lastId = defender.lastMoveUsedId;
        final copied = lastId != null ? PokedexDatabase.moves[lastId] : null;
        if (copied == null ||
            copied.id == 'mimic' ||
            copied.id == 'transform' ||
            copied.id == 'metronome' ||
            copied.id == 'struggle') {
          events.add(BattleStepEvent(
            message: "$attackerName used Mimic, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        } else {
          final List<Move> working = attacker.transformedMoves ??
              attacker.moves.map((m) => m.copy()).toList();
          final int mimicIdx = working.indexWhere((m) => m.id == 'mimic');
          if (mimicIdx >= 0) {
            working[mimicIdx] = Move(
              id: copied.id,
              name: copied.name,
              type: copied.type,
              category: copied.category,
              power: copied.power,
              accuracy: copied.accuracy,
              maxPp: 5,
              currentPp: 5,
              priority: copied.priority,
              description: copied.description,
              statTarget: copied.statTarget,
              statChange: copied.statChange,
              statusEffect: copied.statusEffect,
              statusChance: copied.statusChance,
              minHits: copied.minHits,
              maxHits: copied.maxHits,
              stageMechanic: copied.stageMechanic,
              chargeStatusMessage: copied.chargeStatusMessage,
              chargeSelfStatTarget: copied.chargeSelfStatTarget,
              chargeSelfStatChange: copied.chargeSelfStatChange,
            );
            attacker.transformedMoves = working;
          }
          events.add(BattleStepEvent(
            message: "$attackerName learned ${copied.name}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
          ));
        }
        return events;
      case 'quick_guard':
      case 'wide_guard':
        final double successProb = 1.0 / pow(2, attacker.consecutiveProtectCount).toDouble();
        if (random.nextDouble() < successProb) {
          attacker.consecutiveProtectCount++;
          attacker.isProtectedThisTurn = true;
          events.add(BattleStepEvent(
            message: "$attackerName protected itself with ${move.name}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true, statusInflictedLabel: 'PROTECTED',
          ));
        } else {
          attacker.consecutiveProtectCount = 0;
          events.add(BattleStepEvent(
            message: "$attackerName used ${move.name}, but it failed!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
        }
        return events;
      case 'roar':
      case 'whirlwind':
        final bool foeSoundproof =
            move.id == 'roar' && !bypassDefAb && defAb == 'soundproof';
        if (foeSoundproof) {
          events.add(BattleStepEvent(
            message: "$defenderName's Soundproof blocked Roar!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, hideMoveVfx: true, abilityTriggeredName: 'Soundproof',
          ));
        } else {
          events.add(BattleStepEvent(
            message: "$attackerName blew $defenderName back with ${move.name}!",
            isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          ));
          _applySingleStatStage(
            target: defender,
            foe: attacker,
            stat: 'atk',
            delta: -1,
            targetLabel: defenderName,
            targetIsPlayer: !isPlayer,
            byFoe: true,
            bypassDefAbility: bypassDefAb,
            events: events,
            field: field,
          );
          _applySingleStatStage(
            target: defender,
            foe: attacker,
            stat: 'spa',
            delta: -1,
            targetLabel: defenderName,
            targetIsPlayer: !isPlayer,
            byFoe: true,
            bypassDefAbility: bypassDefAb,
            events: events,
            field: field,
          );
        }
        return events;
      case 'teleport':
        events.add(BattleStepEvent(
          message: "$attackerName warped across the battlefield!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category, statTargetIsSelf: true,
        ));
        _applySingleStatStage(
          target: attacker,
          foe: defender,
          stat: 'eva',
          delta: 1,
          targetLabel: attackerName,
          targetIsPlayer: isPlayer,
          byFoe: false,
          bypassDefAbility: bypassDefAb,
          events: events,
          field: field,
        );
        return events;
      case 'charge':
        attacker.isChargedElectric = true;
        attacker.modifyStatStage('spd', 1);
        events.add(BattleStepEvent(
          message: "$attackerName began charging power! Its Sp. Def rose!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statChangedLabel: 'SPD ▲',
          statTargetIsSelf: true,
          statusInflictedLabel: 'CHARGED!',
        ));
        return events;
      case 'healing_wish':
        selfSide.hasHealingWishPending = true;
        events.add(BattleStepEvent(
          message: "$attackerName made a Healing Wish!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
        ));
        appendSelfKo();
        return events;
      case 'magic_coat':
        attacker.hasMagicCoatThisTurn = true;
        events.add(BattleStepEvent(
          message: "$attackerName shrouded itself with Magic Coat!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          statusInflictedLabel: 'MAGIC COAT',
        ));
        return events;
      case 'imprison':
        if (attacker.isImprisoning) {
          events.add(BattleStepEvent(
            message: "$attackerName used Imprison, but it failed!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            isMiss: true,
          ));
        } else {
          attacker.isImprisoning = true;
          events.add(BattleStepEvent(
            message: "$attackerName sealed any moves shared with $defenderName!",
            isPlayerActor: isPlayer,
            moveId: move.id,
            moveType: move.type,
            moveCategory: move.category,
            statTargetIsSelf: true,
            statusInflictedLabel: 'IMPRISON!',
          ));
        }
        return events;
      case 'grudge':
        attacker.hasGrudge = true;
        events.add(BattleStepEvent(
          message: "$attackerName wants its foe to bear a grudge!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          statusInflictedLabel: 'GRUDGE!',
        ));
        return events;
      case 'helping_hand':
        attacker.helpingHandBoosted = true;
        events.add(BattleStepEvent(
          message: "$attackerName is ready to power up its next attack!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          statChangedLabel: 'PWR ▲',
        ));
        return events;
      case 'baton_pass':
        events.add(BattleStepEvent(
          message: "$attackerName prepared to pass its boosts!",
          isPlayerActor: isPlayer,
          moveId: move.id,
          moveType: move.type,
          moveCategory: move.category,
          statTargetIsSelf: true,
          requestBatonPassSwitch: true,
        ));
        return events;
      case 'ally_switch':
        _applySingleStatStage(
          target: attacker,
          foe: defender,
          stat: 'eva',
          delta: 1,
          targetLabel: attackerName,
          targetIsPlayer: isPlayer,
          byFoe: false,
          bypassDefAbility: bypassDefAb,
          events: events,
          move: move,
          actorLabel: attackerName,
          isPlayerActor: isPlayer,
          field: field,
        );
        return events;
      case 'follow_me':
        _applySingleStatStage(
          target: defender,
          foe: attacker,
          stat: 'acc',
          delta: -1,
          targetLabel: defenderName,
          targetIsPlayer: !isPlayer,
          byFoe: true,
          bypassDefAbility: bypassDefAb,
          events: events,
          move: move,
          actorLabel: attackerName,
          isPlayerActor: isPlayer,
          field: field,
        );
        return events;
      case 'after_you':
        _applySingleStatStage(
          target: attacker,
          foe: defender,
          stat: 'spe',
          delta: 1,
          targetLabel: attackerName,
          targetIsPlayer: isPlayer,
          byFoe: false,
          bypassDefAbility: bypassDefAb,
          events: events,
          move: move,
          actorLabel: attackerName,
          isPlayerActor: isPlayer,
          field: field,
        );
        return events;
    }

    // 6. Leech Seed
    if (move.id == 'leech_seed') {
      if (defender.effectiveTypes.contains(PokemonType.grass)) {
        events.add(BattleStepEvent(
          message: "$attackerName used Leech Seed! It doesn't affect $defenderName...",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          effectiveness: 0.0, targetHpAfter: defender.currentHp,
        ));
      } else if (defender.substituteHp > 0 && atkAb != 'infiltrator') {
        events.add(BattleStepEvent(
          message: "$attackerName used Leech Seed! $defenderName's substitute blocked it!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statusInflictedLabel: 'BLOCKED', targetHpAfter: defender.currentHp,
        ));
      } else if (defender.isSeeded) {
        events.add(BattleStepEvent(
          message: "$attackerName used Leech Seed, but $defenderName is already seeded!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          targetHpAfter: defender.currentHp,
        ));
      } else {
        defender.isSeeded = true;
        events.add(BattleStepEvent(
          message: "$defenderName was seeded!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statusInflictedLabel: 'SEEDED!', targetHpAfter: defender.currentHp,
        ));
      }
      return events;
    }

    // 7. Substitute
    if (move.id == 'substitute') {
      final int cost = max(1, attacker.maxHp ~/ 4);
      if (attacker.substituteHp > 0) {
        events.add(BattleStepEvent(
          message: "$attackerName already has a substitute!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statTargetIsSelf: true, targetHpAfter: attacker.currentHp,
        ));
      } else if (attacker.currentHp <= cost) {
        events.add(BattleStepEvent(
          message: "It was too weak to make a substitute!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statTargetIsSelf: true, targetHpAfter: attacker.currentHp,
        ));
      } else {
        attacker.currentHp -= cost;
        attacker.substituteHp = cost;
        events.add(BattleStepEvent(
          message: "$attackerName put up a substitute!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          damageDealt: cost, targetHpAfter: attacker.currentHp, statTargetIsSelf: true,
          statusInflictedLabel: 'SUBSTITUTE', isSelfDamage: true,
        ));
      }
      return events;
    }

    // 8. Swagger & Flatter (target stat buff + confusion!)
    if (move.id == 'swagger' || move.id == 'flatter') {
      final String sTarget = move.id == 'swagger' ? 'atk' : 'spa';
      final int delta = move.id == 'swagger' ? 2 : 1;
      defender.modifyStatStage(sTarget, delta);
      final confused = _tryInflictStatus(defender, 'confusion',
          random: random, field: field, targetIsPlayer: !isPlayer, bypassDefAbility: bypassDefAb);
      events.add(BattleStepEvent(
        message: confused != null
            ? "$attackerName used ${move.name}! $defenderName's ${_statDisplayName(sTarget)} rose and it became confused!"
            : "$attackerName used ${move.name}! $defenderName's ${_statDisplayName(sTarget)} rose!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statChangedLabel: '${sTarget.toUpperCase()} ▲',
        statusInflictedLabel: confused,
        targetHpAfter: defender.currentHp,
      ));
      return events;
    }

    // 9. Multi-stat status moves (Quiver Dance, Shell Smash, Growth, Memento, etc.)
    if (_multiStatMoves.containsKey(move.id)) {
      _applyMultiStats(
        attacker,
        defender,
        move.id,
        attackerName,
        defenderName,
        isPlayer,
        events,
        bypassDefAb: bypassDefAb,
        move: move,
        weather: weather,
      );
      appendSelfKo();
      return events;
    }

    // 10. Generic single stat or status moves
    if (move.statTarget != null && move.statChange != 0) {
      final bool selfBuff = move.statChange > 0;
      if (!selfBuff &&
          defender.substituteHp > 0 &&
          atkAb != 'infiltrator' &&
          !_soundMoves.contains(move.id)) {
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}! The substitute protected $defenderName!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statusInflictedLabel: 'BLOCKED', targetHpAfter: defender.currentHp,
        ));
        return events;
      }
      final targetMon = selfBuff ? attacker : defender;
      final foeMon = selfBuff ? defender : attacker;
      final ok = _applySingleStatStage(
        target: targetMon,
        foe: foeMon,
        stat: move.statTarget!,
        delta: move.statChange,
        targetLabel: selfBuff ? attackerName : defenderName,
        targetIsPlayer: selfBuff ? isPlayer : !isPlayer,
        byFoe: !selfBuff,
        bypassDefAbility: bypassDefAb,
        events: events,
        move: move,
        actorLabel: attackerName,
        isPlayerActor: isPlayer,
        field: field,
      );
      if (ok) {
        final berryEv = checkAndConsumeHeldBerry(defender,
            opponent: attacker, isPlayer: !isPlayer, isWild: isWild);
        if (berryEv != null) events.add(berryEv);
      }
      return events;
    }

    if (move.statusEffect != null) {
      if (defender.substituteHp > 0 &&
          atkAb != 'infiltrator' &&
          !_soundMoves.contains(move.id)) {
        events.add(BattleStepEvent(
          message: "$attackerName used ${move.name}! The substitute protected $defenderName!",
          isPlayerActor: isPlayer, moveId: move.id, moveType: move.type, moveCategory: move.category,
          statusInflictedLabel: 'BLOCKED', targetHpAfter: defender.currentHp,
        ));
        return events;
      }
      final inflicted = _tryInflictStatus(
        defender,
        move.statusEffect!,
        random: random,
        field: field,
        targetIsPlayer: !isPlayer,
        source: attacker,
        bypassDefAbility: bypassDefAb,
      );
      events.add(BattleStepEvent(
        message: inflicted != null
            ? "$attackerName used ${move.name}! $defenderName is $inflicted"
            : "$attackerName used ${move.name}, but it failed!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        statusInflictedLabel: inflicted,
        targetHpAfter: defender.currentHp,
      ));
      if (inflicted != null &&
          !bypassDefAb &&
          defAb == 'synchronize' &&
          (move.statusEffect == 'burn' ||
              move.statusEffect == 'poison' ||
              move.statusEffect == 'badly_poison' ||
              move.statusEffect == 'paralysis')) {
        final synced = _tryInflictStatus(
          attacker,
          move.statusEffect == 'badly_poison' ? 'poison' : move.statusEffect!,
          random: random,
          field: field,
          targetIsPlayer: isPlayer,
        );
        if (synced != null) {
          events.add(BattleStepEvent(
            message: "$defenderName's Synchronize passed $synced to $attackerName!",
            isPlayerActor: !isPlayer,
            statusInflictedLabel: synced,
            hideMoveVfx: true,
            abilityTriggeredName: 'Synchronize',
          ));
        }
      }
      final berryEv = checkAndConsumeHeldBerry(defender,
          opponent: attacker, isPlayer: !isPlayer, isWild: isWild);
      if (berryEv != null) events.add(berryEv);
      return events;
    }

    events.add(BattleStepEvent(
      message: "$attackerName used ${move.name}!" + (move.id == 'splash' ? " But nothing happened!" : ""),
      isPlayerActor: isPlayer,
      moveId: move.id,
      moveType: move.type,
      moveCategory: move.category,
      statTargetIsSelf: true,
      targetHpAfter: defender.currentHp,
    ));
    appendSelfKo();
    return events;
  }

  static void _applyMultiStats(
    PokemonInstance attacker,
    PokemonInstance defender,
    String moveId,
    String attackerName,
    String defenderName,
    bool isPlayer,
    List<BattleStepEvent> events, {
    required bool bypassDefAb,
    Move? move,
    BattleWeather weather = BattleWeather.none,
  }) {
    if (moveId == 'stockpile') {
      if (attacker.stockpileCount >= 3) {
        events.add(BattleStepEvent(
          message: "$attackerName can't stockpile any more!",
          isPlayerActor: isPlayer,
          moveId: move?.id,
          moveType: move?.type,
          moveCategory: move?.category,
          statTargetIsSelf: true,
        ));
        return;
      }
      attacker.stockpileCount++;
    }
    final entries = _multiStatMoves[moveId]!;
    final List<String> tags = [];
    for (final e in entries) {
      int delta = e.delta;
      if (moveId == 'growth' && weather == BattleWeather.sun) {
        delta *= 2;
      }
      final target = e.self ? attacker : defender;
      final applied = _canApplyStatDrop(target, e.stat, delta,
              byFoe: !e.self, bypassDefAbility: bypassDefAb)
          ? target.modifyStatStage(e.stat, delta)
          : 0;
      if (applied != 0) {
        tags.add("${e.stat.toUpperCase()} ${delta > 0 ? '▲' : '▼'}");
      }
    }
    final bool allSelf = entries.every((e) => e.self);
    events.add(BattleStepEvent(
      message: move != null
          ? "$attackerName used ${move.name}!"
          : (allSelf ? "$attackerName's stats changed!" : "$defenderName's stats changed!"),
      isPlayerActor: isPlayer,
      moveId: move?.id,
      moveType: move?.type,
      moveCategory: move?.category,
      statChangedLabel: tags.isNotEmpty ? tags.join(' ') : null,
      statTargetIsSelf: allSelf,
      targetHpAfter: defender.currentHp,
      hideMoveVfx: move == null,
    ));
  }

  static bool _canApplyStatDrop(
    PokemonInstance target,
    String stat,
    int delta, {
    required bool byFoe,
    required bool bypassDefAbility,
    BattleFieldState? field,
    bool targetIsPlayer = false,
  }) {
    if (delta >= 0 || !byFoe) return true;
    if (field != null && field.sideFor(targetIsPlayer).mistTurns > 0) return false;
    if (bypassDefAbility) return true;
    final ab = target.effectiveAbilityId;
    if (ab == 'clear_body') return false;
    if (ab == 'hyper_cutter' && stat == 'atk') return false;
    if (ab == 'big_pecks' && stat == 'def') return false;
    if (ab == 'keen_eye' && stat == 'acc') return false;
    return true;
  }

  static bool _applySingleStatStage({
    required PokemonInstance target,
    required PokemonInstance foe,
    required String stat,
    required int delta,
    required String targetLabel,
    required bool targetIsPlayer,
    required bool byFoe,
    required bool bypassDefAbility,
    required List<BattleStepEvent> events,
    Move? move,
    String? actorLabel,
    bool? isPlayerActor,
    BattleFieldState? field,
  }) {
    if (!_canApplyStatDrop(target, stat, delta,
        byFoe: byFoe,
        bypassDefAbility: bypassDefAbility,
        field: field,
        targetIsPlayer: targetIsPlayer)) {
      events.add(BattleStepEvent(
        message: "$targetLabel's ${AbilityDatabase.nameOf(target.effectiveAbilityId)} prevented stat loss!",
        isPlayerActor: isPlayerActor ?? targetIsPlayer,
        moveId: move?.id,
        moveType: move?.type,
        moveCategory: move?.category,
        abilityTriggeredName: AbilityDatabase.nameOf(target.effectiveAbilityId),
        hideMoveVfx: move == null,
      ));
      return false;
    }

    final int actualDelta = target.modifyStatStage(stat, delta);
    final statFullName = _statDisplayName(stat);
    final String arrow = delta > 0 ? '▲' : '▼';
    final String? statLabel = "${stat.toUpperCase()} $arrow";
    String msg;
    if (actualDelta == 0) {
      msg =
          "${move != null ? '${actorLabel ?? targetLabel} used ${move.name}! ' : ''}$targetLabel's $statFullName won't go any ${delta > 0 ? 'higher' : 'lower'}!";
    } else if (delta >= 2) {
      msg = "${move != null ? '${actorLabel ?? targetLabel} used ${move.name}! ' : ''}$targetLabel's $statFullName rose sharply!";
    } else if (delta > 0) {
      msg = "${move != null ? '${actorLabel ?? targetLabel} used ${move.name}! ' : ''}$targetLabel's $statFullName rose!";
    } else if (delta <= -2) {
      msg = "${move != null ? '${actorLabel ?? targetLabel} used ${move.name}! ' : ''}$targetLabel's $statFullName harshly fell!";
    } else {
      msg = "${move != null ? '${actorLabel ?? targetLabel} used ${move.name}! ' : ''}$targetLabel's $statFullName fell!";
    }

    events.add(BattleStepEvent(
      message: msg,
      isPlayerActor: isPlayerActor ?? targetIsPlayer,
      moveId: move?.id,
      moveType: move?.type,
      moveCategory: move?.category,
      statChangedLabel: statLabel,
      statTargetIsSelf: !byFoe,
      targetHpAfter: byFoe ? target.currentHp : foe.currentHp,
      hideMoveVfx: move == null,
    ));

    if (actualDelta < 0 && byFoe && target.effectiveAbilityId == 'defiant' && !target.isFainted) {
      target.modifyStatStage('atk', 2);
      events.add(BattleStepEvent(
        message: "$targetLabel's Defiant sharply raised its Attack!",
        isPlayerActor: targetIsPlayer,
        statChangedLabel: 'ATK ▲▲',
        statTargetIsSelf: true,
        hideMoveVfx: true,
        abilityTriggeredName: 'Defiant',
      ));
    }
    return actualDelta != 0;
  }

  static List<BattleStepEvent> _executeSpecialFormulaAttack({
    required PokemonInstance attacker,
    required Move move,
    required PokemonInstance defender,
    required bool isPlayer,
    bool? defenderIsPlayer,
    required bool isWild,
    required bool surfacedThisTurn,
    required Random random,
    BattleFieldState? field,
  }) {
    final List<BattleStepEvent> events = [];
    final bool defIsPlayer = defenderIsPlayer ?? !isPlayer;
    final attackerName = _labelFor(attacker, isPlayer, isWild);
    final defenderName = _labelFor(defender, defIsPlayer, isWild);
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = defender.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';

    double typeEff = _applyIdentifiedTypeOverride(
      PokemonTypeExtension.getEffectiveness(move.type, _defensiveTypes(defender)),
      move.type,
      defender,
      bypassGhostWithScrappy: atkAb == 'scrappy',
    );
    if (typeEff == 0.0) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}! It doesn't affect $defenderName...",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        effectiveness: 0.0,
        targetHpAfter: defender.currentHp,
        surfaceActorOnAttack: surfacedThisTurn,
      ));
      return events;
    }

    if (move.id == 'dream_eater' && defender.status != StatusCondition.sleep) {
      events.add(BattleStepEvent(
        message: "$attackerName used Dream Eater, but $defenderName isn't asleep!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        targetHpAfter: defender.currentHp,
      ));
      return events;
    }

    if (_ohkoMoves.contains(move.id) && !bypassDefAb && defAb == 'sturdy') {
      events.add(BattleStepEvent(
        message: "$defenderName's Sturdy protected it from the one-hit KO!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        hideMoveVfx: true,
        abilityTriggeredName: 'Sturdy',
      ));
      return events;
    }

    int fixedDmg;
    switch (move.id) {
      case 'dragon_rage':
        fixedDmg = 40;
        break;
      case 'sonic_boom':
        fixedDmg = 20;
        break;
      case 'seismic_toss':
      case 'night_shade':
        fixedDmg = attacker.level;
        break;
      case 'psywave':
        fixedDmg = max(1, (attacker.level * (50 + random.nextInt(101))) ~/ 100);
        break;
      case 'counter':
        fixedDmg = attacker.lastPhysicalDamageTakenThisTurn > 0
            ? attacker.lastPhysicalDamageTakenThisTurn * 2
            : 0;
        break;
      case 'mirror_coat':
        fixedDmg = attacker.lastSpecialDamageTakenThisTurn > 0
            ? attacker.lastSpecialDamageTakenThisTurn * 2
            : 0;
        break;
      case 'super_fang':
        fixedDmg = max(1, defender.currentHp ~/ 2);
        break;
      case 'endeavor':
        fixedDmg = max(0, defender.currentHp - attacker.currentHp);
        break;
      case 'final_gambit':
        fixedDmg = attacker.currentHp;
        break;
      case 'guillotine':
      case 'horn_drill':
      case 'fissure':
      case 'sheer_cold':
        fixedDmg = defender.currentHp;
        break;
      default:
        fixedDmg = max(1, attacker.level);
    }

    if (fixedDmg <= 0) {
      events.add(BattleStepEvent(
        message: "$attackerName used ${move.name}, but it failed!",
        isPlayerActor: isPlayer,
        moveId: move.id,
        moveType: move.type,
        moveCategory: move.category,
        targetHpAfter: defender.currentHp,
      ));
      return events;
    }

    if (!bypassDefAb &&
        defAb == 'sturdy' &&
        defender.currentHp == defender.maxHp &&
        fixedDmg >= defender.currentHp) {
      fixedDmg = max(0, defender.currentHp - 1);
    }

    final int prevHp = defender.currentHp;
    defender.currentHp = (defender.currentHp - fixedDmg).clamp(0, defender.maxHp);
    final int actualLost = max(0, prevHp - defender.currentHp);
    defender.lastDamageTakenThisTurn += actualLost;
    if (move.category == MoveCategory.physical) {
      defender.lastPhysicalDamageTakenThisTurn += actualLost;
    } else if (move.category == MoveCategory.special) {
      defender.lastSpecialDamageTakenThisTurn += actualLost;
    }

    events.add(BattleStepEvent(
      message: _ohkoMoves.contains(move.id)
          ? "$attackerName used ${move.name}! It's a one-hit KO!"
          : "$attackerName used ${move.name}!",
      isPlayerActor: isPlayer,
      moveId: move.id,
      moveType: move.type,
      moveCategory: move.category,
      damageDealt: fixedDmg,
      targetHpAfter: defender.currentHp,
      effectiveness: typeEff,
      targetFainted: defender.isFainted,
      surfaceActorOnAttack: surfacedThisTurn,
    ));

    if (move.id == 'final_gambit' && !attacker.isFainted) {
      attacker.currentHp = 0;
      events.add(BattleStepEvent(
        message: "$attackerName fainted from Final Gambit!",
        isPlayerActor: isPlayer,
        damageDealt: fixedDmg,
        targetHpAfter: 0,
        targetFainted: true,
        isSelfDamage: true,
        hideMoveVfx: true,
      ));
      events.add(BattleStepEvent(
        message: "$attackerName fainted!",
        isPlayerActor: !isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }

    if (defender.isFainted) {
      events.add(BattleStepEvent(
        message: "$defenderName fainted!",
        isPlayerActor: isPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
      if (defender.hasGrudge && move.currentPp > 0) {
        move.currentPp = 0;
        events.add(BattleStepEvent(
          message: "$attackerName's ${move.name} lost all its PP due to the grudge!",
          isPlayerActor: !isPlayer,
          hideMoveVfx: true,
        ));
      }
    }
    return events;
  }

  // ─── END-OF-TURN PROCESSING ─────────────────────────────────────────────────
  static List<BattleStepEvent> processEndOfTurnStatus(
    PokemonInstance mon, {
    PokemonInstance? opponent,
    required bool isPlayer,
    required bool isWild,
    BattleFieldState? field,
  }) {
    final List<BattleStepEvent> events = [];
    if (mon.isFainted) return events;
    final monName = _labelFor(mon, isPlayer, isWild);
    final String ab = mon.effectiveAbilityId;
    final bool magicGuard = ab == 'magic_guard';
    final weather = field?.effectiveWeather(mon, opponent) ?? BattleWeather.none;

    // 1. Shed Skin / Hydration / Healer end-of-turn cures
    if (mon.status != StatusCondition.none) {
      if (ab == 'hydration' && weather == BattleWeather.rain) {
        mon.status = StatusCondition.none;
        mon.isBadlyPoisoned = false;
        events.add(BattleStepEvent(
          message: "$monName's Hydration cured its status condition!",
          isPlayerActor: isPlayer, statusInflictedLabel: 'CURED', hideMoveVfx: true, abilityTriggeredName: 'Hydration',
        ));
      } else if (ab == 'shed_skin' && _rng.nextInt(100) < 30) {
        mon.status = StatusCondition.none;
        mon.isBadlyPoisoned = false;
        events.add(BattleStepEvent(
          message: "$monName shed its skin and cured its status condition!",
          isPlayerActor: isPlayer, statusInflictedLabel: 'CURED', hideMoveVfx: true, abilityTriggeredName: 'Shed Skin',
        ));
      } else if (ab == 'healer' && _rng.nextInt(100) < 30) {
        mon.status = StatusCondition.none;
        mon.isBadlyPoisoned = false;
        events.add(BattleStepEvent(
          message: "$monName's Healer soothed its status condition!",
          isPlayerActor: isPlayer, statusInflictedLabel: 'CURED', hideMoveVfx: true, abilityTriggeredName: 'Healer',
        ));
      }
    }

    // 2. Burn / Poison ticks (ignored by Magic Guard!)
    if ((mon.status == StatusCondition.burn || mon.status == StatusCondition.poison) && !magicGuard) {
      final bool isBurn = mon.status == StatusCondition.burn;
      final bool isToxic = !isBurn && mon.isBadlyPoisoned;
      final int tickDmg = isToxic
          ? max(1, (mon.maxHp * mon.toxicCounter) ~/ 16)
          : max(1, mon.maxHp ~/ 8);
      if (isToxic) mon.toxicCounter = min(15, mon.toxicCounter + 1);
      mon.currentHp = (mon.currentHp - tickDmg).clamp(0, mon.maxHp);
      events.add(BattleStepEvent(
        message: isBurn
            ? "$monName was hurt by its burn!"
            : (isToxic ? "$monName is hurt by toxin!" : "$monName was hurt by poison!"),
        isPlayerActor: !isPlayer,
        moveType: isBurn ? PokemonType.fire : PokemonType.poison,
        damageDealt: tickDmg,
        targetHpAfter: mon.currentHp,
        targetFainted: mon.isFainted,
        isStatusTick: true,
      ));
      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
        ));
        return events;
      }
    }

    // 3. Weather Abilities & Damage (Rain Dish, Dry Skin, Solar Power, Ice Body, Sandstorm, Hail)
    if (weather == BattleWeather.rain) {
      if ((ab == 'rain_dish' || ab == 'dry_skin') && mon.currentHp < mon.maxHp) {
        final int frac = ab == 'dry_skin' ? 8 : 16;
        final int heal = min(max(1, mon.maxHp ~/ frac), mon.maxHp - mon.currentHp);
        mon.currentHp += heal;
        events.add(BattleStepEvent(
          message: "$monName restored HP with ${AbilityDatabase.nameOf(ab)}!",
          isPlayerActor: isPlayer, healAmount: heal, targetHpAfter: mon.currentHp, isStatusTick: true,
        ));
      }
    } else if (weather == BattleWeather.sun && !magicGuard) {
      if (ab == 'dry_skin' || ab == 'solar_power') {
        final int chip = max(1, mon.maxHp ~/ 8);
        mon.currentHp = (mon.currentHp - chip).clamp(0, mon.maxHp);
        events.add(BattleStepEvent(
          message: "$monName lost HP from the harsh sunlight (${AbilityDatabase.nameOf(ab)})!",
          isPlayerActor: !isPlayer, moveType: PokemonType.fire, damageDealt: chip,
          targetHpAfter: mon.currentHp, targetFainted: mon.isFainted, isStatusTick: true,
        ));
        if (mon.isFainted) {
          events.add(BattleStepEvent(
            message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
          ));
          return events;
        }
      }
    } else if (weather == BattleWeather.sandstorm && !magicGuard) {
      final bool immune = mon.effectiveTypes.contains(PokemonType.rock) ||
          mon.effectiveTypes.contains(PokemonType.ground) ||
          mon.effectiveTypes.contains(PokemonType.steel) ||
          ab == 'sand_veil' || ab == 'sand_rush' || ab == 'sand_force' || ab == 'overcoat';
      if (!immune) {
        final int chip = max(1, mon.maxHp ~/ 16);
        mon.currentHp = (mon.currentHp - chip).clamp(0, mon.maxHp);
        events.add(BattleStepEvent(
          message: "$monName is buffeted by the sandstorm!",
          isPlayerActor: !isPlayer, moveType: PokemonType.rock, damageDealt: chip,
          targetHpAfter: mon.currentHp, targetFainted: mon.isFainted, isStatusTick: true,
        ));
        if (mon.isFainted) {
          events.add(BattleStepEvent(
            message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
          ));
          return events;
        }
      }
    } else if (weather == BattleWeather.hail) {
      if (ab == 'ice_body' && mon.currentHp < mon.maxHp) {
        final int heal = min(max(1, mon.maxHp ~/ 16), mon.maxHp - mon.currentHp);
        mon.currentHp += heal;
        events.add(BattleStepEvent(
          message: "$monName restored HP with Ice Body!",
          isPlayerActor: isPlayer, healAmount: heal, targetHpAfter: mon.currentHp, isStatusTick: true,
        ));
      } else if (!magicGuard &&
          !mon.effectiveTypes.contains(PokemonType.ice) &&
          ab != 'snow_cloak' &&
          ab != 'overcoat' &&
          ab != 'ice_body') {
        final int chip = max(1, mon.maxHp ~/ 16);
        mon.currentHp = (mon.currentHp - chip).clamp(0, mon.maxHp);
        events.add(BattleStepEvent(
          message: "$monName is buffeted by the hail!",
          isPlayerActor: !isPlayer, moveType: PokemonType.ice, damageDealt: chip,
          targetHpAfter: mon.currentHp, targetFainted: mon.isFainted, isStatusTick: true,
        ));
        if (mon.isFainted) {
          events.add(BattleStepEvent(
            message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
          ));
          return events;
        }
      }
    }

    // 4. Leech Seed sapping (blocked by Magic Guard)
    if (!mon.isFainted && mon.isSeeded && !magicGuard) {
      final int seedDmg = max(1, mon.maxHp ~/ 8);
      final int prevHp = mon.currentHp;
      mon.currentHp = (mon.currentHp - seedDmg).clamp(0, mon.maxHp);
      final int drained = max(0, prevHp - mon.currentHp);
      events.add(BattleStepEvent(
        message: "$monName's health is sapped by Leech Seed!",
        isPlayerActor: !isPlayer, moveId: 'leech_seed', moveType: PokemonType.grass,
        damageDealt: drained, targetHpAfter: mon.currentHp, targetFainted: mon.isFainted, isStatusTick: true,
      ));
      if (opponent != null && !opponent.isFainted && drained > 0 && opponent.currentHp < opponent.maxHp) {
        final int actualHeal = min(drained, opponent.maxHp - opponent.currentHp);
        opponent.currentHp += actualHeal;
        events.add(BattleStepEvent(
          message: "${_labelFor(opponent, !isPlayer, isWild)} absorbed Leech Seed energy! (+$actualHeal HP)",
          isPlayerActor: !isPlayer, healAmount: actualHeal, targetHpAfter: opponent.currentHp, isStatusTick: true, hideMoveVfx: true,
        ));
      }
      if (mon.isFainted) {
        events.add(BattleStepEvent(
          message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
        ));
        return events;
      }
    }

    // 4b. Nightmare (1/4 max HP while asleep, ignored by Magic Guard)
    if (!mon.isFainted && mon.hasNightmare) {
      if (mon.status != StatusCondition.sleep) {
        mon.hasNightmare = false;
      } else if (!magicGuard) {
        final int nightmareDmg = max(1, mon.maxHp ~/ 4);
        mon.currentHp = (mon.currentHp - nightmareDmg).clamp(0, mon.maxHp);
        events.add(BattleStepEvent(
          message: "$monName is locked in a nightmare!",
          isPlayerActor: !isPlayer,
          moveId: 'nightmare',
          moveType: PokemonType.ghost,
          damageDealt: nightmareDmg,
          targetHpAfter: mon.currentHp,
          targetFainted: mon.isFainted,
          isStatusTick: true,
        ));
        if (mon.isFainted) {
          mon.hasNightmare = false;
          events.add(BattleStepEvent(
            message: "$monName fainted!",
            isPlayerActor: !isPlayer,
            targetHpAfter: 0,
            targetFainted: true,
          ));
          return events;
        }
      }
    }

    // 5. Partial trapping chip damage
    if (!mon.isFainted && mon.trappedTurnsRemaining > 0 && !magicGuard) {
      final trapDmg = max(1, mon.maxHp ~/ 8);
      final trapName = mon.trappedByMoveName ?? 'the vortex';
      final trapMoveId = mon.trappedByMoveId;
      mon.currentHp = (mon.currentHp - trapDmg).clamp(0, mon.maxHp);
      mon.trappedTurnsRemaining--;
      events.add(BattleStepEvent(
        message: "$monName is hurt by $trapName!",
        isPlayerActor: !isPlayer, moveId: trapMoveId,
        moveType: trapMoveId == 'fire_spin' ? PokemonType.fire : PokemonType.normal,
        damageDealt: trapDmg, targetHpAfter: mon.currentHp, targetFainted: mon.isFainted, isStatusTick: true,
      ));
      if (mon.isFainted) {
        mon.trappedTurnsRemaining = 0;
        events.add(BattleStepEvent(
          message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
        ));
        return events;
      } else if (mon.trappedTurnsRemaining == 0) {
        mon.trappedByMoveId = null;
        mon.trappedByMoveName = null;
        events.add(BattleStepEvent(
          message: "$monName was freed from $trapName!",
          isPlayerActor: !isPlayer, targetHpAfter: mon.currentHp, hideMoveVfx: true,
        ));
      }
    }

    // 6. Leftovers / Ingrain / Aqua Ring / Harvest
    if (!mon.isFainted && (mon.isIngrained || mon.hasAquaRing) && mon.currentHp < mon.maxHp) {
      final int heal = min(max(1, mon.maxHp ~/ 16), mon.maxHp - mon.currentHp);
      mon.currentHp += heal;
      events.add(BattleStepEvent(
        message: "$monName restored a little HP!",
        isPlayerActor: isPlayer, healAmount: heal, targetHpAfter: mon.currentHp, isStatusTick: true,
      ));
    }
    if (!mon.isFainted && mon.heldItemId == 'leftovers' && mon.currentHp < mon.maxHp) {
      final int heal = min(max(1, mon.maxHp ~/ 16), mon.maxHp - mon.currentHp);
      mon.currentHp += heal;
      events.add(BattleStepEvent(
        message: "$monName restored a little HP with its Leftovers!",
        isPlayerActor: isPlayer, healAmount: heal, targetHpAfter: mon.currentHp, isStatusTick: true,
      ));
    }
    if (!mon.isFainted &&
        ab == 'harvest' &&
        !mon.hasHeldItem &&
        mon.consumedBerryIdForHarvest != null &&
        (weather == BattleWeather.sun || _rng.nextBool())) {
      final restoredId = mon.consumedBerryIdForHarvest!;
      mon.equipHeldItem(restoredId);
      mon.consumedBerryIdForHarvest = null;
      events.add(BattleStepEvent(
        message: "$monName harvested one ${ItemDatabase.byId(restoredId)?.name ?? restoredId}!",
        isPlayerActor: isPlayer, hideMoveVfx: true, abilityTriggeredName: 'Harvest',
      ));
    }

    // 7. Yawn / Perish Song / Taunt / Encore / Magnet Rise countdowns
    if (!mon.isFainted && mon.isYawnDrowsy) {
      mon.isYawnDrowsy = false;
      final asleep = _tryInflictStatus(mon, 'sleep', field: field, targetIsPlayer: isPlayer);
      if (asleep != null) {
        events.add(BattleStepEvent(
          message: "$monName fell asleep!",
          isPlayerActor: !isPlayer, statusInflictedLabel: asleep, hideMoveVfx: true,
        ));
      }
    }
    if (mon.tauntTurnsRemaining > 0) {
      mon.tauntTurnsRemaining--;
      if (mon.tauntTurnsRemaining <= 0) mon.isTaunted = false;
    }
    if (mon.encoreTurnsRemaining > 0) {
      mon.encoreTurnsRemaining--;
      if (mon.encoreTurnsRemaining <= 0) mon.encoredMoveId = null;
    }
    if (mon.magnetRiseTurnsRemaining > 0) {
      mon.magnetRiseTurnsRemaining--;
      if (mon.magnetRiseTurnsRemaining <= 0) mon.hasMagnetRise = false;
    }
    if (mon.sureHitAgainstTurns > 0) {
      mon.sureHitAgainstTurns--;
    }
    if (mon.disableTurnsRemaining > 0) {
      mon.disableTurnsRemaining--;
      if (mon.disableTurnsRemaining <= 0) {
        mon.disabledMoveId = null;
        events.add(BattleStepEvent(
          message: "$monName's move is no longer disabled!",
          isPlayerActor: isPlayer, hideMoveVfx: true,
        ));
      }
    }
    if (!mon.isFainted && mon.perishTurnsRemaining > 0) {
      mon.perishTurnsRemaining--;
      if (mon.perishTurnsRemaining == 0) {
        final cost = mon.currentHp;
        mon.currentHp = 0;
        events.add(BattleStepEvent(
          message: "$monName's perish count fell to 0!",
          isPlayerActor: !isPlayer, damageDealt: cost, targetHpAfter: 0, targetFainted: true, isStatusTick: true,
        ));
        events.add(BattleStepEvent(
          message: "$monName fainted!", isPlayerActor: !isPlayer, targetHpAfter: 0, targetFainted: true,
        ));
      } else {
        events.add(BattleStepEvent(
          message: "$monName's perish count fell to ${mon.perishTurnsRemaining}!",
          isPlayerActor: isPlayer, hideMoveVfx: true,
        ));
      }
    }

    // Speed Boost end-of-turn Speed raise
    if (!mon.isFainted && ab == 'speed_boost') {
      final delta = mon.modifyStatStage('spe', 1);
      if (delta != 0) {
        events.add(BattleStepEvent(
          message: "$monName's Speed Boost raised its Speed!",
          isPlayerActor: isPlayer,
          statChangedLabel: 'SPE ▲',
          statTargetIsSelf: true,
          hideMoveVfx: true,
          abilityTriggeredName: 'Speed Boost',
        ));
      }
    }

    return events;
  }

  static void _resolveFutureSightForSide({
    required BattleFieldState field,
    required bool targetIsPlayer,
    required PokemonInstance playerMon,
    required PokemonInstance opponentMon,
    required bool isWild,
    required Trainer? playerTrainer,
    required Random random,
    required List<BattleStepEvent> events,
  }) {
    final side = field.sideFor(targetIsPlayer);
    if (side.futureSightTurns <= 0) return;
    side.futureSightTurns--;
    if (side.futureSightTurns > 0) return;

    final attacker = side.futureSightAttacker;
    final fromPlayer = side.futureSightFromPlayer;
    final move = side.futureSightMove ??
        PokedexDatabase.moves['future_sight']?.copy() ??
        Move(
          id: 'future_sight',
          name: 'Future Sight',
          type: PokemonType.psychic,
          category: MoveCategory.special,
          power: 120,
          accuracy: 100,
          maxPp: 10,
          description:
              'Two turns after this move is used, a hunk of psychic energy attacks the target.',
        );
    side.clearFutureSight();

    final target = targetIsPlayer ? playerMon : opponentMon;
    if (attacker == null || target.isFainted) return;

    final targetName = _labelFor(target, targetIsPlayer, isWild);
    final String atkAb = attacker.effectiveAbilityId;
    final String defAb = target.effectiveAbilityId;
    final bool bypassDefAb = atkAb == 'mold_breaker';
    final bool noGuard = atkAb == 'no_guard' || defAb == 'no_guard';

    // Gen V Future Sight bypasses Protect/Detect, but semi-invulnerable targets avoid it unless No Guard
    if (target.isUnderground && !noGuard) {
      events.add(BattleStepEvent(
        message: "$targetName avoided the Future Sight attack!",
        isPlayerActor: fromPlayer,
        moveId: 'future_sight',
        moveType: PokemonType.psychic,
        moveCategory: MoveCategory.special,
        isMiss: true,
      ));
      return;
    }

    final hitResult = _computeHitDamage(
      attacker: attacker,
      move: move,
      defender: target,
      isPlayer: fromPlayer,
      playerTrainer: playerTrainer,
      random: random,
      field: field,
    );

    if (hitResult.typeMultiplier == 0.0) {
      events.add(BattleStepEvent(
        message:
            "$targetName took the Future Sight attack! It doesn't affect $targetName...",
        isPlayerActor: fromPlayer,
        moveId: 'future_sight',
        moveType: PokemonType.psychic,
        moveCategory: MoveCategory.special,
        effectiveness: 0.0,
        targetHpAfter: target.currentHp,
      ));
      return;
    }

    if (target.substituteHp > 0 && atkAb != 'infiltrator') {
      target.substituteHp = max(0, target.substituteHp - hitResult.damage);
      final bool broke = target.substituteHp <= 0;
      events.add(BattleStepEvent(
        message: broke
            ? "$targetName took the Future Sight attack! $targetName's substitute broke!"
            : "$targetName took the Future Sight attack! The substitute took the damage for $targetName!",
        isPlayerActor: fromPlayer,
        moveId: 'future_sight',
        moveType: PokemonType.psychic,
        moveCategory: MoveCategory.special,
        damageDealt: 0,
        targetHpAfter: target.currentHp,
        isCrit: hitResult.isCrit,
        effectiveness: hitResult.typeMultiplier,
        statusInflictedLabel: broke ? 'SUB BROKE!' : 'SUBSTITUTE!',
      ));
      return;
    }

    int dealtDamage = hitResult.damage;
    bool sturdySaved = false;
    bool enduredHit = false;
    if (dealtDamage >= target.currentHp) {
      if (target.isEnduringThisTurn) {
        dealtDamage = max(0, target.currentHp - 1);
        enduredHit = true;
      } else if (!bypassDefAb &&
          defAb == 'sturdy' &&
          target.currentHp == target.maxHp) {
        dealtDamage = max(0, target.currentHp - 1);
        sturdySaved = true;
      }
    }

    final int prevHp = target.currentHp;
    target.currentHp = (target.currentHp - dealtDamage).clamp(0, target.maxHp);
    final int actualLost = max(0, prevHp - target.currentHp);
    target.lastDamageTakenThisTurn += actualLost;
    target.lastSpecialDamageTakenThisTurn += actualLost;
    if (target.bideTurnsRemaining > 0 && actualLost > 0) {
      target.bideDamageStored += actualLost;
    }

    final msgBuffer = StringBuffer("$targetName took the Future Sight attack!");
    if (hitResult.isCrit) msgBuffer.write(" A critical hit!");
    if (hitResult.typeMultiplier >= 2.0) {
      msgBuffer.write(" It's super effective!");
    } else if (hitResult.typeMultiplier > 0 && hitResult.typeMultiplier < 1.0) {
      msgBuffer.write(" It's not very effective...");
    }
    if (sturdySaved) {
      msgBuffer.write(" $targetName endured the hit with Sturdy!");
    } else if (enduredHit) {
      msgBuffer.write(" $targetName endured the hit!");
    }

    events.add(BattleStepEvent(
      message: msgBuffer.toString(),
      isPlayerActor: fromPlayer,
      moveId: 'future_sight',
      moveType: PokemonType.psychic,
      moveCategory: MoveCategory.special,
      damageDealt: dealtDamage,
      targetHpAfter: target.currentHp,
      isCrit: hitResult.isCrit,
      effectiveness: hitResult.typeMultiplier,
      targetFainted: target.isFainted,
      abilityTriggeredName: sturdySaved ? 'Sturdy' : null,
    ));

    if (!target.isFainted) {
      final berryEv = checkAndConsumeHeldBerry(
        target,
        opponent: targetIsPlayer ? opponentMon : playerMon,
        isPlayer: targetIsPlayer,
        isWild: isWild,
      );
      if (berryEv != null) events.add(berryEv);
    } else {
      events.add(BattleStepEvent(
        message: "$targetName fainted!",
        isPlayerActor: fromPlayer,
        targetHpAfter: 0,
        targetFainted: true,
      ));
    }
  }

  static List<BattleStepEvent> processEndOfTurnField(
    BattleFieldState field,
    PokemonInstance playerMon,
    PokemonInstance opponentMon, {
    bool isWild = true,
    Trainer? playerTrainer,
    Random? rng,
    bool playerSideFirst = true,
  }) {
    final List<BattleStepEvent> events = [];
    final random = rng ?? _rng;

    final sideOrder = playerSideFirst ? [true, false] : [false, true];
    for (final targetIsPlayer in sideOrder) {
      _resolveFutureSightForSide(
        field: field,
        targetIsPlayer: targetIsPlayer,
        playerMon: playerMon,
        opponentMon: opponentMon,
        isWild: isWild,
        playerTrainer: playerTrainer,
        random: random,
        events: events,
      );
    }

    field.playerSide.tickTurn();
    field.opponentSide.tickTurn();
    if (field.gravityTurns > 0) field.gravityTurns--;
    if (field.uproarTurns > 0) field.uproarTurns--;
    if (field.wonderRoomTurns > 0) {
      field.wonderRoomTurns--;
      if (field.wonderRoomTurns == 0) {
        events.add(BattleStepEvent(
          message: "Wonder Room wore off, and Defense and Sp. Def stats returned to normal!",
          isPlayerActor: true,
          hideMoveVfx: true,
        ));
      }
    }

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
        events.add(BattleStepEvent(
          message: endedMsg,
          isPlayerActor: true,
          hideMoveVfx: true,
        ));
      }
    }
    return events;
  }

  static String? _tryInflictStatus(
    PokemonInstance target,
    String effect, {
    Random? random,
    BattleFieldState? field,
    bool targetIsPlayer = false,
    PokemonInstance? source,
    bool bypassDefAbility = false,
  }) {
    if (target.isFainted) return null;
    if (field != null && field.sideFor(targetIsPlayer).safeguardTurns > 0) return null;

    final String ab = target.effectiveAbilityId;
    if (!bypassDefAbility &&
        ab == 'leaf_guard' &&
        field?.effectiveWeather(target, source) == BattleWeather.sun) {
      return null;
    }

    if (effect == 'confusion') {
      if (target.isConfused || (!bypassDefAbility && ab == 'own_tempo')) return null;
      final r = random ?? _rng;
      target.isConfused = true;
      target.confusionTurnsRemaining = 2 + r.nextInt(4);
      return 'CONFUSED!';
    }
    if (target.status != StatusCondition.none) return null;

    switch (effect) {
      case 'burn':
        if (target.effectiveTypes.contains(PokemonType.fire) ||
            (!bypassDefAbility && ab == 'water_veil')) {
          return null;
        }
        target.status = StatusCondition.burn;
        return 'BURNED!';
      case 'poison':
        if (target.effectiveTypes.contains(PokemonType.poison) ||
            target.effectiveTypes.contains(PokemonType.steel) ||
            (!bypassDefAbility && ab == 'immunity')) {
          return null;
        }
        target.status = StatusCondition.poison;
        target.isBadlyPoisoned = false;
        target.toxicCounter = 1;
        return 'POISONED!';
      case 'badly_poison':
        if (target.effectiveTypes.contains(PokemonType.poison) ||
            target.effectiveTypes.contains(PokemonType.steel) ||
            (!bypassDefAbility && ab == 'immunity')) {
          return null;
        }
        target.status = StatusCondition.poison;
        target.isBadlyPoisoned = true;
        target.toxicCounter = 1;
        return 'BADLY POISONED!';
      case 'paralysis':
        if (target.effectiveTypes.contains(PokemonType.electric) ||
            (!bypassDefAbility && ab == 'limber')) {
          return null;
        }
        target.status = StatusCondition.paralysis;
        return 'PARALYZED!';
      case 'sleep':
        if (field != null && field.uproarTurns > 0) {
          return null;
        }
        if (!bypassDefAbility && (ab == 'insomnia' || ab == 'vital_spirit')) {
          return null;
        }
        target.status = StatusCondition.sleep;
        target.sleepTurnsRemaining = 2 + (random ?? _rng).nextInt(3);
        return 'ASLEEP!';
      case 'freeze':
        if (target.effectiveTypes.contains(PokemonType.ice) ||
            field?.effectiveWeather(target, source) == BattleWeather.sun) {
          return null;
        }
        target.status = StatusCondition.freeze;
        return 'FROZEN!';
      default:
        return null;
    }
  }

  static String _statDisplayName(String stat) {
    switch (stat) {
      case 'atk':
        return 'Attack';
      case 'def':
        return 'Defense';
      case 'spa':
        return 'Sp. Atk';
      case 'spd':
        return 'Sp. Def';
      case 'spe':
        return 'Speed';
      case 'acc':
        return 'Accuracy';
      case 'eva':
        return 'Evasiveness';
      default:
        return stat.toUpperCase();
    }
  }

  static bool isNightTime([DateTime? now]) {
    final int hour = (now ?? DateTime.now()).hour;
    return hour >= 20 || hour < 6;
  }

  /// Effective catch multiplier for all Poké Balls in standard wild encounters.
  /// Special Poké Balls grant no bonus modifiers on Legendaries or Mythicals
  /// and use the regular Poké Ball rate (1.0x) instead.
  static double getBallCatchMultiplier({
    required String ballType,
    required PokemonInstance target,
    PokemonInstance? playerPokemon,
    int turnNumber = 1,
    bool isAlreadyCaught = false,
    bool isExpedition = false,
    bool? isNight,
  }) {
    if ((target.species.isLegendary || target.species.isMythical) &&
        ItemDatabase.specialBallIds.contains(ballType)) {
      return 1.0;
    }
    switch (ballType) {
      case 'great_ball':
        return 1.5;
      case 'ultra_ball':
        return 2.0;
      case 'master_ball':
        return 255.0;
      case 'quick_ball':
        return turnNumber <= 1 ? 5.0 : 1.0;
      case 'timer_ball':
        return min(4.0, 1.0 + max(0, turnNumber - 1) * 0.3);
      case 'dusk_ball':
        return (isExpedition || (isNight ?? isNightTime())) ? 3.0 : 1.0;
      case 'net_ball':
        final hasNetType = target.species.types.any(
          (t) => t == PokemonType.water || t == PokemonType.bug,
        );
        return hasNetType ? 3.5 : 1.0;
      case 'fast_ball':
        return target.species.baseSpe >= 100 ? 4.0 : 1.0;
      case 'dream_ball':
        return target.status == StatusCondition.sleep ? 4.0 : 1.0;
      case 'repeat_ball':
        return isAlreadyCaught ? 3.5 : 1.0;
      case 'level_ball':
        if (playerPokemon == null) return 1.0;
        if (playerPokemon.level >= target.level * 2) return 4.0;
        if (playerPokemon.level > target.level) return 2.0;
        return 1.0;
      case 'heal_ball':
        return 1.5;
      case 'poke_ball':
      default:
        return 1.0;
    }
  }

  /// Gen 4 Capture Formula
  static bool attemptCapture({
    required PokemonInstance target,
    required String ballType,
    PokemonInstance? playerPokemon,
    int turnNumber = 1,
    bool isAlreadyCaught = false,
    bool isExpedition = false,
    bool? isNight,
    Random? rng,
  }) {
    if (ballType == 'master_ball') return true;
    final double ballMod = getBallCatchMultiplier(
      ballType: ballType,
      target: target,
      playerPokemon: playerPokemon,
      turnNumber: turnNumber,
      isAlreadyCaught: isAlreadyCaught,
      isExpedition: isExpedition,
      isNight: isNight,
    );

    final int maxHp = target.maxHp;
    final int curHp = target.currentHp;
    final int catchRate = target.species.baseCatchRate;

    double statusMod = 1.0;
    if (target.status == StatusCondition.sleep || target.status == StatusCondition.freeze) {
      statusMod = 2.0;
    } else if (target.status != StatusCondition.none) {
      statusMod = 1.5;
    }

    final double a =
        (((3 * maxHp - 2 * curHp) * catchRate * ballMod) / (3 * maxHp)) * statusMod;
    if (a >= 255) return true;

    final Random rand = rng ?? _rng;
    final double b = 65536.0 * pow(a / 255.0, 0.25).toDouble();
    for (int i = 0; i < 4; i++) {
      if (rand.nextInt(65536) >= b) {
        return false;
      }
    }
    return true;
  }

  /// Catch probability used during Expedition Legendary / Mythical boss KO phase.
  /// Special Poké Balls have the same catch rate as a regular Poké Ball (1%).
  static double getLegendaryKoCatchRate({
    required String ballType,
    required PokemonInstance target,
    PokemonInstance? playerPokemon,
    int turnNumber = 1,
    bool isAlreadyCaught = false,
    bool isExpedition = true,
    bool? isNight,
    int legendaryCatchAttempts = 0,
  }) {
    switch (ballType) {
      case 'master_ball':
        return 1.00;
      case 'ultra_ball':
        return 0.10;
      case 'great_ball':
        return 0.05;
      case 'poke_ball':
      default:
        return 0.01;
    }
  }

  /// KO-to-catch formula used during Expedition Legendary / Mythical boss battles
  static bool attemptLegendaryKoCapture({
    required String ballType,
    PokemonInstance? target,
    PokemonInstance? playerPokemon,
    int turnNumber = 1,
    bool isAlreadyCaught = false,
    bool isExpedition = true,
    bool? isNight,
    int legendaryCatchAttempts = 0,
    Random? rng,
  }) {
    if (ballType == 'master_ball') return true;
    final double rate;
    if (target == null) {
      if (ballType == 'ultra_ball') {
        rate = 0.10;
      } else if (ballType == 'great_ball') {
        rate = 0.05;
      } else {
        rate = 0.01;
      }
    } else {
      rate = getLegendaryKoCatchRate(
        ballType: ballType,
        target: target,
        playerPokemon: playerPokemon,
        turnNumber: turnNumber,
        isAlreadyCaught: isAlreadyCaught,
        isExpedition: isExpedition,
        isNight: isNight,
        legendaryCatchAttempts: legendaryCatchAttempts,
      );
    }
    return (rng ?? _rng).nextDouble() < rate;
  }
}
