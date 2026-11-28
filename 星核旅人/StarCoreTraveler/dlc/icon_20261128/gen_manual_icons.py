# -*- coding: utf-8 -*-
"""Generate the 12x12 manual mechanic icons for 星核旅人.

The pause-page manual used to borrow keycaps and the 20x20 sun/moon art for
its left column, so the glyph did not describe the mechanism.  This script
draws one dedicated 12x12 icon per registry row with the established palette
(gold / cyan / purple / stone), a 1 px ink outline and no background plate.

Every icon is authored as a 12-row pixel map, then written as:
    assets/ui/mechanic_icons/<id>_12.png

Run from the project root:
    D:/minic/envs/2024212971/python.exe dlc/icon_20261128/gen_manual_icons.py

It also writes review sheets under screenshots/manual_icons_20261128/.
No third-party pixels are used; the maps are original.
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets/ui/mechanic_icons"
SHEET_DIR = ROOT / "screenshots/manual_icons_20261128"

# Palette already used by the game (dlc/PRESENTATION_SYSTEM.md).
PALETTE = {
    ".": None,
    "K": (13, 20, 26, 255),      # ink outline
    "G": (244, 205, 99, 255),    # gold
    "g": (168, 123, 45, 255),    # gold shadow
    "H": (255, 230, 161, 255),   # gold highlight
    "C": (95, 225, 230, 255),    # cyan
    "c": (42, 125, 132, 255),    # cyan shadow
    "T": (176, 248, 249, 255),   # cyan highlight
    "P": (185, 140, 255, 255),   # purple
    "p": (106, 74, 158, 255),    # purple shadow
    "Q": (217, 194, 255, 255),   # purple highlight
    "S": (76, 67, 73, 255),      # stone
    "s": (43, 40, 46, 255),      # deep recess
    "L": (139, 128, 121, 255),   # stone light
    "W": (255, 252, 240, 255),   # warm white / arrow
    "R": (217, 87, 87, 255),     # life red
    "r": (255, 123, 123, 255),   # life highlight
}

ORDER = [
    "polarity",
    "gate",
    "rune",
    "bay",
    "checkpoint",
    "guard",
    "inversion",
    "bridge",
    "core_delivery",
    "loom_node",
    "fire",
    "gear",
    "wisp",
    "mirror",
    "lives",
]

# 12 columns x 12 rows each.  "K" is the 1 px dark outline.  Shapes keep at
# least one transparent pixel around the artwork unless the silhouette needs
# the full 12 px.
ICONS = {
    "polarity": """
............
....KKKK....
..KKGGCCKK..
.KGHGGCCCCK.
.KGGGGCCCTK.
KGGGGGCCCCCK
KGGGGGCCCCCK
.KGGGGCCCTK.
.KGGGGCCCCK.
..KKGGCCKK..
....KKKK....
............
""",
    "gate": """
............
...KKKKKK...
..KLLLLLLK..
..KGGLLCCK..
.KLLLLLLLLK.
.KLKKKKKKLK.
.KLKssssKLK.
.KLKssssKLK.
.KLKssssKLK.
.KLKssssKLK.
.KKKKKKKKKK.
............
""",
    "rune": """
............
..KKKKKKKK..
.KLLLLLLLLK.
.KLCSSSSCLK.
.KLSCSSCSLK.
.KLSSCCSSK..
.KLSSCCSSK..
.KLSSCCSSK..
.KLSCSSCSLK.
.KLCSSSSCLK.
.KKKKKKKKKK.
............
""",
    "bay": """
............
............
..KKKKKKKK..
.KLLKssKLLK.
.KLLKssKLLK.
.KLLKssKLLK.
.KLLKccKLLK.
.KLLKKKKLLK.
.KLLLLLLLLK.
.KLSSSSSSLK.
.KKKKKKKKKK.
............
""",
    "checkpoint": """
..HH........
..GG........
..LKKKKKK...
..LKCCCCK...
..LKCCCCK...
..LKCCCK....
..LKKKK.....
..L.........
..L.........
.KKKK.......
.KLLK.......
.KKKK.......
""",
    "guard": """
.KKK....KKK.
.KLLK..KLLK.
.KLLK..KLLK.
.KLLLKKLLLK.
..KLLLLLLK..
.KLLLLLLLLK.
.KLLCCCCLLK.
.KLLLKKLLLK.
..KLLKKLLK..
...KKKKKK...
............
............
""",
    "inversion": """
............
.KKKKKKKKKK.
GKLLLLLLLLKG
.KPQpPPpQPK.
.KPQpPPpQPK.
.KPQpPPpQPK.
.KPQpPPpQPK.
.KPQpPPpQPK.
.KPQpPPpQPK.
.KPQpPPpQPK.
.KKKKKKKKKK.
............
""",
    "bridge": """
............
............
..KK....KK..
..KL....LK..
..KKKKKKKK..
..KLLLLLLK..
..KLLLLLLK..
..KGGGGGGK..
..KKKKKKKK..
...K....K...
...KK..KK...
............
""",
    "core_delivery": """
............
....KKKK....
..KKGHHGKK..
..KGGGGGGK..
...KKKKKK...
.....WW.....
.....WW.....
...WWWWWW...
..KKKKKKKK..
..KLLccLLK..
..KLLccLLK..
..KKKKKKKK..
""",
    "loom_node": """
....CCCC....
...C....C...
..C......C..
..C.KKKK.C..
..CKQQQQKC..
..CKQPPQKC..
..CKQPPQKC..
..C.KKKK.C..
...C....C...
....CCCC....
............
............
""",
    "fire": """
............
.....K......
....KGK.....
....KGK.....
...KGGGK....
...KGHGK....
..KGGHHGGK..
..KGGHHGGK..
..KGGGGGGK..
...KggggK...
....KKKK....
............
""",
    "gear": """
............
...KK..KK...
..KLLKKLLK..
.KKLLLLLLKK.
.KLLLLLLLLK.
.KLLKKKKLLK.
.KLKKGGKKLK.
.KLKKGGKKLK.
.KLLKKKKLLK.
.KKLLLLLLKK.
..KLLKKLLK..
...KK..KK...
""",
    "wisp": """
............
.....KK.....
....KQQK....
...KQPPQK...
...KPWPPK...
...KPPWPK...
..KPPPPPPK..
..KPPpppPK..
...KPPpPK...
....KPPK....
...KpK......
..Kp........
""",
    "mirror": """
............
...KKKKKK...
..KGGGGGGK..
.KGGGGGGGGK.
.KGCCCCCCGK.
.KGCCWWCCGK.
.KGCCWKWCGK.
.KGCCCCCCGK.
.KGGGGGGGGK.
..KGGGGGGK..
...KKKKKK...
............
""",
    "lives": """
............
..KK..KK....
.KRRKKRRK...
.KRrRRRRK...
KRRrRRRRRK..
KRRRRRRRRK..
.KRRRRRRK...
..KRRRRK....
...KRRK.....
....KK......
............
............
""",
}


def parse_icon(icon_id: str, art: str) -> Image.Image:
    rows = [row for row in art.strip("\n").splitlines()]
    if len(rows) != 12:
        raise ValueError(f"{icon_id}: expected 12 rows, got {len(rows)}")
    image = Image.new("RGBA", (12, 12), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        if len(row) != 12:
            raise ValueError(f"{icon_id}: row {y} has {len(row)} columns")
        for x, char in enumerate(row):
            if char not in PALETTE:
                raise ValueError(f"{icon_id}: unknown palette char {char!r} at {x},{y}")
            color = PALETTE[char]
            if color is not None:
                image.putpixel((x, y), color)
    if not any(char != "." for row in rows for char in row):
        raise ValueError(f"{icon_id}: empty icon")
    return image


def build_sheet(images: dict[str, Image.Image]) -> Image.Image:
    """6x nearest-neighbour review sheet, 5 columns x 3 rows."""
    scale = 6
    cell_w = 12 * scale + 12
    cell_h = 12 * scale + 20
    sheet = Image.new("RGBA", (cell_w * 5, cell_h * 3), (8, 15, 20, 255))
    draw = ImageDraw.Draw(sheet)
    for index, icon_id in enumerate(ORDER):
        image = images[icon_id]
        big = image.resize((12 * scale, 12 * scale), Image.NEAREST)
        x = (index % 5) * cell_w + 6
        y = (index // 5) * cell_h + 6
        sheet.alpha_composite(big, (x, y))
        draw.text((x, y + 12 * scale + 2), icon_id, fill=(220, 230, 230, 255))
    return sheet


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SHEET_DIR, exist_ok=True)
    images: dict[str, Image.Image] = {}
    for icon_id in ORDER:
        image = parse_icon(icon_id, ICONS[icon_id])
        output = OUT_DIR / f"{icon_id}_12.png"
        image.save(output)
        images[icon_id] = image
        print(f"WROTE {output.relative_to(ROOT).as_posix()} 12x12")
    sheet = build_sheet(images)
    sheet_path = SHEET_DIR / "icons_sheet_6x.png"
    sheet.save(sheet_path)
    print(f"WROTE {sheet_path.relative_to(ROOT).as_posix()} {sheet.width}x{sheet.height}")
    print(f"ICON_COUNT {len(images)}")


if __name__ == "__main__":
    main()
