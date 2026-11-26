import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_bump/models/item.dart';
import 'package:pocket_bump/models/pokemon_instance.dart';
import 'package:pocket_bump/models/trainer.dart';
import 'package:pocket_bump/services/battle_engine.dart';
import 'package:pocket_bump/services/elite_four_database.dart';
import 'package:pocket_bump/services/pokedex_database.dart';
import 'package:pocket_bump/services/tm_service.dart';

PokemonInstance _makeMon({
  int speciesId = 6,
  int level = 95,
  List<String> moveIds = const ['tackle', 'ice_beam'],
  String? heldItemId,
  String abilityId = 'blaze',
}) {
  final spec = PokedexDatabase.species[speciesId]!;
  final moves = moveIds
      .map((id) => PokedexDatabase.moves[id]!.copy())
      .toList();
  return PokemonInstance(
    species: spec,
    level: level,
    moves: moves,
    heldItemId: heldItemId,
    abilityId: abilityId,
    abilitySlot: 1,
  );
}

void main() {
  group('Victory Road, Final Four & Champion', () {
    test('Unlocks strictly at 8 badges with 3 progression states', () {
      final trainer = Trainer(
        name: 'Red',
        clearedGymIds: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(trainer.isVictoryRoadUnlocked, isFalse);

      trainer.clearedGymIds.add(8);
      expect(trainer.isVictoryRoadUnlocked, isTrue);
      expect(trainer.victoryRoadCleared, isFalse);
      expect(trainer.isChampion, isFalse);

      trainer.markVictoryRoadCleared();
      expect(trainer.victoryRoadCleared, isTrue);
      expect(trainer.isChampion, isFalse);

      trainer.party.add(_makeMon(speciesId: 6, level: 92));
      trainer.recordChampionVictory();
      expect(trainer.isChampion, isTrue);
      expect(trainer.championClears, 1);
      expect(trainer.hallOfFameEntries.length, 1);
    });

    test('State 1 builds alternating wild-trainer-wild-trainer-wild-trainer stages', () {
      final stages = EliteFourDatabase.buildFirstAscentStages();
      expect(stages.length, 6);
      expect(stages[0].isWild, isTrue);
      expect(stages[1].isWild, isFalse);
      expect(stages[2].isWild, isTrue);
      expect(stages[3].isWild, isFalse);
      expect(stages[4].isWild, isTrue);
      expect(stages[5].isWild, isFalse);

      for (final s in stages) {
        if (!s.isWild) {
          expect(s.trainer!.introDialogue.isNotEmpty, isTrue);
          expect(s.trainer!.defeatDialogue.isNotEmpty, isTrue);
        }
      }
    });

    test('State 2 builds Final Four + Champion Blue and rewards TM51 without Master Ball', () {
      final trainer = Trainer(
        name: 'Red',
        clearedGymIds: {1, 2, 3, 4, 5, 6, 7, 8},
        party: [_makeMon(speciesId: 6, level: 90)],
      );
      final bosses = EliteFourDatabase.buildEliteFourAndChampionStages(trainer);
      expect(bosses.length, 5);
      expect(bosses[0].name, 'Lorelei');
      expect(bosses[1].name, 'Bruno');
      expect(bosses[2].name, 'Agatha');
      expect(bosses[3].name, 'Lance');
      expect(bosses[4].name, 'Champion Blue');

      // Player has Charizard -> Blue should counter with Blastoise (#9)
      expect(bosses[4].team.last.speciesId, 9);
      for (final b in bosses) {
        expect(b.team.length, 6);
        expect(b.introDialogue.isNotEmpty, isTrue);
        expect(b.defeatDialogue.isNotEmpty, isTrue);
      }

      final rewards =
          EliteFourDatabase.buildChampionFirstClearRewards(trainer: trainer);
      expect(rewards.any((d) => d.itemId == 'master_ball'), isFalse);
      expect(rewards.any((d) => d.itemId == 'tm_51'), isTrue);
      expect(rewards.any((d) => d.itemId == 'heart_scale'), isTrue);
    });

    test('State 3 builds Lv.99 alternating gauntlet with random Final Four / Blue and exclusive drops', () {
      final trainer = Trainer(
        name: 'Red',
        clearedGymIds: {1, 2, 3, 4, 5, 6, 7, 8},
        victoryRoadCleared: true,
        championClears: 1,
        party: [_makeMon(speciesId: 3, level: 98)],
      );

      final seenBosses = <String>{};
      for (int seed = 0; seed < 30; seed++) {
        final stages = EliteFourDatabase.buildMasterRematchStages(
          trainer,
          rng: Random(seed),
        );
        expect(stages.length, 6);
        expect(stages[0].isWild, isTrue);
        expect(stages[0].wildLevel, 99);
        expect(stages[1].isWild, isFalse);
        expect(stages[2].isWild, isTrue);
        expect(stages[2].wildLevel, 99);
        expect(stages[3].isWild, isFalse);
        expect(stages[4].isWild, isTrue);
        expect(stages[4].wildLevel, 99);
        expect(stages[5].isWild, isFalse);

        final boss = stages[5].trainer as LeagueBossTrainer;
        seenBosses.add(boss.name);
        for (final monSpec in boss.team) {
          expect(monSpec.level, 99);
        }

        final drops = EliteFourDatabase.rollLeagueBossRematchDrops(
          boss: boss,
          trainer: trainer,
          rng: Random(seed),
        );
        expect(drops.any((d) => d.itemId == boss.exclusiveHeldItemId), isTrue);
        expect(drops.any((d) => d.itemId == boss.exclusiveTmId), isTrue);
        expect(drops.any((d) => d.itemId == 'master_ball'), isFalse);
      }

      expect(
        seenBosses,
        containsAll(['Lorelei', 'Bruno', 'Agatha', 'Lance', 'Blue']),
      );
    });

    test('New held items boost power and Life Orb deals 10% max HP recoil', () {
      final target = _makeMon(speciesId: 143, level: 90, moveIds: ['tackle']);
      final orbUser = _makeMon(
        speciesId: 65,
        level: 95,
        moveIds: ['psychic'],
        heldItemId: 'life_orb',
        abilityId: 'synchronize',
      );
      final int startHp = orbUser.maxHp;

      final events = BattleEngine.executeSingleAttack(
        orbUser,
        orbUser.moves.first,
        target,
        isPlayer: true,
        rng: Random(0),
      );
      expect(events.any((e) => e.message.contains('from Life Orb!')), isTrue);
      expect(orbUser.currentHp, startHp - (orbUser.maxHp ~/ 10));
    });

    test('Exclusive TMs TM51-TM56 exist and check compatibility', () {
      for (int tm = 51; tm <= 56; tm++) {
        final item = ItemDatabase.byId('tm_$tm');
        expect(item, isNotNull);
        expect(item!.isTm, isTrue);
      }
      final gengar = PokedexDatabase.species[94]!;
      expect(TmService.canLearnTm(gengar, ItemDatabase.byId('tm_54')!), isTrue);
      expect(TmService.canLearnTm(gengar, ItemDatabase.byId('tm_56')!), isTrue);

      final dragonite = PokedexDatabase.species[149]!;
      expect(TmService.canLearnTm(dragonite, ItemDatabase.byId('tm_55')!), isTrue);
    });

    test('Trainer serializes and restores Victory Road & Hall of Fame progress', () {
      final trainer = Trainer(
        name: 'Leaf',
        clearedGymIds: {1, 2, 3, 4, 5, 6, 7, 8},
        party: [_makeMon(speciesId: 9, level: 95)],
      );
      trainer.markVictoryRoadCleared();
      trainer.recordChampionVictory();

      final saved = trainer.toJson();
      final restored = Trainer(name: 'Red');
      restored.applyFromJson(saved);

      expect(restored.victoryRoadCleared, isTrue);
      expect(restored.championClears, 1);
      expect(restored.isChampion, isTrue);
      expect(restored.hallOfFameEntries.length, 1);
      expect(restored.hallOfFameEntries.first['runNumber'], 1);
    });
  });
}
