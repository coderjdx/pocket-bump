import 'dart:math';
import '../models/item.dart';
import '../models/pokemon_species.dart';
import 'gym_database.dart';

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

  /// Rolls multi-item drop count:
  /// - 1 item: 50%
  /// - 2 items: 35%
  /// - 3 items: 15%
  static int rollDropCount([Random? rng]) {
    final double r = (rng ?? _rng).nextDouble();
    if (r < 0.50) return 1;
    if (r < 0.85) return 2;
    return 3;
  }

  /// Merges duplicate [ItemDrop] entries by `itemId`, summing counts in order.
  static List<ItemDrop> mergeDrops(List<ItemDrop> rawDrops) {
    final Map<String, ItemDrop> merged = {};
    for (final drop in rawDrops) {
      final existing = merged[drop.itemId];
      if (existing == null) {
        merged[drop.itemId] = drop;
      } else {
        merged[drop.itemId] = ItemDrop(
          itemId: existing.itemId,
          itemName: existing.itemName,
          count: existing.count + drop.count,
          rarity: existing.rarity,
        );
      }
    }
    return merged.values.toList();
  }

  /// Formats a list of drops cleanly (e.g. `"2x Potion, 1x Oran Berry"`).
  static String formatDrops(List<ItemDrop> drops) {
    return drops.map((d) => '${d.count}x ${d.itemName}').join(', ');
  }

  /// Rolls 1–3 item drops when a wild Pokémon is defeated or caught based on [species.rarity].
  ///
  /// Base encounter drop chances:
  /// - Common Pokémon: 50%
  /// - Uncommon Pokémon: 65%
  /// - Rare Pokémon: 80%
  /// - Special Pokémon (Legendary/Mythical): 100%
  ///
  /// When a drop triggers, rolls 1 (50%), 2 (35%), or 3 (15%) items from that
  /// rarity tier's pool and merges duplicate item stacks.
  static List<ItemDrop> rollDrops(PokemonSpecies species, {Random? rng}) {
    final Random r = rng ?? _rng;
    final double dropRoll = r.nextDouble();
    final double threshold;
    switch (species.rarity) {
      case PokemonRarity.common:
        threshold = 0.50;
        break;
      case PokemonRarity.uncommon:
        threshold = 0.65;
        break;
      case PokemonRarity.rare:
        threshold = 0.80;
        break;
      case PokemonRarity.special:
        threshold = 1.00;
        break;
    }
    if (dropRoll > threshold) return const [];

    final int dropCount = rollDropCount(r);
    final List<ItemDrop> rolled = [
      for (int i = 0; i < dropCount; i++)
        rollSingleTierItem(species.rarity, rng: r),
    ];
    return mergeDrops(rolled);
  }

  /// Backwards-compatible single-roll helper (returns the first merged drop if any).
  static ItemDrop? rollDrop(PokemonSpecies species, {Random? rng}) {
    final drops = rollDrops(species, rng: rng);
    return drops.isEmpty ? null : drops.first;
  }

  /// Rolls a single item from the given [rarity] pool:
  /// - Common: 25% Poké Ball, 25% Potion, 25% Status Cure, 25% Common Berry
  /// - Uncommon: 25% Great Ball, 25% Super Potion, 15% Full Heal, 7% Ether, 8% Revive, 20% Uncommon Berry
  /// - Rare: 25% Ultra Ball, 25% Hyper Potion, 15% Full Restore, 10% Revive, 9% Max Ether, 6% Elixir, 10% Rare Berry
  /// - Special: 30% Ultra Ball x2, 30% Hyper Potion x2, 25% Full Restore x2, 15% Max Elixir
  static ItemDrop rollSingleTierItem(PokemonRarity rarity, {Random? rng}) {
    final Random r = rng ?? _rng;
    final double subRoll = r.nextDouble();

    switch (rarity) {
      case PokemonRarity.common:
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
          return statusItems[r.nextInt(statusItems.length)];
        } else {
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
          return berryItems[r.nextInt(berryItems.length)];
        }

      case PokemonRarity.uncommon:
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
        } else if (subRoll < 0.72) {
          return const ItemDrop(
            itemId: 'ether',
            itemName: 'Ether',
            rarity: PokemonRarity.uncommon,
          );
        } else if (subRoll < 0.80) {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        } else {
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
          return berryItems[r.nextInt(berryItems.length)];
        }

      case PokemonRarity.rare:
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
        } else if (subRoll < 0.75) {
          return const ItemDrop(
            itemId: 'revive',
            itemName: 'Revive',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.84) {
          return const ItemDrop(
            itemId: 'max_ether',
            itemName: 'Max Ether',
            rarity: PokemonRarity.rare,
          );
        } else if (subRoll < 0.90) {
          return const ItemDrop(
            itemId: 'elixir',
            itemName: 'Elixir',
            rarity: PokemonRarity.rare,
          );
        } else {
          final berryRoll = r.nextInt(3);
          if (berryRoll == 0) {
            return const ItemDrop(
              itemId: 'lum_berry',
              itemName: 'Lum Berry',
              rarity: PokemonRarity.rare,
            );
          } else if (berryRoll == 1) {
            return const ItemDrop(
              itemId: 'leppa_berry',
              itemName: 'Leppa Berry',
              rarity: PokemonRarity.uncommon,
            );
          }
          return const ItemDrop(
            itemId: 'sitrus_berry',
            itemName: 'Sitrus Berry',
            count: 2,
            rarity: PokemonRarity.uncommon,
          );
        }

      case PokemonRarity.special:
        if (subRoll < 0.30) {
          return const ItemDrop(
            itemId: 'ultra_ball',
            itemName: 'Ultra Ball',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else if (subRoll < 0.60) {
          return const ItemDrop(
            itemId: 'hyper_potion',
            itemName: 'Hyper Potion',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else if (subRoll < 0.85) {
          return const ItemDrop(
            itemId: 'full_restore',
            itemName: 'Full Restore',
            count: 2,
            rarity: PokemonRarity.special,
          );
        } else {
          return const ItemDrop(
            itemId: 'max_elixir',
            itemName: 'Max Elixir',
            rarity: PokemonRarity.special,
          );
        }
    }
  }

  static ItemDrop _itemDropFromId(
    String itemId, {
    int count = 1,
    PokemonRarity fallbackRarity = PokemonRarity.rare,
  }) {
    final itemDef = ItemDatabase.byId(itemId);
    return ItemDrop(
      itemId: itemId,
      itemName: itemDef?.name ?? itemId,
      count: count,
      rarity: itemDef?.rarity ?? fallbackRarity,
    );
  }

  /// Guaranteed 1–3 item drops on Gym Leader rematch clears (no empty drops).
  ///
  /// When unowned TMs remain in [gym.tmDrops]:
  /// - 32% TM (never repeats TMs already in [ownedTmIds] or this roll)
  /// - 21% Signature held item
  /// - 19% Signature stone / Leftovers
  /// - 14% Unknown Fossil
  /// - 14% Fossil Restoration Voucher
  ///
  /// When all of [gym.tmDrops] are already owned, the 32% TM weight is
  /// redistributed proportionally across the 4 non-TM buckets.
  static List<ItemDrop> rollGymRematchDrops({
    required GymDefinition gym,
    required Set<String> ownedTmIds,
    Random? rng,
  }) {
    final Random r = rng ?? _rng;
    final int dropCount = rollDropCount(r);
    final Set<String> grantedTms = {};
    final List<ItemDrop> rawDrops = [];

    for (int i = 0; i < dropCount; i++) {
      final List<String> availableTms = gym.tmDrops
          .where((id) => !ownedTmIds.contains(id) && !grantedTms.contains(id))
          .toList();

      final double roll = r.nextDouble();
      if (availableTms.isNotEmpty) {
        if (roll < 0.32) {
          final String sigTm = gym.tmDrops.first;
          final String chosenTm =
              (availableTms.contains(sigTm) && r.nextDouble() < 0.35)
                  ? sigTm
                  : availableTms[r.nextInt(availableTms.length)];
          grantedTms.add(chosenTm);
          rawDrops.add(_itemDropFromId(chosenTm));
        } else if (roll < 0.53) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 0.72) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 0.86) {
          rawDrops.add(_itemDropFromId('unknown_fossil'));
        } else {
          rawDrops.add(_itemDropFromId('fossil_restoration_voucher'));
        }
      } else {
        // All TMs from this gym are already owned: redistribute 21:19:14:14
        if (roll < 21 / 68) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 40 / 68) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 54 / 68) {
          rawDrops.add(_itemDropFromId('unknown_fossil'));
        } else {
          rawDrops.add(_itemDropFromId('fossil_restoration_voucher'));
        }
      }
    }

    return mergeDrops(rawDrops);
  }

  /// Expedition Team Rocket battle reward:
  /// - 1–3 wild-like tier items (50% / 35% / 15%):
  ///   - Rocket Grunt: Uncommon (60%) or Rare (40%)
  ///   - Jessie & James: Rare (75%) or Special (25%)
  /// - Plus 1x random Special Poké Ball
  static List<ItemDrop> rollExpeditionRocketDrops({
    required bool isJessieOrJames,
    Random? rng,
  }) {
    final Random r = rng ?? _rng;
    final int wildItemCount = rollDropCount(r);
    final List<ItemDrop> rawDrops = [];

    for (int i = 0; i < wildItemCount; i++) {
      final PokemonRarity tier;
      if (isJessieOrJames) {
        tier = r.nextDouble() < 0.75
            ? PokemonRarity.rare
            : PokemonRarity.special;
      } else {
        tier = r.nextDouble() < 0.60
            ? PokemonRarity.uncommon
            : PokemonRarity.rare;
      }
      rawDrops.add(rollSingleTierItem(tier, rng: r));
    }

    final String specialBallId = ItemDatabase.specialBallIds[
        r.nextInt(ItemDatabase.specialBallIds.length)];
    rawDrops.add(_itemDropFromId(specialBallId));

    return mergeDrops(rawDrops);
  }
}
