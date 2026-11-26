import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_bump/models/move.dart';
import 'package:pocket_bump/models/pokemon_instance.dart';
import 'package:pocket_bump/services/battle_engine.dart';
import 'package:pocket_bump/services/double_battle_engine.dart';
import 'package:pocket_bump/services/expedition_database.dart';
import 'package:pocket_bump/services/pokedex_database.dart';
import 'package:pocket_bump/services/pvp_link_service.dart';

PokemonInstance _mon({
  required int speciesId,
  int level = 50,
  List<String> moveIds = const ['tackle'],
  String? abilityId,
}) {
  final spec = PokedexDatabase.species[speciesId]!;
  return PokemonInstance(
    species: spec,
    level: level,
    moves: [for (final id in moveIds) PokedexDatabase.moves[id]!.copy()],
    abilityId: abilityId ?? spec.abilitySlot1Id,
    abilitySlot: 1,
  );
}

void main() {
  group('Canon Double Battles', () {
    test('MoveTarget classifies spread, ally, side, field, self, and single moves accurately', () {
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['earthquake']!),
        MoveTarget.allOthers,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['surf']!),
        MoveTarget.allOthers,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['discharge']!),
        MoveTarget.allOthers,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['rock_slide']!),
        MoveTarget.allFoes,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['heat_wave']!),
        MoveTarget.allFoes,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['helping_hand']!),
        MoveTarget.allyOnly,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['wide_guard']!),
        MoveTarget.userSide,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['tailwind']!),
        MoveTarget.userSide,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['stealth_rock']!),
        MoveTarget.foeSide,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['rain_dance']!),
        MoveTarget.entireField,
      );
      expect(
        DoubleBattleEngine.classifyMoveTarget(PokedexDatabase.moves['flamethrower']!),
        MoveTarget.singleAdjacent,
      );
    });

    test('Earthquake hits grounded ally and misses Flying/Levitate ally', () {
      final user = _mon(speciesId: 112, level: 80, moveIds: ['earthquake']); // Rhydon
      final groundedAlly = _mon(speciesId: 25, level: 60, moveIds: ['tackle']); // Pikachu
      final levitateAlly = _mon(
        speciesId: 94,
        level: 60,
        moveIds: ['tackle'],
        abilityId: 'levitate',
      );
      final foe1 = _mon(speciesId: 59, level: 60, moveIds: ['tackle']);
      final foe2 = _mon(speciesId: 135, level: 60, moveIds: ['tackle']);

      final int groundedBefore = groundedAlly.currentHp;
      final slotsA = <PokemonInstance?>[user, groundedAlly, foe1, foe2];
      DoubleBattleEngine.resolveDoubleTurn(
        slots: slotsA,
        slotActions: [
          DoubleBattleSlotAction.fight(user.moves.first),
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.pass(),
        ],
        playerParty: [user, groundedAlly],
        opponentParty: [foe1, foe2],
        field: BattleFieldState(),
        rng: Random(1),
      );
      expect(groundedAlly.currentHp, lessThan(groundedBefore));
      expect(foe1.currentHp, lessThan(foe1.maxHp));
      expect(foe2.currentHp, lessThan(foe2.maxHp));

      final int levitateBefore = levitateAlly.currentHp;
      final slotsB = <PokemonInstance?>[
        _mon(speciesId: 112, level: 80, moveIds: ['earthquake']),
        levitateAlly,
        _mon(speciesId: 59, level: 60),
        _mon(speciesId: 135, level: 60),
      ];
      DoubleBattleEngine.resolveDoubleTurn(
        slots: slotsB,
        slotActions: [
          DoubleBattleSlotAction.fight(slotsB[0]!.moves.first),
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.pass(),
        ],
        playerParty: [slotsB[0]!, levitateAlly],
        opponentParty: [slotsB[2]!, slotsB[3]!],
        field: BattleFieldState(),
        rng: Random(1),
      );
      expect(levitateAlly.currentHp, equals(levitateBefore));
    });

    test('Intimidate hits both active foes and Wide Guard blocks Rock Slide', () {
      final intimidator = _mon(
        speciesId: 59,
        level: 80,
        moveIds: ['tackle'],
        abilityId: 'intimidate',
      );
      final partner = _mon(speciesId: 68, level: 80, moveIds: ['wide_guard']);
      final foe1 = _mon(speciesId: 142, level: 80, moveIds: ['rock_slide']);
      final foe2 = _mon(speciesId: 149, level: 80, moveIds: ['dragon_claw']);

      final slots = <PokemonInstance?>[intimidator, partner, foe1, foe2];
      final field = BattleFieldState();

      DoubleBattleEngine.triggerDoubleSwitchIn(slot: 0, slots: slots, field: field);
      expect(foe1.atkStage, -1);
      expect(foe2.atkStage, -1);

      final int partnerStartHp = partner.currentHp;
      final int intimStartHp = intimidator.currentHp;

      DoubleBattleEngine.resolveDoubleTurn(
        slots: slots,
        slotActions: [
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.fight(partner.moves.first), // Wide Guard (+3)
          DoubleBattleSlotAction.fight(foe1.moves.first), // Rock Slide (spread)
          DoubleBattleSlotAction.fight(foe2.moves.first, targetSlot: 0), // Single target
        ],
        playerParty: [intimidator, partner],
        opponentParty: [foe1, foe2],
        field: field,
        rng: Random(2),
      );

      // Partner protected from Rock Slide; Intimidator only damaged by Dragon Claw
      expect(partner.currentHp, equals(partnerStartHp));
      expect(intimidator.currentHp, lessThan(intimStartHp));
    });

    test('Follow Me redirects foe single-target moves; Ally Switch swaps left/right slots', () {
      final center = _mon(speciesId: 36, level: 85, moveIds: ['follow_me', 'tackle']);
      final ally = _mon(speciesId: 65, level: 85, moveIds: ['ally_switch', 'psychic']);
      final foe1 = _mon(speciesId: 59, level: 70, moveIds: ['flamethrower']);
      final foe2 = _mon(speciesId: 135, level: 70, moveIds: ['thunderbolt']);

      final slots = <PokemonInstance?>[center, ally, foe1, foe2];
      final int allyHpBefore = ally.currentHp;
      final int centerHpBefore = center.currentHp;

      DoubleBattleEngine.resolveDoubleTurn(
        slots: slots,
        slotActions: [
          DoubleBattleSlotAction.fight(center.moves[0]), // Follow Me
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.fight(foe1.moves.first, targetSlot: 1), // targeted ally!
          DoubleBattleSlotAction.pass(),
        ],
        playerParty: [center, ally],
        opponentParty: [foe1, foe2],
        field: BattleFieldState(),
        rng: Random(4),
      );

      expect(ally.currentHp, equals(allyHpBefore));
      expect(center.currentHp, lessThan(centerHpBefore));

      // Now Ally Switch swaps slots 0 <-> 1
      DoubleBattleEngine.resolveDoubleTurn(
        slots: slots,
        slotActions: [
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.fight(ally.moves[0]), // Ally Switch
          DoubleBattleSlotAction.pass(),
          DoubleBattleSlotAction.pass(),
        ],
        playerParty: [center, ally],
        opponentParty: [foe1, foe2],
        field: BattleFieldState(),
        rng: Random(5),
      );

      expect(identical(slots[0], ally), isTrue);
      expect(identical(slots[1], center), isTrue);
    });

    test('Expedition Jessie & James always spawn as 2v2 Double Battle; Grunt is Singles', () {
      bool sawDuo = false;
      bool sawGrunt = false;
      for (int seed = 0; seed < 100; seed++) {
        final r = ExpeditionDatabase.generateRocketChallenger(rng: Random(seed));
        if (r.isJessieOrJames) {
          sawDuo = true;
          expect(r.isDoubleBattle, isTrue);
          expect(r.name, 'Jessie & James');
          expect(r.partnerSpriteId, 'rocket_james');
          expect(r.team.length, 6);
        } else {
          sawGrunt = true;
          expect(r.isDoubleBattle, isFalse);
        }
      }
      expect(sawDuo, isTrue);
      expect(sawGrunt, isTrue);
    });

    test('BumpLinkMode parses doubles mode cleanly', () {
      expect(parseBumpLinkMode('battle'), BumpLinkMode.battle);
      expect(parseBumpLinkMode('doubleBattle'), BumpLinkMode.doubleBattle);
      expect(parseBumpLinkMode('trade'), BumpLinkMode.trade);
      expect(BumpLinkMode.doubleBattle.isBattle, isTrue);
      expect(BumpLinkMode.doubleBattle.isDoubleBattle, isTrue);
    });
  });
}
