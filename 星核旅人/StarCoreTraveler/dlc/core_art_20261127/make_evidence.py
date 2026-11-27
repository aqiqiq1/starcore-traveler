"""Build the 4x nearest-neighbour evidence sheets for the 2026-11-27 core pass.

Reads only the project's own generated assets and live 640x360 captures.
Writes into screenshots/core_art_20261127/.
"""

from __future__ import annotations

import os
import shutil
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "screenshots", "core_art_20261127")
CAPTURE = os.path.join(ROOT, "screenshots", "loom_core_wisp_20261127")
CORE = os.path.join(ROOT, "assets", "star_core")

BG = (10, 18, 22, 255)
PANEL = (18, 30, 34, 255)
INK = (232, 238, 230, 255)
MUTED = (160, 180, 178, 255)


def font(size: int = 12):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/consola.ttf", size)
    except OSError:
        return ImageFont.load_default()


def nearest(image: Image.Image, scale: int = 4) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


def core_sheet() -> None:
    sheet = Image.open(os.path.join(CORE, "star_core_positive_12f.png")).convert("RGBA")
    scale = 4
    cell_w = 16 * scale + 12
    cell_h = 16 * scale + 22
    cols, rows = 6, 2
    width = cols * cell_w + 16
    height = rows * cell_h + 52
    canvas = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 8), "STAR CORE  12 FRAMES  4x NEAREST", fill=INK, font=font(14))
    draw.text((10, 26), "positive / gold; frames 0-3 are the L1 handoff poses", fill=MUTED, font=font(10))
    for index in range(12):
        frame = sheet.crop((index * 16, 0, index * 16 + 16, 16))
        big = nearest(frame, scale)
        col = index % cols
        row = index // cols
        x = 10 + col * cell_w
        y = 48 + row * cell_h
        canvas.alpha_composite(big, (x, y))
        draw.rectangle((x - 1, y - 1, x + 64, y + 64), outline=(58, 76, 78, 255), width=1)
        draw.text((x + 2, y + 66), "F%02d" % index, fill=MUTED, font=font(10))
    canvas.convert("RGB").save(os.path.join(OUT, "star_core_12f_4x.png"))


def panel(canvas: Image.Image, image: Image.Image, x: int, y: int, label: str, sub: str) -> int:
    big = nearest(image.convert("RGBA"), 4)
    draw = ImageDraw.Draw(canvas)
    canvas.alpha_composite(big, (x, y))
    draw.rectangle((x - 1, y - 1, x + big.width, y + big.height), outline=(64, 84, 86, 255), width=1)
    draw.text((x, y + big.height + 5), label, fill=INK, font=font(12))
    draw.text((x, y + big.height + 20), sub, fill=MUTED, font=font(9))
    return big.width


def bay_states() -> None:
    l3_empty = Image.open(os.path.join(OUT, "02_l3_bay_empty.png")).convert("RGB")
    l3_full = Image.open(os.path.join(OUT, "02b_l3_bay_locked.png")).convert("RGB")
    dlc_before = Image.open(os.path.join(CAPTURE, "01_core_before_bay.png")).convert("RGB")
    dlc_after = Image.open(os.path.join(CAPTURE, "03_core_seated_lit.png")).convert("RGB")

    # Crops are the real viewport pixels around each bay, not re-rendered art.
    l3e = l3_empty.crop((312, 300, 352, 330))
    l3f = l3_full.crop((130, 290, 172, 330))
    d3b = dlc_before.crop((300, 286, 360, 334))
    d3a = dlc_after.crop((300, 286, 360, 334))

    canvas = Image.new("RGBA", (700, 520), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((10, 8), "STAR CORE BAY  EMPTY / FULL  4x NEAREST", fill=INK, font=font(14))
    draw.text((10, 26), "real 640x360 captures, nearest 4x crop (no debug overlay)", fill=MUTED, font=font(10))
    y0 = 50
    panel(canvas, l3e, 10, y0, "L3 TARGET BAY / EMPTY", "base dim, gold socket hint, glass open")
    panel(canvas, l3f, 230, y0, "L3 START BAY / FULL (LOCKED)", "white pedestal + framed glass + purple core")
    y1 = 250
    panel(canvas, d3b, 10, y1, "DLC3 BEFORE / EMPTY", "dark niche, gold core ring, glass hidden")
    panel(canvas, d3a, 300, y1, "DLC3 AFTER / LIT", "core seated, base and dome lit")
    canvas.convert("RGB").save(os.path.join(OUT, "star_core_bay_states_4x.png"))


def copy_dlc3() -> None:
    shutil.copyfile(
        os.path.join(CAPTURE, "01_core_before_bay.png"),
        os.path.join(OUT, "03_dlc3_before.png"),
    )
    shutil.copyfile(
        os.path.join(CAPTURE, "03_core_seated_lit.png"),
        os.path.join(OUT, "04_dlc3_after.png"),
    )


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    copy_dlc3()
    core_sheet()
    bay_states()
    print("CORE_EVIDENCE_DONE", OUT)


if __name__ == "__main__":
    main()
