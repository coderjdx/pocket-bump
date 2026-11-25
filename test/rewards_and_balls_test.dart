import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_bump/models/item.dart';
import 'package:pocket_bump/models/pokemon_instance.dart';
import 'package:pocket_bump/models/pokemon_species.dart';
import 'package:pocket_bump/models/pokemon_type.dart';
import 'package:pocket_bump/models/trainer.dart';
import 'package:pocket_bump/services/adventure_database.dart';
import 'package:pocket_bump/services/battle_engine.dart';
import 'package:pocket_bump/services/battle_sprite_metrics.dart';
import 'package:pocket_bump/services/egg_move_service.dart';
import 'package:pocket_bump/services/expedition_database.dart';
import 'package:pocket_bump/services/gym_database.dart';
import 'package:pocket_bump/services/item_drop_service.dart';
import 'package:pocket_bump/services/pokedex_database.dart';
import 'package:pocket_bump/services/tm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

PokemonSpecies _makeSpecies({
  int id = 1,
  String name = 'TestMon',
  List<PokemonType> types = const [PokemonType.normal],
  int baseSpe = 50,
  int evolutionStage = 1,
  int? evolutionSpeciesId = 2,
  bool isLegendary = false,
  bool isMythical = false,
}) {
  return PokemonSpecies(
    id: id,
    name: name,
    types: types,
    baseHp: 80,
    baseAtk: 80,
    baseDef: 80,
    baseSpA: 80,
    baseSpD: 80,
    baseSpe: baseSpe,
    baseCatchRate: 45,
    evolutionStage: evolutionStage,
    evolutionSpeciesId: evolutionSpeciesId,
    isLegendary: isLegendary,
    isMythical: isMythical,
  );
}

PokemonInstance _makeMon(
  PokemonSpecies species, {
  int level = 20,
  StatusCondition status = StatusCondition.none,
}) {
  return PokemonInstance(
    species: species,
    level: level,
    status: status,
    moves: [PokedexDatabase.moves['tackle']!.copy()],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TMs: Reusable & Unique', () {
    test('all TMs are marked reusable and Trainer clamps count to 1', () {
      expect(TmService.allTms, isNotEmpty);
      for (final tm in TmService.allTms) {
        expect(tm.isTm, isTrue);
        expect(tm.isReusable, isTrue);
      }

      final trainer = Trainer(name: 'Red');
      final tmId = TmService.allTms.first.id;
      expect(trainer.hasTm(tmId), isFalse);

      trainer.adjustItemCount(tmId, 1);
      expect(trainer.getItemCount(tmId), 1);
      expect(trainer.hasTm(tmId), isTrue);

      // Attempting to add duplicate TMs does not stack above 1.
      trainer.adjustItemCount(tmId, 3);
      expect(trainer.getItemCount(tmId), 1);
    });

    test('applyFromJson deduplicates legacy >1 TM counts down to 1', () {
      final trainer = Trainer(name: 'Red');
      trainer.party = [_makeMon(_makeSpecies())];
      trainer.adjustItemCount('potion', 5);
      final json = trainer.toJson();
      final custom = Map<String, dynamic>.from(json['customItems'] as Map? ?? {});
      custom['tm_24'] = 4;
      custom['tm_13'] = 2;
      custom['quick_ball'] = 7;
      json['customItems'] = custom;

      final restored = Trainer(name: 'Restored');
      restored.applyFromJson(json);

      expect(restored.getItemCount('tm_24'), 1);
      expect(restored.getItemCount('tm_13'), 1);
      expect(restored.getItemCount('quick_ball'), 7);
    });
  });

  group('Wild & Multi-Item Drop Service', () {
    test('rollDropCount matches ~50% / 35% / 15% distribution', () {
      final rng = Random(42);
      final counts = <int, int>{1: 0, 2: 0, 3: 0};
      const samples = 10000;
      for (int i = 0; i < samples; i++) {
        final c = ItemDropService.rollDropCount(rng);
        expect(c, inInclusiveRange(1, 3));
        counts[c] = (counts[c] ?? 0) + 1;
      }
      expect(counts[1]! / samples, closeTo(0.50, 0.03));
      expect(counts[2]! / samples, closeTo(0.35, 0.03));
      expect(counts[3]! / samples, closeTo(0.15, 0.03));
    });

    test('rollDrops yields 0 drops on miss or 1-3 tier drops when triggered', () {
      final common = _makeSpecies(id: 19, name: 'Rattata');
      final special = _makeSpecies(
        id: 150,
        name: 'Mewtwo',
        isLegendary: true,
        evolutionSpeciesId: null,
      );

      final rng = Random(123);
      bool sawEmptyCommon = false;
      bool sawMultiCommon = false;
      for (int i = 0; i < 200; i++) {
        final drops = ItemDropService.rollDrops(common, rng: rng);
        if (drops.isEmpty) {
          sawEmptyCommon = true;
        } else {
          final totalUnits = drops.fold<int>(0, (sum, d) => sum + d.count);
          expect(totalUnits, inInclusiveRange(1, 3));
          if (totalUnits > 1) sawMultiCommon = true;
        }
      }
      expect(sawEmptyCommon, isTrue);
      expect(sawMultiCommon, isTrue);

      for (int i = 0; i < 50; i++) {
        final specialDrops = ItemDropService.rollDrops(special, rng: rng);
        expect(specialDrops, isNotEmpty);
      }
    });
  });

  group('Gym Rematch Drops', () {
    test('never drops empty, respects TM uniqueness, and redistributes when all TMs owned', () {
      final gym = GymDatabase.gyms.first;
      final rng = Random(99);

      for (int i = 0; i < 500; i++) {
        final owned = <String>{gym.tmDrops.first};
        final drops = ItemDropService.rollGymRematchDrops(
          gym: gym,
          ownedTmIds: owned,
          rng: rng,
        );
        expect(drops, isNotEmpty);

        final tmDropsInResult = drops
            .where((d) => ItemDatabase.byId(d.itemId)?.isTm == true)
            .toList();
        for (final tmDrop in tmDropsInResult) {
          expect(owned.contains(tmDrop.itemId), isFalse);
          expect(tmDrop.count, 1);
        }
        // Duplicate TMs must never appear within the same multi-drop reward.
        expect(tmDropsInResult.map((d) => d.itemId).toSet().length,
            tmDropsInResult.length);
      }

      // When all of the gym's TMs and Map are already owned, drops come purely from the 4 non-TM/non-Map buckets.
      final allGymTms = gym.tmDrops.toSet();
      for (int i = 0; i < 200; i++) {
        final drops = ItemDropService.rollGymRematchDrops(
          gym: gym,
          ownedTmIds: allGymTms,
          ownedAdventureMapIds: {gym.signatureAdventureMapDrop},
          rng: rng,
        );
        expect(drops, isNotEmpty);
        for (final drop in drops) {
          final def = ItemDatabase.byId(drop.itemId);
          expect(def?.isTm ?? false, isFalse);
          expect(def?.isAdventureMap ?? false, isFalse);
        }
      }

      // Unowned Adventure Map can drop, never repeats within one clear, and never drops once owned.
      bool sawMapDrop = false;
      for (int i = 0; i < 400; i++) {
        final drops = ItemDropService.rollGymRematchDrops(
          gym: gym,
          ownedTmIds: const {},
          ownedAdventureMapIds: const {},
          rng: rng,
        );
        final mapDrops = drops
            .where((d) => d.itemId == gym.signatureAdventureMapDrop)
            .toList();
        if (mapDrops.isNotEmpty) {
          sawMapDrop = true;
          expect(mapDrops, hasLength(1));
          expect(mapDrops.first.count, 1);
        }
      }
      expect(sawMapDrop, isTrue);
    });
  });

  group('Pokédex & Adventure Mode', () {
    test('Pokédex Gen 1 total is 151 while caughtCount exceeds 151 with Gen 2-5 Pokémon', () {
      expect(PokedexDatabase.gen1TotalSpecies, 151);
      expect(PokedexDatabase.gen1SpeciesIds, hasLength(151));
      expect(PokedexDatabase.gen1SpeciesIds.every((id) => id <= 151), isTrue);

      final trainer = Trainer(
        name: 'Red',
        caughtSpeciesIds: {
          for (int id = 1; id <= 151; id++) id,
          390, // Chimchar
          391, // Monferno
          392, // Infernape
        },
      );
      expect(trainer.caughtCount, 154);
    });

    test('Adventure Maps are unique and clamp/deduplicate to 1', () {
      final trainer = Trainer(name: 'Red');
      trainer.party = [_makeMon(_makeSpecies())];
      const mapId = 'map_deep_sea';
      expect(trainer.hasAdventureMap(mapId), isFalse);

      trainer.adjustItemCount(mapId, 1);
      expect(trainer.hasAdventureMap(mapId), isTrue);
      expect(trainer.getItemCount(mapId), 1);

      trainer.adjustItemCount(mapId, 4);
      expect(trainer.getItemCount(mapId), 1);

      final json = trainer.toJson();
      final custom = Map<String, dynamic>.from(json['customItems'] as Map? ?? {});
      custom[mapId] = 5;
      json['customItems'] = custom;

      final restored = Trainer(name: 'Restored');
      restored.applyFromJson(json);
      expect(restored.getItemCount(mapId), 1);
    });

    test('Adventure encounters never spawn Legendaries/Mythicals and respect Biome types', () {
      final rng = Random(2026);
      for (int i = 0; i < 150; i++) {
        final wild = PokedexDatabase.generateAdventureEncounter(
          playerLevel: 50,
          rng: rng,
        );
        expect(wild.species.isLegendary, isFalse);
        expect(wild.species.isMythical, isFalse);
      }

      for (final biome in AdventureDatabase.biomes) {
        for (int i = 0; i < 30; i++) {
          final wild = PokedexDatabase.generateAdventureEncounter(
            playerLevel: 50,
            allowedTypes: biome.typeSet,
            rng: rng,
          );
          expect(wild.species.isLegendary, isFalse);
          expect(wild.species.isMythical, isFalse);
          expect(
            wild.species.types.any(biome.typeSet.contains),
            isTrue,
            reason: '${wild.species.name} did not match ${biome.name}',
          );
        }
      }
    });
  });

  group('Expedition Rocket Drops', () {
    test('always includes wild-like items plus 1 random Special Poké Ball', () {
      final rng = Random(77);
      final seenSpecialBalls = <String>{};

      for (final isBoss in [false, true]) {
        for (int i = 0; i < 120; i++) {
          final drops = ItemDropService.rollExpeditionRocketDrops(
            isJessieOrJames: isBoss,
            rng: rng,
          );
          expect(drops.length, greaterThanOrEqualTo(2));
          final specialDrops = drops
              .where((d) => ItemDatabase.specialBallIds.contains(d.itemId))
              .toList();
          expect(specialDrops, hasLength(1));
          expect(specialDrops.first.count, 1);
          seenSpecialBalls.add(specialDrops.first.itemId);
        }
      }

      // Over 240 runs, all 9 Special Balls should appear.
      expect(seenSpecialBalls.length, ItemDatabase.specialBallIds.length);
    });
  });

  group('Special Poké Ball Mechanics', () {
    test('standard & all 9 special ball multipliers match expected conditions', () {
      final waterTarget = _makeMon(
        _makeSpecies(id: 7, name: 'Squirtle', types: [PokemonType.water], baseSpe: 43),
        level: 20,
      );
      final fastSleepingTarget = _makeMon(
        _makeSpecies(id: 101, name: 'Electrode', types: [PokemonType.electric], baseSpe: 150),
        level: 20,
        status: StatusCondition.sleep,
      );
      final highLead = _makeMon(_makeSpecies(id: 6), level: 40);
      final slightlyHigherLead = _makeMon(_makeSpecies(id: 6), level: 21);
      final lowerLead = _makeMon(_makeSpecies(id: 6), level: 15);

      expect(ItemDatabase.specialBallIds, hasLength(9));

      // Quick Ball
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'quick_ball', target: waterTarget, turnNumber: 1),
        5.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'quick_ball', target: waterTarget, turnNumber: 2),
        1.0,
      );

      // Timer Ball
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'timer_ball', target: waterTarget, turnNumber: 1),
        1.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'timer_ball', target: waterTarget, turnNumber: 6),
        closeTo(2.5, 0.001),
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'timer_ball', target: waterTarget, turnNumber: 15),
        4.0,
      );

      // Dusk Ball
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'dusk_ball', target: waterTarget, isNight: true, isExpedition: false),
        3.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'dusk_ball', target: waterTarget, isNight: false, isExpedition: true),
        3.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'dusk_ball', target: waterTarget, isNight: false, isExpedition: false),
        1.0,
      );

      // Net Ball
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'net_ball', target: waterTarget),
        3.5,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'net_ball', target: fastSleepingTarget),
        1.0,
      );

      // Fast Ball
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'fast_ball', target: fastSleepingTarget),
        4.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'fast_ball', target: waterTarget),
        1.0,
      );

      // Dream Ball
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'dream_ball', target: fastSleepingTarget),
        4.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'dream_ball', target: waterTarget),
        1.0,
      );

      // Repeat Ball
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'repeat_ball', target: waterTarget, isAlreadyCaught: true),
        3.5,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'repeat_ball', target: waterTarget, isAlreadyCaught: false),
        1.0,
      );

      // Level Ball
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'level_ball', target: waterTarget, playerPokemon: highLead),
        4.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'level_ball', target: waterTarget, playerPokemon: slightlyHigherLead),
        2.0,
      );
      expect(
        BattleEngine.getBallCatchMultiplier(
            ballType: 'level_ball', target: waterTarget, playerPokemon: lowerLead),
        1.0,
      );

      // Heal Ball
      expect(
        BattleEngine.getBallCatchMultiplier(ballType: 'heal_ball', target: waterTarget),
        1.5,
      );

      // Legendary & Mythical targets receive no Special Poké Ball bonuses (1.0x / 1%)
      final legendaryTarget = _makeMon(
        _makeSpecies(
          id: 144,
          name: 'Articuno',
          types: [PokemonType.water, PokemonType.flying],
          baseSpe: 150,
          isLegendary: true,
        ),
        level: 20,
        status: StatusCondition.sleep,
      );
      final mythicalTarget = _makeMon(
        _makeSpecies(
          id: 151,
          name: 'Mew',
          types: [PokemonType.water],
          baseSpe: 150,
          isMythical: true,
        ),
        level: 20,
        status: StatusCondition.sleep,
      );

      for (final bossTarget in [legendaryTarget, mythicalTarget]) {
        for (final ballId in ItemDatabase.specialBallIds) {
          expect(
            BattleEngine.getBallCatchMultiplier(
              ballType: ballId,
              target: bossTarget,
              playerPokemon: highLead,
              turnNumber: 1,
              isAlreadyCaught: true,
              isExpedition: true,
              isNight: true,
            ),
            1.0,
          );
          expect(
            BattleEngine.getLegendaryKoCatchRate(
              ballType: ballId,
              target: bossTarget,
              playerPokemon: highLead,
              turnNumber: 1,
              isAlreadyCaught: true,
              isExpedition: true,
              isNight: true,
            ),
            0.01,
          );
        }
        expect(
          BattleEngine.getBallCatchMultiplier(
              ballType: 'ultra_ball', target: bossTarget),
          2.0,
        );
        expect(
          BattleEngine.getLegendaryKoCatchRate(
              ballType: 'ultra_ball', target: bossTarget),
          0.10,
        );
      }
    });
  });

  group('BattleSpriteMetrics Layout Safety', () {
    test('resolve never throws clamp range error across all species and viewports', () {
      final viewports = [
        (zoom: 1.05, maxW: 96.0, maxH: 92.0),
        (zoom: 1.38, maxW: 175.0, maxH: 142.0),
        (zoom: 1.88, maxW: 214.0, maxH: 176.0),
        (zoom: 1.93, maxW: 240.0, maxH: 195.0),
        (zoom: 1.38, maxW: 0.0, maxH: 0.0),
      ];

      for (final speciesId in BattleSpriteMetrics.bySpeciesId.keys) {
        for (final isBack in [false, true]) {
          for (final vp in viewports) {
            final resolved = BattleSpriteMetrics.resolve(
              speciesId: speciesId,
              isBack: isBack,
              targetZoom: vp.zoom,
              maxWidth: vp.maxW,
              maxHeight: vp.maxH,
            );
            expect(resolved.width.isFinite && resolved.width >= 1.0, isTrue);
            expect(resolved.height.isFinite && resolved.height >= 1.0, isTrue);
            expect(resolved.visualHeight.isFinite && resolved.visualHeight > 0.0, isTrue);
            expect(resolved.bodyCenterFromBottom >= 0.0, isTrue);
            expect(resolved.bodyTopFromBottom >= resolved.visualHeight - 0.001, isTrue);
            expect(resolved.bodyTopFromBottom <= resolved.height + 0.001, isTrue);
          }
        }
      }
    });
  });

  group('Egg Moves & Heart Scale Tutor Drops', () {
    test('all configured Egg Moves exist in PokedexDatabase and inherit cleanly', () {
      for (final entry in EggMoveService.familyEggMoveIds.entries) {
        expect(PokedexDatabase.species.containsKey(entry.key), isTrue);
        for (final moveId in entry.value) {
          expect(
            PokedexDatabase.moves.containsKey(moveId),
            isTrue,
            reason: 'Missing move $moveId for root ${entry.key}',
          );
        }
      }

      final charizard = PokedexDatabase.species[6]!;
      expect(EggMoveService.isEggMoveForSpecies(charizard, 'dragon_dance'), isTrue);

      final vaporeon = PokedexDatabase.species[134]!;
      expect(EggMoveService.isEggMoveForSpecies(vaporeon, 'yawn'), isTrue);

      final infernape = PokedexDatabase.species[392]!;
      expect(EggMoveService.isEggMoveForSpecies(infernape, 'thunder_punch'), isTrue);
    });

    test('wild & expedition encounters can spawn knowing an Egg Move', () {
      final rng = Random(404);
      bool sawAdventureEggMove = false;
      for (int i = 0; i < 120; i++) {
        final mon = PokedexDatabase.generateAdventureEncounter(
          playerLevel: 30,
          rng: rng,
        );
        if (mon.moves.any((m) => EggMoveService.isEggMoveForSpecies(mon.species, m.id))) {
          sawAdventureEggMove = true;
          break;
        }
      }
      expect(sawAdventureEggMove, isTrue);

      final dest = ExpeditionDatabase.destinations.first;
      bool sawExpeditionEggMove = false;
      for (int i = 0; i < 120; i++) {
        final mon = ExpeditionDatabase.generateWildEncounter(dest, rng: rng);
        if (mon.moves.any((m) => EggMoveService.isEggMoveForSpecies(mon.species, m.id))) {
          sawExpeditionEggMove = true;
          break;
        }
      }
      expect(sawExpeditionEggMove, isTrue);
    });

    test('Heart Scale drops only from Gym Leaders and Team Rocket, never Wilds', () {
      final rng = Random(505);
      final wildSpecies = [
        _makeSpecies(id: 19, name: 'Rattata', evolutionSpeciesId: 20),
        _makeSpecies(id: 20, name: 'Raticate', evolutionStage: 2, evolutionSpeciesId: null),
        _makeSpecies(id: 6, name: 'Charizard', evolutionStage: 3, evolutionSpeciesId: null),
        _makeSpecies(id: 150, name: 'Mewtwo', isLegendary: true, evolutionSpeciesId: null),
      ];
      for (final spec in wildSpecies) {
        for (int i = 0; i < 300; i++) {
          final drops = ItemDropService.rollDrops(spec, rng: rng);
          expect(drops.any((d) => d.itemId == 'heart_scale'), isFalse);
        }
      }

      final gym = GymDatabase.gyms.first;
      bool sawGymHeartScale = false;
      for (int i = 0; i < 150; i++) {
        final drops = ItemDropService.rollGymRematchDrops(
          gym: gym,
          ownedTmIds: const {},
          rng: rng,
        );
        if (drops.any((d) => d.itemId == 'heart_scale')) {
          sawGymHeartScale = true;
          break;
        }
      }
      expect(sawGymHeartScale, isTrue);

      bool sawGruntHeartScale = false;
      bool sawBossHeartScale = false;
      for (int i = 0; i < 100; i++) {
        if (ItemDropService.rollExpeditionRocketDrops(isJessieOrJames: false, rng: rng)
            .any((d) => d.itemId == 'heart_scale')) {
          sawGruntHeartScale = true;
        }
        if (ItemDropService.rollExpeditionRocketDrops(isJessieOrJames: true, rng: rng)
            .any((d) => d.itemId == 'heart_scale')) {
          sawBossHeartScale = true;
        }
      }
      expect(sawGruntHeartScale, isTrue);
      expect(sawBossHeartScale, isTrue);
    });
  });
}
