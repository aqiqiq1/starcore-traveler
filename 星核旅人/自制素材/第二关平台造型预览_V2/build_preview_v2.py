# -*- coding: utf-8 -*-
"""
Level 02 platform silhouette preview V2  (static art preview, not implemented)

Direction:
    The upper deck is read as the carved parapet and road of ONE ruined stone
    aqueduct: four piers, four arches (the last one broken), a carved frieze
    with a central star medallion.  The five real 8x6 apertures stay open for
    the polarity field and receive only a 1 px inner reveal.  The seven deck
    blocks, the y264 stand line, every collision rectangle and the 20 px low
    corridor are untouched.  Decoration is a separate transparent layer that
    stops at y299.

READ-ONLY sources:
    基础场景原型/screenshots/ds03_godot_background_only.png
    基础场景原型/assets/map/ruin_platform_tiles.png
    基础场景原型/assets/...  (bay, stele, exit, player)
Method reference only (NOT copied art): 自制素材/第二关地形美化预览_V1/build_preview_v1.py
    -> object anchors / compositing order only.  draw_ground() is NOT reused:
       the ground here is rebuilt pixel-exactly from the project atlas.

Writes only:
    自制素材/第二关平台造型预览_V2/
"""
from __future__ import annotations

import hashlib
import json
import math
import os
from math import ceil
from PIL import Image

ROOT = r"D:\godot game\星核旅人"
SRC = os.path.join(ROOT, "基础场景原型")
OUT = os.path.join(ROOT, "自制素材", "第二关平台造型预览_V2")
PROTECTED = (r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
             r"\level02-art-preview-ae17ade72c2e48d8b742f3302031b847\protected.json")
V1_OBJECTS = os.path.join(ROOT, "自制素材", "第二关地形美化预览_V1", "objects_overlay_v1.png")

W, H = 640, 360

# ---------------------------------------------------------------- approved ramp
# Sampled from assets/doric_columns/doric_column_tall.png and
# assets/checkpoint_exit/exit_open.png (warm grey stone, mauve shadow).
HI = (174, 161, 151)
HI2 = (167, 154, 146)
LIT = (160, 145, 138)
LIT2 = (151, 136, 130)
FACE = (143, 128, 126)
FACE_D = (137, 127, 124)
MID = (128, 112, 113)
MID2 = (122, 104, 107)
LOW = (113, 96, 100)
LOW2 = (103, 87, 93)
SEAM = (89, 74, 81)
DEEP = (66, 55, 62)
SOFFIT = (52, 44, 53)

CYAN = (124, 172, 170)      # same family as the approved gate's cyan mark
CYAN_DIM = (95, 133, 133)
SAGE = (105, 126, 107)
SAGE_D = (84, 104, 86)
SAGE_DD = (66, 82, 69)
MOSS = (58, 74, 56)

# ---------------------------------------------------------------- geometry (physics reference only)
FLOOR_Y = 320
HIGH_STEP = (152, 274, 56, 14)
PIERS = [(232, 264, 8, 36), (296, 264, 8, 36)]
BEAMS = [(240, 264, 16, 6), (264, 264, 16, 6), (288, 264, 8, 6),
         (304, 264, 16, 6), (328, 264, 16, 6), (352, 264, 16, 6),
         (376, 264, 24, 6)]
GAPS = [(256, 264, 8, 6), (280, 264, 8, 6), (320, 264, 8, 6),
        (344, 264, 8, 6), (368, 264, 8, 6)]
RIGHT_LEDGE = (400, 276, 32, 10)
DECK_X0, DECK_X1 = 232, 400


def shade(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


def blend(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


# ---------------------------------------------------------------- canvas
class Canvas:
    def __init__(self, w=W, h=H):
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def put(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            if a <= 0:
                self.img.putpixel((x, y), (0, 0, 0, 0))
            else:
                self.img.putpixel((x, y), (c[0], c[1], c[2], a))

    def erase(self, x, y):
        self.put(x, y, (0, 0, 0), 0)

    def fill(self, x, y, w, h, c, a=255):
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        if x1 <= x0 or y1 <= y0:
            return
        if a <= 0:
            self.img.paste((0, 0, 0, 0), (x0, y0, x1, y1))
        else:
            self.img.paste((c[0], c[1], c[2], a), (x0, y0, x1, y1))

    def hline(self, x, y, w, c, a=255):
        self.fill(x, y, w, 1, c, a)

    def vline(self, x, y, h, c, a=255):
        self.fill(x, y, 1, h, c, a)

    def paste(self, img, x, y):
        self.img.alpha_composite(img, (x, y))


# ---------------------------------------------------------------- project atlas, exact
def load_atlas():
    p = os.path.join(SRC, "assets", "map", "ruin_platform_tiles.png")
    im = Image.open(p).convert("RGBA")
    assert im.size == (192, 32), im.size
    return im


def draw_ground(atlas):
    """Exact TerrainTop + TerrainFill from level_02.tscn / terrain_strip.gd.

    TerrainTop : pos (0,320), region (16,0,16,16), 640x16
    TerrainFill: pos (0,336), region (16,16,16,16), 640x24 (last row clipped by viewport)
    Native 16 px repetition, NEAREST, no scaling, no tint.
    """
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    top = atlas.crop((16, 0, 32, 16))
    fill = atlas.crop((16, 16, 32, 32))
    for k in range(ceil(640 / 16)):
        layer.alpha_composite(top, (k * 16, 320))
    for k in range(ceil(640 / 16)):
        layer.alpha_composite(fill, (k * 16, 336))
        layer.alpha_composite(fill, (k * 16, 352))
    return layer.crop((0, 0, W, H))


def draw_block(layer, atlas, x0, y0, w, h):
    """Pixel-exact replica of scripts/level02_block.gd::_draw for a block."""
    cols = ceil(w / 16)
    rows = ceil(h / 16)
    for row in range(rows):
        ly = row * 16
        th = min(16, h - ly)
        if th <= 0:
            continue
        for col in range(cols):
            lx = col * 16
            tw = min(16, w - lx)
            if tw <= 0:
                continue
            if row == 0:
                if col == 0:
                    ac = 0
                elif col == cols - 1:
                    ac = 11
                else:
                    ac = 1 + ((col - 1) % 10)
            else:
                if col == 0:
                    ac = 0
                elif col == cols - 1:
                    ac = 11
                else:
                    ac = 1 + ((col + row * 3) % 10)
            ar = 0 if row == 0 else 1
            tile = atlas.crop((ac * 16, ar * 16, ac * 16 + tw, ar * 16 + th))
            layer.alpha_composite(tile, (x0 + lx, y0 + ly))


def draw_platform_surface(atlas):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for rect in [HIGH_STEP] + PIERS + BEAMS + [RIGHT_LEDGE]:
        draw_block(layer, atlas, *rect)
    return layer


# ---------------------------------------------------------------- carving helpers
def chip(cv, x, y, c=None):
    cv.put(x, y, c or SEAM)


def tool_marks(cv, x, y, w, seed, c=None):
    """Sparse 1 px chisel marks inside a face; never a wood-grain field."""
    seq = ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0))
    n = 2 + (seed % 3)
    for i in range(n):
        dx, dy = seq[(seed * 3 + i * 2) % len(seq)]
        px = x + (seed * 5 + i * 7) % max(1, w)
        if 0 <= px < x + w:
            cv.put(px, y + dy, c or shade(FACE_D, -6))


def sage_tuft(cv, x, y):
    cv.put(x, y, SAGE)
    cv.put(x + 1, y, SAGE_D)
    cv.put(x, y + 1, SAGE_D)
    cv.put(x + 1, y + 1, SAGE_DD)
    cv.put(x + 2, y, MOSS)


def rosette(cv, cx, cy, r=3, eye=CYAN):
    """6/8 px carved rosette: light petals around a dark/cyan eye."""
    cv.put(cx, cy, eye)
    cv.put(cx, cy - 1, HI2)
    cv.put(cx, cy + 1, LIT)
    cv.put(cx - 1, cy, HI2)
    cv.put(cx + 1, cy, LIT2)
    if r >= 3:
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            cv.put(cx + dx, cy + dy, FACE)
        cv.put(cx, cy - 2, LIT2)
        cv.put(cx, cy + 2, MID)
        cv.put(cx - 2, cy, LIT2)
        cv.put(cx + 2, cy, MID)
    if r >= 4:
        cv.put(cx, cy - 3, FACE)
        cv.put(cx, cy + 3, MID2)
        cv.put(cx - 3, cy, FACE)
        cv.put(cx + 3, cy, MID2)


def metope(cv, x, y, w, h, seed, big=False):
    """Recessed panel with a light frame; face a shade darker than the rail."""
    # lit inner frame (top/left), shadow (bottom/right)
    cv.hline(x, y, w, shade(MID, 6))
    cv.vline(x, y + 1, h - 1, shade(MID, 4))
    cv.hline(x + 1, y + h - 1, w - 1, shade(SEAM, 3))
    cv.vline(x + w - 1, y + 1, h - 1, shade(SEAM, 5))
    cv.fill(x + 1, y + 1, w - 2, h - 2, shade(LOW2, -8))
    if big:
        cv.fill(x + 1, y + 1, w - 2, 1, shade(FACE, -12))
    # quiet tool work
    tool_marks(cv, x + 2, y + 2, max(1, w - 4), seed, shade(FACE, -15))


def draw_arch(cv, x0, x1, rise, keystone=True, broke=None, portal=False):
    """Carved elliptical arch, 4 px ring + spandrel, springing at y299.

    Decoration only: no collision, and nothing below y299.  The spandrel is the
    stone between the arch extrados and the screen bottom at y281.
    """
    span = x1 - x0

    def intrados(x):
        # pixel-art elliptical arch: steep at the spring, round at the crown.
        # At this size a sine/flat-crown profile reads as a pointed arch.
        half = span / 2.0
        u = (x - (x0 + half)) / half
        return int(round(299 - rise * math.sqrt(max(0.0, 1.0 - u * u))))

    for x in range(x0, x1):
        yi = intrados(x)
        ye = yi - 4
        # spandrel body: mid-dark stone, clearly behind the lit arch ring
        for y in range(281, ye):
            v = (y - 281) / 18.0
            c = blend(LOW, SEAM, min(1.0, 0.18 + v * 1.0))
            if y == 281:
                c = shade(SEAM, 7)
            cv.put(x, y, c)
        # 1 px shadow above the ring so the arch reads as a raised band
        if ye - 1 >= 281:
            cv.put(x, ye - 1, shade(SEAM, 1))
        # 4 px voussoir ring, alternating stone tones
        seg = (x - x0) // 7
        tone = 6 if seg % 2 == 0 else -5
        cv.put(x, ye, shade(HI2, tone + 2))
        cv.put(x, ye + 1, shade(LIT, tone))
        cv.put(x, ye + 2, shade(FACE_D, tone))
        cv.put(x, ye + 3, shade(LOW2, tone // 2))
        cv.put(x, yi, DEEP)
        if (x - x0) % 7 == 0 and x0 + 3 < x < x1 - 3 and abs(x - (x0 + span // 2)) > 2:
            for y in range(ye, yi):
                cv.put(x, y, shade(SEAM, 2))
            cv.put(x + 1, ye, HI)
        if broke is not None and x >= broke:
            for y in range(ye, yi + 1):
                cv.put(x, y, (0, 0, 0), 0)

    # weathered chips on the ring (outer silhouette only)
    for x, y in ((x0 + 5, intrados(x0 + 5) - 4), (x1 - 8, intrados(x1 - 8) - 4)):
        if 281 <= y < 299:
            cv.put(x, y, (0, 0, 0), 0)
            cv.put(x + 1, y, shade(HI2, -6))

    if keystone:
        kx = x0 + span // 2
        ik = intrados(kx)
        for y in range(ik - 3, ik):
            for dx in (-3, -2, -1, 0, 1, 2):
                c = LIT if dx < 0 else FACE_D
                if dx == -3:
                    c = SEAM
                if dx == 2:
                    c = shade(SEAM, -2)
                cv.put(kx + dx, y, c)
        cv.put(kx - 2, ik - 2, HI2)
        cv.put(kx, ik - 1, CYAN_DIM)
        cv.put(kx - 1, ik - 1, shade(CYAN_DIM, -10))


def draw_pier(cv, left, w=8):
    """One 8 px stone pier / abutment between arches; stops at y299."""
    for y in range(281, 298):
        v = (y - 281) / 17.0
        base = blend(FACE_D, LOW2, v * 0.9)
        cv.fill(left, y, w, 1, base)
        cv.put(left, y, SEAM)
        cv.put(left + 1, y, shade(base, 10))
        cv.put(left + w - 2, y, shade(base, -15))
        cv.put(left + w - 1, y, shade(SEAM, -2))
        cv.put(left + w // 2, y, shade(base, -9))
        cv.put(left + w // 2 + 1, y, shade(base, 4))
    for jy in (288, 293):
        cv.hline(left + 1, jy, w - 2, shade(SEAM, 4))
        cv.hline(left + 1, jy + 1, w - 2, shade(LIT2, -10))
    # blunt, shadowed foot: no bright table-leg base
    cv.fill(left, 298, w, 1, LOW2)
    cv.fill(left + 1, 299, w - 2, 1, DEEP)
    cv.put(left, 298, (0, 0, 0), 0)
    cv.put(left + w - 1, 298, (0, 0, 0), 0)
    sage_tuft(cv, left + w - 3, 296)


def draw_pier(cv, left, w=8):
    """One 8 px stone pier / abutment between arches; stops at y299."""
    for y in range(281, 297):
        v = (y - 281) / 16.0
        base = blend(LIT2, FACE_D, v * 0.8)
        cv.fill(left, y, w, 1, base)
        cv.put(left, y, SEAM)
        cv.put(left + 1, y, shade(base, 12))
        cv.put(left + w - 2, y, shade(base, -16))
        cv.put(left + w - 1, y, shade(SEAM, -2))
        cv.put(left + w // 2, y, shade(base, -8))
        cv.put(left + w // 2 + 1, y, shade(base, 5))
    # two real joints
    for jy in (288, 293):
        cv.hline(left + 1, jy, w - 2, shade(SEAM, 3))
        cv.hline(left + 1, jy + 1, w - 2, shade(LIT2, -9))
    # base, 10 px wide, stops at y299
    cv.fill(left - 1, 297, w + 2, 1, SEAM)
    cv.fill(left - 1, 298, w + 2, 1, HI2)
    cv.fill(left - 1, 299, w + 2, 1, LIT)
    cv.put(left - 1, 297, (0, 0, 0), 0)
    cv.put(left + w, 297, (0, 0, 0), 0)
    cv.put(left + w, 298, (0, 0, 0), 0)
    sage_tuft(cv, left + w - 3, 296)


# ---------------------------------------------------------------- main entablature
def draw_frieze(cv):
    """Non-collision carved aqueduct facade around the real 6 px deck.

    The seven solid blocks and their y264 stand line are untouched.  The five
    8x6 gaps stay open for the polarity field (only a 1 px inner reveal); the
    carved frieze (y270..281), four 8 px piers and the arches (y281..299) turn
    the row into one aqueduct ruin, with the last arch broken.  Decoration
    stops at y299; the 20 px low corridor (300..319) is untouched.
    """
    x0, x1 = DECK_X0, DECK_X1

    # The real dark deck face (atlas) stays visible at 265..269; only the
    # 1 px top line at y264 and the five real notches are read as the road.

    # ---------------- thick carved entablature, continuous 232..400
    for x in range(x0, x1):
        cv.put(x, 270, SOFFIT)
        cv.put(x, 271, shade(SEAM, -7))
        cv.put(x, 272, HI)
        cv.put(x, 273, LIT2)
        cv.put(x, 274, FACE_D)
        cv.put(x, 275, MID)
        cv.put(x, 276, MID)
        cv.put(x, 277, MID2)
        cv.put(x, 278, LOW)
        cv.put(x, 279, LOW2)
        cv.put(x, 280, SEAM)
        cv.put(x, 281, shade(SEAM, -4))

    # ---------------- four bays with recessed panels, framed by pilasters
    # that continue the arcade verticals up into the parapet
    for px, pw, cx, big in ((244, 48, 268, True), (308, 20, 318, False),
                            (344, 24, 356, False), (384, 12, 390, False)):
        metope(cv, px, 274, pw, 7, 100 + cx, big=big)
        cv.hline(px + 1, 275, pw - 2, shade(FACE, -16))
        if pw >= 20:
            if big:
                cv.fill(cx - 5, 275, 11, 1, HI2)
                cv.fill(cx - 5, 279, 11, 1, SEAM)
                rosette(cv, cx, 277, 4, CYAN)
                cv.put(cx - 1, 277, HI2)
                cv.put(cx + 1, 277, LIT2)
            else:
                rosette(cv, cx, 277, 2, shade(CYAN_DIM, 8))
        else:
            cv.vline(cx, 275, 4, shade(SEAM, 3))
            cv.vline(cx + 1, 275, 4, shade(LIT2, -4))
    # pilasters at the four pier axes, 3 px wide, with small capital/base
    for cx in (236, 300, 336, 376):
        cv.hline(cx - 1, 273, 3, HI)
        cv.vline(cx - 1, 274, 7, HI2)
        cv.vline(cx, 274, 7, LIT2)
        cv.vline(cx + 1, 274, 7, SEAM)
        cv.hline(cx - 1, 280, 3, SEAM)
        cv.put(cx - 1, 273, LIT)
        cv.put(cx + 1, 273, shade(SEAM, 3))

    # ---------------- pilaster strips between panels (vertical rhythm)
    for px in (304, 348):
        cv.fill(px, 274, 4, 8, shade(MID, -4))
        cv.hline(px, 274, 4, HI2)
        cv.vline(px, 275, 7, LIT2)
        cv.vline(px + 3, 274, 8, SEAM)
        cv.hline(px, 281, 4, SEAM)
        cv.put(px + 1, 278, shade(FACE, -10))
        cv.put(px + 2, 278, shade(SEAM, 6))
        # small corbel foot below the strip
        cv.fill(px, 282, 4, 1, LOW2)
        cv.fill(px + 1, 283, 2, 1, SEAM)

    # ---------------- four-pier arcade under the carved screen.
    # The two real piers are at 232 and 296; two decorative piers at 332 and
    # 372 carry the right run so the deck reads as one aqueduct, not a long
    # table.  All decoration stops at y299, above the 20 px low corridor.
    draw_arch(cv, 240, 296, 14, keystone=True, portal=True)
    draw_arch(cv, 304, 332, 12)
    draw_arch(cv, 340, 372, 14, keystone=False)
    draw_arch(cv, 380, 400, 9, broke=396)
    for left in (232, 296, 332, 372):
        draw_pier(cv, left)
    # sparse sage on the haunches, never on the stand line
    for sx, sy in ((250, 296), (288, 296), (348, 296), (386, 296)):
        cv.put(sx, sy, SAGE_D)
        cv.put(sx + 1, sy, SAGE_DD)

    # ---------------- broken bracket down to the right ledge (decor only).
    # Its top edge is deliberately slanted and chipped, so it reads as broken
    # masonry, not as an extra 6 px step the player could stand on.
    for x in range(398, 405):
        top = 270 + (x - 398)
        for y in range(top, 276):
            c = blend(MID, LOW2, (y - top) / 6.0)
            if y == top:
                c = LIT2
            if x == 398:
                c = shade(SEAM, -2)
            cv.put(x, y, c)
    cv.put(399, 271, HI2)
    cv.put(400, 272, LIT)
    cv.put(404, 275, (0, 0, 0), 0)
    cv.put(403, 275, (0, 0, 0), 0)
    cv.put(402, 274, SEAM)

    # ---------------- broken ends of the screen    # ---------------- broken ends of the screen
    for x, y in ((232, 281), (399, 281), (399, 282)):
        cv.put(x, y, (0, 0, 0), 0)
    cv.put(232, 280, SEAM)
    cv.put(399, 280, shade(SEAM, -3))
    cv.put(396, 282, (0, 0, 0), 0)
    cv.put(397, 283, (0, 0, 0), 0)
    cv.put(394, 282, (0, 0, 0), 0)
    # a couple of old cracks in the frieze
    cv.put(252, 276, shade(SEAM, 2))
    cv.put(252, 277, shade(SEAM, -3))
    cv.put(253, 278, shade(SEAM, -1))
    cv.put(362, 275, shade(SEAM, 3))
    cv.put(361, 276, shade(SEAM, -2))
    cv.put(361, 277, shade(SEAM, 2))


# ---------------------------------------------------------------- high step
def relief_arch(cv, x, y, w, h, keystone=True):
    """Blind carved arch on a solid block face (no see-through).

    The block stays a solid collision rectangle; only the front face is carved.
    """
    half = w / 2.0
    for i in range(w):
        u = (i - half + 0.5) / half
        ay = y + int(round((h - 1) * (1.0 - math.sqrt(max(0.0, 1.0 - u * u)))))
        # recessed interior under the arch
        for yy in range(ay + 3, y + h):
            v = (yy - ay) / max(1.0, h - 3)
            cv.put(x + i, yy, shade(MID2, -12) if v < 0.6 else shade(SEAM, -2))
        # 3 px lit arch ring
        cv.put(x + i, ay, HI2)
        cv.put(x + i, ay + 1, LIT)
        cv.put(x + i, ay + 2, FACE_D)
        # voussoir joints
        if i % 6 == 0 and 1 < i < w - 2:
            for yy in range(ay, ay + 3):
                cv.put(x + i, yy, shade(SEAM, 4))
            cv.put(x + i + 1, ay, HI)
    if keystone:
        kx = x + w // 2
        for yy in range(y + 1, y + 4):
            for dx in (-1, 0, 1):
                cv.put(kx + dx, yy, LIT if dx < 0 else FACE_D)
        cv.put(kx, y + 3, CYAN_DIM)
    # dark sill at the bottom
    cv.hline(x + 1, y + h - 1, w - 2, shade(SEAM, -4))


def draw_high_step(cv):
    x0, y0, w, h = HIGH_STEP
    # top y274..276 is the real atlas tread (stand line untouched)
    for x in range(x0, x0 + w):
        cv.put(x, 277, HI2)
        cv.put(x, 278, LIT2)
        cv.put(x, 279, FACE_D)
        cv.put(x, 280, FACE_D)
        cv.put(x, 281, MID)
        cv.put(x, 282, MID2)
        cv.put(x, 283, LOW)
        cv.put(x, 284, LOW2)
        cv.put(x, 285, SEAM)
        cv.put(x, 286, shade(SEAM, -5))
        cv.put(x, 287, shade(SEAM, -8))
    # one large blind arch makes it a fallen fragment of the same arcade,
    # not a bench with a drawer front
    relief_arch(cv, x0 + 8, 279, 40, 9, keystone=True)
    # old chisel scars
    cv.put(x0 + 51, 281, SEAM)
    cv.put(x0 + 52, 282, shade(SEAM, -4))
    cv.put(x0 + 54, 283, shade(SEAM, -2))
    # broken lower lip: three irregular chunks, transparent gaps between
    for gx, gw in ((x0 + 4, 3), (x0 + 24, 2), (x0 + 42, 4)):
        for x in range(gx, gx + gw):
            cv.put(x, 286, (0, 0, 0), 0)
        cv.put(gx, 287, (0, 0, 0), 0)
        cv.put(gx + gw - 1, 287, LIT2 if gw > 2 else SEAM)
    # chipped ends
    cv.put(x0, 287, (0, 0, 0), 0)
    cv.put(x0 + 1, 287, SEAM)
    cv.put(x0 + w - 1, 285, (0, 0, 0), 0)
    cv.put(x0 + w - 2, 286, (0, 0, 0), 0)
    cv.put(x0 + w - 3, 287, (0, 0, 0), 0)
    for y in range(277, 288):
        cv.put(x0, y, SEAM)
        cv.put(x0 + w - 1, y, shade(SEAM, -3))
    cv.put(x0 + 1, 277, HI)
    cv.put(x0 + w - 2, 277, LIT)
    sage_tuft(cv, x0 + 58, 284)
    cv.put(x0 + 6, 285, SAGE)
    cv.put(x0 + 6, 286, SAGE_D)


# ---------------------------------------------------------------- right ledge
def draw_right_ledge(cv):
    x0, y0, w, h = RIGHT_LEDGE
    for x in range(x0, x0 + w):
        cv.put(x, 279, HI2)
        cv.put(x, 280, LIT2)
        cv.put(x, 281, FACE_D)
        cv.put(x, 282, MID)
        cv.put(x, 283, MID2)
        cv.put(x, 284, LOW)
        cv.put(x, 285, LOW2)
        cv.put(x, 286, SEAM)
        cv.put(x, 287, shade(SEAM, -7))
    # one blind arch: a broken abutment fragment, same language as the bridge
    relief_arch(cv, x0 + 5, 280, 22, 7, keystone=True)
    cv.put(x0 + 29, 281, shade(SEAM, 2))
    cv.put(x0 + 30, 282, shade(LIT, -6))
    # broken left end and a chipped lower lip (no leg)
    cv.put(x0, 286, (0, 0, 0), 0)
    cv.put(x0 + 1, 287, (0, 0, 0), 0)
    cv.put(x0 + 1, 286, shade(SEAM, -3))
    for x in (x0 + 18, x0 + 19, x0 + 27):
        cv.put(x, 286, (0, 0, 0), 0)
    cv.put(x0 + 18, 287, (0, 0, 0), 0)
    cv.put(x0 + 27, 287, (0, 0, 0), 0)
    # right terminal: clean cut + lit arris
    for y in range(280, 288):
        cv.put(x0 + w - 1, y, shade(SEAM, -3))
        cv.put(x0 + w - 2, y, LIT2)
    cv.put(x0, 280, HI2)
    cv.put(x0 + 1, 280, HI)
    cv.put(x0 + w - 1, 286, (0, 0, 0), 0)
    sage_tuft(cv, x0 + 29, 284)
    cv.put(x0 + 12, 284, SAGE_D)


# ---------------------------------------------------------------- composition
def build_decor():
    cv = Canvas()
    draw_frieze(cv)
    draw_high_step(cv)
    draw_right_ledge(cv)
    return cv.img


# ---------------------------------------------------------------- objects (V1 anchors, unchanged)
def load_rgba(path):
    return Image.open(path).convert("RGBA")


def paste_center(dst, tex, cx, cy):
    dst.alpha_composite(tex, (cx - tex.width // 2, cy - tex.height // 2))


def build_objects():
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    base = load_rgba(os.path.join(SRC, "assets/star_core_bay/star_core_bay_base.png"))
    glass = load_rgba(os.path.join(SRC, "assets/star_core_bay/star_core_bay_glass.png"))
    sheet = load_rgba(os.path.join(SRC, "assets/star_core/star_core_locked_12f.png"))
    core = sheet.crop((0, 0, 16, 16))
    paste_center(layer, base, 118, 304)
    lx, ly = 118 + 4, 304 + 11
    layer.putpixel((lx + 1, ly), (247, 227, 162, 255))
    layer.putpixel((lx + 2, ly), (247, 227, 162, 255))
    layer.paste((226, 189, 106, 255), (lx, ly + 1, lx + 4, ly + 3))
    layer.putpixel((lx, ly + 1), (107, 127, 139, 255))
    layer.putpixel((lx + 3, ly + 1), (107, 127, 139, 255))
    layer.putpixel((lx + 3, ly + 2), (107, 127, 139, 255))
    layer.putpixel((lx + 1, ly + 1), (247, 227, 162, 255))
    layer.putpixel((lx + 1, ly + 2), (107, 127, 139, 255))
    layer.putpixel((lx + 2, ly + 2), (107, 127, 139, 255))
    paste_center(layer, core, 118, 304)
    paste_center(layer, glass, 118, 304)

    paste_center(layer, base, 520, 304)

    stele = load_rgba(os.path.join(SRC, "assets/tutorial_stele/tutorial_stele_grey.png"))
    layer.alpha_composite(stele, (80 - 13, 320 - 52))

    gate = load_rgba(os.path.join(SRC, "assets/checkpoint_exit/exit_open.png"))
    layer.alpha_composite(gate, (600 - 38, 320 - 99))

    idle = load_rgba(os.path.join(SRC, "assets/characters/male_hero-idle.png"))
    frame0 = idle.crop((0, 0, 128, 128))
    layer.alpha_composite(frame0, (36 - 59, 320 - 79))
    return layer


# ---------------------------------------------------------------- checks
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def alpha_mask(img):
    return img.getchannel("A")


def count_alpha(img, rect):
    x, y, w, h = rect
    a = img.crop((x, y, x + w, y + h)).getchannel("A")
    return sum(1 for v in a.getdata() if v)


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = load_rgba(os.path.join(SRC, "screenshots", "ds03_godot_background_only.png"))
    assert bg.size == (W, H), bg.size

    atlas = load_atlas()
    ground = draw_ground(atlas)
    surface = draw_platform_surface(atlas)
    decor = build_decor()
    objects = build_objects()

    # no decor may enter the floor or the ground-core band
    deco_px = decor.load()
    bad = [(x, y) for y in range(320, H) for x in range(W) if deco_px[x, y][3]]
    if bad:
        raise SystemExit(f"decor touches y>=320: {bad[:8]}")

    # decorative carving must never cover the real stand line at y264
    if any(deco_px[x, 264][3] for x in range(W)):
        raise SystemExit("decor covers the y264 stand line")

    # the five apertures stay open: only a 1 px dark reveal is allowed on the
    # top row and left column, the rest must be empty stone-free space
    for gx, gy, gw, gh in GAPS:
        for y in range(gy, gy + gh):
            for x in range(gx, gx + gw):
                if deco_px[x, y][3] != 0:
                    if y == 265 or x == gx:
                        continue
                    raise SystemExit(f"decor covers aperture at {x},{y}")
    surf_px = surface.load()
    for gx, gy, gw, gh in GAPS:
        for y in range(gy, gy + gh):
            for x in range(gx, gx + gw):
                if surf_px[x, y][3] != 0:
                    raise SystemExit(f"surface covers aperture at {x},{y}")

    # stand line: solid beams keep a real atlas top at y264, gaps do not
    for bx, by, bw, bh in BEAMS:
        for x in range(bx, bx + bw):
            if surf_px[x, 264][3] != 255:
                raise SystemExit(f"stand line broken at {x},264")

    # no decor above the stand line, none in the low corridor
    bad2 = [(x, y) for y in range(0, 264) for x in range(W) if deco_px[x, y][3]]
    if bad2:
        raise SystemExit(f"decor above stand line: {bad2[:8]}")
    bad3 = [(x, y) for y in range(300, 320) for x in range(W) if deco_px[x, y][3]]
    if bad3:
        raise SystemExit(f"decor in low corridor: {bad3[:8]}")

    preview = bg.copy()
    preview.alpha_composite(ground)
    preview.alpha_composite(surface)
    preview.alpha_composite(decor)
    preview.alpha_composite(objects)
    preview640 = preview.convert("RGBA")
    preview1280 = preview640.resize((W * 2, H * 2), Image.NEAREST)

    ground.save(os.path.join(OUT, "layer_ground_atlas_640.png"))
    surface.save(os.path.join(OUT, "layer_platform_surface_640.png"))
    decor.save(os.path.join(OUT, "layer_platform_decor_640.png"))
    objects.save(os.path.join(OUT, "layer_objects_640.png"))
    preview640.save(os.path.join(OUT, "level02_platform_preview_v2_640.png"))
    preview1280.save(os.path.join(OUT, "level02_platform_preview_v2.png"))

    # ---- ground is exactly the project atlas strip: rebuild independently
    expect = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    t = Image.open(os.path.join(SRC, "assets", "map", "ruin_platform_tiles.png")).convert("RGBA")
    top = t.crop((16, 0, 32, 16))
    fill = t.crop((16, 16, 32, 32))
    for k in range(40):
        expect.alpha_composite(top, (k * 16, 320))
        expect.alpha_composite(fill, (k * 16, 336))
        expect.alpha_composite(fill, (k * 16, 352))
    expect = expect.crop((0, 0, W, H))
    if ground.tobytes() != expect.tobytes():
        raise SystemExit("ground differs from exact project atlas strip")
    if ground.crop((0, 0, W, 320)).getchannel("A").getbbox() is not None:
        raise SystemExit("ground layer is not empty above y320")

    # ---- preview at the floor equals background+ground+objects (no new pixels)
    ref = bg.copy()
    ref.alpha_composite(ground)
    ref.alpha_composite(objects)
    pv = preview640.load()
    rf = ref.load()
    for y in range(320, H):
        for x in range(W):
            if pv[x, y][:3] != rf[x, y][:3] or pv[x, y][3] != rf[x, y][3]:
                raise SystemExit(f"preview floor differs at {x},{y}")

    # ---- aperture centres really show the untouched background
    bgp = bg.load()
    for gx, gy, gw, gh in GAPS:
        for y in range(gy + 2, gy + gh):
            for x in range(gx + 1, gx + gw):
                if pv[x, y] != bgp[x, y]:
                    raise SystemExit(f"aperture {x},{y} not background: {pv[x,y]} vs {bgp[x,y]}")

    # ---- exact NEAREST 2x
    p2 = preview1280.load()
    for y in range(H):
        for x in range(W):
            c = pv[x, y]
            if not (p2[2 * x, 2 * y] == p2[2 * x + 1, 2 * y] ==
                    p2[2 * x, 2 * y + 1] == p2[2 * x + 1, 2 * y + 1] == c):
                raise SystemExit(f"2x mismatch at {x},{y}")

    # ---- objects layer must equal the previous approved-anchor composite
    obj_note = "n/a"
    if os.path.exists(V1_OBJECTS):
        old = Image.open(V1_OBJECTS).convert("RGBA")
        obj_note = "identical" if old.tobytes() == objects.tobytes() else "DIFF"
        if obj_note == "DIFF":
            raise SystemExit("objects layer differs from V1 anchors")

    # ---- protected baseline
    with open(PROTECTED, "r", encoding="utf-8-sig") as f:
        protected = json.load(f)
    changed = []
    for item in protected:
        p = item["path"]
        if not os.path.exists(p):
            changed.append((p, "MISSING"))
        elif sha256(p) != item["sha256"].upper():
            changed.append((p, "HASH"))
    if changed:
        raise SystemExit(f"protected changed: {changed[:6]}")

    print(f"protected: {len(protected)}; changed: 0")
    print(f"objects vs V1 anchors: {obj_note}")
    print("ground: exact atlas strip, alpha-empty above y320")
    print("apertures: 5/5 open and showing background at y264..270")
    print("decor: none above y264, none y>=300 (corridor), none y>=320")
    print("surface: atlas replica; stand line y264 intact at every beam")
    print("2x: exact NEAREST")
    for n in ("layer_ground_atlas_640.png", "layer_platform_surface_640.png",
              "layer_platform_decor_640.png", "layer_objects_640.png",
              "level02_platform_preview_v2_640.png", "level02_platform_preview_v2.png"):
        p = os.path.join(OUT, n)
        print(f"  {n}: {Image.open(p).size}  {os.path.getsize(p)} B  {sha256(p)[:16]}")


if __name__ == "__main__":
    main()
