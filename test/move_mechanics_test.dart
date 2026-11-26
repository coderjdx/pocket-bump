import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_bump/models/move.dart';
import 'package:pocket_bump/models/pokemon_instance.dart';
import 'package:pocket_bump/models/pokemon_species.dart';
import 'package:pocket_bump/models/pokemon_type.dart';
import 'package:pocket_bump/services/battle_engine.dart';
import 'package:pocket_bump/services/pokedex_database.dart';

PokemonInstance _makeMon({
  required String name,
  List<PokemonType> types = const [PokemonType.normal],
  required List<String> moveIds,
  String abilityId = 'sturdy',
  int level = 50,
  int baseHp = 100,
}) {
  final species = PokemonSpecies(
    id: 999,
    name: name,
    types: types,
    baseHp: baseHp,
    baseAtk: 90,
    baseDef: 90,
    baseSpA: 90,
    baseSpD: 90,
    baseSpe: 80,
    baseCatchRate: 45,
    evolutionStage: 1,
    abilitySlot1Id: abilityId,
  );
  return PokemonInstance(
    species: species,
    level: level,
    abilityId: abilityId,
    moves: moveIds.map((id) => PokedexDatabase.moves[id]!.copy()).toList(),
  );
}

void main() {
  group('Sleep & Status Move Mechanics', () {
    test('Snore works consistently while asleep and fails while awake', () {
      final sleeper = _makeMon(
        name: 'Snorlax',
        moveIds: ['snore', 'body_slam'],
      );
      final target = _makeMon(name: 'Dummy', moveIds: ['tackle']);

      // Awake: Snore fails
      final awakeEvents = BattleEngine.executeSingleAttack(
        sleeper,
        sleeper.moves[0],
        target,
        isPlayer: true,
        rng: Random(1),
      );
      expect(awakeEvents.any((e) => e.damageDealt > 0), isFalse);
      expect(awakeEvents.any((e) => e.isMiss), isTrue);

      // Asleep with 2 remaining sleep turns: Snore hits!
      sleeper.status = StatusCondition.sleep;
      sleeper.sleepTurnsRemaining = 3;
      final sleepEvents = BattleEngine.executeSingleAttack(
        sleeper,
        sleeper.moves[0],
        target,
        isPlayer: true,
        rng: Random(1),
      );
      expect(sleepEvents.any((e) => e.damageDealt > 0 && e.moveId == 'snore'), isTrue);
    });

    test('Sleep Talk executes a valid known move while asleep (even if picked move is another attack)', () {
      final sleeper = _makeMon(
        name: 'Snorlax',
        moveIds: ['sleep_talk', 'body_slam'],
      );
      final target = _makeMon(name: 'Dummy', moveIds: ['tackle']);

      sleeper.status = StatusCondition.sleep;
      sleeper.sleepTurnsRemaining = 3;

      final events = BattleEngine.executeSingleAttack(
        sleeper,
        sleeper.moves[0],
        target,
        isPlayer: true,
        rng: Random(2),
      );

      expect(events.any((e) => e.message.contains('used Sleep Talk! (Body Slam)')), isTrue);
      expect(events.any((e) => e.moveId == 'body_slam' && e.damageDealt > 0), isTrue);
      // Sub-move does not overwrite lastMoveUsedId or consume Body Slam PP
      expect(sleeper.lastMoveUsedId, 'sleep_talk');
      expect(sleeper.moves[1].currentPp, sleeper.moves[1].maxPp);
    });

    test('Sleep Talk skips two-turn charge moves and uncallable moves', () {
      final sleeper = _makeMon(
        name: 'Venosaur',
        types: const [PokemonType.grass],
        moveIds: ['sleep_talk', 'solar_beam', 'focus_punch', 'tackle'],
      );
      final target = _makeMon(name: 'Dummy', moveIds: ['tackle']);
      sleeper.status = StatusCondition.sleep;
      sleeper.sleepTurnsRemaining = 3;

      for (int seed = 0; seed < 15; seed++) {
        sleeper.status = StatusCondition.sleep;
        sleeper.sleepTurnsRemaining = 3;
        sleeper.chargingMoveId = null;
        final events = BattleEngine.executeSingleAttack(
          sleeper,
          sleeper.moves[0],
          target,
          isPlayer: true,
          rng: Random(seed),
        );
        expect(events.any((e) => e.moveId == 'tackle'), isTrue);
        expect(events.any((e) => e.moveId == 'solar_beam'), isFalse);
        expect(events.any((e) => e.moveId == 'focus_punch'), isFalse);
      }
    });

    test('Rest heals full HP, sets deterministic sleep turns, and Early Bird wakes faster', () {
      final bird = _makeMon(
        name: 'Dodrio',
        moveIds: ['rest', 'tackle'],
        abilityId: 'early_bird',
      );
      final foe = _makeMon(name: 'Dummy', moveIds: ['tackle']);
      bird.currentHp = 20;

      final restEvents = BattleEngine.executeSingleAttack(
        bird,
        bird.moves[0],
        foe,
        isPlayer: true,
        rng: Random(0),
      );
      expect(bird.currentHp, bird.maxHp);
      expect(bird.status, StatusCondition.sleep);
      expect(bird.sleepTurnsRemaining, 3);
      expect(restEvents.any((e) => e.healAmount > 0), isTrue);

      // Early Bird decrements by 2 on first turn (3 -> 1) -> still asleep
      final turn1 = BattleEngine.executeSingleAttack(
        bird,
        bird.moves[1],
        foe,
        isPlayer: true,
        rng: Random(0),
      );
      expect(bird.status, StatusCondition.sleep);
      expect(turn1.any((e) => e.message.contains('fast asleep')), isTrue);

      // Next turn Early Bird decrements 1 -> 0 -> wakes up and attacks!
      final turn2 = BattleEngine.executeSingleAttack(
        bird,
        bird.moves[1],
        foe,
        isPlayer: true,
        rng: Random(0),
      );
      expect(bird.status, StatusCondition.none);
      expect(turn2.any((e) => e.message.contains('woke up')), isTrue);
      expect(turn2.any((e) => e.damageDealt > 0 && e.moveId == 'tackle'), isTrue);
    });
  });

  group('Fixed Special Move Mechanics', () {
    test('Charge raises Sp. Def and doubles next Electric move damage', () {
      final atk = _makeMon(
        name: 'Raichu',
        types: const [PokemonType.electric],
        moveIds: ['charge', 'thunderbolt'],
      );
      final foe1 = _makeMon(name: 'Foe1', moveIds: ['tackle']);
      final foe2 = _makeMon(name: 'Foe2', moveIds: ['tackle']);

      // Baseline Thunderbolt without Charge
      final baseEv = BattleEngine.executeSingleAttack(
        atk,
        PokedexDatabase.moves['thunderbolt']!.copy(),
        foe1,
        isPlayer: true,
        rng: Random(42),
      );
      final baseDmg = baseEv.firstWhere((e) => e.damageDealt > 0).damageDealt;

      // With Charge
      BattleEngine.executeSingleAttack(
        atk,
        atk.moves[0],
        foe2,
        isPlayer: true,
        rng: Random(42),
      );
      expect(atk.spdStage, 1);
      expect(atk.isChargedElectric, isTrue);

      final chargedEv = BattleEngine.executeSingleAttack(
        atk,
        atk.moves[1],
        foe2,
        isPlayer: true,
        rng: Random(42),
      );
      final chargedDmg = chargedEv.firstWhere((e) => e.damageDealt > 0).damageDealt;
      expect(chargedDmg, greaterThan((baseDmg * 1.75).round()));
      expect(atk.isChargedElectric, isFalse);
    });

    test('Counter uses priority -5 and returns 2x physical damage taken', () {
      final counterMove = PokedexDatabase.moves['counter']!;
      expect(counterMove.priority, -5);
      expect(counterMove.power, 0);

      final wobb = _makeMon(name: 'Wobbuffet', moveIds: ['counter']);
      final hitter = _makeMon(name: 'Machamp', moveIds: ['tackle']);

      final events = BattleEngine.resolveTurn(
        playerMon: wobb,
        playerAction: BattleAction.fight(wobb.moves[0]),
        opponentMon: hitter,
        opponentAction: BattleAction.fight(hitter.moves[0]),
      );
      final physicalTaken = wobb.maxHp - wobb.currentHp;
      expect(physicalTaken, greaterThan(0));
      final counterHit = events.firstWhere((e) => e.moveId == 'counter');
      expect(counterHit.damageDealt, physicalTaken * 2);
    });

    test('Magic Coat bounces status moves back to the user', () {
      final defender = _makeMon(
        name: 'Espeon',
        types: const [PokemonType.psychic],
        moveIds: ['magic_coat', 'tackle'],
      );
      final attacker = _makeMon(
        name: 'Bulbasaur',
        types: const [PokemonType.grass],
        moveIds: ['toxic'],
      );
      defender.hasMagicCoatThisTurn = true;

      final events = BattleEngine.executeSingleAttack(
        attacker,
        attacker.moves[0],
        defender,
        isPlayer: false,
        rng: Random(1),
      );
      expect(events.any((e) => e.message.contains('Magic Coat')), isTrue);
      expect(attacker.status, StatusCondition.poison);
      expect(defender.status, StatusCondition.none);
    });

    test('Imprison seals shared moves and Uproar wakes sleepers & blocks Rest', () {
      final gardevoir = _makeMon(
        name: 'Gardevoir',
        types: const [PokemonType.psychic],
        moveIds: ['imprison', 'thunderbolt'],
      );
      final foe = _makeMon(
        name: 'Alakazam',
        types: const [PokemonType.psychic],
        moveIds: ['thunderbolt', 'uproar', 'rest'],
      );

      BattleEngine.executeSingleAttack(gardevoir, gardevoir.moves[0], foe, isPlayer: true);
      expect(gardevoir.isImprisoning, isTrue);

      final blocked = BattleEngine.executeSingleAttack(
        foe,
        foe.moves[0],
        gardevoir,
        isPlayer: false,
      );
      expect(blocked.any((e) => e.message.contains('sealed')), isTrue);

      // Uproar wakes sleeper and sets field uproarTurns
      final field = BattleFieldState();
      gardevoir.status = StatusCondition.sleep;
      gardevoir.sleepTurnsRemaining = 3;
      BattleEngine.executeSingleAttack(
        foe,
        foe.moves[1],
        gardevoir,
        isPlayer: false,
        field: field,
        rng: Random(1),
      );
      expect(field.uproarTurns, 3);
      expect(gardevoir.status, StatusCondition.none);

      gardevoir.currentHp = 20;
      final restBlocked = BattleEngine.executeSingleAttack(
        gardevoir,
        PokedexDatabase.moves['rest']!.copy(),
        foe,
        isPlayer: true,
        field: field,
      );
      expect(restBlocked.any((e) => e.message.contains('uproar')), isTrue);
      expect(gardevoir.status, StatusCondition.none);
    });

    test('Roost removes Flying weakness for the turn and Healing Wish heals replacement', () {
      final bird = _makeMon(
        name: 'Pidgeot',
        types: const [PokemonType.normal, PokemonType.flying],
        moveIds: ['roost'],
      );
      final zap = _makeMon(
        name: 'Pikachu',
        types: const [PokemonType.electric],
        moveIds: ['thunderbolt'],
      );
      bird.currentHp = 40;
      BattleEngine.executeSingleAttack(bird, bird.moves[0], zap, isPlayer: true);
      expect(bird.isRoostedThisTurn, isTrue);

      final hitEv = BattleEngine.executeSingleAttack(
        zap,
        zap.moves[0],
        bird,
        isPlayer: false,
        rng: Random(1),
      );
      expect(hitEv.firstWhere((e) => e.damageDealt > 0).effectiveness, 1.0);

      // Healing Wish
      final healer = _makeMon(
        name: 'Blissey',
        moveIds: ['healing_wish'],
      );
      final field = BattleFieldState();
      BattleEngine.executeSingleAttack(healer, healer.moves[0], zap, isPlayer: true, field: field);
      expect(healer.isFainted, isTrue);
      expect(field.playerSide.hasHealingWishPending, isTrue);

      final injuredReplacement = _makeMon(name: 'Charizard', moveIds: ['tackle']);
      injuredReplacement.currentHp = 10;
      injuredReplacement.status = StatusCondition.paralysis;
      final enterEvents = BattleEngine.onPokemonEnterBattle(
        injuredReplacement,
        zap,
        isPlayer: true,
        isWild: true,
        field: field,
      );
      expect(injuredReplacement.currentHp, injuredReplacement.maxHp);
      expect(injuredReplacement.status, StatusCondition.none);
      expect(field.playerSide.hasHealingWishPending, isFalse);
      expect(enterEvents.any((e) => e.healAmount > 0), isTrue);
    });

    test('Synchronoise fails against non-matching type and hits matching type', () {
      final user = _makeMon(
        name: 'Eevee',
        types: const [PokemonType.normal],
        moveIds: ['synchronoise'],
      );
      final ghost = _makeMon(
        name: 'Gengar',
        types: const [PokemonType.ghost],
        moveIds: ['tackle'],
      );
      final normalFoe = _makeMon(
        name: 'Raticate',
        types: const [PokemonType.normal],
        moveIds: ['tackle'],
      );

      final failEv = BattleEngine.executeSingleAttack(user, user.moves[0], ghost, isPlayer: true);
      expect(failEv.any((e) => e.effectiveness == 0.0 && e.damageDealt == 0), isTrue);

      final hitEv = BattleEngine.executeSingleAttack(user, user.moves[0], normalFoe, isPlayer: true, rng: Random(1));
      expect(hitEv.any((e) => e.damageDealt > 0), isTrue);
    });

    test('Grudge drains killer move PP to 0', () {
      final grudger = _makeMon(name: 'Gengar', types: const [PokemonType.ghost], moveIds: ['grudge'], baseHp: 1);
      final killer = _makeMon(name: 'BiteMon', moveIds: ['bite']);
      grudger.hasGrudge = true;
      grudger.currentHp = 1;

      final events = BattleEngine.executeSingleAttack(
        killer,
        killer.moves[0],
        grudger,
        isPlayer: false,
        rng: Random(1),
      );
      expect(grudger.isFainted, isTrue);
      expect(killer.moves[0].currentPp, 0);
      expect(events.any((e) => e.message.contains('grudge')), isTrue);
    });
  });

  group('Weight-Dependent Moves', () {
    test('all 187 Pokedex species have official positive weightKg values', () {
      expect(PokedexDatabase.species.length, 187);
      for (final sp in PokedexDatabase.species.values) {
        expect(sp.weightKg, greaterThan(0), reason: '${sp.name} missing weightKg');
      }
      expect(PokedexDatabase.species[92]!.weightKg, 0.1); // Gastly
      expect(PokedexDatabase.species[76]!.weightKg, 300.0); // Golem
      expect(PokedexDatabase.species[143]!.weightKg, 460.0); // Snorlax
    });

    test('Grass Knot / Low Kick scale with defender weightKg instead of height', () {
      final caster = _makeMon(
        name: 'Pikachu',
        types: const [PokemonType.grass],
        moveIds: ['grass_knot'],
      );
      final gastly = PokemonInstance(
        species: PokedexDatabase.species[92]!, // 1.3m tall, 0.1kg (20 power)
        level: 50,
        moves: [PokedexDatabase.moves['tackle']!.copy()],
      );
      final golem = PokemonInstance(
        species: PokedexDatabase.species[76]!, // 1.4m tall, 300kg (120 power)
        level: 50,
        moves: [PokedexDatabase.moves['tackle']!.copy()],
      );

      final gastlyEv = BattleEngine.executeSingleAttack(
        caster,
        caster.moves[0],
        gastly,
        isPlayer: true,
        rng: Random(7),
      );
      final golemEv = BattleEngine.executeSingleAttack(
        caster,
        caster.moves[0],
        golem,
        isPlayer: true,
        rng: Random(7),
      );
      final dmgGastly = gastlyEv.firstWhere((e) => e.damageDealt > 0).damageDealt;
      final dmgGolem = golemEv.firstWhere((e) => e.damageDealt > 0).damageDealt;
      // 120 power vs 4x Grass-weak Golem dwarfs 20 power vs 0.5x Poison-resisted Gastly
      expect(dmgGolem, greaterThan(dmgGastly * 10));
    });

    test('Heavy Slam scales with attacker-to-defender weightKg ratio', () {
      final snorlax = PokemonInstance(
        species: PokedexDatabase.species[143]!, // 460 kg
        level: 50,
        moves: [PokedexDatabase.moves['heavy_slam']!.copy()],
      );
      final squirtle = PokemonInstance(
        species: PokedexDatabase.species[7]!, // 9.0 kg -> ratio > 51x -> 120 power
        level: 50,
        moves: [PokedexDatabase.moves['tackle']!.copy()],
      );
      final onix = PokemonInstance(
        species: PokedexDatabase.species[95]!, // 210 kg -> ratio 2.19x -> 60 power
        level: 50,
        moves: [PokedexDatabase.moves['tackle']!.copy()],
      );

      final vsSquirtle = BattleEngine.executeSingleAttack(
        snorlax,
        snorlax.moves[0],
        squirtle,
        isPlayer: true,
        rng: Random(3),
      );
      final vsOnix = BattleEngine.executeSingleAttack(
        snorlax,
        snorlax.moves[0],
        onix,
        isPlayer: true,
        rng: Random(3),
      );
      expect(vsSquirtle.firstWhere((e) => e.damageDealt > 0).damageDealt,
          greaterThan(vsOnix.firstWhere((e) => e.damageDealt > 0).damageDealt));
    });
  });
}
