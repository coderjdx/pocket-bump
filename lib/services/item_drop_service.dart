import 'dart:math';
import '../models/game_region.dart';
import '../models/item.dart';
import '../models/mystery_egg.dart';
import '../models/pokemon_species.dart';
import 'gym_database.dart';
import 'pokedex_database.dart';

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

  static const List<String> _johtoEvolutionItemIds = [
    'sun_stone',
    'metal_coat',
    'kings_rock',
    'dragon_scale',
    'up_grade',
  ];

  static ItemDrop _regionSpecialtyDrop(GymDefinition gym, Random r, {required bool secondSlot}) {
    if (gym.region.hasFossilLab) {
      return _itemDropFromId(secondSlot ? 'fossil_restoration_voucher' : 'unknown_fossil');
    }
    if (secondSlot) {
      return _itemDropFromId(r.nextDouble() < 0.55 ? 'rare_candy' : 'max_revive');
    }
    final picked = _johtoEvolutionItemIds[r.nextInt(_johtoEvolutionItemIds.length)];
    return _itemDropFromId(picked);
  }

  /// Guaranteed 1–3 item drops on Gym Leader rematch clears (no empty drops).
  /// Heart Scales drop exclusively from Gym Leaders and Team Rocket.
  ///
  /// Kanto Gyms drop Unknown Fossils / Vouchers; Johto Gyms drop Gen 2
  /// Evolution Items (Sun Stone, Metal Coat, King's Rock, Dragon Scale, Up-Grade)
  /// and Rare Candy / Max Revive instead of Kanto fossils.
  static List<ItemDrop> rollGymRematchDrops({
    required GymDefinition gym,
    required Set<String> ownedTmIds,
    Set<String> ownedAdventureMapIds = const {},
    Random? rng,
  }) {
    final Random r = rng ?? _rng;
    final int dropCount = rollDropCount(r);
    final Set<String> grantedTms = {};
    final Set<String> grantedMaps = {};
    final List<ItemDrop> rawDrops = [];

    for (int i = 0; i < dropCount; i++) {
      final List<String> availableTms = gym.tmDrops
          .where((id) => !ownedTmIds.contains(id) && !grantedTms.contains(id))
          .toList();
      final bool canDropMap = gym.signatureAdventureMapDrop.isNotEmpty &&
          !ownedAdventureMapIds.contains(gym.signatureAdventureMapDrop) &&
          !grantedMaps.contains(gym.signatureAdventureMapDrop);

      final double roll = r.nextDouble();
      if (canDropMap && availableTms.isNotEmpty) {
        if (roll < 0.15) {
          grantedMaps.add(gym.signatureAdventureMapDrop);
          rawDrops.add(_itemDropFromId(gym.signatureAdventureMapDrop));
        } else if (roll < 0.39) {
          final String sigTm = gym.tmDrops.first;
          final String chosenTm =
              (availableTms.contains(sigTm) && r.nextDouble() < 0.35)
                  ? sigTm
                  : availableTms[r.nextInt(availableTms.length)];
          grantedTms.add(chosenTm);
          rawDrops.add(_itemDropFromId(chosenTm));
        } else if (roll < 0.54) {
          rawDrops.add(_itemDropFromId('heart_scale'));
        } else if (roll < 0.68) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 0.80) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 0.90) {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: false));
        } else {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: true));
        }
      } else if (canDropMap) {
        // Unowned Adventure Map, all TMs owned: 15:15:14:12:10:10 (sum 76)
        if (roll < 15 / 76) {
          grantedMaps.add(gym.signatureAdventureMapDrop);
          rawDrops.add(_itemDropFromId(gym.signatureAdventureMapDrop));
        } else if (roll < 30 / 76) {
          rawDrops.add(_itemDropFromId('heart_scale'));
        } else if (roll < 44 / 76) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 56 / 76) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 66 / 76) {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: false));
        } else {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: true));
        }
      } else if (availableTms.isNotEmpty) {
        if (roll < 0.28) {
          final String sigTm = gym.tmDrops.first;
          final String chosenTm =
              (availableTms.contains(sigTm) && r.nextDouble() < 0.35)
                  ? sigTm
                  : availableTms[r.nextInt(availableTms.length)];
          grantedTms.add(chosenTm);
          rawDrops.add(_itemDropFromId(chosenTm));
        } else if (roll < 0.46) {
          rawDrops.add(_itemDropFromId('heart_scale'));
        } else if (roll < 0.62) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 0.76) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 0.88) {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: false));
        } else {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: true));
        }
      } else {
        // All TMs & Map owned: 18:16:14:12:12 (sum 72)
        if (roll < 18 / 72) {
          rawDrops.add(_itemDropFromId('heart_scale'));
        } else if (roll < 34 / 72) {
          rawDrops.add(_itemDropFromId(gym.signatureHeldItemDrop));
        } else if (roll < 48 / 72) {
          rawDrops.add(_itemDropFromId(gym.signatureStoneDrop));
        } else if (roll < 60 / 72) {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: false));
        } else {
          rawDrops.add(_regionSpecialtyDrop(gym, r, secondSlot: true));
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
  /// - Plus Heart Scale chance (Grunt: 35% for 1x; Jessie/James: 65% for 1x–2x)
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

    final double heartChance = isJessieOrJames ? 0.65 : 0.35;
    if (r.nextDouble() < heartChance) {
      final int scaleCount =
          (isJessieOrJames && r.nextDouble() < 0.25) ? 2 : 1;
      rawDrops.add(_itemDropFromId('heart_scale', count: scaleCount));
    }

    return mergeDrops(rawDrops);
  }

  /// Final-stage species of the 8 Baby Pokémon lines rarely drop a "Mystery Egg"
  /// that remembers which baby species it came from.
  static MysteryEgg? rollMysteryEggDrop(
    PokemonSpecies defeated, {
    required String originRegion,
    double chance = 0.12,
    Random? rng,
  }) {
    final int? babyId = MysteryEgg.babyEggSourceToBabySpecies[defeated.id];
    if (babyId == null) return null;
    if (!PokedexDatabase.species.containsKey(babyId)) return null;
    final Random r = rng ?? _rng;
    if (r.nextDouble() >= chance) return null;
    return MysteryEgg(
      eggId:
          'egg_${babyId}_${DateTime.now().microsecondsSinceEpoch}_${r.nextInt(9999)}',
      speciesId: babyId,
      requiredProgress: MysteryEgg.requiredProgressForBaby(babyId),
      originRegion: originRegion,
    );
  }

  /// Rare reusable Lab Equipment drop (Flame Armor / Magma Armor, max 1 each).
  static ItemDrop? rollLabArmorDrop({
    required bool hasFlameArmor,
    required bool hasMagmaArmor,
    double chance = 0.03,
    Random? rng,
  }) {
    final List<String> candidates = [
      if (!hasFlameArmor) 'flame_armor',
      if (!hasMagmaArmor) 'magma_armor',
    ];
    if (candidates.isEmpty) return null;
    final Random r = rng ?? _rng;
    if (r.nextDouble() >= chance) return null;
    final String picked = candidates[r.nextInt(candidates.length)];
    return _itemDropFromId(picked);
  }
}
