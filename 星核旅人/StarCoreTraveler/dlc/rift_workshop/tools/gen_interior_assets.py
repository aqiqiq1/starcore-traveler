"""DLC2 rift-workshop interior art pass (2026-11-27).

Runtime-only, fully procedural pixel art for the whole chapter:

  interior_back_1880x360.png   distant stone wall / arch rhythm / mirror hall
  interior_mid_1880x360.png    dark timber frame, iron straps, chains, forge
  interior_fore_640x360.png    screen-fixed dark timber edge frame
  interior_floor_1880x40.png   warm stone floor, open over the bridge pit
  interior_warm_haze_640x360.png  warm dust haze for RiftFog

The four layer images are original drawings made from integer rectangles and
arch spans.  No third-party pixel, palette file or screenshot is read.  The
SotN Marble Gallery / Chrono Trigger Zeal references in
REF_INTERIOR_20261127.md were studied for structure and value separation, not
traced or sampled.

Design notes
  * warm interior vs. DLC3's cold stone hall: wood + iron dominate the upper
    two thirds, stone is the quiet middle field, firelight is local.
  * key light is upper-left: every horizontal ledge has a 1 px top light and a
    1 px dark bottom; every post is 1 px lighter on the left, 1 px darker on
    the right.
  * the band behind the phase bridges (y 200-320) is kept deliberately dark
    and low-saturation so the violet curtain and the gold/cyan decks stay the
    first thing the eye finds.
  * the back layer's mirror bays are neutral charcoal glass, not windows and
    not cyan/gold panels, so the mirror boss remains the brightest object.

Run:
    D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/gen_interior_assets.py
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
OUT = os.path.join(DLC, "assets", "interior")

W = 1880
H = 360
FW = 640

# --- palette ---------------------------------------------------------------
INK = (13, 10, 10, 255)
NIGHT = (20, 16, 18, 255)
SHADOW = (28, 23, 25, 255)

# Interior stone: the approved L2 grey-mauve family, pressed one to two steps
# darker and warmed only by the local light overlays.
STONE_DARK = (44, 39, 42, 255)
STONE_0 = (58, 51, 54, 255)
STONE_1 = (66, 58, 61, 255)
STONE_2 = (76, 67, 70, 255)
STONE_3 = (86, 76, 78, 255)
STONE_4 = (97, 86, 86, 255)
STONE_5 = (111, 99, 95, 255)
STONE_6 = (126, 112, 105, 255)
STONE_TOP = (146, 131, 120, 255)
STONE_HI = (166, 149, 134, 255)
MORTAR = (38, 33, 36, 255)

# Bright floor values are the approved L2 stone strip, kept for continuity
# with l3_terrain / l2_ground_1792x40.
FLOOR_0 = (76, 67, 73, 255)
FLOOR_1 = (94, 82, 87, 255)
FLOOR_2 = (112, 99, 101, 255)
FLOOR_3 = (124, 110, 109, 255)
FLOOR_4 = (136, 122, 120, 255)
FLOOR_5 = (147, 132, 127, 255)
FLOOR_6 = (159, 146, 138, 255)
FLOOR_HI = (172, 160, 151, 255)

WOOD_DARK = (28, 20, 17, 255)
WOOD_0 = (38, 27, 22, 255)
WOOD_1 = (49, 35, 28, 255)
WOOD_2 = (61, 43, 33, 255)
WOOD_3 = (74, 52, 39, 255)
WOOD_4 = (88, 62, 45, 255)
WOOD_HI = (108, 77, 53, 255)

IRON = (23, 22, 21, 255)
IRON_0 = (31, 29, 27, 255)
IRON_1 = (40, 37, 33, 255)
IRON_2 = (52, 47, 41, 255)
IRON_3 = (68, 60, 49, 255)
IRON_HI = (88, 75, 57, 255)
RIVET = (116, 93, 60, 255)

GOLD_DARK = (126, 92, 36, 255)
GOLD_MID = (176, 132, 56, 255)

FIRE_DEEP = (88, 34, 14, 255)
FIRE_DARK = (142, 62, 22, 255)
FIRE = (198, 96, 32, 255)
FIRE_MID = (234, 142, 58, 255)
FIRE_LIGHT = (255, 196, 108, 255)
FIRE_HOT = (255, 235, 180, 255)

GLASS_TOP = (45, 47, 51, 255)
GLASS_MID = (35, 37, 41, 255)
GLASS_LOW = (25, 27, 31, 255)
GLASS_HI = (62, 62, 64, 255)
GLASS_WARM = (72, 58, 46, 255)


# --- generic helpers -------------------------------------------------------
def rect(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, color) -> None:
    if x1 < x0 or y1 < y0:
        return
    draw.rectangle((x0, y0, x1, y1), fill=color)


def px(draw: ImageDraw.ImageDraw, x: int, y: int, color) -> None:
    if 0 <= x < draw.im.size[0] and 0 <= y < draw.im.size[1]:
        draw.point((x, y), fill=color)


def lerp(a, b, t: float):
    t = max(0.0, min(1.0, t))
    return (
        int(round(a[0] + (b[0] - a[0]) * t)),
        int(round(a[1] + (b[1] - a[1]) * t)),
        int(round(a[2] + (b[2] - a[2]) * t)),
        255,
    )


def arch_spans(x0: int, y0: int, x1: int, y1: int):
    """Yield (y, left, right) for a round-arched opening, inclusive."""
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    spring = y0 + half
    for y in range(y0, y1 + 1):
        if y < spring:
            dy = spring - y
            h = math.sqrt(max(half * half - dy * dy, 0.0))
        else:
            h = half
        yield y, int(round(cx - h)), int(round(cx + h))


def fill_arch(draw: ImageDraw.ImageDraw, x0, y0, x1, y1, color) -> None:
    for y, left, right in arch_spans(x0, y0, x1, y1):
        rect(draw, left, y, right, y, color)


def arch_edges(
    draw: ImageDraw.ImageDraw, x0, y0, x1, y1,
    left_color, right_color, top_color=None,
) -> None:
    """1 px directional edge on an already filled arch."""
    for y, left, right in arch_spans(x0, y0, x1, y1):
        px(draw, left, y, left_color)
        px(draw, right, y, right_color)
    if top_color is not None:
        for y in range(y0, min(y0 + 3, y1 + 1)):
            span = next(arch_spans(x0, y, x1, y1))
            rect(draw, span[1] + 1, y, span[2] - 1, y, top_color)


def glow(img: Image.Image, cx: int, cy: int, rx: int, ry: int, color, alpha: int) -> None:
    """Soft stepped elliptical glow, clipped to the image."""
    if alpha <= 0 or rx <= 0 or ry <= 0:
        return
    x0 = max(0, cx - rx)
    x1 = min(img.width - 1, cx + rx)
    y0 = max(0, cy - ry)
    y1 = min(img.height - 1, cy + ry)
    draw = ImageDraw.Draw(img)
    for y in range(y0, y1 + 1):
        ny = (y - cy) / float(ry)
        for x in range(x0, x1 + 1):
            nx = (x - cx) / float(rx)
            d = nx * nx + ny * ny
            if d >= 1.0:
                continue
            a = int(alpha * (1.0 - d) * (1.0 - d))
            if a <= 0:
                continue
            a = min(255, a)
            old = img.getpixel((x, y))
            old_a = old[3]
            den = a * 255 + old_a * (255 - a)
            if den <= 0:
                continue
            draw.point((x, y), fill=(
                (color[0] * a * 255 + old[0] * old_a * (255 - a)) // den,
                (color[1] * a * 255 + old[1] * old_a * (255 - a)) // den,
                (color[2] * a * 255 + old[2] * old_a * (255 - a)) // den,
                den // 255,
            ))


def shade_rows(img: Image.Image, y0: int, y1: int, color, alpha_top: int,
               alpha_bottom: int) -> None:
    """Darken a horizontal band with a linear alpha ramp."""
    if y1 < y0:
        return
    draw = ImageDraw.Draw(img)
    span = max(1, y1 - y0)
    for y in range(max(0, y0), min(img.height - 1, y1) + 1):
        a = int(alpha_top + (alpha_bottom - alpha_top) * (y - y0) / span)
        if a <= 0:
            continue
        for x in range(img.width):
            old = img.getpixel((x, y))
            draw.point((x, y), fill=(
                (old[0] * (255 - a) + color[0] * a) // 255,
                (old[1] * (255 - a) + color[1] * a) // 255,
                (old[2] * (255 - a) + color[2] * a) // 255,
                255,
            ))


# --- stone -----------------------------------------------------------------
def brick_wall(
    img: Image.Image, x0: int, y0: int, x1: int, y1: int,
    tones=(STONE_0, STONE_1, STONE_1, STONE_2), seed: int = 20261127,
) -> None:
    """Calm 48x24 coursing, 1 px top light, 1 px bottom mortar."""
    draw = ImageDraw.Draw(img)
    rng = random.Random(seed)
    rect(draw, x0, y0, x1, y1, STONE_1)
    course = 24
    brick = 48
    row = 0
    y = y0
    while y <= y1:
        h = min(course, y1 - y + 1)
        rect(draw, x0, y, x1, y + h - 1, STONE_1)
        # The top edge of every course catches the upper-left light.
        rect(draw, x0, y, x1, y, STONE_3)
        offset = 0 if row % 2 == 0 else brick // 2
        bx = x0 - offset
        while bx < x1:
            tone = rng.choice(tones)
            bx0 = max(x0, bx + 1)
            bx1 = min(x1, bx + brick - 2)
            if bx1 >= bx0:
                rect(draw, bx0, y + 1, bx1, y + h - 2, tone)
                # A single quiet nick on roughly one brick in seven.
                if rng.random() < 0.14:
                    nx = min(bx1 - 4, bx0 + 9)
                    px(draw, nx, y + 5, STONE_4)
                if rng.random() < 0.08:
                    nx = min(bx1 - 6, bx0 + 21)
                    px(draw, nx, y + h - 5, STONE_DARK)
            # Right-hand mortar joint.
            if x0 <= bx + brick - 1 <= x1:
                rect(draw, bx + brick - 1, y + 1, bx + brick - 1, y + h - 2, MORTAR)
            bx += brick
        rect(draw, x0, y + h - 1, x1, y + h - 1, MORTAR)
        y += h
        row += 1


def stone_pier(img: Image.Image, x: int, width: int, top: int, bottom: int) -> None:
    """Square stone pier: 1 px left light, right shadow, capped and based."""
    draw = ImageDraw.Draw(img)
    # Cast shadow on the wall to the right.
    for step in range(4):
        a = 26 - step * 6
        if a <= 0:
            continue
        for y in range(top + 16, bottom):
            old = img.getpixel((min(img.width - 1, x + width + step), y))
            draw.point((min(img.width - 1, x + width + step), y), fill=(
                old[0] * (255 - a) // 255, old[1] * (255 - a) // 255,
                old[2] * (255 - a) // 255, 255,
            ))
    shaft_x0 = x + 4
    shaft_x1 = x + width - 5
    rect(draw, shaft_x0, top + 12, shaft_x1, bottom - 16, STONE_1)
    rect(draw, shaft_x0, top + 12, shaft_x0 + 1, bottom - 16, STONE_4)
    rect(draw, shaft_x1 - 1, top + 12, shaft_x1, bottom - 16, STONE_0)
    rect(draw, shaft_x1, top + 12, shaft_x1, bottom - 16, STONE_DARK)
    # Sparse vertical joints, no random noise.
    for gx in range(shaft_x0 + 10, shaft_x1 - 4, 12):
        rect(draw, gx, top + 18, gx, bottom - 22, STONE_0)
        px(draw, gx, top + 22, STONE_3)
    # Capital.
    rect(draw, x, top, x + width - 1, top + 3, STONE_4)
    rect(draw, x, top, x + width - 1, top, STONE_TOP)
    rect(draw, x, top + 4, x + width - 1, top + 8, STONE_3)
    rect(draw, x, top + 4, x + width - 1, top + 4, STONE_5)
    rect(draw, x + 2, top + 9, x + width - 3, top + 10, STONE_2)
    rect(draw, x + 2, top + 11, x + width - 3, top + 11, GOLD_DARK)
    rect(draw, x + 3, top + 12, x + width - 4, top + 12, STONE_DARK)
    # Base.
    rect(draw, x + 2, bottom - 22, x + width - 3, bottom - 16, STONE_3)
    rect(draw, x + 2, bottom - 22, x + width - 3, bottom - 22, STONE_5)
    rect(draw, x, bottom - 15, x + width - 1, bottom - 4, STONE_2)
    rect(draw, x, bottom - 15, x + width - 1, bottom - 15, STONE_5)
    rect(draw, x + 3, bottom - 10, x + width - 4, bottom - 10, GOLD_DARK)
    rect(draw, x, bottom - 3, x + width - 1, bottom, STONE_0)
    rect(draw, x, bottom, x + width - 1, bottom, INK)


def plinth(img: Image.Image, x0: int, y0: int, x1: int) -> None:
    """20 px skirting at the wall/floor junction (y 300..319)."""
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y0, x1, 319, STONE_1)
    rect(draw, x0, y0, x1, y0, STONE_5)
    rect(draw, x0, y0 + 1, x1, y0 + 1, STONE_3)
    rect(draw, x0, 318, x1, 319, STONE_DARK)
    for bx in range(x0 + 8, x1, 72):
        rect(draw, bx, y0 + 7, min(x1, bx + 56), 316, STONE_0)
        rect(draw, bx, y0 + 7, min(x1, bx + 56), y0 + 7, STONE_0)
        rect(draw, bx + 1, y0 + 8, min(x1, bx + 55), y0 + 8, STONE_3)
        rect(draw, bx, 316, min(x1, bx + 56), 316, SHADOW)


# --- wood / iron -----------------------------------------------------------
def wood_post(img: Image.Image, x: int, width: int, top: int, bottom: int) -> None:
    draw = ImageDraw.Draw(img)
    # Wall shadow to the right.  The mid layer is transparent, so the shadow
    # must keep its own alpha instead of writing opaque black on the wall.
    for step in range(3):
        a = 30 - step * 8
        if a <= 0:
            continue
        for y in range(top + 8, bottom):
            xx = min(img.width - 1, x + width + step)
            old = img.getpixel((xx, y))
            if old[3] == 0:
                draw.point((xx, y), fill=(12, 9, 9, a))
            else:
                draw.point((xx, y), fill=(
                    old[0] * (255 - a) // 255, old[1] * (255 - a) // 255,
                    old[2] * (255 - a) // 255, old[3],
                ))
    rect(draw, x, top + 8, x + width - 1, bottom, WOOD_1)
    rect(draw, x, top + 8, x + 1, bottom, WOOD_3)
    rect(draw, x + 2, top + 8, x + 2, bottom, WOOD_2)
    rect(draw, x + width - 3, top + 8, x + width - 3, bottom, WOOD_0)
    rect(draw, x + width - 2, top + 8, x + width - 1, bottom, WOOD_DARK)
    # Quiet grain: one 1 px line every 7 rows, deterministic.
    for gy in range(top + 16, bottom - 8, 7):
        rect(draw, x + 4, gy, x + width - 5, gy, WOOD_0 if (gy // 7) % 2 == 0 else WOOD_2)
    # Iron bands at fixed heights.
    for band_y in (top + 46, top + 118, top + 190, top + 262):
        if band_y + 5 >= bottom:
            continue
        rect(draw, x - 1, band_y, x + width, band_y + 4, IRON_2)
        rect(draw, x - 1, band_y, x + width, band_y, IRON_3)
        rect(draw, x - 1, band_y + 4, x + width, band_y + 4, IRON_0)
        for rx in (x + 3, x + width - 4):
            px(draw, rx, band_y + 2, RIVET)
            px(draw, rx, band_y + 3, IRON_1)
    # Stone base.
    rect(draw, x - 4, bottom - 14, x + width + 3, bottom, STONE_2)
    rect(draw, x - 4, bottom - 14, x + width + 3, bottom - 14, STONE_5)
    rect(draw, x - 2, bottom - 9, x + width + 1, bottom - 9, STONE_0)
    rect(draw, x - 4, bottom - 2, x + width + 3, bottom, STONE_DARK)
    rect(draw, x - 4, bottom, x + width + 3, bottom, INK)


def wood_beam(img: Image.Image, x0: int, x1: int, y: int, height: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y, x1, y + height - 1, WOOD_1)
    rect(draw, x0, y, x1, y, WOOD_4)
    rect(draw, x0, y + 1, x1, y + 1, WOOD_3)
    rect(draw, x0, y + height - 1, x1, y + height - 1, WOOD_DARK)
    rect(draw, x0, y + height, x1, y + height, INK)
    for gy in range(y + 5, y + height - 2, 6):
        rect(draw, x0, gy, x1, gy, WOOD_0 if (gy - y) % 12 < 6 else WOOD_2)
    # Iron straps and rivets at a readable 96 px rhythm.
    for sx in range(x0 + 24, x1, 96):
        rect(draw, sx, y - 1, sx + 5, y + height, IRON_2)
        rect(draw, sx, y - 1, sx + 5, y - 1, IRON_3)
        rect(draw, sx, y + height, sx + 5, y + height, IRON_0)
        px(draw, sx + 2, y + 3, RIVET)
        px(draw, sx + 2, y + height - 4, IRON_0)


def brace(img: Image.Image, x: int, y_top: int, y_bottom: int, width: int = 7) -> None:
    """Diagonal timber brace from a post up to the wall plate."""
    draw = ImageDraw.Draw(img)
    steps = max(1, y_bottom - y_top)
    for index in range(steps):
        t = index / float(steps)
        xx = x + int(round(width * (1.0 - t)))
        yy = y_top + index
        rect(draw, xx, yy, xx + 3, yy, WOOD_2)
        px(draw, xx, yy, WOOD_4)
        px(draw, xx + 3, yy, WOOD_0)
    # One iron nail at each end.
    px(draw, x + width, y_top + 1, RIVET)
    px(draw, x + 1, y_bottom - 2, IRON_1)


def chain(img: Image.Image, x: int, y0: int, y1: int) -> None:
    draw = ImageDraw.Draw(img)
    # Top ring.
    rect(draw, x - 2, y0 - 2, x + 2, y0, IRON_2)
    px(draw, x - 2, y0 - 2, IRON_3)
    y = y0
    toggle = 0
    while y < y1 - 6:
        if toggle % 2 == 0:
            rect(draw, x - 1, y, x + 1, y, IRON_2)
            px(draw, x - 1, y, IRON_3)
            px(draw, x - 1, y + 1, IRON_0)
            px(draw, x + 1, y + 1, IRON_0)
        else:
            rect(draw, x, y, x, y + 2, IRON_1)
            px(draw, x, y, IRON_3)
        y += 3
        toggle += 1
    # Hook / end link.
    rect(draw, x - 1, y1 - 5, x + 1, y1 - 3, IRON_2)
    px(draw, x - 1, y1 - 5, IRON_3)
    rect(draw, x, y1 - 2, x, y1, IRON_1)


def lantern(img: Image.Image, x: int, y: int) -> None:
    """Small iron lantern with a warm pane; the caller draws the chain."""
    glow(img, x, y + 4, 30, 30, FIRE_MID, 16)
    draw = ImageDraw.Draw(img)
    rect(draw, x - 3, y - 4, x + 3, y - 2, IRON_2)
    rect(draw, x - 3, y - 4, x + 3, y - 4, IRON_3)
    rect(draw, x - 5, y - 1, x + 5, y + 10, IRON_1)
    rect(draw, x - 4, y, x + 4, y + 8, (42, 32, 24, 255))
    rect(draw, x - 3, y + 1, x + 3, y + 7, FIRE_MID)
    rect(draw, x - 2, y + 2, x + 1, y + 4, FIRE_LIGHT)
    px(draw, x - 1, y + 3, FIRE_HOT)
    rect(draw, x - 4, y + 9, x + 4, y + 10, IRON_2)
    rect(draw, x - 5, y + 11, x + 5, y + 12, IRON_0)
    px(draw, x, y + 13, GOLD_DARK)


def pulley(img: Image.Image, x: int, y: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x - 9, y - 2, x + 9, y + 12, IRON_1)
    rect(draw, x - 9, y - 2, x + 9, y - 2, IRON_3)
    draw.ellipse((x - 7, y, x + 7, y + 10), fill=IRON_0)
    draw.ellipse((x - 5, y + 2, x + 5, y + 8), fill=WOOD_1)
    for angle in range(0, 360, 60):
        ax = x + int(round(math.cos(math.radians(angle)) * 6))
        ay = y + 5 + int(round(math.sin(math.radians(angle)) * 4))
        px(draw, ax, ay, IRON_3)
    px(draw, x, y + 5, RIVET)
    # Rope falling from the sheave.
    rect(draw, x, y + 12, x, y + 38, (92, 76, 54, 255))
    px(draw, x + 1, y + 14, (120, 98, 68, 255))
    rect(draw, x - 3, y + 38, x + 3, y + 42, IRON_1)
    rect(draw, x - 4, y + 42, x + 4, y + 44, IRON_2)


# --- back layer ------------------------------------------------------------
def make_back() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rect(draw, 0, 0, W - 1, H - 1, NIGHT)
    # Ceiling void, cornice, main wall, skirting.
    rect(draw, 0, 0, W - 1, 23, (22, 18, 20, 255))
    brick_wall(img, 0, 31, W - 1, 299)
    plinth(img, 0, 300, W - 1)
    # Cornice: one warm top light, one dull gold line, one dark seam.
    rect(draw, 0, 24, W - 1, 30, STONE_1)
    rect(draw, 0, 24, W - 1, 24, STONE_TOP)
    rect(draw, 0, 25, W - 1, 25, STONE_4)
    rect(draw, 0, 29, W - 1, 29, STONE_0)
    rect(draw, 0, 30, W - 1, 30, GOLD_DARK)
    rect(draw, 0, 31, W - 1, 31, STONE_DARK)
    # Underfloor void: only visible through the bridge pit (the floor layer
    # and terrain hide it elsewhere).  No hard vertical edges, so the small
    # parallax offset never exposes a false seam.
    rect(draw, 0, 320, W - 1, H - 1, (18, 14, 16, 255))
    rect(draw, 0, 336, W - 1, 342, IRON_1)
    rect(draw, 0, 336, W - 1, 336, IRON_2)
    rect(draw, 0, 342, W - 1, 342, IRON)
    for rx in range(12, W, 48):
        px(draw, rx, 339, RIVET)
    # Distant lower machinery silhouettes.
    for cx, top in ((620, 344), (760, 348), (930, 342), (1050, 350)):
        rect(draw, cx - 18, top, cx + 18, H - 1, (24, 19, 21, 255))
        rect(draw, cx - 10, top - 6, cx + 10, top, (30, 24, 25, 255))
        px(draw, cx - 10, top - 6, IRON_1)
    glow(img, 810, 354, 190, 44, FIRE_DARK, 12)

    # Stone piers: zero/entry/bridge/transition/mirror-hall frames.
    for x, width in ((0, 22), (292, 30), (552, 30), (1080, 30), (1224, 30), (1852, 28)):
        stone_pier(img, x, width, 31, 319)

    # Entry blind arch behind the gate / violet curtain.
    ax0, ay0, ax1, ay1 = 146, 96, 288, 299
    fill_arch(draw, ax0 - 7, ay0 - 7, ax1 + 7, ay1, STONE_0)
    fill_arch(draw, ax0 - 6, ay0 - 6, ax1 + 6, ay1, STONE_2)
    fill_arch(draw, ax0, ay0, ax1, ay1, (26, 21, 23, 255))
    arch_edges(draw, ax0 - 7, ay0 - 7, ax1 + 7, ay1, STONE_4, STONE_DARK, STONE_3)
    arch_edges(draw, ax0, ay0, ax1, ay1, (78, 64, 54, 255), (18, 15, 16, 255))
    # Deep shadow inside the arch, darker at the bottom.
    for y, left, right in arch_spans(ax0 + 2, ay0 + 2, ax1 - 2, ay1):
        rect(draw, left, y, right, y, lerp((30, 24, 26, 255), (20, 17, 18, 255),
                                          (y - ay0) / float(ay1 - ay0)))
    # Low-contrast coursing keeps the recess from reading as a flat hole.
    for y in range(ay0 + 24, ay1 - 8, 24):
        span = next(arch_spans(ax0 + 2, y, ax1 - 2, ay1))
        rect(draw, span[1] + 3, y, span[2] - 3, y, (34, 28, 29, 255))
        for x in range(span[1] + 10 + (y // 24 % 2) * 12, span[2] - 6, 24):
            rect(draw, x, y, x, min(ay1, y + 22), (32, 26, 27, 255))
    # One very quiet back panel behind the gate.
    rect(draw, 200, 150, 246, 298, (24, 20, 22, 255))
    rect(draw, 200, 150, 200, 298, (36, 30, 30, 255))
    rect(draw, 246, 150, 246, 298, (18, 15, 16, 255))

    # Entry forge: the chapter's strongest local warm source, at the far left
    # so it never sits behind the violet curtain or the phase decks.
    entry_forge(img)

    # Bridge-hall giant blind arch.  Its interior is nearly black so the
    # phase decks and wisps keep the full contrast budget.
    bx0, by0, bx1, by1 = 606, 92, 1004, 299
    fill_arch(draw, bx0 - 9, by0 - 9, bx1 + 9, by1, STONE_0)
    fill_arch(draw, bx0 - 7, by0 - 7, bx1 + 7, by1, STONE_2)
    fill_arch(draw, bx0, by0, bx1, by1, (20, 17, 18, 255))
    arch_edges(draw, bx0 - 9, by0 - 9, bx1 + 9, by1, STONE_4, STONE_DARK, STONE_3)
    arch_edges(draw, bx0, by0, bx1, by1, (62, 52, 46, 255), (14, 12, 13, 255))
    for y, left, right in arch_spans(bx0 + 2, by0 + 2, bx1 - 2, by1):
        rect(draw, left, y, right, y, lerp((28, 23, 24, 255), (18, 15, 16, 255),
                                          (y - by0) / float(by1 - by0)))
    for y in range(by0 + 24, by1 - 8, 24):
        span = next(arch_spans(bx0 + 2, y, bx1 - 2, by1))
        rect(draw, span[1] + 4, y, span[2] - 4, y, (31, 26, 27, 255))
        for x in range(span[1] + 12 + (y // 24 % 2) * 14, span[2] - 8, 24):
            rect(draw, x, y, x, min(by1, y + 22), (29, 24, 25, 255))
    # Wall gear and a slack chain: readable as machinery, not as a light.
    gcx, gcy, gr = 824, 168, 38
    draw.ellipse((gcx - gr, gcy - gr, gcx + gr, gcy + gr), fill=(35, 30, 28, 255))
    draw.ellipse((gcx - gr + 3, gcy - gr + 3, gcx + gr - 3, gcy + gr - 3), fill=(24, 20, 20, 255))
    for angle in range(0, 360, 30):
        tx = gcx + int(round(math.cos(math.radians(angle)) * (gr - 2)))
        ty = gcy + int(round(math.sin(math.radians(angle)) * (gr - 2)))
        rect(draw, tx - 3, ty - 3, tx + 3, ty + 3, (36, 31, 29, 255))
        px(draw, tx - 2, ty - 3, (52, 45, 39, 255))
    draw.ellipse((gcx - 14, gcy - 14, gcx + 14, gcy + 14), fill=(42, 36, 32, 255))
    draw.ellipse((gcx - 10, gcy - 10, gcx + 10, gcy + 10), fill=(24, 20, 19, 255))
    rect(draw, gcx - 2, gcy - 5, gcx + 2, gcy + 5, (36, 30, 27, 255))
    chain(img, gcx, 104, 130)
    # Faint soot and a cold-iron glint on the gear.
    px(draw, gcx - gr + 4, gcy - 12, (66, 58, 48, 255))
    px(draw, gcx - 8, gcy - gr + 1, (66, 58, 48, 255))

    # Transition door: heavy planks, iron bands, a warm seam below.
    dx0, dy0, dx1, dy1 = 1112, 114, 1204, 299
    fill_arch(draw, dx0 - 7, dy0 - 7, dx1 + 7, dy1, STONE_0)
    fill_arch(draw, dx0 - 5, dy0 - 5, dx1 + 5, dy1, STONE_2)
    fill_arch(draw, dx0, dy0, dx1, dy1, (39, 28, 22, 255))
    arch_edges(draw, dx0 - 7, dy0 - 7, dx1 + 7, dy1, STONE_4, STONE_DARK, STONE_3)
    for plank in range(dx0 + 4, dx1 - 2, 12):
        rect(draw, plank, dy0 + 16, plank, dy1 - 2, (33, 23, 19, 255))
        rect(draw, plank + 1, dy0 + 16, plank + 1, dy1 - 2, (48, 34, 27, 255))
    for band_y in (dy0 + 52, dy0 + 112, dy0 + 170):
        rect(draw, dx0 + 2, band_y, dx1 - 2, band_y + 4, IRON_2)
        rect(draw, dx0 + 2, band_y, dx1 - 2, band_y, IRON_3)
        rect(draw, dx0 + 2, band_y + 4, dx1 - 2, band_y + 4, IRON_0)
        px(draw, dx0 + 10, band_y + 2, RIVET)
        px(draw, dx1 - 10, band_y + 2, RIVET)
    # Bottom warm seam, as if a forge is on the other side.
    rect(draw, dx0 + 3, dy1 - 3, dx1 - 4, dy1, (80, 44, 24, 255))
    glow(img, (dx0 + dx1) // 2, dy1, 40, 12, FIRE_DARK, 16)

    # Mirror hall: three neutral charcoal mirrors.  The boss (gold/cyan faces)
    # stands in front of the centre bay.
    for mx0, mx1 in ((1248, 1424), (1452, 1628), (1656, 1832)):
        mirror_bay(img, mx0, 64, mx1, 299)

    # Warm sconces between the mirror bays and at the hall edges.  Their glow
    # stays at y 150-190, well above the boss core.
    for cx in (1236, 1438, 1642, 1846):
        wall_sconce(img, cx, 154)

    # Global key-light / depth shaping.
    shade_rows(img, 24, 78, (16, 13, 15, 255), 10, 0)
    shade_rows(img, 200, 319, (12, 9, 11, 255), 0, 22)
    # A very light warm wash from the upper-left; it never creates a bright
    # horizontal band behind the bridges.
    glow(img, 260, 90, 420, 220, (236, 170, 110, 255), 6)
    glow(img, 250, 250, 330, 170, FIRE_MID, 7)
    glow(img, 1540, 250, 300, 150, FIRE_DARK, 6)
    glow(img, 150, 290, 150, 100, FIRE_MID, 15)
    return img


def entry_forge(img: Image.Image) -> None:
    """Stone chimney breast with a live forge at the chapter's left edge."""
    draw = ImageDraw.Draw(img)
    # Chimney breast: large calm stone, not another 48x24 wall field.
    rect(draw, 0, 48, 92, 319, STONE_1)
    rect(draw, 0, 48, 92, 48, STONE_TOP)
    rect(draw, 0, 49, 92, 49, STONE_4)
    rect(draw, 90, 50, 91, 318, STONE_0)
    rect(draw, 92, 50, 92, 318, STONE_DARK)
    for by in range(56, 312, 16):
        rect(draw, 0, by, 90, by, STONE_3)
        rect(draw, 0, by + 15, 90, by + 15, MORTAR)
        for bx in range(0, 92, 24):
            rect(draw, bx + 23, by + 1, bx + 23, by + 14, MORTAR)
            px(draw, bx + 5, by + 7, STONE_2)
    # Mantel shelf.
    rect(draw, 0, 196, 100, 204, STONE_2)
    rect(draw, 0, 196, 100, 196, STONE_TOP)
    rect(draw, 0, 197, 100, 197, STONE_5)
    rect(draw, 0, 204, 100, 204, STONE_DARK)
    # Raised forge opening: 5 px stone ring, near-black firebox.  It sits above
    # the standing player's head so the start silhouette never sits on fire.
    ox0, oy0, ox1, oy1 = 20, 212, 70, 268
    fill_arch(draw, ox0 - 5, oy0 - 5, ox1 + 5, oy1, STONE_0)
    fill_arch(draw, ox0 - 4, oy0 - 4, ox1 + 4, oy1, STONE_3)
    fill_arch(draw, ox0, oy0, ox1, oy1, (22, 15, 13, 255))
    arch_edges(draw, ox0 - 5, oy0 - 5, ox1 + 5, oy1, STONE_TOP, STONE_DARK, STONE_4)
    arch_edges(draw, ox0, oy0, ox1, oy1, (86, 57, 38, 255), (13, 10, 10, 255))
    # Iron lintel and grate.
    rect(draw, ox0 - 2, oy0 + 2, ox1 + 2, oy0 + 5, IRON_2)
    rect(draw, ox0 - 2, oy0 + 2, ox1 + 2, oy0 + 2, IRON_3)
    for gx in (ox0 + 8, ox0 + 24, ox0 + 40):
        rect(draw, gx, oy0 + 18, gx, oy1 - 1, IRON_2)
        px(draw, gx, oy0 + 18, IRON_3)
    rect(draw, ox0 + 2, oy1 - 4, ox1 - 2, oy1 - 1, IRON_1)
    # Hearth ledge below the opening, then the solid breast down to the floor.
    rect(draw, 13, oy1 + 1, 77, oy1 + 8, STONE_2)
    rect(draw, 13, oy1 + 1, 77, oy1 + 1, STONE_TOP)
    rect(draw, 13, oy1 + 8, 77, oy1 + 8, STONE_DARK)
    # Flame: broad dark body, two inner tongues, a small hot base.
    flame = [
        (21, 267), (20, 255), (25, 245), (29, 251), (33, 235), (39, 247),
        (44, 229), (49, 245), (54, 237), (59, 251), (65, 243), (69, 259),
        (69, 267),
    ]
    draw.polygon(flame, fill=FIRE_DARK)
    flame_mid = [(24, 267), (25, 257), (31, 250), (36, 256), (41, 243),
                 (46, 255), (52, 248), (59, 256), (64, 250), (66, 267)]
    draw.polygon(flame_mid, fill=FIRE)
    flame_core = [(28, 267), (30, 260), (36, 256), (41, 251), (46, 259),
                  (52, 255), (59, 261), (60, 267)]
    draw.polygon(flame_core, fill=FIRE_MID)
    rect(draw, 32, 264, 56, 267, FIRE_LIGHT)
    px(draw, 42, 263, FIRE_HOT)
    # A few 1 px sparks, fixed positions.
    for sx, sy in ((30, 233), (48, 225), (57, 237), (24, 241)):
        px(draw, sx, sy, FIRE_LIGHT)
    # Soot above the opening and an iron tool pair on the right cheek.
    glow(img, 45, 196, 46, 40, (12, 9, 9, 255), 20)
    rect(draw, 80, 219, 81, 249, IRON_1)
    rect(draw, 85, 219, 86, 249, IRON_1)
    px(draw, 80, 219, IRON_3)
    px(draw, 85, 219, IRON_3)
    # Strong local light, then a wider bounce that stays on the left wall.
    glow(img, 45, 255, 104, 92, FIRE_MID, 22)
    glow(img, 60, 253, 150, 120, FIRE, 10)
    glow(img, 45, 207, 70, 60, FIRE_DARK, 12)


def wall_sconce(img: Image.Image, cx: int, cy: int) -> None:
    glow(img, cx, cy + 8, 28, 26, FIRE_MID, 13)
    draw = ImageDraw.Draw(img)
    rect(draw, cx - 2, cy + 4, cx + 2, cy + 14, IRON_1)
    rect(draw, cx - 2, cy + 4, cx + 2, cy + 4, IRON_3)
    rect(draw, cx - 4, cy + 2, cx + 4, cy + 4, IRON_2)
    rect(draw, cx - 3, cy - 3, cx + 3, cy + 2, FIRE_DARK)
    rect(draw, cx - 2, cy - 5, cx + 2, cy + 1, FIRE)
    rect(draw, cx - 1, cy - 7, cx + 1, cy - 1, FIRE_MID)
    px(draw, cx, cy - 8, FIRE_LIGHT)
    rect(draw, cx - 4, cy + 14, cx + 4, cy + 15, IRON_0)


def mirror_bay(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    draw = ImageDraw.Draw(img)
    # Deep arched niche.  The glass itself is a separate rectangular plate, so
    # this reads as a mounted mirror rather than a DLC3-style window.
    fill_arch(draw, x0, y0, x1, y1, STONE_0)
    fill_arch(draw, x0 + 3, y0 + 3, x1 - 3, y1, STONE_2)
    fill_arch(draw, x0 + 16, y0 + 16, x1 - 16, y1 - 6, (23, 19, 21, 255))
    arch_edges(draw, x0, y0, x1, y1, STONE_TOP, STONE_DARK, STONE_4)
    arch_edges(draw, x0 + 3, y0 + 3, x1 - 3, y1, STONE_3, STONE_0)
    arch_edges(draw, x0 + 16, y0 + 16, x1 - 16, y1 - 6, (62, 53, 47, 255), (14, 12, 13, 255))
    # Quiet brick coursing inside the niche above the plate.
    for y in range(y0 + 22, y0 + 58, 8):
        for x in range(x0 + 22, x1 - 22, 24):
            if (x + y) % 48 < 24:
                rect(draw, x, y, x + 10, y, (30, 25, 26, 255))
    # Rectangular mirror plate with a 3 px iron frame.
    px0, py0 = x0 + 23, y0 + 50
    px1, py1 = x1 - 23, y1 - 18
    rect(draw, px0, py0, px1, py1, IRON_1)
    rect(draw, px0, py0, px1, py0, IRON_3)
    rect(draw, px0, py0, px0, py1, IRON_2)
    rect(draw, px1, py0, px1, py1, IRON)
    rect(draw, px0, py1, px1, py1, IRON)
    # Glass: dark neutral charcoal, no sky and no cyan.
    for y in range(py0 + 3, py1 - 2):
        t = (y - py0) / float(max(1, py1 - py0))
        color = lerp(GLASS_TOP, GLASS_LOW, t)
        rect(draw, px0 + 3, y, px1 - 3, y, color)
    # Bevel: top/left 1 px pale, bottom/right 1 px nearly black.
    rect(draw, px0 + 3, py0 + 3, px1 - 3, py0 + 3, GLASS_HI)
    rect(draw, px0 + 3, py0 + 4, px0 + 3, py1 - 3, GLASS_HI)
    rect(draw, px0 + 3, py1 - 3, px1 - 3, py1 - 3, IRON)
    rect(draw, px1 - 3, py0 + 3, px1 - 3, py1 - 3, IRON)
    # Soft diagonal sheen: a 3 px band, not a single scratch.  It is the only
    # large diagonal in the plate, so the surface reads as glass.
    for y in range(py0 + 8, py1 - 6):
        sx = px0 + 12 + (y - py0) // 2
        for dx, color in ((-1, (47, 48, 51, 255)), (0, (56, 56, 58, 255)),
                          (1, (47, 48, 51, 255))):
            if px0 + 5 < sx + dx < px1 - 5:
                px(draw, sx + dx, y, color)
    # A short second reflection near the right edge, broken into segments.
    for y in range(py0 + 30, py1 - 40):
        if (y // 8) % 3 == 0:
            continue
        sx = px0 + 82 + (y - py0) // 4
        if px0 + 5 < sx < px1 - 5:
            px(draw, sx, y, (45, 46, 49, 255))
    # Warm firelight reflection along the bottom edge.
    for y in range(py1 - 26, py1 - 2):
        for x in range(px0 + 4, px1 - 3):
            if (x + y) % 4 == 0:
                old = img.getpixel((x, y))
                draw.point((x, y), fill=(
                    (old[0] * 7 + GLASS_WARM[0]) // 8,
                    (old[1] * 7 + GLASS_WARM[1]) // 8,
                    (old[2] * 7 + GLASS_WARM[2]) // 8, 255,
                ))
    # Corner clips, a small bottom bracket and a top crest.
    for cx, cy in ((px0, py0), (px1, py0), (px0, py1), (px1, py1)):
        rect(draw, cx - 2, cy - 1, cx + 2, cy + 1, IRON_2)
        px(draw, cx, cy, RIVET)
        px(draw, cx - 1, cy - 1, IRON_3)
    rect(draw, (px0 + px1) // 2 - 6, py1 + 1, (px0 + px1) // 2 + 6, py1 + 4, IRON_1)
    rect(draw, (px0 + px1) // 2 - 6, py1 + 1, (px0 + px1) // 2 + 6, py1 + 1, IRON_3)
    ccx = (px0 + px1) // 2
    rect(draw, ccx - 5, py0 - 5, ccx + 5, py0 - 3, IRON_1)
    rect(draw, ccx - 5, py0 - 5, ccx + 5, py0 - 5, IRON_3)
    px(draw, ccx, py0 - 4, RIVET)
    # Sill / base.
    rect(draw, x0 - 4, y1 - 4, x1 + 4, y1 + 1, STONE_2)
    rect(draw, x0 - 4, y1 - 4, x1 + 4, y1 - 4, STONE_5)
    rect(draw, x0 - 2, y1, x1 + 2, y1, GOLD_DARK)
    rect(draw, x0 - 4, y1 + 1, x1 + 4, y1 + 2, STONE_0)
    # Crown finial.
    rect(draw, (x0 + x1) // 2 - 2, y0 - 9, (x0 + x1) // 2 + 2, y0 - 4, IRON_1)
    rect(draw, (x0 + x1) // 2 - 1, y0 - 11, (x0 + x1) // 2 + 1, y0 - 9, IRON_2)
    px(draw, (x0 + x1) // 2, y0 - 10, RIVET)


# --- mid layer -------------------------------------------------------------
def make_mid() -> Image.Image:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # A continuous wall plate makes the room read as one timber structure.
    wood_beam(img, 0, W - 1, 30, 24)
    # Sparse posts at the bay joints; the bridge-mouth post continues down into
    # the open pit instead of ending on a floating stone base.
    for x, width, bottom in ((18, 26, 319), (420, 24, 319), (660, 26, 359),
                             (1200, 26, 319), (1862, 24, 319)):
        wood_post(img, x, width, 54, bottom)
    brace(img, 420, 56, 150)
    brace(img, 660, 56, 170)
    brace(img, 1200, 56, 160)
    # Hanging chains: three per typical screen at most, all above the play band.
    for x, end in ((180, 152), (470, 118), (620, 176), (840, 142), (1010, 158),
                   (1290, 166), (1810, 150)):
        chain(img, x, 54, end)
    lantern(img, 180, 152)
    lantern(img, 1010, 158)
    pulley(img, 840, 142)
    # Smoky soot above the forge, kept as a soft value change.
    glow(img, 46, 220, 96, 120, (10, 8, 9, 255), 18)
    # A quiet workbench and tool board in the entry bay.  Everything stays
    # above the floor and low-contrast, so it reads as set dressing.
    rect(draw, 436, 214, 512, 218, WOOD_2)
    rect(draw, 436, 214, 512, 214, WOOD_4)
    rect(draw, 436, 218, 512, 218, WOOD_DARK)
    for tx in (446, 462, 478, 494):
        rect(draw, tx, 219, tx, 246, IRON_1)
        px(draw, tx, 219, IRON_2)
    rect(draw, 456, 244, 468, 252, IRON_1)
    rect(draw, 456, 244, 468, 244, IRON_2)
    # Bench top, legs, anvil and a closed box.
    rect(draw, 430, 286, 526, 293, WOOD_2)
    rect(draw, 430, 286, 526, 286, WOOD_4)
    rect(draw, 430, 293, 526, 293, WOOD_DARK)
    rect(draw, 434, 294, 440, 319, WOOD_1)
    rect(draw, 516, 294, 522, 319, WOOD_1)
    rect(draw, 434, 294, 434, 319, WOOD_3)
    rect(draw, 466, 278, 484, 286, IRON_1)
    rect(draw, 466, 278, 484, 278, IRON_2)
    rect(draw, 470, 274, 480, 278, IRON_2)
    px(draw, 474, 275, IRON_3)
    rect(draw, 488, 280, 508, 286, WOOD_0)
    rect(draw, 488, 280, 508, 280, WOOD_3)
    # A second, lower chain with a counterweight at the bridge mouth.
    chain(img, 620, 176, 214)
    rect(draw, 613, 214, 627, 232, IRON_1)
    rect(draw, 613, 214, 627, 214, IRON_2)
    rect(draw, 615, 220, 625, 221, IRON_0)
    # Warm bounce on the lower edge of the wall plate from the forge.
    glow(img, 60, 54, 180, 60, FIRE_MID, 8)
    return img


# --- foreground / floor ----------------------------------------------------
def make_fore() -> Image.Image:
    img = Image.new("RGBA", (FW, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Dark timber top beam; screen-fixed, so the frame reads at every camera.
    rect(draw, 0, 0, FW - 1, 15, WOOD_1)
    rect(draw, 0, 0, FW - 1, 0, WOOD_4)
    rect(draw, 0, 1, FW - 1, 1, WOOD_3)
    rect(draw, 0, 15, FW - 1, 15, WOOD_DARK)
    for gy in range(5, 13, 4):
        rect(draw, 0, gy, FW - 1, gy, WOOD_0)
    for sx in range(28, FW, 96):
        rect(draw, sx, 0, sx + 6, 15, IRON_2)
        rect(draw, sx, 0, sx + 6, 0, IRON_3)
        rect(draw, sx, 15, sx + 6, 15, IRON_0)
        px(draw, sx + 3, 8, RIVET)
    # Side posts; the outer 1 px catches the key light, the inner edge is dark.
    for side in (0, 1):
        x0 = 0 if side == 0 else FW - 10
        rect(draw, x0, 0, x0 + 9, H - 1, WOOD_0)
        if side == 0:
            rect(draw, x0, 0, x0, H - 1, WOOD_4)
            rect(draw, x0 + 9, 0, x0 + 9, H - 1, WOOD_DARK)
        else:
            rect(draw, x0, 0, x0, H - 1, WOOD_HI)
            rect(draw, x0 + 9, 0, x0 + 9, H - 1, WOOD_DARK)
        for gy in range(20, H - 10, 11):
            rect(draw, x0 + 2, gy, x0 + 7, gy, WOOD_1)
        for band_y in (44, 156, 268):
            rect(draw, x0 - 1, band_y, x0 + 10, band_y + 4, IRON_2)
            rect(draw, x0 - 1, band_y, x0 + 10, band_y, IRON_3)
            rect(draw, x0 - 1, band_y + 4, x0 + 10, band_y + 4, IRON_0)
            px(draw, x0 + 3, band_y + 2, RIVET)
    # Corner brackets.
    for side in (0, 1):
        x0 = 0 if side == 0 else FW - 22
        for index in range(12):
            xx = x0 + (index if side == 0 else 21 - index)
            rect(draw, xx, 16 + index, xx + 2, 16 + index, WOOD_2)
            px(draw, xx, 16 + index, WOOD_3)
    return img


def make_floor() -> Image.Image:
    img = Image.new("RGBA", (W, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rng = random.Random(27)
    # The floor is visible under the start ground (0..559) and the approach /
    # arena (1080..1879).  The bridge chasm stays open.
    spans = ((0, 559), (1080, W - 1))
    for x0, x1 in spans:
        rect(draw, x0, 0, x1, 7, FLOOR_4)
        rect(draw, x0, 0, x1, 0, FLOOR_HI)
        rect(draw, x0, 1, x1, 1, FLOOR_5)
        for x in range(x0, x1 + 1, 64):
            rect(draw, x, 0, x, 7, FLOOR_1)
            jx = min(x1, x + 63)
            rect(draw, x, 7, jx, 7, (55, 47, 52, 255))
            if x + 4 <= x1:
                px(draw, x + 4, 3, FLOOR_6)
            if x + 22 <= x1 and rng.random() < 0.45:
                px(draw, x + 22, 5, FLOOR_3)
        rect(draw, x0, 8, x1, 11, FLOOR_2)
        rect(draw, x0, 8, x1, 8, FLOOR_4)
        rect(draw, x0, 12, x1, 15, FLOOR_0)
        rect(draw, x0, 12, x1, 12, (60, 52, 57, 255))
        for x in range(x0, x1 + 1, 64):
            rect(draw, x, 8, x, 11, FLOOR_1)
            rect(draw, x + 32, 12, x + 32, 15, FLOOR_1)
        # Recessed iron channel and grate.
        rect(draw, x0, 16, x1, 23, (24, 21, 24, 255))
        rect(draw, x0, 16, x1, 16, FLOOR_3)
        rect(draw, x0, 23, x1, 23, FLOOR_0)
        for x in range(x0 + 4, x1 + 1, 20):
            rect(draw, x, 18, x, 21, IRON_2)
            px(draw, x, 18, IRON_3)
            if (x - x0) % 80 == 4:
                px(draw, x, 20, IRON_1)
        # Front face.
        rect(draw, x0, 24, x1, 39, FLOOR_1)
        rect(draw, x0, 24, x1, 24, FLOOR_3)
        rect(draw, x0, 25, x1, 25, FLOOR_4)
        rect(draw, x0, 38, x1, 39, INK)
        for x in range(x0, x1 + 1, 72):
            bx1 = min(x1, x + 60)
            rect(draw, x + 8, 28, bx1, 36, FLOOR_0)
            rect(draw, x + 8, 28, bx1, 28, FLOOR_2)
            rect(draw, x + 8, 36, bx1, 36, SHADOW)
            px(draw, min(x1, x + 14), 31, FLOOR_4)
    # Cut faces where the floor meets the pit.
    for edge, dark_side in ((559, 1), (1080, -1)):
        rect(draw, edge - 2, 0, edge + 2, 39, FLOOR_0)
        rect(draw, edge - 2, 0, edge + 2, 0, FLOOR_HI)
        if dark_side > 0:
            rect(draw, edge + 1, 1, edge + 2, 39, INK)
        else:
            rect(draw, edge - 2, 1, edge - 1, 39, INK)
    # A warm low wash under the start forge, still below the gameplay band.
    for x in range(0, 180):
        for y in range(0, 8):
            a = max(0, 10 - abs(x - 80) // 18 - y)
            if a > 0:
                old = img.getpixel((x, y))
                if old[3] == 0:
                    continue
                draw.point((x, y), fill=(
                    (old[0] * (255 - a) + FIRE[0] * a) // 255,
                    (old[1] * (255 - a) + FIRE[1] * a) // 255,
                    (old[2] * (255 - a) + FIRE[2] * a) // 255, 255,
                ))
    return img


def make_haze() -> Image.Image:
    """Warm dust haze for RiftFog; only behind the world (Background layer)."""
    img = Image.new("RGBA", (FW, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Stepped vertical warm haze: nearly clear at the top, slightly stronger
    # near the floor.  RiftFog adds the moving motes.
    for y in range(H):
        if y < 180:
            a = 0
        else:
            a = min(14, 2 + (y - 180) * 12 // 180)
        if a <= 0:
            continue
        rect(draw, 0, y, FW - 1, y, (224, 150, 84, a))
    # A faint local warm patch at the left forge.
    glow(img, 44, 300, 120, 70, FIRE_MID, 8)
    return img


def make_post_tall() -> Image.Image:
    """52x112 workshop support: dark timber, iron bands, stone footing.

    Same footprint as the doric column it replaces in this chapter; the node
    names and positions in rift_workshop.tscn do not change.
    """
    img = Image.new("RGBA", (52, 112), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Stone footing.
    rect(draw, 0, 92, 51, 111, STONE_2)
    rect(draw, 0, 92, 51, 92, STONE_5)
    rect(draw, 4, 97, 47, 105, STONE_1)
    rect(draw, 4, 97, 47, 97, STONE_3)
    rect(draw, 0, 110, 51, 111, INK)
    # Timber shaft.
    rect(draw, 10, 12, 41, 92, WOOD_1)
    rect(draw, 10, 12, 12, 92, WOOD_3)
    rect(draw, 10, 12, 41, 12, WOOD_4)
    rect(draw, 39, 12, 41, 92, WOOD_0)
    rect(draw, 41, 12, 41, 92, WOOD_DARK)
    for gy in range(18, 88, 7):
        rect(draw, 14, gy, 37, gy, WOOD_0 if (gy // 7) % 2 == 0 else WOOD_2)
    # Iron bands.
    for by in (28, 52, 76):
        rect(draw, 8, by, 43, by + 4, IRON_2)
        rect(draw, 8, by, 43, by, IRON_3)
        rect(draw, 8, by + 4, 43, by + 4, IRON_0)
        px(draw, 13, by + 2, RIVET)
        px(draw, 38, by + 2, RIVET)
    # Timber head and iron cap.
    rect(draw, 2, 2, 49, 9, WOOD_2)
    rect(draw, 2, 2, 49, 2, WOOD_4)
    rect(draw, 2, 9, 49, 9, WOOD_DARK)
    rect(draw, 4, 10, 47, 13, IRON_2)
    rect(draw, 4, 10, 47, 10, IRON_3)
    rect(draw, 4, 13, 47, 13, IRON_0)
    for rx in (9, 42):
        px(draw, rx, 11, RIVET)
    # Small diagonal knee braces.
    for index in range(10):
        rect(draw, 12 + index, 14 + index, 14 + index, 14 + index, WOOD_0)
        px(draw, 12 + index, 14 + index, WOOD_3)
        rect(draw, 39 - index, 14 + index, 41 - index, 14 + index, WOOD_0)
        px(draw, 39 - index, 14 + index, WOOD_3)
    return img


def make_post_broken() -> Image.Image:
    """52x84 broken workshop post with the same footing as the tall version."""
    img = Image.new("RGBA", (52, 84), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rect(draw, 0, 64, 51, 83, STONE_2)
    rect(draw, 0, 64, 51, 64, STONE_5)
    rect(draw, 4, 69, 47, 77, STONE_1)
    rect(draw, 4, 69, 47, 69, STONE_3)
    rect(draw, 0, 82, 51, 83, INK)
    rect(draw, 10, 16, 41, 64, WOOD_1)
    rect(draw, 10, 16, 12, 64, WOOD_3)
    rect(draw, 39, 16, 41, 64, WOOD_0)
    rect(draw, 41, 16, 41, 64, WOOD_DARK)
    for gy in range(22, 60, 7):
        rect(draw, 14, gy, 37, gy, WOOD_0 if (gy // 7) % 2 == 0 else WOOD_2)
    for by in (34, 54):
        rect(draw, 8, by, 43, by + 4, IRON_2)
        rect(draw, 8, by, 43, by, IRON_3)
        rect(draw, 8, by + 4, 43, by + 4, IRON_0)
        px(draw, 13, by + 2, RIVET)
        px(draw, 38, by + 2, RIVET)
    # Splintered top.
    for sx, sy in ((10, 22), (14, 16), (18, 24), (22, 14), (26, 21), (30, 15),
                   (34, 23), (38, 17), (41, 26)):
        rect(draw, sx, sy, sx + 2, 16 + 8, WOOD_1)
        px(draw, sx, sy, WOOD_3)
    rect(draw, 10, 24, 41, 28, WOOD_0)
    rect(draw, 10, 24, 41, 24, WOOD_2)
    # A short hanging chain from the break.
    chain(img, 26, 16, 34)
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    assets = {
        "interior_back_1880x360.png": make_back(),
        "interior_mid_1880x360.png": make_mid(),
        "interior_fore_640x360.png": make_fore(),
        "interior_floor_1880x40.png": make_floor(),
        "interior_warm_haze_640x360.png": make_haze(),
        "interior_post_tall_52x112.png": make_post_tall(),
        "interior_post_broken_52x84.png": make_post_broken(),
    }
    for name, image in assets.items():
        image.save(os.path.join(OUT, name))
        print("WROTE", name, image.size)
    print("RIFT_INTERIOR_DONE", OUT)


if __name__ == "__main__":
    main()
