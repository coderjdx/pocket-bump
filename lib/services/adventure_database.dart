import 'package:flutter/material.dart';
import '../models/game_region.dart';
import '../models/pokemon_type.dart';

class AdventureBiome {
  final String id;
  final String name;
  final String mapItemId;
  final String subtitle;
  final List<PokemonType> types;
  final String backgroundAsset;
  final Color accentColor;
  final IconData icon;
  final String sourceGymName;
  final String johtoSourceGymName;

  const AdventureBiome({
    required this.id,
    required this.name,
    required this.mapItemId,
    required this.subtitle,
    required this.types,
    required this.backgroundAsset,
    required this.accentColor,
    required this.icon,
    required this.sourceGymName,
    required this.johtoSourceGymName,
  });

  Set<PokemonType> get typeSet => types.toSet();

  String sourceGymNameForRegion(GameRegion region) {
    return region == GameRegion.johto ? johtoSourceGymName : sourceGymName;
  }
}

class AdventureDatabase {
  static const List<AdventureBiome> biomes = [
    AdventureBiome(
      id: 'underground_cave',
      name: 'Underground Cave',
      mapItemId: 'map_underground_cave',
      subtitle: 'Echoing mineral caverns rich with Rock, Ground & Steel Pokémon.',
      types: [PokemonType.rock, PokemonType.ground, PokemonType.steel],
      backgroundAsset: 'assets/images/battle_bg_cave.png',
      accentColor: Color(0xFFBCAAA4),
      icon: Icons.terrain_rounded,
      sourceGymName: 'Pewter Gym (Brock)',
      johtoSourceGymName: 'Olivine Gym (Jasmine)',
    ),
    AdventureBiome(
      id: 'deep_sea',
      name: 'Deep Sea',
      mapItemId: 'map_deep_sea',
      subtitle: 'Azure ocean trenches teeming with Water & Ice Pokémon.',
      types: [PokemonType.water, PokemonType.ice],
      backgroundAsset: 'assets/images/battle_bg_beach.png',
      accentColor: Color(0xFF29B6F6),
      icon: Icons.water_rounded,
      sourceGymName: 'Cerulean Gym (Misty)',
      johtoSourceGymName: 'Mahogany Gym (Pryce)',
    ),
    AdventureBiome(
      id: 'thunder_plains',
      name: 'Thunder Plains',
      mapItemId: 'map_thunder_plains',
      subtitle: 'Wind-swept plateaus home to Electric, Normal & Flying Pokémon.',
      types: [PokemonType.electric, PokemonType.normal, PokemonType.flying],
      backgroundAsset: 'assets/images/battle_bg_urban.png',
      accentColor: Color(0xFFFFD54F),
      icon: Icons.bolt_rounded,
      sourceGymName: 'Vermilion Gym (Lt. Surge)',
      johtoSourceGymName: 'Violet Gym (Falkner)',
    ),
    AdventureBiome(
      id: 'emerald_forest',
      name: 'Emerald Forest',
      mapItemId: 'map_emerald_forest',
      subtitle: 'Sunlit woodland canopies brimming with Grass & Bug Pokémon.',
      types: [PokemonType.grass, PokemonType.bug],
      backgroundAsset: 'assets/images/battle_bg_forest.png',
      accentColor: Color(0xFF66BB6A),
      icon: Icons.forest_rounded,
      sourceGymName: 'Celadon Gym (Erika)',
      johtoSourceGymName: 'Azalea Gym (Bugsy)',
    ),
    AdventureBiome(
      id: 'toxic_marsh',
      name: 'Toxic Marsh',
      mapItemId: 'map_toxic_marsh',
      subtitle: 'Misty boglands haunted by Poison, Ghost & Dark Pokémon.',
      types: [PokemonType.poison, PokemonType.ghost, PokemonType.dark],
      backgroundAsset: 'assets/images/battle_bg_cave.png',
      accentColor: Color(0xFFAB47BC),
      icon: Icons.bubble_chart_rounded,
      sourceGymName: 'Fuchsia Gym (Koga)',
      johtoSourceGymName: 'Ecruteak Gym (Morty)',
    ),
    AdventureBiome(
      id: 'mystic_sanctum',
      name: 'Mystic Sanctum',
      mapItemId: 'map_mystic_sanctum',
      subtitle: 'Astral ruins resonating with Psychic & Fairy Pokémon.',
      types: [PokemonType.psychic, PokemonType.fairy],
      backgroundAsset: 'assets/images/battle_bg_route.png',
      accentColor: Color(0xFFEC407A),
      icon: Icons.auto_awesome_rounded,
      sourceGymName: 'Saffron Gym (Sabrina)',
      johtoSourceGymName: 'Goldenrod Gym (Whitney)',
    ),
    AdventureBiome(
      id: 'volcanic_ridge',
      name: 'Volcanic Ridge',
      mapItemId: 'map_volcanic_ridge',
      subtitle: 'Molten calderas inhabited by fierce Fire & Dragon Pokémon.',
      types: [PokemonType.fire, PokemonType.dragon],
      backgroundAsset: 'assets/images/battle_bg_volcano.png',
      accentColor: Color(0xFFFF7043),
      icon: Icons.local_fire_department_rounded,
      sourceGymName: 'Cinnabar Gym (Blaine)',
      johtoSourceGymName: 'Blackthorn Gym (Clair)',
    ),
    AdventureBiome(
      id: 'victory_highlands',
      name: 'Victory Highlands',
      mapItemId: 'map_victory_highlands',
      subtitle: 'Rugged training peaks ruled by Fighting, Ground & Rock Pokémon.',
      types: [PokemonType.fighting, PokemonType.ground, PokemonType.rock],
      backgroundAsset: 'assets/images/battle_bg_victory_road.png',
      accentColor: Color(0xFF8D6E63),
      icon: Icons.landscape_rounded,
      sourceGymName: 'Viridian Gym (Giovanni)',
      johtoSourceGymName: 'Cianwood Gym (Chuck)',
    ),
  ];

  static AdventureBiome? byMapItemId(String mapItemId) {
    for (final biome in biomes) {
      if (biome.mapItemId == mapItemId) return biome;
    }
    return null;
  }
}
