import 'dart:math';

enum PokemonNature {
  hardy,
  lonely,
  brave,
  adamant,
  naughty,
  bold,
  docile,
  relaxed,
  impish,
  lax,
  timid,
  hasty,
  serious,
  jolly,
  naive,
  modest,
  mild,
  quiet,
  bashful,
  rash,
  calm,
  gentle,
  sassy,
  careful,
  quirky,
}

extension PokemonNatureExtension on PokemonNature {
  String get displayName => name[0].toUpperCase() + name.substring(1);

  String? get increasedStat {
    switch (this) {
      case PokemonNature.lonely:
      case PokemonNature.brave:
      case PokemonNature.adamant:
      case PokemonNature.naughty:
        return 'atk';
      case PokemonNature.bold:
      case PokemonNature.relaxed:
      case PokemonNature.impish:
      case PokemonNature.lax:
        return 'def';
      case PokemonNature.modest:
      case PokemonNature.mild:
      case PokemonNature.quiet:
      case PokemonNature.rash:
        return 'spa';
      case PokemonNature.calm:
      case PokemonNature.gentle:
      case PokemonNature.sassy:
      case PokemonNature.careful:
        return 'spd';
      case PokemonNature.timid:
      case PokemonNature.hasty:
      case PokemonNature.jolly:
      case PokemonNature.naive:
        return 'spe';
      case PokemonNature.hardy:
      case PokemonNature.docile:
      case PokemonNature.serious:
      case PokemonNature.bashful:
      case PokemonNature.quirky:
        return null;
    }
  }

  String? get decreasedStat {
    switch (this) {
      case PokemonNature.bold:
      case PokemonNature.modest:
      case PokemonNature.calm:
      case PokemonNature.timid:
        return 'atk';
      case PokemonNature.lonely:
      case PokemonNature.mild:
      case PokemonNature.gentle:
      case PokemonNature.hasty:
        return 'def';
      case PokemonNature.adamant:
      case PokemonNature.impish:
      case PokemonNature.careful:
      case PokemonNature.jolly:
        return 'spa';
      case PokemonNature.naughty:
      case PokemonNature.lax:
      case PokemonNature.rash:
      case PokemonNature.naive:
        return 'spd';
      case PokemonNature.brave:
      case PokemonNature.relaxed:
      case PokemonNature.quiet:
      case PokemonNature.sassy:
        return 'spe';
      case PokemonNature.hardy:
      case PokemonNature.docile:
      case PokemonNature.serious:
      case PokemonNature.bashful:
      case PokemonNature.quirky:
        return null;
    }
  }

  double multiplierFor(String stat) {
    if (increasedStat == null || decreasedStat == null) return 1.0;
    if (stat == increasedStat) return 1.1;
    if (stat == decreasedStat) return 0.9;
    return 1.0;
  }

  static String _statShortLabel(String stat) {
    switch (stat) {
      case 'atk':
        return 'Atk';
      case 'def':
        return 'Def';
      case 'spa':
        return 'SpA';
      case 'spd':
        return 'SpD';
      case 'spe':
        return 'Spe';
      default:
        return stat;
    }
  }

  String get shortEffectLabel {
    final up = increasedStat;
    final down = decreasedStat;
    if (up == null || down == null) return 'Neutral';
    return '+${_statShortLabel(up)} / -${_statShortLabel(down)}';
  }

  static PokemonNature random([Random? rng]) {
    final r = rng ?? Random();
    return PokemonNature.values[r.nextInt(PokemonNature.values.length)];
  }

  static PokemonNature fromStorageKey(String? raw) {
    if (raw == null || raw.isEmpty) return PokemonNature.hardy;
    for (final n in PokemonNature.values) {
      if (n.name == raw) return n;
    }
    return PokemonNature.hardy;
  }
}
