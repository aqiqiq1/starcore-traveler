"""Three pixel-art icon concepts for 星核旅人, drawn at 128x128 then
nearest-upscaled.  Run with the project python (Pillow)."""

import os
import math
from PIL import Image, ImageDraw

OUT = "assets/icon/concepts"
os.makedirs(OUT, exist_ok=True)

NAVY_TOP = (16, 32, 46)
NAVY_BOT = (36, 80, 94)
CLOUD = (120, 156, 166)
CLOUD_HI = (170, 200, 205)
STONE = (76, 67, 75)
STONE_HI = (139, 128, 121)
STONE_LO = (43, 40, 46)
GOLD = (244, 205, 99)
GOLD_HI = (255, 230, 161)
GOLD_LO = (168, 123, 45)
CYAN = (95, 225, 230)
CYAN_LO = (42, 125, 132)
WHITE = (255, 252, 240)
INK = (13, 20, 26)


def gradient(size):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(NAVY_TOP[i] + (NAVY_BOT[i] - NAVY_TOP[i]) * t) for i in range(3))
        d.line([(0, y), (size, y)], fill=c + (255,))
    return im


def halo(im, cx, cy, r, color, steps=4):
    for i in range(steps, 0, -1):
        rr = r + i * 4
        a = int(30 / i)
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (a,))
        im.alpha_composite(layer)


def core(d, cx, cy, r, split_cyan=True):
    # dark outline
    d.ellipse([cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_LO)
    # inner body
    d.ellipse([cx - r + 1, cy - r + 1, cx + r - 1, cy + r - 1], fill=GOLD)
    # facets: top-left light, bottom-right shadow
    d.polygon([(cx - r + 2, cy - 2), (cx - 2, cy - r + 2), (cx + 2, cy - r + 3), (cx - r + 3, cy + 2)], fill=GOLD_HI)
    d.polygon([(cx + 3, cy + 1), (cx + r - 2, cy - 2), (cx + r - 3, cy + r - 4), (cx + 1, cy + r - 3)], fill=GOLD_LO)
    if split_cyan:
        d.polygon([(cx + 1, cy + r - 4), (cx + r - 3, cy + r - 4), (cx + r - 5, cy + r - 8), (cx + 3, cy + r - 9)], fill=CYAN_LO)
        d.polygon([(cx + 3, cy + r - 9), (cx + r - 5, cy + r - 8), (cx + r - 7, cy + r - 11), (cx + 5, cy + r - 12)], fill=CYAN)
    # white heart
    d.rectangle([cx - 2, cy - 3, cx + 1, cy + 1], fill=WHITE)


def concept_a():
    im = gradient(128)
    d = ImageDraw.Draw(im)
    # moon ring
    d.ellipse([96, 14, 118, 36], outline=(232, 226, 213, 255), width=2)
    # clouds
    for y, w, x in [(86, 42, 8), (92, 30, 70), (78, 22, 96)]:
        d.rectangle([x, y, x + w, y + 2], fill=CLOUD)
        d.rectangle([x + 4, y - 2, x + w - 6, y], fill=CLOUD_HI)
    # broken bridge deck
    d.rectangle([0, 104, 52, 112], fill=STONE)
    d.rectangle([0, 104, 52, 106], fill=STONE_HI)
    d.rectangle([76, 104, 128, 112], fill=STONE)
    d.rectangle([76, 104, 128, 106], fill=STONE_HI)
    # pylons
    d.rectangle([12, 96, 22, 104], fill=STONE_HI)
    d.rectangle([106, 96, 116, 104], fill=STONE_HI)
    # rubble in the gap
    d.rectangle([54, 108, 58, 112], fill=STONE_LO)
    d.rectangle([70, 108, 75, 111], fill=STONE_LO)
    # core
    halo(im, 64, 62, 20, GOLD)
    core(d, 64, 62, 18, True)
    # traveler silhouette on the left deck
    d.rectangle([40, 92, 45, 102], fill=INK)          # body
    d.rectangle([42, 86, 45, 92], fill=INK)           # head
    d.polygon([(40, 92), (34, 100), (41, 99)], fill=(90, 40, 70))  # cape
    return im


def concept_b():
    im = gradient(128)
    d = ImageDraw.Draw(im)
    cx, cy = 64, 64
    # halo
    halo(im, cx, cy, 40, (244, 205, 99))
    # outer ring split gold/cyan
    d.ellipse([cx - 47, cy - 47, cx + 47, cy + 47], fill=INK)
    d.ellipse([cx - 44, cy - 44, cx + 44, cy + 44], fill=GOLD_LO)
    d.ellipse([cx - 41, cy - 41, cx + 41, cy + 41], fill=INK)
    # split colors: draw arcs by pieslice
    d.pieslice([cx - 44, cy - 44, cx + 44, cy + 44], 90, 270, fill=GOLD)
    d.pieslice([cx - 44, cy - 44, cx + 44, cy + 44], 270, 450, fill=CYAN)
    d.ellipse([cx - 40, cy - 40, cx + 40, cy + 40], fill=(18, 26, 32))
    # inner rings
    d.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], outline=(70, 62, 58), width=1)
    # eye: almond
    d.polygon([(cx - 26, cy), (cx - 12, cy - 10), (cx + 12, cy - 10), (cx + 26, cy),
               (cx + 12, cy + 10), (cx - 12, cy + 10)], fill=(232, 226, 213))
    d.polygon([(cx - 24, cy), (cx - 11, cy - 8), (cx + 11, cy - 8), (cx + 24, cy),
               (cx + 11, cy + 8), (cx - 11, cy + 8)], fill=(20, 28, 34))
    # iris split gold/cyan
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=GOLD)
    d.pieslice([cx - 9, cy - 9, cx + 9, cy + 9], 270, 450, fill=CYAN)
    d.ellipse([cx - 4, cy - 9, cx + 4, cy + 9], fill=(12, 16, 20))
    d.rectangle([cx - 1, cy - 7, cx + 1, cy + 7], fill=(8, 10, 12))
    # glints
    d.rectangle([cx - 16, cy - 6, cx - 13, cy - 3], fill=WHITE)
    d.rectangle([cx + 12, cy + 4, cx + 14, cy + 6], fill=(255, 255, 255))
    return im


def concept_c():
    im = gradient(128)
    d = ImageDraw.Draw(im)
    # far clouds
    for y, w, x in [(96, 50, 6), (100, 34, 80)]:
        d.rectangle([x, y, x + w, y + 3], fill=CLOUD)
    # big core low-centre
    halo(im, 64, 70, 30, GOLD)
    core(d, 64, 70, 30, True)
    # traveler silhouette in front, left
    d.rectangle([30, 96, 37, 110], fill=INK)
    d.rectangle([32, 88, 37, 96], fill=INK)
    d.polygon([(30, 96), (20, 108), (31, 105)], fill=(90, 40, 70))
    # bridge deck
    d.rectangle([0, 112, 128, 118], fill=STONE)
    d.rectangle([0, 112, 128, 114], fill=STONE_HI)
    return im


for name, fn in [("A_core_bridge", concept_a), ("B_mirror_eye", concept_b), ("C_traveler_core", concept_c)]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)
