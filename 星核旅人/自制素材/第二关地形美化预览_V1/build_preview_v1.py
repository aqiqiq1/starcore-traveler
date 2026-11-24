# -*- coding: utf-8 -*-
"""
Level 02 terrain art preview V1.

Outputs (all inside this folder):
  terrain_overlay_v1.png       640x360, self-drawn terrain only, transparent elsewhere
  objects_overlay_v1.png       640x360, existing sprites at unchanged anchors
  level02_art_preview_v1_640.png
  level02_art_preview_v1.png   1280x720, exact NEAREST 2x of the 640 preview

READ-ONLY sources:
  基础场景原型/screenshots/ds03_godot_background_only.png
  基础场景原型/assets/... (bay, stele, exit, player idle sheet, star core sheet)

No Godot files, collision, scene positions or source art are modified.
"""
from __future__ import annotations

import hashlib
import json
import os
import random
from PIL import Image

ROOT = r"D:\godot game\星核旅人"
SRC = os.path.join(ROOT, "基础场景原型")
OUT = os.path.join(ROOT, "自制素材", "第二关地形美化预览_V1")
PROTECTED = r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode\level02-art-preview-ae17ade72c2e48d8b742f3302031b847\protected.json"

W, H = 640, 360

# ---------------------------------------------------------------- palette
# Exact ramp sampled from the approved doric_column_tall.png / exit_open.png:
# 174-161-151 light, 143-128-126 body, 113-96-100 low, 66-55-62 deepest.
# This is the foreground "warm grey / grey-brown, purple-grey shadow" family.
TOP_HI = (171, 161, 153)
BEVEL_HI = (158, 148, 141)
FACE_HI = (147, 137, 132)
FACE = (137, 127, 124)
FACE_MID = (123, 114, 113)
FACE_LOW = (109, 101, 102)
SEAM = (94, 87, 93)
UNDER = (80, 75, 86)
DEEP = (67, 62, 73)
OUTLINE = (88, 74, 81)   # 1 px mauve contour, same family as the approved gate
MOSS_HI = (104, 118, 94)
MOSS = (88, 104, 84)
MOSS_DARK = (73, 89, 76)
GOLD = (226, 189, 106)


def shade(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


# ---------------------------------------------------------------- drawing primitives
class Canvas:
    def __init__(self, w=W, h=H):
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    def put(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((x, y), (c[0], c[1], c[2], a))

    def fill(self, x, y, w, h, c, a=255):
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        if x1 <= x0 or y1 <= y0:
            return
        self.img.paste((c[0], c[1], c[2], a), (x0, y0, x1, y1))

    def hline(self, x, y, w, c, a=255):
        self.fill(x, y, w, 1, c, a)

    def vline(self, x, y, h, c, a=255):
        self.fill(x, y, 1, h, c, a)


def segments(start, widths):
    out = []
    x = start
    for w in widths:
        out.append((x, w))
        x += w
    return out


def add_moss(cv: Canvas, x, y, size=1, face=True):
    """Desaturated sage tuft, small and local. Never a hanging vine curtain."""
    cv.put(x, y, MOSS_HI)
    cv.put(x + 1, y, MOSS)
    cv.put(x, y + 1, MOSS)
    cv.put(x + 1, y + 1, MOSS_DARK)
    if size >= 2:
        cv.put(x + 2, y + 1, MOSS)
        cv.put(x + 2, y + 2, MOSS_DARK)
    if face:
        cv.put(x + 1, y + 2, MOSS_DARK)


def mottle(cv: Canvas, x, y, w, h, seed):
    """Clustered 2x2 stone flecks. Never horizontal single-pixel wood grain."""
    r = random.Random(seed)
    count = min(3, max(1, (w * h) // 40))
    tones = [shade(FACE_HI, -5), shade(FACE, -4), shade(FACE_MID, 3),
             (132, 128, 134), (158, 148, 143)]
    for _ in range(count):
        if w < 3 or h < 2:
            return
        px = x + r.randint(1, w - 3)
        py = y + r.randint(1, h - 2)
        c = r.choice(tones)
        cv.put(px, py, c)
        if r.random() < 0.55:
            cv.put(px + 1, py, c)
        if r.random() < 0.55:
            cv.put(px, py + 1, shade(c, -3))
        if r.random() < 0.25:
            cv.put(px + 1, py + 1, shade(c, -5))


def crack(cv: Canvas, x, y, steps=4, seed=0):
    """A 1 px weathered crack, mostly vertical, with a lit lip."""
    r = random.Random(seed)
    for i in range(steps):
        px = x + i // 2
        py = y + i
        cv.put(px, py, shade(SEAM, -5))
        if i % 2 == 0:
            cv.put(px - 1, py, shade(FACE_HI, 4))
        if r.random() < 0.2:
            cv.put(px + 1, py, shade(SEAM, 1))


# ---------------------------------------------------------------- terrain
def draw_ground(cv: Canvas):
    rng = random.Random(20261105)

    # --- capstone course y320..325 (6 px). The top edge stays crisp: it is
    # the actual stand line, so only colour wear is used, no missing collision.
    cap = segments(0, [36, 32, 40, 28, 44, 30, 38, 34, 42, 30,
                       36, 32, 40, 28, 44, 34, 38, 34])
    for i, (x, w) in enumerate(cap):
        v = rng.choice([-4, -2, 0, 1, 2, 3])
        top = shade(TOP_HI, v)
        bev = shade(BEVEL_HI, v)
        fhi = shade(FACE_HI, v)
        flo = shade(FACE, v)
        cv.fill(x, 320, w, 1, top)
        cv.fill(x, 321, w, 1, bev)
        cv.fill(x, 322, w, 2, fhi)
        cv.fill(x, 324, w, 1, flo)
        cv.fill(x, 325, w, 1, shade(SEAM, 2))
        if x > 0:
            # 1 px shadow + 1 px lit arris makes each capstone legible
            cv.vline(x, 320, 5, SEAM)
            cv.vline(x + 1, 320, 5, shade(FACE_HI, v + 6))
            cv.put(x, 320, shade(BEVEL_HI, -7))
            cv.put(x + 1, 320, shade(TOP_HI, v - 2))
            cv.put(x, 321, shade(FACE_HI, -6))
        # worn top: 1-2 shallow pits per block, never a broken stand surface
        for _ in range(rng.randint(1, 2)):
            px = x + rng.randint(3, max(3, w - 4))
            cv.put(px, 320, shade(top, -14))
            cv.put(px, 321, shade(bev, 5))
        # a chipped top corner (colour only) on a few blocks
        if i in (2, 5, 9):
            cv.put(x + w - 1, 320, shade(bev, -6))
            cv.put(x + w - 1, 321, shade(fhi, -7))
            cv.put(x + w - 2, 320, shade(top, -4))
        if i in (1, 7):
            cv.put(x + 4, 320, MOSS)
        mottle(cv, x + 2, 321, w - 4, 3, 1000 + i)

    # --- first ashlar course y326..334 (9 px)
    c1 = segments(-24, [34, 42, 30, 38, 46, 32, 40, 36, 30,
                        44, 34, 42, 30, 38, 36, 44, 32, 36])
    for i, (x, w) in enumerate(c1):
        if x >= W or x + w <= 0:
            continue
        v = rng.choice([-3, -1, 0, 2, 4])
        cv.fill(x, 326, w, 1, shade(FACE_HI, v - 4))
        cv.fill(x, 327, w, 2, shade(FACE_HI, v - 1))
        cv.fill(x, 329, w, 3, shade(FACE_MID, v))
        cv.fill(x, 332, w, 1, shade(FACE_MID, v - 5))
        cv.fill(x, 333, w, 1, shade(FACE_LOW, v))
        cv.fill(x, 334, w, 1, shade(SEAM, 1))
        if x > 0:
            cv.vline(x, 326, 8, SEAM)
            cv.vline(x + 1, 327, 7, shade(FACE_HI, v + 5))
            cv.put(x, 326, shade(FACE_HI, v + 7))
            cv.put(x + 1, 326, shade(FACE_HI, v + 2))
        # break the coursing line occasionally with a chipped/lit arris
        if i % 4 == 0 and w > 8:
            cv.hline(x + 2, 334, 3, shade(FACE_HI, v - 1))
        # quiet tool marks: short, structured, low contrast
        for _ in range(rng.randint(0, 2)):
            sx = x + rng.randint(3, max(3, w - 7))
            sy = 327 + rng.randint(0, 4)
            cv.hline(sx, sy, min(rng.randint(2, 5), x + w - sx),
                     shade(FACE_MID, v + rng.choice([-6, 6])))
        # chipped corner / worn arris, colour only
        if i in (3, 7, 10):
            cv.put(x + w - 1, 326, shade(FACE_MID, v))
            cv.put(x + w - 1, 327, shade(FACE_HI, v + 5))
        if i == 8:
            cv.put(x + 2, 329, shade(FACE_MID, v - 8))
            cv.put(x + 3, 330, shade(FACE_MID, v - 5))
        mottle(cv, x + 2, 327, w - 4, 5, 2000 + i)

    # --- second, larger course y335..346 (12 px)
    c2 = segments(12, [50, 36, 48, 38, 44, 36, 50, 40, 34, 46, 40, 42, 34, 50, 40])
    for i, (x, w) in enumerate(c2):
        v = rng.choice([-3, -1, 1, 3])
        cv.fill(x, 335, w, 1, shade(FACE, v + 4))
        cv.fill(x, 336, w, 2, shade(FACE_HI, v - 2))
        cv.fill(x, 338, w, 4, shade(FACE_MID, v))
        cv.fill(x, 342, w, 2, shade(FACE_MID, v - 5))
        cv.fill(x, 344, w, 1, shade(FACE_LOW, v))
        cv.fill(x, 345, w, 1, shade(FACE_LOW, v - 4))
        cv.fill(x, 346, w, 1, shade(SEAM, 1))
        if x > 0:
            cv.vline(x, 335, 11, shade(SEAM, 2))
            cv.vline(x + 1, 336, 10, shade(FACE_HI, v + 3))
            cv.put(x, 335, shade(FACE_HI, v + 4))
        if i % 3 == 1 and w > 10:
            cv.hline(x + 3, 346, 3, shade(FACE, v + 2))
        for _ in range(rng.randint(0, 2)):
            sx = x + rng.randint(4, max(4, w - 8))
            sy = 337 + rng.randint(0, 6)
            cv.hline(sx, sy, min(rng.randint(3, 6), x + w - sx),
                     shade(FACE_MID, v + rng.choice([-6, 6])))
        if i == 4:
            cv.put(x + w - 1, 335, shade(FACE_MID, v))
            cv.put(x + w - 2, 335, shade(FACE_HI, v + 3))
        if i == 2:
            # one old chisel scar, not a random noise field
            cv.put(x + 22, 339, shade(FACE_MID, -7))
            cv.put(x + 23, 339, shade(FACE_MID, -7))
            cv.put(x + 23, 340, shade(FACE_MID, -5))
        mottle(cv, x + 3, 337, w - 6, 7, 3000 + i)

    # --- foundation y347..359 (13 px), deliberately quieter but not a dead band
    c3 = segments(-40, [68, 56, 76, 64, 72, 60, 80, 64, 72, 68])
    for i, (x, w) in enumerate(c3):
        v = rng.choice([-2, 0, 2])
        cv.fill(x, 347, w, 1, shade(SEAM, v - 2))
        cv.fill(x, 348, w, 1, shade(FACE_MID, v - 8))
        cv.fill(x, 349, w, 6, shade(FACE_LOW, v))
        cv.fill(x, 355, w, 2, shade(UNDER, v))
        cv.fill(x, 357, w, 1, shade(DEEP, v + 4))
        cv.fill(x, 358, w, 1, shade(DEEP, v + 2))
        cv.fill(x, 359, w, 1, shade(DEEP, v - 2))
        if x > 0:
            cv.vline(x, 347, 12, shade(SEAM, -5))
            cv.vline(x + 1, 348, 11, shade(FACE_MID, v - 4))
            cv.put(x, 348, shade(FACE_MID, v - 2))
        # a few large foundation blocks still show a chisel edge
        if i in (1, 4, 6):
            cv.hline(x + 10, 351, min(9, w - 12), shade(FACE_LOW, v - 6))
        if i in (2, 6):
            sx = x + rng.randint(10, max(10, w - 14))
            sy = 349 + rng.randint(0, 3)
            for k in range(rng.randint(3, 5)):
                cv.put(sx + k, sy + (k // 2), shade(SEAM, -4))
        mottle(cv, x + 4, 349, w - 8, 5, 4000 + i)

    # a few long cracks, placed by hand so they do not become a texture field
    crack(cv, 122, 327, 5, 11)
    crack(cv, 351, 337, 6, 12)
    crack(cv, 563, 350, 4, 13)

    # --- break the long horizontal coursing at a few joints. A 1 px step in
    # the seam is what separates "ashlar blocks" from "decking planks".
    for segs, y, idxs in (
        (cap, 325, (3, 6, 9, 12, 15)),
        (c1, 334, (2, 5, 8, 11, 14)),
        (c2, 346, (3, 6, 9, 12)),
    ):
        for i in idxs:
            if i >= len(segs):
                continue
            bx = segs[i][0]
            if 2 < bx < W - 7:
                cv.hline(bx + 2, y, 4, shade(FACE_HI, 1))
                cv.hline(bx + 2, y - 1, 4, shade(SEAM, 1))
                cv.put(bx + 2, y - 1, shade(FACE_MID, -2))

    # --- restrained moss pockets
    add_moss(cv, 64, 320, 1)
    add_moss(cv, 201, 320, 1)
    add_moss(cv, 473, 320, 2)
    add_moss(cv, 552, 320, 1)
    add_moss(cv, 177, 326, 1)
    add_moss(cv, 437, 335, 1)
    add_moss(cv, 561, 347, 1)
    # hairline stains below capstone joints
    for sx in (148, 388, 506):
        cv.put(sx, 326, shade(MOSS_DARK, -9))
        cv.put(sx, 327, MOSS_DARK)
        cv.put(sx + 1, 328, shade(MOSS_DARK, -5))
    # a couple of quiet water stains, not random noise
    for sx, sy, sw, sh in ((312, 326, 2, 4), (583, 335, 2, 5), (89, 348, 3, 4)):
        for yy in range(sy, sy + sh):
            for xx in range(sx, sx + sw - (yy - sy) // 3):
                cv.put(xx, yy, shade(FACE_MID, -7))


def draw_high_step(cv: Canvas):
    x0, y0, w, h = 152, 274, 56, 14
    # A simple, solid stone slab: lit tread / bevel / flat face / plinth.
    # Deliberately no dentils or routed panels at this scale: the approved
    # doric base reads through flat planes, joints and chips, not tiny trim.
    for x in range(x0, x0 + w):
        v = ((x * 7) % 5) - 2
        cv.put(x, 274, shade(TOP_HI, v))
        cv.put(x, 275, shade(BEVEL_HI, v))
        cv.put(x, 276, shade(FACE_HI, v + 2))
    # face with a quiet vertical falloff
    for y in range(277, 282):
        t = (y - 277) / 4.0
        base = tuple(int(FACE_HI[i] * (1 - t) + FACE_MID[i] * t) for i in range(3))
        cv.fill(x0, y, w, 1, base)
    cv.fill(x0, 282, w, 1, FACE_LOW)
    cv.fill(x0, 283, w, 1, SEAM)
    cv.fill(x0, 284, w, 1, FACE_MID)
    cv.fill(x0, 285, w, 1, FACE_LOW)
    cv.fill(x0, 286, w, 1, UNDER)
    cv.fill(x0, 287, w, 1, DEEP)
    # four cut blocks, not one long beam: three real joints + varied faces
    for i, (bx0, bx1) in enumerate(((152, 166), (166, 180), (180, 194), (194, 208))):
        cv.put(bx0 + 1, 276, shade(FACE, 3 if i % 2 else -2))
        cv.vline(bx0 + 1, 277, 5, shade(FACE, 2 if i % 2 else -2))
        cv.vline(bx1 - 1, 277, 5, shade(FACE_MID, -2))
        if bx0 > x0:
            cv.put(bx0, 274, shade(BEVEL_HI, -7))
            cv.vline(bx0, 275, 10, shade(SEAM, 2))
            cv.put(bx0 + 1, 275, shade(BEVEL_HI, 4))
            cv.put(bx0 + 1, 276, shade(FACE_HI, 5))
    # a few chisel marks, short and irregular, one per block
    for sx, sy, ln in ((157, 278, 3), (169, 280, 2), (188, 279, 3), (198, 281, 2)):
        cv.hline(sx, sy, ln, shade(FACE_MID, -7))
    cv.put(163, 279, shade(FACE_HI, 5))
    cv.put(173, 281, shade(FACE_HI, 4))
    cv.put(192, 280, shade(FACE_HI, 4))
    mottle(cv, x0 + 3, 277, w - 6, 5, 77)
    crack(cv, 170, 278, 3, 78)
    # a worn spot on the top arris (colour only: the stand line stays intact)
    cv.put(174, 274, shade(BEVEL_HI, -10))
    cv.put(174, 275, shade(SEAM, 6))
    cv.put(160, 287, (0, 0, 0), 0)
    cv.put(161, 287, (0, 0, 0), 0)
    cv.put(200, 286, (0, 0, 0), 0)
    cv.put(201, 286, (0, 0, 0), 0)
    # 1 px mauve side contour + lit inner edge
    for y in range(275, 288):
        cv.put(x0, y, OUTLINE)
        cv.put(x0 + w - 1, y, OUTLINE)
    cv.put(x0 + 1, 275, shade(BEVEL_HI, 4))
    cv.put(x0 + 1, 276, shade(FACE, 5))
    cv.put(x0 + w - 2, 275, shade(FACE_HI, -8))
    cv.put(x0 + w - 2, 276, shade(FACE_MID, -3))
    # worn arris / chipped corners (colour only)
    cv.put(x0, 274, shade(FACE, -2))
    cv.put(x0 + 1, 274, shade(BEVEL_HI, 3))
    cv.put(x0 + w - 1, 274, shade(BEVEL_HI, -8))
    cv.put(x0 + w - 2, 274, shade(TOP_HI, -4))
    cv.put(x0 + w - 1, 275, shade(BEVEL_HI, -10))
    # transparent chips only on the lower silhouette; the stand line stays
    # intact and readable
    for px, py in ((x0 + w - 1, 286), (x0 + w - 1, 287), (x0 + w - 2, 287)):
        cv.put(px, py, (0, 0, 0), 0)
    cv.put(x0 + w - 2, 286, shade(DEEP, 2))
    # moss only at the shaded end and lower edge
    add_moss(cv, 154, 274, 1)
    add_moss(cv, 201, 284, 1)


def draw_pier(cv: Canvas, x0: int, variant: int = 0):
    # capital / abacus
    cv.fill(x0, 264, 8, 1, TOP_HI)
    cv.fill(x0, 265, 8, 1, BEVEL_HI)
    cv.fill(x0, 266, 8, 1, FACE_HI)
    cv.fill(x0, 267, 8, 1, SEAM)
    # shaft: square pilaster with one broad central flute, not corrugated metal
    # Square stone pilaster: three-pixel faces and one broad central groove.
    # A single groove reads as masonry at this size; three thin flutes read as
    # corrugated metal.
    shaft = [
        (0, OUTLINE),
        (1, (160, 145, 138)),
        (2, (151, 136, 130)),
        (3, (128, 112, 113)),
        (4, (148, 136, 130)),
        (5, (137, 127, 124)),
        (6, (118, 106, 109)),
        (7, OUTLINE),
    ]
    for y in range(268, 292):
        for dx, c in shaft:
            cv.put(x0 + dx, y, c)
    # one-pixel contour continues across the capital, shaft and base
    for y in range(265, 300):
        cv.put(x0, y, OUTLINE)
        cv.put(x0 + 7, y, OUTLINE)
    mottle(cv, x0 + 1, 269, 5, 21, 700 + variant)
    if variant == 0:
        crack(cv, x0 + 2, 281, 4, 701)
    else:
        crack(cv, x0 + 4, 272, 3, 702)
    # masonry joints with a small lit arris on the lower edge
    for jy in (276, 285):
        cv.hline(x0 + 1, jy, 6, shade(SEAM, 7))
        cv.hline(x0 + 1, jy + 1, 6, shade(FACE_HI, -2))
    # an old crack on one pier only
    if variant == 1:
        cv.put(x0 + 4, 270, shade(SEAM, -2))
        cv.put(x0 + 4, 271, shade(SEAM, -2))
        cv.put(x0 + 3, 272, shade(SEAM, -2))
        cv.put(x0 + 3, 273, shade(SEAM, -2))
    # base / plinth
    cv.fill(x0, 292, 8, 1, SEAM)
    cv.fill(x0, 293, 8, 1, BEVEL_HI)
    cv.fill(x0, 294, 8, 2, FACE_HI)
    cv.fill(x0, 296, 8, 1, FACE)
    cv.fill(x0, 297, 8, 1, SEAM)
    cv.fill(x0, 298, 8, 1, FACE_MID)
    cv.fill(x0, 299, 8, 1, UNDER)
    # moss only in the foot recess
    add_moss(cv, x0 + 5, 296, 1)


def draw_beam(cv: Canvas, x0: int, w: int, idx: int):
    """A short weathered stone lintel, exactly 6 px high.

    Top surface, chamfer, a 1 px dark arris, two face rows and a dark soffit.
    The single central joint is real masonry; chips are colour-only, so the
    collision rectangle and the five real gaps are untouched.
    """
    v = [-2, 0, 2, -1, 1, -2, 0][idx]
    top = shade(TOP_HI, v)
    # 6 px simple stone lintel: tread / bevel / face / soffit. Flat planes and
    # a real joint read as stone at this size; dentils read as wood trim.
    cv.fill(x0, 264, w, 1, top)
    cv.fill(x0, 265, w, 1, shade(BEVEL_HI, v))
    cv.fill(x0, 266, w, 1, shade(FACE_HI, v))
    cv.fill(x0, 267, w, 1, shade(FACE, v))
    cv.fill(x0, 268, w, 1, shade(FACE_MID, v - 2))
    cv.fill(x0, 269, w, 1, UNDER)
    # 1 px mauve side contour + lit inner edge, the same read as the approved
    # gate/column. It is a contour, not a thick black border.
    for y in range(265, 270):
        cv.put(x0, y, OUTLINE)
        cv.put(x0 + w - 1, y, OUTLINE)
    cv.put(x0, 264, shade(BEVEL_HI, v + 2))
    cv.put(x0 + 1, 265, shade(BEVEL_HI, v + 4))
    cv.put(x0 + 1, 266, shade(FACE_HI, v + 5))
    cv.put(x0 + 1, 267, shade(FACE_HI, v + 2))
    cv.put(x0 + 1, 268, shade(FACE, v + 2))
    cv.put(x0 + w - 1, 264, shade(BEVEL_HI, v - 7))
    cv.put(x0 + w - 2, 265, shade(FACE_HI, v - 8))
    cv.put(x0 + w - 2, 266, shade(FACE_MID, v - 4))
    cv.put(x0 + w - 2, 267, shade(FACE_MID, v - 6))
    cv.put(x0 + w - 2, 268, shade(SEAM, v))
    # real masonry joints, deliberately not all at the centre. Uneven joints
    # are one of the strongest "broken stone" cues at this size.
    joint_offsets = {0: (6,), 1: (9,), 2: (), 3: (7,), 4: (10,), 5: (6,),
                     6: (7, 15)}
    for jx in (x0 + o for o in joint_offsets[idx]):
        cv.put(jx, 264, shade(BEVEL_HI, v - 8))
        cv.put(jx, 265, shade(FACE_HI, v - 6))
        cv.vline(jx, 266, 3, shade(SEAM, 1))
        cv.put(jx + 1, 265, shade(BEVEL_HI, v + 2))
        cv.put(jx + 1, 268, shade(FACE_HI, v + 2))
        cv.put(jx, 269, shade(SEAM, -2))
    # individual wear: a chipped top, a nicked soffit, two tool marks
    chip = [2, 0, 3, 1, 2, 0, 1][idx]
    if chip < w - 2:
        cv.put(x0 + chip, 264, shade(top, -13))
        cv.put(x0 + chip + 1, 264, shade(top, -5))
    cv.put(x0 + w - 2, 269, shade(FACE_MID, v - 2))
    cv.put(x0 + 2 + (idx % 3), 268, shade(FACE_MID, v - 7))
    cv.put(x0 + w - 3, 268, shade(FACE_MID, v + 4))
    mottle(cv, x0 + 2, 265, w - 4, 3, 500 + idx)
    # 1 px transparent chips only on the lower silhouette, and only on ends
    # that abut a pier or the right ledge. Gap-facing ends stay straight, so
    # the five real 8 px slots are not made to look wider than they are.
    if idx in (0, 3):
        cv.put(x0, 269, (0, 0, 0), 0)
        cv.put(x0 + 1, 269, shade(SEAM, -3))
    if idx in (2, 6):
        cv.put(x0 + w - 1, 269, (0, 0, 0), 0)
        cv.put(x0 + w - 2, 269, shade(SEAM, -3))
    # a 1 px nick in the soffit, one pixel inside the stone
    cv.put(x0 + w - 2, 269, (0, 0, 0), 0)


def draw_right_ledge(cv: Canvas):
    x0, y0, w, h = 400, 276, 32, 10
    for x in range(x0, x0 + w):
        v = ((x * 3) % 3) - 1
        cv.put(x, 276, shade(TOP_HI, v))
        cv.put(x, 277, shade(BEVEL_HI, v))
        cv.put(x, 278, shade(FACE_HI, v + 2))
    cv.fill(x0, 279, w, 1, FACE)
    cv.fill(x0, 280, w, 1, FACE)
    cv.fill(x0, 281, w, 1, FACE_MID)
    cv.fill(x0, 282, w, 1, FACE_LOW)
    cv.fill(x0, 283, w, 1, SEAM)
    cv.fill(x0, 284, w, 1, UNDER)
    cv.fill(x0, 285, w, 1, DEEP)
    # 1 px mauve side contour
    for y in range(277, 286):
        cv.put(x0, y, OUTLINE)
        cv.put(x0 + w - 1, y, OUTLINE)
    cv.put(x0 + 1, 277, shade(BEVEL_HI, 3))
    cv.put(x0 + w - 2, 277, shade(FACE_HI, -7))
    # centre joint
    jx = 416
    cv.put(jx, 276, shade(BEVEL_HI, -6))
    cv.vline(jx, 277, 8, shade(SEAM, 1))
    cv.put(jx + 1, 277, shade(BEVEL_HI, 3))
    # the two pixels under the deck sit in its shadow
    cv.fill(x0, 280, 2, 3, shade(FACE_MID, -6))
    cv.put(x0, 276, shade(TOP_HI, 3))
    # small chisel marks
    cv.put(428, 280, shade(FACE_HI, 5))
    cv.put(410, 281, shade(FACE_LOW, -4))
    mottle(cv, x0 + 2, 279, w - 4, 3, 900)
    # chipped lower corner / soffit nick, visual only
    cv.put(x0 + w - 1, 285, (0, 0, 0), 0)
    cv.put(x0 + w - 2, 285, (0, 0, 0), 0)
    cv.put(x0 + w - 2, 284, shade(DEEP, 2))
    add_moss(cv, 424, 276, 1)


def build_terrain() -> Image.Image:
    cv = Canvas()
    draw_ground(cv)
    draw_high_step(cv)
    draw_pier(cv, 232, 0)
    draw_pier(cv, 296, 1)
    for i, (x, w) in enumerate([(240, 16), (264, 16), (288, 8), (304, 16),
                                 (328, 16), (352, 16), (376, 24)]):
        draw_beam(cv, x, w, i)
    draw_right_ledge(cv)
    return cv.img


# ---------------------------------------------------------------- existing objects
def load_rgba(path):
    return Image.open(path).convert("RGBA")


def paste_center(dst: Image.Image, tex: Image.Image, cx: int, cy: int):
    x = cx - tex.width // 2
    y = cy - tex.height // 2
    dst.alpha_composite(tex, (x, y))


def paste_clipped(dst: Image.Image, tex: Image.Image, x: int, y: int):
    dst.alpha_composite(tex, (x, y))


def build_objects() -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # --- start bay at (118,304): locked, purple core, glass closed
    base = load_rgba(os.path.join(SRC, "assets/star_core_bay/star_core_bay_base.png"))
    glass = load_rgba(os.path.join(SRC, "assets/star_core_bay/star_core_bay_glass.png"))
    sheet = load_rgba(os.path.join(SRC, "assets/star_core/star_core_locked_12f.png"))
    core = sheet.crop((0, 0, 16, 16))
    paste_center(layer, base, 118, 304)
    # exact code-drawn 4x3 lock mark from star_core_bay_lock_mark.gd
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

    # --- target bay at (520,304): open/empty, only the base pedestal
    paste_center(layer, base, 520, 304)

    # --- tutorial stele at (80,320): approved grey shell, no prompt UI
    stele = load_rgba(os.path.join(SRC, "assets/tutorial_stele/tutorial_stele_grey.png"))
    paste_clipped(layer, stele, 80 - 13, 320 - 52)

    # --- exit at (600,320): approved open gate, foot anchor (38,99)
    gate = load_rgba(os.path.join(SRC, "assets/checkpoint_exit/exit_open.png"))
    paste_clipped(layer, gate, 600 - 38, 320 - 99)

    # --- player idle frame 0 only, as a scale reference at spawn (36,320)
    idle = load_rgba(os.path.join(SRC, "assets/characters/male_hero-idle.png"))
    frame0 = idle.crop((0, 0, 128, 128))
    paste_clipped(layer, frame0, 36 - 59, 320 - 79)

    return layer


# ---------------------------------------------------------------- checks
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def main():
    os.makedirs(OUT, exist_ok=True)
    bg_path = os.path.join(SRC, "screenshots", "ds03_godot_background_only.png")
    bg = load_rgba(bg_path)
    if bg.size != (W, H):
        raise SystemExit(f"background is {bg.size}, expected {(W, H)}")

    terrain = build_terrain()
    objects = build_objects()

    preview = bg.copy()
    preview.alpha_composite(terrain)
    preview.alpha_composite(objects)
    preview640 = preview.convert("RGBA")
    preview1280 = preview640.resize((W * 2, H * 2), Image.NEAREST)

    terrain.save(os.path.join(OUT, "terrain_overlay_v1.png"))
    objects.save(os.path.join(OUT, "objects_overlay_v1.png"))
    preview640.save(os.path.join(OUT, "level02_art_preview_v1_640.png"))
    preview1280.save(os.path.join(OUT, "level02_art_preview_v1.png"))

    # ---- geometric truth: the five real gaps must be fully transparent
    gaps = [(256, 264), (280, 288), (320, 328), (344, 352), (368, 376)]
    gap_px = terrain.load()
    bad = []
    for x0, x1 in gaps:
        for y in range(264, 270):
            for x in range(x0, x1):
                if gap_px[x, y][3] != 0:
                    bad.append((x, y, gap_px[x, y]))
    if bad:
        raise SystemExit(f"terrain alpha in real gaps: {bad[:8]}")

    # ---- allowed terrain footprint: no new bridge/deck/support structures
    allowed = Image.new("1", (W, H), 0)
    ap = allowed.load()

    def allow(x, y, w, h):
        for yy in range(max(0, y), min(H, y + h)):
            for xx in range(max(0, x), min(W, x + w)):
                ap[xx, yy] = 1

    allow(0, 320, 640, 40)
    allow(152, 274, 56, 14)
    allow(232, 264, 8, 36)
    allow(296, 264, 8, 36)
    for x, w in [(240, 16), (264, 16), (288, 8), (304, 16), (328, 16), (352, 16), (376, 24)]:
        allow(x, 264, w, 6)
    allow(400, 276, 32, 10)
    tpx = terrain.load()
    outside = [(x, y) for y in range(H) for x in range(W) if tpx[x, y][3] and not ap[x, y]]
    if outside:
        raise SystemExit(f"terrain outside approved geometry: {outside[:8]}")

    # ---- background untouched: composite equals background inside every gap
    bgpx = bg.load()
    pv = preview640.load()
    for x0, x1 in gaps:
        for y in range(264, 270):
            for x in range(x0, x1):
                if pv[x, y] != bgpx[x, y]:
                    raise SystemExit(f"gap {x},{y} not showing background: {pv[x, y]} vs {bgpx[x, y]}")

    # ---- exact NEAREST 2x, no grey fringe
    p2 = preview1280.load()
    for y in range(H):
        for x in range(W):
            c = pv[x, y]
            if not (p2[2 * x, 2 * y] == p2[2 * x + 1, 2 * y] ==
                    p2[2 * x, 2 * y + 1] == p2[2 * x + 1, 2 * y + 1] == c):
                raise SystemExit(f"2x mismatch at {x},{y}")

    # ---- geometry assertions
    assert terrain.getpixel((232, 299))[3] == 255
    assert terrain.getpixel((303, 299))[3] == 255
    assert terrain.getpixel((240, 310))[3] == 0  # 20 px low corridor stays open
    assert terrain.getpixel((296, 310))[3] == 0

    # ---- protected baseline
    with open(PROTECTED, "r", encoding="utf-8-sig") as f:
        protected = json.load(f)
    changed = []
    for item in protected:
        path = item["path"]
        if not os.path.exists(path):
            changed.append((path, "MISSING"))
            continue
        if sha256(path) != item["sha256"].upper():
            changed.append((path, "HASH"))
    print(f"protected files: {len(protected)}; changed: {len(changed)}")
    for p, why in changed[:10]:
        print("  ", why, p)

    print("background sha256:", sha256(bg_path))
    print("terrain sha256:", sha256(os.path.join(OUT, "terrain_overlay_v1.png")))
    print("preview640 sha256:", sha256(os.path.join(OUT, "level02_art_preview_v1_640.png")))
    print("preview1280 sha256:", sha256(os.path.join(OUT, "level02_art_preview_v1.png")))
    print("sizes:", preview640.size, preview1280.size, terrain.size, objects.size)
    print("gaps alpha0: OK; allowed footprint: OK; exact 2x: OK; bg untouched in gaps: OK")


if __name__ == "__main__":
    main()
