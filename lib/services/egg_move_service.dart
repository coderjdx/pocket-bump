import 'dart:math';
import '../models/move.dart';
import '../models/pokemon_species.dart';
import 'pokedex_database.dart';

/// Curated breeding-era Egg Moves per evolutionary family across all 91 lines
/// (Gen 1 Kanto families + Gen 2–5 starter families).
///
/// Wild Pokémon have a chance to spawn knowing one of these moves, and the
/// Move Tutor in the Pokémon Center can teach them in exchange for 1 Heart Scale.
class EggMoveService {
  static final Random _rng = Random();

  static const Map<int, int> _speciesToFamilyRoot = {
    // Bulbasaur
    2: 1, 3: 1,
    // Charmander
    5: 4, 6: 4,
    // Squirtle
    8: 7, 9: 7,
    // Pidgey
    17: 16, 18: 16,
    // Rattata
    20: 19,
    // Spearow
    22: 21,
    // Ekans
    24: 23,
    // Pikachu
    26: 25,
    // Sandshrew
    28: 27,
    // Nidoran F
    30: 29, 31: 29,
    // Nidoran M
    33: 32, 34: 32,
    // Clefairy
    36: 35,
    // Vulpix
    38: 37,
    // Jigglypuff
    40: 39,
    // Zubat
    42: 41,
    // Oddish
    44: 43, 45: 43,
    // Paras
    47: 46,
    // Venonat
    49: 48,
    // Diglett
    51: 50,
    // Meowth
    53: 52,
    // Psyduck
    55: 54,
    // Mankey
    57: 56,
    // Growlithe
    59: 58,
    // Poliwag
    61: 60, 62: 60,
    // Abra
    64: 63, 65: 63,
    // Machop
    67: 66, 68: 66,
    // Bellsprout
    70: 69, 71: 69,
    // Tentacool
    73: 72,
    // Geodude
    75: 74, 76: 74,
    // Ponyta
    78: 77,
    // Slowpoke
    80: 79,
    // Doduo
    85: 84,
    // Seel
    87: 86,
    // Grimer
    89: 88,
    // Shellder
    91: 90,
    // Gastly
    93: 92, 94: 92,
    // Drowzee
    97: 96,
    // Krabby
    99: 98,
    // Exeggcute
    103: 102,
    // Cubone
    105: 104,
    // Koffing
    110: 109,
    // Rhyhorn
    112: 111,
    // Horsea
    117: 116,
    // Goldeen
    119: 118,
    // Staryu
    121: 120,
    // Magikarp (covered with Gyarados if needed; non-egg in main games)
    130: 129,
    // Eevee
    134: 133, 135: 133, 136: 133,
    // Omanyte
    139: 138,
    // Kabuto
    141: 140,
    // Dratini
    148: 147, 149: 147,
    // Gen 2 Starters
    153: 152, 154: 152,
    156: 155, 157: 155,
    159: 158, 160: 158,
    // Gen 3 Starters
    253: 252, 254: 252,
    256: 255, 257: 255,
    259: 258, 260: 258,
    // Gen 4 Starters
    388: 387, 389: 387,
    391: 390, 392: 390,
    394: 393, 395: 393,
    // Gen 5 Starters
    496: 495, 497: 495,
    499: 498, 500: 498,
    502: 501, 503: 501,
  };

  /// All curated Egg Moves per evolutionary family root ID.
  /// Genderless / non-breedable lines (Magnemite, Voltorb, Porygon, Ditto,
  /// Legendaries, Mythicals) intentionally have no Egg Moves.
  static const Map<int, List<String>> familyEggMoveIds = {
    1: ['leaf_storm', 'power_whip', 'giga_drain', 'amnesia', 'curse', 'ingrain'], // Bulbasaur line
    4: ['dragon_dance', 'belly_drum', 'flare_blitz', 'outrage', 'crunch', 'ancient_power'], // Charmander line
    7: ['aqua_jet', 'aura_sphere', 'mirror_coat', 'dragon_pulse', 'muddy_water', 'yawn'], // Squirtle line
    16: ['brave_bird', 'air_slash', 'pursuit', 'uproar', 'feint_attack', 'roost'], // Pidgey line
    19: ['flame_wheel', 'reversal', 'counter', 'screech', 'bite', 'revenge'], // Rattata line
    21: ['sky_attack', 'feather_dance', 'quick_attack', 'astonish', 'whirlwind', 'aerial_ace'], // Spearow line
    23: ['sucker_punch', 'iron_tail', 'poison_fang', 'disable', 'pursuit', 'slam'], // Ekans line
    25: ['thunder_punch', 'encore', 'fake_out', 'disarming_voice', 'tickle', 'reversal'], // Pikachu line
    27: ['night_slash', 'metal_claw', 'rapid_spin', 'counter', 'crush_claw', 'rock_slide'], // Sandshrew line
    29: ['pursuit', 'skull_bash', 'disable', 'counter', 'iron_tail', 'charm'], // Nidoran F line
    32: ['head_smash', 'sucker_punch', 'confusion', 'counter', 'iron_tail', 'disable'], // Nidoran M line
    35: ['aromatherapy', 'belly_drum', 'amnesia', 'stored_power', 'fake_tears', 'tickle'], // Clefairy line
    37: ['extrasensory', 'heat_wave', 'hypnosis', 'flare_blitz', 'disable', 'hex'], // Vulpix line
    39: ['perish_song', 'feint_attack', 'fake_tears', 'gravity', 'last_resort', 'punishment'], // Jigglypuff line
    41: ['brave_bird', 'zen_headbutt', 'hypnosis', 'nasty_plot', 'quick_attack', 'curse'], // Zubat line
    43: ['synthesis', 'ingrain', 'charm', 'petal_blizzard', 'tickle', 'razor_leaf'], // Oddish line
    46: ['leech_seed', 'bug_bite', 'cross_poison', 'pursuit', 'counter', 'metal_claw'], // Paras line
    48: ['baton_pass', 'bug_bite', 'signal_beam', 'toxic_spikes', 'agility', 'giga_drain'], // Venonat line
    50: ['memento', 'reversal', 'pursuit', 'headbutt', 'ancient_power', 'feint_attack'], // Diglett line
    52: ['hypnosis', 'iron_tail', 'amnesia', 'last_resort', 'charm', 'punishment'], // Meowth line
    54: ['yawn', 'hypnosis', 'encore', 'future_sight', 'cross_chop', 'psybeam'], // Psyduck line
    56: ['close_combat', 'night_slash', 'encore', 'counter', 'reversal', 'meditate'], // Mankey line
    58: ['close_combat', 'flare_blitz', 'flame_wheel', 'crunch', 'body_slam', 'double_kick'], // Growlithe line
    60: ['encore', 'icy_wind', 'refresh', 'haze', 'water_pulse', 'mist'], // Poliwag line
    63: ['fire_punch', 'ice_punch', 'thunder_punch', 'encore', 'barrier', 'magic_coat'], // Abra line
    66: ['bullet_punch', 'close_combat', 'fire_punch', 'ice_punch', 'thunder_punch', 'heavy_slam'], // Machop line
    69: ['power_whip', 'giga_drain', 'petal_blizzard', 'clear_smog', 'synthesis', 'ingrain'], // Bellsprout line
    72: ['rapid_spin', 'mirror_coat', 'haze', 'aqua_ring', 'knock_off', 'muddy_water'], // Tentacool line
    74: ['hammer_arm', 'curse', 'mega_punch', 'flail', 'wide_guard', 'rock_polish'], // Geodude line
    77: ['heat_wave', 'hypnosis', 'double_kick', 'flame_wheel', 'horn_drill', 'charm'], // Ponyta line
    79: ['belly_drum', 'future_sight', 'zen_headbutt', 'sleep_talk', 'stomp', 'mud_sport'], // Slowpoke line
    83: ['leaf_blade', 'night_slash', 'quick_attack', 'feather_dance', 'mirror_move', 'pluck'], // Farfetch'd
    84: ['brave_bird', 'quick_attack', 'flail', 'haze', 'feint_attack', 'mirror_move'], // Doduo line
    86: ['icicle_spear', 'fake_out', 'perish_song', 'encore', 'iron_tail', 'signal_beam'], // Seel line
    88: ['shadow_punch', 'curse', 'mean_look', 'haze', 'lick', 'clear_smog'], // Grimer line
    90: ['icicle_spear', 'rock_blast', 'rapid_spin', 'aqua_ring', 'bubble_beam', 'barrier'], // Shellder line
    92: ['perish_song', 'disable', 'clear_smog', 'grudge', 'psywave', 'astonish'], // Gastly line
    95: ['heavy_slam', 'rock_blast', 'stealth_rock', 'flail', 'rollout', 'defense_curl'], // Onix
    96: ['fire_punch', 'ice_punch', 'thunder_punch', 'nasty_plot', 'psycho_cut', 'barrier'], // Drowzee line
    98: ['knock_off', 'agility', 'ancient_power', 'haze', 'amnesia', 'tickle'], // Krabby line
    102: ['leaf_storm', 'giga_drain', 'moonlight', 'ancient_power', 'synthesis', 'ingrain'], // Exeggcute line
    104: ['belly_drum', 'iron_head', 'perish_song', 'ancient_power', 'skull_bash', 'double_kick'], // Cubone line
    106: ['mach_punch', 'bullet_punch', 'rapid_spin', 'high_jump_kick', 'feint', 'counter'], // Hitmonlee
    107: ['mach_punch', 'bullet_punch', 'rapid_spin', 'high_jump_kick', 'feint', 'counter'], // Hitmonchan
    108: ['belly_drum', 'zen_headbutt', 'hammer_arm', 'curse', 'amnesia', 'body_slam'], // Lickitung
    109: ['spite', 'curse', 'destiny_bond', 'psybeam', 'toxic_spikes', 'stockpile'], // Koffing line
    111: ['ice_fang', 'fire_fang', 'thunder_fang', 'dragon_rush', 'crush_claw', 'counter'], // Rhyhorn line
    113: ['aromatherapy', 'seismic_toss', 'counter', 'metronome', 'mud_bomb', 'gravity'], // Chansey
    114: ['leaf_storm', 'leech_seed', 'amnesia', 'giga_drain', 'confusion', 'flail'], // Tangela
    115: ['double_edge', 'hammer_arm', 'crush_claw', 'disable', 'counter', 'stomp'], // Kangaskhan
    116: ['outrage', 'signal_beam', 'dragon_breath', 'clear_smog', 'disable', 'aurora_beam'], // Horsea line
    118: ['aqua_tail', 'hydro_pump', 'signal_beam', 'body_slam', 'haze', 'psybeam'], // Goldeen line
    122: ['icy_wind', 'future_sight', 'nasty_plot', 'fake_out', 'hypnosis', 'trick'], // Mr. Mime
    123: ['night_slash', 'bug_buzz', 'silver_wind', 'counter', 'reversal', 'baton_pass'], // Scyther
    124: ['nasty_plot', 'fake_out', 'ice_punch', 'meditate', 'miracle_eye', 'wake_up_slap'], // Jynx
    125: ['cross_chop', 'ice_punch', 'fire_punch', 'dynamic_punch', 'barrier', 'meditate'], // Electabuzz
    126: ['flare_blitz', 'cross_chop', 'thunder_punch', 'mach_punch', 'belly_drum', 'barrier'], // Magmar
    127: ['close_combat', 'quick_attack', 'feint_attack', 'bug_bite', 'superpower', 'flail'], // Pinsir
    128: [], // Tauros (100% male in mainline, no egg moves)
    131: ['icy_wind', 'ancient_power', 'dragon_dance', 'dragon_pulse', 'avalanche', 'curse'], // Lapras
    133: ['yawn', 'curse', 'stored_power', 'tickle', 'charm', 'flail'], // Eevee line
    138: ['spikes', 'toxic_spikes', 'aurora_beam', 'haze', 'slam', 'water_pulse'], // Omanyte line
    140: ['rapid_spin', 'knock_off', 'aurora_beam', 'confuse_ray', 'icy_wind', 'screech'], // Kabuto line
    142: ['roost', 'tailwind', 'pursuit', 'wide_guard', 'whirlwind', 'assurance'], // Aerodactyl
    143: ['curse', 'pursuit', 'double_edge', 'counter', 'whirlwind', 'zen_headbutt'], // Snorlax
    147: ['dragon_dance', 'extreme_speed', 'aqua_jet', 'iron_tail', 'dragon_pulse', 'haze'], // Dratini line
    // Gen 2 Starters
    152: ['leech_seed', 'leaf_storm', 'ancient_power', 'aromatherapy', 'ingrain', 'counter'], // Chikorita line
    155: ['flare_blitz', 'extrasensory', 'reversal', 'double_kick', 'flame_burst', 'crush_claw'], // Cyndaquil line
    158: ['dragon_dance', 'aqua_jet', 'ice_punch', 'crunch', 'metal_claw', 'ancient_power'], // Totodile line
    // Gen 3 Starters
    252: ['leaf_storm', 'leech_seed', 'dragon_breath', 'crunch', 'synthesis', 'crush_claw'], // Treecko line
    255: ['baton_pass', 'night_slash', 'reversal', 'counter', 'agility', 'crush_claw'], // Torchic line
    258: ['avalanche', 'curse', 'mirror_coat', 'yawn', 'sludge', 'wide_guard'], // Mudkip line
    // Gen 4 Starters
    387: ['seed_bomb', 'superpower', 'heavy_slam', 'body_slam', 'stockpile', 'amnesia'], // Turtwig line
    390: ['thunder_punch', 'fire_punch', 'fake_out', 'blaze_kick', 'encore', 'counter'], // Chimchar line
    393: ['aqua_ring', 'agility', 'hydro_pump', 'icy_wind', 'feather_dance', 'yawn'], // Piplup line
    // Gen 5 Starters
    495: ['glare', 'mirror_coat', 'iron_tail', 'magical_leaf', 'pursuit', 'mean_look'], // Snivy line
    498: ['superpower', 'sucker_punch', 'heavy_slam', 'yawn', 'curse', 'body_slam'], // Tepig line
    501: ['night_slash', 'air_slash', 'detect', 'screech', 'assurance', 'trump_card'], // Oshawott line
  };

  static int familyRootId(int speciesId) =>
      _speciesToFamilyRoot[speciesId] ?? speciesId;

  static List<String> eggMoveIdsForSpecies(PokemonSpecies species) {
    final int rootId = familyRootId(species.id);
    final raw = familyEggMoveIds[rootId] ?? const [];
    return raw.where(PokedexDatabase.moves.containsKey).toList();
  }

  static bool isEggMoveForSpecies(PokemonSpecies species, String moveId) {
    return eggMoveIdsForSpecies(species).contains(moveId);
  }

  static List<Move> eggMovesForSpecies(PokemonSpecies species) {
    return [
      for (final id in eggMoveIdsForSpecies(species))
        if (PokedexDatabase.moves[id] != null) PokedexDatabase.moves[id]!.copy(),
    ];
  }

  static Move? rollWildEggMove(
    PokemonSpecies species, {
    double chance = 0.15,
    Set<String> excludeMoveIds = const {},
    Random? rng,
  }) {
    if (chance <= 0) return null;
    final List<String> candidates = eggMoveIdsForSpecies(species)
        .where((id) => !excludeMoveIds.contains(id))
        .toList();
    if (candidates.isEmpty) return null;
    final Random r = rng ?? _rng;
    if (r.nextDouble() >= chance) return null;
    final String chosenId = candidates[r.nextInt(candidates.length)];
    return PokedexDatabase.moves[chosenId]?.copy();
  }
}
