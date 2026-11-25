import 'dart:math';
import 'package:flutter/material.dart';
import 'pokemon_instance.dart';
import 'pokemon_species.dart';

enum ItemCategory {
  pokeball,
  medicine,
  berry,
  heldItem,
  evolutionStone,
  fossil,
  tm,
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
  final String? moveId;

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
    this.moveId,
  });

  bool get isBuyable => price != null;
  bool get isBerry => category == ItemCategory.berry;
  bool get isHeldItem => category == ItemCategory.heldItem;
  bool get isEvolutionStone => category == ItemCategory.evolutionStone;
  bool get isFossil => category == ItemCategory.fossil;
  bool get isTm => category == ItemCategory.tm;
  bool get isReusable => isTm;
  bool get isBall => category == ItemCategory.pokeball;
  bool get isMedicine => category == ItemCategory.medicine;
}

class ItemDatabase {
  static const List<String> standardBallIds = [
    'poke_ball',
    'great_ball',
    'ultra_ball',
    'master_ball',
  ];

  static const List<String> specialBallIds = [
    'quick_ball',
    'timer_ball',
    'dusk_ball',
    'net_ball',
    'fast_ball',
    'dream_ball',
    'repeat_ball',
    'level_ball',
    'heal_ball',
  ];

  static List<Item> get allBalls => [
        for (final id in [...standardBallIds, ...specialBallIds])
          if (allItems[id] != null) allItems[id]!,
      ];

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
    'master_ball': Item(
      id: 'master_ball',
      name: 'Master Ball',
      description: 'The ultimate Poké Ball that catches any wild Pokémon without fail (100% catch rate).',
      category: ItemCategory.pokeball,
      requiredBadges: 8,
      rarity: PokemonRarity.special,
      color: Color(0xFFAB47BC),
      icon: Icons.catching_pokemon,
    ),
    'quick_ball': Item(
      id: 'quick_ball',
      name: 'Quick Ball',
      description: 'An ultra-fast Poké Ball with a 5.0x catch rate when thrown on Turn 1 of battle.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFF29B6F6),
      icon: Icons.bolt_rounded,
    ),
    'timer_ball': Item(
      id: 'timer_ball',
      name: 'Timer Ball',
      description: 'A Poké Ball that grows stronger each turn, scaling from 1.0x up to 4.0x in long battles.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFEF5350),
      icon: Icons.timer_rounded,
    ),
    'dusk_ball': Item(
      id: 'dusk_ball',
      name: 'Dusk Ball',
      description: 'A shadowy Poké Ball with a 3.0x catch rate at night (8 PM–6 AM) or during Expeditions.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFF2E7D32),
      icon: Icons.nights_stay_rounded,
    ),
    'net_ball': Item(
      id: 'net_ball',
      name: 'Net Ball',
      description: 'A specialized Poké Ball with a 3.5x catch rate on Water- and Bug-type Pokémon.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFF26A69A),
      icon: Icons.grid_4x4_rounded,
    ),
    'fast_ball': Item(
      id: 'fast_ball',
      name: 'Fast Ball',
      description: 'A sleek Poké Ball with a 4.0x catch rate on agile Pokémon with 100+ Base Speed.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF7043),
      icon: Icons.speed_rounded,
    ),
    'dream_ball': Item(
      id: 'dream_ball',
      name: 'Dream Ball',
      description: 'A misty Poké Ball with a 4.0x catch rate on sleeping wild Pokémon.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFEC407A),
      icon: Icons.bedtime_rounded,
    ),
    'repeat_ball': Item(
      id: 'repeat_ball',
      name: 'Repeat Ball',
      description: 'A Poké Ball with a 3.5x catch rate on species already registered in your Pokédex.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFB300),
      icon: Icons.repeat_rounded,
    ),
    'level_ball': Item(
      id: 'level_ball',
      name: 'Level Ball',
      description: 'A Poké Ball with 2.0x catch rate if your Pokémon outlevels the target (4.0x at 2x+ level).',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFCA28),
      icon: Icons.trending_up_rounded,
    ),
    'heal_ball': Item(
      id: 'heal_ball',
      name: 'Heal Ball',
      description: 'A soothing Poké Ball (1.5x catch rate) that fully restores HP, PP, and status on catch.',
      category: ItemCategory.pokeball,
      rarity: PokemonRarity.rare,
      color: Color(0xFFF48FB1),
      icon: Icons.favorite_rounded,
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

    // === PP RESTORE ===
    'ether': Item(
      id: 'ether',
      name: 'Ether',
      description: 'Restores 10 PP to one selected move of a single Pokémon.',
      category: ItemCategory.medicine,
      price: 1200,
      requiredBadges: 5,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF9575CD),
      icon: Icons.bolt_rounded,
    ),
    'max_ether': Item(
      id: 'max_ether',
      name: 'Max Ether',
      description: 'Fully restores the PP of one selected move of a single Pokémon.',
      category: ItemCategory.medicine,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF7E57C2),
      icon: Icons.flash_on_rounded,
    ),
    'elixir': Item(
      id: 'elixir',
      name: 'Elixir',
      description: 'Restores 10 PP to all moves of a single Pokémon.',
      category: ItemCategory.medicine,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF26A69A),
      icon: Icons.auto_awesome,
    ),
    'max_elixir': Item(
      id: 'max_elixir',
      name: 'Max Elixir',
      description: 'Fully restores the PP of all moves of a single Pokémon.',
      category: ItemCategory.medicine,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.special,
      color: Color(0xFF00E5FF),
      icon: Icons.flare_rounded,
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
    'leppa_berry': Item(
      id: 'leppa_berry',
      name: 'Leppa Berry',
      description: 'Held Berry: Restores 10 PP when a move runs out of PP, or use from Bag on a move.',
      category: ItemCategory.berry,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFEF5350),
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

    // === FOSSIL RESTORATION ITEMS (Gym Leader Repeat Rare Drops) ===
    'unknown_fossil': Item(
      id: 'unknown_fossil',
      name: 'Unknown Fossil',
      description: 'A mysterious prehistoric fossil. Take it with a Fossil Restoration Voucher to a Poké Lab to restore it.',
      category: ItemCategory.fossil,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFFD7CCC8),
      icon: Icons.album,
    ),
    'fossil_restoration_voucher': Item(
      id: 'fossil_restoration_voucher',
      name: 'Fossil Restoration Voucher',
      description: 'Requires an Unknown Fossil. Redeem at a Poké Lab to restore a random Lv. 10 first-stage Fossil Pokémon.',
      category: ItemCategory.fossil,
      price: null,
      requiredBadges: 0,
      rarity: PokemonRarity.rare,
      color: Color(0xFF4DD0E1),
      icon: Icons.science,
    ),

    // === GEN 1 TECHNICAL MACHINES (TM01 - TM50) ===
    'tm_01': Item(
      id: 'tm_01',
      name: 'TM01 Mega Punch',
      description: 'Teaches Mega Punch (80 PWR Fighting-limb power punch) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'mega_punch',
    ),
    'tm_02': Item(
      id: 'tm_02',
      name: 'TM02 Razor Wind',
      description: 'Teaches Razor Wind (80 PWR slicing whirlwind) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF90CAF9),
      icon: Icons.album_rounded,
      moveId: 'razor_wind',
    ),
    'tm_03': Item(
      id: 'tm_03',
      name: 'TM03 Swords Dance',
      description: 'Teaches Swords Dance (+2 Atk setup dance) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFE0E0E0),
      icon: Icons.album_rounded,
      moveId: 'swords_dance',
    ),
    'tm_04': Item(
      id: 'tm_04',
      name: 'TM04 Whirlwind',
      description: 'Teaches Whirlwind (lowers target Speed) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF90CAF9),
      icon: Icons.album_rounded,
      moveId: 'whirlwind',
    ),
    'tm_05': Item(
      id: 'tm_05',
      name: 'TM05 Mega Kick',
      description: 'Teaches Mega Kick (120 PWR heavy kick) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'mega_kick',
    ),
    'tm_06': Item(
      id: 'tm_06',
      name: 'TM06 Toxic',
      description: 'Teaches Toxic (badly poisons the target) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFAB47BC),
      icon: Icons.album_rounded,
      moveId: 'toxic',
    ),
    'tm_07': Item(
      id: 'tm_07',
      name: 'TM07 Horn Drill',
      description: 'Teaches Horn Drill (massive piercing horn strike) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'horn_drill',
    ),
    'tm_08': Item(
      id: 'tm_08',
      name: 'TM08 Body Slam',
      description: 'Teaches Body Slam (85 PWR + 30% Paralyze) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'body_slam',
    ),
    'tm_09': Item(
      id: 'tm_09',
      name: 'TM09 Take Down',
      description: 'Teaches Take Down (90 PWR reckless charge) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'take_down',
    ),
    'tm_10': Item(
      id: 'tm_10',
      name: 'TM10 Double-Edge',
      description: 'Teaches Double-Edge (120 PWR full-force tackle) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'double_edge',
    ),
    'tm_11': Item(
      id: 'tm_11',
      name: 'TM11 Bubble Beam',
      description: 'Teaches Bubble Beam (65 PWR Water attack) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF42A5F5),
      icon: Icons.album_rounded,
      moveId: 'bubble_beam',
    ),
    'tm_12': Item(
      id: 'tm_12',
      name: 'TM12 Water Gun',
      description: 'Teaches Water Gun (40 PWR Water blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF42A5F5),
      icon: Icons.album_rounded,
      moveId: 'water_gun',
    ),
    'tm_13': Item(
      id: 'tm_13',
      name: 'TM13 Ice Beam',
      description: 'Teaches Ice Beam (90 PWR freezing beam) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF4DD0E1),
      icon: Icons.album_rounded,
      moveId: 'ice_beam',
    ),
    'tm_14': Item(
      id: 'tm_14',
      name: 'TM14 Blizzard',
      description: 'Teaches Blizzard (110 PWR howling snowstorm) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF4DD0E1),
      icon: Icons.album_rounded,
      moveId: 'blizzard',
    ),
    'tm_15': Item(
      id: 'tm_15',
      name: 'TM15 Hyper Beam',
      description: 'Teaches Hyper Beam (150 PWR devastating beam) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFE0E0E0),
      icon: Icons.album_rounded,
      moveId: 'hyper_beam',
    ),
    'tm_16': Item(
      id: 'tm_16',
      name: 'TM16 Pay Day',
      description: 'Teaches Pay Day (40 PWR coin-hurling strike) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFFFD54F),
      icon: Icons.album_rounded,
      moveId: 'pay_day',
    ),
    'tm_17': Item(
      id: 'tm_17',
      name: 'TM17 Submission',
      description: 'Teaches Submission (80 PWR Fighting throw) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFD32F2F),
      icon: Icons.album_rounded,
      moveId: 'submission',
    ),
    'tm_18': Item(
      id: 'tm_18',
      name: 'TM18 Counter',
      description: 'Teaches Counter (75 PWR retaliatory Fighting hit) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFD32F2F),
      icon: Icons.album_rounded,
      moveId: 'counter',
    ),
    'tm_19': Item(
      id: 'tm_19',
      name: 'TM19 Seismic Toss',
      description: 'Teaches Seismic Toss (80 PWR gravity slam) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFD32F2F),
      icon: Icons.album_rounded,
      moveId: 'seismic_toss',
    ),
    'tm_20': Item(
      id: 'tm_20',
      name: 'TM20 Rage',
      description: 'Teaches Rage (55 PWR furious tackle) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'rage',
    ),
    'tm_21': Item(
      id: 'tm_21',
      name: 'TM21 Mega Drain',
      description: 'Teaches Mega Drain (60 PWR Grass absorption) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFF66BB6A),
      icon: Icons.album_rounded,
      moveId: 'mega_drain',
    ),
    'tm_22': Item(
      id: 'tm_22',
      name: 'TM22 Solar Beam',
      description: 'Teaches Solar Beam (120 PWR solar energy blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF66BB6A),
      icon: Icons.album_rounded,
      moveId: 'solar_beam',
    ),
    'tm_23': Item(
      id: 'tm_23',
      name: 'TM23 Dragon Rage',
      description: 'Teaches Dragon Rage (shockwave Dragon blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF7E57C2),
      icon: Icons.album_rounded,
      moveId: 'dragon_rage',
    ),
    'tm_24': Item(
      id: 'tm_24',
      name: 'TM24 Thunderbolt',
      description: 'Teaches Thunderbolt (90 PWR + 10% Paralyze) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFEE58),
      icon: Icons.album_rounded,
      moveId: 'thunderbolt',
    ),
    'tm_25': Item(
      id: 'tm_25',
      name: 'TM25 Thunder',
      description: 'Teaches Thunder (110 PWR + 30% Paralyze) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFEE58),
      icon: Icons.album_rounded,
      moveId: 'thunder',
    ),
    'tm_26': Item(
      id: 'tm_26',
      name: 'TM26 Earthquake',
      description: 'Teaches Earthquake (100 PWR Ground tremor) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFD4A359),
      icon: Icons.album_rounded,
      moveId: 'earthquake',
    ),
    'tm_27': Item(
      id: 'tm_27',
      name: 'TM27 Fissure',
      description: 'Teaches Fissure (130 PWR earth-splitting strike) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFD4A359),
      icon: Icons.album_rounded,
      moveId: 'fissure',
    ),
    'tm_28': Item(
      id: 'tm_28',
      name: 'TM28 Dig',
      description: 'Teaches Dig (80 PWR burrowing Ground strike) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFD4A359),
      icon: Icons.album_rounded,
      moveId: 'dig',
    ),
    'tm_29': Item(
      id: 'tm_29',
      name: 'TM29 Psychic',
      description: 'Teaches Psychic (90 PWR telekinetic blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'psychic',
    ),
    'tm_30': Item(
      id: 'tm_30',
      name: 'TM30 Teleport',
      description: 'Teaches Teleport (+2 Speed warp technique) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'teleport',
    ),
    'tm_31': Item(
      id: 'tm_31',
      name: 'TM31 Mimic',
      description: 'Teaches Mimic (+1 Atk stance mimicry) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'mimic',
    ),
    'tm_32': Item(
      id: 'tm_32',
      name: 'TM32 Double Team',
      description: 'Teaches Double Team (+1 Speed illusion boost) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'double_team',
    ),
    'tm_33': Item(
      id: 'tm_33',
      name: 'TM33 Reflect',
      description: 'Teaches Reflect (+2 Defense psychic barrier) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'reflect',
    ),
    'tm_34': Item(
      id: 'tm_34',
      name: 'TM34 Bide',
      description: 'Teaches Bide (80 PWR stored-energy retaliation) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'bide',
    ),
    'tm_35': Item(
      id: 'tm_35',
      name: 'TM35 Metronome',
      description: 'Teaches Metronome (80 PWR unpredictable burst) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFE0E0E0),
      icon: Icons.album_rounded,
      moveId: 'metronome',
    ),
    'tm_36': Item(
      id: 'tm_36',
      name: 'TM36 Self-Destruct',
      description: 'Teaches Self-Destruct (140 PWR shockwave blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF7043),
      icon: Icons.album_rounded,
      moveId: 'self_destruct',
    ),
    'tm_37': Item(
      id: 'tm_37',
      name: 'TM37 Egg Bomb',
      description: 'Teaches Egg Bomb (100 PWR hurled egg blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'egg_bomb',
    ),
    'tm_38': Item(
      id: 'tm_38',
      name: 'TM38 Fire Blast',
      description: 'Teaches Fire Blast (110 PWR + Burn star flame) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF7043),
      icon: Icons.album_rounded,
      moveId: 'fire_blast',
    ),
    'tm_39': Item(
      id: 'tm_39',
      name: 'TM39 Swift',
      description: 'Teaches Swift (60 PWR never-miss star rays) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFFFCA28),
      icon: Icons.album_rounded,
      moveId: 'swift',
    ),
    'tm_40': Item(
      id: 'tm_40',
      name: 'TM40 Skull Bash',
      description: 'Teaches Skull Bash (115 PWR armored headbutt) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'skull_bash',
    ),
    'tm_41': Item(
      id: 'tm_41',
      name: 'TM41 Soft-Boiled',
      description: 'Teaches Soft-Boiled (rejuvenating recovery glow) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFF48FB1),
      icon: Icons.album_rounded,
      moveId: 'soft_boiled',
    ),
    'tm_42': Item(
      id: 'tm_42',
      name: 'TM42 Dream Eater',
      description: 'Teaches Dream Eater (100 PWR Psychic strike) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'dream_eater',
    ),
    'tm_43': Item(
      id: 'tm_43',
      name: 'TM43 Sky Attack',
      description: 'Teaches Sky Attack (130 PWR radiant aerial dive) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFF90CAF9),
      icon: Icons.album_rounded,
      moveId: 'sky_attack',
    ),
    'tm_44': Item(
      id: 'tm_44',
      name: 'TM44 Rest',
      description: 'Teaches Rest (defensive recovery technique) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'rest',
    ),
    'tm_45': Item(
      id: 'tm_45',
      name: 'TM45 Thunder Wave',
      description: 'Teaches Thunder Wave (paralyzes the target) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFEE58),
      icon: Icons.album_rounded,
      moveId: 'thunder_wave',
    ),
    'tm_46': Item(
      id: 'tm_46',
      name: 'TM46 Psywave',
      description: 'Teaches Psywave (75 PWR Psychic pulse) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.uncommon,
      color: Color(0xFFEC407A),
      icon: Icons.album_rounded,
      moveId: 'psywave',
    ),
    'tm_47': Item(
      id: 'tm_47',
      name: 'TM47 Explosion',
      description: 'Teaches Explosion (200 PWR cataclysmic blast) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFF7043),
      icon: Icons.album_rounded,
      moveId: 'explosion',
    ),
    'tm_48': Item(
      id: 'tm_48',
      name: 'TM48 Rock Slide',
      description: 'Teaches Rock Slide (75 PWR boulder avalanche) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFA1887F),
      icon: Icons.album_rounded,
      moveId: 'rock_slide',
    ),
    'tm_49': Item(
      id: 'tm_49',
      name: 'TM49 Tri Attack',
      description: 'Teaches Tri Attack (80 PWR elemental beam) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFFFCA28),
      icon: Icons.album_rounded,
      moveId: 'tri_attack',
    ),
    'tm_50': Item(
      id: 'tm_50',
      name: 'TM50 Substitute',
      description: 'Teaches Substitute (+1 Defense decoy guard) to compatible Pokémon.',
      category: ItemCategory.tm,
      rarity: PokemonRarity.rare,
      color: Color(0xFFBDBDBD),
      icon: Icons.album_rounded,
      moveId: 'substitute',
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

  /// Buyable Poké Mart items locked behind higher gym badge tiers.
  static List<Item> getLockedMartItems(int badgeCount) {
    return allItems.values
        .where((item) => item.isBuyable && badgeCount < item.requiredBadges)
        .toList()
      ..sort((a, b) {
        final cmp = a.requiredBadges.compareTo(b.requiredBadges);
        return cmp != 0 ? cmp : (a.price ?? 0).compareTo(b.price ?? 0);
      });
  }

  static bool isSingleMovePpItem(String itemId) =>
      itemId == 'ether' || itemId == 'max_ether' || itemId == 'leppa_berry';

  static bool isAllMovesPpItem(String itemId) =>
      itemId == 'elixir' || itemId == 'max_elixir';

  static bool isPpRestoreItem(String itemId) =>
      isSingleMovePpItem(itemId) || isAllMovesPpItem(itemId);

  /// Shared usability check for medicine & PP-restoring items across Bag, League, and Battle.
  static bool canUseMedicineOn(String itemId, PokemonInstance mon) {
    if (isPpRestoreItem(itemId)) {
      return mon.moves.any((m) => m.currentPp < m.maxPp);
    }
    switch (itemId) {
      case 'revive':
        return mon.isFainted;
      case 'potion':
      case 'super_potion':
      case 'hyper_potion':
      case 'max_potion':
        return !mon.isFainted && mon.currentHp < mon.maxHp;
      case 'antidote':
        return !mon.isFainted && mon.status == StatusCondition.poison;
      case 'paralyze_heal':
        return !mon.isFainted && mon.status == StatusCondition.paralysis;
      case 'awakening':
        return !mon.isFainted && mon.status == StatusCondition.sleep;
      case 'burn_heal':
        return !mon.isFainted && mon.status == StatusCondition.burn;
      case 'ice_heal':
        return !mon.isFainted && mon.status == StatusCondition.freeze;
      case 'full_heal':
        return !mon.isFainted &&
            (mon.status != StatusCondition.none || mon.isConfused);
      case 'full_restore':
        return !mon.isFainted &&
            (mon.currentHp < mon.maxHp ||
                mon.status != StatusCondition.none ||
                mon.isConfused);
      default:
        return false;
    }
  }

  /// Applies a medicine or PP-restoring item to [targetMon] and returns a user-facing summary message.
  static String applyMedicineToPokemon({
    required String itemId,
    required PokemonInstance targetMon,
    int? moveIndex,
    String? actorName,
    bool inBattle = false,
  }) {
    final String itemName = byId(itemId)?.name ?? itemId;
    final String prefix = actorName != null ? "$actorName used $itemName! " : "";

    if (isSingleMovePpItem(itemId)) {
      if (targetMon.moves.isEmpty) {
        return "${targetMon.nickname} has no moves!";
      }
      int resolvedIndex =
          (moveIndex != null && moveIndex >= 0 && moveIndex < targetMon.moves.length)
              ? moveIndex
              : targetMon.moves.indexWhere((m) => m.currentPp < m.maxPp);
      if (resolvedIndex < 0) resolvedIndex = 0;
      final move = targetMon.moves[resolvedIndex];
      final int missing = max(0, move.maxPp - move.currentPp);
      final int gained = itemId == 'max_ether' ? missing : min(10, missing);
      move.currentPp = (move.currentPp + gained).clamp(0, move.maxPp);
      return itemId == 'max_ether'
          ? "$prefix${targetMon.nickname}'s ${move.name} PP was fully restored!"
          : "$prefix${targetMon.nickname}'s ${move.name} restored $gained PP!";
    }

    if (isAllMovesPpItem(itemId)) {
      final bool isFull = itemId == 'max_elixir';
      for (final move in targetMon.moves) {
        move.currentPp = isFull ? move.maxPp : min(move.maxPp, move.currentPp + 10);
      }
      return isFull
          ? "$prefix${targetMon.nickname}'s moves had all PP fully restored!"
          : "$prefix${targetMon.nickname} restored 10 PP for all moves!";
    }

    switch (itemId) {
      case 'revive':
        targetMon.currentHp = max(1, (targetMon.maxHp / 2).ceil());
        targetMon.status = StatusCondition.none;
        targetMon.isBadlyPoisoned = false;
        targetMon.toxicCounter = 1;
        return "$prefix${targetMon.nickname} was revived to half HP!";
      case 'potion':
        final heal = min(20, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$prefix${targetMon.nickname} restored $heal HP.";
      case 'super_potion':
        final heal = min(50, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$prefix${targetMon.nickname} restored $heal HP.";
      case 'hyper_potion':
        final heal = min(200, targetMon.maxHp - targetMon.currentHp);
        targetMon.currentHp = (targetMon.currentHp + heal).clamp(0, targetMon.maxHp);
        return "$prefix${targetMon.nickname} restored $heal HP.";
      case 'max_potion':
        targetMon.currentHp = targetMon.maxHp;
        return "$prefix${targetMon.nickname}'s HP was fully restored!";
      case 'full_restore':
        targetMon.currentHp = targetMon.maxHp;
        targetMon.status = StatusCondition.none;
        targetMon.isBadlyPoisoned = false;
        targetMon.toxicCounter = 1;
        if (inBattle) {
          targetMon.isConfused = false;
          targetMon.confusionTurnsRemaining = 0;
        }
        return "$prefix${targetMon.nickname} fully restored HP and cured status!";
      default:
        targetMon.status = StatusCondition.none;
        if (itemId == 'full_heal' || itemId == 'antidote') {
          targetMon.isBadlyPoisoned = false;
          targetMon.toxicCounter = 1;
        }
        if (itemId == 'full_heal' && inBattle) {
          targetMon.isConfused = false;
          targetMon.confusionTurnsRemaining = 0;
        }
        return "$prefix${targetMon.nickname}'s status condition was cured!";
    }
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
