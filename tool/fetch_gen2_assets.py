#!/usr/bin/env python3
"""Fetch Gen 2 (#161-#251) Gen 5 animated GIF sprites, MP3 cries, and generate gen2_species_data.dart."""

from concurrent.futures import ThreadPoolExecutor, as_completed
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SPRITE_FRONT = ROOT / "assets/sprites/front"
SPRITE_BACK = ROOT / "assets/sprites/back"
SPRITE_SHINY_FRONT = ROOT / "assets/sprites/shiny_front"
SPRITE_SHINY_BACK = ROOT / "assets/sprites/shiny_back"
CRIES_DIR = ROOT / "assets/audio/cries"
CACHE_DIR = Path("/tmp/pocket_bump_gen2_cache")
CACHE_DIR.mkdir(parents=True, exist_ok=True)

USER_AGENT = "PocketBump/1.0 (+https://github.com/coderjdx/pocket-bump)"

# Extra move IDs being added in Phase 2 alongside existing PokedexDatabase.moves
NEW_GEN2_MOVES = {
    "aeroblast",
    "sacred_fire",
    "morning_sun",
    "milk_drink",
    "heal_bell",
    "pain_split",
    "hidden_power",
    "return_move",
    "frustration",
    "steel_wing",
    "octazooka",
    "triple_kick",
    "present",
    "spider_web",
    "sweet_kiss",
    "cotton_spore",
    "attract",
}

NEW_GEN2_ABILITIES = {
    "sand_stream",
    "huge_power",
    "shadow_tag",
    "magma_armor",
    "suction_cups",
    "magic_bounce",
    "sap_sipper",
    "prankster",
    "super_luck",
}

DISPLAY_NAME_OVERRIDES = {
    "ho-oh": "Ho-Oh",
    "porygon2": "Porygon2",
}

POKEAPI_TO_OUR_MOVE = {
    "return": "return_move",
    "faint-attack": "feint_attack",
    "vice-grip": "vise_grip",
    "self-destruct": "self_destruct",
    "soft-boiled": "soft_boiled",
    "hi-jump-kick": "high_jump_kick",
    "smelling-salts": "smelling_salts",
    "will-o-wisp": "will_o_wisp",
    "double-edge": "double_edge",
    "mud-slap": "mud_slap",
    "x-scissor": "x_scissor",
    "u-turn": "bug_bite",
    "roar-of-time": "dragon_pulse",
    "conversion-2": "conversion_2",
}

ABILITY_FALLBACKS = {
    "stench": "stench",
    "sand_stream": "sand_stream",
    "drizzle": "drizzle",
    "huge_power": "huge_power",
    "pure_power": "huge_power",
    "shadow_tag": "shadow_tag",
    "magma_armor": "magma_armor",
    "suction_cups": "suction_cups",
    "magic_bounce": "magic_bounce",
    "sap_sipper": "sap_sipper",
    "prankster": "prankster",
    "super_luck": "super_luck",
    "moody": "simple",
    "pickpocket": "frisk",
    "leaf_guard": "leaf_guard",
    "truant": "own_tempo",
    "hustle": "hustle",
    "wonder_skin": "wonder_skin",
    "magic_guard": "magic_guard",
    "healer": "healer",
    "skill_link": "skill_link",
    "moody": "own_tempo",
    "analytic": "analytic",
    "tangled_feet": "tangled_feet",
    "water_veil": "water_veil",
    "sand_veil": "sand_veil",
    "rattled": "rattled",
    "regenerator": "regenerator",
    "multiscale": "multiscale",
    "harvest": "harvest",
    "sheer_force": "sheer_force",
    "unaware": "unaware",
    "moxie": "moxie",
    "contrary": "contrary",
    "speed_boost": "speed_boost",
    "natural_cure": "natural_cure",
    "serene_grace": "serene_grace",
    "technician": "technician",
    "filter": "filter",
    "unnerve": "unnerve",
    "friend_guard": "friend_guard",
    "overcoat": "overcoat",
    "immunity": "immunity",
    "telepathy": "synchronize",
    "plus": "static",
    "minus": "static",
    "drizzle": "drizzle",
}

SPECIAL_LEARNSETS = {
    201: [(1, "hidden_power"), (10, "psybeam"), (20, "ancient_power")],
    202: [
        (1, "counter"),
        (1, "mirror_coat"),
        (1, "safeguard"),
        (1, "destiny_bond"),
    ],
    235: [
        (1, "tackle"),
        (1, "false_swipe"),
        (11, "spore"),
        (21, "encore"),
        (31, "recover"),
        (41, "swords_dance"),
        (51, "baton_pass"),
        (61, "extreme_speed"),
    ],
}

# Clean level-up evolutions for 161..251
LEVEL_EVOLUTIONS = {
    161: (15, 162),  # Sentret -> Furret
    163: (20, 164),  # Hoothoot -> Noctowl
    165: (18, 166),  # Ledyba -> Ledian
    167: (22, 168),  # Spinarak -> Ariados
    170: (27, 171),  # Chinchou -> Lanturn
    177: (25, 178),  # Natu -> Xatu
    179: (15, 180),  # Mareep -> Flaaffy
    180: (30, 181),  # Flaaffy -> Ampharos
    183: (18, 184),  # Marill -> Azumarill
    187: (18, 188),  # Hoppip -> Skiploom
    188: (27, 189),  # Skiploom -> Jumpluff
    194: (20, 195),  # Wooper -> Quagsire
    204: (31, 205),  # Pineco -> Forretress
    209: (23, 210),  # Snubbull -> Granbull
    216: (30, 217),  # Teddiursa -> Ursaring
    218: (38, 219),  # Slugma -> Magcargo
    220: (33, 221),  # Swinub -> Piloswine
    223: (25, 224),  # Remoraid -> Octillery
    228: (24, 229),  # Houndour -> Houndoom
    231: (25, 232),  # Phanpy -> Donphan
    238: (30, 124),  # Smoochum -> Jynx
    239: (30, 125),  # Elekid -> Electabuzz
    240: (30, 126),  # Magby -> Magmar
    246: (30, 247),  # Larvitar -> Pupitar
    247: (55, 248),  # Pupitar -> Tyranitar
}

EVOLUTION_STAGE_OVERRIDES = {
    # Babies (stage 1)
    172: 1, 173: 1, 174: 1, 175: 1, 236: 1, 238: 1, 239: 1, 240: 1,
    # Evos of Gen 1 / Babies
    169: 3,  # Crobat
    176: 2,  # Togetic
    182: 3,  # Bellossom
    184: 2,  # Azumarill (Baby Azurill is Gen 3, treat Marill 1 / Azumarill 2)
    186: 3,  # Politoed
    189: 3,  # Jumpluff
    196: 2,  # Espeon
    197: 2,  # Umbreon
    199: 2,  # Slowking
    208: 2,  # Steelix
    212: 2,  # Scizor
    230: 3,  # Kingdra
    233: 2,  # Porygon2
    237: 2,  # Hitmontop
    242: 2,  # Blissey
    181: 3,  # Ampharos
    248: 3,  # Tyranitar
    180: 2,  # Flaaffy
    188: 2,  # Skiploom
    247: 2,  # Pupitar
    # Standard stage 2s
    162: 2, 164: 2, 166: 2, 168: 2, 171: 2, 178: 2, 192: 2, 195: 2,
    205: 2, 210: 2, 217: 2, 219: 2, 221: 2, 224: 2, 229: 2, 232: 2,
}

BABY_IDS = {172, 173, 174, 175, 236, 238, 239, 240}
PSEUDO_IDS = {246, 247, 248}
LEGENDARY_IDS = {243, 244, 245, 249, 250}
MYTHICAL_IDS = {251}
EVOLVED_KANTO_LINE_SECOND_STAGES = {169, 182, 186, 196, 197, 199, 208, 212, 230, 233, 242}


def fetch_bytes(url: str, retries: int = 3) -> bytes:
    last_err = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=20) as resp:
                return resp.read()
        except Exception as e:
            last_err = e
            time.sleep(0.4 * (attempt + 1))
    raise RuntimeError(f"Failed to fetch {url}: {last_err}")


def fetch_json_cached(url: str, cache_name: str) -> dict:
    cache_path = CACHE_DIR / cache_name
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))
    data = json.loads(fetch_bytes(url).decode("utf-8"))
    cache_path.write_text(json.dumps(data), encoding="utf-8")
    return data


def ensure_file(url: str, dest: Path, validator):
    if dest.exists() and validator(dest.read_bytes()):
        return "cached"
    raw = fetch_bytes(url)
    if not validator(raw):
        raise ValueError(f"Invalid payload from {url} -> {dest}")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    return "downloaded"


def is_valid_gif(raw: bytes) -> bool:
    return len(raw) > 100 and (raw.startswith(b"GIF87a") or raw.startswith(b"GIF89a"))


def is_valid_mp3(raw: bytes) -> bool:
    return len(raw) > 1000


def parse_existing_moves() -> set:
    txt = (ROOT / "lib/services/pokedex_database.dart").read_text(encoding="utf-8")
    return set(re.findall(r"'([a-z0-9_]+)':\s*Move\(", txt)) | NEW_GEN2_MOVES


def parse_existing_abilities() -> set:
    txt = (ROOT / "lib/models/ability.dart").read_text(encoding="utf-8")
    return set(re.findall(r"id:\s*'([a-z0-9_]+)'", txt)) | NEW_GEN2_ABILITIES


def normalize_ability(raw_slug: str, valid_abilities: set) -> str:
    cand = raw_slug.replace("-", "_")
    if cand in valid_abilities:
        return cand
    mapped = ABILITY_FALLBACKS.get(cand)
    if mapped and mapped in valid_abilities:
        return mapped
    return "inner_focus"


def normalize_move(raw_slug: str, valid_moves: set):
    if raw_slug in POKEAPI_TO_OUR_MOVE:
        cand = POKEAPI_TO_OUR_MOVE[raw_slug]
        return cand if cand in valid_moves else None
    cand = raw_slug.replace("-", "_")
    return cand if cand in valid_moves else None


def format_display_name(slug: str, spec_json: dict) -> str:
    if slug in DISPLAY_NAME_OVERRIDES:
        return DISPLAY_NAME_OVERRIDES[slug]
    for n in spec_json.get("names", []):
        if n.get("language", {}).get("name") == "en":
            return n["name"]
    return slug.replace("-", " ").title()


def showdown_slug(pokeapi_slug: str) -> str:
    return re.sub(r"[^a-z0-9]", "", pokeapi_slug.lower())


def min_encounter_level_for(sid: int, stage: int) -> int:
    if sid in LEVEL_EVOLUTIONS:
        # base forms
        if sid in {246}:
            return 20
        return 2
    if stage == 1:
        return 2
    for pre_id, (lvl, target_id) in LEVEL_EVOLUTIONS.items():
        if target_id == sid:
            return lvl
    if sid in LEGENDARY_IDS or sid in MYTHICAL_IDS:
        return 50
    if sid == 208 or sid == 212 or sid == 230 or sid == 233:
        return 30
    if sid in {169, 182, 186, 196, 197, 199, 242}:
        return 26
    return 18


def build_evolution_rules_expr(sid: int) -> str:
    if sid == 172:
        return "[const EvolutionRule(targetSpeciesId: 25, minFriendship: 220)]"
    if sid == 173:
        return "[const EvolutionRule(targetSpeciesId: 35, minFriendship: 220)]"
    if sid == 174:
        return "[const EvolutionRule(targetSpeciesId: 39, minFriendship: 220)]"
    if sid == 175:
        return "[const EvolutionRule(targetSpeciesId: 176, minFriendship: 220)]"
    if sid == 236:
        return (
            "[\n"
            "        const EvolutionRule(targetSpeciesId: 106, minLevel: 20, statCompare: EvolutionStatCompare.atkGreaterThanDef),\n"
            "        const EvolutionRule(targetSpeciesId: 107, minLevel: 20, statCompare: EvolutionStatCompare.defGreaterThanAtk),\n"
            "        const EvolutionRule(targetSpeciesId: 237, minLevel: 20, statCompare: EvolutionStatCompare.atkEqualsDef),\n"
            "      ]"
        )
    return "const []"


def main():
    valid_moves = parse_existing_moves()
    valid_abilities = parse_existing_abilities()
    print(f"Valid moves: {len(valid_moves)}, Valid abilities: {len(valid_abilities)}")

    ids = list(range(161, 252))
    poke_data = {}
    species_meta = {}

    print("Fetching PokeAPI metadata for #161-#251...")
    with ThreadPoolExecutor(max_workers=12) as ex:
        fut_p = {
            ex.submit(fetch_json_cached, f"https://pokeapi.co/api/v2/pokemon/{sid}", f"pokemon_{sid}.json"): sid
            for sid in ids
        }
        fut_s = {
            ex.submit(fetch_json_cached, f"https://pokeapi.co/api/v2/pokemon-species/{sid}", f"species_{sid}.json"): sid
            for sid in ids
        }
        for f in as_completed(fut_p):
            sid = fut_p[f]
            poke_data[sid] = f.result()
        for f in as_completed(fut_s):
            sid = fut_s[f]
            species_meta[sid] = f.result()

    print("Downloading 364 sprites and 91 cries...")
    tasks = []
    with ThreadPoolExecutor(max_workers=12) as ex:
        for sid in ids:
            base = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated"
            tasks.append(ex.submit(ensure_file, f"{base}/{sid}.gif", SPRITE_FRONT / f"{sid}.gif", is_valid_gif))
            tasks.append(ex.submit(ensure_file, f"{base}/back/{sid}.gif", SPRITE_BACK / f"{sid}.gif", is_valid_gif))
            tasks.append(ex.submit(ensure_file, f"{base}/shiny/{sid}.gif", SPRITE_SHINY_FRONT / f"{sid}.gif", is_valid_gif))
            tasks.append(ex.submit(ensure_file, f"{base}/back/shiny/{sid}.gif", SPRITE_SHINY_BACK / f"{sid}.gif", is_valid_gif))

            cry_slug = showdown_slug(poke_data[sid]["name"])
            tasks.append(
                ex.submit(
                    ensure_file,
                    f"https://play.pokemonshowdown.com/audio/cries/{cry_slug}.mp3",
                    CRIES_DIR / f"{sid}.mp3",
                    is_valid_mp3,
                )
            )
        dl_count = 0
        for t in as_completed(tasks):
            if t.result() == "downloaded":
                dl_count += 1
        print(f"Asset sync done ({dl_count} newly downloaded, {len(tasks) - dl_count} already cached).")

    # Verify asset counts
    for folder in (SPRITE_FRONT, SPRITE_BACK, SPRITE_SHINY_FRONT, SPRITE_SHINY_BACK, CRIES_DIR):
        cnt = len([p for p in folder.iterdir() if p.is_file()])
        print(f"  {folder.relative_to(ROOT)}: {cnt} files")
        assert cnt == 278, f"Expected 278 files in {folder}, found {cnt}"

    # Generate lib/services/gen2_species_data.dart
    lines = [
        "import '../models/pokemon_species.dart';",
        "import '../models/pokemon_type.dart';",
        "",
        "/// Complete Gen 2 (Johto) species definitions (#161 Sentret to #251 Celebi).",
        "final Map<int, PokemonSpecies> gen2SpeciesData = {",
    ]

    for sid in ids:
        p = poke_data[sid]
        sp = species_meta[sid]
        name = format_display_name(p["name"], sp)

        # Types (modern Fairy types included directly by PokeAPI pokemon/ endpoint)
        type_names = [t["type"]["name"] for t in sorted(p["types"], key=lambda x: x["slot"])]
        types_expr = ", ".join(f"PokemonType.{tn}" for tn in type_names)

        stats = {st["stat"]["name"]: st["base_stat"] for st in p["stats"]}
        hp = stats["hp"]
        atk = stats["attack"]
        def_ = stats["defense"]
        spa = stats["special-attack"]
        spd = stats["special-defense"]
        spe = stats["speed"]

        catch_rate = sp["capture_rate"]
        base_exp = p.get("base_experience") or 64
        height_m = round(p["height"] / 10.0, 2)
        weight_kg = round(p["weight"] / 10.0, 2)

        stage = EVOLUTION_STAGE_OVERRIDES.get(sid, 1)
        is_pseudo = sid in PSEUDO_IDS
        is_leg = sid in LEGENDARY_IDS
        is_myth = sid in MYTHICAL_IDS
        allow_wild = not (sid in BABY_IDS or sid == 176 or is_leg or is_myth)
        min_lvl = min_encounter_level_for(sid, stage)

        rarity_override = None
        if sid in EVOLVED_KANTO_LINE_SECOND_STAGES and stage == 2 and not is_pseudo:
            rarity_override = "PokemonRarity.uncommon"
        if sid in {192, 198, 200, 202, 203, 206, 207, 211, 213, 214, 215, 222, 225, 226, 227, 234, 235, 241}:
            rarity_override = "PokemonRarity.uncommon"
        if sid in {186, 199, 208, 212, 230, 233, 242}:
            rarity_override = "PokemonRarity.rare"

        # Abilities
        ab_list = sorted(p["abilities"], key=lambda a: (a["is_hidden"], a["slot"]))
        slot1 = None
        slot2 = None
        hidden = None
        for a in ab_list:
            norm = normalize_ability(a["ability"]["name"], valid_abilities)
            if a["is_hidden"]:
                hidden = norm
            elif slot1 is None:
                slot1 = norm
            elif slot2 is None and norm != slot1:
                slot2 = norm
        if slot1 is None:
            slot1 = "run_away"

        # Learnset (prefer black-white / heartgold-soulsilver level-up moves)
        if sid in SPECIAL_LEARNSETS:
            learnset = SPECIAL_LEARNSETS[sid]
        else:
            raw_moves = []
            seen_pair = set()
            for mv in p["moves"]:
                our_mv = normalize_move(mv["move"]["name"], valid_moves)
                if not our_mv:
                    continue
                chosen_lvl = None
                for vg in ("black-white", "heartgold-soulsilver", "platinum", "diamond-pearl", "emerald"):
                    for det in mv["version_group_details"]:
                        if (
                            det["version_group"]["name"] == vg
                            and det["move_learn_method"]["name"] == "level-up"
                        ):
                            chosen_lvl = max(1, det["level_learned_at"])
                            break
                    if chosen_lvl is not None:
                        break
                if chosen_lvl is not None:
                    key = (chosen_lvl, our_mv)
                    if key not in seen_pair:
                        seen_pair.add(key)
                        raw_moves.append(key)
            raw_moves.sort(key=lambda x: (x[0], x[1]))
            # Guarantee at least a Lv.1 move
            if not raw_moves or raw_moves[0][0] > 1:
                raw_moves.insert(0, (1, "tackle"))
            learnset = raw_moves[:18]

        # Ensure key canon signature moves are present
        if sid == 249 and all(m != "aeroblast" for _, m in learnset):
            learnset.append((43, "aeroblast"))
        if sid == 250 and all(m != "sacred_fire" for _, m in learnset):
            learnset.append((43, "sacred_fire"))
        if sid == 251 and all(m != "heal_bell" for _, m in learnset):
            learnset.append((1, "heal_bell"))
        if sid == 225 and all(m != "present" for _, m in learnset):
            learnset.append((1, "present"))
        if sid == 241 and all(m != "milk_drink" for _, m in learnset):
            learnset.append((15, "milk_drink"))
        learnset.sort(key=lambda x: (x[0], x[1]))

        evo_lvl, evo_target = LEVEL_EVOLUTIONS.get(sid, (None, None))
        evo_rules_expr = build_evolution_rules_expr(sid)

        safe_name = name.replace("'", "\\'")
        lines.append(f"  {sid}: const PokemonSpecies(")
        lines.append(f"    id: {sid},")
        lines.append(f"    name: '{safe_name}',")
        lines.append(f"    types: [{types_expr}],")
        lines.append(f"    baseHp: {hp},")
        lines.append(f"    baseAtk: {atk},")
        lines.append(f"    baseDef: {def_},")
        lines.append(f"    baseSpA: {spa},")
        lines.append(f"    baseSpD: {spd},")
        lines.append(f"    baseSpe: {spe},")
        lines.append(f"    baseCatchRate: {catch_rate},")
        lines.append(f"    baseExp: {base_exp},")
        lines.append(f"    heightMeters: {height_m},")
        lines.append(f"    weightKg: {weight_kg},")
        lines.append(f"    evolutionStage: {stage},")
        if is_pseudo:
            lines.append("    isPseudoLegendary: true,")
        if is_leg:
            lines.append("    isLegendary: true,")
        if is_myth:
            lines.append("    isMythical: true,")
        if rarity_override:
            lines.append(f"    rarityOverride: {rarity_override},")
        lines.append(f"    minEncounterLevel: {min_lvl},")
        if not allow_wild:
            lines.append("    allowWildEncounter: false,")
        if evo_lvl is not None and evo_target is not None:
            lines.append(f"    evolutionLevel: {evo_lvl},")
            lines.append(f"    evolutionSpeciesId: {evo_target},")
        if evo_rules_expr != "const []":
            lines.append(f"    evolutionRules: {evo_rules_expr},")
        lines.append(f"    abilitySlot1Id: '{slot1}',")
        if slot2:
            lines.append(f"    abilitySlot2Id: '{slot2}',")
        if hidden:
            lines.append(f"    hiddenAbilityId: '{hidden}',")
        lines.append("    learnset: [")
        for lv, mv_id in learnset:
            lines.append(f"      LearnedMove({lv}, '{mv_id}'),")
        lines.append("    ],")
        lines.append("  ),")

    lines.append("};")
    out_path = ROOT / "lib/services/gen2_species_data.dart"
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out_path} ({len(ids)} species)")


if __name__ == "__main__":
    main()
