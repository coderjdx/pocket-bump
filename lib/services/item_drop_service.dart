import 'dart:math';
import '../models/pokemon_species.dart';

class ItemDrop {
  final String itemId;
  final String itemName;
  final int count;
  final PokemonRarity rarity;

  const ItemDrop({
    required this.itemId,
    required this.itemName,
    this.count = 1,
    required this.rarity,
  });
}

class ItemDropService {
  static final Random _rng = Random();

  /// Rolls an item drop when a Pokémon is defeated or caught based on [species.rarity].
  ///
  /// Drop rules:
  /// - Common Pokémon (45% drop chance):
  ///   - 50% Poké Ball (Common)
  ///   - 50% Potion (Common)
  /// - Uncommon Pokémon (60% drop chance):
  ///   - 45% Great Ball (Uncommon)
  ///   - 45% Super Potion (Uncommon)
  ///   - 10% Revive (Rare)
  /// - Rare Pokémon (75% drop chance):
  ///   - 45% Ultra Ball (Rare)
  ///   - 40% Hyper Potion (Rare)
  ///   - 15% Revive (Rare)
  /// - Special Pokémon (100% drop chance - Legendary/Mythical event encounters):
  ///   - 50% Ultra Ball x2
  ///   - 50% Hyper Potion x2
  static ItemDrop? rollDrop(PokemonSpecies species) {
    final double dropRoll = _rng.nextDouble();
    switch (species.rarity) {
      case PokemonRarity.common:
        if (dropRoll > 0.45) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.50) {
          return const ItemDrop(
            itemId: 'poke_ball',
            itemName: 'Poké Ball',
            rarity: PokemonRarity.common,
          );
        } else {
          return const ItemDrop(
            itemId: 'potion',
            itemName: 'Potion',
            rarity: PokemonRarity.common,
          );
        }

      case PokemonRarity.uncommon:
        if (dropRoll > 0.60) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.45) {
          return const ItemDrop(
            itemId: 'great_ball',
            itemName: 'Great Ball',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.90) {
          return const ItemDrop(
            itemId: 'super_potion',
            itemName: 'Super Potion',
            rarity: PokemonRarity.uncommon,
          );
        } else {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        }

      case PokemonRarity.rare:
        if (dropRoll > 0.75) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.45) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.85) {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            rarity: PokemonRarity.rare,
          );
        } else {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        }

      case PokemonRarity.special:
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.50) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            count: 2,
            rarity: PokemonRarity.special,
          );
        }
    }
  }
}
