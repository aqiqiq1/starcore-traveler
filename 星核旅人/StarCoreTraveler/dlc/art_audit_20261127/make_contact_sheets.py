"""Build 4x evidence sheets for the 2026-11-27 art audit.

Not a runtime dependency.  Reads only project assets and the before/after
captures; writes PNGs into screenshots/art_audit_20261127/.
"""

import os
from PIL import Image

ROOT = r"D:\godot game\星核旅人\StarCoreTraveler"
OUT = os.path.join(ROOT, "screenshots", "art_audit_20261127")


def nearest(image: Image.Image, scale: int) -> Image.Image:
    return image.resize((image.width * scale, image.height * scale), Image.NEAREST)


def ui_sheet() -> None:
    badge = [Image.open(os.path.join(ROOT, "assets", "ui", "icons", name)).convert("RGBA")
             for name in ("affinity_sun_20.png", "affinity_moon_20.png")]
    heart = Image.open(os.path.join(ROOT, "assets", "ui", "icons", "heart_10.png")).convert("RGBA")
    keys = []
    for name in ("key_q.png", "key_j.png", "key_e.png", "key_f.png"):
        keys.append(Image.open(os.path.join(ROOT, "assets", "ui", "keycaps", name)).convert("RGBA"))
    scale = 6
    cell = 32 * scale
    sheet = Image.new("RGB", (cell * 7, cell), (10, 20, 24))
    items = badge + [heart] + keys
    for index, item in enumerate(items):
        big = nearest(item, scale)
        x = index * cell + (cell - big.width) // 2
        y = (cell - big.height) // 2
        sheet.paste(big, (x, y), big)
    sheet.save(os.path.join(OUT, "ui_icons_6x.png"))


def windows_sheet() -> None:
    before = Image.open(os.path.join(ROOT, "dlc", "star_loom", "assets", "city", "city_back_960x360.png")).convert("RGBA")
    after = Image.open(os.path.join(ROOT, "dlc", "star_loom", "assets", "city_v2", "city_back_960x360.png")).convert("RGBA")
    box = (40, 60, 600, 330)
    b = before.crop(box)
    a = after.crop(box)
    bg = Image.new("RGB", (b.width * 2 + 8, b.height), (7, 13, 15))
    bg.paste(b, (0, 0), b)
    bg.paste(a, (b.width + 8, 0), a)
    nearest(bg, 2).save(os.path.join(OUT, "dlc3_windows_before_after_2x.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ui_sheet()
    windows_sheet()
    print("CONTACT_SHEETS_DONE", OUT)
