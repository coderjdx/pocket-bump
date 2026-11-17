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
  /// - Common Pokémon (50% drop chance):
  ///   - 35% Poké Ball (Common)
  ///   - 35% Potion (Common)
  ///   - 30% Status Remedies (Common - single condition cure):
  ///     Antidote, Paralyze Heal, Awakening, Burn Heal, Ice Heal
  /// - Uncommon Pokémon (65% drop chance):
  ///   - 35% Great Ball (Uncommon)
  ///   - 35% Super Potion (Uncommon)
  ///   - 20% Full Heal (Uncommon - cures any status condition)
  ///   - 10% Revive (Rare)
  /// - Rare Pokémon (80% drop chance):
  ///   - 35% Ultra Ball (Rare)
  ///   - 30% Hyper Potion (Rare)
  ///   - 20% Full Restore (Rare - 100% HP + cures any status condition)
  ///   - 15% Revive (Rare)
  /// - Special Pokémon (100% drop chance - Legendary/Mythical event encounters):
  ///   - 35% Ultra Ball x2
  ///   - 35% Hyper Potion x2
  ///   - 30% Full Restore x2
  static ItemDrop? rollDrop(PokemonSpecies species) {
    final double dropRoll = _rng.nextDouble();
    switch (species.rarity) {
      case PokemonRarity.common:
        if (dropRoll > 0.50) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.35) {
          return const ItemDrop(
            itemId: 'poke_ball',
            itemName: 'Poké Ball',
            rarity: PokemonRarity.common,
          );
        } else if (subRoll < 0.70) {
          return const ItemDrop(
            itemId: 'potion',
            itemName: 'Potion',
            rarity: PokemonRarity.common,
          );
        } else {
          // Status healing items: Common (specific condition remedies)
          const statusItems = [
            ItemDrop(
              itemId: 'antidote',
              itemName: 'Antidote',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'paralyze_heal',
              itemName: 'Paralyze Heal',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'awakening',
              itemName: 'Awakening',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'burn_heal',
              itemName: 'Burn Heal',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'ice_heal',
              itemName: 'Ice Heal',
              rarity: PokemonRarity.common,
            ),
          ];
          return statusItems[_rng.nextInt(statusItems.length)];
        }

      case PokemonRarity.uncommon:
        if (dropRoll > 0.65) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.35) {
          return const ItemDrop(
            itemId: 'great_ball',
            itemName: 'Great Ball',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.70) {
          return const ItemDrop(
            itemId: 'super_potion',
            itemName: 'Super Potion',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.90) {
          // Status healing item: Uncommon (Universal all-status cure)
          return const ItemDrop(
            itemId: 'full_heal',
            itemName: 'Full Heal',
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
        if (dropRoll > 0.80) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.35) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.65) {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.85) {
          // Status + HP healing item: Rare (100% HP + all status cure)
          return const ItemDrop(
            itemId: 'full_restore',
            itemName: 'Full Restore',
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
        if (subRoll < 0.35) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else if (subRoll < 0.70) {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else {
          return const ItemDrop(
            itemId: 'full_restore',
            itemName: 'Full Restore',
            count: 2,
            rarity: PokemonRarity.special,
          );
        }
    }
  }
}
