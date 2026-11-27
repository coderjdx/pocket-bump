#!/usr/bin/env python3
"""
Fetches Gen 4/5 Johto Gym Leader, Elite Four, and Neo Team Rocket sprites
from Pokemon Showdown and generates crisp 96x96 Johto Gym Badge pixel art.
"""
import io
import os
import urllib.request
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAINER_DIR = os.path.join(ROOT, "assets", "images", "trainers")
BADGE_DIR = os.path.join(ROOT, "assets", "images", "badges")

TRAINER_SPRITES = {
    "leader_falkner_front.png": "falkner",
    "leader_bugsy_front.png": "bugsy",
    "leader_whitney_front.png": "whitney",
    "leader_morty_front.png": "morty",
    "leader_chuck_front.png": "chuck",
    "leader_jasmine_front.png": "jasmine",
    "leader_pryce_front.png": "pryce",
    "leader_clair_front.png": "clair",
    "e4_will_front.png": "will",
    "e4_karen_front.png": "karen",
    "rocket_proton_front.png": "proton",
    "rocket_petrel_front.png": "petrel",
    "rocket_ariana_front.png": "ariana",
    "rocket_archer_front.png": "archer",
}


def fetch_trainer_sprites():
    os.makedirs(TRAINER_DIR, exist_ok=True)
    for out_name, showdown_slug in TRAINER_SPRITES.items():
        url = f"https://play.pokemonshowdown.com/sprites/trainers/{showdown_slug}.png"
        out_path = os.path.join(TRAINER_DIR, out_name)
        req = urllib.request.Request(
            url, headers={"User-Agent": "Mozilla/5.0"}
        )
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
        im = Image.open(io.BytesIO(raw)).convert("RGBA")
        # Showdown sprites are 80x80; upscale 2x NEAREST to 160x160 to match Kanto E4/Leaders
        im_scaled = im.resize((160, 160), Image.Resampling.NEAREST)
        im_scaled.save(out_path, format="PNG")
        print(f"Saved {out_name} <- {showdown_slug}.png ({im_scaled.size} {im_scaled.mode})")


def render_badge_grid(grid, palette):
    """Renders a 16x16 character grid into a 96x96 RGBA PNG with NEAREST upscaling."""
    assert len(grid) == 16
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = im.load()
    for y, row in enumerate(grid):
        assert len(row) == 16, f"Row {y} len {len(row)} != 16"
        for x, ch in enumerate(row):
            if ch != ".":
                px[x, y] = palette[ch]
    return im.resize((96, 96), Image.Resampling.NEAREST)


BADGES = {
    # 1. Zephyr Badge (Sky-blue & white wing crest)
    "zephyr_badge.png": (
        {
            "K": (28, 44, 72, 255),
            "D": (41, 128, 185, 255),
            "B": (93, 193, 248, 255),
            "L": (180, 232, 255, 255),
            "W": (245, 252, 255, 255),
        },
        [
            "......KKKK......",
            "....KKLLLLKK....",
            "...KLLWWWWLLK...",
            "..KLWWBBBBWWLK..",
            ".KLLBBDDDDDBLLK.",
            ".KLBBDLLLLDBBLK.",
            "KLBBDLWWWWLDBBLK",
            "KLBBDWWWWWWDBBLK",
            "KLBBDWWWWWWDBBLK",
            "KLBBDLWWWWLDBBLK",
            ".KLBBDLLLLDBBLK.",
            ".KLLBBDDDDDBLLK.",
            "..KLWWBBBBWWLK..",
            "...KLLWWWWLLK...",
            "....KKLLLLKK....",
            "......KKKK......",
        ],
    ),
    # 2. Hive Badge (Golden-amber hexagonal ladybug/hive emblem)
    "hive_badge.png": (
        {
            "K": (42, 28, 16, 255),
            "D": (194, 108, 18, 255),
            "G": (244, 180, 32, 255),
            "Y": (255, 230, 109, 255),
            "R": (220, 62, 54, 255),
            "W": (255, 248, 220, 255),
        },
        [
            ".....KKKKKK.....",
            "...KKYYYYYYKK...",
            "..KYYGGGGGGYYK..",
            ".KYGGRRRRRRGGYK.",
            ".KYGRWWKKWWRGYK.",
            "KYGGRKKKKKKRGGYK",
            "KYGGRKKYYKKRGGYK",
            "KYGGRKYGGYKRGGYK",
            "KYGGRKYGGYKRGGYK",
            "KYGGRKKKKKKRGGYK",
            ".KYGGRRRRRRGGYK.",
            ".KYGGDDDDDDGGYK.",
            "..KGGDDDDDDGGK..",
            "...KKDDDDDDKK...",
            ".....KKKKKK.....",
            "................",
        ],
    ),
    # 3. Plain Badge (Rose-cream faceted shield / star cross)
    "plain_badge.png": (
        {
            "K": (72, 40, 52, 255),
            "P": (240, 148, 178, 255),
            "R": (255, 200, 220, 255),
            "C": (255, 240, 232, 255),
            "D": (196, 98, 132, 255),
        },
        [
            "......KKKK......",
            ".....KCCCCK.....",
            "....KCRRRRCK....",
            "....KCRPPPCK....",
            ".KKKKCRPPPCKKKK.",
            "KCCCCPPPPPPCCCCK",
            "KCRPPPPDDPPPPRCK",
            "KCRPPPDDDDPPPRCK",
            "KCRPPPDDDDPPPRCK",
            "KCRPPPPDDPPPPRCK",
            "KCCCCPPPPPPCCCCK",
            ".KKKKDPPPPDKKKK.",
            "....KDPPPPDK....",
            "....KDDDDDDK....",
            ".....KDDDDK.....",
            "......KKKK......",
        ],
    ),
    # 4. Fog Badge (Mystic violet crescent & mist orb)
    "fog_badge.png": (
        {
            "K": (36, 20, 58, 255),
            "D": (106, 56, 168, 255),
            "V": (164, 108, 226, 255),
            "L": (222, 186, 255, 255),
            "C": (118, 226, 240, 255),
        },
        [
            "......KKKK......",
            "....KKLLLLKK....",
            "...KLLVVVVLLK...",
            "..KLVVCCCCVVLK..",
            ".KLVVCCCCCCVVLK.",
            ".KLVCCDDDDCCVLK.",
            "KLVCDDDDDDDDCVLK",
            "KLVCKDDDDDDKCVLK",
            "KLVCKDDVVDDKCVLK",
            "KLVCDDDDDDDDCVLK",
            ".KLVCCDDDDCCVLK.",
            ".KDVVCCCCCCVVDK.",
            "..KDVVCCCCVVDK..",
            "...KDDVVVVDDK...",
            "....KKDDDDKK....",
            "......KKKK......",
        ],
    ),
    # 5. Storm Badge (Crimson-orange martial starburst ring)
    "storm_badge.png": (
        {
            "K": (52, 22, 16, 255),
            "D": (180, 54, 24, 255),
            "O": (244, 118, 42, 255),
            "Y": (255, 208, 72, 255),
            "W": (255, 244, 210, 255),
        },
        [
            ".......KK.......",
            ".....KKWWKK.....",
            "...KKWYYYYWKK...",
            "..KWYYOOOOYYWK..",
            "..KYOOODDOOOYK..",
            ".KYOOOKKKKOOOYK.",
            ".KYODKWWWWKDOYK.",
            "KWYODKWYYWKDOYWK",
            "KWYODKWYYWKDOYWK",
            ".KYODKWWWWKDOYK.",
            ".KYOOOKKKKOOOYK.",
            "..KYOOODDOOOYK..",
            "..KWYYDDDDYYWK..",
            "...KKWDDDDWKK...",
            ".....KKDDKK.....",
            ".......KK.......",
        ],
    ),
    # 6. Mineral Badge (Gleaming silver-steel hexagonal gem)
    "mineral_badge.png": (
        {
            "K": (36, 44, 54, 255),
            "D": (110, 126, 146, 255),
            "S": (182, 198, 216, 255),
            "W": (240, 248, 255, 255),
            "B": (108, 196, 232, 255),
        },
        [
            "....KKKKKKKK....",
            "...KWWWWWWWWK...",
            "..KWWSSSSSSWWK..",
            ".KWSSBBBBBBSSWK.",
            "KWSSBBWWWWBBSSWK",
            "KWSBBWWSSWWBBSWK",
            "KWSBBWSSSSWBBSWK",
            "KWSBBWSSSSWBBSWK",
            "KWSBBWWSSWWBBSWK",
            "KDSBBWWWWWWBBSKD",
            "KDSBBBBBBBBBBSKD",
            ".KDSSDDDDDDSSDK.",
            "..KDDDDDDDDDDK..",
            "...KDDDDDDDDK...",
            "....KKKKKKKK....",
            "................",
        ],
    ),
    # 7. Glacier Badge (Icy cyan diamond crystal)
    "glacier_badge.png": (
        {
            "K": (20, 52, 74, 255),
            "D": (42, 142, 194, 255),
            "C": (112, 224, 248, 255),
            "L": (204, 248, 255, 255),
            "W": (250, 255, 255, 255),
        },
        [
            ".......KK.......",
            "......KWWK......",
            ".....KWLLWK.....",
            "....KWLCCLWK....",
            "...KWLCCCCLWK...",
            "..KWLCCWWCCLWK..",
            ".KWLCCWWWWCCLWK.",
            "KWLCCWWWWWWCCLWK",
            "KDLCCWWWWWWCCLDK",
            ".KDLCCWWWWCCLDK.",
            "..KDLCCDDCCLDK..",
            "...KDLDDDDLDK...",
            "....KDLDDLDK....",
            ".....KDDDDK.....",
            "......KDDK......",
            ".......KK.......",
        ],
    ),
    # 8. Rising Badge (Royal indigo-crimson-gold dragon crest)
    "rising_badge.png": (
        {
            "K": (28, 22, 54, 255),
            "B": (62, 82, 196, 255),
            "C": (116, 146, 248, 255),
            "G": (255, 204, 52, 255),
            "R": (224, 62, 78, 255),
            "W": (255, 246, 210, 255),
        },
        [
            "..KK........KK..",
            ".KGGK..KK..KGGK.",
            ".KGYKKWWWWKKYGK." if False else ".KGWKKGGGGKKWGK.",
            "..KBGGRRRRRGBK..",
            "..KBBGRWWRGBBK..",
            ".KCCBGRRRRRGBCK.",
            ".KCBBRGGGGGRBCLK".replace("L", "C"),
            "KCBBBRGWWGRBBBCK",
            "KCBBBRGWWGRBBBCK",
            ".KCBBGGGGGGGBCK.",
            "..KBBBBBBBBBBK..",
            "..KBBKKBBKKBBK..",
            "...KBK.KK.KBK...",
            "...KK......KK...",
            "................",
            "................",
        ],
    ),
}


def generate_badges():
    os.makedirs(BADGE_DIR, exist_ok=True)
    for fname, (palette, grid) in BADGES.items():
        out_path = os.path.join(BADGE_DIR, fname)
        im = render_badge_grid(grid, palette)
        im.save(out_path, format="PNG")
        print(f"Saved badge {fname} ({im.size} {im.mode})")


if __name__ == "__main__":
    fetch_trainer_sprites()
    generate_badges()
