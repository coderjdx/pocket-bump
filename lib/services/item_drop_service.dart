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
  ///   - 25% Poké Ball (Common)
  ///   - 25% Potion (Common)
  ///   - 25% Status Remedies (Antidote, Paralyze Heal, Awakening, Burn Heal, Ice Heal)
  ///   - 25% Berries (Oran, Pecha, Cheri, Chesto, Rawst, Aspear)
  /// - Uncommon Pokémon (65% drop chance):
  ///   - 25% Great Ball (Uncommon)
  ///   - 25% Super Potion (Uncommon)
  ///   - 15% Full Heal (Uncommon)
  ///   - 10% Revive (Rare)
  ///   - 25% Berries (Sitrus Berry, Lum Berry)
  /// - Rare Pokémon (80% drop chance):
  ///   - 25% Ultra Ball (Rare)
  ///   - 25% Hyper Potion (Rare)
  ///   - 15% Full Restore (Rare)
  ///   - 15% Revive (Rare)
  ///   - 20% Berries (Lum Berry, Sitrus Berry x2)
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
        if (subRoll < 0.25) {
          return const ItemDrop(
            itemId: 'poke_ball',
            itemName: 'Poké Ball',
            rarity: PokemonRarity.common,
          );
        } else if (subRoll < 0.50) {
          return const ItemDrop(
            itemId: 'potion',
            itemName: 'Potion',
            rarity: PokemonRarity.common,
          );
        } else if (subRoll < 0.75) {
          // Status remedies
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
        } else {
          // Common Berries
          const berryItems = [
            ItemDrop(
              itemId: 'oran_berry',
              itemName: 'Oran Berry',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'pecha_berry',
              itemName: 'Pecha Berry',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'cheri_berry',
              itemName: 'Cheri Berry',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'chesto_berry',
              itemName: 'Chesto Berry',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'rawst_berry',
              itemName: 'Rawst Berry',
              rarity: PokemonRarity.common,
            ),
            ItemDrop(
              itemId: 'aspear_berry',
              itemName: 'Aspear Berry',
              rarity: PokemonRarity.common,
            ),
          ];
          return berryItems[_rng.nextInt(berryItems.length)];
        }

      case PokemonRarity.uncommon:
        if (dropRoll > 0.65) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.25) {
          return const ItemDrop(
            itemId: 'great_ball',
            itemName: 'Great Ball',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.50) {
          return const ItemDrop(
            itemId: 'super_potion',
            itemName: 'Super Potion',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.65) {
          return const ItemDrop(
            itemId: 'full_heal',
            itemName: 'Full Heal',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.75) {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        } else {
          // Uncommon Berries
          const berryItems = [
            ItemDrop(
              itemId: 'sitrus_berry',
              itemName: 'Sitrus Berry',
              rarity: PokemonRarity.uncommon,
            ),
            ItemDrop(
              itemId: 'lum_berry',
              itemName: 'Lum Berry',
              rarity: PokemonRarity.rare,
            ),
          ];
          return berryItems[_rng.nextInt(berryItems.length)];
        }

      case PokemonRarity.rare:
        if (dropRoll > 0.80) return null;
        final subRoll = _rng.nextDouble();
        if (subRoll < 0.25) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.50) {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.65) {
          return const ItemDrop(
            itemId: 'full_restore',
            itemName: 'Full Restore',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.80) {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        } else {
          // Rare Berries
          final isLum = _rng.nextBool();
          return isLum
              ? const ItemDrop(
                  itemId: 'lum_berry',
                  itemName: 'Lum Berry',
                  rarity: PokemonRarity.rare,
                )
              : const ItemDrop(
                  itemId: 'sitrus_berry',
                  itemName: 'Sitrus Berry',
                  count: 2,
                  rarity: PokemonRarity.uncommon,
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
