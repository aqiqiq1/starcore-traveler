"""Draw the formal bridge_stone_v1 atlas.  Explicit pixel work only; no noise.

Reproduce with:
  D:\\minic\\envs\\2024212971\\python.exe generate_atlas.py
"""
from __future__ import annotations

import json
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
import layout as L

P = L.PALETTE
OUT, DEEP, DARK, SHADE, MIDD, MID, MID2, LIGHT, LIGHT2, TOP, TOPHI, BEAR, BEAR2, BEAR3 = (
    P["OUT"], P["DEEP"], P["DARK"], P["SHADE"], P["MIDD"], P["MID"], P["MID2"],
    P["LIGHT"], P["LIGHT2"], P["TOP"], P["TOPHI"], P["BEAR"], P["BEAR2"], P["BEAR3"],
)

SHADOW_OF = {
    LIGHT2: LIGHT, LIGHT: MID2, MID2: MID, MID: MIDD,
    MIDD: SHADE, SHADE: DARK, DARK: DEEP, BEAR: DARK,
    BEAR2: DEEP, BEAR3: OUT,
}


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    if x1 >= x0 and y1 >= y0:
        ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def hline(im, x0, x1, y, c):
    rect(im, x0, y, x1, y, c)


def vline(im, x, y0, y1, c):
    rect(im, x, y0, x, y1, c)


def poly(im, pts, c):
    ImageDraw.Draw(im).polygon(pts, fill=c)


def stepped_tone(im, x0, y0, x1, y1, c):
    poly(im, [(x0 + 2, y0), (x1 - 4, y0), (x1 - 1, y0 + 2), (x1, y1 - 2),
              (x1 - 3, y1), (x0 + 3, y1), (x0, y1 - 1)], c)


def spall(im, x, y, w, h, lip=True):
    poly(im, [(x, y + 1), (x + 1, y), (x + w - 3, y + 1), (x + w - 1, y + 2),
              (x + w - 2, y + h - 2), (x + w - 4, y + h - 1), (x + 2, y + h - 2)],
         DARK)
    hline(im, x + 1, x + 3, y + 1, DEEP)
    im.putpixel((x + w - 2, y + 2), DEEP)
    if lip:
        hline(im, x + 2, min(x + 5, x + w - 3), y + h - 1, LIGHT)


def crack(im, pts, w, h):
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        steps = max(abs(bx - ax), abs(by - ay))
        for s in range(steps + 1):
            x = round(ax + (bx - ax) * s / steps)
            y = round(ay + (by - ay) * s / steps)
            if 0 <= x < w and 0 <= y < h - 1:
                im.putpixel((x, y), DEEP)
                if s % 5 in (1, 2) and x - 1 >= 0:
                    im.putpixel((x - 1, y), LIGHT)


BLOCK_SPECS = {
    "block_mid2_a": dict(face=MID2, top_shadow=SHADE, lit=(1, 22), stain=(62, 3, 13),
                          chip=(77, 0, 2, 2, DARK)),
    "block_mid2_b": dict(face=MID2, top_shadow=None, lit=None, stain=(18, 4, 15),
                          bed=(26, 52, 14, MID), chip=(1, 17, 3, 2, DEEP)),
    "block_mid_a": dict(face=MID, top_shadow=None, lit=(1, 34), stain=(68, 3, 12),
                         bed=(14, 42, 15, MID2)),
    "block_mid_b": dict(face=MID, top_shadow=SHADE, lit=(42, 70), stain=(10, 4, 14),
                         spall=(50, 8, 8, 5)),
    "block_midd_a": dict(face=MIDD, top_shadow=DARK, lit=(1, 26), stain=(70, 4, 14),
                          chip=(76, 17, 3, 2, DEEP)),
    "block_midd_b": dict(face=MIDD, top_shadow=None, lit=None, stain=(24, 3, 16),
                          bed=(34, 66, 15, SHADE)),
    "block_bear_a": dict(face=BEAR, top_shadow=DARK, lit=(1, 20), stain=(60, 3, 13),
                          chip=(76, 18, 3, 1, OUT)),
    "block_bear_b": dict(face=BEAR, top_shadow=None, lit=(46, 72), stain=(30, 4, 14),
                          bed=(10, 38, 15, SHADE)),
    "block_bear2_a": dict(face=BEAR2, top_shadow=DEEP, lit=(1, 24), stain=(58, 4, 13),
                           chip=(77, 0, 2, 2, DEEP)),
    "block_bear2_b": dict(face=BEAR2, top_shadow=None, lit=(48, 70), stain=(14, 3, 15),
                           bed=(24, 56, 15, DARK)),
    "block_light_a": dict(face=LIGHT, top_shadow=None, lit=(1, 48), stain=(66, 3, 12),
                           chip=(70, 6, 3, 1, DEEP)),
    "block_lit_a": dict(face=MID2, top_shadow=None, lit=(1, 30), stain=(60, 4, 14),
                         beam=(1, 3, 1, 16)),
    "block_chip_a": dict(face=MID2, top_shadow=SHADE, lit=(1, 30), stain=(20, 3, 15),
                          spall=(54, 7, 8, 5)),
    "block_crack_a": dict(face=MID, top_shadow=None, lit=(1, 28), stain=(68, 4, 14),
                           crack=((50, 1), (46, 6), (50, 12), (45, 18))),
    "block_light_b": dict(face=LIGHT, top_shadow=None, lit=(1, 38), stain=(56, 3, 13),
                           bed=(8, 34, 16, MID2)),
    "block_dark_a": dict(face=BEAR3, top_shadow=DEEP, lit=(1, 26), stain=(50, 4, 14),
                          chip=(74, 0, 3, 2, OUT)),
}

# Only true "lit stone" variants own a bright top edge.  Regular blocks get a
# dark recess instead, so the wall does not become a wireframe of white lines.
for _name, _spec in BLOCK_SPECS.items():
    if _name not in ("block_light_a", "block_light_b", "block_lit_a"):
        _spec.pop("lit", None)


def draw_block(w, h, spec):
    im = canvas(w, h)
    face = spec["face"]
    rect(im, 0, 0, w - 1, h - 1, face)
    # lower recess: a short horizontal shadow, not a diagonal graphic wedge
    hline(im, 1, max(2, int(w * 0.62)), h - 2, SHADOW_OF[face])
    if w > 64:
        hline(im, int(w * 0.72), w - 2, h - 3, SHADOW_OF[face])
    for x0, x1, y, c in [spec.get("bed", ())] if "bed" in spec else []:
        hline(im, max(1, x0), min(x1, w - 2), y, c)
    if "stain" in spec:
        x, y0, y1 = spec["stain"]
        vline(im, x, y0, min(y1, h - 2), SHADOW_OF.get(face, SHADE))
        if y1 - y0 > 8:
            im.putpixel((x + 1, y1 - 1), SHADOW_OF.get(face, SHADE))
    if spec.get("beam"):
        x0, x1, y0, y1 = spec["beam"]
        vline(im, x0, y0, y1, LIGHT2)
        if x1 > x0:
            vline(im, x1, y0 + 1, y1, LIGHT)
    if spec.get("chip"):
        x, y, cw, ch, c = spec["chip"]
        rect(im, x, y, min(x + cw - 1, w - 1), min(y + ch - 1, h - 1), c)
    if spec.get("spall"):
        spall(im, *spec["spall"])
    if spec.get("crack"):
        crack(im, spec["crack"], w, h)
    # lit top edge: never a complete bright frame
    if spec.get("lit"):
        x0, x1 = spec["lit"]
        hline(im, max(1, x0), min(x1, w - 2), 1, LIGHT)
    if spec.get("top_shadow"):
        hline(im, 1, w - 2, 0, spec["top_shadow"])
    # joints: left + bottom only
    joint = DEEP if face in (BEAR, BEAR2, BEAR3, MIDD) else DARK
    hline(im, 0, w - 1, h - 1, joint)
    for x in range(5, w, 23):
        if (x + w) % 5 == 0:
            im.putpixel((x, h - 1), DEEP)
    vline(im, 0, 0, h - 1, joint)
    return im


def deck_top(w, variant):
    im = canvas(w, 3)
    rect(im, 0, 0, w - 1, 2, TOP)
    hline(im, 0, w - 1, 0, TOPHI)
    # wear breaks the white line, but keeps the top row opaque
    wear = [(19, 23), (57, 60), (79, 81)] if variant == "a" else [(9, 14), (48, 52), (70, 74)]
    for a, b in wear:
        if a < w:
            hline(im, a, min(b, w - 1), 0, MID2)
    hline(im, 0, w - 1, 2, LIGHT2)
    if variant == "b":
        hline(im, 30, min(46, w - 1), 2, LIGHT)
    return im


def deck_face(w, variant):
    im = canvas(w, 7)
    face = LIGHT if variant == "a" else LIGHT2
    rect(im, 0, 0, w - 1, 6, face)
    hline(im, 0, w - 1, 6, LIGHT)
    # tooling / weather, not a joint
    if variant == "a":
        vline(im, min(66, w - 3), 1, 5, SHADE)
        hline(im, min(18, w - 4), min(34, w - 2), 4, LIGHT2)
        rect(im, min(52, w - 2), 5, min(55, w - 1), 5, DEEP)
    else:
        vline(im, min(36, w - 3), 2, 6, SHADE)
        hline(im, min(10, w - 4), min(24, w - 2), 3, LIGHT)
        rect(im, min(74, w - 2), 4, min(77, w - 1), 5, DEEP)
    return im


def beam_face(w, variant):
    im = canvas(w, 8)
    rect(im, 0, 0, w - 1, 7, LIGHT2 if variant == "a" else LIGHT)
    hline(im, 0, w - 1, 0, LIGHT2)
    hline(im, 0, w - 1, 7, SHADE)
    if variant == "a":
        vline(im, min(58, w - 3), 1, 6, SHADE)
        hline(im, min(14, w - 4), min(30, w - 2), 4, LIGHT)
    else:
        stepped_tone(im, 28, 3, min(66, w - 2), 6, MID2)
        vline(im, min(76, w - 3), 1, 7, SHADE)
    return im


def beam_lower(w, variant):
    im = canvas(w, 9)
    face = MIDD if variant == "a" else MID
    rect(im, 0, 0, w - 1, 8, face)
    hline(im, 0, w - 1, 0, DARK)
    hline(im, 0, w - 1, 1, SHADE)
    hline(im, 0, w - 1, 8, SHADE)
    # local lit top facets on a few stones; the rest stays in shadow
    hline(im, 1, min(16, w - 2), 1, LIGHT)
    hline(im, min(32, w - 2), min(44, w - 2), 1, MID2)
    vline(im, min(70, w - 3), 2, 7, SHADE)
    return im


def soffit(w, h, variant):
    im = canvas(w, h)
    rect(im, 0, 0, w - 1, h - 2, SHADE if variant == "a" else MIDD)
    hline(im, 0, w - 1, 0, SHADE)
    hline(im, 0, w - 1, h - 1, DEEP)
    if variant == "b" and h >= 3:
        hline(im, 0, w - 1, 1, DARK)
    return im


def base(w, variant):
    im = canvas(w, 10)
    face = BEAR2 if variant in ("a", "c") else BEAR
    rect(im, 0, 0, w - 1, 9, face)
    hline(im, 0, w - 1, 0, DARK)
    hline(im, 1, w - 2, 1, LIGHT2)
    if variant in ("b", "c"):
        hline(im, max(1, w // 3), min(w - 2, w // 3 + 22), 1, TOP)
    hline(im, 1, w - 2, 2, MID2 if variant != "b" else MID)
    hline(im, 1, w - 2, 7, SHADE)
    hline(im, 1, w - 2, 8, DEEP)
    hline(im, 1, w - 2, 9, DEEP)
    # tooling / stain
    hline(im, max(1, w // 4), min(w - 2, w // 4 + 18), 4, MID)
    vline(im, min(w - 8, w - 3), 2, 6, SHADE)
    if variant in ("b", "c"):
        rect(im, w - 6, 7, w - 4, 8, DEEP)
    vline(im, 0, 0, 9, DEEP)
    return im


def pier_cap(variant):
    im = canvas(8, 3)
    rect(im, 0, 0, 7, 2, TOP)
    hline(im, 0, 7, 0, TOPHI)
    hline(im, 0, 7, 2, SHADE)
    vline(im, 0, 0, 2, LIGHT2)
    vline(im, 7, 0, 2, DARK)
    if variant == "b":
        im.putpixel((6, 0), MID2)
    return im


def pier_drum(variant):
    im = canvas(8, 12)
    face = MID if variant == "a" else MIDD
    rect(im, 0, 0, 7, 11, face)
    vline(im, 0, 0, 11, LIGHT2)
    vline(im, 1, 0, 11, LIGHT)
    vline(im, 6, 0, 11, SHADE)
    vline(im, 7, 0, 11, DARK)
    hline(im, 1, 5, 0, LIGHT)
    hline(im, 1, 6, 10, MIDD)
    hline(im, 0, 7, 11, DEEP)
    if variant == "b":
        im.putpixel((5, 5), DEEP)
        im.putpixel((6, 6), SHADE)
    return im


def pier_base(variant):
    im = canvas(8, 6)
    face = BEAR if variant == "a" else BEAR2
    rect(im, 0, 0, 7, 5, face)
    hline(im, 0, 7, 0, DARK)
    hline(im, 1, 6, 1, LIGHT2)
    hline(im, 1, 6, 4, SHADE)
    hline(im, 1, 6, 5, DEEP)
    vline(im, 0, 0, 5, LIGHT)
    vline(im, 7, 0, 5, DARK)
    return im


def break_core(w, h, side, variant):
    im = canvas(w, h)
    # The core is a fractured continuation of the same stone, not a dark strip.
    rect(im, 0, 0, w - 1, h - 1, MID2 if variant == "b" else MID)

    def mx(x):
        return w - 1 - x if side == "left" else x

    if variant == "a":
        chunks = [
            ([(3, 1), (12, 0), (15, 9), (10, 16), (3, 14)], MID2),
            ([(13, 2), (23, 5), (23, 19), (17, 24), (13, 13)], MIDD),
            ([(2, 15), (10, 14), (13, 28), (4, 31)], MID),
            ([(12, 23), (23, 21), (23, 36), (17, 39), (13, 31)], BEAR),
            ([(2, 31), (9, 29), (13, 39), (3, 39)], MID2),
        ]
        seams = [(22, 13, 23), (31, 2, 13)]
    elif variant == "b":
        chunks = [
            ([(3, 3), (12, 1), (15, 11), (10, 18), (3, 15)], MID),
            ([(13, 4), (23, 7), (23, 21), (18, 26), (14, 14)], MID2),
            ([(2, 17), (9, 15), (12, 29), (4, 32)], MIDD),
            ([(12, 25), (23, 22), (23, 37), (16, 39), (13, 32)], BEAR),
            ([(2, 33), (10, 31), (14, 39), (3, 39)], MID),
        ]
        seams = [(23, 13, 23), (32, 2, 12)]
    else:
        chunks = [
            ([(3, 1), (11, 2), (14, 11), (9, 17), (3, 15)], MIDD),
            ([(12, 3), (23, 1), (23, 15), (17, 21), (13, 12)], MID),
            ([(2, 16), (10, 14), (13, 29), (4, 32)], BEAR),
            ([(13, 22), (23, 19), (23, 35), (17, 39), (13, 30)], MID2),
            ([(2, 32), (9, 30), (13, 39), (3, 39)], MIDD),
        ]
        seams = [(21, 12, 23), (30, 2, 13)]
    for pts, face in chunks:
        mpts = [(mx(x), y) for x, y in pts]
        poly(im, mpts, face)
        # short lit top facet and a shade under the chunk; no full outline
        xs = [p[0] for p in mpts]
        ys = [p[1] for p in mpts]
        top = min(ys)
        left = min(xs)
        right = max(xs)
        hline(im, left + 1, min(left + 5, right - 1), top, LIGHT2)
        hline(im, left + 1, max(left + 1, right - 2), max(ys), SHADE)
    # irregular horizontal breaks and a few solid voids
    for y, x0, x1 in seams:
        a, b = (mx(x0), mx(x1))
        hline(im, min(a, b), max(a, b), y, DEEP)
        if y + 1 < h:
            hline(im, min(a, b) + 2, max(a, b) - 2, y + 1, SHADE)
    rect(im, mx(10), 18, mx(11), 19, DEEP)
    rect(im, mx(19), 27, mx(20), 28, DEEP)
    # long inner fracture, jagged, only two lit catches
    pts = [(1, 0), (2, 6), (0, 12), (2, 18), (1, 24), (2, 30), (0, 36), (1, h - 1)]
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        steps = max(abs(bx - ax), abs(by - ay))
        for s in range(steps + 1):
            x = round(ax + (bx - ax) * s / steps)
            y = round(ay + (by - ay) * s / steps)
            x = mx(x)
            if 0 <= x < w and 0 <= y < h:
                im.putpixel((x, y), DEEP)
                if (i == 1 and s == 2) or (i == 5 and s == 1):
                    lx = x - 1 if side == "left" else x + 1
                    if 0 <= lx < w:
                        im.putpixel((lx, y), LIGHT)
    # one branch into the wall side
    for s in range(4):
        x = mx(2 + s)
        y = 8 + (1 if s in (2, 3) else 0)
        if 0 <= x < w:
            im.putpixel((x, y), DEEP)
    return im


def beam_break(w, h, side, variant):
    im = canvas(w, h)
    rect(im, 0, 0, w - 1, h - 1, BEAR2)
    if side == "right":
        vline(im, 0, 0, h - 1, DEEP)
        poly(im, [(2, 1), (8, 2), (11, 5), (7, h - 2), (2, h - 3)], MID)
        hline(im, 2, 7, 1, LIGHT)
        hline(im, 2, 8, h - 2, SHADE)
    else:
        vline(im, w - 1, 0, h - 1, DEEP)
        poly(im, [(w - 3, 1), (w - 9, 2), (w - 12, 5), (w - 8, h - 2), (w - 3, h - 3)], MID)
        hline(im, w - 8, w - 3, 1, LIGHT)
        hline(im, w - 9, w - 3, h - 2, SHADE)
    hline(im, 0, w - 1, h - 1, DEEP)
    return im


def pier_break(w, h, side):
    im = canvas(w, h)
    rect(im, 0, 0, w - 1, h - 1, BEAR2)
    if side == "right":
        vline(im, 0, 0, h - 1, DEEP)
        hline(im, 1, w - 2, 1, LIGHT)
        im.putpixel((w - 1, 3), DARK)
    else:
        vline(im, w - 1, 0, h - 1, DEEP)
        hline(im, 1, w - 2, 1, LIGHT)
        im.putpixel((0, 3), DARK)
    return im


def damp(w, h):
    im = canvas(w, h)
    poly(im, [(2, 2), (9, 1), (17, 2), (22, 4), (21, 7), (17, 9),
              (12, 10), (5, 9), (1, 7)], MIDD)
    hline(im, 3, 19, 9, SHADE)
    hline(im, 2, 7, 8, SHADE)
    hline(im, 13, 20, 10, DARK)
    for x, y in ((5, 9), (11, 10), (17, 10)):
        im.putpixel((x, y), DEEP if x == 11 else SHADE)
    return im


def crack_decal(w, h):
    im = canvas(w, h)
    pts = [(2, 0), (1, 5), (2, 11), (0, 16), (2, 19)]
    for i in range(len(pts) - 1):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        steps = max(abs(bx - ax), abs(by - ay))
        for s in range(steps + 1):
            x = round(ax + (bx - ax) * s / steps)
            y = round(ay + (by - ay) * s / steps)
            if 0 <= x < w and 0 <= y < h:
                im.putpixel((x, y), DEEP)
                if y % 7 in (2, 3) and x + 1 < w:
                    im.putpixel((x + 1, y), LIGHT)
    return im


def chip(w, h):
    im = canvas(w, h)
    poly(im, [(1, 1), (2, 0), (6, 1), (7, 3), (5, 5), (2, 4)], DARK)
    hline(im, 2, 5, 5, LIGHT)
    im.putpixel((5, 2), DEEP)
    return im


def weather(w, h):
    im = canvas(w, h)
    for y in range(1, h - 2):
        if y % 19 in (0, 1):
            continue
        im.putpixel((1, y), SHADE)
        im.putpixel((2, y), DARK if y % 7 else SHADE)
        if y % 13 in (3, 4):
            im.putpixel((0, y), MIDD)
    return im


def main():
    atlas = canvas(*L.ATLAS_SIZE)
    for name, (x, y, w, h) in L.MODULES.items():
        if name.startswith("deck_top_"):
            im = deck_top(w, name[-1])
        elif name.startswith("deck_face_"):
            im = deck_face(w, name[-1])
        elif name.startswith("beam_face_"):
            im = beam_face(w, name[-1])
        elif name.startswith("beam_lower_"):
            im = beam_lower(w, name[-1])
        elif name.startswith("soffit_"):
            im = soffit(w, h, name[-1])
        elif name.startswith("block_"):
            im = draw_block(w, h, BLOCK_SPECS[name])
        elif name.startswith("base_"):
            variant = "a" if name.endswith("_a") else "b"
            if name.startswith("base_128"):
                variant = "c" if name.endswith("_a") else "b"
            im = base(w, variant)
        elif name.startswith("pier_cap_"):
            im = pier_cap(name[-1])
        elif name.startswith("pier_drum_"):
            im = pier_drum(name[-1])
        elif name.startswith("pier_base_"):
            im = pier_base(name[-1])
        elif name.startswith("break_core_"):
            side = "right" if "right" in name else "left"
            im = break_core(w, h, side, name[-1])
        elif name.startswith("beam_break_"):
            side = "right" if "right" in name else "left"
            im = beam_break(w, h, side, name[-1])
        elif name.startswith("pier_break_"):
            side = "right" if "right" in name else "left"
            im = pier_break(w, h, side)
        elif name == "damp_24x14":
            im = damp(w, h)
        elif name == "crack_4x20":
            im = crack_decal(w, h)
        elif name == "chip_8x6":
            im = chip(w, h)
        elif name == "weather_4x48":
            im = weather(w, h)
        else:
            raise KeyError(name)
        atlas.alpha_composite(im, (x, y))
    atlas.save(os.path.join(HERE, "atlas.png"))
    print("saved atlas.png", atlas.size, "modules", len(L.MODULES))


if __name__ == "__main__":
    main()
