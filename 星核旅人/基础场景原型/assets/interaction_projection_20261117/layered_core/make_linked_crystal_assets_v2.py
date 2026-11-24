#!/usr/bin/env python3
"""Build the LinkedWall + LinkedLip crystal component (2026-11-18).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_linked_crystal_assets_v2.py

Outputs (original wall/lip PNGs untouched):
  layered_linked_v2_base_200x60.png
  layered_linked_v2_active_200x60.png
  layered_linked_v2_mask_200x60.png
  layered_linked_v2_arrival_200x60.png
  manifest_linked_v2_20261118.json

The 200x60 combined L-shape places the original 40x12 lip at x0..39,y0..11
and the 160x60 wall at x40..199,y0..59. Top/shell/original outline and the
transparent left-bottom are preserved. The lip stays stone; the wall crystal
is inset behind a thick upper stone shell with a short irregular contact shadow,
a thin inset dark bottom edge, and no purple L at the wall/lip seam.
Same approved crystal palette; new Delaunay facets/arrival map for this
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
BASE_OUT = HERE / "layered_linked_v2_base_200x60.png"
ACTIVE_OUT = HERE / "layered_linked_v2_active_200x60.png"
MASK_OUT = HERE / "layered_linked_v2_mask_200x60.png"
ARRIVAL_OUT = HERE / "layered_linked_v2_arrival_200x60.png"
MANIFEST = HERE / "manifest_linked_v2_20261118.json"

W, H = 200, 60
SEED = 20261119
ARRIVAL_WINDOW = 0.16 / 0.7
MAX_ARRIVAL = 1.0 - ARRIVAL_WINDOW
LIGHT_DIR = (-0.65, -0.76)
SUPER = [(-1000.0, -1000.0), (3000.0, -1000.0), (-1000.0, 3000.0)]

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


def boundary_at(wall_x: int) -> int:
    # Hand-run thick wall top shell; crystal begins two rows lower (contact
    # shadow). No lip connector: the seam stays stone.
    if wall_x < 6 or wall_x > 155:
        return 0
    runs = [
        (10, 26), (8, 25), (14, 27), (7, 26), (12, 28), (9, 25), (13, 27),
        (6, 26), (15, 28), (8, 25), (11, 27), (7, 26), (14, 28), (9, 26),
        (12, 25), (7, 27), (10, 28), (8, 26), (13, 27), (6, 25),
    ]
    pos = 6
    for length, val in runs:
        if wall_x < pos + length:
            return val
        pos += length
    return 26


def build_mask() -> Image.Image:
    mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mp = mask.load()
    # Wall crystal is inset from the outer silhouette and begins below the
    # shell's 1 px irregular contact shadow. The lip is entirely stone.
    for wx in range(6, 156):
        b = boundary_at(wx)
        cx = 40 + wx
        for y in range(b + 2, 55):
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
    while len(pts) < 86 and attempts < 5000:
        attempts += 1
        x = rng.uniform(-4.0, W + 4.0)
        y = rng.uniform(3.0, H + 1.0)
        radius = rng.uniform(5.0, 11.0)
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
    if gy < 27 and h < 0.5 and t < 4:
        t += 1
    if gy > 47 and h > 0.68 and t > 0:
        t -= 1
    return max(0, min(4, t))


def build():
    wall = Image.open(WALL).convert("RGBA")
    lip = Image.open(LIP).convert("RGBA")
    assert wall.size == (160, 60) and lip.size == (40, 12)
    original = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    original.paste(lip, (0, 0))
    original.paste(wall, (40, 0))
    mask = build_mask()
    mp = mask.load()

    rng = random.Random(SEED)
    pts = build_points(rng)
    tris = delaunay(pts)
    tones = [tone_for(t, pts, i) for i, t in enumerate(tris)]

    tri_pixels = [[] for _ in tris]
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] > 0:
                ti = triangle_at(x + 0.5, y + 0.5, tris, pts)
                tri_pixels[ti].append((x, y))
    visible = [i for i in range(len(tris)) if tri_pixels[i]]
    visible_set = set(visible)

    base = original.copy()
    active = original.copy()
    bp, ap = base.load(), active.load()
    for ti in visible:
        tone = tones[ti]
        for (x, y) in tri_pixels[ti]:
            bp[x, y] = (*INACTIVE[tone], 255)
            ap[x, y] = (*ACTIVE[tone], 255)

    # Short irregular stone contact/shadow at the shell mouth and a thin inset
    # dark bottom edge. These are stone, not crystal; the mask stays clear.
    for wx in range(6, 156):
        cx = 40 + wx
        b = boundary_at(wx)
        stone = (50 + (wx * 7) % 7, 42 + (wx * 5) % 6, 46 + (wx * 3) % 5, 255)
        bp[cx, b + 1] = stone
        ap[cx, b + 1] = stone
        inner = (57 + (wx * 3) % 5, 49 + (wx * 5) % 5, 53 + (wx * 7) % 5, 255)
        bp[cx, 55] = inner
        ap[cx, 55] = inner

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

    # Sources: lip/connector top plus the wall panel's top faces.
    sources = []
    for ti in visible:
        cx, cy = centroid[ti]
        if cx > 40 and min_y[ti] <= 32:
            sources.append(ti)
    start = {}
    for ti in sources:
        cx, cy = centroid[ti]
        if cx < 48:
            start[ti] = 0.015 + 0.03 * value_noise(cx / 8.0, 1.3)
        else:
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
        "top_y": min(y for (_, y) in raw),
        "bottom_y": max(y for (_, y) in raw),
    }
    return base, active, mask, arrival_img, info, original


def main():
    base, active, mask, arrival, info, original = build()
    # Source shell/original preservation and L-shape alpha checks.
    op = original.load()
    bp = base.load()
    ap = active.load()
    mp = mask.load()
    shell_mismatch = 0
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] == 0:
                allowed = False
                if 46 <= x <= 195:
                    wx = x - 40
                    allowed = (y == boundary_at(wx) + 1) or (y == 55)
                if not allowed and (bp[x, y] != op[x, y] or ap[x, y] != op[x, y]):
                    shell_mismatch += 1
    assert shell_mismatch == 0, shell_mismatch
    assert mp[0, 30][3] == 0 and mp[39, 30][3] == 0, "left-bottom should be transparent"
    assert mp[36, 9][3] == 0 and mp[41, 9][3] == 0, "lip/seam must stay stone"
    assert mp[100, 30][3] == 255, "wall crystal missing"
    manifest = {
        "title": "LinkedWall + LinkedLip crystal component v2 (stone shell + recessed crystal)",
        "created": "2026-11-18",
        "status": "second high platform visual polish; original wall/lip untouched",
        "geometry": "200x60 combined L: original 40x12 lip at x0..39,y0..11; original 160x60 wall at x40..199,y0..59; transparent x0..39,y12..59",
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
            "Wall crystal is inset 6 px from the left and 4 px from the right; thick upper stone shell (27..31 px) with a short irregular stone contact shadow, and a thin inset dark bottom edge.",
            "The lip is entirely original stone; no lip crystal patch or L-shaped purple jump at the wall seam.",
            "Wall top/shell/side frames and lip stone remain source pixels except the authored contact/bottom stone shading rows.",
            "No first-platform texture is stretched or reused; this is a separate 200x60 original-size component.",
            "No route/gold corners or independent unlock are present.",
        ],
        "regenerate": "D:/minic/envs/2024212971/python.exe make_linked_crystal_assets_v2.py",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, ensure_ascii=False))
    print(json.dumps(manifest["files"], ensure_ascii=False))


if __name__ == "__main__":
    main()
