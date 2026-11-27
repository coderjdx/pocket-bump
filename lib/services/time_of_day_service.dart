enum DayPeriod {
  morning,
  day,
  night,
}

extension DayPeriodExtension on DayPeriod {
  String get displayName {
    switch (this) {
      case DayPeriod.morning:
        return 'Morning';
      case DayPeriod.day:
        return 'Day';
      case DayPeriod.night:
        return 'Night';
    }
  }
}

class TimeOfDayService {
  /// Returns the current global day period from the device's local clock.
  static DayPeriod currentPeriod([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 4 && hour < 10) return DayPeriod.morning;
    if (hour >= 10 && hour < 18) return DayPeriod.day;
    return DayPeriod.night;
  }

  /// Daytime window (6 AM - 6 PM) used by daytime evolutions like Espeon.
  static bool isDaytime([DateTime? now]) {
    final hour = (now ?? DateTime.now()).hour;
    return hour >= 6 && hour < 18;
  }

  /// Nighttime window (6 PM - 6 AM) used by nighttime evolutions like Umbreon.
  static bool isNighttime([DateTime? now]) => !isDaytime(now);

  static const Set<int> _nocturnalSpeciesIds = {
    // Kanto nocturnal / ghostly lines
    23, 24, // Ekans, Arbok
    35, 36, // Clefairy, Clefable
    41, 42, // Zubat, Golbat
    43, 44, 45, // Oddish line
    48, 49, // Venonat, Venomoth
    52, 53, // Meowth, Persian
    92, 93, 94, // Gastly line
    96, 97, // Drowzee, Hypno
    // Johto nocturnal lines
    163, 164, // Hoothoot, Noctowl
    167, 168, // Spinarak, Ariados
    169, // Crobat
    170, 171, // Chinchou, Lanturn
    173, // Cleffa
    197, // Umbreon
    198, // Murkrow
    200, // Misdreavus
    207, // Gligar
    215, // Sneasel
    228, 229, // Houndour, Houndoom
  };

  static const Set<int> _diurnalSpeciesIds = {
    // Kanto diurnal / sun-loving lines
    10, 11, 12, // Caterpie line
    13, 14, 15, // Weedle line
    16, 17, 18, // Pidgey line
    21, 22, // Spearow, Fearow
    58, 59, // Growlithe, Arcanine
    69, 70, 71, // Bellsprout line
    84, 85, // Doduo, Dodrio
    102, 103, // Exeggcute, Exeggutor
    // Johto diurnal lines
    161, 162, // Sentret, Furret
    165, 166, // Ledyba, Ledian
    182, // Bellossom
    187, 188, 189, // Hoppip line
    190, // Aipom
    191, 192, // Sunkern, Sunflora
    196, // Espeon
    203, // Girafarig
    204, 205, // Pineco, Forretress
    209, 210, // Snubbull, Granbull
    214, // Heracross
    227, // Skarmory
    231, 232, // Phanpy, Donphan
  };

  /// Wild species remain encounterable at any hour, with encounter weight
  /// boosted during their natural waking period.
  static double encounterWeightForSpecies(int speciesId, {DateTime? now}) {
    final period = currentPeriod(now);
    if (period == DayPeriod.night && _nocturnalSpeciesIds.contains(speciesId)) {
      return 1.8;
    }
    if (period != DayPeriod.night && _diurnalSpeciesIds.contains(speciesId)) {
      return 1.8;
    }
    return 1.0;
  }
}
