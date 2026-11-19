class AbilityDefinition {
  final String id;
  final String name;
  final String description;

  const AbilityDefinition({
    required this.id,
    required this.name,
    required this.description,
  });
}

class AbilityDatabase {
  static const Map<String, AbilityDefinition> all = {
    'adaptability': AbilityDefinition(
      id: 'adaptability',
      name: 'Adaptability',
      description: 'Powers up moves of the same type as the Pokémon (2x STAB instead of 1.5x).',
    ),
    'aftermath': AbilityDefinition(
      id: 'aftermath',
      name: 'Aftermath',
      description: 'Damages the attacker for 1/4 max HP if knocked out by a contact move.',
    ),
    'analytic': AbilityDefinition(
      id: 'analytic',
      name: 'Analytic',
      description: 'Boosts move power by 30% if the user attacks after the foe.',
    ),
    'anger_point': AbilityDefinition(
      id: 'anger_point',
      name: 'Anger Point',
      description: 'Maxes out Attack upon taking a critical hit.',
    ),
    'anticipation': AbilityDefinition(
      id: 'anticipation',
      name: 'Anticipation',
      description: 'Senses dangerous super-effective or one-hit KO moves on entry.',
    ),
    'arena_trap': AbilityDefinition(
      id: 'arena_trap',
      name: 'Arena Trap',
      description: 'Prevents grounded opposing Pokémon from fleeing or switching.',
    ),
    'battle_armor': AbilityDefinition(
      id: 'battle_armor',
      name: 'Battle Armor',
      description: 'Hard armor protects the Pokémon from critical hits.',
    ),
    'big_pecks': AbilityDefinition(
      id: 'big_pecks',
      name: 'Big Pecks',
      description: 'Protects the Pokémon from Defense-lowering effects.',
    ),
    'blaze': AbilityDefinition(
      id: 'blaze',
      name: 'Blaze',
      description: 'Powers up Fire-type moves by 50% when HP drops to 1/3 or below.',
    ),
    'chlorophyll': AbilityDefinition(
      id: 'chlorophyll',
      name: 'Chlorophyll',
      description: 'Doubles the Pokémon\'s Speed stat in harsh sunlight.',
    ),
    'clear_body': AbilityDefinition(
      id: 'clear_body',
      name: 'Clear Body',
      description: 'Prevents other Pokémon\'s moves or Abilities from lowering stats.',
    ),
    'cloud_nine': AbilityDefinition(
      id: 'cloud_nine',
      name: 'Cloud Nine',
      description: 'Eliminates all weather effects while the Pokémon is in battle.',
    ),
    'compound_eyes': AbilityDefinition(
      id: 'compound_eyes',
      name: 'Compound Eyes',
      description: 'The Pokémon\'s compound eyes boost move accuracy by 30%.',
    ),
    'cute_charm': AbilityDefinition(
      id: 'cute_charm',
      name: 'Cute Charm',
      description: 'Making contact may cause the attacker to become infatuated/hesitate.',
    ),
    'damp': AbilityDefinition(
      id: 'damp',
      name: 'Damp',
      description: 'Prevents all Pokémon from using Self-Destruct or Explosion.',
    ),
    'defiant': AbilityDefinition(
      id: 'defiant',
      name: 'Defiant',
      description: 'Sharply raises Attack by 2 stages whenever a foe lowers its stats.',
    ),
    'download': AbilityDefinition(
      id: 'download',
      name: 'Download',
      description: 'Raises Attack or Sp. Atk on entry based on the foe\'s lower Defense.',
    ),
    'drought': AbilityDefinition(
      id: 'drought',
      name: 'Drought',
      description: 'Turns the sunlight harsh when the Pokémon enters battle.',
    ),
    'dry_skin': AbilityDefinition(
      id: 'dry_skin',
      name: 'Dry Skin',
      description: 'Restores HP from Water moves and Rain; takes extra damage from Fire and Sun.',
    ),
    'early_bird': AbilityDefinition(
      id: 'early_bird',
      name: 'Early Bird',
      description: 'The Pokémon awakens twice as fast as other Pokémon from sleep.',
    ),
    'effect_spore': AbilityDefinition(
      id: 'effect_spore',
      name: 'Effect Spore',
      description: 'Contact with the Pokémon may inflict poison, sleep, or paralysis.',
    ),
    'filter': AbilityDefinition(
      id: 'filter',
      name: 'Filter',
      description: 'Reduces damage from super-effective attacks by 25%.',
    ),
    'flame_body': AbilityDefinition(
      id: 'flame_body',
      name: 'Flame Body',
      description: 'Contact with the Pokémon may burn the attacker.',
    ),
    'flash_fire': AbilityDefinition(
      id: 'flash_fire',
      name: 'Flash Fire',
      description: 'Absorbs Fire-type hits to power up its own Fire moves by 50%.',
    ),
    'forewarn': AbilityDefinition(
      id: 'forewarn',
      name: 'Forewarn',
      description: 'Reveals the foe\'s highest-power attack upon entering battle.',
    ),
    'friend_guard': AbilityDefinition(
      id: 'friend_guard',
      name: 'Friend Guard',
      description: 'Reduces damage taken from incoming attacks slightly.',
    ),
    'frisk': AbilityDefinition(
      id: 'frisk',
      name: 'Frisk',
      description: 'Identifies the opposing Pokémon\'s held item upon entering battle.',
    ),
    'gluttony': AbilityDefinition(
      id: 'gluttony',
      name: 'Gluttony',
      description: 'Triggers HP-restoring held Berries earlier, at 50% HP or below.',
    ),
    'guts': AbilityDefinition(
      id: 'guts',
      name: 'Guts',
      description: 'Boosts Attack by 50% if afflicted with a status condition, ignoring Burn drop.',
    ),
    'harvest': AbilityDefinition(
      id: 'harvest',
      name: 'Harvest',
      description: 'May restore a consumed held Berry at the end of a turn (always in Sun).',
    ),
    'healer': AbilityDefinition(
      id: 'healer',
      name: 'Healer',
      description: 'Occasionally soothes status conditions at the end of a turn.',
    ),
    'hustle': AbilityDefinition(
      id: 'hustle',
      name: 'Hustle',
      description: 'Boosts Attack by 50%, but lowers accuracy of physical moves by 20%.',
    ),
    'hydration': AbilityDefinition(
      id: 'hydration',
      name: 'Hydration',
      description: 'Heals status conditions at the end of each turn if it is raining.',
    ),
    'hyper_cutter': AbilityDefinition(
      id: 'hyper_cutter',
      name: 'Hyper Cutter',
      description: 'Protects the Pokémon from having its Attack stat lowered.',
    ),
    'ice_body': AbilityDefinition(
      id: 'ice_body',
      name: 'Ice Body',
      description: 'Gradually regains 1/16 max HP each turn during a hailstorm.',
    ),
    'illuminate': AbilityDefinition(
      id: 'illuminate',
      name: 'Illuminate',
      description: 'Emits a bright glow; carries no direct battle modifier.',
    ),
    'immunity': AbilityDefinition(
      id: 'immunity',
      name: 'Immunity',
      description: 'Prevents the Pokémon from being poisoned.',
    ),
    'imposter': AbilityDefinition(
      id: 'imposter',
      name: 'Imposter',
      description: 'Transforms into the opposing Pokémon upon entering battle.',
    ),
    'infiltrator': AbilityDefinition(
      id: 'infiltrator',
      name: 'Infiltrator',
      description: 'Attacks bypass Light Screen, Reflect, Safeguard, and Substitute.',
    ),
    'inner_focus': AbilityDefinition(
      id: 'inner_focus',
      name: 'Inner Focus',
      description: 'The Pokémon\'s intensely focused mind protects it from flinching.',
    ),
    'insomnia': AbilityDefinition(
      id: 'insomnia',
      name: 'Insomnia',
      description: 'Prevents the Pokémon from falling asleep.',
    ),
    'intimidate': AbilityDefinition(
      id: 'intimidate',
      name: 'Intimidate',
      description: 'Lowers the opposing Pokémon\'s Attack stat on entry.',
    ),
    'iron_fist': AbilityDefinition(
      id: 'iron_fist',
      name: 'Iron Fist',
      description: 'Powers up punching moves by 20%.',
    ),
    'justified': AbilityDefinition(
      id: 'justified',
      name: 'Justified',
      description: 'Raises Attack by 1 stage when hit by a Dark-type move.',
    ),
    'keen_eye': AbilityDefinition(
      id: 'keen_eye',
      name: 'Keen Eye',
      description: 'Keen eyes prevent other Pokémon from lowering accuracy.',
    ),
    'leaf_guard': AbilityDefinition(
      id: 'leaf_guard',
      name: 'Leaf Guard',
      description: 'Prevents status conditions in harsh sunlight.',
    ),
    'levitate': AbilityDefinition(
      id: 'levitate',
      name: 'Levitate',
      description: 'By floating in the air, the Pokémon receives full immunity to Ground-type moves.',
    ),
    'lightning_rod': AbilityDefinition(
      id: 'lightning_rod',
      name: 'Lightning Rod',
      description: 'Draws in Electric moves to take no damage and raise Sp. Atk.',
    ),
    'limber': AbilityDefinition(
      id: 'limber',
      name: 'Limber',
      description: 'Its limber body protects the Pokémon from paralysis.',
    ),
    'liquid_ooze': AbilityDefinition(
      id: 'liquid_ooze',
      name: 'Liquid Ooze',
      description: 'Oozing liquid damages foes using HP-draining moves instead of healing them.',
    ),
    'magic_guard': AbilityDefinition(
      id: 'magic_guard',
      name: 'Magic Guard',
      description: 'The Pokémon only takes damage from direct attacks, ignoring status, weather, and recoil.',
    ),
    'magnet_pull': AbilityDefinition(
      id: 'magnet_pull',
      name: 'Magnet Pull',
      description: 'Traps opposing Steel-type Pokémon in battle.',
    ),
    'marvel_scale': AbilityDefinition(
      id: 'marvel_scale',
      name: 'Marvel Scale',
      description: 'Boosts Defense by 50% if the Pokémon has a status condition.',
    ),
    'mold_breaker': AbilityDefinition(
      id: 'mold_breaker',
      name: 'Mold Breaker',
      description: 'Moves ignore defensive Abilities on the target (like Levitate or Sturdy).',
    ),
    'moxie': AbilityDefinition(
      id: 'moxie',
      name: 'Moxie',
      description: 'Boosts Attack by 1 stage after knocking out any Pokémon.',
    ),
    'multiscale': AbilityDefinition(
      id: 'multiscale',
      name: 'Multiscale',
      description: 'Halves damage taken from attacks when HP is completely full.',
    ),
    'natural_cure': AbilityDefinition(
      id: 'natural_cure',
      name: 'Natural Cure',
      description: 'All status conditions heal when the Pokémon switches out or battle ends.',
    ),
    'no_guard': AbilityDefinition(
      id: 'no_guard',
      name: 'No Guard',
      description: 'Ensures attacks by or against the Pokémon never miss.',
    ),
    'oblivious': AbilityDefinition(
      id: 'oblivious',
      name: 'Oblivious',
      description: 'Keeps the Pokémon from becoming infatuated or taunted.',
    ),
    'overcoat': AbilityDefinition(
      id: 'overcoat',
      name: 'Overcoat',
      description: 'Protects the Pokémon from hail/sandstorm damage and powder moves.',
    ),
    'overgrow': AbilityDefinition(
      id: 'overgrow',
      name: 'Overgrow',
      description: 'Powers up Grass-type moves by 50% when HP drops to 1/3 or below.',
    ),
    'own_tempo': AbilityDefinition(
      id: 'own_tempo',
      name: 'Own Tempo',
      description: 'Prevents the Pokémon from becoming confused.',
    ),
    'pickup': AbilityDefinition(
      id: 'pickup',
      name: 'Pickup',
      description: 'May scavenge useful items; carries no direct battle modifier.',
    ),
    'poison_point': AbilityDefinition(
      id: 'poison_point',
      name: 'Poison Point',
      description: 'Contact with the Pokémon may poison the attacker.',
    ),
    'poison_touch': AbilityDefinition(
      id: 'poison_touch',
      name: 'Poison Touch',
      description: 'May poison a target when the Pokémon makes contact.',
    ),
    'pressure': AbilityDefinition(
      id: 'pressure',
      name: 'Pressure',
      description: 'By putting pressure on the foe, raises their PP usage by +1.',
    ),
    'quick_feet': AbilityDefinition(
      id: 'quick_feet',
      name: 'Quick Feet',
      description: 'Boosts Speed by 50% if the Pokémon has a status condition.',
    ),
    'rain_dish': AbilityDefinition(
      id: 'rain_dish',
      name: 'Rain Dish',
      description: 'Gradually regains 1/16 max HP each turn while it is raining.',
    ),
    'rattled': AbilityDefinition(
      id: 'rattled',
      name: 'Rattled',
      description: 'Raises Speed by 1 stage if hit by a Bug-, Ghost-, or Dark-type move.',
    ),
    'reckless': AbilityDefinition(
      id: 'reckless',
      name: 'Reckless',
      description: 'Powers up moves that have recoil damage by 20%.',
    ),
    'regenerator': AbilityDefinition(
      id: 'regenerator',
      name: 'Regenerator',
      description: 'Restores 1/3 of max HP when withdrawn from battle.',
    ),
    'rivalry': AbilityDefinition(
      id: 'rivalry',
      name: 'Rivalry',
      description: 'Deals 25% more damage to foes that share a type.',
    ),
    'rock_head': AbilityDefinition(
      id: 'rock_head',
      name: 'Rock Head',
      description: 'Protects the Pokémon from recoil damage.',
    ),
    'run_away': AbilityDefinition(
      id: 'run_away',
      name: 'Run Away',
      description: 'Enables a sure getaway from wild Pokémon.',
    ),
    'sand_force': AbilityDefinition(
      id: 'sand_force',
      name: 'Sand Force',
      description: 'Boosts Rock-, Ground-, and Steel-type moves by 30% in a sandstorm.',
    ),
    'sand_rush': AbilityDefinition(
      id: 'sand_rush',
      name: 'Sand Rush',
      description: 'Doubles the Pokémon\'s Speed stat in a sandstorm.',
    ),
    'sand_veil': AbilityDefinition(
      id: 'sand_veil',
      name: 'Sand Veil',
      description: 'Boosts evasion in a sandstorm and gives immunity to sandstorm damage.',
    ),
    'scrappy': AbilityDefinition(
      id: 'scrappy',
      name: 'Scrappy',
      description: 'Normal- and Fighting-type moves can hit Ghost-type Pokémon.',
    ),
    'serene_grace': AbilityDefinition(
      id: 'serene_grace',
      name: 'Serene Grace',
      description: 'Doubles the chance of moves\' additional effects occurring.',
    ),
    'shed_skin': AbilityDefinition(
      id: 'shed_skin',
      name: 'Shed Skin',
      description: 'Has a 30% chance to cure status conditions at the end of each turn.',
    ),
    'sheer_force': AbilityDefinition(
      id: 'sheer_force',
      name: 'Sheer Force',
      description: 'Removes secondary move effects to boost power by 30%.',
    ),
    'shell_armor': AbilityDefinition(
      id: 'shell_armor',
      name: 'Shell Armor',
      description: 'A hard shell protects the Pokémon from critical hits.',
    ),
    'shield_dust': AbilityDefinition(
      id: 'shield_dust',
      name: 'Shield Dust',
      description: 'Blocks the additional effects of attacks taken.',
    ),
    'skill_link': AbilityDefinition(
      id: 'skill_link',
      name: 'Skill Link',
      description: 'Multi-hit moves always strike the maximum number of times.',
    ),
    'sniper': AbilityDefinition(
      id: 'sniper',
      name: 'Sniper',
      description: 'Powers up critical hits to deal 50% more damage.',
    ),
    'snow_cloak': AbilityDefinition(
      id: 'snow_cloak',
      name: 'Snow Cloak',
      description: 'Boosts evasion in a hailstorm and gives immunity to hail damage.',
    ),
    'solar_power': AbilityDefinition(
      id: 'solar_power',
      name: 'Solar Power',
      description: 'In harsh sunlight, boosts Sp. Atk by 50% at the cost of 1/8 max HP per turn.',
    ),
    'soundproof': AbilityDefinition(
      id: 'soundproof',
      name: 'Soundproof',
      description: 'Gives full immunity to all sound-based moves.',
    ),
    'static': AbilityDefinition(
      id: 'static',
      name: 'Static',
      description: 'The Pokémon is charged with static electricity; contact may paralyze.',
    ),
    'steadfast': AbilityDefinition(
      id: 'steadfast',
      name: 'Steadfast',
      description: 'Raises Speed by 1 stage each time the Pokémon flinches.',
    ),
    'stench': AbilityDefinition(
      id: 'stench',
      name: 'Stench',
      description: 'Adds a 10% chance to make the target flinch when attacking.',
    ),
    'sticky_hold': AbilityDefinition(
      id: 'sticky_hold',
      name: 'Sticky Hold',
      description: 'Protects the Pokémon\'s held item from being knocked off or stolen.',
    ),
    'sturdy': AbilityDefinition(
      id: 'sturdy',
      name: 'Sturdy',
      description: 'Cannot be knocked out with one hit when at full HP (survives with 1 HP) and blocks OHKO moves.',
    ),
    'swarm': AbilityDefinition(
      id: 'swarm',
      name: 'Swarm',
      description: 'Powers up Bug-type moves by 50% when HP drops to 1/3 or below.',
    ),
    'swift_swim': AbilityDefinition(
      id: 'swift_swim',
      name: 'Swift Swim',
      description: 'Doubles the Pokémon\'s Speed stat in rain.',
    ),
    'synchronize': AbilityDefinition(
      id: 'synchronize',
      name: 'Synchronize',
      description: 'Passes a burn, poison, or paralysis back to the Pokémon that inflicted it.',
    ),
    'tangled_feet': AbilityDefinition(
      id: 'tangled_feet',
      name: 'Tangled Feet',
      description: 'Raises evasion noticeably while the Pokémon is confused.',
    ),
    'technician': AbilityDefinition(
      id: 'technician',
      name: 'Technician',
      description: 'Powers up moves with a base power of 60 or less by 50%.',
    ),
    'thick_fat': AbilityDefinition(
      id: 'thick_fat',
      name: 'Thick Fat',
      description: 'Halves the damage taken from Fire- and Ice-type moves.',
    ),
    'tinted_lens': AbilityDefinition(
      id: 'tinted_lens',
      name: 'Tinted Lens',
      description: 'Doubles the power of "not very effective" moves.',
    ),
    'torrent': AbilityDefinition(
      id: 'torrent',
      name: 'Torrent',
      description: 'Powers up Water-type moves by 50% when HP drops to 1/3 or below.',
    ),
    'trace': AbilityDefinition(
      id: 'trace',
      name: 'Trace',
      description: 'Copies the opposing Pokémon\'s Ability when entering battle.',
    ),
    'unaware': AbilityDefinition(
      id: 'unaware',
      name: 'Unaware',
      description: 'Ignores the opposing Pokémon\'s stat changes when taking or dealing damage.',
    ),
    'unburden': AbilityDefinition(
      id: 'unburden',
      name: 'Unburden',
      description: 'Doubles Speed once its held item is consumed or lost.',
    ),
    'unnerve': AbilityDefinition(
      id: 'unnerve',
      name: 'Unnerve',
      description: 'Unnerves the foe, preventing them from eating held Berries.',
    ),
    'vital_spirit': AbilityDefinition(
      id: 'vital_spirit',
      name: 'Vital Spirit',
      description: 'Prevents the Pokémon from falling asleep.',
    ),
    'volt_absorb': AbilityDefinition(
      id: 'volt_absorb',
      name: 'Volt Absorb',
      description: 'Restores up to 1/4 max HP when hit by Electric-type moves instead of taking damage.',
    ),
    'water_absorb': AbilityDefinition(
      id: 'water_absorb',
      name: 'Water Absorb',
      description: 'Restores up to 1/4 max HP when hit by Water-type moves instead of taking damage.',
    ),
    'water_veil': AbilityDefinition(
      id: 'water_veil',
      name: 'Water Veil',
      description: 'Its veil of water prevents the Pokémon from getting a burn.',
    ),
    'weak_armor': AbilityDefinition(
      id: 'weak_armor',
      name: 'Weak Armor',
      description: 'Physical hits lower Defense by 1 stage and raise Speed by 1 stage.',
    ),
    'wonder_skin': AbilityDefinition(
      id: 'wonder_skin',
      name: 'Wonder Skin',
      description: 'Lowers the accuracy of status moves targeting this Pokémon to 50%.',
    ),
  };

  static AbilityDefinition? byId(String? id) =>
      id == null ? null : all[id];

  static String nameOf(String? id) => all[id]?.name ?? (id ?? 'None');
}
