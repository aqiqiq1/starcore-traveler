#!/usr/bin/env python3
"""Build the LinkedWall + LinkedLip crystal component v3 (2026-11-18).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_linked_crystal_assets_v3.py

Outputs (original wall/lip PNGs untouched):
  layered_linked_v3_base_200x60.png
  layered_linked_v3_active_200x60.png
  layered_linked_v3_mask_200x60.png
  layered_linked_v3_arrival_200x60.png
  manifest_linked_v3_20261118.json

The 200x60 combined L-shape places the original 40x12 lip at x0..39,y0..11
and the wall at x40..199,y0..59. Unlike v2 this starts from a transparent
canvas: only the original upper stone shell (rows 0..26), its authored
downward face (2..6 px, irregular) and the original lip are stone. The lower
three sides are crystal all the way to the wall rectangle, so no old stone
strip can survive on the left, right or bottom. A short contact shadow is
multiplied into the top crystal rows so the facets still show through it.
Same approved two-state palette and a new Delaunay facet/arrival pass for this
component. No approved first-platform file is modified.
"""
from __future__ import annotations

import hashlib
import heapq
import json
import math
import random
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
WALL = PROJECT / "assets" / "level02_conductive_stone" / "conductive_sill_160x60.png"
LIP = PROJECT / "assets" / "level02_conductive_stone" / "conductive_lip_40x12.png"
BASE_OUT = HERE / "layered_linked_v3_base_200x60.png"
ACTIVE_OUT = HERE / "layered_linked_v3_active_200x60.png"
MASK_OUT = HERE / "layered_linked_v3_mask_200x60.png"
ARRIVAL_OUT = HERE / "layered_linked_v3_arrival_200x60.png"
MANIFEST = HERE / "manifest_linked_v3_20261118.json"

W, H = 200, 60
SEED = 20261121
ARRIVAL_WINDOW = 0.16 / 0.7
MAX_ARRIVAL = 1.0 - ARRIVAL_WINDOW
LIGHT_DIR = (-0.65, -0.76)
SUPER = [(-1000.0, -1000.0), (3000.0, -1000.0), (-1000.0, 3000.0)]

## Wall rows 0..26 keep the original stone cap (highlight, two bands, grooves).
SHELL_END = 27

## Downward face: below the cap the shell shows its front belly edge (one lit
## row) then turns away through 4..8 rows of darkening stone. The profile is
## hand-run so the thickness changes along the length instead of reading as one
## even outline.
FACE_RUNS = [
    (9, 6), (5, 4), (12, 7), (6, 5), (10, 8), (7, 4), (13, 6),
    (5, 7), (9, 4), (6, 8), (11, 5), (7, 6), (10, 4), (6, 7),
    (12, 5), (5, 6), (9, 8), (7, 4), (11, 6), (7, 5),
]

FACE_TONES = [
    (145, 130, 128),
    (136, 122, 121),
    (128, 115, 115),
    (120, 108, 109),
    (112, 101, 103),
    (104, 94, 97),
    (96, 86, 90),
]

INACTIVE = [
    (22, 13, 34),
    (34, 20, 50),
    (52, 31, 76),
    (76, 47, 108),
    (104, 70, 146),
]
ACTIVE = [
    (40, 20, 63),
    (74, 36, 112),
    (113, 54, 158),
    (180, 107, 221),
    (211, 147, 237),
]


def face_depth(wall_x: int) -> int:
    pos = 0
    for length, val in FACE_RUNS:
        if wall_x < pos + length:
            return val
        pos += length
    return 3


def crystal_top(wall_x: int) -> int:
    return SHELL_END + face_depth(wall_x)


def shadow_rows(wall_x: int) -> int:
    n = value_noise(wall_x / 9.0, 5.7)
    return 1 if n < 0.30 else (2 if n < 0.78 else 3)


def shadow_mul(wall_x: int) -> float:
    return 0.50 + 0.14 * value_noise(wall_x / 7.0, 11.3)


def build_mask() -> Image.Image:
    mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mp = mask.load()
    # Wall crystal reaches the wall rectangle on left, right and bottom; the
    # shell/face above it and the lip stay stone.
    for wx in range(0, 160):
        cx = 40 + wx
        for y in range(crystal_top(wx), H):
            mp[cx, y] = (255, 255, 255, 255)
    return mask


def value_noise(x: float, y: float) -> float:
    def h(ix: int, iy: int) -> float:
        n = (ix * 374761393 + iy * 668265263) & 0xFFFFFFFF
        n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
    x0, y0 = int(x // 1), int(y // 1)
    fx, fy = x - x0, y - y0
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    a = h(x0, y0)
    b = h(x0 + 1, y0)
    c = h(x0, y0 + 1)
    d = h(x0 + 1, y0 + 1)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def build_points(rng: random.Random) -> list[tuple[float, float]]:
    pts = [(-8.0, 4.0), (W + 8.0, 4.0), (W + 8.0, H + 3.0), (-8.0, H + 3.0)]
    attempts = 0
    while len(pts) < 92 and attempts < 6000:
        attempts += 1
        x = rng.uniform(-4.0, W + 4.0)
        y = rng.uniform(24.0, H + 1.0)
        radius = rng.uniform(5.0, 10.0)
        ok = True
        for (px, py) in pts[4:]:
            if (x - px) ** 2 + (y - py) ** 2 < radius * radius:
                ok = False
                break
        if ok:
            pts.append((x, y))
    for _ in range(18):
        px, py = pts[rng.randrange(4, len(pts))]
        ang = rng.uniform(0.0, math.tau)
        d = rng.uniform(3.0, 5.5)
        pts.append((px + math.cos(ang) * d, py + math.sin(ang) * d))
    return pts


def circumcircle(a, b, c):
    ax, ay = a
    bx, by = b
    cx, cy = c
    d = 2.0 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if abs(d) < 1e-9:
        return None
    a2 = ax * ax + ay * ay
    b2 = bx * bx + by * by
    c2 = cx * cx + cy * cy
    ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d
    uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d
    return ux, uy, (ax - ux) ** 2 + (ay - uy) ** 2


def delaunay(points):
    allp = points + SUPER
    n = len(points)
    tris = [(n, n + 1, n + 2)]
    for pi in range(n):
        p = allp[pi]
        bad = []
        for tri in tris:
            cc = circumcircle(allp[tri[0]], allp[tri[1]], allp[tri[2]])
            if cc is None:
                continue
            ux, uy, r2 = cc
            if (p[0] - ux) ** 2 + (p[1] - uy) ** 2 <= r2 + 1e-7:
                bad.append(tri)
        edges = {}
        for (a, b, c) in bad:
            for (u, v) in ((a, b), (b, c), (c, a)):
                key = (u, v) if u < v else (v, u)
                if key in edges:
                    del edges[key]
                else:
                    edges[key] = key
        keep = [t for t in tris if t not in bad]
        for (u, v) in edges.values():
            keep.append((u, v, pi))
        tris = keep
    return [t for t in tris if all(i < n for i in t)]


def triangle_at(px, py, tris, pts):
    for i, (a, b, c) in enumerate(tris):
        ax, ay = pts[a]
        bx, by = pts[b]
        cx, cy = pts[c]
        c1 = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        c2 = (cx - bx) * (py - by) - (cy - by) * (px - bx)
        c3 = (ax - cx) * (py - cy) - (ay - cy) * (px - cx)
        if (c1 >= -1e-7 and c2 >= -1e-7 and c3 >= -1e-7) or \
           (c1 <= 1e-7 and c2 <= 1e-7 and c3 <= 1e-7):
            return i
    best = 1e18
    hit = 0
    for i, (a, b, c) in enumerate(tris):
        gx = (pts[a][0] + pts[b][0] + pts[c][0]) / 3.0
        gy = (pts[a][1] + pts[b][1] + pts[c][1]) / 3.0
        d = (gx - px) ** 2 + (gy - py) ** 2
        if d < best:
            best = d
            hit = i
    return hit


def barycentric(p, a, b, c):
    ax, ay = a
    bx, by = b
    cx, cy = c
    v0x, v0y = bx - ax, by - ay
    v1x, v1y = cx - ax, cy - ay
    v2x, v2y = p[0] - ax, p[1] - ay
    den = v0x * v1y - v1x * v0y
    if abs(den) < 1e-9:
        return (1.0, 0.0, 0.0)
    v = (v2x * v1y - v1x * v2y) / den
    w = (v0x * v2y - v2x * v0y) / den
    return (1.0 - v - w, v, w)


def tone_for(tri, pts, idx):
    ax, ay = pts[tri[0]]
    bx, by = pts[tri[1]]
    cx, cy = pts[tri[2]]
    gx = (ax + bx + cx) / 3.0
    gy = (ay + by + cy) / 3.0
    edges = [((bx - ax), (by - ay)), ((cx - bx), (cy - by)), ((ax - cx), (ay - cy))]
    ex, ey = max(edges, key=lambda e: e[0] * e[0] + e[1] * e[1])
    nx, ny = -ey, ex
    ln = math.hypot(nx, ny)
    if ln > 1e-6:
        nx, ny = nx / ln, ny / ln
    if nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1] < 0:
        nx, ny = -nx, -ny
    lit = nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1]
    h = random.Random(SEED + idx * 7919).random()
    if h < 0.36:
        t = 0
    elif h < 0.62:
        t = 1
    elif h < 0.88:
        t = 2
    elif h < 0.97:
        t = 3
    else:
        t = 4
    if gy < 38 and h < 0.5 and t < 4:
        t += 1
    if gy > 52 and h > 0.68 and t > 0:
        t -= 1
    return max(0, min(4, t))


def build():
    wall = Image.open(WALL).convert("RGBA")
    lip = Image.open(LIP).convert("RGBA")
    assert wall.size == (160, 60) and lip.size == (40, 12)
    # Transparent canvas: no original.copy(), so no side or bottom stone can
    # survive from the old wall.
    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    active = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    base.paste(lip, (0, 0))
    active.paste(lip, (0, 0))
    # Original upper stone shell only.
    for y in range(SHELL_END):
        for x in range(160):
            base.putpixel((40 + x, y), wall.getpixel((x, y)))
            active.putpixel((40 + x, y), wall.getpixel((x, y)))

    bp, ap = base.load(), active.load()
    # Authored downward face of the same stone: darker per row, jittered along
    # the length, irregular depth from FACE_RUNS.
    for wx in range(160):
        cx = 40 + wx
        d = face_depth(wx)
        for i in range(d):
            y = SHELL_END + i
            tone = FACE_TONES[min(i, len(FACE_TONES) - 1)]
            j = int(round((value_noise(wx / 5.0, 21.7) - 0.5) * 8.0))
            if wx == 80:
                j -= 12          # the cap's own vertical joint continues down
            col = (
                max(0, min(255, tone[0] + j)),
                max(0, min(255, tone[1] + j)),
                max(0, min(255, tone[2] + j)),
                255,
            )
            bp[cx, y] = col
            ap[cx, y] = col

    mask = build_mask()
    mp = mask.load()

    rng = random.Random(SEED)
    pts = build_points(rng)
    tris = delaunay(pts)
    tones = [tone_for(t, pts, i) for i, t in enumerate(tris)]

    tri_pixels = [[] for _ in tris]
    crystal_px = []
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] > 0:
                ti = triangle_at(x + 0.5, y + 0.5, tris, pts)
                tri_pixels[ti].append((x, y))
                crystal_px.append((x, y))
    visible = [i for i in range(len(tris)) if tri_pixels[i]]

    for ti in visible:
        tone = tones[ti]
        for (x, y) in tri_pixels[ti]:
            bp[x, y] = (*INACTIVE[tone], 255)
            ap[x, y] = (*ACTIVE[tone], 255)

    # Contact shadow: multiply the top crystal rows (facets stay readable), with
    # varying row count and strength along the length.
    for (x, y) in crystal_px:
        wx = x - 40
        top = crystal_top(wx)
        k = y - top
        if k < shadow_rows(wx):
            f = shadow_mul(wx) + 0.10 * k
            r, g, b, a = bp[x, y]
            bp[x, y] = (int(r * f), int(g * f), int(b * f), a)
            r, g, b, a = ap[x, y]
            ap[x, y] = (int(r * f), int(g * f), int(b * f), a)

    # Adjacency among visible crystal triangles.
    edge_to_tris = {}
    for ti in visible:
        a, b, c = tris[ti]
        for (u, v) in ((a, b), (b, c), (c, a)):
            key = (u, v) if u < v else (v, u)
            edge_to_tris.setdefault(key, []).append(ti)
    neighbors = {ti: set() for ti in visible}
    for lst in edge_to_tris.values():
        for i in range(len(lst)):
            for j in range(i + 1, len(lst)):
                neighbors[lst[i]].add(lst[j])
                neighbors[lst[j]].add(lst[i])
    centroid = {}
    min_y = {}
    for ti in visible:
        a, b, c = tris[ti]
        centroid[ti] = ((pts[a][0] + pts[b][0] + pts[c][0]) / 3.0,
                        (pts[a][1] + pts[b][1] + pts[c][1]) / 3.0)
        min_y[ti] = min(y for (_, y) in tri_pixels[ti])

    # Sources: faces along the shell mouth, then down over ~0.7 s.
    sources = []
    for ti in visible:
        cx, cy = centroid[ti]
        if cx >= 40 and min_y[ti] <= 38:
            sources.append(ti)
    start = {}
    for ti in sources:
        cx, cy = centroid[ti]
        start[ti] = 0.02 + 0.06 * value_noise(cx / 60.0, 2.3)
    arrival = {ti: 1e9 for ti in visible}
    heap = []
    for ti, t in start.items():
        arrival[ti] = t
        heapq.heappush(heap, (t, ti))
    while heap:
        cur, ti = heapq.heappop(heap)
        if cur > arrival[ti] + 1e-9:
            continue
        cx, cy = centroid[ti]
        for nb in neighbors[ti]:
            nx, ny = centroid[nb]
            dist = math.hypot(nx - cx, ny - cy)
            down = max(0.0, ny - cy) / 5.0
            cost = 0.010 + 0.008 * dist / 9.0 + 0.016 * down
            cand = cur + cost
            if cand < arrival[nb]:
                arrival[nb] = cand
                heapq.heappush(heap, (cand, nb))
    finite = [arrival[t] for t in visible if arrival[t] < 1e8]
    fallback = max(finite) + 0.1 if finite else 0.1
    for ti in visible:
        if arrival[ti] >= 1e8:
            arrival[ti] = fallback + centroid[ti][1] / 80.0

    incident = {}
    for ti in visible:
        w = len(tri_pixels[ti])
        for vi in tris[ti]:
            incident.setdefault(vi, []).append((arrival[ti], w))
    vert_arr = {}
    rvr = random.Random(SEED + 777)
    for vi, vals in incident.items():
        total = sum(w for _, w in vals)
        val = sum(a * w for a, w in vals) / max(total, 1)
        val += (rvr.random() - 0.5) * 0.012
        vert_arr[vi] = val

    raw = {}
    for ti in visible:
        a, b, c = tris[ti]
        for (x, y) in tri_pixels[ti]:
            w0, w1, w2 = barycentric((x + 0.5, y + 0.5), pts[a], pts[b], pts[c])
            raw[(x, y)] = max(0.0, w0 * vert_arr[a] + w1 * vert_arr[b] + w2 * vert_arr[c])
    lo = min(raw.values())
    hi = max(raw.values())
    span = max(hi - lo, 1e-9)
    norm = {}
    for p, v in raw.items():
        base_v = (v - lo) / span * MAX_ARRIVAL
        extra = max(0.0, base_v - 0.08)
        norm[p] = base_v + 0.6 * extra * (MAX_ARRIVAL - base_v) / MAX_ARRIVAL

    arrival_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rp = arrival_img.load()
    for (x, y), v in norm.items():
        g = int(round(v * 255.0))
        rp[x, y] = (g, g, g, 255)

    base.save(BASE_OUT)
    active.save(ACTIVE_OUT)
    mask.save(MASK_OUT)
    arrival_img.save(ARRIVAL_OUT)
    info = {
        "visible_triangles": len(visible),
        "source_faces": len(sources),
        "crystal_pixels": len(raw),
        "mask_pixels": sum(1 for y in range(H) for x in range(W) if mp[x, y][3] > 0),
        "arrival_min_norm": min(norm.values()),
        "arrival_max_norm": max(norm.values()),
        "arrival_window_norm": ARRIVAL_WINDOW,
        "arrival_window_s": 0.16,
        "duration_s": 0.7,
        "shell_rows": SHELL_END,
        "face_depth_min": min(face_depth(x) for x in range(160)),
        "face_depth_max": max(face_depth(x) for x in range(160)),
        "crystal_top_min": min(crystal_top(x) for x in range(160)),
        "crystal_top_max": max(crystal_top(x) for x in range(160)),
        "bottom_y": max(y for (_, y) in raw),
    }
    return base, active, mask, arrival_img, info, wall


def main():
    base, active, mask, arrival, info, wall = build()
    bp, ap, mp = base.load(), active.load(), mask.load()
    # No old side or bottom stone: every wall pixel below the shell/face is
    # crystal, and both states are opaque there.
    for wx in range(160):
        cx = 40 + wx
        top = crystal_top(wx)
        for y in range(top, H):
            assert bp[cx, y][3] == 255 and ap[cx, y][3] == 255, (cx, y)
            r, g, b, _ = bp[cx, y]
            assert b > r, ("crystal should be violet", cx, y, (r, g, b))
        for y in range(top):
            assert mp[cx, y][3] == 0, ("stone must not be crystal", cx, y)
    assert mp[40, 40][3] == 255 and mp[199, 40][3] == 255, "side edge must be crystal"
    assert mp[120, 59][3] == 255, "bottom edge must be crystal"
    assert mp[36, 9][3] == 0 and mp[41, 9][3] == 0, "lip/seam stays stone"
    assert mp[120, 3][3] == 0, "shell stays stone"
    assert bp[0, 30][3] == 0 and bp[39, 59][3] == 0, "left-bottom stays transparent"
    # Lip pixels are the untouched source.
    lp = Image.open(LIP).convert("RGBA").load()
    for y in range(12):
        for x in range(40):
            assert bp[x, y] == lp[x, y], ("lip changed", x, y)
    # The shell keeps the original stone rows.
    wp = wall.load()
    for y in range(SHELL_END):
        for wx in range(160):
            assert bp[40 + wx, y] == wp[wx, y], ("shell changed", wx, y)

    manifest = {
        "title": "LinkedWall + LinkedLip crystal component v3 (stone cap, exposed crystal sides/bottom)",
        "created": "2026-11-18",
        "status": "second high platform visual rework; original wall/lip untouched",
        "geometry": "200x60 combined L: original 40x12 lip at x0..39,y0..11; wall x40..199,y0..59; transparent x0..39,y12..59",
        "states": "inactive = approved dark purple; active = approved internal-lit purple",
        "activation": "shared first Relay, 0.7 s face-following arrival, 0.16 s window; no independent trigger",
        "files": {
            "base": {"file": BASE_OUT.name, "sha256": hashlib.sha256(BASE_OUT.read_bytes()).hexdigest()},
            "active": {"file": ACTIVE_OUT.name, "sha256": hashlib.sha256(ACTIVE_OUT.read_bytes()).hexdigest()},
            "mask": {"file": MASK_OUT.name, "sha256": hashlib.sha256(MASK_OUT.read_bytes()).hexdigest()},
            "arrival": {"file": ARRIVAL_OUT.name, "sha256": hashlib.sha256(ARRIVAL_OUT.read_bytes()).hexdigest()},
        },
        "source": {
            "wall": {"file": str(WALL.relative_to(PROJECT)).replace("\\", "/"),
                     "sha256": hashlib.sha256(WALL.read_bytes()).hexdigest()},
            "lip": {"file": str(LIP.relative_to(PROJECT)).replace("\\", "/"),
                    "sha256": hashlib.sha256(LIP.read_bytes()).hexdigest()},
        },
        "info": info,
        "design_notes": [
            "Starts from a transparent canvas. Only the original stone cap (rows 0..26), its authored downward face (2..6 px, irregular runs) and the original lip are stone.",
            "The crystal fills the wall rectangle on the left, right and bottom, so the old side and bottom stone strips cannot appear; the original Wall/Lip sprites are hidden at runtime once this material binds.",
            "The downward face is two to six rows of dark stone with per-row darkening and per-column jitter; a multiplied 1..3 row contact shadow varies with the facets below it.",
            "The mouth is only along the upper junction; nothing wraps around the lower three sides.",
            "Facet tones and both approved state palettes are the same as the first platform component; only mask/arrival geometry is new for this larger crystal area.",
            "No route/gold corners or independent unlock are present. Collision and coordinates are untouched.",
        ],
        "regenerate": "D:/minic/envs/2024212971/python.exe make_linked_crystal_assets_v3.py",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, ensure_ascii=False))
    print(json.dumps(manifest["files"], ensure_ascii=False))


if __name__ == "__main__":
    main()
