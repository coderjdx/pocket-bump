import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_bump/models/pokemon_instance.dart';
import 'package:pocket_bump/models/trainer.dart';
import 'package:pocket_bump/services/pokedex_database.dart';

void main() {
  group('Permanent Nicknames & Original Trainer (OT)', () {
    test('PokemonInstance can be nicknamed once and locks permanently', () {
      final pika = PokemonInstance(
        species: PokedexDatabase.species[25]!,
        level: 10,
      );

      expect(pika.nickname, 'Pikachu');
      expect(pika.hasCustomNickname, isFalse);
      expect(pika.canSetNickname, isTrue);

      // Blank nickname does not lock or change name
      expect(pika.setPermanentNickname('   '), isFalse);
      expect(pika.hasCustomNickname, isFalse);
      expect(pika.canSetNickname, isTrue);

      // Valid nickname sets and locks permanently
      expect(pika.setPermanentNickname('  Sparky  '), isTrue);
      expect(pika.nickname, 'Sparky');
      expect(pika.hasCustomNickname, isTrue);
      expect(pika.canSetNickname, isFalse);

      // Subsequent attempts fail and keep original custom nickname
      expect(pika.setPermanentNickname('Volt'), isFalse);
      expect(pika.nickname, 'Sparky');
    });

    test('Evolving updates un-nicknamed Pokémon but preserves permanent nicknames', () {
      final charmander = PokemonInstance(
        species: PokedexDatabase.species[4]!,
        level: 16,
      );
      final charmeleonSpec = PokedexDatabase.species[5]!;
      charmander.evolve(charmeleonSpec, const []);
      expect(charmander.nickname, 'Charmeleon');
      expect(charmander.hasCustomNickname, isFalse);

      final bulba = PokemonInstance(
        species: PokedexDatabase.species[1]!,
        level: 16,
      );
      expect(bulba.setPermanentNickname('Sprout'), isTrue);
      bulba.evolve(PokedexDatabase.species[2]!, const []);
      expect(bulba.nickname, 'Sprout');
      expect(bulba.hasCustomNickname, isTrue);
    });

    test('Original Trainer (OT) shows name now and appends ID when live account ID exists', () {
      final trainer = Trainer(name: 'Ash');
      final squirtle = PokemonInstance(
        species: PokedexDatabase.species[7]!,
        level: 5,
      );

      trainer.addPokemon(squirtle);
      expect(squirtle.originalTrainerName, 'Ash');
      expect(squirtle.originalTrainerId, isNull);
      expect(squirtle.originalTrainerDisplay(fallbackName: 'Red'), 'Ash');

      squirtle.originalTrainerId = '48291';
      expect(
        squirtle.originalTrainerDisplay(fallbackName: 'Red'),
        'Ash (#48291)',
      );
    });

    test('Trainer serializes & restores permanent nickname and OT, and backfills legacy saves', () {
      final trainer = Trainer(name: 'Misty', accountId: '1042');
      final staryu = PokemonInstance(
        species: PokedexDatabase.species[120]!,
        level: 12,
      );
      trainer.addPokemon(staryu);
      trainer.setPokemonNickname(staryu, 'Starlight');

      final json = trainer.toJson();
      final restored = Trainer(name: 'Red');
      restored.applyFromJson(json);

      expect(restored.accountId, '1042');
      expect(restored.party.first.nickname, 'Starlight');
      expect(restored.party.first.hasCustomNickname, isTrue);
      expect(restored.party.first.canSetNickname, isFalse);
      expect(restored.party.first.originalTrainerDisplay(), 'Misty (#1042)');

      // Legacy JSON without originalTrainerName or hasCustomNickname
      final legacyJson = {
        'name': 'Brock',
        'party': [
          {
            'speciesId': 95,
            'nickname': 'Rocky',
            'level': 14,
          },
          {
            'speciesId': 74,
            'nickname': 'Geodude',
            'level': 12,
          },
        ],
      };
      final legacyTrainer = Trainer(name: 'Red');
      legacyTrainer.applyFromJson(legacyJson);

      expect(legacyTrainer.party[0].originalTrainerName, 'Brock');
      expect(legacyTrainer.party[0].hasCustomNickname, isTrue);
      expect(legacyTrainer.party[0].canSetNickname, isFalse);

      expect(legacyTrainer.party[1].originalTrainerName, 'Brock');
      expect(legacyTrainer.party[1].hasCustomNickname, isFalse);
      expect(legacyTrainer.party[1].canSetNickname, isTrue);
    });
  });
}
