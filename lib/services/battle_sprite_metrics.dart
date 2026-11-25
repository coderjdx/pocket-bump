import 'dart:math';

class BattleSpriteMetric {
  final int frontW;
  final int frontH;
  final int frontVisH;
  final int frontPadB;
  final int backW;
  final int backH;
  final int backVisH;
  final int backPadB;

  const BattleSpriteMetric(
    this.frontW,
    this.frontH,
    this.frontVisH,
    this.frontPadB,
    this.backW,
    this.backH,
    this.backVisH,
    this.backPadB,
  );
}

class ResolvedBattleSpriteLayout {
  final double width;
  final double height;
  final double zoom;
  final double bodyCenterFromBottom;
  final double bodyTopFromBottom;
  final double visualHeight;

  const ResolvedBattleSpriteLayout({
    required this.width,
    required this.height,
    required this.zoom,
    required this.bodyCenterFromBottom,
    required this.bodyTopFromBottom,
    required this.visualHeight,
  });
}

/// Canonical Gen V Black/White animated GIF dimensions and vertical content bounds
/// measured per species so sprites render at uniform pixel density without distortion.
class BattleSpriteMetrics {
  static const BattleSpriteMetric fallback =
      BattleSpriteMetric(60, 60, 52, 2, 62, 60, 52, 2);

  static const Map<int, BattleSpriteMetric> bySpeciesId = {
    1: BattleSpriteMetric(37, 38, 33, 0, 34, 39, 30, 1), // Bulbasaur
    2: BattleSpriteMetric(58, 51, 51, 0, 59, 47, 45, 1), // Ivysaur
    3: BattleSpriteMetric(86, 71, 69, 2, 91, 66, 63, 1), // Venusaur
    4: BattleSpriteMetric(41, 42, 42, 0, 46, 46, 41, 1), // Charmander
    5: BattleSpriteMetric(66, 56, 56, 0, 69, 62, 58, 1), // Charmeleon
    6: BattleSpriteMetric(87, 89, 81, 0, 100, 85, 81, 1), // Charizard
    7: BattleSpriteMetric(39, 43, 39, 0, 41, 47, 39, 3), // Squirtle
    8: BattleSpriteMetric(60, 57, 57, 0, 58, 64, 61, 2), // Wartortle
    9: BattleSpriteMetric(70, 66, 62, 0, 68, 68, 61, 3), // Blastoise
    10: BattleSpriteMetric(36, 37, 35, 2, 40, 37, 34, 1), // Caterpie
    11: BattleSpriteMetric(37, 38, 37, 1, 45, 45, 43, 1), // Metapod
    12: BattleSpriteMetric(61, 58, 51, 6, 66, 59, 51, 6), // Butterfree
    13: BattleSpriteMetric(37, 44, 37, 2, 42, 46, 38, 0), // Weedle
    14: BattleSpriteMetric(31, 40, 39, 1, 32, 41, 39, 0), // Kakuna
    15: BattleSpriteMetric(72, 69, 59, 4, 76, 68, 59, 3), // Beedrill
    16: BattleSpriteMetric(42, 48, 41, 1, 47, 48, 40, 1), // Pidgey
    17: BattleSpriteMetric(82, 117, 80, 19, 97, 97, 77, 2), // Pidgeotto
    18: BattleSpriteMetric(58, 68, 68, 0, 70, 67, 66, 0), // Pidgeot
    19: BattleSpriteMetric(43, 43, 43, 0, 59, 42, 42, 0), // Rattata
    20: BattleSpriteMetric(57, 52, 51, 0, 66, 52, 52, 0), // Raticate
    21: BattleSpriteMetric(33, 40, 39, 0, 34, 40, 40, 0), // Spearow
    22: BattleSpriteMetric(82, 105, 74, 30, 78, 112, 77, 35), // Fearow
    23: BattleSpriteMetric(59, 45, 44, 1, 63, 54, 47, 3), // Ekans
    24: BattleSpriteMetric(78, 75, 65, 3, 87, 73, 66, 1), // Arbok
    25: BattleSpriteMetric(50, 46, 46, 0, 43, 49, 47, 1), // Pikachu
    26: BattleSpriteMetric(74, 73, 61, 1, 78, 75, 65, 1), // Raichu
    27: BattleSpriteMetric(36, 39, 39, 0, 43, 40, 38, 1), // Sandshrew
    28: BattleSpriteMetric(57, 54, 49, 0, 59, 54, 48, 2), // Sandslash
    29: BattleSpriteMetric(35, 34, 34, 0, 33, 36, 36, 0), // Nidoran♀
    30: BattleSpriteMetric(52, 47, 45, 2, 55, 48, 43, 3), // Nidorina
    31: BattleSpriteMetric(77, 70, 69, 0, 91, 72, 68, 3), // Nidoqueen
    32: BattleSpriteMetric(37, 37, 36, 1, 39, 45, 40, 1), // Nidoran♂
    33: BattleSpriteMetric(52, 56, 51, 0, 59, 59, 52, 1), // Nidorino
    34: BattleSpriteMetric(86, 71, 67, 1, 90, 71, 63, 3), // Nidoking
    35: BattleSpriteMetric(48, 42, 39, 0, 56, 46, 40, 1), // Clefairy
    36: BattleSpriteMetric(54, 52, 52, 0, 57, 53, 51, 1), // Clefable
    37: BattleSpriteMetric(60, 50, 46, 0, 64, 54, 48, 1), // Vulpix
    38: BattleSpriteMetric(74, 73, 69, 4, 79, 66, 64, 1), // Ninetales
    39: BattleSpriteMetric(47, 46, 34, 0, 48, 50, 36, 2), // Jigglypuff
    40: BattleSpriteMetric(48, 82, 57, 2, 49, 84, 54, 4), // Wigglytuff
    41: BattleSpriteMetric(53, 46, 37, 9, 49, 59, 47, 12), // Zubat
    42: BattleSpriteMetric(110, 82, 62, 13, 95, 84, 62, 16), // Golbat
    43: BattleSpriteMetric(37, 50, 35, 0, 41, 51, 36, 0), // Oddish
    44: BattleSpriteMetric(50, 45, 45, 0, 51, 49, 45, 1), // Gloom
    45: BattleSpriteMetric(56, 50, 49, 0, 57, 50, 48, 1), // Vileplume
    46: BattleSpriteMetric(45, 37, 37, 0, 47, 32, 32, 0), // Paras
    47: BattleSpriteMetric(62, 62, 57, 3, 70, 52, 52, 0), // Parasect
    48: BattleSpriteMetric(42, 53, 53, 0, 42, 53, 52, 0), // Venonat
    49: BattleSpriteMetric(101, 74, 61, 13, 104, 73, 63, 10), // Venomoth
    50: BattleSpriteMetric(38, 31, 27, 0, 40, 34, 24, 1), // Diglett
    51: BattleSpriteMetric(52, 42, 41, 0, 52, 43, 42, 0), // Dugtrio
    52: BattleSpriteMetric(48, 65, 49, 1, 60, 67, 47, 4), // Meowth
    53: BattleSpriteMetric(72, 62, 62, 0, 80, 58, 56, 1), // Persian
    54: BattleSpriteMetric(39, 46, 45, 0, 37, 45, 44, 0), // Psyduck
    55: BattleSpriteMetric(60, 59, 59, 0, 57, 59, 57, 1), // Golduck
    56: BattleSpriteMetric(65, 61, 49, 0, 63, 61, 48, 1), // Mankey
    57: BattleSpriteMetric(66, 61, 55, 1, 74, 60, 54, 2), // Primeape
    58: BattleSpriteMetric(56, 49, 42, 1, 58, 60, 46, 1), // Growlithe
    59: BattleSpriteMetric(75, 69, 69, 0, 84, 70, 68, 1), // Arcanine
    60: BattleSpriteMetric(53, 34, 34, 0, 54, 35, 34, 1), // Poliwag
    61: BattleSpriteMetric(74, 55, 46, 0, 80, 58, 47, 0), // Poliwhirl
    62: BattleSpriteMetric(81, 57, 57, 0, 74, 57, 56, 1), // Poliwrath
    63: BattleSpriteMetric(62, 53, 44, 1, 73, 58, 43, 5), // Abra
    64: BattleSpriteMetric(78, 61, 56, 0, 83, 67, 57, 3), // Kadabra
    65: BattleSpriteMetric(92, 69, 67, 0, 85, 68, 66, 1), // Alakazam
    66: BattleSpriteMetric(50, 50, 50, 0, 59, 54, 51, 1), // Machop
    67: BattleSpriteMetric(61, 71, 69, 0, 63, 73, 68, 1), // Machoke
    68: BattleSpriteMetric(63, 77, 68, 0, 69, 79, 69, 1), // Machamp
    69: BattleSpriteMetric(41, 44, 44, 0, 44, 52, 46, 0), // Bellsprout
    70: BattleSpriteMetric(68, 50, 48, 2, 72, 54, 48, 4), // Weepinbell
    71: BattleSpriteMetric(65, 71, 71, 0, 69, 70, 68, 2), // Victreebel
    72: BattleSpriteMetric(57, 69, 53, 4, 62, 77, 53, 10), // Tentacool
    73: BattleSpriteMetric(83, 85, 63, 0, 84, 85, 62, 3), // Tentacruel
    74: BattleSpriteMetric(61, 45, 24, 1, 57, 52, 28, 1), // Geodude
    75: BattleSpriteMetric(71, 44, 44, 0, 65, 43, 42, 1), // Graveler
    76: BattleSpriteMetric(72, 57, 57, 0, 68, 56, 55, 1), // Golem
    77: BattleSpriteMetric(58, 57, 57, 0, 58, 59, 59, 0), // Ponyta
    78: BattleSpriteMetric(74, 73, 73, 0, 76, 76, 73, 0), // Rapidash
    79: BattleSpriteMetric(65, 54, 44, 0, 67, 51, 44, 0), // Slowpoke
    80: BattleSpriteMetric(62, 60, 60, 0, 76, 58, 57, 0), // Slowbro
    81: BattleSpriteMetric(37, 33, 24, 2, 36, 31, 23, 2), // Magnemite
    82: BattleSpriteMetric(68, 60, 53, 0, 73, 59, 52, 0), // Magneton
    83: BattleSpriteMetric(45, 49, 48, 0, 46, 50, 50, 0), // Farfetch
    84: BattleSpriteMetric(60, 54, 53, 0, 63, 59, 55, 1), // Doduo
    85: BattleSpriteMetric(69, 77, 77, 0, 75, 78, 75, 2), // Dodrio
    86: BattleSpriteMetric(62, 47, 45, 1, 61, 43, 43, 0), // Seel
    87: BattleSpriteMetric(75, 74, 67, 3, 76, 87, 65, 8), // Dewgong
    88: BattleSpriteMetric(66, 42, 37, 0, 71, 46, 40, 0), // Grimer
    89: BattleSpriteMetric(94, 68, 58, 0, 99, 76, 62, 0), // Muk
    90: BattleSpriteMetric(42, 38, 31, 1, 47, 38, 27, 1), // Shellder
    91: BattleSpriteMetric(73, 65, 61, 1, 69, 68, 56, 0), // Cloyster
    92: BattleSpriteMetric(67, 75, 55, 20, 64, 78, 56, 20), // Gastly
    93: BattleSpriteMetric(85, 69, 48, 19, 91, 71, 46, 24), // Haunter
    94: BattleSpriteMetric(74, 63, 56, 0, 72, 65, 54, 1), // Gengar
    95: BattleSpriteMetric(74, 74, 73, 1, 100, 73, 71, 1), // Onix
    96: BattleSpriteMetric(52, 58, 52, 0, 57, 57, 52, 0), // Drowzee
    97: BattleSpriteMetric(67, 62, 62, 0, 65, 60, 60, 0), // Hypno
    98: BattleSpriteMetric(55, 40, 39, 0, 57, 44, 42, 1), // Krabby
    99: BattleSpriteMetric(82, 59, 59, 0, 85, 65, 63, 1), // Kingler
    100: BattleSpriteMetric(46, 31, 30, 1, 48, 33, 31, 1), // Voltorb
    101: BattleSpriteMetric(48, 52, 46, 1, 50, 54, 46, 2), // Electrode
    102: BattleSpriteMetric(54, 43, 36, 1, 57, 42, 33, 2), // Exeggcute
    103: BattleSpriteMetric(78, 73, 70, 0, 77, 73, 70, 1), // Exeggutor
    104: BattleSpriteMetric(49, 43, 39, 0, 55, 43, 39, 2), // Cubone
    105: BattleSpriteMetric(67, 55, 47, 4, 67, 54, 49, 2), // Marowak
    106: BattleSpriteMetric(67, 78, 69, 0, 64, 77, 66, 2), // Hitmonlee
    107: BattleSpriteMetric(34, 59, 59, 0, 46, 58, 56, 1), // Hitmonchan
    108: BattleSpriteMetric(68, 52, 52, 0, 76, 53, 53, 0), // Lickitung
    109: BattleSpriteMetric(90, 59, 35, 20, 80, 66, 35, 15), // Koffing
    110: BattleSpriteMetric(85, 67, 64, 0, 87, 68, 63, 1), // Weezing
    111: BattleSpriteMetric(68, 54, 54, 0, 73, 54, 54, 0), // Rhyhorn
    112: BattleSpriteMetric(79, 68, 63, 0, 84, 69, 62, 1), // Rhydon
    113: BattleSpriteMetric(59, 47, 44, 1, 68, 50, 44, 2), // Chansey
    114: BattleSpriteMetric(49, 42, 42, 0, 51, 44, 41, 2), // Tangela
    115: BattleSpriteMetric(78, 61, 61, 0, 74, 69, 65, 1), // Kangaskhan
    116: BattleSpriteMetric(34, 43, 35, 8, 39, 40, 32, 8), // Horsea
    117: BattleSpriteMetric(57, 56, 47, 0, 64, 58, 47, 1), // Seadra
    118: BattleSpriteMetric(75, 57, 39, 18, 74, 57, 37, 20), // Goldeen
    119: BattleSpriteMetric(72, 65, 50, 15, 96, 72, 56, 16), // Seaking
    120: BattleSpriteMetric(57, 49, 44, 4, 55, 52, 44, 7), // Staryu
    121: BattleSpriteMetric(65, 61, 52, 7, 55, 55, 53, 2), // Starmie
    122: BattleSpriteMetric(58, 53, 53, 0, 56, 53, 51, 1), // Mr. Mime
    123: BattleSpriteMetric(54, 61, 61, 0, 69, 65, 62, 2), // Scyther
    124: BattleSpriteMetric(63, 60, 53, 3, 64, 62, 53, 4), // Jynx
    125: BattleSpriteMetric(72, 65, 61, 0, 75, 65, 59, 1), // Electabuzz
    126: BattleSpriteMetric(71, 61, 61, 0, 71, 62, 59, 1), // Magmar
    127: BattleSpriteMetric(73, 63, 61, 0, 72, 62, 61, 1), // Pinsir
    128: BattleSpriteMetric(75, 59, 59, 0, 74, 56, 54, 1), // Tauros
    129: BattleSpriteMetric(47, 64, 57, 0, 66, 58, 50, 1), // Magikarp
    130: BattleSpriteMetric(102, 84, 77, 6, 109, 83, 77, 3), // Gyarados
    131: BattleSpriteMetric(68, 72, 66, 3, 86, 83, 71, 6), // Lapras
    132: BattleSpriteMetric(47, 32, 29, 0, 49, 34, 29, 1), // Ditto
    133: BattleSpriteMetric(46, 47, 47, 0, 51, 52, 47, 4), // Eevee
    134: BattleSpriteMetric(50, 59, 53, 3, 55, 57, 54, 0), // Vaporeon
    135: BattleSpriteMetric(47, 49, 49, 0, 53, 50, 48, 1), // Jolteon
    136: BattleSpriteMetric(66, 60, 49, 0, 80, 57, 47, 1), // Flareon
    137: BattleSpriteMetric(57, 53, 40, 0, 62, 48, 38, 0), // Porygon
    138: BattleSpriteMetric(43, 44, 34, 0, 49, 48, 34, 4), // Omanyte
    139: BattleSpriteMetric(62, 58, 48, 1, 64, 61, 50, 1), // Omastar
    140: BattleSpriteMetric(39, 41, 30, 6, 37, 43, 32, 3), // Kabuto
    141: BattleSpriteMetric(64, 61, 61, 0, 67, 55, 55, 0), // Kabutops
    142: BattleSpriteMetric(94, 82, 59, 19, 89, 92, 67, 22), // Aerodactyl
    143: BattleSpriteMetric(74, 75, 67, 1, 78, 73, 63, 1), // Snorlax
    144: BattleSpriteMetric(73, 81, 81, 0, 78, 87, 78, 2), // Articuno
    145: BattleSpriteMetric(96, 71, 58, 13, 87, 74, 61, 12), // Zapdos
    146: BattleSpriteMetric(128, 97, 74, 22, 119, 81, 60, 17), // Moltres
    147: BattleSpriteMetric(44, 51, 44, 4, 50, 58, 46, 10), // Dratini
    148: BattleSpriteMetric(64, 73, 68, 0, 65, 76, 67, 4), // Dragonair
    149: BattleSpriteMetric(80, 82, 80, 0, 86, 81, 80, 1), // Dragonite
    150: BattleSpriteMetric(90, 69, 65, 0, 95, 71, 65, 0), // Mewtwo
    151: BattleSpriteMetric(77, 53, 42, 1, 62, 63, 44, 2), // Mew
    152: BattleSpriteMetric(41, 56, 44, 0, 41, 59, 45, 0), // Chikorita
    153: BattleSpriteMetric(52, 80, 61, 1, 55, 78, 60, 2), // Bayleef
    154: BattleSpriteMetric(59, 82, 82, 0, 64, 80, 80, 0), // Meganium
    155: BattleSpriteMetric(44, 37, 37, 0, 46, 37, 36, 0), // Cyndaquil
    156: BattleSpriteMetric(63, 53, 45, 0, 63, 53, 53, 0), // Quilava
    157: BattleSpriteMetric(59, 72, 71, 0, 60, 72, 70, 1), // Typhlosion
    158: BattleSpriteMetric(43, 58, 36, 0, 44, 63, 38, 1), // Totodile
    159: BattleSpriteMetric(45, 59, 58, 1, 48, 60, 58, 1), // Croconaw
    160: BattleSpriteMetric(82, 72, 72, 0, 84, 75, 73, 1), // Feraligatr
    252: BattleSpriteMetric(43, 63, 45, 6, 46, 63, 46, 5), // Treecko
    253: BattleSpriteMetric(64, 70, 57, 0, 75, 77, 61, 1), // Grovyle
    254: BattleSpriteMetric(67, 74, 71, 0, 75, 86, 77, 6), // Sceptile
    255: BattleSpriteMetric(33, 47, 43, 0, 31, 46, 42, 0), // Torchic
    256: BattleSpriteMetric(71, 63, 63, 0, 71, 65, 65, 0), // Combusken
    257: BattleSpriteMetric(59, 75, 75, 0, 73, 72, 72, 0), // Blaziken
    258: BattleSpriteMetric(43, 49, 42, 0, 44, 52, 43, 1), // Mudkip
    259: BattleSpriteMetric(54, 58, 56, 1, 50, 59, 58, 0), // Marshtomp
    260: BattleSpriteMetric(76, 60, 58, 1, 82, 61, 60, 0), // Swampert
    387: BattleSpriteMetric(31, 42, 42, 0, 34, 43, 43, 0), // Turtwig
    388: BattleSpriteMetric(61, 61, 58, 0, 59, 62, 59, 0), // Grotle
    389: BattleSpriteMetric(78, 80, 77, 0, 84, 82, 78, 0), // Torterra
    390: BattleSpriteMetric(41, 56, 45, 1, 45, 55, 46, 0), // Chimchar
    391: BattleSpriteMetric(70, 68, 52, 0, 68, 68, 54, 1), // Monferno
    392: BattleSpriteMetric(80, 74, 68, 0, 83, 78, 68, 0), // Infernape
    393: BattleSpriteMetric(30, 41, 35, 1, 27, 41, 35, 1), // Piplup
    394: BattleSpriteMetric(59, 61, 57, 1, 58, 60, 55, 2), // Prinplup
    395: BattleSpriteMetric(88, 78, 77, 0, 83, 75, 74, 0), // Empoleon
    495: BattleSpriteMetric(46, 39, 37, 0, 48, 41, 38, 0), // Snivy
    496: BattleSpriteMetric(62, 58, 58, 0, 59, 60, 60, 0), // Servine
    497: BattleSpriteMetric(88, 74, 68, 1, 81, 79, 72, 1), // Serperior
    498: BattleSpriteMetric(37, 46, 39, 2, 38, 47, 41, 1), // Tepig
    499: BattleSpriteMetric(55, 57, 57, 0, 59, 61, 59, 2), // Pignite
    500: BattleSpriteMetric(92, 76, 72, 0, 94, 80, 75, 1), // Emboar
    501: BattleSpriteMetric(33, 48, 36, 0, 33, 51, 36, 3), // Oshawott
    502: BattleSpriteMetric(36, 56, 56, 0, 34, 56, 56, 0), // Dewott
    503: BattleSpriteMetric(95, 80, 80, 0, 88, 80, 80, 0), // Samurott
  };

  static BattleSpriteMetric of(int speciesId) => bySpeciesId[speciesId] ?? fallback;

  static ResolvedBattleSpriteLayout resolve({
    required int speciesId,
    required bool isBack,
    required double targetZoom,
    required double maxWidth,
    required double maxHeight,
  }) {
    final m = of(speciesId);
    final int rawW = isBack ? m.backW : m.frontW;
    final int rawH = isBack ? m.backH : m.frontH;
    final int rawVisH = isBack ? m.backVisH : m.frontVisH;
    final int rawPadB = isBack ? m.backPadB : m.frontPadB;

    final double safeW = rawW > 0 ? rawW.toDouble() : 60.0;
    final double safeH = rawH > 0 ? rawH.toDouble() : 60.0;
    final double zoom = min(targetZoom, min(maxWidth / safeW, maxHeight / safeH));
    final double renderW = (safeW * zoom).roundToDouble();
    final double renderH = (safeH * zoom).roundToDouble();

    final double visHClamped = rawVisH > 0 ? rawVisH.toDouble() : safeH;
    final double bodyBottom = rawPadB * zoom;
    final double bodyH = visHClamped * zoom;
    final double bodyCenterFromBottom = bodyBottom + bodyH * 0.5;
    final double bodyTopFromBottom = (bodyBottom + bodyH).clamp(bodyH, renderH);

    return ResolvedBattleSpriteLayout(
      width: renderW,
      height: renderH,
      zoom: zoom,
      bodyCenterFromBottom: bodyCenterFromBottom,
      bodyTopFromBottom: bodyTopFromBottom,
      visualHeight: bodyH,
    );
  }
}
