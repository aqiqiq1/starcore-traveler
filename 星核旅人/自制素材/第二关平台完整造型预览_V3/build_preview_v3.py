# -*- coding: utf-8 -*-
"""
Level 02 platform silhouette preview V3  (static art preview, not implemented)

Direction
---------
V2 read as a row of brown atlas blocks sitting on a carved strip, with four
small arches of different sizes.  V3 replaces that silhouette with ONE ruined
aqueduct fragment:

  * one continuous coping / top line from x232 to x400 (the five real 8x6
    apertures are visually closed, but stay physically open);
  * one continuous bridge body with two large, equal-height arches and a
    single wide central pier;
  * one solid left abutment and one solid right abutment; the right abutment
    steps down into the existing 400..432 ledge and terminates in a dressed
    end, so the right side reads as one descending terminal structure;
  * the 152..208 high step is a smaller fragment of the same order, with the
    same cornice / quoin / plinth language.  The 208..232 gap is left empty.

Weathering is surface only (tone, a few stains, very sparse moss).  No chips
are cut out of the silhouette.  No small medallions, rosettes, repeated
panels or broken mini-arches.

Physics is untouched.  The visual is a set of separate PNG layers; the real
collision, polarity field, anchors and scene files are not modified.  All
visual pixels stop at y299, so the 20 px low corridor (300..319) and the
ground (320..359) are free.

Read-only sources
-----------------
基础场景原型/screenshots/ds03_godot_background_only.png
自制素材/第二关平台造型预览_V2/layer_ground_atlas_640.png   (copied byte-exact)
自制素材/第二关平台造型预览_V2/layer_objects_640.png       (copied byte-exact)
Palette reference: assets/doric_columns/doric_column_tall.png,
                   assets/checkpoint_exit/exit_open.png

Writes only:
    自制素材/第二关平台完整造型预览_V3/
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import shutil
from PIL import Image

ROOT = r"D:\godot game\星核旅人"
SRC = os.path.join(ROOT, "基础场景原型")
V2 = os.path.join(ROOT, "自制素材", "第二关平台造型预览_V2")
OUT = os.path.join(ROOT, "自制素材", "第二关平台完整造型预览_V3")
PROTECTED = (r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
             r"\level02-art-preview-ae17ade72c2e48d8b742f3302031b847\protected.json")

W, H = 640, 360

# ---------------------------------------------------------------- approved ramp
# Same warm grey / mauve family as the doric column and the exit gate.
TOP_LIT = (190, 180, 168)
TOP = (178, 166, 156)
HI = (181, 169, 158)
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

SAGE = (105, 126, 107)
SAGE_D = (84, 104, 86)
SAGE_DD = (66, 82, 69)
MOSS = (58, 74, 56)

# ---------------------------------------------------------------- geometry (read-only reference)
FLOOR_Y = 320
HIGH_STEP = (152, 274, 56, 14)          # x, y, w, h -- real collision
PIERS = [(232, 264, 8, 36), (296, 264, 8, 36)]
BEAMS = [(240, 264, 16, 6), (264, 264, 16, 6), (288, 264, 8, 6),
         (304, 264, 16, 6), (328, 264, 16, 6), (352, 264, 16, 6),
         (376, 264, 24, 6)]
GAPS = [(256, 264, 8, 6), (280, 264, 8, 6), (320, 264, 8, 6),
        (344, 264, 8, 6), (368, 264, 8, 6)]
RIGHT_LEDGE = (400, 276, 32, 10)        # x, y, w, h -- real collision

MAIN_X0, MAIN_X1 = 232, 400
MAIN_TOP = 264
BODY_BOTTOM = 299
ARCH_A = (246, 294, 283, 299)           # x0, x1, crown y, spring y
ARCH_B = (314, 368, 283, 299)
HIGH_X0, HIGH_X1 = 152, 208
LEDGE_X0, LEDGE_X1 = 400, 432


def shade(c, d):
    return tuple(max(0, min(255, v + d)) for v in c)


def blend(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def tone_patch(cv, x, y, w, h, d):
    """Large, low-contrast stone block: tonal variation without new lines."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            p = cv.img.getpixel((xx, yy))
            if p[3]:
                cv.put(xx, yy, shade(p[:3], d), p[3])


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


# ---------------------------------------------------------------- arch maths
def arch_y(x, x0, x1, crown, spring):
    """Intrados row for column x of an elliptical arch."""
    half = (x1 - x0) / 2.0
    u = (x + 0.5 - (x0 + x1) / 2.0) / half
    return int(round(spring - (spring - crown) * math.sqrt(max(0.0, 1.0 - u * u))))


def carve_arch(cv, x0, x1, crown, spring):
    """Cut the opening, then draw a 4 px voussoir ring and a keystone."""
    for x in range(x0, x1):
        yi = arch_y(x, x0, x1, crown, spring)
        for y in range(yi + 1, BODY_BOTTOM + 1):
            cv.erase(x, y)
        seg = (x - x0) // 8
        tone = 5 if seg % 2 == 0 else -4
        cv.put(x, yi - 5, shade(SEAM, 2))      # dark extrados outline
        cv.put(x, yi - 4, shade(HI, tone))
        cv.put(x, yi - 3, shade(HI2, tone))
        cv.put(x, yi - 2, shade(LIT, tone))
        cv.put(x, yi - 1, shade(LIT2, tone))
        cv.put(x, yi, DEEP)
        # one quiet voussoir joint per segment (no bright alternating blocks)
        if (x - x0) % 8 == 0 and x0 + 2 < x < x1 - 3:
            for y in range(yi - 5, yi):
                cv.put(x, y, shade(SEAM, 1))
            cv.put(x + 1, yi - 4, shade(HI, tone + 3))

    # keystone: one 6 px block, same stone, slightly proud
    xm = (x0 + x1) // 2
    ym = arch_y(xm, x0, x1, crown, spring)
    for dx in range(-2, 4):
        for y in range(ym - 6, ym):
            if dx == -2:
                c = HI
            elif dx == -1:
                c = HI2
            elif dx in (0, 1):
                c = LIT
            elif dx == 2:
                c = FACE_D
            else:
                c = SEAM
            cv.put(xm + dx, y, c)
    cv.put(xm - 2, ym - 6, HI)
    cv.put(xm + 3, ym - 6, shade(SEAM, -2))
    cv.put(xm + 3, ym - 5, SEAM)
    cv.put(xm + 3, ym - 4, SEAM)


# ---------------------------------------------------------------- main bridge
def draw_main(cv):
    x0, x1 = MAIN_X0, MAIN_X1
    wid = x1 - x0

    # ---- continuous deck: this closes the five 8x6 apertures visually, but
    #      only in this preview layer.  The real collision gaps are untouched.
    for x in range(x0, x1):
        cv.put(x, 264, TOP_LIT)
        cv.put(x, 265, TOP)
        cv.put(x, 266, HI2)
        cv.put(x, 267, LIT)
        cv.put(x, 268, FACE)
        cv.put(x, 269, SEAM)       # deep continuous shadow under the coping
        cv.put(x, 270, MID2)
        cv.put(x, 271, LIT2)       # single lit moulding line
        cv.put(x, 272, FACE_D)
        cv.put(x, 273, SEAM)       # cornice shadow

    # three coping-slab joints: the top line stays continuous, only the
    # surface is divided, like a real stone deck.
    for jx in (270, 318, 366):
        for y in range(264, 267):
            cv.put(jx, y, shade(TOP, -10))
        cv.put(jx + 1, 265, HI2)

    # ---- spandrel: one calm field, one course line, little tonal drift
    for y in range(274, 283):
        t = (y - 274) / 9.0
        base = blend(LIT2, FACE, t * 0.95) if y <= 278 else blend(FACE, FACE_D, (y - 278) / 4.0)
        cv.fill(x0, y, wid, 1, base)
    cv.hline(x0, 278, wid, shade(FACE, -8))

    # ---- lower body (piers / abutments).  Carved by the two arches next.
    for y in range(283, BODY_BOTTOM + 1):
        if y <= 290:
            t = (y - 283) / 7.0
            base = blend(LIT2, FACE, t)
        elif y <= 296:
            t = (y - 291) / 5.0
            base = blend(FACE, MID, t)
        elif y == 297:
            base = MID2
        elif y == 298:
            base = LOW
        else:
            base = SEAM
        cv.fill(x0, y, wid, 1, base)

    # ---- very quiet ashlar joints, staggered; not decoration
    for jx, jy0, jy1 in ((258, 274, 277), (282, 279, 282),
                         (326, 274, 277), (350, 279, 282),
                         (384, 274, 277)):
        cv.vline(jx, jy0, jy1 - jy0 + 1, shade(FACE, -10))

    # ---- vertical volume on the three supports
    # left abutment 232..246
    for y in range(274, 300):
        cv.put(232, y, SEAM)
        cv.put(233, y, HI2)
        cv.put(234, y, LIT2)
        cv.put(245, y, SEAM)
    # central pier 294..314 (covers the real 296..304 pier)
    for y in range(283, 300):
        cv.put(294, y, HI2)
        cv.put(295, y, LIT2)
        cv.put(296, y, FACE)
        cv.put(313, y, FACE_D)
        cv.put(314, y, SEAM)
    # right abutment 368..400 + terminal pilaster
    for y in range(283, 300):
        cv.put(368, y, SEAM)
        cv.put(369, y, HI2)
        cv.put(370, y, LIT2)
        cv.put(394, y, HI2)
        cv.put(395, y, LIT)
        cv.put(396, y, FACE_D)
        cv.put(397, y, SEAM)
        cv.put(398, y, FACE_D)
        cv.put(399, y, LIT2)   # internal joint to the ledge, not a black edge

    # ---- quiet ashlar courses on the solid supports (surface only)
    for yy in (285, 292):
        cv.hline(236, yy, 9, shade(FACE, -7))
    for yy in (290, 295):
        cv.hline(296, yy, 17, shade(FACE_D, -7))
    for yy in (286, 292):
        cv.hline(370, yy, 24, shade(FACE, -7))
    for jx, jy0, jy1 in ((240, 283, 284), (304, 283, 289),
                         (378, 283, 285), (386, 287, 291),
                         (380, 293, 296)):
        cv.vline(jx, jy0, jy1 - jy0 + 1, shade(FACE, -9))

    # ---- dressed quoins at the two main ends: the same 1 px joint rhythm
    #      used on the high step and the right ledge.
    for qy in (270, 282, 294):
        cv.hline(233, qy, 3, SEAM)
    for qy in (270, 282, 294):
        cv.hline(396, qy, 3, SEAM)

    # ---- arches
    carve_arch(cv, *ARCH_A)
    carve_arch(cv, *ARCH_B)

    # ---- large, quiet tonal blocks (stone variation, no new silhouette)
    tone_patch(cv, 236, 284, 8, 6, 4)
    tone_patch(cv, 298, 286, 10, 7, -4)
    tone_patch(cv, 372, 284, 10, 7, 4)

    # ---- a few surface stains / pockmarks, never on the silhouette
    for x, y, c in ((252, 276, shade(FACE, -7)),
                    (335, 276, shade(FACE, -7)),
                    (386, 291, shade(FACE_D, -9)),
                    (240, 285, shade(LIT2, -12)),
                    (370, 288, shade(LIT2, -10))):
        cv.put(x, y, c)
    # damp streaks under the cornice
    for x, y0, y1 in ((262, 274, 281), (338, 274, 280), (390, 283, 292)):
        for y in range(y0, y1 + 1):
            cv.put(x, y, blend(cv.img.getpixel((x, y))[:3], SEAM, 0.18))

    # ---- coping scuffs (surface only)
    cv.put(250, 265, FACE)
    cv.put(333, 265, HI2)
    cv.put(389, 265, LIT)

    # ---- clean end caps
    cv.put(232, 264, HI2)
    cv.put(399, 264, HI2)
    for y in range(265, 276):
        cv.put(399, y, DEEP)
    cv.put(398, 265, SEAM)
    cv.put(398, 266, SEAM)
    # below the step the main abutment and the 400..432 ledge are one mass:
    # share a lit joint instead of a black edge.
    for y in range(283, 300):
        cv.put(397, y, FACE_D)
        cv.put(398, y, FACE_D)
        cv.put(399, y, LIT2)
    # underside shadow of the upper deck over the lower ledge
    cv.hline(396, 275, 4, SEAM)


def draw_high_step(cv):
    """152..208 fragment: same cornice, quoins and bottom line as the bridge,
    with a deliberately corbelled base.  It reads as a broken wall pier, not
    a bench.  The 208..232 jump gap stays empty."""
    x0, x1 = HIGH_X0, HIGH_X1
    wid = x1 - x0
    for x in range(x0, x1):
        cv.put(x, 274, TOP_LIT)
        cv.put(x, 275, TOP)
        cv.put(x, 276, HI2)
        cv.put(x, 277, SEAM)
        cv.put(x, 278, LIT2)
        cv.put(x, 279, FACE_D)
    for y in range(280, 289):
        t = (y - 280) / 9.0
        cv.fill(x0, y, wid, 1, blend(LIT2, FACE, t * 0.9))
    for y in range(289, 296):
        t = (y - 289) / 7.0
        cv.fill(x0, y, wid, 1, blend(FACE, MID, t * 0.95))
    for x in range(x0, x1):
        cv.put(x, 296, MID2)
        cv.put(x, 297, LOW)
        cv.put(x, 298, SEAM)
        cv.put(x, 299, SEAM)

    # structural joint + staggered courses: large-block masonry
    for y in range(280, 297):
        cv.put(180, y, SEAM)
        cv.put(181, y, HI2)
    cv.hline(x0 + 1, 286, 27, shade(FACE, -7))
    cv.hline(182, 291, 22, shade(FACE, -7))

    # corbelled base: two deliberate setbacks, not weathering chips.
    for y in range(289, 295):
        for x in list(range(x0, x0 + 3)) + list(range(x1 - 3, x1)):
            cv.erase(x, y)
    for y in range(295, 300):
        for x in list(range(x0, x0 + 5)) + list(range(x1 - 5, x1)):
            cv.erase(x, y)
    # shadows under the two overhangs
    cv.hline(x0 + 3, 289, wid - 6, SEAM)
    cv.hline(x0 + 5, 295, wid - 10, SEAM)

    # edges follow the corbel
    for y in range(274, 289):
        cv.put(x0, y, SEAM)
        cv.put(x0 + 1, y, HI2)
        cv.put(x0 + 2, y, LIT2)
        cv.put(x1 - 1, y, DEEP)
        cv.put(x1 - 2, y, SEAM)
        cv.put(x1 - 3, y, FACE_D)
        cv.put(x1 - 4, y, LIT2)
    for y in range(289, 295):
        cv.put(x0 + 3, y, SEAM)
        cv.put(x0 + 4, y, HI2)
        cv.put(x0 + 5, y, LIT2)
        cv.put(x1 - 4, y, DEEP)
        cv.put(x1 - 5, y, SEAM)
        cv.put(x1 - 6, y, FACE_D)
    for y in range(295, 300):
        cv.put(x0 + 5, y, SEAM)
        cv.put(x0 + 6, y, HI2)
        cv.put(x0 + 7, y, LIT2)
        cv.put(x1 - 6, y, DEEP)
        cv.put(x1 - 7, y, SEAM)
        cv.put(x1 - 8, y, FACE_D)

    cv.hline(x0 + 1, 282, 2, SEAM)
    cv.hline(x1 - 5, 282, 4, SEAM)
    cv.put(x0, 274, HI2)
    cv.put(x1 - 1, 274, HI2)

    # slab joint on the top face
    for y in range(274, 277):
        cv.put(180, y, shade(TOP, -9))
    cv.put(181, 275, HI2)

    tone_patch(cv, 156, 282, 10, 5, 4)
    tone_patch(cv, 188, 284, 10, 6, -3)

    # sparse moss at the foot, not on the top or the ends
    cv.put(x0 + 8, 296, SAGE_D)
    cv.put(x0 + 9, 298, SAGE_DD)
    cv.put(x1 - 10, 298, SAGE)
    cv.put(x1 - 9, 298, SAGE_DD)


def draw_right_ledge(cv):
    x0, x1 = LEDGE_X0, LEDGE_X1
    wid = x1 - x0
    for x in range(x0, x1):
        cv.put(x, 276, TOP_LIT)
        cv.put(x, 277, TOP)
        cv.put(x, 278, HI2)
        cv.put(x, 279, SEAM)
        cv.put(x, 280, MID2)
        cv.put(x, 281, LIT2)
        cv.put(x, 282, FACE_D)
    for y in range(283, 296):
        if y <= 289:
            t = (y - 283) / 6.0
            base = blend(LIT2, FACE, t)
        else:
            t = (y - 289) / 6.0
            base = blend(FACE, MID, t * 0.95)
        cv.fill(x0, y, wid, 1, base)
    for x in range(x0, x1):
        cv.put(x, 296, MID2)
        cv.put(x, 297, LOW)
        cv.put(x, 298, SEAM)
        cv.put(x, 299, SEAM)

    cv.hline(x0 + 2, 286, 13, shade(FACE, -8))
    cv.vline(416, 283, 14, shade(FACE, -9))
    cv.hline(417, 291, 13, shade(FACE, -6))
    tone_patch(cv, 404, 284, 10, 6, 3)
    for y in range(276, 279):
        cv.put(416, y, shade(TOP, -9))
    cv.put(417, 277, HI2)

    # left edge: only the 276..282 riser is an inside corner; below that the
    # ledge and the main abutment are one continuous mass, so no black seam.
    for y in range(277, 283):
        cv.put(x0, y, SEAM)
        cv.put(x0 + 1, y, FACE_D)
    for y in range(283, 300):
        cv.put(x0, y, LIT2)
    cv.put(x0, 276, HI2)
    # right terminal
    for y in range(276, 300):
        cv.put(x1 - 1, y, DEEP)
        cv.put(x1 - 2, y, SEAM)
        cv.put(x1 - 3, y, FACE_D)
        cv.put(x1 - 4, y, LIT2)
    for qy in (282, 292):
        cv.hline(x1 - 4, qy, 3, SEAM)
    cv.put(x1 - 1, 276, HI2)

    # a damp streak at the foot, surface only
    for y in range(291, 297):
        cv.put(423, y, blend(cv.img.getpixel((423, y))[:3], SEAM, 0.2))
    cv.put(x0 + 7, 296, SAGE_D)
    cv.put(x0 + 8, 296, SAGE_DD)


def build_platform():
    cv = Canvas()
    draw_main(cv)
    draw_high_step(cv)
    draw_right_ledge(cv)
    return cv.img


# ---------------------------------------------------------------- low-key decor
def build_decor():
    """Only what the structure cannot carry itself: five setting joints over
    the real apertures, three moss touches and a couple of stains.  All of it
    is non-collision and stops above y300."""
    cv = Canvas()

    # one quiet recessed setting joint over each real 8x6 aperture.  It is a
    # joint, not a hole: 1 px, ~30% dark, only on the deck fascia.
    for gx, gy, gw, gh in GAPS:
        cx = gx + gw // 2
        for y in range(267, 273):
            cv.put(cx, y, (66, 55, 62), 72)

    # three moss touches, always on a horizontal ledge, never on an edge
    for x, y in ((248, 297), (292, 297), (371, 296)):
        cv.put(x, y, SAGE, 210)
        cv.put(x + 1, y, SAGE_D, 210)
        cv.put(x, y + 1, SAGE_DD, 190)
    # a little dry lichen on the high step shoulder
    cv.put(160, 289, SAGE_D, 150)
    cv.put(161, 289, SAGE_DD, 150)

    return cv.img


# ---------------------------------------------------------------- checks
def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def main():
    os.makedirs(OUT, exist_ok=True)

    bg = Image.open(os.path.join(SRC, "screenshots",
                                 "ds03_godot_background_only.png")).convert("RGBA")
    assert bg.size == (W, H)

    # ---- reuse the already-verified V2 ground and object layers byte-exact
    ground_src = os.path.join(V2, "layer_ground_atlas_640.png")
    objects_src = os.path.join(V2, "layer_objects_640.png")
    ground_dst = os.path.join(OUT, "layer_ground_atlas_640.png")
    objects_dst = os.path.join(OUT, "layer_objects_640.png")
    shutil.copyfile(ground_src, ground_dst)
    shutil.copyfile(objects_src, objects_dst)
    ground = Image.open(ground_dst).convert("RGBA")
    objects = Image.open(objects_dst).convert("RGBA")

    platform = build_platform()
    decor = build_decor()

    # ---- all visual layers must end above the low corridor
    for name, layer in (("platform", platform), ("decor", decor)):
        px = layer.load()
        bad = [(x, y) for y in range(300, H) for x in range(W) if px[x, y][3]]
        if bad:
            raise SystemExit(f"{name} touches y>=300: {bad[:8]}")
        bad2 = [(x, y) for y in range(0, 264) for x in range(W) if px[x, y][3]]
        if bad2:
            raise SystemExit(f"{name} above y264: {bad2[:8]}")
        # no pixels over the ground
        bad3 = [(x, y) for y in range(320, H) for x in range(W) if px[x, y][3]]
        if bad3:
            raise SystemExit(f"{name} touches ground: {bad3[:8]}")

    # ---- the whole point of V3: one unbroken top line 232..399 at y264
    pp = platform.load()
    for x in range(MAIN_X0, MAIN_X1):
        if pp[x, 264][3] != 255:
            raise SystemExit(f"top line broken at {x},264")
    # ... and it is one continuous silhouette from 232 to 432 at some row
    for x in range(MAIN_X0, LEDGE_X1):
        if not any(pp[x, y][3] for y in range(264, 300)):
            raise SystemExit(f"silhouette gap at x={x}")
    # the 208..232 gap must stay empty (jump route is not bridged)
    for x in range(HIGH_X1, MAIN_X0):
        if any(pp[x, y][3] for y in range(264, 300)):
            raise SystemExit(f"decor/visual fills the 208..232 jump gap at x={x}")

    # ---- arches really open onto the background
    for x0, x1, crown, spring in (ARCH_A, ARCH_B):
        xm = (x0 + x1) // 2
        for y in range(crown + 3, 298):
            if pp[xm, y][3]:
                raise SystemExit(f"arch centre not open at {xm},{y}")
    # ---- both arch openings expose background pixels after compositing
    #      (checked on the composite below)

    # ---- the two real piers are entirely covered by stone in this visual
    for px0, py0, pw, ph in PIERS:
        for x in range(px0, px0 + pw):
            for y in range(264, 300):
                if pp[x, y][3] != 255:
                    raise SystemExit(f"real pier pixel open at {x},{y}")

    # ---- composite
    preview = bg.copy()
    preview.alpha_composite(ground)
    preview.alpha_composite(platform)
    preview.alpha_composite(decor)
    preview.alpha_composite(objects)
    preview640 = preview.convert("RGBA")
    preview1280 = preview640.resize((W * 2, H * 2), Image.NEAREST)

    platform.save(os.path.join(OUT, "layer_platform_visual_640.png"))
    decor.save(os.path.join(OUT, "layer_platform_decor_640.png"))
    preview640.save(os.path.join(OUT, "level02_platform_preview_v3_640.png"))
    preview1280.save(os.path.join(OUT, "level02_platform_preview_v3.png"))

    # ---- ground / objects are byte-identical to the V2 layers
    if sha256(ground_dst) != sha256(ground_src):
        raise SystemExit("ground copy differs")
    if sha256(objects_dst) != sha256(objects_src):
        raise SystemExit("objects copy differs")
    if ground.tobytes() != Image.open(ground_src).convert("RGBA").tobytes():
        raise SystemExit("ground pixels differ from V2")
    if objects.tobytes() != Image.open(objects_src).convert("RGBA").tobytes():
        raise SystemExit("objects pixels differ from V2")
    if ground.crop((0, 0, W, 320)).getchannel("A").getbbox() is not None:
        raise SystemExit("ground layer has pixels above y320")

    # ---- layering is exact
    rebuilt = bg.copy()
    for layer in (ground, platform, decor, objects):
        rebuilt.alpha_composite(layer)
    if rebuilt.tobytes() != preview640.tobytes():
        raise SystemExit("layer rebuild differs from preview")

    # ---- ground area is untouched by the new visual
    gp = ground.load()
    for y in range(320, H):
        for x in range(W):
            if preview640.getpixel((x, y)) != rebuilt.getpixel((x, y)):
                raise SystemExit(f"floor differs at {x},{y}")
    # ... and byte-for-byte the same floor as the approved V2 preview
    v2_main = Image.open(os.path.join(V2, "level02_platform_preview_v2_640.png")).convert("RGBA")
    v2p = v2_main.load()
    for y in range(320, H):
        for x in range(W):
            if preview640.getpixel((x, y)) != v2p[x, y]:
                raise SystemExit(f"floor differs from V2 at {x},{y}")

    # ---- arch openings show untouched background (no decoration)
    bgp = bg.load()
    pvp = preview640.load()
    for x0, x1, crown, spring in (ARCH_A, ARCH_B):
        for x in range(x0 + 4, x1 - 4, 3):
            yi = arch_y(x, x0, x1, crown, spring)
            for y in range(max(crown + 5, yi + 3), 297, 3):
                if pvp[x, y] != bgp[x, y]:
                    raise SystemExit(f"arch opening not background at {x},{y}")
    # ---- 208..232 gap shows untouched background
    for x in range(HIGH_X1, MAIN_X0):
        for y in range(270, 299):
            if pvp[x, y] != bgp[x, y]:
                raise SystemExit(f"jump gap not background at {x},{y}")

    # ---- exact NEAREST 2x
    p2 = preview1280.load()
    for y in range(H):
        for x in range(W):
            c = pvp[x, y]
            if not (p2[2 * x, 2 * y] == p2[2 * x + 1, 2 * y] ==
                    p2[2 * x, 2 * y + 1] == p2[2 * x + 1, 2 * y + 1] == c):
                raise SystemExit(f"2x mismatch at {x},{y}")

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

    # ---- structural (not just tonal) change report
    pv2 = Image.open(os.path.join(V2, "level02_platform_preview_v2_640.png")).convert("RGBA")
    print(f"protected: {len(protected)}; changed: 0")
    print("ground: byte-identical to V2; empty above y320")
    print("objects: byte-identical to V2; anchors untouched")
    print("platform top line y264: continuous 232..399")
    print("silhouette: continuous 232..432; 208..232 jump gap empty")
    print("arches: 2 large openings (246..294, 314..368), crown y283")
    print("decor: 5 setting joints + sparse moss; none y>=300")
    print("2x: exact NEAREST")
    for n in ("layer_ground_atlas_640.png", "layer_platform_visual_640.png",
              "layer_platform_decor_640.png", "layer_objects_640.png",
              "level02_platform_preview_v3_640.png",
              "level02_platform_preview_v3.png"):
        p = os.path.join(OUT, n)
        im = Image.open(p)
        print(f"  {n}: {im.size}  {os.path.getsize(p)} B  {sha256(p)[:16]}")
    print(f"v2 main: {pv2.size}")


if __name__ == "__main__":
    main()
