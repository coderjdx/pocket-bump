import 'package:flutter/material.dart';
import 'pokemon_species.dart';

enum ItemCategory {
  pokeball,
  medicine,
  berry,
  heldItem,
  evolutionStone,
}

class Item {
  final String id;
  final String name;
  final String description;
  final ItemCategory category;
  final int? price; // Price in Poke Mart (null if cannot be purchased)
  final int requiredBadges; // Minimum badges required to buy at Poke Mart
  final PokemonRarity rarity;
  final Color color;
  final IconData icon;

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.price,
    this.requiredBadges = 0,
    required this.rarity,
    required this.color,
    required this.icon,
  });

  bool get isBuyable => price != null;
  bool get isBerry => category == ItemCategory.berry;
  bool get isHeldItem => category == ItemCategory.heldItem;
  bool get isEvolutionStone => category == ItemCategory.evolutionStone;
  bool get isBall => category == ItemCategory.pokeball;
  bool get isMedicine => category == ItemCategory.medicine;
}

class ItemDatabase {
  static const Map<String, Item> allItems = {
    // === BALLS ===
    'poke_ball': Item(
      id: 'poke_ball',
      name: 'Poké Ball',
      description: 'A device for catching wild Pokémon (1.0x catch rate).',
      category: ItemCategory.pokeball,
      price: 200,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFEF5350),
      icon: Icons.sports_baseball,
    ),
    'great_ball': Item(
      id: 'great_ball',
      name: 'Great Ball',
      description: 'A good Poké Ball with a higher catch rate (1.5x catch rate).',
      category: ItemCategory.pokeball,
      price: 600,
      requiredBadges: 2,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF42A5F5),
      icon: Icons.sports_baseball,
    ),
    'ultra_ball': Item(
      id: 'ultra_ball',
      name: 'Ultra Ball',
      description: 'An ultra-high performance Poké Ball (2.0x catch rate).',
      category: ItemCategory.pokeball,
      price: 1200,
      requiredBadges: 4,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFCA28),
      icon: Icons.sports_baseball,
    ),

    // === MEDICINE ===
    'potion': Item(
      id: 'potion',
      name: 'Potion',
      description: 'Restores 20 HP for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 300,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFAB47BC),
      icon: Icons.local_hospital,
    ),
    'super_potion': Item(
      id: 'super_potion',
      name: 'Super Potion',
      description: 'Restores 50 HP for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 700,
      requiredBadges: 1,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFE53935),
      icon: Icons.local_hospital,
    ),
    'hyper_potion': Item(
      id: 'hyper_potion',
      name: 'Hyper Potion',
      description: 'Restores 200 HP for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 1200,
      requiredBadges: 4,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF9800),
      icon: Icons.local_hospital,
    ),
    'max_potion': Item(
      id: 'max_potion',
      name: 'Max Potion',
      description: 'Fully restores HP for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 2500,
      requiredBadges: 6,
      rarity: PokemonRarity.rare,
      color: Color(0xFF29B6F6),
      icon: Icons.healing,
    ),
    'full_restore': Item(
      id: 'full_restore',
      name: 'Full Restore',
      description: 'Fully restores HP and cures all status ailments for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 3000,
      requiredBadges: 7,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF80AB),
      icon: Icons.stars,
    ),
    'revive': Item(
      id: 'revive',
      name: 'Revive',
      description: 'Revives a fainted Pokémon to 50% max HP.',
      category: ItemCategory.medicine,
      price: 1500,
      requiredBadges: 3,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFD54F),
      icon: Icons.favorite,
    ),

    // === STATUS REMEDIES ===
    'antidote': Item(
      id: 'antidote',
      name: 'Antidote',
      description: 'Cures a Pokémon of poisoning.',
      category: ItemCategory.medicine,
      price: 100,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFAB47BC),
      icon: Icons.healing,
    ),
    'paralyze_heal': Item(
      id: 'paralyze_heal',
      name: 'Paralyze Heal',
      description: 'Cures a Pokémon of paralysis.',
      category: ItemCategory.medicine,
      price: 200,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFFFEE58),
      icon: Icons.flash_on,
    ),
    'awakening': Item(
      id: 'awakening',
      name: 'Awakening',
      description: 'Awakens a sleeping Pokémon.',
      category: ItemCategory.medicine,
      price: 250,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFF26C6DA),
      icon: Icons.alarm,
    ),
    'burn_heal': Item(
      id: 'burn_heal',
      name: 'Burn Heal',
      description: 'Cures a Pokémon of a burn.',
      category: ItemCategory.medicine,
      price: 250,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFFF7043),
      icon: Icons.whatshot,
    ),
    'ice_heal': Item(
      id: 'ice_heal',
      name: 'Ice Heal',
      description: 'Thaws a frozen Pokémon.',
      category: ItemCategory.medicine,
      price: 250,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFF80DEEA),
      icon: Icons.ac_unit,
    ),
    'full_heal': Item(
      id: 'full_heal',
      name: 'Full Heal',
      description: 'Cures all status ailments for a single Pokémon.',
      category: ItemCategory.medicine,
      price: 600,
      requiredBadges: 2,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF64FFDA),
      icon: Icons.auto_fix_high,
    ),

    // === BERRIES (Wild Drops & Auto-Used when Held) ===
    'oran_berry': Item(
      id: 'oran_berry',
      name: 'Oran Berry',
      description: 'Held Berry: Restores 10 HP when holder HP drops to 50% or less.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFF42A5F5),
      icon: Icons.eco,
    ),
    'sitrus_berry': Item(
      id: 'sitrus_berry',
      name: 'Sitrus Berry',
      description: 'Held Berry: Restores 30 HP when holder HP drops to 50% or less.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFFFD54F),
      icon: Icons.eco,
    ),
    'cheri_berry': Item(
      id: 'cheri_berry',
      name: 'Cheri Berry',
      description: 'Held Berry: Instantly cures paralysis in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFEF5350),
      icon: Icons.eco,
    ),
    'chesto_berry': Item(
      id: 'chesto_berry',
      name: 'Chesto Berry',
      description: 'Held Berry: Instantly cures sleep in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFF8D6E63),
      icon: Icons.eco,
    ),
    'pecha_berry': Item(
      id: 'pecha_berry',
      name: 'Pecha Berry',
      description: 'Held Berry: Instantly cures poison in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFF48FB1),
      icon: Icons.eco,
    ),
    'rawst_berry': Item(
      id: 'rawst_berry',
      name: 'Rawst Berry',
      description: 'Held Berry: Instantly cures burn in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFF81C784),
      icon: Icons.eco,
    ),
    'aspear_berry': Item(
      id: 'aspear_berry',
      name: 'Aspear Berry',
      description: 'Held Berry: Instantly cures freeze in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.common,
      color: Color(0xFFFFB74D),
      icon: Icons.eco,
    ),
    'lum_berry': Item(
      id: 'lum_berry',
      name: 'Lum Berry',
      description: 'Held Berry: Instantly cures any status condition in battle.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF80CBC4),
      icon: Icons.eco,
    ),

    // === HELD ITEMS (Gym Leader Repeat Rare Drops) ===
    'hard_stone': Item(
      id: 'hard_stone',
      name: 'Hard Stone',
      description: 'Held Item: An unbreakable stone that boosts Rock-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBCAAA4),
      icon: Icons.terrain,
    ),
    'mystic_water': Item(
      id: 'mystic_water',
      name: 'Mystic Water',
      description: 'Held Item: A tear-shaped gem that boosts Water-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF29B6F6),
      icon: Icons.water_drop,
    ),
    'magnet': Item(
      id: 'magnet',
      name: 'Magnet',
      description: 'Held Item: A powerful magnet that boosts Electric-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFD54F),
      icon: Icons.flash_on,
    ),
    'miracle_seed': Item(
      id: 'miracle_seed',
      name: 'Miracle Seed',
      description: 'Held Item: A life-imbued seed that boosts Grass-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF66BB6A),
      icon: Icons.grass,
    ),
    'poison_barb': Item(
      id: 'poison_barb',
      name: 'Poison Barb',
      description: 'Held Item: A small, toxic barb that boosts Poison-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBA68C8),
      icon: Icons.colorize,
    ),
    'twisted_spoon': Item(
      id: 'twisted_spoon',
      name: 'Twisted Spoon',
      description: 'Held Item: A telekinetically charged spoon that boosts Psychic moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF4081),
      icon: Icons.psychology,
    ),
    'charcoal': Item(
      id: 'charcoal',
      name: 'Charcoal',
      description: 'Held Item: A combustible fuel that boosts Fire-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF7043),
      icon: Icons.local_fire_department,
    ),
    'soft_sand': Item(
      id: 'soft_sand',
      name: 'Soft Sand',
      description: 'Held Item: Finely textured sand that boosts Ground-type moves by 20%.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFCA28),
      icon: Icons.grain,
    ),
    'leftovers': Item(
      id: 'leftovers',
      name: 'Leftovers',
      description: 'Held Item: Gradually restores 1/16 of max HP at the end of each battle turn.',
      category: ItemCategory.heldItem,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF81C784),
      icon: Icons.restaurant,
    ),

    // === EVOLUTION STONES (Post-Gym 8 Poke Mart & Rare Leader Drops) ===
    'fire_stone': Item(
      id: 'fire_stone',
      name: 'Fire Stone',
      description: 'A peculiar stone that triggers evolution in certain Fire Pokémon (e.g. Vulpix, Growlithe, Eevee).',
      category: ItemCategory.evolutionStone,
      price: 5000,
      requiredBadges: 8,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF5722),
      icon: Icons.whatshot,
    ),
    'water_stone': Item(
      id: 'water_stone',
      name: 'Water Stone',
      description: 'A peculiar stone that triggers evolution in certain Water Pokémon (e.g. Poliwhirl, Shellder, Staryu, Eevee).',
      category: ItemCategory.evolutionStone,
      price: 5000,
      requiredBadges: 8,
      rarity: PokemonRarity.rare,
      color: Color(0xFF03A9F4),
      icon: Icons.water_drop,
    ),
    'thunder_stone': Item(
      id: 'thunder_stone',
      name: 'Thunder Stone',
      description: 'A peculiar stone that triggers evolution in certain Electric Pokémon (e.g. Pikachu, Eevee).',
      category: ItemCategory.evolutionStone,
      price: 5000,
      requiredBadges: 8,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFEB3B),
      icon: Icons.flash_on,
    ),
    'leaf_stone': Item(
      id: 'leaf_stone',
      name: 'Leaf Stone',
      description: 'A peculiar stone that triggers evolution in certain Grass Pokémon (e.g. Gloom, Weepinbell, Exeggcute).',
      category: ItemCategory.evolutionStone,
      price: 5000,
      requiredBadges: 8,
      rarity: PokemonRarity.rare,
      color: Color(0xFF4CAF50),
      icon: Icons.spa,
    ),
    'moon_stone': Item(
      id: 'moon_stone',
      name: 'Moon Stone',
      description: 'A peculiar stone that triggers evolution in certain Pokémon (e.g. Nidorina, Nidorino, Clefairy, Jigglypuff).',
      category: ItemCategory.evolutionStone,
      price: 5000,
      requiredBadges: 8,
      rarity: PokemonRarity.rare,
      color: Color(0xFF9FA8DA),
      icon: Icons.nightlight_round,
    ),
  };

  static Item? byId(String id) => allItems[id];

  /// List of items available in the Poké Mart based on player's badge count.
  /// Evolution stones only unlock after all 8 badges. Rare Candies are strictly excluded.
  static List<Item> getMartItems(int badgeCount) {
    return allItems.values
        .where((item) => item.isBuyable && badgeCount >= item.requiredBadges)
        .toList();
  }

  /// Evolution stone compatibility table
  static int? getStoneEvolutionTarget(String stoneId, int speciesId) {
    switch (stoneId) {
      case 'fire_stone':
        if (speciesId == 37) return 38; // Vulpix -> Ninetales
        if (speciesId == 58) return 59; // Growlithe -> Arcanine
        if (speciesId == 133) return 136; // Eevee -> Flareon
        break;
      case 'water_stone':
        if (speciesId == 61) return 62; // Poliwhirl -> Poliwrath
        if (speciesId == 90) return 91; // Shellder -> Cloyster
        if (speciesId == 120) return 121; // Staryu -> Starmie
        if (speciesId == 133) return 134; // Eevee -> Vaporeon
        break;
      case 'thunder_stone':
        if (speciesId == 25) return 26; // Pikachu -> Raichu
        if (speciesId == 133) return 135; // Eevee -> Jolteon
        break;
      case 'leaf_stone':
        if (speciesId == 44) return 45; // Gloom -> Vileplume
        if (speciesId == 70) return 71; // Weepinbell -> Victreebel
        if (speciesId == 102) return 103; // Exeggcute -> Exeggutor
        break;
      case 'moon_stone':
        if (speciesId == 30) return 31; // Nidorina -> Nidoqueen
        if (speciesId == 33) return 34; // Nidorino -> Nidoking
        if (speciesId == 35) return 36; // Clefairy -> Clefable
        if (speciesId == 39) return 40; // Jigglypuff -> Wigglytuff
        break;
    }
    return null;
  }
}
