import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import 'pokedex_database.dart';

class GymPokemonSpec {
  final int speciesId;
  final int level;
  final List<String>? moveIds;

  const GymPokemonSpec({
    required this.speciesId,
    required this.level,
    this.moveIds,
  });

  PokemonInstance createInstance() {
    final species = PokedexDatabase.species[speciesId] ?? PokedexDatabase.species[1]!;
    final moves = (moveIds != null && moveIds!.isNotEmpty)
        ? moveIds!
            .map((id) => PokedexDatabase.moves[id]?.copy())
            .whereType<Move>()
            .toList()
        : PokedexDatabase.movesForSpeciesAtLevel(species, level);
    return PokemonInstance(
      species: species,
      level: level,
      moves: moves,
    );
  }
}

class GymTrainer {
  final String id;
  final String name;
  final String title;
  final int prizeMoney;
  final String introDialogue;
  final List<GymPokemonSpec> team;

  const GymTrainer({
    required this.id,
    required this.name,
    required this.title,
    required this.prizeMoney,
    required this.introDialogue,
    required this.team,
  });
}

class GymDefinition {
  final int id;
  final String name;
  final String city;
  final String leaderName;
  final String leaderTitle;
  final String badgeName;
  final String badgeDescription;
  final String element;
  final Color elementColor;
  final int requiredCaught;
  final int requiredSteps;
  final String signatureHeldItemDrop;
  final String signatureStoneDrop;
  final List<GymTrainer> trainers; // 4 Junior Gym Trainers
  final GymTrainer leader; // The Gym Leader

  const GymDefinition({
    required this.id,
    required this.name,
    required this.city,
    required this.leaderName,
    required this.leaderTitle,
    required this.badgeName,
    required this.badgeDescription,
    required this.element,
    required this.elementColor,
    required this.requiredCaught,
    required this.requiredSteps,
    required this.signatureHeldItemDrop,
    required this.signatureStoneDrop,
    required this.trainers,
    required this.leader,
  });

  List<GymTrainer> get fullGauntlet => [...trainers, leader];
}

class GymDatabase {
  static final List<GymDefinition> gyms = [
    // === 1. PEWTER GYM (Brock) ===
    GymDefinition(
      id: 1,
      name: "Pewter Gym",
      city: "Pewter City",
      leaderName: "Brock",
      leaderTitle: "The Rock-Solid Pokémon Trainer",
      badgeName: "Boulder Badge",
      badgeDescription: "+10% Phys ATK • Commands Pokémon up to Lv. 25",
      element: "Rock",
      elementColor: const Color(0xFFBCAAA4),
      requiredCaught: 10,
      requiredSteps: 2000,
      signatureHeldItemDrop: 'hard_stone',
      signatureStoneDrop: 'moon_stone',
      trainers: [
        const GymTrainer(
          id: 'pewter_t1',
          name: 'Camper Liam',
          title: 'Gym Junior Trainer',
          prizeMoney: 250,
          introDialogue: "Stop right there! You're ten thousand light-years from facing Brock!",
          team: [GymPokemonSpec(speciesId: 74, level: 9)], // Geodude
        ),
        const GymTrainer(
          id: 'pewter_t2',
          name: 'Hiker Anthony',
          title: 'Mountain Man',
          prizeMoney: 300,
          introDialogue: "My rock Pokémon have high defense! Can you scratch them?",
          team: [GymPokemonSpec(speciesId: 74, level: 10)], // Geodude
        ),
        const GymTrainer(
          id: 'pewter_t3',
          name: 'Picnicker Diana',
          title: 'Gym Trainer',
          prizeMoney: 350,
          introDialogue: "Watch out for sand attack! My Sandshrew is super swift!",
          team: [GymPokemonSpec(speciesId: 27, level: 10)], // Sandshrew
        ),
        const GymTrainer(
          id: 'pewter_t4',
          name: 'Jr. Trainer Jerry',
          title: 'Brock\'s Apprentice',
          prizeMoney: 400,
          introDialogue: "If you can't beat me, you'll never survive Brock's Onix!",
          team: [
            GymPokemonSpec(speciesId: 50, level: 11), // Diglett
            GymPokemonSpec(speciesId: 74, level: 11), // Geodude
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'brock',
        name: 'Brock',
        title: 'Pewter Gym Leader',
        prizeMoney: 1400,
        introDialogue: "I'm Brock! I'm Pewter's Gym Leader! My rock-hard willpower is evident even in my Pokémon!",
        team: [
          GymPokemonSpec(speciesId: 74, level: 12), // Geodude
          GymPokemonSpec(speciesId: 95, level: 14), // Onix
        ],
      ),
    ),

    // === 2. CERULEAN GYM (Misty) ===
    GymDefinition(
      id: 2,
      name: "Cerulean Gym",
      city: "Cerulean City",
      leaderName: "Misty",
      leaderTitle: "The Tomboyish Mermaid",
      badgeName: "Cascade Badge",
      badgeDescription: "+10% Spec ATK • Commands Pokémon up to Lv. 34",
      element: "Water",
      elementColor: const Color(0xFF4FC3F7),
      requiredCaught: 18,
      requiredSteps: 4000,
      signatureHeldItemDrop: 'mystic_water',
      signatureStoneDrop: 'water_stone',
      trainers: [
        const GymTrainer(
          id: 'cerulean_t1',
          name: 'Swimmer Luis',
          title: 'Poolside Athlete',
          prizeMoney: 450,
          introDialogue: "Splash! Let's see if your team knows how to swim!",
          team: [GymPokemonSpec(speciesId: 118, level: 15)], // Goldeen
        ),
        const GymTrainer(
          id: 'cerulean_t2',
          name: 'Sailor Trevor',
          title: 'Ocean Sailor',
          prizeMoney: 500,
          introDialogue: "Anchors aweigh! My water partners won't take it easy on you!",
          team: [
            GymPokemonSpec(speciesId: 116, level: 15), // Horsea
            GymPokemonSpec(speciesId: 90, level: 15), // Shellder
          ],
        ),
        const GymTrainer(
          id: 'cerulean_t3',
          name: 'Picnicker Diana',
          title: 'Cerulean Swimmer',
          prizeMoney: 550,
          introDialogue: "Poliwag's Water Gun will wash you right out of our gym pool!",
          team: [GymPokemonSpec(speciesId: 60, level: 17)], // Poliwag
        ),
        const GymTrainer(
          id: 'cerulean_t4',
          name: 'Beauty Violet',
          title: 'Gym Sensational Sister',
          prizeMoney: 600,
          introDialogue: "Misty is tough, but you'll have to get past our synchronized defense first!",
          team: [
            GymPokemonSpec(speciesId: 118, level: 16), // Goldeen
            GymPokemonSpec(speciesId: 120, level: 16), // Staryu
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'misty',
        name: 'Misty',
        title: 'Cerulean Gym Leader',
        prizeMoney: 2100,
        introDialogue: "Hi, you're a new face! Only trainers with true policy and skill can win against my Water Pokémon!",
        team: [
          GymPokemonSpec(speciesId: 120, level: 18), // Staryu
          GymPokemonSpec(speciesId: 121, level: 21), // Starmie
        ],
      ),
    ),

    // === 3. VERMILION GYM (Lt. Surge) ===
    GymDefinition(
      id: 3,
      name: "Vermilion Gym",
      city: "Vermilion City",
      leaderName: "Lt. Surge",
      leaderTitle: "The Lightning American",
      badgeName: "Thunder Badge",
      badgeDescription: "+10% Speed • Commands Pokémon up to Lv. 42",
      element: "Electric",
      elementColor: const Color(0xFFFFD54F),
      requiredCaught: 28,
      requiredSteps: 6000,
      signatureHeldItemDrop: 'magnet',
      signatureStoneDrop: 'thunder_stone',
      trainers: [
        const GymTrainer(
          id: 'vermilion_t1',
          name: 'Sailor Dwayne',
          title: 'Naval Recruit',
          prizeMoney: 650,
          introDialogue: "Lt. Surge taught me the shock-and-awe combat doctrine!",
          team: [GymPokemonSpec(speciesId: 25, level: 19)], // Pikachu
        ),
        const GymTrainer(
          id: 'vermilion_t2',
          name: 'Engineer Baily',
          title: 'Power Plant Tech',
          prizeMoney: 700,
          introDialogue: "High voltage warning! Magnemite is fully charged!",
          team: [GymPokemonSpec(speciesId: 81, level: 20)], // Magnemite
        ),
        const GymTrainer(
          id: 'vermilion_t3',
          name: 'Gentleman Tucker',
          title: 'Army Veteran',
          prizeMoney: 800,
          introDialogue: "War is rough, rookie! Prepare for rapid electric fire!",
          team: [
            GymPokemonSpec(speciesId: 25, level: 20), // Pikachu
            GymPokemonSpec(speciesId: 100, level: 20), // Voltorb
          ],
        ),
        const GymTrainer(
          id: 'vermilion_t4',
          name: 'Rocker Gene',
          title: 'Sound & Surge',
          prizeMoney: 850,
          introDialogue: "Can you hear that hum? It's the electric current ready to buzz you!",
          team: [
            GymPokemonSpec(speciesId: 100, level: 21), // Voltorb
            GymPokemonSpec(speciesId: 81, level: 21), // Magnemite
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'lt_surge',
        name: 'Lt. Surge',
        title: 'Vermilion Gym Leader',
        prizeMoney: 2400,
        introDialogue: "Ten-hut! You won't live long in combat with just guts! I tell you, electric Pokémon saved me during the war!",
        team: [
          GymPokemonSpec(speciesId: 100, level: 21), // Voltorb
          GymPokemonSpec(speciesId: 25, level: 22), // Pikachu
          GymPokemonSpec(speciesId: 26, level: 24), // Raichu
        ],
      ),
    ),

    // === 4. CELADON GYM (Erika) ===
    GymDefinition(
      id: 4,
      name: "Celadon Gym",
      city: "Celadon City",
      leaderName: "Erika",
      leaderTitle: "The Nature-Loving Princess",
      badgeName: "Rainbow Badge",
      badgeDescription: "+10% Spec DEF • Commands Pokémon up to Lv. 50",
      element: "Grass",
      elementColor: const Color(0xFF81C784),
      requiredCaught: 40,
      requiredSteps: 8000,
      signatureHeldItemDrop: 'miracle_seed',
      signatureStoneDrop: 'leaf_stone',
      trainers: [
        const GymTrainer(
          id: 'celadon_t1',
          name: 'Lass Kay',
          title: 'Flower Arranger',
          prizeMoney: 850,
          introDialogue: "Welcome to our botanical paradise! Watch out for sweet scents!",
          team: [
            GymPokemonSpec(speciesId: 69, level: 23), // Bellsprout
            GymPokemonSpec(speciesId: 43, level: 23), // Oddish
          ],
        ),
        const GymTrainer(
          id: 'celadon_t2',
          name: 'Beauty Tamia',
          title: 'Floral Designer',
          prizeMoney: 900,
          introDialogue: "Our petals hide sharp thorns and paralyzing spores!",
          team: [
            GymPokemonSpec(speciesId: 43, level: 24), // Oddish
            GymPokemonSpec(speciesId: 69, level: 24), // Bellsprout
          ],
        ),
        const GymTrainer(
          id: 'celadon_t3',
          name: 'Picnicker Tina',
          title: 'Nature Scout',
          prizeMoney: 950,
          introDialogue: "My Bulbasaur has trained under Erika's serene guidance!",
          team: [
            GymPokemonSpec(speciesId: 1, level: 24), // Bulbasaur
            GymPokemonSpec(speciesId: 2, level: 26), // Ivysaur
          ],
        ),
        const GymTrainer(
          id: 'celadon_t4',
          name: 'Cooltrainer Mary',
          title: 'Celadon Elite',
          prizeMoney: 1050,
          introDialogue: "Only those who respect the delicate strength of flora may challenge the mistress!",
          team: [
            GymPokemonSpec(speciesId: 70, level: 26), // Weepinbell
            GymPokemonSpec(speciesId: 44, level: 26), // Gloom
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'erika',
        name: 'Erika',
        title: 'Celadon Gym Leader',
        prizeMoney: 2900,
        introDialogue: "Hello... Lovely weather, isn't it? It's so pleasant. My name is Erika. I am the Leader of Celadon Gym.",
        team: [
          GymPokemonSpec(speciesId: 71, level: 29), // Victreebel
          GymPokemonSpec(speciesId: 114, level: 24), // Tangela
          GymPokemonSpec(speciesId: 45, level: 29), // Vileplume
        ],
      ),
    ),

    // === 5. FUCHSIA GYM (Koga) ===
    GymDefinition(
      id: 5,
      name: "Fuchsia Gym",
      city: "Fuchsia City",
      leaderName: "Koga",
      leaderTitle: "The Poisonous Ninja Master",
      badgeName: "Soul Badge",
      badgeDescription: "+10% Phys DEF • Commands Pokémon up to Lv. 60",
      element: "Poison",
      elementColor: const Color(0xFFBA68C8),
      requiredCaught: 55,
      requiredSteps: 10000,
      signatureHeldItemDrop: 'poison_barb',
      signatureStoneDrop: 'fire_stone',
      trainers: [
        const GymTrainer(
          id: 'fuchsia_t1',
          name: 'Juggler Kirk',
          title: 'Ninja Illusionist',
          prizeMoney: 1100,
          introDialogue: "Fwahaha! The invisible walls are just the first of my illusions!",
          team: [
            GymPokemonSpec(speciesId: 96, level: 34), // Drowzee
            GymPokemonSpec(speciesId: 64, level: 34), // Kadabra
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t2',
          name: 'Tamer Edgar',
          title: 'Beast Ninja',
          prizeMoney: 1200,
          introDialogue: "Venom courses through my serpentine companions!",
          team: [
            GymPokemonSpec(speciesId: 24, level: 33), // Arbok
            GymPokemonSpec(speciesId: 28, level: 33), // Sandslash
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t3',
          name: 'Juggler Shawn',
          title: 'Hypnotic Master',
          prizeMoney: 1300,
          introDialogue: "Can your mind resist sleep while toxins sap your vitality?",
          team: [
            GymPokemonSpec(speciesId: 96, level: 34), // Drowzee
            GymPokemonSpec(speciesId: 97, level: 36), // Hypno
          ],
        ),
        const GymTrainer(
          id: 'fuchsia_t4',
          name: 'Ninja Boy Lao',
          title: 'Shadow Disciple',
          prizeMoney: 1400,
          introDialogue: "Koga's ninja techniques have been passed down for four centuries!",
          team: [
            GymPokemonSpec(speciesId: 109, level: 35), // Koffing
            GymPokemonSpec(speciesId: 88, level: 35), // Grimer
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'koga',
        name: 'Koga',
        title: 'Fuchsia Gym Leader',
        prizeMoney: 4300,
        introDialogue: "Fwahahaha! A mere child challenges me? Very well, despair before the creeping terror of poison and sleep!",
        team: [
          GymPokemonSpec(speciesId: 109, level: 37), // Koffing
          GymPokemonSpec(speciesId: 89, level: 39), // Muk
          GymPokemonSpec(speciesId: 109, level: 37), // Koffing
          GymPokemonSpec(speciesId: 110, level: 43), // Weezing
        ],
      ),
    ),

    // === 6. SAFFRON GYM (Sabrina) ===
    GymDefinition(
      id: 6,
      name: "Saffron Gym",
      city: "Saffron City",
      leaderName: "Sabrina",
      leaderTitle: "The Master of Psychic Pokémon",
      badgeName: "Marsh Badge",
      badgeDescription: "+10% Max HP • Commands Pokémon up to Lv. 70",
      element: "Psychic",
      elementColor: const Color(0xFFFF80AB),
      requiredCaught: 70,
      requiredSteps: 12000,
      signatureHeldItemDrop: 'twisted_spoon',
      signatureStoneDrop: 'moon_stone',
      trainers: [
        const GymTrainer(
          id: 'saffron_t1',
          name: 'Psychic Johan',
          title: 'Telekinetic Adept',
          prizeMoney: 1400,
          introDialogue: "I can read your mind! You are wondering if you can defeat me!",
          team: [
            GymPokemonSpec(speciesId: 64, level: 36), // Kadabra
            GymPokemonSpec(speciesId: 122, level: 36), // Mr. Mime
          ],
        ),
        const GymTrainer(
          id: 'saffron_t2',
          name: 'Channeler Stacy',
          title: 'Medium of Spirits',
          prizeMoney: 1450,
          introDialogue: "The unseen realm bows to Sabrina's overwhelming psionic will!",
          team: [
            GymPokemonSpec(speciesId: 92, level: 34), // Gastly
            GymPokemonSpec(speciesId: 93, level: 36), // Haunter
          ],
        ),
        const GymTrainer(
          id: 'saffron_t3',
          name: 'Psychic Cameron',
          title: 'Mind Bender',
          prizeMoney: 1500,
          introDialogue: "Physical attacks cannot breach a focused telepathic mind!",
          team: [
            GymPokemonSpec(speciesId: 79, level: 35), // Slowpoke
            GymPokemonSpec(speciesId: 80, level: 37), // Slowbro
          ],
        ),
        const GymTrainer(
          id: 'saffron_t4',
          name: 'Psychic Preston',
          title: 'High Esper',
          prizeMoney: 1600,
          introDialogue: "Sabrina foresaw your arrival three days ago. Your defeat was also predicted!",
          team: [
            GymPokemonSpec(speciesId: 80, level: 38), // Slowbro
            GymPokemonSpec(speciesId: 64, level: 38), // Kadabra
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'sabrina',
        name: 'Sabrina',
        title: 'Saffron Gym Leader',
        prizeMoney: 4300,
        introDialogue: "I had a vision of your arrival! I have had psychic powers since I was a child. I do not like to fight, but I will not lose!",
        team: [
          GymPokemonSpec(speciesId: 64, level: 38), // Kadabra
          GymPokemonSpec(speciesId: 122, level: 37), // Mr. Mime
          GymPokemonSpec(speciesId: 49, level: 38), // Venomoth
          GymPokemonSpec(speciesId: 65, level: 43), // Alakazam
        ],
      ),
    ),

    // === 7. CINNABAR GYM (Blaine) ===
    GymDefinition(
      id: 7,
      name: "Cinnabar Gym",
      city: "Cinnabar Island",
      leaderName: "Blaine",
      leaderTitle: "The Hotheaded Quiz Master",
      badgeName: "Volcano Badge",
      badgeDescription: "+10% Critical Hit Rate • Commands Pokémon up to Lv. 82",
      element: "Fire",
      elementColor: const Color(0xFFFF7043),
      requiredCaught: 85,
      requiredSteps: 15000,
      signatureHeldItemDrop: 'charcoal',
      signatureStoneDrop: 'fire_stone',
      trainers: [
        const GymTrainer(
          id: 'cinnabar_t1',
          name: 'Burglar Quinn',
          title: 'Torchbearer',
          prizeMoney: 1600,
          introDialogue: "Quiz time! Does fire burn? You're about to find out first hand!",
          team: [
            GymPokemonSpec(speciesId: 58, level: 39), // Growlithe
            GymPokemonSpec(speciesId: 37, level: 39), // Vulpix
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t2',
          name: 'Super Nerd Erik',
          title: 'Thermodynamics Researcher',
          prizeMoney: 1700,
          introDialogue: "The combustion reaction in Ninetales' nine tails is mathematically sublime!",
          team: [
            GymPokemonSpec(speciesId: 37, level: 40), // Vulpix
            GymPokemonSpec(speciesId: 38, level: 42), // Ninetales
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t3',
          name: 'Burglar Ramon',
          title: 'Fire Thief',
          prizeMoney: 1800,
          introDialogue: "Can your Pokémon withstand a 10,000-degree blaze?",
          team: [
            GymPokemonSpec(speciesId: 77, level: 41), // Ponyta
            GymPokemonSpec(speciesId: 58, level: 41), // Growlithe
          ],
        ),
        const GymTrainer(
          id: 'cinnabar_t4',
          name: 'Super Nerd Avery',
          title: 'Volcano Expert',
          prizeMoney: 1900,
          introDialogue: "Magmar's body burns brighter than magma! You better bring Burn Heal!",
          team: [
            GymPokemonSpec(speciesId: 78, level: 43), // Rapidash
            GymPokemonSpec(speciesId: 126, level: 43), // Magmar
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'blaine',
        name: 'Blaine',
        title: 'Cinnabar Gym Leader',
        prizeMoney: 4700,
        introDialogue: "Hah! I am Blaine, the red-hot quiz master! My fiery Pokémon will incinerate all challengers! You better have Burn Heal ready!",
        team: [
          GymPokemonSpec(speciesId: 58, level: 42), // Growlithe
          GymPokemonSpec(speciesId: 77, level: 40), // Ponyta
          GymPokemonSpec(speciesId: 78, level: 42), // Rapidash
          GymPokemonSpec(speciesId: 59, level: 47), // Arcanine
        ],
      ),
    ),

    // === 8. VIRIDIAN GYM (Giovanni) ===
    GymDefinition(
      id: 8,
      name: "Viridian Gym",
      city: "Viridian City",
      leaderName: "Giovanni",
      leaderTitle: "The Master of Earth & Legendary Boss",
      badgeName: "Earth Badge",
      badgeDescription: "Master Boost (+5% All Stats) • Commands Lv. 100 • Unlocks Legendaries",
      element: "Ground",
      elementColor: const Color(0xFFFFB300),
      requiredCaught: 100,
      requiredSteps: 20000,
      signatureHeldItemDrop: 'soft_sand',
      signatureStoneDrop: 'leftovers',
      trainers: [
        const GymTrainer(
          id: 'viridian_t1',
          name: 'Tamer Cole',
          title: 'Beast Master',
          prizeMoney: 2000,
          introDialogue: "The Viridian Gym was closed for so long... Now only the elite may tread here!",
          team: [
            GymPokemonSpec(speciesId: 24, level: 43), // Arbok
            GymPokemonSpec(speciesId: 128, level: 44), // Tauros
          ],
        ),
        const GymTrainer(
          id: 'viridian_t2',
          name: 'Black Belt Takashi',
          title: 'Dojo Champion',
          prizeMoney: 2100,
          introDialogue: "Earth and martial arts unite! We will crush your defenses to gravel!",
          team: [
            GymPokemonSpec(speciesId: 67, level: 44), // Machoke
            GymPokemonSpec(speciesId: 68, level: 46), // Machamp
          ],
        ),
        const GymTrainer(
          id: 'viridian_t3',
          name: 'Cooltrainer Samuel',
          title: 'Gym Enforcer',
          prizeMoney: 2200,
          introDialogue: "Rhyhorn's armor cannot be pierced by ordinary strikes! Tremble!",
          team: [
            GymPokemonSpec(speciesId: 28, level: 45), // Sandslash
            GymPokemonSpec(speciesId: 111, level: 46), // Rhyhorn
          ],
        ),
        const GymTrainer(
          id: 'viridian_t4',
          name: 'Cooltrainer Yuji',
          title: 'Giovanni\'s Right Hand',
          prizeMoney: 2300,
          introDialogue: "You stand before the gateway to the Pokémon League! Show me your absolute peak!",
          team: [
            GymPokemonSpec(speciesId: 33, level: 46), // Nidorino
            GymPokemonSpec(speciesId: 75, level: 47), // Graveler
          ],
        ),
      ],
      leader: const GymTrainer(
        id: 'giovanni',
        name: 'Giovanni',
        title: 'Viridian Gym Leader',
        prizeMoney: 5000,
        introDialogue: "Fwahaha! Welcome to my hideout! It seems you've made quite a name for yourself. But this is the end of the line! Behold the ultimate power of Earth!",
        team: [
          GymPokemonSpec(speciesId: 111, level: 45), // Rhyhorn
          GymPokemonSpec(speciesId: 51, level: 42), // Dugtrio
          GymPokemonSpec(speciesId: 31, level: 45), // Nidoqueen
          GymPokemonSpec(speciesId: 34, level: 46), // Nidoking
          GymPokemonSpec(speciesId: 112, level: 50), // Rhydon
        ],
      ),
    ),
  ];

  static GymDefinition? getGymById(int id) {
    if (id < 1 || id > gyms.length) return null;
    return gyms[id - 1];
  }
}
