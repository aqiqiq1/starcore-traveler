"""Draw the 32x32 completion gate emblem (2026-11-27).

The emblem is a *settlement* mark, not a star core and not the guard's chest
core: a dark stone roundel, a 1 px gold gate silhouette (two pillars + arch +
threshold + central door seam), and one thin ring of pale light outside the
stone.  It follows the project's cold-stone / #f4cd63 gold HUD language.

Deterministic Pillow pixel art.  No third-party image is read or sampled.

Run:
  D:/minic/envs/2024212971/python.exe dlc/core_badge_20261127/gen_completion_emblem.py
"""

from __future__ import annotations

import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ui", "icons", "completion_gate_emblem_32.png")

CLEAR = (0, 0, 0, 0)
STONE_EDGE = (13, 21, 23, 255)
STONE_DARK = (27, 37, 40, 255)
STONE = (43, 53, 55, 255)
STONE_HI = (72, 85, 88, 255)
STONE_LIGHT = (110, 127, 128, 255)
GOLD = (244, 205, 99, 255)
GOLD_HI = (255, 233, 160, 255)
GOLD_DIM = (146, 102, 34, 235)
LIGHT = (255, 228, 150, 150)
LIGHT_HI = (255, 248, 214, 235)

SIZE = 32
CX = 15.5
CY = 15.5


def put(px, x: int, y: int, color) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        px[x, y] = color


def line(px, x0: int, y0: int, x1: int, y1: int, color) -> None:
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    x, y = x0, y0
    while True:
        put(px, x, y, color)
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy


def draw() -> Image.Image:
    image = Image.new("RGBA", (SIZE, SIZE), CLEAR)
    px = image.load()

    # 1. Stone roundel.  A 1 px bevel: top-left lit, bottom-right in shadow.
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (x + 0.5) - CX
            dy = (y + 0.5) - CY
            d = math.hypot(dx, dy)
            if d > 12.4:
                continue
            if d > 11.4:
                if dx + dy < -2.0:
                    color = STONE_LIGHT
                elif dx + dy < 0.5:
                    color = STONE_HI
                elif dx + dy > 2.0:
                    color = STONE_EDGE
                else:
                    color = STONE_DARK
            elif d > 10.7:
                color = STONE
            else:
                color = STONE_DARK
            px[x, y] = color

    # A couple of chipped rim pixels so the roundel reads as stone, not a coin.
    for x, y in ((4, 9), (5, 9), (28, 22), (27, 23), (25, 5)):
        if math.hypot((x + 0.5) - CX, (y + 0.5) - CY) >= 11.2:
            px[x, y] = CLEAR

    # Sparse stone texture inside the face, kept away from the gate lines.
    for x, y, color in (
        (7, 17, STONE_EDGE), (8, 18, STONE), (24, 10, STONE_EDGE),
        (24, 21, STONE), (7, 11, STONE), (19, 23, STONE_EDGE),
        (12, 8, STONE), (22, 17, STONE_EDGE),
    ):
        px[x, y] = color

    # 2. Gold gate silhouette.  Two 2 px pillars, a round arch, threshold and
    #    a dim central door seam.  It stays a silhouette: no glowing core.
    # Arch: upper half of a circle centred on the doorway, r = 5.5.
    for step in range(0, 180, 2):
        angle = math.radians(float(step))
        x = int(round(CX + math.cos(angle) * 5.5 - 0.5))
        y = int(round(15.5 - math.sin(angle) * 5.5 - 0.5))
        put(px, x, y, GOLD)
        if step < 20 or step > 160:
            put(px, x, y, GOLD_HI)

    # A second lit pixel just above the arch crown (keystone).
    put(px, 15, 8, GOLD_HI)
    put(px, 16, 8, GOLD_HI)
    put(px, 15, 9, GOLD)
    put(px, 16, 9, GOLD)

    # Pillars: x=9..10 and x=21..22, from the arch springing to the threshold.
    for y in range(14, 25):
        put(px, 9, y, GOLD)
        put(px, 10, y, GOLD_HI if y in (14, 24) else GOLD)
        put(px, 21, y, GOLD_HI if y in (14, 24) else GOLD)
        put(px, 22, y, GOLD)

    # Threshold.  The doorway itself stays open/dark: the emblem is a gate
    # silhouette, not a filled door and not a core.
    for x in range(8, 24):
        put(px, x, 25, GOLD_DIM)
    put(px, 8, 25, GOLD)
    put(px, 23, 25, GOLD)

    # Small pillar feet, one pixel wider than the shaft.
    for x in (8, 23):
        put(px, x, 24, GOLD_DIM)
        put(px, x, 25, GOLD)

    # 3. One thin ring of pale light outside the stone, with four brighter
    #    cardinal beads.  It never touches the gold gate or the stone face.
    for y in range(SIZE):
        for x in range(SIZE):
            dx = (x + 0.5) - CX
            dy = (y + 0.5) - CY
            d = math.hypot(dx, dy)
            if not 13.35 <= d <= 14.65:
                continue
            angle = math.atan2(dy, dx)
            bead = max(0.0, math.cos(angle * 4.0)) ** 8
            color = LIGHT_HI if bead > 0.65 else LIGHT
            px[x, y] = color

    return image


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    image = draw()
    image.save(OUT, optimize=True)
    print("WROTE", OUT, image.size)


if __name__ == "__main__":
    main()
