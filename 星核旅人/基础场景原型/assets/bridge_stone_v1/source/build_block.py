"""Offline whole-pixel terrain builder for bridge_stone_v1.

Fixed CLI:
  python build_block.py --width W --height H --kind ground|deck|pier \
      --left solid|broken --right solid|broken --output ABSOLUTE_PATH

No scale, no random seed, no extra artistic parameters.  The output is exactly
W x H; the top row is opaque across the full width.  Broken ends only recede
below the top strip and never open an interior hole.
"""
from __future__ import annotations

import argparse
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

P = L.PALETTE
OUT, DEEP, DARK, SHADE, MIDD, MID, MID2, LIGHT, LIGHT2, TOP, TOPHI, BEAR, BEAR2, BEAR3 = (
    P["OUT"], P["DEEP"], P["DARK"], P["SHADE"], P["MIDD"], P["MID"], P["MID2"],
    P["LIGHT"], P["LIGHT2"], P["TOP"], P["TOPHI"], P["BEAR"], P["BEAR2"], P["BEAR3"],
)

_ATLAS = Image.open(os.path.join(HERE, "atlas.png")).convert("RGBA")


def get(name):
    x, y, w, h = L.MODULES[name]
    return _ATLAS.crop((x, y, x + w, y + h))


def paste(im, src, x, y):
    im.alpha_composite(src, (x, y))


def clear(im, x0, y0, x1, y1):
    if x1 < x0 or y1 < y0:
        return
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=(0, 0, 0, 0))


def rect(im, x0, y0, x1, y1, c):
    if x1 >= x0 and y1 >= y0:
        ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def hline(im, x0, x1, y, c):
    rect(im, x0, y, x1, y, c)


def poly(im, pts, c):
    ImageDraw.Draw(im).polygon(pts, fill=c)


def vline(im, x, y0, y1, c):
    rect(im, x, y0, x, y1, c)


def tile_h(im, names, x0, x1, y, h=None, from_bottom=False, start=0):
    """Tile modules horizontally to exactly x1-x0.  Last module is cropped."""
    x = x0
    i = start
    while x < x1:
        src = get(names[i % len(names)])
        if h is not None and h < src.height:
            src = src.crop((0, src.height - h, src.width, src.height)) if from_bottom else src.crop((0, 0, src.width, h))
        if x + src.width > x1:
            src = src.crop((0, 0, x1 - x, src.height))
        paste(im, src, x, y)
        x += src.width
        i += 1


def place_block(im, name, x, y, w, h):
    src = get(name)
    if h < src.height:
        src = src.crop((0, src.height - h, src.width, src.height))
    if w < src.width:
        src = src.crop((0, 0, w, src.height))
    paste(im, src, x, y)


def slab_positions(W):
    """Interior deck joints; last slab is at least 24 px."""
    pattern = [96, 80, 112, 96, 64, 128]
    xs = []
    x = 0
    i = 0
    while True:
        x += pattern[i % len(pattern)]
        i += 1
        if x >= W - 24:
            break
        xs.append(x)
    return xs


def block_widths(W, offset):
    pattern = [72, 80, 64, 56, 80, 64, 72, 56]
    out = []
    rem = W
    k = offset
    while rem > 80:
        w = pattern[k % len(pattern)]
        k += 1
        if rem - w < 8:
            w = rem - 8
        if w < 24:
            w = min(80, rem - 8)
        out.append(w)
        rem -= w
    if rem > 0:
        if rem < 24 and out:
            need = 24 - rem
            take = min(need, out[-1] - 32)
            if take > 0:
                out[-1] -= take
                rem += take
        out.append(rem)
    return out


def course_heights(body):
    n = max(1, math.ceil(body / 20))
    base = body // n
    rem = body % n
    return [base + (1 if i < rem else 0) for i in range(n)]


def course_family(i, n):
    if n == 1:
        return "mid"
    if i == 0:
        return "mid2"
    if i == n - 1:
        return "bear2"
    if n >= 6 and i == 1:
        return "mid"
    if n >= 6 and i == n - 2:
        return "bear"
    return "midd"


LIGHTER = {"mid": "mid2", "midd": "mid", "bear": "midd", "bear2": "bear"}
DARKER = {"mid2": "mid", "mid": "midd", "midd": "bear", "bear": "bear2"}


def shifted_family(fam, j, i):
    if (j * 7 + i * 5) % 9 == 0:
        return LIGHTER.get(fam, fam)
    if (j * 11 + i * 3) % 13 == 0:
        return DARKER.get(fam, fam)
    return fam


def pick_block(family, j, i, lower):
    fam = family
    if (j * 5 + i * 7) % 23 == 0:
        fam = "crack"
    elif (j * 3 + i * 5) % 17 == 0:
        fam = "chip"
    elif (j * 7 + i * 3) % 13 == 4:
        fam = "lit" if lower else "light"
    names = L.BLOCK_FAMILIES[fam]
    return names[(j * 3 + i * 5) % len(names)]


def add_deck(W, H, kind):
    """Return y where the bearing body starts."""
    top_h = 3
    tile_h(_im, L.DECK_TOP, 0, W, 0, top_h, start=0)
    # face 7 rows
    tile_h(_im, L.DECK_FACE, 0, W, top_h, 7, start=1)
    # bevel + narrow eave shadow
    hline(_im, 0, W - 1, 10, LIGHT)
    hline(_im, 0, W - 1, 11, SHADE)
    hline(_im, 0, W - 1, 12, DEEP)
    hline(_im, 0, W - 1, 13, DARK)
    # slab joints, opaque (top row stays full)
    for idx, x in enumerate(slab_positions(W)):
        if x <= 0 or x >= W:
            continue
        vline(_im, x, 0, 11, DARK if idx % 3 else DEEP)
        _im.putpixel((x, 10), DEEP)
        # a worn chip at one joint, still opaque
        if idx % 4 == 1:
            _im.putpixel((x, 0), DEEP)
            _im.putpixel((min(x + 1, W - 1), 0), MID2)
    return 14


def add_ground(W, H, left, right):
    deck = 12
    body0 = 14
    base0 = H - 10
    body = base0 - body0
    heights = course_heights(body)
    y = body0
    for i, h in enumerate(heights):
        fam = course_family(i, len(heights))
        lower = i >= len(heights) - 2
        widths = block_widths(W, i * 3)
        nblocks = len(widths)
        light_i = (i * 2 + 1) % nblocks
        dark_i = (i * 3 + 2) % nblocks
        if dark_i == light_i:
            dark_i = (dark_i + 1) % nblocks
        x = 0
        for j, w in enumerate(widths):
            fam_j = shifted_family(fam, j, i)
            if j == light_i:
                fam_j = LIGHTER.get(fam, fam)
            elif j == dark_i:
                fam_j = DARKER.get(fam, fam)
            name = pick_block(fam_j, j, i, lower)
            place_block(_im, name, x, y, w, h)
            x += w
        y += h
    # base course
    tile_h(_im, L.BASE_PIECES, 0, W, base0, 10, start=1)
    # decals: weather below selected deck joints, one damp patch, one crack
    joints = slab_positions(W)
    for k, jx in enumerate(joints):
        if k % 2 == 0 and base0 - 14 > 10:
            src = get("weather_4x48")
            hh = min(48, base0 - 14)
            src = src.crop((0, 0, 4, hh))
            paste(_im, src, min(jx + 2, W - 4), 14)
    if body >= 12:
        damp = get("damp_24x14")
        dx = max(2, W // 2 - 12)
        dy = 14 + max(0, body // 2 - 7)
        if dy + 14 > base0:
            damp = damp.crop((0, 0, 24, base0 - dy))
        paste(_im, damp, min(dx, W - 24), dy)
        crack = get("crack_4x20")
        cx = min(int(W * 0.72), W - 6)
        cy = 14 + max(0, body // 2)
        ch = min(20, base0 - cy)
        if ch > 4:
            paste(_im, crack.crop((0, 0, 4, ch)), cx, cy)
    # breaks
    if left == "broken":
        apply_break(W, H, "ground", "left", body0, base0)
    if right == "broken":
        apply_break(W, H, "ground", "right", body0, base0)


def add_deck_block(W, H, left, right):
    t = 2 if H <= 8 else 3
    u = 2 if H <= 12 else 3
    tile_h(_im, L.DECK_TOP, 0, W, 0, t, start=0)
    middle = H - t - u
    if middle <= 8:
        tile_h(_im, L.BEAM_FACE, 0, W, t, middle, start=0)
    else:
        upper = min(8, middle - 3)
        lower = middle - upper
        extra = 0
        if lower > 9:
            extra = lower - 9
            lower = 9
        tile_h(_im, L.BEAM_FACE, 0, W, t, upper, start=0)
        if upper >= 4:
            sx = max(2, min(W - 3, int(W * 0.62)))
            vline(_im, sx, t + 1, t + upper - 2, SHADE)
            cm = max(2, min(W - 4, int(W * 0.34)))
            hline(_im, cm, cm + 2, t + upper - 2, DEEP)
        by = t + upper
        if extra:
            hline(_im, 0, W - 1, by, SHADE)
            by += extra
        tile_h(_im, [L.BEAM_LOWER[(W // 8) % 2]], 0, W, by, lower, from_bottom=True)
        hline(_im, 0, W - 1, by, DARK)
        if by + lower + u < H:
            hline(_im, 0, W - 1, by + lower, SHADE)
    soffit_y = H - u
    if u == 2:
        tile_h(_im, L.SOFFIT2, 0, W, soffit_y, 2, start=0)
    else:
        tile_h(_im, L.SOFFIT3, 0, W, soffit_y, 3, start=0)
    # solid ends: one shade line, not a frame
    vline(_im, 0, t, H - u - 1, LIGHT2)
    vline(_im, W - 1, t, H - u - 1, SHADE)
    if left == "broken":
        apply_break(W, H, "deck", "left", t, H - u)
    if right == "broken":
        apply_break(W, H, "deck", "right", t, H - u)


def add_pier(W, H, left, right):
    cap = 3
    base = 6
    shaft = H - cap - base
    if W == 8:
        tile_h(_im, L.PIER_CAP, 0, 8, 0, 3, start=0)
        n = max(1, math.ceil(shaft / 12))
        pieces = [shaft // n + (1 if i < shaft % n else 0) for i in range(n)]
        y = cap
        for i, h in enumerate(pieces):
            tile_h(_im, [L.PIER_DRUM[i % 2]], 0, 8, y, h, from_bottom=True, start=0)
            hline(_im, 1, min(5, 7), y, MID2)
            y += h
        tile_h(_im, L.PIER_BASE, 0, 8, H - base, base, start=0)
    else:
        # continuous wide pier: lit left, shadowed back, horizontal drum joints
        hline(_im, 0, W - 1, 0, TOPHI)
        hline(_im, 0, W - 1, 1, TOP)
        hline(_im, 0, W - 1, 2, SHADE)
        vline(_im, 0, 0, 2, LIGHT2)
        vline(_im, W - 1, 0, 2, DARK)
        rect(_im, 0, cap, W - 1, H - base - 1, MID)
        vline(_im, 0, cap, H - base - 1, LIGHT2)
        vline(_im, 1, cap, H - base - 1, LIGHT)
        vline(_im, W - 2, cap, H - base - 1, SHADE)
        vline(_im, W - 1, cap, H - base - 1, DARK)
        for y in range(cap + 11, H - base, 12):
            hline(_im, 1, W - 2, y, DEEP)
            if y + 1 < H - base:
                hline(_im, 1, W - 2, y + 1, SHADE)
            hline(_im, 1, min(W // 3, W - 2), y - 1, MID2)
        if W >= 24:
            vline(_im, W // 2, cap + 2, H - base - 2, SHADE)
            vline(_im, W // 2 + 1, cap + 2, H - base - 2, MID)
        # base
        hline(_im, 0, W - 1, H - base, DARK)
        hline(_im, 1, W - 2, H - base + 1, LIGHT2)
        rect(_im, 0, H - base + 2, W - 1, H - 3, BEAR)
        hline(_im, 1, W - 2, H - 2, SHADE)
        hline(_im, 0, W - 1, H - 1, DEEP)
        vline(_im, 0, H - base, H - 1, LIGHT)
        vline(_im, W - 1, H - base, H - 1, DARK)
    if left == "broken":
        apply_break(W, H, "pier", "left", cap, H - base)
    if right == "broken":
        apply_break(W, H, "pier", "right", cap, H - base)


def _profile(W, H, kind, side, top, bottom, max_rec):
    edge = [W - 1] * H if side == "right" else [0] * H
    def put_depth(y0, y1, d, base_full=False):
        d = max(0, min(max_rec, d))
        for y in range(max(0, y0), min(H, y1)):
            edge[y] = (W - 1 - d) if side == "right" else d
    if kind == "ground":
        # top 6 px are untouchable; small deck-face chips, then body notches
        put_depth(0, 6, 0)
        put_depth(6, 7, 0)
        put_depth(7, 9, 1)
        put_depth(9, 10, 0)
        put_depth(10, 12, 1)
        put_depth(12, 14, 0)
        body0, base0 = 14, H - 10
        span = max(4, base0 - body0)
        notches = [(0.34, 0.05, 2), (0.64, 0.05, 2), (0.84, 0.04, 3)]
        for frac, dur, d in notches:
            y0 = body0 + int(span * frac)
            y1 = y0 + max(2, int(span * dur))
            put_depth(y0, y1, min(max_rec, d))
        # base gets a small break; most of the end stays solid stone
        put_depth(base0, H - 4, 1)
        put_depth(H - 4, H, 0)
    elif kind == "deck":
        put_depth(0, top, 0)
        # shallow chipped end below the continuous top strip
        span = max(1, bottom - top)
        d1 = 2 if H >= 12 else 1
        for frac, d in ((0.30, d1), (0.68, 1)):
            y0 = top + int(span * frac)
            put_depth(y0, min(bottom, y0 + max(2, span // 5)), d)
        put_depth(bottom, H, 1)
    else:  # pier
        put_depth(0, top, 0)
        span = max(1, bottom - top)
        for frac in (0.25, 0.65):
            y0 = top + int(span * frac)
            put_depth(y0, min(bottom, y0 + max(2, span // 5)), 1)
        put_depth(bottom, H, 1)
    return edge


def apply_break(W, H, kind, side, top, bottom):
    cw = min(24, max(6, W // 4)) if kind == "ground" else (min(12, max(4, W // 4)) if kind == "deck" else min(4, max(3, W // 4)))
    if kind == "ground":
        names = ["break_core_right_24x40_a", "break_core_right_24x40_b", "break_core_right_24x40_c"] if side == "right" else ["break_core_left_24x40_a", "break_core_left_24x40_b", "break_core_left_24x40_c"]
        x = W - cw if side == "right" else 0
        y = 14
        end = H - 10
        i = 0
        while y < end:
            h = min(40, end - y)
            src = get(names[i % 3])
            if side == "right":
                src = src.crop((0, 0, cw, h))
            else:
                src = src.crop((24 - cw, 0, 24, h))
            paste(_im, src, x, y)
            y += h
            i += 1
    elif kind == "deck":
        cw = min(8, max(4, W // 4))
        inner = W - cw + 2 if side == "right" else cw - 3
        if side == "right":
            pts = [(inner, top), (W - 2, top + 1), (W - 1, bottom - 3),
                   (W - 3, bottom - 1), (inner + 1, bottom - 2)]
        else:
            pts = [(inner, top), (1, top + 1), (0, bottom - 3),
                   (2, bottom - 1), (inner - 1, bottom - 2)]
        poly(_im, pts, MID2)
        hline(_im, min(p[0] for p in pts), max(p[0] for p in pts), top, LIGHT2)
        hline(_im, min(p[0] for p in pts) + 1, max(p[0] for p in pts) - 1, bottom - 1, SHADE)
        for y in range(top, bottom):
            x = inner + (1 if y % 7 in (2, 3) else 0)
            if 0 <= x < W:
                _im.putpixel((x, y), DEEP)
                if y % 9 == 2:
                    lx = x - 1 if side == "right" else x + 1
                    if 0 <= lx < W:
                        _im.putpixel((lx, y), LIGHT)
        if bottom - top > 6:
            vx = W - 3 if side == "right" else 2
            _im.putpixel((vx, top + 3), DEEP)
    else:
        cw = min(6, max(3, W // 3))
        inner = W - cw + 1 if side == "right" else cw - 2
        if side == "right":
            pts = [(inner, top), (W - 1, top + 2), (W - 1, bottom - 2),
                   (W - 3, bottom), (inner + 1, bottom - 1)]
        else:
            pts = [(inner, top), (0, top + 2), (0, bottom - 2),
                   (2, bottom), (inner - 1, bottom - 1)]
        poly(_im, pts, MID2)
        hline(_im, min(p[0] for p in pts) + 1, max(p[0] for p in pts), top, LIGHT2)
        hline(_im, min(p[0] for p in pts) + 1, max(p[0] for p in pts) - 1, bottom - 1, SHADE)
        for y in range(top, bottom):
            x = inner + (1 if y % 9 in (3, 4) else 0)
            if 0 <= x < W:
                _im.putpixel((x, y), DEEP)
                if y % 11 == 2:
                    lx = x - 1 if side == "right" else x + 1
                    if 0 <= lx < W:
                        _im.putpixel((lx, y), LIGHT)
    max_rec = 4 if kind == "ground" else (2 if kind == "deck" else 1)
    max_rec = min(max_rec, max(1, W // 8))
    edge = _profile(W, H, kind, side, top, bottom, max_rec)
    for y in range(H):
        if side == "right":
            clear(_im, edge[y] + 1, y, W - 1, y)
        else:
            clear(_im, 0, y, edge[y] - 1, y)
    # step shading: shadow under overhangs, light on surviving top faces
    for y in range(1, H):
        inward = edge[y] < edge[y - 1] if side == "right" else edge[y] > edge[y - 1]
        outward = edge[y] > edge[y - 1] if side == "right" else edge[y] < edge[y - 1]
        if inward:
            if side == "right":
                for x in range(edge[y], edge[y - 1]):
                    if _im.getpixel((x, y - 1))[3]:
                        _im.putpixel((x, y - 1), SHADE if y % 3 else DARK)
            else:
                for x in range(edge[y - 1], edge[y]):
                    if _im.getpixel((x, y - 1))[3]:
                        _im.putpixel((x, y - 1), SHADE if y % 3 else DARK)
        elif outward:
            if side == "right":
                for x in range(edge[y - 1] + 1, edge[y] + 1):
                    if 0 <= x < W and _im.getpixel((x, y))[3]:
                        _im.putpixel((x, y), LIGHT)
            else:
                for x in range(edge[y], edge[y - 1]):
                    if 0 <= x < W and _im.getpixel((x, y))[3]:
                        _im.putpixel((x, y), LIGHT)


def build(W, H, kind, left, right):
    global _im
    _im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if kind == "ground":
        add_deck(W, H, kind)
        add_ground(W, H, left, right)
    elif kind == "deck":
        add_deck_block(W, H, left, right)
    else:
        add_pier(W, H, left, right)
    # invariant: top row opaque across the full width
    px = _im.load()
    for x in range(W):
        if px[x, 0][3] != 255:
            raise AssertionError(("top row hole", W, H, kind, x))
    return _im


def main():
    ap = argparse.ArgumentParser(description="Build one exact-size bridge stone PNG.")
    ap.add_argument("--width", type=int, required=True)
    ap.add_argument("--height", type=int, required=True)
    ap.add_argument("--kind", choices=("ground", "deck", "pier"), required=True)
    ap.add_argument("--left", choices=("solid", "broken"), default="solid")
    ap.add_argument("--right", choices=("solid", "broken"), default="solid")
    ap.add_argument("--output", required=True)
    a = ap.parse_args()
    if a.kind == "ground" and (a.width < 32 or a.height < 32):
        ap.error("ground requires width>=32 and height>=32")
    if a.kind == "deck" and (a.width < 8 or a.height < 6 or a.height > 24):
        ap.error("deck requires width>=8 and 6<=height<=24")
    if a.kind == "pier" and (a.width < 8 or a.height < 24):
        ap.error("pier requires width>=8 and height>=24")
    if not os.path.isabs(a.output):
        ap.error("--output must be an absolute path")
    im = build(a.width, a.height, a.kind, a.left, a.right)
    os.makedirs(os.path.dirname(a.output), exist_ok=True)
    im.save(a.output)
    print(f"{a.output} {im.width}x{im.height} kind={a.kind} left={a.left} right={a.right}")


if __name__ == "__main__":
    main()
